/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ps/1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module lldma #(
  parameter        FPGA_INFO = 32'h0001012c,//FPGA INFO Ver/Rev
  parameter        TCQ = 1,
  parameter [1:0]  AXISTEN_IF_WIDTH = 2'b11,
  parameter        AXISTEN_IF_RQ_ALIGNMENT_MODE    = 0,//DW alignment //modify "FALSE"->"0"
  parameter        AXISTEN_IF_CC_ALIGNMENT_MODE    = 0,//DW alignment //modify "FALSE"->"0"
  parameter        AXISTEN_IF_CQ_ALIGNMENT_MODE    = 0,
  parameter        AXISTEN_IF_RC_ALIGNMENT_MODE    = 0,
  parameter        AXI4_CQ_TUSER_WIDTH             = 183,
  parameter        AXI4_CC_TUSER_WIDTH             = 81,
  parameter        AXI4_RQ_TUSER_WIDTH             = 137,
  parameter        AXI4_RC_TUSER_WIDTH             = 161,
  parameter        AXISTEN_IF_ENABLE_CLIENT_TAG    = 0,
  parameter        AXISTEN_IF_RQ_PARITY_CHECK      = 0,
  parameter        AXISTEN_IF_CC_PARITY_CHECK      = 0,
  parameter        AXISTEN_IF_RC_PARITY_CHECK      = 0,
  parameter        AXISTEN_IF_CQ_PARITY_CHECK      = 0,
  parameter        AXISTEN_IF_RC_STRADDLE          = 0,
  parameter        AXISTEN_IF_ENABLE_RX_MSG_INTFC  = 0,
  parameter [17:0] AXISTEN_IF_ENABLE_MSG_ROUTE     = 18'h2FFFF,
  parameter        ENABLE_TX_STREAM_ENGINE = 1,
  parameter        ENABLE_RX_STREAM_ENGINE = 1,
  parameter CH_NUM_LOG = 5,
  parameter DESC_RQ_DW = 512,
  parameter DESC_RC_DW = 512,
  parameter DESC_RQ_DK = DESC_RQ_DW/32,
  parameter DESC_RC_DK = DESC_RC_DW/32,
  parameter DESC_RC_USER = 32,

  //Do not modify the parameters below this line
  parameter C_DATA_WIDTH = 512,
  parameter PARITY_WIDTH = C_DATA_WIDTH /8,
  parameter KEEP_WIDTH   = C_DATA_WIDTH /32,

  parameter CH_NUM       = 32,
  parameter CHAIN_NUM    = 4,
  parameter CH_PAR_CHAIN = CH_NUM / CHAIN_NUM,

  parameter ADDR_W             = 16, // Memory Depth based on the C_DATA_WIDTH. 6bit -> 16bit modify
  parameter integer DATA_WIDTH = 32, //! data bit width
  parameter integer STRB_WIDTH = (DATA_WIDTH+7)/8 //! Width of the STRB signal

  )(

  //----------------------------------------------
  // CLK,RST,LNK_UP
  //----------------------------------------------

  input  logic                     user_clk,
  input  logic                     reset_n,
  input  logic                     user_lnk_up,

  input  logic                     ext_clk,      // Chain control clock
  input  logic                     ext_reset_n,  // Chain control unit reset

  //----------------------------------------------
  // AXI4-Lite 
  //----------------------------------------------

  input  logic     [ADDR_W-1:0]    s_axi_araddr  , //! AXI4-Lite ARADDR 
  input  logic                     s_axi_arvalid , //! AXI4-Lite ARVALID
  output logic                     s_axi_arready , //! AXI4-Lite ARREADY
  output logic [DATA_WIDTH-1:0]    s_axi_rdata   , //! AXI4-Lite RDATA  
  output logic            [1:0]    s_axi_rresp   , //! AXI4-Lite RRESP  
  output logic                     s_axi_rvalid  , //! AXI4-Lite RVALID 
  input  logic                     s_axi_rready  , //! AXI4-Lite RREADY 
  input  logic     [ADDR_W-1:0]    s_axi_awaddr  , //! AXI4-Lite AWADDR 
  input  logic                     s_axi_awvalid , //! AXI4-Lite AWVALID
  output logic                     s_axi_awready , //! AXI4-Lite AWREADY
  input  logic [DATA_WIDTH-1:0]    s_axi_wdata   , //! AXI4-Lite WDATA  
  input  logic [STRB_WIDTH-1:0]    s_axi_wstrb   , //! AXI4-Lite WSTRB not used
  input  logic                     s_axi_wvalid  , //! AXI4-Lite WVALID 
  output logic                     s_axi_wready  , //! AXI4-Lite WREADY 
  output logic            [1:0]    s_axi_bresp   , //! AXI4-Lite BRESP  
  output logic                     s_axi_bvalid  , //! AXI4-Lite BVALID 
  input  logic                     s_axi_bready  , //! AXI4-Lite BREADY 

  //----------------------------------------------
  // AXI4 CIF_DN
  //----------------------------------------------

  output logic [CHAIN_NUM-1:0]        m_axi_cd_awvalid,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_awready,
  output logic [CHAIN_NUM-1:0][63:0]  m_axi_cd_awaddr,
  output logic [CHAIN_NUM-1:0][7:0]   m_axi_cd_awlen,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cd_awsize,
  output logic [CHAIN_NUM-1:0][1:0]   m_axi_cd_awburst,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_awlock,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cd_awcache,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cd_awprot,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cd_awqos,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cd_awregion,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_wvalid,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_wready,
  output logic [CHAIN_NUM-1:0][511:0] m_axi_cd_wdata,
  output logic [CHAIN_NUM-1:0][63:0]  m_axi_cd_wstrb,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_wlast,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_arvalid,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_arready,
  output logic [CHAIN_NUM-1:0][63:0]  m_axi_cd_araddr,
  output logic [CHAIN_NUM-1:0][7:0]   m_axi_cd_arlen,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cd_arsize,
  output logic [CHAIN_NUM-1:0][1:0]   m_axi_cd_arburst,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_arlock,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cd_arcache,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cd_arprot,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cd_arqos,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cd_arregion,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_rvalid,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_rready,
  input  logic [CHAIN_NUM-1:0][511:0] m_axi_cd_rdata,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_rlast,
  input  logic [CHAIN_NUM-1:0] [1:0]  m_axi_cd_rresp,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_bvalid,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_bready,
  input  logic [CHAIN_NUM-1:0] [1:0]  m_axi_cd_bresp,

  //----------------------------------------------
  // AXI-S CIF_DN
  //----------------------------------------------

  //input  logic [CHAIN_NUM-1:0]        s_axis_cd_transfer_cmd_valid,
  //input  logic [CHAIN_NUM-1:0][63:0]  s_axis_cd_transfer_cmd_data,
  //output logic [CHAIN_NUM-1:0]        s_axis_cd_transfer_cmd_ready,
  //output logic [CHAIN_NUM-1:0]        m_axis_cd_transfer_eve_valid,
  //output logic [CHAIN_NUM-1:0][127:0] m_axis_cd_transfer_eve_data,
  //input  logic [CHAIN_NUM-1:0]        m_axis_cd_transfer_eve_ready,

  //----------------------------------------------
  // AXI4 CIF_UP
  //----------------------------------------------

  output logic [CHAIN_NUM-1:0]        m_axi_cu_awvalid,
  input  logic [CHAIN_NUM-1:0]        m_axi_cu_awready,
  output logic [CHAIN_NUM-1:0][63:0]  m_axi_cu_awaddr,
  output logic [CHAIN_NUM-1:0][7:0]   m_axi_cu_awlen,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cu_awsize,
  output logic [CHAIN_NUM-1:0][1:0]   m_axi_cu_awburst,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_awlock,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cu_awcache,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cu_awprot,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cu_awqos,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cu_awregion,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_wvalid,
  input  logic [CHAIN_NUM-1:0]        m_axi_cu_wready,
  output logic [CHAIN_NUM-1:0][511:0] m_axi_cu_wdata,
  output logic [CHAIN_NUM-1:0][63:0]  m_axi_cu_wstrb,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_wlast,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_arvalid,
  input  logic [CHAIN_NUM-1:0]        m_axi_cu_arready,
  output logic [CHAIN_NUM-1:0][63:0]  m_axi_cu_araddr,
  output logic [CHAIN_NUM-1:0][7:0]   m_axi_cu_arlen,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cu_arsize,
  output logic [CHAIN_NUM-1:0][1:0]   m_axi_cu_arburst,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_arlock,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cu_arcache,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cu_arprot,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cu_arqos,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cu_arregion,
  input  logic [CHAIN_NUM-1:0]        m_axi_cu_rvalid,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_rready,
  input  logic [CHAIN_NUM-1:0][511:0] m_axi_cu_rdata,
  input  logic [CHAIN_NUM-1:0]        m_axi_cu_rlast,
  input  logic [CHAIN_NUM-1:0][1:0]   m_axi_cu_rresp,
  input  logic [CHAIN_NUM-1:0]        m_axi_cu_bvalid,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_bready,
  input  logic [CHAIN_NUM-1:0][1:0]   m_axi_cu_bresp,

  //----------------------------------------------
  // AXI-S CIF_UP
  //----------------------------------------------

  //input  logic [CHAIN_NUM-1:0]        s_axis_cu_transfer_cmd_valid,
  //input  logic [CHAIN_NUM-1:0][63:0]  s_axis_cu_transfer_cmd_data,
  //output logic [CHAIN_NUM-1:0]        s_axis_cu_transfer_cmd_ready,
  //output logic [CHAIN_NUM-1:0]        m_axis_cu_transfer_eve_valid,
  //output logic [CHAIN_NUM-1:0][127:0] m_axis_cu_transfer_eve_data,
  //input  logic [CHAIN_NUM-1:0]        m_axis_cu_transfer_eve_ready,

  //----------------------------------------------
  // AXI-S EVE CMD
  //----------------------------------------------

  input  logic [CHAIN_NUM-1:0]        s_axis_transfer_cmd_valid,
  input  logic [CHAIN_NUM-1:0][63:0]  s_axis_transfer_cmd_data,
  output logic [CHAIN_NUM-1:0]        s_axis_transfer_cmd_ready,
  output logic [CHAIN_NUM-1:0]        m_axis_transfer_eve_valid,
  output logic [CHAIN_NUM-1:0][127:0] m_axis_transfer_eve_data,
  input  logic [CHAIN_NUM-1:0]        m_axis_transfer_eve_ready,

  //----------------------------------------------
  // CMS IF
  //----------------------------------------------

  input  logic                     s_d2d_req_valid,
  input  logic                     s_d2d_ack_valid,
  input  logic [511:0]             s_d2d_data,
  output logic                     s_d2d_ready,

  //----------------------------------------------
  // AXI-S Requester Request Interface
  //----------------------------------------------

  output logic                           m_axis_rq_tvalid,
  output logic        [C_DATA_WIDTH-1:0] m_axis_rq_tdata,
  output logic          [KEEP_WIDTH-1:0] m_axis_rq_tkeep,
  output logic                           m_axis_rq_tlast,
  output logic [AXI4_RQ_TUSER_WIDTH-1:0] m_axis_rq_tuser,
  input  logic                           m_axis_rq_tready,

  //----------------------------------------------
  // AXI-S Requester Completion Interface
  //----------------------------------------------

  input  logic                           s_axis_rc_tvalid,
  input  logic        [C_DATA_WIDTH-1:0] s_axis_rc_tdata,
  input  logic          [KEEP_WIDTH-1:0] s_axis_rc_tkeep,
  input  logic                           s_axis_rc_tlast,
  input  logic [AXI4_RC_TUSER_WIDTH-1:0] s_axis_rc_tuser,
  output logic                           s_axis_rc_tready,

  //----------------------------------------------
  // AXI-S Completer Request Interface
  //----------------------------------------------

  input  logic                           s_axis_direct_tvalid,
  input  logic                  [511:0]  s_axis_direct_tdata,
  input  logic                   [15:0]  s_axis_direct_tuser,
  output logic                           s_axis_direct_tready,

  //----------------------------------------------
  // TX Message Interface
  //----------------------------------------------

  input  logic                     cfg_msg_transmit_done,
  output logic                     cfg_msg_transmit,
  output logic              [2:0]  cfg_msg_transmit_type,
  output logic             [31:0]  cfg_msg_transmit_data,

  //----------------------------------------------
  //Tag availability and Flow control Information
  //----------------------------------------------

  input  logic             [5:0]   pcie_rq_tag,
  input  logic                     pcie_rq_tag_vld,
  input  logic             [3:0]   pcie_tfc_nph_av,
  input  logic             [3:0]   pcie_tfc_npd_av,
  input  logic                     pcie_tfc_np_pl_empty,
  input  logic             [3:0]   pcie_rq_seq_num,
  input  logic                     pcie_rq_seq_num_vld,

  //----------------------------------------------
  //Cfg Max Payload, Max Read Req
  //----------------------------------------------

  input  logic             [1:0]   cfg_max_payload,
  input  logic             [2:0]   cfg_max_read_req,

  input  logic                     timer_pulse,

  //----------------------------------------------
  //Cfg Error
  //----------------------------------------------

  input  logic             [4:0]   cfg_local_error_out,
  input  logic                     cfg_local_error_valid,

  //----------------------------------------------
  //Cfg Flow Control Information
  //----------------------------------------------

  input  logic             [7:0]   cfg_fc_ph,
  input  logic             [7:0]   cfg_fc_nph,
  input  logic             [7:0]   cfg_fc_cplh,
  input  logic            [11:0]   cfg_fc_pd,
  input  logic            [11:0]   cfg_fc_npd,
  input  logic            [11:0]   cfg_fc_cpld,
  output logic             [2:0]   cfg_fc_sel,

  input  logic             [5:0]   pcie_cq_np_req_count,
  output logic                     pcie_cq_np_req,

  //----------------------------------------------
  // RX Message Interface
  //----------------------------------------------

  input  logic                     cfg_msg_received,
  input  logic             [4:0]   cfg_msg_received_type,
  input  logic             [7:0]   cfg_msg_received_data,

  //----------------------------------------------
  // PIO Interrupt Interface
  //----------------------------------------------

  output logic                     interrupt_done,  // Indicates whether interrupt is done or in process

  //----------------------------------------------
  // Legacy Interrupt Interface
  //----------------------------------------------

  input  logic                     cfg_interrupt_sent, // Core asserts this signal when it sends out a Legacy interrupt
  output logic             [3:0]   cfg_interrupt_int,  // 4 Bits for INTA, INTB, INTC, INTD (assert or deassert)

  //----------------------------------------------
  // MSI Interrupt Interface
  //----------------------------------------------

  input  logic                     cfg_interrupt_msi_enable,
  input  logic                     cfg_interrupt_msi_sent,
  input  logic                     cfg_interrupt_msi_fail,
  output logic            [31:0]   cfg_interrupt_msi_int,

  //----------------------------------------------
  //MSI-X Interrupt Interface
  //----------------------------------------------

  input  logic                     cfg_interrupt_msix_enable,
  input  logic                     cfg_interrupt_msix_sent,
  input  logic                     cfg_interrupt_msix_fail,
  output logic                     cfg_interrupt_msix_int,
  output logic            [63:0]   cfg_interrupt_msix_address,
  output logic            [31:0]   cfg_interrupt_msix_data,

  input  logic                     cfg_power_state_change_interrupt,
  output logic                     cfg_power_state_change_ack,

  //----------------------------------------------
  //Error detect
  //----------------------------------------------

  output logic                     error_detect_lldma
  );

// -------------------------------------------------
// Local wires
// -------------------------------------------------

  wire pio_reset_n = user_lnk_up && reset_n;

// -------------------------------------------------
// logic
// -------------------------------------------------

  //setting,pa,trace
  logic [  2:0]   cfg_max_read_req_dmar_rs;
  logic [  1:0]   cfg_max_payload_dmar_rs;

  logic [  2:0]   cfg_max_read_req_dmat_rs;
  logic [  1:0]   cfg_max_payload_dmat_rs;

  logic           dbg_enable_dmar_rs;
  logic           dbg_count_reset_dmar_rs;
  logic           dma_trace_enable_dmar_rs;
  logic           dma_trace_rst_dmar_rs;
  logic [ 31:0]   dbg_freerun_count_dmar_rs;

  logic           dbg_enable_dmat_rs;
  logic           dbg_count_reset_dmat_rs;
  logic           dma_trace_enable_dmat_rs;
  logic           dma_trace_rst_dmat_rs;
  logic [ 31:0]   dbg_freerun_count_dmat_rs;

  logic           dbg_enable_cifdn_rs;
  logic           dbg_count_reset_cifdn_rs;
  logic           dma_trace_enable_cifdn_rs;
  logic           dma_trace_rst_cifdn_rs;
  logic [ 31:0]   dbg_freerun_count_cifdn_rs;

  logic           dbg_enable_cifup_rs;
  logic           dbg_count_reset_cifup_rs;
  logic           dma_trace_enable_cifup_rs;
  logic           dma_trace_rst_cifup_rs;
  logic [ 31:0]   dbg_freerun_count_cifup_rs;

  logic           timer_pulse_rs;

  //Register Access Interface

  logic           regreq_axis_tvalid_cifup;
  logic           regreq_axis_tvalid_cifdn;
  logic           regreq_axis_tvalid_dmar;
  logic           regreq_axis_tvalid_dmat;
  logic [511:0]   regreq_axis_tdata;
  logic           regreq_axis_tlast;
  logic  [63:0]   regreq_axis_tuser;

  //Register Access Read Reply Interface

  logic           regrep_axis_tvalid_cifup;
  logic           regrep_axis_tvalid_cifdn;
  logic           regrep_axis_tvalid_dmar;
  logic           regrep_axis_tvalid_dmat;
  logic  [31:0]   regrep_axis_tdata_cifup;
  logic  [31:0]   regrep_axis_tdata_cifdn;
  logic  [31:0]   regrep_axis_tdata_dmar;
  logic  [31:0]   regrep_axis_tdata_dmat;

  //RQ Request Interface

  logic           rq_dmar_crd_axis_tvalid;
  logic [511:0]   rq_dmar_crd_axis_tdata;
  logic           rq_dmar_crd_axis_tlast;
  logic           rq_dmar_crd_axis_tready;

  logic           rq_dmar_cwr_axis_tvalid;
  logic [511:0]   rq_dmar_cwr_axis_tdata;
  logic           rq_dmar_cwr_axis_tlast;
  logic           rq_dmar_cwr_axis_tready;

  logic           rq_dmar_rd_axis_tvalid;
  logic [511:0]   rq_dmar_rd_axis_tdata;
  logic           rq_dmar_rd_axis_tlast;
  logic           rq_dmar_rd_axis_tready;

  logic           rq_dmar_rd_axis_tvalid_rs;
  logic [511:0]   rq_dmar_rd_axis_tdata_rs;
  logic           rq_dmar_rd_axis_tlast_rs;
  logic           rq_dmar_rd_axis_tready_rs;

  logic           rq_dmaw_dwr_axis_tvalid;
  logic [511:0]   rq_dmaw_dwr_axis_tdata;
  logic           rq_dmaw_dwr_axis_tlast;
  logic           rq_dmaw_dwr_axis_tready;
  logic           rq_dmaw_dwr_axis_wr_ptr;
  logic           rq_dmaw_dwr_axis_rd_ptr;

  logic           rq_dmaw_dwr_axis_tvalid_rs;
  logic [511:0]   rq_dmaw_dwr_axis_tdata_rs;
  logic           rq_dmaw_dwr_axis_tlast_rs;
  logic           rq_dmaw_dwr_axis_tready_rs;
  logic           rq_dmaw_dwr_axis_wr_ptr_rs;
  logic           rq_dmaw_dwr_axis_rd_ptr_rs;

  logic           rq_dmaw_cwr_axis_tvalid;
  logic [511:0]   rq_dmaw_cwr_axis_tdata;
  logic           rq_dmaw_cwr_axis_tlast;
  logic           rq_dmaw_cwr_axis_tready;

  logic           rq_dmaw_crd_axis_tvalid;
  logic [511:0]   rq_dmaw_crd_axis_tdata;
  logic           rq_dmaw_crd_axis_tlast;
  logic           rq_dmaw_crd_axis_tready;

  //RC Read Reply Interface

  logic           rc_axis_tvalid_dmar;
  logic           rc_axis_tvalid_dmat;
  logic [511:0]   rc_axis_tdata;
  logic           rc_axis_tlast;
  logic  [15:0]   rc_axis_tkeep;
  logic  [15:0]   rc_axis_tuser;
  logic  [11:0]   rc_axis_taddr_dmar;
  logic           rc_axis_tready_dmar;
  logic           rc_axis_tready_dmat;

  //MSI Int User Interface

  logic  [31:0]   cfg_interrupt_msi_int_user;

  // pci_trx <-> dma_rx/dma_tx

  logic           dbg_enable;
  logic           dbg_count_reset;
  logic           dma_trace_enable;
  logic           dma_trace_rst;
  logic  [31:0]   dbg_freerun_count;

  // cif_up <-> dma_tx

  logic                 c2d_axis_tvalid[CHAIN_NUM-1:0];
  logic [511:0]         c2d_axis_tdata[CHAIN_NUM-1:0];
  logic                 c2d_axis_tlast[CHAIN_NUM-1:0];
  logic  [15:0]         c2d_axis_tuser[CHAIN_NUM-1:0];
  logic                 c2d_axis_tready[CHAIN_NUM-1:0];
  logic   [1:0]         c2d_pkt_mode[CH_NUM-1:0];
  logic [CH_NUM-1:0]    c2d_txch_ie;
  logic [CH_NUM-1:0]    c2d_txch_clr;
  logic [CH_NUM-1:0]    c2d_cifu_busy;
  logic [CH_NUM-1:0]    c2d_cifu_rd_enb;
  logic [CH_NUM-1:0]    dma_tx_ch_connection_enable;

  // cif_dn <-> dma_rx

  logic                 d2c_axis_tvalid;
  logic [511:0]         d2c_axis_tdata;
  logic  [15:0]         d2c_axis_tuser;
  logic                 d2c_axis_tready;
  logic [CH_NUM-1:0]    d2c_rxch_oe;
  logic [CH_NUM-1:0]    d2c_rxch_clr;
  logic [CH_NUM-1:0]    d2c_cifd_busy;
  logic [CH_NUM-1:0]    d2c_dmar_rd_enb;
  logic   [1:0]         d2c_pkt_mode[CH_NUM-1:0];
  logic [CH_NUM-1:0]    d2c_que_wt_ack_mode2;
  logic [CH_NUM-1:0]    d2c_que_wt_req_mode2;
  logic  [31:0]         d2c_que_wt_req_ack_rp_mode2[CH_NUM-1:0];
  logic  [31:0]         d2c_ack_rp_mode2[CH_NUM-1:0];
  logic [CH_NUM-1:0]    dma_rx_ch_connection_enable;

  // other

  logic           req_completion;
  logic           completion_done;

  // Error detect

  logic           error_detect_dma_tx;
  logic           error_detect_dma_rx;
  logic           error_detect_cif_up;
  logic           error_detect_cif_dn;

  
  // stream engine signal
  wire [31:0]                          w_cifup_frame_info_size  [CHAIN_NUM-1:0] ;
  wire [$clog2(CH_NUM)-1:0]            w_cifup_frame_info_ch    [CHAIN_NUM-1:0] ;
  wire [CHAIN_NUM-1:0]                 w_cifup_frame_info_valid   ;
  wire [32*CHAIN_NUM-1:0]              w_sten_tx_frame_info_size  ;
  wire [$clog2(CH_NUM)*CHAIN_NUM-1:0]  w_sten_tx_frame_info_ch    ;
  wire [CHAIN_NUM-1:0]                 w_sten_tx_frame_info_valid ;
  wire [DESC_RQ_DW-1:0]   w_sten_tx_i_rd_data           ;
  wire                    w_sten_tx_i_rd_last           ;
  wire                    w_sten_tx_i_rd_valid          ;
  wire                    w_sten_tx_i_rd_ready          ;
  wire [DESC_RQ_DW-1:0]   w_sten_tx_i_wr_data           ;
  wire                    w_sten_tx_i_wr_last           ;
  wire                    w_sten_tx_i_wr_valid          ;
  wire                    w_sten_tx_i_wr_ready          ;
  wire [DESC_RC_DW-1:0]   w_sten_tx_i_rc_data           ;
  wire [DESC_RC_DK-1:0]   w_sten_tx_i_rc_keep           ;
  wire [DESC_RC_USER-1:0] w_sten_tx_i_rc_user           ;
  wire                    w_sten_tx_i_rc_last           ;
  wire                    w_sten_tx_i_rc_valid          ;
  wire                    w_sten_tx_i_rc_ready          ;
  wire [DESC_RC_DW-1:0]   w_sten_tx_o_rc_data           ;
  wire [DESC_RC_DK-1:0]   w_sten_tx_o_rc_keep           ;
  wire [15:0]             w_sten_tx_o_rc_user           ;
  wire                    w_sten_tx_o_rc_last           ;
  wire                    w_sten_tx_o_rc_valid          ;
  wire                    w_sten_tx_o_rc_ready          ;
  wire [DESC_RQ_DW-1:0]   w_sten_tx_o_rd_data           ;
  wire                    w_sten_tx_o_rd_last           ;
  wire                    w_sten_tx_o_rd_valid          ;
  wire                    w_sten_tx_o_rd_ready          ;
  wire [DESC_RQ_DW-1:0]   w_sten_tx_o_wr_data           ;
  wire                    w_sten_tx_o_wr_last           ;
  wire                    w_sten_tx_o_wr_valid          ;
  wire                    w_sten_tx_o_wr_ready          ;
  wire [31:0]             w_sten_tx_rc_icount           ;
  wire [31:0]             w_sten_tx_rc_count            ;
  wire [15:0]             w_sten_tx_rc_count_fixed_cycle;
  
  wire [DESC_RQ_DW-1:0]   w_sten_rx_i_rd_data           ;
  wire                    w_sten_rx_i_rd_last           ;
  wire                    w_sten_rx_i_rd_valid          ;
  wire                    w_sten_rx_i_rd_ready          ;
  wire [DESC_RQ_DW-1:0]   w_sten_rx_i_wr_data           ;
  wire                    w_sten_rx_i_wr_last           ;
  wire                    w_sten_rx_i_wr_valid          ;
  wire                    w_sten_rx_i_wr_ready          ;
  wire [DESC_RC_DW-1:0]   w_sten_rx_i_rc_data           ;
  wire [DESC_RC_DK-1:0]   w_sten_rx_i_rc_keep           ;
  wire [DESC_RC_USER-1:0] w_sten_rx_i_rc_user           ;
  wire                    w_sten_rx_i_rc_last           ;
  wire                    w_sten_rx_i_rc_valid          ;
  wire                    w_sten_rx_i_rc_ready          ;
  wire [DESC_RC_DW-1:0]   w_sten_rx_o_rc_data           ;
  wire [DESC_RC_DK-1:0]   w_sten_rx_o_rc_keep           ;
  wire [DESC_RC_USER-1:0] w_sten_rx_o_rc_user           ;
  wire                    w_sten_rx_o_rc_last           ;
  wire                    w_sten_rx_o_rc_valid          ;
  wire                    w_sten_rx_o_rc_ready          ;
  wire [DESC_RQ_DW-1:0]   w_sten_rx_o_rd_data           ;
  wire                    w_sten_rx_o_rd_last           ;
  wire                    w_sten_rx_o_rd_valid          ;
  wire                    w_sten_rx_o_rd_ready          ;
  wire [DESC_RQ_DW-1:0]   w_sten_rx_o_wr_data           ;
  wire                    w_sten_rx_o_wr_last           ;
  wire                    w_sten_rx_o_wr_valid          ;
  wire                    w_sten_rx_o_wr_ready          ;
  wire [31:0]             w_sten_rx_rc_icount           ;
  wire [31:0]             w_sten_rx_rc_count            ;
  wire [15:0]             w_sten_rx_rc_count_fixed_cycle;
  
  wire                      w_pci_trx_rq_dmar_crd_axis_tvalid;
  wire [511:0]              w_pci_trx_rq_dmar_crd_axis_tdata ;
  wire                      w_pci_trx_rq_dmar_crd_axis_tlast ;
  wire                      w_pci_trx_rq_dmar_crd_axis_tready;
  wire                      w_pci_trx_rq_dmar_cwr_axis_tvalid;
  wire [511:0]              w_pci_trx_rq_dmar_cwr_axis_tdata ;
  wire                      w_pci_trx_rq_dmar_cwr_axis_tlast ;
  wire                      w_pci_trx_rq_dmar_cwr_axis_tready;
  wire                      w_pci_trx_rq_dmaw_crd_axis_tvalid;
  wire [511:0]              w_pci_trx_rq_dmaw_crd_axis_tdata ;
  wire                      w_pci_trx_rq_dmaw_crd_axis_tlast ;
  wire                      w_pci_trx_rq_dmaw_crd_axis_tready;
  wire                      w_pci_trx_rq_dmaw_cwr_axis_tvalid;
  wire [511:0]              w_pci_trx_rq_dmaw_cwr_axis_tdata ;
  wire                      w_pci_trx_rq_dmaw_cwr_axis_tlast ;
  wire                      w_pci_trx_rq_dmaw_cwr_axis_tready;
  wire                      w_pci_trx_rc_axis_tvalid_dmar    ;
  wire                      w_pci_trx_rc_axis_tvalid_dmat    ;
  wire                      w_pci_trx_rc_axis_tready_dmar    ;
  wire                      w_pci_trx_rc_axis_tready_dmat    ;
  wire [511:0]              w_pci_trx_rc_axis_tdata          ;
  wire                      w_pci_trx_rc_axis_tlast          ;
  wire  [15:0]              w_pci_trx_rc_axis_tkeep          ;
  wire  [15:0]              w_pci_trx_rc_axis_tuser          ;
  wire  [11:0]              w_pci_trx_rc_axis_taddr_dmar     ;
  
  wire                      w_pci_trx_rc_axis_tvalid_dmar_rs    ;
  wire                      w_pci_trx_rc_axis_tvalid_dmat_rs    ;
  wire                      w_pci_trx_rc_axis_tready_dmar_rs    ;
  wire                      w_pci_trx_rc_axis_tready_dmat_rs    ;
  wire  [11:0]              w_pci_trx_rc_axis_taddr_dmar_rs     ;
  
  
  wire [511:0]              w_pci_trx_rc_axis_tdata_dmar          ;
  wire                      w_pci_trx_rc_axis_tlast_dmar          ;
  wire  [15:0]              w_pci_trx_rc_axis_tkeep_dmar          ;
  wire  [31:0]              w_pci_trx_rc_axis_tuser_dmar          ;
  wire [511:0]              w_pci_trx_rc_axis_tdata_dmat          ;
  wire                      w_pci_trx_rc_axis_tlast_dmat          ;
  wire  [15:0]              w_pci_trx_rc_axis_tkeep_dmat          ;
  wire  [31:0]              w_pci_trx_rc_axis_tuser_dmat          ;
  
  wire [511:0]              w_pci_trx_rc_axis_tdata_dmar_rs          ;
  wire                      w_pci_trx_rc_axis_tlast_dmar_rs          ;
  wire  [15:0]              w_pci_trx_rc_axis_tkeep_dmar_rs          ;
  wire  [31:0]              w_pci_trx_rc_axis_tuser_dmar_rs          ;
  wire [511:0]              w_pci_trx_rc_axis_tdata_dmat_rs          ;
  wire                      w_pci_trx_rc_axis_tlast_dmat_rs          ;
  wire  [15:0]              w_pci_trx_rc_axis_tkeep_dmat_rs          ;
  wire  [31:0]              w_pci_trx_rc_axis_tuser_dmat_rs          ;
  
  
  wire                      w_dma_tx_rq_dmaw_crd_axis_tvalid;
  wire [511:0]              w_dma_tx_rq_dmaw_crd_axis_tdata ;
  wire                      w_dma_tx_rq_dmaw_crd_axis_tlast ;
  wire                      w_dma_tx_rq_dmaw_crd_axis_tready;
  wire                      w_dma_tx_rq_dmaw_cwr_axis_tvalid;
  wire [511:0]              w_dma_tx_rq_dmaw_cwr_axis_tdata ;
  wire                      w_dma_tx_rq_dmaw_cwr_axis_tlast ;
  wire                      w_dma_tx_rq_dmaw_cwr_axis_tready;
  wire                      w_dma_tx_rc_axis_tvalid_dmat    ;
  wire                      w_dma_tx_rc_axis_tready_dmat    ;
  wire [511:0]              w_dma_tx_rc_axis_tdata          ;
  wire                      w_dma_tx_rc_axis_tlast          ;
  wire  [15:0]              w_dma_tx_rc_axis_tuser          ;
  
  wire                      w_dma_tx_rc_axis_tvalid_dmat_rs    ;
  wire                      w_dma_tx_rc_axis_tready_dmat_rs    ;
  
  wire                      w_dma_rx_rq_dmar_crd_axis_tvalid;
  wire [511:0]              w_dma_rx_rq_dmar_crd_axis_tdata ;
  wire                      w_dma_rx_rq_dmar_crd_axis_tlast ;
  wire                      w_dma_rx_rq_dmar_crd_axis_tready;
  wire                      w_dma_rx_rq_dmar_cwr_axis_tvalid;
  wire [511:0]              w_dma_rx_rq_dmar_cwr_axis_tdata ;
  wire                      w_dma_rx_rq_dmar_cwr_axis_tlast ;
  wire                      w_dma_rx_rq_dmar_cwr_axis_tready;
  wire                      w_dma_rx_rc_axis_tvalid_dmar    ;
  wire                      w_dma_rx_rc_axis_tready_dmar    ;
  wire [511:0]              w_dma_rx_rc_axis_tdata          ;
  wire                      w_dma_rx_rc_axis_tlast          ;
  wire  [15:0]              w_dma_rx_rc_axis_tuser          ;
  wire  [11:0]              w_dma_rx_rc_axis_taddr_dmar     ;
  
  wire                      w_dma_rx_rc_axis_tvalid_dmar_rs    ;
  wire                      w_dma_rx_rc_axis_tready_dmar_rs    ;

  wire                      w_dma_tx_rq_dmaw_crd_axis_tvalid_rs;
  wire [511:0]              w_dma_tx_rq_dmaw_crd_axis_tdata_rs ;
  wire                      w_dma_tx_rq_dmaw_crd_axis_tlast_rs ;
  wire                      w_dma_tx_rq_dmaw_crd_axis_tready_rs;
  wire                      w_dma_tx_rq_dmaw_cwr_axis_tvalid_rs;
  wire [511:0]              w_dma_tx_rq_dmaw_cwr_axis_tdata_rs ;
  wire                      w_dma_tx_rq_dmaw_cwr_axis_tlast_rs ;
  wire                      w_dma_tx_rq_dmaw_cwr_axis_tready_rs;
  wire                      w_sten_tx_o_rc_valid_rs            ;
  wire [511:0]              w_sten_tx_o_rc_data_rs             ;
  wire                      w_sten_tx_o_rc_last_rs             ;
  wire  [15:0]              w_sten_tx_o_rc_user_rs             ;
  wire                      w_sten_tx_o_rc_ready_rs            ;
  
  wire                      w_dma_rx_rq_dmar_crd_axis_tvalid_rs;
  wire [511:0]              w_dma_rx_rq_dmar_crd_axis_tdata_rs ;
  wire                      w_dma_rx_rq_dmar_crd_axis_tlast_rs ;
  wire                      w_dma_rx_rq_dmar_crd_axis_tready_rs;
  wire                      w_dma_rx_rq_dmar_cwr_axis_tvalid_rs;
  wire [511:0]              w_dma_rx_rq_dmar_cwr_axis_tdata_rs ;
  wire                      w_dma_rx_rq_dmar_cwr_axis_tlast_rs ;
  wire                      w_dma_rx_rq_dmar_cwr_axis_tready_rs;
  wire                      w_sten_rx_o_rc_valid_rs            ;
  wire [511:0]              w_sten_rx_o_rc_data_rs             ;
  wire                      w_sten_rx_o_rc_last_rs             ;
  wire [DESC_RC_USER-1:0]   w_sten_rx_o_rc_user_rs             ;
  wire                      w_sten_rx_o_rc_ready_rs            ;
  
  
  wire [CHAIN_NUM-1:0]       w_s_axis_cd_transfer_eve_tvalid;
  wire [CHAIN_NUM-1:0][127:0]w_s_axis_cd_transfer_eve_tdata;
  wire [CHAIN_NUM-1:0]       w_s_axis_cd_transfer_eve_tready;
  wire [CHAIN_NUM-1:0]       w_s_axis_cu_transfer_eve_tvalid;
  wire [CHAIN_NUM-1:0][127:0]w_s_axis_cu_transfer_eve_tdata;
  wire [CHAIN_NUM-1:0]       w_s_axis_cu_transfer_eve_tready;
  wire [CHAIN_NUM-1:0]       w_m_axis_cd_transfer_cmd_tvalid;
  wire [CHAIN_NUM-1:0][ 63:0]w_m_axis_cd_transfer_cmd_tdata;
  wire [CHAIN_NUM-1:0]       w_m_axis_cd_transfer_cmd_tready;
  wire [CHAIN_NUM-1:0]       w_m_axis_cu_transfer_cmd_tvalid;
  wire [CHAIN_NUM-1:0][ 63:0]w_m_axis_cu_transfer_cmd_tdata;
  wire [CHAIN_NUM-1:0]       w_m_axis_cu_transfer_cmd_tready;
  
  wire [CHAIN_NUM-1:0]        m_axis_transfer_eve_valid_rs;
  wire [CHAIN_NUM-1:0][127:0] m_axis_transfer_eve_data_rs;
  wire [CHAIN_NUM-1:0]        m_axis_transfer_eve_ready_rs;
  wire [CHAIN_NUM-1:0]        s_axis_transfer_cmd_valid_rs;
  wire [CHAIN_NUM-1:0][ 63:0] s_axis_transfer_cmd_data_rs;
  wire [CHAIN_NUM-1:0]        s_axis_transfer_cmd_ready_rs;
  
// ----------------------------------------------------------------
//  Register Slice
// ----------------------------------------------------------------

// PCI_TRX
  logic         regreq_axis_tvalid_cifdn_rs;
  logic [511:0] regreq_axis_tdata_cifdn_rs;
  logic         regreq_axis_tlast_cifdn_rs;
  logic [ 63:0] regreq_axis_tuser_cifdn_rs;

  logic         regreq_axis_tvalid_cifup_rs;
  logic [511:0] regreq_axis_tdata_cifup_rs;
  logic         regreq_axis_tlast_cifup_rs;
  logic [ 63:0] regreq_axis_tuser_cifup_rs;

  logic         regreq_axis_tvalid_dmar_rs;
  logic [511:0] regreq_axis_tdata_dmar_rs;
  logic         regreq_axis_tlast_dmar_rs;
  logic [ 63:0] regreq_axis_tuser_dmar_rs;

  logic         regreq_axis_tvalid_dmat_rs;
  logic [511:0] regreq_axis_tdata_dmat_rs;
  logic         regreq_axis_tlast_dmat_rs;
  logic [ 63:0] regreq_axis_tuser_dmat_rs;

// CIF_DN
  logic         s_axis_direct_tvalid_rs;
  logic [511:0] s_axis_direct_tdata_rs;
  logic [15:0]  s_axis_direct_tuser_rs;
  logic         s_axis_direct_tready_rs;

  logic [CHAIN_NUM-1:0]        s_axis_cd_transfer_cmd_valid_rs;
  logic [CHAIN_NUM-1:0][ 63:0] s_axis_cd_transfer_cmd_data_rs;
  logic [CHAIN_NUM-1:0]        s_axis_cd_transfer_cmd_ready_rs;

  logic [CHAIN_NUM-1:0]        m_axis_cd_transfer_eve_valid_rs;
  logic [CHAIN_NUM-1:0][127:0] m_axis_cd_transfer_eve_data_rs;
  logic [CHAIN_NUM-1:0]        m_axis_cd_transfer_eve_ready_rs;

  logic [CHAIN_NUM-1:0]        m_axi_cd_awvalid_rs;
  logic [CHAIN_NUM-1:0][ 63:0] m_axi_cd_awaddr_rs;
  logic [CHAIN_NUM-1:0][  7:0] m_axi_cd_awlen_rs;
  logic [CHAIN_NUM-1:0]        m_axi_cd_awready_rs;

  logic [CHAIN_NUM-1:0]        m_axi_cd_wvalid_rs;
  logic [CHAIN_NUM-1:0][511:0] m_axi_cd_wdata_rs;
  logic [CHAIN_NUM-1:0]        m_axi_cd_wlast_rs;
  logic [CHAIN_NUM-1:0]        m_axi_cd_wready_rs;

  logic [CHAIN_NUM-1:0]        m_axi_cd_bvalid_rs;
  logic [CHAIN_NUM-1:0][  1:0] m_axi_cd_bresp_rs;
  logic [CHAIN_NUM-1:0]        m_axi_cd_bready_rs;

// CIF_UP
  logic [CHAIN_NUM-1:0]        s_axis_cu_transfer_cmd_valid_rs;
  logic [CHAIN_NUM-1:0][ 63:0] s_axis_cu_transfer_cmd_data_rs;
  logic [CHAIN_NUM-1:0]        s_axis_cu_transfer_cmd_ready_rs;

  logic [CHAIN_NUM-1:0]        m_axis_cu_transfer_eve_valid_rs;
  logic [CHAIN_NUM-1:0][127:0] m_axis_cu_transfer_eve_data_rs;
  logic [CHAIN_NUM-1:0]        m_axis_cu_transfer_eve_ready_rs;

  logic [CHAIN_NUM-1:0]        m_axi_cu_arvalid_rs;
  logic [CHAIN_NUM-1:0][ 63:0] m_axi_cu_araddr_rs;
  logic [CHAIN_NUM-1:0][  7:0] m_axi_cu_arlen_rs;
  logic [CHAIN_NUM-1:0]        m_axi_cu_arready_rs;

  logic [CHAIN_NUM-1:0]        m_axi_cu_rvalid_rs;
  logic [CHAIN_NUM-1:0][511:0] m_axi_cu_rdata_rs;
  logic [CHAIN_NUM-1:0]        m_axi_cu_rlast_rs;
  logic [CHAIN_NUM-1:0][  1:0] m_axi_cu_rresp_rs;
  logic [CHAIN_NUM-1:0]        m_axi_cu_rready_rs;
  

// ----------------------------------------------------------------
//  Bypass
// ----------------------------------------------------------------
  assign w_pci_trx_rc_axis_tdata_dmat = w_pci_trx_rc_axis_tdata;
  assign w_pci_trx_rc_axis_tlast_dmat = w_pci_trx_rc_axis_tlast;
  assign w_pci_trx_rc_axis_tkeep_dmat = w_pci_trx_rc_axis_tkeep;
  assign w_pci_trx_rc_axis_tuser_dmat = {16'h0000, w_pci_trx_rc_axis_tuser};
  assign w_pci_trx_rc_axis_tdata_dmar = w_pci_trx_rc_axis_tdata;
  assign w_pci_trx_rc_axis_tlast_dmar = w_pci_trx_rc_axis_tlast;
  assign w_pci_trx_rc_axis_tkeep_dmar = w_pci_trx_rc_axis_tkeep;
  assign w_pci_trx_rc_axis_tuser_dmar = {4'h0, w_pci_trx_rc_axis_taddr_dmar, w_pci_trx_rc_axis_tuser};
  

  assign w_pci_trx_rq_dmaw_crd_axis_tdata     = w_dma_tx_rq_dmaw_crd_axis_tdata_rs;
  assign w_pci_trx_rq_dmaw_crd_axis_tlast     = w_dma_tx_rq_dmaw_crd_axis_tlast_rs;
  assign w_pci_trx_rq_dmaw_crd_axis_tvalid    = w_dma_tx_rq_dmaw_crd_axis_tvalid_rs;
  assign w_dma_tx_rq_dmaw_crd_axis_tready_rs  = w_pci_trx_rq_dmaw_crd_axis_tready;
  assign w_pci_trx_rq_dmaw_cwr_axis_tdata     = w_dma_tx_rq_dmaw_cwr_axis_tdata_rs;
  assign w_pci_trx_rq_dmaw_cwr_axis_tlast     = w_dma_tx_rq_dmaw_cwr_axis_tlast_rs;
  assign w_pci_trx_rq_dmaw_cwr_axis_tvalid    = w_dma_tx_rq_dmaw_cwr_axis_tvalid_rs;
  assign w_dma_tx_rq_dmaw_cwr_axis_tready_rs  = w_pci_trx_rq_dmaw_cwr_axis_tready;
  assign w_dma_tx_rc_axis_tdata               = w_pci_trx_rc_axis_tdata_dmat_rs;
  //assign                                    = w_pci_trx_rc_axis_tkeep_dmat_rs;
  assign w_dma_tx_rc_axis_tuser               = w_pci_trx_rc_axis_tuser_dmat_rs[15:0];
  assign w_dma_tx_rc_axis_tlast               = w_pci_trx_rc_axis_tlast_dmat_rs;
  assign w_dma_tx_rc_axis_tvalid_dmat         = w_pci_trx_rc_axis_tvalid_dmat_rs;
  assign w_pci_trx_rc_axis_tready_dmat_rs     = w_dma_tx_rc_axis_tready_dmat;

  assign w_pci_trx_rq_dmar_crd_axis_tdata     = w_dma_rx_rq_dmar_crd_axis_tdata_rs;
  assign w_pci_trx_rq_dmar_crd_axis_tlast     = w_dma_rx_rq_dmar_crd_axis_tlast_rs;
  assign w_pci_trx_rq_dmar_crd_axis_tvalid    = w_dma_rx_rq_dmar_crd_axis_tvalid_rs;
  assign w_dma_rx_rq_dmar_crd_axis_tready_rs  = w_pci_trx_rq_dmar_crd_axis_tready;
  assign w_pci_trx_rq_dmar_cwr_axis_tdata     = w_dma_rx_rq_dmar_cwr_axis_tdata_rs;
  assign w_pci_trx_rq_dmar_cwr_axis_tlast     = w_dma_rx_rq_dmar_cwr_axis_tlast_rs;
  assign w_pci_trx_rq_dmar_cwr_axis_tvalid    = w_dma_rx_rq_dmar_cwr_axis_tvalid_rs;
  assign w_dma_rx_rq_dmar_cwr_axis_tready_rs  = w_pci_trx_rq_dmar_cwr_axis_tready;
  assign w_dma_rx_rc_axis_tdata               = w_pci_trx_rc_axis_tdata_dmar_rs;
  //assign                                    = w_pci_trx_rc_axis_tkeep_dmar_rs;
  assign w_dma_rx_rc_axis_tuser               = w_pci_trx_rc_axis_tuser_dmar_rs[15:0];
  assign w_dma_rx_rc_axis_taddr_dmar          = w_pci_trx_rc_axis_tuser_dmar_rs[27:16];
  assign w_dma_rx_rc_axis_tlast               = w_pci_trx_rc_axis_tlast_dmar_rs;
  assign w_dma_rx_rc_axis_tvalid_dmar         = w_pci_trx_rc_axis_tvalid_dmar_rs;
  assign w_pci_trx_rc_axis_tready_dmar_rs     = w_dma_rx_rc_axis_tready_dmar;


// ----------------------------------------------------------------
//  PCI_TRX
// ----------------------------------------------------------------
  pci_trx #(
    .FPGA_INFO  ( FPGA_INFO )
  ) PCI_TRX (
    .user_clk ( user_clk ),
    .reset_n  ( reset_n  ),
    .pcie_rq_seq_num         (4'd0),
    .pcie_rq_seq_num_vld     (1'd0),
    .pcie_rq_tag             (6'd0),
    .pcie_rq_tag_vld         (1'd0),
    .rq_dmar_crd_axis_tvalid ( w_pci_trx_rq_dmar_crd_axis_tvalid ),
    .rq_dmar_crd_axis_tdata  ( w_pci_trx_rq_dmar_crd_axis_tdata  ),
    .rq_dmar_crd_axis_tlast  ( w_pci_trx_rq_dmar_crd_axis_tlast  ),
    .rq_dmar_crd_axis_tready ( w_pci_trx_rq_dmar_crd_axis_tready ),
    .rq_dmar_cwr_axis_tvalid ( w_pci_trx_rq_dmar_cwr_axis_tvalid ),
    .rq_dmar_cwr_axis_tdata  ( w_pci_trx_rq_dmar_cwr_axis_tdata  ),
    .rq_dmar_cwr_axis_tlast  ( w_pci_trx_rq_dmar_cwr_axis_tlast  ),
    .rq_dmar_cwr_axis_tready ( w_pci_trx_rq_dmar_cwr_axis_tready ),
    .rq_dmaw_crd_axis_tvalid ( w_pci_trx_rq_dmaw_crd_axis_tvalid ),
    .rq_dmaw_crd_axis_tdata  ( w_pci_trx_rq_dmaw_crd_axis_tdata  ),
    .rq_dmaw_crd_axis_tlast  ( w_pci_trx_rq_dmaw_crd_axis_tlast  ),
    .rq_dmaw_crd_axis_tready ( w_pci_trx_rq_dmaw_crd_axis_tready ),
    .rq_dmaw_cwr_axis_tvalid ( w_pci_trx_rq_dmaw_cwr_axis_tvalid ),
    .rq_dmaw_cwr_axis_tdata  ( w_pci_trx_rq_dmaw_cwr_axis_tdata  ),
    .rq_dmaw_cwr_axis_tlast  ( w_pci_trx_rq_dmaw_cwr_axis_tlast  ),
    .rq_dmaw_cwr_axis_tready ( w_pci_trx_rq_dmaw_cwr_axis_tready ),
    .rc_axis_tvalid_dmar     ( w_pci_trx_rc_axis_tvalid_dmar     ),
    .rc_axis_tvalid_dmat     ( w_pci_trx_rc_axis_tvalid_dmat     ),
    .rc_axis_tready_dmar     ( w_pci_trx_rc_axis_tready_dmar     ),
    .rc_axis_tready_dmat     ( w_pci_trx_rc_axis_tready_dmat     ),
    .rc_axis_tdata           ( w_pci_trx_rc_axis_tdata           ),
    .rc_axis_tlast           ( w_pci_trx_rc_axis_tlast           ),
    .rc_axis_tkeep           ( w_pci_trx_rc_axis_tkeep           ),
    .rc_axis_tuser           ( w_pci_trx_rc_axis_tuser           ),
    .rc_axis_taddr_dmar      ( w_pci_trx_rc_axis_taddr_dmar      ),
    .*
  );

// ----------------------------------------------------------------
//  CIF_DN
// ----------------------------------------------------------------

  cif_dn  #(
    .CH_NUM    (CH_NUM),
    .CHAIN_NUM (CHAIN_NUM)
  ) CIF_DN (
    .user_clk    ( user_clk    ),
    .reset_n     ( reset_n     ),
    .ext_clk     ( ext_clk     ),
    .ext_reset_n ( ext_reset_n ),
    .regreq_axis_tvalid_cifdn     ( regreq_axis_tvalid_cifdn_rs     ),
    .regreq_axis_tdata            ( regreq_axis_tdata_cifdn_rs      ),
    .regreq_axis_tlast            ( regreq_axis_tlast_cifdn_rs      ),
    .regreq_axis_tuser            ( regreq_axis_tuser_cifdn_rs      ),
    .dbg_enable                   ( dbg_enable_cifdn_rs             ),
    .dbg_count_reset              ( dbg_count_reset_cifdn_rs        ),
    .dma_trace_enable             ( dma_trace_enable_cifdn_rs       ),
    .dma_trace_rst                ( dma_trace_rst_cifdn_rs          ),
    .dbg_freerun_count            ( dbg_freerun_count_cifdn_rs      ),
    .s_axis_direct_tvalid         ( s_axis_direct_tvalid_rs         ),
    .s_axis_direct_tdata          ( s_axis_direct_tdata_rs          ),
    .s_axis_direct_tuser          ( s_axis_direct_tuser_rs          ),
    .s_axis_direct_tready         ( s_axis_direct_tready_rs         ),
    .s_axis_cd_transfer_cmd_valid ( w_m_axis_cd_transfer_cmd_tvalid ),
    .s_axis_cd_transfer_cmd_data  ( w_m_axis_cd_transfer_cmd_tdata  ),
    .s_axis_cd_transfer_cmd_ready ( w_m_axis_cd_transfer_cmd_tready ),
    .m_axis_cd_transfer_eve_valid ( w_s_axis_cd_transfer_eve_tvalid ),
    .m_axis_cd_transfer_eve_data  ( w_s_axis_cd_transfer_eve_tdata  ),
    .m_axis_cd_transfer_eve_ready ( w_s_axis_cd_transfer_eve_tready ),
    .m_axi_cd_awvalid             ( m_axi_cd_awvalid_rs             ),
    .m_axi_cd_awaddr              ( m_axi_cd_awaddr_rs              ),
    .m_axi_cd_awlen               ( m_axi_cd_awlen_rs               ),
    .m_axi_cd_awready             ( m_axi_cd_awready_rs             ),
    .m_axi_cd_wvalid              ( m_axi_cd_wvalid_rs              ),
    .m_axi_cd_wdata               ( m_axi_cd_wdata_rs               ),
    .m_axi_cd_wlast               ( m_axi_cd_wlast_rs               ),
    .m_axi_cd_wready              ( m_axi_cd_wready_rs              ),
    .m_axi_cd_bvalid              ( m_axi_cd_bvalid_rs              ),
    .m_axi_cd_bresp               ( m_axi_cd_bresp_rs               ),
    .m_axi_cd_bready              ( m_axi_cd_bready_rs              ),
    .*
  );

// ----------------------------------------------------------------
//  CIF_UP
// ----------------------------------------------------------------

  cif_up #(
    .CH_NUM    (CH_NUM),
    .CHAIN_NUM (CHAIN_NUM)
  ) CIF_UP (
    .user_clk    ( user_clk    ),
    .reset_n     ( reset_n     ),
    .ext_clk     ( ext_clk     ),
    .ext_reset_n ( ext_reset_n ),
    .regreq_axis_tvalid_cifup     ( regreq_axis_tvalid_cifup_rs     ),
    .regreq_axis_tdata            ( regreq_axis_tdata_cifup_rs      ),
    .regreq_axis_tlast            ( regreq_axis_tlast_cifup_rs      ),
    .regreq_axis_tuser            ( regreq_axis_tuser_cifup_rs      ),
    .dbg_enable                   ( dbg_enable_cifup_rs             ),
    .dbg_count_reset              ( dbg_count_reset_cifup_rs        ),
    .dma_trace_enable             ( dma_trace_enable_cifup_rs       ),
    .dma_trace_rst                ( dma_trace_rst_cifup_rs          ),
    .dbg_freerun_count            ( dbg_freerun_count_cifup_rs      ),
    .s_axis_cu_transfer_cmd_valid ( w_m_axis_cu_transfer_cmd_tvalid ),
    .s_axis_cu_transfer_cmd_data  ( w_m_axis_cu_transfer_cmd_tdata  ),
    .s_axis_cu_transfer_cmd_ready ( w_m_axis_cu_transfer_cmd_tready ),
    .m_axis_cu_transfer_eve_valid ( w_s_axis_cu_transfer_eve_tvalid ),
    .m_axis_cu_transfer_eve_data  ( w_s_axis_cu_transfer_eve_tdata  ),
    .m_axis_cu_transfer_eve_ready ( w_s_axis_cu_transfer_eve_tready ),
    .m_axi_cu_arvalid             ( m_axi_cu_arvalid_rs             ),
    .m_axi_cu_araddr              ( m_axi_cu_araddr_rs              ),
    .m_axi_cu_arlen               ( m_axi_cu_arlen_rs               ),
    .m_axi_cu_arready             ( m_axi_cu_arready_rs             ),
    .m_axi_cu_rvalid              ( m_axi_cu_rvalid_rs              ),
    .m_axi_cu_rdata               ( m_axi_cu_rdata_rs               ),
    .m_axi_cu_rlast               ( m_axi_cu_rlast_rs               ),
    .m_axi_cu_rresp               ( m_axi_cu_rresp_rs               ),
    .m_axi_cu_rready              ( m_axi_cu_rready_rs              ),
    .frame_info_size              ( w_cifup_frame_info_size         ),
    .frame_info_ch                ( w_cifup_frame_info_ch           ),
    .frame_info_valid             ( w_cifup_frame_info_valid        ),
    .*
  );

// cmd/eve unified module
     eve_arbter_hub #(
        .CHAIN_NUM(CHAIN_NUM),
        .CH_NUM(CH_NUM)
       ) u_eve_arbter_hub(
         .user_clk                       ( user_clk        ), // input  wire,
         .reset_n                        ( reset_n         ), // input  wire
         .s_axis_cd_transfer_eve_tvalid  (w_s_axis_cd_transfer_eve_tvalid  ) , //input  wire [CHAIN_NUM-1:0]       
         .s_axis_cd_transfer_eve_tdata   (w_s_axis_cd_transfer_eve_tdata   ) , //input  wire [CHAIN_NUM-1:0][127:0]
         .s_axis_cd_transfer_eve_tready  (w_s_axis_cd_transfer_eve_tready  ) , //output wire [CHAIN_NUM-1:0]       
         .s_axis_cu_transfer_eve_tvalid  (w_s_axis_cu_transfer_eve_tvalid  ) , //input  wire [CHAIN_NUM-1:0]       
         .s_axis_cu_transfer_eve_tdata   (w_s_axis_cu_transfer_eve_tdata   ) , //input  wire [CHAIN_NUM-1:0][127:0]
         .s_axis_cu_transfer_eve_tready  (w_s_axis_cu_transfer_eve_tready  ) , //output wire [CHAIN_NUM-1:0]       
         .m_axis_transfer_eve_tvalid     (m_axis_transfer_eve_valid_rs     ) , //output wire [CHAIN_NUM-1:0]       
         .m_axis_transfer_eve_tdata      (m_axis_transfer_eve_data_rs      ) , //output wire [CHAIN_NUM-1:0][127:0]
         .m_axis_transfer_eve_tready     (m_axis_transfer_eve_ready_rs     ) , //input  wire [CHAIN_NUM-1:0]       
         .m_axis_cd_transfer_cmd_tvalid  (w_m_axis_cd_transfer_cmd_tvalid  ) , //output wire [CHAIN_NUM-1:0]       
         .m_axis_cd_transfer_cmd_tdata   (w_m_axis_cd_transfer_cmd_tdata   ) , //output wire [CHAIN_NUM-1:0][ 63:0]
         .m_axis_cd_transfer_cmd_tready  (w_m_axis_cd_transfer_cmd_tready  ) , //input  wire [CHAIN_NUM-1:0]       
         .m_axis_cu_transfer_cmd_tvalid  (w_m_axis_cu_transfer_cmd_tvalid  ) , //output wire [CHAIN_NUM-1:0]       
         .m_axis_cu_transfer_cmd_tdata   (w_m_axis_cu_transfer_cmd_tdata   ) , //output wire [CHAIN_NUM-1:0][ 63:0]
         .m_axis_cu_transfer_cmd_tready  (w_m_axis_cu_transfer_cmd_tready  ) , //input  wire [CHAIN_NUM-1:0]       
         .s_axis_transfer_cmd_tvalid     (s_axis_transfer_cmd_valid_rs     ) , //input  wire [CHAIN_NUM-1:0]       
         .s_axis_transfer_cmd_tdata      (s_axis_transfer_cmd_data_rs      ) , //input  wire [CHAIN_NUM-1:0][ 63:0]
         .s_axis_transfer_cmd_tready     (s_axis_transfer_cmd_ready_rs     ) , //output wire [CHAIN_NUM-1:0]       
         .*
     );
     
generate
    for (genvar i=0; i<CHAIN_NUM; i++) begin
        assign w_sten_tx_frame_info_size [i*32+:32]
                                          = w_cifup_frame_info_size [i][31:0];
        assign w_sten_tx_frame_info_ch   [i*($clog2(CH_NUM))+:$clog2(CH_NUM)]
                                          = w_cifup_frame_info_ch   [i][$clog2(CH_NUM)-1:0];
        //assign w_sten_tx_frame_info_valid[i] = w_cifup_frame_info_valid[i];
    end
        assign w_sten_tx_frame_info_valid[CHAIN_NUM-1:0] = w_cifup_frame_info_valid[CHAIN_NUM-1:0];
endgenerate

// ----------------------------------------------------------------
//  DMA_RX
// ----------------------------------------------------------------

  dma_rx #(
    .CH_NUM    (CH_NUM)
  ) DMA_RX (
    .user_clk ( user_clk ),
    .reset_n  ( reset_n  ),
    .regreq_axis_tvalid_dmar ( regreq_axis_tvalid_dmar_rs       ),
    .regreq_axis_tdata       ( regreq_axis_tdata_dmar_rs        ),
    .regreq_axis_tlast       ( regreq_axis_tlast_dmar_rs        ),
    .regreq_axis_tuser       ( regreq_axis_tuser_dmar_rs        ),
    .cfg_max_read_req        ( cfg_max_read_req_dmar_rs         ),
    .cfg_max_payload         ( cfg_max_payload_dmar_rs          ),
    .dbg_enable              ( dbg_enable_dmar_rs               ),
    .dbg_count_reset         ( dbg_count_reset_dmar_rs          ),
    .dma_trace_enable        ( dma_trace_enable_dmar_rs         ),
    .dma_trace_rst           ( dma_trace_rst_dmar_rs            ),
    .dbg_freerun_count       ( dbg_freerun_count_dmar_rs        ),
    .rq_dmar_rd_axis_tvalid  ( rq_dmar_rd_axis_tvalid_rs        ),
    .rq_dmar_rd_axis_tdata   ( rq_dmar_rd_axis_tdata_rs         ),
    .rq_dmar_rd_axis_tlast   ( rq_dmar_rd_axis_tlast_rs         ),
    .rq_dmar_rd_axis_tready  ( rq_dmar_rd_axis_tready_rs        ),
    .rq_dmar_crd_axis_tvalid ( w_dma_rx_rq_dmar_crd_axis_tvalid ),
    .rq_dmar_crd_axis_tdata  ( w_dma_rx_rq_dmar_crd_axis_tdata  ),
    .rq_dmar_crd_axis_tlast  ( w_dma_rx_rq_dmar_crd_axis_tlast  ),
    .rq_dmar_crd_axis_tready ( w_dma_rx_rq_dmar_crd_axis_tready ),
    .rq_dmar_cwr_axis_tvalid ( w_dma_rx_rq_dmar_cwr_axis_tvalid ),
    .rq_dmar_cwr_axis_tdata  ( w_dma_rx_rq_dmar_cwr_axis_tdata  ),
    .rq_dmar_cwr_axis_tlast  ( w_dma_rx_rq_dmar_cwr_axis_tlast  ),
    .rq_dmar_cwr_axis_tready ( w_dma_rx_rq_dmar_cwr_axis_tready ),
    .rc_axis_tvalid_dmar     ( w_dma_rx_rc_axis_tvalid_dmar     ),
    .rc_axis_tready_dmar     ( w_dma_rx_rc_axis_tready_dmar     ),
    .rc_axis_tdata           ( w_dma_rx_rc_axis_tdata           ),
    .rc_axis_tlast           ( w_dma_rx_rc_axis_tlast           ),
    //.rc_axis_tkeep         (           ),
    .rc_axis_tuser           ( w_dma_rx_rc_axis_tuser           ),
    .rc_axis_taddr_dmar      ( w_dma_rx_rc_axis_taddr_dmar      ),
    .*
  );

// ----------------------------------------------------------------
//  DMA_TX
// ----------------------------------------------------------------

  dma_tx #(
    .CH_NUM    (CH_NUM),
    .CHAIN_NUM (CHAIN_NUM)
  ) DMA_TX (
    .user_clk ( user_clk ),
    .reset_n  ( reset_n  ),
    .regreq_axis_tvalid_dmat ( regreq_axis_tvalid_dmat_rs       ),
    .regreq_axis_tdata       ( regreq_axis_tdata_dmat_rs        ),
    .regreq_axis_tlast       ( regreq_axis_tlast_dmat_rs        ),
    .regreq_axis_tuser       ( regreq_axis_tuser_dmat_rs        ),
    .cfg_max_read_req        ( cfg_max_read_req_dmar_rs         ),
    .cfg_max_payload         ( cfg_max_payload_dmar_rs          ),
    .dbg_enable              ( dbg_enable_dmat_rs               ),
    .dbg_count_reset         ( dbg_count_reset_dmat_rs          ),
    .dma_trace_enable        ( dma_trace_enable_dmat_rs         ),
    .dma_trace_rst           ( dma_trace_rst_dmat_rs            ),
    .dbg_freerun_count       ( dbg_freerun_count_dmat_rs        ),
    .timer_pulse             ( timer_pulse_rs                   ),
    .rq_dmaw_dwr_axis_tvalid ( rq_dmaw_dwr_axis_tvalid_rs       ),
    .rq_dmaw_dwr_axis_tdata  ( rq_dmaw_dwr_axis_tdata_rs        ),
    .rq_dmaw_dwr_axis_tlast  ( rq_dmaw_dwr_axis_tlast_rs        ),
    .rq_dmaw_dwr_axis_tready ( rq_dmaw_dwr_axis_tready_rs       ),
    .rq_dmaw_dwr_axis_wr_ptr ( rq_dmaw_dwr_axis_wr_ptr_rs       ),
    .rq_dmaw_dwr_axis_rd_ptr ( rq_dmaw_dwr_axis_rd_ptr_rs       ),
    .rq_dmaw_crd_axis_tvalid ( w_dma_tx_rq_dmaw_crd_axis_tvalid ),
    .rq_dmaw_crd_axis_tdata  ( w_dma_tx_rq_dmaw_crd_axis_tdata  ),
    .rq_dmaw_crd_axis_tlast  ( w_dma_tx_rq_dmaw_crd_axis_tlast  ),
    .rq_dmaw_crd_axis_tready ( w_dma_tx_rq_dmaw_crd_axis_tready ),
    .rq_dmaw_cwr_axis_tvalid ( w_dma_tx_rq_dmaw_cwr_axis_tvalid ),
    .rq_dmaw_cwr_axis_tdata  ( w_dma_tx_rq_dmaw_cwr_axis_tdata  ),
    .rq_dmaw_cwr_axis_tlast  ( w_dma_tx_rq_dmaw_cwr_axis_tlast  ),
    .rq_dmaw_cwr_axis_tready ( w_dma_tx_rq_dmaw_cwr_axis_tready ),
    .rc_axis_tvalid_dmat     ( w_dma_tx_rc_axis_tvalid_dmat     ),
    .rc_axis_tready_dmat     ( w_dma_tx_rc_axis_tready_dmat     ),
    .rc_axis_tdata           ( w_dma_tx_rc_axis_tdata           ),
    .rc_axis_tlast           ( w_dma_tx_rc_axis_tlast           ),
    //.rc_axis_tkeep         ( ),
    .rc_axis_tuser           ( w_dma_tx_rc_axis_tuser           ),
    .*
  );


// ----------------------------------------------------------------
//  Register Slice
// ----------------------------------------------------------------

  rs #(
    .CHAIN_NUM (CHAIN_NUM)
  ) RS (
    .user_clk    ( user_clk    ),
    .reset_n     ( reset_n     ),
    .ext_clk     ( ext_clk     ),
    .ext_reset_n ( ext_reset_n ),
    .*
  );


// ----------------------------------------------------------------
//  Turn-Off controller
// ----------------------------------------------------------------

  pio_to_ctrl pio_to  (
    .clk                                     ( user_clk ),
    .rst_n                                   ( pio_reset_n ),

    .req_compl                               ( req_completion ),
    .compl_done                              ( completion_done ),

    .cfg_power_state_change_interrupt        ( cfg_power_state_change_interrupt ),
    .cfg_power_state_change_ack              ( cfg_power_state_change_ack )
  );

endmodule
