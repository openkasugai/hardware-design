/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module pci_mon_wire #(
  parameter AXI4_CQ_TUSER_WIDTH            = 183,
  parameter AXI4_CC_TUSER_WIDTH            = 81,
  parameter AXI4_RQ_TUSER_WIDTH            = 137,
  parameter AXI4_RC_TUSER_WIDTH            = 161,
  parameter C_DATA_WIDTH           = 512,
  parameter KEEP_WIDTH             = C_DATA_WIDTH /32
)(

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME user_clk, ASSOCIATED_BUSIF s_axis_cq_pci:m_axis_cc_pci:m_axis_rq_pci:s_axis_rc_pci:m_axis_cq_user:s_axis_cc_user:s_axis_rq_user:m_axis_rc_user:m_axis_cq_mon:m_axis_cc_mon:m_axis_rq_mon:m_axis_rc_mon, ASSOCIATED_RESET reset_n, FREQ_TOLERANCE_HZ 0, PHASE 0.000, CLK_DOMAIN design_1_pcie4_uscale_plus_0_0_user_clk, INSERT_VIP 0" *)
  input  wire                           user_clk,
  input  wire                           reset_n,
  
  //PCI
  input  wire                           s_axis_cq_pci_tvalid,
  input  wire        [C_DATA_WIDTH-1:0] s_axis_cq_pci_tdata,
  input  wire          [KEEP_WIDTH-1:0] s_axis_cq_pci_tkeep,
  input  wire                           s_axis_cq_pci_tlast,
  input  wire [AXI4_CQ_TUSER_WIDTH-1:0] s_axis_cq_pci_tuser,
  output wire                           s_axis_cq_pci_tready,

  output wire                           m_axis_cc_pci_tvalid,
  output wire        [C_DATA_WIDTH-1:0] m_axis_cc_pci_tdata,
  output wire          [KEEP_WIDTH-1:0] m_axis_cc_pci_tkeep,
  output wire                           m_axis_cc_pci_tlast,
  output wire [AXI4_CC_TUSER_WIDTH-1:0] m_axis_cc_pci_tuser,
  input  wire                           m_axis_cc_pci_tready,

  output wire                           m_axis_rq_pci_tvalid,
  output wire        [C_DATA_WIDTH-1:0] m_axis_rq_pci_tdata,
  output wire          [KEEP_WIDTH-1:0] m_axis_rq_pci_tkeep,
  output wire                           m_axis_rq_pci_tlast,
  output wire [AXI4_RQ_TUSER_WIDTH-1:0] m_axis_rq_pci_tuser,
  input  wire                           m_axis_rq_pci_tready,
  
  input  wire                           s_axis_rc_pci_tvalid,
  input  wire        [C_DATA_WIDTH-1:0] s_axis_rc_pci_tdata,
  input  wire          [KEEP_WIDTH-1:0] s_axis_rc_pci_tkeep,
  input  wire                           s_axis_rc_pci_tlast,
  input  wire [AXI4_RC_TUSER_WIDTH-1:0] s_axis_rc_pci_tuser,
  output wire                           s_axis_rc_pci_tready,
  
  //USER
  output wire                           m_axis_cq_user_tvalid,
  output wire        [C_DATA_WIDTH-1:0] m_axis_cq_user_tdata,
  output wire          [KEEP_WIDTH-1:0] m_axis_cq_user_tkeep,
  output wire                           m_axis_cq_user_tlast,
  output wire [AXI4_CQ_TUSER_WIDTH-1:0] m_axis_cq_user_tuser,
  input  wire                           m_axis_cq_user_tready,

  input  wire                           s_axis_cc_user_tvalid,
  input  wire        [C_DATA_WIDTH-1:0] s_axis_cc_user_tdata,
  input  wire          [KEEP_WIDTH-1:0] s_axis_cc_user_tkeep,
  input  wire                           s_axis_cc_user_tlast,
  input  wire [AXI4_CC_TUSER_WIDTH-1:0] s_axis_cc_user_tuser,
  output wire                           s_axis_cc_user_tready,

  input  wire                           s_axis_rq_user_tvalid,
  input  wire        [C_DATA_WIDTH-1:0] s_axis_rq_user_tdata,
  input  wire          [KEEP_WIDTH-1:0] s_axis_rq_user_tkeep,
  input  wire                           s_axis_rq_user_tlast,
  input  wire [AXI4_RQ_TUSER_WIDTH-1:0] s_axis_rq_user_tuser,
  output wire                           s_axis_rq_user_tready,
  
  output wire                           m_axis_rc_user_tvalid,
  output wire        [C_DATA_WIDTH-1:0] m_axis_rc_user_tdata,
  output wire          [KEEP_WIDTH-1:0] m_axis_rc_user_tkeep,
  output wire                           m_axis_rc_user_tlast,
  output wire [AXI4_RC_TUSER_WIDTH-1:0] m_axis_rc_user_tuser,
  input  wire                           m_axis_rc_user_tready,  
  
  //MON
  output wire                           m_axis_cq_mon_tvalid,
  output wire        [C_DATA_WIDTH-1:0] m_axis_cq_mon_tdata,
  output wire          [KEEP_WIDTH-1:0] m_axis_cq_mon_tkeep,
  output wire                           m_axis_cq_mon_tlast,
  output wire [AXI4_CQ_TUSER_WIDTH-1:0] m_axis_cq_mon_tuser,
  output wire                           m_axis_cq_mon_tready,

  output wire                           m_axis_cc_mon_tvalid,
  output wire        [C_DATA_WIDTH-1:0] m_axis_cc_mon_tdata,
  output wire          [KEEP_WIDTH-1:0] m_axis_cc_mon_tkeep,
  output wire                           m_axis_cc_mon_tlast,
  output wire [AXI4_CC_TUSER_WIDTH-1:0] m_axis_cc_mon_tuser,
  output wire                           m_axis_cc_mon_tready,

  output wire                           m_axis_rq_mon_tvalid,
  output wire        [C_DATA_WIDTH-1:0] m_axis_rq_mon_tdata,
  output wire          [KEEP_WIDTH-1:0] m_axis_rq_mon_tkeep,
  output wire                           m_axis_rq_mon_tlast,
  output wire [AXI4_RQ_TUSER_WIDTH-1:0] m_axis_rq_mon_tuser,
  output wire                           m_axis_rq_mon_tready,
  
  output wire                           m_axis_rc_mon_tvalid,
  output wire        [C_DATA_WIDTH-1:0] m_axis_rc_mon_tdata,
  output wire          [KEEP_WIDTH-1:0] m_axis_rc_mon_tkeep,
  output wire                           m_axis_rc_mon_tlast,
  output wire [AXI4_RC_TUSER_WIDTH-1:0] m_axis_rc_mon_tuser,
  output wire                           m_axis_rc_mon_tready

);


  assign m_axis_cq_user_tvalid = s_axis_cq_pci_tvalid;
  assign m_axis_cq_user_tdata  = s_axis_cq_pci_tdata;
  assign m_axis_cq_user_tkeep  = s_axis_cq_pci_tkeep;
  assign m_axis_cq_user_tlast  = s_axis_cq_pci_tlast;
  assign m_axis_cq_user_tuser  = s_axis_cq_pci_tuser;
  assign s_axis_cq_pci_tready  = m_axis_cq_user_tready;

  assign m_axis_cc_pci_tvalid  = s_axis_cc_user_tvalid;
  assign m_axis_cc_pci_tdata   = s_axis_cc_user_tdata;
  assign m_axis_cc_pci_tkeep   = s_axis_cc_user_tkeep;
  assign m_axis_cc_pci_tlast   = s_axis_cc_user_tlast;
  assign m_axis_cc_pci_tuser   = s_axis_cc_user_tuser;
  assign s_axis_cc_user_tready = m_axis_cc_pci_tready;

  assign m_axis_rq_pci_tvalid  = s_axis_rq_user_tvalid;
  assign m_axis_rq_pci_tdata   = s_axis_rq_user_tdata;
  assign m_axis_rq_pci_tkeep   = s_axis_rq_user_tkeep;
  assign m_axis_rq_pci_tlast   = s_axis_rq_user_tlast;
  assign m_axis_rq_pci_tuser   = s_axis_rq_user_tuser;
  assign s_axis_rq_user_tready = m_axis_rq_pci_tready;
  
  assign m_axis_rc_user_tvalid = s_axis_rc_pci_tvalid;
  assign m_axis_rc_user_tdata  = s_axis_rc_pci_tdata;
  assign m_axis_rc_user_tkeep  = s_axis_rc_pci_tkeep;
  assign m_axis_rc_user_tlast  = s_axis_rc_pci_tlast;
  assign m_axis_rc_user_tuser  = s_axis_rc_pci_tuser;
  assign s_axis_rc_pci_tready  = m_axis_rc_user_tready;
  
  assign m_axis_cq_mon_tvalid = s_axis_cq_pci_tvalid;
  assign m_axis_cq_mon_tdata  = s_axis_cq_pci_tdata;
  assign m_axis_cq_mon_tkeep  = s_axis_cq_pci_tkeep;
  assign m_axis_cq_mon_tlast  = s_axis_cq_pci_tlast;
  assign m_axis_cq_mon_tuser  = s_axis_cq_pci_tuser;
  assign m_axis_cq_mon_tready = m_axis_cq_user_tready;

  assign m_axis_cc_mon_tvalid = s_axis_cc_user_tvalid;
  assign m_axis_cc_mon_tdata  = s_axis_cc_user_tdata;
  assign m_axis_cc_mon_tkeep  = s_axis_cc_user_tkeep;
  assign m_axis_cc_mon_tlast  = s_axis_cc_user_tlast;
  assign m_axis_cc_mon_tuser  = s_axis_cc_user_tuser;
  assign m_axis_cc_mon_tready = m_axis_cc_pci_tready;

  assign m_axis_rq_mon_tvalid = s_axis_rq_user_tvalid;
  assign m_axis_rq_mon_tdata  = s_axis_rq_user_tdata;
  assign m_axis_rq_mon_tkeep  = s_axis_rq_user_tkeep;
  assign m_axis_rq_mon_tlast  = s_axis_rq_user_tlast;
  assign m_axis_rq_mon_tuser  = s_axis_rq_user_tuser;
  assign m_axis_rq_mon_tready = m_axis_rq_pci_tready;
  
  assign m_axis_rc_mon_tvalid = s_axis_rc_pci_tvalid;
  assign m_axis_rc_mon_tdata  = s_axis_rc_pci_tdata;
  assign m_axis_rc_mon_tkeep  = s_axis_rc_pci_tkeep;
  assign m_axis_rc_mon_tlast  = s_axis_rc_pci_tlast;
  assign m_axis_rc_mon_tuser  = s_axis_rc_pci_tuser;
  assign m_axis_rc_mon_tready = m_axis_rc_user_tready;
    
endmodule
