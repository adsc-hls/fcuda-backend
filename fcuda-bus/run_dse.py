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
from sklearn import linear_model
import operator
import math
from multiprocessing import Process

from gen_hb import Bus_design

def usage():
    print """
    Usage:
      python run_dse.py {benchmark_name}
    Example:
        python run_dse.py matmul
    """

def run_command(command, is_exit):
    process = subprocess.Popen([command], shell=True)
    out, err = process.communicate()
    if process.returncode != 0:
        print "Error: " + command
        print out, err
        if is_exit:
            sys.exit(1)


#num_cores_per_tile, unroll_degree, mpart_degree, num_tiles 
configs = [
[1, 1, 1, 1],
[1, 2, 1, 1],
[1, 2, 2, 1],
[1, 4, 1, 1],
[1, 4, 2, 1],
[1, 4, 4, 1],
[1, 8, 1, 1],
[1, 8, 2, 1],
[1, 8, 4, 1],
[1, 8, 8, 1],
[1, 16, 1, 1],
[1, 16, 2, 1],
[1, 16, 4, 1],
[1, 16, 8, 1],
[1, 16, 16, 1],
[2, 1, 1, 1],
[4, 1, 1, 1],
[8, 1, 1, 1],
[16, 1, 1, 1],
[10, 1, 1, 2]]

weights = [ 
[ 1, 1, 1, 1, 1, 1],
[ 1, 1, 2, 1, 2, 1],
[ 1, 1, 2, 2, 4, 1],
[ 1, 1, 4, 1, 4, 1],
[ 1, 1, 4, 2, 8, 1],
[ 1, 1, 4, 4, 16, 1],
[ 1, 1, 8, 1, 8, 1],
[ 1, 1, 8, 2, 16, 1],
[ 1, 1, 8, 4, 32, 1],
[ 1, 1, 8, 8, 64, 1],
[ 1, 1, 16, 1, 16, 1],
[ 1, 1, 16, 2, 32, 1],
[ 1, 1, 16, 4, 64, 1],
[ 1, 1, 16, 8, 128, 1],
[ 1, 1, 16, 16, 256, 1], 
[ 1, 2, 2, 2, 1, 1],
[ 1, 4, 4, 4, 1, 1],
[ 1, 8, 8, 8, 1, 1],
[ 1, 16, 16, 16, 1, 1],
[ 2, 20, 20, 20, 2, 1]]

# Resource consumption of an AXI Interconnect
# AXI_TILE (Level 1)
yaxi_slice = [       
218,
683,
908,
1030,
1250,
1430,
1681,
1856,
2012,
2181,
2374,
2546,
2697,
2967,
3120,
3348]

yaxi_lut = [       
282,
1082,
1469,
1773,
2257,
2579,
3113,
3435,
3854,
4243,
4725,
5098,
5326,
5977,
6334,
6766]

yaxi_ff = [       
651,
2071,
2667,
3249,
3845,
4427,
5015,
5597,
6187,
6769,
7325,
7933,
8519,
9112,
9695,
10273]

yaxi_bram = [       
1.5,
4.5,
5,
5.5,
6,
6.5,
7,
7.5,
8,
8.5,
9,
9.5,
10,
10.5,
11,
11.5]

yaxi_dsp = [       
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0]

# AXI_TOP (Level 1)
yaxi_top_slice = [       
207,
1003,
1148,
1345,
1539,
1723,
1958,
2080,
2279,
2538,
2695,
2873,
3018,
3234,
3403,
3674]

yaxi_top_lut = [       
282,
1422,
1808,
2112,
2596,
2919,
3452,
3775,
4191,
4580,
5071,
5436,
5665,
6312,
6673,
7104]

yaxi_top_ff = [       
651,
2998,
3600,
4182,
4784,
5366,
5954,
6536,
7132,
7714,
8310,
8878,
9464,
10057,
10640,
11218]

yaxi_top_bram = [       
1.5,
4.5,
5,
5.5,
6,
6.5,
7,
7.5,
8,
8.5,
9,
9.5,
10,
10.5,
11,
11.5]

yaxi_top_dsp = [       
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0]

axi_slice = [
yaxi_top_slice[1 - 1],
yaxi_top_slice[1 - 1],
yaxi_top_slice[1 - 1],
yaxi_top_slice[1 - 1],
yaxi_top_slice[1 - 1],
yaxi_top_slice[1 - 1],
yaxi_top_slice[1 - 1],
yaxi_top_slice[1 - 1],
yaxi_top_slice[1 - 1],
yaxi_top_slice[1 - 1],
yaxi_top_slice[1 - 1],
yaxi_top_slice[1 - 1],
yaxi_top_slice[1 - 1],
yaxi_top_slice[1 - 1],
yaxi_top_slice[1 - 1],
yaxi_top_slice[2 - 1],
yaxi_top_slice[4 - 1],
yaxi_top_slice[8 - 1],
yaxi_top_slice[16 - 1],
yaxi_slice[10 - 1] * 2 + yaxi_top_slice[2 - 1]
]

axi_lut = [
yaxi_top_lut[1 - 1],
yaxi_top_lut[1 - 1],
yaxi_top_lut[1 - 1],
yaxi_top_lut[1 - 1],
yaxi_top_lut[1 - 1],
yaxi_top_lut[1 - 1],
yaxi_top_lut[1 - 1],
yaxi_top_lut[1 - 1],
yaxi_top_lut[1 - 1],
yaxi_top_lut[1 - 1],
yaxi_top_lut[1 - 1],
yaxi_top_lut[1 - 1],
yaxi_top_lut[1 - 1],
yaxi_top_lut[1 - 1],
yaxi_top_lut[1 - 1],
yaxi_top_lut[2 - 1],
yaxi_top_lut[4 - 1],
yaxi_top_lut[8 - 1],
yaxi_top_lut[16 - 1],
yaxi_lut[10 - 1] * 2 + yaxi_top_lut[2 - 1]
]

axi_ff = [
yaxi_top_ff[1 - 1],
yaxi_top_ff[1 - 1],
yaxi_top_ff[1 - 1],
yaxi_top_ff[1 - 1],
yaxi_top_ff[1 - 1],
yaxi_top_ff[1 - 1],
yaxi_top_ff[1 - 1],
yaxi_top_ff[1 - 1],
yaxi_top_ff[1 - 1],
yaxi_top_ff[1 - 1],
yaxi_top_ff[1 - 1],
yaxi_top_ff[1 - 1],
yaxi_top_ff[1 - 1],
yaxi_top_ff[1 - 1],
yaxi_top_ff[1 - 1],
yaxi_top_ff[2 - 1],
yaxi_top_ff[4 - 1],
yaxi_top_ff[8 - 1],
yaxi_top_ff[16 - 1],
yaxi_ff[10 - 1] * 2 + yaxi_top_ff[2 - 1]
]

axi_bram = [
yaxi_top_bram[1 - 1],
yaxi_top_bram[1 - 1],
yaxi_top_bram[1 - 1],
yaxi_top_bram[1 - 1],
yaxi_top_bram[1 - 1],
yaxi_top_bram[1 - 1],
yaxi_top_bram[1 - 1],
yaxi_top_bram[1 - 1],
yaxi_top_bram[1 - 1],
yaxi_top_bram[1 - 1],
yaxi_top_bram[1 - 1],
yaxi_top_bram[1 - 1],
yaxi_top_bram[1 - 1],
yaxi_top_bram[1 - 1],
yaxi_top_bram[1 - 1],
yaxi_top_bram[2 - 1],
yaxi_top_bram[4 - 1],
yaxi_top_bram[8 - 1],
yaxi_top_bram[16 - 1],
yaxi_bram[10 - 1] * 2 + yaxi_top_bram[2 - 1]
]

axi_dsp = [
yaxi_top_dsp[1 - 1],
yaxi_top_dsp[1 - 1],
yaxi_top_dsp[1 - 1],
yaxi_top_dsp[1 - 1],
yaxi_top_dsp[1 - 1],
yaxi_top_dsp[1 - 1],
yaxi_top_dsp[1 - 1],
yaxi_top_dsp[1 - 1],
yaxi_top_dsp[1 - 1],
yaxi_top_dsp[1 - 1],
yaxi_top_dsp[1 - 1],
yaxi_top_dsp[1 - 1],
yaxi_top_dsp[1 - 1],
yaxi_top_dsp[1 - 1],
yaxi_top_dsp[1 - 1],
yaxi_top_dsp[2 - 1],
yaxi_top_dsp[4 - 1],
yaxi_top_dsp[8 - 1],
yaxi_top_dsp[16 - 1],
yaxi_dsp[10 - 1] * 2 + yaxi_top_dsp[2 - 1]
]
# Frequency model
# num_cores_per_tile, unroll_degree, mpart_degree, num_tiles_x, num_tiles_y
configs_freq = [
[1, 1, 1, 1, 1],
[1, 2, 1, 1, 1],
[1, 2, 2, 1, 1],
[2, 1, 1, 2, 1],
[2, 1, 1, 1, 2],
[2, 1, 1, 2, 2],
[2, 2, 1, 2, 2],
[2, 2, 2, 2, 2]
]

# Memory latency model
# num_cores_per_tile, num_tiles
configs_mem = [
[1, 1],
[2, 1],
[4, 1],
[6, 1],
[8, 1],
[10, 1],
[12, 1],
[14, 1],
[16, 1],
[5, 4],
[6, 4],
[7, 4],
[8, 4],
[16, 4]
]

weights_mem = [
[1, 1, 0, 0],
[1, 2, 0, 0],
[1, 4, 0, 0],
[1, 6, 0, 0],
[1, 8, 0, 0],
[1, 10, 0, 0],
[1, 12, 0, 0],
[1, 14, 0, 0],
[1, 16, 0, 0],
[1, 5, 4, 4 * 5],
[1, 6, 4, 4 * 6],
[1, 7, 4, 4 * 7],
[1, 8, 4, 4 * 8],
[1, 16, 4, 4 * 16]
]

# Create linear regression object
regr = linear_model.LinearRegression(fit_intercept=False)

def linear_regression(profile_data, weights):
    regr.fit(weights, profile_data)
    return regr.coef_

def get_cluster_slices_count_from_model(coeffs, num_cores_per_tile,
        unroll_degree, mpart_degree):
    return coeffs[0] + coeffs[1] * num_cores_per_tile +\
        coeffs[2] * num_cores_per_tile * unroll_degree +\
        coeffs[3] * num_cores_per_tile * mpart_degree +\
        coeffs[4] * unroll_degree * mpart_degree +\
        yaxi_slice[num_cores_per_tile]

def gen_template(template_env, template_dir, template_name, json_obj):
    template = template_env.get_template('_%s.jinja' % template_name)
    f = open('%s/%s' % (template_dir, template_name), 'w')
    f.write(template.render(json_obj))
    f.close()

def profile_resource(app, configs, list_slices,
        list_lut, list_ff, list_bram, list_dsp):

    for cf in configs:
        print cf
        bus_obj = Bus_design(
                    app = app,
                    num_cores_per_tile = cf[0],
                    unroll_degree = cf[1],
                    mpart_degree = cf[2],
                    num_tiles_x = 1,
                    num_tiles_y = cf[3],
                    frequency = 5)
        # run Synthesis only (and no need to find f_max)
        bus_obj.gen_design(0, 1, 0)

        list_slices.append(bus_obj.get_slice_count())
        list_lut.append(bus_obj.get_lut_count())
        list_ff.append(bus_obj.get_ff_count())
        list_dsp.append(bus_obj.get_dsp_count())
        list_bram.append(bus_obj.get_bram_count())

        print "SLICES", bus_obj.get_slice_count() 
        print "LUT", bus_obj.get_lut_count()
        print "FF", bus_obj.get_ff_count()
        print "DSP", bus_obj.get_dsp_count()
        print "BRAM", bus_obj.get_bram_count()

def profile_mem_latency(app, configs, list_mem_lat, task_iter):

    for cf in configs:
        print cf
        bus_obj = Bus_design(
                app = app,
                num_cores_per_tile = cf[0],
                unroll_degree = 1,
                mpart_degree = 1,
                num_tiles_x = 1,
                num_tiles_y = cf[1],
                frequency = 5)
        mem_lat = bus_obj.get_transfer_latency() / task_iter
        list_mem_lat.append(mem_lat)
        print "MEM_LAT", mem_lat

def profile_frequency(app, configs, list_frequency):

    for cf in configs:
        print cf
        bus_obj = Bus_design(
                app = app,
                num_cores_per_tile = cf[0],
                unroll_degree = cf[1],
                mpart_degree = cf[2],
                num_tiles_x = cf[3],
                num_tiles_y = cf[4],
                frequency = 5)
        bus_obj.gen_design(0, 1, 1)
        print "SLACK", bus_obj.get_slack_value()
        print "FREQUENCY", bus_obj.get_frequency()
        list_frequency.append(bus_obj.get_frequency())

def main(argv):
    app = argv[1]

    # Examples
    slices_coeff = [-243.4, 657.7, 0.8, 79.7, 5.5, 5811.3]
    lut_coeff = [2780, 2425, -3, 226, 16, 13112]
    ff_coeff = [3294.5, 2295.2, 21.4, 231.3, 11.3, 9797.4]
    bram_coeff = [11.9021, 1.8387, 0.4074, 2.3107, -0.1496, -12.6417]
    dsp_coeff = [0.3380, 11.1628, 1.1667, 5.6148, 0.1117, 0.2142]
    freq_coeff = [4.7559, -0.0072, 2.6177, 0.0300, 0.0802]
    mem_coeff = [1629.6, 127.8, 193.7]
    

    bus_dir = os.path.join(os.environ['BUS_DIR'])
    benchmark_dir = os.path.join(os.environ['BENCHMARKS'], app)
    benchmark_bus_config = "%s/bus/bus_config.json" % benchmark_dir
    if not os.path.isfile(benchmark_bus_config):
        print "ERROR: Could not find the file bus_config.json of the benchmark."
        print "The specified benchmark is possibly not yet tested"
        sys.exit(1)

    json_obj = json.load(open(benchmark_bus_config))

    dse_dir = os.path.join(benchmark_dir, "dse", 
            datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
    os.makedirs(dse_dir)
    command = "cp -R %s/* %s" % (bus_dir, dse_dir)
    run_command(command, 1)

    # profile resource
    list_slices = []
    list_lut = []
    list_ff = []
    list_dsp = []
    list_bram = []
    p1 = Process(target=profile_resource(app, configs, list_slices, 
            list_lut, list_ff, list_dsp, list_bram))
    p1.start()
    
    # profile memory latency
    list_mem_lat = []
    p2 = Process(target=profile_mem_latency(
        app, configs_mem, list_mem_lat, json_obj["app_task_iter"]))
    p2.start()

    # profile frequency
    list_frequency = []
    p3 = Process(target=profile_frequency(app, configs_freq, list_frequency))
    p3.start()

    p1.join()
    p2.join()
    p3.join()

    slices_coeff = linear_regression(map(operator.sub, list_slices, axi_slice), weights)
    lut_coeff = linear_regression(map(operator.sub, list_lut, axi_lut), weights)
    ff_coeff = linear_regression(map(operator.sub, list_ff, axi_ff), weights)
    dsp_coeff = linear_regression(map(operator.sub, list_bram, axi_bram), weights)
    bram_coeff = linear_regression(map(operator.sub, list_dsp, axi_dsp), weights)
    mem_coeff = linear_regression(list_mem_lat, weights_mem)

    weights_freq = []
    for cf in configs_freq:
        cluster_slices = get_cluster_slices_count_from_model(
                slices_coeff, 
                cf[0], cf[1], cf[2])
        dim_x = json_obj['platform_width'] / cf[3]
        dim_y = json_obj['platform_height'] / cf[4]
        min_dim = min(dim_x, dim_y)
        if cluster_slices <= min_dim * min_dim:
            diag = math.sqrt(2 * cluster_slices)
        else:
            diag = math.sqrt(min_dim * min_dim + 
                    (cluster_slices / min_dim) * (cluster_slices / min_dim))
        util = cluster_slices / (dim_x * dim_y)
        # constant, Diag, Util, Unroll, Mpart
        weights_freq.append([1, diag, util, cf[1], cf[2]])

    print "Frequency model's weights", weights_freq
    freq_coeff = linear_regression(list_frequency, weights_freq)
    
    print "SLICES coeffs", slices_coeff
    print "LUT coeffs", lut_coeff
    print "FF coeffs", ff_coeff
    print "DSP coeffs", dsp_coeff
    print "BRAM coeffs", bram_coeff
    print "Frequency coeffs", freq_coeff
    print "Memory latency coeffs", mem_coeff
    
    json_obj['slices_coeffs'] = slices_coeff
    json_obj['lut_coeffs'] = lut_coeff
    json_obj['ff_coeffs'] = ff_coeff
    json_obj['dsp_coeffs'] = dsp_coeff
    json_obj['bram_coeffs'] = bram_coeff
    json_obj['freq_coeffs'] = freq_coeff
    json_obj['mem_coeffs'] = mem_coeff
    json_obj['app'] = app

    # Generate a program from an existing DSE template
    # Inject all the coefficents for the models computed here
    # to the template.
    # This program will examine all the possible configurations
    # and will invoke exhaustive search / binary search to find
    # the optimal configuration
    template_env = Environment(loader = FileSystemLoader(dse_dir))
    template_env.filters['joinpath'] = lambda list: os.path.join(*list)

    gen_template(template_env, dse_dir, "dse.cpp", json_obj)
    os.chdir(dse_dir)
    command = "g++ dse.cpp -o dse.exe"
    run_command(command, 1)
    command = "./dse.exe"
    run_command(command, 1)

if __name__ == "__main__":
    print len(sys.argv)
    if len(sys.argv) < 2:
        print "Insufficient number of argument"
        usage()
        sys.exit(1)

    main(sys.argv)

