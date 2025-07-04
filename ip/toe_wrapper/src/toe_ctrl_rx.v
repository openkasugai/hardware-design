/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module toe_ctrl_rx #(
    parameter DW_LOG = 9,
    parameter BURST_BITS = 6,
    parameter CH_NUM_LOG = 4,
    parameter SESSION_NUM_LOG = 6,
    parameter FRAME_MAX = 8,
    parameter MAX_INFLIGHT = 2,
    parameter ACTIVATE_MAGIC = 32'h56544341, // ACTV
    parameter CREDIT_MAGIC = 32'h54445243  // CRDT
    ) (
    input [(1<<DW_LOG)-1:0]                   rx_toe_tdata,
    input [(1<<(DW_LOG-3))-1:0]               rx_toe_tkeep,
    input [SESSION_NUM_LOG-1:0]               rx_toe_tuser,
    input                                     rx_toe_tlast,
    input                                     rx_toe_tvalid,
    output                                    rx_toe_tready,

    output reg [(1<<DW_LOG)-1:0]              rx_tx_tdata,
    output reg [(1<<(DW_LOG-3))-1:0]          rx_tx_tkeep,
    output reg [CH_NUM_LOG-1:0]               rx_tx_tuser,
    output reg                                rx_tx_tlast, // eop
    output reg                                rx_tx_tvalid,
    input                                     rx_tx_tready,

    output [(1<<DW_LOG)-1:0]                  tx_tdata,
    output [(1<<(DW_LOG-3))-1:0]              tx_tkeep,
    output [SESSION_NUM_LOG-1:0]              tx_tuser,
    output [BURST_BITS-1:0]                   tx_burst,
    output [DW_LOG-4:0]                       tx_last_cnts,
    output                                    tx_tlast,
    output                                    tx_tvalid,
    input                                     tx_tready,

    output [(1<<DW_LOG)-1:0]                  rx_out_tdata,
    output [(1<<(DW_LOG-3))-1:0]              rx_out_tkeep,
    output [CH_NUM_LOG-1:0]                   rx_out_tuser,
    output                                    rx_out_tlast, // eop
    output                                    rx_out_eof,
    output                                    rx_out_tvalid,
    input                                     rx_out_tready,

    output [31:0]                             frame_info_out_tdata, // frame size
    output [CH_NUM_LOG-1:0]                   frame_info_out_tuser,
    output                                    frame_info_out_tvalid,
    input                                     frame_info_out_tready,

    input [31:0]                              frame_info_tdata, // frame size
    input [CH_NUM_LOG-1:0]                    frame_info_tuser,
    input                                     frame_info_tvalid,
    output                                    frame_info_tready,

    input [(1<<CH_NUM_LOG)-1:0]               rx_ch_valids,
    input [(1<<CH_NUM_LOG)-1:0]               rx_ch_activates,
    input [(1<<CH_NUM_LOG)-1:0]               rx_ch_actives,
    input [(1<<CH_NUM_LOG)-1:0]               rx_ch_readys,
    input [(SESSION_NUM_LOG<<CH_NUM_LOG)-1:0] rx_ch_session_ids,
    input [(32<<CH_NUM_LOG)-1:0]              rx_ch_frame_sizes,
    input [(16<<CH_NUM_LOG)-1:0]              rx_ch_credit_max,
    input [(16<<CH_NUM_LOG)-1:0]              rx_ch_credit_cur,

    output reg [SESSION_NUM_LOG-1:0]          rx_credit_inc_session_id,
    output reg                                rx_credit_inc,
    output reg [SESSION_NUM_LOG-1:0]          rx_credit_dec_session_id,
    output reg                                rx_credit_dec,

    output [SESSION_NUM_LOG-1:0]              find_ch_session_id,
    output                                    find_ch_valid,
    input [CH_NUM_LOG-1:0]                    find_ch_id,
    input                                     find_ch_id_tx_valid,
    input                                     find_ch_id_rx_valid,
    input                                     find_ch_id_invalid,

    output reg [SESSION_NUM_LOG-1:0]          activate_done_session_id,
    output reg                                activate_done,

    input                                     clk,
    input                                     resetn
    );

   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam DW = 1 << DW_LOG;
   localparam KW_LOG = DW_LOG - 3;
   localparam KW = 1 << KW_LOG;
   localparam FRAME_MAX_LOG = $clog2(FRAME_MAX);
   localparam KDIV = 4;

   reg    sof;
   reg [SESSION_NUM_LOG-1:0] cur_session_id;
   reg                       cur_session_id_valid;
   reg                       cur_session_id_ready;
   always @(posedge clk) begin
      if (~resetn) begin
         sof <= 1'b1;
         cur_session_id_valid <= 1'b0;
         cur_session_id_ready <= 1'b1;
      end else if (rx_toe_tvalid & rx_toe_tready) begin
         if (sof) begin
            cur_session_id <= rx_toe_tuser;
            cur_session_id_valid <= 1'b1;
            cur_session_id_ready <= 1'b0;
         end else begin
            cur_session_id_valid <= 1'b0;
            cur_session_id_ready <= cur_session_id_ready | (find_ch_id_tx_valid | find_ch_id_rx_valid | find_ch_id_invalid);
         end
         sof <= rx_toe_tlast;
      end else begin
         cur_session_id_valid <= 1'b0;
         cur_session_id_ready <= cur_session_id_ready | (find_ch_id_tx_valid | find_ch_id_rx_valid | find_ch_id_invalid);
      end
   end
   assign find_ch_valid = cur_session_id_valid;
   assign find_ch_session_id = cur_session_id;

   wire [CH_NUM-1:0] w_frame_size_valids;
   wire [32*CH_NUM-1:0] w_frame_sizes;
   wire [CH_NUM-1:0]    w_frame_size_consumes;

   wire                      rx_toe_iready;
   wire                      find_ch_iready;
   assign rx_toe_tready = rx_toe_iready & find_ch_iready & cur_session_id_ready;

   wire [DW-1:0]             rx_mid0_data;
   wire [KW-1:0]             rx_mid0_keep;
   wire [(KW_LOG+1)*4-1:0]   rx_mid0_part_pos;
   wire                      rx_mid0_last;
   wire                      rx_mid0_valid;
   wire                      rx_mid0_ready;

   wire [DW-1:0]             rx_mid_data;
   wire [KW-1:0]             rx_mid_keep;
   wire [KW_LOG:0]           rx_mid_pos;
   wire                      rx_mid_last;
   wire                      rx_mid_valid;
   wire                      rx_mid_ready;
   wire [CH_NUM_LOG-1:0]     rx_mid_ch;


   wire [CH_NUM_LOG-1:0]     w_recv_ch;
   wire                      w_rx_ch_valid, w_tx_ch_valid, w_recv_ch_valid, w_recv_ch_ready;

   wire [(KW_LOG+1)*4-1:0]   w_rx_toe_part_pos;
   bit_count #(
       .DIV ( KDIV ),
       .WL ( KW_LOG )
   ) rx_keep_part_sum (
       .idata ( rx_toe_tkeep ),
       .odata ( w_rx_toe_part_pos )
   );

   fifo #(
       .DW ( DW + KW + 1 + 4 * (KW_LOG + 1)),
       .DL ( 6 )
   ) idata_fifo (
       .idata ( {rx_toe_tlast, w_rx_toe_part_pos, rx_toe_tkeep, rx_toe_tdata} ),
       .ivalid ( rx_toe_tvalid && rx_toe_tready ),
       .iready ( rx_toe_iready ),
       .odata ( {rx_mid0_last, rx_mid0_part_pos, rx_mid0_keep, rx_mid0_data} ),
       .ovalid ( rx_mid0_valid ),
       .oready ( rx_mid0_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   wire [KW_LOG:0]         w_rx_mid0_pos;
   bit_count_sum #(
       .DIV ( KDIV ),
       .WL ( KW_LOG ),
       .ORIGIN ( 1 )
   ) rx_keep_sum (
       .idata ( rx_mid0_part_pos ),
       .odata ( w_rx_mid0_pos )
   );

   fifo #(
       .DW ( CH_NUM_LOG + 2 ),
       .DL ( 4 )
   ) channel_fifo (
       .idata ( {find_ch_id_rx_valid, find_ch_id_tx_valid, find_ch_id} ),
       .ivalid ( find_ch_id_rx_valid | find_ch_id_tx_valid | find_ch_id_invalid ),
       .iready ( find_ch_iready ),
       .odata ( {w_rx_ch_valid, w_tx_ch_valid, w_recv_ch} ),
       .ovalid ( w_recv_ch_valid ),
       .oready ( w_recv_ch_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   wire                    rx_mid0_rx_valid;
   wire                    rx_mid0_rx_ready;
   wire [KW-1:0]           rx_mid0_rx_keep;

   axis_buf #(
       .DW ( DW + KW + KW_LOG + 1 + CH_NUM_LOG )
   ) idata_buf (
       .idata ( {w_recv_ch, w_rx_mid0_pos, rx_mid0_rx_keep, rx_mid0_data} ),
       .ilast ( rx_mid0_last ),
       .ivalid ( rx_mid0_rx_valid ),
       .iready ( rx_mid0_rx_ready ),
       .odata ( {rx_mid_ch, rx_mid_pos, rx_mid_keep, rx_mid_data} ),
       .olast ( rx_mid_last ),
       .ovalid ( rx_mid_valid ),
       .oready ( rx_mid_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   always @(posedge clk) begin
      if (~resetn) begin
         rx_tx_tvalid <= 1'b0;
      end else if (~rx_tx_tvalid || rx_tx_tready) begin
         rx_tx_tdata <= rx_mid0_data;
         rx_tx_tkeep <= rx_mid0_keep;
         rx_tx_tlast <= rx_mid0_last;
         rx_tx_tuser <= w_recv_ch;
         rx_tx_tvalid = rx_mid0_valid && w_recv_ch_valid && w_tx_ch_valid;
      end
   end

   assign w_recv_ch_ready = rx_mid0_valid & rx_mid0_ready & rx_mid0_last;
   assign rx_mid0_rx_keep = rx_mid0_last ? rx_mid0_keep : {KW{1'b1}};
   assign rx_mid0_rx_valid = rx_mid0_valid & w_rx_ch_valid & w_recv_ch_valid;
   assign rx_mid0_ready = w_recv_ch_valid & ((w_rx_ch_valid & rx_mid0_rx_ready) |
                                             (w_tx_ch_valid & (~rx_tx_tvalid | rx_tx_tready)) |
                                             (~w_rx_ch_valid & ~w_tx_ch_valid));

   reg [DW*2-1:0]            recv_pre_data;
   reg [KW*2-1:0]            recv_pre_keep;
   reg [KW*2-1:0]            recv_pre_keep_next;
   reg [DW*2-1:0]            recv_pre_data_shift;
   reg [KW*2-1:0]            recv_pre_keep_shift;
   reg [KW*2-1:0]            recv_pre_keep_next_shift;
   reg [KW_LOG:0]            recv_pre_rpos;
   reg [KW_LOG:0]            recv_pre_wpos;
   reg [KW_LOG-1:0]          recv_pre_wpos_rev;
   reg [KW_LOG+1:0]          recv_pre_len;
   reg [CH_NUM_LOG-1:0]      recv_pre_ch;
   reg                       recv_pre_last;
   reg                       recv_pre_valid;
   reg                       recv_pre_out_valid;
   reg                       recv_pre_wr_en;
   reg                       recv_pre_shift_stat;
   wire [KW*2-1:0]           w_recv_read_mask;
   wire [KW_LOG:0]           w_recv_read_cnt;
   wire [KW_LOG:0]           w_recv_read_cnt_next;
   wire                      w_recv_read_valid;

   reg [DW*CH_NUM-1:0]       recv_remaining_data;
   reg [KW*CH_NUM-1:0]       recv_remaining_keeps;
   reg [KW_LOG*CH_NUM-1:0]   recv_remaining_pos;
   reg [32*CH_NUM-1:0]       recv_remaining_sizes;

   reg [DW-1:0]              recv_remain_tmp_data;
   reg [KW-1:0]              recv_remain_tmp_keep;
   reg [CH_NUM_LOG-1:0]      recv_remain_tmp_ch;
   reg [KW_LOG-1:0]          recv_remain_tmp_pos;
   reg [31:0]                recv_remain_tmp_size;
   reg                       recv_remain_tmp_valid;

   wire [DW*2-1:0]           w_recv_pre_keep_next8;
   wire [DW*2-1:0]           w_recv_read_mask8;
   wire [DW-1:0]             w_rx_mid_data_rot;
   wire [KW-1:0]             w_rx_mid_keep_rot;
   assign w_rx_mid_data_rot = {rx_mid_data, rx_mid_data} >> {recv_pre_wpos_rev, 3'd0};
   assign w_rx_mid_keep_rot = {rx_mid_keep, rx_mid_keep} >> recv_pre_wpos_rev;
   generate
      for (genvar i=0; i<KW*2; i=i+1) begin
         assign w_recv_pre_keep_next8[i*8+:8] = {8{recv_pre_keep_next[i]}};
         assign w_recv_read_mask8[i*8+:8] = {8{w_recv_read_mask[i]}};
      end
   endgenerate

   wire w_recv_stat_save;
   wire [KW_LOG-1:0] w_cur_recv_wpos = recv_remaining_pos >> (KW_LOG * rx_mid_ch);
   always @(posedge clk) begin
      if (~resetn) begin
         recv_pre_valid <= 1'b0;
         recv_pre_out_valid <= 1'b0;
         recv_pre_wr_en <= 1'b0;
         recv_pre_shift_stat <= 1'b0;
      end else if (rx_mid_valid && ~recv_pre_valid) begin
         // restore pending state
         recv_pre_valid <= 1'b1;
         recv_pre_out_valid <= 1'b0;
         if (recv_remain_tmp_valid && recv_remain_tmp_ch == rx_mid_ch) begin
            recv_pre_data[DW-1:0] <= recv_remain_tmp_data;
            recv_pre_keep[KW-1:0] <= recv_remain_tmp_keep;
            recv_pre_wpos <= recv_remain_tmp_pos;
            recv_pre_wpos_rev <= ~recv_remain_tmp_pos + 1'b1;
            recv_pre_keep_next <= {{KW{1'b0}}, {KW{1'b1}}} << recv_remain_tmp_pos;
            recv_pre_len[KW_LOG-1:0] <= recv_remain_tmp_pos;
         end else begin
            recv_pre_data[DW-1:0] <= recv_remaining_data >> {rx_mid_ch, {DW_LOG{1'b0}}};
            recv_pre_keep[KW-1:0] <= recv_remaining_keeps >> {rx_mid_ch, {KW_LOG{1'b0}}};
            recv_pre_wpos <= w_cur_recv_wpos;
            recv_pre_wpos_rev <= ~w_cur_recv_wpos + 1'b1;
            recv_pre_keep_next <= {{KW{1'b0}}, {KW{1'b1}}} << w_cur_recv_wpos;
            recv_pre_len[KW_LOG-1:0] <= recv_remaining_pos >> (KW_LOG * rx_mid_ch);
         end
         recv_pre_data[DW+:DW] <= 'd0;
         recv_pre_keep[KW+:KW] <= 'd0;
         recv_pre_rpos <= 'd0;
         recv_pre_len[KW_LOG+:2] <= 2'd0;
         recv_pre_ch <= rx_mid_ch;
         recv_pre_last <= 1'b0;
         recv_pre_wr_en <= 1'b1;
      end else if (rx_mid_valid && rx_mid_ready) begin
         // update data with rx packet and rx output
         recv_pre_data <= (recv_pre_data & ~w_recv_read_mask8) | (w_recv_pre_keep_next8 & {w_rx_mid_data_rot, w_rx_mid_data_rot});
         recv_pre_keep <= (recv_pre_keep & ~w_recv_read_mask) | (recv_pre_keep_next & {w_rx_mid_keep_rot, w_rx_mid_keep_rot});
         recv_pre_rpos <= recv_pre_rpos + w_recv_read_cnt;
         recv_pre_wpos <= recv_pre_wpos + rx_mid_pos;
         recv_pre_wpos_rev <= recv_pre_wpos_rev - rx_mid_pos;
         recv_pre_len <= recv_pre_len + rx_mid_pos - w_recv_read_cnt;
         recv_pre_out_valid <= ({1'b0, recv_pre_len} + rx_mid_pos - w_recv_read_cnt >= w_recv_read_cnt_next) && ~|w_recv_read_cnt[KW_LOG-1:0];
         recv_pre_last <= rx_mid_last;
         recv_pre_keep_next <= ~recv_pre_keep_next;
         recv_pre_wr_en <= {1'b0, recv_pre_len} + rx_mid_pos - w_recv_read_cnt <= KW;
      end else if (|recv_pre_rpos[KW_LOG-1:0]) begin
         if (~recv_pre_shift_stat) begin
            recv_pre_data_shift <= {recv_pre_data[DW-9:0], recv_pre_data} >> {recv_pre_rpos[KW_LOG-1:0], 3'd0};
            recv_pre_keep_shift <= {recv_pre_keep[KW-2:0], recv_pre_keep} >> recv_pre_rpos[KW_LOG-1:0];
            recv_pre_keep_next_shift <= {recv_pre_keep_next[KW-2:0], recv_pre_keep_next} >> recv_pre_rpos[KW_LOG-1:0];
            recv_pre_shift_stat <= 1'b1;
         end else begin
            recv_pre_data <= recv_pre_data_shift;
            recv_pre_keep <= recv_pre_keep_shift;
            recv_pre_keep_next <= recv_pre_keep_next_shift;
            recv_pre_rpos <= recv_pre_rpos & {1'b1, {KW_LOG{1'b0}}};
            recv_pre_wpos <= recv_pre_wpos - recv_pre_rpos[KW_LOG-1:0];
            recv_pre_wpos_rev <= recv_pre_wpos_rev + recv_pre_rpos[KW_LOG-1:0];
            recv_pre_out_valid <= (recv_pre_len >= w_recv_read_cnt_next && |w_recv_read_cnt_next) || recv_pre_len >= KW;
            recv_pre_shift_stat <= 1'b0;
         end
      end else if (|w_recv_read_cnt) begin
         // update data with  rx output
         recv_pre_data <= recv_pre_data & ~w_recv_read_mask8;
         recv_pre_keep <= recv_pre_keep & ~w_recv_read_mask;
         recv_pre_rpos <= recv_pre_rpos + w_recv_read_cnt;
         recv_pre_len <= recv_pre_len - w_recv_read_cnt;
         recv_pre_out_valid <= ({1'b0, recv_pre_len} - w_recv_read_cnt >= w_recv_read_cnt_next) &&
                               |w_recv_read_cnt_next && w_recv_read_cnt == KW;
         recv_pre_wr_en <= {1'b0, recv_pre_len} - w_recv_read_cnt <= KW;
      end else if (w_recv_stat_save) begin
         // save pending state
         recv_pre_valid <= recv_pre_valid & (~recv_pre_last | recv_pre_out_valid);
         recv_pre_last <= recv_pre_last & recv_pre_out_valid;
         if (recv_pre_valid & ~recv_pre_last) begin
            recv_pre_out_valid <= {1'b0, recv_pre_len} >= w_recv_read_cnt_next && |w_recv_read_cnt_next;
         end
      end else begin
         // remaining output data
         recv_pre_out_valid <= recv_pre_out_valid || (recv_pre_len >= KW && w_recv_read_cnt_next == KW);
      end
   end
   assign rx_mid_ready = recv_pre_valid & ~recv_pre_last & ~recv_pre_shift_stat && (recv_pre_wr_en | w_recv_read_valid);

   reg [DW-1:0]            recv_data;
   reg [KW-1:0]            recv_keep;
   reg                     recv_last;
   reg [31:0]              recv_size;
   reg [31:0]              recv_size_remain;
   reg                     recv_read_size_is_full;
   reg [KW_LOG:0]          recv_read_size;
   reg [KW_LOG:0]          recv_read_size_next;
   reg [31:0]              recv_cur_frame_size;
   reg                     recv_eof;
   reg                     recv_valid;
   reg [CH_NUM_LOG-1:0]    recv_ch;
   reg                     recv_cur_frame_size_valid;
   wire                    recv_oready;

   assign w_recv_stat_save = ~(rx_mid_valid & rx_mid_ready) && ~|recv_pre_len[KW_LOG+:2] &&
                             ~|recv_pre_rpos[KW_LOG-1:0] && ~|w_recv_read_cnt & recv_pre_last & ~recv_pre_out_valid;

   always @(posedge clk) begin
      if (~resetn) begin
         recv_remain_tmp_valid <= 1'b0;
      end else if (w_recv_stat_save) begin
         if (~recv_pre_rpos[KW_LOG]) begin
            recv_remain_tmp_keep <= recv_pre_keep[0+:KW];
         end else begin
            recv_remain_tmp_keep <= recv_pre_keep[KW+:KW];
         end
         recv_remain_tmp_size <= recv_size_remain;
         recv_remain_tmp_pos <= recv_pre_len;
         recv_remain_tmp_ch <= recv_pre_ch;
         recv_remain_tmp_valid <= 1'b1;
      end else begin
         recv_remain_tmp_valid <= 1'b0;
      end
   end
   generate
      for (genvar i=0; i<KW; i=i+1) begin
         always @(posedge clk) begin
            if (~resetn) begin
               recv_remain_tmp_data[i*8+:8] <= 8'd0;
            end else if (w_recv_stat_save) begin
               if (~recv_pre_rpos[KW_LOG]) begin
                  recv_remain_tmp_data[i*8+:8] <= recv_pre_data[i*8+:8] & {8{recv_pre_keep[i]}};
               end else begin
                  recv_remain_tmp_data[i*8+:8] <= recv_pre_data[DW+i*8+:8] & {8{recv_pre_keep[KW+i]}};
               end
            end
         end
      end
   endgenerate
   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         always @(posedge clk) begin
            if (~resetn || ~rx_ch_readys[i]) begin
               recv_remaining_data[DW*i+:DW] <= 'd0;
               recv_remaining_keeps[KW*i+:KW] <= 'd0;
               recv_remaining_pos[KW_LOG*i+:KW_LOG] <= 'd0;
               recv_remaining_sizes[32*i+:32] <= 'd0;
            end else if (recv_remain_tmp_valid && recv_remain_tmp_ch == i) begin
               recv_remaining_data[DW*i+:DW] <= recv_remain_tmp_data;
               recv_remaining_keeps[KW*i+:KW] <= recv_remain_tmp_keep;
               recv_remaining_sizes[32*i+:32] <= recv_remain_tmp_size;
               recv_remaining_pos[KW_LOG*i+:KW_LOG] <= recv_remain_tmp_pos;
            end else if (recv_valid && recv_oready && recv_eof && recv_ch == i) begin
               recv_remaining_sizes[32*i+:32] <= 'd0;
            end
         end
      end
   endgenerate

   wire [31:0] w_cur_frame_size = w_frame_sizes >> {recv_pre_ch, 5'd0};
   wire [31:0] w_cur_recv_size_remain = recv_remaining_sizes >> {recv_pre_ch, 5'd0};
   wire [31:0] w_recv_size_remain_next;
   wire [KW-1:0] w_recv_read_mask_self;
   always @(posedge clk) begin
      if (~resetn) begin
         recv_valid <= 1'b0;
         recv_cur_frame_size_valid <= 1'b0;
         recv_size_remain <= 'd0;
         recv_read_size_is_full <= 'd0;
         recv_read_size <= 'd0;
         recv_read_size_next <= 'd0;
      end else if (~recv_cur_frame_size_valid && recv_pre_valid) begin
         recv_cur_frame_size <= w_cur_frame_size;
         recv_cur_frame_size_valid <= w_frame_size_valids >> recv_pre_ch;
         recv_ch <= recv_pre_ch;
         if (~|w_cur_recv_size_remain) begin
            recv_size_remain <= w_cur_frame_size;
         end else begin
            recv_size_remain <= w_cur_recv_size_remain;
         end
         recv_valid <= recv_valid & ~recv_oready;
         recv_eof <= 1'b0;
      end else if (recv_cur_frame_size_valid) begin
         recv_read_size_is_full <= w_recv_size_remain_next >= KW;
         recv_read_size <= w_recv_size_remain_next >= KW ? KW : w_recv_size_remain_next;
         recv_read_size_next <= w_recv_size_remain_next >= KW*2 ? KW :
                                w_recv_size_remain_next >= KW ? w_recv_size_remain_next - KW : w_recv_size_remain_next;
         if (w_recv_stat_save) begin
            recv_size_remain <= 'd0;
            recv_cur_frame_size_valid <= 1'b0;
            recv_valid <= recv_valid & ~recv_oready;
            if (~recv_valid || recv_oready) begin
               recv_cur_frame_size_valid <= |recv_size_remain;
            end
         end if (w_recv_read_valid || |w_recv_read_cnt) begin
            recv_size_remain <= w_recv_size_remain_next;
            recv_data <= recv_pre_rpos[KW_LOG] ? recv_pre_data[DW+:DW] : recv_pre_data[0+:DW];
            recv_keep <= (recv_pre_rpos[KW_LOG] ? recv_pre_keep[KW+:KW] : recv_pre_keep[0+:KW]) & w_recv_read_mask_self;
            recv_last <= recv_pre_last && ((recv_pre_len - recv_read_size < recv_read_size_next) ||
                                           (recv_pre_len == recv_read_size));
            recv_eof <= recv_size_remain <= recv_read_size;
            recv_valid <= 1'b1;
         end else begin
            recv_valid <= recv_valid & ~recv_oready;
            if (~recv_valid || recv_oready) begin
               recv_cur_frame_size_valid <= |recv_size_remain;
            end
         end
      end else begin
         recv_valid <= recv_valid & ~recv_oready;
      end
   end
   assign w_recv_read_valid = recv_read_size_is_full & recv_pre_out_valid & (~recv_valid | recv_oready);
   assign w_recv_read_cnt = recv_pre_out_valid & (~recv_valid | recv_oready) ? recv_read_size : 'd0;
   assign w_recv_read_cnt_next = recv_pre_out_valid & (~recv_valid | recv_oready) ? recv_read_size_next : recv_read_size;
   assign w_recv_size_remain_next = recv_size_remain - w_recv_read_cnt;
   generate
      for (genvar i=0; i<KW; i=i+1) begin
         assign w_recv_read_mask_self[i] = i < w_recv_read_cnt;
      end
   endgenerate
   assign w_recv_read_mask[0+:KW] = recv_pre_rpos[KW_LOG] ? 'd0 : w_recv_read_mask_self;
   assign w_recv_read_mask[KW+:KW] = recv_pre_rpos[KW_LOG] ? w_recv_read_mask_self : 'd0;

   wire [DW+KW+CH_NUM_LOG:0] w_recv_cnt_data;
   wire                      w_recv_cnt_last;
   wire                      w_recv_cnt_valid;
   wire                      w_recv_cnt_ready;
   axis_buf #(
       .DW ( DW + KW + CH_NUM_LOG + 1 )
   ) recv_cnt_buf (
       .idata ( {recv_eof, recv_ch, recv_keep, recv_data} ),
       .ilast ( recv_eof || recv_last ),
       .ivalid ( recv_valid ),
       .iready ( recv_oready ),
       .odata ( w_recv_cnt_data ),
       .olast ( w_recv_cnt_last ),
       .ovalid ( w_recv_cnt_valid ),
       .oready ( w_recv_cnt_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   reg [BURST_BITS-1:0]      recv_cnts;
   always @(posedge clk) begin
      if (~resetn) begin
         recv_cnts <= 'd0;
      end else if (w_recv_cnt_valid & w_recv_cnt_ready) begin
         if (w_recv_cnt_last || &recv_cnts) begin
            recv_cnts <= 'd0;
         end else begin
            recv_cnts <= recv_cnts + 1'b1;
         end
      end
   end
   assign w_recv_cnt_last_mod = &recv_cnts || w_recv_cnt_last;

   packet_fifo #(
       .DW ( DW + KW + CH_NUM_LOG + 1 ),
       .BURST_BITS ( BURST_BITS )
   ) out_fifo (
       .i_tdata ( w_recv_cnt_data ),
       .i_tlast ( w_recv_cnt_last_mod ),
       .i_tvalid ( w_recv_cnt_valid ),
       .i_tready ( w_recv_cnt_ready ),
       .o_tdata ( {rx_out_eof, rx_out_tuser, rx_out_tkeep, rx_out_tdata} ),
       .o_tlast ( rx_out_tlast ),
       .o_tvalid ( rx_out_tvalid ),
       .o_tready ( rx_out_tready ),
       .full ( ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   always @(posedge clk) begin
      if (~resetn) begin
        rx_credit_dec <= 1'b0;
      end else begin
         rx_credit_dec <= recv_valid && recv_eof && recv_oready;
         rx_credit_dec_session_id <= rx_ch_session_ids >> (recv_ch * SESSION_NUM_LOG);
      end
   end

   reg [CH_NUM*FRAME_MAX-1:0] frame_size_valids;
   reg [CH_NUM*FRAME_MAX*32-1:0] frame_sizes;
   reg [CH_NUM*(FRAME_MAX_LOG+1)-1:0] frame_size_nums;
   wire [CH_NUM-1:0]                  w_frame_size_fulls;

   generate
      for (genvar ch=0; ch<CH_NUM; ch=ch+1) begin
         for (genvar i=0; i<FRAME_MAX; i=i+1) begin
            wire cur_valid = frame_size_valids[ch*FRAME_MAX+i];
            wire prev_valid, succ_valid;
            if (i>0) assign prev_valid = frame_size_valids[ch*FRAME_MAX+i-1];
            if (i<FRAME_MAX-1) assign succ_valid = frame_size_valids[ch*FRAME_MAX+i+1];
            always @(posedge clk) begin
               if (~resetn || ~rx_ch_readys[ch]) begin
                  frame_sizes[(ch*FRAME_MAX+i)*32+:32] <= 32'd0;
                  frame_size_valids[ch*FRAME_MAX+i] <= 1'b0;
                  frame_size_nums[ch*(FRAME_MAX_LOG+1)+:FRAME_MAX_LOG+1] <= 'd0;
               end else if (frame_info_tvalid && frame_info_tready && frame_info_tuser == ch) begin
                  frame_size_nums[ch*(FRAME_MAX_LOG+1)+:FRAME_MAX_LOG+1] <= frame_size_nums[ch*(FRAME_MAX_LOG+1)+:FRAME_MAX_LOG+1] + 1'b1 - w_frame_size_consumes[ch];
                  if (i==0) begin
                     if (~cur_valid || (~succ_valid && w_frame_size_consumes[ch])) begin
                        frame_size_valids[ch*FRAME_MAX+i] <= 1'b1;
                        frame_sizes[(ch*FRAME_MAX+i)*32+:32] <= frame_info_tdata;
                     end else if (succ_valid && w_frame_size_consumes[ch]) begin
                        frame_size_valids[ch*FRAME_MAX+i] <= 1'b1;
                        frame_sizes[(ch*FRAME_MAX+i)*32+:32] <= frame_sizes[(ch*FRAME_MAX+i+1)*32+:32];
                     end
                  end else if (i<FRAME_MAX-1) begin
                     if ((~cur_valid && prev_valid && ~w_frame_size_consumes[ch]) ||
                         (~succ_valid && cur_valid && w_frame_size_consumes[ch])) begin
                        frame_size_valids[ch*FRAME_MAX+i] <= 1'b1;
                        frame_sizes[(ch*FRAME_MAX+i)*32+:32] <= frame_info_tdata;
                     end else if (succ_valid && w_frame_size_consumes[ch]) begin
                        frame_size_valids[ch*FRAME_MAX+i] <= 1'b1;
                        frame_sizes[(ch*FRAME_MAX+i)*32+:32] <= frame_sizes[(ch*FRAME_MAX+i+1)*32+:32];
                     end
                  end else begin // i== FRAME_MAX-1
                     if (prev_valid && ~w_frame_size_consumes[ch]) begin
                        frame_size_valids[ch*FRAME_MAX+i] <= 1'b1;
                        frame_sizes[(ch*FRAME_MAX+i)*32+:32] <= frame_info_tdata;
                     end
                  end
               end else if (w_frame_size_consumes[ch]) begin
                  frame_size_nums[ch*(FRAME_MAX_LOG+1)+:FRAME_MAX_LOG+1] <= frame_size_nums[ch*(FRAME_MAX_LOG+1)+:FRAME_MAX_LOG+1] - w_frame_size_consumes[ch];
                  if (i<FRAME_MAX-1) begin
                     frame_size_valids[ch*FRAME_MAX+i] <= succ_valid;
                     frame_sizes[(ch*FRAME_MAX+i)*32+:32] <= frame_sizes[(ch*FRAME_MAX+i+1)*32+:32];
                  end else begin
                     frame_size_valids[ch*FRAME_MAX+i] <= 1'b0;
                     frame_sizes[(ch*FRAME_MAX+i)*32+:32] <= 32'd0;
                  end
               end
            end
         end
         assign w_frame_size_valids[ch] = frame_size_valids[ch*FRAME_MAX];
         assign w_frame_sizes[32*ch+:32] = frame_sizes[ch*FRAME_MAX*32+:32];
         assign w_frame_size_fulls[ch] = frame_size_valids[(ch+1)*FRAME_MAX-1];
      end
   endgenerate
   assign w_frame_size_consumes = ({{CH_NUM{1'b0}}, recv_valid && recv_eof && recv_oready} << recv_ch) & {CH_NUM{recv_valid}};

   // tx signals
   reg [DW-1:0]         tx_ctrl_data;
   reg [KW-1:0]         tx_ctrl_keep;
   reg [SESSION_NUM_LOG-1:0] tx_ctrl_user;
   reg                       tx_ctrl_last;
   reg                       tx_ctrl_valid;
   reg [BURST_BITS-1:0]      tx_ctrl_burst;
   reg [KW_LOG-1:0]          tx_ctrl_last_cnts;

   reg                  activate_to_tx;
   reg                  credit_inc_to_tx;
   reg [CH_NUM_LOG-1:0] activate_ch;
   reg                  cur_ch_activate;
   wire [SESSION_NUM_LOG-1:0] w_cur_tx_ch_session_id = rx_ch_session_ids >> (activate_ch * SESSION_NUM_LOG);
   wire [SESSION_NUM_LOG-1:0] w_cur_tx_credit_session_id = rx_ch_session_ids >> (frame_info_tuser * SESSION_NUM_LOG);
   wire [31:0]                w_cur_tx_ch_frame_size = rx_ch_frame_sizes >> {activate_ch, 5'd0};
   wire [15:0]                w_cur_tx_ch_credit_max = rx_ch_credit_max >> {activate_ch, 4'd0};
   wire [CH_NUM_LOG-1:0]      w_activate_ch_next = activate_ch + 1'b1;
   always @(posedge clk) begin
      if (~resetn) begin
         tx_ctrl_valid <= 1'b0;
         activate_to_tx <= 1'b0;
         credit_inc_to_tx <= 1'b0;
         activate_ch <= 'd0;
         cur_ch_activate <= 1'b0;
         rx_credit_inc <= 1'b0;
         activate_done <= 1'b0;
      end else begin
         cur_ch_activate <= rx_ch_activates >> w_activate_ch_next;
         activate_ch <= w_activate_ch_next;
         if (~tx_ctrl_valid | tx_tready) begin
            if (cur_ch_activate) begin
               tx_ctrl_data <= {w_cur_tx_ch_credit_max, w_cur_tx_ch_frame_size, ACTIVATE_MAGIC};
               tx_ctrl_keep <= {KW{1'b0}} | {10'h3ff};
               tx_ctrl_user <= w_cur_tx_ch_session_id;
               tx_ctrl_last <= 1'b1;
               tx_ctrl_burst <= 'd0;
               tx_ctrl_last_cnts <= 'd9;
               tx_ctrl_valid <= 1'b1;
               activate_to_tx <= 1'b1;
               credit_inc_to_tx <= 1'b0;
               rx_credit_inc <= 1'b0;
            end else if (frame_info_tvalid & frame_info_tready) begin
               tx_ctrl_data <= {frame_info_tdata, CREDIT_MAGIC};
               tx_ctrl_keep <= {KW{1'b0}} | {8'hff};
               tx_ctrl_user <= w_cur_tx_credit_session_id;
               tx_ctrl_last <= 1'b1;
               tx_ctrl_burst <= 'd0;
               tx_ctrl_last_cnts <= 'd7;
               tx_ctrl_valid <= 1'b1;
               credit_inc_to_tx <= 1'b1;
               activate_to_tx <= 1'b0;
               rx_credit_inc <= 1'b0;
            end else begin
               tx_ctrl_valid <= 1'b0;
               credit_inc_to_tx <= 1'b0;
               activate_to_tx <= 1'b0;
               if (activate_to_tx && tx_tvalid && tx_tready && tx_tlast) begin
                  activate_done <= 1'b1;
                  activate_done_session_id <= tx_tuser;
               end else begin
                  activate_done <= 1'b0;
               end
               if (credit_inc_to_tx && tx_tvalid && tx_tready && tx_tlast) begin
                  rx_credit_inc <= 1'b1;
                  rx_credit_inc_session_id <= tx_tuser;
               end else begin
                  rx_credit_inc <= 1'b0;
               end
            end
         end else begin
            rx_credit_inc <= 1'b0;
         end
      end
   end
   assign tx_tdata = tx_ctrl_data;
   assign tx_tkeep = tx_ctrl_keep;
   assign tx_tuser = tx_ctrl_user;
   assign tx_tlast = tx_ctrl_last;
   assign tx_burst = tx_ctrl_burst;
   assign tx_last_cnts = tx_ctrl_last_cnts;
   assign tx_tvalid = tx_ctrl_valid;
   assign frame_info_tready = ~|w_frame_size_fulls && ~tx_ctrl_valid && ~cur_ch_activate;

   // frame info out
   reg [CH_NUM_LOG-1:0] frame_info_out_ch;
   reg [CH_NUM_LOG-1:0] frame_info_ch_candidate;
   reg                  frame_info_out_valid;
   reg [31:0]           frame_info_out_size;
   wire [CH_NUM_LOG-1:0] w_frame_info_out_ch_next = frame_info_ch_candidate + 1'b1;
   wire [15:0]           w_cur_credit_max = rx_ch_credit_max >> {frame_info_ch_candidate, 4'd0};
   wire [15:0]           w_cur_credit_cur = rx_ch_credit_cur >> {frame_info_ch_candidate, 4'd0};
   reg [4*CH_NUM-1:0]    frame_info_inflights;
   wire [3:0]            w_frame_info_inflight = frame_info_inflights >> {frame_info_ch_candidate, 2'd0};
   wire [31:0]           w_frame_info_out_size = rx_ch_frame_sizes >> {frame_info_ch_candidate, 5'd0};
   wire                  w_ch_ready = rx_ch_readys >> frame_info_ch_candidate;
   wire [FRAME_MAX_LOG:0] w_cur_frame_num = frame_size_nums >> ((FRAME_MAX_LOG+1)*frame_info_ch_candidate);
   wire                  w_cur_frame_size_full = w_frame_size_fulls >> frame_info_ch_candidate;
   wire                  w_frame_info_out_enable = w_cur_credit_max > (w_cur_credit_cur + w_frame_info_inflight) &&
                         w_frame_info_inflight < MAX_INFLIGHT && w_ch_ready &&
                         (w_cur_frame_num + w_frame_info_inflight) < FRAME_MAX-1;
   always @(posedge clk) begin
      if (~resetn) begin
         frame_info_ch_candidate <= 'd0;
         frame_info_out_valid <= 1'b0;
      end else begin
         if (~frame_info_out_valid) begin
            frame_info_out_ch <= frame_info_ch_candidate;
            frame_info_out_valid <= w_frame_info_out_enable;
            frame_info_out_size <= w_frame_info_out_size;
         end else begin
            frame_info_out_valid <= frame_info_out_valid & ~frame_info_out_tready;
         end
         frame_info_ch_candidate <= w_frame_info_out_ch_next;
      end
   end
   assign frame_info_out_tdata = frame_info_out_size;
   assign frame_info_out_tuser = frame_info_out_ch;
   assign frame_info_out_tvalid = frame_info_out_valid;

   generate
      for (genvar ch=0; ch<CH_NUM; ch=ch+1) begin
         wire w_inflight_inc = frame_info_out_tvalid && frame_info_out_tready && frame_info_out_tuser == ch;
         wire w_inflight_dec = frame_info_tvalid && frame_info_tready && frame_info_tuser == ch;
         always @(posedge clk) begin
            if (~resetn || ~rx_ch_readys[ch]) begin
               frame_info_inflights[ch*4+:4] <= 'd0;
            end else begin
               frame_info_inflights[ch*4+:4] <= frame_info_inflights[ch*4+:4] + w_inflight_inc - w_inflight_dec;
            end
         end
      end
   endgenerate

endmodule
