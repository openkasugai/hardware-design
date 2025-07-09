/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_toe_ctrl_regs #(
    parameter AW = 16,
    parameter CH_NUM_LOG = 4,
    parameter SESSION_NUM_LOG = 6,
    parameter MODE = 0
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

   reg [AW-1:0]                             axil_araddr;
   reg                                      axil_arvalid;
   wire                                     axil_arready;
   wire [31:0]                              axil_rdata;
   wire [1:0]                               axil_rresp;
   wire                                     axil_rvalid;
   reg                                      axil_rready;
   reg [AW-1:0]                             axil_awaddr;
   reg                                      axil_awvalid;
   wire                                     axil_awready;
   reg [31:0]                               axil_wdata;
   reg                                      axil_wvalid;
   wire                                     axil_wready;
   wire [1:0]                               axil_bresp;
   wire                                     axil_bvalid;
   reg                                      axil_bready;

   wire [(1<<CH_NUM_LOG)-1:0]               tx_ch_enables;
   wire [(1<<CH_NUM_LOG)-1:0]               tx_ch_valids;
   wire [(1<<CH_NUM_LOG)-1:0]               tx_ch_actives;
   wire [(1<<CH_NUM_LOG)-1:0]               tx_ch_readys;
   wire [(SESSION_NUM_LOG<<CH_NUM_LOG)-1:0] tx_ch_session_ids;
   wire [(32<<CH_NUM_LOG)-1:0]              tx_ch_frame_sizes;
   wire [(16<<CH_NUM_LOG)-1:0]              tx_ch_credit_max;
   wire [(16<<CH_NUM_LOG)-1:0]              tx_ch_credit_cur;
   wire [(32<<CH_NUM_LOG)-1:0]              tx_ch_ip_bases;
   wire [(32<<CH_NUM_LOG)-1:0]              tx_ch_ip_masks;
   wire [(16<<CH_NUM_LOG)-1:0]              tx_ch_port_bases;
   wire [(16<<CH_NUM_LOG)-1:0]              tx_ch_port_masks;
   wire                                     invalidate_activate;

   wire [(1<<CH_NUM_LOG)-1:0]               rx_ch_enables;
   wire [(1<<CH_NUM_LOG)-1:0]               rx_ch_valids;
   wire [(1<<CH_NUM_LOG)-1:0]               rx_ch_activates;
   wire [(1<<CH_NUM_LOG)-1:0]               rx_ch_actives;
   wire [(1<<CH_NUM_LOG)-1:0]               rx_ch_readys;
   wire [(SESSION_NUM_LOG<<CH_NUM_LOG)-1:0] rx_ch_session_ids;
   wire [(32<<CH_NUM_LOG)-1:0]              rx_ch_frame_sizes;
   wire [(16<<CH_NUM_LOG)-1:0]              rx_ch_credit_max;
   wire [(16<<CH_NUM_LOG)-1:0]              rx_ch_credit_cur;
   wire [(32<<CH_NUM_LOG)-1:0]              rx_ch_ip_bases;
   wire [(32<<CH_NUM_LOG)-1:0]              rx_ch_ip_masks;
   wire [(16<<CH_NUM_LOG)-1:0]              rx_ch_port_bases;
   wire [(16<<CH_NUM_LOG)-1:0]              rx_ch_port_masks;

   reg [SESSION_NUM_LOG-1:0]                activate_done_session_id;
   reg                                      activate_done;

   reg [SESSION_NUM_LOG-1:0]                connected_session_id;
   reg [31:0]                               connected_ip;
   reg [15:0]                               connected_port;
   reg                                      connected_valid;
   wire                                     connected_out_found;
   wire                                     connected_out_valid;

   reg [SESSION_NUM_LOG-1:0]                close_session_id;
   reg                                      close_valid;

   reg [SESSION_NUM_LOG-1:0]                find_ch_session_id;
   reg                                      find_ch_valid;
   wire [CH_NUM_LOG-1:0]                    find_ch_id;
   wire                                     find_ch_id_tx_valid;
   wire                                     find_ch_id_rx_valid;
   wire                                     find_ch_id_invalid;

   reg [15:0]                               cp_config_credit_max;
   reg [31:0]                               cp_config_frame_size;
   reg [SESSION_NUM_LOG-1:0]                cp_config_session_id;
   reg                                      cp_config_valid;

   reg [SESSION_NUM_LOG-1:0]                tx_credit_inc_session_id;
   reg                                      tx_credit_inc;
   reg [SESSION_NUM_LOG-1:0]                rx_credit_inc_session_id;
   reg                                      rx_credit_inc;
   reg [SESSION_NUM_LOG-1:0]                tx_credit_dec_session_id;
   reg                                      tx_credit_dec;
   reg [SESSION_NUM_LOG-1:0]                rx_credit_dec_session_id;
   reg                                      rx_credit_dec;

   wire                                      clk, resetn;
   wire [31:0]                               rd;

   clk_reset clk_reset (
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
   );

   toe_ctrl_regs #(
       .AW ( AW ),
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .SESSION_NUM_LOG ( SESSION_NUM_LOG )
   ) dut (
       .*
   );

   initial begin
      axil_arvalid = 1'b0;
      axil_rready = 1'b1;
      axil_awvalid = 1'b0;
      axil_wvalid = 1'b0;
      axil_bready = 1'b1;
      activate_done = 1'b0;
      connected_valid = 1'b0;
      close_valid = 1'b0;
      find_ch_valid = 1'b0;
      cp_config_valid = 1'b0;
      tx_credit_inc = 1'b0;
      tx_credit_dec = 1'b0;
      rx_credit_inc = 1'b0;
      rx_credit_dec = 1'b0;
   end

   reg [SESSION_NUM_LOG-1:0] tx_sessions[0:CH_NUM-1];
   reg [SESSION_NUM_LOG-1:0] rx_sessions[0:CH_NUM-1];
   reg [CH_NUM-1:0]          tx_enables;
   reg [CH_NUM-1:0]          rx_enables;
   reg [CH_NUM-1:0]          tx_valids;
   reg [CH_NUM-1:0]          rx_valids;
   reg [CH_NUM-1:0]          rx_activates;
   reg [31:0]                tx_ips[0:CH_NUM-1], rx_ips[0:CH_NUM-1];
   reg [31:0]                tx_ip_masks[0:CH_NUM-1], rx_ip_masks[0:CH_NUM-1];
   reg [15:0]                tx_ports[0:CH_NUM-1], rx_ports[0:CH_NUM-1];
   reg [15:0]                tx_port_masks[0:CH_NUM-1], rx_port_masks[0:CH_NUM-1];

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
      for (int dir=0; dir<2; dir++) begin
         for (int ch=0; ch<CH_NUM; ch++) begin
            for (int i=2; i<11; i++) begin
               awaddr = (dir == 0 ? TX_BASE : RX_BASE) + CH_SIZE * ch + (i % 10) * 4;
               wdata = rd;
               casex(i%10)
                  0: edata = {27'd0, wdata[4] && wdata[0] && dir== 1, 3'd0, wdata[0]};
                  1: edata = 32'd0;
                  2: edata = 'd0;// | wdata[SESSION_NUM_LOG-1:0];
                  3: edata = dir==1 ? wdata : 32'd0;
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
      for (int i=0; i<CH_NUM; i++) begin
         $display("%d: [%2h] rx: %h %h %h(%h) %h(%h), tx: %h %h %h(%h) %h(%h)", $time, i,
                  rx_enables[i], rx_sessions[i], rx_ips[i], rx_ip_masks[i], rx_ports[i], rx_port_masks[i],
                  tx_enables[i], tx_sessions[i], tx_ips[i], tx_ip_masks[i], tx_ports[i], tx_port_masks[i]);
      end
      while (~is_tx || ch < CH_NUM || valid || inflight) @(posedge clk) begin
         if (~inflight && ~connected_valid) begin
            session_id = is_tx ? tx_sessions[ch] : rx_sessions[ch];
            ip = is_tx ? tx_ips[ch] : rx_ips[ch];
            ip_mask = is_tx ? tx_ip_masks[ch] : rx_ip_masks[ch];
            port = is_tx ? tx_ports[ch] : rx_ports[ch];
            port_mask = is_tx ? tx_port_masks[ch] : rx_port_masks[ch];
            ip = ip ^ (~ip_mask);
            port = port ^ (~port_mask);
            valid = is_tx ? tx_enables[ch] : rx_enables[ch];
            if (valid) begin
               connected_ip <= ip;
               connected_port <= port;
               connected_session_id <= session_id;
            end else begin
               ch++;
               if (ch==CH_NUM && ~is_tx) begin
                  ch = 0;
                  is_tx = 1;
               end
               continue;
            end
            connected_valid <= valid & rd[12];
            inflight <= valid & rd[12];
         end else begin
            if (connected_out_valid) begin
               ch++;
               if (ch==CH_NUM && ~is_tx) begin
                  ch = 0;
                  is_tx = 1;
               end
               inflight <= 1'b0;
               if (!connected_out_found) begin
                  $error("%d: not found channel: %h", $time, connected_session_id);
               end
            end
            connected_valid <= 1'b0;
         end
      end
   endtask

   task static activate_rx;
      logic [1:0] stat = 0;
      logic [AW-1:0] araddr;
      logic [31:0]   rdata;
      for (int ch=0; ch<CH_NUM; ch++) begin
         if (~rx_valids[ch] | ~rx_activates[ch]) continue;
         @(posedge clk) begin
            activate_done_session_id <= rx_sessions[ch];
            activate_done <= 1'b1;
         end
         @(posedge clk) activate_done <= 1'b0;
         for (int i=0; i<3; i++) begin
            while (~&stat) @(posedge clk) begin
               araddr = RX_BASE + CH_SIZE * ch + i * 4;
               rdata = i==0 ? 32'd1 :
                       i==1 ? 32'h111 : 32'd0 | rx_sessions[ch];
               if (~stat[0] && rd[5]) begin
                  axil_araddr <= araddr;
                  axil_arvalid <= 1'b1;
                  stat[0] <= 1'b1;
               end else begin
                  axil_arvalid <= axil_arvalid & ~axil_arready;
               end
               axil_rready <= rd[6];
               if (axil_rvalid & axil_rready) begin
                  if (axil_rdata !== rdata) begin
                     $error("%d: rx activate[%2h][%3h][%h]: %h %h", $time, ch, araddr, i, axil_rdata, i==0 ? 32'd1 : 32'h11);
                  end
                  stat[1] <= 1'b1;
               end
            end
            @(posedge clk) stat <= 'd0;
            @(posedge clk);
         end
      end
   endtask

   task static activate_tx;
      logic [15:0] credit_max;
      logic [31:0] frame_size;
      logic [1:0] stat = 0;
      logic [AW-1:0] araddr;
      logic [31:0]   rdata;
      for (int ch=0; ch<CH_NUM; ch++) begin
         if (~tx_enables[ch]) continue;
         credit_max = rd[10+:16];
         frame_size = rd ^ 32'h100f00ba;
         @(posedge clk) begin
            cp_config_credit_max <= credit_max;
            cp_config_frame_size <= frame_size;
            cp_config_session_id <= tx_sessions[ch];
            cp_config_valid <= 1'b1;
         end
         @(posedge clk) cp_config_valid <= 1'b0;
         for (int i=1; i<6; i++) begin
            while (~&stat) @(posedge clk) begin
               araddr = TX_BASE + CH_SIZE * ch + i * 4;
               rdata = i==1 ? {23'd0, 1'b1, 3'd0, 1'b1, 3'd0, tx_enables[ch]} :
                       i==2 ? 32'd0 | tx_sessions[ch] :
                       i==3 ? frame_size :
                       i==4 ? {16'd0, credit_max} : 32'd0;
               if (~stat[0] && rd[5]) begin
                  axil_araddr <= araddr;
                  axil_arvalid <= 1'b1;
                  stat[0] <= 1'b1;
               end else begin
                  axil_arvalid <= axil_arvalid & ~axil_arready;
               end
               axil_rready <= rd[6];
               if (axil_rvalid & axil_rready) begin
                  if (axil_rdata !== rdata) begin
                     $error("%d: tx activate[%2h][%3h]: %h %h", $time, ch, araddr, axil_rdata, rdata);
                  end
                  stat[1] <= 1'b1;
               end
            end
            @(posedge clk) stat <= 'd0;
            @(posedge clk);
         end
      end
   endtask

   task static channel_invalidate;
      logic [SESSION_NUM_LOG-1:0] session_id;
      logic [CH_NUM_LOG:0]        ch = 0;
      logic                       is_tx = 0;
      logic                       valid = 0;
      logic [AW-1:0]              awaddr;
      logic [AW-1:0]              araddr;
      logic [2:0]                 stat = 0;
      while (~is_tx || ch < CH_NUM) @(posedge clk) begin
         if ((is_tx && tx_enables[ch]) || (~is_tx && rx_enables[ch])) begin
            valid = 1'b0;
            if (MODE == 1) begin
               // close signal
               if (~close_valid) begin
                  session_id = is_tx ? tx_sessions[ch] : rx_sessions[ch];
                  close_valid <= 1'b1;
                  close_session_id <= session_id;
                  valid = 1'b1;
               end else begin
                  valid = 1'b0;
                  close_valid <= 1'b0;
               end
            end else begin
               // reg write
               if (~stat[0] && (~axil_awvalid || axil_awready)) begin
                  awaddr = (is_tx ? TX_BASE : RX_BASE) + ch * CH_SIZE;
                  axil_awaddr <= awaddr;
                  axil_awvalid <= 1'b1;
                  stat[0] <= 1'b1;
               end else begin
                  axil_awvalid <= axil_awvalid & ~axil_awready;
               end
               if (~stat[1] && (~axil_wvalid || axil_wready)) begin
                  axil_wdata <= 32'd0;
                  axil_wvalid <= 1'b1;
                  stat[1] <= 1'b1;
               end else begin
                  axil_wvalid <= axil_wvalid & ~axil_wready;
               end
               if (axil_bvalid & axil_bready) begin
                  stat[2] <= 1'b1;
               end
               if (&stat) begin
                  valid = 1'b1;
                  stat <= 'd0;
               end
            end
         end else begin
            close_valid <= 1'b0;
            axil_awvalid <= axil_awvalid & ~axil_awready;
            axil_wvalid <= axil_wvalid & ~axil_wready;
            valid = 1'b1;
         end
         if (valid) begin
            ch = ch + 1;
            if (ch == CH_NUM && ~is_tx) begin
               ch = 0;
               is_tx = 1;
            end
         end
         axil_bready <= &rd[3+:2];
      end
      is_tx = 0;
      while (~is_tx || ch < CH_NUM) @(posedge clk) begin
         // reg read
         if (~stat[0] && (~axil_arvalid || axil_arready)) begin
            araddr = (is_tx ? TX_BASE : RX_BASE) + ch * CH_SIZE + 4;
            axil_araddr <= araddr;
            axil_arvalid <= 1'b1;
            stat[0] <= 1'b1;
         end else begin
            axil_arvalid <= axil_arvalid & ~axil_arready;
         end
         if (axil_rvalid & axil_rready) begin
            stat[1] <= 1'b1;
            if (axil_rdata !== 32'd0) begin
               $error("%d: [%2h] %s not invalidated", $time, ch, is_tx ? "tx" : "rx");
            end
         end
         if (&stat[1:0]) begin
            ch = ch + 1;
            if (ch == CH_NUM && ~is_tx) begin
               ch = 0;
               is_tx = 1;
            end
            stat <= 'd0;
         end
         axil_rready <= &rd[5+:2];
      end
   endtask

   initial begin
      @(posedge clk);
      while (~resetn) @(posedge clk);

      case (MODE)
        0: begin
           read_write_configs;
        end
        default: begin
           read_write_configs;
           channel_validate;
           activate_rx;
           activate_tx;
           channel_invalidate;
        end
      endcase

      $finish;
   end

endmodule

module test_toe_ctrl_regs_read_write_simple;
   tb_toe_ctrl_regs tb();
endmodule

module test_toe_ctrl_regs_read_write_activates;
   tb_toe_ctrl_regs #(
       .MODE ( 1 )
   ) tb ();
endmodule

module test_toe_ctrl_regs_read_write_activates2;
   tb_toe_ctrl_regs #(
       .MODE ( 2 )
   ) tb ();
endmodule
