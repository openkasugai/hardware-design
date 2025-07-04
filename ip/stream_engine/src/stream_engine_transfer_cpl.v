/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module stream_engine_transfer_cpl #(
    parameter CH_NUM_LOG = 3,
    parameter QEW = 32,
    parameter QEW_LOG = 5,
    parameter DESC_RQ_DW = 512,
    parameter DESC_RQ_DK = 16,
    parameter DESC_LEN = 512,
    parameter RQ_DW = 384,
    parameter RQ_DK = 12,
    parameter RQBASE = 128,
    parameter DISABLE_FRAME_INFO = 0,
    parameter IGNORE_CPL_SIZE = 0
    ) (
    input [(1<<CH_NUM_LOG)-1:0]    stream_ch_valids,
    input [(1<<CH_NUM_LOG)-1:0]    stream_ch_d2d_valids,

    input [64*(1<<CH_NUM_LOG)-1:0] desc_base_vaddr,
    input [32*(1<<CH_NUM_LOG)-1:0] desc_base_size,
    input [(1<<CH_NUM_LOG)-1:0]    desc_base_final,
    input [(1<<CH_NUM_LOG)-1:0]    desc_base_valid,
    output [(1<<CH_NUM_LOG)-1:0]   desc_base_ready,
`ifdef OLD_IMPL
    input [DESC_RQ_DW-1:0]         desc_req_data,
    input [DESC_RQ_DK-1:0]         desc_req_keep,
    input                          desc_req_valid,
    input                          desc_req_last,
    output                         desc_req_ready,
`else
    input [CH_NUM_LOG-1:0]         desc_cpl_ch,
    input [31:0]                   desc_cpl_data,
    input                          desc_cpl_valid,
    output                         desc_cpl_ready,
`endif
    output [CH_NUM_LOG-1:0]        transfer_cpl_ch,
    output                         transfer_cpl_ch_valid,
    input                          transfer_cpl_ch_done,

    output reg [RQ_DW-1:0]         queue_wr_data,
    output reg [RQ_DK-1:0]         queue_wr_keep,
    output                         queue_wr_valid,
    input                          queue_wr_ready,

    input [(1<<CH_NUM_LOG)*64-1:0] cpl_q_head_addrs,
`ifdef OLD_IMPL
    input [(1<<CH_NUM_LOG)*64-1:0] stream_desc_bases,
    input [(1<<CH_NUM_LOG)*64-1:0] stream_desc_ends,
`endif
    output [CH_NUM_LOG-1:0]        desc_req_ch,
    output                         desc_req_ch_valid,
    output [(1<<CH_NUM_LOG)-1:0]   dbg_transfer_valids,
    output [(1<<CH_NUM_LOG)-1:0]   dbg_transfer_issue_ends,
    output [(1<<CH_NUM_LOG)-1:0]   dbg_transfer_ends,
    output [(1<<CH_NUM_LOG)-1:0]   transfer_cpl_ch_cand,

    input                          clk,
    input                          resetn
    );

    localparam CH_NUM = 1 << CH_NUM_LOG;
    localparam QEWB = QEW << 3;
    localparam QEWB_LOG = QEW_LOG + 3;

    localparam IDDMA_STAT_SUCCESS = 8'd2;
    localparam IDDMA_STAT_FAILED = 8'd3;

    reg                           transfered_valid;
    wire                          transfered_ch_ready;
`ifdef OLD_IMPL
    reg [63:0]                    desc_req_addr;
    reg [DESC_LEN-1:0]            desc_body;
    reg [7:0]                     desc_body_len;
    reg                           desc_req_addr_valid;
    reg                           desc_body_valid;

    // descriptor completion check
    always @(posedge clk) begin
        if (~resetn) begin
            desc_req_addr <= 'd0;
            desc_req_addr_valid <= 1'b0;
            desc_body <= 'd0;
            desc_body_len <= 'd0;
            desc_body_valid <= 1'b0;
        end else if (desc_req_valid & desc_req_ready) begin
            if (~|desc_body_len) begin
                desc_req_addr <= desc_req_data[63:0];
                desc_body <= 'd0 | desc_req_data[DESC_RQ_DW-1:RQBASE];
                desc_body_len <= DESC_RQ_DK - (RQBASE>>5);
                desc_req_addr_valid <= 1'b1;
            end else begin
                desc_body <= desc_body | (({DESC_LEN{1'b0}} | desc_req_data) << {desc_body_len, 5'd0});
                desc_body_len <= desc_body_len + DESC_RQ_DK;
                desc_req_addr_valid <= 1'b0;
            end
            desc_body_valid <= desc_req_last;
        end else if (transfered_valid & transfered_ch_ready) begin
            desc_body_valid <= 1'b0;
            desc_body_len <= 'd0;
            desc_req_addr_valid <= 1'b0;
        end
    end
    assign desc_req_ready = ~desc_body_valid;

    reg [CH_NUM-1:0] desc_req_addr_gel;
    reg [CH_NUM-1:0] desc_req_addr_gth;
    reg [CH_NUM-1:0] desc_req_addr_ueqh;
    reg [CH_NUM-1:0] desc_req_addr_ltl;
    reg [CH_NUM-1:0] desc_req_addr_lth;
    reg [CH_NUM-1:0] desc_req_addr_leqh;
    generate
        for (genvar i=0; i<CH_NUM; i=i+1) begin
            always @(posedge clk) begin
                if (~resetn) begin
                    desc_req_addr_gel[i] <= 1'b0;
                    desc_req_addr_gth[i] <= 1'b0;
                    desc_req_addr_ueqh[i] <= 1'b0;
                    desc_req_addr_ltl[i] <= 1'b0;
                    desc_req_addr_lth[i] <= 1'b0;
                    desc_req_addr_leqh[i] <= 1'b0;
                end else begin
                    desc_req_addr_gel[i] <= stream_desc_bases[i*64+2+:30] <= desc_req_addr[31:2];
                    desc_req_addr_gth[i] <= stream_desc_bases[i*64+32+:32] < desc_req_addr[63:32];
                    desc_req_addr_ueqh[i] <= stream_desc_bases[i*64+32+:32] == desc_req_addr[63:32];
                    desc_req_addr_ltl[i] <= stream_desc_ends[i*64+2+:30] > desc_req_addr[31:2];
                    desc_req_addr_lth[i] <= stream_desc_ends[i*64+32+:32] > desc_req_addr[63:32];
                    desc_req_addr_leqh[i] <= stream_desc_ends[i*64+32+:32] == desc_req_addr[63:32];
                end
            end
        end
    endgenerate

    reg              desc_req_addr_part_valid;
    reg [CH_NUM-1:0] desc_req_addr_in_range;
    reg              desc_req_addr_in_range_valid;
    always @(posedge clk) begin
        if (~resetn) begin
            desc_req_addr_in_range <= 'd0;
            desc_req_addr_part_valid <= 1'b0;
            desc_req_addr_in_range_valid <= 1'b0;
        end else if (desc_body_valid) begin
            desc_req_addr_in_range <= (desc_req_addr_gth | (desc_req_addr_ueqh & desc_req_addr_gel)) &
                                      (desc_req_addr_lth | (desc_req_addr_leqh & desc_req_addr_ltl));
            desc_req_addr_part_valid <= desc_req_addr_valid;
            desc_req_addr_in_range_valid <= |((desc_req_addr_gth | (desc_req_addr_ueqh & desc_req_addr_gel)) &
                                              (desc_req_addr_lth | (desc_req_addr_leqh & desc_req_addr_ltl)));
        end else begin
            desc_req_addr_in_range_valid <= 1'b0;
        end
    end

    reg [CH_NUM_LOG-1:0] desc_req_addr_ch;
    reg                  desc_req_addr_ch_valid;
    integer              i;
    always @(desc_req_addr_in_range) begin
        desc_req_addr_ch_valid = 1'b0;
        desc_req_addr_ch = 'd0;
        if (resetn) begin
            for (i=0; i<CH_NUM; i=i+1) begin
                if (desc_req_addr_in_range[i] && ~desc_req_addr_ch_valid) begin
                    desc_req_addr_ch = i;
                    desc_req_addr_ch_valid = 1'b1;
                end
            end
        end
    end

    reg [31:0]                    transfered_size;
    reg [CH_NUM_LOG-1:0]          transfered_ch;
    reg                           transfered_ch_valid;

    always @(posedge clk) begin
        if (~resetn) begin
            transfered_size <= 'd0;
            transfered_ch <= 'd0;
            transfered_valid <= 'd0;
            transfered_ch_valid <= 'd0;
        end else if (desc_body_valid & desc_req_addr_in_range_valid & ~transfered_valid) begin
            transfered_ch <= desc_req_addr_ch;
            transfered_size <= desc_body[32+:32];
            transfered_valid <= 1'b1;
            transfered_ch_valid <= desc_req_addr_ch_valid;
        end else if (transfered_ch_valid && transfered_ch_ready) begin
            transfered_valid <= 1'b0;
            transfered_ch_valid <= 1'b0;
        end
    end
`else
    reg [31:0]                    transfered_size;
    reg [CH_NUM_LOG-1:0]          transfered_ch;
    reg                           transfered_ch_valid;

    always @(posedge clk) begin
        if (~resetn) begin
            transfered_size <= 'd0;
            transfered_ch <= 'd0;
            transfered_valid <= 'd0;
            transfered_ch_valid <= 'd0;
        end else if (desc_cpl_valid & desc_cpl_ready) begin
            transfered_ch <= desc_cpl_ch;
            transfered_size <= desc_cpl_data;
            transfered_valid <= 1'b1;
            transfered_ch_valid <= 1'b1;
        end else if (transfered_ch_valid && transfered_ch_ready) begin
            transfered_valid <= 1'b0;
            transfered_ch_valid <= 1'b0;
        end
    end
   assign desc_cpl_ready = ~transfered_ch_valid;
`endif

    reg [CH_NUM*64-1:0]            transfer_start_vaddrs;
    reg [CH_NUM*32-1:0]            transfer_issued_sizes;
    reg [CH_NUM*32-1:0]            transfer_completed_sizes;
    reg [CH_NUM-1:0]               transfer_issue_ends;
    reg [CH_NUM-1:0]               transfer_valids;
    reg [CH_NUM-1:0]               transfer_ends;
    reg [CH_NUM*8-1:0]             transfer_issued_counts;

    reg [CH_NUM_LOG-1:0]           write_cpl_ch;
    reg                            write_cpl_valid;

    assign transfered_ch_ready = (transfer_valids & ~transfer_ends) >> transfered_ch;

    generate
        for (genvar i=0; i<CH_NUM; i=i+1) begin
            always @(posedge clk) begin
                if (~resetn || ~stream_ch_valids[i]) begin
                    transfer_start_vaddrs[i*64+:64] <= 'd0;
                    transfer_issued_sizes[i*32+:32] <= 'd0;
                    if (DISABLE_FRAME_INFO > 0 || IGNORE_CPL_SIZE > 0) begin
                        transfer_issued_counts[i*8+:8] <= 'd0;
                    end
                    transfer_issue_ends[i] <= 1'b0;
                    transfer_valids[i] <= 1'b0;
                end else if (desc_base_valid[i] & desc_base_ready[i]) begin
                    if (~transfer_valids[i]) begin
                        transfer_start_vaddrs[i*64+:64] <= desc_base_vaddr[i*64+:64];
                        transfer_issued_sizes[i*32+:32] <= desc_base_size[i*32+:32];
                        if (DISABLE_FRAME_INFO > 0 || IGNORE_CPL_SIZE > 0) begin
                            transfer_issued_counts[i*8+:8] <= 'd0 | |desc_base_size[i*32+:32];
                        end
                    end else begin
                        transfer_issued_sizes[i*32+:32] <= transfer_issued_sizes[i*32+:32] + desc_base_size[i*32+:32];
                        if (DISABLE_FRAME_INFO > 0 || IGNORE_CPL_SIZE > 0) begin
                            transfer_issued_counts[i*8+:8] <= transfer_issued_counts[i*8+:8] + 1'b1;
                        end
                    end
                    transfer_valids[i] <= 1'b1;
                    transfer_issue_ends[i] <= desc_base_final[i];
                end else if (write_cpl_valid && write_cpl_ch == i) begin
                    transfer_valids[i] <= 1'b0;
                    transfer_issue_ends[i] <= 1'b0;
                end
            end
            always @(posedge clk) begin
                if (~resetn || ~stream_ch_valids[i]) begin
                    transfer_completed_sizes[i*32+:32] <= 'd0;
                    transfer_ends[i] <= 1'b0;
                end else if (write_cpl_valid && write_cpl_ch == i) begin
                    transfer_completed_sizes[i*32+:32] <= 'd0;
                    transfer_ends[i] <= 1'b0;
                end else if (transfered_ch_ready) begin
                    if (transfered_ch_valid && transfered_ch == i) begin
                        if (DISABLE_FRAME_INFO > 0 || IGNORE_CPL_SIZE > 0) begin
                            transfer_completed_sizes[i*32+:8] <= transfer_completed_sizes[i*32+:8] + 1'b1;
                        end else begin
                            transfer_completed_sizes[i*32+:32] <= transfer_completed_sizes[i*32+:32] + transfered_size;
                        end
                    end
                    if (DISABLE_FRAME_INFO > 0 || IGNORE_CPL_SIZE > 0) begin
                        transfer_ends[i] <= transfer_issue_ends[i] &&
                                             (transfer_completed_sizes[i*32+:8] >= transfer_issued_counts[i*8+:8]);
                    end else begin
                        transfer_ends[i] <= transfer_issue_ends[i] &&
                                             (transfer_completed_sizes[i*32+:32] >= transfer_issued_sizes[i*32+:32]);
                    end
                end
            end
        end
    endgenerate
    wire [CH_NUM-1:0] cur_channel_busy = transfer_valids & transfer_issue_ends;
    assign desc_base_ready = ~cur_channel_busy;

    wire [CH_NUM_LOG-1:0] write_cpl_ch_candidate;
    wire                  write_cpl_ch_valid_candidate;

    assign transfer_cpl_ch_cand = {{CH_NUM-1{1'b0}}, write_cpl_ch_valid_candidate} << write_cpl_ch_candidate;
    assign dbg_transfer_valids = transfer_valids;
    assign dbg_transfer_issue_ends = transfer_issue_ends;
    assign dbg_transfer_ends = transfer_ends;

    ch_candidate #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .RR ( 0 )
    ) i_write_cpl_ch_candidate (
        .ch_valids ( transfer_valids & transfer_issue_ends & transfer_ends ),
        .update ( transfer_cpl_ch_valid ),
        .candidate ( write_cpl_ch_candidate ),
        .candidate_valid ( write_cpl_ch_valid_candidate ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    reg        write_cpl_busy;
    reg [63:0] write_cpl_vaddr;
    reg [31:0] write_cpl_size;
    reg        write_cpl_update;
    reg [7:0]  write_cpl_status;
    wire [31:0] w_write_cpl_size;

    always @(posedge clk) begin
        if (~resetn) begin
            write_cpl_valid <= 1'b0;
        end else begin
            write_cpl_valid <= write_cpl_ch_valid_candidate && ~write_cpl_busy & ~write_cpl_update;
        end
    end

    reg queue_wr_enable;

    reg write_cpl_update_d1;
    always @(posedge clk) begin
        if (~resetn) begin
            write_cpl_busy <= 1'b0;
            write_cpl_vaddr <= 'd0;
            write_cpl_size <= 'd0;
            write_cpl_ch <= 'd0;
            write_cpl_status <= 'd0;
            write_cpl_update <= 1'b0;
            write_cpl_update_d1 <= 1'b0;
        end else if (~write_cpl_busy & ~write_cpl_update) begin
            write_cpl_busy <= write_cpl_ch_valid_candidate;
            write_cpl_ch <= write_cpl_ch_candidate;
            write_cpl_status <= |w_write_cpl_size ? IDDMA_STAT_SUCCESS : IDDMA_STAT_FAILED ;
            write_cpl_vaddr <= transfer_start_vaddrs >> {write_cpl_ch_candidate, 6'd0};
            write_cpl_size <= w_write_cpl_size;
            write_cpl_update_d1 <= write_cpl_update;
        end else begin
            write_cpl_busy <= write_cpl_busy & ~(queue_wr_enable & queue_wr_ready);
            write_cpl_update <= (~write_cpl_update & queue_wr_enable & queue_wr_ready) | (write_cpl_update & ~transfer_cpl_ch_done);
            write_cpl_update_d1 <= write_cpl_update;
        end
    end

    assign transfer_cpl_ch = write_cpl_ch;
    assign transfer_cpl_ch_valid = write_cpl_update & ~write_cpl_update_d1;
    generate
        if (DISABLE_FRAME_INFO > 0 || IGNORE_CPL_SIZE > 0) begin
            assign w_write_cpl_size = transfer_issued_sizes >> {write_cpl_ch_candidate, 5'd0};
        end else begin
            assign w_write_cpl_size = transfer_completed_sizes >> {write_cpl_ch_candidate, 5'd0};
        end
    endgenerate

    // queue write
    reg queue_wr_ignore;
    always @(posedge clk) begin
        if (~resetn) begin
            queue_wr_data <= 'd0;
            queue_wr_keep <= 'd0;
            queue_wr_enable <= 'd0;
            queue_wr_ignore <= 1'b0;
        end else if (write_cpl_busy) begin
            queue_wr_data[63:2] <= cpl_q_head_addrs >> {write_cpl_ch, 6'd2};
            queue_wr_data[74:64] <= 11'd0 | (QEW >> 2); // byte -> word
            queue_wr_data[78:75] <= 4'd1;
            queue_wr_keep <= ({{RQ_DK{1'b0}}, 1'b1} << ((QEW >> 2) + 4)) - 1'b1;
            queue_wr_data[RQBASE+:QEWB] <= {64'd0, 56'd0, write_cpl_status, 32'd0, write_cpl_size, write_cpl_vaddr};
            queue_wr_enable <= ~(queue_wr_enable & queue_wr_ready);
            queue_wr_ignore <= stream_ch_d2d_valids >> write_cpl_ch;
        end else begin
            queue_wr_enable <= 1'b0;
        end
    end
    assign queue_wr_valid = queue_wr_enable && ~queue_wr_ignore;

    assign desc_req_ch = transfered_ch;
    assign desc_req_ch_valid = transfered_ch_valid & transfered_ch_ready;

endmodule
