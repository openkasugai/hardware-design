/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module stream_engine_queue_head_tail #(
    parameter CH_NUM_LOG = 3,
    parameter ENABLE_QUEUE = 0,
    parameter RQ_DW = 384,
    parameter RQ_DK = 12,
    parameter RC_DW = 352,
    parameter QEW_LOG = 5,
    parameter RQBASE = 128,
    parameter RCBASE = 96,
    parameter QUEUE_CHECK_TAG = 99
    ) (
    input [3:0]                         ctrl_reg_waddr,
    input [31:0]                        ctrl_reg_wdata,
    input [CH_NUM_LOG-1:0]              ctrl_reg_wch,
    input                               ctrl_reg_wen,

    input [(1<<CH_NUM_LOG)-1:0]         stream_ch_valids,
    input [(1<<CH_NUM_LOG)-1:0]         stream_ch_d2d_valids,
    input [(1<<CH_NUM_LOG)*64-1:0]      stream_req_q_bases,
    input [(1<<CH_NUM_LOG)*64-1:0]      stream_cpl_q_bases,
    input [(1<<CH_NUM_LOG)*8-1:0]       stream_req_q_depth,
    input [(1<<CH_NUM_LOG)*8-1:0]       stream_cpl_q_depth,
    input [(1<<CH_NUM_LOG)*64-1:0]      stream_req_q_head_tails,
    input [(1<<CH_NUM_LOG)*64-1:0]      stream_cpl_q_head_tails,

    input [15:0]                        stream_check_interval,
    input [CH_NUM_LOG:0]                stream_ch_valid_num,
    input [CH_NUM_LOG:0]                stream_ch_doorbell_num,

    input [RC_DW-1:0]                   queue_check_res_data,
    input                               queue_check_res_valid,

    output reg [RQ_DW-1:0]              queue_check_data,
    output reg [RQ_DK-1:0]              queue_check_keep,
    output reg                          queue_check_valid,
    input                               queue_check_ready,

    output reg [RQ_DW-1:0]              queue_update_data, // [135:128] head/tail, [160+:CH_NUM_LOG] ch, [192] is_cpl
    output reg [RQ_DK-1:0]              queue_update_keep,
    output reg                          queue_update_valid,
    input                               queue_update_ready,

    input [CH_NUM_LOG-1:0]              request_head_update_ch,
    input                               request_head_update_ch_valid,

    input [CH_NUM_LOG-1:0]              transfer_cpl_ch,
    input                               transfer_cpl_ch_valid,
    output reg                          transfer_cpl_ch_done,

    input [(1<<CH_NUM_LOG)-1:0]         queue_errors,

    output reg [(1<<CH_NUM_LOG)-1:0]    initialized_queues,

    output reg [(1<<CH_NUM_LOG)-1:0]    req_q_valids,
    output reg [(1<<CH_NUM_LOG)-1:0]    cpl_q_vacants,

    output reg [(1<<CH_NUM_LOG)*64-1:0] req_q_head_addrs,
    output reg [(1<<CH_NUM_LOG)*64-1:0] cpl_q_head_addrs,

    input [(1<<CH_NUM_LOG)-1:0]         stream_check_requests,
    input [(1<<CH_NUM_LOG)-1:0]         stream_ch_check_with_doorbells,
    output reg [CH_NUM_LOG-1:0]         stream_check_ch,
    output reg                          stream_check_done,

    output [8*(1<<CH_NUM_LOG)-1:0]      dbg_req_q_head,
    output [8*(1<<CH_NUM_LOG)-1:0]      dbg_req_q_read_pos,
    output [8*(1<<CH_NUM_LOG)-1:0]      dbg_req_q_tail,
    output [8*(1<<CH_NUM_LOG)-1:0]      dbg_cpl_q_head,
    output [8*(1<<CH_NUM_LOG)-1:0]      dbg_cpl_q_head_inflight,
    output [8*(1<<CH_NUM_LOG)-1:0]      dbg_cpl_q_tail,
    output reg [8*(1<<CH_NUM_LOG)-1:0]  dbg_cpl_counts,
    output reg [8*(1<<CH_NUM_LOG)-1:0]  dbg_cpl_counts2,

    input                               clk,
    input                               resetn
    );

    localparam CH_NUM = 1 << CH_NUM_LOG;

    // initialize queue informations
    reg [CH_NUM-1:0] need_initialize_head_tail;

    wire [CH_NUM_LOG-1:0] initialize_head_tail_cpl_ch;
    wire                  initialize_head_tail_cpl_valid;

    generate
        wire [CH_NUM-1:0]  w_d2d_valids;
        wire               w_write_d2d;
        if (ENABLE_QUEUE > 0) begin
           assign w_d2d_valids = stream_ch_d2d_valids;
           assign w_write_d2d = ctrl_reg_wdata[4];
        end else begin
           assign w_d2d_valids = 'd0;
           assign w_write_d2d = 1'b0;
        end
        for (genvar i=0; i<CH_NUM; i=i+1) begin
            always @(posedge clk) begin
                if (~resetn) begin
                    need_initialize_head_tail[i] <= 1'b0;
                    initialized_queues[i] <= 1'b0;
                end else if (queue_errors[i]) begin
                    need_initialize_head_tail[i] <= 1'b0;
                    initialized_queues[i] <= 1'b0;
                end else if (ctrl_reg_wen && ctrl_reg_wch == i && ~|ctrl_reg_waddr && ~w_write_d2d && ~w_d2d_valids[i]) begin
                    need_initialize_head_tail[i] <= ctrl_reg_wdata[0];
                    initialized_queues[i] <= initialized_queues[i] & ctrl_reg_wdata[0];
                end else if (initialize_head_tail_cpl_ch == i && initialize_head_tail_cpl_valid) begin
                    need_initialize_head_tail[i] <= 1'b0;
                    initialized_queues[i] <= 1'b1;
                end
            end
        end
    endgenerate

    // queue head tail checking
    reg [CH_NUM_LOG-1:0] check_ch;
    reg [CH_NUM_LOG-1:0] check_ch_num;
    wire [CH_NUM_LOG-1:0] check_ch_next;
    reg                  check_cpl;
    reg                  check_requested;
    reg                  check_doorbell;
    reg [15:0]           check_interval;

    wire                 cur_initialize_head_tail = need_initialize_head_tail >> check_ch;
    wire                 cur_check_head_tail = (~stream_ch_check_with_doorbells & initialized_queues) >> check_ch;
    wire                 cur_check_with_doorbell = (stream_ch_check_with_doorbells & stream_check_requests) >> check_ch;
    wire                 cur_uncheck_with_doorbell = (stream_ch_check_with_doorbells & ~stream_check_requests) >> check_ch;
    always @(posedge clk) begin
        if (~resetn) begin
            check_ch <= 'd0;
            check_cpl <= 1'b0;
            check_ch_num <= 'd0;
            check_requested <= 1'b0;
            check_doorbell <= 1'b0;
            queue_check_data <= 'd0;
            queue_check_keep <= 'd0;
            queue_check_valid <= 1'b0;
            check_interval <= 'd0;
            stream_check_done <= 1'b0;
        end else if (~check_requested) begin
            if (cur_initialize_head_tail || (~|check_interval && cur_check_head_tail) || cur_check_with_doorbell) begin
                check_requested <= 1'b1;
                if (~check_cpl) begin
                    queue_check_data[63:2] <= stream_req_q_head_tails >> {check_ch, 6'd2};
                end else begin
                    queue_check_data[63:2] <= stream_cpl_q_head_tails >> {check_ch, 6'd2};
                end
                queue_check_data[74:64] <= 11'd2; // dword count
                queue_check_data[78:75] <= 4'd0; // memory read
                queue_check_data[103:96] <= QUEUE_CHECK_TAG; // tag
                queue_check_keep[3:0] <= 4'd15;
                queue_check_valid <= 1'b1;
                if (~cur_initialize_head_tail && check_cpl) begin
                    if (cur_check_with_doorbell) begin
                        stream_check_done <= 1'b1;
                        stream_check_ch <= check_ch;
                    end else begin
                        check_ch_num <= |check_ch_num ? check_ch_num - 1'b1 : stream_ch_valid_num - stream_ch_doorbell_num - 1'b1;
                    end
                end
                check_doorbell <= cur_check_with_doorbell;
            end else if (~cur_check_head_tail && ~cur_check_with_doorbell) begin
                check_ch <= check_ch_next;
                check_cpl <= 1'b0;
            end
            if (|check_interval) begin
                check_interval <= check_interval - 1'b1;
            end
        end else begin
           stream_check_done <= 1'b0;
           if (queue_check_res_valid) begin
                check_cpl <= ~check_cpl;
                if (check_cpl) begin
                    check_ch <= check_ch_next;
                end
                if (~cur_initialize_head_tail && ~|check_ch_num && check_cpl && ~check_doorbell) begin
                    check_interval <= stream_check_interval;
                end else if (|check_interval) begin
                    check_interval <= check_interval - 1'b1;
                end
                check_requested <= 1'b0;
            end else if (|check_interval) begin
                check_interval <= check_interval - 1'b1;
            end
            if (queue_check_ready) begin
                queue_check_valid <= 1'b0;
            end
        end
    end

    assign initialize_head_tail_cpl_ch = check_ch;
    assign initialize_head_tail_cpl_valid = check_cpl && cur_initialize_head_tail && queue_check_res_valid;

    wire head_tail_ch_update = (check_requested && queue_check_res_valid && check_cpl) |
         (~check_requested && ~cur_initialize_head_tail && |check_interval && |need_initialize_head_tail) |
         (~check_requested && cur_uncheck_with_doorbell);
    wire [CH_NUM-1:0] head_tail_ch_valids = need_initialize_head_tail | ((~req_q_valids | ~cpl_q_vacants) & stream_ch_valids & initialized_queues);
    ch_candidate #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .RR ( 1 )
    ) check_ch_candidate (
        .ch_valids ( head_tail_ch_valids ),
        .update ( head_tail_ch_update ),
        .candidate ( check_ch_next ),
        .candidate_valid ( ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    // update queue head tail
    reg [8*CH_NUM-1:0] req_q_head;
    reg [8*CH_NUM-1:0] req_q_read_pos;
    reg [8*CH_NUM-1:0] req_q_tail;
    reg [8*CH_NUM-1:0] cpl_q_head;
    reg [8*CH_NUM-1:0] cpl_q_head_inflight;
    reg [8*CH_NUM-1:0] cpl_q_tail;

    assign dbg_req_q_head = req_q_head;
    assign dbg_req_q_read_pos = req_q_read_pos;
    assign dbg_req_q_tail = req_q_tail;
    assign dbg_cpl_q_head = cpl_q_head;
    assign dbg_cpl_q_head_inflight = cpl_q_head_inflight;
    assign dbg_cpl_q_tail = cpl_q_tail;

    // addr update after request queue head read
    wire [63:0]          req_q_head_addr_update;
    wire [7:0]           req_q_head_pos_update;
    wire                 req_q_head_addr_carry;
    wire [CH_NUM_LOG-1:0] req_q_head_ch;
    wire                  req_q_head_update;

    calc_queue_info #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .QEW_LOG ( QEW_LOG )
    ) req_q_read_pos_calc (
        .update_ch ( request_head_update_ch ),
        .update_ch_valid ( request_head_update_ch_valid ),
        .addr_bases ( stream_req_q_bases ),
        .q_depth ( stream_req_q_depth ),
        .q_pos ( req_q_read_pos ),
        .addr_out ( req_q_head_addr_update ),
        .addr_carry32 ( req_q_head_addr_carry ),
        .q_pos_out ( req_q_head_pos_update ),
        .q_ch_out ( req_q_head_ch ),
        .out_valid ( req_q_head_update ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    // addr update after completion queue head write
    wire [63:0]          cpl_q_head_addr_update;
    wire [7:0]           cpl_q_head_pos_update;
    wire                 cpl_q_head_addr_carry;
    wire [CH_NUM_LOG-1:0] cpl_q_head_ch;
    wire                  cpl_q_head_update;

    calc_queue_info #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .QEW_LOG ( QEW_LOG )
    ) cpl_q_head_calc (
        .update_ch ( transfer_cpl_ch ),
        .update_ch_valid ( transfer_cpl_ch_valid ),
        .addr_bases ( stream_cpl_q_bases ),
        .q_depth ( stream_cpl_q_depth ),
        .q_pos ( cpl_q_head ),
        .addr_out ( cpl_q_head_addr_update ),
        .addr_carry32 ( cpl_q_head_addr_carry ),
        .q_pos_out ( cpl_q_head_pos_update ),
        .q_ch_out ( cpl_q_head_ch ),
        .out_valid ( cpl_q_head_update ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    // addr update after initializing queue head/tail
    wire [63:0] w_init_q_base = (check_cpl ? stream_cpl_q_bases : stream_req_q_bases) >> {check_ch, 6'd0};
    wire [7:0]  w_update_init_q_head = queue_check_res_data[RCBASE+:8];
    wire [7:0]  w_update_init_q_tail = queue_check_res_data[RCBASE+32+:8];

    reg [63:0]          init_q_head_addr_update;
    reg [63:0]          init_q_tail_addr_update;
    reg [1:0]           init_q_addr_update_valids;
    reg [7:0]           init_q_head_update;
    reg [7:0]           init_q_tail_update;
    reg                 init_q_head_addr_carry;
    reg                 init_q_tail_addr_carry;
    reg [CH_NUM_LOG-1:0] init_q_ch;
    reg                  init_q_cpl;

    always @(posedge clk) begin
        if (~resetn) begin
            init_q_addr_update_valids <= 'd0;
            init_q_head_addr_update <= 'd0;
            init_q_tail_addr_update <= 'd0;
            init_q_head_update <= 'd0;
            init_q_tail_update <= 'd0;
            init_q_head_addr_carry <= 1'b0;
            init_q_tail_addr_carry <= 1'b0;
            init_q_ch <= 'd0;
            init_q_cpl <= 1'b0;
        end else if (init_q_addr_update_valids[0]) begin
            {init_q_head_addr_carry, init_q_head_addr_update[31:0]} <= {1'b0, init_q_head_addr_update[31:0]} + {init_q_head_update, {QEW_LOG{1'b0}}};
            {init_q_tail_addr_carry, init_q_tail_addr_update[31:0]} <= {1'b0, init_q_tail_addr_update[31:0]} + {init_q_tail_update, {QEW_LOG{1'b0}}};
            init_q_addr_update_valids <= {init_q_addr_update_valids, 1'b0};
        end else if (queue_check_res_valid && cur_initialize_head_tail) begin
            init_q_addr_update_valids <= 'd1;
            init_q_head_addr_update <= w_init_q_base;
            init_q_tail_addr_update <= w_init_q_base;
            init_q_head_update <= w_update_init_q_head;
            init_q_tail_update <= w_update_init_q_tail;
            init_q_ch <= check_ch;
            init_q_cpl <= check_cpl;
        end else begin
            init_q_addr_update_valids <= 'd0;
        end
    end

    reg [CH_NUM-1:0] queue_head_tail_writes;
    wire [CH_NUM-1:0] queue_head_tail_written;

    generate
        for (genvar i=0; i<CH_NUM; i=i+1) begin
            wire [7:0] cpl_q_head_inflight_p1 = cpl_q_head_inflight[i*8+:8] + 1'b1 >= stream_cpl_q_depth[i*8+:8] ? 8'd0 : cpl_q_head_inflight[i*8+:8] + 1'b1;
            wire [7:0] cpl_q_head_p1 = cpl_q_head[i*8+:8] + 1'b1 >= stream_cpl_q_depth[i*8+:8] ? 8'd0 : cpl_q_head[i*8+:8] + 1'b1;
            wire [7:0] req_q_tail_p1 = req_q_tail[i*8+:8] + 1'b1 >= stream_req_q_depth[i*8+:8] ? 8'd0 : req_q_tail[i*8+:8] + 1'b1;
            always @(posedge clk) begin
                if (~resetn || ~stream_ch_valids[i]) begin
                    req_q_head[i*8+:8] <= 8'd0;
                    req_q_read_pos[i*8+:8] <= 8'd0;
                    req_q_tail[i*8+:8] <= 8'd0;
                    cpl_q_head[i*8+:8] <= 8'd0;
                    cpl_q_head_inflight[i*8+:8] <= 8'd0;
                    cpl_q_tail[i*8+:8] <= 8'd0;
                    req_q_valids[i] <= 1'b0;
                    cpl_q_vacants[i] <= 1'b0;
                    req_q_head_addrs[i*64+:64] <= 64'd0;
                    cpl_q_head_addrs[i*64+:64] <= 64'd0;
                    queue_head_tail_writes[i] <= 1'b0;
                end else begin
                    if (cur_initialize_head_tail) begin
                        if (queue_check_res_valid && i == check_ch) begin
                            if (check_cpl) begin
                                if (stream_ch_d2d_valids[i]) begin
                                    {cpl_q_tail[i*8+:8], cpl_q_head[i*8+:8]} <= 'd0;
                                    cpl_q_head_inflight[i*8+:8] <= 'd0;
                                end else begin
                                    {cpl_q_tail[i*8+:8], cpl_q_head[i*8+:8]} <= {queue_check_res_data[RCBASE+32+:8], queue_check_res_data[RCBASE+:8]};
                                    cpl_q_head_inflight[i*8+:8] <= queue_check_res_data[RCBASE+:8];
                                end
                            end else begin
                                if (stream_ch_d2d_valids[i]) begin
                                   {req_q_tail[i*8+:8], req_q_head[i*8+:8]} <= {8'd0, queue_check_res_data[RCBASE+:8]};
                                   req_q_read_pos[i*8+:8] <= 'd0;
                                end else begin
                                   {req_q_tail[i*8+:8], req_q_head[i*8+:8]} <= {queue_check_res_data[RCBASE+32+:8], queue_check_res_data[RCBASE+:8]};
                                   req_q_read_pos[i*8+:8] <= queue_check_res_data[RCBASE+32+:8];
                                end
                            end
                        end
                    end else begin
                        if (queue_check_res_valid && i == check_ch) begin
                            if (check_cpl) begin
                                cpl_q_tail[i*8+:8] <= queue_check_res_data[RCBASE+32+:8];
                            end else begin
                                req_q_head[i*8+:8] <= queue_check_res_data[RCBASE+:8];
                            end
                        end
                        queue_head_tail_writes[i] <= queue_head_tail_writes[i] & ~queue_head_tail_written[i];
                        req_q_valids[i] <= req_q_read_pos[i*8+:8] != req_q_head[i*8+:8];

                        // although increment inflight at request_head_udpate_ch_valid,
                        // vacants are not used during queue element reading.
                        if ((request_head_update_ch_valid && request_head_update_ch == i) ||
                            (cpl_q_head_update && cpl_q_head_ch == i)) begin
                            // fall-down vacant signal 1cycle after request head updated.
                            cpl_q_vacants[i] <= 1'b0;
                        end else begin
                            cpl_q_vacants[i] <= cpl_q_head_inflight_p1 != cpl_q_tail[i*8+:8] &&
                                                cpl_q_head_p1 != cpl_q_tail[i*8+:8];
                        end
                    end

                    if (request_head_update_ch_valid && request_head_update_ch == i) begin
                        cpl_q_head_inflight[i*8+:8] <= cpl_q_head_inflight_p1;
                    end

                    if (init_q_addr_update_valids[1] && ~init_q_cpl && init_q_ch == i) begin
                        if (stream_ch_d2d_valids[i]) begin
                            req_q_head_addrs[i*64+:64] <= stream_req_q_bases[i*64+:64];
                        end else begin
                            req_q_head_addrs[i*64+:64] <= {init_q_head_addr_update[63:32] + init_q_head_addr_carry, init_q_head_addr_update[31:0]};
                        end
                    end else begin
                        if (req_q_head_update && req_q_head_ch == i) begin
                            req_q_head_addrs[i*64+:64] <= {req_q_head_addr_update[63:32] + req_q_head_addr_carry, req_q_head_addr_update[31:0]};
                            req_q_read_pos[i*8+:8] <= req_q_head_pos_update;
                        end
                        if (request_head_update_ch_valid && request_head_update_ch == i) begin
                            req_q_tail[i*8+:8] <= req_q_tail_p1;
                        end
                    end

                    if (init_q_addr_update_valids[1] && init_q_cpl && init_q_ch == i) begin
                        if (stream_ch_d2d_valids[i]) begin
                            cpl_q_head_addrs[i*64+:64] <= stream_cpl_q_bases[i*64+:64];
                        end else begin
                            cpl_q_head_addrs[i*64+:64] <= {init_q_head_addr_update[63:32] + init_q_head_addr_carry, init_q_head_addr_update[31:0]};
                        end
                        queue_head_tail_writes[i] <= queue_head_tail_writes[i] & ~queue_head_tail_written[i];
                    end else begin
                        if (cpl_q_head_update && cpl_q_head_ch == i) begin
                            cpl_q_head_addrs[i*64+:64] <= {cpl_q_head_addr_update[63:32] + cpl_q_head_addr_carry, cpl_q_head_addr_update[31:0]};
                            cpl_q_head[i*8+:8] <= cpl_q_head_pos_update;
                            queue_head_tail_writes[i] <= 1'b1;
                        end else begin
                            queue_head_tail_writes[i] <= queue_head_tail_writes[i] & ~queue_head_tail_written[i];
                        end
                    end
                end
            end
        end
    endgenerate

    // counterpart queue update
    wire [CH_NUM_LOG-1:0] cp_update_ch_next;
    wire                  cp_update_ch_next_valid;
    reg                   cp_queue_update_start;
    wire                  cp_queue_update_complete;

    ch_candidate #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .RR ( 0 )
    ) update_ch_candidate (
        .ch_valids ( queue_head_tail_writes ),
        .update ( cp_queue_update_start ),
        .candidate ( cp_update_ch_next ),
        .candidate_valid ( cp_update_ch_next_valid ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    reg [CH_NUM_LOG-1:0]  cp_update_ch;
    reg                   cp_update_cpl;
    reg                   cp_updating;

    always @(posedge clk) begin
        if (~resetn) begin
            cp_updating <= 1'b0;
            cp_update_ch <= 'd0;
            cp_update_cpl <= 1'b0;
            cp_queue_update_start <= 1'b0;
        end else if (~cp_updating) begin
            cp_updating <= cp_update_ch_next_valid;
            cp_update_ch <= cp_update_ch_next;
            cp_queue_update_start <= cp_update_ch_next_valid;
        end else begin
            cp_queue_update_start <= 1'b0;
            if (queue_update_valid && queue_update_ready) begin
                if (cp_update_cpl) begin
                    cp_updating <= 1'b0;
                    cp_update_cpl <= 1'b0;
                end else begin
                    cp_update_cpl <= 1'b1;
                end
            end
        end
    end
    assign cp_queue_update_complete = queue_update_valid & queue_update_ready & cp_update_cpl;

    generate
        for (genvar i=0; i<CH_NUM; i=i+1) begin
            assign queue_head_tail_written[i] = (cp_update_ch == i) && cp_queue_update_start;
        end
    endgenerate

    always @(posedge clk) begin
        if (~resetn) begin
            queue_update_data <= 'd0;
            queue_update_keep <= 'd0;
            queue_update_valid <= 1'b0;
        end else if (cp_queue_update_complete) begin
            queue_update_valid <= 1'b0;
        end else if (cp_updating & (~queue_update_valid | queue_update_ready)) begin
            if (cp_update_cpl || (queue_update_valid & queue_update_ready)) begin
                queue_update_data[63:2] <= (stream_cpl_q_head_tails >> {cp_update_ch, 6'd2}); // cpl head
                queue_update_data[128+:8] <= cpl_q_head >> {cp_update_ch, 3'd0};
            end else begin
                queue_update_data[63:2] <= (stream_req_q_head_tails >> {cp_update_ch, 6'd2}) + 1'b1; // req tail
                queue_update_data[128+:8] <= req_q_tail >> {cp_update_ch, 3'd0};
            end
            queue_update_data[128+32+:CH_NUM_LOG] <= cp_update_ch;
            queue_update_data[128+64] <= cp_update_cpl;
            queue_update_data[74:64] <= 'd1;
            queue_update_data[78:75] <= 4'd1;
            queue_update_keep[4:0] <= 5'h1f;
            queue_update_valid <= 1'b1;
        end
    end

    always @(posedge clk) begin
        if (~resetn) begin
            transfer_cpl_ch_done <= 1'b0;
        end else begin
            transfer_cpl_ch_done <= cpl_q_head_update;
        end
    end

    generate
        for (genvar i=0; i<CH_NUM; i=i+1) begin
            always @(posedge clk) begin
                if (~resetn) begin
                    dbg_cpl_counts[i*8+:8] <= 8'd0;
                    dbg_cpl_counts2[i*8+:8] <= 8'd0;
                end else begin
                    if (transfer_cpl_ch_valid && transfer_cpl_ch == i) begin
                        dbg_cpl_counts[i*8+:8] <= dbg_cpl_counts[i*8+:8] + 1'b1;
                    end
                    if (cpl_q_head_update && cpl_q_head_ch == i) begin
                        dbg_cpl_counts2[i*8+:8] <= dbg_cpl_counts2[i*8+:8] + 1'b1;
                    end
                end
            end
        end
    endgenerate

endmodule
