/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module rs_ddr_w (
  input  logic         user_clk,
  input  logic         reset_n,

  output logic         m_axi_cd_awvalid,
  output logic [ 63:0] m_axi_cd_awaddr,
  output logic [  7:0] m_axi_cd_awlen,
  input  logic         m_axi_cd_awready,

  input  logic         m_axi_cd_awvalid_rs,
  input  logic [ 63:0] m_axi_cd_awaddr_rs,
  input  logic [  7:0] m_axi_cd_awlen_rs,
  output logic         m_axi_cd_awready_rs,

  output logic         m_axi_cd_wvalid,
  output logic [511:0] m_axi_cd_wdata,
  output logic         m_axi_cd_wlast,
  input  logic         m_axi_cd_wready,

  input  logic         m_axi_cd_wvalid_rs,
  input  logic [511:0] m_axi_cd_wdata_rs,
  input  logic         m_axi_cd_wlast_rs,
  output logic         m_axi_cd_wready_rs,

  input  logic         m_axi_cd_bvalid,
  input  logic [  1:0] m_axi_cd_bresp,
  output logic         m_axi_cd_bready,

  output logic         m_axi_cd_bvalid_rs,
  output logic [  1:0] m_axi_cd_bresp_rs,
  input logic          m_axi_cd_bready_rs
);

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      m_axi_cd_awvalid   <= '0;
      m_axi_cd_awaddr    <= '0;
      m_axi_cd_awlen     <= '0;
      m_axi_cd_wvalid    <= '0;
      m_axi_cd_wdata     <= '0;
      m_axi_cd_wlast     <= '0;
      m_axi_cd_bvalid_rs <= '0;
      m_axi_cd_bresp_rs  <= '0;
    end else begin
      if (m_axi_cd_awready_rs == 1'b1) begin
        m_axi_cd_awvalid <= m_axi_cd_awvalid_rs;
        m_axi_cd_awaddr  <= m_axi_cd_awaddr_rs;
        m_axi_cd_awlen   <= m_axi_cd_awlen_rs;
      end
      if (m_axi_cd_wready_rs == 1'b1) begin
        m_axi_cd_wvalid  <= m_axi_cd_wvalid_rs;
        m_axi_cd_wdata   <= m_axi_cd_wdata_rs;
        m_axi_cd_wlast   <= m_axi_cd_wlast_rs;
      end
      if (m_axi_cd_bready == 1'b1) begin
        m_axi_cd_bvalid_rs <= m_axi_cd_bvalid;
        m_axi_cd_bresp_rs  <= m_axi_cd_bresp;
      end
    end
  end
     
  assign m_axi_cd_awready_rs = m_axi_cd_awready   | ~m_axi_cd_awvalid;
  assign m_axi_cd_wready_rs  = m_axi_cd_wready    | ~m_axi_cd_wvalid;
  assign m_axi_cd_bready     = m_axi_cd_bready_rs;

endmodule
