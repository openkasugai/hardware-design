#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

################################################################
# This is a generated script based on design: chain_control_bd
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
# source chain_control_bd_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# func_latency, chain_control_control_s_axi, chain_control_egr_concat_reg_out, egr_latency, cc_egr_monitor_protocol, chain_control_egr_concat_reg_in, ingr_latency, ingr_latency, chain_control_ingr_concat_reg_in, cc_ingr_monitor_protocol, chain_control_ingr_concat_reg_out, ingr_event

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
set design_name chain_control_bd

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
xilinx.com:hls:cs_ctrl_id:1.0\
xilinx.com:hls:select_stream_nw:1.0\
xilinx.com:hls:term_evt:1.0\
xilinx.com:ip:axis_register_slice:1.1\
xilinx.com:hls:egr_term:1.0\
xilinx.com:hls:term_update_req_egr_fw:1.0\
xilinx.com:hls:term_update_resp_egr_fw:1.0\
xilinx.com:hls:egr_hdr_ins:1.0\
xilinx.com:hls:egr_write:1.0\
xilinx.com:hls:egr_forward:1.0\
xilinx.com:hls:egr_resp:1.0\
xilinx.com:hls:ht_egr_fw:1.0\
xilinx.com:hls:ht_ingr_fw:1.0\
xilinx.com:hls:ingr_hdr_rmv:1.0\
xilinx.com:hls:ingr_read:1.0\
xilinx.com:hls:ingr_req:1.0\
xilinx.com:hls:ingr_stall:1.0\
xilinx.com:hls:ingr_term:1.0\
xilinx.com:hls:term_update_req_ingr_fw:1.0\
xilinx.com:hls:term_update_resp_ingr_fw:1.0\
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
func_latency\
chain_control_control_s_axi\
chain_control_egr_concat_reg_out\
egr_latency\
cc_egr_monitor_protocol\
chain_control_egr_concat_reg_in\
ingr_latency\
ingr_latency\
chain_control_ingr_concat_reg_in\
cc_ingr_monitor_protocol\
chain_control_ingr_concat_reg_out\
ingr_event\
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


# Hierarchical cell: ingr
proc create_hier_cell_ingr { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_ingr() - Empty argument(s)!"}
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
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 rcv_nxt_update_req_estab_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 rcv_nxt_update_req_estab_1

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 rcv_nxt_update_req_receive_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 rcv_nxt_update_req_receive_1

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 ingr_session_req

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 ingr_session_resp

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_gmem_extif0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_gmem_extif1

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 ingr_session_data

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 ingr_cmd_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 ingr_cmd_1

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 header_req

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 header_data

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 ingr_header_rmv_done


  # Create pins
  create_bd_pin -dir I -type clk ap_clk
  create_bd_pin -dir I -type rst ap_rst_n
  create_bd_pin -dir I -from 1023 -to 0 reg_out
  create_bd_pin -dir O -from 2047 -to 0 reg_in

  # Create instance: ht_ingr_fw, and set properties
  set ht_ingr_fw [ create_bd_cell -type ip -vlnv xilinx.com:hls:ht_ingr_fw:1.0 ht_ingr_fw ]

  # Create instance: ingr_hdr_rmv, and set properties
  set ingr_hdr_rmv [ create_bd_cell -type ip -vlnv xilinx.com:hls:ingr_hdr_rmv:1.0 ingr_hdr_rmv ]

  # Create instance: ingr_read, and set properties
  set ingr_read [ create_bd_cell -type ip -vlnv xilinx.com:hls:ingr_read:1.0 ingr_read ]

  # Create instance: ingr_req, and set properties
  set ingr_req [ create_bd_cell -type ip -vlnv xilinx.com:hls:ingr_req:1.0 ingr_req ]

  # Create instance: ingr_stall, and set properties
  set ingr_stall [ create_bd_cell -type ip -vlnv xilinx.com:hls:ingr_stall:1.0 ingr_stall ]

  # Create instance: ingr_term, and set properties
  set ingr_term [ create_bd_cell -type ip -vlnv xilinx.com:hls:ingr_term:1.0 ingr_term ]

  # Create instance: term_update_req_ingr_fw, and set properties
  set term_update_req_ingr_fw [ create_bd_cell -type ip -vlnv xilinx.com:hls:term_update_req_ingr_fw:1.0 term_update_req_ingr_fw ]

  # Create instance: term_update_resp_ingr_fw, and set properties
  set term_update_resp_ingr_fw [ create_bd_cell -type ip -vlnv xilinx.com:hls:term_update_resp_ingr_fw:1.0 term_update_resp_ingr_fw ]

  # Create instance: ingr_latency_0, and set properties
  set block_name ingr_latency
  set block_cell_name ingr_latency_0
  if { [catch {set ingr_latency_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $ingr_latency_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: ingr_latency_1, and set properties
  set block_name ingr_latency
  set block_cell_name ingr_latency_1
  if { [catch {set ingr_latency_1 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $ingr_latency_1 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: ingr_concat_reg_in, and set properties
  set block_name chain_control_ingr_concat_reg_in
  set block_cell_name ingr_concat_reg_in
  if { [catch {set ingr_concat_reg_in [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $ingr_concat_reg_in eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: cc_ingr_monitor_protocol, and set properties
  set block_name cc_ingr_monitor_protocol
  set block_cell_name cc_ingr_monitor_protocol
  if { [catch {set cc_ingr_monitor_protocol [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $cc_ingr_monitor_protocol eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: ingr_concat_reg_out, and set properties
  set block_name chain_control_ingr_concat_reg_out
  set block_cell_name ingr_concat_reg_out
  if { [catch {set ingr_concat_reg_out [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $ingr_concat_reg_out eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: ingr_event, and set properties
  set block_name ingr_event
  set block_cell_name ingr_event
  if { [catch {set ingr_event [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $ingr_event eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins ingr_req/ingr_session_req] [get_bd_intf_pins ingr_session_req]
  connect_bd_intf_net -intf_net [get_bd_intf_nets Conn1] [get_bd_intf_pins ingr_req/ingr_session_req] [get_bd_intf_pins cc_ingr_monitor_protocol/req]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins ingr_read/ingr_session_resp] [get_bd_intf_pins ingr_session_resp]
  connect_bd_intf_net -intf_net [get_bd_intf_nets Conn2] [get_bd_intf_pins ingr_read/ingr_session_resp] [get_bd_intf_pins cc_ingr_monitor_protocol/resp]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins ingr_read/m_axi_gmem_extif0] [get_bd_intf_pins m_axi_gmem_extif0]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins ingr_read/m_axi_gmem_extif1] [get_bd_intf_pins m_axi_gmem_extif1]
  connect_bd_intf_net -intf_net Conn5 [get_bd_intf_pins ingr_read/ingr_session_data] [get_bd_intf_pins ingr_session_data]
  connect_bd_intf_net -intf_net [get_bd_intf_nets Conn5] [get_bd_intf_pins ingr_read/ingr_session_data] [get_bd_intf_pins cc_ingr_monitor_protocol/data]
  connect_bd_intf_net -intf_net Conn6 [get_bd_intf_pins ingr_read/ingr_cmd_0] [get_bd_intf_pins ingr_cmd_0]
  connect_bd_intf_net -intf_net [get_bd_intf_nets Conn6] [get_bd_intf_pins ingr_read/ingr_cmd_0] [get_bd_intf_pins ingr_latency_0/ingr_cmd]
  connect_bd_intf_net -intf_net Conn7 [get_bd_intf_pins ingr_read/ingr_cmd_1] [get_bd_intf_pins ingr_cmd_1]
  connect_bd_intf_net -intf_net [get_bd_intf_nets Conn7] [get_bd_intf_pins ingr_read/ingr_cmd_1] [get_bd_intf_pins ingr_latency_1/ingr_cmd]
  connect_bd_intf_net -intf_net Conn8 [get_bd_intf_pins ingr_hdr_rmv/header_req] [get_bd_intf_pins header_req]
  connect_bd_intf_net -intf_net Conn9 [get_bd_intf_pins ingr_hdr_rmv/header_data] [get_bd_intf_pins header_data]
  connect_bd_intf_net -intf_net Conn10 [get_bd_intf_pins ingr_hdr_rmv/ingr_header_rmv_done] [get_bd_intf_pins ingr_header_rmv_done]
  connect_bd_intf_net -intf_net ht_ingr_fw_0_m_axis_lup_rsp [get_bd_intf_pins ht_ingr_fw/m_axis_lup_rsp] [get_bd_intf_pins ingr_req/ingr_forward_lookup_resp]
  connect_bd_intf_net -intf_net ht_ingr_fw_0_m_axis_read_rsp [get_bd_intf_pins ht_ingr_fw/m_axis_read_rsp] [get_bd_intf_pins term_update_resp_ingr_fw/read_resp]
  connect_bd_intf_net -intf_net ht_ingr_fw_0_m_axis_upd_rsp [get_bd_intf_pins ht_ingr_fw/m_axis_upd_rsp] [get_bd_intf_pins term_update_resp_ingr_fw/update_resp]
  connect_bd_intf_net -intf_net ingr_event_ingr_done [get_bd_intf_pins ingr_event/ingr_done] [get_bd_intf_pins ingr_stall/ingr_done]
  connect_bd_intf_net -intf_net ingr_event_ingr_receive [get_bd_intf_pins ingr_event/ingr_receive] [get_bd_intf_pins ingr_term/ingr_receive]
  connect_bd_intf_net -intf_net ingr_hdr_rmv_ingr_payload_len [get_bd_intf_pins ingr_hdr_rmv/ingr_payload_len] [get_bd_intf_pins ingr_event/ingr_payload_len]
  connect_bd_intf_net -intf_net ingr_read_ingr_header_channel [get_bd_intf_pins ingr_read/ingr_header_channel] [get_bd_intf_pins ingr_hdr_rmv/ingr_header_channel]
  connect_bd_intf_net -intf_net ingr_read_ingr_header_data [get_bd_intf_pins ingr_read/ingr_header_data] [get_bd_intf_pins ingr_hdr_rmv/ingr_header_data]
  connect_bd_intf_net -intf_net ingr_read_ingr_usr_read_update_req [get_bd_intf_pins ingr_read/ingr_usr_read_update_req] [get_bd_intf_pins ingr_event/ingr_usr_read_update_req]
  connect_bd_intf_net -intf_net ingr_req_ingr_send [get_bd_intf_pins ingr_req/ingr_send] [get_bd_intf_pins ingr_read/ingr_send]
  connect_bd_intf_net -intf_net ingr_stall_ingr_start [get_bd_intf_pins ingr_stall/ingr_start] [get_bd_intf_pins ingr_event/ingr_start]
  connect_bd_intf_net -intf_net ingr_term_ingr_forward_lookup_req [get_bd_intf_pins ingr_term/ingr_forward_lookup_req] [get_bd_intf_pins ht_ingr_fw/s_axis_lup_req]
  connect_bd_intf_net -intf_net ingr_term_ingr_lookup_req [get_bd_intf_pins ingr_term/ingr_lookup_req] [get_bd_intf_pins ingr_req/ingr_lookup_req]
  connect_bd_intf_net -intf_net rcv_nxt_update_req_estab_0_1 [get_bd_intf_pins rcv_nxt_update_req_estab_0] [get_bd_intf_pins ingr_event/rcv_nxt_update_req_estab_0]
  connect_bd_intf_net -intf_net rcv_nxt_update_req_estab_1_1 [get_bd_intf_pins rcv_nxt_update_req_estab_1] [get_bd_intf_pins ingr_event/rcv_nxt_update_req_estab_1]
  connect_bd_intf_net -intf_net rcv_nxt_update_req_receive_0_1 [get_bd_intf_pins rcv_nxt_update_req_receive_0] [get_bd_intf_pins ingr_event/rcv_nxt_update_req_receive_0]
  connect_bd_intf_net -intf_net [get_bd_intf_nets rcv_nxt_update_req_receive_0_1] [get_bd_intf_pins rcv_nxt_update_req_receive_0] [get_bd_intf_pins ingr_latency_0/rcv_nxt_update_req_receive]
  connect_bd_intf_net -intf_net rcv_nxt_update_req_receive_1_1 [get_bd_intf_pins rcv_nxt_update_req_receive_1] [get_bd_intf_pins ingr_event/rcv_nxt_update_req_receive_1]
  connect_bd_intf_net -intf_net [get_bd_intf_nets rcv_nxt_update_req_receive_1_1] [get_bd_intf_pins rcv_nxt_update_req_receive_1] [get_bd_intf_pins ingr_latency_1/rcv_nxt_update_req_receive]
  connect_bd_intf_net -intf_net term_update_req_ingr_fw_st_update_read [get_bd_intf_pins term_update_req_ingr_fw/st_update_read] [get_bd_intf_pins ht_ingr_fw/s_axis_read_req]
  connect_bd_intf_net -intf_net term_update_req_ingr_fw_st_update_req [get_bd_intf_pins term_update_req_ingr_fw/st_update_req] [get_bd_intf_pins ht_ingr_fw/s_axis_upd_req]

  # Create port connections
  connect_bd_net -net ap_clk_0_1 [get_bd_pins ap_clk] [get_bd_pins ht_ingr_fw/ap_clk] [get_bd_pins ingr_hdr_rmv/ap_clk] [get_bd_pins ingr_read/ap_clk] [get_bd_pins ingr_req/ap_clk] [get_bd_pins ingr_stall/ap_clk] [get_bd_pins ingr_term/ap_clk] [get_bd_pins term_update_req_ingr_fw/ap_clk] [get_bd_pins term_update_resp_ingr_fw/ap_clk] [get_bd_pins ingr_latency_0/ap_clk] [get_bd_pins ingr_latency_1/ap_clk] [get_bd_pins cc_ingr_monitor_protocol/ap_clk] [get_bd_pins ingr_event/ap_clk]
  connect_bd_net -net ap_rst_n_0_1 [get_bd_pins ap_rst_n] [get_bd_pins ht_ingr_fw/ap_rst_n] [get_bd_pins ingr_hdr_rmv/ap_rst_n] [get_bd_pins ingr_read/ap_rst_n] [get_bd_pins ingr_req/ap_rst_n] [get_bd_pins ingr_stall/ap_rst_n] [get_bd_pins ingr_term/ap_rst_n] [get_bd_pins term_update_req_ingr_fw/ap_rst_n] [get_bd_pins term_update_resp_ingr_fw/ap_rst_n] [get_bd_pins ingr_latency_0/ap_rst_n] [get_bd_pins ingr_latency_1/ap_rst_n] [get_bd_pins cc_ingr_monitor_protocol/ap_rst_n] [get_bd_pins ingr_event/ap_rst_n]
  connect_bd_net -net cc_ingr_monitor_prot_0_protocol_error [get_bd_pins cc_ingr_monitor_protocol/protocol_error] [get_bd_pins ingr_concat_reg_in/ingr_snd_protocol_fault]
  connect_bd_net -net cc_ingr_monitor_prot_0_protocol_error_ap_vld [get_bd_pins cc_ingr_monitor_protocol/protocol_error_ap_vld] [get_bd_pins ingr_concat_reg_in/ingr_snd_protocol_fault_ap_vld]
  connect_bd_net -net chain_control_ingr_c_0_reg_in [get_bd_pins ingr_concat_reg_in/reg_in] [get_bd_pins reg_in]
  connect_bd_net -net ht_ingr_fw_detect_fault [get_bd_pins ht_ingr_fw/detect_fault] [get_bd_pins ingr_concat_reg_in/ht_ingr_fw_fault]
  connect_bd_net -net ht_ingr_fw_detect_fault_ap_vld [get_bd_pins ht_ingr_fw/detect_fault_ap_vld] [get_bd_pins ingr_concat_reg_in/ht_ingr_fw_fault_ap_vld]
  connect_bd_net -net ingr_concat_reg_out_ap_start [get_bd_pins ingr_concat_reg_out/ap_start] [get_bd_pins ingr_stall/ap_start_r]
  connect_bd_net -net ingr_concat_reg_out_dbg_sel_session [get_bd_pins ingr_concat_reg_out/dbg_sel_session] [get_bd_pins ingr_event/dbg_sel_session]
  connect_bd_net -net ingr_concat_reg_out_extif0_insert_command_fault [get_bd_pins ingr_concat_reg_out/extif0_insert_command_fault] [get_bd_pins ingr_read/insert_command_fault_0]
  connect_bd_net -net ingr_concat_reg_out_extif1_insert_command_fault [get_bd_pins ingr_concat_reg_out/extif1_insert_command_fault] [get_bd_pins ingr_read/insert_command_fault_1]
  connect_bd_net -net ingr_concat_reg_out_ht_ingr_fw_insert_fault [get_bd_pins ingr_concat_reg_out/ht_ingr_fw_insert_fault] [get_bd_pins ht_ingr_fw/insert_fault]
  connect_bd_net -net ingr_concat_reg_out_ingr_event_insert_fault [get_bd_pins ingr_concat_reg_out/ingr_event_insert_fault] [get_bd_pins ingr_event/ingr_rcv_insert_fault]
  connect_bd_net -net ingr_concat_reg_out_ingr_forward_channel [get_bd_pins ingr_concat_reg_out/ingr_forward_channel] [get_bd_pins term_update_req_ingr_fw/update_value]
  connect_bd_net -net ingr_concat_reg_out_ingr_forward_session [get_bd_pins ingr_concat_reg_out/ingr_forward_session] [get_bd_pins term_update_req_ingr_fw/update_key]
  connect_bd_net -net ingr_concat_reg_out_ingr_forward_update_req [get_bd_pins ingr_concat_reg_out/ingr_forward_update_req] [get_bd_pins term_update_req_ingr_fw/update_req]
  connect_bd_net -net ingr_concat_reg_out_ingr_insert_protocl_fault [get_bd_pins ingr_concat_reg_out/ingr_insert_protocl_fault] [get_bd_pins ingr_read/insert_protocol_fault] [get_bd_pins ingr_req/insert_protocol_fault]
  connect_bd_net -net ingr_concat_reg_out_m_axi_extif0_buffer_base [get_bd_pins ingr_concat_reg_out/m_axi_extif0_buffer_base] [get_bd_pins ingr_read/m_axi_extif0_buffer]
  connect_bd_net -net ingr_concat_reg_out_m_axi_extif0_buffer_rx_offset [get_bd_pins ingr_concat_reg_out/m_axi_extif0_buffer_rx_offset] [get_bd_pins ingr_read/m_axi_extif0_buffer_rx_offset]
  connect_bd_net -net ingr_concat_reg_out_m_axi_extif0_buffer_rx_size [get_bd_pins ingr_concat_reg_out/m_axi_extif0_buffer_rx_size] [get_bd_pins ingr_read/m_axi_extif0_buffer_rx_size]
  connect_bd_net -net ingr_concat_reg_out_m_axi_extif0_buffer_rx_stride [get_bd_pins ingr_concat_reg_out/m_axi_extif0_buffer_rx_stride] [get_bd_pins ingr_read/m_axi_extif0_buffer_rx_stride]
  connect_bd_net -net ingr_concat_reg_out_m_axi_extif1_buffer_base [get_bd_pins ingr_concat_reg_out/m_axi_extif1_buffer_base] [get_bd_pins ingr_read/m_axi_extif1_buffer]
  connect_bd_net -net ingr_concat_reg_out_m_axi_extif1_buffer_rx_offset [get_bd_pins ingr_concat_reg_out/m_axi_extif1_buffer_rx_offset] [get_bd_pins ingr_read/m_axi_extif1_buffer_rx_offset]
  connect_bd_net -net ingr_concat_reg_out_m_axi_extif1_buffer_rx_size [get_bd_pins ingr_concat_reg_out/m_axi_extif1_buffer_rx_size] [get_bd_pins ingr_read/m_axi_extif1_buffer_rx_size]
  connect_bd_net -net ingr_concat_reg_out_m_axi_extif1_buffer_rx_stride [get_bd_pins ingr_concat_reg_out/m_axi_extif1_buffer_rx_stride] [get_bd_pins ingr_read/m_axi_extif1_buffer_rx_stride]
  connect_bd_net -net ingr_concat_reg_out_stat_sel_session [get_bd_pins ingr_concat_reg_out/stat_sel_session] [get_bd_pins ingr_event/stat_sel_session]
  connect_bd_net -net ingr_event_extif_session_status [get_bd_pins ingr_event/extif_session_status] [get_bd_pins ingr_concat_reg_in/extif_session_status]
  connect_bd_net -net ingr_event_ingr_last_ptr [get_bd_pins ingr_event/ingr_last_ptr] [get_bd_pins ingr_concat_reg_in/ingr_last_ptr]
  connect_bd_net -net ingr_event_ingr_rcv_detect_fault [get_bd_pins ingr_event/ingr_rcv_detect_fault] [get_bd_pins ingr_concat_reg_in/ingr_event_fault]
  connect_bd_net -net ingr_event_ingr_rcv_detect_fault_vld [get_bd_pins ingr_event/ingr_rcv_detect_fault_vld] [get_bd_pins ingr_concat_reg_in/ingr_event_fault_vld]
  connect_bd_net -net ingr_event_rcv_nxt_update_resp_count [get_bd_pins ingr_event/rcv_nxt_update_resp_count] [get_bd_pins ingr_concat_reg_in/rcv_nxt_update_resp_count]
  connect_bd_net -net ingr_event_rx_head_update_resp_count [get_bd_pins ingr_event/rx_head_update_resp_count] [get_bd_pins ingr_concat_reg_in/rx_head_update_resp_count]
  connect_bd_net -net ingr_event_rx_tail_update_resp_count [get_bd_pins ingr_event/rx_tail_update_resp_count] [get_bd_pins ingr_concat_reg_in/rx_tail_update_resp_count]
  connect_bd_net -net ingr_event_stat_ingr_rcv_data [get_bd_pins ingr_event/stat_ingr_rcv_data] [get_bd_pins ingr_concat_reg_in/stat_ingr_rcv_data_data]
  connect_bd_net -net ingr_event_stat_ingr_rcv_data_vld [get_bd_pins ingr_event/stat_ingr_rcv_data_vld] [get_bd_pins ingr_concat_reg_in/stat_ingr_rcv_data_valid]
  connect_bd_net -net ingr_event_usr_read_update_resp_count [get_bd_pins ingr_event/usr_read_update_resp_count] [get_bd_pins ingr_concat_reg_in/usr_read_update_resp_count]
  connect_bd_net -net ingr_hdr_rmv_detect_fault [get_bd_pins ingr_hdr_rmv/detect_fault] [get_bd_pins ingr_concat_reg_in/ingr_hdr_rmv_fault]
  connect_bd_net -net ingr_hdr_rmv_detect_fault_ap_vld [get_bd_pins ingr_hdr_rmv/detect_fault_ap_vld] [get_bd_pins ingr_concat_reg_in/ingr_hdr_rmv_fault_ap_vld]
  connect_bd_net -net ingr_hdr_rmv_header_buff_usage [get_bd_pins ingr_hdr_rmv/header_buff_usage] [get_bd_pins ingr_concat_reg_in/header_buff_usage] [get_bd_pins ingr_event/header_buff_usage]
  connect_bd_net -net ingr_hdr_rmv_header_buff_usage_ap_vld [get_bd_pins ingr_hdr_rmv/header_buff_usage_ap_vld] [get_bd_pins ingr_concat_reg_in/header_buff_usage_ap_vld] [get_bd_pins ingr_event/header_buff_usage_ap_vld]
  connect_bd_net -net ingr_latency_0_ingr_latency_data [get_bd_pins ingr_latency_0/ingr_latency_data] [get_bd_pins ingr_concat_reg_in/ingr_latency_0_data]
  connect_bd_net -net ingr_latency_0_ingr_latency_valid [get_bd_pins ingr_latency_0/ingr_latency_valid] [get_bd_pins ingr_concat_reg_in/ingr_latency_0_valid]
  connect_bd_net -net ingr_latency_1_ingr_latency_data [get_bd_pins ingr_latency_1/ingr_latency_data] [get_bd_pins ingr_concat_reg_in/ingr_latency_1_data]
  connect_bd_net -net ingr_latency_1_ingr_latency_valid [get_bd_pins ingr_latency_1/ingr_latency_valid] [get_bd_pins ingr_concat_reg_in/ingr_latency_1_valid]
  connect_bd_net -net ingr_read_stat_ingr_discard [get_bd_pins ingr_read/stat_ingr_discard] [get_bd_pins ingr_concat_reg_in/stat_ingr_discard_data]
  connect_bd_net -net ingr_read_stat_ingr_discard_ap_vld [get_bd_pins ingr_read/stat_ingr_discard_ap_vld] [get_bd_pins ingr_concat_reg_in/stat_ingr_discard_data_ap_vld]
  connect_bd_net -net ingr_read_stat_ingr_snd_data [get_bd_pins ingr_read/stat_ingr_snd_data] [get_bd_pins ingr_concat_reg_in/stat_ingr_snd_data]
  connect_bd_net -net ingr_read_stat_ingr_snd_data_ap_vld [get_bd_pins ingr_read/stat_ingr_snd_data_ap_vld] [get_bd_pins ingr_concat_reg_in/stat_ingr_snd_data_ap_vld]
  connect_bd_net -net ingr_read_stat_ingr_snd_frame [get_bd_pins ingr_read/stat_ingr_snd_frame] [get_bd_pins ingr_concat_reg_in/stat_ingr_snd_frame]
  connect_bd_net -net ingr_read_stat_ingr_snd_frame_ap_vld [get_bd_pins ingr_read/stat_ingr_snd_frame_ap_vld] [get_bd_pins ingr_concat_reg_in/stat_ingr_snd_frame_ap_vld]
  connect_bd_net -net ingr_req_ingr_forward_mishit [get_bd_pins ingr_req/ingr_forward_mishit] [get_bd_pins ingr_concat_reg_in/ingr_forward_mishit]
  connect_bd_net -net ingr_req_ingr_forward_mishit_ap_vld [get_bd_pins ingr_req/ingr_forward_mishit_ap_vld] [get_bd_pins ingr_concat_reg_in/ingr_forward_mishit_ap_vld]
  connect_bd_net -net reg_out_0_1 [get_bd_pins reg_out] [get_bd_pins ingr_concat_reg_out/reg_out]
  connect_bd_net -net term_update_resp_ingr_fw_resp [get_bd_pins term_update_resp_ingr_fw/resp] [get_bd_pins ingr_concat_reg_in/ingr_forward_update_resp]
  connect_bd_net -net term_update_resp_ingr_fw_resp_count [get_bd_pins term_update_resp_ingr_fw/resp_count] [get_bd_pins ingr_concat_reg_in/ingr_forward_update_resp_count]
  connect_bd_net -net term_update_resp_ingr_fw_resp_data [get_bd_pins term_update_resp_ingr_fw/resp_data] [get_bd_pins ingr_concat_reg_in/ingr_forward_update_resp_data]
  connect_bd_net -net term_update_resp_ingr_fw_resp_data_ap_vld [get_bd_pins term_update_resp_ingr_fw/resp_data_ap_vld] [get_bd_pins ingr_concat_reg_in/ingr_forward_update_resp_data_ap_vld]
  connect_bd_net -net term_update_resp_ingr_fw_resp_fail_count [get_bd_pins term_update_resp_ingr_fw/resp_fail_count] [get_bd_pins ingr_concat_reg_in/ingr_forward_update_resp_fail_count]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: egr
proc create_hier_cell_egr { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_egr() - Empty argument(s)!"}
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
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_egr_rx_data

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 egr_session_req

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 snd_una_update_req_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 evt_usr_wrt_update_req_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 snd_una_update_req_1

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 evt_usr_wrt_update_req_1

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 egr_session_resp

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 header_req

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 header_data

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 egr_header_ins_done

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_gmem_extif0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_gmem_extif1

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 egr_cmd_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 egr_cmd_1


  # Create pins
  create_bd_pin -dir I -type clk ap_clk
  create_bd_pin -dir I -type rst ap_rst_n
  create_bd_pin -dir I -from 1023 -to 0 reg_out
  create_bd_pin -dir O -from 2047 -to 0 reg_in

  # Create instance: egr_concat_reg_out, and set properties
  set block_name chain_control_egr_concat_reg_out
  set block_cell_name egr_concat_reg_out
  if { [catch {set egr_concat_reg_out [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $egr_concat_reg_out eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: egr_term, and set properties
  set egr_term [ create_bd_cell -type ip -vlnv xilinx.com:hls:egr_term:1.0 egr_term ]

  # Create instance: term_update_req_egr, and set properties
  set term_update_req_egr [ create_bd_cell -type ip -vlnv xilinx.com:hls:term_update_req_egr_fw:1.0 term_update_req_egr ]

  # Create instance: term_update_resp_egr, and set properties
  set term_update_resp_egr [ create_bd_cell -type ip -vlnv xilinx.com:hls:term_update_resp_egr_fw:1.0 term_update_resp_egr ]

  # Create instance: egr_latency, and set properties
  set block_name egr_latency
  set block_cell_name egr_latency
  if { [catch {set egr_latency [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $egr_latency eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: cc_egr_monitor_protocol, and set properties
  set block_name cc_egr_monitor_protocol
  set block_cell_name cc_egr_monitor_protocol
  if { [catch {set cc_egr_monitor_protocol [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $cc_egr_monitor_protocol eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: egr_concat_reg_in, and set properties
  set block_name chain_control_egr_concat_reg_in
  set block_cell_name egr_concat_reg_in
  if { [catch {set egr_concat_reg_in [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $egr_concat_reg_in eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: egr_hdr_ins, and set properties
  set egr_hdr_ins [ create_bd_cell -type ip -vlnv xilinx.com:hls:egr_hdr_ins:1.0 egr_hdr_ins ]

  # Create instance: egr_write, and set properties
  set egr_write [ create_bd_cell -type ip -vlnv xilinx.com:hls:egr_write:1.0 egr_write ]

  # Create instance: egr_forward, and set properties
  set egr_forward [ create_bd_cell -type ip -vlnv xilinx.com:hls:egr_forward:1.0 egr_forward ]

  # Create instance: egr_resp, and set properties
  set egr_resp [ create_bd_cell -type ip -vlnv xilinx.com:hls:egr_resp:1.0 egr_resp ]

  # Create instance: ht_egr_fw, and set properties
  set ht_egr_fw [ create_bd_cell -type ip -vlnv xilinx.com:hls:ht_egr_fw:1.0 ht_egr_fw ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins egr_hdr_ins/s_axis_egr_rx_data] [get_bd_intf_pins s_axis_egr_rx_data]
  connect_bd_intf_net -intf_net [get_bd_intf_nets Conn1] [get_bd_intf_pins egr_hdr_ins/s_axis_egr_rx_data] [get_bd_intf_pins cc_egr_monitor_protocol/data]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins egr_term/egr_session_req] [get_bd_intf_pins egr_session_req]
  connect_bd_intf_net -intf_net [get_bd_intf_nets Conn2] [get_bd_intf_pins egr_term/egr_session_req] [get_bd_intf_pins cc_egr_monitor_protocol/req]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins egr_resp/snd_una_update_req_0] [get_bd_intf_pins snd_una_update_req_0]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins egr_resp/evt_usr_wrt_update_req_0] [get_bd_intf_pins evt_usr_wrt_update_req_0]
  connect_bd_intf_net -intf_net Conn5 [get_bd_intf_pins egr_resp/snd_una_update_req_1] [get_bd_intf_pins snd_una_update_req_1]
  connect_bd_intf_net -intf_net Conn6 [get_bd_intf_pins egr_resp/evt_usr_wrt_update_req_1] [get_bd_intf_pins evt_usr_wrt_update_req_1]
  connect_bd_intf_net -intf_net Conn7 [get_bd_intf_pins egr_resp/egr_session_resp] [get_bd_intf_pins egr_session_resp]
  connect_bd_intf_net -intf_net [get_bd_intf_nets Conn7] [get_bd_intf_pins egr_resp/egr_session_resp] [get_bd_intf_pins cc_egr_monitor_protocol/resp]
  connect_bd_intf_net -intf_net Conn8 [get_bd_intf_pins egr_hdr_ins/header_req] [get_bd_intf_pins header_req]
  connect_bd_intf_net -intf_net Conn9 [get_bd_intf_pins egr_hdr_ins/header_data] [get_bd_intf_pins header_data]
  connect_bd_intf_net -intf_net Conn10 [get_bd_intf_pins egr_hdr_ins/egr_header_ins_done] [get_bd_intf_pins egr_header_ins_done]
  connect_bd_intf_net -intf_net Conn11 [get_bd_intf_pins egr_write/m_axi_gmem_extif0] [get_bd_intf_pins m_axi_gmem_extif0]
  connect_bd_intf_net -intf_net Conn12 [get_bd_intf_pins egr_write/m_axi_gmem_extif1] [get_bd_intf_pins m_axi_gmem_extif1]
  connect_bd_intf_net -intf_net Conn13 [get_bd_intf_pins egr_write/egr_cmd_0] [get_bd_intf_pins egr_cmd_0]
  connect_bd_intf_net -intf_net Conn14 [get_bd_intf_pins egr_write/egr_cmd_1] [get_bd_intf_pins egr_cmd_1]
  connect_bd_intf_net -intf_net egr_forward_egr_lookup_resp [get_bd_intf_pins egr_forward/egr_lookup_resp] [get_bd_intf_pins egr_resp/egr_lookup_resp]
  connect_bd_intf_net -intf_net egr_hdr_ins_egr_send_length [get_bd_intf_pins egr_hdr_ins/egr_send_length] [get_bd_intf_pins egr_write/egr_send_length]
  connect_bd_intf_net -intf_net egr_hdr_ins_egr_send_ptr [get_bd_intf_pins egr_hdr_ins/egr_send_ptr] [get_bd_intf_pins egr_write/egr_send_ptr]
  connect_bd_intf_net -intf_net egr_hdr_ins_egr_session_data [get_bd_intf_pins egr_hdr_ins/egr_session_data] [get_bd_intf_pins egr_write/egr_session_data]
  connect_bd_intf_net -intf_net egr_resp_egr_hdr_ins_ptr [get_bd_intf_pins egr_resp/egr_hdr_ins_ptr] [get_bd_intf_pins egr_hdr_ins/egr_hdr_ins_ptr]
  connect_bd_intf_net -intf_net egr_resp_egr_hdr_ins_req [get_bd_intf_pins egr_resp/egr_hdr_ins_req] [get_bd_intf_pins egr_hdr_ins/egr_hdr_ins_req]
  connect_bd_intf_net -intf_net egr_resp_egr_meas_start [get_bd_intf_pins egr_resp/egr_meas_start] [get_bd_intf_pins egr_latency/egr_meas_start]
  connect_bd_intf_net -intf_net egr_term_egr_forward_lookup_req [get_bd_intf_pins egr_term/egr_forward_lookup_req] [get_bd_intf_pins ht_egr_fw/s_axis_lup_req]
  connect_bd_intf_net -intf_net egr_term_egr_lookup_forward [get_bd_intf_pins egr_term/egr_lookup_forward] [get_bd_intf_pins egr_forward/egr_lookup_forward]
  connect_bd_intf_net -intf_net egr_write_egr_frame_end [get_bd_intf_pins egr_write/egr_frame_end] [get_bd_intf_pins egr_resp/egr_frame_end]
  connect_bd_intf_net -intf_net egr_write_egr_meas_end [get_bd_intf_pins egr_write/egr_meas_end] [get_bd_intf_pins egr_latency/egr_meas_end]
  connect_bd_intf_net -intf_net ht_egr_fw_m_axis_lup_rsp [get_bd_intf_pins ht_egr_fw/m_axis_lup_rsp] [get_bd_intf_pins egr_forward/egr_forward_lookup_resp]
  connect_bd_intf_net -intf_net ht_egr_fw_m_axis_read_rsp [get_bd_intf_pins ht_egr_fw/m_axis_read_rsp] [get_bd_intf_pins term_update_resp_egr/read_resp]
  connect_bd_intf_net -intf_net ht_egr_fw_m_axis_upd_rsp [get_bd_intf_pins ht_egr_fw/m_axis_upd_rsp] [get_bd_intf_pins term_update_resp_egr/update_resp]
  connect_bd_intf_net -intf_net term_update_req_egr_st_update_read [get_bd_intf_pins term_update_req_egr/st_update_read] [get_bd_intf_pins ht_egr_fw/s_axis_read_req]
  connect_bd_intf_net -intf_net term_update_req_egr_st_update_req [get_bd_intf_pins term_update_req_egr/st_update_req] [get_bd_intf_pins ht_egr_fw/s_axis_upd_req]

  # Create port connections
  connect_bd_net -net ap_clk_0_1 [get_bd_pins ap_clk] [get_bd_pins egr_term/ap_clk] [get_bd_pins term_update_req_egr/ap_clk] [get_bd_pins term_update_resp_egr/ap_clk] [get_bd_pins egr_latency/ap_clk] [get_bd_pins cc_egr_monitor_protocol/ap_clk] [get_bd_pins egr_hdr_ins/ap_clk] [get_bd_pins egr_write/ap_clk] [get_bd_pins egr_forward/ap_clk] [get_bd_pins egr_resp/ap_clk] [get_bd_pins ht_egr_fw/ap_clk]
  connect_bd_net -net ap_rst_n_0_1 [get_bd_pins ap_rst_n] [get_bd_pins egr_term/ap_rst_n] [get_bd_pins term_update_req_egr/ap_rst_n] [get_bd_pins term_update_resp_egr/ap_rst_n] [get_bd_pins egr_latency/ap_rst_n] [get_bd_pins cc_egr_monitor_protocol/ap_rst_n] [get_bd_pins egr_hdr_ins/ap_rst_n] [get_bd_pins egr_write/ap_rst_n] [get_bd_pins egr_forward/ap_rst_n] [get_bd_pins egr_resp/ap_rst_n] [get_bd_pins ht_egr_fw/ap_rst_n]
  connect_bd_net -net cc_egr_monitor_proto_0_protocol_error [get_bd_pins cc_egr_monitor_protocol/protocol_error] [get_bd_pins egr_concat_reg_in/egr_rcv_protocol_fault]
  connect_bd_net -net cc_egr_monitor_proto_0_protocol_error_ap_vld [get_bd_pins cc_egr_monitor_protocol/protocol_error_ap_vld] [get_bd_pins egr_concat_reg_in/egr_rcv_protocol_fault_ap_vld]
  connect_bd_net -net chain_control_egr_co_0_reg_in [get_bd_pins egr_concat_reg_in/reg_in] [get_bd_pins reg_in]
  connect_bd_net -net egr_concat_reg_out_egr_forward_channel [get_bd_pins egr_concat_reg_out/egr_forward_channel] [get_bd_pins term_update_req_egr/update_key]
  connect_bd_net -net egr_concat_reg_out_egr_forward_session [get_bd_pins egr_concat_reg_out/egr_forward_session] [get_bd_pins term_update_req_egr/update_value]
  connect_bd_net -net egr_concat_reg_out_egr_forward_update_req [get_bd_pins egr_concat_reg_out/egr_forward_update_req] [get_bd_pins term_update_req_egr/update_req]
  connect_bd_net -net egr_concat_reg_out_egr_hdr_ins_insert_fault [get_bd_pins egr_concat_reg_out/egr_hdr_ins_insert_fault] [get_bd_pins egr_hdr_ins/insert_fault]
  connect_bd_net -net egr_concat_reg_out_egr_rcv_insert_protocol_fault [get_bd_pins egr_concat_reg_out/egr_rcv_insert_protocol_fault] [get_bd_pins egr_resp/insert_protocol_fault]
  connect_bd_net -net egr_concat_reg_out_egr_resp_insert_fault [get_bd_pins egr_concat_reg_out/egr_resp_insert_fault] [get_bd_pins egr_resp/insert_fault]
  connect_bd_net -net egr_concat_reg_out_extif0_insert_command_fault [get_bd_pins egr_concat_reg_out/extif0_insert_command_fault] [get_bd_pins egr_write/insert_command_fault_0]
  connect_bd_net -net egr_concat_reg_out_extif1_insert_command_fault [get_bd_pins egr_concat_reg_out/extif1_insert_command_fault] [get_bd_pins egr_write/insert_command_fault_1]
  connect_bd_net -net egr_concat_reg_out_ht_egr_fw_insert_fault [get_bd_pins egr_concat_reg_out/ht_egr_fw_insert_fault] [get_bd_pins ht_egr_fw/insert_fault]
  connect_bd_net -net egr_concat_reg_out_m_axi_extif0_buffer_base [get_bd_pins egr_concat_reg_out/m_axi_extif0_buffer_base] [get_bd_pins egr_write/m_axi_extif0_buffer]
  connect_bd_net -net egr_concat_reg_out_m_axi_extif0_buffer_tx_offset [get_bd_pins egr_concat_reg_out/m_axi_extif0_buffer_tx_offset] [get_bd_pins egr_write/m_axi_extif0_buffer_tx_offset]
  connect_bd_net -net egr_concat_reg_out_m_axi_extif0_buffer_tx_stride [get_bd_pins egr_concat_reg_out/m_axi_extif0_buffer_tx_stride] [get_bd_pins egr_write/m_axi_extif0_buffer_tx_stride]
  connect_bd_net -net egr_concat_reg_out_m_axi_extif1_buffer_base [get_bd_pins egr_concat_reg_out/m_axi_extif1_buffer_base] [get_bd_pins egr_write/m_axi_extif1_buffer]
  connect_bd_net -net egr_concat_reg_out_m_axi_extif1_buffer_tx_offset [get_bd_pins egr_concat_reg_out/m_axi_extif1_buffer_tx_offset] [get_bd_pins egr_write/m_axi_extif1_buffer_tx_offset]
  connect_bd_net -net egr_concat_reg_out_m_axi_extif1_buffer_tx_stride [get_bd_pins egr_concat_reg_out/m_axi_extif1_buffer_tx_stride] [get_bd_pins egr_write/m_axi_extif1_buffer_tx_stride]
  connect_bd_net -net egr_forward_egr_forward_mishit [get_bd_pins egr_forward/egr_forward_mishit] [get_bd_pins egr_concat_reg_in/egr_forward_mishit]
  connect_bd_net -net egr_forward_egr_forward_mishit_ap_vld [get_bd_pins egr_forward/egr_forward_mishit_ap_vld] [get_bd_pins egr_concat_reg_in/egr_forward_mishit_ap_vld]
  connect_bd_net -net egr_hdr_ins_stat_egr_discard [get_bd_pins egr_hdr_ins/stat_egr_discard] [get_bd_pins egr_concat_reg_in/stat_egr_discard_data]
  connect_bd_net -net egr_hdr_ins_stat_egr_discard_ap_vld [get_bd_pins egr_hdr_ins/stat_egr_discard_ap_vld] [get_bd_pins egr_concat_reg_in/stat_egr_discard_data_ap_vld]
  connect_bd_net -net egr_latency_egr_latency_data [get_bd_pins egr_latency/egr_latency_data] [get_bd_pins egr_concat_reg_in/egr_latency_data]
  connect_bd_net -net egr_latency_egr_latency_valid [get_bd_pins egr_latency/egr_latency_valid] [get_bd_pins egr_concat_reg_in/egr_latency_valid]
  connect_bd_net -net egr_resp_dbg_lup_tx_head [get_bd_pins egr_resp/dbg_lup_tx_head] [get_bd_pins egr_concat_reg_in/dbg_lup_tx_head]
  connect_bd_net -net egr_resp_dbg_lup_tx_tail [get_bd_pins egr_resp/dbg_lup_tx_tail] [get_bd_pins egr_concat_reg_in/dbg_lup_tx_tail]
  connect_bd_net -net egr_resp_detect_fault [get_bd_pins egr_resp/detect_fault] [get_bd_pins egr_concat_reg_in/egr_resp_fault]
  connect_bd_net -net egr_resp_detect_fault_ap_vld [get_bd_pins egr_resp/detect_fault_ap_vld] [get_bd_pins egr_concat_reg_in/egr_resp_fault_ap_vld]
  connect_bd_net -net egr_resp_egr_busy_count [get_bd_pins egr_resp/egr_busy_count] [get_bd_pins egr_concat_reg_in/egr_busy_count]
  connect_bd_net -net egr_resp_egr_busy_count_ap_vld [get_bd_pins egr_resp/egr_busy_count_ap_vld] [get_bd_pins egr_concat_reg_in/egr_busy_count_ap_vld]
  connect_bd_net -net egr_resp_egr_last_ptr [get_bd_pins egr_resp/egr_last_ptr] [get_bd_pins egr_concat_reg_in/egr_last_ptr]
  connect_bd_net -net egr_resp_egr_last_ptr_ap_vld [get_bd_pins egr_resp/egr_last_ptr_ap_vld] [get_bd_pins egr_concat_reg_in/egr_last_ptr_ap_vld]
  connect_bd_net -net egr_resp_snd_una_update_resp_count [get_bd_pins egr_resp/snd_una_update_resp_count] [get_bd_pins egr_concat_reg_in/snd_una_update_resp_count]
  connect_bd_net -net egr_resp_stat_egr_rcv_frame [get_bd_pins egr_resp/stat_egr_rcv_frame] [get_bd_pins egr_concat_reg_in/stat_egr_rcv_frame]
  connect_bd_net -net egr_resp_stat_egr_rcv_frame_ap_vld [get_bd_pins egr_resp/stat_egr_rcv_frame_ap_vld] [get_bd_pins egr_concat_reg_in/stat_egr_rcv_frame_ap_vld]
  connect_bd_net -net egr_resp_stat_egr_snd_data [get_bd_pins egr_resp/stat_egr_snd_data] [get_bd_pins egr_concat_reg_in/stat_egr_snd_data]
  connect_bd_net -net egr_resp_stat_egr_snd_data_ap_vld [get_bd_pins egr_resp/stat_egr_snd_data_ap_vld] [get_bd_pins egr_concat_reg_in/stat_egr_snd_data_ap_vld]
  connect_bd_net -net egr_resp_tx_head_update_resp_count [get_bd_pins egr_resp/tx_head_update_resp_count] [get_bd_pins egr_concat_reg_in/tx_head_update_resp_count]
  connect_bd_net -net egr_resp_tx_tail_update_resp_count [get_bd_pins egr_resp/tx_tail_update_resp_count] [get_bd_pins egr_concat_reg_in/tx_tail_update_resp_count]
  connect_bd_net -net egr_resp_usr_wrt_update_resp_count [get_bd_pins egr_resp/usr_wrt_update_resp_count] [get_bd_pins egr_concat_reg_in/usr_wrt_update_resp_count]
  connect_bd_net -net egr_write_stat_egr_rcv_data [get_bd_pins egr_write/stat_egr_rcv_data] [get_bd_pins egr_concat_reg_in/stat_egr_rcv_data]
  connect_bd_net -net egr_write_stat_egr_rcv_data_ap_vld [get_bd_pins egr_write/stat_egr_rcv_data_ap_vld] [get_bd_pins egr_concat_reg_in/stat_egr_rcv_data_ap_vld]
  connect_bd_net -net ht_egr_fw_detect_fault [get_bd_pins ht_egr_fw/detect_fault] [get_bd_pins egr_concat_reg_in/ht_egr_fw_fault]
  connect_bd_net -net ht_egr_fw_detect_fault_ap_vld [get_bd_pins ht_egr_fw/detect_fault_ap_vld] [get_bd_pins egr_concat_reg_in/ht_egr_fw_fault_ap_vld]
  connect_bd_net -net m_axi_extif0_buffer_tx_size_0_1 [get_bd_pins egr_concat_reg_out/m_axi_extif0_buffer_tx_size] [get_bd_pins egr_write/m_axi_extif0_buffer_tx_size] [get_bd_pins egr_resp/m_axi_extif0_buffer_tx_size]
  connect_bd_net -net m_axi_extif1_buffer_tx_size_0_1 [get_bd_pins egr_concat_reg_out/m_axi_extif1_buffer_tx_size] [get_bd_pins egr_write/m_axi_extif1_buffer_tx_size] [get_bd_pins egr_resp/m_axi_extif1_buffer_tx_size]
  connect_bd_net -net reg_out_0_1 [get_bd_pins reg_out] [get_bd_pins egr_concat_reg_out/reg_out]
  connect_bd_net -net term_update_resp_egr_resp [get_bd_pins term_update_resp_egr/resp] [get_bd_pins egr_concat_reg_in/egr_forward_update_resp]
  connect_bd_net -net term_update_resp_egr_resp_count [get_bd_pins term_update_resp_egr/resp_count] [get_bd_pins egr_concat_reg_in/egr_forward_update_resp_count]
  connect_bd_net -net term_update_resp_egr_resp_data [get_bd_pins term_update_resp_egr/resp_data] [get_bd_pins egr_concat_reg_in/egr_forward_update_resp_data]
  connect_bd_net -net term_update_resp_egr_resp_data_ap_vld [get_bd_pins term_update_resp_egr/resp_data_ap_vld] [get_bd_pins egr_concat_reg_in/egr_forward_update_resp_data_ap_vld]
  connect_bd_net -net term_update_resp_egr_resp_fail_count [get_bd_pins term_update_resp_egr/resp_fail_count] [get_bd_pins egr_concat_reg_in/egr_forward_update_resp_fail_count]

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
  set s_axis_egr_rx_data [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_egr_rx_data ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {64} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $s_axis_egr_rx_data

  set m_axis_egr_rx_resp [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_egr_rx_resp ]

  set s_axis_egr_rx_req [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_egr_rx_req ]
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
   ] $s_axis_egr_rx_req

  set m_axis_ingr_tx_req [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_ingr_tx_req ]

  set s_axis_ingr_tx_resp [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_ingr_tx_resp ]
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
   ] $s_axis_ingr_tx_resp

  set m_axi_extif0_buffer_rd [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_extif0_buffer_rd ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {64} \
   CONFIG.DATA_WIDTH {512} \
   CONFIG.HAS_BURST {0} \
   CONFIG.NUM_READ_OUTSTANDING {16} \
   CONFIG.NUM_WRITE_OUTSTANDING {16} \
   CONFIG.PROTOCOL {AXI4} \
   CONFIG.READ_WRITE_MODE {READ_ONLY} \
   ] $m_axi_extif0_buffer_rd

  set m_axi_extif1_buffer_rd [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_extif1_buffer_rd ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {64} \
   CONFIG.DATA_WIDTH {512} \
   CONFIG.HAS_BURST {0} \
   CONFIG.NUM_READ_OUTSTANDING {16} \
   CONFIG.NUM_WRITE_OUTSTANDING {16} \
   CONFIG.PROTOCOL {AXI4} \
   CONFIG.READ_WRITE_MODE {READ_ONLY} \
   ] $m_axi_extif1_buffer_rd

  set m_axis_ingr_tx_data [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_ingr_tx_data ]

  set m_axi_extif0_buffer_wr [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_extif0_buffer_wr ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {64} \
   CONFIG.DATA_WIDTH {512} \
   CONFIG.HAS_BURST {0} \
   CONFIG.NUM_READ_OUTSTANDING {16} \
   CONFIG.NUM_WRITE_OUTSTANDING {16} \
   CONFIG.PROTOCOL {AXI4} \
   CONFIG.READ_WRITE_MODE {WRITE_ONLY} \
   ] $m_axi_extif0_buffer_wr

  set m_axi_extif1_buffer_wr [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_extif1_buffer_wr ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {64} \
   CONFIG.DATA_WIDTH {512} \
   CONFIG.HAS_BURST {0} \
   CONFIG.NUM_READ_OUTSTANDING {16} \
   CONFIG.NUM_WRITE_OUTSTANDING {16} \
   CONFIG.PROTOCOL {AXI4} \
   CONFIG.READ_WRITE_MODE {WRITE_ONLY} \
   ] $m_axi_extif1_buffer_wr

  set s_axis_extif0_evt [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_extif0_evt ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {16} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $s_axis_extif0_evt

  set s_axis_extif1_evt [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_extif1_evt ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {16} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $s_axis_extif1_evt

  set m_axis_extif0_cmd [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_extif0_cmd ]

  set m_axis_extif1_cmd [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_extif1_cmd ]

  set s_axi_control [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_control ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {12} \
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


  # Create ports
  set ap_clk [ create_bd_port -dir I -type clk ap_clk ]
  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {m_axi_extif1_buffer_wr:m_axi_extif0_buffer_wr:s_axis_egr_rx_data:m_axis_egr_rx_resp:s_axis_egr_rx_req:m_axis_ingr_tx_req:s_axis_ingr_tx_resp:m_axi_extif0_buffer_rd:m_axi_extif1_buffer_rd:m_axis_ingr_tx_data:s_axis_extif0_evt:s_axis_extif1_evt:m_axis_extif0_cmd:m_axis_extif1_cmd:s_axi_control} \
 ] $ap_clk
  set ap_rst_n [ create_bd_port -dir I -type rst ap_rst_n ]
  set detect_fault [ create_bd_port -dir O detect_fault ]
  set streamif_stall [ create_bd_port -dir I -from 9 -to 0 streamif_stall ]

  # Create instance: egr
  create_hier_cell_egr [current_bd_instance .] egr

  # Create instance: ingr
  create_hier_cell_ingr [current_bd_instance .] ingr

  # Create instance: cs_ctrl_id, and set properties
  set cs_ctrl_id [ create_bd_cell -type ip -vlnv xilinx.com:hls:cs_ctrl_id:1.0 cs_ctrl_id ]

  # Create instance: select_stream_0, and set properties
  set select_stream_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:select_stream_nw:1.0 select_stream_0 ]

  # Create instance: select_stream_1, and set properties
  set select_stream_1 [ create_bd_cell -type ip -vlnv xilinx.com:hls:select_stream_nw:1.0 select_stream_1 ]

  # Create instance: term_evt_0, and set properties
  set term_evt_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:term_evt:1.0 term_evt_0 ]

  # Create instance: term_evt_1, and set properties
  set term_evt_1 [ create_bd_cell -type ip -vlnv xilinx.com:hls:term_evt:1.0 term_evt_1 ]

  # Create instance: func_latency, and set properties
  set block_name func_latency
  set block_cell_name func_latency
  if { [catch {set func_latency [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $func_latency eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: slice_extif1_evt, and set properties
  set slice_extif1_evt [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 slice_extif1_evt ]

  # Create instance: slice_extif0_evt, and set properties
  set slice_extif0_evt [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 slice_extif0_evt ]

  # Create instance: slice_extif0_cmd, and set properties
  set slice_extif0_cmd [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 slice_extif0_cmd ]

  # Create instance: slice_extif1_cmd, and set properties
  set slice_extif1_cmd [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 slice_extif1_cmd ]

  # Create instance: control_s_axi, and set properties
  set block_name chain_control_control_s_axi
  set block_cell_name control_s_axi
  if { [catch {set control_s_axi [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $control_s_axi eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create interface connections
  connect_bd_intf_net -intf_net axis_register_slice_0_M_AXIS [get_bd_intf_pins term_evt_1/s_axis_extif_evt] [get_bd_intf_pins slice_extif1_evt/M_AXIS]
  connect_bd_intf_net -intf_net egr_egr_cmd_0 [get_bd_intf_pins select_stream_0/in_1] [get_bd_intf_pins egr/egr_cmd_0]
  connect_bd_intf_net -intf_net egr_egr_cmd_1 [get_bd_intf_pins select_stream_1/in_1] [get_bd_intf_pins egr/egr_cmd_1]
  connect_bd_intf_net -intf_net egr_egr_header_ins_done [get_bd_intf_pins func_latency/egr_hdr_ins_done] [get_bd_intf_pins egr/egr_header_ins_done]
  connect_bd_intf_net -intf_net egr_egr_session_resp_0 [get_bd_intf_ports m_axis_egr_rx_resp] [get_bd_intf_pins egr/egr_session_resp]
  connect_bd_intf_net -intf_net egr_header_req [get_bd_intf_pins egr/header_req] [get_bd_intf_pins ingr/header_req]
  connect_bd_intf_net -intf_net egr_m_axi_gmem_extif0_1 [get_bd_intf_ports m_axi_extif0_buffer_wr] [get_bd_intf_pins egr/m_axi_gmem_extif0]
  connect_bd_intf_net -intf_net egr_m_axi_gmem_extif1_1 [get_bd_intf_ports m_axi_extif1_buffer_wr] [get_bd_intf_pins egr/m_axi_gmem_extif1]
  connect_bd_intf_net -intf_net egr_session_req_0_1 [get_bd_intf_ports s_axis_egr_rx_req] [get_bd_intf_pins egr/egr_session_req]
  connect_bd_intf_net -intf_net ingr_header_data [get_bd_intf_pins ingr/header_data] [get_bd_intf_pins egr/header_data]
  connect_bd_intf_net -intf_net ingr_ingr_cmd_0 [get_bd_intf_pins select_stream_0/in_0] [get_bd_intf_pins ingr/ingr_cmd_0]
  connect_bd_intf_net -intf_net ingr_ingr_cmd_1 [get_bd_intf_pins select_stream_1/in_0] [get_bd_intf_pins ingr/ingr_cmd_1]
  connect_bd_intf_net -intf_net ingr_ingr_header_rmv_done [get_bd_intf_pins func_latency/ingr_hdr_rmv_done] [get_bd_intf_pins ingr/ingr_header_rmv_done]
  connect_bd_intf_net -intf_net ingr_ingr_session_data_0 [get_bd_intf_ports m_axis_ingr_tx_data] [get_bd_intf_pins ingr/ingr_session_data]
  connect_bd_intf_net -intf_net ingr_ingr_session_req_0 [get_bd_intf_ports m_axis_ingr_tx_req] [get_bd_intf_pins ingr/ingr_session_req]
  connect_bd_intf_net -intf_net ingr_m_axi_gmem_extif0_0 [get_bd_intf_ports m_axi_extif0_buffer_rd] [get_bd_intf_pins ingr/m_axi_gmem_extif0]
  connect_bd_intf_net -intf_net ingr_session_resp_0_1 [get_bd_intf_ports s_axis_ingr_tx_resp] [get_bd_intf_pins ingr/ingr_session_resp]
  connect_bd_intf_net -intf_net interface_aximm_0_1 [get_bd_intf_ports s_axi_control] [get_bd_intf_pins control_s_axi/interface_aximm]
  connect_bd_intf_net -intf_net m_axi_extif1_buffer_rd [get_bd_intf_ports m_axi_extif1_buffer_rd] [get_bd_intf_pins ingr/m_axi_gmem_extif1]
  connect_bd_intf_net -intf_net rcv_nxt_update_req_estab_0_1 [get_bd_intf_pins ingr/rcv_nxt_update_req_estab_0] [get_bd_intf_pins term_evt_0/rcv_nxt_update_req_estab]
  connect_bd_intf_net -intf_net rcv_nxt_update_req_receive_0_1 [get_bd_intf_pins ingr/rcv_nxt_update_req_receive_0] [get_bd_intf_pins term_evt_0/rcv_nxt_update_req_receive]
  connect_bd_intf_net -intf_net s_axis_egr_rx_data_0_1 [get_bd_intf_ports s_axis_egr_rx_data] [get_bd_intf_pins egr/s_axis_egr_rx_data]
  connect_bd_intf_net -intf_net s_axis_extif0_evt_1 [get_bd_intf_ports s_axis_extif0_evt] [get_bd_intf_pins slice_extif0_evt/S_AXIS]
  connect_bd_intf_net -intf_net s_axis_extif1_evt_1 [get_bd_intf_ports s_axis_extif1_evt] [get_bd_intf_pins slice_extif1_evt/S_AXIS]
  connect_bd_intf_net -intf_net select_stream_0_out_r [get_bd_intf_pins select_stream_0/out_r] [get_bd_intf_pins slice_extif0_cmd/S_AXIS]
  connect_bd_intf_net -intf_net select_stream_1_out_r [get_bd_intf_pins select_stream_1/out_r] [get_bd_intf_pins slice_extif1_cmd/S_AXIS]
  connect_bd_intf_net -intf_net slice_extif0_cmd_M_AXIS [get_bd_intf_ports m_axis_extif0_cmd] [get_bd_intf_pins slice_extif0_cmd/M_AXIS]
  connect_bd_intf_net -intf_net slice_extif0_evt_M_AXIS [get_bd_intf_pins slice_extif0_evt/M_AXIS] [get_bd_intf_pins term_evt_0/s_axis_extif_evt]
  connect_bd_intf_net -intf_net slice_extif1_cmd_M_AXIS [get_bd_intf_ports m_axis_extif1_cmd] [get_bd_intf_pins slice_extif1_cmd/M_AXIS]
  connect_bd_intf_net -intf_net term_evt_0_evt_usr_wrt_update_req [get_bd_intf_pins term_evt_0/evt_usr_wrt_update_req] [get_bd_intf_pins egr/evt_usr_wrt_update_req_0]
  connect_bd_intf_net -intf_net term_evt_0_snd_una_update_req [get_bd_intf_pins term_evt_0/snd_una_update_req] [get_bd_intf_pins egr/snd_una_update_req_0]
  connect_bd_intf_net -intf_net term_evt_1_evt_usr_wrt_update_req [get_bd_intf_pins term_evt_1/evt_usr_wrt_update_req] [get_bd_intf_pins egr/evt_usr_wrt_update_req_1]
  connect_bd_intf_net -intf_net term_evt_1_rcv_nxt_update_req_estab [get_bd_intf_pins term_evt_1/rcv_nxt_update_req_estab] [get_bd_intf_pins ingr/rcv_nxt_update_req_estab_1]
  connect_bd_intf_net -intf_net term_evt_1_rcv_nxt_update_req_receive [get_bd_intf_pins term_evt_1/rcv_nxt_update_req_receive] [get_bd_intf_pins ingr/rcv_nxt_update_req_receive_1]
  connect_bd_intf_net -intf_net term_evt_1_snd_una_update_req [get_bd_intf_pins term_evt_1/snd_una_update_req] [get_bd_intf_pins egr/snd_una_update_req_1]

  # Create port connections
  connect_bd_net -net ap_clk_0_1 [get_bd_ports ap_clk] [get_bd_pins egr/ap_clk] [get_bd_pins ingr/ap_clk] [get_bd_pins select_stream_0/ap_clk] [get_bd_pins select_stream_1/ap_clk] [get_bd_pins term_evt_0/ap_clk] [get_bd_pins term_evt_1/ap_clk] [get_bd_pins func_latency/ap_clk] [get_bd_pins slice_extif1_evt/aclk] [get_bd_pins slice_extif0_evt/aclk] [get_bd_pins slice_extif0_cmd/aclk] [get_bd_pins slice_extif1_cmd/aclk] [get_bd_pins control_s_axi/ACLK]
  connect_bd_net -net ap_rst_n_0_1 [get_bd_ports ap_rst_n] [get_bd_pins egr/ap_rst_n] [get_bd_pins ingr/ap_rst_n] [get_bd_pins select_stream_0/ap_rst_n] [get_bd_pins select_stream_1/ap_rst_n] [get_bd_pins term_evt_0/ap_rst_n] [get_bd_pins term_evt_1/ap_rst_n] [get_bd_pins func_latency/ap_rst_n] [get_bd_pins slice_extif1_evt/aresetn] [get_bd_pins slice_extif0_evt/aresetn] [get_bd_pins slice_extif0_cmd/aresetn] [get_bd_pins slice_extif1_cmd/aresetn] [get_bd_pins control_s_axi/ARESET_N]
  connect_bd_net -net control_s_axi_detect_fault [get_bd_pins control_s_axi/detect_fault] [get_bd_ports detect_fault]
  connect_bd_net -net control_s_axi_egr_reg_out [get_bd_pins control_s_axi/egr_reg_out] [get_bd_pins egr/reg_out]
  connect_bd_net -net control_s_axi_ingr_reg_out [get_bd_pins control_s_axi/ingr_reg_out] [get_bd_pins ingr/reg_out]
  connect_bd_net -net cs_ctrl_id_0_local_version [get_bd_pins cs_ctrl_id/local_version] [get_bd_pins control_s_axi/local_version]
  connect_bd_net -net cs_ctrl_id_0_module_id [get_bd_pins cs_ctrl_id/module_id] [get_bd_pins control_s_axi/module_id]
  connect_bd_net -net egr_reg_in [get_bd_pins egr/reg_in] [get_bd_pins control_s_axi/egr_reg_in]
  connect_bd_net -net func_latency_0_func_latency_data [get_bd_pins func_latency/func_latency_data] [get_bd_pins control_s_axi/func_latency_data]
  connect_bd_net -net func_latency_0_func_latency_valid [get_bd_pins func_latency/func_latency_valid] [get_bd_pins control_s_axi/func_latency_valid]
  connect_bd_net -net ingr_reg_in [get_bd_pins ingr/reg_in] [get_bd_pins control_s_axi/ingr_reg_in]
  connect_bd_net -net streamif_stall_0_1 [get_bd_ports streamif_stall] [get_bd_pins control_s_axi/streamif_stall]
  connect_bd_net -net term_evt_0_extif_event_fault [get_bd_pins term_evt_0/extif_event_fault] [get_bd_pins control_s_axi/extif0_event_fault]
  connect_bd_net -net term_evt_0_extif_event_fault_ap_vld [get_bd_pins term_evt_0/extif_event_fault_ap_vld] [get_bd_pins control_s_axi/extif0_event_fault_ap_vld]
  connect_bd_net -net term_evt_1_extif_event_fault [get_bd_pins term_evt_1/extif_event_fault] [get_bd_pins control_s_axi/extif1_event_fault]
  connect_bd_net -net term_evt_1_extif_event_fault_ap_vld [get_bd_pins term_evt_1/extif_event_fault_ap_vld] [get_bd_pins control_s_axi/extif1_event_fault_ap_vld]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x00010000000000000000 -target_address_space [get_bd_addr_spaces egr/egr_write/Data_m_axi_gmem_extif0] [get_bd_addr_segs m_axi_extif0_buffer_wr/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x00010000000000000000 -target_address_space [get_bd_addr_spaces egr/egr_write/Data_m_axi_gmem_extif1] [get_bd_addr_segs m_axi_extif1_buffer_wr/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x00010000000000000000 -target_address_space [get_bd_addr_spaces ingr/ingr_read/Data_m_axi_gmem_extif0] [get_bd_addr_segs m_axi_extif0_buffer_rd/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x00010000000000000000 -target_address_space [get_bd_addr_spaces ingr/ingr_read/Data_m_axi_gmem_extif1] [get_bd_addr_segs m_axi_extif1_buffer_rd/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x00001000 -target_address_space [get_bd_addr_spaces s_axi_control] [get_bd_addr_segs control_s_axi/interface_aximm/reg0] -force


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


