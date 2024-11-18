/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module axi4l_decoupler #(
  parameter IN_ADDR_WIDTH          = 16,
  parameter DATA_WIDTH             = 32
)(

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME user_clk, ASSOCIATED_BUSIF m_axi:s_axi, ASSOCIATED_RESET reset_n, FREQ_TOLERANCE_HZ 0, PHASE 0.000, INSERT_VIP 0" *)
  input  wire                           user_clk,
  input  wire                           reset_n,
  input  wire                           decouple_enable,
  output wire                           decouple_status,
  
  // In
  input  wire       [IN_ADDR_WIDTH-1:0] s_axi_awaddr,
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
  input  wire       [IN_ADDR_WIDTH-1:0] s_axi_araddr,
  input  wire                     [2:0] s_axi_arprot,
  input  wire                           s_axi_arvalid,
  output wire                           s_axi_arready,
  output wire                    [31:0] s_axi_rdata,
  output wire                     [1:0] s_axi_rresp,  // open
  output wire                           s_axi_rvalid,
  input  wire                           s_axi_rready,

  // Out
  output wire       [IN_ADDR_WIDTH-1:0] m_axi_awaddr,
  output wire                     [2:0] m_axi_awprot,
  output wire                           m_axi_awvalid,
  input  wire                           m_axi_awready,
  output wire                    [31:0] m_axi_wdata,
  output wire                     [3:0] m_axi_wstrb,
  output wire                           m_axi_wvalid,
  input  wire                           m_axi_wready,
  input  wire                     [1:0] m_axi_bresp,  // open
  input  wire                           m_axi_bvalid, // Write response (unused)
  output wire                           m_axi_bready,
  output wire       [IN_ADDR_WIDTH-1:0] m_axi_araddr,
  output wire                     [2:0] m_axi_arprot,
  output wire                           m_axi_arvalid,
  input  wire                           m_axi_arready,
  input  wire                    [31:0] m_axi_rdata,
  input  wire                     [1:0] m_axi_rresp,  // open
  input  wire                           m_axi_rvalid,
  output wire                           m_axi_rready
);


  assign  m_axi_awaddr  = s_axi_awaddr ;
  assign  m_axi_awprot  = s_axi_awprot ;
  assign  m_axi_awvalid = s_axi_awvalid & ~decouple_enable;
  assign  s_axi_awready = m_axi_awready & ~decouple_enable;
  assign  m_axi_wdata   = s_axi_wdata  ;
  assign  m_axi_wstrb   = s_axi_wstrb  ;
  assign  m_axi_wvalid  = s_axi_wvalid  & ~decouple_enable;
  assign  s_axi_wready  = m_axi_wready  & ~decouple_enable;
  assign  s_axi_bresp   = m_axi_bresp  ;
  assign  s_axi_bvalid  = m_axi_bvalid  & ~decouple_enable;
  assign  m_axi_bready  = s_axi_bready  & ~decouple_enable;
  assign  m_axi_araddr  = s_axi_araddr ;
  assign  m_axi_arprot  = s_axi_arprot ;
  assign  m_axi_arvalid = s_axi_arvalid & ~decouple_enable;
  assign  s_axi_arready = m_axi_arready & ~decouple_enable;
  assign  s_axi_rdata   = m_axi_rdata  ;
  assign  s_axi_rresp   = m_axi_rresp  ;
  assign  s_axi_rvalid  = m_axi_rvalid  & ~decouple_enable;
  assign  m_axi_rready  = s_axi_rready  & ~decouple_enable;
  
  assign  decouple_status = decouple_enable;
    
endmodule
