/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module rs #(
  parameter CHAIN_NUM  = 4
)(
  input  logic                        user_clk,
  input  logic                        reset_n,
  input  logic                        ext_clk,
  input  logic                        ext_reset_n,

// PCI_TRX
  input  logic                        regreq_axis_tvalid_cifdn,
  input  logic                        regreq_axis_tvalid_cifup,
  input  logic                        regreq_axis_tvalid_dmar,
  input  logic                        regreq_axis_tvalid_dmat,
  input  logic [511:0]                regreq_axis_tdata,
  input  logic                        regreq_axis_tlast,
  input  logic [ 63:0]                regreq_axis_tuser,

  output logic                        regreq_axis_tvalid_dmar_rs,
  output logic [511:0]                regreq_axis_tdata_dmar_rs,
  output logic                        regreq_axis_tlast_dmar_rs,
  output logic [ 63:0]                regreq_axis_tuser_dmar_rs,

  output logic                        regreq_axis_tvalid_dmat_rs,
  output logic [511:0]                regreq_axis_tdata_dmat_rs,
  output logic                        regreq_axis_tlast_dmat_rs,
  output logic [ 63:0]                regreq_axis_tuser_dmat_rs,

  output logic                        regreq_axis_tvalid_cifdn_rs,
  output logic [511:0]                regreq_axis_tdata_cifdn_rs,
  output logic                        regreq_axis_tlast_cifdn_rs,
  output logic [ 63:0]                regreq_axis_tuser_cifdn_rs,

  output logic                        regreq_axis_tvalid_cifup_rs,
  output logic [511:0]                regreq_axis_tdata_cifup_rs,
  output logic                        regreq_axis_tlast_cifup_rs,
  output logic [ 63:0]                regreq_axis_tuser_cifup_rs,

  input  logic [  2:0]                cfg_max_read_req,
  input  logic [  1:0]                cfg_max_payload,

  output logic [  2:0]                cfg_max_read_req_dmar_rs,
  output logic [  1:0]                cfg_max_payload_dmar_rs,

  output logic [  2:0]                cfg_max_read_req_dmat_rs,
  output logic [  1:0]                cfg_max_payload_dmat_rs,

  input  logic                        dbg_enable,         // PA ENB
  input  logic                        dbg_count_reset,    // PA CLR
  input  logic                        dma_trace_enable,   // TRACE ENB
  input  logic                        dma_trace_rst,      // TRACE CLR
  input  logic [ 31:0]                dbg_freerun_count,  // TRACE FREERUN COUNT

  output logic                        dbg_enable_dmar_rs,
  output logic                        dbg_count_reset_dmar_rs,
  output logic                        dma_trace_enable_dmar_rs,
  output logic                        dma_trace_rst_dmar_rs,
  output logic [ 31:0]                dbg_freerun_count_dmar_rs,

  output logic                        dbg_enable_dmat_rs,
  output logic                        dbg_count_reset_dmat_rs,
  output logic                        dma_trace_enable_dmat_rs,
  output logic                        dma_trace_rst_dmat_rs,
  output logic [ 31:0]                dbg_freerun_count_dmat_rs,

  output logic                        dbg_enable_cifdn_rs,
  output logic                        dbg_count_reset_cifdn_rs,
  output logic                        dma_trace_enable_cifdn_rs,
  output logic                        dma_trace_rst_cifdn_rs,
  output logic [ 31:0]                dbg_freerun_count_cifdn_rs,

  output logic                        dbg_enable_cifup_rs,
  output logic                        dbg_count_reset_cifup_rs,
  output logic                        dma_trace_enable_cifup_rs,
  output logic                        dma_trace_rst_cifup_rs,
  output logic [ 31:0]                dbg_freerun_count_cifup_rs,

// DMA_RX
  output logic                        rq_dmar_rd_axis_tvalid,
  output logic [511:0]                rq_dmar_rd_axis_tdata,
  output logic                        rq_dmar_rd_axis_tlast,
  input  logic                        rq_dmar_rd_axis_tready,

  input  logic                        rq_dmar_rd_axis_tvalid_rs,
  input  logic [511:0]                rq_dmar_rd_axis_tdata_rs,
  input  logic                        rq_dmar_rd_axis_tlast_rs,
  output logic                        rq_dmar_rd_axis_tready_rs,

// DMA_TX
  output logic                        rq_dmaw_dwr_axis_tvalid,
  output logic [511:0]                rq_dmaw_dwr_axis_tdata,
  output logic                        rq_dmaw_dwr_axis_tlast,
  input  logic                        rq_dmaw_dwr_axis_tready,
  input  logic                        rq_dmaw_dwr_axis_wr_ptr,
  input  logic                        rq_dmaw_dwr_axis_rd_ptr,

  input  logic                        rq_dmaw_dwr_axis_tvalid_rs,
  input  logic [511:0]                rq_dmaw_dwr_axis_tdata_rs,
  input  logic                        rq_dmaw_dwr_axis_tlast_rs,
  output logic                        rq_dmaw_dwr_axis_tready_rs,
  output logic                        rq_dmaw_dwr_axis_wr_ptr_rs,
  output logic                        rq_dmaw_dwr_axis_rd_ptr_rs,

  input  logic                        timer_pulse,

  output logic                        timer_pulse_rs,

// CIF_DN
  input  logic                        s_axis_direct_tvalid,
  input  logic [511:0]                s_axis_direct_tdata,
  input  logic [15:0]                 s_axis_direct_tuser,
  output logic                        s_axis_direct_tready,

  output logic                        s_axis_direct_tvalid_rs,
  output logic [511:0]                s_axis_direct_tdata_rs,
  output logic [15:0]                 s_axis_direct_tuser_rs,
  input  logic                        s_axis_direct_tready_rs,

  //input  logic [CHAIN_NUM-1:0]        s_axis_cd_transfer_cmd_valid,
  //input  logic [CHAIN_NUM-1:0][ 63:0] s_axis_cd_transfer_cmd_data,
  //output logic [CHAIN_NUM-1:0]        s_axis_cd_transfer_cmd_ready,
  //
  //output logic [CHAIN_NUM-1:0]        s_axis_cd_transfer_cmd_valid_rs,
  //output logic [CHAIN_NUM-1:0][ 63:0] s_axis_cd_transfer_cmd_data_rs,
  //input  logic [CHAIN_NUM-1:0]        s_axis_cd_transfer_cmd_ready_rs,
  //
  //output logic [CHAIN_NUM-1:0]        m_axis_cd_transfer_eve_valid,
  //output logic [CHAIN_NUM-1:0][127:0] m_axis_cd_transfer_eve_data,
  //input  logic [CHAIN_NUM-1:0]        m_axis_cd_transfer_eve_ready,
  //
  //input  logic [CHAIN_NUM-1:0]        m_axis_cd_transfer_eve_valid_rs,
  //input  logic [CHAIN_NUM-1:0][127:0] m_axis_cd_transfer_eve_data_rs,
  //output logic [CHAIN_NUM-1:0]        m_axis_cd_transfer_eve_ready_rs,

  output logic [CHAIN_NUM-1:0]        m_axi_cd_awvalid,
  output logic [CHAIN_NUM-1:0][ 63:0] m_axi_cd_awaddr,
  output logic [CHAIN_NUM-1:0][ 7:0]  m_axi_cd_awlen,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_awready,

  input  logic [CHAIN_NUM-1:0]        m_axi_cd_awvalid_rs,
  input  logic [CHAIN_NUM-1:0][ 63:0] m_axi_cd_awaddr_rs,
  input  logic [CHAIN_NUM-1:0][ 7:0]  m_axi_cd_awlen_rs,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_awready_rs,

  output logic [CHAIN_NUM-1:0]        m_axi_cd_wvalid,
  output logic [CHAIN_NUM-1:0][511:0] m_axi_cd_wdata,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_wlast,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_wready,

  input  logic [CHAIN_NUM-1:0]        m_axi_cd_wvalid_rs,
  input  logic [CHAIN_NUM-1:0][511:0] m_axi_cd_wdata_rs,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_wlast_rs,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_wready_rs,

  input  logic [CHAIN_NUM-1:0]        m_axi_cd_bvalid,
  input  logic [CHAIN_NUM-1:0][ 1:0]  m_axi_cd_bresp,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_bready,

  output logic [CHAIN_NUM-1:0]        m_axi_cd_bvalid_rs,
  output logic [CHAIN_NUM-1:0][ 1:0]  m_axi_cd_bresp_rs,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_bready_rs,

// CIF_UP
  //input  logic [CHAIN_NUM-1:0]        s_axis_cu_transfer_cmd_valid,
  //input  logic [CHAIN_NUM-1:0][ 63:0] s_axis_cu_transfer_cmd_data,
  //output logic [CHAIN_NUM-1:0]        s_axis_cu_transfer_cmd_ready,
  //
  //output logic [CHAIN_NUM-1:0]        s_axis_cu_transfer_cmd_valid_rs,
  //output logic [CHAIN_NUM-1:0][ 63:0] s_axis_cu_transfer_cmd_data_rs,
  //input  logic [CHAIN_NUM-1:0]        s_axis_cu_transfer_cmd_ready_rs,
  //
  //output logic [CHAIN_NUM-1:0]        m_axis_cu_transfer_eve_valid,
  //output logic [CHAIN_NUM-1:0][127:0] m_axis_cu_transfer_eve_data,
  //input  logic [CHAIN_NUM-1:0]        m_axis_cu_transfer_eve_ready,
  //
  //input  logic [CHAIN_NUM-1:0]        m_axis_cu_transfer_eve_valid_rs,
  //input  logic [CHAIN_NUM-1:0][127:0] m_axis_cu_transfer_eve_data_rs,
  //output logic [CHAIN_NUM-1:0]        m_axis_cu_transfer_eve_ready_rs,  
  
  output logic [CHAIN_NUM-1:0]        m_axi_cu_arvalid,
  output logic [CHAIN_NUM-1:0][ 63:0] m_axi_cu_araddr,
  output logic [CHAIN_NUM-1:0][ 7:0]  m_axi_cu_arlen,
  input  logic [CHAIN_NUM-1:0]        m_axi_cu_arready,

  input  logic [CHAIN_NUM-1:0]        m_axi_cu_arvalid_rs,
  input  logic [CHAIN_NUM-1:0][ 63:0] m_axi_cu_araddr_rs,
  input  logic [CHAIN_NUM-1:0][ 7:0]  m_axi_cu_arlen_rs,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_arready_rs,

  input  logic [CHAIN_NUM-1:0]        m_axi_cu_rvalid,
  input  logic [CHAIN_NUM-1:0][511:0] m_axi_cu_rdata,
  input  logic [CHAIN_NUM-1:0]        m_axi_cu_rlast,
  input  logic [CHAIN_NUM-1:0][ 1:0]  m_axi_cu_rresp,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_rready,

  output logic [CHAIN_NUM-1:0]        m_axi_cu_rvalid_rs,
  output logic [CHAIN_NUM-1:0][511:0] m_axi_cu_rdata_rs,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_rlast_rs,
  output logic [CHAIN_NUM-1:0][ 1:0]  m_axi_cu_rresp_rs,
  input  logic [CHAIN_NUM-1:0]        m_axi_cu_rready_rs,

//EVE CMD
  input  logic [CHAIN_NUM-1:0]        s_axis_transfer_cmd_valid,
  input  logic [CHAIN_NUM-1:0][ 63:0] s_axis_transfer_cmd_data,
  output logic [CHAIN_NUM-1:0]        s_axis_transfer_cmd_ready,
  
  output logic [CHAIN_NUM-1:0]        s_axis_transfer_cmd_valid_rs,
  output logic [CHAIN_NUM-1:0][ 63:0] s_axis_transfer_cmd_data_rs,
  input  logic [CHAIN_NUM-1:0]        s_axis_transfer_cmd_ready_rs,
  
  output logic [CHAIN_NUM-1:0]        m_axis_transfer_eve_valid,
  output logic [CHAIN_NUM-1:0][127:0] m_axis_transfer_eve_data,
  input  logic [CHAIN_NUM-1:0]        m_axis_transfer_eve_ready,
  
  input  logic [CHAIN_NUM-1:0]        m_axis_transfer_eve_valid_rs,
  input  logic [CHAIN_NUM-1:0][127:0] m_axis_transfer_eve_data_rs,
  output logic [CHAIN_NUM-1:0]        m_axis_transfer_eve_ready_rs,
  
// Bypass RX
  input  logic                        w_dma_rx_rq_dmar_crd_axis_tvalid,
  input  logic [511:0]                w_dma_rx_rq_dmar_crd_axis_tdata,
  input  logic                        w_dma_rx_rq_dmar_crd_axis_tlast,
  output logic                        w_dma_rx_rq_dmar_crd_axis_tready,
  input  logic                        w_dma_rx_rq_dmar_cwr_axis_tvalid,
  input  logic [511:0]                w_dma_rx_rq_dmar_cwr_axis_tdata,
  input  logic                        w_dma_rx_rq_dmar_cwr_axis_tlast,
  output logic                        w_dma_rx_rq_dmar_cwr_axis_tready,

  output logic                        w_dma_rx_rq_dmar_crd_axis_tvalid_rs,
  output logic [511:0]                w_dma_rx_rq_dmar_crd_axis_tdata_rs,
  output logic                        w_dma_rx_rq_dmar_crd_axis_tlast_rs,
  input  logic                        w_dma_rx_rq_dmar_crd_axis_tready_rs,
  output logic                        w_dma_rx_rq_dmar_cwr_axis_tvalid_rs,
  output logic [511:0]                w_dma_rx_rq_dmar_cwr_axis_tdata_rs,
  output logic                        w_dma_rx_rq_dmar_cwr_axis_tlast_rs,
  input  logic                        w_dma_rx_rq_dmar_cwr_axis_tready_rs,
  
  input  logic                        w_pci_trx_rc_axis_tvalid_dmat,
  input  logic [511:0]                w_pci_trx_rc_axis_tdata_dmat,
  input  logic                        w_pci_trx_rc_axis_tlast_dmat,
  input  logic [31:0]                 w_pci_trx_rc_axis_tuser_dmat,
  output logic                        w_pci_trx_rc_axis_tready_dmat,

  output logic                        w_pci_trx_rc_axis_tvalid_dmat_rs,
  output logic [511:0]                w_pci_trx_rc_axis_tdata_dmat_rs,
  output logic                        w_pci_trx_rc_axis_tlast_dmat_rs,
  output logic [31:0]                 w_pci_trx_rc_axis_tuser_dmat_rs,
  input  logic                        w_pci_trx_rc_axis_tready_dmat_rs,
  
  
// Bypass TX
  input  logic                        w_dma_tx_rq_dmaw_crd_axis_tvalid,
  input  logic [511:0]                w_dma_tx_rq_dmaw_crd_axis_tdata,
  input  logic                        w_dma_tx_rq_dmaw_crd_axis_tlast,
  output logic                        w_dma_tx_rq_dmaw_crd_axis_tready,
  input  logic                        w_dma_tx_rq_dmaw_cwr_axis_tvalid,
  input  logic [511:0]                w_dma_tx_rq_dmaw_cwr_axis_tdata,
  input  logic                        w_dma_tx_rq_dmaw_cwr_axis_tlast,
  output logic                        w_dma_tx_rq_dmaw_cwr_axis_tready,

  output logic                        w_dma_tx_rq_dmaw_crd_axis_tvalid_rs,
  output logic [511:0]                w_dma_tx_rq_dmaw_crd_axis_tdata_rs,
  output logic                        w_dma_tx_rq_dmaw_crd_axis_tlast_rs,
  input  logic                        w_dma_tx_rq_dmaw_crd_axis_tready_rs,
  output logic                        w_dma_tx_rq_dmaw_cwr_axis_tvalid_rs,
  output logic [511:0]                w_dma_tx_rq_dmaw_cwr_axis_tdata_rs,
  output logic                        w_dma_tx_rq_dmaw_cwr_axis_tlast_rs,
  input  logic                        w_dma_tx_rq_dmaw_cwr_axis_tready_rs,
  
  input  logic                        w_pci_trx_rc_axis_tvalid_dmar,
  input  logic [511:0]                w_pci_trx_rc_axis_tdata_dmar,
  input  logic                        w_pci_trx_rc_axis_tlast_dmar,
  input  logic [31:0]                 w_pci_trx_rc_axis_tuser_dmar,
  output logic                        w_pci_trx_rc_axis_tready_dmar,

  output logic                        w_pci_trx_rc_axis_tvalid_dmar_rs,
  output logic [511:0]                w_pci_trx_rc_axis_tdata_dmar_rs,
  output logic                        w_pci_trx_rc_axis_tlast_dmar_rs,
  output logic [31:0]                 w_pci_trx_rc_axis_tuser_dmar_rs,
  input  logic                        w_pci_trx_rc_axis_tready_dmar_rs
);

// PCI_TRX
  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      regreq_axis_tvalid_cifdn_rs  <= '0;
      regreq_axis_tdata_cifdn_rs   <= '0;
      regreq_axis_tlast_cifdn_rs   <= '0;
      regreq_axis_tuser_cifdn_rs   <= '0;
      regreq_axis_tvalid_cifup_rs  <= '0;
      regreq_axis_tdata_cifup_rs   <= '0;
      regreq_axis_tlast_cifup_rs   <= '0;
      regreq_axis_tuser_cifup_rs   <= '0;
      regreq_axis_tvalid_dmar_rs   <= '0;
      regreq_axis_tdata_dmar_rs    <= '0;
      regreq_axis_tlast_dmar_rs    <= '0;
      regreq_axis_tuser_dmar_rs    <= '0;
      regreq_axis_tvalid_dmat_rs   <= '0;
      regreq_axis_tdata_dmat_rs    <= '0;
      regreq_axis_tlast_dmat_rs    <= '0;
      regreq_axis_tuser_dmat_rs    <= '0;
      cfg_max_read_req_dmar_rs     <= '0;
      cfg_max_payload_dmar_rs      <= '0;
      cfg_max_read_req_dmat_rs     <= '0;
      cfg_max_payload_dmat_rs      <= '0;
      dbg_enable_dmar_rs           <= '0;
      dbg_count_reset_dmar_rs      <= '0;
      dma_trace_enable_dmar_rs     <= '0;
      dma_trace_rst_dmar_rs        <= '0;
      dbg_freerun_count_dmar_rs    <= '0;
      dbg_enable_dmat_rs           <= '0;
      dbg_count_reset_dmat_rs      <= '0;
      dma_trace_enable_dmat_rs     <= '0;
      dma_trace_rst_dmat_rs        <= '0;
      dbg_freerun_count_dmat_rs    <= '0;
      dbg_enable_cifdn_rs          <= '0;
      dbg_count_reset_cifdn_rs     <= '0;
      dma_trace_enable_cifdn_rs    <= '0;
      dma_trace_rst_cifdn_rs       <= '0;
      dbg_freerun_count_cifdn_rs   <= '0;
      dbg_enable_cifup_rs          <= '0;
      dbg_count_reset_cifup_rs     <= '0;
      dma_trace_enable_cifup_rs    <= '0;
      dma_trace_rst_cifup_rs       <= '0;
      dbg_freerun_count_cifup_rs   <= '0;
      timer_pulse_rs               <= '0;
    end else begin
      regreq_axis_tvalid_cifdn_rs  <= regreq_axis_tvalid_cifdn;
      if (regreq_axis_tvalid_cifdn == 1'b1) begin
        regreq_axis_tdata_cifdn_rs <= regreq_axis_tdata;
        regreq_axis_tlast_cifdn_rs <= regreq_axis_tlast;
        regreq_axis_tuser_cifdn_rs <= regreq_axis_tuser;
      end
      regreq_axis_tvalid_cifup_rs  <= regreq_axis_tvalid_cifup;
      if (regreq_axis_tvalid_cifup == 1'b1) begin
        regreq_axis_tdata_cifup_rs <= regreq_axis_tdata;
        regreq_axis_tlast_cifup_rs <= regreq_axis_tlast;
        regreq_axis_tuser_cifup_rs <= regreq_axis_tuser;
      end
      regreq_axis_tvalid_dmar_rs   <= regreq_axis_tvalid_dmar;
      if (regreq_axis_tvalid_dmar == 1'b1) begin
        regreq_axis_tdata_dmar_rs  <= regreq_axis_tdata;
        regreq_axis_tlast_dmar_rs  <= regreq_axis_tlast;
        regreq_axis_tuser_dmar_rs  <= regreq_axis_tuser;
      end
      regreq_axis_tvalid_dmat_rs   <= regreq_axis_tvalid_dmat;
      if (regreq_axis_tvalid_dmat == 1'b1) begin
        regreq_axis_tdata_dmat_rs  <= regreq_axis_tdata;
        regreq_axis_tlast_dmat_rs  <= regreq_axis_tlast;
        regreq_axis_tuser_dmat_rs  <= regreq_axis_tuser;
      end
      cfg_max_read_req_dmar_rs     <= cfg_max_read_req;
      cfg_max_payload_dmar_rs      <= cfg_max_payload;
      cfg_max_read_req_dmat_rs     <= cfg_max_read_req;
      cfg_max_payload_dmat_rs      <= cfg_max_payload;
      dbg_enable_dmar_rs           <= dbg_enable;
      dbg_count_reset_dmar_rs      <= dbg_count_reset;
      dma_trace_enable_dmar_rs     <= dma_trace_enable;
      dma_trace_rst_dmar_rs        <= dma_trace_rst;
      dbg_freerun_count_dmar_rs    <= dbg_freerun_count;
      dbg_enable_dmat_rs           <= dbg_enable;
      dbg_count_reset_dmat_rs      <= dbg_count_reset;
      dma_trace_enable_dmat_rs     <= dma_trace_enable;
      dma_trace_rst_dmat_rs        <= dma_trace_rst;
      dbg_freerun_count_dmat_rs    <= dbg_freerun_count;
      dbg_enable_cifdn_rs          <= dbg_enable;
      dbg_count_reset_cifdn_rs     <= dbg_count_reset;
      dma_trace_enable_cifdn_rs    <= dma_trace_enable;
      dma_trace_rst_cifdn_rs       <= dma_trace_rst;
      dbg_freerun_count_cifdn_rs   <= dbg_freerun_count;
      dbg_enable_cifup_rs          <= dbg_enable;
      dbg_count_reset_cifup_rs     <= dbg_count_reset;
      dma_trace_enable_cifup_rs    <= dma_trace_enable;
      dma_trace_rst_cifup_rs       <= dma_trace_rst;
      dbg_freerun_count_cifup_rs   <= dbg_freerun_count;
      timer_pulse_rs               <= timer_pulse;
    end
  end

// DMA_RX
  rs_type4 #(.DATA_WIDTH(513)) rs_rx_rd (
    .user_clk(user_clk),
    .reset_n(reset_n),
    .tready_in (rq_dmar_rd_axis_tready_rs),
    .tvalid_in (rq_dmar_rd_axis_tvalid_rs),
    .tdata_in  ({rq_dmar_rd_axis_tdata_rs,rq_dmar_rd_axis_tlast_rs}),
    .tready_out(rq_dmar_rd_axis_tready),
    .tvalid_out(rq_dmar_rd_axis_tvalid),
    .tdata_out ({rq_dmar_rd_axis_tdata,rq_dmar_rd_axis_tlast})
  );

// DMA_TX
  rs_type4 #(.DATA_WIDTH(513)) rs_tx_dwr (
    .user_clk(user_clk),
    .reset_n(reset_n),
    .tready_in (rq_dmaw_dwr_axis_tready_rs),
    .tvalid_in (rq_dmaw_dwr_axis_tvalid_rs),
    .tdata_in  ({rq_dmaw_dwr_axis_tdata_rs,rq_dmaw_dwr_axis_tlast_rs}),
    .tready_out(rq_dmaw_dwr_axis_tready),
    .tvalid_out(rq_dmaw_dwr_axis_tvalid),
    .tdata_out ({rq_dmaw_dwr_axis_tdata,rq_dmaw_dwr_axis_tlast})
  );

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      rq_dmaw_dwr_axis_wr_ptr_rs <= '0;
      rq_dmaw_dwr_axis_rd_ptr_rs <= '0;
    end else begin
      rq_dmaw_dwr_axis_wr_ptr_rs <= rq_dmaw_dwr_axis_wr_ptr;
      rq_dmaw_dwr_axis_rd_ptr_rs <= rq_dmaw_dwr_axis_rd_ptr;
    end
  end

// CIF_DN
  rs_type4 #(.DATA_WIDTH(528)) rs_cd_dir (
    .user_clk(user_clk),
    .reset_n(reset_n),
    .tready_in (s_axis_direct_tready),
    .tvalid_in (s_axis_direct_tvalid),
    .tdata_in  ({s_axis_direct_tdata,s_axis_direct_tuser}),
    .tready_out(s_axis_direct_tready_rs),
    .tvalid_out(s_axis_direct_tvalid_rs),
    .tdata_out ({s_axis_direct_tdata_rs,s_axis_direct_tuser_rs})
  );

  for (genvar i = 0; i < CHAIN_NUM; i++) begin : rs_cif

    //rs_type4 #(.DATA_WIDTH(64)) rs_cd_cmd (
    //  .user_clk(ext_clk),
    //  .reset_n(ext_reset_n),
    //  .tready_in (s_axis_cd_transfer_cmd_ready[i]),
    //  .tvalid_in (s_axis_cd_transfer_cmd_valid[i]),
    //  .tdata_in  (s_axis_cd_transfer_cmd_data[i]),
    //  .tready_out(s_axis_cd_transfer_cmd_ready_rs[i]),
    //  .tvalid_out(s_axis_cd_transfer_cmd_valid_rs[i]),
    //  .tdata_out (s_axis_cd_transfer_cmd_data_rs[i])
    //);
    //
    //rs_type4 #(.DATA_WIDTH(128)) rs_cd_eve (
    //  .user_clk(ext_clk),
    //  .reset_n(ext_reset_n),
    //  .tready_in (m_axis_cd_transfer_eve_ready_rs[i]),
    //  .tvalid_in (m_axis_cd_transfer_eve_valid_rs[i]),
    //  .tdata_in  (m_axis_cd_transfer_eve_data_rs[i]),
    //  .tready_out(m_axis_cd_transfer_eve_ready[i]),
    //  .tvalid_out(m_axis_cd_transfer_eve_valid[i]),
    //  .tdata_out (m_axis_cd_transfer_eve_data[i])
    //);

    rs_type4 #(.DATA_WIDTH(72)) rs_cd_ddr_wa (
      .user_clk(user_clk),
      .reset_n(reset_n),
      .tready_in (m_axi_cd_awready_rs[i]),
      .tvalid_in (m_axi_cd_awvalid_rs[i]),
      .tdata_in  ({m_axi_cd_awaddr_rs[i],m_axi_cd_awlen_rs[i]}),
      .tready_out(m_axi_cd_awready[i]),
      .tvalid_out(m_axi_cd_awvalid[i]),
      .tdata_out ({m_axi_cd_awaddr[i],m_axi_cd_awlen[i]})
    );

    rs_type4 #(.DATA_WIDTH(513)) rs_cd_ddr_wd (
      .user_clk(user_clk),
      .reset_n(reset_n),
      .tready_in (m_axi_cd_wready_rs[i]),
      .tvalid_in (m_axi_cd_wvalid_rs[i]),
      .tdata_in  ({m_axi_cd_wdata_rs[i],m_axi_cd_wlast_rs[i]}),
      .tready_out(m_axi_cd_wready[i]),
      .tvalid_out(m_axi_cd_wvalid[i]),
      .tdata_out ({m_axi_cd_wdata[i],m_axi_cd_wlast[i]})
    );

    rs_type4 #(.DATA_WIDTH(2)) rs_cd_ddr_wresp (
      .user_clk(user_clk),
      .reset_n(reset_n),
      .tready_in (m_axi_cd_bready[i]),
      .tvalid_in (m_axi_cd_bvalid[i]),
      .tdata_in  (m_axi_cd_bresp[i]),
      .tready_out(m_axi_cd_bready_rs[i]),
      .tvalid_out(m_axi_cd_bvalid_rs[i]),
      .tdata_out (m_axi_cd_bresp_rs[i])
    );

// CIF_UP
    //rs_type4 #(.DATA_WIDTH(64)) rs_cu_cmd (
    //  .user_clk(ext_clk),
    //  .reset_n(ext_reset_n),
    //  .tready_in (s_axis_cu_transfer_cmd_ready[i]),
    //  .tvalid_in (s_axis_cu_transfer_cmd_valid[i]),
    //  .tdata_in  (s_axis_cu_transfer_cmd_data[i]),
    //  .tready_out(s_axis_cu_transfer_cmd_ready_rs[i]),
    //  .tvalid_out(s_axis_cu_transfer_cmd_valid_rs[i]),
    //  .tdata_out (s_axis_cu_transfer_cmd_data_rs[i])
    //);
    //
    //rs_type4 #(.DATA_WIDTH(128)) rs_cu_eve (
    //  .user_clk(ext_clk),
    //  .reset_n(ext_reset_n),
    //  .tready_in (m_axis_cu_transfer_eve_ready_rs[i]),
    //  .tvalid_in (m_axis_cu_transfer_eve_valid_rs[i]),
    //  .tdata_in  (m_axis_cu_transfer_eve_data_rs[i]),
    //  .tready_out(m_axis_cu_transfer_eve_ready[i]),
    //  .tvalid_out(m_axis_cu_transfer_eve_valid[i]),
    //  .tdata_out (m_axis_cu_transfer_eve_data[i])
    //);

    rs_type4 #(.DATA_WIDTH(72)) rs_cu_ddr_ra (
      .user_clk(user_clk),
      .reset_n(reset_n),
      .tready_in (m_axi_cu_arready_rs[i]),
      .tvalid_in (m_axi_cu_arvalid_rs[i]),
      .tdata_in  ({m_axi_cu_araddr_rs[i],m_axi_cu_arlen_rs[i]}),
      .tready_out(m_axi_cu_arready[i]),
      .tvalid_out(m_axi_cu_arvalid[i]),
      .tdata_out ({m_axi_cu_araddr[i],m_axi_cu_arlen[i]})
    );

    rs_type4 #(.DATA_WIDTH(515)) rs_cu_ddr_rd (
      .user_clk(user_clk),
      .reset_n(reset_n),
      .tready_in (m_axi_cu_rready[i]),
      .tvalid_in (m_axi_cu_rvalid[i]),
      .tdata_in  ({m_axi_cu_rdata[i],m_axi_cu_rlast[i],m_axi_cu_rresp[i]}),
      .tready_out(m_axi_cu_rready_rs[i]),
      .tvalid_out(m_axi_cu_rvalid_rs[i]),
      .tdata_out ({m_axi_cu_rdata_rs[i],m_axi_cu_rlast_rs[i],m_axi_cu_rresp_rs[i]})
    );
    
    //EVE CMD
    rs_type4 #(.DATA_WIDTH(64)) rs_cmd (
      .user_clk(user_clk),
      .reset_n(reset_n),
      .tready_in (s_axis_transfer_cmd_ready[i]),
      .tvalid_in (s_axis_transfer_cmd_valid[i]),
      .tdata_in  (s_axis_transfer_cmd_data[i]),
      .tready_out(s_axis_transfer_cmd_ready_rs[i]),
      .tvalid_out(s_axis_transfer_cmd_valid_rs[i]),
      .tdata_out (s_axis_transfer_cmd_data_rs[i])
    );

    rs_type4 #(.DATA_WIDTH(128)) rs_eve (
      .user_clk(user_clk),
      .reset_n(reset_n),
      .tready_in (m_axis_transfer_eve_ready_rs[i]),
      .tvalid_in (m_axis_transfer_eve_valid_rs[i]),
      .tdata_in  (m_axis_transfer_eve_data_rs[i]),
      .tready_out(m_axis_transfer_eve_ready[i]),
      .tvalid_out(m_axis_transfer_eve_valid[i]),
      .tdata_out (m_axis_transfer_eve_data[i])
    );

  end

// Bypass RX
  rs_type4 #(.DATA_WIDTH(513)) rs_rx_se_crd (
    .user_clk(user_clk),
    .reset_n(reset_n),
    .tready_in (w_dma_rx_rq_dmar_crd_axis_tready),
    .tvalid_in (w_dma_rx_rq_dmar_crd_axis_tvalid),
    .tdata_in  ({w_dma_rx_rq_dmar_crd_axis_tdata,w_dma_rx_rq_dmar_crd_axis_tlast}),
    .tready_out(w_dma_rx_rq_dmar_crd_axis_tready_rs),
    .tvalid_out(w_dma_rx_rq_dmar_crd_axis_tvalid_rs),
    .tdata_out ({w_dma_rx_rq_dmar_crd_axis_tdata_rs,w_dma_rx_rq_dmar_crd_axis_tlast_rs})
  );

  rs_type4 #(.DATA_WIDTH(513)) rs_rx_se_cwr (
    .user_clk(user_clk),
    .reset_n(reset_n),
    .tready_in (w_dma_rx_rq_dmar_cwr_axis_tready),
    .tvalid_in (w_dma_rx_rq_dmar_cwr_axis_tvalid),
    .tdata_in  ({w_dma_rx_rq_dmar_cwr_axis_tdata,w_dma_rx_rq_dmar_cwr_axis_tlast}),
    .tready_out(w_dma_rx_rq_dmar_cwr_axis_tready_rs),
    .tvalid_out(w_dma_rx_rq_dmar_cwr_axis_tvalid_rs),
    .tdata_out ({w_dma_rx_rq_dmar_cwr_axis_tdata_rs,w_dma_rx_rq_dmar_cwr_axis_tlast_rs})
  );

  rs_type4 #(.DATA_WIDTH(545)) rs_rx_se_rc (
    .user_clk(user_clk),
    .reset_n(reset_n),
    .tready_in (w_pci_trx_rc_axis_tready_dmat),
    .tvalid_in (w_pci_trx_rc_axis_tvalid_dmat),
    .tdata_in  ({w_pci_trx_rc_axis_tdata_dmat,w_pci_trx_rc_axis_tlast_dmat,w_pci_trx_rc_axis_tuser_dmat}),
    .tready_out(w_pci_trx_rc_axis_tready_dmat_rs),
    .tvalid_out(w_pci_trx_rc_axis_tvalid_dmat_rs),
    .tdata_out ({w_pci_trx_rc_axis_tdata_dmat_rs,w_pci_trx_rc_axis_tlast_dmat_rs,w_pci_trx_rc_axis_tuser_dmat_rs})
  );

// Bypass TX
  rs_type4 #(.DATA_WIDTH(513)) rs_tx_se_crd (
    .user_clk(user_clk),
    .reset_n(reset_n),
    .tready_in (w_dma_tx_rq_dmaw_crd_axis_tready),
    .tvalid_in (w_dma_tx_rq_dmaw_crd_axis_tvalid),
    .tdata_in  ({w_dma_tx_rq_dmaw_crd_axis_tdata,w_dma_tx_rq_dmaw_crd_axis_tlast}),
    .tready_out(w_dma_tx_rq_dmaw_crd_axis_tready_rs),
    .tvalid_out(w_dma_tx_rq_dmaw_crd_axis_tvalid_rs),
    .tdata_out ({w_dma_tx_rq_dmaw_crd_axis_tdata_rs,w_dma_tx_rq_dmaw_crd_axis_tlast_rs})
  );

  rs_type4 #(.DATA_WIDTH(513)) rs_tx_se_cwr (
    .user_clk(user_clk),
    .reset_n(reset_n),
    .tready_in (w_dma_tx_rq_dmaw_cwr_axis_tready),
    .tvalid_in (w_dma_tx_rq_dmaw_cwr_axis_tvalid),
    .tdata_in  ({w_dma_tx_rq_dmaw_cwr_axis_tdata,w_dma_tx_rq_dmaw_cwr_axis_tlast}),
    .tready_out(w_dma_tx_rq_dmaw_cwr_axis_tready_rs),
    .tvalid_out(w_dma_tx_rq_dmaw_cwr_axis_tvalid_rs),
    .tdata_out ({w_dma_tx_rq_dmaw_cwr_axis_tdata_rs,w_dma_tx_rq_dmaw_cwr_axis_tlast_rs})
  );

  rs_type4 #(.DATA_WIDTH(545)) rs_tx_se_rc (
    .user_clk(user_clk),
    .reset_n(reset_n),
    .tready_in (w_pci_trx_rc_axis_tready_dmar),
    .tvalid_in (w_pci_trx_rc_axis_tvalid_dmar),
    .tdata_in  ({w_pci_trx_rc_axis_tdata_dmar,w_pci_trx_rc_axis_tlast_dmar,w_pci_trx_rc_axis_tuser_dmar}),
    .tready_out(w_pci_trx_rc_axis_tready_dmar_rs),
    .tvalid_out(w_pci_trx_rc_axis_tvalid_dmar_rs),
    .tdata_out ({w_pci_trx_rc_axis_tdata_dmar_rs,w_pci_trx_rc_axis_tlast_dmar_rs,w_pci_trx_rc_axis_tuser_dmar_rs})
  );

endmodule
