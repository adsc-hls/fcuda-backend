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

/*
 * this modulea only calculates nexthop values for two possible input
 * destinations
 *   one :  always memory address
 *   other: the output from directory
 */

module hitreplace #(
  parameter [`ALL_ROUTE_BITS - 1 : 0] ROUTE = {`ALL_ROUTE_BITS{1'b0}},
  parameter [`DESTWIDTH-1: 0] MEM_ADDRESS = {`DESTWIDTH{1'b0}}
) (
  input wire clk,
  input wire rst,
  input wire[`TOTAL_RESULT_SIZE - 1: 0] addresses,
  output wire[`NEXTHOPWIDTH *`NUM_INPUTS  - 1: 0] nhops,
  output wire[`NEXTHOPWIDTH *`NUM_INPUTS  - 1: 0] mem_nhops
);

/* 
 * look up next route based on dest addr
 *
 * This is more heavy on logic than I would like it to be, but, it should wokr
 * for now
 */
genvar i,j;
generate
  for (i =0; i < `NUM_INPUTS; i = i + 1) begin:outer
  wire [`DESTWIDTH - 1: 0] local_addr ;

  assign local_addr = addresses[ (i+1)*`DESTWIDTH-1 : (i * `DESTWIDTH)]; 

    for (j = 0; j < `NEXTHOPWIDTH; j = j + 1) begin:inner
      wire   local_sel;
      wire   local_mem_sel;
      nextroute #(
        .ROUTE(ROUTE[((i) * `NEXTHOPWIDTH * `ROUTE_WIRE_WIDTH) + ((j + 1)*`ROUTE_WIRE_WIDTH) -1 -: `ROUTE_WIRE_WIDTH])
      ) nr_new(
        .clk(clk), 
        .rst(rst), 
        .ce(1'b1), 
        .destaddr(local_addr), 
        .sel (local_sel ) 
      );

      `ifdef STATIC_MEM_NEXTROUTE
        nextroute_static #(
          .ROUTE(ROUTE[((i) * `NEXTHOPWIDTH * `ROUTE_WIRE_WIDTH) + ((j + 1)*`ROUTE_WIRE_WIDTH) -1 -: `ROUTE_WIRE_WIDTH]),
          .DEST_ADDR(MEM_ADDRESS)
        ) nr_mem (
          .sel(local_mem_sel)
        );
      `else
        nextroute #(
          .ROUTE(ROUTE[((i) * `NEXTHOPWIDTH * `ROUTE_WIRE_WIDTH) + ((j + 1)*`ROUTE_WIRE_WIDTH) -1 -: `ROUTE_WIRE_WIDTH])
        ) nr_mem (
          .clk(clk), 
          .rst(rst), 
          .ce(1'b1), 
          .destaddr(MEM_ADDRESS), 
          .sel (local_mem_sel ) 
        );
      `endif

      assign nhops[(i) * `NEXTHOPWIDTH + j]     = local_sel;
      assign mem_nhops[(i) * `NEXTHOPWIDTH + j] = local_mem_sel;
    end
  end
endgenerate

endmodule

