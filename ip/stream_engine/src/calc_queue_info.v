/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module calc_queue_info #(
    parameter CH_NUM_LOG = 3,
    parameter QEW_LOG = 5
    ) (
    input [CH_NUM_LOG-1:0]         update_ch,
    input                          update_ch_valid,
    input [(1<<CH_NUM_LOG)*64-1:0] addr_bases,
    input [(1<<CH_NUM_LOG)*8-1:0]  q_depth,
    input [(1<<CH_NUM_LOG)*8-1:0]  q_pos,
    output                         out_valid,
    output reg [63:0]              addr_out,
    output reg                     addr_carry32,
    output reg [7:0]               q_pos_out,
    output reg [CH_NUM_LOG-1:0]    q_ch_out,
    input                          clk,
    input                          resetn
    );

    wire [63:0] w_q_base = addr_bases >> {update_ch, 6'd0};
    wire [7:0]  w_q_depth = q_depth >> {update_ch, 3'd0};
    wire [7:0]  w_q_pos = q_pos >> {update_ch, 3'd0};

    reg [7:0]           cur_depth;
    reg [1:0]           stages;

    always @(posedge clk) begin
        if (~resetn) begin
            stages <= 'd0;
            addr_out <= 'd0;
            q_pos_out <= 'd0;
            cur_depth <= 'd0;
            addr_carry32 <= 1'b0;
            q_ch_out <= 'd0;
        end else if (stages[0]) begin
            if (q_pos_out + 1'b1 < cur_depth) begin
                q_pos_out <= q_pos_out + 1'b1;
                {addr_carry32, addr_out[31:0]} <= {1'b0, addr_out[31:0]} + {q_pos_out + 1'b1, {QEW_LOG{1'b0}}};
            end else begin
                q_pos_out <= 'd0;
                addr_carry32 <= 1'b0;
            end
            stages <= 'd2;
        end else if (update_ch_valid) begin
            stages <= 'd1;
            addr_out <= w_q_base;
            cur_depth <= w_q_depth;
            q_pos_out <= w_q_pos;
            q_ch_out <= update_ch;
        end else begin
            stages <= 'd0;
        end
    end
    assign out_valid = stages[1];

endmodule
