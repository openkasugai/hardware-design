/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module axi_reader #(
    parameter DW = 512,
    parameter CTX_ID_BITS = 5,
    parameter BURST_MAX_LOG = 4,
    parameter HEADER_FIFO_DL = 2,
    parameter HEADER_OUT_FIFO_DL = 4,
    parameter DATA_FIFO_DL = BURST_MAX_LOG + 2,
    parameter DM_STS_FIFO_DL = 5,
    parameter RR_BITS = 4,
    parameter ODEST_BITS = 4,
    parameter DM_ADDR_BITS = 40 // ceil to multiple of 8
    ) (
    output [DW-1:0]               odata_tdata,
    output [DW/8-1:0]             odata_tkeep,
    output [CTX_ID_BITS-1:0]      odata_tuser,
    output [ODEST_BITS-1:0]       odata_tdest,
    output                        odata_tlast, // eof
    output                        odata_tvalid,
    input                         odata_tready,

    output [DM_ADDR_BITS-1:0]     axi_araddr,
    output [7:0]                  axi_arlen,
    output [2:0]                  axi_arsize,
    output [1:0]                  axi_arburst,
    output [2:0]                  axi_arprot,
    output [3:0]                  axi_arcache,
    output [3:0]                  axi_aruser,
    output                        axi_arvalid,
    input                         axi_arready,
    input [DW-1:0]                axi_rdata,
    input [1:0]                   axi_rresp,
    input                         axi_rlast,
    input                         axi_rvalid,
    output                        axi_rready,

    input [127:0]                 frame_complete_tdata, // [63:0] frame addr, [95:64] frame size, [103:96] frame id
    input [CTX_ID_BITS-1:0]       frame_complete_tuser,
    input                         frame_complete_tvalid,
    output                        frame_complete_tready,

    output [127:0]                frame_complete_consume_tdata, // [63:0] frame addr, [95:64] frame size, [103:96] frame id, [104+:ODEST_BITS] odest
    output [CTX_ID_BITS-1:0]      frame_complete_consume_tuser,
    output [ODEST_BITS-1:0]       frame_complete_consume_tdest,
    output                        frame_complete_consume_tvalid,
    input                         frame_complete_consume_tready,

    output [7:0]                  frame_consume_tdata, // [7:0] frame id
    output [CTX_ID_BITS-1:0]      frame_consume_tuser,
    output [ODEST_BITS-1:0]       frame_consume_tdest,
    output                        frame_consume_tvalid,
    input                         frame_consume_tready,

    output [5:0]                  errors,
    output [(1<<CTX_ID_BITS)-1:0] underflows,

    input                         clk,
    input                         resetn
    );

   wire [DW-1:0]           idata_tdata;
   wire [DW/8-1:0]         idata_tkeep;
   wire                    idata_tlast;
   wire                    idata_tvalid;
   wire                    idata_tready;

   wire [DM_ADDR_BITS+39:0] dm_cmd_tdata;
   wire                     dm_cmd_tvalid;
   wire                     dm_cmd_tready;
   wire [7:0]               dm_sts_tdata;
   wire                     dm_sts_tvalid;
   wire                     dm_sts_tready;

   axi_reader_ctrl #(
       .DW ( DW ),
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .BURST_MAX_LOG ( BURST_MAX_LOG ),
       .HEADER_FIFO_DL ( HEADER_FIFO_DL ),
       .HEADER_OUT_FIFO_DL ( HEADER_OUT_FIFO_DL ),
       .DATA_FIFO_DL ( DATA_FIFO_DL ),
       .DM_STS_FIFO_DL ( DM_STS_FIFO_DL ),
       .RR_BITS ( RR_BITS ),
       .DM_ADDR_BITS ( DM_ADDR_BITS ),
       .ODEST_BITS ( ODEST_BITS )
   ) ctrl (
       .idata_tdata ( idata_tdata ),
       .idata_tkeep ( idata_tkeep ),
       .idata_tlast ( idata_tlast ),
       .idata_tvalid ( idata_tvalid ),
       .idata_tready ( idata_tready ),
       .odata_tdata ( odata_tdata ),
       .odata_tkeep ( odata_tkeep ),
       .odata_tuser ( odata_tuser ),
       .odata_tdest ( odata_tdest ),
       .odata_tlast ( odata_tlast ),
       .odata_tvalid ( odata_tvalid ),
       .odata_tready ( odata_tready ),
       .dm_cmd_tdata ( dm_cmd_tdata ),
       .dm_cmd_tvalid ( dm_cmd_tvalid ),
       .dm_cmd_tready ( dm_cmd_tready ),
       .dm_sts_tdata ( dm_sts_tdata ),
       .dm_sts_tvalid ( dm_sts_tvalid ),
       .dm_sts_tready ( dm_sts_tready ),
       .frame_complete_tdata ( frame_complete_tdata ),
       .frame_complete_tuser ( frame_complete_tuser ),
       .frame_complete_tvalid ( frame_complete_tvalid ),
       .frame_complete_tready ( frame_complete_tready ),
       .frame_complete_consume_tdata ( frame_complete_consume_tdata ),
       .frame_complete_consume_tuser ( frame_complete_consume_tuser ),
       .frame_complete_consume_tdest ( frame_complete_consume_tdest ),
       .frame_complete_consume_tvalid ( frame_complete_consume_tvalid ),
       .frame_complete_consume_tready ( frame_complete_consume_tready ),
       .frame_consume_tdata ( frame_consume_tdata ),
       .frame_consume_tuser ( frame_consume_tuser ),
       .frame_consume_tdest ( frame_consume_tdest ),
       .frame_consume_tvalid ( frame_consume_tvalid ),
       .frame_consume_tready ( frame_consume_tready ),
       .errors ( errors[4:0] ),
       .underflows ( underflows ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   datamover_for_reader dm (
       .m_axi_mm2s_aclk ( clk ),
       .m_axi_mm2s_aresetn ( resetn ),
       .mm2s_err ( errors[5] ),
       .m_axis_mm2s_cmdsts_aclk ( clk ),
       .m_axis_mm2s_cmdsts_aresetn ( resetn ),
       .s_axis_mm2s_cmd_tvalid ( dm_cmd_tvalid ),
       .s_axis_mm2s_cmd_tready ( dm_cmd_tready ),
       .s_axis_mm2s_cmd_tdata ( dm_cmd_tdata ),
       .m_axis_mm2s_sts_tvalid ( dm_sts_tvalid ),
       .m_axis_mm2s_sts_tready ( dm_sts_tready ),
       .m_axis_mm2s_sts_tdata ( dm_sts_tdata ),
       .m_axis_mm2s_sts_tkeep (  ),
       .m_axis_mm2s_sts_tlast (  ),
       .m_axi_mm2s_araddr ( axi_araddr ),
       .m_axi_mm2s_arlen ( axi_arlen ),
       .m_axi_mm2s_arsize ( axi_arsize ),
       .m_axi_mm2s_arburst ( axi_arburst ),
       .m_axi_mm2s_arprot ( axi_arprot ),
       .m_axi_mm2s_arcache ( axi_arcache ),
       .m_axi_mm2s_aruser ( axi_aruser ),
       .m_axi_mm2s_arvalid ( axi_arvalid ),
       .m_axi_mm2s_arready ( axi_arready ),
       .m_axi_mm2s_rdata ( axi_rdata ),
       .m_axi_mm2s_rresp ( axi_rresp ),
       .m_axi_mm2s_rlast ( axi_rlast ),
       .m_axi_mm2s_rvalid ( axi_rvalid ),
       .m_axi_mm2s_rready ( axi_rready ),
       .m_axis_mm2s_tdata ( idata_tdata ),
       .m_axis_mm2s_tkeep ( idata_tkeep ),
       .m_axis_mm2s_tlast ( idata_tlast ),
       .m_axis_mm2s_tvalid ( idata_tvalid ),
       .m_axis_mm2s_tready ( idata_tready )
   );

endmodule
