/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module incoming_route_controller #(
    parameter DW_LOG = 9,
    parameter CTX_ID_BITS = 5,
    parameter TDEST_BITS = 4,
    parameter EXT_RELATION = 0,
    parameter CREDIT_MAX = 4,
    parameter SELF_DEST = 0
    ) (
    // data stream input
    input [(1<<DW_LOG)-1:0]      st_in_tdata,
    input [(1<<(DW_LOG-3))-1:0]  st_in_tkeep,
    input [CTX_ID_BITS-1:0]      st_in_tuser, // context id, extract tuser[12:8] (ch_id)
    input                        st_in_tlast, // convert from tuser[6] (eop)
    input                        st_in_eof, // end of frame
    input                        st_in_tvalid,
    output                       st_in_tready,
    // data stream output
    output [(1<<DW_LOG)-1:0]     st_out_tdata,
    output [(1<<(DW_LOG-3))-1:0] st_out_tkeep,
    output [CTX_ID_BITS-1:0]     st_out_tuser,
    output [TDEST_BITS-1:0]      st_out_tdest,
    output                       st_out_tlast, // eop
    output                       st_out_tid, // eof
    output                       st_out_tvalid,
    input                        st_out_tready,
    // frame header output (to functions)
    output [127:0]               frame_header_tdata, // [63:0] frame addr, [95:64] frame size, [103:96] frame id
    output [CTX_ID_BITS-1:0]     frame_header_tuser,
    output [TDEST_BITS-1:0]      frame_header_tdest,
    output                       frame_header_tvalid,
    input                        frame_header_tready,
    // frame header consume (from functions)
    input [CTX_ID_BITS-1:0]      frame_header_consume_tuser,
    input                        frame_header_consume_tvalid,
    output                       frame_header_consume_tready,
    // frame consume input (from functions)
    input [7:0]                  frame_consume_tdata, // frame id
    input [CTX_ID_BITS-1:0]      frame_consume_tuser,
    input                        frame_consume_tvalid,
    output                       frame_consume_tready,
    // incoming frame info (from DMAC)
    input [31:0]                 frame_info_tdata, // frame size
    input [CTX_ID_BITS-1:0]      frame_info_tuser, // context id
    input                        frame_info_tvalid,
    output                       frame_info_tready,
    // incoming frame ready (to DMAC)
    output [31:0]                frame_in_ready_tdata, // frame size
    output [CTX_ID_BITS-1:0]     frame_in_ready_tuser,
    output                       frame_in_ready_tvalid,
    input                        frame_in_ready_tready,
    // outgoing frame request (to outgoing route controller)
    output reg [CTX_ID_BITS-1:0] frame_out_req_tuser,
    output reg [TDEST_BITS-1:0]  frame_out_req_tdest,
    output reg                   frame_out_req_tvalid,
    input                        frame_out_req_tready,
    // outgoing frame ready (from outgoing route controller)
    input [CTX_ID_BITS-1:0]      frame_out_ready_tuser,
    input                        frame_out_ready_tvalid,
    output                       frame_out_ready_tready,
    // frame completion out
    output [CTX_ID_BITS-1:0]     frame_completion_tuser, // ch
    output                       frame_completion_tvalid,
    // config
    input [CTX_ID_BITS+4:0]      cfg_raddr,
    input                        cfg_arvalid,
    output [31:0]                cfg_rdata,
    output                       cfg_rvalid,
    input [CTX_ID_BITS+4:0]      cfg_waddr,
    input [31:0]                 cfg_wdata,
    input                        cfg_wvalid,

    input                        clk,
    input                        resetn
    );

   localparam DW = 1 << DW_LOG;
   localparam KW_LOG = DW_LOG - 3;
   localparam KW = 1 << KW_LOG;
   localparam CH_NUM = 1 << CTX_ID_BITS;
   localparam FRAME0 = 8;
   localparam FRAME_MAX = 24;
   localparam FRAME_MAX_CEIL = 32;
   localparam FRAME_MAX_LOG = $clog2(FRAME_MAX_CEIL);
   localparam RELATION_NUM = EXT_RELATION > 0 ? 7 : 3;

   wire [CH_NUM-1:0]          ch_valids;
   wire [CH_NUM-1:0]          ch_mmapped;
   wire [CH_NUM-1:0]          disable_frame_out_requests;
   wire [CH_NUM*TDEST_BITS-1:0] ch_dests;
   wire [CH_NUM*32-1:0]         ch_frame_sizes;
   wire [CH_NUM-1:0]            ch_frame_size_variables;
   wire [CH_NUM*FRAME_MAX-1:0]  ch_frame_addr_valids;
   wire [CH_NUM*FRAME_MAX-1:0]  ch_frames_used;
   wire [CH_NUM-1:0]            ch_frame_vacants;
   wire [CH_NUM*3-1:0]          ch_relation_nums;
   wire [CH_NUM*RELATION_NUM*8-1:0] ch_relations;

   wire [CTX_ID_BITS+4:0]      addr_read_pos;
   wire                        addr_read_valid;
   wire [63:0]                 addr_read_data;
   wire                        addr_read_data_valid;

   wire [7:0]                  frame_assign_frame_id;
   wire [CTX_ID_BITS-1:0]      frame_assign_user;
   wire                        frame_assign_valid;

   route_control_regs #(
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .TDEST_BITS ( TDEST_BITS ),
       .EXT_RELATION ( EXT_RELATION )
   ) regs (
       .cfg_raddr ( cfg_raddr ),
       .cfg_arvalid ( cfg_arvalid ),
       .cfg_rdata ( cfg_rdata ),
       .cfg_rvalid ( cfg_rvalid ),
       .cfg_waddr ( cfg_waddr ),
       .cfg_wdata ( cfg_wdata ),
       .cfg_wvalid ( cfg_wvalid ),
       .ch_valids ( ch_valids ),
       .ch_mmapped ( ch_mmapped ),
       .disable_frame_out_signals ( disable_frame_out_requests ),
       .ch_dests ( ch_dests ),
       .ch_frame_sizes ( ch_frame_sizes ),
       .ch_frame_size_variables ( ch_frame_size_variables ),
       .ch_frame_addr_valids ( ch_frame_addr_valids ),
       .ch_frames_used ( ch_frames_used ),
       .ch_frame_vacants ( ch_frame_vacants ),
       .ch_relation_nums ( ch_relation_nums ),
       .ch_relations ( ch_relations ),
       .burst_max (  ),
       .addr_read_pos ( addr_read_pos ),
       .addr_read_valid ( addr_read_valid ),
       .addr_read_data ( addr_read_data ),
       .addr_read_data_valid ( addr_read_data_valid ),
       .frame_assign_frame_id ( frame_assign_frame_id ),
       .frame_assign_user ( frame_assign_user ),
       .frame_assign_valid ( frame_assign_valid ),
       .frame_release_frame_id ( frame_consume_tdata ),
       .frame_release_user ( frame_consume_tuser ),
       .frame_release_valid ( frame_consume_tvalid & frame_consume_tready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   // frame sizes
   wire                 frame_header_generate_ready;
   wire [CH_NUM-1:0]    w_frame_header_generates;
   wire [32*CH_NUM-1:0] frame_info_sizes;
   wire [CH_NUM-1:0]    frame_info_valids;

   frame_info #(
       .CTX_ID_BITS ( CTX_ID_BITS )
   ) frame_info (
       .frame_info_tdata ( frame_info_tdata ),
       .frame_info_tuser ( frame_info_tuser ),
       .frame_info_tvalid ( frame_info_tvalid ),
       .frame_info_tready ( frame_info_tready ),
       .ch_frame_sizes ( ch_frame_sizes ),
       .ch_mmapped ( ch_mmapped ),
       .frame_info_consumes ( (w_frame_header_generates & {CH_NUM{frame_header_generate_ready}}) | ~ch_valids ),
       .frame_info_valids ( frame_info_valids ),
       .frame_info_sizes ( frame_info_sizes ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   // relations solver
   reg [3*CH_NUM-1:0]   out_buf_req_nums;
   reg [3*CH_NUM-1:0]   out_buf_rsp_nums;
   reg [CH_NUM-1:0]     out_buf_req_valids;
   reg [CH_NUM-1:0]     out_buf_valids;
   reg [CH_NUM-1:0]     out_buf_resolved;
   reg [CH_NUM-1:0]     out_buf_no_related;
   wire                 relation_req_start;
   wire [CTX_ID_BITS-1:0] relation_req_start_ch;
   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         always @(posedge clk) begin
            if (~resetn || ~ch_valids[i]) begin
               out_buf_valids[i] <= 1'b0;
               out_buf_req_valids[i] <= 1'b0;
               out_buf_resolved[i] <= 1'b0;
               out_buf_no_related[i] <= 1'b0;
               out_buf_rsp_nums[3*i+:3] <= 'd0;
            end else begin
               if (~out_buf_valids[i] && frame_info_valids[i]) begin
                  out_buf_rsp_nums[3*i+:3] <= ch_relation_nums[3*i+:3];
                  out_buf_valids[i] <= 1'b1;
                  out_buf_req_valids[i] <= |ch_relation_nums[3*i+:3];
               end else begin
                  if (frame_out_ready_tvalid && frame_out_ready_tready && frame_out_ready_tuser == i) begin
                     out_buf_rsp_nums[3*i+:3] <= out_buf_rsp_nums[3*i+:3] - 1'b1;
                     if (out_buf_rsp_nums[3*i+:3] == 'd1) begin
                        out_buf_resolved[i] <= 1'b1;
                     end
                  end
                  out_buf_req_valids[i] <= out_buf_req_valids[i] & ~(relation_req_start && relation_req_start_ch == i);
                  if (w_frame_header_generates[i] && frame_header_generate_ready) begin
                     out_buf_valids[i] <= 1'b0;
                     out_buf_resolved[i] <= 1'b0;
                  end
               end
               out_buf_no_related[i] <= ~|ch_relation_nums[3*i+:3];
            end
         end
      end
   endgenerate

   // relations req/rsp
   wire [CTX_ID_BITS-1:0] relation_req_ch;
   frame_header_ch_generate #(
       .CTX_ID_BITS ( CTX_ID_BITS )
   ) relation_ch_generate (
       .frame_info_valids ( frame_info_valids & out_buf_req_valids ),
       .frame_header_gen_ch ( relation_req_ch ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   reg [CTX_ID_BITS-1:0]  relation_req_ch_reg;
   reg [2:0]              relation_req_num;
   reg                    relation_req_valid;
   reg [8*RELATION_NUM-1:0] cur_relations;
   wire [7:0]               cur_relation_target = {cur_relations, 8'd0} >> {relation_req_num, 3'b0};
   wire [CTX_ID_BITS-1:0]   cur_relation_ch = cur_relation_target;
   wire [TDEST_BITS-1:0]    cur_relation_dest = cur_relation_target >> CTX_ID_BITS;
   always @(posedge clk) begin
      if (~resetn) begin
         relation_req_valid <= 1'b0;
         frame_out_req_tvalid <= 1'b0;
      end else if (~relation_req_valid) begin
         relation_req_ch_reg <= relation_req_ch;
         relation_req_valid <= (frame_info_valids & out_buf_req_valids) >> relation_req_ch;
         relation_req_num <= ch_relation_nums >> (3 * relation_req_ch);
         cur_relations <= ch_relations >> (relation_req_ch * RELATION_NUM*8);
      end else begin
         if ((~frame_out_req_tvalid | frame_out_req_tready) && |relation_req_num) begin
            frame_out_req_tuser <= cur_relation_ch;
            frame_out_req_tdest <= cur_relation_dest;
            frame_out_req_tvalid <= 1'b1;
            relation_req_num <= relation_req_num - 1'b1;
         end else begin
            frame_out_req_tvalid <= frame_out_req_tvalid & ~frame_out_req_tready;
         end
         if (~|relation_req_num && ~frame_out_req_tvalid) relation_req_valid <= 1'b0;
      end
   end
   assign relation_req_start = ~relation_req_valid & (out_buf_req_valids >> relation_req_ch);
   assign relation_req_start_ch = relation_req_ch;

   // frame header channel generate
   wire [CH_NUM-1:0] w_frame_header_gen_valids;
   wire [CTX_ID_BITS-1:0] frame_header_gen_ch;
   frame_header_ch_generate #(
       .CTX_ID_BITS ( CTX_ID_BITS )
   ) frame_header_ch_generate (
       .frame_info_valids ( w_frame_header_gen_valids ),
       .frame_header_gen_ch ( frame_header_gen_ch ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   assign w_frame_header_gen_valids = frame_info_valids & (out_buf_resolved | out_buf_no_related) & ch_frame_vacants;
   assign w_frame_header_generates = w_frame_header_gen_valids & ({{CH_NUM-1{1'b0}}, 1'b1} << frame_header_gen_ch) & ch_valids;

   //generate
   //   for (genvar i=0; i<CH_NUM; i=i+1) begin
   //      assign w_frame_header_generates[i] = frame_info_valids[i] && out_buf_resolved[i] && ch_frame_vacants[i] &&
   //                                           frame_header_gen_ch == i && ch_valids[i];
   //   end
   //endgenerate
   assign frame_out_ready_tready = 1'b1;
   assign frame_header_consume_tready = 1'b1;

   wire [CTX_ID_BITS-1:0] frame_header_ch_reg;
   wire [TDEST_BITS-1:0]  frame_header_dest_reg;
   wire [FRAME_MAX_LOG-1:0] frame_header_idx_reg;
   wire [31:0]              frame_header_size_reg;
   wire                     frame_header_idx_found;
   wire [63:0]              frame_header_addr;
   wire                     w_frame_header_out_valid;
   wire                     w_frame_header_out_ready;

   frame_header_generate #(
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .TDEST_BITS ( TDEST_BITS ),
       .FRAME_MAX ( FRAME_MAX ),
       .FRAME_MAX_LOG ( FRAME_MAX_LOG ),
       .CREDIT_MAX ( CREDIT_MAX )
   ) header_generate (
       .frame_header_generate ( |w_frame_header_generates ),
       .frame_header_gen_ch ( frame_header_gen_ch ),
       .frame_info_valids ( frame_info_valids ),
       .frame_info_sizes ( frame_info_sizes ),
       .ch_valids ( ch_valids ),
       .ch_dests ( ch_dests ),
       .ch_mmapped ( ch_mmapped ),
       .ch_frame_addr_valids ( ch_frame_addr_valids ),
       .ch_frames_used ( ch_frames_used ),
       .disable_frame_out_signals ( disable_frame_out_requests ),
       .frame_header_generate_ready ( frame_header_generate_ready ),
       .frame_header_consume_valid ( frame_header_consume_tvalid & frame_header_consume_tready ),
       .frame_header_consume_ch ( frame_header_consume_tuser ),
       .addr_read_pos ( addr_read_pos ),
       .addr_read_valid ( addr_read_valid ),
       .addr_read_data ( addr_read_data ),
       .addr_read_data_valid ( addr_read_data_valid ),
       .frame_header_ch_reg ( frame_header_ch_reg ),
       .frame_header_dest_reg ( frame_header_dest_reg ),
       .frame_header_idx_reg ( frame_header_idx_reg ),
       .frame_header_size_reg ( frame_header_size_reg ),
       .frame_header_addr ( frame_header_addr ),
       .frame_header_out_valid ( w_frame_header_out_valid ),
       .frame_header_out_ready ( w_frame_header_out_ready ),
       .frame_header_idx_found ( frame_header_idx_found ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   assign w_frame_header_out_ready = w_frame_header_out_part_ready & w_frame_in_ready_ready;
   assign frame_assign_frame_id = frame_header_idx_reg;
   assign frame_assign_user = frame_header_ch_reg;
   assign frame_assign_valid = frame_header_idx_found;

   wire  cur_disable_frame_out_request = disable_frame_out_requests >> frame_header_ch_reg;
   axis_buf #(
       .DW ( 96 + CTX_ID_BITS + TDEST_BITS + FRAME_MAX_LOG )
   ) frame_header_buf (
       .idata ( {frame_header_dest_reg, frame_header_ch_reg, frame_header_idx_reg, frame_header_size_reg, frame_header_addr} ),
       .ivalid ( w_frame_header_out_valid & ~cur_disable_frame_out_request ),
       .iready ( w_frame_header_out_part_ready ),
       .odata ( {frame_header_tdest, frame_header_tuser, frame_header_tdata[95+FRAME_MAX_LOG:0]} ),
       .ovalid ( frame_header_tvalid ),
       .oready ( frame_header_tready ),
       .clk ( clk ),
       .resetn ( resetn )
   );
   assign frame_header_tdata[127:104+TDEST_BITS] = 'd0;
   assign frame_header_tdata[104+:TDEST_BITS] = SELF_DEST;
   assign frame_header_tdata[103:96+FRAME_MAX_LOG] = 'd0;

   axis_buf #(
       .DW ( 32 + CTX_ID_BITS )
   ) frame_in_ready_buf (
       .idata ( {frame_header_ch_reg, frame_header_size_reg} ),
       .ivalid ( w_frame_header_out_valid ),
       .iready ( w_frame_in_ready_ready ),
       .odata ( {frame_in_ready_tuser, frame_in_ready_tdata} ),
       .ovalid ( frame_in_ready_tvalid ),
       .oready ( frame_in_ready_tready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   // stream in
   wire [DW-1:0] stream_in_data;
   wire [KW-1:0] stream_in_keep;
   wire [CTX_ID_BITS-1:0] stream_in_user;
   wire                   stream_in_last;
   wire                   stream_in_eof;
   wire                   stream_in_valid;
   wire                   stream_in_ready;

   axis_buf #(
       .DW ( DW + KW + CTX_ID_BITS + 2 )
   ) stream_in_buf (
       .idata ( {st_in_eof, st_in_tlast, st_in_tuser, st_in_tkeep, st_in_tdata} ),
       .ivalid ( st_in_tvalid ),
       .iready ( st_in_tready ),
       .odata ( {stream_in_eof, stream_in_last, stream_in_user, stream_in_keep, stream_in_data} ),
       .ovalid ( stream_in_valid ),
       .oready ( stream_in_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   reg                   stream_in_sop;
   reg [CTX_ID_BITS-1:0] stream_in_ctx_id_reg;
   reg [TDEST_BITS-1:0]  stream_in_dest_reg;
   wire [TDEST_BITS-1:0]  stream_in_dest;
   wire [CTX_ID_BITS-1:0] stream_in_ctx_id;
   always @(posedge clk) begin
      if (~resetn) begin
         stream_in_sop <= 1'b1;
         stream_in_ctx_id_reg <= 'd0;
         stream_in_dest_reg <= 'd0;
      end else if (stream_in_valid & stream_in_ready) begin
         if (stream_in_sop) begin
            stream_in_ctx_id_reg <= stream_in_user;
            stream_in_dest_reg <= ch_dests >> (stream_in_user * TDEST_BITS);
         end
         stream_in_sop <= stream_in_last;
      end
   end
   assign stream_in_dest = stream_in_sop ? ch_dests >> (stream_in_user * TDEST_BITS) : stream_in_dest_reg;
   assign stream_in_ctx_id = stream_in_sop ? stream_in_user : stream_in_ctx_id_reg;

   wire stream_out_valid, stream_out_ready;

   axis_buf #(
       .DW ( DW + KW + CTX_ID_BITS + TDEST_BITS + 2 )
   ) stream_out_buf (
       .idata ( {stream_in_eof, stream_in_last, stream_in_dest, stream_in_ctx_id, stream_in_keep, stream_in_data} ),
       .ivalid ( stream_out_valid ),
       .iready ( stream_out_ready ),
       .odata ( {st_out_tid, st_out_tlast, st_out_tdest, st_out_tuser, st_out_tkeep, st_out_tdata} ),
       .ovalid ( st_out_tvalid ),
       .oready ( st_out_tready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   assign stream_out_valid = stream_in_valid;
   assign stream_in_ready = stream_out_ready;

   reg [CTX_ID_BITS-1:0] stream_eof_ch;
   reg                   stream_eof_ch_valid;
   reg [CTX_ID_BITS-1:0] frame_consume_ch;
   reg                   frame_consume_ch_valid;
   wire                  w_st_out_mmapped = ch_mmapped >> st_out_tuser;
   always @(posedge clk) begin
      if (~resetn) begin
         stream_eof_ch_valid <= 1'b0;
         frame_consume_ch_valid <= 1'b0;
      end else begin
         if (st_out_tvalid && st_out_tready && st_out_tid && ~w_st_out_mmapped) begin
            stream_eof_ch_valid <= 1'b1;
            stream_eof_ch <= st_out_tuser;
         end else begin
            stream_eof_ch_valid <= 1'b0;
         end
         if (frame_consume_tvalid && frame_consume_tready) begin
            frame_consume_ch_valid <= 1'b1;
            frame_consume_ch <= frame_consume_tuser;
         end else begin
            frame_consume_ch_valid <= frame_consume_ch_valid & stream_eof_ch_valid;
         end
      end
   end
   assign frame_completion_tuser = stream_eof_ch_valid ? stream_eof_ch : frame_consume_ch;
   assign frame_completion_tvalid = stream_eof_ch_valid | frame_consume_ch_valid;

   assign frame_consume_tready = ~frame_consume_ch_valid;

endmodule
