/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_outgoing_route_controller #(
    parameter DW_LOG = 9,
    parameter CTX_ID_BITS = 4,
    parameter TDEST_BITS = 4,
    parameter EXT_RELATION = 0,
    parameter BURST_BITS = 4,
    parameter SELF_DEST = 4,
    parameter REG_BITS = 0,
    parameter ST_IN_BITS = 0,
    parameter ST_OUT_BITS = 0,
    parameter FRAME_HEADER_BITS = 0,
    parameter FRAME_COMPLETE_BITS = 0,
    parameter FRAME_CONSUME_BITS = 0,
    parameter BUFFER_INFO_BITS = 0,
    parameter FRAME_INFO_BITS = 0,
    parameter OUT_REQ_BITS = 0,
    parameter OUT_RSP_BITS = 0,
    parameter MMAPPED = 0,
    parameter MMAPPED_FRAME_MAX = 24,
    parameter DISABLE_FRAME_OUT = 0,
    parameter NEED_RELATION = 1,
    parameter OUT_REQ_FIRST = 0,
    parameter FRAME_SIZE_BITS = 15,
    parameter FRAME_NUM = 100,
    parameter BURST_MAX = 16,
    parameter SEED = 12356
    ) ();

   localparam KW_LOG = DW_LOG - 3;
   localparam RELATION_NUM = EXT_RELATION > 0 ? 7 : 3;
   localparam DW = 1 << DW_LOG;
   localparam KW = 1 << KW_LOG;
   localparam CH_NUM = 1 << CTX_ID_BITS;
   localparam FRAME_MAX = 32;
   localparam FRAME0 = 8;

   localparam REG_BITS_MOD = REG_BITS > 0 ? REG_BITS : 1;
   localparam ST_IN_BITS_MOD = ST_IN_BITS > 0 ? ST_IN_BITS : 1;
   localparam ST_OUT_BITS_MOD = ST_OUT_BITS > 0 ? ST_OUT_BITS : 1;
   localparam FRAME_HEADER_BITS_MOD = FRAME_HEADER_BITS > 0 ? FRAME_HEADER_BITS : 1;
   localparam FRAME_COMPLETE_BITS_MOD = FRAME_COMPLETE_BITS > 0 ? FRAME_COMPLETE_BITS : 1;
   localparam FRAME_CONSUME_BITS_MOD = FRAME_CONSUME_BITS > 0 ? FRAME_CONSUME_BITS : 1;
   localparam BUFFER_INFO_BITS_MOD = BUFFER_INFO_BITS > 0 ? BUFFER_INFO_BITS : 1;
   localparam FRAME_INFO_BITS_MOD = FRAME_INFO_BITS > 0 ? FRAME_INFO_BITS : 1;
   localparam OUT_REQ_BITS_MOD = OUT_REQ_BITS > 0 ? OUT_REQ_BITS : 1;
   localparam OUT_RSP_BITS_MOD = OUT_RSP_BITS > 0 ? OUT_RSP_BITS : 1;
   localparam MM_TDEST = {TDEST_BITS{1'b1}};

   reg [DW-1:0]           st_in_tdata;
   reg [KW-1:0]           st_in_tkeep;
   reg [CTX_ID_BITS-1:0]  st_in_tuser; // context id; extract tuser[12:8] (ch_id)
   reg                    st_in_tlast; // convert from tuser[6] (eop)
   reg                    st_in_tvalid;
   wire                   st_in_tready;
   // data stream output
   wire [DW-1:0]          st_out_tdata;
   wire [KW-1:0]          st_out_tkeep;
   wire [CTX_ID_BITS-1:0] st_out_tuser;
   wire [TDEST_BITS-1:0]  st_out_tdest;
   wire                   st_out_tlast;
   wire                   st_out_sop;
   wire                   st_out_eop;
   wire [BURST_BITS-1:0]  st_out_burst;
   wire [KW_LOG-1:0]      st_out_last_cnt;
   wire                   st_out_tvalid;
   reg                    st_out_tready;
   // frame header output (to functions)
   wire [127:0]           frame_header_tdata; // [63:0] frame addr; [95:64] frame size; [103:96] frame id
   wire [CTX_ID_BITS-1:0] frame_header_tuser;
   wire [TDEST_BITS-1:0]  frame_header_tdest;
   wire                   frame_header_tvalid;
   reg                    frame_header_tready;
   // frame completion input (from functions)
   reg [127:0]            frame_complete_tdata; // frame addr, frame size
   reg [CTX_ID_BITS-1:0]  frame_complete_tuser;
   reg                    frame_complete_tvalid;
   wire                   frame_complete_tready;
   // frame consume input (from functions)
   reg [7:0]              frame_consume_tdata; // frame id
   reg [CTX_ID_BITS-1:0]  frame_consume_tuser;
   reg                    frame_consume_tvalid;
   wire                   frame_consume_tready;
   // incoming frame info (from DMAC)
   reg [31:0]             buffer_info_tdata; // buffer size
   reg [CTX_ID_BITS-1:0]  buffer_info_tuser; // context id
   reg                    buffer_info_tvalid;
   wire                   buffer_info_tready;
   // incoming frame ready (to DMAC)
   wire [31:0]            frame_info_tdata; // frame size
   wire [CTX_ID_BITS-1:0] frame_info_tuser;
   wire                   frame_info_tvalid;
   reg                    frame_info_tready;
   // outgoing frame request (to outgoing route controller)
   reg [CTX_ID_BITS-1:0] frame_out_req_tuser;
   reg                   frame_out_req_tvalid;
   wire                  frame_out_req_tready;
   // outgoing frame ready (from outgoing route controller)
   wire [CTX_ID_BITS-1:0] frame_out_ready_tuser;
   wire [TDEST_BITS-1:0]  frame_out_ready_tdest;
   wire                   frame_out_ready_tvalid;
   reg                    frame_out_ready_tready;
   // config
   reg [CTX_ID_BITS+4:0]  cfg_raddr;
   reg                    cfg_arvalid;
   wire [31:0]            cfg_rdata;
   wire                   cfg_rvalid;
   reg [CTX_ID_BITS+4:0]  cfg_waddr;
   reg [31:0]             cfg_wdata;
   reg                    cfg_wvalid;

   reg           clk;
   reg           resetn;
   reg [31:0]    rd;

   outgoing_route_controller #(
       .DW_LOG ( DW_LOG ),
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .TDEST_BITS ( TDEST_BITS ),
       .BURST_BITS ( BURST_BITS ),
       .EXT_RELATION ( EXT_RELATION ),
       .SELF_DEST ( SELF_DEST )
   ) dut (
       .*
   );

   initial begin
      clk = 1'b0;
      resetn = 1'b0;
      rd = $random(SEED);

      st_in_tvalid = 1'b0;
      st_out_tready = 1'b1;
      frame_header_tready = 1'b1;
      frame_complete_tdata = 'd0;
      frame_complete_tuser = 'd0;
      frame_complete_tvalid = 1'b0;
      frame_consume_tdata = 'd0;
      frame_consume_tuser = 'd0;
      frame_consume_tvalid = 1'b0;
      buffer_info_tvalid = 1'b0;
      frame_info_tready = 1'b1;
      frame_out_req_tvalid = 1'b0;
      frame_out_ready_tready = 1'b1;
      cfg_arvalid = 1'b0;
      cfg_wvalid = 1'b0;
   end
   always #5 clk = ~clk;
   always #100 resetn = 1'b1;
   always @(posedge clk) begin
      rd <= $random();
   end

   reg [DW-1:0]          st_data_saved[0:CH_NUM-1][0:255];
   reg [KW-1:0]          st_keep_saved[0:CH_NUM-1][0:255];
   reg                   st_last_saved[0:CH_NUM-1][0:255];
   reg                   st_sop_saved[0:CH_NUM-1][0:255];
   reg                   st_eop_saved[0:CH_NUM-1][0:255];
   reg [BURST_BITS-1:0]  st_burst_saved[0:CH_NUM-1][0:255];
   reg [KW_LOG-1:0]      st_last_cnt_saved[0:CH_NUM-1][0:255];
   reg [7:0]             st_wpos[0:CH_NUM-1];
   reg [7:0]             st_rpos[0:CH_NUM-1];
   logic                 ignore_prev_ch;

   // st data check
   initial begin
      for (int i=0; i<CH_NUM; i++) begin
         st_wpos[i] = 'd0;
         st_rpos[i] = 'd0;
      end
   end
   always @(posedge clk) begin
      if (resetn) begin
         if (st_out_tvalid & st_out_tready) begin
            if (st_out_tdata !== st_data_saved[st_out_tuser][st_rpos[st_out_tuser]] ||
                st_out_tkeep !== st_keep_saved[st_out_tuser][st_rpos[st_out_tuser]] ||
                st_out_tlast !== st_last_saved[st_out_tuser][st_rpos[st_out_tuser]] ||
                (st_out_sop !== st_sop_saved[st_out_tuser][st_rpos[st_out_tuser]] && ~ignore_prev_ch) ||
                (st_out_eop !== st_eop_saved[st_out_tuser][st_rpos[st_out_tuser]] && ~ignore_prev_ch) ||
                (st_out_sop && st_out_burst !== st_burst_saved[st_out_tuser][st_rpos[st_out_tuser]] && ~ignore_prev_ch) ||
                (st_out_sop && st_out_last_cnt !== st_last_cnt_saved[st_out_tuser][st_rpos[st_out_tuser]] && ~ignore_prev_ch)) begin
               $error("%d: [%2h] %h %h, %h %h, %h %h, [%h %h], %h %h, %h %h, %h %h", $time, st_out_tuser,
                      st_out_tdata, st_data_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_tkeep, st_keep_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_tlast, st_last_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_sop, st_sop_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_eop, st_eop_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_burst, st_burst_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_last_cnt, st_last_cnt_saved[st_out_tuser][st_rpos[st_out_tuser]]);
            end else begin
               $display("%d: [%2h] %h %h, %h %h, %h %h, [%h %h], %h %h, %h %h, %h %h", $time, st_out_tuser,
                      st_out_tdata, st_data_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_tkeep, st_keep_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_tlast, st_last_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_sop, st_sop_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_eop, st_eop_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_burst, st_burst_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_last_cnt, st_last_cnt_saved[st_out_tuser][st_rpos[st_out_tuser]]);
            end
            st_rpos[st_out_tuser] <= st_rpos[st_out_tuser] + 1'b1;
         end
         st_out_tready <= ST_OUT_BITS > 0 ? &rd[18+:ST_OUT_BITS_MOD] : 1'b1;
      end
   end

   reg                  channel_valids[0:CH_NUM-1];
   reg                  channel_is_mmapped[0:CH_NUM-1];
   reg                  channel_disable_frame_out[0:CH_NUM-1];
   reg [TDEST_BITS-1:0] channel_dests[0:CH_NUM-1];
   reg [31:0]           channel_frame_size[0:CH_NUM-1];
   reg [63:0]           channel_addrs[0:CH_NUM-1][0:FRAME_MAX];
   reg [FRAME_MAX-1:0]  channel_frame_valids[0:CH_NUM-1];
   reg [FRAME_MAX-1:0]  channel_frame_used[0:CH_NUM-1];
   reg [2:0]            channel_relation_nums[0:CH_NUM-1];
   reg [7:0]            channel_relations[0:CH_NUM-1][0:RELATION_NUM-1];
   initial begin
      for (int i=0; i<CH_NUM; i++) begin
         channel_valids[i] = 1'b0;
         channel_is_mmapped[i] = 1'b0;
         channel_disable_frame_out[i] = 1'b0;
         channel_dests[i] = {TDEST_BITS{1'b1}};
         channel_frame_size[i] = 'd0;
         for (int j=0; j<FRAME_MAX; j++) channel_addrs[i][j] = 'd0;
         channel_frame_valids[i] = 'd0;
         channel_frame_used[i] = 'd0;
         channel_relation_nums[i] = 'd0;
         for (int j=0; j<RELATION_NUM; j++) channel_relations[i][j] = 'd0;
      end
   end

   reg [31:0] buffer_size_saved[0:CH_NUM-1][0:255];
   reg [31:0] frame_size_saved[0:CH_NUM-1][0:255];
   reg [63:0] frame_addr_saved[0:CH_NUM-1][0:255];
   reg [7:0]  buffer_size_wpos[0:CH_NUM-1];
   reg [7:0]  buffer_size_rpos[0:CH_NUM-1];
   reg [7:0]  buffer_size_gpos[0:CH_NUM-1];
   reg [7:0]  frame_size_wpos[0:CH_NUM-1];
   reg [7:0]  frame_size_rpos[0:CH_NUM-1];
   reg [7:0]  frame_size_gpos[0:CH_NUM-1];
   reg [7:0]  frame_idx_saved[0:CH_NUM-1][0:255];
   reg [7:0]  frame_idx_wpos[0:CH_NUM-1];
   reg [7:0]  frame_idx_cpos[0:CH_NUM-1];
   reg [7:0]  frame_idx_rpos[0:CH_NUM-1];
   initial begin
      for (int i=0; i<CH_NUM; i++) begin
         buffer_size_wpos[i] = 'd0;
         buffer_size_rpos[i] = 'd0;
         buffer_size_gpos[i] = 'd0;
         frame_size_wpos[i] = 'd0;
         frame_size_rpos[i] = 'd0;
         frame_size_gpos[i] = 'd0;
         frame_idx_wpos[i] = 'd0;
         frame_idx_cpos[i] = 'd0;
         frame_idx_rpos[i] = 'd0;
      end
   end

   // frame info check
   reg [CH_NUM-1:0] buffer_info_busy;
   initial begin
      buffer_info_busy = 'd0;
   end

   always @(posedge clk) begin
      if (resetn) begin
         if (frame_info_tvalid & frame_info_tready) begin
            if (frame_info_tdata !== frame_size_saved[frame_info_tuser][frame_size_rpos[frame_info_tuser]]) begin
               $error("%d: [%2h] frame info size: %h %h (%d)", $time, frame_info_tuser, frame_info_tdata,
                      frame_size_saved[frame_info_tuser][frame_size_rpos[frame_info_tuser]], frame_size_rpos[frame_info_tuser]);
            end else begin
               $display("%d: [%2h] frame info size: %h %h (%d)", $time, frame_info_tuser, frame_info_tdata,
                        frame_size_saved[frame_info_tuser][frame_size_rpos[frame_info_tuser]], frame_size_rpos[frame_info_tuser]);
            end
            frame_size_rpos[frame_info_tuser] <= frame_size_rpos[frame_info_tuser] + 1'b1;
            buffer_info_busy[frame_info_tuser] <= 1'b0;
            $display("@@@ frame info complete [%2h]: %d", frame_info_tuser, frame_size_rpos[frame_info_tuser]);
         end
      end
   end

   // frame out ready
   logic [15:0] frame_out_ready_count;
   logic [3:0] rev_relation_nums[0:CH_NUM-1];
   logic [3:0] rev_relation_counts[0:CH_NUM-1];
   logic [7:0] rev_relations[0:CH_NUM-1][0:RELATION_NUM-1];
   logic [7:0] rev_relation_dests[0:CH_NUM-1][0:RELATION_NUM-1];
   initial begin
      for (int i=0; i<CH_NUM; i++) rev_relation_nums[i] = 'd0;
      for (int i=0; i<CH_NUM; i++) rev_relation_counts[i] = 'd0;
   end
   always @(posedge clk) begin
      if (~resetn) begin
         frame_out_ready_count <= 'd0;
      end else begin
         if (frame_out_ready_tvalid & frame_out_ready_tready) begin
            if (frame_out_ready_tdest !== rev_relation_dests[frame_out_ready_tuser][rev_relation_counts[frame_out_ready_tuser]]) begin
               $error("%d: [%2h] frame out ready dest: %h %h", $time, frame_out_ready_tuser,
                      frame_out_ready_tdest,
                      rev_relation_dests[frame_out_ready_tuser][rev_relation_counts[frame_out_ready_tuser]]);
            end
            rev_relation_counts[frame_out_ready_tuser] = rev_relation_counts[frame_out_ready_tuser] + 1'b1;
            if (rev_relation_counts[frame_out_ready_tuser] == rev_relation_nums[frame_out_ready_tuser]) begin
               frame_out_ready_count++;
               rev_relation_counts[frame_out_ready_tuser] = 'd0;
               $display("%d: [%2h] frame out ready", $time, frame_out_ready_tuser);
            end else if (rev_relation_nums[frame_out_ready_tuser] == 0) begin
               $error("%d: [%2h] frame_out ready channel wrong", $time, frame_out_ready_tuser);
            end
         end
         frame_out_ready_tready <= OUT_RSP_BITS > 0 ? &rd[15+:OUT_RSP_BITS_MOD] : 1'b1;
      end
   end

   // frame header check
   logic frame_is_valid;
   int   frame_header_count;
   always @(posedge clk) begin
      if (~resetn) begin
         frame_header_count = 0;
      end else begin
         if (frame_header_tvalid && frame_header_tready) begin
            frame_is_valid = ~channel_is_mmapped[frame_header_tuser];
            if (channel_is_mmapped[frame_header_tuser]) begin
               frame_idx_saved[frame_header_tuser][frame_idx_wpos[frame_header_tuser]] <= frame_header_tdata[96+:8];
               frame_idx_wpos[frame_header_tuser] <= frame_idx_wpos[frame_header_tuser] + 1'b1;
               $display("%d: [%2h] frame header addr[%2h]: %h", $time, frame_header_tuser, frame_header_tdata[96+:8],
                        frame_header_tdata[63:0]);
            end
            if (frame_header_tdata[63:0] === channel_addrs[frame_header_tuser][frame_header_tdata[96+:8]]) begin
               frame_is_valid = 1'b1;
            end
            if (~frame_is_valid ||
                (frame_header_tdata[64+:32] > channel_frame_size[frame_header_tuser] && channel_is_mmapped[frame_header_tuser]) ||
                (frame_header_tdata[104+:TDEST_BITS] !== SELF_DEST) ||
                frame_header_tdest !== channel_dests[frame_header_tuser]) begin
               $error("%d: [%2h] frame header addr[%2d]: %h %h, size: %h %h", $time, frame_header_tuser,
                      frame_header_tdata[96+:8], frame_header_tdata[63:0], channel_addrs[frame_header_tuser][frame_header_tdata[96+:8]],
                      frame_header_tdata[64+:32], channel_frame_size[frame_header_tuser]);
            end else if (frame_header_tdata[64+:32] !== buffer_size_saved[frame_header_tuser][buffer_size_rpos[frame_header_tuser]]) begin
               $error("%d: [%2h] frame header size: %h %h", $time, frame_header_tuser,
                      frame_header_tdata[64+:32], buffer_size_saved[frame_header_tuser][buffer_size_rpos[frame_header_tuser]]);
            end else begin
               frame_header_count++;
               $display("%d: [%2h] frame header (%d) size: %h", $time, frame_header_tuser, frame_header_count, frame_header_tdata[64+:32]);
            end
            frame_addr_saved[frame_header_tuser][buffer_size_rpos[frame_header_tuser]] <= frame_header_tdata[63:0];
            buffer_size_rpos[frame_header_tuser] <= buffer_size_rpos[frame_header_tuser] + 1'b1;
         end
      end
   end

   reg [7:0] out_req_counts[0:CH_NUM-1];
   reg [7:0] buffer_info_counts[0:CH_NUM-1];
   initial begin
      for (int i=0; i<CH_NUM; i++) begin
         out_req_counts[i] = 'd0;
         buffer_info_counts[i] = 'd0;
      end
   end

   logic frame_complete_done;
   initial frame_complete_done = 0;

   task static setup_regs();
      logic [CTX_ID_BITS-1:0] ch;
      logic                   is_mmapped = 1'b0;
      logic                   disable_frame_out_signal = 1'b0;
      logic                   ch_valid = 1'b0;
      logic [TDEST_BITS-1:0]  destination = {TDEST_BITS{1'b1}};
      logic [31:0]            frame_size = 0;
      logic [31:0]            addr_mid = 0;
      logic [FRAME_MAX-1:0]   frame_valids = 0;
      logic [FRAME_MAX-1:0]   frame_used = 0;
      logic [3:0]             relation_num = 0;
      logic [RELATION_NUM*8-1:0] relations = 0;
      logic [CTX_ID_BITS:0]      relation_total = 0;
      logic [CH_NUM-1:0]         relation_used = 0;
      logic                      wvalid;
      logic                      arvalid;
      logic                      rwait = 0;
      logic [31:0]               rdata_exp;
      for (int i=0; i<CH_NUM; i++) begin
         ch = i;
         ch_valid = rd[ch];
         is_mmapped = MMAPPED > 0 ? rd[1+ch] : 1'b0;
         disable_frame_out_signal = DISABLE_FRAME_OUT > 0 ? rd[2+ch] : 1'b0;
         destination = ch_valid ? is_mmapped ? MM_TDEST : rd[14+:TDEST_BITS] : {TDEST_BITS{1'b1}};
         frame_size = {{26-FRAME_SIZE_BITS{1'b0}}, rd[FRAME_SIZE_BITS-1:6], 6'd0};
         relation_num = NEED_RELATION > 0 ? {2'b0, &rd[3+ch+:2]} : 3'd0;
         //if (NEED_RELATION > 0 && relation_num == 0) relation_num = 1;
         if (relation_total + relation_num > CH_NUM) relation_num = CH_NUM - relation_total;
         //if (NEED_RELATION > 0 && relation_num == 0) ch_valid = 1'b0;
         relation_total += relation_num;
         for (int j=0; j<relation_num;) @(posedge clk) begin
            relations[8*j+:8] = {rd[17+:8-CTX_ID_BITS], rd[4+:CTX_ID_BITS]};
            if (!relation_used[relations[8*j+:CTX_ID_BITS]]) begin
               relation_used[relations[8*j+:CTX_ID_BITS]] = 1'b1;
               rev_relations[relations[8*j+:CTX_ID_BITS]][rev_relation_nums[relations[8*j+:CTX_ID_BITS]]] = ch;
               rev_relation_dests[relations[8*j+:CTX_ID_BITS]][rev_relation_nums[relations[8*j+:CTX_ID_BITS]]] = relations[8*j+CTX_ID_BITS+:8-CTX_ID_BITS];
               rev_relation_nums[relations[8*j+:CTX_ID_BITS]]++;
               j++;
            end
         end
         frame_valids = (32'd1 << ((MMAPPED_FRAME_MAX < rd[3+:5] ? MMAPPED_FRAME_MAX : rd[3+:5])+FRAME0+1)) - 1'b1;

         if (~ch_valid) continue;

         channel_valids[ch] = ch_valid;
         channel_is_mmapped[ch] = is_mmapped;
         channel_disable_frame_out[ch] = disable_frame_out_signal;
         channel_dests[ch] = destination;
         channel_frame_size[ch] = frame_size;
         channel_frame_valids[ch] = frame_valids;
         channel_relation_nums[ch] = relation_num;
         for (int j=0; j<relation_num; j++) channel_relations[ch][j] = relations[j*8+:8];

         $display("[%2h]: valid: %d, mmap: %d, disable: %d, dest: %x, size: %h, valids: %h, relation: %d", ch,
                  ch_valid, is_mmapped, disable_frame_out_signal, destination, frame_size, frame_valids, relation_num);
         for (int j=0; j<relation_num; j++) $display("[%2h]:  [%2d]: %h", ch, j, relations[j*8+:8]);

         // write configs
         for (logic [4:0] j=0; j<(EXT_RELATION > 0 ? 6 : 5);) @(posedge clk) begin : write_config
            wvalid = REG_BITS > 0 ? &rd[3+:REG_BITS_MOD] : 1'b1;
            cfg_wvalid <= wvalid;
            cfg_waddr <= {ch, j};
            cfg_wdata <= j == 0 ? {{16-TDEST_BITS{1'b0}}, destination, 7'd0, disable_frame_out_signal,
                                   3'd0, is_mmapped, 3'd0, ch_valid} :
                         j == 1 ? frame_size :
                         j == 2 ? frame_valids :
                         j == 3 ? frame_used :
                         j == 4 ? {relations[23:0], 4'd0, relation_num} : relations >> 24;
            if (wvalid) j++;
         end
         @(posedge clk) cfg_wvalid <= 1'b0;
         // write frame addrs
         for (logic [5:0] j=FRAME0; j<32;) @(posedge clk) begin : write_addrs
            wvalid = REG_BITS > 0 ? &rd[3+:REG_BITS_MOD] : 1'b1;
            cfg_wvalid <= wvalid;
            cfg_waddr <= {ch, j[4:0]};
            cfg_wdata <= rd;
            channel_addrs[ch][j-FRAME0] <= {20'd0, rd, 12'd0};
            if (wvalid) begin
               $display("%d: [%2h] frame addr[%2h]: %h", $time, ch, j-FRAME0, {20'd0, rd, 12'd0});
               j++;
            end
            if (~frame_valids[j]) break;
         end
         @(posedge clk) cfg_wvalid <= 1'b0;
         // read configs
         for (logic [4:0] j=0; j<(EXT_RELATION > 0 ? 6 : 5);) @(posedge clk) begin : read_config
            arvalid = REG_BITS > 0 ? &rd[4+:REG_BITS_MOD] : 1'b1;
            if (~rwait) begin
               cfg_arvalid <= arvalid;
               cfg_raddr <= {ch, j};
               rwait = arvalid;
            end else begin
               cfg_arvalid <= 1'b0;
            end
            if (cfg_rvalid) begin
               rdata_exp = j==0 ? {{16-TDEST_BITS{1'b0}}, destination, 7'd0, disable_frame_out_signal,
                                   3'd0, is_mmapped, 3'd0, ch_valid} :
                           j==1 ? frame_size :
                           j==2 ? frame_valids & (32'hffffffff << FRAME0):
                           j==3 ? frame_used & (32'hffffffff << FRAME0):
                           j==4 ? {relations[23:0], 4'd0, relation_num} : relations >> 24;
               if (cfg_rdata != rdata_exp) begin
                  $error("%d: [%2h](%3d) %h: %h %h", $time, ch, j, cfg_raddr, cfg_rdata, rdata_exp);
               end
               rwait = 0;
               j++;
            end
         end
      end
   endtask

   logic [2:0]             out_req_relation_num[0:CH_NUM-1];
   wire [3*CH_NUM-1:0]     out_req_relation_nums;
   generate
      for (genvar i=0; i<CH_NUM; i++) assign out_req_relation_nums[3*i+:3] = out_req_relation_num[i];
   endgenerate

   task static generate_out_req();
      logic [CTX_ID_BITS-1:0] ch = 0;
      logic                   valid = 0;
      logic                   valid_p = 0;
      logic                   valid_pp = 0;
      logic                   mod_cond =0;
      int                     frames = 0;
      frame_out_req_tuser = 0;
      for (int i=0; i<CH_NUM; i++) out_req_relation_num[i] = 0;

      while (frames < FRAME_NUM && ~frame_complete_done) @(posedge clk) begin
         if (~frame_out_req_tvalid | frame_out_req_tready) begin
            mod_cond = ~valid_pp || valid || ~|channel_relation_nums[ch];
            if (mod_cond) ch = rd[12+:CTX_ID_BITS];
            if (mod_cond && ~|out_req_relation_num[ch]) begin
               valid_pp = channel_valids[ch];
               if (OUT_REQ_FIRST == 0) valid_pp &= (~|channel_relation_nums[ch] || out_req_counts[ch] < buffer_info_counts[ch]);
               if (valid_pp) out_req_relation_num[ch] = channel_relation_nums[ch];
            end
            if (frame_out_req_tvalid & frame_out_req_tready) begin
               $display("%d: [%2h] frame out req (%d)", $time, frame_out_req_tuser, frames);
            end
            valid_p = valid_pp && |out_req_relation_num[ch];
            valid = valid_p && (OUT_REQ_BITS > 0 ? &rd[15+:OUT_REQ_BITS_MOD] : 1'b1);
            if (valid) begin
               frame_out_req_tuser <= ch;
               out_req_relation_num[ch]--;
               if (~|out_req_relation_num[ch]) begin
                  out_req_counts[ch]++;
                  frames++;
               end
            end
            frame_out_req_tvalid <= valid;
         end else begin
            frame_out_req_tvalid <= frame_out_req_tvalid & ~frame_out_req_tready;
         end
      end
      @(posedge clk) frame_out_req_tvalid <= frame_out_req_tvalid & ~frame_out_req_tready;
      while (frame_out_req_tvalid) @(posedge clk) frame_out_req_tvalid <= frame_out_req_tvalid & ~frame_out_req_tready;
      $display("generate out_req finish");
   endtask

   task static generate_buffer_info();
      logic [CTX_ID_BITS-1:0] ch;
      logic [31:0]            buffer_size;
      logic                   valid_pp;
      logic                   valid_p;
      logic                   valid;
      int                     buffers = 0;
      @(posedge clk) $display("%d: generate buffer info start", $time);
      while (buffers < FRAME_NUM || buffer_info_tvalid) @(posedge clk) begin
         if ((~buffer_info_tvalid | buffer_info_tready) && buffers < FRAME_NUM) begin
            ch = rd[10+:CTX_ID_BITS];
            valid_pp = (BUFFER_INFO_BITS > 0 ? &rd[5+:BUFFER_INFO_BITS_MOD] : 1'b1) | (valid_pp & ~valid);
            valid_p = valid_pp & channel_valids[ch] & ~buffer_info_busy[ch];
            valid = valid_p;
            if (OUT_REQ_FIRST != 0) valid &= (out_req_counts[ch] > buffer_info_counts[ch] || ~|channel_relation_nums[ch]);
            buffer_info_tvalid <= valid;
            if (valid) begin
               buffer_size = {{26-FRAME_SIZE_BITS{1'b0}}, rd[FRAME_SIZE_BITS-1:0]};
               buffer_info_tdata <= buffer_size;
               buffer_info_tuser <= ch;
               buffer_info_busy[ch] <= 1'b1;
               buffer_info_counts[ch]++;
            end
         end else begin
            buffer_info_tvalid <= buffer_info_tvalid & ~buffer_info_tready;
         end
         if (buffer_info_tvalid && buffer_info_tready) begin
            if ((~channel_is_mmapped[buffer_info_tuser] && ~|channel_frame_size[buffer_info_tuser]) ||
                buffer_info_tdata < channel_frame_size[buffer_info_tuser]) begin
               buffer_size_saved[buffer_info_tuser][buffer_size_wpos[buffer_info_tuser]] <= buffer_info_tdata;
            end else begin
               buffer_size_saved[buffer_info_tuser][buffer_size_wpos[buffer_info_tuser]] <= channel_frame_size[buffer_info_tuser];
            end
            buffer_size_wpos[buffer_info_tuser] <= buffer_size_wpos[buffer_info_tuser] + 1'b1;
            buffers++;
            $display("%d: [%2h] buffer info (%d, %d) size: %h", $time, buffer_info_tuser, buffers,
                     buffer_size_wpos[buffer_info_tuser],
                     ~channel_is_mmapped[buffer_info_tuser] || buffer_info_tdata < channel_frame_size[buffer_info_tuser] ? buffer_info_tdata : channel_frame_size[buffer_info_tuser]);
         end
      end
      @(posedge clk) buffer_info_tvalid <= 1'b0;
   endtask

   wire [8*CH_NUM-1:0] buffer_size_rposes;
   wire [8*CH_NUM-1:0] buffer_size_wposes;
   wire [8*CH_NUM-1:0] buffer_size_gposes;
   generate
      for (genvar i=0; i<CH_NUM; i++) begin
         assign buffer_size_wposes[8*i+:8] = buffer_size_wpos[i];
         assign buffer_size_rposes[8*i+:8] = buffer_size_rpos[i];
         assign buffer_size_gposes[8*i+:8] = buffer_size_gpos[i];
      end
   endgenerate

   task static generate_frame_complete();
      logic [CTX_ID_BITS-1:0] ch = 0;
      logic [CTX_ID_BITS-1:0] prev_ch = 0;
      logic [31:0]            frame_size;
      logic [63:0]            frame_addr;
      logic                   valid;
      int                     frames = 0;
      frame_complete_done = 1'b0;
      while (frames < FRAME_NUM || frame_complete_tvalid) @(posedge clk) begin
         if ((~frame_complete_tvalid | frame_complete_tready) &&
             (FRAME_COMPLETE_BITS > 0 ? &rd[7+:FRAME_COMPLETE_BITS_MOD] : 1'b1)) begin
            prev_ch = ch -1;
            while (buffer_size_rpos[ch] == buffer_size_gpos[ch] && ((ch + 1) & {1'b0, {CTX_ID_BITS{1'b1}}}) != prev_ch) ch++;
            if (buffer_size_rpos[ch] != buffer_size_gpos[ch]) begin
               frame_size = {{26-FRAME_SIZE_BITS{1'b0}}, rd[FRAME_SIZE_BITS-1:6], 6'd0};
               frame_addr = frame_addr_saved[ch][buffer_size_gpos[ch]];
               if (frame_size > buffer_size_saved[ch][buffer_size_gpos[ch]]) begin
                  frame_size = buffer_size_saved[ch][buffer_size_gpos[ch]];
               end else if (frame_size == 0) begin
                  frame_size = buffer_size_saved[ch][buffer_size_gpos[ch]];
               end
               frame_complete_tvalid <= 1'b1;
               frame_complete_tuser <= ch;
               frame_complete_tdata <= {frame_size, frame_addr};
               buffer_size_gpos[ch] <= buffer_size_gpos[ch] + 1'b1;
               frame_size_saved[ch][frame_size_wpos[ch]] <= frame_size;
               frame_size_wpos[ch] <= frame_size_wpos[ch] + 1'b1;
               $display("%d: [%2h] frame complete: %h", $time, ch, frame_size);
               ch++;
            end else begin
               frame_complete_tvalid <= 1'b0;
            end
         end else begin
            frame_complete_tvalid <= frame_complete_tvalid & ~frame_complete_tready;
         end
         if (frame_complete_tvalid & frame_complete_tready) begin
            frames++;
            $display("%d: [%2h] frame complete (%d) size: %h", $time, frame_complete_tuser, frames, frame_complete_tdata);
         end
      end
      while (frame_complete_tvalid) @(posedge clk) begin
         frame_complete_tvalid <= frame_complete_tvalid & ~frame_complete_tready;
      end
      for (int i=0; i<CH_NUM; i++) begin
         $display("@@@ frame complete [%2h]: %d", i, frame_size_wpos[i]);
      end
      frame_complete_done = 1'b1;
   endtask

   task static generate_stream_data();
      logic [31:0] pos[0:CH_NUM-1];
      logic [CTX_ID_BITS-1:0] ch = 0;
      logic [CTX_ID_BITS-1:0] prev_ch = 0;
      logic [4:0]             burst = 0;
      logic [DW-1:0]          data;
      logic [KW-1:0]          keep;
      logic                   last = 1;
      logic                   valid;
      logic                   sop = 0;
      logic                   eop = 0;
      logic [CTX_ID_BITS-1:0] remain_chs;
      logic [CTX_ID_BITS-1:0] remain_pos_chs;
      logic [(8<<CTX_ID_BITS)-1:0] last_counts = 0;
      logic [7:0]                  last_count = 0;
      logic [KW_LOG-1:0]           last_pos;
      logic [31:0]                 cur_pos;
      int                     frames = 0;
      for (int i=0; i<CH_NUM; i++) pos[i] = 0;
      ignore_prev_ch = 0;
      while (frames < FRAME_NUM || st_in_tvalid) @(posedge clk) begin
         ignore_prev_ch = frame_complete_done;
         if (ignore_prev_ch) begin
            remain_chs = 0;
            remain_pos_chs = 0;
            for (int i=0; i<CH_NUM; i++) begin
               remain_chs += (frame_size_rpos[i] !== frame_size_gpos[i]);
               remain_pos_chs += |pos[ch];
            end
            ignore_prev_ch &= remain_chs < 2;
         end
         if (~|burst) begin
            ch = rd[14+:CTX_ID_BITS];
            if (~|pos[ch]) begin
               if (channel_valids[ch]) begin
                  if (frame_size_rpos[ch] !== frame_size_gpos[ch]) begin
                     pos[ch] = frame_size_saved[ch][frame_size_gpos[ch]];
                     frame_size_gpos[ch] = frame_size_gpos[ch] + 1'b1;
                     $display("%d: [%2h] stream start: %d size: %h", $time, ch, frame_size_gpos[ch], pos[ch]);
                  end
               end else begin
                  //pos[ch] = channel_frame_size[ch];
               end
            end
            if (|pos[ch] && (ch != prev_ch || ignore_prev_ch)) begin
               if ((pos[ch] + KW - 1) / KW <= BURST_MAX) begin
                  burst = (pos[ch] + KW - 1) / KW;
                  last_pos = pos[ch] - 1;
               end else begin
                  burst = BURST_MAX;
                  last_pos = {KW_LOG{1'b1}};
               end
               sop = 1'b1;
               prev_ch = ch;
            end
         end
         if ((~st_in_tvalid | st_in_tready) & |burst)  begin
            cur_pos = pos[ch];
            for (int i=0; i<KW; i++) begin
               if (burst > 1 || i < pos[ch]) begin
                  data[i*8+:8] = rd ^ (64'hdeadbeef01050910 >> (i&63));
                  keep[i] = 1'b1;
               end else begin
                  data[i*8+:8] = 8'd0;
                  keep[i] = 1'b0;
               end
            end
            last = pos[ch] <= KW;
            eop = burst == 1;
            valid = ST_IN_BITS > 0 ? &rd[6+:ST_IN_BITS_MOD] : 1'b1;
            if (valid) begin
               st_in_tdata <= data;
               st_in_tkeep <= keep;
               st_in_tuser <= ch;
               st_in_tlast <= last;
               st_data_saved[ch][st_wpos[ch]] <= data;
               st_keep_saved[ch][st_wpos[ch]] <= keep;
               st_last_saved[ch][st_wpos[ch]] <= last;
               st_sop_saved[ch][st_wpos[ch]] <= sop;
               st_eop_saved[ch][st_wpos[ch]] <= eop;
               st_burst_saved[ch][st_wpos[ch]] <= burst - 1;
               st_last_cnt_saved[ch][st_wpos[ch]] <= last_pos;
               st_wpos[ch] <= st_wpos[ch] + 1'b1;
               if (pos[ch] <= DW/8) begin
                  pos[ch] = 'd0;
                  if (channel_valids[ch]) begin
                     frame_idx_cpos[ch] <= frame_idx_cpos[ch] + 1'b1;
                     frames++;
                  end
               end else begin
                  pos[ch] -= DW/8;
               end
               sop = 1'b0;
               burst--;
            end
            st_in_tvalid <= valid;
         end else begin
            st_in_tvalid <= st_in_tvalid & ~st_in_tready;
         end
         if (st_in_tvalid & st_in_tready & st_in_tlast) begin
            last_count++;
            last_counts[st_in_tuser*8+:8]++;
            $display("%d: [%2h] last count: %d, %d", $time, st_in_tuser, last_counts[st_in_tuser*8+:8],
                     frame_size_gpos[st_in_tuser]);
         end
      end
      while (st_in_tvalid) @(posedge clk) begin
         st_in_tvalid <= st_in_tvalid & ~st_in_tready;
      end
      $display("stream data finish");
   endtask

   task static generate_frame_consume;
      int consumes = 0;
      int no_action = 0;
      logic remain = 0;
      logic [CTX_ID_BITS-1:0] ch = 0;
      logic                   valid = 0;
      logic [7:0]             frame_idx;
      while ((consumes == 0 && MMAPPED)  || no_action < 100) @(posedge clk) begin
         remain = 0;
         for (int i=0; i<CH_NUM; i++) begin
            if (frame_idx_wpos[(ch+i)%CH_NUM] != frame_idx_rpos[(ch+i)%CH_NUM] &&
                frame_idx_cpos[(ch+i)%CH_NUM] != frame_idx_rpos[(ch+i)%CH_NUM]) begin
               ch = ch + i;
               break;
            end
            remain |= frame_idx_wpos[(ch+i)%CH_NUM] != frame_idx_rpos[(ch+i)%CH_NUM];
         end
         valid = (frame_idx_wpos[ch] != frame_idx_rpos[ch]) && (frame_idx_cpos[ch] != frame_idx_rpos[ch]);
         valid = valid & (FRAME_CONSUME_BITS > 0 ? &rd[10+:FRAME_CONSUME_BITS_MOD] : 1'b1);
         if (valid && (~frame_consume_tvalid | frame_consume_tready)) begin
            frame_idx = frame_idx_saved[ch][frame_idx_rpos[ch]];
            frame_consume_tdata <= frame_idx;
            frame_consume_tuser <= ch;
            frame_consume_tvalid <= 1'b1;
            frame_idx_rpos[ch] <= frame_idx_rpos[ch] + 1'b1;
            $display("%d: [%2h] frame consume %2h", $time, ch, frame_idx);
            consumes++;
            ch <= ch + 1;
            no_action = 0;
         end else begin
            frame_consume_tvalid <= frame_consume_tvalid & ~frame_consume_tready;
            if (~remain) no_action++;
         end
      end
   endtask

   initial begin
      @(posedge clk);
      while (resetn !== 1'b1) @(posedge clk);

      setup_regs();

      fork
         begin
            generate_buffer_info();
         end
         begin
            generate_out_req();
         end
         begin
            generate_frame_complete();
         end
         begin
            generate_stream_data();
         end
         begin
            generate_frame_consume();
         end
      join

      $finish();
   end

endmodule

module test_outgoing_route_controller_random_fast();
   tb_outgoing_route_controller tb();
endmodule

module test_outgoing_route_controller_random();
   tb_outgoing_route_controller #(
       .SEED ( 12345 ),
       .ST_IN_BITS ( 1 ),
       .ST_OUT_BITS ( 1 ),
       .FRAME_HEADER_BITS ( 2 ),
       .FRAME_COMPLETE_BITS ( 2 ),
       .FRAME_CONSUME_BITS ( 2 ),
       .BUFFER_INFO_BITS ( 3 ),
       .FRAME_INFO_BITS ( 2 ),
       .OUT_REQ_BITS ( 2 ),
       .OUT_RSP_BITS ( 2 )
   ) tb ();
endmodule

module test_outgoing_route_controller_random_slow_ctrl();
   tb_outgoing_route_controller #(
       .SEED ( 1234 ),
       .ST_IN_BITS ( 0 ),
       .ST_OUT_BITS ( 1 ),
       .FRAME_HEADER_BITS ( 4 ),
       .FRAME_COMPLETE_BITS ( 4 ),
       .FRAME_CONSUME_BITS ( 4 ),
       .BUFFER_INFO_BITS ( 4 ),
       .FRAME_INFO_BITS ( 4 ),
       .OUT_REQ_BITS ( 4 ),
       .OUT_RSP_BITS ( 4 )
   ) tb ();
endmodule

module test_outgoing_route_controller_mmapped_fast();
   tb_outgoing_route_controller #(
       .MMAPPED ( 1 )
   ) tb ();
endmodule

module test_outgoing_route_controller_mmapped_random();
   tb_outgoing_route_controller #(
       .SEED ( 12345 ),
       .ST_IN_BITS ( 1 ),
       .ST_OUT_BITS ( 1 ),
       .FRAME_HEADER_BITS ( 2 ),
       .FRAME_COMPLETE_BITS ( 2 ),
       .FRAME_CONSUME_BITS ( 2 ),
       .BUFFER_INFO_BITS ( 3 ),
       .FRAME_INFO_BITS ( 2 ),
       .OUT_REQ_BITS ( 2 ),
       .OUT_RSP_BITS ( 2 ),
       .MMAPPED ( 1 )
   ) tb ();
endmodule

module test_outgoing_route_controller_mmapped_random_2frames();
   tb_outgoing_route_controller #(
       .SEED ( 12345 ),
       .ST_IN_BITS ( 1 ),
       .ST_OUT_BITS ( 1 ),
       .FRAME_HEADER_BITS ( 2 ),
       .FRAME_COMPLETE_BITS ( 2 ),
       .FRAME_CONSUME_BITS ( 2 ),
       .BUFFER_INFO_BITS ( 3 ),
       .FRAME_INFO_BITS ( 2 ),
       .OUT_REQ_BITS ( 2 ),
       .OUT_RSP_BITS ( 2 ),
       .MMAPPED ( 1 ),
       .MMAPPED_FRAME_MAX ( 1 )
   ) tb ();
endmodule
