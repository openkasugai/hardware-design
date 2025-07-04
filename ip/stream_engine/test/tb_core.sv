/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_core #(
    parameter CH_NUM_LOG = 3,
    parameter RQ_DW = 384,
    parameter RQ_DK = 12,
    parameter RC_DW = 352,
    parameter RC_DK = 11,
    parameter DESC_RQ_DW = 512,
    parameter DESC_RQ_DK = 16,
    parameter DESC_RC_DW = 512,
    parameter DESC_RC_DK = 16,
    parameter DESC_LEN = 512,
    parameter DISABLE_FRAME_INFO = 0,
    parameter ENABLE_FRAME_INFO_OUT = 0,
    parameter FRAME_INFO_FIFO_DL = 5,
    parameter DESC_BASE_FIFO_DL = 2,
    parameter VP_MAP_NUM_LOG = 5,
    parameter FRAME_INFO_BITS = 1,
    parameter REQ_CH_BASE = 22,
    parameter ADD_REQ_BASE = 15,
    parameter ADD_REQ_BITS = 2,
    parameter TRANSFER_MAX_LOG = 8,
    parameter TRANSFER_NUM = 100,
    parameter VPMAP_SIZE_MAX = 32'hfffffffc,
    parameter TAIL_UP_POS = 12,
    parameter TAIL_UP_NUM = 3,
    parameter CH_BASE = 0,
    parameter QEW_LOG = 5,
    parameter QEW = 1 << QEW_LOG,
    parameter QUEUE_CHECK_TAG = 99,
    parameter QUEUE_READ_TAG = 98,
    parameter RQBASE = 128,
    parameter RCBASE = 96,
    parameter REG_BASE = 16'h4000,
    parameter QUEUE_MAX = 16,
    parameter ENABLE_QUEUE = 0,
    parameter [39:0] D2D_AXI_BASE = 40'h0,
    parameter [31:0] D2D_AXI_RANGE = 32'h4000_0000, // 1GB
    parameter ENABLE_D2D = 0,
    parameter QUEUE_DL = 3,
    parameter ENABLE_QUEUE_PATTERN = 0,
    parameter [(1<<CH_NUM_LOG)-1:0] QUEUE_PATTERN = {(1<<CH_NUM_LOG){1'b1}},
    parameter ENABLE_OOR = 0,
    parameter CPL_START_DELAY = 0,
    parameter TEST_CASE = 0,
    parameter FRAME_INFO_READY_BITS = 0,
    parameter INCOMPLETE_THRESHOLD = 10000
    ) ();

    wire clk, resetn;
    wire [31:0] rd;
    clk_reset clk_reset(
        .clk ( clk ),
        .resetn ( resetn ),
        .rd ( rd )
    );

    localparam CH_NUM = 1 << CH_NUM_LOG;
    localparam QEWB_LOG = QEW + 3;
    localparam QEWB = 1 << QEWB_LOG;
    localparam FRAME_INFO_READY_BITS_MOD = FRAME_INFO_READY_BITS > 0 ? FRAME_INFO_READY_BITS : 1'b1;

    reg [15:0]           reg_araddr;
    reg                  reg_arvalid;
    wire                 reg_arready;
    wire [31:0]          reg_rdata;
    wire [1:0]           reg_rresp;
    wire                 reg_rvalid;
    reg                  reg_rready;
    reg [15:0]           reg_awaddr;
    reg                  reg_awvalid;
    wire                 reg_awready;
    reg [31:0]           reg_wdata;
    reg                  reg_wvalid;
    wire                 reg_wready;
    wire [1:0]           reg_bresp;
    wire                 reg_bvalid;
    reg                  reg_bready;

    reg [31:0]           tx_size;
    reg [CH_NUM_LOG-1:0] tx_ch;
    reg                  tx_valid;
    wire                 tx_ready;

    wire [31:0]           rx_size;
    wire [CH_NUM_LOG-1:0] rx_ch;
    wire                  rx_valid;
    reg                   rx_ready;

    reg [DESC_RQ_DW-1:0] desc_req_data;
    reg [DESC_RQ_DK-1:0] desc_req_keep;
    reg                  desc_req_valid;
    wire                 desc_req_ready;

    wire [DESC_RC_DW-1:0] desc_out_data;
    wire [DESC_RC_DK-1:0] desc_out_keep;
    wire                  desc_out_valid;
    wire                  desc_out_last;
    reg                   desc_out_ready;
`ifdef OLD_IMPL
    reg [DESC_RQ_DW-1:0]  desc_cpl_data;
    reg [DESC_RQ_DK-1:0]  desc_cpl_keep;
    reg                   desc_cpl_valid;
    reg                   desc_cpl_last;
    wire                  desc_cpl_ready;
`else
    reg [CH_NUM_LOG-1:0]  desc_cpl_ch;
    reg [31:0]            desc_cpl_data;
    reg                   desc_cpl_valid;
    wire                  desc_cpl_ready;
`endif
    wire [RQ_DW-1:0]     queue_check_data;
    wire [RQ_DK-1:0]     queue_check_keep;
    wire                 queue_check_valid;
    reg                  queue_check_ready;

    wire [RQ_DW-1:0]     queue_update_data;
    wire [RQ_DK-1:0]     queue_update_keep;
    wire                 queue_update_valid;
    reg                  queue_update_ready;

    reg [RC_DW-1:0]      queue_check_res_data;
    reg                  queue_check_res_valid;

    reg [RC_DW-1:0]      queue_rd_res_data;
    reg                  queue_rd_res_valid;

    wire [RQ_DW-1:0]     queue_rd_data;
    wire [RQ_DK-1:0]     queue_rd_keep;
    wire                 queue_rd_valid;
    reg                  queue_rd_ready;

    wire [RQ_DW-1:0]     queue_wr_data;
    wire [RQ_DK-1:0]     queue_wr_keep;
    wire                 queue_wr_valid;
    reg                  queue_wr_ready;

    wire                 frame_info_full;

    wire [CH_NUM-1:0]    head_tail_updates;

    wire [64*CH_NUM-1:0] stream_cpl_q_bases_out;
    wire [CH_NUM-1:0]    stream_ch_valids;
    wire [CH_NUM-1:0]    stream_ch_d2d_valids;
    wire [64*CH_NUM-1:0] stream_doorbell_addrs;
    wire [CH_NUM-1:0]    stream_ch_interrupt_enables;

    reg [CH_NUM_LOG-1:0] stream_cpl_update_ch; // tail update
    reg                  stream_cpl_update;
    reg [CH_NUM_LOG-1:0] stream_queue_read_ch;
    reg [QUEUE_DL-1:0]   stream_queue_read_entry;
    reg                  stream_queue_read_valid;
    wire [QEWB-1:0]      stream_queue_read_data;
    wire                 stream_queue_read_data_valid;

    initial begin
        reg_araddr = 16'd0;
        reg_arvalid = 1'b0;
        reg_rready = 1'b0;
        reg_awaddr = 16'd0;
        reg_awvalid = 1'b0;
        reg_wdata = 32'd0;
        reg_wvalid = 1'b0;
        reg_bready = 1'b0;
        tx_size <= 'd0;
        tx_ch <= 'd0;
        tx_valid <= 1'b0;
        rx_ready <= 1'b1;
        desc_req_data = 'd0;
        desc_req_keep = 'd0;
        desc_req_valid = 1'b0;
        desc_out_ready = 1'b0;
        desc_cpl_data = 'd0;
        desc_cpl_valid = 1'b0;
`ifdef OLD_IMPL
        desc_cpl_keep = 'd0;
        desc_cpl_last = 1'b0;
`endif
        queue_check_ready = 'b0;
        queue_update_ready = 'b0;
        queue_check_res_valid = 1'b0;
        queue_check_res_data = 'd0;
        queue_rd_res_data = 'd0;
        queue_rd_res_valid = 1'b0;
        queue_rd_ready = 1'b0;
        queue_wr_ready = 1'b0;
        stream_cpl_update = 1'b0;
        stream_queue_read_valid = 1'b0;
    end

    stream_engine_core #(
        .REG_BASE ( REG_BASE ),
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .RQ_DW ( RQ_DW ),
        .RQ_DK ( RQ_DK ),
        .RC_DW ( RC_DW ),
        .RC_DK ( RC_DK ),
        .DESC_RQ_DW ( DESC_RQ_DW ),
        .DESC_RQ_DK ( DESC_RQ_DK ),
        .DESC_RC_DW ( DESC_RC_DW ),
        .DESC_RC_DK ( DESC_RC_DK ),
        .DESC_LEN ( DESC_LEN ),
        .DISABLE_FRAME_INFO ( DISABLE_FRAME_INFO ),
        .ENABLE_FRAME_INFO_OUT ( ENABLE_FRAME_INFO_OUT ),
        .FRAME_INFO_FIFO_DL ( FRAME_INFO_FIFO_DL ),
        .DESC_BASE_FIFO_DL ( DESC_BASE_FIFO_DL ),
        .VP_MAP_NUM_LOG ( VP_MAP_NUM_LOG ),
        .CH_BASE ( CH_BASE ),
        .QEW_LOG ( QEW_LOG ),
        .QEW ( 1 << QEW_LOG ),
        .ENABLE_QUEUE ( ENABLE_QUEUE ),
        .D2D_AXI_BASE ( D2D_AXI_BASE ),
        .D2D_AXI_RANGE ( D2D_AXI_RANGE ),
        .QUEUE_DL ( QUEUE_DL ),
        .RQBASE ( RQBASE ),
        .RCBASE ( RCBASE ),
        .QUEUE_CHECK_TAG ( QUEUE_CHECK_TAG ),
        .QUEUE_READ_TAG ( QUEUE_READ_TAG )
    ) dut (
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

        .frame_info_size ( tx_size ),
        .frame_info_ch ( tx_ch ),
        .frame_info_valid ( tx_valid ),
        .frame_info_ready ( tx_ready ),

        .frame_info_out_size ( rx_size ),
        .frame_info_out_ch ( rx_ch ),
        .frame_info_out_valid ( rx_valid ),
        .frame_info_out_ready ( rx_ready ),

        .desc_req_data ( desc_req_data ),
        .desc_req_keep ( desc_req_keep ),
        .desc_req_valid ( desc_req_valid ),
        .desc_req_ready ( desc_req_ready ),

        .desc_out_data ( desc_out_data ),
        .desc_out_keep ( desc_out_keep ),
        .desc_out_valid ( desc_out_valid ),
        .desc_out_last ( desc_out_last ),
        .desc_out_ready ( desc_out_ready ),
`ifdef OLD_IMPL
        .desc_cpl_data ( desc_cpl_data ),
        .desc_cpl_keep ( desc_cpl_keep ),
        .desc_cpl_valid ( desc_cpl_valid ),
        .desc_cpl_last ( desc_cpl_last ),
        .desc_cpl_ready ( desc_cpl_ready ),
`else
        .desc_cpl_data ( desc_cpl_data ),
        .desc_cpl_ch ( desc_cpl_ch ),
        .desc_cpl_valid ( desc_cpl_valid ),
        .desc_cpl_ready ( desc_cpl_ready ),
`endif
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

        .queue_rd_data ( queue_rd_data ),
        .queue_rd_keep ( queue_rd_keep ),
        .queue_rd_valid ( queue_rd_valid ),
        .queue_rd_ready ( queue_rd_ready ),
        .queue_rd_res_data ( queue_rd_res_data ),
        .queue_rd_res_valid ( queue_rd_res_valid ),

        .queue_wr_data ( queue_wr_data ),
        .queue_wr_keep ( queue_wr_keep ),
        .queue_wr_valid ( queue_wr_valid ),
        .queue_wr_ready ( queue_wr_ready ),

        .stream_cpl_q_bases (stream_cpl_q_bases_out ),
        .stream_ch_valids ( stream_ch_valids ),
        .stream_ch_d2d_valids ( stream_ch_d2d_valids ),
        .stream_doorbell_addrs ( stream_doorbell_addrs ),
        .stream_ch_interrupt_enables ( stream_ch_interrupt_enables ),

        .stream_cpl_update_ch ( stream_cpl_update_ch ),
        .stream_cpl_update ( stream_cpl_update ),
        .stream_queue_read_ch ( stream_queue_read_ch ),
        .stream_queue_read_entry ( stream_queue_read_entry ),
        .stream_queue_read_valid ( stream_queue_read_valid ),
        .stream_queue_read_data ( stream_queue_read_data ),
        .stream_queue_read_data_valid ( stream_queue_read_data_valid ),

        .head_tail_updates ( head_tail_updates ),

        .clk ( clk ),
        .resetn ( resetn )
    );

    localparam VP_MAP_NUM = 1 << VP_MAP_NUM_LOG;
    localparam VPMAP_CH_AGGREGATE = CH_NUM_LOG + VP_MAP_NUM_LOG + 5 > 15 ? 1 : 0;
    localparam VPMAP_MAX = VPMAP_CH_AGGREGATE ? 4 << (VP_MAP_NUM_LOG + 3) : 4 << (CH_NUM_LOG + VP_MAP_NUM_LOG + 3);
    localparam CTRL_MAX = VPMAP_MAX + (4 << (CH_NUM_LOG + 4));

    reg                  w_initializing;

    reg [CH_NUM*64-1:0]  stream_req_q_bases;
    reg [CH_NUM*64-1:0]  stream_cpl_q_bases;
    reg [CH_NUM*8-1:0]   stream_req_q_depth;
    reg [CH_NUM*8-1:0]   stream_cpl_q_depth;
    reg [CH_NUM*64-1:0]  stream_req_q_head_tails;
    reg [CH_NUM*64-1:0]  stream_cpl_q_head_tails;
    reg [CH_NUM*64-1:0]  stream_doorbell_bases;
    reg [CH_NUM*64-1:0]  stream_desc_bases; // not used
    reg [CH_NUM*64-1:0]  stream_desc_ends; // not used

    // queue check/update packet
    reg [7:0] req_queue_head[0:CH_NUM-1];
    reg [7:0] req_queue_read_pos[0:CH_NUM-1];
    reg [7:0] req_queue_tail[0:CH_NUM-1];
    reg [7:0] cpl_queue_head[0:CH_NUM-1];
    reg [7:0] cpl_queue_tail[0:CH_NUM-1];
    reg       req_queue_tail_updates[0:CH_NUM-1];
    reg       cpl_queue_head_updates[0:CH_NUM-1];
    reg [CH_NUM_LOG:0] stream_ch_valid_num;
    reg [CH_NUM_LOG:0] stream_ch_doorbell_num;
    reg [CH_NUM-1:0]   stream_ch_valids_reg;
    reg [CH_NUM-1:0]   stream_ch_d2d_valids_reg;
    reg [CH_NUM-1:0]   stream_ch_check_with_doorbells_reg;
    reg [CH_NUM-1:0]   stream_ch_interrupt_enables_reg;

    reg [CH_NUM_LOG-1:0] check_q_head_tail_ch;
    reg                  is_check_req_head_tail;
    reg [CH_NUM_LOG-1:0] update_q_head_tail_ch;
    reg                  is_update_req_head_tail;
    int                  ch;
    always @(queue_check_data) begin
        for (ch = 0; ch < CH_NUM; ch++) begin
            if (queue_check_data[63:0] === stream_req_q_head_tails[ch*64+:64]) begin
                check_q_head_tail_ch = ch;
                is_check_req_head_tail = 1'b1;
                break;
            end else if (queue_check_data[63:0] == stream_cpl_q_head_tails[ch*64+:64]) begin
                check_q_head_tail_ch = ch;
                is_check_req_head_tail = 1'b0;
                break;
            end
        end
    end
    always @(queue_update_data) begin
        for (ch = 0; ch < CH_NUM; ch++) begin
            if (queue_update_data[63:0] === stream_req_q_head_tails[ch*64+:64] + 3'd4) begin
                update_q_head_tail_ch = ch;
                is_update_req_head_tail = 1'b1;
                break;
            end else if (queue_update_data[63:0] === stream_cpl_q_head_tails[ch*64+:64]) begin
                update_q_head_tail_ch = ch;
                is_update_req_head_tail = 1'b0;
                break;
            end
        end
    end
    always @(posedge clk) begin
        if (~resetn) begin
            queue_check_res_valid <= 1'b0;
            queue_check_res_data[RCBASE+63:0] <= 'd0;
            queue_check_ready <= 1'b0;
        end else begin
            if (queue_check_valid & queue_check_ready) begin
                queue_check_res_valid <= 1'b1;
                if (is_check_req_head_tail) begin
                    queue_check_res_data[RCBASE+:8] <= req_queue_head[check_q_head_tail_ch];
                    queue_check_res_data[RCBASE+32+:8] <= req_queue_tail[check_q_head_tail_ch];
                    if (req_queue_head[check_q_head_tail_ch] != req_queue_tail[check_q_head_tail_ch]) begin
                        $display("%d [%2d]: queue check: req q head/tail: %h/%h", $time, check_q_head_tail_ch,
                                 req_queue_head[check_q_head_tail_ch], req_queue_tail[check_q_head_tail_ch]);
                    end
                end else begin
                    queue_check_res_data[RCBASE+:8] <= cpl_queue_head[check_q_head_tail_ch];
                    queue_check_res_data[RCBASE+32+:8] <= cpl_queue_tail[check_q_head_tail_ch];
                    if (cpl_queue_head[check_q_head_tail_ch] != cpl_queue_tail[check_q_head_tail_ch]) begin
                        $display("%d [%2d]: queue check: cpl q head/tail: %h/%h", $time, check_q_head_tail_ch,
                                 cpl_queue_head[check_q_head_tail_ch], cpl_queue_tail[check_q_head_tail_ch]);
                    end
                end
                queue_check_res_data[11:0] <= queue_check_data[11:0]; // low addr
                queue_check_res_data[28:16] <= {queue_check_data[74:64], 2'd0}; // byte counts
                queue_check_res_data[30] <= 1'b1; // request completion
                queue_check_res_data[42:32] <= queue_check_data[74:64]; // dword count
                queue_check_res_data[71:64] <= queue_check_data[103:96]; // tag
            end else begin
                queue_check_res_valid <= 1'b0;
            end
            queue_check_ready <= rd[3];
            if (queue_update_valid & queue_update_ready) begin
                $display("queue update: %h %h <= %h", is_update_req_head_tail,
                         update_q_head_tail_ch, queue_update_data[128+:8]);
                if (is_update_req_head_tail) begin
                    req_queue_tail[update_q_head_tail_ch] <= queue_update_data[128+:8];
                    req_queue_tail_updates[update_q_head_tail_ch] <= 1'b1;
                    cpl_queue_head_updates[update_q_head_tail_ch] <= 1'b0;
                end else begin
                    cpl_queue_head[update_q_head_tail_ch] <= queue_update_data[128+:8];
                    cpl_queue_head_updates[update_q_head_tail_ch] <= 1'b1;
                    req_queue_tail_updates[update_q_head_tail_ch] <= 1'b0;
                end
            end else begin
                req_queue_tail_updates[update_q_head_tail_ch] <= 1'b0;
                cpl_queue_head_updates[update_q_head_tail_ch] <= 1'b0;
            end
            queue_update_ready <= rd[5];
        end
    end

    // virt/phys address map
    reg [63:0] vaddrs[0:CH_NUM-1];
    reg [31:0] vsizes[0:CH_NUM-1];
    reg [31:0] vaddr_offsets[0:CH_NUM-1];
    reg [63:0] vpmap_vaddrs[0:CH_NUM-1][0:VP_MAP_NUM-1];
    reg [31:0] vpmap_vsizes[0:CH_NUM-1][0:VP_MAP_NUM-1];
    reg [63:0] vpmap_paddrs[0:CH_NUM-1][0:VP_MAP_NUM-1];
    reg        vpmap_valids[0:CH_NUM-1][0:VP_MAP_NUM-1];

    initial begin
        for (int i=0; i<CH_NUM; i++) begin
            for (int j=0; j<VP_MAP_NUM; j++) begin
                vpmap_valids[i][j] = 1'b0;
            end
        end
    end

    // queue data
    reg [63:0] req_queue_addr[0:CH_NUM-1][0:QUEUE_MAX-1];
    reg [31:0] req_queue_size[0:CH_NUM-1][0:QUEUE_MAX-1];
    reg [31:0] req_queue_info_size[0:CH_NUM-1][0:QUEUE_MAX-1];
    reg [31:0] req_queue_stat[0:CH_NUM-1][0:QUEUE_MAX-1];
    reg        req_queue_read[0:CH_NUM-1][0:QUEUE_MAX-1];
    reg [CH_NUM-1:0] req_queue_ch;
    reg [15:0]       req_queue_idx;
    reg [15:0]       req_queue_check_idx;

    initial begin
        for (int i=0; i<CH_NUM; i++) begin
            for (int j=0; j<QUEUE_MAX; j++) begin
                req_queue_addr[i][j] = 'd0;
                req_queue_size[i][j] = 'd0;
                req_queue_info_size[i][j] = 'd0;
                req_queue_stat[i][j] = 'd0;
                req_queue_read[i][j] = 'd0;
            end
        end
    end

    // frame info out
    reg [31:0] frame_info_out_sizes[0:CH_NUM-1][0:255];
    reg [7:0]  out_size_wpos[0:CH_NUM-1];
    reg [7:0]  out_size_rpos[0:CH_NUM-1];
    initial begin
        for (int i=0; i<CH_NUM; i++) begin
            out_size_wpos[i] = 'd0;
            out_size_rpos[i] = 'd0;
        end
    end

    always @(queue_rd_data) begin
        for (int i=0; i<CH_NUM; i++) begin
            if (stream_req_q_bases[i*64+:64] <= queue_rd_data[63:0] &&
                queue_rd_data[63:0] < stream_req_q_bases[i*64+:64] + {stream_req_q_depth[i*8+:8], {QEW_LOG{1'b0}}}) begin
                req_queue_ch = i;
                req_queue_idx = (queue_rd_data[63:0] - stream_req_q_bases[i*64+:64]) >> QEW_LOG;
            end
        end
    end

    reg queue_rd_res_remain;
    always @(posedge clk) begin
        if (~resetn) begin
            queue_rd_res_valid <= 1'b0;
            queue_rd_res_data[RCBASE+QEWB-1:0] <= 'd0;
            queue_rd_ready <= 1'b0;
            queue_rd_res_remain <= 1'b0;
        end else begin
            if ((queue_rd_valid & queue_rd_ready) || queue_rd_res_remain) begin
                queue_rd_res_valid <= &rd[12:11];
                queue_rd_res_remain <= ~&rd[12:11];
                queue_rd_res_data[RCBASE+:64] <= req_queue_addr[req_queue_ch][req_queue_idx];
                queue_rd_res_data[RCBASE+64+:32] <= req_queue_size[req_queue_ch][req_queue_idx];
                queue_rd_res_data[RCBASE+128+:32] <= 32'd1;//req_queue_stat[req_queue_ch][req_queue_idx];
                queue_rd_res_data[11:0] <= queue_rd_data[11:0]; // low addr
                queue_rd_res_data[28:16] <= {queue_rd_data[74:64], 2'd0}; // byte counts
                queue_rd_res_data[30] <= 1'b1; // request completion
                queue_rd_res_data[42:32] <= queue_rd_data[74:64]; // dword count
                queue_rd_res_data[71:64] <= queue_rd_data[103:96]; // tag
                req_queue_read[req_queue_ch][req_queue_idx] <= 1'b1;
                if (&rd[12:11]) begin
                    $display("%d [%2d]: queue rd: vaddr:%h vsize:%h stat:%h, idx:%h (%h)", $time, req_queue_ch,
                             req_queue_addr[req_queue_ch][req_queue_idx], req_queue_size[req_queue_ch][req_queue_idx],
                             req_queue_stat[req_queue_ch][req_queue_idx], req_queue_idx, queue_rd_data[63:0]);
                end
            end else begin
                queue_rd_res_valid <= 1'b0;
            end
            queue_rd_ready <= rd[3];
        end
    end

    reg [31:0] frame_info_sizes[0:255];
    reg [CH_NUM_LOG-1:0] frame_info_chs[0:255];
    reg [7:0]            frame_info_rpos;
    reg [7:0]            frame_info_wpos;
    reg [31:0]           frame_info_ch_sizes[0:CH_NUM-1][0:255];
    reg [7:0]            frame_info_ch_size_wpos[0:CH_NUM-1];
    reg [7:0]            frame_info_ch_size_rpos[0:CH_NUM-1];

    initial begin
        frame_info_wpos = 'd0;
        for (int i=0; i<CH_NUM; i++) begin
           frame_info_ch_size_wpos[i] = 'd0;
           frame_info_ch_size_rpos[i] = 'd0;
        end
    end

    always @(posedge clk) begin
        if (~resetn) begin
            frame_info_rpos <= 'd0;
            tx_size <= 'd0;
            tx_ch <= 'd0;
            tx_valid <= 1'b0;
        end else if (frame_info_rpos[6:0] != frame_info_wpos[6:0]) begin
            if (DISABLE_FRAME_INFO == 0 && &rd[8+:FRAME_INFO_BITS]) begin
                tx_size <= frame_info_sizes[frame_info_rpos];
                tx_ch <= frame_info_chs[frame_info_rpos];
                tx_valid <= 1'b1;
                frame_info_rpos <= frame_info_rpos + 1'b1;
                frame_info_ch_sizes[frame_info_chs[frame_info_rpos]][frame_info_ch_size_wpos[frame_info_chs[frame_info_rpos]]] <= frame_info_sizes[frame_info_rpos];
                frame_info_ch_size_wpos[frame_info_chs[frame_info_rpos]] <= frame_info_ch_size_wpos[frame_info_chs[frame_info_rpos]] + 1'b1;
            end else begin
                tx_valid <= tx_valid & ~tx_ready;
            end
        end else begin
            tx_valid <= tx_valid & ~tx_ready;
        end
    end

    // queue wr
    reg queue_wr_addr_found;
    logic [TRANSFER_MAX_LOG-1:0] cur_deq_pos;
    logic [TRANSFER_MAX_LOG-1:0] deq_pos[0:CH_NUM-1];
    always @(posedge clk) begin
        if (~resetn) begin
            for (int i=0; i<CH_NUM; i++) begin
                deq_pos[i] <= 'd0;
            end
        end
        if (queue_wr_valid === 1'b1 && queue_wr_ready === 1'b1) begin
            queue_wr_addr_found = 1'b0;
            for (int i=0; i<CH_NUM; i++) begin
`ifdef OBS
                if (stream_req_q_bases[i*64+:64] <= queue_wr_data[63:0] &&
                    queue_wr_data[63:0] < stream_req_q_bases[i*64+:64] + {stream_req_q_depth[i*8+:8], {QEW_LOG{1'b0}}}) begin
                    $display("%d [%2d]:                         req tail: vaddr:%h size:%h stat:%h", $time, i,
                             queue_wr_data[RQBASE+:64], queue_wr_data[RQBASE+64+:32], queue_wr_data[RQBASE+128+:32]);
                    cur_deq_pos = (queue_wr_data[63:0] - stream_req_q_bases[i*64+:64]) >> QEW_LOG;
                    if (req_queue_addr[i][cur_deq_pos] !== queue_wr_data[RQBASE+:64] ||
                        (req_queue_size[i][cur_deq_pos] !== queue_wr_data[RQBASE+64+:32] &&
                         req_queue_info_size[i][cur_deq_pos] !== queue_wr_data[RQBASE+64+:32])||
                        queue_wr_data[RQBASE+128+:32] !== 'd2) begin
                        $error("req tail error[%3d]: ch:%h, vaddr:%h,%h, size:%h,%h,%h, stat:%h", cur_deq_pos,
                               i, queue_wr_data[RQBASE+:64], req_queue_addr[i][cur_deq_pos],
                               queue_wr_data[RQBASE+64+:32], req_queue_size[i][cur_deq_pos], req_queue_info_size[i][cur_deq_pos], queue_wr_data[RQBASE+128+:32]);
                    end else begin
                        $display("req tail[%3d]: ch:%h, vaddr:%h,%h, size:%h,%h,%h, stat:%h", cur_deq_pos,
                                 i, queue_wr_data[RQBASE+:64], req_queue_addr[i][cur_deq_pos],
                                 queue_wr_data[RQBASE+64+:32], req_queue_size[i][cur_deq_pos], req_queue_info_size[i][cur_deq_pos], queue_wr_data[RQBASE+128+:32]);
                    end
                    cur_deq_pos_saved <= cur_deq_pos;
                    queue_wr_addr_found = 1'b1;
                end
`endif
                if (stream_cpl_q_bases[i*64+:64] <= queue_wr_data[63:0] &&
                    queue_wr_data[63:0] < stream_cpl_q_bases[i*64+:64] + {stream_cpl_q_depth[i*8+:8], {QEW_LOG{1'b0}}}) begin
                    $display("%d [%2d]:                         cpl head: vaddr:%h size:%h stat:%h", $time, i,
                             queue_wr_data[RQBASE+:64], queue_wr_data[RQBASE+64+:32], queue_wr_data[RQBASE+128+:32]);
                    cur_deq_pos = (queue_wr_data[63:0] - stream_cpl_q_bases[i*64+:64]) >> QEW_LOG;
                    if (req_queue_stat[i][deq_pos[i]] !== queue_wr_data[RQBASE+128+:32] ||
                        req_queue_addr[i][deq_pos[i]] !== queue_wr_data[RQBASE+:64] ||
                        (req_queue_size[i][deq_pos[i]] !== queue_wr_data[RQBASE+64+:32] &&
                         req_queue_info_size[i][deq_pos[i]] !== queue_wr_data[RQBASE+64+:32] &&
                         (req_queue_stat[i][deq_pos[i]] == 'd2 || |queue_wr_data[RQBASE+64+:32]))) begin
                        $error("cpl head error[%3d,%3d]: ch:%h, vaddr:%h,%h, size:%h,%h,%h, stat:%h", deq_pos[i], cur_deq_pos,
                               i, queue_wr_data[RQBASE+:64], req_queue_addr[i][deq_pos[i]],
                               queue_wr_data[RQBASE+64+:32], req_queue_size[i][deq_pos[i]], req_queue_info_size[i][deq_pos[i]], queue_wr_data[RQBASE+128+:32]);
                    end else begin
                        $display("cpl head[%3d,%3d]: ch:%h, vaddr:%h,%h, size:%h,%h, stat:%h", deq_pos[i], cur_deq_pos,
                               i, queue_wr_data[RQBASE+:64], req_queue_addr[i][deq_pos[i]],
                               queue_wr_data[RQBASE+64+:32], req_queue_size[i][deq_pos[i]], req_queue_info_size[i][deq_pos[i]], queue_wr_data[RQBASE+128+:32]);
                    end
                    req_queue_stat[i][deq_pos[i]] <= 'd0;
                    deq_pos[i] <= deq_pos[i] + 1'b1 >= stream_req_q_depth[i*8+:8] ? 'd0 : deq_pos[i] + 1'b1;
                    queue_wr_addr_found = 1'b1;
                end
            end
            if (!queue_wr_addr_found) begin
                $error("queue wr addr failed: %h", queue_wr_data[63:0]);
            end
            if (queue_wr_data[74:64] !== (QEW>>2) ||
                queue_wr_data[78:75] !== 4'd1) begin
                $error("queue wr desc failed: %h %h", queue_wr_data[74:64], queue_wr_data[78:75]);
            end
        end
        queue_wr_ready <= rd[4];
    end

    // desc read
    reg [CH_NUM_LOG-1:0] desc_req_ch;
    logic [CH_NUM-1:0]   desc_req_fulls;
    always @(posedge clk) begin
        if (~resetn) begin
            desc_req_data <= 'd0;
            desc_req_keep <= 'd0;
            desc_req_valid <= 1'b0;
            desc_req_ch <= 'd0;
        end else if ((~desc_req_valid | desc_req_ready) & &rd[11:10]) begin
            desc_req_data[63:2] <= stream_desc_bases[desc_req_ch * 64+2+:62];
            desc_req_data[74:64] <= DESC_LEN >> 5;
            desc_req_data[103:96] <= CH_BASE + desc_req_ch;
            desc_req_keep <= 'hf;
            desc_req_valid <= ~desc_req_fulls[desc_req_ch];
            desc_req_ch <= desc_req_ch + 1'b1;
        end else begin
            desc_req_valid <= desc_req_valid & ~desc_req_ready;
        end
    end

    // desc out
    reg [31:0] dma_desc_sizes[0:CH_NUM-1][0:7];
    reg [3:0]  dma_desc_wpos[0:CH_NUM-1];
    reg [3:0]  dma_desc_rpos[0:CH_NUM-1];

    reg [CH_NUM_LOG-1:0] dma_desc_wch;
    reg                  desc_out_start;
    always @(posedge clk) begin
        if (~resetn) begin
            for (int i=0; i<CH_NUM; i++) begin
                dma_desc_wpos[i] <= 'd0;
            end
            desc_out_start <= 1'b1;
            desc_out_ready <= 1'b0;
        end else if (desc_out_start && desc_out_valid && desc_out_ready) begin
            dma_desc_wch = desc_out_data[71:64] - CH_BASE;
            dma_desc_sizes[dma_desc_wch][dma_desc_wpos[dma_desc_wch][2:0]] <= desc_out_data[RCBASE+32+:32];
            dma_desc_wpos[dma_desc_wch] <= dma_desc_wpos[dma_desc_wch] + (desc_out_data[RCBASE+16+:8] == 'd1);
            desc_out_start <= desc_out_last;
            if (desc_out_data[RCBASE+16+:8] == 'd1) begin
                $display("%d [%2d]: desc out: paddr:%h psize:%h cmd:%h, wpos:%h", $time, dma_desc_wch,
                         desc_out_data[RCBASE+64+:64], desc_out_data[RCBASE+32+:32], desc_out_data[RCBASE+16+:8], dma_desc_wpos[dma_desc_wch]);
            end
        end else begin
            desc_out_start <= (desc_out_valid && desc_out_ready && desc_out_last) ^ desc_out_start;
        end
        for (int i=0; i<CH_NUM; i++) begin
            desc_req_fulls[i] = (dma_desc_wpos[i][3] != dma_desc_rpos[i][3]) & (dma_desc_rpos[i][2:0] == dma_desc_wpos[i][2:0]);
        end
        desc_out_ready <= rd[22];
    end

    // desc cpl
    reg [CH_NUM_LOG-1:0] dma_desc_rch;
    reg [31:0]           dma_desc_total_sizes[0:CH_NUM-1];
`ifdef OLD_IMPL
    reg [15:0]           dma_desc_len;
    always @(posedge clk) begin
        if (~resetn) begin
            desc_cpl_data <= 'd0;
            desc_cpl_keep <= 'd0;
            desc_cpl_last <= 1'b0;
            desc_cpl_valid <= 1'b0;
            dma_desc_rch <= 'd0;
            dma_desc_len <= 'd0;
            for (int i=0; i<CH_NUM; i++) begin
                dma_desc_rpos[i] <= 'd0;
            end
        end else if (~desc_cpl_valid | desc_cpl_ready & ($time > CPL_START_DELAY)) begin
            if (~|dma_desc_len | (desc_cpl_valid & desc_cpl_last)) begin
                if ((dma_desc_wpos[dma_desc_rch][3] != dma_desc_rpos[dma_desc_rch][3]) ^ (dma_desc_wpos[dma_desc_rch][2:0] > dma_desc_rpos[dma_desc_rch][2:0])) begin
                    desc_cpl_data[63:2] <= stream_desc_bases[dma_desc_rch*64+2+:62];
                    desc_cpl_data[74:64] <= DESC_LEN >> 5;
                    desc_cpl_data[78:75] <= 4'd1;
                    desc_cpl_data[RQBASE+:16] <= rd[15:0];
                    desc_cpl_data[RQBASE+16+:8] <= 'd2;
                    if (DISABLE_FRAME_INFO > 0) begin
                        desc_cpl_data[RQBASE+32+:32] <= 'd0;
                    end else begin
                        desc_cpl_data[RQBASE+32+:32] <= dma_desc_sizes[dma_desc_rch][dma_desc_rpos[dma_desc_rch][2:0]];
                    end
                    desc_cpl_keep <= ('d1 << ((DESC_LEN + RQBASE) >> 5)) - 1'b1;
                    desc_cpl_last <= DESC_LEN + RQBASE <= DESC_RQ_DW;
                    desc_cpl_valid <= 1'b1;
                    dma_desc_len <= (DESC_LEN - RQBASE) >> 5;
                    dma_desc_rpos[dma_desc_rch] <= dma_desc_rpos[dma_desc_rch] + 1'b1;
                    dma_desc_rch <= dma_desc_rch + (DESC_LEN + RQBASE <= DESC_RQ_DW ? 1 : 0);
                    $display("%d [%2d]: desc cpl: psize:%h", $time, dma_desc_rch,
                             dma_desc_sizes[dma_desc_rch][dma_desc_rpos[dma_desc_rch][2:0]]);
                end else begin
                    desc_cpl_valid <= 1'b0;
                    desc_cpl_last <= 1'b0;
                    dma_desc_len <= 'd0;
                    dma_desc_rch <= dma_desc_rch + 1'b1;
                end
            end else if (|dma_desc_len) begin
                desc_cpl_data <= 'd0;
                desc_cpl_keep <= ('d1 << ((DESC_LEN >> 5) - dma_desc_len)) - 1'b1;
                desc_cpl_last <= DESC_LEN <= {dma_desc_len, 5'd0} + DESC_RQ_DW;
                dma_desc_len <= dma_desc_len + (DESC_RQ_DW >> 5);
                dma_desc_rch <= dma_desc_rch + (DESC_LEN <= {dma_desc_len, 5'd0} + DESC_RQ_DW);
            end else begin
                desc_cpl_last <= 1'b0;
                desc_cpl_valid <= 1'b0;
                dma_desc_len <= 'd0;
                dma_desc_rch <= dma_desc_rch + 1'b1;
            end
        end
    end
`else
    logic [31:0] cur_desc_cpl_size;
    logic [31:0] cur_desc_cpl_frame_size;
    always @(posedge clk) begin
        if (~resetn) begin
            desc_cpl_data <= 'd0;
            desc_cpl_ch <= 'd0;
            desc_cpl_valid <= 1'b0;
            dma_desc_rch <= 'd0;
            for (int i=0; i<CH_NUM; i++) begin
                dma_desc_rpos[i] <= 'd0;
                dma_desc_total_sizes[i] <= 'd0;
            end
        end else if (w_initializing) begin
            for (int i=0; i<CH_NUM; i++) begin
                dma_desc_total_sizes[i] <= 'd0;
            end
        end else if (~desc_cpl_valid | desc_cpl_ready & ($time > CPL_START_DELAY)) begin
           if ((dma_desc_wpos[dma_desc_rch][3] != dma_desc_rpos[dma_desc_rch][3]) ^ (dma_desc_wpos[dma_desc_rch][2:0] > dma_desc_rpos[dma_desc_rch][2:0])) begin
              cur_desc_cpl_size = dma_desc_sizes[dma_desc_rch][dma_desc_rpos[dma_desc_rch][2:0]];
              if (DISABLE_FRAME_INFO > 0) begin
                 desc_cpl_data <= 'd0;
              end else begin
                 desc_cpl_data <= cur_desc_cpl_size;
              end
              desc_cpl_ch <= dma_desc_rch;
              desc_cpl_valid <= 1'b1;
              dma_desc_rpos[dma_desc_rch] <= dma_desc_rpos[dma_desc_rch] + 1'b1;
              dma_desc_total_sizes[dma_desc_rch] += cur_desc_cpl_size;
              if (stream_ch_d2d_valids[dma_desc_rch]) begin
                 cur_desc_cpl_frame_size = req_queue_size[dma_desc_rch][deq_pos[dma_desc_rch]];
                 if (cur_desc_cpl_frame_size >= frame_info_ch_sizes[dma_desc_rch][frame_info_ch_size_rpos[dma_desc_rch]]) begin
                    cur_desc_cpl_frame_size = frame_info_ch_sizes[dma_desc_rch][frame_info_ch_size_rpos[dma_desc_rch]];
                 end
                 $display("%d [%2d]: d2d tx descriptor out: (%3d) size:%h, %h, %h", $time,
                          dma_desc_rch, deq_pos[dma_desc_rch],
                          dma_desc_sizes[dma_desc_rch][dma_desc_rpos[dma_desc_rch][2:0]],
                          dma_desc_total_sizes[dma_desc_rch], cur_desc_cpl_frame_size);
                 if (dma_desc_total_sizes[dma_desc_rch] == cur_desc_cpl_frame_size) begin
                    // no queue wr at d2d tx
                    $display("%d [%2d]: cpl not exist: (%3d) size:%h, %h", $time, dma_desc_rch, deq_pos[dma_desc_rch],
                             dma_desc_total_sizes[dma_desc_rch], cur_desc_cpl_frame_size);
                    req_queue_stat[dma_desc_rch][deq_pos[dma_desc_rch]] <= 'd0;
                    deq_pos[dma_desc_rch] <= (deq_pos[dma_desc_rch] + 1'b1) % stream_req_q_depth[dma_desc_rch*8+:8];
                    dma_desc_total_sizes[dma_desc_rch] = 'd0;
                    frame_info_ch_size_rpos[dma_desc_rch] <= frame_info_ch_size_rpos[dma_desc_rch] + 1'b1;
                 end
              end
          end else begin
              desc_cpl_valid <= desc_cpl_valid & ~desc_cpl_ready;
           end
           dma_desc_rch <= dma_desc_rch + 1'b1;
        end else begin
           desc_cpl_valid <= desc_cpl_valid & ~desc_cpl_ready;
           dma_desc_rch <= dma_desc_rch + 1'b1;
        end
    end
`endif
    // cpl q tail update
    always @(posedge clk) begin
        if (resetn) begin
            for (int i=0; i<CH_NUM; i++) begin
                if (cpl_queue_head[i] != cpl_queue_tail[i] && &rd[TAIL_UP_POS+:TAIL_UP_NUM]) begin
                    cpl_queue_tail[i] <= cpl_queue_tail[i] + 1'b1 < stream_cpl_q_depth[i*8+:8] ? cpl_queue_tail[i] + 1'b1 : 'd0;
                end
            end
        end
    end

    // frame info out check
    always @(posedge clk) begin
        if (rx_valid & rx_ready) begin
            if (ENABLE_QUEUE > 0 && stream_ch_d2d_valids[rx_ch]) begin
               if (rx_size !== D2D_AXI_RANGE) begin
                  $error("%d: frame info out: [%2d]  %h %h", $time, rx_ch, rx_size, D2D_AXI_RANGE);
               end
            end else if (rx_size !== frame_info_out_sizes[rx_ch][out_size_rpos[rx_ch]]) begin
                $error("%d: frame info out: [%2d]  %h %h", $time, rx_ch,
                       rx_size, frame_info_out_sizes[rx_ch][out_size_rpos[rx_ch]]);
            end
            out_size_rpos[rx_ch] <= out_size_rpos[rx_ch] + 1'b1;
        end
        if (resetn) rx_ready <= FRAME_INFO_READY_BITS > 0 ? &rd[9+:FRAME_INFO_READY_BITS_MOD] : 1'b1;
    end

    reg [7:0]            cpl_q_tails_doorbell[0:CH_NUM-1];
    reg [CH_NUM-1:0]     req_q_doorbells;
    reg                  doorbell_writing;
    reg                  w_doorbell_writing;
    always @(posedge clk) begin
       if (~resetn || w_initializing) begin
          for (int i=0; i<CH_NUM; i++) cpl_q_tails_doorbell[i] = 'd0;
          req_q_doorbells <= 'd0;
          doorbell_writing <= 1'b0;
       end else begin
          w_doorbell_writing = 1'b0;
          for (int ch=0; ch<CH_NUM; ch++) begin
             if (stream_ch_valids[ch] && stream_ch_check_with_doorbells_reg[ch] && ~doorbell_writing &&
                 (req_q_doorbells[ch] || cpl_q_tails_doorbell[ch] != cpl_queue_tail[ch])) begin
                reg_awaddr <= REG_BASE + VPMAP_MAX + ch * 64 + 60; // doorbell addr
                reg_awvalid <= 1'b1;
                reg_wvalid <= 1'b1;
                doorbell_writing <= 1'b1;
                w_doorbell_writing = 1'b1;
                req_q_doorbells[ch] <= 1'b0;
                cpl_q_tails_doorbell[ch] <= cpl_queue_tail[ch];
                break;
             end
          end
          if (~w_doorbell_writing) begin
             reg_awvalid <= reg_awvalid & ~reg_awready;
             reg_wvalid <= reg_wvalid & ~reg_wready;
             if ((~reg_awvalid || reg_awready) && (~reg_wvalid || reg_wready)) doorbell_writing <= 1'b0;
          end
          reg_bready <= rd[10];
       end
    end

    task static initialize_queues();
        int          i, j;
        logic [31:0] wdata;
        logic        addr_carry;
        // initialize registers
        @(posedge clk) stream_ch_valid_num <= 'd0;
        for (i=0; i<CH_NUM; i++) begin
            @(posedge clk) begin
                stream_ch_valids_reg[i] <= 1'b0;
                stream_ch_d2d_valids_reg[i] <= 1'b0;
                stream_ch_check_with_doorbells_reg[i] <= 1'b0;
                reg_bready <= 1'b0;
            end
            for (j=2; j<17; j++) begin
                @(posedge clk) begin
                    reg_awaddr <= REG_BASE + VPMAP_MAX + (i * 64) + (j & 15) * 4;
                    if (j==16 && ENABLE_QUEUE_PATTERN) begin
                        wdata = QUEUE_PATTERN[i] ? 'd1 : 'd0;
                    end else begin
                        wdata = j == 2 || j == 4 || j == 6 || j == 8 || j == 12 ? {rd[31:5], 5'd0} :
                                j == 10 || j == 11 ? (rd & 32'h0f0f) | 32'h0404 :
                                j==16 && ENABLE_D2D == 0 ? rd & 32'hffffffef : rd;
                    end
                    addr_carry = ({1'b0, stream_desc_bases[i*64+:32]} + {rd[31:$clog2(DESC_LEN>>3)], {$clog2(DESC_LEN>>3){1'b0}}}) >> 32;
                    reg_wdata <= wdata;
                    {reg_awvalid, reg_wvalid} <= j==15 ? 2'd0 : 2'd3;
                    case(j)
                        2: stream_req_q_bases[i*64+:32] <= wdata;
                        3: stream_req_q_bases[i*64+32+:32] <= wdata;
                        4: stream_cpl_q_bases[i*64+:32] <= wdata;
                        5: stream_cpl_q_bases[i*64+32+:32] <= wdata;
                        6: stream_req_q_head_tails[i*64+:32] <= wdata;
                        7: stream_req_q_head_tails[i*64+32+:32] <= wdata;
                        8: stream_cpl_q_head_tails[i*64+:32] <= wdata;
                        9: stream_cpl_q_head_tails[i*64+32+:32] <= wdata;
                        10: {stream_cpl_q_depth[i*8+:8], stream_req_q_depth[i*8+:8]} <= wdata[15:0];
                        11: begin
                            req_queue_head[i] <= wdata[7:0] % stream_req_q_depth[i*8+:8];
                            req_queue_read_pos[i] <= wdata[7:0] % stream_req_q_depth[i*8+:8];
                            req_queue_tail[i] <= wdata[7:0] % stream_req_q_depth[i*8+:8];
                            cpl_queue_head[i] <= wdata[15:8] % stream_cpl_q_depth[i*8+:8];
                            cpl_queue_tail[i] <= wdata[15:8] % stream_cpl_q_depth[i*8+:8];
                            req_queue_check_idx[i] <= wdata[7:0] % stream_req_q_depth[i*8+:8];
                            deq_pos[i] <= wdata[7:0] % stream_req_q_depth[i*8+:8];
                        end
                        12: stream_doorbell_bases[i*64+:32] <= wdata;
                        13: stream_doorbell_bases[i*64+32+:32] <= wdata;
                        14: begin
                           stream_ch_check_with_doorbells_reg[i] <= wdata[4];
                           stream_ch_interrupt_enables_reg[i] <= wdata[0];
                        end
                        15: begin
                           stream_desc_bases[i*64+:32] <= wdata;
                           stream_desc_bases[i*64+32+:32] <= wdata ^32'hd00db00f;
                           stream_desc_ends[i*64+:64] <= {wdata ^ 32'hd00db00f, wdata} +
                                                         {rd[31:$clog2(DESC_LEN>>3)], {$clog2(DESC_LEN>>3){1'b0}}};
                        end
                        16: begin
                            stream_ch_valids_reg[i] <= wdata[0];
                            stream_ch_d2d_valids_reg[i] <= wdata[4];
                            stream_ch_valid_num <= stream_ch_valid_num + (wdata[0] && (~wdata[4] || ENABLE_QUEUE==0));
                            $display("%d [%2d]: stream valid:%1h, d2d:%1h", $time, i, wdata[0], wdata[4]);
                        end
                    endcase
                end
                do @(posedge clk) {reg_awvalid, reg_wvalid} <= {reg_awvalid, reg_wvalid} & ~{reg_awready, reg_wready}; while (reg_awvalid | reg_wvalid);
                while (1'b1) @(posedge clk) begin
                    reg_bready <= rd[10];
                    if ((reg_bvalid & reg_bready) || j==15) break;
                end
                @(posedge clk) reg_bready <= 1'b0;
            end
            $display("initialize queue[%2d]: req head/tail=%d/%d(%h), depth=%d, base=%h",
                     i, req_queue_head[i], req_queue_tail[i], stream_req_q_head_tails[i*64+:64],
                     stream_req_q_depth[i*8+:8], stream_req_q_bases[i*64+:64]);
            $display("initialize queue[%2d]: cpl head/tail=%d/%d(%h), depth=%d, base=%h",
                     i, cpl_queue_head[i], cpl_queue_tail[i], stream_cpl_q_head_tails[i*64+:64],
                     stream_cpl_q_depth[i*8+:8], stream_cpl_q_bases[i*64+:64]);
        end
    endtask

    task static reset_valid_ch();
        int          i;
        for (i=0; i<CH_NUM; i++) begin
            if (stream_ch_valids[i]) begin
                @(posedge clk) begin
                    reg_awaddr <= REG_BASE + VPMAP_MAX + (i * 64);
                    reg_wdata <= 0;
                    {reg_awvalid, reg_wvalid} <= 2'd3;
                    stream_ch_valids_reg[i] <= 1'b0;
                    stream_ch_valid_num <= stream_ch_valid_num - (~stream_ch_d2d_valids_reg[i] || ENABLE_QUEUE==0);
                    $display("%d [%2d]: stream valid:%1h", $time, i, stream_ch_valid_num-1'b1);
                end
                do @(posedge clk) {reg_awvalid, reg_wvalid} <= {reg_awvalid, reg_wvalid} & ~{reg_awready, reg_wready}; while (reg_awvalid | reg_wvalid);
                while (1'b1) @(posedge clk) begin
                    reg_bready <= rd[10];
                    if (reg_bvalid & reg_bready) break;
                end
                @(posedge clk) reg_bready <= 1'b0;
            end
        end
        for (i=0; i<2000; i++) @(posedge clk);
    endtask

    task static initialize_vpmap();
        int          i, j, k;
        reg [63:0]   cur_vaddr;
        reg [31:0]   cur_remain;
        logic [31:0] wdata;
        int          reg_max = VPMAP_CH_AGGREGATE > 0 ? 4 : 6;
        // initialize registers
        for (i=0; i<CH_NUM; i++) begin
            for (j=0; j<VP_MAP_NUM; j++) begin
                if (j==0) begin
                    @(posedge clk) vaddrs[i] = {rd, rd[31:12], 12'd0};
                    @(posedge clk) begin
                        vsizes[i] = {rd[31:12], 12'd0};
                        cur_vaddr = vaddrs[i];
                        cur_remain = vsizes[i];
                        $display("[%2d]: vaddr: %h vsize: %h", i, vaddrs[i], vsizes[i]);
                    end
                end
                @(posedge clk) begin
                    if (cur_remain) begin
                        vpmap_vsizes[i][j] = cur_remain < {1'b0, rd[30:12], 12'd0} ? cur_remain : {1'b0, rd[30:12], 12'd0};
                        if (j == VP_MAP_NUM - 1) vpmap_vsizes[i][j] = cur_remain;
                        else if (vpmap_vsizes[i][j] > VPMAP_SIZE_MAX) vpmap_vsizes[i][j] = VPMAP_SIZE_MAX;
                        cur_remain = cur_remain - vpmap_vsizes[i][j];
                        vpmap_vaddrs[i][j] = cur_vaddr;
                        vpmap_valids[i][j] = 1'b1;
                        cur_vaddr = cur_vaddr + vpmap_vsizes[i][j];
                    end else begin
                        vpmap_vaddrs[i][j] = 'd0;
                        vpmap_vsizes[i][j] = 'd0;
                        vpmap_valids[i][j] = 1'b0;
                    end
                end
                @(posedge clk) begin
                    vpmap_paddrs[i][j] = {rd, rd[31:12], 12'd0};
                    $display("       %h vaddr: %h vsize: %h paddr: %h", vpmap_valids[i][j],
                             vpmap_vaddrs[i][j], vpmap_vsizes[i][j], vpmap_paddrs[i][j]);
                end
                if (VPMAP_CH_AGGREGATE > 0) begin
                   @(posedge clk) begin
                      reg_awaddr <= REG_BASE + CTRL_MAX + 4'd8;
                      reg_wdata <= i;
                      reg_awvalid <= 1'b1;
                      reg_wvalid <= 1'b1;
                   end
                   do @(posedge clk) {reg_awvalid, reg_wvalid} <= {reg_awvalid, reg_wvalid} & ~{reg_awready, reg_wready}; while (reg_awvalid | reg_wvalid);
                   do @(posedge clk) reg_bready <= rd[10]; while (~reg_bvalid | ~reg_bready);
                   @(posedge clk) reg_bready <= 1'b0;
                end
                if (vpmap_vsizes[i][j]) begin
                    for (k=0; k<reg_max; k++) begin
                        @(posedge clk) begin
                            if (VPMAP_CH_AGGREGATE > 0) begin
                                reg_awaddr <= REG_BASE + (j * 32) + (k * 4);
                                case(k)
                                  0: wdata = vpmap_vaddrs[i][j][43:12];
                                  1: wdata = {vpmap_paddrs[i][j][23:12], vpmap_vaddrs[i][j][63:44]};
                                  2: wdata = vpmap_paddrs[i][j][55:24];
                                  3: wdata = {3'd0, vpmap_valids[i][j], vpmap_vsizes[i][j][31:12], vpmap_paddrs[i][j][63:56]};
                                endcase
                            end else begin
                                reg_awaddr <= REG_BASE + (i * VP_MAP_NUM * 32) + (j * 32) + (k * 4);
                                case(k)
                                  0: wdata = vpmap_vaddrs[i][j][31:0];
                                  1: wdata = vpmap_vaddrs[i][j][63:32];
                                  2: wdata = vpmap_paddrs[i][j][31:0];
                                  3: wdata = vpmap_paddrs[i][j][63:32];
                                  4: wdata = vpmap_vsizes[i][j];
                                  5: wdata = {'d0 | vpmap_valids[i][j]};
                                endcase
                            end
                           reg_wdata <= wdata;
                           {reg_awvalid, reg_wvalid} <= 2'd3;
                        end
                        do @(posedge clk) {reg_awvalid, reg_wvalid} <= {reg_awvalid, reg_wvalid} & ~{reg_awready, reg_wready}; while (reg_awvalid | reg_wvalid);
                        do @(posedge clk) begin
                            reg_bready <= rd[10];
                        end while (~reg_bvalid | ~reg_bready);
                        @(posedge clk) reg_bready <= 1'b0;
                    end
                end else begin
                    @(posedge clk) begin
                        if (VPMAP_CH_AGGREGATE > 0) begin
                            reg_awaddr <= REG_BASE + (j * 32) + 12;
                            reg_wdata <= 32'h0;
                        end else begin
                            reg_awaddr <= REG_BASE + (i * VP_MAP_NUM * 32) + (j * 32) + 20;
                            reg_wdata <= 32'h0;
                        end
                        {reg_awvalid, reg_wvalid} <= 2'd3;
                    end
                    do @(posedge clk) {reg_awvalid, reg_wvalid} <= {reg_awvalid, reg_wvalid} & ~{reg_awready, reg_wready}; while (reg_awvalid | reg_wvalid);
                    while (1'b1) @(posedge clk) begin
                        reg_bready <= rd[10];
                        if (reg_bvalid & reg_bready) break;
                    end
                    @(posedge clk) reg_bready <= 1'b0;
                end
            end
        end
    endtask

    task static add_request();
        int i, j;
        reg [15:0] counts;
        logic [CH_NUM_LOG-1:0] ch;
        reg [15:0]             queue_idx[0:CH_NUM-1];
        logic [15:0]           queue_idx_next;
        logic [63:0]           transfer_addr;
        logic [31:0]           transfer_size;

        @(posedge clk) begin
            counts = 'd0;
            for (i=0; i<CH_NUM; i++) queue_idx[i] = 16'd0 | req_queue_head[i];
        end
        while (counts < TRANSFER_NUM) @(posedge clk) begin
            ch = rd[REQ_CH_BASE+:CH_NUM_LOG];
            queue_idx_next = queue_idx[ch] + 1'b1 >= stream_req_q_depth[ch*8+:8] ? 'd0 : (16'd0 | queue_idx[ch]) + 1'b1;
            if (stream_ch_valids[ch] && (~stream_ch_d2d_valids[ch] || ENABLE_QUEUE==0) &&
                &rd[ADD_REQ_BASE+:ADD_REQ_BITS] && req_queue_stat[ch][queue_idx_next] === 'd0 &&
                frame_info_wpos[6:0] + 1'b1 != frame_info_rpos[6:0]) begin
                transfer_addr = vaddrs[ch] + {rd[29:2], 2'd0};
                transfer_size = {rd[31:2], 2'd0};
                if (transfer_addr < vaddrs[ch] + vsizes[ch]) begin
                    transfer_size = transfer_addr + transfer_size < vaddrs[ch] + vsizes[ch] ? transfer_size : vaddrs[ch] + vsizes[ch] - transfer_addr;
                    req_queue_addr[ch][queue_idx[ch]] <= transfer_addr;
                    req_queue_size[ch][queue_idx[ch]] <= transfer_size;
                    req_queue_stat[ch][queue_idx[ch]] <= 32'd2;
                    queue_idx[ch] <= queue_idx_next;
                    req_queue_head[ch] <= queue_idx_next;
                    counts = counts + 1'b1;
                    $display("%d [%2d]: request vaddr:%h vsize:%h queue_idx:%h->%h, frame_info:%h", $time, ch,
                             transfer_addr, transfer_size, queue_idx[ch], queue_idx_next, {rd[3:0], rd[31:6], 2'd0});
                    if (ENABLE_FRAME_INFO_OUT) begin
                        frame_info_out_sizes[ch][out_size_wpos[ch]] <= transfer_size;
                        out_size_wpos[ch] <= out_size_wpos[ch] + |transfer_size;
                    end
                    if (DISABLE_FRAME_INFO) begin
                        req_queue_info_size[ch][queue_idx[ch]] <= VPMAP_SIZE_MAX;
                        frame_info_sizes[frame_info_wpos] <= VPMAP_SIZE_MAX;
                    end else begin
                        req_queue_info_size[ch][queue_idx[ch]] <= {rd[3:0], rd[31:6], 2'd0};
                        frame_info_sizes[frame_info_wpos] <= {rd[3:0], rd[31:6], 2'd0};
                        frame_info_chs[frame_info_wpos] <= ch;
                        frame_info_wpos <= frame_info_wpos + 1'b1;
                    end
                    req_q_doorbells[ch] <= 1'b1;
                end else if (ENABLE_OOR > 0) begin
                    req_queue_addr[ch][queue_idx[ch]] <= transfer_addr;
                    req_queue_size[ch][queue_idx[ch]] <= transfer_size;
                    req_queue_stat[ch][queue_idx[ch]] <= 32'd3;
                    queue_idx[ch] <= queue_idx_next;
                    req_queue_head[ch] <= queue_idx_next;
                    counts = counts + 1'b1;
                    $display("%d [%2d]: request vaddr:%h vsize:%h queue_idx:%h->%h, frame_info:%h OOR", $time, ch,
                             transfer_addr, transfer_size, queue_idx[ch], queue_idx_next, {rd[3:0], rd[31:6], 2'd0});
                    if (DISABLE_FRAME_INFO) begin
                        req_queue_info_size[ch][queue_idx[ch]] <= VPMAP_SIZE_MAX;
                        frame_info_sizes[frame_info_wpos] <= VPMAP_SIZE_MAX;
                    end else begin
                        req_queue_info_size[ch][queue_idx[ch]] <= {rd[3:0], rd[31:6], 2'd0};
                        frame_info_sizes[frame_info_wpos] <= {rd[3:0], rd[31:6], 2'd0};
                        frame_info_chs[frame_info_wpos] <= ch;
                        frame_info_wpos <= frame_info_wpos + 1'b1;
                    end
                    $display("@@@ [%2d]: %h %h", ch, transfer_addr, vaddrs[ch] + {rd[29:2], 2'd0});
                end
            end
        end
    endtask

    task static transfer_completes();
        int i, j;
        reg transfer_cpl_wait;
        reg [15:0] counts = 0;
        logic finished;
        while (1) @(posedge clk) begin
            finished = 1'b1;
            for (i=0; i<CH_NUM; i++) begin
                for (j=0; j<stream_req_q_depth[i*8+:8]; j++) begin
                    if (stream_ch_valids[i] && req_queue_stat[i][j] !== 'd0) begin
                        finished = 1'b0;
                        $display("%d: ch:%2d, stat[%d]:%d", $time, i, j, req_queue_stat[i][j]);
                        break;
                    end
                end
            end
            if (finished) break;
            counts = counts + 1'b1;
            if (counts > INCOMPLETE_THRESHOLD) $fatal(2, "transfer incompleted\n");
        end // while (1)
    endtask

    initial begin
        int i;
        w_initializing = 1'b1;
        while (resetn !== 1'b1) @(posedge clk);
        case(TEST_CASE)
            0 : begin
                initialize_queues;
                initialize_vpmap;
                w_initializing = 1'b0;
                add_request;
                transfer_completes;
            end
            1 : begin
                initialize_queues;
                initialize_vpmap;
                w_initializing = 1'b0;
                add_request;
                transfer_completes;
                w_initializing = 1'b1;
                reset_valid_ch;
                initialize_queues;
                initialize_vpmap;
                w_initializing = 1'b0;
                add_request;
                transfer_completes;
                w_initializing = 1'b1;
                reset_valid_ch;
                initialize_queues;
                initialize_vpmap;
                w_initializing = 1'b0;
                add_request;
                transfer_completes;
                w_initializing = 1'b1;
                reset_valid_ch;
                initialize_queues;
                initialize_vpmap;
                w_initializing = 1'b0;
                add_request;
                transfer_completes;
            end
            default: begin
                $fatal(2, "unknown test case");
            end
        endcase

        $finish();
    end

endmodule

module test_core_simple();

    tb_core tb();

endmodule

module test_core_simple2();

    tb_core #(
        .ADD_REQ_BASE ( 20 )
    ) tb();

endmodule

module test_core_queue_full();

    tb_core #(
        .TRANSFER_NUM ( 1000 ),
        .DESC_BASE_FIFO_DL ( 3 ),
        .CPL_START_DELAY ( 250000 )
    ) tb();

endmodule

module test_core_restart();

    tb_core #(
        .TEST_CASE ( 1 ),
        .FRAME_INFO_FIFO_DL ( 7 ),
        .ENABLE_QUEUE_PATTERN ( 1 ),
        .ENABLE_OOR ( 1 ),
        .QUEUE_PATTERN ( 8'd1 ),
        .ADD_REQ_BASE ( 20 )
    ) tb();

endmodule

module test_core_without_frame_info_restart();

    tb_core #(
        .TEST_CASE ( 1 ),
        .DISABLE_FRAME_INFO ( 1 ),
        .ENABLE_QUEUE_PATTERN ( 1 ),
        .ENABLE_OOR ( 1 ),
        .QUEUE_PATTERN ( 8'd1 ),
        .ADD_REQ_BASE ( 20 )
    ) tb();

endmodule

module test_core_with_frame_info_out();

    tb_core #(
        .TEST_CASE ( 1 ),
        .DISABLE_FRAME_INFO ( 1 ),
        .ENABLE_FRAME_INFO_OUT ( 1 ),
        .FRAME_INFO_READY_BITS ( 6 ),
        .ADD_REQ_BASE ( 20 ),
        .INCOMPLETE_THRESHOLD ( 20000 )
    ) tb();

endmodule

module test_core_simple_large_vpmap();

    tb_core #(
        .VP_MAP_NUM_LOG ( 8 )
    ) tb ();

endmodule

module test_core_simple_d2d();

    tb_core #(
        .ADD_REQ_BASE ( 20 ),
        .ENABLE_QUEUE ( 1 ),
        .ENABLE_D2D ( 1 )
    ) tb();

endmodule
