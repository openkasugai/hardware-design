/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_queue_head_tail #(
    parameter CH_NUM_LOG = 3,
    parameter RQ_DW = 384,
    parameter RQ_DK = 12,
    parameter RC_DW = 352,
    parameter QEW_LOG = 5,
    parameter RQBASE = 128,
    parameter RCBASE = 96,
    parameter READ_QE_BITS = 1,
    parameter CPL_VALID_BITS = 4,
    parameter CPL_TAIL_VALID_BITS = 4,
    parameter QUEUE_CHECK_TAG = 99,
    parameter CHECK_INTERVAL = 200,
    parameter INITIALIZE_INTERVAL = 10,
    parameter UPDATE_INTERVAL = 30,
    parameter [(1<<CH_NUM_LOG)-1:0] CH_VALIDS = 8'h80,
    parameter FIXED_CH_VALIDS = 0,
    parameter TEST_CASE = 0,
    parameter ENABLE_QUEUE = 0,
    parameter REQUEST_NUM = 1000
    ) ();

    wire clk, resetn;
    wire [31:0] rd;
    clk_reset clk_reset(
        .clk ( clk ),
        .resetn ( resetn ),
        .rd ( rd )
    );

    localparam CH_NUM = 1 << CH_NUM_LOG;

    reg [CH_NUM-1:0]     stream_ch_valids;
    reg [CH_NUM-1:0]     stream_ch_d2d_valids;
    reg [CH_NUM*64-1:0]  stream_req_q_bases;
    reg [CH_NUM*64-1:0]  stream_cpl_q_bases;
    reg [CH_NUM*8-1:0]   stream_req_q_depth;
    reg [CH_NUM*8-1:0]   stream_cpl_q_depth;
    reg [CH_NUM*64-1:0]  stream_req_q_head_tails;
    reg [CH_NUM*64-1:0]  stream_cpl_q_head_tails;

    reg [15:0]           stream_check_interval;
    reg [CH_NUM_LOG:0]   stream_ch_valid_num;
    reg [CH_NUM_LOG:0]   stream_ch_doorbell_num;

    reg [RC_DW-1:0]      queue_check_res_data;
    reg                  queue_check_res_valid;

    wire [RQ_DW-1:0]     queue_check_data;
    wire [RQ_DK-1:0]     queue_check_keep;
    wire                 queue_check_valid;
    reg                  queue_check_ready;

    wire [RQ_DW-1:0]     queue_update_data;
    wire [RQ_DK-1:0]     queue_update_keep;
    wire                 queue_update_valid;
    reg                  queue_update_ready;

    wire [CH_NUM*64-1:0] req_q_head_addrs;
    wire [CH_NUM*64-1:0] cpl_q_head_addrs;

    wire [CH_NUM-1:0]    req_q_valids;
    wire [CH_NUM-1:0]    cpl_q_vacants;
    wire [CH_NUM-1:0]    initialized_queues;

    reg [CH_NUM-1:0]     queue_errors;

    reg [3:0]            ctrl_reg_waddr;
    reg [31:0]           ctrl_reg_wdata;
    reg [CH_NUM_LOG-1:0] ctrl_reg_wch;
    reg                  ctrl_reg_wen;

    reg [CH_NUM-1:0]      stream_check_requests;
    reg [CH_NUM-1:0]      stream_ch_check_with_doorbells;
    wire [CH_NUM_LOG-1:0] stream_check_ch;
    wire                  stream_check_done;

    reg [CH_NUM_LOG-1:0] request_head_update_ch;
    reg                  request_head_update_ch_valid;

    reg [CH_NUM_LOG-1:0] transfer_cpl_ch;
    reg                  transfer_cpl_ch_valid;
    wire                 transfer_cpl_ch_done;

    initial begin
        ctrl_reg_waddr = 4'd0;
        ctrl_reg_wdata = 32'd0;
        ctrl_reg_wch = 'd0;
        ctrl_reg_wen = 1'b0;
        queue_errors = 'd0;
        stream_ch_valids = 'd0;
        stream_ch_d2d_valids = 'd0;
        stream_req_q_bases = 'd0;
        stream_cpl_q_bases = 'd0;
        stream_req_q_depth = 'd0;
        stream_cpl_q_depth = 'd0;
        stream_req_q_head_tails = 'd0;
        stream_cpl_q_head_tails = 'd0;
        stream_check_interval = CHECK_INTERVAL;
        stream_ch_valid_num = 'd0;
        stream_ch_doorbell_num = 'd0;
        queue_check_ready = 'b0;
        queue_update_ready = 'b0;
        request_head_update_ch = 'd0;
        request_head_update_ch_valid = 1'b0;
        transfer_cpl_ch = 'd0;
        transfer_cpl_ch_valid = 1'b0;
        stream_check_requests = 'd0;
        stream_ch_check_with_doorbells = 'd0;
    end

    stream_engine_queue_head_tail #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .ENABLE_QUEUE ( ENABLE_QUEUE ),
        .RQ_DW ( RQ_DW ),
        .RQ_DK ( RQ_DK ),
        .RC_DW ( RC_DW ),
        .QEW_LOG ( QEW_LOG ),
        .RCBASE ( RCBASE ),
        .QUEUE_CHECK_TAG ( QUEUE_CHECK_TAG )
    ) dut (
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
        .clk ( clk ),
        .resetn ( resetn )
    );

    // queue check/update packet
    reg [7:0] req_queue_head[0:CH_NUM-1];
    reg [7:0] req_queue_read_pos[0:CH_NUM-1];
    reg [7:0] req_queue_tail[0:CH_NUM-1];
    reg [7:0] cpl_queue_head[0:CH_NUM-1];
    reg [7:0] cpl_queue_tail[0:CH_NUM-1];
    reg       req_queue_tail_updates[0:CH_NUM-1];
    reg       cpl_queue_head_updates[0:CH_NUM-1];
    reg [31:0] cpl_tail_counts[0:CH_NUM-1];

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
                end else begin
                    queue_check_res_data[RCBASE+:8] <= cpl_queue_head[check_q_head_tail_ch];
                    queue_check_res_data[RCBASE+32+:8] <= cpl_queue_tail[check_q_head_tail_ch];
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
                $display("%d [%2d]: queue update: %s value: %h", $time, update_q_head_tail_ch,
                         is_update_req_head_tail ? "req_tail" : "cpl_head", queue_update_data[128+:8]);
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
    reg [CH_NUM_LOG-1:0] cpl_tail_ch;
    always @(posedge clk) begin
        if (~resetn) begin
            cpl_tail_ch <= 'd0;
            for (int i=0; i<CH_NUM; i++) cpl_tail_counts[i] <= 'd0;
        end else if (&rd[27-:CPL_TAIL_VALID_BITS]) begin
            if (cpl_queue_head[cpl_tail_ch] != cpl_queue_tail[cpl_tail_ch]) begin
                if (cpl_queue_tail[cpl_tail_ch] + 1'b1 < stream_cpl_q_depth[cpl_tail_ch*8+:8]) begin
                    cpl_queue_tail[cpl_tail_ch] <= cpl_queue_tail[cpl_tail_ch] + 1'b1;
                end else begin
                    cpl_queue_tail[cpl_tail_ch] <= 'd0;
                end
                stream_check_requests[cpl_tail_ch] <= 1'b1;
                cpl_tail_counts[cpl_tail_ch] <= cpl_tail_counts[cpl_tail_ch] + 1'b1;
                $display("%d [%2d]: update cpl tail: %h, count: %h", $time, cpl_tail_ch,
                         cpl_queue_tail[cpl_tail_ch], cpl_tail_counts[cpl_tail_ch]);
            end
            cpl_tail_ch <= cpl_tail_ch + 1'b1;
        end
    end
    always @(posedge clk) begin
        if (resetn && stream_check_done) begin
            stream_check_requests[stream_check_ch] <= 1'b0;
        end
    end
    task static initialize_queues();
        int          i, j;
        // initialize registers
        for (i=0; i<CH_NUM; i++) begin
            @(posedge clk) begin
                stream_ch_valids[i] <= 1'b0;
                stream_req_q_bases[i*64+:64] <= {rd      , rd[31:5], 5'd0};
                stream_cpl_q_bases[i*64+:64] <= {rd[30:0], rd[31:4], 5'd0};
                stream_req_q_head_tails[i*64+:64] <= {rd[29:0], rd[31:3], 5'd0};
                stream_cpl_q_head_tails[i*64+:64] <= {rd[28:0], rd[31:2], 5'd0};
                stream_req_q_depth[i*8+:8] <= {5'd0, rd[3:1]} + 2'd3;
                stream_cpl_q_depth[i*8+:8] <= {5'd0, rd[23:21]} + 2'd3;
                req_queue_head[i] <= 8'd0 | (rd[24+:CH_NUM_LOG] % ({5'd0, rd[3:1]} + 2'd2));
                req_queue_read_pos[i] <= 8'd0 | (rd[24+:CH_NUM_LOG] % ({5'd0, rd[3:1]} + 2'd2));
                req_queue_tail[i] <= 8'd0 | (rd[24+:CH_NUM_LOG] % ({5'd0, rd[3:1]} + 2'd2));
                cpl_queue_head[i] <= 8'd0 | (rd[20+:CH_NUM_LOG] % ({5'd0, rd[23:21]} + 2'd2));
                cpl_queue_tail[i] <= 8'd0 | (rd[20+:CH_NUM_LOG] % ({5'd0, rd[23:21]} + 2'd2));
            end
        end

        // set channel valid
        for (i=0; i<CH_NUM; i++) begin
            @(posedge clk) begin
                ctrl_reg_waddr <= 4'd0;
                ctrl_reg_wdata <= FIXED_CH_VALIDS>0 ? {32{CH_VALIDS[i]}} : rd;
                ctrl_reg_wch <= 'd0 | i;
                ctrl_reg_wen <= 1'b1;
                stream_ch_valid_num <= stream_ch_valid_num + ((FIXED_CH_VALIDS>0 ? CH_VALIDS[i] : rd[0]) && (ENABLE_QUEUE==0 || ~rd[4]));
                stream_ch_doorbell_num <= stream_ch_doorbell_num + ((FIXED_CH_VALIDS>0 ? CH_VALIDS[i] : rd[0]) && (ENABLE_QUEUE==0 || ~rd[4]) && rd[8]);
                stream_ch_valids[i] <= FIXED_CH_VALIDS>0 ? CH_VALIDS[i] : rd[0];
                stream_ch_d2d_valids[i] <= (FIXED_CH_VALIDS>0 ? CH_VALIDS[i] : rd[0]) & rd[4];
                if ((FIXED_CH_VALIDS>0 ? CH_VALIDS[i] : rd[0]) & rd[4]) begin
                   req_queue_head[i] <= 8'd0;
                   req_queue_read_pos[i] <= 8'd0;
                   req_queue_tail[i] <= 8'd0;
                   cpl_queue_head[i] <= 8'd0;
                   cpl_queue_tail[i] <= 8'd0;
                end
                stream_ch_check_with_doorbells[i] <= (FIXED_CH_VALIDS>0 ? CH_VALIDS[i] : rd[0]) & rd[8];
            end
            @(posedge clk) ctrl_reg_wen <= 1'b0;

            $display("initialize queue[%2d]: req head/tail=%d, depth=%d, base=%h", i,
                     req_queue_head[i], req_queue_tail[i], stream_req_q_depth[i*8+:8], stream_req_q_bases[i*64+:64]);
            $display("initialize queue[%2d]: cpl head/tail=%d, depth=%d, base=%h", i,
                     cpl_queue_head[i], cpl_queue_tail[i], stream_cpl_q_depth[i*8+:8], stream_cpl_q_bases[i*64+:64]);

            for (j=0; j<INITIALIZE_INTERVAL; j++) @(posedge clk);
        end
        // wait initialized
        if (ENABLE_QUEUE == 0) begin
           while (initialized_queues !== stream_ch_valids) @(posedge clk);
        end else begin
           while (initialized_queues !== (stream_ch_valids & ~stream_ch_d2d_valids)) @(posedge clk);
        end
    endtask

    task static add_request(inout reg [CH_NUM-1:0] add_queue);
        int i, j;
        for (i=0; i<CH_NUM; i++) begin
            for (j=0; j<UPDATE_INTERVAL; j++) @(posedge clk);
            @(posedge clk) begin
                if (rd[i] && stream_ch_valids[i] && (ENABLE_QUEUE==0 || ~stream_ch_d2d_valids[i])) begin
                    if (req_queue_head[i] + 1'b1 == stream_req_q_depth[i*8+:8]) begin
                        if (req_queue_tail[i] != 'd0) begin
                            req_queue_head[i] <= 'd0;
                            add_queue[i] = 1'b1;
                        end
                    end else begin
                        if (req_queue_tail[i] != req_queue_head[i] + 1'b1) begin
                            req_queue_head[i] <= req_queue_head[i] + 1'b1;
                            add_queue[i] = 1'b1;
                        end
                    end
                    if (stream_ch_check_with_doorbells[i]) begin
                       stream_check_requests[i] <= 1'b1;
                    end
                end
            end
        end
    endtask

    reg [31:0]         add_requests_ch[0:CH_NUM-1];
    reg [31:0]         transferring_ch[0:CH_NUM-1];
    reg [31:0]         fin_requests_ch[0:CH_NUM-1];

    task static add_request_random();
        int i, j;
        logic [31:0] count = 0;
        logic [CH_NUM_LOG-1:0] ch;
        while (count < REQUEST_NUM) begin
            @(posedge clk) begin
                ch = rd[CH_NUM_LOG-1:0];
                if (rd[23] && stream_ch_valids[ch] && (ENABLE_QUEUE==0 || ~stream_ch_d2d_valids[ch])) begin
                    if (req_queue_head[ch] + 1'b1 == stream_req_q_depth[ch*8+:8]) begin
                        if (req_queue_tail[ch] != 'd0) begin
                            req_queue_head[ch] <= 'd0;
                            add_requests_ch[ch] = add_requests_ch[ch] + 1'b1;
                            count <= count + 1'b1;
                            $display("%d [%2d]: add request %h %h", $time, ch, req_queue_head[ch], add_requests_ch[ch]);
                        end
                    end else begin
                        if (req_queue_tail[ch] != req_queue_head[ch] + 1'b1) begin
                            req_queue_head[ch] <= req_queue_head[ch] + 1'b1;
                            add_requests_ch[ch] = add_requests_ch[ch] + 1'b1;
                            count <= count + 1'b1;
                            $display("%d [%2d]: add request %h %h", $time, ch, req_queue_head[ch], add_requests_ch[ch]);
                        end
                    end
                    if (stream_ch_check_with_doorbells[ch]) begin
                       stream_check_requests[ch] <= 1'b1;
                    end
                end
            end
        end
        $display("finish: add request");
    endtask

    task static check_req_queue_addr(input reg [CH_NUM-1:0] add_queue, input reg fin_queue[0:CH_NUM-1]);
        int i, j;
        reg [15:0] count;
        reg pass;

        pass = 1'b0;
        count = 'd0;
        while (!pass && count < 'd10000) begin
            @(posedge clk) begin
                pass = 1'b1;
                for (i=0; i<CH_NUM; i++) begin
                    if (stream_ch_valids[i] && (ENABLE_QUEUE == 0 || ~stream_ch_d2d_valids[i]) &&
                        ((req_q_valids[i] ^ add_queue[i] ^ fin_queue[i]) ||
                         (req_q_head_addrs[i*64+:64] !== stream_req_q_bases[i*64+:64] + {req_queue_read_pos[i], {QEW_LOG{1'b0}}}))) begin
                        pass = 1'b0;
                        count <= count + 1'b1;
`ifdef DEBUG
                        $display("%d: [%d] valid=%h, req_q_valid=%h, stream_req_q_bases=%h, depth=%h, head_eq=%d", $time, i,
                                 stream_ch_valids[i], req_q_valids[i], stream_req_q_bases[i*64+:64], stream_req_q_depth[i*8+:8],
                                 req_q_head_addrs[i*64+:64] === stream_req_q_bases[i*64+:64] + {req_queue_read_pos[i], {QEW_LOG{1'b0}}});
                        $display("%d: [%d] req_q_head_addrs=%h req_queue_head=%h req_queue_tail=%h, %h, %h %h", $time, i,
                                 req_q_head_addrs[i*64+:64], req_queue_read_pos[i], req_queue_tail[i],
                                 stream_req_q_bases[i*64+:64] + {req_queue_tail[i], {QEW_LOG{1'b0}}}, req_q_valids[i] ^ add_queue[i],
                                 stream_req_q_bases[i*64+:64] + {req_queue_read_pos[i], {QEW_LOG{1'b0}}});
`endif
                        break;
                    end
                end
            end
        end
        @(posedge clk) begin
            if (pass == 0) #100 $error("req queue address wrong.");
        end
    endtask

    task static check_cpl_queue_addr(inout reg fin_queue[0:CH_NUM-1]);
        int i, j;
        reg [15:0] count;
        reg pass;

        pass = 1'b0;
        count = 'd0;
        while (!pass && count < 'd10000) begin
            @(posedge clk) begin
                pass = 1'b1;
                for (i=0; i<CH_NUM; i++) begin
                    if (stream_ch_valids[i] && (ENABLE_QUEUE == 0 || ~stream_ch_d2d_valids[i]) &&
                        (((~cpl_q_vacants[i] ^ stream_cpl_q_depth[i*8+:8] == 'd2) && fin_queue[i]) ||
                         (cpl_q_head_addrs[i*64+:64] !== stream_cpl_q_bases[i*64+:64] + {cpl_queue_head[i], {QEW_LOG{1'b0}}}))) begin
                        pass = 1'b0;
                        count <= count + 1'b1;
`ifdef DEBUG
                        $display("%d: [%d] valid=%h, cpl_q_vacant=%h, stream_cpl_q_bases=%h, head_eq=%d", $time, i,
                                 stream_ch_valids[i], cpl_q_vacants[i], stream_cpl_q_bases[i*64+:64],
                                 cpl_q_head_addrs[i*64+:64] === stream_cpl_q_bases[i*64+:64] + {cpl_queue_head[i], {QEW_LOG{1'b0}}});
                        $display("%d: [%d] cpl_q_head_addrs=%h cpl_queue_head=%h", $time, i, cpl_q_head_addrs[i*64+:64], cpl_queue_head[i]);
`endif
                        break;
                    end
                end
            end
        end
        @(posedge clk) begin
            if (pass == 0) begin
                #100 $error("cpl queue address wrong.");
            end else begin
                for (i=0; i<CH_NUM; i++) fin_queue[i] <= 1'b0;
            end
        end
    endtask

    task static read_queue_element(inout reg read_requests[0:CH_NUM-1]);
        int i, j;
        for (i=0; i<CH_NUM; i++) begin
            for (j=0; j<UPDATE_INTERVAL; j++) @(posedge clk);
            @(posedge clk) begin
                if (~read_requests[i] & |rd[i+2+:4] & req_q_valids[i] & cpl_q_vacants[i]) begin
                    request_head_update_ch <= i;
                    request_head_update_ch_valid <= 1'b1;
                    read_requests[i] = 1'b1;
                    req_queue_read_pos[i] <= req_queue_read_pos[i] + 1'b1 == stream_req_q_depth[i*8+:8] ? 'd0 : req_queue_read_pos[i] + 1'b1;
                    $display("read queue element[%d]", i);
                end
            end
            @(posedge clk) request_head_update_ch_valid <= 1'b0;
        end
    endtask

    task static read_queue_element_random();
        int i, j;
        logic [31:0]  count = 0;
        logic [CH_NUM_LOG-1:0] ch;
        while (count < REQUEST_NUM) begin
            @(posedge clk) begin
                ch = rd[4+:CH_NUM_LOG];
                if (add_requests_ch[ch] > transferring_ch[ch] && |rd[ch+8+:READ_QE_BITS] && req_q_valids[ch] && cpl_q_vacants[ch]) begin
                    request_head_update_ch <= ch;
                    request_head_update_ch_valid <= 1'b1;
                    transferring_ch[ch] <= transferring_ch[ch] + 1'b1;
                    req_queue_read_pos[ch] <= req_queue_read_pos[ch] + 1'b1 == stream_req_q_depth[ch*8+:8] ? 'd0 : req_queue_read_pos[ch] + 1'b1;
                    count <= count + 1'b1;
                    $display("%d [%2d] read queue element: %h", $time, ch, transferring_ch[ch]);
                end else if (add_requests_ch[ch]) begin
                    //$display("read queue element[%d]: rand:%h, valid:%h, vacant:%h", ch,
                    //         |rd[ch+8+:READ_QE_BITS], req_q_valids[ch], cpl_q_vacants[ch]);
                end else if (|rd[ch+8+:READ_QE_BITS] && req_q_valids[ch] && cpl_q_vacants[ch]) begin
                    //$display("read queue element[%d]: request:%h rand:%h, valid:%h, vacant:%h", ch,
                    // add_requests_ch[ch], |rd[ch+8+:READ_QE_BITS], req_q_valids[ch], cpl_q_vacants[ch]);
                end
            end
            @(posedge clk) request_head_update_ch_valid <= 1'b0;
        end
        $display("finish: read qe");
    endtask

    task static transfer_completes(inout reg read_requests[0:CH_NUM-1], inout reg fin_requests[0:CH_NUM-1]);
        int i, j;
        reg transfer_cpl_wait;
        for (i=0; i<CH_NUM; i++) begin
            for (j=0; j<UPDATE_INTERVAL; j++) @(posedge clk);
            @(posedge clk) begin
                if (|rd[i+:CPL_VALID_BITS] & read_requests[i] & cpl_q_vacants[i]) begin
                    transfer_cpl_ch <= i;
                    transfer_cpl_ch_valid <= 1'b1;
                    transfer_cpl_wait <= 1'b1;
                    read_requests[i] = 1'b0;
                    fin_requests[i] = 1'b1;
                    $display("transfer completion[%d]", i);
                end else begin
                    transfer_cpl_wait <= 1'b0;
                end
            end
            do @(posedge clk) transfer_cpl_ch_valid <= 1'b0; while (transfer_cpl_wait & ~transfer_cpl_ch_done);
        end
        @(posedge clk) $display("transfer complete fin");
    endtask

    task static transfer_completes_random();
        int i, j;
        reg transfer_cpl_wait;
        logic [31:0] count = 0;
        logic [CH_NUM_LOG-1:0] ch;
        logic                  finished = 1'b0;
        logic [31:0]           watchdog = 'd0;
        while (count < REQUEST_NUM) begin
            @(posedge clk) begin
                ch = rd[8+:CH_NUM_LOG];
                if (&rd[12+:CPL_VALID_BITS] && transferring_ch[ch] > fin_requests_ch[ch]/* && cpl_q_vacants[ch]*/) begin
                    transfer_cpl_ch <= ch;
                    transfer_cpl_ch_valid <= 1'b1;
                    transfer_cpl_wait <= 1'b1;
                    fin_requests_ch[ch] <= fin_requests_ch[ch] + 1'b1;
                    $display("%d [%2d] transfer completion: %h", $time, ch, fin_requests_ch[ch]);
                    count <= count + 1'b1;
                end else begin
                    transfer_cpl_wait <= 1'b0;
                end
            end
            do @(posedge clk) transfer_cpl_ch_valid <= 1'b0; while (transfer_cpl_wait & ~transfer_cpl_ch_done);
        end
        @(posedge clk) $display("transfer complete fin");
        while (~finished && watchdog < 'd100000) begin
            @(posedge clk) watchdog <= watchdog + 1'b1;
            finished = 1'b1;
            for (i=0; i<CH_NUM; i++) begin
                if (fin_requests_ch[ch] != cpl_tail_counts[ch]) finished = 1'b0;
            end
        end
        if (~finished) $fatal(2, "cpl tail not finished\n");
    endtask

    wire [32*CH_NUM-1:0] add_requests_chs;
    wire [32*CH_NUM-1:0] transferring_chs;
    wire [32*CH_NUM-1:0] fin_requests_chs;
    generate
        for (genvar ii=0; ii<CH_NUM; ii++) begin
            assign add_requests_chs[ii*32+:32] = add_requests_ch[ii];
            assign transferring_chs[ii*32+:32] = transferring_ch[ii];
            assign fin_requests_chs[ii*32+:32] = fin_requests_ch[ii];
        end
    endgenerate

    initial begin
        int i;
        reg [CH_NUM-1:0] add_requests;
        reg transferring[0:CH_NUM-1];
        reg fin_requests[0:CH_NUM-1];

        while (resetn !== 1'b1) @(posedge clk);
        for (i=0; i<CH_NUM; i++) begin
            add_requests[i] = 1'b0;
            transferring[i] = 1'b0;
            fin_requests[i] = 1'b0;
            add_requests_ch[i] = 'b0;
            transferring_ch[i] = 'b0;
            fin_requests_ch[i] = 'b0;
        end

        case(TEST_CASE)
            0 : initialize_queues;
            1 : begin
                initialize_queues;
                add_request(add_requests);
                check_req_queue_addr(add_requests, fin_requests);
                read_queue_element(transferring);
                transfer_completes(transferring, fin_requests);
                check_req_queue_addr(add_requests, fin_requests);
                check_cpl_queue_addr(fin_requests);
            end
            2 : begin
                initialize_queues;
                fork
                    begin
                        add_request_random();
                    end
                    begin
                        read_queue_element_random();
                    end
                    begin
                        transfer_completes_random();
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

module test_queue_head_tail_initialize();

    tb_queue_head_tail tb();

endmodule

module test_queue_head_tail_update();

    tb_queue_head_tail #(
        .TEST_CASE ( 1 )
    ) tb();

endmodule

module test_queue_head_tail_update_max();

    tb_queue_head_tail #(
        .TEST_CASE ( 2 ),
        .UPDATE_INTERVAL ( 3 ),
        .READ_QE_BITS ( 1 ),
        .CPL_VALID_BITS ( 2 ),
        .CPL_TAIL_VALID_BITS ( 7 )
    ) tb();

endmodule

module test_queue_head_tail_update_fixed_ch();

    tb_queue_head_tail #(
        .TEST_CASE ( 1 ),
        .CH_NUM_LOG ( 4 ),
        .CH_VALIDS ( 16'h8000 ),
        .FIXED_CH_VALIDS ( 1 )
    ) tb();

endmodule

module test_queue_head_tail_initialize_d2d();

    tb_queue_head_tail #(
        .ENABLE_QUEUE ( 1 )
    ) tb ();

endmodule

module test_queue_head_tail_update_d2d();

    tb_queue_head_tail #(
        .ENABLE_QUEUE ( 1 ),
        .TEST_CASE ( 2 )
    ) tb();

endmodule
