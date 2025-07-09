/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module xdma_rd_switch #(
    parameter CH_NUM_LOG = 3,
    parameter DW = 512,
    parameter RQ_DW = 384,
    parameter RQ_DK = 12,
    parameter RC_DW = 352,
    parameter RCBASE = 96
    ) (
    input [RQ_DW-1:0]      queue_check_data,
    input [RQ_DK-1:0]      queue_check_keep,
    input                  queue_check_valid,
    output                 queue_check_ready,

    input [RQ_DW-1:0]      queue_rd_data,
    input [RQ_DK-1:0]      queue_rd_keep,
    input                  queue_rd_valid,
    output                 queue_rd_ready,

    output reg [RC_DW-1:0] queue_check_res_data,
    output reg             queue_check_res_valid,
    output reg [RC_DW-1:0] queue_rd_res_data,
    output reg             queue_rd_res_valid,

    output [15:0]          desc_ctl,
    output [63:0]          desc_dst_addr, // dummy
    output [63:0]          desc_src_addr,
    output [27:0]          desc_len,
    output                 desc_load,
    input                  desc_ready,

    input [DW-1:0]         rd_tdata,
    input [DW/8-1:0]       rd_tkeep,
    input                  rd_tlast,
    input                  rd_tvalid,
    output                 rd_tready,

    input [7:0]            sts,
    output [31:0]          done_count,

    input                  clk,
    input                  resetn
    );

   reg [63:0]          addr;
   reg [10:0]          len;
   reg                 valid;
   reg                 is_check;
   reg [2:0]           desc_wait;
   always @(posedge clk) begin
      if (~resetn) begin
         desc_wait <= 3'd4;
      end else begin
         if (~desc_ready || (~|desc_wait && desc_load)) begin
            desc_wait <= 3'd4;
         end else if (|desc_wait) begin
            desc_wait <= desc_wait - 1'b1;
         end
      end
   end
   always @(posedge clk) begin
      if (~resetn) begin
         valid <= 1'b0;
      end else if (queue_rd_valid & queue_rd_ready) begin
         addr <= {queue_rd_data[63:2], 2'd0};
         len <= queue_rd_data[74:64];
         valid <= 1'b1;
         is_check <= 1'b0;
      end else if (queue_check_valid & queue_check_ready) begin
         addr <= {queue_check_data[63:2], 2'd0};
         len <= queue_check_data[74:64];
         valid <= 1'b1;
         is_check <= 1'b1;
      end else begin
         valid <= 1'b0;
      end
   end

   wire fifo_ready;

   assign queue_rd_ready = ~valid && ~|desc_wait && desc_ready && fifo_ready;
   assign queue_check_ready = queue_rd_ready && ~queue_rd_valid;

   assign desc_ctl = 16'h0010; // eop
   assign desc_dst_addr = 64'd0;
   assign desc_src_addr = addr;
   assign desc_len = {14'd0, len, 2'd0};
   assign desc_load = valid;

   wire rdata_is_check;
   wire rdata_out_valid;
   wire rdata_out_ready;
   fifo #(
       .DW ( 1 ),
       .DL ( 6 )
   ) rd_port_fifo (
       .idata ( is_check ),
       .ivalid ( valid ),
       .iready ( fifo_ready ),
       .odata ( rdata_is_check ),
       .ovalid ( rdata_out_valid ),
       .oready ( rdata_out_ready ),
       .full ( ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   always @(posedge clk) begin
      if (~resetn) begin
         queue_check_res_valid <= 1'b0;
         queue_rd_res_valid <= 1'b0;
      end else if (rd_tvalid & rd_tready) begin
         if (rdata_is_check) begin
            queue_check_res_valid <= 1'b1;
            queue_rd_res_valid <= 1'b0;
            queue_check_res_data <= {'d0, rd_tdata, {RCBASE{1'b0}}};
         end else begin
            queue_check_res_valid <= 1'b0;
            queue_rd_res_valid <= 1'b1;
            queue_rd_res_data <= {'d0, rd_tdata, {RCBASE{1'b0}}};
         end
      end else begin
         queue_check_res_valid <= 1'b0;
         queue_rd_res_valid <= 1'b0;
      end
   end
   assign rd_tready = rdata_out_valid;
   assign rdata_out_ready = rd_tvalid;

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
