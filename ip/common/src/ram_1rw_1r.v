/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module ram_1rw_1r #(
    parameter W = 64,
    parameter WW = 32,
    parameter DL = 4,
    parameter ENW = (W + 31) >> 5
    ) (
    input [DL-1:0]  addr_a,
    input [ENW-1:0] wen_a,
    input [WW-1:0]  wdata_a,
    output [W-1:0]  rdata_a,
    input [DL-1:0]  addr_b,
    output [W-1:0]  rdata_b,
    input           clk,
    input           resetn
    );

    localparam DEPTH = 1 << DL;
    localparam LW = W + 32 - ENW * 32;

    reg [W-1:0] rdata_a_reg;
    reg [W-1:0] rdata_b_reg;

    generate
        for (genvar i=0; i<ENW; i=i+1) begin
            if (i<ENW-1) begin
                reg [31:0] mem[0:DEPTH-1];
                always @(posedge clk) begin
                    if (wen_a[i]) mem[addr_a] <= wdata_a;
                    rdata_a_reg[i*32+:32] <= mem[addr_a];
                    rdata_b_reg[i*32+:32] <= mem[addr_b];
                end
            end else begin
                reg [LW-1:0] mem[0:DEPTH-1];
                always @(posedge clk) begin
                    if (wen_a[i]) mem[addr_a] <= wdata_a[LW-1:0];
                    rdata_a_reg[i*32+:LW] <= mem[addr_a];
                    rdata_b_reg[i*32+:LW] <= mem[addr_b];
                end
            end
        end
    endgenerate

    assign rdata_a = rdata_a_reg;
    assign rdata_b = rdata_b_reg;

endmodule

module ram_1rw_1r_uram #(
    parameter WA = 32,
    parameter W = 64,
    parameter DL = 4,
    parameter ENW = (W + 31) >> 5
    ) (
    input [DL-1:0]  addr_a,
    input [ENW-1:0] wen_a,
    input [WA-1:0]  wdata_a,
    output [W-1:0]  rdata_a,
    input [DL-1:0]  addr_b,
    output [W-1:0]  rdata_b,
    input           clk,
    input           resetn
    );

    localparam DEPTH = 1 << DL;
    localparam LW = W - (32 * ((ENW - 1) & ~1));

    reg [W-1:0] rdata_a_reg;
    reg [W-1:0] rdata_b_reg;

    reg [ENW-1:0] prev_wen_sll1;
    reg [DL-1:0]  prev_waddr;
    reg [31:0]    prev_wdata;
    wire          wen_64;
    always @(posedge clk) begin
       if (~resetn) begin
          prev_wen_sll1 <= 'd0;
          prev_waddr <= 'd0;
          prev_wdata <= 'd0;
       end else if (|wen_a) begin
          if (wen_64) begin
             prev_wen_sll1 <= 'd0;
          end else begin
             prev_wen_sll1 <= wen_a << 1;
             prev_waddr <= addr_a;
             prev_wdata <= wdata_a;
          end
       end
    end
    assign wen_64 = prev_waddr == addr_a && (prev_wen_sll1 & wen_a);

    generate
        for (genvar i=0; i<ENW; i=i+2) begin
            if (i+2<ENW) begin
                wire cur_wen;
                wire [63:0] cur_wdata;
                (* ram_style = "ultra" *) reg [63:0] mem[0:DEPTH-1];
                always @(posedge clk) begin
                    if (cur_wen) mem[addr_a] <= cur_wdata;
                    //rdata_a_reg[i*32+:64] <= mem[addr_a];
                    rdata_b_reg[i*32+:64] <= mem[addr_b];
                end
                assign cur_wen = |wen_a[i+:2];
                assign cur_wdata = wen_a[i] ? {32'd0, wdata_a} :
                                   wen_a[i+1] && wen_64 ? {wdata_a, prev_wdata} : {wdata_a, 32'd0};
            end else if (LW > 32) begin
                wire cur_wen;
                wire [LW-1:0] cur_wdata;
                (* ram_style = "ultra" *) reg [LW-1:0] mem[0:DEPTH-1];
                always @(posedge clk) begin
                    if (cur_wen) mem[addr_a] <= cur_wdata;
                    //rdata_a_reg[i*32+:LW] <= mem[addr_a];
                    rdata_b_reg[i*32+:LW] <= mem[addr_b];
                end
                assign cur_wen = |wen_a[ENW-1:i];
                assign cur_wdata = wen_a[i] ? {32'd0, wdata_a} :
                                   wen_a[ENW-1] && wen_64 ? {wdata_a, prev_wdata} : {wdata_a, 32'd0};
            end else begin
                wire cur_wen;
                wire [LW-1:0] cur_wdata;
                reg [LW-1:0] mem[0:DEPTH-1];
                always @(posedge clk) begin
                    if (cur_wen) mem[addr_a] <= cur_wdata;
                    rdata_a_reg[i*32+:LW] <= mem[addr_a];
                    rdata_b_reg[i*32+:LW] <= mem[addr_b];
                end
                assign cur_wen = |wen_a[ENW-1:i];
                assign cur_wdata = wen_a[i] ? {32'd0, wdata_a} :
                                   wen_a[ENW-1] && wen_64 ? {wdata_a, prev_wdata} : {wdata_a, 32'd0};
            end
        end
    endgenerate

    assign rdata_a = rdata_a_reg;
    assign rdata_b = rdata_b_reg;

endmodule
