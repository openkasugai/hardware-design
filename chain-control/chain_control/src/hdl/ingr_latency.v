/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

module ingr_latency #(
  parameter CID_WIDTH = 9
) (
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF rcv_nxt_update_req_receive:ingr_cmd" *)
  input   wire        ap_clk                            ,
  input   wire        ap_rst_n                          ,
  input   wire        rcv_nxt_update_req_receive_tready ,
  input   wire        rcv_nxt_update_req_receive_tvalid ,
  (* X_INTERFACE_MODE = "monitor" *)
  input   wire[63:0]  rcv_nxt_update_req_receive_tdata  , // ptrUpdateReq
  input   wire        ingr_cmd_tready                   ,
  input   wire        ingr_cmd_tvalid                   ,
  (* X_INTERFACE_MODE = "monitor" *)
  input   wire[63:0]  ingr_cmd_tdata                    , // extifCommand
  output  wire        ingr_latency_valid                ,
  output  wire[47:0]  ingr_latency_data
);

  localparam integer SN_WIDTH = 32;

  wire                w_start_valid = rcv_nxt_update_req_receive_tready & rcv_nxt_update_req_receive_tvalid;
  wire[CID_WIDTH-1:0] w_start_index = rcv_nxt_update_req_receive_tdata[16+CID_WIDTH-1:16]; // cid
  wire[SN_WIDTH-1:0]  w_start_sn    = rcv_nxt_update_req_receive_tdata[32+SN_WIDTH-1:32]; // rcv_nxt

  wire                w_stop_valid  = ingr_cmd_tready & ingr_cmd_tvalid;
  wire[CID_WIDTH-1:0] w_stop_index  = ingr_cmd_tdata[32+CID_WIDTH-1:32]; // cid
  wire[SN_WIDTH-1:0]  w_stop_sn     = ingr_cmd_tdata[SN_WIDTH-1:0]; // usr_ptr
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
    .latency_valid        (ingr_latency_valid ), // output
    .latency_data         (ingr_latency_data  ), // output[47:0]
    .err_start_queue_ovfl (/* open */         ), // output
    .err_stop_queue_ovfl  (/* open */         ), // output
    .err_stop_mishit      (/* open */         ), // output
    .err_stop_overrun     (/* open */         ), // output
    .err_panic            (/* open */         )  // output
  );

endmodule

`default_nettype wire
