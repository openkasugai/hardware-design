/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`default_nettype none

module cc_ingr_monitor_protocol (
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF req:resp:data" *)
    input wire ap_clk,
    input wire ap_rst_n,
    input wire req_tready,
    input wire req_tvalid,
    (* X_INTERFACE_MODE = "monitor" *)
    input wire [63:0] req_tdata,
    input wire resp_tready,
    input wire resp_tvalid,
    (* X_INTERFACE_MODE = "monitor" *)
    input wire [63:0] resp_tdata,
    input wire data_tready,
    input wire data_tvalid,
    (* X_INTERFACE_MODE = "monitor" *)
    input wire [511:0] data_tdata,
    output wire [15:0] protocol_error,
    output wire protocol_error_ap_vld
);

  wire fault_resp_channel_eq_req;
  wire fault_resp_burst_length_le_req;
  wire fault_resp_sof_eq_req;
  wire fault_resp_eof_eq_req;
  wire fault_resp_trans_cw_req;
  wire fault_data_trans_cw_resp;
  wire fault_req_outstanding;
  wire fault_resp_outstanding_0;
  wire fault_resp_outstanding_1;
  wire fault_data_outstanding;
  wire fault_req_max_burst_length;
  wire fault_req_burst_length_nz;
  wire fault_resp_burst_length_eq_req;

  reg req_tready_d;
  reg req_tvalid_d;
  reg [63:0] req_tdata_d;
  reg resp_tready_d;
  reg resp_tvalid_d;
  reg [63:0] resp_tdata_d;

  wire [15:0] protocol_error_prev;
  reg [15:0] protocol_error_next;
  reg protocol_error_valid;

  // delay for check req resp
  always @(posedge ap_clk) begin
    if (!ap_rst_n) begin
      req_tready_d  <= 1'b0;
      req_tvalid_d  <= 1'b0;
      req_tdata_d   <= 64'd0;
    end else begin
      req_tready_d  <= req_tready;
      req_tvalid_d  <= req_tvalid;
      req_tdata_d   <= req_tdata;
    end
  end

  // delay for check resp data
  always @(posedge ap_clk) begin
    if (!ap_rst_n) begin
      resp_tready_d <= 1'b0;
      resp_tvalid_d <= 1'b0;
      resp_tdata_d  <= 64'd0;
    end else if ((resp_tvalid == 1'b1) && (resp_tdata[63:48] == 32'd0)) begin
      // drop resp with burst_length=0
      resp_tready_d <= resp_tready;
      resp_tvalid_d <= 1'b0;
      resp_tdata_d  <= resp_tdata;
    end else begin
      resp_tready_d <= resp_tready;
      resp_tvalid_d <= resp_tvalid;
      resp_tdata_d  <= resp_tdata;
    end
  end

  cc_ingr_monitor_protocol_core_0 inst (
      .ap_clk                        (ap_clk),
      .ap_rst                        (~ap_rst_n),
      .req_ready                     (req_tready_d),
      .req_valid                     (req_tvalid_d),
      .req_data                      (req_tdata_d),
      .resp_ready_0                  (resp_tready),
      .resp_valid_0                  (resp_tvalid),
      .resp_data_0                   (resp_tdata),
      .resp_ready_1                  (resp_tready_d),
      .resp_valid_1                  (resp_tvalid_d),
      .resp_data_1                   (resp_tdata_d),
      .data_ready                    (data_tready),
      .data_valid                    (data_tvalid),
      .data_data                     (data_tdata),
      .fault_resp_channel_eq_req     (fault_resp_channel_eq_req),
      .fault_resp_burst_length_le_req(fault_resp_burst_length_le_req),
      .fault_resp_sof_eq_req         (fault_resp_sof_eq_req),
      .fault_resp_eof_eq_req         (fault_resp_eof_eq_req),
      .fault_resp_trans_cw_req       (fault_resp_trans_cw_req),
      .fault_data_trans_cw_resp      (fault_data_trans_cw_resp),
      .fault_req_outstanding         (fault_req_outstanding),
      .fault_resp_outstanding_0      (fault_resp_outstanding_0),
      .fault_resp_outstanding_1      (fault_resp_outstanding_1),
      .fault_data_outstanding        (fault_data_outstanding),
      .fault_req_max_burst_length    (fault_req_max_burst_length),
      .fault_req_burst_length_nz     (fault_req_burst_length_nz),
      .fault_resp_burst_length_eq_req(fault_resp_burst_length_eq_req)
  );

  assign protocol_error_prev[0]  = fault_resp_channel_eq_req;
  assign protocol_error_prev[1]  = fault_resp_burst_length_le_req;
  assign protocol_error_prev[2]  = fault_resp_sof_eq_req;
  assign protocol_error_prev[3]  = fault_resp_eof_eq_req;
  assign protocol_error_prev[4]  = fault_resp_trans_cw_req;
  assign protocol_error_prev[5]  = fault_data_trans_cw_resp;
  assign protocol_error_prev[6]  = fault_req_outstanding;
  assign protocol_error_prev[7]  = fault_resp_outstanding_0 | fault_resp_outstanding_1;
  assign protocol_error_prev[8]  = fault_data_outstanding;
  assign protocol_error_prev[9]  = fault_req_max_burst_length;
  assign protocol_error_prev[10] = 1'b0;  // reserved
  assign protocol_error_prev[11] = 1'b0;  // reserved
  assign protocol_error_prev[12] = fault_req_burst_length_nz;
  assign protocol_error_prev[13] = fault_resp_burst_length_eq_req;
  assign protocol_error_prev[14] = 1'b0;  // reserved
  assign protocol_error_prev[15] = 1'b0;  // reserved

  always @(posedge ap_clk) begin
    if (!ap_rst_n) begin
      protocol_error_next <= 16'd0;
    end else begin
      protocol_error_next <= protocol_error_prev;
    end
  end

  always @(posedge ap_clk) begin
    if (!ap_rst_n) begin
      protocol_error_valid <= 1'b0;
    end else begin
      if (protocol_error_prev != 16'd0) begin
        protocol_error_valid <= 1'b1;
      end else begin
        protocol_error_valid <= 1'b0;
      end
    end
  end

  assign protocol_error = protocol_error_next;
  assign protocol_error_ap_vld = protocol_error_valid;

endmodule

`default_nettype wire
