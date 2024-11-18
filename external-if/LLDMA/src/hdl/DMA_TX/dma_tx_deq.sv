/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/


////////////////////////////////////////////////////////
// Design      : dma_tx_deq.sv
// Designer    : hayasaka
////////////////////////////////////////////////////////

module dma_tx_deq #(
  parameter             CHAIN_NUM =   4,
  parameter                CH_NUM =  32,
  parameter          CH_PAR_CHAIN = CH_NUM / CHAIN_NUM,
  parameter         DEQ_DSC_WIDTH = 128,
  parameter          DEQ_DT_WIDTH = 128,

  parameter    D2D_DSC_ADRS_WIDTH =  64,
  parameter    ACK_DSC_ADRS_WIDTH =  64,

  //Do not modify the parameters below this line
  parameter C_DATA_WIDTH = 512,
  parameter PARITY_WIDTH = C_DATA_WIDTH /8
  )
(
//
     input    logic            user_clk
    ,input    logic            reset_n

// CH controll
    ,input    logic                  [2:0] ch_mode [CH_PAR_CHAIN-1:0]


// dsc (from dma_tx_ctrl)
    ,input    logic    [DEQ_DSC_WIDTH-1:0] dscq_dt[CH_PAR_CHAIN-1:0]
    ,input    logic     [CH_PAR_CHAIN-1:0] dscq_rls
    ,input    logic                [127:0] dscq_rls_dt

    ,input    logic                 [31:0] srbuf_wp[CH_PAR_CHAIN-1:0]
    ,input    logic                        frame_last

// 
    ,input    logic                    [15:0] dma_tx_status

    ,input    logic        [CH_PAR_CHAIN-1:0] deq_kick
    ,input    logic        [CH_PAR_CHAIN-1:0] d2d_kick
    ,input    logic                    [31:0] deq_frm_len
    ,input    logic        [CH_PAR_CHAIN-1:0] deq_wt_ack
    ,output   logic        [CH_PAR_CHAIN-1:0] deq_wt_req
    ,output   logic        [DEQ_DT_WIDTH-1:0] deq_wt_dt[CH_PAR_CHAIN-1:0]
    ,output   logic                           deq_comp
    ,output   logic                           deq_full

//
    ,input    logic        [CH_PAR_CHAIN-1:0] ch_oe
    ,input    logic        [CH_PAR_CHAIN-1:0] tx_drain_flag
    ,output   logic        [CH_PAR_CHAIN-1:0] tx_deq_busy


// debug
    ,output   logic        [CH_PAR_CHAIN-1:0] deq_wt_req_enb
    ,output   logic        [CH_PAR_CHAIN-1:0] deq_wt_ack_enb


//
);

//

logic  [CH_PAR_CHAIN-1:0] ch_mode_sel;
logic  [CH_PAR_CHAIN-1:0] ch_mode_1t;
logic  [CH_PAR_CHAIN-1:0] ch_oe_1t;

logic  [CH_PAR_CHAIN-1:0] dscq_rls_1t;
logic             [127:0] dscq_rls_dt_1t;
logic              [31:0] deq_frm_len_1t;
logic             [127:0] deq_packet;
logic                     deq_pkt_flag;
logic                     deq_pkt_flag_1t;
logic                     deq_wt_req_set;
logic                     deq_wt_ack_or;
logic  [CH_PAR_CHAIN-1:0] deq_kick_1t;
logic  [CH_PAR_CHAIN-1:0] d2d_kick_1t;

logic              [31:0] srbuf_wp_sel;
logic              [31:0] srbuf_wp_1t;
logic                     frame_last_1t;

logic  [CH_PAR_CHAIN-1:0] deq_num[15:0];
logic              [63:0] deq_dt [15:0];

logic               [4:0] wp;
logic               [4:0] wp_p1;
logic               [4:0] rp;
logic                     deq_we;
logic                     d2d_we;
logic                     re;
logic                     empty;
logic                     empty_1t;
logic                     full;
logic                     ovfl;
logic                     udfl;

logic  [CH_PAR_CHAIN-1:0] tx_drain_flag_1t;
logic  [CH_PAR_CHAIN-1:0] tx_drain_trg;
logic               [4:0] tx_drain_wp     [CH_PAR_CHAIN-1:0];


always_comb begin
    srbuf_wp_sel[31:0]     <= {    32{1'b0}};
    ch_mode_sel            <= {CH_PAR_CHAIN{1'b0}};
    for (int i=0; CH_PAR_CHAIN>i; i++) begin
        if ( d2d_kick[i] ) begin
            srbuf_wp_sel[31:0]     <= srbuf_wp[i][31:0];
            ch_mode_sel  [2:0]     <= ch_mode [i] [2:0];
        end
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        dscq_rls_1t           <= {CH_PAR_CHAIN{1'b0}};
        dscq_rls_dt_1t[127:0] <= {         128{1'b0}};
        deq_frm_len_1t [31:0] <= {          32{1'b0}};
        deq_kick_1t           <= {CH_PAR_CHAIN{1'b0}};
        d2d_kick_1t           <= {CH_PAR_CHAIN{1'b0}};
        frame_last_1t         <=               1'b0  ;
        srbuf_wp_1t[31:0]     <= {          32{1'b0}};
        ch_mode_1t            <= {CH_PAR_CHAIN{1'b0}};
        ch_oe_1t              <= {CH_PAR_CHAIN{1'b0}};
    end
    else begin
        dscq_rls_1t           <= dscq_rls;
        dscq_rls_dt_1t[127:0] <= dscq_rls_dt[127:0];
        deq_frm_len_1t [31:0] <= deq_frm_len [31:0];
        deq_kick_1t           <= deq_kick;
        d2d_kick_1t           <= d2d_kick;
        frame_last_1t         <= frame_last;
        srbuf_wp_1t[31:0]     <= srbuf_wp_sel[31:0];
        ch_mode_1t  [2:0]     <= ch_mode_sel  [2:0];
        ch_oe_1t              <= ch_oe;
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        deq_we <= 1'b0;
    end
    else if ( |deq_kick ) begin
        deq_we <= 1'b1;
    end
    else begin
        deq_we <= 1'b0;
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        d2d_we <= 1'b0;
    end
    else if ( |d2d_kick ) begin
        d2d_we <= 1'b1;
    end
    else begin
        d2d_we <= 1'b0;
    end
end

assign we = deq_we | d2d_we;

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        re <= 1'b0;
    end
    else if ( deq_wt_ack_or ) begin
        re <= 1'b1;
    end
    else begin
        re <= 1'b0;
    end
end

// write pointer
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        wp[4:0] <= {5{1'b0}};
        ovfl    <= 1'b0;
    end
    else if (we) begin
        if (full) begin
            ovfl <= 1'b1;
        end
        else begin
            wp[4:0] <= wp[4:0] + 1;
            ovfl <= ovfl;
        end
    end
    else begin
        wp[4:0] <= wp[4:0];
        ovfl    <= ovfl;
    end
end


// read pointer
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        rp[4:0] <= {5{1'b0}};
        udfl    <= 1'b0;
    end
    else if (re) begin
        if (empty) begin
            udfl <= 1'b1;
        end
        else begin
            rp[4:0] <= rp[4:0] + 1;
            udfl    <= udfl;
        end
    end
    else begin
        rp[4:0] <= rp[4:0] ;
        udfl    <= udfl;
    end
end




// Queue

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        for (int i=0; i>16; i++) begin
            deq_num[i][CH_PAR_CHAIN-1:0] <= { CH_PAR_CHAIN{1'b0}};
            deq_dt [i][            63:0] <= {           64{1'b0}};
        end
    end
    else begin
        if ( deq_we ) begin
            deq_num[wp[3:0]][CH_PAR_CHAIN-1: 0] <= deq_kick_1t[CH_PAR_CHAIN-1:0]; // deq ch
            deq_dt [wp[3:0]][            15: 0] <= dscq_rls_dt_1t[15:0]         ; // task_id
            deq_dt [wp[3:0]][            23:16] <= 8'h02                        ; // cmd
            deq_dt [wp[3:0]][            31:24] <= dma_tx_status[7:0]           ; // status
            deq_dt [wp[3:0]][            63:32] <= deq_frm_len_1t[31:0]         ; // dst len
        end
        else if ( d2d_we ) begin
            deq_num[wp[3:0]][CH_PAR_CHAIN-1: 0] <= d2d_kick_1t[CH_PAR_CHAIN-1:0]; // d2d ch
            deq_dt [wp[3:0]][            23: 0] <= {24{1'b0}}                   ; //
            deq_dt [wp[3:0]][               24] <= frame_last_1t                ; // frame last
            deq_dt [wp[3:0]][            31:25] <= { 7{1'b0}}                   ; //
            deq_dt [wp[3:0]][            63:32] <= srbuf_wp_1t[31:0]            ; // srbuf wp
        end
        else begin
            deq_num[wp[3:0]][CH_PAR_CHAIN-1: 0] <= deq_num[wp[3:0]][CH_PAR_CHAIN-1:0];
            deq_dt [wp[3:0]][            63: 0] <= deq_dt [wp[3:0]][            63:0];
        end
    end
end



assign deq_wt_ack_or = |(deq_wt_ack);


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        deq_packet  [127:0]  <= {128{1'b0}};
        deq_wt_req           <= 1'b0;
        deq_pkt_flag         <= 1'b0;
    end
    else if ( ~deq_pkt_flag ) begin
        if ( ~re && (wp != rp) ) begin
            deq_packet[           63: 0] <= deq_dt [rp[3:0]][            63:0]; // task_id,cmd,sts,dst_len
            deq_packet[          127:64] <= {64{1'b0}}                        ; // rserved (dst addr)
            deq_wt_req[CH_PAR_CHAIN-1:0] <= deq_num[rp[3:0]][CH_PAR_CHAIN-1:0];
            deq_pkt_flag           <= 1'b1;
        end
        else begin
            deq_packet[           127:0] <= deq_packet[           127:0];
            deq_wt_req[CH_PAR_CHAIN-1:0] <= deq_wt_req[CH_PAR_CHAIN-1:0];
            deq_pkt_flag                 <= deq_pkt_flag;
        end
    end
    else if ( deq_wt_ack_or ) begin
        deq_packet[           127:0] <= deq_packet   [127:0];
        deq_wt_req[CH_PAR_CHAIN-1:0] <= {CH_PAR_CHAIN{1'b0}};
        deq_pkt_flag                 <=               1'b0  ;
    end
    else begin
        deq_packet[           127:0] <= deq_packet[           127:0];
        deq_wt_req[CH_PAR_CHAIN-1:0] <= deq_wt_req[CH_PAR_CHAIN-1:0];
        deq_pkt_flag                 <= deq_pkt_flag;
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        deq_pkt_flag_1t <= 1'b0;
    end
    else begin
        deq_pkt_flag_1t <= deq_pkt_flag;
    end
end


assign empty = (wp == rp);

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        empty_1t <= 1'b0;
    end
    else begin
        empty_1t <= empty_1t;
    end
end

assign deq_wt_req_set =  (~empty & empty_1t)
                       | (wp != rp);


assign wp_p1[4:0]  = wp[4:0] + 1 ;

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        full  <= 1'b0;
    end
    else if ( (wp_p1[4] != rp[4]) && (wp_p1[3:0] == rp[3:0]) && we && ~re ) begin
        full <= 1'b1;
    end
    else if ( re ) begin
        full <= 1'b0;
    end
    else begin
        full <= full;
    end
end



// output

assign  deq_comp = ~deq_pkt_flag_1t & deq_pkt_flag ;
assign  deq_full = full;

always_comb begin
    for (int i=0; CH_PAR_CHAIN>i; i++) begin
        deq_wt_dt[i][127:0] <= deq_packet[127:0];
    end
end


// drain

assign tx_drain_trg = tx_drain_flag & ~tx_drain_flag_1t;

for (genvar i=0; i<CH_PAR_CHAIN; i++) begin

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            tx_drain_flag_1t[i] <= 1'b0;
        end
        else begin
            tx_drain_flag_1t[i] <= tx_drain_flag[i];
        end
    end


    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            tx_deq_busy[i] <= 1'b0;
        end
        else if ( tx_drain_trg[i] ) begin
            tx_deq_busy[i] <= 1'b1  ;
        end
        else if ( tx_deq_busy && (tx_drain_wp[i] == rp) ) begin
            tx_deq_busy[i] <= 1'b0;
        end
        else begin
            tx_deq_busy[i] <= tx_deq_busy[i];
        end
    end

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            tx_drain_wp[i] <= {5{1'b0}};
        end
        else if ( tx_drain_trg[i] ) begin
            tx_drain_wp[i] <= wp;
        end
        else if ( tx_drain_flag[i] && (deq_kick_1t[i] || d2d_kick_1t[i]) ) begin
            tx_drain_wp[i] <= wp;
        end
        else begin
            tx_drain_wp[i] <= tx_drain_wp[i];
        end
    end


end



//// debug ////

// PA
assign deq_wt_req_enb[CH_PAR_CHAIN-1:0] = deq_kick  [CH_PAR_CHAIN-1:0] & {CH_PAR_CHAIN{~deq_pkt_flag}};
assign deq_wt_ack_enb[CH_PAR_CHAIN-1:0] = deq_wt_ack[CH_PAR_CHAIN-1:0] & {CH_PAR_CHAIN{ deq_pkt_flag}};


endmodule // dma_tx_deq.sv

