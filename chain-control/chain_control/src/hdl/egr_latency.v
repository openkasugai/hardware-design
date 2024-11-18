/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

module egr_latency#(
  parameter integer CID_WIDTH = 10
) (
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF egr_meas_start:egr_meas_end" *)
  input   wire        ap_clk                ,
  input   wire        ap_rst_n              ,
  output  wire        egr_meas_start_tready ,
  input   wire        egr_meas_start_tvalid ,
  input   wire[135:0] egr_meas_start_tdata  , // sessionPtr
  output  wire        egr_meas_end_tready   ,
  input   wire        egr_meas_end_tvalid   ,
  input   wire[135:0] egr_meas_end_tdata    , // sessionPtr
  output  wire        egr_latency_valid     ,
  output  wire[47:0]  egr_latency_data
);

  localparam integer SN_WIDTH = 32;

  assign egr_meas_start_tready = 1'b1;
  assign egr_meas_end_tready = 1'b1;

  wire                w_start_valid = egr_meas_start_tvalid;
  wire[CID_WIDTH-1:0] w_start_index = egr_meas_start_tdata[CID_WIDTH-1:0]; // cid
  wire[SN_WIDTH-1:0]  w_start_sn    = egr_meas_start_tdata[64+SN_WIDTH-1:64]; // usr

  wire                w_stop_valid  = egr_meas_end_tvalid;
  wire[CID_WIDTH-1:0] w_stop_index  = egr_meas_end_tdata[CID_WIDTH-1:0]; // cid
  wire[SN_WIDTH-1:0]  w_stop_sn     = egr_meas_end_tdata[32+SN_WIDTH-1:32]; // ext
  wire                w_stop_discard= 1'b0;

  latency_meas_core #(
    .INDEX_WIDTH(CID_WIDTH),
    .SN_WIDTH   (SN_WIDTH )
  ) u_core (
    .clk                  (ap_clk             ), // input
    .rstn                 (ap_rst_n           ), // input
    .cfg_allow_overrun    (1'b1               ), // input
    .start_valid          (w_start_valid      ), // input
    .start_index          (w_start_index      ), // input [INDEX_WIDTH-1:0]
    .start_sn             (w_start_sn         ), // input [SN_WIDTH-1:0]
    .stop_valid           (w_stop_valid       ), // input
    .stop_index           (w_stop_index       ), // input [INDEX_WIDTH-1:0]
    .stop_sn              (w_stop_sn          ), // input [SN_WIDTH-1:0]
    .stop_discard         (w_stop_discard     ), // input
    .latency_valid        (egr_latency_valid  ), // output
    .latency_data         (egr_latency_data   ), // output[47:0]
    .err_start_queue_ovfl (/* open */         ), // output
    .err_stop_queue_ovfl  (/* open */         ), // output
    .err_stop_mishit      (/* open */         ), // output
    .err_stop_overrun     (/* open */         ), // output
    .err_panic            (/* open */         )  // output
  );

endmodule

`default_nettype wire
