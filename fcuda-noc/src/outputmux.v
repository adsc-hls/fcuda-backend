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

// Output mux for an output port

module outputmux(
  input wire clk,
  input wire rst,
  input wire override,
  input wire oktosend,
  output reg send,
  input wire [`NEXTHOPWIDTH * ( `DATAWIDTH + `SENDBIT ) - 1 : 0] iput,
  output wire [`DATAWIDTH+`SENDBIT - 1 : 0] q,
  input wire [`NEXTHOPWIDTH - 1 : 0] sel,
  input wire [`NEXTHOPWIDTH - 1 : 0] override_oth
);

wire sendit;

genvar i;
genvar j;

wire [`NEXTHOPWIDTH-1:0] sendit_tmp;
wire [`NEXTHOPWIDTH-1:0] sendit_tmp_2;
wire [`NEXTHOPWIDTH * ( `DATAWIDTH + `SENDBIT ) - 1 : 0] to_mux;

assign sendit = (|sendit_tmp) || (!override && (|sendit_tmp_2));

generate
 for ( i = 0; i < `NEXTHOPWIDTH; i = i + 1) begin: SENDIT
   assign sendit_tmp[i] = sel[i] && override_oth[i];
 end

 for ( i = 0; i < `NEXTHOPWIDTH; i = i + 1) begin: SENDIT_TMP
   wire [`NEXTHOPWIDTH-2:0] sendit_tmp_3;
   for ( j = 0; j < `NEXTHOPWIDTH; j = j + 1) begin: SENDIT_TMP_INNER
     if (i != j) begin: SENDIT_NOTEQ
       if (j < i) begin: SENDIT_LESSTHAN
         assign sendit_tmp_3[j] = !sel[j];
       end else begin: SENDIT_GTHAN
         assign sendit_tmp_3[j-1] = !sel[j];
       end
     end
   end
   assign sendit_tmp_2[i] = (&sendit_tmp_3) && sel[i];
 end

 // rearrange wires to go to mux
 for(i = 0; i < `NEXTHOPWIDTH; i = i + 1) begin: REARRANGE_OUTER
   for ( j = 0; j < `DATAWIDTH + `SENDBIT; j = j + 1) begin: REARRANGE_INNER
     assign to_mux[j * `NEXTHOPWIDTH + i ] = iput[ i * (`DATAWIDTH + `SENDBIT) + j];
   end
 end

  // The output muxes/flipflops
  for(i=0; i < `SENDBIT+`DATAWIDTH; i = i + 1) begin:MUX
    muxbit_wrap mux(
      .clk(clk),
      .rst(rst),
      .i(to_mux[(i + 1) * `NEXTHOPWIDTH - 1: i * `NEXTHOPWIDTH]),
      .sel(sel),
      .override(override_oth),
      .q(q[i]));
  end
endgenerate

// Might want to add a reset signal to "send"
always @(posedge clk) begin:SETSEND
  send <= 0;
  if(oktosend) begin
    send <= sendit;
  end
end

endmodule // outputmux
