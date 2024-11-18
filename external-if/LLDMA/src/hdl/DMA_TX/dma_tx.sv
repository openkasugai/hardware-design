/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/


////////////////////////////////////////////////////////
// Design      : dma_tx.sv
// Designer    : hayasaka
////////////////////////////////////////////////////////


`define TRACE_TX

module dma_tx #(
  parameter                  TCQ =   1,
  parameter      C2D_TUSER_WIDTH =  16,
  parameter    ENQ_DSC_CMD_WIDTH =  16,
  parameter   D2D_DSC_ADRS_WIDTH =  64,
  parameter   ACK_DSC_ADRS_WIDTH =  64,
  parameter    REG_WT_DATA_WIDTH = 512,
  parameter    REG_RD_DATA_WIDTH =  32,
  parameter       REG_USER_WIDTH =  64,
  parameter       INT_DATA_WIDTH =  32,

  parameter           CHAIN_NUM  =   4,
  parameter              CH_NUM  =  32,
  parameter        CH_PAR_CHAIN  = CH_NUM / CHAIN_NUM,
  parameter       DEQ_DSC_WIDTH  = 128,


  //Do not modify the parameters below this line
  parameter C_DATA_WIDTH = 512,
  parameter PARITY_WIDTH = C_DATA_WIDTH /8,
  parameter KEEP_WIDTH   = C_DATA_WIDTH /32
  )
(
//
     input    logic            user_clk
    ,input    logic            reset_n
    
// DMA write
    ,input    logic                           rq_dmaw_dwr_axis_tready
    ,output   logic                           rq_dmaw_dwr_axis_tvalid
    ,output   logic        [C_DATA_WIDTH-1:0] rq_dmaw_dwr_axis_tdata
    ,output   logic                           rq_dmaw_dwr_axis_tlast

    ,input    logic                           rq_dmaw_dwr_axis_wr_ptr
    ,input    logic                           rq_dmaw_dwr_axis_rd_ptr

// completion write
    ,input    logic                           rq_dmaw_cwr_axis_tready
    ,output   logic                           rq_dmaw_cwr_axis_tvalid
    ,output   logic        [C_DATA_WIDTH-1:0] rq_dmaw_cwr_axis_tdata
    ,output   logic                           rq_dmaw_cwr_axis_tlast
    
// reg_ctrl
    ,input    logic                           regreq_axis_tvalid_dmat
    ,input    logic   [REG_WT_DATA_WIDTH-1:0] regreq_axis_tdata
    ,input    logic                           regreq_axis_tlast
    ,input    logic      [REG_USER_WIDTH-1:0] regreq_axis_tuser
    ,output   logic                           regrep_axis_tvalid_dmat
    ,output   logic   [REG_RD_DATA_WIDTH-1:0] regrep_axis_tdata_dmat
    
// reg_ctrl
    ,input    logic                           cfg_interrupt_msi_enable
    ,input    logic                           cfg_interrupt_msi_sent
    ,input    logic                           cfg_interrupt_msi_fail
    ,output   logic      [INT_DATA_WIDTH-1:0] cfg_interrupt_msi_int_user
    
// read req
    ,output   logic                           rq_dmaw_crd_axis_tvalid
    ,output   logic        [C_DATA_WIDTH-1:0] rq_dmaw_crd_axis_tdata
    ,output   logic                           rq_dmaw_crd_axis_tlast
    ,input    logic                           rq_dmaw_crd_axis_tready
    
// read cmp
    ,input    logic                           rc_axis_tvalid_dmat
    ,input    logic                    [15:0] rc_axis_tuser
    ,input    logic        [C_DATA_WIDTH-1:0] rc_axis_tdata
    ,input    logic                           rc_axis_tlast
    ,output   logic                           rc_axis_tready_dmat
    
// CIFU
    ,output   logic                                 c2d_axis_tready [CHAIN_NUM-1:0]
    ,input    logic                                 c2d_axis_tvalid [CHAIN_NUM-1:0]
    ,input    logic              [C_DATA_WIDTH-1:0] c2d_axis_tdata  [CHAIN_NUM-1:0]
    ,input    logic                                 c2d_axis_tlast  [CHAIN_NUM-1:0]
    ,input    logic           [C2D_TUSER_WIDTH-1:0] c2d_axis_tuser  [CHAIN_NUM-1:0]
    ,output   logic                           [1:0] c2d_pkt_mode    [CH_NUM-1:0]
    ,output   logic                    [CH_NUM-1:0] c2d_txch_ie
    ,output   logic                    [CH_NUM-1:0] c2d_txch_clr
    ,input    logic                    [CH_NUM-1:0] c2d_cifu_busy
    ,output   logic                    [CH_NUM-1:0] c2d_cifu_rd_enb
    
// cfg
    ,input    logic                     [2:0] cfg_max_read_req
    ,input    logic                     [1:0] cfg_max_payload

    ,input    logic                           timer_pulse

    ,output   logic              [CH_NUM-1:0] dma_tx_ch_connection_enable

// trace/pa
    ,input    logic                          [31:0] dbg_freerun_count
    ,input    logic                                 dbg_enable
    ,input    logic                                 dbg_count_reset
    ,input    logic                                 dma_trace_rst
    ,input    logic                                 dma_trace_enable

// error detect
    ,output   logic                                 error_detect_dma_tx

);

//
//logic                           timer_pulse;

//

logic      [31:0] enqdeq_rd_data;
logic     [127:0] que_rd_dt;

logic                      reg_tvalid_1t;
logic              [511:0] reg_tdata_1t;
logic               [63:0] reg_tuser_1t;

logic         [CH_NUM-1:0] que_rd_req;
logic         [CH_NUM-1:0] deq_wt_req;
logic         [CH_NUM-1:0] deq_wt_ack;
logic  [DEQ_DSC_WIDTH-1:0] deq_wt_dt[CH_NUM-1:0];
logic         [CH_NUM-1:0] que_rd_dv;

logic                [2:0] pci_size;

// logic                      int_kick;

logic               [31:0] srbuf_wp      [CH_NUM-1:0];
logic               [31:0] srbuf_rp      [CH_NUM-1:0];
logic               [63:0] srbuf_addr    [CH_NUM-1:0];
logic               [31:0] srbuf_size    [CH_NUM-1:0];
logic                      frame_last    [CHAIN_NUM-1:0];
logic               [63:0] que_base_addr [CH_NUM-1:0];

logic                [2:0] ch_mode [CH_NUM-1:0];
logic         [CH_NUM-1:0] ch_ie;
logic         [CH_NUM-1:0] ch_oe;
logic         [CH_NUM-1:0] ch_clr;
logic         [CH_NUM-1:0] ch_dscq_clr;
logic         [CH_NUM-1:0] ch_busy;

logic         [CH_NUM-1:0] d2d_rp_updt;
logic               [31:0] d2d_rp;

logic                [3:0] d2d_interval;
logic                      dscq_to_enb;

logic         [CH_NUM-1:0] tx_drain_flag;

logic      [CHAIN_NUM-1:0] dwr_axis_tready ;
logic      [CHAIN_NUM-1:0] dwr_axis_tvalid ;
logic   [C_DATA_WIDTH-1:0] dwr_axis_tdata  [CHAIN_NUM-1:0];
logic      [CHAIN_NUM-1:0] dwr_axis_tlast  ;

logic      [CHAIN_NUM-1:0] rq_pend;


//// debug ////
logic                      error_clear;
logic                      err_injct_dscq;
logic         [CH_NUM-1:0] err_dscq_pe;
logic         [CH_NUM-1:0] err_dscq_pe_ins;
logic                      err_dma_tx;


// status
logic                [7:0] txch_sel;

logic               [31:0] status_reg00 [CHAIN_NUM-1:0];
logic               [31:0] status_reg01 [CHAIN_NUM-1:0];
logic               [31:0] status_reg02 [CHAIN_NUM-1:0];
logic               [31:0] status_reg03 [CHAIN_NUM-1:0];
logic               [31:0] status_reg04 [CHAIN_NUM-1:0];
logic               [31:0] status_reg05 [CHAIN_NUM-1:0];
logic               [31:0] status_reg06 [CHAIN_NUM-1:0];
logic               [31:0] status_reg07 [CHAIN_NUM-1:0];
logic               [31:0] status_reg08 [CHAIN_NUM-1:0];
logic               [31:0] status_reg09 [CHAIN_NUM-1:0];
logic               [31:0] status_reg10 [CHAIN_NUM-1:0];
logic               [31:0] status_reg11 [CHAIN_NUM-1:0];
logic               [31:0] status_reg12 [CHAIN_NUM-1:0];
logic               [31:0] status_reg13 [CHAIN_NUM-1:0];
logic               [31:0] status_reg14 [CHAIN_NUM-1:0];
logic               [31:0] status_reg15 [CHAIN_NUM-1:0];

// PA
logic               [15:0] used_addr_cnt [CHAIN_NUM-1:0];
logic         [CH_NUM-1:0] c2d_pkt_enb;
logic         [CH_NUM-1:0] d2p_pkt_enb;
logic         [CH_NUM-1:0] d2p_pkt_hd_enb;
logic         [CH_NUM-1:0] deq_wt_req_enb;
logic         [CH_NUM-1:0] deq_wt_ack_enb;

logic         [CH_NUM-1:0] pa_item_fetch_enqdeq;
logic         [CH_NUM-1:0] pa_item_receive_dsc;
logic         [CH_NUM-1:0] pa_item_store_enqdeq;
logic         [CH_NUM-1:0] pa_item_rcv_send_d2d;
logic         [CH_NUM-1:0] pa_item_send_rcv_ack;
logic               [15:0] pa_item_dscq_used_cnt[CH_NUM-1:0];


assign rc_axis_tready_dmat = 1'b1;

// enqdeq
  enqdeq #(
           .CHAIN_NUM(CHAIN_NUM)
          ,.CH_NUM(CH_NUM)
          )
    ENQDEQ (
     .user_clk     (user_clk)
    ,.reset_n      (reset_n)

// Register access IF ///////////////////////////////////////////////////////////////////////
    // input
    ,.regreq_tvalid      (reg_tvalid_1t)
    ,.regreq_tdata       (reg_tdata_1t[31:0])
    ,.regreq_tuser       (reg_tuser_1t[32:0])

    // output
    ,.regreq_rdt         (enqdeq_rd_data)
    ,.ch_mode            (ch_mode       )

    ,.ch_ie              (ch_ie         )
    ,.ch_oe              (ch_oe         )
    ,.ch_clr             (ch_clr        )
    ,.ch_dscq_clr        (ch_dscq_clr   )
    ,.ch_busy            (ch_busy       )

// Queue Read IF ///////////////////////////////////////////////////////////////////////////
    // input
    ,.que_rd_req         (que_rd_req)
    // output
    ,.que_rd_dv          (que_rd_dv)
    ,.que_rd_dt          (que_rd_dt)

    ,.rq_crd_tvalid      (rq_dmaw_crd_axis_tvalid)
    ,.rq_crd_tlast       (rq_dmaw_crd_axis_tlast)
    ,.rq_crd_tdata       (rq_dmaw_crd_axis_tdata)

    // input
    ,.rq_crd_tready      (rq_dmaw_crd_axis_tready)
    ,.rc_tvalid          (rc_axis_tvalid_dmat)
    ,.rc_tdata           (rc_axis_tdata)
    ,.rc_tuser           (rc_axis_tuser)

// Queue Write IF ///////////////////////////////////////////////////////////////////////////
    // input
    ,.que_wt_req         (deq_wt_req)
    ,.que_wt_dt          (deq_wt_dt )

    // output
    ,.que_wt_ack         (deq_wt_ack)

    ,.rq_cwr_tvalid      (rq_dmaw_cwr_axis_tvalid)
    ,.rq_cwr_tlast       (rq_dmaw_cwr_axis_tlast)
    ,.rq_cwr_tdata       (rq_dmaw_cwr_axis_tdata)

    // input
    ,.rq_cwr_tready      (rq_dmaw_cwr_axis_tready)

// D2D //////////////////////////////////////////////////////////////////////////////////////
    // input
    ,.srbuf_wp           (srbuf_wp      )
    ,.srbuf_rp           (srbuf_rp      )

    // output
    ,.srbuf_addr         (srbuf_addr    )
    ,.srbuf_size         (srbuf_size    )
    ,.que_base_addr      (que_base_addr )

// PA Counter /////////////////////////////////////////////////////////////////////////////
    ,.pa_item_fetch_enqdeq   (pa_item_fetch_enqdeq  )
    ,.pa_item_receive_dsc    (pa_item_receive_dsc   )
    ,.pa_item_store_enqdeq   (pa_item_store_enqdeq  )
    ,.pa_item_rcv_send_d2d   (pa_item_rcv_send_d2d  )
    ,.pa_item_send_rcv_ack   (pa_item_send_rcv_ack  )
    ,.pa_item_dscq_used_cnt  (pa_item_dscq_used_cnt )

  );

assign c2d_txch_ie  = ch_ie;
assign c2d_txch_clr = ch_clr;


// dma_tx_chain

for (genvar i=0; i<CHAIN_NUM; i++) begin : dma_tx_chain

dma_tx_chain #(
               .CHAIN_NUM(CHAIN_NUM)
              ,.CH_NUM(CH_NUM)
              )

 DMA_TX_CHAIN(
//
     .user_clk        (user_clk  )
    ,.reset_n         (reset_n   )
    
// DMA write
    ,.rq_dmaw_dwr_axis_tready  (dwr_axis_tready[i] )
    ,.rq_dmaw_dwr_axis_tvalid  (dwr_axis_tvalid[i] )
    ,.rq_dmaw_dwr_axis_tdata   (dwr_axis_tdata[i]  )
    ,.rq_dmaw_dwr_axis_tlast   (dwr_axis_tlast[i]  )
    
    ,.rq_pend                  (rq_pend[i]              )
//    ,.rq_dmaw_dwr_axis_wr_ptr  (rq_dmaw_dwr_axis_wr_ptr )
//    ,.rq_dmaw_dwr_axis_rd_ptr  (rq_dmaw_dwr_axis_rd_ptr )
    
// CIFU
    ,.c2d_axis_tready          (c2d_axis_tready[i] )
    ,.c2d_axis_tvalid          (c2d_axis_tvalid[i] )
    ,.c2d_axis_tdata           (c2d_axis_tdata[i]  )
    ,.c2d_axis_tlast           (c2d_axis_tlast[i]  )
    ,.c2d_axis_tuser           (c2d_axis_tuser[i]  )
    ,.c2d_pkt_mode             (c2d_pkt_mode   [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)] )
    ,.c2d_cifu_busy            (c2d_cifu_busy  [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)] )
    ,.c2d_cifu_rd_enb          (c2d_cifu_rd_enb[(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)] )

// dma_tx_dsc
    ,.que_rd_dv                (que_rd_dv    [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]   )
    ,.que_rd_dt                (que_rd_dt       )

    ,.que_rd_req               (que_rd_req   [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]   ) // [CH_NUM-1:0]

    ,.pci_size                 (pci_size        )

// D2D
    ,.srbuf_addr               (srbuf_addr   [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]   ) // [CH_NUM-1:0]
    ,.srbuf_size               (srbuf_size   [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]   ) // [CH_NUM-1:0]
    ,.srbuf_wp                 (srbuf_wp     [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]   ) // [CH_NUM-1:0]
    ,.srbuf_rp                 (srbuf_rp     [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]   ) // [CH_NUM-1:0]
    ,.que_base_addr            (que_base_addr[(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]   ) // [CH_NUM-1:0]

// ack
    ,.d2d_rp_updt              (d2d_rp_updt[(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]   ) // [CH_NUM-1:0]
    ,.d2d_rp                   (d2d_rp             )

// deq
    ,.deq_wt_req               (deq_wt_req [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]   ) // [CH_NUM-1:0]
    ,.deq_wt_dt                (deq_wt_dt  [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]   ) // [CH_NUM-1:0]
    ,.deq_wt_ack               (deq_wt_ack [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]   ) // [CH_NUM-1:0]

// reg
    ,.d2d_interval             (d2d_interval    )
    ,.dscq_to_enb              (dscq_to_enb     )


// CH controll
    ,.ch_mode                  (ch_mode     [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]    )
    ,.ch_ie                    (ch_ie       [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]    )
    ,.ch_oe                    (ch_oe       [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]    )
    ,.ch_clr                   (ch_clr      [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]    )
    ,.ch_dscq_clr              (ch_dscq_clr [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]    )
    ,.ch_busy                  (ch_busy     [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]    )

    ,.tx_drain_flag            (tx_drain_flag [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]  )

//
    ,.timer_pulse              (timer_pulse     )
//    ,.timer_pulse              (1'b0     )
    
    ,.chain                    (i        )


//// debug ////
    ,.error_clear       (error_clear       )
    ,.err_injct_dscq    (err_injct_dscq    )
    ,.err_dscq_pe       (err_dscq_pe    [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]   )
    ,.err_dscq_pe_ins   (err_dscq_pe_ins[(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]   )
    ,.err_dma_tx        (err_dma_tx      )

// status 
    ,.txch_sel          (txch_sel          )

    ,.status_reg00      (status_reg00[i]   )
    ,.status_reg01      (status_reg01[i]   )
    ,.status_reg02      (status_reg02[i]   )
    ,.status_reg03      (status_reg03[i]   )
    ,.status_reg04      (status_reg04[i]   )
    ,.status_reg05      (status_reg05[i]   )
    ,.status_reg06      (status_reg06[i]   )
    ,.status_reg07      (status_reg07[i]   )
    ,.status_reg08      (status_reg08[i]   )
    ,.status_reg09      (status_reg09[i]   )
    ,.status_reg10      (status_reg10[i]   )
    ,.status_reg11      (status_reg11[i]   )
    ,.status_reg12      (status_reg12[i]   )
    ,.status_reg13      (status_reg13[i]   )
    ,.status_reg14      (status_reg14[i]   )
    ,.status_reg15      (status_reg15[i]   )

// PA
    ,.used_addr_cnt   (used_addr_cnt [i]      )
    ,.c2d_pkt_enb     (c2d_pkt_enb   [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]      ) // [CH_NUM-1:0]
    ,.d2p_pkt_enb     (d2p_pkt_enb   [(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]      ) // [CH_NUM-1:0]
    ,.d2p_pkt_hd_enb  (d2p_pkt_hd_enb[(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]      ) // [CH_NUM-1:0]

    ,.deq_wt_req_enb  (deq_wt_req_enb[(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]      ) // [CH_NUM-1:0]
    ,.deq_wt_ack_enb  (deq_wt_ack_enb[(CH_PAR_CHAIN*(i+1)-1):(CH_PAR_CHAIN*i)]      ) // [CH_NUM-1:0]

    );


end // for (dma_tx_chan)


// dma_tx_mux
dma_tx_mux #(
               .CHAIN_NUM(CHAIN_NUM)
              )

 DMA_TX_MUX
    (
     .user_clk         (user_clk                )
    ,.reset_n          (reset_n                 )

    ,.tvalid_in        (dwr_axis_tvalid         )
    ,.tlast_in         (dwr_axis_tlast          )
    ,.tdata_in         (dwr_axis_tdata          )
    ,.tready_in        (dwr_axis_tready         )
    ,.rq_pend          (rq_pend                 )

    ,.tvalid_out       (rq_dmaw_dwr_axis_tvalid )
    ,.tlast_out        (rq_dmaw_dwr_axis_tlast  )
    ,.tdata_out        (rq_dmaw_dwr_axis_tdata  )
    ,.tready_out       (rq_dmaw_dwr_axis_tready )
    ,.trx_fifo_rd_ptr  (rq_dmaw_dwr_axis_rd_ptr )

    );


// dma_tx_reg
dma_tx_reg #(
               .CHAIN_NUM(CHAIN_NUM)
              ,.CH_NUM(CH_NUM)
              )

 DMA_TX_REG
    (
     .user_clk          (user_clk          )
    ,.reset_n           (reset_n           )
    
// reg_ctrl
    ,.reg_valid         (regreq_axis_tvalid_dmat)
    ,.reg_wt_data       (regreq_axis_tdata      )
    ,.reg_last          (regreq_axis_tlast      )
    ,.reg_user          (regreq_axis_tuser      )
    ,.reg_rd_valid      (regrep_axis_tvalid_dmat )
    ,.reg_rd_data       (regrep_axis_tdata_dmat  )

// enqdeq
    ,.reg_tvalid_1t     (reg_tvalid_1t      )
    ,.reg_tdata_1t      (reg_tdata_1t      )
    ,.reg_tuser_1t      (reg_tuser_1t      )
    ,.enqdeq_rd_data    (enqdeq_rd_data    )

// ack
    ,.d2d_rp_updt       (d2d_rp_updt       )
    ,.d2d_rp            (d2d_rp            )

// reg out
    ,.d2d_interval      (d2d_interval      )
    ,.dscq_to_enb       (dscq_to_enb       )

// cfg
    ,.cfg_max_read_req  (cfg_max_read_req  )
    ,.cfg_max_payload   (cfg_max_payload   )
    ,.pci_size          (pci_size          )

    ,.ch_ie             (ch_ie             )
    ,.ch_oe             (ch_oe             )
    ,.ch_connect        (dma_tx_ch_connection_enable)

//// debug ////
    ,.error_clear       (error_clear       )
    ,.err_injct_dscq    (err_injct_dscq    )
    ,.err_dscq_pe       (err_dscq_pe       )
    ,.err_dscq_pe_ins   (err_dscq_pe_ins   )
    ,.err_dma_tx        (err_dma_tx      )

// status 
    ,.txch_sel          (txch_sel          )

    ,.status_reg00      (status_reg00      )
    ,.status_reg01      (status_reg01      )
    ,.status_reg02      (status_reg02      )
    ,.status_reg03      (status_reg03      )
    ,.status_reg04      (status_reg04      )
    ,.status_reg05      (status_reg05      )
    ,.status_reg06      (status_reg06      )
    ,.status_reg07      (status_reg07      )
    ,.status_reg08      (status_reg08      )
    ,.status_reg09      (status_reg09      )
    ,.status_reg10      (status_reg10      )
    ,.status_reg11      (status_reg11      )
    ,.status_reg12      (status_reg12      )
    ,.status_reg13      (status_reg13      )
    ,.status_reg14      (status_reg14      )
    ,.status_reg15      (status_reg15      )

    ,.dma_trace_rst     (dma_trace_rst     )
    ,.dma_trace_enb     (dma_trace_enable  )
    ,.dbg_freerun_count (dbg_freerun_count )
    ,.dbg_enable        (dbg_enable        )
    ,.dbg_count_reset   (dbg_count_reset   )

// PA
    ,.used_addr_cnt   (used_addr_cnt )
    ,.c2d_pkt_enb     (c2d_pkt_enb    ) // [CH_NUM-1:0]
    ,.d2p_pkt_enb     (d2p_pkt_enb    ) // [CH_NUM-1:0]
    ,.d2p_pkt_hd_enb  (d2p_pkt_hd_enb ) // [CH_NUM-1:0]

    ,.deq_wt_req_enb  (deq_wt_req_enb ) // [CH_NUM-1:0]
    ,.deq_wt_ack_enb  (deq_wt_ack_enb ) // [CH_NUM-1:0]

    ,.pa_item_fetch_enqdeq   (pa_item_fetch_enqdeq  )
    ,.pa_item_receive_dsc    (pa_item_receive_dsc   )
    ,.pa_item_store_enqdeq   (pa_item_store_enqdeq  )
    ,.pa_item_rcv_send_d2d   (pa_item_rcv_send_d2d  )
    ,.pa_item_send_rcv_ack   (pa_item_send_rcv_ack  )
    ,.pa_item_dscq_used_cnt  (pa_item_dscq_used_cnt )

    ,.error_detect_dma_tx    (error_detect_dma_tx   )

//// trace / pa
//    ,.dma_trace_rst     (dma_trace_rst     )
//    ,.dbg_freerun_count (dbg_freerun_count )
//    ,.dbg_enable        (dbg_enable        )
//    ,.dbg_count_reset   (dbg_count_reset   )
//    ,.trace_on          (trace_on          )
//    ,.trace_dsc_start   (trace_dsc_start   )
//    ,.trace_dsc_end     (trace_dsc_end     )
//    ,.trace_pkt_start   (trace_pkt_start   )
//    ,.trace_pkt_end     (trace_pkt_end     )
//    ,.trace_length      (trace_length      )
//
//    ,.c2d_axis_tready    (c2d_axis_tready    )
//    ,.c2d_axis_tvalid    (c2d_axis_tvalid    )
//    ,.c2d_axis_tlast     (c2d_axis_tlast     )
//    ,.rq_dmaw_dwr_axis_tready (rq_dmaw_dwr_axis_tready )
//    ,.rq_dmaw_dwr_axis_tvalid (rq_dmaw_dwr_axis_tvalid )
//    ,.rq_dmaw_dwr_axis_tlast  (rq_dmaw_dwr_axis_tlast  )
//    ,.deq_pkt_val             (deq_pkt_val             )
//    ,.d2d_pkt_val             (d2d_pkt_val             )
//
//    ,.used_addr               (used_addr               )
//    ,.trace_keep              (trace_keep              )
//    ,.trace_data              (trace_data              )
//    ,.task_id                 (dsc_data[15:0]          )
//    ,.enq_id                  (dsc_data[31:16]         )
//    ,.trace_dsc_read          (trace_dsc_read          )

);


// dma_tx_int

dma_tx_int #(
              )

 DMA_TX_INT
    (
     .user_clk     (user_clk     )
    ,.reset_n      (reset_n      )
    
// 
    ,.int_kick     (1'b0         )

// from/to PCI_TRX
    ,.int_msi_enb  (cfg_interrupt_msi_enable)
    ,.int_msi_sent (cfg_interrupt_msi_sent  )
    ,.int_msi_fail (cfg_interrupt_msi_fail  )
    
    ,.msi_int_user (cfg_interrupt_msi_int_user)

    );


endmodule // dma_tx.sv
