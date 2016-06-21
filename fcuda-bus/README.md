#FCUDA Hierarchical - AXI Bus Flow (FCUDA HB)

##Introduction
- This repository contains a script for the automation of the hierarchical
AXI bus generation and testing (simulation + logic synthesis + P & R). 
It invokes the front-end FCUDA C compiler to translate CUDA C kernel to a 
serial C code, followed by RTL generation by Vivado HLS. The script will
launch Vivado Design to instantiate as many generated RTL IPs as stipulated
by a user, and connect them to the memory controller (MIG) via one or
two - level of AXI Interconnect. In addition, the repository also supplements
another script for running Design Space Exploration (DSE) for the Hierarchical
Bus system. The script will profile data to construct resource model, frequency
model, and memory latency model, assisted by a configuration file per benchmark
supplied by user to provide sufficient information to run the benchmark.
Once the models are built, the script will call either binary/exhaustive
search to find the optimal system configuration for a given problem size
of a benchmark.

##Setup & Requirement
- This repository needs the FCUDA compiler repository and the FCUDA 
benchmarks for testing. Please clone the FCUDA repository and follow the 
instructions to set up the entire flow.
- Please ensure that you have python-jinja2 in your system as the Python
script will generate necessary files from jinja template for the project.
- The scripts are tested with Vivado HLS & Vivado Design 2015.3. Please install 
the respective software version before you use the flow.
- At this moment, the flow is tested with the board VC709.

##How to use

- The folder *prepareFile_709/* contains the top level module for simulation, plus
DDR3 model verilog file and other files from Xilinx. They have been lightly
modified to initiate the necessary input data in the DDR3 after DDR3 calibration
is done, so we do not concern about writing another module to initialize data
for simulation.

- The script **gen_hb.py** is used for generating a Hierarchical bus -based system. 
Before using the script, please source the script **env_vars.sh** at the top level
directory (to initialize all the environment variables used by this Python
script) by running the following command `source env_vars.sh`

- The usage of the script **gen_hb.py** is described as below:

```
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
```

- The script will create a timestamp directory located at *{benchmark's
directory}/bus_prj*. Inside this directory, the generated FCUDA C code is put
under *fcuda_gen/*; the HLS project is at *hls/*; and the Vivado project's directory
(either simulation or logic synthesis) is *vivado_prj/*.

- The script reads the JSON file **busconfig.json** located at *{benchmark's
  directory}/bus*. The JSON file defines many essential parameters for
simulation/synthesis. Here is an explanation of the parameters used
in the file.

    + top\_level\_function: the name of the kernel function for HLS.
    + compute\_task: the name of the FCUDA task in the benchmark (after
    FCUDA compilation). User specifies it to assist the script to do profiling 
    on the task.
    + transfer\_task: the name of the FCUDA task in the benchmark (before
    FCUDA compilation). User specifies it to assist the script to do profiling 
    on the task. Note that this task must be overlapped with the chosen compute 
    task by ping-pong buffering optimization. Also, the task does not need
    to be FCUDA TRANSFER type as long as its functionality is to copying data
    from off-chip to on-chip or vice versa.
    + device\_id: the ID of the FPGA platform.  
    + platform\_width: the number of slices of the FPGA platform in x-direction.
    + platform\_height: the number of slices of the FPGA platform in y-direction.
    + platform\_bram\_width: the number of BRAMs of the FPGA platform in x-direction.
    + platform\_bram\_height: the number of BRAMs of the FPGA platform in y-direction.
    + platform\_dsp\_width: the number of DSPs of the FPGA platform in x-direction.
    + platform\_dsp\_height: the number of DSPs of the FPGA platform in y-direction.
    + platform\_ff\_num: the number of Flip-flops of the FPGA platform.
    + platform\_lut\_num: the number of LUTs of the FPGA platform.
    + app\_task\_iter: the number of times that the chosen compute task and transfer
    task execute.
    + app\_threadblock\_num: the number of threadblocks that the benchmark executes.
    + app\_unroll\_max: the maximum threadloop unrolling degree of the benchmark.
    Normally, it equals the thread block size.
    + memport\_data\_type: the datatype of the bus pointer.
    + input\_file & gold\_file: These are the file names of the input file for 
    initializing data and verifying data, respectively. Those files must be put 
    under {benchmark's directory}/sim_data. The files store the content of the memory 
    data before and after kernel's execution and can be generated using the C 
    program in the benchmark's directory.  
    + scalar values: this field provides a list of scalars and their corresponding 
    values for simulation.  To ensure the correctness of the simulation, please 
    try to supply sufficient (and correct!) values for all the scalars used by 
    the benchmark. If you are unsure about which scalar parameter is used by a 
    benchmark, take a look at the interface of the benchmark's CUDA kernel. 
    Normally, besides the existing scalars of a kernel, FCUDA does generate 
    extraneous scalars, specifically:
        + gridDim: grid dimension of a CUDA kernel, will be splitted into 
        gridDim_x, gridDim_y, gridDim_z by Vivado HLS. One must get a sense of how 
        the grid values are calculated based on the block dimensions as well as 
        the size of input/output data to assign correct values. Normally, the 
        information can be found in the main file of a benchmark, or in a function 
        that invokes the CUDA kernel.
        + blockDim: block dimension of a CUDA kernel, will be splitted into 
        blockDim_x, blockDim_y, blockDim_z by Vivado HLS. Normally, these values 
        can be found in a header file or main file of a benchmark.
        + num_cores: the number of FCUDA cores in the design. 
        + core_id: the core's identifier. It is used to distribute the workload 
        (num. thread blocks) among FCUDA cores.
        + {pointer_name}\_addr: to make FCUDA HB function correctly, all the pointers 
        of the CUDA's kernel must be merged into one single port. This is handled 
        automatically by FCUDA C compiler. To differentiate these pointers, an 
        offset {pointer_name}_addr is generated to tell at which location of the 
        address space is the start of a respective pointer. Please note this detail 
        to assign correct values for these offsets.  It also correlates to how we 
        generate input and gold files. For example, if my kernel uses 3 pointers A, 
        B, and C, the size of each pointer is 1024. If I put them all in the 
        consecutive regions, the first 1024 lines of my input/gold files are A's data, 
        the next 1024 lines are B's data, and the rest is C's data. Similarly, A_addr 
        is 0, B_addr is 1024, and C_addr is 2048.

- If a benchmark does not have this **hb_config.json**, it means we have not yet
tested FCUDA HB with that benchmark.  At this moment, FCUDA HB is tested
with benchmarks: *matmul*, *cp*, *dwt*, *fwt*, *hotspot*, *pathfinder*, *lavaMD*.
Note that the FCUDA HB flow is tested with the kernel file  **fcuda_annot_{benchmark's name}_hb.cu** 
in each kernel directory of a benchmark's directory. These are the integer version
of the kernels as we intend to test with integer at this moment.

- The script **run_dse.py** will perform the Design Space Exploration on the
benchmark stipulated by user's input. To use the script, run the following command. 
```
python run_dse.py {benchmark_name}
Example:
  python run_dse.py matmul
```

- The script will generate multiple bus-based system in order to profile data
to build resource model, frequency model, and memory latency model. After
all the necessary data is gathered, the script uses linear regression to find
the coefficients of the respective models. The script thereby loads the template
**_dse.cpp.jinja** to inject all the coefficents into it to generate the CPP
file **dse.cpp**. This file then gets compiled and executed. It performs
exhaustive or binary search on myriads of possible system configurations 
based on the constructed model to find the optimum system configuration.

##References

+ [1] A. Papakonstantinou, Y. Liang, J. Stratton, K. Gururaj, D. Chen, 
W.M. Hwu and J. Cong, "Multilevel Granularity Parallelism Synthesis on 
FPGAs," Proceedings of IEEE International Symposium on Field-Programmable 
Custom Computing Machines, May 2011.

+ [2] Y. Chen, T. Nguyen, Y. Chen, S. T. Gurumani, Y. Liang, K. Rupnow, 
J. Cong, W.M. Hwu, and D. Chen, "FCUDA-HB: Hierarchical and Scalable Bus 
Architecture Generation on FPGAs with the FCUDA Flow," IEEE Transactions 
on Computer-Aided Design of Integrated Circuits and Systems, 2016.
