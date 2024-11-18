/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module rs_pcie (
  input  logic         user_clk,
  input  logic         reset_n,

  output logic         m_axis_rq_tvalid,
  output logic [511:0] m_axis_rq_tdata,
  output logic [ 15:0] m_axis_rq_tkeep,
  output logic [136:0] m_axis_rq_tuser,
  output logic         m_axis_rq_tlast,
  input  logic         m_axis_rq_tready,

  input  logic         m_axis_rq_tvalid_rs,
  input  logic [511:0] m_axis_rq_tdata_rs,
  input  logic [ 15:0] m_axis_rq_tkeep_rs,
  input  logic [136:0] m_axis_rq_tuser_rs,
  input  logic         m_axis_rq_tlast_rs,
  output logic         m_axis_rq_tready_rs,

  input  logic         s_axis_rc_tvalid,
  input  logic [511:0] s_axis_rc_tdata,
  input  logic [ 15:0] s_axis_rc_tkeep,
  input  logic [ 16:0] s_axis_rc_tuser,
  input  logic         s_axis_rc_tlast,
  output logic         s_axis_rc_tready,

  output logic         s_axis_rc_tvalid_rs,
  output logic [511:0] s_axis_rc_tdata_rs,
  output logic [ 15:0] s_axis_rc_tkeep_rs,
  output logic [ 16:0] s_axis_rc_tuser_rs,
  output logic         s_axis_rc_tlast_rs,
  input  logic         s_axis_rc_tready_rs
);

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      m_axis_rq_tvalid      <= '0;
      m_axis_rq_tdata       <= '0;
      m_axis_rq_tkeep       <= '0;
      m_axis_rq_tuser       <= '0;
      m_axis_rq_tlast       <= '0;
      s_axis_rc_tvalid_rs   <= '0;
      s_axis_rc_tdata_rs    <= '0;
      s_axis_rc_tkeep_rs    <= '0;
      s_axis_rc_tuser_rs    <= '0;
      s_axis_rc_tlast_rs    <= '0;
    end else begin
      if (m_axis_rq_tready_rs == 1'b1) begin
        m_axis_rq_tvalid    <= m_axis_rq_tvalid_rs;
        m_axis_rq_tdata     <= m_axis_rq_tdata_rs;
        m_axis_rq_tkeep     <= m_axis_rq_tkeep_rs;
        m_axis_rq_tuser     <= m_axis_rq_tuser_rs;
        m_axis_rq_tlast     <= m_axis_rq_tlast_rs;
      end
      if (s_axis_rc_tready == 1'b1) begin
        s_axis_rc_tvalid_rs <= s_axis_rc_tvalid;
        s_axis_rc_tdata_rs  <= s_axis_rc_tdata;
        s_axis_rc_tkeep_rs  <= s_axis_rc_tkeep;
        s_axis_rc_tuser_rs  <= s_axis_rc_tuser;
        s_axis_rc_tlast_rs  <= s_axis_rc_tlast;
      end
    end
  end
     
  assign m_axis_rq_tready_rs = m_axis_rq_tready    | ~m_axis_rq_tvalid;
  assign s_axis_rc_tready    = s_axis_rc_tready_rs | ~s_axis_rc_tvalid_rs;

endmodule
