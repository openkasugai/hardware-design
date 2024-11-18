/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

module chain_control_ingr_concat_reg_out (
  input   wire[1023:0]  reg_out                             ,
  output  wire          ap_start                            ,
  output  wire[63:0]    m_axi_extif0_buffer_base            ,
  output  wire[63:0]    m_axi_extif1_buffer_base            ,
  output  wire[63:0]    m_axi_extif0_buffer_rx_offset       ,
  output  wire[31:0]    m_axi_extif0_buffer_rx_stride       ,
  output  wire[7:0]     m_axi_extif0_buffer_rx_size         ,
  output  wire[63:0]    m_axi_extif1_buffer_rx_offset       ,
  output  wire[31:0]    m_axi_extif1_buffer_rx_stride       ,
  output  wire[7:0]     m_axi_extif1_buffer_rx_size         ,
  output  wire[31:0]    ingr_forward_update_req             ,
  output  wire[31:0]    ingr_forward_session                ,
  output  wire[31:0]    ingr_forward_channel                ,
  output  wire[7:0]     ingr_event_insert_fault             ,
  output  wire[7:0]     ht_ingr_fw_insert_fault             ,
  output  wire[31:0]    ingr_insert_protocl_fault           ,
  output  wire[31:0]    extif0_insert_command_fault         ,
  output  wire[31:0]    extif1_insert_command_fault         ,
  output  wire[15:0]    dbg_sel_session                     ,
  output  wire[15:0]    stat_sel_session
);

assign ap_start = reg_out[0:0];
assign m_axi_extif0_buffer_base = reg_out[95:32];
assign m_axi_extif1_buffer_base = reg_out[159:96];
assign m_axi_extif0_buffer_rx_offset = reg_out[223:160];
assign m_axi_extif0_buffer_rx_stride = reg_out[255:224];
assign m_axi_extif0_buffer_rx_size = reg_out[263:256];
assign m_axi_extif1_buffer_rx_offset = reg_out[351:288];
assign m_axi_extif1_buffer_rx_stride = reg_out[383:352];
assign m_axi_extif1_buffer_rx_size = reg_out[391:384];
assign ingr_forward_update_req = reg_out[447:416];
assign ingr_forward_session = reg_out[479:448];
assign ingr_forward_channel = reg_out[511:480];
assign ingr_event_insert_fault = reg_out[519:512];
assign ht_ingr_fw_insert_fault = reg_out[551:544];
assign ingr_insert_protocl_fault = reg_out[607:576];
assign extif0_insert_command_fault = reg_out[639:608];
assign extif1_insert_command_fault = reg_out[671:640];
assign dbg_sel_session = reg_out[687:672];
assign stat_sel_session = reg_out[719:704];

endmodule

`default_nettype wire
