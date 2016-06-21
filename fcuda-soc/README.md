#FCUDA Sytem-on-Chip flow (FCUDA SOC)

##Introduction
- This repository contains scripts for the automation of the FCUDA SoC platform. It calls the CUDA-to-C
compiler to compile CUDA code to C. The C code will then pass to Vivado High Level Synthesis (Xilinx) to
generate RTL IP. The scripts will generate the Vivado Block Design which one or more FCUDA cores are connected
to the Zynq Processing System, and will generate a bitstream to configure an FPGA at the end.
##Setup & Requirement
- This repository needs the FCUDA compiler repository and the FCUDA benchmarks for testing. Please clone the 
FCUDA repository and follow the instructions to set up the entire flow.
- The scripts are tested with Vivado version 2015.3 and Vivado HLS version 2015.4. Please install the
respective software version before you use the flow.
- At this moment, the flows are tested with the platform XC7Z020 and XC7Z045.

##How to use
- The file *gen_platform.py* is a Python script which automates the whole flow: CUDA-to-C, HLS translation,
and Vivado System Integration and will run until a bitstream is generated. It invokes the TCL script 
*run_vivado_wrapper.tcl* to perform the system integration in Vivado. The usage of the script is

```
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
```

- The input to the script includes the platform ID (at this moment, either 7z020 or 7z045), the name of the
benchmark, the frequency divisor to set up the initial frequency for the design, the option find_max_freq
for either iterating the design until timing is met(1) or just run once(0). The last input is the workload 
numbers of all the kernels of the benchmark. A workload number is defined as the total CUDA thread blocks
a kernel runs. This information is obtained from the application itself. For example, if a benchmark has
2 kernels, two workload numbers should be input, e.g. python gen_platform 7z020 fwt 5 1 200 200. The workload
number is not necessarily correct. You can assign an arbitrary large number. It is just an information given 
to the scripts to decide how many cores it should generate for the respective kernel based on HLS report.

- The output of the script is the Vivado project located at *fcuda-benchmarks/{benchmark_name}/vivado*.
It also generates a HDF file (Hardware Description File) at *fcuda-benchmarks/{benchmark_name}/sdk* for 
testing on-board.

- The directory *bare_metal_scripts* contains scripts for testing on-board in bare-metal mode.

`gen_bsp.sh {benchmark_name}`
This command will generate Board Support Package for the generated HDF file of the testing benchmark.
The Board Support Package contains many essential driver files (including driver for FCUDA IP core) in order
to make the full system runnable.

`download.sh {benchmark_name}`
This command will download the bitstream of the testing benchmark to the FPGA. Make sure you connect your 
development platform with the FPGA board via the JTAG port before running this command.

`./run_arm.sh {benchmark_name} {time}`
This command will open the Xilinx Microprocessor Debugger (XMD). Please connect your development platform
with the FPGA board via the UART port, and open up a serial terminal viewer. For example:

`sudo minicom --device=/dev/ttyACM0`

The script will compile the host code located at *fcuda-benchmarks/{benchmark_name}/sdk/app* and connect 
to the XMD to run the binary file. You can observe the output from the serial terminal viewer. The connect
session will last for the input time duration(e.g. 1000 ~ 1 second), then it will disconnect. Therefore,
make sure you input sufficient waiting time to observe the final output of the program.


