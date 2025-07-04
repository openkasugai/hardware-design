/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_xdma_rx_switch #(
    parameter CH_NUM_LOG = 3,
    parameter DW = 512,
    parameter DATA_FIFO_DL = 7,
    parameter CPL_FIFO_DL = 4,
    parameter DESC_FIFO_DL = 4,
    parameter STS_FIFO_DL = 7,
    parameter BURST_MAX = 4,
    parameter DESC_MAX = 4,
    parameter DESC_RQ_DW = 512,
    parameter DESC_RQ_DK = 16,
    parameter DESC_RC_DW = 512,
    parameter DESC_RC_DK = 16,
    parameter CH_BASE = 0,
    parameter REQ_BITS = 1,
    parameter OUT_BITS = 1,
    parameter CPL_BITS = 1,
    parameter DIN_BITS = 1,
    parameter DOUT_BITS = 1,
    parameter DESC_BITS = 1,
    parameter STS_BITS = 1,
    parameter FRAME_MAX = 100,
    parameter SIZE_BITS = 14,
    parameter RCBASE = 96,
    parameter RES_DELAY = 100
    ) ();

   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam KW = DW/8;
   localparam KW_LOG = $clog2(KW);
   localparam REQ_BITS_MOD = REQ_BITS > 0 ? REQ_BITS : 1'b1;
   localparam OUT_BITS_MOD = OUT_BITS > 0 ? OUT_BITS : 1'b1;
   localparam CPL_BITS_MOD = CPL_BITS > 0 ? CPL_BITS : 1'b1;
   localparam DIN_BITS_MOD = DIN_BITS > 0 ? DIN_BITS : 1'b1;
   localparam DOUT_BITS_MOD = DOUT_BITS > 0 ? DOUT_BITS : 1'b1;
   localparam STS_BITS_MOD = STS_BITS > 0 ? STS_BITS : 1'b1;
   localparam DESC_BITS_MOD = DESC_BITS > 0 ? DESC_BITS : 1'b1;

   reg [(1<<CH_NUM_LOG)-1:0] stream_ch_valids;

   wire [DESC_RQ_DW-1:0]     desc_req_data;
   wire [DESC_RQ_DK-1:0]     desc_req_keep;
   wire                      desc_req_valid;
   reg                       desc_req_ready;

   reg [DESC_RC_DW-1:0]      desc_out_data;
   reg [DESC_RC_DK-1:0]      desc_out_keep;
   reg                       desc_out_last;
   reg                       desc_out_valid;
   wire                      desc_out_ready;

   wire [31:0]               desc_cpl_data;
   wire [CH_NUM_LOG-1:0]     desc_cpl_ch;
   wire                      desc_cpl_valid;
   reg                       desc_cpl_ready;

   reg [DW-1:0]              rx_in_tdata;
   reg [DW/8-1:0]            rx_in_tkeep;
   reg                       rx_in_tlast;
   reg                       rx_in_tvalid;
   wire                      rx_in_tready;

   wire [15:0]               desc_ctl;
   wire [63:0]               desc_src_addr;
   wire [63:0]               desc_dst_addr;
   wire [27:0]               desc_len;
   wire                      desc_load;
   reg                       desc_ready;

   reg [DW-1:0]              rx_d2d_tdata;
   reg [DW/8-1:0]            rx_d2d_tkeep;
   reg [CH_NUM_LOG-1:0]      rx_d2d_tuser;
   reg                       rx_d2d_tlast;
   reg                       rx_d2d_tvalid;
   reg                       rx_d2d_eof;
   wire                      rx_d2d_tready;

   wire [DW-1:0]             rx_out_tdata;
   wire [DW/8-1:0]           rx_out_tkeep;
   wire [CH_NUM_LOG-1:0]     rx_out_tuser;
   wire                      rx_out_tlast;
   wire                      rx_out_eof;
   wire                      rx_out_tvalid;
   reg                       rx_out_tready;

   reg [7:0]                 sts;

   wire                  clk;
   wire                  resetn;
   wire [31:0]           rd;

   clk_reset clk_reset (
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
   );

   xdma_rx_switch #(
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .DW ( DW ),
       .DATA_FIFO_DL ( DATA_FIFO_DL ),
       .CPL_FIFO_DL ( CPL_FIFO_DL ),
       .DESC_FIFO_DL ( DESC_FIFO_DL ),
       .STS_FIFO_DL ( STS_FIFO_DL ),
       .BURST_MAX ( BURST_MAX ),
       .DESC_MAX ( DESC_MAX ),
       .CH_BASE ( CH_BASE )
   ) dut (
       .*
   );

   initial begin
      desc_req_ready = 1'b0;
      desc_out_valid = 1'b0;
      desc_cpl_ready = 1'b1;
      rx_in_tvalid = 1'b0;
      rx_out_tready = 1'b1;
      desc_ready = 1'b0;
      sts = 'd0;
      rx_d2d_tvalid = 1'b0;
   end

   reg [31:0] global_count;
   always @(posedge clk) begin
      if (~resetn) global_count <= 'd0;
      else global_count <= global_count + 1'b1;
   end

   reg [63:0]            desc_addrs[0:CH_NUM-1][0:255];
   reg [31:0]            desc_sizes[0:CH_NUM-1][0:255];
   reg [7:0]             desc_wpos[0:CH_NUM-1];
   reg [7:0]             desc_cpos[0:CH_NUM-1];
   reg [7:0]             desc_rpos[0:CH_NUM-1];

   reg [63:0]            desc_addr_starts[0:CH_NUM-1];
   reg [63:0]            desc_addr_ends[0:CH_NUM-1];
   reg                   desc_addr_range_valids[0:CH_NUM-1];

   reg [63:0]            dut_desc_addr_saves[0:255];
   reg [27:0]            dut_desc_len_saves[0:255];
   reg [CH_NUM_LOG-1:0]  dut_desc_ch_saves[0:255];
   reg                   dut_desc_eof_saves[0:255];
   reg [31:0]            dut_desc_times[0:255];
   reg [7:0]             dut_desc_wpos, dut_desc_rpos;

   reg [DW-1:0]          data_saves[0:255];
   reg [KW-1:0]          keep_saves[0:255];
   reg [CH_NUM_LOG-1:0]  user_saves[0:255];
   reg                   last_saves[0:255];
   reg [7:0]             st_wpos, st_rpos;

   reg [DW-1:0]          d2d_data_saves[0:255];
   reg [KW-1:0]          d2d_keep_saves[0:255];
   reg [CH_NUM_LOG-1:0]  d2d_user_saves[0:255];
   reg                   d2d_last_saves[0:255];
   reg                   d2d_eof_saves[0:255];
   reg [7:0]             d2d_st_wpos, d2d_st_rpos;

   reg [31:0]            desc_done_num, sts_num;

   initial begin
      for (int i=0; i<CH_NUM; i++) begin
         desc_wpos[i] = 'd0;
         desc_cpos[i] = 'd0;
         desc_rpos[i] = 'd0;
         desc_addr_range_valids[i] = 1'b0;
      end
      st_wpos = 'd0;
      st_rpos = 'd0;
      d2d_st_wpos = 'd0;
      d2d_st_rpos = 'd0;
      dut_desc_wpos = 'd0;
      dut_desc_rpos = 'd0;
      stream_ch_valids = 'd0;
      desc_done_num = 'd0;
      sts_num = 'd0;
   end

   reg desc_ready_d1;
   wire desc_ready_mod = desc_ready | desc_ready_d1;
   always @(posedge clk) begin
      if (~resetn) begin
         desc_ready_d1 <= 1'b0;
      end else begin
         desc_ready_d1 <= desc_ready;
         desc_ready <= DESC_BITS > 0 ? &rd[12+:DESC_BITS_MOD] : 1'b1;
      end
   end

   // cpl check
   reg [31:0] cpl_num;
   always @(posedge clk) begin
      if (~resetn) begin
         cpl_num <= 'd0;
      end else begin
         if (desc_cpl_valid & desc_cpl_ready) begin
            if (desc_cpl_data !== desc_sizes[desc_cpl_ch][desc_rpos[desc_cpl_ch]]) begin
               $error("%d: cpl [%2h] %h %h", $time, desc_cpl_ch, desc_cpl_data, desc_sizes[desc_cpl_ch][desc_rpos[desc_cpl_ch]]);
            end
            cpl_num <= cpl_num + 1'b1;
            desc_rpos[desc_cpl_ch] <= desc_rpos[desc_cpl_ch] + 1'b1;
         end
         desc_cpl_ready <= CPL_BITS > 0 ? &rd[17+:CPL_BITS_MOD] : 1'b1;
      end
   end

   // data check
   always @(posedge clk) begin
      if (resetn && rx_out_tvalid && rx_out_tready) begin
         if (rx_out_tdata === data_saves[st_rpos]) begin
            if (rx_out_tkeep !== keep_saves[st_rpos] ||
                rx_out_tuser !== user_saves[st_rpos] ||
                rx_out_tlast !== last_saves[st_rpos]) begin
               $error("%d: data %h %h, %h %h, %h %h, %h %h", $time,
                      rx_out_tdata, data_saves[st_rpos],
                      rx_out_tkeep, keep_saves[st_rpos],
                      rx_out_tuser, user_saves[st_rpos],
                      rx_out_tlast, last_saves[st_rpos]);
            end
            st_rpos <= st_rpos + 1'b1;
         end else if (rx_out_tdata === d2d_data_saves[d2d_st_rpos]) begin
            if (rx_out_tkeep !== d2d_keep_saves[d2d_st_rpos] ||
                rx_out_tuser !== d2d_user_saves[d2d_st_rpos] ||
                rx_out_tlast !== d2d_last_saves[d2d_st_rpos]) begin
               $error("%d: data %h %h, %h %h, %h %h, %h %h", $time,
                      rx_out_tdata, d2d_data_saves[d2d_st_rpos],
                      rx_out_tkeep, d2d_keep_saves[d2d_st_rpos],
                      rx_out_tuser, d2d_user_saves[d2d_st_rpos],
                      rx_out_tlast, d2d_last_saves[d2d_st_rpos]);
            end
            d2d_st_rpos <= d2d_st_rpos + 1'b1;
         end else begin
            $error("%d: data %h %h, %h %h, %h %h, %h %h", $time,
                   rx_out_tdata, data_saves[st_rpos],
                   rx_out_tkeep, keep_saves[st_rpos],
                   rx_out_tuser, user_saves[st_rpos],
                   rx_out_tlast, last_saves[st_rpos]);
            $error("%d: data %h %h, %h %h, %h %h, %h %h", $time,
                   rx_out_tdata, d2d_data_saves[d2d_st_rpos],
                   rx_out_tkeep, d2d_keep_saves[d2d_st_rpos],
                   rx_out_tuser, d2d_user_saves[d2d_st_rpos],
                   rx_out_tlast, d2d_last_saves[d2d_st_rpos]);
         end
      end
      if (resetn) begin
         rx_out_tready <= DOUT_BITS > 0 ? &rd[21+:DOUT_BITS_MOD] : 1'b1;
      end
   end

   // sts
   always @(posedge clk) begin
      if (resetn) begin
         if (desc_done_num > sts_num && (STS_BITS > 0 ? &rd[8+:STS_BITS_MOD] : 1'b1)) begin
            sts <= 8'd8;
            sts_num <= sts_num + 1'b1;
         end else begin
            sts <= 'd0;
         end
      end
   end

   task static setup_ch_valids;
      // same as tx switch
      stream_ch_valids = 'd0;
      while (~|stream_ch_valids) begin
         for (int i=0; i<CH_NUM; i++) @(posedge clk) begin
            stream_ch_valids[i] <= rd[i&31];
         end
      end
   endtask

   task static frame_generate;
      // same as tx switch
      int frame_count = 0;
      logic [63:0] addr;
      logic [31:0] size;
      logic [CH_NUM_LOG-1:0] ch;
      logic                  valid;
      logic                  cont = 0;
      logic [7:0]            request_wpos = 0;
      logic [7:0]            request_rpos = 0;
      logic [CH_NUM_LOG-1:0] request_chs[0:255];

      while (frame_count < FRAME_MAX || desc_out_valid) @(posedge clk) begin
         if (desc_req_valid & desc_req_ready) begin
            request_chs[request_wpos] <= desc_req_data[103:96] - CH_BASE;
            request_wpos <= request_wpos + 1'b1;
            $display("%d: desc_req(%3d) %h", $time, request_wpos, desc_req_data[103:96]);
         end
         if (request_rpos != request_wpos && (~desc_out_valid || desc_out_ready)) begin
            valid = OUT_BITS > 0 ? &rd[9+:OUT_BITS_MOD] : 1'b1;
            if (~cont) begin
               size = frame_count < FRAME_MAX ? 'd0 | rd[8+:SIZE_BITS] : 'd0;
               addr = {rd, rd, 2'd0};
               if (((addr + size) >> 32) != (addr >> 32)) valid = 1'b0;
               if (valid) begin
                  desc_out_data[RCBASE+:128] <= {addr, size, 15'd0, |size, 16'd0};
                  desc_out_last <= 1'b0;
                  cont <= 1'b1;
                  ch = request_chs[request_rpos];
                  desc_addrs[ch][desc_wpos[ch]] <= addr;
                  desc_sizes[ch][desc_wpos[ch]] <= size;
                  desc_wpos[ch] <= desc_wpos[ch] + 1'b1;
                  $display("%d: desc_out(%3d) %h %h", $time, request_rpos, addr, size);
               end
            end else begin
               desc_out_data[RCBASE+:128] <= {rd, rd, rd, rd};
               desc_out_last <= 1'b1;
               cont <= cont & ~valid;
               request_rpos <= request_rpos + valid;
            end
            desc_out_valid <= valid;
         end else begin
            desc_out_valid <= desc_out_valid & ~desc_out_ready;
         end
         if (desc_out_valid & desc_out_ready & desc_out_last) frame_count++;
         desc_req_ready <= ((request_wpos + 1'b1) & 255) != request_rpos &&
                           (REQ_BITS > 0 ? &rd[3+:REQ_BITS_MOD] : 1'b1);
      end
   endtask

   task static desc_check;
      int desc_count = 0;
      logic [63:0] addr;
      logic [27:0] len;
      logic [CH_NUM_LOG-1:0] ch;
      logic                  frame_end;
      logic                  valid;
      logic                  hit;

      while (desc_count < FRAME_MAX) @(posedge clk) begin
         hit = 0;
         frame_end = 0;
         for (int i=0; i<CH_NUM; i++) begin
            if (~desc_addr_range_valids[i] && desc_wpos[i] !== desc_cpos[i]) begin
               desc_addr_range_valids[i] = 1'b1;
               desc_cpos[i] <= desc_cpos[i] + 1'b1;
               desc_addr_starts[i] = desc_addrs[i][desc_cpos[i]];
               desc_addr_ends[i] = desc_addrs[i][desc_cpos[i]] + desc_sizes[i][desc_cpos[i]];
               $display("%d: desc start (%2h) %h %h %h", $time, i, desc_addrs[i][desc_cpos[i]],
                        desc_sizes[i][desc_cpos[i]], desc_addrs[i][desc_cpos[i]] + desc_sizes[i][desc_cpos[i]]);
            end
         end
         if (desc_load && desc_ready_mod) begin
            for (int i=0; i<CH_NUM; i++) begin
               if (desc_src_addr == desc_addr_starts[i]) begin
                  hit = 1'b1;
                  ch = i;
                  desc_addr_starts[i] += desc_len;
                  if (desc_addr_starts[i] == desc_addr_ends[i]) begin
                     frame_end = 1'b1;
                     desc_addr_range_valids[i] = 1'b0;
                     desc_count++;
                  end
                  break;
               end
            end
            if (!hit) begin
               $error("%d: desc unknown ch: %h %h", $time, desc_src_addr, desc_len);
            end else begin
               dut_desc_addr_saves[dut_desc_wpos] <= desc_src_addr;
               dut_desc_len_saves[dut_desc_wpos] <= desc_len;
               dut_desc_ch_saves[dut_desc_wpos] <= ch;
               dut_desc_times[dut_desc_wpos] <= global_count;
               dut_desc_eof_saves[dut_desc_wpos] <= frame_end;
               dut_desc_wpos <= dut_desc_wpos + 1'b1;
            end
         end
      end
   endtask

   task static data_generate;
      int data_frame_count = 0;
      logic [27:0] size = 0;
      logic [CH_NUM_LOG-1:0] ch;
      logic [DW-1:0]         data;
      logic [KW-1:0]         keep;
      logic                  last;
      logic                  eof;
      logic                  valid;
      logic [31:0]           gtime;
      logic [KW_LOG:0]       len;

      while (data_frame_count < FRAME_MAX || rx_in_tvalid || valid) @(posedge clk) begin
         if (~|size && dut_desc_wpos != dut_desc_rpos) begin
            size = dut_desc_len_saves[dut_desc_rpos];
            ch = dut_desc_ch_saves[dut_desc_rpos];
            eof = dut_desc_eof_saves[dut_desc_rpos];
            gtime = dut_desc_times[dut_desc_rpos];
            dut_desc_rpos++;
         end
         if (~rx_in_tvalid || rx_in_tready) begin
            valid = |size && gtime + RES_DELAY <= global_count;
            valid = valid && (DIN_BITS > 0 ? &rd[10+:DIN_BITS_MOD] : 1'b1);
            valid = valid && ((st_wpos + 1) & 255) != st_rpos;
            rx_in_tvalid <= valid;
            if (valid) begin
               last = size <= KW;
               len = last ? size : KW;
               for (int i=0; i<DW; i+=8) begin
                  data[i+:8] = rd[(i&31)+:8] & {8{(i/8 < len)}};
               end
               keep = ({{KW{1'b0}}, 1'b1} << len) - 1'b1;
               rx_in_tdata <= data;
               rx_in_tkeep <= keep;
               rx_in_tlast <= last;
               data_saves[st_wpos] <= data;
               keep_saves[st_wpos] <= keep;
               user_saves[st_wpos] <= ch;
               last_saves[st_wpos] <= last;
               st_wpos <= st_wpos + 1'b1;
               size -= len;
               if (eof && ~|size) data_frame_count++;
               if (last) desc_done_num++;
            end
         end else begin
            rx_in_tvalid <= rx_in_tvalid & ~rx_in_tready;
         end
      end
   endtask

   task static d2d_data_generate;
      int d2d_data_count = 0;
      logic [27:0] size = 0;
      logic [CH_NUM_LOG-1:0] ch;
      logic [DW-1:0]         data;
      logic [KW-1:0]         keep;
      logic                  last;
      logic                  eof;
      logic                  valid;
      logic [31:0]           gtime;
      logic [KW_LOG:0]       len;

      while (d2d_data_count < FRAME_MAX || rx_d2d_tvalid || valid) @(posedge clk) begin
         if (~|size && d2d_data_count < FRAME_MAX) begin
            size = rd[11+:SIZE_BITS] > {1'b0, {BURST_MAX+KW_LOG{1'b0}}} ? {'d1, {BURST_MAX+KW_LOG{1'b0}}} : rd[11+:SIZE_BITS];
            ch = rd[15+:CH_NUM_LOG];
            eof = rd[21];
         end
         if (~rx_d2d_tvalid || rx_d2d_tready) begin
            valid = |size;
            valid = valid && (DIN_BITS > 0 ? &rd[6+:DIN_BITS_MOD] : 1'b1);
            valid = valid && ((d2d_st_wpos + 1) & 255) != d2d_st_rpos;
            rx_d2d_tvalid <= valid;
            if (valid) begin
               last = size <= KW;
               len = last ? size : KW;
               for (int i=0; i<DW; i+=8) begin
                  data[i+:8] = rd[((i+8)&31)+:8] & {8{(i/8 < len)}};
               end
               keep = ({{KW{1'b0}}, 1'b1} << len) - 1'b1;
               rx_d2d_tdata <= data;
               rx_d2d_tkeep <= keep;
               rx_d2d_tuser <= ch;
               rx_d2d_tlast <= last;
               rx_d2d_eof <= last && eof;
               d2d_data_saves[d2d_st_wpos] <= data;
               d2d_keep_saves[d2d_st_wpos] <= keep;
               d2d_user_saves[d2d_st_wpos] <= ch;
               d2d_last_saves[d2d_st_wpos] <= last;
               d2d_eof_saves[d2d_st_wpos] <= eof;
               d2d_st_wpos <= d2d_st_wpos + 1'b1;
               size -= len;
               if (eof && ~|size) d2d_data_count++;
            end
         end else begin
            rx_d2d_tvalid <= rx_d2d_tvalid & ~rx_d2d_tready;
         end
      end
   endtask

   initial begin
      @(posedge clk);
      while (~resetn) @(posedge clk);

      setup_ch_valids();

      fork
         begin
            frame_generate();
         end
         begin
            data_generate();
         end
         begin
            d2d_data_generate();
         end
         begin
            desc_check();
         end
      join

      while (cpl_num < FRAME_MAX) @(posedge clk);

      $finish;
   end

endmodule

module test_xdma_rx_switch_fast;
   tb_xdma_rx_switch #(
       .REQ_BITS ( 0 ),
       .OUT_BITS ( 0 ),
       .CPL_BITS ( 0 ),
       .DIN_BITS ( 0 ),
       .DOUT_BITS ( 0 ),
       .DESC_BITS ( 0 ),
       .STS_BITS ( 0 )
   ) tb ();
endmodule

module test_xdma_rx_switch_random;
   tb_xdma_rx_switch tb();
endmodule

module test_xdma_rx_switch_slow_in;
   tb_xdma_rx_switch #(
       .REQ_BITS ( 1 ),
       .OUT_BITS ( 3 ),
       .CPL_BITS ( 1 ),
       .DIN_BITS ( 2 ),
       .DOUT_BITS ( 1 ),
       .DESC_BITS ( 1 ),
       .STS_BITS ( 3 )
   ) tb ();
endmodule

module test_xdma_rx_switch_slow_out;
   tb_xdma_rx_switch #(
       .REQ_BITS ( 3 ),
       .OUT_BITS ( 1 ),
       .CPL_BITS ( 3 ),
       .DIN_BITS ( 1 ),
       .DOUT_BITS ( 2 ),
       .DESC_BITS ( 3 ),
       .STS_BITS ( 1 )
   ) tb ();
endmodule
