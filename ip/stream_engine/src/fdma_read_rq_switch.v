/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module fdma_read_rq_switch #(
    parameter ENGINE_IPORT_NUM = 2,
    parameter ENGINE_OPORT_NUM = 1, // don't modify
    parameter DESC_RQ_DW = 512,
    parameter RQ_DW = 384,
    parameter CH_NUM_LOG = 3,
    parameter CH_BASE = 0
    ) (
    input [(1<<CH_NUM_LOG)-1:0]              stream_valids,

    // from PCI TRX
    input [DESC_RQ_DW-1:0]                   i_rq_data,
    input                                    i_rq_last,
    input                                    i_rq_valid,
    output                                   i_rq_ready,

    // from core
    input [RQ_DW*ENGINE_IPORT_NUM-1:0]       i_se_data,
    input [ENGINE_IPORT_NUM-1:0]             i_se_last,
    input [ENGINE_IPORT_NUM-1:0]             i_se_valid,
    output [ENGINE_IPORT_NUM-1:0]            i_se_ready,

    // to DMA TX/RX
    output [DESC_RQ_DW-1:0]                  o_rq_data,
    output                                   o_rq_last,
    output                                   o_rq_valid,
    input                                    o_rq_ready,

    // to core
    output [DESC_RQ_DW*ENGINE_OPORT_NUM-1:0] o_se_data,
    output [ENGINE_OPORT_NUM-1:0]            o_se_last,
    output [ENGINE_OPORT_NUM-1:0]            o_se_valid,
    input [ENGINE_OPORT_NUM-1:0]             o_se_ready,

    input                                    clk,
    input                                    resetn
    );

    localparam CH_NUM = 1 << CH_NUM_LOG;
    localparam ICH_NUM_LOG = $clog2(ENGINE_IPORT_NUM + 1);
    localparam DESC_RQ_DW_LOG = $clog2(DESC_RQ_DW);

    reg                                 i2_rq_se;
    reg [DESC_RQ_DW-1:0]                i2_rq_data;
    reg                                 i2_rq_last;
    reg                                 i2_rq_valid;
    wire                                i2_rq_ready;

    wire w_cur_ch_stream_valid = stream_valids >> i_rq_data[96+:CH_NUM_LOG];
    always @(posedge clk) begin
        if (~resetn) begin
            i2_rq_se <= 1'b0;
            i2_rq_data <= 'd0;
            i2_rq_last <= 1'b0;
            i2_rq_valid <= 1'b0;
        end else if (i2_rq_ready) begin
            i2_rq_se <= CH_BASE <= i_rq_data[103:96] && i_rq_data[103:96] < CH_BASE + CH_NUM && w_cur_ch_stream_valid;
            i2_rq_data <= i_rq_data;
            i2_rq_last <= i_rq_last;
            i2_rq_valid <= i_rq_valid;
        end
    end
    assign i_rq_ready = i2_rq_ready;

    wire [DESC_RQ_DW-1:0]      i3_rq_data;
    wire                       i3_rq_last;
    wire                       i3_rq_se;
    wire                       i3_rq_valid;
    wire                       i3_rq_ready;
    wire                       i2_rq_start;

    axis_buf #(
        .DW ( DESC_RQ_DW + 1 )
    ) i_rq_buf (
        .idata ( {i2_rq_se, i2_rq_data} ),
        .ilast ( i2_rq_last ),
        .ivalid ( i2_rq_valid ),
        .iready ( i2_rq_ready ),
        .odata ( {i3_rq_se, i3_rq_data} ),
        .olast ( i3_rq_last ),
        .ovalid ( i3_rq_valid ),
        .oready ( i3_rq_ready ),
        .ostart_prev ( i2_rq_start ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    wire [DESC_RQ_DW*ENGINE_IPORT_NUM-1:0] i2_se_data;
    wire [ENGINE_IPORT_NUM-1:0]            i2_se_last;
    wire [ENGINE_IPORT_NUM-1:0]            i2_se_valid;
    wire [ENGINE_IPORT_NUM-1:0]            i2_se_ready;
    wire [ENGINE_IPORT_NUM-1:0]            i_se_start;

    generate
        for (genvar i=0; i<ENGINE_IPORT_NUM; i=i+1) begin
            axis_buf #(
                .DW ( RQ_DW )
            ) i_se_buf (
                .idata ( i_se_data[i*RQ_DW+:RQ_DW] ),
                .ilast ( i_se_last[i] ),
                .ivalid ( i_se_valid[i] ),
                .iready ( i_se_ready[i] ),
                .odata ( i2_se_data[i*DESC_RQ_DW+:RQ_DW] ),
                .olast ( i2_se_last[i] ),
                .ovalid ( i2_se_valid[i] ),
                .oready ( i2_se_ready[i] ),
                .ostart_prev ( i_se_start[i] ),
                .clk ( clk ),
                .resetn ( resetn )
            );
            assign i2_se_data[i*DESC_RQ_DW+DESC_RQ_DW-1:i*DESC_RQ_DW+RQ_DW] = 'd0;
        end
    endgenerate

    wire [ICH_NUM_LOG*ENGINE_IPORT_NUM-1:0] o2_se_ch_candidate;
    generate
        for (genvar i=0; i<ENGINE_IPORT_NUM; i=i+1) begin
            if (i==0) begin
                assign o2_se_ch_candidate[i*ICH_NUM_LOG+:ICH_NUM_LOG] = 'd1;
            end else begin
                assign o2_se_ch_candidate[i*ICH_NUM_LOG+:ICH_NUM_LOG] = ~|i_se_start[i-1:0] ? i + 'd1 : o2_se_ch_candidate[(i-1)*ICH_NUM_LOG+:ICH_NUM_LOG];
            end
        end
    endgenerate
    wire [ICH_NUM_LOG-1:0] o2_ch_candidate = ~|i_se_start ? 'd0 : o2_se_ch_candidate[ICH_NUM_LOG*(ENGINE_IPORT_NUM-1)+:ICH_NUM_LOG];

    wire                  o2_rq_last;
    wire                  o2_rq_valid;
    wire                  o2_rq_ready;
    wire                  o2_rq_se;
    reg [ICH_NUM_LOG-1:0] o2_i_ch;
    reg [ENGINE_IPORT_NUM:0] o2_ch_enable;
    reg                   o2_ch_valid;
    always @(posedge clk) begin
        if (~resetn) begin
            o2_i_ch <= 'd0;
            o2_ch_valid <= 1'b0;
            o2_ch_enable <= 'd0;
        end else if (|({i2_se_valid, o2_rq_valid} & {i2_se_ready, i3_rq_ready} & {i2_se_last, o2_rq_last}) | ~o2_ch_valid) begin
            o2_i_ch <= o2_ch_candidate;
            o2_ch_valid <= |i_se_start | i2_rq_start;
            o2_ch_enable <= |i_se_start | i2_rq_start ? 'd1 << o2_ch_candidate : 'd0;
        end
    end

    wire [ENGINE_OPORT_NUM-1:0] o2_se_ready;

    assign i2_se_ready = o2_ch_enable[ENGINE_IPORT_NUM:1] & {ENGINE_IPORT_NUM{o2_rq_ready}};
    assign i3_rq_ready = o2_ch_enable[0] & (o2_rq_se ? &o2_se_ready : o2_rq_ready);

    wire [DESC_RQ_DW-1:0] o2_rq_data = {i2_se_data, i3_rq_data} >> {o2_i_ch, {DESC_RQ_DW_LOG{1'b0}}};
    assign o2_rq_last = {i2_se_last, i3_rq_last} >> o2_i_ch;
    assign o2_rq_valid = {i2_se_valid, i3_rq_valid & o2_ch_valid} >> o2_i_ch;
    assign o2_rq_se = i3_rq_se & ~|o2_i_ch;

    axis_buf #(
        .DW ( DESC_RQ_DW )
    ) o_r1_buf (
        .idata ( o2_rq_data ),
        .ilast ( o2_rq_last ),
        .ivalid ( o2_rq_valid  & ~o2_rq_se ),
        .iready ( o2_rq_ready ),
        .odata ( o_rq_data ),
        .olast ( o_rq_last ),
        .ovalid ( o_rq_valid ),
        .oready ( o_rq_ready ),
        .ostart_prev ( ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    generate
        for (genvar i=0; i<ENGINE_OPORT_NUM; i=i+1) begin
            axis_buf #(
                .DW ( DESC_RQ_DW )
            ) o_se_buf (
                .idata ( o2_rq_data ),
                .ilast ( o2_rq_last ),
                .ivalid ( o2_rq_valid & o2_rq_se ),
                .iready ( o2_se_ready[i] ),
                .odata ( o_se_data[i*DESC_RQ_DW+:DESC_RQ_DW] ),
                .olast ( o_se_last[i] ),
                .ovalid ( o_se_valid[i] ),
                .oready ( o_se_ready[i] ),
                .ostart_prev ( ),
                .clk ( clk ),
                .resetn ( resetn )
            );
        end
    endgenerate

endmodule
