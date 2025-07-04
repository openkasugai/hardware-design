/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module toe_ctrl_tx #(
    parameter DW_LOG = 9,
    parameter CH_NUM_LOG = 4,
    parameter BURST_BITS = 6,
    parameter SESSION_NUM_LOG = 6,
    parameter FRAME_MAX = 8,
    parameter MAX_INFLIGHT = 2,
    parameter TX_FIFO_DL = 9,
    parameter TX_AUX_FIFO_DL = 4,
    parameter ACTIVATE_MAGIC = 32'h56544341, // ACTV
    parameter CREDIT_MAGIC = 32'h54445243  // CRDT
    ) (
    input [(1<<DW_LOG)-1:0]                   tx_in_tdata,
    input [(1<<(DW_LOG-3))-1:0]               tx_in_tkeep,
    input [CH_NUM_LOG-1:0]                    tx_in_tuser,
    input                                     tx_in_tlast,
    input                                     tx_in_sop,
    input                                     tx_in_eop,
    input [BURST_BITS-1:0]                    tx_in_burst, // 0-origin -> 1-origin
    input [DW_LOG-4:0]                        tx_in_last_cnt, // 0-origin -> 1->origin
    input                                     tx_in_tvalid,
    output                                    tx_in_tready,

    output [(1<<DW_LOG)-1:0]                  tx_toe_tdata,
    output [(1<<(DW_LOG-3))-1:0]              tx_toe_tkeep,
    output [SESSION_NUM_LOG-1:0]              tx_toe_tuser,
    output                                    tx_toe_tlast,
    output                                    tx_toe_tvalid,
    input                                     tx_toe_tready,

    output [31:0]                             tx_toe_cmd_tdata,
    output                                    tx_toe_cmd_tvalid,
    input                                     tx_toe_cmd_tready,

    input [87:0]                              tx_toe_rsp_tdata,
    input                                     tx_toe_rsp_tvalid,
    output                                    tx_toe_rsp_tready,

    // received packet for tx session
    input [(1<<DW_LOG)-1:0]                   rx_tx_tdata,
    input [(1<<(DW_LOG-3))-1:0]               rx_tx_tkeep,
    input [CH_NUM_LOG-1:0]                    rx_tx_tuser,
    input                                     rx_tx_tlast, // eop
    input                                     rx_tx_tvalid,
    output                                    rx_tx_tready,

    // transfer packet of rx session
    input [(1<<DW_LOG)-1:0]                   tx_tdata,
    input [(1<<(DW_LOG-3))-1:0]               tx_tkeep,
    input [SESSION_NUM_LOG-1:0]               tx_tuser,
    input [BURST_BITS-1:0]                    tx_burst,
    input [DW_LOG-4:0]                        tx_last_cnts,
    input                                     tx_tlast,
    input                                     tx_tvalid,
    output                                    tx_tready,

    input [(1<<CH_NUM_LOG)-1:0]               tx_ch_valids,
    input [(1<<CH_NUM_LOG)-1:0]               tx_ch_actives,
    input [(1<<CH_NUM_LOG)-1:0]               tx_ch_readys,
    input [(SESSION_NUM_LOG<<CH_NUM_LOG)-1:0] tx_ch_session_ids,
    input [(32<<CH_NUM_LOG)-1:0]              tx_ch_frame_sizes,
    input                                     invalidate_activate,

    output [SESSION_NUM_LOG-1:0]              connected_session_id,
    output [31:0]                             connected_ip,
    output [15:0]                             connected_port,
    output                                    connected_valid,
    input                                     connected_out_found,
    input                                     connected_out_valid,

    output reg [SESSION_NUM_LOG-1:0]          close_session_id,
    output reg                                close_valid,

    output reg [15:0]                         cp_config_credit_max,
    output reg [31:0]                         cp_config_frame_size,
    output reg [SESSION_NUM_LOG-1:0]          cp_config_session_id,
    output reg                                cp_config_valid,

    output reg [SESSION_NUM_LOG-1:0]          tx_credit_inc_session_id,
    output reg                                tx_credit_inc,
    output [SESSION_NUM_LOG-1:0]              tx_credit_dec_session_id,
    output                                    tx_credit_dec,

    output reg [31:0]                         frame_info_out_tdata, // frame size
    output reg [CH_NUM_LOG-1:0]               frame_info_out_tuser,
    output reg                                frame_info_out_tvalid,
    input                                     frame_info_out_tready,

    input [31:0]                              frame_info_tdata, // frame size
    input [CH_NUM_LOG-1:0]                    frame_info_tuser,
    input                                     frame_info_tvalid,
    output                                    frame_info_tready,

    input                                     clk,
    input                                     resetn
    );

   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam DW = 1 << DW_LOG;
   localparam KW_LOG = DW_LOG - 3;
   localparam KW = 1 << KW_LOG;
   localparam FRAME_MAX_LOG = $clog2(FRAME_MAX);
   localparam KDIV = 4;
   localparam DIV_KW = KW / KDIV;

   localparam TX_AUX_FIFO_DEPTH = 1 << TX_AUX_FIFO_DL;
   localparam ACTIVATE_PACKET_SIZE = 10;
   localparam CREDIT_PACKET_SIZE = 8;
   localparam MIN_RECV_PACKET = CREDIT_PACKET_SIZE;
   localparam MAX_RECV_PACKET = ACTIVATE_PACKET_SIZE;

   // receive packet
   wire [KDIV*(KW_LOG+1)-1:0]                   w_rx_tx_keep_part_cnts;
   bit_count #(
       .DIV ( KDIV ),
       .WL ( KW_LOG )
   ) rx_tx_keep_cnt (
       .idata ( rx_tx_tkeep ),
       .odata ( w_rx_tx_keep_part_cnts )
   );

   wire [DW-1:0] w_rx_tx_data;
   wire [KDIV*(KW_LOG+1)-1:0] w_rx_tx_part_cnts;
   wire [CH_NUM_LOG-1:0]      w_rx_tx_user;
   wire                       w_rx_tx_last;
   wire                       w_rx_tx_valid, w_rx_tx_ready;

   axis_buf #(
       .DW ( DW + KDIV*(KW_LOG+1) + CH_NUM_LOG )
   ) rx_tx_ibuf (
       .idata ( {rx_tx_tuser, w_rx_tx_keep_part_cnts, rx_tx_tdata} ),
       .ilast ( rx_tx_tlast ),
       .ivalid ( rx_tx_tvalid ),
       .iready ( rx_tx_tready ),
       .odata ( {w_rx_tx_user, w_rx_tx_part_cnts, w_rx_tx_data} ),
       .olast ( w_rx_tx_last ),
       .ovalid ( w_rx_tx_valid ),
       .oready ( w_rx_tx_ready ),
       .ostart_prev (),
       .clk ( clk ),
       .resetn ( resetn )
   );

   wire [KW_LOG:0]            w_rx_tx_cnts;
   bit_count_sum #(
       .DIV ( KDIV ),
       .WL ( KW_LOG )
   ) rx_tx_keep_cnt_sum (
       .idata ( w_rx_tx_part_cnts ),
       .odata ( w_rx_tx_cnts )
   );

   reg [DW*CH_NUM-1:0]        recv_data;
   reg [KW_LOG*CH_NUM-1:0]    recv_bytes;
   reg [CH_NUM-1:0]           recv_exists;

   reg [CH_NUM_LOG-1:0] rx_tx_check_ch;
   reg                  rx_tx_check_valid;
   reg [KW_LOG+1:0]     rx_tx_check_len;
   reg                  rx_tx_check_len_gt_kw;
   reg [DW*2-1:0]       rx_tx_check_data;
   reg                  rx_tx_check_wr_en;
   reg                  rx_tx_check_ready;
   reg                  rx_tx_check_is_activate;
   reg                  rx_tx_check_is_credit;
   wire [CH_NUM_LOG-1:0] w_rx_tx_check_ch_candidate;
   wire                  w_rx_tx_check_ready;
   wire [3:0]            w_rx_tx_check_ch_valids;

   wire [KW_LOG-1:0]     w_rx_tx_consume_cnts;
   wire                  w_rx_tx_consume;

   wire [KW_LOG-1:0]     w_cur_ch_recv_byte = recv_bytes >> (w_rx_tx_check_ch_candidate * KW_LOG);
   wire [DW-1:0]         w_cur_ch_recv_data = recv_data >> {w_rx_tx_check_ch_candidate, {DW_LOG{1'b0}}};
   wire [DW*2-1:0]       w_cur_ch_merged_data = rx_tx_check_data | (w_rx_tx_data << {rx_tx_check_len, 3'd0});
   wire [KW_LOG+1:0]     w_cur_ch_merged_len = rx_tx_check_len + (w_rx_tx_last ? w_rx_tx_cnts : KW);
   wire [DW*2-1:0]       w_cur_ch_consumed_data = rx_tx_check_data >> {w_rx_tx_consume_cnts, 3'd0};
   wire [KW_LOG+1:0]     w_cur_ch_consumed_len = rx_tx_check_len - w_rx_tx_consume_cnts;
   always @(posedge clk) begin
      if (~resetn) begin
         rx_tx_check_ch <= 'd0;
         rx_tx_check_valid <= 1'b0;
         rx_tx_check_ready <= 1'b0;
         rx_tx_check_is_activate <= 1'b0;
         rx_tx_check_is_credit <= 1'b0;
      end else if (~rx_tx_check_valid) begin
         rx_tx_check_ch <= w_rx_tx_check_ch_candidate;
         rx_tx_check_valid <= |w_rx_tx_check_ch_valids;
         rx_tx_check_len <= {2'd0, w_cur_ch_recv_byte};
         rx_tx_check_len_gt_kw <= 1'b0;
         rx_tx_check_data[DW-1:0] <= w_cur_ch_recv_data;
         rx_tx_check_data[DW+:DW] <= 'd0;
         rx_tx_check_wr_en <= w_rx_tx_check_ch_candidate == w_rx_tx_user && w_rx_tx_valid;
         rx_tx_check_ready <= w_rx_tx_check_ch_candidate == w_rx_tx_user && w_rx_tx_valid;
         rx_tx_check_is_activate <= w_cur_ch_recv_data[31:0] == ACTIVATE_MAGIC && w_cur_ch_recv_byte >= ACTIVATE_PACKET_SIZE;
         rx_tx_check_is_credit <= w_cur_ch_recv_data[31:0] == CREDIT_MAGIC && w_cur_ch_recv_byte >= CREDIT_PACKET_SIZE;
      end else if (rx_tx_check_valid && w_rx_tx_valid && w_rx_tx_ready) begin
         rx_tx_check_len <= w_cur_ch_merged_len;
         rx_tx_check_len_gt_kw <= w_cur_ch_merged_len > KW;
         rx_tx_check_data <= w_cur_ch_merged_data;
         rx_tx_check_wr_en <= rx_tx_check_wr_en & ~w_rx_tx_last;
         rx_tx_check_ready <= (rx_tx_check_wr_en & ~w_rx_tx_last) & (rx_tx_check_len + (w_rx_tx_last ? w_rx_tx_cnts : KW) <= KW);
         rx_tx_check_is_activate <= w_cur_ch_merged_data[31:0] == ACTIVATE_MAGIC && w_cur_ch_merged_len >= ACTIVATE_PACKET_SIZE;
         rx_tx_check_is_credit <= w_cur_ch_merged_data[31:0] == CREDIT_MAGIC && w_cur_ch_merged_len >= CREDIT_PACKET_SIZE;
      end else if (w_rx_tx_consume && w_rx_tx_check_ready) begin
         rx_tx_check_len <= w_cur_ch_consumed_len;
         rx_tx_check_len_gt_kw <= w_cur_ch_consumed_len > KW;
         rx_tx_check_data <= w_cur_ch_consumed_data;
         rx_tx_check_ready <= (rx_tx_check_len - w_rx_tx_consume_cnts <= KW) & rx_tx_check_wr_en;
         rx_tx_check_is_activate <= w_cur_ch_consumed_data[31:0] == ACTIVATE_MAGIC && w_cur_ch_consumed_len >= ACTIVATE_PACKET_SIZE;
         rx_tx_check_is_credit <= w_cur_ch_consumed_data[31:0] == CREDIT_MAGIC && w_cur_ch_consumed_len >= CREDIT_PACKET_SIZE;
      end else if (rx_tx_check_len < KW && w_rx_tx_check_ready) begin
         if (w_rx_tx_valid && ~rx_tx_check_wr_en && w_rx_tx_user == rx_tx_check_ch) begin
            rx_tx_check_wr_en <= 1'b1;
            rx_tx_check_ready <= 1'b1;
         end else begin
            rx_tx_check_valid <= 1'b0;
            rx_tx_check_ready <= 1'b0;
         end
         rx_tx_check_is_activate <= 1'b0;
         rx_tx_check_is_credit <= 1'b0;
      end
   end
   wire [CH_NUM-1:0] w_rx_tx_recv_valids = ({{CH_NUM{1'b0}}, w_rx_tx_valid} << w_rx_tx_user) & {CH_NUM{w_rx_tx_valid}};
   wire [CH_NUM-1:0] w_rx_tx_rotated_exists = {recv_exists | w_rx_tx_recv_valids,
                                               recv_exists[CH_NUM-1:1] | w_rx_tx_recv_valids[CH_NUM-1:1]} >> rx_tx_check_ch;
   assign w_rx_tx_check_ch_candidate = w_rx_tx_rotated_exists[0] ? rx_tx_check_ch + 1'b1 :
                                       w_rx_tx_rotated_exists[1] ? rx_tx_check_ch + 2'd2 :
                                       w_rx_tx_rotated_exists[2] ? rx_tx_check_ch + 2'd3 : rx_tx_check_ch + 3'd4;
   assign w_rx_tx_check_ch_valids = w_rx_tx_rotated_exists[3:0];
   assign w_rx_tx_ready = rx_tx_check_ready;

   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         always @(posedge clk) begin
            if (~resetn) begin
               recv_bytes[KW_LOG*i+:KW_LOG] <= 'd0;
               recv_exists[i] <= 1'b0;
            end else if (rx_tx_check_valid && ~(w_rx_tx_valid && w_rx_tx_ready) && ~w_rx_tx_consume &&
                         rx_tx_check_len < KW && rx_tx_check_ch == i) begin
               recv_bytes[KW_LOG*i+:KW_LOG] <= rx_tx_check_len;
               recv_exists[i] <= |rx_tx_check_len;
            end
         end
         for (genvar j=0; j<KW; j=j+1) begin
            always @(posedge clk) begin
               if (~resetn) begin
                  recv_data[DW*i+j*8+:8] <= 'd0;
               end else if (rx_tx_check_valid && ~(w_rx_tx_valid && w_rx_tx_ready) && ~w_rx_tx_consume &&
                            rx_tx_check_len < KW && rx_tx_check_ch == i) begin
                  if (j < rx_tx_check_len) begin
                     recv_data[DW*i+j*8+:8] <= rx_tx_check_data[j*8+:8];
                  end else begin
                     recv_data[DW*i+j*8+:8] <= 8'd0;
                  end
               end
            end
         end
      end
   endgenerate

   wire w_rx_tx_check_is_activate = rx_tx_check_is_activate && ~(w_rx_tx_valid && w_rx_tx_ready);
   wire w_rx_tx_check_is_credit = rx_tx_check_is_credit && ~(w_rx_tx_valid && w_rx_tx_ready);
   assign w_rx_tx_consume = w_rx_tx_check_is_activate || w_rx_tx_check_is_credit;
   assign w_rx_tx_consume_cnts = w_rx_tx_check_is_activate ? ACTIVATE_PACKET_SIZE : CREDIT_PACKET_SIZE;

   // credit, activate
   always @(posedge clk) begin
      if (~resetn) begin
         cp_config_valid <= 1'b0;
         tx_credit_inc <= 1'b0;
      end else begin
         cp_config_valid <= w_rx_tx_check_is_activate && w_rx_tx_check_ready;
         cp_config_session_id <= tx_ch_session_ids >> (rx_tx_check_ch*SESSION_NUM_LOG);
         {cp_config_credit_max, cp_config_frame_size} <= rx_tx_check_data[32+:48];
         tx_credit_inc_session_id <= tx_ch_session_ids >> (rx_tx_check_ch*SESSION_NUM_LOG);
         tx_credit_inc <= w_rx_tx_check_is_credit && w_rx_tx_check_ready;
      end
   end

   // credit -> frame info out
   wire [32*CH_NUM-1:0] w_buffer_size_outs;
   wire [CH_NUM-1:0]    w_buffer_size_valids, w_buffer_size_readys;
   ch_separate_fifo #(
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .DW ( 32 ),
       .DL ( 4 )
   ) frame_info_out_fifo (
       .idata ( rx_tx_check_data[32+:32] ),
       .ich ( rx_tx_check_ch ),
       .ivalid ( w_rx_tx_check_is_credit ),
       .iready ( w_rx_tx_check_ready ),
       .odata ( w_buffer_size_outs ),
       .ovalid ( w_buffer_size_valids ),
       .oready ( w_buffer_size_readys ),
       .full ( ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   reg [CH_NUM_LOG-1:0] buffer_size_ch;
   wire [CH_NUM_LOG-1:0] w_buffer_size_ch_candidate;
   always @(posedge clk) begin
      if (~resetn) begin
         buffer_size_ch <= 'd0;
      end else begin
         buffer_size_ch <= w_buffer_size_ch_candidate;
      end
   end
   wire [CH_NUM-1:0] w_buffer_size_rotated_valids = {w_buffer_size_valids, w_buffer_size_valids} >> buffer_size_ch;
   assign w_buffer_size_ch_candidate = w_buffer_size_rotated_valids[1] ? buffer_size_ch + 1'b1 :
                                       w_buffer_size_rotated_valids[2] ? buffer_size_ch + 2'd2 :
                                       w_buffer_size_rotated_valids[3] ? buffer_size_ch + 2'd3 : buffer_size_ch + 3'd4;

   reg [CH_NUM*2-1:0] buffer_size_inflights;
   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         always @(posedge clk) begin
            if (~resetn) begin
               buffer_size_inflights[i*2+:2] <= 2'd0;
            end else begin
               buffer_size_inflights[i*2+:2] <= buffer_size_inflights[i*2+:2] +
                                                ((~frame_info_out_tvalid || frame_info_out_tready) && buffer_size_ch == i &&
                                                 w_buffer_size_valids[i] && buffer_size_inflights[i*2+:2] < 2'd2) -
                                                (frame_info_tvalid && frame_info_tready && frame_info_tuser == i);
            end
         end
         assign w_buffer_size_readys[i] = (~frame_info_out_tvalid || frame_info_out_tready) && buffer_size_ch == i &&
                                          w_buffer_size_valids[i] && buffer_size_inflights[i*2+:2] < 2'd2;
      end
   endgenerate

   always @(posedge clk) begin
      if (~resetn) begin
         frame_info_out_tvalid <= 1'b0;
      end else if (|w_buffer_size_readys) begin
         frame_info_out_tvalid <= 1'b1;
         frame_info_out_tuser <= buffer_size_ch;
         frame_info_out_tdata <= w_buffer_size_outs >> {buffer_size_ch, 5'd0};
      end else begin
         frame_info_out_tvalid <= frame_info_out_tvalid & ~frame_info_out_tready;
      end
   end

   // frame_info -> transfer size check
   wire [32*CH_NUM-1:0] w_frame_sizes;
   wire [CH_NUM-1:0]    w_frame_size_valids, w_frame_size_readys;
   ch_separate_fifo #(
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .DW ( 32 ),
       .DL ( 4 )
   ) frame_info_fifo (
       .idata ( frame_info_tdata ),
       .ich ( frame_info_tuser ),
       .ivalid ( frame_info_tvalid ),
       .iready ( frame_info_tready ),
       .odata ( w_frame_sizes ),
       .ovalid ( w_frame_size_valids ),
       .oready ( w_frame_size_readys ),
       .full ( ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   assign tx_credit_dec_session_id = tx_ch_session_ids >> (frame_info_tuser * SESSION_NUM_LOG);
   assign tx_credit_dec = frame_info_tvalid && frame_info_tready;

   // tx data merge
   wire [DW-1:0]        w_tx_data;
   wire [KW-1:0]        w_tx_keep;
   wire [SESSION_NUM_LOG-1:0] w_tx_user;
   wire [KW_LOG-1:0] w_tx_last_cnts;
   wire [BURST_BITS-1:0] w_tx_burst;
   wire                  w_tx_last, w_tx_valid, w_tx_ready;
   axis_buf #(
       .DW ( DW + KW + KW_LOG + BURST_BITS + SESSION_NUM_LOG )
   ) tx_buf (
       .idata ( {tx_tuser, tx_burst, tx_last_cnts, tx_tkeep, tx_tdata} ),
       .ilast ( tx_tlast ),
       .ivalid ( tx_tvalid ),
       .iready ( tx_tready ),
       .odata ( {w_tx_user, w_tx_burst, w_tx_last_cnts, w_tx_keep, w_tx_data} ),
       .olast ( w_tx_last ),
       .ovalid ( w_tx_valid ),
       .oready ( w_tx_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   reg                   tx_in_ch_valid;
   always @(posedge clk) begin
      if (~resetn) begin
         tx_in_ch_valid <= 1'b0;
      end else if (tx_in_tvalid & tx_in_tready) begin
         if (tx_in_sop) begin
            tx_in_ch_valid <= tx_ch_readys >> tx_in_tuser;
         end
      end
   end
   wire w_tx_in_ch_valid = tx_in_sop ? tx_ch_readys >> tx_in_tuser : tx_in_ch_valid;
   wire [SESSION_NUM_LOG-1:0] w_tx_in_cvt_session = tx_ch_session_ids >> (tx_in_tuser * SESSION_NUM_LOG);

   wire [DW-1:0]              w_tx_in_data;
   wire [KW-1:0]              w_tx_in_keep;
   wire [SESSION_NUM_LOG-1:0] w_tx_in_session;
   wire [BURST_BITS-1:0]      w_tx_in_burst;
   wire [CH_NUM_LOG-1:0]      w_tx_in_user;
   wire [KW_LOG-1:0]          w_tx_in_last_cnt;
   wire                       w_tx_in_last, w_tx_in_eop, w_tx_in_valid, w_tx_in_ready;
   axis_buf #(
       .DW ( DW + KW + CH_NUM_LOG + SESSION_NUM_LOG + 1 + BURST_BITS + KW_LOG )
   ) tx_in_buf (
       .idata ( {tx_in_last_cnt, tx_in_burst, tx_in_tlast, w_tx_in_cvt_session, tx_in_tuser, tx_in_tkeep, tx_in_tdata} ),
       .ilast ( tx_in_eop ),
       .ivalid ( tx_in_tvalid && w_tx_in_ch_valid ),
       .iready ( tx_in_tready ),
       .odata ( {w_tx_in_last_cnt, w_tx_in_burst, w_tx_in_last, w_tx_in_session, w_tx_in_user, w_tx_in_keep, w_tx_in_data} ),
       .olast ( w_tx_in_eop ),
       .ovalid ( w_tx_in_valid ),
       .oready ( w_tx_in_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   wire                  w_tx_fifo_ready;

   wire                  w_tx_data_is_input;
   reg                   tx_data_sop;
   reg                   tx_data_is_input;
   always @(posedge clk) begin
      if (~resetn) begin
         tx_data_sop <= 1'b1;
         tx_data_is_input <= 1'b0;
      end else if (w_tx_fifo_ready) begin
         if (tx_data_sop) begin
            if (w_tx_valid & w_tx_ready) begin
               tx_data_sop <= w_tx_last;
               tx_data_is_input <= 1'b0;
            end else if (w_tx_in_valid & w_tx_in_ready) begin
               tx_data_sop <= w_tx_in_eop;
               tx_data_is_input <= 1'b1;
            end
         end else begin
            tx_data_sop <= w_tx_data_is_input ? w_tx_in_valid & w_tx_in_ready & w_tx_in_eop : w_tx_valid & w_tx_ready & w_tx_last;
         end
      end
   end
   assign w_tx_in_ready = w_tx_data_is_input && w_tx_fifo_ready;
   assign w_tx_ready = ~w_tx_data_is_input && w_tx_fifo_ready;

   assign w_tx_data_is_input = tx_data_sop ? ~w_tx_valid : tx_data_is_input;
   wire [DW-1:0] w_tx_fifo_data = w_tx_data_is_input ? w_tx_in_data : w_tx_data;
   wire [KW-1:0] w_tx_fifo_keep = w_tx_data_is_input ? w_tx_in_keep : w_tx_keep;
   wire [SESSION_NUM_LOG-1:0] w_tx_fifo_user = w_tx_data_is_input ? w_tx_in_session : w_tx_user;
   wire [CH_NUM_LOG-1:0]      w_tx_fifo_org_user = w_tx_data_is_input ? w_tx_in_user : 'd0;
   wire [KW_LOG-1:0]          w_tx_fifo_last_cnts = w_tx_data_is_input ? w_tx_in_last_cnt : w_tx_last_cnts;
   wire [BURST_BITS-1:0]      w_tx_fifo_burst = w_tx_data_is_input ? w_tx_in_burst : w_tx_burst;
   wire                       w_tx_fifo_last = w_tx_data_is_input ? w_tx_in_eop : w_tx_last;
   wire                       w_tx_fifo_valid = (w_tx_data_is_input ? w_tx_in_valid : w_tx_valid) && w_tx_fifo_ready;
   wire [KW_LOG+BURST_BITS:0] w_tx_fifo_bytes = {1'b0, w_tx_fifo_burst, w_tx_fifo_last_cnts} + 1'b1;

   wire                       w_tx_fifo_ready_data;
   wire                       w_tx_toe_valid, w_tx_toe_ready;
   fifo #(
       .DW ( DW + KW + SESSION_NUM_LOG + 1 ),
       .DL ( TX_FIFO_DL )
   ) tx_data_fifo (
       .idata ( {w_tx_fifo_last, w_tx_fifo_user, w_tx_fifo_keep, w_tx_fifo_data} ),
       .ivalid ( w_tx_fifo_valid ),
       .iready ( w_tx_fifo_ready_data ),
       .odata ( {tx_toe_tlast, tx_toe_tuser, tx_toe_tkeep, tx_toe_tdata} ),
       .ovalid ( w_tx_toe_valid ),
       .oready ( w_tx_toe_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   wire                       w_tx_fifo_ready_aux;
   wire [KW_LOG+BURST_BITS:0] w_tx_aux_bytes;
   wire [SESSION_NUM_LOG-1:0] w_tx_aux_user;
   wire [CH_NUM_LOG-1:0]      w_tx_aux_org_user;
   wire                       w_tx_aux_is_input;
   wire                       w_tx_aux_valid, w_tx_aux_ready;
   fifo #(
       .DW ( SESSION_NUM_LOG + KW_LOG + BURST_BITS + 1 + CH_NUM_LOG + 1 ),
       .DL ( TX_AUX_FIFO_DL )
   ) tx_data_aux_fifo (
       .idata ( {w_tx_fifo_bytes, w_tx_fifo_user, w_tx_data_is_input, w_tx_fifo_org_user} ),
       .ivalid ( w_tx_fifo_valid && tx_data_sop ),
       .iready ( w_tx_fifo_ready_aux ),
       .odata ( {w_tx_aux_bytes, w_tx_aux_user, w_tx_aux_is_input, w_tx_aux_org_user} ),
       .ovalid ( w_tx_aux_valid ),
       .oready ( w_tx_aux_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   assign w_tx_fifo_ready = w_tx_fifo_ready_data & w_tx_fifo_ready_aux;

   // toe cmd
   reg [KW_LOG+BURST_BITS:0]  cmd_size;
   reg [SESSION_NUM_LOG-1:0]  cmd_session;
   reg [CH_NUM_LOG-1:0]       cmd_ch;
   reg                        cmd_is_input;
   reg                        cmd_valid;
   reg                        cmd_inflight;
   reg                        activate_valid;
   always @(posedge clk) begin
      if (~resetn) begin
         cmd_valid <= 1'b0;
         activate_valid <= 1'b0;
      end else if (~cmd_valid) begin
         cmd_valid <= w_tx_aux_valid;
         cmd_size <= w_tx_aux_bytes;
         cmd_session <= w_tx_aux_user;
         cmd_ch <= w_tx_aux_org_user;
         cmd_is_input <= w_tx_aux_is_input;
         cmd_inflight <= 1'b0;
         activate_valid <= w_tx_aux_valid && ~w_tx_aux_is_input && w_tx_aux_bytes == ACTIVATE_PACKET_SIZE;
      end else if (invalidate_activate && cmd_valid && activate_valid) begin
         cmd_valid <= 1'b0;
      end else if (~cmd_inflight) begin
         cmd_inflight <= tx_toe_cmd_tvalid & tx_toe_cmd_tready;
      end else if (tx_toe_rsp_tvalid && tx_toe_rsp_tready && tx_toe_rsp_tdata[15:0] == cmd_session) begin
         cmd_inflight <= 1'b0;
         if (~cmd_is_input && cmd_size == ACTIVATE_PACKET_SIZE) begin
            cmd_valid <= |tx_toe_rsp_tdata[82:81] || ~|tx_toe_rsp_tdata[31:16];
         end else begin
            cmd_valid <= ~|tx_toe_rsp_tdata[31:16] && ~|tx_toe_rsp_tdata[82:81];
         end
      end
   end
   assign w_tx_aux_ready = ~cmd_valid;
   assign tx_toe_cmd_tdata = {16'h0 | cmd_size, 16'h0 | cmd_session};
   assign tx_toe_cmd_tvalid = cmd_valid & ~cmd_inflight;

   // frame size check
   reg [32*CH_NUM-1:0] cur_frame_sizes;
   reg [CH_NUM-1:0]    cur_frame_size_valids;
   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         always @(posedge clk) begin
            if (~resetn) begin
               cur_frame_size_valids[i] <= 1'b0;
            end else if (~tx_ch_readys[i]) begin
               cur_frame_size_valids[i] <= 1'b0;
            end else if (~cur_frame_size_valids[i] && w_frame_size_valids[i]) begin
               cur_frame_size_valids[i] <= 1'b1;
               cur_frame_sizes[i*32+:32] <= w_frame_sizes[i*32+:32];
            end else if (cur_frame_size_valids[i] && cmd_is_input && cmd_ch == i &&
                         tx_toe_rsp_tvalid && tx_toe_rsp_tready && tx_toe_rsp_tdata[15:0] == cmd_session) begin
               if (cur_frame_sizes[i*32+:32] <= tx_toe_rsp_tdata[31:16]) begin
                  cur_frame_sizes[i*32+:32] <= 'd0;
                  cur_frame_size_valids[i] <= 1'b0;
               end else begin
                  cur_frame_sizes[i*32+:32] <= cur_frame_sizes[i*32+:32] - tx_toe_rsp_tdata[31:16];
               end
            end
         end
         assign w_frame_size_readys[i] = ~tx_ch_readys[i] || ~cur_frame_size_valids[i];
      end
   endgenerate

   // toe data
   reg [TX_AUX_FIFO_DEPTH-1:0] toe_data_to_closed;
   reg [TX_AUX_FIFO_DL:0]      toe_data_enable_counts;
   reg                         toe_data_enable;
   wire [TX_AUX_FIFO_DL:0] w_toe_data_enable_counts_next;
   always @(posedge clk) begin
      if (~resetn) begin
         toe_data_enable_counts <= 'd0;
         toe_data_enable <= 1'b0;
      end else begin
         toe_data_enable_counts <= w_toe_data_enable_counts_next;
         toe_data_enable <= |w_toe_data_enable_counts_next;
      end
   end
   generate
      for (genvar i=0; i<TX_AUX_FIFO_DEPTH; i=i+1) begin
         always @(posedge clk) begin
            if (~resetn) begin
               toe_data_to_closed[i] <= 1'b0;
            end else if (cmd_inflight && tx_toe_rsp_tvalid && tx_toe_rsp_tready &&
                         (tx_toe_rsp_tdata[15:0] == cmd_session) &&
                         (|tx_toe_rsp_tdata[31:16] || (|tx_toe_rsp_tdata[82:81] && (cmd_is_input || cmd_size != ACTIVATE_PACKET_SIZE)))) begin
               if (i != TX_AUX_FIFO_DEPTH-1) begin
                  if (tx_toe_tvalid && tx_toe_tready && tx_toe_tlast) begin
                     if (i + 1 < toe_data_enable_counts) begin
                        toe_data_to_closed[i] <= toe_data_to_closed[i+1];
                     end else if (i + 1 == toe_data_enable_counts) begin
                        toe_data_to_closed[i] <= |tx_toe_rsp_tdata[82:81];
                     end
                  end else if (i == toe_data_enable_counts) begin
                     toe_data_to_closed[i] <= |tx_toe_rsp_tdata[82:81];
                  end
               end else begin
                  toe_data_to_closed[i] <= |tx_toe_rsp_tdata[82:81];
               end
            end else if (tx_toe_tvalid && tx_toe_tready && tx_toe_tlast) begin
               if (i != TX_AUX_FIFO_DEPTH-1) begin
                  toe_data_to_closed[i] <= toe_data_to_closed[i+1];
               end else begin
                  toe_data_to_closed[i] <= 1'b0;
               end
            end
         end
      end
   endgenerate
   assign w_toe_data_enable_counts_next = toe_data_enable_counts +
                                          (cmd_inflight && tx_toe_rsp_tvalid && tx_toe_rsp_tready &&
                                          tx_toe_rsp_tdata[15:0] == cmd_session &&
                                          ((|tx_toe_rsp_tdata[31:16] && ~|tx_toe_rsp_tdata[82:81]) || (|tx_toe_rsp_tdata[82:81] && ~activate_valid))) -
                                          (w_tx_toe_valid && w_tx_toe_ready && tx_toe_tlast) +
                                          (invalidate_activate && cmd_valid && activate_valid);

   assign tx_toe_tvalid = w_tx_toe_valid && toe_data_enable && ~toe_data_to_closed[0];
   assign w_tx_toe_ready = tx_toe_tready & toe_data_enable;

   // toe rsp
   reg [31:0] toe_rsp_ip;
   reg [15:0] toe_rsp_port;
   reg [SESSION_NUM_LOG-1:0] toe_rsp_session;
   reg [2:0]                 toe_rsp_event;
   reg [15:0]                toe_rsp_len;
   reg                       toe_rsp_valid;
   reg                       toe_rsp_checking;
   reg                       toe_rsp_checking_pulse;
   reg                       toe_rsp_out;
   wire                      toe_rsp_out_ready;
   always @(posedge clk) begin
      if (~resetn) begin
         toe_rsp_valid <= 1'b0;
         toe_rsp_checking <= 1'b0;
         toe_rsp_out <= 1'b0;
      end else if (tx_toe_rsp_tvalid && tx_toe_rsp_tready &&
                   (~cmd_valid || tx_toe_rsp_tdata[15:0] != cmd_session)) begin
         toe_rsp_session <= tx_toe_rsp_tdata[15:0];
         toe_rsp_len <= tx_toe_rsp_tdata[31:16];
         {toe_rsp_ip, toe_rsp_port} <= tx_toe_rsp_tdata[79:32];
         toe_rsp_event <= tx_toe_rsp_tdata[80+:3];
         toe_rsp_valid <= 1'b1;
         toe_rsp_checking <= tx_toe_rsp_tdata[80];
         toe_rsp_checking_pulse <= tx_toe_rsp_tdata[80];
         toe_rsp_out <= ~tx_toe_rsp_tdata[80];
      end else begin
         toe_rsp_checking_pulse <= 1'b0;
         toe_rsp_checking <= toe_rsp_checking & ~connected_out_valid;
         toe_rsp_out <= (toe_rsp_out & ~toe_rsp_out_ready) || (toe_rsp_checking && connected_out_valid && ~connected_out_found);
         toe_rsp_valid <= toe_rsp_valid &&
                          ((toe_rsp_checking && (~connected_out_valid || ~connected_out_found)) ||
                           (toe_rsp_out && ~toe_rsp_out_ready));
      end
   end
   assign tx_toe_rsp_tready = ~toe_rsp_valid;
   always @(posedge clk) begin
      if (~resetn) begin
         close_valid <= 1'b0;
      end else begin
         close_session_id <= tx_toe_rsp_tdata[0+:SESSION_NUM_LOG];
         close_valid <= tx_toe_rsp_tvalid && tx_toe_rsp_tready && |tx_toe_rsp_tdata[82:81] &&
                        (~cmd_inflight || cmd_is_input || cmd_size != ACTIVATE_PACKET_SIZE);
      end
   end

   assign connected_session_id = toe_rsp_session;
   assign connected_ip = toe_rsp_ip;
   assign connected_port = toe_rsp_port;
   assign connected_valid = toe_rsp_checking_pulse;

   assign toe_rsp_out_ready = 1'b1; // for bypass out

endmodule
