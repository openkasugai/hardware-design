/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/


////////////////////////////////////////////////////////
// Design      : dma_tx_chain.sv
// Designer    : hayasaka
////////////////////////////////////////////////////////


`define TRACE_TX

module dma_tx_chain #(
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
    ,input    logic                          rq_dmaw_dwr_axis_tready
    ,output   logic                          rq_dmaw_dwr_axis_tvalid
    ,output   logic       [C_DATA_WIDTH-1:0] rq_dmaw_dwr_axis_tdata
    ,output   logic                          rq_dmaw_dwr_axis_tlast

    ,input    logic                          rq_pend

// CIFU
    ,output   logic                          c2d_axis_tready
    ,input    logic                          c2d_axis_tvalid
    ,input    logic       [C_DATA_WIDTH-1:0] c2d_axis_tdata
    ,input    logic                          c2d_axis_tlast
    ,input    logic    [C2D_TUSER_WIDTH-1:0] c2d_axis_tuser
    ,output   logic                    [1:0] c2d_pkt_mode [CH_PAR_CHAIN-1:0]

    ,input    logic       [CH_PAR_CHAIN-1:0] c2d_cifu_busy
    ,output   logic       [CH_PAR_CHAIN-1:0] c2d_cifu_rd_enb

// enqdeq
    ,input    logic       [CH_PAR_CHAIN-1:0] que_rd_dv
    ,input    logic      [DEQ_DSC_WIDTH-1:0] que_rd_dt

    ,output   logic       [CH_PAR_CHAIN-1:0] que_rd_req

    ,input    logic                   [63:0] srbuf_addr    [CH_PAR_CHAIN-1:0]
    ,input    logic                   [31:0] srbuf_size    [CH_PAR_CHAIN-1:0]
    ,input    logic                   [63:0] que_base_addr [CH_PAR_CHAIN-1:0]
    ,output   logic                   [31:0] srbuf_wp      [CH_PAR_CHAIN-1:0]
    ,output   logic                   [31:0] srbuf_rp      [CH_PAR_CHAIN-1:0]

    ,output   logic       [CH_PAR_CHAIN-1:0] deq_wt_req
    ,output   logic      [DEQ_DSC_WIDTH-1:0] deq_wt_dt  [CH_PAR_CHAIN-1:0]
    ,input    logic       [CH_PAR_CHAIN-1:0] deq_wt_ack


    
// reg
    ,input    logic                    [2:0] pci_size
    ,input    logic                    [3:0] d2d_interval
    ,input    logic                          dscq_to_enb

    ,input    logic       [CH_PAR_CHAIN-1:0] d2d_rp_updt
    ,input    logic                   [31:0] d2d_rp


// CH controll
    ,input    logic                    [2:0] ch_mode [CH_PAR_CHAIN-1:0]
    ,input    logic       [CH_PAR_CHAIN-1:0] ch_ie
    ,input    logic       [CH_PAR_CHAIN-1:0] ch_oe
    ,input    logic       [CH_PAR_CHAIN-1:0] ch_clr
    ,input    logic       [CH_PAR_CHAIN-1:0] ch_dscq_clr
    ,output   logic       [CH_PAR_CHAIN-1:0] ch_busy

    ,output   logic       [CH_PAR_CHAIN-1:0] tx_drain_flag

// cfg
    ,input    logic                          timer_pulse

    ,input    logic                   [31:0] chain


//// debug ////
    ,input    logic                          error_clear
    ,input    logic                          err_injct_dscq
    ,output   logic       [CH_PAR_CHAIN-1:0] err_dscq_pe
    ,output   logic       [CH_PAR_CHAIN-1:0] err_dscq_pe_ins
    ,input    logic                          err_dma_tx

// status
    ,input    logic                    [7:0] txch_sel

    ,output   logic                   [31:0] status_reg00
    ,output   logic                   [31:0] status_reg01
    ,output   logic                   [31:0] status_reg02
    ,output   logic                   [31:0] status_reg03
    ,output   logic                   [31:0] status_reg04
    ,output   logic                   [31:0] status_reg05
    ,output   logic                   [31:0] status_reg06
    ,output   logic                   [31:0] status_reg07
    ,output   logic                   [31:0] status_reg08
    ,output   logic                   [31:0] status_reg09
    ,output   logic                   [31:0] status_reg10
    ,output   logic                   [31:0] status_reg11
    ,output   logic                   [31:0] status_reg12
    ,output   logic                   [31:0] status_reg13
    ,output   logic                   [31:0] status_reg14
    ,output   logic                   [31:0] status_reg15

// PA
    ,output   logic                   [15:0] used_addr_cnt
    ,output   logic       [CH_PAR_CHAIN-1:0] c2d_pkt_enb
    ,output   logic       [CH_PAR_CHAIN-1:0] d2p_pkt_enb
    ,output   logic       [CH_PAR_CHAIN-1:0] d2p_pkt_hd_enb

    ,output   logic       [CH_PAR_CHAIN-1:0] deq_wt_req_enb
    ,output   logic       [CH_PAR_CHAIN-1:0] deq_wt_ack_enb

//    ,output   logic                          trace_on
//    ,output   logic                          trace_dsc_start
//    ,output   logic                          trace_dsc_end
//    ,output   logic                          trace_pkt_start
//    ,output   logic                          trace_pkt_end
//    ,output   logic                   [31:0] trace_length


//    ,output   logic                   [11:0] used_addr
//    ,output   logic                   [15:0] trace_keep
//    ,output   logic                  [511:0] trace_data
//    ,output   logic                          trace_dsc_read

// trace/pa
//    ,input    logic                   [31:0] dbg_freerun_count
//    ,input    logic                          dbg_enable
//    ,input    logic                          dbg_count_reset
//    ,input    logic                          dma_trace_rst
//    ,input    logic                          dma_trace_enable


);

//

logic      [31:0] enqdeq_rd_data;

logic                      reg_tvalid_1t;
logic              [511:0] reg_tdata_1t;
logic               [63:0] reg_tuser_1t;

logic   [CH_PAR_CHAIN-1:0] dscq_rls;
logic              [127:0] dscq_rls_dt;
logic   [CH_PAR_CHAIN-1:0] dscq_vld;
logic  [DEQ_DSC_WIDTH-1:0] dscq_dt       [CH_PAR_CHAIN-1:0];

logic               [31:0] deq_frm_len;

logic              [511:0] deq_pkt_out;

logic   [CH_PAR_CHAIN-1:0] deq_kick;
logic                      deq_comp;
logic                      deq_full;
logic   [CH_PAR_CHAIN-1:0] d2d_kick;
logic                      d2d_enb;
logic                      int_kick;

logic   [CH_PAR_CHAIN-1:0] tx_deq_busy;

logic   [CH_PAR_CHAIN-1:0] dscq_ovfl_hld;
logic   [CH_PAR_CHAIN-1:0] dscq_udfl_hld;

logic                      frame_last;


//// debug ////

// PA
logic   [CH_PAR_CHAIN-1:0] pa_item_fetch_enqdeq;
logic   [CH_PAR_CHAIN-1:0] pa_item_receive_dsc;
logic   [CH_PAR_CHAIN-1:0] pa_item_store_enqdeq;
logic   [CH_PAR_CHAIN-1:0] pa_item_rcv_send_d2d;
logic   [CH_PAR_CHAIN-1:0] pa_item_send_rcv_ack;
logic               [15:0] pa_item_dscq_used_cnt[CH_PAR_CHAIN-1:0];

// dma_tx_ctrl

dma_tx_ctrl #(
               .CHAIN_NUM(CHAIN_NUM)
              ,.CH_NUM(CH_NUM)
              )

 DMA_TX_CTRL(
//
     .user_clk        (user_clk  )
    ,.reset_n         (reset_n   )
    
// DMA write
    ,.rq_dmaw_dwr_axis_tready  (rq_dmaw_dwr_axis_tready )
    ,.rq_dmaw_dwr_axis_tvalid  (rq_dmaw_dwr_axis_tvalid )
    ,.rq_dmaw_dwr_axis_tdata   (rq_dmaw_dwr_axis_tdata  )
    ,.rq_dmaw_dwr_axis_tlast   (rq_dmaw_dwr_axis_tlast  )
    
    ,.rq_pend                  (rq_pend                 )
//    ,.rq_dmaw_dwr_axis_wr_ptr  (rq_dmaw_dwr_axis_wr_ptr )
//    ,.rq_dmaw_dwr_axis_rd_ptr  (rq_dmaw_dwr_axis_rd_ptr )
    
// completion write
    ,.rq_dmaw_cwr_axis_tready  (1'b0 )
    ,.rq_dmaw_cwr_axis_tvalid  ( )
    ,.rq_dmaw_cwr_axis_tdata   ( )
    ,.rq_dmaw_cwr_axis_tlast   ( )
    
// CIFU
    ,.c2d_axis_tready          (c2d_axis_tready )
    ,.c2d_axis_tvalid          (c2d_axis_tvalid )
    ,.c2d_axis_tdata           (c2d_axis_tdata  )
    ,.c2d_axis_tlast           (c2d_axis_tlast  )
    ,.c2d_axis_tuser           (c2d_axis_tuser  )
    ,.c2d_pkt_mode             (c2d_pkt_mode    )
    ,.c2d_cifu_busy            (c2d_cifu_busy   )
    ,.c2d_cifu_rd_enb          (c2d_cifu_rd_enb )

// dma_tx_dsc
    ,.dscq_vld                 (dscq_vld        ) // [CH_PAR_CHAIN-1:0]
    ,.dscq_dt                  (dscq_dt         ) // [CH_PAR_CHAIN-1:0]
    ,.dscq_rls                 (dscq_rls        ) // [CH_PAR_CHAIN-1:0]
    ,.dscq_rls_dt              (dscq_rls_dt     )

    ,.deq_wt_val               (1'b0            ) // [CH_PAR_CHAIN-1:0]
    ,.deq_pkt_out              ({512{1'b0}}     )
    ,.deq_comp                 (deq_comp        )
    ,.deq_full                 (deq_full        )
    ,.d2d_pkt_val              (1'b0            ) // "0" clip
    ,.d2d_pkt_out              ({512{1'b0}}     ) // "0" clip
    ,.d2d_wt_end               (1'b0            ) // "0" clip
    ,.deq_kick                 (deq_kick        )
    ,.deq_frm_len              (deq_frm_len     )
    ,.d2d_kick                 (d2d_kick        )
    ,.d2d_enb                  (d2d_enb         ) // open
    ,.int_kick                 (int_kick        ) // open

    ,.dscq_ovfl_hld            (dscq_ovfl_hld   )
    ,.dscq_udfl_hld            (dscq_udfl_hld   )

    ,.pci_size                 (pci_size        )

// D2D
    ,.srbuf_addr               (srbuf_addr      )
    ,.srbuf_size               (srbuf_size      )
    ,.que_base_addr            (que_base_addr   )

    ,.srbuf_wp                 (srbuf_wp        )
    ,.srbuf_rp                 (srbuf_rp        )
    ,.frame_last               (frame_last      )

// ack
    ,.d2d_rp_updt              (d2d_rp_updt     )
    ,.d2d_rp                   (d2d_rp          )

// reg
    ,.d2d_interval             (d2d_interval    )
    ,.dscq_to_enb              (dscq_to_enb     )


// CH controll
    ,.ch_mode                  (ch_mode         )
    ,.ch_ie                    (ch_ie           )
    ,.ch_oe                    (ch_oe           )
    ,.ch_clr                   (ch_clr          )
    ,.ch_dscq_clr              (ch_dscq_clr     )
    ,.ch_busy                  (ch_busy         )

    ,.tx_deq_busy              (tx_deq_busy     )
    ,.tx_drain_flag            (tx_drain_flag   )

//
    ,.timer_pulse              (timer_pulse     )

    ,.chain                    (chain[1:0]      )

//// debug ////
    ,.err_dscq_pe              (err_dscq_pe     )
    ,.err_dma_tx               (err_dma_tx      )

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

// PA
    ,.used_addr_cnt   (used_addr_cnt       )
    ,.c2d_pkt_enb     (c2d_pkt_enb         ) // [CH_PAR_CHAIN-1:0]
    ,.d2p_pkt_enb     (d2p_pkt_enb         ) // [CH_PAR_CHAIN-1:0]
    ,.d2p_pkt_hd_enb  (d2p_pkt_hd_enb      ) // [CH_PAR_CHAIN-1:0]


    );


// dma_tx_dsc

dma_tx_dsc #(
               .CHAIN_NUM(CHAIN_NUM)
              ,.CH_NUM(CH_NUM)
              )

 DMA_TX_DSC
    (
     .user_clk          (user_clk        )
    ,.reset_n           (reset_n         )

// 
    ,.que_rd_dv         (que_rd_dv       ) // [CH_PAR_CHAIN-1:0]
    ,.que_rd_dt         (que_rd_dt       )


    ,.dscq_rls          (dscq_rls        ) // [CH_PAR_CHAIN-1:0]
    ,.dscq_vld          (dscq_vld        ) // [CH_PAR_CHAIN-1:0]
    ,.dscq_dt           (dscq_dt         ) // [CH_PAR_CHAIN-1:0]
    ,.que_rd_req        (que_rd_req      ) // [CH_PAR_CHAIN-1:0]

    ,.ch_dscq_clr       (ch_dscq_clr     ) // [CH_PAR_CHAIN-1:0]

    ,.dscq_ovfl_hld     (dscq_ovfl_hld   )
    ,.dscq_udfl_hld     (dscq_udfl_hld   )

    ,.error_clear       (error_clear       )
    ,.err_injct_dscq    (err_injct_dscq    )
    ,.err_dscq_pe       (err_dscq_pe       )
    ,.err_dscq_pe_ins   (err_dscq_pe_ins   )

    );


// dma_tx_deq

dma_tx_deq #(
               .CHAIN_NUM(CHAIN_NUM)
              ,.CH_NUM(CH_NUM)
              )

 DMA_TX_DEQ
    (
     .user_clk      (user_clk      )
    ,.reset_n       (reset_n       )
    
// CH controll
    ,.ch_mode       (ch_mode       )
    ,.ch_oe         (ch_oe         )

// 
    ,.dscq_dt       (dscq_dt       )
    ,.dscq_rls      (dscq_rls      ) // [CH_PAR_CHAIN-1:0]
    ,.dscq_rls_dt   (dscq_rls_dt   )

    ,.srbuf_wp      (srbuf_wp      )
    ,.frame_last    (frame_last    )

    ,.dma_tx_status (16'h0000      )

    ,.deq_kick      (deq_kick      ) // [CH_PAR_CHAIN-1:0]
    ,.d2d_kick      (d2d_kick      ) // [CH_PAR_CHAIN-1:0]
    ,.deq_frm_len   (deq_frm_len   )
    ,.deq_wt_ack    (deq_wt_ack    )
    ,.deq_wt_req    (deq_wt_req    )
    ,.deq_wt_dt     (deq_wt_dt     )
    ,.deq_comp      (deq_comp      )
    ,.deq_full      (deq_full      )

    ,.tx_drain_flag (tx_drain_flag )
    ,.tx_deq_busy   (tx_deq_busy   )

//// debug ////

    ,.deq_wt_req_enb  (deq_wt_req_enb ) // [CH_PAR_CHAIN-1:0]
    ,.deq_wt_ack_enb  (deq_wt_ack_enb ) // [CH_PAR_CHAIN-1:0]

    );


endmodule // dma_tx_chain.sv
