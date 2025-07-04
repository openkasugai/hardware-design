/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_ch_separate_fifo #(
    parameter CH_NUM_LOG = 3,
    parameter DW = 32,
    parameter DL = 2,
    parameter MAX_INPUT_PER_CH = 10,
    parameter IVALID_BITS = 1,
    parameter OREADY_BITS = 1,
    parameter CYCLES = 100000
    ) ();

    wire clk, resetn;
    wire [31:0] rd;
    clk_reset clk_reset(
        .clk ( clk ),
        .resetn ( resetn ),
        .rd ( rd )
    );

    localparam CH_NUM = 1 << CH_NUM_LOG;

    reg [DW-1:0]         idata;
    reg [CH_NUM_LOG-1:0] ich;
    reg                  ivalid;
    wire                 iready;
    wire [DW*CH_NUM-1:0] odata;
    wire [CH_NUM-1:0]    ovalid;
    reg [CH_NUM-1:0]     oready;

    ch_separate_fifo #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .DW ( DW ),
        .DL ( DL )
    ) dut (
        .full ( ),
        .*
    );

    initial begin
        idata = 'd0;
        ich = 'd0;
        ivalid = 1'b0;
        oready = 'd0;
    end

    reg [DW-1:0] data[0:CH_NUM-1][0:255];
    reg [7:0]    wpos[0:CH_NUM-1];
    reg [7:0]    rpos[0:CH_NUM-1];
    wire [CH_NUM_LOG-1:0] cur_ich = rd[14+:CH_NUM_LOG];

    // input
    always @(posedge clk) begin
        if (~resetn) begin
            ivalid <= 1'b0;
        end else if (~ivalid | iready) begin
            ivalid <= &rd[3+:IVALID_BITS] && ({wpos[cur_ich] < rpos[cur_ich], wpos[cur_ich]} - rpos[cur_ich] < MAX_INPUT_PER_CH - (ivalid & ich == cur_ich));
            idata <= rd;
            ich <= cur_ich;
        end else begin
            ivalid <= ivalid & ~iready;
        end
    end
    always @(posedge clk) begin
        if (ivalid & iready) begin
            $display("%d [%2d]: i %h (%d)", $time, ich, idata, {wpos[ich] < rpos[ich], wpos[ich]} - rpos[ich]
                     + (ovalid[ich] & oready[ich] ? 0 : 1));
            if ({wpos[ich] < rpos[ich], wpos[ich]} - rpos[ich] + (ovalid[ich] & oready[ich] ? 0 : 1) > MAX_INPUT_PER_CH) begin
                $error("%d [%2d]: i max error", $time, ich);
            end
        end
        for (int i=0; i<CH_NUM; i++) begin
            if (ovalid[i] & oready[i]) begin
                $display("%d [%2d]: o %h (%d)", $time, i, odata[i*DW+:DW], {wpos[i] < rpos[i], wpos[i]} - rpos[i]
                         - (ivalid & iready & (ich==i) ? 0 : 1));
                if ({wpos[i] < rpos[i], wpos[i]} - rpos[i] - (ivalid & iready & (ich==i) ? 0 : 1) > MAX_INPUT_PER_CH) begin
                    $error("%d [%2d]: o max error", $time, i);
                end
            end
        end
    end
    // input save
    always @(posedge clk) begin
        if (~resetn) begin
            for (int i=0; i<CH_NUM; i++) begin
                wpos[i] <= 'd0;
            end
        end else begin
            for (int i=0; i<CH_NUM; i++) begin
                if (ivalid && iready && ich == i) begin
                    data[i][wpos[i]] <= idata;
                    wpos[i] <= wpos[i] + 1'b1;
                end
            end
        end
    end
    // output check
    always @(posedge clk) begin
        for (int i=0; i<CH_NUM; i++) begin
            if (~resetn) begin
                rpos[i] <= 'd0;
                oready[i] <= 1'b0;
            end else begin
                if (ovalid[i] & oready[i]) begin
                    if (odata[i*DW+:DW] !== data[i][rpos[i]]) begin
                        $fatal(2, "%d [%2d]: failed channel output: %h %h", $time, i,
                               odata[i*DW+:DW], data[i][rpos[i]]);
                    end
                    rpos[i] <= rpos[i] + 1'b1;
                end
                oready[i] <= &rd[8+i+:OREADY_BITS];
            end
        end
    end
    // cycles
    always @(posedge clk) begin
        if ($time > CYCLES) $finish();
    end

endmodule

module test_ch_separate_fifo_simple;

    tb_ch_separate_fifo tb();

endmodule

module test_ch_separate_fifo_slow_out;

    tb_ch_separate_fifo #(
        .OREADY_BITS ( 4 )
    ) tb();

endmodule

module test_ch_separate_fifo_not_full;

    tb_ch_separate_fifo #(
        .MAX_INPUT_PER_CH ( 4 ),
        .OREADY_BITS ( 5 )
    ) tb();

endmodule
