/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module stream_engine #(
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
    parameter CH_NUM_LOG = 3,
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
    parameter IS_TX = 0,
    parameter DISABLE_FRAME_INFO = 0,
    parameter ENABLE_FRAME_INFO_OUT = 0,
    parameter IGNORE_CPL_SIZE = 0,
    parameter USE_ULTRA_RAM_VPMAP = 1,
    parameter ACTIVE_LOW_RESET_IN = 1
    ) (
    // axi bypass slave
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
    output [3:0]                 axi_bid,
    output [1:0]                 axi_bresp,
    output                       axi_bvalid,
    input                        axi_bready,
    // axilite slave
    input [15:0]                 reg_araddr,
    input                        reg_arvalid,
    output                       reg_arready,
    output [31:0]                reg_rdata,
    output [1:0]                 reg_rresp,
    output                       reg_rvalid,
    input                        reg_rready,
    input [15:0]                 reg_awaddr,
    input                        reg_awvalid,
    output                       reg_awready,
    input [31:0]                 reg_wdata,
    input                        reg_wvalid,
    output                       reg_wready,
    output [1:0]                 reg_bresp,
    output                       reg_bvalid,
    input                        reg_bready,
    // descriptor output (to xdma)
    output [15:0]                wr_desc_ctl,
    output [63:0]                wr_desc_dst_addr,
    output [63:0]                wr_desc_src_addr, // dummy
    output [27:0]                wr_desc_len,
    output                       wr_desc_load,
    input                        wr_desc_ready,
    // data output (to xdma)
    output [(1<<DW_LOG)-1:0]     wr_tdata,
    output [(1<<(DW_LOG-3))-1:0] wr_tkeep,
    output                       wr_tlast,
    output                       wr_tvalid,
    input                        wr_tready,
    // descriptor output (to xdma)
    output [15:0]                rd_desc_ctl,
    output [63:0]                rd_desc_dst_addr, // dummy
    output [63:0]                rd_desc_src_addr,
    output [27:0]                rd_desc_len,
    output                       rd_desc_load,
    input                        rd_desc_ready,
    // data input (from xdma)
    input [(1<<DW_LOG)-1:0]      rd_tdata,
    input [(1<<(DW_LOG-3))-1:0]  rd_tkeep,
    input                        rd_tlast,
    input                        rd_tvalid,
    output                       rd_tready,
    // dma status
    input [7:0]                  wr_sts,
    output [31:0]                wr_done_count,
    input [7:0]                  rd_sts,
    output [31:0]                rd_done_count,
    // descriptor output (to xdma)
    output [15:0]                data_desc_ctl,
    output [63:0]                data_desc_src_addr,
    output [63:0]                data_desc_dst_addr,
    output [27:0]                data_desc_len,
    output                       data_desc_load,
    input                        data_desc_ready,
    // dma status
    input [7:0]                  data_sts,
    // rx data input (from xdma)
    input [(1<<DW_LOG)-1:0]      rx_in_tdata,
    input [(1<<(DW_LOG-3))-1:0]  rx_in_tkeep,
    input                        rx_in_tlast,
    input                        rx_in_tvalid,
    output                       rx_in_tready,
    // rx data output (to route_controller)
    output [(1<<DW_LOG)-1:0]     rx_out_tdata,
    output [(1<<(DW_LOG-3))-1:0] rx_out_tkeep,
    output [CH_NUM_LOG-1:0]      rx_out_tuser,
    output                       rx_out_tlast,
    output                       rx_out_tvalid,
    output                       rx_out_eof,
    input                        rx_out_tready,
    // tx data input (from route_controller)
    input [(1<<DW_LOG)-1:0]      tx_in_tdata,
    input [(1<<(DW_LOG-3))-1:0]  tx_in_tkeep,
    input [CH_NUM_LOG-1:0]       tx_in_tuser,
    input                        tx_in_tlast,
    input                        tx_in_sop,
    input                        tx_in_eop,
    input                        tx_in_tvalid,
    output                       tx_in_tready,
    // tx data output (to xdma)
    output [(1<<DW_LOG)-1:0]     tx_out_tdata,
    output [(1<<(DW_LOG-3))-1:0] tx_out_tkeep,
    output                       tx_out_tlast,
    output                       tx_out_tvalid,
    input                        tx_out_tready,
    // interrupt
    output [(1<<CH_NUM_LOG)-1:0] irq_out,
    input [(1<<CH_NUM_LOG)-1:0]  irq_ack,
     // completion tail update
    input [CH_NUM_LOG-1:0]       stream_cpl_update_ch,
    input                        stream_cpl_update,

    input [31:0]                 frame_info_size,
    input [CH_NUM_LOG-1:0]       frame_info_ch,
    input                        frame_info_valid,
    output                       frame_info_ready,

    output [31:0]                frame_info_out_size,
    output [CH_NUM_LOG-1:0]      frame_info_out_ch,
    output                       frame_info_out_valid,
    input                        frame_info_out_ready,

    input                        clk,
    input                        resetn
    );

   localparam QEW = 1 << QEW_LOG;
   localparam RQ_DW = (8 << QEW_LOG) + RQBASE;
   localparam RQ_DK = RQ_DW / 32;
   localparam RC_DW = (8 << QEW_LOG) + RCBASE;
   localparam RC_DK = RC_DW / 32;
   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam ENABLE_QUEUE = IS_TX == 0 ? 1 : 0;

   // axilite master
   wire [15:0]                   bypass_reg_araddr;
   wire                          bypass_reg_arvalid;
   wire                          bypass_reg_arready;
   wire [31:0]                   bypass_reg_rdata;
   wire [1:0]                    bypass_reg_rresp;
   wire                          bypass_reg_rvalid;
   wire                          bypass_reg_rready;
   wire [15:0]                   bypass_reg_awaddr;
   wire                          bypass_reg_awvalid;
   wire                          bypass_reg_awready;
   wire [31:0]                   bypass_reg_wdata;
   wire                          bypass_reg_wvalid;
   wire                          bypass_reg_wready;
   wire [1:0]                    bypass_reg_bresp;
   wire                          bypass_reg_bvalid;
   wire                          bypass_reg_bready;
   // axilite to core
   wire [15:0]                   core_reg_araddr;
   wire                          core_reg_arvalid;
   wire                          core_reg_arready;
   wire [31:0]                   core_reg_rdata;
   wire [1:0]                    core_reg_rresp;
   wire                          core_reg_rvalid;
   wire                          core_reg_rready;
   wire [15:0]                   core_reg_awaddr;
   wire                          core_reg_awvalid;
   wire                          core_reg_awready;
   wire [31:0]                   core_reg_wdata;
   wire                          core_reg_wvalid;
   wire                          core_reg_wready;
   wire [1:0]                    core_reg_bresp;
   wire                          core_reg_bvalid;
   wire                          core_reg_bready;
   // queue element read
   wire [CH_NUM_LOG-1:0]         stream_queue_read_ch;
   wire [QUEUE_DL-1:0]           stream_queue_read_entry;
   wire                          stream_queue_read_valid;
   wire [(8<<QEW_LOG)-1:0]       stream_queue_read_data;
   wire                          stream_queue_read_data_valid;
   // queue update (from core)
   wire [RQ_DW-1:0]              queue_update_data;
   wire [RQ_DK-1:0]              queue_update_keep;
   wire                          queue_update_valid;
   wire                          queue_update_ready;
   // queue write (from core)
   wire [RQ_DW-1:0]              queue_wr_data;
   wire [RQ_DK-1:0]              queue_wr_keep;
   wire                          queue_wr_valid;
   wire                          queue_wr_ready;
   // queue check (from core)
   wire [RQ_DW-1:0]              queue_check_data;
   wire [RQ_DK-1:0]              queue_check_keep;
   wire                          queue_check_valid;
   wire                          queue_check_ready;
   wire [RC_DW-1:0]              queue_check_res_data;
   wire                          queue_check_res_valid;
   // queue read (from core)
   wire [RQ_DW-1:0]              queue_rd_data;
   wire [RQ_DK-1:0]              queue_rd_keep;
   wire                          queue_rd_valid;
   wire                          queue_rd_ready;
   wire [RC_DW-1:0]              queue_rd_res_data;
   wire                          queue_rd_res_valid;
   // descriptor read req
   wire [DESC_RQ_DW-1:0]         desc_req_data;
   wire [DESC_RQ_DK-1:0]         desc_req_keep;
   wire                          desc_req_valid;
   wire                          desc_req_ready;
   // descriptor read result
   wire [DESC_RC_DW-1:0]         desc_out_data;
   wire [DESC_RC_DK-1:0]         desc_out_keep;
   wire                          desc_out_last;
   wire                          desc_out_valid;
   wire                          desc_out_ready;
   // descriptor completion
   wire [31:0]                   desc_cpl_data;
   wire [CH_NUM_LOG-1:0]         desc_cpl_ch;
   wire                          desc_cpl_valid;
   wire                          desc_cpl_ready;
   // wire from register
   wire [CH_NUM-1:0]             stream_ch_valids;
   wire [CH_NUM-1:0]             stream_ch_d2d_valids;
   wire [64*CH_NUM-1:0]          stream_cpl_q_bases;
   wire [CH_NUM-1:0]             head_tail_updates;
   wire [64*CH_NUM-1:0]          stream_doorbell_addrs;
   wire [CH_NUM-1:0]             stream_ch_interrupt_enables;

   wire                          internal_resetn;
   generate
      if (ACTIVE_LOW_RESET_IN) begin
         assign internal_resetn = resetn;
      end else begin
         assign internal_resetn = ~resetn;
      end
   endgenerate

   stream_engine_core #(
       .REG_BASE ( REG_BASE ),
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .RQ_DW ( RQ_DW ),
       .RQ_DK ( RQ_DK ),
       .RC_DW ( RC_DW ),
       .RC_DK ( RC_DK ),
       .DESC_RQ_DW ( DESC_RQ_DW ),
       .DESC_RQ_DK ( DESC_RQ_DK ),
       .DESC_RC_DW ( DESC_RC_DW ),
       .DESC_RC_DK ( DESC_RC_DK ),
       .DESC_LEN ( DESC_LEN ),
       .DISABLE_FRAME_INFO ( DISABLE_FRAME_INFO ),
       .ENABLE_FRAME_INFO_OUT ( ENABLE_FRAME_INFO_OUT ),
       .IGNORE_CPL_SIZE ( IGNORE_CPL_SIZE ),
       .FRAME_INFO_FIFO_DL ( FRAME_INFO_FIFO_DL ),
       .DESC_BASE_FIFO_DL ( DESC_BASE_FIFO_DL ),
       .VP_MAP_NUM_LOG ( VP_MAP_NUM_LOG ),
       .CH_BASE ( CH_BASE ),
       .QEW_LOG ( QEW_LOG ),
       .QEW ( QEW ),
       .ENABLE_QUEUE ( ENABLE_QUEUE ),
       .D2D_AXI_BASE ( D2D_AXI_BASE ),
       .D2D_AXI_RANGE ( D2D_AXI_RANGE ),
       .QUEUE_DL ( QUEUE_DL ),
       .QESIZE_POS ( QESIZE_POS ),
       .RQBASE ( RQBASE ),
       .RCBASE ( RCBASE ),
       .QUEUE_CHECK_TAG ( QUEUE_CHECK_TAG ),
       .QUEUE_READ_TAG ( QUEUE_READ_TAG ),
       .USE_ULTRA_RAM_VPMAP ( USE_ULTRA_RAM_VPMAP )
   ) core (
       .reg_araddr ( core_reg_araddr ),
       .reg_arvalid ( core_reg_arvalid ),
       .reg_arready ( core_reg_arready ),
       .reg_rdata ( core_reg_rdata ),
       .reg_rresp ( core_reg_rresp ),
       .reg_rvalid ( core_reg_rvalid ),
       .reg_rready ( core_reg_rready ),
       .reg_awaddr ( core_reg_awaddr ),
       .reg_awvalid ( core_reg_awvalid ),
       .reg_awready ( core_reg_awready ),
       .reg_wdata ( core_reg_wdata ),
       .reg_wvalid ( core_reg_wvalid ),
       .reg_wready ( core_reg_wready ),
       .reg_bresp ( core_reg_bresp ),
       .reg_bvalid ( core_reg_bvalid ),
       .reg_bready ( core_reg_bready ),

       .frame_info_size ( frame_info_size ),
       .frame_info_ch ( frame_info_ch ),
       .frame_info_valid ( frame_info_valid ),
       .frame_info_ready ( frame_info_ready ),

       .frame_info_out_size ( frame_info_out_size ),
       .frame_info_out_ch ( frame_info_out_ch ),
       .frame_info_out_valid ( frame_info_out_valid ),
       .frame_info_out_ready ( frame_info_out_ready ),

       .desc_req_data ( desc_req_data ),
       .desc_req_keep ( desc_req_keep ),
       .desc_req_valid ( desc_req_valid ),
       .desc_req_ready ( desc_req_ready ),

       .desc_out_data ( desc_out_data ),
       .desc_out_keep ( desc_out_keep ),
       .desc_out_valid ( desc_out_valid ),
       .desc_out_last ( desc_out_last ),
       .desc_out_ready ( desc_out_ready ),

       .desc_cpl_data ( desc_cpl_data ),
       .desc_cpl_ch ( desc_cpl_ch ),
       .desc_cpl_valid ( desc_cpl_valid ),
       .desc_cpl_ready ( desc_cpl_ready ),

       .queue_check_res_data ( queue_check_res_data ),
       .queue_check_res_valid ( queue_check_res_valid ),
       .queue_check_data ( queue_check_data ),
       .queue_check_keep ( queue_check_keep ),
       .queue_check_valid ( queue_check_valid ),
       .queue_check_ready ( queue_check_ready ),
       .queue_update_data ( queue_update_data ),
       .queue_update_keep ( queue_update_keep ),
       .queue_update_valid ( queue_update_valid ),
       .queue_update_ready ( queue_update_ready ),

       .queue_rd_data ( queue_rd_data ),
       .queue_rd_keep ( queue_rd_keep ),
       .queue_rd_valid ( queue_rd_valid ),
       .queue_rd_ready ( queue_rd_ready ),
       .queue_rd_res_data ( queue_rd_res_data ),
       .queue_rd_res_valid ( queue_rd_res_valid ),

       .queue_wr_data ( queue_wr_data ),
       .queue_wr_keep ( queue_wr_keep ),
       .queue_wr_valid ( queue_wr_valid ),
       .queue_wr_ready ( queue_wr_ready ),

       .stream_ch_valids ( stream_ch_valids ),
       .stream_ch_d2d_valids ( stream_ch_d2d_valids ),
       .stream_cpl_q_bases ( stream_cpl_q_bases ),
       .stream_doorbell_addrs ( stream_doorbell_addrs ),
       .stream_ch_interrupt_enables ( stream_ch_interrupt_enables ),

       .stream_cpl_update_ch ( stream_cpl_update_ch ),
       .stream_cpl_update ( stream_cpl_update ),
       .stream_queue_read_ch ( stream_queue_read_ch ),
       .stream_queue_read_entry ( stream_queue_read_entry ),
       .stream_queue_read_valid ( stream_queue_read_valid ),
       .stream_queue_read_data ( stream_queue_read_data ),
       .stream_queue_read_data_valid ( stream_queue_read_data_valid ),
       .head_tail_updates ( head_tail_updates ),

       .i_rc_icount ( wr_done_count ),
       .i_rc_count ( rd_done_count ),

       .clk ( clk ),
       .resetn ( internal_resetn )
   );

   xdma_rr_switch #(
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .DW_LOG ( DW_LOG ),
       .IS_TX ( IS_TX ),
       .DATA_FIFO_DL ( DATA_FIFO_DL ),
       .CPL_FIFO_DL ( CPL_FIFO_DL ),
       .DESC_FIFO_DL ( DESC_FIFO_DL ),
       .STS_FIFO_DL ( STS_FIFO_DL ),
       .KDIV ( KDIV ),
       .DESC_MAX ( DESC_MAX ),
       .DESC_RQ_DW ( DESC_RQ_DW ),
       .DESC_RQ_DK ( DESC_RQ_DK ),
       .DESC_RC_DW ( DESC_RC_DW ),
       .DESC_RC_DK ( DESC_RC_DK ),
       .RCBASE ( RCBASE ),
       .BURST_MAX ( BURST_MAX ),
       .CH_BASE ( CH_BASE ),
       .QEW_LOG ( QEW_LOG ),
       .RQ_DW ( RQ_DW ),
       .RQ_DK ( RQ_DK ),
       .RC_DW ( RC_DW ),
       .RQBASE ( RQBASE ),
       .CH_POS ( CH_POS ),
       .CPL_POS ( CPL_POS ),
       .QUEUE_DL ( QUEUE_DL ),
       .VP_MAP_NUM_LOG ( VP_MAP_NUM_LOG ),
       .D2D_AXI_BASE ( D2D_AXI_BASE ),
       .D2D_AXI_RANGE ( D2D_AXI_RANGE )
   ) switch (
       .axi_araddr ( axi_araddr ),
       .axi_arburst ( axi_arburst),
       .axi_arcache ( axi_arcache ),
       .axi_arid ( axi_arid ),
       .axi_arlen ( axi_arlen ),
       .axi_arlock ( axi_arlock ),
       .axi_arprot ( axi_arprot ),
       .axi_arsize ( axi_arsize ),
       .axi_arvalid ( axi_arvalid ),
       .axi_arready ( axi_arready ),
       .axi_rdata ( axi_rdata ),
       .axi_rid ( axi_rid ),
       .axi_rresp ( axi_rresp ),
       .axi_rlast ( axi_rlast ),
       .axi_rvalid ( axi_rvalid ),
       .axi_rready ( axi_rready ),
       .axi_awaddr ( axi_awaddr ),
       .axi_awburst ( axi_awburst),
       .axi_awcache ( axi_awcache ),
       .axi_awid ( axi_awid ),
       .axi_awlen ( axi_awlen ),
       .axi_awlock ( axi_awlock ),
       .axi_awprot ( axi_awprot ),
       .axi_awsize ( axi_awsize ),
       .axi_awvalid ( axi_awvalid ),
       .axi_awready ( axi_awready ),
       .axi_wdata ( axi_wdata ),
       .axi_wstrb ( axi_wstrb ),
       .axi_wid ( axi_wid ),
       .axi_wlast ( axi_wlast ),
       .axi_wvalid ( axi_wvalid ),
       .axi_wready ( axi_wready ),
       .axi_bid ( axi_bid ),
       .axi_bresp ( axi_bresp ),
       .axi_bvalid ( axi_bvalid ),
       .axi_bready ( axi_bready ),

       .reg_araddr ( bypass_reg_araddr ),
       .reg_arvalid ( bypass_reg_arvalid ),
       .reg_arready ( bypass_reg_arready ),
       .reg_rdata ( bypass_reg_rdata ),
       .reg_rresp ( bypass_reg_rresp ),
       .reg_rvalid ( bypass_reg_rvalid ),
       .reg_rready ( bypass_reg_rready ),
       .reg_awaddr ( bypass_reg_awaddr ),
       .reg_awvalid ( bypass_reg_awvalid ),
       .reg_awready ( bypass_reg_awready ),
       .reg_wdata ( bypass_reg_wdata ),
       .reg_wvalid ( bypass_reg_wvalid ),
       .reg_wready ( bypass_reg_wready ),
       .reg_bresp ( bypass_reg_bresp ),
       .reg_bvalid ( bypass_reg_bvalid ),
       .reg_bready ( bypass_reg_bready ),

       .stream_queue_read_ch ( stream_queue_read_ch ),
       .stream_queue_read_entry ( stream_queue_read_entry ),
       .stream_queue_read_valid ( stream_queue_read_valid ),
       .stream_queue_read_data ( stream_queue_read_data ),
       .stream_queue_read_data_valid ( stream_queue_read_data_valid ),

       .queue_update_data ( queue_update_data ),
       .queue_update_keep ( queue_update_keep ),
       .queue_update_valid ( queue_update_valid ),
       .queue_update_ready ( queue_update_ready ),
       .queue_wr_data ( queue_wr_data ),
       .queue_wr_keep ( queue_wr_keep ),
       .queue_wr_valid ( queue_wr_valid ),
       .queue_wr_ready ( queue_wr_ready ),
       .queue_check_data ( queue_check_data ),
       .queue_check_keep ( queue_check_keep ),
       .queue_check_valid ( queue_check_valid ),
       .queue_check_ready ( queue_check_ready ),
       .queue_check_res_data ( queue_check_res_data ),
       .queue_check_res_valid ( queue_check_res_valid ),
       .queue_rd_data ( queue_rd_data ),
       .queue_rd_keep ( queue_rd_keep ),
       .queue_rd_valid ( queue_rd_valid ),
       .queue_rd_ready ( queue_rd_ready ),
       .queue_rd_res_data ( queue_rd_res_data ),
       .queue_rd_res_valid ( queue_rd_res_valid ),

       .wr_desc_ctl ( wr_desc_ctl ),
       .wr_desc_dst_addr ( wr_desc_dst_addr ),
       .wr_desc_src_addr ( wr_desc_src_addr ),
       .wr_desc_len ( wr_desc_len ),
       .wr_desc_load ( wr_desc_load ),
       .wr_desc_ready ( wr_desc_ready ),
       .wr_tdata ( wr_tdata ),
       .wr_tkeep( wr_tkeep ),
       .wr_tlast ( wr_tlast ),
       .wr_tvalid ( wr_tvalid ),
       .wr_tready ( wr_tready ),
       .wr_sts ( wr_sts ),
       .wr_done_count ( wr_done_count ),
       .rd_desc_ctl ( rd_desc_ctl ),
       .rd_desc_dst_addr ( rd_desc_dst_addr ),
       .rd_desc_src_addr ( rd_desc_src_addr ),
       .rd_desc_len ( rd_desc_len ),
       .rd_desc_load ( rd_desc_load ),
       .rd_desc_ready ( rd_desc_ready ),
       .rd_tdata ( rd_tdata ),
       .rd_tkeep( rd_tkeep ),
       .rd_tlast ( rd_tlast ),
       .rd_tvalid ( rd_tvalid ),
       .rd_tready ( rd_tready ),
       .rd_sts ( rd_sts ),
       .rd_done_count ( rd_done_count ),

       .desc_req_data ( desc_req_data ),
       .desc_req_keep ( desc_req_keep ),
       .desc_req_valid ( desc_req_valid ),
       .desc_req_ready ( desc_req_ready ),
       .desc_out_data ( desc_out_data ),
       .desc_out_keep ( desc_out_keep ),
       .desc_out_valid ( desc_out_valid ),
       .desc_out_last ( desc_out_last ),
       .desc_out_ready ( desc_out_ready ),
       .desc_cpl_data ( desc_cpl_data ),
       .desc_cpl_ch ( desc_cpl_ch ),
       .desc_cpl_valid ( desc_cpl_valid ),
       .desc_cpl_ready ( desc_cpl_ready ),

       .data_desc_ctl ( data_desc_ctl ),
       .data_desc_src_addr ( data_desc_src_addr ),
       .data_desc_dst_addr ( data_desc_dst_addr ),
       .data_desc_len ( data_desc_len ),
       .data_desc_load ( data_desc_load ),
       .data_desc_ready ( data_desc_ready ),
       .data_sts ( data_sts ),

       .tx_in_tdata ( tx_in_tdata ),
       .tx_in_tkeep ( tx_in_tkeep ),
       .tx_in_tuser ( tx_in_tuser ),
       .tx_in_tlast ( tx_in_tlast ),
       .tx_in_sop ( tx_in_sop ),
       .tx_in_eop ( tx_in_eop ),
       .tx_in_tvalid ( tx_in_tvalid ),
       .tx_in_tready ( tx_in_tready ),
       .tx_out_tdata ( tx_out_tdata ),
       .tx_out_tkeep ( tx_out_tkeep ),
       .tx_out_tlast ( tx_out_tlast ),
       .tx_out_tvalid ( tx_out_tvalid ),
       .tx_out_tready ( tx_out_tready ),
       .rx_in_tdata ( rx_in_tdata ),
       .rx_in_tkeep ( rx_in_tkeep ),
       .rx_in_tlast ( rx_in_tlast ),
       .rx_in_tvalid ( rx_in_tvalid ),
       .rx_in_tready ( rx_in_tready ),
       .rx_out_tdata ( rx_out_tdata ),
       .rx_out_tkeep ( rx_out_tkeep ),
       .rx_out_tuser ( rx_out_tuser ),
       .rx_out_tlast ( rx_out_tlast ),
       .rx_out_eof ( rx_out_eof ),
       .rx_out_tvalid ( rx_out_tvalid ),
       .rx_out_tready ( rx_out_tready ),

       .stream_ch_valids ( stream_ch_valids ),
       .stream_ch_d2d_valids ( stream_ch_d2d_valids ),
       .stream_cpl_q_bases ( stream_cpl_q_bases ),
       .doorbell_addrs ( stream_doorbell_addrs ),
       .doorbell_int_enables ( stream_ch_interrupt_enables ),
       .head_tail_updates ( head_tail_updates ),

       .irq_out ( irq_out ),
       .irq_ack ( irq_ack ),
       .clk ( clk ),
       .resetn ( internal_resetn )
   );

   axil_switch #(
       .AW ( 16 )
   ) axil_switch (
       .in0_araddr ( bypass_reg_araddr ),
       .in0_arvalid ( bypass_reg_arvalid ),
       .in0_arready ( bypass_reg_arready ),
       .in0_rdata ( bypass_reg_rdata ),
       .in0_rresp ( bypass_reg_rresp ),
       .in0_rvalid ( bypass_reg_rvalid ),
       .in0_rready ( bypass_reg_rready ),
       .in0_awaddr ( bypass_reg_awaddr ),
       .in0_awvalid ( bypass_reg_awvalid ),
       .in0_awready ( bypass_reg_awready ),
       .in0_wdata ( bypass_reg_wdata ),
       .in0_wvalid ( bypass_reg_wvalid ),
       .in0_wready ( bypass_reg_wready ),
       .in0_bresp ( bypass_reg_bresp ),
       .in0_bvalid ( bypass_reg_bvalid ),
       .in0_bready ( bypass_reg_bready ),
       .in1_araddr ( reg_araddr ),
       .in1_arvalid ( reg_arvalid ),
       .in1_arready ( reg_arready ),
       .in1_rdata ( reg_rdata ),
       .in1_rresp ( reg_rresp ),
       .in1_rvalid ( reg_rvalid ),
       .in1_rready ( reg_rready ),
       .in1_awaddr ( reg_awaddr ),
       .in1_awvalid ( reg_awvalid ),
       .in1_awready ( reg_awready ),
       .in1_wdata ( reg_wdata ),
       .in1_wvalid ( reg_wvalid ),
       .in1_wready ( reg_wready ),
       .in1_bresp ( reg_bresp ),
       .in1_bvalid ( reg_bvalid ),
       .in1_bready ( reg_bready ),
       .out_araddr ( core_reg_araddr ),
       .out_arvalid ( core_reg_arvalid ),
       .out_arready ( core_reg_arready ),
       .out_rdata ( core_reg_rdata ),
       .out_rresp ( core_reg_rresp ),
       .out_rvalid ( core_reg_rvalid ),
       .out_rready ( core_reg_rready ),
       .out_awaddr ( core_reg_awaddr ),
       .out_awvalid ( core_reg_awvalid ),
       .out_awready ( core_reg_awready ),
       .out_wdata ( core_reg_wdata ),
       .out_wvalid ( core_reg_wvalid ),
       .out_wready ( core_reg_wready ),
       .out_bresp ( core_reg_bresp ),
       .out_bvalid ( core_reg_bvalid ),
       .out_bready ( core_reg_bready ),
       .clk ( clk ),
       .resetn ( internal_resetn )
   );


endmodule
