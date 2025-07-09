/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module clk_reset (
    output reg clk,
    output reg resetn,
    output reg [31:0] rd
    );

    initial begin
        clk = 1'b0;
        resetn = 1'b0;
        rd = $random(12345);
    end

    always #5 clk = ~clk;
    always #50 resetn = 1'b1;

    always @(posedge clk) begin
        rd <= $random();
    end

endmodule

module watchdog #(
    parameter W = 1,
    parameter WD_CNT = 10000
    ) (
    input [W-1:0] valids,
    input [W-1:0] readys,
    input         clk,
    input         resetn
    );

    reg [31:0]    count;

    always @(posedge clk) begin
        if (~resetn) begin
            count <= 32'd0;
        end else if (|(valids & readys)) begin
            count <= 32'd0;
        end else begin
            count <= count + 1'b1;
            if (count >= WD_CNT) begin
                $fatal(2, "watchdog... valid:%h ready:%h", valids, readys);
            end
        end
    end

endmodule

module tb_fifo #(
    parameter W = 32,
    parameter DL = 10,
    parameter IV_BITS = 1,
    parameter OR_BITS = 1,
    parameter MAX_CYCLES = 100000
    ) (
    );

   localparam IV_BITS_MOD = IV_BITS > 0 ? IV_BITS : 1;
   localparam OR_BITS_MOD = OR_BITS > 0 ? OR_BITS : 1;

   wire clk, resetn;
   wire [31:0] rd;
   clk_reset clk_reset (
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
   );

   reg [W-1:0] idata;
   reg         ivalid;
   wire        iready;
   wire [W-1:0] odata;
   wire         ovalid;
   reg          oready;
   wire         full;

   fifo #(
       .DW ( W ),
       .DL ( DL )
   ) dut (
       .*
   );

   reg [W-1:0]  data_saved[0:2047];
   reg [10:0]   wpos, rpos;

   wire         iv_cand = IV_BITS > 0 ? &rd[4+:IV_BITS_MOD] : 1'b1;
   wire         or_cand = OR_BITS > 0 ? &rd[8+:OR_BITS_MOD] : 1'b1;

   always @(posedge clk) begin
      if (~resetn) begin
         wpos <= 'd0;
         ivalid <= 1'b0;
      end else if (iv_cand && (~ivalid || iready)) begin
         idata <= rd;
         ivalid <= iv_cand;
         data_saved[wpos] <= rd;
         wpos <= wpos + 1'b1;
      end else begin
         ivalid <= ivalid & ~iready;
      end
   end

   always @(posedge clk) begin
      if (~resetn) begin
         rpos <= 'd0;
         oready <= 1'b0;
      end else begin
         if (ovalid && oready) begin
            if (data_saved[rpos] !== odata) begin
               $error("%d: %h %h", $time, odata, data_saved[rpos]);
            end
            rpos <= rpos + 1'b1;
         end
         oready <= or_cand;
      end
   end

   watchdog #(
       .W ( 2 ),
       .WD_CNT ( 1000 )
   ) watchdog (
       .valids ( {ovalid, ivalid} ),
       .readys ( {oready, iready} ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   always @(posedge clk) begin
      if ($time > MAX_CYCLES) $finish();
   end

endmodule

module test_fifo_simple;
   tb_fifo tb();
endmodule

module test_fifo_simple_slow_in;
   tb_fifo #(
       .IV_BITS ( 2 )
   ) tb ();
endmodule

module test_fifo_simple_slow_out;
   tb_fifo #(
       .OR_BITS ( 2 )
   ) tb ();
endmodule
