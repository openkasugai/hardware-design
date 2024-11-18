/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

module chain_control_ingr_concat_reg_in (
  output  wire[2047:0]  reg_in                              ,
  input   wire[31:0]    ingr_forward_update_resp            ,
  input   wire[31:0]    ingr_forward_update_resp_data       ,
  input   wire          ingr_forward_update_resp_data_ap_vld,
  input   wire          ingr_latency_0_valid                ,
  input   wire[47:0]    ingr_latency_0_data                 ,
  input   wire          ingr_latency_1_valid                ,
  input   wire[47:0]    ingr_latency_1_data                 ,
  input   wire          stat_ingr_rcv_data_valid            ,
  input   wire[47:0]    stat_ingr_rcv_data_data             ,
  input   wire          stat_ingr_snd_data_ap_vld           ,
  input   wire[23:0]    stat_ingr_snd_data                  ,
  input   wire          stat_ingr_snd_frame_ap_vld          ,
  input   wire[15:0]    stat_ingr_snd_frame                 ,
  input   wire          stat_ingr_discard_data_ap_vld       ,
  input   wire[47:0]    stat_ingr_discard_data              ,
  input   wire          header_buff_usage_ap_vld            ,
  input   wire[47:0]    header_buff_usage                   ,
  input   wire          ingr_hdr_rmv_fault_ap_vld           ,
  input   wire[31:0]    ingr_hdr_rmv_fault                  ,
  input   wire          ingr_event_fault_vld                ,
  input   wire[15:0]    ingr_event_fault                    ,
  input   wire          ht_ingr_fw_fault_ap_vld             ,
  input   wire[15:0]    ht_ingr_fw_fault                    ,
  input   wire          ingr_forward_mishit_ap_vld          ,
  input   wire[15:0]    ingr_forward_mishit                 ,
  input   wire          ingr_snd_protocol_fault_ap_vld      ,
  input   wire[15:0]    ingr_snd_protocol_fault             ,
  input   wire[1:0]     extif_session_status                ,
  input   wire[127:0]   ingr_last_ptr                       ,
  input   wire[31:0]    rcv_nxt_update_resp_count           ,
  input   wire[31:0]    usr_read_update_resp_count          ,
  input   wire[31:0]    ingr_forward_update_resp_count      ,
  input   wire[31:0]    ingr_forward_update_resp_fail_count ,
  input   wire[31:0]    rx_head_update_resp_count           ,
  input   wire[31:0]    rx_tail_update_resp_count
);

reg[2047:0] w_reg_in;
always @(*) begin
  w_reg_in = 2048'd0;
  
  w_reg_in[31:0] = ingr_forward_update_resp;
  w_reg_in[63:32] = ingr_forward_update_resp_data;
  w_reg_in[64:64] = ingr_forward_update_resp_data_ap_vld;
  w_reg_in[96:96] = ingr_latency_0_valid;
  w_reg_in[175:128] = ingr_latency_0_data;
  w_reg_in[192:192] = ingr_latency_1_valid;
  w_reg_in[271:224] = ingr_latency_1_data;
  w_reg_in[288:288] = stat_ingr_rcv_data_valid;
  w_reg_in[367:320] = stat_ingr_rcv_data_data;
  w_reg_in[384:384] = stat_ingr_snd_data_ap_vld;
  w_reg_in[439:416] = stat_ingr_snd_data;
  w_reg_in[448:448] = stat_ingr_snd_frame_ap_vld;
  w_reg_in[495:480] = stat_ingr_snd_frame;
  w_reg_in[512:512] = stat_ingr_discard_data_ap_vld;
  w_reg_in[591:544] = stat_ingr_discard_data;
  w_reg_in[608:608] = header_buff_usage_ap_vld;
  w_reg_in[687:640] = header_buff_usage;
  w_reg_in[704:704] = ingr_hdr_rmv_fault_ap_vld;
  w_reg_in[767:736] = ingr_hdr_rmv_fault;
  w_reg_in[768:768] = ingr_event_fault_vld;
  w_reg_in[815:800] = ingr_event_fault;
  w_reg_in[832:832] = ht_ingr_fw_fault_ap_vld;
  w_reg_in[879:864] = ht_ingr_fw_fault;
  w_reg_in[896:896] = ingr_forward_mishit_ap_vld;
  w_reg_in[943:928] = ingr_forward_mishit;
  w_reg_in[960:960] = ingr_snd_protocol_fault_ap_vld;
  w_reg_in[1007:992] = ingr_snd_protocol_fault;
  w_reg_in[1025:1024] = extif_session_status;
  w_reg_in[1183:1056] = ingr_last_ptr;
  w_reg_in[1215:1184] = rcv_nxt_update_resp_count;
  w_reg_in[1247:1216] = usr_read_update_resp_count;
  w_reg_in[1279:1248] = ingr_forward_update_resp_count;
  w_reg_in[1311:1280] = ingr_forward_update_resp_fail_count;
  w_reg_in[1343:1312] = rx_head_update_resp_count;
  w_reg_in[1375:1344] = rx_tail_update_resp_count;
end
assign reg_in = w_reg_in;

endmodule

`default_nettype wire
