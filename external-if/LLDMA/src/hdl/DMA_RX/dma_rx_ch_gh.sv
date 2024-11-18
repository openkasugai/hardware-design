/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module dma_rx_ch_gh (
  input  logic         user_clk,
  input  logic         reset_n,

// input
  // setting
  input  logic [  2:0] chx_rxch_mode,
  input  logic [  2:0] ack_addr_aline_mode,
  input  logic         ack_send_mode,
  input  logic [ 63:6] chx_srbuf_addr,
  input  logic [ 31:6] chx_srbuf_size,

  // D2D receive
  input  logic         chx_srbuf_wp_update,
  input  logic [ 31:0] d2d_wp,
  input  logic         d2d_frame_last,

  // DSCQ
  input  logic         chx_dscq_full,
  input  logic         chx_que_wt_ack,
  input  logic [ 31:6] chx_que_wt_dscq_src_len,
  input  logic [ 31:6] chx_que_wt_task_id_rp_pros,

  // clear
  input  logic         chx_rxch_enb,
  input  logic         chx_rxch_clr_exec,

  // error
  input  logic         reg_dma_rx_err_1wc,

// output
  // DSCQ
  output logic         chx_dscq_we_gh,
  output logic [ 63:6] chx_dsc_src_addr_gh,
  output logic [ 31:6] chx_dsc_src_len_gh,
  output logic [ 31:6] chx_dsc_srbuf_rp_pros_gh,

  // status
  output logic [ 31:6] chx_srbuf_wp,
  output logic [ 31:6] chx_srbuf_rp,
  output logic [ 31:6] chx_srbuf_inflight_area,
  output logic         chx_d2d_wp_not_update_detect,

  // clear
  output logic         chx_dmar_busy_mode1,

  // error
  output logic [  5:0] chx_set_reg_dma_rx_err_gh
);

  logic         chx_srbuf_frame_last;
  logic         chx_srbuf_wp_update_forward;
  logic         chx_srbuf_wp_update_reverse;
  logic         chx_srbuf_rp_pros_update_hope;
  logic         chx_srbuf_rp_pros_update;
  logic [ 31:6] chx_srbuf_rp_pros;
  logic [ 31:6] chx_srbuf_rp_pros_plus_sub;
  logic [ 31:6] chx_srbuf_rp_pros_mask;
  logic         chx_srbuf_data_size_wp_update;
  logic         chx_srbuf_data_size_rp_update;
  logic         chx_srbuf_data_size_wp;
  logic         chx_srbuf_data_size_rp;
  logic [ 31:6] chx_srbuf_data_size0;
  logic [ 31:6] chx_srbuf_data_size1;
  logic         chx_srbuf_data_size0_udfl_flg;
  logic         chx_srbuf_data_size1_udfl_flg;
  logic         chx_srbuf_data_size_valid;
  logic [ 31:6] chx_srbuf_data_size_current;
  logic [ 31:6] chx_srbuf_data_size_add_1st;
  logic [ 31:6] chx_srbuf_data_size_add_2nd;
  logic [ 31:6] chx_srbuf_data_size_sub_hope_pre_aline;
  logic [ 31:6] chx_srbuf_data_size_sub_hope;
  logic [ 31:6] chx_srbuf_data_size_sub;
  logic [ 31:6] chx_srbuf_data_size_to_area_last;
  logic         chx_srbuf_inflight_area_udfl_flg;
  logic         chx_dscq_wt_req_gh;
  logic [ 31:6] chx_que_wt_dscq_src_len_1tc;

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      chx_srbuf_wp                           <= '0;
      chx_srbuf_frame_last                   <= '0;
      chx_srbuf_rp_pros_update_hope          <= '0;
      chx_srbuf_rp_pros_update               <= '0;
      chx_srbuf_rp_pros                      <= '0;
      chx_srbuf_rp                           <= '0;
      chx_srbuf_data_size_wp_update          <= '0;
      chx_srbuf_data_size_wp                 <= '0;
      chx_srbuf_data_size_rp                 <= '0;
      chx_srbuf_data_size0                   <= '0;
      chx_srbuf_data_size1                   <= '0;
      chx_srbuf_data_size0_udfl_flg          <= '0;
      chx_srbuf_data_size1_udfl_flg          <= '0;
      chx_srbuf_data_size_add_1st            <= '0;
      chx_srbuf_data_size_add_2nd            <= '0;
      chx_srbuf_data_size_sub_hope           <= '0;
      chx_srbuf_data_size_sub_hope_pre_aline <= '0;
      chx_srbuf_data_size_sub                <= '0;
      chx_srbuf_data_size_to_area_last       <= '0;
      chx_srbuf_inflight_area                <= '0;
      chx_dscq_wt_req_gh                     <= '0;
      chx_dsc_src_addr_gh                    <= '0;
      chx_dsc_src_len_gh                     <= '0;
      chx_d2d_wp_not_update_detect           <= '0;
      chx_que_wt_dscq_src_len_1tc            <= '0;
      chx_set_reg_dma_rx_err_gh              <= '0;
    end else begin
      if (chx_rxch_clr_exec == 1'b1) begin
        chx_srbuf_wp                         <= '0;
        chx_srbuf_frame_last                 <= '0;
        chx_srbuf_rp_pros                    <= '0;
        chx_srbuf_rp                         <= '0;
        chx_srbuf_data_size_wp               <= '0;
        chx_srbuf_data_size_rp               <= '0;
        chx_srbuf_data_size0                 <= '0;
        chx_srbuf_data_size1                 <= '0;
        chx_srbuf_data_size0_udfl_flg        <= '0;
        chx_srbuf_data_size1_udfl_flg        <= '0;
        chx_srbuf_inflight_area              <= '0;
        chx_srbuf_inflight_area_udfl_flg     <= '0;
      end else begin
        if (chx_srbuf_wp_update == 1'b1) begin
          chx_srbuf_wp <= d2d_wp[31:6];
          chx_srbuf_frame_last <= d2d_frame_last;
          if (d2d_wp[31:6] == chx_srbuf_wp) begin
            chx_d2d_wp_not_update_detect <= 1'b1;
          end
          if ((chx_set_reg_dma_rx_err_gh[0] == 1'b0) && ((d2d_wp[31:6] >= chx_srbuf_size) || (d2d_wp[5:0] > 6'h00))) begin
            chx_set_reg_dma_rx_err_gh[0] <= 1'b1; // reg_dma_rx_err_chx_graph_host_wp
          end
        end
        if (chx_srbuf_rp_pros_update == 1'b1) begin
          if (chx_srbuf_size > chx_srbuf_rp_pros + chx_srbuf_data_size_sub) begin
            chx_srbuf_rp_pros <= (chx_srbuf_rp_pros + chx_srbuf_data_size_sub);
          end else if (chx_srbuf_size == chx_srbuf_rp_pros + chx_srbuf_data_size_sub) begin
            chx_srbuf_rp_pros <= 26'h0;
          end else if (chx_set_reg_dma_rx_err_gh[1] == 1'b0) begin
            chx_set_reg_dma_rx_err_gh[1] <= 1'b1; // reg_dma_rx_err_chx_graph_host_rp
          end
        end
        if ((chx_rxch_mode == 3'h1) && (chx_que_wt_ack == 1'b1)) begin
          chx_srbuf_rp <= chx_que_wt_task_id_rp_pros;
          chx_que_wt_dscq_src_len_1tc <= chx_que_wt_dscq_src_len;
        end else begin
          chx_que_wt_dscq_src_len_1tc <= '0;
        end
        chx_srbuf_inflight_area <= (chx_srbuf_inflight_area + chx_srbuf_data_size_add_1st + chx_srbuf_data_size_add_2nd - chx_que_wt_dscq_src_len_1tc);
        if (chx_srbuf_inflight_area < chx_que_wt_dscq_src_len_1tc) begin
          chx_srbuf_inflight_area_udfl_flg <= 1'b1;
        end else begin
          chx_srbuf_inflight_area_udfl_flg <= 1'b0;
        end
        if (chx_srbuf_data_size_wp_update == 1'b1) begin
          chx_srbuf_data_size_wp <= ~chx_srbuf_data_size_wp;
        end
        if (chx_srbuf_data_size_rp_update == 1'b1) begin
          chx_srbuf_data_size_rp <= ~chx_srbuf_data_size_rp;
        end
        if (chx_srbuf_data_size_wp == 1'b0) begin
          if (chx_srbuf_data_size_rp == 1'b0) begin
            chx_srbuf_data_size0 <= (chx_srbuf_data_size0 + chx_srbuf_data_size_add_1st - chx_srbuf_data_size_sub);
            chx_srbuf_data_size1 <= (chx_srbuf_data_size1 + chx_srbuf_data_size_add_2nd);
            if (chx_srbuf_data_size0 < chx_srbuf_data_size_sub) begin
              chx_srbuf_data_size0_udfl_flg <= 1'b1;
            end else begin
              chx_srbuf_data_size0_udfl_flg <= 1'b0;
            end
          end else begin
            chx_srbuf_data_size0 <= (chx_srbuf_data_size0 + chx_srbuf_data_size_add_1st);
            chx_srbuf_data_size1 <= (chx_srbuf_data_size1 + chx_srbuf_data_size_add_2nd - chx_srbuf_data_size_sub);
            if (chx_srbuf_data_size1 < chx_srbuf_data_size_sub) begin
              chx_srbuf_data_size1_udfl_flg <= 1'b1;
            end else begin
              chx_srbuf_data_size1_udfl_flg <= 1'b0;
            end
          end
        end else begin
          if (chx_srbuf_data_size_rp == 1'b0) begin
            chx_srbuf_data_size0 <= (chx_srbuf_data_size0 + chx_srbuf_data_size_add_2nd - chx_srbuf_data_size_sub);
            chx_srbuf_data_size1 <= (chx_srbuf_data_size1 + chx_srbuf_data_size_add_1st);
            if (chx_srbuf_data_size0 < chx_srbuf_data_size_sub) begin
              chx_srbuf_data_size0_udfl_flg <= 1'b1;
            end else begin
              chx_srbuf_data_size0_udfl_flg <= 1'b0;
            end
          end else begin
            chx_srbuf_data_size0 <= (chx_srbuf_data_size0 + chx_srbuf_data_size_add_2nd);
            chx_srbuf_data_size1 <= (chx_srbuf_data_size1 + chx_srbuf_data_size_add_1st - chx_srbuf_data_size_sub);
            if (chx_srbuf_data_size1 < chx_srbuf_data_size_sub) begin
              chx_srbuf_data_size1_udfl_flg <= 1'b1;
            end else begin
              chx_srbuf_data_size1_udfl_flg <= 1'b0;
            end
          end
        end
      end
      if (chx_srbuf_wp_update_forward == 1'b1) begin
        chx_srbuf_data_size_add_1st <= (d2d_wp[31:6] - chx_srbuf_wp);
        chx_srbuf_data_size_add_2nd <= 26'h0;
      end else if (chx_srbuf_wp_update_reverse == 1'b1) begin
        chx_srbuf_data_size_add_1st <= (chx_srbuf_size - chx_srbuf_wp);
        chx_srbuf_data_size_add_2nd <= d2d_wp[31:6];
      end else begin
        chx_srbuf_data_size_add_1st <= 26'h0;
        chx_srbuf_data_size_add_2nd <= 26'h0;
      end
      chx_srbuf_data_size_wp_update <= chx_srbuf_wp_update_reverse;
      if ((chx_rxch_mode == 3'h1) && (chx_srbuf_rp_pros == 26'h0) && (chx_srbuf_size == chx_srbuf_data_size_sub_hope)) begin
        chx_srbuf_data_size_sub <= (chx_srbuf_data_size_sub_hope >> 1);
      end else begin
        chx_srbuf_data_size_sub <= chx_srbuf_data_size_sub_hope;
      end
      chx_srbuf_data_size_sub_hope_pre_aline <= ((~(chx_srbuf_addr[31:6] + chx_srbuf_rp_pros) & chx_srbuf_rp_pros_mask) + 26'h1);
      chx_srbuf_data_size_to_area_last <= (chx_srbuf_size - chx_srbuf_rp_pros);
      if ((chx_srbuf_data_size_valid == 1'b1)) begin
        if ((chx_srbuf_data_size_current >= chx_srbuf_data_size_sub_hope_pre_aline)) begin
          chx_srbuf_rp_pros_update_hope <= 1'b1;
          chx_srbuf_data_size_sub_hope <= chx_srbuf_data_size_sub_hope_pre_aline;
        end else if ((ack_send_mode == 1'b1) ||(chx_srbuf_frame_last == 1'b1) || (chx_srbuf_data_size_current == chx_srbuf_data_size_to_area_last)) begin
          chx_srbuf_rp_pros_update_hope <= 1'b1;
          chx_srbuf_data_size_sub_hope <= chx_srbuf_data_size_current;
        end else begin
          chx_srbuf_rp_pros_update_hope <= 1'b0;
          chx_srbuf_data_size_sub_hope <= 26'h0;
        end
      end else begin
        chx_srbuf_rp_pros_update_hope <= 1'b0;
        chx_srbuf_data_size_sub_hope <= 26'h0;
      end
      chx_srbuf_rp_pros_update <= chx_srbuf_rp_pros_update_hope;
      chx_dscq_wt_req_gh <= chx_srbuf_rp_pros_update;
      chx_dsc_src_addr_gh <= (chx_srbuf_addr + {32'h0,chx_srbuf_rp_pros});
      chx_dsc_src_len_gh <= chx_srbuf_data_size_sub;
      if ((chx_set_reg_dma_rx_err_gh[2] == 1'b0) && (chx_srbuf_inflight_area_udfl_flg == 1'b0) && (chx_srbuf_inflight_area > chx_srbuf_size)) begin
        chx_set_reg_dma_rx_err_gh[2] <= 1'b1; // reg_dma_rx_err_chx_graph_host_inflight_ovfl
      end
      if ((chx_set_reg_dma_rx_err_gh[3] == 1'b0) && (chx_srbuf_inflight_area_udfl_flg == 1'b1)) begin
        chx_set_reg_dma_rx_err_gh[3] <= 1'b1; // reg_dma_rx_err_chx_graph_host_inflight_udfl
      end
      if ((chx_set_reg_dma_rx_err_gh[4] == 1'b0) && (((chx_srbuf_data_size0_udfl_flg == 1'b0) && (chx_srbuf_data_size0 > chx_srbuf_size)) || ((chx_srbuf_data_size1_udfl_flg == 1'b0) && (chx_srbuf_data_size1 > chx_srbuf_size)))) begin
        chx_set_reg_dma_rx_err_gh[4] <= 1'b1; // reg_dma_rx_err_chx_graph_host_data_size_ovfl
      end
      if ((chx_set_reg_dma_rx_err_gh[5] == 1'b0) && ((chx_srbuf_data_size0_udfl_flg == 1'b1) || (chx_srbuf_data_size1_udfl_flg == 1'b1))) begin
        chx_set_reg_dma_rx_err_gh[5] <= 1'b1; // reg_dma_rx_err_chx_graph_host_data_size_unfl
      end
      for (int i = 0; i < 6; i++) begin
        if ((chx_set_reg_dma_rx_err_gh[i] == 1'b1) && (reg_dma_rx_err_1wc == 1'b1)) begin
          chx_set_reg_dma_rx_err_gh[i] <= 1'b0;
        end
      end
    end
  end

  always_comb begin
    case (ack_addr_aline_mode)
      3'h0    : chx_srbuf_rp_pros_mask = 26'h00F; //   1KB
      3'h1    : chx_srbuf_rp_pros_mask = 26'h01F; //   2KB
      3'h2    : chx_srbuf_rp_pros_mask = 26'h03F; //   4KB
      3'h3    : chx_srbuf_rp_pros_mask = 26'h07F; //   8KB
      3'h4    : chx_srbuf_rp_pros_mask = 26'h0FF; //  16KB
      3'h5    : chx_srbuf_rp_pros_mask = 26'h1FF; //  32KB
      3'h6    : chx_srbuf_rp_pros_mask = 26'h3FF; //  64KB
      3'h7    : chx_srbuf_rp_pros_mask = 26'h7FF; // 128KB
      default : chx_srbuf_rp_pros_mask = 26'h000;
    endcase
    if (chx_srbuf_data_size_rp == 1'b0) begin
      chx_srbuf_data_size_current = chx_srbuf_data_size0;
    end else begin
      chx_srbuf_data_size_current = chx_srbuf_data_size1;
    end
  end

  assign chx_srbuf_wp_update_forward            = chx_srbuf_wp_update & (chx_srbuf_wp < d2d_wp[31:6] ?1:0);
  assign chx_srbuf_wp_update_reverse            = chx_srbuf_wp_update & (chx_srbuf_wp > d2d_wp[31:6] ?1:0);
  assign chx_srbuf_rp_pros_plus_sub             = chx_srbuf_rp_pros + chx_srbuf_data_size_sub;
  assign chx_srbuf_data_size_rp_update          = chx_srbuf_rp_pros_update & (chx_srbuf_size == chx_srbuf_rp_pros_plus_sub ?1:0);
  assign chx_srbuf_data_size_valid              = ~chx_dscq_full & ~chx_dscq_wt_req_gh & ~chx_srbuf_rp_pros_update_hope & ~chx_srbuf_rp_pros_update & (chx_srbuf_data_size_current > 0 ?1:0);
  assign chx_dscq_we_gh                         = chx_rxch_enb & chx_dscq_wt_req_gh;
  assign chx_dsc_srbuf_rp_pros_gh               = chx_srbuf_rp_pros;
  assign chx_dmar_busy_mode1                    = 1'b0;

endmodule
