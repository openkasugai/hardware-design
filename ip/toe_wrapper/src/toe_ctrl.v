/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module toe_ctrl #(
    parameter AW = 16,
    parameter DW_LOG = 9,
    parameter CH_NUM_LOG = 4,
    parameter BURST_BITS = 6,
    parameter SESSION_NUM_LOG = 6,
    parameter FRAME_MAX = 8,
    parameter MAX_INFLIGHT = 2,
    parameter TX_FIFO_DL = 9,
    parameter TX_AUX_FIFO_DL = 4,
    parameter ACTIVATE_MAGIC = 32'h56544341, // ACTV
    parameter CREDIT_MAGIC = 32'h54445243  // CRDT
    ) (
    // reg
    input [AW-1:0]               axil_araddr,
    input                        axil_arvalid,
    output                       axil_arready,
    output [31:0]                axil_rdata,
    output [1:0]                 axil_rresp,
    output                       axil_rvalid,
    input                        axil_rready,
    input [AW-1:0]               axil_awaddr,
    input                        axil_awvalid,
    output                       axil_awready,
    input [31:0]                 axil_wdata,
    input                        axil_wvalid,
    output                       axil_wready,
    output [1:0]                 axil_bresp,
    output                       axil_bvalid,
    input                        axil_bready,

    // tx
    input [(1<<DW_LOG)-1:0]      tx_in_tdata,
    input [(1<<(DW_LOG-3))-1:0]  tx_in_tkeep,
    input [CH_NUM_LOG-1:0]       tx_in_tuser,
    input                        tx_in_tlast,
    input                        tx_in_sop,
    input                        tx_in_eop,
    input [BURST_BITS-1:0]       tx_in_burst, // 0-origin -> 1-origin
    input [DW_LOG-4:0]           tx_in_last_cnt, // 0-origin -> 1->origin
    input                        tx_in_tvalid,
    output                       tx_in_tready,

    output [(1<<DW_LOG)-1:0]     tx_toe_tdata,
    output [(1<<(DW_LOG-3))-1:0] tx_toe_tkeep,
    output [SESSION_NUM_LOG-1:0] tx_toe_tuser,
    output                       tx_toe_tlast,
    output                       tx_toe_tvalid,
    input                        tx_toe_tready,

    output [31:0]                tx_toe_cmd_tdata,
    output                       tx_toe_cmd_tvalid,
    input                        tx_toe_cmd_tready,

    input [87:0]                 tx_toe_rsp_tdata,
    input                        tx_toe_rsp_tvalid,
    output                       tx_toe_rsp_tready,

    // rx
    input [(1<<DW_LOG)-1:0]      rx_toe_tdata,
    input [(1<<(DW_LOG-3))-1:0]  rx_toe_tkeep,
    input [SESSION_NUM_LOG-1:0]  rx_toe_tuser,
    input                        rx_toe_tlast,
    input                        rx_toe_tvalid,
    output                       rx_toe_tready,

    output [(1<<DW_LOG)-1:0]     rx_out_tdata,
    output [(1<<(DW_LOG-3))-1:0] rx_out_tkeep,
    output [CH_NUM_LOG-1:0]      rx_out_tuser,
    output                       rx_out_tlast, // eop
    output                       rx_out_eof,
    output                       rx_out_tvalid,
    input                        rx_out_tready,

    // tx frame
    output [31:0]                tx_frame_info_out_tdata, // tx_frame size
    output [CH_NUM_LOG-1:0]      tx_frame_info_out_tuser,
    output                       tx_frame_info_out_tvalid,
    input                        tx_frame_info_out_tready,

    input [31:0]                 tx_frame_info_tdata, // tx_frame size
    input [CH_NUM_LOG-1:0]       tx_frame_info_tuser,
    input                        tx_frame_info_tvalid,
    output                       tx_frame_info_tready,

    // rx frame
    output [31:0]                rx_frame_info_out_tdata, // rx_frame size
    output [CH_NUM_LOG-1:0]      rx_frame_info_out_tuser,
    output                       rx_frame_info_out_tvalid,
    input                        rx_frame_info_out_tready,

    input [31:0]                 rx_frame_info_tdata, // rx_frame size
    input [CH_NUM_LOG-1:0]       rx_frame_info_tuser,
    input                        rx_frame_info_tvalid,
    output                       rx_frame_info_tready,

    input                        clk,
    input                        resetn
    );

   localparam DW = 1 << DW_LOG;
   localparam KW_LOG = DW_LOG - 3;
   localparam KW = 1 << KW_LOG;
   localparam CH_NUM = 1 << CH_NUM_LOG;
   localparam SESSION_NUM = 1 << SESSION_NUM_LOG;

   wire [DW-1:0]                     rx_tx_tdata;
   wire [KW-1:0]                     rx_tx_tkeep;
   wire [CH_NUM_LOG-1:0]             rx_tx_tuser;
   wire                              rx_tx_tlast; // eop
   wire                              rx_tx_tvalid;
   wire                              rx_tx_tready;

   wire [DW-1:0]                     tx_tdata;
   wire [KW-1:0]                     tx_tkeep;
   wire [SESSION_NUM_LOG-1:0]        tx_tuser;
   wire [BURST_BITS-1:0]             tx_burst;
   wire [KW_LOG-1:0]                 tx_last_cnts;
   wire                              tx_tlast;
   wire                              tx_tvalid;
   wire                              tx_tready;

   wire [CH_NUM-1:0]                 tx_ch_enables;
   wire [CH_NUM-1:0]                 tx_ch_valids;
   wire [CH_NUM-1:0]                 tx_ch_actives;
   wire [CH_NUM-1:0]                 tx_ch_readys;
   wire [SESSION_NUM_LOG*CH_NUM-1:0] tx_ch_session_ids;
   wire [32*CH_NUM-1:0]              tx_ch_frame_sizes;

   wire [CH_NUM-1:0]                 rx_ch_enables;
   wire [CH_NUM-1:0]                 rx_ch_valids;
   wire [CH_NUM-1:0]                 rx_ch_activates;
   wire [CH_NUM-1:0]                 rx_ch_actives;
   wire [CH_NUM-1:0]                 rx_ch_readys;
   wire [SESSION_NUM_LOG*CH_NUM-1:0] rx_ch_session_ids;
   wire [32*CH_NUM-1:0]              rx_ch_frame_sizes;
   wire [16*CH_NUM-1:0]              rx_ch_credit_max;
   wire [16*CH_NUM-1:0]              rx_ch_credit_cur;

   wire [SESSION_NUM_LOG-1:0]        tx_credit_inc_session_id;
   wire                              tx_credit_inc;
   wire [SESSION_NUM_LOG-1:0]        tx_credit_dec_session_id;
   wire                              tx_credit_dec;
   wire [SESSION_NUM_LOG-1:0]        rx_credit_inc_session_id;
   wire                              rx_credit_inc;
   wire [SESSION_NUM_LOG-1:0]        rx_credit_dec_session_id;
   wire                              rx_credit_dec;

   wire [SESSION_NUM_LOG-1:0]        find_ch_session_id;
   wire                              find_ch_valid;
   wire [CH_NUM_LOG-1:0]             find_ch_id;
   wire                              find_ch_id_tx_valid;
   wire                              find_ch_id_rx_valid;
   wire                              find_ch_id_invalid;

   wire [SESSION_NUM_LOG-1:0]        connected_session_id;
   wire [31:0]                       connected_ip;
   wire [15:0]                       connected_port;
   wire                              connected_valid;
   wire                              connected_out_found;
   wire                              connected_out_valid;

   wire [SESSION_NUM_LOG-1:0]        activate_done_session_id;
   wire                              activate_done;
   wire [SESSION_NUM_LOG-1:0]        close_session_id;
   wire                              close_valid;

   wire [15:0]                       cp_config_credit_max;
   wire [31:0]                       cp_config_frame_size;
   wire [SESSION_NUM_LOG-1:0]        cp_config_session_id;
   wire                              cp_config_valid;

   wire                              invalidate_activate;

   toe_ctrl_regs #(
       .AW ( AW ),
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .SESSION_NUM_LOG ( SESSION_NUM_LOG )
   ) regs (
       .axil_araddr ( axil_araddr ),
       .axil_arvalid ( axil_arvalid ),
       .axil_arready ( axil_arready ),
       .axil_rdata ( axil_rdata ),
       .axil_rresp ( axil_rresp ),
       .axil_rvalid ( axil_rvalid ),
       .axil_rready ( axil_rready ),
       .axil_awaddr ( axil_awaddr ),
       .axil_awvalid ( axil_awvalid ),
       .axil_awready ( axil_awready ),
       .axil_wdata ( axil_wdata ),
       .axil_wvalid ( axil_wvalid ),
       .axil_wready ( axil_wready ),
       .axil_bresp ( axil_bresp ),
       .axil_bvalid ( axil_bvalid ),
       .axil_bready ( axil_bready ),
       .tx_ch_enables ( tx_ch_enables ),
       .tx_ch_valids ( tx_ch_valids ),
       .tx_ch_actives ( tx_ch_actives ),
       .tx_ch_readys ( tx_ch_readys ),
       .tx_ch_session_ids ( tx_ch_session_ids ),
       .tx_ch_frame_sizes ( tx_ch_frame_sizes ),
       .tx_ch_credit_max (  ),
       .tx_ch_credit_cur (  ),
       .tx_ch_ip_bases (  ),
       .tx_ch_ip_masks (  ),
       .tx_ch_port_bases (  ),
       .tx_ch_port_masks (  ),
       .rx_ch_enables ( rx_ch_enables ),
       .rx_ch_valids ( rx_ch_valids ),
       .rx_ch_activates ( rx_ch_activates ),
       .rx_ch_actives ( rx_ch_actives ),
       .rx_ch_readys ( rx_ch_readys ),
       .rx_ch_session_ids ( rx_ch_session_ids ),
       .rx_ch_frame_sizes ( rx_ch_frame_sizes ),
       .rx_ch_credit_max ( rx_ch_credit_max ),
       .rx_ch_credit_cur ( rx_ch_credit_cur ),
       .rx_ch_ip_bases (  ),
       .rx_ch_ip_masks (  ),
       .rx_ch_port_bases (  ),
       .rx_ch_port_masks (  ),
       .invalidate_activate ( invalidate_activate ),
       .activate_done_session_id ( activate_done_session_id ),
       .activate_done ( activate_done ),
       .close_session_id ( close_session_id ),
       .close_valid ( close_valid ),
       .connected_session_id ( connected_session_id ),
       .connected_ip ( connected_ip ),
       .connected_port ( connected_port ),
       .connected_valid ( connected_valid ),
       .connected_out_found ( connected_out_found ),
       .connected_out_valid ( connected_out_valid ),
       .find_ch_session_id ( find_ch_session_id ),
       .find_ch_valid ( find_ch_valid ),
       .find_ch_id ( find_ch_id ),
       .find_ch_id_tx_valid ( find_ch_id_tx_valid ),
       .find_ch_id_rx_valid ( find_ch_id_rx_valid ),
       .find_ch_id_invalid ( find_ch_id_invalid ),
       .cp_config_credit_max ( cp_config_credit_max ),
       .cp_config_frame_size ( cp_config_frame_size ),
       .cp_config_session_id ( cp_config_session_id ),
       .cp_config_valid ( cp_config_valid ),
       .tx_credit_inc_session_id ( tx_credit_inc_session_id ),
       .tx_credit_inc ( tx_credit_inc ),
       .rx_credit_inc_session_id ( rx_credit_inc_session_id ),
       .rx_credit_inc ( rx_credit_inc ),
       .tx_credit_dec_session_id ( tx_credit_dec_session_id ),
       .tx_credit_dec ( tx_credit_dec ),
       .rx_credit_dec_session_id ( rx_credit_dec_session_id ),
       .rx_credit_dec ( rx_credit_dec ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   toe_ctrl_tx #(
       .DW_LOG ( DW_LOG ),
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .BURST_BITS ( BURST_BITS ),
       .SESSION_NUM_LOG ( SESSION_NUM_LOG ),
       .FRAME_MAX ( FRAME_MAX ),
       .MAX_INFLIGHT ( MAX_INFLIGHT ),
       .TX_FIFO_DL ( TX_FIFO_DL ),
       .TX_AUX_FIFO_DL ( TX_AUX_FIFO_DL ),
       .ACTIVATE_MAGIC ( ACTIVATE_MAGIC ),
       .CREDIT_MAGIC ( CREDIT_MAGIC )
   ) tx_ctrl (
       .tx_in_tdata ( tx_in_tdata ),
       .tx_in_tkeep ( tx_in_tkeep ),
       .tx_in_tuser ( tx_in_tuser ),
       .tx_in_tlast ( tx_in_tlast ),
       .tx_in_sop ( tx_in_sop ),
       .tx_in_eop ( tx_in_eop ),
       .tx_in_burst ( tx_in_burst ),
       .tx_in_last_cnt ( tx_in_last_cnt ),
       .tx_in_tvalid ( tx_in_tvalid ),
       .tx_in_tready ( tx_in_tready ),
       .tx_toe_tdata ( tx_toe_tdata ),
       .tx_toe_tkeep ( tx_toe_tkeep ),
       .tx_toe_tuser ( tx_toe_tuser ),
       .tx_toe_tlast ( tx_toe_tlast ),
       .tx_toe_tvalid ( tx_toe_tvalid ),
       .tx_toe_tready ( tx_toe_tready ),
       .tx_toe_cmd_tdata ( tx_toe_cmd_tdata ),
       .tx_toe_cmd_tvalid ( tx_toe_cmd_tvalid ),
       .tx_toe_cmd_tready ( tx_toe_cmd_tready ),
       .tx_toe_rsp_tdata ( tx_toe_rsp_tdata ),
       .tx_toe_rsp_tvalid ( tx_toe_rsp_tvalid ),
       .tx_toe_rsp_tready ( tx_toe_rsp_tready ),
       .rx_tx_tdata ( rx_tx_tdata ),
       .rx_tx_tkeep ( rx_tx_tkeep ),
       .rx_tx_tuser ( rx_tx_tuser ),
       .rx_tx_tlast ( rx_tx_tlast ),
       .rx_tx_tvalid ( rx_tx_tvalid ),
       .rx_tx_tready ( rx_tx_tready ),
       .tx_tdata ( tx_tdata ),
       .tx_tkeep ( tx_tkeep ),
       .tx_tuser ( tx_tuser ),
       .tx_burst ( tx_burst ),
       .tx_last_cnts ( tx_last_cnts ),
       .tx_tlast ( tx_tlast ),
       .tx_tvalid ( tx_tvalid ),
       .tx_tready ( tx_tready ),
       .tx_ch_valids ( tx_ch_valids ),
       .tx_ch_actives ( tx_ch_actives ),
       .tx_ch_readys ( tx_ch_readys ),
       .tx_ch_session_ids ( tx_ch_session_ids ),
       .tx_ch_frame_sizes ( tx_ch_frame_sizes ),
       .invalidate_activate ( invalidate_activate ),
       .connected_session_id ( connected_session_id ),
       .connected_ip ( connected_ip ),
       .connected_port ( connected_port ),
       .connected_valid ( connected_valid ),
       .connected_out_found ( connected_out_found ),
       .connected_out_valid ( connected_out_valid ),
       .close_session_id ( close_session_id ),
       .close_valid ( close_valid ),
       .cp_config_credit_max ( cp_config_credit_max ),
       .cp_config_frame_size ( cp_config_frame_size ),
       .cp_config_session_id ( cp_config_session_id ),
       .cp_config_valid ( cp_config_valid ),
       .tx_credit_inc_session_id ( tx_credit_inc_session_id ),
       .tx_credit_inc ( tx_credit_inc ),
       .tx_credit_dec_session_id ( tx_credit_dec_session_id ),
       .tx_credit_dec ( tx_credit_dec ),
       .frame_info_out_tdata ( tx_frame_info_out_tdata ),
       .frame_info_out_tuser ( tx_frame_info_out_tuser ),
       .frame_info_out_tvalid ( tx_frame_info_out_tvalid ),
       .frame_info_out_tready ( tx_frame_info_out_tready ),
       .frame_info_tdata ( tx_frame_info_tdata ),
       .frame_info_tuser ( tx_frame_info_tuser ),
       .frame_info_tvalid ( tx_frame_info_tvalid ),
       .frame_info_tready ( tx_frame_info_tready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

   toe_ctrl_rx #(
       .DW_LOG ( DW_LOG ),
       .CH_NUM_LOG ( CH_NUM_LOG ),
       .BURST_BITS ( BURST_BITS ),
       .SESSION_NUM_LOG ( SESSION_NUM_LOG ),
       .FRAME_MAX ( FRAME_MAX ),
       .MAX_INFLIGHT ( MAX_INFLIGHT ),
       .ACTIVATE_MAGIC ( ACTIVATE_MAGIC ),
       .CREDIT_MAGIC ( CREDIT_MAGIC )
   ) rx_ctrl (
       .rx_toe_tdata ( rx_toe_tdata ),
       .rx_toe_tkeep ( rx_toe_tkeep ),
       .rx_toe_tuser ( rx_toe_tuser ),
       .rx_toe_tlast ( rx_toe_tlast ),
       .rx_toe_tvalid ( rx_toe_tvalid ),
       .rx_toe_tready ( rx_toe_tready ),
       .rx_tx_tdata ( rx_tx_tdata ),
       .rx_tx_tkeep ( rx_tx_tkeep ),
       .rx_tx_tuser ( rx_tx_tuser ),
       .rx_tx_tlast ( rx_tx_tlast ),
       .rx_tx_tvalid ( rx_tx_tvalid ),
       .rx_tx_tready ( rx_tx_tready ),
       .tx_tdata ( tx_tdata ),
       .tx_tkeep ( tx_tkeep ),
       .tx_tuser ( tx_tuser ),
       .tx_burst ( tx_burst ),
       .tx_last_cnts ( tx_last_cnts ),
       .tx_tlast ( tx_tlast ),
       .tx_tvalid ( tx_tvalid ),
       .tx_tready ( tx_tready ),
       .rx_out_tdata ( rx_out_tdata ),
       .rx_out_tkeep ( rx_out_tkeep ),
       .rx_out_tuser ( rx_out_tuser ),
       .rx_out_tlast ( rx_out_tlast ),
       .rx_out_eof ( rx_out_eof ),
       .rx_out_tvalid ( rx_out_tvalid ),
       .rx_out_tready ( rx_out_tready ),
       .frame_info_out_tdata ( rx_frame_info_out_tdata ),
       .frame_info_out_tuser ( rx_frame_info_out_tuser ),
       .frame_info_out_tvalid ( rx_frame_info_out_tvalid ),
       .frame_info_out_tready ( rx_frame_info_out_tready ),
       .frame_info_tdata ( rx_frame_info_tdata ),
       .frame_info_tuser ( rx_frame_info_tuser ),
       .frame_info_tvalid ( rx_frame_info_tvalid ),
       .frame_info_tready ( rx_frame_info_tready ),
       .rx_ch_valids ( rx_ch_valids ),
       .rx_ch_activates ( rx_ch_activates ),
       .rx_ch_actives ( rx_ch_actives ),
       .rx_ch_readys ( rx_ch_readys ),
       .rx_ch_session_ids ( rx_ch_session_ids ),
       .rx_ch_frame_sizes ( rx_ch_frame_sizes ),
       .rx_ch_credit_max ( rx_ch_credit_max ),
       .rx_ch_credit_cur ( rx_ch_credit_cur ),
       .rx_credit_inc_session_id ( rx_credit_inc_session_id ),
       .rx_credit_inc ( rx_credit_inc ),
       .rx_credit_dec_session_id ( rx_credit_dec_session_id ),
       .rx_credit_dec ( rx_credit_dec ),
       .find_ch_session_id ( find_ch_session_id ),
       .find_ch_valid ( find_ch_valid ),
       .find_ch_id ( find_ch_id ),
       .find_ch_id_tx_valid ( find_ch_id_tx_valid ),
       .find_ch_id_rx_valid ( find_ch_id_rx_valid ),
       .find_ch_id_invalid ( find_ch_id_invalid ),
       .activate_done_session_id ( activate_done_session_id ),
       .activate_done ( activate_done ),
       .clk ( clk ),
       .resetn ( resetn )
   );

endmodule
