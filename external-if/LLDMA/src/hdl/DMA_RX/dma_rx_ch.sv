/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`define TRACE_RX

module dma_rx_ch (
  input  logic         user_clk,
  input  logic         reset_n,

// input
  // setting
  input  logic [  2:0] chx_rxch_mode,
  input  logic [  2:0] pkt_max_len_mode,
  input  logic [  9:0] pkt_addr_mask,
  input  logic [ 31:0] pkt_len_mask,
  input  logic [  2:0] ack_addr_aline_mode,
  input  logic         ack_send_mode,
  input  logic [ 63:6] chx_srbuf_addr,
  input  logic [ 31:6] chx_srbuf_size,

  // D2D receive
  input  logic         chx_srbuf_wp_update,
  input  logic [ 31:0] d2d_wp,
  input  logic         d2d_frame_last,

  // DSCQ
  input  logic         chx_dscq_we_enq,
  input  logic         chx_dscq_we_enq_tlast,
  input  logic [ 63:0] dsc_src_addr_enq,
  input  logic [ 31:0] dsc_src_len_enq,
  input  logic [ 15:0] dsc_task_id_enq,
  input  logic         chx_ram_we_pkt_tail_1tc,
  input  logic [  1:0] ram_wt_dscq_entry_1tc,
  input  logic         chx_ram_re_dsc_last_tail,
  input  logic         chx_que_wt_ack,
  `ifdef TRACE_RX
    input  logic       trace_enb,   // TRACE ENB
  `endif

  // packet send
  input  logic         chx_pkt_send_go,
  input  logic [ 25:0] rq_dmar_rd_axis_pkt_num,

  // clear
  input  logic         chx_rxch_enb,
  input  logic         chx_rxch_rd_enb,
  input  logic         chx_rxch_clr_exec,
  input  logic         chx_d2c_pkt_tail,

  // error
  input  logic         reg_dma_rx_err_1wc,
  input  logic         reg_dma_rx_err_eg0_set,
  input  logic         dscq_rd_pe_detect,

// output
  // DSCQ
  output logic [  1:0] chx_dscq_wp,
  output logic [  1:0] chx_dscq_pkt_send_rp,
  output logic [  1:0] chx_dscq_rp,
  output logic [  2:0] chx_dscq_pcnt,
  output logic [  2:0] chx_dscq_ucnt,
  output logic         chx_dscq_full,
  output logic         chx_que_wt_req_pre,
  output logic [  2:0] chx_que_wt_req_cnt,
  output logic [ 31:0] chx_que_wt_task_id_rp_pros,
  `ifdef TRACE_RX
    output logic [ 31:0] chx_trace_dscq_src_len,
    output logic [ 15:0] chx_trace_dscq_task_id_rp_pros,
    output logic [ 25:0] chx_trace_dscq_sp_pkt_num,
    output logic [ 25:0] chx_trace_dscq_sp_pkt_rcv_cnt,
  `endif

  // packet send
  output logic         chx_pkt_send_valid,
  output logic [ 63:0] chx_pkt_send_pkt_addr,
  output logic [ 25:0] chx_pkt_num,
  output logic [  4:0] chx_pkt_sta_cycle,
  output logic [  4:0] chx_pkt_end_cycle,
  output logic [ 24:0] chx_pkt_send_cnt,

  // status
  output logic [ 31:6] chx_srbuf_wp,
  output logic [ 31:6] chx_srbuf_rp,
  output logic [ 31:6] chx_srbuf_inflight_area,
  output logic         chx_d2d_wp_not_update_detect,

  // clear
  output logic         chx_dmar_busy,

  // error
  output logic [ 31:0] chx_set_reg_dma_rx_err,
  output logic         chx_dscq_rd_pe_detect,
  output logic         chx_reg_dma_rx_err_eg0_inj
);

// DSCQ
  logic         chx_dscq_we;
  logic [ 63:0] chx_dsc_src_addr;
  logic [  7:0] chx_dsc_src_addr_ep;
  logic [ 31:0] chx_dsc_src_len;
  logic [  3:0] chx_dsc_src_len_ep;
  logic [ 31:0] chx_dsc_task_id_rp_pros;
  logic [  3:0] chx_dsc_task_id_rp_pros_ep;
  logic [ 63:0] chx_dscq_src_addr[3:0];
  logic [  7:0] chx_dscq_src_addr_ep[3:0];
  logic [ 31:0] chx_dscq_src_len[3:0];
  logic [  3:0] chx_dscq_src_len_ep[3:0];
  logic [ 31:0] chx_dscq_task_id_rp_pros[3:0];
  logic [  3:0] chx_dscq_task_id_rp_pros_ep[3:0];
  logic         chx_dscq_we_1tc;
  logic [  1:0] chx_dscq_wp_1tc;
  logic         chx_dscq_pkt_send_re;
  logic         chx_dscq_pkt_send_re_1tc;
  logic [  1:0] chx_dscq_pkt_send_rp_1tc;
  logic         chx_dscq_re;
  logic         chx_dscq_rd_pe_detect_pre;
  logic         chx_que_wt_req_cnt_up;
  logic [ 31:0] chx_que_wt_dscq_src_len;
  logic [  3:0] chx_que_wt_dscq_src_len_ep;
  logic         chx_que_wt_dscq_src_len_pe;
  logic [  3:0] chx_que_wt_task_id_rp_pros_ep;
  logic         chx_que_wt_task_id_rp_pros_pe;
  logic         chx_pkt_send_go_1tc;
  `ifdef TRACE_RX
    logic [ 24:0] chx_pkt_send_cnt_1tc;
    logic [ 25:0] chx_dscq_sp_pkt_num[3:0];
    logic [ 25:0] chx_dscq_sp_pkt_rcv_cnt[3:0];
  `endif

// packet send
  logic         chx_pkt_send_valid_pre;
  logic [ 63:0] chx_pkt_send_src_addr_pre;
  logic [  7:0] chx_pkt_send_src_addr_ep_pre;
  logic         chx_pkt_send_src_addr_pre_pe;
  logic [ 31:0] chx_pkt_send_src_len_pre;
  logic [  3:0] chx_pkt_send_src_len_ep_pre;
  logic         chx_pkt_send_src_len_pre_pe;
  logic         chx_pkt_no_send_valid;
  logic [ 63:0] chx_pkt_send_src_addr;
  logic [ 31:0] chx_pkt_send_src_len;
  logic [  4:0] chx_pkt_sta_cycle_mc;
  logic [ 25:0] chx_pkt_end_cycle_ptn11;
  logic [ 25:0] chx_dsc_cycle_exc_sta_mc;

  // clear
  logic [ 11:0] chx_pkt_inflight_cnt;
  logic         chx_dmar_busy_mode1;

// dma_rx_ch_gh
  // output
    // DSCQ
  logic         chx_dscq_we_gh;
  logic [ 63:6] chx_dsc_src_addr_gh;
  logic [ 31:6] chx_dsc_src_len_gh;
  logic [ 31:6] chx_dsc_srbuf_rp_pros_gh;

    // error
  logic [  5:0] chx_set_reg_dma_rx_err_gh;

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin

// DSCQ
      chx_dscq_we_1tc                         <= '0;
      chx_dscq_wp                             <= '0;
      chx_dscq_wp_1tc                         <= '0;
      chx_dscq_pkt_send_re_1tc                <= '0;
      chx_dscq_pkt_send_rp                    <= '0;
      chx_dscq_pkt_send_rp_1tc                <= '0;
      chx_dscq_rp                             <= '0;
      chx_dscq_pcnt                           <= '0;
      chx_dscq_ucnt                           <= '0;
      for (int i = 0; i < 4; i++) begin
        chx_dscq_src_addr[i][63:0]            <= '0;
        chx_dscq_src_len[i][31:0]             <= '0;
        chx_dscq_task_id_rp_pros[i][31:0]     <= '0;
        `ifdef TRACE_RX
          chx_dscq_sp_pkt_num[i][25:0]        <= '0;
          chx_dscq_sp_pkt_rcv_cnt[i][25:0]    <= '0;
        `endif
      end
      chx_dscq_rd_pe_detect                   <= '0;
      chx_que_wt_req_cnt                      <= '0;
      chx_pkt_send_go_1tc                     <= '0;
      `ifdef TRACE_RX
        chx_pkt_send_cnt_1tc                  <= '0;
      `endif

// packet send
      chx_pkt_send_valid_pre                  <= '0;
      chx_pkt_send_src_addr_pre               <= '0;
      chx_pkt_send_src_addr_ep_pre            <= '0;
      chx_pkt_send_src_len_pre                <= '0;
      chx_pkt_send_src_len_ep_pre             <= '0;
      chx_pkt_send_valid                      <= '0;
      chx_pkt_no_send_valid                   <= '0;
      chx_pkt_send_src_addr                   <= '0;
      chx_pkt_send_src_len                    <= '0;
      chx_pkt_send_pkt_addr                   <= '0;
      chx_pkt_num                             <= '0;
      chx_pkt_sta_cycle_mc                    <= '0;
      chx_pkt_sta_cycle                       <= '0;
      chx_pkt_end_cycle                       <= '0;
      chx_pkt_send_cnt                        <= '0;
      chx_dsc_cycle_exc_sta_mc                <= '0;

// clear
      chx_pkt_inflight_cnt                    <= '0;
      chx_dmar_busy                           <= '0;

// error
      chx_reg_dma_rx_err_eg0_inj              <= '0;
      chx_set_reg_dma_rx_err                  <= '0;

    end else begin

// DSCQ
      if (chx_rxch_clr_exec == 1'b1) begin
        chx_dscq_wp                           <= '0;
        chx_dscq_pkt_send_rp                  <= '0;
        chx_dscq_rp                           <= '0;
        chx_dscq_pcnt                         <= '0;
        chx_dscq_ucnt                         <= '0;
        chx_que_wt_req_cnt                    <= '0;
        chx_pkt_send_cnt                      <= '0;
      end else begin
        if (chx_dscq_we == 1'b1) begin
          for (int i = 0; i < 4; i++) begin
            if (chx_dscq_wp == i) begin
              chx_dscq_src_addr[i][63:0]          <= chx_dsc_src_addr;
              chx_dscq_src_addr_ep[i][7:0]        <= chx_dsc_src_addr_ep;
              chx_dscq_src_len[i][31:0]           <= chx_dsc_src_len;
              chx_dscq_src_len_ep[i][3:0]         <= chx_dsc_src_len_ep;
              chx_dscq_task_id_rp_pros[i][31:0]   <= chx_dsc_task_id_rp_pros;
              chx_dscq_task_id_rp_pros_ep[i][3:0] <= chx_dsc_task_id_rp_pros_ep;
              if ((chx_set_reg_dma_rx_err[1] == 1'b0) && (((chx_dscq_re == 1'b1) && (chx_dscq_rp == i)) 
                || (chx_dscq_ucnt == 3'h4) || ((chx_dscq_we_enq == 1'b1) && (chx_dscq_we_enq_tlast == 1'b0)))) begin
                chx_set_reg_dma_rx_err[1] <= 1'b1; // reg_dma_rx_err_chx_dscq_wt
              end
            end
          end
          chx_dscq_wp <= (chx_dscq_wp + 2'h1);
        end
        chx_dscq_pkt_send_rp <= (chx_dscq_pkt_send_rp + {1'b0,chx_dscq_pkt_send_re});
        chx_dscq_pcnt <= (chx_dscq_pcnt - {2'h0,chx_dscq_pkt_send_re} + {2'h0,chx_dscq_we});
        chx_dscq_rp <= (chx_dscq_rp + {1'b0,chx_dscq_re});
        chx_dscq_ucnt <= (chx_dscq_ucnt - {2'h0,chx_dscq_re} + {2'h0,chx_dscq_we});
        if ((chx_que_wt_req_cnt_up == 1'b1) && (chx_que_wt_ack == 1'b0)) begin
          chx_que_wt_req_cnt <= (chx_que_wt_req_cnt + 3'h1);
        end else if ((chx_que_wt_req_cnt_up == 1'b0) && (chx_que_wt_ack == 1'b1)) begin
          chx_que_wt_req_cnt <= (chx_que_wt_req_cnt - 3'h1);
        end
      end
      chx_dscq_we_1tc <= chx_dscq_we;
      chx_dscq_wp_1tc <= chx_dscq_wp;
      chx_dscq_pkt_send_re_1tc <= chx_dscq_pkt_send_re;
      chx_dscq_pkt_send_rp_1tc <= chx_dscq_pkt_send_rp;
      if (chx_dscq_we_1tc == 1'b1) begin
        for (int i = 0; i < 4; i++) begin
          if (chx_dscq_wp_1tc == i) begin
            if ((chx_set_reg_dma_rx_err[1] == 1'b0) && ((chx_dscq_pkt_send_re_1tc == 1'b1) && (chx_dscq_pkt_send_rp_1tc == i))) begin
              chx_set_reg_dma_rx_err[1] <= 1'b1; // reg_dma_rx_err_chx_dscq_wt
            end
          end
        end
      end
      if ((chx_set_reg_dma_rx_err[2] == 1'b0) && (chx_dscq_pcnt < {2'h0,chx_dscq_pkt_send_re})) begin
        chx_set_reg_dma_rx_err[2] <= 1'b1; // reg_dma_rx_err_chx_dscq_pkt_send_rd
      end
      if ((chx_set_reg_dma_rx_err[3] == 1'b0) && (chx_dscq_ucnt < {2'h0,chx_dscq_re})) begin
        chx_set_reg_dma_rx_err[3] <= 1'b1; // reg_dma_rx_err_chx_dscq_rd
      end
      if ((chx_set_reg_dma_rx_err[4] == 1'b0) && (chx_dscq_pcnt > chx_dscq_ucnt)) begin
        chx_set_reg_dma_rx_err[4] <= 1'b1; // reg_dma_rx_err_chx_dscq_pcnt_ovfl
      end
      if ((chx_set_reg_dma_rx_err[14] == 1'b0) && (chx_que_wt_req_cnt == 3'h0) && (chx_que_wt_ack == 1'b1)) begin
        chx_set_reg_dma_rx_err[14] <= 1'b1; // reg_dma_rx_err_chx_que_wt_req_cnt_udfl
      end
      if ((chx_set_reg_dma_rx_err[21] == 1'b0) && ((chx_pkt_send_valid_pre == 1'b1) && ((chx_pkt_send_src_addr_pre_pe == 1'b1) || (chx_pkt_send_src_len_pre_pe == 1'b1))
        || ((chx_que_wt_ack == 1'b1) && ((chx_que_wt_dscq_src_len_pe == 1'b1) || (chx_que_wt_task_id_rp_pros_pe == 1'b1))))) begin
        chx_set_reg_dma_rx_err[21] <= 1'b1; // reg_dma_rx_err_chx_dscq_rd_pe
        chx_dscq_rd_pe_detect <= 1'b1;
      end
      if (reg_dma_rx_err_eg0_set == 1'b0) begin
        chx_reg_dma_rx_err_eg0_inj <= 1'b0;
      end else if ((chx_reg_dma_rx_err_eg0_inj == 1'b0) && (chx_dscq_we == 1'b1)) begin
        chx_reg_dma_rx_err_eg0_inj <= 1'b1;
      end
      chx_pkt_send_go_1tc <= chx_pkt_send_go;
      `ifdef TRACE_RX
        chx_pkt_send_cnt_1tc <= chx_pkt_send_cnt;
        if (trace_enb == 1'b1) begin
          if ((chx_pkt_send_go_1tc == 1'b1) && (chx_pkt_send_cnt_1tc == 25'h0)) begin
            chx_dscq_sp_pkt_num[chx_dscq_pkt_send_rp_1tc][25:0] <= rq_dmar_rd_axis_pkt_num;
            chx_dscq_sp_pkt_rcv_cnt[chx_dscq_pkt_send_rp_1tc][25:0] <= 26'h0;
          end
          if (chx_ram_we_pkt_tail_1tc == 1'b1) begin
            chx_dscq_sp_pkt_rcv_cnt[ram_wt_dscq_entry_1tc][25:0] <= (chx_dscq_sp_pkt_rcv_cnt[ram_wt_dscq_entry_1tc][25:0] + 26'h1);
          end
        end
      `endif

// packet send
      chx_pkt_send_valid_pre <= (chx_rxch_rd_enb & ~chx_rxch_clr_exec & (chx_dscq_pcnt > 0 ?1:0) & ~chx_dscq_pkt_send_re & ~chx_dscq_rd_pe_detect_pre & ~dscq_rd_pe_detect);
      chx_pkt_send_src_addr_pre <= chx_dscq_src_addr[chx_dscq_pkt_send_rp][63:0];
      chx_pkt_send_src_addr_ep_pre <= chx_dscq_src_addr_ep[chx_dscq_pkt_send_rp][7:0];
      chx_pkt_send_src_len_pre <= chx_dscq_src_len[chx_dscq_pkt_send_rp][31:0];
      chx_pkt_send_src_len_ep_pre <= chx_dscq_src_len_ep[chx_dscq_pkt_send_rp][3:0];
      chx_pkt_send_valid <= (chx_rxch_rd_enb & ~chx_rxch_clr_exec & chx_pkt_send_valid_pre & (chx_pkt_send_src_len_pre > 0 ?1:0) & ~chx_dscq_pkt_send_re & ~chx_dscq_rd_pe_detect_pre & ~dscq_rd_pe_detect);
      chx_pkt_no_send_valid <= (~chx_rxch_clr_exec & chx_pkt_send_valid_pre & (chx_pkt_send_src_len_pre == 32'h0 ?1:0) & ~chx_pkt_no_send_valid & ~chx_dscq_rd_pe_detect_pre & ~dscq_rd_pe_detect);
      chx_pkt_send_src_addr <= chx_pkt_send_src_addr_pre;
      chx_pkt_send_src_len <= chx_pkt_send_src_len_pre;   // unuse, for debug
      chx_pkt_sta_cycle_mc <= ((~chx_dscq_src_addr[chx_dscq_pkt_send_rp][9:6] & pkt_addr_mask[9:6]) + 5'h01);
      chx_dsc_cycle_exc_sta_mc <= (chx_dscq_src_len[chx_dscq_pkt_send_rp][31:6] - {22'h0,(~chx_dscq_src_addr[chx_dscq_pkt_send_rp][9:6] & pkt_addr_mask[9:6])} - 26'h1);
      if (chx_pkt_send_valid_pre == 1'b1) begin
        if ({22'h0,chx_pkt_sta_cycle_mc} >= chx_pkt_send_src_len_pre[31:6]) begin
          chx_pkt_num <= 26'h1;
          chx_pkt_sta_cycle <= chx_pkt_send_src_len_pre[10:6];
          chx_pkt_end_cycle <= chx_pkt_send_src_len_pre[10:6];
        end else begin
          chx_pkt_sta_cycle <= ({1'b0,~chx_pkt_send_src_addr_pre[9:6] & pkt_addr_mask[9:6]} + 5'h01);
          if ((chx_pkt_send_src_addr_pre[9:6] & pkt_addr_mask[9:6]) == 4'h0) begin
            if ((chx_pkt_send_src_len_pre[9:6] & pkt_len_mask[9:6]) == 4'h0) begin
              chx_pkt_num <= (chx_pkt_send_src_len_pre[31:6] >> pkt_max_len_mode);
              chx_pkt_end_cycle <= (5'h01 << pkt_max_len_mode);
            end else begin
              chx_pkt_num <= ((chx_pkt_send_src_len_pre[31:6] >> pkt_max_len_mode) + 26'h1);
              chx_pkt_end_cycle <= {1'b0,(chx_pkt_send_src_len_pre[9:6] & pkt_len_mask[9:6])};
            end
          end else begin
            if ((chx_dsc_cycle_exc_sta_mc & pkt_len_mask[31:6]) == 26'h0) begin
              chx_pkt_num <= ((chx_dsc_cycle_exc_sta_mc >> pkt_max_len_mode) + 26'h1);
              chx_pkt_end_cycle <= (5'h01 << pkt_max_len_mode);
            end else begin
              chx_pkt_num <= ((chx_dsc_cycle_exc_sta_mc >> pkt_max_len_mode) + 26'h2);
              chx_pkt_end_cycle <= chx_pkt_end_cycle_ptn11[4:0];
            end
          end
        end
      end
      if (chx_pkt_send_go_1tc == 1'b1) begin
        if (({1'b0,chx_pkt_send_cnt} + 26'h1) < chx_pkt_num) begin
          chx_pkt_send_cnt <= (chx_pkt_send_cnt + 25'h1);
          chx_pkt_send_pkt_addr <= {({chx_pkt_send_pkt_addr[63:10],chx_pkt_send_pkt_addr[9:6] & ~pkt_addr_mask[9:6]} + (58'h1 << pkt_max_len_mode)),6'h00};
        end else begin
          chx_pkt_send_cnt <= 25'h0;
        end
      end else if (chx_pkt_send_cnt == 25'h0) begin
        chx_pkt_send_pkt_addr <= chx_pkt_send_src_addr_pre;
      end

// clear
      if ((chx_pkt_send_go_1tc == 1'b1) && (chx_d2c_pkt_tail == 1'b0)) begin
        chx_pkt_inflight_cnt <= (chx_pkt_inflight_cnt + 12'h1);
      end if ((chx_pkt_send_go_1tc == 1'b0) && (chx_d2c_pkt_tail == 1'b1)) begin
        chx_pkt_inflight_cnt <= (chx_pkt_inflight_cnt - 12'h1);
      end
      chx_dmar_busy <= ((|chx_dscq_pcnt) | (|chx_dscq_ucnt) | (|chx_que_wt_req_cnt) | (|chx_pkt_inflight_cnt) | chx_dmar_busy_mode1);

// error
      for (int i = 0; i < 6; i++) begin
        if ((chx_set_reg_dma_rx_err[i+15] == 1'b0) && (chx_set_reg_dma_rx_err_gh[i] == 1'b1) && (reg_dma_rx_err_1wc == 1'b0)) begin
          chx_set_reg_dma_rx_err[i+15] <= 1'b1;
        end
      end
      for (int i = 0; i < 32; i++) begin
        if ((chx_set_reg_dma_rx_err[i] == 1'b1) && (reg_dma_rx_err_1wc == 1'b1)) begin
          chx_set_reg_dma_rx_err[i] <= 1'b0;
        end
      end

    end
  end

  always_comb begin
    if (chx_dscq_we_enq == 1'b1) begin
      chx_dscq_we             = 1'b1;
      chx_dsc_src_addr        = {dsc_src_addr_enq[63:6],6'h00};
      chx_dsc_src_len         = {dsc_src_len_enq[31:6],6'h00};
      chx_dsc_task_id_rp_pros = {16'h0,dsc_task_id_enq};
    end else if (chx_dscq_we_gh == 1'b1) begin
      chx_dscq_we             = 1'b1;
      chx_dsc_src_addr        = {chx_dsc_src_addr_gh,6'h00};
      chx_dsc_src_len         = {chx_dsc_src_len_gh,6'h00};
      chx_dsc_task_id_rp_pros = {chx_dsc_srbuf_rp_pros_gh,6'h00};
    end else begin
      chx_dscq_we             = 1'b0;
      chx_dsc_src_addr        = {chx_dsc_src_addr_gh,6'h00};
      chx_dsc_src_len         = {chx_dsc_src_len_gh,6'h00};
      chx_dsc_task_id_rp_pros = {chx_dsc_srbuf_rp_pros_gh,6'h00};
    end
    chx_pkt_send_src_addr_pre_pe    = 1'b0;
    chx_pkt_send_src_len_pre_pe     = 1'b0;
    chx_que_wt_dscq_src_len_pe      = 1'b0;
    chx_que_wt_task_id_rp_pros_pe   = 1'b0;
    for (int i = 0; i < 8; i++) begin
      if (i == 0) begin
        chx_dsc_src_addr_ep[i]      = reg_dma_rx_err_eg0_set ^ (^chx_dsc_src_addr[i*8+:8]);
      end else begin
        chx_dsc_src_addr_ep[i]      = ^chx_dsc_src_addr[i*8+:8];
      end
      chx_pkt_send_src_addr_pre_pe  = chx_pkt_send_src_addr_pre_pe  | ((^chx_pkt_send_src_addr_pre[i*8+:8])  ^ chx_pkt_send_src_addr_ep_pre[i]);
    end
    for (int i = 0; i < 4; i++) begin
      chx_dsc_src_len_ep[i]         = ^chx_dsc_src_len[i*8+:8];
      chx_dsc_task_id_rp_pros_ep[i] = ^chx_dsc_task_id_rp_pros[i*8+:8];
      chx_pkt_send_src_len_pre_pe   = chx_pkt_send_src_len_pre_pe   | ((^chx_pkt_send_src_len_pre[i*8+:8])   ^ chx_pkt_send_src_len_ep_pre[i]);
      chx_que_wt_dscq_src_len_pe    = chx_que_wt_dscq_src_len_pe    | ((^chx_que_wt_dscq_src_len[i*8+:8])    ^ chx_que_wt_dscq_src_len_ep[i]);
      chx_que_wt_task_id_rp_pros_pe = chx_que_wt_task_id_rp_pros_pe | ((^chx_que_wt_task_id_rp_pros[i*8+:8]) ^ chx_que_wt_task_id_rp_pros_ep[i]);
    end
    if ((chx_set_reg_dma_rx_err[21] == 1'b0) && ((chx_pkt_send_valid_pre == 1'b1) && ((chx_pkt_send_src_addr_pre_pe == 1'b1) || (chx_pkt_send_src_len_pre_pe == 1'b1))
      || ((chx_que_wt_ack == 1'b1) && ((chx_que_wt_dscq_src_len_pe == 1'b1) || (chx_que_wt_task_id_rp_pros_pe == 1'b1))))) begin
      chx_dscq_rd_pe_detect_pre     = 1'b1;
    end else begin
      chx_dscq_rd_pe_detect_pre     = 1'b0;
    end
  end

  assign chx_pkt_end_cycle_ptn11          = (chx_pkt_send_src_len_pre[31:6] - {22'h0,(~chx_pkt_send_src_addr_pre[9:6] & pkt_addr_mask[9:6])} - 26'h1) & pkt_len_mask[31:6];
  assign chx_dscq_full                    = chx_dscq_ucnt[2];
  assign chx_dscq_pkt_send_re             = (chx_pkt_send_go & ({1'b0,chx_pkt_send_cnt} + 26'h1 == chx_pkt_num ?1:0)) | chx_pkt_no_send_valid;
  assign chx_dscq_re                      = chx_que_wt_ack;
  assign chx_que_wt_req_pre               = (chx_que_wt_req_cnt > 3'h0 ?1:0);
  assign chx_que_wt_req_cnt_up            = chx_ram_re_dsc_last_tail | chx_pkt_no_send_valid;
  assign chx_que_wt_dscq_src_len          = chx_dscq_src_len[chx_dscq_rp][31:0];
  assign chx_que_wt_dscq_src_len_ep       = chx_dscq_src_len_ep[chx_dscq_rp][3:0];
  assign chx_que_wt_task_id_rp_pros       = chx_dscq_task_id_rp_pros[chx_dscq_rp][31:0];
  assign chx_que_wt_task_id_rp_pros_ep    = chx_dscq_task_id_rp_pros_ep[chx_dscq_rp][3:0];
  `ifdef TRACE_RX
    assign chx_trace_dscq_src_len         = chx_dscq_src_len[ram_wt_dscq_entry_1tc][31:0];
    assign chx_trace_dscq_task_id_rp_pros = chx_dscq_task_id_rp_pros[ram_wt_dscq_entry_1tc][15:0];
    assign chx_trace_dscq_sp_pkt_num      = chx_dscq_sp_pkt_num[ram_wt_dscq_entry_1tc][25:0];
    assign chx_trace_dscq_sp_pkt_rcv_cnt  = chx_dscq_sp_pkt_rcv_cnt[ram_wt_dscq_entry_1tc][25:0];
  `endif

// dma_rx_ch_gh
  dma_rx_ch_gh DMA_RX_CH_GH (
  // input
    .user_clk(user_clk),
    .reset_n(reset_n),
    // setting
    .chx_rxch_mode(chx_rxch_mode),
    .ack_addr_aline_mode(ack_addr_aline_mode),
    .ack_send_mode(ack_send_mode),
    .chx_srbuf_addr(chx_srbuf_addr),
    .chx_srbuf_size(chx_srbuf_size),
    // D2D receive
    .chx_srbuf_wp_update(chx_srbuf_wp_update),
    .d2d_wp(d2d_wp),
    .d2d_frame_last(d2d_frame_last),
    // DSCQ
    .chx_dscq_full(chx_dscq_full),
    .chx_que_wt_ack(chx_que_wt_ack),
    .chx_que_wt_dscq_src_len(chx_que_wt_dscq_src_len[31:6]),
    .chx_que_wt_task_id_rp_pros(chx_que_wt_task_id_rp_pros[31:6]),
    // clear
    .chx_rxch_enb(chx_rxch_enb),
    .chx_rxch_clr_exec(chx_rxch_clr_exec),
    // error
    .reg_dma_rx_err_1wc(reg_dma_rx_err_1wc),
  // output
    // DSCQ
    .chx_dscq_we_gh(chx_dscq_we_gh),
    .chx_dsc_src_addr_gh(chx_dsc_src_addr_gh),
    .chx_dsc_src_len_gh(chx_dsc_src_len_gh),
    .chx_dsc_srbuf_rp_pros_gh(chx_dsc_srbuf_rp_pros_gh),
    // status
    .chx_srbuf_wp(chx_srbuf_wp),
    .chx_srbuf_rp(chx_srbuf_rp),
    .chx_srbuf_inflight_area(chx_srbuf_inflight_area),
    .chx_d2d_wp_not_update_detect(chx_d2d_wp_not_update_detect),
    // clear
    .chx_dmar_busy_mode1(chx_dmar_busy_mode1),
    // error
    .chx_set_reg_dma_rx_err_gh(chx_set_reg_dma_rx_err_gh)
  );

endmodule
