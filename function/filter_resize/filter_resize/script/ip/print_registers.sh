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
echo_reg_info rows_in                             0x010     32          
echo_reg_info cols_in                             0x018     32          
echo_reg_info rows_out                            0x020     32          
echo_reg_info cols_out                            0x028     32          
echo_reg_info rx_rcv_notify_0                     0x030     32          
echo_reg_info rx_snd_req_0                        0x038     32          
echo_reg_info rx_rcv_data_0                       0x048     32          
echo_reg_info tx_snd_req_0                        0x058     32          
echo_reg_info tx_rcv_resp_0                       0x068     32          
echo_reg_info tx_snd_data_0                       0x078     32          
echo_reg_info rx_rcv_notify_1                     0x088     32          
echo_reg_info rx_snd_req_1                        0x090     32          
echo_reg_info rx_rcv_data_1                       0x0a0     32          
echo_reg_info tx_snd_req_1                        0x0b0     32          
echo_reg_info tx_rcv_resp_1                       0x0c0     32          
echo_reg_info tx_snd_data_1                       0x0d0     32          
echo_reg_info fnc_module_id                       0x0e0     32          
echo_reg_info fnc_local_version                   0x0f0     32          
