/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_incoming_route_controller #(
    parameter DW_LOG = 9,
    parameter CTX_ID_BITS = 4,
    parameter TDEST_BITS = 4,
    parameter EXT_RELATION = 0,
    parameter CREDIT_MAX = 1,
    parameter SELF_DEST = 5,
    parameter REG_BITS = 0,
    parameter ST_IN_BITS = 0,
    parameter ST_OUT_BITS = 0,
    parameter FRAME_HEADER_BITS = 0,
    parameter FRAME_CONSUME_BITS = 0,
    parameter FRAME_INFO_BITS = 0,
    parameter FRAME_INFO_READY_BITS = 0,
    parameter OUT_REQ_BITS = 0,
    parameter OUT_RSP_BITS = 0,
    parameter MMAPPED = 0,
    parameter MMAPPED_FRAME_MAX = 24,
    parameter DISABLE_FRAME_OUT = 0,
    parameter NEED_RELATION = 1,
    parameter FRAME_SIZE_BITS = 15,
    parameter FRAME_NUM = 100,
    parameter SEED = 12356
    ) ();

   localparam RELATION_NUM = EXT_RELATION > 0 ? 7 : 3;
   localparam KW_LOG = DW_LOG - 3;
   localparam DW = 1 << DW_LOG;
   localparam KW = 1 << KW_LOG;
   localparam CH_NUM = 1 << CTX_ID_BITS;
   localparam FRAME_MAX = 32;
   localparam FRAME0 = 8;

   localparam REG_BITS_MOD = REG_BITS > 0 ? REG_BITS : 1;
   localparam ST_IN_BITS_MOD = ST_IN_BITS > 0 ? ST_IN_BITS : 1;
   localparam ST_OUT_BITS_MOD = ST_OUT_BITS > 0 ? ST_OUT_BITS : 1;
   localparam FRAME_HEADER_BITS_MOD = FRAME_HEADER_BITS > 0 ? FRAME_HEADER_BITS : 1;
   localparam FRAME_CONSUME_BITS_MOD = FRAME_CONSUME_BITS > 0 ? FRAME_CONSUME_BITS : 1;
   localparam FRAME_INFO_BITS_MOD = FRAME_INFO_BITS > 0 ? FRAME_INFO_BITS : 1;
   localparam FRAME_INFO_READY_BITS_MOD = FRAME_INFO_READY_BITS > 0 ? FRAME_INFO_READY_BITS : 1;
   localparam OUT_REQ_BITS_MOD = OUT_REQ_BITS > 0 ? OUT_REQ_BITS : 1;
   localparam OUT_RSP_BITS_MOD = OUT_RSP_BITS > 0 ? OUT_RSP_BITS : 1;
   localparam MM_TDEST = {TDEST_BITS{1'b1}};

   reg [DW-1:0]           st_in_tdata;
   reg [KW-1:0]           st_in_tkeep;
   reg [CTX_ID_BITS-1:0]  st_in_tuser; // context id; extract tuser[12:8] (ch_id)
   reg                    st_in_tlast; // convert from tuser[6] (eop)
   reg                    st_in_eof;
   reg                    st_in_tvalid;
   wire                   st_in_tready;
   // data stream output
   wire [DW-1:0]          st_out_tdata;
   wire [KW-1:0]          st_out_tkeep;
   wire [CTX_ID_BITS-1:0] st_out_tuser;
   wire [TDEST_BITS-1:0]  st_out_tdest;
   wire                   st_out_tlast;
   wire                   st_out_tid;
   wire                   st_out_tvalid;
   reg                    st_out_tready;
   // frame header output (to functions)
   wire [127:0]           frame_header_tdata; // [63:0] frame addr; [95:64] frame size; [103:96] frame id
   wire [CTX_ID_BITS-1:0] frame_header_tuser;
   wire [TDEST_BITS-1:0]  frame_header_tdest;
   wire                   frame_header_tvalid;
   reg                    frame_header_tready;
   // frame header consume
   reg [CTX_ID_BITS-1:0]  frame_header_consume_tuser;
   reg                    frame_header_consume_tvalid;
   wire                   frame_header_consume_tready;
   // frame consume input (from functions)
   reg [7:0]              frame_consume_tdata; // frame id
   reg [CTX_ID_BITS-1:0]  frame_consume_tuser;
   reg                    frame_consume_tvalid;
   wire                   frame_consume_tready;
   // incoming frame info (from DMAC)
   reg [31:0]             frame_info_tdata; // frame size
   reg [CTX_ID_BITS-1:0]  frame_info_tuser; // context id
   reg                    frame_info_tvalid;
   wire                   frame_info_tready;
   // incoming frame ready (to DMAC)
   wire [31:0]            frame_in_ready_tdata; // frame size
   wire [CTX_ID_BITS-1:0] frame_in_ready_tuser;
   wire                   frame_in_ready_tvalid;
   reg                    frame_in_ready_tready;
   // outgoing frame request (to outgoing route controller)
   wire [CTX_ID_BITS-1:0] frame_out_req_tuser;
   wire [TDEST_BITS-1:0]  frame_out_req_tdest;
   wire                   frame_out_req_tvalid;
   reg                    frame_out_req_tready;
   // outgoing frame ready (from outgoing route controller)
   reg [CTX_ID_BITS-1:0]  frame_out_ready_tuser;
   reg                    frame_out_ready_tvalid;
   wire                   frame_out_ready_tready;
   // frame completion out
   wire [CTX_ID_BITS-1:0] frame_completion_tuser; // ch
   wire                   frame_completion_tvalid;
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

   incoming_route_controller #(
       .DW_LOG ( DW_LOG ),
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .TDEST_BITS ( TDEST_BITS ),
       .EXT_RELATION ( EXT_RELATION ),
       .CREDIT_MAX (CREDIT_MAX ),
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
      frame_header_consume_tvalid = 1'b0;
      frame_consume_tdata = 'd0;
      frame_consume_tuser = 'd0;
      frame_consume_tvalid = 1'b0;
      frame_info_tvalid = 1'b0;
      frame_in_ready_tready = 1'b1;
      frame_out_req_tready = 1'b1;
      frame_out_ready_tvalid = 1'b0;
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
   reg                   st_eof_saved[0:CH_NUM-1][0:255];
   reg [TDEST_BITS-1:0]  st_dest_saved[0:CH_NUM-1][0:255];
   reg [7:0]             st_wpos[0:CH_NUM-1];
   reg [7:0]             st_rpos[0:CH_NUM-1];

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
                st_out_tid !== st_eof_saved[st_out_tuser][st_rpos[st_out_tuser]] ||
                st_out_tdest !== st_dest_saved[st_out_tuser][st_rpos[st_out_tuser]]) begin
               $error("%d: [%2h] %h %h, %h %h, %h %h, %h %h", $time, st_out_tuser,
                      st_out_tdata, st_data_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_tkeep, st_keep_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_tlast, st_last_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_tid, st_eof_saved[st_out_tuser][st_rpos[st_out_tuser]],
                      st_out_tdest, st_dest_saved[st_out_tuser][st_rpos[st_out_tuser]]);
            end
            st_rpos[st_out_tuser] <= st_rpos[st_out_tuser] + 1'b1;
         end
         st_out_tready <= ST_OUT_BITS > 0 ? &rd[9+:ST_OUT_BITS_MOD] : 1'b1;
      end
   end

   reg                  channel_valids[0:CH_NUM-1];
   reg                  channel_is_mmapped[0:CH_NUM-1];
   reg                  channel_disable_frame_out[0:CH_NUM-1];
   reg [TDEST_BITS-1:0] channel_dests[0:CH_NUM-1];
   reg [31:0]           channel_frame_size[0:CH_NUM-1];
   reg [63:0]           channel_addrs[0:CH_NUM-1][0:FRAME_MAX-1];
   reg [FRAME_MAX-1:0]  channel_frame_valids[0:CH_NUM-1];
   reg [FRAME_MAX-1:0]  channel_frame_used[0:CH_NUM-1];
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
         for (int j=0; j<RELATION_NUM; j++) channel_relations[i][j] = 'd0;
      end
   end

   reg [31:0] frame_size_saved[0:CH_NUM-1][0:255];
   reg [31:0] frame_size_isaved[0:CH_NUM-1][0:255];
   reg [7:0]  frame_size_wpos[0:CH_NUM-1];
   reg [7:0]  frame_size_rpos[0:CH_NUM-1];
   reg [7:0]  frame_size_iwpos[0:CH_NUM-1];
   reg [7:0]  frame_size_irpos[0:CH_NUM-1];
   reg [7:0]  frame_out_saved[0:CH_NUM-1];
   reg [7:0]  frame_idx_saved[0:CH_NUM-1][0:255];
   reg [7:0]  frame_idx_wpos[0:CH_NUM-1];
   reg [7:0]  frame_idx_cpos[0:CH_NUM-1];
   reg [7:0]  frame_idx_rpos[0:CH_NUM-1];

   initial begin
      for (int i=0; i<CH_NUM; i++) begin
         frame_size_wpos[i] = 'd0;
         frame_size_rpos[i] = 'd0;
         frame_size_iwpos[i] = 'd0;
         frame_size_irpos[i] = 'd0;
         frame_out_saved[i] = 'd0;
         frame_idx_wpos[i] = 'd0;
         frame_idx_cpos[i] = 'd0;
         frame_idx_rpos[i] = 'd0;
      end
   end

   // frame in ready
   always @(posedge clk) begin
      if (resetn) begin
         if (frame_in_ready_tvalid & frame_in_ready_tready) begin
            frame_size_isaved[frame_in_ready_tuser][frame_size_iwpos[frame_in_ready_tuser]] <= frame_in_ready_tdata;
            frame_size_iwpos[frame_in_ready_tuser] <= frame_size_iwpos[frame_in_ready_tuser] + 1'b1;
            $display("%d: [%2h] frame in ready size: %h", $time, frame_in_ready_tuser, frame_in_ready_tdata);
         end
      end
   end

   // frame out req/ready
   logic [3:0] rev_relation_nums[0:CH_NUM-1];
   logic [7:0] rev_relations[0:CH_NUM-1][0:RELATION_NUM-1];
   logic [7:0] rev_relation_dests[0:CH_NUM-1][0:RELATION_NUM-1];
   initial begin
      for (int i=0; i<CH_NUM; i++) rev_relation_nums[i] = 'd0;
   end
   always @(posedge clk) begin
      if (resetn) begin
         if (frame_out_req_tvalid & frame_out_req_tready) begin
            if (frame_out_req_tdest !== rev_relation_dests[frame_out_req_tuser][0]) begin
               $error("%d: [%2h] frame out req destination: %h %h", $time, frame_out_req_tuser,
                      frame_out_req_tdest, rev_relation_dests[frame_out_req_tuser][0]);
            end
            frame_out_ready_tvalid <= 1'b1;
            frame_out_ready_tuser <= rev_relations[frame_out_req_tuser][0];
            $display("%d: [%2h] frame out req/ready channel: %h", $time, rev_relations[frame_out_req_tuser][0],
                     frame_out_req_tuser);
         end else begin
            frame_out_ready_tvalid <= frame_out_ready_tvalid & ~frame_out_ready_tready;
         end
         frame_out_req_tready <= OUT_REQ_BITS > 0 ? &rd[12+:OUT_REQ_BITS_MOD] : 1'b1;
      end
   end

   // frame header check
   logic frame_is_valid;
   always @(posedge clk) begin
      if (resetn) begin
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
                (frame_header_tdata[64+:32] !== frame_size_saved[frame_header_tuser][frame_size_rpos[frame_header_tuser]] &&
                 ~channel_is_mmapped[frame_header_tuser])) begin
               $error("%d: [%2h] frame header addr[%2d]: %h %h, size: %h %h", $time, frame_header_tuser,
                      frame_header_tdata[96+:8], frame_header_tdata[63:0], channel_addrs[frame_header_tuser][frame_header_tdata[96+:8]],
                      frame_header_tdata[64+:32], frame_size_saved[frame_header_tuser][frame_size_rpos[frame_header_tuser]]);
            end
            if (frame_header_tdata[64+:32] !== frame_size_saved[frame_header_tuser][frame_size_rpos[frame_header_tuser]]) begin
               $error("%d: [%2h] frame header size: %h %h", $time, frame_header_tuser,
                      frame_header_tdata[64+:32], frame_size_saved[frame_header_tuser][frame_size_rpos[frame_header_tuser]]);
            end
            frame_size_rpos[frame_header_tuser] <= frame_size_rpos[frame_header_tuser] + 1'b1;
            frame_header_consume_tuser <= frame_header_tuser;
            frame_header_consume_tvalid <= 1'b1;
         end else begin
            frame_header_consume_tvalid <= frame_header_consume_tvalid & ~frame_header_consume_tready;
         end
      end
   end

   // frame completion check
   logic [15:0] issued_frames[0:CH_NUM-1];
   logic [15:0] completion_frames[0:CH_NUM-1];
   always @(posedge clk) begin
      if (~resetn) begin
         for (int i=0; i<CH_NUM; i++) begin
            issued_frames[i] <= 'd0;
            completion_frames[i] <= 'd0;
         end
      end else begin
         if (frame_completion_tvalid) begin
            completion_frames[frame_completion_tuser] <= completion_frames[frame_completion_tuser] + 1'b1;
         end
      end
   end
   wire [16*CH_NUM-1:0] issued_frames_vec;
   wire [16*CH_NUM-1:0] completion_frames_vec;
   generate
      for (genvar i=0; i<CH_NUM; i++) begin
         assign issued_frames_vec[16*i+:16] = issued_frames[i];
         assign completion_frames_vec[16*i+:16] = completion_frames[i];
      end
   endgenerate

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
         destination = ch_valid ? is_mmapped ? MM_TDEST : ch : {TDEST_BITS{1'b1}};
         frame_size = {{26-FRAME_SIZE_BITS{1'b0}}, rd[FRAME_SIZE_BITS-1:6], 6'd0};
         relation_num = NEED_RELATION > 0 ? {2'b0, &rd[3+ch+:2]} : 3'd0;
         if (relation_total + relation_num > CH_NUM) relation_num = CH_NUM - relation_total;
         relation_total += relation_num;
         for (int j=0; j<relation_num;) @(posedge clk) begin
            relations[8*j+:8] = {rd[18+:8-CTX_ID_BITS], rd[4+:CTX_ID_BITS]};
            if (!relation_used[relations[8*j+:CTX_ID_BITS]]) begin
               relation_used[relations[8*j+:CTX_ID_BITS]] = 1'b1;
               rev_relations[relations[8*j+:CTX_ID_BITS]][rev_relation_nums[relations[8*j+:CTX_ID_BITS]]] = ch;
               rev_relation_dests[relations[8*j+:CTX_ID_BITS]][rev_relation_nums[relations[8*j+:CTX_ID_BITS]]] = {'d0, relations[8*j+CTX_ID_BITS+:8-CTX_ID_BITS]};
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
         for (int j=0; j<relation_num; j++) channel_relations[ch][j] = relations[j*8+:8];

         $display("[%2h]: valid: %d, mmap: %d, disable: %d, dest: %x, size: %h, valids: %h, relation: %d", ch,
                  ch_valid, is_mmapped, disable_frame_out_signal, destination,
                  frame_size, frame_valids, relation_num);
         for (int j=0; j<relation_num; j++) $display("[%2h]:  [%2d]: %h", ch, j, relations[j*8+:8]);

         // write configs
         for (logic [4:0] j=0; j<(EXT_RELATION > 0 ? 6 : 5);) @(posedge clk) begin : write_config
            wvalid = REG_BITS > 0 ? &rd[3+:REG_BITS_MOD] : 1'b1;
            cfg_wvalid <= wvalid;
            cfg_waddr <= {ch, j};
            cfg_wdata <= j == 0 ? {{16-TDEST_BITS{1'b0}}, destination,
                                   7'd0, disable_frame_out_signal, 3'd0, is_mmapped, 3'd0, ch_valid} :
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
               cfg_raddr <= rd;
            end
            if (cfg_rvalid) begin
               rdata_exp = j==0 ? {{16-TDEST_BITS{1'b0}}, destination,
                                   7'd0, disable_frame_out_signal, 3'd0, is_mmapped, 3'd0, ch_valid} :
                           j==1 ? frame_size :
                           j==2 ? frame_valids & (32'hffffffff << FRAME0):
                           j==3 ? frame_used & (32'hffffffff << FRAME0):
                           j==4 ? {relations[23:0], 4'd0, relation_num} : relations >> 24;
               if (cfg_rdata != rdata_exp) begin
                  $error("%d: [%2h] %h: %h %h", $time, ch, cfg_raddr, cfg_rdata, rdata_exp);
               end
               rwait = 0;
               j++;
            end
         end
         // read frame addrs (debug)
         for (logic [4:0] j=FRAME0; j<32;) @(posedge clk) begin : read_addrs
            arvalid = REG_BITS > 0 ? &rd[5+:REG_BITS_MOD] : 1'b1;
            if (~rwait) begin
               cfg_arvalid <= arvalid;
               cfg_raddr <= {ch, j};
               rwait = arvalid;
            end else begin
               cfg_arvalid <= 1'b0;
               cfg_raddr <= rd;
            end
            if (cfg_rvalid) begin
               $display("%d: [%2h] frame addr[%2h] read: %h", $time, ch, j-FRAME0, {20'd0, cfg_rdata, 12'd0});
               rwait = 0;
               if (j<31) j++;
            end
            if (~frame_valids[j] || j==31) break;
         end
      end
   endtask

   task static generate_frame_info();
      logic [CTX_ID_BITS-1:0] ch;
      logic [31:0]            frame_size, frame_size_mod;
      logic                   valid;
      int                     frames = 0;
      while (frames < FRAME_NUM || frame_info_tvalid) @(posedge clk) begin
         if ((~frame_info_tvalid | frame_info_tready) && frames < FRAME_NUM) begin
            ch = rd[10+:CTX_ID_BITS];
            valid = FRAME_INFO_BITS > 0 ? &rd[5+:FRAME_INFO_BITS_MOD] : 1'b1;
            valid = valid & channel_valids[ch];
            frame_info_tvalid <= valid;
            if (valid) begin
               frame_size = {{26-FRAME_SIZE_BITS{1'b0}}, rd[FRAME_SIZE_BITS-1:0]};
               frame_info_tdata <= frame_size;
               frame_info_tuser <= ch;
               frames <= frames + 1;
            end
         end else begin
            frame_info_tvalid <= frame_info_tvalid & ~frame_info_tready;
         end
         if (frame_info_tvalid && frame_info_tready) begin
            if (frame_info_tdata > channel_frame_size[frame_info_tuser] &&
                (|channel_frame_size[frame_info_tuser] || channel_is_mmapped[frame_info_tuser])) begin
               frame_size_mod = channel_frame_size[frame_info_tuser];
            end else begin
               frame_size_mod = frame_info_tdata;
            end
            frame_size_saved[frame_info_tuser][frame_size_wpos[frame_info_tuser]] <= frame_size_mod;
            frame_size_wpos[frame_info_tuser] <= frame_size_wpos[frame_info_tuser] + 1'b1;
            $display("%d: [%2h] frame info size: %h %h", $time, frame_info_tuser, frame_info_tdata, frame_size_mod);
         end
      end
      @(posedge clk) frame_info_tvalid <= 1'b0;
   endtask

   task static generate_stream_data();
      logic [31:0] pos[0:CH_NUM-1];
      logic [CTX_ID_BITS-1:0] ch = 0;
      logic [3:0]             burst = 0;
      logic [DW-1:0]          data;
      logic [KW-1:0]          keep;
      logic                   last = 1;
      logic                   eof;
      logic                   valid;
      int                     frames = 0;
      logic [32*CH_NUM-1:0]   pos_vec;
      for (int i=0; i<CH_NUM; i++) pos[i] = 0;
      while (frames < FRAME_NUM || st_in_tvalid || valid) @(posedge clk) begin
         for (int i=0; i<CH_NUM; i++) pos_vec[i*32+:32] <= pos[i];
         if (~|burst) begin
            ch = rd[14+:CTX_ID_BITS];
            if (~|pos[ch] && frames < FRAME_NUM) begin
               if (channel_valids[ch]) begin
                  if (frame_size_iwpos[ch] !== frame_size_irpos[ch]) begin
                     pos[ch] = frame_size_isaved[ch][frame_size_irpos[ch]];
                     frame_size_irpos[ch] = frame_size_irpos[ch] + 1'b1;
                  end
               end
            end
            if (|pos[ch]) begin
               burst = (pos[ch] + KW - 1) / KW < 'd8 ? (pos[ch] + KW - 1) / KW : 'd8;
               eof = (pos[ch] + KW - 1) / KW <= 'd8;
               if (eof) begin
                  issued_frames[ch] <= issued_frames[ch] + 1'b1;
                  frame_idx_cpos[ch] <= frame_idx_cpos[ch] + 1'b1;
               end
            end
         end
         if ((~st_in_tvalid | st_in_tready) & |burst)  begin
            for (int i=0; i<KW; i++) begin
               if (burst > 1 || i < pos[ch]) begin
                  data[i*8+:8] = {rd, rd ^ 32'hf00baa11, rd ^ 32'hdeadbeef} >> ((i*8) & 63);
                  keep[i] = 1'b1;
               end else begin
                  data[i*8+:8] = 8'd0;
                  keep[i] = 1'b0;
               end
            end
            last = burst == 1;
            valid = ST_IN_BITS > 0 ? &rd[6+:ST_IN_BITS_MOD] : 1'b1;
            if (valid) begin
               st_in_tdata <= data;
               st_in_tkeep <= keep;
               st_in_tuser <= ch;
               st_in_tlast <= last;
               st_in_eof <= eof && last;
               st_data_saved[ch][st_wpos[ch]] <= data;
               st_keep_saved[ch][st_wpos[ch]] <= keep;
               st_last_saved[ch][st_wpos[ch]] <= last;
               st_eof_saved[ch][st_wpos[ch]] <= last && eof;
               st_dest_saved[ch][st_wpos[ch]] <= channel_dests[ch];
               st_wpos[ch] <= st_wpos[ch] + 1'b1;
               if (pos[ch] <= DW/8) begin
                  pos[ch] = 'd0;
                  if (channel_valids[ch]) frames++;
               end else begin
                  pos[ch] -= DW/8;
               end
               burst--;
            end
            st_in_tvalid <= valid;
         end else begin
            valid = 1'b0;
            st_in_tvalid <= st_in_tvalid & ~st_in_tready;
         end
      end
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
            if (remain) no_action = 0;
         end
      end
   endtask

   wire [CH_NUM*8-1:0] w_idx_wpos, w_idx_rpos, w_idx_cpos;
   generate
      for (genvar i=0; i<CH_NUM; i++) begin
         assign w_idx_wpos[8*i+:8] = frame_idx_wpos[i];
         assign w_idx_cpos[8*i+:8] = frame_idx_cpos[i];
         assign w_idx_rpos[8*i+:8] = frame_idx_rpos[i];
      end
   endgenerate

   logic frame_completions_match;
   initial begin
      @(posedge clk);
      while (resetn !== 1'b1) @(posedge clk);

      setup_regs();

      fork
         begin
            generate_frame_info();
         end
         begin
            generate_stream_data();
         end
         begin
            generate_frame_consume();
         end
      join

      for (int j=0; j<100; j++) @(posedge clk) begin
         frame_completions_match = 1;
         for (int i=0; i<CH_NUM; i++) begin
            if (issued_frames[i] !== completion_frames[i]) frame_completions_match = 0;
         end
         if (frame_completions_match) $finish;
      end
      $error("%d: frame completions unmatched", $time);
      for (int i=0; i<CH_NUM; i++) begin
         $display("%d: [%2h] %h %h", $time, i, issued_frames[i], completion_frames[i]);
      end
      $finish;
   end
endmodule

module test_incoming_route_controller_random_fast();
   tb_incoming_route_controller tb();
endmodule

module test_incoming_route_controller_random();
   tb_incoming_route_controller #(
       .SEED ( 12345 ),
       .ST_IN_BITS ( 1 ),
       .ST_OUT_BITS ( 1 ),
       .FRAME_HEADER_BITS ( 2 ),
       .FRAME_CONSUME_BITS ( 2 ),
       .FRAME_INFO_BITS ( 2 ),
       .FRAME_INFO_READY_BITS ( 2 ),
       .OUT_REQ_BITS ( 2 ),
       .OUT_RSP_BITS ( 2 )
   ) tb ();
endmodule

module test_incoming_route_controller_mmapped_fast();
   tb_incoming_route_controller #(
       .MMAPPED ( 1 )
   ) tb ();
endmodule

module test_incoming_route_controller_mmapped_random();
   tb_incoming_route_controller #(
       .SEED ( 12345 ),
       .ST_IN_BITS ( 1 ),
       .ST_OUT_BITS ( 1 ),
       .FRAME_HEADER_BITS ( 2 ),
       .FRAME_CONSUME_BITS ( 2 ),
       .FRAME_INFO_BITS ( 2 ),
       .FRAME_INFO_READY_BITS ( 2 ),
       .OUT_REQ_BITS ( 2 ),
       .OUT_RSP_BITS ( 2 ),
       .MMAPPED ( 1 )
   ) tb ();
endmodule

module test_incoming_route_controller_mmapped_random_2frames();
   tb_incoming_route_controller #(
       .SEED ( 12345 ),
       .ST_IN_BITS ( 1 ),
       .ST_OUT_BITS ( 1 ),
       .FRAME_HEADER_BITS ( 2 ),
       .FRAME_CONSUME_BITS ( 2 ),
       .FRAME_INFO_BITS ( 2 ),
       .FRAME_INFO_READY_BITS ( 2 ),
       .OUT_REQ_BITS ( 2 ),
       .OUT_RSP_BITS ( 2 ),
       .MMAPPED ( 1 ),
       .MMAPPED_FRAME_MAX ( 1 )
   ) tb ();
endmodule
