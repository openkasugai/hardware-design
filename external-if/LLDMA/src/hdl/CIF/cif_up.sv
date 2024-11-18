/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module cif_up #(
  parameter CHAIN_NUM     = 4,
  parameter CH_NUM        = 32,
  parameter CH_PAR_CHAIN  = CH_NUM / CHAIN_NUM,
  parameter BUF1_WORD     = 32*16,  // Number of BUF1 word. 1word=64B
  parameter BUF1_SDB_NUM  = 32
)(
  input  logic                 reset_n,      // LLDMA internal reset
  input  logic                 ext_reset_n,  // Chain control unit reset
  input  logic                 user_clk,     // LLDMA internal clock
  input  logic                 ext_clk,      // Chain control clock

  output logic                 c2d_axis_tvalid[CHAIN_NUM-1:0],
  output logic [511:0]         c2d_axis_tdata[CHAIN_NUM-1:0],
  output logic                 c2d_axis_tlast[CHAIN_NUM-1:0],
  output logic [15:0]          c2d_axis_tuser[CHAIN_NUM-1:0],
  input  logic                 c2d_axis_tready[CHAIN_NUM-1:0],
  input  logic [1:0]           c2d_pkt_mode[CH_NUM-1:0],

  output logic [CHAIN_NUM-1:0]        m_axi_cu_awvalid,
  input  logic [CHAIN_NUM-1:0]        m_axi_cu_awready,
  output logic [CHAIN_NUM-1:0][63:0]  m_axi_cu_awaddr,
  output logic [CHAIN_NUM-1:0][7:0]   m_axi_cu_awlen,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cu_awsize,
  output logic [CHAIN_NUM-1:0][1:0]   m_axi_cu_awburst,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_awlock,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cu_awcache,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cu_awprot,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cu_awqos,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cu_awregion,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_wvalid,
  input  logic [CHAIN_NUM-1:0]        m_axi_cu_wready,
  output logic [CHAIN_NUM-1:0][511:0] m_axi_cu_wdata,
  output logic [CHAIN_NUM-1:0][63:0]  m_axi_cu_wstrb,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_wlast,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_arvalid,
  input  logic [CHAIN_NUM-1:0]        m_axi_cu_arready,
  output logic [CHAIN_NUM-1:0][63:0]  m_axi_cu_araddr,
  output logic [CHAIN_NUM-1:0][7:0]   m_axi_cu_arlen,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cu_arsize,
  output logic [CHAIN_NUM-1:0][1:0]   m_axi_cu_arburst,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_arlock,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cu_arcache,
  output logic [CHAIN_NUM-1:0][2:0]   m_axi_cu_arprot,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cu_arqos,
  output logic [CHAIN_NUM-1:0][3:0]   m_axi_cu_arregion,
  input  logic [CHAIN_NUM-1:0]        m_axi_cu_rvalid,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_rready,
  input  logic [CHAIN_NUM-1:0][511:0] m_axi_cu_rdata,
  input  logic [CHAIN_NUM-1:0]        m_axi_cu_rlast,
  input  logic [CHAIN_NUM-1:0][1:0]   m_axi_cu_rresp,
  input  logic [CHAIN_NUM-1:0]        m_axi_cu_bvalid,
  output logic [CHAIN_NUM-1:0]        m_axi_cu_bready,
  input  logic [CHAIN_NUM-1:0][1:0]   m_axi_cu_bresp,

  input  logic [CHAIN_NUM-1:0]        s_axis_cu_transfer_cmd_valid,
  input  logic [CHAIN_NUM-1:0][63:0]  s_axis_cu_transfer_cmd_data,
  output logic [CHAIN_NUM-1:0]        s_axis_cu_transfer_cmd_ready,
  output logic [CHAIN_NUM-1:0]        m_axis_cu_transfer_eve_valid,
  output logic [CHAIN_NUM-1:0][127:0] m_axis_cu_transfer_eve_data,
  input  logic [CHAIN_NUM-1:0]        m_axis_cu_transfer_eve_ready,

  input  logic [CH_NUM-1:0]    c2d_txch_ie,
  input  logic [CH_NUM-1:0]    c2d_txch_clr,
  output logic [CH_NUM-1:0]    c2d_cifu_busy,
  input  logic [CH_NUM-1:0]    c2d_cifu_rd_enb,

  input  logic                 regreq_axis_tvalid_cifup,
  input  logic [511:0]         regreq_axis_tdata,
  input  logic                 regreq_axis_tlast,
  input  logic [63:0]          regreq_axis_tuser,
  output logic                 regrep_axis_tvalid_cifup,
  output logic [31:0]          regrep_axis_tdata_cifup,
  input  logic                 dbg_enable,
  input  logic                 dbg_count_reset,
  input  logic                 dma_trace_enable,
  input  logic                 dma_trace_rst,
  input  logic [31:0]          dbg_freerun_count,

  output logic [31:0]               frame_info_size [CHAIN_NUM-1:0],
  output logic [$clog2(CH_NUM)-1:0] frame_info_ch   [CHAIN_NUM-1:0],
  output logic [CHAIN_NUM-1:0]      frame_info_valid,

// error
  output logic                 error_detect_cif_up
);

//// signal ////
localparam BUF1_AD_W     = $clog2(BUF1_WORD);
localparam BUF1_SDB_AD_W = $clog2(BUF1_SDB_NUM);

logic [31:0]            cif_up_tx_base_dn[CHAIN_NUM-1:0];
logic [31:0]            cif_up_tx_base_up[CHAIN_NUM-1:0];
logic [2:0]             cif_up_tx_ddr_size;
logic                   cif_up_error;
logic [31:0]            cif_up_error_detail[CHAIN_NUM-1:0];
logic [31:0]            cif_up_error_msk;
logic                   cif_up_eg2_set;
logic                   cif_up_eg2_inj;
logic [31:0]            cif_up_mode;
logic                   transfer_cmd_err_detect_all;
logic [CHAIN_NUM-1:0]   transfer_cmd_err_detect;
logic [31:0]            i_ad_0900[CHAIN_NUM-1:0];
logic [31:0]            i_ad_0904[CHAIN_NUM-1:0];
logic [31:0]            i_ad_0908[CHAIN_NUM-1:0];
logic [31:0]            i_ad_090c[CHAIN_NUM-1:0];
logic [31:0]            i_ad_0910[CHAIN_NUM-1:0];
logic [31:0]            i_ad_0914[CHAIN_NUM-1:0];
logic [31:0]            i_ad_09e4[CHAIN_NUM-1:0];
logic [31:0]            i_ad_09f8[CHAIN_NUM-1:0];
logic [31:0]            i_ad_1840[CHAIN_NUM-1:0];
logic [31:0]            i_ad_1844[CHAIN_NUM-1:0];
logic [31:0]            i_ad_1848[CHAIN_NUM-1:0];
logic [31:0]            i_ad_184c[CHAIN_NUM-1:0];
logic [31:0]            i_ad_1854[CH_NUM-1:0];
logic [31:0]            i_ad_1858[CH_NUM-1:0];
logic [31:0]            i_ad_185c[CH_NUM-1:0];
logic [31:0]            i_ad_1860[CH_NUM-1:0];
logic [31:0]            i_ad_1864[CH_NUM-1:0];
logic [31:0]            i_ad_1868[CH_NUM-1:0];
logic [31:0]            i_ad_186c[CHAIN_NUM-1:0];
logic [31:0]            i_ad_1870[CHAIN_NUM-1:0];
logic [31:0]            i_ad_1874[CHAIN_NUM-1:0];
logic [31:0]            i_ad_1878[CHAIN_NUM-1:0];
logic [31:0]            i_ad_187c[CHAIN_NUM-1:0];
logic [CH_NUM-1:0]      pa00_inc_enb;
logic [CH_NUM-1:0]      pa01_inc_enb;
logic [CH_NUM-1:0]      pa02_inc_enb;
logic [CH_NUM-1:0]      pa03_inc_enb;
logic [CH_NUM-1:0]      pa04_inc_enb;
logic [CH_NUM-1:0]      pa05_inc_enb;
logic [15:0]            pa10_add_val[CHAIN_NUM-1:0];
logic [15:0]            pa11_add_val[CHAIN_NUM-1:0];
logic [15:0]            pa12_add_val[CHAIN_NUM-1:0];
logic [15:0]            pa13_add_val[CHAIN_NUM-1:0];
//logic [15:0]            trace_we[CHAIN_NUM-1:0];
//logic [15:0][31:0]      trace_wd[CHAIN_NUM-1:0];
logic [3:0]             trace_we[CHAIN_NUM-1:0];
logic [3:0][31:0]       trace_wd[CHAIN_NUM-1:0];
logic [3:0]             trace_we_mode;
logic [3:0]             trace_wd_mode;
logic [31:0]            trace_free_run_cnt;
logic [31:0]            dbg_dma_size[CH_NUM-1:0];
logic [$clog2(CH_PAR_CHAIN)-1:0] frame_info_ch_chain[CHAIN_NUM-1:0];

generate
  for(genvar i=0; i<CH_NUM; i++) begin
    assign dbg_dma_size[i] = '0;
  end
endgenerate
//// logic ////

////////////////////////////////////////////////
// cif_up_chainx : per-chain logic
////////////////////////////////////////////////
generate
for(genvar i=0; i<CHAIN_NUM; i++) begin: cif_up_chainx

  logic [$clog2(CHAIN_NUM)-1:0] chain_no;
  assign chain_no = i;

  assign frame_info_ch[i] = {chain_no, frame_info_ch_chain[i]};

  cif_up_chainx #(
    .CHAIN_ID       (i),
    .CH_NUM         (CH_PAR_CHAIN),  // CH_NUM/CHAIN_NUM
    .BUF1_WORD      (32*16),
    .BUF1_SDB_NUM   (32)
  ) cif_up_chainx (
    .reset_n                       (reset_n),
    .ext_reset_n                   (ext_reset_n),
    .user_clk                      (user_clk),
    .ext_clk                       (ext_clk),

    .c2d_axis_tvalid               (c2d_axis_tvalid[i]),
    .c2d_axis_tdata                (c2d_axis_tdata[i]),
    .c2d_axis_tlast                (c2d_axis_tlast[i]),
    .c2d_axis_tuser                (c2d_axis_tuser[i]),
    .c2d_axis_tready               (c2d_axis_tready[i]),
    .c2d_pkt_mode                  (c2d_pkt_mode[i*8+7:i*8]),

    .m_axi_cu_awvalid              (m_axi_cu_awvalid[i]),
    .m_axi_cu_awready              (m_axi_cu_awready[i]),
    .m_axi_cu_awaddr               (m_axi_cu_awaddr[i]),
    .m_axi_cu_awlen                (m_axi_cu_awlen[i]),
    .m_axi_cu_awsize               (m_axi_cu_awsize[i]),
    .m_axi_cu_awburst              (m_axi_cu_awburst[i]),
    .m_axi_cu_awlock               (m_axi_cu_awlock[i]),
    .m_axi_cu_awcache              (m_axi_cu_awcache[i]),
    .m_axi_cu_awprot               (m_axi_cu_awprot[i]),
    .m_axi_cu_awqos                (m_axi_cu_awqos[i]),
    .m_axi_cu_awregion             (m_axi_cu_awregion[i]),
    .m_axi_cu_wvalid               (m_axi_cu_wvalid[i]),
    .m_axi_cu_wready               (m_axi_cu_wready[i]),
    .m_axi_cu_wdata                (m_axi_cu_wdata[i]),
    .m_axi_cu_wstrb                (m_axi_cu_wstrb[i]),
    .m_axi_cu_wlast                (m_axi_cu_wlast[i]),
    .m_axi_cu_arvalid              (m_axi_cu_arvalid[i]),
    .m_axi_cu_arready              (m_axi_cu_arready[i]),
    .m_axi_cu_araddr               (m_axi_cu_araddr[i]),
    .m_axi_cu_arlen                (m_axi_cu_arlen[i]),
    .m_axi_cu_arsize               (m_axi_cu_arsize[i]),
    .m_axi_cu_arburst              (m_axi_cu_arburst[i]),
    .m_axi_cu_arlock               (m_axi_cu_arlock[i]),
    .m_axi_cu_arcache              (m_axi_cu_arcache[i]),
    .m_axi_cu_arprot               (m_axi_cu_arprot[i]),
    .m_axi_cu_arqos                (m_axi_cu_arqos[i]),
    .m_axi_cu_arregion             (m_axi_cu_arregion[i]),
    .m_axi_cu_rvalid               (m_axi_cu_rvalid[i]),
    .m_axi_cu_rready               (m_axi_cu_rready[i]),
    .m_axi_cu_rdata                (m_axi_cu_rdata[i]),
    .m_axi_cu_rlast                (m_axi_cu_rlast[i]),
    .m_axi_cu_rresp                (m_axi_cu_rresp[i]),
    .m_axi_cu_bvalid               (m_axi_cu_bvalid[i]),
    .m_axi_cu_bready               (m_axi_cu_bready[i]),
    .m_axi_cu_bresp                (m_axi_cu_bresp[i]),

    .s_axis_cu_transfer_cmd_valid  (s_axis_cu_transfer_cmd_valid[i]),
    .s_axis_cu_transfer_cmd_data   (s_axis_cu_transfer_cmd_data[i]),
    .s_axis_cu_transfer_cmd_ready  (s_axis_cu_transfer_cmd_ready[i]),
    .m_axis_cu_transfer_eve_valid  (m_axis_cu_transfer_eve_valid[i]),
    .m_axis_cu_transfer_eve_data   (m_axis_cu_transfer_eve_data[i]),
    .m_axis_cu_transfer_eve_ready  (m_axis_cu_transfer_eve_ready[i]),

    .c2d_txch_ie                   (c2d_txch_ie[i*8+7:i*8]),
    .c2d_txch_clr                  (c2d_txch_clr[i*8+7:i*8]),
    .c2d_cifu_busy                 (c2d_cifu_busy[i*8+7:i*8]),
    .c2d_cifu_rd_enb               (c2d_cifu_rd_enb[i*8+7:i*8]),
    .cif_up_mode                   (cif_up_mode),

    .cif_up_tx_base_dn             (cif_up_tx_base_dn[i]),
    .cif_up_tx_base_up             (cif_up_tx_base_up[i]),
    .cif_up_tx_ddr_size            (cif_up_tx_ddr_size),
    .cif_up_eg2_set                (cif_up_eg2_set),
    .transfer_cmd_err_detect_all   (transfer_cmd_err_detect_all),
    .transfer_cmd_err_detect       (transfer_cmd_err_detect[i]),
    .i_ad_0900_ff                  (i_ad_0900[i]),
    .i_ad_0904_ff                  (i_ad_0904[i]),
    .i_ad_0908_ff                  (i_ad_0908[i]),
    .i_ad_090c_ff                  (i_ad_090c[i]),
    .i_ad_0910_ff                  (i_ad_0910[i]),
    .i_ad_0914_ff                  (i_ad_0914[i]),
    .i_ad_09e4_ff                  (i_ad_09e4[i]),
    .i_ad_09f8_ff                  (i_ad_09f8[i]),
    .i_ad_1840_ff                  (i_ad_1840[i]),
    .i_ad_1844_ff                  (i_ad_1844[i]),
    .i_ad_1848_ff                  (i_ad_1848[i]),
    .i_ad_184c_ff                  (i_ad_184c[i]),
    .i_ad_1854_ff                  (i_ad_1854[i*8+7:i*8]),
    .i_ad_1858_ff                  (i_ad_1858[i*8+7:i*8]),
    .i_ad_185c_ff                  (i_ad_185c[i*8+7:i*8]),
    .i_ad_1860_ff                  (i_ad_1860[i*8+7:i*8]),
    .i_ad_1864_ff                  (i_ad_1864[i*8+7:i*8]),
    .i_ad_1868_ff                  (i_ad_1868[i*8+7:i*8]),
    .i_ad_186c_ff                  (i_ad_186c[i]),
    .i_ad_1870_ff                  (i_ad_1870[i]),
    .i_ad_1874_ff                  (i_ad_1874[i]),
    .i_ad_1878_ff                  (i_ad_1878[i]),
    .i_ad_187c_ff                  (i_ad_187c[i]),
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
    .trace_free_run_cnt            (trace_free_run_cnt),
    .frame_info_size               (frame_info_size[i]),
    .frame_info_ch                 (frame_info_ch_chain[i]),
    .frame_info_valid              (frame_info_valid[i])
//    .o_dma_size                    (dbg_dma_size[i*8+7:i*8])
  );
end
endgenerate

assign transfer_cmd_err_detect_all = |transfer_cmd_err_detect;

////////////////////////////////////////////////
// cifu_reg : register
////////////////////////////////////////////////
cifu_reg #(
  .CH_NUM     (CH_NUM),
  .CHAIN_NUM  (CHAIN_NUM)
) cifu_reg (
  .reset_n                   (reset_n),
  .user_clk                  (user_clk),

  .regreq_axis_tvalid_cif    (regreq_axis_tvalid_cifup),
  .regreq_axis_tdata         (regreq_axis_tdata),
  .regreq_axis_tlast         (regreq_axis_tlast),
  .regreq_axis_tuser         (regreq_axis_tuser),
  .regrep_axis_tvalid_cif    (regrep_axis_tvalid_cifup),
  .regrep_axis_tdata_cif     (regrep_axis_tdata_cifup),

  .o_ad_0800                 (cif_up_tx_base_dn),    // 0x0800,0x0808,0x0810,0x0818
  .o_ad_0804                 (cif_up_tx_base_up),    // 0x0804,0x080c,0x0814,0x081c
  .o_ad_0880                 (cif_up_tx_ddr_size),   // 0x0880
  .o_ad_09e0                 (cif_up_error),         // 0x09e0[0]
  .o_ad_09e4                 (cif_up_error_detail),  // 0x09e4-0x09f0
  .o_ad_09f4                 (cif_up_error_msk),     // 0x09f4
  .o_ad_09f8                 (cif_up_eg2_inj),       // 0x09f8[2]
  .o_ad_09fc                 (cif_up_eg2_set),       // 0x09fc[2]
  .o_ad_1800                 (cif_up_mode),          // 0x1800
  .i_ad_0900                 (i_ad_0900),
  .i_ad_0904                 (i_ad_0904),
  .i_ad_0908                 (i_ad_0908),
  .i_ad_090c                 (i_ad_090c),
  .i_ad_0910                 (i_ad_0910),
  .i_ad_0914                 (i_ad_0914),
  .i_ad_09e4                 (i_ad_09e4),
  .i_ad_09f8                 (i_ad_09f8),
  .i_ad_1840                 (i_ad_1840),
  .i_ad_1844                 (i_ad_1844),
  .i_ad_1848                 (i_ad_1848),
  .i_ad_184c                 (i_ad_184c),
  .i_ad_1854                 (i_ad_1854),
  .i_ad_1858                 (i_ad_1858),
  .i_ad_185c                 (i_ad_185c),
  .i_ad_1860                 (i_ad_1860),
  .i_ad_1864                 (i_ad_1864),
  .i_ad_1868                 (i_ad_1868),
  .i_ad_186c                 (i_ad_186c),
  .i_ad_1870                 (i_ad_1870),
  .i_ad_1874                 (i_ad_1874),
  .i_ad_1878                 (i_ad_1878),
  .i_ad_187c                 (i_ad_187c),
  .i_dbg_dma_size            (dbg_dma_size),
  .dbg_enable                (dbg_enable),
  .dbg_count_reset           (dbg_count_reset),
  .pa00_inc_enb              (pa00_inc_enb),
  .pa01_inc_enb              (pa01_inc_enb),
  .pa02_inc_enb              (pa02_inc_enb),
  .pa03_inc_enb              (pa03_inc_enb),
  .pa04_inc_enb              (pa04_inc_enb),
  .pa05_inc_enb              (pa05_inc_enb),
  .pa10_add_val              (pa10_add_val),
  .pa11_add_val              (pa11_add_val),
  .pa12_add_val              (pa12_add_val),
  .pa13_add_val              (pa13_add_val),
  .dma_trace_enable          (dma_trace_enable),
  .dma_trace_rst             (dma_trace_rst),
  .dbg_freerun_count         (dbg_freerun_count),
  .trace_we                  (trace_we),
  .trace_wd                  (trace_wd),
  .trace_we_mode             (trace_we_mode),
  .trace_wd_mode             (trace_wd_mode),
  .trace_free_run_cnt        (trace_free_run_cnt)
);

assign error_detect_cif_up = cif_up_error;

endmodule
