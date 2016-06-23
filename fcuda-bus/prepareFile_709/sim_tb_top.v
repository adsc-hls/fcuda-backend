/////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/09/2014 09:51:42 PM
// Design Name: 
// Module Name: sim_for_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ps/100fs
//////////////////////////////////////////////////////////////////////////////////
module sim_for_top;
parameter DQ_WIDTH              = 64;//16;
parameter DQS_WIDTH             = 8;//2;


parameter ECC                   = "OFF";
parameter BANK_WIDTH            = 3;
                                  // # of memory Bank Address bits.
parameter CK_WIDTH              = 1;
                                  // # of CK/CK# outputs to memory.
parameter COL_WIDTH             = 10;
                                  // # of memory Column Address bits.
parameter CS_WIDTH              = 1;
                                  // # of unique CS outputs to memory.
parameter nCS_PER_RANK          = 1;
                                  // # of unique CS outputs per rank for phy
parameter CKE_WIDTH             = 1;
                                  // # of CKE outputs to memory.

                                  // = ceil(log2(DQ_WIDTH))
parameter DM_WIDTH              = 8;//2;
parameter ODT_WIDTH             = 1;
                                  // # of ODT outputs to memory.
parameter ROW_WIDTH             = 16;//15;
                                  // # of memory Row Address bits.
parameter SIM_BYPASS_INIT_CAL   = "FAST";
                                  // # = "OFF" -  Complete memory init &
                                  //              calibration sequence
                                  // # = "SKIP" - Not supported
                                  // # = "FAST" - Complete memory init & use
 parameter CA_MIRROR             = "OFF";
                                  // C/A mirror opt for DDR3 dual rank	abbreviated calib sequence
 parameter RST_ACT_LOW           = 1;
                                  // =1 for active low reset,
                                  // =0 for active high.

 parameter CLKIN_PERIOD          = 2500;
 parameter tCK                   = 2500;
 parameter CORE_CLOCK            = 10000;
                                  // memory tCK paramter.
                                  // # = Clock Period in pS.
 parameter REFCLK_FREQ           = 200.0;
                                                                       // IODELAYCTRL reference clock frequency
 parameter DIFF_TERM_REFCLK      = "FALSE";
                                                                       // Differential Termination for idelay
                                                                       // reference clock input pins

 localparam real TPROP_DQS          = 0.00;
                                      // Delay for DQS signal during Write Operation
 localparam real TPROP_DQS_RD       = 0.00;
                      // Delay for DQS signal during Read Operation
 localparam real TPROP_PCB_CTRL     = 0.00;
                      // Delay for Address and Ctrl signals
 localparam real TPROP_PCB_DATA     = 0.00;
                      // Delay for data signal during Write operation
 localparam real TPROP_PCB_DATA_RD  = 0.00;
                      // Delay for data signal during Read operation

 localparam MEMORY_WIDTH            = 8;  
 localparam NUM_COMP                = DQ_WIDTH/MEMORY_WIDTH;

localparam ERR_INSERT ="OFF";
 localparam real REFCLK_PERIOD = (1000000.0/(2*REFCLK_FREQ));
 localparam RESET_PERIOD = 200000; //in pSec  
 localparam real SYSCLK_PERIOD = tCK;   

/*
parameter DQ_WIDTH              = 16;
parameter DQS_WIDTH             = 2;


parameter ECC                   = "OFF";
parameter BANK_WIDTH            = 3;
                                  // # of memory Bank Address bits.
parameter CK_WIDTH              = 1;
                                  // # of CK/CK# outputs to memory.
parameter COL_WIDTH             = 10;
                                  // # of memory Column Address bits.
parameter CS_WIDTH              = 1;
                                  // # of unique CS outputs to memory.
parameter nCS_PER_RANK          = 1;
                                  // # of unique CS outputs per rank for phy
parameter CKE_WIDTH             = 1;
                                  // # of CKE outputs to memory.

                                  // = ceil(log2(DQ_WIDTH))
parameter DM_WIDTH              = 2;
parameter ODT_WIDTH             = 1;
                                  // # of ODT outputs to memory.
parameter ROW_WIDTH             = 15;
                                  // # of memory Row Address bits.
parameter SIM_BYPASS_INIT_CAL   = "FAST";
                                  // # = "OFF" -  Complete memory init &
                                  //              calibration sequence
                                  // # = "SKIP" - Not supported
                                  // # = "FAST" - Complete memory init & use
 parameter CA_MIRROR             = "OFF";
                                  // C/A mirror opt for DDR3 dual rank	abbreviated calib sequence
 parameter RST_ACT_LOW           = 1;
                                  // =1 for active low reset,
                                  // =0 for active high.

 parameter CLKIN_PERIOD          = 2500;
 parameter tCK                   = 2500;
 parameter CORE_CLOCK            = 2500;
                                  // memory tCK paramter.
                                  // # = Clock Period in pS.
 parameter REFCLK_FREQ           = 200.0;
                                                                       // IODELAYCTRL reference clock frequency
 parameter DIFF_TERM_REFCLK      = "FALSE";
                                                                       // Differential Termination for idelay
                                                                       // reference clock input pins

 localparam real TPROP_DQS          = 0.00;
                                      // Delay for DQS signal during Write Operation
 localparam real TPROP_DQS_RD       = 0.00;
                      // Delay for DQS signal during Read Operation
 localparam real TPROP_PCB_CTRL     = 0.00;
                      // Delay for Address and Ctrl signals
 localparam real TPROP_PCB_DATA     = 0.00;
                      // Delay for data signal during Write operation
 localparam real TPROP_PCB_DATA_RD  = 0.00;
                      // Delay for data signal during Read operation

 localparam MEMORY_WIDTH            = 8;  
 localparam NUM_COMP                = DQ_WIDTH/MEMORY_WIDTH;

localparam ERR_INSERT ="OFF";
 localparam real REFCLK_PERIOD = (1000000.0/(2*REFCLK_FREQ));
 localparam RESET_PERIOD = 200000; //in pSec  
 localparam real SYSCLK_PERIOD = tCK;   
*/
   wire init_calib_complete;
   reg sys_clk_i;
   wire sys_rst;
   reg clk_ref_i;
   reg sys_rst_n;
   wire aresetn;
   reg ap_start;
   reg aclk;
   wire ap_done;
   reg start_count;
   
  //**************************************************************************//
  // Wire Declarations
  //**************************************************************************//
 
  wire                               DDR3_reset_n;
  wire [DQ_WIDTH-1:0]                DDR3_dq;
  wire [DQS_WIDTH-1:0]               DDR3_dqs_p;
  wire [DQS_WIDTH-1:0]               DDR3_dqs_n;
  wire [ROW_WIDTH-1:0]               DDR3_addr;
  wire [BANK_WIDTH-1:0]              DDR3_ba;
  wire                               DDR3_ras_n;
  wire                               DDR3_cas_n;
  wire                               DDR3_we_n;
  wire [CKE_WIDTH-1:0]               DDR3_cke;
  wire [CK_WIDTH-1:0]                DDR3_ck_p;
  wire [CK_WIDTH-1:0]                DDR3_ck_n;
    
  
  wire                               tg_compare_error;
  wire [(CS_WIDTH*nCS_PER_RANK)-1:0] DDR3_cs_n;
    
  wire [DM_WIDTH-1:0]                DDR3_dm;
    
  wire [ODT_WIDTH-1:0]               DDR3_odt;
    
  
  reg [(CS_WIDTH*nCS_PER_RANK)-1:0] DDR3_cs_n_sdram_tmp;
    
  reg [DM_WIDTH-1:0]                 DDR3_dm_sdram_tmp;
    
  reg [ODT_WIDTH-1:0]                DDR3_odt_sdram_tmp;
    

  
  wire [DQ_WIDTH-1:0]                DDR3_dq_sdram;
  reg [ROW_WIDTH-1:0]                DDR3_addr_sdram [0:1];
  reg [BANK_WIDTH-1:0]               DDR3_ba_sdram [0:1];
  reg                                DDR3_ras_n_sdram;
  reg                                DDR3_cas_n_sdram;
  reg                                DDR3_we_n_sdram;
  wire [(CS_WIDTH*nCS_PER_RANK)-1:0] DDR3_cs_n_sdram;
  wire [ODT_WIDTH-1:0]               DDR3_odt_sdram;
  reg [CKE_WIDTH-1:0]                DDR3_cke_sdram;
  wire [DM_WIDTH-1:0]                DDR3_dm_sdram;
  wire [DQS_WIDTH-1:0]               DDR3_dqs_p_sdram;
  wire [DQS_WIDTH-1:0]               DDR3_dqs_n_sdram;
  reg [CK_WIDTH-1:0]                 DDR3_ck_p_sdram;
  reg [CK_WIDTH-1:0]                 DDR3_ck_n_sdram;
         
 //Count clock cycle *********************************************************//
  integer cyc_count = 0; 

 //**************************************************************************//

//Application wire or reg declare

wire ap_ready_0;
wire ap_done_0;
wire ap_idle_0;

  //**************************************************************************//
  // Reset Generation
  //**************************************************************************//
  initial begin
    sys_rst_n = 1'b0;
    //aresetn = 1'b0;
    #RESET_PERIOD
      sys_rst_n = 1'b1;
      //aresetn = 1'b1;
   end

   assign sys_rst = RST_ACT_LOW ? sys_rst_n : ~sys_rst_n;
    assign aresetn=1'b1;
  //**************************************************************************//
  // Clock Generation
  //**************************************************************************//

  initial
    sys_clk_i = 1'b0;
  always
    sys_clk_i = #(CLKIN_PERIOD/2.0) ~sys_clk_i;

  initial 
    aclk = 1'b0;
  always
    aclk = #(CORE_CLOCK/2.0) ~aclk;

  initial
    clk_ref_i = 1'b0;
  always
    clk_ref_i = #REFCLK_PERIOD ~clk_ref_i;

  always @(posedge aclk)
    if (start_count)
      cyc_count = cyc_count + 1;

  always @( * ) begin
    DDR3_ck_p_sdram      <=  #(TPROP_PCB_CTRL) DDR3_ck_p;
    DDR3_ck_n_sdram      <=  #(TPROP_PCB_CTRL) DDR3_ck_n;
    DDR3_addr_sdram[0]   <=  #(TPROP_PCB_CTRL) DDR3_addr;
    DDR3_addr_sdram[1]   <=  #(TPROP_PCB_CTRL) (CA_MIRROR == "ON") ?
                                                 {DDR3_addr[ROW_WIDTH-1:9],
                                                  DDR3_addr[7], DDR3_addr[8],
                                                  DDR3_addr[5], DDR3_addr[6],
                                                  DDR3_addr[3], DDR3_addr[4],
                                                  DDR3_addr[2:0]} :
                                                 DDR3_addr;
    DDR3_ba_sdram[0]     <=  #(TPROP_PCB_CTRL) DDR3_ba;
    DDR3_ba_sdram[1]     <=  #(TPROP_PCB_CTRL) (CA_MIRROR == "ON") ?
                                                 {DDR3_ba[3-1:2],
                                                  DDR3_ba[0],
                                                  DDR3_ba[1]} :
                                                 DDR3_ba;
    DDR3_ras_n_sdram     <=  #(TPROP_PCB_CTRL) DDR3_ras_n;
    DDR3_cas_n_sdram     <=  #(TPROP_PCB_CTRL) DDR3_cas_n;
    DDR3_we_n_sdram      <=  #(TPROP_PCB_CTRL) DDR3_we_n;
    DDR3_cke_sdram       <=  #(TPROP_PCB_CTRL) DDR3_cke;
  end
    

  always @( * )
    DDR3_cs_n_sdram_tmp   <=  #(TPROP_PCB_CTRL) DDR3_cs_n;
  assign DDR3_cs_n_sdram =  DDR3_cs_n_sdram_tmp;
    

  always @( * )
    DDR3_dm_sdram_tmp <=  #(TPROP_PCB_DATA) DDR3_dm;//DM signal generation
  assign DDR3_dm_sdram = DDR3_dm_sdram_tmp;
    

  always @( * )
    DDR3_odt_sdram_tmp  <=  #(TPROP_PCB_CTRL) DDR3_odt;
  assign DDR3_odt_sdram =  DDR3_odt_sdram_tmp;
    

// Controlling the bi-directional BUS

  genvar dqwd;
  generate
    for (dqwd = 1;dqwd < DQ_WIDTH;dqwd = dqwd+1) begin : dq_delay
      WireDelay #
       (
        .Delay_g    (TPROP_PCB_DATA),
        .Delay_rd   (TPROP_PCB_DATA_RD),
        .ERR_INSERT ("OFF")
       )
      u_delay_dq
       (
        .A             (DDR3_dq[dqwd]),
        .B             (DDR3_dq_sdram[dqwd]),
        .reset         (sys_rst_n),
        .phy_init_done (init_calib_complete)
       );
    end
    // For ECC ON case error is inserted on LSB bit from DRAM to FPGA
          WireDelay #
       (
        .Delay_g    (TPROP_PCB_DATA),
        .Delay_rd   (TPROP_PCB_DATA_RD),
        .ERR_INSERT (ERR_INSERT)
       )
      u_delay_dq_0
       (
        .A             (DDR3_dq[0]),
        .B             (DDR3_dq_sdram[0]),
        .reset         (sys_rst_n),
        .phy_init_done (init_calib_complete)
       );
  endgenerate

  genvar dqswd;
  generate
    for (dqswd = 0;dqswd < DQS_WIDTH;dqswd = dqswd+1) begin : dqs_delay
      WireDelay #
       (
        .Delay_g    (TPROP_DQS),
        .Delay_rd   (TPROP_DQS_RD),
        .ERR_INSERT ("OFF")
       )
      u_delay_dqs_p
       (
        .A             (DDR3_dqs_p[dqswd]),
        .B             (DDR3_dqs_p_sdram[dqswd]),
        .reset         (sys_rst_n),
        .phy_init_done (init_calib_complete)
       );

      WireDelay #
       (
        .Delay_g    (TPROP_DQS),
        .Delay_rd   (TPROP_DQS_RD),
        .ERR_INSERT ("OFF")
       )
      u_delay_dqs_n
       (
        .A             (DDR3_dqs_n[dqswd]),
        .B             (DDR3_dqs_n_sdram[dqswd]),
        .reset         (sys_rst_n),
        .phy_init_done (init_calib_complete)
       );
    end
  endgenerate
    
    

  //===========================================================================
  //Application system top func
  //===========================================================================
  design_1_wrapper design_1_u(
    .DDR3_addr(DDR3_addr),
    .DDR3_ba(DDR3_ba),
    .DDR3_cas_n(DDR3_cas_n),
    .DDR3_ck_n(DDR3_ck_n),
    .DDR3_ck_p(DDR3_ck_p),
    .DDR3_cke(DDR3_cke),
    .DDR3_cs_n(DDR3_cs_n),
    .DDR3_dm(DDR3_dm),
    .DDR3_dq(DDR3_dq),
    .DDR3_dqs_n(DDR3_dqs_n),
    .DDR3_dqs_p(DDR3_dqs_p),
    .DDR3_odt(DDR3_odt),
    .DDR3_ras_n(DDR3_ras_n),
    .DDR3_reset_n(DDR3_reset_n),
    .DDR3_we_n(DDR3_we_n),
    .ap_start(ap_start),
    .clk_ref_i(clk_ref_i),
    .init_calib_complete(init_calib_complete),
    .sys_clk_i(sys_clk_i),
    .aclk(aclk),
    .ap_done(ap_done),
    .sys_rst(sys_rst));
  //**************************************************************************//
  // Memory Models instantiations
  //**************************************************************************//
  parameter DATA_SIZE = 32768; // make sure it is large enough

  genvar r,i;
  generate
    for (r = 0; r < CS_WIDTH; r = r + 1) begin: mem_rnk
      for (i = 0; i < NUM_COMP; i = i + 1) begin: gen_mem
        ddr3_model 
        #(.comp_no(i), 
          .DQ_WIDTH(DQ_WIDTH), 
          .NUM_COMP(NUM_COMP),
          .MEMORY_WIDTH(MEMORY_WIDTH), 
          .DATA_SIZE(DATA_SIZE)) u_comp_ddr3 
          (
           .rst_n   (DDR3_reset_n),
           .ck      (DDR3_ck_p_sdram),
           .ck_n    (DDR3_ck_n_sdram),
           .cke     (DDR3_cke_sdram[r]),
           .cs_n    (DDR3_cs_n_sdram[r]),
           .ras_n   (DDR3_ras_n_sdram),
           .cas_n   (DDR3_cas_n_sdram),
           .we_n    (DDR3_we_n_sdram),
           .dm_tdqs (DDR3_dm_sdram[i]),
           .ba      (DDR3_ba_sdram[r]),
           .addr    (DDR3_addr_sdram[r]),
           .dq      (DDR3_dq_sdram[MEMORY_WIDTH*(i+1)-1:MEMORY_WIDTH*(i)]),
           .dqs     (DDR3_dqs_p_sdram[i]),
           .dqs_n   (DDR3_dqs_n_sdram[i]),
           .tdqs_n  (),
           .odt     (DDR3_odt_sdram[r]),
           .init_calib_complete(init_calib_complete)
           );
      end
    end
  endgenerate

  always @(DDR3_dq) begin
   if (init_calib_complete)
    $display("[%t] data=%h, addr=%h\n", $time, DDR3_dq, DDR3_addr);
  end 
 
  //***************************************************************************
  // Reporting the test case status
  // Status reporting logic exists both in simulation test bench (sim_tb_top)
  // and sim.do file for ModelSim. Any update in simulation run time or time out
  // in this file need to be updated in sim.do file as well.
  //***************************************************************************
          initial
            begin : Logging
               integer i;
               integer j;
               integer z;
               reg [2048:1] file_mem_final;
               reg [DQ_WIDTH-1:0] mem_final[DATA_SIZE-1:0];
               reg [DQ_WIDTH-1:0] mem_data[MEMORY_WIDTH*DATA_SIZE-1:0];

               fork
                  begin : calibration_done
                     wait (init_calib_complete);
                     $display("Calibration Done at %d", $time);
                     ap_start <= 1;
                     start_count <= 1;
                     $display("Start %d!", $time);
                     #1000000;
                     $display("Stop %d!", $time);
                     ap_start <= 0;
                     wait (ap_done);
		     $display("[%t] clock cycle count: %d", $time, cyc_count);
		     $display("FINAL_LATENCY=%d", cyc_count);
                     /*
                     // delay time to wait for all the written data to emerge in memory
                     #100000000; 
                     // then, write to output file for verification
                     for (j = 0; j < NUM_COMP; j = j + 1) begin
                      $sformat(file_mem_final, "mem_final_%0d.hex", j);
                      $readmemh(file_mem_final, mem_final);
                      for (i = 0; i < DATA_SIZE; i = i + 1) begin
                        for (z = 0; z < MEMORY_WIDTH; z = z + 1) begin
                          mem_data[i*MEMORY_WIDTH+z][MEMORY_WIDTH*j +: MEMORY_WIDTH] = mem_final[i][MEMORY_WIDTH*z +: MEMORY_WIDTH];
                        end
                      end
                     end
                     $writememh("mem_data_final.hex", mem_data);
                     */
                     $finish;
                  end
          
                  begin : calib_not_done
                     if (SIM_BYPASS_INIT_CAL == "SIM_INIT_CAL_FULL")
                       #2500000000.0;
                     else
                       #100000000000.0;
                       
                     if (!init_calib_complete) begin
                        $display("TEST FAILED: INITIALIZATION DID NOT COMPLETE");
                     end
                     
                     disable calibration_done;
                      $finish;
                  end
               join
            end
    
endmodule
