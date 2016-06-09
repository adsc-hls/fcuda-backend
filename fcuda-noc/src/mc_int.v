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

// 
// mc_int.v
//
// Jacob Tolar
//
// mc_int is the output interface between the memory controller and the
// network on chip. It contains fifos which track the addresses the MiG
// controller is currently accessing as well as when the MiG responds
// with data.
//
// When a reponse comes from memory we take an element from the addr fifo,
// use it in order to respond to the correct node. 
// 

`include "noc_pkt.vh"
`timescale 1ns / 1ps

module mc_int #(
  parameter DEPTH = 2304,
  parameter ADDR_DATA_WIDTH = `IO_WIDTH,
  parameter ADDR_WIDTH = 32,
  parameter ADDR_DEPTH = 64,
  parameter DATA_WIDTH = 32,
  parameter DATA_DEPTH = 64,
  parameter ROUTE              = {32'h00000000, 32'h01000000, 32'h00000000, 32'h00000000}
)
(
  input wire clk,
  input wire rst,

  input wire                  rd_data_valid,
  input wire [DATA_WIDTH:0]   rd_data_fifo_out,

  input wire                  addr_valid,
  input wire [ADDR_DATA_WIDTH-1:0]  addr_data,
  output reg [`IO_WIDTH-1:0]  data_to_noc
);

`include "functions.vh"

localparam aff_log2_depthp1 = log2(ADDR_DEPTH+1);
localparam dff_log2_depthp1 = log2(DEPTH+1);

// states
localparam s_aff_empty    = 0;
localparam s_aff_read     = 1;
localparam s_dff_not_empty= 2;
localparam s_dff_rd_pkt   = 3;
localparam s_dff_send_pkt = 4;
localparam s_send_noc_pkt = 5;
localparam s_mem_delay    = 6;

reg[10:0] memory_delay_ctr;

wire dff_wren = rd_data_valid;
wire aff_wren = addr_valid;

reg aff_rden;
wire aff_empty;
wire aff_full;

wire [ADDR_DATA_WIDTH - 1 : 0] aff_wr_data;
wire [ADDR_DATA_WIDTH - 1 : 0] aff_rd_data;
wire [aff_log2_depthp1 - 1 : 0] aff_count;

reg dff_rden;
wire dff_empty;
wire dff_full;

wire [DATA_WIDTH -1 : 0] dff_wr_data;
wire [DATA_WIDTH -1 : 0] dff_rd_data;
wire [dff_log2_depthp1 - 1 : 0] dff_count;

// nexthop for data sent back to core
wire [`NEXTHOPWIDTH - 1 : 0] sel;
wire [`DESTWIDTH - 1 : 0] destaddr;

// nexthop for address sent back to update home node
wire [`NEXTHOPWIDTH - 1 : 0] sel_addr;
wire [`DESTWIDTH - 1 : 0] destaddr_addr;

// handle reading fifos
reg [2 : 0] state;

// number of packets we have sent (resets to 0)
reg [9 : 0] inner_pkt_count;
reg [9 : 0] outer_pkt_count;

reg [DATA_WIDTH-1:0] mig_reg;
reg [ADDR_DATA_WIDTH-1:0] aff_reg;

assign aff_wr_data = addr_data;
assign dff_wr_data = rd_data_fifo_out;

assign destaddr = aff_reg[`FIELD(`SRC_OFFSET, `SRCWIDTH)];
assign destaddr_addr = `NUM_COMPUTE_NODES + `HOME_NODE_MAPPING(aff_reg, destaddr);
wire [`DATA_AWIDTH-1:0] addr = aff_reg;

wire outer_pkt_count_minus_one = outer_pkt_count - 1;
wire outer_pkt_cmp = (outer_pkt_count_minus_one) == addr[4];
wire inner_pkt_cmp = (addr[3:2] == inner_pkt_count[1:0]);

// instantiate fifo
vfifo #(
.depth(DEPTH), 
.width(ADDR_DATA_WIDTH)
) addrfifo (
  .clk(clk),
  .rst(rst),
  .wren(aff_wren), 
  .rden(aff_rden),
  .empty(aff_empty),
  .full(aff_full),
  .wr_data(aff_wr_data),
  .rd_data(aff_rd_data),
  .count(aff_count)
);

// instantiate fifo
vfifo #(
.depth(DEPTH), 
.width(DATA_WIDTH)
) datafifo (
  .clk(clk),
  .rst(rst),
  .wren(dff_wren), 
  .rden(dff_rden),
  .empty(dff_empty),
  .full(dff_full),
  .wr_data(dff_wr_data),
  .rd_data(dff_rd_data),
  .count(dff_count)
);

genvar j;
generate
  for (j=0;j<`NEXTHOPWIDTH;j = j + 1) begin:REG_NHOP
    nextroute #(.ROUTE(ROUTE[`BOUNDS(j,`ROUTE_WIRE_WIDTH)])) nr
      (.clk(clk), 
       .rst(rst),
       .ce(1'b1),
       .destaddr(destaddr),
       .sel(sel[j])
      );
  end
endgenerate

`ifdef ENABLE_DIRECTORIES 
generate
  // if directories are enabled, then we need to also generate NHOP to send
  // packet back to update directory
  for (j=0;j<`NEXTHOPWIDTH;j = j + 1) begin:ADDR_NHOP
    nextroute #(
      .ROUTE(ROUTE[`BOUNDS(j,`ROUTE_WIRE_WIDTH)])
    ) nr (
      .clk(clk), 
      .rst(rst),
      .ce(1'b1),
      .destaddr(destaddr_addr),
      .sel(sel_addr[j])
    );
  end
endgenerate
`endif

always @(posedge clk) begin
  if (dff_rden) 
    mig_reg <= dff_rd_data;
  if (aff_rden)
    aff_reg <= aff_rd_data;
end


always@(state)begin
  $display("[%m] at %t, state number = 0x%x", $time, state);
end

always @(posedge clk) begin
  if (rst) begin
    state <= s_aff_empty;
    inner_pkt_count <= 10'b0;
    outer_pkt_count <= 10'b0;
    memory_delay_ctr <= 10'b0;
    dff_rden <= 1'b0;
    aff_rden <= 1'b0;
    data_to_noc <= 
        ({`IO_WIDTH{1'bX}} | (1 << `SENDOKBIT_OFFSET)) & (~(1 << `SENDBIT_OFFSET))  ;
end else begin
    case(state)
      // wait for fifo to fill
      s_aff_empty: begin
        if((!aff_empty))begin
          state <= s_aff_read;
          memory_delay_ctr <= 10'b0;
          // read the fifo
          aff_rden <= 1'b1;
          dff_rden <= 1'b0;
        end
        else begin
          state <= s_aff_empty;
          dff_rden <= 1'b0;
          aff_rden <= 1'b0;
          data_to_noc <= 
              ({`IO_WIDTH{1'bX}} | (1 << `SENDOKBIT_OFFSET)) & (~(1 << `SENDBIT_OFFSET))  ;
        end
      end

      // read afifo into reg
      s_aff_read: begin
        state <= s_dff_not_empty;
        dff_rden <= 1'b0;
        aff_rden <= 1'b0;
      end
      // wait for dfifo to have data
      s_dff_not_empty: begin         
        if (!dff_empty) begin
          state <= s_dff_rd_pkt;
          dff_rden <= 1'b1;
        end
        aff_rden <= 1'b0;
      end
      // read a pkt from dff
      s_dff_rd_pkt: begin
        state <= s_dff_send_pkt;
        dff_rden <= 1'b0;
        // SENDBIT   - always 1
        // SENDOKBIT - 1 when packet is valid [only when addr match]
        // NHOP      - comes from nhop modules
        //           - computed based on the SRC_ADDR of request
        // LASTBIT   - always 1 (for now)
        // DEST      - set to the SRC_ADDR of the request
        // SRC       - also SRC_ADDR of request
        //           - SRC field is used by directory when updating!
        // TYPE      - set to TYPE_RESPONSE_DATA
        // DATA      - set to the MIG data
        // ADDR      - set to input address
        $display("[%m] at %t, MC_INT Memory response received: addr = %h, data = %h, dest_node = %d; outer_pkt_cmp = %d; inner_pkt_cmp = %d; cmp = %d", $time, aff_reg[`FIELD(`DATA_A_OFFSET, `DATA_AWIDTH)], dff_rd_data, 
            destaddr, outer_pkt_cmp, inner_pkt_cmp, (outer_pkt_cmp & inner_pkt_cmp));
        data_to_noc <= {1'b1, 
                        1'b1,
                        sel,
                        1'b1,
                        destaddr,
                        destaddr,
                        `TYPE_RESPONSE_DATA,
                        dff_rd_data,
                        aff_reg[`FIELD(`DATA_A_OFFSET, `DATA_AWIDTH)]  
                       };
      end

      s_dff_send_pkt: begin
        `ifdef ENABLE_DIRECTORIES
          // if we are using directories, send update packet
          state <= s_send_noc_pkt;
          // SENDBIT   - always 1
          // SENDOKBIT - always 1
          // NHOP      - comes from nhop modules
          //           - computed based on `NUM_COMPUTE_NODES +
          //           - ADDR[`ROUTER_ID_LOW ...] => basically, compute the
          //           - address of the home node; that is NHOP 
          // LASTBIT   - always 1 (for now)
          // DEST      - set to the HOME NODE of the request (see NHOP)
          // SRC       - also SRC_ADDR of request
          //           - SRC field is used by directory when updating!
          // TYPE      - set to TYPE_RESPONSE_ADDR
          // DATA      - irrelevant here!!
          // ADDR      - set to input address
          $display("[%m] at %t, MC_INT Sending update to home node;  addr = %h, data = %h, dest_node = %d",
            $time, aff_reg[`FIELD(`DATA_A_OFFSET, `DATA_AWIDTH)],  aff_reg[`FIELD(`DATA_A_OFFSET, `DATA_AWIDTH)], destaddr_addr);
          data_to_noc <= {1'b1,
                          1'b1,
                          sel_addr,
                          1'b1,
                          destaddr_addr,
                          destaddr,
                          `TYPE_RESPONSE_ADDR,
                          32'b0,
                          aff_reg[`FIELD(`DATA_A_OFFSET, `DATA_AWIDTH)]
                         };
        `else
          // else, just go back to empty state
          state <= s_mem_delay;
          data_to_noc <= ({`IO_WIDTH{1'bX}} | (1 << `SENDOKBIT_OFFSET)) & (~(1 << `SENDBIT_OFFSET))  ;
        `endif
      end
      // send a packet to update home node; then, done
      s_send_noc_pkt: begin
        state <= s_mem_delay;
      end
      s_mem_delay: begin
        memory_delay_ctr <= memory_delay_ctr + 1;
        if (memory_delay_ctr == 0) begin
          state <= s_aff_empty;
          dff_rden <= 1'b0;
          aff_rden <= 1'b0;
          data_to_noc <= 
              ({`IO_WIDTH{1'bX}} | (1 << `SENDOKBIT_OFFSET)) & (~(1 << `SENDBIT_OFFSET))  ;
        end else begin
          state <= s_mem_delay;
        end
      end
    endcase
  end
end
endmodule
