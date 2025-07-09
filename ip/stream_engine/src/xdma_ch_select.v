/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module xdma_ch_select #(
    parameter CH_NUM_LOG = 3
    ) (
    input [(1<<CH_NUM_LOG)-1:0] ch_valids,

    output reg [CH_NUM_LOG-1:0] req_ch,
    output reg                  req_ch_valid,
    input                       req_ch_ready,

    input                       clk,
    input                       resetn
    );

   localparam CH_NUM = 1 << CH_NUM_LOG;

   reg [CH_NUM_LOG-1:0]         req_ch_cand;
   wire [CH_NUM_LOG-1:0]        w_req_ch;
   wire                         w_cur_cand_valid = ch_valids >> w_req_ch;
   always @(posedge clk) begin
      if (~resetn) begin
         req_ch <= 'd0;
         req_ch_valid <= 1'b0;
         req_ch_cand <= 'd0;
      end else begin
         if (~req_ch_valid) begin
            if (w_cur_cand_valid) begin
               req_ch <= w_req_ch;
               req_ch_valid <= 1'b1;
            end
            req_ch_cand <= w_req_ch;
         end else if (req_ch_ready) begin
            req_ch_valid <= 1'b0;
         end
      end
   end
   wire [CH_NUM-1:0] rotated_valids = {ch_valids, ch_valids[CH_NUM-1:1]} >> req_ch_cand;
   assign w_req_ch = rotated_valids[0] ? req_ch_cand + 1'b1 :
                     rotated_valids[1] ? req_ch_cand + 2'd2 :
                     rotated_valids[2] ? req_ch_cand + 2'd3 :
                     rotated_valids[3] ? req_ch_cand + 3'd4 :
                     rotated_valids[4] ? req_ch_cand + 3'd5 :
                     rotated_valids[5] ? req_ch_cand + 3'd6 :
                     rotated_valids[6] ? req_ch_cand + 3'd7 : req_ch_cand + 4'd8;

endmodule
