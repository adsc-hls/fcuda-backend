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
// There are 5 registers, one for each input port
// Each can be written by only that input port...
// However, each can *compare* to every register


module outstanding_array #(
  parameter REG_WIDTH      = 30,
  parameter ROUTER_ID      = 0 
)(
  input wire  [`NUM_PORTS - 1 : 0] we,

  input wire  [`NUM_PORTS*`IO_WIDTH - 1 : 0] di,

  output reg  [`NUM_PORTS*`IO_WIDTH - 1 : 0] dout,
  output wire [`NUM_PORTS - 1 : 0] wasreplaced,

  input wire clk,
  input wire rst
);

genvar j;
genvar k;

wire [`DATA_AWIDTH * `NUM_PORTS -1 : 0] addrs;

// we must use a larger tag as we do not have an index..
// However we can still ignore bottom bits (directory id, offset)
localparam local_tagwidth = `INDEX_WIDTH + `TAG_WIDTH;

wire [local_tagwidth * `NUM_PORTS -1 : 0] tags;

// register must store [valid][tag][dest]
localparam reg_width = 1 + local_tagwidth + `DESTWIDTH;

// get addresses...
generate
  for(j = 0; j < `NUM_PORTS; j = j + 1) begin : ADDRGEN1
    wire [`IO_WIDTH-1:0] cur_di = di[(j + 1) * `IO_WIDTH - 1 -: `IO_WIDTH];
    assign addrs[(j + 1) * `DATA_AWIDTH  - 1 -: `DATA_AWIDTH]  = cur_di[`PKT_ADDR];
  end

  // basically, assign the tag to be the top part of the address
  for(j = 0; j < `NUM_PORTS; j = j + 1) begin : ADDRGEN2
    wire [`IO_WIDTH-1:0] cur_di = di[(j + 1) * `IO_WIDTH - 1 -: `IO_WIDTH];
    assign tags[(j + 1) * local_tagwidth  - 1 -: local_tagwidth]  = addrs[`DATA_AWIDTH * (j + 1) -1  -: local_tagwidth];
  end
endgenerate

wire [`NUM_PORTS * reg_width -1 : 0] oa_reg_out;
generate
  for (j = 0; j < `NUM_PORTS; j = j + 1) begin: OA_REG_GEN
    reg [reg_width-1:0] oa_reg;
    assign oa_reg_out[(j + 1) * reg_width - 1 -: reg_width] = oa_reg;
    always @(posedge clk or posedge rst) begin
      if(rst) begin
        oa_reg <= 0;
      end else begin
        if(we[j]) begin
          // format: {valid, tag=di[tag], dest=di[src]}
          oa_reg <= {1'b1, di[(j * `IO_WIDTH) + `DATA_A_OFFSET + `DATA_AWIDTH -1 -: local_tagwidth], di[(j * `IO_WIDTH) + `SRC_OFFSET + `DATA_SRCWIDTH -1 -: `DATA_SRCWIDTH]};
        end
      end
    end
  end
endgenerate
  
// generate the comparator matches ; we only need to compare the input tag
// (concatinated with valid == 1) to array, e.g., not the entire register
wire [`NUM_PORTS*`NUM_PORTS-1:0] matches;
generate  
  for ( j = 0; j < `NUM_PORTS; j = j + 1)  begin : CMP_OUT
    wire [local_tagwidth - 1 + 1 : 0] cur_tag = {1'b1, tags[(j+1)*local_tagwidth -1 -:local_tagwidth]};

    // current packet
    wire [`IO_WIDTH-1:0] cur_di = di[(j + 1) * `IO_WIDTH - 1 -: `IO_WIDTH];
    wire [`DATA_AWIDTH-1:0] cur_addr = cur_di[`PKT_ADDR];


         for ( k = 0; k < `NUM_PORTS; k = k + 1) begin : CMP_IN

     wire [reg_width-1:0 ] cur_reg = oa_reg_out[(k + 1) * reg_width - 1 -: reg_width];

     // get current { valid, tag} from reg
     wire [local_tagwidth - 1 + 1:0 ] cur_reg_tag = cur_reg[reg_width-1  -: local_tagwidth + 1];
     
      cmp #(
        .CMP_WIDTH(local_tagwidth+1)
      ) c (
        .valid(we[j] && (cur_di[`PKT_DEST] == (ROUTER_ID + `NUM_COMPUTE_NODES))),
        .lhs(cur_tag),
        .rhs(cur_reg_tag),
        .match(matches[j*`NUM_PORTS+k])
      );
    end
  end
endgenerate


  integer i;
  // Now we need to use the comparator matches as a way to select the correct
  // signals from reg output
  //
  // Basically use 'matches' as a sort of priority mux
  // Output to generate: 
  //   Basically: NHOP will be set later on
  //   So, we want to update a packet's DEST field
  //
  //   Then
  // generate wire outputs for register array
 
generate
  for(j = 0; j < `NUM_PORTS; j = j + 1) begin: GENBLK1
          wire [`NUM_PORTS-1:0] tw = matches[(j+1)*`NUM_PORTS -1 -: `NUM_PORTS];
    always@(di or tw) begin
    //always@(di or tw or oa_reg_out) begin
    //always @(posedge clk) begin
      dout[(j) * `IO_WIDTH + `DATA_A_OFFSET + `DATA_AWIDTH -1 -: `DATA_AWIDTH] <= di[(j) * `IO_WIDTH + `DATA_A_OFFSET + `DATA_AWIDTH -1 -: `DATA_AWIDTH]; 
      dout[(j) * `IO_WIDTH + `DATA_D_OFFSET + `DATA_DWIDTH -1 -: `DATA_DWIDTH] <= di[(j) * `IO_WIDTH + `DATA_D_OFFSET + `DATA_DWIDTH -1 -: `DATA_DWIDTH]; 
      dout[(j) * `IO_WIDTH + `SRC_OFFSET + `DATA_SRCWIDTH - 1 -: `DATA_SRCWIDTH] <= di[(j) * `IO_WIDTH + `SRC_OFFSET + `DATA_SRCWIDTH - 1 -: `DATA_SRCWIDTH]; 
      dout[(j) * `IO_WIDTH + `LASTBIT_OFFSET] <= di[j * `IO_WIDTH + `LASTBIT_OFFSET ]; 
      dout[(j) * `IO_WIDTH + `NEXTHOP_OFFSET + `NEXTHOPWIDTH - 1 -: `NEXTHOPWIDTH] <= di[j * `IO_WIDTH + `NEXTHOP_OFFSET + `NEXTHOPWIDTH - 1 -: `NEXTHOPWIDTH ]; 
      dout[(j) * `IO_WIDTH + `SENDBIT_OFFSET] <= di[j * `IO_WIDTH + `SENDBIT_OFFSET ]; 
      dout[(j) * `IO_WIDTH + `SENDOKBIT_OFFSET] <= di[j * `IO_WIDTH + `SENDOKBIT_OFFSET ]; 
      if (!(|tw)) begin
        dout[j * `IO_WIDTH + `DEST_OFFSET + `DESTWIDTH - 1 -: `DESTWIDTH] <= di[j * `IO_WIDTH + `DEST_OFFSET + `DESTWIDTH - 1 -: `DESTWIDTH];
        dout[j * `IO_WIDTH + `TYPE_OFFSET + `DATA_TYPEWIDTH - 1 -: `DATA_TYPEWIDTH] <= di[j * `IO_WIDTH + `TYPE_OFFSET + `DATA_TYPEWIDTH - 1 -: `DATA_TYPEWIDTH];
      end else begin
        for(i=0;i<`NUM_PORTS;i = i + 1) begin: DOUT_INNER
          if(tw[i]) begin
            dout[j * `IO_WIDTH + `DEST_OFFSET + `DESTWIDTH - 1 -: `DESTWIDTH]           <=   oa_reg_out[i * reg_width + `DESTWIDTH - 1 -: `DESTWIDTH];
            dout[j * `IO_WIDTH + `TYPE_OFFSET + `DATA_TYPEWIDTH - 1 -: `DATA_TYPEWIDTH] <= `TYPE_OUTSTANDING;
          end
        end // end for
      end // end else
    end // end always
  end // end for
endgenerate

generate
  for(j = 0 ; j < `NUM_PORTS; j = j + 1) begin : WASREPLACED
    assign wasreplaced[j] = |matches[(j+1)*`NUM_PORTS -1 -: `NUM_PORTS];
  end
endgenerate

endmodule


module cmp #(
  parameter CMP_WIDTH = 10
)(
  input wire valid, 
  input wire [CMP_WIDTH - 1 : 0] lhs,
  input wire [CMP_WIDTH - 1 : 0] rhs,
  output wire match
);
  assign match = (lhs == rhs) && valid;
endmodule
