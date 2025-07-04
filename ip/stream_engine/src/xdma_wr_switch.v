/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module xdma_wr_switch #(
    parameter CH_NUM_LOG = 3,
    parameter DW = 512,
    parameter QEW = 32,
    parameter RQ_DW = 384,
    parameter RQ_DK = 12,
    parameter RQBASE = 128,
    parameter CH_POS = RQBASE + 32,
    parameter CPL_POS = RQBASE + 64
    ) (
    input [RQ_DW-1:0]            queue_update_data,
    input [RQ_DK-1:0]            queue_update_keep,
    input                        queue_update_valid,
    output                       queue_update_ready,

    input [RQ_DW-1:0]            queue_wr_data,
    input [RQ_DK-1:0]            queue_wr_keep,
    input                        queue_wr_valid,
    output                       queue_wr_ready,

    input [(1<<CH_NUM_LOG)-1:0]  head_tail_updates,

    output [15:0]                desc_ctl,
    output [63:0]                desc_dst_addr,
    output [63:0]                desc_src_addr, // dummy
    output [27:0]                desc_len,
    output                       desc_load,
    input                        desc_ready,

    output [DW-1:0]              wr_tdata,
    output [DW/8-1:0]            wr_tkeep,
    output                       wr_tlast,
    output                       wr_tvalid,
    input                        wr_tready,

    input [7:0]                  sts,
    output [31:0]                done_count,

    input [(64<<CH_NUM_LOG)-1:0] doorbell_addrs,
    input [(1<<CH_NUM_LOG)-1:0]  doorbell_int_enables,

    output [(1<<CH_NUM_LOG)-1:0] irq_out,
    input [(1<<CH_NUM_LOG)-1:0]  irq_ack,

    input                        clk,
    input                        resetn
    );

   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam QEWB = QEW*8;
   localparam KW = DW/8;

   reg [CH_NUM-1:0]              head_tail_doorbell_requests;
   reg [CH_NUM_LOG-1:0]          head_tail_doorbell_request_ch;
   wire [CH_NUM-1:0]             w_cur_head_tail_doorbell_requests;
   wire [CH_NUM_LOG-1:0]         w_head_tail_doorbell_request_ch_cand;
   wire [CH_NUM-1:0]             w_head_tail_doorbell_dones;
   always @(posedge clk) begin
      if (~resetn) begin
         head_tail_doorbell_requests <= 'd0;
         head_tail_doorbell_request_ch <= 'd0;
      end else begin
         head_tail_doorbell_requests <= (head_tail_doorbell_requests & ~w_head_tail_doorbell_dones) | head_tail_updates;
         head_tail_doorbell_request_ch <= w_head_tail_doorbell_request_ch_cand;
      end
   end
   assign w_cur_head_tail_doorbell_requests = {head_tail_doorbell_requests, head_tail_doorbell_requests} >> head_tail_doorbell_request_ch;
   assign w_head_tail_doorbell_request_ch_cand = w_cur_head_tail_doorbell_requests[0] ? head_tail_doorbell_request_ch :
                                                 w_cur_head_tail_doorbell_requests[1] ? head_tail_doorbell_request_ch + 1'b1 :
                                                 w_cur_head_tail_doorbell_requests[2] ? head_tail_doorbell_request_ch + 2'd2 :
                                                 w_cur_head_tail_doorbell_requests[3] ? head_tail_doorbell_request_ch + 2'd3 :
                                                 head_tail_doorbell_request_ch + 3'd4;

   // queue wr is prior
   reg [63:0]                    addr;
   reg [QEWB-1:0]                data;
   reg [QEW-1:0]                 keep;
   reg [10:0]                    len;
   reg                           valid;
   reg                           dvalid;
   reg                           need_int;
   reg [63:0]                    doorbell_addr;
   reg                           empty;
   reg                           head_tail_doorbell_valid;
   reg                           ready_d1;
   reg [2:0]                     desc_wait;
   wire                          ready = ready_d1 | desc_ready;
   wire                          w_cur_ch_head_tail_doorbell_req_valid = head_tail_doorbell_requests >> head_tail_doorbell_request_ch;
   always @(posedge clk) begin
      if (~resetn) begin
         ready_d1 <= 1'b0;
      end else begin
         ready_d1 <= desc_ready;
      end
   end
   always @(posedge clk) begin
      if (~resetn) begin
         desc_wait <= 3'd4;
         doorbell_addr <= 'd0;
         valid <= 1'b0;
         dvalid <= 1'b0;
         empty <= 1'b1;
         head_tail_doorbell_valid <= 1'b0;
      end else if (queue_wr_valid & queue_wr_ready) begin
         addr <= {queue_wr_data[63:2], 2'd0};
         data <= queue_wr_data[RQBASE+:QEWB];
         keep <= ({{QEW{1'b0}}, 1'b1} << {queue_wr_data[74:64], 2'd0}) - 1'b1;
         len <= queue_wr_data[74:64];
         valid <= 1'b1;
         dvalid <= 1'b1;
         empty <= 1'b0;
         desc_wait <= 3'd4;
      end else if (queue_update_valid & queue_update_ready) begin
         addr <= {queue_update_data[63:2], 2'd0};
         data <= {{QEWB-8{1'b0}}, queue_update_data[RQBASE+:8]};
         keep <= ({{QEW{1'b0}}, 1'b1} << {queue_update_data[74:64], 2'd0}) - 1'b1;
         len <= queue_update_data[74:64];
         if (queue_update_data[CPL_POS]) begin
            doorbell_addr <= doorbell_addrs >> {queue_update_data[CH_POS+:CH_NUM_LOG], 6'd0};
         end else begin
            doorbell_addr <= 'd0;
         end
         valid <= 1'b1;
         dvalid <= 1'b1;
         empty <= 1'b0;
         desc_wait <= 3'd4;
      end else if (empty && w_cur_ch_head_tail_doorbell_req_valid) begin
         doorbell_addr <= doorbell_addrs >> {head_tail_doorbell_request_ch, 6'd0};
         head_tail_doorbell_valid <= 1'b1;
         empty <= 1'b0;
         desc_wait <= 3'd4;
      end else begin
         head_tail_doorbell_valid <= 1'b0;
         valid <= 1'b0;
         dvalid <= dvalid & ~dready;
         if (|doorbell_addr && ~valid && ~dvalid && ~|desc_wait && desc_ready) begin
            addr <= doorbell_addr;
            data <= 'd0;
            len <= 'd1;
            keep <= {{QEW-4{1'b0}}, 4'hf};
            doorbell_addr <= 'd0;
            valid <= 1'b1;
            dvalid <= 1'b1;
            desc_wait <= 3'd4;
         end else begin
            if (~|doorbell_addr) begin
               if (~dvalid | dready) empty <= 1'b1;
            end
            if (~desc_ready) begin
               desc_wait <= 3'd4;
            end else if (|desc_wait) begin
               desc_wait <= desc_wait - 1'b1;
            end
         end
      end
   end
   assign queue_wr_ready = empty && ~|desc_wait && desc_ready;
   assign queue_update_ready = queue_wr_ready && ~queue_wr_valid;
   assign w_head_tail_doorbell_dones = {{CH_NUM-1{1'b0}}, head_tail_doorbell_valid} << head_tail_doorbell_request_ch;

   reg [CH_NUM-1:0] irq;
   always @(posedge clk) begin
      if (~resetn) begin
         irq <= 'd0;
      end else begin
         if (queue_update_valid & queue_update_ready & queue_update_data[CPL_POS]) begin
            irq <= (irq | (doorbell_int_enables & ({{CH_NUM{1'b0}}, 1'b1} << queue_update_data[CH_POS+:CH_NUM_LOG]))) & ~irq_ack;
         end else begin
            irq <= irq & ~irq_ack;
         end
      end
   end
   assign irq_out = irq;

   assign desc_ctl = 16'h0010; // eop
   assign desc_dst_addr = addr;
   assign desc_src_addr = 64'd0;
   assign desc_len = {14'd0, len, 2'd0};
   assign desc_load = valid;

   assign wr_tdata[DW-1:QEWB] = 'd0;
   assign wr_tdata[QEWB-1:0] = data;
   assign wr_tkeep[KW-1:QEW] = 'd0;
   assign wr_tkeep[QEW-1:0] = keep;
   assign wr_tlast = 1'b1;
   assign wr_tvalid = dvalid;
   assign dready = wr_tready;

   reg [31:0] counts;
   always @(posedge clk) begin
      if (~resetn) begin
         counts <= 'd0;
      end else if (sts[3]) begin
         counts <= counts + 1'b1;
      end
   end
   assign done_count = counts;

endmodule
