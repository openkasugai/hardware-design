/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

module ingr_event(
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF rcv_nxt_update_req_estab_0:rcv_nxt_update_req_estab_1:rcv_nxt_update_req_receive_0:rcv_nxt_update_req_receive_1:ingr_usr_read_update_req:ingr_payload_len:ingr_start:ingr_done:ingr_receive" *)
  input   wire        ap_clk,
  input   wire        ap_rst_n,
  input   wire[63:0]  rcv_nxt_update_req_estab_0_tdata,
  input   wire        rcv_nxt_update_req_estab_0_tvalid,
  output  wire        rcv_nxt_update_req_estab_0_tready,
  input   wire[63:0]  rcv_nxt_update_req_estab_1_tdata,
  input   wire        rcv_nxt_update_req_estab_1_tvalid,
  output  wire        rcv_nxt_update_req_estab_1_tready,
  input   wire[63:0]  rcv_nxt_update_req_receive_0_tdata,
  input   wire        rcv_nxt_update_req_receive_0_tvalid,
  output  wire        rcv_nxt_update_req_receive_0_tready,
  input   wire[63:0]  rcv_nxt_update_req_receive_1_tdata,
  input   wire        rcv_nxt_update_req_receive_1_tvalid,
  output  wire        rcv_nxt_update_req_receive_1_tready,
  input   wire[63:0]  ingr_usr_read_update_req_tdata,
  input   wire        ingr_usr_read_update_req_tvalid,
  output  wire        ingr_usr_read_update_req_tready,
  input   wire[39:0]  ingr_payload_len_tdata,
  input   wire        ingr_payload_len_tvalid,
  output  wire        ingr_payload_len_tready,
  input   wire[7:0]   ingr_start_tdata,
  input   wire        ingr_start_tvalid,
  output  wire        ingr_start_tready,
  output  wire[7:0]   ingr_done_tdata,
  output  wire        ingr_done_tvalid,
  input   wire        ingr_done_tready,
  output  wire[135:0] ingr_receive_tdata,
  output  wire        ingr_receive_tvalid,
  input   wire        ingr_receive_tready,
  input   wire[47:0]  header_buff_usage,
  input   wire        header_buff_usage_ap_vld,
  output  wire[47:0]  stat_ingr_rcv_data,
  output  wire        stat_ingr_rcv_data_vld,
  output  wire[15:0]  ingr_rcv_detect_fault,
  output  wire        ingr_rcv_detect_fault_vld,
  input   wire[7:0]   ingr_rcv_insert_fault,
  output  wire[31:0]  rcv_nxt_update_resp_count,
  output  wire[31:0]  usr_read_update_resp_count,
  output  wire[31:0]  rx_head_update_resp_count,
  output  wire[31:0]  rx_tail_update_resp_count,
  input   wire[15:0]  dbg_sel_session,
  input   wire[15:0]  stat_sel_session,
  output  wire[1:0]   extif_session_status,
  output  wire[127:0] ingr_last_ptr
);

  wire[63:0]  w_estab_0_tdata;
  wire        w_estab_0_tvalid;
  wire        w_estab_0_tready;
  wire[63:0]  w_estab_1_tdata;
  wire        w_estab_1_tvalid;
  wire        w_estab_1_tready;
  wire[63:0]  w_rcv_nxt_upd_0_tdata;
  wire        w_rcv_nxt_upd_0_tvalid;
  wire        w_rcv_nxt_upd_0_tready;
  wire[63:0]  w_rcv_nxt_upd_1_tdata;
  wire        w_rcv_nxt_upd_1_tvalid;
  wire        w_rcv_nxt_upd_1_tready;
  wire[63:0]  w_usr_read_upd_tdata;
  wire        w_usr_read_upd_tvalid;
  wire        w_usr_read_upd_tready;
  wire[39:0]  w_payload_len_tdata;
  wire        w_payload_len_tvalid;
  wire        w_payload_len_tready;
  wire[127:0] w_rx_hp_upd_tdata;
  wire        w_rx_hp_upd_tvalid;
  wire        w_rx_hp_upd_tready;
  wire[127:0] w_rx_tp_upd_tdata;
  wire        w_rx_tp_upd_tvalid;
  wire        w_rx_tp_upd_tready;
  wire[7:0]   w_start_tdata;
  wire        w_start_tvalid;
  wire        w_start_tready;
  wire[7:0]   w_done_tdata;
  wire        w_done_tvalid;
  wire        w_done_tready;
  wire[135:0] w_receive_tdata;
  wire        w_receive_tvalid;
  wire        w_receive_tready;

  // Reset Synchronization
  reg r_rst_n_sync, r_rst_n;
  always @(posedge ap_clk or negedge ap_rst_n) begin
    if ( ! ap_rst_n) begin
      r_rst_n_sync <= 1'b0;
      r_rst_n <= 1'b0;
    end else begin
      r_rst_n_sync <= 1'b1;
      r_rst_n <= r_rst_n_sync;
    end
  end

  // Register Slice
  axis_reg_slice #(
    .DATA_WIDTH(64) // Data Bus Width
  ) u_reg_estab_0 (
    .resetn     (r_rst_n                          ), // input
    .ap_clk     (ap_clk                           ), // input
    .in_tdata   (rcv_nxt_update_req_estab_0_tdata ), // input  [DATA_WIDTH-1:0]
    .in_tvalid  (rcv_nxt_update_req_estab_0_tvalid), // input
    .in_tready  (rcv_nxt_update_req_estab_0_tready), // output
    .out_tdata  (w_estab_0_tdata                  ), // output [DATA_WIDTH-1:0]
    .out_tvalid (w_estab_0_tvalid                 ), // output
    .out_tready (w_estab_0_tready                 )  // input
  );

  // Register Slice
  axis_reg_slice #(
    .DATA_WIDTH(64) // Data Bus Width
  ) u_reg_estab_1 (
    .resetn     (r_rst_n                          ), // input
    .ap_clk     (ap_clk                           ), // input
    .in_tdata   (rcv_nxt_update_req_estab_1_tdata ), // input  [DATA_WIDTH-1:0]
    .in_tvalid  (rcv_nxt_update_req_estab_1_tvalid), // input
    .in_tready  (rcv_nxt_update_req_estab_1_tready), // output
    .out_tdata  (w_estab_1_tdata                  ), // output [DATA_WIDTH-1:0]
    .out_tvalid (w_estab_1_tvalid                 ), // output
    .out_tready (w_estab_1_tready                 )  // input
  );

  // Register Slice
  axis_reg_slice #(
    .DATA_WIDTH(64) // Data Bus Width
  ) u_reg_rcv_nxt_0 (
    .resetn     (r_rst_n                            ), // input
    .ap_clk     (ap_clk                             ), // input
    .in_tdata   (rcv_nxt_update_req_receive_0_tdata ), // input  [DATA_WIDTH-1:0]
    .in_tvalid  (rcv_nxt_update_req_receive_0_tvalid), // input
    .in_tready  (rcv_nxt_update_req_receive_0_tready), // output
    .out_tdata  (w_rcv_nxt_upd_0_tdata              ), // output [DATA_WIDTH-1:0]
    .out_tvalid (w_rcv_nxt_upd_0_tvalid             ), // output
    .out_tready (w_rcv_nxt_upd_0_tready             )  // input
  );

  // Register Slice
  axis_reg_slice #(
    .DATA_WIDTH(64) // Data Bus Width
  ) u_reg_rcv_nxt_1 (
    .resetn     (r_rst_n                            ), // input
    .ap_clk     (ap_clk                             ), // input
    .in_tdata   (rcv_nxt_update_req_receive_1_tdata ), // input  [DATA_WIDTH-1:0]
    .in_tvalid  (rcv_nxt_update_req_receive_1_tvalid), // input
    .in_tready  (rcv_nxt_update_req_receive_1_tready), // output
    .out_tdata  (w_rcv_nxt_upd_1_tdata              ), // output [DATA_WIDTH-1:0]
    .out_tvalid (w_rcv_nxt_upd_1_tvalid             ), // output
    .out_tready (w_rcv_nxt_upd_1_tready             )  // input
  );

  // Register Slice
  axis_reg_slice #(
    .DATA_WIDTH(64) // Data Bus Width
  ) u_reg_usr_read (
    .resetn     (r_rst_n                        ), // input
    .ap_clk     (ap_clk                         ), // input
    .in_tdata   (ingr_usr_read_update_req_tdata ), // input  [DATA_WIDTH-1:0]
    .in_tvalid  (ingr_usr_read_update_req_tvalid), // input
    .in_tready  (ingr_usr_read_update_req_tready), // output
    .out_tdata  (w_usr_read_upd_tdata           ), // output [DATA_WIDTH-1:0]
    .out_tvalid (w_usr_read_upd_tvalid          ), // output
    .out_tready (w_usr_read_upd_tready          )  // input
  );

  // Register Slice
  axis_reg_slice #(
    .DATA_WIDTH(40) // Data Bus Width
  ) u_reg_payload_len (
    .resetn     (r_rst_n                ), // input
    .ap_clk     (ap_clk                 ), // input
    .in_tdata   (ingr_payload_len_tdata ), // input  [DATA_WIDTH-1:0]
    .in_tvalid  (ingr_payload_len_tvalid), // input
    .in_tready  (ingr_payload_len_tready), // output
    .out_tdata  (w_payload_len_tdata    ), // output [DATA_WIDTH-1:0]
    .out_tvalid (w_payload_len_tvalid   ), // output
    .out_tready (w_payload_len_tready   )  // input
  );

  // Register Slice
  axis_reg_slice #(
    .DATA_WIDTH(8) // Data Bus Width
  ) u_reg_start (
    .resetn     (r_rst_n          ), // input
    .ap_clk     (ap_clk           ), // input
    .in_tdata   (ingr_start_tdata ), // input  [DATA_WIDTH-1:0]
    .in_tvalid  (ingr_start_tvalid), // input
    .in_tready  (ingr_start_tready), // output
    .out_tdata  (w_start_tdata    ), // output [DATA_WIDTH-1:0]
    .out_tvalid (w_start_tvalid   ), // output
    .out_tready (w_start_tready   )  // input
  );

  // Register Slice
  axis_reg_slice #(
    .DATA_WIDTH(8) // Data Bus Width
  ) u_reg_done (
    .resetn     (r_rst_n          ), // input
    .ap_clk     (ap_clk           ), // input
    .in_tdata   (w_done_tdata     ), // input  [DATA_WIDTH-1:0]
    .in_tvalid  (w_done_tvalid    ), // input
    .in_tready  (w_done_tready    ), // output
    .out_tdata  (ingr_done_tdata  ), // output [DATA_WIDTH-1:0]
    .out_tvalid (ingr_done_tvalid ), // output
    .out_tready (ingr_done_tready )  // input
  );

  // Register Slice
  axis_reg_slice #(
    .DATA_WIDTH(136) // Data Bus Width
  ) u_reg_receive (
    .resetn     (r_rst_n            ), // input
    .ap_clk     (ap_clk             ), // input
    .in_tdata   (w_receive_tdata    ), // input  [DATA_WIDTH-1:0]
    .in_tvalid  (w_receive_tvalid   ), // input
    .in_tready  (w_receive_tready   ), // output
    .out_tdata  (ingr_receive_tdata ), // output [DATA_WIDTH-1:0]
    .out_tvalid (ingr_receive_tvalid), // output
    .out_tready (ingr_receive_tready)  // input
  );

  // Register Slice
  reg[15:0] r_dbg_sel_session;
  reg[15:0] r_stat_sel_session;
  reg[47:0] r_header_buff_usage;
  reg r_header_buff_usage_vld;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_dbg_sel_session <= 16'd0;
      r_stat_sel_session <= 16'd0;
      r_header_buff_usage <= 48'd0;
      r_header_buff_usage_vld <= 1'b0;
    end else begin
      r_dbg_sel_session <= dbg_sel_session;
      r_stat_sel_session <= stat_sel_session;
      r_header_buff_usage <= header_buff_usage;
      r_header_buff_usage_vld <= header_buff_usage_ap_vld;
    end
  end

  // Core
  ingr_event_core u_core(
    .ap_clk               (ap_clk                     ), // input
    .ap_rst_n             (r_rst_n                    ), // input
    .estab_0_tdata        (w_estab_0_tdata            ), // input [63:0]
    .estab_0_tvalid       (w_estab_0_tvalid           ), // input
    .estab_0_tready       (w_estab_0_tready           ), // output
    .estab_1_tdata        (w_estab_1_tdata            ), // input [63:0]
    .estab_1_tvalid       (w_estab_1_tvalid           ), // input
    .estab_1_tready       (w_estab_1_tready           ), // output
    .rcv_nxt_upd_0_tdata  (w_rcv_nxt_upd_0_tdata      ), // input [63:0]
    .rcv_nxt_upd_0_tvalid (w_rcv_nxt_upd_0_tvalid     ), // input
    .rcv_nxt_upd_0_tready (w_rcv_nxt_upd_0_tready     ), // output
    .rcv_nxt_upd_1_tdata  (w_rcv_nxt_upd_1_tdata      ), // input [63:0]
    .rcv_nxt_upd_1_tvalid (w_rcv_nxt_upd_1_tvalid     ), // input
    .rcv_nxt_upd_1_tready (w_rcv_nxt_upd_1_tready     ), // output
    .usr_read_upd_tdata   (w_usr_read_upd_tdata       ), // input [63:0]
    .usr_read_upd_tvalid  (w_usr_read_upd_tvalid      ), // input
    .usr_read_upd_tready  (w_usr_read_upd_tready      ), // output
    .payload_len_tdata    (w_payload_len_tdata        ), // input [39:0]
    .payload_len_tvalid   (w_payload_len_tvalid       ), // input
    .payload_len_tready   (w_payload_len_tready       ), // output
    .start_tdata          (w_start_tdata              ), // input [7:0]
    .start_tvalid         (w_start_tvalid             ), // input
    .start_tready         (w_start_tready             ), // output
    .done_tdata           (w_done_tdata               ), // output[7:0]
    .done_tvalid          (w_done_tvalid              ), // output
    .done_tready          (w_done_tready              ), // input
    .receive_tdata        (w_receive_tdata            ), // output[135:0]
    .receive_tvalid       (w_receive_tvalid           ), // output
    .receive_tready       (w_receive_tready           ), // input
    .header_buff_usage    (r_header_buff_usage        ), // input [47:0]
    .header_buff_usage_vld(r_header_buff_usage_vld    ), // input
    .stat_rcv_data        (stat_ingr_rcv_data         ), // output[47:0]
    .stat_rcv_data_vld    (stat_ingr_rcv_data_vld     ), // output
    .rcv_detect_fault     (ingr_rcv_detect_fault      ), // output[15:0]
    .rcv_detect_fault_vld (ingr_rcv_detect_fault_vld  ), // output
    .rcv_insert_fault     (ingr_rcv_insert_fault      ), // input [7:0]
    .rcv_nxt_upd_count    (rcv_nxt_update_resp_count  ), // output[31:0]
    .usr_read_upd_count   (usr_read_update_resp_count ), // output[31:0]
    .rx_hp_upd_count      (rx_head_update_resp_count  ), // output[31:0]
    .rx_tp_upd_count      (rx_tail_update_resp_count  ), // output[31:0]
    .dbg_sel_session      (r_dbg_sel_session          ), // input [15:0]
    .stat_sel_session     (r_stat_sel_session         ), // input [15:0]
    .extif_session_status (extif_session_status       ), // output[1:0]
    .last_ptr             (ingr_last_ptr              )  // output[127:0]
  );

endmodule

`default_nettype wire
