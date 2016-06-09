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
`include  "noc_pkt.vh"

// generic impl of FDE flip flop
// slightly different than spec (which has no reset, but resets to 0 on power on)
module my_fde (
  input wire clk,
  input wire ce,
  input wire rst,
  input wire d,
  output reg q);

always @(posedge clk) begin
  if (rst == 1) begin
    q <= 1'b0;
  end else if (ce == 1) begin
    q <= d;
  end
end

endmodule


