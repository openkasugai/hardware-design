#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

################################################################
# This is a generated script based on design: toe_bd
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
# source toe_bd_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# network_ip_ctrl

# Please add the sources of those modules before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xcu250-figd2104-2L-e
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name toe_bd

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
ethz.systems.fpga:hls:arp_server_subnet:1.1\
xilinx.com:ip:c_shift_ram:12.0\
ethz.systems.fpga:hls:ethernet_frame_padding:0.2\
ethz.systems.fpga:hls:hash_table:1.0\
xilinx.labs:hls:icmp_server:1.67\
ethz.systems.fpga:hls:ip_handler:2.0\
ethz.systems.fpga:hls:mac_ip_encode:2.0\
ethz.systems.fpga:hls:toe:1.6\
xilinx.com:ip:axi_datamover:5.1\
xilinx.com:ip:axis_broadcaster:1.1\
xilinx.com:ip:axis_dwidth_converter:1.1\
xilinx.com:ip:system_ila:1.1\
xilinx.com:ip:axis_switch:1.1\
xilinx.com:ip:axis_data_fifo:2.0\
xilinx.com:ip:xlconstant:1.1\
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
network_ip_ctrl\
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
  set axi_dram [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 axi_dram ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {32} \
   CONFIG.DATA_WIDTH {512} \
   CONFIG.FREQ_HZ {300000000} \
   CONFIG.NUM_READ_OUTSTANDING {2} \
   CONFIG.NUM_WRITE_OUTSTANDING {2} \
   CONFIG.PROTOCOL {AXI4} \
   ] $axi_dram

  set axil [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 axil ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {12} \
   CONFIG.ARUSER_WIDTH {0} \
   CONFIG.AWUSER_WIDTH {0} \
   CONFIG.BUSER_WIDTH {0} \
   CONFIG.DATA_WIDTH {32} \
   CONFIG.FREQ_HZ {322265625} \
   CONFIG.HAS_BRESP {1} \
   CONFIG.HAS_BURST {0} \
   CONFIG.HAS_CACHE {0} \
   CONFIG.HAS_LOCK {0} \
   CONFIG.HAS_PROT {0} \
   CONFIG.HAS_QOS {0} \
   CONFIG.HAS_REGION {0} \
   CONFIG.HAS_RRESP {1} \
   CONFIG.HAS_WSTRB {0} \
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
   ] $axil

  set mac_rx_data [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 mac_rx_data ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {322265625} \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {64} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {1} \
   ] $mac_rx_data

  set mac_tx_data [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 mac_tx_data ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {322265625} \
   ] $mac_tx_data

  set tcp_cmd [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_cmd ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {322265625} \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {4} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $tcp_cmd

  set tcp_rsp [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_rsp ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {322265625} \
   ] $tcp_rsp

  set tcp_rx_data [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_rx_data ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {322265625} \
   ] $tcp_rx_data

  set tcp_tx_data [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_tx_data ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {322265625} \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {64} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $tcp_tx_data


  # Create ports
  set dram_clk [ create_bd_port -dir I -type clk -freq_hz 300000000 dram_clk ]
  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {axi_dram} \
   CONFIG.ASSOCIATED_RESET {dram_interconnect_aresetn} \
 ] $dram_clk
  set dram_interconnect_aresetn [ create_bd_port -dir I -type rst dram_interconnect_aresetn ]
  set mac_rx_aresetn [ create_bd_port -dir I -type rst mac_rx_aresetn ]
  set mac_rx_clk [ create_bd_port -dir I -type clk -freq_hz 322265625 mac_rx_clk ]
  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {mac_rx_data} \
   CONFIG.ASSOCIATED_RESET {mac_rx_aresetn:mac_rx_aresetn} \
 ] $mac_rx_clk
  set mac_tx_clk [ create_bd_port -dir I -type clk -freq_hz 322265625 mac_tx_clk ]
  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {mac_tx_data} \
 ] $mac_tx_clk
  set toe_aresetn [ create_bd_port -dir I -type rst toe_aresetn ]
  set toe_clk [ create_bd_port -dir I -type clk -freq_hz 322265625 toe_clk ]
  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {axil:tcp_cmd:tcp_rsp:tcp_rx_data:tcp_tx_data} \
   CONFIG.ASSOCIATED_RESET {tcp_cmd_aresetn:tcp_rsp_aresetn:toe_aresetn:toe_interconnect_aresetn} \
 ] $toe_clk
  set toe_interconnect_aresetn [ create_bd_port -dir I -type rst toe_interconnect_aresetn ]

  # Create instance: arp_server_subnet_0, and set properties
  set arp_server_subnet_0 [ create_bd_cell -type ip -vlnv ethz.systems.fpga:hls:arp_server_subnet:1.1 arp_server_subnet_0 ]

  # Create instance: c_shift_ram_0, and set properties
  set c_shift_ram_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:c_shift_ram:12.0 c_shift_ram_0 ]
  set_property -dict [list \
    CONFIG.AsyncInitRadix {16} \
    CONFIG.AsyncInitVal {0000} \
    CONFIG.DefaultData {0000} \
    CONFIG.DefaultDataRadix {16} \
    CONFIG.Depth {2} \
    CONFIG.Width {16} \
  ] $c_shift_ram_0


  # Create instance: ethernet_frame_paddi_0, and set properties
  set ethernet_frame_paddi_0 [ create_bd_cell -type ip -vlnv ethz.systems.fpga:hls:ethernet_frame_padding:0.2 ethernet_frame_paddi_0 ]

  # Create instance: hash_table_0, and set properties
  set hash_table_0 [ create_bd_cell -type ip -vlnv ethz.systems.fpga:hls:hash_table:1.0 hash_table_0 ]

  # Create instance: icmp_server_0, and set properties
  set icmp_server_0 [ create_bd_cell -type ip -vlnv xilinx.labs:hls:icmp_server:1.67 icmp_server_0 ]

  # Create instance: ip_handler_0, and set properties
  set ip_handler_0 [ create_bd_cell -type ip -vlnv ethz.systems.fpga:hls:ip_handler:2.0 ip_handler_0 ]

  # Create instance: mac_ip_encode_0, and set properties
  set mac_ip_encode_0 [ create_bd_cell -type ip -vlnv ethz.systems.fpga:hls:mac_ip_encode:2.0 mac_ip_encode_0 ]

  # Create instance: network_ip_ctrl_0, and set properties
  set block_name network_ip_ctrl
  set block_cell_name network_ip_ctrl_0
  if { [catch {set network_ip_ctrl_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $network_ip_ctrl_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property CONFIG.CH_NUM_LOG {10} $network_ip_ctrl_0


  # Create instance: toe_0, and set properties
  set toe_0 [ create_bd_cell -type ip -vlnv ethz.systems.fpga:hls:toe:1.6 toe_0 ]

  # Create instance: axi_datamover_0, and set properties
  set axi_datamover_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_datamover:5.1 axi_datamover_0 ]
  set_property -dict [list \
    CONFIG.c_addr_width {32} \
    CONFIG.c_dummy {1} \
    CONFIG.c_include_mm2s_dre {true} \
    CONFIG.c_include_s2mm_dre {true} \
    CONFIG.c_m_axi_mm2s_data_width {512} \
    CONFIG.c_m_axi_mm2s_id_width {0} \
    CONFIG.c_m_axi_s2mm_data_width {512} \
    CONFIG.c_m_axi_s2mm_id_width {0} \
    CONFIG.c_m_axis_mm2s_tdata_width {512} \
    CONFIG.c_mm2s_burst_size {16} \
    CONFIG.c_mm2s_include_sf {false} \
    CONFIG.c_s_axis_s2mm_tdata_width {512} \
  ] $axi_datamover_0


  # Create instance: axi_interconnect_0, and set properties
  set axi_interconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0 ]
  set_property -dict [list \
    CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
    CONFIG.M00_HAS_DATA_FIFO {2} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {2} \
    CONFIG.XBAR_DATA_WIDTH {512} \
  ] $axi_interconnect_0


  # Create instance: axis_broadcaster_0, and set properties
  set axis_broadcaster_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_0 ]
  set_property -dict [list \
    CONFIG.M00_TDATA_REMAP {tdata[143:0]} \
    CONFIG.M01_TDATA_REMAP {tdata[143:0]} \
    CONFIG.M_TDATA_NUM_BYTES {18} \
    CONFIG.S_TDATA_NUM_BYTES {18} \
  ] $axis_broadcaster_0


  # Create instance: icmp_in_width_conv, and set properties
  set icmp_in_width_conv [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 icmp_in_width_conv ]
  set_property -dict [list \
    CONFIG.HAS_MI_TKEEP {0} \
    CONFIG.HAS_TKEEP {1} \
    CONFIG.HAS_TLAST {1} \
    CONFIG.HAS_TSTRB {1} \
    CONFIG.M_TDATA_NUM_BYTES {8} \
    CONFIG.S_TDATA_NUM_BYTES {64} \
    CONFIG.TDEST_WIDTH {0} \
    CONFIG.TID_WIDTH {0} \
    CONFIG.TUSER_BITS_PER_BYTE {0} \
  ] $icmp_in_width_conv


  # Create instance: icmp_out_width_conv, and set properties
  set icmp_out_width_conv [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 icmp_out_width_conv ]
  set_property -dict [list \
    CONFIG.HAS_MI_TKEEP {1} \
    CONFIG.HAS_TKEEP {1} \
    CONFIG.HAS_TLAST {1} \
    CONFIG.HAS_TSTRB {1} \
    CONFIG.M_TDATA_NUM_BYTES {64} \
    CONFIG.S_TDATA_NUM_BYTES {8} \
    CONFIG.TDEST_WIDTH {0} \
    CONFIG.TID_WIDTH {0} \
    CONFIG.TUSER_BITS_PER_BYTE {0} \
  ] $icmp_out_width_conv


  # Create instance: ila_toe, and set properties
  set ila_toe [ create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 ila_toe ]
  set_property -dict [list \
    CONFIG.C_DATA_DEPTH {4096} \
    CONFIG.C_MON_TYPE {INTERFACE} \
    CONFIG.C_NUM_MONITOR_SLOTS {14} \
    CONFIG.C_SLOT {13} \
    CONFIG.C_SLOT_0_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_10_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_11_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_12_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_13_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_1_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_2_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_3_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_4_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_5_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_6_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_7_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_8_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_9_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
  ] $ila_toe


  # Create instance: ip_merger, and set properties
  set ip_merger [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 ip_merger ]
  set_property -dict [list \
    CONFIG.ARB_ON_MAX_XFERS {0} \
    CONFIG.ARB_ON_TLAST {1} \
    CONFIG.HAS_TLAST {1} \
  ] $ip_merger


  # Create instance: mac_merger, and set properties
  set mac_merger [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 mac_merger ]
  set_property -dict [list \
    CONFIG.ARB_ON_MAX_XFERS {0} \
    CONFIG.ARB_ON_TLAST {1} \
    CONFIG.HAS_TLAST {1} \
  ] $mac_merger


  # Create instance: rx_data_fifo, and set properties
  set rx_data_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 rx_data_fifo ]
  set_property -dict [list \
    CONFIG.FIFO_DEPTH {4096} \
    CONFIG.HAS_TKEEP {1} \
    CONFIG.HAS_TLAST {1} \
    CONFIG.HAS_TSTRB {1} \
    CONFIG.HAS_WR_DATA_COUNT {1} \
    CONFIG.TDATA_NUM_BYTES {64} \
  ] $rx_data_fifo


  # Create instance: rx_fifo, and set properties
  set rx_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 rx_fifo ]
  set_property -dict [list \
    CONFIG.HAS_TKEEP {1} \
    CONFIG.HAS_TLAST {1} \
    CONFIG.IS_ACLK_ASYNC {1} \
    CONFIG.TDATA_NUM_BYTES {64} \
    CONFIG.TUSER_WIDTH {1} \
  ] $rx_fifo


  # Create instance: tx_fifo, and set properties
  set tx_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 tx_fifo ]
  set_property -dict [list \
    CONFIG.FIFO_MODE {2} \
    CONFIG.HAS_TKEEP {1} \
    CONFIG.HAS_TSTRB {1} \
    CONFIG.IS_ACLK_ASYNC {1} \
    CONFIG.TDATA_NUM_BYTES {64} \
    CONFIG.TDEST_WIDTH {0} \
    CONFIG.TID_WIDTH {0} \
    CONFIG.TUSER_WIDTH {0} \
  ] $tx_fifo


  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
  set_property CONFIG.CONST_VAL {0} $xlconstant_0


  # Create instance: xlconstant_4096, and set properties
  set xlconstant_4096 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_4096 ]
  set_property -dict [list \
    CONFIG.CONST_VAL {4096} \
    CONFIG.CONST_WIDTH {16} \
  ] $xlconstant_4096


  # Create interface connections
  connect_bd_intf_net -intf_net S_AXIS_0_1 [get_bd_intf_ports mac_rx_data] [get_bd_intf_pins rx_fifo/S_AXIS]
  connect_bd_intf_net -intf_net arp_server_subnet_0_m_axis [get_bd_intf_pins arp_server_subnet_0/m_axis] [get_bd_intf_pins mac_merger/S00_AXIS]
  connect_bd_intf_net -intf_net arp_server_subnet_0_m_axis_arp_lookup_reply [get_bd_intf_pins arp_server_subnet_0/m_axis_arp_lookup_reply] [get_bd_intf_pins mac_ip_encode_0/s_axis_arp_lookup_reply]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXIS_MM2S [get_bd_intf_pins axi_datamover_0/M_AXIS_MM2S] [get_bd_intf_pins toe_0/s_axis_txread_data]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXIS_S2MM_STS [get_bd_intf_pins axi_datamover_0/M_AXIS_S2MM_STS] [get_bd_intf_pins toe_0/s_axis_txwrite_sts]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXI_MM2S [get_bd_intf_pins axi_datamover_0/M_AXI_MM2S] [get_bd_intf_pins axi_interconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXI_S2MM [get_bd_intf_pins axi_datamover_0/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_0/S01_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI [get_bd_intf_ports axi_dram] [get_bd_intf_pins axi_interconnect_0/M00_AXI]
  connect_bd_intf_net -intf_net axil_0_1 [get_bd_intf_ports axil] [get_bd_intf_pins network_ip_ctrl_0/axil]
  connect_bd_intf_net -intf_net axis_broadcaster_0_M00_AXIS [get_bd_intf_pins axis_broadcaster_0/M00_AXIS] [get_bd_intf_pins network_ip_ctrl_0/ht_upd]
connect_bd_intf_net -intf_net [get_bd_intf_nets axis_broadcaster_0_M00_AXIS] [get_bd_intf_pins axis_broadcaster_0/M00_AXIS] [get_bd_intf_pins ila_toe/SLOT_13_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_0_M01_AXIS [get_bd_intf_pins axis_broadcaster_0/M01_AXIS] [get_bd_intf_pins hash_table_0/s_axis_upd_req]
  connect_bd_intf_net -intf_net axis_data_fifo_0_M_AXIS [get_bd_intf_ports mac_tx_data] [get_bd_intf_pins tx_fifo/M_AXIS]
  connect_bd_intf_net -intf_net axis_dwidth_converter_0_M_AXIS [get_bd_intf_pins icmp_in_width_conv/M_AXIS] [get_bd_intf_pins icmp_server_0/s_axis]
  connect_bd_intf_net -intf_net axis_tcp_cmd_0_1 [get_bd_intf_ports tcp_cmd] [get_bd_intf_pins network_ip_ctrl_0/axis_tcp_cmd]
  connect_bd_intf_net -intf_net ethernet_frame_paddi_0_m_axis [get_bd_intf_pins ethernet_frame_paddi_0/m_axis] [get_bd_intf_pins tx_fifo/S_AXIS]
  connect_bd_intf_net -intf_net hash_table_0_m_axis_lup_rsp [get_bd_intf_pins hash_table_0/m_axis_lup_rsp] [get_bd_intf_pins toe_0/s_axis_session_lup_rsp]
  connect_bd_intf_net -intf_net hash_table_0_m_axis_upd_rsp [get_bd_intf_pins hash_table_0/m_axis_upd_rsp] [get_bd_intf_pins toe_0/s_axis_session_upd_rsp]
  connect_bd_intf_net -intf_net icmp_out_width_conv_M_AXIS [get_bd_intf_pins icmp_out_width_conv/M_AXIS] [get_bd_intf_pins ip_merger/S00_AXIS]
  connect_bd_intf_net -intf_net icmp_server_0_m_axis [get_bd_intf_pins icmp_out_width_conv/S_AXIS] [get_bd_intf_pins icmp_server_0/m_axis]
  connect_bd_intf_net -intf_net ip_handler_0_m_axis_arp [get_bd_intf_pins arp_server_subnet_0/s_axis] [get_bd_intf_pins ip_handler_0/m_axis_arp]
  connect_bd_intf_net -intf_net ip_handler_0_m_axis_icmp [get_bd_intf_pins icmp_in_width_conv/S_AXIS] [get_bd_intf_pins ip_handler_0/m_axis_icmp]
  connect_bd_intf_net -intf_net ip_handler_0_m_axis_tcp [get_bd_intf_pins ip_handler_0/m_axis_tcp] [get_bd_intf_pins toe_0/s_axis_tcp_data]
connect_bd_intf_net -intf_net [get_bd_intf_nets ip_handler_0_m_axis_tcp] [get_bd_intf_pins ip_handler_0/m_axis_tcp] [get_bd_intf_pins ila_toe/SLOT_9_AXIS]
  connect_bd_intf_net -intf_net ip_merger_M00_AXIS [get_bd_intf_pins ip_merger/M00_AXIS] [get_bd_intf_pins mac_ip_encode_0/s_axis_ip]
  connect_bd_intf_net -intf_net mac_ip_encode_0_m_axis_arp_lookup_request_0 [get_bd_intf_pins arp_server_subnet_0/s_axis_arp_lookup_request_0] [get_bd_intf_pins mac_ip_encode_0/m_axis_arp_lookup_request_0]
  connect_bd_intf_net -intf_net mac_ip_encode_0_m_axis_ip [get_bd_intf_pins mac_ip_encode_0/m_axis_ip] [get_bd_intf_pins mac_merger/S01_AXIS]
  connect_bd_intf_net -intf_net mac_merger_M00_AXIS [get_bd_intf_pins ethernet_frame_paddi_0/s_axis] [get_bd_intf_pins mac_merger/M00_AXIS]
  connect_bd_intf_net -intf_net network_ip_ctrl_0_axis_tcp_rsp [get_bd_intf_ports tcp_rsp] [get_bd_intf_pins network_ip_ctrl_0/axis_tcp_rsp]
connect_bd_intf_net -intf_net [get_bd_intf_nets network_ip_ctrl_0_axis_tcp_rsp] [get_bd_intf_ports tcp_rsp] [get_bd_intf_pins ila_toe/SLOT_7_AXIS]
  connect_bd_intf_net -intf_net network_ip_ctrl_0_close_conn [get_bd_intf_pins network_ip_ctrl_0/close_conn] [get_bd_intf_pins toe_0/s_axis_close_conn_req_0]
  connect_bd_intf_net -intf_net network_ip_ctrl_0_listen_req [get_bd_intf_pins network_ip_ctrl_0/listen_req] [get_bd_intf_pins toe_0/s_axis_listen_port_req_0]
connect_bd_intf_net -intf_net [get_bd_intf_nets network_ip_ctrl_0_listen_req] [get_bd_intf_pins network_ip_ctrl_0/listen_req] [get_bd_intf_pins ila_toe/SLOT_11_AXIS]
  connect_bd_intf_net -intf_net network_ip_ctrl_0_open_req [get_bd_intf_pins network_ip_ctrl_0/open_req] [get_bd_intf_pins toe_0/s_axis_open_conn_req]
connect_bd_intf_net -intf_net [get_bd_intf_nets network_ip_ctrl_0_open_req] [get_bd_intf_pins network_ip_ctrl_0/open_req] [get_bd_intf_pins ila_toe/SLOT_10_AXIS]
  connect_bd_intf_net -intf_net network_ip_ctrl_0_rx_req [get_bd_intf_pins network_ip_ctrl_0/rx_req] [get_bd_intf_pins toe_0/s_axis_rx_data_req]
connect_bd_intf_net -intf_net [get_bd_intf_nets network_ip_ctrl_0_rx_req] [get_bd_intf_pins network_ip_ctrl_0/rx_req] [get_bd_intf_pins ila_toe/SLOT_3_AXIS]
  connect_bd_intf_net -intf_net network_ip_ctrl_0_tx_req [get_bd_intf_pins network_ip_ctrl_0/tx_req] [get_bd_intf_pins toe_0/s_axis_tx_data_req_metadata]
connect_bd_intf_net -intf_net [get_bd_intf_nets network_ip_ctrl_0_tx_req] [get_bd_intf_pins network_ip_ctrl_0/tx_req] [get_bd_intf_pins ila_toe/SLOT_0_AXIS]
  connect_bd_intf_net -intf_net rx_data_fifo_M_AXIS [get_bd_intf_pins rx_data_fifo/M_AXIS] [get_bd_intf_pins toe_0/s_axis_rxread_data]
  connect_bd_intf_net -intf_net rx_fifo_M_AXIS [get_bd_intf_pins ip_handler_0/s_axis_raw] [get_bd_intf_pins rx_fifo/M_AXIS]
  connect_bd_intf_net -intf_net s_axis_tx_data_req_0_1 [get_bd_intf_ports tcp_tx_data] [get_bd_intf_pins toe_0/s_axis_tx_data_req]
connect_bd_intf_net -intf_net [get_bd_intf_nets s_axis_tx_data_req_0_1] [get_bd_intf_ports tcp_tx_data] [get_bd_intf_pins ila_toe/SLOT_5_AXIS]
  connect_bd_intf_net -intf_net toe_0_m_axis_listen_port_rsp_0 [get_bd_intf_pins network_ip_ctrl_0/listen_status] [get_bd_intf_pins toe_0/m_axis_listen_port_rsp_0]
connect_bd_intf_net -intf_net [get_bd_intf_nets toe_0_m_axis_listen_port_rsp_0] [get_bd_intf_pins network_ip_ctrl_0/listen_status] [get_bd_intf_pins ila_toe/SLOT_12_AXIS]
  connect_bd_intf_net -intf_net toe_0_m_axis_notification [get_bd_intf_pins network_ip_ctrl_0/notification] [get_bd_intf_pins toe_0/m_axis_notification]
connect_bd_intf_net -intf_net [get_bd_intf_nets toe_0_m_axis_notification] [get_bd_intf_pins network_ip_ctrl_0/notification] [get_bd_intf_pins ila_toe/SLOT_2_AXIS]
  connect_bd_intf_net -intf_net toe_0_m_axis_open_conn_rsp [get_bd_intf_pins network_ip_ctrl_0/open_status] [get_bd_intf_pins toe_0/m_axis_open_conn_rsp]
connect_bd_intf_net -intf_net [get_bd_intf_nets toe_0_m_axis_open_conn_rsp] [get_bd_intf_pins network_ip_ctrl_0/open_status] [get_bd_intf_pins ila_toe/SLOT_8_AXIS]
  connect_bd_intf_net -intf_net toe_0_m_axis_rx_data_rsp [get_bd_intf_ports tcp_rx_data] [get_bd_intf_pins network_ip_ctrl_0/rx_out]
connect_bd_intf_net -intf_net [get_bd_intf_nets toe_0_m_axis_rx_data_rsp] [get_bd_intf_ports tcp_rx_data] [get_bd_intf_pins ila_toe/SLOT_6_AXIS]
  connect_bd_intf_net -intf_net toe_0_m_axis_rx_data_rsp1 [get_bd_intf_pins toe_0/m_axis_rx_data_rsp] [get_bd_intf_pins network_ip_ctrl_0/rx_in]
  connect_bd_intf_net -intf_net toe_0_m_axis_rx_data_rsp_metadata [get_bd_intf_pins network_ip_ctrl_0/rx_rsp] [get_bd_intf_pins toe_0/m_axis_rx_data_rsp_metadata_0]
connect_bd_intf_net -intf_net [get_bd_intf_nets toe_0_m_axis_rx_data_rsp_metadata] [get_bd_intf_pins network_ip_ctrl_0/rx_rsp] [get_bd_intf_pins ila_toe/SLOT_4_AXIS]
  connect_bd_intf_net -intf_net toe_0_m_axis_rxwrite_data [get_bd_intf_pins rx_data_fifo/S_AXIS] [get_bd_intf_pins toe_0/m_axis_rxwrite_data]
  connect_bd_intf_net -intf_net toe_0_m_axis_session_lup_req [get_bd_intf_pins hash_table_0/s_axis_lup_req] [get_bd_intf_pins toe_0/m_axis_session_lup_req]
  connect_bd_intf_net -intf_net toe_0_m_axis_session_upd_req [get_bd_intf_pins axis_broadcaster_0/S_AXIS] [get_bd_intf_pins toe_0/m_axis_session_upd_req]
  connect_bd_intf_net -intf_net toe_0_m_axis_tcp_data [get_bd_intf_pins ip_merger/S01_AXIS] [get_bd_intf_pins toe_0/m_axis_tcp_data]
  connect_bd_intf_net -intf_net toe_0_m_axis_tx_data_rsp [get_bd_intf_pins network_ip_ctrl_0/tx_rsp] [get_bd_intf_pins toe_0/m_axis_tx_data_rsp]
connect_bd_intf_net -intf_net [get_bd_intf_nets toe_0_m_axis_tx_data_rsp] [get_bd_intf_pins network_ip_ctrl_0/tx_rsp] [get_bd_intf_pins ila_toe/SLOT_1_AXIS]
  connect_bd_intf_net -intf_net toe_0_m_axis_txread_cmd [get_bd_intf_pins axi_datamover_0/S_AXIS_MM2S_CMD] [get_bd_intf_pins toe_0/m_axis_txread_cmd]
  connect_bd_intf_net -intf_net toe_0_m_axis_txwrite_cmd [get_bd_intf_pins axi_datamover_0/S_AXIS_S2MM_CMD] [get_bd_intf_pins toe_0/m_axis_txwrite_cmd]
  connect_bd_intf_net -intf_net toe_0_m_axis_txwrite_data [get_bd_intf_pins axi_datamover_0/S_AXIS_S2MM] [get_bd_intf_pins toe_0/m_axis_txwrite_data]

  # Create port connections
  connect_bd_net -net M00_ACLK_0_1 [get_bd_ports dram_clk] [get_bd_pins axi_interconnect_0/M00_ACLK]
  connect_bd_net -net M00_ARESETN_0_1 [get_bd_ports dram_interconnect_aresetn] [get_bd_pins axi_interconnect_0/M00_ARESETN]
  connect_bd_net -net ap_rst_n_0_1 [get_bd_ports toe_aresetn] [get_bd_pins arp_server_subnet_0/ap_rst_n] [get_bd_pins ethernet_frame_paddi_0/ap_rst_n] [get_bd_pins hash_table_0/ap_rst_n] [get_bd_pins icmp_server_0/ap_rst_n] [get_bd_pins ip_handler_0/ap_rst_n] [get_bd_pins mac_ip_encode_0/ap_rst_n] [get_bd_pins network_ip_ctrl_0/resetn] [get_bd_pins toe_0/ap_rst_n] [get_bd_pins axi_datamover_0/m_axi_mm2s_aresetn] [get_bd_pins axi_datamover_0/m_axis_mm2s_cmdsts_aresetn] [get_bd_pins axi_datamover_0/m_axi_s2mm_aresetn] [get_bd_pins axi_datamover_0/m_axis_s2mm_cmdsts_aresetn] [get_bd_pins ila_toe/resetn] [get_bd_pins rx_data_fifo/s_axis_aresetn] [get_bd_pins tx_fifo/s_axis_aresetn]
  connect_bd_net -net aresetn_0_1 [get_bd_ports toe_interconnect_aresetn] [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins axi_interconnect_0/S00_ARESETN] [get_bd_pins axi_interconnect_0/S01_ARESETN] [get_bd_pins axis_broadcaster_0/aresetn] [get_bd_pins icmp_in_width_conv/aresetn] [get_bd_pins icmp_out_width_conv/aresetn] [get_bd_pins ip_merger/aresetn] [get_bd_pins mac_merger/aresetn]
  connect_bd_net -net c_shift_ram_0_Q [get_bd_pins c_shift_ram_0/Q] [get_bd_pins toe_0/axis_data_count]
  connect_bd_net -net m_axis_aclk_0_1 [get_bd_ports toe_clk] [get_bd_pins arp_server_subnet_0/ap_clk] [get_bd_pins c_shift_ram_0/CLK] [get_bd_pins ethernet_frame_paddi_0/ap_clk] [get_bd_pins hash_table_0/ap_clk] [get_bd_pins icmp_server_0/ap_clk] [get_bd_pins ip_handler_0/ap_clk] [get_bd_pins mac_ip_encode_0/ap_clk] [get_bd_pins network_ip_ctrl_0/clk] [get_bd_pins toe_0/ap_clk] [get_bd_pins axi_datamover_0/m_axi_mm2s_aclk] [get_bd_pins axi_datamover_0/m_axis_mm2s_cmdsts_aclk] [get_bd_pins axi_datamover_0/m_axi_s2mm_aclk] [get_bd_pins axi_datamover_0/m_axis_s2mm_cmdsts_awclk] [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins axi_interconnect_0/S01_ACLK] [get_bd_pins axis_broadcaster_0/aclk] [get_bd_pins icmp_in_width_conv/aclk] [get_bd_pins icmp_out_width_conv/aclk] [get_bd_pins ila_toe/clk] [get_bd_pins ip_merger/aclk] [get_bd_pins mac_merger/aclk] [get_bd_pins rx_data_fifo/s_axis_aclk] [get_bd_pins rx_fifo/m_axis_aclk] [get_bd_pins tx_fifo/s_axis_aclk]
  connect_bd_net -net network_ip_ctrl_0_default_gateway [get_bd_pins network_ip_ctrl_0/default_gateway] [get_bd_pins mac_ip_encode_0/regDefaultGateway]
  connect_bd_net -net network_ip_ctrl_0_ip_addr [get_bd_pins network_ip_ctrl_0/ip_addr] [get_bd_pins arp_server_subnet_0/myIpAddress] [get_bd_pins ip_handler_0/myIpAddress] [get_bd_pins toe_0/myIpAddress]
  connect_bd_net -net network_ip_ctrl_0_mac_addr [get_bd_pins network_ip_ctrl_0/mac_addr] [get_bd_pins arp_server_subnet_0/myMacAddress] [get_bd_pins mac_ip_encode_0/myMacAddress]
  connect_bd_net -net network_ip_ctrl_0_subnet_mask [get_bd_pins network_ip_ctrl_0/subnet_mask] [get_bd_pins mac_ip_encode_0/regSubNetMask]
  connect_bd_net -net rx_data_fifo_axis_wr_data_count [get_bd_pins rx_data_fifo/axis_wr_data_count] [get_bd_pins c_shift_ram_0/D]
  connect_bd_net -net s_axis_aclk_0_1 [get_bd_ports mac_tx_clk] [get_bd_pins tx_fifo/m_axis_aclk]
  connect_bd_net -net s_axis_aclk_0_2 [get_bd_ports mac_rx_clk] [get_bd_pins rx_fifo/s_axis_aclk]
  connect_bd_net -net s_axis_aresetn_0_1 [get_bd_ports mac_rx_aresetn] [get_bd_pins rx_fifo/s_axis_aresetn]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins xlconstant_0/dout] [get_bd_pins arp_server_subnet_0/s_axis_host_arp_lookup_request_0_TVALID] [get_bd_pins icmp_server_0/ttlIn_TVALID] [get_bd_pins icmp_server_0/udpIn_TVALID]
  connect_bd_net -net xlconstant_1024_dout [get_bd_pins xlconstant_4096/dout] [get_bd_pins toe_0/axis_max_data_count]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs axi_dram/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs axi_dram/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x00001000 -target_address_space [get_bd_addr_spaces axil] [get_bd_addr_segs network_ip_ctrl_0/axil/reg0] -force


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


