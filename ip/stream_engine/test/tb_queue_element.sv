/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_queue_element #(
    parameter CH_NUM_LOG = 3,
    parameter RQ_DW = 384,
    parameter RQ_DK = 12,
    parameter RC_DW = 352,
    parameter QEW = 32,
    parameter QEW_LOG = 5,
    parameter RQBASE = 128,
    parameter RCBASE = 96,
    parameter QUEUE_READ_TAG = 98,
    parameter CHECK_INTERVAL = 200,
    parameter INITIALIZE_INTERVAL = 10,
    parameter UPDATE_INTERVAL = 30,
    parameter TEST_CASE = 0,
    parameter ENABLE_FRAME_INFO_OUT = 0,
    parameter FRAME_INFO_READY_BITS = 0,
    parameter ENABLE_QUEUE = 0,
    parameter QUEUE_DEPTH = 8,
    parameter [31:0] D2D_AXI_RANGE = 32'h4000_0000
    ) ();

    wire clk, resetn;
    wire [31:0] rd;
    clk_reset clk_reset(
        .clk ( clk ),
        .resetn ( resetn ),
        .rd ( rd )
    );

    localparam CH_NUM = 1 << CH_NUM_LOG;
    localparam QEWB = QEW << 3;
    localparam QEWB_LOG = QEW_LOG + 3;
    localparam FRAME_INFO_READY_BITS_MOD = FRAME_INFO_READY_BITS > 0 ? FRAME_INFO_READY_BITS : 1'b1;

    reg [CH_NUM*64-1:0]    stream_req_q_bases;
    reg [CH_NUM*8-1:0]    stream_req_q_depth;

    reg [RC_DW-1:0]       queue_rd_res_data;
    reg                   queue_rd_res_valid;

    wire [RQ_DW-1:0]      queue_rd_data;
    wire [RQ_DK-1:0]      queue_rd_keep;
    wire                  queue_rd_valid;
    reg                   queue_rd_ready;

    wire [QEWB*CH_NUM-1:0] requests;
    wire [CH_NUM-1:0]      request_valids;
    wire [CH_NUM-1:0]      request_firsts;

    reg [CH_NUM-1:0]       stream_ch_valids;
    reg [CH_NUM-1:0]       initialized_queues;
    reg [CH_NUM-1:0]       stream_ch_d2d_valids;
    reg [8*CH_NUM-1:0]     stream_req_q_heads;
    reg [8*CH_NUM-1:0]     stream_req_q_tails;

    reg [CH_NUM-1:0]       req_q_valids;
    reg [CH_NUM-1:0]       cpl_q_vacants;
    reg [CH_NUM*64-1:0]    req_q_head_addrs;

    reg [63:0]             updated_request_vaddr;
    reg [31:0]             updated_request_size;
    reg                    updated_request_valid;
    reg [CH_NUM_LOG-1:0]   updated_request_ch;

    wire [CH_NUM_LOG-1:0]  request_head_update_ch;
    wire                   request_head_update_ch_valid;

    wire [31:0]            frame_info_size;
    wire [CH_NUM_LOG-1:0]  frame_info_ch;
    wire                   frame_info_valid;
    reg                    frame_info_ready;

    initial begin
        stream_req_q_bases = 'd0;
        stream_req_q_depth = 'd0;
        queue_rd_res_data = 'd0;
        queue_rd_res_valid = 1'b0;
        queue_rd_ready = 1'b0;
        initialized_queues = 'd0;
        stream_ch_valids = 'd0;
        stream_ch_d2d_valids = 'd0;
        stream_req_q_heads = 'd0;
        stream_req_q_tails = 'd0;
        req_q_valids = 'd0;
        cpl_q_vacants = 'd0;
        req_q_head_addrs = 'd0;
        updated_request_vaddr = 'd0;
        updated_request_size = 'd0;
        updated_request_valid = 1'b0;
        updated_request_ch = 'd0;
        frame_info_ready = 1'b1;
    end

    stream_engine_queue_element #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .QEW ( QEW ),
        .QEW_LOG ( QEW_LOG ),
        .RQ_DW ( RQ_DW ),
        .RQ_DK ( RQ_DK ),
        .RC_DW ( RC_DW ),
        .RCBASE ( RCBASE ),
        .QUEUE_READ_TAG ( QUEUE_READ_TAG ),
        .ENABLE_FRAME_INFO_OUT ( ENABLE_FRAME_INFO_OUT ),
        .ENABLE_QUEUE ( ENABLE_QUEUE ),
        .QUEUE_DEPTH ( QUEUE_DEPTH ),
        .D2D_AXI_RANGE ( D2D_AXI_RANGE )
    ) dut (
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

        .frame_info_size ( frame_info_size ),
        .frame_info_ch ( frame_info_ch ),
        .frame_info_valid ( frame_info_valid ),
        .frame_info_ready ( frame_info_ready ),

        .clk ( clk ),
        .resetn ( resetn )
    );

    // queue data check packet
    reg [63:0] req_queue_addr[0:CH_NUM-1];
    reg [31:0] req_queue_size[0:CH_NUM-1];

    reg [CH_NUM_LOG-1:0] check_q_ch;
    int                  ch;
    always @(queue_rd_data) begin
        for (ch = 0; ch < CH_NUM; ch++) begin
            if (queue_rd_data[63:0] >= stream_req_q_bases[ch*64+:64] &&
                queue_rd_data[63:0] < stream_req_q_bases[ch*64+:64] + {stream_req_q_depth[ch*8+:8], {QEW_LOG{1'b0}}}) begin
                check_q_ch = ch;
                break;
            end
        end
    end
    always @(posedge clk) begin
        if (~resetn) begin
            queue_rd_res_valid <= 1'b0;
            queue_rd_res_data[RCBASE+QEWB-1:0] <= 'd0;
            queue_rd_ready <= 1'b0;
        end else begin
            if (queue_rd_valid & queue_rd_ready) begin
                queue_rd_res_valid <= 1'b1;
                queue_rd_res_data[RCBASE+:64] <= req_queue_addr[check_q_ch];
                queue_rd_res_data[RCBASE+64+:32] <= req_queue_size[check_q_ch];
                queue_rd_res_data[11:0] <= queue_rd_data[11:0]; // low addr
                queue_rd_res_data[28:16] <= {queue_rd_data[74:64], 2'd0}; // byte counts
                queue_rd_res_data[30] <= 1'b1; // request completion
                queue_rd_res_data[42:32] <= queue_rd_data[74:64]; // dword count
                queue_rd_res_data[71:64] <= queue_rd_data[103:96]; // tag
                req_q_valids[check_q_ch] <= 1'b0;
            end else begin
                queue_rd_res_valid <= 1'b0;
            end
            queue_rd_ready <= rd[3];
        end
    end

    // first request check
    generate
        for (genvar i=0; i<CH_NUM; i++) begin
            always @(posedge clk) begin
                if (request_valids[i] & request_firsts[i]) begin
                    if (requests[i*QEWB+:64] !== req_queue_addr[i] ||
                        requests[i*QEWB+64+:32] != req_queue_size[i]) begin
                        $error("request output[%2d] is wrong: addr:%h,%h, size:%h,%h", i,
                               requests[i*QEWB+:64], req_queue_addr[i], requests[i*QEWB+64+:32], req_queue_size[i]);
                    end
                end
            end
        end
    endgenerate

    task static initialize_queues();
        int          i;
        // initialize registers
        for (i=0; i<CH_NUM; i++) begin
            @(posedge clk) begin
                stream_ch_valids[i] <= |rd[3:1];
                initialized_queues[i] <= |rd[3:1] && (ENABLE_QUEUE == 0 || ~|rd[8+:2]);
                stream_ch_d2d_valids[i] <= |rd[8+:2];
                req_q_valids[i] <= 1'b0;
                cpl_q_vacants[i] <= 1'b1;
                stream_req_q_bases[i*64+:64] <= {rd, rd[31:5], 5'd0};
                stream_req_q_depth[i*8+:8] <= {5'd0, rd[19+:3]} + 2'd2;
                req_queue_addr[i] <= 64'd0;
                req_queue_size[i] <= 32'd0;
            end
        end
        @(posedge clk);
        for (i=0; i<CH_NUM; i++) begin
           $display("%d: [%2h] valid: %h init: %h d2d_valid: %h", $time, i,
                    stream_ch_valids[i], initialized_queues[i], stream_ch_d2d_valids[i]);
        end
    endtask

    reg [31:0] frame_size_saved[0:CH_NUM-1];
    reg        frame_size_valid[0:CH_NUM-1];
    initial begin
       for (int i=0; i<CH_NUM; i++) begin
          frame_size_valid[i] = 1'b0;
       end
    end
    always @(posedge clk) begin
       if (frame_info_valid & frame_info_ready && (ENABLE_QUEUE==0 || ~stream_ch_d2d_valids[frame_info_ch])) begin
          if (frame_info_size !== frame_size_saved[frame_info_ch] || ~frame_size_valid[frame_info_ch]) begin
             $error("%d: frame info: [%2d] %h %h, %h", $time, frame_info_ch, frame_info_size, frame_size_saved[frame_info_ch], frame_size_valid[frame_info_ch]);
          end
       end
       frame_info_ready <= FRAME_INFO_READY_BITS > 0 ? &rd[8+:FRAME_INFO_READY_BITS_MOD] : 1'b1;
    end
    always @(posedge clk) begin
       if (resetn && frame_info_valid && frame_info_ready && stream_ch_d2d_valids[frame_info_ch] && ENABLE_QUEUE > 0) begin
          if (frame_info_size !== D2D_AXI_RANGE) begin
             $error("%d: [%2h] d2d frame size %h %h", $time, frame_info_ch, frame_info_size, D2D_AXI_RANGE);
          end
          if (stream_req_q_tails[frame_info_ch*8+:8] == (stream_req_q_heads[frame_info_ch*8+:8] + 1'b1) & (QUEUE_DEPTH-1)) begin
             $error("%d: [%2h] d2d req q overrun: head %h tail %h", $time, frame_info_ch,
                    stream_req_q_heads[frame_info_ch*8+:8], stream_req_q_tails[frame_info_ch*8+:8]);
          end
          $display("%d: [%2h] d2d frame size %h (head/tail=%h/%h)", $time, frame_info_ch, frame_info_size,
                   stream_req_q_heads[frame_info_ch*8+:8], stream_req_q_tails[frame_info_ch*8+:8]);
          stream_req_q_heads[frame_info_ch*8+:8] <= (stream_req_q_heads[frame_info_ch*8+:8] + 1'b1) & (QUEUE_DEPTH-1);
       end
    end

    task static add_request(inout reg add_queue[0:CH_NUM-1]);
        int i, j;
        logic [63:0] head_addr;
        logic [63:0] queue_addr;
        logic [31:0] queue_size;
        for (i=0; i<CH_NUM; i++) begin
            for (j=0; j<UPDATE_INTERVAL; j++) @(posedge clk);
            @(posedge clk) begin
                if (rd[i] & initialized_queues[i]) begin
                    head_addr = stream_req_q_bases[i*64+:64] + {(rd[4+:4] % stream_req_q_depth[i*8+:8]), {QEW_LOG{1'b0}}};
                    queue_addr = {rd, rd[31:5], 5'd0};
                    queue_size = {8'd0, rd[23:0]};
                    add_queue[i] <= 1'b1;
                    req_q_valids[i] <= 1'b1;
                    req_q_head_addrs[i*64+:64] <= head_addr;
                    req_queue_addr[i] <= queue_addr;
                    req_queue_size[i] <= queue_size;
                    frame_size_saved[i] <= queue_size;
                    frame_size_valid[i] <= 1'b1;
                end
            end
        end
    endtask

    task static update_requests(inout reg add_queue[0:CH_NUM-1]);
        int i, j;
        reg [15:0] count;
        reg [31:0] contiguous_size;
        reg        req_valid_d1;
        reg [CH_NUM:0] pass;

        pass = 'd0;
        count = 'd0;
        while (pass < CH_NUM && count < 'd10000) begin
            @(posedge clk) begin
                pass = 'd0;
                updated_request_valid = 1'b0;
                for (i=0; i<CH_NUM; i++) begin
                    if (add_queue[i] && request_valids[i]) begin
                        contiguous_size = requests[QEWB*i+64+:32] > rd[23:0] ? {8'd0, rd[23:0]} : requests[QEWB*i+64+:32];
                        if (&rd[31:30]) begin
                            updated_request_vaddr <= requests[QEWB*i+:64] + contiguous_size;
                            updated_request_size <= requests[QEWB*i+64+:32] - contiguous_size;
                            updated_request_ch <= i;
                            updated_request_valid <= 1'b1;
                            if (contiguous_size == requests[QEWB*i+64+:32]) req_q_valids[i] <= 1'b0;
                            break;
                        end
                    end else if (~request_valids[i]) begin
                        pass = pass + 1'b1;
                    end
                end
                count = count + 1'b1;
            end
            @(posedge clk) begin
                req_valid_d1 <= updated_request_valid;
                updated_request_valid <= 1'b0;
                count = count + 1'b1;
            end
            if (req_valid_d1) begin
                while (requests[QEWB*updated_request_ch+64+:32] !== updated_request_size) begin
                    @(posedge clk) req_valid_d1 <= 1'b0;
                    count = count + 1'b1;
                end
            end
        end
        @(posedge clk) begin
            if (pass != CH_NUM) $error("update requests failed");
        end
    endtask

    initial begin
        int i;
        reg add_requests[0:CH_NUM-1];
        reg transferring[0:CH_NUM-1];
        reg fin_requests[0:CH_NUM-1];
        int  d2d_num = 0;
        int  d2d_max = 0;
        while (resetn !== 1'b1) @(posedge clk);
        for (i=0; i<CH_NUM; i++) begin
            add_requests[i] = 1'b0;
            transferring[i] = 1'b0;
            fin_requests[i] = 1'b0;
        end

        case(TEST_CASE)
            0 : begin
                initialize_queues;
                add_request(add_requests);
                update_requests(add_requests);
            end
            default: begin
                $fatal(2, "unknown test case");
            end
        endcase
        if (ENABLE_QUEUE>0) begin
           d2d_num = 0;
           for (i=0; i<CH_NUM; i++) begin
              d2d_num += stream_ch_d2d_valids[i];
           end
           while (d2d_max != d2d_num) @(posedge clk) begin
              d2d_max = 0;
              for (i=0; i<CH_NUM; i++) begin
                 if (stream_ch_d2d_valids[i] && ((stream_req_q_heads[i*8+:8] + 1'b1) & (QUEUE_DEPTH-1)) == stream_req_q_tails[i*8+:8]) d2d_max++;
              end
           end
           for (i=0; i<100; i++) @(posedge clk);
        end

        $finish();
    end

endmodule

module test_queue_element_update();

    tb_queue_element tb();

endmodule

module test_queue_element_frame_info_out();

    tb_queue_element #(
        .ENABLE_FRAME_INFO_OUT ( 1 ),
        .FRAME_INFO_READY_BITS ( 6 )
    ) tb ();

endmodule

module test_queue_element_frame_info_out_d2d();

    tb_queue_element #(
        .ENABLE_FRAME_INFO_OUT ( 1 ),
        .ENABLE_QUEUE ( 1 ),
        .FRAME_INFO_READY_BITS ( 6 )
    ) tb ();

endmodule
