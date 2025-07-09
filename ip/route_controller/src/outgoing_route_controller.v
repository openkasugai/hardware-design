/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module outgoing_route_controller #(
    parameter DW_LOG = 9,
    parameter CTX_ID_BITS = 5,
    parameter TDEST_BITS = 4,
    parameter BURST_BITS = 4,
    parameter EXT_RELATION = 0,
    parameter CREDIT_MAX = 4,
    parameter SELF_DEST = 0,
    parameter KDIV = 4
    ) (
    // data stream input
    input [(1<<DW_LOG)-1:0]      st_in_tdata,
    input [(1<<(DW_LOG-3))-1:0]  st_in_tkeep,
    input [CTX_ID_BITS-1:0]      st_in_tuser,
    input                        st_in_tlast, // eof
    input                        st_in_tvalid,
    output                       st_in_tready,
    // data stream output
    output [(1<<DW_LOG)-1:0]     st_out_tdata,
    output [(1<<(DW_LOG-3))-1:0] st_out_tkeep,
    output [CTX_ID_BITS-1:0]     st_out_tuser,
    output                       st_out_tlast, // end of frame
    output                       st_out_sop, // start of packet (optional for fdma2)
    output                       st_out_eop, // end of packet (optional for fdma2)
    output [BURST_BITS-1:0]      st_out_burst, // optional only for fdma2
    output [DW_LOG-4:0]          st_out_last_cnt, // optional for toe_ctrl
    output                       st_out_tvalid,
    input                        st_out_tready,
    // frame header output (to functions)
    output [127:0]               frame_header_tdata, // [63:0] frame addr, [95:64] frame size(max), [103:96] frame id, [104+:TDEST_BITS] dest
    output [CTX_ID_BITS-1:0]     frame_header_tuser,
    output [TDEST_BITS-1:0]      frame_header_tdest,
    output                       frame_header_tvalid,
    input                        frame_header_tready,
    // frame completion input (from functions (direct or via data mover)
    input [127:0]                frame_complete_tdata, // [63:0] frame addr, [95:64] frame size, [103:96] frame id, [104+:TDEST_BITS] dest
    input [CTX_ID_BITS-1:0]      frame_complete_tuser,
    input                        frame_complete_tvalid,
    output                       frame_complete_tready,
    // frame consume input (from AXI reader)
    input [7:0]                  frame_consume_tdata, // [7:0] frame id
    input [CTX_ID_BITS-1:0]      frame_consume_tuser,
    input                        frame_consume_tvalid,
    output                       frame_consume_tready,
    // incoming buffer info (from DMAC)
    input [31:0]                 buffer_info_tdata, // frame size
    input [CTX_ID_BITS-1:0]      buffer_info_tuser, // context id
    input                        buffer_info_tvalid,
    output                       buffer_info_tready,
    // outgoing frame ready (to DMAC)
    output [31:0]                frame_info_tdata, // frame size
    output [CTX_ID_BITS-1:0]     frame_info_tuser,
    output                       frame_info_tvalid,
    input                        frame_info_tready,
    // outgoin frame request (from incoming route controller)
    input [CTX_ID_BITS-1:0]      frame_out_req_tuser,
    input                        frame_out_req_tvalid,
    output                       frame_out_req_tready,
    // outgoing frame ready (to incoming route controller)
    output reg [CTX_ID_BITS-1:0] frame_out_ready_tuser,
    output reg [TDEST_BITS-1:0]  frame_out_ready_tdest,
    output reg                   frame_out_ready_tvalid,
    input                        frame_out_ready_tready,
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

   // streaming
   //  - buffer info -> frame_out_ready, frame_header
   //  - frame_complete -> frame_info
   // mmapped
   //  - frame_out_req -> frame_out_ready, frame_header
   //  - frame_complete, buffer info -> frame_info
   //  - frame_consume -> release buffer

   localparam DW = 1 << DW_LOG;
   localparam CH_NUM = 1 << CTX_ID_BITS;
   localparam FRAME0 = 4;
   localparam FRAME_MAX = 24;
   localparam FRAME_MAX_CEIL = 32;
   localparam FRAME_MAX_LOG = $clog2(FRAME_MAX_CEIL);
   localparam RELATION_NUM = EXT_RELATION > 0 ? 7 : 3;

   wire [CH_NUM-1:0]          ch_valids;
   wire [CH_NUM-1:0]          ch_mmapped;
   wire [CH_NUM-1:0]          disable_frame_out_requests;
   wire [CH_NUM*TDEST_BITS-1:0] ch_dests;
   wire [CH_NUM*32-1:0]         ch_frame_sizes;
   wire [CH_NUM*FRAME_MAX-1:0]  ch_frame_addr_valids;
   wire [CH_NUM*FRAME_MAX-1:0]  ch_frames_used;
   wire [CH_NUM-1:0]            ch_frame_vacants;
   wire [CH_NUM*3-1:0]          ch_relation_nums;
   wire [CH_NUM*RELATION_NUM*8-1:0] ch_relations;
   wire [BURST_BITS:0]              burst_max;

   wire [CTX_ID_BITS+4:0]      addr_read_pos;
   wire                        addr_read_valid;
   wire [63:0]                 addr_read_data;
   wire                        addr_read_data_valid;

   wire [7:0]                  frame_assign_frame_id;
   wire [CTX_ID_BITS-1:0]      frame_assign_user;
   wire                        frame_assign_valid;

   wire [7:0]                  frame_release_frame_id;
   wire [CTX_ID_BITS-1:0]      frame_release_user;
   wire                        frame_release_valid;

   route_control_regs #(
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .TDEST_BITS ( TDEST_BITS ),
       .EXT_RELATION ( EXT_RELATION ),
       .BURST_BITS ( BURST_BITS )
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
       .ch_frame_addr_valids ( ch_frame_addr_valids ),
       .ch_frames_used ( ch_frames_used ),
       .ch_frame_vacants ( ch_frame_vacants ),
       .ch_relation_nums ( ch_relation_nums ),
       .ch_relations ( ch_relations ),
       .burst_max ( burst_max ),
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

   assign frame_consume_tready = 1'b1;

   // frame sizes
   wire [CH_NUM-1:0]    w_buffer_info_consumes;
   wire [32*CH_NUM-1:0] buffer_info_sizes;
   wire [CH_NUM-1:0]    buffer_info_valids;

   frame_info #(
       .CTX_ID_BITS ( CTX_ID_BITS )
   ) buffer_info (
       .frame_info_tdata ( buffer_info_tdata ),
       .frame_info_tuser ( buffer_info_tuser ),
       .frame_info_tvalid ( buffer_info_tvalid ),
       .frame_info_tready ( buffer_info_tready ),
       .ch_frame_sizes ( ch_frame_sizes ),
       .ch_mmapped ( ch_mmapped ),
       .frame_info_consumes ( w_buffer_info_consumes ),
       .frame_info_valids ( buffer_info_valids ),
       .frame_info_sizes ( buffer_info_sizes ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   // relations solver
   wire [CH_NUM-1:0]      w_frame_header_generates;
   wire [CTX_ID_BITS-1:0] frame_header_gen_ch;
   wire                   frame_header_generate_ready;
   reg [3*CH_NUM-1:0]     frame_out_req_nums;
   reg [CH_NUM-1:0]       in_buf_valids;
   reg [CH_NUM-1:0]       in_buf_resolved;
   reg [CH_NUM-1:0]       in_buf_no_related;
   wire [CTX_ID_BITS-1:0] in_buf_resolve_ch;
   wire                   in_buf_resolve_end;
   reg [CTX_ID_BITS-1:0]  relation_rsp_ch_reg;
   reg [CTX_ID_BITS-1:0]  frame_out_req_id_saved;
   reg                    frame_out_req_id_valid;
   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         wire [2:0] w_cur_frame_out_req_num = frame_out_req_nums[i*3+:3]
                    + (frame_out_req_id_valid && frame_out_req_id_saved == i);
         always @(posedge clk) begin
            if (~resetn || ~ch_valids[i]) begin
               frame_out_req_nums[i*3+:3] <= 'd0;
               in_buf_valids[i] <= 1'b0;
               in_buf_resolved[i] <= 1'b0;
               in_buf_no_related[i] <= 1'b0;
            end else begin
               if (~in_buf_valids[i]) begin
                  frame_out_req_nums[i*3+:3] <= w_cur_frame_out_req_num;
                  in_buf_valids[i] <= w_cur_frame_out_req_num == ch_relation_nums[3*i+:3] && |ch_relation_nums[3*i+:3];
               end
               if (in_buf_resolve_end && relation_rsp_ch_reg == i) begin
                  in_buf_resolved[i] <= 1'b1;
                  in_buf_valids[i] <= 1'b0;
                  frame_out_req_nums[i*3+:3] <= 3'd0;
               end else if (w_frame_header_generates[i] && frame_header_gen_ch == i && frame_header_generate_ready) begin
                  in_buf_resolved[i] <= 1'b0;
               end
               in_buf_no_related[i] <= ~|ch_relation_nums[3*i+:3];
            end
         end
      end
   endgenerate

   wire                  frame_out_req_ch_ready;
   always @(posedge clk) begin
      if (~resetn) begin
         frame_out_req_id_valid <= 1'b0;
      end else if (frame_out_req_tvalid & frame_out_req_tready) begin
         frame_out_req_id_valid <= 1'b1;
         frame_out_req_id_saved <= frame_out_req_tuser;
      end else if (frame_out_req_id_valid) begin
         frame_out_req_id_valid <= frame_out_req_id_valid & ~frame_out_req_ch_ready;
      end
   end
   assign frame_out_req_ch_ready = ~in_buf_valids >> frame_out_req_id_saved;
   assign frame_out_req_tready = ~frame_out_req_id_valid;

   wire [CH_NUM-1:0] relation_start_enables = buffer_info_valids & in_buf_valids & ~in_buf_resolved & ch_frame_vacants;
   frame_header_ch_generate #(
       .CTX_ID_BITS ( CTX_ID_BITS )
   ) relation_ch_generate (
       .frame_info_valids ( relation_start_enables ),
       .frame_header_gen_ch ( in_buf_resolve_ch ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   reg                    relation_rsp_valid;
   reg [2:0]              relation_rsp_num;
   reg [8*RELATION_NUM-1:0] cur_relations;
   wire [7:0]               cur_relation_target = {cur_relations, 8'd0} >> {relation_rsp_num, 3'b0};
   wire [CTX_ID_BITS-1:0]   cur_relation_ch = cur_relation_target;
   wire [TDEST_BITS-1:0]    cur_relation_dest = cur_relation_target >> CTX_ID_BITS;
   always @(posedge clk) begin
      if (~resetn) begin
         relation_rsp_valid <= 1'b0;
         frame_out_ready_tvalid <= 1'b0;
      end else if (~relation_rsp_valid) begin
         relation_rsp_valid <= relation_start_enables >> in_buf_resolve_ch;
         relation_rsp_ch_reg <= in_buf_resolve_ch;
         relation_rsp_num <= ch_relation_nums >> (3*in_buf_resolve_ch);
         cur_relations <= ch_relations >> (in_buf_resolve_ch * RELATION_NUM*8);
      end else begin
         if ((~frame_out_ready_tvalid | frame_out_ready_tready) && |relation_rsp_num) begin
            frame_out_ready_tuser <= cur_relation_ch;
            frame_out_ready_tdest <= cur_relation_dest;
            frame_out_ready_tvalid <= 1'b1;
            relation_rsp_num <= relation_rsp_num - 1'b1;
         end else begin
            frame_out_ready_tvalid <= frame_out_ready_tvalid & ~frame_out_ready_tready;
         end
         if (~|relation_rsp_num && ~frame_out_ready_tvalid) relation_rsp_valid <= 1'b0;
      end
   end
   assign in_buf_resolve_end = relation_rsp_valid && ~|relation_rsp_num && ~frame_out_ready_tvalid;

   // frame header channel generate
   wire                   frame_header_gen_ch_valid;
   reg                    frame_header_generate_d1;
   always @(posedge clk) begin
      if (~resetn) begin
         frame_header_generate_d1 <= 1'b0;
      end else begin
         frame_header_generate_d1 <= |w_frame_header_generates & frame_header_generate_ready;
      end
   end
   wire [CH_NUM-1:0] w_frame_header_gen_valids;
   frame_header_ch_generate #(
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .ENABLE_BUSY ( 1 )
   ) frame_header_ch_generate (
       .frame_info_valids ( w_frame_header_gen_valids ),
       .frame_header_gen_ch_reset ( frame_header_generate_d1 ),
       .frame_header_gen_ch ( frame_header_gen_ch ),
       .frame_header_gen_ch_valid ( frame_header_gen_ch_valid ),
       .clk ( clk ),
       .resetn ( resetn )
   );
   assign w_frame_header_gen_valids = buffer_info_valids & (in_buf_no_related | in_buf_resolved) & ch_frame_vacants;
   assign w_frame_header_generates = w_frame_header_gen_valids & {CH_NUM{frame_header_gen_ch_valid}};

   // frame header generate
   wire [CTX_ID_BITS-1:0] frame_header_ch_reg;
   wire [TDEST_BITS-1:0]  frame_header_dest_reg;
   wire [FRAME_MAX_LOG-1:0] frame_header_idx_reg;
   wire [31:0]              frame_header_size_reg;
   wire                     frame_header_idx_found;
   wire [63:0]              frame_header_addr;
   wire                     w_frame_header_out_valid;
   wire                     w_frame_header_out_ready;
   wire [32*CH_NUM-1:0]     w_buffer_sizes;
   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         wire ch_frame_small = ch_frame_sizes[i*32+:32] < buffer_info_sizes[i*32+:32];
         assign w_buffer_sizes[32*i+:32] = ch_mmapped[i] && ch_frame_small ? ch_frame_sizes[i*32+:32] : buffer_info_sizes[i*32+:32];
      end
   endgenerate

   wire w_frame_header_generate = w_frame_header_generates >> frame_header_gen_ch;
   frame_header_generate #(
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .TDEST_BITS ( TDEST_BITS ),
       .FRAME_MAX ( FRAME_MAX ),
       .FRAME_MAX_LOG ( FRAME_MAX_LOG ),
       .CREDIT_MAX ( CREDIT_MAX )
   ) header_generate (
       .frame_header_generate ( w_frame_header_generate ),
       .frame_header_gen_ch ( frame_header_gen_ch ),
       .frame_info_valids ( buffer_info_valids ),
       .frame_info_sizes ( w_buffer_sizes ),
       .ch_valids ( ch_valids ),
       .ch_dests ( ch_dests ),
       .ch_mmapped ( ch_mmapped ),
       .ch_frame_addr_valids ( ch_frame_addr_valids ),
       .ch_frames_used ( ch_frames_used ),
       .disable_frame_out_signals ( disable_frame_out_requests ),
       .frame_header_generate_ready ( frame_header_generate_ready ),
       .frame_header_consume_valid ( frame_complete_tvalid & frame_complete_tready ),
       .frame_header_consume_ch ( frame_complete_tuser ),
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

   assign frame_assign_frame_id = frame_header_idx_reg;
   assign frame_assign_user = frame_header_ch_reg;
   assign frame_assign_valid = frame_header_idx_found;

   wire  cur_disable_frame_out_request = disable_frame_out_requests >> frame_header_ch_reg;
   axis_buf #(
       .DW ( 96 + CTX_ID_BITS + TDEST_BITS + FRAME_MAX_LOG )
   ) frame_header_buf (
       .idata ( {frame_header_dest_reg, frame_header_ch_reg, frame_header_idx_reg, frame_header_size_reg, frame_header_addr} ),
       .ivalid ( w_frame_header_out_valid & ~cur_disable_frame_out_request ),
       .iready ( w_frame_header_out_ready ),
       .odata ( {frame_header_tdest, frame_header_tuser, frame_header_tdata[95+FRAME_MAX_LOG:0]} ),
       .ovalid ( frame_header_tvalid ),
       .oready ( frame_header_tready ),
       .clk ( clk ),
       .resetn ( resetn )
   );
   assign frame_header_tdata[127:104+TDEST_BITS] = 'd0;
   assign frame_header_tdata[104+:TDEST_BITS] = SELF_DEST;
   assign frame_header_tdata[103:96+FRAME_MAX_LOG] = 'd0;

   // complete input
   reg [CTX_ID_BITS-1:0] complete_ch;
   reg                   complete_valid;
   reg [31:0]            complete_size;
   reg [63:0]            complete_addr;
   wire                  cur_complete_buffer_info_valid;
   wire                  frame_info_ready;

   always @(posedge clk) begin
      if (~resetn) begin
         complete_valid <= 1'b0;
      end else if (frame_complete_tvalid & frame_complete_tready) begin
         complete_valid <= 1'b1;
         complete_ch <= frame_complete_tuser;
         complete_size <= frame_complete_tdata[95:64];
         complete_addr <= frame_complete_tdata[63:0];
      end else begin
         if (cur_complete_buffer_info_valid && frame_info_ready) begin
            complete_valid <= 1'b0;
         end
      end
   end
   assign cur_complete_buffer_info_valid = 1'b1; //(buffer_info_valids | ~ch_mmapped) >> complete_ch;
   assign frame_complete_tready = ~complete_valid;

   axis_buf #(
       .DW ( 32 + CTX_ID_BITS )
   ) frame_info_buf (
       .idata ( {complete_ch, complete_size} ),
       .ivalid ( cur_complete_buffer_info_valid && complete_valid ),
       .iready ( frame_info_ready ),
       .odata ( {frame_info_tuser, frame_info_tdata} ),
       .ovalid ( frame_info_tvalid ),
       .oready ( frame_info_tready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         assign w_buffer_info_consumes[i] = (buffer_info_valids[i] && w_frame_header_generates[i] && frame_header_generate_ready && frame_header_gen_ch == i) || ~ch_valids[i];
         //&& ~ch_mmapped[i]) ||
         //(ch_mmapped[i] && cur_complete_buffer_info_valid && frame_info_ready && complete_valid && complete_ch == i) || ~ch_valids[i];
      end
   endgenerate

   outgoing_fifo #(
       .DW_LOG ( DW_LOG ),
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .BURST_BITS ( BURST_BITS ),
       .KDIV ( KDIV )
   ) fifo (
       .i_tdata ( st_in_tdata ),
       .i_tkeep ( st_in_tkeep ),
       .i_tuser ( st_in_tuser ),
       .i_tlast ( st_in_tlast ),
       .i_tvalid ( st_in_tvalid ),
       .i_tready ( st_in_tready ),
       .o_tdata ( st_out_tdata ),
       .o_tkeep ( st_out_tkeep ),
       .o_tuser ( st_out_tuser ),
       .o_tlast ( st_out_tlast ),
       .o_sop ( st_out_sop ),
       .o_eop ( st_out_eop ),
       .o_burst ( st_out_burst ),
       .o_last_cnt ( st_out_last_cnt ),
       .o_tvalid ( st_out_tvalid ),
       .o_tready ( st_out_tready ),
       .burst_max ( burst_max ),
       .clk ( clk ),
       .resetn ( resetn )
   );

endmodule

module outgoing_fifo #(
    parameter DW_LOG = 9,
    parameter CTX_ID_BITS = 4,
    parameter BURST_BITS = 4,
    parameter KDIV = 4
    ) (
    input [(1<<DW_LOG)-1:0]      i_tdata,
    input [(1<<(DW_LOG-3))-1:0]  i_tkeep,
    input [CTX_ID_BITS-1:0]      i_tuser,
    input                        i_tlast,
    input                        i_tvalid,
    output                       i_tready,

    output [(1<<DW_LOG)-1:0]     o_tdata,
    output [(1<<(DW_LOG-3))-1:0] o_tkeep,
    output [CTX_ID_BITS-1:0]     o_tuser,
    output                       o_tlast,
    output                       o_sop,
    output                       o_eop,
    output [BURST_BITS-1:0]      o_burst,
    output [DW_LOG-4:0]          o_last_cnt,
    output                       o_tvalid,
    input                        o_tready,

    input [BURST_BITS:0]         burst_max,

    input                        clk,
    input                        resetn
    );

   localparam KW_LOG = DW_LOG - 3;
   localparam DW = 1 << DW_LOG;
   localparam KW = 1 << KW_LOG;
   localparam DEPTH = 4 << BURST_BITS;

   reg [DW-1:0]         data_mem[0:DEPTH-1];
   reg [KW-1:0]         keep_mem[0:DEPTH-1];
   reg [CTX_ID_BITS:0]  aux_mem[0:DEPTH-1];
   reg [BURST_BITS+2:0] wpos;
   reg [BURST_BITS+2:0] rpos;

   reg [BURST_BITS+(KW+1)*KDIV-1:0] burst_mem[0:7];
   reg [3:0]            burst_wpos;
   reg [3:0]            burst_rpos;

   reg                  is_full;
   reg                  is_data_empty;
   reg                  is_burst_empty;

   wire                 data_wen;
   wire                 burst_wen;
   reg [BURST_BITS:0]   burst_len;

   reg [DW-1:0]         rdata;
   reg [KW-1:0]         rkeep;
   reg [CTX_ID_BITS-1:0] ruser;
   reg                   rlast;
   reg [BURST_BITS:0]    rburst;
   reg [(KW_LOG+1)*KDIV-1:0] rkeep_part_cnts;
   wire [BURST_BITS+2:0] wpos_next, rpos_next;
   wire [3:0] burst_wpos_next, burst_rpos_next;
   reg [(KW_LOG+1)*KDIV-1:0] keep_part_cnts;
   wire [(KW_LOG+1)*KDIV-1:0] w_keep_part_cnts;

   always @(posedge clk) begin
      if (data_wen) data_mem[wpos[BURST_BITS+1:0]] <= i_tdata;
      rdata <= data_mem[rpos_next[BURST_BITS+1:0]];
   end
   always @(posedge clk) begin
      if (data_wen) keep_mem[wpos[BURST_BITS+1:0]] <= i_tkeep;
      rkeep <= keep_mem[rpos_next[BURST_BITS+1:0]];
   end
   always @(posedge clk) begin
      if (data_wen) aux_mem[wpos[BURST_BITS+1:0]] <= {i_tlast, i_tuser};
      {rlast, ruser} <= aux_mem[rpos_next[BURST_BITS+1:0]];
   end
   always @(posedge clk) begin
      if (burst_wen) burst_mem[burst_wpos[2:0]] <= {keep_part_cnts, burst_len};
      {rkeep_part_cnts, rburst} <= burst_mem[burst_rpos_next[2:0]];
   end

   assign data_wen = i_tvalid & i_tready;

   bit_count #(
       .DIV ( KDIV ),
       .WL ( KW_LOG )
   ) keep_part_cnt (
       .idata ( i_tkeep ),
       .odata ( w_keep_part_cnts )
   );
   always @(posedge clk) begin
      if (~resetn) begin
         keep_part_cnts <= 'd0;
      end else begin
         keep_part_cnts <= w_keep_part_cnts;
      end
   end

   wire burst_ren;
   wire data_ren;

   reg [CTX_ID_BITS-1:0] user_prev;
   reg                   prev_valid;
   reg                   sof;
   always @(posedge clk) begin
      if (~resetn) begin
         wpos <= 'd0;
         rpos <= 'd0;
         burst_wpos <= 'd0;
         burst_rpos <= 'd0;
         is_full <= 1'b0;
         is_data_empty <= 1'b1;
         is_burst_empty <= 1'b1;
         burst_len <= 'd0;
         user_prev <= 'd0;
         prev_valid <= 1'b0;
         sof <= 1'b0;
      end else begin
         if (i_tvalid & i_tready) begin
            if (burst_wen) begin
               burst_len <= 'd1;
            end else begin
               burst_len <= burst_len + 1'b1;
            end
            sof <= i_tlast;
            user_prev <= i_tuser;
            prev_valid <= ~i_tlast;
         end else begin
            if (burst_wen) begin
               burst_len <= 'd0;
               prev_valid <= 1'b0;
            end
            sof <= 1'b0;
         end
         burst_wpos <= burst_wpos_next;
         burst_rpos <= burst_rpos_next;
         wpos <= wpos_next;
         rpos <= rpos_next;
         is_full <= (wpos_next[BURST_BITS+1:0] == rpos_next[BURST_BITS+1:0] && wpos_next[BURST_BITS+2] != rpos_next[BURST_BITS+2]) ||
                    (burst_wpos_next[2:0] == burst_rpos_next[2:0] && burst_wpos_next[3] != burst_rpos_next[3]);
         is_data_empty <= wpos == rpos_next;
         is_burst_empty <= burst_wpos == burst_rpos_next;
      end
   end
   assign burst_wpos_next = burst_wen ? burst_wpos + 1'b1 : burst_wpos;
   assign burst_rpos_next = burst_ren ? burst_rpos + 1'b1 : burst_rpos;
   assign wpos_next = i_tvalid & i_tready ? wpos + 1'b1 : wpos;
   assign rpos_next = data_ren ? rpos + 1'b1 : rpos;

   assign burst_wen = (i_tvalid && user_prev != i_tuser && prev_valid) || sof || burst_len == burst_max;

   assign i_tready = ~is_full;

   wire [KW_LOG-1:0] w_last_cnts;

   bit_count_sum #(
       .DIV ( KDIV ),
       .WL ( KW_LOG ),
       .ORIGIN ( 0 )
   ) keep_last_cnts (
       .idata ( rkeep_part_cnts ),
       .odata ( w_last_cnts )
   );

   reg [BURST_BITS:0]    oburst_m1;
   reg [DW-1:0]          odata;
   reg [KW-1:0]          okeep;
   reg [CTX_ID_BITS-1:0] ouser;
   reg [KW_LOG-1:0]      olast_cnts;
   reg                   olast;
   reg                   osop;
   reg                   oeop;
   reg                   ovalid;
   always @(posedge clk) begin
      if (~resetn) begin
         ovalid <= 1'b0;
         oburst_m1 <= 'd0;
         olast_cnts <= 'd0;
      end else begin
         if (data_ren) begin
            odata <= rdata;
            okeep <= rkeep;
            ouser <= ruser;
            olast <= rlast;
            if (burst_ren) begin
               oburst_m1 <= rburst - 1'b1;
               osop <= 1'b1;
               oeop <= rburst == 'd1;
               olast_cnts <= w_last_cnts;
            end else begin
               oburst_m1 <= |oburst_m1 ? oburst_m1 - ovalid : 'd0;
               osop <= osop & ~ovalid;
               oeop <= oburst_m1 == 'd1;
            end
            ovalid <= 1'b1;
         end else begin
            ovalid <= ovalid & ~o_tready;
            osop <= osop & ~o_tready;
            if (burst_ren) begin
               oburst_m1 <= rburst - 1'b1;
               osop <= 1'b1;
               oeop <= rburst == 'd1;
            end
         end
      end
   end

   assign data_ren = (~ovalid | o_tready) && (|oburst_m1 || ~is_burst_empty) && ~is_data_empty;
   assign burst_ren = ~|oburst_m1 && ~is_burst_empty && (~o_tvalid | o_tready);

   assign o_tdata = odata;
   assign o_tkeep = okeep;
   assign o_tuser = ouser;
   assign o_tlast = olast;
   assign o_sop = osop;
   assign o_eop = oeop;
   assign o_burst = oburst_m1;
   assign o_tvalid = ovalid;
   assign o_last_cnt = olast_cnts;

endmodule
