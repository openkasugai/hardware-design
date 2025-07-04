/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_xdma_bypass_axi #(
    parameter CH_NUM_LOG = 3,
    parameter DW_LOG = 9,
    parameter QEW_LOG = 5,
    parameter QUEUE_DL = 3,
    parameter VP_MAP_NUM_LOG = 5,
    parameter [39:0] D2D_AXI_BASE = 40'h0,
    parameter [31:0] D2D_AXI_RANGE = 32'h4000_0000, // 1GB
    parameter [31:0] D2D_AXI_RANGE_MASK = 32'h3fff_fffc, // 1GB
    parameter AXI_AR_BITS = 2,
    parameter AXI_R_BITS = 1,
    parameter AXI_AW_BITS = 2,
    parameter AXI_W_BITS = 1,
    parameter AXI_B_BITS = 2,
    parameter AXIS_BITS = 1,
    parameter AXIL_AR_BITS = 1,
    parameter AXIL_R_BITS = 1,
    parameter AXIL_AW_BITS = 1,
    parameter AXIL_W_BITS = 1,
    parameter AXIL_B_BITS = 1,
    parameter AXI_WR_REQ_NUM = 500,
    parameter AXI_RD_REQ_NUM = 500,
    parameter ENABLE_DATA_READ = 0
    ) ();

   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam KW_LOG = DW_LOG - 3;
   localparam KW_LOG_LOG = $clog2(KW_LOG);
   localparam DW = 1 << DW_LOG;
   localparam KW = 1 << KW_LOG;
   localparam QEW = 1 << QEW_LOG;
   localparam QEWB = QEW * 8;
   localparam VPMAP_CH_AGGREGATE = CH_NUM_LOG + VP_MAP_NUM_LOG + 5 > 15 ? 1 : 0;
   localparam VPMAP_MAX = VPMAP_CH_AGGREGATE ? 4 << (VP_MAP_NUM_LOG + 3) : 4 << (CH_NUM_LOG + VP_MAP_NUM_LOG + 3);
   localparam CTRL_MAX = VPMAP_MAX + (4 << (CH_NUM_LOG + 4));
   localparam CTRL_END = CTRL_MAX + 4 * 4;
   localparam QUEUE_DEPTH = 1 << QUEUE_DL;
   localparam QUEUE_BASE = (CTRL_END + 63) & ~63;
   localparam QUEUE_HEAD_TAIL = QUEUE_BASE + QEW * CH_NUM * QUEUE_DEPTH * 2; // (QEW * QUEUE_DEPTH) x ch_num x(req,cpl)
   localparam QUEUE_HEAD_TAIL_END = QUEUE_HEAD_TAIL + CH_NUM * 16; // ch_num x(req,cpl) x(head,tail)

   localparam AXI_AR_BITS_MOD = AXI_AR_BITS > 0 ? AXI_AR_BITS : 1;
   localparam AXI_R_BITS_MOD = AXI_R_BITS > 0 ? AXI_R_BITS : 1;
   localparam AXI_AW_BITS_MOD = AXI_AW_BITS > 0 ? AXI_AW_BITS : 1;
   localparam AXI_W_BITS_MOD = AXI_W_BITS > 0 ? AXI_W_BITS : 1;
   localparam AXI_B_BITS_MOD = AXI_B_BITS > 0 ? AXI_B_BITS : 1;
   localparam AXIS_BITS_MOD = AXIS_BITS > 0 ? AXIS_BITS : 1;
   localparam AXIL_AR_BITS_MOD = AXIL_AR_BITS > 0 ? AXIL_AR_BITS : 1;
   localparam AXIL_R_BITS_MOD = AXIL_R_BITS > 0 ? AXIL_R_BITS : 1;
   localparam AXIL_AW_BITS_MOD = AXIL_AW_BITS > 0 ? AXIL_AW_BITS : 1;
   localparam AXIL_W_BITS_MOD = AXIL_W_BITS > 0 ? AXIL_W_BITS : 1;
   localparam AXIL_B_BITS_MOD = AXIL_B_BITS > 0 ? AXIL_B_BITS : 1;

   reg [63:0]                     axi_araddr;
   reg [1:0]                      axi_arburst;
   reg [3:0]                      axi_arcache;
   reg [3:0]                      axi_arid;
   reg [7:0]                      axi_arlen;
   reg                            axi_arlock;
   reg [2:0]                      axi_arprot;
   reg [2:0]                      axi_arsize;
   reg                            axi_arvalid;
   wire                           axi_arready;
   wire [DW-1:0]                  axi_rdata;
   wire [3:0]                     axi_rid;
   wire [1:0]                     axi_rresp;
   wire                           axi_rlast;
   wire                           axi_rvalid;
   reg                            axi_rready;
   reg [63:0]                     axi_awaddr;
   reg [1:0]                      axi_awburst;
   reg [3:0]                      axi_awcache;
   reg [3:0]                      axi_awid;
   reg [7:0]                      axi_awlen;
   reg                            axi_awlock;
   reg [2:0]                      axi_awprot;
   reg [2:0]                      axi_awsize;
   reg                            axi_awvalid;
   wire                           axi_awready;
   reg [DW-1:0]                   axi_wdata;
   reg [KW-1:0]                   axi_wstrb;
   reg [3:0]                      axi_wid;
   reg                            axi_wlast;
   reg                            axi_wvalid;
   wire                           axi_wready;
   wire [3:0]                     axi_bid;
   wire [1:0]                     axi_bresp;
   wire                           axi_bvalid;
   reg                            axi_bready;

   wire [DW-1:0]                  axis_tdata;
   wire [KW-1:0]                  axis_tkeep;
   wire [CH_NUM_LOG-1:0]          axis_tuser;
   wire                           axis_tlast;
   wire                           axis_eof;
   wire                           axis_tvalid;
   reg                            axis_tready;

   wire [15:0]                    reg_araddr;
   wire                           reg_arvalid;
   reg                            reg_arready;
   reg [31:0]                     reg_rdata;
   reg [1:0]                      reg_rresp;
   reg                            reg_rvalid;
   wire                           reg_rready;
   wire [15:0]                    reg_awaddr;
   wire                           reg_awvalid;
   reg                            reg_awready;
   wire [31:0]                    reg_wdata;
   wire                           reg_wvalid;
   reg                            reg_wready;
   reg [1:0]                      reg_bresp;
   reg                            reg_bvalid;
   wire                           reg_bready;

   wire [CH_NUM_LOG-1:0]          stream_queue_read_ch;
   wire [QUEUE_DL-1:0]            stream_queue_read_entry;
   wire                           stream_queue_read_valid;
   reg [QEWB-1:0]                 stream_queue_read_data;
   reg                            stream_queue_read_data_valid;

    wire clk, resetn;
    wire [31:0] rd;
    clk_reset clk_reset(
        .clk ( clk ),
        .resetn ( resetn ),
        .rd ( rd )
    );

    xdma_bypass_axi #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .DW_LOG ( DW_LOG ),
        .QEW_LOG ( QEW_LOG ),
        .QUEUE_DL ( QUEUE_DL ),
        .VP_MAP_NUM_LOG ( VP_MAP_NUM_LOG ),
        .D2D_AXI_BASE ( D2D_AXI_BASE ),
        .D2D_AXI_RANGE ( D2D_AXI_RANGE )
    ) dut (
        .*
    );

   initial begin
      axi_arvalid = 1'b0;
      axi_rready = 1'b1;
      axi_awvalid = 1'b0;
      axi_wvalid = 1'b0;
      axi_bready = 1'b1;
      axis_tready = 1'b1;
      reg_arready = 1'b1;
      reg_rvalid = 1'b0;
      reg_awready = 1'b1;
      reg_wready = 1'b1;
      reg_bvalid = 1'b0;
      stream_queue_read_data_valid = 1'b0;
   end

   reg [QEWB-1:0] queue_data_buf[0:QUEUE_DEPTH*CH_NUM*2-1];
   reg [31:0]    queue_head_tail_buf[0:CH_NUM*4-1];
   reg [DW-1:0]  stream_data_save[0:255];
   reg [KW-1:0]  stream_keep_save[0:255];
   reg           stream_last_save[0:255];
   reg           stream_eof_save[0:255];
   reg [7:0]     stream_wpos, stream_rpos;

   reg [15:0]    reg_addr_save[0:255];
   reg [31:0]    reg_data_save[0:255];
   reg [7:0]     reg_w_wpos, reg_w_arpos, reg_w_drpos;

   reg [DW-1:0] rd_data_buf[0:255];
   reg [KW-1:0] rd_keep_buf[0:255];
   reg          rd_last_buf[0:255];
   reg [3:0]    rd_id_buf[0:255];
   reg [7:0]    rd_wpos, rd_rpos;

   initial begin
      stream_wpos = 'd0;
      stream_rpos = 'd0;
      reg_w_wpos = 'd0;
      reg_w_arpos = 'd0;
      reg_w_drpos = 'd0;
      rd_wpos = 'd0;
      rd_rpos = 'd0;
   end

   // axis check
   reg [DW-1:0] cur_st_mask;
   always @(posedge clk) begin
      if (resetn && axis_tvalid && axis_tready) begin
         for (int i=0; i<KW; i++) begin
            cur_st_mask[i*8+:8] = {8{axis_tkeep[i]}};
         end
         if ((axis_tdata & cur_st_mask) !== (stream_data_save[stream_rpos] & cur_st_mask) ||
             axis_tkeep !== stream_keep_save[stream_rpos] ||
             axis_tlast !== stream_last_save[stream_rpos]) begin
            $error("%d: write stream: %h %h, %h %h, %h %h", $time,
                   axis_tdata, stream_data_save[stream_rpos],
                   axis_tkeep, stream_keep_save[stream_rpos],
                   axis_tlast, stream_last_save[stream_rpos]);
         end
         stream_rpos <= stream_rpos + 1'b1;
      end
      axis_tready = AXIS_BITS > 0 ? &rd[21+:AXIS_BITS_MOD] : 1'b1;
   end

   // reg write check
   reg [15:0] reg_aw_count, reg_w_count, reg_b_count;
   always @(posedge clk) begin
      if (~resetn) begin
         reg_aw_count <= 'd0;
         reg_w_count <= '0;
         reg_b_count <= '0;
      end
      if (resetn && reg_awvalid && reg_awready) begin
         if (reg_awaddr !== reg_addr_save[reg_w_arpos]) begin
            $error("%d: write reg addr: %h %h", $time, reg_awaddr, reg_addr_save[reg_w_arpos]);
         end
         reg_w_arpos <= reg_w_arpos + 1'b1;
         reg_aw_count <= reg_aw_count + 1'b1;
      end
      if (resetn && reg_wvalid && reg_wready) begin
         if (reg_wdata !== reg_data_save[reg_w_drpos]) begin
            $error("%d: write reg data: %h %h", $time, reg_wdata, reg_data_save[reg_w_drpos]);
         end
         reg_w_drpos <= reg_w_drpos + 1'b1;
         reg_w_count <= reg_w_count + 1'b1;
      end
      if (reg_b_count < reg_w_count && reg_b_count < reg_aw_count && (~reg_bvalid || reg_bready)) begin
         if (AXIL_B_BITS > 0 ? &rd[13+:AXIL_B_BITS_MOD] : 1'b1) begin
            reg_bvalid <= 1'b1;
            reg_b_count <= reg_b_count + 1'b1;
         end else begin
            reg_bvalid <= 1'b0;
         end
      end else begin
         reg_bvalid <= reg_bvalid & ~reg_bready;
      end
      reg_awready <= AXIL_AW_BITS > 0 ? &rd[15+:AXIL_AW_BITS_MOD] : 1'b1;
      reg_wready <= AXIL_W_BITS > 0 ? &rd[21+:AXIL_W_BITS_MOD] : 1'b1;
   end

   // reg read response
   reg        reg_read_valid;
   reg [15:0] reg_read_addr;
   wire [15:0] w_queue_read_addr;
   wire [15:0] w_head_tail_read_addr;
   always @(posedge clk) begin
      if (~resetn) begin
         reg_read_valid <= 1'b0;
      end else begin
         if (reg_arvalid & reg_arready) begin
            reg_read_valid <= 1'b1;
            reg_read_addr <= reg_araddr;
         end else if (reg_read_valid && (AXIL_R_BITS > 0 ? &rd[17+:AXIL_R_BITS_MOD]: 1'b1) && (~reg_rvalid || reg_rready)) begin
            if (QUEUE_BASE <= reg_read_addr && reg_read_addr < QUEUE_HEAD_TAIL) begin
               reg_rdata <= queue_data_buf[w_queue_read_addr[QEW_LOG+:CH_NUM_LOG+QUEUE_DL+1]] >> {w_queue_read_addr[QEW_LOG-1:2], 2'd0};
            end else if (QUEUE_HEAD_TAIL <= reg_read_addr && reg_read_addr < QUEUE_HEAD_TAIL_END) begin
               reg_rdata <= queue_head_tail_buf[w_head_tail_read_addr[2+:CH_NUM_LOG+2]];
            end else begin
               reg_rdata <= {16'hbeef, reg_read_addr};
            end
            reg_read_valid <= 1'b0;
            reg_rvalid <= 1'b1;
         end else begin
            reg_rvalid <= reg_rvalid & ~reg_rready;
         end
         reg_arready <= ~reg_read_valid && (AXIL_AR_BITS > 0 ? &rd[8+:AXIL_AR_BITS_MOD] : 1'b1);
      end
   end
   assign w_queue_read_addr = reg_read_addr - QUEUE_BASE;
   assign w_head_tail_read_addr = reg_read_addr - QUEUE_HEAD_TAIL;

   always @(posedge clk) begin
      if (resetn && stream_queue_read_valid) begin
         stream_queue_read_data_valid <= 1'b1;
         stream_queue_read_data <= {'d0, queue_data_buf[{stream_queue_read_ch, 1'b0, stream_queue_read_entry}]};
      end else begin
         stream_queue_read_data_valid <= 1'b0;
      end
   end

   // axi read response check
   reg [DW-1:0] cur_rd_keep_mask;
   always @(posedge clk) begin
      if (resetn && axi_rvalid & axi_rready) begin
         for (int i=0; i<KW; i++) begin
            cur_rd_keep_mask[i*8+:8] = {8{rd_keep_buf[rd_rpos][i]}};
         end
         if ((axi_rdata & cur_rd_keep_mask) !== (rd_data_buf[rd_rpos] & cur_rd_keep_mask) ||
             axi_rlast !== rd_last_buf[rd_rpos] ||
             axi_rid !== rd_id_buf[rd_rpos]) begin
            $error("%d: axi read data: %h %h (%h), %h %h, %h %h", $time, axi_rdata, rd_data_buf[rd_rpos],
                   rd_keep_buf[rd_rpos], axi_rlast, rd_last_buf[rd_rpos], axi_rid, rd_id_buf[rd_rpos]);
         end
         rd_rpos <= rd_rpos + 1'b1;
      end
      if (resetn) begin
         axi_rready <= AXI_R_BITS > 0 ? &rd[11+:AXI_R_BITS_MOD] : 1'b1;
      end
   end

   task static setup;
      logic [QEWB-1:0] data;
      for (int i=0; i<QUEUE_DEPTH*CH_NUM*2; i++) @(posedge clk) begin
         for (int j=0; j<QEWB; j+=32) begin
            data[j+:32] = rd ^ (64'hdeadbeefdeadbeef >> (j/16));
         end
         queue_data_buf[i] = data;
      end
      for (int i=0; i<CH_NUM*4; i++) begin
         queue_head_tail_buf[i] = (i/4) & 7;
      end
   endtask

   task static generate_write_requests;
      logic [CH_NUM_LOG:0] addr_base_0;
      logic [7:0]          len_0 = 0;
      logic [2:0]          size_0;
      logic [3:0]          id_0;
      logic [63:0]         addr_0;
      logic                eof_0 = 0;
      logic [CH_NUM_LOG:0] addr_base;
      logic [7:0]          len = 0;
      logic                eof;
      logic [2:0]          size;
      logic [63:0]         addr;
      logic [DW-1:0]       data;
      logic [KW-1:0]       keep;
      logic                last;
      logic [3:0]          id;
      logic [KW_LOG:0]     keep_size;
      logic [KW_LOG-1:0]   addr_lower;
      logic                avalid;
      logic                valid;
      int                  wr_req_count = 0;
      int                  wr_addr_count = 0;
      logic [CH_NUM_LOG+1+64+4+8+3+1-1:0] addr_save[0:255];
      logic [7:0]          addr_wpos = 0;
      logic [7:0]          addr_rpos = 0;

      while (wr_req_count < AXI_WR_REQ_NUM || axi_awvalid || axi_wvalid) @(posedge clk) begin
         if (wr_addr_count < AXI_WR_REQ_NUM && ((addr_wpos + 1) & 255) != addr_rpos && (~axi_awvalid || axi_awready)) begin
            avalid = AXI_AW_BITS > 0 ? &rd[12+:AXI_AW_BITS_MOD] : 1'b1;
            if (avalid) begin
               if (eof_0) begin
                  len_0 = 0;
                  size_0 = 2;
                  addr_0 = D2D_AXI_BASE + QUEUE_BASE + QEW * QUEUE_DEPTH * ((addr_base_0 - 1)*2+1) + 8; // cpl size
                  addr_base_0 = 0;
                  eof_0 = 0;
               end else begin
                  addr_base_0 = rd[20+:CH_NUM_LOG+1];
                  if (addr_base_0 >= CH_NUM+1) addr_base_0 -= CH_NUM;
                  if (wr_addr_count == AXI_WR_REQ_NUM - 2 && addr_base_0 == 0) begin
                     eof_0 = 1;
                     addr_base_0 = 1;
                  end else if (wr_addr_count == AXI_WR_REQ_NUM - 2) begin
                     eof_0 = 1;
                  end else begin
                     if (wr_addr_count == AXI_WR_REQ_NUM - 1) begin
                        addr_base_0 = 0;
                     end
                     eof_0 = 0;
                  end
                  len_0 = rd[4+:4];
                  if (addr_base_0 == 0) len_0 = 0;
                  size_0 = KW_LOG; // len_0 == 0 ? (rd[8+:KW_LOG_LOG] > KW_LOG ? KW_LOG : rd[8+:KW_LOG_LOG]) : KW_LOG;
                  addr_0 = D2D_AXI_BASE + D2D_AXI_RANGE * addr_base_0 + (rd & D2D_AXI_RANGE_MASK);
               end
               id_0 = rd[20+:4];
               eof_0 = eof_0 || (rd[14] && |addr_base_0);
               addr_save[addr_wpos] <= {eof_0, id_0, len_0, size_0, addr_base_0, addr_0};
               addr_wpos <= addr_wpos + 1'b1;
               axi_awaddr <= addr_0;
               axi_awburst <= 2'd0;
               axi_awcache <= 4'd0;
               axi_awid <= id_0;
               axi_awlen <= len_0;
               axi_awlock <= 1'b0;
               axi_awprot <= 3'd0;
               axi_awsize <= size_0;
               wr_addr_count++;
               //$display("%d: wr addr: %h %h %h", $time, addr_base_0, addr_0, len_0);
            end
            axi_awvalid <= avalid;
         end else begin
            axi_awvalid <= axi_awvalid & ~axi_awready;
         end
         if (~|len && wr_req_count < AXI_WR_REQ_NUM && addr_wpos != addr_rpos) begin
            {eof, id, len, size, addr_base, addr} = addr_save[addr_rpos];
            addr_rpos <= addr_rpos + 1'b1;
            len++;
            addr_lower = addr[KW_LOG-1:0];
         end
         if (|len && (~axi_wvalid || axi_wready)) begin
            valid = AXI_W_BITS > 0 ? &rd[14+:AXI_W_BITS_MOD] : 1'b1;
            for (int i=0; i<DW; i+=32) begin
               data[i+:32] = {rd,rd} ^ (64'hf00baa00f00baa00 >> (i/16));
            end
            last = len == 1;
            keep_size = {rd[7+:KW_LOG-2], 2'd0};
            if (~|keep_size) keep_size = 16'd4;
            if (keep_size > (16'd1<<size)) keep_size = 16'd1 << size;
            keep = last ? ({{KW{1'b0}}, 1'b1} << keep_size)-1'b1 : {KW{1'b1}};
            keep = keep << addr_lower;
            axi_wdata <= data;
            axi_wstrb <= keep;
            axi_wlast <= last;
            axi_wid <= id;
            axi_wvalid <= valid;
            if (valid) begin
               addr_lower = 0;
               len--;
               if (~|len) wr_req_count++;
               if (addr_base > 0) begin
                  stream_data_save[stream_wpos] <= data;
                  stream_keep_save[stream_wpos] <= keep;
                  stream_last_save[stream_wpos] <= last;
                  stream_eof_save[stream_wpos] <= last && eof;
                  stream_wpos <= stream_wpos + 1'b1;
               end else begin
                  $display("%d: reg write: %h %h %h", $time, addr, data, keep);
                  for (int i=0; i<KW; i+=4) begin
                     if (&keep[i+:4]) begin
                        reg_addr_save[reg_w_wpos] = {addr[63:KW_LOG], {KW_LOG{1'b0}}} + i;
                        reg_data_save[reg_w_wpos] = data[i*8+:32];
                        $display("%d: reg write[%x]: %h %h", $time, i, {addr[63:KW_LOG], {KW_LOG{1'b0}}} + i, data[i*8+:32]);
                        reg_w_wpos++;
                     end
                  end
               end
            end
         end else begin
            axi_wvalid <= axi_wvalid & ~axi_wready;
         end
      end
   endtask

   task static generate_read_requests;
      logic [CH_NUM_LOG:0] addr_base_0;
      logic [7:0]          len_0 = 0;
      logic [2:0]          size_0;
      logic [3:0]          id_0;
      logic [63:0]         addr_0;
      logic                avalid = 0;
      logic [7:0]          len;
      logic [63:0]         addr;
      logic [DW-1:0]       data;
      logic [KW-1:0]       keep;
      logic                last;
      logic [CH_NUM_LOG-1:0] queue_ch;
      logic [QUEUE_DL-1:0]   queue_entry;
      logic [CH_NUM_LOG+1:0] head_tail_pos;
      int                    rd_req_count = 0;
      while (rd_req_count < AXI_RD_REQ_NUM || axi_arvalid || avalid) @(posedge clk) begin
         if (rd_req_count < AXI_RD_REQ_NUM && ((rd_wpos + 1) & 255) != rd_rpos && (~axi_arvalid || axi_arready) && ~avalid) begin
            avalid = (AXI_AW_BITS > 0 ? &rd[12+:AXI_AW_BITS_MOD] : 1'b1) && rd_req_count < AXI_RD_REQ_NUM;
            if (avalid) begin
               if (ENABLE_DATA_READ > 0) begin
                  addr_base_0 = rd[20+:CH_NUM_LOG+1];
               end else begin
                  addr_base_0 = 0;
               end
               if (addr_base_0 >= CH_NUM+1) addr_base_0 -= CH_NUM;
               len_0 = rd[4+:4];
               if (addr_base_0 == 0) len_0 = 0;
               size_0 = KW_LOG; // len_0 == 0 ? (rd[8+:KW_LOG_LOG] > KW_LOG ? KW_LOG : rd[8+:KW_LOG_LOG]) : KW_LOG;
               addr_0 = D2D_AXI_BASE + D2D_AXI_RANGE * addr_base_0 + (rd & D2D_AXI_RANGE_MASK);
               id_0 = rd[20+:4];
               addr = addr_0;
               len = len_0 + 1;
               axi_araddr <= addr_0;
               axi_arburst <= 2'd0;
               axi_arcache <= 4'd0;
               axi_arid <= id_0;
               axi_arlen <= len_0;
               axi_arlock <= 1'b0;
               axi_arprot <= 3'd0;
               axi_arsize <= size_0;
               rd_req_count++;
               //$display("%d: rd addr: %h %h %h", $time, addr_base_0, addr_0, len_0);
            end
            axi_arvalid <= avalid;
         end else begin
            axi_arvalid <= axi_arvalid & ~axi_arready;
         end
         if (avalid) begin
            while (|len && ((rd_wpos + 1) & 255) != rd_rpos) begin
               if (addr_base_0 == 0 && QUEUE_BASE <= addr[15:0] && addr[15:0] < QUEUE_HEAD_TAIL) begin
                  queue_ch = (addr[15:0] - QUEUE_BASE) >> (QEW_LOG + QUEUE_DL + 1);
                  queue_entry = (addr[15:0] - QUEUE_BASE) >> QEW_LOG;
                  data = {queue_data_buf[{queue_ch, 1'b0, queue_entry}], queue_data_buf[{queue_ch, 1'b0, queue_entry}]};
                  keep = {'d0, {QEW{1'b1}}} << addr[KW_LOG-1:0];
                  last = 1'b1;
               end else if (addr_base_0 == 0 && QUEUE_HEAD_TAIL <= addr[15:0] && addr[15:0] < QUEUE_HEAD_TAIL_END) begin
                  head_tail_pos = ({addr[15:KW_LOG], {KW_LOG{1'b0}}} - QUEUE_HEAD_TAIL) >> 2;
                  keep = 'd0;
                  for (int i=0; i<KW; i+=4) begin
                     data[i*8+:32] = queue_head_tail_buf[head_tail_pos];
                     keep[i+:4] = i >= addr[KW_LOG-1:0] ? 4'hf : 4'h0;
                     head_tail_pos++;
                  end
                  last = 1'b1;
               end else if (addr_base_0 == 0) begin
                  keep = 'd0;
                  for (int i=0; i<(1<<size_0); i+=4) begin
                     data[i*8+:32] = 32'hbeef0000 | (({addr[15:KW_LOG], {KW_LOG{1'b0}}} + i) & 16'hffff);
                     keep[i+:4] = i >= addr[KW_LOG-1:0] ? 4'hf : 4'h0;
                  end
                  last = 1'b1;
               end else begin
                  keep = 'd0;
                  last = len == 1;
               end
               rd_data_buf[rd_wpos] = data;
               rd_keep_buf[rd_wpos] = keep;
               rd_last_buf[rd_wpos] = last;
               rd_id_buf[rd_wpos] = id_0;
               $display("%d: read exp[%1d][%h]: %h %h %h, %s", $time, addr_base_0, addr, data, keep, last,
                        ~|addr_base_0 && QUEUE_BASE <= addr[15:0] && addr[15:0] < QUEUE_HEAD_TAIL ? "head_tail" :
                        ~|addr_base_0 && QUEUE_HEAD_TAIL <= addr[15:0] && addr[15:0] < QUEUE_HEAD_TAIL_END ? "queue" :
                        ~|addr_base_0 ? "ctrl_other" : "unknown");
               rd_wpos++;
               len--;
               if (len==0) avalid <= 0;
            end
         end
      end
   endtask

   logic [9:0] timeout;
   initial begin
      timeout = 0;
      @(posedge clk);
      while (~resetn) @(posedge clk);

      setup();

      fork
         generate_write_requests();
         generate_read_requests();
      join

      while (~&timeout && stream_rpos !== stream_wpos) @(posedge clk) begin
         timeout <= timeout + 1'b1;
      end
      if (&timeout) begin
         $error("%d: stream output is not finished.", $time);
      end
      $finish;
   end

endmodule

module test_xdma_bypass_axi_fast;
   tb_xdma_bypass_axi #(
       .AXI_AR_BITS ( 0 ),
       .AXI_R_BITS ( 0 ),
       .AXI_AW_BITS ( 0 ),
       .AXI_W_BITS ( 0 ),
       .AXI_B_BITS ( 0 ),
       .AXIS_BITS ( 0 ),
       .AXIL_AR_BITS ( 0 ),
       .AXIL_R_BITS ( 0 ),
       .AXIL_AW_BITS ( 0 ),
       .AXIL_W_BITS ( 0 ),
       .AXIL_B_BITS ( 0 )
   ) tb ();
endmodule

module test_xdma_bypass_axi_random;
   tb_xdma_bypass_axi tb();
endmodule

module test_xdma_bypass_axi_slow_in;
   tb_xdma_bypass_axi #(
       .AXI_AR_BITS ( 3 ),
       .AXI_R_BITS ( 0 ),
       .AXI_AW_BITS ( 3 ),
       .AXI_W_BITS ( 2 ),
       .AXI_B_BITS ( 0 ),
       .AXIS_BITS ( 0 ),
       .AXIL_AR_BITS ( 0 ),
       .AXIL_R_BITS ( 2 ),
       .AXIL_AW_BITS ( 0 ),
       .AXIL_W_BITS ( 0 ),
       .AXIL_B_BITS ( 2 )
   ) tb ();
endmodule

module test_xdma_bypass_axi_slow_out;
   tb_xdma_bypass_axi #(
       .AXI_AR_BITS ( 0 ),
       .AXI_R_BITS ( 2 ),
       .AXI_AW_BITS ( 0 ),
       .AXI_W_BITS ( 0 ),
       .AXI_B_BITS ( 2 ),
       .AXIS_BITS ( 2 ),
       .AXIL_AR_BITS ( 3 ),
       .AXIL_R_BITS ( 0 ),
       .AXIL_AW_BITS ( 3 ),
       .AXIL_W_BITS ( 2 ),
       .AXIL_B_BITS ( 0 )
   ) tb ();
endmodule

module test_xdma_bypass_axi_random_data_read;
   tb_xdma_bypass_axi #(
       .ENABLE_DATA_READ ( 1 )
   ) tb ();
endmodule
