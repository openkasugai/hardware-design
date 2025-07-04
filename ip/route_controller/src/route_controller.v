/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module route_controller #(
    parameter CTX_ID_BITS = 4,
    parameter ADDR_BITS = 16,
    parameter DW_LOG = 9,
    parameter TDEST_BITS = 4,
    parameter BURST_BITS = 4,
    parameter EXT_RELATION = 0,
    parameter CREDIT_MAX = 4,
    parameter ENABLE_MULTI_CONTROLLER = 0,
    parameter SELF_DEST = 0
    ) (
    // data stream input (from DMAC)
    input [(1<<DW_LOG)-1:0]      st_in_tdata,
    input [(1<<(DW_LOG-3))-1:0]  st_in_tkeep,
    input [CTX_ID_BITS-1:0]      st_in_tuser, // context id, extract tuser[12:8] (ch_id)
    input                        st_in_tlast, // convert from tuser[6] (eop)
    input                        st_in_eof,
    input                        st_in_tvalid,
    output                       st_in_tready,
    // data stream output (to DMAC)
    output [(1<<DW_LOG)-1:0]     st_out_tdata,
    output [(1<<(DW_LOG-3))-1:0] st_out_tkeep,
    output [CTX_ID_BITS-1:0]     st_out_tuser,
    output                       st_out_tlast, // end of frame
    output                       st_out_sop, // start of packet (optional for fdma2)
    output                       st_out_eop, // end of packet (optional for fdma2)
    output [BURST_BITS-1:0]      st_out_burst, // optional only for fdma2
    output [DW_LOG-4:0]          st_out_last_cnt, // optional for toe_ctrl
    output                       st_out_tvalid,
    input                        st_out_tready,
    // data stream input (from user)
    input [(1<<DW_LOG)-1:0]      user_st_in_tdata,
    input [(1<<(DW_LOG-3))-1:0]  user_st_in_tkeep,
    input [CTX_ID_BITS-1:0]      user_st_in_tuser,
    input                        user_st_in_tlast, // eof
    input                        user_st_in_tvalid,
    output                       user_st_in_tready,
    // data stream output (to user)
    output [(1<<DW_LOG)-1:0]     user_st_out_tdata,
    output [(1<<(DW_LOG-3))-1:0] user_st_out_tkeep,
    output [CTX_ID_BITS-1:0]     user_st_out_tuser,
    output [TDEST_BITS-1:0]      user_st_out_tdest,
    output                       user_st_out_tlast, // eop
    output                       user_st_out_tid, // eof
    output                       user_st_out_tvalid,
    input                        user_st_out_tready,
    // frame header output (to functions)
    output [127:0]               in_frame_header_tdata, // [63:0] frame addr, [95:64] frame size, [103:96] frame id, [104+:TDEST_BITS] dest
    output [CTX_ID_BITS-1:0]     in_frame_header_tuser,
    output [TDEST_BITS-1:0]      in_frame_header_tdest,
    output                       in_frame_header_tvalid,
    input                        in_frame_header_tready,
    // frame header output (to functions)
    output [127:0]               out_frame_header_tdata, // [63:0] frame addr, [95:64] frame size(max), [103:96] frame id, [104+:TDEST_BITS] dest
    output [CTX_ID_BITS-1:0]     out_frame_header_tuser,
    output [TDEST_BITS-1:0]      out_frame_header_tdest,
    output                       out_frame_header_tvalid,
    input                        out_frame_header_tready,
    // frame consume input (from functions)
    input [7:0]                  in_frame_consume_tdata, // frame id
    input [CTX_ID_BITS-1:0]      in_frame_consume_tuser,
    input                        in_frame_consume_tvalid,
    output                       in_frame_consume_tready,
    // incoming frame info (from DMAC)
    input [31:0]                 in_frame_info_tdata, // frame size
    input [CTX_ID_BITS-1:0]      in_frame_info_tuser, // context id
    input                        in_frame_info_tvalid,
    output                       in_frame_info_tready,
    // incoming frame ready (to DMAC)
    output [31:0]                in_frame_info_ready_tdata, // frame size
    output [CTX_ID_BITS-1:0]     in_frame_info_ready_tuser,
    output                       in_frame_info_ready_tvalid,
    input                        in_frame_info_ready_tready,
    // frame header consume (from function)
    input [CTX_ID_BITS-1:0]      in_frame_header_consume_tuser,
    input                        in_frame_header_consume_tvalid,
    output                       in_frame_header_consume_tready,
    // frame completion input (from functions (direct or via data mover)
    input [127:0]                out_frame_complete_tdata, // [63:0] frame addr, [95:64] frame size, [103:96] frame id, [104+:TDEST_BITS] dest
    input [CTX_ID_BITS-1:0]      out_frame_complete_tuser,
    input                        out_frame_complete_tvalid,
    output                       out_frame_complete_tready,
    // frame consume input (from AXI reader)
    input [7:0]                  out_frame_consume_tdata, // [7:0] frame id
    input [CTX_ID_BITS-1:0]      out_frame_consume_tuser,
    input                        out_frame_consume_tvalid,
    output                       out_frame_consume_tready,
    // incoming buffer info (from DMAC)
    input [31:0]                 out_buffer_info_tdata, // frame size
    input [CTX_ID_BITS-1:0]      out_buffer_info_tuser, // context id
    input                        out_buffer_info_tvalid,
    output                       out_buffer_info_tready,
    // outgoing frame ready (to DMAC)
    output [31:0]                out_frame_info_tdata, // frame size
    output [CTX_ID_BITS-1:0]     out_frame_info_tuser,
    output                       out_frame_info_tvalid,
    input                        out_frame_info_tready,
    // reg
    input [ADDR_BITS-1:0]        cfg_araddr,
    input                        cfg_arvalid,
    output                       cfg_arready,
    output [31:0]                cfg_rdata,
    output [1:0]                 cfg_rresp,
    output                       cfg_rvalid,
    input                        cfg_rready,
    input [ADDR_BITS-1:0]        cfg_awaddr,
    input                        cfg_awvalid,
    output                       cfg_awready,
    input [31:0]                 cfg_wdata,
    input                        cfg_wvalid,
    output                       cfg_wready,
    output [1:0]                 cfg_bresp,
    output                       cfg_bvalid,
    input                        cfg_bready,
    // outgoing frame request (to outgoing route controller)
    output [CTX_ID_BITS-1:0]     in_frame_out_req_tuser,
    output [TDEST_BITS-1:0]      in_frame_out_req_tdest,
    output                       in_frame_out_req_tvalid,
    input                        in_frame_out_req_tready,
    // outgoing frame ready (from outgoing route controller)
    input [CTX_ID_BITS-1:0]      in_frame_out_ready_tuser,
    input                        in_frame_out_ready_tvalid,
    output                       in_frame_out_ready_tready,
    // outgoin frame request (from incoming route controller)
    input [CTX_ID_BITS-1:0]      out_frame_out_req_tuser,
    input                        out_frame_out_req_tvalid,
    output                       out_frame_out_req_tready,
    // outgoing frame ready (to incoming route controller)
    output [CTX_ID_BITS-1:0]     out_frame_out_ready_tuser,
    output [TDEST_BITS-1:0]      out_frame_out_ready_tdest,
    output                       out_frame_out_ready_tvalid,
    input                        out_frame_out_ready_tready,
    // input frame completion out
    output [CTX_ID_BITS-1:0]     in_frame_completion_tuser, // ch
    output                       in_frame_completion_tvalid,
    // dbg
    output [CTX_ID_BITS-1:0]     dbg_frame_out_req_tuser,
    output                       dbg_frame_out_req_tvalid,
    output [CTX_ID_BITS-1:0]     dbg_frame_out_ready_tuser,
    output                       dbg_frame_out_ready_tvalid,
    // global
    input                        clk,
    input                        resetn
    );

   // outgoing frame request (to outgoing route controller)
   wire [CTX_ID_BITS-1:0]    w_in_frame_out_req_tuser;
   wire [TDEST_BITS-1:0]     w_in_frame_out_req_tdest;
   wire                      w_in_frame_out_req_tvalid;
   wire                      w_in_frame_out_req_tready;
   wire [CTX_ID_BITS-1:0]    w_in_frame_out_ready_tuser;
   wire                      w_in_frame_out_ready_tvalid;
   wire                      w_in_frame_out_ready_tready;
   // outgoing frame ready (from outgoing route controller)
   wire [CTX_ID_BITS-1:0]    w_out_frame_out_req_tuser;
   wire                      w_out_frame_out_req_tvalid;
   wire                      w_out_frame_out_req_tready;
   wire [CTX_ID_BITS-1:0]    w_out_frame_out_ready_tuser;
   wire [TDEST_BITS-1:0]     w_out_frame_out_ready_tdest;
   wire                      w_out_frame_out_ready_tvalid;
   wire                      w_out_frame_out_ready_tready;

   // reg separate
   wire [CTX_ID_BITS+4:0]    incoming_raddr;
   wire                      incoming_arvalid;
   wire [31:0]               incoming_rdata;
   wire                      incoming_rvalid;
   wire [CTX_ID_BITS+4:0]    incoming_waddr;
   wire [31:0]               incoming_wdata;
   wire                      incoming_wvalid;

   wire [CTX_ID_BITS+4:0]    outgoing_raddr;
   wire                      outgoing_arvalid;
   wire [31:0]               outgoing_rdata;
   wire                      outgoing_rvalid;
   wire [CTX_ID_BITS+4:0]    outgoing_waddr;
   wire [31:0]               outgoing_wdata;
   wire                      outgoing_wvalid;

   assign dbg_frame_out_req_tuser = w_in_frame_out_req_tuser;
   assign dbg_frame_out_reg_tvalid = w_in_frame_out_req_tvalid & w_in_frame_out_req_tready;
   assign dbg_frame_out_ready_tuser = w_out_frame_out_ready_tuser;
   assign dbg_frame_out_ready_tvalid = w_out_frame_out_ready_tvalid & w_out_frame_out_ready_tready;

   route_control_reg_switch #(
       .ADDR_BITS ( ADDR_BITS ),
       .CTX_ID_BITS ( CTX_ID_BITS )
   ) reg_switch (
       .cfg_araddr ( cfg_araddr ),
       .cfg_arvalid ( cfg_arvalid ),
       .cfg_arready ( cfg_arready ),
       .cfg_rdata ( cfg_rdata ),
       .cfg_rresp ( cfg_rresp ),
       .cfg_rvalid ( cfg_rvalid ),
       .cfg_rready ( cfg_rready ),
       .cfg_awaddr ( cfg_awaddr ),
       .cfg_awvalid ( cfg_awvalid ),
       .cfg_awready ( cfg_awready ),
       .cfg_wdata ( cfg_wdata ),
       .cfg_wvalid ( cfg_wvalid ),
       .cfg_wready ( cfg_wready ),
       .cfg_bresp ( cfg_bresp ),
       .cfg_bvalid ( cfg_bvalid ),
       .cfg_bready ( cfg_bready ),
       .incoming_raddr ( incoming_raddr ),
       .incoming_arvalid ( incoming_arvalid ),
       .incoming_rdata ( incoming_rdata ),
       .incoming_rvalid ( incoming_rvalid ),
       .incoming_waddr ( incoming_waddr ),
       .incoming_wdata ( incoming_wdata ),
       .incoming_wvalid ( incoming_wvalid ),
       .outgoing_raddr ( outgoing_raddr ),
       .outgoing_arvalid ( outgoing_arvalid ),
       .outgoing_rdata ( outgoing_rdata ),
       .outgoing_rvalid ( outgoing_rvalid ),
       .outgoing_waddr ( outgoing_waddr ),
       .outgoing_wdata ( outgoing_wdata ),
       .outgoing_wvalid ( outgoing_wvalid ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   incoming_route_controller #(
       .DW_LOG ( DW_LOG ),
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .TDEST_BITS ( TDEST_BITS ),
       .EXT_RELATION ( EXT_RELATION ),
       .CREDIT_MAX ( CREDIT_MAX ),
       .SELF_DEST ( SELF_DEST )
   ) incoming_route_ctrl (
       .st_in_tdata ( st_in_tdata ),
       .st_in_tkeep ( st_in_tkeep ),
       .st_in_tuser ( st_in_tuser ),
       .st_in_tlast ( st_in_tlast ),
       .st_in_eof ( st_in_eof ),
       .st_in_tvalid ( st_in_tvalid ),
       .st_in_tready ( st_in_tready ),
       .st_out_tdata ( user_st_out_tdata ),
       .st_out_tkeep ( user_st_out_tkeep ),
       .st_out_tuser ( user_st_out_tuser ),
       .st_out_tdest ( user_st_out_tdest ),
       .st_out_tlast ( user_st_out_tlast ),
       .st_out_tid ( user_st_out_tid ),
       .st_out_tvalid ( user_st_out_tvalid ),
       .st_out_tready ( user_st_out_tready ),
       .frame_header_tdata ( in_frame_header_tdata ),
       .frame_header_tuser ( in_frame_header_tuser ),
       .frame_header_tdest ( in_frame_header_tdest ),
       .frame_header_tvalid ( in_frame_header_tvalid ),
       .frame_header_tready ( in_frame_header_tready ),
       .frame_header_consume_tuser ( in_frame_header_consume_tuser ),
       .frame_header_consume_tvalid ( in_frame_header_consume_tvalid ),
       .frame_header_consume_tready ( in_frame_header_consume_tready ),
       .frame_consume_tdata ( in_frame_consume_tdata ),
       .frame_consume_tuser ( in_frame_consume_tuser ),
       .frame_consume_tvalid ( in_frame_consume_tvalid ),
       .frame_consume_tready ( in_frame_consume_tready ),
       .frame_info_tdata ( in_frame_info_tdata ),
       .frame_info_tuser ( in_frame_info_tuser ),
       .frame_info_tvalid ( in_frame_info_tvalid ),
       .frame_info_tready ( in_frame_info_tready ),
       .frame_in_ready_tdata ( in_frame_info_ready_tdata ),
       .frame_in_ready_tuser ( in_frame_info_ready_tuser ),
       .frame_in_ready_tvalid ( in_frame_info_ready_tvalid ),
       .frame_in_ready_tready ( in_frame_info_ready_tready ),
       .frame_out_req_tuser ( w_in_frame_out_req_tuser ),
       .frame_out_req_tdest ( w_in_frame_out_req_tdest ),
       .frame_out_req_tvalid ( w_in_frame_out_req_tvalid ),
       .frame_out_req_tready ( w_in_frame_out_req_tready ),
       .frame_out_ready_tuser ( w_in_frame_out_ready_tuser ),
       .frame_out_ready_tvalid ( w_in_frame_out_ready_tvalid ),
       .frame_out_ready_tready ( w_in_frame_out_ready_tready ),
       .frame_completion_tuser ( in_frame_completion_tuser ),
       .frame_completion_tvalid ( in_frame_completion_tvalid ),
       .cfg_raddr ( incoming_raddr ),
       .cfg_arvalid ( incoming_arvalid ),
       .cfg_rdata ( incoming_rdata ),
       .cfg_rvalid ( incoming_rvalid ),
       .cfg_waddr ( incoming_waddr ),
       .cfg_wdata ( incoming_wdata ),
       .cfg_wvalid ( incoming_wvalid ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   outgoing_route_controller #(
       .DW_LOG ( DW_LOG ),
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .TDEST_BITS ( TDEST_BITS ),
       .BURST_BITS ( BURST_BITS ),
       .EXT_RELATION ( EXT_RELATION ),
       .CREDIT_MAX ( CREDIT_MAX ),
       .SELF_DEST ( SELF_DEST )
   ) outgoing_route_ctrl (
       .st_in_tdata ( user_st_in_tdata ),
       .st_in_tkeep ( user_st_in_tkeep ),
       .st_in_tuser ( user_st_in_tuser ),
       .st_in_tlast ( user_st_in_tlast ),
       .st_in_tvalid ( user_st_in_tvalid ),
       .st_in_tready ( user_st_in_tready ),
       .st_out_tdata ( st_out_tdata ),
       .st_out_tkeep ( st_out_tkeep ),
       .st_out_tuser ( st_out_tuser ),
       .st_out_tlast ( st_out_tlast ),
       .st_out_sop ( st_out_sop ),
       .st_out_eop ( st_out_eop ),
       .st_out_burst ( st_out_burst ),
       .st_out_last_cnt ( st_out_last_cnt ),
       .st_out_tvalid ( st_out_tvalid ),
       .st_out_tready ( st_out_tready ),
       .frame_header_tdata ( out_frame_header_tdata ),
       .frame_header_tuser ( out_frame_header_tuser ),
       .frame_header_tdest ( out_frame_header_tdest ),
       .frame_header_tvalid ( out_frame_header_tvalid ),
       .frame_header_tready ( out_frame_header_tready ),
       .frame_complete_tdata ( out_frame_complete_tdata ),
       .frame_complete_tuser ( out_frame_complete_tuser ),
       .frame_complete_tvalid ( out_frame_complete_tvalid ),
       .frame_complete_tready ( out_frame_complete_tready ),
       .frame_consume_tdata ( out_frame_consume_tdata ),
       .frame_consume_tuser ( out_frame_consume_tuser ),
       .frame_consume_tvalid ( out_frame_consume_tvalid ),
       .frame_consume_tready ( out_frame_consume_tready ),
       .buffer_info_tdata ( out_buffer_info_tdata ),
       .buffer_info_tuser ( out_buffer_info_tuser ),
       .buffer_info_tvalid ( out_buffer_info_tvalid ),
       .buffer_info_tready ( out_buffer_info_tready ),
       .frame_info_tdata ( out_frame_info_tdata ),
       .frame_info_tuser ( out_frame_info_tuser ),
       .frame_info_tvalid ( out_frame_info_tvalid ),
       .frame_info_tready ( out_frame_info_tready ),
       .frame_out_req_tuser ( w_out_frame_out_req_tuser ),
       .frame_out_req_tvalid ( w_out_frame_out_req_tvalid ),
       .frame_out_req_tready ( w_out_frame_out_req_tready ),
       .frame_out_ready_tuser ( w_out_frame_out_ready_tuser ),
       .frame_out_ready_tdest ( w_out_frame_out_ready_tdest ),
       .frame_out_ready_tvalid ( w_out_frame_out_ready_tvalid ),
       .frame_out_ready_tready ( w_out_frame_out_ready_tready ),
       .cfg_raddr ( outgoing_raddr ),
       .cfg_arvalid ( outgoing_arvalid ),
       .cfg_rdata ( outgoing_rdata ),
       .cfg_rvalid ( outgoing_rvalid ),
       .cfg_waddr ( outgoing_waddr ),
       .cfg_wdata ( outgoing_wdata ),
       .cfg_wvalid ( outgoing_wvalid ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   generate
      if (ENABLE_MULTI_CONTROLLER) begin
         assign in_frame_out_req_tuser = w_in_frame_out_req_tuser;
         assign in_frame_out_req_tdest = w_in_frame_out_req_tdest;
         assign in_frame_out_req_tvalid = w_in_frame_out_req_tvalid;
         assign w_in_frame_out_req_tready = in_frame_out_req_tready;
         assign w_in_frame_out_ready_tuser = in_frame_out_ready_tuser;
         assign w_in_frame_out_ready_tvalid = in_frame_out_ready_tvalid;
         assign in_frame_out_ready_tready = w_in_frame_out_ready_tready;
         assign w_out_frame_out_req_tuser = out_frame_out_req_tuser;
         assign w_out_frame_out_req_tvalid = out_frame_out_req_tvalid;
         assign out_frame_out_req_tready = w_out_frame_out_req_tready;
         assign out_frame_out_ready_tuser = w_out_frame_out_ready_tuser;
         assign out_frame_out_ready_tdest = w_out_frame_out_ready_tdest;
         assign out_frame_out_ready_tvalid = w_out_frame_out_ready_tvalid;
         assign w_out_frame_out_ready_tready = out_frame_out_ready_tready;
      end else begin
         assign in_frame_out_req_tvalid = 1'b0;
         assign in_frame_out_ready_tready = 1'b1;
         assign out_frame_out_req_tready = 1'b1;
         assign out_frame_out_ready_tvalid = 1'b0;
         assign w_out_frame_out_req_tuser = w_in_frame_out_req_tuser;
         assign w_out_frame_out_req_tvalid = w_in_frame_out_req_tvalid;
         assign w_in_frame_out_req_tready = w_out_frame_out_req_tready;
         assign w_in_frame_out_ready_tuser = w_out_frame_out_ready_tuser;
         assign w_in_frame_out_ready_tvalid = w_out_frame_out_ready_tvalid;
         assign w_out_frame_out_ready_tready = w_in_frame_out_ready_tready;
      end
   endgenerate

endmodule
