#!/bin/bash

#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

echo_reg_info() {
  reg_name=$1
  reg_addr=$2
  reg_size=$3
  reg_intf=$4
  echo "set reg      [::ipx::add_register \"${reg_name}\" \$addr_block]"
  echo "  set_property description    \"${reg_name}\"    \$reg"
  echo "  set_property address_offset ${reg_addr} \$reg"
  echo "  set_property size           ${reg_size} \$reg"
  if [[ ! -z "${reg_intf}" ]]; then
    echo "  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} \$reg]"
    echo "  set_property value ${reg_intf} \$regparam"
  fi
  echo ""
}

#             Register Name                       Address   Size(bit)   DDR I/F
echo_reg_info control                             0x000     32
echo_reg_info module_id                           0x010     32
echo_reg_info local_version                       0x020     32
echo_reg_info m_axi_extif0_buffer_base_l          0x100     32
echo_reg_info m_axi_extif0_buffer_base_h          0x104     32
echo_reg_info m_axi_extif0_buffer_rx_offset_l     0x110     32
echo_reg_info m_axi_extif0_buffer_rx_offset_h     0x114     32
echo_reg_info m_axi_extif0_buffer_rx_stride       0x118     32
echo_reg_info m_axi_extif0_buffer_rx_size         0x11C     32
echo_reg_info m_axi_extif0_buffer_tx_offset_l     0x120     32
echo_reg_info m_axi_extif0_buffer_tx_offset_h     0x124     32
echo_reg_info m_axi_extif0_buffer_tx_stride       0x128     32
echo_reg_info m_axi_extif0_buffer_tx_size         0x12C     32
echo_reg_info m_axi_extif1_buffer_base_l          0x140     32
echo_reg_info m_axi_extif1_buffer_base_h          0x144     32
echo_reg_info m_axi_extif1_buffer_rx_offset_l     0x150     32
echo_reg_info m_axi_extif1_buffer_rx_offset_h     0x154     32
echo_reg_info m_axi_extif1_buffer_rx_stride       0x158     32
echo_reg_info m_axi_extif1_buffer_rx_size         0x15C     32
echo_reg_info m_axi_extif1_buffer_tx_offset_l     0x160     32
echo_reg_info m_axi_extif1_buffer_tx_offset_h     0x164     32
echo_reg_info m_axi_extif1_buffer_tx_stride       0x168     32
echo_reg_info m_axi_extif1_buffer_tx_size         0x16C     32
echo_reg_info ingr_forward_update_req             0x200     32
echo_reg_info ingr_forward_update_resp            0x204     32
echo_reg_info ingr_forward_session                0x208     32
echo_reg_info ingr_forward_channel                0x20C     32
echo_reg_info egr_forward_update_req              0x220     32
echo_reg_info egr_forward_update_resp             0x224     32
echo_reg_info egr_forward_channel                 0x228     32
echo_reg_info egr_forward_session                 0x22C     32
echo_reg_info stat_sel_session                    0x300     32
echo_reg_info stat_sel_channel                    0x308     32
echo_reg_info ingr_latency_0_value                0x320     32
echo_reg_info ingr_latency_1_value                0x324     32
echo_reg_info egr_latency_0_value                 0x328     32
echo_reg_info egr_latency_1_value                 0x32C     32
echo_reg_info func_latency_value                  0x330     32
echo_reg_info stat_ingr_rcv_data_0_value_l        0x340     32
echo_reg_info stat_ingr_rcv_data_0_value_h        0x344     32
echo_reg_info stat_ingr_rcv_data_1_value_l        0x348     32
echo_reg_info stat_ingr_rcv_data_1_value_h        0x34C     32
echo_reg_info stat_ingr_snd_data_0_value_l        0x350     32
echo_reg_info stat_ingr_snd_data_0_value_h        0x354     32
echo_reg_info stat_ingr_snd_data_1_value_l        0x358     32
echo_reg_info stat_ingr_snd_data_1_value_h        0x35C     32
echo_reg_info stat_egr_rcv_data_0_value_l         0x360     32
echo_reg_info stat_egr_rcv_data_0_value_h         0x364     32
echo_reg_info stat_egr_rcv_data_1_value_l         0x368     32
echo_reg_info stat_egr_rcv_data_1_value_h         0x36C     32
echo_reg_info stat_egr_snd_data_0_value_l         0x370     32
echo_reg_info stat_egr_snd_data_0_value_h         0x374     32
echo_reg_info stat_egr_snd_data_1_value_l         0x378     32
echo_reg_info stat_egr_snd_data_1_value_h         0x37C     32
echo_reg_info stat_ingr_snd_frame_0_value         0x380     32
echo_reg_info stat_ingr_snd_frame_1_value         0x384     32
echo_reg_info stat_egr_rcv_frame_0_value          0x388     32
echo_reg_info stat_egr_rcv_frame_1_value          0x38C     32
echo_reg_info stat_ingr_discard_data_0_value_l    0x3A0     32
echo_reg_info stat_ingr_discard_data_0_value_h    0x3A4     32
echo_reg_info stat_ingr_discard_data_1_value_l    0x3A8     32
echo_reg_info stat_ingr_discard_data_1_value_h    0x3AC     32
echo_reg_info stat_egr_discard_data_0_value_l     0x3B0     32
echo_reg_info stat_egr_discard_data_0_value_h     0x3B4     32
echo_reg_info stat_egr_discard_data_1_value_l     0x3B8     32
echo_reg_info stat_egr_discard_data_1_value_h     0x3BC     32
echo_reg_info stat_header_buff_stored             0x400     32
echo_reg_info stat_header_buff_bp                 0x404     32
echo_reg_info detect_fault                        0x500     32
echo_reg_info ingr_rcv_detect_fault_0_value       0x510     32
echo_reg_info ingr_rcv_detect_fault_0_mask        0x518     32
echo_reg_info ingr_rcv_detect_fault_0_force       0x51C     32
echo_reg_info ingr_rcv_detect_fault_1_value       0x520     32
echo_reg_info ingr_rcv_detect_fault_1_mask        0x528     32
echo_reg_info ingr_rcv_detect_fault_1_force       0x52C     32
echo_reg_info egr_snd_detect_fault_0_value        0x530     32
echo_reg_info egr_snd_detect_fault_0_mask         0x538     32
echo_reg_info egr_snd_detect_fault_0_force        0x53C     32
echo_reg_info egr_snd_detect_fault_1_value        0x540     32
echo_reg_info egr_snd_detect_fault_1_mask         0x548     32
echo_reg_info egr_snd_detect_fault_1_force        0x54C     32
echo_reg_info ingr_snd_protocol_fault             0x550     32
echo_reg_info ingr_snd_protocol_fault_mask        0x558     32
echo_reg_info ingr_snd_protocol_fault_force       0x55C     32
echo_reg_info egr_rcv_protocol_fault              0x560     32
echo_reg_info egr_rcv_protocol_fault_mask         0x568     32
echo_reg_info egr_rcv_protocol_fault_force        0x56C     32
echo_reg_info extif0_event_fault                  0x570     32
echo_reg_info extif0_event_fault_mask             0x578     32
echo_reg_info extif0_event_fault_force            0x57C     32
echo_reg_info extif1_event_fault                  0x580     32
echo_reg_info extif1_event_fault_mask             0x588     32
echo_reg_info extif1_event_fault_force            0x58C     32
echo_reg_info streamif_stall                      0x590     32
echo_reg_info streamif_stall_mask                 0x598     32
echo_reg_info streamif_stall_force                0x59C     32
echo_reg_info ingr_rcv_insert_fault_0             0x600     32
echo_reg_info ingr_rcv_insert_fault_1             0x604     32
echo_reg_info egr_snd_insert_fault_0              0x608     32
echo_reg_info egr_snd_insert_fault_1              0x60C     32
echo_reg_info ingr_snd_insert_protocol_fault      0x610     32
echo_reg_info egr_rcv_insert_protocol_fault       0x614     32
echo_reg_info extif0_insert_command_fault         0x618     32
echo_reg_info extif1_insert_command_fault         0x61C     32
echo_reg_info rcv_nxt_update_resp_count           0x700     32
echo_reg_info rcv_nxt_update_resp_fail_count      0x704     32
echo_reg_info usr_read_update_resp_count          0x708     32
echo_reg_info usr_read_update_resp_fail_count     0x70C     32
echo_reg_info snd_una_update_resp_count           0x710     32
echo_reg_info snd_una_update_resp_fail_count      0x714     32
echo_reg_info usr_wrt_update_resp_count           0x718     32
echo_reg_info usr_wrt_update_resp_fail_count      0x71C     32
echo_reg_info ingr_forward_update_resp_count      0x720     32
echo_reg_info ingr_forward_update_resp_fail_count 0x724     32
echo_reg_info egr_forward_update_resp_count       0x728     32
echo_reg_info egr_forward_update_resp_fail_count  0x72C     32
echo_reg_info rx_head_update_resp_count           0x730     32
echo_reg_info rx_tail_update_resp_count           0x734     32
echo_reg_info tx_tail_update_resp_count           0x738     32
echo_reg_info tx_head_update_resp_count           0x73C     32
echo_reg_info dbg_lup_rx_head                     0x740     32
echo_reg_info dbg_lup_rx_tail                     0x744     32
echo_reg_info dbg_lup_tx_tail                     0x748     32
echo_reg_info dbg_lup_tx_head                     0x74C     32
echo_reg_info hr_rcv_notify                       0x750     32
echo_reg_info hr_snd_req_hd                       0x754     32
echo_reg_info hr_rcv_data_hd                      0x758     32
echo_reg_info hr_snd_req_dt                       0x75C     32
echo_reg_info hr_snd_notify                       0x760     32
echo_reg_info hr_rcv_req                          0x764     32
echo_reg_info hr_rcv_data_dt                      0x768     32
echo_reg_info hr_snd_data                         0x76C     32
echo_reg_info hr_rcv_length_small                 0x770     32
echo_reg_info ha_rcv_req                          0x774     32
echo_reg_info ha_snd_resp                         0x778     32
echo_reg_info ha_snd_req                          0x77C     32
echo_reg_info ha_rcv_resp                         0x780     32
echo_reg_info ha_rcv_data                         0x784     32
echo_reg_info ha_snd_data                         0x788     32
echo_reg_info hr_rcv_data_dt2                     0x78C     32
echo_reg_info hr_rcv_data_hd_err                  0x790     32
echo_reg_info dbg_sel_session                     0x7A0     32
echo_reg_info extif0_session_status               0x7B0     32
echo_reg_info extif1_session_status               0x7B8     32
echo_reg_info extif0_ingr_last_wr_ptr             0x7C0     32
echo_reg_info extif0_ingr_last_rd_ptr             0x7C4     32
echo_reg_info extif0_egr_last_wr_ptr              0x7C8     32
echo_reg_info extif0_egr_last_rd_ptr              0x7CC     32
echo_reg_info extif1_ingr_last_wr_ptr             0x7D0     32
echo_reg_info extif1_ingr_last_rd_ptr             0x7D4     32
echo_reg_info extif1_egr_last_wr_ptr              0x7D8     32
echo_reg_info extif1_egr_last_rd_ptr              0x7DC     32
