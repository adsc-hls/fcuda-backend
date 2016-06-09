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

module node #(
  parameter [`ALL_ROUTE_BITS - 1 : 0]  ROUTES = { `ALL_ROUTE_BITS{1'b0}},
  parameter UNIFIED_ROUTELOOKUP               = 1
)(
  input wire clk,
  input wire rst,
  input  wire[`TOTAL_WIDTH - 1: 0] iput,
  output wire[`TOTAL_WIDTH - 1: 0] oput
);

genvar i;
genvar j;
genvar k;
genvar a;
genvar b;

wire [(`NUM_INPUTS * `NEXTHOPWIDTH) * `NEXTHOPWIDTH - 1 : 0] nextsel;
wire [(`NUM_INPUTS * `NEXTHOPWIDTH) - 1 : 0] to_oth;
wire [(`NUM_INPUTS * `NEXTHOPWIDTH) - 1 : 0] overrides;
wire [`NUM_INPUTS  - 1 : 0] override;
reg [(`NUM_INPUTS ) - 1 : 0] oktosend_r;
wire [(`NUM_INPUTS ) - 1 : 0] oktosend;
wire [`NUM_INPUTS -1 : 0] lastpart_all;

integer cnt;
always @(posedge clk) begin
  for (cnt = 0; cnt < `NUM_INPUTS; cnt = cnt + 1) begin
    oktosend_r[cnt] <= iput[cnt * `IO_WIDTH + `DATAWIDTH + `SENDOKBIT];
  end
end

assign oktosend = oktosend_r;


wire [`NUM_INPUTS * `DATAWIDTH - 1 : 0] fifodata_all;
wire [`NUM_INPUTS * (`DESTWIDTH + 1) - 1 : 0] fifoctrl_all;

generate
  for (i=0; i < `NUM_INPUTS; i = i + 1) begin:NODE_PORTS
    wire [`IO_WIDTH-1:0] in_local  = iput[`BOUNDS(i,`IO_WIDTH)];

    wire [`IO_WIDTH-1:0] out_local;
    assign oput[`BOUNDS(i,`IO_WIDTH)] = out_local;


    wire [`DATAWIDTH-1:0] data;
    assign data = in_local[`FIELD(0,`DATAWIDTH)] ;

    wire [`CTRLWIDTH-1:0] ctrl;
    assign ctrl = in_local[`FIELD(`DATAWIDTH,`CTRLWIDTH)] ;


    wire [`DATAWIDTH-1:0] fifodata;
    wire [`LASTBIT:0] fifoctrl;
    assign fifodata_all[`BOUNDS(i ,`DATAWIDTH)]  = fifodata;
    assign fifoctrl_all[`BOUNDS(i,(`LASTBIT+1))] = fifoctrl[`LASTBIT:0];

    wire lastpart;
    wire rd;
    wire sendok;
    wire sendbit;
    wire avail;

    assign out_local[`DATAWIDTH + `SENDOKBIT] = sendok;

    assign sendbit = ctrl[`SENDBIT];

    wire [`NEXTHOPWIDTH-1:0] fifo_sel;
    assign to_oth[`FIELD(`NEXTHOPWIDTH * i, `NEXTHOPWIDTH)] = fifo_sel;

    wire [`NEXTHOPWIDTH * `NEXTHOPWIDTH - 1 :0] fifo_to;
    assign nextsel[`FIELD(`NEXTHOPWIDTH * `NEXTHOPWIDTH * i, `NEXTHOPWIDTH * `NEXTHOPWIDTH)] = fifo_to;

    fifo # (
      .ROUTE(ROUTES[`BOUNDS(i,`NEXTHOPWIDTH * `ROUTE_WIRE_WIDTH)]),
      .UNIFIED_ROUTELOOKUP(`ROUTER_UNIFIED_ROUTELOOKUP),
      .LOWWATERMARK(`ROUTER_LOW_WATER_MARK)
    ) f (
      .clk      (clk),
      .rst      (rst),
      .rd       (rd),
      .sendok   (sendok),
      .avail    (avail),
      .q        (fifodata),
      .controlq (fifoctrl),
      // Inputs
      .d        (data),
      .control  (ctrl),
      .we       (sendbit),
      .sel      (fifo_sel /*     to_oth_local*/ ),
      .to       (fifo_to  /*     nextsel_local*/ )
    );

    assign lastpart = fifoctrl[`LASTBIT];
    assign lastpart_all[i] = lastpart;

    wire [`NEXTHOPWIDTH * `NEXTHOPWIDTH - 1 : 0] readenable_sel;

    integer count;

    wire no_assignment;

    for (j = 0; j < `NUM_INPUTS; j = j + 1) begin: JONE
      for (k = 0; k < `NEXTHOPWIDTH; k = k + 1) begin: KONE
        for ( a = j ; a < j + 1; a = a + 1) begin:AONE
          for ( b = (k < j) ? k : k + 1 ; b > - 1 ; b = -1) begin:BONE
            if (b == i) begin:IFONE
              assign no_assignment=1;
            end else if (a == i) begin:ELSEONE
              if ( b < i) begin
                  assign   readenable_sel[b*4]                     = to_oth [ j * `NEXTHOPWIDTH + k  ];
              end else begin
                  assign   readenable_sel[(b - 1) * 4]             = to_oth [ j * `NEXTHOPWIDTH + k  ];
              end
            end else if (( a < i ) && ( b > a ) &&  ( b < i )) begin
                  assign    readenable_sel[b * 4 + a + 1]          = to_oth [ j * `NEXTHOPWIDTH + k  ];
            end else if (( a < i ) && ( b > a ) &&  ( b > i )) begin 
                  assign    readenable_sel[(b - 1) * 4  + a + 1]   = to_oth [ j * `NEXTHOPWIDTH + k  ]; 
            end else if (( a < i ) && ( b < a ) &&  ( b < i )) begin 
                  assign    readenable_sel[b*4 + a]                = to_oth [ j * `NEXTHOPWIDTH + k  ]; 
            end else if (( a < i ) && ( b < a ) &&  ( b > i )) begin 
                  // nothing: this is impossible
                  assign   no_assignment = 1; 
            end else if (( a > i ) && ( b > a ) &&  ( b < i )) begin 
                  // nothing: this is impossible
                  assign   no_assignment = 1; 
            end else if (( a > i ) && ( b > a ) &&  ( b > i )) begin 
                  assign    readenable_sel[(b - 1) * 4 + a]        = to_oth [ j * `NEXTHOPWIDTH + k  ]; 
            end else if (( a > i ) && ( b < a ) &&  ( b < i )) begin 
                  assign    readenable_sel[(b * 4) + a - 1]        = to_oth [ j * `NEXTHOPWIDTH + k  ]; 
            end else if (( a > i ) && ( b < a ) &&  ( b > i )) begin 
                  assign    readenable_sel[(b - 1) * 4 + a - 1]    = to_oth [ j * `NEXTHOPWIDTH + k  ]; 
            end else begin 
                  // nothing: this should not ever happen
                  assign no_assignment = 1; 
            end 
          end
        end
      end
    end


    wire [`NEXTHOPWIDTH - 1:0] readenable_oktosend;
    
    for ( j = 0; j <  `NEXTHOPWIDTH+1; j = j + 1) begin: JVAR
      if (j < i) begin
        assign readenable_oktosend[j] = oktosend[j];
      end else if (j > i) begin
        assign readenable_oktosend[j - 1] = oktosend[j];
      end
    end

    wire [`NEXTHOPWIDTH - 1:0] readenable_override = overrides[`BOUNDS(i,`NEXTHOPWIDTH) ];

    readenable re(
	// Inputs
	.nolocal_rd(avail),
        .sel ( readenable_sel ),
        .oktosend( readenable_oktosend ),
        .override ( readenable_override ),
	// Outputs
	.rd(rd));

    wire [`NEXTHOPWIDTH * ( `DATAWIDTH + `SENDBIT ) - 1 : 0] om_inputs;
    wire [`NEXTHOPWIDTH  - 1 : 0] om_to;
    wire [`NEXTHOPWIDTH  - 1 : 0] arb_override;
    wire [`NEXTHOPWIDTH  - 1 : 0] om_lastpart;
   
    for ( j = 0 ; j < `NUM_INPUTS; j = j + 1) begin: LOOP1
      if (j != i) begin: IF2
        if (i < j) begin: IF3
          assign om_inputs [`BOUNDS(j-1,`DATAWIDTH+`SENDBIT)]  = {nextsel[`FIELD(`NEXTHOPWIDTH * (j * `NEXTHOPWIDTH + i),`NEXTHOPWIDTH)], fifoctrl_all[`BOUNDS(j,`DESTWIDTH+1)], fifodata_all[`BOUNDS(j,`DATAWIDTH) ] };
          assign om_to[j-1] = to_oth[j * `NEXTHOPWIDTH + i  ];
          assign om_lastpart[j-1] = lastpart_all[j  ];

          assign overrides[j*`NEXTHOPWIDTH +i] = arb_override[j-1];
        end else begin:ELSE4 // i - 1
          assign om_inputs [`BOUNDS(j,`DATAWIDTH+`SENDBIT)]  = {nextsel[`FIELD( `NEXTHOPWIDTH * (j * `NEXTHOPWIDTH + i-1),`NEXTHOPWIDTH)] , fifoctrl_all[`BOUNDS(j,`DESTWIDTH+1)], fifodata_all[`BOUNDS(j,`DATAWIDTH) ] };
          assign om_to[j] = to_oth[j * `NEXTHOPWIDTH + i - 1];
          assign om_lastpart[j] = lastpart_all[j  ];

          assign overrides[j*`NEXTHOPWIDTH +i-1] = arb_override[j];
        end
      end
    end

    outputmux om(
      .clk(clk),
      .rst(rst),
      .oktosend(oktosend[i]),
      .send(out_local[`DATAWIDTH+`SENDBIT]),
      .iput( om_inputs ),
      .sel ( om_to ),
      .override_oth ( arb_override ),
      .override(override[i]),
      .q(out_local[`DATAWIDTH+`SENDBIT-1:0])
    );

    arbiter ar(
      .clk(clk),
      .rst(rst),
      .override(override[i]),
      .override_oth( arb_override ),
      .sel (om_to ),
      .oktosend(oktosend[i]),
      .last (om_lastpart)
    );

  end
endgenerate

endmodule
