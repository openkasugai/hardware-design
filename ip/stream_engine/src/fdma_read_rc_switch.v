/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module fdma_read_rc_switch #(
    parameter ENGINE_IPORT_NUM = 1,
    parameter ENGINE_OPORT_NUM = 2,
    parameter [ENGINE_OPORT_NUM*8-1:0] TAG_BASE = {8'd99, 8'd98},
    parameter DESC_RC_DW = 512,
    parameter DESC_RC_DK = 16,
    parameter DESC_RC_USER = 16,
    parameter DISABLE_FRAME_INFO = 0,
    parameter RC_DW = 352,
    parameter RC_DK = 11,
    parameter RCBASE = 96,
    parameter IBUF_DEPTH = DISABLE_FRAME_INFO == 0 ? 2 : 4,
    parameter ENABLE_FRAME_INFO_OUT = 0,
    parameter CH_BASE = 0,
    parameter CH_NUM_LOG = 4,
    parameter DESC_CMD_VALID = 16,
    parameter DESC_DATA_POS = 32
    ) (
    // from PCI TRX
    input [DESC_RC_DW-1:0]                  i_rc_data,
    input [DESC_RC_DK-1:0]                  i_rc_keep,
    input [DESC_RC_USER-1:0]                i_rc_user,
    input                                   i_rc_last,
    input                                   i_rc_valid,
    output                                  i_rc_ready,

    // from core
    input [DESC_RC_DW*ENGINE_IPORT_NUM-1:0] i_se_data,
    input [DESC_RC_DK*ENGINE_IPORT_NUM-1:0] i_se_keep,
    input [ENGINE_IPORT_NUM-1:0]            i_se_last,
    input [ENGINE_IPORT_NUM-1:0]            i_se_valid,
    output [ENGINE_IPORT_NUM-1:0]           i_se_ready,

    // to DMA TX/RX
    output [DESC_RC_DW-1:0]                 o_rc_data,
    output [DESC_RC_DK-1:0]                 o_rc_keep,
    output [DESC_RC_USER-1:0]               o_rc_user,
    output                                  o_rc_last,
    output                                  o_rc_valid,
    input                                   o_rc_ready,

    // to core
    output [RC_DW*ENGINE_OPORT_NUM-1:0]     o_se_data,
    output [ENGINE_OPORT_NUM-1:0]           o_se_last,
    output [ENGINE_OPORT_NUM-1:0]           o_se_valid,
    input [ENGINE_OPORT_NUM-1:0]            o_se_ready,

    // debug
    output reg [31:0]                       o_rc_icount,
    output reg [31:0]                       o_rc_count,
    output reg [15:0]                       o_rc_count_fixed_cycle,

    // frame info out
    input [31:0]                            frame_info_in_size,
    input [CH_NUM_LOG-1:0]                  frame_info_in_ch,
    input                                   frame_info_in_valid,
    output                                  frame_info_in_ready,

    output [31:0]                           frame_info_out_size,
    output [CH_NUM_LOG-1:0]                 frame_info_out_ch,
    output                                  frame_info_out_valid,
    input                                   frame_info_out_ready,

    input                                   clk,
    input                                   resetn
    );

    localparam ICH_NUM_LOG = $clog2(ENGINE_IPORT_NUM + 1);
    localparam DESC_RC_DW_LOG = $clog2(DESC_RC_DW);
    localparam DESC_RC_DK_LOG = $clog2(DESC_RC_DK);
    localparam DESC_RC_USER_LOG = $clog2(DESC_RC_USER);
    localparam CH_NUM = 1 << CH_NUM_LOG;

    wire [DESC_RC_DW-1:0]                  i2_rc_data;
    wire [DESC_RC_DK-1:0]                  i2_rc_keep;
    wire [DESC_RC_USER-1:0]                i2_rc_user;
    wire                                   i2_rc_last;
    wire                                   i2_rc_valid;
    wire                                   i2_rc_ready;
    wire                                   i_rc_start;

    axis_buf #(
        .DW ( DESC_RC_DW + DESC_RC_DK + DESC_RC_USER ),
        .DEPTH ( IBUF_DEPTH )
    ) i_rc_buf (
        .idata ( {i_rc_user, i_rc_keep, i_rc_data} ),
        .ilast ( i_rc_last ),
        .ivalid ( i_rc_valid ),
        .iready ( i_rc_ready ),
        .odata ( {i2_rc_user, i2_rc_keep, i2_rc_data} ),
        .olast ( i2_rc_last ),
        .ovalid ( i2_rc_valid ),
        .oready ( i2_rc_ready ),
        .ostart_prev ( i_rc_start ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    reg [ENGINE_IPORT_NUM-1:0]             i2_start;
    reg [DESC_RC_DW*ENGINE_IPORT_NUM-1:0]  i2_se_data;
    reg [DESC_RC_DW*ENGINE_IPORT_NUM-1:0]  i2_se_data_save;
    reg [DESC_RC_DK*ENGINE_IPORT_NUM-1:0]  i2_se_keep;
    reg [DESC_RC_DK*ENGINE_IPORT_NUM-1:0]  i2_se_keep_save;
    reg [DESC_RC_USER*ENGINE_IPORT_NUM-1:0] i2_se_user;
    reg [ENGINE_IPORT_NUM-1:0]              i2_se_last;
    reg [ENGINE_IPORT_NUM-1:0]              i2_se_last_save;
    reg [ENGINE_IPORT_NUM-1:0]              i2_se_valid;
    wire [ENGINE_IPORT_NUM-1:0]             i2_se_ready;

    wire [DESC_RC_DW*ENGINE_IPORT_NUM-1:0] i3_se_data;
    wire [DESC_RC_DK*ENGINE_IPORT_NUM-1:0] i3_se_keep;
    wire [DESC_RC_USER*ENGINE_IPORT_NUM-1:0] i3_se_user;
    wire [ENGINE_IPORT_NUM-1:0]            i3_se_last;
    wire [ENGINE_IPORT_NUM-1:0]            i3_se_valid;
    wire [ENGINE_IPORT_NUM-1:0]            i3_se_ready;
    wire [ENGINE_IPORT_NUM-1:0]            i2_se_start;

    generate
        for (genvar i=0; i<ENGINE_IPORT_NUM; i=i+1) begin
            always @(posedge clk) begin
                if (~resetn) begin
                    i2_start[i] <= 1'b1;
                    i2_se_data[i*DESC_RC_DW+:DESC_RC_DW] <= 'd0;
                    i2_se_data_save[i*DESC_RC_DW+RCBASE+:DESC_RC_DW-RCBASE] <= 'd0;
                    i2_se_keep[i*DESC_RC_DK+:DESC_RC_DK] <= 'd0;
                    i2_se_keep_save[i*DESC_RC_DK+RCBASE/32+:DESC_RC_DK-RCBASE/32] <= 'd0;
                    i2_se_user[i*DESC_RC_USER+:DESC_RC_USER] <= 'd0;
                    i2_se_last[i] <= 1'b0;
                    i2_se_last_save[i] <= 1'b0;
                    i2_se_valid[i] <= 1'b0;
                end else if (i_se_valid[i] & i_se_ready[i]) begin
                    if (i_se_last[i]) begin
                        if (i2_start[i]) begin
                            i2_se_data[i*DESC_RC_DW+:DESC_RC_DW] <= {'d0, i2_se_data[i*DESC_RC_DW+RCBASE+:DESC_RC_DW-RCBASE]};
                            i2_se_keep[i*DESC_RC_DK+:DESC_RC_DK] <= {'d0, i2_se_keep[i*DESC_RC_DK+RCBASE/32+:DESC_RC_DK-RCBASE/32]};
                        end else begin
                            i2_se_data[i*DESC_RC_DW+:DESC_RC_DW] <= {i_se_data[RCBASE-1:0], i2_se_data_save[i*DESC_RC_DW+RCBASE+:DESC_RC_DW-RCBASE]};
                            i2_se_keep[i*DESC_RC_DK+:DESC_RC_DK] <= {i_se_keep[RCBASE/32-1:0], i2_se_keep_save[i*DESC_RC_DK+RCBASE/32+:DESC_RC_DK-RCBASE/32]};
                        end
                        if (|i_se_keep[DESC_RC_DK-1:RCBASE/32]) begin
                            i2_se_data_save[i*DESC_RC_DW+RCBASE+:DESC_RC_DW-RCBASE] <= i_se_data[i*DESC_RC_DW+RCBASE+:DESC_RC_DW-RCBASE];
                            i2_se_keep_save[i*DESC_RC_DK+RCBASE/32+:DESC_RC_DK-RCBASE/32] <= i_se_keep[i*DESC_RC_DK+RCBASE/32+:DESC_RC_DK-RCBASE/32];
                            i2_se_last_save[i] <= 1'b1;
                            i2_se_last[i] <= 1'b0;
                            i2_start[i] <= 1'b0;
                        end else begin
                            i2_se_data_save[i*DESC_RC_DW+RCBASE+:DESC_RC_DW-RCBASE] <= 'd0;
                            i2_se_keep_save[i*DESC_RC_DK+RCBASE/32+:DESC_RC_DK-RCBASE/32] <= 'd0;
                            i2_start[i] <= 1'b1;
                            i2_se_last[i] <= 1'b1;
                            i2_se_last_save[i] <= 1'b0;
                        end
                    end else begin
                        i2_start[i] <= 1'b0;
                        i2_se_data_save[i*DESC_RC_DW+RCBASE+:DESC_RC_DW-RCBASE] <= i_se_data[i*DESC_RC_DW+RCBASE+:DESC_RC_DW-RCBASE];
                        i2_se_data[i*DESC_RC_DW+:DESC_RC_DW] <= {i_se_data[RCBASE-1:0], i2_se_data_save[i*DESC_RC_DW+RCBASE+:DESC_RC_DW-RCBASE]};
                        i2_se_keep_save[i*DESC_RC_DK+RCBASE/32+:DESC_RC_DK-RCBASE/32] <= i_se_keep[i*DESC_RC_DK+RCBASE/32+:DESC_RC_DK-RCBASE/32];
                        i2_se_keep[i*DESC_RC_DK+:DESC_RC_DK] <= {i_se_keep[RCBASE/32-1:0], i2_se_keep_save[i*DESC_RC_DK+RCBASE/32+:DESC_RC_DK-RCBASE/32]};
                        i2_se_user[i*DESC_RC_USER+:DESC_RC_USER] <= i2_start[i] ? {i_se_data[71:64], i_se_data[46:43], i_se_data[15:12]} : i2_se_user[i*DESC_RC_USER+:DESC_RC_USER];
                        i2_se_last[i] <= 1'b0;
                    end
                    i2_se_valid[i] <= ~i2_start[i];
                end else if (i2_se_last_save[i] & i2_se_ready[i]) begin
                    i2_se_data[i*DESC_RC_DW+:DESC_RC_DW] <= {'d0, i2_se_data_save[i*DESC_RC_DW+RCBASE+:DESC_RC_DW-RCBASE]};
                    i2_se_keep[i*DESC_RC_DK+:DESC_RC_DK] <= {'d0, i2_se_keep_save[i*DESC_RC_DK+RCBASE/32+:DESC_RC_DK-RCBASE/32]};
                    i2_se_data_save[i*DESC_RC_DW+RCBASE+:DESC_RC_DW-RCBASE] <= 'd0;
                    i2_se_keep_save[i*DESC_RC_DK+RCBASE/32+:DESC_RC_DK-RCBASE/32] <= 'd0;
                    i2_se_last[i] <= 1'b1;
                    i2_se_last_save[i] <= 1'b0;
                    i2_se_valid[i] <= 1'b1;
                    i2_start[i] <= 1'b1;
                end else begin
                    i2_se_valid[i] <= i2_se_valid[i] & ~i2_se_ready[i];
                end
            end

            assign i_se_ready[i] = ~i2_se_valid[i] | (i2_se_ready[i] && ~i2_se_last_save[i]);

            axis_buf #(
                .DW ( DESC_RC_DW + DESC_RC_DK + DESC_RC_USER )
            ) i_rc_buf (
                .idata ( {i2_se_user[i*DESC_RC_USER+:DESC_RC_USER], i2_se_keep[i*DESC_RC_DK+:DESC_RC_DK], i2_se_data[i*DESC_RC_DW+:DESC_RC_DW]} ),
                .ilast ( i2_se_last[i] ),
                .ivalid ( i2_se_valid[i] ),
                .iready ( i2_se_ready[i] ),
                .odata ( {i3_se_user[i*DESC_RC_USER+:DESC_RC_USER], i3_se_keep[i*DESC_RC_DK+:DESC_RC_DK], i3_se_data[i*DESC_RC_DW+:DESC_RC_DW]} ),
                .olast ( i3_se_last[i] ),
                .ovalid ( i3_se_valid[i] ),
                .oready ( i3_se_ready[i] ),
                .ostart_prev ( i2_se_start[i] ),
                .clk ( clk ),
                .resetn ( resetn )
            );
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
    wire [ICH_NUM_LOG-1:0] o2_ch_candidate = i_rc_start || i2_rc_valid ? 'd0 : o2_se_ch_candidate[ICH_NUM_LOG*(ENGINE_IPORT_NUM-1)+:ICH_NUM_LOG];

    wire                  o2_rc_last;
    wire                  o2_rc_valid;
    wire                  o2_rc_ready;
    reg [ICH_NUM_LOG-1:0] o2_ch;
    reg [ENGINE_IPORT_NUM:0] o2_ch_enable;
    reg                   o2_ch_valid;
    wire                  o2ch_mod;
    always @(posedge clk) begin
        if (~resetn) begin
            o2_ch <= 'd0;
            o2_ch_valid <= 1'b0;
            o2_ch_enable <= 'd0;
        end else if (o2ch_mod) begin
            o2_ch <= o2_ch_candidate;
            o2_ch_valid <= ~|o2_ch_candidate ? i_rc_start || i_rc_valid : |i2_se_start;
            o2_ch_enable <= |i2_se_start | i_rc_start ? 'd1 << o2_ch_candidate : 'd0;
        end
    end
    assign o2ch_mod = |({i3_se_valid, o2_rc_valid} & {i3_se_ready, i2_rc_ready} & {i3_se_last, o2_rc_last}) | ~o2_ch_valid;

    wire [ENGINE_OPORT_NUM-1:0] o2_se_ready;
    wire [ENGINE_OPORT_NUM-1:0] o2_se_valid;
    wire [ENGINE_OPORT_NUM-1:0] o2_rc_se;
    reg [ENGINE_OPORT_NUM-1:0] o2_rc_se_saved;
    reg                        o2_rc_sop;

    assign i3_se_ready = o2_ch_enable[ENGINE_IPORT_NUM:1] & {ENGINE_IPORT_NUM{o2_rc_ready}};
    generate
        for (genvar i=0; i<ENGINE_OPORT_NUM; i=i+1) begin
            assign o2_rc_se[i] = o2_rc_sop ? i2_rc_user[15:8] == TAG_BASE[i*8+:8] : o2_rc_se_saved[i];
            assign o2_se_valid[i] = i2_rc_valid && o2_rc_se[i] & o2_ch_enable[0] & o2_ch_valid;
        end
    endgenerate
    always @(posedge clk) begin
        if (~resetn) begin
            o2_rc_se_saved <= 'd0;
            o2_rc_sop <= 1'b1;
        end else begin
            o2_rc_se_saved <= o2_rc_se;
            o2_rc_sop <= (i2_rc_valid & i2_rc_ready & i2_rc_last) | (o2_rc_sop & ~(i2_rc_valid & i2_rc_ready));
        end
    end
    assign i2_rc_ready = o2_ch_enable[0] & |({o2_rc_se, ~|o2_rc_se} & {o2_se_ready, o2_rc_ready});

    wire [DESC_RC_DW-1:0] o2_rc_data = {i3_se_data, i2_rc_data} >> {o2_ch, {DESC_RC_DW_LOG{1'b0}}};
    wire [DESC_RC_DK-1:0] o2_rc_keep = {i3_se_keep, i2_rc_keep} >> {o2_ch, {DESC_RC_DK_LOG{1'b0}}};
    wire [DESC_RC_USER-1:0] o2_rc_user = {i3_se_user, i2_rc_user} >> {o2_ch, {DESC_RC_USER_LOG{1'b0}}};
    assign o2_rc_last = {i3_se_last, i2_rc_last} >> o2_ch;
    assign o2_rc_valid = {i3_se_valid, i2_rc_valid & o2_ch_valid} >> o2_ch;

    wire o2_rc_buf_valid = o2_rc_valid & (|o2_ch_enable[ENGINE_IPORT_NUM:1] || ~|o2_rc_se);

    axis_buf #(
        .DW ( DESC_RC_DW + DESC_RC_DK + DESC_RC_USER ),
        .INVALID_AFTER_LAST ( 1 )
    ) o_rc_buf (
        .idata ( {o2_rc_user, o2_rc_keep, o2_rc_data} ),
        .ilast ( o2_rc_last ),
        .ivalid ( o2_rc_buf_valid ),
        .iready ( o2_rc_ready ),
        .odata ( {o_rc_user, o_rc_keep, o_rc_data} ),
        .olast ( o_rc_last ),
        .ovalid ( o_rc_valid ),
        .oready ( o_rc_ready ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    wire [RC_DW-1:0]        o2_se_data;
    wire                    o2_se_last;

    assign o2_se_data = {i2_rc_data, 24'd0, i2_rc_user[15:8], 17'd0, i2_rc_user[7:4], 27'd0, i2_rc_user[3:0], 12'd0};
    assign o2_se_last = o2_rc_last;

    generate
        for (genvar i=0; i<ENGINE_OPORT_NUM; i=i+1) begin
            axis_buf #(
                .DW ( RC_DW )
            ) o_rc_buf (
                .idata ( o2_se_data ),
                .ilast ( o2_se_last ),
                .ivalid ( o2_se_valid[i] ),
                .iready ( o2_se_ready[i] ),
                .odata ( o_se_data[i*RC_DW+:RC_DW] ),
                .olast ( o_se_last[i] ),
                .ovalid ( o_se_valid[i] ),
                .oready ( o_se_ready[i] ),
                .clk ( clk ),
                .resetn ( resetn )
            );
        end
    endgenerate

    always @(posedge clk) begin
        if (~resetn) begin
            o_rc_icount <= 'd0;
        end else if (i_rc_valid & i_rc_ready & i_rc_user[15]) begin
            o_rc_icount <= o_rc_icount + 1'b1;
        end
    end
    always @(posedge clk) begin
        if (~resetn) begin
            o_rc_count <= 'd0;
            o_rc_count_fixed_cycle <= 'd0;
        end else if (o_rc_valid & o_rc_ready & o_rc_user[15]) begin
            o_rc_count <= o_rc_count + 1'b1;
            o_rc_count_fixed_cycle <= 'd0;
        end else begin
            o_rc_count_fixed_cycle <= &o_rc_count_fixed_cycle ? o_rc_count_fixed_cycle : o_rc_count_fixed_cycle + 1'b1;
        end
    end

    generate
        if (ENABLE_FRAME_INFO_OUT > 0) begin
           wire is_desc_user = CH_BASE <= o2_rc_user[15:8] && o2_rc_user[15:8] < CH_BASE + CH_NUM;
           wire is_desc_data_valid = o2_rc_data[DESC_CMD_VALID] & |o2_rc_data[DESC_DATA_POS+:32];
           wire is_desc_valid = o2_rc_buf_valid & o2_rc_ready & ~|o2_ch;

           wire [CH_NUM_LOG-1:0] desc_out_user;
           wire [31:0]           desc_out_data;
           wire                  desc_out_valid;
           wire                  desc_out_ready;

           fifo #(
               .DW ( CH_NUM_LOG + 32 ),
               .DL ( 5 )
           ) frame_info_out_fifo (
               .idata ( {o2_rc_user[8+:CH_NUM_LOG], o2_rc_data[DESC_DATA_POS+:32]} ),
               .ivalid ( is_desc_valid & is_desc_data_valid & is_desc_user ),
               .iready ( /*TODO: back pressure*/ ),
               .odata ( {desc_out_user, desc_out_data} ),
               .ovalid ( desc_out_valid ),
               .oready ( desc_out_ready ),
               .clk ( clk ),
               .resetn ( resetn )
           );

           reg [31:0]            frame_info_out_data_reg;
           reg [CH_NUM_LOG-1:0]  frame_info_out_user_reg;
           reg                   frame_info_out_valid_reg;
           always @(posedge clk) begin
              if (~resetn) begin
                 frame_info_out_valid_reg <= 1'b0;
              end else if (frame_info_in_valid & frame_info_in_ready) begin
                 frame_info_out_valid_reg <= 1'b1;
                 frame_info_out_data_reg <= frame_info_in_size;
                 frame_info_out_user_reg <= frame_info_in_ch;
              end else if (desc_out_valid & desc_out_ready) begin
                 frame_info_out_valid_reg <= 1'b1;
                 frame_info_out_data_reg <= desc_out_data;
                 frame_info_out_user_reg <= desc_out_user;
              end else begin
                 frame_info_out_valid_reg <= frame_info_out_valid_reg & ~frame_info_out_ready;
              end
           end
           assign desc_out_ready = frame_info_out_ready & ~frame_info_in_valid;
           assign frame_info_in_ready = frame_info_out_ready;

           assign frame_info_out_size = frame_info_out_data_reg;
           assign frame_info_out_ch = frame_info_out_user_reg;
           assign frame_info_out_valid = frame_info_out_valid_reg;
        end else begin
           assign frame_info_in_ready = 1'b1;
           assign frame_info_out_valid = 1'b0;
        end
    endgenerate


endmodule
