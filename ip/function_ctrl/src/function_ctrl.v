/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1 ns / 1 ps

module function_ctrl #(
    parameter DW_LOG = 9,
    parameter CTX_ID_BITS = 4,
    parameter TDEST_BITS = 4,
    parameter BURST_BITS = 5,
    parameter IPORT_NUM = 1,
    parameter OPORT_NUM = 1,
    parameter IPORT_MAX = 8,
    parameter OPORT_MAX = 8,
    parameter [IPORT_MAX-1:0] IPORT_IS_MM = {IPORT_NUM{1'b0}},
    parameter [OPORT_MAX-1:0] OPORT_IS_MM = {OPORT_NUM{1'b0}},
    parameter [OPORT_MAX-1:0] OPORT_HEADER_UPDATE = {OPORT_NUM{1'b1}},
    parameter [OPORT_MAX-1:0] OPORT_USER_OVERWRITE = {OPORT_NUM{1'b1}}
    ) (
    // st
    input [(IPORT_NUM<<DW_LOG)-1:0]      in_tdata,
    input [(IPORT_NUM<<(DW_LOG-3))-1:0]  in_tkeep,
    input [IPORT_NUM*CTX_ID_BITS-1:0]    in_tuser,
    input [IPORT_NUM-1:0]                in_tlast,
    input [IPORT_NUM-1:0]                in_tid, // eof
    input [IPORT_NUM-1:0]                in_tvalid,
    output [IPORT_NUM-1:0]               in_tready,
    output [(OPORT_NUM<<DW_LOG)-1:0]     out_tdata,
    output [(OPORT_NUM<<(DW_LOG-3))-1:0] out_tkeep,
    output [OPORT_NUM*CTX_ID_BITS-1:0]   out_tuser,
    output [OPORT_NUM*TDEST_BITS-1:0]    out_tdest,
    output [OPORT_NUM-1:0]               out_tlast, // eof
    output [OPORT_NUM-1:0]               out_tvalid,
    input [OPORT_NUM-1:0]                out_tready,
    // input frame info
    input [IPORT_NUM*128-1:0]            in_frame_header_tdata,
    input [IPORT_NUM*CTX_ID_BITS-1:0]    in_frame_header_tuser,
    input [IPORT_NUM-1:0]                in_frame_header_tvalid,
    output [IPORT_NUM-1:0]               in_frame_header_tready,
    output [IPORT_NUM*CTX_ID_BITS-1:0]   in_frame_header_consume_tuser,
    output [IPORT_NUM*TDEST_BITS-1:0]    in_frame_header_consume_tdest,
    output [IPORT_NUM-1:0]               in_frame_header_consume_tvalid,
    input [IPORT_NUM-1:0]                in_frame_header_consume_tready,
    output [IPORT_NUM*8-1:0]             in_frame_consume_tdata,
    output [IPORT_NUM*CTX_ID_BITS-1:0]   in_frame_consume_tuser,
    output [IPORT_NUM*TDEST_BITS-1:0]    in_frame_consume_tdest,
    output [IPORT_NUM-1:0]               in_frame_consume_tvalid,
    input [IPORT_NUM-1:0]                in_frame_consume_tready,
    // output frame info
    input [OPORT_NUM*128-1:0]            out_frame_header_tdata,
    input [OPORT_NUM*CTX_ID_BITS-1:0]    out_frame_header_tuser,
    input [OPORT_NUM-1:0]                out_frame_header_tvalid,
    output [OPORT_NUM-1:0]               out_frame_header_tready,
    output [OPORT_NUM*128-1:0]           out_frame_complete_tdata,
    output [OPORT_NUM*CTX_ID_BITS-1:0]   out_frame_complete_tuser,
    output [OPORT_NUM*TDEST_BITS-1:0]    out_frame_complete_tdest,
    output [OPORT_NUM-1:0]               out_frame_complete_tvalid,
    input [OPORT_NUM-1:0]                out_frame_complete_tready,
    // function
    output [(IPORT_NUM<<DW_LOG)-1:0]     func_in_tdata,
    output [(IPORT_NUM<<(DW_LOG-3))-1:0] func_in_tkeep,
    output [IPORT_NUM*CTX_ID_BITS-1:0]   func_in_tuser,
    output [IPORT_NUM-1:0]               func_in_tlast, // eof
    output [IPORT_NUM-1:0]               func_in_tvalid,
    input [IPORT_NUM-1:0]                func_in_tready,
    input [(OPORT_NUM<<DW_LOG)-1:0]      func_out_tdata,
    input [(OPORT_NUM<<(DW_LOG-3))-1:0]  func_out_tkeep,
    input [OPORT_NUM*CTX_ID_BITS-1:0]    func_out_tuser,
    input [OPORT_NUM-1:0]                func_out_tlast, // eof
    input [OPORT_NUM-1:0]                func_out_tvalid,
    output [OPORT_NUM-1:0]               func_out_tready,
    output reg [64*IPORT_NUM-1:0]        func_in_addr,
    output reg [32*IPORT_NUM-1:0]        func_in_size,
    output reg [64*OPORT_NUM-1:0]        func_out_addr,
    output reg [32*OPORT_NUM-1:0]        func_out_size,
    input [64*OPORT_NUM-1:0]             func_out_updated_addr,
    input [32*OPORT_NUM-1:0]             func_out_updated_size,
    input [OPORT_NUM-1:0]                func_out_updated_valid,
    output reg                           func_ap_start,
    input                                func_ap_idle,
    input                                func_ap_done,
    input                                func_ap_ready,
    // global
    input                                clk,
    input                                resetn
    );

   localparam DW = 1 << DW_LOG;
   localparam KW_LOG = DW_LOG - 3;
   localparam KW = 1 << KW_LOG;

   wire [IPORT_NUM*128-1:0]              w_in_header_data;
   wire [IPORT_NUM*CTX_ID_BITS-1:0]      w_in_header_users;
   wire [IPORT_NUM-1:0]                  w_in_header_valids;
   wire [OPORT_NUM*128-1:0]              w_out_header_data;
   wire [OPORT_NUM*CTX_ID_BITS-1:0]      w_out_header_users;
   wire [OPORT_NUM-1:0]                  w_out_header_valids;
   wire                                  w_header_ready;
   generate
      for (genvar i=0; i<IPORT_NUM; i=i+1) begin
         reg [255:0]             header_data;
         reg [CTX_ID_BITS*2-1:0] header_users;
         reg [1:0]               header_valids;
         always @(posedge clk) begin
            if (~resetn) begin
               header_valids <= 2'd0;
            end else if (in_frame_header_tvalid[i] && in_frame_header_tready[i]) begin
               if (header_valids[0] && ~w_header_ready) begin
                  header_data[128+:128] <= in_frame_header_tdata[i*128+:128];
                  header_users[CTX_ID_BITS+:CTX_ID_BITS] <= in_frame_header_tuser[i*CTX_ID_BITS+:CTX_ID_BITS];
                  header_valids[1] <= 1'b1;
               end else begin
                  header_data[0+:128] <= in_frame_header_tdata[i*128+:128];
                  header_users[0+:CTX_ID_BITS] <= in_frame_header_tuser[i*CTX_ID_BITS+:CTX_ID_BITS];
                  header_valids[0] <= 1'b1;
               end
            end else if (w_header_ready) begin
               header_data <= header_data >> 128;
               header_users <= header_users >> CTX_ID_BITS;
               header_valids <= header_valids >> 1;
            end
         end
         assign in_frame_header_tready[i] = ~header_valids[1];
         assign w_in_header_data[i*128+:128] = header_data[127:0];
         assign w_in_header_users[i*CTX_ID_BITS+:CTX_ID_BITS] = header_users[CTX_ID_BITS-1:0];
         assign w_in_header_valids[i] = header_valids[0];
         always @(posedge clk) begin
            if (~resetn) begin
               func_in_addr[i*64+:64] <= 'd0;
               func_in_size[i*32+:32] <= 'd0;
            end else if (func_ap_idle || w_header_ready) begin
               func_in_addr[i*64+:64] <= header_data[63:0];
               func_in_size[i*32+:32] <= header_data[95:64];
            end
         end
      end
   endgenerate
   generate
      for (genvar i=0; i<OPORT_NUM; i=i+1) begin
         reg [255:0]             header_data;
         reg [CTX_ID_BITS*2-1:0] header_users;
         reg [1:0]               header_valids;
         always @(posedge clk) begin
            if (~resetn) begin
               header_valids <= 2'd0;
            end else if (out_frame_header_tvalid[i] && out_frame_header_tready[i]) begin
               if (header_valids[0] && ~w_header_ready) begin
                  header_data[128+:128] <= out_frame_header_tdata[i*128+:128];
                  header_users[CTX_ID_BITS+:CTX_ID_BITS] <= out_frame_header_tuser[i*CTX_ID_BITS+:CTX_ID_BITS];
                  header_valids[1] <= 1'b1;
               end else begin
                  header_data[0+:128] <= out_frame_header_tdata[i*128+:128];
                  header_users[0+:CTX_ID_BITS] <= out_frame_header_tuser[i*CTX_ID_BITS+:CTX_ID_BITS];
                  header_valids[0] <= 1'b1;
               end
            end else if (w_header_ready) begin
               header_data <= header_data >> 128;
               header_users <= header_users >> CTX_ID_BITS;
               header_valids <= header_valids >> 1;
            end
         end
         assign out_frame_header_tready[i] = ~header_valids[1];
         assign w_out_header_data[i*128+:128] = header_data[127:0];
         assign w_out_header_users[i*CTX_ID_BITS+:CTX_ID_BITS] = header_users[CTX_ID_BITS-1:0];
         assign w_out_header_valids[i] = header_valids[0];
         always @(posedge clk) begin
            if (~resetn) begin
               func_out_addr[i*64+:64] <= 'd0;
               func_out_size[i*32+:32] <= 'd0;
            end else if (func_ap_idle || w_header_ready) begin
               func_out_addr[i*64+:64] <= header_data[63:0];
               func_out_size[i*32+:32] <= header_data[95:64];
            end
         end
      end
   endgenerate

   always @(posedge clk) begin
      if (~resetn) begin
         func_ap_start <= 1'b0;
      end else if (w_header_ready) begin
         func_ap_start <= 1'b1;
      end else begin
         func_ap_start <= func_ap_start & ~func_ap_ready;
      end
   end

   reg ap_done_d1;
   reg ap_ready_d1;
   always @(posedge clk) begin
      if (~resetn) begin
         ap_done_d1 <= 1'b0;
         ap_ready_d1 <= 1'b0;
      end else begin
         ap_done_d1 <= func_ap_done;
         ap_ready_d1 <= func_ap_ready;
      end
   end

   wire w_input_done = func_ap_ready & ~ap_ready_d1;
   wire w_output_done = func_ap_done & ~ap_done_d1;

   wire [IPORT_NUM-1:0] w_in_header_consume_readys;
   generate
      for (genvar i=0; i<IPORT_NUM; i=i+1) begin
         reg [CTX_ID_BITS*2-1:0] header_users;
         reg [TDEST_BITS*2-1:0]  header_dests;
         reg [1:0]               header_valids;
         always @(posedge clk) begin
            if (~resetn) begin
               header_valids <= 2'd0;
            end else if (w_header_ready) begin
               if (header_valids[0] && ~in_frame_header_consume_tready[i]) begin
                  header_users[CTX_ID_BITS+:CTX_ID_BITS] <= w_in_header_users[i*CTX_ID_BITS+:CTX_ID_BITS];
                  header_dests[TDEST_BITS+:TDEST_BITS] <= w_in_header_data[i*128+104+:TDEST_BITS];
                  header_valids[1] <= 1'b1;
               end else begin
                  header_users[0+:CTX_ID_BITS] <= w_in_header_users[i*CTX_ID_BITS+:CTX_ID_BITS];
                  header_dests[0+:TDEST_BITS] <= w_in_header_data[i*128+104+:TDEST_BITS];
                  header_valids[0] <= 1'b1;
               end
            end else if (in_frame_header_consume_tready[i]) begin
               header_users <= header_users >> CTX_ID_BITS;
               header_dests <= header_dests >> TDEST_BITS;
               header_valids <= header_valids >> 1;
            end
         end
         assign w_in_header_consume_readys[i] = ~header_valids[1];
         assign in_frame_header_consume_tuser[i*CTX_ID_BITS+:CTX_ID_BITS] = header_users[CTX_ID_BITS-1:0];
         assign in_frame_header_consume_tdest[i*TDEST_BITS+:TDEST_BITS] = header_dests[TDEST_BITS-1:0];
         assign in_frame_header_consume_tvalid[i] = header_valids[0];
      end
   endgenerate

   wire [IPORT_NUM-1:0] w_in_consume_readys;
   generate
      for (genvar i=0; i<IPORT_NUM; i=i+1) begin
         if (IPORT_IS_MM[i]) begin
            reg [15:0]              consume_data;
            reg [CTX_ID_BITS*2-1:0] consume_users;
            reg [TDEST_BITS*2-1:0]  consume_dests;
            reg [1:0]               consume_valids;
            reg [1:0]               consume_out_valids;
            always @(posedge clk) begin
               if (~resetn) begin
                  consume_valids <= 2'd0;
                  consume_out_valids <= 2'd0;
               end else if (w_header_ready) begin
                  if (consume_valids[0] && (~consume_out_valids[0] || ~in_frame_consume_tready[i])) begin
                     consume_data[8+:8] <= w_in_header_data[i*128+96+:8];
                     consume_users[CTX_ID_BITS+:CTX_ID_BITS] <= w_in_header_users[i*CTX_ID_BITS+:CTX_ID_BITS];
                     consume_dests[TDEST_BITS+:TDEST_BITS] <= w_in_header_data[i*128+104+:TDEST_BITS];
                     consume_valids[1] <= 1'b1;
                     consume_out_valids[1] <= 1'b0;
                     consume_out_valids[0] <= consume_out_valids[0] | w_input_done;
                  end else begin
                     consume_data[0+:8] <= w_in_header_data[i*128+96+:8];
                     consume_users[0+:CTX_ID_BITS] <= w_in_header_users[i*CTX_ID_BITS+:CTX_ID_BITS];
                     consume_dests[0+:TDEST_BITS] <= w_in_header_data[i*128+104+:TDEST_BITS];
                     consume_valids[0] <= 1'b1;
                     consume_out_valids[0] <= 1'b0;
                  end
               end else if (consume_out_valids[0] & in_frame_consume_tready[i]) begin
                  consume_data <= consume_data >> 8;
                  consume_users <= consume_users >> CTX_ID_BITS;
                  consume_dests <= consume_dests >> TDEST_BITS;
                  consume_valids <= consume_valids >> 1;
                  if (w_input_done & consume_valids[1]) begin
                     consume_out_valids <= (consume_out_valids >> 1) | 1'b1;
                  end else begin
                     consume_out_valids <= consume_out_valids >> 1;
                  end
               end else if (w_input_done) begin
                  if (consume_out_valids[0]) begin
                     consume_out_valids[1] <= consume_valids[1];
                  end else begin
                     consume_out_valids[0] <= consume_valids[0];
                  end
               end
            end
            assign w_in_consume_readys[i] = ~consume_valids[1];
            assign in_frame_consume_tdata[i*8+:8] = consume_data[7:0];
            assign in_frame_consume_tuser[i*CTX_ID_BITS+:CTX_ID_BITS] = consume_users[CTX_ID_BITS-1:0];
            assign in_frame_consume_tdest[i*TDEST_BITS+:TDEST_BITS] = consume_dests[TDEST_BITS-1:0];
            assign in_frame_consume_tvalid[i] = consume_out_valids[0];
         end else begin
            assign w_in_consume_readys[i] = 1'b1;
            assign in_frame_consume_tvalid[i] = 1'b0;
         end
      end
   endgenerate

   wire [OPORT_NUM-1:0] w_out_complete_readys;
   generate
      for (genvar i=0; i<OPORT_NUM; i=i+1) begin
         reg [207:0]             complete_data;
         reg [CTX_ID_BITS*2-1:0] complete_users;
         reg [TDEST_BITS*2-1:0]  complete_dests;
         reg [1:0]               complete_valids;
         reg [1:0]               complete_out_valids;
         reg [1:0]               complete_out_ready_valids;
         reg [1:0]               complete_update_valids;
         always @(posedge clk) begin
            if (~resetn) begin
               complete_valids <= 2'd0;
               complete_out_ready_valids <= 2'd0;
               complete_out_valids <= 2'd0;
               complete_update_valids <= 2'd0;
            end else if (w_header_ready) begin
               if (complete_valids[0] && (~complete_out_valids[0] || ~out_frame_complete_tready[i])) begin
                  complete_users[CTX_ID_BITS+:CTX_ID_BITS] <= w_out_header_users[i*CTX_ID_BITS+:CTX_ID_BITS];
                  complete_dests[TDEST_BITS+:TDEST_BITS] <= w_out_header_data[i*128+104+:TDEST_BITS];
                  complete_valids[1] <= 1'b1;
                  if (OPORT_IS_MM[i] && OPORT_HEADER_UPDATE[i]) begin
                     if (complete_update_valids[0]) begin
                        complete_out_valids[0] <= complete_out_valids[0] | w_output_done;
                     end else begin
                        complete_out_ready_valids[0] <= complete_out_ready_valids[0] | w_output_done;
                     end
                     complete_out_valids[1] <= 1'b0;
                     complete_out_ready_valids[1] <= 1'b0;
                  end else if (OPORT_IS_MM[i]) begin
                     complete_out_valids[0] <= complete_out_valids[0] | w_output_done;
                     complete_out_valids[1] <= 1'b0;
                  end else if (OPORT_HEADER_UPDATE[i]) begin
                     if (complete_update_valids[0]) begin
                        complete_out_valids[1] <= 1'b1;
                     end else begin
                        complete_out_valids[1] <= 1'b0;
                        complete_out_ready_valids[1] <= 1'b1;
                     end
                  end else begin
                     complete_out_valids[1] <= 1'b1;
                  end
                  if (OPORT_HEADER_UPDATE[i]) begin
                     if (func_out_updated_valid[i]) begin
                        if (complete_update_valids[0]) begin
                           complete_data[104+:104] <= {w_out_header_data[i*128+103:i*128+64+32],
                                                       func_out_updated_size[32*i+:32], func_out_updated_addr[64*i+:64]};
                        end else begin
                           complete_data[104+:104] <= w_out_header_data[i*128+:104];
                           complete_data[0+:96] <= {func_out_updated_size[32*i+:32], func_out_updated_addr[64*i+:64]};
                        end
                     end else begin
                        complete_data[104+:104] <= w_out_header_data[i*128+:104];
                     end
                     complete_update_valids[1] <= (complete_update_valids[0] & func_out_updated_valid[i]) | complete_update_valids[1];
                     complete_update_valids[0] <= complete_update_valids[0] | func_out_updated_valid[i];
                  end else begin
                     complete_data[104+:104] <= w_out_header_data[i*128+:104];
                  end
               end else begin
                  complete_users[0+:CTX_ID_BITS] <= w_out_header_users[i*CTX_ID_BITS+:CTX_ID_BITS];
                  complete_dests[0+:TDEST_BITS] <= w_out_header_data[i*128+104+:TDEST_BITS];
                  complete_valids[0] <= 1'b1;
                  if (OPORT_IS_MM[i] && OPORT_HEADER_UPDATE[i]) begin
                     complete_out_valids[0] <= 1'b0;
                     complete_out_ready_valids[0] <= 1'b0;
                  end else if (OPORT_IS_MM[i]) begin
                     complete_out_valids[0] <= 1'b0;
                  end else if (OPORT_HEADER_UPDATE[i]) begin
                     complete_out_valids[0] <= 1'b0;
                     complete_out_ready_valids[0] <= 1'b1;
                  end else begin
                     complete_out_valids[0] <= 1'b1;
                  end
                  if (OPORT_HEADER_UPDATE[i]) begin
                     if (func_out_updated_valid[i]) begin
                        complete_data[0+:104] <= {w_out_header_data[i*128+103:i*128+64+32],
                                                  func_out_updated_size[32*i+:32], func_out_updated_addr[64*i+:64]};
                     end else begin
                        complete_data[0+:104] <= w_out_header_data[i*128+:104];
                     end
                     complete_update_valids[0] <= func_out_updated_valid[i];
                  end else begin
                     complete_data[0+:104] <= w_out_header_data[i*128+:104];
                  end
               end
            end else if (complete_out_valids[0] & out_frame_complete_tready[i]) begin
               complete_users <= complete_users >> CTX_ID_BITS;
               complete_dests <= complete_dests >> TDEST_BITS;
               complete_valids <= complete_valids >> 1;
               if (OPORT_HEADER_UPDATE[i]) begin
                  if (func_out_updated_valid[i]) begin
                     complete_data <= {104'd0, complete_data[207:104+64+32],
                                       func_out_updated_size[32*i+:32], func_out_updated_addr[64*i+:64]};
                  end else begin
                     complete_data <= complete_data >> 104;
                  end
                  complete_update_valids <= {1'b0, complete_update_valids[1] | func_out_updated_valid[i]};
               end else begin
                  complete_data <= complete_data >> 104;
               end
               if (OPORT_IS_MM[i] && OPORT_HEADER_UPDATE[i]) begin
                  complete_out_valids <= (complete_out_valids >> 1) | (w_output_done && complete_valids[1] && complete_update_valids[1]);
                  complete_out_ready_valids <= (complete_out_ready_valids >> 1) | (w_output_done && complete_valids[1] && ~complete_update_valids[1]);
               end else if (OPORT_IS_MM[i]) begin
                  complete_out_valids <= (complete_out_valids >> 1) | (w_output_done && complete_valids[1]);
               end else if (OPORT_HEADER_UPDATE[i]) begin
                  complete_out_valids <= complete_out_valids >> 1;
                  complete_out_ready_valids <= complete_out_ready_valids >> 1;
               end else begin
                  complete_out_valids <= complete_out_valids >> 1;
               end
            end else if (OPORT_IS_MM[i] && w_output_done) begin
               if (OPORT_HEADER_UPDATE[i]) begin
                  if (complete_out_valids[0] || complete_out_ready_valids[0]) begin
                     complete_out_valids[1] <= complete_valids[1] && complete_update_valids[1];
                     complete_out_ready_valids[1] <= complete_valids[1] && ~complete_update_valids[1];
                  end else begin
                     complete_out_valids[0] <= complete_valids[0] && complete_update_valids[0];
                     complete_out_ready_valids[0] <= complete_valids[0] && ~complete_update_valids[0];
                  end
                  if (func_out_updated_valid[i]) begin
                     if (complete_update_valids[0]) begin
                        complete_data[104+:96] <= {func_out_updated_size[32*i+:32], func_out_updated_addr[64*i+:64]};
                        complete_update_valids[1] <= 1'b1;
                     end else begin
                        complete_data[0+:96] <= {func_out_updated_size[32*i+:32], func_out_updated_addr[64*i+:64]};
                        complete_update_valids[0] <= 1'b1;
                     end
                  end
               end else begin
                  if (complete_out_valids[0]) begin
                     complete_out_valids[1] <= complete_valids[1];
                  end else begin
                     complete_out_valids[0] <= complete_valids[0];
                  end
               end
            end else if (OPORT_HEADER_UPDATE[i]) begin
               if (func_out_updated_valid[i]) begin
                  if (complete_update_valids[0]) begin
                     complete_data[104+:96] <= {func_out_updated_size[32*i+:32], func_out_updated_addr[64*i+:64]};
                     complete_update_valids[1] <= 1'b1;
                  end else begin
                     complete_data[0+:96] <= {func_out_updated_size[32*i+:32], func_out_updated_addr[64*i+:64]};
                     complete_update_valids[0] <= 1'b1;
                  end
               end
               if (complete_out_ready_valids[0] && complete_update_valids[0]) begin
                  complete_out_valids[0] <= 1'b1;
                  complete_out_ready_valids[0] <= 1'b0;
               end
            end
         end
         assign w_out_complete_readys[i] = ~complete_valids[1];
         assign out_frame_complete_tdata[i*128+:128] = {24'd0, complete_data[103:0]};
         assign out_frame_complete_tuser[i*CTX_ID_BITS+:CTX_ID_BITS] = complete_users[CTX_ID_BITS-1:0];
         assign out_frame_complete_tdest[i*TDEST_BITS+:TDEST_BITS] = complete_dests[TDEST_BITS-1:0];
         assign out_frame_complete_tvalid[i] = complete_out_valids[0];
      end
   endgenerate

   assign w_header_ready = ~func_ap_start && &w_in_header_valids && &w_out_header_valids &&
                           &w_in_header_consume_readys && &w_in_consume_readys && &w_out_complete_readys;

   generate
      for (genvar i=0; i<IPORT_NUM; i=i+1) begin
         if (~IPORT_IS_MM[i]) begin
            axis_buf #(
                .DW ( DW + KW + CTX_ID_BITS )
            ) i_st_buf (
                .idata ( {in_tuser[i*CTX_ID_BITS+:CTX_ID_BITS], in_tkeep[i*KW+:KW], in_tdata[i*DW+:DW]} ),
                .ilast ( in_tid[i] ),
                .ivalid ( in_tvalid[i] ),
                .iready ( in_tready[i] ),
                .odata ( {func_in_tuser[i*CTX_ID_BITS+:CTX_ID_BITS], func_in_tkeep[i*KW+:KW], func_in_tdata[i*DW+:DW]} ),
                .olast ( func_in_tlast[i] ),
                .ovalid ( func_in_tvalid[i] ),
                .oready ( func_in_tready[i] ),
                .clk ( clk ),
                .resetn ( resetn )
           );
         end else begin
            assign func_in_tvalid[i] = 1'b0;
         end
      end
   endgenerate
   generate
      for (genvar i=0; i<OPORT_NUM; i=i+1) begin
         if (~OPORT_IS_MM[i]) begin
            reg [CTX_ID_BITS*2-1:0] st_users;
            reg [TDEST_BITS*2-1:0]  st_dests;
            reg [1:0]               st_valids;
            wire                    w_st_ready;
            always @(posedge clk) begin
               if (~resetn) begin
                  st_valids <= 2'd0;
               end else if (w_header_ready) begin
                  if (st_valids[0] && ~w_st_ready) begin
                     st_dests[TDEST_BITS+:TDEST_BITS] <= w_out_header_data[i*128+104+:TDEST_BITS];
                     st_users[CTX_ID_BITS+:CTX_ID_BITS] <= w_out_header_users[i*CTX_ID_BITS+:CTX_ID_BITS];
                     st_valids[1] <= 1'b1;
                  end else begin
                     st_dests[0+:TDEST_BITS] <= w_out_header_data[i*128+104+:TDEST_BITS];
                     st_users[0+:CTX_ID_BITS] <= w_out_header_users[i*CTX_ID_BITS+:CTX_ID_BITS];
                     st_valids[0] <= 1'b1;
                  end
               end else if (w_st_ready) begin
                  st_dests <= st_dests >> TDEST_BITS;
                  st_users <= st_users >> CTX_ID_BITS;
                  st_valids <= st_valids >> 1;
               end
            end
            wire [CTX_ID_BITS-1:0] w_out_tuser;
            wire                   w_func_out_tready;
            if (OPORT_USER_OVERWRITE[i]) begin
               assign w_out_tuser = st_users[CTX_ID_BITS-1:0];
            end else begin
               assign w_out_tuser = func_out_tuser[i*CTX_ID_BITS+:CTX_ID_BITS];
            end
            packet_fifo #(
                .DW ( DW + KW + CTX_ID_BITS + TDEST_BITS ),
                .BURST_BITS ( BURST_BITS )
            ) o_st_fifo (
                .i_tdata ( {st_dests[TDEST_BITS-1:0], w_out_tuser,
                            func_out_tkeep[i*KW+:KW], func_out_tdata[i*DW+:DW]} ),
                .i_tlast ( func_out_tlast[i] ),
                .i_tvalid ( func_out_tvalid[i] & func_out_tready[i] ),
                .i_tready ( w_func_out_tready ),
                .o_tdata ( {out_tdest[i*TDEST_BITS+:TDEST_BITS], out_tuser[i*CTX_ID_BITS+:CTX_ID_BITS],
                            out_tkeep[i*KW+:KW], out_tdata[i*DW+:DW]} ),
                .o_tlast ( out_tlast[i] ),
                .o_tvalid ( out_tvalid[i] ),
                .o_tready ( out_tready[i] ),
                .clk ( clk ),
                .resetn ( resetn )
            );
            assign w_st_ready = func_out_tvalid[i] & func_out_tready[i] & func_out_tlast[i];
            assign func_out_tready[i] = w_func_out_tready & st_valids[0];
            //assign w_st_ready = out_tvalid[i] & out_tready[i] & out_tlast[i];
            //assign out_tdest[i*TDEST_BITS+:TDEST_BITS] = st_dests[TDEST_BITS-1:0];
            //if (OPORT_USER_OVERWRITE[i]) begin
            //   assign out_tuser[i*CTX_ID_BITS+:CTX_ID_BITS] = st_users[CTX_ID_BITS-1:0];
            //end else begin
            //   assign out_tuser[i*CTX_ID_BITS+:CTX_ID_BITS] = w_out_tuser;
            //end
         end else begin
            assign out_tvalid[i] = 1'b0;
         end
      end
   endgenerate

endmodule
