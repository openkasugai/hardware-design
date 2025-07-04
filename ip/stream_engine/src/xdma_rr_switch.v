/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module xdma_rr_switch #(
    parameter CH_NUM_LOG = 3,
    parameter DW_LOG = 9,
    parameter IS_TX = 0,
    parameter DATA_FIFO_DL = 7,
    parameter CPL_FIFO_DL = 4,
    parameter DESC_FIFO_DL = 7,
    parameter STS_FIFO_DL = 7,
    parameter KDIV = 4,
    parameter DESC_MAX = 4,
    parameter DESC_RQ_DW = 512,
    parameter DESC_RQ_DK = 16,
    parameter DESC_RC_DW = 512,
    parameter DESC_RC_DK = 16,
    parameter RCBASE = 96,
    parameter BURST_MAX = 4,
    parameter CH_BASE = 0,
    parameter QEW_LOG = 5,
    parameter RQ_DW = 384,
    parameter RQ_DK = 12,
    parameter RC_DW = 352,
    parameter RQBASE = 128,
    parameter CH_POS = RQBASE + 32,
    parameter CPL_POS = RQBASE + 64,
    parameter QUEUE_DL = 3,
    parameter VP_MAP_NUM_LOG = 5,
    parameter [39:0] D2D_AXI_BASE = 40'h0,
    parameter [31:0] D2D_AXI_RANGE = 32'h4000_0000 // 1GB
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
    // axilite master
    output [15:0]                reg_araddr,
    output                       reg_arvalid,
    input                        reg_arready,
    input [31:0]                 reg_rdata,
    input [1:0]                  reg_rresp,
    input                        reg_rvalid,
    output                       reg_rready,
    output [15:0]                reg_awaddr,
    output                       reg_awvalid,
    input                        reg_awready,
    output [31:0]                reg_wdata,
    output                       reg_wvalid,
    input                        reg_wready,
    input [1:0]                  reg_bresp,
    input                        reg_bvalid,
    output                       reg_bready,
    // queue element read
    output [CH_NUM_LOG-1:0]      stream_queue_read_ch,
    output [QUEUE_DL-1:0]        stream_queue_read_entry,
    output                       stream_queue_read_valid,
    input [(8<<QEW_LOG)-1:0]     stream_queue_read_data,
    input                        stream_queue_read_data_valid,
    // queue update (from core)
    input [RQ_DW-1:0]            queue_update_data,
    input [RQ_DK-1:0]            queue_update_keep,
    input                        queue_update_valid,
    output                       queue_update_ready,
    // queue write (from core)
    input [RQ_DW-1:0]            queue_wr_data,
    input [RQ_DK-1:0]            queue_wr_keep,
    input                        queue_wr_valid,
    output                       queue_wr_ready,
    // queue check (from core)
    input [RQ_DW-1:0]            queue_check_data,
    input [RQ_DK-1:0]            queue_check_keep,
    input                        queue_check_valid,
    output                       queue_check_ready,
    output [RC_DW-1:0]           queue_check_res_data,
    output                       queue_check_res_valid,
    // queue read (from core)
    input [RQ_DW-1:0]            queue_rd_data,
    input [RQ_DK-1:0]            queue_rd_keep,
    input                        queue_rd_valid,
    output                       queue_rd_ready,
    output [RC_DW-1:0]           queue_rd_res_data,
    output                       queue_rd_res_valid,
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
    // descriptor read req
    output [DESC_RQ_DW-1:0]      desc_req_data,
    output [DESC_RQ_DK-1:0]      desc_req_keep,
    output                       desc_req_valid,
    input                        desc_req_ready,
    // descriptor read result
    input [DESC_RC_DW-1:0]       desc_out_data,
    input [DESC_RC_DK-1:0]       desc_out_keep,
    input                        desc_out_last,
    input                        desc_out_valid,
    output                       desc_out_ready,
    // descriptor completion
    output [31:0]                desc_cpl_data,
    output [CH_NUM_LOG-1:0]      desc_cpl_ch,
    output                       desc_cpl_valid,
    input                        desc_cpl_ready,
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
    // wire from register
    input [(1<<CH_NUM_LOG)-1:0]  stream_ch_valids,
    input [(1<<CH_NUM_LOG)-1:0]  stream_ch_d2d_valids,
    input [(64<<CH_NUM_LOG)-1:0] stream_cpl_q_bases,
    input [(1<<CH_NUM_LOG)-1:0]  head_tail_updates,
    input [(64<<CH_NUM_LOG)-1:0] doorbell_addrs,
    input [(1<<CH_NUM_LOG)-1:0]  doorbell_int_enables,
    // interrupt
    output [(1<<CH_NUM_LOG)-1:0] irq_out,
    input [(1<<CH_NUM_LOG)-1:0]  irq_ack,
    // global
    input                        clk,
    input                        resetn
    );

   localparam QEW = 1 << QEW_LOG;
   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam DW = 1 << DW_LOG;
   localparam KW_LOG = DW_LOG - 3;
   localparam KW = 1 << KW_LOG;

   xdma_rd_switch #(
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .DW ( DW ),
       .RQ_DW ( RQ_DW ),
       .RQ_DK ( RQ_DK ),
       .RC_DW ( RC_DW )
   ) rd_switch (
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
       .desc_ctl ( rd_desc_ctl ),
       .desc_dst_addr ( rd_desc_dst_addr ),
       .desc_src_addr ( rd_desc_src_addr ),
       .desc_len ( rd_desc_len ),
       .desc_load ( rd_desc_load ),
       .desc_ready ( rd_desc_ready ),
       .rd_tdata ( rd_tdata ),
       .rd_tkeep( rd_tkeep ),
       .rd_tlast ( rd_tlast ),
       .rd_tvalid ( rd_tvalid ),
       .rd_tready ( rd_tready ),
       .sts ( rd_sts ),
       .done_count ( rd_done_count ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   xdma_wr_switch #(
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .DW ( DW ),
       .QEW ( QEW ),
       .RQ_DW ( RQ_DW ),
       .RQ_DK ( RQ_DK ),
       .RQBASE ( RQBASE ),
       .CH_POS ( CH_POS ),
       .CPL_POS ( CPL_POS )
   ) wr_switch (
       .queue_update_data ( queue_update_data ),
       .queue_update_keep ( queue_update_keep ),
       .queue_update_valid ( queue_update_valid ),
       .queue_update_ready ( queue_update_ready ),
       .queue_wr_data ( queue_wr_data ),
       .queue_wr_keep ( queue_wr_keep ),
       .queue_wr_valid ( queue_wr_valid ),
       .queue_wr_ready ( queue_wr_ready ),
       .head_tail_updates ( head_tail_updates ),
       .desc_ctl ( wr_desc_ctl ),
       .desc_dst_addr ( wr_desc_dst_addr ),
       .desc_src_addr ( wr_desc_src_addr ),
       .desc_len ( wr_desc_len ),
       .desc_load ( wr_desc_load ),
       .desc_ready ( wr_desc_ready ),
       .wr_tdata ( wr_tdata ),
       .wr_tkeep( wr_tkeep ),
       .wr_tlast ( wr_tlast ),
       .wr_tvalid ( wr_tvalid ),
       .wr_tready ( wr_tready ),
       .sts ( wr_sts ),
       .done_count ( wr_done_count ),
       .doorbell_addrs ( doorbell_addrs ),
       .doorbell_int_enables ( doorbell_int_enables ),
       .irq_out ( irq_out ),
       .irq_ack ( irq_ack ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   generate
      if (IS_TX == 0) begin
         wire [DW-1:0]              rx_d2d_tdata;
         wire [KW-1:0]              rx_d2d_tkeep;
         wire [CH_NUM_LOG-1:0]      rx_d2d_tuser;
         wire                       rx_d2d_tlast;
         wire                       rx_d2d_tvalid;
         wire                       rx_d2d_eof;
         wire                       rx_d2d_tready;

         xdma_rx_switch #(
             .CH_NUM_LOG ( CH_NUM_LOG ),
             .DW ( DW ),
             .DATA_FIFO_DL ( DATA_FIFO_DL ),
             .CPL_FIFO_DL ( CPL_FIFO_DL ),
             .DESC_FIFO_DL ( DESC_FIFO_DL ),
             .STS_FIFO_DL ( STS_FIFO_DL ),
             .DESC_MAX ( DESC_MAX ),
             .DESC_RQ_DW ( DESC_RQ_DW ),
             .DESC_RQ_DK ( DESC_RQ_DK ),
             .DESC_RC_DW ( DESC_RC_DW ),
             .DESC_RC_DK ( DESC_RC_DK ),
             .RCBASE ( RCBASE ),
             .BURST_MAX ( BURST_MAX ),
             .CH_BASE ( CH_BASE )
         ) rx_switch (
             .stream_ch_valids ( stream_ch_valids ),
             .desc_req_data ( desc_req_data ),
             .desc_req_keep ( desc_req_keep ),
             .desc_req_valid ( desc_req_valid ),
             .desc_req_ready ( desc_req_ready ),
             .desc_out_data ( desc_out_data ),
             .desc_out_keep ( desc_out_keep ),
             .desc_out_last ( desc_out_last ),
             .desc_out_valid ( desc_out_valid ),
             .desc_out_ready ( desc_out_ready ),
             .desc_cpl_data ( desc_cpl_data ),
             .desc_cpl_ch ( desc_cpl_ch ),
             .desc_cpl_valid ( desc_cpl_valid ),
             .desc_cpl_ready ( desc_cpl_ready ),
             .rx_in_tdata ( rx_in_tdata ),
             .rx_in_tkeep ( rx_in_tkeep ),
             .rx_in_tlast ( rx_in_tlast ),
             .rx_in_tvalid ( rx_in_tvalid ),
             .rx_in_tready ( rx_in_tready ),
             .desc_ctl ( data_desc_ctl ),
             .desc_src_addr ( data_desc_src_addr ),
             .desc_dst_addr ( data_desc_dst_addr ),
             .desc_len ( data_desc_len ),
             .desc_load ( data_desc_load ),
             .desc_ready ( data_desc_ready ),
             .sts ( data_sts ),
             .rx_d2d_tdata ( rx_d2d_tdata ),
             .rx_d2d_tkeep ( rx_d2d_tkeep ),
             .rx_d2d_tuser ( rx_d2d_tuser ),
             .rx_d2d_tlast ( rx_d2d_tlast ),
             .rx_d2d_eof ( rx_d2d_eof ),
             .rx_d2d_tvalid ( rx_d2d_tvalid ),
             .rx_d2d_tready ( rx_d2d_tready ),
             .rx_out_tdata ( rx_out_tdata ),
             .rx_out_tkeep ( rx_out_tkeep ),
             .rx_out_tuser ( rx_out_tuser ),
             .rx_out_tlast ( rx_out_tlast ),
             .rx_out_eof ( rx_out_eof ),
             .rx_out_tvalid ( rx_out_tvalid ),
             .rx_out_tready ( rx_out_tready ),
             .clk ( clk ),
             .resetn ( resetn )
         );

         xdma_bypass_axi #(
             .CH_NUM_LOG ( CH_NUM_LOG ),
             .DW_LOG ( DW_LOG ),
             .QEW_LOG ( QEW_LOG ),
             .QUEUE_DL ( QUEUE_DL ),
             .D2D_AXI_BASE ( D2D_AXI_BASE ),
             .D2D_AXI_RANGE ( D2D_AXI_RANGE )
         ) bypass_axi (
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
             .axis_tdata ( rx_d2d_tdata ),
             .axis_tkeep ( rx_d2d_tkeep ),
             .axis_tuser ( rx_d2d_tuser ),
             .axis_tlast ( rx_d2d_tlast ),
             .axis_eof ( rx_d2d_eof ),
             .axis_tvalid ( rx_d2d_tvalid ),
             .axis_tready ( rx_d2d_tready ),
             .reg_araddr ( reg_araddr ),
             .reg_arvalid ( reg_arvalid ),
             .reg_arready ( reg_arready ),
             .reg_rdata ( reg_rdata ),
             .reg_rresp ( reg_rresp ),
             .reg_rvalid ( reg_rvalid ),
             .reg_rready ( reg_rready ),
             .reg_awaddr ( reg_awaddr ),
             .reg_awvalid ( reg_awvalid ),
             .reg_awready ( reg_awready ),
             .reg_wdata ( reg_wdata ),
             .reg_wvalid ( reg_wvalid ),
             .reg_wready ( reg_wready ),
             .reg_bresp ( reg_bresp ),
             .reg_bvalid ( reg_bvalid ),
             .reg_bready ( reg_bready ),
             .stream_queue_read_ch ( stream_queue_read_ch ),
             .stream_queue_read_entry ( stream_queue_read_entry ),
             .stream_queue_read_valid ( stream_queue_read_valid ),
             .stream_queue_read_data ( stream_queue_read_data ),
             .stream_queue_read_data_valid ( stream_queue_read_data_valid ),
             .clk ( clk ),
             .resetn ( resetn )
         );

         assign tx_in_tready = 1'b1;
         assign tx_out_tvalid = 1'b0;
      end else begin
         xdma_tx_switch #(
             .CH_NUM_LOG ( CH_NUM_LOG ),
             .DW ( DW ),
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
             .CH_BASE ( CH_BASE )
         ) tx_switch (
             .stream_ch_valids ( stream_ch_valids ),
             .stream_ch_d2d_valids ( stream_ch_d2d_valids ),
             .stream_cpl_q_bases ( stream_cpl_q_bases ),
             .desc_req_data ( desc_req_data ),
             .desc_req_keep ( desc_req_keep ),
             .desc_req_valid ( desc_req_valid ),
             .desc_req_ready ( desc_req_ready ),
             .desc_out_data ( desc_out_data ),
             .desc_out_keep ( desc_out_keep ),
             .desc_out_last ( desc_out_last ),
             .desc_out_valid ( desc_out_valid ),
             .desc_out_ready ( desc_out_ready ),
             .desc_cpl_data ( desc_cpl_data ),
             .desc_cpl_ch ( desc_cpl_ch ),
             .desc_cpl_valid ( desc_cpl_valid ),
             .desc_cpl_ready ( desc_cpl_ready ),
             .tx_in_tdata ( tx_in_tdata ),
             .tx_in_tkeep ( tx_in_tkeep ),
             .tx_in_tuser ( tx_in_tuser ),
             .tx_in_tlast ( tx_in_tlast ),
             .tx_in_sop ( tx_in_sop ),
             .tx_in_eop ( tx_in_eop ),
             .tx_in_tvalid ( tx_in_tvalid ),
             .tx_in_tready ( tx_in_tready ),
             .desc_ctl ( data_desc_ctl ),
             .desc_src_addr ( data_desc_src_addr ),
             .desc_dst_addr ( data_desc_dst_addr ),
             .desc_len ( data_desc_len ),
             .desc_load ( data_desc_load ),
             .desc_ready ( data_desc_ready ),
             .sts ( data_sts ),
             .tx_out_tdata ( tx_out_tdata ),
             .tx_out_tkeep ( tx_out_tkeep ),
             .tx_out_tlast ( tx_out_tlast ),
             .tx_out_tvalid ( tx_out_tvalid ),
             .tx_out_tready ( tx_out_tready ),
             .clk ( clk ),
             .resetn ( resetn )
         );
         assign rx_d2d_tready = 1'b1;
         assign rx_in_tready = 1'b1;
         assign rx_out_tvalid = 1'b0;
         assign axi_arready = 1'b1;
         assign axi_rvalid = 1'b0;
         assign axi_awready = 1'b1;
         assign axi_wready = 1'b1;
         assign axi_bvalid = 1'b0;
         assign reg_arvalid = 1'b0;
         assign reg_rready = 1'b1;
         assign reg_awvalid = 1'b0;
         assign reg_wvalid = 1'b0;
         assign reg_bready = 1'b1;
         assign stream_queue_read_valid = 1'b0;
      end
   endgenerate

endmodule
