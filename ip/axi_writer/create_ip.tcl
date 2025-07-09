#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

set     DIR [exec pwd]
set     project_directory  "$DIR/create_ip"
set     project_name        "create_ip"
set     device_ip_dir       "src"
set     ptu_core_ip_repo    "."

create_project -force $project_name $project_directory -part xcu250-figd2104-2L-e
set_property board_part xilinx.com:au250:part0:1.3 [current_project]
set_property ip_repo_paths $ptu_core_ip_repo [current_fileset]

create_ip -name axi_datamover -vendor xilinx.com -library ip -version 5.1 -module_name datamover_for_writer -dir $device_ip_dir
set_property -dict [list \
   CONFIG.c_addr_width {40} \
   CONFIG.c_dummy {0} \
   CONFIG.c_enable_mm2s {0} \
   CONFIG.c_enable_s2mm_adv_sig {0} \
   CONFIG.c_m_axi_s2mm_data_width {512} \
   CONFIG.c_m_axi_s2mm_id_width {0} \
   CONFIG.c_s2mm_burst_size {64} \
   CONFIG.c_s_axis_s2mm_tdata_width {512} \
 ] [get_ips datamover_for_writer]

