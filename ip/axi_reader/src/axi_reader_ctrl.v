/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module axi_reader_ctrl #(
    parameter DW = 512,
    parameter CTX_ID_BITS = 5,
    parameter BURST_MAX_LOG = 4,
    parameter HEADER_FIFO_DL = 2,
    parameter HEADER_OUT_FIFO_DL = 4,
    parameter DATA_FIFO_DL = BURST_MAX_LOG + 2,
    parameter DM_STS_FIFO_DL = 5,
    parameter RR_BITS = 4,
    parameter ODEST_BITS = 4,
    parameter DM_ADDR_BITS = 40 // ceil to multiple of 8
    ) (
    input [DW-1:0]                idata_tdata,
    input [DW/8-1:0]              idata_tkeep,
    input                         idata_tlast,
    input                         idata_tvalid,
    output                        idata_tready,

    output reg [DW-1:0]           odata_tdata,
    output reg [DW/8-1:0]         odata_tkeep,
    output reg [CTX_ID_BITS-1:0]  odata_tuser,
    output reg [ODEST_BITS-1:0]   odata_tdest,
    output reg                    odata_tlast, // eof
    output reg                    odata_tvalid,
    input                         odata_tready,

    output [DM_ADDR_BITS+39:0]    dm_cmd_tdata,
    output                        dm_cmd_tvalid,
    input                         dm_cmd_tready,
    input [7:0]                   dm_sts_tdata,
    input                         dm_sts_tvalid,
    output                        dm_sts_tready,

    input [127:0]                 frame_complete_tdata, // [63:0] frame addr, [95:64] frame size, [103:96] frame id, [104+:ODEST_BITS] odest
    input [CTX_ID_BITS-1:0]       frame_complete_tuser,
    input                         frame_complete_tvalid,
    output                        frame_complete_tready,

    output [127:0]                frame_complete_consume_tdata, // [63:0] frame addr, [95:64] frame size, [103:96] frame id, [104+:ODEST_BITS] odest
    output [CTX_ID_BITS-1:0]      frame_complete_consume_tuser,
    output [ODEST_BITS-1:0]       frame_complete_consume_tdest,
    output                        frame_complete_consume_tvalid,
    input                         frame_complete_consume_tready,

    output [7:0]                  frame_consume_tdata, // [7:0] frame id
    output [CTX_ID_BITS-1:0]      frame_consume_tuser,
    output [ODEST_BITS-1:0]       frame_consume_tdest,
    output                        frame_consume_tvalid,
    input                         frame_consume_tready,

    output [4:0]                  errors,
    output [(1<<CTX_ID_BITS)-1:0] underflows,

    input                         clk,
    input                         resetn
    );

   localparam CH_NUM = 1 << CTX_ID_BITS;
   localparam DW_LOG = $clog2(DW);
   localparam KW = DW/8;
   localparam ENABLE_FRAME_END = 1;
   localparam BURST_MAX_SIZE = 1 << (BURST_MAX_LOG + DW_LOG - 3);

   wire [CH_NUM-1:0]      header_active_valids;
   wire [32*CH_NUM-1:0]   header_active_sizes;
   wire [ODEST_BITS*CH_NUM-1:0] header_active_odests;
   wire [CH_NUM-1:0]      header_active_finishes;

   reg [CTX_ID_BITS-1:0]  cmd_ch;
   reg [ODEST_BITS-1:0]   cmd_dest;
   reg                    cmd_ch_valid;
   reg [15:0]             cmd_size;
   reg [CTX_ID_BITS-1:0]  cmd_ch_candidate;
   reg [ODEST_BITS-1:0]   cmd_dest_candidate;
   reg [31:0]             cmd_size_candidate;
   reg [1:0]              cmd_out_disabled;
   wire                   cmd_fifo_iready;
   wire                   cmd_ch_ready;
   wire [CTX_ID_BITS-1:0]  w_cmd_ch_candidate;
   wire [CH_NUM-1:0] need_transfers = {header_active_valids & ~header_active_finishes,
                                       header_active_valids & ~header_active_finishes} >> cmd_ch_candidate;
   generate
      if (RR_BITS == 4 && CTX_ID_BITS >= 3) begin
         assign w_cmd_ch_candidate = need_transfers[0] ? cmd_ch_candidate :
                                     need_transfers[1] ? cmd_ch_candidate + 1'b1 :
                                     need_transfers[2] ? cmd_ch_candidate + 2'd2 :
                                     need_transfers[3] ? cmd_ch_candidate + 2'd3 :
                                     need_transfers[4] ? cmd_ch_candidate + 3'd4 :
                                     need_transfers[5] ? cmd_ch_candidate + 3'd5 :
                                     need_transfers[6] ? cmd_ch_candidate + 3'd6 :
                                     need_transfers[7] ? cmd_ch_candidate + 3'd7 : cmd_ch_candidate + 4'd8;
      end else if (CTX_ID_BITS >= 2) begin
         assign w_cmd_ch_candidate = need_transfers[0] ? cmd_ch_candidate :
                                     need_transfers[1] ? cmd_ch_candidate + 1'b1 :
                                     need_transfers[2] ? cmd_ch_candidate + 2'd2 :
                                     need_transfers[3] ? cmd_ch_candidate + 2'd3 : cmd_ch_candidate + 3'd4;
      end else if (CTX_ID_BITS == 1) begin
         assign w_cmd_ch_candidate = need_transfers[0] ? cmd_ch_candidate :
                                     need_transfers[1] ? cmd_ch_candidate + 1'b1 : cmd_ch_candidate;
      end else begin
         assign w_cmd_ch_candidate = need_transfers[0] ? cmd_ch_candidate : cmd_ch_candidate + 1'b1;
      end
   endgenerate
   wire [CTX_ID_BITS-1:0] w_cmd_ch_candidate_next = cmd_ch_candidate + 1'b1;
   always @(posedge clk) begin
      if (~resetn) begin
         cmd_ch_candidate <= 'd0;
         cmd_dest_candidate <= 'd0;
         cmd_size_candidate <= 'd0;
         cmd_ch <= 'd0;
         cmd_dest <= 'd0;
         cmd_ch_valid <= 1'b0;
         cmd_out_disabled <= 'd0;
      end else begin
         if (~cmd_ch_valid && ~|cmd_out_disabled && need_transfers[0]) begin
            cmd_ch_candidate <= w_cmd_ch_candidate_next;
            cmd_size_candidate <= header_active_sizes >> {w_cmd_ch_candidate_next, 5'd0};
            cmd_dest_candidate <= header_active_odests >> (w_cmd_ch_candidate_next * ODEST_BITS);
            cmd_ch <= cmd_ch_candidate;
            cmd_dest <= cmd_dest_candidate;
            cmd_ch_valid <= need_transfers[0] && |cmd_size_candidate;
            cmd_size <= cmd_size_candidate >= BURST_MAX_SIZE ? BURST_MAX_SIZE : cmd_size_candidate;
            cmd_out_disabled <= cmd_out_disabled << 1;
         end else begin
            cmd_ch_candidate <= w_cmd_ch_candidate;
            cmd_dest_candidate <= header_active_odests >> (w_cmd_ch_candidate * ODEST_BITS);
            cmd_size_candidate <= header_active_sizes >> {w_cmd_ch_candidate, 5'd0};
            if (|cmd_out_disabled) begin
               cmd_out_disabled <= cmd_out_disabled << 1;
            end else begin
               cmd_ch_valid <= cmd_ch_valid & ~cmd_ch_ready;
               cmd_out_disabled <= {1'b0, cmd_ch_valid & cmd_ch_ready};
            end
         end
      end
   end

   wire [95:0] frame_consume_dummy_lower;
   wire [127:104] frame_consume_dummy_upper;
   dm_ctrl #(
       .DW ( DW ),
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .HEADER_FIFO_DL ( HEADER_FIFO_DL ),
       .HEADER_OUT_FIFO_DL ( HEADER_OUT_FIFO_DL ),
       .TDEST_BITS ( 0 ),
       .DM_STS_FIFO_DL ( DM_STS_FIFO_DL ),
       .ENABLE_FRAME_END ( ENABLE_FRAME_END ),
       .DM_ADDR_BITS ( DM_ADDR_BITS )
   ) dm_ctrl (
       .dm_cmd_tdata ( dm_cmd_tdata ),
       .dm_cmd_tvalid ( dm_cmd_tvalid ),
       .dm_cmd_tready ( dm_cmd_tready ),
       .dm_sts_tdata ( dm_sts_tdata ),
       .dm_sts_tvalid ( dm_sts_tvalid ),
       .dm_sts_tready ( dm_sts_tready ),
       .frame_header_tdata ( frame_complete_tdata ),
       .frame_header_tuser ( frame_complete_tuser ),
       .frame_header_tvalid ( frame_complete_tvalid ),
       .frame_header_tready ( frame_complete_tready ),
       .header_active_valids ( header_active_valids ),
       .header_active_sizes ( header_active_sizes ),
       .header_active_odests ( header_active_odests ),
       .header_active_finishes ( header_active_finishes ),
       .cmd_out_ch ( cmd_ch ),
       .cmd_out_size ( cmd_size ),
       .cmd_out_valid ( cmd_ch_valid ),
       .cmd_out_fifo_ready ( cmd_fifo_iready ),
       .cmd_out_ready ( cmd_ch_ready ),
       .frame_header_consume_tdata ( frame_complete_consume_tdata ),
       .frame_header_consume_tuser ( frame_complete_consume_tuser ),
       .frame_header_consume_tvalid ( frame_complete_consume_tvalid ),
       .frame_header_consume_tready ( frame_complete_consume_tready ),
       .header_out_data ( {frame_consume_dummy_upper, frame_consume_tdata, frame_consume_dummy_lower} ),
       .header_out_user ( frame_consume_tuser ),
       .header_out_valid ( frame_consume_tvalid ),
       .header_out_ready ( frame_consume_tready ),
       .errors ( errors[3:0] ),
       .underflows ( underflows ),
       .clk ( clk ),
       .resetn ( resetn )
   );
   assign frame_complete_consume_tdest = frame_complete_consume_tdata[104+:ODEST_BITS];
   assign frame_consume_tdest = frame_consume_dummy_upper[104+:ODEST_BITS];

   wire [CTX_ID_BITS-1:0] cmd_out_ch;
   wire [ODEST_BITS-1:0]  cmd_out_dest;
   wire [15:0]            cmd_out_size;
   wire                   cmd_out_local_valid, cmd_out_local_ready;

   fifo #(
       .DW ( ODEST_BITS + CTX_ID_BITS + 16),
       .DL ( DM_STS_FIFO_DL )
   ) cmd_fifo (
       .idata ( {cmd_dest, cmd_ch, cmd_size} ),
       .ivalid ( cmd_ch_valid & cmd_ch_ready ),
       .iready ( cmd_fifo_iready ),
       .odata ( {cmd_out_dest, cmd_out_ch, cmd_out_size} ),
       .ovalid ( cmd_out_local_valid ),
       .oready ( cmd_out_local_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   wire [DW-1:0]          mdata_tdata;
   wire [KW-1:0]          mdata_tkeep;
   wire                   mdata_tlast, mdata_tvalid, mdata_tready;

   fifo #(
       .DW ( DW + KW + 1 ),
       .DL ( DATA_FIFO_DL )
   ) data_fifo (
       .idata ( {idata_tlast, idata_tkeep, idata_tdata} ),
       .ivalid ( idata_tvalid ),
       .iready ( idata_tready ),
       .odata ( {mdata_tlast, mdata_tkeep, mdata_tdata} ),
       .ovalid ( mdata_tvalid ),
       .oready ( mdata_tready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   reg [15:0]             cur_remain;
   reg [CTX_ID_BITS-1:0]  cur_ch;
   reg [ODEST_BITS-1:0]   cur_dest;
   always @(posedge clk) begin
      if (~resetn) begin
         cur_remain <= 'd0;
         cur_ch <= 'd0;
         cur_dest <= 'd0;
      end else if (cmd_out_local_valid && cmd_out_local_ready) begin
         cur_remain <= cmd_out_size;
         cur_ch <= cmd_out_ch;
         cur_dest <= cmd_out_dest;
      end else if (mdata_tvalid & mdata_tready) begin
         if (cur_remain >= (16'd1 << (DW_LOG-3))) begin
            cur_remain <= cur_remain - (16'd1 << (DW_LOG-3));
         end else begin
            cur_remain <= 'd0;
         end
      end
   end
   assign cmd_out_local_ready = ~|cur_remain || (cur_remain <= (16'd1 << (DW_LOG-3)) && mdata_tvalid & mdata_tready);

   always @(posedge clk) begin
      if (~resetn) begin
         odata_tvalid <= 1'b0;
      end else if (mdata_tvalid && mdata_tready) begin
         odata_tvalid <= 1'b1;
         odata_tuser <= |cur_remain ? cur_ch : cmd_out_ch;
         odata_tdest <= |cur_remain ? cur_dest : cmd_out_dest;
         {odata_tlast, odata_tkeep, odata_tdata} <= {mdata_tlast, mdata_tkeep, mdata_tdata};
      end else begin
         odata_tvalid <= odata_tvalid & ~odata_tready;
      end
   end
   assign mdata_tready = (~odata_tvalid || odata_tready) && (cmd_out_local_valid || |cur_remain);
   assign errors[4] = ~cmd_fifo_iready && cmd_ch_valid & cmd_ch_ready;

endmodule
