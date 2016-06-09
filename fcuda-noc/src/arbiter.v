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

module arbiter(
  input wire clk,
  input wire rst,
  input wire [`NEXTHOPWIDTH - 1 : 0] sel,
  input wire oktosend,
  input wire [`NEXTHOPWIDTH - 1 : 0] last,
  output reg [`NEXTHOPWIDTH - 1 : 0] override_oth,
  output reg override
);

reg [`NEXTHOPWIDTH - 1 : 0] done;
wire [`NEXTHOPWIDTH - 1 : 0] only;

wire [`NEXTHOPWIDTH - 1 : 0] only_int_1;
wire [`NEXTHOPWIDTH - 1 : 0] only_int_2;

wire [`NEXTHOPWIDTH - 1 : 0] conds;

wire [`NEXTHOPWIDTH - 1 : 0] cond_tmp;
wire [(`NEXTHOPWIDTH - 1) *`NEXTHOPWIDTH - 1 : 0] cond_tmp_2;


genvar i,j;
generate
for (i = 0; i < `NEXTHOPWIDTH; i = i + 1) begin: ONLY_WIRES_2
  assign only_int_1[i] = sel[i];
  assign only[i] = only_int_1[i] && only_int_2[i];
end

for (i = 0; i < `NEXTHOPWIDTH; i = i + 1) begin: ONLY_WIRES_3
  wire[`NEXTHOPWIDTH * (`NEXTHOPWIDTH-1) - 1 : 0] only_int_3;
  for (j = 0; j < `NEXTHOPWIDTH; j = j + 1) begin: ONLY_WIRES_INT_2
    if (j != i) begin
      if (j < i) begin
        assign only_int_3[(i * (`NEXTHOPWIDTH - 1)) + j] =(!sel[j]);
      end else begin
        assign only_int_3[(i * (`NEXTHOPWIDTH - 1)) + (j - 1)] =(!sel[j]);
      end
    end
    assign only_int_2[i] = &only_int_3[((i + 1) * 
                      (`NEXTHOPWIDTH - 1) - 1) : i * (`NEXTHOPWIDTH - 1)];
  end
end

for (i = 0; i < `NEXTHOPWIDTH; i = i + 1) begin: CONDS_BEGIN
  wire [`NEXTHOPWIDTH - 1 : 0] conds_int;
  assign conds_int[i]  = (sel[i] && (!done[i] || only[i]) && !override);
  for (j = 0; j < i; j = j + 1) begin: CONDS_INT
    assign conds_int[j] = (!sel[j] || done[j]);
  end
  if (i == 0) begin
    assign conds[0] = conds_int[0];
  end else begin
    assign conds[i] = &conds_int[i : 0 ];
  end
end

for (i = 0; i < `NEXTHOPWIDTH; i = i + 1)  begin: COND_TMP
  wire [`NEXTHOPWIDTH-2:0] cond_tmp_int;
  for (j = 0; j <  `NEXTHOPWIDTH; j = j + 1 ) begin: COND_TMP_INT
    if (j != i) begin
      if (j < i) begin
        assign cond_tmp_2[i * (`NEXTHOPWIDTH - 1) + j] =  (sel[j] && !done[j] ); 
      end else begin
        assign cond_tmp_2[i * (`NEXTHOPWIDTH - 1) + j - 1] =  (sel[j ] && !done[j] );
      end
    end
  end
  assign cond_tmp[i] = !cond_tmp_2[`BOUNDS(i,`NEXTHOPWIDTH - 1)];
end
endgenerate

integer k;
always @(posedge clk) begin
  /* set override = 1 */
  for (k = 0; k < `NEXTHOPWIDTH; k = k + 1) begin: ARBIFY
    if (conds[k]) begin
      override_oth[k] <= 1;
    end
    if ((override_oth[k] || only[k]) && last[k] && oktosend) begin
      done[k] <= 1;
      override_oth[k] <= 0;
    end
    if (cond_tmp[k]) begin
      done[k] <= 0;
    end
    if (rst) begin
      done[k]         <= 0;
      override_oth[k] <= 0;
    end
  end
end

integer gen;
always @(*) begin
  override = |override_oth;
end

// for sanity checking
reg [31 : 0] count;
integer sanity_count;
always @(posedge clk) begin
  count = 0;
  for (sanity_count = 0; sanity_count < `NEXTHOPWIDTH; 
        sanity_count = sanity_count + 1) begin
    if(override_oth[sanity_count]) begin
      count = count + 1;
    end
  end
  if (count > 1) begin
    $display("[%m] ERROR: More than one override active at the same time!");
    $stop;
  end
end

endmodule 
