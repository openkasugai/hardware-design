/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module rs_cmdeve (
  input  logic         ext_clk,
  input  logic         ext_reset_n,

  input  logic         s_axis_cx_transfer_cmd_valid,
  input  logic [ 63:0] s_axis_cx_transfer_cmd_data,
  output logic         s_axis_cx_transfer_cmd_ready,

  output logic         s_axis_cx_transfer_cmd_valid_rs,
  output logic [ 63:0] s_axis_cx_transfer_cmd_data_rs,
  input  logic         s_axis_cx_transfer_cmd_ready_rs,

  output logic         m_axis_cx_transfer_eve_valid,
  output logic [127:0] m_axis_cx_transfer_eve_data,
  input  logic         m_axis_cx_transfer_eve_ready,

  input  logic         m_axis_cx_transfer_eve_valid_rs,
  input  logic [127:0] m_axis_cx_transfer_eve_data_rs,
  output logic         m_axis_cx_transfer_eve_ready_rs
);

  always_ff @(posedge ext_clk or negedge ext_reset_n) begin
    if (ext_reset_n == 1'b0) begin
      s_axis_cx_transfer_cmd_valid_rs   <= '0;
      s_axis_cx_transfer_cmd_data_rs    <= '0;
      m_axis_cx_transfer_eve_valid      <= '0;
      m_axis_cx_transfer_eve_data       <= '0;
    end else begin
      if (s_axis_cx_transfer_cmd_ready == 1'b1) begin
        s_axis_cx_transfer_cmd_valid_rs <= s_axis_cx_transfer_cmd_valid;
        s_axis_cx_transfer_cmd_data_rs  <= s_axis_cx_transfer_cmd_data;
      end
      if (m_axis_cx_transfer_eve_ready_rs == 1'b1) begin
        m_axis_cx_transfer_eve_valid    <= m_axis_cx_transfer_eve_valid_rs;
        m_axis_cx_transfer_eve_data     <= m_axis_cx_transfer_eve_data_rs;
      end
    end
  end
     
  assign s_axis_cx_transfer_cmd_ready    = s_axis_cx_transfer_cmd_ready_rs;
  assign m_axis_cx_transfer_eve_ready_rs = m_axis_cx_transfer_eve_ready    | ~m_axis_cx_transfer_eve_valid;

endmodule
