/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module rs_ddr_r (
  input  logic         user_clk,
  input  logic         reset_n,

  output logic         m_axi_cu_arvalid,
  output logic [ 63:0] m_axi_cu_araddr,
  output logic [  7:0] m_axi_cu_arlen,
  input  logic         m_axi_cu_arready,

  input  logic         m_axi_cu_arvalid_rs,
  input  logic [ 63:0] m_axi_cu_araddr_rs,
  input  logic [  7:0] m_axi_cu_arlen_rs,
  output logic         m_axi_cu_arready_rs,

  input  logic         m_axi_cu_rvalid,
  input  logic [511:0] m_axi_cu_rdata,
  input  logic         m_axi_cu_rlast,
  input  logic [  1:0] m_axi_cu_rresp,
  output logic         m_axi_cu_rready,

  output logic         m_axi_cu_rvalid_rs,
  output logic [511:0] m_axi_cu_rdata_rs,
  output logic         m_axi_cu_rlast_rs,
  output logic [  1:0] m_axi_cu_rresp_rs,
  input  logic         m_axi_cu_rready_rs
);

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      m_axi_cu_arvalid     <= '0;
      m_axi_cu_araddr      <= '0;
      m_axi_cu_arlen       <= '0;
      m_axi_cu_rvalid_rs   <= '0;
      m_axi_cu_rdata_rs    <= '0;
      m_axi_cu_rlast_rs    <= '0;
      m_axi_cu_rresp_rs    <= '0;
    end else begin
      if (m_axi_cu_arready_rs == 1'b1) begin
        m_axi_cu_arvalid   <= m_axi_cu_arvalid_rs;
        m_axi_cu_araddr    <= m_axi_cu_araddr_rs;
        m_axi_cu_arlen     <= m_axi_cu_arlen_rs;
      end
      if (m_axi_cu_rready == 1'b1) begin
        m_axi_cu_rvalid_rs <= m_axi_cu_rvalid;
        m_axi_cu_rdata_rs  <= m_axi_cu_rdata;
        m_axi_cu_rlast_rs  <= m_axi_cu_rlast;
        m_axi_cu_rresp_rs  <= m_axi_cu_rresp;
      end
    end
  end
     
  assign m_axi_cu_arready_rs = m_axi_cu_arready   | ~m_axi_cu_arvalid;
  assign m_axi_cu_rready     = m_axi_cu_rready_rs;

endmodule
