#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

################################################################
# This is a generated script based on design: filter_resize_bd
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

# To test this script, run the following commands from Vivado Tcl console:
# source filter_resize_bd_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# filter_resize_control_s_axi, fr_egr_monitor_protocol, fr_egr_monitor_protocol, fr_ingr_monitor_protocol, fr_ingr_monitor_protocol, ap_ctrl_krnl, ap_ctrl_krnl

# Please add the sources of those modules before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xcu250-figd2104-2L-e
   set_property BOARD_PART xilinx.com:au250:part0:1.3 [current_project]
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name filter_resize_bd

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:hls:filter_resize_id:1.0\
xilinx.com:hls:data_in_krnl:1.0\
xilinx.com:hls:data_out_krnl:1.0\
xilinx.com:hls:filter_proc_krnl:1.0\
xilinx.com:hls:resize_proc_krnl:1.0\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

##################################################################
# CHECK Modules
##################################################################
set bCheckModules 1
if { $bCheckModules == 1 } {
   set list_check_mods "\ 
filter_resize_control_s_axi\
fr_egr_monitor_protocol\
fr_egr_monitor_protocol\
fr_ingr_monitor_protocol\
fr_ingr_monitor_protocol\
ap_ctrl_krnl\
ap_ctrl_krnl\
"

   set list_mods_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2020 -severity "INFO" "Checking if the following modules exist in the project's sources: $list_check_mods ."

   foreach mod_vlnv $list_check_mods {
      if { [can_resolve_reference $mod_vlnv] == 0 } {
         lappend list_mods_missing $mod_vlnv
      }
   }

   if { $list_mods_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2021 -severity "ERROR" "The following module(s) are not found in the project: $list_mods_missing" }
      common::send_gid_msg -ssname BD::TCL -id 2022 -severity "INFO" "Please add source files for the missing module(s) above."
      set bCheckIPsPassed 0
   }
}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################


# Hierarchical cell: filter_krnl_1
proc create_hier_cell_filter_krnl_1 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_filter_krnl_1() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_rx_req_1

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_rx_data_1

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_rx_resp_1

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_tx_req_1

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_tx_data_1

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_tx_resp_1


  # Create pins
  create_bd_pin -dir O stat_ingr_rcv_data_ap_vld
  create_bd_pin -dir O -from 23 -to 0 -type data stat_ingr_rcv_data
  create_bd_pin -dir I -from 31 -to 0 -type data cols_out
  create_bd_pin -dir I -from 31 -to 0 -type data rows_out
  create_bd_pin -dir I -from 31 -to 0 -type data cols_in
  create_bd_pin -dir I -from 31 -to 0 -type data rows_in
  create_bd_pin -dir I -type rst ARESET_N_1
  create_bd_pin -dir I -type clk ACLK_1
  create_bd_pin -dir O -from 23 -to 0 -type data stat_egr_snd_data
  create_bd_pin -dir O stat_egr_snd_data_ap_vld
  create_bd_pin -dir I -from 4 -to 0 -type data insert_protocol_fault
  create_bd_pin -dir I -from 0 -to 0 -type data insert_protocol_fault_req
  create_bd_pin -dir I -from 0 -to 0 -type data insert_protocol_fault_data
  create_bd_pin -dir O -from 31 -to 0 -type data rcv_sof
  create_bd_pin -dir O -from 31 -to 0 -type data rcv_cid_diff
  create_bd_pin -dir O -from 31 -to 0 -type data rcv_line_chk
  create_bd_pin -dir O -from 31 -to 0 -type data rcv_data
  create_bd_pin -dir O -from 31 -to 0 -type data rcv_length_chk
  create_bd_pin -dir O -from 31 -to 0 -type data snd_req
  create_bd_pin -dir O -from 31 -to 0 -type data rcv_resp
  create_bd_pin -dir O -from 31 -to 0 -type data snd_data
  create_bd_pin -dir I ap_start
  create_bd_pin -dir O -from 31 -to 0 -type data snd_resp
  create_bd_pin -dir O -from 31 -to 0 -type data rcv_req
  create_bd_pin -dir O -from 23 -to 0 -type data stat_egr_snd_frame
  create_bd_pin -dir O stat_egr_snd_frame_ap_vld
  create_bd_pin -dir O -from 23 -to 0 -type data stat_ingr_rcv_frame
  create_bd_pin -dir O stat_ingr_rcv_frame_ap_vld

  # Create instance: ap_ctrl_krnl_1, and set properties
  set block_name ap_ctrl_krnl
  set block_cell_name ap_ctrl_krnl_1
  if { [catch {set ap_ctrl_krnl_1 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $ap_ctrl_krnl_1 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: data_in_krnl_1, and set properties
  set data_in_krnl_1 [ create_bd_cell -type ip -vlnv xilinx.com:hls:data_in_krnl:1.0 data_in_krnl_1 ]

  # Create instance: data_out_krnl_1, and set properties
  set data_out_krnl_1 [ create_bd_cell -type ip -vlnv xilinx.com:hls:data_out_krnl:1.0 data_out_krnl_1 ]

  # Create instance: filter_proc_krnl_1, and set properties
  set filter_proc_krnl_1 [ create_bd_cell -type ip -vlnv xilinx.com:hls:filter_proc_krnl:1.0 filter_proc_krnl_1 ]

  # Create instance: resize_proc_krnl_1, and set properties
  set resize_proc_krnl_1 [ create_bd_cell -type ip -vlnv xilinx.com:hls:resize_proc_krnl:1.0 resize_proc_krnl_1 ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins data_in_krnl_1/s_axis_rx_req] [get_bd_intf_pins s_axis_rx_req_1]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins data_in_krnl_1/s_axis_rx_data] [get_bd_intf_pins s_axis_rx_data_1]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins data_in_krnl_1/m_axis_rx_resp] [get_bd_intf_pins m_axis_rx_resp_1]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins data_out_krnl_1/m_axis_tx_req] [get_bd_intf_pins m_axis_tx_req_1]
  connect_bd_intf_net -intf_net Conn5 [get_bd_intf_pins data_out_krnl_1/m_axis_tx_data] [get_bd_intf_pins m_axis_tx_data_1]
  connect_bd_intf_net -intf_net Conn6 [get_bd_intf_pins data_out_krnl_1/s_axis_tx_resp] [get_bd_intf_pins s_axis_tx_resp_1]
  connect_bd_intf_net -intf_net data_in_krnl_0_m_axis_tx_data [get_bd_intf_pins data_in_krnl_1/m_axis_tx_data] [get_bd_intf_pins filter_proc_krnl_1/p_data_in]
  connect_bd_intf_net -intf_net data_in_krnl_0_s_axis_local_req [get_bd_intf_pins data_in_krnl_1/s_axis_local_req] [get_bd_intf_pins data_out_krnl_1/s_axis_local_req]
  connect_bd_intf_net -intf_net filter_proc_krnl_0_p_data_out [get_bd_intf_pins filter_proc_krnl_1/p_data_out] [get_bd_intf_pins resize_proc_krnl_1/p_data_in]
  connect_bd_intf_net -intf_net resize_proc_krnl_0_p_data_out [get_bd_intf_pins resize_proc_krnl_1/p_data_out] [get_bd_intf_pins data_out_krnl_1/s_axis_rx_data]

  # Create port connections
  connect_bd_net -net ACLK_0_1 [get_bd_pins ACLK_1] [get_bd_pins ap_ctrl_krnl_1/ap_clk] [get_bd_pins data_in_krnl_1/ap_clk] [get_bd_pins data_out_krnl_1/ap_clk] [get_bd_pins filter_proc_krnl_1/ap_clk] [get_bd_pins resize_proc_krnl_1/ap_clk]
  connect_bd_net -net ARESET_N_0_1 [get_bd_pins ARESET_N_1] [get_bd_pins ap_ctrl_krnl_1/ap_rst_n] [get_bd_pins data_in_krnl_1/ap_rst_n] [get_bd_pins data_out_krnl_1/ap_rst_n] [get_bd_pins filter_proc_krnl_1/ap_rst_n] [get_bd_pins resize_proc_krnl_1/ap_rst_n]
  connect_bd_net -net ap_ctrl_krnl_0_ap_start_data_in [get_bd_pins ap_ctrl_krnl_1/ap_start_data_in] [get_bd_pins data_in_krnl_1/ap_start]
  connect_bd_net -net ap_ctrl_krnl_0_ap_start_data_out [get_bd_pins ap_ctrl_krnl_1/ap_start_data_out] [get_bd_pins data_out_krnl_1/ap_start]
  connect_bd_net -net ap_ctrl_krnl_0_ap_start_filter_proc [get_bd_pins ap_ctrl_krnl_1/ap_start_filter_proc] [get_bd_pins filter_proc_krnl_1/ap_start]
  connect_bd_net -net ap_ctrl_krnl_0_ap_start_resize_proc [get_bd_pins ap_ctrl_krnl_1/ap_start_resize_proc] [get_bd_pins resize_proc_krnl_1/ap_start]
  connect_bd_net -net ap_start_1 [get_bd_pins ap_start] [get_bd_pins ap_ctrl_krnl_1/ap_start]
  connect_bd_net -net cols_in_1 [get_bd_pins cols_in] [get_bd_pins data_in_krnl_1/cols_in] [get_bd_pins filter_proc_krnl_1/cols_in] [get_bd_pins resize_proc_krnl_1/cols_in]
  connect_bd_net -net cols_out_1 [get_bd_pins cols_out] [get_bd_pins data_out_krnl_1/cols_out] [get_bd_pins resize_proc_krnl_1/cols_out]
  connect_bd_net -net data_in_krnl_0_ap_done [get_bd_pins data_in_krnl_1/ap_done] [get_bd_pins ap_ctrl_krnl_1/ap_done_data_in]
  connect_bd_net -net data_in_krnl_0_ap_ready [get_bd_pins data_in_krnl_1/ap_ready] [get_bd_pins ap_ctrl_krnl_1/ap_ready_data_in]
  connect_bd_net -net data_in_krnl_0_rcv_cid_diff [get_bd_pins data_in_krnl_1/rcv_cid_diff] [get_bd_pins rcv_cid_diff]
  connect_bd_net -net data_in_krnl_0_rcv_data [get_bd_pins data_in_krnl_1/rcv_data] [get_bd_pins rcv_data]
  connect_bd_net -net data_in_krnl_0_rcv_length_chk [get_bd_pins data_in_krnl_1/rcv_length_chk] [get_bd_pins rcv_length_chk]
  connect_bd_net -net data_in_krnl_0_rcv_line_chk [get_bd_pins data_in_krnl_1/rcv_line_chk] [get_bd_pins rcv_line_chk]
  connect_bd_net -net data_in_krnl_0_rcv_sof [get_bd_pins data_in_krnl_1/rcv_sof] [get_bd_pins rcv_sof]
  connect_bd_net -net data_in_krnl_0_snd_resp [get_bd_pins data_in_krnl_1/snd_resp] [get_bd_pins snd_resp]
  connect_bd_net -net data_in_krnl_0_stat_ingr_rcv_data [get_bd_pins data_in_krnl_1/stat_ingr_rcv_data] [get_bd_pins stat_ingr_rcv_data]
  connect_bd_net -net data_in_krnl_0_stat_ingr_rcv_data_ap_vld [get_bd_pins data_in_krnl_1/stat_ingr_rcv_data_ap_vld] [get_bd_pins stat_ingr_rcv_data_ap_vld]
  connect_bd_net -net data_in_krnl_1_rcv_req [get_bd_pins data_in_krnl_1/rcv_req] [get_bd_pins rcv_req]
  connect_bd_net -net data_in_krnl_1_stat_ingr_rcv_frame [get_bd_pins data_in_krnl_1/stat_ingr_rcv_frame] [get_bd_pins stat_ingr_rcv_frame]
  connect_bd_net -net data_in_krnl_1_stat_ingr_rcv_frame_ap_vld [get_bd_pins data_in_krnl_1/stat_ingr_rcv_frame_ap_vld] [get_bd_pins stat_ingr_rcv_frame_ap_vld]
  connect_bd_net -net data_out_krnl_0_ap_done [get_bd_pins data_out_krnl_1/ap_done] [get_bd_pins ap_ctrl_krnl_1/ap_done_data_out]
  connect_bd_net -net data_out_krnl_0_ap_ready [get_bd_pins data_out_krnl_1/ap_ready] [get_bd_pins ap_ctrl_krnl_1/ap_ready_data_out]
  connect_bd_net -net data_out_krnl_0_rcv_resp [get_bd_pins data_out_krnl_1/rcv_resp] [get_bd_pins rcv_resp]
  connect_bd_net -net data_out_krnl_0_snd_data [get_bd_pins data_out_krnl_1/snd_data] [get_bd_pins snd_data]
  connect_bd_net -net data_out_krnl_0_snd_req [get_bd_pins data_out_krnl_1/snd_req] [get_bd_pins snd_req]
  connect_bd_net -net data_out_krnl_0_stat_egr_snd_data [get_bd_pins data_out_krnl_1/stat_egr_snd_data] [get_bd_pins stat_egr_snd_data]
  connect_bd_net -net data_out_krnl_0_stat_egr_snd_data_ap_vld [get_bd_pins data_out_krnl_1/stat_egr_snd_data_ap_vld] [get_bd_pins stat_egr_snd_data_ap_vld]
  connect_bd_net -net data_out_krnl_1_stat_egr_snd_frame [get_bd_pins data_out_krnl_1/stat_egr_snd_frame] [get_bd_pins stat_egr_snd_frame]
  connect_bd_net -net data_out_krnl_1_stat_egr_snd_frame_ap_vld [get_bd_pins data_out_krnl_1/stat_egr_snd_frame_ap_vld] [get_bd_pins stat_egr_snd_frame_ap_vld]
  connect_bd_net -net filter_proc_krnl_0_ap_done [get_bd_pins filter_proc_krnl_1/ap_done] [get_bd_pins ap_ctrl_krnl_1/ap_done_filter_proc]
  connect_bd_net -net filter_proc_krnl_0_ap_ready [get_bd_pins filter_proc_krnl_1/ap_ready] [get_bd_pins ap_ctrl_krnl_1/ap_ready_filter_proc]
  connect_bd_net -net insert_protocol_fault_1 [get_bd_pins insert_protocol_fault] [get_bd_pins data_in_krnl_1/insert_protocol_fault]
  connect_bd_net -net insert_protocol_fault_data_1 [get_bd_pins insert_protocol_fault_data] [get_bd_pins data_out_krnl_1/insert_protocol_fault_data]
  connect_bd_net -net insert_protocol_fault_req_1 [get_bd_pins insert_protocol_fault_req] [get_bd_pins data_out_krnl_1/insert_protocol_fault_req]
  connect_bd_net -net resize_proc_krnl_0_ap_done [get_bd_pins resize_proc_krnl_1/ap_done] [get_bd_pins ap_ctrl_krnl_1/ap_done_resize_proc]
  connect_bd_net -net resize_proc_krnl_0_ap_ready [get_bd_pins resize_proc_krnl_1/ap_ready] [get_bd_pins ap_ctrl_krnl_1/ap_ready_resize_proc]
  connect_bd_net -net rows_in_1 [get_bd_pins rows_in] [get_bd_pins data_in_krnl_1/rows_in] [get_bd_pins filter_proc_krnl_1/rows_in] [get_bd_pins resize_proc_krnl_1/rows_in]
  connect_bd_net -net rows_out_1 [get_bd_pins rows_out] [get_bd_pins data_out_krnl_1/rows_out] [get_bd_pins resize_proc_krnl_1/rows_out]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: filter_krnl_0
proc create_hier_cell_filter_krnl_0 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_filter_krnl_0() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_rx_req_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_rx_data_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_rx_resp_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_tx_req_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_tx_data_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_tx_resp_0


  # Create pins
  create_bd_pin -dir O stat_ingr_rcv_data_ap_vld
  create_bd_pin -dir O -from 23 -to 0 -type data stat_ingr_rcv_data
  create_bd_pin -dir I -from 31 -to 0 -type data cols_out
  create_bd_pin -dir I -from 31 -to 0 -type data rows_out
  create_bd_pin -dir I -from 31 -to 0 -type data cols_in
  create_bd_pin -dir I -from 31 -to 0 -type data rows_in
  create_bd_pin -dir I -type rst ARESET_N_0
  create_bd_pin -dir I -type clk ACLK_0
  create_bd_pin -dir O -from 23 -to 0 -type data stat_egr_snd_data
  create_bd_pin -dir O stat_egr_snd_data_ap_vld
  create_bd_pin -dir I -from 4 -to 0 -type data insert_protocol_fault
  create_bd_pin -dir I -from 0 -to 0 -type data insert_protocol_fault_req
  create_bd_pin -dir I -from 0 -to 0 -type data insert_protocol_fault_data
  create_bd_pin -dir O -from 31 -to 0 -type data rcv_sof
  create_bd_pin -dir O -from 31 -to 0 -type data rcv_cid_diff
  create_bd_pin -dir O -from 31 -to 0 -type data rcv_line_chk
  create_bd_pin -dir O -from 31 -to 0 -type data rcv_data
  create_bd_pin -dir O -from 31 -to 0 -type data rcv_length_chk
  create_bd_pin -dir O -from 31 -to 0 -type data snd_req
  create_bd_pin -dir O -from 31 -to 0 -type data rcv_resp
  create_bd_pin -dir O -from 31 -to 0 -type data snd_data
  create_bd_pin -dir I ap_start
  create_bd_pin -dir O -from 31 -to 0 -type data snd_resp
  create_bd_pin -dir O -from 31 -to 0 -type data rcv_req
  create_bd_pin -dir O stat_ingr_rcv_frame_ap_vld
  create_bd_pin -dir O -from 23 -to 0 -type data stat_ingr_rcv_frame
  create_bd_pin -dir O stat_egr_snd_frame_ap_vld
  create_bd_pin -dir O -from 23 -to 0 -type data stat_egr_snd_frame

  # Create instance: ap_ctrl_krnl_0, and set properties
  set block_name ap_ctrl_krnl
  set block_cell_name ap_ctrl_krnl_0
  if { [catch {set ap_ctrl_krnl_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $ap_ctrl_krnl_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: data_in_krnl_0, and set properties
  set data_in_krnl_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:data_in_krnl:1.0 data_in_krnl_0 ]

  # Create instance: data_out_krnl_0, and set properties
  set data_out_krnl_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:data_out_krnl:1.0 data_out_krnl_0 ]

  # Create instance: filter_proc_krnl_0, and set properties
  set filter_proc_krnl_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:filter_proc_krnl:1.0 filter_proc_krnl_0 ]

  # Create instance: resize_proc_krnl_0, and set properties
  set resize_proc_krnl_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:resize_proc_krnl:1.0 resize_proc_krnl_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins data_in_krnl_0/s_axis_rx_req] [get_bd_intf_pins s_axis_rx_req_0]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins data_in_krnl_0/s_axis_rx_data] [get_bd_intf_pins s_axis_rx_data_0]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins data_in_krnl_0/m_axis_rx_resp] [get_bd_intf_pins m_axis_rx_resp_0]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins data_out_krnl_0/m_axis_tx_req] [get_bd_intf_pins m_axis_tx_req_0]
  connect_bd_intf_net -intf_net Conn5 [get_bd_intf_pins data_out_krnl_0/m_axis_tx_data] [get_bd_intf_pins m_axis_tx_data_0]
  connect_bd_intf_net -intf_net Conn6 [get_bd_intf_pins data_out_krnl_0/s_axis_tx_resp] [get_bd_intf_pins s_axis_tx_resp_0]
  connect_bd_intf_net -intf_net data_in_krnl_0_m_axis_tx_data [get_bd_intf_pins data_in_krnl_0/m_axis_tx_data] [get_bd_intf_pins filter_proc_krnl_0/p_data_in]
  connect_bd_intf_net -intf_net data_in_krnl_0_s_axis_local_req [get_bd_intf_pins data_in_krnl_0/s_axis_local_req] [get_bd_intf_pins data_out_krnl_0/s_axis_local_req]
  connect_bd_intf_net -intf_net filter_proc_krnl_0_p_data_out [get_bd_intf_pins filter_proc_krnl_0/p_data_out] [get_bd_intf_pins resize_proc_krnl_0/p_data_in]
  connect_bd_intf_net -intf_net resize_proc_krnl_0_p_data_out [get_bd_intf_pins resize_proc_krnl_0/p_data_out] [get_bd_intf_pins data_out_krnl_0/s_axis_rx_data]

  # Create port connections
  connect_bd_net -net ACLK_0_1 [get_bd_pins ACLK_0] [get_bd_pins ap_ctrl_krnl_0/ap_clk] [get_bd_pins data_in_krnl_0/ap_clk] [get_bd_pins data_out_krnl_0/ap_clk] [get_bd_pins filter_proc_krnl_0/ap_clk] [get_bd_pins resize_proc_krnl_0/ap_clk]
  connect_bd_net -net ARESET_N_0_1 [get_bd_pins ARESET_N_0] [get_bd_pins ap_ctrl_krnl_0/ap_rst_n] [get_bd_pins data_in_krnl_0/ap_rst_n] [get_bd_pins data_out_krnl_0/ap_rst_n] [get_bd_pins filter_proc_krnl_0/ap_rst_n] [get_bd_pins resize_proc_krnl_0/ap_rst_n]
  connect_bd_net -net ap_ctrl_krnl_0_ap_start_data_in [get_bd_pins ap_ctrl_krnl_0/ap_start_data_in] [get_bd_pins data_in_krnl_0/ap_start]
  connect_bd_net -net ap_ctrl_krnl_0_ap_start_data_out [get_bd_pins ap_ctrl_krnl_0/ap_start_data_out] [get_bd_pins data_out_krnl_0/ap_start]
  connect_bd_net -net ap_ctrl_krnl_0_ap_start_filter_proc [get_bd_pins ap_ctrl_krnl_0/ap_start_filter_proc] [get_bd_pins filter_proc_krnl_0/ap_start]
  connect_bd_net -net ap_ctrl_krnl_0_ap_start_resize_proc [get_bd_pins ap_ctrl_krnl_0/ap_start_resize_proc] [get_bd_pins resize_proc_krnl_0/ap_start]
  connect_bd_net -net ap_start_1 [get_bd_pins ap_start] [get_bd_pins ap_ctrl_krnl_0/ap_start]
  connect_bd_net -net cols_in_1 [get_bd_pins cols_in] [get_bd_pins data_in_krnl_0/cols_in] [get_bd_pins filter_proc_krnl_0/cols_in] [get_bd_pins resize_proc_krnl_0/cols_in]
  connect_bd_net -net cols_out_1 [get_bd_pins cols_out] [get_bd_pins data_out_krnl_0/cols_out] [get_bd_pins resize_proc_krnl_0/cols_out]
  connect_bd_net -net data_in_krnl_0_ap_done [get_bd_pins data_in_krnl_0/ap_done] [get_bd_pins ap_ctrl_krnl_0/ap_done_data_in]
  connect_bd_net -net data_in_krnl_0_ap_ready [get_bd_pins data_in_krnl_0/ap_ready] [get_bd_pins ap_ctrl_krnl_0/ap_ready_data_in]
  connect_bd_net -net data_in_krnl_0_rcv_cid_diff [get_bd_pins data_in_krnl_0/rcv_cid_diff] [get_bd_pins rcv_cid_diff]
  connect_bd_net -net data_in_krnl_0_rcv_data [get_bd_pins data_in_krnl_0/rcv_data] [get_bd_pins rcv_data]
  connect_bd_net -net data_in_krnl_0_rcv_length_chk [get_bd_pins data_in_krnl_0/rcv_length_chk] [get_bd_pins rcv_length_chk]
  connect_bd_net -net data_in_krnl_0_rcv_line_chk [get_bd_pins data_in_krnl_0/rcv_line_chk] [get_bd_pins rcv_line_chk]
  connect_bd_net -net data_in_krnl_0_rcv_req [get_bd_pins data_in_krnl_0/rcv_req] [get_bd_pins rcv_req]
  connect_bd_net -net data_in_krnl_0_rcv_sof [get_bd_pins data_in_krnl_0/rcv_sof] [get_bd_pins rcv_sof]
  connect_bd_net -net data_in_krnl_0_snd_resp [get_bd_pins data_in_krnl_0/snd_resp] [get_bd_pins snd_resp]
  connect_bd_net -net data_in_krnl_0_stat_ingr_rcv_data [get_bd_pins data_in_krnl_0/stat_ingr_rcv_data] [get_bd_pins stat_ingr_rcv_data]
  connect_bd_net -net data_in_krnl_0_stat_ingr_rcv_data_ap_vld [get_bd_pins data_in_krnl_0/stat_ingr_rcv_data_ap_vld] [get_bd_pins stat_ingr_rcv_data_ap_vld]
  connect_bd_net -net data_in_krnl_0_stat_ingr_rcv_frame [get_bd_pins data_in_krnl_0/stat_ingr_rcv_frame] [get_bd_pins stat_ingr_rcv_frame]
  connect_bd_net -net data_in_krnl_0_stat_ingr_rcv_frame_ap_vld [get_bd_pins data_in_krnl_0/stat_ingr_rcv_frame_ap_vld] [get_bd_pins stat_ingr_rcv_frame_ap_vld]
  connect_bd_net -net data_out_krnl_0_ap_done [get_bd_pins data_out_krnl_0/ap_done] [get_bd_pins ap_ctrl_krnl_0/ap_done_data_out]
  connect_bd_net -net data_out_krnl_0_ap_ready [get_bd_pins data_out_krnl_0/ap_ready] [get_bd_pins ap_ctrl_krnl_0/ap_ready_data_out]
  connect_bd_net -net data_out_krnl_0_rcv_resp [get_bd_pins data_out_krnl_0/rcv_resp] [get_bd_pins rcv_resp]
  connect_bd_net -net data_out_krnl_0_snd_data [get_bd_pins data_out_krnl_0/snd_data] [get_bd_pins snd_data]
  connect_bd_net -net data_out_krnl_0_snd_req [get_bd_pins data_out_krnl_0/snd_req] [get_bd_pins snd_req]
  connect_bd_net -net data_out_krnl_0_stat_egr_snd_data [get_bd_pins data_out_krnl_0/stat_egr_snd_data] [get_bd_pins stat_egr_snd_data]
  connect_bd_net -net data_out_krnl_0_stat_egr_snd_data_ap_vld [get_bd_pins data_out_krnl_0/stat_egr_snd_data_ap_vld] [get_bd_pins stat_egr_snd_data_ap_vld]
  connect_bd_net -net data_out_krnl_0_stat_egr_snd_frame [get_bd_pins data_out_krnl_0/stat_egr_snd_frame] [get_bd_pins stat_egr_snd_frame]
  connect_bd_net -net data_out_krnl_0_stat_egr_snd_frame_ap_vld [get_bd_pins data_out_krnl_0/stat_egr_snd_frame_ap_vld] [get_bd_pins stat_egr_snd_frame_ap_vld]
  connect_bd_net -net filter_proc_krnl_0_ap_done [get_bd_pins filter_proc_krnl_0/ap_done] [get_bd_pins ap_ctrl_krnl_0/ap_done_filter_proc]
  connect_bd_net -net filter_proc_krnl_0_ap_ready [get_bd_pins filter_proc_krnl_0/ap_ready] [get_bd_pins ap_ctrl_krnl_0/ap_ready_filter_proc]
  connect_bd_net -net insert_protocol_fault_1 [get_bd_pins insert_protocol_fault] [get_bd_pins data_in_krnl_0/insert_protocol_fault]
  connect_bd_net -net insert_protocol_fault_data_1 [get_bd_pins insert_protocol_fault_data] [get_bd_pins data_out_krnl_0/insert_protocol_fault_data]
  connect_bd_net -net insert_protocol_fault_req_1 [get_bd_pins insert_protocol_fault_req] [get_bd_pins data_out_krnl_0/insert_protocol_fault_req]
  connect_bd_net -net resize_proc_krnl_0_ap_done [get_bd_pins resize_proc_krnl_0/ap_done] [get_bd_pins ap_ctrl_krnl_0/ap_done_resize_proc]
  connect_bd_net -net resize_proc_krnl_0_ap_ready [get_bd_pins resize_proc_krnl_0/ap_ready] [get_bd_pins ap_ctrl_krnl_0/ap_ready_resize_proc]
  connect_bd_net -net rows_in_1 [get_bd_pins rows_in] [get_bd_pins data_in_krnl_0/rows_in] [get_bd_pins filter_proc_krnl_0/rows_in] [get_bd_pins resize_proc_krnl_0/rows_in]
  connect_bd_net -net rows_out_1 [get_bd_pins rows_out] [get_bd_pins data_out_krnl_0/rows_out] [get_bd_pins resize_proc_krnl_0/rows_out]

  # Restore current instance
  current_bd_instance $oldCurInst
}


# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set s_axi_control [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_control ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {16} \
   CONFIG.ARUSER_WIDTH {0} \
   CONFIG.AWUSER_WIDTH {0} \
   CONFIG.BUSER_WIDTH {0} \
   CONFIG.DATA_WIDTH {32} \
   CONFIG.HAS_BRESP {1} \
   CONFIG.HAS_BURST {0} \
   CONFIG.HAS_CACHE {0} \
   CONFIG.HAS_LOCK {0} \
   CONFIG.HAS_PROT {0} \
   CONFIG.HAS_QOS {0} \
   CONFIG.HAS_REGION {0} \
   CONFIG.HAS_RRESP {1} \
   CONFIG.HAS_WSTRB {1} \
   CONFIG.ID_WIDTH {0} \
   CONFIG.MAX_BURST_LENGTH {1} \
   CONFIG.NUM_READ_OUTSTANDING {1} \
   CONFIG.NUM_READ_THREADS {1} \
   CONFIG.NUM_WRITE_OUTSTANDING {1} \
   CONFIG.NUM_WRITE_THREADS {1} \
   CONFIG.PROTOCOL {AXI4LITE} \
   CONFIG.READ_WRITE_MODE {READ_WRITE} \
   CONFIG.RUSER_BITS_PER_BYTE {0} \
   CONFIG.RUSER_WIDTH {0} \
   CONFIG.SUPPORTS_NARROW_BURST {0} \
   CONFIG.WUSER_BITS_PER_BYTE {0} \
   CONFIG.WUSER_WIDTH {0} \
   ] $s_axi_control

  set s_axis_rx_req_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_rx_req_0 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $s_axis_rx_req_0

  set s_axis_rx_data_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_rx_data_0 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {4} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $s_axis_rx_data_0

  set m_axis_rx_resp_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_rx_resp_0 ]

  set m_axis_tx_req_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_tx_req_0 ]

  set m_axis_tx_data_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_tx_data_0 ]

  set s_axis_tx_resp_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_tx_resp_0 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $s_axis_tx_resp_0

  set s_axis_rx_req_1 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_rx_req_1 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $s_axis_rx_req_1

  set s_axis_rx_data_1 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_rx_data_1 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {4} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $s_axis_rx_data_1

  set s_axis_tx_resp_1 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_tx_resp_1 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $s_axis_tx_resp_1

  set m_axis_rx_resp_1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_rx_resp_1 ]

  set m_axis_tx_req_1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_tx_req_1 ]

  set m_axis_tx_data_1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_tx_data_1 ]


  # Create ports
  set ACLK [ create_bd_port -dir I -type clk ACLK ]
  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {s_axi_control:s_axis_rx_req_0:s_axis_rx_data_0:m_axis_rx_resp_0:m_axis_tx_req_0:m_axis_tx_data_0:s_axis_tx_resp_0:s_axis_rx_req_1:s_axis_rx_data_1:s_axis_tx_resp_1:m_axis_rx_resp_1:m_axis_tx_req_1:m_axis_tx_data_1} \
 ] $ACLK
  set ARESET_N [ create_bd_port -dir I ARESET_N ]
  set detect_fault [ create_bd_port -dir O detect_fault ]
  set streamif_stall [ create_bd_port -dir I -from 11 -to 0 streamif_stall ]

  # Create instance: filter_krnl_0
  create_hier_cell_filter_krnl_0 [current_bd_instance .] filter_krnl_0

  # Create instance: filter_krnl_1
  create_hier_cell_filter_krnl_1 [current_bd_instance .] filter_krnl_1

  # Create instance: filter_resize_contro_0, and set properties
  set block_name filter_resize_control_s_axi
  set block_cell_name filter_resize_contro_0
  if { [catch {set filter_resize_contro_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $filter_resize_contro_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: filter_resize_id_0, and set properties
  set filter_resize_id_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:filter_resize_id:1.0 filter_resize_id_0 ]

  # Create instance: egr_monitor_protocol_0, and set properties
  set block_name fr_egr_monitor_protocol
  set block_cell_name egr_monitor_protocol_0
  if { [catch {set egr_monitor_protocol_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $egr_monitor_protocol_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: egr_monitor_protocol_1, and set properties
  set block_name fr_egr_monitor_protocol
  set block_cell_name egr_monitor_protocol_1
  if { [catch {set egr_monitor_protocol_1 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $egr_monitor_protocol_1 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: ingr_monitor_protocol_0, and set properties
  set block_name fr_ingr_monitor_protocol
  set block_cell_name ingr_monitor_protocol_0
  if { [catch {set ingr_monitor_protocol_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $ingr_monitor_protocol_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: ingr_monitor_protocol_1, and set properties
  set block_name fr_ingr_monitor_protocol
  set block_cell_name ingr_monitor_protocol_1
  if { [catch {set ingr_monitor_protocol_1 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $ingr_monitor_protocol_1 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create interface connections
  connect_bd_intf_net -intf_net filter_krnl1_m_axis_rx_resp_1 [get_bd_intf_ports m_axis_rx_resp_1] [get_bd_intf_pins filter_krnl_1/m_axis_rx_resp_1]
connect_bd_intf_net -intf_net [get_bd_intf_nets filter_krnl1_m_axis_rx_resp_1] [get_bd_intf_ports m_axis_rx_resp_1] [get_bd_intf_pins ingr_monitor_protocol_1/resp]
  connect_bd_intf_net -intf_net filter_krnl1_m_axis_tx_data_1 [get_bd_intf_ports m_axis_tx_data_1] [get_bd_intf_pins filter_krnl_1/m_axis_tx_data_1]
connect_bd_intf_net -intf_net [get_bd_intf_nets filter_krnl1_m_axis_tx_data_1] [get_bd_intf_ports m_axis_tx_data_1] [get_bd_intf_pins egr_monitor_protocol_1/data]
  connect_bd_intf_net -intf_net filter_krnl1_m_axis_tx_req_1 [get_bd_intf_ports m_axis_tx_req_1] [get_bd_intf_pins filter_krnl_1/m_axis_tx_req_1]
connect_bd_intf_net -intf_net [get_bd_intf_nets filter_krnl1_m_axis_tx_req_1] [get_bd_intf_ports m_axis_tx_req_1] [get_bd_intf_pins egr_monitor_protocol_1/req]
  connect_bd_intf_net -intf_net filter_krnl_m_axis_rx_resp_0 [get_bd_intf_ports m_axis_rx_resp_0] [get_bd_intf_pins filter_krnl_0/m_axis_rx_resp_0]
connect_bd_intf_net -intf_net [get_bd_intf_nets filter_krnl_m_axis_rx_resp_0] [get_bd_intf_ports m_axis_rx_resp_0] [get_bd_intf_pins ingr_monitor_protocol_0/resp]
  connect_bd_intf_net -intf_net filter_krnl_m_axis_tx_data_0 [get_bd_intf_ports m_axis_tx_data_0] [get_bd_intf_pins filter_krnl_0/m_axis_tx_data_0]
connect_bd_intf_net -intf_net [get_bd_intf_nets filter_krnl_m_axis_tx_data_0] [get_bd_intf_ports m_axis_tx_data_0] [get_bd_intf_pins egr_monitor_protocol_0/data]
  connect_bd_intf_net -intf_net filter_krnl_m_axis_tx_req_0 [get_bd_intf_ports m_axis_tx_req_0] [get_bd_intf_pins filter_krnl_0/m_axis_tx_req_0]
connect_bd_intf_net -intf_net [get_bd_intf_nets filter_krnl_m_axis_tx_req_0] [get_bd_intf_ports m_axis_tx_req_0] [get_bd_intf_pins egr_monitor_protocol_0/req]
  connect_bd_intf_net -intf_net interface_aximm_0_1 [get_bd_intf_ports s_axi_control] [get_bd_intf_pins filter_resize_contro_0/interface_aximm]
  connect_bd_intf_net -intf_net s_axis_rx_data_0_1 [get_bd_intf_ports s_axis_rx_data_0] [get_bd_intf_pins filter_krnl_0/s_axis_rx_data_0]
connect_bd_intf_net -intf_net [get_bd_intf_nets s_axis_rx_data_0_1] [get_bd_intf_ports s_axis_rx_data_0] [get_bd_intf_pins ingr_monitor_protocol_0/data]
  connect_bd_intf_net -intf_net s_axis_rx_data_1_0_1 [get_bd_intf_ports s_axis_rx_data_1] [get_bd_intf_pins filter_krnl_1/s_axis_rx_data_1]
connect_bd_intf_net -intf_net [get_bd_intf_nets s_axis_rx_data_1_0_1] [get_bd_intf_ports s_axis_rx_data_1] [get_bd_intf_pins ingr_monitor_protocol_1/data]
  connect_bd_intf_net -intf_net s_axis_rx_req_0_1 [get_bd_intf_ports s_axis_rx_req_0] [get_bd_intf_pins filter_krnl_0/s_axis_rx_req_0]
connect_bd_intf_net -intf_net [get_bd_intf_nets s_axis_rx_req_0_1] [get_bd_intf_ports s_axis_rx_req_0] [get_bd_intf_pins ingr_monitor_protocol_0/req]
  connect_bd_intf_net -intf_net s_axis_rx_req_1_0_1 [get_bd_intf_ports s_axis_rx_req_1] [get_bd_intf_pins filter_krnl_1/s_axis_rx_req_1]
connect_bd_intf_net -intf_net [get_bd_intf_nets s_axis_rx_req_1_0_1] [get_bd_intf_ports s_axis_rx_req_1] [get_bd_intf_pins ingr_monitor_protocol_1/req]
  connect_bd_intf_net -intf_net s_axis_tx_resp_0_1 [get_bd_intf_ports s_axis_tx_resp_0] [get_bd_intf_pins filter_krnl_0/s_axis_tx_resp_0]
connect_bd_intf_net -intf_net [get_bd_intf_nets s_axis_tx_resp_0_1] [get_bd_intf_ports s_axis_tx_resp_0] [get_bd_intf_pins egr_monitor_protocol_0/resp]
  connect_bd_intf_net -intf_net s_axis_tx_resp_1_0_1 [get_bd_intf_ports s_axis_tx_resp_1] [get_bd_intf_pins filter_krnl_1/s_axis_tx_resp_1]
connect_bd_intf_net -intf_net [get_bd_intf_nets s_axis_tx_resp_1_0_1] [get_bd_intf_ports s_axis_tx_resp_1] [get_bd_intf_pins egr_monitor_protocol_1/resp]

  # Create port connections
  connect_bd_net -net ACLK_0_1 [get_bd_ports ACLK] [get_bd_pins filter_krnl_0/ACLK_0] [get_bd_pins filter_krnl_1/ACLK_1] [get_bd_pins filter_resize_contro_0/ACLK] [get_bd_pins egr_monitor_protocol_0/ap_clk] [get_bd_pins egr_monitor_protocol_1/ap_clk] [get_bd_pins ingr_monitor_protocol_0/ap_clk] [get_bd_pins ingr_monitor_protocol_1/ap_clk]
  connect_bd_net -net ARESET_N_0_1 [get_bd_ports ARESET_N] [get_bd_pins filter_krnl_0/ARESET_N_0] [get_bd_pins filter_krnl_1/ARESET_N_1] [get_bd_pins filter_resize_contro_0/ARESET_N] [get_bd_pins egr_monitor_protocol_0/ap_rst_n] [get_bd_pins egr_monitor_protocol_1/ap_rst_n] [get_bd_pins ingr_monitor_protocol_0/ap_rst_n] [get_bd_pins ingr_monitor_protocol_1/ap_rst_n]
  connect_bd_net -net egr_monitor_protocol_0_protocol_error [get_bd_pins egr_monitor_protocol_0/protocol_error] [get_bd_pins filter_resize_contro_0/egr_protocol_error_0]
  connect_bd_net -net egr_monitor_protocol_0_protocol_error_ap_vld [get_bd_pins egr_monitor_protocol_0/protocol_error_ap_vld] [get_bd_pins filter_resize_contro_0/egr_protocol_error_0_vld]
  connect_bd_net -net egr_monitor_protocol_1_protocol_error [get_bd_pins egr_monitor_protocol_1/protocol_error] [get_bd_pins filter_resize_contro_0/egr_protocol_error_1]
  connect_bd_net -net egr_monitor_protocol_1_protocol_error_ap_vld [get_bd_pins egr_monitor_protocol_1/protocol_error_ap_vld] [get_bd_pins filter_resize_contro_0/egr_protocol_error_1_vld]
  connect_bd_net -net filter_krnl1_rcv_cid_diff [get_bd_pins filter_krnl_1/rcv_cid_diff] [get_bd_pins filter_resize_contro_0/rx_rcv_cid_diff_1]
  connect_bd_net -net filter_krnl1_rcv_data [get_bd_pins filter_krnl_1/rcv_data] [get_bd_pins filter_resize_contro_0/rx_rcv_data_1]
  connect_bd_net -net filter_krnl1_rcv_length_chk [get_bd_pins filter_krnl_1/rcv_length_chk] [get_bd_pins filter_resize_contro_0/rx_rcv_length_chk_1]
  connect_bd_net -net filter_krnl1_rcv_line_chk [get_bd_pins filter_krnl_1/rcv_line_chk] [get_bd_pins filter_resize_contro_0/rx_rcv_line_chk_1]
  connect_bd_net -net filter_krnl1_rcv_resp [get_bd_pins filter_krnl_1/rcv_resp] [get_bd_pins filter_resize_contro_0/tx_rcv_resp_1]
  connect_bd_net -net filter_krnl1_rcv_sof [get_bd_pins filter_krnl_1/rcv_sof] [get_bd_pins filter_resize_contro_0/rx_rcv_sof_1]
  connect_bd_net -net filter_krnl1_snd_data [get_bd_pins filter_krnl_1/snd_data] [get_bd_pins filter_resize_contro_0/tx_snd_data_1]
  connect_bd_net -net filter_krnl1_snd_req [get_bd_pins filter_krnl_1/snd_req] [get_bd_pins filter_resize_contro_0/tx_snd_req_1]
  connect_bd_net -net filter_krnl1_snd_resp [get_bd_pins filter_krnl_1/snd_resp] [get_bd_pins filter_resize_contro_0/rx_snd_resp_1]
  connect_bd_net -net filter_krnl1_stat_egr_snd_data [get_bd_pins filter_krnl_1/stat_egr_snd_data] [get_bd_pins filter_resize_contro_0/egr_stat_data_1]
  connect_bd_net -net filter_krnl1_stat_egr_snd_data_ap_vld [get_bd_pins filter_krnl_1/stat_egr_snd_data_ap_vld] [get_bd_pins filter_resize_contro_0/egr_stat_data_1_vld]
  connect_bd_net -net filter_krnl1_stat_ingr_rcv_data [get_bd_pins filter_krnl_1/stat_ingr_rcv_data] [get_bd_pins filter_resize_contro_0/ingr_stat_data_1]
  connect_bd_net -net filter_krnl1_stat_ingr_rcv_data_ap_vld [get_bd_pins filter_krnl_1/stat_ingr_rcv_data_ap_vld] [get_bd_pins filter_resize_contro_0/ingr_stat_data_1_vld]
  connect_bd_net -net filter_krnl_0_rcv_req [get_bd_pins filter_krnl_0/rcv_req] [get_bd_pins filter_resize_contro_0/rx_rcv_req_0]
  connect_bd_net -net filter_krnl_0_stat_egr_snd_frame [get_bd_pins filter_krnl_0/stat_egr_snd_frame] [get_bd_pins filter_resize_contro_0/egr_stat_frame_0]
  connect_bd_net -net filter_krnl_0_stat_egr_snd_frame_ap_vld [get_bd_pins filter_krnl_0/stat_egr_snd_frame_ap_vld] [get_bd_pins filter_resize_contro_0/egr_stat_frame_0_vld]
  connect_bd_net -net filter_krnl_0_stat_ingr_rcv_frame [get_bd_pins filter_krnl_0/stat_ingr_rcv_frame] [get_bd_pins filter_resize_contro_0/ingr_stat_frame_0]
  connect_bd_net -net filter_krnl_0_stat_ingr_rcv_frame_ap_vld [get_bd_pins filter_krnl_0/stat_ingr_rcv_frame_ap_vld] [get_bd_pins filter_resize_contro_0/ingr_stat_frame_0_vld]
  connect_bd_net -net filter_krnl_1_rcv_req [get_bd_pins filter_krnl_1/rcv_req] [get_bd_pins filter_resize_contro_0/rx_rcv_req_1]
  connect_bd_net -net filter_krnl_1_stat_egr_snd_frame [get_bd_pins filter_krnl_1/stat_egr_snd_frame] [get_bd_pins filter_resize_contro_0/egr_stat_frame_1]
  connect_bd_net -net filter_krnl_1_stat_egr_snd_frame_ap_vld [get_bd_pins filter_krnl_1/stat_egr_snd_frame_ap_vld] [get_bd_pins filter_resize_contro_0/egr_stat_frame_1_vld]
  connect_bd_net -net filter_krnl_1_stat_ingr_rcv_frame [get_bd_pins filter_krnl_1/stat_ingr_rcv_frame] [get_bd_pins filter_resize_contro_0/ingr_stat_frame_1]
  connect_bd_net -net filter_krnl_1_stat_ingr_rcv_frame_ap_vld [get_bd_pins filter_krnl_1/stat_ingr_rcv_frame_ap_vld] [get_bd_pins filter_resize_contro_0/ingr_stat_frame_1_vld]
  connect_bd_net -net filter_krnl_rcv_cid_diff [get_bd_pins filter_krnl_0/rcv_cid_diff] [get_bd_pins filter_resize_contro_0/rx_rcv_cid_diff_0]
  connect_bd_net -net filter_krnl_rcv_data [get_bd_pins filter_krnl_0/rcv_data] [get_bd_pins filter_resize_contro_0/rx_rcv_data_0]
  connect_bd_net -net filter_krnl_rcv_length_chk [get_bd_pins filter_krnl_0/rcv_length_chk] [get_bd_pins filter_resize_contro_0/rx_rcv_length_chk_0]
  connect_bd_net -net filter_krnl_rcv_line_chk [get_bd_pins filter_krnl_0/rcv_line_chk] [get_bd_pins filter_resize_contro_0/rx_rcv_line_chk_0]
  connect_bd_net -net filter_krnl_rcv_resp [get_bd_pins filter_krnl_0/rcv_resp] [get_bd_pins filter_resize_contro_0/tx_rcv_resp_0]
  connect_bd_net -net filter_krnl_rcv_sof [get_bd_pins filter_krnl_0/rcv_sof] [get_bd_pins filter_resize_contro_0/rx_rcv_sof_0]
  connect_bd_net -net filter_krnl_snd_data [get_bd_pins filter_krnl_0/snd_data] [get_bd_pins filter_resize_contro_0/tx_snd_data_0]
  connect_bd_net -net filter_krnl_snd_req [get_bd_pins filter_krnl_0/snd_req] [get_bd_pins filter_resize_contro_0/tx_snd_req_0]
  connect_bd_net -net filter_krnl_snd_resp [get_bd_pins filter_krnl_0/snd_resp] [get_bd_pins filter_resize_contro_0/rx_snd_resp_0]
  connect_bd_net -net filter_krnl_stat_egr_snd_data [get_bd_pins filter_krnl_0/stat_egr_snd_data] [get_bd_pins filter_resize_contro_0/egr_stat_data_0]
  connect_bd_net -net filter_krnl_stat_egr_snd_data_ap_vld [get_bd_pins filter_krnl_0/stat_egr_snd_data_ap_vld] [get_bd_pins filter_resize_contro_0/egr_stat_data_0_vld]
  connect_bd_net -net filter_krnl_stat_ingr_rcv_data [get_bd_pins filter_krnl_0/stat_ingr_rcv_data] [get_bd_pins filter_resize_contro_0/ingr_stat_data_0]
  connect_bd_net -net filter_krnl_stat_ingr_rcv_data_ap_vld [get_bd_pins filter_krnl_0/stat_ingr_rcv_data_ap_vld] [get_bd_pins filter_resize_contro_0/ingr_stat_data_0_vld]
  connect_bd_net -net filter_resize_contro_0_ap_start [get_bd_pins filter_resize_contro_0/ap_start] [get_bd_pins filter_krnl_0/ap_start] [get_bd_pins filter_krnl_1/ap_start]
  connect_bd_net -net filter_resize_contro_0_cols_in [get_bd_pins filter_resize_contro_0/cols_in] [get_bd_pins filter_krnl_0/cols_in] [get_bd_pins filter_krnl_1/cols_in]
  connect_bd_net -net filter_resize_contro_0_cols_out [get_bd_pins filter_resize_contro_0/cols_out] [get_bd_pins filter_krnl_0/cols_out] [get_bd_pins filter_krnl_1/cols_out]
  connect_bd_net -net filter_resize_contro_0_detect_fault [get_bd_pins filter_resize_contro_0/detect_fault] [get_bd_ports detect_fault]
  connect_bd_net -net filter_resize_contro_0_rows_in [get_bd_pins filter_resize_contro_0/rows_in] [get_bd_pins filter_krnl_0/rows_in] [get_bd_pins filter_krnl_1/rows_in]
  connect_bd_net -net filter_resize_contro_0_rows_out [get_bd_pins filter_resize_contro_0/rows_out] [get_bd_pins filter_krnl_0/rows_out] [get_bd_pins filter_krnl_1/rows_out]
  connect_bd_net -net filter_resize_id_0_filter_resize_local_version [get_bd_pins filter_resize_id_0/filter_resize_local_version] [get_bd_pins filter_resize_contro_0/local_version]
  connect_bd_net -net filter_resize_id_0_filter_resize_module_id [get_bd_pins filter_resize_id_0/filter_resize_module_id] [get_bd_pins filter_resize_contro_0/module_id]
  connect_bd_net -net ingr_monitor_protocol_0_protocol_error [get_bd_pins ingr_monitor_protocol_0/protocol_error] [get_bd_pins filter_resize_contro_0/ingr_protocol_error_0]
  connect_bd_net -net ingr_monitor_protocol_0_protocol_error_ap_vld [get_bd_pins ingr_monitor_protocol_0/protocol_error_ap_vld] [get_bd_pins filter_resize_contro_0/ingr_protocol_error_0_vld]
  connect_bd_net -net ingr_monitor_protocol_1_protocol_error [get_bd_pins ingr_monitor_protocol_1/protocol_error] [get_bd_pins filter_resize_contro_0/ingr_protocol_error_1]
  connect_bd_net -net ingr_monitor_protocol_1_protocol_error_ap_vld [get_bd_pins ingr_monitor_protocol_1/protocol_error_ap_vld] [get_bd_pins filter_resize_contro_0/ingr_protocol_error_1_vld]
  connect_bd_net -net insert_protocol_fault_1 [get_bd_pins filter_resize_contro_0/insert_protocol_fault_resp_0] [get_bd_pins filter_krnl_0/insert_protocol_fault]
  connect_bd_net -net insert_protocol_fault_2 [get_bd_pins filter_resize_contro_0/insert_protocol_fault_resp_1] [get_bd_pins filter_krnl_1/insert_protocol_fault]
  connect_bd_net -net insert_protocol_fault_data_1 [get_bd_pins filter_resize_contro_0/insert_protocol_fault_data_0] [get_bd_pins filter_krnl_0/insert_protocol_fault_data]
  connect_bd_net -net insert_protocol_fault_data_2 [get_bd_pins filter_resize_contro_0/insert_protocol_fault_data_1] [get_bd_pins filter_krnl_1/insert_protocol_fault_data]
  connect_bd_net -net insert_protocol_fault_req_1 [get_bd_pins filter_resize_contro_0/insert_protocol_fault_req_0] [get_bd_pins filter_krnl_0/insert_protocol_fault_req]
  connect_bd_net -net insert_protocol_fault_req_2 [get_bd_pins filter_resize_contro_0/insert_protocol_fault_req_1] [get_bd_pins filter_krnl_1/insert_protocol_fault_req]
  connect_bd_net -net streamif_stall_0_1 [get_bd_ports streamif_stall] [get_bd_pins filter_resize_contro_0/streamif_stall]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x00001000 -target_address_space [get_bd_addr_spaces s_axi_control] [get_bd_addr_segs filter_resize_contro_0/interface_aximm/reg0] -force


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


