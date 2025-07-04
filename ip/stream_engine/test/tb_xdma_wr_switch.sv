/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_xdma_wr_switch #(
    parameter CH_NUM_LOG = 3,
    parameter DW = 512,
    parameter QEW = 32,
    parameter UPDATE_BITS = 1,
    parameter WRITE_BITS = 1,
    parameter DESC_BITS = 1,
    parameter DATA_BITS = 1,
    parameter STS_BITS = 1,
    parameter IRQ_BITS = 1,
    parameter WR_MAX = 1000,
    parameter UPDATE_MAX = 1000,
    parameter HEAD_TAIL_UPDATE_BITS = 5,
    parameter ENABLE_D2D_RX = 0
    ) ();

   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam UPDATE_BITS_MOD = UPDATE_BITS > 0 ? UPDATE_BITS : 1;
   localparam WRITE_BITS_MOD = WRITE_BITS > 0 ? WRITE_BITS : 1;
   localparam DESC_BITS_MOD = DESC_BITS > 0 ? DESC_BITS : 1;
   localparam DATA_BITS_MOD = DATA_BITS > 0 ? DATA_BITS : 1;
   localparam STS_BITS_MOD = STS_BITS > 0 ? STS_BITS : 1;
   localparam IRQ_BITS_MOD = IRQ_BITS > 0 ? IRQ_BITS : 1;

   localparam KW = DW/8;
   localparam QEWB = QEW * 8;
   localparam RQ_DW = 384;
   localparam RQ_DK = 12;
   localparam RQBASE = 128;

   reg [RQ_DW-1:0]            queue_update_data;
   reg [RQ_DK-1:0]            queue_update_keep;
   reg                        queue_update_valid;
   wire                       queue_update_ready;

   reg [RQ_DW-1:0]            queue_wr_data;
   reg [RQ_DK-1:0]            queue_wr_keep;
   reg                        queue_wr_valid;
   wire                       queue_wr_ready;

   reg [CH_NUM-1:0]           head_tail_updates;

   wire [15:0]                desc_ctl;
   wire [63:0]                desc_dst_addr;
   wire [63:0]                desc_src_addr; // dummy
   wire [27:0]                desc_len;
   wire                       desc_load;
   reg                        desc_ready;

   wire [DW-1:0]              wr_tdata;
   wire [DW/8-1:0]            wr_tkeep;
   wire                       wr_tlast;
   wire                       wr_tvalid;
   reg                        wr_tready;

   reg [7:0]                  sts;
   wire [31:0]                done_count;

   reg [(64<<CH_NUM_LOG)-1:0] doorbell_addrs;
   reg [(1<<CH_NUM_LOG)-1:0]  doorbell_int_enables;

   wire [(1<<CH_NUM_LOG)-1:0] irq_out;
   reg [(1<<CH_NUM_LOG)-1:0]  irq_ack;

   wire                        clk;
   wire                        resetn;
   wire [31:0]                 rd;

   clk_reset clk_reset (
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
   );

   xdma_wr_switch #(
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .DW ( DW ),
       .QEW ( QEW )
   ) dut (
       .*
   );

   initial begin
      queue_update_valid = 1'b0;
      queue_wr_valid = 1'b0;
      desc_ready = 1'b0;
      sts = 'd0;
      irq_ack = 'd0;
      head_tail_updates = 'd0;
   end

   reg [64*CH_NUM-1:0] queue_addr_starts;
   reg [64*CH_NUM-1:0] queue_addr_ends;
   reg [64*CH_NUM-1:0] queue_req_addrs;
   reg [64*CH_NUM-1:0] queue_cpl_addrs;

   reg [63:0]          queue_wr_addrs[0:255];
   reg [DW-1:0]        queue_wr_datum[0:255];
   reg [KW-1:0]        queue_wr_keeps[0:255];
   reg [7:0]           queue_wr_wpos, queue_wr_rpos, queue_wr_dpos;

   reg [63:0]          queue_update_addrs[0:255];
   reg [DW-1:0]        queue_update_datum[0:255];
   reg [KW-1:0]        queue_update_keeps[0:255];
   reg [CH_NUM_LOG-1:0] queue_update_ch[0:255];
   reg                  queue_update_is_cpl[0:255];
   reg                  queue_update_is_doorbell[0:255];
   reg [7:0]            queue_update_wpos, queue_update_rpos, queue_update_dpos;

   reg [CH_NUM-1:0]     d2d_rx_mode;

   initial begin
      queue_wr_wpos = 'd0;
      queue_wr_rpos = 'd0;
      queue_wr_dpos = 'd0;
      queue_update_wpos = 'd0;
      queue_update_rpos = 'd0;
      queue_update_dpos = 'd0;
      d2d_rx_mode = 'd0;
   end

   reg desc_is_update_cpl;
   reg desc_is_update_req;
   reg desc_is_doorbell;
   reg desc_is_wr;
   reg [CH_NUM_LOG-1:0] desc_ch;
   always @(desc_dst_addr) begin
      desc_is_update_req = 1'b0;
      desc_is_update_cpl = 1'b0;
      desc_is_doorbell = 1'b0;
      desc_is_wr = 1'b0;
      for (int i=0; i<CH_NUM; i++) begin
         if (queue_addr_starts[64*i+:64] <= desc_dst_addr && desc_dst_addr <= queue_addr_ends[64*i+:64]) begin
            desc_ch = i;
            desc_is_wr = 1'b1;
         end else if (desc_dst_addr == queue_req_addrs[64*i+:64]) begin
            desc_ch = i;
            desc_is_update_req = 1'b1;
         end else if (desc_dst_addr == queue_cpl_addrs[64*i+:64]) begin
            desc_ch = i;
            desc_is_update_cpl = 1'b1;
         end else if (desc_dst_addr == doorbell_addrs[64*i+:64]) begin
            desc_ch = i;
            desc_is_doorbell = 1'b1;
         end
         if (desc_is_update_req || desc_is_update_cpl || desc_is_doorbell || desc_is_wr) break;
      end
   end

   // descriptor out
   reg [31:0] desc_count;
   reg ready_d1;
   reg [CH_NUM-1:0] doorbell_written;
   wire desc_axis_ready = ready_d1 | desc_ready;
   always @(posedge clk) begin
      if (~resetn) begin
         ready_d1 <= 1'b0;
         desc_count <= 'd0;
         doorbell_written <= 'd0;
      end else begin
         ready_d1 <= desc_ready;
         if (desc_load && desc_axis_ready) begin
            desc_count <= desc_count + 1'b1;
            if (desc_is_wr) begin
               if (desc_dst_addr !== queue_wr_addrs[queue_wr_rpos] ||
                   desc_len !== QEW) begin
                  $error("%d desc wr: %h %h, %h", $time, desc_dst_addr, queue_wr_addrs[queue_wr_rpos], desc_len);
               end
               queue_wr_rpos <= queue_wr_rpos + 1'b1;
            end else if (desc_is_doorbell && d2d_rx_mode[desc_ch]) begin
               doorbell_written[desc_ch] <= 1'b1;
            end else if (desc_is_update_req || desc_is_update_cpl || desc_is_doorbell) begin
               if (desc_dst_addr !== queue_update_addrs[queue_update_rpos] ||
                   desc_len !== 'd4 ||
                   (desc_is_update_req === queue_update_is_cpl[queue_update_rpos] && ~desc_is_doorbell) ||
                   desc_is_update_cpl !== queue_update_is_cpl[queue_update_rpos] ||
                   desc_is_doorbell !== queue_update_is_doorbell[queue_update_rpos]) begin
                  $error("%d desc update: %h %h, %h, %h %h, %h %h, %h %h", $time,
                         desc_dst_addr, queue_update_addrs[queue_update_rpos], desc_len,
                         desc_is_update_req, ~queue_update_is_cpl[queue_update_rpos],
                         desc_is_update_cpl, queue_update_is_cpl[queue_update_rpos],
                         desc_is_doorbell, queue_update_is_doorbell[queue_update_rpos]);
               end
               queue_update_rpos <= queue_update_rpos + 1'b1;
            end else begin
               $error("%d desc unknown: %h %h", $time, desc_dst_addr, desc_len);
            end
         end
         desc_ready <= DESC_BITS > 0 ? &rd[5+:DESC_BITS_MOD] : 1'b1;
      end
   end

   // data out
   reg [31:0] data_count;
   reg is_wr_write, is_update_write, is_head_tail_update;
   always @(posedge clk) begin
      if (~resetn) begin
         data_count <= 'd0;
      end else begin
         if (wr_tvalid & wr_tready) begin
            data_count <= data_count + 1'b1;
            is_head_tail_update = wr_tdata === 'd0 && wr_tkeep == 'hf &&
                                  (queue_update_dpos == queue_update_wpos || |queue_update_datum[queue_update_dpos]);
            is_wr_write = wr_tdata === queue_wr_datum[queue_wr_dpos] && wr_tkeep === queue_wr_keeps[queue_wr_dpos];
            is_update_write = wr_tdata === queue_update_datum[queue_update_dpos] &&
                              wr_tkeep === queue_update_keeps[queue_update_dpos] && ~is_head_tail_update;
            if (~is_head_tail_update &&
                ((wr_tdata !== queue_wr_datum[queue_wr_dpos] && wr_tdata !== queue_update_datum[queue_update_dpos]) ||
                 (wr_tkeep !== queue_wr_keeps[queue_wr_dpos] && wr_tkeep !== queue_update_keeps[queue_update_dpos]) ||
                 ~wr_tlast)) begin
               $error("%d data: %h %h %h, %h %h %h", $time,
                      wr_tdata, queue_wr_datum[queue_wr_dpos], queue_update_datum[queue_update_dpos],
                      wr_tkeep, queue_wr_keeps[queue_wr_dpos], queue_update_keeps[queue_update_dpos]);
            end
            if (is_wr_write) queue_wr_dpos <= queue_wr_dpos + 1'b1;
            if (is_update_write) queue_update_dpos <= queue_update_dpos + 1'b1;
         end
         wr_tready <= WRITE_BITS > 0 ? &rd[8+:WRITE_BITS_MOD] : 1'b1;
      end
   end

   // sts in
   reg [31:0] sts_count;
   always @(posedge clk) begin
      if (~resetn) begin
         sts_count <= 'd0;
      end else begin
         if (sts_count < data_count && sts_count < desc_count) begin
            if (STS_BITS == 0 || &rd[12+:STS_BITS_MOD]) begin
               sts <= 8'h8;
               sts_count <= sts_count + 1'b1;
            end else begin
               sts <= 8'h0;
            end
         end else begin
            sts <= 8'h0;
         end
      end
   end

   // irq ack
   reg [CH_NUM-1:0] irq_d1;
   reg [CH_NUM-1:0] irq_ack_need;
   always @(posedge clk) begin
      if (~resetn) begin
         irq_d1 <= 'd0;
         irq_ack_need <= 'd0;
      end else begin
         irq_d1 <= irq_out;
         irq_ack_need <= (irq_ack_need & ~rd) | (irq_out & ~irq_d1);
         irq_ack <= irq_ack_need & rd;
      end
   end

   task static setup_registers;
      logic [63:0] addr;
      for (int i=0; i<CH_NUM; i++) begin
         for (int target = 0; target < 4; target++) @(posedge clk) begin
            addr = {rd, rd, 2'd0} ^ (64'h0101001010110 << (i+target));
            if (target==0) begin
               queue_addr_starts[i*64+:64] = addr;
               queue_addr_ends[i*64+:64] = addr + 16'h1000;
            end else if (target==1) queue_req_addrs[i*64+:64] = addr;
            else if (target==2) queue_cpl_addrs[i*64+:64] = addr;
            else if (target==3) begin
               doorbell_addrs[i*64+:64] = rd[(i+5)&31] ? addr : 64'd0;
               doorbell_int_enables[i] = rd[i&31];
            end
         end
         d2d_rx_mode[i] = ENABLE_D2D_RX > 0 ? rd[i&31] : 1'b0;
         $display("[%2h]: %h %h, %h, %h, %h, %h, d2d_rx: %1h", i,
                  queue_addr_starts[i*64+:64], queue_addr_ends[i*64+:64],
                  queue_req_addrs[i*64+:64], queue_cpl_addrs[i*64+:64], doorbell_addrs[i*64+:64], doorbell_int_enables[i],
                  d2d_rx_mode[i]);
      end
   endtask

   task static queue_wr_generate;
      int wr_count = 0;
      logic [63:0] addr;
      logic [10:0] len;
      logic [QEWB-1:0] qe;
      logic [CH_NUM_LOG-1:0] ch;
      logic            valid;

      while (wr_count < WR_MAX || queue_wr_valid) @(posedge clk) begin
         if (queue_wr_valid & queue_wr_ready) wr_count++;
         if (~queue_wr_valid || queue_wr_ready) begin
            valid = ((queue_wr_wpos + 1'b1) & 255) != queue_wr_rpos &&
                    ((queue_wr_wpos + 1'b1) & 255) != queue_wr_dpos;
            valid = valid && (WRITE_BITS > 0 ? &rd[20+:WRITE_BITS_MOD] : 1'b1);
            valid = valid && wr_count < WR_MAX;
            ch = rd[9+:CH_NUM_LOG];
            valid = valid && ~d2d_rx_mode[ch];
            if (valid) begin
               for (int i=0; i<QEWB; i+=32) begin
                  qe[i+:32] = rd ^ (32'h1001 << i/32);
               end
               addr = queue_addr_starts[ch*64+:64];
               addr += {rd[4+:10], 2'd0};
               len = QEW/4;
               queue_wr_data[RQBASE+:QEWB] <= qe;
               queue_wr_data[63:0] <= addr;
               queue_wr_data[74:64] <= len;
               queue_wr_data[RQBASE-1:75] <= 'd0;
               queue_wr_valid <= 1'b1;
               queue_wr_addrs[queue_wr_wpos] <= addr;
               queue_wr_datum[queue_wr_wpos] <= {{DW-QEWB{1'b0}}, qe};
               queue_wr_keeps[queue_wr_wpos] <= {{KW-QEW{1'b0}}, {QEW{1'b1}}};
               queue_wr_wpos <= queue_wr_wpos + 1'b1;
            end else begin
               queue_wr_valid <= queue_wr_valid & ~queue_wr_ready;
            end
         end
      end
   endtask

   task static queue_update_generate;
      int update_count = 0;
      logic [63:0] addr;
      logic [10:0] len;
      logic [7:0]  qv;
      logic [CH_NUM-1:0] ch;
      logic        valid;
      logic [7:0]  wpos_p1;
      int          mode = 0; // 0: req, 1: cpl, 2: doorbell

      while (update_count < UPDATE_MAX || queue_update_valid) @(posedge clk) begin
         if (queue_update_valid & queue_update_ready) update_count++;
         if (~queue_update_valid || queue_update_ready) begin
            valid = ((queue_update_wpos + 1'b1) & 255) != queue_update_rpos &&
                    ((queue_update_wpos + 1'b1) & 255) != queue_update_dpos;
            valid = valid && (UPDATE_BITS > 0 ? &rd[14+:UPDATE_BITS_MOD] : 1'b1);
            valid = valid && update_count < UPDATE_MAX;
            if (mode==0) ch = rd[10+:CH_NUM_LOG];
            valid = valid && ~d2d_rx_mode[ch];
            if (valid) begin
               qv = rd;
               addr = mode == 0 ? queue_req_addrs[ch*64+:64] :
                      mode == 1 ? queue_cpl_addrs[ch*64+:64] : doorbell_addrs[ch*64+:64];
               queue_update_data[RQBASE+:32] <= {24'd0, qv};
               queue_update_data[RQBASE+32+:32] <= {{32-CH_NUM_LOG{1'b0}}, ch};
               queue_update_data[RQBASE+64] <= mode == 1;
               queue_update_data[RQ_DW-1:RQBASE+65] <= 'd0;
               queue_update_data[63:0] <= addr;
               queue_update_data[74:64] <= 11'd1;
               queue_update_data[RQBASE-1:75] <= 'd0;
               queue_update_valid <= 1'b1;

               queue_update_addrs[queue_update_wpos] <= addr;
               queue_update_datum[queue_update_wpos] <= {'d0, qv};
               queue_update_keeps[queue_update_wpos] <= {{RQ_DK-4{1'b0}}, 4'hf};
               queue_update_ch[queue_update_wpos] <= ch;
               queue_update_is_cpl[queue_update_wpos] <= mode == 1;
               queue_update_is_doorbell[queue_update_wpos] <= 1'b0;
               if (mode==1 && |doorbell_addrs[ch*64+:64]) begin
                  wpos_p1 = queue_update_wpos + 1'b1;
                  queue_update_addrs[wpos_p1] <= doorbell_addrs[ch*64+:64];
                  queue_update_datum[wpos_p1] <= 'd0;
                  queue_update_keeps[wpos_p1] <= {{RQ_DK-4{1'b0}}, 4'hf};
                  queue_update_ch[wpos_p1] <= ch;
                  queue_update_is_cpl[wpos_p1] <= 1'b0;
                  queue_update_is_doorbell[wpos_p1] <= 1'b1;
                  queue_update_wpos <= queue_update_wpos + 2'd2;
               end else begin
                  queue_update_wpos <= queue_update_wpos + 1'b1;
               end
               mode = (mode + 1) & 1;
            end else begin
               queue_update_valid <= queue_update_valid & ~queue_update_ready;
            end
         end
      end
   endtask

   reg [CH_NUM-1:0] head_tail_update_requested;

   task static head_tail_update_generate;
      logic [CH_NUM_LOG:0] ch = 0;
      logic                valid;
      logic                doorbell_valid;
      head_tail_update_requested = 'd0;
      while (ch < CH_NUM || |head_tail_updates) @(posedge clk) begin
         valid = &rd[4+:HEAD_TAIL_UPDATE_BITS] && d2d_rx_mode[ch];
         head_tail_updates <= {{CH_NUM-1{1'b0}}, valid} << ch;
         doorbell_valid = |doorbell_addrs[64*ch+:64];
         head_tail_update_requested <= head_tail_update_requested | {{CH_NUM-1{1'b0}}, valid && doorbell_valid} << ch;
         if (ch < CH_NUM) ch <= ch + (valid || ~d2d_rx_mode[ch]);
      end
   endtask

   initial begin
      @(posedge clk);
      while (~resetn) @(posedge clk);

      setup_registers();

      fork
         begin
            queue_wr_generate();
         end
         begin
            queue_update_generate();
         end
         begin
            head_tail_update_generate();
         end
      join

      while (|irq_out) @(posedge clk);
      while (done_count < WR_MAX + UPDATE_MAX) @(posedge clk);
      if (ENABLE_D2D_RX > 0) begin
         if ((doorbell_written & d2d_rx_mode) !== head_tail_update_requested || ~|head_tail_update_requested) begin
            $error("d2d rx doorbell: %h %h %h", doorbell_written, d2d_rx_mode, head_tail_update_requested);
         end
      end

      $finish;
   end

endmodule

module test_xdma_wr_switch_fast;
   tb_xdma_wr_switch #(
       .UPDATE_BITS ( 0 ),
       .WRITE_BITS ( 0 ),
       .STS_BITS ( 0 ),
       .DESC_BITS ( 0 ),
       .DATA_BITS ( 0 ),
       .IRQ_BITS ( 0 )
   ) tb ();
endmodule

module test_xdma_wr_switch_random;
   tb_xdma_wr_switch tb();
endmodule

module test_xdma_wr_switch_slow_in;
   tb_xdma_wr_switch #(
       .UPDATE_BITS ( 2 ),
       .WRITE_BITS ( 3 ),
       .STS_BITS ( 3 ),
       .WR_MAX ( 500 ),
       .UPDATE_MAX ( 500 )
   ) tb ();
endmodule

module test_xdma_wr_switch_slow_out;
   tb_xdma_wr_switch #(
       .DESC_BITS ( 2 ),
       .DATA_BITS ( 2 ),
       .IRQ_BITS ( 2 ),
       .WR_MAX ( 500 ),
       .UPDATE_MAX ( 500 )
   ) tb ();
endmodule

module test_xdma_wr_switch_random_d2d_rx;
   tb_xdma_wr_switch #(
       .ENABLE_D2D_RX ( 1 )
   ) tb ();
endmodule
