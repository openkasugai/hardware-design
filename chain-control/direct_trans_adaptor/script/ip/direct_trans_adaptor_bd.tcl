#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

################################################################
# This is a generated script based on design: direct_trans_adaptor_bd
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
# source direct_trans_adaptor_bd_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# direct_trans_adaptor_control_s_axi, dta_ingr_rcv_monitor_protocol, dta_egr_snd_monitor_protocol, dta_ingr_snd_monitor_protocol, dta_egr_rcv_monitor_protocol

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
set design_name direct_trans_adaptor_bd

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
xilinx.com:hls:direct_trans_adaptor_core:1.0\
xilinx.com:hls:direct_trans_adaptor_id:1.0\
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
direct_trans_adaptor_control_s_axi\
dta_ingr_rcv_monitor_protocol\
dta_egr_snd_monitor_protocol\
dta_ingr_snd_monitor_protocol\
dta_egr_rcv_monitor_protocol\
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
   CONFIG.ADDR_WIDTH {12} \
   CONFIG.ARUSER_WIDTH {0} \
   CONFIG.AWUSER_WIDTH {0} \
   CONFIG.BUSER_WIDTH {0} \
   CONFIG.DATA_WIDTH {32} \
   CONFIG.FREQ_HZ {200000000} \
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

  set m_axis_egr_tx_req [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_egr_tx_req ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {200000000} \
   ] $m_axis_egr_tx_req

  set s_axis_egr_rx_req [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_egr_rx_req ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {200000000} \
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
  set_property -dict [ list \
   CONFIG.FREQ_HZ {200000000} \
   ] $m_axis_ingr_tx_req

  set s_axis_ingr_rx_req [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_ingr_rx_req ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {200000000} \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $s_axis_ingr_rx_req

  set s_axis_egr_tx_resp [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_egr_tx_resp ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {200000000} \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $s_axis_egr_tx_resp

  set m_axis_egr_rx_resp [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_egr_rx_resp ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {200000000} \
   ] $m_axis_egr_rx_resp

  set s_axis_ingr_tx_resp [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_ingr_tx_resp ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {200000000} \
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

  set m_axis_ingr_rx_resp [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_ingr_rx_resp ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {200000000} \
   ] $m_axis_ingr_rx_resp

  set s_axis_egr_rx_data [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_egr_rx_data ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {200000000} \
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

  set m_axis_ingr_tx_data [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_ingr_tx_data ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {200000000} \
   ] $m_axis_ingr_tx_data

  set s_axis_ingr_rx_data [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_ingr_rx_data ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {200000000} \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {64} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $s_axis_ingr_rx_data

  set m_axis_egr_tx_data [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_egr_tx_data ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {200000000} \
   ] $m_axis_egr_tx_data


  # Create ports
  set ap_clk [ create_bd_port -dir I -type clk -freq_hz 200000000 ap_clk ]
  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {s_axis_ingr_rx_req:s_axis_ingr_rx_data:s_axis_ingr_tx_resp:s_axis_egr_rx_req:s_axis_egr_rx_data:s_axis_egr_tx_resp:m_axis_ingr_rx_resp:m_axis_ingr_tx_req:m_axis_ingr_tx_data:m_axis_egr_rx_resp:m_axis_egr_tx_req:m_axis_egr_tx_data:s_axi_control} \
   CONFIG.ASSOCIATED_RESET {ap_rst_n} \
 ] $ap_clk
  set ap_rst_n [ create_bd_port -dir I -type rst ap_rst_n ]
  set detect_fault [ create_bd_port -dir O detect_fault ]
  set streamif_stall [ create_bd_port -dir I -from 11 -to 0 streamif_stall ]

  # Create instance: dta_control_s_axi, and set properties
  set block_name direct_trans_adaptor_control_s_axi
  set block_cell_name dta_control_s_axi
  if { [catch {set dta_control_s_axi [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $dta_control_s_axi eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: dta_core, and set properties
  set dta_core [ create_bd_cell -type ip -vlnv xilinx.com:hls:direct_trans_adaptor_core:1.0 dta_core ]

  # Create instance: dta_id, and set properties
  set dta_id [ create_bd_cell -type ip -vlnv xilinx.com:hls:direct_trans_adaptor_id:1.0 dta_id ]

  # Create instance: ingr_rcv_monitor_protocol, and set properties
  set block_name dta_ingr_rcv_monitor_protocol
  set block_cell_name ingr_rcv_monitor_protocol
  if { [catch {set ingr_rcv_monitor_protocol [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $ingr_rcv_monitor_protocol eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: egr_snd_monitor_protocol, and set properties
  set block_name dta_egr_snd_monitor_protocol
  set block_cell_name egr_snd_monitor_protocol
  if { [catch {set egr_snd_monitor_protocol [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $egr_snd_monitor_protocol eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: ingr_snd_monitor_protocol, and set properties
  set block_name dta_ingr_snd_monitor_protocol
  set block_cell_name ingr_snd_monitor_protocol
  if { [catch {set ingr_snd_monitor_protocol [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $ingr_snd_monitor_protocol eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: egr_rcv_monitor_protocol, and set properties
  set block_name dta_egr_rcv_monitor_protocol
  set block_cell_name egr_rcv_monitor_protocol
  if { [catch {set egr_rcv_monitor_protocol [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $egr_rcv_monitor_protocol eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create interface connections
  connect_bd_intf_net -intf_net dta_core_m_axis_egr_rx_resp [get_bd_intf_ports m_axis_egr_rx_resp] [get_bd_intf_pins dta_core/m_axis_egr_rx_resp]
connect_bd_intf_net -intf_net [get_bd_intf_nets dta_core_m_axis_egr_rx_resp] [get_bd_intf_ports m_axis_egr_rx_resp] [get_bd_intf_pins egr_rcv_monitor_protocol/resp]
  connect_bd_intf_net -intf_net dta_core_m_axis_egr_tx_data [get_bd_intf_ports m_axis_egr_tx_data] [get_bd_intf_pins dta_core/m_axis_egr_tx_data]
connect_bd_intf_net -intf_net [get_bd_intf_nets dta_core_m_axis_egr_tx_data] [get_bd_intf_ports m_axis_egr_tx_data] [get_bd_intf_pins egr_snd_monitor_protocol/data]
  connect_bd_intf_net -intf_net dta_core_m_axis_egr_tx_req [get_bd_intf_ports m_axis_egr_tx_req] [get_bd_intf_pins dta_core/m_axis_egr_tx_req]
connect_bd_intf_net -intf_net [get_bd_intf_nets dta_core_m_axis_egr_tx_req] [get_bd_intf_ports m_axis_egr_tx_req] [get_bd_intf_pins egr_snd_monitor_protocol/req]
  connect_bd_intf_net -intf_net dta_core_m_axis_ingr_rx_resp [get_bd_intf_ports m_axis_ingr_rx_resp] [get_bd_intf_pins dta_core/m_axis_ingr_rx_resp]
connect_bd_intf_net -intf_net [get_bd_intf_nets dta_core_m_axis_ingr_rx_resp] [get_bd_intf_ports m_axis_ingr_rx_resp] [get_bd_intf_pins ingr_rcv_monitor_protocol/resp]
  connect_bd_intf_net -intf_net dta_core_m_axis_ingr_tx_data [get_bd_intf_ports m_axis_ingr_tx_data] [get_bd_intf_pins dta_core/m_axis_ingr_tx_data]
connect_bd_intf_net -intf_net [get_bd_intf_nets dta_core_m_axis_ingr_tx_data] [get_bd_intf_ports m_axis_ingr_tx_data] [get_bd_intf_pins ingr_snd_monitor_protocol/data]
  connect_bd_intf_net -intf_net dta_core_m_axis_ingr_tx_req [get_bd_intf_ports m_axis_ingr_tx_req] [get_bd_intf_pins dta_core/m_axis_ingr_tx_req]
connect_bd_intf_net -intf_net [get_bd_intf_nets dta_core_m_axis_ingr_tx_req] [get_bd_intf_ports m_axis_ingr_tx_req] [get_bd_intf_pins ingr_snd_monitor_protocol/req]
  connect_bd_intf_net -intf_net interface_aximm_0_1 [get_bd_intf_ports s_axi_control] [get_bd_intf_pins dta_control_s_axi/interface_aximm]
  connect_bd_intf_net -intf_net s_axis_egr_rx_data_0_1 [get_bd_intf_ports s_axis_egr_rx_data] [get_bd_intf_pins dta_core/s_axis_egr_rx_data]
connect_bd_intf_net -intf_net [get_bd_intf_nets s_axis_egr_rx_data_0_1] [get_bd_intf_ports s_axis_egr_rx_data] [get_bd_intf_pins egr_rcv_monitor_protocol/data]
  connect_bd_intf_net -intf_net s_axis_egr_rx_req_0_1 [get_bd_intf_ports s_axis_egr_rx_req] [get_bd_intf_pins dta_core/s_axis_egr_rx_req]
connect_bd_intf_net -intf_net [get_bd_intf_nets s_axis_egr_rx_req_0_1] [get_bd_intf_ports s_axis_egr_rx_req] [get_bd_intf_pins egr_rcv_monitor_protocol/req]
  connect_bd_intf_net -intf_net s_axis_egr_tx_resp_0_1 [get_bd_intf_ports s_axis_egr_tx_resp] [get_bd_intf_pins dta_core/s_axis_egr_tx_resp]
connect_bd_intf_net -intf_net [get_bd_intf_nets s_axis_egr_tx_resp_0_1] [get_bd_intf_ports s_axis_egr_tx_resp] [get_bd_intf_pins egr_snd_monitor_protocol/resp]
  connect_bd_intf_net -intf_net s_axis_ingr_rx_data_0_1 [get_bd_intf_ports s_axis_ingr_rx_data] [get_bd_intf_pins dta_core/s_axis_ingr_rx_data]
connect_bd_intf_net -intf_net [get_bd_intf_nets s_axis_ingr_rx_data_0_1] [get_bd_intf_ports s_axis_ingr_rx_data] [get_bd_intf_pins ingr_rcv_monitor_protocol/data]
  connect_bd_intf_net -intf_net s_axis_ingr_rx_req_0_1 [get_bd_intf_ports s_axis_ingr_rx_req] [get_bd_intf_pins dta_core/s_axis_ingr_rx_req]
connect_bd_intf_net -intf_net [get_bd_intf_nets s_axis_ingr_rx_req_0_1] [get_bd_intf_ports s_axis_ingr_rx_req] [get_bd_intf_pins ingr_rcv_monitor_protocol/req]
  connect_bd_intf_net -intf_net s_axis_ingr_tx_resp_0_1 [get_bd_intf_ports s_axis_ingr_tx_resp] [get_bd_intf_pins dta_core/s_axis_ingr_tx_resp]
connect_bd_intf_net -intf_net [get_bd_intf_nets s_axis_ingr_tx_resp_0_1] [get_bd_intf_ports s_axis_ingr_tx_resp] [get_bd_intf_pins ingr_snd_monitor_protocol/resp]

  # Create port connections
  connect_bd_net -net ap_clk_0_1 [get_bd_ports ap_clk] [get_bd_pins dta_control_s_axi/ACLK] [get_bd_pins dta_core/ap_clk] [get_bd_pins ingr_rcv_monitor_protocol/ap_clk] [get_bd_pins egr_snd_monitor_protocol/ap_clk] [get_bd_pins ingr_snd_monitor_protocol/ap_clk] [get_bd_pins egr_rcv_monitor_protocol/ap_clk]
  connect_bd_net -net ap_rst_n_0_1 [get_bd_ports ap_rst_n] [get_bd_pins dta_control_s_axi/ARESET_N] [get_bd_pins dta_core/ap_rst_n] [get_bd_pins ingr_rcv_monitor_protocol/ap_rst_n] [get_bd_pins egr_snd_monitor_protocol/ap_rst_n] [get_bd_pins ingr_snd_monitor_protocol/ap_rst_n] [get_bd_pins egr_rcv_monitor_protocol/ap_rst_n]
  connect_bd_net -net direct_trans_adaptor_2_local_version [get_bd_pins dta_id/local_version] [get_bd_pins dta_control_s_axi/local_version]
  connect_bd_net -net direct_trans_adaptor_2_module_id [get_bd_pins dta_id/module_id] [get_bd_pins dta_control_s_axi/module_id]
  connect_bd_net -net dta_control_s_axi_detect_fault [get_bd_pins dta_control_s_axi/detect_fault] [get_bd_ports detect_fault]
  connect_bd_net -net dta_control_s_axi_egr_rcv_insert_protocol_fault [get_bd_pins dta_control_s_axi/egr_rcv_insert_protocol_fault] [get_bd_pins dta_core/egr_rcv_insert_protocol_fault]
  connect_bd_net -net dta_control_s_axi_egr_snd_insert_protocol_fault [get_bd_pins dta_control_s_axi/egr_snd_insert_protocol_fault] [get_bd_pins dta_core/egr_snd_insert_protocol_fault]
  connect_bd_net -net dta_control_s_axi_ingr_rcv_insert_protocol_fault [get_bd_pins dta_control_s_axi/ingr_rcv_insert_protocol_fault] [get_bd_pins dta_core/ingr_rcv_insert_protocol_fault]
  connect_bd_net -net dta_control_s_axi_ingr_snd_insert_protocol_fault [get_bd_pins dta_control_s_axi/ingr_snd_insert_protocol_fault] [get_bd_pins dta_core/ingr_snd_insert_protocol_fault]
  connect_bd_net -net dta_core_stat_egr_rcv_data [get_bd_pins dta_core/stat_egr_rcv_data] [get_bd_pins dta_control_s_axi/stat_egr_rcv_data]
  connect_bd_net -net dta_core_stat_egr_rcv_data_ap_vld [get_bd_pins dta_core/stat_egr_rcv_data_ap_vld] [get_bd_pins dta_control_s_axi/stat_egr_rcv_data_ap_vld]
  connect_bd_net -net dta_core_stat_egr_rcv_frame [get_bd_pins dta_core/stat_egr_rcv_frame] [get_bd_pins dta_control_s_axi/stat_egr_rcv_frame]
  connect_bd_net -net dta_core_stat_egr_rcv_frame_ap_vld [get_bd_pins dta_core/stat_egr_rcv_frame_ap_vld] [get_bd_pins dta_control_s_axi/stat_egr_rcv_frame_ap_vld]
  connect_bd_net -net dta_core_stat_egr_snd_data [get_bd_pins dta_core/stat_egr_snd_data] [get_bd_pins dta_control_s_axi/stat_egr_snd_data]
  connect_bd_net -net dta_core_stat_egr_snd_data_ap_vld [get_bd_pins dta_core/stat_egr_snd_data_ap_vld] [get_bd_pins dta_control_s_axi/stat_egr_snd_data_ap_vld]
  connect_bd_net -net dta_core_stat_egr_snd_frame [get_bd_pins dta_core/stat_egr_snd_frame] [get_bd_pins dta_control_s_axi/stat_egr_snd_frame]
  connect_bd_net -net dta_core_stat_egr_snd_frame_ap_vld [get_bd_pins dta_core/stat_egr_snd_frame_ap_vld] [get_bd_pins dta_control_s_axi/stat_egr_snd_frame_ap_vld]
  connect_bd_net -net dta_core_stat_ingr_rcv_data [get_bd_pins dta_core/stat_ingr_rcv_data] [get_bd_pins dta_control_s_axi/stat_ingr_rcv_data]
  connect_bd_net -net dta_core_stat_ingr_rcv_data_ap_vld [get_bd_pins dta_core/stat_ingr_rcv_data_ap_vld] [get_bd_pins dta_control_s_axi/stat_ingr_rcv_data_ap_vld]
  connect_bd_net -net dta_core_stat_ingr_rcv_frame [get_bd_pins dta_core/stat_ingr_rcv_frame] [get_bd_pins dta_control_s_axi/stat_ingr_rcv_frame]
  connect_bd_net -net dta_core_stat_ingr_rcv_frame_ap_vld [get_bd_pins dta_core/stat_ingr_rcv_frame_ap_vld] [get_bd_pins dta_control_s_axi/stat_ingr_rcv_frame_ap_vld]
  connect_bd_net -net dta_core_stat_ingr_snd_data [get_bd_pins dta_core/stat_ingr_snd_data] [get_bd_pins dta_control_s_axi/stat_ingr_snd_data]
  connect_bd_net -net dta_core_stat_ingr_snd_data_ap_vld [get_bd_pins dta_core/stat_ingr_snd_data_ap_vld] [get_bd_pins dta_control_s_axi/stat_ingr_snd_data_ap_vld]
  connect_bd_net -net dta_core_stat_ingr_snd_frame [get_bd_pins dta_core/stat_ingr_snd_frame] [get_bd_pins dta_control_s_axi/stat_ingr_snd_frame]
  connect_bd_net -net dta_core_stat_ingr_snd_frame_ap_vld [get_bd_pins dta_core/stat_ingr_snd_frame_ap_vld] [get_bd_pins dta_control_s_axi/stat_ingr_snd_frame_ap_vld]
  connect_bd_net -net egr_rcv_monitor_protocol_protocol_error [get_bd_pins egr_rcv_monitor_protocol/protocol_error] [get_bd_pins dta_control_s_axi/egr_rcv_protocol_fault]
  connect_bd_net -net egr_rcv_monitor_protocol_protocol_error_ap_vld [get_bd_pins egr_rcv_monitor_protocol/protocol_error_ap_vld] [get_bd_pins dta_control_s_axi/egr_rcv_protocol_fault_ap_vld]
  connect_bd_net -net egr_snd_monitor_protocol_protocol_error [get_bd_pins egr_snd_monitor_protocol/protocol_error] [get_bd_pins dta_control_s_axi/egr_snd_protocol_fault]
  connect_bd_net -net egr_snd_monitor_protocol_protocol_error_ap_vld [get_bd_pins egr_snd_monitor_protocol/protocol_error_ap_vld] [get_bd_pins dta_control_s_axi/egr_snd_protocol_fault_ap_vld]
  connect_bd_net -net ingr_rcv_monitor_protocol_protocol_error [get_bd_pins ingr_rcv_monitor_protocol/protocol_error] [get_bd_pins dta_control_s_axi/ingr_rcv_protocol_fault]
  connect_bd_net -net ingr_rcv_monitor_protocol_protocol_error_ap_vld [get_bd_pins ingr_rcv_monitor_protocol/protocol_error_ap_vld] [get_bd_pins dta_control_s_axi/ingr_rcv_protocol_fault_ap_vld]
  connect_bd_net -net ingr_snd_monitor_protocol_protocol_error [get_bd_pins ingr_snd_monitor_protocol/protocol_error] [get_bd_pins dta_control_s_axi/ingr_snd_protocol_fault]
  connect_bd_net -net ingr_snd_monitor_protocol_protocol_error_ap_vld [get_bd_pins ingr_snd_monitor_protocol/protocol_error_ap_vld] [get_bd_pins dta_control_s_axi/ingr_snd_protocol_fault_ap_vld]
  connect_bd_net -net streamif_stall_0_1 [get_bd_ports streamif_stall] [get_bd_pins dta_control_s_axi/streamif_stall]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x00001000 -target_address_space [get_bd_addr_spaces s_axi_control] [get_bd_addr_segs dta_control_s_axi/interface_aximm/reg0] -force


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


