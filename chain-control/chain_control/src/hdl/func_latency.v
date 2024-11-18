/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

module func_latency #(
  parameter integer CHANNEL_WIDTH = 9
) (
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF ingr_hdr_rmv_done:egr_hdr_ins_done" *)
  input   wire        ap_clk                  ,
  input   wire        ap_rst_n                ,
  output  wire        ingr_hdr_rmv_done_tready,
  input   wire        ingr_hdr_rmv_done_tvalid,
  input   wire[63:0]  ingr_hdr_rmv_done_tdata , // headerSeq
  output  wire        egr_hdr_ins_done_tready ,
  input   wire        egr_hdr_ins_done_tvalid ,
  input   wire[63:0]  egr_hdr_ins_done_tdata  , // headerSeq
  output  wire        func_latency_valid      ,
  output  wire[47:0]  func_latency_data
);

  localparam integer SN_WIDTH = 32;

  assign ingr_hdr_rmv_done_tready = 1'b1;
  assign egr_hdr_ins_done_tready = 1'b1;

  wire                    w_start_valid = ingr_hdr_rmv_done_tvalid;
  wire[CHANNEL_WIDTH-1:0] w_start_index = ingr_hdr_rmv_done_tdata[CHANNEL_WIDTH-1:0]; // channel
  wire[SN_WIDTH-1:0]      w_start_sn    = ingr_hdr_rmv_done_tdata[32+SN_WIDTH-1:32]; // seq_no

  wire                    w_stop_valid  = egr_hdr_ins_done_tvalid;
  wire[CHANNEL_WIDTH-1:0] w_stop_index  = egr_hdr_ins_done_tdata[CHANNEL_WIDTH-1:0]; // channel
  wire[SN_WIDTH-1:0]      w_stop_sn     = egr_hdr_ins_done_tdata[32+SN_WIDTH-1:32]; // seq_no
  wire                    w_stop_discard= egr_hdr_ins_done_tdata[16];

  latency_meas_core #(
    .INDEX_WIDTH(CHANNEL_WIDTH),
    .SN_WIDTH   (SN_WIDTH     )
  ) u_core (
    .clk                  (ap_clk             ), // input
    .rstn                 (ap_rst_n           ), // input
    .cfg_allow_overrun    (1'b0               ), // input
    .start_valid          (w_start_valid      ), // input
    .start_index          (w_start_index      ), // input [INDEX_WIDTH-1:0]
    .start_sn             (w_start_sn         ), // input [SN_WIDTH-1:0]
    .stop_valid           (w_stop_valid       ), // input
    .stop_index           (w_stop_index       ), // input [INDEX_WIDTH-1:0]
    .stop_sn              (w_stop_sn          ), // input [SN_WIDTH-1:0]
    .stop_discard         (w_stop_discard     ), // input
    .latency_valid        (func_latency_valid ), // output
    .latency_data         (func_latency_data  ), // output[47:0]
    .err_start_queue_ovfl (/* open */         ), // output
    .err_stop_queue_ovfl  (/* open */         ), // output
    .err_stop_mishit      (/* open */         ), // output
    .err_stop_overrun     (/* open */         ), // output
    .err_panic            (/* open */         )  // output
  );

endmodule

`default_nettype wire
