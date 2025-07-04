/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_tkeep_gen #(
    parameter DW = 512,
    parameter CHECK_COUNT = 10000
    ) ();

    wire clk, resetn;
    wire [31:0] rd;

    clk_reset clk_reset (
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
    );

    reg [DW-1:0] tdata;
    reg          tvalid;
    reg          tready;
    reg          tlast;

    wire [DW/32-1:0] tkeep;

    tkeep_gen #(
       .DW ( DW )
    ) dut (
        .rq_dma_cwr_axis_tdata ( tdata ),
        .rq_dma_cwr_axis_tvalid ( tvalid ),
        .rq_dma_cwr_axis_tready ( tready ),
        .rq_dma_cwr_axis_tlast ( tlast ),
        .rq_dma_cwr_axis_tkeep_1t ( tkeep ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    reg [10:0]       payload_dword;
    wire [10:0]      cur_payload_dword;
    wire             cur_valid;

    always @(posedge clk) begin
        if (~resetn) begin
            tdata <= 'd0;
            tvalid <= 'b0;
            tready <= 'b0;
            tlast <= 'b0;
            payload_dword <= 'd0;
        end else if (~tvalid || tready) begin
            if (~|payload_dword) begin
                tdata <= {'d0, cur_payload_dword, rd, rd};
                if (cur_valid) begin
                    payload_dword <= cur_payload_dword;
                    tlast <= 1'b0;
                end
            end else begin
                for (int i=0; i<DW; i+=32) tdata[i+:32] <= rd + i/32;
                if (cur_valid) begin
                    payload_dword <= cur_payload_dword > DW/32 ? cur_payload_dword - DW/32 : 'd0;
                    tlast <= cur_payload_dword <= DW/32;
                end
            end
            tvalid <= cur_valid;
            tready <= rd[28];
        end else begin
            tready <= rd[28];
        end
    end
    assign cur_payload_dword = ~|payload_dword ? ~|rd[12+:6] ? 'd1 : 'd0 | rd[12+:6] : payload_dword;
    assign cur_valid = rd[30];

    reg out_valid;
    reg out_first;
    reg [DW/32-1:0] out_dword;
    wire [DW/32-1:0] out_tkeep;
    always @(posedge clk) begin
        if (~resetn) begin
            out_valid <= 1'b0;
            out_first <= 1'b1;
            out_dword <= 'd0;
        end else begin
            out_valid <= tvalid & tready;
            out_first <= (out_first & (~tvalid || ~tready)) | (tvalid & tready & tlast);
            if (out_first & tvalid & tready) begin
                out_dword <= tdata[64+:11] + 3'd4;
            end else if (tvalid & tready) begin
                out_dword <= out_dword - DW/32;
            end
            if (out_valid) begin
                if (tkeep !== out_tkeep) begin
                    $error("%d keep: %h %h", $time, tkeep, out_tkeep);
                end else begin
                    $display("%d keep: %h %h", $time, tkeep, out_tkeep);
                end
            end
        end
    end
    assign out_tkeep = out_dword >= DW/32 ? {DW/32{1'b1}} : ('d1 << out_dword) - 1'b1;

    reg [15:0] counts;
    always @(posedge clk) begin
        if (~resetn) begin
            counts <= 'd0;
        end else if (out_valid) begin
            counts <= counts + 1'b1;
            if (counts + 1'b1 >= CHECK_COUNT) $finish();
        end
    end

endmodule

module test_tkeep_gen;

    tb_tkeep_gen tb();

endmodule
