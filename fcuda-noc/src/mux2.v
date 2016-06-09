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

// generic 2 input mux
module mux2 (
  input wire I0,
  input wire I1,
  input wire S,
  output wire O);

reg tmp;

always  @(I0 or I1 or S) begin
  if (S==0) tmp = I0;
  else tmp = I1;
end

assign O = tmp;

endmodule

