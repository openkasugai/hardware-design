/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module route_control_reg_switch #(
    parameter ADDR_BITS = 16,
    parameter CTX_ID_BITS = 4
    ) (
    input [ADDR_BITS-1:0]    cfg_araddr,
    input                    cfg_arvalid,
    output                   cfg_arready,
    output [31:0]            cfg_rdata,
    output [1:0]             cfg_rresp,
    output                   cfg_rvalid,
    input                    cfg_rready,
    input [ADDR_BITS-1:0]    cfg_awaddr,
    input                    cfg_awvalid,
    output                   cfg_awready,
    input [31:0]             cfg_wdata,
    input                    cfg_wvalid,
    output                   cfg_wready,
    output [1:0]             cfg_bresp,
    output                   cfg_bvalid,
    input                    cfg_bready,

    output [CTX_ID_BITS+4:0] incoming_raddr,
    output                   incoming_arvalid,
    input [31:0]             incoming_rdata,
    input                    incoming_rvalid,
    output [CTX_ID_BITS+4:0] incoming_waddr,
    output [31:0]            incoming_wdata,
    output                   incoming_wvalid,

    output [CTX_ID_BITS+4:0] outgoing_raddr,
    output                   outgoing_arvalid,
    input [31:0]             outgoing_rdata,
    input                    outgoing_rvalid,
    output [CTX_ID_BITS+4:0] outgoing_waddr,
    output [31:0]            outgoing_wdata,
    output                   outgoing_wvalid,

    input                    clk,
    input                    resetn
    );

   localparam INCOMING_UPPER_ADDR = {(ADDR_BITS-CTX_ID_BITS-7){1'b0}};
   localparam OUTGOING_UPPER_ADDR = {1'b1, {(ADDR_BITS-CTX_ID_BITS-8){1'b0}}};

   reg [ADDR_BITS-1:0]       araddr;
   reg                       arvalid;
   reg                       arvalid_incoming;
   reg                       arvalid_outgoing;
   reg                       arvalid_other;
   reg [31:0]                rdata;
   reg                       rvalid;
   reg [ADDR_BITS-1:0]       awaddr;
   reg                       awvalid;
   reg [31:0]                wdata;
   reg                       wvalid;
   reg                       wvalid_incoming;
   reg                       wvalid_outgoing;
   reg                       bvalid;

   always @(posedge clk) begin
      if (~resetn) begin
         arvalid_incoming <= 1'b0;
         arvalid_outgoing <= 1'b0;
         arvalid_other <= 1'b0;
         arvalid <= 1'b0;
         rvalid <= 1'b0;
         awvalid <= 1'b0;
         wvalid <= 1'b0;
         wvalid_incoming <= 1'b0;
         wvalid_outgoing <= 1'b0;
         bvalid <= 1'b0;
      end else begin
         if (cfg_arvalid && cfg_arready) begin
            arvalid <= 1'b1;
            arvalid_incoming <= cfg_araddr[ADDR_BITS-1:CTX_ID_BITS+7] == INCOMING_UPPER_ADDR;
            arvalid_outgoing <= cfg_araddr[ADDR_BITS-1:CTX_ID_BITS+7] == OUTGOING_UPPER_ADDR;
            arvalid_other <= cfg_araddr[ADDR_BITS-1:CTX_ID_BITS+7] != INCOMING_UPPER_ADDR &&
                             cfg_araddr[ADDR_BITS-1:CTX_ID_BITS+7] != OUTGOING_UPPER_ADDR;
            araddr <= cfg_araddr;
         end else begin
            arvalid_incoming <= 1'b0;
            arvalid_outgoing <= 1'b0;
            arvalid_other <= 1'b0;
            arvalid <= arvalid & (~cfg_rvalid | ~cfg_rready);
         end
         if (incoming_rvalid) begin
            rdata <= incoming_rdata;
            rvalid <= 1'b1;
         end else if (outgoing_rvalid) begin
            rdata <= outgoing_rdata;
            rvalid <= 1'b1;
         end else if (arvalid_other)  begin
            rdata <= 32'hdeadbeef;
            rvalid <= 1'b1;
         end else begin
            rvalid <= rvalid & (~cfg_rvalid | ~cfg_rready);
         end
         if (cfg_awvalid && cfg_awready) begin
            awvalid <= 1'b1;
            awaddr <= cfg_awaddr;
         end else begin
            awvalid <= awvalid & ~wvalid;
         end
         if (cfg_wvalid && cfg_wready) begin
            wvalid <= 1'b1;
            wdata <= cfg_wdata;
         end else begin
            wvalid <= wvalid & ~awvalid;
         end
         bvalid <= (wvalid & awvalid) | (bvalid & ~cfg_bready);
         wvalid_incoming <= wvalid && awvalid && awaddr[ADDR_BITS-1:CTX_ID_BITS+7] == INCOMING_UPPER_ADDR;
         wvalid_outgoing <= wvalid && awvalid && awaddr[ADDR_BITS-1:CTX_ID_BITS+7] == OUTGOING_UPPER_ADDR;
      end
   end
   assign cfg_arready = ~arvalid;
   assign cfg_awready = ~awvalid;
   assign cfg_wready = ~wvalid;
   assign cfg_rdata = rdata;
   assign cfg_rvalid = rvalid;
   assign cfg_rresp = 2'd0;
   assign cfg_bresp = 2'd0;
   assign cfg_bvalid = bvalid;

   assign incoming_raddr = araddr[CTX_ID_BITS+6:2];
   assign incoming_arvalid = arvalid_incoming;
   assign incoming_waddr = awaddr[CTX_ID_BITS+6:2];
   assign incoming_wdata = wdata;
   assign incoming_wvalid = wvalid_incoming;

   assign outgoing_raddr = araddr[CTX_ID_BITS+6:2];
   assign outgoing_arvalid = arvalid_outgoing;
   assign outgoing_waddr = awaddr[CTX_ID_BITS+6:2];
   assign outgoing_wdata = wdata;
   assign outgoing_wvalid = wvalid_outgoing;

endmodule
