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

`timescale 1ns/1ps
`include  "noc_pkt.vh"
// Route lookup
module nextroute (
  input wire clk,
  input wire rst,
  
  input wire ce,
  input wire [`DESTWIDTH - 1: 0] destaddr,
  output wire sel);

parameter [`ROUTE_WIRE_WIDTH - 1 : 0] ROUTE = {`ROUTE_WIRE_WIDTH{1'b0}};

reg sel_tmp;

always @(posedge clk) begin
  if (rst) begin
    sel_tmp <= 1'b0;
  end 
  else begin
    if (ce) begin
      sel_tmp <= ROUTE[destaddr];
    end
  end
end

assign sel = sel_tmp;

endmodule

