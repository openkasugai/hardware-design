/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`default_nettype none

module conversion_adaptor(
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi_control:m_axi_ingr_frame_buffer:s_axis_ingr_tx_req:m_axis_ingr_tx_resp:s_axis_ingr_tx_data:m_axis_egr_rx_req:s_axis_egr_rx_resp:m_axis_egr_rx_data:m_axis_ingr_tx_req0:s_axis_ingr_tx_resp0:m_axis_ingr_tx_data0:s_axis_egr_rx_req0:m_axis_egr_rx_resp0:s_axis_egr_rx_data0:m_axis_ingr_tx_req1:s_axis_ingr_tx_resp1:m_axis_ingr_tx_data1:s_axis_egr_rx_req1:m_axis_egr_rx_resp1:s_axis_egr_rx_data1" *)
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

  output  wire[63:0]    m_axi_ingr_frame_buffer_araddr  ,
  output  wire[1:0]     m_axi_ingr_frame_buffer_arburst ,
  output  wire[3:0]     m_axi_ingr_frame_buffer_arcache ,
  output  wire[0:0]     m_axi_ingr_frame_buffer_arid    ,
  output  wire[7:0]     m_axi_ingr_frame_buffer_arlen   ,
  output  wire[1:0]     m_axi_ingr_frame_buffer_arlock  ,
  output  wire[2:0]     m_axi_ingr_frame_buffer_arprot  ,
  output  wire[3:0]     m_axi_ingr_frame_buffer_arqos   ,
  input   wire          m_axi_ingr_frame_buffer_arready ,
  output  wire[3:0]     m_axi_ingr_frame_buffer_arregion,
  output  wire[2:0]     m_axi_ingr_frame_buffer_arsize  ,
  output  wire          m_axi_ingr_frame_buffer_arvalid ,
  output  wire[63:0]    m_axi_ingr_frame_buffer_awaddr  ,
  output  wire[1:0]     m_axi_ingr_frame_buffer_awburst ,
  output  wire[3:0]     m_axi_ingr_frame_buffer_awcache ,
  output  wire[0:0]     m_axi_ingr_frame_buffer_awid    ,
  output  wire[7:0]     m_axi_ingr_frame_buffer_awlen   ,
  output  wire[1:0]     m_axi_ingr_frame_buffer_awlock  ,
  output  wire[2:0]     m_axi_ingr_frame_buffer_awprot  ,
  output  wire[3:0]     m_axi_ingr_frame_buffer_awqos   ,
  input   wire          m_axi_ingr_frame_buffer_awready ,
  output  wire[3:0]     m_axi_ingr_frame_buffer_awregion,
  output  wire[2:0]     m_axi_ingr_frame_buffer_awsize  ,
  output  wire          m_axi_ingr_frame_buffer_awvalid ,
  input   wire[0:0]     m_axi_ingr_frame_buffer_bid     ,
  output  wire          m_axi_ingr_frame_buffer_bready  ,
  input   wire[1:0]     m_axi_ingr_frame_buffer_bresp   ,
  input   wire          m_axi_ingr_frame_buffer_bvalid  ,
  input   wire[511:0]   m_axi_ingr_frame_buffer_rdata   ,
  input   wire[0:0]     m_axi_ingr_frame_buffer_rid     ,
  input   wire          m_axi_ingr_frame_buffer_rlast   ,
  output  wire          m_axi_ingr_frame_buffer_rready  ,
  input   wire[1:0]     m_axi_ingr_frame_buffer_rresp   ,
  input   wire          m_axi_ingr_frame_buffer_rvalid  ,
  output  wire[511:0]   m_axi_ingr_frame_buffer_wdata   ,
  output  wire[0:0]     m_axi_ingr_frame_buffer_wid     ,
  output  wire          m_axi_ingr_frame_buffer_wlast   ,
  input   wire          m_axi_ingr_frame_buffer_wready  ,
  output  wire[63:0]    m_axi_ingr_frame_buffer_wstrb   ,
  output  wire          m_axi_ingr_frame_buffer_wvalid  ,

  output  wire          s_axis_ingr_tx_req_tready       ,
  input   wire          s_axis_ingr_tx_req_tvalid       ,
  input   wire[63:0]    s_axis_ingr_tx_req_tdata        ,

  input   wire          m_axis_ingr_tx_resp_tready      ,
  output  wire          m_axis_ingr_tx_resp_tvalid      ,
  output  wire[63:0]    m_axis_ingr_tx_resp_tdata       ,

  output  wire          s_axis_ingr_tx_data_tready      ,
  input   wire          s_axis_ingr_tx_data_tvalid      ,
  input   wire[511:0]   s_axis_ingr_tx_data_tdata       ,

  input   wire          m_axis_egr_rx_req_tready        ,
  output  wire          m_axis_egr_rx_req_tvalid        ,
  output  wire[63:0]    m_axis_egr_rx_req_tdata         ,

  output  wire          s_axis_egr_rx_resp_tready       ,
  input   wire          s_axis_egr_rx_resp_tvalid       ,
  input   wire[63:0]    s_axis_egr_rx_resp_tdata        ,

  input   wire          m_axis_egr_rx_data_tready       ,
  output  wire          m_axis_egr_rx_data_tvalid       ,
  output  wire[511:0]   m_axis_egr_rx_data_tdata        ,

  input   wire          m_axis_ingr_tx_req0_tready      ,
  output  wire          m_axis_ingr_tx_req0_tvalid      ,
  output  wire[63:0]    m_axis_ingr_tx_req0_tdata       ,

  output  wire          s_axis_ingr_tx_resp0_tready     ,
  input   wire          s_axis_ingr_tx_resp0_tvalid     ,
  input   wire[63:0]    s_axis_ingr_tx_resp0_tdata      ,

  input   wire          m_axis_ingr_tx_data0_tready     ,
  output  wire          m_axis_ingr_tx_data0_tvalid     ,
  output  wire[31:0]    m_axis_ingr_tx_data0_tdata      ,

  output  wire          s_axis_egr_rx_req0_tready       ,
  input   wire          s_axis_egr_rx_req0_tvalid       ,
  input   wire[63:0]    s_axis_egr_rx_req0_tdata        ,

  input   wire          m_axis_egr_rx_resp0_tready      ,
  output  wire          m_axis_egr_rx_resp0_tvalid      ,
  output  wire[63:0]    m_axis_egr_rx_resp0_tdata       ,

  output  wire          s_axis_egr_rx_data0_tready      ,
  input   wire          s_axis_egr_rx_data0_tvalid      ,
  input   wire[31:0]    s_axis_egr_rx_data0_tdata       ,

  input   wire          m_axis_ingr_tx_req1_tready      ,
  output  wire          m_axis_ingr_tx_req1_tvalid      ,
  output  wire[63:0]    m_axis_ingr_tx_req1_tdata       ,

  output  wire          s_axis_ingr_tx_resp1_tready     ,
  input   wire          s_axis_ingr_tx_resp1_tvalid     ,
  input   wire[63:0]    s_axis_ingr_tx_resp1_tdata      ,

  input   wire          m_axis_ingr_tx_data1_tready     ,
  output  wire          m_axis_ingr_tx_data1_tvalid     ,
  output  wire[31:0]    m_axis_ingr_tx_data1_tdata      ,

  output  wire          s_axis_egr_rx_req1_tready       ,
  input   wire          s_axis_egr_rx_req1_tvalid       ,
  input   wire[63:0]    s_axis_egr_rx_req1_tdata        ,

  input   wire          m_axis_egr_rx_resp1_tready      ,
  output  wire          m_axis_egr_rx_resp1_tvalid      ,
  output  wire[63:0]    m_axis_egr_rx_resp1_tdata       ,

  output  wire          s_axis_egr_rx_data1_tready      ,
  input   wire          s_axis_egr_rx_data1_tvalid      ,
  input   wire[31:0]    s_axis_egr_rx_data1_tdata
);

wire[17:0] w_streamif_stall;
assign w_streamif_stall[0]  = s_axis_ingr_tx_req_tvalid    & ~ s_axis_ingr_tx_req_tready;
assign w_streamif_stall[1]  = m_axis_ingr_tx_resp_tvalid   & ~ m_axis_ingr_tx_resp_tready;
assign w_streamif_stall[2]  = s_axis_ingr_tx_data_tvalid   & ~ s_axis_ingr_tx_data_tready;
assign w_streamif_stall[3]  = m_axis_ingr_tx_req0_tvalid   & ~ m_axis_ingr_tx_req0_tready;
assign w_streamif_stall[4]  = s_axis_ingr_tx_resp0_tvalid  & ~ s_axis_ingr_tx_resp0_tready;
assign w_streamif_stall[5]  = m_axis_ingr_tx_data0_tvalid  & ~ m_axis_ingr_tx_data0_tready;
assign w_streamif_stall[6]  = m_axis_ingr_tx_req1_tvalid   & ~ m_axis_ingr_tx_req1_tready;
assign w_streamif_stall[7]  = s_axis_ingr_tx_resp1_tvalid  & ~ s_axis_ingr_tx_resp1_tready;
assign w_streamif_stall[8]  = m_axis_ingr_tx_data1_tvalid  & ~ m_axis_ingr_tx_data1_tready;
assign w_streamif_stall[9]  = s_axis_egr_rx_req0_tvalid    & ~ s_axis_egr_rx_req0_tready;
assign w_streamif_stall[10] = m_axis_egr_rx_resp0_tvalid   & ~ m_axis_egr_rx_resp0_tready;
assign w_streamif_stall[11] = s_axis_egr_rx_data0_tvalid   & ~ s_axis_egr_rx_data0_tready;
assign w_streamif_stall[12] = s_axis_egr_rx_req1_tvalid    & ~ s_axis_egr_rx_req1_tready;
assign w_streamif_stall[13] = m_axis_egr_rx_resp1_tvalid   & ~ m_axis_egr_rx_resp1_tready;
assign w_streamif_stall[14] = s_axis_egr_rx_data1_tvalid   & ~ s_axis_egr_rx_data1_tready;
assign w_streamif_stall[15] = m_axis_egr_rx_req_tvalid     & ~ m_axis_egr_rx_req_tready;
assign w_streamif_stall[16] = s_axis_egr_rx_resp_tvalid    & ~ s_axis_egr_rx_resp_tready;
assign w_streamif_stall[17] = m_axis_egr_rx_data_tvalid    & ~ m_axis_egr_rx_data_tready;

  conv_adpt conv_adpt_i (
    .ap_clk                          (ap_clk                          ),
    .ap_rst_n                        (ap_rst_n                        ),
    .detect_fault                    (detect_fault                    ),
    .s_axi_control_araddr            (s_axi_control_araddr            ),
    .s_axi_control_arready           (s_axi_control_arready           ),
    .s_axi_control_arvalid           (s_axi_control_arvalid           ),
    .s_axi_control_awaddr            (s_axi_control_awaddr            ),
    .s_axi_control_awready           (s_axi_control_awready           ),
    .s_axi_control_awvalid           (s_axi_control_awvalid           ),
    .s_axi_control_bready            (s_axi_control_bready            ),
    .s_axi_control_bresp             (s_axi_control_bresp             ),
    .s_axi_control_bvalid            (s_axi_control_bvalid            ),
    .s_axi_control_rdata             (s_axi_control_rdata             ),
    .s_axi_control_rready            (s_axi_control_rready            ),
    .s_axi_control_rresp             (s_axi_control_rresp             ),
    .s_axi_control_rvalid            (s_axi_control_rvalid            ),
    .s_axi_control_wdata             (s_axi_control_wdata             ),
    .s_axi_control_wready            (s_axi_control_wready            ),
    .s_axi_control_wstrb             (s_axi_control_wstrb             ),
    .s_axi_control_wvalid            (s_axi_control_wvalid            ),
    .m_axi_gmem3_araddr              (m_axi_ingr_frame_buffer_araddr  ),
    .m_axi_gmem3_arburst             (m_axi_ingr_frame_buffer_arburst ),
    .m_axi_gmem3_arcache             (m_axi_ingr_frame_buffer_arcache ),
    .m_axi_gmem3_arid                (m_axi_ingr_frame_buffer_arid    ),
    .m_axi_gmem3_arlen               (m_axi_ingr_frame_buffer_arlen   ),
    .m_axi_gmem3_arlock              (m_axi_ingr_frame_buffer_arlock  ),
    .m_axi_gmem3_arprot              (m_axi_ingr_frame_buffer_arprot  ),
    .m_axi_gmem3_arqos               (m_axi_ingr_frame_buffer_arqos   ),
    .m_axi_gmem3_arready             (m_axi_ingr_frame_buffer_arready ),
    .m_axi_gmem3_arregion            (m_axi_ingr_frame_buffer_arregion),
    .m_axi_gmem3_arsize              (m_axi_ingr_frame_buffer_arsize  ),
    .m_axi_gmem3_arvalid             (m_axi_ingr_frame_buffer_arvalid ),
    .m_axi_gmem3_awaddr              (m_axi_ingr_frame_buffer_awaddr  ),
    .m_axi_gmem3_awburst             (m_axi_ingr_frame_buffer_awburst ),
    .m_axi_gmem3_awcache             (m_axi_ingr_frame_buffer_awcache ),
    .m_axi_gmem3_awid                (m_axi_ingr_frame_buffer_awid    ),
    .m_axi_gmem3_awlen               (m_axi_ingr_frame_buffer_awlen   ),
    .m_axi_gmem3_awlock              (m_axi_ingr_frame_buffer_awlock  ),
    .m_axi_gmem3_awprot              (m_axi_ingr_frame_buffer_awprot  ),
    .m_axi_gmem3_awqos               (m_axi_ingr_frame_buffer_awqos   ),
    .m_axi_gmem3_awready             (m_axi_ingr_frame_buffer_awready ),
    .m_axi_gmem3_awregion            (m_axi_ingr_frame_buffer_awregion),
    .m_axi_gmem3_awsize              (m_axi_ingr_frame_buffer_awsize  ),
    .m_axi_gmem3_awvalid             (m_axi_ingr_frame_buffer_awvalid ),
    .m_axi_gmem3_bid                 (m_axi_ingr_frame_buffer_bid     ),
    .m_axi_gmem3_bready              (m_axi_ingr_frame_buffer_bready  ),
    .m_axi_gmem3_bresp               (m_axi_ingr_frame_buffer_bresp   ),
    .m_axi_gmem3_bvalid              (m_axi_ingr_frame_buffer_bvalid  ),
    .m_axi_gmem3_rdata               (m_axi_ingr_frame_buffer_rdata   ),
    .m_axi_gmem3_rid                 (m_axi_ingr_frame_buffer_rid     ),
    .m_axi_gmem3_rlast               (m_axi_ingr_frame_buffer_rlast   ),
    .m_axi_gmem3_rready              (m_axi_ingr_frame_buffer_rready  ),
    .m_axi_gmem3_rresp               (m_axi_ingr_frame_buffer_rresp   ),
    .m_axi_gmem3_rvalid              (m_axi_ingr_frame_buffer_rvalid  ),
    .m_axi_gmem3_wdata               (m_axi_ingr_frame_buffer_wdata   ),
    .m_axi_gmem3_wid                 (m_axi_ingr_frame_buffer_wid     ),
    .m_axi_gmem3_wlast               (m_axi_ingr_frame_buffer_wlast   ),
    .m_axi_gmem3_wready              (m_axi_ingr_frame_buffer_wready  ),
    .m_axi_gmem3_wstrb               (m_axi_ingr_frame_buffer_wstrb   ),
    .m_axi_gmem3_wvalid              (m_axi_ingr_frame_buffer_wvalid  ),
    .s_axis_ingr_rx_req_tready       (s_axis_ingr_tx_req_tready       ),
    .s_axis_ingr_rx_req_tvalid       (s_axis_ingr_tx_req_tvalid       ),
    .s_axis_ingr_rx_req_tdata        (s_axis_ingr_tx_req_tdata        ),
    .m_axis_ingr_rx_resp_tready      (m_axis_ingr_tx_resp_tready      ),
    .m_axis_ingr_rx_resp_tvalid      (m_axis_ingr_tx_resp_tvalid      ),
    .m_axis_ingr_rx_resp_tdata       (m_axis_ingr_tx_resp_tdata       ),
    .s_axis_ingr_rx_data_tready      (s_axis_ingr_tx_data_tready      ),
    .s_axis_ingr_rx_data_tvalid      (s_axis_ingr_tx_data_tvalid      ),
    .s_axis_ingr_rx_data_tdata       (s_axis_ingr_tx_data_tdata       ),
    .m_axis_egr_tx_req_tready        (m_axis_egr_rx_req_tready        ),
    .m_axis_egr_tx_req_tvalid        (m_axis_egr_rx_req_tvalid        ),
    .m_axis_egr_tx_req_tdata         (m_axis_egr_rx_req_tdata         ),
    .s_axis_egr_tx_resp_tready       (s_axis_egr_rx_resp_tready       ),
    .s_axis_egr_tx_resp_tvalid       (s_axis_egr_rx_resp_tvalid       ),
    .s_axis_egr_tx_resp_tdata        (s_axis_egr_rx_resp_tdata        ),
    .m_axis_egr_tx_data_tready       (m_axis_egr_rx_data_tready       ),
    .m_axis_egr_tx_data_tvalid       (m_axis_egr_rx_data_tvalid       ),
    .m_axis_egr_tx_data_tdata        (m_axis_egr_rx_data_tdata        ),
    .m_axis_ingr_tx_req_0_tready     (m_axis_ingr_tx_req0_tready      ),
    .m_axis_ingr_tx_req_0_tvalid     (m_axis_ingr_tx_req0_tvalid      ),
    .m_axis_ingr_tx_req_0_tdata      (m_axis_ingr_tx_req0_tdata       ),
    .s_axis_ingr_tx_resp_0_tready    (s_axis_ingr_tx_resp0_tready     ),
    .s_axis_ingr_tx_resp_0_tvalid    (s_axis_ingr_tx_resp0_tvalid     ),
    .s_axis_ingr_tx_resp_0_tdata     (s_axis_ingr_tx_resp0_tdata      ),
    .m_axis_ingr_tx_data_0_tready    (m_axis_ingr_tx_data0_tready     ),
    .m_axis_ingr_tx_data_0_tvalid    (m_axis_ingr_tx_data0_tvalid     ),
    .m_axis_ingr_tx_data_0_tdata     (m_axis_ingr_tx_data0_tdata      ),
    .s_axis_egr_rx_req_0_tready      (s_axis_egr_rx_req0_tready       ),
    .s_axis_egr_rx_req_0_tvalid      (s_axis_egr_rx_req0_tvalid       ),
    .s_axis_egr_rx_req_0_tdata       (s_axis_egr_rx_req0_tdata        ),
    .m_axis_egr_rx_resp_0_tready     (m_axis_egr_rx_resp0_tready      ),
    .m_axis_egr_rx_resp_0_tvalid     (m_axis_egr_rx_resp0_tvalid      ),
    .m_axis_egr_rx_resp_0_tdata      (m_axis_egr_rx_resp0_tdata       ),
    .s_axis_egr_rx_data_0_tready     (s_axis_egr_rx_data0_tready      ),
    .s_axis_egr_rx_data_0_tvalid     (s_axis_egr_rx_data0_tvalid      ),
    .s_axis_egr_rx_data_0_tdata      (s_axis_egr_rx_data0_tdata       ),
    .m_axis_ingr_tx_req_1_tready     (m_axis_ingr_tx_req1_tready      ),
    .m_axis_ingr_tx_req_1_tvalid     (m_axis_ingr_tx_req1_tvalid      ),
    .m_axis_ingr_tx_req_1_tdata      (m_axis_ingr_tx_req1_tdata       ),
    .s_axis_ingr_tx_resp_1_tready    (s_axis_ingr_tx_resp1_tready     ),
    .s_axis_ingr_tx_resp_1_tvalid    (s_axis_ingr_tx_resp1_tvalid     ),
    .s_axis_ingr_tx_resp_1_tdata     (s_axis_ingr_tx_resp1_tdata      ),
    .m_axis_ingr_tx_data_1_tready    (m_axis_ingr_tx_data1_tready     ),
    .m_axis_ingr_tx_data_1_tvalid    (m_axis_ingr_tx_data1_tvalid     ),
    .m_axis_ingr_tx_data_1_tdata     (m_axis_ingr_tx_data1_tdata      ),
    .s_axis_egr_rx_req_1_tready      (s_axis_egr_rx_req1_tready       ),
    .s_axis_egr_rx_req_1_tvalid      (s_axis_egr_rx_req1_tvalid       ),
    .s_axis_egr_rx_req_1_tdata       (s_axis_egr_rx_req1_tdata        ),
    .m_axis_egr_rx_resp_1_tready     (m_axis_egr_rx_resp1_tready      ),
    .m_axis_egr_rx_resp_1_tvalid     (m_axis_egr_rx_resp1_tvalid      ),
    .m_axis_egr_rx_resp_1_tdata      (m_axis_egr_rx_resp1_tdata       ),
    .s_axis_egr_rx_data_1_tready     (s_axis_egr_rx_data1_tready      ),
    .s_axis_egr_rx_data_1_tvalid     (s_axis_egr_rx_data1_tvalid      ),
    .s_axis_egr_rx_data_1_tdata      (s_axis_egr_rx_data1_tdata       ),
    .streamif_stall                  (w_streamif_stall                )
  );

endmodule // conversion_adaptor

`default_nettype wire
