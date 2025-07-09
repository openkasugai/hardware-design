/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_xdma_rd_switch #(
    parameter CH_NUM_LOG = 3,
    parameter DW = 512,
    parameter QEW = 32,
    parameter CHECK_BITS = 1,
    parameter READ_BITS = 1,
    parameter DESC_BITS = 1,
    parameter DATA_BITS = 1,
    parameter STS_BITS = 1,
    parameter RES_DELAY = 100,
    parameter RD_MAX = 1000,
    parameter CHECK_MAX = 1000
    ) ();

   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam CHECK_BITS_MOD = CHECK_BITS > 0 ? CHECK_BITS : 1;
   localparam READ_BITS_MOD = READ_BITS > 0 ? READ_BITS : 1;
   localparam DESC_BITS_MOD = DESC_BITS > 0 ? DESC_BITS : 1;
   localparam DATA_BITS_MOD = DATA_BITS > 0 ? DATA_BITS : 1;
   localparam STS_BITS_MOD = STS_BITS > 0 ? STS_BITS : 1;

   localparam KW = DW/8;
   localparam QEWB = QEW * 8;
   localparam RQ_DW = 384;
   localparam RQ_DK = 12;
   localparam RC_DW = 352;
   localparam RCBASE = 96;

   reg [RQ_DW-1:0]            queue_check_data;
   reg [RQ_DK-1:0]            queue_check_keep;
   reg                        queue_check_valid;
   wire                       queue_check_ready;

   reg [RQ_DW-1:0]            queue_rd_data;
   reg [RQ_DK-1:0]            queue_rd_keep;
   reg                        queue_rd_valid;
   wire                       queue_rd_ready;

   wire [RC_DW-1:0]           queue_check_res_data;
   wire                       queue_check_res_valid;
   wire [RC_DW-1:0]           queue_rd_res_data;
   wire                       queue_rd_res_valid;

   wire [15:0]                desc_ctl;
   wire [63:0]                desc_dst_addr; // dummy
   wire [63:0]                desc_src_addr;
   wire [27:0]                desc_len;
   wire                       desc_load;
   reg                        desc_ready;

   reg [DW-1:0]               rd_tdata;
   reg [DW/8-1:0]             rd_tkeep;
   reg                        rd_tlast;
   reg                        rd_tvalid;
   wire                       rd_tready;

   reg [7:0]                  sts;
   wire [31:0]                done_count;

   wire                        clk;
   wire                        resetn;
   wire [31:0]                 rd;

   clk_reset clk_reset (
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
   );

   xdma_rd_switch #(
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .DW ( DW )
   ) dut (
       .*
   );

   initial begin
      queue_check_valid = 1'b0;
      queue_rd_valid = 1'b0;
      desc_ready = 1'b0;
      rd_tvalid = 1'b0;
      sts = 'd0;
   end

   reg [63:0] queue_check_addrs[0:255];
   reg [63:0] queue_check_datum[0:255];
   reg [63:0] queue_rd_addrs[0:255];
   reg [QEWB-1:0] queue_rd_datum[0:255];
   reg [7:0]      qc_wpos, qc_cpos, qc_dpos, qc_rpos;
   reg [7:0]      qr_wpos, qr_cpos, qr_dpos, qr_rpos;
   reg            desc_is_checks[0:255];
   reg [31:0]     desc_times[0:255];
   reg [7:0]      dc_wpos, dc_rpos;

   initial begin
      qc_wpos = 'd0;
      qc_cpos = 'd0;
      qc_dpos = 'd0;
      qc_rpos = 'd0;
      qr_wpos = 'd0;
      qr_cpos = 'd0;
      qr_dpos = 'd0;
      qr_rpos = 'd0;
      dc_wpos = 'd0;
      dc_rpos = 'd0;
   end

   reg [31:0] global_count;
   always @(posedge clk) begin
      if (~resetn) begin
         global_count <= 'd0;
      end else begin
         global_count <= global_count + 1'b1;
      end
   end

   reg desc_is_check;
   reg desc_is_rd;
   always @(desc_src_addr) begin
      desc_is_check = 1'b0;
      desc_is_rd = 1'b0;
      if (desc_src_addr === queue_check_addrs[qc_cpos]) begin
         desc_is_check = 1'b1;
      end else if (desc_src_addr === queue_rd_addrs[qr_cpos]) begin
         desc_is_rd = 1'b1;
      end
   end

   // descriptor out
   reg ready_d1;
   wire desc_axis_ready = ready_d1 | desc_ready;
   always @(posedge clk) begin
      if (~resetn) begin
         ready_d1 <= 1'b0;
      end else begin
         ready_d1 <= desc_ready;
         if (desc_load && desc_axis_ready) begin
            if (desc_is_check) begin
               if (desc_src_addr !== queue_check_addrs[qc_cpos] ||
                   desc_len !== 'd8) begin
                  $error("%d: desc check %h %h %h", $time, desc_src_addr, queue_check_addrs[qc_cpos], desc_len);
               end
               qc_cpos <= qc_cpos + 1'b1;
            end else if (desc_is_rd) begin
               if (desc_src_addr !== queue_rd_addrs[qr_cpos] ||
                   desc_len != QEW) begin
                  $error("%d: desc rd %h %h %h", $time, desc_src_addr, queue_rd_addrs[qr_cpos], desc_len);
               end
               qr_cpos <= qr_cpos + 1'b1;
            end else begin
               $error("%d: desc unknown %h %h", $time, desc_src_addr, desc_len);
            end
            if (desc_is_check || desc_is_rd) begin
               desc_is_checks[dc_wpos] <= desc_is_check;
               desc_times[dc_wpos] <= global_count;
               dc_wpos <= dc_wpos + 1'b1;
            end
         end
         desc_ready <= (DESC_BITS > 0 ? &rd[8+:DESC_BITS_MOD] : 1'b1) &&
                       ((dc_wpos + 1'b1) & 255) != dc_rpos &&
                       ((dc_wpos + 2'd2) & 255) != dc_rpos;
      end
   end

   // queue check rdata
   always @(posedge clk) begin
      if (resetn) begin
         if (queue_check_res_valid) begin
            if (queue_check_res_data[RCBASE+:64] !== queue_check_datum[qc_rpos]) begin
               $error("%d: check data %h %h", $time, queue_check_res_data, queue_check_datum[qc_rpos]);
            end
            qc_rpos <= qc_rpos + 1'b1;
         end
      end
   end

   // queue rd rdata
   always @(posedge clk) begin
      if (resetn) begin
         if (queue_rd_res_valid) begin
            if (queue_rd_res_data[RC_DW-1:RCBASE] !== queue_rd_datum[qr_rpos]) begin
               $error("%d: rd data %h %h", $time, queue_rd_res_data, queue_rd_datum[qr_rpos]);
            end
            qr_rpos <= qr_rpos + 1'b1;
         end
      end
   end

   task static queue_rd_generate;
      int rd_count = 0;
      logic [63:0] addr;
      logic [10:0] len;
      logic [QEWB-1:0] qe;
      logic            valid;

      while (rd_count < RD_MAX || queue_rd_valid) @(posedge clk) begin
         if (~queue_rd_valid || queue_rd_ready) begin
            valid = ((qr_wpos + 1'b1) & 255) != qr_rpos;
            valid = valid && (READ_BITS > 0 ? &rd[20+:READ_BITS_MOD] : 1'b1);
            valid = valid && rd_count < RD_MAX;
            if (valid) begin
               addr = {rd, rd, 2'd0};
               for (int i=0; i<QEWB; i+=32) begin
                  qe[i+:32] = rd ^ (32'h1001 << i/32);
               end
               len = QEW/4;
               queue_rd_data[63:0] <= addr;
               queue_rd_data[74:64] <= len;
               queue_rd_data[RQ_DW-1:75] <= 'd0;
               queue_rd_valid <= 1'b1;
               queue_rd_addrs[qr_wpos] <= addr;
               queue_rd_datum[qr_wpos] <= qe;
               qr_wpos <= qr_wpos + 1'b1;
            end else begin
               queue_rd_valid <= queue_rd_valid & ~queue_rd_ready;
            end
            if (queue_rd_valid & queue_rd_ready) rd_count++;
         end
      end
   endtask

   task static queue_check_generate;
      int check_count = 0;
      logic [63:0] addr;
      logic [10:0] len;
      logic [63:0] cdata;
      logic        valid;

      while (check_count < CHECK_MAX || queue_check_valid) @(posedge clk) begin
         if (~queue_check_valid || queue_check_ready) begin
            valid = ((qc_wpos + 1'b1) & 255) != qc_rpos;
            valid = valid && (CHECK_BITS > 0 ? &rd[10+:CHECK_BITS_MOD] : 1'b1);
            valid = valid && check_count < CHECK_MAX;
            if (valid) begin
               addr = {rd, rd, rd[31:10], 2'd0};
               cdata[31:0] = rd;
               cdata[63:32] = rd ^ 32'hdeadbeef;
               len = 2;
               queue_check_data[63:0] <= addr;
               queue_check_data[74:64] <= len;
               queue_check_data[RQ_DW-1:75] <= 'd0;
               queue_check_valid <= 1'b1;
               queue_check_addrs[qc_wpos] <= addr;
               queue_check_datum[qc_wpos] <= cdata;
               qc_wpos <= qc_wpos + 1'b1;
            end else begin
               queue_check_valid <= queue_check_valid & ~queue_check_ready;
            end
            if (queue_check_valid & queue_check_ready) check_count++;
         end
      end
   endtask

   task static read_data_generate;
      int rdata_count = 0;
      logic valid;

      while (rdata_count < CHECK_MAX + RD_MAX || rd_tvalid) @(posedge clk) begin
         if (~rd_tvalid || rd_tready) begin
            valid = dc_rpos != dc_wpos && desc_times[dc_rpos] + RES_DELAY <= global_count;
            valid = valid && (DATA_BITS > 0 ? &rd[24+:DATA_BITS_MOD] : 1'b1);
            valid = valid && rdata_count < CHECK_MAX + RD_MAX;
            if (valid) begin
               if (desc_is_checks[dc_rpos]) begin
                  rd_tdata <= {'d0, queue_check_datum[qc_dpos]};
                  rd_tkeep <= {'d0, 8'hff};
                  qc_dpos <= qc_dpos + 1'b1;
               end else begin
                  rd_tdata <= {'d0, queue_rd_datum[qr_dpos]};
                  rd_tkeep <= {'d0, {QEW{1'b1}}};
                  qr_dpos <= qr_dpos + 1'b1;
               end
               dc_rpos <= dc_rpos + 1'b1;
               rd_tlast <= 1'b1;
               rd_tvalid <= 1'b1;
            end else begin
               rd_tvalid <= rd_tvalid & ~rd_tready;
            end
            if (rd_tvalid & rd_tready) rdata_count++;
         end
         sts <= rd_tvalid & rd_tready ? 8'h8 : 8'd0;
      end
   endtask

   initial begin
      @(posedge clk);
      while (~resetn) @(posedge clk);

      fork
         begin
            queue_rd_generate();
         end
         begin
            queue_check_generate();
         end
         begin
            read_data_generate();
         end
      join

      while (done_count < RD_MAX + CHECK_MAX) @(posedge clk);

      $finish;
   end

endmodule

module test_xdma_rd_switch_fast;
   tb_xdma_rd_switch #(
       .CHECK_BITS ( 0 ),
       .READ_BITS ( 0 ),
       .STS_BITS ( 0 ),
       .DATA_BITS ( 0 ),
       .DESC_BITS ( 0 )
   ) tb ();
endmodule

module test_xdma_rd_switch_random;
   tb_xdma_rd_switch tb();
endmodule

module test_xdma_rd_switch_slow_in;
   tb_xdma_rd_switch #(
       .CHECK_BITS ( 2 ),
       .READ_BITS ( 3 ),
       .STS_BITS ( 2 ),
       .DATA_BITS ( 2 ),
       .RD_MAX ( 500 )
   ) tb ();
endmodule

module test_xdma_rd_switch_slow_out;
   tb_xdma_rd_switch #(
       .DESC_BITS ( 2 )
   ) tb ();
endmodule
