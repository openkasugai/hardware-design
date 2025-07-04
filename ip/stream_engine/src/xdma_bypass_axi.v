/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module xdma_bypass_axi #(
    parameter CH_NUM_LOG = 3,
    parameter DW_LOG = 9,
    parameter QEW_LOG = 5,
    parameter QUEUE_DL = 3,
    parameter VP_MAP_NUM_LOG = 5,
    parameter [39:0] D2D_AXI_BASE = 40'h0,
    parameter [31:0] D2D_AXI_RANGE = 32'h4000_0000 // 1GB
    ) (
    input [63:0]                 axi_araddr,
    input [1:0]                  axi_arburst,
    input [3:0]                  axi_arcache,
    input [3:0]                  axi_arid,
    input [7:0]                  axi_arlen,
    input                        axi_arlock,
    input [2:0]                  axi_arprot,
    input [2:0]                  axi_arsize,
    input                        axi_arvalid,
    output                       axi_arready,
    output [(1<<DW_LOG)-1:0]     axi_rdata,
    output [3:0]                 axi_rid,
    output [1:0]                 axi_rresp,
    output                       axi_rlast,
    output                       axi_rvalid,
    input                        axi_rready,
    input [63:0]                 axi_awaddr,
    input [1:0]                  axi_awburst,
    input [3:0]                  axi_awcache,
    input [3:0]                  axi_awid,
    input [7:0]                  axi_awlen,
    input                        axi_awlock,
    input [2:0]                  axi_awprot,
    input [2:0]                  axi_awsize,
    input                        axi_awvalid,
    output                       axi_awready,
    input [(1<<DW_LOG)-1:0]      axi_wdata,
    input [(1<<(DW_LOG-3))-1:0]  axi_wstrb,
    input [3:0]                  axi_wid,
    input                        axi_wlast,
    input                        axi_wvalid,
    output                       axi_wready,
    output reg [3:0]             axi_bid,
    output [1:0]                 axi_bresp,
    output reg                   axi_bvalid,
    input                        axi_bready,

    output [(1<<DW_LOG)-1:0]     axis_tdata,
    output [(1<<(DW_LOG-3))-1:0] axis_tkeep,
    output [CH_NUM_LOG-1:0]      axis_tuser,
    output                       axis_tlast,
    output                       axis_eof,
    output                       axis_tvalid,
    input                        axis_tready,

    output reg [15:0]            reg_araddr,
    output reg                   reg_arvalid,
    input                        reg_arready,
    input [31:0]                 reg_rdata,
    input [1:0]                  reg_rresp,
    input                        reg_rvalid,
    output                       reg_rready,
    output reg [15:0]            reg_awaddr,
    output reg                   reg_awvalid,
    input                        reg_awready,
    output reg [31:0]            reg_wdata,
    output reg                   reg_wvalid,
    input                        reg_wready,
    input [1:0]                  reg_bresp,
    input                        reg_bvalid,
    output                       reg_bready,

    output reg [CH_NUM_LOG-1:0]  stream_queue_read_ch,
    output reg [QUEUE_DL-1:0]    stream_queue_read_entry,
    output reg                   stream_queue_read_valid,
    input [(8<<QEW_LOG)-1:0]     stream_queue_read_data,
    input                        stream_queue_read_data_valid,

    input                        clk,
    input                        resetn
    );

   // stream data write
   // queue element read
   // queue head/tail read/write
   // queue element(size only) write

   localparam DW = 1 << DW_LOG;
   localparam KW_LOG = DW_LOG - 3;
   localparam KW = 1 << KW_LOG;
   localparam QEW = 1 << QEW_LOG;
   localparam QEWB = QEW * 8;
   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam VPMAP_CH_AGGREGATE = CH_NUM_LOG + VP_MAP_NUM_LOG + 5 > 15 ? 1 : 0;
   localparam VPMAP_MAX = VPMAP_CH_AGGREGATE ? 4 << (VP_MAP_NUM_LOG + 3) : 4 << (CH_NUM_LOG + VP_MAP_NUM_LOG + 3);
   localparam CTRL_MAX = VPMAP_MAX + (4 << (CH_NUM_LOG + 4));
   localparam CTRL_END = CTRL_MAX + 4 * 4;
   localparam QUEUE_DEPTH = 1 << QUEUE_DL;
   localparam QUEUE_BASE = (CTRL_END + 63) & ~63;
   localparam QUEUE_HEAD_TAIL = QUEUE_BASE + QEW * CH_NUM * QUEUE_DEPTH * 2; // (QEW * QUEUE_DEPTH) x ch_num x(req,cpl)
   localparam D2D_AXI_RANGE_BITS = $clog2(D2D_AXI_RANGE);

   // axi write addr
   reg [127:0]                  axi_waddrs;
   reg [31:0]                   axi_wsizes;
   reg [7:0]                    axi_waids;
   reg [1:0]                    axi_wavalids;
   wire                         axi_waready;
   always @(posedge clk) begin
      if (~resetn) begin
         axi_wavalids <= 'd0;
      end else if (axi_awvalid & axi_awready) begin
         if (axi_wavalids[0] & ~axi_waready) begin
            axi_waddrs[64+:64] <= axi_awaddr;
            if (axi_awsize == KW_LOG) begin
               axi_wsizes[16+:16] <= ({8'd0, axi_awlen} + 1'b1) << axi_awsize;
            end else begin
               axi_wsizes[16+:16] <= (({8'd0, axi_awlen} + 1'b1) << axi_awsize) + axi_awaddr[KW_LOG-1:0];
            end
            axi_waids[4+:4] <= axi_awid;
            axi_wavalids[1] <= 1'b1;
         end else begin
            axi_waddrs[0+:64] <= axi_awaddr;
            if (axi_awsize == KW_LOG) begin
               axi_wsizes[0+:16] <= ({8'd0, axi_awlen} + 1'b1) << axi_awsize;
            end else begin
               axi_wsizes[0+:16] <= (({8'd0, axi_awlen} + 1'b1) << axi_awsize) + axi_awaddr[KW_LOG-1:0];
            end
            axi_waids[0+:4] <= axi_awid;
            axi_wavalids[0] <= 1'b1;
         end
      end else if (axi_waready) begin
         axi_waddrs <= axi_waddrs >> 64;
         axi_wsizes <= axi_wsizes >> 16;
         axi_waids <= axi_waids >> 4;
         axi_wavalids <= axi_wavalids >> 1;
      end
   end
   assign axi_awready = ~axi_wavalids[1];

   // write ctrl
   reg [CH_NUM_LOG-1:0] write_ch;
   reg                  write_is_ctrl;
   reg [15:0]           write_ctrl_addr;
   reg [15:0]           write_size;
   reg                  write_info_valid;
   reg [3:0]            write_id;
   reg                  bvalid_save;
   wire                 axi_wdready;
   wire                 axi_wdvalid;
   always @(posedge clk) begin
      if (~resetn) begin
         write_is_ctrl <= 1'b0;
         write_info_valid <= 1'b0;
      end else if (axi_wavalids[0] && axi_waready && ~bvalid_save) begin
         write_ch <= axi_waddrs[D2D_AXI_RANGE_BITS+:CH_NUM_LOG+1] - 1'b1;
         write_is_ctrl <= ~|axi_waddrs[D2D_AXI_RANGE_BITS+:CH_NUM_LOG+1];
         write_ctrl_addr <= {axi_waddrs[15:KW_LOG], {KW_LOG{1'b0}}};
         write_size <= axi_wsizes;
         write_id <= axi_waids;
         write_info_valid <= 1'b1;
      end else if (axi_wdvalid & axi_wdready) begin
         if (write_size <= KW) begin
            write_info_valid <= 1'b0;
         end else begin
            write_size <= write_size - KW;
         end
      end
   end
   assign axi_waready = ~write_info_valid && ~bvalid_save;

   // axi write response
   reg [3:0] bid_save;
   always @(posedge clk) begin
      if (~resetn) begin
         axi_bvalid <= 1'b0;
         bvalid_save <= 1'b0;
      end else if (axi_wdvalid & axi_wdready && write_size <= KW) begin
         if (axi_bvalid & ~axi_bready) begin
            bvalid_save <= 1'b1;
            bid_save <= write_id;
         end else begin
            axi_bvalid <= 1'b1;
            axi_bid <= write_id;
         end
      end else if (axi_bready) begin
         axi_bvalid <= bvalid_save;
         bvalid_save <= 1'b0;
         axi_bid <= bid_save;
      end
   end
   assign axi_bresp = 2'd0;

   // axi write data
   reg [DW*2-1:0] axi_wdatas;
   reg [KW*2-1:0] axi_wstrbs;
   reg [1:0]      axi_wlasts;
   reg [7:0]      axi_wids;
   reg [1:0]      axi_wvalids;
   always @(posedge clk) begin
      if (~resetn) begin
         axi_wvalids <= 'd0;
      end else if (axi_wvalid & axi_wready) begin
         if (axi_wvalids[0] & ~axi_wdready) begin
            axi_wdatas[DW+:DW] <= axi_wdata;
            axi_wstrbs[KW+:KW] <= axi_wstrb;
            axi_wlasts[1] <= axi_wlast;
            axi_wids[4+:4] <= axi_wid;
            axi_wvalids[1] <= 1'b1;
         end else begin
            axi_wdatas[0+:DW] <= axi_wdata;
            axi_wstrbs[0+:KW] <= axi_wstrb;
            axi_wlasts[0] <= axi_wlast;
            axi_wids[0+:4] <= axi_wid;
            axi_wvalids[0] <= 1'b1;
         end
      end else if (axi_wdready) begin
         axi_wdatas <= axi_wdatas >> DW;
         axi_wstrbs <= axi_wstrbs >> KW;
         axi_wlasts <= axi_wlasts >> 1;
         axi_wids <= axi_wids >> 4;
         axi_wvalids <= axi_wvalids >> 1;
      end
   end
   assign axi_wdvalid = axi_wvalids[0];
   assign axi_wready = ~axi_wvalids[1] && write_info_valid;

   // write to ctrl regs
   reg [KW_LOG:0]   axil_write_addr_ofs;
   wire [3:0]       w_cur_strb = axi_wstrbs >> axil_write_addr_ofs;
   wire [CH_NUM_LOG-1:0] w_ctrl_write_ch = (write_ctrl_addr[15:0] + axil_write_addr_ofs - QUEUE_BASE) >> (QUEUE_DL + QEW_LOG + 1);
   wire                  w_ctrl_write_q = QUEUE_BASE <= write_ctrl_addr[15:0] + axil_write_addr_ofs &&
                         write_ctrl_addr[15:0] + axil_write_addr_ofs < QUEUE_HEAD_TAIL;
   wire                  w_ctrl_write_enable;
   always @(posedge clk) begin
      if (~resetn) begin
         axil_write_addr_ofs <= 'd0;
         reg_awvalid <= 1'b0;
         reg_wvalid <= 1'b0;
      end else begin
         if (axi_wavalids[0] && axi_waready && ~bvalid_save) begin
            axil_write_addr_ofs <= {1'b0, axi_waddrs[KW_LOG-1:0]};
            reg_awvalid <= reg_awvalid & ~reg_awready;
            reg_wvalid <= reg_wvalid & ~reg_wready;
         end else if (~reg_awvalid & ~reg_wvalid) begin
            if (axi_wvalids[0] && write_info_valid && write_is_ctrl && w_ctrl_write_enable) begin
               reg_awvalid <= axil_write_addr_ofs < write_size && &w_cur_strb;
               reg_wvalid <= axil_write_addr_ofs < write_size && &w_cur_strb;
               reg_awaddr <= write_ctrl_addr + axil_write_addr_ofs;
               reg_wdata <= axi_wdatas >> {axil_write_addr_ofs, 3'd0};
               axil_write_addr_ofs <= axil_write_addr_ofs + 3'd4;
            end
         end else begin
            reg_awvalid <= reg_awvalid & ~reg_awready;
            reg_wvalid <= reg_wvalid & ~reg_wready;
         end
         if (axi_wdvalid && axi_wdready && write_is_ctrl) begin
            axil_write_addr_ofs <= 'd0;
         end
      end
   end
   assign reg_bready = 1'b1;
   wire w_ctrl_written = axil_write_addr_ofs >= write_size;
   wire w_ctrl_wdready = w_ctrl_written && write_is_ctrl && write_info_valid;

   reg [32*CH_NUM-1:0] stream_sizes;
   reg [CH_NUM-1:0]    stream_size_valids;
   reg [CH_NUM-1:0]    stream_size_pendings;
   wire [CH_NUM-1:0]   w_stream_size_dones;
   wire [CH_NUM_LOG-1:0] w_stream_size_ch = (reg_awaddr - QUEUE_BASE) >> (QUEUE_DL + QEW_LOG + 1);
   wire                  w_stream_size_is_cpl = (reg_awaddr - QUEUE_BASE) >> (QUEUE_DL + QEW_LOG);
   wire                  w_stream_size_is_lsize = (((reg_awaddr - QUEUE_BASE) & {QEW_LOG{1'b1}}) >> 2) == 'd2;
   wire                  w_stream_queue_write = QUEUE_BASE <= reg_awaddr && reg_awaddr < QUEUE_HEAD_TAIL;
   generate
      for (genvar i=0; i<CH_NUM; i=i+1) begin
         always @(posedge clk) begin
            if (~resetn) begin
               stream_size_valids[i] <= 1'b0;
               stream_size_pendings[i] <= 1'b0;
            end else if (~stream_size_valids[i] && reg_awvalid && ~stream_size_pendings[i] && w_stream_size_ch == i &&
                         w_stream_size_is_cpl && w_stream_size_is_lsize && w_stream_queue_write) begin
               stream_size_valids[i] <= 1'b1;
               stream_sizes[32*i+:32] <= reg_wdata;
               stream_size_pendings[i] <= ~reg_awready;
            end else begin
               stream_size_valids[i] <= stream_size_valids[i] & ~w_stream_size_dones[i];
               stream_size_pendings[i] <= stream_size_pendings[i] & ~reg_awready;
            end
         end
      end
   endgenerate
   assign w_ctrl_write_enable = 1'b1;

   // convert to axis
   reg [DW*2-1:0]         axis_data;
   reg [KW*2-1:0]         axis_keeps;
   reg [CH_NUM_LOG*2-1:0] axis_users;
   reg [1:0]              axis_lasts;
   reg [1:0]              axis_eofs;
   reg [1:0]              axis_valids;
   reg [1:0]              axis_out_valids;

   wire                   w_data_wdready;
   wire                   w_axis_size_valid_0 = stream_size_valids >> axis_users[CH_NUM_LOG-1:0];
   wire                   w_axis_size_valid_1 = stream_size_valids >> axis_users[CH_NUM_LOG+:CH_NUM_LOG];

   always @(posedge clk) begin
      if (~resetn) begin
         axis_valids <= 'd0;
         axis_users <= 'd0;
         axis_out_valids <= 'd0;
      end else if (axi_wvalids[0] && write_info_valid && ~write_is_ctrl && w_data_wdready) begin
         if (~axis_valids[0] || (~axis_valids[1] && axis_out_valids[0] && axis_tready)) begin
            axis_data[0+:DW] <= axi_wdatas[DW-1:0];
            axis_keeps[0+:KW] <= axi_wstrbs[KW-1:0];
            axis_users[0+:CH_NUM_LOG] <= write_ch;
            axis_eofs[0] <= 1'b0;
            axis_lasts[0] <= axi_wlasts[0];
            axis_valids[0] <= 1'b1;
            axis_out_valids[0] <= 1'b0;
         end else if (axis_out_valids[0] && axis_tready) begin
            axis_data <= {axi_wdatas[DW-1:0], axis_data[DW+:DW]};
            axis_keeps <= {axi_wstrbs[KW-1:0], axis_keeps[KW+:KW]};
            axis_users <= {write_ch, axis_users[CH_NUM_LOG+:CH_NUM_LOG]};
            axis_eofs <= {1'b0, axis_eofs[1]};
            axis_lasts <= {axi_wlasts[0], axis_lasts[1]};
            axis_valids <= {1'b1, axis_valids[1]};
            axis_out_valids <= {1'b0, axis_valids[1]};
         end else begin
            axis_data[DW+:DW] <= axi_wdatas[DW-1:0];
            axis_keeps[KW+:KW] <= axi_wstrbs[KW-1:0];
            axis_users[CH_NUM_LOG+:CH_NUM_LOG] <= write_ch;
            axis_eofs[1] <= 1'b0;
            axis_lasts[1] <= axi_wlasts[0];
            axis_valids[1] <= 1'b1;
            axis_out_valids[1] <= 1'b0;
            axis_out_valids[0] <= 1'b1;
         end
      end else begin
         if (axis_out_valids[0] && axis_tready) begin
            axis_data <= axis_data >> DW;
            axis_keeps <= axis_keeps >> KW;
            axis_users <= axis_users >> CH_NUM_LOG;
            axis_lasts <= axis_lasts >> 1;
            axis_eofs <= (axis_eofs >> 1) | {1'b0, w_axis_size_valid_1 && axis_valids[1] && axis_lasts[1]};
            axis_valids <= axis_valids >> 1;
            axis_out_valids <= (axis_out_valids >> 1) | {1'b0, w_axis_size_valid_1 && axis_valids[1]};
         end else begin
            axis_eofs <= axis_eofs | ({w_axis_size_valid_1, w_axis_size_valid_0} & axis_valids & axis_lasts);
            axis_out_valids <= axis_out_valids | {w_axis_size_valid_1 && axis_valids[1], w_axis_size_valid_0 && axis_valids[0]};
         end
      end
   end
   assign w_data_wdready = (~axis_valids[1] || (axis_out_valids[0] && axis_tready)) && ~write_is_ctrl && write_info_valid;
   assign w_stream_size_dones = ({{CH_NUM_LOG-1{1'b0}}, ~axis_out_valids[0] && axis_valids[0] && axis_lasts[0]} << axis_users[0+:CH_NUM_LOG]) |
                                ({{CH_NUM_LOG-1{1'b0}}, ~axis_out_valids[1] && axis_valids[1] && axis_lasts[1]} << axis_users[CH_NUM_LOG+:CH_NUM_LOG]);
   wire [CH_NUM-1:0] w_stream_size_dones_mod = w_stream_size_dones & stream_size_valids;

   assign axis_tdata = axis_data;
   assign axis_tkeep = axis_keeps;
   assign axis_tuser = axis_users;
   assign axis_tlast = axis_lasts;
   assign axis_eof = axis_eofs;
   assign axis_tvalid = axis_out_valids;

   assign axi_wdready = w_ctrl_wdready || w_data_wdready;

   // axi read addr
   reg [127:0]                  axi_raddrs;
   reg [31:0]                   axi_rsizes;
   reg [7:0]                    axi_raids;
   reg [1:0]                    axi_ravalids;
   wire                         axi_raready;

   always @(posedge clk) begin
      if (~resetn) begin
         axi_ravalids <= 'd0;
      end else if (axi_arvalid & axi_arready) begin
         if (axi_ravalids[0] & ~axi_raready) begin
            axi_raddrs[64+:64] <= axi_araddr;
            axi_rsizes[16+:16] <= ({8'd0, axi_arlen} + 1'b1) << axi_arsize;
            axi_raids[4+:4] <= axi_arid;
            axi_ravalids[1] <= 1'b1;
         end else begin
            axi_raddrs[0+:64] <= axi_araddr;
            axi_rsizes[0+:16] <= ({8'd0, axi_arlen} + 1'b1) << axi_arsize;
            axi_raids[0+:4] <= axi_arid;
            axi_ravalids[0] <= 1'b1;
         end
      end else if (axi_raready) begin
         axi_raddrs <= axi_raddrs >> 64;
         axi_rsizes <= axi_rsizes >> 16;
         axi_raids <= axi_raids >> 4;
         axi_ravalids <= axi_ravalids >> 1;
      end
   end
   assign axi_arready = ~axi_ravalids[1];

   // read ctrl
   reg                  read_is_ctrl;
   reg [15:0]           read_ctrl_addr;
   reg [15:0]           read_size;
   reg                  read_info_valid;
   reg [3:0]            read_id;
   reg [CH_NUM_LOG-1:0] read_queue_ch;
   reg [QUEUE_DL-1:0]   read_queue_entry;
   reg                  read_queue_valid;
   reg                  read_queue_done;
   wire [CH_NUM_LOG-1:0] w_queue_read_ch;
   wire [QUEUE_DL-1:0]   w_queue_read_entry;
   wire                  w_queue_read_valid;
   wire [7:0]           w_read_size;
   wire                 w_read;
   wire                 w_read_last_valid;
   always @(posedge clk) begin
      if (~resetn) begin
         read_is_ctrl <= 1'b0;
         read_info_valid <= 1'b0;
         read_size <= 'd0;
      end else if (axi_ravalids[0] && axi_raready && ~w_read_last_valid) begin
         read_is_ctrl <= ~|axi_raddrs[D2D_AXI_RANGE_BITS+:CH_NUM_LOG+1];
         read_ctrl_addr <= {axi_raddrs[15:KW_LOG], {KW_LOG{1'b0}}};
         read_queue_valid <= w_queue_read_valid;
         read_queue_done <= 1'b0;
         read_queue_ch = w_queue_read_ch;
         read_queue_entry = w_queue_read_entry;
         read_size <= axi_rsizes;
         read_id <= axi_raids;
         read_info_valid <= 1'b1;
      end else if (w_read) begin
         read_queue_done <= 1'b1;
         if (read_size <= KW) begin
            read_info_valid <= 1'b0;
         end else begin
            read_size <= read_size - KW;
         end
      end
   end
   assign axi_raready = ~read_info_valid;
   assign w_queue_read_valid = QUEUE_BASE <= axi_raddrs[15:0] && axi_raddrs[15:0] < QUEUE_HEAD_TAIL;
   assign w_queue_read_ch = (axi_raddrs[15:0] - QUEUE_BASE) >> (QEW_LOG + QUEUE_DL + 1);
   assign w_queue_read_entry = (axi_raddrs[15:0] - QUEUE_BASE) >> QEW_LOG;

   wire w_read_data_fifo_full;

   // reg read request
   reg [KW_LOG:0] read_pos;
   reg [KW_LOG:0] read_data_pos;
   reg            reading;
   reg            read_last;
   always @(posedge clk) begin
      if (~resetn) begin
         reg_arvalid <= 1'b0;
         read_pos <= 'd0;
         reading <= 1'b0;
         read_last <= 1'b0;
         read_data_pos <= 'd0;
      end else if (w_read || (axi_ravalids[0] && axi_raready && ~w_read_last_valid)) begin
         read_last <= 1'b0;
         if (axi_ravalids[0] && axi_raready && ~w_read_last_valid) begin
            read_pos <= {1'b0, axi_raddrs[KW_LOG-1:0]};
         end
      end else begin
         if (read_info_valid && read_is_ctrl && ~read_queue_valid && ~reading && ~w_read_data_fifo_full) begin
            reg_arvalid <= read_pos < read_size;
            read_data_pos <= read_pos;
            reading <= read_pos < read_size;
            reg_araddr <= read_ctrl_addr + read_pos;
            read_pos <= read_pos + 3'd4;
            read_last <= read_pos >= read_size || read_pos == KW;
         end else begin
            read_last <= 1'b0;
            reg_arvalid <= reg_arvalid & ~reg_arready;
            reading <= reading & ~(reg_rvalid & reg_rready);
         end
      end
   end
   wire w_reg_read = read_last;
   wire w_reg_read_size = read_pos;
   wire w_reg_read_last_valid = read_last;
   assign reg_rready = 1'b1;

   // queue read request
   reg  queue_reading;
   always @(posedge clk) begin
      if (~resetn) begin
         stream_queue_read_valid <= 1'b0;
         queue_reading <= 1'b0;
      end else if (read_info_valid && read_is_ctrl && read_queue_valid && ~read_queue_done && ~w_read_data_fifo_full & ~queue_reading) begin
         stream_queue_read_valid <= 1'b1;
         stream_queue_read_ch <= read_queue_ch;
         stream_queue_read_entry <= read_queue_entry;
         queue_reading <= 1'b1;
      end else begin
         stream_queue_read_valid <= 1'b0;
         queue_reading <= queue_reading & ~stream_queue_read_data_valid;
      end
   end
   wire w_queue_read = stream_queue_read_valid;

   reg  data_read_req;
   reg  data_read_last;
   always @(posedge clk) begin
      if (~resetn) begin
         data_read_req <= 1'b0;
         data_read_last <= 1'b0;
      end else begin
         data_read_req <= read_info_valid && ~read_is_ctrl && ~w_read_data_fifo_full;
         data_read_last <= read_info_valid && ~read_is_ctrl && ~w_read_data_fifo_full ? read_size - KW <= KW : read_size <= KW;
      end
   end
   wire w_data_read_req = read_info_valid && ~read_is_ctrl && ~w_read_data_fifo_full; //data_read_req;
   wire w_data_read_last = read_size <= KW;

   assign w_read = w_reg_read || w_queue_read || w_data_read_req;
   assign w_read_size = w_reg_read ? read_pos : KW;
   assign w_read_last_valid = w_reg_read_last_valid || w_queue_read || (w_data_read_req && w_data_read_last);

   // read data queue
   reg [DW-1:0] read_data;
   reg          read_data_valid;
   //reg [KW_LOG-1:0] read_data_pos;
   wire         read_data_ready;
   wire         axi_rvalid_data;
   wire         axi_rvalid_sideband;
   wire         axi_rready_post;
   generate
      for (genvar i=0; i<DW/32; i=i+1) begin
         always @(posedge clk) begin
            if (~resetn) begin
               read_data[i*32+:32] <= 'd0;
            end else if (reg_rvalid && reg_rready && read_data_pos == i*4) begin
               read_data[i*32+:32] <= reg_rdata;
            end else if (stream_queue_read_data_valid) begin
               read_data[i*32+:32] <= stream_queue_read_data >> ((i*32) & (QEWB-1));
            end else if (w_data_read_req) begin
               read_data[i*32+:32] <= 'd0;
            end
         end
      end
   endgenerate
   always @(posedge clk) begin
      if (~resetn) begin
         read_data_valid <= 1'b0;
         //read_data_pos <= 'd0;
      end else begin
         //read_data_pos <= read_data_valid ? read_pos : read_data_pos + (reg_rvalid & reg_rready ? 3'd4 : 3'd0);
         read_data_valid <= (reg_rvalid && reg_rready && (read_pos >= read_size || read_pos == KW)) ||
                            stream_queue_read_data_valid || w_data_read_req || (read_data_valid & ~read_data_ready);
      end
   end

   fifo #(
       .DW ( DW ),
       .DL ( 3 )
   ) read_data_queue (
       .idata ( read_data ),
       .ivalid ( read_data_valid ),
       .iready ( read_data_ready ),
       .odata ( axi_rdata ),
       .ovalid ( axi_rvalid_data ),
       .oready ( axi_rready_post ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   // read sideband queue
   fifo #(
       .DW ( 4 + 1 ),
       .DL ( 4 )
   ) read_sideband_queue (
       .idata ( {read_size <= KW, read_id} ),
       .ivalid ( w_read ),
       .iready (  ), // not full
       .odata ( {axi_rlast, axi_rid} ),
       .ovalid ( axi_rvalid_sideband ),
       .oready ( axi_rready_post ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   assign axi_rready_post = axi_rvalid_data & axi_rvalid_sideband & axi_rready;
   assign axi_rvalid = axi_rvalid_data & axi_rvalid_sideband;
   assign axi_rresp = 2'd0;

   // fifo full
   reg [3:0] queue_credit;
   reg       queue_full;
   wire [3:0] w_queue_credit;
   always @(posedge clk) begin
      if (~resetn) begin
         queue_credit <= 4'd5;
         queue_full <= 1'b0;
      end else begin
         queue_credit <= w_queue_credit;
         queue_full <= w_queue_credit < 'd2;
      end
   end
   assign w_queue_credit = queue_credit + (axi_rvalid_data && axi_rready_post) - (read_data_valid && read_data_ready);
   assign w_read_data_fifo_full = queue_full;

endmodule
