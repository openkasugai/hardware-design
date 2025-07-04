/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module tb_toe_ctrl #(
    parameter AW = 16,
    parameter DW_LOG = 9,
    parameter CH_NUM_LOG = 4,
    parameter BURST_BITS = 6,
    parameter SESSION_NUM_LOG = 6,
    parameter FRAME_MAX = 8,
    parameter MAX_INFLIGHT = 2,
    parameter TX_FIFO_DL = 9,
    parameter TX_AUX_FIFO_DL = 4,
    parameter ACTIVATE_MAGIC = 32'h56544341, // ACTV
    parameter CREDIT_MAGIC = 32'h54445243,  // CRDT
    parameter RX_IN_BITS = 1,
    parameter RX_OUT_BITS = 1,
    parameter TX_IN_BITS = 1,
    parameter TX_OUT_BITS = 1,
    parameter TX_CMD_BITS = 1,
    parameter TX_RSP_BITS = 1,
    parameter FRAME_INFO_OUT_BITS = 1,
    parameter FRAME_INFO_IN_BITS = 1,
    parameter MAX_FRAME_SIZE_BITS = 14,
    parameter MAX_CREDIT_BITS = 3,
    parameter FIXED_CH = 4,
    parameter ENABLE_FIXED_CH = 0,
    parameter PACKET_CONCAT = 0,
    parameter ENABLE_DIRTY_RX_TX = 1,
    parameter RX_TX_CREDIT_MAX = 0,
    parameter MAX_TRANSFERS = 100
    ) ();

   localparam CH_REG_BITS = 8;
   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam SESSION_NUM = 1 << SESSION_NUM_LOG;
   localparam GLOBAL_BASE = 16'h0;
   localparam GLOBAL_SIZE = 16'h1000;
   localparam CH_SIZE = 1 << CH_REG_BITS;
   localparam TX_BASE = GLOBAL_BASE + GLOBAL_SIZE;
   localparam RX_BASE = TX_BASE + CH_SIZE * CH_NUM;
   localparam CH_BASE_NUM = GLOBAL_SIZE >> CH_REG_BITS;
   localparam DW = 1 << DW_LOG;
   localparam KW_LOG = DW_LOG - 3;
   localparam KW = 1 << KW_LOG;
   localparam BURST_SIZE = 1 << (BURST_BITS + KW_LOG);
   localparam FRAME_SIZE_MAX = 1 << MAX_FRAME_SIZE_BITS;
   localparam RX_IN_BITS_MOD = RX_IN_BITS > 0 ? RX_IN_BITS : 1;
   localparam RX_OUT_BITS_MOD = RX_OUT_BITS > 0 ? RX_OUT_BITS : 1;
   localparam TX_IN_BITS_MOD = TX_IN_BITS > 0 ? TX_IN_BITS : 1;
   localparam TX_OUT_BITS_MOD = TX_OUT_BITS > 0 ? TX_OUT_BITS : 1;
   localparam TX_CMD_BITS_MOD = TX_CMD_BITS > 0 ? TX_CMD_BITS : 1;
   localparam TX_RSP_BITS_MOD = TX_RSP_BITS > 0 ? TX_RSP_BITS : 1;
   localparam FRAME_INFO_IN_BITS_MOD = FRAME_INFO_IN_BITS > 0 ? FRAME_INFO_IN_BITS : 1;
   localparam FRAME_INFO_OUT_BITS_MOD = FRAME_INFO_OUT_BITS > 0 ? FRAME_INFO_OUT_BITS : 1;

   // reg
   reg [AW-1:0]               axil_araddr;
   reg                        axil_arvalid;
   wire                       axil_arready;
   wire [31:0]                axil_rdata;
   wire [1:0]                 axil_rresp;
   wire                       axil_rvalid;
   reg                        axil_rready;
   reg [AW-1:0]               axil_awaddr;
   reg                        axil_awvalid;
   wire                       axil_awready;
   reg [31:0]                 axil_wdata;
   reg                        axil_wvalid;
   wire                       axil_wready;
   wire [1:0]                 axil_bresp;
   wire                       axil_bvalid;
   reg                        axil_bready;

   // tx
   reg [(1<<DW_LOG)-1:0]      tx_in_tdata;
   reg [(1<<(DW_LOG-3))-1:0]  tx_in_tkeep;
   reg [CH_NUM_LOG-1:0]       tx_in_tuser;
   reg                        tx_in_tlast;
   reg                        tx_in_sop;
   reg                        tx_in_eop;
   reg [BURST_BITS-1:0]       tx_in_burst; // 0-origin -> 1-origin
   reg [DW_LOG-4:0]           tx_in_last_cnt; // 0-origin -> 1->origin
   reg                        tx_in_tvalid;
   wire                       tx_in_tready;

   wire [(1<<DW_LOG)-1:0]     tx_toe_tdata;
   wire [(1<<(DW_LOG-3))-1:0] tx_toe_tkeep;
   wire [SESSION_NUM_LOG-1:0] tx_toe_tuser;
   wire                       tx_toe_tlast;
   wire                       tx_toe_tvalid;
   reg                        tx_toe_tready;

   wire [31:0]                tx_toe_cmd_tdata;
   wire                       tx_toe_cmd_tvalid;
   reg                        tx_toe_cmd_tready;

   reg [87:0]                 tx_toe_rsp_tdata;
   reg                        tx_toe_rsp_tvalid;
   wire                       tx_toe_rsp_tready;

   // rx
   reg [(1<<DW_LOG)-1:0]      rx_toe_tdata;
   reg [(1<<(DW_LOG-3))-1:0]  rx_toe_tkeep;
   reg [SESSION_NUM_LOG-1:0]  rx_toe_tuser;
   reg                        rx_toe_tlast;
   reg                        rx_toe_tvalid;
   wire                       rx_toe_tready;

   wire [(1<<DW_LOG)-1:0]     rx_out_tdata;
   wire [(1<<(DW_LOG-3))-1:0] rx_out_tkeep;
   wire [CH_NUM_LOG-1:0]      rx_out_tuser;
   wire                       rx_out_tlast; // eop
   wire                       rx_out_eof;
   wire                       rx_out_tvalid;
   reg                        rx_out_tready;

   // tx frame
   wire [31:0]                tx_frame_info_out_tdata; // tx_frame size
   wire [CH_NUM_LOG-1:0]      tx_frame_info_out_tuser;
   wire                       tx_frame_info_out_tvalid;
   reg                        tx_frame_info_out_tready;

   reg [31:0]                 tx_frame_info_tdata; // tx_frame size
   reg [CH_NUM_LOG-1:0]       tx_frame_info_tuser;
   reg                        tx_frame_info_tvalid;
   wire                       tx_frame_info_tready;

   // rx frame
   wire [31:0]                rx_frame_info_out_tdata; // rx_frame size
   wire [CH_NUM_LOG-1:0]      rx_frame_info_out_tuser;
   wire                       rx_frame_info_out_tvalid;
   reg                        rx_frame_info_out_tready;

   reg [31:0]                 rx_frame_info_tdata; // rx_frame size
   reg [CH_NUM_LOG-1:0]       rx_frame_info_tuser;
   reg                        rx_frame_info_tvalid;
   wire                       rx_frame_info_tready;

   wire                       clk;
   wire                       resetn;
   wire [31:0]                rd;

   clk_reset clk_reset (
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
   );

   toe_ctrl #(
       .AW ( AW ),
       .DW_LOG ( DW_LOG ),
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .BURST_BITS ( BURST_BITS ),
       .SESSION_NUM_LOG ( SESSION_NUM_LOG ),
       .FRAME_MAX ( FRAME_MAX ),
       .MAX_INFLIGHT ( MAX_INFLIGHT ),
       .TX_FIFO_DL ( TX_FIFO_DL ),
       .TX_AUX_FIFO_DL ( TX_AUX_FIFO_DL ),
       .ACTIVATE_MAGIC ( ACTIVATE_MAGIC ),
       .CREDIT_MAGIC ( CREDIT_MAGIC )
   ) dut (
       .*
   );

   initial begin
      axil_arvalid = 1'b0;
      axil_rready = 1'b1;
      axil_awvalid = 1'b0;
      axil_wvalid = 1'b0;
      axil_bready = 1'b1;
      tx_in_tvalid = 1'b0;
      tx_toe_tready = 1'b1;
      tx_toe_cmd_tready = 1'b1;
      tx_toe_rsp_tvalid = 1'b0;
      rx_toe_tvalid = 1'b0;
      rx_out_tready = 1'b1;
      tx_frame_info_out_tready = 1'b1;
      tx_frame_info_tvalid = 1'b0;
      rx_frame_info_out_tready = 1'b1;
      rx_frame_info_tvalid = 1'b0;
   end

   reg [SESSION_NUM_LOG-1:0] tx_sessions[0:CH_NUM-1];
   reg [SESSION_NUM_LOG-1:0] rx_sessions[0:CH_NUM-1];
   reg [CH_NUM-1:0]          tx_enables;
   reg [CH_NUM-1:0]          rx_enables;
   reg [CH_NUM-1:0]          tx_valids;
   reg [CH_NUM-1:0]          rx_valids;
   reg [CH_NUM-1:0]          rx_activates;
   reg [31:0]                rx_frame_sizes[0:CH_NUM-1];
   reg [15:0]                rx_max_credits[0:CH_NUM-1];
   reg [31:0]                tx_frame_sizes[0:CH_NUM-1];
   reg [15:0]                tx_max_credits[0:CH_NUM-1];
   reg [31:0]                tx_ips[0:CH_NUM-1], rx_ips[0:CH_NUM-1];
   reg [31:0]                tx_ip_masks[0:CH_NUM-1], rx_ip_masks[0:CH_NUM-1];
   reg [15:0]                tx_ports[0:CH_NUM-1], rx_ports[0:CH_NUM-1];
   reg [15:0]                tx_port_masks[0:CH_NUM-1], rx_port_masks[0:CH_NUM-1];

   reg [DW-1:0] rx_data_saved[0:255];
   reg [KW-1:0] rx_keep_saved[0:255];
   reg [CH_NUM_LOG-1:0] rx_user_saved[0:255];
   reg                  rx_last_saved[0:255];
   reg                  rx_eof_saved[0:255];
   reg [7:0]            rx_wpos, rx_rpos, rx_epos;
   logic [DW-1:0]         tx_credit_data_saved[0:255];
   logic [KW-1:0]         tx_credit_keep_saved[0:255];
   logic [SESSION_NUM_LOG-1:0] tx_credit_session_saved[0:255];
   logic                       tx_credit_last_saved[0:255];
   logic [7:0]            tx_credit_wpos;
   logic [7:0]            tx_credit_rpos;
   logic [1:0] rx_toe_mode;
   logic       rx_toe_mode_var;
   initial begin
      rx_wpos = 'd0;
      rx_epos = 'd0;
      rx_rpos = 'd0;
      tx_credit_wpos = 'd0;
      tx_credit_rpos = 'd0;
      rx_toe_mode = 'd0;
      rx_toe_mode_var = 1'b1;
   end
   always @(posedge clk) begin
      if (resetn) begin
         if (rx_toe_mode_var) rx_toe_mode = rd[10+:2];
         if ((RX_IN_BITS > 0 ? &rd[13+:RX_IN_BITS_MOD] : 1'b1) & (~rx_toe_tvalid || rx_toe_tready)) begin
            if (&rx_toe_mode && tx_credit_wpos != tx_credit_rpos) begin
               rx_toe_tdata <= tx_credit_data_saved[tx_credit_rpos];
               rx_toe_tkeep <= tx_credit_keep_saved[tx_credit_rpos];
               rx_toe_tuser <= tx_credit_session_saved[tx_credit_rpos];
               rx_toe_tlast <= tx_credit_last_saved[tx_credit_rpos];
               rx_toe_tvalid <= 1'b1;
               tx_credit_rpos <= tx_credit_rpos + 1'b1;
               rx_toe_mode_var <= tx_credit_last_saved[tx_credit_rpos];
            end else if (~&rx_toe_mode && rx_wpos != rx_epos) begin
               rx_toe_tdata <= rx_data_saved[rx_epos];
               rx_toe_tkeep <= rx_keep_saved[rx_epos];
               rx_toe_tuser <= rx_sessions[rx_user_saved[rx_epos]];
               rx_toe_tlast <= rx_last_saved[rx_epos];
               rx_toe_tvalid <= 1'b1;
               rx_toe_mode_var <= rx_last_saved[rx_epos];
               rx_epos <= rx_epos + 1'b1;
            end else begin
               rx_toe_tvalid <= rx_toe_tvalid & ~rx_toe_tready;
            end
         end else begin
            rx_toe_tvalid <= rx_toe_tvalid & ~rx_toe_tready;
         end
      end
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


   reg [31:0] tx_frame_size_saved[0:CH_NUM-1][0:255];
   reg [7:0]  tx_frame_size_spos[0:CH_NUM-1];
   reg [7:0]  tx_frame_size_cpos[0:CH_NUM-1];
   reg [7:0]  tx_frame_size_wpos[0:CH_NUM-1];
   reg [7:0]  tx_frame_size_rpos[0:CH_NUM-1];
   reg [7:0]  tx_frame_size_epos[0:CH_NUM-1];
   reg [31:0] rx_frame_size_saved[0:CH_NUM-1][0:255];
   reg [7:0]  rx_frame_size_spos[0:CH_NUM-1];
   reg [7:0]  rx_frame_size_cpos[0:CH_NUM-1];
   reg [7:0]  rx_frame_size_wpos[0:CH_NUM-1];
   reg [7:0]  rx_frame_size_rpos[0:CH_NUM-1];
   reg [7:0]  rx_frame_size_epos[0:CH_NUM-1];
   initial begin
      for (int i=0; i<CH_NUM; i++) begin
         tx_frame_size_spos[i] = 'd0;
         tx_frame_size_cpos[i] = 'd0;
         tx_frame_size_wpos[i] = 'd0;
         tx_frame_size_rpos[i] = 'd0;
         tx_frame_size_epos[i] = 'd0;
         rx_frame_size_spos[i] = 'd0;
         rx_frame_size_cpos[i] = 'd0;
         rx_frame_size_wpos[i] = 'd0;
         rx_frame_size_rpos[i] = 'd0;
         rx_frame_size_epos[i] = 'd0;
      end
   end
   always @(posedge clk) begin
      if (resetn && tx_frame_info_out_tvalid && tx_frame_info_out_tready) begin
         if (tx_frame_info_out_tdata !== tx_frame_size_saved[tx_frame_info_out_tuser][tx_frame_size_cpos[tx_frame_info_out_tuser]]) begin
            $error("%d: [%2h] tx frame info out: %h %h", $time, tx_frame_info_out_tuser,
                   tx_frame_info_out_tdata, tx_frame_size_saved[tx_frame_info_out_tuser][tx_frame_size_cpos[tx_frame_info_out_tuser]]);
         end else begin
            $display("%d: [%2h] tx frame info out: %h %h", $time, tx_frame_info_out_tuser,
                     tx_frame_info_out_tdata, tx_frame_size_saved[tx_frame_info_out_tuser][tx_frame_size_cpos[tx_frame_info_out_tuser]]);
         end
         tx_frame_size_cpos[tx_frame_info_out_tuser] <= tx_frame_size_cpos[tx_frame_info_out_tuser] + 1'b1;
      end
      if (resetn && rx_frame_info_out_tvalid && rx_frame_info_out_tready) begin
         rx_frame_size_saved[rx_frame_info_out_tuser][rx_frame_size_spos[rx_frame_info_out_tuser]] <= rx_frame_info_out_tdata;
         rx_frame_size_spos[rx_frame_info_out_tuser] <= rx_frame_size_spos[rx_frame_info_out_tuser] + 1'b1;
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
   initial begin
      tx_wpos = 'd0;
      tx_rpos = 'd0;
      rx_packet_wpos = 'd0;
      rx_packet_rpos = 'd0;
   end
   logic tx_toe_is_rx;
   always @(posedge clk) begin
      if (resetn && tx_toe_tvalid && tx_toe_tready) begin
         for (int i=0; i<CH_NUM; i++) begin
            if (tx_toe_tuser == tx_sessions[i]) begin
               tx_toe_is_rx = 0;
               break;
            end else if (tx_toe_tuser == rx_sessions[i]) begin
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
         end else begin
            if (tx_toe_tdata !== rx_packet_data_saved[rx_packet_rpos] ||
                tx_toe_tkeep !== rx_packet_keep_saved[rx_packet_rpos] ||
                tx_toe_tuser !== rx_packet_user_saved[rx_packet_rpos] ||
                tx_toe_tlast !== rx_packet_last_saved[rx_packet_rpos]) begin
               $error("%d: [%2h] rx packet data: %h %h, %h %h, %h %h, %h %h (%h %h)", $time, tx_toe_tuser,
                      tx_toe_tdata, rx_packet_data_saved[rx_packet_rpos],
                      tx_toe_tkeep, rx_packet_keep_saved[rx_packet_rpos],
                      tx_toe_tuser, rx_packet_user_saved[rx_packet_rpos],
                      tx_toe_tlast, rx_packet_last_saved[rx_packet_rpos], rx_packet_rpos, rx_packet_wpos);
            end
            rx_packet_rpos <= rx_packet_rpos + 1'b1;
         end
      end
   end
   // tx cmd rsp
   logic        all_connected;
   logic [15:0] toe_cmd_size;
   logic [15:0] toe_cmd_session_id;
   logic        toe_cmd_valid;
   logic        toe_rsp_valid;
   logic        toe_rsp_vacant;
   logic        tx_toe_is_closed;
   logic [3:0]  toe_rsp_mode;
   logic [SESSION_NUM_LOG-1:0] toe_conn_session_id;
   logic                       toe_conn_session_id_dup;
   logic [87:0]                conn_rsp_data_saved[0:255];
   logic [7:0]                 conn_rsp_wpos, conn_rsp_rpos;
   initial begin
      toe_cmd_valid = 1'b0;
      all_connected = 1'b0;
      conn_rsp_wpos = 'd0;
      conn_rsp_rpos = 'd0;
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
               if (tx_toe_cmd_tdata[15:0] == rx_sessions[i] ||
                   tx_toe_cmd_tdata[15:0] == tx_sessions[i]) begin
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
                         (~tx_toe_rsp_tvalid || tx_toe_rsp_tready) && (toe_cmd_valid || &toe_rsp_mode || ~all_connected);
         toe_rsp_vacant = rd[30];
         if (toe_rsp_valid && ~all_connected) begin
            tx_toe_rsp_tdata <= conn_rsp_data_saved[conn_rsp_rpos];
            tx_toe_rsp_tvalid <= conn_rsp_rpos != conn_rsp_wpos;
            conn_rsp_rpos <= conn_rsp_rpos + (conn_rsp_rpos != conn_rsp_wpos);
         end else if (toe_rsp_valid && ~&toe_rsp_mode) begin
            tx_toe_rsp_tdata <= {5'd0, tx_toe_is_closed, 2'd0, rd[31:0], rd[15:0], toe_rsp_vacant ? toe_cmd_size : 16'd0, toe_cmd_session_id};
            tx_toe_rsp_tvalid <= toe_rsp_valid;
            toe_cmd_valid <= 1'b0;
         end else if (toe_rsp_valid) begin
            toe_conn_session_id = rd;
            toe_conn_session_id_dup = 1;
            while (toe_conn_session_id_dup) begin
               toe_conn_session_id_dup = 0;
               for (int i=0; i<CH_NUM; i++) begin
                  if (toe_conn_session_id == tx_sessions[i] ||
                      toe_conn_session_id == rx_sessions[i]) begin
                     toe_conn_session_id_dup = 1;
                     break;
                  end
               end
               if (toe_conn_session_id_dup) toe_conn_session_id++;
            end
            tx_toe_rsp_tdata <= {7'd0, 1'b1, rd[31:0], rd[15:0], 16'd0, 16'd0 | toe_conn_session_id};
            tx_toe_rsp_tvalid <= toe_rsp_valid;
         end else begin
            tx_toe_rsp_tvalid <= tx_toe_rsp_tvalid & ~tx_toe_rsp_tready;
         end
      end
   end

   task static read_write_configs;
      logic [CH_NUM_LOG-1:0] ch;
      logic                  is_rx;
      logic [AW-1:0]         awaddr;
      logic [31:0]           wdata, edata;
      logic [AW-1:0]         araddr;
      logic [31:0]           rdata;
      logic [31:0]           wdata_saved[0:CH_NUM*2*10-1];
      int                    wdata_pos = 0;
      logic                  awvalid = 0;
      logic                  wvalid = 0;
      logic [2:0]            stat = 0;
      logic                  dup = 0;
      // write
      $display("read write config start");
      for (int dir=0; dir<2; dir++) begin
         for (int ch=0; ch<CH_NUM; ch++) begin
            for (int i=2; i<11; i++) begin
               awaddr = (dir == 0 ? TX_BASE : RX_BASE) + CH_SIZE * ch + (i % 10) * 4;
               wdata = rd;
               casex(i%10)
                  0: edata = {27'd0, wdata[4] && wdata[0] && dir== 1, 3'd0, wdata[0]};
                  1: edata = 32'd0;
                  2: edata = 'd0;
                  3: edata = wdata;
                  4: edata = dir==1 ? {16'd0, wdata[15:0]} : 32'd0;
                  5: edata = 32'd0;
                  6: edata = wdata;
                  7: edata = 32'hffffffff ^ (32'h1 << ch);
                  8: edata = {16'd0, wdata[15:0]};
                  9: edata = {16'd0, 16'hffff ^ (16'h1 << ch)};
               endcase
               if (i==2) begin
                  dup = 1;
                  while (dup) @(posedge clk) begin
                     dup = 0;
                     for (int prev = 0; prev < ch; prev++) begin
                        if (tx_sessions[prev] == rd[SESSION_NUM_LOG-1:0] ||
                            rx_sessions[prev] == rd[SESSION_NUM_LOG-1:0]) begin
                           dup = 1;
                           break;
                        end
                     end
                     if (dir == 1 && tx_sessions[ch] == rd[SESSION_NUM_LOG-1:0]) begin
                        dup = 1;
                     end
                  end
                  if (dir==0) begin
                     tx_sessions[ch] = rd[SESSION_NUM_LOG-1:0];
                  end else begin
                     rx_sessions[ch] = rd[SESSION_NUM_LOG-1:0];
                  end
                  wdata = 'd0;
               end else if (i==3) begin
                  wdata &= (32'h1 << MAX_FRAME_SIZE_BITS) - 1;
                  if (~|wdata) wdata = 'h876;
                  if (dir == 1) begin
                     rx_frame_sizes[ch] = wdata;
                     edata = wdata;
                  end else begin
                     tx_frame_sizes[ch] = wdata;
                     edata = 32'd0;
                  end
               end else if (i==4) begin
                  if (dir == 1) begin
                     rx_max_credits[ch] = edata;
                  end else begin
                     tx_max_credits[ch] = edata;
                     edata <= 32'd0;
                  end
               end else if (i==6) begin
                  if (dir==0) begin
                     tx_ips[ch] = wdata;
                  end else begin
                     rx_ips[ch] = wdata;
                  end
               end else if (i==7) begin
                  wdata = 32'hffffffff ^ (32'h1 << ch);
                  if (dir==0) begin
                     tx_ip_masks[ch] = wdata;
                  end else begin
                     rx_ip_masks[ch] = wdata;
                  end
               end else if (i==8) begin
                  wdata = {16'd0, wdata[15:0]};
                  if (dir==0) begin
                     tx_ports[ch] = wdata[15:0];
                  end else begin
                     rx_ports[ch] = wdata[15:0];
                  end
               end else if (i==9) begin
                  wdata = {16'd0, 16'hffff ^ (16'h1 << ch)};
                  if (dir==0) begin
                     tx_port_masks[ch] = wdata[15:0];
                  end else begin
                     rx_port_masks[ch] = wdata[15:0];
                  end
               end else if (i==10) begin
                  if (dir==0) begin
                     tx_enables[ch] = wdata[0];
                  end else begin
                     rx_enables[ch] = wdata[0];
                     rx_activates[ch] = wdata[4] & wdata[0];
                  end
               end
               wdata_saved[wdata_pos] = edata;
               wdata_pos++;
               while (~&stat) @(posedge clk) begin
                  if (~stat[0] && rd[4]) begin
                     axil_awvalid <= 1'b1;
                     axil_awaddr <= awaddr;
                     stat[0] <= 1'b1;
                  end else begin
                     axil_awvalid <= axil_awvalid & ~axil_awready;
                  end
                  if (~stat[1] && rd[8]) begin
                     axil_wvalid <= 1'b1;
                     axil_wdata <= wdata;
                     stat[1] <= 1'b1;
                  end else begin
                     axil_wvalid <= axil_wvalid & ~axil_wready;
                  end
                  axil_bready <= rd[12];
                  if (~stat[2] && axil_bvalid & axil_bready) begin
                     stat[2] <= 1'b1;
                  end
               end
               @(posedge clk) stat <= 'd0;
               @(posedge clk);
            end
         end
      end
      $display("read write config write done");
      // read
      wdata_pos = 0;
      for (int dir=0; dir<2; dir++) begin
         for (int ch=0; ch<CH_NUM; ch++) begin
            for (int i=2; i<11; i++) begin
               araddr = (dir == 0 ? TX_BASE : RX_BASE) + CH_SIZE * ch + (i % 10) * 4;
               rdata = wdata_saved[wdata_pos];
               wdata_pos++;
               while (~&stat[1:0]) @(posedge clk) begin
                  if (~stat[0] && rd[4]) begin
                     axil_arvalid <= 1'b1;
                     axil_araddr <= araddr;
                     stat[0] <= 1'b1;
                  end else begin
                     axil_arvalid <= axil_arvalid & ~axil_arready;
                  end
                  axil_rready <= rd[12];
                  if (~stat[1] && axil_rvalid & axil_rready) begin
                     if (axil_rdata !== rdata) begin
                        $error("%d: %s[%2h][%3h]: %h %h", $time, dir==0 ? "tx" : "rx", ch, araddr,
                               axil_rdata, rdata);
                     end
                     stat[1] <= 1'b1;
                  end
               end
               @(posedge clk) stat <= 'd0;
               @(posedge clk);
            end
         end
      end
      $display("read write config read done");
      // read global
      rdata = 32'h0 | (SESSION_NUM_LOG << 8) | CH_NUM_LOG;
      while (~&stat[1:0]) @(posedge clk) begin
         if (~stat[0] && rd[4]) begin
            axil_arvalid <= 1'b1;
            axil_araddr <= 'd0;
            stat[0] <= 1'b1;
         end else begin
            axil_arvalid <= axil_arvalid & ~axil_arready;
         end
         axil_rready <= rd[12];
         if (~stat[1] && axil_rvalid & axil_rready) begin
            if (axil_rdata !== rdata) begin
               $error("%d: global: %h %h", $time, axil_rdata, rdata);
            end
            stat[1] <= 1'b1;
         end
      end
      @(posedge clk) stat <= 'd0;
   endtask

   task static channel_validate;
      logic [SESSION_NUM_LOG-1:0] session_id;
      logic [CH_NUM_LOG:0]        ch = 0;
      logic                       is_tx = 0;
      logic [31:0]                ip, ip_mask;
      logic [15:0]                port, port_mask;
      logic                       inflight = 0;
      logic                       valid = 0;
      logic [AW-1:0]              araddr;
      logic [31:0]                rdata;
      logic [1:0]                 stat = 0;
      logic [3:0]                 retry;
      for (int i=0; i<CH_NUM; i++) begin
         $display("%d: [%2h] rx: %h %h %h %h(%h) %h(%h), tx: %h %h %h(%h) %h(%h)", $time, i,
                  rx_enables[i], rx_activates[i], rx_sessions[i], rx_ips[i], rx_ip_masks[i], rx_ports[i], rx_port_masks[i],
                  tx_enables[i], tx_sessions[i], tx_ips[i], tx_ip_masks[i], tx_ports[i], tx_port_masks[i]);
      end
      while (~is_tx || ch < CH_NUM || valid || inflight) @(posedge clk) begin
         if (~inflight) begin
            session_id = is_tx ? tx_sessions[ch] : rx_sessions[ch];
            ip = is_tx ? tx_ips[ch] : rx_ips[ch];
            ip_mask = is_tx ? tx_ip_masks[ch] : rx_ip_masks[ch];
            port = is_tx ? tx_ports[ch] : rx_ports[ch];
            port_mask = is_tx ? tx_port_masks[ch] : rx_port_masks[ch];
            ip = ip ^ (~ip_mask);
            port = port ^ (~port_mask);
            valid = is_tx ? tx_enables[ch] : rx_enables[ch];
            if (valid) begin
               conn_rsp_data_saved[conn_rsp_wpos] <= {7'd0, 1'b1, ip, port, 16'd0, 16'd0 | session_id};
               conn_rsp_wpos <= conn_rsp_wpos + rd[12];
               if (rd[12]) $display("%d: [%2h] connected rsp: %h %h, %h", $time, ch, session_id, ip, port);
               if (~is_tx && rx_activates[ch] && rd[12]) begin
                  rx_packet_data_saved[rx_packet_wpos] <= 'd0 | {rx_max_credits[ch], rx_frame_sizes[ch], ACTIVATE_MAGIC};
                  rx_packet_keep_saved[rx_packet_wpos] <= {KW{1'b0}} | 10'h3ff;
                  rx_packet_last_saved[rx_packet_wpos] <= 1'b1;
                  rx_packet_user_saved[rx_packet_wpos] <= rx_sessions[ch];
                  rx_packet_wpos <= rx_packet_wpos + 1'b1;
               end
               inflight <= valid & rd[12];
               retry <= 10;
            end else begin
               ch++;
               if (ch==CH_NUM && ~is_tx) begin
                  ch = 0;
                  is_tx = 1;
               end
               continue;
            end
         end else begin
            if (~stat[0] && (~axil_arvalid || axil_arready)) begin
               stat[0] <= 1'b1;
               axil_araddr <= (is_tx ? TX_BASE : RX_BASE) + CH_SIZE * ch + 2 * 4; // session_id
               axil_arvalid <= 1'b1;
            end else begin
               axil_arvalid <= axil_arvalid & ~axil_arready;
            end
            if (axil_rvalid && axil_rready) begin
               if (axil_rdata !== (32'h0 | session_id)) begin
                  if (~|retry) begin
                     stat[1] <= 'd1;
                     $error("%d: [%2h] connected %h %h", $time, ch, axil_rdata, session_id);
                     #50 $fatal(2, "%d: [%2h] connected %h %h", $time, ch, axil_rdata, session_id);
                  end else begin
                     stat <= 'd0;
                     retry <= retry - 1'b1;
                  end
               end else begin
                  stat[1] <= 1'b1;
               end
            end
            if (&stat) begin
               if (is_tx) begin
                  tx_credit_data_saved[tx_credit_wpos] <= {'d0, tx_max_credits[ch], tx_frame_sizes[ch], ACTIVATE_MAGIC};
                  tx_credit_keep_saved[tx_credit_wpos] <= {KW{1'b0}} | 10'h3ff;
                  tx_credit_last_saved[tx_credit_wpos] <= 1'b1;
                  tx_credit_session_saved[tx_credit_wpos] <= tx_sessions[ch];
                  tx_credit_wpos <= tx_credit_wpos + 1'b1;
               end
               stat <= 'd0;
               inflight <= 1'b0;
               ch++;
               if (ch==CH_NUM && ~is_tx) begin
                  ch = 0;
                  is_tx = 1;
               end
            end
         end
         axil_rready <= rd[14];
      end
      while (tx_credit_wpos != tx_credit_rpos) @(posedge clk);
      $display("channel validate fin");
   endtask

   task static generate_tx_credit;
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
      while (frame_count < MAX_TRANSFERS || |num || |len || tx_credit_wpos != tx_credit_rpos) @(posedge clk) begin
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
               if (~tx_enables[ch]) num = 0;
            end
         end
         max_len = ENABLE_DIRTY_RX_TX > 0 ? rd[12+:KW_LOG]+1 : 8;
         if (num > 0) begin
            size = (('d1 << MAX_FRAME_SIZE_BITS)-1) & rd;
            if (|size) begin
               data = data | {size, CREDIT_MAGIC} << {len, 3'd0};
               tx_frame_size_saved[ch][tx_frame_size_spos[ch]] <= size;
               tx_frame_size_spos[ch] <= tx_frame_size_spos[ch] + 1'b1;
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
            tx_credit_data_saved[tx_credit_wpos] = data;
            keep = ({{KW{1'b0}}, 1'b1} << len)-1;
            tx_credit_keep_saved[tx_credit_wpos] = keep;
            tx_credit_session_saved[tx_credit_wpos] = tx_sessions[ch];
            tx_credit_last_saved[tx_credit_wpos] = len >= max_len || (num == 0 && remain == 0);
            $display("%d: [%2h] tx credit packet %h %h %h, len=%d, remain=%d", $time, ch,
                     data, keep, len >= max_len || (num == 0 && remain == 0),
                     len, remain);
            tx_credit_wpos++;
            data >>= {len, 3'd0};
            len = remain;
         end
      end
   endtask

   task static generate_tx_frames;
      int frame_count = 0;
      logic [31:0] size, cur_size;
      logic [CH_NUM_LOG-1:0] ch;
      logic                  valid = 0;
      while (frame_count < MAX_TRANSFERS || valid || tx_frame_info_tvalid ) @(posedge clk) begin
         ch = rd[4+:CH_NUM_LOG];
         valid = tx_frame_size_cpos[ch] != tx_frame_size_wpos[ch];
         valid &= FRAME_INFO_IN_BITS > 0 ? &rd[10+:FRAME_INFO_IN_BITS_MOD] : 1'b1;
         size = tx_frame_size_saved[ch][tx_frame_size_wpos[ch]];
         valid &= |size;
         if (valid && (~tx_frame_info_tvalid | tx_frame_info_tready)) begin
            tx_frame_size_wpos[ch] <= tx_frame_size_wpos[ch] + 1'b1;
            frame_count++;
            tx_frame_info_tdata <= size;
            tx_frame_info_tuser <= ch;
            tx_frame_info_tvalid <= valid;
            $display("%d: [%2h] generate frame: %d, %h (%d)", $time, ch, tx_frame_size_wpos[ch], size, frame_count);
         end else begin
            tx_frame_info_tvalid <= tx_frame_info_tvalid & ~tx_frame_info_tready;
         end
      end
      $display("generate tx frame finish");
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
            if (~|frame_sizes[ch] && tx_frame_size_epos[ch] != tx_frame_size_wpos[ch]) begin
               frame_sizes[ch] = tx_frame_size_saved[ch][tx_frame_size_epos[ch]];
               tx_frame_size_epos[ch] = tx_frame_size_epos[ch] + 1'b1;
               $display("%d: [%2h] tx input size: %h", $time, ch, frame_sizes[ch]);
            end
            cur_size = frame_sizes[ch] < BURST_SIZE ? frame_sizes[ch] : BURST_SIZE;
            frame_sizes[ch] -= cur_size;
            sop = 1;
            if (~|frame_sizes[ch] && |cur_size) begin
               eof = 1'b1;
               $display("%d: [%2h] tx input frames: %d, %d", $time, ch, tx_frame_size_epos[ch], frame_count);
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
            tx_user_saved[tx_wpos] <= tx_sessions[ch];
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
      $display("generate tx input finish");
   endtask

   task static generate_rx_frames;
      int frame_count = 0;
      logic [31:0] size, cur_size;
      logic [CH_NUM_LOG-1:0] ch;
      logic                  valid = 0;
      while (frame_count < MAX_TRANSFERS || valid || rx_frame_info_tvalid ) @(posedge clk) begin
         ch = rd[4+:CH_NUM_LOG];
         valid = rx_frame_size_spos[ch] != rx_frame_size_wpos[ch];
         valid &= FRAME_INFO_IN_BITS > 0 ? &rd[10+:FRAME_INFO_IN_BITS_MOD] : 1'b1;
         cur_size = rd & ((32'd1 << FRAME_SIZE_MAX)-1);
         valid &= |cur_size;
         if (valid && (~rx_frame_info_tvalid | rx_frame_info_tready)) begin
            size = rx_frame_size_saved[ch][rx_frame_size_wpos[ch]];
            size = size > cur_size ? cur_size : size;
            rx_frame_size_saved[ch][rx_frame_size_wpos[ch]] <= size;
            rx_frame_size_wpos[ch] <= rx_frame_size_wpos[ch] + 1'b1;
            rx_packet_data_saved[rx_packet_wpos] <= {'d0, size, CREDIT_MAGIC};
            rx_packet_keep_saved[rx_packet_wpos] <= {KW{1'b0}} | 8'hff;
            rx_packet_user_saved[rx_packet_wpos] <= rx_sessions[ch];
            rx_packet_last_saved[rx_packet_wpos] <= 1'b1;
            rx_packet_wpos <= rx_packet_wpos + 1'b1;
            frame_count++;
            rx_frame_info_tdata <= size;
            rx_frame_info_tuser <= ch;
            rx_frame_info_tvalid <= valid;
            $display("%d: [%2h] rx generate frame: %d, %h > %h", $time, ch, rx_frame_size_wpos[ch],
                     rx_frame_size_saved[ch][rx_frame_size_wpos[ch]], size);
         end else begin
            rx_frame_info_tvalid <= rx_frame_info_tvalid & ~rx_frame_info_tready;
         end
      end
   endtask

   task static generate_rx_inputs;
      logic [DW-1:0] data, data_sep0;
      logic [KW-1:0] keep, keep_sep0;
      logic [DW-1:0] data_sep1[0:CH_NUM-1];
      logic [KW_LOG-1:0] keep_cnt_sep1[0:CH_NUM-1];
      logic          last;
      logic          valid;
      logic          eof;
      logic [CH_NUM_LOG-1:0] ch;
      logic [31:0]   frame_sizes[0:CH_NUM-1];
      logic [31:0]   cur_size = 0;
      logic [31:0]   concat_size = 0;
      logic [3:0]    mode = 0;
      logic [7:0]    rx_wpos_next;
      int            frame_count = 0;
      for (int i=0; i<CH_NUM; i++) begin
         frame_sizes[i] = 'd0;
         data_sep1[i] = 'd0;
         keep_cnt_sep1[i] = 'd0;
      end
      while (frame_count < MAX_TRANSFERS || valid || rx_wpos != rx_rpos) @(posedge clk) begin
         if (~|concat_size) begin
            ch = rd[8+:CH_NUM_LOG];
            if (~|frame_sizes[ch] && rx_frame_size_epos[ch] != rx_frame_size_wpos[ch]) begin
               frame_sizes[ch] = rx_frame_size_saved[ch][rx_frame_size_epos[ch]];
               rx_frame_size_epos[ch] = rx_frame_size_epos[ch] + 1'b1;
               $display("%d: [%2h] rx input size: %h", $time, ch, frame_sizes[ch]);
            end
            cur_size = frame_sizes[ch] < BURST_SIZE ? frame_sizes[ch] : BURST_SIZE;
            frame_sizes[ch] -= cur_size;
            concat_size = cur_size;
            if (~|frame_sizes[ch] && |cur_size) begin
               eof = 1'b1;
               frame_count <= frame_count + 1'b1;
               $display("%d: [%2h] rx input frames: %d", $time, ch, rx_frame_size_epos[ch]);
               if (rx_frame_size_epos[ch] != rx_frame_size_wpos[ch] && PACKET_CONCAT) begin
                  if (cur_size < BURST_SIZE && BURST_SIZE - cur_size <= rx_frame_size_saved[ch][rx_frame_size_epos[ch]]) begin
                     rx_frame_size_saved[ch][rx_frame_size_epos[ch]] <= rx_frame_size_saved[ch][rx_frame_size_epos[ch]] - (BURST_SIZE - cur_size);
                     concat_size = BURST_SIZE;
                  end
               end
            end else begin
               eof = 1'b0;
            end
            if (|cur_size) begin
               $display("%d: [%2h] rx input: size: %h(%h), remain: %h, frames:%d, keep save:%d", $time, ch,
                        cur_size, concat_size, frame_sizes[ch], frame_count, keep_cnt_sep1[ch]);
            end
         end
         valid = |concat_size && (RX_IN_BITS > 0 ? &rd[10+:RX_IN_BITS_MOD] : 1'b1);
         rx_wpos_next = rx_wpos + 1;
         valid &= rx_wpos_next != rx_rpos && ((rx_wpos + 2) & 255) != rx_rpos;
         if (valid) begin
            for (int i=0; i<KW; i++) begin
               keep[i] = i < concat_size;
               data[i*8+:8] = ((rd >> (i&3)*8) ^ (32'h1002 << (i/4))) & {8{keep[i]}};
            end
            last = concat_size <= KW;
            if (cur_size > 0 && cur_size < KW) begin
               // cycle for eof and last without fullbit keep
               $display("%d: [%2h] rx cur_size last: %h %h %h %h, %d %d %d", $time, ch,
                        data, keep, last, eof, keep_cnt_sep1[ch], concat_size, cur_size);
               if (keep_cnt_sep1[ch] + cur_size > KW) begin
                  // separate to 2data splitted by eof
                  $display("%d: [%2h] rx cur_size separate last: %h %h %h %h, %d %d %d", $time, ch,
                           data, keep, last, eof, keep_cnt_sep1[ch], concat_size, cur_size);
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
                  rx_last_saved[rx_wpos] <= 1'b0;
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
                  $display("%d: [%2h] rx size: %h %d %d", $time, ch, keep_sep0, cur_size, keep_cnt_sep1[ch]);
               end else begin
                  // output 1data and remain next frame data
                  keep_sep0 = ({{KW{1'b0}}, 1'b1} << (cur_size + keep_cnt_sep1[ch]))-1;
                  $display("%d: [%2h] rx cur_size no separate last: %h %h %h %h, %d %d %d, %h %h", $time, ch,
                           data, keep, last, eof, keep_cnt_sep1[ch], concat_size, cur_size, keep_sep0,
                           (({{KW{1'b0}}, 1'b1} << (cur_size + keep_cnt_sep1[ch]))-1));
                  for (int i=0; i<KW; i++) begin
                     if (i < keep_cnt_sep1[ch]) begin
                        data_sep0[i*8+:8] = data_sep1[ch][i*8+:8];
                     end else begin
                        data_sep0[i*8+:8] = data[(i-keep_cnt_sep1[ch])*8+:8] & {8{keep_sep0[i]}};
                     end
                  end
                  if (eof) begin
                     $display("%d: [%2h] rx last %h %h", $time, ch, data_sep0, keep_sep0);
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
                  rx_keep_saved[rx_wpos] <= {KW{1'b1}};
                  rx_user_saved[rx_wpos] <= ch;
                  rx_last_saved[rx_wpos] <= last;
                  rx_eof_saved[rx_wpos] <= eof && last;
                  rx_wpos <= rx_wpos + 1'b1;
               end else begin
                  for (int i=keep_cnt_sep1[ch]; i<keep_cnt_sep1[ch] + concat_size; i++) begin
                     data_sep1[ch][i*8+:8] = data[(i-keep_cnt_sep1[ch])*8+:8];
                  end
                  keep_cnt_sep1[ch] += concat_size;
               end
            end
            cur_size = cur_size <= KW? 0 : cur_size - KW;
            concat_size = last ? 0 : concat_size - KW;
         end
      end
   endtask

   initial begin
      @(posedge clk);
      while (~resetn) @(posedge clk);

      read_write_configs;
      channel_validate;
      @(posedge clk) all_connected <= 1'b1;
      fork
         generate_tx_credit;
         generate_tx_frames;
         generate_tx_inputs;
         generate_rx_frames;
         generate_rx_inputs;
      join

      $finish;
   end

endmodule

module test_toe_ctrl_fast;
   tb_toe_ctrl #(
       .RX_IN_BITS ( 0 ),
       .RX_OUT_BITS ( 0 ),
       .TX_IN_BITS ( 0 ),
       .TX_OUT_BITS ( 0 )
   ) tb ();
endmodule

module test_toe_ctrl_random;
   tb_toe_ctrl tb();
endmodule

module test_toe_ctrl_slow_frame_info;
   tb_toe_ctrl #(
       .RX_IN_BITS ( 0 ),
       .RX_OUT_BITS ( 0 ),
       .TX_IN_BITS ( 0 ),
       .TX_OUT_BITS ( 0 ),
       .MAX_FRAME_SIZE_BITS ( 8 ),
       .FRAME_INFO_IN_BITS ( 5 )
   ) tb ();
endmodule

module test_toe_ctrl_random_concat;
   tb_toe_ctrl #(
       .PACKET_CONCAT ( 1 )
   ) tb ();
endmodule

module test_toe_ctrl_random_1ch;
   tb_toe_ctrl #(
       .ENABLE_FIXED_CH ( 1 )
   ) tb ();
endmodule
