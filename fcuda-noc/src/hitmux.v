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

/* 
 * generate muxes for inputs based on whether or not there was a hit within
 * the lookup table. 
 */

`timescale 1ns / 1ps
`include "noc_pkt.vh" 

module hitmux(
	input wire clk,
	input wire rst,

  input  wire[`DIR_READEN_WIDTH           - 1: 0] hits,             /* hits - act as mux select bits */
  input  wire[`TOTAL_ROUTER_ID_WIDTH      - 1: 0] router_ids,
  input  wire[`TOTAL_RESULT_SIZE          - 1: 0] orig_addresses,   /* dest addresses to (maybe) replace */
  input  wire[`NEXTHOPWIDTH *`NUM_INPUTS  - 1: 0] orig_nhops,       /* nhops          to (maybe) replace */
  input  wire[`TOTAL_RESULT_SIZE          - 1: 0] addresses,        /* dest addresses to (maybe) replace */
  input  wire[`NEXTHOPWIDTH *`NUM_INPUTS  - 1: 0] nhops,            /* nhops          to (maybe) replace */
  input  wire[`NEXTHOPWIDTH *`NUM_INPUTS  - 1: 0] mem_nhops,        /* nhops          to (maybe) replace */
  input  wire[`TOTAL_PKT_TYPE_WIDTH       - 1: 0] types,
//   input  wire[`NUM_INPUTS                 - 1: 0] wasreplaced,
  output wire[`TOTAL_PKT_TYPE_WIDTH       - 1: 0] out_types,
  output wire[`TOTAL_RESULT_SIZE          - 1: 0] destout, 
  output wire[`NEXTHOPWIDTH *`NUM_INPUTS  - 1: 0] nhopout 
);

parameter [`DESTWIDTH      -1:0] MEM_ADDRESS = {`DESTWIDTH{1'b0}};
parameter [`ROUTER_ID_WIDTH-1:0] ROUTER_ID   = {`ROUTER_ID_WIDTH{1'b0}};


/* 
 * look up next route based on dest addr
 */
genvar i;
generate
  for (i =0; i < `NUM_INPUTS; i = i + 1) begin:outer
    wire local_hit;

    wire [`DESTWIDTH       - 1:0] local_orig_addr;
    wire [`DESTWIDTH       - 1:0] local_addr;
    wire [`NEXTHOPWIDTH    - 1:0] local_orig_nhops;
    wire [`NEXTHOPWIDTH    - 1:0] local_nhops;
    wire [`DESTWIDTH       - 1:0] local_destout;
    wire [`NEXTHOPWIDTH    - 1:0] local_nhopout;
    wire [`ROUTER_ID_WIDTH - 1:0] local_router_id;
    wire [`NEXTHOPWIDTH    - 1:0] local_mem_nhops;
    wire [`DATA_TYPEWIDTH  - 1:0] local_type;
    wire [`DATA_TYPEWIDTH  - 1:0] local_out_type;

    assign local_hit = hits[i] == 1'b1;

    assign local_orig_addr   = orig_addresses[ (i + 1) * `DESTWIDTH       - 1 : (i * `DESTWIDTH)];
    assign local_addr        =      addresses[ (i + 1) * `DESTWIDTH       - 1 : (i * `DESTWIDTH)];
    assign local_orig_nhops  =     orig_nhops[ (i + 1) * `NEXTHOPWIDTH    - 1 : (i * `NEXTHOPWIDTH)];
    assign local_nhops       =          nhops[ (i + 1) * `NEXTHOPWIDTH    - 1 : (i * `NEXTHOPWIDTH)];
    assign local_router_id   =     router_ids[ (i + 1) * `ROUTER_ID_WIDTH - 1 : (i * `ROUTER_ID_WIDTH)];
    assign local_mem_nhops   =      mem_nhops[ (i + 1) * `NEXTHOPWIDTH    - 1 : (i * `NEXTHOPWIDTH)];
    assign local_type        =          types[ (i + 1) * `DATA_TYPEWIDTH  - 1 : (i * `DATA_TYPEWIDTH)];

    wire check = (local_type != `TYPE_REQUEST || (ROUTER_ID != local_router_id) || ((ROUTER_ID+`NUM_COMPUTE_NODES != local_orig_addr)));

    wire outstanding_repl = (local_type == `TYPE_OUTSTANDING) && ( ROUTER_ID == local_router_id) && (local_hit == 1'b1);
    assign local_destout  = outstanding_repl ? local_orig_addr : (check ? local_orig_addr  : (local_hit ? local_addr  : MEM_ADDRESS));
    assign local_nhopout  = outstanding_repl ? /* choose the dir item */ local_nhops       :  (check ? local_orig_nhops : (local_hit ? local_nhops : local_mem_nhops));

    assign local_out_type = outstanding_repl ? local_type : (check ? local_type            : (local_hit ?`TYPE_C_REQ  : local_type));
    
    
    assign destout[(i + 1) * `DESTWIDTH - 1 : i * `DESTWIDTH]       = local_destout;
    assign nhopout[(i + 1) * `NEXTHOPWIDTH - 1 : i * `NEXTHOPWIDTH] = local_nhopout;
    assign out_types[(i + 1) * `TYPEWIDTH - 1 : i * `TYPEWIDTH]     = local_out_type;
    
  end
endgenerate

endmodule


