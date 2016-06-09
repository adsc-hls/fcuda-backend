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

module bram_controller #(
  parameter [`DESTWIDTH - 1 : 0] NODE_ID                      = {`DESTWIDTH{1'b0}},
  parameter [`DESTWIDTH - 1 : 0] MEM_ID                       = {`DESTWIDTH{1'b0}},
  parameter [`NEXTHOPWIDTH * `ROUTE_WIRE_WIDTH - 1 : 0] ROUTE = {`NEXTHOPWIDTH * `ROUTE_WIRE_WIDTH{1'b0}},
  parameter TAG_FIFO_DEPTH                                    = 64,
  parameter TAG_FIFO_WIDTH                                    = `IO_WIDTH
)( 
input wire                                             clk,                   // clk
input wire                                             rst,                   // rst
input wire  [`IO_WIDTH - 1 : 0]                        noc_line_in,           // data from NoC
output wire [`IO_WIDTH - 1 : 0]                        noc_line_out,          // data to NoC
input wire  [`NUM_BRAMS * `BRAM_TAG_DATAWIDTH - 1 : 0] bram_tag_input,        // input from tag BRAM: used
output wire [`NUM_BRAMS * `BRAM_TAG_ADDRWIDTH - 1 : 0] bram_tag_rd_addr_out,  // address for tag BRAM reads
input  wire [`NUM_BRAMS * `BRAM_DATA_DATAWIDTH - 1 : 0] bram_data_input,      // data returned from data BRAM to send to NoC
output wire [`NUM_BRAMS * `BRAM_DATA_ADDRWIDTH - 1 : 0] bram_data_addr_out    // index for data BRAM
);

`include "functions.vh"

// wires, etc for the dingus
localparam s_reset = 2'b00, s_count = 2'b01, s_read = 2'b10; 

`ifdef ENABLE_OA_TIMEOUT
localparam s_send=2'b11;
`endif

reg [1:0]                         q_state;
reg [20:0]                        q_waitcount;
reg[`IO_WIDTH-1:0]                q_out;
reg                               sendable;
reg                               earlysendable;
reg                               q_rden;

reg [`IO_WIDTH-1:0]               delayed_input; // copy of input delayed by a cycle as BRAM takes a cycle to read
reg [`IO_WIDTH-1:0]               delayed_noc_in; // copy of input delayed by a cycle as BRAM takes a cycle to read
reg [`DATA_AWIDTH - 1 : 0]        delayed_addr;
reg [`BRAM_TAG_TAGWIDTH - 1 : 0]  delayed_tag;
reg [`TYPEWIDTH - 1 : 0]          delayed_type;
reg                               delayed_sendbit;

wire [`IO_WIDTH-1:0]               tag_fifo_pkt_out;

wire[`IO_WIDTH-1:0]                q_out_w;
wire[`IO_WIDTH-1:0]                q_in_w;
wire                               q_wren;
wire                               q_empty;
wire                               q_full;
wire [`DATA_AWIDTH - 1 : 0]        input_addr;  // split addr into fields

`ifndef ENABLE_OA_TIMEOUT
wire q_match_prev;
wire q_match_bram;

wire [`DATA_AWIDTH - 1 : 0]        q_addr;  // split addr into fields
wire [`BRAM_TAG_TAGWIDTH - 1 : 0]  q_tag;

reg [`BRAM_TAG_TAGWIDTH - 1 : 0]  delayed_q_tag;
reg                               block_first_transfer;
reg                               block_first_transfer_delayed;

wire [`DATA_SRCWIDTH -1 : 0 ]      q_src;
`endif

wire q_match_incoming;

wire [`BRAM_TAG_TAGWIDTH - 1 : 0]  input_tag;
wire [`TYPEWIDTH - 1 : 0]          input_type;
wire                               input_sendbit;
wire [`DATA_SRCWIDTH -1 : 0 ]      input_src;
wire                               input_sel;
wire [`IO_WIDTH-1:0]               selected_input ;
wire [`NUM_BRAMS - 1 : 0]          tagcmp_results;  // place to hold results for tag comparision
wire                               result_found;

assign input_sel      = (!noc_line_in[`SENDBIT_OFFSET]) && sendable;

assign selected_input = input_sel ? q_out : noc_line_in;
assign input_addr     = selected_input[`PKT_ADDR]; 

`ifndef ENABLE_OA_TIMEOUT
assign q_addr         = q_out[`PKT_ADDR];
assign q_src          = q_out[`PKT_SRC];
assign q_tag          = q_addr[`ADDR_TAG]; // based on input_addr, so selection already done - no need to check
`endif

assign input_tag      = input_addr[`ADDR_TAG]; // based on input_addr, so selection already done - no need to check
assign input_type     = input_sel ? `TYPE_C_REQ : noc_line_in[`PKT_TYPE];  // Convert type OUTSTANDING ---> C_REQ
assign input_sendbit  = selected_input[`SENDBIT_OFFSET];
assign input_src      = selected_input[`PKT_SRC];

// put input through a register (or two...)
always@(posedge clk) begin : DELAY_INPUT
  if (rst == 1'b1) begin
    delayed_input <= 0;
    delayed_tag <= 0;
    delayed_noc_in <= 0;
    delayed_addr <= 0;
    delayed_type <= 0;
    delayed_sendbit <= 0;
  end else begin
    delayed_input            <= selected_input;
    delayed_noc_in           <= noc_line_in;
    delayed_tag              <= input_tag;
    `ifndef ENABLE_OA_TIMEOUT
    block_first_transfer_delayed <= block_first_transfer;
    delayed_q_tag              <= q_tag;
    `endif
    // FIXME: Should be generic
    delayed_addr             <= input_addr;
    delayed_type             <= input_type;
    delayed_sendbit          <= input_sendbit;
  end
end

// set the index - same for both data/tag fields now / accessed in parallel
`ifndef ENABLE_OA_TIMEOUT
assign bram_tag_rd_addr_out  = input_sendbit ? selected_input[`PKT_DATA] : q_out[`PKT_DATA];
assign bram_data_addr_out = input_sendbit ? selected_input[`PKT_DATA] : q_out[`PKT_DATA];
`else
assign bram_tag_rd_addr_out  = selected_input[`PKT_DATA];
assign bram_data_addr_out = selected_input[`PKT_DATA];
`endif

genvar j;

generate
  // set outputs: addr are all 'input_index', tag are all 'input_tag'
  for (j = 0; j < `NUM_BRAMS; j = j + 1) begin : SET_BRAM_ADDRESSES_COMPARE_TAGS
    wire [`BRAM_TAG_DATAWIDTH-1:0] cur       = bram_tag_input[`PBOUNDS(j,`BRAM_TAG_DATAWIDTH)];
    wire                           cur_valid = cur[`BRAM_TAG_DATAWIDTH - 1];
    wire [`BRAM_TAG_TAGWIDTH-1:0]  cur_tag   = cur[`BRAM_TAG_TAGWIDTH  - 1 : 0];
    `ifndef ENABLE_OA_TIMEOUT
    assign tagcmp_results[j] = delayed_sendbit ?      ({1'b1,delayed_tag} == {cur_valid,cur_tag}) : ({1'b1,delayed_q_tag} == {cur_valid,cur_tag});     // tag comparison
    `else
    assign tagcmp_results[j] =  ({1'b1,delayed_tag} == {cur_valid,cur_tag}); // tag comparison
    `endif
  end
endgenerate

// encoder to generate mux select signals
// input : tagcmp_results [delayed]
// output: mux_sel
wire [clogb2(`NUM_BRAMS) - 1 : 0] mux_sel;
encoder #(
  .n(`NUM_BRAMS),            /* number of inputs: 2 1-hot */
  .m(clogb2(`NUM_BRAMS))     /* outputs: 1 bit == 0 or 1 */
) enc (
  .a(tagcmp_results),
  .b(mux_sel)
);

// mux to choose which bram we are reading from
wire [`BRAM_DATA_DATAWIDTH - 1 : 0] muxdataout;
varmux #(
  .num_inputs(`NUM_BRAMS),
  .width(`BRAM_DATA_DATAWIDTH)
) vm (
  .in_bus(bram_data_input),  
  .sel(mux_sel), 
  .out(muxdataout)
);

assign result_found =  (|(tagcmp_results));

//  Now, the type can be EITHER TYPE_C_REQ or TYPE_OUTSTANDING
wire sendbit_2    =  ((delayed_type == `TYPE_C_REQ)  && delayed_sendbit == 1'b1);
wire out_sendbit  = (((delayed_type == `TYPE_C_REQ || (delayed_type ==`TYPE_OUTSTANDING))) && delayed_sendbit == 1'b1) && (|(tagcmp_results));

wire [`NEXTHOPWIDTH-1:0]  resp_nhop;
wire [`NEXTHOPWIDTH-1:0]  mem_nhop;

reg [`NEXTHOPWIDTH-1:0]  resp_nhop_reg;
reg [`NEXTHOPWIDTH-1:0]  mem_nhop_reg;

always@(posedge clk) begin
  resp_nhop_reg <= resp_nhop;
  mem_nhop_reg  <= mem_nhop;
end

// NEXTHOP for return trip
generate
  for (j =0; j < `NEXTHOPWIDTH; j = j + 1) begin:outer
    nextroute #(
      .ROUTE(ROUTE[`PBOUNDS(j, `ROUTE_WIRE_WIDTH)])
    ) nhop_1( 
    .clk(clk), 
    .rst(rst), 
    .ce(1'b1),  
    `ifndef ENABLE_OA_TIMEOUT
    .destaddr (input_sendbit ? input_src : q_src),  // destination
    `else
    .destaddr (input_src),  // destination
    `endif
    .sel (resp_nhop[j])
    );
  end
endgenerate

// NEXTHOP for memory
generate
  for (j =0; j < `NEXTHOPWIDTH; j = j + 1) begin:nexthop_mem
    nextroute #(
      .ROUTE(ROUTE[`PBOUNDS(j, `ROUTE_WIRE_WIDTH)])
    ) nhop_1( 
    .clk(clk), 
    .rst(rst), 
    .ce(1'b1), 
    .destaddr (MEM_ID) ,  // destination
    .sel (mem_nhop[j])
  );
  end
endgenerate

wire send_pkt_early; 
// for debugging: printout when we get a BRAM hit
always @(posedge clk) begin
  if ((result_found && out_sendbit == 1)) begin
    $display("[%m] [%d]: BRAM controller responding with addr / data: 0x%8x: 0x%8x to node %d", $time,  delayed_input[`PKT_ADDR], muxdataout, delayed_input[`PKT_SRC]);
  end else if (sendbit_2) begin
    $display("[%m] [%d]: BRAM controller redirecting packet to memory, not found: addr=0x%8x, req node=%d", $time, delayed_input[`PKT_ADDR],delayed_input[`PKT_SRC] );
  end

  if (send_pkt_early) begin
    `ifndef  ENABLE_OA_TIMEOUT
    $display("[%m] [%d]: BRAM controller earlyresponding with addr / data: 0x%8x: 0x%8x to node %d, [%d][%d][%d]", $time,  q_out[`PKT_ADDR], delayed_noc_in[`PKT_DATA], q_out[`PKT_SRC],q_match_incoming,q_match_bram,q_match_prev);
    `else
    $display("[%m] [%d]: BRAM controller earlyresponding with addr / data: 0x%8x: 0x%8x to node %d", $time,  q_out[`PKT_ADDR], delayed_noc_in[`PKT_DATA], q_out[`PKT_SRC]);
    `endif
end

  `ifndef ENABLE_OA_TIMEOUT
  if (send_pkt_early && result_found && delayed_sendbit) begin
    $display("ERROR [%d]: Unexpected condition in BRAM_CONTROLLER",$time);
    $stop;
  end
  `else
  if (send_pkt_early && result_found) begin
    $display("ERROR [%d]: Unexpected condition in BRAM_CONTROLLER %d %d %d",$time, send_pkt_early, result_found, out_sendbit);
    $stop;
  end
  `endif
end

  `ifndef ENABLE_OA_TIMEOUT
reg [`IO_WIDTH-1:0] pkt_early_reg;
always @(posedge clk) begin
  if (rst) begin
    pkt_early_reg <= 0;
  end else if (send_pkt_early) begin
    pkt_early_reg <= { 1'b1,     /* sendok bit */
    q_out[`PKT_SENDBIT],
    q_out[`PKT_NHOP],
    1'b1,
    q_out[`PKT_SRC],
    q_out[`PKT_DEST],
    `TYPE_RESPONSE_DATA,
    (q_match_prev ? pkt_early_reg[`PKT_DATA] : q_match_bram ? muxdataout :  delayed_noc_in[`PKT_DATA]),

    q_out[`PKT_ADDR] } ;
  end
end
`endif

assign noc_line_out =  (send_pkt_early === 1'b1) ?
  {1'b1,     /* sendok bit */
  q_out[`PKT_SENDBIT],
  q_out[`PKT_NHOP],
  1'b1,
  q_out[`PKT_SRC],
  q_out[`PKT_DEST],
  `TYPE_RESPONSE_DATA,
  `ifndef ENABLE_OA_TIMEOUT
  (q_match_prev ? pkt_early_reg[`PKT_DATA] : q_match_bram ? muxdataout :  delayed_noc_in[`PKT_DATA]),
  `else
  delayed_noc_in[`PKT_DATA],
  `endif
  q_out[`PKT_ADDR]}  : 

  (result_found === 1'b1) ?  
  {1'b1,   // HIT
  out_sendbit,
  resp_nhop,
  1'b1, 
  delayed_input[`PKT_SRC],
  delayed_input[`PKT_DEST],
  `TYPE_RESPONSE_DATA,
  muxdataout, /* should already be delayed */
  delayed_input[`PKT_ADDR]} : 

  {1'b1,  // MISS
  sendbit_2,
  mem_nhop,
  1'b1, 
  MEM_ID,                  // dest: memory
  delayed_input[`PKT_SRC], // source: original source
  `TYPE_REQUEST,
  delayed_input[`PKT_DATA],
  delayed_input[`PKT_ADDR]};

// if delayed-Type == TYPE_OUTSTANDING and 
// delayed-sendbit == 1 
// AND is a miss ==> out_sendbit == 0
// THEN: 
//   Enqueue it 
//   Read it into a register 
//   When data comes in
//     If there is an address match => send the packet out with data, else
//     send out as request
//   Else, if data never comes in, then quit after some # cycles

assign q_wren = (delayed_noc_in[`PKT_SENDBIT] == 1) && 
        (delayed_noc_in[`PKT_TYPE] == `TYPE_OUTSTANDING) && 
        (delayed_noc_in[`PKT_DEST] == NODE_ID) && 
        (!out_sendbit);   // if BC is responding immediately, don't write to queue!

// send the packet it it valid and address matches => send packet with data
`ifndef ENABLE_OA_TIMEOUT
// match OA request with incoming packets
assign q_match_incoming = ((q_out[`PKT_SENDBIT] == 1) &&
        (q_out[`PKT_ADDR]    == delayed_noc_in[`PKT_ADDR]) &&
        (delayed_noc_in[`PKT_TYPE] == `TYPE_RESPONSE_DATA) && 
        (delayed_noc_in[`PKT_SENDBIT] == 1)); 

// match OA request with BRAM contents
assign q_match_bram     = (delayed_sendbit != 1) &&     // don't conflict with incoming packet
        (q_out[`PKT_SENDBIT] == 1) &&                   // only match when q_out is valid
        (result_found == 1) && 
        (block_first_transfer_delayed == 0);            // only match when we get tagmatch from BRAM

// match OA request with previous response
assign q_match_prev     = (delayed_sendbit != 1) &&                       // don't conflict with incoming packet
        (q_out[`PKT_SENDBIT] == 1) &&                   // only match if q_out contains valid packet
        (pkt_early_reg[`PKT_SENDBIT] == 1)  &&          // 
        (pkt_early_reg[`PKT_ADDR] == q_out[`PKT_ADDR]); 


assign send_pkt_early = earlysendable && (q_match_incoming   || q_match_bram || q_match_prev); 
`else
assign q_match_incoming = ((q_out[`PKT_SENDBIT] == 1) &&
          (q_out[`PKT_ADDR] == delayed_noc_in[`PKT_ADDR]) &&
          (delayed_noc_in[`PKT_TYPE] == `TYPE_RESPONSE_DATA) && 
          (delayed_noc_in[`PKT_SENDBIT] == 1)); 
assign send_pkt_early = earlysendable && (q_match_incoming );
`endif

/* 
* We keep a FIFO of outstanding requests that come in from the network
*
* Currently, when a request comes in it is put in the FIFO
* Then, many cycles later, we read from the FIFO and try to do a lookup
* in the BRAMs. 
*
* We wait several cycles because the request is outstanding - so we want to
* give it some time to return from memory. 
*
* The basic design is a FIFO and then a state machine that reads the FIFO
* and sends requests.
*/

vfifo #(
.depth(64),
.width(`IO_WIDTH)
) outstanding_q (
  .clk(clk),
  .rst(rst),
  .wren(q_wren),
  .rden(q_rden),
  .empty(q_empty),
  .full(q_full),
  .rd_data(q_out_w),
  .wr_data({delayed_noc_in[`PKT_SENDOKBIT],
  delayed_noc_in[`PKT_SENDBIT],
  resp_nhop,
  delayed_noc_in[`PKT_LASTBIT],
  delayed_noc_in[`PKT_DEST],
  delayed_noc_in[`PKT_SRC],
  delayed_noc_in[`PKT_TYPE],
  delayed_noc_in[`PKT_DATA],
  delayed_noc_in[`PKT_ADDR]}),
  .count()
);

always @(q_state) begin
  $display("[%m] at %t, BRAM CONT state=%d", $time, q_state);
end

reg q_reg_reset;
always@(posedge clk) begin
  if (rst | q_reg_reset   ) begin
    q_out <= 1 << `SENDOKBIT_OFFSET;
  end else begin
    if(q_rden) begin
      q_out <= q_out_w;
    end
  end
end

always@(posedge clk) begin
  if (rst) begin
    q_state <= s_reset;
    q_waitcount <= 0;
    q_reg_reset <= 1;
    earlysendable <= 0;
    sendable <= 0;
    q_rden <= 0;
  end else begin
    case(q_state)
      s_reset: begin
        q_waitcount <= 0;
        if (q_empty) begin
          q_state <= s_reset;
          q_reg_reset <= 1;
          earlysendable <= 0;
          sendable <= 0;
          q_rden <= 0;
          `ifndef ENABLE_OA_TIMEOUT
          block_first_transfer <= 0;
          `endif
        end
        else begin
          q_state <= s_read;
          q_reg_reset <= 0;
          earlysendable <= 0;
          sendable <= 0;
          q_rden <= 1;
          `ifndef ENABLE_OA_TIMEOUT
          block_first_transfer <= 1;
          `endif
        end
      end
      s_read: begin
        q_state <= s_count;
        sendable <= 0;
        earlysendable <= 1;
        q_rden <= 0;
        `ifndef ENABLE_OA_TIMEOUT
        block_first_transfer <= 0;
        `endif
      end
      // read queue into register
      s_count: begin
        q_waitcount <= q_waitcount + 1;
        if (send_pkt_early) begin
          // packet was sent early, we can go on to next state
          q_state <= s_reset;
          q_reg_reset <= 1;
          earlysendable <= 0;
          sendable <= 0;
          q_rden <= 0;
        end
        // wait to send the packet
        // nominally this waiting period is because the data could be at the
        // memory controller and not back to the node yet
        //
        // this parameter can posssibly be adjusted in order to tune
        // performance
        `ifdef ENABLE_OA_TIMEOUT
        else if (q_waitcount > `OA_WAIT_DELAY) begin
          q_state <= s_send;
          earlysendable <= 0;
          sendable <= 1;
          q_rden <= 0;
        end
        `endif
        else begin
          q_state <= s_count;
          sendable <= 0;
          earlysendable <= 1;
          q_rden <= 0;
          `ifndef ENABLE_OA_TIMEOUT
          block_first_transfer <= 0;
          `endif
        end
      end
      `ifdef ENABLE_OA_TIMEOUT
      s_send: begin
        $display("[%m] SENT PACKET EARLY at %t, noc_line_in=%h, q_waitcount=%d", $time, noc_line_in, q_waitcount);
        q_waitcount <= 0;
        if (noc_line_in[`SENDBIT_OFFSET]) begin
          q_state <= s_send;
          earlysendable <= 0;
          sendable <= 1;
          q_rden <= 0;
        end
        else begin
          q_state <= s_reset;
          q_reg_reset <= 1;
          earlysendable <= 0;
          sendable <= 0;
          q_rden <= 0;
        end
      end
      `endif
    endcase
  end
end

endmodule
