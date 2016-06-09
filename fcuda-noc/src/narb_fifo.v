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

//This is a FIFO. The width of each FIFO entry is set by the generic BUF_WIDTH
//and the number of entries in the buffer is the generic BUF_DEPTH
//LOG2_BUF_DEPTH is log base 2 of the BUF_DEPTH, used for pointer vector lengths

`include "noc_pkt.vh"
`timescale 1ns / 1ps

module narb_fifo # (
  parameter BUF_WIDTH    = 8,
  parameter BUF_DEPTH     = 4,
  parameter LOG2_BUF_DEPTH = 2
)
(
  input wire clk,
  input wire rst,
  input wire enr, //enable read,should be '0' when not in use.
  input wire enw, //enable write,should be '0' when not in use.
  output reg [BUF_WIDTH-1:0] dataout, //output data
  input wire [BUF_WIDTH-1:0] datain, //input data
  output wire empty_o, //set as '1' when the queue is empty
  output wire full_o, //set as '1' when the queue is full
  output wire error_o //set if error, such as write when full
);

reg [BUF_WIDTH-1:0] memory [BUF_DEPTH-1:0];
//read and write pointers
reg [LOG2_BUF_DEPTH-1:0] readptr;
reg [LOG2_BUF_DEPTH-1:0] writeptr;
reg empty;
reg full;
reg wr_error, rd_error;
wire [LOG2_BUF_DEPTH-1:0] readptrplusone;
wire [LOG2_BUF_DEPTH-1:0] readptr_minus_one;
wire [LOG2_BUF_DEPTH-1:0] writeptr_minus_one;

integer i;

assign full_o = full;
assign empty_o = empty;
assign error_o = wr_error | rd_error;
assign readptrplusone = readptr + 1;
assign readptr_minus_one = readptr - 1;
assign writeptr_minus_one = writeptr - 1;

always @(posedge clk) begin
  if (rst == 1) begin
    for (i = 0; i < BUF_DEPTH; i = i + 1) begin
      memory[i] <= 0;
    end
    dataout <= 0;
    readptr <= 0;
    writeptr <= 0;
    wr_error <= 0;
    rd_error <= 0;
    empty <= 1;
    full <= 0;
  end 
  else begin
    if (enw === 1'b1) begin
      //If the buffer is full, don't write and set error
      if (full == 1 && enr === 1'b0) begin
        wr_error <= 1;
        $display("[%m] trying to write to full narb_fifo");
        $stop;
      end
      //otherwise perform the write
      else if (empty == 1) begin
        empty <= 0;
        wr_error <= 0;
        memory[writeptr] <= datain;
        dataout <= datain;
        writeptr <= writeptr + 1;  
      end else begin
        empty <= 0;
        wr_error <= 0;
        memory[writeptr] <= datain;
        writeptr <= writeptr + 1; 
      end
      //check if full
      if (writeptr == readptr_minus_one) begin
        full <= 1;
      end
    end
    //if reads are enabled
    if (enr === 1'b1) begin
      //If the buffer is empty, don't read and set error
      if(empty == 1) begin
        rd_error <= 1;
        $display("trying to read empty narb_fifo");
        $stop;
      end
      //otherwise read
      else begin
        //full <= 0;
        rd_error <= 0;
        if (enw === 1'b1 && enr === 1'b1 && (writeptr_minus_one == readptr)) begin
          dataout <= datain;
        end else
          dataout <= memory[readptrplusone];
        readptr <= readptr + 1; //points to next address.  
      end;
      //is narb_fifo empty?
      if ((writeptr_minus_one == readptr) && enw === 1'b0) begin
        empty <= 1;
        dataout <= 0;
      end
    end
  end
end

endmodule
