/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

module chain_control_egr_concat_reg_in (
  output  wire[2047:0]  reg_in                              ,
  input   wire[31:0]    egr_forward_update_resp             ,
  input   wire[31:0]    egr_forward_update_resp_data        ,
  input   wire          egr_forward_update_resp_data_ap_vld ,
  input   wire          egr_latency_valid                   ,
  input   wire[47:0]    egr_latency_data                    ,
  input   wire          stat_egr_rcv_data_ap_vld            ,
  input   wire[23:0]    stat_egr_rcv_data                   ,
  input   wire          stat_egr_snd_data_ap_vld            ,
  input   wire[47:0]    stat_egr_snd_data                   ,
  input   wire          stat_egr_rcv_frame_ap_vld           ,
  input   wire[15:0]    stat_egr_rcv_frame                  ,
  input   wire          stat_egr_discard_data_ap_vld        ,
  input   wire[23:0]    stat_egr_discard_data               ,
  input   wire          egr_resp_fault_ap_vld               ,
  input   wire[23:0]    egr_resp_fault                      ,
  input   wire          ht_egr_fw_fault_ap_vld              ,
  input   wire[15:0]    ht_egr_fw_fault                     ,
  input   wire          egr_forward_mishit_ap_vld           ,
  input   wire[15:0]    egr_forward_mishit                  ,
  input   wire          egr_rcv_protocol_fault_ap_vld       ,
  input   wire[15:0]    egr_rcv_protocol_fault              ,
  input   wire          egr_last_ptr_ap_vld                 ,
  input   wire[79:0]    egr_last_ptr                        ,
  input   wire[31:0]    snd_una_update_resp_count           ,
  input   wire[31:0]    usr_wrt_update_resp_count           ,
  input   wire[31:0]    egr_forward_update_resp_count       ,
  input   wire[31:0]    egr_forward_update_resp_fail_count  ,
  input   wire[31:0]    tx_tail_update_resp_count           ,
  input   wire[31:0]    tx_head_update_resp_count           ,
  input   wire[31:0]    dbg_lup_tx_tail                     ,
  input   wire[31:0]    dbg_lup_tx_head                     ,
  input   wire          egr_busy_count_ap_vld               ,
  input   wire[23:0]    egr_busy_count
);

reg[2047:0] w_reg_in;
always @(*) begin
  w_reg_in = 2048'd0;

  w_reg_in[31:0] = egr_forward_update_resp;
  w_reg_in[63:32] = egr_forward_update_resp_data;
  w_reg_in[64:64] = egr_forward_update_resp_data_ap_vld;
  w_reg_in[96:96] = egr_latency_valid;
  w_reg_in[175:128] = egr_latency_data;
  w_reg_in[192:192] = stat_egr_rcv_data_ap_vld;
  w_reg_in[247:224] = stat_egr_rcv_data;
  w_reg_in[256:256] = stat_egr_snd_data_ap_vld;
  w_reg_in[335:288] = stat_egr_snd_data;
  w_reg_in[352:352] = stat_egr_rcv_frame_ap_vld;
  w_reg_in[399:384] = stat_egr_rcv_frame;
  w_reg_in[416:416] = stat_egr_discard_data_ap_vld;
  w_reg_in[471:448] = stat_egr_discard_data;
  w_reg_in[480:480] = egr_resp_fault_ap_vld;
  w_reg_in[535:512] = egr_resp_fault;
  w_reg_in[544:544] = ht_egr_fw_fault_ap_vld;
  w_reg_in[591:576] = ht_egr_fw_fault;
  w_reg_in[608:608] = egr_forward_mishit_ap_vld;
  w_reg_in[655:640] = egr_forward_mishit;
  w_reg_in[672:672] = egr_rcv_protocol_fault_ap_vld;
  w_reg_in[719:704] = egr_rcv_protocol_fault;
  w_reg_in[736:736] = egr_last_ptr_ap_vld;
  w_reg_in[847:768] = egr_last_ptr;
  w_reg_in[895:864] = snd_una_update_resp_count;
  w_reg_in[927:896] = usr_wrt_update_resp_count;
  w_reg_in[959:928] = egr_forward_update_resp_count;
  w_reg_in[991:960] = egr_forward_update_resp_fail_count;
  w_reg_in[1023:992] = tx_tail_update_resp_count;
  w_reg_in[1055:1024] = tx_head_update_resp_count;
  w_reg_in[1087:1056] = dbg_lup_tx_tail;
  w_reg_in[1119:1088] = dbg_lup_tx_head;
  w_reg_in[1120:1120] = egr_busy_count_ap_vld;
  w_reg_in[1175:1152] = egr_busy_count;
end
assign reg_in = w_reg_in;

endmodule

`default_nettype wire
