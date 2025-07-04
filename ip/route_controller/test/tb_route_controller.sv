/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_route_controller #(
    parameter CTX_ID_BITS = 4,
    parameter ADDR_BITS = 16,
    parameter DW_LOG = 9,
    parameter TDEST_BITS = 4,
    parameter BURST_BITS = 4,
    parameter EXT_RELATION = 0,
    parameter CREDIT_MAX = 1,
    parameter SELF_DEST = 3,
    parameter ENABLE_MULTI_CONTROLLER = 0,
    parameter REG_BITS = 0,
    parameter ST_IN_BITS = 0,
    parameter ST_OUT_BITS = 0,
    parameter FRAME_HEADER_BITS = 0,
    parameter FRAME_COMPLETE_BITS = 0,
    parameter FRAME_CONSUME_BITS = 0,
    parameter BUFFER_INFO_BITS = 0,
    parameter FRAME_INFO_BITS = 0,
    parameter OUT_REQ_BITS = 0,
    parameter OUT_RSP_BITS = 0,
    parameter MMAPPED = 0,
    parameter MMAPPED_FRAME_MAX = 24,
    parameter DISABLE_FRAME_OUT = 0,
    parameter FRAME_INFO_DELAY = 0,
    parameter NEED_RELATION = 1,
    parameter FRAME_SIZE_BITS = 15,
    parameter FRAME_NUM = 100,
    parameter SEED = 12356
    ) ();

   localparam KW_LOG = DW_LOG - 3;
   localparam RELATION_NUM = EXT_RELATION > 0 ? 7 : 3;
   localparam DW = 1 << DW_LOG;
   localparam KW = 1 << KW_LOG;
   localparam CH_NUM = 1 << CTX_ID_BITS;
   localparam FRAME_MAX = 32;
   localparam FRAME0 = 8;

   localparam REG_BITS_MOD = REG_BITS > 0 ? REG_BITS : 1;
   localparam ST_IN_BITS_MOD = ST_IN_BITS > 0 ? ST_IN_BITS : 1;
   localparam ST_OUT_BITS_MOD = ST_OUT_BITS > 0 ? ST_OUT_BITS : 1;
   localparam FRAME_HEADER_BITS_MOD = FRAME_HEADER_BITS > 0 ? FRAME_HEADER_BITS : 1;
   localparam FRAME_COMPLETE_BITS_MOD = FRAME_COMPLETE_BITS > 0 ? FRAME_COMPLETE_BITS : 1;
   localparam FRAME_CONSUME_BITS_MOD = FRAME_CONSUME_BITS > 0 ? FRAME_CONSUME_BITS : 1;
   localparam BUFFER_INFO_BITS_MOD = BUFFER_INFO_BITS > 0 ? BUFFER_INFO_BITS : 1;
   localparam FRAME_INFO_BITS_MOD = FRAME_INFO_BITS > 0 ? FRAME_INFO_BITS : 1;
   localparam OUT_REQ_BITS_MOD = OUT_REQ_BITS > 0 ? OUT_REQ_BITS : 1;
   localparam OUT_RSP_BITS_MOD = OUT_RSP_BITS > 0 ? OUT_RSP_BITS : 1;
   localparam MM_TDEST = {TDEST_BITS{1'b1}};

   // data stream input (from DMAC)
   reg [DW-1:0]           st_in_tdata;
   reg [KW-1:0]           st_in_tkeep;
   reg [CTX_ID_BITS-1:0]  st_in_tuser; // context id; extract tuser[12:8] (ch_id)
   reg                    st_in_tlast; // convert from tuser[6] (eop)
   reg                    st_in_eof;
   reg                    st_in_tvalid;
   wire                   st_in_tready;
   // data stream output (to DMAC)
   wire [DW-1:0]          st_out_tdata;
   wire [KW-1:0]          st_out_tkeep;
   wire [CTX_ID_BITS-1:0] st_out_tuser;
   wire                   st_out_tlast; // end of frame
   wire                   st_out_sop; // start of packet (optional for fdma2)
   wire                   st_out_eop; // end of packet (optional for fdma2)
   wire [BURST_BITS-1:0]  st_out_burst; // optional only for fdma2
   wire [KW_LOG-1:0]      st_out_last_cnt;
   wire                   st_out_tvalid;
   reg                    st_out_tready;
   // data stream input (from user)
   wire [DW-1:0]          user_st_in_tdata;
   wire [KW-1:0]          user_st_in_tkeep;
   wire [CTX_ID_BITS-1:0] user_st_in_tuser;
   wire                   user_st_in_tlast; // eof
   wire                   user_st_in_tvalid;
   wire                   user_st_in_tready;
   // data stream output (to user)
   wire [DW-1:0]          user_st_out_tdata;
   wire [KW-1:0]          user_st_out_tkeep;
   wire [CTX_ID_BITS-1:0] user_st_out_tuser;
   wire [TDEST_BITS-1:0]  user_st_out_tdest;
   wire                   user_st_out_tlast; // eop (TODO: symmetrical with input)
   wire                   user_st_out_tid; // eof
   wire                   user_st_out_tvalid;
   wire                   user_st_out_tready;
   // frame header output (to functions)
   wire [127:0]           in_frame_header_tdata; // [63:0] frame addr; [95:64] frame size; [103:96] frame id, [104+:TDEST_BITS] dest
   wire [CTX_ID_BITS-1:0] in_frame_header_tuser;
   wire [TDEST_BITS-1:0]  in_frame_header_tdest;
   wire                   in_frame_header_tvalid;
   wire                   in_frame_header_tready;
   // frame header output (to functions)
   wire [127:0]           out_frame_header_tdata; // [63:0] frame addr; [95:64] frame size(max); [103:96] frame id, [104+:TDEST_BITS] dest
   wire [CTX_ID_BITS-1:0] out_frame_header_tuser;
   wire [TDEST_BITS-1:0]  out_frame_header_tdest;
   wire                   out_frame_header_tvalid;
   wire                   out_frame_header_tready;
   // frame consume input (from functions)
   reg [7:0]              in_frame_consume_tdata; // frame id
   reg [CTX_ID_BITS-1:0]  in_frame_consume_tuser;
   reg                    in_frame_consume_tvalid;
   wire                   in_frame_consume_tready;
   // incoming frame info (from DMAC)
   reg [31:0]             in_frame_info_tdata; // frame size
   reg [CTX_ID_BITS-1:0]  in_frame_info_tuser; // context id
   reg                    in_frame_info_tvalid;
   wire                   in_frame_info_tready;
   // incoming frame ready (to DMAC)
   wire [31:0]            in_frame_info_ready_tdata; // frame size
   wire [CTX_ID_BITS-1:0] in_frame_info_ready_tuser;
   wire                   in_frame_info_ready_tvalid;
   reg                    in_frame_info_ready_tready;
   // incoming frame header consume (from function)
   wire [CTX_ID_BITS-1:0] in_frame_header_consume_tuser;
   wire                   in_frame_header_consume_tvalid;
   wire                   in_frame_header_consume_tready;
   // frame completion input (from functions (direct or via data mover)
   wire [127:0]           out_frame_complete_tdata; // [63:0] frame addr; [95:64] frame size; [103:96] frame id, [104+:TDEST_BITS] dest
   wire [CTX_ID_BITS-1:0] out_frame_complete_tuser;
   wire                   out_frame_complete_tvalid;
   wire                   out_frame_complete_tready;
   // frame consume input (from AXI reader)
   reg [7:0]              out_frame_consume_tdata; // [7:0] frame id
   reg [CTX_ID_BITS-1:0]  out_frame_consume_tuser;
   reg                    out_frame_consume_tvalid;
   wire                   out_frame_consume_tready;
   // incoming buffer info (from DMAC)
   reg [31:0]             out_buffer_info_tdata; // frame size
   reg [CTX_ID_BITS-1:0]  out_buffer_info_tuser; // context id
   reg                    out_buffer_info_tvalid;
   wire                   out_buffer_info_tready;
   // outgoing frame ready (to DMAC)
   wire [31:0]            out_frame_info_tdata; // frame size
   wire [CTX_ID_BITS-1:0] out_frame_info_tuser;
   wire                   out_frame_info_tvalid;
   reg                    out_frame_info_tready;
   // outgoing frame request (to outgoing route controller)
   wire [CTX_ID_BITS-1:0] in_frame_out_req_tuser;
   wire [TDEST_BITS-1:0]  in_frame_out_req_tdest;
   wire                   in_frame_out_req_tvalid;
   reg                    in_frame_out_req_tready;
   // outgoing frame ready (from outgoing route controller)
   reg [CTX_ID_BITS-1:0]  in_frame_out_ready_tuser;
   reg                    in_frame_out_ready_tvalid;
   wire                   in_frame_out_ready_tready;
   // outgoin frame request (from incoming route controller)
   reg [CTX_ID_BITS-1:0]  out_frame_out_req_tuser;
   reg                    out_frame_out_req_tvalid;
   wire                   out_frame_out_req_tready;
   // outgoing frame ready (to incoming route controller)
   wire [CTX_ID_BITS-1:0] out_frame_out_ready_tuser;
   wire [TDEST_BITS-1:0]  out_frame_out_ready_tdest;
   wire                   out_frame_out_ready_tvalid;
   reg                    out_frame_out_ready_tready;
   // reg frame completion out
   wire [CTX_ID_BITS-1:0] in_frame_completion_tuser; // ch
   wire                   in_frame_completion_tvalid;
   // reg
   reg [ADDR_BITS-1:0]    cfg_araddr;
   reg                    cfg_arvalid;
   wire                   cfg_arready;
   wire [31:0]            cfg_rdata;
   wire [1:0]             cfg_rresp;
   wire                   cfg_rvalid;
   reg                    cfg_rready;
   reg [ADDR_BITS-1:0]    cfg_awaddr;
   reg                    cfg_awvalid;
   wire                   cfg_awready;
   reg [31:0]             cfg_wdata;
   reg                    cfg_wvalid;
   wire                   cfg_wready;
   wire [1:0]             cfg_bresp;
   wire                   cfg_bvalid;
   reg                    cfg_bready;

   wire [CTX_ID_BITS-1:0] dbg_frame_out_req_tuser;
   wire                   dbg_frame_out_req_tvalid;
   wire [CTX_ID_BITS-1:0] dbg_frame_out_ready_tuser;
   wire                   dbg_frame_out_ready_tvalid;

   reg           clk;
   reg           resetn;
   reg [31:0]    rd;

   route_controller #(
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .ADDR_BITS ( ADDR_BITS ),
       .DW_LOG ( DW_LOG ),
       .TDEST_BITS ( TDEST_BITS ),
       .BURST_BITS ( BURST_BITS ),
       .EXT_RELATION (EXT_RELATION ),
       .CREDIT_MAX ( CREDIT_MAX ),
       .ENABLE_MULTI_CONTROLLER ( ENABLE_MULTI_CONTROLLER ),
       .SELF_DEST ( SELF_DEST )
   ) dut (
      .*
   );

   initial begin
      clk = 1'b0;
      resetn = 1'b0;
      rd = $random(SEED);

      st_in_tvalid = 1'b0;
      st_out_tready = 1'b1;
      in_frame_consume_tvalid = 1'b0;
      in_frame_info_tvalid = 1'b0;
      in_frame_info_ready_tready = 1'b1;
      out_frame_consume_tvalid = 1'b0;
      out_buffer_info_tvalid = 1'b0;
      out_frame_info_tready =1'b1;
      cfg_arvalid = 1'b0;
      cfg_rready =1'b1;
      cfg_awvalid = 1'b0;
      cfg_wvalid =1'b0;
      cfg_bready = 1'b1;
      in_frame_out_req_tready = 1'b0;
      in_frame_out_ready_tvalid = 1'b0;
      out_frame_out_req_tvalid = 1'b0;
      out_frame_out_ready_tready = 1'b0;
   end
   always #5 clk = ~clk;
   always #100 resetn = 1'b1;
   always @(posedge clk) begin
      rd <= $random();
   end

   reg                  channel_valids[0:CH_NUM-1];
   reg                  channel_is_mmapped[0:CH_NUM-1];
   reg                  channel_disable_frame_out[0:CH_NUM-1];
   reg [TDEST_BITS-1:0] channel_dests[0:CH_NUM-1];
   reg [31:0]           channel_frame_size[0:CH_NUM-1];
   reg [63:0]           channel_iaddrs[0:CH_NUM-1][0:FRAME_MAX];
   reg [63:0]           channel_oaddrs[0:CH_NUM-1][0:FRAME_MAX];
   reg [FRAME_MAX-1:0]  channel_frame_valids[0:CH_NUM-1];
   reg [FRAME_MAX-1:0]  channel_frame_used[0:CH_NUM-1];
   reg [7:0]            channel_relations[0:CH_NUM-1][0:RELATION_NUM-1];

   reg [31:0] in_frame_size_saved[0:CH_NUM-1][0:255];
   reg [7:0]  in_frame_size_wpos[0:CH_NUM-1];
   reg [7:0]  in_frame_size_rpos[0:CH_NUM-1];
   reg [7:0]  in_frame_size_gpos[0:CH_NUM-1];

   reg [31:0] st_size_saved[0:CH_NUM-1][0:255];
   reg [7:0]  st_size_wpos[0:CH_NUM-1];
   reg [7:0]  st_size_rpos[0:CH_NUM-1];
   reg [7:0]  st_size_cpos[0:CH_NUM-1];

   reg [31:0] out_buffer_size_saved[0:CH_NUM-1][0:255];
   reg [31:0] out_frame_size_saved[0:CH_NUM-1][0:255];
   reg [63:0] out_frame_addr_saved[0:CH_NUM-1][0:255];
   reg [7:0]  out_buffer_size_wpos[0:CH_NUM-1];
   reg [7:0]  out_buffer_size_rpos[0:CH_NUM-1];
   reg [7:0]  out_buffer_size_gpos[0:CH_NUM-1];
   reg [7:0]  out_frame_wpos[0:CH_NUM-1];
   reg [7:0]  out_frame_rpos[0:CH_NUM-1];

   reg [DW-1:0]          st_data_saved[0:CH_NUM-1][0:255];
   reg [KW-1:0]          st_keep_saved[0:CH_NUM-1][0:255];
   reg                   st_last_saved[0:CH_NUM-1][0:255];
   reg [TDEST_BITS-1:0]  st_dest_saved[0:CH_NUM-1][0:255];
   reg                   st_sop_saved[0:CH_NUM-1][0:255];
   reg                   st_eop_saved[0:CH_NUM-1][0:255];
   reg                   st_eof_saved[0:CH_NUM-1][0:255];
   reg [BURST_BITS-1:0]  st_burst_saved[0:CH_NUM-1][0:255];
   reg [KW_LOG-1:0]      st_last_cnt_saved[0:CH_NUM-1][0:255];
   reg [7:0]             st_wpos[0:CH_NUM-1];
   reg [7:0]             st_rpos[0:CH_NUM-1];
   reg [7:0]             st_cpos[0:CH_NUM-1];

   initial begin
      for (int i=0; i<CH_NUM; i++) begin
         st_size_wpos[i] = 'd0;
         st_size_rpos[i] = 'd0;
         st_size_cpos[i] = 'd0;
         in_frame_size_wpos[i] = 'd0;
         in_frame_size_rpos[i] = 'd0;
         in_frame_size_gpos[i] = 'd0;
         out_buffer_size_wpos[i] = 'd0;
         out_buffer_size_rpos[i] = 'd0;
         out_buffer_size_gpos[i] = 'd0;
         out_frame_wpos[i] = 'd0;
         out_frame_rpos[i] = 'd0;
         st_wpos[i] = 'd0;
         st_rpos[i] = 'd0;
         st_cpos[i] = 'd0;
      end
   end

   st_nop_function #(
       .DW_LOG ( DW_LOG ),
       .CTX_ID_BITS ( CTX_ID_BITS )
   ) nop_func (
       .i_tdata ( user_st_out_tdata ),
       .i_tkeep ( user_st_out_tkeep ),
       .i_tuser ( user_st_out_tuser ),
       .i_tlast ( user_st_out_tlast ),
       .i_tid ( user_st_out_tid ),
       .i_tvalid ( user_st_out_tvalid ),
       .i_tready ( user_st_out_tready ),
       .o_tdata ( user_st_in_tdata ),
       .o_tkeep ( user_st_in_tkeep ),
       .o_tuser ( user_st_in_tuser ),
       .o_tlast ( user_st_in_tlast ),
       .o_tvalid ( user_st_in_tvalid ),
       .o_tready ( user_st_in_tready ),
       .iheader_tdata ( in_frame_header_tdata ),
       .iheader_tuser ( in_frame_header_tuser ),
       .iheader_tvalid ( in_frame_header_tvalid ),
       .iheader_tready ( in_frame_header_tready ),
       .oheader_tdata ( out_frame_header_tdata ),
       .oheader_tuser ( out_frame_header_tuser ),
       .oheader_tvalid ( out_frame_header_tvalid ),
       .oheader_tready ( out_frame_header_tready ),
       .iconsume_tuser ( in_frame_header_consume_tuser ),
       .iconsume_tvalid ( in_frame_header_consume_tvalid ),
       .iconsume_tready ( in_frame_header_consume_tready ),
       .cpl_tdata ( out_frame_complete_tdata ),
       .cpl_tuser ( out_frame_complete_tuser ),
       .cpl_tvalid ( out_frame_complete_tvalid ),
       .cpl_tready ( out_frame_complete_tready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   // in frame info ready
   always @(posedge clk) begin
      if (resetn) begin
         if (in_frame_info_ready_tvalid & in_frame_info_ready_tready) begin
            st_size_saved[in_frame_info_ready_tuser][st_size_wpos[in_frame_info_ready_tuser]] <= in_frame_info_ready_tdata;
            st_size_wpos[in_frame_info_ready_tuser] <= st_size_wpos[in_frame_info_ready_tuser] + 1'b1;
            $display("%d: [%2h] in frame info ready size: %h", $time, in_frame_info_ready_tuser, in_frame_info_ready_tdata);
         end
      end
   end
   // in frame header check
   logic in_frame_is_valid;
   always @(posedge clk) begin
      if (resetn) begin
         if (in_frame_header_tvalid && in_frame_header_tready) begin
            in_frame_is_valid = ~channel_is_mmapped[in_frame_header_tuser];
            if (in_frame_header_tdata[63:0] === channel_iaddrs[in_frame_header_tuser][in_frame_header_tdata[96+:8]]) begin
               in_frame_is_valid = 1'b1;
            end
            if (~in_frame_is_valid ||
                (channel_is_mmapped[in_frame_header_tuser] || |channel_frame_size[in_frame_header_tuser] ?
                 in_frame_header_tdata[64+:32] > channel_frame_size[in_frame_header_tuser] :
                 in_frame_header_tdata[64+:32] !== in_frame_size_saved[in_frame_header_tuser][in_frame_size_rpos[in_frame_header_tuser]]) ||
                in_frame_header_tdata[104+:TDEST_BITS] !== SELF_DEST ||
                in_frame_header_tdest !== channel_dests[in_frame_header_tuser]) begin
               $error("%d: [%2h] in frame header addr[%2d]: %h %h, size: %h %h, %h, %h %h", $time, in_frame_header_tuser,
                      in_frame_header_tdata[96+:8], in_frame_header_tdata[63:0], channel_iaddrs[in_frame_header_tuser][in_frame_header_tdata[96+:8]],
                      in_frame_header_tdata[64+:32],
                      channel_is_mmapped[in_frame_header_tuser] ? channel_frame_size[in_frame_header_tuser] :
                      in_frame_size_saved[in_frame_header_tuser][in_frame_size_rpos[in_frame_header_tuser]],
                      in_frame_header_tdata[104+:TDEST_BITS],
                      in_frame_header_tdest, channel_dests[in_frame_header_tuser]);
            end else if (in_frame_header_tdata[64+:32] !== in_frame_size_saved[in_frame_header_tuser][in_frame_size_rpos[in_frame_header_tuser]] ||
                         in_frame_header_tdata[104+:TDEST_BITS] !== SELF_DEST) begin
               $error("%d: [%2h] in frame header size: %h %h, %h", $time, in_frame_header_tuser,
                      in_frame_header_tdata[64+:32],
                      in_frame_size_saved[in_frame_header_tuser][in_frame_size_rpos[in_frame_header_tuser]],
                      in_frame_header_tdata[104+:TDEST_BITS]);
            end else begin
               $display("%d: [%2h] in frame header size: %h", $time, in_frame_header_tuser, in_frame_header_tdata[64+:32]);
            end
            in_frame_size_rpos[in_frame_header_tuser] <= in_frame_size_rpos[in_frame_header_tuser] + 1'b1;
         end
      end
   end
   // out frame info check
   always @(posedge clk) begin
      if (resetn) begin
         if (out_frame_info_tvalid & out_frame_info_tready) begin
            if (out_frame_info_tdata !== st_size_saved[out_frame_info_tuser][st_size_cpos[out_frame_info_tuser]]) begin
               $error("%d: [%2h] out frame info size: %h %h", $time, out_frame_info_tuser, out_frame_info_tdata,
                      st_size_saved[out_frame_info_tuser][st_size_cpos[out_frame_info_tuser]]);
            end
            st_size_cpos[out_frame_info_tuser] <= st_size_cpos[out_frame_info_tuser] + 1'b1;
         end
      end
   end
   // out frame header check
   logic out_frame_is_valid;
   always @(posedge clk) begin
      if (resetn) begin
         if (out_frame_header_tvalid && out_frame_header_tready) begin
            out_frame_is_valid = ~channel_is_mmapped[out_frame_header_tuser];
            if (out_frame_header_tdata[63:0] === channel_oaddrs[out_frame_header_tuser][out_frame_header_tdata[96+:8]]) begin
               out_frame_is_valid = 1'b1;
            end
            if (~out_frame_is_valid ||
                (out_frame_header_tdata[64+:32] > channel_frame_size[out_frame_header_tuser] &&
                 (channel_is_mmapped[out_frame_header_tuser] || channel_frame_size[out_frame_header_tuser])) ||
                out_frame_header_tdata[104+:TDEST_BITS] !== SELF_DEST ||
                out_frame_header_tdest !== channel_dests[out_frame_header_tuser]) begin
               $error("%d: [%2h] out frame header addr[%2d]: %h %h, size: %h %h, %h", $time, out_frame_header_tuser,
                      out_frame_header_tdata[96+:8], out_frame_header_tdata[63:0], channel_oaddrs[out_frame_header_tuser][out_frame_header_tdata[96+:8]],
                      out_frame_header_tdata[64+:32], channel_frame_size[out_frame_header_tuser],
                      out_frame_header_tdata[104+:TDEST_BITS]);
            end else if (out_frame_header_tdata[64+:32] !== out_buffer_size_saved[out_frame_header_tuser][out_buffer_size_rpos[out_frame_header_tuser]] ||
                         out_frame_header_tdata[104+:TDEST_BITS] !== SELF_DEST) begin
               $error("%d: [%2h] out frame header size: %h %h, %h", $time, out_frame_header_tuser,
                      out_frame_header_tdata[64+:32],
                      out_buffer_size_saved[out_frame_header_tuser][out_buffer_size_rpos[out_frame_header_tuser]],
                      out_frame_header_tdata[104+:TDEST_BITS]);
            end else begin
               $display("%d: [%2h] out frame header size: %h", $time, out_frame_header_tuser, out_frame_header_tdata[64+:32]);
            end
            out_frame_addr_saved[out_frame_header_tuser][out_buffer_size_rpos[out_frame_header_tuser]] <= out_frame_header_tdata[63:0];
            out_buffer_size_rpos[out_frame_header_tuser] <= out_buffer_size_rpos[out_frame_header_tuser] + 1'b1;
         end
      end
   end

   // in consume
   always @(posedge clk) begin
      if (resetn) begin
         if (in_frame_header_consume_tvalid & in_frame_header_consume_tready) begin
            $display("%d: [%2h] in frame header consume", $time, in_frame_header_consume_tuser);
         end
      end
   end

   // st data check
   initial begin
      for (int i=0; i<CH_NUM; i++) begin
         st_wpos[i] = 'd0;
         st_rpos[i] = 'd0;
         st_cpos[i] = 'd0;
      end
   end
   reg [BURST_BITS:0] st_check_burst;
   always @(posedge clk) begin
      if (~resetn) begin
         st_check_burst <= 'd0;
      end else begin
         if (user_st_out_tvalid & user_st_out_tready) begin
            if (user_st_out_tdata !== st_data_saved[user_st_out_tuser][st_rpos[user_st_out_tuser]] ||
                user_st_out_tkeep !== st_keep_saved[user_st_out_tuser][st_rpos[user_st_out_tuser]] ||
                user_st_out_tlast !== st_eop_saved[user_st_out_tuser][st_rpos[user_st_out_tuser]] ||
                user_st_out_tdest !== st_dest_saved[user_st_out_tuser][st_rpos[user_st_out_tuser]]) begin
               $error("%d: [%2h] user st %h %h, %h %h, %h %h", $time, user_st_out_tuser,
                      user_st_out_tdata, st_data_saved[user_st_out_tuser][st_rpos[user_st_out_tuser]],
                      user_st_out_tkeep, st_keep_saved[user_st_out_tuser][st_rpos[user_st_out_tuser]],
                      user_st_out_tlast, st_eop_saved[user_st_out_tuser][st_rpos[user_st_out_tuser]],
                      user_st_out_tdest, st_dest_saved[user_st_out_tuser][st_rpos[user_st_out_tuser]]);
            end
            st_rpos[user_st_out_tuser] <= st_rpos[user_st_out_tuser] + 1'b1;
         end
         if (st_out_tvalid & st_out_tready) begin
            if (st_out_tdata !== st_data_saved[st_out_tuser][st_cpos[st_out_tuser]] ||
                st_out_tkeep !== st_keep_saved[st_out_tuser][st_cpos[st_out_tuser]] ||
                st_out_tlast !== st_last_saved[st_out_tuser][st_cpos[st_out_tuser]] ||
                st_out_sop !== st_sop_saved[st_out_tuser][st_cpos[st_out_tuser]] ||
                st_out_eop !== st_eop_saved[st_out_tuser][st_cpos[st_out_tuser]] ||
                (st_out_sop && st_out_burst !== st_burst_saved[st_out_tuser][st_cpos[st_out_tuser]]) ||
                (st_out_sop && st_out_last_cnt !== st_last_cnt_saved[st_out_tuser][st_cpos[st_out_tuser]])) begin
               $error("%d: [%2h] st %h %h, %h %h, %h %h, %h %h, %h %h, %h %h", $time, st_out_tuser,
                      st_out_tdata, st_data_saved[st_out_tuser][st_cpos[st_out_tuser]],
                      st_out_tkeep, st_keep_saved[st_out_tuser][st_cpos[st_out_tuser]],
                      st_out_tlast, st_last_saved[st_out_tuser][st_cpos[st_out_tuser]],
                      st_out_sop, st_sop_saved[st_out_tuser][st_cpos[st_out_tuser]],
                      st_out_eop, st_eop_saved[st_out_tuser][st_cpos[st_out_tuser]],
                      st_out_burst, st_burst_saved[st_out_tuser][st_cpos[st_out_tuser]],
                      st_out_last_cnt, st_last_cnt_saved[st_out_tuser][st_cpos[st_out_tuser]]);
            end
            if (st_out_tlast) begin
               $display("%d: [%2h] st %h %h %h %h", $time, st_out_tuser, st_out_tdata, st_out_tlast, st_out_sop, st_out_eop);
            end
            st_cpos[st_out_tuser] <= st_cpos[st_out_tuser] + 1'b1;
         end
         st_out_tready <= ST_OUT_BITS > 0 ? &rd[3+:ST_OUT_BITS_MOD] : 1'b1;
      end
   end

   // in frame completion check
   logic [15:0] issued_frames[0:CH_NUM-1];
   logic [15:0] completion_frames[0:CH_NUM-1];
   always @(posedge clk) begin
      if (~resetn) begin
         for (int i=0; i<CH_NUM; i++) begin
            issued_frames[i] <= 'd0;
            completion_frames[i] <= 'd0;
         end
      end else begin
         if (in_frame_completion_tvalid) begin
            completion_frames[in_frame_completion_tuser] <= completion_frames[in_frame_completion_tuser] + 1'b1;
         end
      end
   end

   task static setup_regs();
      logic [CTX_ID_BITS-1:0] ch;
      logic                   is_mmapped = 1'b0;
      logic                   disable_frame_out_signal = 1'b0;
      logic                   ch_valid = 1'b0;
      logic [TDEST_BITS-1:0]  destination = {TDEST_BITS{1'b1}};
      logic [31:0]            frame_size = 0;
      logic [31:0]            addr_mid = 0;
      logic [FRAME_MAX-1:0]   frame_valids = 0;
      logic [FRAME_MAX-1:0]   frame_used = 0;
      logic [3:0]             relation_num = 0;
      logic [RELATION_NUM*8-1:0] relations = 0;
      logic [CTX_ID_BITS:0]      relation_total = 0;
      logic [CH_NUM-1:0]         relation_used = 0;
      logic                      wvalid, awvalid, arvalid;
      logic [1:0]                stats;
      for (int i=0; i<CH_NUM; i++) begin
         ch = i;
         ch_valid = rd[ch];
         is_mmapped = MMAPPED > 0 ? rd[1+ch] : 1'b0;
         disable_frame_out_signal = DISABLE_FRAME_OUT > 0 ? rd[2+ch] : 1'b0;
         destination = ch_valid ? is_mmapped ? MM_TDEST : rd[14+:TDEST_BITS] : {TDEST_BITS{1'b1}};
         frame_size = {{26-FRAME_SIZE_BITS{1'b0}}, rd[FRAME_SIZE_BITS-1:6], 6'd0};
         relation_num = NEED_RELATION > 0 ? 3'd1 : 3'd0;
         if (relation_total + relation_num > CH_NUM) relation_num = CH_NUM - relation_total;
         if (NEED_RELATION > 0 && relation_num == 0) ch_valid = 1'b0;
         relation_total += relation_num;
         for (int j=0; j<relation_num;) @(posedge clk) begin
            relations[8*j+:8] = 'd0 | (ch + j);
            if (!relation_used[relations[8*j+:8]]) begin
               relation_used[relations[8*j+:8]] = 1'b1;
               j++;
            end
         end
         frame_valids = (32'd1 << ((MMAPPED_FRAME_MAX < rd[3+:5] ? MMAPPED_FRAME_MAX : rd[3+:5])+FRAME0+1)) - 1'b1;
         channel_valids[ch] = ch_valid;

         if (~ch_valid) continue;

         channel_is_mmapped[ch] = is_mmapped;
         channel_disable_frame_out[ch] = disable_frame_out_signal;
         channel_dests[ch] = destination;
         channel_frame_size[ch] = frame_size;
         channel_frame_valids[ch] = frame_valids;
         for (int j=0; j<relation_num; j++) channel_relations[ch][j] = relations[j*8+:8];

         $display("[%2h]: valid: %d, mmap: %d, disable: %d, dest: %x, size: %h, valids: %h, relation: %d", ch,
                  ch_valid, is_mmapped, disable_frame_out_signal, destination, frame_size, frame_valids, relation_num);
         for (int j=0; j<relation_num; j++) $display("[%2h]:  [%2d]: %h", ch, j, relations[j*8+:8]);

         // write configs
         stats = 0;
         for (logic [ADDR_BITS:0] k=0; k<{1'b1,{ADDR_BITS{1'b0}}}; k+={1'b1, {ADDR_BITS-1{1'b0}}}) begin
            for (logic [4:0] j=0; j<(EXT_RELATION > 0 ? 6 : 5);) @(posedge clk) begin : write_config
               awvalid = REG_BITS > 0 ? &rd[3+:REG_BITS_MOD] : 1'b1;
               if (~stats[0] && awvalid) begin
                  cfg_awaddr <= k[ADDR_BITS-1:0] | {ch, j, 2'd0};
                  cfg_awvalid <= awvalid;
                  stats[0] <= awvalid;
               end else begin
                  cfg_awvalid <= cfg_awvalid & ~cfg_awready;
               end
               wvalid = REG_BITS > 0 ? &rd[8+:REG_BITS_MOD] : 1'b1;
               if (~stats[1] && wvalid) begin
                  cfg_wdata <= j == 0 ? {{16-TDEST_BITS{1'b0}}, destination, 7'd0, disable_frame_out_signal,
                                   3'd0, is_mmapped, 3'd0, ch_valid} :
                               j == 1 ? frame_size :
                               j == 2 ? frame_valids :
                               j == 3 ? frame_used :
                               j == 4 ? {relations[23:0], 4'd0, relation_num} : relations >> 24;
                  cfg_wvalid <= wvalid;
                  stats[1] <= wvalid;
               end else begin
                  cfg_wvalid <= cfg_wvalid & ~cfg_wready;
               end
               if (cfg_bvalid & cfg_bready) begin
                  stats <= 2'd0;
                  j++;
               end
               cfg_bready <= REG_BITS > 0 ? &rd[13+:REG_BITS_MOD] : 1'b1;
            end
            if (~is_mmapped) continue;
            // write addrs
            for (logic [5:0] j=FRAME0; j<32;) @(posedge clk) begin : write_addrs
               awvalid = REG_BITS > 0 ? &rd[5+:REG_BITS_MOD] : 1'b1;
               if (~stats[0] && awvalid) begin
                  cfg_awaddr <= k[ADDR_BITS-1:0] | {ch, j[4:0], 2'd0};
                  cfg_awvalid <= awvalid;
                  stats[0] <= awvalid;
               end else begin
                  cfg_awvalid <= cfg_awvalid & ~cfg_awready;
               end
               wvalid = REG_BITS > 0 ? &rd[9+:REG_BITS_MOD] : 1'b1;
               if (~stats[1] && wvalid) begin
                  cfg_wdata <= rd;
                  cfg_wvalid <= wvalid;
                  if (k == 0) begin
                     channel_iaddrs[ch][j-FRAME0] <= {20'd0, rd, 12'd0};
                     //$display("%d: in addr[%h][%2h] %16h", $time, ch, j-FRAME0, {20'd0, rd, 12'd0});
                  end else begin
                     channel_oaddrs[ch][j-FRAME0] <= {20'd0, rd, 12'd0};
                     //$display("%d: out addr[%h][%2h] %16h", $time, ch, j-FRAME0, {20'd0, rd, 12'd0});
                  end
                  stats[1] <= wvalid;
               end else begin
                  cfg_wvalid <= cfg_wvalid & ~cfg_wready;
               end
               if (cfg_bvalid & cfg_bready) begin
                  stats <= 2'd0;
                  j++;
               end
               cfg_bready <= REG_BITS > 0 ? &rd[13+:REG_BITS_MOD] : 1'b1;
               if (~frame_valids[j]) break;
            end
            // read addrs
            for (logic [5:0] j=FRAME0; j<32;) @(posedge clk) begin : write_addrs
               arvalid = REG_BITS > 0 ? &rd[7+:REG_BITS_MOD] : 1'b1;
               if (~stats[0] && arvalid) begin
                  cfg_araddr <= k[ADDR_BITS-1:0] | {ch, j[4:0], 2'd0};
                  cfg_arvalid <= awvalid;
                  stats[0] <= arvalid;
               end else begin
                  cfg_arvalid <= cfg_arvalid & ~cfg_arready;
               end
               if (cfg_rvalid && cfg_rready) begin
                  if (k == 0) begin
                     if (cfg_rdata !== channel_iaddrs[ch][j-FRAME0][43:12]) begin
                        $error("%d: in addr[%2h][%2h] check: %h %h", $time, ch, j-FRAME0, cfg_rdata, channel_iaddrs[ch][j-FRAME0][43:12]);
                     end else begin
                        //$display("%d: in addr check[%h][%2h] %8h %16h", $time, ch, j-FRAME0, cfg_rdata, channel_iaddrs[ch][j-FRAME0]);
                     end
                  end else begin
                     if (cfg_rdata !== channel_oaddrs[ch][j-FRAME0][43:12]) begin
                        $error("%d: out addr[%2h][%2h] check: %h %h", $time, ch, j-FRAME0, cfg_rdata, channel_oaddrs[ch][j-FRAME0][43:12]);
                     end else begin
                        //$display("%d: out addr check[%h][%2h] %8h %16h", $time, ch, j-FRAME0, cfg_rdata, channel_oaddrs[ch][j-FRAME0]);
                     end
                  end
                  stats <= 2'd0;
                  j++;
               end
               cfg_rready <= REG_BITS > 0 ? &rd[14+:REG_BITS_MOD] : 1'b1;
               if (~frame_valids[j]) break;
            end
         end
      end
   endtask

   task static generate_frame_info();
      logic [CTX_ID_BITS-1:0] ch;
      logic [31:0]            frame_size, in_frame_size_mod, out_buffer_size_mod;
      logic                   valid = 0;
      logic                   idone = 0, odone = 0;
      int                     in_frames = 0;
      int                     out_buffers = 0;
      while (in_frames < FRAME_NUM || out_buffers < FRAME_NUM || in_frame_info_tvalid || out_frame_info_tvalid) @(posedge clk) begin
         if ((~in_frame_info_tvalid | in_frame_info_tready) &&
             (~out_buffer_info_tvalid | out_buffer_info_tready) &&
             (in_frames < FRAME_NUM || out_buffers < FRAME_NUM)) begin
            if (!valid || (idone && odone)) begin
               ch = rd[10+:CTX_ID_BITS];
               valid = FRAME_INFO_BITS > 0 ? &rd[5+:FRAME_INFO_BITS_MOD] : 1'b1;
               valid = valid & channel_valids[ch];
               frame_size = {{26-FRAME_SIZE_BITS{1'b0}}, rd[FRAME_SIZE_BITS-1:0]};
               idone = 0;
               odone = 0;
            end
            if (valid && ~idone && (FRAME_INFO_BITS > 0 ? &rd[5+:FRAME_INFO_BITS_MOD] : 1'b1)) begin
               in_frame_info_tvalid <= valid;
               in_frame_info_tdata <= frame_size;
               in_frame_info_tuser <= ch;
               idone = 1;
            end else begin
               in_frame_info_tvalid <= in_frame_info_tvalid & ~in_frame_info_tready;
            end
            if (valid && ~odone && (BUFFER_INFO_BITS > 0 ? &rd[5+:BUFFER_INFO_BITS_MOD] : 1'b1)) begin
               out_buffer_info_tvalid <= valid;
               out_buffer_info_tdata <= frame_size;
               out_buffer_info_tuser <= ch;
               odone = 1;
            end else begin
               out_buffer_info_tvalid <= out_buffer_info_tvalid & ~out_buffer_info_tready;
            end
         end else begin
            in_frame_info_tvalid <= in_frame_info_tvalid & ~in_frame_info_tready;
            out_buffer_info_tvalid <= out_buffer_info_tvalid & ~out_buffer_info_tready;
         end
         if (in_frame_info_tvalid && in_frame_info_tready) begin
            if (in_frame_info_tdata > channel_frame_size[in_frame_info_tuser] &&
                (channel_is_mmapped[in_frame_info_tuser] || |channel_frame_size[in_frame_info_tuser])) begin
               in_frame_size_mod = channel_frame_size[in_frame_info_tuser];
            end else begin
               in_frame_size_mod = in_frame_info_tdata;
            end
            in_frame_size_saved[in_frame_info_tuser][in_frame_size_wpos[in_frame_info_tuser]] <= in_frame_size_mod;
            in_frame_size_wpos[in_frame_info_tuser] <= in_frame_size_wpos[in_frame_info_tuser] + 1'b1;
            $display("%d: [%2h] in frame info size: %h %h", $time, in_frame_info_tuser,
                     in_frame_info_tdata, in_frame_size_mod);
            in_frames++;
         end
         if (out_buffer_info_tvalid && out_buffer_info_tready) begin
            if (out_buffer_info_tdata > channel_frame_size[out_buffer_info_tuser] &&
                (channel_is_mmapped[out_buffer_info_tuser] || |channel_frame_size[out_buffer_info_tuser])) begin
               out_buffer_size_mod = channel_frame_size[out_buffer_info_tuser];
            end else begin
               out_buffer_size_mod = out_buffer_info_tdata;
            end
            out_buffer_size_saved[out_buffer_info_tuser][out_buffer_size_wpos[out_buffer_info_tuser]] <= out_buffer_size_mod;
            out_buffer_size_wpos[out_buffer_info_tuser] <= out_buffer_size_wpos[out_buffer_info_tuser] + 1'b1;
            $display("%d: [%2h] out buffer info size: %h %h", $time, out_buffer_info_tuser, out_buffer_size_mod, out_buffer_info_tdata);
            out_buffers++;
         end
      end
      @(posedge clk) begin
         in_frame_info_tvalid <= 1'b0;
         out_buffer_info_tvalid <= 1'b0;
      end
   endtask

   task static generate_frame_complete();
      logic [CTX_ID_BITS-1:0] ch = 0;
      logic [CTX_ID_BITS-1:0] prev_ch = 0;
      logic [31:0]            frame_size;
      logic [63:0]            frame_addr;
      logic                   valid;
      int                     frames = 0;
      while (frames < FRAME_NUM || out_frame_complete_tvalid) @(posedge clk) begin
         if ((~out_frame_complete_tvalid | out_frame_complete_tready) &&
             (FRAME_COMPLETE_BITS > 0 ? &rd[7+:FRAME_COMPLETE_BITS_MOD] : 1'b1)) begin
            prev_ch = ch -1;
            while (out_buffer_size_rpos[ch] == out_buffer_size_gpos[ch] && ((ch + 1) & {1'b0, {CTX_ID_BITS{1'b1}}}) != prev_ch) ch++;
            if (out_buffer_size_rpos[ch] != out_buffer_size_gpos[ch] &&
                in_frame_size_rpos[ch] != in_frame_size_gpos[ch]) begin
               frame_size = {{26-FRAME_SIZE_BITS{1'b0}}, rd[FRAME_SIZE_BITS-1:0]};
               frame_addr = out_frame_addr_saved[ch][out_buffer_size_gpos[ch]];
               if (frame_size > out_buffer_size_saved[ch][out_buffer_size_gpos[ch]]) begin
                  frame_size = out_buffer_size_saved[ch][out_buffer_size_gpos[ch]];
               end
               if (in_frame_size_saved[ch][in_frame_size_gpos[ch]] > out_buffer_size_saved[ch][out_buffer_size_gpos[ch]]) begin
                  $error("%d: [%2h] in/out frame size wrong: in %h, out %h", $time, ch,
                         in_frame_size_saved[ch][in_frame_size_gpos[ch]], out_buffer_size_saved[ch][out_buffer_size_gpos[ch]]);
               end
               //out_frame_complete_tvalid <= 1'b1;
               //out_frame_complete_tuser <= ch;
               //out_frame_complete_tdata <= {frame_size, frame_addr};
               out_buffer_size_gpos[ch] <= out_buffer_size_gpos[ch] + 1'b1;
               in_frame_size_gpos[ch] <= in_frame_size_gpos[ch] + 1'b1;
               out_frame_size_saved[ch][out_frame_wpos[ch]] <= frame_size;
               out_frame_wpos[ch] <= out_frame_wpos[ch] + 1'b1;
               ch++;
            end else begin
               //out_frame_complete_tvalid <= 1'b0;
            end
         end else begin
            //out_frame_complete_tvalid <= out_frame_complete_tvalid & ~out_frame_complete_tready;
         end
         if (out_frame_complete_tvalid & out_frame_complete_tready) begin
            frames++;
            $display("%d: [%2h] frame complete (%d) size: %h", $time, out_frame_complete_tuser, frames, out_frame_complete_tdata);
         end
      end
   endtask

   task static generate_stream_data();
      logic [31:0] pos[0:CH_NUM-1];
      logic [CTX_ID_BITS-1:0] ch = 0, prev_ch = 0;
      logic [4:0]             burst = 0;
      logic [DW-1:0]          data;
      logic [KW-1:0]          keep;
      logic                   last = 1;
      logic                   valid;
      logic                   sop = 0;
      logic                   eop = 0;
      logic [KW_LOG-1:0]      last_pos;
      int                     frames = 0;
      logic [32*CH_NUM-1:0]   poses;
      for (int i=0; i<CH_NUM; i++) pos[i] = 0;
      while (frames < FRAME_NUM || valid) @(posedge clk) begin
         if (~|burst) begin
            ch = rd[14+:CTX_ID_BITS];
            if (~|pos[ch]) begin
               if (channel_valids[ch]) begin
                  if (st_size_wpos[ch] !== st_size_rpos[ch]) begin
                     pos[ch] = st_size_saved[ch][st_size_rpos[ch]];
                     $display("%d: [%2h] stream start: %h (%2d)", $time, ch, pos[ch], st_size_rpos[ch]);
                     st_size_rpos[ch] = st_size_rpos[ch] + 1'b1;
                  end
               end
            end
            if (|pos[ch] /*&& ch != prev_ch*/) begin
               if ((pos[ch] + KW - 1) / KW <= 'd16) begin
                  burst = (pos[ch] + KW - 1) / KW;
                  last_pos = pos[ch]-1;
               end else begin
                  burst = 'd16;
                  last_pos = {KW_LOG{1'b1}};
               end
               sop = 1'b1;
               prev_ch = ch;
               if ((pos[ch] + KW - 1) / KW <= 'd16) begin
                  issued_frames[ch] <= issued_frames[ch] + 1'b1;
               end
            end
         end
         for (int i=0; i<CH_NUM; i++) poses[i*32+:32] = pos[i];
         if ((~st_in_tvalid | st_in_tready) & |burst)  begin
            for (int i=0; i<KW; i++) begin
               if (burst > 1 || i < pos[ch]) begin
                  data[i*8+:8] = rd ^ (64'hdeadbeef01050910 >> (i&63));
                  keep[i] = 1'b1;
               end else begin
                  data[i*8+:8] = 'd0;
                  keep[i] = 1'b0;
               end
            end
            eop = burst == 1;
            last = pos[ch] <= KW;
            valid = ST_IN_BITS > 0 ? &rd[6+:ST_IN_BITS_MOD] : 1'b1;
            if (valid) begin
               st_in_tdata <= data;
               st_in_tkeep <= keep;
               st_in_tuser <= ch;
               st_in_tlast <= eop;
               st_in_eof <= last;
               st_data_saved[ch][st_wpos[ch]] <= data;
               st_keep_saved[ch][st_wpos[ch]] <= keep;
               st_last_saved[ch][st_wpos[ch]] <= last;
               st_dest_saved[ch][st_wpos[ch]] <= channel_dests[ch];
               st_sop_saved[ch][st_wpos[ch]] <= sop;
               st_eop_saved[ch][st_wpos[ch]] <= eop;
               st_burst_saved[ch][st_wpos[ch]] <= burst - 1;
               st_last_cnt_saved[ch][st_wpos[ch]] <= last_pos;
               st_wpos[ch] <= st_wpos[ch] + 1'b1;
               if (pos[ch] <= DW/8) begin
                  pos[ch] = 'd0;
                  if (channel_valids[ch]) frames++;
               end else begin
                  pos[ch] -= DW/8;
               end
               sop = 1'b0;
               burst--;
            end
            st_in_tvalid <= valid;
         end else begin
            valid = 0;
            st_in_tvalid <= st_in_tvalid & ~st_in_tready;
         end
      end
   endtask

   logic frame_completions_match;
   initial begin
      @(posedge clk);
      while (resetn !== 1'b1) @(posedge clk);

      setup_regs();

      fork
         begin
            generate_frame_info();
         end
         begin
            generate_frame_complete();
         end
         begin
            generate_stream_data();
         end
      join

      for (int i=0; i<100; i++) @(posedge clk) begin
         frame_completions_match = 1;
         for (int j=0; j<CH_NUM; j++) begin
            if (issued_frames[j] !== completion_frames[j]) frame_completions_match = 0;
         end
         if (frame_completions_match) $finish;
      end
      $error("%d: frame completion timeout", $time);
      for (int j=0; j<CH_NUM; j++) begin
         $display("%d: [%2h] %h %h", $time, j, issued_frames[j], completion_frames[j]);
      end
      $finish();
   end

endmodule

module st_nop_function #(
    parameter DW_LOG = 9,
    parameter CTX_ID_BITS = 4
    ) (
    input [(1<<DW_LOG)-1:0]      i_tdata,
    input [(1<<(DW_LOG-3))-1:0]  i_tkeep,
    input [CTX_ID_BITS-1:0]      i_tuser,
    input                        i_tlast, // eop
    input                        i_tid, // eof
    input                        i_tvalid,
    output                       i_tready,
    output [(1<<DW_LOG)-1:0]     o_tdata,
    output [(1<<(DW_LOG-3))-1:0] o_tkeep,
    output [CTX_ID_BITS-1:0]     o_tuser,
    output                       o_tlast,
    output                       o_tvalid,
    input                        o_tready,
    input [127:0]                iheader_tdata,
    input [CTX_ID_BITS-1:0]      iheader_tuser,
    input                        iheader_tvalid,
    output                       iheader_tready,
    input [127:0]                oheader_tdata,
    input [CTX_ID_BITS-1:0]      oheader_tuser,
    input                        oheader_tvalid,
    output                       oheader_tready,
    output [CTX_ID_BITS-1:0]     iconsume_tuser,
    output                       iconsume_tvalid,
    input                        iconsume_tready,
    output [95:0]                cpl_tdata,
    output [CTX_ID_BITS-1:0]     cpl_tuser,
    output                       cpl_tvalid,
    input                        cpl_tready,
    input                        clk,
    input                        resetn
    );

   parameter DW = 1 << DW_LOG;
   parameter KW = 1 << (DW_LOG-3);
   parameter CH_NUM = 1 << CTX_ID_BITS;

   wire [CH_NUM-1:0]         iheader_readys;
   wire [CH_NUM-1:0]         oheader_readys;
   assign iheader_tready = iheader_readys >> iheader_tuser;
   assign oheader_tready = oheader_readys >> oheader_tuser;

   wire [CH_NUM-1:0]         cpl_valids;
   wire [CH_NUM-1:0]         cpl_readys;
   wire [CH_NUM*96-1:0]      cpl_data;
   wire [CH_NUM-1:0]         consume_valids;
   wire [CH_NUM-1:0]         consume_readys;
   wire [CH_NUM-1:0]         out_lasts;
   wire [CH_NUM-1:0]         out_enables;

   generate
      for (genvar i=0; i<CH_NUM; i++) begin
         wire [63:0] ih_addr;
         wire [31:0] ih_size;
         wire [7:0]  ih_frame_id;
         wire        ih_valid, ih_ready;
         wire [63:0] oh_addr;
         wire [31:0] oh_size;
         wire [7:0]  oh_frame_id;
         wire        oh_valid, oh_ready;

         wire        iheader_valid = iheader_tvalid && iheader_tuser == i;
         fifo #(
             .DW ( 104 ),
             .DL ( 4 )
         ) iheader_fifo (
             .idata ( iheader_tdata[103:0] ),
             .ivalid ( iheader_valid ),
             .iready ( iheader_readys[i] ),
             .odata ( {ih_frame_id, ih_size, ih_addr} ),
             .ovalid ( ih_valid ),
             .oready ( ih_ready ),
             .clk ( clk ),
             .resetn ( resetn )
         );

         wire        oheader_valid = oheader_tvalid && oheader_tuser == i;
         fifo #(
             .DW ( 104 ),
             .DL ( 4 )
         ) oheader_fifo (
             .idata ( oheader_tdata[103:0] ),
             .ivalid ( oheader_valid ),
             .iready ( oheader_readys[i] ),
             .odata ( {oh_frame_id, oh_size, oh_addr} ),
             .ovalid ( oh_valid ),
             .oready ( oh_ready ),
             .clk ( clk ),
             .resetn ( resetn )
         );

         reg         max_valid;
         wire        oc_valid = ih_valid & oh_valid & ~max_valid;
         wire [31:0] oc_size = ih_size;
         wire [63:0] oc_addr = oh_addr;
         wire        oc_ready;
         assign ih_ready = oc_valid;
         assign oh_ready = oc_valid;

         fifo #(
             .DW ( 96 ),
             .DL ( 2 )
         ) ocomplete_fifo (
             .idata ( {oc_size, oc_addr} ),
             .ivalid ( oc_valid ),
             .iready ( oc_ready ),
             .odata ( {cpl_data[i*96+:96]} ),
             .ovalid ( cpl_valids[i] ),
             .oready ( cpl_readys[i] ),
             .clk ( clk ),
             .resetn ( resetn )
         );

         fifo #(
             .DW ( 1 ),
             .DL ( 4 )
         ) oconsume_fifo (
             .idata ( 1'b0 ),
             .ivalid ( oc_valid & oc_ready ),
             .iready ( ),
             .odata ( ),
             .ovalid ( consume_valids[i] ),
             .oready ( consume_readys[i] ),
             .clk ( clk ),
             .resetn ( resetn )
         );

         wire        w_cur_last;
         reg [31:0]  max_size;
         always @(posedge clk) begin
            if (~resetn) begin
               max_valid <= 1'b0;
            end else if (oc_valid & oc_ready) begin
               max_valid <= 1'b1;
               max_size <= oc_size;
               if (ih_size > oh_size) begin
                  $error("%d: [%2h] in/out size unsupported: %h %h", $time, i, ih_size, oh_size);
               end
            end else if (i_tvalid && i_tready && i_tuser == i && w_cur_last) begin
               max_valid <= 1'b0;
            end
         end
         assign out_enables[i] = max_valid;

         reg [31:0]  cur_size;
         reg         cur_last;
         always @(posedge clk) begin
            if (~resetn) begin
               cur_size <= 'd0;
               cur_last <= 1'b0;
            end else if (i_tvalid && i_tready && i_tuser == i) begin
               if (w_cur_last) begin
                  if (~i_tid) begin
                     $error("%d: function end of frame: %h %h %h, %h", $time, cur_size, i_tkeep, i_tid, max_size);
                  end
                  cur_last <= 1'b1;
                  cur_size <= 'd0;
               end else begin
                  cur_last <= 1'b0;
                  cur_size <= cur_size + DW/8;
               end
            end
         end
         assign w_cur_last = cur_size + DW/8 >= max_size;

         assign out_lasts[i] = cur_last;
      end
   endgenerate

   reg [CTX_ID_BITS-1:0] cpl_user;
   reg [CTX_ID_BITS-1:0] cpl_user_search_pos;
   always @(posedge clk) begin
      if (~resetn) begin
         cpl_user <= 'd0;
         cpl_user_search_pos <= 'd0;
      end else begin
         if (|cpl_valids[cpl_user_search_pos+:4] && (~cpl_tvalid | cpl_tready)) begin
            cpl_user <= cpl_user_search_pos + (cpl_valids[cpl_user_search_pos] ? 0 :
                                               cpl_valids[cpl_user_search_pos+1] ? 1 :
                                               cpl_valids[cpl_user_search_pos+2] ? 2 : 3);
         end else begin
            cpl_user_search_pos <= cpl_user_search_pos + 4;
         end
      end
   end
   assign cpl_tdata = cpl_data >> (96*cpl_user);
   assign cpl_tvalid = cpl_valids >> cpl_user;
   assign cpl_tuser = cpl_user;
   assign cpl_readys = {{CH_NUM-1{1'b0}}, cpl_tready} << cpl_tuser;

   reg [CTX_ID_BITS-1:0] consume_user;
   reg [CTX_ID_BITS-1:0] consume_user_search_pos;
   always @(posedge clk) begin
      if (~resetn) begin
         consume_user <= 'd0;
         consume_user_search_pos <= 'd0;
      end else begin
         if (|consume_valids[consume_user_search_pos+:4] && (~iconsume_tvalid | iconsume_tready)) begin
            consume_user <= consume_user_search_pos + (consume_valids[consume_user_search_pos] ? 0 :
                                               consume_valids[consume_user_search_pos+1] ? 1 :
                                               consume_valids[consume_user_search_pos+2] ? 2 : 3);
         end else begin
            consume_user_search_pos <= consume_user_search_pos + 4;
         end
      end
   end
   assign iconsume_tvalid = consume_valids >> consume_user;
   assign iconsume_tuser = consume_user;
   assign consume_readys = {{CH_NUM-1{1'b0}}, iconsume_tready} << consume_user;

   reg [DW-1:0] out_data;
   reg [KW-1:0] out_keep;
   reg [CTX_ID_BITS-1:0] out_user;
   reg                   out_valid;
   always @(posedge clk) begin
      if (~resetn) begin
         out_valid <= 1'b0;
      end else begin
         out_valid <= (i_tvalid & i_tready) | (out_valid & ~o_tready);
         out_data <= i_tvalid & i_tready ? i_tdata : out_data;
         out_keep <= i_tvalid & i_tready ? i_tkeep : out_keep;
         out_user <= i_tvalid & i_tready ? i_tuser : out_user;
      end
   end
   assign o_tdata = out_data;
   assign o_tkeep = out_keep;
   assign o_tuser = out_user;
   assign o_tlast = out_lasts >> out_user;
   assign o_tvalid = out_valid;

   assign i_tready = (~o_tvalid | o_tready) & (out_enables >> i_tuser);

endmodule

module test_route_controller_fast;
   tb_route_controller tb();
endmodule

module test_route_controller_random;
   tb_route_controller #(
       .SEED ( 12345 ),
       .ST_IN_BITS ( 1 ),
       .ST_OUT_BITS ( 1 ),
       .FRAME_HEADER_BITS ( 2 ),
       .FRAME_COMPLETE_BITS ( 2 ),
       .FRAME_CONSUME_BITS ( 2 ),
       .BUFFER_INFO_BITS ( 3 ),
       .FRAME_INFO_BITS ( 2 ),
       .OUT_REQ_BITS ( 2 ),
       .OUT_RSP_BITS ( 2 )
   ) tb ();
endmodule

module test_route_controller_random_slow_out;
   tb_route_controller #(
       .SEED ( 12345 ),
       .ST_IN_BITS ( 1 ),
       .ST_OUT_BITS ( 2 ),
       .FRAME_HEADER_BITS ( 2 ),
       .FRAME_COMPLETE_BITS ( 2 ),
       .FRAME_CONSUME_BITS ( 2 ),
       .BUFFER_INFO_BITS ( 3 ),
       .FRAME_INFO_BITS ( 2 ),
       .OUT_REQ_BITS ( 2 ),
       .OUT_RSP_BITS ( 2 )
   ) tb ();
endmodule

module test_route_controller_mmapped_fast;
   tb_route_controller #(
       .MMAPPED ( 1 )
   ) tb ();
endmodule
