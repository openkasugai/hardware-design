/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1 ns / 1 ps 

`default_nettype none

module filter_resize(
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi_control:s_axis_rx_req_0:m_axis_rx_resp_0:s_axis_rx_data_0:m_axis_tx_req_0:s_axis_tx_resp_0:m_axis_tx_data_0:s_axis_rx_req_1:m_axis_rx_resp_1:s_axis_rx_data_1:m_axis_tx_req_1:s_axis_tx_resp_1:m_axis_tx_data_1" *)
  input   wire          ap_clk                          ,
  input   wire          ap_rst_n                        ,
  output  wire          detect_fault                    ,
  input   wire[9:0]     s_axi_control_araddr            ,
  output  wire          s_axi_control_arready           ,
  input   wire          s_axi_control_arvalid           ,
  input   wire[9:0]     s_axi_control_awaddr            ,
  output  wire          s_axi_control_awready           ,
  input   wire          s_axi_control_awvalid           ,
  input   wire          s_axi_control_bready            ,
  output  wire[1:0]     s_axi_control_bresp             ,
  output  wire          s_axi_control_bvalid            ,
  output  wire[31:0]    s_axi_control_rdata             ,
  input   wire          s_axi_control_rready            ,
  output  wire[1:0]     s_axi_control_rresp             ,
  output  wire          s_axi_control_rvalid            ,
  input   wire[31:0]    s_axi_control_wdata             ,
  output  wire          s_axi_control_wready            ,
  input   wire[3:0]     s_axi_control_wstrb             ,
  input   wire          s_axi_control_wvalid            ,
  input   wire[63:0]    s_axis_rx_req_0_tdata           ,
  input   wire          s_axis_rx_req_0_tvalid          ,
  output  wire          s_axis_rx_req_0_tready          ,
  output  wire[63:0]    m_axis_rx_resp_0_tdata          ,
  output  wire          m_axis_rx_resp_0_tvalid         ,
  input   wire          m_axis_rx_resp_0_tready         ,
  input   wire[31:0]    s_axis_rx_data_0_tdata          ,
  input   wire          s_axis_rx_data_0_tvalid         ,
  output  wire          s_axis_rx_data_0_tready         ,
  output  wire[63:0]    m_axis_tx_req_0_tdata           ,
  output  wire          m_axis_tx_req_0_tvalid          ,
  input   wire          m_axis_tx_req_0_tready          ,
  input   wire[63:0]    s_axis_tx_resp_0_tdata          ,
  input   wire          s_axis_tx_resp_0_tvalid         ,
  output  wire          s_axis_tx_resp_0_tready         ,
  output  wire[31:0]    m_axis_tx_data_0_tdata          ,
  output  wire          m_axis_tx_data_0_tvalid         ,
  input   wire          m_axis_tx_data_0_tready         ,
  input   wire[63:0]    s_axis_rx_req_1_tdata           ,
  input   wire          s_axis_rx_req_1_tvalid          ,
  output  wire          s_axis_rx_req_1_tready          ,
  output  wire[63:0]    m_axis_rx_resp_1_tdata          ,
  output  wire          m_axis_rx_resp_1_tvalid         ,
  input   wire          m_axis_rx_resp_1_tready         ,
  input   wire[31:0]    s_axis_rx_data_1_tdata          ,
  input   wire          s_axis_rx_data_1_tvalid         ,
  output  wire          s_axis_rx_data_1_tready         ,
  output  wire[63:0]    m_axis_tx_req_1_tdata           ,
  output  wire          m_axis_tx_req_1_tvalid          ,
  input   wire          m_axis_tx_req_1_tready          ,
  input   wire[63:0]    s_axis_tx_resp_1_tdata          ,
  input   wire          s_axis_tx_resp_1_tvalid         ,
  output  wire          s_axis_tx_resp_1_tready         ,
  output  wire[31:0]    m_axis_tx_data_1_tdata          ,
  output  wire          m_axis_tx_data_1_tvalid         ,
  input   wire          m_axis_tx_data_1_tready
  
);

wire[11:0] w_streamif_stall;
assign w_streamif_stall[0]  = s_axis_rx_req_0_tvalid   & ~ s_axis_rx_req_0_tready;
assign w_streamif_stall[1]  = m_axis_rx_resp_0_tvalid  & ~ m_axis_rx_resp_0_tready;
assign w_streamif_stall[2]  = s_axis_rx_data_0_tvalid  & ~ s_axis_rx_data_0_tready;
assign w_streamif_stall[3]  = s_axis_rx_req_1_tvalid   & ~ s_axis_rx_req_1_tready;
assign w_streamif_stall[4]  = m_axis_rx_resp_1_tvalid  & ~ m_axis_rx_resp_1_tready;
assign w_streamif_stall[5]  = s_axis_rx_data_1_tvalid  & ~ s_axis_rx_data_1_tready;
assign w_streamif_stall[6]  = m_axis_tx_req_0_tvalid   & ~ m_axis_tx_req_0_tready;
assign w_streamif_stall[7]  = s_axis_tx_resp_0_tvalid  & ~ s_axis_tx_resp_0_tready;
assign w_streamif_stall[8]  = m_axis_tx_data_0_tvalid  & ~ m_axis_tx_data_0_tready;
assign w_streamif_stall[9]  = m_axis_tx_req_1_tvalid   & ~ m_axis_tx_req_1_tready;
assign w_streamif_stall[10] = s_axis_tx_resp_1_tvalid  & ~ s_axis_tx_resp_1_tready;
assign w_streamif_stall[11] = m_axis_tx_data_1_tvalid  & ~ m_axis_tx_data_1_tready;

  filter_resize_bd filter_resize_bd_i (
    .ACLK                          (ap_clk                  ),
    .ARESET_N                      (ap_rst_n                ),
    .detect_fault                  (detect_fault            ),
    .s_axi_control_araddr          (s_axi_control_araddr    ),
    .s_axi_control_arready         (s_axi_control_arready   ),
    .s_axi_control_arvalid         (s_axi_control_arvalid   ),
    .s_axi_control_awaddr          (s_axi_control_awaddr    ),
    .s_axi_control_awready         (s_axi_control_awready   ),
    .s_axi_control_awvalid         (s_axi_control_awvalid   ),
    .s_axi_control_bready          (s_axi_control_bready    ),
    .s_axi_control_bresp           (s_axi_control_bresp     ),
    .s_axi_control_bvalid          (s_axi_control_bvalid    ),
    .s_axi_control_rdata           (s_axi_control_rdata     ),
    .s_axi_control_rready          (s_axi_control_rready    ),
    .s_axi_control_rresp           (s_axi_control_rresp     ),
    .s_axi_control_rvalid          (s_axi_control_rvalid    ),
    .s_axi_control_wdata           (s_axi_control_wdata     ),
    .s_axi_control_wready          (s_axi_control_wready    ),
    .s_axi_control_wstrb           (s_axi_control_wstrb     ),
    .s_axi_control_wvalid          (s_axi_control_wvalid    ),
    .s_axis_rx_req_0_tdata         (s_axis_rx_req_0_tdata   ),
    .s_axis_rx_req_0_tvalid        (s_axis_rx_req_0_tvalid  ),
    .s_axis_rx_req_0_tready        (s_axis_rx_req_0_tready  ),
    .m_axis_rx_resp_0_tdata        (m_axis_rx_resp_0_tdata  ),
    .m_axis_rx_resp_0_tvalid       (m_axis_rx_resp_0_tvalid ),
    .m_axis_rx_resp_0_tready       (m_axis_rx_resp_0_tready ),
    .s_axis_rx_data_0_tdata        (s_axis_rx_data_0_tdata  ),
    .s_axis_rx_data_0_tvalid       (s_axis_rx_data_0_tvalid ),
    .s_axis_rx_data_0_tready       (s_axis_rx_data_0_tready ),
    .m_axis_tx_req_0_tdata         (m_axis_tx_req_0_tdata   ),
    .m_axis_tx_req_0_tvalid        (m_axis_tx_req_0_tvalid  ),
    .m_axis_tx_req_0_tready        (m_axis_tx_req_0_tready  ),
    .s_axis_tx_resp_0_tdata        (s_axis_tx_resp_0_tdata  ),
    .s_axis_tx_resp_0_tvalid       (s_axis_tx_resp_0_tvalid ),
    .s_axis_tx_resp_0_tready       (s_axis_tx_resp_0_tready ),
    .m_axis_tx_data_0_tdata        (m_axis_tx_data_0_tdata  ),
    .m_axis_tx_data_0_tvalid       (m_axis_tx_data_0_tvalid ),
    .m_axis_tx_data_0_tready       (m_axis_tx_data_0_tready ),
    .s_axis_rx_req_1_tdata         (s_axis_rx_req_1_tdata   ),
    .s_axis_rx_req_1_tvalid        (s_axis_rx_req_1_tvalid  ),
    .s_axis_rx_req_1_tready        (s_axis_rx_req_1_tready  ),
    .m_axis_rx_resp_1_tdata        (m_axis_rx_resp_1_tdata  ),
    .m_axis_rx_resp_1_tvalid       (m_axis_rx_resp_1_tvalid ),
    .m_axis_rx_resp_1_tready       (m_axis_rx_resp_1_tready ),
    .s_axis_rx_data_1_tdata        (s_axis_rx_data_1_tdata  ),
    .s_axis_rx_data_1_tvalid       (s_axis_rx_data_1_tvalid ),
    .s_axis_rx_data_1_tready       (s_axis_rx_data_1_tready ),
    .m_axis_tx_req_1_tdata         (m_axis_tx_req_1_tdata   ),
    .m_axis_tx_req_1_tvalid        (m_axis_tx_req_1_tvalid  ),
    .m_axis_tx_req_1_tready        (m_axis_tx_req_1_tready  ),
    .s_axis_tx_resp_1_tdata        (s_axis_tx_resp_1_tdata  ),
    .s_axis_tx_resp_1_tvalid       (s_axis_tx_resp_1_tvalid ),
    .s_axis_tx_resp_1_tready       (s_axis_tx_resp_1_tready ),
    .m_axis_tx_data_1_tdata        (m_axis_tx_data_1_tdata  ),
    .m_axis_tx_data_1_tvalid       (m_axis_tx_data_1_tvalid ),
    .m_axis_tx_data_1_tready       (m_axis_tx_data_1_tready ),
    .streamif_stall                (w_streamif_stall        )
  );


endmodule //filter_resize

`default_nettype wire

