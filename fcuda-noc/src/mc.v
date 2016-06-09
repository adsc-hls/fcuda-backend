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
// mc.v
//
// Jacob Tolar & Yao Chen
// mc is the input interface between the memory controller and the
// network on chip. 
//
//   The goal of this module is to interface with Xilinx's MIG
//   and the NoC
//
//   Essentially -- the NoC is connected to a FIFO 
//   The fifo is written to when there is a valid packet (causing
//   a read or write to / from memory). 
//
//   This module implements a state machine which reads the fifo
//   when it is non-empty, performs a read or write to/from memory. 
//

`include "noc_pkt.vh"

`timescale 1ns / 1ps

module mc # (
  parameter NUM_CORES = 1,
  parameter FIFO_DATA_WIDTH    = `IO_WIDTH
)
(
  input wire clk,
  input wire rst,

  output reg mem_req_din,
  input mem_req_full_n,
  output reg mem_req_write,
  input mem_rsp_empty_n,
  output reg mem_rsp_read,
  output [31 : 0] mem_address,
  input [31 : 0] mem_datain,
  output [31 : 0] mem_dataout,
  output [31 : 0] mem_size,

  input wire ini_end,
  input wire fifo_empty,

  input wire [FIFO_DATA_WIDTH - 1 : 0] input_fifo_data,

  // to mc_int
  output wire [FIFO_DATA_WIDTH - 1 : 0] out_addr_data,
  output wire                       out_addr_valid,
  output reg read_fifo,
  
  output reg        rd_data_valid,
  output reg [31 : 0] rd_data_fifo_out,

  output reg mc_done
);


reg [31:0] clock_counter;

always @(posedge clk) begin
  if (rst) begin
    clock_counter <= 32'b0;
  end
  else begin
    if (ini_end)
      clock_counter <= clock_counter + 1;

    if (clock_counter % 1000 == 0)
      $display("[%m] clock_counter=%d", clock_counter);
  end
end

// states
localparam s_wait        = 0;
localparam s_fifo_read   = 1;
localparam s_check       = 2;
localparam s_mem_read    = 3;
localparam s_mem_write   = 4;

// state variable
reg [2 : 0] state;

reg [FIFO_DATA_WIDTH - 1 : 0] fifo_reg;
// set to 1 when we want to update reg; 0 otherwise
reg write_reg;

// write register with fifo contents if enabled
always @(posedge clk) begin
  if (write_reg) begin
    fifo_reg <=  input_fifo_data;
  end
end

always @(input_fifo_data)begin
  $display("at %t, input_fifo_data = 0x%x", $time, input_fifo_data);
end

wire [`DATA_AWIDTH - 1 : 0] addr;
assign addr = fifo_reg[`FIELD(`DATA_A_OFFSET,`DATA_AWIDTH)] >> 2; 

reg [`DATA_AWIDTH - 1 : 0] addr_r;
reg [31 : 0] data_out;

assign mem_size = 32'b1;
assign mem_address = addr_r;
assign mem_dataout = data_out;
assign out_addr_data  = fifo_reg;

wire sendokbit;
assign sendokbit = fifo_reg[`SENDOKBIT_OFFSET];

reg out_addr_valid_reg;
assign out_addr_valid = out_addr_valid_reg;

// determine if packet is a read or write packet
wire is_read;
wire is_write;
wire is_done;
assign is_read  = (fifo_reg[`FIELD(`TYPE_OFFSET, `DATA_TYPEWIDTH)] ==  `TYPE_REQUEST) && (sendokbit);
assign is_write = (fifo_reg[`FIELD(`TYPE_OFFSET, `DATA_TYPEWIDTH)] ==  `TYPE_WRITE) && (sendokbit);
assign is_done = (fifo_reg[`FIELD(`TYPE_OFFSET, `DATA_TYPEWIDTH)] ==  `TYPE_DONE) && (sendokbit);

reg [31 : 0] mem_access = 0;
reg [31 : 0] count_output = 0;
reg [31 : 0] count_done = 0;

always @(posedge clk) begin
  if (mem_rsp_empty_n == 1'b1 && mem_rsp_read == 1'b0) begin
    $display("[%m] at %t, READING DATA mem_datain=%h, rd_data_fifo_out=%h, mem_rsp_empty_n=%d, mem_req_full_n=%d, state=%d, clock_counter=%d, mem_access=%d", $time, mem_datain, rd_data_fifo_out, mem_rsp_empty_n, mem_req_full_n, state, clock_counter, mem_access);
    rd_data_valid <= 1'b1;
    rd_data_fifo_out <= mem_datain;
    mem_rsp_read <= 1'b1;
  end else begin
    mem_rsp_read <= 1'b0;
    rd_data_valid <= 1'b0;
    rd_data_fifo_out <= 32'bx;
  end
end

always @(posedge clk or posedge rst) begin
  if (rst) begin
    state <= s_wait;
  end else begin
    case (state)        
      // wait for fifo to fill
      s_wait: begin
        if (count_done == NUM_CORES) begin
          $display("Done simulation: count_done = %d, clock_counter = %d, mem_access = %d", count_done, clock_counter, mem_access);
          mc_done <= 1'b1;
        end else
          mc_done <= 1'b0;

        addr_r <= 32'bx;
        data_out <= 32'b0;
        mem_req_din <= 1'b0;
        mem_req_write <= 1'b0;
        //mem_rsp_read <= 1'b0;

        //rd_data_valid <= 1'b0;
        //rd_data_fifo_out <= 0;
        out_addr_valid_reg <= 0;
        
        if (fifo_empty || !(ini_end)) begin
          read_fifo    <= 0;
          write_reg    <= 0;
          state <= s_wait;
        end else begin
          read_fifo    <= 1;
          write_reg    <= 1;
          state <= s_fifo_read;
        end;
      end
      // read from fifo
      s_fifo_read: begin
        read_fifo <= 0;
        write_reg <= 0;
        state <= s_check;
      end
      // check whether it is a read or a write
      s_check: begin
        if (is_read)
          state <= s_mem_read;
        else if (is_write)
          state <= s_mem_write;
        else if (is_done) begin
          $display("[%m] MC DONE at %t, fifo_reg=%h, node=%d", $time, fifo_reg, fifo_reg[`PKT_SRC]);
          count_done <= count_done + 1;
          state <= s_wait;
        end
        else
          state <= s_wait;
      end
      // do a memory read
      s_mem_read: begin
        if (mem_req_full_n == 1'b1) begin
          addr_r <= addr;
          out_addr_valid_reg <= 1'b1;
          mem_req_din <= 1'b0; //0: read, 1: write
          mem_req_write <= 1'b1;
          state <= s_wait;
          mem_access <= mem_access + 1; // count the number of memory accesses/read
        end
      end
      // do a memory write
      s_mem_write: begin
        if (mem_req_full_n == 1'b1) begin
          $display("Final write to mem fifo_reg=%h, type=%d, data=%h, addr=%h, is_write=%d, count_output=%d", fifo_reg, fifo_reg[`PKT_TYPE], fifo_reg[`PKT_DATA], fifo_reg[`PKT_ADDR], is_write, count_output);
          count_output <= count_output + 1;
          mem_req_din <= 1'b1; //0: read, 1: write
          mem_req_write <= 1'b1;
          addr_r <= addr;
          data_out <= fifo_reg[`FIELD(`DATA_D_OFFSET,`DATA_DWIDTH)];
          state <= s_wait;
        end
      end
    endcase
  end
end
endmodule
