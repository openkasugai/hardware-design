/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module route_control_regs #(
    parameter CTX_ID_BITS = 5,
    parameter TDEST_BITS = 4,
    parameter EXT_RELATION = 0,
    parameter FRAME_MAX = 24,
    parameter BURST_BITS = 4
    ) (
    input [CTX_ID_BITS+4:0]                                        cfg_raddr,
    input                                                          cfg_arvalid,
    output [31:0]                                                  cfg_rdata,
    output                                                         cfg_rvalid,
    input [CTX_ID_BITS+4:0]                                        cfg_waddr,
    input [31:0]                                                   cfg_wdata,
    input                                                          cfg_wvalid,

    output reg [(1<<CTX_ID_BITS)-1:0]                              ch_valids,
    output reg [(1<<CTX_ID_BITS)-1:0]                              ch_mmapped,
    output reg [(1<<CTX_ID_BITS)-1:0]                              disable_frame_out_signals,
    output reg [(1<<CTX_ID_BITS)*TDEST_BITS-1:0]                   ch_dests,
    output reg [(1<<CTX_ID_BITS)*32-1:0]                           ch_frame_sizes,
    output reg [(1<<CTX_ID_BITS)-1:0]                              ch_frame_size_variables,
    output reg [(1<<CTX_ID_BITS)*FRAME_MAX-1:0]                    ch_frame_addr_valids,
    output reg [(1<<CTX_ID_BITS)*FRAME_MAX-1:0]                    ch_frames_used,
    output reg [(1<<CTX_ID_BITS)-1:0]                              ch_frame_vacants,
    output reg [(1<<CTX_ID_BITS)*3-1:0]                            ch_relation_nums,
    output reg [(1<<CTX_ID_BITS)*(EXT_RELATION > 0 ? 7 : 3)*8-1:0] ch_relations,
    output reg [BURST_BITS:0]                                      burst_max,

    input [CTX_ID_BITS+4:0]                                        addr_read_pos,
    input                                                          addr_read_valid,
    output [63:0]                                                  addr_read_data,
    output                                                         addr_read_data_valid,

    input [7:0]                                                    frame_assign_frame_id,
    input [CTX_ID_BITS-1:0]                                        frame_assign_user,
    input                                                          frame_assign_valid,

    input [7:0]                                                    frame_release_frame_id,
    input [CTX_ID_BITS-1:0]                                        frame_release_user,
    input                                                          frame_release_valid,

    input                                                          clk,
    input                                                          resetn
    );

   localparam CH_NUM = 1 << CTX_ID_BITS;
   localparam RELATION_NUM = EXT_RELATION > 0 ? 7 : 3;
   localparam FRAME_MAX_CEIL = 32;
   localparam FRAME0 = FRAME_MAX_CEIL - FRAME_MAX;
   localparam FRAME_MAX_LOG = $clog2(FRAME_MAX_CEIL);

   // registers
   // [+0] [0]: valid
   //      [4]: memory mapped
   //      [8]: disable frame out req/ready
   //      [16+:TDEST_BITS]: destination
   // [+1] [31:0] buffer size
   // [+2] [31:8] buffer address valids
   // [+3] [31:8] buffer used
   // [+4]   [2:0] out/in frame ctx id num
   //       [15:8] out/in frame ctx id 0
   //      [23:16] out/in frame ctx id 1
   //      [31:24] out/in frame ctx id 2
   // [+5]   [7:0] out/in frame ctx id 3
   //       [15:8] out/in frame ctx id 4
   //      [23:16] out/in frame ctx id 5
   //      [31:24] out/in frame ctx id 6
   // [+8-31] frame address 32bit [43:12]

   wire [CTX_ID_BITS-1:0]    cfg_wch = cfg_waddr >> 5;
   wire [CTX_ID_BITS-1:0]    cfg_rch = cfg_raddr >> 5;
   wire [4:0]                cfg_addr_pos = cfg_waddr[4:0] - FRAME0;

   // write config regs
   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         always @(posedge clk) begin
            if (~resetn) begin
               ch_valids[i] <= 1'b0;
               ch_mmapped[i] <= 1'b0;
               disable_frame_out_signals[i] <= 1'b0;
               ch_dests[i*TDEST_BITS+:TDEST_BITS] <= {TDEST_BITS{1'b1}};
               ch_frame_sizes[i*32+:32] <= 32'd0;
               ch_frame_addr_valids[i*FRAME_MAX+:FRAME_MAX] <= 'd0;
               ch_relation_nums[i*3+:3] <= 'd0;
               ch_relations[i*RELATION_NUM*8+:24] <= 'd0;
            end else if (cfg_wvalid && cfg_wch == i) begin
               casex(cfg_waddr[4:0])
                 5'h00: begin
                    ch_valids[i] <= cfg_wdata[0];
                    ch_mmapped[i] <= cfg_wdata[4];
                    disable_frame_out_signals[i] <= cfg_wdata[8];
                    ch_dests[i*TDEST_BITS+:TDEST_BITS] <= cfg_wdata[16+:TDEST_BITS];
                 end
                 5'h01: begin
                    ch_frame_sizes[i*32+:32] <= cfg_wdata;
                    ch_frame_size_variables[i] <= &cfg_wdata;
                 end
                 5'h02: ch_frame_addr_valids[i*FRAME_MAX+:FRAME_MAX] <= cfg_wdata[FRAME0+:FRAME_MAX];
                 5'h04: begin
                    ch_relation_nums[i*3+:3] <= cfg_wdata[0+:3];
                    ch_relations[i*RELATION_NUM*8+:24] <= cfg_wdata[8+:24];
                 end
               endcase
            end
         end
         wire [FRAME_MAX-1:0] w_frame_assigned;
         wire [FRAME_MAX-1:0] w_frame_released;
         assign w_frame_assigned = {{FRAME_MAX-1{1'b0}}, frame_assign_user == i && frame_assign_valid} << frame_assign_frame_id;
         assign w_frame_released = {{FRAME_MAX-1{1'b0}}, frame_release_user == i && frame_release_valid} << frame_release_frame_id;
         wire [FRAME_MAX-1:0] w_frame_used_update = (ch_frames_used[i*FRAME_MAX+:FRAME_MAX] | w_frame_assigned) & ~w_frame_released;
         wire [FRAME_MAX-1:0] w_frame_valid_local = ch_frame_addr_valids[i*FRAME_MAX+:FRAME_MAX];
         always @(posedge clk) begin
            if (~resetn) begin
               ch_frames_used[i*FRAME_MAX+:FRAME_MAX] <= 'd0;
               ch_frame_vacants[i] <= 1'b1;
            end else if (cfg_wvalid && cfg_wch == i && cfg_waddr[4:0] == 5'h03) begin
               ch_frames_used[i*FRAME_MAX+:FRAME_MAX] <= cfg_wdata[FRAME0+:FRAME_MAX];
               ch_frame_vacants[i] <= |(~cfg_wdata[FRAME0+:FRAME_MAX] & ch_frame_addr_valids[i*FRAME_MAX+:FRAME_MAX]) | ~ch_mmapped[i];
            end else begin
               ch_frames_used[i*FRAME_MAX+:FRAME_MAX] <= (ch_frames_used[i*FRAME_MAX+:FRAME_MAX] | w_frame_assigned) & ~w_frame_released;
               ch_frame_vacants[i] <= |(~((ch_frames_used[i*FRAME_MAX+:FRAME_MAX] | w_frame_assigned) & ~w_frame_released) &
                                        ch_frame_addr_valids[i*FRAME_MAX+:FRAME_MAX]) | ~ch_mmapped[i];
            end
         end
      end
   endgenerate

   generate
      if (EXT_RELATION > 0) begin
         for (genvar i=0; i<CH_NUM; i=i+1) begin
            always @(posedge clk) begin
               if (~resetn) begin
                  ch_relations[i*RELATION_NUM*8+24+:32] <= 'd0;
               end else if (cfg_wvalid && cfg_wch == i && cfg_waddr[4:0] == 5'h05) begin
                  ch_relations[i*RELATION_NUM*8+24+:32] <= cfg_wdata;
               end
            end
         end
      end
   endgenerate

   always @(posedge clk) begin
      if (~resetn) begin
         burst_max <= 'd1 << BURST_BITS;
      end else if (cfg_wvalid && cfg_wch == 'd0 && cfg_waddr[4:0] == 5'd6) begin
         burst_max <= cfg_wdata[BURST_BITS:0];
      end
   end

   // address regs
   reg [31:0] ch_frame_mid_addresses[0:CH_NUM*FRAME_MAX_CEIL-1];
   (* mark_debug = "true" *) wire       addr_wen = cfg_wvalid && cfg_waddr[4:0] >= FRAME0;
   (* mark_debug = "true" *) wire       addr_ren = cfg_arvalid && cfg_raddr[4:0] >= FRAME0;

   reg [CTX_ID_BITS+4:0]  addr_read_pos_saved;
   reg                    addr_read_valid_saved;
   reg                    addr_read_data_valid_reg;
   always @(posedge clk) begin
      if (~resetn) begin
         addr_read_valid_saved <= 1'b0;
      end else if ((addr_wen || addr_ren) & addr_read_valid) begin
         addr_read_valid_saved <= 1'b1;
         addr_read_pos_saved <= addr_read_pos;
      end else begin
         addr_read_valid_saved <= addr_read_valid_saved & (addr_wen || addr_ren);
      end
   end
   always @(posedge clk) begin
      if (~resetn) begin
         addr_read_data_valid_reg <= 1'b0;
      end else begin
         addr_read_data_valid_reg <= (addr_read_valid || addr_read_valid_saved) && ~(addr_wen || addr_ren);
      end
   end

   wire [CTX_ID_BITS+4:0] addr_read_pos_merged = addr_ren ? cfg_raddr - FRAME0 :
                          addr_read_valid ? addr_read_pos : addr_read_pos_saved;
   (* mark_debug = "true" *) wire [CTX_ID_BITS+4:0] addr_rw_pos = addr_wen ? cfg_waddr[CTX_ID_BITS+4:0] - FRAME0 : addr_read_pos_merged;

   reg [31:0]             addr_read_data_reg;
   always @(posedge clk) begin
      if (addr_wen) ch_frame_mid_addresses[addr_rw_pos] <= cfg_wdata;
      addr_read_data_reg <= ch_frame_mid_addresses[addr_rw_pos];
   end
   assign addr_read_data_valid = addr_read_data_valid_reg;
   assign addr_read_data = {20'd0, addr_read_data_reg, 12'd0};

   // read regs
   wire w_ch_valid = ch_valids >> cfg_rch;
   wire w_ch_mmapped = ch_mmapped >> cfg_rch;
   wire w_disable_frame_out_signal = disable_frame_out_signals >> cfg_rch;
   wire [TDEST_BITS-1:0] w_ch_tdest;
   wire [31:0]           w_ch_frame_size = ch_frame_sizes >> {cfg_rch, 5'd0};
   wire [FRAME_MAX-1:0]  w_ch_frame_addr_valid = ch_frame_addr_valids >> (cfg_rch * FRAME_MAX);
   wire [FRAME_MAX-1:0]  w_ch_frame_used = ch_frames_used >> (cfg_rch * FRAME_MAX);
   wire [2:0]            w_ch_relation_num = ch_relation_nums >> (cfg_rch * 3);
   wire [RELATION_NUM*8-1:0] w_ch_relation_chs = ch_relations >> (cfg_rch * RELATION_NUM*8);
   wire [RELATION_NUM*8+8-1:0] w_ch_relations = {w_ch_relation_chs, 5'd0, w_ch_relation_num};
   wire [BURST_BITS:0]         w_burst_max = ~|cfg_rch ? burst_max : {BURST_BITS+1{1'b0}};

   assign w_ch_tdest = ch_dests >> (cfg_rch * TDEST_BITS);

   reg [31:0]            cfg_rdata_reg;
   reg                   cfg_rvalid_reg;
   reg                   cfg_arvalid_reg;
   always @(posedge clk) begin
      if (~resetn) begin
         cfg_rdata_reg <= 'd0;
         cfg_rvalid_reg <= 1'b0;
         cfg_arvalid_reg <= 1'b0;
      end else begin
         if (cfg_arvalid & cfg_raddr[4:0] >= FRAME0) begin
            cfg_arvalid_reg <= 1'b1;
         end else begin
            cfg_arvalid_reg <= 1'b0;
         end
         if (cfg_arvalid & cfg_raddr[4:0] < FRAME0) begin
            cfg_rvalid_reg <= 1'b1;
            cfg_rdata_reg <= cfg_raddr[4:0] == 5'h0 ? {{16-TDEST_BITS{1'b0}}, w_ch_tdest,
                                                       7'd0, w_disable_frame_out_signal, 3'd0, w_ch_mmapped, 3'd0, w_ch_valid} :
                             cfg_raddr[4:0] == 5'h1 ? w_ch_frame_size :
                             cfg_raddr[4:0] == 5'h2 ? {w_ch_frame_addr_valid, {FRAME0{1'b0}}} :
                             cfg_raddr[4:0] == 5'h3 ? {w_ch_frame_used, {FRAME0{1'b0}}} :
                             cfg_raddr[4:0] == 5'h4 ? w_ch_relations[31:0] :
                             cfg_raddr[4:0] == 5'h5 ? w_ch_relations >> 32 :
                             cfg_raddr[4:0] == 5'h6 ? {{31-BURST_BITS{1'b0}}, w_burst_max} : 'd0;
         end else if (cfg_arvalid_reg) begin
            cfg_rvalid_reg <= 1'b1;
            cfg_rdata_reg <= addr_read_data_reg;
            cfg_arvalid_reg <= 1'b0;
         end else begin
            cfg_rvalid_reg <= 1'b0;
         end
      end
   end
   assign cfg_rdata = cfg_rdata_reg;
   assign cfg_rvalid = cfg_rvalid_reg;

endmodule

module frame_info #(
    parameter CTX_ID_BITS = 4
    ) (
    input [31:0]                         frame_info_tdata,
    input [CTX_ID_BITS-1:0]              frame_info_tuser,
    input                                frame_info_tvalid,
    output                               frame_info_tready,

    input [32*(1<<CTX_ID_BITS)-1:0]      ch_frame_sizes,
    input [(1<<CTX_ID_BITS)-1:0]         ch_mmapped,

    input [(1<<CTX_ID_BITS)-1:0]         frame_info_consumes,
    output reg [(1<<CTX_ID_BITS)-1:0]    frame_info_valids,
    output reg [32*(1<<CTX_ID_BITS)-1:0] frame_info_sizes,

    input                                clk,
    input                                resetn
    );

   localparam CH_NUM = 1 << CTX_ID_BITS;

   wire [31:0]         w_frame_info_size;
   wire [CTX_ID_BITS-1:0] w_frame_info_ch;
   wire                   w_frame_info_valid;
   wire                   w_frame_info_ready;
   wire [31:0]            w_frame_info_size2;
   wire [CTX_ID_BITS-1:0] w_frame_info_ch2;
   wire                   w_frame_info_valid2;
   wire                   w_frame_info_ready2;

   axis_buf_ooo #(
       .DW ( 32 + CTX_ID_BITS )
   ) frame_info_buf (
       .idata ( {frame_info_tuser, frame_info_tdata} ),
       .ivalid ( frame_info_tvalid ),
       .iready ( frame_info_tready ),
       .odata ( {w_frame_info_ch, w_frame_info_size} ),
       .ovalid ( w_frame_info_valid ),
       .oready ( w_frame_info_ready ),
       .odata2 ( {w_frame_info_ch2, w_frame_info_size2} ),
       .ovalid2 ( w_frame_info_valid2 ),
       .oready2 ( w_frame_info_ready2 ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         wire [31:0] cur_frame_size;
         wire [31:0] cur_frame_size2;
         always @(posedge clk) begin
            if (~resetn) begin
               frame_info_valids[i] <= 1'b0;
            end else if (w_frame_info_valid & w_frame_info_ready & w_frame_info_ch == i) begin
               frame_info_valids[i] <= 1'b1;
               frame_info_sizes[i*32+:32] <= cur_frame_size;
            end else if (w_frame_info_valid2 & w_frame_info_ready2 & w_frame_info_ch2 == i) begin
               frame_info_valids[i] <= 1'b1;
               frame_info_sizes[i*32+:32] <= cur_frame_size2;
            end else if (frame_info_consumes[i]) begin
               frame_info_valids[i] <= 1'b0;
            end
         end
         assign cur_frame_size = (~ch_mmapped[i] && ~|ch_frame_sizes[32*i+:32]) ||
                                 w_frame_info_size < ch_frame_sizes[32*i+:32] ? w_frame_info_size : ch_frame_sizes[32*i+:32];
         assign cur_frame_size2 = (~ch_mmapped[i] && ~|ch_frame_sizes[32*i+:32]) ||
                                  w_frame_info_size2 < ch_frame_sizes[32*i+:32] ? w_frame_info_size2 : ch_frame_sizes[32*i+:32];
      end
   endgenerate
   assign w_frame_info_ready = ~frame_info_valids >> w_frame_info_ch;
   assign w_frame_info_ready2 = ~w_frame_info_ready & (~frame_info_valids >> w_frame_info_ch2);

endmodule

module frame_header_ch_generate #(
    parameter CTX_ID_BITS = 4,
    parameter ENABLE_BUSY_ = 0,
    parameter ENABLE_BUSY = 0
    ) (
    input [(1<<CTX_ID_BITS)-1:0] frame_info_valids,
    input                        frame_header_gen_ch_reset,

    output reg [CTX_ID_BITS-1:0] frame_header_gen_ch,
    output reg                   frame_header_gen_ch_valid,

    input                        clk,
    input                        resetn
    );

   localparam CH_BITS = CTX_ID_BITS > 4 ? CTX_ID_BITS : 4;
   localparam CHS = 1 << CH_BITS;
   localparam CH_NUM = 1 << CTX_ID_BITS;

   reg [CH_BITS-1:0]     frame_header_gen_ch_search_pos;
   reg [3:0]             cur_frame_info_valids;
   reg                   frame_header_gen_busy;
   wire [CH_BITS-1:0]    w_frame_header_gen_ch_candidate;
   wire                  w_cur_frame_info_valid;

   wire [3:0]            frame_info_valids_rot;
   generate
      if (CH_BITS > CTX_ID_BITS) begin
         assign frame_info_valids_rot = {{CHS-CH_NUM{1'b0}}, frame_info_valids, {CHS-CH_NUM{1'b0}}, frame_info_valids} >> frame_header_gen_ch_search_pos;
      end else begin
         assign frame_info_valids_rot = {frame_info_valids, frame_info_valids} >> frame_header_gen_ch_search_pos;
      end
   endgenerate

   assign w_frame_header_gen_ch_candidate = frame_info_valids_rot[0] ? frame_header_gen_ch_search_pos :
                                            frame_info_valids_rot[1] ? frame_header_gen_ch_search_pos + 1'b1 :
                                            frame_info_valids_rot[2] ? frame_header_gen_ch_search_pos + 2'd2 :
                                            frame_header_gen_ch_search_pos + 2'd3;
   assign w_cur_frame_info_valid = |frame_info_valids_rot;

   always @(posedge clk) begin
      if (~resetn) begin
         frame_header_gen_ch <= 'd0;
         frame_header_gen_ch_valid <= 1'b0;
         frame_header_gen_ch_search_pos <= 'd0;
      end else begin
         if (w_cur_frame_info_valid) begin
            frame_header_gen_ch <= w_frame_header_gen_ch_candidate[CTX_ID_BITS-1:0];
            frame_header_gen_ch_search_pos <= w_frame_header_gen_ch_candidate + 1'b1;
         end else begin
            frame_header_gen_ch_search_pos <= frame_header_gen_ch_search_pos + 3'd4;
         end
         frame_header_gen_ch_valid <= w_cur_frame_info_valid;
      end
   end

endmodule

module axis_buf_ooo #(
    parameter DW = 32
    ) (
    input [DW-1:0]  idata,
    input           ivalid,
    output          iready,
    output [DW-1:0] odata,
    output          ovalid,
    input           oready,
    output [DW-1:0] odata2,
    output          ovalid2,
    input           oready2,
    input           clk,
    input           resetn
    );

   reg [DW*2-1:0]   data_saved;
   reg [1:0]        valid_saved;

   always @(posedge clk) begin
      if (~resetn) begin
         data_saved <= 'd0;
         valid_saved <= 'd0;
      end else if (ivalid & iready) begin
         if (valid_saved[0] & ~oready) begin
            data_saved[DW+:DW] <= idata;
            valid_saved[1] <= 1'b1;
         end else begin
            data_saved[0+:DW] <= idata;
            valid_saved[0] <= 1'b1;
         end
      end else if (oready) begin
         data_saved <= data_saved >> DW;
         valid_saved <= valid_saved >> 1;
      end else if (oready2) begin
         valid_saved[1] <= 1'b0;
      end
   end

   assign iready = ~valid_saved[1];
   assign odata = data_saved[0+:DW];
   assign ovalid = valid_saved[0];
   assign odata2 = data_saved[DW+:DW];
   assign ovalid2 = valid_saved[1];

endmodule

module frame_header_generate #(
    parameter CTX_ID_BITS = 4,
    parameter TDEST_BITS = 4,
    parameter TDEST_ENABLE = 1,
    parameter FRAME_MAX = 24,
    parameter FRAME_MAX_LOG = 5,
    parameter CREDIT_MAX = 4
    ) (
    input                                 frame_header_generate,
    input [CTX_ID_BITS-1:0]               frame_header_gen_ch,
    input [(1<<CTX_ID_BITS)-1:0]          frame_info_valids,
    input [(32<<CTX_ID_BITS)-1:0]         frame_info_sizes,
    input [(1<<CTX_ID_BITS)-1:0]          ch_valids,
    input [(TDEST_BITS<<CTX_ID_BITS)-1:0] ch_dests,
    input [(1<<CTX_ID_BITS)-1:0]          ch_mmapped,
    input [(FRAME_MAX<<CTX_ID_BITS)-1:0]  ch_frame_addr_valids,
    input [(FRAME_MAX<<CTX_ID_BITS)-1:0]  ch_frames_used,
    input [(1<<CTX_ID_BITS)-1:0]          disable_frame_out_signals,
    output                                frame_header_generate_ready,
    input                                 frame_header_consume_valid,
    input [CTX_ID_BITS-1:0]               frame_header_consume_ch,

    output [CTX_ID_BITS+4:0]              addr_read_pos,
    output                                addr_read_valid,
    input [63:0]                          addr_read_data,
    input                                 addr_read_data_valid,

    output reg [CTX_ID_BITS-1:0]          frame_header_ch_reg,
    output [TDEST_BITS-1:0]               frame_header_dest_reg,
    output reg [FRAME_MAX_LOG-1:0]        frame_header_idx_reg,
    output reg [31:0]                     frame_header_size_reg,
    output reg [63:0]                     frame_header_addr,
    output                                frame_header_out_valid,
    input                                 frame_header_out_ready,

    output reg                            frame_header_idx_found,

    input                                 clk,
    input                                 resetn
    );

   localparam CH_NUM = 1 << CTX_ID_BITS;

   reg                   frame_header_valid_reg;
   reg [FRAME_MAX-1:0]   frame_header_frame_valid;
   reg [FRAME_MAX-1:0]   frame_header_frame_used;
   reg                   frame_header_mmapped;
   reg                   frame_header_idx_valid;
   reg [CTX_ID_BITS+4:0] frame_header_raddr;
   reg                   frame_header_raddr_valid;
   reg                   frame_header_raddr_data_valid;
   wire                  w_frame_addr_found;
   wire                  cur_ch_mmapped = ch_mmapped >> frame_header_gen_ch;
   wire                  cur_ch_invalid = (~ch_valids >> frame_header_ch_reg) & frame_header_valid_reg;

   always @(posedge clk) begin
      if (~resetn || cur_ch_invalid) begin
         frame_header_valid_reg <= 1'b0;
         frame_header_idx_valid <= 1'b0;
         frame_header_idx_found <= 1'b0;
         frame_header_mmapped <= 'd0;
         frame_header_idx_reg <= 'd0;
         frame_header_frame_valid <= 'd0;
         frame_header_frame_used <= 'd0;
         frame_header_raddr_valid <= 1'b0;
         frame_header_raddr_data_valid <= 1'b0;
      end else if (frame_header_generate && frame_header_generate_ready) begin
         frame_header_valid_reg <= frame_info_valids >> frame_header_gen_ch;
         frame_header_ch_reg <= frame_header_gen_ch;
         frame_header_size_reg <= frame_info_sizes >> {frame_header_gen_ch, 5'd0};
         frame_header_idx_reg <= 'd0;
         frame_header_idx_valid <= 1'b0;
         frame_header_idx_found <= 1'b0;
         frame_header_mmapped <= cur_ch_mmapped;
         frame_header_frame_valid <= ch_frame_addr_valids >> (frame_header_gen_ch * FRAME_MAX);
         frame_header_frame_used <= ch_frames_used >> (frame_header_gen_ch * FRAME_MAX);
         frame_header_raddr_data_valid <= 1'b0;
         frame_header_raddr_valid <= 1'b0;
      end else begin
         frame_header_idx_reg <= ~w_frame_addr_found ? frame_header_idx_reg + 1'b1 : frame_header_idx_reg;
         frame_header_idx_valid <= w_frame_addr_found && frame_header_mmapped;
         frame_header_idx_found <= w_frame_addr_found && frame_header_mmapped && ~frame_header_idx_valid;
         frame_header_raddr <= w_frame_addr_found ? {frame_header_ch_reg, frame_header_idx_reg} : frame_header_raddr;
         frame_header_raddr_valid <= w_frame_addr_found & frame_header_mmapped && ~frame_header_idx_valid;
         frame_header_raddr_data_valid <= addr_read_data_valid ||
                                          (frame_header_raddr_data_valid && ~(frame_header_out_valid && frame_header_out_ready));
         frame_header_addr <= addr_read_data_valid ? addr_read_data : frame_header_addr;
         frame_header_valid_reg <= frame_header_valid_reg & ~(frame_header_out_valid && frame_header_out_ready);
      end
   end

   generate
      if (TDEST_ENABLE > 0) begin
         reg [TDEST_BITS-1:0] frame_header_dest;
         always @(posedge clk) begin
            if (resetn && frame_header_generate && ~frame_header_valid_reg) begin
               frame_header_dest <= ch_dests >> (frame_header_gen_ch * TDEST_BITS);
            end
         end
         assign frame_header_dest_reg = frame_header_dest;
      end else begin
         assign frame_header_dest_reg = 'd0;
      end
   endgenerate

   assign frame_header_out_valid = frame_header_valid_reg & (~frame_header_mmapped || frame_header_raddr_data_valid) & frame_header_out_ready;
   assign w_frame_addr_found = (frame_header_frame_valid & ~frame_header_frame_used) >> frame_header_idx_reg;
   assign addr_read_pos = frame_header_raddr;
   assign addr_read_valid = frame_header_raddr_valid;

   reg [CH_NUM*4-1:0] frame_header_credits;
   reg [CH_NUM-1:0]   frame_header_credit_exists;
   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         always @(posedge clk) begin
            if (~resetn || ~ch_valids[i]) begin
               frame_header_credits[i*4+:4] <= CREDIT_MAX;
               frame_header_credit_exists[i] <= 1'b1;
            end else begin
               frame_header_credits[i*4+:4] <= frame_header_credits[i*4+:4]
                                               - (frame_header_generate && frame_header_generate_ready && frame_header_gen_ch == i)
                                               + (frame_header_consume_valid && frame_header_consume_ch == i);
               frame_header_credit_exists[i] <= frame_header_credits[i*4+:4] > 4'd1 ||
                                                (|frame_header_credits[i*4+:4] && (~frame_header_generate || ~frame_header_generate_ready)) ||
                                                disable_frame_out_signals[i];
            end
         end
      end
   endgenerate

   assign frame_header_generate_ready = ~frame_header_valid_reg & (frame_header_credit_exists >> frame_header_gen_ch);

endmodule
