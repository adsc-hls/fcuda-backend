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

module  router_wrap 
#(
  parameter [`NUM_INPUTS * `NEXTHOPWIDTH * `ROUTE_WIRE_WIDTH - 1 : 0] PREROUTE     = {`NUM_INPUTS * `NEXTHOPWIDTH * `ROUTE_WIRE_WIDTH{1'b0}},
  parameter [`NUM_INPUTS * `NEXTHOPWIDTH * `ROUTE_WIRE_WIDTH - 1 : 0] ACTUAL_ROUTE = {`NUM_INPUTS * `NEXTHOPWIDTH * `ROUTE_WIRE_WIDTH{1'b0}},
  parameter [`DESTWIDTH-1: 0]      MEM_ADDRESS                                     = {`DESTWIDTH{1'b0}},
  parameter [`ROUTER_ID_WIDTH-1:0] ROUTER_ID                                       = {`ROUTER_ID_WIDTH{1'b0}}

)
(
  input wire clk,
  input wire rst,
  input  wire[`TOTAL_WIDTH - 1 : 0] router_in,
  output wire[`TOTAL_WIDTH - 1 : 0] router_out
);

genvar i;
generate

  `ifdef ENABLE_DIRECTORIES

  reg [`TOTAL_WIDTH - 1 : 0] stage_3_4;
  wire [`TOTAL_RESULT_SIZE - 1 : 0] destout;

  // Stage 1
  // Traverse directories
  //

  wire [`NUM_INPUTS - 1 : 0] bypass;
  reg [`NUM_INPUTS - 1 : 0] count_packet_received;

  for (i=0; i < `NUM_INPUTS; i = i + 1) begin:BUILD_DIR_WIRES2
    wire  [`IO_WIDTH-1 : 0] msg_cur = router_in[`BOUNDS(i, `IO_WIDTH)];
    always@(posedge clk) begin

    if (msg_cur[`SENDBIT_OFFSET] == 1'b1 && 
      !(|(msg_cur[`FIELD(`NEXTHOP_OFFSET,`NEXTHOPWIDTH)])))   begin
      $display("[%m]: @ %d - Error: packet is valid but no nexthop bits set.", $time);
      $stop;
    end

    if (msg_cur[`SENDBIT_OFFSET] == 1'b1)   begin
      $display("[%m]: @ %d - packet received, type = %d, src = %d, dest = %d, data = %h, addr = %h, nhop = %h", 
        $time,
        msg_cur[`PKT_TYPE],
        msg_cur[`PKT_SRC],
        msg_cur[`PKT_DEST],
        msg_cur[`PKT_DATA],
        msg_cur[`PKT_ADDR],
        msg_cur[`PKT_NHOP]
      );
      count_packet_received[i] <= 1;
    end
    else
      count_packet_received[i] <= 0;

      if (bypass[i]) begin
        $display("[%m]: @ %d - directory bypass enabled: type = %d, src = %d, dest = %d, data = %h, addr = %h, nhop = %h - saved 3750 ps = 3.75 ns",
        $time,
        msg_cur[`PKT_TYPE],
        msg_cur[`PKT_SRC],
        msg_cur[`PKT_DEST],
        msg_cur[`PKT_DATA],
        msg_cur[`PKT_ADDR],
       msg_cur[`PKT_NHOP]
      );
      end
    end
  end

  // we want to enable bypassing in the directory 
  // basically...  rtr_in[i] has one mux before it
  //   if rtr_in[i] sendbit == 0 and pkt_input is not required to
  //   pass through directory (bunch of conditions) => send that, and
  //   nullify the pkt_input for next stage
  //   else
  //     just send other 

  // required_dircheck

  // assign required_dircheck =  (dir read) | (dir write) 
  //        dir_read  := pkt_valid AND 
  //        dir_write := (pkt_valid AND (dest == this node) AND type = update directory) OR 
  //                     (pkt_valid AND (dest == this node) AND type == request) << oustanding array

  // outstanding array: 
  //   read: if (valid) and (home node == this node) and (type == request)  and (dest == this guy) ==> oa read, don't fwd
  //   write: if (valid) and (home node == this node) and (type == reqeust) and (dest == this guy) ==> oa write, don't fwd
       // write actual condition: (oa_cur[`PKT_SENDBIT] == 1'b1) && (oa_cur[`PKT_TYPE] == `TYPE_REQUEST) && (oa_addr[`ROUTER_ID_LOW + `ROUTER_ID_WIDTH -1 : `ROUTER_ID_LOW] == ROUTER_ID );
  // dir: 
  //   dir read:  if (valid) and (home node == this guy) and (type == request) and (dest == this guy) ==> dir read (???????????????)
  //   dir write: if (valid) and (home node == this guy) and (type == update) and (dest == this guy) ==> dir write (?????????????)
                            
          

  `ifdef DIRECTORY_BYPASS
  for (i = 0; i < `NUM_INPUTS; i = i + 1) begin:  DIR_BYPASS
    wire [`IO_WIDTH - 1 : 0] bp_cur     = router_in[`BOUNDS(i,`IO_WIDTH)];
    wire [`DATA_AWIDTH - 1 : 0] bp_addr = bp_cur[`PKT_ADDR];
    wire [`DESTWIDTH - 1 : 0] bp_dest   = bp_cur[`PKT_DEST];

    wire [`ROUTER_ID_WIDTH - 1 : 0] bp_rid = `HOME_NODE_MAPPING(bp_addr, ROUTER_ID);

    wire [`IO_WIDTH - 1 : 0] future_cur  = stage_3_4[`BOUNDS(i,`IO_WIDTH)];
    wire future_sb                   = future_cur[`SENDBIT_OFFSET];
    integer r_addr = ROUTER_ID + `NUM_COMPUTE_NODES;
    
    wire [`DESTWIDTH-1:0] future_dest =  destout[`BOUNDS(i,`DESTWIDTH)]; //// future_cur[`PKT_DEST];
    wire future_sb_2                  =  (r_addr == future_dest) ? 1'b0 : future_sb;



    wire cur_byp = (bp_cur[`PKT_SENDBIT] == 1'b1) && 
                   (!((bp_cur[`PKT_TYPE] == `TYPE_REQUEST) &&         // not oe_we or oe_read. also covers dir read
                      (bp_rid  == ROUTER_ID ) && 
                      (bp_dest == r_addr))) &&
                   (!((bp_cur[`PKT_TYPE] == `TYPE_RESPONSE_ADDR) &&   // not dir update. 
                      (bp_rid  == ROUTER_ID ) && 
                      (bp_dest == r_addr ))) &&  
                   (!(future_sb_2)) ;   // future packet not valid 

    assign bypass[i] = cur_byp;
  end
  `endif

  // if bypass[i] is 1 => then we want to *not* send the packet
  // how do we avoid passing this packet on through network? 
  // 
  // Leave oe logic the same -- if [oe] => no bypass

  `ifdef ENABLE_OUTSTANDING_ARRAY
  wire [`NUM_INPUTS - 1 : 0] oe_we;
  wire [`NUM_INPUTS*`IO_WIDTH - 1 : 0] outstanding_array_out;
  wire [`NUM_INPUTS - 1 : 0] wasreplaced;
  reg  [`NUM_INPUTS - 1 : 0] wasreplaced_reg;

  for (i = 0; i < `NUM_INPUTS; i = i + 1) begin: OA_GEN
    // set we 
    //
    wire [`IO_WIDTH - 1 : 0] oa_cur  = router_in[`BOUNDS(i,`IO_WIDTH)];
    wire [`DATA_AWIDTH - 1 : 0] oa_addr = oa_cur[`PKT_ADDR];
    wire [`ROUTER_ID_WIDTH - 1 : 0] oa_rid = `HOME_NODE_MAPPING(oa_addr, ROUTER_ID);

    // update the outstanding_array register iff: 
    //   packet is valid
    //   packet type is request
    //   packet home node is this node
    //     --> stronger condition: packet DEST is this node [ e..g
    //     oa_cur[`PKT_DEST] == ROUTER_ID + NUM_NODES. 
    //
    //     We are potentially writing when we should not be -- e.g.
    //     requests that have failed (?) 
    //     FIXME --- the above stronger condition is not implemented
    assign oe_we[i] = (oa_cur[`PKT_SENDBIT] == 1'b1) && 
                      (oa_cur[`PKT_TYPE] == `TYPE_REQUEST) && 
                      (oa_rid == ROUTER_ID ) ;// &&
                      // (oa_cur[`PKT_DEST] == (ROUTER_ID + `NUM_COMPUTE_NODES));
  end

  // try to redirect for outstanding requests not yet in the directory
  //
  // Alternatively: send another packet type from the home node that
  // says the packet is outstanding one cycle later
  outstanding_array  #(
    .ROUTER_ID(ROUTER_ID)
  ) arr_cmp (
    .we(oe_we),                   
    .di(router_in),              
    .dout(outstanding_array_out),
    .wasreplaced(wasreplaced),
    .clk(clk),
    .rst(rst)
  ); 

  `endif

  // goal here: if we are using bypassing, then we need to potentially
  // cancel out the current packet if it is being bypassed...

  wire [`NUM_INPUTS*`IO_WIDTH-1:0]             bypassed_input;

  // Logic here is: 
  // If bypass enabled
    // If outstanding array enabled
      //  Bypass using outstanding array out
    // Else
      // Bypass using router_in
  // Else
    // If outstanding array enabled
      // Input = oa_output
    // Else
      // Input = router_in
  for(i = 0; i < `NUM_INPUTS; i = i + 1) begin:SET_OA_BYPASSED
  `ifdef DIRECTORY_BYPASS
    `ifdef ENABLE_OUTSTANDING_ARRAY
      assign bypassed_input[`BOUNDS(i,`IO_WIDTH)] = outstanding_array_out[`BOUNDS(i,`IO_WIDTH)] & ((~(bypass[i] << `SENDBIT_OFFSET)) | (1 << `SENDOKBIT_OFFSET)) ;
    `else
      assign bypassed_input[`BOUNDS(i,`IO_WIDTH)] =  router_in[`BOUNDS(i,`IO_WIDTH)]  & ((~(bypass[i] << `SENDBIT_OFFSET)) | (1 << `SENDOKBIT_OFFSET)) ;
    `endif
  `else
    `ifdef ENABLE_OUTSTANDING_ARRAY
      assign bypassed_input[`BOUNDS(i,`IO_WIDTH)] = outstanding_array_out[`BOUNDS(i,`IO_WIDTH)];
    `else
      assign bypassed_input[`BOUNDS(i,`IO_WIDTH)] =  router_in[`BOUNDS(i,`IO_WIDTH)];
    `endif
  `endif
  end

  reg [`TOTAL_WIDTH - 1 : 0] stage_1_2;
  always @(posedge clk) begin
    stage_1_2 <= bypassed_input;
    `ifdef ENABLE_OUTSTANDING_ARRAY
      wasreplaced_reg <= wasreplaced;
    `endif
  end

  // get packet fields for directory
  wire[`TOTAL_TAG_WIDTH       - 1 : 0] dir_tags;
  wire[`TOTAL_INDEX_WIDTH     - 1 : 0] dir_indecies;
  wire[`DIR_READEN_WIDTH      - 1 : 0] dir_hits;
  wire[`TOTAL_RESULT_SIZE     - 1 : 0] dir_results;
  wire[`DIR_READEN_WIDTH      - 1 : 0] dir_readen;
  wire[`TOTAL_ROUTER_ID_WIDTH - 1 : 0] dir_router_ids;
  wire[`TOTAL_PKT_TYPE_WIDTH  - 1 : 0] dir_pkt_types;

  wire[`NUM_INPUTS  - 1 : 0]           dir_pkt_valids;

  wire[`TOTAL_SRC_ADDR_WIDTH  - 1 : 0] dir_src_addrs;
  wire[`TOTAL_DEST_ADDR_WIDTH - 1 : 0] dir_dest_addrs;

  // build inputs to directory
  for (i = 0; i < `NUM_INPUTS; i = i + 1) begin:BUILD_DIR_WIRES

    // get current packet
    wire  [`IO_WIDTH - 1 : 0] cur = stage_1_2[`BOUNDS(i, `IO_WIDTH)];

    // get SENDBIT
    wire sendbit = cur[`SENDBIT_OFFSET];

    // wires for fields of current packet
    wire                         local_readen;
    wire                         local_valid;
    wire [`TAG_WIDTH      - 1 : 0] local_tag;
    wire [`INDEX_WIDTH    - 1 : 0] local_index;
    wire [`ROUTER_ID_WIDTH - 1 : 0] local_rid;
    wire [`ROUTER_ID_WIDTH - 1 : 0] local_rid_m;
    wire [`DATA_TYPEWIDTH - 1 : 0] local_type;
    wire [`DATA_SRCWIDTH  - 1 : 0] local_src;
    wire [`DESTWIDTH      - 1 : 0] local_dest;

    // assign based on fields
    assign local_valid = cur[`PKT_SENDBIT];
    assign local_index = cur[`FIELD(`INDEX_LOW,`INDEX_WIDTH)];
    //assign local_rid_m = (cur[`FIELD(`ROUTER_ID_LOW,`ROUTER_ID_WIDTH)]) % (`NUM_ROUTER_NODES) ;
    assign local_rid_m = `HOME_NODE_MAPPING(cur, ROUTER_ID);
    assign local_rid   = cur[`FIELD(`ROUTER_ID_LOW,`ROUTER_ID_WIDTH)];
    assign local_type  = cur[`FIELD(`TYPE_OFFSET,`DATA_TYPEWIDTH)]; 
    assign local_src   = cur[`FIELD(`SRC_OFFSET,`DATA_SRCWIDTH)];
    assign local_dest  = cur[`FIELD(`DEST_OFFSET,`DESTWIDTH)];

    // The tag includes the tag field as well as the top bit of the rid
    // field
    // assign local_tag   = {cur[`FIELD(`TAG_LOW,`TAG_WIDTH)],local_rid[`ROUTER_ID_WIDTH - 1]};
    assign local_tag   = cur[`FIELD(`TAG_LOW,`TAG_WIDTH)];

    // we can say, readen is (TYPE == REQUEST) AND (PKT == VALID)
    // better: type == REQUEST, PKT == VALID, ROUTER_ID == my router id
    // assign local_readen = (local_tag == `TYPE_REQUEST) && sendbit && (local_rid == ROUTER_ID);

    // FIXED: This was totally a bug (not sure how I missed it), but should be better now...
    // assign local_readen = (local_type == `TYPE_REQUEST) && sendbit && (local_rid == ROUTER_ID);

    // FIXED : The above was again a bug. we should also check that the
    // DEST is the same as this node's ID. Otherwise failed directory
    // lookups will loop back around. 
    assign local_readen = (local_type == `TYPE_REQUEST) && sendbit && (local_rid_m == ROUTER_ID) && (local_dest == (ROUTER_ID + `NUM_COMPUTE_NODES));

    // assign directory inputs
    assign dir_readen[i]                                 = local_readen;
    assign dir_tags[ `BOUNDS(i,`TAG_WIDTH) ]             = local_tag;
    assign dir_indecies[`BOUNDS(i,`INDEX_WIDTH) ]        = local_index;
    assign dir_router_ids[`BOUNDS(i, `ROUTER_ID_WIDTH) ] = local_rid_m;
    assign dir_pkt_types[`BOUNDS(i,`DATA_TYPEWIDTH) ]    = local_type;
    assign dir_src_addrs[`BOUNDS(i,`DATA_SRCWIDTH) ]     = local_src;

    assign dir_dest_addrs[`BOUNDS(i,`DESTWIDTH) ]         = local_dest;
    assign dir_pkt_valids[i]                             = local_valid;
  end
        
  dirnew #(
    .ROUTER_ID(ROUTER_ID)
  )dir(
    .clk(clk),
    .rst(rst),
    .readen(dir_readen),
    .tags(dir_tags),
    .indecies(dir_indecies),
    .router_ids(dir_router_ids),
    .pkt_types(dir_pkt_types),
    .src_addrs(dir_src_addrs),
    `ifdef ENABLE_OUTSTANDING_ARRAY
    .dest_addrs(dir_dest_addrs),
    .wasreplaced(wasreplaced_reg),
    `endif
    .pkt_valids(dir_pkt_valids),
    .hits(dir_hits),
    .results(dir_results)
  );

  // Stage 2: hitreplace 
  //

  `ifdef REAL_DIRECTORY_IMPLEMENTATION
    wire [`DIR_READEN_WIDTH - 1 : 0] hits_stage_2_3 = dir_hits;
    wire [`TOTAL_RESULT_SIZE - 1 : 0] results_stage_2_3 = dir_results;
  `else
    reg [`DIR_READEN_WIDTH - 1 : 0] hits_stage_2_3;
    reg [`TOTAL_RESULT_SIZE - 1 : 0] results_stage_2_3;
  `endif
  reg [`TOTAL_WIDTH - 1 : 0] stage_2_3;
  always @(posedge clk) begin
    stage_2_3 <= stage_1_2;
    `ifndef REAL_DIRECTORY_IMPLEMENTATION
      hits_stage_2_3 <= dir_hits;
      results_stage_2_3 <= dir_results;
    `endif
  end

  // these are not latched because the NHOP actually has flip-flops in it!
  wire[`NEXTHOPWIDTH *`NUM_INPUTS  - 1: 0] nhops;
  wire[`NEXTHOPWIDTH *`NUM_INPUTS  - 1: 0] mem_nhops;

  hitreplace #(
    .ROUTE(PREROUTE),
    .MEM_ADDRESS(MEM_ADDRESS)
  )hr(
    .clk(clk),
    .rst(rst),
    .addresses(results_stage_2_3),
    .mem_nhops(mem_nhops),
    .nhops(nhops)
  );

  // Stage 3: hitmux
  //

  reg [`DIR_READEN_WIDTH - 1 : 0] hits_stage_3_4;
  reg [`TOTAL_RESULT_SIZE - 1 : 0] results_stage_3_4;

  always @(posedge clk) begin
    stage_3_4 <= stage_2_3;
    hits_stage_3_4 <= hits_stage_2_3;
    results_stage_3_4 <= results_stage_2_3;
  end

  // these are not latched because the NHOP actually has flip-flops in it!
  wire [`NEXTHOPWIDTH *`NUM_INPUTS  - 1: 0] nhops_stage_3_4;
  wire [`NEXTHOPWIDTH *`NUM_INPUTS  - 1: 0] mem_nhops_stage_3_4;

  assign nhops_stage_3_4     = nhops;
  assign mem_nhops_stage_3_4 = mem_nhops;

  // need to get original dDEST nad NHOP
  wire[`NEXTHOPWIDTH *`NUM_INPUTS  - 1: 0] nhopout;

  wire[`TOTAL_RESULT_SIZE         - 1: 0]  orig_addresses; /* dest addresses to (maybe) replace */
  wire[`NEXTHOPWIDTH *`NUM_INPUTS - 1: 0]  orig_nhops;     /* nhops to (maybe) replace */
  wire[`TOTAL_ROUTER_ID_WIDTH     - 1: 0]  hm_router_ids;
  wire[`TOTAL_PKT_TYPE_WIDTH      - 1: 0]  hm_types;
  wire[`TOTAL_PKT_TYPE_WIDTH      - 1: 0]  out_types;

  for (i = 0; i < `NUM_INPUTS; i = i + 1) begin:GET_ORIG_ADDR_NHOP_FIELDS
    wire [`IO_WIDTH-1:0] cur;
    assign cur = stage_3_4[`BOUNDS(i,`IO_WIDTH)];

    wire[`DESTWIDTH       - 1 : 0] local_addr;
    wire[`NEXTHOPWIDTH    - 1 : 0] local_nhop;
    wire[`ROUTER_ID_WIDTH - 1 : 0] local_rid;
    wire[`DATA_TYPEWIDTH  - 1 : 0] local_type;

    assign local_addr = cur[`FIELD(`DEST_OFFSET,`DESTWIDTH)];
    assign local_nhop = cur[`FIELD(`NEXTHOP_OFFSET,`NEXTHOPWIDTH)];
    assign local_rid  = `HOME_NODE_MAPPING(cur, ROUTER_ID);
    assign local_type = cur[`FIELD(`TYPE_OFFSET,`DATA_TYPEWIDTH)];

    assign orig_addresses[`BOUNDS(i,`DESTWIDTH)]      = local_addr;
    assign orig_nhops[ `BOUNDS(i,`NEXTHOPWIDTH)]      = local_nhop;
    assign hm_router_ids[`BOUNDS(i,`ROUTER_ID_WIDTH)] = local_rid;
    assign hm_types[`BOUNDS(i,`DATA_TYPEWIDTH)]       = local_type;
  end

  hitmux #(
    .MEM_ADDRESS(MEM_ADDRESS),
    .ROUTER_ID(ROUTER_ID)
  ) hm (
    .clk(clk),
    .rst(rst),
    .hits(hits_stage_3_4),
    .orig_addresses(orig_addresses),
    .orig_nhops(orig_nhops),
    .addresses(results_stage_3_4),
    .router_ids(hm_router_ids),
    .types(hm_types),
    .out_types(out_types),
    .nhops(nhops_stage_3_4),
    .mem_nhops(mem_nhops_stage_3_4),
    .destout(destout), 
    .nhopout(nhopout)
  );

  wire[`TOTAL_WIDTH - 1 : 0] rtr_in;
  wire[`TOTAL_WIDTH - 1 : 0] rtr_out;

  for (i = 0; i < `NUM_INPUTS; i = i + 1) begin:SET_RTR_INPUTS
    wire [`IO_WIDTH - 1 : 0] cur;
    assign cur = stage_3_4[`BOUNDS(i,`IO_WIDTH)];

    integer r_addr = ROUTER_ID + `NUM_COMPUTE_NODES;

    wire [`DATA_DATAWIDTH - 1 : 0] data;
    wire [`SRCWIDTH - 1 : 0]       src;
    wire [`TYPEWIDTH - 1 : 0]      type;
    wire [`DESTWIDTH - 1 : 0]       dest;
    wire [`NEXTHOPWIDTH - 1 : 0]    nh;
    wire sendbit;
    wire sendokbit;
    wire lastbit;

    assign data      = cur[`FIELD(0,`DATA_DATAWIDTH)];
    assign src       = cur[`FIELD(`SRC_OFFSET,`SRCWIDTH)];
    assign type      = out_types[`BOUNDS(i,`TYPEWIDTH)];
    assign dest      = destout[`BOUNDS(i,`DESTWIDTH)];
    assign lastbit   = cur[`LASTBIT_OFFSET];
    assign nh        = nhopout[`BOUNDS(i,`NEXTHOPWIDTH)];
    assign sendbit   = (r_addr == dest) ? 1'b0 : cur[`SENDBIT_OFFSET];  // top two bits = sendbit, sendokbit
    assign sendokbit = cur[`SENDOKBIT_OFFSET];

    `ifdef DIRECTORY_BYPASS
      assign rtr_in[`BOUNDS(i,`IO_WIDTH)] = bypass[i] ? router_in[`BOUNDS(i,`IO_WIDTH)] : { sendokbit, sendbit, nh, lastbit, dest, src, type, data };
    `else
      assign rtr_in[`BOUNDS(i,`IO_WIDTH)] = { sendokbit, sendbit, nh, lastbit, dest, src, type, data };
    `endif
  end

  /* Now we take outputs from hitmux and pass them to the actual router */
  node #(
    .UNIFIED_ROUTELOOKUP(1),
    .ROUTES(ACTUAL_ROUTE)
  ) rtr(
    .clk(clk),
    .rst(rst),
    .iput(rtr_in),
    .oput(rtr_out)
  );

  assign router_out = rtr_out;

  `else //no dir
  for (i=0; i < `NUM_INPUTS; i = i + 1) begin:BUILD_DIR_WIRES2
    wire  [`IO_WIDTH - 1 : 0] msg_cur = router_in[`BOUNDS(i, `IO_WIDTH)];
    always @(posedge clk) begin

      if (msg_cur[`SENDBIT_OFFSET] == 1'b1 && 
        !(|(msg_cur[`FIELD(`NEXTHOP_OFFSET,`NEXTHOPWIDTH)])))   begin
        $display("[%m]: @ %d - Error: packet is valid but no nexthop bits set.", $time);
        $stop;
      end

      if (msg_cur[`SENDBIT_OFFSET] == 1'b1)   begin
        $display("[%m]: @ %d - packet received, type = %d, src = %d, dest = %d, data = %h, addr = %h, nhop = %h", 
          $time,
          msg_cur[`PKT_TYPE],
          msg_cur[`PKT_SRC],
          msg_cur[`PKT_DEST],
          msg_cur[`PKT_DATA],
          msg_cur[`PKT_ADDR],
          msg_cur[`PKT_NHOP]
        );
      end
    end
  end

  // No directory: just use the router 
  node #(
    .UNIFIED_ROUTELOOKUP(1),
    .ROUTES(ACTUAL_ROUTE)
  ) rtr(
    .clk(clk),
    .rst(rst),
    .iput(router_in),
    .oput(router_out)
  );

  `endif

endgenerate

endmodule
