#!/bin/bash
app=$1
app_dir=$BENCHMARKS/$app
mkdir -p $app_dir/sdk/bsp
cp $app_dir/sdk/${app}.hdf $app_dir/sdk/bsp
cd $app_dir/sdk/bsp
#Generate bsp code
hsi -mode batch -source $FCUDA_DIR/fcuda_soc/bare_metal_scripts/gen_bsp.tcl -tclargs $app
#Compile bsp code
make clean
make
