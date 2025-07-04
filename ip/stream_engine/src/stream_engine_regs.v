/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module stream_engine_regs #(
    parameter [15:0] REG_BASE = 16'h4000,
    parameter        QEW_LOG = 5,
    parameter        VP_MAP_NUM_LOG = 5,
    parameter        CH_NUM_LOG = 3,
    parameter        ENABLE_QUEUE = 0,
    parameter [39:0] D2D_AXI_BASE = 40'h0,
    parameter [31:0] D2D_AXI_RANGE = 32'h4000_0000, // 1GB
    parameter        QUEUE_DL = 3,
    parameter        USE_ULTRA_RAM_VPMAP = 1
    ) (
    input [15:0]                          reg_araddr,
    input                                 reg_arvalid,
    output                                reg_arready,
    output [31:0]                         reg_rdata,
    output [1:0]                          reg_rresp,
    output                                reg_rvalid,
    input                                 reg_rready,
    input [15:0]                          reg_awaddr,
    input                                 reg_awvalid,
    output                                reg_awready,
    input [31:0]                          reg_wdata,
    input                                 reg_wvalid,
    output                                reg_wready,
    output [1:0]                          reg_bresp,
    output                                reg_bvalid,
    input                                 reg_bready,

    input [VP_MAP_NUM_LOG+CH_NUM_LOG-1:0] vpmap_conv_addr,
    output [64+64+32:0]                   vpmap_conv_rdata,

    output reg [(1<<CH_NUM_LOG)-1:0]      stream_ch_valids,
    input [(1<<CH_NUM_LOG)-1:0]           stream_ch_initialized,
    output reg [(1<<CH_NUM_LOG)-1:0]      stream_ch_pendings,
    output reg [(1<<CH_NUM_LOG)*64-1:0]   stream_req_q_bases,
    output reg [(1<<CH_NUM_LOG)*64-1:0]   stream_cpl_q_bases,
    output reg [(1<<CH_NUM_LOG)*8-1:0]    stream_req_q_depth,
    output reg [(1<<CH_NUM_LOG)*8-1:0]    stream_cpl_q_depth,
    output reg [(1<<CH_NUM_LOG)*64-1:0]   stream_req_q_head_tails,
    output reg [(1<<CH_NUM_LOG)*64-1:0]   stream_cpl_q_head_tails,

    input [CH_NUM_LOG-1:0]                stream_check_ch,
    input                                 stream_check_done,
    output reg [(64<<CH_NUM_LOG)-1:0]     stream_doorbell_addrs,
    output reg [(1<<CH_NUM_LOG)-1:0]      stream_check_requests,
    output reg [(1<<CH_NUM_LOG)-1:0]      stream_ch_check_with_doorbells,
    output reg [(1<<CH_NUM_LOG)-1:0]      stream_ch_interrupt_enables,
    output reg [(1<<CH_NUM_LOG)-1:0]      stream_ch_d2d_valids,

    output reg [15:0]                     stream_check_interval,
    output reg [CH_NUM_LOG:0]             stream_ch_valid_num,
    output reg [CH_NUM_LOG:0]             stream_ch_doorbell_num,

    input [CH_NUM_LOG-1:0]                stream_req_update_ch, // head update
    input [31:0]                          stream_req_update_size,
    input                                 stream_req_update,
    input [CH_NUM_LOG-1:0]                stream_cpl_update_ch, // tail update
    input                                 stream_cpl_update,
    input [CH_NUM_LOG-1:0]                stream_queue_read_ch,
    input [QUEUE_DL-1:0]                  stream_queue_read_entry,
    input                                 stream_queue_read_valid,
    output [(8<<QEW_LOG)-1:0]             stream_queue_read_data,
    output                                stream_queue_read_data_valid,

    output [(8<<CH_NUM_LOG)-1:0]          stream_req_q_heads,
    output [(8<<CH_NUM_LOG)-1:0]          stream_req_q_tails,
    output [(8<<CH_NUM_LOG)-1:0]          stream_cpl_q_heads,
    output [(8<<CH_NUM_LOG)-1:0]          stream_cpl_q_tails,

    output [3:0]                          ctrl_reg_waddr,
    output [31:0]                         ctrl_reg_wdata,
    output [CH_NUM_LOG-1:0]               ctrl_reg_wch,
    output                                ctrl_reg_wen,

    output [(1<<CH_NUM_LOG)-1:0]          head_tail_updates, // pulse

    // debug
    input [31:0]                          i_rc_icount,
    input [31:0]                          i_rc_count,

    input [(1<<CH_NUM_LOG)-1:0]           desc_issues,
    input [(1<<CH_NUM_LOG)-1:0]           desc_completes,

    input [8*(1<<CH_NUM_LOG)-1:0]         req_q_head,
    input [8*(1<<CH_NUM_LOG)-1:0]         req_q_read_pos,
    input [8*(1<<CH_NUM_LOG)-1:0]         req_q_tail,
    input [8*(1<<CH_NUM_LOG)-1:0]         cpl_q_head,
    input [8*(1<<CH_NUM_LOG)-1:0]         cpl_q_head_inflight,
    input [8*(1<<CH_NUM_LOG)-1:0]         cpl_q_tail,
    input [8*(1<<CH_NUM_LOG)-1:0]         cpl_counts,
    input [8*(1<<CH_NUM_LOG)-1:0]         cpl_counts2,
    input [(1<<CH_NUM_LOG)-1:0]           dbg_transfer_valids,
    input [(1<<CH_NUM_LOG)-1:0]           dbg_transfer_issue_ends,
    input [(1<<CH_NUM_LOG)-1:0]           dbg_transfer_ends,
    input [(1<<CH_NUM_LOG)-1:0]           transfer_cpl_ch_cand,

    input                                 clk,
    input                                 resetn
    );

    localparam STATUS_VALID = 1;
    localparam STATUS_CLOSED = 5;

    localparam QEW = 1 << QEW_LOG;
    localparam QEWB = QEW * 8;
    localparam VPMAP_CH_AGGREGATE = CH_NUM_LOG + VP_MAP_NUM_LOG + 2 + 3 > 15 ? 1 : 0;
    localparam CH_NUM = 1 << CH_NUM_LOG;
    localparam VP_MAP_NUM = 1 << VP_MAP_NUM_LOG;
    localparam VPMAP_MAX = VPMAP_CH_AGGREGATE ? 4 << (VP_MAP_NUM_LOG + 3) : 4 << (CH_NUM_LOG + VP_MAP_NUM_LOG + 3);
    localparam CTRL_MAX = VPMAP_MAX + (4 << (CH_NUM_LOG + 4));
    localparam CTRL_END = CTRL_MAX + 4 * 4;
    localparam QUEUE_DEPTH = 1 << QUEUE_DL;
    localparam QUEUE_BASE = (CTRL_END + 63) & ~63;
    localparam QUEUE_HEAD_TAIL = QUEUE_BASE + QEW * CH_NUM * QUEUE_DEPTH * 2; // (QEW * QUEUE_DEPTH) x ch_num x(req,cpl)
    localparam QUEUE_END = QUEUE_HEAD_TAIL + 4 * 2 * CH_NUM * 2; // 4B x(head, tail) x ch_num x(req, cpl)

    localparam [31:0] STREAM_ENGINE_IDENTIFIER = 32'h6e457453; // StEn
    localparam [7:0] VP_MAP_NUM_LOG_8B = VP_MAP_NUM_LOG;
    localparam [7:0] CH_NUM_LOG_8B = CH_NUM_LOG;

    reg [3:0]                 axi_rstat; // 0: capture address, 1: read sram, 2: capture sram, 3: merge rdata & output
    reg [2:0]                 axi_wstat; // 0: capture address, 1: capture data, 2: response output
    reg [15:0]                axi_read_addr;
    reg [31:0]                axi_read_data;
    reg [15:0]                axi_write_addr;
    reg [31:0]                axi_write_data;
    reg                       axi_write_valid;
    reg                       axi_vpmap_write;
    reg                       axi_vpmap_read;
    reg                       axi_ctrl_write;
    reg                       axi_ctrl_read;
    reg                       axi_queue_write;
    reg                       axi_queue_read;
    always @(posedge clk) begin
        if (~resetn) begin
            axi_rstat <= 4'd0;
            axi_wstat <= 3'd0;
            axi_read_addr <= 16'd0;
            axi_write_addr <= 16'd0;
            axi_write_data <= 32'd0;
            axi_write_valid <= 1'b0;
            axi_vpmap_write <= 1'b0;
            axi_vpmap_read <= 1'b0;
            axi_ctrl_write <= 1'b0;
            axi_ctrl_read <= 1'b0;
            axi_queue_write <= 1'b0;
            axi_queue_read <= 1'b0;
        end else begin
            if (reg_rvalid & reg_rready) begin
                axi_rstat <= 4'd0;
            end else begin
                axi_rstat[0] <= reg_arvalid & reg_arready ? 1'b1 : axi_rstat[0];
                axi_rstat[3:1] <= axi_rstat[2:0];
                axi_read_addr <= reg_arvalid & reg_arready ? reg_araddr - REG_BASE : axi_read_addr;
                if (axi_rstat[0]) begin
                    axi_vpmap_read <= axi_read_addr < VPMAP_MAX;
                    axi_ctrl_read <= (axi_read_addr >= VPMAP_MAX) && (axi_read_addr < CTRL_MAX);
                    axi_queue_read <= (axi_read_addr >= QUEUE_BASE) && (axi_read_addr < QUEUE_END);
                end
            end
            if (reg_bvalid & reg_bready) begin
                axi_wstat <= 3'd0;
                axi_write_valid <= 1'b0;
            end else begin
                axi_wstat[0] <= reg_awvalid & reg_awready ? 1'b1 : axi_wstat[0];
                axi_wstat[1] <= reg_wvalid & reg_wready ? 1'b1 : axi_wstat[1];
                axi_wstat[2] <= axi_wstat[0] & axi_wstat[1];
                axi_write_valid <= ~axi_wstat[2] && &axi_wstat[1:0];
                axi_write_addr <= reg_awvalid & reg_awready ? reg_awaddr - REG_BASE : axi_write_addr;
                axi_write_data <= reg_wvalid & reg_wready ? reg_wdata : axi_write_data;
                axi_vpmap_write <= ~axi_wstat[2] && &axi_wstat[1:0] && (axi_write_addr < VPMAP_MAX);
                axi_ctrl_write <= ~axi_wstat[2] && &axi_wstat[1:0] &&
                                  (axi_write_addr >= VPMAP_MAX) && (axi_write_addr < CTRL_MAX);
                axi_queue_write <= ~axi_wstat[2] && &axi_wstat[1:0] &&
                                   (axi_write_addr >= QUEUE_BASE) && (axi_write_addr < QUEUE_END);
            end
        end
    end
    assign reg_arready = ~axi_rstat[0];
    assign reg_rdata = axi_read_data;
    assign reg_rresp = 2'd0;
    assign reg_rvalid = axi_rstat[3];
    assign reg_awready = ~axi_wstat[0];
    assign reg_wready = ~axi_wstat[1];
    assign reg_bresp = 2'd0;
    assign reg_bvalid = axi_wstat[2];

    wire [VP_MAP_NUM_LOG+CH_NUM_LOG-1:0] vpmap_reg_addr;
    wire [31:0]                          vpmap_reg_wdata;
    wire [5:0]                           vpmap_reg_wen;
    wire [64+64+32:0]                    vpmap_reg_rdata;
    reg [CH_NUM_LOG-1:0]                 vpmap_acc_ch;

    generate
       if (VPMAP_CH_AGGREGATE) begin
           assign vpmap_reg_addr = {vpmap_acc_ch, (axi_write_valid ? axi_write_addr[5+:VP_MAP_NUM_LOG] : axi_read_addr[5+:VP_MAP_NUM_LOG])};
           if (USE_ULTRA_RAM_VPMAP > 0) begin
               ram_1rw_1r_uram #(
                   .W ( 52 + 52 + 20 + 1 ),
                   .DL ( VP_MAP_NUM_LOG + CH_NUM_LOG )
               ) vp_map (
                   .addr_a ( vpmap_reg_addr ),
                   .wen_a ( vpmap_reg_wen[3:0] ),
                   .wdata_a ( vpmap_reg_wdata ),
                   .rdata_a ( vpmap_reg_rdata ),
                   .addr_b ( vpmap_conv_addr ),
                   .rdata_b ( {vpmap_conv_rdata[160], vpmap_conv_rdata[159:140], vpmap_conv_rdata[127:76], vpmap_conv_rdata[63:12]} ),
                   .clk ( clk ),
                   .resetn ( resetn )
               );
           end else begin
               ram_1rw_1r #(
                   .W ( 52 + 52 + 20 + 1 ),
                   .DL ( VP_MAP_NUM_LOG + CH_NUM_LOG )
               ) vp_map (
                   .addr_a ( vpmap_reg_addr ),
                   .wen_a ( vpmap_reg_wen[3:0] ),
                   .wdata_a ( vpmap_reg_wdata ),
                   .rdata_a ( vpmap_reg_rdata ),
                   .addr_b ( vpmap_conv_addr ),
                   .rdata_b ( {vpmap_conv_rdata[160], vpmap_conv_rdata[159:140], vpmap_conv_rdata[127:76], vpmap_conv_rdata[63:12]} ),
                   .clk ( clk ),
                   .resetn ( resetn )
               );
           end
           assign vpmap_conv_rdata[11:0] = 12'd0;
           assign vpmap_conv_rdata[75:64] = 12'd0;
           assign vpmap_conv_rdata[139:128] = 12'd0;
       end else begin
           assign vpmap_reg_addr = (axi_write_valid ? axi_write_addr : axi_read_addr) >> 5;
           ram_1rw_1r #(
               .W ( 64 + 64 + 32 + 1 ),
               .DL ( VP_MAP_NUM_LOG + CH_NUM_LOG )
           ) vp_map (
               .addr_a ( vpmap_reg_addr ),
               .wen_a ( vpmap_reg_wen ),
               .wdata_a ( vpmap_reg_wdata ),
               .rdata_a ( vpmap_reg_rdata ),
               .addr_b ( vpmap_conv_addr ),
               .rdata_b ( vpmap_conv_rdata ),
               .clk ( clk ),
               .resetn ( resetn )
           );
       end
    endgenerate

    assign vpmap_reg_wen = axi_write_valid & axi_vpmap_write ? 6'd1 << ((axi_write_addr >> 2) & 3'd7) : 6'd0;
    assign vpmap_reg_wdata = axi_write_data;

    assign ctrl_reg_waddr = axi_write_addr[2+:4];
    assign ctrl_reg_wch = axi_write_addr[6+:CH_NUM_LOG];
    assign ctrl_reg_wen = axi_write_valid && axi_ctrl_write;
    assign ctrl_reg_wdata = axi_write_data;

    wire [3:0]                  ctrl_reg_raddr = axi_read_addr[2+:4];
    wire [CH_NUM_LOG-1:0]       ctrl_reg_rch = axi_read_addr[6+:CH_NUM_LOG];

    wire                        cur_stream_ch_valid = stream_ch_valids >> ctrl_reg_wch;
    wire                        cur_stream_ch_d2d_valid = stream_ch_d2d_valids >> ctrl_reg_wch;
    wire                        cur_doorbell_ch_valid = stream_ch_check_with_doorbells >> ctrl_reg_wch;
    wire stream_ch_valid_num_plus = ctrl_reg_wen && ctrl_reg_waddr[3:0] == 4'h0 &&
         axi_write_data[0] && (~axi_write_data[4] || ENABLE_QUEUE==0) && (~cur_stream_ch_valid || cur_stream_ch_d2d_valid);
    wire stream_ch_valid_num_minus = ctrl_reg_wen && ctrl_reg_waddr[3:0] == 4'h0 &&
         (~axi_write_data[0] || (axi_write_data[4] && ENABLE_QUEUE > 0)) && (cur_stream_ch_valid && ~cur_stream_ch_d2d_valid);
    wire w_ch_doorbell_num_plus = (stream_ch_valid_num_plus && cur_doorbell_ch_valid) ||
         (ctrl_reg_wen && ctrl_reg_waddr[3:0] == 4'he && axi_write_data[4] &&
          cur_stream_ch_valid && (~cur_stream_ch_d2d_valid || ENABLE_QUEUE==0) && ~cur_doorbell_ch_valid);
    wire w_ch_doorbell_num_minus = (stream_ch_valid_num_minus && cur_doorbell_ch_valid) ||
         (ctrl_reg_wen && ctrl_reg_waddr[3:0] == 4'he && ~axi_write_data[4] &&
          cur_stream_ch_valid && (~cur_stream_ch_d2d_valid || ENABLE_QUEUE==0) && cur_doorbell_ch_valid);
    reg  rccount_switch;
    always @(posedge clk) begin
        if (~resetn) begin
            stream_check_interval <= 16'd0;
            stream_ch_valid_num <= 'd0;
            stream_ch_doorbell_num <= 'd0;
            rccount_switch <= 1'b0;
        end else begin
            if (axi_write_valid && axi_write_addr == CTRL_MAX) begin
                stream_check_interval <= ctrl_reg_wdata[15:0];
                rccount_switch <= ctrl_reg_wdata[16];
            end else if (axi_write_valid && axi_write_addr == CTRL_MAX + 4'd8) begin
                vpmap_acc_ch <= ctrl_reg_wdata[CH_NUM_LOG-1:0];
            end
            stream_ch_valid_num <= stream_ch_valid_num + stream_ch_valid_num_plus - stream_ch_valid_num_minus;
            stream_ch_doorbell_num <= stream_ch_doorbell_num + w_ch_doorbell_num_plus - w_ch_doorbell_num_minus;
        end
    end

    reg [CH_NUM*16-1:0] stream_issue_counts;
    reg [CH_NUM*16-1:0] stream_complete_counts;
    generate
        for (genvar i=0; i<CH_NUM; i=i+1) begin
            always @(posedge clk) begin
                if (~resetn) begin
                    stream_ch_valids[i] <= 1'b0;
                    stream_ch_pendings[i] <= 1'b0;
                    stream_req_q_bases[i*64+:64] <= 64'h0;
                    stream_cpl_q_bases[i*64+:64] <= 64'h0;
                    stream_req_q_head_tails[i*64+:64] <= 64'h0;
                    stream_cpl_q_head_tails[i*64+:64] <= 64'h0;
                    stream_req_q_depth[i*8+:8] <= 8'd0;
                    stream_cpl_q_depth[i*8+:8] <= 8'd0;
                    stream_doorbell_addrs[i*64+:64] <= 64'd0;
                    stream_check_requests[i] <= 1'b0;
                    stream_ch_check_with_doorbells[i] <= 1'b0;
                    stream_ch_interrupt_enables[i] <= 1'b0;
                    stream_ch_d2d_valids[i] <= 1'b0;
                end else if (ctrl_reg_wen && ctrl_reg_wch == i) begin
                    case (ctrl_reg_waddr)
                        4'h0 : begin
                           stream_ch_valids[i] <= ctrl_reg_wdata[0];
                           stream_ch_d2d_valids[i] <= ctrl_reg_wdata[4];
                        end
                        4'h1 : ;//stream_ch_pendings[i] <= ctrl_reg_wdata[0];
                        4'h2 : stream_req_q_bases[i*64+:32] <= ctrl_reg_wdata;
                        4'h3 : stream_req_q_bases[i*64+32+:32] <= ctrl_reg_wdata;
                        4'h4 : stream_cpl_q_bases[i*64+:32] <= ctrl_reg_wdata;
                        4'h5 : stream_cpl_q_bases[i*64+32+:32] <= ctrl_reg_wdata;
                        4'h6 : stream_req_q_head_tails[i*64+:32] <= ctrl_reg_wdata;
                        4'h7 : stream_req_q_head_tails[i*64+32+:32] <= ctrl_reg_wdata;
                        4'h8 : stream_cpl_q_head_tails[i*64+:32] <= ctrl_reg_wdata;
                        4'h9 : stream_cpl_q_head_tails[i*64+32+:32] <= ctrl_reg_wdata;
                        4'ha : {stream_cpl_q_depth[i*8+:8], stream_req_q_depth[i*8+:8]} <= ctrl_reg_wdata[15:0];
                        4'hb : ;
                        4'hc : stream_doorbell_addrs[i*64+:32] <= ctrl_reg_wdata;
                        4'hd : stream_doorbell_addrs[i*64+32+:32] <= ctrl_reg_wdata;
                        4'he : {stream_ch_check_with_doorbells[i], stream_ch_interrupt_enables[i]} <= {ctrl_reg_wdata[4], ctrl_reg_wdata[0]};
                        4'hf : stream_check_requests[i] <= stream_ch_check_with_doorbells[i]; // doorbell
                    endcase
                end else begin
                   stream_check_requests[i] <= stream_check_requests[i] && ~(stream_check_done && stream_check_ch == i);
                end
            end
            always @(posedge clk) begin
                if (~resetn) begin
                    stream_issue_counts[i*16+:16] <= 16'd0;
                    stream_complete_counts[i*16+:16] <= 16'd0;
                end else begin
                    stream_issue_counts[i*16+:16] <= stream_issue_counts[i*16+:16] + desc_issues[i];
                    stream_complete_counts[i*16+:16] <= stream_complete_counts[i*16+:16] + desc_completes[i];
                end
            end
        end
    endgenerate

    wire rd_stream_ch_valid = stream_ch_valids >> ctrl_reg_rch;
    wire rd_stream_ch_d2d_valid = stream_ch_d2d_valids >> ctrl_reg_rch;
    wire rd_stream_ch_initialized = stream_ch_initialized >> ctrl_reg_rch;
    wire rd_stream_ch_pending = stream_ch_pendings >> ctrl_reg_rch;
    wire [63:0] rd_stream_ch_req_q_base = stream_req_q_bases >> {ctrl_reg_rch, 6'd0};
    wire [63:0] rd_stream_ch_cpl_q_base = stream_cpl_q_bases >> {ctrl_reg_rch, 6'd0};
    wire [63:0] rd_stream_ch_req_head_tail = stream_req_q_head_tails >> {ctrl_reg_rch, 6'd0};
    wire [63:0] rd_stream_ch_cpl_head_tail = stream_cpl_q_head_tails >> {ctrl_reg_rch, 6'd0};
    wire [7:0] rd_stream_ch_req_q_depth = stream_req_q_depth >> {ctrl_reg_rch, 3'd0};
    wire [7:0] rd_stream_ch_cpl_q_depth = stream_cpl_q_depth >> {ctrl_reg_rch, 3'd0};
    wire [15:0] rd_stream_issues = stream_issue_counts >> {ctrl_reg_rch, 4'd0};
    wire [15:0] rd_stream_completes = stream_complete_counts >> {ctrl_reg_rch, 4'd0};
    wire [3:0]  rd_req_q_head = req_q_head >> {ctrl_reg_rch, 3'd0};
    wire [3:0]  rd_req_q_read_pos = req_q_read_pos >> {ctrl_reg_rch, 3'd0};
    wire [3:0]  rd_req_q_tail = req_q_tail >> {ctrl_reg_rch, 3'd0};
    wire [3:0]  rd_cpl_q_head = cpl_q_head >> {ctrl_reg_rch, 3'd0};
    wire [3:0]  rd_cpl_q_head_inflight = cpl_q_head_inflight >> {ctrl_reg_rch, 3'd0};
    wire [3:0]  rd_cpl_q_tail = cpl_q_tail >> {ctrl_reg_rch, 3'd0};
    wire [7:0]  rd_cpl_count = cpl_counts >> {ctrl_reg_rch, 3'd0};
    wire [7:0]  rd_cpl_count2 = cpl_counts2 >> {ctrl_reg_rch, 3'd0};
    wire        rd_transfer_valid = dbg_transfer_valids >> ctrl_reg_rch;
    wire        rd_transfer_issue_end = dbg_transfer_issue_ends >> ctrl_reg_rch;
    wire        rd_transfer_end = dbg_transfer_ends >> ctrl_reg_rch;
    wire        rd_transfer_cpl_ch_cand = transfer_cpl_ch_cand >> ctrl_reg_rch;
    wire [63:0] rd_doorbell_addr = stream_doorbell_addrs >> {ctrl_reg_rch, 6'd0};
    wire        rd_check_request = stream_check_requests >> ctrl_reg_rch;
    wire        rd_ch_check_with_doorbell = stream_ch_check_with_doorbells >> ctrl_reg_rch;
    wire        rd_ch_interrupt = stream_ch_interrupt_enables >> ctrl_reg_rch;

    wire [31:0] rd_stream_rdata =
                ctrl_reg_raddr == 4'h0 ? {rd_cpl_count2, 3'd0, rd_transfer_cpl_ch_cand,
                                          1'd0, rd_transfer_end, rd_transfer_issue_end, rd_transfer_valid,
                                          7'd0, rd_stream_ch_initialized, 3'd0, rd_stream_ch_d2d_valid, 3'd0, rd_stream_ch_valid} :
                ctrl_reg_raddr == 4'h1 ? {rd_cpl_count, rd_cpl_q_tail, rd_cpl_q_head_inflight, rd_cpl_q_head,
                                          rd_req_q_tail, rd_req_q_read_pos, rd_req_q_head} :
                ctrl_reg_raddr == 4'h2 ? rd_stream_ch_req_q_base[31:0] :
                ctrl_reg_raddr == 4'h3 ? rd_stream_ch_req_q_base[63:32] :
                ctrl_reg_raddr == 4'h4 ? rd_stream_ch_cpl_q_base[31:0] :
                ctrl_reg_raddr == 4'h5 ? rd_stream_ch_cpl_q_base[63:32] :
                ctrl_reg_raddr == 4'h6 ? rd_stream_ch_req_head_tail[31:0] :
                ctrl_reg_raddr == 4'h7 ? rd_stream_ch_req_head_tail[63:32] :
                ctrl_reg_raddr == 4'h8 ? rd_stream_ch_cpl_head_tail[31:0] :
                ctrl_reg_raddr == 4'h9 ? rd_stream_ch_cpl_head_tail[63:32] :
                ctrl_reg_raddr == 4'ha ? {16'd0, rd_stream_ch_cpl_q_depth, rd_stream_ch_req_q_depth} :
                ctrl_reg_raddr == 4'hb ? {rd_stream_completes, rd_stream_issues} :
                ctrl_reg_raddr == 4'hc ? rd_doorbell_addr[31:0] :
                ctrl_reg_raddr == 4'hd ? rd_doorbell_addr[63:32] :
                ctrl_reg_raddr == 4'he ? {23'd0, rd_check_request, 3'd0, rd_ch_check_with_doorbell, 3'd0, rd_ch_interrupt} :
                ctrl_reg_raddr == 4'hf ? 32'd0 : 32'd0;

    // queue data
    wire [31:0]  rd_queue_rdata;
    generate
       if (ENABLE_QUEUE > 0) begin
          // addr : ch_log, req/cpl, queue_dl, qew_log
          wire [QEW_LOG-1:0]    queue_data_waddr = axi_write_addr - QUEUE_BASE;
          wire [CH_NUM_LOG-1:0] queue_data_wch = (axi_write_addr - QUEUE_BASE) >> (QEW_LOG + QUEUE_DL + 1);
          wire                  queue_data_w_is_cpl = (axi_write_addr - QUEUE_BASE) >> (QEW_LOG + QUEUE_DL);
          wire [QUEUE_DL-1:0]   queue_data_wentry = (axi_write_addr - QUEUE_BASE) >> QEW_LOG;
          wire                  queue_data_wen = axi_write_addr < QUEUE_HEAD_TAIL && axi_queue_write;
          wire [3:0]            queue_head_tail_waddr = axi_write_addr - QUEUE_HEAD_TAIL;
          wire [CH_NUM_LOG-1:0] queue_head_tail_wch = (axi_write_addr - QUEUE_HEAD_TAIL) >> 4;
          wire                  queue_head_tail_wen = axi_write_addr >= QUEUE_HEAD_TAIL && axi_queue_write;
          wire [QEW_LOG-1:0]    queue_data_raddr = axi_read_addr - QUEUE_BASE;
          wire [CH_NUM_LOG-1:0] queue_data_rch = (axi_read_addr - QUEUE_BASE) >> (QEW_LOG + QUEUE_DL + 1);
          wire                  queue_data_r_is_cpl = (axi_read_addr - QUEUE_BASE) >> (QEW_LOG + QUEUE_DL);
          wire [QUEUE_DL-1:0]   queue_data_rentry = (axi_read_addr - QUEUE_BASE) >> QEW_LOG;
          wire                  queue_data_ren = axi_read_addr < QUEUE_HEAD_TAIL && axi_queue_read;
          wire [3:0]            queue_head_tail_raddr = axi_read_addr - QUEUE_HEAD_TAIL;
          wire [CH_NUM_LOG-1:0] queue_head_tail_rch = (axi_read_addr - QUEUE_HEAD_TAIL) >> 4;
          wire                  queue_head_tail_ren = axi_read_addr >= QUEUE_HEAD_TAIL && axi_queue_read;
          wire [31:0]           queue_wdata = axi_write_data;

          reg [8*CH_NUM-1:0]    req_queue_heads;
          reg [8*CH_NUM-1:0]    req_queue_tails;
          reg [8*CH_NUM-1:0]    cpl_queue_heads;
          reg [8*CH_NUM-1:0]    cpl_queue_tails;
          for (genvar i=0; i<CH_NUM; i=i+1) begin
             always @(posedge clk) begin
                if (~resetn || ~stream_ch_valids[i]) begin
                   req_queue_heads[i*8+:8] <= 'd0;
                end else if (queue_head_tail_wen && queue_head_tail_wch == i && queue_head_tail_waddr[3:2] == 2'h0) begin
                   req_queue_heads[i*8+:8] <= {'d0, queue_wdata[QUEUE_DL-1:0]};
                end else if (stream_req_update && stream_req_update_ch == i) begin
                   req_queue_heads[i*8+:8] <= (req_queue_heads[i*8+:8] + 1'b1) & (QUEUE_DEPTH-1);
                end
             end
             always @(posedge clk) begin
                if (~resetn || ~stream_ch_valids[i]) begin
                   req_queue_tails[i*8+:8] <= 'd0;
                end else if (queue_head_tail_wen && queue_head_tail_wch == i && queue_head_tail_waddr[3:2] == 2'h1) begin
                   req_queue_tails[i*8+:8] <= {'d0, queue_wdata[QUEUE_DL-1:0]};
                end
             end
             always @(posedge clk) begin
                if (~resetn || ~stream_ch_valids[i]) begin
                   cpl_queue_heads[i*8+:8] <= 'd0;
                end else if (queue_head_tail_wen && queue_head_tail_wch == i && queue_head_tail_waddr[3:2] == 2'h2) begin
                   cpl_queue_heads[i*8+:8] <= {'d0, queue_wdata[QUEUE_DL-1:0]};
                end
             end
             always @(posedge clk) begin
                if (~resetn || ~stream_ch_valids[i]) begin
                   cpl_queue_tails[i*8+:8] <= 'd0;
                end else if (queue_head_tail_wen && queue_head_tail_wch == i && queue_head_tail_waddr[3:2] == 2'h3) begin
                   cpl_queue_tails[i*8+:8] <= {'d0, queue_wdata[QUEUE_DL-1:0]};
                end else if (stream_cpl_update && stream_cpl_update_ch == i) begin
                   cpl_queue_tails[i*8+:8] <= (cpl_queue_tails[i*8+:8] + 1'b1) & (QUEUE_DEPTH-1);
                end
             end
          end
          reg [32*CH_NUM-1:0] queue_cpl_sizes;
          reg [32*QUEUE_DEPTH*CH_NUM-1:0] queue_req_sizes;
          for (genvar i=0; i<CH_NUM; i=i+1) begin
             for (genvar j=0; j<QUEUE_DEPTH; j=j+1) begin
                always @(posedge clk) begin
                   if (~resetn) begin
                      queue_req_sizes[(i*QUEUE_DEPTH+j)*32+:32] <= 'd0;
                   end else if (stream_req_update && stream_req_update_ch == i && req_queue_heads[i*8+:8] == j) begin
                      queue_req_sizes[(i*QUEUE_DEPTH+j)*32+:32] <= stream_req_update_size;
                   end
                end
             end
          end
          for (genvar i=0; i<CH_NUM; i=i+1) begin
             always @(posedge clk) begin
                if (~resetn || ~stream_ch_valids[i]) begin
                   queue_cpl_sizes[i*32+:32] <= 'd0;
                end else if (queue_data_wen && queue_data_wch == i && queue_data_w_is_cpl && queue_data_waddr[QEW_LOG-1:2] == 'h2) begin
                   queue_cpl_sizes[i*32+:32] <= queue_wdata;
                end
             end
          end
          wire w_queue_ch_valid = stream_ch_valids >> queue_data_rch;
          wire [63:0] w_queue_element_addr = {'d0, D2D_AXI_BASE} + {32'd0, queue_data_rch} * D2D_AXI_RANGE;
          wire [31:0] w_queue_element_low_req_size = queue_req_sizes >> {queue_data_rch, queue_data_rentry, 5'd0};
          wire [31:0] w_queue_element_low_cpl_size = queue_cpl_sizes >> {queue_data_rch, 5'd0};
          wire [63:0] w_queue_element_size = {32'd0, queue_data_r_is_cpl ? w_queue_element_low_cpl_size : w_queue_element_low_req_size};
          wire [63:0] w_queue_element_status = w_queue_ch_valid ? STATUS_VALID : STATUS_CLOSED;
          wire [QEWB-1:0] w_queue_element = {64'd0, w_queue_element_status, w_queue_element_size, w_queue_element_addr};
          wire [7:0]      w_queue_req_head = req_queue_heads >> {queue_head_tail_rch, 3'd0};
          wire [7:0]      w_queue_req_tail = req_queue_tails >> {queue_head_tail_rch, 3'd0};
          wire [7:0]      w_queue_cpl_head = cpl_queue_heads >> {queue_head_tail_rch, 3'd0};
          wire [7:0]      w_queue_cpl_tail = cpl_queue_tails >> {queue_head_tail_rch, 3'd0};
          assign rd_queue_rdata = queue_data_ren ? w_queue_element >> {queue_data_raddr, 3'd0} :
                                  queue_head_tail_raddr[3:2] == 2'h0 ? {24'd0, w_queue_req_head} :
                                  queue_head_tail_raddr[3:2] == 2'h1 ? {24'd0, w_queue_req_tail} :
                                  queue_head_tail_raddr[3:2] == 2'h2 ? {24'd0, w_queue_cpl_head} : {24'd0, w_queue_cpl_tail};
          assign stream_req_q_heads = req_queue_heads;
          assign stream_req_q_tails = req_queue_tails;
          assign stream_cpl_q_heads = cpl_queue_heads;
          assign stream_cpl_q_tails = cpl_queue_tails;

          reg [QEWB-1:0]  qe_data;
          reg             qe_data_valid;
          wire            w_q_ch_valid = stream_ch_valids >> stream_queue_read_ch;
          wire [63:0] w_qe_addr = {'d0, D2D_AXI_BASE} + ({1'd0, stream_queue_read_ch} + 1) * D2D_AXI_RANGE;
          wire [31:0] w_qe_low_req_size = queue_req_sizes >> {stream_queue_read_ch, stream_queue_read_entry, 5'd0};
          wire [63:0] w_qe_size = {32'd0, w_qe_low_req_size};
          wire [63:0] w_qe_status = w_q_ch_valid ? STATUS_VALID : STATUS_CLOSED;
          always @(posedge clk) begin
             if (~resetn) begin
                qe_data_valid <= 1'b0;
             end else begin
                qe_data <= {64'd0, w_qe_status, w_qe_size, w_qe_addr};
                qe_data_valid <= stream_queue_read_valid;
             end
          end
          assign stream_queue_read_data = qe_data;
          assign stream_queue_read_data_valid = qe_data_valid;

          reg [CH_NUM-1:0] head_tail_updates_reg;
          wire [CH_NUM-1:0] w_head_updates = stream_ch_valids & stream_ch_d2d_valids & ({{CH_NUM-1{1'b0}}, stream_req_update} << stream_req_update_ch);
          wire [CH_NUM-1:0] w_tail_updates = stream_ch_valids & stream_ch_d2d_valids & ({{CH_NUM-1{1'b0}}, stream_cpl_update} << stream_cpl_update_ch);
          always @(posedge clk) begin
             if (~resetn) begin
                head_tail_updates_reg <= 'd0;
             end else if (stream_req_update && stream_cpl_update) begin
                head_tail_updates_reg <= w_head_updates | w_tail_updates;
             end else if (stream_req_update) begin
                head_tail_updates_reg <= w_head_updates;
             end else if (stream_cpl_update) begin
                head_tail_updates_reg <= w_tail_updates;
             end else begin
                head_tail_updates_reg <= 'd0;
             end
          end
          assign head_tail_updates = head_tail_updates_reg;
       end else begin
          assign rd_queue_rdata = STREAM_ENGINE_IDENTIFIER;
          assign stream_queue_read_data_valid = 1'b0;
          assign stream_req_q_heads = 'd0;
          assign stream_req_q_tails = 'd0;
          assign stream_cpl_q_heads = 'd0;
          assign stream_cpl_q_tails = 'd0;
          assign head_tail_updates = 'd0;
       end
    endgenerate


    wire [31:0] global_rdata =
                axi_read_addr == CTRL_MAX ? {15'd0, rccount_switch, stream_check_interval} :
                axi_read_addr == CTRL_MAX + 3'd4 ? rccount_switch ? i_rc_count : i_rc_icount :
                axi_read_addr == CTRL_MAX + 4'd8 ? 32'd0 | vpmap_acc_ch :
                axi_read_addr < CTRL_END ? {8'd0, VP_MAP_NUM_LOG_8B, 8'd0, CH_NUM_LOG_8B} : STREAM_ENGINE_IDENTIFIER;
    reg [31:0]  ctrl_reg_rdata;

    always @(posedge clk) begin
        if (~resetn) begin
            ctrl_reg_rdata <= 32'd0;
        end else if (axi_ctrl_read) begin
            ctrl_reg_rdata <= rd_stream_rdata;
        end else if (axi_queue_read) begin
            ctrl_reg_rdata <= rd_queue_rdata;
        end else begin
            ctrl_reg_rdata <= global_rdata;
        end
    end

    always @(posedge clk) begin
        if (~resetn) begin
            axi_read_data <= 32'd0;
        end else if (axi_vpmap_read) begin
            axi_read_data <= vpmap_reg_rdata >> {axi_read_addr[2+:3], 5'd0};
        end else begin
            axi_read_data <= ctrl_reg_rdata;
        end
    end

endmodule
