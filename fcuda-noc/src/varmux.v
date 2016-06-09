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

// http://www.stanford.edu/class/ee108/verilog/blocks.v
// http://www.alteraforum.com/forum/showthread.php?t=22519
module varmux #(
  parameter width=32,
  parameter num_inputs=2
) ( 
  input wire  [num_inputs*width - 1 : 0] in_bus,  
  input wire  [clogb2(num_inputs) - 1 : 0] sel,
  output wire [width - 1 : 0]              out
);

`include "functions.vh"

wire [width - 1 : 0] input_array[0 : num_inputs - 1];

assign out=input_array[sel];

genvar ig;
generate
  for (ig = 0; ig < num_inputs; ig = ig + 1) begin : array_assignments
    assign input_array[ig] = in_bus[ig * width +:width];
  end
endgenerate

endmodule
