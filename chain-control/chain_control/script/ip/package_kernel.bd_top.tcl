#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

if { $::argc != 3 } {
    puts "ERROR: Program \"$::argv0\" requires 3 arguments!, (${argc} given)\n"
    exit
}


set xoname    [lindex $::argv 0]
set krnl_name [lindex $::argv 1]
set krnl_conf [lindex $::argv 2]
set bd_name   chain_control_bd

set part "xcu250-figd2104-2L-e"

puts "INFO: xoname-> ${xoname}\n      krnl_name-> ${krnl_name}\n      krnl_conf-> ${krnl_conf}\n"

set projName kernel_pack
set path_to_workdir "."
set path_to_hdl "../../src/hdl"
set path_to_bd_tcl "./${bd_name}.tcl"
set path_to_ip "../src/ip"
set path_to_packaged "./pack_${krnl_name}"
set path_to_tmp_project "./tmp_${krnl_name}"

## Create Vivado project
create_project -force $projName $path_to_tmp_project -part ${part}

## Import IP files
exec rm -rf ${path_to_packaged}
exec mkdir -p ${path_to_packaged}
exec cp -r ../src/ip ${path_to_packaged}

## Set IP repository paths
set obj [get_filesets sources_1]
if { $obj != {} } {
   set_property "ip_repo_paths" "[file normalize "../src/ip"]" $obj
   # Rebuild user ip_repo's index before adding any source files
   update_ip_catalog -rebuild
}

create_ip -name cc_ingr_monitor_protocol_core -vendor xilinx.com -library hls -version 1.0 -module_name cc_ingr_monitor_protocol_core_0
generate_target {instantiation_template} [get_files ${path_to_tmp_project}/${projName}.srcs/sources_1/ip/cc_ingr_monitor_protocol_core_0/cc_ingr_monitor_protocol_core_0.xci]
update_compile_order -fileset sources_1
generate_target all [get_files  ${path_to_tmp_project}/${projName}.srcs/sources_1/ip/cc_ingr_monitor_protocol_core_0/cc_ingr_monitor_protocol_core_0.xci]
catch { config_ip_cache -export [get_ips -all cc_ingr_monitor_protocol_core_0] }
export_ip_user_files -of_objects [get_files ${path_to_tmp_project}/${projName}.srcs/sources_1/ip/cc_ingr_monitor_protocol_core_0/cc_ingr_monitor_protocol_core_0.xci] -no_script -sync -force -quiet

create_ip -name cc_egr_monitor_protocol_core -vendor xilinx.com -library hls -version 1.0 -module_name cc_egr_monitor_protocol_core_0
generate_target {instantiation_template} [get_files ${path_to_tmp_project}/${projName}.srcs/sources_1/ip/cc_egr_monitor_protocol_core_0/cc_egr_monitor_protocol_core_0.xci]
update_compile_order -fileset sources_1
generate_target all [get_files  ${path_to_tmp_project}/${projName}.srcs/sources_1/ip/cc_egr_monitor_protocol_core_0/cc_egr_monitor_protocol_core_0.xci]
catch { config_ip_cache -export [get_ips -all cc_egr_monitor_protocol_core_0] }
export_ip_user_files -of_objects [get_files ${path_to_tmp_project}/${projName}.srcs/sources_1/ip/cc_egr_monitor_protocol_core_0/cc_egr_monitor_protocol_core_0.xci] -no_script -sync -force -quiet

## Add design sources
#add_files -norecurse [glob $path_to_hdl/*.dat]
add_files -norecurse [glob $path_to_hdl/*.v]
add_files -norecurse [glob $path_to_hdl/*.sv]
#add_files -norecurse [glob /home/rootsys2/work_murakami/smartconnect_0/smartconnect_0/smartconnect_0.gen/sources_1/bd/smartconnect_0/hdl/smartconnect_0_wrapper.v]
#add_files -norecurse [glob /home/rootsys2/work_murakami/smartconnect_0/smartconnect_0/smartconnect_0.srcs/sources_1/bd/smartconnect_0/smartconnect_0.bd]
update_compile_order -fileset sources_1

## Import Block Design
source ${path_to_bd_tcl}
update_compile_order -fileset sources_1
generate_target all [get_files  ${path_to_tmp_project}/${projName}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd]
export_ip_user_files -of_objects [get_files ${path_to_tmp_project}/${projName}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] ${path_to_tmp_project}/${projName}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd]
update_compile_order -fileset sources_1

set_property top ${krnl_name} [current_fileset]

# Package IP

ipx::package_project -root_dir ${path_to_packaged} -vendor xilinx.com -library RTLKernel -taxonomy /KernelIP -import_files -set_current false
ipx::unload_core ${path_to_packaged}/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory ${path_to_packaged} ${path_to_packaged}/component.xml

set core [ipx::current_core]

set_property core_revision 2 $core
foreach up [ipx::get_user_parameters] {
  ipx::remove_user_parameter [get_property NAME $up] $core
}

if { $krnl_conf != 999 } {
  ipx::associate_bus_interfaces -busif m_axi_extif0_buffer_rd -clock ap_clk $core
}
ipx::associate_bus_interfaces -busif m_axi_extif0_buffer_wr -clock ap_clk $core
ipx::associate_bus_interfaces -busif s_axi_control -clock ap_clk $core
ipx::associate_bus_interfaces -busif m_axis_extif0_cmd -clock ap_clk $core
ipx::associate_bus_interfaces -busif s_axis_extif0_evt -clock ap_clk $core
if { $krnl_conf != 999 } {
  ipx::associate_bus_interfaces -busif m_axis_ingr_tx_req -clock ap_clk $core
  ipx::associate_bus_interfaces -busif s_axis_ingr_tx_resp -clock ap_clk $core
  ipx::associate_bus_interfaces -busif m_axis_ingr_tx_data -clock ap_clk $core
}
ipx::associate_bus_interfaces -busif s_axis_egr_rx_req -clock ap_clk $core
ipx::associate_bus_interfaces -busif m_axis_egr_rx_resp -clock ap_clk $core
ipx::associate_bus_interfaces -busif s_axis_egr_rx_data -clock ap_clk $core
ipx::associate_bus_interfaces -busif m_axi_extif1_buffer_rd -clock ap_clk $core
ipx::associate_bus_interfaces -busif m_axi_extif1_buffer_wr -clock ap_clk $core
ipx::associate_bus_interfaces -busif m_axis_extif1_cmd -clock ap_clk $core
ipx::associate_bus_interfaces -busif s_axis_extif1_evt -clock ap_clk $core

set mem_map    [::ipx::add_memory_map -quiet "s_axi_control" $core]
set addr_block [::ipx::add_address_block -quiet "reg0" $mem_map]

source ${path_to_workdir}/tmp.registers.tcl

set_property slave_memory_map_ref "s_axi_control" [::ipx::get_bus_interfaces -of $core "s_axi_control"]

set_property xpm_libraries {XPM_CDC XPM_MEMORY XPM_FIFO} $core
set_property sdx_kernel true $core
set_property sdx_kernel_type rtl $core
set_property supported_families { } $core
set_property auto_family_support_level level_2 $core
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity -kernel $core
ipx::save_core [ipx::current_core]
close_project -delete

## Generate XO
if {[file exists "${xoname}"]} {
    file delete -force "${xoname}"
}

package_xo \
  -ctrl_protocol user_managed \
  -xo_path ${xoname} \
  -kernel_name ${krnl_name} \
  -ip_directory ${path_to_packaged}
