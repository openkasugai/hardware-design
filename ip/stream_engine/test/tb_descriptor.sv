/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_descriptor #(
    parameter CH_NUM_LOG = 3,
    parameter DESC_RQ_DW = 512,
    parameter DESC_RQ_DK = 16,
    parameter DESC_RC_DW = 512,
    parameter DESC_RC_DK = 16,
    parameter QEW = 32,
    parameter QEW_LOG = 5,
    parameter RQBASE = 128,
    parameter RCBASE = 96,
    parameter VP_MAP_NUM_LOG = 8,
    parameter VPMAP_SIZE_MAX = 32'hfffffffc,
    parameter DESC_DWORD = 16,
    parameter CH_BASE = 0,
    parameter ENABLE_QUEUE = 0,
    parameter CHECK_INTERVAL = 200,
    parameter INITIALIZE_INTERVAL = 10,
    parameter UPDATE_INTERVAL = 30,
    parameter DISABLE_FRAME_INFO = 0,
    parameter DESC_LEN = 512,
    parameter MAX_CYCLE = 'd10000,
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
    localparam QEWB = QEW << 3;
    localparam QEWB_LOG = QEW_LOG + 3;
    localparam VP_MAP_NUM = 1 << VP_MAP_NUM_LOG;

    reg [CH_NUM-1:0]          stream_ch_d2d_valids;

    reg [31:0]                tx_size;
    reg [CH_NUM_LOG-1:0]      tx_ch;
    reg                       tx_valid;
    wire                      tx_ready;

    wire [CH_NUM_LOG-1:0]     stream_req_update_ch; // head update
    wire [31:0]               stream_req_update_size;
    wire                      stream_req_update;

    reg [QEWB*CH_NUM-1:0]     requests;
    reg [CH_NUM-1:0]          request_valids;
    reg [CH_NUM-1:0]          request_firsts;

    reg [DESC_RQ_DW-1:0]      desc_req_data;
    reg [DESC_RQ_DK-1:0]      desc_req_keep;
    reg                       desc_req_valid;
    wire                      desc_req_ready;

    wire [DESC_RC_DW-1:0]     desc_out_data;
    wire [DESC_RC_DK-1:0]     desc_out_keep;
    wire                      desc_out_valid;
    wire                      desc_out_last;
    reg                       desc_out_ready;

    wire [63:0]               updated_request_vaddr;
    wire [31:0]               updated_request_size;
    wire                      updated_request_valid;
    wire [CH_NUM_LOG-1:0]     updated_request_ch;

    wire [63:0]               request_base_vaddr;
    wire [31:0]               request_base_size;
    wire [CH_NUM_LOG-1:0]     request_base_ch;
    wire                      request_base_final;
    wire                      request_base_valid;
    reg                       request_base_ready;

    wire [VP_MAP_NUM_LOG+CH_NUM_LOG-1:0] vpmap_conv_addr;
    reg [160:0]                          vpmap_conv_rdata;

    initial begin
        tx_size <= 'd0;
        tx_ch <= 'd0;
        tx_valid <= 1'b0;
        desc_req_data = 'd0;
        desc_req_keep = 'd0;
        desc_req_valid = 1'b0;
        desc_out_ready = 1'b0;
        requests = 'd0;
        request_valids = 'd0;
        request_firsts = 'd0;
        vpmap_conv_rdata = 'd0;
        request_base_ready = 'd0;
        @(posedge clk);
        stream_ch_d2d_valids = ENABLE_QUEUE > 0 ? rd : 'd0;
    end

    stream_engine_descriptor #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .QEW ( QEW ),
        .QEW_LOG ( QEW_LOG ),
        .DESC_RQ_DW ( DESC_RQ_DW ),
        .DESC_RQ_DK ( DESC_RQ_DK ),
        .DESC_RC_DW ( DESC_RC_DW ),
        .DESC_RC_DK ( DESC_RC_DK ),
        .DESC_LEN ( DESC_LEN ),
        .VP_MAP_NUM_LOG ( VP_MAP_NUM_LOG ),
        .RCBASE ( RCBASE ),
        .ENABLE_QUEUE ( ENABLE_QUEUE ),
        .DISABLE_FRAME_INFO ( DISABLE_FRAME_INFO )
    ) dut (
        .stream_ch_valids ( {CH_NUM{1'b1}} ),
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
        .desc_out_valid ( desc_out_valid ),
        .desc_out_last ( desc_out_last ),
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

    reg [63:0] vaddrs[0:CH_NUM-1];
    reg [31:0] vsizes[0:CH_NUM-1];
    reg [31:0] vaddr_offsets[0:CH_NUM-1];
    reg [63:0] vpmap_vaddrs[0:CH_NUM-1][0:VP_MAP_NUM-1];
    reg [31:0] vpmap_vsizes[0:CH_NUM-1][0:VP_MAP_NUM-1];
    reg [63:0] vpmap_paddrs[0:CH_NUM-1][0:VP_MAP_NUM-1];
    reg        vpmap_valids[0:CH_NUM-1][0:VP_MAP_NUM-1];
    reg [31:0] frame_info_sizes[0:CH_NUM-1];
    reg [31:0] descriptor_total_sizes[0:CH_NUM-1];
    reg [31:0] requested_sizes[0:CH_NUM-1];

    initial begin
        for (int i=0; i<CH_NUM; i++) begin
            for (int j=0; j<VP_MAP_NUM; j++) begin
                vpmap_valids[i][j] = 1'b0;
            end
            descriptor_total_sizes[i] = 'd0;
            if (DISABLE_FRAME_INFO) frame_info_sizes[i] = 32'hffffffc0;
            else frame_info_sizes[i] = 'd0;
            requested_sizes[i] = 'd0;
        end
    end

    // vpmap output
    wire [CH_NUM_LOG-1:0] vpmap_conv_ch = vpmap_conv_addr[VP_MAP_NUM_LOG+:CH_NUM_LOG];
    wire [VP_MAP_NUM_LOG-1:0] vpmap_conv_vpmap_idx = vpmap_conv_addr[0+:VP_MAP_NUM_LOG];
    always @(posedge clk) begin
        if (~resetn) begin
            vpmap_conv_rdata <= 'd0;
        end else begin
            vpmap_conv_rdata <= {vpmap_valids[vpmap_conv_ch][vpmap_conv_vpmap_idx],
                                 vpmap_vsizes[vpmap_conv_ch][vpmap_conv_vpmap_idx],
                                 vpmap_paddrs[vpmap_conv_ch][vpmap_conv_vpmap_idx],
                                 vpmap_vaddrs[vpmap_conv_ch][vpmap_conv_vpmap_idx]};
        end
    end

    // descriptor read req
    reg [CH_NUM_LOG-1:0] desc_req_ch;
    reg                  desc_req_inflight;
    always @(posedge clk) begin
        if (~resetn) begin
            desc_req_ch <= 'd0;
            desc_req_inflight <= 1'b0;
        end else if (~desc_req_inflight & rd[20]) begin
            desc_req_data[63:0] <= {rd, rd[31:5], 5'd0};
            desc_req_data[74:64] <= DESC_DWORD;
            desc_req_data[78:75] <= 4'd0; // read
            desc_req_data[103:96] <= CH_BASE + desc_req_ch;
            desc_req_keep <= 'hf;
            desc_req_valid <= 1'b1;
            desc_req_inflight <= 1'b1;
        end else begin
            desc_req_valid <= desc_req_valid & ~desc_req_ready;
            desc_req_inflight <= desc_req_inflight & ~(desc_out_valid & desc_out_ready & desc_out_last);
            if (desc_out_valid & desc_out_ready & desc_out_last) begin
                desc_req_ch <= desc_req_ch + 1'b1;
            end
        end
    end

    // descriptor read completion
    reg [DESC_LEN-1:0]   desc_shifted_data;
    reg [31:0]           desc_shifted_len;
    reg [CH_NUM_LOG-1:0] desc_shifted_ch;
    reg                  desc_shifted_valid;
    reg                  desc_shifted_wrong;
    reg                  desc_shifted_first;

    reg [31:0]           check_desc_offset;

    always @(posedge clk) begin
        if (~resetn) begin
            desc_out_ready <= 1'b0;
            desc_shifted_data <= 'd0;
            desc_shifted_len <= 'd0;
            desc_shifted_valid <= 1'b0;
            desc_shifted_ch <= 'd0;
            desc_shifted_first <= 1'b0;
            desc_shifted_wrong <= 1'b0;
        end else begin
            desc_out_ready <= rd[11];
            if (desc_shifted_valid) begin
                desc_shifted_wrong = (desc_shifted_data[23:16] === 'd1);
                check_desc_offset = 32'd0;
                for (int i=0; i<VP_MAP_NUM; i++) begin
                    if (vpmap_valids[desc_shifted_ch][i] &&
                        vpmap_paddrs[desc_shifted_ch][i] <= desc_shifted_data[64+:64] &&
                        desc_shifted_data[64+:64] + desc_shifted_data[32+:32] <= vpmap_paddrs[desc_shifted_ch][i] + vpmap_vsizes[desc_shifted_ch][i]) begin
                        desc_shifted_wrong = vpmap_paddrs[desc_shifted_ch][i] + vaddr_offsets[desc_shifted_ch]
                                             - check_desc_offset !== desc_shifted_data[64+:64];
                        $display("[%h] vpmap_paddr[%2d]: %h, vaddr_offset: %h, cur_offset: %h -> cur_paddr: %h, real: %h",
                                 desc_shifted_wrong,
                                 desc_shifted_ch, vpmap_paddrs[desc_shifted_ch][i], vaddr_offsets[desc_shifted_ch],
                                 check_desc_offset,
                                 vpmap_paddrs[desc_shifted_ch][i] + vaddr_offsets[desc_shifted_ch] - check_desc_offset,
                                 desc_shifted_data[64+:64]);
                        break;
                    end else begin
                        check_desc_offset = check_desc_offset + vpmap_vsizes[desc_shifted_ch][i];
                        if (check_desc_offset > vaddr_offsets[desc_shifted_ch]) check_desc_offset = vaddr_offsets[desc_shifted_ch];
                    end
                end
                descriptor_total_sizes[desc_shifted_ch] <= descriptor_total_sizes[desc_shifted_ch] + desc_shifted_data[32+:32];
                if (desc_shifted_wrong)
                  $error("descriptor range wrong[%2d]: %h %h",
                         desc_shifted_ch, desc_shifted_data[64+:64], desc_shifted_data[32+:32]);
                else if (desc_shifted_data[23:16] === 'd1)
                  $display("descriptor[%2d] paddr: %h psize: %h", desc_shifted_ch, desc_shifted_data[64+:64], desc_shifted_data[32+:32]);
            end
            if (desc_out_valid & desc_out_ready) begin
                if (desc_shifted_valid || desc_shifted_len == 0) begin
                    desc_shifted_len <= (DESC_RC_DW - RCBASE) >> 3;
                    desc_shifted_valid <= DESC_RC_DW - RCBASE >= DESC_LEN;
                    desc_shifted_ch <= desc_out_data[71:64] - CH_BASE;
                    if (desc_out_data[32+:11] !== (DESC_LEN>>5) ||
                        desc_out_data[28:16] !== (DESC_LEN>>3) ||
                        desc_out_data[45:43] !== 'd0 ||
                        desc_out_data[30] !== 1'b1 ||
                        desc_out_data[71:64] < CH_BASE ||
                        desc_out_data[71:64] > CH_BASE + CH_NUM ||
                        desc_out_data[11:0] !== desc_req_data[11:0]) begin
                        $error("[%d] completion header wrong: %h:%h, %h:%h, %h:%h, %h:%h, %h <= %h <= %h, %h:%h", $time,
                               desc_out_data[32+:11], DESC_LEN>>5,
                               desc_out_data[28:16], DESC_LEN>>3,
                               desc_out_data[45:43], 'd0,
                               desc_out_data[30], 1'b1,
                               CH_BASE, desc_out_data[71:64], CH_BASE + CH_NUM,
                               desc_out_data[11:0], desc_req_data[11:0]);
                    end
                    desc_shifted_data[DESC_RC_DW - RCBASE - 1:0] <= desc_out_data[DESC_RC_DW-1:RCBASE];
                end else begin
                    desc_shifted_first <= 1'b0;
                    desc_shifted_len <= desc_shifted_len + (DESC_RC_DW >> 3);
                    desc_shifted_valid <= desc_shifted_len + (DESC_RC_DW >> 3) >= (DESC_LEN >> 3);
                    desc_shifted_data <= (desc_shifted_data & (({{DESC_LEN{1'b0}}, 1'b1} << desc_shifted_len*8)-1'b1)) |
                                         ({{DESC_LEN{1'b0}}, desc_out_data} << (desc_shifted_len*8));
                end
            end else if (desc_shifted_valid) begin
                desc_shifted_valid <= 1'b0;
                desc_shifted_len <= 'd0;
            end
        end
    end

    // req base
    reg [63:0] request_base_vaddr_update[0:CH_NUM-1];
    reg [31:0] request_base_size_total[0:CH_NUM-1];
    reg        request_base_finished[0:CH_NUM-1];
    always @(posedge clk) begin
        if (~resetn) begin
            for (int i=0; i<CH_NUM; i++) begin
                request_base_vaddr_update[i] <= 'd0;
                request_base_size_total[i] <= 'd0;
                request_base_finished[i] <= 'd0;
            end
            request_base_ready <= 1'b0;
        end else begin
            if (request_base_valid & request_base_ready) begin
                if (request_base_vaddr_update[request_base_ch] !== 0) begin
                    if (request_base_vaddr_update[request_base_ch] !== request_base_vaddr) begin
                        $error("request base vaddr updating failed[%2d]: %h %h",
                               request_base_ch, request_base_vaddr, request_base_vaddr_update[request_base_ch]);
                    end
                end
                request_base_vaddr_update[request_base_ch] <= request_base_vaddr + request_base_size;
                request_base_size_total[request_base_ch] <= request_base_size_total[request_base_ch] + request_base_size;
                request_base_finished[request_base_ch] <= request_base_final;
            end
            request_base_ready <= rd[12];
        end
    end

    // requests update
    always @(posedge clk) begin
        if (resetn) begin
            if (updated_request_valid) begin
                requests[updated_request_ch*QEWB+:64] <= updated_request_vaddr;
                requests[updated_request_ch*QEWB+64+:32] <= updated_request_size;
                request_firsts[updated_request_ch] <= 1'b0;
                if (~|updated_request_size) begin
                    request_valids[updated_request_ch] <= 1'b0;
                end
            end
        end
    end

    // d2d req queue update
    always @(posedge clk) begin
       if (resetn && stream_req_update) begin
          if (ENABLE_QUEUE==0 || ~stream_ch_d2d_valids[stream_req_update_ch] ||
              stream_req_update_size !== frame_info_sizes[stream_req_update_ch]) begin
             $error("%d: [%2h] stream req update wrong %h %h", $time, stream_req_update_ch,
                    stream_req_update_size, frame_info_sizes[stream_req_update_ch]);
          end else begin
             $display("%d: [%2h] stream req update %h %h", $time, stream_req_update_ch,
                      stream_req_update_size, frame_info_sizes[stream_req_update_ch]);
          end
       end
    end

    task static initialize_vpmap();
        int          i, j;
        reg [63:0]   cur_vaddr;
        reg [31:0]   cur_remain;
        // initialize registers
        for (i=0; i<CH_NUM; i++) begin
            for (j=0; j<VP_MAP_NUM; j++) begin
                if (j==0) begin
                    @(posedge clk) vaddrs[i] = {rd, rd[31:5], 5'd0};
                    @(posedge clk) begin
                        vsizes[i] = {rd[31:5], 5'd0};
                        cur_vaddr = vaddrs[i];
                        cur_remain = vsizes[i];
                        $display("[%2d]: vaddr: %h vsize: %h", i, vaddrs[i], vsizes[i]);
                    end
                end
                @(posedge clk) begin
                    if (cur_remain) begin
                        vpmap_vsizes[i][j] = cur_remain < {1'b0, rd[30:0]} ? cur_remain : {1'b0, rd[30:0]};
                        if (j == VP_MAP_NUM - 1) vpmap_vsizes[i][j] = cur_remain;
                        else if (vpmap_vsizes[i][j] > VPMAP_SIZE_MAX) vpmap_vsizes[i][j] = VPMAP_SIZE_MAX;
                        cur_remain = cur_remain - vpmap_vsizes[i][j];
                        vpmap_vaddrs[i][j] = cur_vaddr;
                        vpmap_valids[i][j] = 1'b1;
                        cur_vaddr = cur_vaddr + vpmap_vsizes[i][j];
                    end
                end
                @(posedge clk) begin
                    vpmap_paddrs[i][j] = {rd, rd[31:5], 5'd0};
                    $display("       %4h: %h vaddr: %h vsize: %h paddr: %h", j, vpmap_valids[i][j],
                             vpmap_vaddrs[i][j], vpmap_vsizes[i][j], vpmap_paddrs[i][j]);
                end
            end
        end
    endtask

    task static add_request();
        int i, j;
        reg [31:0] offset;
        reg [31:0] old_rd;
        reg [31:0] cur_size;
        for (i=0; i<CH_NUM; i++) begin
            for (j=0; j<UPDATE_INTERVAL; j++) @(posedge clk);
            @(posedge clk) if ((~tx_valid || tx_ready) && (i&1) && !DISABLE_FRAME_INFO) begin
                tx_size <= rd;
                tx_ch <= i;
                tx_valid <= 1'b1;
                frame_info_sizes[i] <= rd;
                $display("[%2d]: transfer size(A): %h", i, rd);
            end
            do @(posedge clk) tx_valid <= tx_valid & ~tx_ready; while (tx_valid);
            for (j=0; j<UPDATE_INTERVAL; j++) @(posedge clk) if (&rd[4+:3]) break;
            @(posedge clk) if (~request_valids[i] && (ENABLE_QUEUE == 0 || ~stream_ch_d2d_valids[i])) begin
                offset = rd % vsizes[i];
                old_rd = rd;
                requests[QEWB*i+:64] <= vaddrs[i] + offset;
                vaddr_offsets[i] <= offset;
            end
            @(posedge clk) if (~request_valids[i] && (ENABLE_QUEUE == 0 || ~stream_ch_d2d_valids[i])) begin
                cur_size = {1'b0, vsizes[i]} < {1'b0, rd} + offset ? vsizes[i] - offset : rd;
                requests[QEWB*i+64+:32] <= cur_size;
                if (|rd[i+5+:2]) begin
                    $display("[%2d]: vsize: %h, rd: %h, offset: %h, rd+offset: %h, vsize-offset: %h : vaddr: %h, vsize: %h",
                             i, vsizes[i], rd, offset, {1'b0, rd} + offset, vsizes[i] - offset, vaddrs[i] + offset, cur_size);
                end
                request_valids[i] <= |rd[i+5+:2];
                request_firsts[i] <= |rd[i+5+:2];
                if (|rd[i+5+:2]) requested_sizes[i] <= cur_size;
            end
            for (j=0; j<UPDATE_INTERVAL; j++) @(posedge clk) if (&rd[4+:3]) break;
            @(posedge clk) if ((~tx_valid || tx_ready) && !(i&1) && !DISABLE_FRAME_INFO) begin
                tx_size <= rd;
                tx_ch <= i;
                tx_valid <= 1'b1;
                frame_info_sizes[i] <= rd;
                $display("[%2d]: transfer size(B): %h", i, rd);
            end
            do @(posedge clk) tx_valid <= tx_valid & ~tx_ready; while (tx_valid);
        end
    endtask

    task static wait_finish_request();
        int i;
        reg [31:0] counts = 0;
        reg [31:0] minsize;
        while (counts < MAX_CYCLE) @(posedge clk) begin
            if (~|request_valids) break;
            counts <= counts + 1'b1;
        end
        if (counts >= MAX_CYCLE) $error("timeout to finish requests.");
        for (i=0; i<1000; i++) @(posedge clk);
        for (i=0; i<CH_NUM; i++) begin
            if (ENABLE_QUEUE == 0 || stream_ch_d2d_valids[i]) begin
               minsize = frame_info_sizes[i] < requested_sizes[i] ? frame_info_sizes[i] : requested_sizes[i];
               if (descriptor_total_sizes[i] !== minsize) $error("transferred size [%2d] is different: %h %h %h", i,
                                                                 descriptor_total_sizes[i],
                                                                 frame_info_sizes[i], requested_sizes[i]);
               if ((~request_base_finished[i] ^ ~|requested_sizes[i]) || request_base_size_total[i] !== minsize) begin
                  $error("request base total size[%2d] is differnt: %h %h, %1d", i,
                         request_base_size_total[i], minsize, request_base_finished[i]);
               end
            end
        end
    endtask

    initial begin
        int i;
        while (resetn !== 1'b1) @(posedge clk);

        case(TEST_CASE)
            0 : begin
                initialize_vpmap;
                add_request();
                wait_finish_request();
            end
            default: begin
                $fatal(2, "unknown test case");
            end
        endcase

        $finish();
    end

endmodule

module test_descriptor_create();

    tb_descriptor #(
        .DISABLE_FRAME_INFO ( 1 )
    ) tb();

endmodule

module test_descriptor_create_full_vpmap();

    tb_descriptor #(
        .DISABLE_FRAME_INFO ( 1 ),
        .VPMAP_SIZE_MAX ( 32'h100000 ),
        .MAX_CYCLE ( 'd30000 )
    ) tb();

endmodule

module test_descriptor_create_with_frame_info();

    tb_descriptor tb();

endmodule

module test_descriptor_create_with_frame_info_d2d();

    tb_descriptor #(
        .ENABLE_QUEUE ( 1 )
    ) tb ();

endmodule
