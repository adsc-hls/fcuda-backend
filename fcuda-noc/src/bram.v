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

// Dual-Port Block RAM

`timescale 1ns / 1ps
`include "noc_pkt.vh"

module bram #(
  parameter DATASIZE = `BRAM_DATA_DATAWIDTH,
  parameter DEPTH = 1024,
  parameter ADDRWIDTH = `BRAM_DATA_ADDRWIDTH
) (
  input wire clk,
  input wire rst,
  input wire we1, we2,
  input wire [ADDRWIDTH - 1 : 0] addr1, addr2,
  input wire [DATASIZE - 1 : 0] di1, di2,
  output [DATASIZE - 1 : 0] do1, do2
);

reg [DATASIZE - 1 : 0] ram [DEPTH - 1 : 0];
reg [DATASIZE - 1 : 0] do1, do2;
integer i;

always @(posedge clk) begin
  if (rst) begin
    for (i = 0; i < DEPTH; i = i + 1) begin
      ram[i] <= 0;
    end
    do1 <= 0;
    do2 <= 0;
  end
end

always @(posedge clk) begin
  if (!rst) begin
    if (we1 === 1'b1) begin
      ram[addr1] <= di1;
    end
    do1 <= ram[addr1];
  end
end

always @(posedge clk) begin
  if (!rst) begin
    if (we2 === 1'b1) begin
      ram[addr2] <= di2;
    end
    do2 <= ram[addr2];
  end
end

endmodule
