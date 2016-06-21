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

def usage():
    print """
    Usage:
      python gen_bus.py {benchmark_name} {num_cores_per_tile} \
                {unroll_degree} {mpart_degree} {num_tiles_x} \
                {num_tiles_y} {sim_flow} {syn_flow} {frequency} \
                {find_max_f}

      where:
        benchmark_name: the name of the benchmarks for testing
        num_cores_per_tile: number of FCUDA per tile
        unroll_degree: degree of thread-loop unrolling
        mpart_degree: degree of memory (CUDA shared memory) partition
        num_tiles_x: number of FCUDA tiles in x direction
        num_tiles_y: number of FCUDA tiles in y direction
            therefore, total number of FCUDA cores = 
                    num_cores_per_tile * num_tiles_x * num_tiles_y
        sim_flow: simulation flow
            0 - no simulation
            1 - run Simulation with MIG + DDR3 
        syn_flow: synthesis flow
            0 - no synthesis
            1 - run Synthesis + P & R

        frequency: frequency for the Bus system (note: not MIG's frequency)
        find_max_f: reiterate synthesis flow to find maximum
            achievable frequency (if set to 1)
    Example:
        python gen_bus.py matmul 2 2 1 2 2 1 1 5 0
    """

def run_command(command, is_exit):
    process = subprocess.Popen([command], shell=True)
    out, err = process.communicate()
    if process.returncode != 0:
        print "Error: " + command
        print out, err
        if is_exit:
            sys.exit(1)

class Bus_design(object):
    def __init__(self, app, num_cores_per_tile, unroll_degree, mpart_degree, 
                    num_tiles_x, num_tiles_y, frequency):
        self.app = app
        self.num_cores_per_tile = num_cores_per_tile
        self.unroll_degree = unroll_degree
        self.mpart_degree = mpart_degree
        self.num_tiles_x = num_tiles_x
        self.num_tiles_y = num_tiles_y
        self.num_tiles = num_tiles_x * num_tiles_y

        self.frequency = frequency

        # Get path from env_vars.sh. Make sure to "source env_vars.sh" before using this script.
        self.benchmark_dir = os.path.join(os.environ['BENCHMARKS'], self.app)
        self.fcuda_header_dir = os.path.join(os.environ['FROOT'], "include")
        self.bus_dir = os.path.join(os.environ['BUS_DIR'])

        self.benchmark_bus_config = "%s/bus/bus_config.json" % self.benchmark_dir
        if not os.path.isfile(self.benchmark_bus_config):
            print "ERROR: Could not find the file bus_config.json of the benchmark."
            print "The specified benchmark is possibly not yet tested"
            sys.exit(1)

        self.project_dir = os.path.join(
                self.benchmark_dir, 'bus_prj', datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
        os.makedirs(self.project_dir)

        self.json_obj = json.load(open(self.benchmark_bus_config))
        
        if 'input_file' not in self.json_obj or \
          not os.path.isfile('%s/sim_data/%s' % (self.benchmark_dir, self.json_obj['input_file'])):
            print "ERROR: Could not find input test file."
            sys.exit(1)

        if 'gold_file' not in self.json_obj or \
          not os.path.isfile('%s/sim_data/%s' % (self.benchmark_dir, self.json_obj['gold_file'])):
            print "ERROR: Could not find gold test file."
            sys.exit(1)

        command = "cp -R %s/src %s/prj_files" % (self.bus_dir, self.project_dir)
        run_command(command, 1)

        self.input_file = '%s/sim_data/%s' % (self.benchmark_dir, self.json_obj['input_file'])
        self.gold_file = '%s/sim_data/%s' % (self.benchmark_dir, self.json_obj['gold_file'])
        command = "cp %s %s/prj_files" % (self.input_file, self.project_dir)
        run_command(command, 1)
        command = "cp %s %s/prj_files" % (self.gold_file, self.project_dir)
        run_command(command, 1)

        num_lines = sum(1 for line in open(self.gold_file))
        self.json_obj['sim_file_size'] = num_lines
        num_lines = sum(1 for line in open(self.input_file))
        self.json_obj['sim_input_file_size'] = num_lines

        self.template_dir = "%s/prj_files" % self.project_dir
        self.template_env = Environment(loader = FileSystemLoader(self.template_dir))
        self.template_env.filters['joinpath'] = lambda list: os.path.join(*list)

        self.json_obj['total_num_cores'] = self.num_cores_per_tile * self.num_tiles
        self.json_obj['num_tiles'] = self.num_tiles
        self.json_obj['num_tiles_x'] = self.num_tiles_x
        self.json_obj['num_tiles_y'] = self.num_tiles_y
        self.json_obj['num_slices_per_tile_x'] = self.json_obj['platform_width'] / self.num_tiles_x
        self.json_obj['num_slices_per_tile_y'] = self.json_obj['platform_height'] / self.num_tiles_y
        self.json_obj['frequency']  = self.frequency

        self.lut_count = 0
        self.ff_count = 0
        self.slice_count = 0
        self.bram_count = 0
        self.dsp_count = 0
        self.slack_value = -1

        self.compute_lat = 0
        self.transfer_lat = 0

    def get_lut_count(self):
        return self.lut_count

    def get_ff_count(self):
        return self.ff_count

    def get_slice_count(self):
        return self.slice_count

    def get_bram_count(self):
        return self.bram_count

    def get_dsp_count(self):
        return self.dsp_count

    def get_frequency(self):
        return self.frequency

    def get_slack_value(self):
        return self.slack_value

    def fcuda_gen(self, profile_transfer_task):
        print "CUDA-to-C translation"

        tf = tempfile.NamedTemporaryFile()
        kernel_file = open(os.path.join(
            self.benchmark_dir, "kernel/fcuda_annot_%s_hb.cu" % self.app), 'r')
        for line in kernel_file:
            if "pragma FCUDA COMPUTE" in line or "pragma FCUDA TRANSFER" in line:
                new_line_u = re.sub("unroll=[0-9]*", "unroll=%d" % (self.unroll_degree), line)
                new_line_u_m = re.sub("mpart=[0-9]*", "mpart=%d" % (self.mpart_degree), new_line_u)

                if profile_transfer_task == 1:
                    if "name=%s" % (self.json_obj['transfer_task']) in new_line_u_m:
                        if "disable=" in line:
                            new_line = re.sub("disable=yes", "disable=no", new_line_u_m)
                        else:
                            new_line = "%s disable=no\n" % new_line_u_m[:-1]
                    else:
                        if "disable=" in line:
                            new_line = re.sub("disable=no", "disable=yes", new_line_u_m)
                        else:
                            new_line = "%s disable=yes\n" % new_line_u_m[:-1]
                else:
                    new_line = new_line_u_m
                tf.write(new_line)
            elif "pragma FCUDA COREINFO" in line:
                new_line = re.sub("pipeline=no", "pipeline=yes", line)
                tf.write(new_line)
            else:
                tf.write(line)

        tf.flush()

        os.chdir(self.benchmark_dir)
        command = "fcuda %s -param_core > log_fcuda.cu 2>&1" % (tf.name)
        run_command(command, 1)
        
        command = "mkdir -p %s/fcuda_gen" % self.project_dir
        run_command(command, 1)
        tmp =  os.path.split(tf.name)
        command = "cp %s/%s/%s %s/fcuda_gen/fcuda_gen_%s.c" % (
                tmp[0], "fcuda_output", tmp[1], self.project_dir, self.app)
        run_command(command, 1)

        tf.close()
        
    def hls_gen(self):
        print "Vivado HLS C-to-RTL IP translation"
        os.chdir(self.project_dir)

        tf = tempfile.NamedTemporaryFile()
        tcl_script = """
            open_project -reset hls
            set_top %s

            add_files -cflags "-I%s -I%s" fcuda_gen/fcuda_gen_%s.c

            open_solution -reset "solution1"

            set_part {%s}

            create_clock -period 10 -name default
            csynth_design
            export_design
            exit""" % (self.json_obj['top_level_function'], self.fcuda_header_dir,
                        self.benchmark_dir, self.app,
                        self.json_obj['device_id'])

        tf.write(tcl_script)
        tf.flush()
        command = "vivado_hls %s" % (tf.name)
        run_command(command, 1)
        tf.close()

    def profile_compute_task(self):
        tf_fixed = tempfile.NamedTemporaryFile()
        gen_c_file = open("%s/fcuda_gen/fcuda_gen_%s.c" % (self.project_dir, self.app), 'r')
        self.json_obj['list_arguments'] = []
        for line in gen_c_file:
            new_line = line.replace("#pragma HLS interface ap_bus port=memport_p0", 
                    "#pragma HLS interface ap_bus port=memport_p0 depth=%s" % self.json_obj['sim_file_size'])
            tf_fixed.write(new_line)

            # parse the function interface to obtain information about arguments
            if "void %s(" % (self.json_obj['top_level_function']) in line:
                m = line.split('(')[1].split(')')[0]
                list_arguments = m.split(',')
                for arg_decl in list_arguments:
                    arg = arg_decl.strip().split(' ')
                    arg_type = arg[0]
                    arg_name = arg[1]
                    # probably pointer
                    if arg[1] == "*":
                        arg_name = arg[2]
                    self.json_obj['list_arguments'].append(
                            {"type": arg_type, "name": arg_name})
                    

        tf_fixed.flush()
        command = "cp %s %s/fcuda_gen/fcuda_gen_%s.c" % (
                tf_fixed.name, self.project_dir, self.app)
        run_command(command, 1)
        tf_fixed.close()

        self.gen_template("testbench.c") 

        os.chdir(self.project_dir)

        tf_compute = tempfile.NamedTemporaryFile()
        tcl_script = """
            open_project hls
            set_top %s

            add_files -cflags "-I%s -I%s" fcuda_gen/fcuda_gen_%s.c
            add_files -tb -cflags "-I%s -I%s" prj_files/testbench.c
            add_files -tb %s

            open_solution -reset "solution2"

            set_part {%s}

            create_clock -period 10 -name default
            csim_design
            csynth_design
            cosim_design -trace_level none -rtl verilog -tool xsim
            exit""" % ("%s" % (self.json_obj['compute_task']), 
                        self.fcuda_header_dir, self.benchmark_dir, 
                        self.app,
                        self.fcuda_header_dir, self.benchmark_dir,
                        self.gold_file,
                        self.json_obj['device_id'])

        tf_compute.write(tcl_script)
        tf_compute.flush()
        command = "vivado_hls %s" % (tf_compute.name)
        run_command(command, 1)
        tf_compute.close()

        latency_report = open("%s/hls/solution2/sim/report/verilog/lat.rpt" % (self.project_dir), 'r')
        for line in latency_report:
            m = line.split('=')
            print m[0].strip(), m[1].strip()
            if "MAX_LATENCY" in m[0]:
                lat_str = m[1].strip()
                self.compute_lat = int(lat_str[1:-1])
                break
        print "Compute Latency", self.compute_lat

    def gen_template(self, template_name):
        template = self.template_env.get_template('_%s.jinja' % template_name)
        f = open('%s/%s' % (self.template_dir, template_name), 'w')
        f.write(template.render(self.json_obj))
        f.close()

    def vivado_prj_setup(self):
        # Parse HLS resource report XML file
        xml_file = "%s/hls/solution1/syn/report/%s_csynth.xml" % (
                self.project_dir, self.json_obj['top_level_function'])
        tree = ET.parse(xml_file)
        root = tree.getroot()

        data_width = 32
        for child in root.iter('RtlPorts'):
            if child.find('name') == 'memport_p0_datain':
                data_width = int(child.find('Bits').text)

        self.json_obj['data_width'] = data_width

        list_templates = [
                'const.xdc',
                'ddr3_model.v',
                'hb_script.tcl']

        for template_name in list_templates:
            self.gen_template(template_name) 

        command = "cp %s/prj_files/hb_script.tcl %s" % (
                self.project_dir, self.project_dir)
        run_command(command, 1)

        command = "cp -R %s/prepareFile_709 %s" % (
                self.bus_dir, self.project_dir)
        run_command(command, 1)

        command = "cp %s/prj_files/const.xdc %s/prepareFile_709" % (
                self.project_dir, self.project_dir)
        run_command(command, 1)

        command = "cp %s/prj_files/ddr3_model.v %s/prepareFile_709" % (
                self.project_dir, self.project_dir)
        run_command(command, 1)


    def vivado_run(self, is_already_run, sim_flow, syn_flow):
        os.chdir(self.project_dir)

        total_num_cores = self.num_cores_per_tile * self.num_tiles

        command = "vivado -mode batch -source hb_script.tcl -tclargs\
                vivado_prj %s %s %s %s %s %s" % \
                (self.json_obj['top_level_function'], total_num_cores, 
                self.num_tiles, sim_flow, syn_flow,
                is_already_run)
        run_command(command, 1)

    def get_resource_info(self):
        rpt_file = "%s/vivado_prj/report/post_place_packthru_report.rpt" % self.project_dir
        if not os.path.isfile(rpt_file):
            print "ERROR: Could not find the report file."
            print "Probably synthesis flow has not started or not finished yet."
            sys.exit(1)

        from_rpt = open(rpt_file, 'r')

        for line in from_rpt:
            m = re.split('\|', line)
            if len(m) > 3:
                if "Slice" == m[1].strip():
                    self.slice_count = float(m[2])
                if "Slice LUTs" == m[1].strip():
                    self.lut_count = float(m[2])
                if "Slice Registers" == m[1].strip():
                    self.ff_count = float(m[2])
                if "Block RAM Tile" == m[1].strip():
                    self.bram_count = float(m[2])
                if "DSPs" == m[1].strip():
                    self.dsp_count = float(m[2])

        from_rpt.close()

        rpt_file = "%s/vivado_prj/report/post_route_timing.rpt" % self.project_dir
        if not os.path.isfile(rpt_file):
            print "ERROR: Could not find the report file."
            print "Probably synthesis flow has not yet finished."
            sys.exit(1)

        from_rpt = open(rpt_file, 'r')

        for line in from_rpt:
            m = re.split(' ', " ".join(line.split()))
            if len(m) == 2 and m[0] == "slack":
                self.slack_value = float(m[1])

        from_rpt.close()

    def find_max_freq(self):
        # accept frequency value if the slack is within (0, 0.2)
        # note: this is worst negative setup slack
        if self.slack_value >= 0 and self.slack_value < 0.2:
            return True
        else:
            self.frequency = self.frequency - self.slack_value
        
        # generate constraint file again with new frequency value
        self.json_obj['frequency'] = self.frequency
        print "New Frequency", self.frequency
        self.gen_template('const.xdc') 
        command = "cp %s/prj_files/const.xdc %s/prepareFile_709" % (
                self.project_dir, self.project_dir)
        run_command(command, 1)

        # run Synthesis again, but open the existing project
        # to run with new frequency instead of creating 
        # a new one to save time
        self.vivado_run(1, 0, 1)
        self.get_resource_info()

        return False

    # Profiling compute task
    def get_compute_latency(self):
        self.fcuda_gen(0)
        self.profile_compute_task()
        return self.compute_lat

    # Profiling transfer task
    def get_transfer_latency(self):
        self.fcuda_gen(1)
        self.hls_gen()

        # make all the cores run only once to save time
        for scalar in self.json_obj["scalar_values"]:
            if scalar["name"] == "gridDim_x":
                scalar["value"] = self.num_cores_per_tile * self.num_tiles
            if scalar["name"] == "gridDim_y":
                scalar["value"] = 1
            if scalar["name"] == "gridDim_z":
                scalar["value"] = 1
        
        self.vivado_prj_setup()

        # only run simulation
        self.vivado_run(0, 1, 0)
        
        # get latency result from log file
        vivado_log_file = open("%s/vivado.log" % self.project_dir, 'r')
        for line in vivado_log_file:
            if "FINAL_LATENCY" in line:
                m = line.split('=')
                self.transfer_lat = int(m[1].strip())

        return self.transfer_lat

    def gen_design(self, sim_flow, syn_flow, find_max_f):
        # Generate RTL code using FCUDA + Vivado HLS
        self.fcuda_gen(0)
        self.hls_gen()

        self.vivado_prj_setup()

        self.vivado_run(0, sim_flow, syn_flow)
        if syn_flow == 1:
            self.get_resource_info()

        if find_max_f == 1:
            while self.find_max_freq() is False:
                pass

def main(argv):
    try:
        app = argv[1]
        num_cores_per_tile = int(argv[2])
        unroll_degree = int(argv[3])
        mpart_degree = int(argv[4])
        num_tiles_x = int(argv[5])
        num_tiles_y = int(argv[6])
        # sim_flow: 0 -- no simulation, 1 -- run Simulation with MIG + DDR3, 
        sim_flow = int(argv[7])
        # syn_flow: 0 -- no Sythesis, 1 -- run Synthesis + P & R
        syn_flow = int(argv[8])

        frequency = float(argv[9])
        find_max_f = int(argv[10])
    except:
        print "Error:", sys.exc_info()
        usage()
        sys.exit(1)

    bus_obj = Bus_design(
            app = app,
            num_cores_per_tile = num_cores_per_tile,
            unroll_degree = unroll_degree,
            mpart_degree = mpart_degree,
            num_tiles_x = num_tiles_x,
            num_tiles_y = num_tiles_y,
            frequency = frequency)

    #bus_obj.gen_design(sim_flow, syn_flow, find_max_f)
    compute_lat = 0
    transfer_lat = 0
    compute_lat = bus_obj.get_compute_latency()
    #transfer_lat = bus_obj.get_transfer_latency()

    print "lut ", bus_obj.get_lut_count()
    print "ff ", bus_obj.get_ff_count()
    print "slice ", bus_obj.get_slice_count()
    print "bram ", bus_obj.get_bram_count()
    print "dsp ", bus_obj.get_dsp_count()
    print "slack ", bus_obj.get_slack_value()
    print "frequency", bus_obj.get_frequency()
    print "compute latency", compute_lat
    print "transfer latency", transfer_lat

if __name__ == "__main__":
    print len(sys.argv)
    if len(sys.argv) < 10:
        print "Insufficient number of argument"
        usage()
        sys.exit(1)

    main(sys.argv)

