/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module axis_buf #(
    parameter DW = 16,
    parameter INVALID_AFTER_LAST = 0,
    parameter DEPTH = 2
    ) (
    input [DW-1:0]  idata,
    input           ilast,
    input           ivalid,
    output          iready,
    output [DW-1:0] odata,
    output          olast,
    output          ovalid,
    input           oready,
    output          ostart_prev,
    input           clk,
    input           resetn
    );

    reg [DW*DEPTH-1:0] r_data;
    reg [DEPTH-1:0]    r_valid;
    reg [DEPTH-1:0]    r_last;
    reg [DEPTH-1:0]    r_start;
    reg                lasted;

    reg                invalid_cycle;
    generate
        always @(posedge clk) begin
            if (~resetn) begin
                invalid_cycle <= 1'b0;
            end else if (INVALID_AFTER_LAST != 0) begin
                invalid_cycle <= ovalid & oready & olast;
            end
        end
    endgenerate

    generate
        for (genvar i=0; i<DEPTH; i=i+1) begin
            always @(posedge clk) begin
                if (~resetn) begin
                    r_data[i*DW+:DW] <= 'd0;
                    r_valid[i] <= 1'b0;
                    r_last[i] <= 1'b0;
                    r_start[i] <= 1'b0;
                end else if (oready & ~invalid_cycle) begin
                    if (i < DEPTH - 1) begin
                        r_data[i*DW+:DW] <= r_valid[i+1] ? r_data[i*DW+DW+:DW] : idata;
                        r_last[i] <= r_valid[i+1] ? r_last[i+1] : ilast;
                        r_valid[i] <= r_valid[i+1] | (~r_valid[i+1] & (r_valid[i] || i==0) & ivalid);
                        r_start[i] <= r_valid[i] & r_last[i];
                    end else begin
                        r_valid[i] <= 1'b0;
                        r_start[i] <= 1'b0;
                    end
                end else begin
                    if (i > 0) begin
                        r_data[i*DW+:DW] <= r_valid[i-1] & ~r_valid[i] ? idata : r_data[i*DW+:DW];
                        r_last[i] <= r_valid[i-1] & ~r_valid[i] ? ilast : r_last[i];
                        r_valid[i] <= (r_valid[i-1] & ivalid) | r_valid[i];
                        r_start[i] <= r_valid[i-1] & r_last[i-1];
                    end else if (!r_valid[i]) begin
                        r_data[i*DW+:DW] <= idata;
                        r_last[i] <= ilast;
                        r_valid[i] <= ivalid;
                    end
                end
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (~resetn) begin
            lasted <= 1'b1;
        end else begin
            lasted <= (lasted & ~(ovalid & oready)) | (ovalid & oready & olast);
        end
    end

    assign ostart_prev = (r_start[0] & r_valid[0] & ~oready) | (r_start[1] & r_valid[1] & oready & ~invalid_cycle) |
                         (~r_valid[0] & ivalid & lasted) | (r_valid[0] & ~oready & lasted) |
                         ((r_valid[1] | ivalid) & r_valid[0] & r_last[0] & oready & ~invalid_cycle);
    assign iready = ~r_valid[DEPTH-1];
    assign odata = r_data[DW-1:0];
    assign olast = r_last[0];
    assign ovalid = r_valid[0] & ~invalid_cycle;

endmodule
