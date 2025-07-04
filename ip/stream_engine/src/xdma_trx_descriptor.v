/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module xdma_trx_descriptor #(
    parameter CH_NUM_LOG = 3,
    parameter DESC_MAX = 4,
    parameter DESC_RQ_DW = 512,
    parameter DESC_RQ_DK = 16,
    parameter DESC_RC_DW = 512,
    parameter DESC_RC_DK = 16,
    parameter RCBASE = 96,
    parameter CH_BASE = 0
    ) (
    input [(1<<CH_NUM_LOG)-1:0]    stream_ch_valids,

    output reg [DESC_RQ_DW-1:0]    desc_req_data,
    output reg                     desc_req_valid,
    input                          desc_req_ready,

    input [DESC_RC_DW-1:0]         desc_in_data,
    input                          desc_in_last,
    input                          desc_in_valid,
    output                         desc_in_ready,

    output [(128<<CH_NUM_LOG)-1:0] desc_front_data,
    output [(1<<CH_NUM_LOG)-1:0]   desc_front_finals,
    output [(1<<CH_NUM_LOG)-1:0]   desc_front_valids,

    input [127:0]                  desc_update_data,
    input [CH_NUM_LOG-1:0]         desc_update_ch,
    input                          desc_update_valid,

    input                          desc_out_ready,
    input [CH_NUM_LOG-1:0]         desc_out_ready_ch,

    input                          clk,
    input                          resetn
    );

   localparam CH_NUM = 1 << CH_NUM_LOG;

   wire                  desc_skip;
   wire [CH_NUM_LOG-1:0] req_ch;
   wire                  req_ch_valid;
   wire                  req_ch_ready = (desc_req_valid & desc_req_ready) || desc_skip;

   xdma_ch_select #(
       .CH_NUM_LOG ( CH_NUM_LOG )
   ) req_ch_selector (
       .ch_valids ( stream_ch_valids ),
       .req_ch ( req_ch ),
       .req_ch_valid ( req_ch_valid ),
       .req_ch_ready ( req_ch_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   reg                  req_inflight;
   reg [CH_NUM_LOG-1:0] req_inflight_ch;
   wire                 desc_req_out_ready;
   always @(posedge clk) begin
      if (~resetn) begin
         req_inflight <= 1'b0;
         desc_req_valid <= 1'b0;
         desc_req_data <= 'd0;
      end else if (req_ch_valid && ~req_inflight && (~desc_req_valid || desc_req_ready)) begin
         if (desc_req_out_ready) begin
            desc_req_data[103:96] <= CH_BASE + req_ch;
            desc_req_valid <= 1'b1;
            req_inflight <= 1'b1;
            req_inflight_ch <= req_ch;
         end else begin
            desc_req_valid <= 1'b0;
         end
      end else begin
         desc_req_valid <= desc_req_valid & ~desc_req_ready;
         if (desc_in_valid & desc_in_ready & desc_in_last) begin
            req_inflight <= 1'b0;
         end
      end
   end
   assign desc_skip = req_ch_valid && ~req_inflight && (~desc_req_valid || desc_req_ready) && ~desc_req_out_ready;

   // paddr 64, size 32
   reg [128*CH_NUM*DESC_MAX-1:0] desc_data;
   reg [CH_NUM*DESC_MAX-1:0]     desc_finals;
   reg [CH_NUM*DESC_MAX-1:0]    desc_valids;
   wire [CH_NUM-1:0]            desc_req_out_readys;
   wire [CH_NUM-1:0]            desc_out_readys = {{CH_NUM{1'b0}}, desc_out_ready} << desc_out_ready_ch;
   wire [CH_NUM-1:0]            desc_updates = {{CH_NUM{1'b0}}, desc_update_valid} << desc_update_ch;

   assign desc_req_out_ready = desc_req_out_readys >> req_ch;

   generate
      for (genvar ch=0; ch<CH_NUM; ch=ch+1) begin
         wire [DESC_MAX-1:0]    w_valids = desc_valids[ch*DESC_MAX+:DESC_MAX];
         wire                   w_ch_match = ch == req_inflight_ch;
         for (genvar i=0; i<DESC_MAX; i=i+1) begin
            always @(posedge clk) begin
               if (~resetn) begin
                  desc_valids[ch*DESC_MAX+i] <= 1'b0;
                  desc_finals[ch*DESC_MAX+i] <= 1'b0;
               end else if (i==0) begin
                  if (desc_in_valid & desc_in_ready & ~desc_in_last & ~w_valids[i] && w_ch_match) begin
                     desc_data[128*(ch*DESC_MAX+i)+:128] <= {desc_in_data[RCBASE+32+:32], desc_in_data[RCBASE+32+:32],
                                                             desc_in_data[RCBASE+64+:64]};
                     desc_finals[ch*DESC_MAX+i] <= desc_in_data[RCBASE+24];
                     desc_valids[ch*DESC_MAX+i] <= |desc_in_data[RCBASE+16];
                  end else if (desc_updates[ch]) begin
                     desc_data[128*(ch*DESC_MAX+i)+:128] <= desc_update_data;
                  end else if (desc_out_readys[ch]) begin
                     desc_data[128*(ch*DESC_MAX+i)+:128] <= desc_data[128*(ch*DESC_MAX+i+1)+:128];
                     desc_finals[ch*DESC_MAX+i] <= desc_finals[ch*DESC_MAX+i+1];
                     desc_valids[ch*DESC_MAX+i] <= desc_valids[ch*DESC_MAX+i+1];
                  end
               end else if (i < DESC_MAX-1) begin
                  if (desc_in_valid & desc_in_ready & ~desc_in_last & ~w_valids[i] && w_valids[i-1] && w_ch_match) begin
                     desc_data[128*(ch*DESC_MAX+i)+:128] <= {desc_in_data[RCBASE+32+:32], desc_in_data[RCBASE+32+:32],
                                                             desc_in_data[RCBASE+64+:64]};
                     desc_finals[ch*DESC_MAX+i] <= desc_in_data[RCBASE+24];
                     desc_valids[ch*DESC_MAX+i] <= |desc_in_data[RCBASE+16];
                  end else if (desc_out_readys[ch]) begin
                     desc_data[128*(ch*DESC_MAX+i)+:128] <= desc_data[128*(ch*DESC_MAX+i+1)+:128];
                     desc_finals[ch*DESC_MAX+i] <= desc_finals[ch*DESC_MAX+i+1];
                     desc_valids[ch*DESC_MAX+i] <= desc_valids[ch*DESC_MAX+i+1];
                  end
               end else begin
                  if (desc_in_valid & desc_in_ready & ~desc_in_last & ~w_valids[i] && w_valids[i-1] && w_ch_match) begin
                     desc_data[128*(ch*DESC_MAX+i)+:128] <= {desc_in_data[RCBASE+32+:32], desc_in_data[RCBASE+32+:32],
                                                             desc_in_data[RCBASE+64+:64]};
                     desc_finals[ch*DESC_MAX+i] <= desc_in_data[RCBASE+24];
                     desc_valids[ch*DESC_MAX+i] <= |desc_in_data[RCBASE+16];
                  end else if (desc_out_readys[ch]) begin
                     desc_valids[ch*DESC_MAX+i] <= 1'b0;
                  end
               end
            end
         end
         assign desc_req_out_readys[ch] = ~w_valids[DESC_MAX-1];
         assign desc_front_finals[ch] = desc_finals[ch*DESC_MAX];
         assign desc_front_valids[ch] = w_valids[0];
         assign desc_front_data[ch*128+:128] = desc_data[128*ch*DESC_MAX+:128];
      end
   endgenerate

   assign desc_in_ready = ~desc_out_ready;

endmodule
