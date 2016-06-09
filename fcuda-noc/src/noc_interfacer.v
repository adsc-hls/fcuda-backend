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

// This interface can handle single reads + writes

module noc_interfacer #(
  parameter [`DESTWIDTH - 1 : 0] NODE_ID                      = {`DESTWIDTH{1'b0}},
  parameter [`DESTWIDTH - 1 : 0] MEM_ID                       = {`DESTWIDTH{1'b0}}, // id of memory node
  parameter [`NEXTHOPWIDTH * `ROUTE_WIRE_WIDTH - 1 : 0] ROUTE = {`NEXTHOPWIDTH * `ROUTE_WIRE_WIDTH{1'b0}}
)(
  input wire [`NUM_BRAMS * `BRAM_TAG_ADDRWIDTH - 1 : 0] bram_index,
  input wire addr_matched,
  /* mem ctrl outputs */
  output wire  wr_ready,
  output reg rd_valid,
  output reg [ `DATA_DWIDTH -1 : 0 ] rd_data,
  
  /* inputs */
  input wire wrNotRd,
  input wire pe_req,
  input wire rd_ack,

  input wire clk,
  input wire rst,
  input wire ap_done,

  input wire [ `DATA_AWIDTH - 1 : 0 ] address,
  input wire [ `DATA_DWIDTH - 1 : 0] wr_data,
  input wire [ `DATA_DWIDTH - 1 : 0 ] size,

  /* inputs from router */
  input wire  [ `IO_WIDTH-1:0 ] router_input,

  /* outputs to router */
  output wire [ `IO_WIDTH-1:0 ] router_output
);

wire [`DATA_AWIDTH - 1 : 0] byte_addr = address << 2;

wire rd_valid1;
wire [ `DATA_DWIDTH -1 : 0 ] rd_data1;

// we need to store everything in registers - 
// nexthop calculation has a cycle delay
reg wrNotRd_reg;
reg pe_req_reg;
reg rd_ack_reg;
reg is_write_reg; 
reg is_done_reg;
reg is_read_reg;

reg [`DATA_AWIDTH-1:0] address_reg;
reg [`DATA_DWIDTH-1:0] wr_data_reg;
reg [`DATA_AWIDTH-1:0] size_reg;
reg [`DESTWIDTH-1:0]   r_dest_reg; 

/* 
 * protocol of ap_bus is approximately as follows:
 *
 *   Write:         
 *                    ___     ___
 *       clk        _/   \___/   \
 *                    ______
 *       wrNotRd    _/      \_ 
 *                    ______ 
 *       peRq       _/      \_
 *
 *   Read: 
 *                    ___     ___
 *       clk        _/   \___/   \
 *                          
 *       wrNotRd    ____________
 *                    ______ 
 *       peRq       _/      \__
 */

wire is_write = (wrNotRd == 1'b1 && pe_req == 1'b1);
wire is_read  = (wrNotRd == 1'b0 && pe_req == 1'b1);
 
// For reads, default destination is home node [ a router ]
// For writes, default destination is memory node

wire [ `DESTWIDTH-1:0 ] home_node = `NUM_COMPUTE_NODES + `HOME_NODE_MAPPING(byte_addr, NODE_ID); 

always @(home_node) begin
  $display("[%m] CHECK HOME_NODE home_node=%d, addr=%h, byte_addr=%h", home_node, address, byte_addr);
end

`ifdef ENABLE_DIRECTORIES
// if directories are enabled: send to either MEM node or home node
// Reads are sent to home node, writes are sent to MEM node
wire [ `DESTWIDTH-1:0 ] r_dest = (is_write || ap_done) ? MEM_ID : home_node;
`else
// If directories are not enabled, send all requests to memory node
wire [ `DESTWIDTH-1:0 ] r_dest = MEM_ID; 
`endif


wire fifo_empty;
wire fifo_read = (count == 1) && (!fifo_empty);
reg [31 : 0] count = 0;
wire [`IO_WIDTH - 1 : 0 ] router_output_q_wr;
wire [`IO_WIDTH - 1 : 0 ] router_output_q_rd;
reg [`IO_WIDTH - 1 : 0 ] router_output_reg;

wire [`DATA_AWIDTH - 1 : 0] address_q;
assign addr_matched = rd_valid1 && (address_q == (router_input[`PKT_ADDR] >> 2));

wire addr_mismatched = rd_valid1 && (address_q != (router_input[`PKT_ADDR] >> 2));
reg addr_mismatched_reg;
reg [`IO_WIDTH - 1 : 0] router_input_reg;

vfifo #(
  .depth(64),
  .width(`DATA_AWIDTH)
) packet_fifo (
  .clk(clk),
  .rst(rst),
  .wren(is_read), 
  .rden(addr_matched),
  .empty(),
  .full(),
  .wr_data(address),
  .rd_data(address_q),
  .count()
);

always @(posedge clk) begin
  if (addr_matched) begin
    rd_valid <= rd_valid1;
    rd_data <= rd_data1;
  end
  else begin
    rd_valid <= 0;
    rd_data <= 0;
  end
end

always @(posedge clk) begin
  //If the incoming packet has address mismatched the expected address, deflect it
  if (addr_mismatched) begin
    addr_mismatched_reg <= 1;
    router_input_reg <= router_input;
  end
  else
    addr_mismatched_reg <= 0;
end

always @(posedge clk) begin
  if (addr_mismatched_reg)
    $display("[%m] Deflect packet at %t: router_ouput=%h, address_fifo=%h", $time, router_output, address_q);
  if (addr_matched)
    $display("[%m] Got packet matched at %t: router_input=%h, address_fifo=%h, rd_valid=%d, rd_valid1=%d", $time, router_input, address_q, rd_valid, rd_valid1);
end

always @(posedge clk) begin
  if (is_read) begin
    $display("[%m] CHECK BRAM_INDEX at %t, bram_index=%h, address=%h", $time, bram_index, address);
  end
end

// generate nexthop for packet
wire [`NEXTHOPWIDTH-1:0]  resp_nhop;
genvar j;
generate
  for (j =0; j < `NEXTHOPWIDTH; j = j + 1) begin:outer
    nextroute #(
      .ROUTE(ROUTE[`PBOUNDS(j, `ROUTE_WIRE_WIDTH)])
    ) nhop_1( 
      .clk(clk), 
      .rst(rst), 
      .ce(1'b1), 
      .destaddr ((!addr_mismatched) ? r_dest : NODE_ID) , 
      .sel (resp_nhop[j])
    );
  end
endgenerate

// delay all signals by a cycle: nexthop takes one cycle
always @(posedge clk) begin
  wrNotRd_reg <= wrNotRd;
  pe_req_reg  <= pe_req | ap_done;
  rd_ack_reg  <= rd_ack;
  address_reg <= byte_addr;
  wr_data_reg <= wr_data;
  size_reg    <= size;

  r_dest_reg   <= r_dest;
  is_write_reg <= is_write;
  is_done_reg <= ap_done;
  is_read_reg <= is_read;
end

// return data to core if valid bit set
assign rd_valid1 = router_input[`SENDBIT_OFFSET ] && (router_input[`PKT_TYPE] == `TYPE_RESPONSE_DATA) && (router_input[`PKT_DEST]==NODE_ID);
assign rd_data1 = router_input[`DATA_DWIDTH + `DATA_D_OFFSET -1:`DATA_D_OFFSET];

//back pressure signal from router FIFO. If the watermark point is passed,
//the core is notified to stop writing
assign wr_ready = router_input[`SENDOKBIT_OFFSET];

// setup remaining outputs to NoC
wire                         r_sendokbit = 1'b1;           // can be always 1 for now
wire                         r_lastbit   = 1'b1;           // can be always 1 for now

wire [ `DATA_SRCWIDTH-1:0 ]  r_src       = NODE_ID;        // src is self
wire [ `DATA_TYPEWIDTH-1:0 ] r_type      = is_done_reg ? `TYPE_DONE : (is_write_reg ? `TYPE_WRITE : `TYPE_REQUEST); 

/* 
 * form NoC packet
 *
 * Fields: 
 *   sendok    : always 1 for now - FCUDA cores don't support flow control
 *   sendokbit : pe_req_reg - only 1 when reading / writing
 *   nexthop   : set up above
 *   lastbit   : always 1 for now
 *   dest      : home node / mem node, depending on request type
 *   src       : current node id
 *   type      : depends on request type
 *   data      : input data from core
 *   addr      : input addr from core, adjusted to make it a byte address
*/
noc_sender nsend(
  .sendokbit(r_sendokbit),
  .sendbit((!addr_mismatched_reg) ? pe_req_reg : router_input_reg[`SENDBIT_OFFSET]),
  .nhop(resp_nhop),
  .lastbit(r_lastbit),
  .dest((!addr_mismatched_reg) ? r_dest_reg : router_input_reg[`PKT_DEST]),
  .src((!addr_mismatched_reg) ? r_src : router_input_reg[`PKT_SRC]),
  .type((!addr_mismatched_reg) ? r_type : router_input_reg[`PKT_TYPE]),
  .data((!addr_mismatched_reg) ? ((is_write_reg) ? wr_data_reg[`DATA_DWIDTH-1:0] : bram_index) : router_input_reg[`PKT_DATA]),
  .addr((!addr_mismatched_reg) ? address_reg[`DATA_AWIDTH-1:0] : router_input_reg[`PKT_ADDR]),
  .out(router_output)
);

endmodule
