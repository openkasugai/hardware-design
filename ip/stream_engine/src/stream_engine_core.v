/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module stream_engine_core #(
    parameter [15:0] REG_BASE = 16'h4000,
    parameter        RQ_DW = 384,
    parameter        RQ_DK = 12,
    parameter        RC_DW = 352,
    parameter        RC_DK = 11,
    parameter        DESC_RQ_DW = 512,
    parameter        DESC_RQ_DK = 16,
    parameter        DESC_RC_DW = 512,
    parameter        DESC_RC_DK = 16,
    parameter        DESC_LEN = 512,
    parameter        DISABLE_FRAME_INFO = 0,
    parameter        ENABLE_FRAME_INFO_OUT = 0,
    parameter        IGNORE_CPL_SIZE = 0,
    parameter        FRAME_INFO_FIFO_DL = 5,
    parameter        DESC_BASE_FIFO_DL = 2,
    parameter        VP_MAP_NUM_LOG = 5,
    parameter        CH_BASE = 0,
    parameter        CH_NUM_LOG = 3,
    parameter        QEW_LOG = 5,
    parameter        QEW = 1 << QEW_LOG,
    parameter        ENABLE_QUEUE = 0,
    parameter [39:0] D2D_AXI_BASE = 40'h0,
    parameter [31:0] D2D_AXI_RANGE = 32'h4000_0000, // 1GB
    parameter        QUEUE_DL = 3,
    parameter        QESIZE_POS = 64,
    parameter        QUEUE_CHECK_TAG = 99,
    parameter        QUEUE_READ_TAG = 98,
    parameter        RQBASE = 128,
    parameter        RCBASE = 96,
    parameter        USE_ULTRA_RAM_VPMAP = 1
    ) (
    input [15:0]                    reg_araddr,
    input                           reg_arvalid,
    output                          reg_arready,
    output [31:0]                   reg_rdata,
    output [1:0]                    reg_rresp,
    output                          reg_rvalid,
    input                           reg_rready,
    input [15:0]                    reg_awaddr,
    input                           reg_awvalid,
    output                          reg_awready,
    input [31:0]                    reg_wdata,
    input                           reg_wvalid,
    output                          reg_wready,
    output [1:0]                    reg_bresp,
    output                          reg_bvalid,
    input                           reg_bready,

    input [31:0]                    frame_info_size,
    input [CH_NUM_LOG-1:0]          frame_info_ch,
    input                           frame_info_valid,
    output                          frame_info_ready,

    output [31:0]                   frame_info_out_size,
    output [CH_NUM_LOG-1:0]         frame_info_out_ch,
    output                          frame_info_out_valid,
    input                           frame_info_out_ready,

    // read descriptor / clear descriptor input
    input [DESC_RQ_DW-1:0]          desc_req_data,
    input [DESC_RQ_DK-1:0]          desc_req_keep,
    input                           desc_req_valid,
    output                          desc_req_ready,
`ifdef OLD_IMPL
    input [DESC_RQ_DW-1:0]          desc_cpl_data,
    input [DESC_RQ_DK-1:0]          desc_cpl_keep,
    input                           desc_cpl_last,
    input                           desc_cpl_valid,
    output                          desc_cpl_ready,
`else
    input [31:0]                    desc_cpl_data,
    input [CH_NUM_LOG-1:0]          desc_cpl_ch,
    input                           desc_cpl_valid,
    output                          desc_cpl_ready,
`endif
    // read/write counterpart queue
    output [RQ_DW-1:0]              queue_check_data,
    output [RQ_DK-1:0]              queue_check_keep,
    output                          queue_check_valid,
    input                           queue_check_ready,
    output [RQ_DW-1:0]              queue_update_data,
    output [RQ_DK-1:0]              queue_update_keep,
    output                          queue_update_valid,
    input                           queue_update_ready,
    output [RQ_DW-1:0]              queue_rd_data,
    output [RQ_DK-1:0]              queue_rd_keep,
    output                          queue_rd_valid,
    input                           queue_rd_ready,
    output [RQ_DW-1:0]              queue_wr_data,
    output [RQ_DK-1:0]              queue_wr_keep,
    output                          queue_wr_valid,
    input                           queue_wr_ready,
    // read/write counterpart queue
    input [RC_DW-1:0]               queue_check_res_data,
    input                           queue_check_res_valid,
    input [RC_DW-1:0]               queue_rd_res_data,
    input                           queue_rd_res_valid,
    // enqueued descriptor output
    output [DESC_RC_DW-1:0]         desc_out_data,
    output [DESC_RC_DK-1:0]         desc_out_keep,
    output                          desc_out_last,
    output                          desc_out_valid,
    input                           desc_out_ready,

    output [(1<<CH_NUM_LOG)*64-1:0] stream_cpl_q_bases,
    output [(1<<CH_NUM_LOG)-1:0]    stream_ch_valids,
    output [(1<<CH_NUM_LOG)-1:0]    stream_ch_d2d_valids,
    output [(64<<CH_NUM_LOG)-1:0]   stream_doorbell_addrs,
    output [(1<<CH_NUM_LOG)-1:0]    stream_ch_interrupt_enables,

    input [CH_NUM_LOG-1:0]          stream_cpl_update_ch, // tail update
    input                           stream_cpl_update,
    input [CH_NUM_LOG-1:0]          stream_queue_read_ch,
    input [QUEUE_DL-1:0]            stream_queue_read_entry,
    input                           stream_queue_read_valid,
    output [((1<<QEW_LOG)<<3)-1:0]  stream_queue_read_data,
    output                          stream_queue_read_data_valid,

    output [(1<<CH_NUM_LOG)-1:0]    head_tail_updates,

    input [31:0]                    i_rc_icount,
    input [31:0]                    i_rc_count,

    input                           clk,
    input                           resetn
    );

    localparam CH_NUM = 1 << CH_NUM_LOG;
    localparam VP_MAP_NUM = 1 << VP_MAP_NUM_LOG;
    localparam QEWB_LOG = QEW_LOG + 3;
    localparam QEWB = QEW << 3;
    localparam QUEUE_DEPTH = 1 << QUEUE_DL;

    // registers
    wire [VP_MAP_NUM_LOG+CH_NUM_LOG-1:0] vpmap_conv_addr;
    wire [64+64+32:0]                    vpmap_conv_rdata;

    wire [CH_NUM-1:0]          initialized_queues;
    wire [CH_NUM-1:0]          stream_ch_pendings;
    wire [CH_NUM*64-1:0]       stream_req_q_bases;
    //wire [CH_NUM*64-1:0]       stream_cpl_q_bases;
    wire [CH_NUM*8-1:0]        stream_req_q_depth;
    wire [CH_NUM*8-1:0]        stream_cpl_q_depth;
    wire [CH_NUM*64-1:0]       stream_req_q_head_tails;
    wire [CH_NUM*64-1:0]       stream_cpl_q_head_tails;

    wire [15:0]                stream_check_interval;
    wire [CH_NUM_LOG:0]        stream_ch_valid_num;
    wire [CH_NUM_LOG:0]        stream_ch_doorbell_num;

    wire [3:0]                 ctrl_reg_waddr;
    wire [31:0]                ctrl_reg_wdata;
    wire [CH_NUM_LOG-1:0]      ctrl_reg_wch;
    wire                       ctrl_reg_wen;

    wire [CH_NUM-1:0]          desc_issues;
    wire [CH_NUM-1:0]          desc_completes;

    wire [CH_NUM-1:0]          transfer_valids;
    wire [CH_NUM-1:0]          transfer_issue_ends;
    wire [CH_NUM-1:0]          transfer_ends;
    wire [CH_NUM-1:0]          transfer_cpl_ch_cand;

    wire [8*CH_NUM-1:0]         req_q_head;
    wire [8*CH_NUM-1:0]         req_q_read_pos;
    wire [8*CH_NUM-1:0]         req_q_tail;
    wire [8*CH_NUM-1:0]         cpl_q_head;
    wire [8*CH_NUM-1:0]         cpl_q_head_inflight;
    wire [8*CH_NUM-1:0]         cpl_q_tail;
    wire [8*CH_NUM-1:0]         cpl_counts;
    wire [8*CH_NUM-1:0]         cpl_counts2;

    wire [CH_NUM_LOG-1:0]       stream_check_ch;
    wire                        stream_check_done;
    wire [CH_NUM-1:0]           stream_check_requests;
    wire [CH_NUM-1:0]           stream_ch_check_with_doorbells;

    wire [CH_NUM_LOG-1:0]       stream_req_update_ch; // head update
    wire [31:0]                 stream_req_update_size;
    wire                        stream_req_update;

    // D2D RX queue head/tail
    wire [8*CH_NUM-1:0]          stream_req_q_heads;
    wire [8*CH_NUM-1:0]          stream_req_q_tails;
    wire [8*CH_NUM-1:0]          stream_cpl_q_heads;
    wire [8*CH_NUM-1:0]          stream_cpl_q_tails;

    stream_engine_regs #(
        .REG_BASE ( REG_BASE ),
        .VP_MAP_NUM_LOG ( VP_MAP_NUM_LOG ),
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .QEW_LOG ( QEW_LOG ),
        .ENABLE_QUEUE ( ENABLE_QUEUE ),
        .D2D_AXI_BASE ( D2D_AXI_BASE ),
        .D2D_AXI_RANGE ( D2D_AXI_RANGE ),
        .QUEUE_DL ( QUEUE_DL ),
        .USE_ULTRA_RAM_VPMAP ( USE_ULTRA_RAM_VPMAP )
    ) regs (
        .reg_araddr ( reg_araddr ),
        .reg_arvalid ( reg_arvalid ),
        .reg_arready ( reg_arready ),
        .reg_rdata ( reg_rdata ),
        .reg_rresp ( reg_rresp ),
        .reg_rvalid ( reg_rvalid ),
        .reg_rready ( reg_rready ),
        .reg_awaddr ( reg_awaddr ),
        .reg_awvalid ( reg_awvalid ),
        .reg_awready ( reg_awready ),
        .reg_wdata ( reg_wdata ),
        .reg_wvalid ( reg_wvalid ),
        .reg_wready ( reg_wready ),
        .reg_bresp ( reg_bresp ),
        .reg_bvalid ( reg_bvalid ),
        .reg_bready ( reg_bready ),
        .vpmap_conv_addr ( vpmap_conv_addr ),
        .vpmap_conv_rdata ( vpmap_conv_rdata ),
        .stream_ch_valids ( stream_ch_valids ),
        .stream_ch_initialized ( initialized_queues ),
        .stream_ch_pendings ( stream_ch_pendings ),
        .stream_req_q_bases ( stream_req_q_bases ),
        .stream_cpl_q_bases ( stream_cpl_q_bases ),
        .stream_req_q_depth ( stream_req_q_depth ),
        .stream_cpl_q_depth ( stream_cpl_q_depth ),
        .stream_req_q_head_tails ( stream_req_q_head_tails ),
        .stream_cpl_q_head_tails ( stream_cpl_q_head_tails ),
        .stream_check_ch ( stream_check_ch ),
        .stream_check_done ( stream_check_done ),
        .stream_doorbell_addrs ( stream_doorbell_addrs ),
        .stream_check_requests ( stream_check_requests ),
        .stream_ch_check_with_doorbells ( stream_ch_check_with_doorbells ),
        .stream_ch_interrupt_enables ( stream_ch_interrupt_enables ),
        .stream_ch_d2d_valids ( stream_ch_d2d_valids ),
        .stream_check_interval ( stream_check_interval ),
        .stream_ch_valid_num ( stream_ch_valid_num ),
        .stream_ch_doorbell_num ( stream_ch_doorbell_num ),
        .stream_req_update_ch ( stream_req_update_ch ),
        .stream_req_update_size ( stream_req_update_size ),
        .stream_req_update ( stream_req_update ),
        .stream_cpl_update_ch ( stream_cpl_update_ch ),
        .stream_cpl_update ( stream_cpl_update ),
        .stream_queue_read_ch ( stream_queue_read_ch ),
        .stream_queue_read_entry ( stream_queue_read_entry ),
        .stream_queue_read_valid ( stream_queue_read_valid ),
        .stream_queue_read_data ( stream_queue_read_data ),
        .stream_queue_read_data_valid ( stream_queue_read_data_valid ),
        .stream_req_q_heads ( stream_req_q_heads ),
        .stream_req_q_tails ( stream_req_q_tails ),
        .stream_cpl_q_heads ( stream_cpl_q_heads ),
        .stream_cpl_q_tails ( stream_cpl_q_tails ),
        .ctrl_reg_wen ( ctrl_reg_wen ),
        .ctrl_reg_wch ( ctrl_reg_wch ),
        .ctrl_reg_waddr ( ctrl_reg_waddr ),
        .ctrl_reg_wdata ( ctrl_reg_wdata ),
        .head_tail_updates ( head_tail_updates ),
        .i_rc_icount ( i_rc_icount ),
        .i_rc_count ( i_rc_count ),
        .desc_issues ( desc_issues ),
        .desc_completes ( desc_completes ),
        .req_q_head ( req_q_head ),
        .req_q_read_pos ( req_q_read_pos ),
        .req_q_tail ( req_q_tail ),
        .cpl_q_head ( cpl_q_head ),
        .cpl_q_head_inflight ( cpl_q_head_inflight ),
        .cpl_q_tail ( cpl_q_tail ),
        .cpl_counts ( cpl_counts ),
        .cpl_counts2 ( cpl_counts2 ),
        .dbg_transfer_valids ( transfer_valids ),
        .dbg_transfer_issue_ends ( transfer_issue_ends ),
        .dbg_transfer_ends ( transfer_ends ),
        .transfer_cpl_ch_cand ( transfer_cpl_ch_cand ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    // queue control
    wire [CH_NUM*64-1:0]  req_q_head_addrs;
    wire [CH_NUM*64-1:0]  cpl_q_head_addrs;

    wire [CH_NUM-1:0]     req_q_valids;
    wire [CH_NUM-1:0]     cpl_q_vacants;

    wire [CH_NUM_LOG-1:0] request_head_update_ch;
    wire                  request_head_update_ch_valid;

    wire [CH_NUM_LOG-1:0] transfer_cpl_ch;
    wire                  transfer_cpl_ch_valid;
    wire                  transfer_cpl_ch_done;

    wire [CH_NUM-1:0]     queue_errors = 'd0;

    stream_engine_queue_head_tail #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .ENABLE_QUEUE ( ENABLE_QUEUE ),
        .RQ_DW ( RQ_DW ),
        .RQ_DK ( RQ_DK ),
        .RC_DW ( RC_DW ),
        .QEW_LOG ( QEW_LOG ),
        .RCBASE ( RCBASE ),
        .QUEUE_CHECK_TAG ( QUEUE_CHECK_TAG )
    ) head_tail (
        .ctrl_reg_wen ( ctrl_reg_wen ),
        .ctrl_reg_wch ( ctrl_reg_wch ),
        .ctrl_reg_waddr ( ctrl_reg_waddr ),
        .ctrl_reg_wdata ( ctrl_reg_wdata ),
        .stream_ch_valids ( stream_ch_valids ),
        .stream_ch_d2d_valids ( stream_ch_d2d_valids ),
        .stream_req_q_bases ( stream_req_q_bases ),
        .stream_cpl_q_bases ( stream_cpl_q_bases ),
        .stream_req_q_depth ( stream_req_q_depth ),
        .stream_cpl_q_depth ( stream_cpl_q_depth ),
        .stream_req_q_head_tails ( stream_req_q_head_tails ),
        .stream_cpl_q_head_tails ( stream_cpl_q_head_tails ),
        .stream_check_interval ( stream_check_interval ),
        .stream_ch_valid_num ( stream_ch_valid_num ),
        .stream_ch_doorbell_num ( stream_ch_doorbell_num ),
        .queue_check_res_data ( queue_check_res_data ),
        .queue_check_res_valid ( queue_check_res_valid ),
        .queue_check_data ( queue_check_data ),
        .queue_check_keep ( queue_check_keep ),
        .queue_check_valid ( queue_check_valid ),
        .queue_check_ready ( queue_check_ready ),
        .queue_update_data ( queue_update_data ),
        .queue_update_keep ( queue_update_keep ),
        .queue_update_valid ( queue_update_valid ),
        .queue_update_ready ( queue_update_ready ),
        .request_head_update_ch ( request_head_update_ch ),
        .request_head_update_ch_valid ( request_head_update_ch_valid ),
        .transfer_cpl_ch ( transfer_cpl_ch ),
        .transfer_cpl_ch_valid ( transfer_cpl_ch_valid ),
        .transfer_cpl_ch_done ( transfer_cpl_ch_done ),
        .queue_errors ( queue_errors ),
        .initialized_queues ( initialized_queues ),
        .req_q_valids ( req_q_valids ),
        .cpl_q_vacants ( cpl_q_vacants ),
        .req_q_head_addrs ( req_q_head_addrs ),
        .cpl_q_head_addrs ( cpl_q_head_addrs ),
        .stream_check_requests ( stream_check_requests ),
        .stream_ch_check_with_doorbells ( stream_ch_check_with_doorbells ),
        .stream_check_ch ( stream_check_ch ),
        .stream_check_done ( stream_check_done ),
        .dbg_req_q_head ( req_q_head ),
        .dbg_req_q_read_pos ( req_q_read_pos ),
        .dbg_req_q_tail ( req_q_tail ),
        .dbg_cpl_q_head ( cpl_q_head ),
        .dbg_cpl_q_head_inflight ( cpl_q_head_inflight ),
        .dbg_cpl_q_tail ( cpl_q_tail ),
        .dbg_cpl_counts ( cpl_counts ),
        .dbg_cpl_counts2 ( cpl_counts2 ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    // update queue element
    wire [63:0]            updated_request_vaddr;
    wire [31:0]            updated_request_size;
    wire                   updated_request_valid;
    wire [CH_NUM_LOG-1:0]  updated_request_ch;

    wire [QEWB*CH_NUM-1:0] requests;
    wire [CH_NUM-1:0]      request_valids;
    wire [CH_NUM-1:0]      request_firsts;

    stream_engine_queue_element #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .QEW ( QEW ),
        .QEW_LOG ( QEW_LOG ),
        .RQ_DW ( RQ_DW ),
        .RQ_DK ( RQ_DK ),
        .RC_DW ( RC_DW ),
        .RCBASE ( RCBASE ),
        .ENABLE_QUEUE ( ENABLE_QUEUE ),
        .D2D_AXI_RANGE ( D2D_AXI_RANGE ),
        .QUEUE_DEPTH ( QUEUE_DEPTH ),
        .QUEUE_READ_TAG ( QUEUE_READ_TAG ),
        .QESIZE_POS ( QESIZE_POS ),
        .ENABLE_FRAME_INFO_OUT ( ENABLE_FRAME_INFO_OUT )
    ) queue_element (
        .stream_ch_valids ( stream_ch_valids ),
        .stream_ch_d2d_valids ( stream_ch_d2d_valids ),
        .stream_req_q_heads ( stream_req_q_heads ),
        .stream_req_q_tails ( stream_req_q_tails ),
        .initialized_queues ( initialized_queues ),
        .req_q_valids ( req_q_valids ),
        .cpl_q_vacants ( cpl_q_vacants ),
        .req_q_addrs ( req_q_head_addrs ),
        .queue_rd_data ( queue_rd_data ),
        .queue_rd_keep ( queue_rd_keep ),
        .queue_rd_valid ( queue_rd_valid ),
        .queue_rd_ready ( queue_rd_ready ),
        .queue_rd_res_data ( queue_rd_res_data ),
        .queue_rd_res_valid ( queue_rd_res_valid ),
        .request_head_update_ch ( request_head_update_ch ),
        .request_head_update_ch_valid ( request_head_update_ch_valid ),
        .requests ( requests ),
        .request_valids ( request_valids ),
        .request_firsts ( request_firsts ),
        .updated_request_vaddr ( updated_request_vaddr ),
        .updated_request_size ( updated_request_size ),
        .updated_request_valid ( updated_request_valid ),
        .updated_request_ch ( updated_request_ch ),
        .frame_info_size ( frame_info_out_size ),
        .frame_info_ch ( frame_info_out_ch ),
        .frame_info_valid ( frame_info_out_valid ),
        .frame_info_ready ( frame_info_out_ready ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    // descriptor
    wire [63:0]               request_base_vaddr;
    wire [31:0]               request_base_size;
    wire [CH_NUM_LOG-1:0]     request_base_ch;
    wire                      request_base_final;
    wire                      request_base_valid;
    wire                      request_base_ready;

    wire [31:0]            tx_size;
    wire [CH_NUM_LOG-1:0]  tx_ch;
    wire                   tx_valid;
    wire                   tx_ready;

    stream_engine_descriptor #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .QEW ( QEW ),
        .QEW_LOG ( QEW_LOG ),
        .VP_MAP_NUM_LOG ( VP_MAP_NUM_LOG ),
        .DESC_RQ_DW ( DESC_RQ_DW ),
        .DESC_RQ_DK ( DESC_RQ_DK ),
        .DESC_RC_DW ( DESC_RC_DW ),
        .DESC_RC_DK ( DESC_RC_DK ),
        .DESC_LEN ( DESC_LEN ),
        .RCBASE ( RCBASE ),
        .DISABLE_FRAME_INFO ( DISABLE_FRAME_INFO ),
        .ENABLE_QUEUE ( ENABLE_QUEUE ),
        .CH_BASE ( CH_BASE )
    ) desc (
        .stream_ch_valids ( stream_ch_valids ),
        .stream_ch_d2d_valids ( stream_ch_d2d_valids ),
        .tx_size ( tx_size ),
        .tx_ch ( tx_ch ),
        .tx_valid ( tx_valid ),
        .tx_ready ( tx_ready ),
        .stream_req_update_ch ( stream_req_update_ch ),
        .stream_req_update_size ( stream_req_update_size ),
        .stream_req_update ( stream_req_update ),
        .requests ( requests ),
        .request_valids ( request_valids ),
        .request_firsts ( request_firsts ),
        .desc_req_data ( desc_req_data ),
        .desc_req_keep ( desc_req_keep ),
        .desc_req_valid ( desc_req_valid ),
        .desc_req_ready ( desc_req_ready ),
        .desc_out_data ( desc_out_data ),
        .desc_out_keep ( desc_out_keep ),
        .desc_out_last ( desc_out_last ),
        .desc_out_valid ( desc_out_valid ),
        .desc_out_ready ( desc_out_ready ),
        .updated_request_vaddr ( updated_request_vaddr ),
        .updated_request_size ( updated_request_size ),
        .updated_request_valid ( updated_request_valid ),
        .updated_request_ch ( updated_request_ch ),
        .request_base_vaddr ( request_base_vaddr ),
        .request_base_size ( request_base_size ),
        .request_base_ch ( request_base_ch ),
        .request_base_final ( request_base_final ),
        .request_base_valid ( request_base_valid ),
        .request_base_ready ( request_base_ready ),
        .vpmap_conv_addr ( vpmap_conv_addr ),
        .vpmap_conv_rdata ( vpmap_conv_rdata ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    assign desc_issues = {{CH_NUM-1{1'b0}}, desc_out_valid & desc_out_ready & ~desc_out_last & desc_out_data[RCBASE+16]} << desc_out_data[64+:CH_NUM_LOG];

    // frame info fifo
    fifo #(
        .DW ( 32 + CH_NUM_LOG ),
        .DL ( FRAME_INFO_FIFO_DL )
    ) frame_info_fifo (
        .idata ( {frame_info_ch, frame_info_size} ),
        .ivalid ( frame_info_valid ),
        .iready ( frame_info_ready ),
        .odata ( {tx_ch, tx_size} ),
        .ovalid ( tx_valid ),
        .oready ( tx_ready ),
        .full (  ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    // desc base fifo
    wire [64*CH_NUM-1:0]   desc_base_o_vaddr;
    wire [32*CH_NUM-1:0]   desc_base_o_size;
    wire [CH_NUM-1:0]      desc_base_o_final;
    wire [CH_NUM-1:0]      desc_base_o_valid;
    wire [CH_NUM-1:0]      desc_base_o_ready;
    wire [(64+32+1)*CH_NUM-1:0] desc_base_o_data;
    generate
        for (genvar i=0; i<CH_NUM; i=i+1) begin
            assign {desc_base_o_final[i], desc_base_o_size[i*32+:32], desc_base_o_vaddr[i*64+:64]} = desc_base_o_data[i*(64+32+1)+:(64+32+1)];
        end
    endgenerate

    ch_separate_fifo #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .DW ( 64 + 32 + 1 ),
        .DL ( DESC_BASE_FIFO_DL )
    ) desc_base_fifo (
        .idata ( {request_base_final, request_base_size, request_base_vaddr} ),
        .ich ( request_base_ch ),
        .ivalid ( request_base_valid ),
        .iready ( request_base_ready ),
        .odata ( desc_base_o_data ),
        .ovalid ( desc_base_o_valid ),
        .oready ( desc_base_o_ready ),
        .full (  ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    // desc cpl
    wire [CH_NUM_LOG-1:0]  desc_req_ch;
    wire                   desc_req_ch_valid;

    stream_engine_transfer_cpl #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .QEW ( QEW ),
        .QEW_LOG ( QEW_LOG ),
        .DESC_RQ_DW ( DESC_RQ_DW ),
        .DESC_RQ_DK ( DESC_RQ_DK ),
        .DESC_LEN ( DESC_LEN ),
        .RQ_DW ( RQ_DW ),
        .RQ_DK ( RQ_DK ),
        .DISABLE_FRAME_INFO ( DISABLE_FRAME_INFO ),
        .IGNORE_CPL_SIZE ( IGNORE_CPL_SIZE ),
        .RQBASE ( RQBASE )
    ) transfer_cpl (
        .stream_ch_valids ( stream_ch_valids ),
        .stream_ch_d2d_valids ( stream_ch_d2d_valids ),

        .desc_base_vaddr ( desc_base_o_vaddr ),
        .desc_base_size ( desc_base_o_size ),
        .desc_base_final ( desc_base_o_final ),
        .desc_base_valid ( desc_base_o_valid ),
        .desc_base_ready ( desc_base_o_ready ),
`ifdef OLD_IMPL
        .desc_req_data ( desc_cpl_data ),
        .desc_req_keep ( desc_cpl_keep ),
        .desc_req_valid ( desc_cpl_valid ),
        .desc_req_last ( desc_cpl_last ),
        .desc_req_ready ( desc_cpl_ready ),
`else
        .desc_cpl_data ( desc_cpl_data ),
        .desc_cpl_ch ( desc_cpl_ch ),
        .desc_cpl_valid ( desc_cpl_valid ),
        .desc_cpl_ready ( desc_cpl_ready ),
`endif
        .transfer_cpl_ch ( transfer_cpl_ch ),
        .transfer_cpl_ch_valid ( transfer_cpl_ch_valid ),
        .transfer_cpl_ch_done ( transfer_cpl_ch_done ),

        .queue_wr_data ( queue_wr_data ),
        .queue_wr_keep ( queue_wr_keep ),
        .queue_wr_valid ( queue_wr_valid ),
        .queue_wr_ready ( queue_wr_ready ),

        .cpl_q_head_addrs ( cpl_q_head_addrs ),
`ifdef OLD_IMPL
        .stream_desc_bases ( stream_desc_bases ),
        .stream_desc_ends ( stream_desc_ends ),
`endif
        .desc_req_ch ( desc_req_ch ),
        .desc_req_ch_valid ( desc_req_ch_valid ),
        .dbg_transfer_valids ( transfer_valids ),
        .dbg_transfer_issue_ends ( transfer_issue_ends ),
        .dbg_transfer_ends ( transfer_ends ),
        .transfer_cpl_ch_cand ( transfer_cpl_ch_cand ),

        .clk ( clk ),
        .resetn ( resetn )
    );

    assign desc_completes = {{CH_NUM-1{1'b0}}, desc_req_ch_valid} << desc_req_ch;
    //assign desc_completes = {{CH_NUM-1{1'b0}}, transfer_cpl_ch_valid} << transfer_cpl_ch;

endmodule
