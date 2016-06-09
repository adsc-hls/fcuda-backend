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

// Route lookup -- static
// For looking up route to memory (address is known at compile time) 
module nextroute_static #(
  parameter [`ROUTE_WIRE_WIDTH - 1 : 0] ROUTE     = {`ROUTE_WIRE_WIDTH{1'b0}},
  parameter [`DESTWIDTH - 1 : 0]        DEST_ADDR = {`DESTWIDTH{1'b0}}
) (
  output wire sel
);

  // should be same behavior as nextroute module, but require 0 area -- should 
  // compile to a constant value
  assign sel = ROUTE[DEST_ADDR];

endmodule
