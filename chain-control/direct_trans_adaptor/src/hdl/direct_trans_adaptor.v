/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`default_nettype none

module direct_trans_adaptor (
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi_control:s_axis_ingr_rx_req:m_axis_ingr_rx_resp:s_axis_ingr_rx_data:m_axis_egr_tx_req:s_axis_egr_tx_resp:m_axis_egr_tx_data:m_axis_ingr_tx_req:s_axis_ingr_tx_resp:m_axis_ingr_tx_data:s_axis_egr_rx_req:m_axis_egr_rx_resp:s_axis_egr_rx_data" *)
    input wire ap_clk,
    input wire ap_rst_n,

    output wire detect_fault,

    input  wire [11:0] s_axi_control_ARADDR,
    output wire        s_axi_control_ARREADY,
    input  wire        s_axi_control_ARVALID,
    input  wire [11:0] s_axi_control_AWADDR,
    output wire        s_axi_control_AWREADY,
    input  wire        s_axi_control_AWVALID,
    input  wire        s_axi_control_BREADY,
    output wire [ 1:0] s_axi_control_BRESP,
    output wire        s_axi_control_BVALID,
    output wire [31:0] s_axi_control_RDATA,
    input  wire        s_axi_control_RREADY,
    output wire [ 1:0] s_axi_control_RRESP,
    output wire        s_axi_control_RVALID,
    input  wire [31:0] s_axi_control_WDATA,
    output wire        s_axi_control_WREADY,
    input  wire [ 3:0] s_axi_control_WSTRB,
    input  wire        s_axi_control_WVALID,

    output wire        s_axis_ingr_rx_req_TREADY,
    input  wire        s_axis_ingr_rx_req_TVALID,
    input  wire [63:0] s_axis_ingr_rx_req_TDATA,

    input  wire        m_axis_ingr_rx_resp_TREADY,
    output wire        m_axis_ingr_rx_resp_TVALID,
    output wire [63:0] m_axis_ingr_rx_resp_TDATA,

    output wire         s_axis_ingr_rx_data_TREADY,
    input  wire         s_axis_ingr_rx_data_TVALID,
    input  wire [511:0] s_axis_ingr_rx_data_TDATA,

    input  wire        m_axis_egr_tx_req_TREADY,
    output wire        m_axis_egr_tx_req_TVALID,
    output wire [63:0] m_axis_egr_tx_req_TDATA,

    output wire        s_axis_egr_tx_resp_TREADY,
    input  wire        s_axis_egr_tx_resp_TVALID,
    input  wire [63:0] s_axis_egr_tx_resp_TDATA,

    input  wire         m_axis_egr_tx_data_TREADY,
    output wire         m_axis_egr_tx_data_TVALID,
    output wire [511:0] m_axis_egr_tx_data_TDATA,

    input  wire        m_axis_ingr_tx_req_TREADY,
    output wire        m_axis_ingr_tx_req_TVALID,
    output wire [63:0] m_axis_ingr_tx_req_TDATA,

    output wire        s_axis_ingr_tx_resp_TREADY,
    input  wire        s_axis_ingr_tx_resp_TVALID,
    input  wire [63:0] s_axis_ingr_tx_resp_TDATA,

    input  wire         m_axis_ingr_tx_data_TREADY,
    output wire         m_axis_ingr_tx_data_TVALID,
    output wire [511:0] m_axis_ingr_tx_data_TDATA,

    output wire        s_axis_egr_rx_req_TREADY,
    input  wire        s_axis_egr_rx_req_TVALID,
    input  wire [63:0] s_axis_egr_rx_req_TDATA,

    input  wire        m_axis_egr_rx_resp_TREADY,
    output wire        m_axis_egr_rx_resp_TVALID,
    output wire [63:0] m_axis_egr_rx_resp_TDATA,

    output wire         s_axis_egr_rx_data_TREADY,
    input  wire         s_axis_egr_rx_data_TVALID,
    input  wire [511:0] s_axis_egr_rx_data_TDATA
);

  wire [11:0] streamif_stall;

  assign streamif_stall = {(~m_axis_egr_tx_data_TREADY  & m_axis_egr_tx_data_TVALID),
                           (~s_axis_egr_tx_resp_TREADY  & s_axis_egr_tx_resp_TVALID),
                           (~m_axis_egr_tx_req_TREADY   & m_axis_egr_tx_req_TVALID),
                           (~s_axis_egr_rx_data_TREADY  & s_axis_egr_rx_data_TVALID),
                           (~m_axis_egr_rx_resp_TREADY  & m_axis_egr_rx_resp_TVALID),
                           (~s_axis_egr_rx_req_TREADY   & s_axis_egr_rx_req_TVALID),
                           (~m_axis_ingr_tx_data_TREADY & m_axis_ingr_tx_data_TVALID),
                           (~s_axis_ingr_tx_resp_TREADY & s_axis_ingr_tx_resp_TVALID),
                           (~m_axis_ingr_tx_req_TREADY  & m_axis_ingr_tx_req_TVALID),
                           (~s_axis_ingr_rx_data_TREADY & s_axis_ingr_rx_data_TVALID),
                           (~m_axis_ingr_rx_resp_TREADY & m_axis_ingr_rx_resp_TVALID),
                           (~s_axis_ingr_rx_req_TREADY  & s_axis_ingr_rx_req_TVALID)};

  direct_trans_adaptor_bd direct_trans_adaptor_bd_i
       (.ap_clk(ap_clk),
        .ap_rst_n(ap_rst_n),
        .detect_fault(detect_fault),
        .streamif_stall(streamif_stall),
        .m_axis_egr_rx_resp_tdata(m_axis_egr_rx_resp_TDATA),
        .m_axis_egr_rx_resp_tready(m_axis_egr_rx_resp_TREADY),
        .m_axis_egr_rx_resp_tvalid(m_axis_egr_rx_resp_TVALID),
        .m_axis_egr_tx_data_tdata(m_axis_egr_tx_data_TDATA),
        .m_axis_egr_tx_data_tready(m_axis_egr_tx_data_TREADY),
        .m_axis_egr_tx_data_tvalid(m_axis_egr_tx_data_TVALID),
        .m_axis_egr_tx_req_tdata(m_axis_egr_tx_req_TDATA),
        .m_axis_egr_tx_req_tready(m_axis_egr_tx_req_TREADY),
        .m_axis_egr_tx_req_tvalid(m_axis_egr_tx_req_TVALID),
        .m_axis_ingr_rx_resp_tdata(m_axis_ingr_rx_resp_TDATA),
        .m_axis_ingr_rx_resp_tready(m_axis_ingr_rx_resp_TREADY),
        .m_axis_ingr_rx_resp_tvalid(m_axis_ingr_rx_resp_TVALID),
        .m_axis_ingr_tx_data_tdata(m_axis_ingr_tx_data_TDATA),
        .m_axis_ingr_tx_data_tready(m_axis_ingr_tx_data_TREADY),
        .m_axis_ingr_tx_data_tvalid(m_axis_ingr_tx_data_TVALID),
        .m_axis_ingr_tx_req_tdata(m_axis_ingr_tx_req_TDATA),
        .m_axis_ingr_tx_req_tready(m_axis_ingr_tx_req_TREADY),
        .m_axis_ingr_tx_req_tvalid(m_axis_ingr_tx_req_TVALID),
        .s_axi_control_araddr(s_axi_control_ARADDR),
        .s_axi_control_arready(s_axi_control_ARREADY),
        .s_axi_control_arvalid(s_axi_control_ARVALID),
        .s_axi_control_awaddr(s_axi_control_AWADDR),
        .s_axi_control_awready(s_axi_control_AWREADY),
        .s_axi_control_awvalid(s_axi_control_AWVALID),
        .s_axi_control_bready(s_axi_control_BREADY),
        .s_axi_control_bresp(s_axi_control_BRESP),
        .s_axi_control_bvalid(s_axi_control_BVALID),
        .s_axi_control_rdata(s_axi_control_RDATA),
        .s_axi_control_rready(s_axi_control_RREADY),
        .s_axi_control_rresp(s_axi_control_RRESP),
        .s_axi_control_rvalid(s_axi_control_RVALID),
        .s_axi_control_wdata(s_axi_control_WDATA),
        .s_axi_control_wready(s_axi_control_WREADY),
        .s_axi_control_wstrb(s_axi_control_WSTRB),
        .s_axi_control_wvalid(s_axi_control_WVALID),
        .s_axis_egr_rx_data_tdata(s_axis_egr_rx_data_TDATA),
        .s_axis_egr_rx_data_tready(s_axis_egr_rx_data_TREADY),
        .s_axis_egr_rx_data_tvalid(s_axis_egr_rx_data_TVALID),
        .s_axis_egr_rx_req_tdata(s_axis_egr_rx_req_TDATA),
        .s_axis_egr_rx_req_tready(s_axis_egr_rx_req_TREADY),
        .s_axis_egr_rx_req_tvalid(s_axis_egr_rx_req_TVALID),
        .s_axis_egr_tx_resp_tdata(s_axis_egr_tx_resp_TDATA),
        .s_axis_egr_tx_resp_tready(s_axis_egr_tx_resp_TREADY),
        .s_axis_egr_tx_resp_tvalid(s_axis_egr_tx_resp_TVALID),
        .s_axis_ingr_rx_data_tdata(s_axis_ingr_rx_data_TDATA),
        .s_axis_ingr_rx_data_tready(s_axis_ingr_rx_data_TREADY),
        .s_axis_ingr_rx_data_tvalid(s_axis_ingr_rx_data_TVALID),
        .s_axis_ingr_rx_req_tdata(s_axis_ingr_rx_req_TDATA),
        .s_axis_ingr_rx_req_tready(s_axis_ingr_rx_req_TREADY),
        .s_axis_ingr_rx_req_tvalid(s_axis_ingr_rx_req_TVALID),
        .s_axis_ingr_tx_resp_tdata(s_axis_ingr_tx_resp_TDATA),
        .s_axis_ingr_tx_resp_tready(s_axis_ingr_tx_resp_TREADY),
        .s_axis_ingr_tx_resp_tvalid(s_axis_ingr_tx_resp_TVALID));

endmodule

`default_nettype wire
