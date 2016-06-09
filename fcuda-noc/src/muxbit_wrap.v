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
// wrapper for muxbit -- converts bundles to individual wires
module muxbit_wrap(
  input wire clk,
  input wire rst,
  input [`NEXTHOPWIDTH-1:0] i,
  input [`NEXTHOPWIDTH-1:0] sel,
  input [`NEXTHOPWIDTH-1:0] override,
/*  input wire muxsel, */
  output wire q
);


muxbit mb (
  .clk(clk),
  .rst(rst),
/*  .muxsel(muxsel),*/
  .w0(i[0]),
  .w1(i[1]),
  .w2(i[2]),
  .w3(i[3]),
  .w0sel(sel[0]),
  .w1sel(sel[1]),
  .w2sel(sel[2]),
  .w3sel(sel[3]),
  .w0override(override[0]),
  .w1override(override[1]),
  .w2override(override[2]),
  .w3override(override[3]),
  .q(q)
);

endmodule

