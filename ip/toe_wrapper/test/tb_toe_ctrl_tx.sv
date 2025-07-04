/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module tb_toe_ctrl_tx #(
    parameter DW_LOG = 9,
    parameter BURST_BITS = 6,
    parameter CH_NUM_LOG = 4,
    parameter SESSION_NUM_LOG = 6,
    parameter FRAME_MAX = 8,
    parameter MAX_INFLIGHT = 2,
    parameter TX_FIFO_DL = 9,
    parameter TX_AUX_FIFO_DL = 4,
    parameter ACTIVATE_MAGIC = 32'h56544341, // ACTV
    parameter CREDIT_MAGIC = 32'h54445243, // CRDT
    parameter RX_IN_BITS = 1,
    parameter RX_PACKET_BITS = 5,
    parameter TX_CMD_BITS = 1,
    parameter TX_RSP_BITS = 1,
    parameter TX_IN_BITS = 1,
    parameter TX_OUT_BITS = 1,
    parameter CREDIT_BITS = 1,
    parameter FRAME_INFO_OUT_BITS = 1,
    parameter FRAME_INFO_IN_BITS = 1,
    parameter MAX_FRAME_SIZE_BITS = 14,
    parameter MAX_CREDIT_BITS = 3,
    parameter FIXED_CH = 4,
    parameter ENABLE_FIXED_CH = 0,
    parameter ENABLE_DIRTY_RX_TX = 1,
    parameter RX_TX_CREDIT_MAX = 0,
    parameter ACTIVATE_FAIL = 0,
    parameter MAX_TRANSFERS = 100
    ) ();

   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam DW = 1 << DW_LOG;
   localparam KW_LOG = DW_LOG - 3;
   localparam KW = 1 << KW_LOG;
   localparam BURST_SIZE = 1 << (BURST_BITS + KW_LOG);
   localparam FRAME_SIZE_MAX = 1 << MAX_FRAME_SIZE_BITS;

   localparam RX_IN_BITS_MOD = RX_IN_BITS > 0 ? RX_IN_BITS : 1;
   localparam RX_PACKET_BITS_MOD = RX_PACKET_BITS > 0 ? RX_PACKET_BITS : 1;
   localparam TX_CMD_BITS_MOD = TX_CMD_BITS > 0 ? TX_CMD_BITS : 1;
   localparam TX_RSP_BITS_MOD = TX_RSP_BITS > 0 ? TX_RSP_BITS : 1;
   localparam TX_IN_BITS_MOD = TX_IN_BITS > 0 ? TX_IN_BITS : 1;
   localparam TX_OUT_BITS_MOD = TX_OUT_BITS > 0 ? TX_OUT_BITS : 1;
   localparam CREDIT_BITS_MOD = CREDIT_BITS > 0 ? CREDIT_BITS : 1;
   localparam FRAME_INFO_IN_BITS_MOD = FRAME_INFO_IN_BITS > 0 ? FRAME_INFO_IN_BITS : 1;
   localparam FRAME_INFO_OUT_BITS_MOD = FRAME_INFO_OUT_BITS > 0 ? FRAME_INFO_OUT_BITS : 1;

   localparam ACTIVATE_PACKET_SIZE = 10;

   reg [DW-1:0]                   tx_in_tdata;
   reg [KW-1:0]                   tx_in_tkeep;
   reg [CH_NUM_LOG-1:0]           tx_in_tuser;
   reg                            tx_in_tlast;
   reg                            tx_in_sop;
   reg                            tx_in_eop;
   reg [BURST_BITS-1:0]           tx_in_burst; // 0-origin -> 1-origin
   reg [KW_LOG-1:0]               tx_in_last_cnt; // 0-origin -> 1->origin
   reg                            tx_in_tvalid;
   wire                           tx_in_tready;

   wire [DW-1:0]                  tx_toe_tdata;
   wire [KW-1:0]                  tx_toe_tkeep;
   wire [SESSION_NUM_LOG-1:0]     tx_toe_tuser;
   wire                           tx_toe_tlast;
   wire                           tx_toe_tvalid;
   reg                            tx_toe_tready;

   wire [31:0]                    tx_toe_cmd_tdata;
   wire                           tx_toe_cmd_tvalid;
   reg                            tx_toe_cmd_tready;

   reg [87:0]                     tx_toe_rsp_tdata;
   reg                            tx_toe_rsp_tvalid;
   wire                           tx_toe_rsp_tready;

   // received packet for tx session
   reg [DW-1:0]                   rx_tx_tdata;
   reg [KW-1:0]                   rx_tx_tkeep;
   reg [CH_NUM_LOG-1:0]           rx_tx_tuser;
   reg                            rx_tx_tlast; // eop
   reg                            rx_tx_tvalid;
   wire                           rx_tx_tready;

   // transfer packet of rx session
   reg [DW-1:0]                   tx_tdata;
   reg [KW-1:0]                   tx_tkeep;
   reg [SESSION_NUM_LOG-1:0]      tx_tuser;
   reg [BURST_BITS-1:0]           tx_burst;
   reg [KW_LOG-1:0]               tx_last_cnts;
   reg                            tx_tlast;
   reg                            tx_tvalid;
   wire                           tx_tready;

   reg [CH_NUM-1:0]               tx_ch_valids;
   reg [CH_NUM-1:0]               tx_ch_actives;
   reg [CH_NUM-1:0]               tx_ch_readys;
   reg [SESSION_NUM_LOG*CH_NUM-1:0] tx_ch_session_ids;
   reg [(32<<CH_NUM_LOG)-1:0]     tx_ch_frame_sizes;
   reg                            invalidate_activate;

   wire [SESSION_NUM_LOG-1:0]     connected_session_id;
   wire [31:0]                    connected_ip;
   wire [15:0]                    connected_port;
   wire                           connected_valid;
   reg                            connected_out_found;
   reg                            connected_out_valid;

   wire [SESSION_NUM_LOG-1:0]     close_session_id;
   wire                           close_valid;

   wire [15:0]                    cp_config_credit_max;
   wire [31:0]                    cp_config_frame_size;
   wire [SESSION_NUM_LOG-1:0]     cp_config_session_id;
   wire                           cp_config_valid;

   wire [SESSION_NUM_LOG-1:0]     tx_credit_inc_session_id;
   wire                           tx_credit_inc;
   wire [SESSION_NUM_LOG-1:0]     tx_credit_dec_session_id;
   wire                           tx_credit_dec;

   wire [31:0]                    frame_info_out_tdata; // frame size
   wire [CH_NUM_LOG-1:0]          frame_info_out_tuser;
   wire                           frame_info_out_tvalid;
   reg                            frame_info_out_tready;

   reg [31:0]                     frame_info_tdata; // frame size
   reg [CH_NUM_LOG-1:0]           frame_info_tuser;
   reg                            frame_info_tvalid;
   wire                           frame_info_tready;

   wire                           clk, resetn;
   wire [31:0]                    rd;

   clk_reset clk_reset (
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
   );

   toe_ctrl_tx #(
       .DW_LOG ( DW_LOG ),
       .BURST_BITS ( BURST_BITS ),
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .SESSION_NUM_LOG ( SESSION_NUM_LOG ),
       .FRAME_MAX ( FRAME_MAX ),
       .MAX_INFLIGHT ( MAX_INFLIGHT ),
       .TX_FIFO_DL ( TX_FIFO_DL ),
       .TX_AUX_FIFO_DL ( TX_AUX_FIFO_DL )
   ) dut (
       .*
   );

   initial begin
      tx_in_tvalid = 1'b0;
      tx_toe_tready = 1'b0;
      tx_toe_cmd_tready = 1'b0;
      tx_toe_rsp_tvalid = 1'b0;
      rx_tx_tvalid = 1'b0;
      tx_tvalid = 1'b0;
      tx_ch_valids = 'd0;
      tx_ch_actives = 'd0;
      tx_ch_readys = 'd0;
      tx_ch_session_ids = 'd0;
      tx_ch_frame_sizes = 'd0;
      invalidate_activate = 1'b0;
      frame_info_out_tready = 1'b0;
      frame_info_tvalid = 1'b0;
      connected_out_valid = 1'b0;
      connected_out_found = 1'b0;
   end

   reg [SESSION_NUM_LOG*CH_NUM-1:0] rx_ch_session_ids;
   reg [32*CH_NUM-1:0]              rx_ch_frame_sizes;
   reg [16*CH_NUM-1:0]              rx_ch_credit_max;
   initial begin
      rx_ch_session_ids = 'd0;
      rx_ch_frame_sizes = 'd0;
      rx_ch_credit_max = 'd0;
   end

   always @(posedge clk) begin
      if (resetn) begin
         frame_info_out_tready <= FRAME_INFO_OUT_BITS > 0 ? &rd[11+:FRAME_INFO_OUT_BITS_MOD] : 1'b1;
         tx_toe_tready <= TX_OUT_BITS > 0 ? &rd[17+:TX_OUT_BITS_MOD] : 1'b1;
         tx_toe_cmd_tready <= TX_CMD_BITS > 0 ? &rd[21+:TX_CMD_BITS_MOD] : 1'b1;
      end
   end

   // cp_config check
   logic [CH_NUM-1:0] cp_config_ch;
   always @(cp_config_session_id) begin
      cp_config_ch = 'd0;
      for (int i=0; i<CH_NUM; i++) begin
         if (tx_ch_session_ids[i*SESSION_NUM_LOG+:SESSION_NUM_LOG] == cp_config_session_id) begin
            cp_config_ch = i;
            break;
         end
      end
   end
   always @(posedge clk) begin
      if (resetn && cp_config_valid) begin
         if (cp_config_credit_max !== rx_ch_credit_max[cp_config_ch*16+:16] ||
             cp_config_frame_size !== rx_ch_frame_sizes[cp_config_ch*32+:32]) begin
            $error("%d: [%2h] cp config: %h %h, %h %h, %h", $time, cp_config_ch,
                   cp_config_credit_max, rx_ch_credit_max[cp_config_ch*16+:16],
                   cp_config_frame_size, rx_ch_frame_sizes[cp_config_ch*32+:32], cp_config_session_id);
         end else begin
            tx_ch_actives[cp_config_ch] <= 1'b1;
            tx_ch_readys[cp_config_ch] <= tx_ch_valids[cp_config_ch];
            tx_ch_frame_sizes[cp_config_ch*32+:32] <= cp_config_frame_size;
         end
      end
   end

   // frame size
   reg [31:0] frame_size_saved[0:CH_NUM-1][0:255];
   reg [7:0]  frame_size_spos[0:CH_NUM-1];
   reg [7:0]  frame_size_cpos[0:CH_NUM-1];
   reg [7:0]  frame_size_wpos[0:CH_NUM-1];
   reg [7:0]  frame_size_rpos[0:CH_NUM-1];
   reg [7:0]  frame_size_epos[0:CH_NUM-1];
   initial begin
      for (int i=0; i<CH_NUM; i++) begin
         frame_size_spos[i] = 'd0;
         frame_size_cpos[i] = 'd0;
         frame_size_wpos[i] = 'd0;
         frame_size_rpos[i] = 'd0;
         frame_size_epos[i] = 'd0;
      end
   end
   always @(posedge clk) begin
      if (resetn && frame_info_out_tvalid && frame_info_out_tready) begin
         if (frame_info_out_tdata !== frame_size_saved[frame_info_out_tuser][frame_size_cpos[frame_info_out_tuser]]) begin
            $error("%d: [%2h] frame info out: %h %h", $time, frame_info_out_tuser,
                   frame_info_out_tdata, frame_size_saved[frame_info_out_tuser][frame_size_cpos[frame_info_out_tuser]]);
         end else begin
            $display("%d: [%2h] frame info out: %h %h", $time, frame_info_out_tuser,
                     frame_info_out_tdata, frame_size_saved[frame_info_out_tuser][frame_size_cpos[frame_info_out_tuser]]);
         end
         frame_size_cpos[frame_info_out_tuser] <= frame_size_cpos[frame_info_out_tuser] + 1'b1;
      end
   end

   reg [DW-1:0] rx_packet_data_saved[0:255];
   reg [KW-1:0] rx_packet_keep_saved[0:255];
   reg [SESSION_NUM_LOG-1:0] rx_packet_user_saved[0:255];
   reg                       rx_packet_last_saved[0:255];
   reg [7:0]                 rx_packet_wpos, rx_packet_rpos;
   reg [DW-1:0]         tx_data_saved[0:255];
   reg [KW-1:0]         tx_keep_saved[0:255];
   reg [SESSION_NUM_LOG-1:0] tx_user_saved[0:255];
   reg                  tx_last_saved[0:255];
   reg [7:0]            tx_wpos, tx_rpos;
   logic activate_done;
   initial begin
      tx_wpos = 'd0;
      tx_rpos = 'd0;
      rx_packet_rpos = 'd0;
      activate_done = 1'b0;
   end
   logic tx_toe_is_rx;
   always @(posedge clk) begin
      if (resetn && tx_toe_tvalid && tx_toe_tready) begin
         for (int i=0; i<CH_NUM; i++) begin
            if (tx_toe_tuser == tx_ch_session_ids[i*SESSION_NUM_LOG+:SESSION_NUM_LOG]) begin
               tx_toe_is_rx = 0;
               break;
            end else if (tx_toe_tuser == rx_ch_session_ids[i*SESSION_NUM_LOG+:SESSION_NUM_LOG]) begin
               tx_toe_is_rx = 1;
               break;
            end
         end
         if (~tx_toe_is_rx) begin
            if (tx_toe_tdata !== tx_data_saved[tx_rpos] ||
                tx_toe_tkeep !== tx_keep_saved[tx_rpos] ||
                tx_toe_tuser !== tx_user_saved[tx_rpos] ||
                tx_toe_tlast !== tx_last_saved[tx_rpos]) begin
               $error("%d: [%2h] tx data: %h %h, %h %h, %h %h, %h %h", $time, tx_toe_tuser,
                      tx_toe_tdata, tx_data_saved[tx_rpos],
                      tx_toe_tkeep, tx_keep_saved[tx_rpos],
                      tx_toe_tuser, tx_user_saved[tx_rpos],
                      tx_toe_tlast, tx_last_saved[tx_rpos]);
            end
            tx_rpos <= tx_rpos + 1'b1;
         end else if (activate_done) begin
            if (tx_toe_tdata !== rx_packet_data_saved[rx_packet_rpos] ||
                tx_toe_tkeep !== rx_packet_keep_saved[rx_packet_rpos] ||
                tx_toe_tuser !== rx_packet_user_saved[rx_packet_rpos] ||
                tx_toe_tlast !== rx_packet_last_saved[rx_packet_rpos]) begin
               $error("%d: [%2h] rx packet data: %h %h, %h %h, %h %h, %h %h", $time, tx_toe_tuser,
                      tx_toe_tdata, rx_packet_data_saved[rx_packet_rpos],
                      tx_toe_tkeep, rx_packet_keep_saved[rx_packet_rpos],
                      tx_toe_tuser, rx_packet_user_saved[rx_packet_rpos],
                      tx_toe_tlast, rx_packet_last_saved[rx_packet_rpos]);
            end
            rx_packet_rpos <= rx_packet_rpos + 1'b1;
         end
      end
   end

   // tx cmd rsp
   logic [15:0] toe_cmd_size;
   logic [15:0] toe_cmd_session_id;
   logic        toe_cmd_valid;
   logic        toe_rsp_valid;
   logic        toe_rsp_vacant;
   logic        tx_toe_is_closed;
   logic [3:0]  toe_rsp_mode;
   logic [SESSION_NUM_LOG-1:0] toe_conn_session_id;
   logic                       toe_conn_session_id_dup;
   logic [SESSION_NUM_LOG-1:0] conn_session_id_saved[0:255];
   logic [31:0]                conn_ip_saved[0:255];
   logic [15:0]                conn_port_saved[0:255];
   logic [7:0]                 conn_wpos, conn_rpos;
   logic                       conn_stat_saved;
   initial begin
      toe_cmd_valid = 1'b0;
      conn_wpos = 'd0;
      conn_rpos = 'd0;
      conn_stat_saved = 1'b0;
   end
   always @(posedge clk) begin
      if (resetn) begin
         if (tx_toe_cmd_tvalid && tx_toe_cmd_tready) begin
            if (toe_cmd_valid) begin
               $error("%d: tx cmd duplicate: %h %h", $time, tx_toe_cmd_tdata, {toe_cmd_size, toe_cmd_session_id});
            end
            {toe_cmd_size, toe_cmd_session_id} <= tx_toe_cmd_tdata;
            toe_cmd_valid <= 1'b1;
            tx_toe_is_closed = 1'b1;
            for (int i=0; i<CH_NUM; i++) begin
               if (tx_toe_cmd_tdata[15:0] == rx_ch_session_ids[i*SESSION_NUM_LOG+:SESSION_NUM_LOG] ||
                   tx_toe_cmd_tdata[15:0] == tx_ch_session_ids[i*SESSION_NUM_LOG+:SESSION_NUM_LOG]) begin
                  tx_toe_is_closed = 1'b0;
                  break;
               end
            end
            if (tx_toe_is_closed) begin
               $error("%d: tx cmd for unknown session: %h", $time, tx_toe_cmd_tdata);
            end
         end
         toe_rsp_mode = rd[10+:4];
         toe_rsp_valid = (TX_RSP_BITS > 0 ? &rd[9+:TX_RSP_BITS_MOD] : 1'b1) &&
                         (~tx_toe_rsp_tvalid || tx_toe_rsp_tready) && (toe_cmd_valid || &toe_rsp_mode);
         toe_rsp_vacant = rd[30];
         if (toe_rsp_valid && ~&toe_rsp_mode) begin
            tx_toe_rsp_tdata <= {5'd0, tx_toe_is_closed | (ACTIVATE_FAIL && toe_cmd_size == ACTIVATE_PACKET_SIZE && &rd[10+:2] ? 1'b1 : 1'b0),
                                 2'd0, rd[31:0], rd[15:0], toe_rsp_vacant ? toe_cmd_size : 16'd0, toe_cmd_session_id};
            tx_toe_rsp_tvalid <= toe_rsp_valid;
            toe_cmd_valid <= 1'b0;
         end else if (toe_rsp_valid) begin
            toe_conn_session_id = rd;
            toe_conn_session_id_dup = 1;
            while (toe_conn_session_id_dup) begin
               toe_conn_session_id_dup = 0;
               for (int i=0; i<CH_NUM; i++) begin
                  if (toe_conn_session_id == tx_ch_session_ids[i*SESSION_NUM_LOG+:SESSION_NUM_LOG] ||
                      toe_conn_session_id == rx_ch_session_ids[i*SESSION_NUM_LOG+:SESSION_NUM_LOG]) begin
                     toe_conn_session_id_dup = 1;
                     break;
                  end
               end
               if (toe_conn_session_id_dup) toe_conn_session_id++;
            end
            tx_toe_rsp_tdata <= {7'd0, 1'b1, rd[31:0], rd[15:0], 16'd0, 16'd0 | toe_conn_session_id};
            tx_toe_rsp_tvalid <= toe_rsp_valid;
            conn_session_id_saved[conn_wpos] <= toe_conn_session_id;
            conn_ip_saved[conn_wpos] <= rd;
            conn_port_saved[conn_wpos] <= rd[15:0];
            conn_wpos <= conn_wpos + 1'b1;
         end else begin
            tx_toe_rsp_tvalid <= tx_toe_rsp_tvalid & ~tx_toe_rsp_tready;
         end
      end
   end
   always @(posedge clk) begin
      if (resetn && connected_valid) begin
         if (connected_session_id !== conn_session_id_saved[conn_rpos] ||
             connected_ip !== conn_ip_saved[conn_rpos] ||
             connected_port !== conn_port_saved[conn_rpos]) begin
            $error("%d: connected %h %h, %h %h, %h %h", $time,
                   connected_session_id, conn_session_id_saved[conn_rpos],
                   connected_ip, conn_ip_saved[conn_rpos],
                   connected_port, conn_port_saved[conn_rpos]);
         end
         conn_rpos <= conn_rpos + 1'b1;
         conn_stat_saved = 1'b1;
      end
      if (resetn && conn_stat_saved && rd[10]) begin
         connected_out_valid <= 1'b1;
         connected_out_found <= rd[11];
         conn_stat_saved <= 1'b0;
      end else begin
         connected_out_valid <= 1'b0;
      end
   end

   // rx packet
   logic rx_packet_valid;
   logic rx_packet_is_activate;
   logic [CH_NUM_LOG-1:0] rx_packet_ch;
   logic [DW-1:0]         rx_packet_data;
   logic [KW-1:0]         rx_packet_keep;
   logic [CH_NUM-1:0]     rx_ch_valids;
   logic                  check_rx_packet_finish;
   initial begin
      rx_ch_valids = 'd0;
      rx_packet_wpos = 'd0;
      rx_packet_data = 'd0;
      rx_packet_keep = 'd0;
      check_rx_packet_finish = 1'b0;
   end
   task static check_rx_packet();
      while (~check_rx_packet_finish) @(posedge clk) begin
         rx_packet_ch = rd[15+:CH_NUM_LOG];
         rx_packet_valid = (RX_PACKET_BITS > 0 ? &rd[10+:RX_PACKET_BITS_MOD] : 1'b1) && rx_ch_valids[rx_packet_ch];
         rx_packet_is_activate = &rd[20+:4];
         if (rx_packet_valid && (~tx_tvalid || tx_tready)) begin
            if (rx_packet_is_activate) begin
               rx_packet_data[0+:80] = {rd[15:0], rd[31:0] ^ 32'h1010101, ACTIVATE_MAGIC};
               rx_packet_keep = ({{KW{1'b0}},1'b1} << 10) - 1'b1;
            end else begin
               rx_packet_data[0+:80] = {16'd0, rd[31:0] ^ 32'h1010101, CREDIT_MAGIC};
               rx_packet_keep = ({{KW{1'b0}},1'b1} << 8) - 1'b1;
            end
            rx_packet_data_saved[rx_packet_wpos] <= rx_packet_data;
            rx_packet_keep_saved[rx_packet_wpos] <= rx_packet_keep;
            rx_packet_user_saved[rx_packet_wpos] <= rx_ch_session_ids >> (rx_packet_ch * SESSION_NUM_LOG);
            rx_packet_last_saved[rx_packet_wpos] <= 1'b1;
            rx_packet_wpos <= rx_packet_wpos + 1'b1;
            tx_tdata <= rx_packet_data;
            tx_tkeep <= rx_packet_keep;
            tx_tuser <= rx_ch_session_ids >> (rx_packet_ch * SESSION_NUM_LOG);
            tx_burst <= 'd0;
            tx_last_cnts <= rx_packet_is_activate ? 'd9 : 'd7;
            tx_tlast <= 1'b1;
            tx_tvalid <= 1'b1;
         end else begin
            tx_tvalid <= tx_tvalid & ~tx_tready;
         end
      end
   endtask

   logic [CH_NUM_LOG:0] activate_num;
   logic                activate_num_fixed;
   initial begin
      activate_num = 'd0;
      activate_num_fixed = 1'b0;
   end
   task static setup_registers;
      logic dup;
      logic [CH_NUM_LOG:0] cur_ch =0;
      for (int ch=0; ch<CH_NUM; ch++) begin
         while (1) @(posedge clk) begin
            dup = 0;
            for (int j=0; j<ch; j++) if (rd[4+:SESSION_NUM_LOG] == rx_ch_session_ids[j*SESSION_NUM_LOG+:SESSION_NUM_LOG] ||
                                         rd[4+:SESSION_NUM_LOG] == tx_ch_session_ids[j*SESSION_NUM_LOG+:SESSION_NUM_LOG]) dup=1;
            if (~dup) begin
               tx_ch_session_ids[ch*SESSION_NUM_LOG+:SESSION_NUM_LOG] <= rd[4+:SESSION_NUM_LOG];
               break;
            end
         end
         @(posedge clk) tx_ch_valids[ch] <= ENABLE_FIXED_CH != 0 ? ch == FIXED_CH : rd[14];
         while (~|rx_ch_frame_sizes[ch*32+:32]) @(posedge clk) rx_ch_frame_sizes[ch*32+:32] <= rd & ((32'd1 << MAX_FRAME_SIZE_BITS)-1);
         while (~|rx_ch_credit_max[ch*16+:16]) @(posedge clk) rx_ch_credit_max[ch*16+:16] <= rd & ((32'd1 << MAX_CREDIT_BITS)-1);
         while (1) @(posedge clk) begin
            dup = 0;
            for (int j=0; j<ch; j++) if (rd[10+:SESSION_NUM_LOG] == rx_ch_session_ids[j*SESSION_NUM_LOG+:SESSION_NUM_LOG] ||
                                         rd[10+:SESSION_NUM_LOG] == tx_ch_session_ids[j*SESSION_NUM_LOG+:SESSION_NUM_LOG]) dup=1;
            if (rd[10+:SESSION_NUM_LOG] == tx_ch_session_ids[ch*SESSION_NUM_LOG+:SESSION_NUM_LOG]) continue;
            if (~dup) begin
               rx_ch_session_ids[ch*SESSION_NUM_LOG+:SESSION_NUM_LOG] <= rd[10+:SESSION_NUM_LOG];
               break;
            end
         end
         @(posedge clk) rx_ch_valids[ch] <= 1'b1;
         $display("%d: [%2h] rx session:%h frame_size:%h", $time, ch,
                  rx_ch_session_ids[ch*SESSION_NUM_LOG+:SESSION_NUM_LOG], rx_ch_frame_sizes[ch*32+:32]);
         $display("%d: [%2h] tx session:%h valid:%d", $time, ch, tx_ch_session_ids[ch*SESSION_NUM_LOG+:SESSION_NUM_LOG],
                  tx_ch_valids[ch]);
      end
      @(posedge clk);
      cur_ch = 0;
      while (cur_ch < CH_NUM) @(posedge clk) begin
         while (cur_ch < CH_NUM && ~tx_ch_valids[cur_ch]) cur_ch++;
         if (~rx_tx_tvalid || rx_tx_tready) begin
            rx_tx_tdata <= {DW{1'b0}} | {rx_ch_credit_max[cur_ch*16+:16], rx_ch_frame_sizes[cur_ch*32+:32], ACTIVATE_MAGIC};
            rx_tx_tkeep <= ({{KW{1'b0}}, 1'b1} << 10)-1;
            rx_tx_tuser <= cur_ch;
            rx_tx_tlast <= 1'b1;
            rx_tx_tvalid <= cur_ch < CH_NUM && tx_ch_valids[cur_ch];
            $display("%d: [%2h] activate", $time, cur_ch);
            cur_ch++;
         end else begin
            rx_tx_tvalid <= rx_tx_tvalid & ~rx_tx_tready;
         end
      end
      while (rx_tx_tvalid) @(posedge clk) begin
         rx_tx_tvalid <= rx_tx_tvalid & ~rx_tx_tready;
      end
      @(posedge clk);
      cur_ch = 0;
      while (cur_ch < CH_NUM) @(posedge clk) begin
         while (cur_ch < CH_NUM && ~rx_ch_valids[cur_ch]) cur_ch++;
         if (~tx_tvalid || tx_tready) begin
            tx_tdata <= {DW{1'b0}} | {rx_ch_credit_max[cur_ch*16+:16], rx_ch_frame_sizes[cur_ch*32+:32], ACTIVATE_MAGIC};
            tx_tkeep <= ({{KW{1'b0}}, 1'b1} << 10)-1;
            tx_tuser <= rx_ch_session_ids[cur_ch*SESSION_NUM_LOG+:SESSION_NUM_LOG];
            tx_burst <= 'd0;
            tx_last_cnts <= 'd9;
            tx_tlast <= 1'b1;
            tx_tvalid <= cur_ch < CH_NUM && rx_ch_valids[cur_ch];
            activate_num++;
            $display("%d: [%2h] activate: %d, %d", $time, cur_ch, rx_ch_valids[cur_ch], activate_num);
            cur_ch++;
         end else begin
            tx_tvalid <= tx_tvalid & ~tx_tready;
         end
      end
      while (tx_tvalid) @(posedge clk) begin
         tx_tvalid <= tx_tvalid & ~tx_tready;
      end
      activate_num_fixed = 1'b1;
   endtask

   task static activate_check;
      int  activate_count = 0;
      while (~activate_num_fixed || activate_count < activate_num) @(posedge clk) begin
         if (tx_toe_tvalid && tx_toe_tready && tx_toe_tlast && tx_toe_tkeep == ({{KW{1'b0}}, 1'b1} << 10) -1) begin
            activate_count++;
            $display("%d: [%2h] activate: packet out: %d", $time, tx_toe_tuser,  activate_count);
         end
      end
      @(posedge clk) activate_done <= 1'b1;
   endtask

   task static generate_credit;
      int frame_count = 0;
      logic [31:0] size;
      logic [CH_NUM_LOG-1:0] ch;
      logic [DW+63:0]        data;
      logic [KW-1:0]         keep;
      logic                  last;
      logic [3:0]            num = 0;
      logic [15:0]           len = 0;
      logic [15:0]           remain;
      logic [KW_LOG:0]       max_len;
      logic                  valid = 0;
      logic [CH_NUM-1:0]     ch_activates = 'd0;
      logic [DW-1:0]         data_saved[0:255];
      logic [KW-1:0]         keep_saved[0:255];
      logic [CH_NUM_LOG-1:0] ch_saved[0:255];
      logic                  last_saved[0:255];
      logic [7:0]            wpos = 0;
      logic [7:0]            rpos = 0;
      while (frame_count < MAX_TRANSFERS || rx_tx_tvalid || |num || |len || wpos != rpos) @(posedge clk) begin
         valid = 0;
         if (frame_count < MAX_TRANSFERS) begin
            if (num == 0 && len == 0) begin
               num = ENABLE_DIRTY_RX_TX > 0 ? rd : 1;
               if (RX_TX_CREDIT_MAX > 0 && num > RX_TX_CREDIT_MAX) num = RX_TX_CREDIT_MAX;
               ch = rd[7+:CH_NUM_LOG];
               if (frame_count + num > MAX_TRANSFERS) num = MAX_TRANSFERS - frame_count;
               len = 0;
               data = 0;
               remain = 0;
               if (~tx_ch_valids[ch]) num = 0;
            end
         end
         max_len = ENABLE_DIRTY_RX_TX > 0 ? rd[12+:KW_LOG]+1 : 8;
         if (num > 0) begin
            size = (('d1 << MAX_FRAME_SIZE_BITS)-1) & rd;
            if (|size) begin
               data = data | {size, CREDIT_MAGIC} << {len, 3'd0};
               frame_size_saved[ch][frame_size_spos[ch]] <= size;
               frame_size_spos[ch] <= frame_size_spos[ch] + 1'b1;
               $display("%d: [%2h] credit %h", $time, ch, {size, CREDIT_MAGIC});
               frame_count++;
               len += 8;
               num--;
            end
         end
         if (len > max_len) begin
            remain = len - max_len;
            len = max_len;
         end else begin
            remain = 0;
         end
         if (len > 0 && (len >= max_len || num == 0)) begin
            data_saved[wpos] = data;
            keep = ({{KW{1'b0}}, 1'b1} << len)-1;
            keep_saved[wpos] = keep;
            ch_saved[wpos] = ch;
            last_saved[wpos] = len >= max_len || (num == 0 && remain == 0);
            $display("%d: [%2h] credit packet %h %h %h, len=%d, remain=%d", $time, ch,
                     data, keep, len >= max_len || (num == 0 && remain == 0),
                     len, remain);
            wpos++;
            data >>= {len, 3'd0};
            len = remain;
         end
         valid = (CREDIT_BITS > 0 ? &rd[13+:CREDIT_BITS_MOD] : 1'b1) && (~rx_tx_tvalid || rx_tx_tready);
         valid &= wpos != rpos;
         if (valid) begin
            rx_tx_tdata <= data_saved[rpos];
            rx_tx_tkeep <= keep_saved[rpos];
            rx_tx_tuser <= ch_saved[rpos];
            rx_tx_tlast <= last_saved[rpos];
            rx_tx_tvalid <= valid;
            rpos <= rpos + 1'b1;
         end else begin
            rx_tx_tvalid <= rx_tx_tvalid & ~rx_tx_tready;
         end
      end
   endtask

   task static generate_frames;
      int frame_count = 0;
      logic [31:0] size, cur_size;
      logic [CH_NUM_LOG-1:0] ch;
      logic                  valid = 0;
      while (frame_count < MAX_TRANSFERS || valid || frame_info_tvalid ) @(posedge clk) begin
         ch = rd[4+:CH_NUM_LOG];
         valid = frame_size_cpos[ch] != frame_size_wpos[ch];
         valid &= FRAME_INFO_IN_BITS > 0 ? &rd[10+:FRAME_INFO_IN_BITS_MOD] : 1'b1;
         //cur_size = rd & ((32'd1 << FRAME_SIZE_MAX)-1);
         size = frame_size_saved[ch][frame_size_wpos[ch]];
         valid &= |size;
         if (valid && (~frame_info_tvalid | frame_info_tready)) begin
            frame_size_wpos[ch] <= frame_size_wpos[ch] + 1'b1;
            frame_count++;
            frame_info_tdata <= size;
            frame_info_tuser <= ch;
            frame_info_tvalid <= valid;
            $display("%d: [%2h] generate frame: %d, %h (%d)", $time, ch, frame_size_wpos[ch], size, frame_count);
         end else begin
            frame_info_tvalid <= frame_info_tvalid & ~frame_info_tready;
         end
      end
      $display("generate frame finish");
   endtask

   task static generate_tx_inputs;
      logic [DW-1:0] data;
      logic [KW-1:0] keep;
      logic          last;
      logic          valid;
      logic          sop;
      logic          eof;
      logic [BURST_BITS-1:0] burst;
      logic [KW_LOG-1:0]     last_cnts;
      logic [CH_NUM_LOG-1:0] ch;
      logic [31:0]   frame_sizes[0:CH_NUM-1];
      logic [31:0]   cur_size = 0;
      logic [7:0]    tx_wpos_next;
      int            frame_count = 0;
      for (int i=0; i<CH_NUM; i++) frame_sizes[i] = 'd0;
      while (frame_count < MAX_TRANSFERS || valid || tx_in_tvalid) @(posedge clk) begin
         if (~|cur_size) begin
            ch = rd[8+:CH_NUM_LOG];
            if (~|frame_sizes[ch] && frame_size_epos[ch] != frame_size_wpos[ch]) begin
               frame_sizes[ch] = frame_size_saved[ch][frame_size_epos[ch]];
               frame_size_epos[ch] = frame_size_epos[ch] + 1'b1;
               $display("%d: [%2h] tx input size: %h", $time, ch, frame_sizes[ch]);
            end
            cur_size = frame_sizes[ch] < BURST_SIZE ? frame_sizes[ch] : BURST_SIZE;
            frame_sizes[ch] -= cur_size;
            sop = 1;
            if (~|frame_sizes[ch] && |cur_size) begin
               eof = 1'b1;
               $display("%d: [%2h] tx input frames: %d, %d", $time, ch, frame_size_epos[ch], frame_count);
            end else begin
               eof = 1'b0;
            end
            burst = (cur_size - 1) >> KW_LOG;
            last_cnts = cur_size - 1;
            if (|cur_size) begin
               $display("%d: [%2h] tx input: size: %h(%h %h), remain: %h, frames:%d", $time, ch,
                        cur_size, burst, last_cnts, frame_sizes[ch], frame_count);
            end
         end
         valid = |cur_size && (RX_IN_BITS > 0 ? &rd[10+:RX_IN_BITS_MOD] : 1'b1) && (~tx_in_tvalid || tx_in_tready);
         valid &= ((tx_wpos + 1'b1) & 255) != tx_rpos;
         if (valid) begin
            for (int i=0; i<KW; i++) begin
               keep[i] = i < cur_size;
               data[i*8+:8] = ((rd >> (i&3)*8) ^ (32'h1002 << (i/4))) & {8{keep[i]}};
            end
            last = cur_size <= KW;
            tx_data_saved[tx_wpos] <= data;
            tx_keep_saved[tx_wpos] <= keep;
            tx_user_saved[tx_wpos] <= tx_ch_session_ids >> (ch * SESSION_NUM_LOG);
            tx_last_saved[tx_wpos] <= last;
            tx_wpos <= tx_wpos + 1'b1;
            tx_in_tdata <= data;
            tx_in_tkeep <= keep;
            tx_in_tuser <= ch;
            tx_in_tlast <= eof & last;
            tx_in_sop <= sop;
            tx_in_eop <= last;
            tx_in_burst <= burst;
            tx_in_last_cnt <= last_cnts;
            tx_in_tvalid <= valid;
            sop <= 0;
            {burst, last_cnts} <= rd;
            cur_size = last ? 'd0 : cur_size - KW;
            if (last & eof) begin
               frame_count++;
            end
         end else begin
            tx_in_tvalid <= tx_in_tvalid & ~tx_in_tready;
         end
      end
      $display("generate input finish");
      check_rx_packet_finish = 1'b1;
   endtask

   initial begin
      @(posedge clk);
      while (~resetn) @(posedge clk);

      fork
         setup_registers;
         activate_check;
      join
      $display("end setup");
      fork
         generate_credit;
         generate_frames;
         generate_tx_inputs;
         check_rx_packet;
      join

      $finish;
   end

endmodule

module test_toe_ctrl_tx_fast;
   tb_toe_ctrl_tx #(
       .RX_IN_BITS ( 0 ),
       .TX_CMD_BITS ( 0 ),
       .TX_RSP_BITS ( 0 ),
       .TX_IN_BITS ( 0 ),
       .TX_OUT_BITS ( 0 ),
       .FRAME_INFO_OUT_BITS ( 0 ),
       .FRAME_INFO_IN_BITS ( 0 ),
       .RX_TX_CREDIT_MAX ( 8 )
   ) tb ();
endmodule

module test_toe_ctrl_tx_random;
   tb_toe_ctrl_tx tb ();
endmodule

module test_toe_ctrl_tx_slow_frame_info;
   tb_toe_ctrl_tx #(
       .RX_IN_BITS ( 0 ),
       .TX_CMD_BITS ( 0 ),
       .TX_RSP_BITS ( 0 ),
       .TX_IN_BITS ( 0 ),
       .TX_OUT_BITS ( 0 ),
       .MAX_FRAME_SIZE_BITS ( 8 ),
       .FRAME_INFO_IN_BITS ( 5 )
   ) tb ();
endmodule

module test_toe_ctrl_tx_random_1ch;
   tb_toe_ctrl_tx #(
       .ENABLE_FIXED_CH ( 1 ),
       .RX_TX_CREDIT_MAX ( 5 )
   ) tb ();
endmodule

module test_toe_ctrl_tx_random_large;
   tb_toe_ctrl_tx #(
       .MAX_FRAME_SIZE_BITS ( 17 )
   ) tb ();
endmodule

module test_toe_ctrl_tx_fast_activate;
   tb_toe_ctrl_tx #(
       .RX_IN_BITS ( 0 ),
       .TX_CMD_BITS ( 0 ),
       .TX_RSP_BITS ( 0 ),
       .TX_IN_BITS ( 0 ),
       .TX_OUT_BITS ( 0 ),
       .FRAME_INFO_OUT_BITS ( 0 ),
       .FRAME_INFO_IN_BITS ( 0 ),
       .RX_TX_CREDIT_MAX ( 8 ),
       .MAX_TRANSFERS ( 0 ),
       .ACTIVATE_FAIL ( 1 )
   ) tb ();
endmodule
