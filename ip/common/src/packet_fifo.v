/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module packet_fifo #(
    parameter DW = 32,
    parameter BURST_BITS = 4,
    parameter DL = BURST_BITS + 2
    ) (
    input [DW-1:0]  i_tdata,
    input           i_tlast,
    input           i_tvalid,
    output reg      i_tready,

    output [DW-1:0] o_tdata,
    output          o_tvalid,
    output          o_tlast,
    input           o_tready,

    output reg      full,

    input           clk,
    input           resetn
    );

    localparam PACKET_SIZE = 1 << BURST_BITS;
    localparam DEPTH = 1 << DL;

    (* RAM_STYLE = "block" *) reg [DW:0] mem[0:DEPTH-1];
    reg [DW:0]              rdata;
    wire [DW:0]             wdata;
    wire                    wen;

    reg [DL:0]      wptr;
    reg [DL:0]      rptr;
    reg [DL:0]      fifo_len;
    reg [DL:0]      packet_len;
    reg [1:0]       last_count;
    reg             empty;
    wire [DL:0]     wptr_next;
    wire [DL:0]     rptr_next;
    wire [1:0]      last_count_next;
    wire [DL:0]     packet_len_next;
    wire [DL:0]     fifo_len_next;
    wire            ovalid_next;

   assign wen = i_tvalid & i_tready;
   assign wdata = {i_tlast, i_tdata};
   always @(posedge clk) begin
      if (wen) mem[wptr[DL-1:0]] <= wdata;
      rdata <= mem[rptr_next[DL-1:0]];
   end

    reg [DW*2-1:0] data_reg;
    reg [1:0]      last_reg;
    reg [1:0]      valid_reg;
    reg            valid_out_reg;
    wire           mready;

    always @(posedge clk) begin
        if (~resetn) begin
            wptr <= 'd0;
            rptr <= 'd0;
            fifo_len <= 'd0;
            packet_len <= 'd0;
            last_count <= 'd0;
            i_tready <= 1'b0;
            full <= 1'b0;
            empty <= 1'b1;
        end else begin
            wptr <= wptr_next;
            rptr <= rptr_next;
            i_tready <= ((wptr_next[DL] == rptr_next[DL]) || (wptr_next[DL-1:0] != rptr_next[DL-1:0])) &&
                        ~&last_count_next;
            full <= (wptr_next[DL] != rptr_next[DL] && wptr_next[DL-1:0] == rptr_next[DL-1:0]) ||
                    &last_count_next;
            empty <= wptr == rptr_next;
            fifo_len <= fifo_len_next;
            packet_len <= packet_len_next;
            last_count <= last_count_next;
       end
    end
    assign wptr_next = wptr + (i_tvalid & i_tready);
    assign rptr_next = rptr + (~empty && mready);
    assign fifo_len_next = fifo_len + (i_tvalid & i_tready) - (~empty && mready);
    assign packet_len_next = |last_count && ~(o_tvalid & o_tready & o_tlast) ? 'd1 :
                             ~|packet_len && fifo_len_next >= PACKET_SIZE ? PACKET_SIZE :
                             packet_len == 'd1 && o_tvalid && o_tready && fifo_len_next >= PACKET_SIZE ? PACKET_SIZE :
                             |packet_len ? packet_len - (o_tvalid & o_tready) : packet_len;
    assign last_count_next = last_count + (i_tvalid & i_tready & i_tlast) - (o_tvalid & o_tready & o_tlast);

    assign ovalid_next = |packet_len_next;

    assign mready = ~valid_reg[1];
    always @(posedge clk) begin
       if (~resetn) begin
          valid_reg <= 'd0;
          valid_out_reg <= 1'b0;
       end else if (~empty && ~valid_reg[1]) begin
          if (valid_reg[0] && (~o_tvalid || ~o_tready)) begin
             valid_reg[1] <= 1'b1;
             {last_reg[1], data_reg[DW+:DW]} <= rdata;
             valid_out_reg <= |packet_len_next || valid_out_reg;
          end else begin
             valid_reg[0] <= 1'b1;
             {last_reg[0], data_reg[0+:DW]} <= rdata;
             valid_out_reg <= |packet_len_next;
          end
       end else if (o_tvalid & o_tready) begin
          valid_out_reg <= |packet_len_next && valid_reg[1];
          valid_reg <= valid_reg >> 1;
          last_reg <= last_reg >> 1;
          data_reg <= data_reg >> DW;
       end else begin
          valid_out_reg <= valid_out_reg || (|packet_len_next && valid_reg[0]);
       end
    end
    assign o_tdata = data_reg[DW-1:0];
    assign o_tlast = last_reg[0];
    assign o_tvalid = valid_out_reg;

endmodule
