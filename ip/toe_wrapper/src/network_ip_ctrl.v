/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module network_ip_ctrl #(
    parameter DW_LOG = 9,
    parameter CH_NUM_LOG = 4,
    parameter ENABLE_TOE = 1,
    parameter ENABLE_TOE_HW_APP = 1,
    parameter NOTIFICATION_FIFO_DEPTH_LOG = 5,
    parameter NOTIFICATION_FIFO_HOST_DEPTH_LOG = 4,
    parameter RX_RSP_FIFO_DEPTH_LOG = 4,
    parameter RX_DATA_FIFO_DEPTH_LOG = 5
) (
    input [11:0]                 axil_araddr,
    input                        axil_arvalid,
    output                       axil_arready,
    output reg [31:0]            axil_rdata,
    output [1:0]                 axil_rresp,
    output reg                   axil_rvalid,
    input                        axil_rready,
    input [11:0]                 axil_awaddr,
    input                        axil_awvalid,
    output                       axil_awready,
    input [31:0]                 axil_wdata,
    input                        axil_wvalid,
    output                       axil_wready,
    output [1:0]                 axil_bresp,
    output reg                   axil_bvalid,
    input                        axil_bready,

    input [31:0]                 axis_tcp_cmd_tdata, // [31:16]: length, [15:0]: session_id
    input                        axis_tcp_cmd_tvalid,
    output                       axis_tcp_cmd_tready,

    output reg [87:0]            axis_tcp_rsp_tdata, // [87:80]: events, [79:64]: port, [63:32]: ip, [31:16]: length, [15:0]: session_id
    output reg                   axis_tcp_rsp_tvalid, // events: [80] connected, [81] close_wait, [82]: closed
    input                        axis_tcp_rsp_tready,

    output reg [31:0]            ip_addr,
    output reg [31:0]            subnet_mask,
    output reg [31:0]            default_gateway,
    output reg [47:0]            mac_addr,

    output reg                   interrupt,

    output [47:0]                open_req_tdata, // port[47:32], ip[31:0]
    output                       open_req_tvalid,
    input                        open_req_tready,

    input [71:0]                 open_status_tdata, // port[71:56], ip[55:24], flag[23:16], session[15:0]
    input                        open_status_tvalid,
    output                       open_status_tready,

    input [143:0]                ht_upd_tdata, // src[143:112], session_id[111:96], tar_port[95:80], self_port[79:64], tar_ip[63:32], op[31:0]
    input                        ht_upd_tvalid,
    output                       ht_upd_tready,

    output [15:0]                close_conn_tdata, // session[15:0]
    output                       close_conn_tvalid,
    input                        close_conn_tready,

    output [15:0]                listen_req_tdata, // port[15:0]
    output                       listen_req_tvalid,
    input                        listen_req_tready,

    input [7:0]                  listen_status_tdata, // flag[7:0] ?
    input                        listen_status_tvalid,
    output                       listen_status_tready,

    input [87:0]                 notification_tdata, // flag[87:80], port[79:64], ip[63:32], length[31:16], session[15:0]
    input                        notification_tvalid,
    output                       notification_tready,

    output [31:0]                tx_req_tdata, // length[31:16], session[15:0]
    output                       tx_req_tvalid,
    input                        tx_req_tready,

    input [63:0]                 tx_rsp_tdata, // error[63:62], remain[61:32], length[31:16], session[15:0]
    input                        tx_rsp_tvalid,
    output                       tx_rsp_tready,

    output [31:0]                rx_req_tdata, // length[31:16], session[15:0]
    output                       rx_req_tvalid,
    input                        rx_req_tready,

    input [15:0]                 rx_rsp_tdata, // session[15:0]
    input                        rx_rsp_tvalid,
    output                       rx_rsp_tready,

    input [(1<<DW_LOG)-1:0]      rx_in_tdata,
    input [(1<<(DW_LOG-3))-1:0]  rx_in_tkeep,
    input                        rx_in_tlast,
    input                        rx_in_tvalid,
    output                       rx_in_tready,

    output [(1<<DW_LOG)-1:0]     rx_out_tdata,
    output [(1<<(DW_LOG-3))-1:0] rx_out_tkeep,
    output [CH_NUM_LOG-1:0]      rx_out_tuser,
    output                       rx_out_tlast,
    output                       rx_out_tvalid,
    input                        rx_out_tready,

    input                        clk,
    input                        resetn
);

   localparam DW = 1 << DW_LOG;
   localparam KW_LOG = DW_LOG-3;
   localparam KW = 1 << KW_LOG;

   localparam TOE_BASE = 12'h100;
   localparam TOE_APP_BASE = 12'h800;

   localparam TOE_CONNECTED_SESSION = 8'h01;
   localparam TOE_CLOSE_SESSION = 8'h02;
   localparam TOE_CLOSED_SESSION = 8'h04;
   localparam TOE_RX_VALID = 8'h08;

   reg [1:0]                               rstat;
   reg [2:0]                               wstat;
   reg [11:0]                              raddr;
   reg [11:0]                              waddr;
   reg [31:0]                              wdata;
   wire                                    w_rvalid;
   always @(posedge clk) begin
      if (~resetn) begin
	     rstat <= 2'd0;
	     wstat <= 3'd0;
         raddr <= 12'd0;
         waddr <= 12'd0;
         wdata <= 32'd0;
      end else begin
	     if (axil_arvalid & axil_arready) begin
	        rstat[0] <= 1'b1;
	        raddr <= axil_araddr;
	     end
	     if (rstat[0] & ~axil_rvalid) rstat[1] <= w_rvalid;
	     if (&rstat & axil_rvalid & axil_rready) rstat <= 2'd0;
	     if (axil_awvalid & axil_awready) begin
	        wstat[0] <= 1'b1;
	        waddr <= axil_awaddr;
	     end
	     if (axil_wvalid & axil_wready) begin
	        wstat[1] <= 1'b1;
	        wdata <= axil_wdata;
	     end
	     if (wstat == 3'd3 && ~axil_bvalid) wstat[2] <= 1'b1;
	     if (&wstat && axil_bvalid & axil_bready) wstat <= 3'd0;
      end
   end
   assign axil_arready = ~rstat[0];
   assign axil_awready = ~wstat[0];
   assign axil_wready = ~wstat[1];

   wire toe_int;
   wire toe_app_int;

   // base write
   always @(posedge clk) begin
      if (~resetn) begin
	     ip_addr <= 32'd0;
	     subnet_mask <= 32'd0;
	     default_gateway <= 32'd0;
	     mac_addr <= 48'd0;
	     axil_bvalid <= 1'b0;
	     interrupt <= 1'b0;
      end else begin
	     if (wstat == 3'd3 && ~axil_bvalid) begin
	        casex (waddr)
	          12'h000: ip_addr <= wdata;
	          12'h004: subnet_mask <= wdata;
	          12'h008: default_gateway <= wdata;
	          12'h010: mac_addr[31:0] <= wdata;
	          12'h014: mac_addr[47:32] <= wdata[15:0];
	          12'h0f0: interrupt <= interrupt & ~wdata[0]; // 1C
	        endcase
	        axil_bvalid <= 1'b1;
	     end else begin
	        axil_bvalid <= axil_bvalid & ~axil_bready;
	     end
	     interrupt <= interrupt | toe_int | toe_app_int;
      end
   end
   assign axil_bresp = 2'd0;

   // base read
   wire [31:0] rdata;
   wire [31:0] toe_rdata;
   wire        toe_rdata_valid;
   always @(posedge clk) begin
      if (~resetn) begin
	     axil_rdata <= 32'd0;
	     axil_rvalid <= 1'b0;
      end else if (rstat == 2'd1 && ~axil_rvalid) begin
	     axil_rdata <= rdata;
	     axil_rvalid <= w_rvalid;
      end else begin
	     axil_rvalid <= axil_rvalid & ~axil_rready;
      end
   end
   assign rdata = raddr == 12'h000 ? ip_addr :
		          raddr == 12'h004 ? subnet_mask :
		          raddr == 12'h008 ? default_gateway :
		          raddr == 12'h010 ? mac_addr[31:0] :
		          raddr == 12'h014 ? mac_addr[47:32] : toe_rdata;
   assign axil_rresp = 2'd0;
   assign w_rvalid = raddr < TOE_BASE ? 1'b1 : toe_rdata_valid;

   wire [65:0] ctl_event_strm_data; // [65]: connected, [64]: closed, [63:32]: ip, [31:16]: port, [15:0] session_id
   wire        ctl_event_strm_valid;
   wire        ctl_event_strm_ready;

   generate
      if (ENABLE_TOE != 0) begin : toe_block
	     reg [47:0] open_req_data;
	     reg 	    open_req_valid;
	     reg [15:0] listen_req_data;
	     reg 	    listen_req_valid;
	     reg [15:0] close_conn_data;
	     reg 	    close_conn_valid;
	     reg [71:0] open_status_data;
	     reg 	    open_status_valid;
	     reg 	    open_status_int_enable;
	     reg 	    open_status_int;
	     reg [7:0]  listen_status_data;
	     reg 	    listen_status_valid;
	     reg 	    listen_status_int_enable;
	     reg 	    listen_status_int;
	     reg [87:0] notification_data;
	     reg 	    notification_valid;
	     reg 	    notification_int_enable;
	     reg 	    notification_int;
         reg [143:0] ht_update_data;
         reg         ht_update_valid;
         reg         ht_update_int_enable;
         reg         ht_update_int;

	     wire [87:0] notification_host_data;
         wire        notification_host_valid;
	     wire        notification_host_ready;
	     wire        notification_tready_host;
	     reg [65:0]  notification_strm_data;
	     reg         notification_strm_valid;
	     wire        notification_strm_ready;
	     reg [31:0]  notification_rx_cmd_data;
	     reg         notification_rx_cmd_valid;
	     wire        notification_rx_cmd_ready;
	     wire [79:0]  ht_upd_host_data;
         wire         ht_upd_host_valid;
	     wire         ht_upd_host_ready;
	     wire         ht_upd_tready_host;
	     reg [65:0]   ht_upd_strm_data;
	     reg          ht_upd_strm_valid;
	     wire         ht_upd_strm_ready;
	     wire [71:0]  open_status_host_data;
         wire         open_status_host_valid;
	     wire         open_status_host_ready;
	     wire         open_status_tready_host;
	     reg [65:0]   open_status_strm_data;
	     reg          open_status_strm_valid;
	     wire         open_status_strm_ready;

	     // write
	     always @(posedge clk) begin
	        if (~resetn) begin
	           open_req_data <= 48'd0;
	           open_req_valid <= 1'b0;
	           listen_req_data <= 16'd0;
	           listen_req_valid <= 1'b0;
	           close_conn_data <= 16'd0;
	           close_conn_valid <= 1'b0;
	           open_status_data <= 72'd0;
	           open_status_valid <= 1'b0;
	           open_status_int_enable <= 1'b0;
	           open_status_int <= 1'b0;
	           listen_status_data <= 8'd0;
	           listen_status_valid <= 1'b0;
	           listen_status_int_enable <= 1'b0;
	           listen_status_int <= 1'b0;
	           notification_data <= 88'd0;
	           notification_valid <= 1'b0;
	           notification_int_enable <= 1'b0;
	           notification_int <= 1'b0;
	           ht_update_data <= 88'd0;
	           ht_update_valid <= 1'b0;
	           ht_update_int_enable <= 1'b0;
	           ht_update_int <= 1'b0;
	        end else begin
	           if (wstat == 3'd3 && ~axil_bvalid) begin
		          casex (waddr)
		            // open req
		            TOE_BASE+8'h00: open_req_valid <= wdata[0];
		            TOE_BASE+8'h04: open_req_data[31:0] <= wdata;
		            TOE_BASE+8'h08: open_req_data[47:32] <= wdata[15:0];
		            // open status
		            TOE_BASE+8'h10: begin
		               open_status_int_enable <= wdata[4];
		               open_status_valid <= (open_status_valid & ~wdata[0]); // 1C
		            end
		            // close conn
		            TOE_BASE+8'h20: close_conn_valid <= wdata[0];
		            TOE_BASE+8'h24: close_conn_data[15:0] <= wdata[15:0];
		            // listen req
		            TOE_BASE+8'h30: listen_req_valid <= wdata[0];
		            TOE_BASE+8'h34: listen_req_data[15:0] <= wdata[15:0];
		            // Listen status
		            TOE_BASE+8'h40: begin
		               listen_status_int_enable <= wdata[4];
		               listen_status_valid <= (listen_status_valid & ~wdata[0]); // 1C
		            end
		            // notification
		            TOE_BASE+8'h50: begin
		               notification_int_enable <= wdata[4];
		               notification_valid <= (notification_valid & ~wdata[0]); // 1C
		            end
                    // hash table update
                    TOE_BASE+8'h60: begin
                       ht_update_int_enable <= wdata[4];
		               ht_update_valid <= (ht_update_valid & ~wdata[0]); // 1C
                    end
                    TOE_BASE+8'hf0: begin
                       open_status_int <= open_status_int & ~wdata[0]; // 1C
                       listen_status_int <= listen_status_int & ~wdata[1];
                       notification_int <= notification_int & ~wdata[2];
                       ht_update_int <= ht_update_int & ~wdata[3];
                    end
		          endcase
	           end
	           if (open_req_tvalid & open_req_tready) open_req_valid <= 1'b0;
	           if (close_conn_tvalid & close_conn_tready) close_conn_valid <= 1'b0;
	           if (listen_req_tvalid & listen_req_tready) listen_req_valid <= 1'b0;
	           if (open_status_host_valid & open_status_host_ready) begin
		          open_status_data <= open_status_host_data;
		          open_status_valid <= 1'b1;
                  open_status_int <= open_status_int_enable;
	           end
	           if (listen_status_tvalid & listen_status_tready) begin
		          listen_status_data <= listen_status_tdata;
		          listen_status_valid <= 1'b1;
                  listen_status_int <= listen_status_int_enable;
	           end
	           if (notification_host_valid & notification_host_ready) begin
		          notification_data <= notification_host_data;
		          notification_valid <= 1'b1;
                  notification_int <= notification_int_enable;
	           end
	           if (ht_upd_host_valid && ht_upd_host_ready) begin
		          ht_update_data <= ht_upd_host_data;
		          ht_update_valid <= 1'b1;
		          ht_update_int <= ht_update_int_enable;
	           end
	        end
	     end
	     assign toe_int = open_status_int | listen_status_int | notification_int | ht_update_int;
	     assign open_req_tdata = open_req_data;
	     assign open_req_tvalid = open_req_valid;
	     assign close_conn_tdata = close_conn_data;
	     assign close_conn_tvalid = close_conn_valid;
	     assign listen_req_tdata = listen_req_data;
	     assign listen_req_tvalid = listen_req_valid;
	     assign open_status_host_ready = ~open_status_valid;
	     assign listen_status_tready = ~listen_status_valid;
	     assign notification_host_ready = ~notification_valid;
         assign ht_upd_host_ready = ~ht_update_valid;

	     // read
         reg toe_data_valid_reg;
	     reg [31:0] toe_data_reg;
	     wire [31:0] toe_data_pre;
	     always @(posedge clk) begin
	        if (~resetn) begin
	           toe_data_reg <= 32'd0;
               toe_data_valid_reg <= 1'b0;
	        end else begin
	           toe_data_reg <= toe_data_pre;
               toe_data_valid_reg <= rstat[0];
	        end
	     end
	     assign toe_data_pre = raddr == TOE_BASE+8'h00 ? {31'd0, open_req_valid} :
			                   raddr == TOE_BASE+8'h04 ? open_req_data[31:0] :
			                   raddr == TOE_BASE+8'h08 ? {16'd0, open_req_data[47:32]} :
			                   raddr == TOE_BASE+8'h10 ? {27'd0, open_status_int_enable, 3'd0, open_status_valid} :
			                   raddr == TOE_BASE+8'h14 ? open_status_data[31:0] :
			                   raddr == TOE_BASE+8'h18 ? open_status_data[63:32] :
			                   raddr == TOE_BASE+8'h1c ? {24'd0, open_status_data[71:64]} :
			                   raddr == TOE_BASE+8'h20 ? {31'd0, close_conn_valid} :
			                   raddr == TOE_BASE+8'h24 ? {16'd0, close_conn_data} :
			                   raddr == TOE_BASE+8'h30 ? {31'd0, listen_req_valid} :
			                   raddr == TOE_BASE+8'h34 ? {16'd0, listen_req_data} :
			                   raddr == TOE_BASE+8'h40 ? {27'd0, listen_status_int_enable, 3'd0, listen_status_valid} :
			                   raddr == TOE_BASE+8'h44 ? {24'd0, listen_status_data} :
			                   raddr == TOE_BASE+8'h50 ? {27'd0, notification_int_enable, 3'd0, notification_valid} :
			                   raddr == TOE_BASE+8'h54 ? notification_data[31:0] :
			                   raddr == TOE_BASE+8'h58 ? notification_data[63:32] :
			                   raddr == TOE_BASE+8'h5c ? {8'd0, notification_data[87:64]} :
			                   raddr == TOE_BASE+8'h60 ? {27'd0, ht_update_int_enable, 3'd0, ht_update_valid} :
			                   raddr == TOE_BASE+8'h64 ? ht_update_data[31:0] :
			                   raddr == TOE_BASE+8'h68 ? ht_update_data[63:32] :
			                   raddr == TOE_BASE+8'h6c ? {16'd0, ht_update_data[79:64]} :
                               raddr == TOE_BASE+8'hf0 ? {28'h0, ht_update_int, notification_int, listen_status_int, open_status_int} : 32'hdeadbeef;
	     assign toe_rdata = toe_data_reg;
         assign toe_rdata_valid = toe_data_valid_reg;

         // notification > host notification
         fifo #(
             .DW ( 88 ),
             .DL ( NOTIFICATION_FIFO_HOST_DEPTH_LOG )
         ) notification_fifo_host (
             .idata ( notification_tdata ),
             .ivalid ( notification_tvalid && notification_tready && notification_tdata[80] ), // closed notification
             .iready ( notification_tready_host ),
             .odata ( notification_host_data ),
             .ovalid ( notification_host_valid ),
             .oready ( notification_host_ready ),
             .clk ( clk ),
             .resetn ( resetn )
         );
         // notification > data mover cmd
         always @(posedge clk) begin
            if (~resetn) begin
               notification_strm_data <= 66'd0;
               notification_strm_valid <= 1'b0;
               notification_rx_cmd_data <= 32'd0;
               notification_rx_cmd_valid <= 1'b0;
            end else if (notification_tvalid && notification_tready) begin
               if (notification_tdata[80]) begin // close event
                  // close, ip, port, session
                  notification_strm_data <= {1'b0, notification_tdata[80],
                                             notification_tdata[39:32], notification_tdata[47:40],
                                             notification_tdata[55:48], notification_tdata[63:56],
                                             notification_tdata[79:64], notification_tdata[15:0]};
                  notification_strm_valid <= 1'b1;
               end
               if (|notification_tdata[31:16]) begin
                  notification_rx_cmd_data <= notification_tdata[31:0];
                  notification_rx_cmd_valid <= 1'b1;
               end
            end else begin
               notification_strm_valid <= notification_strm_valid & ~notification_strm_ready;
               notification_rx_cmd_valid <= notification_rx_cmd_valid & ~notification_rx_cmd_ready;
            end
         end
         assign notification_tready = (~notification_strm_valid | notification_strm_ready) &
                                      (~notification_rx_cmd_valid | notification_rx_cmd_ready) & notification_tready_host;

         // hash table update > host notification
         wire ht_upd_rx_insert = ~|ht_upd_tdata[31:0] & ~|ht_upd_tdata[143:112];
         fifo #(
             .DW ( 80 ),
             .DL ( NOTIFICATION_FIFO_HOST_DEPTH_LOG )
         ) ht_upd_fifo_host (
             .idata ( ht_upd_tdata[111:32] ),
             .ivalid ( ht_upd_tvalid && ht_upd_tready && ht_upd_rx_insert ), // accept notification
             .iready ( ht_upd_tready_host ),
             .odata ( ht_upd_host_data ),
             .ovalid ( ht_upd_host_valid ),
             .oready ( ht_upd_host_ready ),
             .clk ( clk ),
             .resetn ( resetn )
         );
         // hash table update > data mover cmd
         always @(posedge clk) begin
            if (~resetn) begin
               ht_upd_strm_data <= 66'd0;
               ht_upd_strm_valid <= 1'b0;
            end else if (ht_upd_tvalid && ht_upd_tready && ht_upd_rx_insert) begin
               // connected, tar ip, tar port, session
               ht_upd_strm_data <= {2'd2, ht_upd_tdata[63:32], ht_upd_tdata[95:80], ht_upd_tdata[111:96]};
               ht_upd_strm_valid <= 1'b1;
            end else begin
               ht_upd_strm_valid <= ht_upd_strm_valid & ~ht_upd_strm_ready;
            end
         end
         assign ht_upd_tready = (~ht_upd_strm_valid | ht_upd_strm_ready) & ht_upd_tready_host;

         // open status > host notification
         fifo #(
             .DW ( 72 ),
             .DL ( NOTIFICATION_FIFO_HOST_DEPTH_LOG )
         ) open_status_fifo_host (
             .idata ( open_status_tdata ),
             .ivalid ( open_status_tvalid && open_status_tready ), // accept notification
             .iready ( open_status_tready_host ),
             .odata ( open_status_host_data ),
             .ovalid ( open_status_host_valid ),
             .oready ( open_status_host_ready ),
             .clk ( clk ),
             .resetn ( resetn )
         );
         // open status > data mover cmd
         always @(posedge clk) begin
            if (~resetn) begin
               open_status_strm_data <= 66'd0;
               open_status_strm_valid <= 1'b0;
            end else if (open_status_tvalid && open_status_tready) begin
               // connected, ip, port, session
               open_status_strm_data <= {2'd2,
                                         open_status_tdata[31:24], open_status_tdata[39:32],
                                         open_status_tdata[47:40], open_status_tdata[55:48],
                                         open_status_tdata[71:56], open_status_tdata[15:0]};
               open_status_strm_valid <= open_status_tdata[16]; // success
            end else begin
               open_status_strm_valid <= open_status_strm_valid & ~open_status_strm_ready;
            end
         end
         assign open_status_tready = (~open_status_strm_valid | open_status_strm_ready) & open_status_tready_host;

         // arbitration and fifo
         wire [81:0] arbitrated_strm_data = ht_upd_strm_valid & ht_upd_strm_ready ? ht_upd_strm_data :
                     open_status_strm_valid & open_status_strm_ready ? open_status_strm_data : notification_strm_data;
         wire        arbitrated_strm_valid = ht_upd_strm_valid | open_status_strm_valid | notification_strm_valid;
         wire        arbitrated_strm_ready;

         assign notification_strm_ready = ~open_status_strm_valid & ~ht_upd_strm_valid & arbitrated_strm_ready;
         assign open_status_strm_ready = ~ht_upd_strm_valid & arbitrated_strm_ready;
         assign ht_upd_strm_ready = arbitrated_strm_ready;

         fifo #(
             .DW ( 66 ),
             .DL ( NOTIFICATION_FIFO_DEPTH_LOG )
         ) event_strm_fifo (
             .idata ( arbitrated_strm_data ),
             .ivalid ( arbitrated_strm_valid ),
             .iready ( arbitrated_strm_ready ),
             .odata ( ctl_event_strm_data ),
             .ovalid ( ctl_event_strm_valid ),
             .oready ( ctl_event_strm_ready ),
             .clk ( clk ),
             .resetn ( resetn )
         );

         fifo #(
             .DW ( 32 ),
             .DL ( NOTIFICATION_FIFO_DEPTH_LOG )
         ) rx_req_fifo (
             .idata ( notification_rx_cmd_data ),
             .ivalid ( notification_rx_cmd_valid ),
             .iready ( notification_rx_cmd_ready ),
             .odata ( rx_req_tdata ),
             .ovalid ( rx_req_tvalid ),
             .oready ( rx_req_tready ),
             .clk ( clk ),
             .resetn ( resetn )
         );

         wire        rx_out_session_id_valid;
         wire        rx_out_session_id_ready;
         fifo #(
             .DW ( CH_NUM_LOG ),
             .DL ( RX_RSP_FIFO_DEPTH_LOG )
         ) rx_session_id_fifo (
             .idata ( rx_rsp_tdata[CH_NUM_LOG-1:0] ),
             .ivalid ( rx_rsp_tvalid ),
             .iready ( rx_rsp_tready ),
             .odata ( rx_out_tuser ),
             .ovalid ( rx_out_session_id_valid ),
             .oready ( rx_out_session_id_ready ),
             .clk ( clk ),
             .resetn ( resetn )
         );
         wire        rx_out_data_valid;
         wire        rx_out_data_ready;
         fifo #(
             .DW ( DW + KW + 1 ),
             .DL ( RX_DATA_FIFO_DEPTH_LOG )
         ) rx_data_fifo (
             .idata ( {rx_in_tlast, rx_in_tkeep, rx_in_tdata} ),
             .ivalid ( rx_in_tvalid ),
             .iready ( rx_in_tready ),
             .odata ( {rx_out_tlast, rx_out_tkeep, rx_out_tdata} ),
             .ovalid ( rx_out_data_valid ),
             .oready ( rx_out_data_ready ),
             .clk ( clk ),
             .resetn ( resetn )
         );

         assign rx_out_tvalid = rx_out_session_id_valid & rx_out_data_valid;
         assign rx_out_session_id_ready = rx_out_data_valid & rx_out_tready & rx_out_tlast;
         assign rx_out_data_ready = rx_out_session_id_valid & rx_out_tready;
      end else begin // if (ENABLE_TOE != 0)
	     assign open_req_tvalid = 1'b0;
	     assign close_conn_tvalid = 1'b0;
	     assign listen_req_tvalid = 1'b0;
	     assign open_status_tready = 1'b1;
	     assign listen_status_tready = 1'b1;
	     assign notification_tready = 1'b1;
	     assign toe_rdata = 32'hdeadbeef;
	     assign toe_int = 1'b0;
         assign toe_rdata_valid = 1'b1;
         assign ctl_event_strm_data = 'd0;
         assign ctl_event_strm_valid = 1'b0;
      end
   endgenerate

   generate
      if (ENABLE_TOE_HW_APP != 0) begin : toe_hw_app_block
         reg event_ready;
         reg tx_rsp_ready;
         assign tx_req_tdata = axis_tcp_cmd_tdata[31:0];
         assign tx_req_tvalid = axis_tcp_cmd_tvalid;
         assign axis_tcp_cmd_tready = tx_req_tready;

         // tcp reponse
         always @(posedge clk) begin
            if (~resetn) begin
               axis_tcp_rsp_tdata <= 88'd0;
               axis_tcp_rsp_tvalid <= 1'b0;
            end else if (tx_rsp_tvalid & tx_rsp_tready) begin
               axis_tcp_rsp_tdata <= {5'h0, tx_rsp_tdata[63:62] == 2'h1, 2'h0, 48'd0,
                                      |tx_rsp_tdata[63:62] ? 16'd0 : tx_rsp_tdata[31:16], tx_rsp_tdata[15:0]};
               axis_tcp_rsp_tvalid <= 1'b1;
            end else if (ctl_event_strm_valid & ctl_event_strm_ready) begin
               axis_tcp_rsp_tdata <= {5'd0,
                                      1'b0, // closed
                                      ctl_event_strm_data[64], // close
                                      ctl_event_strm_data[65], // connected
                                      ctl_event_strm_data[63:16], // ip, port
                                      16'd0, // length
                                      ctl_event_strm_data[15:0]}; // session_id
               axis_tcp_rsp_tvalid <= 1'b1;
            end else begin
               axis_tcp_rsp_tvalid <= axis_tcp_rsp_tvalid & ~axis_tcp_rsp_tready;
            end
         end
         wire w_axis_tcp_rsp_tvalid = (tx_rsp_tvalid & tx_rsp_tready) | (ctl_event_strm_valid & ctl_event_strm_ready) |
              (axis_tcp_rsp_tvalid & ~axis_tcp_rsp_tready);
         always @(posedge clk) begin
            if (~resetn) begin
               event_ready <= 1'b0;
               tx_rsp_ready <= 1'b0;
            end else begin
               event_ready <= ~w_axis_tcp_rsp_tvalid;
               tx_rsp_ready <= ~w_axis_tcp_rsp_tvalid & ~(ctl_event_strm_valid & ctl_event_strm_ready);
            end
         end
         assign tx_rsp_tready = tx_rsp_ready;
         assign ctl_event_strm_ready = event_ready;
      end else begin // block: toe_app_block
	     assign tx_req_tvalid = 1'b0;
	     assign tx_rsp_tready = 1'b1;
      end
   endgenerate

endmodule
