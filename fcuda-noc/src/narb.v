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

`include "noc_pkt.vh"

`timescale 1ns / 1ps

module narb # (
  parameter DATA_WIDTH    = 16,
  parameter BUF_DEPTH     = 4,
  parameter LOG2_BUF_DEPTH = 2,
  parameter VALID_BIT_OFFSET = 64
)
(
  input wire clk,
  input wire rst,

  // when there are only 12 entries left in FIFOs
  input wire [DATA_WIDTH - 1 : 0] core_i,
  input wire [DATA_WIDTH - 1 : 0] bcont_i,
  output wire [DATA_WIDTH - 1 : 0] noc_o
);

//Set these for narb_FIFO sizes (buffer width will be the same as data width)

wire bcont_sel; //select between bcont input and buffered bcont input
wire [DATA_WIDTH - 1 : 0] bcont_mux_o; //output of bcont mux
wire bcont_buf_wr;
wire bcont_buf_rd;
wire [DATA_WIDTH - 1 : 0] bcont_buf_out;
wire bcont_buf_empty;
wire bcont_buf_full;
wire bcont_buf_error;

wire core_sel;
wire [DATA_WIDTH - 1 : 0] core_mux_o;
wire core_buf_wr;
wire core_buf_rd;
wire [DATA_WIDTH - 1 : 0] core_buf_out;
wire core_buf_empty;
wire core_buf_full;
wire core_buf_error;
wire noc_sel;
  
//Selection signals, based on valid bits of various data
assign bcont_sel = bcont_buf_out[VALID_BIT_OFFSET];
assign core_sel = core_buf_out[VALID_BIT_OFFSET] && (!bcont_buf_out[VALID_BIT_OFFSET]);
assign bcont_buf_wr = bcont_i[VALID_BIT_OFFSET] && (core_buf_out[VALID_BIT_OFFSET] || bcont_buf_out[VALID_BIT_OFFSET]);
assign bcont_buf_rd = bcont_buf_out[VALID_BIT_OFFSET];
assign core_buf_wr = core_i[VALID_BIT_OFFSET] && (core_buf_out[VALID_BIT_OFFSET] || bcont_i[VALID_BIT_OFFSET] || bcont_buf_out[VALID_BIT_OFFSET]);
assign  core_buf_rd = core_buf_out[VALID_BIT_OFFSET] && (!bcont_buf_out[VALID_BIT_OFFSET]); 
assign  noc_sel = bcont_buf_out[VALID_BIT_OFFSET] || ((!core_buf_out[VALID_BIT_OFFSET]) && bcont_i[VALID_BIT_OFFSET]);
  
narb_fifo #(
  .BUF_WIDTH(DATA_WIDTH), 
  .BUF_DEPTH(BUF_DEPTH), 
  .LOG2_BUF_DEPTH(LOG2_BUF_DEPTH))
    bcont_buf (
  .clk(clk), 
  .rst(rst), 
  .enr(bcont_buf_rd),
  .enw(bcont_buf_wr),
  .dataout(bcont_buf_out),
  .datain(bcont_i),
  .empty_o(bcont_buf_empty),
  .full_o(bcont_buf_full),
  .error_o(bcont_buf_error));
            
narb_fifo #(
  .BUF_WIDTH(DATA_WIDTH), 
  .BUF_DEPTH(BUF_DEPTH), 
  .LOG2_BUF_DEPTH(LOG2_BUF_DEPTH))
    core_buf (
  .clk(clk), 
  .rst(rst), 
  .enr(core_buf_rd),
  .enw(core_buf_wr),
  .dataout(core_buf_out),
  .datain(core_i),
  .empty_o(core_buf_empty),
  .full_o(core_buf_full),
  .error_o(core_buf_error));

assign bcont_mux_o = (bcont_sel == 0) ? bcont_i : bcont_buf_out;
assign core_mux_o = (core_sel == 0) ? core_i : core_buf_out;
assign noc_o = (noc_sel == 0) ? core_mux_o : bcont_mux_o;

endmodule
