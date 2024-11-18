/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module eve_arbter_hub #(
   parameter CHAIN_NUM       = 4,
   parameter CH_NUM          = 32
  )(
  input  wire         user_clk,
  input  wire         reset_n,
  input  wire [CHAIN_NUM-1:0]        s_axis_cd_transfer_eve_tvalid,
  input  wire [CHAIN_NUM-1:0][127:0] s_axis_cd_transfer_eve_tdata,
  output wire [CHAIN_NUM-1:0]        s_axis_cd_transfer_eve_tready,
  input  wire [CHAIN_NUM-1:0]        s_axis_cu_transfer_eve_tvalid,
  input  wire [CHAIN_NUM-1:0][127:0] s_axis_cu_transfer_eve_tdata,
  output wire [CHAIN_NUM-1:0]        s_axis_cu_transfer_eve_tready,
  output wire [CHAIN_NUM-1:0]        m_axis_transfer_eve_tvalid,
  output wire [CHAIN_NUM-1:0][127:0] m_axis_transfer_eve_tdata,
  input  wire [CHAIN_NUM-1:0]        m_axis_transfer_eve_tready,
  output wire [CHAIN_NUM-1:0]        m_axis_cd_transfer_cmd_tvalid,
  output wire [CHAIN_NUM-1:0][ 63:0] m_axis_cd_transfer_cmd_tdata,
  input  wire [CHAIN_NUM-1:0]        m_axis_cd_transfer_cmd_tready,
  output wire [CHAIN_NUM-1:0]        m_axis_cu_transfer_cmd_tvalid,
  output wire [CHAIN_NUM-1:0][ 63:0] m_axis_cu_transfer_cmd_tdata,
  input  wire [CHAIN_NUM-1:0]        m_axis_cu_transfer_cmd_tready,
  input  wire [CHAIN_NUM-1:0]        s_axis_transfer_cmd_tvalid,
  input  wire [CHAIN_NUM-1:0][ 63:0] s_axis_transfer_cmd_tdata,
  output wire [CHAIN_NUM-1:0]        s_axis_transfer_cmd_tready,
  input  wire           [CH_NUM-1:0] dma_rx_ch_connection_enable,
  input  wire           [CH_NUM-1:0] dma_tx_ch_connection_enable
);

generate
  genvar eve_arb_port;    
  for (eve_arb_port=0; eve_arb_port<CHAIN_NUM; eve_arb_port=eve_arb_port+1) 
  begin : eve_arb_inst 
    
     eve_arbter #(
        .CHAIN_NUM(eve_arb_port+1)
       ) u_eve_arbter(
         .user_clk                       ( user_clk        ), // input  wire                           user_clk,
         .reset_n                        ( reset_n         ), // input  wire                           reset_n,
         .s_axis_cd_transfer_eve_tvalid  (s_axis_cd_transfer_eve_tvalid[eve_arb_port]  ) , //input  wire         
         .s_axis_cd_transfer_eve_tdata   (s_axis_cd_transfer_eve_tdata[eve_arb_port]   ) , //input  wire [127:0] 
         .s_axis_cd_transfer_eve_tready  (s_axis_cd_transfer_eve_tready[eve_arb_port]  ) , //output wire         
         .s_axis_cu_transfer_eve_tvalid  (s_axis_cu_transfer_eve_tvalid[eve_arb_port]  ) , //input  wire         
         .s_axis_cu_transfer_eve_tdata   (s_axis_cu_transfer_eve_tdata[eve_arb_port]   ) , //input  wire [127:0] 
         .s_axis_cu_transfer_eve_tready  (s_axis_cu_transfer_eve_tready[eve_arb_port]  ) , //output wire         
         .m_axis_transfer_eve_tvalid     (m_axis_transfer_eve_tvalid[eve_arb_port]     ) , //output wire         
         .m_axis_transfer_eve_tdata      (m_axis_transfer_eve_tdata[eve_arb_port]      ) , //output wire [127:0] 
         .m_axis_transfer_eve_tready     (m_axis_transfer_eve_tready[eve_arb_port]     ) , //input  wire         
         .m_axis_cd_transfer_cmd_tvalid  (m_axis_cd_transfer_cmd_tvalid[eve_arb_port]  ) , //output wire         
         .m_axis_cd_transfer_cmd_tdata   (m_axis_cd_transfer_cmd_tdata[eve_arb_port]   ) , //output wire [127:0] 
         .m_axis_cd_transfer_cmd_tready  (m_axis_cd_transfer_cmd_tready[eve_arb_port]  ) , //input  wire         
         .m_axis_cu_transfer_cmd_tvalid  (m_axis_cu_transfer_cmd_tvalid[eve_arb_port]  ) , //output wire         
         .m_axis_cu_transfer_cmd_tdata   (m_axis_cu_transfer_cmd_tdata[eve_arb_port]   ) , //output wire [127:0] 
         .m_axis_cu_transfer_cmd_tready  (m_axis_cu_transfer_cmd_tready[eve_arb_port]  ) , //input  wire         
         .s_axis_transfer_cmd_tvalid     (s_axis_transfer_cmd_tvalid[eve_arb_port]     ) , //input  wire         
         .s_axis_transfer_cmd_tdata      (s_axis_transfer_cmd_tdata[eve_arb_port]      ) , //input  wire [127:0] 
         .s_axis_transfer_cmd_tready     (s_axis_transfer_cmd_tready[eve_arb_port]     ) , //output wire         
         .dma_rx_ch_connection_enable    (dma_rx_ch_connection_enable[eve_arb_port*8+7:eve_arb_port*8] ) , //input  wire   [7:0] 
         .dma_tx_ch_connection_enable    (dma_tx_ch_connection_enable[eve_arb_port*8+7:eve_arb_port*8] )   //input  wire   [7:0] 
     );
    
  end
endgenerate



endmodule
