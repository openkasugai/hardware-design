/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module fdma_write_rq_switch #(
    parameter ENGINE_IPORT_NUM = 2,
    parameter ENGINE_OPORT_NUM = 1, // don't modify
    parameter DESC_RQ_DW = 512,
    parameter DESC_RQ_DK = 16,
    parameter RQ_DW = 384,
    parameter RQBASE = 128,
    parameter CH_NUM_LOG = 3,
    parameter CH_BASE = 0
    ) (
    input [64*(1<<CH_NUM_LOG)-1:0]           range_starts,
    input [64*(1<<CH_NUM_LOG)-1:0]           range_ends,
    input [(1<<CH_NUM_LOG)-1:0]              range_valids,

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
    output [DESC_RQ_DK*ENGINE_OPORT_NUM-1:0] o_se_keep,
    output [ENGINE_OPORT_NUM-1:0]            o_se_last,
    output [ENGINE_OPORT_NUM-1:0]            o_se_valid,
    input [ENGINE_OPORT_NUM-1:0]             o_se_ready,

    input                                    clk,
    input                                    resetn
    );

    localparam CH_NUM = 1 << CH_NUM_LOG;
    localparam ICH_NUM_LOG = $clog2(ENGINE_IPORT_NUM + 1);
    localparam DESC_RQ_DW_LOG = $clog2(DESC_RQ_DW);

    reg [CH_NUM-1:0]                    i2_rq_se_lge_start;
    reg [CH_NUM-1:0]                    i2_rq_se_heq_start;
    reg [CH_NUM-1:0]                    i2_rq_se_hgt_start;
    reg [CH_NUM-1:0]                    i2_rq_se_llt_end;
    reg [CH_NUM-1:0]                    i2_rq_se_heq_end;
    reg [CH_NUM-1:0]                    i2_rq_se_hlt_end;

    wire [63:0]                         i_addr = {i_rq_data[63:2], 2'd0};
    generate
        for (genvar i=0; i<CH_NUM; i=i+1) begin
            always @(posedge clk) begin
                if (~resetn) begin
                    i2_rq_se_lge_start[i] <= 1'b0;
                    i2_rq_se_heq_start[i] <= 1'b0;
                    i2_rq_se_hgt_start[i] <= 1'b0;
                    i2_rq_se_llt_end[i] <= 1'b0;
                    i2_rq_se_heq_end[i] <= 1'b0;
                    i2_rq_se_hlt_end[i] <= 1'b0;
                end else if (i_rq_ready) begin
                    i2_rq_se_lge_start[i] <= range_starts[i*64+:32] <= i_addr[31:0];
                    i2_rq_se_heq_start[i] <= range_starts[i*64+32+:32] == i_addr[63:32];
                    i2_rq_se_hgt_start[i] <= range_starts[i*64+32+:32] < i_addr[63:32];
                    i2_rq_se_llt_end[i] <= range_ends[i*64+:32] > i_addr[31:0];
                    i2_rq_se_heq_end[i] <= range_ends[i*64+32+:32] == i_addr[63:32];
                    i2_rq_se_hlt_end[i] <= range_ends[i*64+32+:32] > i_addr[63:32];
                end
            end
        end
    endgenerate

    reg                  i2_rq_start;
    reg [DESC_RQ_DK-1:0] i2_rq_keep;
    reg [10:0]           i2_rq_dword;
    wire [10:0]          w_i2_rq_dword;
    always @(posedge clk) begin
        if (~resetn) begin
            i2_rq_start <= 1'b1;
            i2_rq_dword <= 'd0;
        end else if (i_rq_valid & i_rq_ready) begin
            i2_rq_start <= i_rq_last;
            if (i2_rq_start) begin
                i2_rq_dword <= w_i2_rq_dword;
            end else if (i2_rq_dword >= DESC_RQ_DK) begin
                i2_rq_dword <= i2_rq_dword - DESC_RQ_DK;
            end else begin
                i2_rq_dword <= 'd0;
            end
        end
    end
    generate
        for (genvar i=0; i<DESC_RQ_DK; i=i+1) begin
            always @(posedge clk) begin
                if (~resetn) begin
                    i2_rq_keep[i] <= 1'b0;
                end else if (i_rq_valid & i_rq_ready) begin
                    if (i2_rq_start) begin
                        i2_rq_keep[i] <= i < RQBASE/32;
                    end else begin
                        i2_rq_keep[i] <= i2_rq_dword > i;
                    end
                end
            end
        end
    endgenerate
    assign w_i2_rq_dword = i_rq_data[64+:11];

    reg [DESC_RQ_DW-1:0]                i2_rq_data;
    reg                                 i2_rq_last;
    reg                                 i2_rq_valid;
    wire                                i2_rq_ready;
    always @(posedge clk) begin
        if (~resetn) begin
            i2_rq_data <= 'd0;
            i2_rq_last <= 1'b0;
            i2_rq_valid <= 1'b0;
        end else if (i_rq_ready) begin
            i2_rq_data <= i_rq_data;
            i2_rq_last <= i_rq_last;
            i2_rq_valid <= i_rq_valid;
        end
    end
    assign i_rq_ready = i2_rq_ready;

    reg [DESC_RQ_DW-1:0]      i3_rq_data;
    reg [DESC_RQ_DK-1:0]      i3_rq_keep;
    reg                       i3_rq_last;
    reg                       i3_rq_se;
    reg                       i3_rq_valid;
    reg                       i3_rq_sop;
    wire                      i3_rq_ready;

    always @(posedge clk) begin
        if (~resetn) begin
            i3_rq_data <= 'd0;
            i3_rq_keep <= 'd0;
            i3_rq_last <= 1'b0;
            i3_rq_valid <= 1'b0;
            i3_rq_se <= 'b0;
            i3_rq_sop <= 1'b0;
        end else if (i2_rq_ready) begin
            if (i3_rq_sop) begin
                i3_rq_se <= |(((i2_rq_se_lge_start & i2_rq_se_heq_start) | i2_rq_se_hgt_start) &
                              ((i2_rq_se_llt_end & i2_rq_se_heq_end) | i2_rq_se_hlt_end) & range_valids);
            end
            i3_rq_data <= i2_rq_data;
            i3_rq_keep <= i2_rq_keep;
            i3_rq_last <= i2_rq_last;
            i3_rq_valid <= i2_rq_valid;
            i3_rq_sop <= i2_rq_start;
        end
    end
    assign i2_rq_ready = i3_rq_ready;

    wire [DESC_RQ_DW-1:0]      i4_rq_data;
    wire [DESC_RQ_DK-1:0]      i4_rq_keep;
    wire                       i4_rq_last;
    wire                       i4_rq_se;
    wire                       i4_rq_valid;
    wire                       i4_rq_ready;
    wire                       i3_rq_start;

    axis_buf #(
        .DW ( DESC_RQ_DW + DESC_RQ_DK + 1 )
    ) i_rq_buf (
        .idata ( {i3_rq_se, i3_rq_keep, i3_rq_data} ),
        .ilast ( i3_rq_last ),
        .ivalid ( i3_rq_valid ),
        .iready ( i3_rq_ready ),
        .odata ( {i4_rq_se, i4_rq_keep, i4_rq_data} ),
        .olast ( i4_rq_last ),
        .ovalid ( i4_rq_valid ),
        .oready ( i4_rq_ready ),
        .ostart_prev ( i3_rq_start ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    reg [RQ_DW*ENGINE_IPORT_NUM-1:0] r_i2_se_data;
    reg [ENGINE_IPORT_NUM-1:0]       r_i2_se_last;
    reg [ENGINE_IPORT_NUM-1:0]       r_i2_se_valid;
    reg [ENGINE_IPORT_NUM-1:0]       r_i2_se_phase;
    wire [RQ_DW*ENGINE_IPORT_NUM-1:0] i2_se_data;
    wire [ENGINE_IPORT_NUM-1:0]       i2_se_last;
    wire [ENGINE_IPORT_NUM-1:0]       i2_se_valid;
    wire [ENGINE_IPORT_NUM-1:0]       i2_se_ready;

    generate
        for (genvar i=0; i<ENGINE_IPORT_NUM; i=i+1) begin
            always @(posedge clk) begin
                if (~resetn) begin
                    r_i2_se_data[i*RQ_DW+:RQ_DW] <= 'd0;
                    r_i2_se_valid[i] <= 1'b0;
                    r_i2_se_last[i] <= 1'b0;
                    r_i2_se_phase[i] <= 1'b0;
                end else if (i_se_valid[i] & i_se_ready[i]) begin
                    r_i2_se_data[i*RQ_DW+:RQ_DW] <= i_se_data[i*RQ_DW+:RQ_DW];
                    r_i2_se_valid[i] <= 1'b1;
                    r_i2_se_phase[i] <= 1'b0;
                    r_i2_se_last[i] <= i_se_last[i];
                end else if (i2_se_ready[i]) begin
                    r_i2_se_valid[i] <= r_i2_se_valid[i] & ~r_i2_se_phase[i];
                    r_i2_se_phase[i] <= r_i2_se_valid[i] & ~r_i2_se_phase[i];
                    r_i2_se_data[i*RQ_DW+:RQ_DW] <= {'d0, r_i2_se_data[i*RQ_DW+RQBASE+:RQ_DW-RQBASE]};
                end
            end
            assign i2_se_data[i*RQ_DW+:RQ_DW] = ~r_i2_se_phase[i] ? {'d0, r_i2_se_data[i*RQ_DW+:RQBASE]} : r_i2_se_data[i*RQ_DW+:RQ_DW];
            assign i2_se_valid[i] = r_i2_se_valid[i];
            assign i2_se_last[i] = r_i2_se_last[i] & r_i2_se_phase[i];
            assign i_se_ready[i] = ~r_i2_se_valid[i] | (i2_se_ready[i] & r_i2_se_phase[i]);
        end
    endgenerate

    wire [DESC_RQ_DW*ENGINE_IPORT_NUM-1:0] i3_se_data;
    wire [ENGINE_IPORT_NUM-1:0]            i3_se_last;
    wire [ENGINE_IPORT_NUM-1:0]            i3_se_valid;
    wire [ENGINE_IPORT_NUM-1:0]            i3_se_ready;
    wire [ENGINE_IPORT_NUM-1:0]            i2_se_start;

    generate
        for (genvar i=0; i<ENGINE_IPORT_NUM; i=i+1) begin
            axis_buf #(
                .DW ( RQ_DW )
            ) i_se_buf (
                .idata ( i2_se_data[i*RQ_DW+:RQ_DW] ),
                .ilast ( i2_se_last[i] ),
                .ivalid ( i2_se_valid[i] ),
                .iready ( i2_se_ready[i] ),
                .odata ( i3_se_data[i*DESC_RQ_DW+:RQ_DW] ),
                .olast ( i3_se_last[i] ),
                .ovalid ( i3_se_valid[i] ),
                .oready ( i3_se_ready[i] ),
                .ostart_prev ( i2_se_start[i] ),
                .clk ( clk ),
                .resetn ( resetn )
            );
            assign i3_se_data[i*DESC_RQ_DW+DESC_RQ_DW-1:i*DESC_RQ_DW+RQ_DW] = 'd0;
        end
    endgenerate

    wire [ICH_NUM_LOG*ENGINE_IPORT_NUM-1:0] o2_se_ch_candidate;
    generate
        for (genvar i=0; i<ENGINE_IPORT_NUM; i=i+1) begin
            if (i==0) begin
                assign o2_se_ch_candidate[i*ICH_NUM_LOG+:ICH_NUM_LOG] = 'd1;
            end else begin
                assign o2_se_ch_candidate[i*ICH_NUM_LOG+:ICH_NUM_LOG] = ~|i2_se_start[i-1:0] ? i + 'd1 : o2_se_ch_candidate[(i-1)*ICH_NUM_LOG+:ICH_NUM_LOG];
            end
        end
    endgenerate
    wire [ICH_NUM_LOG-1:0] o2_ch_candidate = ~|i2_se_start ? 'd0 : o2_se_ch_candidate[ICH_NUM_LOG*(ENGINE_IPORT_NUM-1)+:ICH_NUM_LOG];

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
        end else if (|({i3_se_valid, o2_rq_valid} & {i3_se_ready, i4_rq_ready} & {i3_se_last, o2_rq_last}) | ~o2_ch_valid) begin
            o2_i_ch <= o2_ch_candidate;
            o2_ch_valid <= |i2_se_start | i3_rq_start;
            o2_ch_enable <= |i2_se_start | i3_rq_start ? 'd1 << o2_ch_candidate : 'd0;
        end
    end
    wire [ENGINE_OPORT_NUM-1:0] o2_se_ready;

    assign i3_se_ready = o2_ch_enable[ENGINE_IPORT_NUM:1] & {ENGINE_IPORT_NUM{o2_rq_ready}};
    assign i4_rq_ready = o2_ch_enable[0] & (o2_rq_se ? &o2_se_ready : o2_rq_ready);

    wire [DESC_RQ_DW-1:0]       o2_rq_data = {i3_se_data, i4_rq_data} >> {o2_i_ch, {DESC_RQ_DW_LOG{1'b0}}};
    wire [DESC_RQ_DK-1:0]       o2_rq_keep = i4_rq_keep;
    assign o2_rq_last = {i3_se_last, i4_rq_last} >> o2_i_ch;
    assign o2_rq_valid = {i3_se_valid, i4_rq_valid & o2_ch_valid} >> o2_i_ch;
    assign o2_rq_se = i4_rq_se & ~|o2_i_ch;

    axis_buf #(
        .DW ( DESC_RQ_DW )
    ) o_rq_buf (
        .idata ( o2_rq_data ),
        .ilast ( o2_rq_last ),
        .ivalid ( o2_rq_valid & ~o2_rq_se ),
        .iready ( o2_rq_ready ),
        .odata ( o_rq_data ),
        .olast ( o_rq_last ),
        .ovalid ( o_rq_valid ),
        .oready ( o_rq_ready ),
        .ostart_prev ( ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    reg [RQBASE-1:0]            o2_se_data_save;
    reg [RQBASE/32-1:0]         o2_se_keep_save;
    reg                         o2_se_last_save;
    reg [DESC_RQ_DW-1:0]        o2_se_data;
    reg [DESC_RQ_DK-1:0]        o2_se_keep;
    reg                         o2_se_last;
    reg [ENGINE_OPORT_NUM-1:0]  o2_se_valids;
    reg                         o2_se_start;

    always @(posedge clk) begin
        if (~resetn) begin
            o2_se_start <= 1'b1;
            o2_se_data_save <= 'd0;
            o2_se_keep_save <= 'd0;
            o2_se_last_save <= 1'b0;
            o2_se_data <= 'd0;
            o2_se_keep <= 'd0;
            o2_se_last <= 1'b0;
        end else if (o2_rq_valid & o2_rq_se & &o2_se_ready) begin
            if (o2_se_start) begin
                o2_se_data_save <= o2_rq_data[RQBASE-1:0];
                o2_se_keep_save <= o2_rq_keep[RQBASE/32-1:0];
                o2_se_last_save <= o2_rq_last;
                o2_se_data <= {'d0, o2_se_data_save};
                o2_se_keep <= {'d0, o2_se_keep_save};
                o2_se_last <= o2_se_last_save;
                o2_se_start <= 1'b0;
            end else begin
                o2_se_data_save <= o2_rq_data[DESC_RQ_DW-1-:RQBASE];
                o2_se_keep_save <= o2_rq_keep[DESC_RQ_DK-1-:RQBASE/32];
                o2_se_last_save <= o2_rq_last && |o2_rq_keep[DESC_RQ_DK-1-:RQBASE/32];
                o2_se_data <= {o2_rq_data, o2_se_data_save};
                o2_se_keep <= {o2_rq_keep, o2_se_keep_save};
                o2_se_last <= o2_rq_last && ~|o2_rq_keep[DESC_RQ_DK-1-:RQBASE/32];
                o2_se_start <= o2_rq_last;
            end
        end else if (&o2_se_ready & o2_se_last_save) begin
            o2_se_last_save <= 1'b0;
            o2_se_data <= {'d0, o2_se_data_save};
            o2_se_keep <= {'d0, o2_se_keep_save};
            o2_se_last <= o2_se_last_save;
        end
    end

    generate
        for (genvar i=0; i<ENGINE_OPORT_NUM; i=i+1) begin
            always @(posedge clk) begin
                if (~resetn) begin
                    o2_se_valids[i] <= 1'b0;
                end else if (o2_rq_valid & o2_rq_se & &o2_se_ready) begin
                    o2_se_valids[i] <= ~o2_se_start | o2_se_last_save;
                end else begin
                    o2_se_valids[i] <= (&o2_se_ready & o2_se_last_save) | (o2_se_valids[i] & ~o2_se_ready[i]);
                end
            end
            axis_buf #(
                .DW ( DESC_RQ_DW + DESC_RQ_DK )
            ) o_rc_buf (
                .idata ( {o2_se_keep, o2_se_data} ),
                .ilast ( o2_se_last ),
                .ivalid ( o2_se_valids[i] ),
                .iready ( o2_se_ready[i] ),
                .odata ( {o_se_keep[i*DESC_RQ_DK+:DESC_RQ_DK], o_se_data[i*DESC_RQ_DW+:DESC_RQ_DW]} ),
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
