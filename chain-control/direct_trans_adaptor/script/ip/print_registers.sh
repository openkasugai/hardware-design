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
