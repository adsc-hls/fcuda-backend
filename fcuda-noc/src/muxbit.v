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
// A simple 4-1 mux with four control signals to select the output
module muxbit(
  input wire clk,
  input wire rst,
  input wire w0, w1, w2, w3,
  input wire w0sel, w1sel, w2sel, w3sel,
  input wire w0override, w1override, w2override, w3override,
  output wire q
);

wire muxsel_1_0;
wire partial_0_1;
wire partial_2_3;
wire partial_0_1_2_3;

assign muxsel_1_0 = (!w0override && !w1override) && (w2sel || w3sel);

muxlut lut0(.I0(w0sel),.I1(w1override),.I2(w0),.I3(w1),.O(partial_0_1));
muxlut lut1(.I0(w2sel),.I1(w3override),.I2(w2),.I3(w3),.O(partial_2_3));

mux2 mux1_0(.I0(partial_0_1),.I1(partial_2_3),.S(muxsel_1_0),.O(partial_0_1_2_3));

my_fdr fd(.q(q),.d(partial_0_1_2_3),.rst(rst),.clk(clk));
endmodule
