/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module toe_ctrl_regs #(
    parameter AW = 16,
    parameter CH_NUM_LOG = 4,
    parameter SESSION_NUM_LOG = 6
    ) (
    input [AW-1:0]                             axil_araddr,
    input                                      axil_arvalid,
    output                                     axil_arready,
    output [31:0]                              axil_rdata,
    output [1:0]                               axil_rresp,
    output                                     axil_rvalid,
    input                                      axil_rready,
    input [AW-1:0]                             axil_awaddr,
    input                                      axil_awvalid,
    output                                     axil_awready,
    input [31:0]                               axil_wdata,
    input                                      axil_wvalid,
    output                                     axil_wready,
    output [1:0]                               axil_bresp,
    output                                     axil_bvalid,
    input                                      axil_bready,

    output [(1<<CH_NUM_LOG)-1:0]               tx_ch_enables,
    output [(1<<CH_NUM_LOG)-1:0]               tx_ch_valids,
    output [(1<<CH_NUM_LOG)-1:0]               tx_ch_actives,
    output [(1<<CH_NUM_LOG)-1:0]               tx_ch_readys,
    output [(SESSION_NUM_LOG<<CH_NUM_LOG)-1:0] tx_ch_session_ids,
    output [(32<<CH_NUM_LOG)-1:0]              tx_ch_frame_sizes,
    output [(16<<CH_NUM_LOG)-1:0]              tx_ch_credit_max,
    output [(16<<CH_NUM_LOG)-1:0]              tx_ch_credit_cur,
    output [(32<<CH_NUM_LOG)-1:0]              tx_ch_ip_bases,
    output [(32<<CH_NUM_LOG)-1:0]              tx_ch_ip_masks,
    output [(16<<CH_NUM_LOG)-1:0]              tx_ch_port_bases,
    output [(16<<CH_NUM_LOG)-1:0]              tx_ch_port_masks,
    output                                     invalidate_activate,

    output [(1<<CH_NUM_LOG)-1:0]               rx_ch_enables,
    output [(1<<CH_NUM_LOG)-1:0]               rx_ch_valids,
    output [(1<<CH_NUM_LOG)-1:0]               rx_ch_activates,
    output [(1<<CH_NUM_LOG)-1:0]               rx_ch_actives,
    output [(1<<CH_NUM_LOG)-1:0]               rx_ch_readys,
    output [(SESSION_NUM_LOG<<CH_NUM_LOG)-1:0] rx_ch_session_ids,
    output [(32<<CH_NUM_LOG)-1:0]              rx_ch_frame_sizes,
    output [(16<<CH_NUM_LOG)-1:0]              rx_ch_credit_max,
    output [(16<<CH_NUM_LOG)-1:0]              rx_ch_credit_cur,
    output [(32<<CH_NUM_LOG)-1:0]              rx_ch_ip_bases,
    output [(32<<CH_NUM_LOG)-1:0]              rx_ch_ip_masks,
    output [(16<<CH_NUM_LOG)-1:0]              rx_ch_port_bases,
    output [(16<<CH_NUM_LOG)-1:0]              rx_ch_port_masks,

    input [SESSION_NUM_LOG-1:0]                activate_done_session_id,
    input                                      activate_done,

    input [SESSION_NUM_LOG-1:0]                connected_session_id,
    input [31:0]                               connected_ip,
    input [15:0]                               connected_port,
    input                                      connected_valid,
    output reg                                 connected_out_found,
    output reg                                 connected_out_valid,

    input [SESSION_NUM_LOG-1:0]                close_session_id,
    input                                      close_valid,

    input [SESSION_NUM_LOG-1:0]                find_ch_session_id,
    input                                      find_ch_valid,
    output [CH_NUM_LOG-1:0]                    find_ch_id,
    output                                     find_ch_id_tx_valid,
    output                                     find_ch_id_rx_valid,
    output                                     find_ch_id_invalid,

    input [15:0]                               cp_config_credit_max,
    input [31:0]                               cp_config_frame_size,
    input [SESSION_NUM_LOG-1:0]                cp_config_session_id,
    input                                      cp_config_valid,

    input [SESSION_NUM_LOG-1:0]                tx_credit_inc_session_id,
    input                                      tx_credit_inc,
    input [SESSION_NUM_LOG-1:0]                rx_credit_inc_session_id,
    input                                      rx_credit_inc,
    input [SESSION_NUM_LOG-1:0]                tx_credit_dec_session_id,
    input                                      tx_credit_dec,
    input [SESSION_NUM_LOG-1:0]                rx_credit_dec_session_id,
    input                                      rx_credit_dec,

    input                                      clk,
    input                                      resetn
    );

   localparam CH_REG_BITS = 8;
   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam SESSION_NUM = 1 << SESSION_NUM_LOG;
   localparam GLOBAL_BASE = 16'h0;
   localparam GLOBAL_SIZE = 16'h1000;
   localparam CH_SIZE = 1 << CH_REG_BITS;
   localparam TX_BASE = GLOBAL_BASE + GLOBAL_SIZE;
   localparam RX_BASE = TX_BASE + CH_SIZE * CH_NUM;
   localparam CH_BASE_NUM = GLOBAL_SIZE >> CH_REG_BITS;

   // global
   //  - config
   // tx,rx
   //  [+0x00]: [0]: enable, [4]: activate(rx only)
   //  [+0x04]: [0]: valid, [4]: active, [8]: ready
   //  [+0x08]: [SESSION_NUM_LOG-1:0] session_id
   //  [+0x0c]: [31:0] frame size
   //  [+0x10]: [15:0] max frame credit
   //  [+0x14]: [15:0] cur frame credit
   //  [+0x18]: [31:0] counterpart ip
   //  [+0x1c]: [31:0] counterpart ip mask
   //  [+0x20]: [15:0] counterpart port
   //  [+0x24]: [15:0] counterpart port mask

   // global
   wire [7:0]                   w_ch_num_log = CH_NUM_LOG;
   wire [7:0]                   w_session_num_log = SESSION_NUM_LOG;
   wire [31:0]                  w_global_config = {16'd0, w_session_num_log, w_ch_num_log};

   reg [11:0]                   g_araddr, g_awaddr;
   reg [AW-1:0]                 ch_araddr, ch_awaddr;
   reg [31:0]                   wdata, rdata;
   reg                          g_arvalid, g_awvalid, wvalid;
   reg                          ch_arvalid, ch_awvalid;
   reg                          bvalid, rvalid, arvalid_d1, awvalid_d1;
   reg                          ch_araddr_is_tx, ch_awaddr_is_tx;
   wire                         w_rdata_valid;
   wire [31:0]                  w_rdata;
   always @(posedge clk) begin
      if (~resetn) begin
         g_araddr <= 'd0;
         ch_araddr <= 'd0;
         g_arvalid <= 1'b0;
         ch_arvalid <= 1'b0;
         rvalid <= 1'b0;
         arvalid_d1 <= 1'b0;
      end else if (axil_arvalid & axil_arready) begin
         g_araddr <= axil_araddr;
         ch_araddr <= axil_araddr - TX_BASE;
         g_arvalid <= axil_araddr < TX_BASE;
         ch_arvalid <= axil_araddr >= TX_BASE;
         ch_araddr_is_tx <= axil_araddr < RX_BASE;
         arvalid_d1 <= 1'b0;
      end else begin
         arvalid_d1 <= (g_arvalid | ch_arvalid) | (arvalid_d1 & ~(rvalid & axil_rready));
         rvalid <= w_rdata_valid | (rvalid & ~axil_rready);
         g_arvalid <= 1'b0;
         ch_arvalid <= ch_arvalid & ~(rvalid & axil_rready);
         if (w_rdata_valid) begin
            rdata <= w_rdata;
         end
      end
   end
   assign axil_arready = ~g_arvalid & ~ch_arvalid;
   assign axil_rdata = rdata;
   assign axil_rresp = 2'd0;
   assign axil_rvalid = rvalid;
   always @(posedge clk) begin
      if (~resetn) begin
         g_awaddr <= 'd0;
         ch_awaddr <= 'd0;
         g_awvalid <= 1'b0;
         ch_awvalid <= 1'b0;
         wvalid <= 1'b0;
         bvalid <= 1'b0;
      end else begin
         if (axil_awvalid & axil_awready) begin
            g_awaddr <= axil_awaddr;
            ch_awaddr <= axil_awaddr - TX_BASE;
            g_awvalid <= axil_awaddr < TX_BASE;
            ch_awvalid <= axil_awaddr >= TX_BASE;
            ch_awaddr_is_tx <= axil_awaddr < RX_BASE;
         end else begin
            g_awvalid <= g_awvalid & ~wvalid;
            ch_awvalid <= ch_awvalid & ~wvalid;
         end
         if (axil_wvalid & axil_wready) begin
            wdata <= axil_wdata;
            wvalid <= 1'b1;
         end else begin
            wvalid <= wvalid & ~(g_awvalid | ch_awvalid);
         end
         bvalid <= ((g_awvalid | ch_awvalid) & wvalid) | (bvalid & ~axil_bready);
      end
   end
   assign axil_awready = ~g_awvalid & ~ch_awvalid & ~bvalid;
   assign axil_wready = ~wvalid & ~bvalid;
   assign axil_bresp = 2'd0;
   assign axil_bvalid = bvalid;

   // global
   reg g_invalidate_activate;
   always @(posedge clk) begin
      if (~resetn) begin
         g_invalidate_activate <= 1'b0;
      end else if (g_awvalid && wvalid && g_awaddr == 'h4) begin
         g_invalidate_activate <= wdata[0];
      end else begin
         g_invalidate_activate <= 1'b0;
      end
   end
   assign invalidate_activate = g_invalidate_activate;

   // tx
   wire [CH_REG_BITS-1:0]       w_ch_araddr = ch_araddr[CH_REG_BITS-1:0];
   wire [CH_NUM_LOG-1:0]        w_ch_rd = ch_araddr[CH_REG_BITS+:CH_NUM_LOG];
   wire                         w_ch_rd_valid = ch_arvalid && ~arvalid_d1;
   wire [CH_REG_BITS-1:0]       w_ch_awaddr = ch_awaddr[CH_REG_BITS-1:0];
   wire [CH_NUM_LOG-1:0]        w_ch_wr = ch_awaddr[CH_REG_BITS+:CH_NUM_LOG];
   wire                         w_ch_wr_valid = ch_awvalid && wvalid;
   wire [32*CH_NUM*2-1:0]       w_ch_rdata;
   wire [CH_NUM*2-1:0]          w_ch_rvalid;

   wire [CH_NUM-1:0]            w_tx_find_matched;
   wire [CH_NUM-1:0]            w_rx_find_matched;
   wire [CH_NUM-1:0]            w_tx_cp_config_dones;
   wire [SESSION_NUM_LOG+47:0] w_cp_config_wdata, w_cp_config_rdata;
   wire                        w_cp_config_wvalid, w_cp_config_wready;
   wire                        w_cp_config_rvalid, w_cp_config_rready;
   wire [7:0]                  w_cp_config_wretry, w_cp_config_rretry;
   wire [CH_NUM-1:0]           w_tx_connected, w_rx_connected;
   wire [SESSION_NUM_LOG-1:0]  w_connected_session_id;
   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         wire w_ch_arvalid = w_ch_rd == i && w_ch_rd_valid && ch_araddr_is_tx;
         wire w_ch_wvalid = w_ch_wr == i && w_ch_wr_valid && ch_awaddr_is_tx;
         toe_ctrl_ch_reg #(
             .IS_TX ( 1 ),
             .CH_NUM_LOG ( CH_NUM_LOG ),
             .SESSION_NUM_LOG ( SESSION_NUM_LOG ),
             .CH_REG_BITS ( CH_REG_BITS )
         ) tx_ch_reg (
             .araddr ( w_ch_araddr ),
             .arvalid ( w_ch_arvalid ),
             .rdata ( w_ch_rdata[i*32+:32] ),
             .rvalid ( w_ch_rvalid[i] ),
             .awaddr ( w_ch_awaddr ),
             .wdata ( wdata ),
             .wvalid ( w_ch_wvalid ),
             .ch_enable ( tx_ch_enables[i] ),
             .ch_valid ( tx_ch_valids[i] ),
             .ch_activate (  ),
             .ch_active ( tx_ch_actives[i] ),
             .ch_ready ( tx_ch_readys[i] ),
             .ch_session_id ( tx_ch_session_ids[i*SESSION_NUM_LOG+:SESSION_NUM_LOG] ),
             .ch_frame_size ( tx_ch_frame_sizes[i*32+:32] ),
             .ch_credit_max ( tx_ch_credit_max[i*16+:16] ),
             .ch_credit_cur ( tx_ch_credit_cur[i*16+:16] ),
             .ch_ip_base ( tx_ch_ip_bases[i*32+:32] ),
             .ch_ip_mask ( tx_ch_ip_masks[i*32+:32] ),
             .ch_port_base ( tx_ch_port_bases[i*16+:16] ),
             .ch_port_mask ( tx_ch_port_masks[i*16+:16] ),
             .connected_session_id ( w_connected_session_id ),
             .connected ( w_tx_connected[i] ),
             .close ( close_valid ),
             .close_session_id ( close_session_id ),
             .activate_done ( activate_done ),
             .activate_done_session_id ( activate_done_session_id ),
             .find_ch_session_id ( find_ch_session_id ),
             .find_ch_matched ( w_tx_find_matched[i] ),
             .cp_config_credit_max ( cp_config_valid ? cp_config_credit_max : w_cp_config_rdata[32+:16] ),
             .cp_config_frame_size ( cp_config_valid ? cp_config_frame_size : w_cp_config_rdata[0+:32] ),
             .cp_config_session_id ( cp_config_valid ? cp_config_session_id : w_cp_config_rdata[48+:SESSION_NUM_LOG] ),
             .cp_config_valid ( cp_config_valid | w_cp_config_rvalid ),
             .cp_config_done ( w_tx_cp_config_dones[i] ),
             .credit_inc_session_id ( tx_credit_inc_session_id ),
             .credit_inc ( tx_credit_inc ),
             .credit_dec_session_id ( tx_credit_dec_session_id ),
             .credit_dec ( tx_credit_dec ),
             .clk ( clk ),
             .resetn ( resetn )
         );
      end
   endgenerate

   reg [SESSION_NUM_LOG-1:0] cp_config_session_id_saved;
   reg [15:0]                cp_config_credit_max_saved;
   reg [31:0]                cp_config_frame_size_saved;
   reg [7:0]                 cp_config_retry_saved;
   reg                       cp_config_valid_saved;
   always @(posedge clk) begin
      if (~resetn) begin
         cp_config_session_id_saved <= 'd0;
         cp_config_credit_max_saved <= 'd0;
         cp_config_frame_size_saved <= 'd0;
         cp_config_retry_saved <= 'd0;
         cp_config_valid_saved <= 1'b0;
      end else if (~cp_config_valid_saved && cp_config_valid) begin
         cp_config_session_id_saved <= cp_config_session_id;
         cp_config_credit_max_saved <= cp_config_credit_max;
         cp_config_frame_size_saved <= cp_config_frame_size;
         cp_config_valid_saved <= 1'b1;
         cp_config_retry_saved <= 'd0;
      end else if (~cp_config_valid_saved && ~cp_config_valid && w_cp_config_rvalid) begin
         {cp_config_session_id_saved, cp_config_credit_max_saved, cp_config_frame_size_saved} <= w_cp_config_rdata;
         cp_config_valid_saved <= ~&w_cp_config_rretry;
         cp_config_retry_saved <= w_cp_config_rretry + 1'b1;
      end else if (cp_config_valid_saved) begin
         cp_config_valid_saved <= 1'b0;
      end
   end
   assign w_cp_config_wretry = cp_config_valid && cp_config_valid_saved ? 'd0 : cp_config_retry_saved;
   assign w_cp_config_wdata = cp_config_valid && cp_config_valid_saved ?
                              {cp_config_session_id, cp_config_credit_max, cp_config_frame_size} :
                              {cp_config_session_id_saved, cp_config_credit_max_saved, cp_config_frame_size_saved};
   assign w_cp_config_wvalid = cp_config_valid_saved && (~|w_tx_cp_config_dones | cp_config_valid);
   assign w_cp_config_rready = ~cp_config_valid_saved && ~cp_config_valid;

   fifo #(
       .DL ( CH_NUM_LOG ),
       .DW ( 8 + 48 + SESSION_NUM_LOG )
   ) cp_config_fifo (
       .idata ( {w_cp_config_wretry, w_cp_config_wdata} ),
       .ivalid ( w_cp_config_wvalid ),
       .iready ( w_cp_config_wready ),
       .odata ( {w_cp_config_rretry, w_cp_config_rdata} ),
       .ovalid ( w_cp_config_rvalid ),
       .oready ( w_cp_config_rready ),
       .full ( ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   // rx
   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         wire w_ch_arvalid = w_ch_rd == i && w_ch_rd_valid && ~ch_araddr_is_tx;
         wire w_ch_wvalid = w_ch_wr == i && w_ch_wr_valid && ~ch_awaddr_is_tx;
         toe_ctrl_ch_reg #(
             .IS_TX ( 0 ),
             .CH_NUM_LOG ( CH_NUM_LOG ),
             .SESSION_NUM_LOG ( SESSION_NUM_LOG ),
             .CH_REG_BITS ( CH_REG_BITS )
         ) rx_ch_reg (
             .araddr ( w_ch_araddr ),
             .arvalid ( w_ch_arvalid ),
             .rdata ( w_ch_rdata[(i+CH_NUM)*32+:32] ),
             .rvalid ( w_ch_rvalid[i+CH_NUM] ),
             .awaddr ( w_ch_awaddr ),
             .wdata ( wdata ),
             .wvalid ( w_ch_wvalid ),
             .ch_enable ( rx_ch_enables[i] ),
             .ch_valid ( rx_ch_valids[i] ),
             .ch_activate ( rx_ch_activates[i] ),
             .ch_active ( rx_ch_actives[i] ),
             .ch_ready ( rx_ch_readys[i] ),
             .ch_session_id ( rx_ch_session_ids[i*SESSION_NUM_LOG+:SESSION_NUM_LOG] ),
             .ch_frame_size ( rx_ch_frame_sizes[i*32+:32] ),
             .ch_credit_max ( rx_ch_credit_max[i*16+:16] ),
             .ch_credit_cur ( rx_ch_credit_cur[i*16+:16] ),
             .ch_ip_base ( rx_ch_ip_bases[i*32+:32] ),
             .ch_ip_mask ( rx_ch_ip_masks[i*32+:32] ),
             .ch_port_base ( rx_ch_port_bases[i*16+:16] ),
             .ch_port_mask ( rx_ch_port_masks[i*16+:16] ),
             .connected_session_id ( w_connected_session_id ),
             .connected ( w_rx_connected[i] ),
             .close ( close_valid ),
             .close_session_id ( close_session_id ),
             .activate_done ( activate_done ),
             .activate_done_session_id ( activate_done_session_id ),
             .find_ch_session_id ( find_ch_session_id ),
             .find_ch_matched ( w_rx_find_matched[i] ),
             .cp_config_credit_max ( 'd0 ),
             .cp_config_frame_size ( 'd0 ),
             .cp_config_session_id ( 'd0 ),
             .cp_config_valid ( 1'b0 ),
             .credit_inc_session_id ( rx_credit_inc_session_id ),
             .credit_inc ( rx_credit_inc ),
             .credit_dec_session_id ( rx_credit_dec_session_id ),
             .credit_dec ( rx_credit_dec ),
             .clk ( clk ),
             .resetn ( resetn )
         );
      end
   endgenerate

   reg [31:0] w_rdata_merged;
   integer    ii;
   always @(w_ch_rvalid) begin
      w_rdata_merged = 32'd0;
      for (ii=0; ii<CH_NUM*2; ii=ii+1) begin
         w_rdata_merged = w_rdata_merged | w_ch_rdata[ii*32+:32];
      end
   end
   assign w_rdata = g_arvalid ? w_global_config : w_rdata_merged;
   assign w_rdata_valid = g_arvalid | |w_ch_rvalid;

   // session_id -> ch (rev map)
   reg [CH_NUM_LOG-1:0] ch_id_from_session;
   reg                  ch_id_rx_valid;
   reg                  ch_id_tx_valid;
   reg                  ch_id_invalid;
   reg                  ch_id_from_session_valid;
   reg [CH_NUM_LOG-1:0] w_ch_id_tx;
   reg [CH_NUM_LOG-1:0] w_ch_id_rx;
   always @(posedge clk) begin
      if (~resetn) begin
         ch_id_from_session <= 'd0;
         ch_id_from_session_valid <= 1'b0;
         ch_id_rx_valid <= 1'b0;
         ch_id_tx_valid <= 1'b0;
         ch_id_invalid <= 1'b0;
      end else begin
         ch_id_from_session_valid <= find_ch_valid;
         if (ch_id_from_session_valid) begin
            if (|w_tx_find_matched) begin
               ch_id_tx_valid <= 1'b1;
               ch_id_rx_valid <= 1'b0;
               ch_id_invalid <= 1'b0;
               ch_id_from_session <= w_ch_id_tx;
            end else if (|w_rx_find_matched) begin
               ch_id_tx_valid <= 1'b0;
               ch_id_rx_valid <= 1'b1;
               ch_id_invalid <= 1'b0;
               ch_id_from_session <= w_ch_id_rx;
            end else begin
               ch_id_tx_valid <= 1'b0;
               ch_id_rx_valid <= 1'b0;
               ch_id_invalid <= 1'b1;
            end
         end else begin
            ch_id_tx_valid <= 1'b0;
            ch_id_rx_valid <= 1'b0;
            ch_id_invalid <= 1'b0;
         end
      end
   end
   always @(w_tx_find_matched) begin
      w_ch_id_tx = 'd0;
      for (ii=0; ii<CH_NUM; ii=ii+1) begin
         if (w_tx_find_matched[ii]) begin
            w_ch_id_tx = ii;
         end
      end
   end
   always @(w_rx_find_matched) begin
      w_ch_id_rx = 'd0;
      for (ii=0; ii<CH_NUM; ii=ii+1) begin
         if (w_rx_find_matched[ii]) begin
            w_ch_id_rx = ii;
         end
      end
   end
   assign find_ch_id = ch_id_from_session;
   assign find_ch_id_tx_valid = ch_id_tx_valid;
   assign find_ch_id_rx_valid = ch_id_rx_valid;
   assign find_ch_id_invalid = ch_id_invalid;

   // connected
   reg [31:0] connected_ip_save;
   reg [15:0] connected_port_save;
   reg [SESSION_NUM_LOG-1:0] connected_session_id_save;
   reg                       connected_valid_save;
   reg [CH_NUM_LOG-1:0]      connected_ch;
   wire                      w_connected_tx_found, w_connected_rx_found;
   wire                      w_connected_last_ch;

   always @(posedge clk) begin
      if (~resetn) begin
         connected_ch <= 'd0;
         connected_valid_save <= 1'b0;
         connected_out_valid <= 1'b0;
      end else if (connected_valid) begin
         connected_valid_save <= 1'b1;
         connected_ch <= 'd0;
         connected_ip_save <= connected_ip;
         connected_port_save <= connected_port;
         connected_session_id_save <= connected_session_id;
         connected_out_valid <= 1'b0;
      end else if (connected_valid_save &&
                   (w_connected_tx_found || w_connected_rx_found || w_connected_last_ch)) begin
         connected_out_valid <= 1'b1;
         connected_out_found <= w_connected_tx_found || w_connected_rx_found;
         connected_valid_save <= 1'b0;
      end else begin
         connected_out_valid <= 1'b0;
         if (connected_valid_save) connected_ch <= connected_ch + 1'b1;
      end
   end

   wire [31:0] w_cur_tx_ip = (tx_ch_ip_bases >> {connected_ch, 5'd0}) & (tx_ch_ip_masks >> {connected_ch, 5'd0});
   wire [31:0] w_cur_rx_ip = (rx_ch_ip_bases >> {connected_ch, 5'd0}) & (rx_ch_ip_masks >> {connected_ch, 5'd0});
   wire [15:0] w_cur_tx_port = (tx_ch_port_bases >> {connected_ch, 4'd0}) & (tx_ch_port_masks >> {connected_ch, 4'd0});
   wire [15:0] w_cur_rx_port = (rx_ch_port_bases >> {connected_ch, 4'd0}) & (rx_ch_port_masks >> {connected_ch, 4'd0});
   wire [31:0] w_cur_connected_tx_ip = connected_ip_save & (tx_ch_ip_masks >> {connected_ch, 5'd0});
   wire [31:0] w_cur_connected_rx_ip = connected_ip_save & (rx_ch_ip_masks >> {connected_ch, 5'd0});
   wire [15:0] w_cur_connected_tx_port = connected_port_save & (tx_ch_port_masks >> {connected_ch, 4'd0});
   wire [15:0] w_cur_connected_rx_port = connected_port_save & (rx_ch_port_masks >> {connected_ch, 4'd0});

   assign w_connected_tx_found = (w_cur_tx_ip == w_cur_connected_tx_ip && w_cur_tx_port == w_cur_connected_tx_port) &
                                 ((tx_ch_enables & ~tx_ch_valids) >> connected_ch) & connected_valid_save;
   assign w_connected_rx_found = (w_cur_rx_ip == w_cur_connected_rx_ip && w_cur_rx_port == w_cur_connected_rx_port) &
                                 ((rx_ch_enables & ~rx_ch_valids) >> connected_ch) & connected_valid_save;
   assign w_connected_last_ch = &connected_ch;

   assign w_tx_connected = {{CH_NUM-1{1'b0}}, w_connected_tx_found} << connected_ch;
   assign w_rx_connected = {{CH_NUM-1{1'b0}}, w_connected_rx_found} << connected_ch;
   assign w_connected_session_id = connected_session_id_save;

endmodule
