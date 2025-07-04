/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_toe_ctrl_rx #(
    parameter DW_LOG = 9,
    parameter BURST_BITS = 6,
    parameter CH_NUM_LOG = 4,
    parameter SESSION_NUM_LOG = 8,
    parameter FRAME_MAX = 8,
    parameter MAX_INFLIGHT = 2,
    parameter ACTIVATE_MAGIC = 32'h56544341, // ACTV
    parameter CREDIT_MAGIC = 32'h54445243,  // CRDT
    parameter RX_IN_BITS = 1,
    parameter RX_OUT_BITS = 1,
    parameter TX_IN_BITS = 1,
    parameter TX_OUT_BITS = 1,
    parameter FIXED_FRAME_SIZE = 0,
    parameter FRAME_INFO_OUT_BITS = 1,
    parameter FRAME_INFO_IN_BITS = 1,
    parameter MAX_FRAME_SIZE_BITS = 14,
    parameter FRAME_SIZE_MASK = 32'hffffffff,
    parameter MAX_CREDIT_BITS = 3,
    parameter FIXED_CH = 4,
    parameter ENABLE_FIXED_CH = 0,
    parameter ENABLE_OVER_SIZE = 0,
    parameter PACKET_CONCAT = 0,
    parameter MAX_TRANSFERS = 100
    ) ();

   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam DW = 1 << DW_LOG;
   localparam KW_LOG = DW_LOG - 3;
   localparam KW = 1 << KW_LOG;
   localparam BURST_SIZE = 1 << (BURST_BITS + KW_LOG);
   localparam FRAME_SIZE_MAX = 1 << MAX_FRAME_SIZE_BITS;

   localparam RX_IN_BITS_MOD = RX_IN_BITS > 0 ? RX_IN_BITS : 1;
   localparam RX_OUT_BITS_MOD = RX_OUT_BITS > 0 ? RX_OUT_BITS : 1;
   localparam TX_IN_BITS_MOD = TX_IN_BITS > 0 ? TX_IN_BITS : 1;
   localparam TX_OUT_BITS_MOD = TX_OUT_BITS > 0 ? TX_OUT_BITS : 1;
   localparam FRAME_INFO_IN_BITS_MOD = FRAME_INFO_IN_BITS > 0 ? FRAME_INFO_IN_BITS : 1;
   localparam FRAME_INFO_OUT_BITS_MOD = FRAME_INFO_OUT_BITS > 0 ? FRAME_INFO_OUT_BITS : 1;

   reg [(1<<DW_LOG)-1:0]                   rx_toe_tdata;
   reg [(1<<(DW_LOG-3))-1:0]               rx_toe_tkeep;
   reg [SESSION_NUM_LOG-1:0]               rx_toe_tuser;
   reg                                     rx_toe_tlast;
   reg                                     rx_toe_tvalid;
   wire                                    rx_toe_tready;

   wire [(1<<DW_LOG)-1:0]                  rx_tx_tdata;
   wire [(1<<(DW_LOG-3))-1:0]              rx_tx_tkeep;
   wire [CH_NUM_LOG-1:0]                   rx_tx_tuser;
   wire                                    rx_tx_tlast; // eop
   wire                                    rx_tx_tvalid;
   reg                                     rx_tx_tready;

   wire [(1<<DW_LOG)-1:0]                  tx_tdata;
   wire [(1<<(DW_LOG-3))-1:0]              tx_tkeep;
   wire [SESSION_NUM_LOG-1:0]              tx_tuser;
   wire [BURST_BITS-1:0]                   tx_burst;
   wire [DW_LOG-4:0]                       tx_last_cnts;
   wire                                    tx_tlast;
   wire                                    tx_tvalid;
   reg                                     tx_tready;

   wire [(1<<DW_LOG)-1:0]                  rx_out_tdata;
   wire [(1<<(DW_LOG-3))-1:0]              rx_out_tkeep;
   wire [CH_NUM_LOG-1:0]                   rx_out_tuser;
   wire                                    rx_out_tlast; // eop
   wire                                    rx_out_eof;
   wire                                    rx_out_tvalid;
   reg                                     rx_out_tready;

   wire [31:0]                             frame_info_out_tdata; // frame size
   wire [CH_NUM_LOG-1:0]                   frame_info_out_tuser;
   wire                                    frame_info_out_tvalid;
   reg                                     frame_info_out_tready;

   reg [31:0]                              frame_info_tdata; // frame size
   reg [CH_NUM_LOG-1:0]                    frame_info_tuser;
   reg                                     frame_info_tvalid;
   wire                                    frame_info_tready;

   reg [(1<<CH_NUM_LOG)-1:0]               rx_ch_valids;
   reg [(1<<CH_NUM_LOG)-1:0]               rx_ch_activates;
   reg [(1<<CH_NUM_LOG)-1:0]               rx_ch_actives;
   reg [(1<<CH_NUM_LOG)-1:0]               rx_ch_readys;
   reg [(SESSION_NUM_LOG<<CH_NUM_LOG)-1:0] rx_ch_session_ids;
   reg [(32<<CH_NUM_LOG)-1:0]              rx_ch_frame_sizes;
   reg [(16<<CH_NUM_LOG)-1:0]              rx_ch_credit_max;
   reg [(16<<CH_NUM_LOG)-1:0]              rx_ch_credit_cur;

   wire [SESSION_NUM_LOG-1:0]              rx_credit_inc_session_id;
   wire                                    rx_credit_inc;
   wire [SESSION_NUM_LOG-1:0]              rx_credit_dec_session_id;
   wire                                    rx_credit_dec;

   wire [SESSION_NUM_LOG-1:0]              find_ch_session_id;
   wire                                    find_ch_valid;
   reg [CH_NUM_LOG-1:0]                    find_ch_id;
   reg                                     find_ch_id_tx_valid;
   reg                                     find_ch_id_rx_valid;
   reg                                     find_ch_id_invalid;

   wire [SESSION_NUM_LOG-1:0]              activate_done_session_id;
   wire                                    activate_done;

   wire                                    clk;
   wire                                    resetn;
   wire [31:0]                             rd;

   clk_reset clk_reset (
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
   );

   toe_ctrl_rx #(
       .DW_LOG ( DW_LOG ),
       .BURST_BITS ( BURST_BITS ),
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .SESSION_NUM_LOG ( SESSION_NUM_LOG ),
       .FRAME_MAX ( FRAME_MAX ),
       .MAX_INFLIGHT ( MAX_INFLIGHT )
   ) dut (
       .*
   );

   initial begin
      rx_toe_tvalid = 1'b0;
      rx_tx_tready = 1'b1;
      tx_tready = 1'b1;
      rx_out_tready = 1'b1;
      frame_info_out_tready = 1'b1;
      frame_info_tvalid = 1'b0;
      rx_ch_valids = 'd0;
      rx_ch_activates = 'd0;
      rx_ch_actives = 'd0;
      rx_ch_readys = 'd0;
      rx_ch_session_ids = 'd0;
      rx_ch_frame_sizes = 'd0;
      rx_ch_credit_max = 'd0;
      rx_ch_credit_cur = 'd0;
      find_ch_id_tx_valid = 1'b0;
      find_ch_id_rx_valid = 1'b0;
      find_ch_id_invalid = 1'b0;
   end

   reg [SESSION_NUM_LOG*CH_NUM-1:0] tx_ch_session_ids;
   initial begin
      tx_ch_session_ids = 'd0;
   end

   always @(posedge clk) begin
      if (resetn) begin
         frame_info_out_tready <= FRAME_INFO_OUT_BITS > 0 ? &rd[12+:FRAME_INFO_OUT_BITS_MOD] : 1'b1;
         rx_out_tready <= RX_OUT_BITS > 0 ? &rd[14+:RX_OUT_BITS_MOD] : 1'b1;
         tx_tready <= TX_IN_BITS > 0 ? &rd[16+:TX_IN_BITS_MOD] : 1'b1;
         rx_tx_tready <= TX_OUT_BITS > 0 ? &rd[18+:TX_OUT_BITS_MOD] : 1'b1;
      end
   end

   logic ch_found;
   always @(posedge clk) begin
      if (resetn) begin
         if (activate_done) begin
            for (int i=0; i<CH_NUM; i++) begin
               if (rx_ch_session_ids[i*SESSION_NUM_LOG+:SESSION_NUM_LOG] == activate_done_session_id) begin
                  rx_ch_activates[i] <= 1'b0;
                  rx_ch_actives[i] <= 1'b1;
                  rx_ch_readys[i] <= rx_ch_valids[i];
                  break;
               end
            end
         end
         if (rx_credit_inc) begin
            for (int i=0; i<CH_NUM; i++) begin
               if (rx_ch_session_ids[i*SESSION_NUM_LOG+:SESSION_NUM_LOG] == rx_credit_inc_session_id) begin
                  rx_ch_credit_cur[i*16+:16]++;
                  break;
               end
            end
         end
         if (rx_credit_dec) begin
            for (int i=0; i<CH_NUM; i++) begin
               if (rx_ch_session_ids[i*SESSION_NUM_LOG+:SESSION_NUM_LOG] == rx_credit_dec_session_id) begin
                  rx_ch_credit_cur[i*16+:16]--;
                  break;
               end
            end
         end
         if (find_ch_valid) begin
            ch_found = 0;
            for (int i=0; i<CH_NUM; i++) begin
               if (rx_ch_session_ids[i*SESSION_NUM_LOG+:SESSION_NUM_LOG] == find_ch_session_id) begin
                  ch_found = 1;
                  find_ch_id <= i;
                  find_ch_id_rx_valid <= 1'b1;
                  find_ch_id_tx_valid <= 1'b0;
                  find_ch_id_invalid <= 1'b0;
                  break;
               end else if (tx_ch_session_ids[i*SESSION_NUM_LOG+:SESSION_NUM_LOG] == find_ch_session_id) begin
                  ch_found = 1;
                  find_ch_id <= i;
                  find_ch_id_rx_valid <= 1'b0;
                  find_ch_id_tx_valid <= 1'b1;
                  find_ch_id_invalid <= 1'b0;
                  break;
               end
            end
            if (~ch_found) begin
               find_ch_id_rx_valid <= 1'b0;
               find_ch_id_tx_valid <= 1'b0;
               find_ch_id_invalid <= 1'b1;
            end
         end else begin
            find_ch_id_rx_valid <= 1'b0;
            find_ch_id_tx_valid <= 1'b0;
            find_ch_id_invalid <= 1'b0;
         end
      end
   end

   reg [DW-1:0] rx_data_saved[0:255];
   reg [KW-1:0] rx_keep_saved[0:255];
   reg [CH_NUM_LOG-1:0] rx_user_saved[0:255];
   reg                  rx_last_saved[0:255];
   reg                  rx_eof_saved[0:255];
   reg [7:0]            rx_wpos, rx_rpos;
   initial begin
      rx_wpos = 'd0;
      rx_rpos = 'd0;
   end
   logic [DW-1:0] w_rx_out_data_masked;
   logic [DW-1:0] w_rx_out_exp_masked;
   always @(posedge clk) begin
      if (resetn && rx_out_tvalid && rx_out_tready) begin
         for (int i=0; i<KW; i++) w_rx_out_data_masked[i*8+:8] = rx_out_tdata[i*8+:8] & {8{rx_out_tkeep[i]}};
         for (int i=0; i<KW; i++) w_rx_out_exp_masked[i*8+:8] = rx_data_saved[rx_rpos][i*8+:8] & {8{rx_keep_saved[rx_rpos][i]}};
         if (w_rx_out_data_masked !== w_rx_out_exp_masked ||
             rx_out_tkeep !== rx_keep_saved[rx_rpos] ||
             rx_out_tuser !== rx_user_saved[rx_rpos] ||
             rx_out_tlast !== rx_last_saved[rx_rpos] ||
             rx_out_eof !== rx_eof_saved[rx_rpos]) begin
            $error("%d: [%2h] rx data: %h %h, %h %h, %h %h, %h %h, %h %h (%d/%d)", $time, rx_out_tuser,
                   w_rx_out_data_masked, w_rx_out_exp_masked,
                   rx_out_tkeep, rx_keep_saved[rx_rpos],
                   rx_out_tuser, rx_user_saved[rx_rpos],
                   rx_out_tlast, rx_last_saved[rx_rpos],
                   rx_out_eof, rx_eof_saved[rx_rpos], rx_wpos, rx_rpos);
         end else begin
            $display("%d: [%2h] rx data: %h %h, %h %h, %h %h, %h %h, %h %h (%d/%d)", $time, rx_out_tuser,
                     w_rx_out_data_masked, w_rx_out_exp_masked,
                     rx_out_tkeep, rx_keep_saved[rx_rpos],
                     rx_out_tuser, rx_user_saved[rx_rpos],
                     rx_out_tlast, rx_last_saved[rx_rpos],
                     rx_out_eof, rx_eof_saved[rx_rpos], rx_wpos, rx_rpos);
         end
         rx_rpos <= rx_rpos + 1'b1;
      end
   end

   reg [DW-1:0] activate_credit_data_saved[0:255];
   reg [KW-1:0] activate_credit_keep_saved[0:255];
   reg [CH_NUM_LOG-1:0] activate_credit_ch_saved[0:255];
   reg [7:0]            activate_credit_wpos, activate_credit_rpos;
   initial begin
      activate_credit_wpos = 'd0;
      activate_credit_rpos = 'd0;
   end
   always @(posedge clk) begin
      if (resetn && rx_tx_tvalid && rx_tx_tready) begin
         if (rx_tx_tdata !== activate_credit_data_saved[activate_credit_rpos] ||
             rx_tx_tkeep !== activate_credit_keep_saved[activate_credit_rpos] ||
             rx_tx_tuser !== activate_credit_ch_saved[activate_credit_rpos] ||
             rx_tx_tlast !== 1'b1) begin
            $error("%d: tx activate/credit: %h %h, %h %h, %h %h, %h", $time,
                   rx_tx_tdata, activate_credit_data_saved[activate_credit_rpos],
                   rx_tx_tkeep, activate_credit_keep_saved[activate_credit_rpos],
                   rx_tx_tuser, activate_credit_ch_saved[activate_credit_rpos], rx_tx_tlast);
         end
         activate_credit_rpos <= activate_credit_rpos + 1'b1;
      end
   end

   reg [31:0] frame_size_saved[0:CH_NUM-1][0:255];
   reg [7:0]  frame_size_spos[0:CH_NUM-1];
   reg [7:0]  frame_size_wpos[0:CH_NUM-1];
   reg [7:0]  frame_size_rpos[0:CH_NUM-1];
   reg [7:0]  frame_size_epos[0:CH_NUM-1];
   initial begin
      for (int i=0; i<CH_NUM; i++) begin
         frame_size_spos[i] = 'd0;
         frame_size_wpos[i] = 'd0;
         frame_size_rpos[i] = 'd0;
         frame_size_epos[i] = 'd0;
      end
   end
   always @(posedge clk) begin
      if (resetn && frame_info_out_tvalid && frame_info_out_tready) begin
         frame_size_saved[frame_info_out_tuser][frame_size_spos[frame_info_out_tuser]] <= frame_info_out_tdata;
         frame_size_spos[frame_info_out_tuser] <= frame_size_spos[frame_info_out_tuser] + 1'b1;
         $display("%d: [%2h] frame info out: size:%h (%d)", $time, frame_info_out_tuser, frame_info_out_tdata, frame_size_spos[frame_info_out_tuser]);
      end
   end

   always @(posedge clk) begin
      if (resetn) begin
         if (tx_tvalid && tx_tready) begin
            for (int i=0; i<CH_NUM; i++) begin
               if (tx_tuser == rx_ch_session_ids[i*SESSION_NUM_LOG+:SESSION_NUM_LOG]) begin
                  if (tx_tdata[31:0] == ACTIVATE_MAGIC) begin
                     if (tx_tdata[32+:32] !== rx_ch_frame_sizes[i*32+:32] ||
                         tx_tdata[64+:16] !== rx_ch_credit_max[i*16+:16] ||
                         tx_tkeep !== 'h3ff || !tx_tlast ||
                         tx_burst !== 'd0 || tx_last_cnts !== 'd9) begin
                        $error("%d: [%2h] tx activate: size:%h %h, credit:%h %h, keep: %h", $time, i,
                               tx_tdata[32+:32], rx_ch_frame_sizes[i*32+:32],
                               tx_tdata[64+:16], rx_ch_credit_max[i*16+:16], tx_tkeep);
                     end
                  end else if (tx_tdata[31:0] == CREDIT_MAGIC) begin
                     if (tx_tdata[32+:32] !== frame_size_saved[i][frame_size_rpos[i]] ||
                         tx_tkeep !== 'hff || !tx_tlast ||
                         tx_burst !== 'd0 || tx_last_cnts !== 'd7) begin
                        $error("%d: [%2h] tx credit inc: size:%h %h, keep: %h (%d)", $time, i,
                               tx_tdata[32+:32], frame_size_saved[i][frame_size_rpos[i]], tx_tkeep, frame_size_rpos[i]);
                     end
                     frame_size_rpos[i] <= frame_size_rpos[i] + 1'b1;
                  end else begin
                     $error("%d: [%2h] tx unknown packet: %h", $time, i, tx_tdata);
                  end
               end
            end
         end
      end
   end

   task static setup_registers;
      logic dup;
      for (int ch=0; ch<CH_NUM; ch++) begin
         while (1) @(posedge clk) begin
            dup = 0;
            for (int j=0; j<ch; j++) if (rd[4+:SESSION_NUM_LOG] == rx_ch_session_ids[j*SESSION_NUM_LOG+:SESSION_NUM_LOG] ||
                                         rd[4+:SESSION_NUM_LOG] == tx_ch_session_ids[j*SESSION_NUM_LOG+:SESSION_NUM_LOG]) dup=1;
            if (~dup) begin
               rx_ch_session_ids[ch*SESSION_NUM_LOG+:SESSION_NUM_LOG] <= rd[4+:SESSION_NUM_LOG];
               break;
            end
         end
         @(posedge clk) rx_ch_valids[ch] <= ENABLE_FIXED_CH != 0 ? ch == FIXED_CH : rd[14];
         while (~|rx_ch_frame_sizes[ch*32+:32]) @(posedge clk) begin
            if (~|rx_ch_frame_sizes[ch*32+:32]) begin
               if (FIXED_FRAME_SIZE > 0) begin
                  rx_ch_frame_sizes[ch*32+:32] <= FIXED_FRAME_SIZE;
               end else begin
                  rx_ch_frame_sizes[ch*32+:32] <= rd & ((32'd1 << MAX_FRAME_SIZE_BITS)-1) & FRAME_SIZE_MASK;
               end
            end
         end
         while (~|rx_ch_credit_max[ch*16+:16]) @(posedge clk) begin
            if (~|rx_ch_credit_max[ch*16+:16]) rx_ch_credit_max[ch*16+:16] <= rd & ((32'd1 << MAX_CREDIT_BITS)-1);
         end
         while (1) @(posedge clk) begin
            dup = 0;
            for (int j=0; j<ch; j++) if (rd[10+:SESSION_NUM_LOG] == rx_ch_session_ids[j*SESSION_NUM_LOG+:SESSION_NUM_LOG] ||
                                         rd[10+:SESSION_NUM_LOG] == tx_ch_session_ids[j*SESSION_NUM_LOG+:SESSION_NUM_LOG]) dup=1;
            if (rd[10+:SESSION_NUM_LOG] == rx_ch_session_ids[ch*SESSION_NUM_LOG+:SESSION_NUM_LOG]) continue;
            if (~dup) begin
               tx_ch_session_ids[ch*SESSION_NUM_LOG+:SESSION_NUM_LOG] <= rd[10+:SESSION_NUM_LOG];
               break;
            end
         end
         @(posedge clk);
         $display("%d: [%2h] rx session:%h valid:%d, frame_size:%h, credit_max:%h", $time, ch,
                  rx_ch_session_ids[ch*SESSION_NUM_LOG+:SESSION_NUM_LOG], rx_ch_valids[ch], rx_ch_frame_sizes[ch*32+:32], rx_ch_credit_max[ch*16+:16]);
         $display("%d: [%2h] tx session:%h", $time, ch, tx_ch_session_ids[ch*SESSION_NUM_LOG+:SESSION_NUM_LOG]);
      end
      @(posedge clk);
      for (int ch=0; ch<CH_NUM; ch++) @(posedge clk) begin
         if (rx_ch_valids[ch]) begin
            rx_ch_activates[ch] <= 1'b1;
         end
      end
      @(posedge clk);
      for (int ch=0; ch<CH_NUM; ch++) begin
         while (rx_ch_activates[ch]) @(posedge clk);
         @(posedge clk) begin
            if ((~rx_ch_actives[ch] || ~rx_ch_readys[ch]) && rx_ch_valids[ch]) begin
               $error("%d: [%2h] valid:%d, activate:%d, active:%d, ready:%d", $time, ch,
                      rx_ch_valids[ch], rx_ch_activates[ch], rx_ch_actives[ch], rx_ch_readys[ch]);
            end
         end
      end
   endtask

   task static generate_frames;
      int frame_count = 0;
      logic [31:0] size, cur_size;
      logic [CH_NUM_LOG-1:0] ch;
      logic                  valid = 0;
      logic [7:0]            cur_spos, cur_wpos;
      while (frame_count < MAX_TRANSFERS || valid || frame_info_tvalid ) @(posedge clk) begin
         ch = rd[4+:CH_NUM_LOG];
         valid = frame_size_spos[ch] != frame_size_wpos[ch];
         cur_spos = frame_size_spos[ch];
         cur_wpos = frame_size_wpos[ch];
         valid &= FRAME_INFO_IN_BITS > 0 ? &rd[10+:FRAME_INFO_IN_BITS_MOD] : 1'b1;
         cur_size = rd & ((32'd1 << FRAME_SIZE_MAX)-1);
         valid &= |cur_size;
         if (valid && (~frame_info_tvalid | frame_info_tready)) begin
            size = frame_size_saved[ch][frame_size_wpos[ch]];
            size = size > cur_size ? cur_size : size;
            frame_size_saved[ch][frame_size_wpos[ch]] <= size;
            frame_size_wpos[ch] <= frame_size_wpos[ch] + 1'b1;
            frame_count++;
            frame_info_tdata <= size;
            frame_info_tuser <= ch;
            frame_info_tvalid <= valid;
            $display("%d: [%2h] generate frame: %d, %h > %h", $time, ch, frame_size_wpos[ch],
                     frame_size_saved[ch][frame_size_wpos[ch]], size);
         end else begin
            frame_info_tvalid <= frame_info_tvalid & ~frame_info_tready;
         end
      end
   endtask

   task static generate_rx_inputs;
      logic [DW-1:0] data, data_sep0;
      logic [KW-1:0] keep, keep_sep0;
      logic [DW-1:0] data_sep1[0:CH_NUM-1];
      logic [KW_LOG-1:0] keep_cnt_sep1[0:CH_NUM-1];
      logic          last_sub;
      logic          last;
      logic          last_in;
      logic          valid;
      logic          eof;
      logic [CH_NUM_LOG-1:0] ch;
      logic [31:0]   frame_sizes[0:CH_NUM-1];
      logic [31:0]   cur_size = 0;
      logic [7:0]    burst = 0;
      logic [31:0]   concat_size = 0;
      logic [3:0]    mode = 0;
      logic [7:0]    rx_wpos_next;
      int            frame_count = 0;
      for (int i=0; i<CH_NUM; i++) begin
         frame_sizes[i] = 'd0;
         data_sep1[i] = 'd0;
         keep_cnt_sep1[i] = 'd0;
      end
      while (frame_count < MAX_TRANSFERS || valid || rx_toe_tvalid) @(posedge clk) begin
         if (~|concat_size) begin
            ch = rd[8+:CH_NUM_LOG];
            if (~|frame_sizes[ch] && frame_size_epos[ch] != frame_size_wpos[ch]) begin
               frame_sizes[ch] = frame_size_saved[ch][frame_size_epos[ch]];
               frame_size_epos[ch] = frame_size_epos[ch] + 1'b1;
               $display("%d: [%2h] rx input size: %h", $time, ch, frame_sizes[ch]);
            end
            mode = rd[5+:4];
            burst = 0;
            if (mode[3:1] != 3'd7) begin
               cur_size = frame_sizes[ch] < BURST_SIZE ? frame_sizes[ch] :
                          ENABLE_OVER_SIZE & frame_sizes[ch] >= BURST_SIZE*2 ? BURST_SIZE*2 : BURST_SIZE;
               frame_sizes[ch] -= cur_size;
               concat_size = cur_size;
               if (~|frame_sizes[ch] && |cur_size) begin
                  eof = 1'b1;
                  frame_count <= frame_count + 1'b1;
                  $display("%d: [%2h] rx input frames: %d", $time, ch, frame_size_epos[ch]);
                  if (frame_size_epos[ch] != frame_size_wpos[ch] && PACKET_CONCAT) begin
                     if (cur_size < BURST_SIZE && BURST_SIZE - cur_size <= frame_size_saved[ch][frame_size_epos[ch]]) begin
                        frame_size_saved[ch][frame_size_epos[ch]] <= frame_size_saved[ch][frame_size_epos[ch]] - (BURST_SIZE - cur_size);
                        concat_size = BURST_SIZE;
                     end
                  end
               end else begin
                  eof = 1'b0;
               end
               if (|cur_size) begin
                  $display("%d: [%2h] rx input: size: %h(%h), remain: %h, frames:%d, keep save:%d", $time, ch,
                           cur_size, concat_size, frame_sizes[ch], frame_count, keep_cnt_sep1[ch]);
               end else begin
                  //$display("%d: [%2h] rx input: size: %h(%h), remain: %h, frames:%d, keep save:%d", $time, ch,
                  //         cur_size, concat_size, frame_sizes[ch], frame_count, keep_cnt_sep1[ch]);
               end
            end else if (mode == 4'he) begin // activate
               cur_size = 10;
               concat_size = 10;
            end else if (mode == 4'hf) begin // credit
               cur_size = 8;
               concat_size = 8;
            end
         end
         rx_wpos_next = rx_wpos + 1;
         valid = |concat_size && (RX_IN_BITS > 0 ? &rd[10+:RX_IN_BITS_MOD] : 1'b1) && (~rx_toe_tvalid || rx_toe_tready);
         valid &= (rx_wpos_next != rx_rpos) && (((rx_wpos + 2'd2) & 255) != rx_rpos);
         if (valid) begin
            for (int i=0; i<KW; i++) begin
               keep[i] = i < concat_size;
               data[i*8+:8] = ((rd >> (i&3)*8) ^ (32'h1002 << (i/4))) & {8{keep[i]}};
            end
            last_in = concat_size <= KW;
            last = concat_size <= KW || burst == ({1'b1, {BURST_BITS{1'b0}}}-1'b1);
            last_sub = burst == ({1'b1, {BURST_BITS{1'b0}}}-1'b1);
            if (mode[3:1] != 3'd7) begin
               if (cur_size > 0 && cur_size < KW) begin
                  // cycle for eof and last without fullbit keep
                  $display("%d: [%2h] A) cur_size last: %h %h %h %h, %d %d %d (%d)", $time, ch,
                           data, keep, last, eof, keep_cnt_sep1[ch], concat_size, cur_size, rx_wpos);
                  if (keep_cnt_sep1[ch] + cur_size > KW) begin
                     // separate to 2data splitted by eof
                     $display("%d: [%2h] cur_size separate last: %h %h %h %h, %d %d %d (%d)+1, (%d, %d)", $time, ch,
                              data, keep, last, eof, keep_cnt_sep1[ch], concat_size, cur_size, rx_wpos, last_sub, burst);
                     for (int i=0; i<KW; i++) begin
                        if (i < keep_cnt_sep1[ch]) begin
                           data_sep0[i*8+:8] = data_sep1[ch][i*8+:8];
                        end else begin
                           data_sep0[i*8+:8] = data[(i-keep_cnt_sep1[ch])*8+:8];
                        end
                     end
                     rx_data_saved[rx_wpos] <= data_sep0;
                     rx_keep_saved[rx_wpos] <= {KW{1'b1}};
                     rx_user_saved[rx_wpos] <= ch;
                     rx_last_saved[rx_wpos] <= last_sub;
                     rx_eof_saved[rx_wpos] <= 1'b0;
                     rx_data_saved[rx_wpos_next] <= data >> {KW - keep_cnt_sep1[ch], 3'd0};
                     rx_keep_saved[rx_wpos_next] <= ({{KW{1'b0}}, 1'b1} << (keep_cnt_sep1[ch] + cur_size - KW))-1;
                     rx_user_saved[rx_wpos_next] <= ch;
                     rx_last_saved[rx_wpos_next] <= last || eof;
                     rx_eof_saved[rx_wpos_next] <= eof;
                     rx_wpos <= rx_wpos + 2'd2;
                     // remain next frame data
                     keep_sep0 = (last ? concat_size : KW) - cur_size;
                     for (int i=0; i<keep_sep0; i++) begin
                        data_sep1[ch][i*8+:8] = data[(i + cur_size)*8+:8];
                     end
                     keep_cnt_sep1[ch] = keep_sep0;
                     burst <= 'd1;
                     $display("%d: [%2h] size: %h %d %d", $time, ch, keep_sep0, cur_size, keep_cnt_sep1[ch]);
                  end else begin
                     // output 1data and remain next frame data
                     keep_sep0 = ({{KW{1'b0}}, 1'b1} << (cur_size + keep_cnt_sep1[ch]))-1;
                     $display("%d: [%2h] cur_size no separate last: %h %h %h %h, %d %d %d, %h %h (%d), (%d, %d)", $time, ch,
                              data, keep, last, eof, keep_cnt_sep1[ch], concat_size, cur_size, keep_sep0,
                              (({{KW{1'b0}}, 1'b1} << (cur_size + keep_cnt_sep1[ch]))-1), rx_wpos, last_sub, burst);
                     for (int i=0; i<KW; i++) begin
                        if (i < keep_cnt_sep1[ch]) begin
                           data_sep0[i*8+:8] = data_sep1[ch][i*8+:8];
                        end else begin
                           data_sep0[i*8+:8] = data[(i-keep_cnt_sep1[ch])*8+:8] & {8{keep_sep0[i]}};
                        end
                     end
                     if (eof) begin
                        $display("%d: [%2h] last %h %h", $time, ch, data_sep0, keep_sep0);
                        rx_data_saved[rx_wpos] <= data_sep0;
                        rx_keep_saved[rx_wpos] <= keep_sep0;
                        rx_user_saved[rx_wpos] <= ch;
                        rx_last_saved[rx_wpos] <= 1'b1;
                        rx_eof_saved[rx_wpos] <= 1'b1;
                        rx_wpos <= rx_wpos + 1'b1;
                        // same as above
                        keep_sep0 = (last ? concat_size : KW) - cur_size;
                        for (int i=0; i<keep_sep0; i++) begin
                           data_sep1[ch][i*8+:8] = data[(i+cur_size)*8+:8];
                        end
                        keep_cnt_sep1[ch] = keep_sep0;
                        burst <= 'd0;
                     end else begin
                        data_sep1[ch] = data_sep0;
                        keep_cnt_sep1[ch] += cur_size;
                     end
                  end
                  eof = 0;
               end else begin
                  if (keep_cnt_sep1[ch] + concat_size >= KW) begin
                     for (int i=0; i<KW; i++) begin
                        if (i < keep_cnt_sep1[ch]) begin
                           data_sep0[i*8+:8] = data_sep1[ch][i*8+:8];
                           data_sep1[ch][i*8+:8] = data[(i+KW-keep_cnt_sep1[ch])*8+:8];
                        end else begin
                           data_sep0[i*8+:8] = data[(i-keep_cnt_sep1[ch])*8+:8];
                        end
                     end
                     rx_data_saved[rx_wpos] <= data_sep0;
                     rx_user_saved[rx_wpos] <= ch;
                     rx_last_saved[rx_wpos] <= last || (eof && (cur_size + keep_cnt_sep1[ch] > 0 && cur_size + keep_cnt_sep1[ch] <= KW));
                     rx_eof_saved[rx_wpos] <= eof && (cur_size + keep_cnt_sep1[ch] > 0 && cur_size + keep_cnt_sep1[ch] <= KW);
                     if (eof && (cur_size + keep_cnt_sep1[ch] > 0 && cur_size + keep_cnt_sep1[ch] <= KW &&
                                 concat_size != cur_size && |keep_cnt_sep1[ch])) begin
                        rx_keep_saved[rx_wpos] <= ({{KW{1'b0}}, 1'b1} << (cur_size + keep_cnt_sep1[ch])) - 1'b1;
                        rx_data_saved[rx_wpos_next] <= data;
                        rx_user_saved[rx_wpos_next] <= ch;
                        rx_last_saved[rx_wpos_next] <= last;
                        rx_eof_saved[rx_wpos_next] <= 1'b0;
                        rx_keep_saved[rx_wpos_next] <= {KW{1'b1}};
                        if (last) begin
                           burst <= 'd0;
                        end else begin
                           burst <= burst + 2'd2;
                        end
                        rx_wpos <= rx_wpos + 2'd2;
                        keep_cnt_sep1[ch] <= 'd0;
                        $display("%d: [%2h] B2) cur_size last: %h %h %h %h, %d %d %d (%d)+1 (%d, %d)", $time, ch,
                                 data, keep, last, eof, keep_cnt_sep1[ch], concat_size, cur_size, rx_wpos, last_sub, burst);
                     end else begin
                        rx_keep_saved[rx_wpos] <= {KW{1'b1}};
                        rx_wpos <= rx_wpos + 1'b1;
                        if (last) begin
                           burst <= 'd0;
                        end else begin
                           burst <= burst + 1'b1;
                        end
                        $display("%d: [%2h] B1) cur_size last: %h %h %h %h, %d %d %d (%d) (%d, %d)", $time, ch,
                                 data, keep, last, eof, keep_cnt_sep1[ch], concat_size, cur_size, rx_wpos, last_sub, burst);
                     end
                  end else begin
                     for (int i=keep_cnt_sep1[ch]; i<keep_cnt_sep1[ch] + concat_size; i++) begin
                        data_sep1[ch][i*8+:8] = data[(i-keep_cnt_sep1[ch])*8+:8];
                     end
                     keep_cnt_sep1[ch] += concat_size;
                  end
               end
            end else if (mode == 4'he) begin
               data[31:0] = ACTIVATE_MAGIC;
               activate_credit_data_saved[activate_credit_wpos] <= data;
               activate_credit_keep_saved[activate_credit_wpos] <= keep;
               activate_credit_ch_saved[activate_credit_wpos] <= ch;
               activate_credit_wpos <= activate_credit_wpos + 1'b1;
            end else if (mode == 4'hf) begin
               data[31:0] = CREDIT_MAGIC;
               activate_credit_data_saved[activate_credit_wpos] <= data;
               activate_credit_keep_saved[activate_credit_wpos] <= keep;
               activate_credit_ch_saved[activate_credit_wpos] <= ch;
               activate_credit_wpos <= activate_credit_wpos + 1'b1;
            end
            cur_size = cur_size <= KW? 0 : cur_size - KW;
            concat_size = last_in ? 0 : concat_size - KW;
            rx_toe_tdata <= data;
            rx_toe_tkeep <= keep;
            rx_toe_tuser <= mode[3:1] != 3'd7 ? rx_ch_session_ids[ch*SESSION_NUM_LOG+:SESSION_NUM_LOG] :
                            tx_ch_session_ids[ch*SESSION_NUM_LOG+:SESSION_NUM_LOG];
            rx_toe_tlast <= last_in;
            rx_toe_tvalid <= valid;
         end else begin
            rx_toe_tvalid <= rx_toe_tvalid & ~rx_toe_tready;
         end
      end
   endtask

   initial begin
      @(posedge clk);
      while (~resetn) @(posedge clk);

      setup_registers;
      fork
         generate_frames;
         generate_rx_inputs;
      join

      $finish;
   end

endmodule

module test_toe_ctrl_rx_random;
   tb_toe_ctrl_rx tb();
endmodule

module test_toe_ctrl_rx_fast;
   tb_toe_ctrl_rx #(
       .RX_IN_BITS ( 0 ),
       .RX_OUT_BITS ( 0 ),
       .TX_IN_BITS ( 0 ),
       .TX_OUT_BITS ( 0 )
   ) tb ();
endmodule

module test_toe_ctrl_rx_slow_frame_info;
   tb_toe_ctrl_rx #(
       .RX_IN_BITS ( 0 ),
       .RX_OUT_BITS ( 0 ),
       .TX_IN_BITS ( 0 ),
       .TX_OUT_BITS ( 0 ),
       .MAX_FRAME_SIZE_BITS ( 8 ),
       .FRAME_INFO_IN_BITS ( 5 )
   ) tb ();
endmodule

module test_toe_ctrl_rx_random_concat;
   tb_toe_ctrl_rx #(
       .PACKET_CONCAT ( 1 ),
       .MAX_TRANSFERS ( 150 )
   ) tb ();
endmodule

module test_toe_ctrl_rx_random_1ch;
   tb_toe_ctrl_rx #(
       .ENABLE_FIXED_CH ( 4 )
   ) tb ();
endmodule

module test_toe_ctrl_rx_random_1ch_aligned;
   tb_toe_ctrl_rx #(
       .MAX_FRAME_SIZE_BITS ( 14 ),
       .ENABLE_FIXED_CH ( 4 ),
       .RX_IN_BITS ( 1 ),
       .RX_OUT_BITS ( 1 ),
       .TX_IN_BITS ( 1 ),
       .TX_OUT_BITS ( 1 ),
       .FRAME_INFO_IN_BITS ( 0 ),
       .FRAME_SIZE_MASK ( 32'hffffffc0 )
   ) tb ();
endmodule

module test_toe_ctrl_rx_random_1ch_aligned_concat;
   tb_toe_ctrl_rx #(
       .PACKET_CONCAT ( 1 ),
       .MAX_FRAME_SIZE_BITS ( 12 ),
       .ENABLE_FIXED_CH ( 1 ),
       .FIXED_CH ( 4 ),
       .RX_IN_BITS ( 1 ),
       .RX_OUT_BITS ( 1 ),
       .TX_IN_BITS ( 1 ),
       .TX_OUT_BITS ( 1 ),
       .ENABLE_OVER_SIZE ( 1 ),
       .FRAME_INFO_IN_BITS ( 1 ),
       .FRAME_INFO_OUT_BITS ( 1 ),
       .FRAME_SIZE_MASK ( 32'hffffffc0 ),
       .MAX_TRANSFERS ( 100 )
   ) tb ();
endmodule

module test_toe_ctrl_rx_fast_1ch_aligned_concat_rare;
   tb_toe_ctrl_rx #(
       .PACKET_CONCAT ( 1 ),
       .MAX_FRAME_SIZE_BITS ( 13 ),
       .ENABLE_FIXED_CH ( 1 ),
       .FIXED_FRAME_SIZE ( 32'h01fc0 ),
       .FIXED_CH ( 12 ),
       .RX_IN_BITS ( 0 ),
       .RX_OUT_BITS ( 0 ),
       .TX_IN_BITS ( 1 ),
       .TX_OUT_BITS ( 1 ),
       .ENABLE_OVER_SIZE ( 1 ),
       .FRAME_INFO_IN_BITS ( 1 ),
       .FRAME_INFO_OUT_BITS ( 1 ),
       .FRAME_SIZE_MASK ( 32'hffffffc0 ),
       .MAX_TRANSFERS ( 100 )
   ) tb ();
endmodule
