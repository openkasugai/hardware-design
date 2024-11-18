/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ps / 1ps

`define PCI_EXP_EP_OUI                           24'h000A35
`define PCI_EXP_EP_DSN_1                         {{8'h1},`PCI_EXP_EP_OUI}
`define PCI_EXP_EP_DSN_2                         32'h00000001

(* DowngradeIPIdentifiedWarnings = "yes" *)
module  lldma_wrapper #(
  parameter         FPGA_INFO    = 32'h00060111,   //FPGA INFO Ver/Rev
  parameter         C_DATA_WIDTH = 512,            // RX/TX interface data width
  parameter         CH_NUM       = 16,
  parameter         CHAIN_NUM    = 2,

  // Do not override parameters below this line
  parameter         KEEP_WIDTH                     = C_DATA_WIDTH / 32,
  parameter         TCQ                            = 1,
  parameter [1:0]   AXISTEN_IF_WIDTH               = (C_DATA_WIDTH == 512) ? 2'b11:(C_DATA_WIDTH == 256) ? 2'b10 : (C_DATA_WIDTH == 128) ? 2'b01 : 2'b00,
  parameter         AXISTEN_IF_RQ_ALIGNMENT_MODE   = "FALSE",
  parameter         AXISTEN_IF_RC_ALIGNMENT_MODE   = "FALSE",
  parameter         AXISTEN_IF_CC_ALIGNMENT_MODE   = "FALSE",
  parameter         AXISTEN_IF_CQ_ALIGNMENT_MODE   = "FALSE",
  parameter         AXI4_CQ_TUSER_WIDTH            = 183,
  parameter         AXI4_CC_TUSER_WIDTH            = 81,
  parameter         AXI4_RQ_TUSER_WIDTH            = 137,
  parameter         AXI4_RC_TUSER_WIDTH            = 161,
  parameter         AXISTEN_IF_ENABLE_CLIENT_TAG   = 0,
  parameter         AXISTEN_IF_RQ_PARITY_CHECK     = 0,
  parameter         AXISTEN_IF_CC_PARITY_CHECK     = 0,
  parameter         AXISTEN_IF_RC_PARITY_CHECK     = 0,
  parameter         AXISTEN_IF_CQ_PARITY_CHECK     = 0,
  parameter         AXISTEN_IF_MC_RX_STRADDLE      = 1,
  parameter         AXISTEN_IF_ENABLE_RX_MSG_INTFC = 0,
  parameter [17:0]  AXISTEN_IF_ENABLE_MSG_ROUTE    = 18'h2FFFF,
  parameter         ADDR_W       = 16, // Memory Depth based on the C_DATA_WIDTH. 6bit -> 16bit modify
  parameter integer DATA_WIDTH   = 32, //! data bit width
  parameter integer STRB_WIDTH   = (DATA_WIDTH+7)/8, //! Width of the STRB signal
  
  parameter        CH_NUM_LOG = 4,
  parameter        DESC_RQ_DW = 512,
  parameter        DESC_RC_DW = 512,
  parameter        DESC_RQ_DK = DESC_RQ_DW/32,
  parameter        DESC_RC_DK = DESC_RC_DW/32,
  parameter        DESC_RC_USER = 32

)(


  //----------------------------------------------------------------------------------------------------------------//
  //  AXI Interface                                                                                                 //
  //----------------------------------------------------------------------------------------------------------------//

  output                                     m_axis_rq_tvalid,
  output              [C_DATA_WIDTH-1:0]     m_axis_rq_tdata,
  output                [KEEP_WIDTH-1:0]     m_axis_rq_tkeep,
  output                                     m_axis_rq_tlast,
  output       [AXI4_RQ_TUSER_WIDTH-1:0]     m_axis_rq_tuser,
  input                                      m_axis_rq_tready,

  input                                      s_axis_rc_tvalid,
  input               [C_DATA_WIDTH-1:0]     s_axis_rc_tdata,
  input                 [KEEP_WIDTH-1:0]     s_axis_rc_tkeep,
  input                                      s_axis_rc_tlast,
  input        [AXI4_RC_TUSER_WIDTH-1:0]     s_axis_rc_tuser,
  output                                     s_axis_rc_tready,

  input                                      s_axis_direct_tvalid,
  input                          [511:0]     s_axis_direct_tdata,
  input                           [15:0]     s_axis_direct_tuser,
  output                                     s_axis_direct_tready,

  input                            [3:0]     pcie_tfc_nph_av,
  input                            [3:0]     pcie_tfc_npd_av,


  //----------------------------------------------------------------------------------------------------------------//
  //  AXI Lite Interface                                                                                            //
  //----------------------------------------------------------------------------------------------------------------//

  input   [ADDR_W-1:0]             s_axi_araddr  , //! AXI4-Lite ARADDR 
  input                            s_axi_arvalid , //! AXI4-Lite ARVALID
  output                           s_axi_arready , //! AXI4-Lite ARREADY
  output  [DATA_WIDTH-1:0]         s_axi_rdata   , //! AXI4-Lite RDATA  
  output  [1:0]                    s_axi_rresp   , //! AXI4-Lite RRESP  
  output                           s_axi_rvalid  , //! AXI4-Lite RVALID 
  input                            s_axi_rready  , //! AXI4-Lite RREADY 
  input   [ADDR_W-1:0]             s_axi_awaddr  , //! AXI4-Lite AWADDR 
  input                            s_axi_awvalid , //! AXI4-Lite AWVALID
  output                           s_axi_awready , //! AXI4-Lite AWREADY
  input   [DATA_WIDTH-1:0]         s_axi_wdata   , //! AXI4-Lite WDATA  
  input   [STRB_WIDTH-1:0]         s_axi_wstrb   , //! AXI4-Lite WSTRB not used
  input                            s_axi_wvalid  , //! AXI4-Lite WVALID 
  output                           s_axi_wready  , //! AXI4-Lite WREADY 
  output  [1:0]                    s_axi_bresp   , //! AXI4-Lite BRESP  
  output                           s_axi_bvalid  , //! AXI4-Lite BVALID 
  input                            s_axi_bready  , //! AXI4-Lite BREADY 
  input   [2:0]                    s_axi_awprot  , //! AXI4-Lite AWPROT not used //disconnected
  input   [2:0]                    s_axi_arprot  , //! AXI4-Lite ARPROT not used //disconnected


  //----------------------------------------------------------------------------------------------------------------//
  // AXI4 CIF_DN                                                                                                    //
  //----------------------------------------------------------------------------------------------------------------//

  output          m_axi_cd_0_awvalid,
  output          m_axi_cd_1_awvalid,
  output          m_axi_cd_2_awvalid,
  output          m_axi_cd_3_awvalid,
  input           m_axi_cd_0_awready,
  input           m_axi_cd_1_awready,
  input           m_axi_cd_2_awready,
  input           m_axi_cd_3_awready,
  output  [63:0]  m_axi_cd_0_awaddr,
  output  [63:0]  m_axi_cd_1_awaddr,
  output  [63:0]  m_axi_cd_2_awaddr,
  output  [63:0]  m_axi_cd_3_awaddr,
  output  [7:0]   m_axi_cd_0_awlen,
  output  [7:0]   m_axi_cd_1_awlen,
  output  [7:0]   m_axi_cd_2_awlen,
  output  [7:0]   m_axi_cd_3_awlen,
  output  [2:0]   m_axi_cd_0_awsize,
  output  [2:0]   m_axi_cd_1_awsize,
  output  [2:0]   m_axi_cd_2_awsize,
  output  [2:0]   m_axi_cd_3_awsize,
  output  [1:0]   m_axi_cd_0_awburst,
  output  [1:0]   m_axi_cd_1_awburst,
  output  [1:0]   m_axi_cd_2_awburst,
  output  [1:0]   m_axi_cd_3_awburst,
  output          m_axi_cd_0_awlock,
  output          m_axi_cd_1_awlock,
  output          m_axi_cd_2_awlock,
  output          m_axi_cd_3_awlock,
  output  [3:0]   m_axi_cd_0_awcache,
  output  [3:0]   m_axi_cd_1_awcache,
  output  [3:0]   m_axi_cd_2_awcache,
  output  [3:0]   m_axi_cd_3_awcache,
  output  [2:0]   m_axi_cd_0_awprot,
  output  [2:0]   m_axi_cd_1_awprot,
  output  [2:0]   m_axi_cd_2_awprot,
  output  [2:0]   m_axi_cd_3_awprot,
  output  [3:0]   m_axi_cd_0_awqos,
  output  [3:0]   m_axi_cd_1_awqos,
  output  [3:0]   m_axi_cd_2_awqos,
  output  [3:0]   m_axi_cd_3_awqos,
  output  [3:0]   m_axi_cd_0_awregion,
  output  [3:0]   m_axi_cd_1_awregion,
  output  [3:0]   m_axi_cd_2_awregion,
  output  [3:0]   m_axi_cd_3_awregion,
  output          m_axi_cd_0_wvalid,
  output          m_axi_cd_1_wvalid,
  output          m_axi_cd_2_wvalid,
  output          m_axi_cd_3_wvalid,
  input           m_axi_cd_0_wready,
  input           m_axi_cd_1_wready,
  input           m_axi_cd_2_wready,
  input           m_axi_cd_3_wready,
  output  [511:0] m_axi_cd_0_wdata,
  output  [511:0] m_axi_cd_1_wdata,
  output  [511:0] m_axi_cd_2_wdata,
  output  [511:0] m_axi_cd_3_wdata,
  output  [63:0]  m_axi_cd_0_wstrb,
  output  [63:0]  m_axi_cd_1_wstrb,
  output  [63:0]  m_axi_cd_2_wstrb,
  output  [63:0]  m_axi_cd_3_wstrb,
  output          m_axi_cd_0_wlast,
  output          m_axi_cd_1_wlast,
  output          m_axi_cd_2_wlast,
  output          m_axi_cd_3_wlast,
  output          m_axi_cd_0_arvalid,
  output          m_axi_cd_1_arvalid,
  output          m_axi_cd_2_arvalid,
  output          m_axi_cd_3_arvalid,
  input           m_axi_cd_0_arready,
  input           m_axi_cd_1_arready,
  input           m_axi_cd_2_arready,
  input           m_axi_cd_3_arready,
  output  [63:0]  m_axi_cd_0_araddr,
  output  [63:0]  m_axi_cd_1_araddr,
  output  [63:0]  m_axi_cd_2_araddr,
  output  [63:0]  m_axi_cd_3_araddr,
  output  [7:0]   m_axi_cd_0_arlen,
  output  [7:0]   m_axi_cd_1_arlen,
  output  [7:0]   m_axi_cd_2_arlen,
  output  [7:0]   m_axi_cd_3_arlen,
  output  [2:0]   m_axi_cd_0_arsize,
  output  [2:0]   m_axi_cd_1_arsize,
  output  [2:0]   m_axi_cd_2_arsize,
  output  [2:0]   m_axi_cd_3_arsize,
  output  [1:0]   m_axi_cd_0_arburst,
  output  [1:0]   m_axi_cd_1_arburst,
  output  [1:0]   m_axi_cd_2_arburst,
  output  [1:0]   m_axi_cd_3_arburst,
  output          m_axi_cd_0_arlock,
  output          m_axi_cd_1_arlock,
  output          m_axi_cd_2_arlock,
  output          m_axi_cd_3_arlock,
  output  [3:0]   m_axi_cd_0_arcache,
  output  [3:0]   m_axi_cd_1_arcache,
  output  [3:0]   m_axi_cd_2_arcache,
  output  [3:0]   m_axi_cd_3_arcache,
  output  [2:0]   m_axi_cd_0_arprot,
  output  [2:0]   m_axi_cd_1_arprot,
  output  [2:0]   m_axi_cd_2_arprot,
  output  [2:0]   m_axi_cd_3_arprot,
  output  [3:0]   m_axi_cd_0_arqos,
  output  [3:0]   m_axi_cd_1_arqos,
  output  [3:0]   m_axi_cd_2_arqos,
  output  [3:0]   m_axi_cd_3_arqos,
  output  [3:0]   m_axi_cd_0_arregion,
  output  [3:0]   m_axi_cd_1_arregion,
  output  [3:0]   m_axi_cd_2_arregion,
  output  [3:0]   m_axi_cd_3_arregion,
  input           m_axi_cd_0_rvalid,
  input           m_axi_cd_1_rvalid,
  input           m_axi_cd_2_rvalid,
  input           m_axi_cd_3_rvalid,
  output          m_axi_cd_0_rready,
  output          m_axi_cd_1_rready,
  output          m_axi_cd_2_rready,
  output          m_axi_cd_3_rready,
  input   [511:0] m_axi_cd_0_rdata,
  input   [511:0] m_axi_cd_1_rdata,
  input   [511:0] m_axi_cd_2_rdata,
  input   [511:0] m_axi_cd_3_rdata,
  input           m_axi_cd_0_rlast,
  input           m_axi_cd_1_rlast,
  input           m_axi_cd_2_rlast,
  input           m_axi_cd_3_rlast,
  input    [1:0]  m_axi_cd_0_rresp,
  input    [1:0]  m_axi_cd_1_rresp,
  input    [1:0]  m_axi_cd_2_rresp,
  input    [1:0]  m_axi_cd_3_rresp,
  input           m_axi_cd_0_bvalid,
  input           m_axi_cd_1_bvalid,
  input           m_axi_cd_2_bvalid,
  input           m_axi_cd_3_bvalid,
  output          m_axi_cd_0_bready,
  output          m_axi_cd_1_bready,
  output          m_axi_cd_2_bready,
  output          m_axi_cd_3_bready,
  input    [1:0]  m_axi_cd_0_bresp,
  input    [1:0]  m_axi_cd_1_bresp,
  input    [1:0]  m_axi_cd_2_bresp,
  input    [1:0]  m_axi_cd_3_bresp,

  //----------------------------------------------------------------------------------------------------------------//
  // AXI-S CIF_DN                                                                                                   //
  //----------------------------------------------------------------------------------------------------------------//

  //input          s_axis_cd_transfer_cmd_0_tvalid,
  //input          s_axis_cd_transfer_cmd_1_tvalid,
  //input          s_axis_cd_transfer_cmd_2_tvalid,
  //input          s_axis_cd_transfer_cmd_3_tvalid,
  //input  [63:0]  s_axis_cd_transfer_cmd_0_tdata,
  //input  [63:0]  s_axis_cd_transfer_cmd_1_tdata,
  //input  [63:0]  s_axis_cd_transfer_cmd_2_tdata,
  //input  [63:0]  s_axis_cd_transfer_cmd_3_tdata,
  //output         s_axis_cd_transfer_cmd_0_tready,
  //output         s_axis_cd_transfer_cmd_1_tready,
  //output         s_axis_cd_transfer_cmd_2_tready,
  //output         s_axis_cd_transfer_cmd_3_tready,
  //output         m_axis_cd_transfer_eve_0_tvalid,
  //output         m_axis_cd_transfer_eve_1_tvalid,
  //output         m_axis_cd_transfer_eve_2_tvalid,
  //output         m_axis_cd_transfer_eve_3_tvalid,
  //output [127:0] m_axis_cd_transfer_eve_0_tdata,
  //output [127:0] m_axis_cd_transfer_eve_1_tdata,
  //output [127:0] m_axis_cd_transfer_eve_2_tdata,
  //output [127:0] m_axis_cd_transfer_eve_3_tdata,
  //input          m_axis_cd_transfer_eve_0_tready,
  //input          m_axis_cd_transfer_eve_1_tready,
  //input          m_axis_cd_transfer_eve_2_tready,
  //input          m_axis_cd_transfer_eve_3_tready,

  //----------------------------------------------------------------------------------------------------------------//
  // AXI4 CIF_UP                                                                                                    //
  //----------------------------------------------------------------------------------------------------------------//

  output          m_axi_cu_0_awvalid,
  output          m_axi_cu_1_awvalid,
  output          m_axi_cu_2_awvalid,
  output          m_axi_cu_3_awvalid,
  input           m_axi_cu_0_awready,
  input           m_axi_cu_1_awready,
  input           m_axi_cu_2_awready,
  input           m_axi_cu_3_awready,
  output  [63:0]  m_axi_cu_0_awaddr,
  output  [63:0]  m_axi_cu_1_awaddr,
  output  [63:0]  m_axi_cu_2_awaddr,
  output  [63:0]  m_axi_cu_3_awaddr,
  output  [7:0]   m_axi_cu_0_awlen,
  output  [7:0]   m_axi_cu_1_awlen,
  output  [7:0]   m_axi_cu_2_awlen,
  output  [7:0]   m_axi_cu_3_awlen,
  output  [2:0]   m_axi_cu_0_awsize,
  output  [2:0]   m_axi_cu_1_awsize,
  output  [2:0]   m_axi_cu_2_awsize,
  output  [2:0]   m_axi_cu_3_awsize,
  output  [1:0]   m_axi_cu_0_awburst,
  output  [1:0]   m_axi_cu_1_awburst,
  output  [1:0]   m_axi_cu_2_awburst,
  output  [1:0]   m_axi_cu_3_awburst,
  output          m_axi_cu_0_awlock,
  output          m_axi_cu_1_awlock,
  output          m_axi_cu_2_awlock,
  output          m_axi_cu_3_awlock,
  output  [3:0]   m_axi_cu_0_awcache,
  output  [3:0]   m_axi_cu_1_awcache,
  output  [3:0]   m_axi_cu_2_awcache,
  output  [3:0]   m_axi_cu_3_awcache,
  output  [2:0]   m_axi_cu_0_awprot,
  output  [2:0]   m_axi_cu_1_awprot,
  output  [2:0]   m_axi_cu_2_awprot,
  output  [2:0]   m_axi_cu_3_awprot,
  output  [3:0]   m_axi_cu_0_awqos,
  output  [3:0]   m_axi_cu_1_awqos,
  output  [3:0]   m_axi_cu_2_awqos,
  output  [3:0]   m_axi_cu_3_awqos,
  output  [3:0]   m_axi_cu_0_awregion,
  output  [3:0]   m_axi_cu_1_awregion,
  output  [3:0]   m_axi_cu_2_awregion,
  output  [3:0]   m_axi_cu_3_awregion,
  output          m_axi_cu_0_wvalid,
  output          m_axi_cu_1_wvalid,
  output          m_axi_cu_2_wvalid,
  output          m_axi_cu_3_wvalid,
  input           m_axi_cu_0_wready,
  input           m_axi_cu_1_wready,
  input           m_axi_cu_2_wready,
  input           m_axi_cu_3_wready,
  output  [511:0] m_axi_cu_0_wdata,
  output  [511:0] m_axi_cu_1_wdata,
  output  [511:0] m_axi_cu_2_wdata,
  output  [511:0] m_axi_cu_3_wdata,
  output  [63:0]  m_axi_cu_0_wstrb,
  output  [63:0]  m_axi_cu_1_wstrb,
  output  [63:0]  m_axi_cu_2_wstrb,
  output  [63:0]  m_axi_cu_3_wstrb,
  output          m_axi_cu_0_wlast,
  output          m_axi_cu_1_wlast,
  output          m_axi_cu_2_wlast,
  output          m_axi_cu_3_wlast,
  output          m_axi_cu_0_arvalid,
  output          m_axi_cu_1_arvalid,
  output          m_axi_cu_2_arvalid,
  output          m_axi_cu_3_arvalid,
  input           m_axi_cu_0_arready,
  input           m_axi_cu_1_arready,
  input           m_axi_cu_2_arready,
  input           m_axi_cu_3_arready,
  output  [63:0]  m_axi_cu_0_araddr,
  output  [63:0]  m_axi_cu_1_araddr,
  output  [63:0]  m_axi_cu_2_araddr,
  output  [63:0]  m_axi_cu_3_araddr,
  output  [7:0]   m_axi_cu_0_arlen,
  output  [7:0]   m_axi_cu_1_arlen,
  output  [7:0]   m_axi_cu_2_arlen,
  output  [7:0]   m_axi_cu_3_arlen,
  output  [2:0]   m_axi_cu_0_arsize,
  output  [2:0]   m_axi_cu_1_arsize,
  output  [2:0]   m_axi_cu_2_arsize,
  output  [2:0]   m_axi_cu_3_arsize,
  output  [1:0]   m_axi_cu_0_arburst,
  output  [1:0]   m_axi_cu_1_arburst,
  output  [1:0]   m_axi_cu_2_arburst,
  output  [1:0]   m_axi_cu_3_arburst,
  output          m_axi_cu_0_arlock,
  output          m_axi_cu_1_arlock,
  output          m_axi_cu_2_arlock,
  output          m_axi_cu_3_arlock,
  output  [3:0]   m_axi_cu_0_arcache,
  output  [3:0]   m_axi_cu_1_arcache,
  output  [3:0]   m_axi_cu_2_arcache,
  output  [3:0]   m_axi_cu_3_arcache,
  output  [2:0]   m_axi_cu_0_arprot,
  output  [2:0]   m_axi_cu_1_arprot,
  output  [2:0]   m_axi_cu_2_arprot,
  output  [2:0]   m_axi_cu_3_arprot,
  output  [3:0]   m_axi_cu_0_arqos,
  output  [3:0]   m_axi_cu_1_arqos,
  output  [3:0]   m_axi_cu_2_arqos,
  output  [3:0]   m_axi_cu_3_arqos,
  output  [3:0]   m_axi_cu_0_arregion,
  output  [3:0]   m_axi_cu_1_arregion,
  output  [3:0]   m_axi_cu_2_arregion,
  output  [3:0]   m_axi_cu_3_arregion,
  input           m_axi_cu_0_rvalid,
  input           m_axi_cu_1_rvalid,
  input           m_axi_cu_2_rvalid,
  input           m_axi_cu_3_rvalid,
  output          m_axi_cu_0_rready,
  output          m_axi_cu_1_rready,
  output          m_axi_cu_2_rready,
  output          m_axi_cu_3_rready,
  input   [511:0] m_axi_cu_0_rdata,
  input   [511:0] m_axi_cu_1_rdata,
  input   [511:0] m_axi_cu_2_rdata,
  input   [511:0] m_axi_cu_3_rdata,
  input           m_axi_cu_0_rlast,
  input           m_axi_cu_1_rlast,
  input           m_axi_cu_2_rlast,
  input           m_axi_cu_3_rlast,
  input    [1:0]  m_axi_cu_0_rresp,
  input    [1:0]  m_axi_cu_1_rresp,
  input    [1:0]  m_axi_cu_2_rresp,
  input    [1:0]  m_axi_cu_3_rresp,
  input           m_axi_cu_0_bvalid,
  input           m_axi_cu_1_bvalid,
  input           m_axi_cu_2_bvalid,
  input           m_axi_cu_3_bvalid,
  output          m_axi_cu_0_bready,
  output          m_axi_cu_1_bready,
  output          m_axi_cu_2_bready,
  output          m_axi_cu_3_bready,
  input    [1:0]  m_axi_cu_0_bresp,
  input    [1:0]  m_axi_cu_1_bresp,
  input    [1:0]  m_axi_cu_2_bresp,
  input    [1:0]  m_axi_cu_3_bresp,

  //----------------------------------------------------------------------------------------------------------------//
  // AXI-S CIF_UP                                                                                                   //
  //----------------------------------------------------------------------------------------------------------------//

  //input          s_axis_cu_transfer_cmd_0_tvalid,
  //input          s_axis_cu_transfer_cmd_1_tvalid,
  //input          s_axis_cu_transfer_cmd_2_tvalid,
  //input          s_axis_cu_transfer_cmd_3_tvalid,
  //input  [63:0]  s_axis_cu_transfer_cmd_0_tdata,
  //input  [63:0]  s_axis_cu_transfer_cmd_1_tdata,
  //input  [63:0]  s_axis_cu_transfer_cmd_2_tdata,
  //input  [63:0]  s_axis_cu_transfer_cmd_3_tdata,
  //output         s_axis_cu_transfer_cmd_0_tready,
  //output         s_axis_cu_transfer_cmd_1_tready,
  //output         s_axis_cu_transfer_cmd_2_tready,
  //output         s_axis_cu_transfer_cmd_3_tready,
  //output         m_axis_cu_transfer_eve_0_tvalid,
  //output         m_axis_cu_transfer_eve_1_tvalid,
  //output         m_axis_cu_transfer_eve_2_tvalid,
  //output         m_axis_cu_transfer_eve_3_tvalid,
  //output [127:0] m_axis_cu_transfer_eve_0_tdata,
  //output [127:0] m_axis_cu_transfer_eve_1_tdata,
  //output [127:0] m_axis_cu_transfer_eve_2_tdata,
  //output [127:0] m_axis_cu_transfer_eve_3_tdata,
  //input          m_axis_cu_transfer_eve_0_tready,
  //input          m_axis_cu_transfer_eve_1_tready,
  //input          m_axis_cu_transfer_eve_2_tready,
  //input          m_axis_cu_transfer_eve_3_tready,

  //----------------------------------------------------------------------------------------------------------------//
  // AXI-S EVE CMD                                                                                                  //
  //----------------------------------------------------------------------------------------------------------------//

  input          s_axis_transfer_cmd_0_tvalid,
  input          s_axis_transfer_cmd_1_tvalid,
  input          s_axis_transfer_cmd_2_tvalid,
  input          s_axis_transfer_cmd_3_tvalid,
  input  [63:0]  s_axis_transfer_cmd_0_tdata,
  input  [63:0]  s_axis_transfer_cmd_1_tdata,
  input  [63:0]  s_axis_transfer_cmd_2_tdata,
  input  [63:0]  s_axis_transfer_cmd_3_tdata,
  output         s_axis_transfer_cmd_0_tready,
  output         s_axis_transfer_cmd_1_tready,
  output         s_axis_transfer_cmd_2_tready,
  output         s_axis_transfer_cmd_3_tready,
  output         m_axis_transfer_eve_0_tvalid,
  output         m_axis_transfer_eve_1_tvalid,
  output         m_axis_transfer_eve_2_tvalid,
  output         m_axis_transfer_eve_3_tvalid,
  output [127:0] m_axis_transfer_eve_0_tdata,
  output [127:0] m_axis_transfer_eve_1_tdata,
  output [127:0] m_axis_transfer_eve_2_tdata,
  output [127:0] m_axis_transfer_eve_3_tdata,
  input          m_axis_transfer_eve_0_tready,
  input          m_axis_transfer_eve_1_tready,
  input          m_axis_transfer_eve_2_tready,
  input          m_axis_transfer_eve_3_tready,

  //----------------------------------------------------------------------------------------------------------------//
  //  CMS IF                                                                                                        //
  //----------------------------------------------------------------------------------------------------------------//

  input                            s_d2d_req_valid,
  input                            s_d2d_ack_valid,
  input   [511:0]                  s_d2d_data,
  output                           s_d2d_ready,

  //----------------------------------------------------------------------------------------------------------------//
  //  Configuration (CFG) Interface                                                                                 //
  //----------------------------------------------------------------------------------------------------------------//

  input                            [3:0]     pcie_rq_seq_num,
  input                                      pcie_rq_seq_num_vld,
  input                            [5:0]     pcie_rq_tag,
  input                                      pcie_rq_tag_vld,
  output                                     pcie_cq_np_req,
  input                            [5:0]     pcie_cq_np_req_count,

  //----------------------------------------------------------------------------------------------------------------//
  // EP and RP                                                                                                      //
  //----------------------------------------------------------------------------------------------------------------//

  input                                      cfg_phy_link_down,
  input                            [2:0]     cfg_negotiated_width,
  input                            [1:0]     cfg_current_speed,
  input                            [1:0]     cfg_max_payload,
  input                            [2:0]     cfg_max_read_req,
  input                           [15:0]     cfg_function_status,
  input                           [11:0]     cfg_function_power_state,
  input                          [503:0]     cfg_vf_status,
  input                            [1:0]     cfg_link_power_state,

  // Error Reporting Interface
  input                                      cfg_err_cor_out,
  input                                      cfg_err_nonfatal_out,
  input                                      cfg_err_fatal_out,

  input                            [4:0]     cfg_local_error_out,
  input                                      cfg_local_error_valid,

  input                                      cfg_ltr_enable,
  input                            [5:0]     cfg_ltssm_state,
  input                            [3:0]     cfg_rcb_status,
  input                            [1:0]     cfg_obff_enable,
  input                                      cfg_pl_status_change,

  // Management Interface
  output wire                      [9:0]     cfg_mgmt_addr,
  output wire                                cfg_mgmt_write,
  output wire                     [31:0]     cfg_mgmt_write_data,
  output wire                      [3:0]     cfg_mgmt_byte_enable,
  output wire                                cfg_mgmt_read,
  input                           [31:0]     cfg_mgmt_read_data,
  input                                      cfg_mgmt_read_write_done,
  output wire                                cfg_mgmt_type1_cfg_reg_access,
  input                                      cfg_msg_received,
  input                            [7:0]     cfg_msg_received_data,
  input                            [4:0]     cfg_msg_received_type,
  output                                     cfg_msg_transmit,
  output                           [2:0]     cfg_msg_transmit_type,
  output                          [31:0]     cfg_msg_transmit_data,
  input                                      cfg_msg_transmit_done,
  input                            [7:0]     cfg_fc_ph,
  input                           [11:0]     cfg_fc_pd,
  input                            [7:0]     cfg_fc_nph,
  input                           [11:0]     cfg_fc_npd,
  input                            [7:0]     cfg_fc_cplh,
  input                           [11:0]     cfg_fc_cpld,
  output                           [2:0]     cfg_fc_sel,
  output  wire                     [2:0]     cfg_per_func_status_control,
  output  wire                     [3:0]     cfg_per_function_number,
  output  wire                               cfg_per_function_output_request,

  output wire                     [63:0]     cfg_dsn,
  output                                     cfg_power_state_change_ack,
  input                                      cfg_power_state_change_interrupt,
  output wire                                cfg_err_cor_in,
  output wire                                cfg_err_uncor_in,

  input                            [3:0]     cfg_flr_in_process,
  output wire                      [3:0]     cfg_flr_done,
  input                            [251:0]   cfg_vf_flr_in_process,
  output wire                                cfg_vf_flr_done,
  output wire                      [7:0]     cfg_vf_flr_func_num,

  output wire                                cfg_link_training_enable,

  output wire                      [7:0]     cfg_ds_port_number,
  output wire                      [7:0]     cfg_ds_bus_number,
  output wire                      [4:0]     cfg_ds_device_number,
  output wire                      [2:0]     cfg_ds_function_number,
  //----------------------------------------------------------------------------------------------------------------//
  // EP Only                                                                                                        //
  //----------------------------------------------------------------------------------------------------------------//

  // Interrupt Interface Signals
  output                           [3:0]     cfg_interrupt_int,
  output wire                      [3:0]     cfg_interrupt_pending,
  input                                      cfg_interrupt_sent,

  input                                      cfg_interrupt_msi_enable,
  input                           [11:0]     cfg_interrupt_msi_mmenable,
  input                                      cfg_interrupt_msi_mask_update,
  input                           [31:0]     cfg_interrupt_msi_data,
  output wire                      [1:0]     cfg_interrupt_msi_select,
  output                          [31:0]     cfg_interrupt_msi_int,
  output wire                     [31:0]     cfg_interrupt_msi_pending_status,
  input                                      cfg_interrupt_msi_sent,
  input                                      cfg_interrupt_msi_fail,
  output wire                      [2:0]     cfg_interrupt_msi_attr,
  output wire                                cfg_interrupt_msi_tph_present,
  output wire                      [1:0]     cfg_interrupt_msi_tph_type,
  output wire                      [7:0]     cfg_interrupt_msi_tph_st_tag,
  output wire                      [7:0]     cfg_interrupt_msi_function_number,


// EP only
  input                                      cfg_hot_reset_in,
  output wire                                cfg_config_space_enable,
  output wire                                cfg_req_pm_transition_l23_ready,

// RP only
  output wire                                cfg_hot_reset_out,

  //----------------------------------------------------------------------------------------------------------------//
  // CLK / RST                                                                                                      //
  //----------------------------------------------------------------------------------------------------------------//

  input            sys_rst,
  output [7:0]     leds,
  input            user_clk,
  input            user_reset,
  input            user_lnk_up,
  input            ext_clk,      // Chain control clock
  input            ext_reset,     // Chain control reset (active-high),
  

  //----------------------------------------------
  //Error detect
  //----------------------------------------------

  output          error_detect_lldma

);

  wire   s_axis_rc_tready_bit;

  //----------------------------------------------------------------------------------------------------------------//
  // PCIe Block EP Tieoffs - Example PIO doesn't support the following outputs                                      //
  //----------------------------------------------------------------------------------------------------------------//
  assign cfg_mgmt_addr                       = 10'h0;                // Zero out CFG MGMT 19-bit address port
  assign cfg_mgmt_write                      = 1'b0;                 // Do not write CFG space
  assign cfg_mgmt_write_data                 = 32'h0;                // Zero out CFG MGMT input data bus
  assign cfg_mgmt_byte_enable                = 4'h0;                 // Zero out CFG MGMT byte enables
  assign cfg_mgmt_read                       = 1'b0;                 // Do not read CFG space
  assign cfg_mgmt_type1_cfg_reg_access       = 1'b0;
  assign cfg_per_func_status_control         = 3'h0;                 // Do not request per function status
  assign cfg_dsn                             = {`PCI_EXP_EP_DSN_2, `PCI_EXP_EP_DSN_1};  // Assign the input DSN
  assign cfg_per_function_number             = 4'h0;                 // Zero out function num for status req
  assign cfg_per_function_output_request     = 1'b0;                 // Do not request configuration status update

  assign cfg_err_cor_in                      = 1'b0;                 // Never report Correctable Error
  assign cfg_err_uncor_in                    = 1'b0;                 // Never report UnCorrectable Error

  assign cfg_link_training_enable            = 1'b1;                 // Always enable LTSSM to bring up the Link

  assign cfg_config_space_enable             = 1'b1;
  assign cfg_req_pm_transition_l23_ready     = 1'b0;

  assign cfg_hot_reset_out                   = 1'b0;
  assign cfg_ds_port_number                  = 8'h0;
  assign cfg_ds_bus_number                   = 8'h0;
  assign cfg_ds_device_number                = 5'h0;
  assign cfg_ds_function_number              = 3'h0;
  assign cfg_interrupt_pending               = 4'h0;
  assign cfg_interrupt_msi_select            = 2'b00;
  assign cfg_interrupt_msi_pending_status    = 32'h0;

  assign cfg_interrupt_msi_attr              = 3'h0;
  assign cfg_interrupt_msi_tph_present       = 1'b0;
  assign cfg_interrupt_msi_tph_type          = 2'h0;
  assign cfg_interrupt_msi_tph_st_tag        = 8'h0;
  assign cfg_interrupt_msi_function_number   = 8'h0;

  assign s_axis_rc_tready  = s_axis_rc_tready_bit;
	
	
  reg [3:0]  cfg_flr_done_reg0;
  reg [5:0]  cfg_vf_flr_done_reg0;
  reg [3:0]  cfg_flr_done_reg1;
  reg [5:0]  cfg_vf_flr_done_reg1;


always @(posedge user_clk)
  begin
   if (user_reset) begin
      cfg_flr_done_reg0       <= 4'b0;
      cfg_vf_flr_done_reg0    <= 6'b0;
      cfg_flr_done_reg1       <= 4'b0;
      cfg_vf_flr_done_reg1    <= 6'b0;
    end
   else begin
      cfg_flr_done_reg0       <= cfg_flr_in_process;
      cfg_vf_flr_done_reg0    <= cfg_vf_flr_in_process;
      cfg_flr_done_reg1       <= cfg_flr_done_reg0;
      cfg_vf_flr_done_reg1    <= cfg_vf_flr_done_reg0;
    end
  end


assign cfg_flr_done[0] = ~cfg_flr_done_reg1[0] && cfg_flr_done_reg0[0];
assign cfg_flr_done[1] = ~cfg_flr_done_reg1[1] && cfg_flr_done_reg0[1];
assign cfg_flr_done[2] = ~cfg_flr_done_reg1[2] && cfg_flr_done_reg0[2];//2022.07.26 add
assign cfg_flr_done[3] = ~cfg_flr_done_reg1[3] && cfg_flr_done_reg0[3];//2022.07.26 add
assign cfg_vf_flr_done = ~cfg_vf_flr_done_reg1[0] && cfg_vf_flr_done_reg0[0]; 


  // Register and cycle through the virtual fucntion function level reset.
  // This counter will just loop over the virtual functions. Ths should be
  // repliced by user logic to perform the actual function level reset as
  // needed.
  reg     [7:0]     cfg_vf_flr_func_num_reg;
  always @(posedge user_clk) begin
    if(user_reset) begin
      cfg_vf_flr_func_num_reg <= 8'd0;
    end else begin
      cfg_vf_flr_func_num_reg <= cfg_vf_flr_func_num_reg + 1'b1;
    end
  end
  assign cfg_vf_flr_func_num = cfg_vf_flr_func_num_reg;

  // User clock heartbeat and LED connectivity
  reg    [25:0]     user_clk_heartbeat = 26'd0;
  // Create a Clock Heartbeat
  always @(posedge user_clk) begin
    if(!sys_rst) begin
      user_clk_heartbeat <= 26'd0;
    end else begin
      user_clk_heartbeat <= user_clk_heartbeat + 1'b1;
    end
  end
  // LED's enabled for Reference Board design
  // The LEDs are intentionally included in this module so they do not
  // get inferred by the tools for Tandem flows.
  OBUF led_0_obuf (.O(leds[0]), .I(sys_rst));
  OBUF led_1_obuf (.O(leds[1]), .I(user_lnk_up));
  OBUF led_2_obuf (.O(leds[2]), .I(user_clk_heartbeat[25]));
  OBUF led_3_obuf (.O(leds[3]), .I(cfg_current_speed[0]));
  OBUF led_4_obuf (.O(leds[4]), .I(cfg_current_speed[1]));
  OBUF led_5_obuf (.O(leds[5]), .I(cfg_negotiated_width[0]));
  OBUF led_6_obuf (.O(leds[6]), .I(cfg_negotiated_width[1]));
  OBUF led_7_obuf (.O(leds[7]), .I(cfg_negotiated_width[2]));

lldma #(
  .FPGA_INFO                              ( FPGA_INFO                      ),
  .TCQ                                    ( TCQ                            ),
  .C_DATA_WIDTH                           ( C_DATA_WIDTH                   ),
  .AXISTEN_IF_WIDTH                       ( AXISTEN_IF_WIDTH               ),
  .AXISTEN_IF_RQ_ALIGNMENT_MODE           ( AXISTEN_IF_RQ_ALIGNMENT_MODE   ),
  .AXISTEN_IF_CC_ALIGNMENT_MODE           ( AXISTEN_IF_CC_ALIGNMENT_MODE   ),
  .AXISTEN_IF_CQ_ALIGNMENT_MODE           ( AXISTEN_IF_CQ_ALIGNMENT_MODE   ),
  .AXISTEN_IF_RC_ALIGNMENT_MODE           ( AXISTEN_IF_RC_ALIGNMENT_MODE   ),
  .AXI4_CQ_TUSER_WIDTH                    ( AXI4_CQ_TUSER_WIDTH            ),
  .AXI4_CC_TUSER_WIDTH                    ( AXI4_CC_TUSER_WIDTH            ),
  .AXI4_RQ_TUSER_WIDTH                    ( AXI4_RQ_TUSER_WIDTH            ),
  .AXI4_RC_TUSER_WIDTH                    ( AXI4_RC_TUSER_WIDTH            ),
  .AXISTEN_IF_ENABLE_CLIENT_TAG           ( AXISTEN_IF_ENABLE_CLIENT_TAG   ),
  .AXISTEN_IF_RQ_PARITY_CHECK             ( AXISTEN_IF_RQ_PARITY_CHECK     ),
  .AXISTEN_IF_CC_PARITY_CHECK             ( AXISTEN_IF_CC_PARITY_CHECK     ),
  .AXISTEN_IF_RC_PARITY_CHECK             ( AXISTEN_IF_RC_PARITY_CHECK     ),
  .AXISTEN_IF_CQ_PARITY_CHECK             ( AXISTEN_IF_CQ_PARITY_CHECK     ),
  .AXISTEN_IF_ENABLE_RX_MSG_INTFC         ( AXISTEN_IF_ENABLE_RX_MSG_INTFC ),
  .AXISTEN_IF_ENABLE_MSG_ROUTE            ( AXISTEN_IF_ENABLE_MSG_ROUTE    ),
  .CH_NUM                                 ( CH_NUM                         ),
  .CHAIN_NUM                              ( CHAIN_NUM                      ),
  .CH_NUM_LOG                             ( CH_NUM_LOG                     ),
  .DESC_RQ_DW                             ( DESC_RQ_DW                     ),
  .DESC_RC_DW                             ( DESC_RC_DW                     ),
  .DESC_RQ_DK                             ( DESC_RQ_DK                     ),
  .DESC_RC_DK                             ( DESC_RC_DK                     ),
  .DESC_RC_USER                           ( DESC_RC_USER                   )
) lldma (
  .user_clk                                       ( user_clk    ),
  .reset_n                                        ( ~user_reset ),
  .user_lnk_up                                    ( user_lnk_up ),
  .ext_clk                                        ( ext_clk     ),
  .ext_reset_n                                    ( ~ext_reset  ),

  .error_detect_lldma                             (error_detect_lldma),

  //AXI4-Lite 

  .s_axi_araddr   (s_axi_araddr    ), // input
  .s_axi_arvalid  (s_axi_arvalid   ), // input
  .s_axi_arready  (s_axi_arready   ), // output
  .s_axi_rdata    (s_axi_rdata     ), // output
  .s_axi_rresp    (s_axi_rresp     ), // output
  .s_axi_rvalid   (s_axi_rvalid    ), // output
  .s_axi_rready   (s_axi_rready    ), // input
  .s_axi_awaddr   (s_axi_awaddr    ), // input
  .s_axi_awvalid  (s_axi_awvalid   ), // input
  .s_axi_awready  (s_axi_awready   ), // output
  .s_axi_wdata    (s_axi_wdata     ), // input
  .s_axi_wstrb    (s_axi_wstrb     ), // input
  .s_axi_wvalid   (s_axi_wvalid    ), // input
  .s_axi_wready   (s_axi_wready    ), // output
  .s_axi_bresp    (s_axi_bresp     ), // output
  .s_axi_bvalid   (s_axi_bvalid    ), // output
  .s_axi_bready   (s_axi_bready    ), // input

  // AXI4 CIF_UP

  .m_axi_cu_awvalid  ({m_axi_cu_1_awvalid  ,m_axi_cu_0_awvalid  }),
  .m_axi_cu_awready  ({m_axi_cu_1_awready  ,m_axi_cu_0_awready  }),
  .m_axi_cu_awaddr   ({m_axi_cu_1_awaddr   ,m_axi_cu_0_awaddr   }),
  .m_axi_cu_awlen    ({m_axi_cu_1_awlen    ,m_axi_cu_0_awlen    }),
  .m_axi_cu_awsize   ({m_axi_cu_1_awsize   ,m_axi_cu_0_awsize   }),
  .m_axi_cu_awburst  ({m_axi_cu_1_awburst  ,m_axi_cu_0_awburst  }),
  .m_axi_cu_awlock   ({m_axi_cu_1_awlock   ,m_axi_cu_0_awlock   }),
  .m_axi_cu_awcache  ({m_axi_cu_1_awcache  ,m_axi_cu_0_awcache  }),
  .m_axi_cu_awprot   ({m_axi_cu_1_awprot   ,m_axi_cu_0_awprot   }),
  .m_axi_cu_awqos    ({m_axi_cu_1_awqos    ,m_axi_cu_0_awqos    }),
  .m_axi_cu_awregion ({m_axi_cu_1_awregion ,m_axi_cu_0_awregion }),
  .m_axi_cu_wvalid   ({m_axi_cu_1_wvalid   ,m_axi_cu_0_wvalid   }),
  .m_axi_cu_wready   ({m_axi_cu_1_wready   ,m_axi_cu_0_wready   }),
  .m_axi_cu_wdata    ({m_axi_cu_1_wdata    ,m_axi_cu_0_wdata    }),
  .m_axi_cu_wstrb    ({m_axi_cu_1_wstrb    ,m_axi_cu_0_wstrb    }),
  .m_axi_cu_wlast    ({m_axi_cu_1_wlast    ,m_axi_cu_0_wlast    }),
  .m_axi_cu_arvalid  ({m_axi_cu_1_arvalid  ,m_axi_cu_0_arvalid  }),
  .m_axi_cu_arready  ({m_axi_cu_1_arready  ,m_axi_cu_0_arready  }),
  .m_axi_cu_araddr   ({m_axi_cu_1_araddr   ,m_axi_cu_0_araddr   }),
  .m_axi_cu_arlen    ({m_axi_cu_1_arlen    ,m_axi_cu_0_arlen    }),
  .m_axi_cu_arsize   ({m_axi_cu_1_arsize   ,m_axi_cu_0_arsize   }),
  .m_axi_cu_arburst  ({m_axi_cu_1_arburst  ,m_axi_cu_0_arburst  }),
  .m_axi_cu_arlock   ({m_axi_cu_1_arlock   ,m_axi_cu_0_arlock   }),
  .m_axi_cu_arcache  ({m_axi_cu_1_arcache  ,m_axi_cu_0_arcache  }),
  .m_axi_cu_arprot   ({m_axi_cu_1_arprot   ,m_axi_cu_0_arprot   }),
  .m_axi_cu_arqos    ({m_axi_cu_1_arqos    ,m_axi_cu_0_arqos    }),
  .m_axi_cu_arregion ({m_axi_cu_1_arregion ,m_axi_cu_0_arregion }),
  .m_axi_cu_rvalid   ({m_axi_cu_1_rvalid   ,m_axi_cu_0_rvalid   }),
  .m_axi_cu_rready   ({m_axi_cu_1_rready   ,m_axi_cu_0_rready   }),
  .m_axi_cu_rdata    ({m_axi_cu_1_rdata    ,m_axi_cu_0_rdata    }),
  .m_axi_cu_rlast    ({m_axi_cu_1_rlast    ,m_axi_cu_0_rlast    }),
  .m_axi_cu_rresp    ({m_axi_cu_1_rresp    ,m_axi_cu_0_rresp    }),
  .m_axi_cu_bvalid   ({m_axi_cu_1_bvalid   ,m_axi_cu_0_bvalid   }),
  .m_axi_cu_bready   ({m_axi_cu_1_bready   ,m_axi_cu_0_bready   }),
  .m_axi_cu_bresp    ({m_axi_cu_1_bresp    ,m_axi_cu_0_bresp    }),

  // AXI-S CIF_UP

  //.s_axis_cu_transfer_cmd_valid ({s_axis_cu_transfer_cmd_1_tvalid  ,s_axis_cu_transfer_cmd_0_tvalid  } ),
  //.s_axis_cu_transfer_cmd_data  ({s_axis_cu_transfer_cmd_1_tdata   ,s_axis_cu_transfer_cmd_0_tdata   } ),
  //.s_axis_cu_transfer_cmd_ready ({s_axis_cu_transfer_cmd_1_tready  ,s_axis_cu_transfer_cmd_0_tready  } ),
  //.m_axis_cu_transfer_eve_valid ({m_axis_cu_transfer_eve_1_tvalid  ,m_axis_cu_transfer_eve_0_tvalid  } ),
  //.m_axis_cu_transfer_eve_data  ({m_axis_cu_transfer_eve_1_tdata   ,m_axis_cu_transfer_eve_0_tdata   } ),
  //.m_axis_cu_transfer_eve_ready ({m_axis_cu_transfer_eve_1_tready  ,m_axis_cu_transfer_eve_0_tready  } ),

  // AXI4 CIF_DN

  .m_axi_cd_awvalid  ({m_axi_cd_1_awvalid  ,m_axi_cd_0_awvalid  }),
  .m_axi_cd_awready  ({m_axi_cd_1_awready  ,m_axi_cd_0_awready  }),
  .m_axi_cd_awaddr   ({m_axi_cd_1_awaddr   ,m_axi_cd_0_awaddr   }),
  .m_axi_cd_awlen    ({m_axi_cd_1_awlen    ,m_axi_cd_0_awlen    }),
  .m_axi_cd_awsize   ({m_axi_cd_1_awsize   ,m_axi_cd_0_awsize   }),
  .m_axi_cd_awburst  ({m_axi_cd_1_awburst  ,m_axi_cd_0_awburst  }),
  .m_axi_cd_awlock   ({m_axi_cd_1_awlock   ,m_axi_cd_0_awlock   }),
  .m_axi_cd_awcache  ({m_axi_cd_1_awcache  ,m_axi_cd_0_awcache  }),
  .m_axi_cd_awprot   ({m_axi_cd_1_awprot   ,m_axi_cd_0_awprot   }),
  .m_axi_cd_awqos    ({m_axi_cd_1_awqos    ,m_axi_cd_0_awqos    }),
  .m_axi_cd_awregion ({m_axi_cd_1_awregion ,m_axi_cd_0_awregion }),
  .m_axi_cd_wvalid   ({m_axi_cd_1_wvalid   ,m_axi_cd_0_wvalid   }),
  .m_axi_cd_wready   ({m_axi_cd_1_wready   ,m_axi_cd_0_wready   }),
  .m_axi_cd_wdata    ({m_axi_cd_1_wdata    ,m_axi_cd_0_wdata    }),
  .m_axi_cd_wstrb    ({m_axi_cd_1_wstrb    ,m_axi_cd_0_wstrb    }),
  .m_axi_cd_wlast    ({m_axi_cd_1_wlast    ,m_axi_cd_0_wlast    }),
  .m_axi_cd_arvalid  ({m_axi_cd_1_arvalid  ,m_axi_cd_0_arvalid  }),
  .m_axi_cd_arready  ({m_axi_cd_1_arready  ,m_axi_cd_0_arready  }),
  .m_axi_cd_araddr   ({m_axi_cd_1_araddr   ,m_axi_cd_0_araddr   }),
  .m_axi_cd_arlen    ({m_axi_cd_1_arlen    ,m_axi_cd_0_arlen    }),
  .m_axi_cd_arsize   ({m_axi_cd_1_arsize   ,m_axi_cd_0_arsize   }),
  .m_axi_cd_arburst  ({m_axi_cd_1_arburst  ,m_axi_cd_0_arburst  }),
  .m_axi_cd_arlock   ({m_axi_cd_1_arlock   ,m_axi_cd_0_arlock   }),
  .m_axi_cd_arcache  ({m_axi_cd_1_arcache  ,m_axi_cd_0_arcache  }),
  .m_axi_cd_arprot   ({m_axi_cd_1_arprot   ,m_axi_cd_0_arprot   }),
  .m_axi_cd_arqos    ({m_axi_cd_1_arqos    ,m_axi_cd_0_arqos    }),
  .m_axi_cd_arregion ({m_axi_cd_1_arregion ,m_axi_cd_0_arregion }),
  .m_axi_cd_rvalid   ({m_axi_cd_1_rvalid   ,m_axi_cd_0_rvalid   }),
  .m_axi_cd_rready   ({m_axi_cd_1_rready   ,m_axi_cd_0_rready   }),
  .m_axi_cd_rdata    ({m_axi_cd_1_rdata    ,m_axi_cd_0_rdata    }),
  .m_axi_cd_rlast    ({m_axi_cd_1_rlast    ,m_axi_cd_0_rlast    }),
  .m_axi_cd_rresp    ({m_axi_cd_1_rresp    ,m_axi_cd_0_rresp    }),
  .m_axi_cd_bvalid   ({m_axi_cd_1_bvalid   ,m_axi_cd_0_bvalid   }),
  .m_axi_cd_bready   ({m_axi_cd_1_bready   ,m_axi_cd_0_bready   }),
  .m_axi_cd_bresp    ({m_axi_cd_1_bresp    ,m_axi_cd_0_bresp    }),

  // AXI-S CIF_DN

  //.s_axis_cd_transfer_cmd_valid ({s_axis_cd_transfer_cmd_1_tvalid  ,s_axis_cd_transfer_cmd_0_tvalid  } ),
  //.s_axis_cd_transfer_cmd_data  ({s_axis_cd_transfer_cmd_1_tdata   ,s_axis_cd_transfer_cmd_0_tdata   } ),
  //.s_axis_cd_transfer_cmd_ready ({s_axis_cd_transfer_cmd_1_tready  ,s_axis_cd_transfer_cmd_0_tready  } ),
  //.m_axis_cd_transfer_eve_valid ({m_axis_cd_transfer_eve_1_tvalid  ,m_axis_cd_transfer_eve_0_tvalid  } ),
  //.m_axis_cd_transfer_eve_data  ({m_axis_cd_transfer_eve_1_tdata   ,m_axis_cd_transfer_eve_0_tdata   } ),
  //.m_axis_cd_transfer_eve_ready ({m_axis_cd_transfer_eve_1_tready  ,m_axis_cd_transfer_eve_0_tready  } ),

  // AXI-S EVE CMD

  .s_axis_transfer_cmd_valid ({s_axis_transfer_cmd_1_tvalid  ,s_axis_transfer_cmd_0_tvalid  } ),
  .s_axis_transfer_cmd_data  ({s_axis_transfer_cmd_1_tdata   ,s_axis_transfer_cmd_0_tdata   } ),
  .s_axis_transfer_cmd_ready ({s_axis_transfer_cmd_1_tready  ,s_axis_transfer_cmd_0_tready  } ),
  .m_axis_transfer_eve_valid ({m_axis_transfer_eve_1_tvalid  ,m_axis_transfer_eve_0_tvalid  } ),
  .m_axis_transfer_eve_data  ({m_axis_transfer_eve_1_tdata   ,m_axis_transfer_eve_0_tdata   } ),
  .m_axis_transfer_eve_ready ({m_axis_transfer_eve_1_tready  ,m_axis_transfer_eve_0_tready  } ),

  // CMS IF

  .s_d2d_req_valid   (s_d2d_req_valid ),
  .s_d2d_ack_valid   (s_d2d_ack_valid ),
  .s_d2d_data        (s_d2d_data      ),
  .s_d2d_ready       (s_d2d_ready     ),

  // AXI-S Requester Request Interface

  .m_axis_rq_tvalid                               ( m_axis_rq_tvalid ),
  .m_axis_rq_tdata                                ( m_axis_rq_tdata ),
  .m_axis_rq_tkeep                                ( m_axis_rq_tkeep ),
  .m_axis_rq_tlast                                ( m_axis_rq_tlast ),
  .m_axis_rq_tuser                                ( m_axis_rq_tuser ),
  .m_axis_rq_tready                               ( m_axis_rq_tready ),

  // AXI-S Requester Completion Interface

  .s_axis_rc_tvalid                               ( s_axis_rc_tvalid ),
  .s_axis_rc_tdata                                ( s_axis_rc_tdata ),
  .s_axis_rc_tkeep                                ( s_axis_rc_tkeep ),
  .s_axis_rc_tlast                                ( s_axis_rc_tlast ),
  .s_axis_rc_tuser                                ( s_axis_rc_tuser ),
  .s_axis_rc_tready                               ( s_axis_rc_tready_bit ),

  // AXI-S Completer Request Interface

  .s_axis_direct_tvalid                           ( s_axis_direct_tvalid ),
  .s_axis_direct_tdata                            ( s_axis_direct_tdata ),
  .s_axis_direct_tuser                            ( s_axis_direct_tuser ),
  .s_axis_direct_tready                           ( s_axis_direct_tready ),

  // Cfg, Pcie, Other

  .cfg_msg_transmit_done                          ( cfg_msg_transmit_done ),
  .cfg_msg_transmit                               ( cfg_msg_transmit ),
  .cfg_msg_transmit_type                          ( cfg_msg_transmit_type ),
  .cfg_msg_transmit_data                          ( cfg_msg_transmit_data ),
  .pcie_tfc_nph_av                                ( pcie_tfc_nph_av ),
  .pcie_tfc_npd_av                                ( pcie_tfc_npd_av ),
  .pcie_rq_tag                                    ( pcie_rq_tag ),
  .pcie_rq_tag_vld                                ( pcie_rq_tag_vld ),
  .pcie_tfc_np_pl_empty                           ( 1'b0 ),
  .pcie_rq_seq_num                                ( pcie_rq_seq_num ),
  .pcie_rq_seq_num_vld                            ( pcie_rq_seq_num_vld ),
  .pcie_cq_np_req                                 ( pcie_cq_np_req ),
  .pcie_cq_np_req_count                           ( pcie_cq_np_req_count ),

  .cfg_max_payload                                ( cfg_max_payload ),
  .cfg_max_read_req                               ( cfg_max_read_req ),

  .cfg_local_error_out                            ( cfg_local_error_out    ),
  .cfg_local_error_valid                          ( cfg_local_error_valid  ),

  .cfg_fc_ph                                      ( cfg_fc_ph ),
  .cfg_fc_nph                                     ( cfg_fc_nph ),
  .cfg_fc_cplh                                    ( cfg_fc_cplh ),
  .cfg_fc_pd                                      ( cfg_fc_pd ),
  .cfg_fc_npd                                     ( cfg_fc_npd ),
  .cfg_fc_cpld                                    ( cfg_fc_cpld ),
  .cfg_fc_sel                                     ( cfg_fc_sel ),

  .cfg_msg_received                               ( cfg_msg_received ),
  .cfg_msg_received_type                          ( cfg_msg_received_type ),
  .cfg_msg_received_data                          ( cfg_msg_received_data ),//cfg_msg_data -> cfg_msg_received_data

  .cfg_interrupt_msi_enable                       ( cfg_interrupt_msi_enable ),
  .cfg_interrupt_msi_sent                         ( cfg_interrupt_msi_sent ),
  .cfg_interrupt_msi_fail                         ( cfg_interrupt_msi_fail ),

  .cfg_interrupt_msi_int                          ( cfg_interrupt_msi_int ),
  .cfg_interrupt_msix_enable                      ( 1'b0 ),
  .cfg_interrupt_msix_sent                        ( 1'b0 ),
  .cfg_interrupt_msix_fail                        ( 1'b0 ),

  .cfg_interrupt_msix_int                         ( ),
  .cfg_interrupt_msix_address                     ( ),
  .cfg_interrupt_msix_data                        ( ),

  .cfg_power_state_change_interrupt               ( cfg_power_state_change_interrupt ),
  .cfg_power_state_change_ack                     ( cfg_power_state_change_ack ),

  .interrupt_done                                 ( ),

  .cfg_interrupt_sent                             ( cfg_interrupt_sent ),
  .cfg_interrupt_int                              ( cfg_interrupt_int )
 );

endmodule


