/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

module chain_control_egr_concat_reg_out (
  input   wire[1023:0]  reg_out                             ,
  output  wire          ap_start                            ,
  output  wire[63:0]    m_axi_extif0_buffer_base            ,
  output  wire[63:0]    m_axi_extif1_buffer_base            ,
  output  wire[63:0]    m_axi_extif0_buffer_tx_offset       ,
  output  wire[31:0]    m_axi_extif0_buffer_tx_stride       ,
  output  wire[7:0]     m_axi_extif0_buffer_tx_size         ,
  output  wire[63:0]    m_axi_extif1_buffer_tx_offset       ,
  output  wire[31:0]    m_axi_extif1_buffer_tx_stride       ,
  output  wire[7:0]     m_axi_extif1_buffer_tx_size         ,
  output  wire[31:0]    egr_forward_update_req              ,
  output  wire[31:0]    egr_forward_channel                 ,
  output  wire[31:0]    egr_forward_session                 ,
  output  wire[31:0]    egr_hdr_ins_insert_fault            ,
  output  wire[7:0]     egr_resp_insert_fault               ,
  output  wire[7:0]     ht_egr_fw_insert_fault              ,
  output  wire[31:0]    egr_rcv_insert_protocol_fault       ,
  output  wire[31:0]    extif0_insert_command_fault         ,
  output  wire[31:0]    extif1_insert_command_fault
);

assign ap_start = reg_out[0:0];
assign m_axi_extif0_buffer_base = reg_out[95:32];
assign m_axi_extif1_buffer_base = reg_out[159:96];
assign m_axi_extif0_buffer_tx_offset = reg_out[223:160];
assign m_axi_extif0_buffer_tx_stride = reg_out[255:224];
assign m_axi_extif0_buffer_tx_size = reg_out[263:256];
assign m_axi_extif1_buffer_tx_offset = reg_out[351:288];
assign m_axi_extif1_buffer_tx_stride = reg_out[383:352];
assign m_axi_extif1_buffer_tx_size = reg_out[391:384];
assign egr_forward_update_req = reg_out[447:416];
assign egr_forward_channel = reg_out[479:448];
assign egr_forward_session = reg_out[511:480];
assign egr_hdr_ins_insert_fault = reg_out[543:512];
assign egr_resp_insert_fault = reg_out[551:544];
assign ht_egr_fw_insert_fault = reg_out[583:576];
assign egr_rcv_insert_protocol_fault = reg_out[639:608];
assign extif0_insert_command_fault = reg_out[671:640];
assign extif1_insert_command_fault = reg_out[703:672];

endmodule

`default_nettype wire
