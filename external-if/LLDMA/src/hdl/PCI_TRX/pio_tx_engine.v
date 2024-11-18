/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module pio_tx_engine    #(

  parameter [1:0] AXISTEN_IF_WIDTH = 2'b11,
  parameter       AXI4_CC_TUSER_WIDTH = 81,
  parameter       AXI4_RQ_TUSER_WIDTH = 137,
  parameter       AXISTEN_IF_RQ_ALIGNMENT_MODE = 0,//DW alignment //modify "FALSE"->"0"
  parameter       AXISTEN_IF_CC_ALIGNMENT_MODE = 0,//DW alignment //modify "FALSE"->"0"
  parameter       AXISTEN_IF_ENABLE_CLIENT_TAG = 0,
  parameter       AXISTEN_IF_RQ_PARITY_CHECK   = 0,
  parameter       AXISTEN_IF_CC_PARITY_CHECK   = 0,

  parameter C_DATA_WIDTH = 512,

  parameter ADDR_W       = 16,                 // Memory Depth based on the C_DATA_WIDTH. 6bit -> 16bit modify
  parameter MEM_W        = 512,                // Memory Depth based on the C_DATA_WIDTH
  parameter BYTE_EN_W    = 64,                 // Width of byte enable going to memory for write data

  parameter PARITY_WIDTH = C_DATA_WIDTH /8,
  parameter KEEP_WIDTH   = C_DATA_WIDTH /32,
  parameter STRB_WIDTH   = C_DATA_WIDTH / 8

  )(

  input                          user_clk,
  input                          reset_n,

  // AXI-S Requester Request Interface

  output                                m_axis_rq_tvalid,
  output            [C_DATA_WIDTH-1:0]  m_axis_rq_tdata,
  output              [KEEP_WIDTH-1:0]  m_axis_rq_tkeep,
  output                                m_axis_rq_tlast,
  output     [AXI4_RQ_TUSER_WIDTH-1:0]  m_axis_rq_tuser,
  input                                 m_axis_rq_tready,

  // TX Message Interface

  input                          cfg_msg_transmit_done,
  output wire                    cfg_msg_transmit,
  output wire             [2:0]  cfg_msg_transmit_type,
  output wire            [31:0]  cfg_msg_transmit_data,

  //Tag availability and Flow control Information

  input                   [5:0]  pcie_rq_tag,
  input                          pcie_rq_tag_vld,
  input                   [3:0]  pcie_tfc_nph_av,
  input                   [3:0]  pcie_tfc_npd_av,
  input                          pcie_tfc_np_pl_empty,
  input                   [3:0]  pcie_rq_seq_num,
  input                          pcie_rq_seq_num_vld,

  //Cfg Flow Control Information

  input                   [7:0]  cfg_fc_ph,
  input                   [7:0]  cfg_fc_nph,
  input                   [7:0]  cfg_fc_cplh,
  input                  [11:0]  cfg_fc_pd,
  input                  [11:0]  cfg_fc_npd,
  input                  [11:0]  cfg_fc_cpld,
  output                  [2:0]  cfg_fc_sel,

  // Arb Control Interface

  input            [31:0]        reg_arb,

  // PA Interface

  output wire           [31:0]   pa_dmaw_pkt_cnt,
  output wire           [31:0]   pa_dmar_pkt_cnt,
  output wire           [31:0]   pa_enque_poling_pkt_cnt,
  output wire           [31:0]   pa_enque_clear_pkt_cnt,
  output wire           [31:0]   pa_deque_poling_pkt_cnt,
  output wire           [31:0]   pa_deque_pkt_cnt,

  input                          en_pa_pkt_cnt,
  input                          rst_pa_pkt_cnt,

  // Debug Deque Data

  output wire          [511:0]   deque_pkt_hold,

  // RQ Request Interface

  input                          rq_dmar_crd_axis_tvalid,
  input                [511:0]   rq_dmar_crd_axis_tdata,
  input                          rq_dmar_crd_axis_tlast,
  output                         rq_dmar_crd_axis_tready,

  input                          rq_dmar_cwr_axis_tvalid,
  input                [511:0]   rq_dmar_cwr_axis_tdata,
  input                          rq_dmar_cwr_axis_tlast,
  output                         rq_dmar_cwr_axis_tready,

  input                          rq_dmar_rd_axis_tvalid,
  input                [511:0]   rq_dmar_rd_axis_tdata,
  input                          rq_dmar_rd_axis_tlast,
  output                         rq_dmar_rd_axis_tready,

  input                          rq_dmaw_dwr_axis_tvalid,
  input                [511:0]   rq_dmaw_dwr_axis_tdata,
  input                          rq_dmaw_dwr_axis_tlast,
  output                         rq_dmaw_dwr_axis_tready,
  output                         rq_dmaw_dwr_axis_wr_ptr,
  output                         rq_dmaw_dwr_axis_rd_ptr,

  input                          rq_dmaw_cwr_axis_tvalid,
  input                [511:0]   rq_dmaw_cwr_axis_tdata,
  input                          rq_dmaw_cwr_axis_tlast,
  output                         rq_dmaw_cwr_axis_tready,

  input                          rq_dmaw_crd_axis_tvalid,
  input                [511:0]   rq_dmaw_crd_axis_tdata,
  input                          rq_dmaw_crd_axis_tlast,
  output                         rq_dmaw_crd_axis_tready
  );

  // registers

  wire            rq_dmar_cwr_axis_tvalid_1t ;
  wire  [511:0]   rq_dmar_cwr_axis_tdata_1t  ;
  wire            rq_dmar_cwr_axis_tlast_1t  ;
  reg            rq_dmaw_dwr_axis_tvalid_1t ;
  reg  [511:0]   rq_dmaw_dwr_axis_tdata_1t  ;
  reg            rq_dmaw_dwr_axis_tlast_1t  ;
  wire            rq_dmaw_cwr_axis_tvalid_1t ;
  wire  [511:0]   rq_dmaw_cwr_axis_tdata_1t  ;
  wire            rq_dmaw_cwr_axis_tlast_1t  ;

  wire [3:0]      rq_dmar_cwr_axis_last_be;
  wire [3:0]      rq_dmaw_cwr_axis_last_be;

  reg            in_packet_dmaw_dwr_q;

  reg            sop_dmaw_dwr_1t;


 // wire

  wire  [15:0]   rq_dmar_crd_axis_tkeep;
  wire  [15:0]   rq_dmar_cwr_axis_tkeep_1t;
  wire  [15:0]   rq_dmar_rd_axis_tkeep;
  wire  [15:0]   rq_dmaw_dwr_axis_tkeep_1t;
  wire  [15:0]   rq_dmaw_cwr_axis_tkeep_1t;
  wire  [15:0]   rq_dmaw_crd_axis_tkeep;

  wire           sop_dmaw_dwr;

  wire [511:0]   rq_dmar_cwr_axis_tdata_out  ;
  wire [511:0]   rq_dmaw_dwr_axis_tdata_out  ;
  wire [511:0]   rq_dmaw_cwr_axis_tdata_out  ;

 // CFG func sel

  assign cfg_fc_sel = 3'b0;

 // tdata generate
   cwr_keep_gen damr_cwr_keep_gen (
       .cwr_axis_tdata ( rq_dmar_cwr_axis_tdata ),
       .cwr_axis_tvalid ( rq_dmar_cwr_axis_tvalid ),
       .cwr_axis_tlast ( rq_dmar_cwr_axis_tlast ),
       .cwr_axis_tready ( rq_dmar_cwr_axis_tready ),
       .cwr_axis_tdata_out ( rq_dmar_cwr_axis_tdata_out ),
       .cwr_axis_tvalid_out ( rq_dmar_cwr_axis_tvalid_1t ),
       .cwr_axis_tlast_out ( rq_dmar_cwr_axis_tlast_1t ),
       .cwr_axis_tkeep_out ( rq_dmar_cwr_axis_tkeep_1t ),
       .cwr_axis_last_be ( rq_dmar_cwr_axis_last_be ),
       .clk ( user_clk ),
       .resetn ( reset_n )
   );

   cwr_keep_gen damw_cwr_keep_gen (
       .cwr_axis_tdata ( rq_dmaw_cwr_axis_tdata ),
       .cwr_axis_tvalid ( rq_dmaw_cwr_axis_tvalid ),
       .cwr_axis_tlast ( rq_dmaw_cwr_axis_tlast ),
       .cwr_axis_tready ( rq_dmaw_cwr_axis_tready ),
       .cwr_axis_tdata_out ( rq_dmaw_cwr_axis_tdata_out ),
       .cwr_axis_tvalid_out ( rq_dmaw_cwr_axis_tvalid_1t ),
       .cwr_axis_tlast_out ( rq_dmaw_cwr_axis_tlast_1t ),
       .cwr_axis_tkeep_out ( rq_dmaw_cwr_axis_tkeep_1t ),
       .cwr_axis_last_be ( rq_dmaw_cwr_axis_last_be ),
       .clk ( user_clk ),
       .resetn ( reset_n )
   );

  assign rq_dmaw_dwr_axis_tdata_out = ( sop_dmaw_dwr_1t == 1'b1) ? {rq_dmaw_dwr_axis_tdata[383:0],rq_dmaw_dwr_axis_tdata_1t[127:0]} :
                                                                   {rq_dmaw_dwr_axis_tdata[383:0],rq_dmaw_dwr_axis_tdata_1t[511:384]};

  assign rq_dmar_crd_axis_tkeep    = 16'h000f;
  assign rq_dmar_rd_axis_tkeep     = 16'h000f;
  assign rq_dmaw_dwr_axis_tkeep_1t = ( rq_dmaw_dwr_axis_tlast_1t == 1'b1) ? 16'h000f : 16'hffff;
  assign rq_dmaw_crd_axis_tkeep    = 16'h000f;

  // ---------------------------------------------------
  // SOP detect
  // ---------------------------------------------------
  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n) begin
      in_packet_dmaw_dwr_q <= 1'b0;
    end else if (rq_dmaw_dwr_axis_tvalid && rq_dmaw_dwr_axis_tready && rq_dmaw_dwr_axis_tlast) begin
      in_packet_dmaw_dwr_q <= 1'b0;
    end else if (sop_dmaw_dwr && rq_dmaw_dwr_axis_tready) begin
      in_packet_dmaw_dwr_q <= 1'b1;
    end
  end
  assign sop_dmaw_dwr = !in_packet_dmaw_dwr_q && rq_dmaw_dwr_axis_tvalid;

  // ---------------------------------------------------
  // Format Convert FF
  // ---------------------------------------------------

  always @(posedge user_clk or negedge reset_n) 
  begin
    if(!reset_n)begin
      rq_dmaw_dwr_axis_tvalid_1t <= 0;
      rq_dmaw_dwr_axis_tdata_1t  <= 0;
      rq_dmaw_dwr_axis_tlast_1t  <= 0;
      sop_dmaw_dwr_1t            <= 0;
    end else if ( rq_dmaw_dwr_axis_tready == 1'b1 ) begin
      rq_dmaw_dwr_axis_tvalid_1t <= rq_dmaw_dwr_axis_tvalid;
      rq_dmaw_dwr_axis_tdata_1t  <= rq_dmaw_dwr_axis_tdata ;
      rq_dmaw_dwr_axis_tlast_1t  <= rq_dmaw_dwr_axis_tlast ;
      sop_dmaw_dwr_1t            <= sop_dmaw_dwr;
    end
  end

  // ---------------------------------------------------
  // ARBITER
  // ---------------------------------------------------

  pio_tx_arbiter arbiter (
    .user_clk     (user_clk),
    .reset_n      (reset_n),

    .rq_dmar_crd_axis_tvalid (rq_dmar_crd_axis_tvalid),
    .rq_dmar_crd_axis_tdata  (rq_dmar_crd_axis_tdata ),
    .rq_dmar_crd_axis_tlast  (rq_dmar_crd_axis_tlast ),
    .rq_dmar_crd_axis_tkeep  (rq_dmar_crd_axis_tkeep ),
    .rq_dmar_crd_axis_tready (rq_dmar_crd_axis_tready),

    .rq_dmar_cwr_axis_tvalid (rq_dmar_cwr_axis_tvalid_1t),
    .rq_dmar_cwr_axis_tdata  (rq_dmar_cwr_axis_tdata_out),
    .rq_dmar_cwr_axis_tlast  (rq_dmar_cwr_axis_tlast_1t ),
    .rq_dmar_cwr_axis_tkeep  (rq_dmar_cwr_axis_tkeep_1t ),
    .rq_dmar_cwr_axis_last_be(rq_dmar_cwr_axis_last_be ),
    .rq_dmar_cwr_axis_tready (rq_dmar_cwr_axis_tready),

    .rq_dmar_rd_axis_tvalid  (rq_dmar_rd_axis_tvalid),
    .rq_dmar_rd_axis_tdata   (rq_dmar_rd_axis_tdata ),
    .rq_dmar_rd_axis_tlast   (rq_dmar_rd_axis_tlast ),
    .rq_dmar_rd_axis_tkeep   (rq_dmar_rd_axis_tkeep ),
    .rq_dmar_rd_axis_tready  (rq_dmar_rd_axis_tready),

    .rq_dmaw_dwr_axis_tvalid (rq_dmaw_dwr_axis_tvalid_1t),
    .rq_dmaw_dwr_axis_tdata  (rq_dmaw_dwr_axis_tdata_out),
    .rq_dmaw_dwr_axis_tlast  (rq_dmaw_dwr_axis_tlast_1t ),
    .rq_dmaw_dwr_axis_tkeep  (rq_dmaw_dwr_axis_tkeep_1t ),
    .rq_dmaw_dwr_axis_tready (rq_dmaw_dwr_axis_tready),
    .rq_dmaw_dwr_axis_wr_ptr (rq_dmaw_dwr_axis_wr_ptr ),
    .rq_dmaw_dwr_axis_rd_ptr (rq_dmaw_dwr_axis_rd_ptr ),

    .rq_dmaw_cwr_axis_tvalid (rq_dmaw_cwr_axis_tvalid_1t),
    .rq_dmaw_cwr_axis_tdata  (rq_dmaw_cwr_axis_tdata_out),
    .rq_dmaw_cwr_axis_tlast  (rq_dmaw_cwr_axis_tlast_1t ),
    .rq_dmaw_cwr_axis_tkeep  (rq_dmaw_cwr_axis_tkeep_1t ),
    .rq_dmaw_cwr_axis_last_be(rq_dmaw_cwr_axis_last_be ),
    .rq_dmaw_cwr_axis_tready (rq_dmaw_cwr_axis_tready),

    .rq_dmaw_crd_axis_tvalid (rq_dmaw_crd_axis_tvalid),
    .rq_dmaw_crd_axis_tdata  (rq_dmaw_crd_axis_tdata ),
    .rq_dmaw_crd_axis_tlast  (rq_dmaw_crd_axis_tlast ),
    .rq_dmaw_crd_axis_tkeep  (rq_dmaw_crd_axis_tkeep ),
    .rq_dmaw_crd_axis_tready (rq_dmaw_crd_axis_tready),

    .m_axis_rq_tvalid        (m_axis_rq_tvalid       ),
    .m_axis_rq_tdata         (m_axis_rq_tdata        ),
    .m_axis_rq_tkeep         (m_axis_rq_tkeep        ),
    .m_axis_rq_tlast         (m_axis_rq_tlast        ),
    .m_axis_rq_tuser         (m_axis_rq_tuser        ),
    .m_axis_rq_tready        (m_axis_rq_tready       ),

    .reg_arb                 (reg_arb                ),

    .pa_dmaw_pkt_cnt         (pa_dmaw_pkt_cnt        ),
    .pa_dmar_pkt_cnt         (pa_dmar_pkt_cnt        ),
    .pa_enque_poling_pkt_cnt (pa_enque_poling_pkt_cnt),
    .pa_enque_clear_pkt_cnt  (pa_enque_clear_pkt_cnt ),
    .pa_deque_poling_pkt_cnt (pa_deque_poling_pkt_cnt),
    .pa_deque_pkt_cnt        (pa_deque_pkt_cnt       ),

    .en_pa_pkt_cnt           (en_pa_pkt_cnt          ),
    .rst_pa_pkt_cnt          (rst_pa_pkt_cnt         ),

    .deque_pkt_hold          (deque_pkt_hold         )

    );

  // ---------------------------------------------------
  // clip
  // ---------------------------------------------------

    assign cfg_msg_transmit      = 0;
    assign cfg_msg_transmit_type = 0;
    assign cfg_msg_transmit_data = 0;

endmodule // pio_tx_engine
