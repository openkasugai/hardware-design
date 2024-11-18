#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

set krnl_name    __KRNL_NAME__
set krnl_version __KRNL_VERSION__

open_project -reset ${krnl_name}_prj

open_solution -flow_target vivado "solution1"
set_part xcu250-figd2104-2L-e
create_clock -period 300.000000MHz -name default

config_interface -m_axi_latency=64
config_interface -m_axi_alignment_byte_size=64
config_interface -m_axi_max_widen_bitwidth=512
config_rtl -register_reset_num=3
config_rtl -reset all

set_top ${krnl_name}

set chain_control_include_dir "../../../chain_control/src/hls/include"
set include_dir "../../src/hls/include"
set hls_dir "../../src/hls"
set cflags "-std=c++1y -I${chain_control_include_dir} -I${include_dir} -I${hls_dir} -DDTA_LOCAL_VERSION=0x${krnl_version}"
add_files ${hls_dir}/${krnl_name}.cpp -cflags "$cflags"

csynth_design
#export_design -format xo -output ${krnl_name}.xo
export_design -rtl verilog -format ip_catalog

close_solution
close_project
exit
