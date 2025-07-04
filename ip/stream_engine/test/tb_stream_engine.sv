/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_stream_engine #(
    parameter [15:0] REG_BASE = 16'h0000,
    parameter DW_LOG = 9,
    parameter QEW_LOG = 5,
    parameter VP_MAP_NUM_LOG = 5,
    parameter QUEUE_DL = 3,
    parameter FRAME_INFO_FIFO_DL = 5,
    parameter DESC_BASE_FIFO_DL = 2,
    parameter DATA_FIFO_DL = 7,
    parameter CPL_FIFO_DL = 4,
    parameter DESC_FIFO_DL = 7,
    parameter STS_FIFO_DL = 7,
    parameter CH_NUM_LOG = 4,
    parameter CH_BASE = 0,
    parameter [7:0] QUEUE_CHECK_TAG = 99,
    parameter [7:0] QUEUE_READ_TAG = 98,
    parameter KDIV = 4,
    parameter DESC_MAX = 4,
    parameter RCBASE = 96,
    parameter RQBASE = 128,
    parameter QESIZE_POS = 64,
    parameter CH_POS = RQBASE + 32,
    parameter CPL_POS = RQBASE + 64,
    parameter BURST_MAX = 4,
    parameter DESC_LEN = 512,
    parameter DESC_RQ_DW = 512,
    parameter DESC_RC_DW = 512,
    parameter DESC_RQ_DK = DESC_RQ_DW/32,
    parameter DESC_RC_DK = DESC_RC_DW/32,
    parameter [39:0] D2D_AXI_BASE = 40'h0,
    parameter [31:0] D2D_AXI_RANGE = 32'h4000_0000, // 1GB
    parameter ENABLE_D2D = 0,
    parameter IS_TX = 1,
    parameter DISABLE_FRAME_INFO = 0,
    parameter ENABLE_FRAME_INFO_OUT = 1,
    parameter IGNORE_CPL_SIZE = 0,
    parameter USE_ULTRA_RAM_VPMAP = 1,
    parameter ACTIVE_LOW_RESET_IN = 1,
    parameter FRAME_INFO_BITS = 1,
    parameter REQ_CH_BASE = 22,
    parameter ADD_REQ_BASE = 15,
    parameter ADD_REQ_BITS = 2,
    parameter TRANSFER_MAX_LOG = 8,
    parameter TRANSFER_SIZE_MAX_LOG = 14,
    parameter TRANSFER_NUM = 100,
    parameter VPMAP_SIZE_MAX = 32'hfffffffc,
    parameter TAIL_UP_POS = 12,
    parameter TAIL_UP_NUM = 3,
    parameter THROUGH_TAG = 8'hef,
    parameter QUEUE_MAX = 16,
    parameter [(1<<CH_NUM_LOG)-1:0] CH_VALIDS = 8'h80,
    parameter FIXED_CH_VALIDS = 0,
    parameter START_DELAY = 0,
    parameter ENABLE_EXTRA_READ = 0,
    parameter TEST_CASE = 0,
    parameter DOORBELL_WITH_AXI = 0,
    parameter FRAME_INFO_READY_BITS = 1,
    parameter RD_VALID_BITS = 1,
    parameter WR_READY_BITS = 1,
    parameter DESC_READY_BITS = 1,
    parameter DATA_VALID_BITS = 1,
    parameter DATA_READY_BITS = 1,
    parameter ENABLE_CHECK_WITH_DOORBELL = 0,
    parameter REQ_INFLIGHT_MAX = 4,
    parameter AXIL_BITS = 1,
    parameter AXI_ABITS = 1,
    parameter AXI_DBITS = 1,
    parameter AXI_RBITS = 1,
    parameter AXI_BBITS = 1
    ) ();

   wire clk, resetn;
   wire [31:0] rd;
   clk_reset clk_reset(
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
   );

   localparam QUEUE_DEPTH = 1 << QUEUE_DL;
   localparam QEW = 1 << QEW_LOG;
   localparam DW = 1 << DW_LOG;
   localparam KW_LOG = DW_LOG - 3;
   localparam KW = 1 << KW_LOG;
   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam QEWB_LOG = QEW + 3;
   localparam QEWB = 1 << QEWB_LOG;
   localparam FRAME_INFO_READY_BITS_MOD = FRAME_INFO_READY_BITS > 0 ? FRAME_INFO_READY_BITS : 1;
   localparam RD_VALID_BITS_MOD = RD_VALID_BITS > 0 ? RD_VALID_BITS : 1;
   localparam WR_READY_BITS_MOD = WR_READY_BITS > 0 ? WR_READY_BITS : 1;
   localparam DESC_READY_BITS_MOD = DESC_READY_BITS > 0 ? DESC_READY_BITS : 1;
   localparam DATA_VALID_BITS_MOD = DATA_VALID_BITS > 0 ? DATA_VALID_BITS : 1;
   localparam DATA_READY_BITS_MOD = DATA_READY_BITS > 0 ? DATA_READY_BITS : 1;
   localparam AXI_DBITS_MOD = AXI_DBITS > 0 ? AXI_DBITS : 1;
   localparam AXI_RBITS_MOD = AXI_RBITS > 0 ? AXI_RBITS : 1;

   localparam D2D_AXI_RANGE_MASK = (D2D_AXI_RANGE - 1) & ~(KW*16-1);

   localparam VP_MAP_NUM = 1 << VP_MAP_NUM_LOG;
   localparam VPMAP_CH_AGGREGATE = CH_NUM_LOG + VP_MAP_NUM_LOG + 5 > 15 ? 1 : 0;
   localparam VPMAP_MAX = VPMAP_CH_AGGREGATE ? 4 << (VP_MAP_NUM_LOG + 3) : 4 << (CH_NUM_LOG + VP_MAP_NUM_LOG + 3);
   localparam CTRL_BASE = VPMAP_MAX;
   localparam CTRL_MAX = VPMAP_MAX + (4 << (CH_NUM_LOG + 4));
   localparam QUEUE_BASE = (CTRL_MAX + 16 + 63) & ~63;
   localparam QUEUE_HEAD_TAIL_BASE = QUEUE_BASE + CH_NUM * QUEUE_DEPTH * QEW * 2;

   reg [63:0]   axi_araddr;
   reg [1:0]    axi_arburst;
   reg [3:0]    axi_arcache;
   reg [3:0]    axi_arid;
   reg [7:0]    axi_arlen;
   reg          axi_arlock;
   reg [2:0]    axi_arprot;
   reg [2:0]    axi_arsize;
   reg          axi_arvalid;
   wire         axi_arready;
   wire [DW-1:0] axi_rdata;
   wire [3:0]    axi_rid;
   wire [1:0]    axi_rresp;
   wire          axi_rlast;
   wire          axi_rvalid;
   reg           axi_rready;
   reg [63:0]    axi_awaddr;
   reg [1:0]     axi_awburst;
   reg [3:0]     axi_awcache;
   reg [3:0]     axi_awid;
   reg [7:0]     axi_awlen;
   reg           axi_awlock;
   reg [2:0]     axi_awprot;
   reg [2:0]     axi_awsize;
   reg           axi_awvalid;
   wire          axi_awready;
   reg [DW-1:0]  axi_wdata;
   reg [KW-1:0]  axi_wstrb;
   reg [3:0]     axi_wid;
   reg           axi_wlast;
   reg           axi_wvalid;
   wire          axi_wready;
   wire [3:0]    axi_bid;
   wire [1:0]    axi_bresp;
   wire          axi_bvalid;
   reg           axi_bready;

   reg [15:0]    reg_araddr;
   reg           reg_arvalid;
   wire          reg_arready;
   wire [31:0]   reg_rdata;
   wire [1:0]    reg_rresp;
   wire          reg_rvalid;
   reg           reg_rready;
   reg [15:0]    reg_awaddr;
   reg           reg_awvalid;
   wire          reg_awready;
   reg [31:0]    reg_wdata;
   reg           reg_wvalid;
   wire          reg_wready;
   wire [1:0]    reg_bresp;
   wire          reg_bvalid;
   reg           reg_bready;

   reg [31:0]    frame_info_size;
   reg [CH_NUM_LOG-1:0] frame_info_ch;
   reg                  frame_info_valid;
   wire                 frame_info_ready;

   wire [31:0]          frame_info_out_size;
   wire [CH_NUM_LOG-1:0] frame_info_out_ch;
   wire                  frame_info_out_valid;
   reg                   frame_info_out_ready;

   wire [15:0]           wr_desc_ctl;
   wire [63:0]           wr_desc_dst_addr;
   wire [63:0]           wr_desc_src_addr; // dummy
   wire [27:0]           wr_desc_len;
   wire                  wr_desc_load;
   reg                   wr_desc_ready;
   // data wire (to xdma)
   wire [DW-1:0]         wr_tdata;
   wire [KW-1:0]         wr_tkeep;
   wire                  wr_tlast;
   wire                  wr_tvalid;
   reg                   wr_tready;
   // descriptor wire (to xdma)
   wire [15:0]           rd_desc_ctl;
   wire [63:0]           rd_desc_dst_addr; // dummy
   wire [63:0]           rd_desc_src_addr;
   wire [27:0]           rd_desc_len;
   wire                  rd_desc_load;
   reg                   rd_desc_ready;
   // data reg (from xdma)
   reg [DW-1:0]          rd_tdata;
   reg [KW-1:0]          rd_tkeep;
   reg                   rd_tlast;
   reg                   rd_tvalid;
   wire                  rd_tready;
   // dma status
   reg [7:0]             wr_sts;
   wire [31:0]           wr_done_count;
   reg [7:0]             rd_sts;
   wire [31:0]           rd_done_count;
   // descriptor wire (to xdma)
   wire [15:0]           data_desc_ctl;
   wire [63:0]           data_desc_src_addr;
   wire [63:0]           data_desc_dst_addr;
   wire [27:0]           data_desc_len;
   wire                  data_desc_load;
   reg                   data_desc_ready;
   // dma status
   reg [7:0]             data_sts;

   // rx data reg (from xdma)
   reg [(1<<DW_LOG)-1:0] rx_in_tdata;
   reg [(1<<(DW_LOG-3))-1:0] rx_in_tkeep;
   reg                       rx_in_tlast;
   reg                       rx_in_tvalid;
   wire                      rx_in_tready;
   // rx data wire (to route_controller)
   wire [(1<<DW_LOG)-1:0]    rx_out_tdata;
   wire [(1<<(DW_LOG-3))-1:0] rx_out_tkeep;
   wire [CH_NUM_LOG-1:0]      rx_out_tuser;
   wire                       rx_out_tlast;
   wire                       rx_out_tvalid;
   wire                       rx_out_eof;
   reg                        rx_out_tready;
   // tx data reg (from route_controller)
   reg [(1<<DW_LOG)-1:0]      tx_in_tdata;
   reg [(1<<(DW_LOG-3))-1:0]  tx_in_tkeep;
   reg [CH_NUM_LOG-1:0]       tx_in_tuser;
   reg                        tx_in_tlast;
   reg                        tx_in_sop;
   reg                        tx_in_eop;
   reg                        tx_in_tvalid;
   wire                       tx_in_tready;
   // tx data wire (to xdma)
   wire [(1<<DW_LOG)-1:0]     tx_out_tdata;
   wire [(1<<(DW_LOG-3))-1:0] tx_out_tkeep;
   wire                       tx_out_tlast;
   wire                       tx_out_tvalid;
   reg                        tx_out_tready;
   // interrupt
   wire [CH_NUM-1:0]          irq_out;
   reg [CH_NUM-1:0]           irq_ack;
   // completion tail update
   reg [CH_NUM_LOG-1:0]       stream_cpl_update_ch;
   reg                        stream_cpl_update;

   initial begin
      axi_arvalid = 1'b0;
      axi_rready = 1'b0;
      axi_awvalid = 1'b0;
      axi_wvalid = 1'b0;
      axi_bready = 1'b0;
      reg_araddr = 16'd0;
      reg_arvalid = 1'b0;
      reg_rready = 1'b0;
      reg_awaddr = 16'd0;
      reg_awvalid = 1'b0;
      reg_wdata = 32'd0;
      reg_wvalid = 1'b0;
      reg_bready = 1'b0;
      frame_info_size = 'd0;
      frame_info_ch = 'd0;
      frame_info_valid = 1'b0;
      frame_info_out_ready = 1'b1;
      wr_desc_ready = 1'b1;
      wr_tready = 1'b1;
      rd_desc_ready = 1'b1;
      rd_tvalid = 1'b0;
      wr_sts = 'd0;
      rd_sts = 'd0;
      data_desc_ready = 1'b1;
      data_sts = 'd0;
      rx_in_tvalid = 1'b0;
      rx_out_tready = 1'b1;
      tx_in_tvalid = 1'b0;
      tx_out_tready = 1'b1;
    end

    stream_engine #(
        .REG_BASE ( REG_BASE ),
        .DW_LOG ( DW_LOG ),
        .QEW_LOG ( QEW_LOG ),
        .VP_MAP_NUM_LOG ( VP_MAP_NUM_LOG ),
        .QUEUE_DL ( QUEUE_DL ),
        .FRAME_INFO_FIFO_DL ( FRAME_INFO_FIFO_DL ),
        .DESC_BASE_FIFO_DL ( DESC_BASE_FIFO_DL ),
        .DATA_FIFO_DL ( DATA_FIFO_DL ),
        .CPL_FIFO_DL ( CPL_FIFO_DL ),
        .DESC_FIFO_DL ( DESC_FIFO_DL ),
        .STS_FIFO_DL ( STS_FIFO_DL ),
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .CH_BASE ( CH_BASE ),
        .QUEUE_CHECK_TAG ( QUEUE_CHECK_TAG ),
        .QUEUE_READ_TAG ( QUEUE_READ_TAG ),
        .KDIV ( KDIV ),
        .DESC_MAX ( DESC_MAX ),
        .RCBASE ( RCBASE ),
        .RQBASE ( RQBASE ),
        .QESIZE_POS ( QESIZE_POS ),
        .BURST_MAX ( BURST_MAX ),
        .DESC_LEN ( DESC_LEN ),
        .DESC_RQ_DW ( DESC_RQ_DW ),
        .DESC_RQ_DK ( DESC_RQ_DK ),
        .DESC_RC_DW ( DESC_RC_DW ),
        .DESC_RC_DK ( DESC_RC_DK ),
        .D2D_AXI_BASE ( D2D_AXI_BASE ),
        .D2D_AXI_RANGE ( D2D_AXI_RANGE ),
        .IS_TX ( IS_TX ),
        .DISABLE_FRAME_INFO ( DISABLE_FRAME_INFO ),
        .ENABLE_FRAME_INFO_OUT ( ENABLE_FRAME_INFO_OUT ),
        .IGNORE_CPL_SIZE ( IGNORE_CPL_SIZE ),
        .USE_ULTRA_RAM_VPMAP ( USE_ULTRA_RAM_VPMAP ),
        .ACTIVE_LOW_RESET_IN ( ACTIVE_LOW_RESET_IN )
    ) dut (
        .*
    );

   reg [CH_NUM*64-1:0]    stream_req_q_bases;
   reg [CH_NUM*64-1:0]    stream_cpl_q_bases;
   reg [CH_NUM*8-1:0]     stream_req_q_depth;
   reg [CH_NUM*8-1:0]     stream_cpl_q_depth;
   reg [CH_NUM*64-1:0]    stream_req_q_head_tails;
   reg [CH_NUM*64-1:0]    stream_cpl_q_head_tails;
   reg [CH_NUM*64-1:0]    stream_doorbell_bases;

   reg                    done_set_desc_addrs;
   reg                    done_set_vpmaps;
   initial begin
      done_set_desc_addrs = 1'b0;
      done_set_vpmaps = 1'b0;
   end

   // queue check/update packet
   reg [CH_NUM-1:0]   stream_ch_valids;
   reg [CH_NUM-1:0]   stream_ch_d2d_valids;
   reg [CH_NUM-1:0]   stream_ch_check_with_doorbells_reg;
   reg [CH_NUM-1:0]   stream_ch_interrupt_enables_reg;
   reg [CH_NUM_LOG:0] stream_ch_valid_num;
   reg [7:0]          req_queue_head[0:CH_NUM-1];
   reg [7:0]          req_queue_read_pos[0:CH_NUM-1];
   reg [7:0]          req_queue_transfer_idx[0:CH_NUM-1];
   reg [7:0]          req_queue_tail[0:CH_NUM-1];
   reg [7:0]          req_queue_head_rx[0:CH_NUM-1];
   reg [7:0]          req_queue_tail_rx[0:CH_NUM-1];
   reg [7:0]          cpl_queue_head[0:CH_NUM-1];
   reg [7:0]          cpl_queue_tail[0:CH_NUM-1];
   reg [7:0]          cpl_queue_head_rx[0:CH_NUM-1];
   reg [7:0]          cpl_queue_tail_rx[0:CH_NUM-1];
   reg                req_queue_tail_updates[0:CH_NUM-1];
   reg                cpl_queue_head_updates[0:CH_NUM-1];
   reg [7:0]          req_queue_pos_for_frame_info[0:CH_NUM-1];

   reg [CH_NUM_LOG-1:0] check_q_head_tail_ch;
   reg                  is_check_req_head_tail;
   reg [CH_NUM_LOG-1:0] update_q_head_tail_ch;
   reg                  is_update_req_head_tail;
   reg [CH_NUM-1:0]     req_queue_ch;
   reg [15:0]           req_queue_idx;
   reg                  is_check_queue;
   reg                  is_update_queue;
   int                  ch;
   initial begin
      stream_ch_valids = 'd0;
      stream_ch_d2d_valids = 'd0;
      stream_ch_check_with_doorbells_reg = 'd0;
      stream_ch_interrupt_enables_reg = 'd0;
      is_check_queue = 1'b0;
      is_update_queue = 1'b0;
      is_check_req_head_tail = 1'b0;
      is_update_req_head_tail = 1'b0;
   end

   localparam AXI_CH_NUM = 3;

   reg [31:0] axil_write_data[0:AXI_CH_NUM-1][0:255];
   reg [15:0] axil_write_addr[0:AXI_CH_NUM-1][0:255];
   reg [7:0]  axil_write_wpos[0:AXI_CH_NUM-1], axil_write_rpos[0:AXI_CH_NUM-1];
   reg [63:0] axi_read_addr[0:AXI_CH_NUM-1][0:255];
   reg [7:0]    axi_read_len[0:AXI_CH_NUM-1][0:255];
   reg [2:0]    axi_read_size[0:AXI_CH_NUM-1][0:255];
   reg [7:0]    axi_read_wpos[0:AXI_CH_NUM-1], axi_read_rpos[0:AXI_CH_NUM-1];
   reg [DW-1:0] axi_write_data[0:AXI_CH_NUM-1][0:255];
   reg [KW-1:0] axi_write_keep[0:AXI_CH_NUM-1][0:255];
   reg          axi_write_last[0:AXI_CH_NUM-1][0:255];
   reg [63:0]   axi_write_addr[0:AXI_CH_NUM-1][0:255];
   reg [7:0]    axi_write_len[0:AXI_CH_NUM-1][0:255];
   reg [2:0]    axi_write_size[0:AXI_CH_NUM-1][0:255];
   reg [7:0]    axi_write_wpos[0:AXI_CH_NUM-1], axi_write_rpos[0:AXI_CH_NUM-1];
   reg [7:0]    axi_write_wdpos[0:AXI_CH_NUM-1], axi_write_rdpos[0:AXI_CH_NUM-1];
   reg          dma_started;
   wire [8*AXI_CH_NUM-1:0] w_axi_write_wdpos_vec;
   wire [8*AXI_CH_NUM-1:0] w_axi_write_rdpos_vec;
   wire [8*AXI_CH_NUM-1:0] w_axi_write_wpos_vec;
   wire [8*AXI_CH_NUM-1:0] w_axi_write_rpos_vec;
   initial begin
      for (int i=0; i<AXI_CH_NUM; i++) begin
         axil_write_wpos[i] = 'd0;
         axil_write_rpos[i] = 'd0;
         axi_write_wpos[i] = 'd0;
         axi_write_rpos[i] = 'd0;
         axi_write_wdpos[i] = 'd0;
         axi_write_rdpos[i] = 'd0;
      end
      dma_started = 1'b0;
   end
   wire [23:0] axil_write_wposes = {axil_write_wpos[2], axil_write_wpos[1], axil_write_wpos[0]};
   wire [23:0] axil_write_rposes = {axil_write_rpos[2], axil_write_rpos[1], axil_write_rpos[0]};

   generate
      for (genvar i=0; i<AXI_CH_NUM; i++) begin
         assign w_axi_write_wdpos_vec[8*i+:8] = axi_write_wdpos[i];
         assign w_axi_write_rdpos_vec[8*i+:8] = axi_write_rdpos[i];
         assign w_axi_write_wpos_vec[8*i+:8] = axi_write_wpos[i];
         assign w_axi_write_rpos_vec[8*i+:8] = axi_write_rpos[i];
      end
   endgenerate

    // virt/phys address map
    reg [63:0] vaddrs[0:CH_NUM-1];
    reg [31:0] vsizes[0:CH_NUM-1];
    reg [31:0] vaddr_offsets[0:CH_NUM-1];
    reg [63:0] vpmap_vaddrs[0:CH_NUM-1][0:VP_MAP_NUM-1];
    reg [31:0] vpmap_vsizes[0:CH_NUM-1][0:VP_MAP_NUM-1];
    reg [63:0] vpmap_paddrs[0:CH_NUM-1][0:VP_MAP_NUM-1];
    reg        vpmap_valids[0:CH_NUM-1][0:VP_MAP_NUM-1];

    initial begin
        for (int i=0; i<CH_NUM; i++) begin
            for (int j=0; j<VP_MAP_NUM; j++) begin
                vpmap_valids[i][j] = 1'b0;
            end
        end
    end

    // queue data
    reg [63:0] req_queue_addr[0:CH_NUM-1][0:QUEUE_MAX-1];
    reg [31:0] req_queue_size[0:CH_NUM-1][0:QUEUE_MAX-1];
    reg [31:0] req_queue_info_size[0:CH_NUM-1][0:QUEUE_MAX-1];
    reg [31:0] req_queue_stat[0:CH_NUM-1][0:QUEUE_MAX-1];
    reg        req_queue_read[0:CH_NUM-1][0:QUEUE_MAX-1];
    reg [15:0]       req_queue_check_idx[0:CH_NUM-1];
    reg [63:0] cpl_queue_addr[0:CH_NUM-1][0:QUEUE_MAX-1];
    reg [31:0] cpl_queue_size[0:CH_NUM-1][0:QUEUE_MAX-1];
    reg [7:0]  req_inflights[0:CH_NUM-1];

    initial begin
        for (int i=0; i<CH_NUM; i++) begin
            for (int j=0; j<QUEUE_MAX; j++) begin
                req_queue_addr[i][j] = 'd0;
                req_queue_size[i][j] = 'd0;
                req_queue_info_size[i][j] = 'd0;
                req_queue_stat[i][j] = 'd0;
                req_queue_read[i][j] = 'd0;
            end
            req_inflights[i] = 'd0;
        end
    end

    reg [31:0] frame_info_sizes[0:255];
    reg [CH_NUM_LOG-1:0] frame_info_chs[0:255];
    reg [7:0]            frame_info_rpos;
    reg [7:0]            frame_info_wpos;

    initial begin
        frame_info_wpos = 'd0;
    end

   always @(posedge clk) begin
      if (~resetn) begin
         frame_info_rpos <= 'd0;
         frame_info_size <= 'd0;
         frame_info_ch <= 'd0;
         frame_info_valid <= 1'b0;
      end else if (frame_info_rpos != frame_info_wpos) begin
         if (DISABLE_FRAME_INFO == 0 && &rd[8+:FRAME_INFO_BITS]) begin
            frame_info_size <= frame_info_sizes[frame_info_rpos];
            frame_info_ch <= frame_info_chs[frame_info_rpos];
            frame_info_valid <= 1'b1;
            frame_info_rpos <= frame_info_rpos + 1'b1;
         end else begin
            frame_info_valid <= 1'b0;
         end
      end else begin
         frame_info_valid <= 1'b0;
      end
   end

    // cpl q tail update
    reg [31:0] req_head_counts[0:CH_NUM-1]; // initialize and update in the task
    reg [31:0] cpl_tail_counts[0:CH_NUM-1];
    wire [32*CH_NUM-1:0] cpl_tail_counter_vec;
    wire [32*CH_NUM-1:0] req_head_counter_vec;
    wire [8*CH_NUM-1:0] cpl_tail_vec, cpl_head_vec;
    wire [8*CH_NUM-1:0] req_tail_vec, req_head_vec;
    always @(posedge clk) begin
        if (~resetn) begin
            for (int i=0; i<CH_NUM; i++) cpl_tail_counts[i] <= 'd0;
        end else begin
            for (int i=0; i<CH_NUM; i++) begin
                if (cpl_queue_head[i] != cpl_queue_tail[i] && &rd[TAIL_UP_POS+:TAIL_UP_NUM]) begin
                    cpl_queue_tail[i] <= cpl_queue_tail[i] + 1'b1 < stream_cpl_q_depth[i*8+:8] ? cpl_queue_tail[i] + 1'b1 : 'd0;
                    cpl_tail_counts[i] <= cpl_tail_counts[i] + 1'b1;
                    if (stream_ch_check_with_doorbells_reg[i]) begin
                       if (DOORBELL_WITH_AXI > 0) begin
                          axi_write_addr[1][axi_write_wpos[1]] <= {'d0, D2D_AXI_BASE} + CTRL_BASE + ch * 64 + 60;
                          axi_write_len[1][axi_write_wpos[1]] <= 'd0; // 1burst
                          axi_write_size[1][axi_write_wpos[1]] <= 2'd2; // 1burst
                          axi_write_data[1][axi_write_wdpos[1]] <= 'd0;
                          axi_write_keep[1][axi_write_wdpos[1]] <= 'hf;
                          axi_write_last[1][axi_write_wdpos[1]] <= 'h1;
                          axi_write_wpos[1] <= axi_write_wpos[1] + 1'b1;
                          axi_write_wdpos[1] <= axi_write_wdpos[1] + 1'b1;
                       end else begin
                          axil_write_addr[1][axil_write_wpos[1]] <= CTRL_BASE + i * 64 + 60;
                          axil_write_data[1][axil_write_wpos[1]] <= 'd0;
                          axil_write_wpos[1] <= axil_write_wpos[1] + 1'b1;
                       end
                    end
                    $display("%d [%2h]: cpl tail update: %h/%h", $time, i, cpl_queue_head[i], cpl_queue_tail[i]);
                end
            end
        end
    end
    generate
        for (genvar i=0; i<CH_NUM; i++) begin
            assign req_head_counter_vec[i*32+:32] = req_head_counts[i];
            assign cpl_tail_counter_vec[i*32+:32] = cpl_tail_counts[i];
            assign req_head_vec[i*8+:8] = req_queue_head[i];
            assign req_tail_vec[i*8+:8] = req_queue_tail[i];
            assign cpl_head_vec[i*8+:8] = cpl_queue_head[i];
            assign cpl_tail_vec[i*8+:8] = cpl_queue_tail[i];
        end
    endgenerate

    // frame info out
    reg [31:0] frame_info_out_sizes[0:CH_NUM-1][0:255];
    reg [7:0]  out_size_wpos[0:CH_NUM-1];
    reg [7:0]  out_size_rpos[0:CH_NUM-1];
    reg [CH_NUM-1:0] out_size_fulls;
    reg [CH_NUM_LOG-1:0] out_size_ch;
    reg [7:0]            frame_info_wpos_inc;
    initial begin
        for (int i=0; i<CH_NUM; i++) begin
            out_size_wpos[i] = 'd0;
            out_size_rpos[i] = 'd0;
        end
        out_size_fulls = 'd0;
        out_size_ch = 'd0;
   end
   wire [8*CH_NUM-1:0] out_size_wpos_vec = {out_size_wpos[7], out_size_wpos[6], out_size_wpos[5], out_size_wpos[4],
                                            out_size_wpos[3], out_size_wpos[2], out_size_wpos[1], out_size_wpos[0]};
   wire [8*CH_NUM-1:0] out_size_rpos_vec = {out_size_rpos[7], out_size_rpos[6], out_size_rpos[5], out_size_rpos[4],
                                            out_size_rpos[3], out_size_rpos[2], out_size_rpos[1], out_size_rpos[0]};
    // frame info out check
   logic [CH_NUM_LOG-1:0] out_size_cur_ch;
    always @(posedge clk) begin
        frame_info_wpos_inc = 0;
        if (frame_info_out_valid & frame_info_out_ready & stream_ch_valids[frame_info_out_ch]) begin
            if (IS_TX==1 || ~stream_ch_d2d_valids[frame_info_out_ch]) begin
               if (frame_info_out_size !== frame_info_out_sizes[frame_info_out_ch][out_size_rpos[frame_info_out_ch]]) begin
                  $error("%d: frame info out: [%2h]  %h %h", $time, frame_info_out_ch,
                         frame_info_out_size, frame_info_out_sizes[frame_info_out_ch][out_size_rpos[frame_info_out_ch]]);
               end
               out_size_rpos[frame_info_out_ch] <= out_size_rpos[frame_info_out_ch] + 1'b1;
            end
            $display("%d: frame info out [%2h]: %h", $time, frame_info_out_ch, frame_info_out_size);
            if (DISABLE_FRAME_INFO == 0 && ENABLE_FRAME_INFO_OUT == 1) begin
               if (IS_TX==0 && stream_ch_d2d_valids[frame_info_out_ch]) begin
                  out_size_wpos[frame_info_out_ch] <= out_size_wpos[frame_info_out_ch] + 1'b1;
                  $display("%d: A) frame info out [%2h]: %h", $time, frame_info_out_ch, frame_info_out_size);
               end else begin
                  frame_info_sizes[frame_info_wpos] <= req_queue_info_size[frame_info_out_ch][req_queue_pos_for_frame_info[frame_info_out_ch]];
                  req_queue_pos_for_frame_info[frame_info_out_ch] <= (req_queue_pos_for_frame_info[frame_info_out_ch] + 1'b1) % stream_req_q_depth[frame_info_out_ch*8+:8];
                  frame_info_chs[frame_info_wpos] <= frame_info_out_ch;
                  frame_info_wpos_inc++;
               end
            end
        end
        for (int i = 0; i < CH_NUM; i++) begin
           out_size_cur_ch = i + out_size_ch;
           if (out_size_wpos[out_size_cur_ch] != out_size_rpos[out_size_cur_ch] && stream_ch_d2d_valids[out_size_cur_ch] && IS_TX==0) begin
              if (req_queue_pos_for_frame_info[out_size_cur_ch] != req_queue_head[out_size_cur_ch] &&
                  ((frame_info_wpos+frame_info_wpos_inc+1)&255) != frame_info_rpos) begin
                 frame_info_sizes[(frame_info_wpos+frame_info_wpos_inc) & 255] <= req_queue_info_size[out_size_cur_ch][req_queue_pos_for_frame_info[out_size_cur_ch]];
                 frame_info_chs[(frame_info_wpos+frame_info_wpos_inc) & 255] <= out_size_cur_ch;
                 req_queue_pos_for_frame_info[out_size_cur_ch] <= (req_queue_pos_for_frame_info[out_size_cur_ch] + 1'b1) % stream_req_q_depth[out_size_cur_ch*8+:8];
                 $display("%d: frame info size set [%2h] (%3d): %h", $time, out_size_cur_ch,
                          (frame_info_wpos+frame_info_wpos_inc) & 255, req_queue_info_size[out_size_cur_ch][req_queue_pos_for_frame_info[out_size_cur_ch]]);
                 frame_info_wpos_inc++;
                 out_size_rpos[out_size_cur_ch] <= out_size_rpos[out_size_cur_ch] + 1'b1;
                 out_size_ch <= out_size_cur_ch;
                 break;
              end
           end
        end
        frame_info_wpos <= frame_info_wpos + frame_info_wpos_inc;
        for (int i=0; i<CH_NUM; i++) begin
           out_size_fulls[i] <= (out_size_wpos[i] + 1'b1 == out_size_rpos[i]) || (out_size_wpos[i] + 2'd2 == out_size_rpos[i]);
        end
        if (resetn) frame_info_out_ready <= (FRAME_INFO_READY_BITS > 0 ? &rd[9+:FRAME_INFO_READY_BITS_MOD] : 1'b1) && ~|out_size_fulls;
    end

   // interrupt check
   reg [CH_NUM-1:0] irq_ack_done;
   always @(posedge clk) begin
      if (~resetn) begin
         irq_ack <= 'd0;
         irq_ack_done <= 'd0;
      end else begin
         if (|irq_out && |(irq_out & ~stream_ch_interrupt_enables_reg)) begin
            $error("%d: irq channel wrong: %h %h", $time, irq_out, stream_ch_interrupt_enables_reg);
         end
         irq_ack <= (irq_out & stream_ch_interrupt_enables_reg & ~irq_ack_done);
         irq_ack_done <= irq_out & stream_ch_interrupt_enables_reg;
      end
   end

   // rd dma
   reg [63:0] rd_dma_addrs[0:255];
   reg [27:0] rd_dma_lengths[0:255];
   reg [7:0]  rd_dma_wpos, rd_dma_rpos;
   initial begin
      rd_dma_wpos = 'd0;
      rd_dma_rpos = 'd0;
   end

   reg        rd_desc_ready_d1;
   wire       rd_desc_ready_mod = rd_desc_ready | rd_desc_ready_d1;
   always @(posedge clk) begin
      if (~resetn) begin
         rd_desc_ready_d1 <= 1'b0;
      end else begin
         rd_desc_ready_d1 <= rd_desc_ready;
         if (rd_desc_load & rd_desc_ready_mod) begin
            rd_dma_addrs[rd_dma_wpos] <= rd_desc_src_addr;
            rd_dma_lengths[rd_dma_wpos] <= rd_desc_len;
            if (~rd_desc_ctl[4]) $error("%d: rd desc ctrl: no last bit set", $time);
            rd_dma_wpos <= rd_dma_wpos + 1'b1;
         end
         rd_desc_ready <= DESC_READY_BITS > 0 ? &rd[3+:DESC_READY_BITS_MOD] : 1'b1;
      end
   end

   // rd dma response
   logic [63:0] rd_dma_cur_addr;
   logic [27:0] rd_dma_cur_length;
   logic        rd_dma_rvalid;
   logic [DW-1:0] rd_dma_rdata;
   logic [KW-1:0] rd_dma_rkeep;
   logic          rd_dma_rlast;
   logic [TRANSFER_MAX_LOG-1:0] rd_dma_qpos;
   logic                        rd_dma_addr_hit;
   reg [63:0]   rd_dma_addr_save = 0;
   reg [27:0]   rd_dma_length_save = 0;
   always @(posedge clk) begin
      if (~resetn) begin
         rd_dma_length_save <= 'd0;
         rd_dma_addr_save <= 'd0;
         rd_sts <= 'd0;
      end else if (rd_dma_wpos !== rd_dma_rpos || |rd_dma_length_save || rd_tvalid || |rd_sts) begin
         if (~|rd_dma_length_save && rd_dma_rpos !== rd_dma_wpos) begin
            rd_dma_cur_length = rd_dma_lengths[rd_dma_rpos];
            rd_dma_cur_addr = rd_dma_addrs[rd_dma_rpos];
            rd_dma_rpos <= rd_dma_rpos + 1'b1;
         end else begin
            rd_dma_cur_length = rd_dma_length_save;
            rd_dma_cur_addr = rd_dma_addr_save;
         end
         if (|rd_dma_cur_length) begin
            rd_dma_rvalid = RD_VALID_BITS > 0 ? &rd[15+:RD_VALID_BITS_MOD] : 1'b1;
            rd_dma_rkeep = ({{KW{1'b0}}, 1'b1} << (rd_dma_cur_length < KW ? rd_dma_cur_length : KW)) - 1'b1;
            rd_dma_addr_hit = 0;
            for (int ch=0; ch<CH_NUM; ch++) begin
               if (stream_req_q_bases[ch*64+:64] <= rd_dma_cur_addr &&
                   rd_dma_cur_addr < stream_req_q_bases[ch*64+:64] + stream_req_q_depth[ch*8+:8] * QEW) begin
                  rd_dma_qpos = (rd_dma_cur_addr - stream_req_q_bases[ch*64+:64]) >> QEW_LOG;
                  rd_dma_rdata = {'d0, 32'd1, 32'd0, req_queue_size[ch][rd_dma_qpos], req_queue_addr[ch][rd_dma_qpos]};
                  req_queue_read_pos[ch] <= (rd_dma_qpos + 1'b1) % stream_req_q_depth[ch*8+:8];
                  $display("%d: req queue read pos inc [%2h]: %h", $time, ch, (rd_dma_qpos + 1'b1) % stream_req_q_depth[ch*8+:8]);
                  rd_dma_addr_hit = 1;
                  break;
               end else if (stream_req_q_head_tails[ch*64+:64] === rd_dma_cur_addr) begin
                  if (rd_dma_cur_length > 4) begin
                     rd_dma_rdata = {'d0, req_queue_tail[ch], 24'd0, req_queue_head[ch]};
                  end else begin
                     rd_dma_rdata = {'d0, req_queue_head[ch]};
                  end
                  rd_dma_addr_hit = 1;
                  break;
               end else if (stream_req_q_head_tails[ch*64+:64] + 4 === rd_dma_cur_addr) begin
                  rd_dma_rdata = {'d0, req_queue_tail[ch]};
                  rd_dma_addr_hit = 1;
                  break;
               end else if (stream_cpl_q_head_tails[ch*64+:64] === rd_dma_cur_addr) begin
                  if (rd_dma_cur_length > 4) begin
                     rd_dma_rdata = {'d0, cpl_queue_tail[ch], 24'd0, cpl_queue_head[ch]};
                  end else begin
                     rd_dma_rdata = {'d0, cpl_queue_head[ch]};
                  end
                  rd_dma_addr_hit = 1;
                  break;
               end else if (stream_cpl_q_head_tails[ch*64+:64] + 4 === rd_dma_cur_addr) begin
                  rd_dma_rdata = {'d0, cpl_queue_tail[ch]};
                  rd_dma_addr_hit = 1;
                  break;
               end
            end
            if (~rd_dma_addr_hit) $error("%d: rd dma addr not hit: %h", $time, rd_dma_cur_addr);
            rd_dma_rlast = rd_dma_cur_length <= KW;
            if (rd_dma_rvalid) begin
               rd_tdata <= rd_dma_rdata;
               rd_tkeep <= rd_dma_rkeep;
               rd_tlast <= rd_dma_rlast;
               rd_dma_cur_length = rd_dma_cur_length <= KW ? 0 : rd_dma_cur_length - KW;
               rd_dma_cur_addr = rd_dma_cur_addr + KW;
            end
            rd_tvalid <= rd_dma_rvalid;
            rd_dma_length_save <= rd_dma_cur_length;
            rd_dma_addr_save <= rd_dma_cur_addr;
         end else begin
            rd_tvalid <= rd_tvalid & ~rd_tready;
         end
         rd_sts <=  (rd_tvalid & rd_tready & rd_tlast) ? 8'h8 : 8'h0;
      end
   end

   // wr dma
   reg [63:0] wr_dma_addrs[0:255];
   reg [27:0] wr_dma_lengths[0:255];
   reg        wr_dma_lasts[0:255];
   reg [7:0]  wr_dma_wpos, wr_dma_rpos;
   reg [DW-1:0] wr_dma_data[0:255];
   reg [KW-1:0] wr_dma_keeps[0:255];
   reg          wr_dma_dlasts[0:255];
   reg [7:0]    wr_dma_wdpos, wr_dma_rdpos;

   initial begin
      wr_dma_wpos = 'd0;
      wr_dma_rpos = 'd0;
      wr_dma_wdpos = 'd0;
      wr_dma_rdpos = 'd0;
   end

   reg        wr_desc_ready_d1;
   wire       wr_desc_ready_mod = wr_desc_ready | wr_desc_ready_d1;
   always @(posedge clk) begin
      if (~resetn) begin
         wr_desc_ready_d1 <= 1'b0;
      end else begin
         wr_desc_ready_d1 <= wr_desc_ready;
         if (wr_desc_load & wr_desc_ready_mod) begin
            wr_dma_addrs[wr_dma_wpos] <= wr_desc_dst_addr;
            wr_dma_lengths[wr_dma_wpos] <= wr_desc_len;
            wr_dma_lasts[wr_dma_wpos] <= wr_desc_ctl[4];
            wr_dma_wpos <= wr_dma_wpos + 1'b1;
         end
         wr_desc_ready <= DESC_READY_BITS > 0 ? &rd[5+:DESC_READY_BITS_MOD] : 1'b1;
         if (wr_tvalid && wr_tready) begin
            wr_dma_data[wr_dma_wdpos] <= wr_tdata;
            wr_dma_keeps[wr_dma_wdpos] <= wr_tkeep;
            wr_dma_dlasts[wr_dma_wdpos] <= wr_tlast;
            wr_dma_wdpos <= wr_dma_wdpos + 1'b1;
         end
         wr_tready <= WR_READY_BITS > 0 ? &rd[7+:WR_READY_BITS_MOD] : 1'b1;
      end
   end

   // wr dma check/update
   logic [CH_NUM-1:0] rx_doorbells;
   logic [63:0] wr_addr;
   logic [27:0] wr_len;
   logic [DW-1:0] wr_data;
   logic [KW-1:0] wr_keep;
   logic          wr_last;
   logic          wr_hit;
   logic [TRANSFER_MAX_LOG-1:0] wr_cpl_qpos;
   always @(posedge clk) begin
      if (~resetn) begin
         rx_doorbells <= 'd0;
      end
      if (wr_dma_wpos !== wr_dma_rpos && wr_dma_wdpos !== wr_dma_rdpos) begin
         wr_addr = wr_dma_addrs[wr_dma_rpos];
         wr_len = wr_dma_lengths[wr_dma_rpos];
         wr_data = wr_dma_data[wr_dma_rdpos];
         wr_keep = wr_dma_keeps[wr_dma_rdpos];
         wr_last = wr_dma_dlasts[wr_dma_rdpos];
         wr_dma_rdpos <= wr_dma_rdpos + 1'b1;
         if (wr_last) begin
            wr_dma_rpos <= wr_dma_rpos + 1'b1;
         end
         wr_sts <= wr_last ? 8'h8 : 8'h0;
         wr_hit = 0;
         if (wr_len == 4) begin
            if (wr_keep !== 'hf || ~wr_last) begin
               $error("%d: write dma sideband: len: %h, keep: %h, last: %h, data: %h", $time, wr_len, wr_keep, wr_last, wr_data);
            end
            for (int i=0; i<CH_NUM; i++) begin
               if (wr_addr === stream_req_q_head_tails[64*i+:64]+4) begin
                  req_queue_tail[i] <= wr_data[7:0];
                  $display("%d: [%2h] req queue tail: %2d", $time, i, wr_data[7:0]);
                  wr_hit = 1;
                  break;
               end else if (wr_addr == stream_cpl_q_head_tails[64*i+:64]) begin
                  cpl_queue_head[i] <= wr_data[7:0];
                  $display("%d: [%2h] cpl queue head: %2d", $time, i, wr_data[7:0]);
                  wr_hit = 1;
                  break;
               end else if (wr_addr == stream_doorbell_bases[64*i+:64]) begin
                  $display("%d: [%2h] doorbell kick", $time, i);
                  rx_doorbells[i] <= 1'b1;
                  wr_hit = 1;
                  break;
               end
            end
         end else if (wr_len == QEW) begin
            if (wr_keep !== {'d0, {QEW{1'b1}}} || ~wr_last) begin
               $error("%d: write dma sideband: len: %h, keep: %h, last: %h", $time, wr_len, wr_keep, wr_last);
            end
            for (int i=0; i<CH_NUM; i++) begin
               if (stream_cpl_q_bases[64*i+:64] <= wr_addr &&
                   wr_addr < stream_cpl_q_bases[64*i+:64] + stream_cpl_q_depth[8*i+:8] * QEW) begin
                  wr_cpl_qpos = (wr_addr - stream_cpl_q_bases[64*i+:64]) >> QEW_LOG;
                  if (req_queue_addr[i][req_queue_check_idx[i]] !== wr_data[63:0] ||
                      (req_queue_size[i][req_queue_check_idx[i]] !== wr_data[95:64] &&
                       req_queue_info_size[i][req_queue_check_idx[i]] !== wr_data[95:64]) ||
                      wr_data[159:128] !== 'd2) begin
                     $error("%d: [%2h] (%2d) cpl queue check: %h %h, %h %h %h, %h", $time, i, wr_cpl_qpos,
                            wr_data[63:0], req_queue_addr[i][wr_cpl_qpos],
                            wr_data[95:64], req_queue_size[i][wr_cpl_qpos], req_queue_info_size[i][wr_cpl_qpos],
                            wr_data[159:128]);
                  end
                  req_queue_check_idx[i] <= (req_queue_check_idx[i] + 1'b1) % stream_req_q_depth[i*8+:8];
                  req_queue_stat[i][req_queue_check_idx[i]] <= 'd0;
                  wr_hit = 1;
                  break;
               end
            end
         end else begin
            $error("%d: unknown write dma size: %h, addr: %h", $time, wr_len, wr_addr);
            wr_hit = 1;
         end
         if (~wr_hit) begin
            $error("%d: unknown wirte dma addr: %h size: %h", $time, wr_addr, wr_len);
         end
      end else begin
         wr_sts <= 8'h0;
      end
   end

   // data dma
   reg [63:0] data_dma_addrs[0:255];
   reg [27:0] data_dma_lengths[0:255];
   reg        data_dma_lasts[0:255];
   reg [7:0]  data_dma_wpos, data_dma_rpos, data_dma_cpos;
   reg [DW-1:0] data_dma_data[0:255];
   reg [KW-1:0] data_dma_keeps[0:255];
   reg          data_dma_dlasts[0:255];
   reg [7:0]    data_dma_wdpos, data_dma_rdpos;
   logic [DW-1:0] rx_mm_data[0:255];
   logic [KW-1:0] rx_mm_keep[0:255];
   logic          rx_mm_last[0:255];
   logic          rx_mm_eof[0:255];
   logic [7:0]    rx_mm_wpos, rx_mm_rpos;
   logic [DW-1:0] rx_st_out_data[0:255];
   logic [KW-1:0] rx_st_out_keep[0:255];
   logic          rx_st_out_last[0:255];
   logic          rx_st_out_eof[0:255];
   logic [7:0]    rx_st_out_wpos, rx_st_out_rpos;

   initial begin
      data_dma_wpos = 'd0;
      data_dma_rpos = 'd0;
      data_dma_cpos = 'd0;
      data_dma_wdpos = 'd0;
      data_dma_rdpos = 'd0;
      rx_mm_wpos = 'd0;
      rx_mm_rpos = 'd0;
      rx_st_out_wpos = 'd0;
      rx_st_out_rpos = 'd0;
   end

   reg        data_desc_ready_d1;
   wire       data_desc_ready_mod = data_desc_ready | data_desc_ready_d1;
   reg [31:0] tx_out_size;
   logic [DW-1:0] tx_out_mask;
   logic [KW_LOG:0] tx_out_bytes;
   always @(posedge clk) begin
      if (~resetn) begin
         data_desc_ready_d1 <= 1'b0;
         tx_out_size <= 'd0;
      end else begin
         data_desc_ready_d1 <= data_desc_ready;
         if (data_desc_load & data_desc_ready_mod) begin
            if (IS_TX == 1) begin
               if (data_desc_dst_addr !== data_dma_addrs[data_dma_rpos] ||
                   data_desc_len !== data_dma_lengths[data_dma_rpos] ||
                   data_desc_ctl[4] !== data_dma_lasts[data_dma_rpos]) begin
                  $error("%d: tx desc (%3d) wrong: %h %h, %h %h, %h %h", $time, data_dma_rpos,
                         data_desc_dst_addr, data_dma_addrs[data_dma_rpos],
                         data_desc_len, data_dma_lengths[data_dma_rpos],
                         data_desc_ctl, data_dma_lasts[data_dma_rpos]);
               end else begin
                  $display("%d: tx desc (%3d): %h %h, %h %h, %h %h", $time, data_dma_rpos,
                           data_desc_dst_addr, data_dma_addrs[data_dma_rpos],
                           data_desc_len, data_dma_lengths[data_dma_rpos],
                           data_desc_ctl, data_dma_lasts[data_dma_rpos]);
               end
               data_dma_rpos <= data_dma_rpos + 1'b1;
            end else begin
               data_dma_addrs[data_dma_wpos] <= IS_TX == 1 ? data_desc_dst_addr : data_desc_src_addr;
               data_dma_lengths[data_dma_wpos] <= data_desc_len;
               data_dma_lasts[data_dma_wpos] <= data_desc_ctl[4];
               data_dma_wpos <= data_dma_wpos + 1'b1;
            end
         end
         data_desc_ready <= (DESC_READY_BITS > 0 ? &rd[9+:DESC_READY_BITS_MOD] : 1'b1) &&
                            ((data_dma_wpos + 1) & 255) != data_dma_rpos &&
                            ((data_dma_wpos + 2) & 255) != data_dma_rpos;
         if (tx_out_tvalid && tx_out_tready) begin
            tx_out_bytes = 'd0;
            for (int i=0; i<KW; i++) begin
               tx_out_bytes += tx_out_tkeep[i];
               tx_out_mask[i*8+:8] = {8{tx_out_tkeep[i]}};
            end
            if ((tx_out_tdata & tx_out_mask) !== (data_dma_data[data_dma_rdpos] & tx_out_mask) ||
                tx_out_tkeep !== data_dma_keeps[data_dma_rdpos] ||
                tx_out_tlast !== data_dma_dlasts[data_dma_rdpos]) begin
               $error("%d: tx out: %h %h, %h %h, %h %h", $time,
                      tx_out_tdata, data_dma_data[data_dma_rdpos],
                      tx_out_tkeep, data_dma_keeps[data_dma_rdpos],
                      tx_out_tlast, data_dma_dlasts[data_dma_rdpos]);
            end
            tx_out_size += tx_out_bytes;
            if (tx_out_tlast) begin
               if (data_dma_wpos === data_dma_cpos ||
                   tx_out_size !== data_dma_lengths[data_dma_cpos]) begin
                  $error("%d: tx dma length wrong: %h %h", $time, tx_out_size, data_dma_lengths[data_dma_cpos]);
               end
               tx_out_size = 'd0;
               data_dma_cpos <= data_dma_cpos + 1'b1;
            end
            data_dma_rdpos <= data_dma_rdpos + 1'b1;
         end
         tx_out_tready <= WR_READY_BITS > 0 ? &rd[11+:WR_READY_BITS_MOD] : 1'b1;
         if (IS_TX>0) begin
            data_sts <= tx_out_tvalid && tx_out_tready && tx_out_tlast ? 8'h8 : 8'h0;
         end else begin
            data_sts <= rx_in_tvalid && rx_in_tready && rx_in_tlast ? 8'h8 : 8'h0;
         end
      end
   end

   // axi / axil write
   reg [3:0] axil_ch;
   reg       axil_writing;
   always @(posedge clk) begin
      if (~resetn) begin
         axil_ch <= 'd0;
         axil_writing <= 1'b0;
      end else if (dma_started) begin
         if ((~reg_awvalid || reg_awready) && (~reg_wvalid || reg_wready)) begin
            if (~axil_writing && &rd[15+:AXIL_BITS] && axil_write_wpos[axil_ch] != axil_write_rpos[axil_ch]) begin
               reg_awaddr <= axil_write_addr[axil_ch][axil_write_rpos[axil_ch]];
               reg_wdata <= axil_write_data[axil_ch][axil_write_rpos[axil_ch]];
               reg_awvalid <= 1'b1;
               reg_wvalid <= 1'b1;
               axil_write_rpos[axil_ch] <= axil_write_rpos[axil_ch] + 1'b1;
               axil_writing <= 1'b1;
               $display("%d: axil_write: %2h (%3d) %h %h", $time, axil_ch, axil_write_rpos[axil_ch],
                        axil_write_addr[axil_ch][axil_write_rpos[axil_ch]], axil_write_data[axil_ch][axil_write_rpos[axil_ch]]);
            end else begin
               axil_ch <= (axil_ch + 1) % AXI_CH_NUM;
               reg_awvalid <= 1'b0;
               reg_wvalid <= 1'b0;
            end
         end else begin
            reg_awvalid <= reg_awvalid & ~reg_awready;
            reg_wvalid <= reg_wvalid & ~reg_wready;
         end
         if (reg_bvalid & reg_bready) begin
            axil_writing <= 1'b0;
         end
         reg_bready <= &rd[18+:AXIL_BITS];
      end
   end

   reg [3:0] axi_ch;
   reg [3:0] axi_dch;
   reg       axi_awrite;
   reg       axi_writing;
   logic [3:0] axi_cur_dch;
   always @(posedge clk) begin
      if (~resetn) begin
         axi_ch <= 'd0;
         axi_awrite <= 1'b0;
         axi_dch <= 'd0;
         axi_writing <= 1'b0;
      end else if (dma_started) begin
         if (~axi_awvalid || axi_awready) begin
            if (~axi_awrite && &rd[15+:AXI_ABITS] && axi_write_wpos[axi_ch] != axi_write_rpos[axi_ch]) begin
               axi_awaddr <= axi_write_addr[axi_ch][axi_write_rpos[axi_ch]];
               axi_awlen <= axi_write_len[axi_ch][axi_write_rpos[axi_ch]];
               axi_awsize <= axi_write_size[axi_ch][axi_write_rpos[axi_ch]];
               axi_awvalid <= 1'b1;
               axi_write_rpos[axi_ch] <= axi_write_rpos[axi_ch] + 1'b1;
               axi_awrite <= 1'b1;
               $display("%d: axi_write addr: %2h (%3d) %h %h %h", $time, axi_ch, axi_write_rpos[axi_ch],
                        axi_write_addr[axi_ch][axi_write_rpos[axi_ch]], axi_write_len[axi_ch][axi_write_rpos[axi_ch]],
                        axi_write_size[axi_ch][axi_write_rpos[axi_ch]]);
            end else begin
               if (~axi_awrite) axi_ch <= (axi_ch + 1) % AXI_CH_NUM;
               axi_awvalid <= 1'b0;
            end
         end
         if (~axi_wvalid || axi_wready) begin
            if (AXI_DBITS>0 ? &rd[12+:AXI_DBITS_MOD] : 1'b1) begin
               if (~axi_writing && axi_awrite && axi_write_wdpos[axi_ch] != axi_write_rdpos[axi_ch]) begin
                  axi_dch <= axi_ch;
                  axi_cur_dch = axi_ch;
                  axi_awrite <= 1'b0;
                  axi_ch <= (axi_ch + 1) % AXI_CH_NUM;
               end else if (axi_writing && axi_write_wdpos[axi_dch] != axi_write_rdpos[axi_dch]) begin
                  axi_cur_dch = axi_dch;
               end else begin
                  axi_cur_dch = 'hf;
               end
               if (axi_cur_dch < AXI_CH_NUM) begin
                  axi_wdata <= axi_write_data[axi_cur_dch][axi_write_rdpos[axi_cur_dch]];
                  axi_wstrb <= axi_write_keep[axi_cur_dch][axi_write_rdpos[axi_cur_dch]];
                  axi_wlast <= axi_write_last[axi_cur_dch][axi_write_rdpos[axi_cur_dch]];
                  axi_wvalid <= 1'b1;
                  axi_write_rdpos[axi_cur_dch] <= axi_write_rdpos[axi_cur_dch] + 1'b1;
                  axi_writing <= ~axi_write_last[axi_cur_dch][axi_write_rdpos[axi_cur_dch]];
                  $display("%d: axi_write data: %2h (%3d) %h %h %h", $time, axi_cur_dch, axi_write_rdpos[axi_cur_dch],
                           axi_write_data[axi_cur_dch][axi_write_rdpos[axi_cur_dch]], axi_write_keep[axi_cur_dch][axi_write_rdpos[axi_cur_dch]],
                           axi_write_last[axi_cur_dch][axi_write_rdpos[axi_cur_dch]]);
               end else begin
                  axi_wvalid <= 1'b0;
               end
            end else begin
               axi_wvalid <= 1'b0;
            end
         end
         axi_bready <= &rd[19+:AXI_BBITS];
      end
   end

   reg [7:0] cpl_update_pos[0:255];
   reg [CH_NUM_LOG-1:0] cpl_update_ch[0:255];
   reg [7:0] cpl_update_wpos, cpl_update_rpos;
   always @(posedge clk) begin
      if (~resetn) begin
         cpl_update_wpos <= 'd0;
         cpl_update_rpos <= 'd0;
      end else begin
         if (cpl_update_rpos != cpl_update_wpos &&
             cpl_update_pos[cpl_update_rpos] == axi_write_rdpos[2]) begin
            stream_cpl_update_ch <= cpl_update_ch[cpl_update_rpos];
            stream_cpl_update <= 1'b1;
            cpl_update_rpos <= cpl_update_rpos + 1'b1;
         end else begin
            stream_cpl_update <= 1'b0;
         end
      end
   end

   // axi read
   reg [CH_NUM_LOG-1:0] axi_check_ch;
   reg                  axi_check_is_cpl;
   reg                  axi_checking;
   reg [CH_NUM_LOG-1:0] axi_read_ch;
   reg                  axi_reading;
   reg [CH_NUM_LOG-1:0] doorbell_ch;
   reg [CH_NUM_LOG-1:0] axi_no_doorbell_ch;
   always @(rx_doorbells) begin
      for (int i=0; i<CH_NUM; i++) begin
         if (rx_doorbells[i] ) begin
            doorbell_ch = i;
            break;
         end
      end
   end
   always @(posedge clk) begin
      if (~resetn) begin
         axi_checking <= 1'b0;
         axi_check_is_cpl <= 1'b0;
         axi_read_ch <= 'd0;
         axi_reading <= 1'b0;
         axi_no_doorbell_ch <= 'd0;
         axi_arid <= 'd0;
         axi_arcache <= 'd0;
         axi_arburst <= 'd0;
         axi_arlock <= 1'b0;
         axi_arprot <= 'd0;
      end else if (IS_TX == 0 && dma_started) begin
         if (axi_check_is_cpl && ~axi_checking && (~axi_arvalid || axi_arready)) begin
            axi_araddr <= {'d0,  D2D_AXI_BASE} + QUEUE_HEAD_TAIL_BASE + axi_check_ch * 16 + 8; // cpl q head/tail
            axi_arlen <= 'd0;
            axi_arid <= 'd1;
            axi_arsize <= 3'd3;
            axi_arvalid <= 1'b1;
            axi_checking <= 1'b1;
         end else if (|rx_doorbells && ~axi_checking && (~axi_arvalid || axi_arready)) begin
            axi_check_ch <= doorbell_ch;
            axi_araddr <= {'d0,  D2D_AXI_BASE} + QUEUE_HEAD_TAIL_BASE + doorbell_ch * 16; // req q head
            axi_arlen <= 'd0;
            axi_arid <= 'd0;
            axi_arsize <= 3'd3;
            axi_arvalid <= 1'b1;
            axi_checking <= 1'b1;
            rx_doorbells[doorbell_ch] <= 1'b0;
         end else if (~stream_ch_check_with_doorbells_reg[axi_no_doorbell_ch] && ~axi_check_is_cpl &&
                      stream_ch_d2d_valids[axi_no_doorbell_ch] && ~axi_checking && (~axi_arvalid || axi_arready)) begin
            axi_check_ch <= axi_no_doorbell_ch;
            axi_araddr <= {'d0,  D2D_AXI_BASE} + QUEUE_HEAD_TAIL_BASE + axi_no_doorbell_ch * 16; // req q head
            axi_arlen <= 'd0;
            axi_arid <= 'd0;
            axi_arsize <= 3'd3;
            axi_arvalid <= 1'b1;
            axi_checking <= 1'b1;
            axi_no_doorbell_ch <= axi_no_doorbell_ch + 1'b1;
         end else if (req_queue_head_rx[axi_read_ch] != req_queue_read_pos[axi_read_ch] && stream_ch_d2d_valids[axi_read_ch] &&
                      ((cpl_queue_head_rx[axi_read_ch] + 1) % stream_cpl_q_depth[axi_read_ch*8+:8]) != cpl_queue_tail_rx[axi_read_ch] &&
                      stream_ch_d2d_valids[axi_read_ch] && ~axi_reading && (~axi_arvalid || axi_arready)) begin
            axi_araddr <= {'d0, D2D_AXI_BASE} + QUEUE_BASE + (axi_read_ch * 2 * QUEUE_DEPTH + req_queue_read_pos[axi_read_ch]) * QEW;
            axi_arlen <= 'd0;
            axi_arid <= 'd2;
            axi_arsize <= QEW_LOG;
            axi_arvalid <= 1'b1;
            axi_reading <= 1'b1;
         end else begin
            axi_arvalid <= axi_arvalid & ~axi_arready;
            if (~axi_reading) axi_read_ch <= axi_read_ch + 1'b1;
         end
         if (~axi_checking && ~axi_check_is_cpl &&
             ~(~stream_ch_check_with_doorbells_reg[axi_no_doorbell_ch] && ~axi_check_is_cpl &&
               stream_ch_d2d_valids[axi_no_doorbell_ch] && ~axi_checking && (~axi_arvalid || axi_arready))) begin
            axi_no_doorbell_ch <= axi_no_doorbell_ch + 1'b1;
         end
         if (axi_rvalid && axi_rready) begin
            if (axi_checking && axi_rid == 'd0) begin
               req_queue_head_rx[axi_check_ch] <= axi_rdata[7:0];
               req_queue_tail_rx[axi_check_ch] <= axi_rdata[39:32];
               axi_checking <= 1'b0;
               axi_check_is_cpl <= ~axi_check_is_cpl;
            end else if (axi_checking && axi_rid == 'd1) begin
               cpl_queue_head_rx[axi_check_ch] <= axi_rdata[7:0];
               cpl_queue_tail_rx[axi_check_ch] <= axi_rdata[39:32];
               axi_checking <= 1'b0;
               axi_check_is_cpl <= ~axi_check_is_cpl;
            end else if (axi_reading && axi_rid == 'd2) begin
               if (req_queue_info_size[axi_read_ch][req_queue_read_pos[axi_read_ch]] !== axi_rdata[64+:32]) begin
                  $error("%d: read qe [%2h] (%2d): size %h %h", $time, axi_read_ch, req_queue_read_pos[axi_read_ch], axi_rdata[64+:32],
                         req_queue_info_size[axi_read_ch][req_queue_read_pos[axi_read_ch]]);
               end
               $display("%d: read qe [%2h] (%2d): size %h %h", $time, axi_read_ch, req_queue_read_pos[axi_read_ch], axi_rdata[64+:32],
                        req_queue_info_size[axi_read_ch][req_queue_read_pos[axi_read_ch]]);
               req_queue_read_pos[axi_read_ch] <= (req_queue_read_pos[axi_read_ch] + 1'b1) % stream_req_q_depth[axi_read_ch*8+:8];
               axi_reading <= 1'b0;
               axi_read_ch <= axi_read_ch + 1'b1;
            end
         end
         axi_rready <= AXI_RBITS > 0 ? &rd[19+:AXI_RBITS_MOD] : 1'b1;
      end
   end

   // rx out check
   always @(posedge clk) begin
      if (resetn && rx_out_tvalid && rx_out_tready) begin
         if (rx_out_tdata === rx_st_out_data[rx_st_out_rpos]) begin
            if (rx_out_tkeep !== rx_st_out_keep[rx_st_out_rpos] ||
                rx_out_tlast !== rx_st_out_last[rx_st_out_rpos] ||
                rx_out_eof !== rx_st_out_eof[rx_st_out_rpos]) begin
               $error("%d: rx st out: %h %h, %h %h, %h %h, %h %h", $time,
                      rx_out_tdata, rx_st_out_data[rx_st_out_rpos],
                      rx_out_tkeep, rx_st_out_keep[rx_st_out_rpos],
                      rx_out_tlast, rx_st_out_last[rx_st_out_rpos], rx_out_eof, rx_st_out_eof[rx_st_out_rpos]);
            end
            rx_st_out_rpos <= rx_st_out_rpos + 1'b1;
         end else if (rx_out_tdata === rx_mm_data[rx_mm_rpos]) begin
            if (rx_out_tkeep !== rx_mm_keep[rx_mm_rpos] ||
                rx_out_tlast !== rx_mm_last[rx_mm_rpos] ||
                rx_out_eof !== rx_mm_eof[rx_mm_rpos]) begin
               $error("%d: rx mm out: %h %h, %h %h, %h %h, %h %h", $time,
                      rx_out_tdata, rx_mm_data[rx_mm_rpos],
                      rx_out_tkeep, rx_mm_keep[rx_mm_rpos],
                      rx_out_tlast, rx_mm_last[rx_mm_rpos], rx_out_eof, rx_mm_eof[rx_mm_rpos]);
            end
            rx_mm_rpos <= rx_mm_rpos + 1'b1;
         end else begin
            $error("%d: rx out wrong: %h %h %h", $time, rx_out_tdata,
                   rx_st_out_data[rx_st_out_rpos], rx_mm_data[rx_mm_rpos]);
         end
      end
      rx_out_tready <= DATA_READY_BITS>0 ? &rd[12+:DATA_READY_BITS_MOD] : 1'b1;
   end

    task static initialize_queues();
        int          i, j;
        logic [31:0] wdata;
        // initialize registers
        @(posedge clk) stream_ch_valid_num <= 'd0;
        for (i=0; i<CH_NUM; i++) begin
            @(posedge clk) begin
                stream_ch_valids[i] <= 1'b0;
                reg_bready <= 1'b0;
            end
            for (j=2; j<17; j++) begin
                @(posedge clk) begin
                    reg_awaddr <= REG_BASE + VPMAP_MAX + (i * 64) + (j & 15) * 4;
                    wdata = j == 2 || j == 4 || j == 6 || j == 8 || j == 12 ? {rd[31:5], 5'd0} :
                            j == 10 || j == 11 ? (rd & 32'h0f0f) | 32'h0404 :
                            j == 16 && ENABLE_D2D==0 ? rd & 32'hffffffef : rd;
                    reg_wdata <= FIXED_CH_VALIDS>0 && j==16 ? {rd[31:1], CH_VALIDS[i]} :
                                 j==14 && ENABLE_CHECK_WITH_DOORBELL == 0 ? wdata & 32'hffffffef :
                                 j==10 ? 32'h00000808 :
                                 j==16 && ENABLE_D2D==0 ? wdata & 32'hffffffef : wdata;
                    {reg_awvalid, reg_wvalid} <= j==15 ? 2'd0 : 2'd3;
                    case(j)
                        2: stream_req_q_bases[i*64+:32] <= wdata;
                        3: stream_req_q_bases[i*64+32+:32] <= wdata;
                        4: stream_cpl_q_bases[i*64+:32] <= wdata;
                        5: stream_cpl_q_bases[i*64+32+:32] <= wdata;
                        6: stream_req_q_head_tails[i*64+:32] <= wdata;
                        7: stream_req_q_head_tails[i*64+32+:32] <= wdata;
                        8: stream_cpl_q_head_tails[i*64+:32] <= wdata;
                        9: stream_cpl_q_head_tails[i*64+32+:32] <= wdata;
                        10: {stream_cpl_q_depth[i*8+:8], stream_req_q_depth[i*8+:8]} <= 16'h0808; //wdata[15:0];
                        11: begin
                            req_queue_head[i] <= wdata[7:0] % stream_req_q_depth[i*8+:8];
                            req_queue_read_pos[i] <= wdata[7:0] % stream_req_q_depth[i*8+:8];
                            req_queue_transfer_idx[i] <= wdata[7:0] % stream_req_q_depth[i*8+:8];
                            req_queue_tail[i] <= wdata[7:0] % stream_req_q_depth[i*8+:8];
                            cpl_queue_head[i] <= wdata[15:8] % stream_cpl_q_depth[i*8+:8];
                            cpl_queue_tail[i] <= wdata[15:8] % stream_cpl_q_depth[i*8+:8];
                            req_queue_check_idx[i] <= wdata[7:0] % stream_req_q_depth[i*8+:8];
                            req_queue_pos_for_frame_info[i] <= wdata[7:0] % stream_req_q_depth[i*8+:8];
                        end
                        12: stream_doorbell_bases[i*64+:32] <= wdata;
                        13: stream_doorbell_bases[i*64+32+:32] <= wdata;
                        14: begin
                           stream_ch_check_with_doorbells_reg[i] <= wdata[4];
                           stream_ch_interrupt_enables_reg[i] <= wdata[0];
                        end
                        16: begin
                            stream_ch_valids[i] <= FIXED_CH_VALIDS>0 ? CH_VALIDS[i] : wdata[0];
                            stream_ch_d2d_valids[i] <= (FIXED_CH_VALIDS>0 ? CH_VALIDS[i] : wdata[0]) & wdata[4] ;
                            stream_ch_valid_num <= stream_ch_valid_num + ((FIXED_CH_VALIDS>0 ? CH_VALIDS[i] : wdata[0]) && (~wdata[4] || IS_TX==1));
                            $display("%d [%2h]: stream valid:%1h, d2d:%1h, doorbell%1h", $time, i, FIXED_CH_VALIDS>0 ? CH_VALIDS[i] : wdata[0],
                                     (FIXED_CH_VALIDS>0 ? CH_VALIDS[i] : wdata[0]) & wdata[4],
                                     stream_ch_check_with_doorbells_reg[i]);
                           if ((FIXED_CH_VALIDS>0 ? CH_VALIDS[i] : wdata[0]) & wdata[4] && IS_TX==0) begin
                              req_queue_head[i] <= 'd0;
                              req_queue_read_pos[i] <= 'd0;
                              req_queue_transfer_idx[i] <= 'd0;
                              req_queue_tail[i] <= 'd0;
                              cpl_queue_head[i] <= 'd0;
                              cpl_queue_tail[i] <= 'd0;
                              req_queue_check_idx[i] <= 'd0;
                              req_queue_pos_for_frame_info[i] <= 'd0;
                           end
                        end
                    endcase
                end
                do @(posedge clk) {reg_awvalid, reg_wvalid} <= {reg_awvalid, reg_wvalid} & ~{reg_awready, reg_wready}; while (reg_awvalid | reg_wvalid);
                while (1'b1) @(posedge clk) begin
                    reg_bready <= rd[10];
                    if ((reg_bvalid & reg_bready) || j==15) break;
                end
                @(posedge clk) reg_bready <= 1'b0;
            end
            $display("initialize queue[%2h]: req head/tail=%d/%d, depth=%d, head/tail=%h, base=%h, doorbell=%h",
                     i, req_queue_head[i], req_queue_tail[i], stream_req_q_depth[i*8+:8],
                     stream_req_q_head_tails[i*64+:64], stream_req_q_bases[i*64+:64], stream_doorbell_bases[i*64+:64]);
            $display("initialize queue[%2h]: cpl head/tail=%d/%d, depth=%d, head/tail=%h, base=%h",
                     i, cpl_queue_head[i], cpl_queue_tail[i], stream_cpl_q_depth[i*8+:8],
                     stream_cpl_q_head_tails[i*64+:64], stream_cpl_q_bases[i*64+:64]);
        end
        @(posedge clk) done_set_desc_addrs = 1'b1;
    endtask

    task static initialize_vpmap();
        int          i, j, k;
        reg [63:0]   cur_vaddr;
        reg [31:0]   cur_remain;
        logic [31:0] wdata;
        int          reg_max = VPMAP_CH_AGGREGATE > 0 ? 4 : 6;
        // initialize registers
        for (i=0; i<CH_NUM; i++) begin
            for (j=0; j<VP_MAP_NUM; j++) begin
                if (j==0) begin
                    @(posedge clk) vaddrs[i] = {rd, rd[31:12], 12'd0};
                    @(posedge clk) begin
                        vsizes[i] = {rd[31:12], 12'd0};
                        cur_vaddr = vaddrs[i];
                        cur_remain = vsizes[i];
                        $display("[%2h]: vaddr: %h vsize: %h", i, vaddrs[i], vsizes[i]);
                    end
                end
                @(posedge clk) begin
                    if (cur_remain) begin
                        vpmap_vsizes[i][j] = cur_remain < {1'b0, rd[30:12], 12'd0} ? cur_remain : {1'b0, rd[30:12], 12'd0};
                        if (j == VP_MAP_NUM - 1) vpmap_vsizes[i][j] = cur_remain;
                        else if (vpmap_vsizes[i][j] > VPMAP_SIZE_MAX) vpmap_vsizes[i][j] = VPMAP_SIZE_MAX;
                        cur_remain = cur_remain - vpmap_vsizes[i][j];
                        vpmap_vaddrs[i][j] = cur_vaddr;
                        vpmap_valids[i][j] = 1'b1;
                        cur_vaddr = cur_vaddr + vpmap_vsizes[i][j];
                    end
                end
                @(posedge clk) begin
                    vpmap_paddrs[i][j] = {rd, rd[31:5], 5'd0};
                    $display("       %h vaddr: %h vsize: %h paddr: %h", vpmap_valids[i][j],
                             vpmap_vaddrs[i][j], vpmap_vsizes[i][j], vpmap_paddrs[i][j]);
                end
                if (VPMAP_CH_AGGREGATE > 0) begin
                   @(posedge clk) begin
                      reg_awaddr <= REG_BASE + CTRL_MAX + 4'd8;
                      reg_wdata <= i;
                      reg_awvalid <= 1'b1;
                      reg_wvalid <= 1'b1;
                   end
                   do @(posedge clk) {reg_awvalid, reg_wvalid} <= {reg_awvalid, reg_wvalid} & ~{reg_awready, reg_wready}; while (reg_awvalid | reg_wvalid);
                   do @(posedge clk) reg_bready <= rd[10]; while (~reg_bvalid | ~reg_bready);
                   @(posedge clk) reg_bready <= 1'b0;
                end
                if (vpmap_vsizes[i][j]) begin
                    for (k=0; k<reg_max; k++) begin
                        @(posedge clk) begin
                            if (VPMAP_CH_AGGREGATE > 0) begin
                                case(k)
                                  0: wdata = vpmap_vaddrs[i][j][43:12];
                                  1: wdata = {vpmap_paddrs[i][j][23:12], vpmap_vaddrs[i][j][63:44]};
                                  2: wdata = vpmap_paddrs[i][j][55:24];
                                  3: wdata = {3'd0, vpmap_valids[i][j], vpmap_vsizes[i][j][31:12], vpmap_paddrs[i][j][63:56]};
                                endcase
                               reg_awaddr <= REG_BASE + (j * 32) + (k * 4);
                            end else begin
                               case(k)
                                 0: wdata = vpmap_vaddrs[i][j][31:0];
                                 1: wdata = vpmap_vaddrs[i][j][63:32];
                                 2: wdata = vpmap_paddrs[i][j][31:0];
                                 3: wdata = vpmap_paddrs[i][j][63:32];
                                 4: wdata = vpmap_vsizes[i][j];
                                 5: wdata = {'d0 | vpmap_valids[i][j]};
                               endcase
                               reg_awaddr <= REG_BASE + (i * VP_MAP_NUM * 32) + (j * 32) + (k * 4);
                            end
                            reg_wdata <= wdata;
                            {reg_awvalid, reg_wvalid} <= 2'd3;
                        end
                        do @(posedge clk) {reg_awvalid, reg_wvalid} <= {reg_awvalid, reg_wvalid} & ~{reg_awready, reg_wready}; while (reg_awvalid | reg_wvalid);
                        do @(posedge clk) begin
                            reg_bready <= rd[10];
                        end while (~reg_bvalid | ~reg_bready);
                        @(posedge clk) reg_bready <= 1'b0;
                    end
                end else begin
                    @(posedge clk) begin
                        if (VPMAP_CH_AGGREGATE > 0) begin
                            reg_awaddr <= REG_BASE + (j * 32) + 12;
                            reg_wdata <= 32'h0;
                        end else begin
                            reg_awaddr <= REG_BASE + (i * VP_MAP_NUM * 32) + (j * 32) + 20;
                            reg_wdata <= 32'h0;
                        end
                        {reg_awvalid, reg_wvalid} <= 2'd3;
                    end
                    do @(posedge clk) {reg_awvalid, reg_wvalid} <= {reg_awvalid, reg_wvalid} & ~{reg_awready, reg_wready}; while (reg_awvalid | reg_wvalid);
                    do @(posedge clk) begin
                        reg_bready <= rd[10];
                    end while (~reg_bvalid | ~reg_bready);
                    @(posedge clk) reg_bready <= 1'b0;
                end
            end
        end
    endtask

    task static add_request();
        int i, j;
        reg [15:0] counts;
        logic [CH_NUM_LOG-1:0] ch;
        reg [15:0]             queue_idx[0:CH_NUM-1];
        logic [15:0]           queue_idx_next;
        logic [63:0]           transfer_addr;
        logic [31:0]           transfer_size;
        logic [31:0] size_mask = ((32'h1 << TRANSFER_SIZE_MAX_LOG)-1);

        for (i=0; i<START_DELAY; i++) @(posedge clk);
        @(posedge clk) begin
            counts = 'd0;
            for (i=0; i<CH_NUM; i++) begin
                queue_idx[i] = 16'd0 | req_queue_head[i];
                req_head_counts[i] = 'd0;
            end
        end
        while (counts < TRANSFER_NUM) @(posedge clk) begin
            ch = rd[REQ_CH_BASE+:CH_NUM_LOG];
            queue_idx_next = queue_idx[ch] + 1'b1 >= stream_req_q_depth[ch*8+:8] ? 'd0 : (16'd0 | queue_idx[ch]) + 1'b1;
            if (stream_ch_valids[ch] && &rd[ADD_REQ_BASE+:ADD_REQ_BITS]) begin
                $display("%d [%2h]: request candidate: stat: %h(%d)", $time, ch, req_queue_stat[ch][queue_idx_next], queue_idx_next);
            end
            if (stream_ch_valids[ch] && &rd[ADD_REQ_BASE+:ADD_REQ_BITS] && req_queue_stat[ch][queue_idx_next] !== 'd1 &&
                req_inflights[ch] < REQ_INFLIGHT_MAX) begin
                transfer_addr = vaddrs[ch] + {rd[29:2], 2'd0};
                transfer_size = {rd[31:2], 2'd0} & size_mask;
                if (transfer_addr < vaddrs[ch] + vsizes[ch] && |transfer_size) begin
                    transfer_size = transfer_addr + transfer_size < vaddrs[ch] + vsizes[ch] ? transfer_size : vaddrs[ch] + vsizes[ch] - transfer_addr;
                    req_queue_addr[ch][queue_idx[ch]] <= transfer_addr;
                    req_queue_size[ch][queue_idx[ch]] <= transfer_size;
                    req_queue_stat[ch][queue_idx[ch]] <= 1'b1;
                    queue_idx[ch] <= queue_idx_next;
                    req_queue_head[ch] <= queue_idx_next;
                    counts = counts + 1'b1;
                    req_head_counts[ch] <= req_head_counts[ch] + 1'b1;
                    req_inflights[ch]++;
                    $display("%d [%2h]: request vaddr:%h vsize:%h queue_idx:%h->%h, frame_info:%h (ch_valids:%h, %h, %h), idx:%h", $time, ch,
                             transfer_addr, transfer_size, queue_idx[ch], queue_idx_next, {rd[3:0], rd[31:6], 2'd0}, stream_ch_valids,
                             stream_ch_d2d_valids, stream_ch_check_with_doorbells_reg, queue_idx[ch]);
                    if (ENABLE_FRAME_INFO_OUT) begin
                       if (IS_TX==1 || ~stream_ch_d2d_valids[ch]) begin
                          frame_info_out_sizes[ch][out_size_wpos[ch]] <= transfer_size;
                          out_size_wpos[ch] <= out_size_wpos[ch] + |transfer_size;
                       end
                    end
                    if (DISABLE_FRAME_INFO) begin
                        req_queue_info_size[ch][queue_idx[ch]] <= VPMAP_SIZE_MAX;
                        frame_info_sizes[frame_info_wpos] <= VPMAP_SIZE_MAX;
                        frame_info_wpos <= frame_info_wpos + 1'b1;
                    end else begin
                        req_queue_info_size[ch][queue_idx[ch]] <= {rd[3:0], rd[31:6], 2'd0} & size_mask;
                        if (ENABLE_FRAME_INFO_OUT == 0) begin
                           frame_info_sizes[frame_info_wpos] <= {rd[3:0], rd[31:6], 2'd0} & size_mask;
                           frame_info_chs[frame_info_wpos] <= ch;
                           frame_info_wpos <= frame_info_wpos + 1'b1;
                        end
                    end
                    if (stream_ch_check_with_doorbells_reg[ch] && (IS_TX==1 || ~stream_ch_d2d_valids[ch])) begin
                       if (DOORBELL_WITH_AXI > 0) begin
                          axi_write_addr[0][axi_write_wpos[0]] <= {'d0, D2D_AXI_BASE} + CTRL_BASE + ch * 64 + 60;
                          axi_write_len[0][axi_write_wpos[0]] <= 'd0; // 1burst
                          axi_write_size[0][axi_write_wpos[0]] <= 3'd2; // 1burst
                          axi_write_data[0][axi_write_wdpos[0]] <= 'd0;
                          axi_write_keep[0][axi_write_wdpos[0]] <= 'hf;
                          axi_write_last[0][axi_write_wdpos[0]] <= 'h1;
                          axi_write_wpos[0] <= axi_write_wpos[0] + 1'b1;
                          axi_write_wdpos[0] <= axi_write_wdpos[0] + 1'b1;
                       end else begin
                          axil_write_addr[0][axil_write_wpos[0]] <= CTRL_BASE + ch * 64 + 60;
                          axil_write_data[0][axil_write_wpos[0]] <= 'd0;
                          axil_write_wpos[0] <= axil_write_wpos[0] + 1'b1;
                          $display("%d: [%2h] (%3d) doorbell write: %h", $time, ch, axil_write_wpos[0], CTRL_BASE + ch * 64 + 60);
                       end
                    end
                end else begin
                    $display("@@@ [%2h]: %h %h", ch, transfer_addr, vaddrs[ch] + {rd[29:2], 2'd0});
                end
            end
        end
        $display("end add requests");
    endtask

   task static tx_input_generate();
      logic [31:0] transfer_sizes[0:CH_NUM-1];
      logic [31:0] transfer_total_sizes[0:CH_NUM-1];
      logic [63:0] transfer_vaddrs[0:CH_NUM-1];
      logic [63:0] transfer_paddrs[0:CH_NUM-1];
      logic [31:0] transfer_psizes[0:CH_NUM-1];
      logic        transfer_finals[0:CH_NUM-1];
      logic [CH_NUM-1:0] transfer_size_exists = 0;
      logic [31:0]       transfer_total_size;
      logic [31:0]       osize, isize;
      logic [15:0] size = 0;
      logic [CH_NUM_LOG-1:0] transfer_ch;
      logic [31:0]           poffset;
      logic        eof;
      logic [DW-1:0] data;
      logic [KW-1:0] keep;
      logic          last;
      logic          valid;
      logic          sop, eop;
      logic          sop_out;
      logic [CH_NUM_LOG-1:0] ch = 0;
      logic [15:0]           burst_max_size = {'d1, {BURST_MAX+KW_LOG{1'b0}}};
      int            tx_input_count = 0;
      for (int i=0; i<CH_NUM; i++) transfer_sizes[i] = 'd0;

      while (tx_input_count < TRANSFER_NUM || |transfer_size_exists || tx_in_tvalid || |size || valid) @(posedge clk) begin
         for (int ch=0; ch<CH_NUM; ch++) begin
            if (~|transfer_sizes[ch] && req_queue_read_pos[ch] !== req_queue_transfer_idx[ch]) begin
               osize = req_queue_size[ch][req_queue_transfer_idx[ch]];
               isize = req_queue_info_size[ch][req_queue_transfer_idx[ch]];
               $display("%d: [%2h] %h %h", $time, ch, osize, isize);
               transfer_sizes[ch] = osize < isize ? osize : isize;
               transfer_total_sizes[ch] = osize < isize ? osize : isize;
               transfer_vaddrs[ch] = req_queue_addr[ch][req_queue_transfer_idx[ch]];
               if (stream_ch_d2d_valids[ch]) req_queue_stat[ch][req_queue_transfer_idx[ch]] <= 'd0;
               for (int i=0; i<VP_MAP_NUM; i++) begin
                  poffset = transfer_vaddrs[ch] - vpmap_vaddrs[ch][i];
                  if (vpmap_valids[ch][i] &&
                      vpmap_vaddrs[ch][i] <= transfer_vaddrs[ch] && transfer_vaddrs[ch] < vpmap_vaddrs[ch][i] + vpmap_vsizes[ch][i]) begin
                     transfer_paddrs[ch] = vpmap_paddrs[ch][i] + poffset;
                     transfer_finals[ch] = (transfer_sizes[ch] + poffset) <= vpmap_vsizes[ch][i];
                     transfer_psizes[ch] = (transfer_sizes[ch] + poffset) > vpmap_vsizes[ch][i] ? vpmap_vsizes[ch][i] - poffset : transfer_sizes[ch];
                     $display("%d: [%2h] vpconv: (%3d) %h %h -> %h %h (%h %h) %h", $time, ch, i,
                              transfer_vaddrs[ch], transfer_sizes[ch], transfer_paddrs[ch], transfer_psizes[ch], vpmap_vsizes[ch][i], poffset,
                              transfer_finals[ch]);
                     break;
                  end
               end
               transfer_size_exists[ch] = 1'b1;
               req_queue_transfer_idx[ch] = (req_queue_transfer_idx[ch] + 1'b1) % stream_req_q_depth[ch*8+:8];
            end
         end
         if (~|size) begin
            if (|transfer_sizes[ch]) begin
               if (~|transfer_psizes[ch]) begin
                  for (int i=0; i<VP_MAP_NUM; i++) begin
                     if (vpmap_valids[ch][i] &&
                         vpmap_vaddrs[ch][i] <= transfer_vaddrs[ch] && transfer_vaddrs[ch] < vpmap_vaddrs[ch][i] + vpmap_vsizes[ch][i]) begin
                        transfer_paddrs[ch] = transfer_paddrs[ch][i] + (transfer_vaddrs[ch] - vpmap_vaddrs[ch][i]);
                        transfer_psizes[ch] = transfer_sizes[ch] > vpmap_vsizes[ch][i] ? vpmap_vsizes[ch][i] : vpmap_vsizes[ch][i] - (transfer_vaddrs[ch] - vpmap_vaddrs[ch][i]);
                        $display("%d: [%2h] vpconv: (%3d) %h %h -> %h %h", $time, ch, i,
                                 transfer_vaddrs[ch], transfer_sizes[ch], transfer_paddrs[ch], transfer_psizes[ch]);
                        break;
                     end
                  end
               end
               size = transfer_psizes[ch] > burst_max_size ? burst_max_size : transfer_psizes[ch];
               eof = transfer_sizes[ch] <= burst_max_size;
               transfer_sizes[ch] = eof ? 'd0 : transfer_sizes[ch] - burst_max_size;
               transfer_psizes[ch] = transfer_psizes[ch] <= burst_max_size ? 'd0 : transfer_psizes[ch] - burst_max_size;
               transfer_total_size = transfer_total_sizes[ch];
               transfer_ch = ch;
               sop = 1;
               data_dma_addrs[data_dma_wpos] <= transfer_paddrs[ch];
               data_dma_lengths[data_dma_wpos] <= size;
               data_dma_lasts[data_dma_wpos] <= 1'b1;
               $display("%d: [%2h] desc (%3d) %h %h %h", $time, ch, data_dma_wpos, transfer_paddrs[ch], size, eof);
               if (eof && stream_ch_d2d_valids[ch]) begin
                  data_dma_addrs[(data_dma_wpos+1)&255] <= stream_cpl_q_bases[ch*64+:64] + 4'd8;
                  data_dma_lengths[(data_dma_wpos+1)&255] <= 'd4;
                  data_dma_lasts[(data_dma_wpos+1)&255] <= 1'b1;
                  data_dma_wpos <= data_dma_wpos + 2'd2;
                  $display("%d: [%2h] cpl size desc %h %h", $time, ch, stream_cpl_q_bases[ch*64+:64] + 4'd8, 4);
               end else begin
                  data_dma_wpos <= data_dma_wpos + 1'b1;
               end
               transfer_vaddrs[ch] += size;
               transfer_paddrs[ch] += size;
               if (transfer_sizes[ch] == 0) begin
                  transfer_size_exists[ch] = 1'b0;
                  tx_input_count++;
               end
            end
            ch++;
         end else begin
            if (~|transfer_sizes[ch]) ch++;
         end
         valid = (DATA_VALID_BITS > 0 ? &rd[17+:DATA_VALID_BITS_MOD] : 1'b1) & |size;
         if ((~tx_in_tvalid | tx_in_tready) && |size) begin
            keep = ({{KW{1'b0}}, 1'b1} << (size < KW ? size : KW)) - 1'b1;
            for (int i=0; i<KW; i++) begin
               data[i*8+:8] = (rd[(i*8)&31+:8] ^ (64'hdeadbeeff00baab1 >> i)) & {8{keep[i]}};
            end
            sop_out = sop;
            eop = size <= KW;
            last = eop && eof;
            tx_in_tvalid <= valid;
            if (valid) begin
               sop = eop;
               tx_in_tdata <= data;
               tx_in_tkeep <= keep;
               tx_in_tuser <= transfer_ch;
               tx_in_tlast <= last;
               tx_in_sop <= sop_out;
               tx_in_eop <= eop;
               data_dma_data[data_dma_wdpos] <= data;
               data_dma_keeps[data_dma_wdpos] <= keep;
               data_dma_dlasts[data_dma_wdpos] <= eop;
               if (last) begin
                  req_inflights[transfer_ch]--;
               end
               if (transfer_finals[transfer_ch] && last && stream_ch_d2d_valids[transfer_ch]) begin
                  data_dma_data[(data_dma_wdpos+1)&255] <= {'d0, transfer_total_size};
                  data_dma_keeps[(data_dma_wdpos+1)&255] <= 'hf;
                  data_dma_dlasts[(data_dma_wdpos+1)&255] <= 1'b1;
                  data_dma_wdpos <= data_dma_wdpos + 2'd2;
                  $display("%d: [%2h] cpl size data %h", $time, transfer_ch, transfer_total_size);
               end else begin
                  data_dma_wdpos <= data_dma_wdpos + 1'b1;
                  if (eop) begin
                     $display("%d: [%2h] cpl size data %h remain %h", $time, transfer_ch, transfer_total_size, transfer_sizes[transfer_ch]);
                  end
               end
               size = size <= KW ? 0 : size - KW;
            end
         end else begin
            tx_in_tvalid <= tx_in_tvalid & ~tx_in_tready;
         end
      end
      $display("end tx input");
   endtask

   task static rx_input_generate();
      logic [31:0] transfer_sizes[0:CH_NUM-1];
      logic [31:0] transfer_total_sizes[0:CH_NUM-1];
      logic [63:0] transfer_vaddrs[0:CH_NUM-1];
      logic [63:0] transfer_paddrs[0:CH_NUM-1];
      logic [31:0] transfer_psizes[0:CH_NUM-1];
      logic        transfer_finals[0:CH_NUM-1];
      logic [CH_NUM-1:0] transfer_size_exists = 0;
      logic [31:0]       transfer_total_size;
      logic [7:0]        transfer_idx;
      logic [31:0]       osize, isize;
      logic [15:0] size = 0;
      logic [CH_NUM_LOG-1:0] transfer_ch;
      logic [31:0]           poffset;
      logic        eof;
      logic [DW-1:0] data;
      logic [KW-1:0] keep;
      logic          last;
      logic          valid;
      logic [32*CH_NUM-1:0] transfer_sizes_vec;
      logic [32*CH_NUM-1:0] transfer_psizes_vec;
      logic [64*CH_NUM-1:0] transfer_paddrs_vec;
      logic [64*CH_NUM-1:0] transfer_vaddrs_vec;
      logic [8*CH_NUM-1:0]  transfer_indices;
      logic [8*CH_NUM-1:0]  transfer_read_poses;
      logic [8*CH_NUM-1:0]  transfer_r_head_rxs;
      logic [8*CH_NUM-1:0]  transfer_r_tail_rxs;
      logic [8*CH_NUM-1:0]  transfer_c_head_rxs;
      logic [8*CH_NUM-1:0]  transfer_c_tail_rxs;
      logic [CH_NUM_LOG-1:0] ch = 0, cur_ch;
      logic [15:0]           burst_max_size = {'d1, {BURST_MAX+KW_LOG{1'b0}}};
      logic [DW-1:0]         rx_st_data[0:255];
      logic [KW-1:0]         rx_st_keep[0:255];
      logic                  rx_st_last[0:255];
      logic [7:0]            rx_st_wpos = 0, rx_st_rpos = 0;
      logic                  is_d2d = 0;

      int            rx_input_count = 0;
      for (int i=0; i<CH_NUM; i++) transfer_sizes[i] = 'd0;

      while (rx_input_count < TRANSFER_NUM || rx_in_tvalid || |transfer_size_exists || |size || rx_st_wpos != rx_st_rpos) @(posedge clk) begin
         for (int i=0; i<CH_NUM; i++) begin
            if (stream_ch_valids[i] && ~|transfer_sizes[i] && req_queue_read_pos[i] !== req_queue_transfer_idx[i] &&
                req_queue_head[i] !== req_queue_transfer_idx[i]) begin
               osize = req_queue_size[i][req_queue_transfer_idx[i]];
               isize = req_queue_info_size[i][req_queue_transfer_idx[i]];
               $display("%d: vpconv pre [%2h] %h %h (%2d/%2d)", $time, i, osize, isize,
                        req_queue_read_pos[i], req_queue_transfer_idx[i]);
               transfer_sizes[i] = osize < isize ? osize : isize;
               transfer_total_sizes[i] = osize < isize ? osize : isize;
               transfer_vaddrs[i] = req_queue_addr[i][req_queue_transfer_idx[i]];
               for (int j=0; j<VP_MAP_NUM; j++) begin
                  poffset = transfer_vaddrs[i] - vpmap_vaddrs[i][j];
                  if (vpmap_valids[i][j] &&
                      vpmap_vaddrs[i][j] <= transfer_vaddrs[i] && transfer_vaddrs[i] < vpmap_vaddrs[i][j] + vpmap_vsizes[i][j]) begin
                     transfer_paddrs[i] = vpmap_paddrs[i][j] + poffset;
                     transfer_finals[i] = (transfer_sizes[i] + poffset) <= vpmap_vsizes[i][j];
                     transfer_psizes[i] = (transfer_sizes[i] + poffset) > vpmap_vsizes[i][j] ? vpmap_vsizes[i][j] - poffset : transfer_sizes[i];
                     $display("%d: [%2h] vpconv: (%3d) %h %h -> %h %h (%h %h) %h, idx:%h", $time, i, j,
                              transfer_vaddrs[i], transfer_sizes[i], transfer_paddrs[i], transfer_psizes[i], vpmap_vsizes[i][j], poffset,
                              transfer_finals[i], req_queue_transfer_idx[i]);
                     break;
                  end
               end
               transfer_size_exists[i] = 1'b1;
            end
         end
         if (~|size) begin
            for (int i=0; i<CH_NUM; i++) begin
               if (|transfer_sizes[i] && ~|transfer_psizes[i]) begin
                  for (int j=0; j<VP_MAP_NUM; j++) begin
                     if (vpmap_valids[i][j] &&
                         vpmap_vaddrs[i][j] <= transfer_vaddrs[i] && transfer_vaddrs[i] < vpmap_vaddrs[i][j] + vpmap_vsizes[i][j]) begin
                        transfer_paddrs[i] = transfer_paddrs[i][j] + (transfer_vaddrs[i] - vpmap_vaddrs[i][j]);
                        transfer_psizes[i] = transfer_sizes[i] > vpmap_vsizes[i][j] ? vpmap_vsizes[i][j] : vpmap_vsizes[i][j] - (transfer_vaddrs[i] - vpmap_vaddrs[i][j]);
                        $display("%d: [%2h] vpconv: (%3d) %h %h -> %h %h", $time, i, j,
                                 transfer_vaddrs[i], transfer_sizes[i], transfer_paddrs[i], transfer_psizes[i]);
                        break;
                     end
                  end
               end
            end
         end
         for (int l=0; l<2; l++) begin
            if (~|size && data_dma_rpos != data_dma_wpos) begin
               for (int i=0; i<CH_NUM; i++) begin
                  if (data_dma_addrs[data_dma_rpos] === transfer_paddrs[i] && |transfer_sizes[i] && (is_d2d || l>0)) begin
                     size = data_dma_lengths[data_dma_rpos];
                     data_dma_rpos <= data_dma_rpos + 1'b1;
                     eof = transfer_sizes[i] <= size;
                     transfer_sizes[i] = eof ? 'd0 : transfer_sizes[i] - size;
                     transfer_psizes[i] = transfer_psizes[i] <= size ? 'd0 : transfer_psizes[i] - size;
                     transfer_total_size = transfer_total_sizes[i];
                     transfer_idx = req_queue_transfer_idx[i];
                     transfer_ch = i;
                     $display("%d: [%2h] transfer: %h %h %h", $time, i, transfer_paddrs[i], transfer_psizes[i], size);
                     transfer_vaddrs[i] += size;
                     transfer_paddrs[i] += size;
                     if (transfer_sizes[i] == 0) begin
                        transfer_size_exists[i] = 1'b0;
                        req_queue_transfer_idx[i] = (req_queue_transfer_idx[i] + 1'b1) % stream_req_q_depth[i*8+:8];
                        rx_input_count++;
                     end
                     is_d2d = 0;
                     break;
                  end
               end
            end
            if (((axi_write_wpos[2]+1) & 255) != axi_write_rpos[2] &&
                ((axi_write_wpos[2]+2) & 255) != axi_write_rpos[2] &&
                ((axi_write_wpos[2]+3) & 255) != axi_write_rpos[2] &&
                ((axi_write_wpos[2]+4) & 255) != axi_write_rpos[2] && (~is_d2d || l>0) && ~|size) begin
               for (int i=0; i<CH_NUM; i++) begin
                  cur_ch = ch + i;
                  if (~|size && |transfer_sizes[cur_ch] && stream_ch_d2d_valids[cur_ch]) begin
                     size = transfer_psizes[cur_ch] > burst_max_size ? burst_max_size : transfer_psizes[cur_ch];
                     eof = transfer_sizes[cur_ch] <= size;
                     transfer_sizes[cur_ch] = eof ? 'd0 : transfer_sizes[cur_ch] - size;
                     transfer_psizes[cur_ch] = transfer_psizes[cur_ch] <= size ? 'd0 : transfer_psizes[cur_ch] - size;
                     transfer_total_size = transfer_total_sizes[cur_ch];
                     transfer_idx = req_queue_transfer_idx[cur_ch];
                     transfer_ch = cur_ch;
                     axi_write_addr[2][axi_write_wpos[2]] <= {'d0, D2D_AXI_BASE} + D2D_AXI_RANGE * (cur_ch + 1) + (rd & D2D_AXI_RANGE_MASK);
                     axi_write_len[2][axi_write_wpos[2]] <= ((size + KW - 1) >> KW_LOG) - 1;
                     axi_write_size[2][axi_write_wpos[2]] <= size >= KW ? KW_LOG : $clog2(size & (KW-1));
                     $display("%d: [%2h] axi transfer: %h %h %h, %h %h %h", $time, cur_ch, transfer_paddrs[cur_ch], transfer_psizes[cur_ch], size,
                              (size + KW - 1) >> KW_LOG, size & (KW-1), $clog2(size & (KW-1)));
                     if (eof) begin
                        axi_write_addr[2][(axi_write_wpos[2]+1)&255] <= QUEUE_BASE + (cur_ch * 2 + 1) * QUEUE_DEPTH * QEW + 4'd8;
                        axi_write_len[2][(axi_write_wpos[2]+1)&255] <= 'd0;
                        axi_write_size[2][(axi_write_wpos[2]+1)&255] <= 3'd2;
                        axi_write_addr[2][(axi_write_wpos[2]+2)&255] <= QUEUE_HEAD_TAIL_BASE + (cur_ch * 16) + 3'd4; // req queue tail
                        axi_write_len[2][(axi_write_wpos[2]+2)&255] <= 'd0;
                        axi_write_size[2][(axi_write_wpos[2]+2)&255] <= 3'd2;
                        axi_write_addr[2][(axi_write_wpos[2]+3)&255] <= QUEUE_HEAD_TAIL_BASE + (cur_ch * 16) + 4'd8; // cpl queue head
                        axi_write_len[2][(axi_write_wpos[2]+3)&255] <= 'd0;
                        axi_write_size[2][(axi_write_wpos[2]+3)&255] <= 3'd2;
                        axi_write_wpos[2] <= axi_write_wpos[2] + 3'd4;
                        transfer_size_exists[cur_ch] = 1'b0;
                        req_queue_transfer_idx[cur_ch] = (req_queue_transfer_idx[cur_ch] + 1'b1) % stream_req_q_depth[cur_ch*8+:8];
                        rx_input_count++;
                     end else begin
                        axi_write_wpos[2] <= axi_write_wpos[2] + 1'b1;
                     end
                     is_d2d = 1;
                     ch = cur_ch;
                     break;
                  end
               end
            end
         end
         valid = (DATA_VALID_BITS > 0 ? &rd[17+:DATA_VALID_BITS_MOD] : 1'b1) & |size;
         if (((rx_st_wpos + 1'b1) & 255) != rx_st_rpos && valid &&
             ((axi_write_wdpos[2] + 1'b1) & 255) !== axi_write_rdpos[2] &&
             ((axi_write_wdpos[2] + 2'd2) & 255) !== axi_write_rdpos[2] &&
             ((axi_write_wdpos[2] + 2'd3) & 255) !== axi_write_rdpos[2] &&
             ((axi_write_wdpos[2] + 3'd4) & 255) !== axi_write_rdpos[2]) begin
            keep = ({{KW{1'b0}}, 1'b1} << (size < KW ? size : KW)) - 1'b1;
            for (int i=0; i<KW; i++) begin
               data[i*8+:8] = (rd[(i*8)&31+:8] ^ (64'hdeadbeeff00baab1 >> i)) & {8{keep[i]}};
            end
            last = size <= KW;
            if (stream_ch_d2d_valids[transfer_ch]) begin
               axi_write_data[2][axi_write_wdpos[2]] <= data;
               axi_write_keep[2][axi_write_wdpos[2]] <= keep;
               axi_write_last[2][axi_write_wdpos[2]] <= last;
               rx_mm_data[rx_mm_wpos] <= data;
               rx_mm_keep[rx_mm_wpos] <= keep;
               rx_mm_last[rx_mm_wpos] <= last;
               rx_mm_eof[rx_mm_wpos] <= last && eof;
               rx_mm_wpos <= rx_mm_wpos + 1'b1;
               if (last && eof) begin
                  req_inflights[transfer_ch]--;
               end
               if (last && eof) begin
                  axi_write_data[2][(axi_write_wdpos[2]+1)&255] <= {'d0, transfer_total_size};
                  axi_write_keep[2][(axi_write_wdpos[2]+1)&255] <= 'hf;
                  axi_write_last[2][(axi_write_wdpos[2]+1)&255] <= last;
                  req_queue_tail[transfer_ch] = (req_queue_tail[transfer_ch] + 1) % stream_req_q_depth[transfer_ch*8+:8];
                  cpl_queue_head[transfer_ch] = (cpl_queue_head[transfer_ch] + 1) % stream_cpl_q_depth[transfer_ch*8+:8];
                  axi_write_data[2][(axi_write_wdpos[2]+2)&255] <= {'d0, req_queue_tail[transfer_ch]};
                  axi_write_keep[2][(axi_write_wdpos[2]+2)&255] <= 'hf;
                  axi_write_last[2][(axi_write_wdpos[2]+2)&255] <= last;
                  axi_write_data[2][(axi_write_wdpos[2]+3)&255] <= {'d0, cpl_queue_head[transfer_ch]};
                  axi_write_keep[2][(axi_write_wdpos[2]+3)&255] <= 'hf;
                  axi_write_last[2][(axi_write_wdpos[2]+3)&255] <= last;
                  axi_write_wdpos[2] <= axi_write_wdpos[2] + 3'd4;
                  req_queue_stat[transfer_ch][transfer_idx] <= 'd0;
                  cpl_update_pos[cpl_update_wpos] <= axi_write_wdpos[2] + 3'd4;
                  cpl_update_ch[cpl_update_wpos] <= transfer_ch;
                  cpl_update_wpos <= cpl_update_wpos + 1'b1;
               end else begin
                  axi_write_wdpos[2] <= axi_write_wdpos[2] + 1'b1;
               end
            end else begin
               rx_st_data[rx_st_wpos] <= data;
               rx_st_keep[rx_st_wpos] <= keep;
               rx_st_last[rx_st_wpos] <= last;
               rx_st_wpos <= rx_st_wpos + 1'b1;
               rx_st_out_data[rx_st_out_wpos] <= data;
               rx_st_out_keep[rx_st_out_wpos] <= keep;
               rx_st_out_last[rx_st_out_wpos] <= last;
               rx_st_out_eof[rx_st_out_wpos] <= last && eof;
               rx_st_out_wpos <= rx_st_out_wpos + 1'b1;
               if (last && eof) begin
                  req_inflights[transfer_ch]--;
               end
            end
            size = size <= KW ? 0 : size - KW;
         end else begin
            rx_in_tvalid <= rx_in_tvalid & ~rx_in_tready;
         end
         if ((~rx_in_tvalid | rx_in_tready) && rx_st_wpos != rx_st_rpos) begin
            rx_in_tvalid <= 1'b1;
            rx_in_tdata <= rx_st_data[rx_st_rpos];
            rx_in_tkeep <= rx_st_keep[rx_st_rpos];
            rx_in_tlast <= rx_st_last[rx_st_rpos];
            rx_st_rpos <= rx_st_rpos + 1'b1;
         end else begin
            rx_in_tvalid <= rx_in_tvalid & ~rx_in_tready;
         end
         for (int i=0; i<CH_NUM; i++) transfer_sizes_vec[32*i+:32] = transfer_sizes[i];
         for (int i=0; i<CH_NUM; i++) transfer_psizes_vec[32*i+:32] = transfer_psizes[i];
         for (int i=0; i<CH_NUM; i++) transfer_vaddrs_vec[64*i+:64] = transfer_vaddrs[i];
         for (int i=0; i<CH_NUM; i++) transfer_paddrs_vec[64*i+:64] = transfer_paddrs[i];
         for (int i=0; i<CH_NUM; i++) transfer_indices[8*i+:8] = req_queue_transfer_idx[i];
         for (int i=0; i<CH_NUM; i++) transfer_read_poses[8*i+:8] = req_queue_read_pos[i];
         for (int i=0; i<CH_NUM; i++) transfer_r_head_rxs[8*i+:8] = req_queue_head_rx[i];
         for (int i=0; i<CH_NUM; i++) transfer_r_tail_rxs[8*i+:8] = req_queue_tail_rx[i];
         for (int i=0; i<CH_NUM; i++) transfer_c_head_rxs[8*i+:8] = cpl_queue_head_rx[i];
         for (int i=0; i<CH_NUM; i++) transfer_c_tail_rxs[8*i+:8] = cpl_queue_tail_rx[i];
      end
   endtask

    task static transfer_completes();
        int i, j;
        reg transfer_cpl_wait;
        reg [15:0] counts = 0;
        logic finished;
        while (1) @(posedge clk) begin
            finished = 1'b1;
            for (i=0; i<CH_NUM; i++) begin
                for (j=0; j<stream_req_q_depth[i*8+:8]; j++) begin
                    if (req_queue_stat[i][j] !== 'd0) begin
                        finished = 1'b0;
                        break;
                    end
                end
                if (req_head_counts[i] != cpl_tail_counts[i]) begin
                    finished = 1'b0;
                    break;
                end
            end
            if (finished) break;
            counts = counts + 1'b1;
            if (counts > 10000) begin
                for (i=0; i<CH_NUM; i++) $display("[%2d]: req: %8d, cpl: %8d", i, req_head_counts[i], cpl_tail_counts[i]);
                $fatal(2, "transfer incompleted\n");
            end
        end // while (1)
    endtask

    initial begin
        int i;
        while (resetn !== 1'b1) @(posedge clk);

        case(IS_TX)
          0 : begin
             initialize_queues;
             initialize_vpmap;
             dma_started = 1'b1;
             fork
                add_request;
                rx_input_generate;
             join
             transfer_completes;
          end
          1 : begin
             initialize_queues;
             initialize_vpmap;
             dma_started = 1'b1;
             fork
                add_request;
                tx_input_generate;
             join
             transfer_completes;
          end
          default: begin
             $fatal(2, "unknown test case");
          end
        endcase

        $finish();
    end

endmodule

module test_all_simple();

    tb_stream_engine tb();

endmodule

module test_all_simple2();

    tb_stream_engine #(
        .ENABLE_CHECK_WITH_DOORBELL ( 1 ),
        .CH_NUM_LOG ( 3 )
    ) tb();

endmodule

module test_all_simple3_slow_cpl_tail();

    tb_stream_engine #(
        .CH_NUM_LOG ( 3 ),
        .TAIL_UP_NUM ( 8 ),
        .ENABLE_CHECK_WITH_DOORBELL ( 1 ),
        .TRANSFER_NUM ( 200 )
    ) tb();

endmodule

module test_all_simple_rx();

    tb_stream_engine #(
        .IS_TX ( 0 ),
        .ENABLE_CHECK_WITH_DOORBELL ( 1 ),
        .CH_NUM_LOG ( 3 )
    ) tb();

endmodule

module test_all_simple_rx_1ch();

    tb_stream_engine #(
        .TRANSFER_NUM ( 100 ),
        .CH_NUM_LOG ( 4 ),
        .FIXED_CH_VALIDS ( 1 ),
        .CH_VALIDS ( 16'h8000 ),
        .START_DELAY ( 7000 )
    ) tb();

endmodule
