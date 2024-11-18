/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

//------------------------------------------------------------------------------------
// Caution.
// Every cid in the cif_dn_chainx indicates the relative cid(0~7) in the chain
//------------------------------------------------------------------------------------

module cif_dn_chainx #(
  parameter CHAIN_ID     = 0,
  parameter CH_NUM       = 8,     // Number of chs in chain
  parameter BUF_WORD     = 32*16  // Number of BUF words, 1word=64B
)(
  input  logic              reset_n,      // LLDMA internal reset
  input  logic              ext_reset_n,  // Chain control unit reset
  input  logic              user_clk,     // LLDMA internal clock
  input  logic              ext_clk,      // Chain control clock

  input  logic              a0_fifo_out_axis_tvalid,
  input  logic [511:0]      a0_fifo_out_axis_tdata,
  input  logic [15:0]       a0_fifo_out_axis_tuser,
  output logic              a0_fifo_out_axis_tready,

  output logic              m_axi_cd_awvalid,
  input  logic              m_axi_cd_awready,
  output logic [63:0]       m_axi_cd_awaddr,
  output logic [7:0]        m_axi_cd_awlen,
  output logic [2:0]        m_axi_cd_awsize,
  output logic [1:0]        m_axi_cd_awburst,
  output logic              m_axi_cd_awlock,
  output logic [3:0]        m_axi_cd_awcache,
  output logic [2:0]        m_axi_cd_awprot,
  output logic [3:0]        m_axi_cd_awqos,
  output logic [3:0]        m_axi_cd_awregion,
  output logic              m_axi_cd_wvalid,
  input  logic              m_axi_cd_wready,
  output logic [511:0]      m_axi_cd_wdata,
  output logic [63:0]       m_axi_cd_wstrb,
  output logic              m_axi_cd_wlast,
  output logic              m_axi_cd_arvalid,
  input  logic              m_axi_cd_arready,
  output logic [63:0]       m_axi_cd_araddr,
  output logic [7:0]        m_axi_cd_arlen,
  output logic [2:0]        m_axi_cd_arsize,
  output logic [1:0]        m_axi_cd_arburst,
  output logic              m_axi_cd_arlock,
  output logic [3:0]        m_axi_cd_arcache,
  output logic [2:0]        m_axi_cd_arprot,
  output logic [3:0]        m_axi_cd_arqos,
  output logic [3:0]        m_axi_cd_arregion,
  input  logic              m_axi_cd_rvalid,
  output logic              m_axi_cd_rready,
  input  logic [511:0]      m_axi_cd_rdata,
  input  logic              m_axi_cd_rlast,
  input  logic [1:0]        m_axi_cd_rresp,
  input  logic              m_axi_cd_bvalid,
  output logic              m_axi_cd_bready,
  input  logic [1:0]        m_axi_cd_bresp,

  input  logic              s_axis_cd_transfer_cmd_valid,
  input  logic [63:0]       s_axis_cd_transfer_cmd_data,
  output logic              s_axis_cd_transfer_cmd_ready,
  output logic              m_axis_cd_transfer_eve_valid,
  output logic [127:0]      m_axis_cd_transfer_eve_data,
  input  logic              m_axis_cd_transfer_eve_ready,

  input  logic [CH_NUM-1:0] d2c_rxch_oe,
  input  logic [CH_NUM-1:0] d2c_rxch_clr,
  input  logic [31:0]       cif_dn_mode,
  output logic [CH_NUM-1:0] cif_dn_chainx_busy,
  output logic [CH_NUM-1:0] d2c_dmar_rd_enb,
  output logic [CH_NUM-1:0] rxch_clr_t1_ff,

  input  logic [31:0]       cif_dn_rx_base_dn,
  input  logic [31:0]       cif_dn_rx_base_up,
  input  logic [2:0]        cif_dn_rx_ddr_size,
  input  logic              cif_dn_eg2_set,
  input  logic              transfer_cmd_err_detect_all,
  output logic              transfer_cmd_err_detect,
  output logic [31:0]       i_ad_0700_ff,
  output logic [31:0]       i_ad_0704_ff,
  output logic [31:0]       i_ad_0708_ff,
  output logic [31:0]       i_ad_070c_ff,
  output logic [31:0]       i_ad_0710_ff,
  output logic [31:0]       i_ad_0714_ff,
  output logic [31:0]       i_ad_07e4_ff,
  output logic [31:0]       i_ad_07f8_ff,
  output logic [31:0]       i_ad_1640_ff,
  output logic [31:0]       i_ad_1644_ff,
  output logic [31:0]       i_ad_1648_ff,
  output logic [31:0]       i_ad_164c_ff,
  output logic [31:0]       i_ad_1654_ff[CH_NUM-1:0],
  output logic [31:0]       i_ad_1658_ff[CH_NUM-1:0],
  output logic [31:0]       i_ad_165c_ff[CH_NUM-1:0],
  output logic [31:0]       i_ad_1660_ff[CH_NUM-1:0],
  output logic [31:0]       i_ad_1664_ff[CH_NUM-1:0],
  output logic [31:0]       i_ad_1668_ff[CH_NUM-1:0],
  output logic [31:0]       i_ad_166c_ff,
  output logic [31:0]       i_ad_1670_ff,
  output logic [31:0]       i_ad_1674_ff,
  output logic [31:0]       i_ad_1678_ff,
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

// cif_dn_chx_gd
  input  logic [1:0]        d2c_pkt_mode[CH_NUM-1:0],
  input  logic [CH_NUM-1:0] d2c_que_wt_ack_mode2,
  output logic [CH_NUM-1:0] d2c_que_wt_req_mode2,
  output logic [31:0]       d2c_que_wt_req_ack_rp_mode2[CH_NUM-1:0],
  output logic [31:0]       d2c_ack_rp_mode2[CH_NUM-1:0]
);

localparam IDLE     = 0;
localparam PRERD    = 1;
localparam BUFRD    = 2;
localparam MARKER   = 32'he0ff10ad;
localparam CH_NUM_W = $clog2(CH_NUM);
localparam BUF_AD_W = $clog2(BUF_WORD);

logic                at_me_main_mode;
logic                at_me_trace_mode;

logic [CH_NUM_W-1:0] a0_cid_ff;
logic [CH_NUM_W-1:0] a0_cid_on_tuser;
logic [CH_NUM_W-1:0] a0_cid;
logic [31:0]         a0_frm_frame_cnt_ff[CH_NUM-1:0];
logic [31:0]         a0_payload_len_for_marker_err_ff[CH_NUM-1:0];

logic                marker_err;
logic [CH_NUM_W-1:0] a0_cid_thd;
logic                a1_tvalid_ff;
logic                a1_tlast_ff;
logic [CH_NUM_W-1:0] a1_cid_ff;
logic [CH_NUM_W-1:0] a1_cid_bufwt_ff;
logic                a1_frstcnt_thd_ach_ff;
logic [63:0]         a1_tdata_sft_hold_ff_we;

logic [511:0]        a1_tdata_ff;
logic [1023:0]       a1_tdata_tmp;
logic [511:0]        a1_tdata_sft;

logic [6:0]          a0_total_frac;
logic [6:0]          a1_total_frac_ff;
logic                a1_buf_we;
logic [5:0]          a1_buf_wp_b11_6;
logic [BUF_AD_W-1:0] a1_buf_wp_fullbit;
logic [7:0]          a1_frm_marker_err_cid_vec;
logic [7:0]          a1_frm_marker_err_cid_vec_acc;
logic [31:0]         a1_frm_marker_err_payload_len;
logic [31:0]         a1_frm_me_marker_ff;
logic [31:0]         a1_frm_me_payload_len_ff;
logic [31:0]         a1_frm_me_header_w2_ff;
logic [31:0]         a1_frm_me_header_w3_ff;
logic [31:0]         a1_frm_me_frame_cnt_ff;
logic [31:0]         a1_frm_me_ddr_wp_ff;
logic [31:0]         a1_frm_me_ddr_rp_ff;
logic [31:0]         a1_frm_me_buf_wp_rp_ff;

logic [63:0]         a2_tdata_sft_hold_ff_we[CH_NUM-1:0];
logic [511:0]        a2_tdata_sft_hold_ff[CH_NUM-1:0];
logic [511:0]        a2_tdata_sft_ff;
logic                a2_buf_we_ff;
logic                a2_buf_we;
logic [BUF_AD_W-1:0] a2_buf_wp_fullbit;
logic                a2_frstcnt_thd_ach_ff;
logic [6:0]          a2_total_frac_ff;
logic [CH_NUM_W-1:0] a2_cid_bufwt_ff;
logic [511:0]        a2_buf_wt_data;

logic [5:0]          eveq_dtsize;
logic [5:0]          eveq_cnt_ff[CH_NUM-1:0];
logic                bufrd_arbenb;
logic [CH_NUM-1:0]   b1_bufrd_gnt_chx;
logic                b1_bufrd_gnt_anych;
logic [31:0]         b1_ddr_nxtwp_win;
logic [4:0]          b1_bufrd_len_win;
logic [CH_NUM_W-1:0] b1_bufrd_cid_win;
logic [31:0]         b1_rx_ddr_wp_win;
logic [CH_NUM_W-1:0] b1_bufrd_cid_win_hold_ff;
logic [CH_NUM_W-1:0] b1_bufrd_cid;

logic                b0_bufrd_req_anych;
logic [1:0]          b1_bufrd_stm_ff;
logic [4:0]          b1_bufrd_remlen_ff;

logic                b1_buf_re;
logic [5:0]          b1_buf_rp_b11_6;
logic [BUF_AD_W-1:0] b1_buf_rp_fullbit;
logic [511:0]        b2_bufrd_data;
logic                b2_buf_re_ff;
logic                b3_buf_re_ff;
logic [511:0]        b3_bufrd_data_ff;

logic [5:0]          a0_pkt_frac;
logic [CH_NUM-1:0]   a0_fifo_out_axis_tready_pre_chx;
logic [6:0]          a0_nxt_total_frac_ff[CH_NUM-1:0];
logic [6:0]          a0_total_frac_ff[CH_NUM-1:0];
logic [CH_NUM-1:0]   a0_frstcnt_thd_t1_ff;
logic [CH_NUM-1:0]   a1_buf_we_ff;
logic [32:0]         a1_buf_wp_ff[CH_NUM-1:0];
logic [CH_NUM-1:0]   b0_bufrd_req;
logic [CH_NUM-1:0]   b1_bufrd_req;
logic [31:0]         b1_ddr_nxtwp_ff[CH_NUM-1:0];
logic [4:0]          b1_bufrd_len_ff[CH_NUM-1:0];
logic [32:0]         b1_buf_rp_ff[CH_NUM-1:0];
logic [31:0]         b1_rx_ddr_wp_ff[CH_NUM-1:0];
logic [32:0]         a0_nxtfrm_wp_ff[CH_NUM-1:0];
logic [31:0]         a0_remfrm_cnt_ff[CH_NUM-1:0];
logic [CH_NUM-1:0]   a0_last_ff;
logic [CH_NUM-1:0]   a0_last_flg_ff;
logic [31:0]         rx_ddr_rp_ff[CH_NUM-1:0];
logic [12:0]         buf_dtsize[CH_NUM-1:0];
logic [CH_NUM-1:0]   buf_dtfull;
logic [CH_NUM-1:0]   buf_dtovfl;
logic                buf_dtfull_hld;
logic                buf_dtovfl_hld;

logic                a0_fifo_out_axis_tready_i_ff;
logic                a0_fifo_out_axis_tready_e_ff;

logic                b2_awvalid_ff;
logic [31:0]         b2_awaddr_ff;
logic [7:0]          b2_awlen_ff;
logic [CH_NUM_W-1:0] b2_bufrd_cid_ff;
logic                b2_awvalid_hold_ff;
logic [31:0]         b2_awaddr_hold_ff;
logic [7:0]          b2_awlen_hold_ff;
logic [CH_NUM_W-1:0] b2_bufrd_cid_hold_ff;
logic                b2_wlast_ff;
logic                b3_awvalid_ff;
logic [31:0]         b3_awaddr_ff;
logic [7:0]          b3_awlen_ff;
logic [CH_NUM_W-1:0] b3_bufrd_cid_ff;
logic                b3_wlast_ff;

logic [5:0]          b1_eveq_wpreq_ff;
logic [5:0]          c0_eveq_wpres_ff;
logic [5:0]          d0_eveq_rp_ff;
logic                ddrwt_err;
logic [CH_NUM_W-1:0] b2_eveq_cid_ff[31:0];
logic [31:0]         b2_eveq_nxtwp_ff[31:0];
logic [31:0]         c1_eveq_resflg_ff;

logic [CH_NUM_W-1:0] d1_eve_cid_ff;
logic [31:0]         d1_eve_rx_ddr_wp_ff;
logic                d1_eve_val_ff;

logic                cmd_valid_clktr;
logic                cmd_valid;
logic [63:0]         cmd_data;
logic                cmd_ready;
logic                transfer_cmd_err;
logic                eve_valid;
logic [127:0]        eve_data;
logic                eve_ready;

logic [CH_NUM-1:0]   rxch_oe_t1_ff;
logic [CH_NUM-1:0]   rxch_oe_t1_ff_detect;
logic [CH_NUM-1:0]   cif_dn_chainx_busy_ff;
logic [CH_NUM-1:0]   dmar_rd_enb_ff;

logic                dmar_rd_enb_mode;
logic [31:0]         cif_dn_rx_base_dn_ff;
logic [31:0]         cif_dn_rx_base_up_ff;
logic [31:0]         i_ad_0700;
logic [31:0]         i_ad_0704;
logic [31:0]         i_ad_0708;
logic [31:0]         i_ad_070c;
logic [31:0]         i_ad_0710;
logic [31:0]         i_ad_0714;
logic [31:0]         i_ad_07e4;
logic [31:0]         i_ad_07f8;
logic [31:0]         i_ad_1640;
logic [31:0]         i_ad_1644;
logic [31:0]         i_ad_1648;
logic [31:0]         i_ad_164c;
logic [31:0]         i_ad_1654[CH_NUM-1:0];
logic [31:0]         i_ad_1658[CH_NUM-1:0];
logic [31:0]         i_ad_165c[CH_NUM-1:0];
logic [31:0]         i_ad_1660[CH_NUM-1:0];
logic [31:0]         i_ad_1664[CH_NUM-1:0];
logic [31:0]         i_ad_1668[CH_NUM-1:0];
logic [31:0]         i_ad_166c;
logic [31:0]         i_ad_1670;
logic [31:0]         i_ad_1674;
logic [31:0]         i_ad_1678;
logic [4:0]          cifd_infl_num_ff[CH_NUM-1:0];
logic [15:0]         cifd_infl_num_chain;
logic [CH_NUM-1:0]   pa00_inc_enb;
logic [CH_NUM-1:0]   pa01_inc_enb;
logic [CH_NUM-1:0]   pa02_inc_enb;
logic [CH_NUM-1:0]   pa03_inc_enb;
logic [CH_NUM-1:0]   pa04_inc_enb;
logic [CH_NUM-1:0]   pa05_inc_enb;
logic [15:0]         pa10_add_val;
logic [15:0]         pa11_add_val;
logic [15:0]         pa12_add_val;
logic [15:0]         pa13_add_val;
logic [3:0]          trace_we;
logic [3:0][31:0]    trace_wd;
logic [3:0]          trace_we_mode_ff;
logic [3:0]          trace_wd_mode_ff;
logic [31:0]         trace_free_run_cnt_ff;

// cif_dn_chx_gd
logic [CH_NUM-1:0]   chx_cifd_busy_mode2;

//// main ////

assign at_me_main_mode  = cif_dn_mode[0];
assign at_me_trace_mode = cif_dn_mode[1];

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    a0_cid_ff <= '0;
    for(int i=0; i<CH_NUM; i++) begin
      a0_payload_len_for_marker_err_ff[i] <= '0;
      a0_frm_frame_cnt_ff[i]              <= 32'h1;
    end
    a1_frm_marker_err_cid_vec     <= '0;
    a1_frm_marker_err_cid_vec_acc <= '0;
    a1_frm_marker_err_payload_len <= '0;
    a1_frm_me_marker_ff           <= '0;
    a1_frm_me_payload_len_ff      <= '0;
    a1_frm_me_header_w2_ff        <= '0;
    a1_frm_me_header_w3_ff        <= '0;
    a1_frm_me_frame_cnt_ff        <= '0;
    a1_frm_me_ddr_wp_ff           <= '0;
    a1_frm_me_ddr_rp_ff           <= '0;
    a1_frm_me_buf_wp_rp_ff        <= '0;
  end else if(a0_fifo_out_axis_tready_i_ff) begin
    if(a0_fifo_out_axis_tvalid & a0_fifo_out_axis_tuser[7]) begin
      a0_cid_ff <= a0_cid_on_tuser;
    end
    if(a0_fifo_out_axis_tvalid & a0_last_flg_ff[a0_cid_on_tuser]) begin
      a0_payload_len_for_marker_err_ff[a0_cid_on_tuser] <= a0_fifo_out_axis_tdata[63:32];
    end
    for(int i=0; i<CH_NUM; i++) begin
      if((i == a0_cid) & rxch_oe_t1_ff[a0_cid] & a0_last_flg_ff[a0_cid] & a0_fifo_out_axis_tvalid & a0_fifo_out_axis_tready_i_ff
         & (a0_frm_frame_cnt_ff[i] < 32'hffff_ffff)) begin
        a0_frm_frame_cnt_ff[i] <= a0_frm_frame_cnt_ff[i] + 32'h1;
      end
      if(marker_err & (i == a0_cid)) begin
        if(a1_frm_marker_err_cid_vec == '0) begin
          a1_frm_marker_err_cid_vec     <= (1<<i);
          a1_frm_marker_err_payload_len <= a0_payload_len_for_marker_err_ff[i];
          a1_frm_me_marker_ff           <= a0_fifo_out_axis_tdata[31:0];
          a1_frm_me_payload_len_ff      <= a0_fifo_out_axis_tdata[63:32];
          a1_frm_me_header_w2_ff        <= a0_fifo_out_axis_tdata[95:64];
          a1_frm_me_header_w3_ff        <= a0_fifo_out_axis_tdata[127:96];
          a1_frm_me_frame_cnt_ff        <= a0_frm_frame_cnt_ff[i];
          a1_frm_me_ddr_wp_ff           <= b1_rx_ddr_wp_ff[i][31:0];
          a1_frm_me_ddr_rp_ff           <= rx_ddr_rp_ff[i][31:0];
          a1_frm_me_buf_wp_rp_ff        <= {3'h0,b1_buf_rp_ff[i][12:0],3'h0,a1_buf_wp_ff[i][12:0]};
        end
        a1_frm_marker_err_cid_vec_acc   <= ((1<<i) | a1_frm_marker_err_cid_vec_acc);
      end
    end
  end
end

assign a0_cid_on_tuser = a0_fifo_out_axis_tuser[7+CH_NUM_W:8];
assign a0_cid          = (a0_fifo_out_axis_tvalid & a0_fifo_out_axis_tuser[7])?
                          a0_cid_on_tuser : a0_cid_ff;

assign marker_err =   rxch_oe_t1_ff[a0_cid]
                   &  a0_last_flg_ff[a0_cid]
                   &  a0_fifo_out_axis_tvalid
                   & (a0_fifo_out_axis_tdata[31:0]!=MARKER)
                   &  a0_fifo_out_axis_tready_i_ff;

////////////////////////////////////////////////
// (1) byte shifter
////////////////////////////////////////////////

always_comb begin
  a0_cid_thd = '0;

  for(int i=0; i<CH_NUM; i++) begin
    if(a0_frstcnt_thd_t1_ff[i]) begin
      a0_cid_thd = a0_cid_thd | i;
    end
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    a1_tvalid_ff          <= '0;
    a1_tlast_ff           <= '0;
    a1_tdata_ff           <= '0;
    a1_cid_ff             <= '0;
    a1_cid_bufwt_ff       <= '0;
    a1_frstcnt_thd_ach_ff <= '0;
  end else begin
    if(a0_fifo_out_axis_tready_i_ff) begin
      a1_tvalid_ff    <= a0_fifo_out_axis_tvalid;
      a1_tlast_ff     <= a0_last_ff[a0_cid];
      a1_tdata_ff     <= a0_fifo_out_axis_tdata;
      a1_cid_ff       <= a0_cid;
    end

    if(|a0_frstcnt_thd_t1_ff) begin
      a1_cid_bufwt_ff <= a0_cid_thd;
    end else if(a1_frstcnt_thd_ach_ff) begin
      a1_cid_bufwt_ff <= a1_cid_ff;
    end else if(a0_fifo_out_axis_tready_i_ff) begin
      a1_cid_bufwt_ff <= a0_cid;
    end

    a1_frstcnt_thd_ach_ff <= | a0_frstcnt_thd_t1_ff;
  end
end

assign a1_tdata_tmp = {2{a1_tdata_ff}};
always_comb begin
  for(int i=0; i<64; i++) begin
    for(int j=0; j<8; j++) begin
      a1_tdata_sft[i*8+j] = a1_tdata_tmp[(64-a1_total_frac_ff[5:0])*8 + i*8 + j];
    end
  end
end

// tdata_sft_hold_ff: Keep fractional data
always_comb begin
  if(a1_tvalid_ff & a1_tlast_ff) begin
    // a0_nxt_total_frac_ff with a1
    if(a0_nxt_total_frac_ff[a1_cid_ff][6]) begin
      a1_tdata_sft_hold_ff_we = 64'hffffffff_ffffffff;
    end else begin
      for(int i=0; i<64; i++) begin
        if(i<a1_total_frac_ff[5:0]) begin
          a1_tdata_sft_hold_ff_we[i] = 1'b0;
        end else begin
          a1_tdata_sft_hold_ff_we[i] = 1'b1;
        end
      end
    end
  end else begin
    a1_tdata_sft_hold_ff_we = 64'hffffffff_ffffffff;
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  for(int i=0; i<CH_NUM; i++) begin
    if(!reset_n) begin
      a2_tdata_sft_hold_ff_we[i] <= '0;
    end else if(a1_tvalid_ff & (a1_cid_ff==i) & a0_fifo_out_axis_tready_i_ff) begin
      a2_tdata_sft_hold_ff_we[i] <= a1_tdata_sft_hold_ff_we;
    end else begin
      a2_tdata_sft_hold_ff_we[i] <= '0;
    end
  end
end


always_ff @(posedge user_clk or negedge reset_n) begin
  for(int i=0; i<CH_NUM; i++) begin
    if(!reset_n) begin
      a2_tdata_sft_hold_ff[i] <= 512'h0;
    end else begin
      for(int j=0; j<64; j++) begin
        for(int k=0; k<8; k++) begin
          if(a2_tdata_sft_hold_ff_we[i][j]) begin
            a2_tdata_sft_hold_ff[i][j*8+k] <= a2_tdata_sft_ff[j*8+k];
          end
        end
      end
    end
  end
end

//// buf in CIF_DN

// buf controller
assign a0_total_frac = a0_total_frac_ff[a0_cid];

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    a1_total_frac_ff <= 7'h00;
  end else if(a0_fifo_out_axis_tready_i_ff) begin
    a1_total_frac_ff <= a0_total_frac;
  end
end

// a1_buf_wp_fullbit: cid in high bit, wp per cid in low bit
assign a1_buf_we         = ((|a1_buf_we_ff) & a0_fifo_out_axis_tready_i_ff) | a1_frstcnt_thd_ach_ff;
assign a1_buf_wp_b11_6   = a1_buf_wp_ff[a1_cid_bufwt_ff][11:6];
assign a1_buf_wp_fullbit = {{3-CH_NUM_W{1'b0}}, a1_cid_bufwt_ff, a1_buf_wp_b11_6};

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    a2_buf_we_ff          <= '0;
    a2_buf_wp_fullbit     <= '0;
    a2_frstcnt_thd_ach_ff <= '0;
    a2_total_frac_ff      <= '0;
    a2_cid_bufwt_ff       <= '0;
    a2_tdata_sft_ff       <= '0;
  end else begin
    a2_buf_we_ff          <= a1_buf_we;
    a2_buf_wp_fullbit     <= a1_buf_wp_fullbit;
    a2_frstcnt_thd_ach_ff <= a1_frstcnt_thd_ach_ff;
    a2_total_frac_ff      <= a1_total_frac_ff;
    a2_cid_bufwt_ff       <= a1_cid_bufwt_ff;
    a2_tdata_sft_ff       <= a1_tdata_sft;
  end
end

assign a2_buf_we         = a2_buf_we_ff & rxch_oe_t1_ff[a2_cid_bufwt_ff] & (at_me_main_mode ? (a1_frm_marker_err_cid_vec == '0) : ~a1_frm_marker_err_cid_vec_acc[a2_cid_bufwt_ff]);

always_comb begin
  if(a2_frstcnt_thd_ach_ff) begin
    a2_buf_wt_data = a2_tdata_sft_hold_ff[a2_cid_bufwt_ff];
  end else begin
    for(int i=0; i<64; i++) begin
      for(int j=0; j<8; j++) begin
        if(i<a2_total_frac_ff[5:0]) begin
          a2_buf_wt_data[i*8+j] = a2_tdata_sft_hold_ff[a2_cid_bufwt_ff][i*8+j];
        end else begin
          a2_buf_wt_data[i*8+j] = a2_tdata_sft_ff[i*8+j];
        end
      end
    end
  end
end

//// buf read arb
assign eveq_dtsize  = b1_eveq_wpreq_ff - d0_eveq_rp_ff;
assign bufrd_arbenb =  (b1_bufrd_stm_ff==IDLE)
                     & (m_axi_cd_awready | ~m_axi_cd_awvalid)
                     & (m_axi_cd_wready  | ~m_axi_cd_wvalid)
                     & (eveq_dtsize < 6'h20);

////////////////////////////////////////////////
// (3) cif_arb (BUF read ch arbiter)
////////////////////////////////////////////////
cif_arb #(
  .CH_NUM    (CH_NUM)
) cifd_bufrd_arb (
  .reset_n   (reset_n),
  .user_clk  (user_clk),
  .req       (b0_bufrd_req),
  .gnt       (b1_bufrd_gnt_chx),
  .gnt_anych (b1_bufrd_gnt_anych),
  .arbenb    (bufrd_arbenb)
);

////////////////////////////////////////////////
// (4) BUF read control, bufrd_stm
////////////////////////////////////////////////
always_comb begin
  b1_ddr_nxtwp_win  = '0;
  b1_bufrd_len_win  = '0;
  b1_bufrd_cid_win  = '0;
  b1_rx_ddr_wp_win  = '0;
  for(int i=0; i<CH_NUM; i++) begin
    if(b1_bufrd_gnt_chx[i]==1) begin
      b1_ddr_nxtwp_win  = b1_ddr_nxtwp_ff[i];
      b1_bufrd_len_win  = b1_bufrd_len_ff[i];
      b1_bufrd_cid_win  = i;
      b1_rx_ddr_wp_win  = b1_rx_ddr_wp_ff[i];
    end
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b1_bufrd_cid_win_hold_ff <= '0;
  end else if(b1_bufrd_gnt_anych) begin
    b1_bufrd_cid_win_hold_ff <= b1_bufrd_cid_win;
  end
end

assign b1_bufrd_cid = b1_bufrd_gnt_anych?
                      b1_bufrd_cid_win : b1_bufrd_cid_win_hold_ff;

//// buf read stm
assign b0_bufrd_req_anych = | b0_bufrd_req;

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b1_bufrd_stm_ff    <= IDLE;
    b1_bufrd_remlen_ff <= '0;
  end else begin
    case(b1_bufrd_stm_ff)
      IDLE: begin
        if(b0_bufrd_req_anych & bufrd_arbenb) begin
          b1_bufrd_stm_ff <= PRERD;
        end
      end

      PRERD: begin
        if( (m_axi_cd_awready | ~m_axi_cd_awvalid)
           &(m_axi_cd_wready  | ~m_axi_cd_wvalid)) begin
          if( ( b1_bufrd_gnt_anych & (b1_bufrd_len_win==5'h01)  )
             |(~b1_bufrd_gnt_anych & (b1_bufrd_remlen_ff==5'h00))) begin
            b1_bufrd_stm_ff    <= IDLE;
          end else begin
            b1_bufrd_stm_ff    <= BUFRD;
          end
        end

        if(b1_bufrd_gnt_anych) begin
          b1_bufrd_remlen_ff <= b1_bufrd_len_win - 1'b1;
        end
      end

      BUFRD: begin
        if(m_axi_cd_wready  | ~m_axi_cd_wvalid) begin
          if(b1_bufrd_remlen_ff==5'h01) begin
            b1_bufrd_stm_ff    <= IDLE;
            b1_bufrd_remlen_ff <= '0;
          end else begin
            b1_bufrd_stm_ff    <= BUFRD;
            b1_bufrd_remlen_ff <= b1_bufrd_remlen_ff - 1;
          end
        end
      end
    endcase
  end
end

//// buf body
// Implemented all chain and ch RAMs together in order to reduce the volume.
// CIF_BUF writes in 64byte units
assign b1_buf_re         = ( (m_axi_cd_awready | ~m_axi_cd_awvalid)
                            &(m_axi_cd_wready  | ~m_axi_cd_wvalid)
                            &(b1_bufrd_stm_ff==PRERD))
                          |( (m_axi_cd_wready  | ~m_axi_cd_wvalid)
                            &(b1_bufrd_stm_ff==BUFRD));
assign b1_buf_rp_b11_6   = b1_buf_rp_ff[b1_bufrd_cid][11:6];
assign b1_buf_rp_fullbit = {{3-CH_NUM_W{1'b0}},b1_bufrd_cid, b1_buf_rp_b11_6};

////////////////////////////////////////////////
// (2) cif_buf3 : BUF
////////////////////////////////////////////////

cif_buf3 cif_dn_buf (
  .clka  (user_clk),
  .ena   (a2_buf_we),
  .wea   (a2_buf_we),
  .addra (a2_buf_wp_fullbit),
  .dina  (a2_buf_wt_data),
  .clkb  (user_clk),
  .enb   (b1_buf_re),
  .addrb (b1_buf_rp_fullbit),
  .doutb (b2_bufrd_data)
);

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b2_buf_re_ff     <= '0;
    b3_buf_re_ff     <= '0;
    b3_bufrd_data_ff <= '0;
  end else if(m_axi_cd_wready  | ~m_axi_cd_wvalid) begin
    b2_buf_re_ff     <= b1_buf_re;
    b3_buf_re_ff     <= b2_buf_re_ff;
    b3_bufrd_data_ff <= b2_bufrd_data;
  end else begin
    b2_buf_re_ff     <= b2_buf_re_ff;
    b3_buf_re_ff     <= b3_buf_re_ff;
    b3_bufrd_data_ff <= b3_bufrd_data_ff;
  end
end

////////////////////////////////////////////////
// cif_dn_chx
////////////////////////////////////////////////
assign a0_pkt_frac = a0_fifo_out_axis_tdata[37:32] + 6'h30;  // 6'h30=fram header length
assign dmar_rd_enb_mode = cif_dn_mode[4];

generate
for(genvar i=0; i<CH_NUM; i++) begin: cif_dn_chx
  cif_dn_chx #(
    .CHAIN_ID (CHAIN_ID),
    .CID      (i),
    .CH_NUM   (CH_NUM)
  ) cif_dn_chx (
    .reset_n                     (reset_n),
    .user_clk                    (user_clk),

    .a0_fifo_out_axis_tvalid_chx     (a0_fifo_out_axis_tvalid & (a0_cid==i)),
    .a0_fifo_out_axis_tdata          (a0_fifo_out_axis_tdata),
    .a0_fifo_out_axis_tready_pre_chx (a0_fifo_out_axis_tready_pre_chx[i]),
    .a0_fifo_out_axis_tready         (a0_fifo_out_axis_tready_i_ff),

    .m_axi_cd_awvalid            (m_axi_cd_awvalid),
    .m_axi_cd_awready            (m_axi_cd_awready),
    .m_axi_cd_wvalid             (m_axi_cd_wvalid),
    .m_axi_cd_wready             (m_axi_cd_wready),

    .cmd_valid                   (cmd_valid),
    .cmd_data                    (cmd_data),

    .rxch_oe_t1_ff               (rxch_oe_t1_ff[i]),
    .rxch_clr_t1_ff              (rxch_clr_t1_ff[i]),
    .dmar_rd_enb_mode            (dmar_rd_enb_mode),
    .dmar_rd_enb_ff              (dmar_rd_enb_ff[i]),

    .a0_pkt_frac                 (a0_pkt_frac),
    .a0_nxt_total_frac_ff        (a0_nxt_total_frac_ff[i]),
    .a0_total_frac_ff            (a0_total_frac_ff[i]),
    .a0_frstcnt_thd_t1_ff        (a0_frstcnt_thd_t1_ff[i]),
    .a1_buf_we_ff                (a1_buf_we_ff[i]),
    .a1_buf_wp_ff                (a1_buf_wp_ff[i]),
                         
    .cif_dn_rx_ddr_size          (cif_dn_rx_ddr_size),
    .b0_bufrd_req                (b0_bufrd_req[i]),
    .b1_bufrd_req                (b1_bufrd_req[i]),
    .b1_ddr_nxtwp_ff             (b1_ddr_nxtwp_ff[i]),
    .b1_bufrd_len_ff             (b1_bufrd_len_ff[i]),
    .b1_buf_rp_ff                (b1_buf_rp_ff[i]),
    .b1_rx_ddr_wp_ff             (b1_rx_ddr_wp_ff[i]),
    .b1_bufrd_gnt_chx            (b1_bufrd_gnt_chx[i]),
    .b1_bufrd_gnt_anych          (b1_bufrd_gnt_anych),
    .b1_bufrd_stm_ff             (b1_bufrd_stm_ff),
    .b1_bufrd_remlen_ff          (b1_bufrd_remlen_ff),

    .a0_nxtfrm_wp_ff             (a0_nxtfrm_wp_ff[i]),
    .a0_remfrm_cnt_ff            (a0_remfrm_cnt_ff[i]),
    .a0_last_ff                  (a0_last_ff[i]),
    .a0_last_flg_ff              (a0_last_flg_ff[i]),
    .rx_ddr_rp_ff                (rx_ddr_rp_ff[i]),
    .buf_dtsize                  (buf_dtsize[i]),
    .buf_dtfull                  (buf_dtfull[i]),
    .buf_dtovfl                  (buf_dtovfl[i]),

// cif_dn_chx_gd
    // input
    .chx_pkt_mode                (d2c_pkt_mode[i]),
    .chx_que_wt_ack_mode2        (d2c_que_wt_ack_mode2[i]), 
    // output
    .chx_que_wt_req_mode2        (d2c_que_wt_req_mode2[i]),
    .chx_que_wt_req_ack_rp_mode2 (d2c_que_wt_req_ack_rp_mode2[i]),
    .chx_ack_rp_mode2            (d2c_ack_rp_mode2[i]),
    .chx_cifd_busy_mode2         (chx_cifd_busy_mode2[i])
  );
end
endgenerate

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    a0_fifo_out_axis_tready_i_ff <= 1'b0;
    a0_fifo_out_axis_tready_e_ff <= 1'b0;
    buf_dtfull_hld               <= '0;
    buf_dtovfl_hld               <= '0;
  end else begin
    a0_fifo_out_axis_tready_i_ff <= & (&a0_fifo_out_axis_tready_pre_chx);
    a0_fifo_out_axis_tready_e_ff <= & (&a0_fifo_out_axis_tready_pre_chx);
    if(|buf_dtfull) begin
      buf_dtfull_hld <= 1'b1;
    end
    if(|buf_dtovfl) begin
      buf_dtovfl_hld <= 1'b1;
    end
  end
end

assign a0_fifo_out_axis_tready = a0_fifo_out_axis_tready_e_ff;

////////////////////////////////////////////////
// (5) DDR Write Signal Generation
////////////////////////////////////////////////
//// AXI-MM I/F
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b2_awvalid_ff        <= '0;
    b2_awaddr_ff         <= '0;
    b2_awlen_ff          <= '0;
    b2_bufrd_cid_ff      <= '0;
    b2_awvalid_hold_ff   <= '0;
    b2_awaddr_hold_ff    <= '0;
    b2_awlen_hold_ff     <= '0;
    b2_bufrd_cid_hold_ff <= '0;
    b3_awvalid_ff        <= '0;
    b3_awaddr_ff         <= '0;
    b3_awlen_ff          <= '0;
    b3_bufrd_cid_ff      <= '0;
  end else begin
    if(   b1_bufrd_gnt_anych
       & (m_axi_cd_awready | ~m_axi_cd_awvalid)) begin
      b2_awvalid_ff   <= 1'b1;
      case (cif_dn_rx_ddr_size)
        3'h0    : b2_awaddr_ff <= (cif_dn_rx_base_dn_ff + (32'h0100000 * b1_bufrd_cid_win) + {12'b0, b1_rx_ddr_wp_win[19:6], 6'h0});
        3'h1    : b2_awaddr_ff <= (cif_dn_rx_base_dn_ff + (32'h0200000 * b1_bufrd_cid_win) + {11'b0, b1_rx_ddr_wp_win[20:6], 6'h0});
        3'h2    : b2_awaddr_ff <= (cif_dn_rx_base_dn_ff + (32'h0400000 * b1_bufrd_cid_win) + {10'b0, b1_rx_ddr_wp_win[21:6], 6'h0});
        3'h3    : b2_awaddr_ff <= (cif_dn_rx_base_dn_ff + (32'h0800000 * b1_bufrd_cid_win) + { 9'b0, b1_rx_ddr_wp_win[22:6], 6'h0});
        3'h4    : b2_awaddr_ff <= (cif_dn_rx_base_dn_ff + (32'h1000000 * b1_bufrd_cid_win) + { 8'b0, b1_rx_ddr_wp_win[23:6], 6'h0});
        3'h5    : b2_awaddr_ff <= (cif_dn_rx_base_dn_ff + (32'h2000000 * b1_bufrd_cid_win) + { 7'b0, b1_rx_ddr_wp_win[24:6], 6'h0});
        3'h6    : b2_awaddr_ff <= (cif_dn_rx_base_dn_ff + (32'h0010000 * b1_bufrd_cid_win) + {16'b0, b1_rx_ddr_wp_win[15:6], 6'h0});
        3'h7    : b2_awaddr_ff <= (cif_dn_rx_base_dn_ff + (32'h0020000 * b1_bufrd_cid_win) + {15'b0, b1_rx_ddr_wp_win[16:6], 6'h0});
        default : b2_awaddr_ff <= (cif_dn_rx_base_dn_ff + (32'h0100000 * b1_bufrd_cid_win) + {12'b0, b1_rx_ddr_wp_win[19:6], 6'h0});
      endcase
      b2_awlen_ff     <= {3'h0, b1_bufrd_len_win} - 8'h01;
      b2_bufrd_cid_ff <= b1_bufrd_cid_win;
    end else begin
      b2_awvalid_ff   <= 1'b0;
      b2_awaddr_ff    <= b2_awaddr_ff;
      b2_awlen_ff     <= b2_awlen_ff;
      b2_bufrd_cid_ff <= b2_bufrd_cid_ff;
    end

    if(    b1_bufrd_gnt_anych
       &(~(m_axi_cd_awready | ~m_axi_cd_awvalid))) begin
      b2_awvalid_hold_ff   <= 1'b1;
      case (cif_dn_rx_ddr_size)
        3'h0    : b2_awaddr_hold_ff <= (cif_dn_rx_base_dn_ff + (32'h0100000 * b1_bufrd_cid_win) + {12'b0, b1_rx_ddr_wp_win[19:6], 6'h0});
        3'h1    : b2_awaddr_hold_ff <= (cif_dn_rx_base_dn_ff + (32'h0200000 * b1_bufrd_cid_win) + {11'b0, b1_rx_ddr_wp_win[20:6], 6'h0});
        3'h2    : b2_awaddr_hold_ff <= (cif_dn_rx_base_dn_ff + (32'h0400000 * b1_bufrd_cid_win) + {10'b0, b1_rx_ddr_wp_win[21:6], 6'h0});
        3'h3    : b2_awaddr_hold_ff <= (cif_dn_rx_base_dn_ff + (32'h0800000 * b1_bufrd_cid_win) + { 9'b0, b1_rx_ddr_wp_win[22:6], 6'h0});
        3'h4    : b2_awaddr_hold_ff <= (cif_dn_rx_base_dn_ff + (32'h1000000 * b1_bufrd_cid_win) + { 8'b0, b1_rx_ddr_wp_win[23:6], 6'h0});
        3'h5    : b2_awaddr_hold_ff <= (cif_dn_rx_base_dn_ff + (32'h2000000 * b1_bufrd_cid_win) + { 7'b0, b1_rx_ddr_wp_win[24:6], 6'h0});
        3'h6    : b2_awaddr_hold_ff <= (cif_dn_rx_base_dn_ff + (32'h0010000 * b1_bufrd_cid_win) + {16'b0, b1_rx_ddr_wp_win[15:6], 6'h0});
        3'h7    : b2_awaddr_hold_ff <= (cif_dn_rx_base_dn_ff + (32'h0020000 * b1_bufrd_cid_win) + {15'b0, b1_rx_ddr_wp_win[16:6], 6'h0});
        default : b2_awaddr_hold_ff <= (cif_dn_rx_base_dn_ff + (32'h0100000 * b1_bufrd_cid_win) + {12'b0, b1_rx_ddr_wp_win[19:6], 6'h0});
      endcase
      b2_awlen_hold_ff     <= {3'h0, b1_bufrd_len_win} - 8'h01;
      b2_bufrd_cid_hold_ff <= b1_bufrd_cid_win;
    end else if(m_axi_cd_awready | ~m_axi_cd_awvalid) begin
      b2_awvalid_hold_ff   <= 1'b0;
    end

    if(m_axi_cd_awready | ~m_axi_cd_awvalid) begin
      if(b2_awvalid_ff) begin
        b3_awvalid_ff   <= b2_awvalid_ff;
        b3_awaddr_ff    <= b2_awaddr_ff;
        b3_awlen_ff     <= b2_awlen_ff;
        b3_bufrd_cid_ff <= b2_bufrd_cid_ff;
      end else begin
        b3_awvalid_ff   <= b2_awvalid_hold_ff;
        b3_awaddr_ff    <= b2_awaddr_hold_ff;
        b3_awlen_ff     <= b2_awlen_hold_ff;
        b3_bufrd_cid_ff <= b2_bufrd_cid_hold_ff;
      end
    end
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b2_wlast_ff   <= 'b0;
    b3_wlast_ff   <= 'b0;

  end else begin
    if( (m_axi_cd_awready | ~m_axi_cd_awvalid)
       &(m_axi_cd_wready  | ~m_axi_cd_wvalid)
       &(b1_bufrd_stm_ff==PRERD)) begin
      b2_wlast_ff <=  b1_bufrd_gnt_anych ?
                     (b1_bufrd_len_win==1) : (b1_bufrd_remlen_ff==0);
    end else if ( (m_axi_cd_wready  | ~m_axi_cd_wvalid)
                 &(b1_bufrd_stm_ff==BUFRD)) begin
      b2_wlast_ff <= (b1_bufrd_remlen_ff==1);
    end

    if(m_axi_cd_wready  | ~m_axi_cd_wvalid) begin
      b3_wlast_ff <= b2_wlast_ff;
    end
  end
end

// DDR-writes
assign m_axi_cd_awvalid  = b3_awvalid_ff;
// m_axi_cd_awready
assign m_axi_cd_awaddr   = {cif_dn_rx_base_up_ff, b3_awaddr_ff};
assign m_axi_cd_awlen    = b3_awlen_ff;
assign m_axi_cd_awsize   = 3'b110;  // 64Byte
assign m_axi_cd_awburst  = 2'b01;   // INCR
assign m_axi_cd_awlock   = 1'b0;
assign m_axi_cd_awcache  = 4'h0;
assign m_axi_cd_awprot   = 3'h0;
assign m_axi_cd_awqos    = 4'h0;
assign m_axi_cd_awregion = 4'h0;
assign m_axi_cd_wvalid   = b3_buf_re_ff;
// m_axi_cd_wready
assign m_axi_cd_wdata    = b3_bufrd_data_ff;
assign m_axi_cd_wstrb    = 64'hffffffff_ffffffff;
assign m_axi_cd_wlast    = b3_wlast_ff;
// m_axi_cd_bvalid
assign m_axi_cd_bready   = 1'b1;
// m_axi_cd_bresp

// DDR-reads (unused output: 0-clip)
assign m_axi_cd_arvalid  = 'b0;
// m_axi_cd_arready
assign m_axi_cd_araddr   = 'b0;
assign m_axi_cd_arlen    = 'b0;
assign m_axi_cd_arsize   = 'b0;
assign m_axi_cd_arburst  = 'b0;
assign m_axi_cd_arlock   = 'b0;
assign m_axi_cd_arcache  = 'b0;
assign m_axi_cd_arprot   = 'b0;
assign m_axi_cd_arqos    = 'b0;
assign m_axi_cd_arregion = 'b0;
// m_axi_cd_rvalid
assign m_axi_cd_rready   = 'b0;
// m_axi_cd_rdata
// m_axi_cd_rlast
// m_axi_cd_rresp

////////////////////////////////////////////////
// (6) eve transmission control, eve queue
////////////////////////////////////////////////
//// eve queue
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b1_eveq_wpreq_ff <= '0;
    c0_eveq_wpres_ff <= '0;
    d0_eveq_rp_ff    <= '0;
  end else begin
    if(b1_bufrd_gnt_anych) begin
      b1_eveq_wpreq_ff <= b1_eveq_wpreq_ff + 6'h01;
    end

    if(m_axi_cd_bvalid & m_axi_cd_bready) begin
      c0_eveq_wpres_ff <= c0_eveq_wpres_ff + 6'h01;
    end

    if(c1_eveq_resflg_ff[d0_eveq_rp_ff[4:0]] == 1'b1) begin
      if(eve_ready | ~eve_valid) begin
        d0_eveq_rp_ff <= d0_eveq_rp_ff + 6'h01;
      end
    end
  end
end

assign ddrwt_err = m_axi_cd_bvalid & m_axi_cd_bready & (m_axi_cd_bresp!=2'b00);
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    for(int i=0; i<32; i++) begin
      b2_eveq_cid_ff[i]    <= '0;
      b2_eveq_nxtwp_ff[i]  <= '0;
      c1_eveq_resflg_ff[i] <= '0;
    end
  end else begin
    if(b1_bufrd_gnt_anych) begin
      b2_eveq_cid_ff[b1_eveq_wpreq_ff[4:0]]   <= b1_bufrd_cid_win;
      b2_eveq_nxtwp_ff[b1_eveq_wpreq_ff[4:0]] <= b1_ddr_nxtwp_win;
    end

    if(m_axi_cd_bvalid & m_axi_cd_bready) begin
      c1_eveq_resflg_ff[c0_eveq_wpres_ff[4:0]] <= 1'b1;
    end
    if(c1_eveq_resflg_ff[d0_eveq_rp_ff[4:0]] == 1'b1) begin
      if(eve_ready | ~eve_valid) begin
        c1_eveq_resflg_ff[d0_eveq_rp_ff[4:0]] <= 1'b0;
      end
    end
  end
end

// // eve packet generation
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
      d1_eve_val_ff       <= '0;
      d1_eve_cid_ff       <= '0;
      d1_eve_rx_ddr_wp_ff <= '0;
  end else begin
    if(~(eve_ready | ~eve_valid)) begin
      d1_eve_val_ff       <= d1_eve_val_ff;
      d1_eve_cid_ff       <= d1_eve_cid_ff;
      d1_eve_rx_ddr_wp_ff <= d1_eve_rx_ddr_wp_ff;
    end else begin
      if(c1_eveq_resflg_ff[d0_eveq_rp_ff[4:0]]==1'b1) begin
        d1_eve_val_ff       <= 1'b1;
        d1_eve_cid_ff       <= b2_eveq_cid_ff[d0_eveq_rp_ff[4:0]];
        d1_eve_rx_ddr_wp_ff <= b2_eveq_nxtwp_ff[d0_eveq_rp_ff[4:0]];
      end else begin
        d1_eve_val_ff       <= 1'b0;
        d1_eve_cid_ff       <= d1_eve_cid_ff;
        d1_eve_rx_ddr_wp_ff <= d1_eve_rx_ddr_wp_ff;
      end
    end 
  end
end

always_comb begin
  eve_valid = d1_eve_val_ff;

  eve_data = {cif_dn_rx_base_dn_ff[31:0],
              ({{16-CH_NUM_W{1'b0}}, d1_eve_cid_ff} | (CHAIN_ID<<CH_NUM_W)),
              16'h0040,
              32'h00000000,
              d1_eve_rx_ddr_wp_ff[31:0]};
end

////////////////////////////////////////////////
// (7) cif_clktr (CDC)
////////////////////////////////////////////////
assign cmd_ready = 1'b1;
assign cmd_valid = cmd_valid_clktr & ~transfer_cmd_err_detect_all;

// Frequency conversion was moved to outside.
//cif_clktr #(
//) cifd_clktr(
//  .reset_n              (reset_n),
//  .ext_reset_n          (ext_reset_n),
//  .user_clk             (user_clk),
//  .ext_clk              (ext_clk),
//
//  .transfer_cmd_valid   (s_axis_cd_transfer_cmd_valid),
//  .transfer_cmd_data    (s_axis_cd_transfer_cmd_data),
//  .transfer_cmd_ready   (s_axis_cd_transfer_cmd_ready),
//  .transfer_eve_valid   (m_axis_cd_transfer_eve_valid),
//  .transfer_eve_data    (m_axis_cd_transfer_eve_data),
//  .transfer_eve_ready   (m_axis_cd_transfer_eve_ready),
//
//  .cmd_valid            (cmd_valid_clktr),
//  .cmd_data             (cmd_data),
//  .cmd_ready            (cmd_ready),
//  .eve_valid            (eve_valid),
//  .eve_data             (eve_data),
//  .eve_ready            (eve_ready)
//);

  assign cmd_valid_clktr              = s_axis_cd_transfer_cmd_valid;
  assign cmd_data                     = s_axis_cd_transfer_cmd_data;
  assign s_axis_cd_transfer_cmd_ready = cmd_ready;
  assign m_axis_cd_transfer_eve_valid = eve_valid;
  assign m_axis_cd_transfer_eve_data  = eve_data;
  assign eve_ready                    = m_axis_cd_transfer_eve_ready;

////////////////////////////////////////////////
// (15b) d2c control signal generation (chain) + rxch_oe, rxch_clr
////////////////////////////////////////////////
always_ff @(posedge user_clk or negedge reset_n) begin
  for(int i=0; i<CH_NUM; i++) begin
    if(!reset_n) begin
      eveq_cnt_ff[i] <= '0;
    end else begin
      eveq_cnt_ff[i] <= eveq_cnt_ff[i]
                        + ( (m_axi_cd_bvalid & m_axi_cd_bready) & (b2_eveq_cid_ff[c0_eveq_wpres_ff[4:0]]==i) )
                        - ( (c1_eveq_resflg_ff[d0_eveq_rp_ff[4:0]] == 1'b1) & (eve_ready | ~eve_valid) & (b2_eveq_cid_ff[d0_eveq_rp_ff[4:0]]==i) );
    end
  end

  if(!reset_n) begin
    rxch_oe_t1_ff         <= '0;
    rxch_oe_t1_ff_detect  <= '0;
    rxch_clr_t1_ff        <= '0;
    cif_dn_chainx_busy_ff <= '0;
  end else begin
    rxch_oe_t1_ff         <= (d2c_rxch_oe & ~transfer_cmd_err_detect_all);
    rxch_clr_t1_ff        <=  d2c_rxch_clr;

    for(int i=0; i<CH_NUM; i++) begin
      if(rxch_clr_t1_ff[i]) begin 
        rxch_oe_t1_ff_detect[i] <= '0;
      end else if(d2c_rxch_oe[i]) begin 
        rxch_oe_t1_ff_detect[i] <= 1'b1;
      end
      cif_dn_chainx_busy_ff[i] <= ((eve_valid               & (d1_eve_cid_ff==i))
                                 | (a0_fifo_out_axis_tvalid & (a0_cid==i))
                                 | (a1_tvalid_ff            & (a1_cid_ff==i))
                                 | (a2_buf_we_ff            & (a2_cid_bufwt_ff==i))
                                 |  b0_bufrd_req[i]
                                 |  b1_bufrd_req[i]
                                 | (b2_awvalid_ff           & (b2_bufrd_cid_ff==i))
                                 | (b2_awvalid_hold_ff      & (b2_bufrd_cid_hold_ff==i))
                                 | (b3_awvalid_ff           & (b3_bufrd_cid_ff==i))
                                 | (eveq_cnt_ff[i]>0 ?1:0)
                                 |  chx_cifd_busy_mode2[i]);
    end
  end
end

assign cif_dn_chainx_busy = cif_dn_chainx_busy_ff;
assign d2c_dmar_rd_enb    = dmar_rd_enb_ff;

////////////////////////////////////////////////
// registers
////////////////////////////////////////////////
assign transfer_cmd_err = cmd_valid & (~(rxch_oe_t1_ff[cmd_data[31+CH_NUM_W:32]] | rxch_oe_t1_ff_detect[cmd_data[31+CH_NUM_W:32]]) | cif_dn_eg2_set);

assign i_ad_0700 = a1_frm_me_marker_ff;
assign i_ad_0704 = a1_frm_me_payload_len_ff;
assign i_ad_0708 = a1_frm_me_header_w2_ff;
assign i_ad_070c = a1_frm_me_header_w3_ff;
assign i_ad_0710 = a1_frm_me_ddr_wp_ff;
assign i_ad_0714 = a1_frm_me_ddr_rp_ff;
assign i_ad_07e4 = {23'b0, buf_dtovfl_hld, 3'b0, ddrwt_err, marker_err, transfer_cmd_err, 2'b0};
assign i_ad_07f8 = {27'b0, (cmd_valid & cif_dn_eg2_set), 2'b0};
assign i_ad_1640 = {{16-CH_NUM_W{1'b0}}, a0_last_flg_ff,
                    {16-CH_NUM_W{1'b0}}, a1_cid_ff};
assign i_ad_1644 = {25'h0, a1_total_frac_ff};
assign i_ad_1648 = {8'h0,
                    8'h0,
                    3'h0, b1_bufrd_remlen_ff,
                    6'h0, b1_bufrd_stm_ff};
assign i_ad_164c = {8'h0,
                    2'h0, d0_eveq_rp_ff,
                    2'h0, c0_eveq_wpres_ff,
                    2'h0, b1_eveq_wpreq_ff};
assign i_ad_166c = {a1_frm_marker_err_cid_vec_acc,15'h0,buf_dtfull_hld,a1_frm_marker_err_cid_vec};
assign i_ad_1670 =  a1_frm_marker_err_payload_len;
assign i_ad_1674 =  a1_frm_me_frame_cnt_ff;
assign i_ad_1678 =  a1_frm_me_buf_wp_rp_ff;

always_comb begin
  for(int i=0; i<CH_NUM; i++) begin
    i_ad_1654[i] = {3'h0, b1_buf_rp_ff[i][12:0],
                    3'h0, a1_buf_wp_ff[i][12:0]};
    i_ad_1658[i] = b1_rx_ddr_wp_ff[i];
    i_ad_165c[i] = rx_ddr_rp_ff[i];
    i_ad_1660[i] = a0_nxtfrm_wp_ff[i][31:0];
    i_ad_1664[i] = a0_remfrm_cnt_ff[i];
    i_ad_1668[i] = {25'h0, a0_total_frac_ff[i]};
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  for(int i=0; i<CH_NUM; i++) begin
    if(!reset_n) begin
      cifd_infl_num_ff[i]   <= 'b0;
    end else begin
      if(rxch_clr_t1_ff[i]) begin
        cifd_infl_num_ff[i] <= 'b0;
      end else begin
        if( (m_axi_cd_awvalid & m_axi_cd_awready & (b3_bufrd_cid_ff==i))
           &(m_axi_cd_bvalid  & m_axi_cd_bready  & (b2_eveq_cid_ff[c0_eveq_wpres_ff[4:0]]==i))) begin
          cifd_infl_num_ff[i] = cifd_infl_num_ff[i];
        end else if(m_axi_cd_awvalid & m_axi_cd_awready & (b3_bufrd_cid_ff==i)) begin
          cifd_infl_num_ff[i] = cifd_infl_num_ff[i] + 5'h01;
        end else if(m_axi_cd_bvalid  & m_axi_cd_bready  & (b2_eveq_cid_ff[c0_eveq_wpres_ff[4:0]]==i)) begin
          cifd_infl_num_ff[i] = cifd_infl_num_ff[i] - 5'h01;
        end else begin
          cifd_infl_num_ff[i] = cifd_infl_num_ff[i];
        end
      end
    end
  end
  if(!reset_n) begin
    transfer_cmd_err_detect <= 'b0;
  end else begin
    if(transfer_cmd_err) begin
      transfer_cmd_err_detect <= 1'b1;
    end
  end
end

always_comb begin
  cifd_infl_num_chain = 16'h0;
  for(int i=0; i<CH_NUM; i++) begin
    // FIFO->CIFDN data count in 64B units
    pa00_inc_enb[i] = a0_fifo_out_axis_tvalid & a0_fifo_out_axis_tready_i_ff & (a0_cid==i);

    // CIFDN->DDR data count in 64B units
    pa01_inc_enb[i] = m_axi_cd_wvalid & m_axi_cd_wready & (b3_bufrd_cid_ff==i);

    // DDR write req count
    pa02_inc_enb[i] = m_axi_cd_awvalid & m_axi_cd_awready & (b3_bufrd_cid_ff==i);

    // DDR write reply count
    pa03_inc_enb[i] = m_axi_cd_bvalid & m_axi_cd_bready & (b2_eveq_cid_ff[c0_eveq_wpres_ff[4:0]]==i);

    // transfer_eve send count
    pa04_inc_enb[i] = eve_valid & eve_ready & (eve_data[79+CH_NUM_W:80]==i);

    // transfer_cmd receive count
    pa05_inc_enb[i] = cmd_valid & (cmd_data[31+CH_NUM_W:32]==i);

    // inflight count
    cifd_infl_num_chain = cifd_infl_num_chain + {11'h0,cifd_infl_num_ff[i]};
  end
  // inflight count
  pa10_add_val      = cifd_infl_num_chain;

  pa11_add_val      = 16'h0000;
  pa12_add_val      = 16'h0000;
  pa13_add_val      = 16'h0000;
end

always_comb begin
  case(trace_wd_mode_ff)
    4'h0 :      begin   trace_wd[0] = {trace_free_run_cnt_ff[31:0]};
                        trace_wd[1] = {cmd_data[35:32],cmd_data[19:0],eve_data[83:80],eve_data[19:16]};
                        trace_wd[2] = {eve_data[15:0],m_axi_cd_awaddr[19:4]};
                end
//    4'h1 :      begin   trace_wd[0] = {trace_free_run_cnt_ff[31:0]};
//                        trace_wd[1] = {cmd_data[35:32],cmd_data[19:0],eve_data[83:80],eve_data[19:16]};
//                        trace_wd[2] = {eve_data[15:0],m_axi_cd_awaddr[19:4]};
//                end
//    4'h4 :      begin   trace_wd[0] = {cmd_data[35:32],cmd_data[35:32],eve_data[83:80],eve_data[83:80],
//                                       trace_free_run_cnt_ff[15:0]};
//                        trace_wd[1] = {cmd_data[11:0],cmd_data[11:0],eve_data[11:4]};
//                        trace_wd[2] = {eve_data[3:0],eve_data[11:0],m_axi_cd_awaddr[19:4]};
//                end
    default :   begin   trace_wd[0] = '0;
                        trace_wd[1] = '0;
                        trace_wd[2] = '0;
                end
  endcase
end

assign trace_wd[3] = {  (~trace_we_mode_ff[0]) & cmd_valid & cmd_ready,                                   // 31
                        (~trace_we_mode_ff[0]) & cmd_valid & cmd_ready,                                   // 30
                        (~trace_we_mode_ff[0]) & eve_valid & eve_ready,                                   // 29
                        (~trace_we_mode_ff[0]) & eve_valid & eve_ready,                                   // 28
                        (~trace_we_mode_ff[1]) & m_axi_cd_awvalid & m_axi_cd_awready,                     // 27
                        (~trace_we_mode_ff[2]) & m_axi_cd_wvalid  & m_axi_cd_wready,                      // 26
                        (~trace_we_mode_ff[3]) & a0_fifo_out_axis_tvalid & a0_fifo_out_axis_tready_i_ff,  // 25
                        a0_last_ff[a0_cid],                                                               // 24
                        m_axi_cd_awlen[3:0],                                                              // 23:20
                        m_axi_cd_bresp[1:0],                                                              // 19:18
                        a0_fifo_out_axis_tuser[7:6],                                                      // 17:16
                        1'b0, m_axi_cd_awaddr[25], CHAIN_ID[1], a0_fifo_out_axis_tuser[12],               // 15:12
                        m_axi_cd_awaddr[24:21],                                                           // 11:8
                        CHAIN_ID[0], b3_bufrd_cid_ff[CH_NUM_W-1:0],                                       // 7:4
                        a0_fifo_out_axis_tuser[11:8]};                                                    // 3:0

assign trace_we[0] = (|trace_wd[3][31:25]) & (at_me_trace_mode ? 1 : (a1_frm_marker_err_cid_vec == '0));
assign trace_we[1] = trace_we[0];
assign trace_we[2] = trace_we[0];
assign trace_we[3] = trace_we[0];

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    cif_dn_rx_base_dn_ff   <= '0;
    cif_dn_rx_base_up_ff   <= '0;

    i_ad_0700_ff           <= '0;
    i_ad_0704_ff           <= '0;
    i_ad_0708_ff           <= '0;
    i_ad_070c_ff           <= '0;
    i_ad_0710_ff           <= '0;
    i_ad_0714_ff           <= '0;
    i_ad_07e4_ff           <= '0;
    i_ad_07f8_ff           <= '0;
    i_ad_1640_ff           <= '0;
    i_ad_1644_ff           <= '0;
    i_ad_1648_ff           <= '0;
    i_ad_164c_ff           <= '0;
    for(int i=0; i<CH_NUM; i++) begin
      i_ad_1654_ff[i]      <= '0;
      i_ad_1658_ff[i]      <= '0;
      i_ad_165c_ff[i]      <= '0;
      i_ad_1660_ff[i]      <= '0;
      i_ad_1664_ff[i]      <= '0;
      i_ad_1668_ff[i]      <= '0;
    end
    i_ad_166c_ff           <= '0;
    i_ad_1670_ff           <= '0;
    i_ad_1674_ff           <= '0;
    i_ad_1678_ff           <= '0;

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
    pa13_add_val_ff        <= '0;

    trace_we_ff            <= '0;
    for(int i=0; i<4; i++) begin
      trace_wd_ff[i]       <= '0;
    end
    trace_we_mode_ff       <= '0;
    trace_wd_mode_ff       <= '0;
    trace_free_run_cnt_ff  <= '0;

  end else begin
    cif_dn_rx_base_dn_ff   <= cif_dn_rx_base_dn;
    cif_dn_rx_base_up_ff   <= cif_dn_rx_base_up;

    i_ad_0700_ff           <= i_ad_0700;
    i_ad_0704_ff           <= i_ad_0704;
    i_ad_0708_ff           <= i_ad_0708;
    i_ad_070c_ff           <= i_ad_070c;
    i_ad_0710_ff           <= i_ad_0710;
    i_ad_0714_ff           <= i_ad_0714;
    i_ad_07e4_ff           <= i_ad_07e4;
    i_ad_07f8_ff           <= i_ad_07f8;
    i_ad_1640_ff           <= i_ad_1640;
    i_ad_1644_ff           <= i_ad_1644;
    i_ad_1648_ff           <= i_ad_1648;
    i_ad_164c_ff           <= i_ad_164c;
    i_ad_1654_ff           <= i_ad_1654;
    i_ad_1658_ff           <= i_ad_1658;
    i_ad_165c_ff           <= i_ad_165c;
    i_ad_1660_ff           <= i_ad_1660;
    i_ad_1664_ff           <= i_ad_1664;
    i_ad_1668_ff           <= i_ad_1668;
    i_ad_166c_ff           <= i_ad_166c;
    i_ad_1670_ff           <= i_ad_1670;
    i_ad_1674_ff           <= i_ad_1674;
    i_ad_1678_ff           <= i_ad_1678;

    pa00_inc_enb_ff        <= pa00_inc_enb;
    pa01_inc_enb_ff        <= pa01_inc_enb;
    pa02_inc_enb_ff        <= pa02_inc_enb;
    pa03_inc_enb_ff        <= pa03_inc_enb;
    pa04_inc_enb_ff        <= pa04_inc_enb;
    pa05_inc_enb_ff        <= pa05_inc_enb;
    pa10_add_val_ff        <= pa10_add_val;
    pa11_add_val_ff        <= pa11_add_val;
    pa12_add_val_ff        <= pa12_add_val;
    pa13_add_val_ff        <= pa13_add_val;

    trace_we_ff            <= trace_we;
    trace_wd_ff            <= trace_wd;
    trace_we_mode_ff       <= trace_we_mode;
    trace_wd_mode_ff       <= trace_wd_mode;
    trace_free_run_cnt_ff  <= trace_free_run_cnt;
  end
end

endmodule
