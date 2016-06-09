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

module encoder (a,b) ;
  parameter n = 2;
  parameter m = 1;
  input wire [n - 1 : 0] a;
  output reg [m - 1 : 0] b;

integer i;
always @(a) begin
  for (i = 0; i < n; i = i + 1) begin
    if (a[i] == 1) begin
      b = i;
    end
  end
  if (a == 0) b = 0;
end

endmodule

