/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_switch #(
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
    parameter RQBASE = 128,
    parameter RCBASE = 96,
    parameter QEW = 32,
    parameter QUEUE_CHECK_TAG = 8'd99,
    parameter QUEUE_READ_TAG = 8'd98,
    parameter DESC_LEN_BYTE_LOG = 6,
    parameter CH_VALID_BITS = 1,
    parameter REQ_VALID_BITS = 1,
    parameter CORE_REQ_VALID_BITS = 1,
    parameter FRAME_INFO_OUT_BITS = 1,
    parameter MAX_REQ_NUM = 100,
    parameter CH_BASE = 0,
    parameter CH_BASE_RX = 128,
    parameter DISABLE_FRAME_INFO = 0,
    parameter NO_RC_BP = 0,
    parameter ENABLE_INVALID_CYCLE = 0,
    parameter IGNORE_RC_READY = 0,
    parameter ENABLE_FRAME_INFO_OUT = 0,
    parameter DESC_DATA_POS = 32,
    parameter DESC_CMD_VALID = 17,
    parameter TEST_CASE = 0
    ) ();

    wire clk, resetn;
    wire [31:0] rd;
    clk_reset clk_reset(
        .clk ( clk ),
        .resetn ( resetn ),
        .rd ( rd )
    );

    localparam CH_NUM = 1 << CH_NUM_LOG;
    localparam DESC_LEN_DW = 1 << (DESC_LEN_BYTE_LOG - 2);
    localparam REQ_VALID_BITS_MOD = REQ_VALID_BITS > 0 ? REQ_VALID_BITS : 1;

    reg [DESC_RQ_DW-1:0] i_rd_data;
    reg                  i_rd_last;
    reg                  i_rd_valid;
    wire                 i_rd_ready;
    reg [DESC_RQ_DW-1:0] i_wr_data;
    reg                  i_wr_last;
    reg                  i_wr_valid;
    wire                 i_wr_ready;

    wire [DESC_RQ_DW-1:0] o_rd_data;
    wire                  o_rd_last;
    wire                  o_rd_valid;
    reg                   o_rd_ready;
    wire [DESC_RQ_DW-1:0] o_wr_data;
    wire                  o_wr_last;
    wire                  o_wr_valid;
    reg                   o_wr_ready;

    reg [DESC_RC_DW-1:0]  i_rc_data;
    reg [DESC_RC_DK-1:0]  i_rc_keep;
    reg [DESC_RC_USER-1:0] i_rc_user;
    reg                    i_rc_last;
    reg                    i_rc_valid;
    wire                   i_rc_ready;

    wire [DESC_RC_DW-1:0]  o_rc_data;
    wire [DESC_RC_DK-1:0]  o_rc_keep;
    wire [DESC_RC_USER-1:0] o_rc_user;
    wire                    o_rc_last;
    wire                    o_rc_valid;
    reg                     o_rc_ready;

    reg [RQ_DW-1:0]         queue_check_data;
    reg [RQ_DK-1:0]         queue_check_keep;
    reg                     queue_check_valid;
    wire                    queue_check_ready;
    reg [RQ_DW-1:0]         queue_update_data;
    reg [RQ_DK-1:0]         queue_update_keep;
    reg                     queue_update_valid;
    wire                    queue_update_ready;
    reg [RQ_DW-1:0]         queue_rd_data;
    reg [RQ_DK-1:0]         queue_rd_keep;
    reg                     queue_rd_valid;
    wire                    queue_rd_ready;
    reg [RQ_DW-1:0]         queue_wr_data;
    reg [RQ_DK-1:0]         queue_wr_keep;
    reg                     queue_wr_valid;
    wire                    queue_wr_ready;

    wire [RC_DW-1:0]         queue_check_res_data;
    wire                     queue_check_res_valid;
    wire [RC_DW-1:0]         queue_rd_res_data;
    wire                     queue_rd_res_valid;

    wire [DESC_RQ_DW-1:0]    desc_req_data;
    wire [DESC_RQ_DK-1:0]    desc_req_keep;
    wire                     desc_req_last;
    wire                     desc_req_valid;
    reg                      desc_req_ready;
    wire [DESC_RQ_DW-1:0]    desc_cpl_data;
    wire [DESC_RQ_DK-1:0]    desc_cpl_keep;
    wire                     desc_cpl_last;
    wire                     desc_cpl_valid;
    reg                      desc_cpl_ready;

    reg [DESC_RC_DW-1:0]    desc_out_data;
    reg [DESC_RC_DK-1:0]    desc_out_keep;
    reg                     desc_out_last;
    reg                     desc_out_valid;
    wire                    desc_out_ready;

   reg [31:0]               frame_info_in_size;
   reg [CH_NUM_LOG-1:0]     frame_info_in_ch;
   reg                      frame_info_in_valid;
   wire                     frame_info_in_ready;
   wire [31:0]              frame_info_out_size;
   wire [CH_NUM_LOG-1:0]    frame_info_out_ch;
   wire                     frame_info_out_valid;
   reg                      frame_info_out_ready;

    reg [CH_NUM*64-1:0]     stream_desc_bases;
    reg [CH_NUM*64-1:0]     stream_desc_ends;
    reg [CH_NUM-1:0]        stream_valids;

    initial begin
        i_rd_data = 'd0;
        i_rd_last = 'b0;
        i_rd_valid = 'b0;
        i_wr_data = 'd0;
        i_wr_last = 'b0;
        i_wr_valid = 'b0;
        i_rc_data = 'd0;
        i_rc_keep = 'd0;
        i_rc_user = 'd0;
        i_rc_last = 'b0;
        i_rc_valid = 'b0;
        o_rc_ready = 'b0;
        o_rd_ready = 'b0;
        o_wr_ready = 'b0;

        queue_check_data = 'd0;
        queue_check_keep = 'd0;
        queue_check_valid = 'b0;
        queue_update_data = 'd0;
        queue_update_keep = 'd0;
        queue_update_valid = 'b0;
        queue_rd_data = 'd0;
        queue_rd_keep = 'd0;
        queue_rd_valid = 'b0;
        queue_wr_data = 'd0;
        queue_wr_keep = 'd0;
        queue_wr_valid = 'b0;
        desc_req_ready = 'b0;
        desc_cpl_ready = 'b0;
        desc_out_data = 'd0;
        desc_out_keep = 'd0;
        desc_out_last = 'd0;
        desc_out_valid = 'b0;

        stream_desc_bases = 'd0;
        stream_desc_ends = 'd0;
        stream_valids = 'd0;

        frame_info_in_valid = 1'b0;
        frame_info_out_ready = 1'b1;
    end

    stream_engine_rr_switch #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .DESC_RQ_DW ( DESC_RQ_DW ),
        .DESC_RQ_DK ( DESC_RQ_DK ),
        .DESC_RC_DW ( DESC_RC_DW ),
        .DESC_RC_DK ( DESC_RC_DK ),
        .DESC_RC_USER ( DESC_RC_USER ),
        .RQ_DW ( RQ_DW ),
        .RQ_DK ( RQ_DK ),
        .RC_DW ( RC_DW ),
        .RC_DK ( RC_DK ),
        .CH_BASE ( CH_BASE ),
        .DISABLE_FRAME_INFO ( DISABLE_FRAME_INFO ),
        .ENABLE_FRAME_INFO_OUT ( ENABLE_FRAME_INFO_OUT ),
        .QUEUE_CHECK_TAG ( QUEUE_CHECK_TAG ),
        .QUEUE_READ_TAG ( QUEUE_READ_TAG )
    ) dut (
        .stream_desc_bases ( stream_desc_bases ),
        .stream_desc_ends ( stream_desc_ends ),
        .stream_valids ( stream_valids ),

        .i_rd_data ( i_rd_data ),
        .i_rd_last ( i_rd_last ),
        .i_rd_valid ( i_rd_valid ),
        .i_rd_ready ( i_rd_ready ),
        .i_wr_data ( i_wr_data ),
        .i_wr_last ( i_wr_last ),
        .i_wr_valid ( i_wr_valid ),
        .i_wr_ready ( i_wr_ready ),
        .i_rc_data ( i_rc_data ),
        .i_rc_keep ( i_rc_keep ),
        .i_rc_user ( i_rc_user ),
        .i_rc_last ( i_rc_last ),
        .i_rc_valid ( i_rc_valid ),
        .i_rc_ready ( i_rc_ready ),
        .o_rc_data ( o_rc_data ),
        .o_rc_keep ( o_rc_keep ),
        .o_rc_user ( o_rc_user ),
        .o_rc_last ( o_rc_last ),
        .o_rc_valid ( o_rc_valid ),
        .o_rc_ready ( o_rc_ready ),

        .o_rd_data ( o_rd_data ),
        .o_rd_last ( o_rd_last ),
        .o_rd_valid ( o_rd_valid ),
        .o_rd_ready ( o_rd_ready ),
        .o_wr_data ( o_wr_data ),
        .o_wr_last ( o_wr_last ),
        .o_wr_valid ( o_wr_valid ),
        .o_wr_ready ( o_wr_ready ),

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
        .queue_wr_data ( queue_wr_data ),
        .queue_wr_keep ( queue_wr_keep ),
        .queue_wr_valid ( queue_wr_valid ),
        .queue_wr_ready ( queue_wr_ready ),

        .queue_check_res_data ( queue_check_res_data ),
        .queue_check_res_valid ( queue_check_res_valid ),
        .queue_rd_res_data ( queue_rd_res_data ),
        .queue_rd_res_valid ( queue_rd_res_valid ),

        .desc_req_data ( desc_req_data ),
        .desc_req_keep ( desc_req_keep ),
        .desc_req_last ( desc_req_last ),
        .desc_req_valid ( desc_req_valid ),
        .desc_req_ready ( desc_req_ready ),
        .desc_cpl_data ( desc_cpl_data ),
        .desc_cpl_keep ( desc_cpl_keep ),
        .desc_cpl_last ( desc_cpl_last ),
        .desc_cpl_valid ( desc_cpl_valid ),
        .desc_cpl_ready ( desc_cpl_ready ),

        .desc_out_data ( desc_out_data ),
        .desc_out_keep ( desc_out_keep ),
        .desc_out_last ( desc_out_last ),
        .desc_out_valid ( desc_out_valid ),
        .desc_out_ready ( desc_out_ready ),

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

    // ready signal
    always @(posedge clk) begin
        if (~resetn) begin
            o_rd_ready <= 1'b0;
            o_wr_ready <= 1'b0;
            desc_req_ready <= 1'b0;
            desc_cpl_ready <= 1'b0;
            o_rc_ready <= 1'b0;
        end else begin
            o_rd_ready <= rd[22];
            o_wr_ready <= rd[29];
            desc_req_ready <= rd[23];
            desc_cpl_ready <= rd[24];
            o_rc_ready <= NO_RC_BP ? 1'b1 : rd[21];
        end
    end

    task static initialize_desc_range();
        int i;
        for (i=0; i<CH_NUM; i++) begin
            @(posedge clk) begin
                stream_desc_bases[i*64+:64] <= {rd, rd, 2'd0};
                stream_desc_ends[i*64+:64] <= {rd, rd, 2'd0} + {rd[9:0] | 10'h040, {DESC_LEN_BYTE_LOG{1'b0}}};
            end
            @(posedge clk) begin
                stream_valids[i] <= &rd[2+:CH_VALID_BITS];
                $display("%d: [%2d]: stream valid: %1d", $time, i, &rd[2+:CH_VALID_BITS]);
            end
        end
    endtask

    // fdma read req
    reg [7:0]            read_req_wpos, read_req_rpos;
    reg [DESC_RQ_DW-1:0] read_req_data_saved[0:255];

    reg [7:0]            desc_req_wpos, desc_req_rpos;
    reg [DESC_RQ_DW-1:0] desc_req_data_saved[0:255];

    initial begin
        read_req_wpos = 'd0;
        read_req_rpos = 'd0;
        desc_req_wpos = 'd0;
        desc_req_rpos = 'd0;
    end

    task static fdma_read_req_issue_check();
        int i;
        int icount = 0;
        int count = 0;
        logic [DESC_RQ_DW-1:0] cur_read_req_data;
        logic [CH_NUM_LOG-1:0] cur_ch;
        logic [63:0]           cur_addr;
        logic [63:0]           cur_offset;
        logic [10:0]           cur_len;
        logic [7:0]            cur_tag;
        logic [7:0]            next_read_wpos, next_desc_wpos;
        while (count < MAX_REQ_NUM / REQ_VALID_BITS_MOD) begin
            @(posedge clk) begin
                // issue
                cur_ch = rd[10+:CH_NUM_LOG];
                cur_addr = stream_desc_bases[cur_ch*64+:64];
                cur_offset = rd % (stream_desc_ends[cur_ch*64+:64] - stream_desc_bases[cur_ch*64+:64]);
                cur_addr = cur_addr + cur_offset;
                cur_len = DESC_LEN_DW;
                cur_tag = CH_BASE + cur_ch;
                cur_read_req_data = {'d0,
                                     cur_tag,
                                     8'd0, 8'd0, 1'b0, 4'd0, // req bus num, req func, poisoned req, ,request type
                                     cur_len, cur_addr};
                next_read_wpos = read_req_wpos + 1'b1;
                next_desc_wpos = desc_req_wpos + 1'b1;
                if (next_read_wpos !== read_req_rpos && next_desc_wpos !== desc_req_rpos &&
                    &rd[30-:REQ_VALID_BITS_MOD] && (~i_rd_valid || i_rd_ready)) begin
                    i_rd_data <= cur_read_req_data;
                    i_rd_last <= 1'b1;
                    i_rd_valid <= icount < MAX_REQ_NUM / REQ_VALID_BITS_MOD;
                    icount = icount < MAX_REQ_NUM / REQ_VALID_BITS_MOD ? icount + 1 : icount;
                    if (!stream_valids[cur_ch]) begin
                        read_req_data_saved[read_req_wpos] <= cur_read_req_data;
                        read_req_wpos <= next_read_wpos;
                    end else begin
                        desc_req_data_saved[desc_req_wpos] <= cur_read_req_data;
                        desc_req_wpos <= next_desc_wpos;
                    end
                    $display("%d read req [%3d]: %h %1h", $time,
                             cur_ch, cur_read_req_data, stream_valids[cur_ch]);
                end else begin
                    i_rd_valid <= i_rd_valid & ~i_rd_ready;
                end
                // check
                if (o_rd_valid & o_rd_ready) begin
                    if (CH_BASE <= o_rd_data[96+:8] && o_rd_data[96+:8] < CH_BASE + CH_NUM &&
                        !stream_valids[o_rd_data[96+:8] - CH_BASE]) begin
                        if (read_req_data_saved[read_req_rpos] !== o_rd_data || ~o_rd_last) begin
                            $error("%d read req through fail[%3d]: %h %h %1h", $time, read_req_rpos, o_rd_data, read_req_data_saved[read_req_rpos], o_rd_last);
                        end else begin
                            $display("%d read req through [%3d]: %h %h %1h", $time, read_req_rpos, o_rd_data, read_req_data_saved[read_req_rpos], o_rd_last);
                        end
                        read_req_rpos <= read_req_rpos + 1'b1;
                        if (o_rd_last) count = count + 1;
                    end
                end
                if (desc_req_valid & desc_req_ready) begin
                    if (CH_BASE <= desc_req_data[96+:8] && desc_req_data[96+:8] < CH_BASE + CH_NUM &&
                        stream_valids[desc_req_data[96+:8] - CH_BASE]) begin
                        if (desc_req_data_saved[desc_req_rpos] !== desc_req_data || ~desc_req_last ||
                            desc_req_keep !== 'hf) begin
                            $error("%d desc req through fail[%3d]: %3d %h %h %1h %h", $time,
                                   desc_req_rpos, desc_req_data[96+:8] - CH_BASE, desc_req_data, desc_req_data_saved[desc_req_rpos], desc_req_last, desc_req_keep);
                        end else begin
                            $display("%d desc req through[%3d]: %3d %h %h %1h %h", $time,
                                     desc_req_rpos, desc_req_data[96+:8] - CH_BASE, desc_req_data, desc_req_data_saved[desc_req_rpos], desc_req_last, desc_req_keep);
                        end
                        desc_req_rpos <= desc_req_rpos + 1'b1;
                        if (desc_req_last) count = count + 1;
                    end
                end
            end
        end
    endtask

    // core read req
    reg [7:0]            queue_check_req_wpos, queue_check_req_rpos;
    reg [RQ_DW-1:0]      queue_check_req_data_saved[0:255];
    reg [7:0]            queue_rd_req_wpos, queue_rd_req_rpos;
    reg [RQ_DW-1:0]      queue_rd_req_data_saved[0:255];

    initial begin
        queue_check_req_wpos = 'd0;
        queue_check_req_rpos = 'd0;
        queue_rd_req_wpos = 'd0;
        queue_rd_req_rpos = 'd0;
    end

    task static core_read_req_issue_check();
        int i;
        int icount = 0;
        int count = 0;
        logic [RQ_DW-1:0] cur_read_req_data;
        logic [CH_NUM_LOG-1:0] cur_ch;
        logic                  cur_port;
        logic [63:0]           cur_addr;
        logic [63:0]           cur_offset;
        logic [10:0]           cur_len;
        logic [7:0]            cur_tag;
        logic [7:0]            next_check_wpos, next_rd_wpos;
        while (count < MAX_REQ_NUM / CORE_REQ_VALID_BITS) begin
            @(posedge clk) begin
                // issue
                cur_port = rd[11];
                cur_ch = rd[12+:CH_NUM_LOG];
                cur_addr = {rd, rd, 2'd0};
                cur_len = cur_port ? QEW/4 : 2; // queue element : head & tail
                cur_tag = cur_port ? QUEUE_READ_TAG : QUEUE_CHECK_TAG;
                cur_read_req_data = {'d0,
                                     cur_tag,
                                     8'd0, 8'd0, 1'b0, 4'd0, // req bus num, req func, poisoned req, ,request type
                                     cur_len, cur_addr};
                next_check_wpos = queue_check_req_wpos + 1'b1;
                next_rd_wpos = queue_rd_req_wpos + 1'b1;
                for (i=0; i<2; i++) begin
                    if (next_check_wpos !== queue_check_req_rpos && next_rd_wpos !== queue_rd_req_rpos &&
                        &rd[28-:CORE_REQ_VALID_BITS] && i == cur_port && stream_valids[cur_ch] &&
                        (i==0 ? (~queue_check_valid || queue_check_ready) : (~queue_rd_valid || queue_rd_ready))) begin
                        if (i==0) begin
                            queue_check_req_data_saved[queue_check_req_wpos] <= cur_read_req_data;
                            queue_check_req_wpos <= next_check_wpos;
                            queue_check_data <= cur_read_req_data;
                            queue_check_keep <= 'hf;
                            queue_check_valid <= icount < MAX_REQ_NUM / CORE_REQ_VALID_BITS;
                        end else begin
                            queue_rd_req_data_saved[queue_rd_req_wpos] <= cur_read_req_data;
                            queue_rd_req_wpos <= next_rd_wpos;
                            queue_rd_data <= cur_read_req_data;
                            queue_rd_keep <= 'hf;
                            queue_rd_valid <= icount < MAX_REQ_NUM / CORE_REQ_VALID_BITS;
                        end
                        $display("%d %s req [%3d]: %h %1h", $time, cur_port ? "queue rd" : "queue check",
                                 cur_ch, cur_read_req_data, stream_valids[cur_ch]);
                        icount = icount < MAX_REQ_NUM / CORE_REQ_VALID_BITS ? icount + 1 : icount;
                    end else begin
                        if (i==0) begin
                            queue_check_valid <= queue_check_valid & ~queue_check_ready;
                        end else begin
                            queue_rd_valid <= queue_rd_valid & ~queue_rd_ready;
                        end
                    end
                end
                // check
                if (o_rd_valid & o_rd_ready) begin
                    if (o_rd_data[96+:8] == QUEUE_CHECK_TAG) begin
                        if (queue_check_req_data_saved[queue_check_req_rpos] !== o_rd_data || ~o_rd_last) begin
                            $error("%d queue check req through fail[%3d]: %h %h %1h", $time,
                                   queue_check_req_rpos, o_rd_data, queue_check_req_data_saved[queue_check_req_rpos], o_rd_last);
                        end else begin
                            $display("%d queue check req through [%3d]: %h %h %1h", $time,
                                   queue_check_req_rpos, o_rd_data, queue_check_req_data_saved[queue_check_req_rpos], o_rd_last);
                        end
                        queue_check_req_rpos <= queue_check_req_rpos + 1'b1;
                        count = count + 1;
                    end
                    if (o_rd_data[96+:8] == QUEUE_READ_TAG) begin
                        if (queue_rd_req_data_saved[queue_rd_req_rpos] !== o_rd_data || ~o_rd_last) begin
                            $error("%d queue rd req through fail[%3d]: %h %h %1h", $time,
                                   queue_rd_req_rpos, o_rd_data, queue_rd_req_data_saved[queue_rd_req_rpos], o_rd_last);
                        end else begin
                            $display("%d queue rd req through[%3d]: %h %h %1h", $time,
                                     queue_rd_req_rpos, o_rd_data, queue_rd_req_data_saved[queue_rd_req_rpos], o_rd_last);
                        end
                        queue_rd_req_rpos <= queue_rd_req_rpos + 1'b1;
                        count = count + 1;
                    end
                end
            end
        end
    endtask

    // fdma write req
    reg [7:0]            write_req_wpos, write_req_rpos;
    reg [DESC_RQ_DW-1:0] write_req_data_saved[0:255];
    reg                  write_req_last_saved[0:255];

    reg [7:0]            desc_cpl_wpos, desc_cpl_rpos;
    reg [DESC_RQ_DW-1:0] desc_cpl_data_saved[0:255];
    reg [DESC_RQ_DK-1:0] desc_cpl_keep_saved[0:255];
    reg                  desc_cpl_last_saved[0:255];

    initial begin
        write_req_wpos = 'd0;
        write_req_rpos = 'd0;
        desc_cpl_wpos = 'd0;
        desc_cpl_rpos = 'd0;
    end

    task static fdma_write_req_issue_check();
        int i;
        int icount = 0;
        int count = 0;
        logic [DESC_RQ_DW-1:0] cur_write_req_data;
        logic                  cur_write_req_last;
        logic [DESC_RQ_DW-1:0] cur_write_req_data_for_save;
        logic [DESC_RQ_DK-1:0] cur_write_req_keep_for_save;
        logic                  cur_write_req_last_for_save;
        logic [CH_NUM_LOG-1:0] cur_ch;
        logic [63:0]           cur_addr;
        logic [63:0]           cur_offset;
        logic [10:0]           cur_len;
        logic [7:0]            next_write_wpos, next_cpl_wpos;
        logic                  cur_start;
        int write_req_ch = -1;
        int desc_cpl_ch = -1;
        @(posedge clk) cur_start = 1'b1;
        while (count < MAX_REQ_NUM / REQ_VALID_BITS_MOD) begin
            @(posedge clk) begin
                // issue
                if (cur_start) begin
                    cur_ch = rd[13+:CH_NUM_LOG];
                    cur_addr = stream_desc_bases[cur_ch*64+:64];
                    cur_offset = rd % (stream_desc_ends[cur_ch*64+:64] - stream_desc_bases[cur_ch*64+:64]);
                    cur_addr = cur_addr + cur_offset;
                    cur_len = DESC_LEN_DW;
                    cur_write_req_data = {'d0,
                                          8'd0, // tag
                                          8'd0, 8'd0, 1'b0, 4'd1, // req bus num, req func, poisoned req, ,request type
                                          cur_len, cur_addr};
                    cur_len = cur_len + DESC_RQ_DK;
                end else begin
                    for (int i=0; i<DESC_RQ_DW; i=i+32) begin
                        cur_write_req_data[i+:32] = rd ^ (i*201);
                    end
                end
                next_write_wpos = write_req_wpos + 1'b1;
                next_cpl_wpos = desc_cpl_wpos + 1'b1;
                cur_write_req_last = (cur_len <= DESC_RQ_DK);
                if (next_write_wpos !== write_req_rpos && ((next_cpl_wpos + 1'b1) & 'hff) !== desc_cpl_rpos &&
                    &rd[30-:REQ_VALID_BITS_MOD] && (~i_wr_valid || i_wr_ready)) begin
                    i_wr_data <= cur_write_req_data;
                    i_wr_valid <= icount < MAX_REQ_NUM / REQ_VALID_BITS_MOD;
                    i_wr_last <= cur_write_req_last;
                    if (!stream_valids[cur_ch]) begin
                        write_req_data_saved[write_req_wpos] <= cur_write_req_data;
                        write_req_last_saved[write_req_wpos] <= cur_write_req_last;
                        write_req_wpos <= next_write_wpos;
                        $display("%d write req [%3d]: %h %1d %1h", $time,
                                 cur_ch, cur_write_req_data, cur_write_req_last, stream_valids[cur_ch]);
                    end else begin
                        if (cur_start) begin
                            cur_write_req_keep_for_save = 'hf;
                            cur_write_req_last_for_save = 1'b0;
                            cur_write_req_data_for_save = cur_write_req_data;
                        end else begin
                            cur_write_req_keep_for_save = (('d1 << (cur_len + RQBASE/32))-1);
                            cur_write_req_last_for_save = cur_len <= DESC_RQ_DK - RQBASE/32;
                            cur_write_req_data_for_save = {cur_write_req_data, cur_write_req_data_for_save[RQBASE-1:0]};

                            desc_cpl_data_saved[desc_cpl_wpos] <= cur_write_req_data_for_save;
                            desc_cpl_keep_saved[desc_cpl_wpos] <= cur_write_req_keep_for_save;
                            desc_cpl_last_saved[desc_cpl_wpos] <= cur_write_req_last_for_save;
                            desc_cpl_wpos <= next_cpl_wpos;
                            $display("%d write cpl [%3d]: save %h %h %1d %1h %d", $time,
                                     cur_ch, cur_write_req_data_for_save, cur_write_req_keep_for_save, cur_write_req_last_for_save, stream_valids[cur_ch], cur_len);
                            cur_write_req_data_for_save = {'d0, cur_write_req_data[DESC_RQ_DW-1-:RQBASE]};
                            if (cur_write_req_last & ~cur_write_req_last_for_save) begin
                                cur_write_req_keep_for_save = (('d1 << (cur_len + RQBASE/32 - DESC_RQ_DK))-1);
                                cur_write_req_last_for_save = cur_len <= DESC_RQ_DK * 2 - RQBASE/32;

                                desc_cpl_data_saved[next_cpl_wpos] <= cur_write_req_data_for_save;
                                desc_cpl_keep_saved[next_cpl_wpos] <= cur_write_req_keep_for_save;
                                desc_cpl_last_saved[next_cpl_wpos] <= cur_write_req_last_for_save;
                                desc_cpl_wpos <= next_cpl_wpos + 1'b1;
                                $display("%d write cpl [%3d]: save %h %h %1d %1h", $time,
                                         cur_ch, cur_write_req_data_for_save, cur_write_req_keep_for_save, cur_write_req_last_for_save, stream_valids[cur_ch]);
                            end
                        end
                        $display("%d write cpl [%3d]: %h %1d %1h", $time,
                                 cur_ch, cur_write_req_data, cur_write_req_last, stream_valids[cur_ch]);
                    end
                    if (cur_write_req_last) begin
                        icount = icount < MAX_REQ_NUM / REQ_VALID_BITS_MOD ? icount + 1 : icount;
                        cur_start = 1'b1;
                    end else begin
                        cur_len = cur_len - DESC_RQ_DK;
                        cur_start = 1'b0;
                    end
                end else begin
                    i_wr_valid <= i_wr_valid & ~i_wr_ready;
                end
                // check
                if (o_wr_valid & o_wr_ready) begin
                    for (int i=0; i<CH_NUM; i++) begin
                        if ((stream_desc_bases[i*64+:64] <= o_wr_data[63:0] &&
                             o_wr_data[63:0] < stream_desc_ends[i*64+:64]) || i == write_req_ch) begin
                            if (write_req_data_saved[write_req_rpos] !== o_wr_data ||
                                write_req_last_saved[write_req_rpos] !== o_wr_last || stream_valids[i]) begin
                                $error("%d write req through fail[%3d]: %h %1h %h %1h", $time,
                                       write_req_rpos, o_wr_data, write_req_data_saved[write_req_rpos], o_wr_last, write_req_last_saved[write_req_rpos]);
                            end else begin
                                $display("%d write req through [%3d]: out %h %1h", $time,
                                         write_req_rpos, o_wr_data, o_wr_last);
                                $display("%d write req through [%3d]: exp %h %1h", $time,
                                         write_req_rpos, write_req_data_saved[write_req_rpos],
                                         write_req_last_saved[write_req_rpos]);
                            end
                            write_req_rpos <= write_req_rpos + 1'b1;
                            if (o_wr_last) count = count + 1;
                            write_req_ch <= o_wr_last ? -1 : i;
                        end
                    end
                end
                if (desc_cpl_valid & desc_cpl_ready) begin
                    for (int i=0; i<CH_NUM; i++) begin
                        if ((stream_desc_bases[i*64+:64] <= desc_cpl_data[63:0] &&
                             desc_cpl_data[63:0] < stream_desc_ends[i*64+:64]) || i == desc_cpl_ch) begin
                            if (desc_cpl_data_saved[desc_cpl_rpos] !== desc_cpl_data ||
                                desc_cpl_keep_saved[desc_cpl_rpos] !== desc_cpl_keep ||
                                desc_cpl_last_saved[desc_cpl_rpos] !== desc_cpl_last || !stream_valids[i]) begin
                                $error("%d desc cpl through fail[%3d]: %3d %h %h %1h %h %h %1h", $time,
                                       desc_cpl_rpos, i, desc_cpl_data, desc_cpl_keep, desc_cpl_last,
                                       desc_cpl_data_saved[desc_cpl_rpos], desc_cpl_keep_saved[desc_cpl_rpos], desc_cpl_last_saved[desc_cpl_rpos]);
                            end else begin
                                $display("%d desc cpl through[%3d]: %3d out %h %h %1h", $time,
                                         desc_cpl_rpos, i, desc_cpl_data, desc_cpl_keep, desc_cpl_last);
                                $display("%d desc cpl through[%3d]: %3d exp %h %h %1h", $time,
                                         desc_cpl_rpos, i,
                                         desc_cpl_data_saved[desc_cpl_rpos], desc_cpl_keep_saved[desc_cpl_rpos], desc_cpl_last_saved[desc_cpl_rpos]);
                            end
                            desc_cpl_rpos <= desc_cpl_rpos + 1'b1;
                            if (desc_cpl_last) count = count + 1;
                            desc_cpl_ch <= desc_cpl_last ? -1 : i;
                        end
                    end
                end
            end
        end
    endtask

    // core write req
    reg [7:0]            queue_update_req_wpos, queue_update_req_rpos;
    reg [RQ_DW-1:0]      queue_update_req_data_saved[0:255];
    reg                  queue_update_req_last_saved[0:255];
    reg [7:0]            queue_wr_req_wpos, queue_wr_req_rpos;
    reg [RQ_DW-1:0]      queue_wr_req_data_saved[0:255];
    reg                  queue_wr_req_last_saved[0:255];

    initial begin
        queue_update_req_wpos = 'd0;
        queue_update_req_rpos = 'd0;
        queue_wr_req_wpos = 'd0;
        queue_wr_req_rpos = 'd0;
    end

    task static core_write_req_issue_check();
        int i;
        int icount = 0;
        int count = 0;
        logic [RQ_DW-1:0] cur_write_req_data;
        logic [CH_NUM_LOG-1:0] cur_ch;
        logic                  cur_port;
        logic [63:0]           cur_addr;
        logic [63:0]           cur_offset;
        logic [10:0]           cur_len;
        logic [7:0]            next_update_wpos, next_wr_wpos;
        int write_req_ch = -1;
        int check_num = 0;
        while (count < MAX_REQ_NUM / CORE_REQ_VALID_BITS) begin
            @(posedge clk) begin
                // issue
                cur_port = rd[19];
                cur_ch = rd[17+:CH_NUM_LOG];
                cur_addr = {rd, rd, 2'd0};
                cur_len = cur_port ? QEW/4 : 2; // queue element : head & tail
                cur_write_req_data[RQBASE-1:0] = {'d0,
                                                  8'd0, // tag
                                                  8'd0, 8'd0, 1'b0, 4'd1, // req bus num, req func, poisoned req, ,request type
                                                  cur_len, cur_addr};
                next_update_wpos = queue_update_req_wpos + 2'd2;
                next_wr_wpos = queue_wr_req_wpos + 2'd2;
                for (i=RQBASE; i<RQ_DW; i+=32) begin
                    if ((i-RQBASE)/32 < cur_len) begin
                        cur_write_req_data[i+:32] = rd ^ (1001 * i);
                    end else begin
                        cur_write_req_data[i+:32] = rd ^ 32'haaaa_aaaa;
                    end
                end
                for (i=0; i<2; i++) begin
                    if (next_update_wpos !== queue_update_req_rpos && next_wr_wpos !== queue_wr_req_rpos &&
                        &rd[26-:CORE_REQ_VALID_BITS] && i == cur_port && stream_valids[cur_ch] &&
                        (i==0 ? (~queue_update_valid || queue_update_ready) : (~queue_wr_valid || queue_wr_ready))) begin
                        if (i==0) begin
                            queue_update_req_data_saved[queue_update_req_wpos] <= {'d0, cur_write_req_data[RQBASE-1:0]};
                            queue_update_req_data_saved[(queue_update_req_wpos + 1'b1) & 'hff] <= {'d0, cur_write_req_data[RQ_DW-1:RQBASE]};
                            queue_update_req_last_saved[queue_update_req_wpos] <= 1'b0;
                            queue_update_req_last_saved[(queue_update_req_wpos + 1'b1) & 'hff] <= 1'b1;
                            queue_update_req_wpos <= next_update_wpos;
                            queue_update_data <= cur_write_req_data;
                            queue_update_keep <= ('h10 << cur_len) - 1'b1;
                            queue_update_valid <= icount < MAX_REQ_NUM / CORE_REQ_VALID_BITS;
                        end else begin
                            queue_wr_req_data_saved[queue_wr_req_wpos] <= {'d0, cur_write_req_data[RQBASE-1:0]};
                            queue_wr_req_data_saved[(queue_wr_req_wpos + 1'b1) & 'hff] <= {'d0, cur_write_req_data[RQ_DW-1:RQBASE]};
                            queue_wr_req_last_saved[queue_wr_req_wpos] <= 1'b0;
                            queue_wr_req_last_saved[(queue_wr_req_wpos + 1'b1) & 'hff] <= 1'b1;
                            queue_wr_req_wpos <= next_wr_wpos;
                            queue_wr_data <= cur_write_req_data;
                            queue_wr_keep <= ('h10 << cur_len) - 1'b1;
                            queue_wr_valid <= icount < MAX_REQ_NUM / CORE_REQ_VALID_BITS;
                        end
                        $display("%d %s req [%3d]: %h %1h", $time, cur_port ? "queue wr" : "queue update",
                                 cur_ch, cur_write_req_data, stream_valids[cur_ch]);
                        icount = icount < MAX_REQ_NUM ? icount + 1 : icount;
                    end else begin
                        if (i==0) begin
                            queue_update_valid <= queue_update_valid & ~queue_update_ready;
                        end else begin
                            queue_wr_valid <= queue_wr_valid & ~queue_wr_ready;
                        end
                    end
                end
                // check
                if (o_wr_valid & o_wr_ready) begin
                    check_num = 0;
                    for (i=0; i<CH_NUM; i++) begin
                        if ((stream_desc_bases[i*64+:64] > o_wr_data[63:0] ||
                             o_wr_data[63:0] >= stream_desc_ends[i*64+:64] || !stream_valids[i]) && write_req_ch < 0) begin
                            check_num++;
                        end
                        if (stream_desc_bases[i*64+:64] <= o_wr_data[63:0] &&
                            o_wr_data[63:0] < stream_desc_ends[i*64+:64] && ~stream_valids[i]) begin
                            write_req_ch = o_wr_last ? -1 : i;
                        end
                    end
                    if (o_wr_last) write_req_ch = -1;
                    $display("%d check_num: %d", $time, check_num);
                    if (check_num == CH_NUM) begin
                        if ((queue_update_req_data_saved[queue_update_req_rpos] !== o_wr_data[RQ_DW-1:0] &&
                             queue_wr_req_data_saved[queue_wr_req_rpos] !== o_wr_data[RQ_DW-1:0]) ||
                            (queue_update_req_last_saved[queue_update_req_rpos] !== o_wr_last &&
                             queue_wr_req_last_saved[queue_wr_req_rpos] !== o_wr_last)) begin
                            $error("%d queue update/wr req through fail[%3d/%3d]: %h %h %h %1h %1h %1h", $time,
                                   queue_update_req_rpos, queue_wr_req_rpos,
                                   o_wr_data[RQ_DW-1:0], queue_update_req_data_saved[queue_update_req_rpos],
                                   queue_wr_req_data_saved[queue_wr_req_rpos], o_wr_last,
                                   queue_update_req_last_saved[queue_update_req_rpos], queue_wr_req_last_saved[queue_wr_req_rpos]);
                        end else begin
                            $display("%d queue update/wr req through [%3d/%3d]: out %h %1h", $time,
                                     queue_update_req_rpos, queue_wr_req_rpos, o_wr_data[RQ_DW-1:0], o_wr_last);
                            $display("%d queue update/wr req through [%3d/%3d]: exp %h", $time,
                                     queue_update_req_rpos, queue_wr_req_rpos,
                                     queue_update_req_data_saved[queue_update_req_rpos]);
                            $display("%d queue wr/wr req through [%3d/%3d]: exp %h", $time,
                                     queue_wr_req_rpos, queue_wr_req_rpos,
                                     queue_wr_req_data_saved[queue_wr_req_rpos]);
                            if (queue_update_req_data_saved[queue_update_req_rpos] === o_wr_data[RQ_DW-1:0]) begin
                                queue_update_req_rpos <= queue_update_req_rpos + 1'b1;
                            end
                            if (queue_wr_req_data_saved[queue_wr_req_rpos] === o_wr_data[RQ_DW-1:0]) begin
                                queue_wr_req_rpos <= queue_wr_req_rpos + 1'b1;
                            end
                        end
                        if (o_wr_last) count = count + 1;
                    end
                end
            end
        end
    endtask

    // fdma read cpl
    reg [7:0]            read_cpl_wpos, read_cpl_rpos;
    reg [DESC_RC_DW-1:0] read_cpl_data_saved[0:255];
    reg [DESC_RC_DK-1:0] read_cpl_keep_saved[0:255];
    reg [DESC_RC_USER-1:0] read_cpl_user_saved[0:255];
    reg                  read_cpl_last_saved[0:255];

    reg [7:0]            core_cpl_wpos[0:1], core_cpl_rpos[0:1];
    reg [RC_DW-1:0]      core_cpl_data_saved[0:1][0:255];

    reg [31:0]           frame_info_size_no_stream_saved[0:255];
    reg [CH_NUM_LOG-1:0] frame_info_ch_no_stream_saved[0:255];
    reg [7:0]            frame_info_no_stream_wpos, frame_info_no_stream_rpos;

    initial begin
        read_cpl_wpos = 'd0;
        read_cpl_rpos = 'd0;
        core_cpl_wpos[0] = 'd0;
        core_cpl_rpos[0] = 'd0;
        core_cpl_wpos[1] = 'd0;
        core_cpl_rpos[1] = 'd0;
        frame_info_no_stream_wpos = 'd0;
        frame_info_no_stream_rpos = 'd0;
    end

    task static fdma_read_cpl_issue_check();
        int i;
        int icount = 0;
        int count = 0;
        logic [DESC_RC_DW-1:0] cur_read_cpl_data;
        logic [DESC_RC_DK-1:0] cur_read_cpl_keep;
        logic                  cur_read_cpl_last;
        logic [DESC_RC_USER-1:0] cur_read_cpl_user;
        logic                    cur_read_cpl_valid;
        logic [1:0]            cur_port;
        logic [CH_NUM_LOG-1:0] cur_ch;
        logic [10:0]           cur_len;
        logic [7:0]            cur_tag;
        logic [7:0]            next_fdma_wpos, next_core_wpos;
        logic                  cur_start;
        logic                  prev_last = 0;
        int                    fdma_ch = -1;
        @(posedge clk) cur_start = 1'b1;
        while (count < MAX_REQ_NUM / REQ_VALID_BITS_MOD) begin
            @(posedge clk) begin
                // issue
                prev_last = (i_rc_valid & i_rc_ready & i_rc_last) || (rd[10] & prev_last);
                if (cur_start) begin
                    cur_port = rd[24:23];
                    if (IGNORE_RC_READY > 0) cur_port = 2'd2;
                    $display("cur_port: %x, %x %x %x %x", cur_port,
                             read_cpl_wpos + 1'b1, read_cpl_rpos, core_cpl_wpos[cur_port[0]] + 1'b1, core_cpl_rpos[cur_port[0]]);
                    cur_ch = rd[19+:CH_NUM_LOG];
                    cur_tag = &cur_port && ~stream_valids[cur_ch] ? CH_BASE + cur_ch :
                              cur_port[1] ? CH_BASE_RX + cur_ch : cur_port[0] ? QUEUE_READ_TAG : QUEUE_CHECK_TAG;
                    cur_len = 'd0 | rd[20+:6];
                    if (~|cur_len) cur_len = 'd1;
                    if (IGNORE_RC_READY > 0 && cur_len < DESC_RC_DK * 4)  cur_len = DESC_RC_DK *4;
                    if (cur_port == 2'd0) cur_len = 'd2;
                    if (cur_port == 2'd1) cur_len = QEW/4;
                    if (cur_port == 2'd3 && ~stream_valids[cur_ch]) cur_len = DESC_RC_DK;
                end else begin
                    //cur_tag = rd[10+:8];
                end
                for (int i=0; i<DESC_RC_DW; i=i+32) begin
                    cur_read_cpl_data[i+:32] = rd ^ (i*202);
                end
                if (&cur_port && ~stream_valids[cur_ch]) begin
                   cur_read_cpl_data[DESC_CMD_VALID] = 1'b1;
                end
                next_fdma_wpos = read_cpl_wpos + 1'b1;
                next_core_wpos = core_cpl_wpos[cur_port[0]] + 1'b1;
                cur_read_cpl_last = (cur_len <= DESC_RC_DK);
                cur_read_cpl_keep = ('d1 << cur_len) - 1'b1;
                cur_read_cpl_user = {cur_tag, rd[13+:8]};
                cur_read_cpl_valid = icount < MAX_REQ_NUM / REQ_VALID_BITS_MOD && (cur_port[1] || stream_valids[i]) &&
                                     (~prev_last || IGNORE_RC_READY==0);
                if ((~cur_port[1] || next_fdma_wpos !== read_cpl_rpos) &&
                    (cur_port[1] || next_core_wpos !== core_cpl_rpos[cur_port[0]]) &&
                    (REQ_VALID_BITS>0 ? &rd[15-:REQ_VALID_BITS_MOD] : 1'b1) &&
                    (~i_rc_valid || i_rc_ready || IGNORE_RC_READY > 0) && cur_read_cpl_valid) begin
                    i_rc_data <= cur_read_cpl_data;
                    i_rc_valid <= cur_read_cpl_valid;
                    i_rc_keep <= cur_read_cpl_keep;
                    i_rc_user <= cur_read_cpl_user;
                    i_rc_last <= cur_read_cpl_last;
                    if (cur_port[1]) begin
                        read_cpl_data_saved[read_cpl_wpos] <= cur_read_cpl_data;
                        read_cpl_keep_saved[read_cpl_wpos] <= cur_read_cpl_keep;
                        read_cpl_user_saved[read_cpl_wpos] <= cur_read_cpl_user;
                        read_cpl_last_saved[read_cpl_wpos] <= cur_read_cpl_last;
                        read_cpl_wpos <= next_fdma_wpos;
                        $display("%d fdma read cpl [%3d]: %h %h %h %1d %1d", $time,
                                 cur_ch, cur_read_cpl_data, cur_read_cpl_keep, cur_read_cpl_user, cur_read_cpl_last, stream_valids[i]);
                        if (cur_port[0] && ~stream_valids[cur_read_cpl_user[8+:CH_NUM_LOG]]) begin
                            frame_info_size_no_stream_saved[frame_info_no_stream_wpos] <= cur_read_cpl_data[DESC_DATA_POS+:32];
                            frame_info_ch_no_stream_saved[frame_info_no_stream_wpos] <= cur_read_cpl_user[8+:CH_NUM_LOG];
                            frame_info_no_stream_wpos <= frame_info_no_stream_wpos + 1'b1;
                        end
                    end else begin
                        core_cpl_data_saved[cur_port[0]][core_cpl_wpos[cur_port[0]]] <= {cur_read_cpl_data, 24'd0, cur_tag,
                                                                                         17'd0, cur_read_cpl_user[7:4], 27'd0, cur_read_cpl_user[3:0], 12'd0};
                        core_cpl_wpos[cur_port[0]] <= next_core_wpos;
                        $display("%d core read cpl [%3d]: %h %h %h %1d", $time,
                                 cur_ch, cur_read_cpl_data, cur_read_cpl_keep, cur_read_cpl_user, cur_read_cpl_last);
                    end
                    if (cur_read_cpl_last) begin
                        icount = icount < MAX_REQ_NUM / REQ_VALID_BITS_MOD ? icount + 1 : icount;
                        cur_start = 1'b1;
                    end else begin
                        cur_len = cur_len - DESC_RQ_DK;
                        cur_start = 1'b0;
                    end
                end else begin
                    i_rc_valid <= i_rc_valid & ~i_rc_ready;
                end
                // check
                if (o_rc_valid & o_rc_ready) begin
                    if ((CH_BASE_RX <= o_rc_user[8+:8] && o_rc_user[8+:8] < CH_BASE_RX + CH_NUM) ||
                        (CH_BASE <= o_rc_user[8+:8] && o_rc_user[8+:8] < CH_BASE + CH_NUM &&
                         ~stream_valids[o_rc_user[8+:8]-CH_BASE]) || fdma_ch >= 0) begin
                        if (read_cpl_data_saved[read_cpl_rpos] !== o_rc_data ||
                            read_cpl_keep_saved[read_cpl_rpos] !== o_rc_keep ||
                            read_cpl_user_saved[read_cpl_rpos] !== o_rc_user ||
                            read_cpl_last_saved[read_cpl_rpos] !== o_rc_last) begin
                            $error("%d fdma read cpl through fail[%3d]: %h %h %h %1h,  %h %h %h %1h", $time,
                                   read_cpl_rpos, o_rc_data, o_rc_keep, o_rc_user, o_rc_last,
                                   read_cpl_data_saved[read_cpl_rpos], read_cpl_keep_saved[read_cpl_rpos],
                                   read_cpl_user_saved[read_cpl_rpos], read_cpl_last_saved[read_cpl_rpos]);
                        end else begin
                            $display("%d fdma read cpl through [%3d]: out %h %h %h %1h", $time,
                                     read_cpl_rpos, o_rc_data, o_rc_keep, o_rc_user, o_rc_last);
                            $display("%d fdma read cpl through [%3d]: exp %h %h %h %1h", $time,
                                     read_cpl_rpos, read_cpl_data_saved[read_cpl_rpos], read_cpl_keep_saved[read_cpl_rpos],
                                     read_cpl_user_saved[read_cpl_rpos], read_cpl_last_saved[read_cpl_rpos]);
                        end
                        read_cpl_rpos <= read_cpl_rpos + 1'b1;
                        if (o_rc_last) begin
                            count = count + 1;
                            fdma_ch = -1;
                        end else begin
                            fdma_ch = o_rc_user[8+:8] - CH_BASE_RX;
                        end
                    end
                end
                if (queue_check_res_valid) begin
                    if (core_cpl_data_saved[0][core_cpl_rpos[0]] !== queue_check_res_data) begin
                        $error("%d queue check cpl through fail[%3d]: %h %h", $time,
                               core_cpl_rpos[0], queue_check_res_data, core_cpl_data_saved[0][core_cpl_rpos[0]]);
                    end else begin
                        $display("%d queue check cpl through[%3d]: %h %h", $time,
                                 core_cpl_rpos[0], queue_check_res_data, core_cpl_data_saved[0][core_cpl_rpos[0]]);
                    end
                    core_cpl_rpos[0] <= core_cpl_rpos[0] + 1'b1;
                    count = count + 1;
                end
                if (queue_rd_res_valid) begin
                    if (core_cpl_data_saved[1][core_cpl_rpos[1]] !== queue_rd_res_data) begin
                        $error("%d queue check cpl through fail[%3d]: %h %h", $time,
                               core_cpl_rpos[1], queue_rd_res_data, core_cpl_data_saved[1][core_cpl_rpos[1]]);
                    end else begin
                        $display("%d queue check cpl through[%3d]: %h %h", $time,
                                 core_cpl_rpos[1], queue_rd_res_data, core_cpl_data_saved[1][core_cpl_rpos[1]]);
                    end
                    core_cpl_rpos[1] <= core_cpl_rpos[1] + 1'b1;
                    count = count + 1;
                end
            end
        end
    endtask

    // frame info
    reg [31:0] frame_info_size_stream_saved[0:255];
    reg [CH_NUM_LOG-1:0] frame_info_ch_stream_saved[0:255];
    reg [7:0]            frame_info_stream_wpos, frame_info_stream_rpos;
    initial begin
        frame_info_stream_wpos = 'd0;
        frame_info_stream_rpos = 'd0;
    end

    task static frame_info_issue_check();
       int count = 0;
       logic valid = 0;
       logic [CH_NUM_LOG-1:0] ch = 0;
       logic [31:0]           size = 0;
       while (count < MAX_REQ_NUM / REQ_VALID_BITS_MOD) @(posedge clk) begin
          // issue
          if (~frame_info_in_valid | frame_info_in_ready) begin
             valid = &rd[12+:FRAME_INFO_OUT_BITS];
             ch = rd[14+:CH_NUM_LOG];
             valid = valid & stream_valids[ch];
             if (valid) begin
                size = rd;
                frame_info_in_size <= size;
                frame_info_in_ch <= ch;
                frame_info_in_valid <= valid;
                frame_info_size_stream_saved[frame_info_stream_wpos] <= size;
                frame_info_ch_stream_saved[frame_info_stream_wpos] <= ch;
                frame_info_stream_wpos <= frame_info_stream_wpos + 1'b1;
                count++;
             end else begin
                frame_info_in_valid <= frame_info_in_valid & ~frame_info_in_valid;
             end
          end
          //check
          if (frame_info_out_valid & frame_info_out_ready) begin
             if (frame_info_out_size === frame_info_size_stream_saved[frame_info_stream_rpos] &&
                 frame_info_out_ch === frame_info_ch_stream_saved[frame_info_stream_rpos]) begin
                frame_info_stream_rpos <= frame_info_stream_rpos + 1'b1;
             end else if (frame_info_out_size === frame_info_size_no_stream_saved[frame_info_no_stream_rpos] &&
                          frame_info_out_ch === frame_info_ch_no_stream_saved[frame_info_no_stream_rpos]) begin
                frame_info_no_stream_rpos <= frame_info_no_stream_rpos + 1'b1;
             end else begin
                $error("%d: frame info out: %h %h, %h %h, %h %h", $time,
                       frame_info_out_size, frame_info_out_ch,
                       frame_info_size_stream_saved[frame_info_stream_rpos],
                       frame_info_ch_stream_saved[frame_info_stream_rpos],
                       frame_info_size_no_stream_saved[frame_info_no_stream_rpos],
                       frame_info_ch_no_stream_saved[frame_info_no_stream_rpos]);
             end
          end
          frame_info_out_ready <= &rd[22+:FRAME_INFO_OUT_BITS];
       end
    endtask

    // core read cpl
    reg [7:0]            desc_out_cpl_wpos, desc_out_cpl_rpos;
    reg [DESC_RC_DW-1:0] desc_out_cpl_data_saved[0:255];
    reg [DESC_RC_DK-1:0] desc_out_cpl_keep_saved[0:255];
    reg [DESC_RC_USER-1:0] desc_out_cpl_user_saved[0:255];
    reg                  desc_out_cpl_last_saved[0:255];

    initial begin
        desc_out_cpl_wpos = 'd0;
        desc_out_cpl_rpos = 'd0;
    end

    task static core_read_cpl_issue_check();
        int i;
        int icount = 0;
        int count = 0;
        logic [DESC_RC_DW-1:0] cur_read_cpl_data;
        logic [DESC_RC_DK-1:0] cur_read_cpl_keep;
        logic                  cur_read_cpl_last;
        logic [CH_NUM_LOG-1:0] cur_ch;
        logic [10:0]           cur_len;
        logic [7:0]            cur_tag;
        logic [7:0]            cur_remain_user;
        logic [7:0]            next_wpos;
        logic                  cur_start;
        int                    core_ch = -1;
        logic [DESC_RC_DW-1:0] cur_read_cpl_data_for_save;
        logic [DESC_RC_DK-1:0] cur_read_cpl_keep_for_save;
        logic [DESC_RC_USER-1:0] cur_read_cpl_user_for_save;
        logic                  cur_read_cpl_last_for_save;
        logic                  cur_read_cpl_valid_for_save;
        logic                  cur_read_cpl_last_d1;
        @(posedge clk) cur_start = 1'b1;
        while (count < MAX_REQ_NUM / CORE_REQ_VALID_BITS) begin
            @(posedge clk) begin
                // issue
                if (cur_start) cur_ch = rd[19+:CH_NUM_LOG];
                next_wpos = desc_out_cpl_wpos + 1'b1;
                if (next_wpos !== desc_out_cpl_rpos && &rd[25-:CORE_REQ_VALID_BITS] &&
                    stream_valids[cur_ch] && (~desc_out_valid || desc_out_ready)) begin
                    cur_remain_user = rd[13+:8];
                    if (cur_start) begin
                        cur_tag = CH_BASE + cur_ch;
                        cur_len = 'd0 | rd[20+:6];
                        if (~|cur_len) cur_len = 'd1;
                        if (IGNORE_RC_READY > 0 && cur_len > DESC_RC_DK) cur_len = DESC_RC_DK;
                        cur_read_cpl_data[RCBASE-1:0] = {24'd0, cur_tag, 17'd0, cur_remain_user[7:4], 27'd0, cur_remain_user[3:0], 12'd0};
                        cur_len = cur_len + 2'd3;
                        cur_read_cpl_user_for_save = {cur_tag, cur_remain_user};
                    end else begin
                        for (int i=0; i<RCBASE; i=i+32) begin
                            cur_read_cpl_data[i+:32] = rd ^ (i*202);
                        end
                        cur_read_cpl_data_for_save[DESC_RC_DW-1-:RCBASE] = cur_read_cpl_data[RCBASE-1:0];
                    end
                    for (int i=RCBASE; i<DESC_RC_DW; i=i+32) begin
                        cur_read_cpl_data[i+:32] = rd ^ (i*202);
                    end
                    cur_read_cpl_last = (cur_len <= DESC_RC_DK);
                    cur_read_cpl_keep = ('d1 << cur_len) - 1'b1;

                    desc_out_data <= cur_read_cpl_data;
                    desc_out_valid <= icount < MAX_REQ_NUM / CORE_REQ_VALID_BITS;
                    desc_out_keep <= cur_read_cpl_keep;
                    desc_out_last <= cur_read_cpl_last;

                    if (cur_start) begin
                        cur_read_cpl_data_for_save = {'d0, cur_read_cpl_data[DESC_RC_DW-1:RCBASE]};
                    end
                    if (!cur_start || cur_len <= DESC_RC_DK) begin
                        if (cur_start) begin
                            cur_read_cpl_last_for_save = (cur_len <= DESC_RC_DK + 3);
                            cur_read_cpl_keep_for_save = ('d1 << (cur_len - 3)) - 1'b1;
                        end else begin
                            cur_read_cpl_last_for_save = (cur_len <= 3);
                            cur_read_cpl_keep_for_save = ('d1 << (cur_len + DESC_RC_DK - 3)) - 1'b1;
                        end
                        desc_out_cpl_data_saved[desc_out_cpl_wpos] <= cur_read_cpl_data_for_save;
                        desc_out_cpl_keep_saved[desc_out_cpl_wpos] <= cur_read_cpl_keep_for_save;
                        desc_out_cpl_user_saved[desc_out_cpl_wpos] <= cur_read_cpl_user_for_save;
                        desc_out_cpl_last_saved[desc_out_cpl_wpos] <= cur_read_cpl_last_for_save;
                        desc_out_cpl_wpos <= next_wpos;
                        $display("%d replace read cpl save [%3d]: %h %h %h %1d", $time,
                                 desc_out_cpl_wpos, cur_read_cpl_data_for_save, cur_read_cpl_keep_for_save,
                                 cur_read_cpl_user_for_save, cur_read_cpl_last_for_save);
                        cur_read_cpl_data_for_save[DESC_RC_DW-RCBASE-1:0] = cur_read_cpl_data[DESC_RC_DW-1:RCBASE];
                        if (cur_read_cpl_last && !cur_read_cpl_last_for_save) begin
                            cur_read_cpl_data_for_save[DESC_RC_DW-1-:RCBASE] = 'd0;
                            cur_read_cpl_last_for_save = (cur_len <= DESC_RC_DK + 3);
                            cur_read_cpl_keep_for_save = ('d1 << (cur_len - 3)) - 1'b1;
                            desc_out_cpl_data_saved[next_wpos] <= cur_read_cpl_data_for_save;
                            desc_out_cpl_keep_saved[next_wpos] <= cur_read_cpl_keep_for_save;
                            desc_out_cpl_user_saved[next_wpos] <= cur_read_cpl_user_for_save;
                            desc_out_cpl_last_saved[next_wpos] <= cur_read_cpl_last_for_save;
                            desc_out_cpl_wpos <= next_wpos + 1'b1;
                            $display("%d replace read cpl save [%3d]: %h %h %h %1d", $time,
                                     next_wpos, cur_read_cpl_data_for_save, cur_read_cpl_keep_for_save,
                                     cur_read_cpl_user_for_save, cur_read_cpl_last_for_save);
                        end
                    end
                    $display("%d replace read cpl [%3d]: %h %h %h %1d %1d", $time,
                             cur_ch, cur_read_cpl_data, cur_read_cpl_keep, cur_read_cpl_user_for_save, cur_read_cpl_last, stream_valids[cur_ch]);

                    if (cur_read_cpl_last) begin
                        icount = icount < MAX_REQ_NUM / CORE_REQ_VALID_BITS ? icount + 1 : icount;
                        cur_start = 1'b1;
                    end else begin
                        cur_len = cur_len - DESC_RQ_DK;
                        cur_start = 1'b0;
                    end
                end else begin
                    desc_out_valid <= desc_out_valid & ~desc_out_ready;
                end
                // check
                if (o_rc_valid & o_rc_ready) begin
                    if ((CH_BASE <= o_rc_user[8+:8] && o_rc_user[8+:8] < CH_BASE + CH_NUM &&
                         stream_valids[o_rc_user[8+:8] - CH_BASE]) || core_ch >= 0) begin
                        if (desc_out_cpl_data_saved[desc_out_cpl_rpos] !== o_rc_data ||
                            desc_out_cpl_keep_saved[desc_out_cpl_rpos] !== o_rc_keep ||
                            desc_out_cpl_user_saved[desc_out_cpl_rpos] !== o_rc_user ||
                            desc_out_cpl_last_saved[desc_out_cpl_rpos] !== o_rc_last) begin
                            $error("%d replace read cpl through fail[%3d]: %h %h %h %1h,  %h %h %h %1h", $time,
                                   desc_out_cpl_rpos, o_rc_data, o_rc_keep, o_rc_user, o_rc_last,
                                   desc_out_cpl_data_saved[desc_out_cpl_rpos], desc_out_cpl_keep_saved[desc_out_cpl_rpos],
                                   desc_out_cpl_user_saved[desc_out_cpl_rpos], desc_out_cpl_last_saved[desc_out_cpl_rpos]);
                        end else begin
                            $display("%d replace read cpl through [%3d]: out %h %h %h %1h", $time,
                                     desc_out_cpl_rpos, o_rc_data, o_rc_keep, o_rc_user, o_rc_last);
                            $display("%d replace read cpl through [%3d]: exp %h %h %h %1h", $time,
                                     desc_out_cpl_rpos, desc_out_cpl_data_saved[desc_out_cpl_rpos], desc_out_cpl_keep_saved[desc_out_cpl_rpos],
                                     desc_out_cpl_user_saved[desc_out_cpl_rpos], desc_out_cpl_last_saved[desc_out_cpl_rpos]);
                        end
                        desc_out_cpl_rpos <= desc_out_cpl_rpos + 1'b1;
                        if (o_rc_last) begin
                            count = count + 1;
                            core_ch = -1;
                        end else begin
                            core_ch = o_rc_user[8+:8] - CH_BASE;
                        end
                    end
                end
                if (ENABLE_INVALID_CYCLE != 0) begin
                    cur_read_cpl_last_d1 <= o_rc_last & o_rc_valid & o_rc_ready;
                    if (o_rc_valid & o_rc_ready & cur_read_cpl_last_d1) begin
                        $error("%d read cpl for data is valid after core cpl for descriptor.", $time);
                    end
                end
            end
        end
    endtask

    initial begin
        int i;
        while (resetn !== 1'b1) @(posedge clk);

        case(TEST_CASE)
            0 : begin
                initialize_desc_range;
                fork
                    begin
                        fdma_read_req_issue_check;
                    end
                    begin
                        core_read_req_issue_check;
                    end
                join
            end
            1 : begin
                initialize_desc_range;
                fork
                    begin
                        fdma_write_req_issue_check;
                    end
                    begin
                        core_write_req_issue_check;
                    end
                join
            end
            2 : begin
                initialize_desc_range;
                fork
                    begin
                        fdma_read_cpl_issue_check;
                    end
                    begin
                        core_read_cpl_issue_check;
                    end
                    if (ENABLE_FRAME_INFO_OUT > 0) begin
                        frame_info_issue_check;
                    end
                join
            end
            10 : begin
                initialize_desc_range;
                fork
                    begin
                        fdma_read_req_issue_check;
                    end
                    begin
                        core_read_req_issue_check;
                    end
                    begin
                        fdma_write_req_issue_check;
                    end
                    begin
                        core_write_req_issue_check;
                    end
                    begin
                        fdma_read_cpl_issue_check;
                    end
                    begin
                        core_read_cpl_issue_check;
                    end
                    if (ENABLE_FRAME_INFO_OUT > 0) begin
                        frame_info_issue_check;
                    end
                join
            end
            default: begin
                $fatal(2, "unknown test case");
            end
        endcase

        $finish();
    end

endmodule

module test_switch_basic();

    tb_switch #(
        .TEST_CASE ( 10 ),
        .MAX_REQ_NUM ( 5000 )
    ) tb();

endmodule

module test_switch_basic2();

    tb_switch #(
        .TEST_CASE ( 10 ),
        .MAX_REQ_NUM ( 5000 ),
        .CORE_REQ_VALID_BITS ( 2 )
    ) tb();

endmodule

module test_switch_basic3();

    tb_switch #(
        .TEST_CASE ( 10 ),
        .MAX_REQ_NUM ( 5000 ),
        .REQ_VALID_BITS ( 2 )
    ) tb();

endmodule

module test_switch_read_req();

    tb_switch #(
        .TEST_CASE ( 0 ),
        .MAX_REQ_NUM ( 5000 )
    ) tb();

endmodule

module test_switch_read_req2();

    tb_switch #(
        .TEST_CASE ( 0 ),
        .MAX_REQ_NUM ( 5000 ),
        .CORE_REQ_VALID_BITS ( 2 )
    ) tb();

endmodule

module test_switch_read_req3();

    tb_switch #(
        .TEST_CASE ( 0 ),
        .MAX_REQ_NUM ( 5000 ),
        .REQ_VALID_BITS ( 2 )
    ) tb();

endmodule

module test_switch_write_req();

    tb_switch #(
        .TEST_CASE ( 1 ),
        .MAX_REQ_NUM ( 5000 )
    ) tb();

endmodule

module test_switch_write_req2();

    tb_switch #(
        .TEST_CASE ( 1 ),
        .MAX_REQ_NUM ( 5000 ),
        .CORE_REQ_VALID_BITS ( 2 )
    ) tb();

endmodule

module test_switch_write_req3();

    tb_switch #(
        .TEST_CASE ( 1 ),
        .MAX_REQ_NUM ( 5000 ),
        .REQ_VALID_BITS ( 2 )
    ) tb();

endmodule

module test_switch_read_cpl();

    tb_switch #(
        .TEST_CASE ( 2 ),
        .MAX_REQ_NUM ( 5000 )
    ) tb();

endmodule

module test_switch_read_cpl2();

    tb_switch #(
        .TEST_CASE ( 2 ),
        .MAX_REQ_NUM ( 5000 ),
        .CORE_REQ_VALID_BITS ( 2 )
    ) tb();

endmodule

module test_switch_read_cpl3();

    tb_switch #(
        .TEST_CASE ( 2 ),
        .DISABLE_FRAME_INFO ( 1 ),
        .MAX_REQ_NUM ( 5000 ),
        .REQ_VALID_BITS ( 2 )
    ) tb();

endmodule

module test_switch_read_cpl4();

    tb_switch #(
        .TEST_CASE ( 2 ),
        .DISABLE_FRAME_INFO ( 1 ),
        .MAX_REQ_NUM ( 5000 ),
        .NO_RC_BP ( 1 )
    ) tb();

endmodule

module test_switch_read_cpl5();

    tb_switch #(
        .TEST_CASE ( 2 ),
        .DISABLE_FRAME_INFO ( 1 ),
        .MAX_REQ_NUM ( 5000 ),
        .CORE_REQ_VALID_BITS ( 2 )
    ) tb();

endmodule

module test_switch_read_cpl6();

    tb_switch #(
        .TEST_CASE ( 2 ),
        .DISABLE_FRAME_INFO ( 1 ),
        .MAX_REQ_NUM ( 5000 ),
        .REQ_VALID_BITS ( 2 )
    ) tb();

endmodule

module test_switch_read_cpl7();

    tb_switch #(
        .TEST_CASE ( 2 ),
        .DISABLE_FRAME_INFO ( 1 ),
        .MAX_REQ_NUM ( 5000 ),
        .REQ_VALID_BITS ( 0 ),
        .IGNORE_RC_READY ( 1 ),
        .NO_RC_BP ( 1 )
    ) tb();

endmodule

module test_switch_read_cpl8();

    tb_switch #(
        .TEST_CASE ( 2 ),
        .DISABLE_FRAME_INFO ( 1 ),
        .ENABLE_FRAME_INFO_OUT ( 1 ),
        .MAX_REQ_NUM ( 5000 ),
        .REQ_VALID_BITS ( 1 ),
        .FRAME_INFO_OUT_BITS ( 2 )
    ) tb();

endmodule
