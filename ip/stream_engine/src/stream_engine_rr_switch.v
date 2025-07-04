/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module stream_engine_rr_switch #(
    parameter CH_NUM_LOG = 3,
    parameter DESC_RQ_DW = 512,
    parameter DESC_RQ_DK = 16,
    parameter DESC_RC_DW = 512,
    parameter DESC_RC_DK = 16,
    parameter DESC_RC_USER = 16,
    parameter RQ_DW = 384,
    parameter RQ_DK = 12,
    parameter RC_DW = 352,
    parameter RC_DK = 11,
    parameter DISABLE_FRAME_INFO = 0,
    parameter ENABLE_FRAME_INFO_OUT = 0,
    parameter CH_BASE = 0,
    parameter RCBASE = 96,
    parameter [7:0] QUEUE_CHECK_TAG = 8'd99,
    parameter [7:0] QUEUE_READ_TAG = 8'd98,
    parameter IBUF_DEPTH = DISABLE_FRAME_INFO == 0 ? 2 : 4
    ) (
    input [(1<<CH_NUM_LOG)*64-1:0] stream_desc_bases,
    input [(1<<CH_NUM_LOG)*64-1:0] stream_desc_ends,
    input [(1<<CH_NUM_LOG)-1:0]    stream_valids,

    // from DMA TX/RX
    input [DESC_RQ_DW-1:0]         i_rd_data,
    input                          i_rd_last,
    input                          i_rd_valid,
    output                         i_rd_ready,
    input [DESC_RQ_DW-1:0]         i_wr_data,
    input                          i_wr_last,
    input                          i_wr_valid,
    output                         i_wr_ready,

    // from PCI TRX
    input [DESC_RC_DW-1:0]         i_rc_data,
    input [DESC_RC_DK-1:0]         i_rc_keep,
    input [DESC_RC_USER-1:0]       i_rc_user,
    input                          i_rc_last,
    input                          i_rc_valid,
    output                         i_rc_ready,

    // to DMA TX/RX
    output [DESC_RC_DW-1:0]        o_rc_data,
    output [DESC_RC_DK-1:0]        o_rc_keep,
    output [DESC_RC_USER-1:0]      o_rc_user,
    output                         o_rc_last,
    output                         o_rc_valid,
    input                          o_rc_ready,

    // to PCI TRX
    output [DESC_RQ_DW-1:0]        o_rd_data,
    output                         o_rd_last,
    output                         o_rd_valid,
    input                          o_rd_ready,
    output [DESC_RQ_DW-1:0]        o_wr_data,
    output                         o_wr_last,
    output                         o_wr_valid,
    input                          o_wr_ready,

    // from core
    input [RQ_DW-1:0]              queue_check_data,
    input [RQ_DK-1:0]              queue_check_keep,
    input                          queue_check_valid,
    output                         queue_check_ready,
    input [RQ_DW-1:0]              queue_update_data,
    input [RQ_DK-1:0]              queue_update_keep,
    input                          queue_update_valid,
    output                         queue_update_ready,
    input [RQ_DW-1:0]              queue_rd_data,
    input [RQ_DK-1:0]              queue_rd_keep,
    input                          queue_rd_valid,
    output                         queue_rd_ready,
    input [RQ_DW-1:0]              queue_wr_data,
    input [RQ_DK-1:0]              queue_wr_keep,
    input                          queue_wr_valid,
    output                         queue_wr_ready,

    // to core
    output [RC_DW-1:0]             queue_check_res_data,
    output                         queue_check_res_valid,
    output [RC_DW-1:0]             queue_rd_res_data,
    output                         queue_rd_res_valid,

    // to core
    output [DESC_RQ_DW-1:0]        desc_req_data,
    output [DESC_RQ_DK-1:0]        desc_req_keep,
    output                         desc_req_last,
    output                         desc_req_valid,
    input                          desc_req_ready,
    output [DESC_RQ_DW-1:0]        desc_cpl_data,
    output [DESC_RQ_DK-1:0]        desc_cpl_keep,
    output                         desc_cpl_last,
    output                         desc_cpl_valid,
    input                          desc_cpl_ready,

    // from core
    input [DESC_RC_DW-1:0]         desc_out_data,
    input [DESC_RC_DK-1:0]         desc_out_keep,
    input                          desc_out_last,
    input                          desc_out_valid,
    output                         desc_out_ready,

    // frame info out
    input [31:0]                   frame_info_in_size,
    input [CH_NUM_LOG-1:0]         frame_info_in_ch,
    input                          frame_info_in_valid,
    output                         frame_info_in_ready,

    output [31:0]                  frame_info_out_size,
    output [CH_NUM_LOG-1:0]        frame_info_out_ch,
    output                         frame_info_out_valid,
    input                          frame_info_out_ready,

    // debug
    output [31:0]                  o_rc_icount,
    output [31:0]                  o_rc_count,
    output [15:0]                  o_rc_count_fixed_cycle,

    input                          clk,
    input                          resetn
    );

    // i_rd -> o_rd / desc_req
    // queue_check, queue_rd, -> o_rd
    fdma_read_rq_switch #(
        .ENGINE_IPORT_NUM ( 2 ),
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .DESC_RQ_DW ( DESC_RQ_DW ),
        .RQ_DW ( RQ_DW ),
        .CH_BASE ( CH_BASE )
    ) rq_read_switch (
        .stream_valids ( stream_valids ),
        .i_rq_data ( i_rd_data ),
        .i_rq_last ( i_rd_last ),
        .i_rq_valid ( i_rd_valid ),
        .i_rq_ready ( i_rd_ready ),
        .i_se_data ( {queue_check_data, queue_rd_data} ),
        .i_se_last ( 2'd3 ),
        .i_se_valid ( {queue_check_valid, queue_rd_valid} ),
        .i_se_ready ( {queue_check_ready, queue_rd_ready} ),
        .o_rq_data ( o_rd_data ),
        .o_rq_last ( o_rd_last ),
        .o_rq_valid ( o_rd_valid ),
        .o_rq_ready ( o_rd_ready ),
        .o_se_data ( desc_req_data ),
        .o_se_last ( desc_req_last ),
        .o_se_valid ( desc_req_valid ),
        .o_se_ready ( desc_req_ready ),
        .clk ( clk ),
        .resetn ( resetn )
    );
    assign desc_req_keep = 'hf;

    // i_wr -> o_wr / desc_cpl
    // queue_update, queue_wr -> o_wr
    fdma_write_rq_switch #(
        .ENGINE_IPORT_NUM ( 2 ),
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .CH_BASE ( CH_BASE ),
        .DESC_RQ_DW ( DESC_RQ_DW ),
        .DESC_RQ_DK ( DESC_RQ_DK ),
        .RQ_DW ( RQ_DW )
    ) rq_write_switch (
        .range_starts ( stream_desc_bases ),
        .range_ends ( stream_desc_ends ),
        .range_valids ( stream_valids ),
        .i_rq_data ( i_wr_data ),
        .i_rq_last ( i_wr_last ),
        .i_rq_valid ( i_wr_valid ),
        .i_rq_ready ( i_wr_ready ),
        .i_se_data ( {queue_update_data, queue_wr_data} ),
        .i_se_last ( 2'd3 ),
        .i_se_valid ( {queue_update_valid, queue_wr_valid} ),
        .i_se_ready ( {queue_update_ready, queue_wr_ready} ),
        .o_rq_data ( o_wr_data ),
        .o_rq_last ( o_wr_last ),
        .o_rq_valid ( o_wr_valid ),
        .o_rq_ready ( o_wr_ready ),
        .o_se_data ( desc_cpl_data ),
        .o_se_keep ( desc_cpl_keep ),
        .o_se_last ( desc_cpl_last ),
        .o_se_valid ( desc_cpl_valid ),
        .o_se_ready ( desc_cpl_ready ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    // i_rc -> o_rc / queue_check_res, queue_rd_res
    // desc_out -> o_rc
    fdma_read_rc_switch #(
        .ENGINE_IPORT_NUM ( 1 ),
        .ENGINE_OPORT_NUM ( 2 ),
        .TAG_BASE ( {QUEUE_CHECK_TAG, QUEUE_READ_TAG} ),
        .DESC_RC_DW ( DESC_RC_DW ),
        .DESC_RC_DK ( DESC_RC_DK ),
        .DESC_RC_USER ( DESC_RC_USER ),
        .RC_DW ( RC_DW ),
        .RC_DK ( RC_DK ),
        .RCBASE ( RCBASE ),
        .CH_BASE ( CH_BASE ),
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .DISABLE_FRAME_INFO ( DISABLE_FRAME_INFO ),
        .ENABLE_FRAME_INFO_OUT ( ENABLE_FRAME_INFO_OUT ),
        .IBUF_DEPTH ( IBUF_DEPTH )
    ) rc_read_switch (
        .i_rc_data ( i_rc_data ),
        .i_rc_keep ( i_rc_keep ),
        .i_rc_user ( i_rc_user ),
        .i_rc_last ( i_rc_last ),
        .i_rc_valid ( i_rc_valid ),
        .i_rc_ready ( i_rc_ready ),
        .i_se_data ( desc_out_data ),
        .i_se_keep ( desc_out_keep ),
        .i_se_last ( desc_out_last ),
        .i_se_valid ( desc_out_valid ),
        .i_se_ready ( desc_out_ready ),
        .o_rc_data ( o_rc_data ),
        .o_rc_keep ( o_rc_keep ),
        .o_rc_user ( o_rc_user ),
        .o_rc_last ( o_rc_last ),
        .o_rc_valid ( o_rc_valid ),
        .o_rc_ready ( o_rc_ready ),
        .o_se_data ( {queue_check_res_data, queue_rd_res_data} ),
        .o_se_last (  ),
        .o_se_valid ( {queue_check_res_valid, queue_rd_res_valid} ),
        .o_se_ready ( 2'd3 ),
        .o_rc_icount ( o_rc_icount ),
        .o_rc_count ( o_rc_count ),
        .o_rc_count_fixed_cycle ( o_rc_count_fixed_cycle ),
        .frame_info_in_size ( frame_info_in_size ),
        .frame_info_in_ch ( frame_info_in_ch ),
        .frame_info_in_valid ( frame_info_in_valid ),
        .frame_info_in_ready ( frame_info_in_ready ),
        .frame_info_out_size ( frame_info_out_size ),
        .frame_info_out_ch ( frame_info_out_ch ),
        .frame_info_out_valid ( frame_info_out_valid ),
        .frame_info_out_ready ( frame_info_out_ready ),
        .clk ( clk ),
        .resetn ( resetn )
    );

endmodule
