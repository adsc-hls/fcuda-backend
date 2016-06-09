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

`timescale 1ns / 1ps
`include "noc_pkt.vh"

// do assignment using a module - abstracts away
// concatenation, makes code cleaner
// noc_sender nsend(
//   .sendokbit(),
//   .sendbit(),
//   .nhop(),
//   .lastbit(),
//   .dest(),
//   .src(),
//   .type(),
//   .data(),
//   .addr(),
//   .out()
// );
/*changed by YaoChen*/
/*
reduce the payload data width DATA_DATAWIDTH = DATA_AWIDTH + DATA_DWIDTH;
send the data and address individually using the same data packet
type:
TYPE_REQUEST        7'b0000000
TYPE_RESPONSE_ADDR  7'b0000001
TYPE_RESPONSE_DATA  7'b0000010
TYPE_C_REQ          7'b0000011
TYPE_WRITE          7'b0000100
TYPE_OUTSTANDING    7'b0000101 
*/
module noc_sender(
  input wire sendokbit,
  input wire sendbit,
  input wire [`NEXTHOPWIDTH - 1 : 0] nhop,
  input wire lastbit,
  input wire [`DESTWIDTH - 1 : 0] dest,
  input wire [`DATA_SRCWIDTH-1 : 0] src,
  input wire [`DATA_TYPEWIDTH - 1 : 0] type,
  input wire [`DATA_DWIDTH - 1 : 0] data,
  input wire [`DATA_AWIDTH - 1 : 0] addr,
/*changed by YaoChen*/
//reduce the output width -32
  output wire [`IO_WIDTH - 1:0] out
);
  
assign out = { sendokbit, sendbit, nhop, lastbit, dest, src, type, data, addr };

endmodule
