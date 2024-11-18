/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/


////////////////////////////////////////////////////////
// Design      : dma_tx_ctrl.sv
// Designer    : hayasaka
////////////////////////////////////////////////////////

module dma_tx_ctrl #(
  parameter             CHAIN_NUM =   4,
  parameter                CH_NUM =  32,
  parameter          CH_PAR_CHAIN = CH_NUM / CHAIN_NUM,
  parameter         DEQ_DSC_WIDTH = 128,

  parameter                   TCQ =   1,
  parameter       C2D_TUSER_WIDTH =  16,
  parameter     ENQ_DSC_CMD_WIDTH =  16,
  parameter    D2D_DSC_ADRS_WIDTH =  64,
  parameter    ACK_DSC_ADRS_WIDTH =  64,
  parameter     REG_WT_DATA_WIDTH =  32,
  parameter     REG_RD_DATA_WIDTH =  32,
  parameter        REG_USER_WIDTH =  64,
  parameter        INT_DATA_WIDTH =  32,

  //Do not modify the parameters below this line
  parameter C_DATA_WIDTH = 512,
  parameter PARITY_WIDTH = C_DATA_WIDTH /8
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

    ,input    logic                           rq_pend
//    ,input    logic                           rq_dmaw_dwr_axis_wr_ptr
//    ,input    logic                           rq_dmaw_dwr_axis_rd_ptr

// completion write
    ,input    logic                           rq_dmaw_cwr_axis_tready
    ,output   logic                           rq_dmaw_cwr_axis_tvalid
    ,output   logic        [C_DATA_WIDTH-1:0] rq_dmaw_cwr_axis_tdata
    ,output   logic                           rq_dmaw_cwr_axis_tlast
    
// CIFU
    ,output   logic                           c2d_axis_tready
    ,input    logic                           c2d_axis_tvalid
    ,input    logic        [C_DATA_WIDTH-1:0] c2d_axis_tdata
    ,input    logic                           c2d_axis_tlast
    ,input    logic     [C2D_TUSER_WIDTH-1:0] c2d_axis_tuser
    ,input    logic        [CH_PAR_CHAIN-1:0] c2d_cifu_busy
    ,output   logic                     [1:0] c2d_pkt_mode [CH_PAR_CHAIN-1:0]
    ,output   logic        [CH_PAR_CHAIN-1:0] c2d_cifu_rd_enb
    

// dma_tx_dsc
    ,input    logic        [CH_PAR_CHAIN-1:0] dscq_vld
    ,input    logic       [DEQ_DSC_WIDTH-1:0] dscq_dt      [CH_PAR_CHAIN-1:0]
    ,output   logic        [CH_PAR_CHAIN-1:0] dscq_rls
    ,output   logic                   [127:0] dscq_rls_dt

    ,input    logic                           deq_wt_val // [CH_PAR_CHAIN-1:0]
    ,input    logic        [C_DATA_WIDTH-1:0] deq_pkt_out
    ,input    logic                           deq_comp
    ,input    logic                           deq_full
    ,input    logic                           d2d_pkt_val  // "0" clip
    ,input    logic        [C_DATA_WIDTH-1:0] d2d_pkt_out  // "0" clip
    ,input    logic                           d2d_wt_end   // "0" clip
    ,output   logic        [CH_PAR_CHAIN-1:0] deq_kick
    ,output   logic                    [31:0] deq_frm_len
    ,output   logic        [CH_PAR_CHAIN-1:0] d2d_kick
    ,output   logic                           d2d_enb
    ,output   logic                           int_kick

    ,input    logic        [CH_PAR_CHAIN-1:0] dscq_ovfl_hld
    ,input    logic        [CH_PAR_CHAIN-1:0] dscq_udfl_hld

    ,input    logic                     [2:0] pci_size


// D2D/ACK
    ,input    logic                    [63:0] srbuf_addr    [CH_PAR_CHAIN-1:0]
    ,input    logic                    [31:0] srbuf_size    [CH_PAR_CHAIN-1:0]
    ,input    logic                    [63:0] que_base_addr [CH_PAR_CHAIN-1:0]

    ,output   logic                    [31:0] srbuf_wp      [CH_PAR_CHAIN-1:0]
    ,output   logic                    [31:0] srbuf_rp      [CH_PAR_CHAIN-1:0]
    ,output   logic                           frame_last

    ,input    logic        [CH_PAR_CHAIN-1:0] d2d_rp_updt
    ,input    logic                    [31:0] d2d_rp

// reg
    ,input    logic                     [3:0] d2d_interval
    ,input    logic                           dscq_to_enb

// CH controll
    ,input    logic                     [2:0] ch_mode [CH_PAR_CHAIN-1:0]
    ,input    logic        [CH_PAR_CHAIN-1:0] ch_ie
    ,input    logic        [CH_PAR_CHAIN-1:0] ch_oe
    ,input    logic        [CH_PAR_CHAIN-1:0] ch_clr
    ,input    logic        [CH_PAR_CHAIN-1:0] ch_dscq_clr
    ,output   logic        [CH_PAR_CHAIN-1:0] ch_busy

    ,input    logic        [CH_PAR_CHAIN-1:0] tx_deq_busy
    ,output   logic        [CH_PAR_CHAIN-1:0] tx_drain_flag


//
    ,input    logic                           timer_pulse

    ,input    logic                     [1:0] chain

//// debug ////
    ,input    logic        [CH_PAR_CHAIN-1:0] err_dscq_pe
    ,input    logic                           err_dma_tx

// status
    ,input    logic                     [7:0] txch_sel

    ,output   logic                    [31:0] status_reg00
    ,output   logic                    [31:0] status_reg01
    ,output   logic                    [31:0] status_reg02
    ,output   logic                    [31:0] status_reg03
    ,output   logic                    [31:0] status_reg04
    ,output   logic                    [31:0] status_reg05
    ,output   logic                    [31:0] status_reg06
    ,output   logic                    [31:0] status_reg07
    ,output   logic                    [31:0] status_reg08
    ,output   logic                    [31:0] status_reg09
    ,output   logic                    [31:0] status_reg10
    ,output   logic                    [31:0] status_reg11
    ,output   logic                    [31:0] status_reg12
    ,output   logic                    [31:0] status_reg13
    ,output   logic                    [31:0] status_reg14
    ,output   logic                    [31:0] status_reg15

// PA
    ,output   logic                    [15:0] used_addr_cnt
    ,output   logic        [CH_PAR_CHAIN-1:0] c2d_pkt_enb
    ,output   logic        [CH_PAR_CHAIN-1:0] d2p_pkt_enb
    ,output   logic        [CH_PAR_CHAIN-1:0] d2p_pkt_hd_enb
//    ,output   logic              [CH_NUM-1:0] dsc_wait_cnt_enb

//    ,output   logic                           trace_on
//    ,output   logic                           trace_dsc_start
//    ,output   logic                           trace_dsc_end
//    ,output   logic                           trace_pkt_start
//    ,output   logic                           trace_pkt_end
//    ,output   logic                    [31:0] trace_length


//    ,output   logic                    [11:0] used_addr
//    ,output   logic                    [15:0] trace_keep
//    ,output   logic                   [511:0] trace_data
//    ,output   logic                           trace_dsc_read

);



//----------------------------------------------------


logic                       c2d_axis_tvalid_1t;
logic    [C_DATA_WIDTH-1:0] c2d_axis_tdata_1t;
logic                       c2d_axis_tlast_1t;
logic [C2D_TUSER_WIDTH-1:0] c2d_axis_tuser_1t;

logic        [2:0] dmaw_stm;
logic        [1:0] deq_stm;
logic       [10:0] wt_addr;
logic       [10:0] rd_addr;
logic       [11:0] used_addr;
logic       [11:0] free_addr;
logic              wt_enb_sop;
logic              wt_enb_eop;
logic              pkt_eop_valid;
logic              pkt_eop_valid_1t;
logic              pkt_last_valid;
logic              pkt_last_valid_1t;
logic       [11:0] eop_cnt;

logic              dwr_axis_tready;

logic        [4:0] rd_tag;
logic              deq_stm_kick;
logic              dmaw_buff_full;
logic              dmaw_buff_empty;

logic              dmaw_valid;
logic              dmaw_end;
logic              dmaw_end_1t;
logic              dma_write_end;
logic              dma_write_end_1t;
logic              dma_write_end_2t;
logic              dma_write_end_3t;
logic              dmaw_stm_hd_gen_1t;
logic              dmaw_stm_hd_gen_2t;
logic              dmaw_stm_hd_gen_3t;

logic              rd_data2_sop;
logic              rd_data2_eop;
logic              rd_data2_last;
logic        [2:0] rd_data2_cid;
logic        [4:0] rd_data2_burst;
logic              rd_data2_frm_hd;
logic              rd_data2_frm_last;
logic              rd_data2_frm_last_1t;
logic              rd_data2_frm_last_2t;

logic        [4:0] rd_burst;
logic              [4:0] rd_burst_count;
logic        [4:0] rd_cnt;
logic              [4:0] re_cnt;
logic              [4:0] dmaw_cnt;
logic              [4:0] dmaw_burst_cnt;
logic              [4:0] pkt_cycle;
logic             [31:0] pkt_length;
logic              [4:0] def_pkt_cycle;
logic             [31:0] def_pkt_length;
logic                    pkt_eop_flag;
logic                    pkt_last_flag;
logic                    send_1st_flag;
logic              [4:0] send_1st_size;
logic             [31:0] send_1st_len;
logic              [4:0] pkt_cycle_stm;

logic                    deq_wt_val_or;
logic                    deq_wt_enb_flag;
logic                    d2d_wt_enb_flag;
logic                    int_enb_flag;

logic                    wt_enb;
logic [CH_PAR_CHAIN-1:0] wt_enb_pre;
logic                    rd_enb;
logic                    rd_enb_1t;
logic                    rd_enb_2t;
logic                    rd_enb_3t;
logic                    rd_enb_flag;
logic                    rd_pkt_flag;

logic    [511:  0] in_buf_data1;
logic    [511:  0] in_buf_data2;
logic    [511:  0] rd_buff;
logic    [ 31:  0] rd_buff2;
logic    [511:  0] rd_data1;
logic    [511:  0] rd_data1_1t;
logic    [ 31:  0] rd_data2_1t;
logic    [511:  0] rd_data1_2t;
logic    [ 31:  0] rd_data2_2t;
logic    [511:  0] rd_data2;
logic    [127:  0] wt_header;
logic    [127:  0] wt_header2;
logic    [127:  0] rd_header;
logic    [ 15:  0] wt_keep;

logic    [511:  0] fifo_rdt1;
logic    [511:  0] fifo_rdt2;
logic    [ 10:  0] fifo_wp;
logic    [ 10:  0] fifo_rp;

logic   [CH_PAR_CHAIN-1:0] dscq_vld_1t;
logic  [DEQ_DSC_WIDTH-1:0] dscq_dt_1t [CH_PAR_CHAIN-1:0];

logic                      dscq_vld_or;
logic                      dscq_vld_mch;
logic               [15:0] dsc_task_id;
logic                [7:0] dsc_cmd;
logic               [31:0] dsc_dst_len;
logic               [63:0] dsc_dst_addr;
logic               [63:0] dst_addr        [CH_PAR_CHAIN-1:0];
logic               [63:0] dst_addr_add    [CH_PAR_CHAIN-1:0];
logic               [63:0] dst_addr_add_1t [CH_PAR_CHAIN-1:0];
logic   [CH_PAR_CHAIN-1:0] dst_addr_add_carry;
logic               [31:0] dst_length;
logic                [4:0] burst_length;
logic               [31:0] frame_len[CH_PAR_CHAIN-1:0];

logic              [127:0] dsc_sel_data;

logic                      ram_rd_ready;

logic                [2:0] cid_hld;
logic                [7:0] cid_dec;
logic                [7:0] cid_sel;

logic               [63:0] d2d_addr        [CH_PAR_CHAIN-1:0];
logic               [31:0] d2d_addr_add    [CH_PAR_CHAIN-1:0];
logic               [31:0] d2d_addr_add_1t [CH_PAR_CHAIN-1:0];
logic               [31:0] d2d_add_mask    [CH_PAR_CHAIN-1:0];
logic               [31:0] d2d_cnt         [CH_PAR_CHAIN-1:0];
logic               [31:0] d2d_rbuf_wp     [CH_PAR_CHAIN-1:0];
logic               [31:0] d2d_rbuf_rp     [CH_PAR_CHAIN-1:0];
logic               [31:0] d2d_rbuf_rp_1t  [CH_PAR_CHAIN-1:0];
logic                      d2d_kick_set;
logic                      d2d_kick_or;
logic   [CH_PAR_CHAIN-1:0] d2d_kick_flag;
logic                      d2d_kick_wait;
logic               [31:0] d2d_interval_cnt;
logic               [31:0] d2d_srbuf_free  [CH_PAR_CHAIN-1:0];
logic                      rq_pend_1t;
logic                      rq_pend_2t;
logic               [31:0] d2d_direct_add   [CH_PAR_CHAIN-1:0];
logic               [31:0] d2d_direct_add_1t[CH_PAR_CHAIN-1:0];

logic                [2:0] ch_mode_1t [CH_PAR_CHAIN-1:0];
logic   [CH_PAR_CHAIN-1:0] ch_mode_0;
logic   [CH_PAR_CHAIN-1:0] ch_mode_1;
logic   [CH_PAR_CHAIN-1:0] ch_mode_2;
logic   [CH_PAR_CHAIN-1:0] ch_mode_0_1t;
logic   [CH_PAR_CHAIN-1:0] ch_mode_1_1t;
logic   [CH_PAR_CHAIN-1:0] ch_mode_2_1t;
logic                [2:0] curr_mode_sel;
logic                [2:0] curr_mode;
logic                [2:0] curr_mode_1t;
logic                [2:0] curr_mode_2t;

logic               [63:0] srbuf_addr_1t [CH_PAR_CHAIN-1:0];
logic               [31:0] srbuf_size_1t [CH_PAR_CHAIN-1:0];
logic   [CH_PAR_CHAIN-1:0] srbuf_size_err;
logic               [63:0] d2d_direct_base_addr [CH_PAR_CHAIN-1:0];


logic   [CH_PAR_CHAIN-1:0] dma_stop_flag;

//// debug ////

logic                    c2d_ready_1t;
logic                    c2d_valid_1t;
logic              [2:0] c2d_cid_1t;
logic                    c2d_sop_1t;
logic                    c2d_eop_1t;
logic              [4:0] c2d_burst_1t;
logic                    c2d_last_1t;
logic              [7:0] c2d_cid_dec;
logic                    c2d_frame_header;
logic                    c2d_pkt_flag;
logic                    c2d_pkt_drop;
logic [CH_PAR_CHAIN-1:0] c2d_pkt_busy;
logic [CH_PAR_CHAIN-1:0] c2d_pkt_drop_flag;
logic [CH_PAR_CHAIN-1:0] c2d_pkt_drop_flag_1t;

logic                    d2p_ready_1t;
logic                    d2p_valid_1t;
logic              [2:0] d2p_cid_1t;
logic              [2:0] d2p_cid_2t;
logic                    d2p_sop_1t;
logic                    d2p_eop_1t;
logic              [4:0] d2p_burst_1t;
logic                    d2p_last_1t;
logic              [7:0] d2p_cid_dec;

logic             [31:0] d2d_sts_wp;
logic             [31:0] d2d_sts_rp;

logic [CH_PAR_CHAIN-1:0] dwr_valid_drain;
logic                    dwr_valid_drain_or;

logic             [10:0] tx_drain_wp   [CH_PAR_CHAIN-1:0];
logic [CH_PAR_CHAIN-1:0] tx_buff_busy;
logic [CH_PAR_CHAIN-1:0] tx_busy;

logic [CH_PAR_CHAIN-1:0] ch_ie_1t;
logic [CH_PAR_CHAIN-1:0] ch_oe_1t;
logic [CH_PAR_CHAIN-1:0] ch_clr_1t;
logic [CH_PAR_CHAIN-1:0] ch_dscq_clr_1t;
logic                    timer_pulse_1t;
logic              [7:0] dscq_empty_timer [CH_PAR_CHAIN-1:0];
logic [CH_PAR_CHAIN-1:0] dscq_empty_timeout;

logic [CH_PAR_CHAIN-1:0] dst_addr_align_err;

logic              [1:0] chain_1t;

logic                    stm_dsc_wait;
logic                    stm_dsc_wait_1t;
logic                    dsc_wait_cnt;
logic                    dsc_wait_cnt_1t;
logic       [CH_NUM-1:0] dsc_wait_cnt_enb;

logic             [31:0] d2d_direct_offset[CH_PAR_CHAIN-1:0] ;
logic             [63:0] d2d_direct_addr  [CH_PAR_CHAIN-1:0] ;

logic                    err_dscq_pe_or;
logic                    err_dma_tx_1t;

localparam DMA_IDLE = 3'b000;
localparam RAM_RD   = 3'b001;
localparam DSC_RD   = 3'b010;
localparam HD_GEN   = 3'b011;
localparam DMA_WT   = 3'b100;
localparam DEQ_KICK = 3'b101;
localparam DSC_WAIT = 3'b111;

localparam DEQ_IDLE = 2'b00;
localparam RD_0LEN  = 2'b01;
localparam RD_WAIT  = 2'b10;
localparam DEQ_WT   = 2'b11;

localparam D2D_DIRECT_BASE = 64'h0000000000012000;
localparam D2D_DIRECT_SIZE = 32'h00001000;


// 
assign dwr_axis_tready  = rq_dmaw_dwr_axis_tready & ~deq_full ;

// chain number
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        chain_1t <= 2'b00;
    end
    else begin
        chain_1t <= chain;
    end
end

// D2D direct address

for (genvar i=0; i<CH_PAR_CHAIN; i++) begin

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            d2d_direct_offset[i]    <= {32{1'b0}};
            d2d_direct_base_addr[i] <= {64{1'b0}};
            d2d_direct_addr  [i]    <= {64{1'b0}};
        end
        else begin
            d2d_direct_offset[i]    <= ( 16'h0400 * (i + (chain_1t *8)) );
            d2d_direct_base_addr[i] <= D2D_DIRECT_BASE  + que_base_addr[i];
            d2d_direct_addr  [i]    <= d2d_direct_offset[i] + d2d_direct_base_addr[i];
        end
    end

end


// descriptor
for (genvar i=0; i<CH_PAR_CHAIN; i++) begin
    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            dscq_vld_1t[i] <= 1'b0;
        end
        else if ( dscq_rls[i] ) begin
            dscq_vld_1t[i] <= 1'b0;
        end
        else if ( ch_dscq_clr_1t[i] ) begin
            dscq_vld_1t[i] <= 1'b0;
        end
        else begin
            dscq_vld_1t[i] <= (dscq_vld[i] | ch_mode_1_1t[i] | ch_mode_2_1t[i] | dscq_empty_timeout[i]) & ~err_dscq_pe[CH_PAR_CHAIN-1:0];
        end
    end
end

for (genvar i=0; i<CH_PAR_CHAIN; i++) begin
    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            dscq_dt_1t[i][127:0] <= {128{1'b0}};
        end
        else if ( dscq_vld[i] ) begin
            dscq_dt_1t[i][127:0] <= dscq_dt[i][127:0];
        end
        else begin
            dscq_dt_1t[i][127:0] <= dscq_dt_1t[i][127:0];
        end
    end
end


always_comb begin
    dsc_task_id  [15:0] = {16{1'b0}};
    dsc_cmd      [ 7:0] = { 8{1'b0}};
    dsc_dst_len  [31:0] = {32{1'b0}};
    dsc_dst_addr [63:0] = {64{1'b0}};

    for (int i=0; i<CH_PAR_CHAIN; i++) begin
        if ( cid_hld[2:0] == i ) begin
            dsc_task_id  [15:0] = dscq_dt_1t[i][ 15: 0];
            dsc_cmd      [ 7:0] = dscq_dt_1t[i][ 23:16];
            dsc_dst_len  [31:0] = dscq_dt_1t[i][ 63:32];
            dsc_dst_addr [63:0] = dscq_dt_1t[i][127:64];
        end
    end

end


assign dsc_sel_data[ 15: 0]  = dsc_task_id [15:0];
assign dsc_sel_data[ 23:16]  = dsc_cmd     [ 7:0];
assign dsc_sel_data[ 31:24]  = 8'h00;
assign dsc_sel_data[ 63:32]  = dsc_dst_len [31:0];
assign dsc_sel_data[127:64]  = dsc_dst_addr[63:0];

//always_ff @(posedge user_clk or negedge reset_n) begin
//    if (~reset_n) begin
//        dsc_sel_data[127:0]  <= {128{1'b0}};
//    end
//    else begin
//        dsc_sel_data[ 15: 0]  <= dsc_task_id [15:0];
//        dsc_sel_data[ 23:16]  <= dsc_cmd     [ 7:0];
//        dsc_sel_data[ 63:32]  <= dsc_dst_len [31:0];
//        dsc_sel_data[127:64]  <= dsc_dst_addr[63:0];
//    end
//end



// headre
assign wt_header[  1:  0] = 2'b00;           //
assign wt_header[  5:  2] = 4'h0;            // dst_address[5:2]
//assign wt_header[ 63:  2] = dsc_dst_addr[63:2] + dst_addr_add_1t[63:2] ; // dst_address
assign wt_header[ 74: 64] = dst_length[12:2]; // length(DW)
assign wt_header[ 78: 75] = 4'b0001;         // mem wt
assign wt_header    [ 79] = 1'b0;            //
assign wt_header[ 87: 80] = 8'h00;           //
assign wt_header[ 95: 88] = 8'h00;           //
assign wt_header[103: 96] = 8'h00;           // wt_tag[7:0]
assign wt_header[111:104] = 8'h00;           //
assign wt_header[119:112] = 8'h00;           //
assign wt_header    [120] = 1'b0;            //
assign wt_header[123:121] = 3'b000;          //
assign wt_header[126:124] = 3'b000;          //
assign wt_header    [127] = 1'b0;            //

assign rd_header[  1:  0] =  2'b00;          //
assign rd_header[  5:  2] =  4'h0;           // dst_address[5:2]
//assign rd_header[ 63:  2] = dsc_dst_addr[63:2] + dst_addr_add_1t[63:2] ; // dst_address
assign rd_header[ 74: 64] = 11'h000;         // length(DW)
assign rd_header[ 78: 75] =  4'b0000;        // mem read
assign rd_header    [ 79] =  1'b0;           //
assign rd_header[ 87: 80] =  8'h00;          //
assign rd_header[ 95: 88] =  8'h00;          //
assign rd_header[103: 96] =  {3'b011, rd_tag[4:0]}; // [7:5] 011 : DMA_TX 0length read, [4:0] CH No.
assign rd_header[111:104] =  8'h00;          //
assign rd_header[119:112] =  8'h00;          //
assign rd_header    [120] =  1'b0;           //
assign rd_header[123:121] =  3'b000;         //
assign rd_header[126:124] =  3'b000;         //
assign rd_header    [127] =  1'b0;           //


for (genvar i=0; i<CH_PAR_CHAIN; i++) begin
    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            dst_addr[i][63:0] <= {64{1'b0}};
        end
        else if (ch_dscq_clr_1t[i]) begin
            dst_addr[i][63:0] <= {64{1'b0}};
        end
        else begin
            dst_addr[i][63:0] <= dscq_dt_1t[i][127:64] + dst_addr_add_1t[i][63:0] ; // dst_address;
        end
    end
end


// dst addr 
always_comb begin
    wt_header[63:6] = {58{1'b0}};
    rd_header[63:6] = {58{1'b0}};

    for (int i=0; i<CH_PAR_CHAIN; i++) begin
        if ( cid_hld[2:0] == i ) begin
            wt_header[ 63:6] = dst_addr[i][63:6] ; // dst_address
            rd_header[ 63:6] = dst_addr[i][63:6] ; // dst_address
        end
    end

end

assign err_dscq_pe_or = (|err_dscq_pe);

assign dscq_vld_or =  (|dscq_vld_1t) | ~err_dscq_pe_or;


always_comb begin
    if ( rd_data2_sop ) begin
        dscq_vld_mch = 1'b0;
        for (int i=0; i<CH_PAR_CHAIN; i++) begin
            if ( rd_data2_cid[2:0] == i ) begin
                dscq_vld_mch = dscq_vld_1t[i];
            end
        end
    end
    else if ( rd_data2_1t[2] ) begin  // r_data2_sop_1t
        dscq_vld_mch = 1'b0;
        for (int i=0; i<CH_PAR_CHAIN; i++) begin
            if ( rd_data2_1t[6:4] == i ) begin  // rd_data2_cid_1t
                dscq_vld_mch = dscq_vld_1t[i];
            end
        end
    end
    else begin
        dscq_vld_mch = 1'b0;
    end
end


// DMA W ctrl STM

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        dmaw_stm      <= DMA_IDLE;
        dmaw_end      <= 1'b0;
        
        pkt_cycle_stm[4:0] <= {5{1'b1}};
    end
    else if ( dwr_axis_tready )begin
        case(dmaw_stm)

            DMA_IDLE : begin
                dmaw_stm      <= ( ram_rd_ready && dscq_vld_or && ~(|dma_stop_flag) && ~(|d2d_kick_flag) && ~err_dma_tx_1t )? DSC_RD : dmaw_stm;   // dscq_vld_1t or
                dmaw_end      <= 1'b0;
                
                pkt_cycle_stm[4:0] <= pkt_cycle_stm[4:0];
            end

            DSC_RD : begin
                if ( dscq_vld_mch && ~err_dscq_pe_or ) begin  // dscq_vld_1t[n] == cid
                    dmaw_stm      <= HD_GEN;
                    dmaw_end      <= 1'b0;
                    pkt_cycle_stm[4:0] <= pkt_cycle[4:0];
                end
                else if ( err_dscq_pe_or ) begin
                    dmaw_stm      <= DMA_IDLE;
                    dmaw_end      <= 1'b0;
                    pkt_cycle_stm[4:0] <= pkt_cycle_stm[4:0];
                end
                else begin
                    dmaw_stm      <= DSC_WAIT;
                    dmaw_end      <= 1'b0;
                    pkt_cycle_stm[4:0] <= pkt_cycle_stm[4:0];
                end
            end

            DSC_WAIT : begin
                if ( dscq_vld_mch ) begin  // dscq_vld_1t[n] == cid
                    dmaw_stm      <= HD_GEN;
                    dmaw_end      <= 1'b0;
                    pkt_cycle_stm[4:0] <= pkt_cycle[4:0];
                end
                else begin
                    dmaw_stm      <= dmaw_stm;
                    dmaw_end      <= 1'b0;
                    pkt_cycle_stm[4:0] <= pkt_cycle[4:0];
                end
            end

            HD_GEN : begin
                dmaw_stm      <= DMA_WT;
                dmaw_end      <= 1'b0;
                pkt_cycle_stm[4:0] <= pkt_cycle_stm[4:0];
            end

            DMA_WT : begin
                if ( rd_burst[4:0] <= (dmaw_burst_cnt[4:0]+1) ) begin
                    dmaw_stm      <= DMA_IDLE;
                    dmaw_end      <= 1'b1;
                    pkt_cycle_stm[4:0] <= pkt_cycle_stm[4:0];
                end
                else if ( pkt_cycle_stm[4:0] <= dmaw_cnt[4:0] ) begin
                    dmaw_stm      <= HD_GEN;
                    dmaw_end      <= 1'b1;
                    pkt_cycle_stm[4:0] <= pkt_cycle[4:0];
                end
                else begin
                    dmaw_stm      <= dmaw_stm;
                    dmaw_end      <= 1'b0;
                    pkt_cycle_stm[4:0] <= pkt_cycle_stm[4:0];
                end
            end

            default : begin
                dmaw_stm      <= DMA_IDLE;
                dmaw_end      <= 1'b0;
                pkt_cycle_stm[4:0] <= pkt_cycle_stm[4:0];
            end

        endcase
    end
    else begin
        dmaw_stm <= dmaw_stm;
        dmaw_end <= dmaw_end;
    end
end


// ch mode

for (genvar i=0; i<CH_PAR_CHAIN; i++) begin

    assign ch_mode_0[i] = ( ch_mode[i][2:0] == 3'b000 );
    assign ch_mode_1[i] = ( ch_mode[i][2:0] == 3'b001 );
    assign ch_mode_2[i] = ( ch_mode[i][2:0] == 3'b010 );

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            c2d_pkt_mode[i][1:0] <= 2'b00;
        end
        else begin
            c2d_pkt_mode[i][1:0] <= ch_mode[i][1:0];
        end
    end

end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        ch_mode_0_1t[CH_PAR_CHAIN-1:0] <= {CH_PAR_CHAIN{1'b0}};
        ch_mode_1_1t[CH_PAR_CHAIN-1:0] <= {CH_PAR_CHAIN{1'b0}};
        ch_mode_2_1t[CH_PAR_CHAIN-1:0] <= {CH_PAR_CHAIN{1'b0}};
    end
    else begin
        ch_mode_0_1t[CH_PAR_CHAIN-1:0] <= ch_mode_0[CH_PAR_CHAIN-1:0];
        ch_mode_1_1t[CH_PAR_CHAIN-1:0] <= ch_mode_1[CH_PAR_CHAIN-1:0];
        ch_mode_2_1t[CH_PAR_CHAIN-1:0] <= ch_mode_2[CH_PAR_CHAIN-1:0];
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        d2d_kick[CH_PAR_CHAIN-1:0] <= {CH_PAR_CHAIN{1'b0}};
    end
    else if ( d2d_kick_set  ) begin
        d2d_kick[CH_PAR_CHAIN-1:0] <= ch_mode_1_1t[CH_PAR_CHAIN-1:0] & d2d_kick_flag[CH_PAR_CHAIN-1:0];
    end
    else begin
        d2d_kick[CH_PAR_CHAIN-1:0] <= {CH_PAR_CHAIN{1'b0}};
    end
end

assign d2d_kick_or  = |d2d_kick ;

always_comb begin
    curr_mode_sel[2:0] = {3{1'b0}};
    for (int i=0; i<CH_PAR_CHAIN; i++) begin
        if ( i == rd_data2_cid ) begin
            curr_mode_sel[2:0] = ch_mode[i][2:0];
        end
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        curr_mode[2:0] <= {3{1'b0}};
    end
    else if ( rd_enb && rd_data2_sop ) begin
        curr_mode[2:0] <= curr_mode_sel[2:0];
    end
    else begin
        curr_mode[2:0] <= curr_mode[2:0];
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        curr_mode_1t <= {3{1'b0}};
        curr_mode_2t <= {3{1'b0}};
    end
    else if ( dwr_axis_tready
              && (dmaw_stm != DSC_WAIT)
             ) begin
        curr_mode_1t <= curr_mode;
        curr_mode_2t <= curr_mode_1t;
    end
    else begin
        curr_mode_1t <= curr_mode_1t;
        curr_mode_2t <= curr_mode_2t;
    end
end



// DEQ STM

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        deq_stm         <= DEQ_IDLE;
        deq_kick        <= {CH_PAR_CHAIN{1'b0}};
        int_kick        <= 1'b0;
    end else begin
        case(deq_stm)
            DEQ_IDLE : begin
                deq_stm  <= (deq_stm_kick)? RD_WAIT : deq_stm;
            end
            RD_0LEN : begin
                    deq_stm         <= RD_WAIT;
                    deq_kick        <= {CH_PAR_CHAIN{1'b0}};
            end
            RD_WAIT : begin
                    deq_stm         <= DEQ_WT;
                    deq_kick        <= cid_sel[CH_PAR_CHAIN-1:0] & ~tx_drain_flag[CH_PAR_CHAIN-1:0];
            end
            DEQ_WT : begin
                deq_stm         <= DEQ_IDLE;
                deq_kick        <= {CH_PAR_CHAIN{1'b0}};
                int_kick        <= 1'b0;
            end
            default : begin
                deq_stm         <= DEQ_IDLE;
                deq_kick        <= {CH_PAR_CHAIN{1'b0}};
                int_kick        <= 1'b0;
            end
        endcase
    end
end



// dmaw stm counter

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        dmaw_cnt      [4:0] <= {5{1'b0}};
        dmaw_burst_cnt[4:0] <= {5{1'b0}};
    end
    else if ( dmaw_stm == DMA_IDLE ) begin
        dmaw_cnt      [4:0] <= {5{1'b0}};
        dmaw_burst_cnt[4:0] <= {5{1'b0}};
    end
    else if ( dwr_axis_tready ) begin
        if ( dmaw_stm == HD_GEN ) begin
            dmaw_cnt      [4:0] <= {5{1'b0}};
            dmaw_burst_cnt[4:0] <= dmaw_burst_cnt[4:0];
        end
        else if ( dmaw_stm == DMA_WT ) begin
            dmaw_cnt      [4:0] <= dmaw_cnt      [4:0] +1;
            dmaw_burst_cnt[4:0] <= dmaw_burst_cnt[4:0] +1;
        end
        else begin
            dmaw_cnt      [4:0] <= dmaw_cnt      [4:0];
            dmaw_burst_cnt[4:0] <= dmaw_burst_cnt[4:0];
        end
    end
    else begin
        dmaw_cnt      [4:0] <= dmaw_cnt      [4:0];
        dmaw_burst_cnt[4:0] <= dmaw_burst_cnt[4:0];
    end
end




assign deq_stm_kick = pkt_last_valid_1t & dwr_axis_tready & ( curr_mode == 3'b000 );
assign ram_rd_ready =   (used_addr[11:0] > pkt_cycle[4:0])
                      | (eop_cnt  [11:0] > 0)
                      ;

// eop counter
//

always_comb begin
    c2d_pkt_drop = 1'b0;

    for (int i=0; i<CH_PAR_CHAIN; i++) begin
        if ( c2d_cid_1t[2:0] == i ) begin
            c2d_pkt_drop = c2d_pkt_drop_flag[i];
        end
    end

end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        wt_enb_sop        <= 1'b0;
        wt_enb_eop        <= 1'b0;
        pkt_eop_valid     <= 1'b0;
        pkt_last_valid    <= 1'b0;
    end
    else begin
        wt_enb_sop        <= c2d_axis_tready && c2d_axis_tvalid_1t && c2d_axis_tuser_1t[7] && ~c2d_pkt_drop;
        wt_enb_eop        <= c2d_axis_tready && c2d_axis_tvalid_1t && c2d_axis_tuser_1t[6] && ~c2d_pkt_drop;
        pkt_eop_valid     <= rd_data2_eop  & rd_enb ;
        pkt_last_valid    <= rd_data2_last & rd_enb ;
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        pkt_eop_valid_1t  <= 1'b0;
    end
    else if ( ~pkt_eop_valid_1t ) begin
        pkt_eop_valid_1t  <= pkt_eop_valid ;
    end
    else if ( pkt_eop_valid_1t && ~dwr_axis_tready ) begin
        pkt_eop_valid_1t  <= pkt_eop_valid_1t ;
    end
    else begin
        pkt_eop_valid_1t  <= 1'b0 ;
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        pkt_last_valid_1t <= 1'b0;
    end
    else if ( ~pkt_last_valid_1t ) begin
        pkt_last_valid_1t <= pkt_last_valid;
    end
    else if ( pkt_last_valid_1t && ~dwr_axis_tready ) begin
        pkt_last_valid_1t <= pkt_last_valid_1t;
    end
    else begin
        pkt_last_valid_1t <= 1'b0;
    end
end



always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        eop_cnt[11:0] <= {12{1'b0}};
    end
    // (in +1) / (out -1)
    else if (  wt_enb_eop &&  pkt_eop_valid ) begin
        eop_cnt[11:0] <= eop_cnt[11:0];
    end
    // (in +0) / (out -1)
    else if ( ~wt_enb_eop &&  pkt_eop_valid ) begin
        eop_cnt[11:0] <= (eop_cnt[11:0] == 0)? eop_cnt[11:0] : eop_cnt[11:0] -1;
    end
    // (in +1) / (out -0)
    else if (  wt_enb_eop && ~pkt_eop_valid ) begin
        eop_cnt[11:0] <= (eop_cnt[11])? eop_cnt[11:0] : eop_cnt[11:0] +1;
    end
    else begin
        eop_cnt[11:0] <= eop_cnt[11:0];
    end
end



// dma buff

    dma_tx_fifo DMA_TX_BUF
        (
         .user_clk    (user_clk      )
        ,.reset_n     (reset_n       )
        ,.fifo_we     (wt_enb        )
        ,.fifo_wd1    (in_buf_data1  )
        ,.fifo_wd2    (in_buf_data2  )
        ,.fifo_re     (rd_enb        )

//        ,.fifo_rd1    (fifo_rdt1     )
//        ,.fifo_rd2    (fifo_rdt2     )
        ,.fifo_rd1    (rd_data1      )
        ,.fifo_rd2    (rd_data2      )
        ,.fifo_wadrs  (wt_addr[10:0] )
        ,.fifo_radrs  (rd_addr[10:0] )
        ,.fifo_wp     (fifo_wp[10:0] )
        ,.fifo_rp     (fifo_rp[10:0] )
        );


//// comp (dequeue/d2d) buff
//
//    DMA_BUF_128K COMP_BUF
//        (
//        .clka(user_clk),
//        .ena(comp_wt_enb),
//        .wea(comp_wt_enb),
//        .addra(comp_wt_addr[10:0]),
//        .dina(comp_wt_data_1t),
//        
//        .clkb(user_clk),
//        .enb(comp_rd_enb),
//        .addrb(comp_rd_addr[10:0]),
//        .doutb(comp_rd_data)
//        
//        );
//

//always_ff @(posedge user_clk or negedge reset_n) begin
//    if (~reset_n) begin
//        rd_data1[511:0] <= {512{1'b0}};
//        rd_data2[511:0] <= {512{1'b0}};
//    end
//    else begin
//        rd_data1[511:0] <= fifo_rdt1[511:0];
//        rd_data2[511:0] <= fifo_rdt2[511:0];
//    end
//end


assign rd_data2_sop        = rd_data2[2];
assign rd_data2_eop        = rd_data2[1];
assign rd_data2_last       = rd_data2[0];
assign rd_data2_cid[2:0]   = rd_data2[ 6: 4];
assign rd_data2_burst[4:0] = rd_data2[16:12];
assign rd_data2_frm_hd     = rd_data2[17];




// write data

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        c2d_axis_tvalid_1t <=                  1'b0;
        c2d_axis_tdata_1t  <= {            512{1'b0}};
        c2d_axis_tlast_1t  <=                  1'b0  ;
        c2d_axis_tuser_1t  <= {C2D_TUSER_WIDTH{1'b0}};
    end
    else if ( c2d_axis_tready ) begin
        c2d_axis_tvalid_1t <= c2d_axis_tvalid;
        c2d_axis_tdata_1t  <= c2d_axis_tdata;
        c2d_axis_tlast_1t  <= c2d_axis_tlast;
        c2d_axis_tuser_1t  <= c2d_axis_tuser;
    end
    else begin
        c2d_axis_tvalid_1t <= c2d_axis_tvalid_1t;
        c2d_axis_tdata_1t  <= c2d_axis_tdata_1t;
        c2d_axis_tlast_1t  <= c2d_axis_tlast_1t;
        c2d_axis_tuser_1t  <= c2d_axis_tuser_1t;
    end
end


assign c2d_frame_header = (c2d_axis_tdata_1t[31:0] == 32'he0ff10ad)? 1'b1: 1'b0;

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        in_buf_data1[511:0] <= {512{1'b0}};
        in_buf_data2[511:0] <= {512{1'b0}};
    end
    else if ( c2d_axis_tuser_1t[7] ) begin
        in_buf_data1[511:0] <= c2d_axis_tdata_1t[511:0];
        in_buf_data2[511:0] <= { {494{1'b0}}
                               , c2d_frame_header     // [17]    : frame header
                               , c2d_axis_tuser_1t[ 4:0] // [16:12] : burst[4:0]
                               , c2d_axis_tuser_1t[15:8] // [11: 4] : cid[7:0]
                               , {1'b0}               // [3]     : reserved
                               , c2d_axis_tuser_1t[7]    // [2]     : SOP
                               , c2d_axis_tuser_1t[6]    // [1]     : EOP
                               , c2d_axis_tlast_1t       // [0]
                               };
    end
    else begin
        in_buf_data1[511:0] <= c2d_axis_tdata_1t[511:0];
        in_buf_data2[511:0] <= { {494{1'b0}}
                               , c2d_frame_header     // [17]    : frame header
                               , in_buf_data2[16:12]  // [16:12] : burst[4:0]
                               , in_buf_data2[11: 4]  // [11: 4] : cid[7:0]
                               , {1'b0}               // [3]     : reserved
                               , c2d_axis_tuser_1t[7]    // [2]     : SOP
                               , c2d_axis_tuser_1t[6]    // [1]     : EOP
                               , c2d_axis_tlast_1t       // [0]
                               };
    end
end



// write pointer

//always_ff @(posedge user_clk or negedge reset_n) begin
//    if (~reset_n) begin
//        wt_enb            <= 1'b0;
//    end
//    else begin
//        wt_enb            <= c2d_axis_tready && c2d_axis_tvalid_1t;
//    end
//end


// read pointer

assign rd_enb =   dwr_axis_tready
                & ( dmaw_stm != DMA_IDLE )
                & ( dmaw_stm != DSC_WAIT )
                & rd_enb_flag
                & (used_addr[11:0] != 0 );

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        rd_enb_flag <= 1'b0;
    end
    else if ( rd_enb_flag && rd_data2_eop && rd_enb && dwr_axis_tready ) begin
        rd_enb_flag <= 1'b0;
    end
    else if ( dwr_axis_tready ) begin
        if ( rd_enb_flag && (pkt_cycle[4:0] == re_cnt[4:0]) ) begin
            rd_enb_flag <= 1'b0;
        end
        else if ( rd_enb_flag && ((burst_length[4:0] -1) == re_cnt[4:0]) && ~( re_cnt[4:0] == 0 ) ) begin
            rd_enb_flag <= 1'b0;
        end
        else if (  dscq_vld_or
                  && ( (used_addr[11:0] > pkt_cycle[4:0]) | (eop_cnt[11:0] > 0) )
                  && ( ~(rd_data2_eop && rd_enb) && (~pkt_eop_flag) )
                 ) begin
                rd_enb_flag <= 1'b1;
        end
        else begin
            rd_enb_flag <= 1'b0 ;
        end
    end
    else begin
        rd_enb_flag <= rd_enb_flag;
    end
end



always_comb begin
    case (pci_size[2:0])
        3'b000 : begin  // 128 byte  2cycle
            def_pkt_cycle[4:0]   =  1;
            def_pkt_length[31:0] = 32'h0080;
        end
        3'b001 : begin // 256 byte  4cycle
            def_pkt_cycle[4:0]   =  3;
            def_pkt_length[31:0] = 32'h0100;
        end
        3'b010 : begin // 512 byte  8cycle
            def_pkt_cycle[4:0]   =  7;
            def_pkt_length[31:0] = 32'h0200;
        end
        3'b011 : begin // 1K  byte 16cycle
            def_pkt_cycle[4:0]   = 15;
            def_pkt_length[31:0] = 32'h0400;
        end
        default: begin // 128 byte 16cycle
            def_pkt_cycle[4:0]   =  1;
            def_pkt_length[31:0] = 32'h0080;
        end
    endcase
end

assign pkt_cycle  = def_pkt_cycle;
assign pkt_length = def_pkt_length;


assign rd_burst[4:0] = (rd_data2_sop && rd_data2_eop && rd_enb)?  rd_data2_burst[4:0] : rd_burst_count[4:0];


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        rd_burst_count[4:0] <= {5{1'b0}};
    end
    else if ( rd_data2_sop && rd_enb )begin
        rd_burst_count[4:0] <= rd_data2_burst[4:0];
    end
    else if ( ( dwr_axis_tready ) && (dmaw_stm == DMA_WT)
           &&  ( rd_burst[4:0] <= (dmaw_burst_cnt[4:0]+1) )
           ) begin
        rd_burst_count[4:0] <= {5{1'b0}};
    end
    else begin
        rd_burst_count[4:0] <= rd_burst_count[4:0];
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        re_cnt[4:0] <= {5{1'b0}};
    end
    else if ( dmaw_stm == DMA_IDLE ) begin
        re_cnt[4:0] <= {5{1'b0}};
    end
    else if ( rd_enb && rd_data2_eop && dwr_axis_tready ) begin
        re_cnt[4:0] <= {5{1'b0}};
    end
    else if ( ~dwr_axis_tready ) begin
        re_cnt[4:0] <= re_cnt[4:0];
    end
    else if ( rd_enb ) begin
        if (    ( re_cnt[4:0] < pkt_cycle[4:0] ) 
             && ( re_cnt[4:0] < (burst_length[4:0]-1) )
            ) begin
            re_cnt[4:0] <= re_cnt[4:0] +1;
        end
        else begin
            re_cnt[4:0] <= {5{1'b0}};
        end
    end
    else begin
        re_cnt[4:0] <= re_cnt[4:0];
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        rd_cnt [4:0] <= {5{1'b0}};
    end
    else if ( ~dwr_axis_tready ) begin
        rd_cnt[4:0] <= rd_cnt[4:0];
    end
    else if ( (dmaw_stm == DSC_RD) && (~dscq_vld_mch) ) begin
        rd_cnt [4:0] <= {5{1'b0}};
    end
    else if ( rd_enb && rd_data2_eop ) begin
        rd_cnt [4:0] <= {5{1'b0}};
    end
    else if (rd_enb)begin
        if ( rd_cnt[4:0] <= rd_burst[4:0] ) begin
            rd_cnt[4:0] <= rd_cnt[4:0] +1;
        end
        else begin
            rd_cnt[4:0] <= {5{1'b0}};
        end
    end
    
    else begin
        rd_cnt[4:0] <= rd_cnt[4:0];
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        used_addr[11:0] <= 0;
    end
    else begin
        if ( wt_enb &&  ( rd_enb && dwr_axis_tready ) )begin
            used_addr[11:0] <= used_addr[11:0];
        end
        else if (~wt_enb &&  ( rd_enb && dwr_axis_tready ) )begin
            used_addr[11:0] <= used_addr[11:0] -1;
        end
        else if ( wt_enb && ~( rd_enb && dwr_axis_tready ) )begin
            used_addr[11:0] <= used_addr[11:0] +1;
        end
        else begin
            used_addr[11:0] <= used_addr[11:0];
        end
    end
end



assign free_addr[11:0] = 12'h800 - used_addr[11:0];


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        c2d_axis_tready <= 1'b1;
    end
    else if ( free_addr[11:0] < 16 ) begin
        c2d_axis_tready <= 1'b0;
    end
    else if ( free_addr[11:0] > 64 ) begin
        c2d_axis_tready <= 1'b1;
    end
    else begin
        c2d_axis_tready <= c2d_axis_tready ;
    end
end


// assign dsc_read = (dmaw_stm == DMA_IDLE) && ~dmaw_buff_empty;

assign dmaw_buff_full  = used_addr[11];
assign dmaw_buff_empty = used_addr[11:0] == 12'b0;


// read buff


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        rd_data1_1t[511:0] <= {512{1'b0}};
        rd_data2_1t[ 31:0] <= { 32{1'b0}};
    end
    else if (~dwr_axis_tready
              | (dmaw_stm == DSC_WAIT)
             ) begin
        rd_data1_1t[511:0] <= rd_data1_1t[511:0];
        rd_data2_1t[ 31:0] <= rd_data2_1t[ 31:0];
    end
    else begin
        rd_data1_1t[511:0] <= rd_data1[511:0];
        rd_data2_1t[ 31:0] <= rd_data2[ 31:0];
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        rd_data1_2t[511:0] <= {512{1'b0}};
        rd_data2_2t[ 31:0] <= { 32{1'b0}};
    end
    else if (~dwr_axis_tready
              | (dmaw_stm == DSC_WAIT)
             ) begin
        rd_data1_2t[511:0] <= rd_data1_2t[511:0];
        rd_data2_2t[ 31:0] <= rd_data2_2t[ 31:0];
    end
    else begin
        rd_data1_2t[511:0] <= rd_data1_1t[511:0];
        rd_data2_2t[ 31:0] <= rd_data2_1t[ 31:0];
    end
end



always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        rd_buff    [511:  0] <= {512{1'b0}};
        rd_buff2   [ 31:  0] <= { 32{1'b0}};
    end
    else if (~dwr_axis_tready
              | (dmaw_stm == DSC_WAIT)
             ) begin
        rd_buff    [511:  0] <= rd_buff [511:0];
        rd_buff2   [ 31:  0] <= rd_buff2[ 31:0];
    end
    else if (dwr_axis_tready && (dmaw_stm == HD_GEN) ) begin
        rd_buff    [127:  0] <= (curr_mode == 3'b000)? wt_header[127:0]: wt_header2[127:0];
        rd_buff    [511:128] <= {384{1'b0}};
        rd_buff2   [ 31:  0] <= rd_data2_2t[ 31:  0];
    end
    else begin
        rd_buff    [511:  0] <= rd_data1_2t[511:  0];
        rd_buff2   [ 31:  0] <= rd_data2_2t[ 31:  0];
    end
end


// dst addr/dst length

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        cid_hld[2:0] <= {3{1'b0}};
    end
    else if ( rd_data2_sop && rd_enb ) begin
        cid_hld[2:0] <= rd_data2_cid[2:0];
    end
    else begin
        cid_hld[2:0] <= cid_hld[2:0];
    end
end


// for i=0~15 //

for (genvar i=0; i<CH_PAR_CHAIN; i++) begin

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
                                    dst_addr_add[i][63:32] <=     1'b0   ;
            {dst_addr_add_carry[i], dst_addr_add[i][31:0]} <= {33{1'b0}} ;
        end
        else if (ch_dscq_clr_1t[i]) begin
                                    dst_addr_add[i][63:32] <=     1'b0   ;
            {dst_addr_add_carry[i], dst_addr_add[i][31:0]} <= {33{1'b0}} ;
        end
        else if ( dwr_axis_tready ) begin
            if ( (cid_hld[2:0] == i) && ( pkt_last_valid_1t ) ) begin
                                        dst_addr_add[i][63:32] <=     1'b0   ;
                {dst_addr_add_carry[i], dst_addr_add[i][31:0]} <= {32{1'b0}} ;
            end
            else if ( (cid_hld[2:0] == i) && ( dmaw_stm == HD_GEN ) ) begin
                if ( burst_length[4:0] < (pkt_cycle[4:0]+1) ) begin
                                        dst_addr_add[i][63:32] <= dst_addr_add_1t[i][63:32];
                {dst_addr_add_carry[i], dst_addr_add[i][31:0]} <= dst_addr_add   [i][31:0] + ( burst_length[4:0] << 6);
                end
                else begin
                                            dst_addr_add[i][63:32] <= dst_addr_add_1t[i][63:32];
                    {dst_addr_add_carry[i], dst_addr_add[i][31:0]} <= dst_addr_add   [i][31:0] + pkt_length[31:0];
                end
            end
            else begin
                                        dst_addr_add[i][63:32] <=                         dst_addr_add[i][63:32];
                {dst_addr_add_carry[i], dst_addr_add[i][31:0]} <= {dst_addr_add_carry[i], dst_addr_add[i][31:0]};
            end
        end
        else begin
                                    dst_addr_add[i][63:32] <=                         dst_addr_add[i][63:32];
            {dst_addr_add_carry[i], dst_addr_add[i][31:0]} <= {dst_addr_add_carry[i], dst_addr_add[i][31:0]};
        end
    end

end

for (genvar i=0; i<CH_PAR_CHAIN; i++) begin

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            dst_addr_add_1t[i][63:0]  <= {64{1'b0}} ;
        end
        else if (ch_dscq_clr_1t[i]) begin
            dst_addr_add_1t[i][63:0]  <= {64{1'b0}} ;
        end
        else if ( dwr_axis_tready ) begin
            dst_addr_add_1t[i][63:32]  <= dst_addr_add[i][63:32] +  dst_addr_add_carry[i];
            dst_addr_add_1t[i][31: 0]  <= dst_addr_add[i][31:0] ;
        end
        else begin
            dst_addr_add_1t[i][63:0]  <= dst_addr_add_1t[i][63:0] ;
        end
    end

end



always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        burst_length [4:0] <= { 5{1'b0}};
    end
    else if ( rd_data2_sop && rd_enb ) begin
        burst_length [4:0] <= rd_data2_burst[4:0];
    end
    else if ( dwr_axis_tready ) begin
        if ( pkt_last_valid_1t ) begin
            burst_length [4:0] <= { 5{1'b0}};
        end
        else if ( dmaw_stm == DMA_IDLE ) begin
            burst_length [4:0] <= { 5{1'b0}};
        end
        else begin
            if (pkt_cycle[4:0] == re_cnt[4:0] ) begin
                burst_length [4:0] <=    burst_length[4:0] - (re_cnt[4:0]+1);
            end 
            else begin
                burst_length [4:0] <= burst_length [4:0];
            end
        end
    end
    else begin
        burst_length [4:0] <= burst_length [4:0];
    end
end

//always_ff @(posedge user_clk or negedge reset_n) begin
//    if (~reset_n) begin
//        burst_length_1t[4:0] <= { 5{1'b0}};
//    end
//    else begin
//        burst_length_1t[4:0] <= burst_length[4:0];
//    end
//end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        dst_length  [31:0] <= {32{1'b0}};
    end
    else if ( dwr_axis_tready ) begin
        if ( pkt_last_valid_1t ) begin
            dst_length  [31:0] <= {32{1'b0}};
        end
        else if ( rd_data2_sop && rd_enb ) begin
            if ( rd_data2_burst[4:0] > (pkt_cycle[4:0]+1) ) begin
                dst_length  [31:0] <= pkt_length[31:0];
            end
            else begin
                dst_length  [31:0] <= (rd_data2_burst[4:0] << 6);
            end
        end
        else if ( burst_length[4:0] == 0 ) begin
            dst_length  [31:0] <= pkt_length[31:0];
        end
        else if ( pkt_cycle[4:0] >= burst_length[4:0] ) begin
            dst_length  [31:0] <= (burst_length[4:0] << 6);
        end
        else if (pkt_cycle[4:0] == re_cnt[4:0] ) begin
            if ( (burst_length[4:0] - (pkt_cycle[4:0] +1) ) > (pkt_cycle[4:0]+1) ) begin
                dst_length  [31:0] <= pkt_length[31:0];
            end
            else begin
                dst_length  [31:0] <= ( (burst_length[4:0] - (pkt_cycle[4:0]+1)) << 6);
            end
        end 
        else begin
            dst_length  [31:0] <= dst_length  [31:0];
        end
    end
    else begin
        dst_length  [31:0] <= dst_length  [31:0];
    end
end



always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        dma_write_end_1t <= 1'b0;
    end
    else if (dwr_axis_tready) begin
        dma_write_end_1t <= dmaw_end   ;
    end
    else begin
        dma_write_end_1t <= dma_write_end_1t;
    end
end


// valid

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        rd_enb_1t           <= 1'b0;
        rd_enb_2t           <= 1'b0;
        rd_enb_3t           <= 1'b0;
        dmaw_stm_hd_gen_2t  <= 1'b0;
        dmaw_stm_hd_gen_3t  <= 1'b0;
    end
    else begin
        rd_enb_1t           <= rd_enb   ;
        rd_enb_2t           <= rd_enb_1t;
        rd_enb_3t           <= rd_enb_2t;
        dmaw_stm_hd_gen_2t  <= dmaw_stm_hd_gen_1t;
        dmaw_stm_hd_gen_3t  <= dmaw_stm_hd_gen_2t;
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        dmaw_stm_hd_gen_1t  <= 1'b0;
    end
    else if (dwr_axis_tready) begin
        if ( dmaw_stm == HD_GEN ) begin
            dmaw_stm_hd_gen_1t  <= 1'b1;
        end
        else begin
            dmaw_stm_hd_gen_1t  <= 1'b0;
        end
    end
    else begin
        dmaw_stm_hd_gen_1t  <= dmaw_stm_hd_gen_1t;
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        dmaw_valid  <= 1'b0;
    end
    else if (dwr_axis_tready) begin
        if ( (dmaw_stm == HD_GEN) | (dmaw_stm == DMA_WT) ) begin
            dmaw_valid <= ~(|dwr_valid_drain);
//            dmaw_valid <= 1'b1;
        end
        else begin
            dmaw_valid <= 1'b0;
        end
    end
    else begin
        dmaw_valid <= dmaw_valid;
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        dscq_rls_dt[127:0] <= {128{1'b0}};
    end
    else if ( pkt_last_valid ) begin
        dscq_rls_dt[127:0] <= dsc_sel_data[127:0];
    end
    else begin
        dscq_rls_dt[127:0] <= dscq_rls_dt[127:0];
    end
end


assign rq_dmaw_dwr_axis_tvalid       = dmaw_valid & ~deq_full & ~dwr_valid_drain_or ;
assign rq_dmaw_dwr_axis_tdata[511:0] = rd_buff[511:0] ;
assign rq_dmaw_dwr_axis_tlast        = dmaw_end;

//assign dscq_rls_dt[127:0] = dsc_sel_data[127:0];

// tag

assign rd_tag[4:0] = 5'b00000; // CH No.

// packet last flag


// descriptor release

always_comb begin
    case ( rd_data2_cid[2:0] )
        3'h0    : cid_dec[7:0] = 8'h01;
        3'h1    : cid_dec[7:0] = 8'h02;
        3'h2    : cid_dec[7:0] = 8'h04;
        3'h3    : cid_dec[7:0] = 8'h08;
        3'h4    : cid_dec[7:0] = 8'h10;
        3'h5    : cid_dec[7:0] = 8'h20;
        3'h6    : cid_dec[7:0] = 8'h40;
        3'h7    : cid_dec[7:0] = 8'h80;
        default : cid_dec[7:0] = 8'h00;
    endcase
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        cid_sel[CH_PAR_CHAIN-1:0] <= {CH_PAR_CHAIN{1'b0}};
    end
    else if ( rd_enb && rd_data2_sop ) begin
        cid_sel[CH_PAR_CHAIN-1:0] <= cid_dec[CH_PAR_CHAIN-1:0];
    end
    else begin
        cid_sel[CH_PAR_CHAIN-1:0] <= cid_sel[CH_PAR_CHAIN-1:0];
    end
end



always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        dscq_rls <= {CH_PAR_CHAIN{1'b0}};
    end
//    else if ( pkt_last_valid_1t && dwr_axis_tready ) begin
    else if ( pkt_last_valid ) begin
        dscq_rls <= cid_sel[CH_PAR_CHAIN-1:0] & ~dscq_empty_timeout[CH_PAR_CHAIN-1:0];
    end
    else begin
        dscq_rls <= {CH_PAR_CHAIN{1'b0}};
    end
end



always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        pkt_eop_flag <= 1'b0;
    end
    else if ( pkt_eop_flag && ( (rd_burst[4:0]-1) == dmaw_burst_cnt[4:0] ) && (dmaw_stm == DMA_WT) ) begin
        pkt_eop_flag <= 1'b0;
    end
    else if (rd_data2_eop && rd_enb) begin
        pkt_eop_flag <= 1'b1;
    end
    else begin
        pkt_eop_flag <= pkt_eop_flag;
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        pkt_last_flag <= 1'b0;
    end
    else if ( pkt_last_flag && ( (rd_burst[4:0]-1) == rd_cnt[4:0] ) && (dmaw_stm == DMA_WT) ) begin
        pkt_last_flag <= 1'b0;
    end
    else if (rd_data2_last && rd_enb) begin
        pkt_last_flag <= 1'b1;
    end
    else begin
        pkt_last_flag <= pkt_last_flag;
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        deq_wt_enb_flag <= 1'b0;
        d2d_wt_enb_flag <= 1'b0;
        int_enb_flag    <= 1'b0;
    end
    else if ( deq_stm_kick ) begin
        deq_wt_enb_flag <= 1'b1 ; // enqc_cmd[ 8];
        d2d_wt_enb_flag <= 1'b0 ; // enqc_cmd[11];
        int_enb_flag    <= 1'b0 ; // enqc_cmd[10];
    end
    else begin
        deq_wt_enb_flag <= deq_wt_enb_flag;
        d2d_wt_enb_flag <= d2d_wt_enb_flag;
        int_enb_flag    <= int_enb_flag   ;
    end
end


// frame length

for (genvar i=0; i<CH_PAR_CHAIN; i++) begin
    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            frame_len[i][31:0] <= {32{1'b0}};
        end
        else if (ch_dscq_clr_1t[i]) begin
            frame_len[i][31:0] <= {32{1'b0}};
        end
        else if ( rd_data2_frm_hd && rd_enb ) begin
            if ( rd_data2_cid[2:0] == i ) begin
                frame_len[i][31:0] <= rd_data1[63:32] + 48 ; // frame payload length + frame header
            end
            else begin
                frame_len[i][31:0] <= frame_len[i][31:0];
            end
        end
        else begin
            frame_len[i][31:0] <= frame_len[i][31:0];
        end
    end
end



always_comb begin
    deq_frm_len[31:0] = {32{1'b0}};

    for (int i=0; i<CH_PAR_CHAIN; i++) begin
        if ( rd_data2_cid[2:0] == i ) begin
            deq_frm_len[31:0] = frame_len[i][31:0];
        end
    end

end



//// debug ////

// PA

// cifu -> dma_tx
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        c2d_ready_1t <=    1'b0;
        c2d_valid_1t <=    1'b0;
        c2d_sop_1t   <=    1'b0;
        c2d_eop_1t   <=    1'b0;
        c2d_burst_1t <= {5{1'b0}};
        c2d_last_1t  <=    1'b0;
    end
    else begin
        c2d_ready_1t <= c2d_axis_tready;
        c2d_valid_1t <= c2d_axis_tvalid;
        c2d_sop_1t   <= c2d_axis_tuser[ 7];
        c2d_eop_1t   <= c2d_axis_tuser[ 6];
        c2d_burst_1t <= c2d_axis_tuser[ 4:0];
        c2d_last_1t  <= c2d_axis_tlast;
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        c2d_cid_1t   <= {3{1'b0}};
    end
    else if ( c2d_axis_tready && c2d_axis_tvalid && c2d_axis_tuser[7] ) begin
        c2d_cid_1t   <= c2d_axis_tuser[10:8];
    end
    else begin
        c2d_cid_1t   <= c2d_cid_1t;
    end
end

always_comb begin
    case ( c2d_cid_1t[2:0] )
        3'h0    : c2d_cid_dec[7:0] = 8'h01;
        3'h1    : c2d_cid_dec[7:0] = 8'h02;
        3'h2    : c2d_cid_dec[7:0] = 8'h04;
        3'h3    : c2d_cid_dec[7:0] = 8'h08;
        3'h4    : c2d_cid_dec[7:0] = 8'h10;
        3'h5    : c2d_cid_dec[7:0] = 8'h20;
        3'h6    : c2d_cid_dec[7:0] = 8'h40;
        3'h7    : c2d_cid_dec[7:0] = 8'h80;
        default : c2d_cid_dec[7:0] = 8'h00;
    endcase
end


// dma_tx -> pci_trx
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        d2p_ready_1t <=    1'b0;
        d2p_valid_1t <=    1'b0;
        d2p_sop_1t   <=    1'b0;
        d2p_eop_1t   <=    1'b0;
        d2p_burst_1t <= {5{1'b0}};
        d2p_last_1t  <=    1'b0;
    end
    else begin
        d2p_ready_1t <= dwr_axis_tready;
        d2p_valid_1t <= dmaw_valid;
        d2p_sop_1t   <= rd_buff2[ 2];
        d2p_eop_1t   <= rd_buff2[ 1];
        d2p_burst_1t <= rd_buff2[16:12];
        d2p_last_1t  <= rq_dmaw_dwr_axis_tlast;
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        d2p_cid_1t   <= {3{1'b0}};
    end
    else if ( dwr_axis_tready && dmaw_valid && rd_data2_2t[2] ) begin
        d2p_cid_1t   <= rd_data2_2t[6:4];
    end
    else if (dmaw_stm == DSC_WAIT) begin
        d2p_cid_1t   <= rd_data2_2t[6:4];
    end
    else begin
        d2p_cid_1t   <= d2p_cid_1t;
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        d2p_cid_2t   <= {3{1'b0}};
    end
    else begin
        d2p_cid_2t   <= d2p_cid_1t;
    end
end

always_comb begin
    case ( d2p_cid_2t[2:0] )
        3'h0    : d2p_cid_dec[7:0] = 8'h01;
        3'h1    : d2p_cid_dec[7:0] = 8'h02;
        3'h2    : d2p_cid_dec[7:0] = 8'h04;
        3'h3    : d2p_cid_dec[7:0] = 8'h08;
        3'h4    : d2p_cid_dec[7:0] = 8'h10;
        3'h5    : d2p_cid_dec[7:0] = 8'h20;
        3'h6    : d2p_cid_dec[7:0] = 8'h40;
        3'h7    : d2p_cid_dec[7:0] = 8'h80;
        default : d2p_cid_dec[7:0] = 8'h00;
    endcase
end


assign c2d_pkt_enb   [CH_PAR_CHAIN-1:0] = {CH_PAR_CHAIN{                       (c2d_ready_1t & c2d_valid_1t) }} & c2d_cid_dec[CH_PAR_CHAIN-1:0];
assign d2p_pkt_enb   [CH_PAR_CHAIN-1:0] = {CH_PAR_CHAIN{ (~dmaw_stm_hd_gen_2t & d2p_ready_1t & d2p_valid_1t) }} & d2p_cid_dec[CH_PAR_CHAIN-1:0];
assign d2p_pkt_hd_enb[CH_PAR_CHAIN-1:0] = {CH_PAR_CHAIN{ ( dmaw_stm_hd_gen_2t & d2p_ready_1t & d2p_valid_1t) }} & d2p_cid_dec[CH_PAR_CHAIN-1:0];

assign dsc_wait_cnt_enb[CH_NUM-1:0] = {CH_NUM{ dsc_wait_cnt_1t }} & d2p_cid_dec[CH_PAR_CHAIN-1:0];

assign stm_dsc_wait = (dmaw_stm == DSC_WAIT);

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        stm_dsc_wait_1t <= 1'b0;
        dsc_wait_cnt    <= 1'b0;
        dsc_wait_cnt_1t <= 1'b0;
    end
    else begin
        stm_dsc_wait_1t <=  stm_dsc_wait;
        dsc_wait_cnt    <=  stm_dsc_wait & ~stm_dsc_wait_1t;
        dsc_wait_cnt_1t <=  dsc_wait_cnt;
    end
end

assign used_addr_cnt[15:0] = {4'h0, used_addr[11:0]};





//////// D2D ////////

assign wt_header2[  1:  0] = 2'b00;           //
assign wt_header2[  5:  2] = 4'h0;            // d2d_address[5:2]
//     wt_header2[ 63:  2]                    // d2d_address
assign wt_header2[ 74: 64] = dst_length[12:2]; // length(DW)
assign wt_header2[ 78: 75] = 4'b0001;         // mem wt
assign wt_header2    [ 79] = 1'b0;            //
assign wt_header2[ 87: 80] = 8'h00;           //
assign wt_header2[ 95: 88] = 8'h00;           //
assign wt_header2[103: 96] = 8'h00;           // wt_tag[7:0]
assign wt_header2[111:104] = 8'h00;           //
assign wt_header2[119:112] = 8'h00;           //
assign wt_header2    [120] = 1'b0;            //
assign wt_header2[123:121] = 3'b000;          //
assign wt_header2[126:124] = 3'b000;          //
assign wt_header2    [127] = 1'b0;            //

// D2D interval

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        d2d_interval_cnt[7:0] <= {8{1'b0}};
    end
    else begin
        case ( d2d_interval[3:0] )
            4'b0000 : d2d_interval_cnt[31:0] <= 32'h00000400; //   1k
            4'b0001 : d2d_interval_cnt[31:0] <= 32'h00000800; //   2k
            4'b0010 : d2d_interval_cnt[31:0] <= 32'h00001000; //   4k
            4'b0011 : d2d_interval_cnt[31:0] <= 32'h00002000; //   8k
            4'b0100 : d2d_interval_cnt[31:0] <= 32'h00004000; //  16k
            4'b0101 : d2d_interval_cnt[31:0] <= 32'h00008000; //  32k
            4'b0110 : d2d_interval_cnt[31:0] <= 32'h00010000; //  64k
            4'b0111 : d2d_interval_cnt[31:0] <= 32'h00020000; // 128k
            default : d2d_interval_cnt[31:0] <= 32'hffffffff; // tlast
        endcase
    end
end


// frame last

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        rd_data2_frm_last <= 1'b0;
    end
    else if ( rd_data2_last && rd_enb ) begin
        rd_data2_frm_last <= 1'b1;
    end
    else if (~dwr_axis_tready ) begin
        rd_data2_frm_last <= rd_data2_frm_last;
    end
    else begin
        rd_data2_frm_last <= 1'b0;
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        rd_data2_frm_last_1t <= 1'b0;
        rd_data2_frm_last_2t <= 1'b0;
    end
    else if ( dwr_axis_tready ) begin
        rd_data2_frm_last_1t <= rd_data2_frm_last;
        rd_data2_frm_last_2t <= rd_data2_frm_last_1t;
    end
    else begin
        rd_data2_frm_last_1t <= rd_data2_frm_last_1t;
        rd_data2_frm_last_2t <= rd_data2_frm_last_2t;
    end
end


// D2D address

for (genvar i=0; i<CH_PAR_CHAIN; i++) begin

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            d2d_add_mask[i][31:0] <= 32'hfffffff;
            srbuf_size_err[i]     <= 1'b0;
        end
        else begin
            if ( ch_mode_1_1t[i] ) begin
                case ( srbuf_size_1t[i] )
                    32'h00001000 : begin  // 4k
                        d2d_add_mask[i][31:0] <= 32'h00000fff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h00002000 : begin  // 8k
                        d2d_add_mask[i][31:0] <= 32'h00001fff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h00004000 : begin  // 16k
                        d2d_add_mask[i][31:0] <= 32'h00003fff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h00008000 : begin  // 32k
                        d2d_add_mask[i][31:0] <= 32'h00007fff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h00010000 : begin  // 64k
                        d2d_add_mask[i][31:0] <= 32'h0000ffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h00020000 : begin  // 128k
                        d2d_add_mask[i][31:0] <= 32'h0001ffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h00040000 : begin  // 256k
                        d2d_add_mask[i][31:0] <= 32'h0003ffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h00080000 : begin  // 512k
                        d2d_add_mask[i][31:0] <= 32'h0007ffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h00100000 : begin  // 1M
                        d2d_add_mask[i][31:0] <= 32'h000fffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h00200000 : begin  // 2M
                        d2d_add_mask[i][31:0] <= 32'h001fffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h00400000 : begin  // 4M
                        d2d_add_mask[i][31:0] <= 32'h003fffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h00800000 : begin  // 8M
                        d2d_add_mask[i][31:0] <= 32'h007fffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h01000000 : begin  // 16M
                        d2d_add_mask[i][31:0] <= 32'h00ffffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h02000000 : begin  // 32M
                        d2d_add_mask[i][31:0] <= 32'h01ffffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h04000000 : begin  // 64M
                        d2d_add_mask[i][31:0] <= 32'h03ffffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h08000000 : begin  // 128M
                        d2d_add_mask[i][31:0] <= 32'h07ffffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h10000000 : begin  // 256M
                        d2d_add_mask[i][31:0] <= 32'h0fffffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h20000000 : begin  // 512M
                        d2d_add_mask[i][31:0] <= 32'h1fffffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h40000000 : begin  // 1G
                        d2d_add_mask[i][31:0] <= 32'h3fffffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    32'h80000000 : begin  // 2G
                        d2d_add_mask[i][31:0] <= 32'h7fffffff;
                        srbuf_size_err[i]     <= 1'b0;
                    end
                    default      : begin  // 
                        d2d_add_mask[i][31:0] <= 32'hffffffff;
                        srbuf_size_err[i]     <= 1'b1;
                    end
                endcase
            end

            else if ( ch_mode_2_1t[i] ) begin // 4k
                d2d_add_mask[i][31:0] <= 32'h00000fff;
                srbuf_size_err[i]     <= 1'b0;
            end

            else begin // DEQ mode
                d2d_add_mask[i][31:0] <= 32'hffffffff;
                srbuf_size_err[i]     <= 1'b0;
            end
        end

    end

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            srbuf_addr_1t[i][63:0] <= {64{1'b0}};
            srbuf_size_1t[i][31:0] <= {32{1'b0}};
        end
        else begin
            srbuf_addr_1t[i][63:0] <= srbuf_addr[i][63:0];
            srbuf_size_1t[i][31:0] <= (ch_mode_1_1t)? srbuf_size[i][31:0] : D2D_DIRECT_SIZE;
        end
    end

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            d2d_addr[i][63:0] <= {64{1'b0}};
        end
        else begin
            d2d_addr[i][63:0] <= srbuf_addr_1t[i][63:0] +  d2d_addr_add_1t[i][31:0] ; // dst_address;
        end
    end
    
end

always_comb begin
    wt_header2[63:6] = {58{1'b0}};

    for (int i=0; i<CH_PAR_CHAIN; i++) begin
        if ( cid_hld[2:0] == i ) begin
            wt_header2[ 63:6] = (curr_mode == 3'b001)? d2d_addr[i][63:6] : d2d_direct_addr[i][63:6]; // d2d_address
        end
    end

end


for (genvar i=0; i<CH_PAR_CHAIN; i++) begin

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            d2d_addr_add[i][31:0]  <= {32{1'b0}} ;
        end
        else if (ch_dscq_clr_1t[i]) begin
            d2d_addr_add[i][31:0]  <= {32{1'b0}} ;
        end
        else if ( dwr_axis_tready ) begin
            if ( (cid_hld[2:0] == i) && ( dmaw_stm == HD_GEN ) ) begin
                if ( burst_length[4:0] < (pkt_cycle[4:0]+1) ) begin
                    d2d_addr_add[i][31:0]  <=  d2d_addr_add[i][31:0] + (burst_length[4:0] << 6);
                end
                else begin
                    d2d_addr_add[i][31:0]  <=  d2d_addr_add[i][31:0] + pkt_length[31:0];
                end
            end
            else begin
                d2d_addr_add[i][31:0]  <= d2d_addr_add[i][31:0] ;
            end
        end
        else begin
            d2d_addr_add[i][31:0]  <= d2d_addr_add[i][31:0] ;
        end
    end

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            d2d_cnt[i][31:0] <= {32{1'b0}} ;
        end
        else if ( ch_mode_1_1t[i] ) begin
            if ( dwr_axis_tready ) begin
                if ( (cid_hld[2:0] == i) ) begin
                    if ( (d2d_cnt[i][31:0] >= d2d_interval_cnt[31:0]) && ( pkt_eop_valid_1t ) ) begin
                        d2d_cnt[i][31:0] <= {32{1'b0}} ;
                    end
                    else if ( rd_data2_frm_last_1t ) begin
                        d2d_cnt[i][31:0] <= {32{1'b0}} ;
                    end
                    else if ( dmaw_stm == HD_GEN ) begin
                        if ( burst_length[4:0] < (pkt_cycle[4:0]+1) ) begin
                            d2d_cnt[i][31:0] <=  d2d_cnt[i][31:0] + ( burst_length[4:0] << 6);
                        end
                        else begin
                            d2d_cnt[i][31:0] <=  d2d_cnt[i][31:0] + pkt_length[31:0];
                        end
                    end
                    else begin
                        d2d_cnt[i][31:0] <= d2d_cnt[i][31:0] ;
                    end
                end
                else begin
                    d2d_cnt[i][31:0] <= d2d_cnt[i][31:0] ;
                end
            end
            else begin
                d2d_cnt[i][31:0] <= d2d_cnt[i][31:0] ;
            end
        end
    end


    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            d2d_kick_flag[i] <= 1'b0 ;
        end
        else if ( d2d_kick_flag[i] && d2d_kick[i] ) begin
             d2d_kick_flag[i] <= 1'b0;
        end
        else if ( dwr_axis_tready ) begin
            if ( (cid_hld[2:0] == i) && ch_mode_1_1t[i] ) begin
                if ( ( pkt_eop_valid_1t && (d2d_cnt[i][31:0] >= d2d_interval_cnt[31:0]) )
                   || ( pkt_last_valid_1t ) ) begin
                    d2d_kick_flag[i] <= 1'b1;
                end
                else begin
                    d2d_kick_flag[i] <= d2d_kick_flag[i];
                end
            end
            else begin
                d2d_kick_flag[i] <= d2d_kick_flag[i];
            end
        end
        else begin
            d2d_kick_flag[i] <= d2d_kick_flag[i];
        end
    end


//    always_ff @(posedge user_clk or negedge reset_n) begin
//        if (~reset_n) begin
//            d2d_direct_add[i][31:0] <= {32{1'b0}};
//        end
//        else if (ch_dscq_clr_1t[i]) begin
//            d2d_direct_add[i][31:0] <= {32{1'b0}};
//        end
//        else if (rd_enb_3t) begin
//            if ( (d2p_cid_1t[2:0] == i) && ~rd_data2_frm_last_2t ) begin
//                d2d_direct_add[i][31:0] <= d2d_direct_add[i][31:0] +64;
//            end
//            else if ( (d2p_cid_1t[2:0] == i) && rd_data2_frm_last_2t ) begin
//                if ( frame_len[i][5:0] == 0 )begin
//                    d2d_direct_add[i][31:0] <= d2d_direct_add[i][31:0] +64;
//                end
//                else begin
//                    d2d_direct_add[i][31:0] <= d2d_direct_add[i][31:0] + frame_len[i][5:0];
//                end
//            end
//            else begin
//                d2d_direct_add[i][31:0] <= d2d_direct_add[i][31:0];
//            end
//        end
//        else begin
//            d2d_direct_add[i][31:0] <= d2d_direct_add[i][31:0];
//        end
//    end

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            d2d_direct_add[i][31:0] <= {32{1'b0}};
        end
        else if (ch_dscq_clr_1t[i]) begin
            d2d_direct_add[i][31:0] <= {32{1'b0}};
        end
        else if (rd_enb_1t) begin
            if ( (rd_data2_1t[6:4] == i) && ~rd_data2_frm_last ) begin
                d2d_direct_add[i][31:0] <= d2d_direct_add[i][31:0] +64;
            end
            else if ( (rd_data2_1t[6:4] == i) && rd_data2_frm_last ) begin
                if ( frame_len[i][5:0] == 0 )begin
                    d2d_direct_add[i][31:0] <= d2d_direct_add[i][31:0] +64;
                end
                else begin
                    d2d_direct_add[i][31:0] <= d2d_direct_add[i][31:0] + frame_len[i][5:0];
                end
            end
            else begin
                d2d_direct_add[i][31:0] <= d2d_direct_add[i][31:0];
            end
        end
        else begin
            d2d_direct_add[i][31:0] <= d2d_direct_add[i][31:0];
        end
    end


    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            d2d_addr_add_1t  [i][31:0] <= {32{1'b0}} ;
            d2d_direct_add_1t[i][31:0] <= {32{1'b0}} ;
        end
        else if (ch_dscq_clr_1t[i]) begin
            d2d_addr_add_1t  [i][31:0] <= {32{1'b0}} ;
            d2d_direct_add_1t[i][31:0] <= {32{1'b0}} ;
        end
        else begin
            d2d_addr_add_1t  [i][31:0] <= d2d_addr_add  [i][31:0] & d2d_add_mask[i][31:0];
            d2d_direct_add_1t[i][31:0] <= d2d_direct_add[i][31:0] & d2d_add_mask[i][31:0];
        end
    end

end


for (genvar i=0; i<CH_PAR_CHAIN; i++) begin

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            d2d_rbuf_wp[i][31:0] <= {32{1'b0}};
            srbuf_wp   [i][31:0] <= {32{1'b0}};
        end
        else if ( ch_mode_2_1t[i] ) begin
            d2d_rbuf_wp[i][31:0] <= d2d_direct_add[i][31:0] & d2d_add_mask[i][31:0];
            srbuf_wp   [i][31:0] <= d2d_direct_add[i][31:0] & d2d_add_mask[i][31:0];
        end
        else begin
            d2d_rbuf_wp[i][31:0] <= d2d_addr_add[i][31:0] & d2d_add_mask[i][31:0];
            srbuf_wp   [i][31:0] <= d2d_addr_add[i][31:0] & d2d_add_mask[i][31:0];
        end
    end

end

//assign d2d_rbuf_wp = d2d_addr_add_1t;
//assign srbuf_wp    = d2d_addr_add_1t;

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        frame_last <= 1'b0 ;
    end
    else if ( dwr_axis_tready && pkt_last_valid_1t && (curr_mode_1t == 3'b001) ) begin
            frame_last <= 1'b1;
    end
    else if ( |d2d_kick ) begin
        frame_last <= 1'b0;
    end
    else begin
        frame_last <= frame_last;
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        d2d_kick_set <= 1'b0 ;
    end
    else if ( dwr_axis_tready ) begin
//        if ( d2d_kick_flag && (dwr_wr_ptr_hld == dwr_rd_ptr ) && ~d2d_kick_or && ~d2d_kick_set ) begin
        if ( d2d_kick_flag && ~d2d_kick_wait && ~d2d_kick_or && ~d2d_kick_set ) begin
            d2d_kick_set <= 1'b1;
        end
        else begin
            d2d_kick_set <= 1'b0;
        end
    end
    else begin
        d2d_kick_set <= 1'b0;
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        rq_pend_1t <= 1'b0;
        rq_pend_2t <= 1'b0;
    end
    else begin
        rq_pend_1t <= rq_pend;
        rq_pend_2t <= rq_pend_1t;
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        d2d_kick_wait <= 1'b0;
    end
    else if ( dwr_axis_tready && rd_data2_frm_last_1t ) begin
        d2d_kick_wait <= 1'b1;
    end
    else if ( ~rq_pend_1t && rq_pend_2t ) begin
        d2d_kick_wait <= 1'b0;
    end
    else begin
        d2d_kick_wait <= d2d_kick_wait;
    end
end


//always_ff @(posedge user_clk or negedge reset_n) begin
//    if (~reset_n) begin
//        dwr_wr_ptr_hld <= 1'b0 ;
//    end
//    else if ( dwr_axis_tready ) begin
//        if ( rd_data2_frm_last_1t ) begin
//            dwr_wr_ptr_hld <= rq_dmaw_dwr_axis_wr_ptr;
//        end
//        else begin
//            dwr_wr_ptr_hld <= dwr_wr_ptr_hld;
//        end
//    end
//    else begin
//        dwr_wr_ptr_hld <= dwr_wr_ptr_hld;
//    end
//end

//always_ff @(posedge user_clk or negedge reset_n) begin
//    if (~reset_n) begin
//        dwr_rd_ptr <= 1'b0 ;
//    end
//    else if ( dwr_axis_tready ) begin
//        dwr_rd_ptr <= rq_dmaw_dwr_axis_rd_ptr;
//    end
//    else begin
//        dwr_rd_ptr <= dwr_rd_ptr;
//    end
//end


// rp
for (genvar i=0; i<CH_PAR_CHAIN; i++) begin

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            d2d_rbuf_rp[i][31:0] <= {32{1'b0}};
        end
        else if (ch_dscq_clr_1t[i]) begin
            d2d_rbuf_rp[i][31:0] <= {32{1'b0}};
        end
        else if ( d2d_rp_updt[i] ) begin
             d2d_rbuf_rp[i][31:0] <= d2d_rp[31:0];
        end
        else begin
             d2d_rbuf_rp[i][31:0] <= d2d_rbuf_rp[i][31:0];
        end
    end

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            d2d_rbuf_rp_1t[i][31:0] <= {32{1'b0}};
        end
        else begin
             d2d_rbuf_rp_1t[i][31:0] <= d2d_rbuf_rp[i][31:0];
        end
    end

end


//assign srbuf_rp[i][31:0] = d2d_rbuf_rp_1t[i][31:0];
assign srbuf_rp = d2d_rbuf_rp_1t;


// dma stop flag (rbuf_wp - rbuf_rp)

logic [31:0] dbg_stop_wp [CH_PAR_CHAIN-1:0];
logic [31:0] dbg_stop_rp [CH_PAR_CHAIN-1:0];
logic [31:0] dbg_sel_stop_wp;
logic [31:0] dbg_sel_stop_rp;

for (genvar i=0; i<CH_PAR_CHAIN; i++) begin


    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            d2d_srbuf_free[i][31:0] <= {32{1'b0}};
        end
        else if ( d2d_rbuf_wp[i][31:0] >= d2d_rbuf_rp[i][31:0] ) begin
            d2d_srbuf_free[i][31:0] <= srbuf_size_1t[i][31:0]
                                       - ( (       d2d_rbuf_wp[i][31:0] - d2d_rbuf_rp[i][31:0] ) & d2d_add_mask[i][31:0] );
        end
        else begin
            d2d_srbuf_free[i][31:0] <= srbuf_size_1t[i][31:0]
                                       - ( ( {1'b1,d2d_rbuf_wp[i][31:0]} - d2d_rbuf_rp[i][31:0] ) & d2d_add_mask[i][31:0] );
        end
    end


    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            dma_stop_flag[i] <= 1'b0;
            dbg_stop_wp[i]   <= {32{1'b0}};
            dbg_stop_rp[i]   <= {32{1'b0}};
        end
        else if (ch_dscq_clr_1t[i]) begin
            dma_stop_flag[i] <= 1'b0;
            dbg_stop_wp[i]   <= {32{1'b0}};
            dbg_stop_rp[i]   <= {32{1'b0}};
        end

        else if ( ch_mode_1_1t[i] ) begin
            if ( d2d_srbuf_free[i][31:0] <= 32'h00000480 ) begin // 1k +128
//            if ( d2d_srbuf_free[i][31:0] <= 32'h00000400 ) begin // 1k
                dma_stop_flag[i] <= 1'b1;
                dbg_stop_wp[i]   <= d2d_rbuf_wp[i];
                dbg_stop_rp[i]   <= d2d_rbuf_rp[i];
            end
            else if ( d2d_srbuf_free[i][31:0] >= 32'h00001000 ) begin // 4k
                dma_stop_flag[i] <= 1'b0;
                dbg_stop_wp[i]   <= dbg_stop_wp[i];
                dbg_stop_rp[i]   <= dbg_stop_rp[i];
            end
            else begin
                dma_stop_flag[i] <= dma_stop_flag[i];
                dbg_stop_wp[i]   <= dbg_stop_wp[i];
                dbg_stop_rp[i]   <= dbg_stop_rp[i];
            end
        end

        else if ( ch_mode_2_1t[i] ) begin
            if ( d2d_srbuf_free[i][31:0] <= 32'h00000480 ) begin // 1k +128
//            if ( d2d_srbuf_free[i][31:0] <= 32'h00000400 ) begin // 1k
                dma_stop_flag[i] <= 1'b1;
                dbg_stop_wp[i]   <= d2d_rbuf_wp[i];
                dbg_stop_rp[i]   <= d2d_rbuf_rp[i];
            end
            else begin
                dma_stop_flag[i] <= 1'b0;
                dbg_stop_wp[i]   <= dbg_stop_wp[i];
                dbg_stop_rp[i]   <= dbg_stop_rp[i];
            end
        end

        else begin
            dma_stop_flag[i] <= 1'b0;
            dbg_stop_wp[i]   <= dbg_stop_wp[i];
            dbg_stop_rp[i]   <= dbg_stop_rp[i];
        end
        
    end
end

assign c2d_cifu_rd_enb = ~dma_stop_flag;

// error

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        err_dma_tx_1t <= 1'b0;
    end
    else begin
        err_dma_tx_1t <= err_dma_tx;
    end
end

for (genvar i=0; i<CH_PAR_CHAIN; i++) begin
    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            dst_addr_align_err[i]   <= 1'b0;
        end
        else begin
            dst_addr_align_err[i]   <=  ( |(dscq_dt_1t[i][69:64]) )
                                      | dst_addr_align_err[i];
        end
    end
end

// status reg
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
      status_reg00 <= {32{1'b0}};
      status_reg01 <= {32{1'b0}};
      status_reg02 <= {32{1'b0}};
      status_reg03 <= {32{1'b0}};
      status_reg04 <= {32{1'b0}};
      status_reg05 <= {32{1'b0}};
      status_reg06 <= {32{1'b0}};
      status_reg07 <= {32{1'b0}};
      status_reg08 <= {32{1'b0}};
      status_reg09 <= {32{1'b0}};
      status_reg10 <= {32{1'b0}};
      status_reg11 <= {32{1'b0}};
      status_reg12 <= {32{1'b0}};
      status_reg13 <= {32{1'b0}};
      status_reg14 <= {32{1'b0}};
      status_reg15 <= {32{1'b0}};
    end
    else begin
      status_reg00 <= { 1'b0, dmaw_stm[2:0],   2'b00, deq_stm[1:0], 24'h0000 }; // stm
      status_reg01 <= { 5'h0, fifo_wp[10:0],   5'h0,  fifo_rp[10:0] }; // ram addr
      status_reg02 <= { 3'h0,   rd_cnt[4:0],   3'h0,  re_cnt[4:0], 3'h0, dmaw_burst_cnt[4:0], 3'h0, burst_length[4:0] }; // counter
      status_reg03 <= { 5'h0, d2p_cid_1t[2:0], 8'h00, {16-CH_PAR_CHAIN{1'b0}}, dscq_vld_1t[CH_PAR_CHAIN-1:0] }; // dsc que
      status_reg04 <= { dsc_sel_data[ 31: 0] }; // sel dsc
      status_reg05 <= { dsc_sel_data[ 63:32] }; // sel dsc
      status_reg06 <= { dsc_sel_data[ 95:64] }; // sel dsc
      status_reg07 <= { dsc_sel_data[127:96] }; // sel dsc
      status_reg08 <= { {4{1'b0}}, eop_cnt[11:0] , used_addr_cnt[15:0]};
      status_reg09 <= d2d_sts_wp[31:0];
      status_reg10 <= d2d_sts_rp[31:0];
      status_reg11 <= dbg_sel_stop_wp[31:0];
      status_reg12 <= dbg_sel_stop_rp[31:0];
      status_reg13 <= { {16{1'b0}},                                               {16-CH_PAR_CHAIN{1'b0}}, dscq_empty_timeout[CH_PAR_CHAIN-1:0] };
      status_reg14 <= { {16{1'b0}},                                               {16-CH_PAR_CHAIN{1'b0}}, dst_addr_align_err[CH_PAR_CHAIN-1:0] };
      status_reg15 <= { {16-CH_PAR_CHAIN{1'b0}}, dscq_ovfl_hld[CH_PAR_CHAIN-1:0], {16-CH_PAR_CHAIN{1'b0}}, dscq_udfl_hld[CH_PAR_CHAIN-1:0] };
    end
end


//assign status_reg00 = { 1'b0, dmaw_stm[2:0],   2'b00, deq_stm[1:0], 24'h0000 }; // stm
//assign status_reg01 = { 5'h0, fifo_wp[10:0],   5'h0,  fifo_rp[10:0] }; // ram addr
//assign status_reg02 = { 3'h0,   rd_cnt[4:0],   3'h0,  re_cnt[4:0], 3'h0, dmaw_burst_cnt[4:0], 3'h0, burst_length[4:0] }; // counter
//assign status_reg03 = { 5'h0, d2p_cid_1t[2:0], 8'h00, {16-CH_PAR_CHAIN{1'b0}}, dscq_vld_1t[CH_PAR_CHAIN-1:0] }; // dsc que
//assign status_reg04 = { dsc_sel_data[ 31: 0] }; // sel dsc
//assign status_reg05 = { dsc_sel_data[ 63:32] }; // sel dsc
//assign status_reg06 = { dsc_sel_data[ 95:64] }; // sel dsc
//assign status_reg07 = { dsc_sel_data[127:96] }; // sel dsc
//assign status_reg08 = { {4{1'b0}}, eop_cnt[11:0] , used_addr_cnt[15:0]};
//assign status_reg09 = d2d_sts_wp[31:0];
//assign status_reg10 = d2d_sts_rp[31:0];
//assign status_reg11 = dbg_sel_stop_wp[31:0];
//assign status_reg12 = dbg_sel_stop_rp[31:0];
//assign status_reg13 = { {16{1'b0}},                                               {16-CH_PAR_CHAIN{1'b0}}, dscq_empty_timeout[CH_PAR_CHAIN-1:0] };
//assign status_reg14 = { {16{1'b0}},                                               {16-CH_PAR_CHAIN{1'b0}}, dst_addr_align_err[CH_PAR_CHAIN-1:0] };
//assign status_reg15 = { {16-CH_PAR_CHAIN{1'b0}}, dscq_ovfl_hld[CH_PAR_CHAIN-1:0], {16-CH_PAR_CHAIN{1'b0}}, dscq_udfl_hld[CH_PAR_CHAIN-1:0] };


always_comb begin
    d2d_sts_wp[31:0] <= {32{1'b0}};
    d2d_sts_rp[31:0] <= {32{1'b0}};

    if ( txch_sel[7:3] == 5'b00000 ) begin
    
        for (int i=0; i<CH_PAR_CHAIN; i++) begin
            if ( txch_sel[2:0] == i ) begin
                d2d_sts_wp[31:0] <= d2d_rbuf_wp[i][31:0];
                d2d_sts_rp[31:0] <= d2d_rbuf_rp[i][31:0];
                dbg_sel_stop_wp  <= dbg_stop_wp[i];
                dbg_sel_stop_rp  <= dbg_stop_rp[i];
            end
        end

    end
    else begin
        d2d_sts_wp[31:0] <= {32{1'b0}};
        d2d_sts_rp[31:0] <= {32{1'b0}};
    end

end


// input drop //

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        c2d_pkt_flag <= 1'b0;
    end
    else if ( c2d_axis_tready && c2d_axis_tuser[6] && c2d_axis_tvalid ) begin  // eop
        c2d_pkt_flag <= 1'b0;
    end
    else if ( c2d_axis_tready && c2d_axis_tuser[7] && c2d_axis_tvalid ) begin  // sop
        c2d_pkt_flag <= 1'b1;
    end
    else begin
        c2d_pkt_flag <= c2d_pkt_flag;
    end
end


for (genvar i=0; i<CH_PAR_CHAIN; i++) begin

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            ch_ie_1t [i] <= 1'b0;
            ch_oe_1t [i] <= 1'b0;
            ch_clr_1t[i] <= 1'b0;
            ch_dscq_clr_1t[i] <= 1'b0;
        end
        else begin
            ch_ie_1t      [i] <= ch_ie      [i];
            ch_oe_1t      [i] <= ch_oe      [i];
            ch_clr_1t     [i] <= ch_clr     [i];
            ch_dscq_clr_1t[i] <= ch_dscq_clr[i];
        end
    end


    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            c2d_pkt_busy[i] <= 1'b0;
        end
        else if ( c2d_axis_tready && c2d_axis_tuser[6] && c2d_axis_tvalid ) begin  // eop
            c2d_pkt_busy[i] <= 1'b0;
        end
        else if ( c2d_axis_tready && c2d_axis_tuser[7] && c2d_axis_tvalid ) begin  // sop
            if ( c2d_axis_tuser[15:8] == i ) begin
                c2d_pkt_busy[i] <= 1'b1;
            end
            else begin
                c2d_pkt_busy[i] <= 1'b0;
            end
        end
        else begin
            c2d_pkt_busy[i] <= c2d_pkt_busy[i];
        end
    end


    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            c2d_pkt_drop_flag[i] <= 1'b1;
        end
        else if ( dscq_empty_timeout[i] ) begin
            c2d_pkt_drop_flag[i] <= 1'b1;
        end
        else if ( ch_oe_1t[i] && ~c2d_pkt_flag && c2d_pkt_drop_flag[i] ) begin
            c2d_pkt_drop_flag[i] <= 1'b0;
        end
        else if ( ~ch_oe_1t[i] && ~c2d_pkt_flag && ~c2d_pkt_drop_flag[i] ) begin
            c2d_pkt_drop_flag[i] <= 1'b1;
        end
        else begin
            c2d_pkt_drop_flag[i] <= c2d_pkt_drop_flag[i];
        end
    end

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            c2d_pkt_drop_flag_1t[i] <= 1'b1;
        end
        else begin
            c2d_pkt_drop_flag_1t[i] <= c2d_pkt_drop_flag[i];
        end
    end

    always_comb begin
        wt_enb_pre[i] = 1'b0;
        if ( (c2d_cid_1t[2:0] == i) &&  ~c2d_pkt_drop_flag[i] ) begin
            wt_enb_pre[i]  <= c2d_axis_tready && c2d_axis_tvalid_1t;
        end
    end

end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        wt_enb <= 1'b0;
    end
    else begin
        wt_enb <= |wt_enb_pre;
    end
end


// tx drain //

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        rd_pkt_flag <= 1'b0;
    end
    else if (  rd_pkt_flag && rd_enb_1t && rd_data2_1t[1] ) begin  // eop
        rd_pkt_flag <= 1'b0;
    end
    else if ( ~rd_pkt_flag && rd_enb_1t && rd_data2_1t[2] ) begin  // sop
        rd_pkt_flag <= 1'b1;
    end
    else begin
        rd_pkt_flag <= rd_pkt_flag;
    end
end


for (genvar i=0; i<CH_PAR_CHAIN; i++) begin

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            tx_drain_flag[i] <= 1'b0;
        end
        else if (ch_dscq_clr_1t[i]) begin
            tx_drain_flag[i] <= 1'b0;
        end
        else if ( dscq_empty_timeout[i] ) begin
            tx_drain_flag[i] <= 1'b1;
        end
        else if ( ch_oe_1t[i] && tx_drain_flag[i] ) begin
            tx_drain_flag[i] <= 1'b0;
        end
        else if ( ~ch_oe_1t[i] && ~rd_pkt_flag && dmaw_end ) begin
            tx_drain_flag[i] <= 1'b1;
        end
        else begin
            tx_drain_flag[i] <= tx_drain_flag[i];
        end
    end

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            tx_drain_wp  [i] <= {11{1'b0}};
            tx_buff_busy [i] <=     1'b0;
        end
        else if (ch_dscq_clr_1t[i]) begin
            tx_drain_wp  [i] <= {11{1'b0}};
            tx_buff_busy [i] <=     1'b0;
        end
        else if ( wt_enb_sop && (c2d_cid_1t[2:0] == i) ) begin
            tx_drain_wp  [i] <= fifo_wp;
            tx_buff_busy [i] <= 1'b1;
        end
        else if ( (tx_drain_wp[i] == fifo_rp) ) begin
            tx_drain_wp  [i] <= tx_drain_wp[i];
            tx_buff_busy [i] <= 1'b0;
        end
        else begin
            tx_drain_wp  [i] <= tx_drain_wp  [i];
            tx_buff_busy [i] <= tx_buff_busy [i];
        end
    end

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            tx_busy [i] <= 1'b0;
        end
        else if ( ~ch_oe[i] && ch_oe_1t[i] ) begin
            tx_busy [i] <= 1'b1;
        end
        else if ( c2d_pkt_busy[i] || tx_buff_busy[i] || tx_deq_busy[i] ) begin
            tx_busy [i] <= 1'b1;
        end
        else if ( ~c2d_pkt_busy[i] && ~tx_buff_busy[i] && ~tx_deq_busy[i] ) begin
            tx_busy [i] <= 1'b0;
        end
        else begin
            tx_busy [i] <= tx_busy [i];
        end
    end

    always_comb begin
        dwr_valid_drain[i] = 1'b0;
        if ( ((dmaw_stm == HD_GEN) || (dmaw_stm == DMA_WT)) 
             && (cid_hld[2:0] == i) && tx_drain_flag[i] ) begin
            dwr_valid_drain[i] = 1'b1;
        end
    end

end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        dwr_valid_drain_or <= 1'b0;
    end
    else if ( |dwr_valid_drain ) begin
        dwr_valid_drain_or <= 1'b1;
    end
    else begin
        dwr_valid_drain_or <= 1'b0;
    end
end



assign ch_busy = tx_busy | c2d_cifu_busy;


// dscq empty timer

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        timer_pulse_1t <= 1'b0;
    end
    else begin
        timer_pulse_1t <= timer_pulse;
    end
end


for (genvar i=0; i<CH_PAR_CHAIN; i++) begin

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            dscq_empty_timer[i] <= {8{1'b0}};
        end
        else if (ch_dscq_clr_1t[i]) begin
            dscq_empty_timer[i] <= {8{1'b0}};
        end
        else if ( ch_mode_0_1t[i] && ch_ie_1t[i] && ch_oe_1t[i] ) begin
            if ( dscq_vld_1t[i] ) begin
                dscq_empty_timer[i] <= {8{1'b0}};
            end
            else if ( timer_pulse_1t ) begin
                dscq_empty_timer[i] <= dscq_empty_timer[i] +1;
            end
            else begin
                dscq_empty_timer[i] <= dscq_empty_timer[i];
            end
        end
        else begin
            dscq_empty_timer[i] <= {8{1'b0}};
        end
    end
    
    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            dscq_empty_timeout[i] <= 1'b0;
        end
        else if ( ch_dscq_clr_1t[i] ) begin
            dscq_empty_timeout[i] <= 1'b0;
        end
        else if ( (~ch_ie_1t[i] && ~ch_oe_1t[i] )
                 || ( ~dscq_to_enb )
                 ) begin
            dscq_empty_timeout[i] <= 1'b0;
        end
        else if ( dscq_empty_timer[i] == 8'hff ) begin
            dscq_empty_timeout[i] <= 1'b1;
        end
        else begin
            dscq_empty_timeout[i] <= dscq_empty_timeout[i];
        end
    end

end



//// trace 
//
//always_ff @(posedge user_clk or negedge reset_n) begin
//    if (~reset_n) begin
//        trace_on <=     1'b0  ;
//    end
//    else if ( (enqc_cmd[7] == 1'b1) && dsc_read ) begin
//        trace_on <= 1'b1;
//    end
//    else if ( (enqc_cmd[7] == 1'b0) && dsc_read ) begin
//        trace_on <= 1'b0;
//    end
//    else begin
//        trace_on <=  trace_on;
//    end
//end
//
//
//always_ff @(posedge user_clk or negedge reset_n) begin
//    if (~reset_n) begin
//        rd_data2_start    <= 1'b0;
//        rd_data2_end      <= 1'b0;
//        pkt_start_flag_1t <= 1'b0;
//    end
//    else begin
//        rd_data2_start    <= rd_data2[81];
//        rd_data2_end      <= rd_data2[80];
//        pkt_start_flag_1t <= pkt_start_flag;
//    end
//end
//
//always_ff @(posedge user_clk or negedge reset_n) begin
//    if (~reset_n) begin
//        pkt_start_flag <= 1'b0;
//    end
//    else if ( ~pkt_start_flag && (dmaw_stm == DMA_WT) ) begin
//        pkt_start_flag <= 1'b1;
//    end
//    else if (  pkt_start_flag && (dmaw_stm != DMA_WT) ) begin
//        pkt_start_flag <= 1'b0;
//    end
//    else begin
//        pkt_start_flag <= pkt_start_flag;
//    end
//end
//
//
//always_ff @(posedge user_clk or negedge reset_n) begin
//    if (~reset_n) begin
//        trace_length[31:0] <= {32{1'b0}};
//    end
//    else if (dsc_read) begin
//        trace_length[31:0] <= dsc_tx_dst_len[31:0];
//    end
//    else begin
//        trace_length[31:0] <= trace_length[31:0];
//    end
//end
//
//
//// 1 discriptor pkt start/end
//assign trace_dsc_start        = ~rd_data2[81] & rd_data2_start ;
//assign trace_dsc_end          = dmaw_end ;
//
//// 1 pcie pkt start/end
//assign trace_pkt_start        = pkt_start_flag & ~pkt_start_flag_1t;
//assign trace_pkt_end          = dmaw_ready & dma_write_end_2t;
//
//assign trace_keep   [15:0]  = wt_keep [15:0];
//assign trace_data  [511:0]  = rd_buff[511:0];
//
//assign trace_dsc_read       = dsc_read;

endmodule // dma_tx_ctrl.sv
