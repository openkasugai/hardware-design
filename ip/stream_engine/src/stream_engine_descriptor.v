/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module stream_engine_descriptor #(
    parameter CH_NUM_LOG = 3,
    parameter QEW_LOG = 5,
    parameter QEW = 1 << QEW_LOG,
    parameter VP_MAP_NUM_LOG = 4,
    parameter DESC_RQ_DW = 512,
    parameter DESC_RQ_DK = 16,
    parameter DESC_RC_DW = 512,
    parameter DESC_RC_DK = 16,
    parameter DESC_LEN = 512,
    parameter RCBASE = 96,
    parameter DISABLE_FRAME_INFO = 0,
    parameter ENABLE_QUEUE = 0,
    parameter CH_BASE = 0
    ) (
    input [(1<<CH_NUM_LOG)-1:0]                  stream_ch_valids,
    input [(1<<CH_NUM_LOG)-1:0]                  stream_ch_d2d_valids,

    input [31:0]                                 tx_size,
    input [CH_NUM_LOG-1:0]                       tx_ch,
    input                                        tx_valid,
    output                                       tx_ready,

    output [CH_NUM_LOG-1:0]                      stream_req_update_ch, // head update
    output [31:0]                                stream_req_update_size,
    output                                       stream_req_update,

    input [(1<<(QEW_LOG+3))*(1<<CH_NUM_LOG)-1:0] requests,
    input [(1<<CH_NUM_LOG)-1:0]                  request_valids,
    input [(1<<CH_NUM_LOG)-1:0]                  request_firsts,

    input [DESC_RQ_DW-1:0]                       desc_req_data,
    input [DESC_RQ_DK-1:0]                       desc_req_keep,
    input                                        desc_req_valid,
    output reg                                   desc_req_ready,

    output reg [DESC_RC_DW-1:0]                  desc_out_data,
    output reg [DESC_RC_DK-1:0]                  desc_out_keep,
    output reg                                   desc_out_valid,
    output reg                                   desc_out_last,
    input                                        desc_out_ready,

    output [63:0]                                updated_request_vaddr,
    output [31:0]                                updated_request_size,
    output reg                                   updated_request_valid,
    output reg [CH_NUM_LOG-1:0]                  updated_request_ch,

    output reg [63:0]                            request_base_vaddr,
    output reg [31:0]                            request_base_size,
    output reg [CH_NUM_LOG-1:0]                  request_base_ch,
    output reg                                   request_base_valid,
    output reg                                   request_base_final,
    input                                        request_base_ready,

    output [VP_MAP_NUM_LOG+CH_NUM_LOG-1:0]       vpmap_conv_addr,
    input [64+64+32:0]                           vpmap_conv_rdata,

    input                                        clk,
    input                                        resetn
    );

    localparam CH_NUM = 1 << CH_NUM_LOG;
    localparam QEWB_LOG = QEW_LOG + 3;
    localparam QEWB = 1 << QEWB_LOG;
    localparam VP_MAP_NUM_HALF = 1 << (VP_MAP_NUM_LOG-1);

    reg                   desc_create_valid;
    reg                   desc_create_ch_valid;
    wire                  desc_create_ch_ready;
    wire [2:0]            addr_hits;
    wire [2:0]            addr_no_hits;
    wire                  w_request_first;

    // frame info
    reg [32*CH_NUM-1:0] frame_info_sizes;
    reg [CH_NUM-1:0]    frame_info_valids;
    wire [CH_NUM-1:0]   frame_info_readys;
    wire [32*CH_NUM-1:0] request_sizes_mod;

    generate
        for (genvar i=0; i<CH_NUM; i=i+1) begin
            always @(posedge clk) begin
                if (~resetn || ~stream_ch_valids[i]) begin
                    frame_info_sizes[32*i+:32] <= 32'd0;
                    frame_info_valids[i] <= 1'b0;
                end else if (DISABLE_FRAME_INFO != 0) begin
                    frame_info_valids[i] <= 1'b1;
                    frame_info_sizes[32*i+:32] <= 32'hffffffc0; // 64byte aligned
                end else if (tx_valid && i == tx_ch && ~frame_info_valids[i] && (ENABLE_QUEUE == 0 || ~stream_ch_d2d_valids[i])) begin
                    frame_info_sizes[32*i+:32] <= tx_size;
                    frame_info_valids[i] <= 1'b1;
                end else if (updated_request_valid && w_request_first && updated_request_ch == i) begin
                    frame_info_valids[i] <= 1'b0;
                end
            end
            assign frame_info_readys[i] = ~frame_info_valids[i] || ~tx_valid || tx_ch != i;
            assign request_sizes_mod[i*32+:32]
              = requests[i*QEWB+7'd64+:32] < frame_info_sizes[i*32+:32] ? requests[i*QEWB+7'd64+:32] : frame_info_sizes[i*32+:32];
        end
        if (DISABLE_FRAME_INFO != 0) begin
            assign tx_ready = 1'b1;
        end else begin
            assign tx_ready = &frame_info_readys;
        end
        if (ENABLE_QUEUE>0) begin
           reg [CH_NUM_LOG-1:0] req_update_ch;
           reg [31:0]           req_update_size;
           reg                  req_update;
           wire                 w_req_ch_valid = stream_ch_d2d_valids >> tx_ch;
           always @(posedge clk) begin
              if (~resetn) begin
                 req_update <= 1'b0;
              end else if (tx_valid && tx_ready && w_req_ch_valid) begin
                 req_update <= 1'b1;
                 req_update_ch <= tx_ch;
                 req_update_size <= tx_size;
              end else begin
                 req_update <= 1'b0;
              end
           end
           assign stream_req_update_ch = req_update_ch;
           assign stream_req_update_size = req_update_size;
           assign stream_req_update = req_update;
        end else begin
           assign stream_req_update_ch = 'd0;
           assign stream_req_update_size = 'd0;
           assign stream_req_update = 1'b0;
        end
    endgenerate

    reg [63:0]            request_vaddr;
    reg [31:0]            request_size;
    reg                   request_valid;
    reg                   request_vaddr_carry;
    wire [63:0]           w_request_vaddr = requests >> {updated_request_ch, {QEWB_LOG{1'd0}}};
    wire [31:0]           w_request_size = requests >> ({updated_request_ch, {QEWB_LOG{1'd0}}} + 7'd64);
    wire [31:0]           w_request_size_first = request_sizes_mod >> {updated_request_ch, 5'd0};
    assign                w_request_first = request_firsts >> updated_request_ch;

    wire [31:0]           desc_size;
    reg [31:0]            vpmap_max_size_d1;

    always @(posedge clk) begin
        if (~resetn) begin
            request_vaddr <= 64'd0;
            request_size <= 32'd0;
            request_valid <= 1'b0;
            request_vaddr_carry <= 1'b0;
        end else if (~request_valid & ~updated_request_valid & ~request_base_valid) begin
            request_vaddr <= w_request_vaddr;
            request_size <= w_request_first ? w_request_size_first : w_request_size;
            request_valid <= desc_create_valid;
        end else if (addr_hits[1]) begin
            request_size <= vpmap_max_size_d1 >= request_size ? 'd0 : request_size - desc_size;
            {request_vaddr_carry, request_vaddr[31:0]} <= {1'b0, request_vaddr[31:0]} + desc_size;
        end else if (addr_no_hits[1]) begin
            request_size <= 'd0;
            {request_vaddr_carry, request_vaddr[31:0]} <= 'd0;
        end else if (addr_hits[2]) begin
            request_vaddr[63:32] <= request_vaddr[63:32] + request_vaddr_carry;
        end else if (addr_no_hits[2]) begin
            request_vaddr[63:32] <= 'd0;
        end else if (desc_out_valid && desc_out_ready && desc_out_last) begin
            request_valid <= 1'b0;
        end
    end
    assign desc_create_ch_ready = addr_hits[2] || addr_no_hits[2] || ~desc_create_ch_valid;

    always @(posedge clk) begin
        if (~resetn) begin
            request_base_valid <= 1'b0;
            request_base_final <= 1'b0;
            request_base_vaddr <= 'd0;
            request_base_size <= 'd0;
            request_base_ch <= 'd0;
        end else if (request_valid && desc_create_ch_valid) begin
            if (addr_hits[1]) begin
                request_base_vaddr <= request_vaddr;
                request_base_final <= vpmap_max_size_d1 >= request_size;
            end else if (addr_no_hits[1]) begin
                request_base_vaddr <= request_vaddr;
                request_base_final <= 1'b1;
            end else if (addr_hits[2] || addr_no_hits[2]) begin
                request_base_valid <= desc_create_ch_valid;
                request_base_size <= desc_size;
                request_base_ch <= updated_request_ch;
            end
        end else begin
            request_base_valid <= request_base_valid & ~request_base_ready;
        end
    end

    always @(posedge clk) begin
        if (~resetn) begin
            updated_request_valid <= 1'b0;
        end else if (request_valid && (addr_hits[2] || addr_no_hits[2])) begin
            updated_request_valid <= desc_create_ch_valid;
        end else begin
            updated_request_valid <= 1'b0;
        end
    end
    assign updated_request_vaddr = request_vaddr;
    assign updated_request_size = request_size;

    wire [RCBASE-1:0]   desc_out_desc;
    wire [63:0]         request_paddr;
    reg [(DESC_LEN>>5)-1:0] desc_keep_pre;

    always @(posedge clk) begin
        if (~resetn) begin
            desc_out_data <= 'd0;
            desc_out_keep <= 'd0;
            desc_out_valid <= 1'b0;
            desc_out_last <= 1'b0;
            desc_keep_pre <= 'd0;
        end else if (desc_out_valid) begin
            desc_out_valid <= desc_out_valid & ~(desc_out_ready & desc_out_last);
            if (desc_out_ready) begin
                desc_out_data <= 'd0;
                desc_out_last <= ~&desc_keep_pre[DESC_RC_DK-1:0];
                desc_out_keep <= desc_keep_pre;
                desc_keep_pre <= desc_keep_pre >> DESC_RC_DK;
            end
        end else if (request_valid && ~desc_create_ch_valid) begin
            desc_out_data[RCBASE-1:0] <= desc_out_desc;
            desc_out_data[RCBASE+64+:64] <= 'd0;
            desc_out_data[RCBASE+32+:32] <= 'd0;
            desc_out_data[RCBASE+:16] <= 'd0;
            desc_out_data[RCBASE+16+:8] <= 'd0;
            desc_out_keep <= {DESC_RC_DK{1'b1}};
            desc_out_last <= DESC_RC_DK >= (DESC_LEN>>5) + 4;
            desc_keep_pre <= ~{((DESC_LEN+RCBASE)>>5){1'b0}} >> DESC_RC_DK;
            desc_out_valid <= 1'b1;
        end else if (request_valid && (addr_hits[2] || addr_no_hits[2])) begin
            desc_out_data[RCBASE-1:0] <= desc_out_desc;
            desc_out_data[RCBASE+64+:64] <= request_paddr;
            desc_out_data[RCBASE+32+:32] <= desc_size;
            desc_out_data[RCBASE+:16] <= desc_out_data[RCBASE+:16] + 1'b1; // task_id
            desc_out_data[RCBASE+16+:8] <= 'd0 | |desc_size;
            desc_out_data[RCBASE+24+:8] <= 'd0 | (vpmap_max_size_d1 >= request_size);
            desc_out_keep <= {DESC_RC_DK{1'b1}};
            desc_out_last <= DESC_RC_DK >= (DESC_LEN>>5) + 4;
            desc_keep_pre <= ~{((DESC_LEN+RCBASE)>>5){1'b0}} >> DESC_RC_DK;
            desc_out_valid <= 1'b1;
        end
    end

    // vaddr -> paddr
    // check belog:
    //  offset = req.vaddr - vmap.vaddr
    //  bool in_range = vmap.vaddr <= req.vaddr && req.vaddr < vmap.vaddr + vmap.size
    //                = vmap.vaddr <= req.vaddr && (req.vaddr - vmap.vaddr) - vmap.size < 0
    //                = vmap.vaddr <= req.vaddr && vmap.size > offset
    //  max_size = vmap.vaddr + vmap.size - req.vaddr
    //           =  vmap.size - offset
    //  out.size = min(max_size, req.size)
    //  out.paddr = vmap.paddr + offset
    //
    // separate 64bit address calculation to 32bit
    //  - range_gth = vmap.vaddr_h < req.vaddr_h
    //    range_eqh = vmap.vaddr_h == req.vaddr_h
    //    range_gel = vmap.vaddr_l <= req.vaddr_l
    //    offset_h_tmp = req.vaddr_h - vmap.vaddr_h
    //    {b, offset_l} = req.vaddr_l - vmap.vaddr_l
    //  - offset_h = offset_h_tmp - b
    //    range_lt = vmap.size > offset_l && ~|offset_h
    //    range_ge = range_gth || (range_eqh && range_gel)
    //    max_size = vmap.size - offset_l
    //    {c3, out.paddr_l} = vmap.paddr_l + offset_l  *
    //    out.paddr_h_tmp = vmap.paddr_h + offset_h
    //  - range_ltl = range_lt_val_l > 0
    //    range_lth = offset_h + c2 == 0
    //    in_range = range_ge && range_ltl && range_lth *
    //    out.size = max_size < req.size ? max_size : req.size *
    //    out.paddr_h = out.paddr_h_tmp + c3  &

    reg [VP_MAP_NUM_LOG-1:0] vpmap_addr;
    reg [VP_MAP_NUM_LOG-1:0] vpmap_addr_low;
    reg [VP_MAP_NUM_LOG-1:0] vpmap_addr_high;
    reg [VP_MAP_NUM_LOG-1:0] vpmap_addr_min;
    reg [VP_MAP_NUM_LOG-1:0] vpmap_addr_max;
    reg [VP_MAP_NUM_LOG-1:0] vpmap_addr_diff;
    reg [VP_MAP_NUM_LOG-1:0] vpmap_addr_low_prev;
    reg [VP_MAP_NUM_LOG-1:0] vpmap_addr_high_prev;
    reg                      vpmap_rd_valid;
    reg                      vpmap_rd_last;
    reg [1:0]                vpmap_addr_count;
    reg                      vpmap_addr_is_high;
    wire [63:0]              vpmap_vaddr;
    wire [63:0]              vpmap_paddr;
    wire [31:0]              vpmap_size;
    wire                     vpmap_valid;
    wire                     vpmap_min_update;
    wire                     vpmap_max_update;
    wire [VP_MAP_NUM_LOG-1:0] w_vpmap_addr_low;
    wire [VP_MAP_NUM_LOG-1:0] w_vpmap_addr_high;
    reg vpmap_range_gth, vpmap_range_eqh, vpmap_range_gel;
    reg vpmap_valid_d1;

    assign {vpmap_valid, vpmap_size, vpmap_paddr, vpmap_vaddr} = vpmap_conv_rdata;

    always @(posedge clk) begin
        if (~resetn) begin
            vpmap_addr <= 'd0;
            vpmap_addr_low <= 'd0;
            vpmap_addr_high <= VP_MAP_NUM_HALF;
            vpmap_addr_high_prev <= VP_MAP_NUM_HALF;
            vpmap_addr_min <= 'd0;
            vpmap_addr_max <= {VP_MAP_NUM_LOG{1'b1}};
            vpmap_addr_diff <= VP_MAP_NUM_HALF >> 1;
            vpmap_rd_valid <= 1'b0;
            vpmap_rd_last <= 1'b0;
            vpmap_addr_is_high <= 1'b0;
            vpmap_addr_count <= 2'd0;
        end else if (|addr_hits || |addr_no_hits) begin
            vpmap_addr <= 'd0;
            vpmap_addr_low <= 'd0;
            vpmap_addr_high <= VP_MAP_NUM_HALF;
            vpmap_addr_high_prev <= VP_MAP_NUM_HALF;
            vpmap_addr_min <= 'd0;
            vpmap_addr_max <= {VP_MAP_NUM_LOG{1'b1}};
            vpmap_addr_diff <= VP_MAP_NUM_HALF >> 1;
            vpmap_rd_valid <= 1'b0;
            vpmap_rd_last <= 1'b0;
            vpmap_addr_is_high <= 1'b0;
            vpmap_addr_count <= 2'd0;
        end else if (vpmap_addr_low == vpmap_addr_high) begin
            vpmap_rd_last <= 1'b1;
        end else if (desc_create_ch_valid) begin
            vpmap_addr_is_high <= ~vpmap_addr_is_high;
            vpmap_addr <= vpmap_addr_is_high ? w_vpmap_addr_low : vpmap_addr_high;
            if (vpmap_addr_is_high) begin
                vpmap_addr_low <= w_vpmap_addr_low;
                vpmap_addr_high <= w_vpmap_addr_high;
                vpmap_addr_diff <= vpmap_addr_diff >> 1;
                vpmap_addr_low_prev <= vpmap_addr_low;
                vpmap_addr_high_prev <= vpmap_addr_high;
            end
            if (vpmap_addr_count >= 2'd3) begin
                if (~vpmap_addr_is_high) begin
                    vpmap_addr_min <= vpmap_min_update && vpmap_addr_low_prev > vpmap_addr_min ? vpmap_addr_low_prev : vpmap_addr_min;
                    vpmap_addr_max <= vpmap_max_update && vpmap_addr_low_prev < vpmap_addr_max ? vpmap_addr_low_prev : vpmap_addr_max;
                end else begin
                    vpmap_addr_min <= vpmap_min_update && vpmap_addr_high_prev > vpmap_addr_min ? vpmap_addr_high_prev : vpmap_addr_min;
                    vpmap_addr_max <= vpmap_max_update && vpmap_addr_high_prev < vpmap_addr_max ? vpmap_addr_high_prev : vpmap_addr_max;
                end
            end
            vpmap_rd_valid <= 1'b1;
            vpmap_addr_count <= &vpmap_addr_count ? vpmap_addr_count : vpmap_addr_count + 1'b1;
        end
    end
    assign vpmap_min_update = (vpmap_range_gth || (vpmap_range_eqh && vpmap_range_gel)) && vpmap_valid_d1;
    assign vpmap_max_update = ~((vpmap_range_gth || (vpmap_range_eqh && vpmap_range_gel)) && vpmap_valid_d1);
    wire w_vpmap_addr_to_lower_min = vpmap_min_update && vpmap_addr_high_prev > vpmap_addr_min ? vpmap_addr_high_prev < vpmap_addr_low : vpmap_addr_min < vpmap_addr_low;
    wire w_vpmap_addr_to_lower_max = vpmap_max_update && vpmap_addr_high_prev < vpmap_addr_max ? vpmap_addr_high_prev > vpmap_addr_low : vpmap_addr_max > vpmap_addr_low;
    wire w_vpmap_addr_to_lower = (w_vpmap_addr_to_lower_max && w_vpmap_addr_to_lower_min) && &vpmap_addr_count;
    assign w_vpmap_addr_low =  w_vpmap_addr_to_lower ? vpmap_addr_low - vpmap_addr_diff : vpmap_addr_high - vpmap_addr_diff;
    assign w_vpmap_addr_high = w_vpmap_addr_to_lower ? vpmap_addr_low + vpmap_addr_diff : vpmap_addr_high + vpmap_addr_diff;

    assign vpmap_conv_addr = {updated_request_ch, vpmap_addr};

    reg [31:0] vpmap_offset_h_tmp;
    reg [31:0] vpmap_offset_l;
    reg        vpmap_borrow;
    reg [31:0] vpmap_size_d1;
    reg [63:0] vpmap_paddr_d1;
    reg        vpmap_rd_last_d1;
    always @(posedge clk) begin
        if (~resetn) begin
            vpmap_range_gth <= 1'b0;
            vpmap_range_eqh <= 1'b0;
            vpmap_range_gel <= 1'b0;
            vpmap_offset_h_tmp <= 32'd0;
            vpmap_offset_l <= 32'd0;
            vpmap_borrow <= 1'b0;
            vpmap_size_d1 <= 32'd0;
            vpmap_paddr_d1 <= 64'd0;
            vpmap_valid_d1 <= 1'b0;
            vpmap_rd_last_d1 <= 1'b0;
        end else begin
            if (|addr_hits || |addr_no_hits) begin
                vpmap_valid_d1 <= 1'b0;
                vpmap_rd_last_d1 <= 1'b0;
            end else begin
                vpmap_valid_d1 <= vpmap_valid & vpmap_rd_valid;
                vpmap_rd_last_d1 <= vpmap_rd_last & vpmap_rd_valid;
                vpmap_range_gth <= vpmap_vaddr[63:32] < request_vaddr[63:32];
                vpmap_range_eqh <= vpmap_vaddr[63:32] == request_vaddr[63:32];
                vpmap_range_gel <= vpmap_vaddr[31:0] <= request_vaddr[31:0];
                vpmap_offset_h_tmp <= request_vaddr[63:32] - vpmap_vaddr[63:32];
                {vpmap_borrow, vpmap_offset_l} <= {1'b0, request_vaddr[31:0]} - vpmap_vaddr[31:0];
                vpmap_size_d1 <= vpmap_size;
                vpmap_paddr_d1 <= vpmap_paddr;
            end
        end
    end

    reg [31:0] vpmap_offset_h;
    reg        vpmap_carry3;
    reg        vpmap_range_ltl;
    reg        vpmap_range_ge;

    reg [31:0] vpmap_max_size;
    reg [31:0] vpmap_paddr_l, vpmap_paddr_h_tmp;
    reg        vpmap_valid_d2, vpmap_rd_last_d2;

    always @(posedge clk) begin
        if (~resetn) begin
            vpmap_offset_h <= 32'd0;
            vpmap_range_ltl <= 1'b0;
            vpmap_carry3 <= 1'b0;
            vpmap_range_ge <= 1'b0;
            vpmap_max_size <= 32'd0;
            vpmap_paddr_l <= 32'd0;
            vpmap_paddr_h_tmp <= 32'd0;
            vpmap_valid_d2 <= 1'b0;
            vpmap_rd_last_d2 <= 1'b0;
        end else begin
            if (|addr_hits || |addr_no_hits) begin
                vpmap_valid_d2 <= 1'b0;
                vpmap_rd_last_d2 <= 1'b0;
            end else begin
                vpmap_valid_d2 <= vpmap_valid_d1;
                vpmap_rd_last_d2 <= vpmap_rd_last_d1;
                vpmap_offset_h <= vpmap_offset_h_tmp - vpmap_borrow;
                vpmap_range_ltl <= vpmap_size_d1 > vpmap_offset_l;
                vpmap_range_ge <= vpmap_range_gth || (vpmap_range_eqh && vpmap_range_gel);
                vpmap_max_size <= vpmap_size_d1 - vpmap_offset_l;
                {vpmap_carry3, vpmap_paddr_l} <= {1'b0, vpmap_paddr_d1[31:0]} + vpmap_offset_l;
                vpmap_paddr_h_tmp <= vpmap_paddr_d1[63:32] + vpmap_offset_h_tmp - vpmap_borrow;
            end
        end
    end

    reg [63:0] vpmap_paddr_out;
    reg [31:0] vpmap_size_out;
    reg        vpmap_valid_out;
    reg        vpmap_last_out;
    wire       vpmap_range_lth = ~|vpmap_offset_h;
    always @(posedge clk) begin
        if (~resetn) begin
            vpmap_valid_out <= 1'b0;
            vpmap_last_out <= 1'b0;
            vpmap_paddr_out <= 64'd0;
            vpmap_size_out <= 32'd0;
            vpmap_max_size_d1 <= 32'd0;
        end else begin
            if (|addr_hits || |addr_no_hits) begin
                vpmap_valid_out <= 1'b0;
                vpmap_last_out <= 1'b0;
            end else begin
                vpmap_valid_out <= vpmap_valid_d2 && vpmap_range_ge && vpmap_range_ltl && vpmap_range_lth;
                vpmap_last_out <= vpmap_rd_last_d2;
                vpmap_paddr_out[63:32] <= vpmap_paddr_h_tmp + vpmap_carry3;
                vpmap_paddr_out[31:0] <= vpmap_paddr_l;
                vpmap_size_out <= vpmap_rd_last_d2 && ~(vpmap_range_ge && vpmap_range_ltl && vpmap_range_lth) ? 'd0 :
                                  vpmap_max_size >= request_size ? request_size : vpmap_max_size;
                vpmap_max_size_d1 <= vpmap_max_size;
            end
        end
    end

    assign desc_size = vpmap_size_out;
    assign request_paddr = vpmap_paddr_out;
    assign addr_hits[0] = vpmap_valid_out;
    assign addr_no_hits[0] = vpmap_last_out;

    reg [1:0] addr_hits_reg;
    reg [1:0] addr_no_hits_reg;
    always @(posedge clk) begin
        if (~resetn) begin
            addr_hits_reg <= 2'd0;
            addr_no_hits_reg <= 2'd0;
        end else begin
            addr_hits_reg <= {addr_hits_reg[0], addr_hits[0]};
            addr_no_hits_reg <= {addr_no_hits_reg[0], addr_no_hits[0]};
        end
    end
    assign addr_hits[2:1] = addr_hits_reg;
    assign addr_no_hits[2:1] = addr_no_hits_reg;

    reg [RCBASE-1:0] res_header;
    always @(posedge clk) begin
        if (~resetn) begin
            res_header <= 'd0;
            desc_req_ready <= 1'b1;
        end else if (desc_req_valid & desc_req_ready) begin
            res_header[11:0] <= desc_req_data[11:0]; // low addr
            res_header[28:16] <= {desc_req_data[74:64], 2'd0}; // byte count
            res_header[30] <= 1'b1; // request completed
            res_header[42:32] <= desc_req_data[74:64]; // dword
            res_header[71:64] <= desc_req_data[103:96]; // tag
            desc_req_ready <= 1'b0;
        end else begin
            desc_req_ready <= desc_req_ready || (desc_out_valid & desc_out_ready & desc_out_last);
        end
    end
    assign desc_out_desc = res_header;

    always @(posedge clk) begin
        if (~resetn) begin
            updated_request_ch <= 'd0;
            desc_create_ch_valid <= 1'b0;
            desc_create_valid <= 1'b0;
        end else if (desc_req_valid & desc_req_ready) begin
            updated_request_ch <= desc_req_data[103:96] - CH_BASE;
            desc_create_valid <= 1'b1;
            desc_create_ch_valid <= (request_valids & (frame_info_valids | ~request_firsts)) >> (desc_req_data[103:96] - CH_BASE);
        end else begin
            desc_create_valid <= desc_create_valid & (~desc_create_ch_ready || request_base_valid);
            desc_create_ch_valid <= desc_create_ch_valid & ~desc_create_ch_ready;
        end
    end

endmodule
