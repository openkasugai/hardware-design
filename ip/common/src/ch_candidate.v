/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module ch_candidate #(
    parameter CH_NUM_LOG = 3,
    parameter RR = 0
    ) (
    input [(1<<CH_NUM_LOG)-1:0] ch_valids,
    input                       update,
    output [CH_NUM_LOG-1:0]     candidate,
    output                      candidate_valid,
    input                       clk,
    input                       resetn
    );

    localparam CH_NUM = 1 << CH_NUM_LOG;

    reg [CH_NUM_LOG-1:0] check_ch_next;
    reg                  check_ch_next_valid;

    wire                 cur_update = ~(ch_valids >> check_ch_next);
    wire                 cur_valid = (ch_valids >> check_ch_next);
    wire [CH_NUM_LOG-1:0] check_ch_next_candidate;
    wire                 check_ch_next_valid_candidate;

    generate
        if (RR) begin
            always @(posedge clk) begin
                if (~resetn) begin
                    check_ch_next <= 'd0;
                    check_ch_next_valid <= 1'b0;
                end else if (cur_update || update) begin
                    check_ch_next <= check_ch_next_candidate;
                    check_ch_next_valid <= check_ch_next_valid_candidate;
                end
            end
        end else begin
            always @(posedge clk) begin
                if (~resetn) begin
                    check_ch_next <= 'd0;
                    check_ch_next_valid <= 1'b0;
                end else if (cur_valid && ~check_ch_next_valid) begin
                    check_ch_next_valid <= cur_valid;
                end else if (cur_update || update) begin
                    check_ch_next <= check_ch_next_candidate;
                    check_ch_next_valid <= check_ch_next_valid_candidate;
                end
            end
        end
    endgenerate

    wire [CH_NUM-1:0] check_ch_selections = {ch_valids, ch_valids} >> check_ch_next;
    assign check_ch_next_candidate = check_ch_selections[1] ? check_ch_next + 1'd1 :
                                     check_ch_selections[2] ? check_ch_next + 2'd2 :
                                     check_ch_selections[3] ? check_ch_next + 2'd3 : check_ch_next + 3'd4;
    assign check_ch_next_valid_candidate = |check_ch_selections[4:1];

    assign candidate = check_ch_next;
    assign candidate_valid = check_ch_next_valid;

endmodule
