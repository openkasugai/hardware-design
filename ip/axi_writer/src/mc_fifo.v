/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module mc_fifo #(
    parameter DW = 128,
    parameter CTX_ID_BITS = 5,
    parameter FIFO_DL = 2
    ) (
    input [DW-1:0]                    i_data,
    input [CTX_ID_BITS-1:0]           i_user,
    input                             i_valid,
    output                            i_ready,

    input [CTX_ID_BITS-1:0]           read_user,
    input                             read_last, // remove read entry
    input                             read_valid,
    output                            read_ready,

    output [DW-1:0]                   o_data,
    output reg                        o_last,
    output reg [CTX_ID_BITS-1:0]      o_user,
    output reg                        o_valid,

    output reg [(1<<CTX_ID_BITS)-1:0] fulls,
    output reg [(1<<CTX_ID_BITS)-1:0] valids,

    input                             clk,
    input                             resetn
    );

   localparam FIFO_DEPTH = 1 << FIFO_DL;
   localparam CH_NUM = 1 << CTX_ID_BITS;

   reg [(FIFO_DL+1)*CH_NUM-1:0] wpos;
   reg [(FIFO_DL+1)*CH_NUM-1:0] rpos;

   reg [DW-1:0]                 mem[0:CH_NUM*FIFO_DEPTH-1];
   reg [DW-1:0]                 mem_rdata;
   wire                         wen;
   wire [FIFO_DL+CTX_ID_BITS-1:0] addr;

   always @(posedge clk) begin
      if (wen) mem[addr] <= i_data;
      mem_rdata <= mem[addr];
   end

   wire [FIFO_DL-1:0]     cur_wpos = wpos >> (i_user * (FIFO_DL+1));
   wire [FIFO_DL-1:0]     cur_rpos = rpos >> (read_user * (FIFO_DL+1));
   wire                   ren;
   assign i_ready = ~|fulls;
   assign read_ready = ~i_valid || ~i_ready;
   assign wen = i_valid & i_ready;
   assign ren = read_valid & read_ready;
   assign addr = wen ? {i_user, cur_wpos} : {read_user, cur_rpos};

   always @(posedge clk) begin
      if (~resetn) begin
         o_valid <= 1'b0;
         o_user <= 'd0;
         o_last <= 1'b0;
      end else begin
         o_valid <= ren;
         o_user <= read_user;
         o_last <= read_last;
      end
   end
   assign o_data = mem_rdata;

   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         wire [FIFO_DL:0] w_wpos = wpos[i*(FIFO_DL+1)+:FIFO_DL+1] + (wen && i_user == i);
         wire [FIFO_DL:0] w_rpos = rpos[i*(FIFO_DL+1)+:FIFO_DL+1] + (valids[i] && ren && read_last && read_user == i);
         always @(posedge clk) begin
            if (~resetn) begin
               wpos[i*(FIFO_DL+1)+:FIFO_DL+1] <= 'd0;
               rpos[i*(FIFO_DL+1)+:FIFO_DL+1] <= 'd0;
               fulls[i] <= 1'b0;
               valids[i] <= 1'b0;
            end else begin
               wpos[i*(FIFO_DL+1)+:FIFO_DL+1] <= w_wpos;
               rpos[i*(FIFO_DL+1)+:FIFO_DL+1] <= w_rpos;
               fulls[i] <= w_wpos[FIFO_DL] != w_rpos[FIFO_DL] &&
                           w_wpos[FIFO_DL-1:0] == w_rpos[FIFO_DL-1:0];
               valids[i] <= w_wpos != w_rpos;
            end
         end
      end
   endgenerate


endmodule
