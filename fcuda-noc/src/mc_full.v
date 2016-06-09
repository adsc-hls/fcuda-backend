//============================================================================//
//    FCUDA
//    Copyright (c) <2016> 
//    <University of Illinois at Urbana-Champaign>
//    <University of California at Los Angeles> 
//    All rights reserved.
// 
//    Developed by:
// 
//        <ES CAD Group & IMPACT Research Group>
//            <University of Illinois at Urbana-Champaign>
//            <http://dchen.ece.illinois.edu/>
//            <http://impact.crhc.illinois.edu/>
// 
//        <VAST Laboratory>
//            <University of California at Los Angeles>
//            <http://vast.cs.ucla.edu/>
// 
//        <Hardware Research Group>
//            <Advanced Digital Sciences Center>
//            <http://adsc.illinois.edu/>
//============================================================================//

// mc_full.v
//
// Jacob Tolar & Yao Chen
// 
// the entire memory controller -- takes all inputs necessary, provides
// all outputs necessary


`include "noc_pkt.vh"

`timescale 1ns / 1ps

module mc_full # (
   parameter NUM_CORES = 1,
   parameter FIFO_DATA_WIDTH    = `IO_WIDTH,
   parameter DEPTH              = 2304,
   parameter WIDTH              = `IO_WIDTH,
   parameter ADDR_WIDTH = 32,
   parameter ADDR_DEPTH = 64,
   parameter DATA_WIDTH = 32,
   parameter ROUTE = 128'h0
) (
   input wire aclk,
   input wire arst,

   output wire mem_req_din,
   input wire mem_req_full_n,
   output wire mem_req_write,
   input wire mem_rsp_empty_n,
   output wire mem_rsp_read,
   output wire [31:0] mem_address,
   input wire [31:0] mem_datain,
   output wire [31:0] mem_dataout,
   output wire [31:0] mem_size,

   input wire mc_start,
   output wire mc_done,

   // NOC ports
   output wire [`IO_WIDTH-1:0] data_to_noc,
   input wire  [`IO_WIDTH-1:0] noc_to_data
); 


`include "functions.vh"
localparam  LOG2_DEPTHP1       = log2(DEPTH+1);
// Diagram of system
//
//                      NoC
//                       |
//     -----------------< <-----------
//     |                             |
//     v                             ^
//   vfifo --> mc -->  MIG   --> mc_int
//     |                             ^
//     ------------------------------|
//
wire                 app_wdf_rdy;
wire                 app_rdy;
wire                 app_rd_data_valid;
wire                 app_wdf_wren;
wire                 app_wdf_end;
wire                 app_en;    
wire  [29:0]         app_addr;    
wire  [2:0]          app_cmd;
wire  [31:0]        rd_data_fifo_out;
wire  [31:0]        app_wdf_data;

// wires between mc / other
wire addr_valid;
wire [FIFO_DATA_WIDTH - 1 : 0] addr_data;


wire [WIDTH - 1 : 0] input_fifo_wr_data;
assign input_fifo_wr_data = noc_to_data;

// inputs to vfifo

// inputs to vfifo from mc
wire                   input_fifo_rden;
wire [WIDTH - 1 : 0]   input_fifo_rd_data;

wire                   input_fifo_empty;

wire                   input_fifo_full;
wire [LOG2_DEPTHP1 - 1 : 0] input_fifo_count; 

wire input_fifo_wren ;
assign input_fifo_wren = noc_to_data[`SENDBIT_OFFSET];

assign mem_size = 32'b1; // burst length of 1

// instantiate memory controller
mc #(
  .NUM_CORES(NUM_CORES),
  .FIFO_DATA_WIDTH(FIFO_DATA_WIDTH)
) mc_input (
.clk(aclk),                       
.rst(arst),                          
   
  .mem_req_din(mem_req_din),
  .mem_req_full_n(mem_req_full_n),
  .mem_req_write(mem_req_write),
  .mem_rsp_empty_n(mem_rsp_empty_n),
  .mem_rsp_read(mem_rsp_read),
  .mem_address(mem_address),
  .mem_datain(mem_datain),
  .mem_dataout(mem_dataout),
  .mem_size(mem_size),

  .ini_end(mc_start),
  .fifo_empty(input_fifo_empty),       
  .input_fifo_data(input_fifo_rd_data),

  .out_addr_data(addr_data),
  .out_addr_valid(addr_valid),

  .read_fifo(input_fifo_rden),           
  .rd_data_valid(app_rd_data_valid),
  .rd_data_fifo_out(rd_data_fifo_out),

  .mc_done(mc_done)
);


// instantiate input fifo
vfifo #(
  .depth(DEPTH),
  .width(WIDTH)
) input_fifo (
  .clk(aclk),
  .rst(arst),
  .wren(input_fifo_wren), 
  .rden(input_fifo_rden),
  .empty(input_fifo_empty),
  .full(input_fifo_full),
  .wr_data(input_fifo_wr_data),
  .rd_data(input_fifo_rd_data),
  .count(input_fifo_count)
);

// instantiate output portion of controller
mc_int #(
  .DEPTH(DEPTH),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(ADDR_WIDTH),  
  .ADDR_DEPTH(ADDR_DEPTH),
  .ROUTE(ROUTE)
) mc_output (
  .clk(aclk),
  .rst(arst),
  .rd_data_valid(app_rd_data_valid),
  .rd_data_fifo_out(rd_data_fifo_out),
  .addr_valid(addr_valid),
  .addr_data(addr_data),
  .data_to_noc(data_to_noc)
);
endmodule
