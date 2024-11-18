/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module cif_dn #(
  parameter CHAIN_NUM    = 4,
  parameter CH_NUM       = 32,
  parameter CH_PAR_CHAIN = CH_NUM / CHAIN_NUM
)(
  input  logic         reset_n,      // LLDMA internal reset
  input  logic         ext_reset_n,  // Chain control unit reset
  input  logic         user_clk,     // LLDMA internal clock
  input  logic         ext_clk,      // Chain control clock

  ///// DMA_RX for mode0,1
  input  logic         d2c_axis_tvalid,
  input  logic [511:0] d2c_axis_tdata,
  input  logic [15:0]  d2c_axis_tuser,
  output logic         d2c_axis_tready,

  ///// axis2axi_bridge for mode2
  input  logic         s_axis_direct_tvalid,
  input  logic [511:0] s_axis_direct_tdata,
  input  logic [15:0]  s_axis_direct_tuser,
  output logic         s_axis_direct_tready,

  output logic [CHAIN_NUM-1:0]        m_axi_cd_awvalid,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_awready,
  output logic [CHAIN_NUM-1:0][63:0]  m_axi_cd_awaddr,
  output logic [CHAIN_NUM-1:0][7:0]   m_axi_cd_awlen,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cd_awsize,
  output logic [CHAIN_NUM-1:0][1:0]   m_axi_cd_awburst,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_awlock,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cd_awcache,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cd_awprot,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cd_awqos,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cd_awregion,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_wvalid,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_wready,
  output logic [CHAIN_NUM-1:0][511:0] m_axi_cd_wdata,
  output logic [CHAIN_NUM-1:0][63:0]  m_axi_cd_wstrb,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_wlast,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_arvalid,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_arready,
  output logic [CHAIN_NUM-1:0][63:0]  m_axi_cd_araddr,
  output logic [CHAIN_NUM-1:0][7:0]   m_axi_cd_arlen,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cd_arsize,
  output logic [CHAIN_NUM-1:0][1:0]   m_axi_cd_arburst,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_arlock,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cd_arcache,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cd_arprot,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cd_arqos,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cd_arregion,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_rvalid,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_rready,
  input  logic [CHAIN_NUM-1:0][511:0] m_axi_cd_rdata,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_rlast,
  input  logic [CHAIN_NUM-1:0][1:0]   m_axi_cd_rresp,
  input  logic [CHAIN_NUM-1:0]        m_axi_cd_bvalid,
  output logic [CHAIN_NUM-1:0]        m_axi_cd_bready,
  input  logic [CHAIN_NUM-1:0][1:0]   m_axi_cd_bresp,

  input  logic [CHAIN_NUM-1:0]        s_axis_cd_transfer_cmd_valid,
  input  logic [CHAIN_NUM-1:0][63:0]  s_axis_cd_transfer_cmd_data,
  output logic [CHAIN_NUM-1:0]        s_axis_cd_transfer_cmd_ready,
  output logic [CHAIN_NUM-1:0]        m_axis_cd_transfer_eve_valid,
  output logic [CHAIN_NUM-1:0][127:0] m_axis_cd_transfer_eve_data,
  input  logic [CHAIN_NUM-1:0]        m_axis_cd_transfer_eve_ready,

  input  logic [CH_NUM-1:0]    d2c_rxch_oe,
  input  logic [CH_NUM-1:0]    d2c_rxch_clr,
  output logic [CH_NUM-1:0]    d2c_cifd_busy,
  output logic [CH_NUM-1:0]    d2c_dmar_rd_enb,

// cif_dn_chx_gd
  input  logic [1:0]           d2c_pkt_mode[CH_NUM-1:0],
  input  logic [CH_NUM-1:0]    d2c_que_wt_ack_mode2,
  output logic [CH_NUM-1:0]    d2c_que_wt_req_mode2,
  output logic [31:0]          d2c_que_wt_req_ack_rp_mode2[CH_NUM-1:0],
  output logic [31:0]          d2c_ack_rp_mode2[CH_NUM-1:0],

  input  logic                 regreq_axis_tvalid_cifdn,
  input  logic [511:0]         regreq_axis_tdata,
  input  logic                 regreq_axis_tlast,
  input  logic [63:0]          regreq_axis_tuser,
  output logic                 regrep_axis_tvalid_cifdn,
  output logic [31:0]          regrep_axis_tdata_cifdn,
  input  logic                 dbg_enable,
  input  logic                 dbg_count_reset,
  input  logic                 dma_trace_enable,
  input  logic                 dma_trace_rst,
  input  logic [31:0]          dbg_freerun_count,

// error
  output logic                 error_detect_cif_dn
);

//// signal ////
localparam CH_NUM_W       = $clog2(CH_NUM);
localparam CHAIN_NUM_W    = $clog2(CHAIN_NUM);
localparam CH_PAR_CHAIN_W = $clog2(CH_PAR_CHAIN);

logic [CH_NUM-1:0]      cif_dn_data_in_busy;
logic [CH_NUM-1:0]      cif_dn_fifo_busy_pre;
logic [CH_NUM-1:0]      cif_dn_fifo_busy;
logic [CH_NUM-1:0]      cif_dn_chainx_busy;

logic                   fifo_in_axis_tvalid;
logic [511:0]           fifo_in_axis_tdata;
logic [15:0]            fifo_in_axis_tuser;
logic                   cif_dn_in_axis_tready;
logic [511:0]           fifo_tdata_ff[7:0];
logic [15:0]            fifo_tuser_ff[7:0];
logic [CHAIN_NUM-1:0]   a0_fifo_out_tvalid_ff;
logic [511:0]           a0_fifo_out_tdata_ff[CHAIN_NUM-1:0];
logic [15:0]            a0_fifo_out_tuser_ff[CHAIN_NUM-1:0];
logic [2:0]             fifo_wp_ff;
logic [2:0]             fifo_rp_ff;
logic [3:0]             fifo_cnt_ff;
logic [CHAIN_NUM-1:0]   fifo_full_hld;
logic [CHAIN_NUM-1:0]   fifo_ovfl;
logic [CHAIN_NUM_W-1:0] fifo_out_chain;
logic [CHAIN_NUM-1:0]   a0_fifo_out_axis_tvalid;
logic [511:0]           a0_fifo_out_axis_tdata[CHAIN_NUM-1:0];
logic [15:0]            a0_fifo_out_axis_tuser[CHAIN_NUM-1:0];
logic [CHAIN_NUM-1:0]   a0_fifo_out_axis_tready;
logic [CH_NUM-1:0]      rxch_clr_t1_ff;

logic [31:0]            cif_dn_rx_base_dn[CHAIN_NUM-1:0];
logic [31:0]            cif_dn_rx_base_up[CHAIN_NUM-1:0];
logic [2:0]             cif_dn_rx_ddr_size;
logic                   cif_dn_error;
logic [31:0]            cif_dn_error_detail[CHAIN_NUM-1:0];
logic [31:0]            cif_dn_error_msk;
logic                   cif_dn_eg2_set;
logic                   cif_dn_eg2_inj;
logic [31:0]            cif_dn_mode;
logic                   transfer_cmd_err_detect_all;
logic [CHAIN_NUM-1:0]   transfer_cmd_err_detect;
logic [31:0]            i_ad_0700[CHAIN_NUM-1:0];
logic [31:0]            i_ad_0704[CHAIN_NUM-1:0];
logic [31:0]            i_ad_0708[CHAIN_NUM-1:0];
logic [31:0]            i_ad_070c[CHAIN_NUM-1:0];
logic [31:0]            i_ad_0710[CHAIN_NUM-1:0];
logic [31:0]            i_ad_0714[CHAIN_NUM-1:0];
logic [31:0]            i_ad_07e4[CHAIN_NUM-1:0];
logic [31:0]            i_ad_07e4_merge[CHAIN_NUM-1:0];
logic [31:0]            i_ad_07f8[CHAIN_NUM-1:0];
logic [31:0]            i_ad_1640[CHAIN_NUM-1:0];
logic [31:0]            i_ad_1640_merge[CHAIN_NUM-1:0];
logic [31:0]            i_ad_1644[CHAIN_NUM-1:0];
logic [31:0]            i_ad_1648[CHAIN_NUM-1:0];
logic [31:0]            i_ad_164c[CHAIN_NUM-1:0];
logic [31:0]            i_ad_1654[CH_NUM-1:0];
logic [31:0]            i_ad_1658[CH_NUM-1:0];
logic [31:0]            i_ad_165c[CH_NUM-1:0];
logic [31:0]            i_ad_1660[CH_NUM-1:0];
logic [31:0]            i_ad_1664[CH_NUM-1:0];
logic [31:0]            i_ad_1668[CH_NUM-1:0];
logic [31:0]            i_ad_166c[CHAIN_NUM-1:0];
logic [31:0]            i_ad_1670[CHAIN_NUM-1:0];
logic [31:0]            i_ad_1674[CHAIN_NUM-1:0];
logic [31:0]            i_ad_1678[CHAIN_NUM-1:0];
logic [4:0]             cifd_infl_num_ff[CH_NUM-1:0];
logic [CH_NUM-1:0]      pa00_inc_enb;
logic [CH_NUM-1:0]      pa01_inc_enb;
logic [CH_NUM-1:0]      pa02_inc_enb;
logic [CH_NUM-1:0]      pa03_inc_enb;
logic [CH_NUM-1:0]      pa04_inc_enb;
logic [CH_NUM-1:0]      pa05_inc_enb;
logic [CH_NUM-1:0]      pa06_inc_enb;
logic [CH_NUM-1:0]      pa07_inc_enb;
logic [CH_NUM-1:0]      pa08_inc_enb;
logic [CH_NUM-1:0]      pa09_inc_enb;
logic [15:0]            pa10_add_val[CHAIN_NUM-1:0];
logic [15:0]            pa11_add_val[CHAIN_NUM-1:0];
logic [15:0]            pa12_add_val[CHAIN_NUM-1:0];
logic [15:0]            pa13_add_val[CHAIN_NUM-1:0];
logic [3:0]             trace_we[CHAIN_NUM-1:0];
logic [3:0][31:0]       trace_wd[CHAIN_NUM-1:0];
logic [3:0]             trace_we_mode;
logic [3:0]             trace_wd_mode;
logic [31:0]            trace_free_run_cnt;

//// logic ////

////////////////////////////////////////////////
// clear(busy)
////////////////////////////////////////////////
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    for(int i=0; i<CH_NUM; i++) begin
      d2c_cifd_busy[i] <= '0;
    end
  end else begin
    for(int i=0; i<CH_NUM; i++) begin
      d2c_cifd_busy[i] <= (cif_dn_data_in_busy[i] | cif_dn_fifo_busy[i] | cif_dn_chainx_busy[i]);
    end
  end   
end   

////////////////////////////////////////////////
// Input data selection
////////////////////////////////////////////////
  cif_dn_data_in #(.CH_NUM(CH_NUM))
    cif_dn_data_in (
    .user_clk(user_clk),
    .reset_n(reset_n),
    ///// DMA_RX for mode0,1
    .d2c_axis_tvalid(d2c_axis_tvalid),
    .d2c_axis_tdata(d2c_axis_tdata),
    .d2c_axis_tuser(d2c_axis_tuser),
    .d2c_axis_tready(d2c_axis_tready),
    ///// axis2axi_bridge for mode2
    .s_axis_direct_tvalid(s_axis_direct_tvalid),
    .s_axis_direct_tdata(s_axis_direct_tdata),
    .s_axis_direct_tuser(s_axis_direct_tuser),
    .s_axis_direct_tready(s_axis_direct_tready),
    ///// CIF_DN data FIFO
    .fifo_in_axis_tvalid(fifo_in_axis_tvalid),
    .fifo_in_axis_tdata(fifo_in_axis_tdata),
    .fifo_in_axis_tuser(fifo_in_axis_tuser),
    .cif_dn_in_axis_tready(cif_dn_in_axis_tready),
    ///// clear
    .cif_dn_data_in_busy(cif_dn_data_in_busy)
  );

////////////////////////////////////////////////
// FIFO for input data splitting
////////////////////////////////////////////////
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    for(int i=0; i<8; i++) begin
      fifo_tdata_ff[i]  <= '0;
      fifo_tuser_ff[i]  <= '0;
    end

    for(int i=0; i<CHAIN_NUM; i++) begin
      a0_fifo_out_tvalid_ff[i] <= '0;
      a0_fifo_out_tdata_ff[i]  <= '0;
      a0_fifo_out_tuser_ff[i]  <= '0;
      fifo_full_hld[i]         <= '0;
    end

    for (int i=0 ; i<CH_NUM; i++) begin
      cif_dn_fifo_busy[i] <= '0;
    end

    fifo_wp_ff  <= '0;
    fifo_rp_ff  <= '0;
    fifo_cnt_ff <= '0;

  end else begin
    for(int i=0; i<CHAIN_NUM; i++) begin
      if(a0_fifo_out_axis_tready[i]) begin
        if(  (fifo_cnt_ff != 0)
           // tuser[7+CH_NUM_W:8+CH_PAR_CHAIN_W] = chain No.
           & (fifo_out_chain==i)) begin
          a0_fifo_out_tvalid_ff[i] <= 1'b1;
          a0_fifo_out_tdata_ff[i]  <= fifo_tdata_ff[fifo_rp_ff];
          a0_fifo_out_tuser_ff[i]  <= fifo_tuser_ff[fifo_rp_ff];
        end else begin
          a0_fifo_out_tvalid_ff[i] <= 1'b0;
        end
      end
      if((fifo_cnt_ff == 4'h7) & fifo_in_axis_tvalid & (fifo_in_axis_tuser[7+CH_NUM_W:8+CH_PAR_CHAIN_W] == i) & ~a0_fifo_out_axis_tready[fifo_out_chain]) begin
        fifo_full_hld[i] <= 1'b1;
      end
    end

    for (int i=0 ; i<CH_NUM; i++) begin
      cif_dn_fifo_busy[i] <= cif_dn_fifo_busy_pre[i];
    end

    if(fifo_in_axis_tvalid) begin
      fifo_tdata_ff[fifo_wp_ff] <= fifo_in_axis_tdata;
      fifo_tuser_ff[fifo_wp_ff] <= fifo_in_axis_tuser;
      fifo_wp_ff <= fifo_wp_ff + 3'h1;
    end

    if((fifo_cnt_ff!=0) & a0_fifo_out_axis_tready[fifo_out_chain]) begin
      fifo_rp_ff <= fifo_rp_ff + 3'h1;
    end

    fifo_cnt_ff <= (  fifo_cnt_ff
                  +   fifo_in_axis_tvalid
                  - ((fifo_cnt_ff!=0) & a0_fifo_out_axis_tready[fifo_out_chain]));
  end
end

always_comb begin
  for (int i=0 ; i<CH_NUM; i++) begin
    cif_dn_fifo_busy_pre[i] = 1'b0;
    if(fifo_cnt_ff > 4'h0) begin
      for (int j=0 ; j<fifo_cnt_ff; j++) begin
        cif_dn_fifo_busy_pre[i] = cif_dn_fifo_busy_pre[i] | (i == fifo_tuser_ff[(fifo_rp_ff+j)%8][CH_NUM_W+7:8] ?1:0);
      end
    end
  end
  for (int i=0 ; i<CHAIN_NUM; i++) begin
    if((fifo_cnt_ff == 4'h8) & fifo_in_axis_tvalid & (fifo_in_axis_tuser[7+CH_NUM_W:8+CH_PAR_CHAIN_W] == i)) begin
      fifo_ovfl[i] = 1'b1;
    end else begin
      fifo_ovfl[i] = 1'b0;
    end
    i_ad_07e4_merge[i] = i_ad_07e4[i] | (fifo_ovfl[i] << 12);
    i_ad_1640_merge[i] = i_ad_1640[i] | (fifo_full_hld[i] << 31);
  end
end

assign fifo_out_chain          = fifo_tuser_ff[fifo_rp_ff][7+CH_NUM_W:8+CH_PAR_CHAIN_W];
assign cif_dn_in_axis_tready   = (fifo_cnt_ff <= 1);
assign a0_fifo_out_axis_tvalid = a0_fifo_out_tvalid_ff;
assign a0_fifo_out_axis_tdata  = a0_fifo_out_tdata_ff;
assign a0_fifo_out_axis_tuser  = a0_fifo_out_tuser_ff;

////////////////////////////////////////////////
// cif_dn_chainx : per-chain logic
////////////////////////////////////////////////
generate
for(genvar i=0; i<CHAIN_NUM; i++) begin: cif_dn_chainx
  cif_dn_chainx #(
    .CHAIN_ID       (i),
    .CH_NUM         (CH_PAR_CHAIN),  // CH_NUM/CHAIN_NUM
    .BUF_WORD       (32*16)
  ) cif_dn_chainx (
    .reset_n                       (reset_n),
    .ext_reset_n                   (ext_reset_n),
    .user_clk                      (user_clk),
    .ext_clk                       (ext_clk),
                                                                
    .a0_fifo_out_axis_tvalid       (a0_fifo_out_axis_tvalid[i]),
    .a0_fifo_out_axis_tdata        (a0_fifo_out_axis_tdata[i]),
    .a0_fifo_out_axis_tuser        (a0_fifo_out_axis_tuser[i]),
    .a0_fifo_out_axis_tready       (a0_fifo_out_axis_tready[i]),
                                                                
    .m_axi_cd_awvalid              (m_axi_cd_awvalid[i]),
    .m_axi_cd_awready              (m_axi_cd_awready[i]),
    .m_axi_cd_awaddr               (m_axi_cd_awaddr[i]),
    .m_axi_cd_awlen                (m_axi_cd_awlen[i]),
    .m_axi_cd_awsize               (m_axi_cd_awsize[i]),
    .m_axi_cd_awburst              (m_axi_cd_awburst[i]),
    .m_axi_cd_awlock               (m_axi_cd_awlock[i]),
    .m_axi_cd_awcache              (m_axi_cd_awcache[i]),
    .m_axi_cd_awprot               (m_axi_cd_awprot[i]),
    .m_axi_cd_awqos                (m_axi_cd_awqos[i]),
    .m_axi_cd_awregion             (m_axi_cd_awregion[i]),
    .m_axi_cd_wvalid               (m_axi_cd_wvalid[i]),
    .m_axi_cd_wready               (m_axi_cd_wready[i]),
    .m_axi_cd_wdata                (m_axi_cd_wdata[i]),
    .m_axi_cd_wstrb                (m_axi_cd_wstrb[i]),
    .m_axi_cd_wlast                (m_axi_cd_wlast[i]),
    .m_axi_cd_arvalid              (m_axi_cd_arvalid[i]),
    .m_axi_cd_arready              (m_axi_cd_arready[i]),
    .m_axi_cd_araddr               (m_axi_cd_araddr[i]),
    .m_axi_cd_arlen                (m_axi_cd_arlen[i]),
    .m_axi_cd_arsize               (m_axi_cd_arsize[i]),
    .m_axi_cd_arburst              (m_axi_cd_arburst[i]),
    .m_axi_cd_arlock               (m_axi_cd_arlock[i]),
    .m_axi_cd_arcache              (m_axi_cd_arcache[i]),
    .m_axi_cd_arprot               (m_axi_cd_arprot[i]),
    .m_axi_cd_arqos                (m_axi_cd_arqos[i]),
    .m_axi_cd_arregion             (m_axi_cd_arregion[i]),
    .m_axi_cd_rvalid               (m_axi_cd_rvalid[i]),
    .m_axi_cd_rready               (m_axi_cd_rready[i]),
    .m_axi_cd_rdata                (m_axi_cd_rdata[i]),
    .m_axi_cd_rlast                (m_axi_cd_rlast[i]),
    .m_axi_cd_rresp                (m_axi_cd_rresp[i]),
    .m_axi_cd_bvalid               (m_axi_cd_bvalid[i]),
    .m_axi_cd_bready               (m_axi_cd_bready[i]),
    .m_axi_cd_bresp                (m_axi_cd_bresp[i]),
                                                                
    .s_axis_cd_transfer_cmd_valid  (s_axis_cd_transfer_cmd_valid[i]),
    .s_axis_cd_transfer_cmd_data   (s_axis_cd_transfer_cmd_data[i]),
    .s_axis_cd_transfer_cmd_ready  (s_axis_cd_transfer_cmd_ready[i]),
    .m_axis_cd_transfer_eve_valid  (m_axis_cd_transfer_eve_valid[i]),
    .m_axis_cd_transfer_eve_data   (m_axis_cd_transfer_eve_data[i]),
    .m_axis_cd_transfer_eve_ready  (m_axis_cd_transfer_eve_ready[i]),
                                                                
    .d2c_rxch_oe                   (d2c_rxch_oe[i*8+7:i*8]),
    .d2c_rxch_clr                  (d2c_rxch_clr[i*8+7:i*8]),
    .cif_dn_mode                   (cif_dn_mode),
    .cif_dn_chainx_busy            (cif_dn_chainx_busy[i*8+7:i*8]),
    .d2c_dmar_rd_enb               (d2c_dmar_rd_enb[i*8+7:i*8]),
    .rxch_clr_t1_ff                (rxch_clr_t1_ff[i*8+7:i*8]),

// cif_dn_chx_gd
    // input
    .d2c_pkt_mode                  (d2c_pkt_mode[i*8+7:i*8]),
    .d2c_que_wt_ack_mode2          (d2c_que_wt_ack_mode2[i*8+7:i*8]), 
    // output
    .d2c_que_wt_req_mode2          (d2c_que_wt_req_mode2[i*8+7:i*8]),
    .d2c_que_wt_req_ack_rp_mode2   (d2c_que_wt_req_ack_rp_mode2[i*8+7:i*8]),
    .d2c_ack_rp_mode2              (d2c_ack_rp_mode2[i*8+7:i*8]),

    .cif_dn_rx_base_dn             (cif_dn_rx_base_dn[i]),
    .cif_dn_rx_base_up             (cif_dn_rx_base_up[i]),
    .cif_dn_rx_ddr_size            (cif_dn_rx_ddr_size),
    .cif_dn_eg2_set                (cif_dn_eg2_set),
    .transfer_cmd_err_detect_all   (transfer_cmd_err_detect_all),
    .transfer_cmd_err_detect       (transfer_cmd_err_detect[i]),
    .i_ad_0700_ff                  (i_ad_0700[i]),
    .i_ad_0704_ff                  (i_ad_0704[i]),
    .i_ad_0708_ff                  (i_ad_0708[i]),
    .i_ad_070c_ff                  (i_ad_070c[i]),
    .i_ad_0710_ff                  (i_ad_0710[i]),
    .i_ad_0714_ff                  (i_ad_0714[i]),
    .i_ad_07e4_ff                  (i_ad_07e4[i]),
    .i_ad_07f8_ff                  (i_ad_07f8[i]),
    .i_ad_1640_ff                  (i_ad_1640[i]),
    .i_ad_1644_ff                  (i_ad_1644[i]),
    .i_ad_1648_ff                  (i_ad_1648[i]),
    .i_ad_164c_ff                  (i_ad_164c[i]),
    .i_ad_1654_ff                  (i_ad_1654[i*8+7:i*8]),
    .i_ad_1658_ff                  (i_ad_1658[i*8+7:i*8]),
    .i_ad_165c_ff                  (i_ad_165c[i*8+7:i*8]),
    .i_ad_1660_ff                  (i_ad_1660[i*8+7:i*8]),
    .i_ad_1664_ff                  (i_ad_1664[i*8+7:i*8]),
    .i_ad_1668_ff                  (i_ad_1668[i*8+7:i*8]),
    .i_ad_166c_ff                  (i_ad_166c[i]),
    .i_ad_1670_ff                  (i_ad_1670[i]),
    .i_ad_1674_ff                  (i_ad_1674[i]),
    .i_ad_1678_ff                  (i_ad_1678[i]),
    .pa00_inc_enb_ff               (pa00_inc_enb[i*8+7:i*8]),
    .pa01_inc_enb_ff               (pa01_inc_enb[i*8+7:i*8]),
    .pa02_inc_enb_ff               (pa02_inc_enb[i*8+7:i*8]),
    .pa03_inc_enb_ff               (pa03_inc_enb[i*8+7:i*8]),
    .pa04_inc_enb_ff               (pa04_inc_enb[i*8+7:i*8]),
    .pa05_inc_enb_ff               (pa05_inc_enb[i*8+7:i*8]),
    .pa10_add_val_ff               (pa10_add_val[i]),
    .pa11_add_val_ff               (pa11_add_val[i]),
    .pa12_add_val_ff               (pa12_add_val[i]),
    .pa13_add_val_ff               (pa13_add_val[i]),
    .trace_we_ff                   (trace_we[i]),
    .trace_wd_ff                   (trace_wd[i]),
    .trace_we_mode                 (trace_we_mode),
    .trace_wd_mode                 (trace_wd_mode),
    .trace_free_run_cnt            (trace_free_run_cnt)
  );
end
endgenerate

assign transfer_cmd_err_detect_all = |transfer_cmd_err_detect;

////////////////////////////////////////////////
// PA
////////////////////////////////////////////////

always_comb begin
  for(int i=0; i<CH_NUM; i++) begin
    // DMA_RX->CIFDN data count in 64B units
    pa06_inc_enb[i] = d2c_axis_tvalid & d2c_axis_tready & (d2c_axis_tuser[CH_NUM_W+7:8]==i);

    // AXI-S to AXI Bridge->CIFDN data count in 64B units
    pa07_inc_enb[i] = s_axis_direct_tvalid & s_axis_direct_tready & (s_axis_direct_tuser[CH_NUM_W+7:8]==i);

    // DMA_RX->CIFDN Number of packets (counted at the beginning of the packet)
    pa08_inc_enb[i] = d2c_axis_tvalid & d2c_axis_tready & (d2c_axis_tuser[CH_NUM_W+7:8]==i) & d2c_axis_tuser[7];

    // AXI-S to AXI Bridge->CIFDN Number of packets (counted at the beginning of the packet)
    pa09_inc_enb[i] = s_axis_direct_tvalid & s_axis_direct_tready & (s_axis_direct_tuser[CH_NUM_W+7:8]==i) & s_axis_direct_tuser[7];
  end
end

////////////////////////////////////////////////
// cifd_reg : register
////////////////////////////////////////////////
cifd_reg #(
  .CH_NUM     (CH_NUM),
  .CHAIN_NUM  (CHAIN_NUM)
) cifd_reg (
  .reset_n                 (reset_n),
  .user_clk                (user_clk),

  .regreq_axis_tvalid_cif  (regreq_axis_tvalid_cifdn),
  .regreq_axis_tdata       (regreq_axis_tdata),
  .regreq_axis_tlast       (regreq_axis_tlast),
  .regreq_axis_tuser       (regreq_axis_tuser),
  .regrep_axis_tvalid_cif  (regrep_axis_tvalid_cifdn),
  .regrep_axis_tdata_cif   (regrep_axis_tdata_cifdn),

  .o_ad_0600               (cif_dn_rx_base_dn),    // 0x0600, 0x0608, 0x0610, 0x0618
  .o_ad_0604               (cif_dn_rx_base_up),    // 0x0604, 0x060c, 0x0614, 0x061c
  .o_ad_0680               (cif_dn_rx_ddr_size),   // 0x0680
  .o_ad_07e0               (cif_dn_error),         // 0x07e0[0]
  .o_ad_07e4               (cif_dn_error_detail),  // 0x07e4-0x07f0
  .o_ad_07f4               (cif_dn_error_msk),     // 0x07f4
  .o_ad_07f8               (cif_dn_eg2_inj),       // 0x07f8[2]
  .o_ad_07fc               (cif_dn_eg2_set),       // 0x07fc[2]
  .o_ad_1600               (cif_dn_mode),          // 0x1600
  .i_ad_0700               (i_ad_0700),
  .i_ad_0704               (i_ad_0704),
  .i_ad_0708               (i_ad_0708),
  .i_ad_070c               (i_ad_070c),
  .i_ad_0710               (i_ad_0710),
  .i_ad_0714               (i_ad_0714),
  .i_ad_07e4               (i_ad_07e4_merge),
  .i_ad_07f8               (i_ad_07f8),
  .i_ad_1640               (i_ad_1640_merge),
  .i_ad_1644               (i_ad_1644),
  .i_ad_1648               (i_ad_1648),
  .i_ad_164c               (i_ad_164c),
  .i_ad_1654               (i_ad_1654),
  .i_ad_1658               (i_ad_1658),
  .i_ad_165c               (i_ad_165c),
  .i_ad_1660               (i_ad_1660),
  .i_ad_1664               (i_ad_1664),
  .i_ad_1668               (i_ad_1668),
  .i_ad_166c               (i_ad_166c),
  .i_ad_1670               (i_ad_1670),
  .i_ad_1674               (i_ad_1674),
  .i_ad_1678               (i_ad_1678),

  .dbg_enable              (dbg_enable),
  .dbg_count_reset         (dbg_count_reset),
  .pa00_inc_enb            (pa00_inc_enb),
  .pa01_inc_enb            (pa01_inc_enb),
  .pa02_inc_enb            (pa02_inc_enb),
  .pa03_inc_enb            (pa03_inc_enb),
  .pa04_inc_enb            (pa04_inc_enb),
  .pa05_inc_enb            (pa05_inc_enb),
  .pa06_inc_enb            (pa06_inc_enb),
  .pa07_inc_enb            (pa07_inc_enb),
  .pa08_inc_enb            (pa08_inc_enb),
  .pa09_inc_enb            (pa09_inc_enb),
  .pa10_add_val            (pa10_add_val),
  .pa11_add_val            (pa11_add_val),
  .pa12_add_val            (pa12_add_val),
  .pa13_add_val            (pa13_add_val),
  .dma_trace_enable        (dma_trace_enable),
  .dma_trace_rst           (dma_trace_rst),
  .dbg_freerun_count       (dbg_freerun_count),
  .trace_we                (trace_we),
  .trace_wd                (trace_wd),
  .trace_we_mode           (trace_we_mode),
  .trace_wd_mode           (trace_wd_mode),
  .trace_free_run_cnt      (trace_free_run_cnt)
);

assign error_detect_cif_dn = cif_dn_error;

endmodule
