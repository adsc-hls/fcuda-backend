#!/usr/bin/python

import os
import sys
import subprocess
import tempfile
import re
import json
import xml.etree.ElementTree as ET
from jinja2 import Environment, FileSystemLoader, Template
from datetime import datetime

noc_dir = os.getcwd()
network_gen_dir = os.path.join(noc_dir, 'network_gen')
sys.path.append(network_gen_dir)

from network import Network
from node    import Node, Compute, Memory, Router

def usage():
    print """
    Usage:
        python gen_noc.py {benchmark_name} {width} {height} {sim_flow} {syn_flow}

      where:
        benchmark_name: the name of the benchmarks for testing
        width: width of the network
        height: height of the network
        sim_flow: simulation flow
            0 - no simulation
            1 - run Simulation with MIG + DDR3 
            2 - run Simulation without MIG + DDR3 (faster)
        syn_flow: synthesis flow
            0 - no synthesis
            1 - run Synthesis + P & R
    Example:
        python gen_noc.py matmul 3 3 2 0
    """

def run_command(command, is_exit):
    process = subprocess.Popen([command], shell=True)
    out, err = process.communicate()
    if process.returncode != 0:
        print "Error: " + command
        print out, err
        if is_exit:
            sys.exit(1)

def fcuda_gen(app):
    print "CUDA-to-C translation"

    tf = tempfile.NamedTemporaryFile()
    kernel_file = open(os.path.join(benchmark_dir, "kernel/fcuda_annot_%s_noc.cu" % app), 'r')
    for line in kernel_file:
        tf.write(line)
    tf.flush()

    os.chdir(benchmark_dir)
    command = "fcuda %s -param_core > log_fcuda.cu 2>&1" % (tf.name)
    run_command(command, 1)
    
    os.makedirs(os.path.join(project_dir, "fcuda_gen"))

    tmp =  os.path.split(tf.name)
    command = "mv %s/%s/%s %s/fcuda_gen/fcuda_gen_%s.c" % (tmp[0], "fcuda_output", tmp[1], project_dir, app)
    run_command(command, 1)
    tf.close()

def hls_gen(app, top_level_function, device_name):
    print "Vivado HLS C-to-RTL IP translation"
    os.chdir(project_dir)

    tf = tempfile.NamedTemporaryFile()
    tcl_script = """
        open_project -reset hls
        set_top %s

        add_files -cflags "-I%s -I%s" fcuda_gen/fcuda_gen_%s.c
        open_solution -reset "solution1"

        set_part {%s}

        create_clock -period 10 -name default
        #csim_design
        csynth_design
        #cosim_design -trace_level none -rtl verilog -tool xsim
        #export_design
        exit""" % (top_level_function, fcuda_header_dir, 
                    benchmark_dir, app, device_name)

    tf.write(tcl_script)
    tf.flush()
    command = "vivado_hls %s" % (tf.name)
    run_command(command, 1)
    tf.close()

    #benchmark_ip_dir = os.path.join(benchmark_dir, "hls_noc/solution1/impl/ip")
    #os.chdir(benchmark_ip_dir)

    #Rerun packing the IP core in case Vivado HLS and Vivado
    #are in different versions.
    #command = "./pack.sh"
    #run_command(command, 1)   

def gen_template(template_env, json_obj, template_dir, template_name):
    template = template_env.get_template('_%s.jinja' % template_name)
    f = open('%s/%s' % (template_dir, template_name), 'w')
    f.write(template.render(json_obj))
    f.close()

def vivado_run(sim_flow, syn_flow):
    os.chdir(project_dir)

    command = "vivado -mode batch -source noc_script.tcl -tclargs\
            vivado_prj %s %s" % \
            (sim_flow, syn_flow)
    run_command(command, 0)

def sim_verify(gold_output, sim_file_size):
    tf = tempfile.NamedTemporaryFile()
    vivado_log_file = "%s/vivado.log" % project_dir
    # Get the written address and data values from the log file
    command = \
        "grep \"Final write\" %s | sed \'s/.*data=\(.*\), addr=\(.*\),.*,.*/\\2 \\1/\' | sort -n > %s" \
            % (vivado_log_file, tf.name)
    run_command(command, 1)

    output_addr = []
    output_data = []
    line_no = 0
    for line in tf:
        line_tmp = line.split(' ')
        output_addr.append(int(line_tmp[0], 16) / 4)
        output_data.append(long(line_tmp[1], 16))

    tf.close()

    mismatched = 0
    pos = 0
    for i in range(sim_file_size):
        if i == output_addr[pos]:
            if gold_output[i] != output_data[pos]:
                mismatched = mismatched + 1
                print "mismatched at %d: %s %s" % (i, output_data[pos], gold_output[i])
            pos = pos + 1
    
    if mismatched > 0:
        print "Simulation failed. Number of mismatches: %d" % mismatched
    else:
        print "Simulation passed!"

def main(argv):

    try:
        app = argv[1]
        width = int(argv[2])
        height = int(argv[3])
        # sim_flow: 0 -- no simulation, 1 -- run Simulation with MIG + DDR3, 
        # 2 -- run Simulation without MIG + DDR3
        sim_flow = int(argv[4])
        # syn_flow: 0 -- no Sythesis, 1 -- run Synthesis + P & R
        syn_flow = int(argv[5])
    except:
        print "Error:", sys.exc_info()
        usage()
        sys.exit(1)

    # Get path from env_vars.sh. Make sure to "source env_vars.sh" before using this script.
    global benchmark_dir 
    benchmark_dir = os.path.join(os.environ['BENCHMARKS'], app)
    global fcuda_header_dir 
    fcuda_header_dir = os.path.join(os.environ['FROOT'], "include")

    benchmark_noc_config = "%s/noc/noc_config.json" % benchmark_dir
    if not os.path.isfile(benchmark_noc_config):
        print "ERROR: Could not find the file noc_config.json of the benchmark."
        print "The specified benchmark is possibly not yet tested"
        sys.exit(1)

    global project_dir
    project_dir = os.path.join(benchmark_dir, 'noc_prj', datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
    os.makedirs(project_dir)

    json_obj = json.load(open(benchmark_noc_config))
    top_level_function = json_obj['top_level_function']
    device_id = json_obj['device_id']

    if 'directory_size' in json_obj and json_obj['directory_size']:
        json_obj['directory_index'] = (json_obj['directory_size'] - 1).bit_length()

    if 'input_file' not in json_obj or \
     not os.path.isfile('%s/sim_data/%s' % (benchmark_dir, json_obj['input_file'])):
        print "ERROR: Could not find input test file."
        sys.exit(1)
    if 'gold_file' not in json_obj or \
     not os.path.isfile('%s/sim_data/%s' % (benchmark_dir, json_obj['gold_file'])):
        print "ERROR: Could not find gold test file."
        sys.exit(1)

    command = "cp -R %s/src %s/prj_files" % (noc_dir, project_dir)
    run_command(command, 1)

    input_file = '%s/sim_data/%s' % (benchmark_dir, json_obj['input_file'])
    gold_file = '%s/sim_data/%s' % (benchmark_dir, json_obj['gold_file'])
    command = "cp %s %s/prj_files" % (input_file, project_dir)
    run_command(command, 1)
    command = "cp %s %s/prj_files" % (gold_file, project_dir)
    run_command(command, 1)

    num_lines = sum(1 for line in open(gold_file))
    json_obj['sim_file_size'] = num_lines
    num_lines = sum(1 for line in open(input_file))
    json_obj['sim_input_file_size'] = num_lines

    json_obj['module_name'] = top_level_function

    # Generate RTL code using FCUDA + Vivado HLS
    fcuda_gen(app)    
    hls_gen(app, top_level_function, device_id)
    
    command = "cp %s/hls/solution1/syn/verilog/* %s/prj_files" % (project_dir, project_dir)
    run_command(command, 1)

    # Parse HLS resource report XML file
    xml_file = "%s/hls/solution1/syn/report/%s_csynth.xml" % (project_dir, top_level_function)
    tree = ET.parse(xml_file)
    root = tree.getroot()

    list_scalar_ports = []
    # assumption: first is Data BRAM, second is corresponding Tag BRAM
    list_bram_ports = []
    data_width = 32
    bram_addr_width = 1
    for child in root.iter('RtlPorts'):
        if child.find('Type').text == 'scalar':
            list_scalar_ports.append(
                (child.find('name').text, 
                child.find('Bits').text))
        if child.find('IOProtocol').text == 'ap_memory':
            if 'address' in child.find('name').text:
                addr_width = int(child.find('Bits').text)
                # find the maximum BRAM size of all shared-BRAM
                if bram_addr_width < addr_width:
                    bram_addr_width = addr_width
            if child.find('Object').text not in list_bram_ports:
                list_bram_ports.append(child.find('Object').text)
        if child.find('name') == 'memport_p0_datain':
            data_width = int(child.find('Bits').text)

    bram_size = 2 ** bram_addr_width
      
    json_obj['scalar_ports'] = []
    for p in list_scalar_ports:
        scalar_details = {}
        scalar_details['name'] = p[0]
        scalar_details['width'] = int(p[1])
        json_obj['scalar_ports'].append(scalar_details)
    json_obj['data_bram_ports'] = []
    count = 0
    for p in list_bram_ports:
        # first is data bram, followed by tag bram
        count = count + 1
        if count % 2 == 0:
            continue
        bram_details = {}
        bram_details['name'] = p
        bram_details['index'] = count / 2
        json_obj['data_bram_ports'].append(bram_details)

    # use the same (maximum) BRAM size for all the shared BRAM for now
    json_obj['bram_addr_width'] = bram_addr_width
    json_obj['bram_size'] = bram_size

    json_obj['data_width'] = data_width

    num_cores = width * height
    json_obj['num_cores'] = num_cores

    json_obj['dest_width'] = (num_cores + 1 + num_cores).bit_length()
    json_obj['router_id_width'] = (num_cores).bit_length()

    # generate the network, including routers, compute nodes, memory controller,
    # also build the routing table to define how a packet traverses from one
    # node to other node.
    N = Network()
    N.buildNetwork(width, height)

    json_obj['router_wires'] = N.buildRoutersLogic()
    json_obj['nodes'] = []
    for node in N.getListNodes():
        node_details = {}
        node_details['id'] = node.getNodeNum()
        node_details['rtables'] = node.getFullRoute('rtables')
        if isinstance(node, Router):
            node_details['type'] = 'router'
            node_details['prtables'] = node.getFullRoute('prtables')
            node_details['commented_prtables'] = node.getCommentRoute('prtables')
            node_details['commented_rtables'] = node.getCommentRoute('rtables')
        elif isinstance(node, Compute):
            node_details['type'] = 'compute'
        elif isinstance(node, Memory):
            node_details['type'] = 'memory'
        json_obj['nodes'].append(node_details)

    template_dir = "%s/prj_files" % project_dir
    template_env = Environment(loader = FileSystemLoader(template_dir))
    template_env.filters['joinpath'] = lambda list: os.path.join(*list)

    list_templates = [
            'wrapper_fcuda_core.v',
            'noc_pkt.vh',
            'gen_network.v',
            'gen_network_tb.v',
            'gen_network_top.v',
            'ddr3_model.v',
            'noc_script.tcl']

    for template_name in list_templates:
        gen_template(template_env, json_obj, template_dir, template_name) 

    command = "cp %s/prj_files/noc_script.tcl %s" % (
            project_dir, project_dir)
    run_command(command, 1)

    command = "cp -R %s/prepareFile_709 %s" % (
            noc_dir, project_dir)
    run_command(command, 1)

    command = "mv %s/prj_files/ddr3_model.v %s/prepareFile_709" % (
            project_dir, project_dir)
    run_command(command, 1)

    vivado_run(sim_flow, syn_flow)

    # Note: only verify integer data for now
    if sim_flow != 0:
        gold_output = []
        i = 0
        for line in open(gold_file):
            gold_output.append(long(line, 16))
        sim_verify(gold_output, json_obj['sim_file_size'])   

if __name__ == "__main__":
    print len(sys.argv)
    if len(sys.argv) < 6:
        print "Insufficient number of argument"
        usage()
        sys.exit(1)

    main(sys.argv)

