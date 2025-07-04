/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module axi_writer_ctrl #(
    parameter DW = 512,
    parameter CTX_ID_BITS = 5,
    parameter BURST_MAX_LOG = 4,
    parameter HEADER_FIFO_DL = 2,
    parameter HEADER_OUT_FIFO_DL = 4,
    parameter DATA_FIFO_DL = BURST_MAX_LOG + 2,
    parameter DM_STS_FIFO_DL = 5,
    parameter IDEST_BITS = 4,
    parameter DM_ADDR_BITS = 40 // ceil to multiple of 8
    ) (
    input [DW-1:0]                idata_tdata,
    input [DW/8-1:0]              idata_tkeep,
    input [CTX_ID_BITS-1:0]       idata_tuser,
    input                         idata_tlast, // eop
    input                         idata_tvalid,
    output                        idata_tready,

    output [DW-1:0]               odata_tdata,
    output [DW/8-1:0]             odata_tkeep,
    output [CTX_ID_BITS-1:0]      odata_tuser,
    output                        odata_tlast,
    output                        odata_tvalid,
    input                         odata_tready,

    output [DM_ADDR_BITS+39:0]    dm_cmd_tdata,
    output                        dm_cmd_tvalid,
    input                         dm_cmd_tready,
    input [7:0]                   dm_sts_tdata,
    input                         dm_sts_tvalid,
    output                        dm_sts_tready,

    input [127:0]                 frame_header_tdata, // [63:0] frame addr, [95:64] frame size, [103:96] frame id, [104+:ODEST_BITS] odest
    input [CTX_ID_BITS-1:0]       frame_header_tuser,
    input [IDEST_BITS-1:0]        frame_header_tdest,
    input                         frame_header_tvalid,
    output                        frame_header_tready,

    output [127:0]                frame_header_out_tdata, // [63:0] frame addr, [95:64] frame size, [103:96] frame id, [104+:ODEST_BITS] odest
    output [CTX_ID_BITS-1:0]      frame_header_out_tuser,
    output [IDEST_BITS-1:0]       frame_header_out_tdest,
    output                        frame_header_out_tvalid,
    input                         frame_header_out_tready,

    output [3:0]                  errors,
    output [(1<<CTX_ID_BITS)-1:0] underflows,

    input                         clk,
    input                         resetn
    );

   localparam CH_NUM = 1 << CTX_ID_BITS;
   localparam DW_LOG = $clog2(DW);
   localparam KW = DW/8;
   localparam KW_LOG = DW_LOG - 3;
   localparam KDIV = 4;
   localparam DIV_KW = KW/KDIV;
   localparam DIV_KW_LOG = $clog2(DIV_KW);

   wire [DW-1:0]                  idata_data;
   wire [KW-1:0]                  idata_keep;
   wire [KDIV-1:0]                idata_keep_block;
   wire [(DIV_KW_LOG+1)*KDIV-1:0] idata_keep_block_count;
   wire [CTX_ID_BITS-1:0]         idata_user;
   wire                           idata_last;
   wire                           idata_valid;
   wire                           idata_ready;

   wire [KDIV-1:0]                idata_tkeep_block;
   wire [(DIV_KW_LOG+1)*KDIV-1:0] idata_tkeep_block_count;
   generate
      for (genvar i=0; i<KDIV; i=i+1) begin
         assign idata_tkeep_block[i] = |idata_tkeep[i*DIV_KW+:DIV_KW];
         if (DIV_KW_LOG == 2) begin
            assign idata_tkeep_block_count[i*(DIV_KW_LOG+1)+:DIV_KW_LOG+1] = {2'd0, idata_tkeep[i*DIV_KW]} + idata_tkeep[i*DIV_KW+1] +
                                                                             idata_tkeep[i*DIV_KW+2] + idata_tkeep[i*DIV_KW+3];
         end else if (DIV_KW_LOG == 3) begin
            assign idata_tkeep_block_count[i*(DIV_KW_LOG+1)+:DIV_KW_LOG+1] = {3'd0, idata_tkeep[i*DIV_KW]} + idata_tkeep[i*DIV_KW+1] +
                                                                             idata_tkeep[i*DIV_KW+2] + idata_tkeep[i*DIV_KW+3] +
                                                                             idata_tkeep[i*DIV_KW+4] + idata_tkeep[i*DIV_KW+5] +
                                                                             idata_tkeep[i*DIV_KW+6] + idata_tkeep[i*DIV_KW+7];
         end else if (DIV_KW_LOG == 4) begin
            assign idata_tkeep_block_count[i*(DIV_KW_LOG+1)+:DIV_KW_LOG+1] = {4'd0, idata_tkeep[i*DIV_KW]} + idata_tkeep[i*DIV_KW+1] +
                                                                             idata_tkeep[i*DIV_KW+2] + idata_tkeep[i*DIV_KW+3] +
                                                                             idata_tkeep[i*DIV_KW+4] + idata_tkeep[i*DIV_KW+5] +
                                                                             idata_tkeep[i*DIV_KW+6] + idata_tkeep[i*DIV_KW+7] +
                                                                             idata_tkeep[i*DIV_KW+8] + idata_tkeep[i*DIV_KW+9] +
                                                                             idata_tkeep[i*DIV_KW+10] + idata_tkeep[i*DIV_KW+11] +
                                                                             idata_tkeep[i*DIV_KW+12] + idata_tkeep[i*DIV_KW+13] +
                                                                             idata_tkeep[i*DIV_KW+14] + idata_tkeep[i*DIV_KW+15];
         end
      end
   endgenerate

   axis_buf #(
       .DW ( DW + KW + KDIV * (DIV_KW_LOG + 2) + CTX_ID_BITS + 1 )
   ) ibuf (
       .idata ( {idata_tlast, idata_tuser, idata_tkeep_block_count, idata_tkeep_block, idata_tkeep, idata_tdata} ),
       .ivalid ( idata_tvalid ),
       .iready ( idata_tready ),
       .odata ( {idata_last, idata_user, idata_keep_block_count, idata_keep_block, idata_keep, idata_data} ),
       .ovalid ( idata_valid ),
       .oready ( idata_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   wire [CH_NUM-1:0]      header_active_valids;
   wire [32*CH_NUM-1:0]   header_active_sizes;
   wire [CH_NUM-1:0]      header_active_finishes;

   reg [BURST_MAX_LOG+KW_LOG:0] cur_burst_bytes;
   reg [CTX_ID_BITS-1:0] cur_burst_ch;
   reg                   cur_burst_last;
   reg                   cur_burst_ready;
   wire                  dm_cmd_enable;
   wire [KW_LOG:0]       w_keep_count;
   always @(posedge clk) begin
      if (~resetn) begin
         cur_burst_ch <= 'd0;
         cur_burst_bytes <= 'd0;
         cur_burst_last <= 1'b0;
      end else if (idata_valid & idata_ready) begin
         if (dm_cmd_enable || ~|cur_burst_bytes) begin
            cur_burst_bytes <= w_keep_count;
            cur_burst_ch <= idata_user;
         end else begin
            cur_burst_bytes <= cur_burst_bytes + w_keep_count;
         end
         cur_burst_last <= idata_last;
      end else if (dm_cmd_enable) begin
         cur_burst_bytes <= 'd0;
         cur_burst_last <= 1'b0;
      end
   end
   assign w_keep_count = idata_keep_block[3] ? {3'd3, {DIV_KW_LOG{1'b0}}} + idata_keep_block_count[3*(DIV_KW_LOG+1)+:DIV_KW_LOG+1] :
                         idata_keep_block[2] ? {2'd2, {DIV_KW_LOG{1'b0}}} + idata_keep_block_count[2*(DIV_KW_LOG+1)+:DIV_KW_LOG+1] :
                         idata_keep_block[1] ? {2'd1, {DIV_KW_LOG{1'b0}}} + idata_keep_block_count[  (DIV_KW_LOG+1)+:DIV_KW_LOG+1] :
                         {2'd0, {DIV_KW_LOG{1'b0}}} + idata_keep_block_count[0+:DIV_KW_LOG+1];
   always @(posedge clk) begin
      if (~resetn) begin
         cur_burst_ready <= 1'b1;
      end else if (~|cur_burst_bytes || dm_cmd_enable) begin
         cur_burst_ready <= ((header_active_valids & ~header_active_finishes) >> idata_user) & idata_valid;
      end else begin
         cur_burst_ready <= (header_active_valids & ~header_active_finishes) >> cur_burst_ch;
      end
   end

   reg [CTX_ID_BITS-1:0]  dm_cmd_ch;
   reg [15:0]             dm_cmd_size;
   reg                    dm_cmd_valid;
   wire                   dm_cmd_ready;
   always @(posedge clk) begin
      if (~resetn) begin
         dm_cmd_ch <= 'd0;
         dm_cmd_size <= 'd0;
         dm_cmd_valid <= 1'b0;
      end else if (~dm_cmd_valid || dm_cmd_ready) begin
         dm_cmd_valid <= dm_cmd_enable;
         dm_cmd_size <= 16'd0 | cur_burst_bytes;
         dm_cmd_ch <= cur_burst_ch;
      end else begin
         dm_cmd_valid <= dm_cmd_valid & ~dm_cmd_ready;
      end
   end
   assign dm_cmd_enable = (cur_burst_bytes[BURST_MAX_LOG+KW_LOG] || (cur_burst_ch != idata_user && |cur_burst_bytes) || cur_burst_last) &&
                          (~dm_cmd_valid || dm_cmd_ready);

   wire idata_ready_pre;
   wire idata_valid_post;
   fifo #(
       .DW ( CTX_ID_BITS + KW + DW ),
       .DL ( DATA_FIFO_DL )
   ) data_fifo (
       .idata ( {idata_user, idata_keep, idata_data} ),
       .ivalid ( idata_valid_post ),
       .iready ( idata_ready_pre ),
       .odata ( {odata_tuser, odata_tkeep, odata_tdata} ),
       .ovalid ( odata_tvalid ),
       .oready ( odata_tready ),
       .clk ( clk ),
       .resetn ( resetn )
   );
   assign odata_tlast = 1'b0;
   assign idata_valid_post = idata_valid & cur_burst_ready & (~dm_cmd_valid || dm_cmd_ready);
   assign idata_ready = idata_ready_pre & cur_burst_ready & (~dm_cmd_valid || dm_cmd_ready);

   dm_ctrl #(
       .DW ( DW ),
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .HEADER_FIFO_DL ( HEADER_FIFO_DL ),
       .HEADER_OUT_FIFO_DL ( HEADER_OUT_FIFO_DL ),
       .TDEST_BITS ( IDEST_BITS ),
       .DM_STS_FIFO_DL ( DM_STS_FIFO_DL ),
       .DM_ADDR_BITS ( DM_ADDR_BITS )
   ) dm_ctrl (
       .dm_cmd_tdata ( dm_cmd_tdata ),
       .dm_cmd_tvalid ( dm_cmd_tvalid ),
       .dm_cmd_tready ( dm_cmd_tready ),
       .dm_sts_tdata ( dm_sts_tdata ),
       .dm_sts_tvalid ( dm_sts_tvalid ),
       .dm_sts_tready ( dm_sts_tready ),
       .frame_header_tdata ( {frame_header_tdest, frame_header_tdata} ),
       .frame_header_tuser ( frame_header_tuser ),
       .frame_header_tvalid ( frame_header_tvalid ),
       .frame_header_tready ( frame_header_tready ),
       .header_active_valids ( header_active_valids ),
       .header_active_sizes ( header_active_sizes ),
       .header_active_odests (  ),
       .header_active_finishes ( header_active_finishes ),
       .cmd_out_ch ( dm_cmd_ch ),
       .cmd_out_size ( dm_cmd_size ),
       .cmd_out_valid ( dm_cmd_valid ),
       .cmd_out_fifo_ready ( 1'b1 ),
       .cmd_out_ready ( dm_cmd_ready ),
       .frame_header_consume_tdata (  ),
       .frame_header_consume_tuser (  ),
       .frame_header_consume_tvalid (  ),
       .frame_header_consume_tready ( 1'b1 ),
       .header_out_data ( {frame_header_out_tdest, frame_header_out_tdata} ),
       .header_out_user ( frame_header_out_tuser ),
       .header_out_valid ( frame_header_out_tvalid ),
       .header_out_ready ( frame_header_out_tready ),
       .errors ( errors ),
       .underflows ( underflows ),
       .clk ( clk ),
       .resetn ( resetn )
   );

endmodule
