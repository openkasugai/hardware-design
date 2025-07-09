/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module xdma_rx_switch #(
    parameter CH_NUM_LOG = 3,
    parameter DW = 512,
    parameter DATA_FIFO_DL = 7,
    parameter CPL_FIFO_DL = 4,
    parameter DESC_FIFO_DL = 7,
    parameter STS_FIFO_DL = 7,
    parameter DESC_MAX = 4,
    parameter DESC_RQ_DW = 512,
    parameter DESC_RQ_DK = 16,
    parameter DESC_RC_DW = 512,
    parameter DESC_RC_DK = 16,
    parameter RCBASE = 96,
    parameter BURST_MAX = 4,
    parameter CH_BASE = 0
    ) (
    input [(1<<CH_NUM_LOG)-1:0] stream_ch_valids,

    output [DESC_RQ_DW-1:0]     desc_req_data,
    output [DESC_RQ_DK-1:0]     desc_req_keep,
    output                      desc_req_valid,
    input                       desc_req_ready,

    input [DESC_RC_DW-1:0]      desc_out_data,
    input [DESC_RC_DK-1:0]      desc_out_keep,
    input                       desc_out_last,
    input                       desc_out_valid,
    output                      desc_out_ready,

    output [31:0]               desc_cpl_data,
    output [CH_NUM_LOG-1:0]     desc_cpl_ch,
    output                      desc_cpl_valid,
    input                       desc_cpl_ready,

    input [DW-1:0]              rx_in_tdata,
    input [DW/8-1:0]            rx_in_tkeep,
    input                       rx_in_tlast,
    input                       rx_in_tvalid,
    output                      rx_in_tready,

    output [15:0]               desc_ctl,
    output [63:0]               desc_src_addr,
    output [63:0]               desc_dst_addr,
    output [27:0]               desc_len,
    output                      desc_load,
    input                       desc_ready,

    input [DW-1:0]              rx_d2d_tdata,
    input [DW/8-1:0]            rx_d2d_tkeep,
    input [CH_NUM_LOG-1:0]      rx_d2d_tuser,
    input                       rx_d2d_tlast,
    input                       rx_d2d_tvalid,
    input                       rx_d2d_eof,
    output                      rx_d2d_tready,

    output [DW-1:0]             rx_out_tdata,
    output [DW/8-1:0]           rx_out_tkeep,
    output [CH_NUM_LOG-1:0]     rx_out_tuser,
    output                      rx_out_tlast,
    output                      rx_out_tvalid,
    output                      rx_out_eof,
    input                       rx_out_tready,

    input [7:0]                 sts,

    input                       clk,
    input                       resetn
    );

   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam KW = DW / 8;
   localparam KW_LOG = $clog2(KW);
   localparam BURST_MAX_LEN = 1 << (BURST_MAX + KW_LOG);

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

   wire [CH_NUM_LOG-1:0] desc_sel_ch;
   wire                  desc_sel_ch_valid;
   wire                  desc_sel_ch_ready;

   xdma_ch_select #(
       .CH_NUM_LOG ( CH_NUM_LOG )
   ) desc_ch_selector (
       .ch_valids ( desc_front_valids ),
       .req_ch ( desc_sel_ch ),
       .req_ch_valid ( desc_sel_ch_valid ),
       .req_ch_ready ( desc_sel_ch_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   reg                   desc_ready_d1;
   always @(posedge clk) begin
      if (~resetn) begin
         desc_ready_d1 <= 1'b0;
      end else begin
         desc_ready_d1 <= desc_ready;
      end
   end
   wire desc_ready_mod = desc_ready | desc_ready_d1;

   wire st_wait_fifo_ready;
   wire sts_fifo_ready;
   wire cpl_fifo_ready;
   wire eof_fifo_ready;

   reg [127:0]           cur_ch_desc_data;
   reg [15:0]            cur_ch_desc_len;
   reg [CH_NUM_LOG-1:0]  cur_ch_desc_ch;
   reg                   cur_ch_desc_final;
   reg                   cur_ch_desc_valid;
   reg                   cur_ch_desc_save;
   reg                   cur_ch_desc_sts;
   reg                   cur_ch_desc_cpl;
   reg                   cur_ch_desc_end;
   reg                   cur_ch_desc_out;
   reg                   cur_ch_desc_for_eof;
   wire [31:0]           w_desc_len;
   wire [15:0]           w_cur_desc_len;
   wire                  w_desc_sel_front_valid;
   reg [2:0]             desc_wait;
   always @(posedge clk) begin
      if (~resetn) begin
         desc_wait <= 3'd4;
         cur_ch_desc_valid <= 1'b0;
         cur_ch_desc_save <= 1'b0;
         cur_ch_desc_sts <= 1'b0;
         cur_ch_desc_cpl <= 1'b0;
         cur_ch_desc_end <= 1'b0;
         cur_ch_desc_out <= 1'b0;
         cur_ch_desc_final <= 1'b0;
         cur_ch_desc_for_eof <= 1'b0;
      end else if (desc_sel_ch_valid && desc_sel_ch_ready && w_desc_sel_front_valid && ~|desc_wait && desc_ready) begin
         cur_ch_desc_valid <= desc_sel_ch_valid;
         cur_ch_desc_data <= desc_front_data >> {desc_sel_ch, 7'd0};
         cur_ch_desc_final <= desc_front_finals >> desc_sel_ch;
         cur_ch_desc_ch <= desc_sel_ch;
         cur_ch_desc_len <= w_cur_desc_len;
         cur_ch_desc_out <= desc_sel_ch_valid;
         cur_ch_desc_save <= desc_sel_ch_valid;
         cur_ch_desc_sts<= desc_sel_ch_valid;
         cur_ch_desc_cpl <= desc_sel_ch_valid && w_desc_len <= BURST_MAX_LEN;
         cur_ch_desc_end <= desc_sel_ch_valid && w_desc_len <= BURST_MAX_LEN;
         cur_ch_desc_for_eof <= desc_sel_ch_valid && w_desc_len <= BURST_MAX_LEN;
         desc_wait <= 3'd4;
      end else begin
         cur_ch_desc_out <= 1'b0;
         cur_ch_desc_save <= cur_ch_desc_save & ~st_wait_fifo_ready;
         cur_ch_desc_sts <= cur_ch_desc_sts & ~sts_fifo_ready;
         cur_ch_desc_cpl <= cur_ch_desc_cpl & ~cpl_fifo_ready;
         cur_ch_desc_for_eof <= cur_ch_desc_for_eof & ~eof_fifo_ready;
         cur_ch_desc_valid <= 1'b0;
         if (desc_ready && |desc_wait) begin
            desc_wait <= desc_wait - 1'b1;
         end else if (~desc_ready) begin
            desc_wait <= 3'd4;
         end
      end
   end
   assign w_desc_sel_front_valid = desc_front_valids >> desc_sel_ch;
   assign w_desc_len = desc_front_data >> {desc_sel_ch, 7'd64};
   assign w_cur_desc_len = w_desc_len >= BURST_MAX_LEN ? BURST_MAX_LEN : w_desc_len;

   assign desc_update_data = {cur_ch_desc_data[127:96], cur_ch_desc_data[95:64] - cur_ch_desc_len,
                              cur_ch_desc_data[63:32], cur_ch_desc_data[31:0] + cur_ch_desc_len}; // no carry upper addr
   assign desc_update_ch = cur_ch_desc_ch;
   assign desc_update_valid = cur_ch_desc_out & ~cur_ch_desc_end;
   assign desc_fin_ready_ch = cur_ch_desc_ch;
   assign desc_fin_ready = cur_ch_desc_out & cur_ch_desc_end;

   assign desc_sel_ch_ready = ~cur_ch_desc_valid && ~cur_ch_desc_save && ~cur_ch_desc_sts &&
                              ~cur_ch_desc_cpl && ~cur_ch_desc_for_eof;

   assign desc_ctl = 16'h0010; // eop
   assign desc_src_addr = cur_ch_desc_data[63:0];
   assign desc_dst_addr = 'd0;
   assign desc_len = cur_ch_desc_len;
   assign desc_load = cur_ch_desc_valid;

   wire [CH_NUM_LOG-1:0] st_wait_ch;
   wire                  st_wait_ch_valid;
   wire                  st_wait_ch_ready;

   fifo #(
       .DW ( CH_NUM_LOG ),
       .DL ( DESC_FIFO_DL )
   ) ch_wait_fifo (
       .idata ( cur_ch_desc_ch ),
       .ivalid ( cur_ch_desc_save ),
       .iready ( st_wait_fifo_ready ),
       .odata ( st_wait_ch ),
       .ovalid ( st_wait_ch_valid ),
       .oready ( st_wait_ch_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   wire [DW-1:0]         rx_out_data;
   wire [KW-1:0]         rx_out_keep;
   wire [CH_NUM_LOG-1:0] rx_out_user;
   wire                  rx_out_last;
   wire                  rx_out_valid;
   wire                  rx_out_ready;

   fifo #(
       .DW ( DW + KW + 1 ),
       .DL ( DATA_FIFO_DL )
   ) data_fifo (
       .idata ( {rx_in_tlast, rx_in_tkeep, rx_in_tdata} ),
       .ivalid ( rx_in_tvalid ),
       .iready ( rx_in_tready ),
       .odata ( {rx_out_last, rx_out_keep, rx_out_data} ),
       .ovalid ( rx_out_valid ),
       .oready ( rx_out_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );
   assign rx_out_user = st_wait_ch;
   assign st_wait_ch_ready = rx_out_valid & rx_out_ready & rx_out_last;

   wire                  sts_end;
   wire                  sts_end_valid;
   wire                  sts_end_ready;

   fifo #(
       .DW ( 1 ),
       .DL ( STS_FIFO_DL )
   ) sts_fifo (
       .idata ( cur_ch_desc_end ),
       .ivalid ( cur_ch_desc_sts ),
       .iready ( sts_fifo_ready ),
       .odata ( sts_end ),
       .ovalid ( sts_end_valid ),
       .oready ( sts_end_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );
   assign sts_end_ready = sts[3];

   reg [CPL_FIFO_DL-1:0] cpl_out_num;
   reg                   cpl_out_enable;
   always @(posedge clk) begin
      if (~resetn) begin
         cpl_out_num <= 'd0;
         cpl_out_enable <= 1'b0;
      end else begin
         cpl_out_num <= cpl_out_num + (sts_end_valid & sts_end_ready & sts_end) - (desc_cpl_valid & desc_cpl_ready);
         cpl_out_enable <= cpl_out_num > 'd1 ||
                           (cpl_out_num == 'd1 && ~(desc_cpl_valid & desc_cpl_ready)) ||
                           (sts_end_valid & sts_end_ready & sts_end);
      end
   end

   wire                  desc_cpl_valid_pre, desc_cpl_ready_post;
   fifo #(
       .DW ( 32 + CH_NUM_LOG ),
       .DL ( CPL_FIFO_DL )
   ) cpl_fifo (
       .idata ( {cur_ch_desc_ch, cur_ch_desc_data[127:96]} ),
       .ivalid ( cur_ch_desc_cpl ),
       .iready ( cpl_fifo_ready ),
       .odata ( {desc_cpl_ch, desc_cpl_data} ),
       .ovalid ( desc_cpl_valid_pre ),
       .oready ( desc_cpl_ready_post ),
       .clk ( clk ),
       .resetn ( resetn )
   );
   assign desc_cpl_ready_post = desc_cpl_ready & cpl_out_enable;
   assign desc_cpl_valid = desc_cpl_valid_pre & cpl_out_enable;

   reg [DW*2-1:0]        out_data;
   reg [KW*2-1:0]        out_keeps;
   reg [CH_NUM_LOG*2-1:0] out_users;
   reg [1:0]              out_lasts;
   reg [1:0]              out_eofs;
   reg [1:0]              out_valids;
   reg                    is_d2d;
   reg                    is_in_packet;

   wire                   d2d_enable = (is_d2d && is_in_packet) || (~is_in_packet && (~rx_out_valid || is_d2d));
   wire                   rx_out_enable = (~is_d2d && is_in_packet) || (~is_in_packet && (~rx_d2d_tvalid || ~is_d2d));

   wire [31:0]            eof_size;
   wire                   eof_final;
   wire [CH_NUM_LOG-1:0]  eof_ch;
   wire                   eof_valid;
   wire                   eof_ready;
   fifo #(
       .DW ( 32 + 1 + CH_NUM_LOG ),
       .DL ( CPL_FIFO_DL )
   ) eof_fifo (
       .idata ( {cur_ch_desc_ch, cur_ch_desc_final, cur_ch_desc_data[127:96]} ),
       .ivalid ( cur_ch_desc_for_eof ),
       .iready ( eof_fifo_ready ),
       .odata ( {eof_ch, eof_final, eof_size} ),
       .ovalid ( eof_valid ),
       .oready ( eof_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );
   wire [CH_NUM-1:0]      w_eof_readys;
   wire [CH_NUM-1:0]      w_eof_marks;
   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         reg [31:0] cur_size;
         always @(posedge clk) begin
            if (~resetn) begin
               cur_size <= 'd0;
            end else begin
               if ((~d2d_enable || ~rx_d2d_tvalid) && rx_out_enable && rx_out_valid && ~out_valids[1] && rx_out_user == i) begin
                  if (eof_valid && eof_ch == i && cur_size + KW >= eof_size) begin
                     cur_size <= 'd0;
                  end else begin
                     cur_size <= cur_size + KW;
                  end
               end
            end
         end
         assign w_eof_readys[i] = rx_out_user == i && eof_ch == i && cur_size + KW >= eof_size;
         assign w_eof_marks[i] = eof_valid && rx_out_user == i && eof_ch == i && cur_size + KW >= eof_size && eof_final;
      end
   endgenerate
   assign eof_ready = |w_eof_readys && eof_valid &&
                      (~d2d_enable || ~rx_d2d_tvalid) && rx_out_enable && rx_out_valid && ~out_valids[1];

   always @(posedge clk) begin
       if (~resetn) begin
          out_valids <= 'd0;
          is_d2d <= 1'b0;
          is_in_packet <= 1'b0;
       end else if (d2d_enable && rx_d2d_tvalid && ~out_valids[1]) begin
          if (out_valids[0] && ~rx_out_tready) begin
             out_data[DW+:DW] <= rx_d2d_tdata;
             out_keeps[KW+:KW] <= rx_d2d_tkeep;
             out_users[CH_NUM_LOG+:CH_NUM_LOG] <= rx_d2d_tuser;
             out_lasts[1] <= rx_d2d_tlast;
             out_eofs[1] <= rx_d2d_eof;
             out_valids[1] <= 1'b1;
          end else begin
             out_data[0+:DW] <= rx_d2d_tdata;
             out_keeps[0+:KW] <= rx_d2d_tkeep;
             out_users[0+:CH_NUM_LOG] <= rx_d2d_tuser;
             out_lasts[0] <= rx_d2d_tlast;
             out_eofs[0] <= rx_d2d_eof;
             out_valids[0] <= 1'b1;
          end
          is_in_packet <= ~rx_d2d_tlast;
          is_d2d <= ~rx_d2d_tlast;
       end else if (rx_out_enable && rx_out_valid && ~out_valids[1]) begin
          if (out_valids[0] && ~rx_out_tready) begin
             out_data[DW+:DW] <= rx_out_data;
             out_keeps[KW+:KW] <= rx_out_keep;
             out_users[CH_NUM_LOG+:CH_NUM_LOG] <= rx_out_user;
             out_lasts[1] <= rx_out_last;
             out_eofs[1] <= |w_eof_marks;
             out_valids[1] <= 1'b1;
          end else begin
             out_data[0+:DW] <= rx_out_data;
             out_keeps[0+:KW] <= rx_out_keep;
             out_users[0+:CH_NUM_LOG] <= rx_out_user;
             out_lasts[0] <= rx_out_last;
             out_eofs[0] <= |w_eof_marks;
             out_valids[0] <= 1'b1;
          end
          is_in_packet <= ~rx_out_last;
          is_d2d <= rx_out_last;
       end else if (rx_out_tready) begin
          out_data <= out_data >> DW;
          out_keeps <= out_keeps >> KW;
          out_users <= out_users >> CH_NUM_LOG;
          out_lasts <= out_lasts >> 1;
          out_eofs <= out_eofs >> 1;
          out_valids <= out_valids >> 1;
          is_d2d <= is_d2d ^ (~is_in_packet);
       end
   end
   assign rx_out_ready = rx_out_enable && ~out_valids[1];
   assign rx_d2d_tready = d2d_enable && ~out_valids[1];

   assign rx_out_tdata = out_data;
   assign rx_out_tkeep = out_keeps;
   assign rx_out_tuser = out_users;
   assign rx_out_tlast = out_lasts;
   assign rx_out_eof = out_eofs;
   assign rx_out_tvalid = out_valids;

endmodule
