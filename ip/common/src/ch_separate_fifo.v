/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module ch_separate_fifo #(
    parameter CH_NUM_LOG = 3,
    parameter DW = 32,
    parameter DL = 2
    ) (
    input [DW-1:0]                      idata,
    input [CH_NUM_LOG-1:0]              ich,
    input                               ivalid,
    output reg                          iready,

    output reg [DW*(1<<CH_NUM_LOG)-1:0] odata,
    output reg [(1<<CH_NUM_LOG)-1:0]    ovalid,
    input [(1<<CH_NUM_LOG)-1:0]         oready,

    output [(1<<CH_NUM_LOG)-1:0]        full,

    input                               clk,
    input                               resetn
    );

    localparam DEPTH = 1 << DL;
    localparam CH_NUM = 1 << CH_NUM_LOG;
    localparam WPC = DW * DEPTH; // width / channel
    localparam DLp1 = DL + 1;
    localparam MDL = DL + CH_NUM_LOG;

    localparam MDEPTH = DEPTH * CH_NUM;

    reg [DW-1:0]                    mem[0:MDEPTH-1];
    reg [DLp1*CH_NUM-1:0]           wptrs;
    reg [DLp1*CH_NUM-1:0]           rptrs;
    reg [CH_NUM-1:0]                mvalids;
    wire [CH_NUM-1:0]               mreadys;
    wire [CH_NUM-1:0]               ireadys;
    wire [DLp1*CH_NUM-1:0]          wptr_nexts;
    wire [DLp1*CH_NUM-1:0]          rptr_nexts;

    wire [MDL-1:0]                   wptr;
    wire [DL-1:0]                    wptr_ch;
    wire [MDL-1:0]                   rptr;
    reg [DW-1:0]                     mdata;
    assign wptr_ch = wptrs >> (ich * DLp1);
    assign wptr = {ich, wptr_ch};

    always @(posedge clk) begin
        if (ivalid & iready) begin
            mem[wptr] <= idata;
        end
        mdata <= mem[rptr];
    end
    always @(posedge clk) begin
        if (~resetn) begin
            iready <= 1'b0;
        end else begin
            iready <= &ireadys;
        end
    end
    generate
        for (genvar i=0; i<CH_NUM; i=i+1) begin
            always @(posedge clk) begin
                if (~resetn) begin
                    wptrs[i*DLp1+:DLp1] <= 'd0;
                    rptrs[i*DLp1+:DLp1] <= 'd0;
                    mvalids[i] <= 1'b0;
                end else begin
                    wptrs[i*DLp1+:DLp1] <= wptr_nexts[i*DLp1+:DLp1];
                    rptrs[i*DLp1+:DLp1] <= rptr_nexts[i*DLp1+:DLp1];
                    mvalids[i] <= wptr_nexts[i*DLp1+:DLp1] != rptr_nexts[i*DLp1+:DLp1];
                end
            end
            assign wptr_nexts[i*DLp1+:DLp1] =  wptrs[i*DLp1+:DLp1] + (ivalid && iready && ich == i);
            assign rptr_nexts[i*DLp1+:DLp1] =  rptrs[i*DLp1+:DLp1] + (mvalids[i] & mreadys[i]);
            assign ireadys[i] = (wptr_nexts[i*DLp1+DL] == rptr_nexts[i*DLp1+DL]) || (wptr_nexts[i*DLp1+:DL] != rptr_nexts[i*DLp1+:DL]);
            assign full[i] = ~ireadys[i];
        end
    endgenerate

    wire                  mready;
    wire [CH_NUM_LOG-1:0] mch_candidate;
    wire                  mch_candidate_valid;

    ch_candidate #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .RR ( 0 )
    ) ch_select (
        .ch_valids ( mvalids ),
        .update ( 1'b1 ),
        .candidate ( mch_candidate ),
        .candidate_valid ( mch_candidate_valid ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    wire [DL-1:0]         rptr_ch = rptrs >> (mch_candidate * DLp1);
    assign rptr = {mch_candidate, rptr_ch};
    reg [CH_NUM_LOG-1:0]  read_ch;
    reg                   read_ch_valid;
    always @(posedge clk) begin
        if (~resetn) begin
            read_ch <= 'd0;
            read_ch_valid <= 1'b0;
        end else begin
            read_ch <= mch_candidate;
            read_ch_valid <= mready;
        end
    end

    assign mready = mch_candidate_valid & ~(ovalid >> mch_candidate) & ~read_ch_valid;
    assign mreadys = ({{CH_NUM-1{1'b0}}, mch_candidate_valid & ~read_ch_valid} << mch_candidate) & ~ovalid;

    generate
        for (genvar i=0; i<CH_NUM; i=i+1) begin
            always @(posedge clk) begin
                if (~resetn) begin
                    ovalid[i] <= 1'b0;
                    odata[i*DW+:DW] <= 'd0;
                end else if (read_ch_valid && read_ch == i) begin
                    ovalid[i] <= read_ch_valid;
                    odata[i*DW+:DW] <= mdata;
                end else if (oready[i]) begin
                    ovalid[i] <= 1'b0;
                end
            end
        end
    endgenerate

endmodule
