/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`define PA_RX
`define TRACE_RX

module dma_rx #(
  parameter CH_NUM    = 32,             // 8,16,24,32 (support for dma_rx_ch_sel)
  parameter CID_WIDTH = (CH_NUM == 1 ? 1 : $clog2(CH_NUM)),
// +--------+-----------+---------------+---------------------+--------------------------+
// | CH_NUM | CID_WIDTH | m of CID[m:0] | n of ch-sig[n:0][*] | support for              |
// |        |           | = CID_WIDTH-1 | = CH_NUM-1          | dma_rx_ch_sel            |
// +--------+-----------+---------------+---------------------+--------------------------+
// |   1    |    0      |     0 (unuse) |     0               |  X                       |
// |   2    |    1      |     0         |     1               |  X                       |
// |  3- 4  |    2      |     1         |    2- 3             |  X                       |
// |  5- 8  |    3      |     2         |    4- 7             |  X[ 5- 7]       O[ 8]    |
// |  9-16  |    4      |     3         |    8-15             |  X[ 9-15]       O[16]    |
// | 17-32  |    5      |     4         |   16-31             |  X[17-23,25-31] O[24,32] |
// +--------+-----------+---------------+---------------------+--------------------------+
  parameter TAG_NUM   = 128,            // 4,8,16,32,64,128
  parameter TAG_WIDTH = $clog2(TAG_NUM)
)(
  input  logic         user_clk,
  input  logic         reset_n,

///// PCI IP
  input  logic [  2:0] cfg_max_read_req,
  input  logic [  1:0] cfg_max_payload,

///// PCI_TRX for regster
  input  logic         regreq_axis_tvalid_dmar,
  input  logic [511:0] regreq_axis_tdata,
  input  logic         regreq_axis_tlast,
  input  logic [ 63:0] regreq_axis_tuser,

  output logic         regrep_axis_tvalid_dmar,
  output logic [ 31:0] regrep_axis_tdata_dmar,

///// PCI_TRX for PA
  input  logic         dbg_enable,         // PA ENB
  input  logic         dbg_count_reset,    // PA CLR

///// PCI_TRX for TRACE
  input  logic         dma_trace_enable,   // TRACE ENB
  input  logic         dma_trace_rst,      // TRACE CLR
  input  logic [ 31:0] dbg_freerun_count,  // TRACE FREERUN COUNT

///// PCI_TRX for DMA read
  output logic         rq_dmar_rd_axis_tvalid,
  output logic [511:0] rq_dmar_rd_axis_tdata,
  output logic         rq_dmar_rd_axis_tlast,

  input  logic         rq_dmar_rd_axis_tready,

  output logic         rq_dmar_crd_axis_tvalid,
  output logic [511:0] rq_dmar_crd_axis_tdata,
  output logic         rq_dmar_crd_axis_tlast,

  input  logic         rq_dmar_crd_axis_tready,

  output logic         rq_dmar_cwr_axis_tvalid,
  output logic [511:0] rq_dmar_cwr_axis_tdata,
  output logic         rq_dmar_cwr_axis_tlast,

  input  logic         rq_dmar_cwr_axis_tready,

  input  logic         rc_axis_tvalid_dmar,
  input  logic [511:0] rc_axis_tdata,
  input  logic         rc_axis_tlast,
  input  logic [ 15:0] rc_axis_tuser,
  input  logic [ 11:0] rc_axis_taddr_dmar,

  output logic         rc_axis_tready_dmar,

///// CIF_DN for DMA read
  output logic         d2c_axis_tvalid,
  output logic [511:0] d2c_axis_tdata,
  output logic [ 15:0] d2c_axis_tuser,

  input  logic         d2c_axis_tready,

///// CIF_DN for D2D-D
  output logic [  1:0]      d2c_pkt_mode[CH_NUM-1:0],
  output logic [CH_NUM-1:0] d2c_que_wt_ack_mode2,

  input  logic [CH_NUM-1:0] d2c_que_wt_req_mode2,
  input  logic [ 31:0]      d2c_que_wt_req_ack_rp_mode2[CH_NUM-1:0],
  input  logic [ 31:0]      d2c_ack_rp_mode2[CH_NUM-1:0],

///// CIF_DN for clear
  input  logic [CH_NUM-1:0] d2c_cifd_busy,
  input  logic [CH_NUM-1:0] d2c_dmar_rd_enb,

  output logic [CH_NUM-1:0] d2c_rxch_oe,
  output logic [CH_NUM-1:0] d2c_rxch_clr,

///// EVE_ARB
  output logic [CH_NUM-1:0] dma_rx_ch_connection_enable,

///// error
  output logic error_detect_dma_rx
);

///// PCI_TRX for regster
  logic         regreq_axis_wt_flg;
  logic [ 15:0] regreq_axis_rw_addr;
  logic [ 63:0] regreq_axis_wt_data;
  logic         regreq_axis_tvalid_dmar_1tc;
  logic         regreq_axis_tvalid_dmar_pa_1tc;
  logic         regreq_axis_tvalid_dmar_npa_1tc;
  logic [ 31:0] regreq_axis_tdata_1tc;
  logic         regreq_axis_tlast_1tc;
  logic [ 32:0] regreq_axis_tuser_1tc;
  logic         regreq_axis_wt_flg_1tc;
  logic [ 15:0] regreq_axis_rw_addr_hld;
  logic [ 63:0] regreq_axis_wt_data_hld;
  logic         regrep_axis_tvalid_dmar_reg;
  logic         regrep_axis_tvalid_dmar_reg_1tc;
  logic         regrep_axis_tvalid_dmar_reg_2tc;
  logic [ 31:0] regrep_axis_tdata_dmar_reg;
  logic [ 31:0] regrep_axis_tdata_dmar_reg_1tc;
  logic [ 31:0] regrep_axis_tdata_dmar_reg_2tc;
  logic [ 31:0] regrep_axis_tdata_dmar_seld;
  logic [ 31:0] reg_dma_rx_mode0;
  logic [ 31:0] reg_dma_rx_mode1;
  logic [ 31:0] reg_dma_rx_status[2:0];
  logic [ 31:0] reg_dma_rx_ch_sel_status;
  logic [ 31:0] reg_dma_rx_ch_status[11:0];
  logic [ 31:0] reg_dma_rx_err;
  logic [ 31:0] reg_dma_rx_err_msk;
  logic         reg_dma_rx_err_detect;
  logic         reg_dma_rx_err_1wc;
  logic         reg_dma_rx_err_eg0_set;
  logic         reg_dma_rx_err_eg1_set;
  logic         reg_dma_rx_err_eg0_inj;
  logic         reg_dma_rx_err_eg1_inj;
  logic [CH_NUM-1:0] chx_dscq_rd_pe_detect;
  logic         dscq_rd_pe_detect;
  logic         pkt_rd_infoq_rd_pe_detect;
  logic         d2d_receive;
  logic [CID_WIDTH-1:0] d2d_next_cid;
  logic         d2c_axis_tlast;
  logic 	d2c_axis_tvalid_mod;
  logic 	d2c_axis_tready_mod;

///// PCI_TRX for PA
  `ifdef PA_RX
    logic       pkt_send_done;

// pa_cnt

// Register access IF //////////////////////////////////////////////////////////////////////
    // output
    logic         regrep_tvalid_pa_cnt;
    logic [ 31:0] regrep_tdata_pa_cnt;

// PA Counter /////////////////////////////////////////////////////////////////////////////
    // input
    logic [ 15:0] pa10_add_val[(CH_NUM/8)-1:0];
    logic [ 15:0] pa11_add_val[(CH_NUM/8)-1:0];
    logic [ 15:0] pa12_add_val[(CH_NUM/8)-1:0];
    logic [ 15:0] pa13_add_val[(CH_NUM/8)-1:0];

    logic         pa_enb;
    logic         pa_clr;
    logic [TAG_WIDTH:0] req_inflight_cnt;  // Number of in-flight requests
    logic [ 11:0] ram_rsvd_entry;          // Number of RAM usage entries (including reserve)
    logic [ 11:0] ram_valid_entry;         // Number of RAM valid data storage entries
  `endif

///// PCI_TRX for TRACE
  `ifdef TRACE_RX
    logic         trace_mode;
    logic         trace_we_mode;
    logic [  1:0] trace_wd_mode;
    logic         trace_enb;
    logic         trace_clr;
    logic [ 31:0] trace_free_run_cnt;
    logic         trace_we_pre0[2:0];
    logic         trace_we_pre1[2:0];
    logic [ 31:0] trace_wd_pre[3:0];
    logic         trace_we0[2:0];
    logic         trace_we1[2:0];
    logic         trace_we[3:0];         // 0 : Timestamp of receiving the first data of dsc
    logic [ 31:0] trace_wd[3:0];         // 1 : Timestamp of last data received for dsc
    logic         trace_re[3:0];         // 2 : Data size of dsc (unit:dWord)
    logic [ 31:0] trace_rd[3:0];         // 3 : [31:21] Reserved [20:16] cid[4:0]
    logic [ 31:0] trace_rd_or;           //     [15:0] mode0: task_id[15:0] mode1: Read pointer of send/receive buffer (before DMA read) [15:0]
    logic [ 31:0] trace_dscq_src_len;
    logic [ 15:0] trace_dscq_task_id_rp_pros;
    logic [ 25:0] trace_dscq_sp_pkt_num;
    logic [ 25:0] trace_dscq_sp_pkt_rcv_cnt;
    logic [TAG_WIDTH-1:0] pkt_tag_hld_3tc;
    logic         ram_we_2tc;
    logic         ram_we_pkt_tail_2tc;
    logic         ram_we_3tc;
    logic [ 10:0] ram_wp_1tc;
    logic [ 10:0] ram_wp_2tc;
    logic [  4:0] ram_wt_cycle_rcv_cnt_1tc;
    logic [  4:0] ram_wt_cycle_rcv_cnt_2tc;
    logic [CID_WIDTH-1:0] ram_wt_cid_2tc;
    logic [511:0] ram_wd_data_1tc;
    logic [511:0] ram_wd_data_2tc;
  `endif

///// PCI_TRX for DMA read

// enqdeq

// Register access IF //////////////////////////////////////////////////////////////////////
  // output
  logic [ 31:0] regreq_rdt_enqdeq;
  logic [  2:0] chx_rxch_mode[CH_NUM-1:0];
  logic [CH_NUM-1:0] rxch_ie;
  logic [CH_NUM-1:0] rxch_oe;
  logic [CH_NUM-1:0] rxch_clr;
  // input
  logic [CH_NUM-1:0] rxch_busy;

// Queue Read IF //////////////////////////////////////////////////////////////////////////
  // input
  logic [CH_NUM-1:0] que_rd_req;
  // output
  logic [CH_NUM-1:0] que_rd_dv;
  logic [127:0] que_rd_dt;

// Queue Write IF //////////////////////////////////////////////////////////////////////////
  // input
  logic [CH_NUM-1:0] que_wt_req_ff;
  logic [CH_NUM-1:0] que_wt_req;
  logic [127:0] que_wt_dt[CH_NUM-1:0];
  // output
  logic [CH_NUM-1:0] que_wt_ack;
  // other
  logic [CH_NUM-1:0] que_wt_ack_1tc;

// D2D-H/D //////////////////////////////////////////////////////////////////////////////////
  // input
  logic [ 31:0] srbuf_wp[CH_NUM-1:0];
  logic [ 31:0] srbuf_rp[CH_NUM-1:0];
  // output
  logic [ 63:0] srbuf_addr[CH_NUM-1:0];
  logic [ 31:0] srbuf_size[CH_NUM-1:0];

// PA Counter /////////////////////////////////////////////////////////////////////////////
  `ifdef PA_RX
    logic [CH_NUM-1:0] pa_item_fetch_enqdeq;
    logic [CH_NUM-1:0] pa_item_receive_dsc;
    logic [CH_NUM-1:0] pa_item_store_enqdeq;
    logic [CH_NUM-1:0] pa_item_rcv_send_d2d;
    logic [CH_NUM-1:0] pa_item_send_rcv_ack;
    logic [15:0]       pa_item_dscq_used_cnt[CH_NUM-1:0];
  `endif

// dma_rx_ch

  // input
    // setting
  logic [  2:0] ack_addr_aline_mode;
  logic         ack_send_mode;
  logic [ 63:6] chx_srbuf_addr[CH_NUM-1:0];
  logic [ 31:6] chx_srbuf_size[CH_NUM-1:0];

    // D2D-H receive
  logic         chx_srbuf_wp_update[CH_NUM-1:0];
  logic [ 31:0] d2d_wp;
  logic         d2d_frame_last;

    // DSCQ
  logic         chx_dscq_we_enq[CH_NUM-1:0];
  logic         chx_dscq_we_enq_tlast[CH_NUM-1:0];
  logic         chx_pkt_send_go[CH_NUM-1:0];
  logic         chx_ram_we_pkt_tail_1tc[CH_NUM-1:0];
  logic         chx_ram_re_dsc_last_tail[CH_NUM-1:0];
  logic         chx_que_wt_ack[CH_NUM-1:0];

  // output
    // DSCQ
  logic [  1:0] chx_dscq_wp[CH_NUM-1:0];
  logic [  1:0] chx_dscq_pkt_send_rp[CH_NUM-1:0];
  logic [  1:0] chx_dscq_rp[CH_NUM-1:0];
  logic [  2:0] chx_dscq_pcnt[CH_NUM-1:0];
  logic [  2:0] chx_dscq_ucnt[CH_NUM-1:0];
  logic         chx_dscq_full[CH_NUM-1:0];
  logic         chx_que_wt_req_pre[CH_NUM-1:0];
  logic [  2:0] chx_que_wt_req_cnt[CH_NUM-1:0];
  logic [ 31:0] chx_que_wt_task_id_rp_pros[CH_NUM-1:0];
  `ifdef TRACE_RX
    logic [ 31:0] chx_trace_dscq_src_len[CH_NUM-1:0];
    logic [ 15:0] chx_trace_dscq_task_id_rp_pros[CH_NUM-1:0];
    logic [ 25:0] chx_trace_dscq_sp_pkt_num[CH_NUM-1:0];
    logic [ 25:0] chx_trace_dscq_sp_pkt_rcv_cnt[CH_NUM-1:0];
  `endif

    // packet send
  logic         chx_pkt_send_valid[CH_NUM-1:0];
  logic [ 63:0] chx_pkt_send_pkt_addr[CH_NUM-1:0];
  logic [ 25:0] chx_pkt_num[CH_NUM-1:0];
  logic [  4:0] chx_pkt_sta_cycle[CH_NUM-1:0];
  logic [  4:0] chx_pkt_end_cycle[CH_NUM-1:0];
  logic [ 24:0] chx_pkt_send_cnt[CH_NUM-1:0];

    // status
  logic [ 31:6] chx_srbuf_wp[CH_NUM-1:0];
  logic [ 31:6] chx_srbuf_rp[CH_NUM-1:0];
  logic [ 31:6] chx_srbuf_inflight_area[CH_NUM-1:0];
  logic         chx_d2d_wp_not_update_detect[CH_NUM-1:0];

    // clear
  logic         chx_rxch_enb[CH_NUM-1:0];
  logic         chx_rxch_rd_enb[CH_NUM-1:0];
  logic         chx_rxch_clr_exec[CH_NUM-1:0];
  logic         chx_d2c_pkt_tail[CH_NUM-1:0];
  logic         chx_dmar_busy[CH_NUM-1:0];

    // error
  logic [ 31:0] chx_set_reg_dma_rx_err[CH_NUM-1:0];
  logic [CH_NUM-1:0] chx_reg_dma_rx_err_eg0_inj;

// ch common
  logic [  7:0] dsc_rx_cmd_enq;
  logic [ 63:0] dsc_src_addr_enq;
  logic [ 31:0] dsc_src_len_enq;
  logic [ 15:0] dsc_task_id_enq;
  logic         dscq_pkt_send_re;
  logic         dscq_pkt_send_re_1tc;
  logic         dscq_pkt_send_re_2tc;
  logic         d2d_wp_not_update_detect;
  logic [ 31:0] set_reg_dma_rx_err;
  logic [  2:0] cfg_max_read_req_1tc;
  logic [  1:0] cfg_max_payload_1tc;
  logic [  2:0] cfg_max_pkt_size;
  logic [  2:0] pkt_max_len_mode;
  logic [  9:0] pkt_addr_mask;
  logic [ 31:0] pkt_len_mask;
  logic         pkt_send_valid;
  logic         pkt_send_no_valid;
  logic [ 31:0] chx_lru_state[31:0];
  logic         pkt_send_valid_1tc;
  logic         pkt_send_valid_2tc;
  logic [CID_WIDTH-1:0] pkt_send_cid_2tc;
  logic         pkt_send_go;
  logic [ 63:0] pkt_send_pkt_addr;
  logic [ 25:0] pkt_num;
  logic [  4:0] pkt_sta_cycle;
  logic [  4:0] pkt_max_cycle;
  logic [  4:0] pkt_end_cycle;
  logic [  4:0] pkt_cycle;
  logic [  4:0] pkt_cycle_1tc;
  logic [TAG_WIDTH:0] tag_inflight_cnt;
  logic [ 24:0] pkt_send_cnt;
  logic [TAG_WIDTH-1:0] pkt_send_tag;
  logic         pkt_send_go_1tc;
  logic         rq_dmar_rd_axis_tvalid_pre;
  logic [TAG_WIDTH-1:0] rq_dmar_rd_axis_pkt_tag_pre;
  logic [CID_WIDTH-1:0] rq_dmar_rd_axis_pkt_cid_pre;
  logic [ 63:0] rq_dmar_rd_axis_pkt_addr_pre;
  logic [  4:0] rq_dmar_rd_axis_pkt_cycle_pre;
  logic         rq_dmar_rd_axis_pkt_dsc_last_pre;
  logic [ 25:0] rq_dmar_rd_axis_pkt_num_pre;
  logic [  1:0] rq_dmar_rd_axis_pkt_dscq_entry_pre;
  logic [TAG_WIDTH-1:0] rq_dmar_rd_axis_pkt_tag[3:0];
  logic [CID_WIDTH-1:0] rq_dmar_rd_axis_pkt_cid;
  logic [ 63:0] rq_dmar_rd_axis_pkt_addr;
  logic [  4:0] rq_dmar_rd_axis_pkt_cycle;
  logic         rq_dmar_rd_axis_pkt_dsc_last;
  logic [ 25:0] rq_dmar_rd_axis_pkt_num;
  logic [  1:0] rq_dmar_rd_axis_pkt_dscq_entry;
  logic         pkt_tag_valid;
  logic         pkt_tag_valid_set_inh;
  logic         pkt_tag_valid_1st;
  logic         pkt_tag_valid_1st_1tc;
  logic         pkt_tag_valid_for_check;
  logic         pkt_tag_valid_1tc;
  logic [TAG_WIDTH-1:0] pkt_tag_hld[3:0];
  logic [TAG_WIDTH-1:0] pkt_tag_hld_1tc[3:0];
  logic [TAG_WIDTH-1:0] pkt_tag_hld_2tc;
  logic [TAG_WIDTH-1:0] pkt_tag_hld_last;
  logic [TAG_WIDTH-1:0] pkt_tag_at_ram_wt_pre;
  logic [TAG_WIDTH-1:0] pkt_tag_at_ram_wt;
  logic [ 11:0] pkt_addr_hld;
  logic         rc_axis_tvalid_dmar_1tc;
  logic [511:0] rc_axis_tdata_hld;
  logic         rc_axis_tlast_1tc;
  logic [ 15:0] rc_axis_tuser_1tc;
  logic [ 15:0] rc_axis_tuser_2tc;
  logic         rc_axis_tlast_2tc;
  logic         rc_axis_tlast_3tc;
  logic         ram_we_pre;
  logic         ram_we;
  logic         ram_we_1tc;
  logic         ram_we_pkt_tail;
  logic         ram_set_pkt_tail_toq;
  logic         ram_we_pkt_tail_1tc;
  logic         ram_set_pkt_tail_toq_1tc;
  logic [ 10:0] ram_wp;
  logic [ 10:0] ram_wp_head;
  logic [  5:0] ram_wp_divide_pkt;
  logic [  5:0] ram_wp_divide_pkt_last;
  logic [ 11:0] ram_wt_pkt_addr;
  logic [  3:0] ram_wt_cycle_cnt;
  logic [  4:0] ram_wt_cycle_m1;
  logic [  4:0] ram_wt_cycle_rcv_cnt;
  logic         ram_wt_cycle_pkt_head;
  logic         ram_wt_cycle_pkt_tail;
  logic         ram_wt_tlast_for_check;
  logic [CID_WIDTH-1:0] ram_wt_cid;
  logic [CID_WIDTH-1:0] ram_wt_cid_1tc;
  logic [  1:0] ram_wt_dscq_entry;
  logic [  1:0] ram_wt_dscq_entry_1tc;
  logic [511:0] ram_wd_data_pre;
  logic [511:0] ram_wd_data;
  logic         pkt_divide_detect;
  logic         pkt_tag_overtake_detect;
  logic         pkt_divide_overtake_detect;

///// RAM write/read ctrl
  logic         pkt_wt_infoq_pkt_valid[TAG_NUM:0];
  logic         pkt_wt_infoq_flg[TAG_NUM:0];
  logic [CID_WIDTH-1:0] pkt_wt_infoq_cid[TAG_NUM:0];
  logic [ 11:0] pkt_wt_infoq_pkt_addr[TAG_NUM:0];
  logic [  4:0] pkt_wt_infoq_cycle_m1[TAG_NUM:-1];
  logic [ 10:0] pkt_wt_infoq_head_ram_addr[TAG_NUM:-1];
  logic [  1:0] pkt_wt_infoq_dscq_entry[TAG_NUM:0];
  logic [  4:0] pkt_wt_infoq_cycle_rcv_cnt[TAG_NUM:0];
  logic [ 31:0] pkt_rd_infoq_wd;
  logic [ 31:0] pkt_rd_infoq_rd;
  logic [ 10:0] pkt_rd_infoq_used_cnt;
  logic [CID_WIDTH-1:0] pkt_rd_infoq_cid_toq;
  logic [  4:0] pkt_rd_infoq_cycle_m1_toq;
  logic         pkt_rd_infoq_dsc_last_toq;
  logic [TAG_WIDTH-1:0] pkt_tag_shift[3:0];
  logic [TAG_WIDTH-1:0] rq_dmar_rd_axis_pkt_tag_offset[TAG_NUM-1:0];
  logic [TAG_WIDTH-1:0] pkt_tag_offset_pre;
  logic [TAG_WIDTH-1:0] pkt_tag_offset[TAG_NUM-1:0];
  logic [TAG_WIDTH-1:0] pkt_tag_offset_for_ram_wt[3:0];

///// RAM resource ctrl
  logic [ 11:0] ram_nrsvd_entry;
  logic [ 11:0] ram_empty_entry;
  logic [ 11:0] ram_pkt_continue_cnt;

///// CIF_DN for DMA read
  logic         ram_re;
  logic         ram_re_pkt_tail;
  logic         ram_re_dsc_last_tail;
  logic [ 10:0] ram_rp;
  logic [  3:0] ram_rd_cycle_cnt;
  logic [511:0] ram_rd_data;
  logic [511:480] d2c_axis_tdata_hld;
  logic         d2c_axis_tvalid_pre;
  logic         d2c_axis_tlast_pre;
  logic [CID_WIDTH-1:0] d2c_axis_cid_pre;
  logic         d2c_axis_sop_pre;
  logic         d2c_axis_eop_pre;
  logic [  4:0] d2c_axis_burst_pre;
  logic [CID_WIDTH-1:0] d2c_axis_cid;
  logic         d2c_axis_sop;
  logic         d2c_axis_eop;
  logic [  4:0] d2c_axis_burst;
  logic [  7:0] d2c_axis_wait_cnt;
  logic         d2c_pkt_tail;

///// CIF_DN for clear
  logic [CH_NUM-1:0] rxch_enb;
  logic [CH_NUM-1:0] rxch_rd_enb;
  logic [CH_NUM-1:0] rxch_clr_exec;
  logic [CH_NUM-1:0] dmar_busy;

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin

///// PCI_TRX for regster
      regreq_axis_tvalid_dmar_1tc     <= '0;
      regreq_axis_tvalid_dmar_pa_1tc  <= '0;
      regreq_axis_tvalid_dmar_npa_1tc <= '0;
      regreq_axis_tdata_1tc           <= '0;
      regreq_axis_tlast_1tc           <= '0;
      regreq_axis_tuser_1tc           <= '0;
      regreq_axis_wt_flg_1tc          <= '0;
      regreq_axis_rw_addr_hld         <= '0;
      regreq_axis_wt_data_hld         <= '0;
      regrep_axis_tvalid_dmar_reg_1tc <= '0;
      regrep_axis_tvalid_dmar_reg_2tc <= '0;
      regrep_axis_tvalid_dmar         <= '0;
      regrep_axis_tdata_dmar_reg_1tc  <= '0;
      regrep_axis_tdata_dmar_reg_2tc  <= '0;
      regrep_axis_tdata_dmar          <= '0;
      reg_dma_rx_mode0                <= 32'h23;
      reg_dma_rx_mode1                <= '0;
      reg_dma_rx_err                  <= '0;
      reg_dma_rx_err_msk              <= '0;
      reg_dma_rx_err_detect           <= '0;
      reg_dma_rx_err_1wc              <= '0;
      reg_dma_rx_err_eg0_set          <= '0;
      reg_dma_rx_err_eg1_set          <= '0;
      reg_dma_rx_err_eg0_inj          <= '0;
      reg_dma_rx_err_eg1_inj          <= '0;
      pkt_rd_infoq_rd_pe_detect       <= '0;
      d2d_receive                     <= '0;
      d2d_next_cid                    <= '0;
      d2d_wp                          <= '0;
      d2d_frame_last                  <= '0;

///// PCI_TRX for PA
      `ifdef PA_RX
        pa_enb                        <= '0;
        pa_clr                        <= '0;
        req_inflight_cnt              <= '0;
      `endif

///// PCI_TRX for TRACE
      `ifdef TRACE_RX
        trace_enb                     <= '0;
        trace_clr                     <= '0;
        trace_free_run_cnt            <= '0;
        for (int i = 0; i < 2; i++) begin
          trace_we0[i]                <= '0;
          trace_we1[i]                <= '0;
        end
        for (int i = 0; i < 4; i++) begin
          trace_wd[i][31:0]           <= '0;
        end
        trace_dscq_src_len            <= '0;
        trace_dscq_task_id_rp_pros    <= '0;
        trace_dscq_sp_pkt_num         <= '0;
        trace_dscq_sp_pkt_rcv_cnt     <= '0;
        pkt_tag_hld_3tc               <= '0;
        ram_we_2tc                    <= '0;
        ram_we_pkt_tail_2tc           <= '0;
        ram_we_3tc                    <= '0;
        ram_wp_1tc                    <= '0;
        ram_wp_2tc                    <= '0;
        ram_wd_data_1tc               <= '0;
        ram_wd_data_2tc               <= '0;
        ram_wt_cycle_rcv_cnt_1tc      <= '0;
        ram_wt_cycle_rcv_cnt_2tc      <= '0;
        ram_wt_cid_2tc                <= '0;
      `endif

///// PCI_TRX for DMA read
      cfg_max_read_req_1tc            <= '0;
      cfg_max_payload_1tc             <= '0;
      dscq_pkt_send_re_1tc            <= '0;
      dscq_pkt_send_re_2tc            <= '0;
      pkt_max_len_mode                <= '0;
      pkt_max_cycle                   <= '0;
      pkt_addr_mask                   <= '0;
      pkt_len_mask                    <= '0;
      pkt_cycle_1tc                   <= '0;
      tag_inflight_cnt                <= '0;
      pkt_send_valid_1tc              <= '0;
      pkt_send_valid_2tc              <= '0;
      pkt_send_tag                    <= '0;
      pkt_send_go_1tc                 <= '0;
      rq_dmar_rd_axis_tvalid          <= '0;
      for (int i = 0; i < 4; i++) begin
        rq_dmar_rd_axis_pkt_tag[i][TAG_WIDTH-1:0] <= '0;
      end
      if (CH_NUM > 1) begin
        rq_dmar_rd_axis_pkt_cid       <= '0;
      end
      rq_dmar_rd_axis_pkt_addr        <= '0;
      rq_dmar_rd_axis_pkt_cycle       <= '0;
      rq_dmar_rd_axis_pkt_dsc_last    <= '0;
      rq_dmar_rd_axis_pkt_num         <= '0;
      rq_dmar_rd_axis_pkt_dscq_entry  <= '0;
      pkt_tag_valid                   <= '0;
      pkt_tag_valid_set_inh           <= '0;
      pkt_tag_valid_1st               <= '0;
      pkt_tag_valid_1st_1tc           <= '0;
      pkt_tag_valid_for_check         <= '0;
      pkt_tag_valid_1tc               <= '0;
      pkt_tag_at_ram_wt_pre           <= '0;
      pkt_tag_at_ram_wt               <= '0;
      for (int i = 0; i < 4; i++) begin
        pkt_tag_hld[i][TAG_WIDTH-1:0] <= '0;
        pkt_tag_hld_1tc[i][TAG_WIDTH-1:0] <= '0;
      end
      pkt_tag_hld_2tc                 <= '0;
      pkt_tag_hld_last                <= '0;
      pkt_addr_hld                    <= '0;
      rc_axis_tvalid_dmar_1tc         <= '0;
      rc_axis_tlast_1tc               <= '0;
      rc_axis_tuser_1tc               <= '0;
      rc_axis_tlast_2tc               <= '0;
      rc_axis_tlast_3tc               <= '0;
      rc_axis_tdata_hld               <= '0;
      ram_we_pre                      <= '0;
      ram_we                          <= '0;
      ram_we_1tc                      <= '0;
      ram_we_pkt_tail_1tc             <= '0;
      ram_set_pkt_tail_toq_1tc        <= '0;
      ram_wp                          <= '0;
      ram_wp_head                     <= '0;
      ram_wp_divide_pkt               <= '0;
      ram_wp_divide_pkt_last          <= '0;
      ram_wt_pkt_addr                 <= '0;
      ram_wt_cycle_cnt                <= '0;
      ram_wt_cycle_rcv_cnt            <= '0;
      ram_wt_cycle_m1                 <= '0;
      if (CH_NUM > 1) begin
        ram_wt_cid_1tc                <= '0;
      end
      ram_wt_dscq_entry_1tc           <= '0;
      ram_wt_tlast_for_check          <= '0;
      ram_wd_data_pre                 <= '0;
      ram_wd_data                     <= '0;
      pkt_divide_detect               <= '0;
      pkt_tag_overtake_detect         <= '0;
      pkt_divide_overtake_detect      <= '0;

// enqdeq
      for (int i = 0; i < CH_NUM; i++) begin
        que_wt_req_ff[i]              <= '0;
        que_wt_dt[i][127:0]           <= '0;
        que_wt_ack_1tc[i]             <= '0;
      end

////// RAM write/read ctrl
      for (int i = 0; i < TAG_NUM+1; i++) begin
        pkt_wt_infoq_pkt_valid[i]            <= '0;
        pkt_wt_infoq_flg[i]                  <= '0;
        if (CH_NUM > 1) begin
          pkt_wt_infoq_cid[i][CID_WIDTH-1:0] <= '0;
        end
        pkt_wt_infoq_pkt_addr[i][11:0]       <= '0;
        pkt_wt_infoq_cycle_m1[i][4:0]        <= '0;
        pkt_wt_infoq_head_ram_addr[i][10:0]  <= '0;
        pkt_wt_infoq_dscq_entry[i][1:0]      <= '0;
        pkt_wt_infoq_cycle_rcv_cnt[i][4:0]   <= '0;
      end
      pkt_wt_infoq_cycle_m1[-1][4:0]         <= 5'h1F;
      pkt_wt_infoq_head_ram_addr[-1][10:0]   <= '0;
      for (int i = 0; i < 4; i++) begin
        pkt_tag_shift[i][TAG_WIDTH-1:0]      <= '0;
      end

///// RAM resource ctrl
      ram_nrsvd_entry                 <= 12'h800;
      ram_empty_entry                 <= 12'h800;
      ram_pkt_continue_cnt            <= '0;

///// CIF_DN for DMA read
      ram_rp                          <= '0;
      ram_rd_cycle_cnt                <= '0;
      d2c_axis_tvalid_pre             <= '0;
      d2c_axis_tlast_pre              <= '0;
      if (CH_NUM > 1) begin
        d2c_axis_cid_pre              <= '0;
      end
      d2c_axis_sop_pre                <= '0;
      d2c_axis_eop_pre                <= '0;
      d2c_axis_burst_pre              <= '0;
      d2c_axis_tvalid_mod             <= '0;
      d2c_axis_tlast                  <= '0;
      d2c_axis_tdata                  <= '0;
      d2c_axis_tdata_hld              <= '0;
      if (CH_NUM > 1) begin
        d2c_axis_cid                  <= '0;
      end
      d2c_axis_sop                    <= '0;
      d2c_axis_eop                    <= '0;
      d2c_axis_burst                  <= '0;
      d2c_axis_wait_cnt               <= '0;

///// CIF_DN for clear
      rxch_enb                        <= '0;
      rxch_rd_enb                     <= '0;
      rxch_clr_exec                   <= '0;

    end else begin

///// PCI_TRX for regster
      regreq_axis_tvalid_dmar_1tc     <=  regreq_axis_tvalid_dmar;
      regreq_axis_tvalid_dmar_pa_1tc  <= (regreq_axis_tvalid_dmar & (((regreq_axis_tuser[15:0] == 16'h1238) || (regreq_axis_tuser[15:7] == 9'h025)|| ((regreq_axis_tuser[15:7] == 9'h027) && (regreq_axis_tuser[6:5] != 2'h3))) ?1:0));
      regreq_axis_tvalid_dmar_npa_1tc <= (regreq_axis_tvalid_dmar & (((regreq_axis_tuser[15:0] == 16'h1238) || (regreq_axis_tuser[15:7] == 9'h025)|| ((regreq_axis_tuser[15:7] == 9'h027) && (regreq_axis_tuser[6:5] != 2'h3))) ?0:1));
      regreq_axis_tdata_1tc <= regreq_axis_tdata[31:0];
      regreq_axis_tlast_1tc <= regreq_axis_tlast;
      regreq_axis_tuser_1tc <= regreq_axis_tuser[32:0];
      regreq_axis_wt_flg_1tc <= regreq_axis_wt_flg;
      if (regreq_axis_tvalid_dmar == 1'b1) begin
        regreq_axis_rw_addr_hld <= regreq_axis_rw_addr;
        if (regreq_axis_wt_flg == 1'b1) begin
          regreq_axis_wt_data_hld <= regreq_axis_wt_data;
        end
      end
      if (regreq_axis_tvalid_dmar_npa_1tc == 1'b1) begin
        if (regreq_axis_wt_flg_1tc == 1'b1) begin
          case (regreq_axis_rw_addr_hld)
// dma_rx_ctrl
//          16'h020C : "ENQDEQ : rxch_sel";
//          16'h0210 : "ENQDEQ : rxch_ctrl0";
//          16'h0214 : "ENQDEQ : rxch_ctrl1";
//          16'h0220 : "ENQDEQ : enq_ctrl / prev_fpga_ctrl";
//          16'h0228 : "ENQDEQ : enq_addr_dn / prev_fpga_addr_dn";
//          16'h022C : "ENQDEQ : enq_addr_up / prev_fpga_addr_up";
//          16'h0238 : "ENQDEQ : srbuf_addr_dn";
//          16'h023C : "ENQDEQ : srbuf_addr_up";
//          16'h0240 : "ENQDEQ : srbuf_size";
// dma_rx_err
            16'h03E0 : reg_dma_rx_err_1wc <= regreq_axis_wt_data_hld[0];
            16'h03F4 : reg_dma_rx_err_msk <= regreq_axis_wt_data_hld[31:0];
            16'h03FC : begin
                       reg_dma_rx_err_eg0_set <= regreq_axis_wt_data_hld[0];
                       reg_dma_rx_err_eg1_set <= regreq_axis_wt_data_hld[1];
                       end
// dma_rx_mode
            16'h1200 : reg_dma_rx_mode0 <= regreq_axis_wt_data_hld[31:0];
            16'h1204 : reg_dma_rx_mode1 <= regreq_axis_wt_data_hld[31:0];
//          16'h1234 : "ENQDEQ : rxch_clr_mode";
//          16'h1238 : "PA_CNT : rxch_sel_pa";
//          16'h123C : "ENQDEQ : polling_interval1/2";
// dma_rx_dbg_rd
//          16'h1340 : "ENQDEQ : 31'h0,enb"
//          16'h1348 : "ENQDEQ : addr[31:6],6'h00"
//          16'h134C : "ENQDEQ : addr[63:32]"
// dma_rx_pa
//          16'h13A0 : "PA_CNT : PA14 : Select PA00-09 that should be counted for each CH"
//          16'h13A4 : "PA_CNT : PA15 : Select PA00-09 that should be counted for each CH"
//          16'h13A8 : "PA_CNT : PA16 : Select PA00-09 that should be counted for each CH"
//          16'h13AC : "PA_CNT : PA17 : Select PA00-09 that should be counted for each CH"
// D2D-H
            16'h1E00 : begin d2d_receive <= 1'b1; d2d_wp <= regreq_axis_wt_data_hld[63:32];
                             d2d_frame_last <= regreq_axis_wt_data_hld[24];
                             d2d_next_cid <= regreq_axis_wt_data_hld[CID_WIDTH+15:16]; end
            default  : ;
          endcase
        end
        if ((reg_dma_rx_err[0] == 1'b0) && (reg_dma_rx_err_msk[0] == 1'b0) && (regreq_axis_tlast_1tc == 1'b0)) begin
          reg_dma_rx_err[0] <= 1'b1; // reg_dma_rx_err_regreq_tlast_lost
        end
      end
      if (reg_dma_rx_err_1wc == 1'b1 && ~(regreq_axis_tvalid_dmar_1tc == 1'b1 && regreq_axis_wt_flg_1tc == 1'b1
          && regreq_axis_rw_addr_hld == 16'h03E0 && regreq_axis_wt_data_hld[0] == 1'b1)) begin
        reg_dma_rx_err_1wc <= 1'b0;
      end
      if (d2d_receive == 1'b1 && ~(regreq_axis_tvalid_dmar_1tc == 1'b1 && regreq_axis_wt_flg_1tc == 1'b1
          && regreq_axis_rw_addr_hld == 16'h1E00)) begin
        d2d_receive <= 1'b0;
      end
      regrep_axis_tvalid_dmar_reg_1tc <= regrep_axis_tvalid_dmar_reg;
      regrep_axis_tvalid_dmar_reg_2tc <= regrep_axis_tvalid_dmar_reg_1tc;
      regrep_axis_tdata_dmar_reg_1tc  <= regrep_axis_tdata_dmar_reg;
      regrep_axis_tdata_dmar_reg_2tc  <= (regrep_axis_tdata_dmar_reg_1tc  | regreq_rdt_enqdeq);
      `ifdef PA_RX
        regrep_axis_tvalid_dmar       <= (regrep_axis_tvalid_dmar_reg_2tc | regrep_tvalid_pa_cnt);
        regrep_axis_tdata_dmar        <= (regrep_axis_tdata_dmar_seld     | regrep_tdata_pa_cnt);
      `else
        regrep_axis_tvalid_dmar       <= regrep_axis_tvalid_dmar_reg_2tc;
        regrep_axis_tdata_dmar        <= regrep_axis_tdata_dmar_seld;
      `endif

///// PCI_TRX for PA
      `ifdef PA_RX
        pa_enb <= dbg_enable;
        pa_clr <= dbg_count_reset;
        if ((pkt_send_done == 1'b1) && (d2c_pkt_tail == 1'b0)) begin
          req_inflight_cnt <= (req_inflight_cnt + {{(TAG_WIDTH){1'b0}},1'b1});
        end if ((pkt_send_done == 1'b0) && (d2c_pkt_tail == 1'b1)) begin
          req_inflight_cnt <= (req_inflight_cnt - {{(TAG_WIDTH){1'b0}},1'b1});
        end
      `endif

///// PCI_TRX for TRACE
      `ifdef TRACE_RX
        trace_enb <= dma_trace_enable;
        trace_clr <= dma_trace_rst;
        trace_free_run_cnt <= dbg_freerun_count;
        for (int i = 0; i < 3; i++) begin
          trace_we0[i] <= trace_we_pre0[i];
          trace_we1[i] <= trace_we_pre1[i];
        end
        for (int i = 0; i < 4; i++) begin
          trace_wd[i][31:0] <= trace_wd_pre[i][31:0];
        end
        if (CH_NUM == 1) begin
          trace_dscq_src_len         <= chx_trace_dscq_src_len[0][31:0]                     ; // trace
          trace_dscq_task_id_rp_pros <= chx_trace_dscq_task_id_rp_pros[0][15:0]             ; // trace
          trace_dscq_sp_pkt_num      <= chx_trace_dscq_sp_pkt_num[0][25:0]                  ; // trace
          trace_dscq_sp_pkt_rcv_cnt  <= chx_trace_dscq_sp_pkt_rcv_cnt[0][25:0]              ; // trace
        end else begin
          trace_dscq_src_len         <= chx_trace_dscq_src_len[ram_wt_cid_1tc][31:0]        ; // trace
          trace_dscq_task_id_rp_pros <= chx_trace_dscq_task_id_rp_pros[ram_wt_cid_1tc][15:0]; // trace
          trace_dscq_sp_pkt_num      <= chx_trace_dscq_sp_pkt_num[ram_wt_cid_1tc][25:0]     ; // trace
          trace_dscq_sp_pkt_rcv_cnt  <= chx_trace_dscq_sp_pkt_rcv_cnt[ram_wt_cid_1tc][25:0] ; // trace
        end
        ram_we_2tc <= ram_we_1tc;
        ram_we_pkt_tail_2tc <= ram_we_pkt_tail_1tc;
        ram_we_3tc <= ram_we_2tc;
        ram_wp_1tc <= ram_wp;
        ram_wp_2tc <= ram_wp_1tc;
        ram_wd_data_1tc <= ram_wd_data;
        ram_wd_data_2tc <= ram_wd_data_1tc;
        ram_wt_cycle_rcv_cnt_1tc <= ram_wt_cycle_rcv_cnt;
        ram_wt_cycle_rcv_cnt_2tc <= ram_wt_cycle_rcv_cnt_1tc;
        ram_wt_cid_2tc <= ram_wt_cid_1tc;
      `endif

///// PCI_TRX for DMA read
      cfg_max_read_req_1tc <= cfg_max_read_req;
      cfg_max_payload_1tc <= cfg_max_payload;
      dscq_pkt_send_re_1tc <= dscq_pkt_send_re;
      dscq_pkt_send_re_2tc <= dscq_pkt_send_re_1tc;
      if ((reg_dma_rx_mode0[3] == 1'b0) && (reg_dma_rx_mode0[2:0] > (cfg_max_pkt_size + 3'h1))) begin
        pkt_max_len_mode <= (cfg_max_pkt_size + 3'h1);
      end else begin
        pkt_max_len_mode <= reg_dma_rx_mode0[2:0];
      end
      case (pkt_max_len_mode)
        3'h0    : begin pkt_addr_mask <= 10'h000; pkt_len_mask <= 32'h000; end //  64B
        3'h1    : begin pkt_addr_mask <= 10'h040; pkt_len_mask <= 32'h040; end // 128B
        3'h2    : begin pkt_addr_mask <= 10'h0C0; pkt_len_mask <= 32'h0C0; end // 256B
        3'h3    : begin pkt_addr_mask <= 10'h1C0; pkt_len_mask <= 32'h1C0; end // 512B
        3'h4    : begin pkt_addr_mask <= 10'h3C0; pkt_len_mask <= 32'h3C0; end //  1KB
        default : begin pkt_addr_mask <= 10'h000; pkt_len_mask <= 32'h000; end
      endcase
      pkt_max_cycle <= 5'h01 << pkt_max_len_mode;
      if ((rq_dmar_rd_axis_tvalid == 1'b0) || (rq_dmar_rd_axis_tready == 1'b1)) begin
        rq_dmar_rd_axis_tvalid <= rq_dmar_rd_axis_tvalid_pre;
        if (rq_dmar_rd_axis_tvalid_pre == 1'b1) begin
          for (int i = 0; i < 4; i++) begin
            rq_dmar_rd_axis_pkt_tag[i][TAG_WIDTH-1:0] <= rq_dmar_rd_axis_pkt_tag_pre;
          end
          if (CH_NUM > 1) begin
            rq_dmar_rd_axis_pkt_cid <= rq_dmar_rd_axis_pkt_cid_pre;
          end
          rq_dmar_rd_axis_pkt_addr <= rq_dmar_rd_axis_pkt_addr_pre;
          rq_dmar_rd_axis_pkt_cycle <= rq_dmar_rd_axis_pkt_cycle_pre;
          rq_dmar_rd_axis_pkt_dsc_last <= rq_dmar_rd_axis_pkt_dsc_last_pre;
          rq_dmar_rd_axis_pkt_num <= rq_dmar_rd_axis_pkt_num_pre;
          rq_dmar_rd_axis_pkt_dscq_entry <= rq_dmar_rd_axis_pkt_dscq_entry_pre;
        end else begin
          rq_dmar_rd_axis_pkt_dsc_last <= 1'b0;
        end
      end
      if ((pkt_send_go == 1'b1) && (ram_set_pkt_tail_toq == 1'b0)) begin
        tag_inflight_cnt <= (tag_inflight_cnt + {{(TAG_WIDTH){1'b0}},1'b1});
      end else if ((pkt_send_go == 1'b0) && (ram_set_pkt_tail_toq == 1'b1)) begin
        tag_inflight_cnt <= (tag_inflight_cnt - {{(TAG_WIDTH){1'b0}},1'b1});
      end
      if ((reg_dma_rx_err[5] == 1'b0) && (reg_dma_rx_err_msk[5] == 1'b0) && (tag_inflight_cnt == {(TAG_WIDTH+1){1'b0}}) && (ram_set_pkt_tail_toq == 1'b1)) begin
        reg_dma_rx_err[5] <= 1'b1; // reg_dma_rx_err_tag_inflight_cnt
      end
      pkt_send_valid_1tc <= pkt_send_valid;
      pkt_send_valid_2tc <= pkt_send_valid_1tc;
      pkt_cycle_1tc <= pkt_cycle;
      if (pkt_send_go == 1'b1) begin
        pkt_send_tag <= (pkt_send_tag + {{(TAG_WIDTH-1){1'b0}},1'b1});
      end

// enqdeq
      for (int i = 0; i < CH_NUM; i++) begin
        if (chx_rxch_mode[i][2:0] == 3'h0) begin
          que_wt_req_ff[i]        <= chx_que_wt_req_pre[i];
          que_wt_dt[i][127:0]     <= {112'h2,chx_que_wt_task_id_rp_pros[i][15:0]};
        end else if (chx_rxch_mode[i][2:0] == 3'h1) begin
          que_wt_req_ff[i]        <= chx_que_wt_req_pre[i];
          que_wt_dt[i][127:0]     <= {64'h0,chx_que_wt_task_id_rp_pros[i][31:0],32'h0};
        end else if (chx_rxch_mode[i][2:0] == 3'h2) begin
          que_wt_req_ff[i]        <= d2c_que_wt_req_mode2[i];
          que_wt_dt[i][127:0]     <= {64'h0,d2c_que_wt_req_ack_rp_mode2[i][31:0],32'h0};
        end else begin
          que_wt_req_ff[i]        <= 1'b0;
          que_wt_dt[i][127:0]     <= 128'h0;
        end
        que_wt_ack_1tc[i]         <= que_wt_ack[i];
      end

///// RAM write/read ctrl
      pkt_send_go_1tc <= pkt_send_go;
      if (pkt_send_go_1tc == 1'b1) begin
        for (int i = 0; i < TAG_NUM; i++) begin
          if (rq_dmar_rd_axis_pkt_tag_offset[i][TAG_WIDTH-1:0] == i) begin
            pkt_wt_infoq_flg[i-ram_set_pkt_tail_toq] <= 1'b1;
            if ((reg_dma_rx_err[6] == 1'b0) && (reg_dma_rx_err_msk[6] == 1'b0) && ((pkt_wt_infoq_flg[i] == 1'b1) || (i == 0 && ram_set_pkt_tail_toq == 1'b1))) begin
              reg_dma_rx_err[6] <= 1'b1; // reg_dma_rx_err_pkt_wt_infoq_set
            end
            if (CH_NUM > 1) begin
              pkt_wt_infoq_cid[i-ram_set_pkt_tail_toq][CID_WIDTH-1:0] <= rq_dmar_rd_axis_pkt_cid;
            end
            pkt_wt_infoq_pkt_addr[i-ram_set_pkt_tail_toq][11:0] <= rq_dmar_rd_axis_pkt_addr[11:0];
            pkt_wt_infoq_cycle_m1[i-ram_set_pkt_tail_toq][4:0] <= (rq_dmar_rd_axis_pkt_cycle - 5'h01);
            pkt_wt_infoq_head_ram_addr[i-ram_set_pkt_tail_toq][10:0] <= (pkt_wt_infoq_head_ram_addr[i-1][10:0] + {6'h00,pkt_wt_infoq_cycle_m1[i-1][4:0] + 5'h01});
            pkt_wt_infoq_dscq_entry[i-ram_set_pkt_tail_toq][1:0] <= rq_dmar_rd_axis_pkt_dscq_entry;
            pkt_wt_infoq_cycle_rcv_cnt[i-ram_set_pkt_tail_toq][4:0] <= 5'h00;
          end
        end
      end
      if (ram_set_pkt_tail_toq == 1'b1) begin
        for (int i = 0; i < TAG_NUM; i++) begin
          if ((ram_we_pkt_tail == 1'b0) || (i != pkt_tag_offset_for_ram_wt[i][TAG_WIDTH-1:0] - {{(TAG_WIDTH-1){1'b0}},1'b1})) begin
            pkt_wt_infoq_pkt_valid[i] <= pkt_wt_infoq_pkt_valid[i+1];
          end
          if ((pkt_send_go_1tc == 1'b0) || (i != rq_dmar_rd_axis_pkt_tag_offset[i][TAG_WIDTH-1:0] - {{(TAG_WIDTH-1){1'b0}},1'b1})) begin
            pkt_wt_infoq_flg[i] <= pkt_wt_infoq_flg[i+1];
            if (CH_NUM > 1) begin
              pkt_wt_infoq_cid[i][CID_WIDTH-1:0] <= pkt_wt_infoq_cid[i+1][CID_WIDTH-1:0];
            end
            pkt_wt_infoq_pkt_addr[i][11:0] <= pkt_wt_infoq_pkt_addr[i+1][11:0];
            pkt_wt_infoq_cycle_m1[i][4:0] <= pkt_wt_infoq_cycle_m1[i+1][4:0];
            pkt_wt_infoq_head_ram_addr[i][10:0] <= pkt_wt_infoq_head_ram_addr[i+1][10:0];
            pkt_wt_infoq_dscq_entry[i][1:0] <= pkt_wt_infoq_dscq_entry[i+1][1:0];
            pkt_wt_infoq_cycle_rcv_cnt[i][4:0] <= pkt_wt_infoq_cycle_rcv_cnt[i+1][4:0];
          end
        end
        pkt_wt_infoq_cycle_m1[-1][4:0] <= pkt_wt_infoq_cycle_m1[0][4:0];
        pkt_wt_infoq_head_ram_addr[-1][10:0] <= pkt_wt_infoq_head_ram_addr[0][10:0];
        for (int i = 0; i < 4; i++) begin
          pkt_tag_shift[i][TAG_WIDTH-1:0] <= (pkt_tag_shift[i][TAG_WIDTH-1:0] + {{(TAG_WIDTH-1){1'b0}},1'b1});
        end
      end

///// PCI_TRX for DMA read
      rc_axis_tvalid_dmar_1tc <= rc_axis_tvalid_dmar;
      rc_axis_tlast_1tc <= rc_axis_tlast;
      rc_axis_tlast_2tc <= rc_axis_tlast_1tc;
      rc_axis_tlast_3tc <= rc_axis_tlast_2tc;
      rc_axis_tuser_1tc <= rc_axis_tuser;
      pkt_tag_valid_1st_1tc <= pkt_tag_valid_1st;
      pkt_tag_valid_1tc <= pkt_tag_valid;
      for (int i = 0; i < 4; i++) begin
        pkt_tag_hld_1tc[i][TAG_WIDTH-1:0] <= pkt_tag_hld[i][TAG_WIDTH-1:0];
      end
      pkt_tag_hld_2tc <= pkt_tag_hld_1tc[0][TAG_WIDTH-1:0];
      `ifdef TRACE_RX
         pkt_tag_hld_3tc <= pkt_tag_hld_2tc;
      `endif
      pkt_tag_at_ram_wt_pre <= rc_axis_tuser_1tc[TAG_WIDTH+7:8];
      pkt_tag_at_ram_wt <= pkt_tag_at_ram_wt_pre;
      ram_we_pre <= (rc_axis_tvalid_dmar_1tc & rc_axis_tuser_1tc[15]);
      ram_we <= ram_we_pre;
      ram_we_1tc <= ram_we;
      ram_we_pkt_tail_1tc <= ram_we_pkt_tail;
      ram_set_pkt_tail_toq_1tc <= ram_set_pkt_tail_toq;
      ram_wt_pkt_addr <= pkt_wt_infoq_pkt_addr[{1'b0,pkt_tag_offset[0][TAG_WIDTH-1:0]}][11:0];
      ram_wt_cycle_m1 <= pkt_wt_infoq_cycle_m1[{1'b0,pkt_tag_offset_for_ram_wt[0][TAG_WIDTH-1:0]}][4:0];
      ram_wt_cycle_rcv_cnt <= pkt_wt_infoq_cycle_rcv_cnt[{1'b0,pkt_tag_offset_for_ram_wt[0][TAG_WIDTH-1:0]}][4:0];
      ram_wt_dscq_entry_1tc <= ram_wt_dscq_entry;
      if (CH_NUM > 1) begin
        ram_wt_cid_1tc <= ram_wt_cid;
      end
      if ((rc_axis_tvalid_dmar == 1'b1) && (rc_axis_tuser[15] == 1'b1)) begin
        if (((rc_axis_tvalid_dmar_1tc == 1'b0) || (rc_axis_tuser_1tc[15] == 1'b0)) && (pkt_tag_valid_set_inh == 1'b0)) begin
          pkt_tag_valid <= 1'b1;
          if (rc_axis_tlast == 1'b0) begin
            pkt_tag_valid_set_inh <= 1'b1;
          end
          pkt_tag_valid_1st <= 1'b1;
          for (int i = 0; i < 4; i++) begin
            pkt_tag_hld[i][TAG_WIDTH-1:0] <= rc_axis_tuser[TAG_WIDTH+7:8];
          end
          pkt_addr_hld <= rc_axis_taddr_dmar;
          if (pkt_tag_valid_for_check == 1'b0) begin
            pkt_tag_valid_for_check <= 1'b1;
          end else begin
            if ((rc_axis_tuser[TAG_WIDTH+7:8] != pkt_tag_hld[0][TAG_WIDTH-1:0]) && (rc_axis_tuser[TAG_WIDTH+7:8] != pkt_tag_hld[0][TAG_WIDTH-1:0] + {{(TAG_WIDTH-1){1'b0}},1'b1})) begin
              pkt_tag_overtake_detect <= 1'b1;
            end
          end
          if ((reg_dma_rx_err[7] == 1'b0) && (reg_dma_rx_err_msk[7] == 1'b0) && (pkt_wt_infoq_flg[{1'b0,pkt_tag_offset_pre}] == 1'b0)) begin
            reg_dma_rx_err[7] <= 1'b1; // reg_dma_rx_err_ram_wt_flg_lost
          end
        end
        if ((rc_axis_tlast == 1'b1) && (pkt_tag_valid_set_inh == 1'b1)) begin
          pkt_tag_valid_set_inh <= 1'b0;
        end
        rc_axis_tdata_hld <= rc_axis_tdata;
      end
      if ((rc_axis_tvalid_dmar_1tc == 1'b1) && (rc_axis_tuser_1tc[15] == 1'b1)) begin
        ram_wd_data_pre <= rc_axis_tdata_hld;
      end
      if (ram_we_pre == 1'b1) begin
        ram_wd_data <= ram_wd_data_pre;
      end
      if (pkt_tag_valid_1st == 1'b1) begin
        pkt_tag_valid_1st <= 1'b0;
        ram_wp_head <= pkt_wt_infoq_head_ram_addr[{1'b0,pkt_tag_offset[0][TAG_WIDTH-1:0]}][10:0];
      end
      if (pkt_tag_valid_1st_1tc == 1'b1) begin
        if (pkt_addr_hld[11:6] >= ram_wt_pkt_addr[11:6]) begin
          ram_wp <= (ram_wp_head + {5'h00,pkt_addr_hld[11:6] -  ram_wt_pkt_addr[11:6]});
          ram_wp_divide_pkt <= (pkt_addr_hld[11:6] -  ram_wt_pkt_addr[11:6]);
        end else begin
          ram_wp <= (ram_wp_head + {5'h00,pkt_addr_hld[11:6] + ~ram_wt_pkt_addr[11:6] + 6'h01});
          ram_wp_divide_pkt <= (pkt_addr_hld[11:6] + ~ram_wt_pkt_addr[11:6] + 6'h01);
        end
        if ((reg_dma_rx_err[13] == 1'b0) && (reg_dma_rx_err_msk[13] == 1'b0) && (pkt_addr_hld[5:0] > 6'h00)) begin
          reg_dma_rx_err[13] <= 1'b1; // reg_dma_rx_err_pkt_divide_err
        end
      end
      if ((ram_we_pre == 1'b1) && (rc_axis_tlast_2tc == 1'b1) && ((rc_axis_tvalid_dmar == 1'b0) || (rc_axis_tuser[15] == 1'b0))) begin
        pkt_tag_valid <= 1'b0;
      end
      if (ram_we == 1'b1) begin
        pkt_wt_infoq_cycle_rcv_cnt[{1'b0,pkt_tag_offset_for_ram_wt[2][TAG_WIDTH-1:0]} - {{(TAG_WIDTH){1'b0}},ram_set_pkt_tail_toq}][4:0] <= (pkt_wt_infoq_cycle_rcv_cnt[{1'b0,pkt_tag_offset_for_ram_wt[2][TAG_WIDTH-1:0]}][4:0] + 5'h01);
        if (rc_axis_tlast_3tc == 1'b0) begin
          ram_wp <= (ram_wp + 11'h1);
          ram_wt_cycle_cnt <= (ram_wt_cycle_cnt + 4'h1);
        end else begin
          if (ram_wt_tlast_for_check == 1'b0) begin
            ram_wt_tlast_for_check <= 1'b1;
          end
          pkt_tag_hld_last <= pkt_tag_hld_1tc[0][TAG_WIDTH-1:0];
          ram_wp_divide_pkt_last <= ram_wp_divide_pkt;
          ram_wt_cycle_cnt <= 4'h0;
        end
        if (ram_wt_cycle_pkt_tail == 1'b0) begin
          if (rc_axis_tlast_3tc == 1'b1) begin
            pkt_divide_detect <= 1'b1;
          end
        end else begin
          if (pkt_tag_offset_for_ram_wt[1][TAG_WIDTH-1:0] > {(TAG_WIDTH){1'b0}}) begin
            pkt_wt_infoq_pkt_valid[{1'b0,pkt_tag_offset_for_ram_wt[1][TAG_WIDTH-1:0]} - {{(TAG_WIDTH){1'b0}},ram_set_pkt_tail_toq}] <= 1'b1;
            if ((reg_dma_rx_err[10] == 1'b0) && (reg_dma_rx_err_msk[10] == 1'b0) && (pkt_wt_infoq_pkt_valid[{1'b0,pkt_tag_offset_for_ram_wt[1][TAG_WIDTH-1:0]}] == 1'b1)) begin
              reg_dma_rx_err[10] <= 1'b1; // reg_dma_rx_err_pkt_wt_infoq_pkt_valid
            end
          end
          if ((reg_dma_rx_err[9] == 1'b0) && (reg_dma_rx_err_msk[9] == 1'b0) && (rc_axis_tlast_3tc == 1'b0)) begin
            reg_dma_rx_err[9] <= 1'b1; // reg_dma_rx_err_ram_wt_tlast_unmch
          end
        end
        if ((ram_wt_tlast_for_check == 1'b1) && (pkt_tag_hld_1tc[1][TAG_WIDTH-1:0] == pkt_tag_hld_last) && (ram_wp_divide_pkt < ram_wp_divide_pkt_last)) begin
          pkt_divide_overtake_detect <= 1'b1;
        end
        if ((reg_dma_rx_err[7] == 1'b0) && (reg_dma_rx_err_msk[7] == 1'b0) && ((pkt_tag_valid_1tc == 1'b0) || (pkt_wt_infoq_flg[{1'b0,pkt_tag_offset_for_ram_wt[0][TAG_WIDTH-1:0]}] == 1'b0))) begin
          reg_dma_rx_err[7] <= 1'b1; // reg_dma_rx_err_ram_wt_flg_lost
        end
        if ((reg_dma_rx_err[8] == 1'b0) && (reg_dma_rx_err_msk[8] == 1'b0) && (pkt_tag_at_ram_wt != pkt_tag_hld_2tc[TAG_WIDTH-1:0])) begin
          reg_dma_rx_err[8] <= 1'b1; // reg_dma_rx_err_ram_wt_tag_unmch
        end
        if ((reg_dma_rx_err[13] == 1'b0) && (reg_dma_rx_err_msk[13] == 1'b0) && ({ram_wp_divide_pkt[5:4],(ram_wp_divide_pkt[3:0] & ~pkt_addr_mask[9:6])} > 6'h00)) begin
          reg_dma_rx_err[13] <= 1'b1; // reg_dma_rx_err_pkt_divide_err
        end
      end

///// RAM resource ctrl
      if ((pkt_send_go_1tc == 1'b1) && (ram_re == 1'b0)) begin
        ram_nrsvd_entry <= (ram_nrsvd_entry - {7'h00,pkt_cycle_1tc});
      end else if ((pkt_send_go_1tc == 1'b0) && (ram_re == 1'b1)) begin
        ram_nrsvd_entry <= (ram_nrsvd_entry + 12'h1);
      end else if ((pkt_send_go_1tc == 1'b1) && (ram_re == 1'b1)) begin
        ram_nrsvd_entry <= (ram_nrsvd_entry - {7'h00,pkt_cycle_1tc} + 12'h1);
      end
      if ((ram_we == 1'b1) && (ram_re == 1'b0)) begin
        ram_empty_entry <= (ram_empty_entry - 12'h1);
      end else if (ram_we == 1'b0 && ram_re == 1'b1) begin
        ram_empty_entry <= (ram_empty_entry + 12'h1);
      end
      if ((ram_set_pkt_tail_toq == 1'b1) && (ram_re_pkt_tail == 1'b0)) begin
        ram_pkt_continue_cnt <= (ram_pkt_continue_cnt + 12'h1);
      end else if ((ram_set_pkt_tail_toq == 1'b0) && (ram_re_pkt_tail == 1'b1)) begin
        ram_pkt_continue_cnt <= (ram_pkt_continue_cnt - 12'h1);
      end
      if ((reg_dma_rx_err[11] == 1'b0) && (reg_dma_rx_err_msk[11] == 1'b0) && (((ram_nrsvd_entry == 12'h0) && (pkt_send_go == 1'b1)) || ((ram_empty_entry == 12'h0) && (ram_we == 1'b1)))) begin
        reg_dma_rx_err[11] <= 1'b1; // reg_dma_rx_err_ram_wt_ovfl
      end

///// CIF_DN for DMA read
      if (ram_re == 1'b1) begin
        d2c_axis_tvalid_pre <= 1'b1;
        if (CH_NUM > 1) begin
          d2c_axis_cid_pre <= pkt_rd_infoq_cid_toq[CID_WIDTH-1:0];
        end
        ram_rp <= (ram_rp + 11'h1);
        if (ram_rd_cycle_cnt == 4'h0) begin
          d2c_axis_sop_pre <= 1'b1;
          d2c_axis_burst_pre <= (pkt_rd_infoq_cycle_m1_toq + 5'h01);
        end else begin
          d2c_axis_sop_pre <= 1'b0;
          d2c_axis_burst_pre <= 5'h00;
        end
        if ({1'b0,ram_rd_cycle_cnt} < pkt_rd_infoq_cycle_m1_toq[4:0]) begin
          ram_rd_cycle_cnt <= (ram_rd_cycle_cnt + 4'h1);
          d2c_axis_tlast_pre <= 1'b0;
          d2c_axis_eop_pre <= 1'b0;
        end else begin
          ram_rd_cycle_cnt <= 4'h0;
          d2c_axis_tlast_pre <= pkt_rd_infoq_dsc_last_toq;
          d2c_axis_eop_pre <= 1'b1;
        end
        if ((reg_dma_rx_err[12] == 1'b0) && (reg_dma_rx_err_msk[12] == 1'b0) && (pkt_rd_infoq_used_cnt == 11'h0)) begin
          reg_dma_rx_err[12] <= 1'b1; // reg_dma_rx_err_ram_rd_infoq_empty
        end
        if ((reg_dma_rx_err[22] == 1'b0) && (reg_dma_rx_err_msk[22] == 1'b0) && (((pkt_rd_infoq_rd[25] ^ pkt_rd_infoq_rd[16] ^ (^pkt_rd_infoq_rd[12:8])) == 1'b1)
                                                                              || ((pkt_rd_infoq_rd[24] ^ pkt_rd_infoq_rd[CID_WIDTH-1:0]) == 1'b1))) begin
          reg_dma_rx_err[22] <= 1'b1; // reg_dma_rx_err_ram_rd_infoq_rd_pe
          pkt_rd_infoq_rd_pe_detect <= 1'b1;
        end
      end else if ((d2c_axis_tvalid_mod == 1'b0) || (d2c_axis_tready_mod == 1'b1)) begin
        d2c_axis_tvalid_pre <= 1'b0;
        d2c_axis_tlast_pre <= 1'b0;
        d2c_axis_sop_pre <= 1'b0;
        d2c_axis_eop_pre <= 1'b0;
      end
      if ((d2c_axis_tvalid_mod == 1'b0) || (d2c_axis_tready_mod == 1'b1)) begin
        d2c_axis_tvalid_mod <= d2c_axis_tvalid_pre;
        if (d2c_axis_tvalid_pre == 1'b1) begin
          d2c_axis_tlast <= d2c_axis_tlast_pre; // unuse, for debug
          d2c_axis_tdata <= ram_rd_data;
          if (CH_NUM > 1) begin
            d2c_axis_cid <= d2c_axis_cid_pre;
          end
          d2c_axis_sop <= d2c_axis_sop_pre;
          d2c_axis_eop <= d2c_axis_eop_pre;
          d2c_axis_burst <= d2c_axis_burst_pre;
        end else begin
          d2c_axis_tlast <= 1'b0;
          d2c_axis_sop <= 1'b0;
          d2c_axis_eop <= 1'b0;
        end
      end
      if ( d2c_pkt_tail ) begin
        d2c_axis_wait_cnt <= reg_dma_rx_mode0[31:24];
      end
      if ( d2c_axis_wait_cnt > 8'h00 ) begin
        d2c_axis_wait_cnt <= d2c_axis_wait_cnt - 8'h01;
      end 

///// CIF_DN for clear
      rxch_enb <= rxch_ie;
      rxch_rd_enb <= d2c_dmar_rd_enb;
      rxch_clr_exec <= rxch_clr;

///// error
      reg_dma_rx_err_detect <= |reg_dma_rx_err;
      for (int i = 0; i < 32; i++) begin
        if ((reg_dma_rx_err[i] == 1'b0) && (reg_dma_rx_err_msk[i] == 1'b0) && (set_reg_dma_rx_err[i] == 1'b1)) begin
          reg_dma_rx_err[i] <= 1'b1;
        end
        if ((reg_dma_rx_err[i] == 1'b1) && (reg_dma_rx_err_1wc == 1'b1)) begin
          reg_dma_rx_err[i] <= 1'b0;
        end
      end
      reg_dma_rx_err_eg0_inj <= |chx_reg_dma_rx_err_eg0_inj;
      if (reg_dma_rx_err_eg1_set == 1'b0) begin
        reg_dma_rx_err_eg1_inj <= 1'b0;
      end else if ((reg_dma_rx_err_eg1_inj == 1'b0) && (pkt_send_go_1tc == 1'b1)) begin
        reg_dma_rx_err_eg1_inj <= 1'b1;
      end
    end

  end

///// PCI_TRX for regster
  always_comb begin
    if (regreq_axis_tvalid_dmar_npa_1tc == 1'b1) begin
      if (regreq_axis_wt_flg_1tc == 1'b0) begin
        regrep_axis_tvalid_dmar_reg = 1'b1;
        case (regreq_axis_rw_addr_hld)
// dma_rx_ctrl
//        16'h0200 : "ENQDEQ : rxch_avail";
//        16'h0204 : "ENQDEQ : rxch_active";
          16'h0208 : regrep_axis_tdata_dmar_reg = {29'h0,pkt_max_len_mode - 3'h1};
//        16'h020C : "ENQDEQ : rxch_sel";
//        16'h0210 : "ENQDEQ : rxch_ctrl0";
//        16'h0214 : "ENQDEQ : rxch_ctrl1";
//        16'h0218 : "ENQDEQ : Reserved";
//        16'h021C : "ENQDEQ : Reserved";
//        16'h0220 : "ENQDEQ : enq_ctrl / prev_fpga_ctrl";
//        16'h0224 : "ENQDEQ : Reserved";
//        16'h0228 : "ENQDEQ : enq_addr_dn / prev_fpga_addr_dn";
//        16'h022C : "ENQDEQ : enq_addr_up / prev_fpga_addr_up";
//        16'h0230 : "ENQDEQ : srbuf_wp_cp";
//        16'h0234 : "ENQDEQ : srbuf_rp";
//        16'h0238 : "ENQDEQ : srbuf_addr_dn";
//        16'h023C : "ENQDEQ : srbuf_addr_up";
//        16'h0240 : "ENQDEQ : srbuf_size";
//        16'h0244-16'h024C : Reserved;
//        16'h0250 : "ENQDEQ : rxch_ie";
//        16'h0254 : "ENQDEQ : rxch_oe";
//        16'h0258 : "ENQDEQ : rxch_clr";
//        16'h025C : "ENQDEQ : rxch_busy";
//        16'h0260-16'h03DC : Reserved;
// dma_rx_err
          16'h03E0 : regrep_axis_tdata_dmar_reg = {31'h0,reg_dma_rx_err_detect};
          16'h03E4 : regrep_axis_tdata_dmar_reg = reg_dma_rx_err;
//        16'h03E8-16'h03F0 : Reserved;
          16'h03F4 : regrep_axis_tdata_dmar_reg = reg_dma_rx_err_msk;
          16'h03F8 : regrep_axis_tdata_dmar_reg = {30'h0,reg_dma_rx_err_eg1_inj,reg_dma_rx_err_eg0_inj};
          16'h03FC : regrep_axis_tdata_dmar_reg = {30'h0,reg_dma_rx_err_eg1_set,reg_dma_rx_err_eg0_set};
// dma_rx_mode
          16'h1200 : regrep_axis_tdata_dmar_reg = reg_dma_rx_mode0;
          16'h1204 : regrep_axis_tdata_dmar_reg = reg_dma_rx_mode1;
          16'h1208 : regrep_axis_tdata_dmar_reg = {chx_srbuf_inflight_area[0][31:6],6'h00};
          16'h120C : regrep_axis_tdata_dmar_reg = {chx_srbuf_inflight_area[1][31:6],6'h00};
          16'h1210 : regrep_axis_tdata_dmar_reg = {chx_srbuf_inflight_area[2][31:6],6'h00};
          16'h1214 : regrep_axis_tdata_dmar_reg = {chx_srbuf_inflight_area[3][31:6],6'h00};
          16'h1218 : regrep_axis_tdata_dmar_reg = {chx_srbuf_inflight_area[4][31:6],6'h00};
          16'h121C : regrep_axis_tdata_dmar_reg = {chx_srbuf_inflight_area[5][31:6],6'h00};
          16'h1220 : regrep_axis_tdata_dmar_reg = {chx_srbuf_inflight_area[6][31:6],6'h00};
          16'h1224 : regrep_axis_tdata_dmar_reg = {chx_srbuf_inflight_area[7][31:6],6'h00};
          16'h1228 : regrep_axis_tdata_dmar_reg = {chx_srbuf_inflight_area[8][31:6],6'h00};
          16'h122C : regrep_axis_tdata_dmar_reg = {chx_srbuf_inflight_area[9][31:6],6'h00};
          16'h1230 : regrep_axis_tdata_dmar_reg = {chx_srbuf_inflight_area[10][31:6],6'h00};
          16'h1234 : regrep_axis_tdata_dmar_reg = {chx_srbuf_inflight_area[11][31:6],6'h00};
//        16'h1234 : "ENQDEQ : rxch_clr_mode(unuse)";
//        16'h1238 : "PA_CNT : rxch_sel_pa"
//        16'h123C : "ENQDEQ : polling_interval1/2";
// dma_rx_status
          16'h1240 : regrep_axis_tdata_dmar_reg = reg_dma_rx_status[0][31:0];
          16'h1244 : regrep_axis_tdata_dmar_reg = reg_dma_rx_status[1][31:0];
          16'h1248 : regrep_axis_tdata_dmar_reg = reg_dma_rx_status[2][31:0];
          16'h124C : regrep_axis_tdata_dmar_reg = reg_dma_rx_ch_sel_status;
          16'h1250 : regrep_axis_tdata_dmar_reg = reg_dma_rx_ch_status[0][31:0];
          16'h1254 : regrep_axis_tdata_dmar_reg = reg_dma_rx_ch_status[1][31:0];
          16'h1258 : regrep_axis_tdata_dmar_reg = reg_dma_rx_ch_status[2][31:0];
          16'h125C : regrep_axis_tdata_dmar_reg = reg_dma_rx_ch_status[3][31:0];
          16'h1260 : regrep_axis_tdata_dmar_reg = reg_dma_rx_ch_status[4][31:0];
          16'h1264 : regrep_axis_tdata_dmar_reg = reg_dma_rx_ch_status[5][31:0];
          16'h1268 : regrep_axis_tdata_dmar_reg = reg_dma_rx_ch_status[6][31:0];
          16'h126C : regrep_axis_tdata_dmar_reg = reg_dma_rx_ch_status[7][31:0];
          16'h1270 : regrep_axis_tdata_dmar_reg = reg_dma_rx_ch_status[8][31:0];
          16'h1274 : regrep_axis_tdata_dmar_reg = reg_dma_rx_ch_status[9][31:0];
          16'h1278 : regrep_axis_tdata_dmar_reg = reg_dma_rx_ch_status[10][31:0];
          16'h127C : regrep_axis_tdata_dmar_reg = reg_dma_rx_ch_status[11][31:0];
// dma_rx_pa
//        16'h1280-16'h1284 : "PA_CNT :  PA00 : Received data size (64B unit)"
//        16'h1288-16'h128C : "PA_CNT :  PA01 : Transmit data size (64B unit)"
//        16'h1290-16'h1294 : "PA_CNT :  PA02 : Number of ENQ Fetch"
//        16'h1298-16'h129C : "PA_CNT :  PA03 : Received Valid Descriptors"
//        16'h12A0-16'h12A4 : "PA_CNT :  PA04 : Number of ENQ Stores"
//        16'h12A8-16'h12AC : "PA_CNT :  PA05 : Received D2D-H Count"
//        16'h12B0-16'h12B4 : "PA_CNT :  PA06 : Transmit ACK Count"
//        16'h12B8-16'h12BC : "PA_CNT :  PA07 : Issued Requests"
//        16'h12C0-16'h12C4 : "PA_CNT :  PA08 : Replies Received"
//        16'h12C8-16'h12D4 : "PA_CNT :  Reserved"
//        16'h12D8-16'h12DC : "PA_CNT :  PA11 : Cumulative value of number of in-flight requests"
//        16'h12E0-16'h12E4 : "PA_CNT :  PA12 : Cumulative value of RAM usage entries (including reserve)"
//        16'h12E8-16'h12EC : "PA_CNT :  PA13 : Cumulative value of number of RAM valid data storage entries"
//        16'h12F0          : "PA_CNT :  Reserved"
//        16'h12F4          : "PA_CNT :  PA11 : Maximum number of in-flight requests"
//        16'h12F8          : "PA_CNT :  PA12 : Maximum number of RAM usage entries (including reserve)"
//        16'h12FC          : "PA_CNT :  PA13 : Maximum number of RAM valid data storage entries"
// dma_rx_dbg_rd
//        16'h1300 : "ENQDEQ : data[31:0]"
//        16'h1304 : "ENQDEQ : data[63:32]"
//        16'h1308 : "ENQDEQ : data[95:64]"
//        16'h130C : "ENQDEQ : data[127:96]"
//        16'h1310 : "ENQDEQ : data[159:128]"
//        16'h1314 : "ENQDEQ : data[191:160]"
//        16'h1318 : "ENQDEQ : data[223:192]"
//        16'h131C : "ENQDEQ : data[255:224]"
//        16'h1320 : "ENQDEQ : data[287:256]"
//        16'h1324 : "ENQDEQ : data[319:288]"
//        16'h1328 : "ENQDEQ : data[351:320]"
//        16'h132C : "ENQDEQ : data[383:352]"
//        16'h1330 : "ENQDEQ : data[415:384]"
//        16'h1334 : "ENQDEQ : data[447:416]"
//        16'h1338 : "ENQDEQ : data[479:448]"
//        16'h133C : "ENQDEQ : data[511:480]"
//        16'h1340 : "ENQDEQ : 31'h0,enb"
//        16'h1344 : "ENQDEQ : Reserved"
//        16'h1348 : "ENQDEQ : addr[31:6],6'h0"
//        16'h134C : "ENQDEQ : addr[63:32]"
//        16'h1350-16'h135C : Reserved;
// undefined
//        16'h1360-16'h137C : Reserved;
// dma_rx_pa
//        16'h1380-16'h1384 : "PA_CNT : PA14 : Result of PA00-09 selected by 0x13A0[3:0] (per CH)"
//        16'h1388-16'h138C : "PA_CNT : PA15 : Result of PA00-09 selected by 0x13A4[3:0] (per CH)"
//        16'h1390-16'h1394 : "PA_CNT : PA16 : Result of PA00-09 selected by 0x13A8[3:0] (per CH)"
//        16'h1398-16'h139C : "PA_CNT : PA17 : Result of PA00-09 selected by 0x13AC[3:0] (per CH)"
//        16'h13A0          : "PA_CNT : PA14 : Select PA00-09 that should be counted for each CH"
//        16'h13A4          : "PA_CNT : PA15 : Select PA00-09 that should be counted for each CH"
//        16'h13A8          : "PA_CNT : PA16 : Select PA00-09 that should be counted for each CH"
//        16'h13AC          : "PA_CNT : PA17 : Select PA00-09 that should be counted for each CH"
// dma_rx_trace
//        16'h13E0 : "TRACE_RX : RAM0";
//        16'h13E4 : "TRACE_RX : RAM1";
//        16'h13E8 : "TRACE_RX : RAM2";
//        16'h13EC : "TRACE_RX : RAM3";
//        16'h13F0-16'h13FC : Reserved;
// D2D-H
//        16'h1E00 : "D2D-H receive";
          default  : regrep_axis_tdata_dmar_reg = 32'h0;
        endcase
      end else begin // if (regreq_axis_wt_flg_1tc == 1'b0)
	 
        regrep_axis_tvalid_dmar_reg = 1'b0;
        regrep_axis_tdata_dmar_reg = 32'h0;
      end
    end else begin
      regrep_axis_tvalid_dmar_reg = 1'b0;
      regrep_axis_tdata_dmar_reg  = 32'h0;
    end
    reg_dma_rx_ch_sel_status = {3'h0,chx_lru_state[4][4:0],1'b0,chx_lru_state[3][4:0],1'b0,chx_lru_state[2][4:0],1'b0,chx_lru_state[1][4:0],1'b0,chx_lru_state[0][4:0]};
    for (int i = 0; i < 12; i++) begin
      if (i < CH_NUM) begin
        reg_dma_rx_ch_status[i][31:0] = {9'h00,chx_que_wt_req_cnt[i][2:0],1'b0,chx_dscq_ucnt[i][2:0],1'b0,chx_dscq_pcnt[i][2:0],2'b0,chx_dscq_rp[i][1:0],2'b0,chx_dscq_pkt_send_rp[i][1:0],2'b0,chx_dscq_wp[i][1:0]};
      end else begin
        reg_dma_rx_ch_status[i][31:0] = 32'h0;
      end
    end
    `ifdef TRACE_RX
      trace_rd_or = 32'h0;
      for (int i = 0; i < 4; i++) begin
        trace_rd_or = trace_rd_or | trace_rd[i][31:0];
      end
      regrep_axis_tdata_dmar_seld = regrep_axis_tdata_dmar_reg_2tc | trace_rd_or;
    `else
      regrep_axis_tdata_dmar_seld = regrep_axis_tdata_dmar_reg_2tc;
    `endif
  end

  assign regreq_axis_wt_flg         = regreq_axis_tuser[32];
  assign regreq_axis_rw_addr        = regreq_axis_tuser[15:0];
  assign regreq_axis_wt_data        = regreq_axis_tdata[63:0];
  assign reg_dma_rx_status[0][31:0] = {pkt_divide_detect,ram_wp[10:0],ram_nrsvd_entry[11:0],pkt_divide_overtake_detect,{(7-TAG_WIDTH){1'b0}},pkt_send_tag[TAG_WIDTH-1:0]};
  assign reg_dma_rx_status[1][31:0] = {pkt_tag_overtake_detect,ram_rp[10:0],4'h0,{(7-TAG_WIDTH){1'b0}},tag_inflight_cnt[TAG_WIDTH:0],d2d_wp_not_update_detect,{(7-TAG_WIDTH){1'b0}},pkt_tag_hld[0][TAG_WIDTH-1:0]};
  assign reg_dma_rx_status[2][31:0] = {{(7-TAG_WIDTH){1'b0}},pkt_tag_shift[0][TAG_WIDTH-1:0],pkt_send_cnt[24:0]};

///// PCI_TRX for PA
  `ifdef PA_RX
    always_comb begin
      for (int i = 0; i < (CH_NUM/8); i++) begin
        pa10_add_val[i][15:0] = 16'h0;
        if (i == 0) begin
          pa11_add_val[i][15:0] = {8'h00,{(7-TAG_WIDTH){1'b0}},req_inflight_cnt};
          pa12_add_val[i][15:0] = {4'h0,ram_rsvd_entry};
          pa13_add_val[i][15:0] = {4'h0,ram_valid_entry};
        end else begin
          pa11_add_val[i][15:0] = 16'h0;
          pa12_add_val[i][15:0] = 16'h0;
          pa13_add_val[i][15:0] = 16'h0;
        end
      end
    end

    assign ram_rsvd_entry    = 12'h800 - ram_nrsvd_entry;
    assign ram_valid_entry   = 12'h800 - ram_empty_entry;

    pa_cnt3_wrapper #(.CH_NUM(CH_NUM), .FF_NUM(1))
      PA_CNT(
      .user_clk(user_clk),
      .reset_n(reset_n),

// Register access IF ///////////////////////////////////////////////////////////////////////
      // input
      .reg_base_addr(7'b0001_001),
      .regreq_tvalid(regreq_axis_tvalid_dmar_pa_1tc),
      .regreq_tdata(regreq_axis_tdata_1tc),
      .regreq_tuser(regreq_axis_tuser_1tc),
      // output
      .regrep_tvalid(regrep_tvalid_pa_cnt),
      .regrep_tdata(regrep_tdata_pa_cnt),

// PA Counter /////////////////////////////////////////////////////////////////////////////
      // input
      .pa_enb(pa_enb),
      .pa_clr(pa_clr),
      .pa00_inc_enb({{(CH_NUM-1){1'b0}},(rc_axis_tvalid_dmar & rc_axis_tuser[15])}), // Receive data size (64B unit)
      .pa01_inc_enb({{(CH_NUM-1){1'b0}},(d2c_axis_tvalid_mod & d2c_axis_tready_mod)}),       // Transmitted data size (64B unit)
      .pa02_inc_enb(pa_item_fetch_enqdeq),                                           // ENQ Fetch number
      .pa03_inc_enb(pa_item_receive_dsc),                                            // number of valid descriptors received
      .pa04_inc_enb(pa_item_store_enqdeq),                                           // Number of ENQ Stores
      .pa05_inc_enb(pa_item_rcv_send_d2d),                                           // Number of received D2D-H
      .pa06_inc_enb(pa_item_send_rcv_ack),                                           // Transmit ACK count
      .pa07_inc_enb({{(CH_NUM-1){1'b0}},pkt_send_done}),                             // Number of requests submitted
      .pa08_inc_enb({{(CH_NUM-1){1'b0}},ram_we_pkt_tail}),                           // Number of replies received
      .pa09_inc_enb({(CH_NUM){1'b0}}),                                               // Reserved
      .pa10_add_val(pa10_add_val),                                                   // Reserved
      .pa11_add_val(pa11_add_val),                                                   // umulative value of number of in-flight requests, maximum value
      .pa12_add_val(pa12_add_val),                                                   // Cumulative value of number of entries using RAM (including reservation), maximum value
      .pa13_add_val(pa13_add_val)                                                    // RAM number of valid data storage entries Cumulative value, maximum value
    );
  `endif

///// PCI_TRX for TRACE
  `ifdef TRACE_RX
    always_comb begin
      case (trace_wd_mode)
        2'h0 : begin trace_wd_pre[0][31:0] = trace_free_run_cnt;
                     trace_wd_pre[1][31:0] = trace_free_run_cnt;
                     trace_wd_pre[2][31:0] = trace_dscq_src_len;
                     trace_wd_pre[3][31:0] = {{(16-CID_WIDTH){1'b0}},ram_wt_cid_2tc,trace_dscq_task_id_rp_pros}; end
        2'h1 : begin trace_wd_pre[0][31:0] = ram_wd_data_2tc[31:0];
                     trace_wd_pre[1][31:0] = ram_wd_data_2tc[31:0];
                     trace_wd_pre[2][31:0] = {13'b0,ram_wp_2tc[10:0],1'b0,{(7-TAG_WIDTH){1'b0}},pkt_tag_hld_3tc[TAG_WIDTH-1:0]};
                     trace_wd_pre[3][31:0] = {{(16-CID_WIDTH){1'b0}},ram_wt_cid_2tc,trace_dscq_task_id_rp_pros}; end
        2'h2 : begin trace_wd_pre[0][31:0] = trace_free_run_cnt;
                     trace_wd_pre[1][31:0] = d2d_wp[31:0];                  // D2D-H WP (mode1)
                     trace_wd_pre[2][31:0] = rq_dmar_cwr_axis_tdata[63:32]; // ACK   RP (mode1)
                     trace_wd_pre[3][31:0] = {d2d_receive,(rq_dmar_cwr_axis_tvalid & rq_dmar_cwr_axis_tlast & rq_dmar_cwr_axis_tready),5'h0,d2d_frame_last,8'h0,{(8-CID_WIDTH){1'b0}},d2d_next_cid[CID_WIDTH-1:0],{(8-CID_WIDTH){1'b0}},rq_dmar_cwr_axis_tdata[CID_WIDTH+15:16]}; end // (mode1)
        2'h3 : begin trace_wd_pre[0][31:0] = '0;
                     trace_wd_pre[1][31:0] = '0; 
                     trace_wd_pre[2][31:0] = '0;
                     trace_wd_pre[3][31:0] = '0; end
        default  : ;
      endcase
    end

    assign trace_mode            = reg_dma_rx_mode1[19];
    assign trace_we_mode         = reg_dma_rx_mode1[16];
    assign trace_wd_mode         = reg_dma_rx_mode1[13:12];
    assign trace_we_pre0[0]      = ram_we_2tc & (ram_wt_cycle_rcv_cnt_2tc == 5'h00 ?1:0) & ~ram_we_3tc;
    assign trace_we_pre1[0]      = trace_we_mode | (trace_dscq_sp_pkt_rcv_cnt == 26'h0 ?1:0);
    assign trace_we_pre0[1]      = ram_we_pkt_tail_2tc;
    assign trace_we_pre1[1]      = trace_we_mode | (trace_dscq_sp_pkt_rcv_cnt + 26'h1 == trace_dscq_sp_pkt_num ?1:0);
    assign trace_we_pre0[2]      = d2d_receive | (rq_dmar_cwr_axis_tvalid & rq_dmar_cwr_axis_tlast & rq_dmar_cwr_axis_tready); // D2D-H or ACK (mode1)
    assign trace_we_pre1[2]      = 1'b1;
    assign trace_we[0]           = (trace_wd_mode[1] ? trace_we0[2] & trace_we1[2] : trace_we0[0] & trace_we1[0]) & (reg_dma_rx_err == '0 ?1:0);
    assign trace_we[1]           = (trace_wd_mode[1] ? trace_we0[2] & trace_we1[2] : trace_we0[1] & trace_we1[1]) & (reg_dma_rx_err == '0 ?1:0);
    assign trace_we[2]           = trace_we[0];
    assign trace_we[3]           = trace_we[0];
    assign trace_re[0]           = regreq_axis_tvalid_dmar_1tc & ~regreq_axis_wt_flg_1tc & (regreq_axis_rw_addr_hld == 16'h13E0 ?1:0);
    assign trace_re[1]           = regreq_axis_tvalid_dmar_1tc & ~regreq_axis_wt_flg_1tc & (regreq_axis_rw_addr_hld == 16'h13E4 ?1:0);
    assign trace_re[2]           = regreq_axis_tvalid_dmar_1tc & ~regreq_axis_wt_flg_1tc & (regreq_axis_rw_addr_hld == 16'h13E8 ?1:0);
    assign trace_re[3]           = regreq_axis_tvalid_dmar_1tc & ~regreq_axis_wt_flg_1tc & (regreq_axis_rw_addr_hld == 16'h13EC ?1:0);

    for (genvar i = 0; i < 4; i++) begin : TRACE_RX
      trace_ram TRACE_RX (
        .user_clk(user_clk),
        .reset_n(reset_n),
        .trace_clr(trace_clr),
        .trace_enb(trace_enb),
        .trace_we(trace_we[i]),
        .trace_wd(trace_wd[i][31:0]),
        .trace_re(trace_re[i]),
        .trace_mode(trace_mode),
        .trace_rd(trace_rd[i][31:0])
      );
    end
  `endif

///// PCI_TRX for DMA read

// enqdeq
  always_comb begin
    for (int i = 0; i < CH_NUM; i++) begin
      // input
      que_rd_req[i]             = ~chx_dscq_full[i];
      que_wt_req[i]             = que_wt_req_ff[i] & ~que_wt_ack_1tc[i];
      if (chx_rxch_mode[i][2:0] == 3'h0) begin
        srbuf_wp[i][31:0]       = 32'h0;
        srbuf_rp[i][31:0]       = 32'h0;
      end else if (chx_rxch_mode[i][2:0] == 3'h1) begin
        srbuf_wp[i][31:0]       = {chx_srbuf_wp[i][31:6],6'h00};
        srbuf_rp[i][31:0]       = {chx_srbuf_rp[i][31:6],6'h00};
      end else if (chx_rxch_mode[i][2:0] == 3'h2) begin
        srbuf_wp[i][31:0]       = 32'h0;
        srbuf_rp[i][31:0]       = d2c_ack_rp_mode2[i][31:0];
      end else begin
        srbuf_wp[i][31:0]       = 32'h0;
        srbuf_rp[i][31:0]       = 32'h0;
      end
      dmar_busy[i]              = chx_dmar_busy[i] | que_wt_req[i];
      // output
      if (chx_rxch_mode[i][2:0] == 3'h0) begin
        chx_que_wt_ack[i]       = que_wt_ack[i];
        chx_srbuf_addr[i][63:6] = 58'h0;
        chx_srbuf_size[i][31:6] = 26'h0;
        d2c_pkt_mode[i][1:0]    = 2'h0;
        d2c_que_wt_ack_mode2[i] = 1'b0; 
      end else if (chx_rxch_mode[i][2:0] == 3'h1) begin
        chx_que_wt_ack[i]       = que_wt_ack[i];
        chx_srbuf_addr[i][63:6] = srbuf_addr[i][63:6];
        chx_srbuf_size[i][31:6] = srbuf_size[i][31:6];
        d2c_pkt_mode[i][1:0]    = 2'h1;
        d2c_que_wt_ack_mode2[i] = 1'b0; 
      end else if (chx_rxch_mode[i][2:0] == 3'h2) begin
        chx_que_wt_ack[i]       = 1'b0;
        chx_srbuf_addr[i][63:6] = 58'h0;
        chx_srbuf_size[i][31:6] = 26'h0;
        d2c_pkt_mode[i][1:0]    = 2'h2;
        d2c_que_wt_ack_mode2[i] = que_wt_ack[i]; 
      end else begin
        chx_que_wt_ack[i]       = 1'b0;
        chx_srbuf_addr[i][63:6] = 58'h0;
        chx_srbuf_size[i][31:6] = 26'h0;
        d2c_pkt_mode[i][1:0]    = 2'h0;
        d2c_que_wt_ack_mode2[i] = 1'b0; 
      end
    end
  end

// dma_rx_ch
  always_comb begin
  // input
    // D2D-H receive, clear
    for (int i = 0; i < CH_NUM; i++) begin
      if (CH_NUM == 1) begin
        chx_srbuf_wp_update[i]      = ((chx_rxch_mode[i][2:0] == 3'h1) ?1:0) & rxch_enb[i] & d2d_receive;
        chx_d2c_pkt_tail[i]         = d2c_pkt_tail;
      end else begin
        chx_srbuf_wp_update[i]      = ((chx_rxch_mode[i][2:0] == 3'h1) ?1:0) & rxch_enb[i] & d2d_receive & (i == d2d_next_cid ?1:0);
        chx_d2c_pkt_tail[i]         = d2c_pkt_tail & (i == d2c_axis_cid ?1:0);
      end
      chx_rxch_enb[i]               = rxch_enb[i];
      chx_rxch_rd_enb[i]            = rxch_rd_enb[i];
      chx_rxch_clr_exec[i]          = rxch_clr_exec[i];
    end
    // DSCQ
    for (int i = 0; i < CH_NUM; i++) begin
      if (rc_axis_tvalid_dmar_1tc == 1'b1) begin
        if ((chx_rxch_mode[i][2:0] == 3'h0) && (que_rd_dv[i] == 1'b1)) begin
          chx_dscq_we_enq[i]        = 1'b1;
          chx_dscq_we_enq_tlast[i]  = rc_axis_tlast_1tc;
        end else begin
          chx_dscq_we_enq[i]        = 1'b0;
          chx_dscq_we_enq_tlast[i]  = 1'b0;
        end
      end else begin
        chx_dscq_we_enq[i]          = 1'b0;
        chx_dscq_we_enq_tlast[i]    = 1'b0;
      end
      if (CH_NUM == 1) begin
        chx_ram_we_pkt_tail_1tc[i]  = ram_we_pkt_tail_1tc                                                   ;
        chx_ram_re_dsc_last_tail[i] = ram_re_dsc_last_tail                                                  ;
      end else begin
        chx_ram_we_pkt_tail_1tc[i]  = ram_we_pkt_tail_1tc  & (i == ram_wt_cid_1tc                      ?1:0);
        chx_ram_re_dsc_last_tail[i] = ram_re_dsc_last_tail & (i == pkt_rd_infoq_cid_toq[CID_WIDTH-1:0] ?1:0);
      end
    end

    // packet send
    pkt_send_valid                  = 1'b0;
    for (int i = 0; i < CH_NUM; i++) begin
      pkt_send_valid                = pkt_send_valid | chx_pkt_send_valid[i]    ;
      if (CH_NUM == 1) begin
        chx_pkt_send_go[i]          = pkt_send_go                               ;
      end else begin
        chx_pkt_send_go[i]          = pkt_send_go & (i == pkt_send_cid_2tc ?1:0);
      end
    end
    if (CH_NUM == 1) begin
      pkt_send_pkt_addr   = chx_pkt_send_pkt_addr[0][63:0];
      pkt_num             = chx_pkt_num[0][25:0];
      pkt_sta_cycle       = chx_pkt_sta_cycle[0][4:0];
      pkt_end_cycle       = chx_pkt_end_cycle[0][4:0];
      pkt_send_cnt        = chx_pkt_send_cnt[0][24:0];
    end else begin
      pkt_send_pkt_addr   = chx_pkt_send_pkt_addr[pkt_send_cid_2tc][63:0];
      pkt_num             = chx_pkt_num[pkt_send_cid_2tc][25:0];
      pkt_sta_cycle       = chx_pkt_sta_cycle[pkt_send_cid_2tc][4:0];
      pkt_end_cycle       = chx_pkt_end_cycle[pkt_send_cid_2tc][4:0];
      pkt_send_cnt        = chx_pkt_send_cnt[pkt_send_cid_2tc][24:0];
    end

    // RAM write
    if (CH_NUM > 1) begin
      ram_wt_cid          = pkt_wt_infoq_cid[{1'b0,pkt_tag_offset_for_ram_wt[3][TAG_WIDTH-1:0]}][CID_WIDTH-1:0];
    end

  // output
    // status
    d2d_wp_not_update_detect = 1'b0;
    for (int i = 0; i < CH_NUM; i++) begin
      d2d_wp_not_update_detect  = d2d_wp_not_update_detect | chx_d2d_wp_not_update_detect[i];
    end

    // error
    set_reg_dma_rx_err = 32'h0;
    for (int i = 0; i < CH_NUM; i++) begin
      set_reg_dma_rx_err  = set_reg_dma_rx_err | chx_set_reg_dma_rx_err[i][31:0];
    end

  end

  assign ack_addr_aline_mode = reg_dma_rx_mode0[6:4];
  assign ack_send_mode       = reg_dma_rx_mode1[24];

// ch common
  always_comb begin
    if ({1'b0,cfg_max_payload_1tc} < cfg_max_read_req_1tc) begin
      cfg_max_pkt_size = {1'b0,cfg_max_payload_1tc};
    end else begin
      cfg_max_pkt_size = cfg_max_read_req_1tc;
    end
    if (que_rd_dt[37:32] == 6'h00) begin
      dsc_src_len_enq =   que_rd_dt[63:32];
    end else begin
      dsc_src_len_enq = {(que_rd_dt[63:38] + 26'h1),6'h00};
    end
    if (   (pkt_send_valid_2tc           == 1'b1)
        && (pkt_send_go_1tc              == 1'b0)
        && (dscq_pkt_send_re_2tc         == 1'b0)
        && (tag_inflight_cnt             <  {1'b1,{(TAG_WIDTH){1'b0}}})
        && ({6'h00,pkt_max_cycle,1'b0}   <= ram_nrsvd_entry)
        && (pkt_rd_infoq_used_cnt        <= 11'h3FE)
        ) begin
      rq_dmar_rd_axis_tvalid_pre         = 1'b1;
    end else begin
      rq_dmar_rd_axis_tvalid_pre         = 1'b0;
    end
    if (CH_NUM == 1) begin
      rq_dmar_rd_axis_pkt_dscq_entry_pre = chx_dscq_pkt_send_rp[0][1:0];
    end else begin
      rq_dmar_rd_axis_pkt_cid_pre        = pkt_send_cid_2tc;
      rq_dmar_rd_axis_pkt_dscq_entry_pre = chx_dscq_pkt_send_rp[pkt_send_cid_2tc][1:0];
    end
    if (pkt_send_cnt == 25'h0) begin
      rq_dmar_rd_axis_pkt_cycle_pre      = pkt_sta_cycle;
      if (pkt_num == 26'h1) begin
        rq_dmar_rd_axis_pkt_dsc_last_pre = 1'b1;
      end else begin
        rq_dmar_rd_axis_pkt_dsc_last_pre = 1'b0;
      end
      pkt_cycle                          = pkt_sta_cycle;
    end else if (({1'b0,pkt_send_cnt} + 26'h1) < pkt_num) begin
      rq_dmar_rd_axis_pkt_cycle_pre      = pkt_max_cycle;
      rq_dmar_rd_axis_pkt_dsc_last_pre   = 1'b0;
      pkt_cycle                          = pkt_max_cycle;
    end else begin
      rq_dmar_rd_axis_pkt_cycle_pre      = pkt_end_cycle;
      rq_dmar_rd_axis_pkt_dsc_last_pre   = 1'b1;
      pkt_cycle                          = pkt_end_cycle;
    end
    if (rq_dmar_rd_axis_tvalid == 1'b1) begin
      rq_dmar_rd_axis_tdata = {409'h1,{(7-TAG_WIDTH){1'b0}},rq_dmar_rd_axis_pkt_tag[0][TAG_WIDTH-1:0],23'h0,rq_dmar_rd_axis_pkt_cycle,4'h0,rq_dmar_rd_axis_pkt_addr[63:6],6'h00};
    end else begin
      rq_dmar_rd_axis_tdata = 512'h0;
    end
    if (CH_NUM == 1) begin
      pkt_rd_infoq_wd = {6'h00,(reg_dma_rx_err_eg1_set ^ rq_dmar_rd_axis_pkt_dsc_last ^ (^(rq_dmar_rd_axis_pkt_cycle - 5'h01))),8'h00,rq_dmar_rd_axis_pkt_dsc_last,3'h0,(rq_dmar_rd_axis_pkt_cycle - 5'h01),8'h00};
    end else begin
      pkt_rd_infoq_wd = {6'h00,(reg_dma_rx_err_eg1_set ^ rq_dmar_rd_axis_pkt_dsc_last ^ (^(rq_dmar_rd_axis_pkt_cycle - 5'h01))),^rq_dmar_rd_axis_pkt_cid,7'h00,rq_dmar_rd_axis_pkt_dsc_last,3'h0,(rq_dmar_rd_axis_pkt_cycle - 5'h01),{(8-CID_WIDTH){1'b0}},rq_dmar_rd_axis_pkt_cid};
    end
  end

// ch common
  assign dsc_src_addr_enq               = que_rd_dt[127:64];
  assign dsc_task_id_enq                = que_rd_dt[15:0];
  assign rq_dmar_rd_axis_pkt_tag_pre    = pkt_send_tag;
  assign rq_dmar_rd_axis_pkt_addr_pre   = pkt_send_pkt_addr;
  assign rq_dmar_rd_axis_pkt_num_pre    = pkt_num;
  assign pkt_send_go                    = rq_dmar_rd_axis_tvalid_pre & (~rq_dmar_rd_axis_tvalid | rq_dmar_rd_axis_tready);
  assign dscq_pkt_send_re               = pkt_send_go & ({1'b0,pkt_send_cnt} + 26'h1 == pkt_num ?1:0);
  assign rq_dmar_rd_axis_tlast          = rq_dmar_rd_axis_tvalid;
  assign rc_axis_tready_dmar            = 1'b1;
  assign ram_wt_cycle_pkt_tail          = pkt_tag_valid_1tc & (ram_wt_cycle_rcv_cnt + {4'h0,ram_we_1tc} == ram_wt_cycle_m1 ?1:0);
  assign ram_we_pkt_tail                = ram_we & ram_wt_cycle_pkt_tail;
  assign ram_set_pkt_tail_toq           = (ram_we_pkt_tail & (pkt_tag_offset_for_ram_wt[3][TAG_WIDTH-1:0] == {(TAG_WIDTH){1'b0}} ?1:0)) | (ram_set_pkt_tail_toq_1tc & pkt_wt_infoq_pkt_valid[0]);
  assign ram_wt_dscq_entry              = pkt_wt_infoq_dscq_entry[{1'b0,pkt_tag_offset_for_ram_wt[3][TAG_WIDTH-1:0]}][1:0];
  assign pkt_rd_infoq_cid_toq           = pkt_rd_infoq_rd[CID_WIDTH-1:0];
  assign pkt_rd_infoq_cycle_m1_toq      = pkt_rd_infoq_rd[12:8];
  assign pkt_rd_infoq_dsc_last_toq      = pkt_rd_infoq_rd[16];
  `ifdef PA_RX
    assign pkt_send_done                = rq_dmar_rd_axis_tvalid & rq_dmar_rd_axis_tready;
  `endif
  assign dscq_rd_pe_detect              = |chx_dscq_rd_pe_detect;
   
///// RAM write/read ctrl
  always_comb begin
    for (int i = 0; i < TAG_NUM; i++) begin
      if ((i >= 0) && (i < (TAG_NUM / 4))) begin
        rq_dmar_rd_axis_pkt_tag_offset[i][TAG_WIDTH-1:0] = rq_dmar_rd_axis_pkt_tag[0][TAG_WIDTH-1:0] - pkt_tag_shift[0][TAG_WIDTH-1:0];
        pkt_tag_offset[i][TAG_WIDTH-1:0]                 = pkt_tag_hld[0][TAG_WIDTH-1:0] - pkt_tag_shift[0][TAG_WIDTH-1:0];
        pkt_tag_offset_for_ram_wt[i][TAG_WIDTH-1:0]      = pkt_tag_hld_1tc[0][TAG_WIDTH-1:0] - pkt_tag_shift[0][TAG_WIDTH-1:0];
      end else if ((i >= (TAG_NUM / 4)) && (i < (TAG_NUM / 2))) begin
        rq_dmar_rd_axis_pkt_tag_offset[i][TAG_WIDTH-1:0] = rq_dmar_rd_axis_pkt_tag[1][TAG_WIDTH-1:0] - pkt_tag_shift[1][TAG_WIDTH-1:0];
        pkt_tag_offset[i][TAG_WIDTH-1:0]                 = pkt_tag_hld[1][TAG_WIDTH-1:0] - pkt_tag_shift[1][TAG_WIDTH-1:0];
        pkt_tag_offset_for_ram_wt[i][TAG_WIDTH-1:0]      = pkt_tag_hld_1tc[1][TAG_WIDTH-1:0] - pkt_tag_shift[1][TAG_WIDTH-1:0];
      end else if ((i >= (TAG_NUM / 2)) && (i < (TAG_NUM * 3 / 4))) begin
        rq_dmar_rd_axis_pkt_tag_offset[i][TAG_WIDTH-1:0] = rq_dmar_rd_axis_pkt_tag[2][TAG_WIDTH-1:0] - pkt_tag_shift[2][TAG_WIDTH-1:0];
        pkt_tag_offset[i][TAG_WIDTH-1:0]                 = pkt_tag_hld[2][TAG_WIDTH-1:0] - pkt_tag_shift[2][TAG_WIDTH-1:0];
        pkt_tag_offset_for_ram_wt[i][TAG_WIDTH-1:0]      = pkt_tag_hld_1tc[2][TAG_WIDTH-1:0] - pkt_tag_shift[2][TAG_WIDTH-1:0];
      end else if ((i >= (TAG_NUM * 3 / 4)) && (i < TAG_NUM)) begin
        rq_dmar_rd_axis_pkt_tag_offset[i][TAG_WIDTH-1:0] = rq_dmar_rd_axis_pkt_tag[3][TAG_WIDTH-1:0] - pkt_tag_shift[3][TAG_WIDTH-1:0];
        pkt_tag_offset[i][TAG_WIDTH-1:0]                 = pkt_tag_hld[3][TAG_WIDTH-1:0] - pkt_tag_shift[3][TAG_WIDTH-1:0];
        pkt_tag_offset_for_ram_wt[i][TAG_WIDTH-1:0]      = pkt_tag_hld_1tc[3][TAG_WIDTH-1:0] - pkt_tag_shift[3][TAG_WIDTH-1:0];
      end
    end
  end

  assign pkt_tag_offset_pre            = rc_axis_tuser[TAG_WIDTH+7:8] - pkt_tag_shift[0][TAG_WIDTH-1:0];

///// CIF_DN for DMA read
  always_comb begin
    if (CH_NUM == 1) begin
      d2c_axis_tuser   = {8'h00,d2c_axis_sop,d2c_axis_eop,1'b0,d2c_axis_burst};
    end else begin
      d2c_axis_tuser   = {{(8-CID_WIDTH){1'b0}},d2c_axis_cid,d2c_axis_sop,d2c_axis_eop,1'b0,d2c_axis_burst};
    end
  end

  assign ram_re               = (ram_pkt_continue_cnt > 12'h0 ?1:0) & (~d2c_axis_tvalid_pre | ~d2c_axis_tvalid_mod | d2c_axis_tready_mod) & ~pkt_rd_infoq_rd_pe_detect;
  assign ram_re_pkt_tail      = ram_re & (({1'b0,ram_rd_cycle_cnt} == pkt_rd_infoq_cycle_m1_toq[4:0]) ?1:0);
  assign ram_re_dsc_last_tail = ram_re_pkt_tail & pkt_rd_infoq_dsc_last_toq;
  assign d2c_pkt_tail         = d2c_axis_tvalid_mod & d2c_axis_tready_mod & d2c_axis_eop;
  assign d2c_axis_tready_mod  = d2c_axis_tready & (d2c_axis_wait_cnt == '0 ?1:0);
  assign d2c_axis_tvalid      = d2c_axis_tvalid_mod & (d2c_axis_wait_cnt == '0 ?1:0);

///// CIF_DN for clear
  assign rxch_busy            = d2c_cifd_busy | dmar_busy;
  assign d2c_rxch_oe          = rxch_oe;
  assign d2c_rxch_clr         = rxch_clr;

///// EVE_ARB
  assign dma_rx_ch_connection_enable = rxch_oe;

///// error
  assign error_detect_dma_rx  = reg_dma_rx_err_detect;

///// sub module ( except PA,TRACE )

// enqdeq
  enqdeq #(.RX(1'b1), .CH_NUM(CH_NUM))
    ENQDEQ (
    .user_clk(user_clk),
    .reset_n(reset_n),

// Register access IF ///////////////////////////////////////////////////////////////////////
    // input
    .regreq_tvalid(regreq_axis_tvalid_dmar_npa_1tc),
    .regreq_tdata(regreq_axis_tdata_1tc),
    .regreq_tuser(regreq_axis_tuser_1tc),
    // output
    .regreq_rdt(regreq_rdt_enqdeq),
    .ch_mode(chx_rxch_mode),
    .ch_ie(rxch_ie),
    .ch_oe(rxch_oe),
    .ch_clr(rxch_clr),
    .ch_dscq_clr(),
    // input
    .ch_busy(rxch_busy),

// Queue Read IF ///////////////////////////////////////////////////////////////////////////
    // input
    .que_rd_req(que_rd_req),
    // output
    .que_rd_dv(que_rd_dv),
    .que_rd_dt(que_rd_dt),
    .rq_crd_tvalid(rq_dmar_crd_axis_tvalid),
    .rq_crd_tlast(rq_dmar_crd_axis_tlast),
    .rq_crd_tdata(rq_dmar_crd_axis_tdata),
    // input
    .rq_crd_tready(rq_dmar_crd_axis_tready),
    .rc_tvalid(rc_axis_tvalid_dmar),
    .rc_tdata(rc_axis_tdata),
    .rc_tuser(rc_axis_tuser),

// Queue Write IF ///////////////////////////////////////////////////////////////////////////
    // input
    .que_wt_req(que_wt_req),
    .que_wt_dt(que_wt_dt),
    // output
    .que_wt_ack(que_wt_ack),
    .rq_cwr_tvalid(rq_dmar_cwr_axis_tvalid),
    .rq_cwr_tlast(rq_dmar_cwr_axis_tlast),
    .rq_cwr_tdata(rq_dmar_cwr_axis_tdata),
    // input
    .rq_cwr_tready(rq_dmar_cwr_axis_tready),

// D2D-H/D ///////////////////////////////////////////////////////////////////////////////////
    // input
    .srbuf_wp(srbuf_wp),
    .srbuf_rp(srbuf_rp),
    // output
    .srbuf_addr(srbuf_addr),
    .srbuf_size(srbuf_size),
    .que_base_addr(),

// PA Counter /////////////////////////////////////////////////////////////////////////////
    `ifdef PA_RX
      .pa_item_fetch_enqdeq(pa_item_fetch_enqdeq),
      .pa_item_receive_dsc(pa_item_receive_dsc),
      .pa_item_store_enqdeq(pa_item_store_enqdeq),
      .pa_item_rcv_send_d2d(pa_item_rcv_send_d2d),
      .pa_item_send_rcv_ack(pa_item_send_rcv_ack),
      .pa_item_dscq_used_cnt(pa_item_dscq_used_cnt)
    `else
      .pa_item_fetch_enqdeq(),
      .pa_item_receive_dsc(),
      .pa_item_store_enqdeq(),
      .pa_item_rcv_send_d2d(),
      .pa_item_send_rcv_ack(),
      .pa_item_dscq_used_cnt()
    `endif
  );

// pkt_rd_infoq
  dma_rx_fifo PKT_RD_INFOQ (
    // input
    .user_clk(user_clk),
    .reset_n(reset_n),
    .fifo_we(pkt_send_go_1tc),
    .fifo_wd(pkt_rd_infoq_wd),
    .fifo_re(ram_re_pkt_tail),
    // output
    .fifo_rd(pkt_rd_infoq_rd),
    .used_cnt(pkt_rd_infoq_used_cnt)
  );

// dma_rx_ch_sel
  dma_rx_ch_sel #(.CH_NUM(CH_NUM))
    DMA_RX_CH_SEL (
    // input
    .user_clk(user_clk),
    .reset_n(reset_n),
    .chx_pkt_send_valid(chx_pkt_send_valid),
    .pkt_send_go_1tc(pkt_send_go_1tc),
    // output
    .pkt_send_cid_2tc(pkt_send_cid_2tc), // unuse for CH_NUM == 1
    .chx_lru_state(chx_lru_state)
  );

// dma_rx_ch
  for (genvar i = 0; i < CH_NUM; i++) begin : DMA_RX_CH
    dma_rx_ch DMA_RX_CH (
    // input
      .user_clk(user_clk),
      .reset_n(reset_n),
      // setting
      .chx_rxch_mode(chx_rxch_mode[i][2:0]),
      .pkt_max_len_mode(pkt_max_len_mode),
      .pkt_addr_mask(pkt_addr_mask),
      .pkt_len_mask(pkt_len_mask),
      .ack_addr_aline_mode(ack_addr_aline_mode),
      .ack_send_mode(ack_send_mode),
      .chx_srbuf_addr(chx_srbuf_addr[i][63:6]),
      .chx_srbuf_size(chx_srbuf_size[i][31:6]),
      // D2D-H receive
      .chx_srbuf_wp_update(chx_srbuf_wp_update[i]),
      .d2d_wp(d2d_wp),
      .d2d_frame_last(d2d_frame_last),
      // DSCQ
      .chx_dscq_we_enq(chx_dscq_we_enq[i]),
      .chx_dscq_we_enq_tlast(chx_dscq_we_enq_tlast[i]),
      .dsc_src_addr_enq(dsc_src_addr_enq),
      .dsc_src_len_enq(dsc_src_len_enq),
      .dsc_task_id_enq(dsc_task_id_enq),
      .chx_ram_we_pkt_tail_1tc(chx_ram_we_pkt_tail_1tc[i]),
      .ram_wt_dscq_entry_1tc(ram_wt_dscq_entry_1tc),
      .chx_ram_re_dsc_last_tail(chx_ram_re_dsc_last_tail[i]),
      .chx_que_wt_ack(chx_que_wt_ack[i]),
      `ifdef TRACE_RX
        .trace_enb(trace_enb),
      `endif
      // packet send
      .chx_pkt_send_go(chx_pkt_send_go[i]),
      .rq_dmar_rd_axis_pkt_num(rq_dmar_rd_axis_pkt_num),
      // clear
      .chx_rxch_enb(chx_rxch_enb[i]),
      .chx_rxch_rd_enb(chx_rxch_rd_enb[i]),
      .chx_rxch_clr_exec(chx_rxch_clr_exec[i]),
      .chx_d2c_pkt_tail(chx_d2c_pkt_tail[i]),
      // error
      .reg_dma_rx_err_1wc(reg_dma_rx_err_1wc),
      .reg_dma_rx_err_eg0_set(reg_dma_rx_err_eg0_set),
      .dscq_rd_pe_detect(dscq_rd_pe_detect),
    // output
      // DSCQ
      .chx_dscq_wp(chx_dscq_wp[i][1:0]),
      .chx_dscq_pkt_send_rp(chx_dscq_pkt_send_rp[i][1:0]),
      .chx_dscq_rp(chx_dscq_rp[i][1:0]),
      .chx_dscq_pcnt(chx_dscq_pcnt[i][2:0]),
      .chx_dscq_ucnt(chx_dscq_ucnt[i][2:0]),
      .chx_dscq_full(chx_dscq_full[i]),
      .chx_que_wt_req_pre(chx_que_wt_req_pre[i]),
      .chx_que_wt_req_cnt(chx_que_wt_req_cnt[i][2:0]),
      .chx_que_wt_task_id_rp_pros(chx_que_wt_task_id_rp_pros[i][31:0]),
      `ifdef TRACE_RX
        .chx_trace_dscq_src_len(chx_trace_dscq_src_len[i][31:0]),
        .chx_trace_dscq_task_id_rp_pros(chx_trace_dscq_task_id_rp_pros[i][15:0]),
        .chx_trace_dscq_sp_pkt_num(chx_trace_dscq_sp_pkt_num[i][25:0]),
        .chx_trace_dscq_sp_pkt_rcv_cnt(chx_trace_dscq_sp_pkt_rcv_cnt[i][25:0]),
      `endif
      // packet send
      .chx_pkt_send_valid(chx_pkt_send_valid[i]),
      .chx_pkt_send_pkt_addr(chx_pkt_send_pkt_addr[i][63:0]),
      .chx_pkt_num(chx_pkt_num[i][25:0]),
      .chx_pkt_sta_cycle(chx_pkt_sta_cycle[i][4:0]),
      .chx_pkt_end_cycle(chx_pkt_end_cycle[i][4:0]),
      .chx_pkt_send_cnt(chx_pkt_send_cnt[i][24:0]),
      // status
      .chx_srbuf_wp(chx_srbuf_wp[i][31:6]),
      .chx_srbuf_rp(chx_srbuf_rp[i][31:6]),
      .chx_srbuf_inflight_area(chx_srbuf_inflight_area[i][31:6]),
      .chx_d2d_wp_not_update_detect(chx_d2d_wp_not_update_detect[i]),
      // clear
      .chx_dmar_busy(chx_dmar_busy[i]),
      // error
      .chx_set_reg_dma_rx_err(chx_set_reg_dma_rx_err[i][31:0]),
      .chx_dscq_rd_pe_detect(chx_dscq_rd_pe_detect[i]),
      .chx_reg_dma_rx_err_eg0_inj(chx_reg_dma_rx_err_eg0_inj[i])
    );
  end

// DMA_RX RAM
  DMA_BUF_128K DMA_RX_BUF (
    .clka(user_clk),
    .ena(ram_we),
    .wea(ram_we),
    .addra(ram_wp),
    .dina(ram_wd_data),
    .clkb(user_clk),
    .enb(ram_re),
    .addrb(ram_rp),
    .doutb(ram_rd_data)
  );

endmodule
