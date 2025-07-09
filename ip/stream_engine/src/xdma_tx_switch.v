/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module xdma_tx_switch #(
    parameter CH_NUM_LOG = 3,
    parameter DW = 512,
    parameter DATA_FIFO_DL = 7,
    parameter CPL_FIFO_DL = 4,
    parameter DESC_FIFO_DL = 4,
    parameter STS_FIFO_DL = 7,
    parameter KDIV = 4,
    parameter DESC_MAX = 4,
    parameter DESC_RQ_DW = 512,
    parameter DESC_RQ_DK = 16,
    parameter DESC_RC_DW = 512,
    parameter DESC_RC_DK = 16,
    parameter RCBASE = 96,
    parameter CH_BASE = 0
    ) (
    input [(1<<CH_NUM_LOG)-1:0]  stream_ch_valids,
    input [(1<<CH_NUM_LOG)-1:0]  stream_ch_d2d_valids,
    input [(64<<CH_NUM_LOG)-1:0] stream_cpl_q_bases,

    output [DESC_RQ_DW-1:0]      desc_req_data,
    output [DESC_RQ_DK-1:0]      desc_req_keep,
    output                       desc_req_valid,
    input                        desc_req_ready,

    input [DESC_RC_DW-1:0]       desc_out_data,
    input [DESC_RC_DK-1:0]       desc_out_keep,
    input                        desc_out_last,
    input                        desc_out_valid,
    output                       desc_out_ready,

    output [31:0]                desc_cpl_data,
    output [CH_NUM_LOG-1:0]      desc_cpl_ch,
    output                       desc_cpl_valid,
    input                        desc_cpl_ready,

    input [DW-1:0]               tx_in_tdata,
    input [DW/8-1:0]             tx_in_tkeep,
    input [CH_NUM_LOG-1:0]       tx_in_tuser,
    input                        tx_in_tlast,
    input                        tx_in_sop,
    input                        tx_in_eop,
    input                        tx_in_tvalid,
    output                       tx_in_tready,

    output [15:0]                desc_ctl,
    output [63:0]                desc_src_addr,
    output [63:0]                desc_dst_addr,
    output [27:0]                desc_len,
    output                       desc_load,
    input                        desc_ready,

    output [DW-1:0]              tx_out_tdata,
    output [DW/8-1:0]            tx_out_tkeep,
    output                       tx_out_tlast,
    output                       tx_out_tvalid,
    input                        tx_out_tready,

    input [7:0]                  sts,

    input                        clk,
    input                        resetn
    );

   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam KW = DW / 8;
   localparam KW_LOG = $clog2(KW);
   localparam KW_LOG_P1 = KW_LOG + 1;
   localparam KPART = KW / KDIV;

   wire [CH_NUM-1:0]     desc_front_valids;
   wire [CH_NUM-1:0]     desc_front_finals;
   wire [128*CH_NUM-1:0] desc_front_data;
   wire [127:0]          desc_update_data;
   wire [CH_NUM_LOG-1:0] desc_update_ch;
   wire                  desc_update_valid;
   wire [CH_NUM_LOG-1:0] desc_fin_ready_ch;
   wire                  desc_fin_ready;

   xdma_trx_descriptor #(
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .DESC_MAX ( DESC_MAX ),
       .DESC_RQ_DW ( DESC_RQ_DW ),
       .DESC_RQ_DK ( DESC_RQ_DK ),
       .DESC_RC_DW ( DESC_RC_DW ),
       .DESC_RC_DK ( DESC_RC_DK ),
       .RCBASE ( RCBASE ),
       .CH_BASE ( CH_BASE )
   ) descriptor (
       .stream_ch_valids ( stream_ch_valids ),
       .desc_req_data ( desc_req_data ),
       .desc_req_valid ( desc_req_valid ),
       .desc_req_ready ( desc_req_ready ),
       .desc_in_data ( desc_out_data ),
       .desc_in_last ( desc_out_last ),
       .desc_in_valid ( desc_out_valid ),
       .desc_in_ready ( desc_out_ready ),
       .desc_front_data ( desc_front_data ),
       .desc_front_finals ( desc_front_finals ),
       .desc_front_valids ( desc_front_valids ),
       .desc_update_data ( desc_update_data ),
       .desc_update_ch ( desc_update_ch ),
       .desc_update_valid ( desc_update_valid ),
       .desc_out_ready ( desc_fin_ready ),
       .desc_out_ready_ch ( desc_fin_ready_ch ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   reg [DW-1:0]         tx_in_data_buf;
   reg [KW-1:0]         tx_in_keep_buf;
   reg [CH_NUM_LOG-1:0] tx_in_user_buf;
   reg                  tx_in_last_buf;
   reg                  tx_in_sop_buf;
   reg                  tx_in_eop_buf;
   reg                  tx_in_valid_buf;
   reg [KDIV-1:0]       tx_in_keep_sparse;
   reg [KW_LOG_P1*KDIV-1:0] tx_in_keep_pos;
   reg                  tx_in_ch_ready;
   wire                 tx_in_ready_buf;

   always @(posedge clk) begin
      if (~resetn) begin
         tx_in_valid_buf <= 1'b0;
         tx_in_ch_ready <= 1'b0;
         tx_in_user_buf <= 'd0;
         tx_in_sop_buf <= 1'b0;
      end else if (tx_in_tready) begin
         tx_in_data_buf <= tx_in_tdata;
         tx_in_keep_buf <= tx_in_tkeep;
         tx_in_last_buf <= tx_in_tlast;
         tx_in_user_buf <= tx_in_tvalid ? tx_in_tuser : tx_in_user_buf;
         tx_in_sop_buf <= tx_in_sop & tx_in_tvalid;
         tx_in_eop_buf <= tx_in_eop;
         tx_in_valid_buf <= tx_in_tvalid;
         tx_in_ch_ready <= tx_in_sop & tx_in_tvalid ? (desc_front_valids >> tx_in_tuser) : tx_in_ch_ready;
      end else begin
         tx_in_ch_ready <= tx_in_sop_buf ? (desc_front_valids >> tx_in_user_buf) : tx_in_ch_ready;
      end
   end
   generate
      for (genvar k=0; k<KDIV; k=k+1) begin
         wire [KPART-1:0] w_keep = tx_in_tkeep >> (k*KPART);
         always @(posedge clk) begin
            if (~resetn) begin
               tx_in_keep_pos[k*KW_LOG_P1+:KW_LOG_P1] <= 'd0;
            end else begin
               if (tx_in_tvalid & tx_in_tready) begin
                  tx_in_keep_sparse[k] <= w_keep[0];
                  if (KPART == 16) begin
                     tx_in_keep_pos[k*KW_LOG_P1+:KW_LOG_P1] <= k*KPART + w_keep[0] + w_keep[1] + w_keep[2] + w_keep[3] +
                                                               w_keep[4] + w_keep[5] + w_keep[6] + w_keep[7] +
                                                               w_keep[8] + w_keep[9] + w_keep[10] + w_keep[11] +
                                                               w_keep[12] + w_keep[13] + w_keep[14] + w_keep[15];
                  end else if (KPART == 8) begin
                     tx_in_keep_pos[k*KW_LOG_P1+:KW_LOG_P1] <= k*KPART + w_keep[0] + w_keep[1] + w_keep[2] + w_keep[3] +
                                                               w_keep[4] + w_keep[5] + w_keep[6] + w_keep[7];
                  end else if (KPART == 4) begin
                     tx_in_keep_pos[k*KW_LOG_P1+:KW_LOG_P1] <= k*KPART + w_keep[0] + w_keep[1] + w_keep[2] + w_keep[3];
                  end else if (KPART == 2) begin
                     tx_in_keep_pos[k*KW_LOG_P1+:KW_LOG_P1] <= k*KPART + w_keep[0] + w_keep[1];
                  end
               end
            end
         end
      end
   endgenerate

   wire [KW_LOG:0] tx_in_pos;
   generate
      if (KDIV == 8) begin
         assign tx_in_pos = tx_in_keep_sparse[7] ? tx_in_keep_pos[7*KW_LOG_P1+:KW_LOG_P1] :
                            tx_in_keep_sparse[6] ? tx_in_keep_pos[6*KW_LOG_P1+:KW_LOG_P1] :
                            tx_in_keep_sparse[5] ? tx_in_keep_pos[5*KW_LOG_P1+:KW_LOG_P1] :
                            tx_in_keep_sparse[4] ? tx_in_keep_pos[4*KW_LOG_P1+:KW_LOG_P1] :
                            tx_in_keep_sparse[3] ? tx_in_keep_pos[3*KW_LOG_P1+:KW_LOG_P1] :
                            tx_in_keep_sparse[2] ? tx_in_keep_pos[2*KW_LOG_P1+:KW_LOG_P1] :
                            tx_in_keep_sparse[1] ? tx_in_keep_pos[1*KW_LOG_P1+:KW_LOG_P1] : tx_in_keep_pos[0+:KW_LOG_P1];
      end else if (KDIV == 4) begin
         assign tx_in_pos = tx_in_keep_sparse[3] ? tx_in_keep_pos[3*KW_LOG_P1+:KW_LOG_P1] :
                            tx_in_keep_sparse[2] ? tx_in_keep_pos[2*KW_LOG_P1+:KW_LOG_P1] :
                            tx_in_keep_sparse[1] ? tx_in_keep_pos[1*KW_LOG_P1+:KW_LOG_P1] : tx_in_keep_pos[0+:KW_LOG_P1];
      end else if (KDIV == 2) begin
         assign tx_in_pos = tx_in_keep_sparse[1] ? tx_in_keep_pos[1*KW_LOG_P1+:KW_LOG_P1] : tx_in_keep_pos[0+:KW_LOG_P1];
      end
   endgenerate

   wire desc_out_fifo_ready;
   wire cpl_fifo_ready;
   wire sts_fifo_ready;
   wire desc_update_ready;
   reg  d2d_end_valid;
   reg cur_ch_desc_d2d;
   wire d2d_end_ready;
   assign tx_in_tready = (~tx_in_valid_buf || (tx_in_ready_buf && tx_in_ch_ready)) &&
                         cpl_fifo_ready && sts_fifo_ready && desc_out_fifo_ready && desc_update_ready && ~d2d_end_valid;
   assign d2d_end_ready = sts_fifo_ready && desc_out_fifo_ready && tx_in_ready_buf;

   wire [DW-1:0] w_d2d_data;
   wire [KW-1:0] w_d2d_keep;
   wire          w_d2d_eop = 1'b1;

   fifo #(
       .DW ( DW + KW + 1 ),
       .DL ( DATA_FIFO_DL )
   ) data_fifo (
       .idata ( cur_ch_desc_d2d ? {w_d2d_eop, w_d2d_keep, w_d2d_data} : {tx_in_eop_buf, tx_in_keep_buf, tx_in_data_buf} ),
       .ivalid ( (tx_in_valid_buf & tx_in_tready) | (cur_ch_desc_d2d & d2d_end_ready) ),
       .iready ( tx_in_ready_buf ),
       .odata ( {tx_out_tlast, tx_out_tkeep, tx_out_tdata} ),
       .ovalid ( tx_out_tvalid ),
       .oready ( tx_out_tready ),
       .full ( ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   reg [127:0]          cur_ch_desc_data;
   reg [15:0]           cur_ch_desc_len;
   reg [127:0]          cur_ch_desc_data_updated;
   reg [CH_NUM_LOG-1:0] cur_ch_desc_ch;
   reg                  cur_ch_desc_final;
   reg                  cur_ch_desc_out;
   reg                  cur_ch_cpl_out;
   reg                  cur_ch_sts_out;
   reg                  cur_ch_desc_end;
   reg [63:0]           cur_ch_d2d_queue_addr;
   wire [127:0] w_desc_data_pre = desc_front_data >> {tx_in_user_buf, 7'd0};
   wire         w_desc_final_pre = desc_front_finals >> tx_in_user_buf;
   wire [127:0] w_desc_data = cur_ch_desc_out && cur_ch_desc_ch == tx_in_user_buf ? cur_ch_desc_data_updated : w_desc_data_pre;
   wire         w_desc_final = cur_ch_desc_out && cur_ch_desc_ch == tx_in_user_buf ? cur_ch_desc_final : w_desc_final_pre;
   assign desc_update_ready = ~cur_ch_desc_end;

   always @(posedge clk) begin
      if (~resetn) begin
         cur_ch_cpl_out <= 1'b0;
         cur_ch_sts_out <= 1'b0;
         cur_ch_desc_out <= 1'b0;
         cur_ch_desc_end <= 1'b0;
         d2d_end_valid <= 1'b0;
         cur_ch_desc_d2d <= 1'b0;
      end else if (tx_in_valid_buf && tx_in_tready && tx_in_sop_buf) begin
         cur_ch_desc_data <= w_desc_data;
         cur_ch_desc_final <= w_desc_final;
         cur_ch_desc_ch <= tx_in_user_buf;
         if (tx_in_eop_buf) begin
            cur_ch_desc_len <= {'d0, tx_in_pos};
            cur_ch_desc_data_updated[95:64] <= w_desc_data[95:64] - tx_in_pos;
            cur_ch_desc_data_updated[31:0] <= w_desc_data[31:0] + tx_in_pos;
            cur_ch_desc_end <= w_desc_data[95:64] == tx_in_pos;
            cur_ch_cpl_out <= w_desc_data[95:64] == tx_in_pos;
            d2d_end_valid <= (stream_ch_d2d_valids >> tx_in_user_buf) & (w_desc_data[95:64] == tx_in_pos) & w_desc_final;
         end else begin
            cur_ch_desc_len <= KW;
            cur_ch_desc_data_updated[95:64] <= w_desc_data[95:64] - KW;
            cur_ch_desc_data_updated[31:0] <= w_desc_data[31:0] + KW;
            cur_ch_desc_end <= 1'b0;
            cur_ch_cpl_out <= 1'b0;
            d2d_end_valid <= 1'b0;
         end
         cur_ch_desc_data_updated[127:96] <= w_desc_data[127:96];
         cur_ch_desc_data_updated[63:32] <= w_desc_data[63:32]; // no carry
         cur_ch_desc_out <= tx_in_eop_buf;
         cur_ch_sts_out <= tx_in_eop_buf;
      end else if (tx_in_valid_buf && tx_in_tready) begin
         if (tx_in_eop_buf) begin
            cur_ch_desc_len <= cur_ch_desc_len + tx_in_pos;
            cur_ch_desc_data_updated[95:64] <= cur_ch_desc_data_updated[95:64] - tx_in_pos;
            cur_ch_desc_data_updated[31:0] <= cur_ch_desc_data_updated[31:0] + tx_in_pos;
            cur_ch_desc_end <= cur_ch_desc_data_updated[95:64] == tx_in_pos;
            cur_ch_cpl_out <= cur_ch_desc_data_updated[95:64] == tx_in_pos;
            d2d_end_valid <= (stream_ch_d2d_valids >> tx_in_user_buf) & (cur_ch_desc_data_updated[95:64] == tx_in_pos) & cur_ch_desc_final;
         end else begin
            cur_ch_desc_len <= cur_ch_desc_len + KW;
            cur_ch_desc_data_updated[95:64] <= cur_ch_desc_data_updated[95:64] - KW;
            cur_ch_desc_data_updated[31:0] <= cur_ch_desc_data_updated[31:0] + KW;
            cur_ch_desc_end <= 1'b0;
            cur_ch_cpl_out <= 1'b0;
            d2d_end_valid <= 1'b0;
         end
         cur_ch_desc_out <= tx_in_eop_buf;
         cur_ch_sts_out <= tx_in_eop_buf;
      end else begin
         cur_ch_desc_out <= cur_ch_desc_out & ~desc_out_fifo_ready;
         cur_ch_sts_out <= cur_ch_sts_out & ~sts_fifo_ready;
         cur_ch_desc_end <= cur_ch_desc_end & ~sts_fifo_ready;
         cur_ch_cpl_out <= cur_ch_cpl_out & ~cpl_fifo_ready;
         if (d2d_end_valid) begin
            d2d_end_valid <= ~cur_ch_desc_d2d | ~d2d_end_ready;
            cur_ch_desc_d2d <= d2d_end_valid & (~cur_ch_desc_d2d | ~d2d_end_ready);
            cur_ch_d2d_queue_addr <= (stream_cpl_q_bases >> {cur_ch_desc_ch, 6'd0}) + 4'd8;
         end
      end
   end
   assign desc_update_data = cur_ch_desc_data_updated;
   assign desc_update_ch = cur_ch_desc_ch;
   assign desc_update_valid = ~cur_ch_desc_end && cur_ch_sts_out & sts_fifo_ready;
   assign desc_fin_ready = cur_ch_desc_end & cur_ch_sts_out & sts_fifo_ready;
   assign desc_fin_ready_ch = cur_ch_desc_ch;
   assign w_d2d_data = {'d0, cur_ch_desc_data_updated[127:96]};
   assign w_d2d_keep = {'d0, 4'hf};

   wire desc_load_pre;
   reg [2:0] desc_wait;
   reg desc_ready_mod;
   always @(posedge clk) begin
      if (~resetn) begin
         desc_wait <= 3'd4;
         desc_ready_mod <= 1'b0;
      end else begin
         if (~desc_ready || desc_load) begin
            desc_wait <= 3'd4;
            desc_ready_mod <= 1'b0;
         end else begin
            if (|desc_wait) begin
               desc_wait <= desc_wait - 1'b1;
            end
            desc_ready_mod <= ~|desc_wait && desc_ready;
         end
      end
   end
   fifo #(
       .DW ( 16 + 64 ),
       .DL ( DESC_FIFO_DL )
   ) desc_out_fifo (
       .idata ( cur_ch_desc_d2d ? {16'h4, cur_ch_d2d_queue_addr} : {cur_ch_desc_len, cur_ch_desc_data[63:0]} ),
       .ivalid ( cur_ch_desc_out | (cur_ch_desc_d2d & d2d_end_ready) ),
       .iready ( desc_out_fifo_ready ),
       .odata ( {desc_len[15:0], desc_dst_addr} ),
       .ovalid ( desc_load_pre ),
       .oready ( desc_ready_mod ),
       .full ( ),
       .clk ( clk ),
       .resetn ( resetn )
   );
   assign desc_len[27:16] = 'd0;
   assign desc_src_addr = 'd0;
   assign desc_ctl = 16'h0010; // eop
   assign desc_load = desc_load_pre && desc_ready_mod;

   wire sts_desc_end, sts_desc_valid, sts_desc_ready;

   fifo #(
       .DW ( 1 ),
       .DL ( STS_FIFO_DL )
   ) sts_fifo (
       .idata ( cur_ch_desc_end ),
       .ivalid ( cur_ch_sts_out | (cur_ch_desc_d2d & d2d_end_ready) ),
       .iready ( sts_fifo_ready ),
       .odata ( sts_desc_end ),
       .ovalid ( sts_desc_valid ),
       .oready ( sts_desc_ready ),
       .full ( ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   reg [7:0] desc_out_num;
   reg       desc_out_enable;
   always @(posedge clk) begin
      if (~resetn) begin
         desc_out_num <= 'd0;
         desc_out_enable <= 1'b0;
      end else begin
         desc_out_num <= desc_out_num + (sts_desc_valid && sts_desc_ready) - (desc_cpl_valid && desc_cpl_ready);
         desc_out_enable <= desc_out_num > 'd1 ||
                            (desc_out_num == 'd1 && (~desc_cpl_valid || ~desc_cpl_ready)) ||
                            (sts_desc_valid && sts_desc_ready);
      end
   end
   assign sts_desc_ready = sts[3];

   wire desc_cpl_valid_pre, desc_cpl_ready_post;
   fifo #(
       .DW ( 32 + CH_NUM_LOG ),
       .DL ( CPL_FIFO_DL )
   ) cpl_fifo (
       .idata ( {cur_ch_desc_ch, cur_ch_desc_data_updated[127:96]} ),
       .ivalid ( cur_ch_cpl_out ),
       .iready ( cpl_fifo_ready ),
       .odata ( {desc_cpl_ch, desc_cpl_data} ),
       .ovalid ( desc_cpl_valid_pre ),
       .oready ( desc_cpl_ready_post ),
       .full ( ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   assign desc_cpl_valid = desc_cpl_valid_pre && desc_out_enable;
   assign desc_cpl_ready_post = desc_cpl_ready && desc_out_enable;

endmodule
