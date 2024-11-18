/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/


////////////////////////////////////////////////////////
// Design      : dma_tx_que.sv
// Designer    : hayasaka
////////////////////////////////////////////////////////

module dma_tx_que #(
  parameter        Q_DT_WIDTH    = (128 + 16)

  )
(
     input    logic         user_clk
    ,input    logic         reset_n
//
    ,input    logic                  clr
    ,input    logic                  we
    ,input    logic                  re
    ,input    logic [Q_DT_WIDTH-1:0] wd
    ,output   logic                  rdv
    ,output   logic [Q_DT_WIDTH-1:0] rd
    ,output   logic                  full
    ,output   logic                  ovfl
    ,output   logic                  udfl

);

//

logic [2:0] wp;
logic [2:0] wp_p1;
logic [2:0] rp;
logic       empty;


logic            [3:0] dsc_val;
logic [Q_DT_WIDTH-1:0] dsc_data[3:0];

integer i;

// Queue
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        dsc_val[3:0] <= {4{1'b0}};
    end
    else if ( clr ) begin
        dsc_val[3:0] <= {4{1'b0}};
    end
    else if ( wp[1:0] != rp[1:0] ) begin
        if ( re ) begin
            dsc_val [rp[1:0]] <= 1'b0;
        end
        else begin
            dsc_val [rp[1:0]] <= dsc_val [rp[1:0]];
        end
        if ( we ) begin
            dsc_val [wp[1:0]] <= 1'b1;
        end
        else begin
            dsc_val[wp[1:0]] <= dsc_val[wp[1:0]];
        end
    end
    else begin // wp == rp
        if ( we ) begin
            dsc_val [wp[1:0]] <= 1'b1;
        end
        else if ( re ) begin
            dsc_val [rp[1:0]] <= 1'b0;
        end
        else begin // ~we && ~re
            dsc_val [wp[1:0]] <= dsc_val [wp[1:0]];
        end
    end
end


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        for (i=0; i>4; i++) begin
            dsc_data[i][Q_DT_WIDTH-1:0] <= { Q_DT_WIDTH{1'b0}};
        end
    end
    else begin
        if ( we ) begin
            dsc_data[wp[1:0]] <= wd[Q_DT_WIDTH-1:0];
        end
        else begin
            dsc_data[wp[1:0]] <= dsc_data[wp[1:0]];
        end
    end
end



// write pointer
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        wp[2:0] <= {3{1'b0}};
        ovfl    <= 1'b0;
    end
    else if (clr) begin
        wp[2:0] <= {3{1'b0}};
        ovfl    <= 1'b0;
    end
    else if (we) begin
        if (full) begin
            ovfl <= 1'b1;
        end
        else begin
            wp[2:0] <= wp[2:0] + 1;
            ovfl <= ovfl;
        end
    end
    else begin
        wp[2:0] <= wp[2:0];
        ovfl    <= ovfl;
    end
end


// read pointer
always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        rp[2:0] <= {3{1'b0}};
        udfl    <= 1'b0;
    end
    else if (clr) begin
        rp[2:0] <= {3{1'b0}};
        udfl    <= 1'b0;
    end
    else if (re) begin
        if (empty) begin
            udfl <= 1'b1;
        end
        else begin
            rp[2:0] <= rp[2:0] + 1;
            udfl    <= udfl;
        end
    end
    else begin
        rp[2:0] <= rp[2:0] ;
        udfl    <= udfl;
    end
end


always_comb begin
    case (rp[1:0])
        2'b00  : begin
                 rdv                = dsc_val [0];
                 rd[Q_DT_WIDTH-1:0] = dsc_data[0][Q_DT_WIDTH-1:0];
        end
        2'b01  : begin
                 rdv                = dsc_val [1];
                 rd[Q_DT_WIDTH-1:0] = dsc_data[1][Q_DT_WIDTH-1:0];
        end
        2'b10  : begin
                 rdv                = dsc_val [2];
                 rd[Q_DT_WIDTH-1:0] = dsc_data[2][Q_DT_WIDTH-1:0];
        end
        2'b11  : begin
                 rdv                = dsc_val [3];
                 rd[Q_DT_WIDTH-1:0] = dsc_data[3][Q_DT_WIDTH-1:0];
        end
        default: begin
                 rdv                = dsc_val [0];
                 rd[Q_DT_WIDTH-1:0] = dsc_data[0][Q_DT_WIDTH-1:0];
        end
    endcase
end


// flow control

//assign full  = (wp[2] != rp[2]) & (wp[1:0] == rp[1:0]) ;
assign empty = (wp == rp);

assign wp_p1[2:0]  = wp[2:0] + 1 ;


always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        full  <= 1'b0;
    end
    else if ( clr ) begin
        full  <= 1'b0;
    end
    else if ( (wp_p1[2] != rp[2]) && (wp_p1[1:0] == rp[1:0]) && we && ~re ) begin
        full <= 1'b1;
    end
    else if ( re ) begin
        full <= 1'b0;
    end
    else begin
        full <= full;
    end
end

endmodule // dma_tx_que.sv



