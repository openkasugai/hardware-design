/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

////////////////////////////////////////////////////////
// Design      : dma_tx_reg.sv
// Designer    : hayasaka
////////////////////////////////////////////////////////

module dma_tx_reg #(
  parameter        TCQ = 1,

  parameter             CHAIN_NUM =   4,
  parameter                CH_NUM =  32,
  parameter          CH_PAR_CHAIN = CH_NUM / CHAIN_NUM,

  parameter     REG_RD_DATA_WIDTH = 32,
  parameter     REG_WT_DATA_WIDTH = 512,
  parameter        REG_USER_WIDTH = 64,

  //Do not modify the parameters below this line
  parameter C_DATA_WIDTH = 512,
  parameter PARITY_WIDTH = C_DATA_WIDTH /8,
  parameter KEEP_WIDTH   = C_DATA_WIDTH /32
  )
(
//
     input    logic            user_clk
    ,input    logic            reset_n
    
// reg_ctrl
    ,input    logic                           reg_valid
    ,input    logic   [REG_WT_DATA_WIDTH-1:0] reg_wt_data
    ,input    logic                           reg_last
    ,input    logic      [REG_USER_WIDTH-1:0] reg_user
    ,output   logic                           reg_rd_valid
    ,output   logic   [REG_RD_DATA_WIDTH-1:0] reg_rd_data

// enqdeq
    ,output   logic                           reg_tvalid_1t
    ,output   logic   [REG_WT_DATA_WIDTH-1:0] reg_tdata_1t
    ,output   logic      [REG_USER_WIDTH-1:0] reg_tuser_1t
    ,input    logic   [REG_RD_DATA_WIDTH-1:0] enqdeq_rd_data  // cycle 2t

// ack
    ,output   logic              [CH_NUM-1:0] d2d_rp_updt
    ,output   logic                    [31:0] d2d_rp

// reg
    ,output   logic                     [3:0] d2d_interval
    ,output   logic                           dscq_to_enb


// cfg
    ,input    logic                     [2:0] cfg_max_read_req
    ,input    logic                     [1:0] cfg_max_payload
    ,output   logic                     [2:0] pci_size

    ,input    logic              [CH_NUM-1:0] ch_ie
    ,input    logic              [CH_NUM-1:0] ch_oe
    ,output   logic              [CH_NUM-1:0] ch_connect

//// debug ////

    ,output  logic                            error_clear
    ,output  logic                            err_injct_dscq
    ,input   logic               [CH_NUM-1:0] err_dscq_pe
    ,input   logic               [CH_NUM-1:0] err_dscq_pe_ins
    ,output  logic                            err_dma_tx
    ,output  logic                            error_detect_dma_tx


// status
    ,output   logic                     [7:0] txch_sel

    ,input    logic                    [31:0] status_reg00 [CHAIN_NUM-1:0]
    ,input    logic                    [31:0] status_reg01 [CHAIN_NUM-1:0]
    ,input    logic                    [31:0] status_reg02 [CHAIN_NUM-1:0]
    ,input    logic                    [31:0] status_reg03 [CHAIN_NUM-1:0]
    ,input    logic                    [31:0] status_reg04 [CHAIN_NUM-1:0]
    ,input    logic                    [31:0] status_reg05 [CHAIN_NUM-1:0]
    ,input    logic                    [31:0] status_reg06 [CHAIN_NUM-1:0]
    ,input    logic                    [31:0] status_reg07 [CHAIN_NUM-1:0]
    ,input    logic                    [31:0] status_reg08 [CHAIN_NUM-1:0]
    ,input    logic                    [31:0] status_reg09 [CHAIN_NUM-1:0]
    ,input    logic                    [31:0] status_reg10 [CHAIN_NUM-1:0]
    ,input    logic                    [31:0] status_reg11 [CHAIN_NUM-1:0]
    ,input    logic                    [31:0] status_reg12 [CHAIN_NUM-1:0]
    ,input    logic                    [31:0] status_reg13 [CHAIN_NUM-1:0]
    ,input    logic                    [31:0] status_reg14 [CHAIN_NUM-1:0]
    ,input    logic                    [31:0] status_reg15 [CHAIN_NUM-1:0]

// pa
    ,input    logic                    [15:0] used_addr_cnt [CHAIN_NUM-1:0]
    ,input    logic              [CH_NUM-1:0] c2d_pkt_enb
    ,input    logic              [CH_NUM-1:0] d2p_pkt_enb
    ,input    logic              [CH_NUM-1:0] d2p_pkt_hd_enb

    ,input    logic              [CH_NUM-1:0] deq_wt_req_enb
    ,input    logic              [CH_NUM-1:0] deq_wt_ack_enb

    ,input    logic              [CH_NUM-1:0] pa_item_fetch_enqdeq
    ,input    logic              [CH_NUM-1:0] pa_item_receive_dsc
    ,input    logic              [CH_NUM-1:0] pa_item_store_enqdeq
    ,input    logic              [CH_NUM-1:0] pa_item_rcv_send_d2d
    ,input    logic              [CH_NUM-1:0] pa_item_send_rcv_ack
    ,input    logic                    [15:0] pa_item_dscq_used_cnt[CH_NUM-1:0]


// trace
    ,input    logic                           dma_trace_rst
    ,input    logic                           dma_trace_enb
    ,input    logic                    [31:0] dbg_freerun_count
    ,input    logic                           dbg_enable
    ,input    logic                           dbg_count_reset




//// for trace: input pin => clip (tentative)
//    ,input    logic                           trace_on
//    ,input    logic                           trace_dsc_start
//    ,input    logic                           trace_dsc_end
//    ,input    logic                           trace_pkt_start
//    ,input    logic                           trace_pkt_end
//    ,input    logic                    [31:0] trace_length
//
//    ,input    logic                    [15:0] trace_keep
//    ,input    logic                   [511:0] trace_data
//    ,input    logic                    [15:0] task_id
//    ,input    logic                    [15:0] enq_id
//    ,input    logic                           trace_dsc_read



);


//// for trace: input pin => clip (tentative)
logic                           trace_on        = 0;
logic                           trace_dsc_start = 0;
logic                           trace_dsc_end   = 0;
logic                           trace_pkt_start = 0;
logic                           trace_pkt_end   = 0;
logic                    [31:0] trace_length    = 0;

logic                    [15:0] trace_keep      = 0;
logic                   [511:0] trace_data      = 0;
logic                    [15:0] task_id         = 0;
logic                    [15:0] enq_id          = 0;
logic                           trace_dsc_read  = 0;

logic                           trace_mode      = 0;


// 


logic  [2:0]  cfg_max_read_req_1t;
logic  [1:0]  cfg_max_payload_1t ;
logic  [2:0]  pkt_size_pre;
logic  [2:0]  size_reg    ;
logic  [2:0]  size_rd_req ;
logic  [2:0]  size_payload;

logic  [ 31:0]  enqdeq_rdt_2t;
logic  [ 31:0]  enqdeq_rdt_3t;

logic  [ 15:0]  reg_addr;
logic           reg_read;
logic           reg_read_1t;
logic           reg_read_2t;
logic           reg_read_3t;
logic           reg_write;
logic  [511:0]  reg_wdata;

logic    [31:0] ack_data;
logic    [ 7:0] ack_chid;
logic    [31:0] ack_chid_dec;
logic           ack_vld;


//// debug ////

logic  [3:0] err_clr_timer;
logic [31:0] error_status_00;
logic [31:0] error_status_01;
logic [31:0] error_mask;
logic [31:0] eg_ctrl;
logic [31:0] eg_status;
logic        err_dscq_pe_or;
logic        err_mask_dscq_pe;

logic        dma_tx_err_or;
logic        err_dscq_pe_ins_or;
logic        err_injct_dscq_done;

// control
logic [31:0] mode_reg00;
logic [31:0] mode_reg01;
logic [31:0] mode_reg02;
logic [31:0] mode_reg03;
logic [31:0] mode_reg04;
logic [31:0] mode_reg05;
logic [31:0] mode_reg06;
logic [31:0] mode_reg07;
logic [31:0] mode_reg08;
logic [31:0] mode_reg09;
logic [31:0] mode_reg10;
logic [31:0] mode_reg11;
logic [31:0] mode_reg12;
logic [31:0] mode_reg13;
logic [31:0] mode_reg14;
logic [31:0] mode_reg15;

logic [31:0] status_reg_sel_00;
logic [31:0] status_reg_sel_01;
logic [31:0] status_reg_sel_02;
logic [31:0] status_reg_sel_03;
logic [31:0] status_reg_sel_04;
logic [31:0] status_reg_sel_05;
logic [31:0] status_reg_sel_06;
logic [31:0] status_reg_sel_07;
logic [31:0] status_reg_sel_08;
logic [31:0] status_reg_sel_09;
logic [31:0] status_reg_sel_10;
logic [31:0] status_reg_sel_11;
logic [31:0] status_reg_sel_12;
logic [31:0] status_reg_sel_13;
logic [31:0] status_reg_sel_14;
logic [31:0] status_reg_sel_15;
logic [15:0] used_addr_cnt_sel;


// PA

logic [31:0] pa_rd_data;
logic [31:0] pa_rdt_2t;
logic [31:0] pa_rdt_3t;

logic        count_reset;
logic        count_enable;

logic [31:0] c2d_pkt_cnt   [CH_NUM-1:0];
logic [31:0] d2p_pkt_cnt   [CH_NUM-1:0];
logic [31:0] deq_wt_req_cnt[CH_NUM-1:0];
logic [31:0] deq_wt_ack_cnt[CH_NUM-1:0];

logic [63:0] c2d_pkt_all_cnt;
logic [63:0] d2p_pkt_all_cnt;
logic [63:0] deq_wt_req_all_cnt;
logic [63:0] deq_wt_ack_all_cnt;


`ifdef TRACE_TX

logic [31:0] trace_wd[3:0];
logic        trace_we[3:0];
logic [31:0] trace_rd[3:0];
logic        trace_re[3:0];
logic        trace_clr;
logic        trace_enb;
logic [31:0] freerun_count;
logic [31:0] trace_dt[3:0];
logic [15:0] trace_task_id;
logic [15:0] trace_enq_id;
logic [31:0] trace_ctrl   ;

logic        trace_ctrl_mode;
logic  [2:0] trace_tim    ;
logic  [3:0] trace0_mode  ;
logic  [3:0] trace1_mode  ;
logic  [3:0] trace2_mode  ;
logic  [3:0] trace3_mode  ;

`endif


//----------------------------------------------------

logic  [3:0]  tx_ctrl;
logic  [3:0]  d2d_ctrl;
logic [31:0]  debug_ctrl;


//----------------------------------------------------


logic [15:0] pa10_add_val [CHAIN_NUM-1:0];
logic [15:0] pa12_add_val [CHAIN_NUM-1:0];
logic [15:0] pa13_add_val [CHAIN_NUM-1:0];

for (genvar i=0; i < CHAIN_NUM; i++) begin : pa12_13_assign
    always_comb begin
        pa10_add_val[i] = 16'h0000;
        pa12_add_val[i] = 16'h0000;
        pa13_add_val[i] = 16'h0000;
    end
end

pa_cnt3 #(
    .CH_NUM(CH_NUM)
        )
pa_cnt (
 .user_clk      (user_clk      )
,.reset_n       (reset_n       )

,.reg_base_addr (7'b0001_010          )  // 0x1400~0x15FC
,.regreq_tvalid (reg_tvalid_1t        )
,.regreq_tdata  (reg_tdata_1t[31:0]   )
,.regreq_tuser  (reg_tuser_1t[32:0]   )
,.regreq_rdt    (pa_rd_data[31:0]     ) // cycle 2t

,.pa_enb        (dbg_enable           )
,.pa_clr        (dbg_count_reset      )

,.pa00_inc_enb  (c2d_pkt_enb          )
,.pa01_inc_enb  (d2p_pkt_enb          )
,.pa02_inc_enb  (pa_item_fetch_enqdeq )
,.pa03_inc_enb  (pa_item_receive_dsc  )
,.pa04_inc_enb  (pa_item_store_enqdeq )
,.pa05_inc_enb  (pa_item_rcv_send_d2d )
,.pa06_inc_enb  (pa_item_send_rcv_ack )
,.pa07_inc_enb  (d2p_pkt_hd_enb       )
,.pa08_inc_enb  ({CH_NUM{1'b0}}       )
,.pa09_inc_enb  ({CH_NUM{1'b0}}       )
,.pa10_add_val  (pa10_add_val         )
,.pa11_add_val  (used_addr_cnt        )
,.pa12_add_val  (pa12_add_val         )
,.pa13_add_val  (pa13_add_val         )

);


`ifdef TRACE_TX

for (genvar i=0; i < 4; i++) begin : trace_ram

    trace_ram #(
            )
    trace_ram (
     .user_clk   (user_clk)
    ,.reset_n    (reset_n)

    ,.trace_clr  (trace_clr        )
    ,.trace_enb  (trace_enb        )
    ,.trace_we   (trace_we[i]      )
    ,.trace_wd   (trace_wd[i][31:0])
    ,.trace_re   (trace_re[i]      )
    ,.trace_mode (trace_mode       )
    ,.trace_rd   (trace_rd[i][31:0])

    );

end

`endif


// 
logic              [CH_NUM-1:0] ch_ie_1t;
logic              [CH_NUM-1:0] ch_oe_1t;
logic              [CH_NUM-1:0] ch_enb;

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        ch_ie_1t <= {CH_NUM{1'b0}};
        ch_oe_1t <= {CH_NUM{1'b0}};
        ch_enb   <= {CH_NUM{1'b0}};
    end
    else begin
        ch_ie_1t <= ch_ie;
        ch_oe_1t <= ch_oe;
        ch_enb   <= ch_ie | ch_oe;
    end
end

for (genvar i=0; i<CH_NUM; i++) begin
    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            ch_connect[i] <= 1'b0;
        end
        else begin
            ch_connect[i] <= ch_ie[i];
        end
    end
end




// to enqdeq
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        reg_tvalid_1t <=      1'b0  ;
        reg_tdata_1t  <= {512{1'b0}};
        reg_tuser_1t  <= { 64{1'b0}};
    end
    else begin
        reg_tvalid_1t <= reg_valid;
        reg_tdata_1t  <= reg_wt_data ;
        reg_tuser_1t  <= reg_user ;
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        enqdeq_rdt_2t <= {32{1'b0}};
        enqdeq_rdt_3t <= {32{1'b0}};
        pa_rdt_2t     <= {32{1'b0}};
        pa_rdt_3t     <= {32{1'b0}};
    end
    else begin
        enqdeq_rdt_2t <= enqdeq_rd_data;
        enqdeq_rdt_3t <= enqdeq_rdt_2t;
        pa_rdt_2t     <= pa_rd_data;
        pa_rdt_3t     <= pa_rdt_2t;
    end
end



// reg cntl
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        reg_addr[15:0]   <= {16{1'b0}};
        reg_read         <= 1'b0 ;
        reg_write        <= 1'b0 ;
        reg_read_1t      <= 1'b0 ;
        reg_wdata[511:0] <= {512{1'b0}};
    end
    else if ( reg_valid ) begin
        reg_addr[15:0]   <= reg_user[15:0];
        reg_read         <= (reg_user[32])? 1'b0 : 1'b1 ;
        reg_write        <= (reg_user[32])? 1'b1 : 1'b0 ;
        reg_read_1t      <= reg_read;
        reg_wdata[511:0] <= reg_wt_data[511:0];
    end
    else begin
        reg_addr[15:0]   <= reg_addr[15:0];
        reg_read         <= 1'b0 ;
        reg_write        <= 1'b0 ;
        reg_read_1t      <= reg_read;
        reg_wdata[511:0] <= reg_wdata[511:0];
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        reg_read_2t    <= 1'b0 ;
        reg_read_3t    <= 1'b0 ;
    end
    else begin
        reg_read_2t    <= reg_read_1t;
        reg_read_3t    <= reg_read_2t;
    end
end


// reg write //


assign mode_reg00[31:0] = { {28{1'b0}},  tx_ctrl[3:0] }; // 0x1400
assign mode_reg01[31:0] = { {28{1'b0}}, d2d_ctrl[3:0] }; // 0x1404
assign mode_reg02[31:0] = 32'b0;
assign mode_reg03[31:0] = 32'b0;
assign mode_reg04[31:0] = debug_ctrl[31:0];               // 0x1410
assign mode_reg05[31:0] = 32'b0;
assign mode_reg06[31:0] = 32'b0;
assign mode_reg07[31:0] = 32'b0;
assign mode_reg08[31:0] = 32'b0;
assign mode_reg09[31:0] = 32'b0;
assign mode_reg10[31:0] = 32'b0;
assign mode_reg11[31:0] = 32'b0;
assign mode_reg12[31:0] = 32'b0;
// assign mode_reg13[31:0] = 32'b0;
// assign mode_reg14[31:0] = 32'b0;
// assign mode_reg15[31:0] = 32'b0;


// reg write //
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        txch_sel[7:0] <= {8{1'b0}};
    end
    else if ( (reg_addr[15:0] == 16'h040c) && (reg_write) ) begin
        txch_sel[7:0] <= reg_wdata[7:0];
    end
    else begin
        txch_sel[7:0] <= txch_sel[7:0];
    end
end

// 0x1400 : tx_ctrl
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        tx_ctrl [3:0] <= 4'b0111;
    end
    else if ( (reg_addr[15:0] == 16'h1400) && (reg_write) ) begin
        tx_ctrl [3:0] <= reg_wdata[3:0];
    end
    else begin
        tx_ctrl[3:0] <= tx_ctrl[3:0];
    end
end

// 0x1404 : d2d_ctrl
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        d2d_ctrl[3:0] <= 4'b0010;  // default 4k
    end
    else if ( (reg_addr[15:0] == 16'h1404) && (reg_write) ) begin
        d2d_ctrl[3:0] <= reg_wdata[3:0];
    end
    else begin
        d2d_ctrl[3:0] <= d2d_ctrl[3:0];
    end
end

assign d2d_interval[3:0] = d2d_ctrl[3:0];

// 0x1410 : debug_ctrl
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        debug_ctrl[0] <= 1'b0;  // default Disable
    end
    else if ( (reg_addr[15:0] == 16'h1410) && (reg_write) ) begin
        debug_ctrl[0] <= reg_wdata[0];
    end
    else begin
        debug_ctrl[0] <= debug_ctrl[0];
    end
end

assign debug_ctrl[31:1] = {31{1'b0}};
assign dscq_to_enb      = debug_ctrl[0];


// 0x05E0 : error clear
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        error_clear <= 1'b0;  // 
    end
    else if ( (reg_addr[15:0] == 16'h05e0) && (reg_write) && reg_wdata[0] ) begin
        error_clear <= 1'b1;  // error clear
    end
    else if ( error_clear && (err_clr_timer == 4'b1111) ) begin
        error_clear <= 1'b0;  // 
    end
    else begin
        error_clear <= error_clear;
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        err_clr_timer[3:0] <= 1'b0;
    end
    else if ( error_clear && (err_clr_timer != 4'b1111) ) begin
        err_clr_timer[3:0] <= err_clr_timer[3:0] +1;
    end
    else begin
        err_clr_timer[3:0] <= 1'b0;
    end
end



// 0x05FC : error error injection (1shot)
// bit[0]
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        err_injct_dscq <= 1'b0;
    end
    else if ( (reg_addr[15:0] == 16'h05fc) && (reg_write) && reg_wdata[0] ) begin
        err_injct_dscq <= 1'b1;
    end
    else if ( (reg_addr[15:0] == 16'h05fc) && (reg_write) && ~reg_wdata[0] ) begin
        err_injct_dscq <= 1'b0;
    end
    else begin
        err_injct_dscq <= err_injct_dscq;
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        err_injct_dscq_done <= 1'b0;
    end
    else if ( (reg_addr[15:0] == 16'h05fc) && (reg_write) && ~reg_wdata[0] ) begin
        err_injct_dscq_done <= 1'b0;
    end
    else if ( err_injct_dscq && err_dscq_pe_ins_or ) begin
        err_injct_dscq_done <= 1'b1;
    end
    else begin
        err_injct_dscq_done <= err_injct_dscq_done;
    end
end

// 0x05F4 : error mask
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        err_mask_dscq_pe <= 1'b0;  // 
    end
    else if ( (reg_addr[15:0] == 16'h05f4) && (reg_write) ) begin
        err_mask_dscq_pe <=  reg_wdata[0];
    end
    else begin
        err_mask_dscq_pe <= err_mask_dscq_pe;
    end
end




always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        dma_tx_err_or <= 1'b0;
    end
    else if ( error_clear ) begin
        dma_tx_err_or <= 1'b0;
    end
    else begin
        dma_tx_err_or <= err_dscq_pe_or;
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        err_dscq_pe_or <= 1'b0;
    end
    else if ( error_clear ) begin
        err_dscq_pe_or <= 1'b0;
    end
    else if ( |(err_dscq_pe && ~err_mask_dscq_pe) ) begin
        err_dscq_pe_or <= 1'b1;
    end
    else begin
        err_dscq_pe_or <= err_dscq_pe_or;
    end
end

assign err_dscq_pe_ins_or = ( |err_dscq_pe_ins );


assign error_status_00[31:1] = {31{1'b0}};
assign error_status_00[   0] = dma_tx_err_or;

assign error_status_01[31:1] = {31{1'b0}};
assign error_status_01[   0] = err_dscq_pe_or;

assign error_mask     [31:1] = {31{1'b0}};
assign error_mask     [   0] = err_mask_dscq_pe;

assign eg_ctrl        [31:1] = {31{1'b0}};
assign eg_ctrl        [   0] = err_injct_dscq;

assign eg_status      [31:1] = {31{1'b0}};
assign eg_status      [   0] = err_injct_dscq_done;


assign err_dma_tx          = dma_tx_err_or;
assign error_detect_dma_tx = dma_tx_err_or;

// 0x1F00 : D2D ack receive
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        ack_chid[ 7:0] <= { 8{1'b0}};
        ack_data[31:0] <= {32{1'b0}};
        ack_vld        <= 1'b0;
    end
    else if ( (reg_addr[15:0] == 16'h1F00) && (reg_write) ) begin
        ack_chid[ 7:0] <= reg_wdata[23:16]; // ACK chid
        ack_data[31:0] <= reg_wdata[63:32]; // ACK rp
        ack_vld        <= 1'b1;
    end
    else begin
        ack_chid[ 7:0] <= ack_chid[ 7:0];
        ack_data[31:0] <= ack_data[31:0];
        ack_vld        <= 1'b0;
    end
end

// descriptor release

always_comb begin
    if ( ack_chid[7:4] == 4'h0 ) begin
        ack_chid_dec[31:16] = 16'h0000;
        case ( ack_chid[3:0] )
            4'h0    : ack_chid_dec[15:0] = 16'h0001;
            4'h1    : ack_chid_dec[15:0] = 16'h0002;
            4'h2    : ack_chid_dec[15:0] = 16'h0004;
            4'h3    : ack_chid_dec[15:0] = 16'h0008;
            4'h4    : ack_chid_dec[15:0] = 16'h0010;
            4'h5    : ack_chid_dec[15:0] = 16'h0020;
            4'h6    : ack_chid_dec[15:0] = 16'h0040;
            4'h7    : ack_chid_dec[15:0] = 16'h0080;
            4'h8    : ack_chid_dec[15:0] = 16'h0100;
            4'h9    : ack_chid_dec[15:0] = 16'h0200;
            4'ha    : ack_chid_dec[15:0] = 16'h0400;
            4'hb    : ack_chid_dec[15:0] = 16'h0800;
            4'hc    : ack_chid_dec[15:0] = 16'h1000;
            4'hd    : ack_chid_dec[15:0] = 16'h2000;
            4'he    : ack_chid_dec[15:0] = 16'h4000;
            4'hf    : ack_chid_dec[15:0] = 16'h8000;
            default : ack_chid_dec[15:0] = 16'h0000;
        endcase
    end
    else if ( ack_chid[7:4] == 4'h1 ) begin
        ack_chid_dec[15:0] = 16'h0000;
        case ( ack_chid[3:0] )
            4'h0    : ack_chid_dec[31:16] = 16'h0001;
            4'h1    : ack_chid_dec[31:16] = 16'h0002;
            4'h2    : ack_chid_dec[31:16] = 16'h0004;
            4'h3    : ack_chid_dec[31:16] = 16'h0008;
            4'h4    : ack_chid_dec[31:16] = 16'h0010;
            4'h5    : ack_chid_dec[31:16] = 16'h0020;
            4'h6    : ack_chid_dec[31:16] = 16'h0040;
            4'h7    : ack_chid_dec[31:16] = 16'h0080;
            4'h8    : ack_chid_dec[31:16] = 16'h0100;
            4'h9    : ack_chid_dec[31:16] = 16'h0200;
            4'ha    : ack_chid_dec[31:16] = 16'h0400;
            4'hb    : ack_chid_dec[31:16] = 16'h0800;
            4'hc    : ack_chid_dec[31:16] = 16'h1000;
            4'hd    : ack_chid_dec[31:16] = 16'h2000;
            4'he    : ack_chid_dec[31:16] = 16'h4000;
            4'hf    : ack_chid_dec[31:16] = 16'h8000;
            default : ack_chid_dec[31:16] = 16'h0000;
        endcase
    end
    else begin
        ack_chid_dec[31:0] = {32{1'b0}};
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        d2d_rp      <= {    32{1'b0}};
        d2d_rp_updt <= {CH_NUM{1'b0}};
    end
    else if ( ack_vld ) begin
        d2d_rp      <= ack_data          [31:0];
        d2d_rp_updt <= ack_chid_dec[CH_NUM-1:0] & ch_enb[CH_NUM-1:0];
    end
    else begin
        d2d_rp      <= d2d_rp [31:0];
        d2d_rp_updt <= {CH_NUM{1'b0}};
    end
end



`ifdef TRACE_TX

//// trace reg ////
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        trace_ctrl[31:0] <= {32{1'b0}};
    end
    else if ( (reg_addr[15:0] == 16'h1480) && (reg_write) ) begin
        trace_ctrl[31:0] <= reg_wdata[31:0];
    end
    else begin
        trace_ctrl[31:0] <= trace_ctrl[31:0];
    end
end

`endif



always_comb begin
    for (int i=0; i<CHAIN_NUM; i++) begin
        if ( txch_sel[7:3] == i ) begin
            status_reg_sel_00[31:0] = status_reg00[i][31:0];
            status_reg_sel_01[31:0] = status_reg01[i][31:0];
            status_reg_sel_02[31:0] = status_reg02[i][31:0];
            status_reg_sel_03[31:0] = status_reg03[i][31:0];
            status_reg_sel_04[31:0] = status_reg04[i][31:0];
            status_reg_sel_05[31:0] = status_reg05[i][31:0];
            status_reg_sel_06[31:0] = status_reg06[i][31:0];
            status_reg_sel_07[31:0] = status_reg07[i][31:0];
            status_reg_sel_08[31:0] = status_reg08[i][31:0];
            status_reg_sel_09[31:0] = status_reg09[i][31:0];
            status_reg_sel_10[31:0] = status_reg10[i][31:0];
            status_reg_sel_11[31:0] = status_reg11[i][31:0];
            status_reg_sel_12[31:0] = status_reg12[i][31:0];
            status_reg_sel_13[31:0] = status_reg13[i][31:0];
            status_reg_sel_14[31:0] = status_reg14[i][31:0];
            status_reg_sel_15[31:0] = status_reg15[i][31:0];
        end
        else begin
            status_reg_sel_00[31:0] = status_reg00[0][31:0];
            status_reg_sel_01[31:0] = status_reg01[0][31:0];
            status_reg_sel_02[31:0] = status_reg02[0][31:0];
            status_reg_sel_03[31:0] = status_reg03[0][31:0];
            status_reg_sel_04[31:0] = status_reg04[0][31:0];
            status_reg_sel_05[31:0] = status_reg05[0][31:0];
            status_reg_sel_06[31:0] = status_reg06[0][31:0];
            status_reg_sel_07[31:0] = status_reg07[0][31:0];
            status_reg_sel_08[31:0] = status_reg08[0][31:0];
            status_reg_sel_09[31:0] = status_reg09[0][31:0];
            status_reg_sel_10[31:0] = status_reg10[0][31:0];
            status_reg_sel_11[31:0] = status_reg11[0][31:0];
            status_reg_sel_12[31:0] = status_reg12[0][31:0];
            status_reg_sel_13[31:0] = status_reg13[0][31:0];
            status_reg_sel_14[31:0] = status_reg14[0][31:0];
            status_reg_sel_15[31:0] = status_reg15[0][31:0];
        end
    end
end


// reg read //

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        reg_rd_data[31:0] <= {32{1'b0}} ;
    end

// packet size
    else if ( reg_read_3t ) begin
        if ( reg_addr[15:0] == 16'h0408 ) begin
            reg_rd_data[31:0] <= { {29{1'b0}},pci_size[2:0] };
        end

// mode
        else if ( reg_addr[15:6] == 10'b0001_0100_00 ) begin  // 0x1400~0x143f
            case (reg_addr[5:2] )
                4'h0    : reg_rd_data[31:0] <= mode_reg00[31:0]; // 0x1400
                4'h1    : reg_rd_data[31:0] <= mode_reg01[31:0]; //      4
                4'h2    : reg_rd_data[31:0] <= mode_reg02[31:0]; //      8
                4'h3    : reg_rd_data[31:0] <= mode_reg03[31:0]; //      c
                4'h4    : reg_rd_data[31:0] <= mode_reg04[31:0]; // 0x1410
                4'h5    : reg_rd_data[31:0] <= mode_reg05[31:0]; //      4
                4'h6    : reg_rd_data[31:0] <= mode_reg06[31:0]; //      8
                4'h7    : reg_rd_data[31:0] <= mode_reg07[31:0]; //      c
                4'h8    : reg_rd_data[31:0] <= mode_reg08[31:0]; // 0x1420
                4'h9    : reg_rd_data[31:0] <= mode_reg09[31:0]; //      4
                4'ha    : reg_rd_data[31:0] <= mode_reg10[31:0]; //      8
                4'hb    : reg_rd_data[31:0] <= mode_reg11[31:0]; //      c
                4'hc    : reg_rd_data[31:0] <= mode_reg12[31:0]; // 0x1430
                4'hd    : reg_rd_data[31:0] <= enqdeq_rdt_3t[31:0]; //   4
                4'he    : reg_rd_data[31:0] <= pa_rdt_3t[31:0];     //   8
                4'hf    : reg_rd_data[31:0] <= enqdeq_rdt_3t[31:0]; //   c
                default : reg_rd_data[31:0] <= {32{1'b0}}         ; //
            endcase
        end

// status
        else if ( reg_addr[15:6] == 10'b0001_0100_01 ) begin  // 0x1440~0x147f
            case (reg_addr[5:2] )
                4'h0    : reg_rd_data[31:0] <= status_reg_sel_00[31:0]; // 0x1440
                4'h1    : reg_rd_data[31:0] <= status_reg_sel_01[31:0]; //      4
                4'h2    : reg_rd_data[31:0] <= status_reg_sel_02[31:0]; //      8
                4'h3    : reg_rd_data[31:0] <= status_reg_sel_03[31:0]; //      c
                4'h4    : reg_rd_data[31:0] <= status_reg_sel_04[31:0]; // 0x1450
                4'h5    : reg_rd_data[31:0] <= status_reg_sel_05[31:0]; //      4
                4'h6    : reg_rd_data[31:0] <= status_reg_sel_06[31:0]; //      8
                4'h7    : reg_rd_data[31:0] <= status_reg_sel_07[31:0]; //      c
                4'h8    : reg_rd_data[31:0] <= status_reg_sel_08[31:0]; // 0x1460
                4'h9    : reg_rd_data[31:0] <= status_reg_sel_09[31:0]; //      4
                4'ha    : reg_rd_data[31:0] <= status_reg_sel_10[31:0]; //      8
                4'hb    : reg_rd_data[31:0] <= status_reg_sel_11[31:0]; //      c
                4'hc    : reg_rd_data[31:0] <= status_reg_sel_12[31:0]; // 0x1470
                4'hd    : reg_rd_data[31:0] <= status_reg_sel_13[31:0]; //      4
                4'he    : reg_rd_data[31:0] <= status_reg_sel_14[31:0]; //      8
                4'hf    : reg_rd_data[31:0] <= status_reg_sel_15[31:0]; //      c
                default : reg_rd_data[31:0] <= {32{1'b0}}             ; //
            endcase
        end

// PA
        else if ( reg_addr[15:7] == 9'b0001_0100_1 ) begin  // 0x1480~0x14fc
            reg_rd_data[31:0] <= pa_rdt_3t[31:0];
        end

        else if ( reg_addr[15:6] == 9'b0001_0101_10 ) begin  // 0x1580~0x15bc
            reg_rd_data[31:0] <= pa_rdt_3t[31:0];
        end


// error
        else if ( reg_addr[15:6] == 10'b0000_0101_11 ) begin  // 0x05c0~0x05ff
            case (reg_addr[5:2] )
              //4'h0    : reg_rd_data[31:0] <= status_reg_sel_00[31:0]; // 0x05c0
              //4'h1    : reg_rd_data[31:0] <= status_reg_sel_01[31:0]; //      4
              //4'h2    : reg_rd_data[31:0] <= status_reg_sel_02[31:0]; //      8
              //4'h3    : reg_rd_data[31:0] <= status_reg_sel_03[31:0]; //      c
              //4'h4    : reg_rd_data[31:0] <= status_reg_sel_04[31:0]; // 0x05d0
              //4'h5    : reg_rd_data[31:0] <= status_reg_sel_05[31:0]; //      4
              //4'h6    : reg_rd_data[31:0] <= status_reg_sel_06[31:0]; //      8
              //4'h7    : reg_rd_data[31:0] <= status_reg_sel_07[31:0]; //      c
                4'h8    : reg_rd_data[31:0] <= error_status_00  [31:0]; // 0x05e0
                4'h9    : reg_rd_data[31:0] <= error_status_01  [31:0]; //      4
              //4'ha    : reg_rd_data[31:0] <=                        ; //      8
              //4'hb    : reg_rd_data[31:0] <=                        ; //      c
              //4'hc    : reg_rd_data[31:0] <=                        ; // 0x05f0
                4'hd    : reg_rd_data[31:0] <= error_mask             ; //      4
                4'he    : reg_rd_data[31:0] <= eg_status        [31:0]; //      8
                4'hf    : reg_rd_data[31:0] <= eg_ctrl          [31:0]; //      c
                default : reg_rd_data[31:0] <= {32{1'b0}}             ; //
            endcase
        end


// ENQDEQ (0x04xx)
        else begin
            reg_rd_data[31:0] <= enqdeq_rdt_3t[31:0];
        end
    end
    else begin
        reg_rd_data[31:0] <= reg_rd_data[31:0];
    end
end


// read valid //
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        reg_rd_valid      <= 1'b0 ;
    end
    else begin
        if (reg_read_3t) begin
            reg_rd_valid      <= 1'b1;
        end
        else begin
            reg_rd_valid      <= 1'b0;
        end
    end
end




// output //



// PCI size

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        size_reg[2:0] <= 3'b000;
    end
    else begin
        case (tx_ctrl[2:0])
            3'b000 : size_reg[2:0] = 3'b000; //  128byte
            3'b001 : size_reg[2:0] = 3'b001; //  256byte
            3'b010 : size_reg[2:0] = 3'b010; //  512byte
            3'b011 : size_reg[2:0] = 3'b011; // 1024byte
            3'b100 : size_reg[2:0] = 3'b100; // 2048byte
            default: size_reg[2:0] = 3'b101; // 4096byte
        endcase
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        size_rd_req[2:0] <= 3'b000;
    end
    else begin
        case (cfg_max_read_req_1t[2:0])
            3'b000 : size_rd_req[2:0] = 3'b000; //  128byte
            3'b001 : size_rd_req[2:0] = 3'b001; //  256byte
            3'b010 : size_rd_req[2:0] = 3'b010; //  512byte
            3'b011 : size_rd_req[2:0] = 3'b011; // 1024byte
            3'b100 : size_rd_req[2:0] = 3'b100; // 2048byte
            3'b101 : size_rd_req[2:0] = 3'b101; // 4096byte
            default: size_rd_req[2:0] = 3'b101; // 4096byte
        endcase
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        size_payload[2:0] <= 3'b000;
    end
    else begin
        case (cfg_max_payload_1t[1:0])
            2'b00  : size_payload[2:0] = 3'b000; //  128byte
            2'b01  : size_payload[2:0] = 3'b001; //  256byte
            2'b10  : size_payload[2:0] = 3'b010; //  512byte
            2'b11  : size_payload[2:0] = 3'b011; // 1024byte
            default: size_payload[2:0] = 3'b011; // 1024byte
        endcase
    end
end


always_comb begin
    if ( tx_ctrl[3] == 1'b0 ) begin
        if (size_rd_req[2:0] < size_payload[2:0]) begin
            if (size_rd_req[2:0] < size_reg[2:0]) begin
                pkt_size_pre[2:0] = size_rd_req[2:0];
            end
            else begin
                pkt_size_pre[2:0] = size_reg[2:0];
            end
        end
        else if (size_payload[2:0] < size_reg[2:0]) begin
            pkt_size_pre[2:0] = size_payload[2:0];
        end
        else begin
            pkt_size_pre[2:0] = size_reg[2:0];
        end
    end
    else begin
        pkt_size_pre[2:0] = size_reg[2:0];
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        cfg_max_read_req_1t[2:0] <= 3'b000;
        cfg_max_payload_1t [1:0] <= 2'b00;
    end
    else begin
        cfg_max_read_req_1t[2:0] <= cfg_max_read_req[2:0];
        cfg_max_payload_1t [1:0] <= cfg_max_payload [1:0];
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        pci_size[2:0] <= 3'b000;
    end
    else begin
        pci_size[2:0] <=  pkt_size_pre[2:0];
    end
end



//// debug ////

// PA

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        count_reset  <= 1'b0  ;
        count_enable <= 1'b0  ;
    end
    else begin
        count_reset  <= dbg_count_reset;
        count_enable <= dbg_enable     ;
    end
end


for (genvar i=0; CH_NUM>i; i++) begin

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            c2d_pkt_cnt   [i][31:0] <= {32{1'b0}};
            d2p_pkt_cnt   [i][31:0] <= {32{1'b0}};
            deq_wt_req_cnt[i][31:0] <= {32{1'b0}};
            deq_wt_ack_cnt[i][31:0] <= {32{1'b0}};
        end
        else if (count_reset) begin
            c2d_pkt_cnt   [i][31:0] <= {32{1'b0}};
            d2p_pkt_cnt   [i][31:0] <= {32{1'b0}};
            deq_wt_req_cnt[i][31:0] <= {32{1'b0}};
            deq_wt_ack_cnt[i][31:0] <= {32{1'b0}};
        end
        else if (count_enable) begin
            c2d_pkt_cnt   [i][31:0] <= (c2d_pkt_enb   [i])? c2d_pkt_cnt   [i][31:0] +1 : c2d_pkt_cnt   [i][31:0];
            d2p_pkt_cnt   [i][31:0] <= (d2p_pkt_enb   [i])? d2p_pkt_cnt   [i][31:0] +1 : d2p_pkt_cnt   [i][31:0];
            deq_wt_req_cnt[i][31:0] <= (deq_wt_req_enb[i])? deq_wt_req_cnt[i][31:0] +1 : deq_wt_req_cnt[i][31:0];
            deq_wt_ack_cnt[i][31:0] <= (deq_wt_ack_enb[i])? deq_wt_ack_cnt[i][31:0] +1 : deq_wt_ack_cnt[i][31:0];
        end
        else begin
            c2d_pkt_cnt   [i][31:0] <= c2d_pkt_cnt   [i][31:0];
            d2p_pkt_cnt   [i][31:0] <= d2p_pkt_cnt   [i][31:0];
            deq_wt_req_cnt[i][31:0] <= deq_wt_req_cnt[i][31:0];
            deq_wt_ack_cnt[i][31:0] <= deq_wt_ack_cnt[i][31:0];
        end
    end

end // for(i)


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        c2d_pkt_all_cnt   [63:0] <= {64{1'b0}};
        d2p_pkt_all_cnt   [63:0] <= {64{1'b0}};
        deq_wt_req_all_cnt[63:0] <= {64{1'b0}};
        deq_wt_ack_all_cnt[63:0] <= {64{1'b0}};
    end
    else if (count_reset) begin
        c2d_pkt_all_cnt   [63:0] <= {64{1'b0}};
        d2p_pkt_all_cnt   [63:0] <= {64{1'b0}};
        deq_wt_req_all_cnt[63:0] <= {64{1'b0}};
        deq_wt_ack_all_cnt[63:0] <= {64{1'b0}};
    end
    else if (count_enable) begin
        c2d_pkt_all_cnt   [63:0] <= (|c2d_pkt_enb   )? c2d_pkt_all_cnt   [63:0] +1 : c2d_pkt_all_cnt   [63:0];
        d2p_pkt_all_cnt   [63:0] <= (|d2p_pkt_enb   )? d2p_pkt_all_cnt   [63:0] +1 : d2p_pkt_all_cnt   [63:0];
        deq_wt_req_all_cnt[63:0] <= (|deq_wt_req_enb)? deq_wt_req_all_cnt[63:0] +1 : deq_wt_req_all_cnt[63:0];
        deq_wt_ack_all_cnt[63:0] <= (|deq_wt_ack_enb)? deq_wt_ack_all_cnt[63:0] +1 : deq_wt_ack_all_cnt[63:0];
    end
    else begin
        c2d_pkt_all_cnt   [63:0] <= c2d_pkt_all_cnt   [63:0];
        d2p_pkt_all_cnt   [63:0] <= d2p_pkt_all_cnt   [63:0];
        deq_wt_req_all_cnt[63:0] <= deq_wt_req_all_cnt[63:0];
        deq_wt_ack_all_cnt[63:0] <= deq_wt_ack_all_cnt[63:0];
    end
end



`ifdef TRACE_TX

// debug

assign trace_ctrl_mode  = trace_ctrl[31]   ;
assign trace_tim  [2:0] = trace_ctrl[30:28];
assign trace0_mode[3:0] = (trace_ctrl_mode)? trace_ctrl[ 3: 0] : trace_ctrl[27:24];
assign trace1_mode[3:0] = (trace_ctrl_mode)? trace_ctrl[ 7: 4] : trace_ctrl[27:24];
assign trace2_mode[3:0] = (trace_ctrl_mode)? trace_ctrl[11: 8] : trace_ctrl[27:24];
assign trace3_mode[3:0] = (trace_ctrl_mode)? trace_ctrl[15:12] : trace_ctrl[27:24];



always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        trace_clr           <=     1'b0  ;
        trace_enb           <=     1'b0  ;
        freerun_count[31:0] <= {32{1'b0}};
    end
    else begin
        trace_clr           <= dma_trace_rst ;
        trace_enb           <= dma_trace_enb ;
        freerun_count[31:0] <= dbg_freerun_count[31:0];
    end
end

assign trace_start = (trace_tim[2])? trace_pkt_start : trace_dsc_start;
assign trace_end   = (trace_tim[2])? trace_pkt_end   : trace_dsc_end  ;


always_comb begin
    case (trace0_mode)
        4'h0   : trace_dt[0][31:0] = freerun_count[31:0];
        4'h1   : trace_dt[0][31:0] = { trace_keep [15:0], trace_data[15:0] };
        4'h2   : trace_dt[0][31:0] = trace_data   [31:0];
        default: trace_dt[0][31:0] = freerun_count[31: 0];
    endcase
end

always_comb begin
    case (trace1_mode)
        4'h0   : trace_dt[1][31:0] = freerun_count[31: 0];
        4'h1   : trace_dt[1][31:0] = { trace_keep [15: 0], trace_data[15:0] };
        4'h2   : trace_dt[1][31:0] = trace_data   [63:32];
        default: trace_dt[1][31:0] = freerun_count[31: 0];
    endcase
end

always_comb begin
    case (trace2_mode)
        4'h0   : trace_dt[2][31:0] = trace_length[31: 0];
        4'h1   : trace_dt[2][31:0] = trace_length[31: 0];
        4'h2   : trace_dt[2][31:0] = trace_data  [95:64];
        default: trace_dt[2][31:0] = trace_length[31: 0];
    endcase
end

always_comb begin
    case (trace3_mode)
        4'h0   : trace_dt[3][31:0] = { trace_task_id[ 15: 0], trace_enq_id[15:0] };
        4'h1   : trace_dt[3][31:0] = { trace_task_id[ 15: 0], trace_enq_id[15:0] };
        4'h2   : trace_dt[3][31:0] = trace_data     [127:96];
        default: trace_dt[3][31:0] = { trace_task_id[ 15: 0], trace_enq_id[15:0] };
    endcase
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        trace_task_id[15:0] <= {16{1'b0}};
        trace_enq_id [15:0] <= {16{1'b0}};
    end
    else if (trace_dsc_read) begin
        trace_task_id[15:0] <= task_id[15:0];
        trace_enq_id [15:0] <= enq_id [15:0];
    end
    else begin
        trace_task_id[15:0] <= trace_task_id[15:0];
        trace_enq_id [15:0] <= trace_enq_id [15:0];
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        trace_re[0] <=     1'b0  ;
        trace_re[1] <=     1'b0  ;
        trace_re[2] <=     1'b0  ;
        trace_re[3] <=     1'b0  ;
    end
    else if (reg_read) begin
        trace_re[0] <= (reg_addr[15:0] == 16'h15e0)? 1'b1 : 1'b0 ;
        trace_re[1] <= (reg_addr[15:0] == 16'h15e4)? 1'b1 : 1'b0 ;
        trace_re[2] <= (reg_addr[15:0] == 16'h15e8)? 1'b1 : 1'b0 ;
        trace_re[3] <= (reg_addr[15:0] == 16'h15ec)? 1'b1 : 1'b0 ;
    end
    else begin
        trace_re[0] <= 1'b0 ;
        trace_re[1] <= 1'b0 ;
        trace_re[2] <= 1'b0 ;
        trace_re[3] <= 1'b0 ;
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        trace_we[0] <=     1'b0  ;
        trace_we[2] <=     1'b0  ;
        trace_we[3] <=     1'b0  ;
        trace_wd[0] <= {32{1'b0}};
        trace_wd[2] <= {32{1'b0}};
        trace_wd[3] <= {32{1'b0}};
    end
    else if (trace_on ) begin
       if (~trace_ctrl_mode) begin
           if ( trace_start ) begin
               trace_we[0]       <= 1'b1;
               trace_we[2]       <= 1'b1;
               trace_we[3]       <= 1'b1;
               trace_wd[0][31:0] <= trace_dt[0][31:0];
               trace_wd[2][31:0] <= trace_dt[2][31:0];
               trace_wd[3][31:0] <= trace_dt[3][31:0];
           end
           else begin
               trace_we[0]       <= 1'b0;
               trace_we[2]       <= 1'b0;
               trace_we[3]       <= 1'b0;
               trace_wd[0][31:0] <= trace_wd[0][31:0];
               trace_wd[2][31:0] <= trace_wd[2][31:0];
               trace_wd[3][31:0] <= trace_wd[3][31:0];
           end
       end
       else begin // trace_ctrl_mode
           if ( trace_start && (   (trace_tim[1:0] == 2'b00)
                                 | (trace_tim[1:0] == 2'b01) )
              ) begin                                                 // tim : 100,101
               trace_we[0]       <= 1'b1;
               trace_we[2]       <= 1'b1;
               trace_we[3]       <= 1'b1;
               trace_wd[0][31:0] <= trace_dt[0][31:0];
               trace_wd[2][31:0] <= trace_dt[2][31:0];
               trace_wd[3][31:0] <= trace_dt[3][31:0];
           end
           else if ( trace_end &&  (trace_tim[1:0] == 2'b10) ) begin  // tim : 110
               trace_we[0]       <= 1'b1;
               trace_we[2]       <= 1'b1;
               trace_we[3]       <= 1'b1;
               trace_wd[0][31:0] <= trace_dt[0][31:0];
               trace_wd[2][31:0] <= trace_dt[2][31:0];
               trace_wd[3][31:0] <= trace_dt[3][31:0];
           end
           else begin
               trace_we[0]       <= 1'b0;
               trace_we[2]       <= 1'b0;
               trace_we[3]       <= 1'b0;
               trace_wd[0][31:0] <= trace_wd[0][31:0];
               trace_wd[2][31:0] <= trace_wd[2][31:0];
               trace_wd[3][31:0] <= trace_wd[3][31:0];
           end
       end
   end
   else begin
       trace_we[0] <= 1'b0 ;
       trace_we[2] <= 1'b0 ;
       trace_we[3] <= 1'b0 ;
       trace_wd[0] <= trace_wd[0];
       trace_wd[2] <= trace_wd[2];
       trace_wd[3] <= trace_wd[3];
   end

end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        trace_we[1] <=     1'b0  ;
        trace_wd[1] <= {32{1'b0}};
    end
    else if (trace_on ) begin
       if (~trace_ctrl_mode) begin
           if ( trace1_mode != 4'h2 ) begin
               if ( trace_end   ) begin
                   trace_we[1]       <= 1'b1;
                   trace_wd[1][31:0] <= trace_dt[1][31:0];
               end
               else begin
                   trace_we[1]       <= 1'b0;
                   trace_wd[1][31:0] <= trace_wd[1][31:0];
               end
           end
           else begin  // trace1_mode : 0 or 1
               if ( trace_start ) begin
                   trace_we[1]       <= 1'b1;
                   trace_wd[1][31:0] <= trace_dt[1][31:0];
               end
               else begin
                   trace_we[1]       <= 1'b0;
                   trace_wd[1][31:0] <= trace_wd[1][31:0];
               end
           end
       end
       else begin // trace_ctrl_mode
           if ( trace_start && (   (trace_tim[1:0] == 2'b00)
                                 | (trace_tim[1:0] == 2'b01) )
              ) begin                                                 // tim : 100,101
               trace_we[1]       <= 1'b1;
               trace_wd[1][31:0] <= trace_dt[1][31:0];
           end
           else if ( trace_end &&  (trace_tim[1:0] == 2'b10) ) begin  // tim : 110
               trace_we[1]       <= 1'b1;
               trace_wd[1][31:0] <= trace_dt[1][31:0];
           end
           else begin
               trace_we[1]       <= 1'b0;
               trace_wd[1][31:0] <= trace_wd[1][31:0];
           end
       end
   end
   else begin
       trace_we[1] <= 1'b0 ;
       trace_wd[1] <= trace_wd[1];
   end

end





`endif





endmodule // dma_tx_reg.sv
