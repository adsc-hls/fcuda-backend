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

// Generate the read enable for the input FIFO combinatorially from
// all incoming select signal and the state of all output port
// arbiters
//
// This is one of the most critical paths.  It can almost fit into one
// CLB for a node with four input ports but it gets a bit worse for a
// five input switch.


module readenable(
  input wire [`NEXTHOPWIDTH*`NEXTHOPWIDTH - 1 : 0] sel,
  input wire [`NEXTHOPWIDTH - 1 : 0] oktosend,
  input wire [`NEXTHOPWIDTH - 1 : 0] override,
  input wire nolocal_rd,
  output wire rd
);

wire [`NEXTHOPWIDTH-1:0] rd_ind;

genvar i;
generate
for (i = 0; i < `NEXTHOPWIDTH; i = i + 1) begin: READENABLE
  assign rd_ind[i] = (oktosend[i] && sel[i * `NEXTHOPWIDTH]) && (&(~sel [(i+1)*`NEXTHOPWIDTH-1 : i*`NEXTHOPWIDTH+ 1 ]));
end
endgenerate

assign rd=((|(override&oktosend)) || !nolocal_rd) || (|rd_ind);
endmodule // readenable

