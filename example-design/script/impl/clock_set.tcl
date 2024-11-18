#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

################################################################
# This is a generated script based on design: design_1
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2023.1
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################
  #LLDMA
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/s_axis_rc]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/m_axis_rq]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/s_axi]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/s_axis_transfer_cmd_0]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/s_axis_transfer_cmd_1]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/s_axis_transfer_cmd_2]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/s_axis_transfer_cmd_3]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/m_axis_transfer_eve_0]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/m_axis_transfer_eve_1]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/m_axis_transfer_eve_2]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/m_axis_transfer_eve_3]
  #axis2axi_bridge
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /axis2axi_bridge_0/s_axis_cq]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /axis2axi_bridge_0/m_axi]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /axis2axi_bridge_0/m_axis_cc]
  
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/m_axi_cd_0]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/m_axi_cd_1]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/m_axi_cd_2]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/m_axi_cd_3]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/m_axi_cu_0]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/m_axi_cu_1]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/m_axi_cu_2]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/m_axi_cu_3]
  
  set_property CONFIG.CLK_DOMAIN design_1_pcie4_uscale_plus_0_0_user_clk [get_bd_intf_pins /axis2axi_bridge_0/m_axis_direct]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /axis2axi_bridge_0/m_axis_direct]
  set_property CONFIG.CLK_DOMAIN design_1_pcie4_uscale_plus_0_0_user_clk [get_bd_intf_pins /lldma_wrapper_0/s_axis_direct]
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_intf_pins /lldma_wrapper_0/s_axis_direct]
