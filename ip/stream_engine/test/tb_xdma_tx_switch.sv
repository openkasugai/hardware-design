/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_xdma_tx_switch #(
    parameter CH_NUM_LOG = 3,
    parameter DW = 512,
    parameter DATA_FIFO_DL = 7,
    parameter CPL_FIFO_DL = 4,
    parameter DESC_FIFO_DL = 4,
    parameter STS_FIFO_DL = 7,
    parameter KDIV = 4,
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
    parameter BURST_BITS = 4,
    parameter SIZE_BITS = 14,
    parameter D2D_ENABLE = 1,
    parameter RCBASE = 96
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

   reg [CH_NUM-1:0] stream_ch_valids;
   reg [CH_NUM-1:0] stream_ch_d2d_valids;
   reg [CH_NUM*64-1:0] stream_cpl_q_bases;

   wire [DESC_RQ_DW-1:0] desc_req_data;
   wire [DESC_RQ_DK-1:0] desc_req_keep;
   wire                  desc_req_valid;
   reg                   desc_req_ready;

   reg [DESC_RC_DW-1:0]  desc_out_data;
   reg [DESC_RC_DK-1:0]  desc_out_keep;
   reg                   desc_out_last;
   reg                   desc_out_valid;
   wire                  desc_out_ready;

   wire [31:0]           desc_cpl_data;
   wire [CH_NUM_LOG-1:0] desc_cpl_ch;
   wire                  desc_cpl_valid;
   reg                   desc_cpl_ready;

   reg [DW-1:0]          tx_in_tdata;
   reg [KW-1:0]          tx_in_tkeep;
   reg [CH_NUM_LOG-1:0]  tx_in_tuser;
   reg                   tx_in_tlast;
   reg                   tx_in_sop;
   reg                   tx_in_eop;
   reg                   tx_in_tvalid;
   wire                  tx_in_tready;

   wire [15:0]           desc_ctl;
   wire [63:0]           desc_src_addr;
   wire [63:0]           desc_dst_addr;
   wire [27:0]           desc_len;
   wire                  desc_load;
   reg                   desc_ready;

   wire [DW-1:0]         tx_out_tdata;
   wire [KW-1:0]         tx_out_tkeep;
   wire                  tx_out_tlast;
   wire                  tx_out_tvalid;
   reg                   tx_out_tready;

   reg [7:0]             sts;

   wire                  clk;
   wire                  resetn;
   wire [31:0]           rd;

   clk_reset clk_reset (
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
   );

   xdma_tx_switch #(
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .DW ( DW ),
       .DATA_FIFO_DL ( DATA_FIFO_DL ),
       .CPL_FIFO_DL ( CPL_FIFO_DL ),
       .DESC_FIFO_DL ( DESC_FIFO_DL ),
       .STS_FIFO_DL ( STS_FIFO_DL ),
       .KDIV ( KDIV ),
       .DESC_MAX ( DESC_MAX ),
       .CH_BASE ( CH_BASE )
   ) dut (
       .*
   );

   initial begin
      desc_req_ready = 1'b1;
      desc_out_valid = 1'b0;
      desc_cpl_ready = 1'b1;
      tx_in_tvalid = 1'b0;
      tx_out_tready = 1'b1;
      desc_ready = 1'b0;
      sts = 'd0;
      stream_ch_valids = 'd0;
      stream_ch_d2d_valids = 'd0;
      stream_cpl_q_bases = 'd0;
   end

   reg [63:0]            desc_addrs[0:CH_NUM-1][0:255];
   reg [31:0]            desc_sizes[0:CH_NUM-1][0:255];
   reg                   desc_eofs[0:CH_NUM-1][0:255];
   reg [7:0]             desc_wpos[0:CH_NUM-1];
   reg [7:0]             desc_cpos[0:CH_NUM-1];
   reg [7:0]             desc_spos[0:CH_NUM-1];
   reg [7:0]             desc_rpos[0:CH_NUM-1];

   reg [63:0]            desc_addr_starts[0:CH_NUM-1];
   reg [63:0]            desc_addr_ends[0:CH_NUM-1];
   reg                   desc_addr_eofs[0:CH_NUM-1];
   reg                   desc_addr_range_valids[0:CH_NUM-1];

   reg [63:0]            dut_desc_addr_saves[0:255];
   reg [27:0]            dut_desc_len_saves[0:255];
   reg [63:0]            st_desc_addr_saves[0:255];
   reg [27:0]            st_desc_len_saves[0:255];
   reg [7:0]             dut_desc_wpos, dut_desc_rpos;
   reg [7:0]             st_desc_wpos, st_desc_rpos;

   reg [DW-1:0]          data_saves[0:255];
   reg [KW-1:0]          keep_saves[0:255];
   reg                   last_saves[0:255];
   reg [7:0]             st_wpos, st_rpos;

   reg [31:0]            st_end_num;
   reg [31:0]            desc_num;
   reg [31:0]            sts_num;

   initial begin
      for (int i=0; i<CH_NUM; i++) begin
         desc_wpos[i] = 'd0;
         desc_cpos[i] = 'd0;
         desc_spos[i] = 'd0;
         desc_rpos[i] = 'd0;
         desc_addr_range_valids[i] = 1'b0;
      end
      st_wpos = 'd0;
      st_rpos = 'd0;
      st_end_num = 'd0;
      desc_num = 'd0;
      sts_num = 'd0;
      dut_desc_wpos = 'd0;
      dut_desc_rpos = 'd0;
      st_desc_wpos = 'd0;
      st_desc_rpos = 'd0;
   end

   // desc check
   reg desc_ready_d1;
   wire desc_ready_mod = desc_ready | desc_ready_d1;
   always @(posedge clk) begin
      if (~resetn) begin
         desc_ready_d1 <= 1'b0;
      end else begin
         desc_ready_d1 <= desc_ready;
         if (desc_load && desc_ready_mod) begin
            dut_desc_addr_saves[dut_desc_wpos] <= desc_dst_addr;
            dut_desc_len_saves[dut_desc_wpos] <= desc_len;
            dut_desc_wpos <= dut_desc_wpos + 1'b1;
            desc_num <= desc_num + 1'b1;
            if (~desc_ctl[4]) $error("%d eop error", $time);
         end
         if (dut_desc_wpos != dut_desc_rpos && st_desc_wpos != st_desc_rpos) begin
            if (dut_desc_addr_saves[dut_desc_rpos] !== st_desc_addr_saves[st_desc_rpos] ||
                dut_desc_len_saves[dut_desc_rpos] !== st_desc_len_saves[st_desc_rpos]) begin
               $error("%d: desc %h %h, %h %h", $time, dut_desc_addr_saves[dut_desc_rpos], st_desc_addr_saves[st_desc_rpos],
                      dut_desc_len_saves[dut_desc_rpos], st_desc_len_saves[st_desc_rpos]);
            end
            dut_desc_rpos <= dut_desc_rpos + 1'b1;
            st_desc_rpos <= st_desc_rpos + 1'b1;
         end
         desc_ready <= DESC_BITS > 0 ? &rd[13+:DESC_BITS_MOD] : 1'b1;
      end
   end

   // data check
   always @(posedge clk) begin
      if (resetn && tx_out_tvalid && tx_out_tready) begin
         if (tx_out_tdata !== data_saves[st_rpos] ||
             tx_out_tkeep !== keep_saves[st_rpos] ||
             tx_out_tlast !== last_saves[st_rpos]) begin
            $error("%d: data %h %h, %h %h, %h %h", $time, tx_out_tdata, data_saves[st_rpos],
                   tx_out_tkeep, keep_saves[st_rpos], tx_out_tlast, last_saves[st_rpos]);
         end
         if (tx_out_tlast) st_end_num <= st_end_num + 1'b1;
         st_rpos <= st_rpos + 1'b1;
      end
      if (resetn) tx_out_tready <= DOUT_BITS > 0 ? &rd[26+:DOUT_BITS_MOD] : 1'b1;
   end

   // sts
   always @(posedge clk) begin
      if (resetn && st_end_num > sts_num && desc_num > sts_num) begin
         if (STS_BITS>0 ? &rd[20+:STS_BITS_MOD] : 1'b1) begin
            sts <= 8'd8;
         end else begin
            sts <= 8'd0;
         end
      end else begin
         sts <= 8'd0;
      end
   end

   // desc cpl
   reg [31:0] desc_cpl_count;
   always @(posedge clk) begin
      if (~resetn) begin
         desc_cpl_count <= 'd0;
      end else begin
         if (desc_cpl_valid & desc_cpl_ready) begin
            if (desc_cpl_data !== desc_sizes[desc_cpl_ch][desc_rpos[desc_cpl_ch]]) begin
               $error("%d: cpl[%2h] %h %h", $time, desc_cpl_ch,
                      desc_cpl_data, desc_sizes[desc_cpl_ch][desc_rpos[desc_cpl_ch]]);
            end
            desc_rpos[desc_cpl_ch] <= desc_rpos[desc_cpl_ch] + 1'b1;
            desc_cpl_count <= desc_cpl_count + 1'b1;
         end
         desc_cpl_ready <= CPL_BITS > 0 ? &rd[16+:CPL_BITS_MOD] : 1'b1;
      end
   end

   task static setup_ch_valids;
      stream_ch_valids = 'd0;
      while (~|stream_ch_valids || (D2D_ENABLE>0 && ~|stream_ch_d2d_valids)) begin
         for (int i=0; i<CH_NUM; i++) @(posedge clk) begin
            stream_ch_valids[i] <= rd[i&31];
            stream_ch_d2d_valids[i] <= D2D_ENABLE>0 ? rd[i&31] && rd[(i+5)&31] : 1'b0;
            stream_cpl_q_bases[i*64+:64] <= {rd, rd, 2'd0};
         end
      end
      for (int i=0; i<CH_NUM; i++) begin
         if (stream_ch_valids[i]) begin
            $display("%d: [%2h]: %h %h", $time, i, stream_ch_d2d_valids[i], stream_cpl_q_bases[i*64+:64]);
         end
      end
   endtask

   task static frame_generate;
      int frame_count = 0;
      logic [63:0] addr;
      logic [31:0] size;
      logic [CH_NUM_LOG-1:0] ch;
      logic                  valid;
      logic                  eof;
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
               eof = rd[13];
               if (((addr + size) >> 32) != (addr >> 32)) valid = 1'b0;
               if (valid) begin
                  desc_out_data[RCBASE+:128] <= {addr, size, 7'd0, eof, 7'd0, |size, 16'd0};
                  desc_out_last <= 1'b0;
                  cont <= 1'b1;
                  ch = request_chs[request_rpos];
                  desc_addrs[ch][desc_wpos[ch]] <= addr;
                  desc_sizes[ch][desc_wpos[ch]] <= size;
                  desc_eofs[ch][desc_wpos[ch]] <= eof;
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

   task static data_generate;
      int data_frame_count = 0;
      logic [31:0] total_sizes[0:CH_NUM-1];
      logic [31:0] total_size;
      logic [63:0] addr;
      logic [31:0] size = 0;
      logic [31:0] frame_size = 0;
      logic [CH_NUM_LOG-1:0] ch;
      logic                  valid;
      logic [DW-1:0]         data;
      logic [KW-1:0]         keep;
      logic                  sop = 1'b1;
      logic                  eop;
      logic                  eof;
      logic [1:0]            w_inc = 0;
      for (int i=0; i<CH_NUM; i++) total_sizes[i] = 0;

      while (data_frame_count < FRAME_MAX || tx_in_tvalid || valid) @(posedge clk) begin
         w_inc = 0;
         if (~|size) begin
            for (int i=0; i<CH_NUM; i++) begin
               ch = {rd, rd} >> (8+i);
               if (desc_addr_range_valids[ch]) break;
               if (desc_wpos[ch] != desc_cpos[ch]) begin
                  desc_addr_starts[ch] = desc_addrs[ch][desc_cpos[ch]];
                  desc_addr_ends[ch] = desc_addr_starts[ch] + desc_sizes[ch][desc_cpos[ch]];
                  desc_addr_eofs[ch] = desc_eofs[ch][desc_cpos[ch]];
                  total_sizes[ch] += desc_sizes[ch][desc_cpos[ch]];
                  desc_addr_range_valids[ch] = 1'b1;
                  desc_cpos[ch] <= desc_cpos[ch] + 1'b1;
                  break;
               end
            end
            if (desc_addr_range_valids[ch]) begin
               addr = desc_addr_starts[ch];
               size = desc_addr_ends[ch] - addr;
               if (size > {1'b1, {BURST_BITS + KW_LOG{1'b1}}}) size = {1'b1, {BURST_BITS + KW_LOG{1'b0}}};
               st_desc_addr_saves[st_desc_wpos] = addr;
               st_desc_len_saves[st_desc_wpos] = size;
               $display("%d: [%2h] st desc(%3d) : %h %h", $time, ch, st_desc_wpos, addr, size);
               w_inc = 1;
               desc_addr_starts[ch] = addr + size;
               eof = desc_addr_eofs[ch];
               total_size = total_sizes[ch];
               if (desc_addr_starts[ch] == desc_addr_ends[ch]) begin
                  desc_addr_range_valids[ch] = 1'b0;
                  total_sizes[ch] = 'd0;
               end
            end
         end
         valid = |size && (~tx_in_tvalid || tx_in_tready);
         valid = valid && (DIN_BITS > 0 ? &rd[14+:DIN_BITS_MOD] : 1'b1);
         if (valid) begin
            eop = size <= KW;
            if (size >= KW) begin
               keep = {KW{1'b1}};
               size -= KW;
            end else begin
               keep = ({{KW{1'b0}}, 1'b1} << size) - 1'b1;
               size = 0;
            end
            for (int i=0; i<DW; i+=8) begin
               data[i+:8] = ((rd >> (i & 31)) ^ (8'h1 << ((i/8) & 7))) & {8{keep[i/8]}};
            end
            tx_in_tdata <= data;
            tx_in_tkeep <= keep;
            tx_in_tuser <= ch;
            tx_in_sop <= sop;
            tx_in_eop <= eop;
            tx_in_tlast <= eop && ~desc_addr_range_valids[ch] && desc_addr_eofs[ch];
            tx_in_tvalid <= 1'b1;
            sop <= eop;

            data_saves[st_wpos] <= data;
            keep_saves[st_wpos] <= keep;
            last_saves[st_wpos] <= eop;
            if (~|size && ~desc_addr_range_valids[ch] && eof && stream_ch_d2d_valids[ch]) begin
               frame_size = desc_sizes[ch][desc_spos[ch]];
               desc_spos[ch] <= desc_spos[ch] + 1'b1;
               data_saves[(st_wpos+1)&255] <= {'d0, total_size};
               keep_saves[(st_wpos+1)&255] <= {'d0, 4'hf};
               last_saves[(st_wpos+1)&255] <= 1'b1;
               st_wpos <= st_wpos + 2'd2;
               if (|w_inc) begin
                  st_desc_addr_saves[(st_desc_wpos + w_inc)&255] = st_desc_addr_saves[st_desc_wpos];
                  st_desc_len_saves[(st_desc_wpos + w_inc)&255] = st_desc_len_saves[st_desc_wpos];
               end
               st_desc_addr_saves[(st_desc_wpos + w_inc)&255] <= (stream_cpl_q_bases >> {ch, 6'd0}) + 4'd8;
               st_desc_len_saves[(st_desc_wpos + w_inc)&255] <= 'd4;
               $display("%d: [%2h] st desc(%3d) : %h %h", $time, ch, (st_desc_wpos + w_inc) & 255, stream_cpl_q_bases[ch*64+:64], 32'd4);
               w_inc = w_inc + 1'b1;
            end else begin
               st_wpos <= st_wpos + 1'b1;
            end
            if (~|size && ~desc_addr_range_valids[ch]) data_frame_count++;
         end else begin
            tx_in_tvalid <= tx_in_tvalid & ~tx_in_tready;
         end
         st_desc_wpos <= st_desc_wpos + w_inc;
      end
   endtask

   initial begin
      @(posedge clk);
      while (~resetn) @(posedge clk);

      fork
         begin
            setup_ch_valids();
         end
         begin
            frame_generate();
         end
         begin
            data_generate();
         end
      join

      while (desc_cpl_count < FRAME_MAX) @(posedge clk);

      for (int i=0; i<10; i++) @(posedge clk);
      $finish;
   end

endmodule

module test_xdma_tx_switch_fast;
   tb_xdma_tx_switch #(
       .REQ_BITS ( 0 ),
       .OUT_BITS ( 0 ),
       .CPL_BITS ( 0 ),
       .DIN_BITS ( 0 ),
       .DOUT_BITS ( 0 ),
       .DESC_BITS ( 0 ),
       .STS_BITS ( 0 )
   ) tb ();
endmodule

module test_xdma_tx_switch_random;
   tb_xdma_tx_switch tb();
endmodule

module test_xdma_tx_switch_slow_in;
   tb_xdma_tx_switch #(
       .REQ_BITS ( 1 ),
       .OUT_BITS ( 3 ),
       .CPL_BITS ( 1 ),
       .DIN_BITS ( 2 ),
       .DOUT_BITS ( 1 ),
       .DESC_BITS ( 1 ),
       .STS_BITS ( 3 )
   ) tb ();
endmodule

module test_xdma_tx_switch_slow_out;
   tb_xdma_tx_switch #(
       .REQ_BITS ( 3 ),
       .OUT_BITS ( 1 ),
       .CPL_BITS ( 3 ),
       .DIN_BITS ( 1 ),
       .DOUT_BITS ( 2 ),
       .DESC_BITS ( 2 ),
       .STS_BITS ( 1 )
   ) tb ();
endmodule
