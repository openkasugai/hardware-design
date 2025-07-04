/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_network_ip_ctrl #(
    parameter MODE = 0,
    parameter SEED = 32'h12345,
    parameter SESSION_NUM = 4,
    parameter DW_LOG = 9,
    parameter CH_NUM_LOG = 4,
    parameter RX_NOTIFY_MAX = 200,
    parameter RX_REQ_BITS = 2,
    parameter RX_BUF_MAX = 32'h100000,
    parameter RX_BUF_CONSUME = 32'h1000,
    parameter TX_TRANSFER_MAX = 200,
    parameter TX_BUF_MAX = 30'hffff,
    parameter TX_BUF_CONSUME = 30'h1000,
    parameter TX_CMD_BITS = 1,
    parameter TX_RSP_BITS = 1,
    parameter RX_CMD_BITS = 4,
    parameter RX_RSP_BITS = 2,
    parameter RX_DATA_BITS = 1,
    parameter RX_DATA_OUT_BITS = 1
    ) ();

   localparam TX_CMD_BITS_MOD = TX_CMD_BITS > 0 ? TX_CMD_BITS : 1;
   localparam TX_RSP_BITS_MOD = TX_RSP_BITS > 0 ? TX_RSP_BITS : 1;
   localparam RX_CMD_BITS_MOD = RX_CMD_BITS > 0 ? RX_CMD_BITS : 1;
   localparam RX_RSP_BITS_MOD = RX_RSP_BITS > 0 ? RX_RSP_BITS : 1;
   localparam RX_DATA_BITS_MOD = RX_DATA_BITS > 0 ? RX_DATA_BITS : 1;
   localparam RX_DATA_OUT_BITS_MOD = RX_DATA_OUT_BITS > 0 ? RX_DATA_OUT_BITS : 1;

   localparam DW = 1 << DW_LOG;
   localparam KW_LOG = DW_LOG-3;
   localparam KW = 1 << KW_LOG;

   reg [11:0]    axil_araddr;
   reg           axil_arvalid;
   wire          axil_arready;
   wire [31:0]   axil_rdata;
   wire [1:0]    axil_rresp;
   wire          axil_rvalid;
   reg           axil_rready;

   reg [11:0]    axil_awaddr;
   reg           axil_awvalid;
   wire          axil_awready;
   reg [31:0]    axil_wdata;
   reg           axil_wvalid;
   wire          axil_wready;
   wire [1:0]    axil_bresp;
   wire          axil_bvalid;
   reg           axil_bready;

   wire [31:0]   ip_addr;
   wire [31:0]   subnet_mask;
   wire [31:0]   default_gateway;
   wire [47:0]   mac_addr;

   wire          interrupt;

   wire [47:0]   open_req_tdata;
   wire          open_req_tvalid;
   reg           open_req_tready;
   reg [71:0]    open_status_tdata;
   reg           open_status_tvalid;
   wire          open_status_tready;
   wire [15:0]   close_conn_tdata;
   wire          close_conn_tvalid;
   reg           close_conn_tready;
   wire [15:0]   listen_req_tdata;
   wire          listen_req_tvalid;
   reg           listen_req_tready;
   reg [7:0]     listen_status_tdata;
   reg           listen_status_tvalid;
   wire          listen_status_tready;
   reg [87:0]    notification_tdata;
   reg           notification_tvalid;
   wire          notification_tready;
   reg [143:0]   ht_upd_tdata;
   reg           ht_upd_tvalid;
   wire          ht_upd_tready;
   wire [31:0]   tx_req_tdata;
   wire          tx_req_tvalid;
   reg           tx_req_tready;
   reg [63:0]    tx_rsp_tdata;
   reg           tx_rsp_tvalid;
   wire          tx_rsp_tready;
   wire [31:0]   rx_req_tdata;
   wire          rx_req_tvalid;
   reg           rx_req_tready;
   reg [15:0]    rx_rsp_tdata;
   reg           rx_rsp_tvalid;
   wire          rx_rsp_tready;

   reg [31:0]    axis_tcp_cmd_tdata;
   reg           axis_tcp_cmd_tvalid;
   wire          axis_tcp_cmd_tready;

   wire [87:0]   axis_tcp_rsp_tdata;
   wire          axis_tcp_rsp_tvalid;
   reg           axis_tcp_rsp_tready;

   reg [DW-1:0]  rx_in_tdata;
   reg [KW-1:0]  rx_in_tkeep;
   reg           rx_in_tlast;
   reg           rx_in_tvalid;
   wire          rx_in_tready;

   wire [DW-1:0] rx_out_tdata;
   wire [KW-1:0] rx_out_tkeep;
   wire [CH_NUM_LOG-1:0] rx_out_tuser;
   wire                  rx_out_tlast;
   wire                  rx_out_tvalid;
   reg                   rx_out_tready;

   reg           clk;
   reg           resetn;
   reg [31:0]    rd;

   network_ip_ctrl dut(
       .*
   );

   initial begin
      clk = 1'b0;
      resetn = 1'b0;
      rd = $random(SEED);

      axil_araddr = 12'd0;
      axil_arvalid = 1'b0;
      axil_rready = 1'b1;

      axil_awaddr = 12'd0;
      axil_awvalid = 1'b0;
      axil_wdata = 32'd0;
      axil_wvalid = 1'b0;
      axil_bready = 1'b1;

      open_req_tready = 1'b1;
      open_status_tdata = 72'd0;
      open_status_tvalid = 1'b0;
      close_conn_tready = 1'b1;
      listen_req_tready = 1'b1;
      listen_status_tdata = 8'd0;
      listen_status_tvalid = 1'b0;
      notification_tdata = 88'd0;
      notification_tvalid = 1'b0;
      ht_upd_tdata = 144'd0;
      ht_upd_tvalid = 1'b0;
      tx_req_tready = 1'b1;
      tx_rsp_tdata = 64'd0;
      tx_rsp_tvalid = 1'b0;
      rx_req_tready = 1'b1;
      rx_rsp_tdata = 16'd0;
      rx_rsp_tvalid = 1'b0;

      axis_tcp_cmd_tdata = 32'd0;
      axis_tcp_cmd_tvalid = 1'b0;
      axis_tcp_rsp_tready = 1'b0;

      rx_in_tvalid = 1'b0;
      rx_out_tready = 1'b0;
   end
   always #5 clk = ~clk;
   always #100 resetn = 1'b1;
   always @(posedge clk) begin
      rd <= $random();
   end

   always @(posedge clk) begin
      if (resetn) begin
         axil_rready <= rd[8];
         axil_bready <= rd[12];
         axis_tcp_rsp_tready <= TX_RSP_BITS > 0 ? &rd[16+:TX_RSP_BITS_MOD] : 1'b1;
         tx_req_tready <= TX_CMD_BITS > 0 ? &rd[18+:TX_CMD_BITS_MOD] : 1'b1;
         rx_out_tready <= RX_DATA_OUT_BITS > 0 ? &rd[20+:RX_DATA_OUT_BITS_MOD] : 1'b1;
         rx_req_tready <= RX_CMD_BITS > 0 ? &rd[22+:RX_CMD_BITS_MOD] : 1'b1;
      end
   end

   // open req/rsp, close
   reg [15:0] session_id_reg;
   always @(posedge clk) begin
      if (~resetn) begin
         session_id_reg <= rd[15:0];
      end else begin
         if (open_req_tvalid & open_req_tready) begin
            open_status_tdata <= {open_req_tdata, 8'd1, session_id_reg};
            session_id_reg <= session_id_reg + rd[4:0];
            open_status_tvalid <= 1'b1;
            ht_upd_tdata <= {32'd1, session_id_reg, open_req_tdata[47:32], rd[31:16],
                             open_req_tdata[7:0], open_req_tdata[15:8], open_req_tdata[23:16],
                             open_req_tdata[31:24], 32'h0};
            ht_upd_tvalid <= 1'b1;
         end else begin
            open_status_tvalid <= open_status_tvalid & ~open_status_tready;
            if (MODE != 4 && MODE != 6 && MODE != 8) begin
               ht_upd_tvalid <= ht_upd_tvalid & ~ht_upd_tready;
            end
         end
         open_req_tready <= rd[3];
         close_conn_tready <= rd[4];
      end
   end

   task static reg_read();
      logic addr_done;
      while (axil_araddr < 12'h900) begin
         @(posedge clk) addr_done <= 1'b0;
         while (!addr_done) begin
            @(posedge clk) begin
               axil_arvalid <= (axil_arvalid & ~axil_arready) | (~addr_done & rd[3]);
               axil_araddr <= axil_araddr + (axil_arvalid & axil_arready ? 3'd4 : 3'd0);
               addr_done <= (axil_arvalid & axil_arready) | addr_done;
            end
         end
      end
   endtask

   task static reg_write();
      logic addr_done, data_done;
      while (axil_awaddr < 12'h900) begin
         @(posedge clk) begin
            addr_done <= 1'b0;
            data_done <= 1'b0;
         end
         while (!addr_done || !data_done) begin
            @(posedge clk) begin
               axil_awvalid <= (axil_awvalid & ~axil_awready) | (~addr_done & rd[3]);
               axil_wvalid <= (axil_wvalid & ~axil_wready) | (~data_done & rd[4]);
               axil_wdata <= axil_wvalid & ~axil_wready ? axil_wdata : rd;
               axil_awaddr <= axil_awaddr + (axil_awvalid & axil_awready ? 3'd4 : 3'd0);
               addr_done <= (axil_awvalid & axil_awready) | addr_done;
               data_done <= (axil_wvalid & axil_wready) | data_done;
            end
         end
      end
   endtask

   logic [15:0] sessions[0:SESSION_NUM-1];
   logic [SESSION_NUM-1:0] session_valids;

   task read_reg(input [11:0] addr, output logic [31:0] data);
      @(posedge clk) begin
         axil_araddr <= addr;
         axil_arvalid <= 1'b1;
      end
      while (1'b1) @(posedge clk) begin
         axil_arvalid <= axil_arvalid & ~axil_arready;
         if (axil_arvalid & axil_arready) break;
      end
      while (1'b1) @(posedge clk) begin
         if (axil_rvalid & axil_rready) begin
            data <= axil_rdata;
            break;
         end
      end
      @(posedge clk) $display("read reg[%h]: %h", addr, data);
   endtask

   task check_reg(input [11:0] addr, input [31:0] mask, input [31:0] expects);
      logic [31:0] data;
      read_reg(addr, data);
      if ((data & mask) !== (expects & mask)) begin
         $error("check reg [%h]: %h %h (%h)", addr, data, expects, mask);
      end
   endtask

   task static connects();
      int          i = 0;
      int          j = 0;
      logic [95:0] open_data;
      logic [11:0] open_addr[0:2] = {12'h104, 12'h108, 12'h100};
      logic [31:0] rdata;

      while (i < SESSION_NUM) begin
         open_data = {32'd1, 16'd0, rd[31:16], 16'hc0a8, rd[7:0], rd[15:8]};
         for (j = 0; j<3; j++) begin
            @(posedge clk) begin
               axil_awaddr <= open_addr[j];
               axil_wdata <= open_data[31:0];
               axil_awvalid <= 1'b1;
               axil_wvalid <= 1'b1;
               open_data <= open_data >> 32;
            end
            while (1'b1) @(posedge clk) begin
               axil_awvalid <= axil_awvalid & ~axil_awready;
               axil_wvalid <= axil_wvalid & ~axil_wready;
               if (~axil_awvalid & ~axil_wvalid) break;
            end
         end
         while (1'b1) @(posedge clk) begin
            if (axis_tcp_rsp_tvalid & axis_tcp_rsp_tready & axis_tcp_rsp_tdata[80]) begin
               sessions[i] <= axis_tcp_rsp_tdata[15:0];
               session_valids[i] <= 1'b1;
               $display("%d [%2h]: connected: %h", $time, i, axis_tcp_rsp_tdata[15:0]);
               i = i+1;
               break;
            end
         end
         check_reg(12'h110, 32'h1, 32'h1);
         read_reg(12'h114, rdata);
         read_reg(12'h118, rdata);
         read_reg(12'h11c, rdata);
         @(posedge clk) begin
            axil_awaddr <= 12'h110;
            axil_wdata <= 32'd1;
            axil_awvalid <= 1'b1;
            axil_wvalid <= 1'b1;
         end
         while (1'b1) @(posedge clk) begin
            axil_awvalid <= axil_awvalid & ~axil_awready;
            axil_wvalid <= axil_wvalid & ~axil_wready;
            if (~axil_awvalid & ~axil_wvalid) break;
         end
      end
      $display("connect done");
   endtask

   task static listen_accepts();
      int          i = 0;
      int          j = 0;
      logic [159:0] listen_data;
      logic [11:0] listen_addr[0:4] = {12'h134, 12'h130, 12'h140, 12'h140, 12'h140};
      logic [143:0] ht_upd_data;
      logic [15:0]  self_port;

      listen_data = {32'd1, 32'd1, 32'd1, 32'd1, 16'd0, rd[15:0]};
      self_port = rd[15:0];
      for (j = 0; j<5; j++) begin
         @(posedge clk) begin
            axil_awaddr <= listen_addr[j];
            axil_wdata <= listen_data[31:0];
            axil_awvalid <= 1'b1;
            axil_wvalid <= 1'b1;
            listen_data <= listen_data >> 32;
         end
         while (1'b1) @(posedge clk) begin
            axil_awvalid <= axil_awvalid & ~axil_awready;
            axil_wvalid <= axil_wvalid & ~axil_wready;
            if (~axil_awvalid & ~axil_wvalid) break;
         end
      end
      while (i < SESSION_NUM) begin
         ht_upd_data = {32'd0, rd[15:0], rd[31:16], self_port, rd[8+:16], 16'ha8c0, 32'h0};
         @(posedge clk) begin
            ht_upd_tdata <= ht_upd_data;
            ht_upd_tvalid <= 1'b1;
         end
         while (1'b1) @(posedge clk) begin
            ht_upd_tvalid <= ht_upd_tvalid & ~ht_upd_tready;
            if (~ht_upd_tvalid) break;
         end
         while (1'b1) @(posedge clk) begin
            if (axis_tcp_rsp_tvalid & axis_tcp_rsp_tready & axis_tcp_rsp_tdata[80]) begin
               sessions[i] <= axis_tcp_rsp_tdata[15:0];
               session_valids[i] <= 1'b1;
               $display("%d [%2h]: connected: %h", $time, i, axis_tcp_rsp_tdata[15:0]);
               i = i+1;
               break;
            end
         end
         @(posedge clk) begin
            axil_awaddr <= 12'h160;
            axil_wdata <= 32'd1;
            axil_awvalid <= 1'b1;
            axil_wvalid <= 1'b1;
         end
         while (1'b1) @(posedge clk) begin
            axil_awvalid <= axil_awvalid & ~axil_awready;
            axil_wvalid <= axil_wvalid & ~axil_wready;
            if (~axil_awvalid & ~axil_wvalid) break;
         end
      end
   endtask

   task static closes();
      int          i = 0;
      int          j = 0;
      logic [63:0] close_data;
      logic [11:0] close_addr[0:1] = {12'h124, 12'h120};

      while (i < SESSION_NUM) begin
         if (~session_valids[i]) begin
            i++;
            continue;
         end
         close_data = {32'd1, 16'd0, sessions[i]};
         for (j = 0; j<2; j++) begin
            @(posedge clk) begin
               axil_awaddr <= close_addr[j];
               axil_wdata <= close_data[31:0];
               axil_awvalid <= 1'b1;
               axil_wvalid <= 1'b1;
               close_data <= close_data >> 32;
            end
            while (1'b1) @(posedge clk) begin
               axil_awvalid <= axil_awvalid & ~axil_awready;
               axil_wvalid <= axil_wvalid & ~axil_wready;
               if (~axil_awvalid & ~axil_wvalid) break;
            end
         end
         $display("%d [%2h]: closed: %h", $time, i, sessions[i]);
         i++;
      end
   endtask

   reg [15:0] rx_notify_sizes[0:255];
   reg [15:0] rx_notify_sessions[0:255];
   reg [7:0]  rx_notify_wpos, rx_notify_rpos;
   reg [7:0]  rx_notify_cpos, rx_notify_epos;
   reg [DW-1:0] rx_data_saved[0:255];
   reg [KW-1:0] rx_keep_saved[0:255];
   reg [CH_NUM_LOG-1:0] rx_ch_saved[0:255];
   reg          rx_last_saved[0:255];
   reg [7:0]  rx_data_wpos, rx_data_rpos;

   initial begin
      rx_notify_wpos = 'd0;
      rx_notify_rpos = 'd0;
      rx_notify_cpos = 'd0;
      rx_notify_epos = 'd0;
      rx_data_wpos = 'd0;
      rx_data_rpos = 'd0;
   end

   always @(posedge clk) begin
      if (resetn) begin
         if (rx_req_tvalid & rx_req_tready) begin
            if (rx_req_tdata[31:16] !== rx_notify_sizes[rx_notify_cpos] ||
                rx_req_tdata[15:0] !== rx_notify_sessions[rx_notify_cpos]) begin
               $error("%d: [%2h] rx req %h %h, %h %h", $time, rx_req_tdata[15:0],
                      rx_req_tdata[31:16], rx_notify_sizes[rx_notify_cpos],
                      rx_req_tdata[15:0], rx_notify_sessions[rx_notify_cpos]);
            end
            rx_notify_cpos <= rx_notify_cpos + 1'b1;
         end
         if ((rx_notify_cpos != rx_notify_epos) && (~rx_rsp_tvalid || rx_rsp_tready)) begin
            if (RX_RSP_BITS > 0 ? &rd[7+:RX_RSP_BITS_MOD] : 1'b1) begin
               rx_rsp_tdata <= rx_notify_sessions[rx_notify_epos];
               rx_rsp_tvalid <= 1'b1;
               rx_notify_epos <= rx_notify_epos + 1'b1;
            end else begin
               rx_rsp_tvalid <= 1'b0;
            end
         end else begin
            rx_rsp_tvalid <= rx_rsp_tvalid & ~rx_rsp_tready;
         end
      end
   end

   always @(posedge clk) begin
      if (resetn) begin
         if (rx_out_tvalid & rx_out_tready) begin
            if (rx_out_tdata !== rx_data_saved[rx_data_rpos] ||
                rx_out_tkeep !== rx_keep_saved[rx_data_rpos] ||
                rx_out_tlast !== rx_last_saved[rx_data_rpos] ||
                rx_out_tuser !== rx_ch_saved[rx_data_rpos]) begin
               $error("%d: [%2h] rx data %h %h, %h %h, %h %h, %h %h", $time, rx_out_tuser,
                      rx_out_tdata, rx_data_saved[rx_data_rpos],
                      rx_out_tkeep, rx_keep_saved[rx_data_rpos],
                      rx_out_tlast, rx_last_saved[rx_data_rpos],
                      rx_out_tuser, rx_ch_saved[rx_data_rpos]);
            end
            rx_data_rpos <= rx_data_rpos + 1'b1;
         end
      end
   end

   task static rx_notification();
      logic [87:0] notification_data;
      logic [15:0] session_id;
      int          notify_count = 0;
      int          session_idx;
      while (notify_count < RX_NOTIFY_MAX) begin
         session_idx = rd % SESSION_NUM;
         notification_data = {8'd0, 48'd0, rd[15:0], sessions[session_idx]};
         @(posedge clk) begin
            notification_tdata <= notification_data;
            if ((RX_RSP_BITS > 0 ? &rd[24+:RX_RSP_BITS_MOD] : 1'b1) &&
                ((rx_notify_wpos + 1) & 255) != rx_notify_rpos) begin
               notification_tvalid <= 1'b1;
               $display("%d [%2h]: rx notify %h %h", $time, session_idx,
                        notification_data[31:16], notification_data[15:0]);
               rx_notify_sizes[rx_notify_wpos] <= notification_data[31:16];
               rx_notify_sessions[rx_notify_wpos] <= notification_data[15:0];
               rx_notify_wpos <= rx_notify_wpos + 1'b1;
               notify_count++;
            end
         end
         while (1'b1) @(posedge clk) begin
            notification_tvalid <= notification_tvalid & ~notification_tready;
            if (~notification_tvalid) break;
         end
      end
   endtask

   task static rx_data_generator();
      int notify_count = 0;
      logic [DW-1:0] data;
      logic [KW-1:0] keep;
      logic [15:0]   size = 0;
      logic          valid = 0;
      logic          last;
      logic [CH_NUM_LOG-1:0] ch;

      while (notify_count < RX_NOTIFY_MAX || valid || rx_in_tvalid) @(posedge clk) begin
         if (size == 0 && rx_notify_cpos != rx_notify_rpos) begin
            size = rx_notify_sizes[rx_notify_rpos];
            ch = rx_notify_sessions[rx_notify_rpos];
            rx_notify_rpos <= rx_notify_rpos + 1'b1;
            if (~|size) notify_count++;
         end
         if (|size && (~rx_in_tvalid || rx_in_tready)) begin
            valid = RX_DATA_BITS > 0 ? &rd[17+:RX_DATA_BITS_MOD] : 1'b1;
            if (valid) begin
               for (int i=0; i<KW; i++) begin
                  if (i < size) begin
                     keep[i] = 1'b1;
                     data[i*8+:8] = (rd >> ((i&3)*8)) ^ i;
                  end else begin
                     keep[i] = 1'b0;
                     data[i*8+:8] = 8'd0;
                  end
               end
               last = size <= KW;
               size = last ? 'd0 : size - KW;
               rx_in_tdata <= data;
               rx_in_tkeep <= keep;
               rx_in_tlast <= last;
               rx_data_saved[rx_data_wpos] <= data;
               rx_keep_saved[rx_data_wpos] <= keep;
               rx_last_saved[rx_data_wpos] <= last;
               rx_ch_saved[rx_data_wpos] <= ch;
               rx_data_wpos <= rx_data_wpos + 1'b1;
               if (last) notify_count++;
            end
            rx_in_tvalid <= valid;
         end else begin
            rx_in_tvalid <= rx_in_tvalid & ~rx_in_tready;
            valid = 1'b0;
         end
      end
   endtask

   task static tx_cmd_rsp_handler();
      logic [29:0] tx_vacants_core[0:SESSION_NUM-1];
      logic [31:0] tx_vacants[0:SESSION_NUM-1];
      logic [15:0] tx_length[0:SESSION_NUM-1][0:255];
      logic [7:0]  tx_length_wpos[0:SESSION_NUM-1];
      logic [7:0]  tx_length_rpos[0:SESSION_NUM-1];

      logic [1:0]  error = 0;
      logic [15:0] session_id = 0;
      logic [15:0] length = 0;
      logic [15:0] length_core = 0;
      logic [29:0] remain = 0;
      int          session_idx = 0;
      int          session_idx_rsp = 0;
      int          session_idx_tx = 0;
      int          session_idx_tx_rsp = 0;
      int          transfer_count = 0;
      int          i;
      logic        is_tx_rsp = 1'b0;
      for (i=0; i<SESSION_NUM; i++) begin
         tx_length_wpos[i] = 8'd0;
         tx_length_rpos[i] = 8'd0;
      end
      while (transfer_count < TX_TRANSFER_MAX || ~is_tx_rsp) @(posedge clk) begin
         if ((~axis_tcp_cmd_tvalid || axis_tcp_cmd_tready) & ~is_tx_rsp) begin
            length = rd[15:0];
            if (TX_CMD_BITS > 0 ? &rd[15+:TX_CMD_BITS_MOD] : 1'b1) begin
               axis_tcp_cmd_tdata <= {length, sessions[session_idx]};
               axis_tcp_cmd_tvalid <= 1'b1;
               $display("%d [%2h]: tx length: %h vacant %h", $time, session_idx, length, tx_vacants[session_idx]);
               session_idx <= (session_idx + 1) % SESSION_NUM;
               is_tx_rsp = 1'b1;
               transfer_count++;
            end else begin
               axis_tcp_cmd_tvalid <= axis_tcp_cmd_tvalid & ~axis_tcp_cmd_tready;
            end
         end else begin
            axis_tcp_cmd_tvalid <= axis_tcp_cmd_tvalid & ~axis_tcp_cmd_tready;
         end
         if (axis_tcp_rsp_tvalid & axis_tcp_rsp_tready & ~|axis_tcp_rsp_tdata[82:80]) begin
            session_idx_rsp = -1;
            for (i=0; i<SESSION_NUM; i++) begin
               if (sessions[i] == axis_tcp_rsp_tdata[15:0]) begin
                  session_idx_rsp = i;
                  break;
               end
            end
            if (session_idx_rsp >= 0) begin
               is_tx_rsp = 1'b0;
            end
         end
         if (tx_req_tvalid & tx_req_tready) begin
            session_idx_tx = -1;
            for (i=0; i<SESSION_NUM; i++) begin
               if (sessions[i] == tx_req_tdata[15:0]) begin
                  session_idx_tx = i;
                  break;
               end
            end
            if (session_idx_tx >= 0) begin
               tx_length[session_idx_tx][tx_length_wpos[session_idx_tx]] <= tx_req_tdata[31:16];
               tx_length_wpos[session_idx_tx] <= tx_length_wpos[session_idx_tx] + 1'b1;
               $display("%d [%2h]: tx req[%3d]: %h", $time, session_idx_tx, tx_length_wpos[session_idx_tx], tx_req_tdata[31:16]);
            end
         end
         if ((~tx_rsp_tvalid || tx_rsp_tready) && (TX_RSP_BITS > 0 ? &rd[16+:TX_RSP_BITS_MOD] : 1'b1)) begin
            if (tx_length_wpos[session_idx_tx_rsp] != tx_length_rpos[session_idx_tx_rsp]) begin
               length_core = tx_length[session_idx_tx_rsp][tx_length_rpos[session_idx_tx_rsp]];
               error = rd[3] ? 2'd0 : 2'd2;
               remain = rd;
               tx_rsp_tdata <= {error, remain, length_core, sessions[session_idx_tx_rsp]};
               tx_rsp_tvalid <= 1'b1;
               session_idx_tx_rsp <= (session_idx_tx_rsp + 1) % SESSION_NUM;
               tx_length_rpos[session_idx_tx_rsp] <= tx_length_rpos[session_idx_tx_rsp] + 1'b1;
               $display("%d [%2h]: tx rsp: size %h status %h", $time, session_idx_tx_rsp, length_core, error);
            end else begin
               tx_rsp_tvalid <= 1'b0;
            end
         end else begin
            tx_rsp_tvalid <= tx_rsp_tvalid & ~tx_rsp_tready;
         end
      end
   endtask

   task static notifications();
      @(posedge clk) begin
         notification_tdata <= {rd,rd,rd};
         notification_tvalid <= 1'b1;
         if (|rd[31:16]) begin
            rx_notify_sizes[rx_notify_wpos] <= rd[31:16];
            rx_notify_sessions[rx_notify_wpos] <= rd[15:0];
            rx_notify_wpos <= rx_notify_wpos + 1'b1;
         end
      end
      while (1'b1) begin
         @(posedge clk) begin
            notification_tvalid <= notification_tvalid & ~notification_tready;
         end
         if (~notification_tvalid) break;
      end
      @(posedge clk) begin
         listen_status_tdata <= {rd};
         listen_status_tvalid <= 1'b1;
      end
      while (1'b1) begin
         @(posedge clk) begin
            listen_status_tvalid <= listen_status_tvalid & ~listen_status_tready;
         end
         if (~listen_status_tvalid) break;
      end
      @(posedge clk) begin
         open_status_tdata <= {rd,rd,rd};
         open_status_tvalid <= 1'b1;
      end
      while (1'b1) begin
         @(posedge clk) begin
            open_status_tvalid <= open_status_tvalid & ~open_status_tready;
         end
         if (~open_status_tvalid) break;
      end
      @(posedge clk) begin
         axil_awaddr <= 12'h150;
         axil_wdata <= 32'd1;
         axil_awvalid <= 1'b1;
         axil_wvalid <= 1'b1;
      end
      while (1'b1) begin
         @(posedge clk) begin
            axil_awvalid <= axil_awvalid & ~axil_awready;
            axil_wvalid <= axil_wvalid & ~axil_wready;
         end
         if (~axil_awvalid & ~axil_wvalid) break;
      end
      for (int i=0; i<10; i++) @(posedge clk);

   endtask

   initial begin
      while (resetn !== 1'b1) @(posedge clk);
      case (MODE)
        0: begin
           reg_read();
        end
        1: begin
           reg_write();
        end
        2: begin
           notifications();
        end
        3: begin
           connects();
           closes();
        end
        4: begin
           listen_accepts();
           closes();
        end
        5: begin
           connects();
           fork
              begin
                 rx_notification();
              end
              begin
                 rx_data_generator();
              end
           join
           closes();
        end
        6: begin
           listen_accepts();
           fork
              begin
                 rx_notification();
              end
              begin
                 rx_data_generator();
              end
           join
           closes();
        end
        7: begin
           connects();
           tx_cmd_rsp_handler();
           closes();
        end
        8: begin
           listen_accepts();
           tx_cmd_rsp_handler();
           closes();
        end
        default: begin
           $fatal(2, "unexpected MODE: %d", MODE);
        end
      endcase
      $finish();
   end
endmodule

module test_reg_read();

   tb_network_ip_ctrl tb();

endmodule

module test_reg_write();

   tb_network_ip_ctrl #(
       .MODE ( 1 )
   ) tb();

endmodule

module test_notifications();

   tb_network_ip_ctrl #(
       .MODE ( 2 )
   ) tb();

endmodule

module test_open_close();

   tb_network_ip_ctrl #(
       .MODE ( 3 )
   ) tb();

endmodule

module test_listen_close();

   tb_network_ip_ctrl #(
       .MODE ( 4 )
   ) tb();

endmodule

module test_open_rx();

   tb_network_ip_ctrl #(
       .MODE ( 5 )
   ) tb();

endmodule

module test_listen_rx();

   tb_network_ip_ctrl #(
       .MODE ( 6 )
   ) tb();

endmodule

module test_open_tx();

   tb_network_ip_ctrl #(
       .MODE ( 7 )
   ) tb();

endmodule

module test_listen_tx();

   tb_network_ip_ctrl #(
       .MODE ( 8 )
   ) tb();

endmodule
