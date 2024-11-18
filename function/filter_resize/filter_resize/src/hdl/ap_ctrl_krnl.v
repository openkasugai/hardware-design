/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1 ns / 1 ps 
module ap_ctrl_krnl (
        ap_clk,
        ap_rst_n,
        ap_start,
        ap_start_data_in,
        ap_start_filter_proc,
        ap_start_resize_proc,
        ap_start_data_out,
        ap_done_data_in,
        ap_done_filter_proc,
        ap_done_resize_proc,
        ap_done_data_out,
        ap_ready_data_in,
        ap_ready_filter_proc,
        ap_ready_resize_proc,
        ap_ready_data_out
);

input   ap_clk;
input   ap_rst_n;
input   ap_start;
output  ap_start_data_in;
output  ap_start_filter_proc;
output  ap_start_resize_proc;
output  ap_start_data_out;
input   ap_done_data_in;
input   ap_done_filter_proc;
input   ap_done_resize_proc;
input   ap_done_data_out;
input   ap_ready_data_in;
input   ap_ready_filter_proc;
input   ap_ready_resize_proc;
input   ap_ready_data_out;

reg     ap_start_latch_data_in;
reg     ap_start_latch_filter_proc;
reg     ap_start_latch_resize_proc;
reg     ap_start_latch_data_out;


always @(posedge ap_clk) begin
    if (!ap_rst_n) begin
        ap_start_latch_data_in <= 1'b0;
    end else if (ap_start | ap_done_data_in) begin
        ap_start_latch_data_in <= 1'b1;
    end else if (ap_ready_data_in) begin
        ap_start_latch_data_in <= 1'b0;
    end
end
assign ap_start_data_in = ap_start_latch_data_in;

always @(posedge ap_clk) begin
    if (!ap_rst_n) begin
        ap_start_latch_filter_proc <= 1'b0;
    end else if (ap_start | ap_done_filter_proc) begin
        ap_start_latch_filter_proc <= 1'b1;
    end else if (ap_ready_filter_proc) begin
        ap_start_latch_filter_proc <= 1'b0;
    end
end
assign ap_start_filter_proc = ap_start_latch_filter_proc;

always @(posedge ap_clk) begin
    if (!ap_rst_n) begin
        ap_start_latch_resize_proc <= 1'b0;
    end else if (ap_start | ap_done_resize_proc) begin
        ap_start_latch_resize_proc <= 1'b1;
    end else if (ap_ready_resize_proc) begin
        ap_start_latch_resize_proc <= 1'b0;
    end
end
assign ap_start_resize_proc = ap_start_latch_resize_proc;

always @(posedge ap_clk) begin
    if (!ap_rst_n) begin
        ap_start_latch_data_out <= 1'b0;
    end else if (ap_start | ap_done_data_out) begin
        ap_start_latch_data_out <= 1'b1;
    end else if (ap_ready_data_out) begin
        ap_start_latch_data_out <= 1'b0;
    end
end
assign ap_start_data_out = ap_start_latch_data_out;

endmodule //ap_ctrl_krnl

`default_nettype wire

