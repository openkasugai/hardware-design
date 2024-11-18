/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/


////////////////////////////////////////////////////////
// Design      : dma_tx_int.sv
// Designer    : hayasaka
////////////////////////////////////////////////////////

module dma_tx_int #()
(
//
     input   logic            user_clk
    ,input   logic            reset_n
    
// 
    ,input   logic            int_kick

// from/to PCI_TRX
    ,input   logic           int_msi_enb
    ,input   logic           int_msi_sent
    ,input   logic           int_msi_fail
    
    ,output  logic    [31:0]  msi_int_user
);

//




always_ff @(posedge user_clk or negedge reset_n) begin
    if (~reset_n) begin
        msi_int_user[31:0] <= {32{1'b0}};
    end
    else if (int_msi_enb && int_kick) begin
        msi_int_user[31:0] <= msi_int_user[31:0];
    end
    else if (int_msi_sent || int_msi_fail) begin
        msi_int_user[31:0] <= {32{1'b0}};
    end
    else begin
        msi_int_user[31:0] <= msi_int_user[31:0];
    end
end





endmodule // dma_tx_int.sv
