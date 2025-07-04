/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module axi_writer #(
    parameter DW = 512,
    parameter CTX_ID_BITS = 5,
    parameter BURST_MAX_LOG = 4,
    parameter HEADER_FIFO_DL = 2,
    parameter HEADER_OUT_FIFO_DL = 4,
    parameter DATA_FIFO_DL = BURST_MAX_LOG + 2,
    parameter DM_STS_FIFO_DL = 5,
    parameter IDEST_BITS = 4,
    parameter DM_ADDR_BITS = 40 // ceil to multiple of 8
    ) (
    input [DW-1:0]                idata_tdata,
    input [DW/8-1:0]              idata_tkeep,
    input [CTX_ID_BITS-1:0]       idata_tuser,
    input                         idata_tlast, // eop
    input                         idata_tvalid,
    output                        idata_tready,

    output [DM_ADDR_BITS-1:0]     axi_awaddr,
    output [7:0]                  axi_awlen,
    output [2:0]                  axi_awsize,
    output [1:0]                  axi_awburst,
    output [2:0]                  axi_awprot,
    output [3:0]                  axi_awcache,
    output [3:0]                  axi_awuser,
    output                        axi_awvalid,
    input                         axi_awready,
    output [DW-1:0]               axi_wdata,
    output [DW/8-1:0]             axi_wstrb,
    output                        axi_wlast,
    output                        axi_wvalid,
    input                         axi_wready,
    input [1:0]                   axi_bresp,
    input                         axi_bvalid,
    output                        axi_bready,

    input [127:0]                 frame_header_tdata, // [63:0] frame addr, [95:64] frame size, [103:96] frame id, [104+:ODEST_BITS] odest
    input [CTX_ID_BITS-1:0]       frame_header_tuser,
    input [IDEST_BITS-1:0]        frame_header_tdest,
    input                         frame_header_tvalid,
    output                        frame_header_tready,

    output [127:0]                frame_header_out_tdata, // [63:0] frame addr, [95:64] frame size, [103:96] frame id, [104+:ODEST_BITS] odest
    output [CTX_ID_BITS-1:0]      frame_header_out_tuser,
    output [IDEST_BITS-1:0]       frame_header_out_tdest,
    output                        frame_header_out_tvalid,
    input                         frame_header_out_tready,

    output [4:0]                  errors,
    output [(1<<CTX_ID_BITS)-1:0] underflows,

    input                         clk,
    input                         resetn
    );

   localparam KW = DW/8;

   wire [DW-1:0]            odata_tdata;
   wire [KW-1:0]            odata_tkeep;
   wire [CTX_ID_BITS-1:0]   odata_tuser;
   wire                     odata_tlast;
   wire                     odata_tvalid;
   wire                     odata_tready;

   wire [DM_ADDR_BITS+39:0] dm_cmd_tdata;
   wire                     dm_cmd_tvalid;
   wire                     dm_cmd_tready;
   wire [7:0]               dm_sts_tdata;
   wire                     dm_sts_tvalid;
   wire                     dm_sts_tready;

   axi_writer_ctrl #(
       .DW ( DW ),
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .BURST_MAX_LOG ( BURST_MAX_LOG ),
       .HEADER_FIFO_DL ( HEADER_FIFO_DL ),
       .HEADER_OUT_FIFO_DL ( HEADER_OUT_FIFO_DL ),
       .DATA_FIFO_DL ( DATA_FIFO_DL ),
       .DM_STS_FIFO_DL ( DM_STS_FIFO_DL ),
       .IDEST_BITS ( IDEST_BITS ),
       .DM_ADDR_BITS ( DM_ADDR_BITS )
   ) ctrl (
       .idata_tdata ( idata_tdata ),
       .idata_tkeep ( idata_tkeep ),
       .idata_tuser ( idata_tuser ),
       .idata_tlast ( idata_tlast ),
       .idata_tvalid ( idata_tvalid ),
       .idata_tready ( idata_tready ),
       .odata_tdata ( odata_tdata ),
       .odata_tkeep ( odata_tkeep ),
       .odata_tuser ( odata_tuser ),
       .odata_tlast ( odata_tlast ),
       .odata_tvalid ( odata_tvalid ),
       .odata_tready ( odata_tready ),
       .dm_cmd_tdata ( dm_cmd_tdata ),
       .dm_cmd_tvalid ( dm_cmd_tvalid ),
       .dm_cmd_tready ( dm_cmd_tready ),
       .dm_sts_tdata ( dm_sts_tdata ),
       .dm_sts_tvalid ( dm_sts_tvalid ),
       .dm_sts_tready ( dm_sts_tready ),
       .frame_header_tdata ( frame_header_tdata ),
       .frame_header_tuser ( frame_header_tuser ),
       .frame_header_tdest ( frame_header_tdest ),
       .frame_header_tvalid ( frame_header_tvalid ),
       .frame_header_tready ( frame_header_tready ),
       .frame_header_out_tdata ( frame_header_out_tdata ),
       .frame_header_out_tuser ( frame_header_out_tuser ),
       .frame_header_out_tdest ( frame_header_out_tdest ),
       .frame_header_out_tvalid ( frame_header_out_tvalid ),
       .frame_header_out_tready ( frame_header_out_tready ),
       .errors ( errors[3:0] ),
       .underflows ( underflows ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   datamover_for_writer dm (
       .m_axi_s2mm_aclk ( clk ),
       .m_axi_s2mm_aresetn ( resetn ),
       .s2mm_err ( errors[4] ),
       .m_axis_s2mm_cmdsts_awclk ( clk ),
       .m_axis_s2mm_cmdsts_aresetn ( resetn ),
       .s_axis_s2mm_cmd_tvalid ( dm_cmd_tvalid ),
       .s_axis_s2mm_cmd_tready ( dm_cmd_tready ),
       .s_axis_s2mm_cmd_tdata ( dm_cmd_tdata ),
       .m_axis_s2mm_sts_tvalid ( dm_sts_tvalid ),
       .m_axis_s2mm_sts_tready ( dm_sts_tready ),
       .m_axis_s2mm_sts_tdata ( dm_sts_tdata ),
       .m_axis_s2mm_sts_tkeep (  ),
       .m_axis_s2mm_sts_tlast (  ),
       .m_axi_s2mm_awaddr ( axi_awaddr ),
       .m_axi_s2mm_awlen ( axi_awlen ),
       .m_axi_s2mm_awsize ( axi_awsize ),
       .m_axi_s2mm_awburst ( axi_awburst ),
       .m_axi_s2mm_awprot ( axi_awprot ),
       .m_axi_s2mm_awcache ( axi_awcache ),
       .m_axi_s2mm_awuser ( axi_awuser ),
       .m_axi_s2mm_awvalid ( axi_awvalid ),
       .m_axi_s2mm_awready ( axi_awready ),
       .m_axi_s2mm_wdata ( axi_wdata ),
       .m_axi_s2mm_wstrb ( axi_wstrb ),
       .m_axi_s2mm_wlast ( axi_wlast ),
       .m_axi_s2mm_wvalid ( axi_wvalid ),
       .m_axi_s2mm_wready ( axi_wready ),
       .m_axi_s2mm_bresp ( axi_bresp ),
       .m_axi_s2mm_bvalid ( axi_bvalid ),
       .m_axi_s2mm_bready ( axi_bready ),
       .s_axis_s2mm_tdata ( odata_tdata ),
       .s_axis_s2mm_tkeep ( odata_tkeep ),
       .s_axis_s2mm_tlast ( odata_tlast ),
       .s_axis_s2mm_tvalid ( odata_tvalid ),
       .s_axis_s2mm_tready ( odata_tready )
   );

endmodule
