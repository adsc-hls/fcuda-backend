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

module fifo #(
  
  // route for nexthop
  parameter [`NEXTHOPWIDTH * `ROUTE_WIRE_WIDTH - 1 : 0] ROUTE = {`NEXTHOPWIDTH * `ROUTE_WIRE_WIDTH{1'b0}},

  // default lowwatermark
  parameter LOWWATERMARK = `FIFO_WIDTH'h30,

  // unused
  parameter UNIFIED_ROUTELOOKUP = 1
)(
  input wire                                          clk,
  input wire                                          rst,
  input wire [`CTRLWIDTH-1:0]                         control,
  input wire [`DATAWIDTH-1:0]                         d,
  input wire                                          we,
  output reg                                          sendok,
  output wire                                         avail,
  output wire [`DATAWIDTH-1:0]                        q,
  output wire [`LASTBIT:0]                            controlq,
  input wire                                          rd,
  output wire [`NEXTHOPWIDTH-1:0]                     sel,
  output wire [`NEXTHOPWIDTH * `NEXTHOPWIDTH - 1 : 0] to
);


wire [`FIFO_WIDTH-1:0]                addrptr;
wire [`DATAWIDTH-1:0]                 srlq;
wire [`DESTWIDTH+`NEXTHOPWIDTH+1-1:0] controlsrlq;
wire                                  avail_in_ff;
wire                                  avail_int;
wire                                  fdce_sel;
wire                                  extread;

reg [`DATAWIDTH-1:0]   q_reg;
reg [`DESTWIDTH+1-1:0] controlq_reg;
reg [`FIFO_WIDTH-1:0]  new_addrptr;
reg [`FIFO_WIDTH-1:0]  addr_reg={`FIFO_WIDTH{1'b1}};
reg [`FIFO_WIDTH-1:0]  maxval = 0;
reg                    avail_flag;
reg                    avail_in_ff_reg;

assign extread   = rd;
assign avail_int = addrptr != {`FIFO_WIDTH{1'b1}};
assign addrptr   = addr_reg;
assign fdce_sel  = extread;
assign avail     = avail_in_ff;

// with no pipeline stages between NoC switches.
always @(posedge clk) begin
  sendok <= (addrptr == {`FIFO_WIDTH{1'b1}}) || (addrptr < LOWWATERMARK);
  if (sendok == 1'b0)
    $display("[%m] at %t, SEND NOT OK addrptr=%d, new_addrptr=%d, LOWWATERMARK=%d", $time, addrptr, new_addrptr, LOWWATERMARK);
  /* debugging */
  if(avail_int) begin
    if(avail && !((|sel))) begin
      // essentially, we got a packet and we have nowhere to send it
      $display("%m: Error, no sel signal active!");
      $stop;
    end
  end

  if(addrptr == {{`FIFO_WIDTH-1{1'b1}},1'b0}) begin
    if(new_addrptr == {`FIFO_WIDTH{1'b1}}) begin
      $display("%m: Fifo overflow, aborting simulation at %t", $time);
      $stop;
    end
  end

  /* flipflops with enable */
  if (rst == 1) begin
    q_reg <= 0;
    controlq_reg <= 0;
    addr_reg <= {`FIFO_WIDTH{1'b1}};
    avail_in_ff_reg <= 0;
  end else begin
    if (fdce_sel == 1) begin
      q_reg <= srlq;
      controlq_reg <= controlsrlq[`DESTWIDTH+1-1:0];
    end

    addr_reg <= new_addrptr;
    avail_in_ff_reg <= avail_flag;
  end
end

always @* begin
  new_addrptr = addrptr;
  if(we) begin
    if(!((extread) && avail_int)) begin
      new_addrptr = addrptr + 1;
    end
  end else if((extread) && avail_int) begin
      new_addrptr = addrptr - 1;
  end

  if(extread) begin
    avail_flag = avail_int;
  end else begin
    avail_flag = avail_in_ff;
  end
end

 
assign avail_in_ff = avail_in_ff_reg;
assign q = q_reg;
assign controlq[`DESTWIDTH+1-1:0] = controlq_reg[`DESTWIDTH+1-1:0];

genvar i;
generate
  for (i=0;i<`NEXTHOPWIDTH;i = i + 1) begin:FDES

    wire sel_local = controlsrlq[`NEXTHOPBIT + i] && avail_int;

    // flipflops
    my_fde ff(
      .clk(clk),
      .ce(fdce_sel),
      .rst(rst),
      .d(sel_local),
      .q(sel[i])
    );

    // get next-nextroute
    nextroute #(
      .ROUTE(ROUTE[`BOUNDS(i,`ROUTE_WIRE_WIDTH)])
    ) nr (
      .clk(clk),
      .rst(rst),
      .ce(fdce_sel),
      .destaddr(controlsrlq[`DESTWIDTH-1:0]),
      .sel(to[i])
    );

  end

  for (i = 1; i < `NEXTHOPWIDTH; i = i + 1) begin:NHOPS_ASSIGN
    assign to[(i+1)*`NEXTHOPWIDTH-1 : i*`NEXTHOPWIDTH] = to[`NEXTHOPWIDTH-1 : 0];
  end

  reg [`DATAWIDTH - 1 : 0] fifo_data[`FIFO_SIZE - 1 : 0];
  reg [`DESTWIDTH + `NEXTHOPWIDTH + 1 - 1 : 0] fifo_control[`FIFO_SIZE - 1 : 0];
  integer j;
  always @(posedge clk) begin
    if (we == 1'b1) begin
      for (j = 0; j < `FIFO_SIZE - 1; j = j + 1) begin
        fifo_data[j + 1] <= fifo_data[j];
        fifo_control[j + 1] <= fifo_control[j];
      end
      fifo_data[0] <= d;
      fifo_control[0] = control;
    end
  end
  assign srlq = fifo_data[addrptr];
  assign controlsrlq = fifo_control[addrptr];
endgenerate

endmodule //srlfifo
