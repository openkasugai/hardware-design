/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module dm_ctrl #(
    parameter DW = 512,
    parameter CTX_ID_BITS = 5,
    parameter HEADER_FIFO_DL = 2,
    parameter HEADER_OUT_FIFO_DL = 4,
    parameter TDEST_BITS = 4,
    parameter DM_STS_FIFO_DL = 5,
    parameter ENABLE_FRAME_END = 0,
    parameter ODEST_BITS = 4,
    parameter DM_ADDR_BITS = 40 // ceil to multiple of 8
    ) (
    output [DM_ADDR_BITS+39:0]                 dm_cmd_tdata,
    output reg                                 dm_cmd_tvalid,
    input                                      dm_cmd_tready,
    input [7:0]                                dm_sts_tdata,
    input                                      dm_sts_tvalid,
    output                                     dm_sts_tready,

    input [127+TDEST_BITS:0]                   frame_header_tdata, // [63:0] frame addr, [95:64] frame size, [103:96] frame id, [104+:ODEST_BITS] odest, [128+:] idest
    input [CTX_ID_BITS-1:0]                    frame_header_tuser,
    input                                      frame_header_tvalid,
    output                                     frame_header_tready,

    output reg [(1<<CTX_ID_BITS)-1:0]          header_active_valids,
    output reg [(32<<CTX_ID_BITS)-1:0]         header_active_sizes,
    output reg [(ODEST_BITS<<CTX_ID_BITS)-1:0] header_active_odests,
    output reg [(1<<CTX_ID_BITS)-1:0]          header_active_finishes,

    input [CTX_ID_BITS-1:0]                    cmd_out_ch,
    input [15:0]                               cmd_out_size,
    input                                      cmd_out_valid,
    input                                      cmd_out_fifo_ready,
    output                                     cmd_out_ready,

    output reg [127:0]                         frame_header_consume_tdata,
    output reg [CTX_ID_BITS-1:0]               frame_header_consume_tuser,
    output reg                                 frame_header_consume_tvalid,
    input                                      frame_header_consume_tready,

    output [127+TDEST_BITS:0]                  header_out_data, // [63:0] frame addr, [95:64] frame size, [103:96] frame id, [104+:ODEST_BITS] odest, [128+:] idest
    output [CTX_ID_BITS-1:0]                   header_out_user,
    output                                     header_out_valid,
    input                                      header_out_ready,

    output [3:0]                               errors,
    output reg [(1<<CTX_ID_BITS)-1:0]          underflows,

    input                                      clk,
    input                                      resetn
    );

   localparam CH_NUM = 1 << CTX_ID_BITS;

   wire [CTX_ID_BITS-1:0]    header_rch;
   wire                      header_ren;
   wire                      header_start;
   wire                      header_rready;
   wire [127+TDEST_BITS:0]   header_rdata;
   wire [CTX_ID_BITS-1:0]    header_ruser;
   wire                      header_rlast;
   wire [CH_NUM-1:0]         header_valids;

   mc_fifo #(
       .DW ( 128+TDEST_BITS ),
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .FIFO_DL ( HEADER_FIFO_DL )
   ) header_fifo (
       .i_data ( frame_header_tdata ),
       .i_user ( frame_header_tuser ),
       .i_valid ( frame_header_tvalid ),
       .i_ready ( frame_header_tready ),
       .read_user ( header_rch ),
       .read_last ( header_ren ),
       .read_valid ( header_ren || header_start ),
       .read_ready ( header_rready ),
       .o_data ( header_rdata ),
       .o_user ( header_ruser ),
       .o_last ( header_rlast ),
       .o_valid ( header_rvalid ),
       .fulls (  ),
       .valids ( header_valids ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   wire header_out_fifo_ready;
   reg [64*CH_NUM-1:0]   header_active_addrs;

   reg [CTX_ID_BITS-1:0] fifo_check_ch;
   always @(posedge clk) begin
      if (~resetn) begin
         fifo_check_ch <= 'd0;
      end else if (~header_ren && header_rready) begin
         fifo_check_ch <= fifo_check_ch + 1'b1;
      end
   end
   wire cur_header_active_valid = header_active_valids >> fifo_check_ch;
   wire cur_header_active_finish = header_active_finishes >> fifo_check_ch;
   wire fifo_check_valid = header_valids >> fifo_check_ch;
   assign header_start = ~cur_header_active_valid && fifo_check_valid &&
                         (~header_rvalid || header_rlast) && (~frame_header_consume_tvalid || frame_header_consume_tready);
   assign header_ren = cur_header_active_valid && cur_header_active_finish && fifo_check_valid && header_out_fifo_ready;
   assign header_rch = fifo_check_ch;

   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         wire cmd_out_last = header_active_sizes[i*32+:32] <= cmd_out_size;
         always @(posedge clk) begin
            if (~resetn) begin
               header_active_addrs[i*64+:64] <= 'd0;
               header_active_sizes[i*32+:32] <= 'd0;
               header_active_odests[i*ODEST_BITS+:ODEST_BITS] <= 'd0;
               header_active_valids[i] <= 1'b0;
               header_active_finishes[i] <= 1'b0;
               underflows[i] <= 1'b0;
            end else if (header_rvalid && ~header_rlast && header_ruser == i) begin
               header_active_addrs[i*64+:64] <= header_rdata[63:0];
               header_active_sizes[i*32+:32] <= header_rdata[95:64];
               header_active_odests[i*ODEST_BITS+:ODEST_BITS] <= header_rdata[104+:ODEST_BITS];
               header_active_valids[i] <= 1'b1;
               header_active_finishes[i] <= 1'b0;
               underflows[i] <= 1'b0;
            end else if (cmd_out_valid && cmd_out_ready && cmd_out_ch == i) begin
               header_active_addrs[i*64+:32] <= header_active_addrs[i*64+:32] + cmd_out_size;
               header_active_sizes[i*32+:32] <= header_active_sizes[i*32+:32] - cmd_out_size;
               header_active_finishes[i] <= cmd_out_last;
               underflows[i] <= header_active_sizes[i*32+:32] < cmd_out_size || underflows[i];
            end else if (header_ren && header_rready && header_rch == i) begin
               header_active_valids[i] <= 1'b0;
            end
         end
      end
   endgenerate
   always @(posedge clk) begin
      if (~resetn) begin
         frame_header_consume_tdata <= 'd0;
         frame_header_consume_tuser <= 'd0;
         frame_header_consume_tvalid <= 1'b0;
      end else if (header_rvalid && ~header_rlast) begin
         frame_header_consume_tdata <= header_rdata;
         frame_header_consume_tuser <= header_ruser;
         frame_header_consume_tvalid <= header_rvalid;
      end else begin
         frame_header_consume_tvalid <= frame_header_consume_tvalid & ~frame_header_consume_tready;
      end
   end

   wire header_out_local_valid, header_out_local_ready;
   fifo #(
       .DW ( 128 + TDEST_BITS + CTX_ID_BITS ),
       .DL ( HEADER_OUT_FIFO_DL )
   ) header_out_fifo (
       .idata ( {header_ruser, header_rdata} ),
       .ivalid ( header_rvalid & header_rlast ),
       .iready ( header_out_fifo_ready ),
       .odata ( {header_out_user, header_out_data} ),
       .ovalid ( header_out_local_valid ),
       .oready ( header_out_local_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   wire [31:0] cur_active_size = header_active_sizes >> {cmd_out_ch, 5'd0};
   wire [CTX_ID_BITS-1:0] dm_stat_ch;
   wire                   dm_stat_last;
   wire                   dm_stat_local_valid;
   wire                   dm_stat_local_ready;
   wire                   cmd_out_local_valid;
   wire                   cmd_out_local_ready;
   wire                   cmd_out_last = cur_active_size <= cmd_out_size;
   fifo #(
       .DW ( CTX_ID_BITS + 1 ),
       .DL ( DM_STS_FIFO_DL )
   ) dm_stat_fifo (
       .idata ( {cmd_out_last, cmd_out_ch} ),
       .ivalid ( cmd_out_local_valid ),
       .iready ( cmd_out_local_ready ),
       .odata ( {dm_stat_last, dm_stat_ch} ),
       .ovalid ( dm_stat_local_valid ),
       .oready ( dm_stat_local_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   reg  header_out_enable;
   always @(posedge clk) begin
      if (~resetn) begin
         header_out_enable <= 1'b0;
      end else begin
         header_out_enable <= (dm_stat_local_valid && dm_stat_local_ready && dm_stat_last) ||
                              (header_out_enable && (~header_out_local_valid || ~header_out_ready));
      end
   end

   reg [DM_ADDR_BITS-1:0] dm_cmd_saddr;
   reg [15:0]             dm_cmd_size;
   reg                    dm_cmd_last;
   always @(posedge clk) begin
      if (~resetn) begin
         dm_cmd_saddr <= 'd0;
         dm_cmd_size <= 'd0;
         dm_cmd_tvalid <= 1'b0;
      end else if (cmd_out_valid & cmd_out_ready) begin
         dm_cmd_saddr <= header_active_addrs >> {cmd_out_ch, 6'd0};
         dm_cmd_size <= cmd_out_size;
         dm_cmd_tvalid <= 1'b1;
      end else begin
         dm_cmd_tvalid <= dm_cmd_tvalid & ~dm_cmd_tready;
      end
   end
   generate
      if (ENABLE_FRAME_END > 0) begin
         always @(posedge clk) begin
            if (~resetn) begin
               dm_cmd_last <= 1'b0;
            end else if (cmd_out_valid & cmd_out_ready) begin
               dm_cmd_last <= cmd_out_last;
            end
         end
      end
   endgenerate
   assign cmd_out_ready = ~dm_cmd_tvalid & (~header_active_finishes >> cmd_out_ch) & cmd_out_local_ready & cmd_out_fifo_ready;

   generate
      if (ENABLE_FRAME_END > 0) begin
         assign dm_cmd_tdata = {8'd0, dm_cmd_saddr, 1'b0, dm_cmd_last, 6'd0, 1'b1, 7'd0, dm_cmd_size};
      end else begin
         assign dm_cmd_tdata = {8'd0, dm_cmd_saddr, 1'b0, 1'b0, 6'd0, 1'b1, 7'd0, dm_cmd_size};
      end
   endgenerate
   assign cmd_out_local_valid = cmd_out_valid & cmd_out_ready;

   assign dm_stat_local_ready = dm_sts_tvalid && dm_sts_tready;
   assign dm_sts_tready = dm_stat_local_valid && ~header_out_enable && (~header_out_valid || header_out_ready);
   assign header_out_local_ready = header_out_valid && header_out_ready;
   assign header_out_valid = header_out_local_valid && header_out_enable;

   assign errors = {|underflows, dm_sts_tvalid && dm_sts_tready && |(dm_sts_tdata[7:4] ^ 4'h8),
                    header_rvalid & header_rlast & ~header_out_fifo_ready, ~cmd_out_local_ready && cmd_out_local_valid};

endmodule
