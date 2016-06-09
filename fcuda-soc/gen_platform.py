#!/usr/bin/python

import os
import sys
import subprocess
import tempfile
import re
import xml.etree.ElementTree as ET

def usage():
    print """
    Usage:
        python gen_platform.py {platform_id} {benchmark_name} {frequency divisor} {find_max_freq} {kernel1_workload} {kernel2_workload} ...

      where:
        platform_id: the device id of the target FPGA Soc platform (e.g 7z020, 7z045)
        benchmark_name: the name of the benchmarks for testing
        frequency divisor: used to calculate frequency: 533.33 / frequency_divisor
                (DDR PLL is the clock source)
        find_max_freq: 1 - reiterate Synthesis & Implementation until timing is met.
            (for each iteration, either increase or decrease the input frequency divisor 
             by 0.5 -- the step size)
                       0 - no iteration. Just generate the platform with the input 
                       frequency divisor
        kernel{i}_workload: the total number of thread blocks the kernel executes
    Example:
        python gen_platform.py 7z020 matmul 5 0 100
    """

def run_command(command, is_exit):
    process = subprocess.Popen([command], shell=True)
    out, err = process.communicate()
    if process.returncode != 0:
        print "Error: " + command
        print out, err
        if is_exit:
            sys.exit(1)

def fcuda_gen(app, kernel_workload):
    print "CUDA-to-C translation with workload: %s" % (str(kernel_workload))
    command = "rm -f %s/fcuda_gen/fcuda_gen_%s.c" % (benchmark_dir, app)
    run_command(command, 1)

    tf = tempfile.NamedTemporaryFile()
    kernel_file = open(os.path.join(benchmark_dir, "kernel/fcuda_annot_%s.cu" % app), 'r')
		
    kernel = 0
    for line in kernel_file:
        if "pragma FCUDA COREINFO" in line:
            new_line = re.sub("num_cores=[0-9]*", "num_cores=%d" % (kernel_workload[kernel]), line)
            kernel += 1
            tf.write(new_line)
        else:
            tf.write(line)
    tf.flush()

    cur_dir = os.getcwd()
    os.chdir(benchmark_dir)
    command = "fcuda %s -param_core -wrapper > log_fcuda.cu 2>&1" % (tf.name)
    run_command(command, 1)
    
    command = "mkdir -p fcuda_gen"
    run_command(command, 1)

    tmp =  os.path.split(tf.name)
    command = "mv %s/%s/%s fcuda_gen/fcuda_gen_%s.c" % (tmp[0], "fcuda_output", tmp[1], app)
    run_command(command, 1)
    tf.close()

    os.chdir(cur_dir)

def hls_gen(app, device_name):
    print "Vivado HLS C-to-RTL IP translation"
    command = "rm -rf %s/hls" % (benchmark_dir)
    run_command(command, 1)
    cur_dir = os.getcwd()
    os.chdir(benchmark_dir)

    tf = tempfile.NamedTemporaryFile()
    tcl_script = """
        open_project -reset hls
        set_top fcuda

        add_files -cflags "-I%s -I%s" fcuda_gen/fcuda_gen_%s.c
        open_solution -reset "solution1"

        set_part {%s}

        create_clock -period 10 -name default
        #csim_design
        csynth_design
        #cosim_design -trace_level none -rtl verilog -tool xsim
        export_design
        exit""" % (fcuda_header_dir, benchmark_dir, app, device_name)

    tf.write(tcl_script)
    tf.flush()
    command = "vivado_hls %s" % (tf.name)
    run_command(command, 1)
    tf.close()

    benchmark_ip_dir = os.path.join(benchmark_dir, "hls/solution1/impl/ip")
    os.chdir(benchmark_ip_dir)

    #Rerun packing the IP core in case Vivado HLS and Vivado
    #are in different versions.
    command = "./pack.sh"
    run_command(command, 1)
    
    os.chdir(cur_dir)

def vivado_gen(app, list_master_ports, freq_factor, find_max_freq, device_name):
    print "Vivado IP Integration"
    command = "vivado -mode batch -nojournal -nolog -source run_vivado_wrapper.tcl -tclargs\
            %s %s \"%s\" %d %d %s" % \
            (benchmark_dir, app, list_master_ports, freq_factor, find_max_freq, device_name)
    run_command(command, 0)
    if not os.path.exists("%s/vivado/%s/%s.runs/synth_1" % (benchmark_dir, app, app)):
        print "Cannot generate the Design. Please check the TCL script"
        sys.exit(1)

def main(argv):

    kernel_workload = []
    single_workload = []
    try:
        device = argv[1]
        app = argv[2]
        freq_factor = int(argv[3])
        find_max_freq = int(argv[4])
        for i in range(5, len(argv)):
            kernel_workload.append(int(argv[i]))
            single_workload.append(1)
    except:
        print "Error:", sys.exc_info()
        usage()
        sys.exit(1)

    num_kernels = len(kernel_workload)
    if num_kernels == 0:
        print "Number of kernels should not be 0"
        sys.exit(1)

    #Add the device id and device name here
    device_dict = {
        "7z020": "xc7z020clg484-1",
        "7z045": "xc7z045ffg900-1"
    }

    device_name = device_dict.get(device, None)
    if device_name is None:
        print "The specified device is not yet tested. Please add your device name in device_dict"
        sys.exit(1)

    #Get path from env_vars.sh. Make sure to "source env_vars.sh" before using this script.
    global benchmark_dir 
    benchmark_dir = os.path.join(os.environ['BENCHMARKS'], app)
    global fcuda_header_dir 
    fcuda_header_dir = os.path.join(os.environ['FROOT'], "include")

    #Generate 1 core design to get initial syn resources
    fcuda_gen(app, single_workload)    
    hls_gen(app, device_name)
    
    bram_util = []
    dsp_util = []
    ff_util = []
    lut_util = []
    for kernel in range(num_kernels):
        #Parse HLS resource report XML file
        xml_file = "%s/hls/solution1/syn/report/fcuda_fcuda%s_csynth.xml" % (benchmark_dir, kernel + 1)
        tree = ET.parse(xml_file)
        root = tree.getroot()
        bram=[]
        for child in root.iter('BRAM_18K'):
            bram.append(int(child.text))

        dsp=[]
        for child in root.iter('DSP48E'):
            dsp.append(int(child.text))

        ff=[]
        for child in root.iter('FF'):
            ff.append(int(child.text))

        lut=[]
        for child in root.iter('LUT'):
            lut.append(int(child.text))


        bram_util.append(bram[0] / float(bram[1]))
        dsp_util.append(dsp[0] / float(dsp[1]))
        ff_util.append(ff[0] / float(ff[1]))
        lut_util.append(lut[0] / float(lut[1]))

    #Find the maximum number of cores analytically
    total_bram_util = sum(bram_util)
    total_dsp_util = sum(dsp_util)
    total_ff_util = sum(ff_util)
    total_lut_util = sum(lut_util)
    
    analytical_max_cores = 1 / max(total_bram_util, total_dsp_util,
            total_ff_util, total_lut_util)
    analytical_max_cores = int(analytical_max_cores)

    bram_max = dsp_max = ff_max = lut_max = 1
    for kernel in range(num_kernels):
        if kernel_workload[kernel] < analytical_max_cores:
            bram_max -= kernel_workload[kernel] * bram_util[kernel]   
            dsp_max -= kernel_workload[kernel] * dsp_util[kernel]   
            ff_max -= kernel_workload[kernel] * ff_util[kernel]   
            lut_max -= kernel_workload[kernel] * lut_util[kernel]
        else:
            kernel_workload[kernel] = -1 #marked

    bram_remain = dsp_remain = ff_remain = lut_remain = 0
    for kernel in range(num_kernels):
        if kernel_workload[kernel] == -1:
            bram_remain = bram_remain + bram_util[kernel] / bram_max;
            dsp_remain = dsp_remain + dsp_util[kernel] / dsp_max;
            ff_remain = ff_remain + ff_util[kernel] / ff_max;
            lut_remain = lut_remain + lut_util[kernel] / lut_max;

    for kernel in range(num_kernels):
        if kernel_workload[kernel] == -1:
            new_analytical_max_cores = 1 / max(bram_remain, dsp_remain,
                    ff_remain, lut_remain)
            new_analytical_max_cores = int(new_analytical_max_cores)
            
            if new_analytical_max_cores == 1:
                new_analytical_max_cores = analytical_max_cores
            kernel_workload[kernel] = new_analytical_max_cores
    
    threshold = max(kernel_workload)
    #Remove old design
    subprocess.call(["rm", "-rf", "%s/vivado" % (benchmark_dir)])

    #Generate max cores design
    while not os.path.isfile("%s/vivado/%s/%s.runs/impl_1/design_1_wrapper.sysdef" % (benchmark_dir, app, app)):
        print "Generate FCUDA SoC platform with workload: %s" % (str(kernel_workload))

        fcuda_gen(app, kernel_workload)
        hls_gen(app, device_name)

        list_master_ports = '{'

        #Parse Vivado HLS IP XML file to get port information
        xml_file = "%s/hls/solution1/impl/ip/component.xml" % (benchmark_dir)
        tree = ET.parse(xml_file)
        root = tree.getroot()
        spirit_str = "{http://www.spiritconsortium.org/XMLSchema/SPIRIT/1685-2009}"
        for child in root.iter(spirit_str + "busInterface"):
            for child1 in child.findall(spirit_str + "name"):
                if "M_AXI_MEMPORT" in child1.text:
                    list_master_ports += child1.text + " "

        list_master_ports += '}'

        vivado_gen(app, list_master_ports, freq_factor, find_max_freq, device_name)

        #if the design is not able to be implemented, reduce #cores of kernels
        #having the biggest workload, and rerun Vivado
        for i in range(num_kernels):
            if kernel_workload[i] == threshold:
                kernel_workload[i] -= 1
        threshold -= 1

if __name__ == "__main__":
    print len(sys.argv)
    if len(sys.argv) < 6:
        print "Insufficient number of argument"
        usage()
        sys.exit(1)

    main(sys.argv)

