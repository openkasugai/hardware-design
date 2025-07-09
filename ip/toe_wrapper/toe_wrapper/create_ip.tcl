#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

#
set DIR [exec pwd]
set     project_directory  "$DIR/toe_network"
set     project_name        "toe_network"

# Create Project
create_project $project_name $project_directory -part xcu250-figd2104-2L-e

# Select Board
#set_property board_part xilinx.com:au250:part0:1.3 [current_project]

update_ip_catalog -rebuild
set_property  ip_repo_paths {../..//external/fpga-network-stack/build/ip_repo} [current_project]
update_ip_catalog

#add source
add_files -norecurse ../src/network_ip_ctrl.v
add_files -norecurse ../../common/src/fifo.v
#

# Reconfigure Block Design
source design_1.tcl
regenerate_bd_layout
save_bd_design
set design_bd_name [get_bd_designs]
generate_target all [get_files $design_bd_name.bd]
make_wrapper -files [get_files $design_bd_name.bd] -top -import
set_property top toe_bd_wrapper [current_fileset]

# Save Design
save_bd_design

update_compile_order -fileset sources_1
ipx::package_project -root_dir . -vendor user.org -library user -taxonomy /UserIP
set_property name toe_network [ipx::current_core]
set_property display_name toe_network [ipx::current_core]
set_property description toe_network [ipx::current_core]
ipx::associate_bus_interfaces -busif mac_rx_data -clock mac_rx_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif mac_tx_data -clock mac_tx_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif tcp_cmd -clock toe_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif tcp_rsp -clock toe_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif tcp_rx_data -clock toe_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif tcp_tx_data -clock toe_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif axi_dram -clock dram_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif axil -clock toe_clk [ipx::current_core]
set_property core_revision 1 [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]

close_project
