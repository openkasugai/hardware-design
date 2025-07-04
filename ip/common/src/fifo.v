/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module fifo #(
    parameter DW = 32,
    parameter DL = 4
    ) (
    input [DW-1:0]      idata,
    input               ivalid,
    output reg          iready,

    output reg [DW-1:0] odata,
    output reg          ovalid,
    input               oready,

    output reg          full,

    input               clk,
    input               resetn
    );

    localparam DEPTH = 1 << DL;

    reg [DW-1:0]    mem[0:DEPTH-1];
    reg [DW-1:0]    rdata;

    reg [DL:0]      wptr;
    reg [DL:0]      wptr_d1;
    reg [DL:0]      rptr;
    wire [DL:0]     wptr_next;
    wire [DL:0]     rptr_next;

    always @(posedge clk) begin
        if (ivalid & iready) begin
            mem[wptr[DL-1:0]] <= idata;
        end
        rdata <= mem[rptr_next[DL-1:0]];
    end

    reg ren;
    reg rvalid;
    always @(posedge clk) begin
        if (~resetn) begin
            wptr <= 'd0;
            wptr_d1 <= 'd0;
            rptr <= 'd0;
            iready <= 1'b0;
            ovalid <= 1'b0;
            odata <= 'd0;
            full <= 1'b0;
            rvalid <= 1'b0;
            ren <= 1'b0;
       end else begin
            wptr <= wptr_next;
            wptr_d1 <= wptr;
            rptr <= rptr_next;
            iready <= (wptr_next[DL] == rptr_next[DL]) || (wptr_next[DL-1:0] != rptr_next[DL-1:0]);
            ovalid <= rvalid | (ovalid & ~oready);
            odata <= (~ovalid | oready) ? rdata : odata;
            full <= wptr_next[DL] != rptr_next[DL] && wptr_next[DL-1:0] == rptr_next[DL-1:0];
            rvalid <= (wptr[DL-1:0] != rptr_next[DL-1:0]) || (rvalid & ovalid & ~oready);
            ren <= wptr[DL-1:0] != rptr_next[DL-1:0] || full;
        end
    end
    assign wptr_next = wptr + (ivalid & iready);
    assign rptr_next = rptr + ((oready | ~rvalid | ~ovalid) && ren);

endmodule
