/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module indirect_reg_access #(
  parameter IN_ADDR_WIDTH          = 21,
  parameter OUT_ADDR_WIDTH         = 37,
  parameter DATA_WIDTH             = 32,
  parameter REG_DATA_WIDTH         = 512,
  parameter STRB_WIDTH             = (REG_DATA_WIDTH+7)/8,
  parameter AXI4_CQ_TUSER_WIDTH            = 183,
  parameter AXI4_CC_TUSER_WIDTH            = 81,
  parameter AXI4_RQ_TUSER_WIDTH            = 137,
  parameter AXI4_RC_TUSER_WIDTH            = 161,
  parameter C_DATA_WIDTH           = 512,
  parameter KEEP_WIDTH             = C_DATA_WIDTH /32
)(

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME user_clk, ASSOCIATED_BUSIF m_axi:s_axi:m_axis_ing_req_mon:s_axis_ing_cmp_mon:m_axis_egr_req_mon:s_axis_egr_cmp_mon, ASSOCIATED_RESET reset_n, FREQ_TOLERANCE_HZ 0, PHASE 0.000, CLK_DOMAIN design_1_pcie4_uscale_plus_0_0_user_clk, INSERT_VIP 0" *)
  input  wire                           user_clk,
  input  wire                           reset_n,


  // AXI4-Lite Interface
  input  wire          [IN_ADDR_WIDTH-1:0] s_axi_awaddr,
  input  wire                     [2:0] s_axi_awprot,
  input  wire                           s_axi_awvalid,
  output wire                           s_axi_awready,
  input  wire                    [31:0] s_axi_wdata,
  input  wire                     [3:0] s_axi_wstrb,
  input  wire                           s_axi_wvalid,
  output wire                           s_axi_wready,
  output wire                     [1:0] s_axi_bresp,  // open
  output wire                           s_axi_bvalid, // Write response (unused)
  input  wire                           s_axi_bready,
  input  wire          [IN_ADDR_WIDTH-1:0] s_axi_araddr,
  input  wire                     [2:0] s_axi_arprot,
  input  wire                           s_axi_arvalid,
  output wire                           s_axi_arready,
  output wire                    [31:0] s_axi_rdata,
  output wire                     [1:0] s_axi_rresp,  // open
  output wire                           s_axi_rvalid,
  input  wire                           s_axi_rready,

    // AXI4-Lite Interface
  output wire                        m_axi_AWVALID,
  input  wire                        m_axi_AWREADY,
  output wire  [OUT_ADDR_WIDTH-1:0]  m_axi_AWADDR,
  output wire                 [7:0]  m_axi_AWLEN,
  output wire                 [2:0]  m_axi_AWSIZE,
  output wire                 [1:0]  m_axi_AWBURST,
  output wire                        m_axi_AWLOCK,
  output wire                 [3:0]  m_axi_AWCACHE,
  output wire                 [2:0]  m_axi_AWPROT,
  output wire                 [3:0]  m_axi_AWQOS,
  output wire                 [3:0]  m_axi_AWREGION,
  output wire                        m_axi_WVALID,
  input  wire                        m_axi_WREADY,
  output wire  [REG_DATA_WIDTH-1:0]  m_axi_WDATA,
  output wire  [STRB_WIDTH-1:0]      m_axi_WSTRB,
  output wire                        m_axi_WLAST,
  output wire                        m_axi_ARVALID,
  input  wire                        m_axi_ARREADY,
  output wire  [OUT_ADDR_WIDTH-1:0]  m_axi_ARADDR,
  output wire                 [7:0]  m_axi_ARLEN,
  output wire                 [2:0]  m_axi_ARSIZE,
  output wire                 [1:0]  m_axi_ARBURST,
  output wire                        m_axi_ARLOCK,
  output wire                 [3:0]  m_axi_ARCACHE,
  output wire                 [2:0]  m_axi_ARPROT,
  output wire                 [3:0]  m_axi_ARQOS,
  output wire                 [3:0]  m_axi_ARREGION,
  input  wire                        m_axi_RVALID,
  output wire                        m_axi_RREADY,
  input  wire  [REG_DATA_WIDTH-1:0]  m_axi_RDATA,
  input  wire                        m_axi_RLAST,
  input  wire                 [1:0]  m_axi_RRESP,
  input  wire                        m_axi_BVALID,
  output wire                        m_axi_BREADY,
  input  wire                 [1:0]  m_axi_BRESP,
  
  // AXI-S Completer Request Interface(ing)
  input  wire                           m_axis_ing_req_mon_tvalid,
  input  wire        [C_DATA_WIDTH-1:0] m_axis_ing_req_mon_tdata,
  input  wire          [KEEP_WIDTH-1:0] m_axis_ing_req_mon_tkeep,
  input  wire                           m_axis_ing_req_mon_tlast,
  input  wire [AXI4_CQ_TUSER_WIDTH-1:0] m_axis_ing_req_mon_tuser,
  input  wire                           m_axis_ing_req_mon_tready,

  // AXI-S Completer Completion Interface(ing)
  input  wire                           s_axis_ing_cmp_mon_tvalid,
  input  wire        [C_DATA_WIDTH-1:0] s_axis_ing_cmp_mon_tdata,
  input  wire          [KEEP_WIDTH-1:0] s_axis_ing_cmp_mon_tkeep,
  input  wire                           s_axis_ing_cmp_mon_tlast,
  input  wire [AXI4_CC_TUSER_WIDTH-1:0] s_axis_ing_cmp_mon_tuser,
  input  wire                           s_axis_ing_cmp_mon_tready,
  
  
  // AXI-S Completer Request Interface(egr)
  input  wire                           m_axis_egr_req_mon_tvalid,
  input  wire        [C_DATA_WIDTH-1:0] m_axis_egr_req_mon_tdata,
  input  wire          [KEEP_WIDTH-1:0] m_axis_egr_req_mon_tkeep,
  input  wire                           m_axis_egr_req_mon_tlast,
  input  wire [AXI4_RQ_TUSER_WIDTH-1:0] m_axis_egr_req_mon_tuser,
  input  wire                           m_axis_egr_req_mon_tready,

  // AXI-S Completer Completion Interface(egr)
  input  wire                           s_axis_egr_cmp_mon_tvalid,
  input  wire        [C_DATA_WIDTH-1:0] s_axis_egr_cmp_mon_tdata,
  input  wire          [KEEP_WIDTH-1:0] s_axis_egr_cmp_mon_tkeep,
  input  wire                           s_axis_egr_cmp_mon_tlast,
  input  wire [AXI4_RC_TUSER_WIDTH-1:0] s_axis_egr_cmp_mon_tuser,
  input  wire                           s_axis_egr_cmp_mon_tready

);

  // Register address
  localparam ADDR_CHANNEL_0         = 21'h00_0000;
  localparam ADDR_REG_WRITE         = 21'h00_0010;
  localparam ADDR_REG_READ          = 21'h00_0014;
  localparam ADDR_REG_RRESP         = 21'h00_0018;
  localparam ADDR_REG_ADDR_L        = 21'h00_0020;
  localparam ADDR_REG_ADDR_H        = 21'h00_0024;
  localparam ADDR_REG_DATA_WRITE_0  = 21'h00_0100;
  localparam ADDR_REG_DATA_WRITE_1  = 21'h00_0104;
  localparam ADDR_REG_DATA_WRITE_2  = 21'h00_0108;
  localparam ADDR_REG_DATA_WRITE_3  = 21'h00_010C;
  localparam ADDR_REG_DATA_WRITE_4  = 21'h00_0110;
  localparam ADDR_REG_DATA_WRITE_5  = 21'h00_0114;
  localparam ADDR_REG_DATA_WRITE_6  = 21'h00_0118;
  localparam ADDR_REG_DATA_WRITE_7  = 21'h00_011C;
  localparam ADDR_REG_DATA_WRITE_8  = 21'h00_0120;
  localparam ADDR_REG_DATA_WRITE_9  = 21'h00_0124;
  localparam ADDR_REG_DATA_WRITE_10 = 21'h00_0128;
  localparam ADDR_REG_DATA_WRITE_11 = 21'h00_012C;
  localparam ADDR_REG_DATA_WRITE_12 = 21'h00_0130;
  localparam ADDR_REG_DATA_WRITE_13 = 21'h00_0134;
  localparam ADDR_REG_DATA_WRITE_14 = 21'h00_0138;
  localparam ADDR_REG_DATA_WRITE_15 = 21'h00_013C;
  localparam ADDR_REG_DATA_READ_0   = 21'h00_0200;
  localparam ADDR_REG_DATA_READ_1   = 21'h00_0204;
  localparam ADDR_REG_DATA_READ_2   = 21'h00_0208;
  localparam ADDR_REG_DATA_READ_3   = 21'h00_020C;
  localparam ADDR_REG_DATA_READ_4   = 21'h00_0210;
  localparam ADDR_REG_DATA_READ_5   = 21'h00_0214;
  localparam ADDR_REG_DATA_READ_6   = 21'h00_0218;
  localparam ADDR_REG_DATA_READ_7   = 21'h00_021C;
  localparam ADDR_REG_DATA_READ_8   = 21'h00_0220;
  localparam ADDR_REG_DATA_READ_9   = 21'h00_0224;
  localparam ADDR_REG_DATA_READ_10  = 21'h00_0228;
  localparam ADDR_REG_DATA_READ_11  = 21'h00_022C;
  localparam ADDR_REG_DATA_READ_12  = 21'h00_0230;
  localparam ADDR_REG_DATA_READ_13  = 21'h00_0234;
  localparam ADDR_REG_DATA_READ_14  = 21'h00_0238;
  localparam ADDR_REG_DATA_READ_15  = 21'h00_023C;
  localparam ADDR_REG_WRIRE_REQ_COUNT    = 21'h00_0300;
  localparam ADDR_REG_READ_REQ_COUNT     = 21'h00_0304;
  localparam ADDR_REG_READ_REP_COUNT     = 21'h00_0308;
  localparam ADDR_REG_READY              = 21'h00_030C;
  localparam ADDR_REG_PCI_PA_COUNT_CTRL  = 21'h00_0400; //[1]enable,[0]reset
  localparam ADDR_REG_PCI_ING_MEM_RD_REQ_COUNT        = 21'h00_0500;
  localparam ADDR_REG_PCI_ING_MEM_WD_REQ_COUNT        = 21'h00_0504;
  localparam ADDR_REG_PCI_ING_I_O_RD_REQ_COUNT        = 21'h00_0508;
  localparam ADDR_REG_PCI_ING_I_O_WD_REQ_COUNT        = 21'h00_050C;
  localparam ADDR_REG_PCI_ING_MEM_FET_ADD_REQ_COUNT   = 21'h00_0510;
  localparam ADDR_REG_PCI_ING_MEM_UNCND_SWP_REQ_COUNT = 21'h00_0514;
  localparam ADDR_REG_PCI_ING_MEM_CMP_SWP_REQ_COUNT   = 21'h00_0518;
  localparam ADDR_REG_PCI_ING_LOCK_RD_REQ_COUNT       = 21'h00_051C;
  localparam ADDR_REG_PCI_ING_TYPE_0_CNF_RD_REQ_COUNT = 21'h00_0520;
  localparam ADDR_REG_PCI_ING_TYPE_1_CNF_RD_REQ_COUNT = 21'h00_0524;
  localparam ADDR_REG_PCI_ING_TYPE_0_CNF_WD_REQ_COUNT = 21'h00_0528;
  localparam ADDR_REG_PCI_ING_TYPE_1_CNF_WD_REQ_COUNT = 21'h00_052C;
  localparam ADDR_REG_PCI_ING_ANY_MESSAGE_COUNT       = 21'h00_0530;
  localparam ADDR_REG_PCI_ING_V_D_MESSAGE_COUNT       = 21'h00_0534;
  localparam ADDR_REG_PCI_ING_ATS_MESSAGE_COUNT       = 21'h00_0538;
  localparam ADDR_REG_PCI_ING_REQ_CMP_COUNT           = 21'h00_053C;
  localparam ADDR_REG_PCI_ENR_MEM_RD_REQ_COUNT        = 21'h00_0540;
  localparam ADDR_REG_PCI_ENR_MEM_WD_REQ_COUNT        = 21'h00_0544;
  localparam ADDR_REG_PCI_ENR_I_O_RD_REQ_COUNT        = 21'h00_0548;
  localparam ADDR_REG_PCI_ENR_I_O_WD_REQ_COUNT        = 21'h00_054C;
  localparam ADDR_REG_PCI_ENR_MEM_FET_ADD_REQ_COUNT   = 21'h00_0550;
  localparam ADDR_REG_PCI_ENR_MEM_UNCND_SWP_REQ_COUNT = 21'h00_0554;
  localparam ADDR_REG_PCI_ENR_MEM_CMP_SWP_REQ_COUNT   = 21'h00_0558;
  localparam ADDR_REG_PCI_ENR_LOCK_RD_REQ_COUNT       = 21'h00_055C;
  localparam ADDR_REG_PCI_ENR_TYPE_0_CNF_RD_REQ_COUNT = 21'h00_0560;
  localparam ADDR_REG_PCI_ENR_TYPE_1_CNF_RD_REQ_COUNT = 21'h00_0564;
  localparam ADDR_REG_PCI_ENR_TYPE_0_CNF_WD_REQ_COUNT = 21'h00_0568;
  localparam ADDR_REG_PCI_ENR_TYPE_1_CNF_WD_REQ_COUNT = 21'h00_056C;
  localparam ADDR_REG_PCI_ENR_ANY_MESSAGE_COUNT       = 21'h00_0570;
  localparam ADDR_REG_PCI_ENR_V_D_MESSAGE_COUNT       = 21'h00_0574;
  localparam ADDR_REG_PCI_ENR_ATS_MESSAGE_COUNT       = 21'h00_0578;
  localparam ADDR_REG_PCI_ENR_REQ_CMP_COUNT           = 21'h00_057C;
  
  
  localparam REG_DATA_WIDTH_REST  = 512 - REG_DATA_WIDTH;
    
  // Local Bus
  wire[IN_ADDR_WIDTH-1:0]w_local_addr    ;
  wire                w_local_wr_en   ;
  wire[DATA_WIDTH-1:0]w_local_wr_data ;
  reg                 r_local_wr_ack  ;
  wire                w_local_rd_en   ;
  reg                 r_local_rd_ack  ;
  reg[DATA_WIDTH-1:0] r_local_rd_data ;
  
  reg  [OUT_ADDR_WIDTH-1:0] sr_m_axi_awaddr;
  reg                   sr_m_axi_awvalid;
  reg  [REG_DATA_WIDTH-1:0]           sr_m_axi_wdata;
  reg                   sr_m_axi_wvalid;
  reg  [OUT_ADDR_WIDTH-1:0] sr_m_axi_araddr;
  reg                   sr_m_axi_arvalid;
  reg  [31:0]           sr_m_axi_rresp;
  
  
  reg [63:0]  sr_indirection_address;
  reg [511:0] sr_indirection_writedata;
  reg [511:0] sr_indirection_readdata;
  reg         sr_indirection_read;
  reg         sr_indirection_write;
  reg [31:0]  sr_write_req_count;
  reg [31:0]  sr_read_req_count;
  reg [31:0]  sr_read_rep_count;
  reg [31:0]  sr_status_ready;
  
  reg  sr_pa_count_reset;
  reg  sr_pa_count_enable;
  
  wire [31:0] w_ing_mem_rd_req_count;
  wire [31:0] w_ing_mem_wd_req_count;
  wire [31:0] w_ing_i_o_rd_req_count;
  wire [31:0] w_ing_i_o_wd_req_count;
  wire [31:0] w_ing_mem_fet_add_req_count;
  wire [31:0] w_ing_mem_uncnd_swp_req_count;
  wire [31:0] w_ing_mem_cmp_swp_req_count;
  wire [31:0] w_ing_lock_rd_req_count;
  wire [31:0] w_ing_type_0_cnf_rd_req_count;
  wire [31:0] w_ing_type_1_cnf_rd_req_count;
  wire [31:0] w_ing_type_0_cnf_wd_req_count;
  wire [31:0] w_ing_type_1_cnf_wd_req_count;
  wire [31:0] w_ing_any_message_count;
  wire [31:0] w_ing_v_d_message_count;
  wire [31:0] w_ing_ats_message_count;
  wire [31:0] w_ing_req_reserved_count;
  wire [31:0] w_ing_req_cmp_count;

  wire [31:0] w_egr_mem_rd_req_count;
  wire [31:0] w_egr_mem_wd_req_count;
  wire [31:0] w_egr_i_o_rd_req_count;
  wire [31:0] w_egr_i_o_wd_req_count;
  wire [31:0] w_egr_mem_fet_add_req_count;
  wire [31:0] w_egr_mem_uncnd_swp_req_count;
  wire [31:0] w_egr_mem_cmp_swp_req_count;
  wire [31:0] w_egr_lock_rd_req_count;
  wire [31:0] w_egr_type_0_cnf_rd_req_count;
  wire [31:0] w_egr_type_1_cnf_rd_req_count;
  wire [31:0] w_egr_type_0_cnf_wd_req_count;
  wire [31:0] w_egr_type_1_cnf_wd_req_count;
  wire [31:0] w_egr_any_message_count;
  wire [31:0] w_egr_v_d_message_count;
  wire [31:0] w_egr_ats_message_count;
  wire [31:0] w_egr_req_reserved_count;
  wire [31:0] w_egr_req_cmp_count;

  
  wire w_req_busy;
  //assign w_req_busy = (sr_m_axi_awvalid&&!m_axi_awready)||(sr_m_axi_wvalid&&!m_axi_wready)||(sr_m_axi_arvalid&&!m_axi_arready);
  assign w_req_busy = (sr_m_axi_awvalid&&!m_axi_AWREADY)||(sr_m_axi_wvalid&&!m_axi_WREADY)||(sr_m_axi_arvalid&&!m_axi_ARREADY);
  
  // AXI Lite Termination
  axi_lite_end_point #(
      .ADDR_WIDTH (IN_ADDR_WIDTH ), // integer
      .DATA_WIDTH (DATA_WIDTH )  // integer
  ) axi_endpoint (
      .aclk           (user_clk               ), // input
      .resetn         (reset_n                ), // input
      .s_axi_araddr   (s_axi_araddr           ), // input
      .s_axi_arvalid  (s_axi_arvalid          ), // input
      .s_axi_arready  (s_axi_arready          ), // output
      .s_axi_rdata    (s_axi_rdata            ), // output
      .s_axi_rresp    (s_axi_rresp            ), // output
      .s_axi_rvalid   (s_axi_rvalid           ), // output
      .s_axi_rready   (s_axi_rready           ), // input
      .s_axi_awaddr   (s_axi_awaddr           ), // input
      .s_axi_awvalid  (s_axi_awvalid          ), // input
      .s_axi_awready  (s_axi_awready          ), // output
      .s_axi_wdata    (s_axi_wdata            ), // input
      .s_axi_wstrb    (s_axi_wstrb            ), // input
      .s_axi_wvalid   (s_axi_wvalid           ), // input
      .s_axi_wready   (s_axi_wready           ), // output
      .s_axi_bresp    (s_axi_bresp            ), // output
      .s_axi_bvalid   (s_axi_bvalid           ), // output
      .s_axi_bready   (s_axi_bready           ), // input
      .local_addr     (w_local_addr           ), // output
      .local_wr_en    (w_local_wr_en          ), // output
      .local_wr_data  (w_local_wr_data        ), // output
      .local_wr_ack   (r_local_wr_ack         ), // input
      .local_rd_en    (w_local_rd_en          ), // output
      .local_rd_data  (r_local_rd_data        ), // input
      .local_rd_ack   (r_local_rd_ack         )  // input
  );
  
  reg   [31:0] sr_test_reg_0;
  reg   [31:0] sr_test_reg_1;
  reg   [31:0] sr_test_reg_2;
  reg   [31:0] sr_test_reg_3;
  reg   [31:0] sr_test_reg_4;
  reg   [31:0] sr_test_reg_5;
  reg   [31:0] sr_test_reg_6;
  reg   [31:0] sr_test_reg_7;
  reg   [31:0] sr_test_reg_8;
  reg   [31:0] sr_test_reg_9;
  reg   [31:0] sr_test_reg_10;
  reg   [31:0] sr_test_reg_11;
  reg   [31:0] sr_test_reg_12;
  reg   [31:0] sr_test_reg_13;
  reg   [31:0] sr_test_reg_14;
  reg   [31:0] sr_test_reg_15;
  reg   [31:0] sr_test_reg_16;
  reg   [31:0] sr_test_reg_17;
  reg   [31:0] sr_test_reg_18;
  reg   [31:0] sr_test_reg_19;
  
    
  // register write (write)
  always @(posedge user_clk or negedge reset_n) begin
    if(!reset_n) begin
          sr_test_reg_0            <= 32'h1020_0304;
          sr_indirection_address   <= {64{1'b0}};
          sr_indirection_writedata <= {512{1'b0}};
          sr_pa_count_enable       <= 1'b0;
          sr_pa_count_reset        <= 1'b0;
      end else begin
          r_local_wr_ack <= w_local_wr_en;
          if (w_local_wr_en) begin
              case (w_local_addr)
              ADDR_CHANNEL_0[IN_ADDR_WIDTH-1:0]         : sr_test_reg_0                      <= w_local_wr_data;
              ADDR_REG_ADDR_L[IN_ADDR_WIDTH-1:0]        : sr_indirection_address[31:0]       <= w_local_wr_data;
              ADDR_REG_ADDR_H[IN_ADDR_WIDTH-1:0]        : sr_indirection_address[63:32]      <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_0[IN_ADDR_WIDTH-1:0]  : sr_indirection_writedata[31:0]     <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_1[IN_ADDR_WIDTH-1:0]  : sr_indirection_writedata[63:32]    <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_2[IN_ADDR_WIDTH-1:0]  : sr_indirection_writedata[95:64]    <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_3[IN_ADDR_WIDTH-1:0]  : sr_indirection_writedata[127:96]   <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_4[IN_ADDR_WIDTH-1:0]  : sr_indirection_writedata[159:128]  <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_5[IN_ADDR_WIDTH-1:0]  : sr_indirection_writedata[191:160]  <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_6[IN_ADDR_WIDTH-1:0]  : sr_indirection_writedata[223:192]  <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_7[IN_ADDR_WIDTH-1:0]  : sr_indirection_writedata[255:224]  <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_8[IN_ADDR_WIDTH-1:0]  : sr_indirection_writedata[287:256]  <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_9[IN_ADDR_WIDTH-1:0]  : sr_indirection_writedata[319:288]  <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_10[IN_ADDR_WIDTH-1:0] : sr_indirection_writedata[351:320]  <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_11[IN_ADDR_WIDTH-1:0] : sr_indirection_writedata[383:352]  <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_12[IN_ADDR_WIDTH-1:0] : sr_indirection_writedata[415:384]  <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_13[IN_ADDR_WIDTH-1:0] : sr_indirection_writedata[447:416]  <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_14[IN_ADDR_WIDTH-1:0] : sr_indirection_writedata[479:448]  <= w_local_wr_data;
              ADDR_REG_DATA_WRITE_15[IN_ADDR_WIDTH-1:0] : sr_indirection_writedata[511:480]  <= w_local_wr_data;
              ADDR_REG_PCI_PA_COUNT_CTRL[IN_ADDR_WIDTH-1:0] : sr_pa_count_enable             <= w_local_wr_data[1];
              endcase
          end
          
          //one shot
          sr_pa_count_reset  <= (w_local_addr==ADDR_REG_PCI_PA_COUNT_CTRL[IN_ADDR_WIDTH-1:0])&&w_local_wr_data[0];
      end
  end
  
  // register read
  always @(posedge user_clk or negedge reset_n) begin
    if(!reset_n) begin
          r_local_rd_ack <= 1'b0;
          r_local_rd_data <= {DATA_WIDTH{1'b0}};
      end else begin
          r_local_rd_ack <= w_local_rd_en;
          if (w_local_rd_en) begin
              case (w_local_addr)
              ADDR_CHANNEL_0[IN_ADDR_WIDTH-1:0]         : r_local_rd_data <= sr_test_reg_0 ;
              ADDR_REG_RRESP[IN_ADDR_WIDTH-1:0]         : r_local_rd_data <= sr_m_axi_rresp ;
              ADDR_REG_ADDR_L[IN_ADDR_WIDTH-1:0]        : r_local_rd_data <= sr_indirection_address[31:0] ;
              ADDR_REG_ADDR_H[IN_ADDR_WIDTH-1:0]        : r_local_rd_data <= sr_indirection_address[63:32] ;
              ADDR_REG_DATA_WRITE_0[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_writedata[31:0]    ;
              ADDR_REG_DATA_WRITE_1[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_writedata[63:32]   ;
              ADDR_REG_DATA_WRITE_2[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_writedata[95:64]   ;
              ADDR_REG_DATA_WRITE_3[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_writedata[127:96]  ;
              ADDR_REG_DATA_WRITE_4[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_writedata[159:128] ;
              ADDR_REG_DATA_WRITE_5[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_writedata[191:160] ;
              ADDR_REG_DATA_WRITE_6[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_writedata[223:192] ;
              ADDR_REG_DATA_WRITE_7[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_writedata[255:224] ;
              ADDR_REG_DATA_WRITE_8[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_writedata[287:256] ;
              ADDR_REG_DATA_WRITE_9[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_writedata[319:288] ;
              ADDR_REG_DATA_WRITE_10[IN_ADDR_WIDTH-1:0] : r_local_rd_data <= sr_indirection_writedata[351:320] ;
              ADDR_REG_DATA_WRITE_11[IN_ADDR_WIDTH-1:0] : r_local_rd_data <= sr_indirection_writedata[383:352] ;
              ADDR_REG_DATA_WRITE_12[IN_ADDR_WIDTH-1:0] : r_local_rd_data <= sr_indirection_writedata[415:384] ;
              ADDR_REG_DATA_WRITE_13[IN_ADDR_WIDTH-1:0] : r_local_rd_data <= sr_indirection_writedata[447:416] ;
              ADDR_REG_DATA_WRITE_14[IN_ADDR_WIDTH-1:0] : r_local_rd_data <= sr_indirection_writedata[479:448] ;
              ADDR_REG_DATA_WRITE_15[IN_ADDR_WIDTH-1:0] : r_local_rd_data <= sr_indirection_writedata[511:480] ;
              ADDR_REG_DATA_READ_0[IN_ADDR_WIDTH-1:0]   : r_local_rd_data <= sr_indirection_readdata[31:0]    ;
              ADDR_REG_DATA_READ_1[IN_ADDR_WIDTH-1:0]   : r_local_rd_data <= sr_indirection_readdata[63:32]   ;
              ADDR_REG_DATA_READ_2[IN_ADDR_WIDTH-1:0]   : r_local_rd_data <= sr_indirection_readdata[95:64]   ;
              ADDR_REG_DATA_READ_3[IN_ADDR_WIDTH-1:0]   : r_local_rd_data <= sr_indirection_readdata[127:96]  ;
              ADDR_REG_DATA_READ_4[IN_ADDR_WIDTH-1:0]   : r_local_rd_data <= sr_indirection_readdata[159:128] ;
              ADDR_REG_DATA_READ_5[IN_ADDR_WIDTH-1:0]   : r_local_rd_data <= sr_indirection_readdata[191:160] ;
              ADDR_REG_DATA_READ_6[IN_ADDR_WIDTH-1:0]   : r_local_rd_data <= sr_indirection_readdata[223:192] ;
              ADDR_REG_DATA_READ_7[IN_ADDR_WIDTH-1:0]   : r_local_rd_data <= sr_indirection_readdata[255:224] ;
              ADDR_REG_DATA_READ_8[IN_ADDR_WIDTH-1:0]   : r_local_rd_data <= sr_indirection_readdata[287:256] ;
              ADDR_REG_DATA_READ_9[IN_ADDR_WIDTH-1:0]   : r_local_rd_data <= sr_indirection_readdata[319:288] ;
              ADDR_REG_DATA_READ_10[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_readdata[351:320] ;
              ADDR_REG_DATA_READ_11[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_readdata[383:352] ;
              ADDR_REG_DATA_READ_12[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_readdata[415:384] ;
              ADDR_REG_DATA_READ_13[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_readdata[447:416] ;
              ADDR_REG_DATA_READ_14[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_readdata[479:448] ;
              ADDR_REG_DATA_READ_15[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_indirection_readdata[511:480] ;
              ADDR_REG_WRIRE_REQ_COUNT[IN_ADDR_WIDTH-1:0] : r_local_rd_data <= sr_write_req_count ;
              ADDR_REG_READ_REQ_COUNT[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_read_req_count ;
              ADDR_REG_READ_REP_COUNT[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= sr_read_rep_count ;
              ADDR_REG_READY[IN_ADDR_WIDTH-1:0]           : r_local_rd_data <= sr_status_ready ;
              ADDR_REG_PCI_ING_MEM_RD_REQ_COUNT       [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_mem_rd_req_count;
              ADDR_REG_PCI_ING_MEM_WD_REQ_COUNT       [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_mem_wd_req_count;
              ADDR_REG_PCI_ING_I_O_RD_REQ_COUNT       [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_i_o_rd_req_count;
              ADDR_REG_PCI_ING_I_O_WD_REQ_COUNT       [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_i_o_wd_req_count;
              ADDR_REG_PCI_ING_MEM_FET_ADD_REQ_COUNT  [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_mem_fet_add_req_count;
              ADDR_REG_PCI_ING_MEM_UNCND_SWP_REQ_COUNT[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_mem_uncnd_swp_req_count;
              ADDR_REG_PCI_ING_MEM_CMP_SWP_REQ_COUNT  [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_mem_cmp_swp_req_count;
              ADDR_REG_PCI_ING_LOCK_RD_REQ_COUNT      [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_lock_rd_req_count;
              ADDR_REG_PCI_ING_TYPE_0_CNF_RD_REQ_COUNT[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_type_0_cnf_rd_req_count;
              ADDR_REG_PCI_ING_TYPE_1_CNF_RD_REQ_COUNT[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_type_1_cnf_rd_req_count;
              ADDR_REG_PCI_ING_TYPE_0_CNF_WD_REQ_COUNT[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_type_0_cnf_wd_req_count;
              ADDR_REG_PCI_ING_TYPE_1_CNF_WD_REQ_COUNT[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_type_1_cnf_wd_req_count;
              ADDR_REG_PCI_ING_ANY_MESSAGE_COUNT      [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_any_message_count;
              ADDR_REG_PCI_ING_V_D_MESSAGE_COUNT      [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_v_d_message_count;
              ADDR_REG_PCI_ING_ATS_MESSAGE_COUNT      [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_ats_message_count;
              ADDR_REG_PCI_ING_REQ_CMP_COUNT          [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_ing_req_cmp_count;
              ADDR_REG_PCI_ENR_MEM_RD_REQ_COUNT       [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_mem_rd_req_count;
              ADDR_REG_PCI_ENR_MEM_WD_REQ_COUNT       [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_mem_wd_req_count;
              ADDR_REG_PCI_ENR_I_O_RD_REQ_COUNT       [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_i_o_rd_req_count;
              ADDR_REG_PCI_ENR_I_O_WD_REQ_COUNT       [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_i_o_wd_req_count;
              ADDR_REG_PCI_ENR_MEM_FET_ADD_REQ_COUNT  [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_mem_fet_add_req_count;
              ADDR_REG_PCI_ENR_MEM_UNCND_SWP_REQ_COUNT[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_mem_uncnd_swp_req_count;
              ADDR_REG_PCI_ENR_MEM_CMP_SWP_REQ_COUNT  [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_mem_cmp_swp_req_count;
              ADDR_REG_PCI_ENR_LOCK_RD_REQ_COUNT      [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_lock_rd_req_count;
              ADDR_REG_PCI_ENR_TYPE_0_CNF_RD_REQ_COUNT[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_type_0_cnf_rd_req_count;
              ADDR_REG_PCI_ENR_TYPE_1_CNF_RD_REQ_COUNT[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_type_1_cnf_rd_req_count;
              ADDR_REG_PCI_ENR_TYPE_0_CNF_WD_REQ_COUNT[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_type_0_cnf_wd_req_count;
              ADDR_REG_PCI_ENR_TYPE_1_CNF_WD_REQ_COUNT[IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_type_1_cnf_wd_req_count;
              ADDR_REG_PCI_ENR_ANY_MESSAGE_COUNT      [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_any_message_count;
              ADDR_REG_PCI_ENR_V_D_MESSAGE_COUNT      [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_v_d_message_count;
              ADDR_REG_PCI_ENR_ATS_MESSAGE_COUNT      [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_ats_message_count;
              ADDR_REG_PCI_ENR_REQ_CMP_COUNT          [IN_ADDR_WIDTH-1:0]  : r_local_rd_data <= w_egr_req_cmp_count;
              default             : r_local_rd_data <= 32'h10101010;
              endcase
          end
      end
  end
  
  // Indirect access
  always @(posedge user_clk or negedge reset_n) begin
    if(!reset_n) begin
      sr_m_axi_awaddr  <= {OUT_ADDR_WIDTH{1'b0}}; 
      sr_m_axi_awvalid <= 1'b0;       
      sr_m_axi_wdata   <= {REG_DATA_WIDTH{1'b0}}; 
      sr_m_axi_wvalid  <= 1'b0;       
      sr_m_axi_araddr  <= {OUT_ADDR_WIDTH{1'b0}}; 
      sr_m_axi_arvalid <= 1'b0;     
    end else begin
      if(!w_req_busy)begin
        //write
        sr_m_axi_awaddr  <= sr_indirection_address[OUT_ADDR_WIDTH-1:0];
        sr_m_axi_awvalid <= w_local_wr_en&&(w_local_addr[IN_ADDR_WIDTH-1:0] == ADDR_REG_WRITE[IN_ADDR_WIDTH-1:0]);
        sr_m_axi_wdata   <= sr_indirection_writedata[REG_DATA_WIDTH-1:0];
        sr_m_axi_wvalid  <= w_local_wr_en&&(w_local_addr[IN_ADDR_WIDTH-1:0] == ADDR_REG_WRITE[IN_ADDR_WIDTH-1:0]);
        //read
        sr_m_axi_araddr  <= sr_indirection_address[OUT_ADDR_WIDTH-1:0];
        sr_m_axi_arvalid <= w_local_wr_en&&(w_local_addr[IN_ADDR_WIDTH-1:0] == ADDR_REG_READ[IN_ADDR_WIDTH-1:0]);
      end else begin //BP HOLD
        sr_m_axi_awaddr  <= sr_m_axi_awaddr;
        sr_m_axi_awvalid <= sr_m_axi_awvalid;
        sr_m_axi_wdata   <= sr_m_axi_wdata;
        sr_m_axi_wvalid  <= sr_m_axi_wvalid;
        sr_m_axi_araddr  <= sr_m_axi_araddr;
        sr_m_axi_arvalid <= sr_m_axi_arvalid;
      end
    end
  end
  
  // Read response
  always @(posedge user_clk or negedge reset_n) begin
    if(!reset_n) begin
      sr_indirection_readdata  <= {512{1'b0}};
      sr_m_axi_rresp   <= {32{1'b0}};
    end else begin
      if(m_axi_RVALID)begin
        sr_indirection_readdata <= {{REG_DATA_WIDTH_REST{1'b0}},m_axi_RDATA};
        sr_m_axi_rresp   <= {{30{1'b0}},m_axi_RRESP};
      end else begin
        sr_indirection_readdata <= sr_indirection_readdata;
        sr_m_axi_rresp          <= sr_m_axi_rresp;
      end
    end
  end

  // Debug counters
  always @(posedge user_clk or negedge reset_n) begin
    if(!reset_n) begin
      sr_write_req_count  <= {32{1'b0}};
      sr_read_req_count   <= {32{1'b0}};
      sr_read_rep_count   <= {32{1'b0}};
      sr_status_ready     <= {32{1'b0}};
    end else begin
      if(sr_m_axi_awvalid && m_axi_AWREADY)begin
        sr_write_req_count <= sr_write_req_count +1;
      end else begin
        sr_write_req_count <= sr_write_req_count;
      end

      if(sr_m_axi_arvalid && m_axi_ARREADY)begin
        sr_read_req_count <= sr_read_req_count +1;
      end else begin
        sr_read_req_count <= sr_read_req_count;
      end

      if(m_axi_RVALID)begin
        sr_read_rep_count <= sr_read_rep_count +1;
      end else begin
        sr_read_rep_count <= sr_read_rep_count;
      end
      
      sr_status_ready <= {26'h000,w_req_busy,sr_m_axi_awvalid,sr_m_axi_arvalid,m_axi_AWREADY,m_axi_WREADY,m_axi_ARREADY};
      
    end
  end
  
assign m_axi_AWVALID  = sr_m_axi_awvalid; //   output wire                        
assign m_axi_AWADDR   = sr_m_axi_awaddr; //   output wire  [OUT_ADDR_WIDTH-1:0]  
assign m_axi_AWLEN    = 8'h00; //   output wire                 [7:0]  
assign m_axi_AWSIZE   = 3'b110; //   output wire                 [2:0]  
assign m_axi_AWBURST  = 2'h0; //   output wire                 [1:0]  
assign m_axi_AWLOCK   = 1'h0; //   output wire                 [1:0]  
assign m_axi_AWCACHE  = 2'h0; //   output wire                 [3:0]  
assign m_axi_AWPROT   = 3'h0; //   output wire                 [2:0]  
assign m_axi_AWQOS    = 4'h0; //   output wire                 [3:0]  
assign m_axi_AWREGION = 2'h0; //   output wire                 [3:0]  
assign m_axi_WVALID   = sr_m_axi_awvalid; //   output wire                        
assign m_axi_WDATA    = sr_m_axi_wdata[REG_DATA_WIDTH-1:0]; //   output wire  [REG_DATA_WIDTH-1:0]  
assign m_axi_WSTRB    = {STRB_WIDTH{1'b1}}; //   output wire  [STRB_WIDTH-1:0]      
assign m_axi_WLAST    = sr_m_axi_awvalid; //   output wire                        
assign m_axi_ARVALID  = sr_m_axi_arvalid; //   output wire                        
assign m_axi_ARADDR   = sr_m_axi_araddr; //   output wire  [OUT_ADDR_WIDTH-1:0]  
assign m_axi_ARLEN    = 8'h00; //   output wire                 [7:0]  
assign m_axi_ARSIZE   = 3'b110; //   output wire                 [2:0]  
assign m_axi_ARBURST  = 2'h0; //   output wire                 [1:0]  
assign m_axi_ARLOCK   = 1'h0; //   output wire                 [1:0]  
assign m_axi_ARCACHE  = 4'h0; //   output wire                 [3:0]  
assign m_axi_ARPROT   = 3'h0; //   output wire                 [2:0]  
assign m_axi_ARQOS    = 4'h0; //   output wire                 [3:0]  
assign m_axi_ARREGION = 4'h0; //   output wire                 [3:0]  
assign m_axi_RREADY   = 1'b1; //   output wire                        
assign m_axi_BREADY   = 1'b1; //   output wire                        

  pci_pa_count #(
     .AXI4_CQ_TUSER_WIDTH(183),
     .AXI4_CC_TUSER_WIDTH(81),
     .C_DATA_WIDTH(512)
   ) pci_ing_pa_count(
     .user_clk               ( user_clk       ),
     .reset_n                ( reset_n        ),
     .m_axis_req_mon_tvalid  ( m_axis_ing_req_mon_tvalid  ),
     .m_axis_req_mon_tdata   ( m_axis_ing_req_mon_tdata   ),
     .m_axis_req_mon_tkeep   ( m_axis_ing_req_mon_tkeep   ),
     .m_axis_req_mon_tlast   ( m_axis_ing_req_mon_tlast   ),
     .m_axis_req_mon_tuser   ( m_axis_ing_req_mon_tuser   ),
     .m_axis_req_mon_tready  ( m_axis_ing_req_mon_tready  ),
     .s_axis_cmp_mon_tvalid  ( s_axis_ing_cmp_mon_tvalid  ),
     .s_axis_cmp_mon_tdata   ( s_axis_ing_cmp_mon_tdata   ),
     .s_axis_cmp_mon_tkeep   ( s_axis_ing_cmp_mon_tkeep   ),
     .s_axis_cmp_mon_tlast   ( s_axis_ing_cmp_mon_tlast   ),
     .s_axis_cmp_mon_tuser   ( s_axis_ing_cmp_mon_tuser   ),
     .s_axis_cmp_mon_tready  ( s_axis_ing_cmp_mon_tready  ),
     .pa_count_reset         ( sr_pa_count_reset          ),
     .pa_count_enable        ( sr_pa_count_enable         ),
     .mem_rd_req_count       ( w_ing_mem_rd_req_count        ),
     .mem_wd_req_count       ( w_ing_mem_wd_req_count        ),
     .i_o_rd_req_count       ( w_ing_i_o_rd_req_count        ),
     .i_o_wd_req_count       ( w_ing_i_o_wd_req_count        ),
     .mem_fet_add_req_count  ( w_ing_mem_fet_add_req_count   ),
     .mem_uncnd_swp_req_count( w_ing_mem_uncnd_swp_req_count ),
     .mem_cmp_swp_req_count  ( w_ing_mem_cmp_swp_req_count   ),
     .lock_rd_req_count      ( w_ing_lock_rd_req_count       ),
     .type_0_cnf_rd_req_count( w_ing_type_0_cnf_rd_req_count ),
     .type_1_cnf_rd_req_count( w_ing_type_1_cnf_rd_req_count ),
     .type_0_cnf_wd_req_count( w_ing_type_0_cnf_wd_req_count ),
     .type_1_cnf_wd_req_count( w_ing_type_1_cnf_wd_req_count ),
     .any_message_count      ( w_ing_any_message_count       ),
     .v_d_message_count      ( w_ing_v_d_message_count       ),
     .ats_message_count      ( w_ing_ats_message_count       ),
     .req_reserved_count     ( w_ing_req_reserved_count      ), //open
     .req_cmp_count          ( w_ing_req_cmp_count           )
   );

   pci_pa_count#(
     .AXI4_CQ_TUSER_WIDTH(183),
     .AXI4_CC_TUSER_WIDTH(81),
     .C_DATA_WIDTH(512)
   ) pci_egr_pa_count(
     .user_clk               ( user_clk       ),
     .reset_n                ( reset_n        ),
     .m_axis_req_mon_tvalid  ( m_axis_egr_req_mon_tvalid  ),
     .m_axis_req_mon_tdata   ( m_axis_egr_req_mon_tdata   ),
     .m_axis_req_mon_tkeep   ( m_axis_egr_req_mon_tkeep   ),
     .m_axis_req_mon_tlast   ( m_axis_egr_req_mon_tlast   ),
     .m_axis_req_mon_tuser   ( m_axis_egr_req_mon_tuser   ),
     .m_axis_req_mon_tready  ( m_axis_egr_req_mon_tready  ),
     .s_axis_cmp_mon_tvalid  ( s_axis_egr_cmp_mon_tvalid  ),
     .s_axis_cmp_mon_tdata   ( s_axis_egr_cmp_mon_tdata   ),
     .s_axis_cmp_mon_tkeep   ( s_axis_egr_cmp_mon_tkeep   ),
     .s_axis_cmp_mon_tlast   ( s_axis_egr_cmp_mon_tlast   ),
     .s_axis_cmp_mon_tuser   ( s_axis_egr_cmp_mon_tuser   ),
     .s_axis_cmp_mon_tready  ( s_axis_egr_cmp_mon_tready  ),
     .pa_count_reset         ( sr_pa_count_reset          ),
     .pa_count_enable        ( sr_pa_count_enable         ),
     .mem_rd_req_count       ( w_egr_mem_rd_req_count        ),
     .mem_wd_req_count       ( w_egr_mem_wd_req_count        ),
     .i_o_rd_req_count       ( w_egr_i_o_rd_req_count        ),
     .i_o_wd_req_count       ( w_egr_i_o_wd_req_count        ),
     .mem_fet_add_req_count  ( w_egr_mem_fet_add_req_count   ),
     .mem_uncnd_swp_req_count( w_egr_mem_uncnd_swp_req_count ),
     .mem_cmp_swp_req_count  ( w_egr_mem_cmp_swp_req_count   ),
     .lock_rd_req_count      ( w_egr_lock_rd_req_count       ),
     .type_0_cnf_rd_req_count( w_egr_type_0_cnf_rd_req_count ),
     .type_1_cnf_rd_req_count( w_egr_type_1_cnf_rd_req_count ),
     .type_0_cnf_wd_req_count( w_egr_type_0_cnf_wd_req_count ),
     .type_1_cnf_wd_req_count( w_egr_type_1_cnf_wd_req_count ),
     .any_message_count      ( w_egr_any_message_count       ),
     .v_d_message_count      ( w_egr_v_d_message_count       ),
     .ats_message_count      ( w_egr_ats_message_count       ),
     .req_reserved_count     ( w_egr_req_reserved_count      ), //open
     .req_cmp_count          ( w_egr_req_cmp_count           )
   );

endmodule
