/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/


////////////////////////////////////////////////////////
// Design      : dma_tx_dsc.sv
// Designer    : hayasaka
////////////////////////////////////////////////////////

module dma_tx_dsc #(
  parameter        CHAIN_NUM                       =   4,
  parameter        CH_NUM                          =  32,
  parameter        CH_PAR_CHAIN                    = CH_NUM / CHAIN_NUM,
  parameter        DEQ_DSC_WIDTH                   = 128,
  parameter        QUE_WIDTH                       = DEQ_DSC_WIDTH + (DEQ_DSC_WIDTH/8),


  parameter        D2D_DSC_ADRS_WIDTH              = 64,
  parameter        ACK_DSC_ADRS_WIDTH              = 64,
  parameter        DSC_TUSER_WIDTH                 = 32,
  parameter        REQ_WT_DATA_WIDTH               = 32,
  parameter        REQ_RD_DATA_WIDTH               = 32,
  parameter        REQ_USER_WIDTH                  = 64,

  //Do not modify the parameters below this line
  parameter C_DATA_WIDTH = 512,
  parameter PARITY_WIDTH = C_DATA_WIDTH /8,
  parameter KEEP_WIDTH   = C_DATA_WIDTH /32
  )
(
//
     input    logic         user_clk
    ,input    logic         reset_n

//

    ,input    logic       [CH_PAR_CHAIN-1:0] que_rd_dv
    ,input    logic      [DEQ_DSC_WIDTH-1:0] que_rd_dt

    ,input    logic       [CH_PAR_CHAIN-1:0] dscq_rls
    ,output   logic       [CH_PAR_CHAIN-1:0] dscq_vld
    ,output   logic      [DEQ_DSC_WIDTH-1:0] dscq_dt[CH_PAR_CHAIN-1:0]
    ,output   logic       [CH_PAR_CHAIN-1:0] que_rd_req

    ,input    logic       [CH_PAR_CHAIN-1:0] ch_dscq_clr


    ,output   logic       [CH_PAR_CHAIN-1:0] dscq_ovfl_hld
    ,output   logic       [CH_PAR_CHAIN-1:0] dscq_udfl_hld

    ,input    logic                          error_clear
    ,input    logic                          err_injct_dscq
    ,output   logic       [CH_PAR_CHAIN-1:0] err_dscq_pe
    ,output   logic       [CH_PAR_CHAIN-1:0] err_dscq_pe_ins


//

);


//----------------------------------------------------



logic      [CH_PAR_CHAIN-1:0] dscq_rdv;
logic     [DEQ_DSC_WIDTH-1:0] que_wdt;
logic [(DEQ_DSC_WIDTH/8)-1:0] que_wdt_p;
logic     [DEQ_DSC_WIDTH-1:0] que_rdt  [CH_PAR_CHAIN-1:0];
logic [(DEQ_DSC_WIDTH/8)-1:0] que_rdt_p[CH_PAR_CHAIN-1:0];
logic      [CH_PAR_CHAIN-1:0] dscq_full;
logic      [CH_PAR_CHAIN-1:0] dscq_ovfl;
logic      [CH_PAR_CHAIN-1:0] dscq_udfl;

logic                   [4:0] dsc_1st_size;
logic                  [31:0] dsc_1st_len;

logic [(DEQ_DSC_WIDTH/8)-1:0] que_rdt_pe[CH_PAR_CHAIN-1:0];
logic      [CH_PAR_CHAIN-1:0] que_rdt_pe_ch;
logic                         que_rdt_pe_or;

logic      [CH_PAR_CHAIN-1:0] dscq_clr;
logic                         err_injct_dscq_1t;
logic                         dscq_pe_ins_1shot;
logic                         dscq_pe_ins_1shot_1t;
logic                         error_clear_1t;


//



for ( genvar i=0; i<CH_PAR_CHAIN; i++) begin
    assign dscq_clr[i] = ch_dscq_clr[i] | (~error_clear & error_clear_1t);
end


assign que_wdt[DEQ_DSC_WIDTH-1:0] = que_rd_dt[DEQ_DSC_WIDTH-1:0];

assign que_wdt_p [0] =  (^que_rd_dt[7:0]) ^ dscq_pe_ins_1shot;

for ( genvar i=1; i<(DEQ_DSC_WIDTH/8); i++) begin
    assign que_wdt_p [i] =  ^(que_rd_dt[(8*i)+:8]);
end


for ( genvar i=0; i<CH_PAR_CHAIN; i++) begin
    for ( genvar j=0; j<(DEQ_DSC_WIDTH/8); j++) begin
        assign que_rdt_pe[i][j] =  (^que_rdt[i][(8*j)+:8]) ^(que_rdt_p[i][j]);
    end
end


// dsc buff

for ( genvar i=0; i<CH_PAR_CHAIN; i++) begin : DSC_QUE

    dma_tx_que DSC_QUEUE (
         .user_clk       (user_clk       )
        ,.reset_n        (reset_n        )
        ,.clr            (dscq_clr[i]    )
        ,.we             (que_rd_dv[i]   )
        ,.wd             ({que_wdt, que_wdt_p})
        ,.re             (dscq_rls[i]    )
        ,.rdv            (dscq_rdv[i]    )
        ,.rd             ({que_rdt[i], que_rdt_p[i]})
        ,.full           (dscq_full[i]   )
        ,.ovfl           (dscq_ovfl[i]   )
        ,.udfl           (dscq_udfl[i]   )

    );

end

for ( genvar i=0; i<CH_PAR_CHAIN; i++) begin

    always_comb begin
        dscq_dt      [i][DEQ_DSC_WIDTH-1:0] = que_rdt[i][DEQ_DSC_WIDTH-1:0];

    end
end


assign dscq_vld[CH_PAR_CHAIN-1:0]       = dscq_rdv[CH_PAR_CHAIN-1:0] & ~que_rdt_pe_ch[CH_PAR_CHAIN-1:0] ;


assign que_rd_req[CH_PAR_CHAIN-1:0] = ~dscq_full[CH_PAR_CHAIN-1:0];



// error 

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        err_injct_dscq_1t <= 1'b0;
        error_clear_1t    <= 1'b0;
    end
    else begin
        err_injct_dscq_1t <= err_injct_dscq;
        error_clear_1t    <= error_clear;
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        dscq_pe_ins_1shot <= 1'b0;
    end
    else if ( |que_rd_dv && dscq_pe_ins_1shot ) begin
        dscq_pe_ins_1shot <= 1'b0;
    end
    else if ( err_injct_dscq && ~err_injct_dscq_1t ) begin
        dscq_pe_ins_1shot <= 1'b1;
    end
    else begin
        dscq_pe_ins_1shot <= dscq_pe_ins_1shot;
    end
end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        dscq_pe_ins_1shot_1t <= 1'b0;
    end
    else begin
        dscq_pe_ins_1shot_1t <= dscq_pe_ins_1shot;
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    for (integer i=0; i< CH_PAR_CHAIN; i++) begin
        if (~reset_n) begin
            dscq_ovfl_hld[i] <= 1'b0;
            dscq_udfl_hld[i] <= 1'b0;
        end
        else begin
            dscq_ovfl_hld[i] <= dscq_ovfl_hld[i] | dscq_ovfl[i];
            dscq_udfl_hld[i] <= dscq_udfl_hld[i] | dscq_udfl[i];
        end
    end
end



for ( genvar i=0; i<CH_PAR_CHAIN; i++) begin

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            que_rdt_pe_ch[i] = 1'b0;
        end
        else if ( error_clear_1t ) begin
            que_rdt_pe_ch[i] = 1'b0;
        end
        else begin
            que_rdt_pe_ch[i] = ( ( |que_rdt_pe[i] ) & dscq_rdv[i] )
                              | que_rdt_pe_ch[i]
                              ;
        end
    end

    always_ff @(posedge user_clk or negedge reset_n) begin
        if (~reset_n) begin
            err_dscq_pe_ins[i] <= 1'b0;
        end
        else begin
            err_dscq_pe_ins[i] <= ~dscq_pe_ins_1shot & dscq_pe_ins_1shot_1t;
        end
    end

end

always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        que_rdt_pe_or = 1'b0;
    end
    else if ( error_clear_1t ) begin
        que_rdt_pe_or = 1'b0;
    end
    else begin
        que_rdt_pe_or = |que_rdt_pe_ch;
    end
end

assign err_dscq_pe = que_rdt_pe_ch;

endmodule // dma_tx_dsc.sv



