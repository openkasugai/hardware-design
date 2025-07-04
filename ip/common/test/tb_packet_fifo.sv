/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_packet_fifo #(
    parameter DW = 32,
    parameter BURST_BITS = 4,
    parameter DL = BURST_BITS + 2,
    parameter IN_BITS = 1,
    parameter OUT_BITS = 1,
    parameter PACKET_NUM = 1000
    ) ();

   localparam BURST_LEN = 1 << BURST_BITS;
   localparam IN_BITS_MOD = IN_BITS > 0 ? IN_BITS : 1;
   localparam OUT_BITS_MOD = OUT_BITS > 0 ? OUT_BITS : 1;

   reg [DW-1:0]         i_tdata;
   reg                  i_tlast;
   reg                  i_tvalid;
   wire                 i_tready;

   wire [DW-1:0]        o_tdata;
   wire                 o_tvalid;
   wire                 o_tlast;
   reg                  o_tready;

   wire                 full;

   wire                 clk;
   wire                 resetn;
   wire [31:0]          rd;

   clk_reset clk_reset (
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
   );

   packet_fifo #(
      .DW ( DW ),
      .BURST_BITS ( BURST_BITS ),
      .DL ( DL )
   ) dut (
      .*
   );

   initial begin
      i_tvalid = 1'b0;
      o_tready = 1'b1;
   end

   reg [DW-1:0] data_saved[0:255];
   reg          last_saved[0:255];
   reg          burst_end_saved[0:255];
   reg [7:0]    wpos, rpos;

   initial begin
      wpos = 'd0;
      rpos = 'd0;
   end

   reg sop;
   always @(posedge clk) begin
      if (~resetn) begin
         sop <= 1'b1;
      end else begin
         if (o_tvalid & o_tready) begin
            if (o_tdata !== data_saved[rpos] ||
                o_tlast !== last_saved[rpos]) begin
               $error("%d: %h %h, %h %h", $time, o_tdata, data_saved[rpos],
                      o_tlast, last_saved[rpos]);
            end
            sop <= burst_end_saved[rpos] || o_tlast;
            rpos <= rpos + 1'b1;
         end
         if (~sop && ~o_tvalid) begin
            $error("%d: burst failed: %h %h, %h %h, %h", $time,
                   o_tdata, data_saved[rpos], o_tlast, last_saved[rpos], burst_end_saved[rpos]);
         end
      end
   end

   always @(posedge clk) begin
      if (resetn) begin
         o_tready <= OUT_BITS > 0 ? &rd[14+:OUT_BITS_MOD] : 1'b1;
      end
   end

   task static generate_input;
      int packet_num = 0;
      int burst_len = 0;
      logic [7:0] len = 0;
      logic       burst_end = 0;
      logic       valid = 0;
      while (packet_num < PACKET_NUM || i_tvalid || valid) @(posedge clk) begin
         if (~|len) begin
            len = rd;
            burst_len = 0;
         end
         if (|len && packet_num < PACKET_NUM) begin
            valid = IN_BITS > 0 ? &rd[18+:IN_BITS_MOD] : 1'b1;
            valid &= ~i_tvalid || i_tready;
            if (valid) begin
               i_tdata <= rd;
               i_tlast <= len == 1;
               burst_end = burst_len + 1 == BURST_LEN;
               data_saved[wpos] <= rd;
               last_saved[wpos] <= len == 1;
               burst_end_saved[wpos] <= burst_end;
               wpos <= wpos + 1'b1;
               if (burst_end) begin
                  burst_len <= 0;
                  packet_num++;
               end else begin
                  burst_len <= burst_len + 1;
               end
               len--;
               i_tvalid <= valid;
            end else begin
               i_tvalid <= i_tvalid & ~i_tready;
            end
         end else begin
            valid = 0;
            i_tvalid <= i_tvalid & ~i_tready;
         end
      end
   endtask

   initial begin
      @(posedge clk);
      while (~resetn) @(posedge clk);

      generate_input;

      for (int i=0; i<100; i++) @(posedge clk);

      $finish;
   end

endmodule

module test_packet_fifo_fast;
   tb_packet_fifo #(
       .IN_BITS ( 0 ),
       .OUT_BITS ( 0 )
   ) tb ();
endmodule

module test_packet_fifo_random;
   tb_packet_fifo #(
       .IN_BITS ( 1 ),
       .OUT_BITS ( 1 )
   ) tb ();
endmodule

module test_packet_fifo_slow_in;
   tb_packet_fifo #(
       .IN_BITS ( 2 ),
       .OUT_BITS ( 0 )
   ) tb ();
endmodule

module test_packet_fifo_slow_out;
   tb_packet_fifo #(
       .IN_BITS ( 0 ),
       .OUT_BITS ( 2 )
   ) tb ();
endmodule
