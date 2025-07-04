/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module stream_engine_queue_element #(
    parameter CH_NUM_LOG = 3,
    parameter QEW = 32,
    parameter QEW_LOG = 5,
    parameter RQ_DW = 384,
    parameter RQ_DK = 12,
    parameter RC_DW = 352,
    parameter RCBASE = 96,
    parameter QUEUE_READ_TAG = 98,
    parameter QESIZE_POS = 64,
    parameter ENABLE_QUEUE = 0,
    parameter QUEUE_DEPTH = 8,
    parameter [31:0] D2D_AXI_RANGE = 32'h4000_0000, // 1GB
    parameter ENABLE_FRAME_INFO_OUT = 0
    ) (
    input [(1<<CH_NUM_LOG)-1:0]                     stream_ch_valids,

    input [(1<<CH_NUM_LOG)-1:0]                     stream_ch_d2d_valids,
    input [(8<<CH_NUM_LOG)-1:0]                     stream_req_q_heads,
    input [(8<<CH_NUM_LOG)-1:0]                     stream_req_q_tails,

    input [(1<<CH_NUM_LOG)-1:0]                     initialized_queues,
    input [(1<<CH_NUM_LOG)-1:0]                     req_q_valids,
    input [(1<<CH_NUM_LOG)-1:0]                     cpl_q_vacants,
    input [(1<<CH_NUM_LOG)*64-1:0]                  req_q_addrs,

    output reg [RQ_DW-1:0]                          queue_rd_data,
    output reg [RQ_DK-1:0]                          queue_rd_keep,
    output reg                                      queue_rd_valid,
    input                                           queue_rd_ready,

    input [RC_DW-1:0]                               queue_rd_res_data,
    input                                           queue_rd_res_valid,

    output reg [CH_NUM_LOG-1:0]                     request_head_update_ch,
    output reg                                      request_head_update_ch_valid,

    output reg [(1<<QEW_LOG+3)*(1<<CH_NUM_LOG)-1:0] requests,
    output reg [(1<<CH_NUM_LOG)-1:0]                request_valids,
    output reg [(1<<CH_NUM_LOG)-1:0]                request_firsts,

    input [63:0]                                    updated_request_vaddr,
    input [31:0]                                    updated_request_size,
    input                                           updated_request_valid,
    input [CH_NUM_LOG-1:0]                          updated_request_ch,

    output [31:0]                                   frame_info_size,
    output [CH_NUM_LOG-1:0]                         frame_info_ch,
    output                                          frame_info_valid,
    input                                           frame_info_ready,

    input                                           clk,
    input                                           resetn
    );

    localparam CH_NUM = 1 << CH_NUM_LOG;
    localparam QEWB = QEW << 3;
    localparam QEWB_LOG = QEW_LOG + 3;

    wire [CH_NUM_LOG-1:0]  request_update_ch;
    wire                   request_update_ch_valid;

    reg                    qe_reading;
    reg [CH_NUM_LOG-1:0]   queue_rd_ch;
    wire                   frame_info_full;

    reg [(1<<QEW_LOG+3)*(1<<CH_NUM_LOG)-1:0] requests_back;
    reg [(1<<CH_NUM_LOG)-1:0]                request_valids_back;

    wire                   request_update_ch_update;

    ch_candidate #(
        .CH_NUM_LOG ( CH_NUM_LOG )
    ) request_update_ch_candidate (
        .ch_valids ( initialized_queues & ~request_valids_back & req_q_valids & cpl_q_vacants ),
        .update ( request_update_ch_update ),
        .candidate ( request_update_ch ),
        .candidate_valid ( request_update_ch_valid ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    reg                    queue_rd_res_valid_d1;
    always @(posedge clk) begin
        if (~resetn) begin
            queue_rd_res_valid_d1 <= 1'b0;
        end else begin
            queue_rd_res_valid_d1 <= queue_rd_res_valid;
        end
    end
    always @(posedge clk) begin
        if (~resetn) begin
            qe_reading <= 1'b0;
            queue_rd_data <= 'd0;
            queue_rd_keep <= 'd0;
            queue_rd_valid <= 1'b0;
            request_head_update_ch <= 'd0;
            request_head_update_ch_valid <= 1'b0;
        end else if (queue_rd_valid & queue_rd_ready) begin
            queue_rd_valid <= 1'b0;
            request_head_update_ch_valid <= 1'b0;
        end else if (~qe_reading & ~frame_info_full) begin
            queue_rd_valid <= request_update_ch_valid;
            queue_rd_data[63:2] <= req_q_addrs >> {request_update_ch, 6'd2};
            queue_rd_data[74:64] <= QEW >> 2; // dword count
            queue_rd_data[78:75] <= 4'd0; // memory read
            queue_rd_data[103:96] <= QUEUE_READ_TAG; // tag
            queue_rd_keep[3:0] <= 4'd15;
            queue_rd_ch <= request_update_ch;
            request_head_update_ch <= request_update_ch;
            request_head_update_ch_valid <= request_update_ch_valid;
            qe_reading <= request_update_ch_valid;
        end else begin
            if (qe_reading && queue_rd_res_valid_d1) begin
                qe_reading <= 1'b0;
            end
            request_head_update_ch_valid <= 1'b0;
        end
    end
    assign request_update_ch_update = queue_rd_res_valid_d1 && request_update_ch_valid;

    generate
        for (genvar i=0; i<CH_NUM; i=i+1) begin
            wire w_queue_res_valid = queue_rd_res_valid && i == queue_rd_ch;
            wire w_queue_update = request_valids[i] && i == updated_request_ch && updated_request_valid;
            wire w_queue_finish = w_queue_update && ~|updated_request_size;
            always @(posedge clk) begin
                if (~resetn || ~stream_ch_valids[i]) begin
                    requests[i*QEWB+:QEWB] <= 'd0;
                    request_valids[i] <= 1'b0;
                    request_firsts[i] <= 1'b0;
                end else if (w_queue_res_valid && (~request_valids[i] || w_queue_finish)) begin
                    requests[i*QEWB+:QEWB] <= queue_rd_res_data[RCBASE+:QEWB];
                    request_valids[i] <= 1'b1;
                    request_firsts[i] <= 1'b1;
                end else if (w_queue_update) begin
                    if (w_queue_finish) begin
                        requests[i*QEWB+:QEWB] <= requests_back[i*QEWB+:QEWB];
                        request_valids[i] <= request_valids_back[i];
                        request_firsts[i] <= 1'b1;
                    end else begin
                        requests[i*QEWB+:QEWB] <= {requests[(i+1)*QEWB-1:i*QEWB+96], updated_request_size, updated_request_vaddr};
                        request_valids[i] <= |updated_request_size;
                        request_firsts[i] <= 1'b0;
                    end
                end
            end
            always @(posedge clk) begin
                if (~resetn || ~stream_ch_valids[i]) begin
                    requests_back[i*QEWB+:QEWB] <= 'd0;
                    request_valids_back[i] <= 1'b0;
                end else if (w_queue_res_valid && (request_valids[i] && ~w_queue_finish)) begin
                    requests_back[i*QEWB+:QEWB] <= queue_rd_res_data[RCBASE+:QEWB];
                    request_valids_back[i] <= 1'b1;
                end else if (w_queue_finish) begin
                    request_valids_back[i] <= 1'b0;
                end
            end
        end
    endgenerate

    generate
       if (ENABLE_FRAME_INFO_OUT != 0) begin
          wire [CH_NUM_LOG-1:0] w_d2d_frame_info_ch;
          wire                  w_d2d_frame_info_valid;
          reg [63:0] frame_info_sizes;
          reg [CH_NUM_LOG*2-1:0] frame_info_chs;
          reg [1:0]              frame_info_valids;
          always @(posedge clk) begin
             if (~resetn) begin
                frame_info_valids <= 2'd0;
             end else if (queue_rd_res_valid) begin
                if (frame_info_valids[0] && ~frame_info_ready) begin
                   frame_info_valids[1] <= |queue_rd_res_data[RCBASE+QESIZE_POS+:32];
                   frame_info_chs[CH_NUM_LOG+:CH_NUM_LOG] <= queue_rd_ch;
                   frame_info_sizes[32+:32] <= queue_rd_res_data[RCBASE+QESIZE_POS+:32];
                end else begin
                   frame_info_valids[0] <= |queue_rd_res_data[RCBASE+QESIZE_POS+:32];
                   frame_info_chs[0+:CH_NUM_LOG] <= queue_rd_ch;
                   frame_info_sizes[0+:32] <= queue_rd_res_data[RCBASE+QESIZE_POS+:32];
                end
             end else if (w_d2d_frame_info_valid && ~frame_info_full && ~qe_reading && ~request_update_ch_valid) begin
                if (frame_info_valids[0] && ~frame_info_ready) begin
                   frame_info_valids[1] <= 1'b1;
                   frame_info_chs[CH_NUM_LOG+:CH_NUM_LOG] <= w_d2d_frame_info_ch;
                   frame_info_sizes[32+:32] <= D2D_AXI_RANGE;
                end else begin
                   frame_info_valids[0] <= 1'b1;
                   frame_info_chs[0+:CH_NUM_LOG] <= w_d2d_frame_info_ch;
                   frame_info_sizes[0+:32] <= D2D_AXI_RANGE;
                end
             end else if (frame_info_ready) begin
                frame_info_valids <= frame_info_valids >> 1;
                frame_info_chs <= frame_info_chs >> CH_NUM_LOG;
                frame_info_sizes <= frame_info_sizes >> 32;
             end
          end
          assign frame_info_full = frame_info_valids[1];
          assign frame_info_size = frame_info_sizes[31:0];
          assign frame_info_ch = frame_info_chs[CH_NUM_LOG-1:0];
          assign frame_info_valid = frame_info_valids[0];

          if (ENABLE_QUEUE>0) begin
             reg [8*CH_NUM-1:0] d2d_req_q_inflight_bases;
             reg [CH_NUM-1:0]   d2d_req_q_inflight_base_valids;
             reg [CH_NUM_LOG-1:0] d2d_head_tail_check_ch;
             wire [CH_NUM-1:0]    w_d2d_req_q_inflight_enables;
             always @(posedge clk) begin
                if (~resetn) begin
                   d2d_head_tail_check_ch <= 'd0;
                end else if (~frame_info_full) begin
                   d2d_head_tail_check_ch <= d2d_head_tail_check_ch + 1'b1;
                end
             end
             for (genvar i=0; i<CH_NUM; i=i+1) begin
                wire [7:0] w_next_req_q_head = (stream_req_q_heads[8*i+:8] + 1'b1) & (QUEUE_DEPTH-1);
                always @(posedge clk) begin
                   if (~resetn || ~stream_ch_valids[i]) begin
                      d2d_req_q_inflight_base_valids[i] <= 1'b0;
                   end else if (w_d2d_req_q_inflight_enables[i] && ~frame_info_full && ~qe_reading && ~request_update_ch_valid) begin
                      d2d_req_q_inflight_base_valids[i] <= 1'b1;
                      d2d_req_q_inflight_bases[8*i+:8] <= w_next_req_q_head;
                   end
                end
                assign w_d2d_req_q_inflight_enables[i] = stream_ch_d2d_valids[i] && d2d_head_tail_check_ch == i &&
                                                         w_next_req_q_head != stream_req_q_tails[8*i+:8] && ~frame_info_full &&
                                                         (~d2d_req_q_inflight_base_valids[i] || d2d_req_q_inflight_bases[8*i+:8] == stream_req_q_heads[8*i+:8]);
             end
             assign w_d2d_frame_info_ch = d2d_head_tail_check_ch;
             assign w_d2d_frame_info_valid = w_d2d_req_q_inflight_enables >> d2d_head_tail_check_ch;
          end else begin
             assign w_d2d_frame_info_valid = 1'b0;
          end
       end else begin
          assign frame_info_full = 1'b0;
          assign frame_info_size = 32'd0;
          assign frame_info_ch = {CH_NUM_LOG{1'b0}};
          assign frame_info_valid = 1'b0;
       end
    endgenerate
endmodule
