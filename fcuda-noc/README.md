#FCUDA Network-on-Chip Flow (FCUDA NOC)

##Introduction
- This repository contains Verilog source files of the NoC backend logic as
well as scripts for the automation of network generation and testing
(simulation + logic synthesis + P & R). It invokes the front-end FCUDA C
compiler to translate CUDA C kernel to a serial C code, followed by RTL
generation by Vivado HLS. After that, our scripts incorporate the generated
RTL code with the existing Verilog source to build the project.

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

- The source code of the NOC backend is located under *src/*

- The folder *prepareFile_709/* contains the top level module for simulation, plus
DDR3 model verilog file and other files from Xilinx. They have been lightly
modified to initiate the necessary input data in the DDR3 after DDR3 calibration
is done, so we do not concern about writing another module to initialize data
for simulation.

- The folder *network_gen/* provides Python scripts to automate the generation of
the routing tables of all the nodes in the network. There are 3 types of node:
Router, Memory, and Compute. The Router nodes route packet throughout the
network, the Compute nodes is wrapper modules of FCUDA cores themselves, whereas
the Memory node is the network memory controller. Note that this memory
controller is different from the MIG: the former's functionality includes
processing the incoming packet, sending the request to the memory, or
constructing a packet and send it to the network, etc.  The latter is the memory
controller of the DDR memory.

- The script **gen_noc.py** is used for testing the whole FCUDA NOC project. Before
  using the script, please source the script **env_vars.sh** at the top level
directory (to initialize all the environment variables used by this Python
script) by running the following command `source env_vars.sh`

- The usage of the script **gen_noc.py** is described as below:

```
python gen_noc.py {benchmark_name} {width} {height} {sim_flow} {syn_flow}

  where: 
    benchmark_name: the name of the benchmarks for testing 
    width: width of the network (number of cores in x-axis)
    height: height of the network (number of cores in y-axis)
    (hence, width * height is the total number of FCUDA cores) 
    sim_flow: simulation flow 
      0 - no simulation 
      1 - run Simulation with MIG + DDR3 
      2 - run Simulation without MIG + DDR3 (faster) 
    syn_flow: synthesis flow 
      0 - no synthesis 
      1 - run Synthesis + P & R 

Example: python gen_noc.py matmul 3 3 2 0
```

- The script will create a timestamp directory located at *{benchmark's
directory}/noc_prj*. Inside this directory, the generated FCUDA C code is put
under *fcuda_gen/*; the HLS project is at *hls/*; and the Vivado project's directory
(either simulation or logic synthesis) is *vivado_prj/*.

- The script reads the NOC JSON file **noc_config.json** located at *{benchmark's
  directory}/noc*. The JSON file defines many essential parameters for
simulation/synthesis. Here is an explanation of the parameters used
in the file.

    + top\_level\_function: the name of the kernel function for HLS.  
    + device\_id: the ID of the FPGA platform.  
    + directory\_enable: enable directory feature of the NOC (if set to 1) 
    + directory\_size: the size of the directory for caching data 
    + directory\_bypass: enable directory bypass feature of the NOC (if set to 1) 
    + outstanding\_array\_enable: enable outstanding array feature of the NOC 
    (if set to 1) 
    + outstanding\_wait\_array\_delay: the delay time (cycles) of the outstanding 
    packet waiting for data before giving up (to go to the external memory) 
    + external\_mem\_delay\_sim: the emulated external memory access latency when 
    using the simulation flow without MIG + DDR3.  
    + output\_size: the size of the output data. This value is used to configure 
    the size of the NOC memory controller's FIFO receiving incoming packet from 
    the network to write data to the memory. This FIFO needs to be set as large 
    as the output's size (overestimated) because when all the cores start writing 
    to the memory, all the packets will be destined to the NOC memory controller 
    node, hence the congestion at the memory node increases significantly. 
    Besides, it also depends on how efficiently the designed state machine of 
    the memory controller node handles the incoming packet. Please note that we 
    do not implement back-pressured signal on this FIFO currently (specifically, 
    **vfifo.v**), so we use the FIFO size as big as necessary. As a side note, the 
    FIFOs at the router inputs/outputs can generate back-pressured signal 
    (specifically, **fifo.v**) to notify neighbors' routers to stop sending packets.  
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
        + num_cores: the number of FCUDA cores in the design. Note that the number of
        cores here does not correlate with the number of thread blocks of a CUDA 
        kernel. A FCUDA core can execute multiple thread blocks. Note that this
        parameter does not have any effect on the top-level module of the NOC
        (gen_network) since it already instantiates the required core number
        (width * height), so one can give arbitrary number to this field.
        + core_id: the core's identifier. It is used to distribute the workload 
        (num. thread blocks) among FCUDA cores. Note that this
        parameter does not have any effect on the top-level module of the NOC
        (gen_network) since it already instantiates the required core number
        (width * height), so one can give arbitrary number to this field.
        + {pointer_name}\_addr: to make FCUDA NOC function correctly, all the pointers 
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

- For NOC-related features, please check the relevant publications.

- If a benchmark does not have this **noc_config.json**, it means we have not yet
tested FCUDA NOC with that benchmark.  At this moment, FCUDA NOC is tested
with benchmarks: *matmul*, *cp*, *conv1d*, *dct*, *idct*. Please note that the CUDA kernel
used for FCUDA NOC is slightly different from the kernel used for Bus or others.
The kernel for NOC has a PORTMERGE pragma to bring the shared memory into
top-level function's interface. The purpose of this transformation is to expose
that shared memory into an outside BRAM, so it can be handled separately by our
designed logic of the network to enable sharing data between FCUDA cores.
Therefore, there is a file **fcuda_annot_{benchmark's name}_noc.cu** for FCUDA NOC
along with **fcuda_annot_{benchmark's name}.cu** in each kernel directory of a
benchmark's directory.

- The difference between 2 simulation flows is explained as followed:

###Run Simulation or Synthesis + P & R with MIG + DDR3

- How does the NoC interface with the MIG? Basically, we use the ap\_bus signals
of Vivado HLS for the top module of the network (**gen_network.v**). Then, we
reuse the AXI wrapper of Vivado HLS to wrap the top module of the network. The
AXI wrapper module will convert the ap\_bus signals to AXI signals to communicate
with other AXI- interface IPs, such as AXI Interconnect, or MIG, etc. As stated
above, we use the DDR3 model provided by Xilinx to run the simulation. This
provides a complete system simulation (FCUDA-core network plus the memory), 
although the simulation is slow.

###Run simulation without MIG + DDR3

- A simple testbench without MIG and DDR3 is also provided to fast-check the
correctness of the logic of the network without having to concern about
interfacing between NoC and (MIG + DDR3). Another advantage of using this
simulation flow is it consumes less time than simulation with MIG + DDR3. The
testbench uses a shift register to hold the request data. The width of the shift
register emulates the latency of the latency of the external memory access. This
value is configurable in the NOC JSON file of each benchmark
(external\_mem\_delay\_sim).  Ideas to improve the existing NoC, or adding new
benchmark should be definitely tried with this flow first.


###Adding new benchmark to FCUDA NOC flow

- At this moment, FCUDA NOC only works with benchmark which uses shared memory.
The shared memory will be made visible so that the data inside can be shared
among FCUDA cores. In fact, FCUDA NOC can also be applied to benchmark with
no shared memory. However, all the core requests will be sent directly to
the memory controller, and there is no opportunity for sharing. The gem of
the FCUDA NOC project lies on the cache-like directory system to track
whether a request data is on-chip or off-chip, and which core holds the data.
Therefore, a request can potentially be fulfil on-chip instead of accessing
the external memory, which incurs longer latency. Note that the current
directory system does not support write invalidation. Therefore, a read-only
shared memory is only applicable to this directory scheme.

- We will use benchmark *matmul* to demonstrate the process of adding essential
pragmas for the FCUDA NOC flow. Besides the usual COMPUTE/TRANSFER pragmas to
split the kernel into multiple sub-tasks, we need to use another type of pragma
called PORTMERGE to manipulate the interface of the kernel as we want. For example,
to expose an internal shared memory, place the following FCUDA PORTMERGE pragma 
right before the declaration of the shared memory.

```c

#pragma FCUDA PORTMERGE remove_port_name=As
__shared__ int As[16][16]
#pragma FCUDA PORTMERGE remove_port_name=Bs
__shared__ int Bs[16][16]

```

- With the above example, As's declaration is moved to the kernel function's 
interface. Vivado HLS then translates it to ap_memory interface, so the core
can connect to an outside BRAM as As' representative. Hence, As is visible
in the network, and other cores can request data from it by supplying a 
BRAM's address with read-enable signal. Same goes for Bs.

- Another requirement of the FCUDA NOC flow is to have only a single memory
port with Xilinx's ap_bus protocol. Therefore, all the interface pointers
will be merged into an unified pointer. As mentioned above, the corresponding
addresses (offsets) will be generated for each pointer to distinguish them.
Here is an example of how to add the pragmas to merge external memory pointers.

```c

#pragma FCUDA PORTMERGE remove_port_name=A port_id=0
#pragma FCUDA PORTMERGE remove_port_name=B port_id=0
#pragma FCUDA PORTMERGE remove_port_name=C port_id=0
__global__ void matrixMul( DATATYPE *C, DATATYPE *A, DATATYPE *B, int wA, int wB)

```

- In this example, *port_id* is the ID number of the merged port. Since we want
all the three pointers to be merged into one single port, their *port_id* values
must be the same.

- The resulting C code will look like:

```c

void matrixMul(DATATYPE *memport_p0, int A_addr, int B_addr, int C_addr, int wA,
  int wB, DATATYPE As[16][16], DATATYPE As_tag[16][16], DATATYPE Bs[16][16], 
  DATATYPE Bs_tag[16][16], int wA, int wB, int gridDim, int blockDim, int num_cores, 
  int core_id)

```

- As shown above, all the three pointers are merged into *memport_p0*, and their
respective offsets are generated. Additionally, FCUDA also produces tag arrays
for each outside-array (array on the kernel's interface). We will refer the
tag array as tag BRAM and the kernel array as data BRAM. When a core gets a packet
containing address plus data, the address portion of the packet is stored to
the tag BRAM, and the data portion of the packet is stored to the data BRAM.
Since an entry in data BRAM can be overwritten by time (e.g multiple writes to
the same location), the role of the tag BRAM is to keep track whether the 
request data (for sharing) at a certain BRAM index is valid. It is done by
comparing the address of the incoming request data with the current address 
stored in the tag BRAM. If it is a match, the data at that BRAM index is valid,
otherwise, it is invalid (the data at that BRAM index is already written by a
newer packet). This brings us to another question: how to infer that "BRAM
index"? When a cores sends a packet to another core to request for data
from its data BRAM, what we only have is the address portion of the packet
(note that it is the address of the memory system), we do not know what is
the BRAM address (or BRAM index) to read from the data BRAM of the destination
node. Thus, we need a BRAM mapping function to convert the memory address to
BRAM index. In other words, if I have a memory address, how do I determine
the corresponding BRAM index of it in a specific core? Obviously, this BRAM
mapping functions depend on various parameters, such as core identifier (which
core), thread indices, block indices, kernel's algorithm, etc. It changes from
one benchmark to another benchmark. When adapting new benchmark to FCUDA NOC
flow, we also have to understand how the memory access of a shared memory 
happens under the hood (the correlation between memory address and BRAM index).
The original author discussed this issue carefully [1].

- To avoid the burden of getting to know the BRAM mapping function of a benchmark,
a simple but not complete solution is to send the BRAM index of the tag BRAM along 
the memory address when a core requests data (source node). That BRAM index is 
generated within the core's logic, since we always write to the tag BRAM and the
data BRAM at the same time, their indices are identical. Also, because the packet
with read request does not necessarily have any sensible value on the data field,
we reuse the data field to store the BRAM index (with the assumption that the data
field's width can accommodate the BRAM index's width!). When the packet arrives 
to the destination node, the BRAM index from the data field of the packet will be used
to access the tag and data BRAMs of the arriving node. This only works if the
BRAM index is homogeneous across different cores, i.e does not depend on core ID,
which is the case of benchmark matmul. However, it is not always the case for
other benchmarks. A complete solution can potentially be: the directory at the
home node can be expanded to add one more field: BRAM index correspodingly to
the memory address. Therefore, when a packet arrives at the home node, performs
directory lookup, and finds that the data resides on a certain node with its
correspond BRAM index at that node, the BRAM index will replace the data field
of that packet and is routed to the node that has the data. It is only possible
if the memory controller sends the packet to update the home node with the relevant
BRAM index in the data field. It might seem that all of these workarounds
from not using BRAM mapping function are more expensive, but it ensures that
any new benchmark can work seamlessly without worrying about the nuances.
This is left for future implementation.

- Another issue is burst-mode support. Vivado HLS can automatically convert
a standard memory access to burst acess even without using memcpy() function.
This is a problem for the NOC logic since the burst transaction is quite different
from standard transaction. In the case of burst, the core only gives the starting
address and the burst length. However, the NOC interprets each address separately.
Because it also wants to increase the opportunity for data sharing, packing a
chunk of data to move at a time seems to make that goal prohibitive. Therefore,
we modified the NOC logic to convert burst-mode at the FCUDA core to standard
memory transaction at the upper-level module (completing one transaction before
starting another). Currently, the NOC works OK with cores using burst access,
however, it does not necessarily imply good performance. Implementing a 
full-fledged burst-mode is left for future work.

- Some other details: a packet takes 3 cycles when traversing through a router.
If the packet needs to access the directory, it will incur 3 additional cycles.
However, a packet does not necessarily access the directory of every router
on its path: it only needs to access the home node's. Hence, the feature 
"directory bypass" ensures that a packet will bypass directory access of all
but the home node.

##References

+ [1] Jacob S. Tolar, "A Directory Enhanced Network on Chip for FPGA", M.S.
thesis, Dept. Elect. Comput. Eng., Univ. Illinois at Urbana-Champaign, Illinois,
USA, 2013

+ [2] S. T. Gurumani, J. Tolar, Y. Chen, Y. Liang, K. Rupnow, and D. Chen.
Integrated CUDA-to-FPGA Synthesis with Network-on-Chip. In FCCM, pages 21–24,
May 2014.

+ [3] Y. Chen, S. Gurumani, Y. Liang, G. Li, D. Guo, K. Rupnow, and D. Chen.
FCUDA-NOC: A Scalable and Efficient Network-on-Chip Imple- mentation for the
CUDA-to-FPGA flow. Very Large Scale Integration (VLSI) Systems, IEEE
Transactions on, PP(99):1–14, 2015
