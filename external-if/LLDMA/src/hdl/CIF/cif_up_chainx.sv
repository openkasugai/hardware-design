/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

//------------------------------------------------------------------------------------
// Caution.
// Every cid in the cif_dn_chainx indicates the relative cid(0~7) in the chain
//------------------------------------------------------------------------------------

module cif_up_chainx #(
  parameter CHAIN_ID      = 0,
  parameter CH_NUM        = 8,      // Number of chs in chain
  parameter BUF1_WORD     = 32*16,  // Number of BUF1 word. 1word=64B
  parameter BUF1_SDB_NUM  = 32
)(
  input  logic              reset_n,      // LLDMA internal reset
  input  logic              ext_reset_n,  // Chain control unit reset
  input  logic              user_clk,     // LLDMA internal clock
  input  logic              ext_clk,      // Chain control clock

  output logic              c2d_axis_tvalid,
  output logic [511:0]      c2d_axis_tdata,
  output logic              c2d_axis_tlast,
  output logic [15:0]       c2d_axis_tuser,
  input  logic              c2d_axis_tready,
  input  logic [1:0]        c2d_pkt_mode[CH_NUM-1:0],

  output logic              m_axi_cu_awvalid,
  input  logic              m_axi_cu_awready,
  output logic [63:0]       m_axi_cu_awaddr,
  output logic [7:0]        m_axi_cu_awlen,
  output logic [2:0]        m_axi_cu_awsize,
  output logic [1:0]        m_axi_cu_awburst,
  output logic              m_axi_cu_awlock,
  output logic [3:0]        m_axi_cu_awcache,
  output logic [2:0]        m_axi_cu_awprot,
  output logic [3:0]        m_axi_cu_awqos,
  output logic [3:0]        m_axi_cu_awregion,
  output logic              m_axi_cu_wvalid,
  input  logic              m_axi_cu_wready,
  output logic [511:0]      m_axi_cu_wdata,
  output logic [63:0]       m_axi_cu_wstrb,
  output logic              m_axi_cu_wlast,
  output logic              m_axi_cu_arvalid,
  input  logic              m_axi_cu_arready,
  output logic [63:0]       m_axi_cu_araddr,
  output logic [7:0]        m_axi_cu_arlen,
  output logic [2:0]        m_axi_cu_arsize,
  output logic [1:0]        m_axi_cu_arburst,
  output logic              m_axi_cu_arlock,
  output logic [3:0]        m_axi_cu_arcache,
  output logic [2:0]        m_axi_cu_arprot,
  output logic [3:0]        m_axi_cu_arqos,
  output logic [3:0]        m_axi_cu_arregion,
  input  logic              m_axi_cu_rvalid,
  output logic              m_axi_cu_rready,
  input  logic [511:0]      m_axi_cu_rdata,
  input  logic              m_axi_cu_rlast,
  input  logic [1:0]        m_axi_cu_rresp,
  input  logic              m_axi_cu_bvalid,
  output logic              m_axi_cu_bready,
  input  logic [1:0]        m_axi_cu_bresp,

  input  logic              s_axis_cu_transfer_cmd_valid,
  input  logic [63:0]       s_axis_cu_transfer_cmd_data,
  output logic              s_axis_cu_transfer_cmd_ready,
  output logic              m_axis_cu_transfer_eve_valid,
  output logic [127:0]      m_axis_cu_transfer_eve_data,
  input  logic              m_axis_cu_transfer_eve_ready,

  input  logic [CH_NUM-1:0] c2d_txch_ie,
  input  logic [CH_NUM-1:0] c2d_txch_clr,
  output logic [CH_NUM-1:0] c2d_cifu_busy,
  input  logic [CH_NUM-1:0] c2d_cifu_rd_enb,
  input  logic [31:0]       cif_up_mode,

  input  logic [31:0]       cif_up_tx_base_dn,
  input  logic [31:0]       cif_up_tx_base_up,
  input  logic [2:0]        cif_up_tx_ddr_size,
  input  logic              cif_up_eg2_set,
  input  logic              transfer_cmd_err_detect_all,
  output logic              transfer_cmd_err_detect,
  output logic [31:0]       i_ad_0900_ff,
  output logic [31:0]       i_ad_0904_ff,
  output logic [31:0]       i_ad_0908_ff,
  output logic [31:0]       i_ad_090c_ff,
  output logic [31:0]       i_ad_0910_ff,
  output logic [31:0]       i_ad_0914_ff,
  output logic [31:0]       i_ad_09e4_ff,
  output logic [31:0]       i_ad_09f8_ff,
  output logic [31:0]       i_ad_1840_ff,
  output logic [31:0]       i_ad_1844_ff,
  output logic [31:0]       i_ad_1848_ff,
  output logic [31:0]       i_ad_184c_ff,
  output logic [31:0]       i_ad_1854_ff[CH_NUM-1:0],
  output logic [31:0]       i_ad_1858_ff[CH_NUM-1:0],
  output logic [31:0]       i_ad_185c_ff[CH_NUM-1:0],
  output logic [31:0]       i_ad_1860_ff[CH_NUM-1:0],
  output logic [31:0]       i_ad_1864_ff[CH_NUM-1:0],
  output logic [31:0]       i_ad_1868_ff[CH_NUM-1:0],
  output logic [31:0]       i_ad_186c_ff,
  output logic [31:0]       i_ad_1870_ff,
  output logic [31:0]       i_ad_1874_ff,
  output logic [31:0]       i_ad_1878_ff,
  output logic [31:0]       i_ad_187c_ff,
  output logic [CH_NUM-1:0] pa00_inc_enb_ff,
  output logic [CH_NUM-1:0] pa01_inc_enb_ff,
  output logic [CH_NUM-1:0] pa02_inc_enb_ff,
  output logic [CH_NUM-1:0] pa03_inc_enb_ff,
  output logic [CH_NUM-1:0] pa04_inc_enb_ff,
  output logic [CH_NUM-1:0] pa05_inc_enb_ff,
  output logic [15:0]       pa10_add_val_ff,
  output logic [15:0]       pa11_add_val_ff,
  output logic [15:0]       pa12_add_val_ff,
  output logic [15:0]       pa13_add_val_ff,
  output logic [3:0]        trace_we_ff,
  output logic [3:0][31:0]  trace_wd_ff,
  input  logic [3:0]        trace_we_mode,
  input  logic [3:0]        trace_wd_mode,
  input  logic [31:0]       trace_free_run_cnt,

  output logic [31:0]               frame_info_size,
  output logic [$clog2(CH_NUM)-1:0] frame_info_ch,
  output logic                      frame_info_valid
//  output logic [31:0]               o_dma_size
);

//// signal ////

localparam IDLE          = 0;
localparam DDRRD         = 1;
localparam RDHD1         = 1;
localparam RDHD2         = 2;
localparam RDHD3         = 3;
localparam RDDT          = 4;
localparam RD            = 1;
localparam RDWAIT        = 2;
localparam CH_NUM_W      = $clog2(CH_NUM);
localparam MARKER        = 32'he0ff10ad;
localparam BUF1_AD_W     = $clog2(BUF1_WORD);
localparam BUF1_SDB_AD_W = $clog2(BUF1_SDB_NUM);
localparam HD_SIZE       = 48;
localparam EVE_WAIT      = 32'h10000;

logic                          at_me_main_mode;
logic                          at_me_trace_mode;
logic                          at_me_eve_mode;
logic [31:0]                   eve_wait_value;

logic [31:0]                   a0_tx_ddr_wp_ff[CH_NUM-1:0];
logic [CH_NUM-1:0]             a0_ddr_wp_eq_nxt_hd;

logic [CH_NUM-1:0]             bm1_ddr_wph_eq_rph;
logic [CH_NUM-1:0]             bm1_ddr_wpl_eq_rpl;
logic [CH_NUM-1:0]             bm1_ddr_rpl_eq_0;
logic [CH_NUM-1:0]             bm1_ddrrd_req_inh;

logic [CH_NUM-1:0]             bm1_ddrrd_req;
logic [31:0]                   bm1_ddrrd_nxtrp[CH_NUM-1:0];
logic [10:0]                   bm1_ddrrd_len[CH_NUM-1:0];

logic [CH_NUM-1:0]             b0_ddrrd_req;
logic [31:0]                   b0_ddrrd_nxtrp[CH_NUM-1:0];
logic [10:0]                   b0_ddrrd_len[CH_NUM-1:0];
logic [1:0]                    b0_ddrrd_stm_ff;
logic                          b0_ddrrd_req_anych;
logic                          b0_ddrrd_buf1_sbd_free_ge2;
logic                          ddrrd_arbenb;

logic [CH_NUM-1:0]             b1_ddrrd_gnt;
logic                          b1_ddrrd_gnt_anych;
logic [31:0]                   b1_ddrrd_rp_ff[CH_NUM-1:0];
logic [CH_NUM-1:0]             b1_evesnd_enb_ff;

logic [31:0]                   b1_ddrrd_nxtrp_win;
logic [10:0]                   b1_ddrrd_len_win;
logic [31:0]                   b1_ddrrd_rp_win;
logic [CH_NUM_W-1:0]           b1_ddrrd_cid_win;
logic                          b1_evesnd_enb_win;

logic                          b2_ddrrd_gnt_anych_ff;
logic [31:0]                   b2_ddrrd_nxtrp_win_ff;
logic [10:0]                   b2_ddrrd_len_win_ff;
logic [31:0]                   b2_ddrrd_rp_win_ff;
logic [CH_NUM_W-1:0]           b2_ddrrd_cid_win_ff;
logic                          b2_evesnd_enb_win_ff;
logic                          b2_buf1_sdb_wt;

reg                            b2_arvalid_ff;
reg   [31:0]                   b2_araddr_ff;
reg   [7:0]                    b2_arlen_ff;
reg   [CH_NUM_W-1:0]           b2_arcid_ff;

reg   [BUF1_SDB_AD_W-1:0]      b3_buf1_sdb_rpeve_ff;
reg                            b4_eve_val_ff;
reg   [CH_NUM_W-1:0]           b4_eve_cid_ff;
reg   [31:0]                   b4_eve_tx_ddr_rp_ff;
reg                            b4_evesnd_enb_ff;
logic [31:0]                   b4_eve_tx_ddr_rp_mod;
logic [31:0]                   b5_ddrrd_rp_ff[CH_NUM-1:0];

reg   [BUF1_AD_W-1:0]          c0_buf1_wp_ff;
reg   [BUF1_AD_W:0]            b2_buf1_wp_rsv_ff;

logic                          b3_evesnd_anych;
reg   [BUF1_SDB_AD_W-1:0]      b1_buf1_sdb_wpreq_ff;
reg   [BUF1_SDB_AD_W-1:0]      b1_buf1_sdb_wprcv_ff;
reg   [CH_NUM_W-1:0]           b3_buf1_cid_ff[BUF1_SDB_NUM-1:0];
reg   [31:0]                   b3_buf1_nxt_ddrrd_rp_ff[BUF1_SDB_NUM-1:0];
reg   [BUF1_SDB_NUM-1:0]       b3_buf1_rcv_flg_ff;
reg   [BUF1_SDB_NUM-1:0]       b3_buf1_evesnd_flg_ff;
reg   [BUF1_SDB_NUM-1:0]       b3_buf1_evesnd_enb_ff;
logic [BUF1_SDB_AD_W:0]        sdb0_dtsize;
logic [BUF1_SDB_AD_W:0]        sdb0_dtsize_chx[CH_NUM-1:0];
logic                          sdb0_dtfull;
logic                          sdb0_dtovfl;
logic                          sdb0_dtfull_hld;
logic                          sdb0_dtovfl_hld;

logic [CH_NUM_W-1:0]           d0_buf1_sdb_cid_ff[BUF1_SDB_NUM:0];
logic [5:0]                    d0_buf1_sdb_ddrrd_rp_ff[BUF1_SDB_NUM:0];
logic [5:0]                    d0_buf1_sdb_nxt_ddrrd_rp_ff[BUF1_SDB_NUM:0];
logic [10:6]                   d0_buf1_sdb_pkt_len_ff[BUF1_SDB_NUM:0];
logic [BUF1_SDB_AD_W-1:0]      d0_buf1_sdb_rpsnd_ff;

logic [BUF1_SDB_AD_W:0]        sdb1_dtsize;
logic [BUF1_SDB_AD_W:0]        sdb1_dtsize_chx[CH_NUM-1:0];
logic                          sdb1_dtfull;
logic                          sdb1_dtovfl;
logic                          sdb1_dtfull_hld;
logic                          sdb1_dtovfl_hld;

logic                   d0_buf1_rd_inh;
logic                   d0_buf1_dt_exist;
logic                   d0_buf1_re;
logic                   d0_valid;
logic [CH_NUM-1:0]      d0_cid_vec;
logic [CH_NUM_W-1:0]    d0_buf1rd_cid;

logic                   d0_buf1_sdb_pkt_len_eq64;
logic                   d0_pkt_remlen_gt64;
logic [10:0]            d0_tmp_len0;
logic [10:0]            d0_tmp_len1;
logic [10:0]            d0_tmp_len2;
logic [10:0]            d0_tmp_len3;
logic [10:0]            d0_tmp_len4;
logic [5:0]             d0_tmp_rp;
logic [33+CH_NUM:0]     d0_tmp;
logic [3:0]             d0_debug_st;
logic                   dm1_pkt_snd_busy_din;
logic [10:0]            dm1_pkt_remlen_din;
logic [CH_NUM-1:0]      d0_cid_vec_din;
logic [5:0]             d0_buf1_sdb_ddrrd_rp_din;
logic [10:0]            d0_pkt_remlen_din;
logic                   d0_pkt_eop;
logic [BUF1_AD_W:0]     d0_buf1_rp_ff;
logic                   d0_pkt_snd_busy_ff;
logic [10:0]            d0_pkt_remlen_ff;
logic                   d1_valid_ff;
logic                   d1_buf1_rd_inh_ff;
logic [CH_NUM-1:0]      d1_cid_vec_ff;
logic [5:0]             d1_buf1_sdb_ddrrd_rp_ff;
logic [10:0]            d1_pkt_remlen_ff;

logic [CH_NUM-1:0]      d1_frm_snd_busy_ff;
logic                   d1_frm_snd_busy;
logic [6:0]             d1_sftreg_len_ff[CH_NUM:0];
logic [32:0]            d1_frm_remlen_ff[CH_NUM:0];
logic [32:0]            d1_sftreg_frm_remlen_ff[CH_NUM:0];
logic                   d1_frm_remlen_ge256_ff;
logic [6:0]             d1_sftreg_len;
logic [32:0]            d1_frm_remlen;
logic [32:0]            d1_sftreg_frm_remlen;
logic                   d1_buf1_sdb_ddrrd_rp_eq0;
logic                   d1_sftreg_len_eq0;
logic                   d1_pkt_remlen_lt64;
logic                   d1_frm_remlen_lt64;
logic                   d1_frm_remlen_eq64;
logic                   d1_sftreg_frm_remlen_gt64;
logic [6:0]             d1_tmp_len0;
logic [6:0]             d1_tmp_len1;
logic [6:0]             d1_tmp_len2;
logic [6:0]             d1_tmp_len3;
logic [6:0]             d1_tmp_len4;
logic [6:0]             d1_tmp_len5;
logic [37+CH_NUM:0]     d1_tmp;

logic [3:0]             d1_debug_st;
logic [CH_NUM-1:0]      d1_cid_vec_din;
logic                   d1_sftreg_we_din;
logic [6:0]             d1_sftreg_len_din;
logic                   d1_buf2_we_din;
logic [6:0]             d1_buf1_rd_rot_din;
logic [6:0]             d1_buf2_wd_sel0_din;
logic [6:0]             d1_buf2_wd_selr_din;
logic                   d1_sftreg_set_sof;
logic                   d1_frm_sof;
logic                   d1_frm_eof;
logic [511:0]           d1_buf1_rddata;

logic [CH_NUM-1:0]      d2_cid_vec_ff;
logic                   d2_sftreg_we_ff;
logic                   d2_buf2_we_ff;
logic [6:0]             d2_buf1_rd_rot_ff;
logic [6:0]             d2_buf2_wd_sel0_ff;
logic [6:0]             d2_buf2_wd_selr_ff;
logic [511:0]           d2_buf1_rddata_ff;
logic                   d2_sftreg_set_sof_ff;
logic [6:0]             d2_sftreg_set_len_ff;
logic                   d2_frm_sof_ff;
logic [1023:0]          d2_buf1_rd_tmp;

logic [CH_NUM-1:0]      d3_cid_vec_ff;
logic                   d3_sftreg_we_ff;
logic                   d3_buf2_we_ff;
logic [511:0]           d3_buf1_rddata_rot_ff;
logic [6:0]             d3_buf2_wd_sel0_ff;
logic [6:0]             d3_buf2_wd_selr_ff;
logic                   d3_sftreg_set_sof_ff;
logic [6:0]             d3_sftreg_set_len_ff;
logic                   d3_frm_sof_ff;

logic [511:0]           d3_sftreg_dt_ff[CH_NUM-1:0];
logic [511:0]           d3_sftreg_dt;
logic [CH_NUM-1:0]      d3_sftreg_sof_ff;
logic                   d3_sftreg_sof;
logic [511:0]           d3_buf2_wd;

logic [CH_NUM_W-1:0]    d4_cid;
logic                   d4_buf2_we_ff;
logic [CH_NUM-1:0]      d4_buf2_we_inh_ff;
logic                   d4_buf2_we_inh_or;
logic [511:0]           d4_buf2_wd_ff;
logic [5:0]             d4_buf2_wp_ff[CH_NUM-1:0];
logic [5:0]             d4_buf2_wp;

logic                   d4_frm_sof_we_ff;
logic [CH_NUM-1:0]      d4_cid_vec_ff;
logic [6:0]             d4_sftreg_set_len_ff;
logic [31:0]            d4_frm_marker_ff;
logic [31:0]            d4_frm_payload_len_ff;
logic                   d4_frm_marker_err;
logic                   d4_frm_payload_err;
logic [31:0]            d4_payload_len_for_marker_err_ff[CH_NUM-1:0];
logic [1:0]             d4_set_d0_frm_remlen_term1;
logic [8:0]             d4_set_d0_frm_remlen_term2;
logic [31:0]            d4_set_d0_frm_remlen;
logic [31:0]            d4_set_d0_sftreg_frm_remlen;
logic [31:0]            d4_frm_header_w2_ff;
logic [31:0]            d4_frm_header_w3_ff;
logic [31:0]            d4_frm_frame_cnt_ff[CH_NUM-1:0];

logic [31:0]            d5_nxt_frm_hd_ddrwp_ff[CH_NUM-1:0];
logic [7:0]             d5_frm_marker_err_cid_vec;
logic [7:0]             d5_frm_marker_err_cid_vec_acc;
logic [31:0]            d5_frm_marker_err_payload_len;
logic [31:0]            d5_frm_me_marker_ff;
logic [31:0]            d5_frm_me_payload_len_ff;
logic [31:0]            d5_frm_me_header_w2_ff;
logic [31:0]            d5_frm_me_header_w3_ff;
logic [31:0]            d5_frm_me_frame_cnt_ff;
logic [31:0]            d5_frm_me_frm_hd_ddrwp_ff;
logic [31:0]            d5_frm_me_ddr_wp_ff;
logic [31:0]            d5_frm_me_ddr_rp_ff;
logic [31:0]            d5_frm_me_buf1_wp_rp_ff;
logic                   d5_buf2_we_inh_or_ff;

logic [CH_NUM-1:0]      em1_buf2dt_ge_1kb;
logic [CH_NUM-1:0]      em1_buf2dt_ge_1stfrmw;
logic [CH_NUM-1:0]      em1_buf2dt_exist;
logic [CH_NUM-1:0]      em1_1stfrmw_gt_1kb;
logic [CH_NUM-1:0]      em1_buf2rd_hd;
logic [CH_NUM-1:0]      em1_buf2rd_req_inh;

logic [CH_NUM-1:0]      em1_buf2rd_req;
logic [4:0]             em1_buf2rd_len[CH_NUM-1:0];
logic [CH_NUM-1:0]      em1_buf2rd_last;

logic [CH_NUM-1:0]      e0_buf2rd_hd;

logic [CH_NUM-1:0]      e0_buf2rd_req;
logic [4:0]             e0_buf2rd_len[CH_NUM-1:0];
logic [CH_NUM-1:0]      e0_buf2rd_last;

logic [5:0]             e1_buf2_rp_ff[CH_NUM-1:0];
logic [CH_NUM-1:0]      e2_buf2rd_gnt_ff;
logic [CH_NUM-1:0]      e3_buf2rd_gnt_ff;
logic [CH_NUM-1:0]      buf2rd_gnt_hold_ff;

reg   [511:0]           e2_buf2rd_data;
logic [511:0]           e3_buf2rd_data_ff;
logic                   buf2rd_arbenb;
logic [CH_NUM-1:0]      e1_buf2rd_gnt;
logic                   e1_buf2rd_gnt_anych;
logic                   e1_buf2rd_hd_win;
logic                   e1_buf2rd_last_win;
logic [4:0]             e1_buf2rd_len_win;
logic [5:0]             e1_buf2rd_rp_win;
logic [CH_NUM_W-1:0]    e1_buf2rd_cid_win;
logic [CH_NUM_W-1:0]    e1_buf2rd_cid_win_hold;
logic [31:0]            buf2_1stfrm_word_win;
reg   [1:0]             buf2rd_stm_ff;
logic                   e1_buf2rd_re;
logic [CH_NUM-1:0]      e1_buf2rd_re_chx;
logic [31:0]            e3_buf2rd_byte;
logic [31:0]            e3_buf2rd_word;
reg   [4:0]             e2_buf2rd_remlen_ff;
reg   [4:0]             e3_buf2rd_remlen_ff;
logic                   e3_buf2rd_pktend;
logic                   e4_frm_marker_err;

reg                     e2_buf2rd_re_ff;
reg                     e2_buf2rd_gnt_anych_ff;
reg                     e2_buf2rd_hd_ff;
reg                     e2_buf2rd_last_hold_ff;
reg   [CH_NUM_W-1:0]    e2_buf2rd_cid_hold_ff;
reg   [4:0]             e2_buf2rd_len_win_ff;
reg                     e3_buf2rd_re_ff;
reg                     e3_buf2rd_gnt_anych_ff;
reg   [4:0]             e3_buf2rd_len_hold_ff;
reg                     e3_buf2rd_hd_ff;
reg   [CH_NUM_W-1:0]    e3_buf2rd_cid_hold_ff;
reg                     e4_buf2rd_val_ff;
reg   [511:0]           e4_buf2rd_data_ff;
reg                     e4_buf2rd_sop_ff;
reg                     e4_buf2rd_eop_ff;
reg                     e4_buf2rd_last_ff;
reg   [CH_NUM_W-1:0]    e4_buf2rd_cid_ff;
reg   [4:0]             e4_buf2rd_burst_ff;

logic [1:0]             pkt_mode_ff[CH_NUM-1:0];
logic [31:0]            b1_ddrrd_nxtrp_ff[CH_NUM-1:0];
logic [10:0]            b1_ddrrd_len_ff[CH_NUM-1:0];

logic [CH_NUM-1:0]      buf2_space_gt_6w_ff;
logic                   buf2_space_gt_6w;
logic [31:0]            buf2_1stfrm_word_ff[CH_NUM-1:0];

logic                   cmd_valid_clktr;
logic                   cmd_valid;
logic [63:0]            cmd_data;
logic                   cmd_ready;
logic                   transfer_cmd_err;
logic                   eve_valid;
logic [127:0]           eve_data;
logic                   eve_ready;

logic [CH_NUM-1:0]      txch_ie_t1_ff;
logic [CH_NUM-1:0]      txch_clr_t1_ff;
logic [CH_NUM-1:0]      rd_enb_t1_ff;
logic [CH_NUM-1:0]      cifu_busy_pre_ff;
logic [CH_NUM-1:0]      cifu_busy_ff;

logic [31:0]            cif_up_tx_base_dn_ff;
logic [31:0]            cif_up_tx_base_up_ff;
logic [31:0]            i_ad_0900;
logic [31:0]            i_ad_0904;
logic [31:0]            i_ad_0908;
logic [31:0]            i_ad_090c;
logic [31:0]            i_ad_0910;
logic [31:0]            i_ad_0914;
logic [31:0]            i_ad_09e4;
logic [31:0]            i_ad_09f8;
logic [31:0]            i_ad_1840;
logic [31:0]            i_ad_1844;
logic [31:0]            i_ad_1848;
logic [31:0]            i_ad_184c;
logic [31:0]            i_ad_1854[CH_NUM-1:0];
logic [31:0]            i_ad_1858[CH_NUM-1:0];
logic [31:0]            i_ad_185c[CH_NUM-1:0];
logic [31:0]            i_ad_1860[CH_NUM-1:0];
logic [31:0]            i_ad_1864[CH_NUM-1:0];
logic [31:0]            i_ad_1868[CH_NUM-1:0];
logic [31:0]            i_ad_186c;
logic [31:0]            i_ad_1870;
logic [31:0]            i_ad_1874;
logic [31:0]            i_ad_1878;
logic [31:0]            i_ad_187c;
reg   [9:0]             cifu_infl_num_ff;
logic [BUF1_AD_W:0]     buf1_dtsize_rsv;
logic [BUF1_AD_W:0]     buf1_dtsize;
logic [BUF1_AD_W:0]     buf1_dtsize_ff;
logic                   buf1_dtfull;
logic                   buf1_dtovfl;
logic                   buf1_dtfull_hld;
logic                   buf1_dtovfl_hld;
logic [5:0]             buf2_dtsize[CH_NUM-1:0];
logic [CH_NUM-1:0]      buf2_dtfull;
logic [CH_NUM-1:0]      buf2_dtfullm1;
logic [CH_NUM-1:0]      buf2_dtovfl;
logic                   buf2_dtfull_hld;
logic                   buf2_dtovfl_hld;
logic [CH_NUM-1:0]      pa00_inc_enb;
logic [CH_NUM-1:0]      pa01_inc_enb;
logic [CH_NUM-1:0]      pa02_inc_enb;
logic [CH_NUM-1:0]      pa03_inc_enb;
logic [CH_NUM-1:0]      pa04_inc_enb;
logic [CH_NUM-1:0]      pa05_inc_enb;
logic [15:0]            pa10_add_val;
logic [15:0]            pa11_add_val;
logic [15:0]            pa12_add_val;
logic [15:0]            pa13_add_val;
logic [3:0]             trace_we;
logic [3:0][31:0]       trace_wd;
logic [3:0]             trace_we_mode_ff;
logic [3:0]             trace_wd_mode_ff;
logic [31:0]            trace_free_run_cnt_ff;

//// main ////

assign at_me_main_mode  = cif_up_mode[0];
assign at_me_trace_mode = cif_up_mode[1];
assign at_me_eve_mode   = cif_up_mode[2];
assign eve_wait_value   = (at_me_eve_mode ? EVE_WAIT : 32'h0);

////////////////////////////////////////////////
// (2) DDR wp control
////////////////////////////////////////////////
always @(posedge user_clk or negedge reset_n) begin
  for(int i=0; i<CH_NUM; i++) begin
    if(!reset_n) begin
      a0_tx_ddr_wp_ff[i] <= 'b0;
    end else begin
      if(txch_clr_t1_ff[i]) begin
        a0_tx_ddr_wp_ff[i] <= 'b0;
      end else if(cmd_valid & (cmd_data[47:32]==(i+(CHAIN_ID<<CH_NUM_W))) &~cmd_data[48]) begin
      // transfer_cmd_data[48]=0: Send command
        a0_tx_ddr_wp_ff[i] <= cmd_data[31:0];
      end
    end
  end
end

////////////////////////////////////////////////
// (3) DDR rp control/DDR read req generation
////////////////////////////////////////////////
// ddrwp_ge_nxtfrmhd: ddr_wp after next frame header
// * Valid only when ddr_wp[31:10]==ddr_rp[31:10]
// b1_ddrrd_rp_ff is used to generate b0 signal, gnt is OK since minimum interval is 2T

always_comb begin
  for(int i=0; i<CH_NUM; i++) begin
    bm1_ddr_wph_eq_rph[i]   = (a0_tx_ddr_wp_ff[i][31:10]==b1_ddrrd_rp_ff[i][31:10]);
    bm1_ddr_wpl_eq_rpl[i]   = (a0_tx_ddr_wp_ff[i][9:0]  ==b1_ddrrd_rp_ff[i][9:0]);
    bm1_ddr_rpl_eq_0[i]     = (b1_ddrrd_rp_ff[i][9:0]==0);
    a0_ddr_wp_eq_nxt_hd[i]  = (a0_tx_ddr_wp_ff[i] == d5_nxt_frm_hd_ddrwp_ff[i]);

    case({rd_enb_t1_ff[i],
         (b0_ddrrd_req[i] | bm1_ddrrd_req_inh[i] | (at_me_main_mode ? d5_buf2_we_inh_or_ff : d4_buf2_we_inh_ff[i])),
          bm1_ddr_wph_eq_rph[i],
          bm1_ddr_wpl_eq_rpl[i],
          bm1_ddr_rpl_eq_0[i],
          a0_ddr_wp_eq_nxt_hd[i]}) inside
      6'b100?1?: begin
        bm1_ddrrd_req[i]   = 1'b1;
        bm1_ddrrd_nxtrp[i] = {(b1_ddrrd_rp_ff[i][31:10] + 1'b1), 10'h000};
        bm1_ddrrd_len[i]   = 11'h400;
      end
      6'b100?0?: begin
        bm1_ddrrd_req[i]   = 1'b1;
        bm1_ddrrd_nxtrp[i] = {(b1_ddrrd_rp_ff[i][31:10] + 1'b1), 10'h000};
        bm1_ddrrd_len[i]   = 11'h400 - {b1_ddrrd_rp_ff[i][9:6],6'h00};
      end
      6'b1010?1: begin
        bm1_ddrrd_req[i]   = 1'b1;
        bm1_ddrrd_nxtrp[i] = {b1_ddrrd_rp_ff[i][31:10], a0_tx_ddr_wp_ff[i][9:0]};
        bm1_ddrrd_len[i]   = {1'b0,a0_tx_ddr_wp_ff[i][9:6],6'h00} - {1'b0,b1_ddrrd_rp_ff[i][9:6],6'h00} + {4'h0,(a0_tx_ddr_wp_ff[i][5:0]>0),6'h00};
      end
      default: begin
        bm1_ddrrd_req[i]   = 1'b0;
        bm1_ddrrd_nxtrp[i] = b1_ddrrd_rp_ff[i];
        bm1_ddrrd_len[i]   = 11'h000;
      end
    endcase
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  for(int i=0; i<CH_NUM; i++) begin
    if(!reset_n) begin
      bm1_ddrrd_req_inh[i] <= '0;
      b0_ddrrd_req[i]      <= '0;
      b0_ddrrd_nxtrp[i]    <= '0;
      b0_ddrrd_len[i]      <= '0;
    end else if(bm1_ddrrd_req[i]) begin
      b0_ddrrd_req[i]      <= '1;
      b0_ddrrd_nxtrp[i]    <= bm1_ddrrd_nxtrp[i];
      b0_ddrrd_len[i]      <= bm1_ddrrd_len[i];
    end else if(b1_ddrrd_gnt[i]) begin
      b0_ddrrd_req[i]      <= '0;
      bm1_ddrrd_req_inh[i] <= '1;
    end else if(bm1_ddrrd_req_inh[i] & ddrrd_arbenb) begin
      bm1_ddrrd_req_inh[i] <= '0;
    end
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  for(int i=0; i<CH_NUM; i++) begin
    if(!reset_n) begin
      b1_ddrrd_rp_ff[i] <= '0;
    end else begin
      if(txch_clr_t1_ff[i]) begin
        b1_ddrrd_rp_ff[i] <= '0;
      end else if((b0_ddrrd_stm_ff==DDRRD) & b1_ddrrd_gnt[i]) begin
        b1_ddrrd_rp_ff[i] <= b1_ddrrd_nxtrp_ff[i];
      end
    end
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  for(int i=0; i<CH_NUM; i++) begin
    if(!reset_n) begin
      b1_ddrrd_nxtrp_ff[i] <= '0;
      b1_ddrrd_len_ff[i]   <= '0;
    end else begin
      b1_ddrrd_nxtrp_ff[i] <= b0_ddrrd_nxtrp[i];
      b1_ddrrd_len_ff[i]   <= b0_ddrrd_len[i];
    end
  end
end

////////////////////////////////////////////////
// (4) cuf_arb (DDR read arbiter)
////////////////////////////////////////////////
assign ddrrd_arbenb = (b0_ddrrd_stm_ff==IDLE);

cif_arb #(
  .CH_NUM    (CH_NUM)
) cifu_ddrrd_arb (
  .reset_n   (reset_n),
  .user_clk  (user_clk),
  .req       (b0_ddrrd_req),
  .gnt       (b1_ddrrd_gnt),
  .gnt_anych (b1_ddrrd_gnt_anych),
  .arbenb    (ddrrd_arbenb)
);

////////////////////////////////////////////////
// (5) DDR read control ddrrd_stm
////////////////////////////////////////////////
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b1_evesnd_enb_ff  <='0;
  end else if(txch_clr_t1_ff) begin
    b1_evesnd_enb_ff  <='0;
  end else begin
    for(int i=0; i<CH_NUM; i++) begin
      if(b1_ddrrd_gnt[i]==1) begin
        if(b1_ddrrd_nxtrp_ff[i] >= eve_wait_value) begin
          b1_evesnd_enb_ff[i] <= 1'b1;
        end
      end
    end
  end
end

always_comb begin
  b1_ddrrd_nxtrp_win = 'b0;
  b1_ddrrd_len_win   = 'b0;
  b1_ddrrd_rp_win    = 'b0;
  b1_ddrrd_cid_win   = 'b0;
  b1_evesnd_enb_win  = 'b0;

  for(int i=0; i<CH_NUM; i++) begin
    if(b1_ddrrd_gnt[i]==1) begin
      b1_ddrrd_nxtrp_win = b1_ddrrd_nxtrp_ff[i];
      b1_ddrrd_len_win   = b1_ddrrd_len_ff[i];
      b1_ddrrd_rp_win    = b1_ddrrd_rp_ff[i][31:0];
      b1_ddrrd_cid_win   = i;
      b1_evesnd_enb_win  = b1_evesnd_enb_ff[i];
    end
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b2_ddrrd_gnt_anych_ff <= '0;
    b2_ddrrd_nxtrp_win_ff <= '0;
    b2_ddrrd_len_win_ff   <= '0;
    b2_ddrrd_rp_win_ff    <= '0;
    b2_ddrrd_cid_win_ff   <= '0;
    b2_evesnd_enb_win_ff  <= '0;
  end else begin
    b2_ddrrd_gnt_anych_ff <= b1_ddrrd_gnt_anych;
    b2_ddrrd_nxtrp_win_ff <= b1_ddrrd_nxtrp_win;
    b2_ddrrd_len_win_ff   <= b1_ddrrd_len_win;
    b2_ddrrd_rp_win_ff    <= b1_ddrrd_rp_win;
    b2_ddrrd_cid_win_ff   <= b1_ddrrd_cid_win;
    b2_evesnd_enb_win_ff  <= b1_evesnd_enb_win;
  end
end

assign b0_ddrrd_req_anych = | b0_ddrrd_req;

//// ddr read stm
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b0_ddrrd_stm_ff <= IDLE;
  end else begin
    case(b0_ddrrd_stm_ff)
      IDLE: begin
        if(b0_ddrrd_req_anych) begin
          b0_ddrrd_stm_ff <= DDRRD;
        end else begin
          b0_ddrrd_stm_ff <= IDLE;
        end
      end
      DDRRD: begin
        if(m_axi_cu_arready & b2_arvalid_ff) begin
          if(b0_ddrrd_buf1_sbd_free_ge2) begin
            b0_ddrrd_stm_ff <= IDLE;
          end else begin
            b0_ddrrd_stm_ff <= RDWAIT;
          end
        end else begin
          b0_ddrrd_stm_ff <= DDRRD;
        end
      end
      RDWAIT: begin
        if(b0_ddrrd_buf1_sbd_free_ge2) begin
          b0_ddrrd_stm_ff <= IDLE;
        end else begin
          b0_ddrrd_stm_ff <= RDWAIT;
        end
      end
    endcase
  end
end

////////////////////////////////////////////////
// (6) DDR Read Signal Generation
////////////////////////////////////////////////
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b2_arvalid_ff <= 1'b0;
    b2_araddr_ff  <= 32'h00000;
    b2_arlen_ff   <= 8'h00;
    b2_arcid_ff   <= 'b0;
  end else begin
    if(~m_axi_cu_arready & b2_arvalid_ff)begin
      b2_arvalid_ff <= b2_arvalid_ff;
      b2_araddr_ff  <= b2_araddr_ff;
      b2_arlen_ff   <= b2_arlen_ff;
      b2_arcid_ff   <= b2_arcid_ff;
    end else if((b0_ddrrd_stm_ff==DDRRD)&b1_ddrrd_gnt_anych) begin
      b2_arvalid_ff <= 1'b1;
      case (cif_up_tx_ddr_size)
        3'h0    : b2_araddr_ff <= (cif_up_tx_base_dn_ff + (32'h0100000 * b1_ddrrd_cid_win) + {12'b0, b1_ddrrd_rp_win[19:6], 6'h0});
        3'h1    : b2_araddr_ff <= (cif_up_tx_base_dn_ff + (32'h0200000 * b1_ddrrd_cid_win) + {11'b0, b1_ddrrd_rp_win[20:6], 6'h0});
        3'h2    : b2_araddr_ff <= (cif_up_tx_base_dn_ff + (32'h0400000 * b1_ddrrd_cid_win) + {10'b0, b1_ddrrd_rp_win[21:6], 6'h0});
        3'h3    : b2_araddr_ff <= (cif_up_tx_base_dn_ff + (32'h0800000 * b1_ddrrd_cid_win) + { 9'b0, b1_ddrrd_rp_win[22:6], 6'h0});
        3'h4    : b2_araddr_ff <= (cif_up_tx_base_dn_ff + (32'h1000000 * b1_ddrrd_cid_win) + { 8'b0, b1_ddrrd_rp_win[23:6], 6'h0});
        3'h5    : b2_araddr_ff <= (cif_up_tx_base_dn_ff + (32'h2000000 * b1_ddrrd_cid_win) + { 7'b0, b1_ddrrd_rp_win[24:6], 6'h0});
        3'h6    : b2_araddr_ff <= (cif_up_tx_base_dn_ff + (32'h0010000 * b1_ddrrd_cid_win) + {16'b0, b1_ddrrd_rp_win[15:6], 6'h0});
        3'h7    : b2_araddr_ff <= (cif_up_tx_base_dn_ff + (32'h0020000 * b1_ddrrd_cid_win) + {15'b0, b1_ddrrd_rp_win[16:6], 6'h0});
        default : b2_araddr_ff <= (cif_up_tx_base_dn_ff + (32'h0100000 * b1_ddrrd_cid_win) + {12'b0, b1_ddrrd_rp_win[19:6], 6'h0});
      endcase
      //b2_arlen_ff   <= {3'h0, b1_ddrrd_len_win[10:6]} + {7'h00, (b1_ddrrd_len_win[5:0]>0)} - 8'h01;
      // Always b1_ddrrd_len_win[5:0] = 0
      b2_arlen_ff   <= {3'h0, b1_ddrrd_len_win[10:6]} - 8'h01;
      b2_arcid_ff   <= b1_ddrrd_cid_win;
    end else begin
      b2_arvalid_ff <= 1'b0;
      b2_araddr_ff  <= 32'h00000;
      b2_arlen_ff   <= 8'h00;
      b2_arcid_ff   <= 'b0;
    end
  end
end

// DDR-reads
assign m_axi_cu_araddr   = {cif_up_tx_base_up_ff, b2_araddr_ff};
assign m_axi_cu_arlen    = b2_arlen_ff;
assign m_axi_cu_arsize   = 3'b110;  // 64Byte
assign m_axi_cu_arburst  = 2'b01;   // INCR
assign m_axi_cu_arlock   = 1'b0;
assign m_axi_cu_arcache  = 4'h0;
assign m_axi_cu_arprot   = 3'h0;
assign m_axi_cu_arqos    = 4'h0;
assign m_axi_cu_arregion = 4'h0;
assign m_axi_cu_arvalid  = b2_arvalid_ff;
assign m_axi_cu_rready   = 1'b1;

// DDR-writes (unused output: 0-clip)
assign m_axi_cu_awvalid  = 'b0;
// m_axi_cu_awready
assign m_axi_cu_awaddr   = 'b0;
assign m_axi_cu_awlen    = 'b0;
assign m_axi_cu_awsize   = 'b0;
assign m_axi_cu_awburst  = 'b0;
assign m_axi_cu_awlock   = 'b0;
assign m_axi_cu_awcache  = 'b0;
assign m_axi_cu_awprot   = 'b0;
assign m_axi_cu_awqos    = 'b0;
assign m_axi_cu_awregion = 'b0;
assign m_axi_cu_wvalid   = 'b0;
// m_axi_cu_wready
assign m_axi_cu_wdata    = 'b0;
assign m_axi_cu_wstrb    = 'b0;
assign m_axi_cu_wlast    = 'b0;
// m_axi_cu_bvalid
assign m_axi_cu_bready   = 'b0;
// m_axassigni_cu_bresp

////////////////////////////////////////////////
// (10) eve transmission control
////////////////////////////////////////////////
// buf1_sdb_rpeve: The next buf1 sideband entry to send eve.
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b3_buf1_sdb_rpeve_ff <= 'b0;
    b4_eve_val_ff        <= 'b0;
    b4_eve_cid_ff        <= 'b0;
    b4_eve_tx_ddr_rp_ff  <= 'b0;
    b4_evesnd_enb_ff     <= 'b0;
    for(int i=0; i<CH_NUM; i++) begin
      b5_ddrrd_rp_ff[i]  <= 'b0;
    end
  end else begin
    for(int i=0; i<CH_NUM; i++) begin
      if(txch_clr_t1_ff[i]) begin
        b5_ddrrd_rp_ff[i] <= 'b0;
      end
    end
    if(b3_buf1_rcv_flg_ff[b3_buf1_sdb_rpeve_ff] & ~b3_buf1_evesnd_flg_ff[b3_buf1_sdb_rpeve_ff]) begin
      b4_eve_val_ff       <= 1'b1;
      b4_eve_cid_ff       <= b3_buf1_cid_ff[b3_buf1_sdb_rpeve_ff];
      b4_eve_tx_ddr_rp_ff <= b3_buf1_nxt_ddrrd_rp_ff[b3_buf1_sdb_rpeve_ff];
      b4_evesnd_enb_ff    <= b3_buf1_evesnd_enb_ff[b3_buf1_sdb_rpeve_ff];
    end else if (eve_ready & eve_valid) begin
      b4_eve_val_ff        <= 1'b0;
      b3_buf1_sdb_rpeve_ff <= b3_buf1_sdb_rpeve_ff + 1'b1;
      for(int i=0; i<CH_NUM; i++) begin
        if(b4_eve_cid_ff==i) begin
          b5_ddrrd_rp_ff[i]  <= b4_eve_tx_ddr_rp_ff;
        end
      end
    end
  end
end

assign b4_eve_tx_ddr_rp_mod = b4_evesnd_enb_ff ? b4_eve_tx_ddr_rp_ff - eve_wait_value : 32'b0;

always_comb begin
  eve_valid = b4_eve_val_ff;

  eve_data =
    {cif_up_tx_base_dn_ff[31:0],
     ({{16-CH_NUM_W{1'b0}}, b4_eve_cid_ff} | (CHAIN_ID<<CH_NUM_W)),
     16'h0080,
     b4_eve_tx_ddr_rp_mod[31:0],
     32'h00000000};
end

////////////////////////////////////////////////
// (7) BUF1 wp control
////////////////////////////////////////////////
// The most significant bit is for wrap around detection.
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    c0_buf1_wp_ff <= 'b0;
  end else begin
    if(m_axi_cu_rvalid) begin
      c0_buf1_wp_ff <= c0_buf1_wp_ff + 1;
    end
  end
end

// buf1_wp_rsv: wp referenced to control DDR read.
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b2_buf1_wp_rsv_ff <= 'b0;
  end else begin
    if((b0_ddrrd_stm_ff==DDRRD) & b1_ddrrd_gnt_anych) begin
      b2_buf1_wp_rsv_ff <= b2_buf1_wp_rsv_ff + {{BUF1_AD_W-4{1'b0}},b1_ddrrd_len_win[10:6]};
    end
  end
end

////////////////////////////////////////////////
// (9) BUF1 sideband queue
////////////////////////////////////////////////
// buf1_sdb_wpreq: buf1 sideband entry to write when issuing ddr-rd request
// buf1_sdb_wprcv: buf1 sideband entry to write when receiving data
assign b2_buf1_sdb_wt =(b0_ddrrd_stm_ff==DDRRD) & b2_ddrrd_gnt_anych_ff;
assign b3_evesnd_anych = b3_buf1_rcv_flg_ff[b3_buf1_sdb_rpeve_ff] &
                        ~b3_buf1_evesnd_flg_ff[b3_buf1_sdb_rpeve_ff];

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b1_buf1_sdb_wpreq_ff <= 'b0;
    b1_buf1_sdb_wprcv_ff <= 'b0;

    for(int i=0; i<BUF1_SDB_NUM; i++) begin
      b3_buf1_cid_ff[i]          <= 'b0;
      b3_buf1_nxt_ddrrd_rp_ff[i] <= 'b0;
      b3_buf1_rcv_flg_ff[i]      <= 'b0;
      b3_buf1_evesnd_flg_ff[i]   <= 'b0;
      b3_buf1_evesnd_enb_ff[i]   <= 'b0;
    end
  end else begin
    for(int i=0; i<BUF1_SDB_NUM; i++) begin
      if(i==b1_buf1_sdb_wpreq_ff) begin
        if(b2_buf1_sdb_wt) begin
          b1_buf1_sdb_wpreq_ff       <= b1_buf1_sdb_wpreq_ff + 1'b1;
          b3_buf1_cid_ff[i]          <= b2_ddrrd_cid_win_ff;
          b3_buf1_nxt_ddrrd_rp_ff[i] <= b2_ddrrd_nxtrp_win_ff;
          b3_buf1_rcv_flg_ff[i]      <= 1'b0;
          b3_buf1_evesnd_flg_ff[i]   <= 1'b0;
          b3_buf1_evesnd_enb_ff[i]   <= b2_evesnd_enb_win_ff;
        end
      end

      if(i==b1_buf1_sdb_wprcv_ff) begin
        if(m_axi_cu_rvalid & m_axi_cu_rlast & (m_axi_cu_rresp==2'b00)) begin
          b3_buf1_rcv_flg_ff[i] <= 1'b1;
          b1_buf1_sdb_wprcv_ff  <= b1_buf1_sdb_wprcv_ff + 'b1;
        end
      end

      if(i==b3_buf1_sdb_rpeve_ff) begin
        if(eve_ready | ~eve_valid) begin
          if(b3_evesnd_anych) begin
            b3_buf1_evesnd_flg_ff[i] <= 1'b1;
          end
        end
      end

    end
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sdb0_dtsize                      <= '0;
    for(int i=0; i<CH_NUM; i++) begin
      sdb0_dtsize_chx[i]             <= '0;
    end
  end else if(eve_ready & eve_valid) begin
    if(b2_buf1_sdb_wt) begin
      if(b2_ddrrd_cid_win_ff != b4_eve_cid_ff) begin
        for(int i=0; i<CH_NUM; i++) begin
          if(b4_eve_cid_ff == i) begin
            sdb0_dtsize_chx[i] <=  sdb0_dtsize_chx[i] - 1;
          end
          if(b2_ddrrd_cid_win_ff == i) begin
            sdb0_dtsize_chx[i] <=  sdb0_dtsize_chx[i] + 1;
          end
        end
      end
    end else begin
      sdb0_dtsize            <= sdb0_dtsize - 1;
      for(int i=0; i<CH_NUM; i++) begin
        if(b4_eve_cid_ff == i) begin
          sdb0_dtsize_chx[i] <=  sdb0_dtsize_chx[i] - 1;
        end
      end
    end
  end else if(b2_buf1_sdb_wt) begin
    sdb0_dtsize            <= sdb0_dtsize + 1;
    for(int i=0; i<CH_NUM; i++) begin
        if(b2_ddrrd_cid_win_ff == i) begin
          sdb0_dtsize_chx[i] <=  sdb0_dtsize_chx[i] + 1;
        end
    end
  end
end

//---------------------------------------------------------------
// SDB of reference of D0 cycle
//---------------------------------------------------------------

assign d0_buf1_sdb_cid_ff         [BUF1_SDB_NUM] = '0;
assign d0_buf1_sdb_ddrrd_rp_ff    [BUF1_SDB_NUM] = '0;
assign d0_buf1_sdb_nxt_ddrrd_rp_ff[BUF1_SDB_NUM] = '0;
assign d0_buf1_sdb_pkt_len_ff     [BUF1_SDB_NUM] = '0;

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sdb1_dtsize                    <= '0;
    d0_buf1_sdb_rpsnd_ff           <= '0;
    for(int i=0; i<BUF1_SDB_NUM; i++) begin
      d0_buf1_sdb_cid_ff[i]           <= '0;
      d0_buf1_sdb_ddrrd_rp_ff[i]      <= '0;
      d0_buf1_sdb_nxt_ddrrd_rp_ff[i]  <= '0;
      d0_buf1_sdb_pkt_len_ff[i]       <= '0;
    end
  end else if(d0_pkt_eop) begin
    d0_buf1_sdb_rpsnd_ff           <= d0_buf1_sdb_rpsnd_ff + 1;
    if(~b2_buf1_sdb_wt) begin
      sdb1_dtsize                  <= sdb1_dtsize - 1;
    end
    for(int i=0; i<BUF1_SDB_NUM; i++) begin
      if(b2_buf1_sdb_wt && (i==sdb1_dtsize-1)) begin
        d0_buf1_sdb_cid_ff[i]           <= b2_ddrrd_cid_win_ff;
        d0_buf1_sdb_ddrrd_rp_ff[i]      <= b2_ddrrd_rp_win_ff[5:0];
        d0_buf1_sdb_nxt_ddrrd_rp_ff[i]  <= b2_ddrrd_nxtrp_win_ff[5:0];
        d0_buf1_sdb_pkt_len_ff[i]       <= b2_ddrrd_len_win_ff[10:6];
      end else begin
        d0_buf1_sdb_cid_ff[i]           <= d0_buf1_sdb_cid_ff[i+1];
        d0_buf1_sdb_ddrrd_rp_ff[i]      <= d0_buf1_sdb_ddrrd_rp_ff[i+1];
        d0_buf1_sdb_nxt_ddrrd_rp_ff[i]  <= d0_buf1_sdb_nxt_ddrrd_rp_ff[i+1];
        d0_buf1_sdb_pkt_len_ff[i]       <= d0_buf1_sdb_pkt_len_ff[i+1];
      end
    end
  end else begin
    if(b2_buf1_sdb_wt) begin
      sdb1_dtsize                <= sdb1_dtsize + 1;
      d0_buf1_sdb_cid_ff[sdb1_dtsize]          <= b2_ddrrd_cid_win_ff;
      d0_buf1_sdb_ddrrd_rp_ff[sdb1_dtsize]     <= b2_ddrrd_rp_win_ff[5:0];
      d0_buf1_sdb_nxt_ddrrd_rp_ff[sdb1_dtsize] <= b2_ddrrd_nxtrp_win_ff[5:0];
      d0_buf1_sdb_pkt_len_ff[sdb1_dtsize]      <= b2_ddrrd_len_win_ff[10:6];
    end
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    for(int i=0; i<CH_NUM; i++) begin
      sdb1_dtsize_chx[i]             <= '0;
    end
    sdb0_dtfull_hld                  <= '0;
    sdb0_dtovfl_hld                  <= '0;
    sdb1_dtfull_hld                  <= '0;
    sdb1_dtovfl_hld                  <= '0;
    buf1_dtfull_hld                  <= '0;
    buf1_dtovfl_hld                  <= '0;
    buf2_dtfull_hld                  <= '0;
    buf2_dtovfl_hld                  <= '0;
  end else begin
    if(d0_pkt_eop) begin
      if(b2_buf1_sdb_wt) begin
        if(b2_ddrrd_cid_win_ff != d0_buf1_sdb_cid_ff[0]) begin
          for(int i=0; i<CH_NUM; i++) begin
            if(d0_buf1_sdb_cid_ff[0] == i) begin
              sdb1_dtsize_chx[i] <=  sdb1_dtsize_chx[i] - 1;
            end
            if(b2_ddrrd_cid_win_ff == i) begin
              sdb1_dtsize_chx[i] <=  sdb1_dtsize_chx[i] + 1;
            end
          end
        end
      end else begin
        for(int i=0; i<CH_NUM; i++) begin
          if(d0_buf1_sdb_cid_ff[0] == i) begin
            sdb1_dtsize_chx[i] <=  sdb1_dtsize_chx[i] - 1;
          end
        end
      end
    end else if(b2_buf1_sdb_wt) begin
      for(int i=0; i<CH_NUM; i++) begin
          if(b2_ddrrd_cid_win_ff == i) begin
            sdb1_dtsize_chx[i] <=  sdb1_dtsize_chx[i] + 1;
          end
      end
    end
    if(sdb0_dtfull) begin
      sdb0_dtfull_hld <= 1'b1;
    end
    if(sdb0_dtovfl) begin
      sdb0_dtovfl_hld <= 1'b1;
    end
    if(sdb1_dtfull) begin
      sdb1_dtfull_hld <= 1'b1;
    end
    if(sdb1_dtovfl) begin
      sdb1_dtovfl_hld <= 1'b1;
    end
    if(buf1_dtfull) begin
      buf1_dtfull_hld <= 1'b1;
    end
    if(buf1_dtovfl) begin
      buf1_dtovfl_hld <= 1'b1;
    end
    if(|buf2_dtfull) begin
      buf2_dtfull_hld <= 1'b1;
    end
    if(|buf2_dtovfl) begin
      buf2_dtovfl_hld <= 1'b1;
    end
  end
end

// b0_ddrrd_buf1_sbd_free_ge2: more than 2 free entries in sideband queue on BUF1
assign b0_ddrrd_buf1_sbd_free_ge2 = (sdb0_dtsize < (BUF1_SDB_NUM-1)) & (sdb1_dtsize < (BUF1_SDB_NUM-1));
assign sdb0_dtfull                = sdb0_dtsize[BUF1_SDB_AD_W] & (sdb0_dtsize[BUF1_SDB_AD_W-1:0] == 0);
assign sdb1_dtfull                = sdb1_dtsize[BUF1_SDB_AD_W] & (sdb1_dtsize[BUF1_SDB_AD_W-1:0] == 0);
assign sdb0_dtovfl                = sdb0_dtsize[BUF1_SDB_AD_W] & (sdb0_dtsize[BUF1_SDB_AD_W-1:0]  > 0);
assign sdb1_dtovfl                = sdb1_dtsize[BUF1_SDB_AD_W] & (sdb1_dtsize[BUF1_SDB_AD_W-1:0]  > 0);

////////////////////////////////////////////////
// (11) BUF1 rp control/read control
////////////////////////////////////////////////

//---------------------------------------------------------------
// D0 cycle : buf1 read control
//---------------------------------------------------------------

always_comb begin
  d0_cid_vec       = '0;
  buf2_space_gt_6w = '0;
  for(int i=0; i<CH_NUM; i++) begin
    if(d0_buf1_sdb_cid_ff[0]==i) begin
      d0_cid_vec[i]    = '1;
      buf2_space_gt_6w = buf2_space_gt_6w_ff[i];
    end
  end
end

assign d0_buf1_dt_exist  = (buf1_dtsize_ff != 0);
assign d0_buf1_re        = ~d0_buf1_rd_inh &  d0_buf1_dt_exist & buf2_space_gt_6w ;
assign d0_valid          =  d0_buf1_rd_inh | (d0_buf1_dt_exist & buf2_space_gt_6w);
assign d0_buf1rd_cid     = d0_buf1_sdb_cid_ff[0];

assign d0_buf1_sdb_pkt_len_eq64 = (d0_buf1_sdb_pkt_len_ff[0] == 1);
assign d0_pkt_remlen_gt64   = (d0_pkt_remlen_ff > 64);
assign d0_tmp_len0 = {d0_buf1_sdb_pkt_len_ff[0],6'b0} - 64 + d0_buf1_sdb_nxt_ddrrd_rp_ff[0] - ((d0_buf1_sdb_nxt_ddrrd_rp_ff[0]==0)?0:64);
assign d0_tmp_len1 = d0_pkt_remlen_ff - 64;
assign d0_tmp_len2 = ((d0_buf1_sdb_nxt_ddrrd_rp_ff[0]==0) ? 7'h40 : {1'b0,d0_buf1_sdb_nxt_ddrrd_rp_ff[0]}) - d0_buf1_sdb_ddrrd_rp_ff[0];
assign d0_tmp_len3 = {d0_buf1_sdb_pkt_len_ff[0],6'b0} - d0_buf1_sdb_ddrrd_rp_ff[0] - 64 + d0_buf1_sdb_nxt_ddrrd_rp_ff[0];
assign d0_tmp_len4 = d1_pkt_remlen_ff - d1_frm_remlen[5:0];
assign d0_tmp_rp   = d1_pkt_remlen_lt64 ? 6'b0 : d1_frm_remlen[5:0];

always_comb begin
  case({d0_buf1_rd_inh, d0_buf1_re, d0_pkt_snd_busy_ff, d0_buf1_sdb_pkt_len_eq64, d0_pkt_remlen_gt64}) inside
//                       st    dm1_bsy             dm1_pkt_remlen     d0_cid         d0_ddrrd_rp                 d0_pkt_remlen     d0_eop
//---------------------------------------------------------------------------------------------------------------------------------------
    5'b0101? : d0_tmp = {4'h1, 1'b0,               11'b0,             d0_cid_vec,    d0_buf1_sdb_ddrrd_rp_ff[0], d0_tmp_len2     , 1'b1};
    5'b0100? : d0_tmp = {4'h2, 1'b1,               d0_tmp_len0,       d0_cid_vec,    d0_buf1_sdb_ddrrd_rp_ff[0], d0_tmp_len3     , 1'b0};
    5'b011?0 : d0_tmp = {4'h3, 1'b0,               11'b0,             d1_cid_vec_ff, 6'b0,                       d0_pkt_remlen_ff, 1'b1};
    5'b011?1 : d0_tmp = {4'h4, d0_pkt_snd_busy_ff, d0_tmp_len1,       d1_cid_vec_ff, 6'b0,                       d0_pkt_remlen_ff, 1'b0};
    5'b1???? : d0_tmp = {4'h5, d0_pkt_snd_busy_ff, d0_pkt_remlen_ff,  d1_cid_vec_ff, d0_tmp_rp,                  d0_tmp_len4,      1'b0};
    default  : d0_tmp = {4'h0, d0_pkt_snd_busy_ff, d0_pkt_remlen_ff,  d1_cid_vec_ff, d1_buf1_sdb_ddrrd_rp_ff,    d0_pkt_remlen_ff, 1'b0};
  endcase
end         

assign d0_debug_st              = d0_tmp[33+CH_NUM:30+CH_NUM];
assign dm1_pkt_snd_busy_din     = d0_tmp[29+CH_NUM];
assign dm1_pkt_remlen_din       = d0_tmp[28+CH_NUM:18+CH_NUM];
assign d0_cid_vec_din           = d0_tmp[17+CH_NUM:18];
assign d0_buf1_sdb_ddrrd_rp_din = d0_tmp[17:12];
assign d0_pkt_remlen_din        = d0_tmp[11:1];
assign d0_pkt_eop               = d0_tmp[0];

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    d0_buf1_rp_ff           <= '0;
    d0_pkt_snd_busy_ff      <= '0;
    d0_pkt_remlen_ff        <= '0;
    d1_valid_ff             <= '0;
    d1_buf1_rd_inh_ff       <= '0;
    d1_cid_vec_ff           <= '0;
    d1_buf1_sdb_ddrrd_rp_ff <= '0;
    d1_pkt_remlen_ff        <= '0;
  end else begin
    if(d0_buf1_re) begin
      d0_buf1_rp_ff         <= d0_buf1_rp_ff + 1;
    end
    d0_pkt_snd_busy_ff      <= dm1_pkt_snd_busy_din;
    d0_pkt_remlen_ff        <= dm1_pkt_remlen_din;
    d1_valid_ff             <= d0_valid;
    d1_buf1_rd_inh_ff       <= d0_buf1_rd_inh;
    d1_cid_vec_ff           <= d0_cid_vec_din;
    d1_buf1_sdb_ddrrd_rp_ff <= d0_buf1_sdb_ddrrd_rp_din;
    d1_pkt_remlen_ff        <= d0_pkt_remlen_din;
  end
end

//---------------------------------------------------------------
// D1 cycle : WD control signal generation
//---------------------------------------------------------------

always_comb begin
  d1_frm_snd_busy = 0;
  for(int i=0; i<CH_NUM; i++) begin
    if(d1_cid_vec_ff[i]) begin
      d1_frm_snd_busy = d1_frm_snd_busy_ff[i];
    end
  end
end

assign d1_sftreg_len        = d1_sftreg_len_ff[CH_NUM];
assign d1_frm_remlen        = d1_frm_remlen_ff[CH_NUM];
assign d1_sftreg_frm_remlen = d1_sftreg_frm_remlen_ff[CH_NUM];

assign d1_buf1_sdb_ddrrd_rp_eq0  = (d1_buf1_sdb_ddrrd_rp_ff == 0);
assign d1_sftreg_len_eq0         = (d1_sftreg_len == 0);
assign d1_pkt_remlen_lt64        = (d1_pkt_remlen_ff < 64);
//assign d1_frm_remlen_lt64        = (d1_frm_remlen < 64);
assign d1_frm_remlen_lt64        = (~d1_frm_remlen_ge256_ff) && (d1_frm_remlen[7:0] < 64);
//assign d1_frm_remlen_eq64        = (d1_frm_remlen == 64);
assign d1_frm_remlen_eq64        = (~d1_frm_remlen_ge256_ff) && (d1_frm_remlen[7:0] == 64);
//assign d1_sftreg_frm_remlen_gt64 = ((d1_sftreg_len + d1_frm_remlen) > 64);
assign d1_sftreg_frm_remlen_gt64 = (d1_sftreg_frm_remlen > 64);
assign d1_tmp_len0               = { 1'b0,d1_buf1_sdb_ddrrd_rp_ff};
assign d1_tmp_len1               = d1_sftreg_len[5:0] + d1_frm_remlen[5:0] - 64;
assign d1_tmp_len2               = 64 - d1_buf1_sdb_ddrrd_rp_ff;
assign d1_tmp_len3               = 64 - d1_sftreg_len;
assign d1_tmp_len4               = d1_sftreg_len[5:0] + d1_frm_remlen[6:0];

always_comb begin
  case({d1_valid_ff,
        d1_buf1_rd_inh_ff,
        d1_buf1_sdb_ddrrd_rp_eq0,
        d1_sftreg_len_eq0,
        d1_pkt_remlen_lt64,
        d1_frm_remlen_lt64,
        d1_frm_remlen_eq64,
        d1_sftreg_frm_remlen_gt64}) inside
//                        st   d0_inh      cid       sftwe   sftlen     buf2we      rot           sel0            selr       sft_sof,sof,eof
//  ----------------------------------------------------------------------------------------------------------------------------------------------------
    8'b0??????? : d1_tmp = {4'h0, 1'b0, d2_cid_vec_ff, 1'b0,     7'h00,     1'b0,     7'h00,      7'h00,          7'h00,     1'b0,1'b0,1'b0};
    8'b10111??? : d1_tmp = {4'h1, 1'b0, d1_cid_vec_ff, 1'b0,     7'h00,     1'b1,     7'h00,   d1_tmp_len4,       7'h00,     1'b0,1'b0,1'b1};
    8'b1011000? : d1_tmp = {4'h2, 1'b0, d1_cid_vec_ff, 1'b0,     7'h00,     1'b1,     7'h00,      7'h40,          7'h00,     1'b0,~d1_frm_snd_busy,1'b0};
    8'b1011001? : d1_tmp = {4'h3, 1'b0, d1_cid_vec_ff, 1'b0,     7'h00,     1'b1,     7'h00,      7'h40,          7'h00,     1'b0,1'b0,1'b1};
    8'b101101?? : d1_tmp = {4'h4, 1'b1, d1_cid_vec_ff, 1'b0,     7'h00,     1'b1,     7'h00,   d1_tmp_len4,       7'h00,     1'b0,1'b0,1'b1};
    8'b10101??0 : d1_tmp = {4'h5, 1'b0, d1_cid_vec_ff, 1'b0,     7'h00,     1'b1, d1_tmp_len3, d1_tmp_len4,   d1_sftreg_len, 1'b0,1'b0,1'b1};
    8'b10101??1 : d1_tmp = {4'h6, 1'b1, d1_cid_vec_ff, 1'b1, d1_tmp_len1,   1'b1, d1_tmp_len3,    7'h40,      d1_sftreg_len, 1'b0,1'b0,1'b1};
    8'b1010000? : d1_tmp = {4'h7, 1'b0, d1_cid_vec_ff, 1'b1, d1_sftreg_len, 1'b1, d1_tmp_len3,    7'h40,      d1_sftreg_len, 1'b0,1'b0,1'b0};
    8'b1010001? : d1_tmp = {4'h8, 1'b1, d1_cid_vec_ff, 1'b1, d1_sftreg_len, 1'b1, d1_tmp_len3,    7'h40,      d1_sftreg_len, 1'b0,1'b0,1'b0};
    8'b101001?0 : d1_tmp = {4'h9, 1'b1, d1_cid_vec_ff, 1'b0,     7'h00,     1'b1, d1_tmp_len3, d1_tmp_len4,   d1_sftreg_len, 1'b0,1'b0,1'b1};
    8'b101001?1 : d1_tmp = {4'ha, 1'b1, d1_cid_vec_ff, 1'b1, d1_tmp_len1,   1'b1, d1_tmp_len3,    7'h40,      d1_sftreg_len, 1'b0,1'b0,1'b1};
    8'b1?01???? : d1_tmp = {4'hb, 1'b0, d1_cid_vec_ff, 1'b1, d1_tmp_len2,   1'b0, d1_tmp_len0,    7'h00,          7'h00,     1'b1,1'b0,1'b0};
    8'b1?00???? : d1_tmp = {4'hc, 1'b0, d1_cid_vec_ff, 1'b1, d1_tmp_len2,   1'b1, d1_tmp_len0, d1_sftreg_len, d1_sftreg_len, 1'b1,1'b0,1'b1};
    8'b111????? : d1_tmp = {4'hd, 1'b0, d1_cid_vec_ff, 1'b0,     7'h00,     1'b1,     7'h00,   d1_tmp_len4,   d1_sftreg_len, 1'b0,1'b0,1'b1};
    default   : d1_tmp = '0;
  endcase
end

assign d1_debug_st         = d1_tmp[37+CH_NUM:34+CH_NUM];
assign d0_buf1_rd_inh      = d1_tmp[33+CH_NUM];
assign d1_cid_vec_din      = d1_tmp[32+CH_NUM:33];
assign d1_sftreg_we_din    = d1_tmp[32];
assign d1_sftreg_len_din   = d1_tmp[31:25];
assign d1_buf2_we_din      = d1_tmp[24];
assign d1_buf1_rd_rot_din  = d1_tmp[23:17];
assign d1_buf2_wd_sel0_din = d1_tmp[16:10];
assign d1_buf2_wd_selr_din = d1_tmp[9:3];
assign d1_sftreg_set_sof   = d1_tmp[2];
assign d1_frm_sof          = d1_tmp[1];
assign d1_frm_eof          = d1_tmp[0];

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    d1_frm_snd_busy_ff    <= '0;
    for(int i=0; i<=CH_NUM; i++) begin
      d1_sftreg_len_ff[i]        <= '0;
      d1_frm_remlen_ff[i]        <= 33'h1_0000_0000;
      d1_sftreg_frm_remlen_ff[i] <= 33'h1_0000_0000;
    end 
    d1_frm_remlen_ge256_ff       <= 1'b1;
    d2_cid_vec_ff         <= '0;
    d2_sftreg_we_ff       <= '0;
    d2_buf2_we_ff         <= '0;
    d2_buf1_rd_rot_ff     <= '0;
    d2_buf2_wd_sel0_ff    <= '0;
    d2_buf2_wd_selr_ff    <= '0;
    d2_buf1_rddata_ff     <= '0;
    d2_sftreg_set_sof_ff  <= '0;
    d2_sftreg_set_len_ff  <= '0;
    d2_frm_sof_ff         <= '0;
  end else begin
    for(int i=0; i<=CH_NUM; i++) begin
      if(txch_clr_t1_ff[i]) begin
          d1_frm_snd_busy_ff[i]  <= '0;
      end else if(d1_cid_vec_ff[i]) begin
        if(d1_sftreg_set_sof || d1_frm_sof) begin
          d1_frm_snd_busy_ff[i]  <= '1;
        end else if(d1_frm_eof) begin
          d1_frm_snd_busy_ff[i]  <= '0;
        end
      end
    end

    for(int i=0; i<CH_NUM; i++) begin
      if(txch_clr_t1_ff[i]) begin
        d1_sftreg_len_ff[i]   <= '0;
      end else if(d1_valid_ff & d1_cid_vec_ff[i]) begin
        d1_sftreg_len_ff[i]   <= d1_sftreg_len_din;
      end
    end

    if(d1_valid_ff && (|(d0_cid_vec_din & d1_cid_vec_ff))) begin
        d1_sftreg_len_ff[CH_NUM]   <= d1_sftreg_len_din;
    end else begin
      for(int i=0; i<CH_NUM; i++) begin
        if(d0_valid && d0_cid_vec_din[i]) begin
          d1_sftreg_len_ff[CH_NUM]   <= d1_sftreg_len_ff[i];
        end
      end
    end

    for(int i=0; i<CH_NUM; i++) begin
      if(txch_clr_t1_ff[i]) begin
        d1_frm_remlen_ff[i]        <= 33'h1_0000_0000;
        d1_sftreg_frm_remlen_ff[i] <= 33'h1_0000_0000;
      end else if(d4_frm_sof_we_ff && d4_cid_vec_ff[i]) begin
        d1_frm_remlen_ff[i]        <= {1'b0,d4_set_d0_frm_remlen};
        d1_sftreg_frm_remlen_ff[i] <= {1'b0,d4_set_d0_sftreg_frm_remlen};
      end else if(d1_valid_ff && d1_frm_eof && d1_cid_vec_ff[i]) begin
        d1_frm_remlen_ff[i]        <= 33'h1_0000_0000;
        d1_sftreg_frm_remlen_ff[i] <= 33'h1_0000_0000;
      end else if(d1_valid_ff && (~d1_frm_remlen_ff[i][32]) && d1_cid_vec_ff[i]) begin
        d1_frm_remlen_ff[i][31:0]        <= d1_frm_remlen_ff[i][31:0] - 64;
        d1_sftreg_frm_remlen_ff[i][31:0] <= d1_sftreg_frm_remlen_ff[i][31:0] - 64;
      end
    end

    if(d4_frm_sof_we_ff && (|(d4_cid_vec_ff & d0_cid_vec_din))) begin
      d1_frm_remlen_ff[CH_NUM]        <= {1'b0,d4_set_d0_frm_remlen};
      d1_sftreg_frm_remlen_ff[CH_NUM] <= {1'b0,d4_set_d0_sftreg_frm_remlen};
      d1_frm_remlen_ge256_ff          <= 1'b1; 					// frm>1KB limit, so always 1 when set
    end else if(d1_valid_ff && ((|(d1_cid_vec_ff & d0_cid_vec_din)))) begin
      if(d1_frm_eof) begin
        d1_frm_remlen_ff[CH_NUM]        <= 33'h1_0000_0000;
        d1_sftreg_frm_remlen_ff[CH_NUM] <= 33'h1_0000_0000;
        d1_frm_remlen_ge256_ff          <= 1'b1;
      end else if(~d1_frm_remlen_ff[CH_NUM][32]) begin
        d1_frm_remlen_ff[CH_NUM][31:0]        <= d1_frm_remlen_ff[CH_NUM][31:0] - 64;
        d1_sftreg_frm_remlen_ff[CH_NUM][31:0] <= d1_sftreg_frm_remlen_ff[CH_NUM][31:0] - 64;
        d1_frm_remlen_ge256_ff                <= |d1_sftreg_frm_remlen_ff[CH_NUM][32:8];	// 1 when >=192B
      end
    end else begin
      for(int i=0; i<CH_NUM; i++) begin
        if(d0_valid && d0_cid_vec_din[i]) begin
          d1_frm_remlen_ff[CH_NUM]        <= d1_frm_remlen_ff[i];
          d1_sftreg_frm_remlen_ff[CH_NUM] <= d1_sftreg_frm_remlen_ff[i];
          d1_frm_remlen_ge256_ff          <= |d1_sftreg_frm_remlen_ff[i][32:8];
        end
      end
    end

    d2_cid_vec_ff         <= d1_cid_vec_din;
    d2_sftreg_we_ff       <= d1_sftreg_we_din;
    d2_buf2_we_ff         <= d1_buf2_we_din;
    d2_buf1_rd_rot_ff     <= d1_buf1_rd_rot_din;
    d2_buf2_wd_sel0_ff    <= d1_buf2_wd_sel0_din;
    d2_buf2_wd_selr_ff    <= d1_buf2_wd_selr_din;
    d2_sftreg_set_sof_ff  <= d1_sftreg_set_sof;
    d2_sftreg_set_len_ff  <= d1_sftreg_len_din;
    d2_frm_sof_ff         <= d1_frm_sof;

    if(d1_valid_ff & (~d1_buf1_rd_inh_ff)) begin
      d2_buf1_rddata_ff     <= d1_buf1_rddata;
    end
  end
end

//---------------------------------------------------------------
// D2 cycle : buf1 rd rotation
//---------------------------------------------------------------

assign d2_buf1_rd_tmp = {d2_buf1_rddata_ff,d2_buf1_rddata_ff};

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    d3_cid_vec_ff         <= '0;
    d3_sftreg_we_ff       <= '0;
    d3_buf2_we_ff         <= '0;
    d3_buf1_rddata_rot_ff <= '0;
    d3_buf2_wd_sel0_ff    <= '0;
    d3_buf2_wd_selr_ff    <= '0;
    d3_sftreg_set_sof_ff  <= '0;
    d3_sftreg_set_len_ff  <= '0;
    d3_frm_sof_ff         <= '0;

  end else begin
    d3_cid_vec_ff         <= d2_cid_vec_ff;
    d3_sftreg_we_ff       <= d2_sftreg_we_ff;
    d3_buf2_we_ff         <= d2_buf2_we_ff;
    d3_buf1_rddata_rot_ff <= d2_buf1_rd_tmp[d2_buf1_rd_rot_ff*8 +:512];
    d3_buf2_wd_sel0_ff    <= d2_buf2_wd_sel0_ff;
    d3_buf2_wd_selr_ff    <= d2_buf2_wd_selr_ff;
    d3_sftreg_set_sof_ff  <= d2_sftreg_set_sof_ff;
    d3_sftreg_set_len_ff  <= d2_sftreg_set_len_ff;
    d3_frm_sof_ff         <= d2_frm_sof_ff;
  end
end

//---------------------------------------------------------------
// D3 cycle : buf2_wd generation
//---------------------------------------------------------------

always_comb begin
  d3_sftreg_dt  = '0;
  d3_sftreg_sof = '0;
  for(int i=0; i<CH_NUM; i++) begin
    if(d3_cid_vec_ff[i]) begin
      d3_sftreg_dt  = d3_sftreg_dt_ff[i];
      d3_sftreg_sof = d3_sftreg_sof_ff[i];
    end
  end
end

always_comb begin
  d3_buf2_wd = '0;
  for(int i=63; i>=0; i--) begin
   if         (i >= d3_buf2_wd_sel0_ff) begin
     d3_buf2_wd[i*8 +:8] = '0;
   end else if(i >= d3_buf2_wd_selr_ff) begin
     d3_buf2_wd[i*8 +:8] = d3_buf1_rddata_rot_ff[i*8 +:8];
   end else begin
     d3_buf2_wd[i*8 +:8] = d3_sftreg_dt[i*8 +:8];
   end
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    for(int i=0; i<CH_NUM; i++) begin
      d3_sftreg_dt_ff[i]    <= '0;
      d3_sftreg_sof_ff[i]   <= '0;
      buf2_space_gt_6w_ff[i]<= '0;
    end
  end else begin
    for(int i=0; i<CH_NUM; i++) begin
      if(txch_clr_t1_ff[i]) begin
          d3_sftreg_sof_ff[i]  <= '0;
      end else if(d3_cid_vec_ff[i]) begin
        if(d3_sftreg_we_ff) begin
          d3_sftreg_dt_ff[i]   <= d3_buf1_rddata_rot_ff;
          d3_sftreg_sof_ff[i]  <= d3_sftreg_set_sof_ff;
        end else if(d3_buf2_we_ff) begin
          d3_sftreg_sof_ff[i]  <= '0;
        end
      end
      buf2_space_gt_6w_ff[i] <= ((6'h20-6'h06) > (d4_buf2_wp_ff[i] - e1_buf2_rp_ff[i]));
    end
  end
end

assign d3_frm_sof_we = d3_buf2_we_ff && (d3_frm_sof_ff || d3_sftreg_sof);

always_comb begin
  d4_cid        = '0;
  d4_buf2_wp    = '0;
  for(int i=0; i<CH_NUM; i++) begin
    if(d4_cid_vec_ff[i]) begin
      d4_cid        = i;
      d4_buf2_wp    = d4_buf2_wp_ff[i];
    end
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    d4_frm_sof_we_ff      <= '0;
    d4_cid_vec_ff         <= '0;
    d4_sftreg_set_len_ff  <= '0;
    d4_frm_marker_ff      <= '0;
    d4_frm_payload_len_ff <= '0;
    d4_frm_header_w2_ff   <= '0;
    d4_frm_header_w3_ff   <= '0;
    d4_buf2_we_ff         <= '0;
    d4_buf2_wd_ff         <= '0;
    for(int i=0; i<CH_NUM; i++) begin
      d4_frm_frame_cnt_ff[i]              <= '0;
      d4_payload_len_for_marker_err_ff[i] <= '0;
      d4_buf2_wp_ff[i]      <= '0;
      d4_buf2_we_inh_ff[i]  <= '0;
    end
  end else begin
    d4_frm_sof_we_ff      <= d3_frm_sof_we;
    d4_cid_vec_ff         <= d3_cid_vec_ff;
    d4_sftreg_set_len_ff  <= d3_sftreg_set_len_ff;
    d4_frm_marker_ff      <= d3_buf2_wd[31:0];
    d4_frm_payload_len_ff <= d3_buf2_wd[63:32];
    d4_frm_header_w2_ff   <= d3_buf2_wd[95:64];
    d4_frm_header_w3_ff   <= d3_buf2_wd[127:96];
    d4_buf2_we_ff         <= d3_buf2_we_ff;
    d4_buf2_wd_ff         <= d3_buf2_wd;
    for(int i=0; i<CH_NUM; i++) begin
      if(txch_clr_t1_ff[i]) begin
          d4_buf2_wp_ff[i]     <= '0;
          d4_buf2_we_inh_ff[i] <= '0;
      end else if(d4_cid_vec_ff[i]) begin
        if(d4_buf2_we_ff) begin
          if(d4_frm_marker_err || d4_frm_payload_err) begin
            d4_buf2_we_inh_ff[i] <= '1;
          end else if(~(at_me_main_mode ? d4_buf2_we_inh_or : d4_buf2_we_inh_ff[i])) begin
            d4_buf2_wp_ff[i]     <= d4_buf2_wp_ff[i] + 1;
          end
        end
      end
      if(d3_frm_sof_we && d3_cid_vec_ff[i] && (d4_frm_frame_cnt_ff[i] < 32'hffff_ffff)) begin
        d4_frm_frame_cnt_ff[i] <= d4_frm_frame_cnt_ff[i] + 32'h1;
      end
      if(d4_frm_sof_we_ff && d4_cid_vec_ff[i]) begin
        d4_payload_len_for_marker_err_ff[i] <= d4_frm_payload_len_ff;
      end
    end
  end
end

//---------------------------------------------------------------
// D4 cycle: HD check, nxt_frm_hd_ddrrp generation
//---------------------------------------------------------------

assign d4_frm_marker_err  = d4_frm_sof_we_ff && (d4_frm_marker_ff != MARKER);
assign d4_frm_payload_err = d4_frm_sof_we_ff && (d4_frm_payload_len_ff < (11'h400 - HD_SIZE));

always_comb begin
  d4_buf2_we_inh_or = 1'b0;
  for (int i = 0; i < CH_NUM; i++) begin
    d4_buf2_we_inh_or = d4_buf2_we_inh_or | d4_buf2_we_inh_ff[i];
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    for(int i=0; i<CH_NUM; i++) begin
      d5_nxt_frm_hd_ddrwp_ff[i] <= '0;
    end
    d5_frm_marker_err_cid_vec     <= '0;
    d5_frm_marker_err_cid_vec_acc <= '0;
    d5_frm_marker_err_payload_len <= '0;
    d5_frm_me_marker_ff           <= '0;
    d5_frm_me_payload_len_ff      <= '0;
    d5_frm_me_header_w2_ff        <= '0;
    d5_frm_me_header_w3_ff        <= '0;
    d5_frm_me_frame_cnt_ff        <= '0;
    d5_frm_me_frm_hd_ddrwp_ff     <= '0;
    d5_frm_me_ddr_wp_ff           <= '0;
    d5_frm_me_ddr_rp_ff           <= '0;
    d5_frm_me_buf1_wp_rp_ff       <= '0;
    d5_buf2_we_inh_or_ff          <= '0;
  end else begin
    for(int i=0; i<CH_NUM; i++) begin
      if(txch_clr_t1_ff[i]) begin
        d5_nxt_frm_hd_ddrwp_ff[i] <= '0;
      end
    end
    if(d4_frm_sof_we_ff) begin
      for(int i=0; i<CH_NUM; i++) begin
        if(d4_cid_vec_ff[i]) begin
          d5_nxt_frm_hd_ddrwp_ff[i] <= d5_nxt_frm_hd_ddrwp_ff[i] + d4_frm_payload_len_ff + HD_SIZE;
        end
      end
    end
    for(int i=0; i<CH_NUM; i++) begin
      if(d4_frm_marker_err & d4_cid_vec_ff[i]) begin
        if(d5_frm_marker_err_cid_vec == '0) begin
          d5_frm_marker_err_cid_vec     <= d4_cid_vec_ff;
          d5_frm_marker_err_payload_len <= d4_payload_len_for_marker_err_ff[i];
          d5_frm_me_marker_ff           <= d4_frm_marker_ff;
          d5_frm_me_payload_len_ff      <= d4_frm_payload_len_ff;
          d5_frm_me_header_w2_ff        <= d4_frm_header_w2_ff;
          d5_frm_me_header_w3_ff        <= d4_frm_header_w3_ff;
          d5_frm_me_frame_cnt_ff        <= d4_frm_frame_cnt_ff[i];
          d5_frm_me_frm_hd_ddrwp_ff     <= d5_nxt_frm_hd_ddrwp_ff[i];
          d5_frm_me_ddr_wp_ff           <= a0_tx_ddr_wp_ff[i][31:0];
          d5_frm_me_ddr_rp_ff           <= b1_ddrrd_rp_ff[i][31:0];
          d5_frm_me_buf1_wp_rp_ff       <= {{15-BUF1_AD_W{1'b0}}, d0_buf1_rp_ff, {16-BUF1_AD_W{1'b0}}, c0_buf1_wp_ff};
        end
        d5_frm_marker_err_cid_vec_acc   <= (d4_cid_vec_ff | d5_frm_marker_err_cid_vec_acc);
      end
    end
    d5_buf2_we_inh_or_ff <= d4_buf2_we_inh_or;
  end
end

assign d4_set_d0_frm_remlen_term1  = {d3_buf2_we_ff && (|(d3_cid_vec_ff & d4_cid_vec_ff))}
                                   + {d2_buf2_we_ff && (|(d2_cid_vec_ff & d4_cid_vec_ff))}
                                   + {d1_valid_ff   && (|(d1_cid_vec_ff & d4_cid_vec_ff))};
assign d4_set_d0_frm_remlen_term2  = {d4_set_d0_frm_remlen_term1,6'h10} + d4_sftreg_set_len_ff;
assign d4_set_d0_frm_remlen        = d4_frm_payload_len_ff - d4_set_d0_frm_remlen_term2;

assign d4_set_d0_sftreg_frm_remlen = d4_frm_payload_len_ff - {d4_set_d0_frm_remlen_term1,6'h10};

////////////////////////////////////////////////
// (8) cif_buf1 (BUF1)
////////////////////////////////////////////////
cif_buf1 cifu_buf1 (
  .clka  (user_clk),
  .ena   (m_axi_cu_rvalid),
  .wea   (m_axi_cu_rvalid),
  .addra (c0_buf1_wp_ff),
  .dina  (m_axi_cu_rdata),
  .clkb  (user_clk),
  .enb   (d0_buf1_re),
  .addrb (d0_buf1_rp_ff[BUF1_AD_W-1:0]),
  .doutb (d1_buf1_rddata)
);

////////////////////////////////////////////////
// (14) cif_buf2 (BUF2)
////////////////////////////////////////////////
// buf2 RAM
// Implemented all chain and ch RAMs together in order to reduce the volume.
// CIF_BUF is in 64byte units
//assign d2_buf2_we = d2_buf2_we_pre | d2_force_buf2_we_t1_ff;

cif_buf2 cifu_buf2 (
  .clka  (user_clk),
  .ena   (d4_buf2_we_ff),
  .wea   (d4_buf2_we_ff),
  .addra ({{4-CH_NUM_W{1'b0}},d4_cid,d4_buf2_wp[4:0]}),
  .dina  (d4_buf2_wd_ff),
  .clkb  (user_clk),
  .enb   (e1_buf2rd_re),
  .addrb ({{4-CH_NUM_W{1'b0}},e1_buf2rd_cid_win_hold,e1_buf2_rp_ff[e1_buf2rd_cid_win_hold][4:0]}),
  .doutb (e2_buf2rd_data)
);

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    e3_buf2rd_data_ff <= 'b0;
  end else if(c2d_axis_tready | ~c2d_axis_tvalid) begin
    e3_buf2rd_data_ff <= e2_buf2rd_data;
  end
end

//wire [5:0] dma_size_phase = o_dma_size[5:0] + 1'b1;
//always_ff @(posedge user_clk or negedge reset_n) begin
//  if (!reset_n) begin
//    o_dma_size <= 32'h0;
//  end else if (c2d_axis_tready | ~c2d_axis_tvalid) begin
//    if (e3_buf2rd_hd_ff & (buf2_1stfrm_word_ff==0) & e3_buf2rd_gnt_ff & e3_buf2rd_re_ff) begin
//      o_dma_size <= {e3_buf2rd_word, dma_size_phase};
//    end
//  end
//end


////////////////////////////////////////////////
// (15) BUF2 rp control/BUF2 read req generation
////////////////////////////////////////////////

always_comb begin
  for(int i=0; i<CH_NUM; i++) begin
    e1_buf2rd_re_chx[i] = e1_buf2rd_re & (e1_buf2rd_cid_win_hold == i);
    buf2_dtsize[i]  = d4_buf2_wp_ff[i][5:0] - e1_buf2_rp_ff[i][5:0];
    buf2_dtfull[i]  = buf2_dtsize[i][5] & (buf2_dtsize[i][4:0] == 0);
    buf2_dtfullm1[i]  = &buf2_dtsize[i][4:0];
    buf2_dtovfl[i]  = buf2_dtsize[i][5] & (buf2_dtsize[i][4:0]  > 0);
  end
end

// buf2_1stfrm_word: number of words to the next frame header
// buf2_1stfrm_word=0: RAM starts in frame header
always_ff @(posedge user_clk or negedge reset_n) begin
  for(int i=0; i<CH_NUM; i++) begin
    if(!reset_n) begin
      buf2_1stfrm_word_ff[i] <= 'b0;
      e4_frm_marker_err      <= 'b0;
    end else begin
      if(txch_clr_t1_ff[i]) begin
        buf2_1stfrm_word_ff[i] <= 'b0;
      end else if(c2d_axis_tready | ~c2d_axis_tvalid) begin
        // Update buf2_1stfrm_word from header information when reading fram header
        if(e3_buf2rd_hd_ff & (buf2_1stfrm_word_ff[i]==0) & e3_buf2rd_gnt_ff[i] & e3_buf2rd_re_ff) begin
          buf2_1stfrm_word_ff[i] <= e3_buf2rd_word - 32'h1 - {31'h0, e2_buf2rd_re_ff} - {31'h0, e1_buf2rd_re_chx[i]};
          if(~e4_frm_marker_err & (e3_buf2rd_data_ff[31:0] != MARKER)) begin
            e4_frm_marker_err <= 1'b1;
          end else begin
            e4_frm_marker_err <= 1'b0;
          end
        end else begin 
          if((buf2_1stfrm_word_ff[i]!=0) & e1_buf2rd_re_chx[i]) begin
            buf2_1stfrm_word_ff[i] <= buf2_1stfrm_word_ff[i] - 1;
          end
          e4_frm_marker_err <= 1'b0;
        end
      end
    end
  end
end

// buf2dt_ge_1kb=1: Valid data in buf2 is 1kB or more.
// buf2rd_hd: Next data read from buf2 is at the top of frame

always_ff @(posedge user_clk or negedge reset_n) begin
  for(int i=0; i<CH_NUM; i++) begin
    if(!reset_n) begin
      pkt_mode_ff[i] <= '0;
    end else begin
      pkt_mode_ff[i] <= c2d_pkt_mode[i];
    end
  end
end

always_comb begin
  for(int i=0; i<CH_NUM; i++) begin
    em1_buf2dt_ge_1kb[i]     = (buf2_dtsize[i]          >= 6'h10);
    em1_buf2dt_ge_1stfrmw[i] = ({26'h0,buf2_dtsize[i]}  >= buf2_1stfrm_word_ff[i]);
    em1_buf2dt_exist[i]      = (buf2_dtsize[i]          >  0);
    em1_1stfrmw_gt_1kb[i]    = (buf2_1stfrm_word_ff[i]  >  32'h10);
    em1_buf2rd_hd[i]         = (buf2_1stfrm_word_ff[i]  == 32'b0);

    case({rd_enb_t1_ff[i],
         (e0_buf2rd_req[i] | em1_buf2rd_req_inh[i]),
          em1_buf2dt_ge_1kb[i],
          em1_buf2dt_exist[i],
          em1_buf2rd_hd[i],
          em1_1stfrmw_gt_1kb[i],
          em1_buf2dt_ge_1stfrmw[i]}) inside
      7'b101?1??: begin
        em1_buf2rd_req[i]  = 1'b1;
        if((pkt_mode_ff[i][1:0]==2'h0) | (e1_buf2_rp_ff[i][3:0]==4'h0)) begin
          em1_buf2rd_len[i]  = 5'h10;
        end else begin
          em1_buf2rd_len[i]  = 5'h10 - {1'h0,e1_buf2_rp_ff[i][3:0]};
        end
        em1_buf2rd_last[i] = 1'b0;
      end
      7'b101?01?: begin
        em1_buf2rd_req[i]  = 1'b1;
        em1_buf2rd_len[i]  = 5'h10;
        em1_buf2rd_last[i] = 1'b0;
      end
      7'b101?00?: begin
        em1_buf2rd_req[i]  = 1'b1;
        em1_buf2rd_len[i]  = buf2_1stfrm_word_ff[i][4:0];
        em1_buf2rd_last[i] = 1'b1;
      end
      7'b1001001: begin
        em1_buf2rd_req[i]  = 1'b1;
        em1_buf2rd_len[i]  = buf2_1stfrm_word_ff[i][4:0];
        em1_buf2rd_last[i] = 1'b1;
      end
      default : begin
        em1_buf2rd_req[i]  = 1'b0;
        em1_buf2rd_len[i]  = 5'h00;
        em1_buf2rd_last[i] = 1'b0;
      end
    endcase
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  for(int i=0; i<CH_NUM; i++) begin
    if(!reset_n) begin
      em1_buf2rd_req_inh[i] <= '0;
      e0_buf2rd_req[i]      <= '0;
      e0_buf2rd_len[i]      <= '0;
      e0_buf2rd_last[i]     <= '0;
      e0_buf2rd_hd[i]       <= '0;
    end else if(em1_buf2rd_req[i]) begin
      e0_buf2rd_req[i]      <= '1;
      e0_buf2rd_len[i]      <= em1_buf2rd_len[i];
      e0_buf2rd_last[i]     <= em1_buf2rd_last[i];
      e0_buf2rd_hd[i]       <= em1_buf2rd_hd[i];
    end else if(e1_buf2rd_gnt[i]) begin
      e0_buf2rd_req[i]      <= '0;
      em1_buf2rd_req_inh[i] <= '1;
    end else if(em1_buf2rd_req_inh[i] & buf2rd_arbenb) begin
      em1_buf2rd_req_inh[i] <= '0;
    end
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  for(int i=0; i<CH_NUM; i++) begin
    if(!reset_n) begin
      e1_buf2_rp_ff[i] <= 'b0;
    end else begin
      if(txch_clr_t1_ff[i]) begin
        e1_buf2_rp_ff[i] <= 'b0;
      end else if(c2d_axis_tready | ~c2d_axis_tvalid) begin
        if(  e1_buf2rd_gnt[i]
           |(buf2rd_gnt_hold_ff[i] & (buf2rd_stm_ff==RD))) begin
          e1_buf2_rp_ff[i] <= e1_buf2_rp_ff[i] + 1'b1;
        end
      end
    end

    if(!reset_n) begin
      e2_buf2rd_gnt_ff[i]   <= 'b0;
      e3_buf2rd_gnt_ff[i]   <= 'b0;
      buf2rd_gnt_hold_ff[i] <= 'b0;
    end else if(c2d_axis_tready | ~c2d_axis_tvalid) begin
      e2_buf2rd_gnt_ff[i] <= e1_buf2rd_gnt[i];
      e3_buf2rd_gnt_ff[i] <= e2_buf2rd_gnt_ff[i];

      if(e1_buf2rd_gnt[i]) begin
        buf2rd_gnt_hold_ff[i] <= 1'b1;
      end else if(~e1_buf2rd_gnt[i] & e1_buf2rd_gnt_anych) begin
        buf2rd_gnt_hold_ff[i] <= 1'b0;
      end else if(buf2rd_stm_ff!=RD) begin
        buf2rd_gnt_hold_ff[i] <= 1'b0;
      end
    end

  end
end


////////////////////////////////////////////////
// (16) BUF2 read arbiter
////////////////////////////////////////////////
assign buf2rd_arbenb =  (buf2rd_stm_ff==IDLE)
                      & (c2d_axis_tready | ~c2d_axis_tvalid);

cif_arb #(
  .CH_NUM    (CH_NUM)
) cifu_buf2rd_arb (
  .reset_n   (reset_n),
  .user_clk  (user_clk),
  .req       (e0_buf2rd_req),
  .gnt       (e1_buf2rd_gnt),
  .gnt_anych (e1_buf2rd_gnt_anych),
  .arbenb    (buf2rd_arbenb)
);

////////////////////////////////////////////////
// (17) BUF2 read control buf2rd_stm
////////////////////////////////////////////////

always_comb begin
 e1_buf2rd_hd_win     = 'b0;
 e1_buf2rd_len_win    = 'b0;
 e1_buf2rd_last_win   = 'b0;
 e1_buf2rd_rp_win     = 'b0;
 e1_buf2rd_cid_win    = 'b0;
// buf2_1stfrm_word_win = 'b0;
 for(int i=0; i<CH_NUM; i++) begin
   // e0 signal is used for e1. Since gnt is the shortest 2T interval, it is OK.
   if(e1_buf2rd_gnt[i]==1) begin
     e1_buf2rd_hd_win     = e0_buf2rd_hd[i];
     e1_buf2rd_len_win    = e0_buf2rd_len[i];
     e1_buf2rd_last_win   = e0_buf2rd_last[i];
     e1_buf2rd_rp_win     = e1_buf2_rp_ff[i];
     e1_buf2rd_cid_win    = i;
//     buf2_1stfrm_word_win = buf2_1stfrm_word_ff[i];
   end
 end
end

//// buf2 read stm
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    buf2rd_stm_ff <= IDLE;
  end else if(c2d_axis_tready | ~c2d_axis_tvalid) begin
    case(buf2rd_stm_ff)
      IDLE: begin
        if(e1_buf2rd_gnt_anych) begin
          if(e1_buf2rd_len_win==1) begin
            buf2rd_stm_ff <= RDWAIT;
          end else begin
            buf2rd_stm_ff <= RD;
          end
        end else begin
          buf2rd_stm_ff <= IDLE;
        end
      end
      RD: begin
        if(e2_buf2rd_remlen_ff<=1) begin
          buf2rd_stm_ff <= IDLE;
        end else begin
          buf2rd_stm_ff <= RD;
        end
      end
      RDWAIT: begin
        buf2rd_stm_ff <= IDLE;
      end
    endcase
  end
end

assign e1_buf2rd_re           =   (c2d_axis_tready | ~c2d_axis_tvalid)
                                & (e1_buf2rd_gnt_anych | (buf2rd_stm_ff==RD));
assign e1_buf2rd_cid_win_hold = e1_buf2rd_gnt_anych ? e1_buf2rd_cid_win : e2_buf2rd_cid_hold_ff;

////////////////////////////////////////////////
// (18) c2d Packet Generation
////////////////////////////////////////////////
assign e3_buf2rd_byte = e3_buf2rd_data_ff[63:32] + 32'h30;
assign e3_buf2rd_word = {6'h00,e3_buf2rd_byte[31:6]} + {31'h0, (e3_buf2rd_byte[5:0]>0)};

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    e2_buf2rd_remlen_ff <= 'b0;
    e3_buf2rd_remlen_ff <= 'b0;
  end else if(c2d_axis_tready | ~c2d_axis_tvalid) begin
    if(e1_buf2rd_gnt_anych) begin
      e2_buf2rd_remlen_ff <= e1_buf2rd_len_win - 1'b1;
    end else if(e1_buf2rd_re) begin
      e2_buf2rd_remlen_ff <= e2_buf2rd_remlen_ff - 1'b1;
    end

    e3_buf2rd_remlen_ff <= e2_buf2rd_remlen_ff;
  end
end

assign e3_buf2rd_pktend = (e3_buf2rd_remlen_ff=='b0);

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    e2_buf2rd_re_ff            <= 'b0;
    e2_buf2rd_gnt_anych_ff     <= 'b0;
    e2_buf2rd_hd_ff            <= 'b0;
    e2_buf2rd_last_hold_ff     <= 'b0;
    e2_buf2rd_cid_hold_ff      <= 'b0;
    e2_buf2rd_len_win_ff       <= 'b0;

    e3_buf2rd_re_ff        <= 'b0;
    e3_buf2rd_gnt_anych_ff <= 'b0;
    e3_buf2rd_len_hold_ff  <= 'b0;
    e3_buf2rd_hd_ff        <= 'b0;
    e3_buf2rd_cid_hold_ff  <= 'b0;

    e4_buf2rd_val_ff       <= 'b0;
    e4_buf2rd_data_ff      <= 'b0;
    e4_buf2rd_sop_ff       <= 'b0;
    e4_buf2rd_eop_ff       <= 'b0;
    e4_buf2rd_last_ff      <= 'b0;
    e4_buf2rd_cid_ff       <= 'b0;
    e4_buf2rd_burst_ff     <= 'b0;
  end else if(c2d_axis_tready | ~c2d_axis_tvalid) begin
    e2_buf2rd_re_ff        <= e1_buf2rd_re;
    e2_buf2rd_gnt_anych_ff <= e1_buf2rd_gnt_anych; 
    e2_buf2rd_hd_ff        <= e1_buf2rd_hd_win;
    if(e1_buf2rd_gnt_anych) begin
      e2_buf2rd_last_hold_ff <= e1_buf2rd_last_win;
    end else if(e3_buf2rd_hd_ff & (e3_buf2rd_word==32'h10)) begin
      e2_buf2rd_last_hold_ff <= 1'b1;
    end else begin
      e2_buf2rd_last_hold_ff <= e2_buf2rd_last_hold_ff;
    end
    if(e1_buf2rd_gnt_anych) begin
      e2_buf2rd_cid_hold_ff <= e1_buf2rd_cid_win;
    end else begin
      e2_buf2rd_cid_hold_ff <= e2_buf2rd_cid_hold_ff;
    end
    e2_buf2rd_len_win_ff       <= e1_buf2rd_len_win;

    e3_buf2rd_re_ff        <= e2_buf2rd_re_ff;
    e3_buf2rd_gnt_anych_ff <= e2_buf2rd_gnt_anych_ff;
    if(e2_buf2rd_gnt_anych_ff) begin
      e3_buf2rd_len_hold_ff <= e2_buf2rd_len_win_ff;
    end else if(e2_buf2rd_hd_ff & e2_buf2rd_re_ff) begin
      e3_buf2rd_len_hold_ff <= e2_buf2rd_remlen_ff;
    end
    e3_buf2rd_hd_ff        <= e2_buf2rd_hd_ff;
    e3_buf2rd_cid_hold_ff  <= e2_buf2rd_cid_hold_ff;

    e4_buf2rd_val_ff   <= e3_buf2rd_re_ff;
    e4_buf2rd_data_ff  <= e3_buf2rd_data_ff;
    e4_buf2rd_sop_ff   <= e3_buf2rd_gnt_anych_ff | (e3_buf2rd_hd_ff & e3_buf2rd_re_ff);
    e4_buf2rd_eop_ff   <= e3_buf2rd_pktend;
    e4_buf2rd_last_ff  <= e3_buf2rd_pktend & e2_buf2rd_last_hold_ff;
    e4_buf2rd_cid_ff   <= e3_buf2rd_cid_hold_ff;
    e4_buf2rd_burst_ff <= e3_buf2rd_len_hold_ff;
  end
end
assign c2d_axis_tvalid = e4_buf2rd_val_ff; 
assign c2d_axis_tdata  = e4_buf2rd_data_ff;
assign c2d_axis_tlast  = e4_buf2rd_last_ff;
assign c2d_axis_tuser  = {({{8-CH_NUM_W{1'b0}},e4_buf2rd_cid_ff[CH_NUM_W-1:0]}|(CHAIN_ID<<CH_NUM_W)),
                          e4_buf2rd_sop_ff,
                          e4_buf2rd_eop_ff,
                          1'b0,
                          e4_buf2rd_burst_ff[4:0]};

////////////////////////////////////////////////
// (1) cif_clktr (Clock Crossing)
////////////////////////////////////////////////
//always_ff @(posedge user_clk or negedge reset_n) begin
//  if (!reset_n) begin
//    e2_buf2rd_gnt_ff <= 1'b0;
//    e3_buf2rd_gnt_ff <= 1'b0;
//  end else if (c2d_axis_tready | ~c2d_axis_tvalid) begin
//    e2_buf2rd_gnt_ff <= |e1_buf2rd_gnt;
//    e3_buf2rd_gnt_ff <= e2_buf2rd_gnt_ff;
//  end
//end

assign buf2_1stfrm_word_win = buf2_1stfrm_word_ff[e3_buf2rd_cid_hold_ff];
always_ff @(posedge user_clk or negedge reset_n) begin
  if (!reset_n) begin
    frame_info_size <= 'd0;
    frame_info_valid <= 1'b0;
    frame_info_ch <= 'd0;
  end else if (c2d_axis_tready | ~c2d_axis_tvalid) begin
    if (e3_buf2rd_hd_ff & (buf2_1stfrm_word_win == 0) & (|e3_buf2rd_gnt_ff) & e3_buf2rd_re_ff) begin
      frame_info_valid <= 1'b1;
      frame_info_size <= {e3_buf2rd_word, 6'd0};
      frame_info_ch <= e3_buf2rd_cid_hold_ff;
    end else begin
      frame_info_valid <= 1'b0;
    end
  end else begin
    frame_info_valid <= 1'b0;
  end
end


assign cmd_ready = 1'b1;
assign cmd_valid = cmd_valid_clktr & ~transfer_cmd_err_detect_all;

// Frequency conversion was moved to outside.
//cif_clktr #(
//) cifu_clktr(
//  .reset_n              (reset_n),
//  .ext_reset_n          (ext_reset_n),
//  .user_clk             (user_clk),
//  .ext_clk              (ext_clk),
//
//  .transfer_cmd_valid   (s_axis_cu_transfer_cmd_valid),
//  .transfer_cmd_data    (s_axis_cu_transfer_cmd_data),
//  .transfer_cmd_ready   (s_axis_cu_transfer_cmd_ready),
//  .transfer_eve_valid   (m_axis_cu_transfer_eve_valid),
//  .transfer_eve_data    (m_axis_cu_transfer_eve_data),
//  .transfer_eve_ready   (m_axis_cu_transfer_eve_ready),
//
//  .cmd_valid            (cmd_valid_clktr),
//  .cmd_data             (cmd_data),
//  .cmd_ready            (cmd_ready),
//  .eve_valid            (eve_valid),
//  .eve_data             (eve_data),
//  .eve_ready            (eve_ready)
//);

  assign cmd_valid_clktr              = s_axis_cu_transfer_cmd_valid;
  assign cmd_data                     = s_axis_cu_transfer_cmd_data;
  assign s_axis_cu_transfer_cmd_ready = cmd_ready;

  assign m_axis_cu_transfer_eve_valid = eve_valid;
  assign m_axis_cu_transfer_eve_data  = eve_data;
  assign eve_ready                    = m_axis_cu_transfer_eve_ready;

////////////////////////////////////////////////
// (19b) c2d control signal generation (chain)
////////////////////////////////////////////////

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    txch_ie_t1_ff      <= '0;
    txch_clr_t1_ff     <= '0;
    rd_enb_t1_ff       <= '0;
    cifu_busy_pre_ff   <= '0;
    cifu_busy_ff       <= '0;
  end else begin
    txch_ie_t1_ff  <= (c2d_txch_ie & ~transfer_cmd_err_detect_all);
    txch_clr_t1_ff <=  c2d_txch_clr;
    rd_enb_t1_ff   <=  c2d_cifu_rd_enb;


    for(int i=0; i<CH_NUM; i++) begin
      cifu_busy_pre_ff[i] <= (a0_tx_ddr_wp_ff[i] != b1_ddrrd_rp_ff[i])
                            |(a0_tx_ddr_wp_ff[i] != b5_ddrrd_rp_ff[i]);
      cifu_busy_ff[i]     <= (cifu_busy_pre_ff[i]
                           | (|sdb0_dtsize_chx[i])
                           | (|sdb1_dtsize_chx[i])
                           | ( d1_valid_ff                      & d1_cid_vec_ff[i])
                           | ((d2_buf2_we_ff | d2_sftreg_we_ff) & d2_cid_vec_ff[i])
                           | ((d3_buf2_we_ff | d3_sftreg_we_ff) & d3_cid_vec_ff[i])
                           | ( d4_buf2_we_ff                    & d4_cid_vec_ff[i])
                           | (|d1_sftreg_len_ff[i])
                           | (d4_buf2_wp_ff[i]   != e1_buf2_rp_ff[i])
                           | (e2_buf2rd_re_ff & (e2_buf2rd_cid_hold_ff==i))
                           | (e3_buf2rd_re_ff & (e3_buf2rd_cid_hold_ff==i))
                           | (c2d_axis_tvalid & (e4_buf2rd_cid_ff==i)));
    end
  end
end

assign c2d_cifu_busy = cifu_busy_ff;

////////////////////////////////////////////////
// Registers
////////////////////////////////////////////////
assign transfer_cmd_err = cmd_valid & (~txch_ie_t1_ff[cmd_data[31+CH_NUM_W:32]] | cif_up_eg2_set);

assign i_ad_0900 = d5_frm_me_marker_ff;
assign i_ad_0904 = d5_frm_me_payload_len_ff;
assign i_ad_0908 = d5_frm_me_header_w2_ff;
assign i_ad_090c = d5_frm_me_header_w3_ff;
assign i_ad_0910 = d5_frm_me_ddr_wp_ff;
assign i_ad_0914 = d5_frm_me_ddr_rp_ff;
assign i_ad_09e4 = {20'b0, buf2_dtovfl_hld,buf1_dtovfl_hld,sdb1_dtovfl_hld,sdb0_dtovfl_hld,2'b0,e4_frm_marker_err,d4_frm_payload_err,d4_frm_marker_err,transfer_cmd_err,2'b0};
assign i_ad_09f8 = {27'b0, (cmd_valid & cif_up_eg2_set), 2'b0};
assign i_ad_1840 = {{15-BUF1_AD_W{1'b0}}, d0_buf1_rp_ff, {16-BUF1_AD_W{1'b0}}, c0_buf1_wp_ff};
assign i_ad_1844 = {{31-BUF1_AD_W{1'b0}}, b2_buf1_wp_rsv_ff};
assign i_ad_1848 = {3'h0, d0_buf1_sdb_rpsnd_ff[4:0],
                    3'h0, b3_buf1_sdb_rpeve_ff[4:0],
                    3'h0, b1_buf1_sdb_wprcv_ff[4:0],
                    3'h0, b1_buf1_sdb_wpreq_ff[4:0]};
assign i_ad_184c = {14'h0000, b0_ddrrd_stm_ff,
                    14'h0000, buf2rd_stm_ff};
assign i_ad_186c = {d5_frm_marker_err_cid_vec_acc,12'h0,buf2_dtfull_hld,buf1_dtfull_hld,sdb1_dtfull_hld,sdb0_dtfull_hld,d5_frm_marker_err_cid_vec};
assign i_ad_1870 =  d5_frm_marker_err_payload_len;
assign i_ad_1874 =  d5_frm_me_frame_cnt_ff;
assign i_ad_1878 =  d5_frm_me_buf1_wp_rp_ff;
assign i_ad_187c =  d5_frm_me_frm_hd_ddrwp_ff;

always_comb begin
  for(int i=0; i<CH_NUM; i++) begin
    i_ad_1854[i] = a0_tx_ddr_wp_ff[i];
    i_ad_1858[i] = b1_ddrrd_rp_ff[i];
    i_ad_185c[i] = {10'b0, e1_buf2_rp_ff[i],
                    10'b0, d4_buf2_wp_ff[i]};
    i_ad_1860[i] = d5_nxt_frm_hd_ddrwp_ff[i];
    i_ad_1864[i] = {25'b0, d1_sftreg_len_ff[i]};
    i_ad_1868[i] = buf2_1stfrm_word_ff[i];
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    cifu_infl_num_ff <= 'b0;
    transfer_cmd_err_detect <= 'b0;
  end else begin
    if         ( (m_axi_cu_arready & b2_arvalid_ff) & (m_axi_cu_rvalid & m_axi_cu_rlast)) begin 
      cifu_infl_num_ff <= cifu_infl_num_ff;
    end else if( (m_axi_cu_arready & b2_arvalid_ff) &~(m_axi_cu_rvalid & m_axi_cu_rlast)) begin
      cifu_infl_num_ff <= cifu_infl_num_ff + 10'h001;
    end else if(~(m_axi_cu_arready & b2_arvalid_ff) & (m_axi_cu_rvalid & m_axi_cu_rlast)) begin
      cifu_infl_num_ff <= cifu_infl_num_ff - 10'h001;
    end else begin
      cifu_infl_num_ff <= cifu_infl_num_ff;
    end
    if(transfer_cmd_err) begin
      transfer_cmd_err_detect <= 1'b1;
    end
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    buf1_dtsize_ff <= '0;
  end else begin
    if         (( m_axi_cu_rvalid) && (~d0_buf1_re)) begin
      buf1_dtsize_ff <= buf1_dtsize_ff + 1;
    end else if((~m_axi_cu_rvalid) && ( d0_buf1_re)) begin
      buf1_dtsize_ff <= buf1_dtsize_ff - 1;
    end
  end
end

assign buf1_dtsize_rsv = b2_buf1_wp_rsv_ff - d0_buf1_rp_ff;
assign buf1_dtsize     = buf1_dtsize_ff;
assign buf1_dtfull     = buf1_dtsize_ff[BUF1_AD_W] & (buf1_dtsize_ff[BUF1_AD_W-1:0] == 0);
assign buf1_dtovfl     = buf1_dtsize_ff[BUF1_AD_W] & (buf1_dtsize_ff[BUF1_AD_W-1:0]  > 0);

always_comb begin
  for(int i=0; i<CH_NUM; i++) begin
    // DDR->CIFUP data count in 64B increments
    pa00_inc_enb[i] = m_axi_cu_rvalid & (d0_buf1rd_cid==i);

    // CIFUP->DMATX data count in 64B increments
    pa01_inc_enb[i] = c2d_axis_tready & c2d_axis_tvalid & (e4_buf2rd_cid_ff==i);

    // DDR read req count
    pa02_inc_enb[i] = m_axi_cu_arready & b2_arvalid_ff & (b2_arcid_ff==i);

    // DDR read reply count
    pa03_inc_enb[i] = m_axi_cu_rvalid & m_axi_cu_rlast & (d0_buf1rd_cid==i);

    // transfer_eve send count
    pa04_inc_enb[i] =   eve_valid & eve_ready & (eve_data[79+CH_NUM_W:80]==i);

    // transfer_cmd received count
    pa05_inc_enb[i] = cmd_valid & (cmd_data[31+CH_NUM_W:32]==i);
  end
end

assign pa10_add_val    = {6'h0, cifu_infl_num_ff};                 // inflight count
assign pa11_add_val    = {{15-BUF1_AD_W{1'b0}},buf1_dtsize_rsv};   // Number of used entries in BUF1 (64B units) Common to all channels
assign pa12_add_val    = {{15-BUF1_AD_W{1'b0}},buf1_dtsize};       // Number of valid entries in BUF1 (64B units) Common to all channels
assign pa13_add_val    = 16'h0000;
assign pa13_add_val_ff = 16'h0000;

always_comb begin
  case(trace_wd_mode_ff)
    4'h0 :      begin   trace_wd[0] = {trace_free_run_cnt_ff[31:0]};
                        trace_wd[1] = {cmd_data[35:32],cmd_data[19:0],eve_data[83:80],eve_data[51:48]};
                        trace_wd[2] = {eve_data[47:32],m_axi_cu_araddr[19:4]};
                end
    4'h1 :      begin   trace_wd[0] = {trace_free_run_cnt_ff[31:0]};
                        trace_wd[1] = {cmd_data[35:32],cmd_data[19:0],eve_data[83:80],eve_data[51:48]};
                        trace_wd[2] = {eve_data[47:32],m_axi_cu_araddr[19:4]};
                end
    4'h4 :      begin   trace_wd[0] = {cmd_data[35:32],cmd_data[35:32],eve_data[83:80],eve_data[83:80],
                                       trace_free_run_cnt_ff[15:0]};
                        trace_wd[1] = {cmd_data[11:0],cmd_data[11:0],eve_data[43:36]};
                        trace_wd[2] = {eve_data[35:32],eve_data[43:32],m_axi_cu_araddr[19:4]};
                end
    default :   begin   trace_wd[0] = '0;
                        trace_wd[1] = '0;
                        trace_wd[2] = '0;
                end
  endcase
end

assign trace_wd[3] = {  (~trace_we_mode_ff[0]) & cmd_valid & cmd_ready,                 // 31
                        (~trace_we_mode_ff[0]) & cmd_valid & cmd_ready,                 // 30
                        (~trace_we_mode_ff[0]) & eve_valid & eve_ready,                 // 29
                        (~trace_we_mode_ff[0]) & eve_valid & eve_ready,                 // 28
                        (~trace_we_mode_ff[1]) & m_axi_cu_arvalid & m_axi_cu_arready,   // 27
                        (~trace_we_mode_ff[2]) & m_axi_cu_rvalid  & m_axi_cu_rready,    // 26
                        (~trace_we_mode_ff[3]) & c2d_axis_tvalid  & c2d_axis_tready,    // 25
                        c2d_axis_tlast,                                                 // 24
                        m_axi_cu_arlen[3:0],                                            // 23:20
                        m_axi_cu_rresp[1:0],                                            // 19:18
                        c2d_axis_tuser[7:6],                                            // 17:16
                        1'b0, m_axi_cu_araddr[25], CHAIN_ID[1], c2d_axis_tuser[12],     // 15:12
                        m_axi_cu_araddr[24:21],                                         // 11:8
                        CHAIN_ID[0], d0_buf1rd_cid[CH_NUM_W-1:0],                       // 7:4
                        c2d_axis_tuser[11:8]};                                          // 3:0

assign trace_we[0] = (|trace_wd[3][31:25]) & (at_me_trace_mode ? 1 : (d5_frm_marker_err_cid_vec == '0));
assign trace_we[1] = trace_we[0];
assign trace_we[2] = trace_we[0];
assign trace_we[3] = trace_we[0];

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    cif_up_tx_base_dn_ff   <= '0;
    cif_up_tx_base_up_ff   <= '0;

    i_ad_0900_ff           <= '0;
    i_ad_0904_ff           <= '0;
    i_ad_0908_ff           <= '0;
    i_ad_090c_ff           <= '0;
    i_ad_0910_ff           <= '0;
    i_ad_0914_ff           <= '0;
    i_ad_09e4_ff           <= '0;
    i_ad_09f8_ff           <= '0;
    i_ad_1840_ff           <= '0;
    i_ad_1844_ff           <= '0;
    i_ad_1848_ff           <= '0;
    i_ad_184c_ff           <= '0;
    i_ad_186c_ff           <= '0;
    i_ad_1870_ff           <= '0;
    i_ad_1874_ff           <= '0;
    i_ad_1878_ff           <= '0;
    i_ad_187c_ff           <= '0;
    for(int i=0; i<CH_NUM; i++) begin
      i_ad_1854_ff[i]      <= '0;
      i_ad_1858_ff[i]      <= '0;
      i_ad_185c_ff[i]      <= '0;
      i_ad_1860_ff[i]      <= '0;
      i_ad_1864_ff[i]      <= '0;
      i_ad_1868_ff[i]      <= '0;
    end

    for(int i=0; i<CH_NUM; i++) begin
      pa00_inc_enb_ff[i]   <= '0;
      pa01_inc_enb_ff[i]   <= '0;
      pa02_inc_enb_ff[i]   <= '0;
      pa03_inc_enb_ff[i]   <= '0;
      pa04_inc_enb_ff[i]   <= '0;
      pa05_inc_enb_ff[i]   <= '0;
    end
    pa10_add_val_ff        <= '0;
    pa11_add_val_ff        <= '0;
    pa12_add_val_ff        <= '0;

    trace_we_ff            <= '0;
    for(int i=0; i<4; i++) begin
      trace_wd_ff[i]       <= '0;
    end
    trace_we_mode_ff       <= '0;
    trace_wd_mode_ff       <= '0;
    trace_free_run_cnt_ff  <= '0;

  end else begin
    cif_up_tx_base_dn_ff   <= cif_up_tx_base_dn;
    cif_up_tx_base_up_ff   <= cif_up_tx_base_up;

    i_ad_0900_ff           <= i_ad_0900;
    i_ad_0904_ff           <= i_ad_0904;
    i_ad_0908_ff           <= i_ad_0908;
    i_ad_090c_ff           <= i_ad_090c;
    i_ad_0910_ff           <= i_ad_0910;
    i_ad_0914_ff           <= i_ad_0914;
    i_ad_09e4_ff           <= i_ad_09e4;
    i_ad_09f8_ff           <= i_ad_09f8;
    i_ad_1840_ff           <= i_ad_1840;
    i_ad_1844_ff           <= i_ad_1844;
    i_ad_1848_ff           <= i_ad_1848;
    i_ad_184c_ff           <= i_ad_184c;
    i_ad_1854_ff           <= i_ad_1854;
    i_ad_1858_ff           <= i_ad_1858;
    i_ad_185c_ff           <= i_ad_185c;
    i_ad_1860_ff           <= i_ad_1860;
    i_ad_1864_ff           <= i_ad_1864;
    i_ad_1868_ff           <= i_ad_1868;
    i_ad_186c_ff           <= i_ad_186c;
    i_ad_1870_ff           <= i_ad_1870;
    i_ad_1874_ff           <= i_ad_1874;
    i_ad_1878_ff           <= i_ad_1878;
    i_ad_187c_ff           <= i_ad_187c;

    pa00_inc_enb_ff        <= pa00_inc_enb;
    pa01_inc_enb_ff        <= pa01_inc_enb;
    pa02_inc_enb_ff        <= pa02_inc_enb;
    pa03_inc_enb_ff        <= pa03_inc_enb;
    pa04_inc_enb_ff        <= pa04_inc_enb;
    pa05_inc_enb_ff        <= pa05_inc_enb;
    pa10_add_val_ff        <= pa10_add_val;
    pa11_add_val_ff        <= pa11_add_val;
    pa12_add_val_ff        <= pa12_add_val;

    trace_we_ff            <= trace_we;
    trace_wd_ff            <= trace_wd;
    trace_we_mode_ff       <= trace_we_mode;
    trace_wd_mode_ff       <= trace_wd_mode;
    trace_free_run_cnt_ff  <= trace_free_run_cnt;

  end
end

logic [ 5:0] chk_d0_debug_st_ff;
logic [13:0] chk_d1_debug_st_ff;
logic [15:0] chk_d0_debug_st_cnt_ff[5:0];
logic [15:0] chk_d1_debug_st_cnt_ff[13:0];

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    chk_d0_debug_st_ff = '0;
    chk_d1_debug_st_ff = '0;
    for(int i=0; i<6; i++) begin
      chk_d0_debug_st_cnt_ff[i] = 0;
    end
    for(int i=0; i<14; i++) begin
      chk_d1_debug_st_cnt_ff[i] = 0;
    end
  end else begin
    for(int i=0; i<6; i++) begin
      if(d0_debug_st==i) begin
        chk_d0_debug_st_ff[i]     = '1;
        chk_d0_debug_st_cnt_ff[i] = chk_d0_debug_st_cnt_ff[i] + 1;
      end
    end
    for(int i=0; i<14; i++) begin
      if(d1_debug_st==i) begin
        chk_d1_debug_st_ff[i]     = '1;
        chk_d1_debug_st_cnt_ff[i] = chk_d1_debug_st_cnt_ff[i] + 1;
      end
    end
  end
end

logic  [2:0]  chk_d0_debug_st1;
logic  [2:0]  chk_d0_debug_st1_ff;
logic  [15:0] chk_d0_debug_st1_cnt_ff[2:0];

assign chk_d0_debug_st1[0] = (d0_debug_st==1) && (d0_buf1_sdb_nxt_ddrrd_rp_ff[0]==0) && (d0_buf1_sdb_ddrrd_rp_ff[0]==0);
assign chk_d0_debug_st1[1] = (d0_debug_st==1) && (d0_buf1_sdb_nxt_ddrrd_rp_ff[0]!=0) && (d0_buf1_sdb_ddrrd_rp_ff[0]==0);
assign chk_d0_debug_st1[2] = (d0_debug_st==1) && (d0_buf1_sdb_nxt_ddrrd_rp_ff[0]==0) && (d0_buf1_sdb_ddrrd_rp_ff[0]!=0);

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    chk_d0_debug_st1_ff = '0;
    for(int i=0; i<3; i++) begin
      chk_d0_debug_st1_cnt_ff[i] = 0;
    end
  end else begin
    for(int i=0; i<3; i++) begin
      if(chk_d0_debug_st1[i]) begin
        chk_d0_debug_st1_ff[i]     = '1;
        chk_d0_debug_st1_cnt_ff[i] = chk_d0_debug_st1_cnt_ff[i] + 1;
      end
    end
  end
end

endmodule
