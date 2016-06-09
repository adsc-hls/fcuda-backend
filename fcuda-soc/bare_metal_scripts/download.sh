#!/bin/bash
app=$1
app_dir=$BENCHMARKS/$app
bitfile=$app_dir/sdk/bsp/design_1_wrapper.bit
ps7_init_file=$app_dir/sdk/bsp/ps7_init.tcl
xmd -tcl test_download.tcl $bitfile $ps7_init_file
