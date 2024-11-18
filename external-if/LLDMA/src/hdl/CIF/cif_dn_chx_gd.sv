/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module cif_dn_chx_gd #(
  parameter BUF_SIZE  = 4,                     // [KB] / CH
  parameter PTR_WIDTH = $clog2(BUF_SIZE) + 10
)(
  input  logic         user_clk,
  input  logic         reset_n,

// input
  // ACK req receive from CIF_DN / cif_dn_chx
  input  logic         chx_b1_buf_rp_update_gd,
  input  logic [ 32:0] b1_buf_rp_gd,

  // ACK ack receive from DMA_RX / ENQDEQ
  input  logic         chx_que_wt_ack_mode2,

  // clear
  input  logic         rxch_clr_t1_ff,

// output
  // ACK req send to DMA_RX / ENQDEQ
  output logic         chx_que_wt_req_mode2,
  output logic [ 31:0] chx_que_wt_req_ack_rp_mode2,

  // status
  output logic [ 31:0] chx_ack_rp_mode2,

  // clear
  output logic         chx_cifd_busy_mode2
);

  logic                 chx_ack_send_valid;
  logic [PTR_WIDTH-1:0] chx_ack_send_rp_pros;
  logic [PTR_WIDTH-1:0] chx_ack_rp;

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      chx_ack_send_valid       <= '0;
      chx_ack_send_rp_pros     <= '0;
      chx_ack_rp               <= '0;
    end else begin
      if (rxch_clr_t1_ff == 1'b1) begin
        chx_ack_send_valid     <= '0;
        chx_ack_send_rp_pros   <= '0;
        chx_ack_rp             <= '0;
      end else begin
        if (chx_b1_buf_rp_update_gd == 1'b1) begin
          chx_ack_send_valid   <= 1'b1;
          chx_ack_send_rp_pros <= b1_buf_rp_gd[PTR_WIDTH-1:0];
        end else if (chx_que_wt_ack_mode2 == 1'b1) begin
          chx_ack_send_valid   <= 1'b0;
        end
        if (chx_que_wt_ack_mode2 == 1'b1) begin
          chx_ack_rp           <= chx_que_wt_req_ack_rp_mode2[PTR_WIDTH-1:0];
        end
      end
    end
  end

  assign chx_que_wt_req_mode2        = chx_ack_send_valid;
  assign chx_que_wt_req_ack_rp_mode2 = {{(32-PTR_WIDTH){1'b0}},chx_ack_send_rp_pros[PTR_WIDTH-1:6],6'h00};
  assign chx_ack_rp_mode2            = {{(32-PTR_WIDTH){1'b0}},chx_ack_rp};
  assign chx_cifd_busy_mode2         = chx_ack_send_valid;

endmodule
