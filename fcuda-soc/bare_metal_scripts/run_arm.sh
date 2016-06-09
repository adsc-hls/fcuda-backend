#!/bin/bash
app=$1
app_dir=$BENCHMARKS/$app
wait_time=$2 #1000: 1 second
cd $app_dir/sdk/app
make clean
make
elf_file=$app_dir/sdk/app/${app}.elf
tcl_file=$FCUDA_DIR/fcuda_soc/bare_metal_scripts/test_arm.tcl
xmd -tcl $tcl_file ${elf_file} ${wait_time}
