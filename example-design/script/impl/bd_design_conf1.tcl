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

# To test this script, run the following commands from Vivado Tcl console:
# source design_1_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# indirect_reg_access, pci_mon_wire, fpga_reg, axis2axi_bridge, lldma_wrapper, axi4l_decoupler, axi4l_decoupler, axi4l_decoupler, axi4l_decoupler

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
set design_name design_1

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
xilinx.com:ip:xlconcat:2.1\
xilinx.com:ip:c_shift_ram:12.0\
xilinx.com:ip:axi_register_slice:2.1\
xilinx.com:ip:util_vector_logic:2.0\
xilinx.com:ip:xlconstant:1.1\
xilinx.com:ip:axi_gpio:2.0\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:cms_subsystem:4.0\
xilinx.com:ip:ddr4:2.2\
xilinx.com:ip:pcie4_uscale_plus:1.3\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:util_ds_buf:2.2\
xilinx.com:ip:axis_register_slice:1.1\
xilinx.com:ip:axis_clock_converter:1.1\
xilinx.com:ip:util_reduced_logic:2.0\
xilinx.com:RTLKernel:chain_control:1.0\
xilinx.com:RTLKernel:direct_trans_adaptor:1.0\
xilinx.com:ip:dfx_decoupler:1.0\
xilinx.com:RTLKernel:conversion_adaptor:1.0\
xilinx.com:RTLKernel:filter_resize:1.0\
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
indirect_reg_access\
pci_mon_wire\
fpga_reg\
axis2axi_bridge\
lldma_wrapper\
axi4l_decoupler\
axi4l_decoupler\
axi4l_decoupler\
axi4l_decoupler\
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


# Hierarchical cell: function_1
proc create_hier_cell_function_1 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_function_1() - Empty argument(s)!"}
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
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_ingr_req

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_ingr_resp

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_ingr_data

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_egr_req

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_egr_resp

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_egr_data

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_control_conv

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_conv

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_control_func


  # Create pins
  create_bd_pin -dir I -type clk aclk_mm
  create_bd_pin -dir O -from 0 -to 0 detect_fault_conv
  create_bd_pin -dir O -from 0 -to 0 -type intr detect_fault_func
  create_bd_pin -dir I -type rst aresetn_mm_filter
  create_bd_pin -dir I -type rst aresetn_mm_conv
  create_bd_pin -dir I decouple_filter
  create_bd_pin -dir I decouple_conv
  create_bd_pin -dir O -from 8 -to 0 decoupler_status

  # Create instance: dfx_decoupler_conv_axi_m, and set properties
  set dfx_decoupler_conv_axi_m [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_decoupler:1.0 dfx_decoupler_conv_axi_m ]
  set_property -dict [list \
    CONFIG.ALL_PARAMS {INTF {intf_0 {ID 0 VLNV xilinx.com:interface:aximm_rtl:1.0 PROTOCOL AXI4 SIGNALS {ARVALID {WIDTH 1 PRESENT 1} ARREADY {WIDTH 1 PRESENT 1} AWVALID {WIDTH 1 PRESENT 1} AWREADY {WIDTH\
1 PRESENT 1} BVALID {WIDTH 1 PRESENT 1} BREADY {WIDTH 1 PRESENT 1} RVALID {WIDTH 1 PRESENT 1} RREADY {WIDTH 1 PRESENT 1} WVALID {WIDTH 1 PRESENT 1} WREADY {WIDTH 1 PRESENT 1} AWID {WIDTH 1 PRESENT 1} AWADDR\
{WIDTH 64 PRESENT 1} AWLEN {WIDTH 8 PRESENT 1} AWSIZE {WIDTH 3 PRESENT 1} AWBURST {WIDTH 2 PRESENT 1} AWLOCK {WIDTH 1 PRESENT 1} AWCACHE {WIDTH 4 PRESENT 1} AWPROT {WIDTH 3 PRESENT 1} AWREGION {WIDTH 4\
PRESENT 1} AWQOS {WIDTH 4 PRESENT 1} AWUSER {WIDTH 0 PRESENT 0} WID {WIDTH 1 PRESENT 1} WDATA {WIDTH 512 PRESENT 1} WSTRB {WIDTH 64 PRESENT 1} WLAST {WIDTH 1 PRESENT 1} WUSER {WIDTH 0 PRESENT 0} BID {WIDTH\
1 PRESENT 1} BRESP {WIDTH 2 PRESENT 1} BUSER {WIDTH 0 PRESENT 0} ARID {WIDTH 1 PRESENT 1} ARADDR {WIDTH 64 PRESENT 1} ARLEN {WIDTH 8 PRESENT 1} ARSIZE {WIDTH 3 PRESENT 1} ARBURST {WIDTH 2 PRESENT 1} ARLOCK\
{WIDTH 1 PRESENT 1} ARCACHE {WIDTH 4 PRESENT 1} ARPROT {WIDTH 3 PRESENT 1} ARREGION {WIDTH 4 PRESENT 1} ARQOS {WIDTH 4 PRESENT 1} ARUSER {WIDTH 0 PRESENT 0} RID {WIDTH 1 PRESENT 1} RDATA {WIDTH 512 PRESENT\
1} RRESP {WIDTH 2 PRESENT 1} RLAST {WIDTH 1 PRESENT 1} RUSER {WIDTH 0 PRESENT 0}}}} IPI_PROP_COUNT 0} \
    CONFIG.GUI_SELECT_VLNV {xilinx.com:interface:aximm_rtl:1.0} \
  ] $dfx_decoupler_conv_axi_m


  # Create instance: dfx_decoupler_conv_axis_m, and set properties
  set dfx_decoupler_conv_axis_m [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_decoupler:1.0 dfx_decoupler_conv_axis_m ]
  set_property -dict [list \
    CONFIG.ALL_PARAMS {HAS_AXIS_CONTROL 0 HAS_AXIS_STATUS 0 INTF {intf_0 {ID 0 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH\
32} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 4} TKEEP {PRESENT 0 WIDTH 4}}} intf_1 {ID 1 VLNV xilinx.com:interface:axis_rtl:1.0\
SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 32} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT\
0 WIDTH 4} TKEEP {PRESENT 0 WIDTH 4}}} intf_2 {ID 2 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH\
0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_3 {ID 3 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID\
{PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8}\
TKEEP {PRESENT 0 WIDTH 8}}} intf_4 {ID 4 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST\
{PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_5 {ID 5 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT\
1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT\
0 WIDTH 8}}} intf_6 {ID 6 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 512} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH\
1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 64} TKEEP {PRESENT 0 WIDTH 64}}} intf_7 {ID 7 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY\
{PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}}\
intf_8 {ID 8 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT\
0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}}} IPI_PROP_COUNT 0} \
    CONFIG.GUI_SELECT_INTERFACE {0} \
    CONFIG.GUI_SELECT_VLNV {xilinx.com:interface:axis_rtl:1.0} \
  ] $dfx_decoupler_conv_axis_m


  # Create instance: dfx_decoupler_conv_axis_s, and set properties
  set dfx_decoupler_conv_axis_s [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_decoupler:1.0 dfx_decoupler_conv_axis_s ]
  set_property -dict [list \
    CONFIG.ALL_PARAMS {INTF {intf_0 {ID 0 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH\
0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_1 {ID 1 MODE slave VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS\
{TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0\
WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_2 {ID 2 MODE slave VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 32} TUSER {PRESENT\
0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 4} TKEEP {PRESENT 0 WIDTH 4}}} intf_3 {ID 3 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave\
SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 32} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT\
0 WIDTH 4} TKEEP {PRESENT 0 WIDTH 4}}} intf_4 {ID 4 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT\
0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_5 {ID 5 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave\
SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT\
0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_6 {ID 6 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT\
0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_7 {ID 7 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave\
SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 512} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT\
0 WIDTH 64} TKEEP {PRESENT 0 WIDTH 64}}} intf_8 {ID 8 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT\
0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}}} IPI_PROP_COUNT 0} \
    CONFIG.GUI_SELECT_INTERFACE {0} \
    CONFIG.GUI_SELECT_MODE {slave} \
    CONFIG.GUI_SELECT_VLNV {xilinx.com:interface:axis_rtl:1.0} \
  ] $dfx_decoupler_conv_axis_s


  # Create instance: dfx_decoupler_filter_axis_m, and set properties
  set dfx_decoupler_filter_axis_m [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_decoupler:1.0 dfx_decoupler_filter_axis_m ]
  set_property -dict [list \
    CONFIG.ALL_PARAMS {HAS_AXIS_CONTROL 0 HAS_AXIS_STATUS 0 INTF {intf_0 {ID 0 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH\
64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_1 {ID 1 VLNV xilinx.com:interface:axis_rtl:1.0\
SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT\
0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_2 {ID 2 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 32} TUSER {PRESENT 0 WIDTH\
0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 4} TKEEP {PRESENT 0 WIDTH 4}}} intf_3 {ID 3 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID\
{PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 32} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 4}\
TKEEP {PRESENT 0 WIDTH 4}}} intf_4 {ID 4 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST\
{PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_5 {ID 5 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT\
1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT\
0 WIDTH 8}}}} IPI_PROP_COUNT 0} \
    CONFIG.GUI_SELECT_INTERFACE {0} \
    CONFIG.GUI_SELECT_VLNV {xilinx.com:interface:axis_rtl:1.0} \
  ] $dfx_decoupler_filter_axis_m


  # Create instance: dfx_decoupler_filter_axis_s, and set properties
  set dfx_decoupler_filter_axis_s [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_decoupler:1.0 dfx_decoupler_filter_axis_s ]
  set_property -dict [list \
    CONFIG.ALL_PARAMS {INTF {intf_0 {ID 0 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 32} TUSER {PRESENT 0 WIDTH\
0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 4} TKEEP {PRESENT 0 WIDTH 4}}} intf_1 {ID 1 MODE slave VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS\
{TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 32} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0\
WIDTH 4} TKEEP {PRESENT 0 WIDTH 4}}} intf_2 {ID 2 MODE slave VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT\
0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_3 {ID 3 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave\
SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT\
0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_4 {ID 4 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT\
0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_5 {ID 5 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave\
SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT\
0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}}} IPI_PROP_COUNT 1} \
    CONFIG.GUI_SELECT_INTERFACE {0} \
    CONFIG.GUI_SELECT_MODE {slave} \
    CONFIG.GUI_SELECT_VLNV {xilinx.com:interface:axis_rtl:1.0} \
  ] $dfx_decoupler_filter_axis_s


  # Create instance: dfx_decoupler_filter_fault, and set properties
  set dfx_decoupler_filter_fault [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_decoupler:1.0 dfx_decoupler_filter_fault ]
  set_property -dict [list \
    CONFIG.ALL_PARAMS {INTF {intf_0 {ID 0 VLNV xilinx.com:signal:data_rtl:1.0 SIGNALS {DATA {PRESENT 1 WIDTH 1}}}} IPI_PROP_COUNT 0} \
    CONFIG.GUI_SELECT_VLNV {xilinx.com:signal:data_rtl:1.0} \
  ] $dfx_decoupler_filter_fault


  # Create instance: xlconcat_1, and set properties
  set xlconcat_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_1 ]
  set_property CONFIG.NUM_PORTS {9} $xlconcat_1


  # Create instance: dfx_decoupler_conv_fault, and set properties
  set dfx_decoupler_conv_fault [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_decoupler:1.0 dfx_decoupler_conv_fault ]
  set_property -dict [list \
    CONFIG.ALL_PARAMS {INTF {intf_0 {ID 0 VLNV xilinx.com:signal:data_rtl:1.0 SIGNALS {DATA {PRESENT 1 WIDTH 1}}}} IPI_PROP_COUNT 0} \
    CONFIG.GUI_SELECT_VLNV {xilinx.com:signal:data_rtl:1.0} \
  ] $dfx_decoupler_conv_fault


  # Create instance: conversion_ada_0, and set properties
  set conversion_ada_0 [ create_bd_cell -type ip -vlnv xilinx.com:RTLKernel:conversion_adaptor:1.0 conversion_ada_0 ]

  # Create instance: filter_resize_0, and set properties
  set filter_resize_0 [ create_bd_cell -type ip -vlnv xilinx.com:RTLKernel:filter_resize:1.0 filter_resize_0 ]

  # Create instance: axi4l_decoupler_conv, and set properties
  set block_name axi4l_decoupler
  set block_cell_name axi4l_decoupler_conv
  if { [catch {set axi4l_decoupler_conv [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $axi4l_decoupler_conv eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property CONFIG.IN_ADDR_WIDTH {10} $axi4l_decoupler_conv


  # Create instance: axi4l_decoupler_filter, and set properties
  set block_name axi4l_decoupler
  set block_cell_name axi4l_decoupler_filter
  if { [catch {set axi4l_decoupler_filter [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $axi4l_decoupler_filter eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property CONFIG.IN_ADDR_WIDTH {10} $axi4l_decoupler_filter


  # Create interface connections
  connect_bd_intf_net -intf_net axi4l_decoupler_conv_m_axi [get_bd_intf_pins conversion_ada_0/s_axi_control] [get_bd_intf_pins axi4l_decoupler_conv/m_axi]
  connect_bd_intf_net -intf_net axi4l_decoupler_filter_m_axi [get_bd_intf_pins filter_resize_0/s_axi_control] [get_bd_intf_pins axi4l_decoupler_filter/m_axi]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axi_ingr_frame_buffer [get_bd_intf_pins conversion_ada_0/m_axi_ingr_frame_buffer] [get_bd_intf_pins dfx_decoupler_conv_axi_m/rp_intf_0]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_egr_rx_data [get_bd_intf_pins conversion_ada_0/m_axis_egr_rx_data] [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_6]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_egr_rx_req [get_bd_intf_pins conversion_ada_0/m_axis_egr_rx_req] [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_7]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_egr_rx_resp0 [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_4] [get_bd_intf_pins conversion_ada_0/m_axis_egr_rx_resp0]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_egr_rx_resp1 [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_5] [get_bd_intf_pins conversion_ada_0/m_axis_egr_rx_resp1]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_ingr_tx_data0 [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_0] [get_bd_intf_pins conversion_ada_0/m_axis_ingr_tx_data0]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_ingr_tx_data1 [get_bd_intf_pins conversion_ada_0/m_axis_ingr_tx_data1] [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_1]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_ingr_tx_req0 [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_2] [get_bd_intf_pins conversion_ada_0/m_axis_ingr_tx_req0]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_ingr_tx_req1 [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_3] [get_bd_intf_pins conversion_ada_0/m_axis_ingr_tx_req1]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_ingr_tx_resp [get_bd_intf_pins conversion_ada_0/m_axis_ingr_tx_resp] [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_8]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axi_m_s_intf_0 [get_bd_intf_pins m_axi_conv] [get_bd_intf_pins dfx_decoupler_conv_axi_m/s_intf_0]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_0 [get_bd_intf_pins dfx_decoupler_filter_axis_s/s_intf_0] [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_0]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_1 [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_1] [get_bd_intf_pins dfx_decoupler_filter_axis_s/s_intf_1]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_2 [get_bd_intf_pins dfx_decoupler_filter_axis_s/s_intf_2] [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_2]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_3 [get_bd_intf_pins dfx_decoupler_filter_axis_s/s_intf_3] [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_3]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_4 [get_bd_intf_pins dfx_decoupler_filter_axis_s/s_intf_4] [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_4]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_5 [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_5] [get_bd_intf_pins dfx_decoupler_filter_axis_s/s_intf_5]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_6 [get_bd_intf_pins m_axis_egr_data] [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_6]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_7 [get_bd_intf_pins m_axis_egr_req] [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_7]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_8 [get_bd_intf_pins m_axis_ingr_resp] [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_8]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_0 [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_0] [get_bd_intf_pins conversion_ada_0/s_axis_ingr_tx_resp0]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_1 [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_1] [get_bd_intf_pins conversion_ada_0/s_axis_ingr_tx_resp1]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_2 [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_2] [get_bd_intf_pins conversion_ada_0/s_axis_egr_rx_data0]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_3 [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_3] [get_bd_intf_pins conversion_ada_0/s_axis_egr_rx_data1]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_4 [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_4] [get_bd_intf_pins conversion_ada_0/s_axis_egr_rx_req0]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_5 [get_bd_intf_pins conversion_ada_0/s_axis_egr_rx_req1] [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_5]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_6 [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_6] [get_bd_intf_pins conversion_ada_0/s_axis_egr_rx_resp]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_7 [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_7] [get_bd_intf_pins conversion_ada_0/s_axis_ingr_tx_data]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_8 [get_bd_intf_pins conversion_ada_0/s_axis_ingr_tx_req] [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_8]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_m_s_intf_0 [get_bd_intf_pins dfx_decoupler_filter_axis_m/s_intf_0] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_0]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_m_s_intf_1 [get_bd_intf_pins dfx_decoupler_filter_axis_m/s_intf_1] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_1]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_m_s_intf_2 [get_bd_intf_pins dfx_decoupler_filter_axis_m/s_intf_2] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_2]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_m_s_intf_3 [get_bd_intf_pins dfx_decoupler_filter_axis_m/s_intf_3] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_3]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_m_s_intf_4 [get_bd_intf_pins dfx_decoupler_filter_axis_m/s_intf_4] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_4]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_m_s_intf_5 [get_bd_intf_pins dfx_decoupler_filter_axis_m/s_intf_5] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_5]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_s_rp_intf_0 [get_bd_intf_pins filter_resize_0/s_axis_rx_data_0] [get_bd_intf_pins dfx_decoupler_filter_axis_s/rp_intf_0]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_s_rp_intf_1 [get_bd_intf_pins filter_resize_0/s_axis_rx_data_1] [get_bd_intf_pins dfx_decoupler_filter_axis_s/rp_intf_1]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_s_rp_intf_2 [get_bd_intf_pins filter_resize_0/s_axis_rx_req_0] [get_bd_intf_pins dfx_decoupler_filter_axis_s/rp_intf_2]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_s_rp_intf_3 [get_bd_intf_pins filter_resize_0/s_axis_rx_req_1] [get_bd_intf_pins dfx_decoupler_filter_axis_s/rp_intf_3]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_s_rp_intf_4 [get_bd_intf_pins filter_resize_0/s_axis_tx_resp_0] [get_bd_intf_pins dfx_decoupler_filter_axis_s/rp_intf_4]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_s_rp_intf_5 [get_bd_intf_pins filter_resize_0/s_axis_tx_resp_1] [get_bd_intf_pins dfx_decoupler_filter_axis_s/rp_intf_5]
  connect_bd_intf_net -intf_net filter_resize_0_m_axis_rx_resp_0 [get_bd_intf_pins filter_resize_0/m_axis_rx_resp_0] [get_bd_intf_pins dfx_decoupler_filter_axis_m/rp_intf_0]
  connect_bd_intf_net -intf_net filter_resize_0_m_axis_rx_resp_1 [get_bd_intf_pins filter_resize_0/m_axis_rx_resp_1] [get_bd_intf_pins dfx_decoupler_filter_axis_m/rp_intf_1]
  connect_bd_intf_net -intf_net filter_resize_0_m_axis_tx_data_0 [get_bd_intf_pins filter_resize_0/m_axis_tx_data_0] [get_bd_intf_pins dfx_decoupler_filter_axis_m/rp_intf_2]
  connect_bd_intf_net -intf_net filter_resize_0_m_axis_tx_data_1 [get_bd_intf_pins filter_resize_0/m_axis_tx_data_1] [get_bd_intf_pins dfx_decoupler_filter_axis_m/rp_intf_3]
  connect_bd_intf_net -intf_net filter_resize_0_m_axis_tx_req_0 [get_bd_intf_pins filter_resize_0/m_axis_tx_req_0] [get_bd_intf_pins dfx_decoupler_filter_axis_m/rp_intf_4]
  connect_bd_intf_net -intf_net filter_resize_0_m_axis_tx_req_1 [get_bd_intf_pins filter_resize_0/m_axis_tx_req_1] [get_bd_intf_pins dfx_decoupler_filter_axis_m/rp_intf_5]
  connect_bd_intf_net -intf_net s_axi_control_conv_1 [get_bd_intf_pins s_axi_control_conv] [get_bd_intf_pins axi4l_decoupler_conv/s_axi]
  connect_bd_intf_net -intf_net s_axi_control_func_1 [get_bd_intf_pins s_axi_control_func] [get_bd_intf_pins axi4l_decoupler_filter/s_axi]
  connect_bd_intf_net -intf_net s_axis_egr_resp_1 [get_bd_intf_pins s_axis_egr_resp] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_6]
  connect_bd_intf_net -intf_net s_axis_ingr_data_1 [get_bd_intf_pins s_axis_ingr_data] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_7]
  connect_bd_intf_net -intf_net s_axis_ingr_req_1 [get_bd_intf_pins s_axis_ingr_req] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_8]

  # Create port connections
  connect_bd_net -net ap_clk_0_1 [get_bd_pins aclk_mm] [get_bd_pins conversion_ada_0/ap_clk] [get_bd_pins filter_resize_0/ap_clk] [get_bd_pins axi4l_decoupler_conv/user_clk] [get_bd_pins axi4l_decoupler_filter/user_clk]
  connect_bd_net -net ap_rst_n1_1 [get_bd_pins aresetn_mm_conv] [get_bd_pins conversion_ada_0/ap_rst_n] [get_bd_pins axi4l_decoupler_filter/reset_n]
  connect_bd_net -net ap_rst_n_1 [get_bd_pins aresetn_mm_filter] [get_bd_pins filter_resize_0/ap_rst_n] [get_bd_pins axi4l_decoupler_conv/reset_n]
  connect_bd_net -net axi4l_decoupler_conv_decouple_status [get_bd_pins axi4l_decoupler_conv/decouple_status] [get_bd_pins xlconcat_1/In5]
  connect_bd_net -net axi4l_decoupler_filter_decouple_status [get_bd_pins axi4l_decoupler_filter/decouple_status] [get_bd_pins xlconcat_1/In3]
  connect_bd_net -net conversion_ada_0_detect_fault [get_bd_pins conversion_ada_0/detect_fault] [get_bd_pins dfx_decoupler_conv_fault/rp_intf_0_DATA]
  connect_bd_net -net decouple1_1 [get_bd_pins decouple_conv] [get_bd_pins dfx_decoupler_conv_axi_m/decouple] [get_bd_pins dfx_decoupler_conv_axis_s/decouple] [get_bd_pins dfx_decoupler_conv_axis_m/decouple] [get_bd_pins dfx_decoupler_conv_fault/decouple] [get_bd_pins axi4l_decoupler_conv/decouple_enable]
  connect_bd_net -net decouple_1 [get_bd_pins decouple_filter] [get_bd_pins dfx_decoupler_filter_axis_m/decouple] [get_bd_pins dfx_decoupler_filter_axis_s/decouple] [get_bd_pins dfx_decoupler_filter_fault/decouple] [get_bd_pins axi4l_decoupler_filter/decouple_enable]
  connect_bd_net -net dfx_decoupler_conv_axi_m_decouple_status [get_bd_pins dfx_decoupler_conv_axi_m/decouple_status] [get_bd_pins xlconcat_1/In7]
  connect_bd_net -net dfx_decoupler_conv_axis_m_decouple_status [get_bd_pins dfx_decoupler_conv_axis_m/decouple_status] [get_bd_pins xlconcat_1/In4]
  connect_bd_net -net dfx_decoupler_conv_axis_s_decouple_status [get_bd_pins dfx_decoupler_conv_axis_s/decouple_status] [get_bd_pins xlconcat_1/In6]
  connect_bd_net -net dfx_decoupler_conv_fault_decouple_status [get_bd_pins dfx_decoupler_conv_fault/decouple_status] [get_bd_pins xlconcat_1/In8]
  connect_bd_net -net dfx_decoupler_conv_fault_s_intf_0_DATA [get_bd_pins dfx_decoupler_conv_fault/s_intf_0_DATA] [get_bd_pins detect_fault_conv]
  connect_bd_net -net dfx_decoupler_filter_axis_m_decouple_status [get_bd_pins dfx_decoupler_filter_axis_m/decouple_status] [get_bd_pins xlconcat_1/In2]
  connect_bd_net -net dfx_decoupler_filter_axis_s_decouple_status [get_bd_pins dfx_decoupler_filter_axis_s/decouple_status] [get_bd_pins xlconcat_1/In1]
  connect_bd_net -net dfx_decoupler_filter_fault_decouple_status [get_bd_pins dfx_decoupler_filter_fault/decouple_status] [get_bd_pins xlconcat_1/In0]
  connect_bd_net -net dfx_decoupler_filter_fault_s_intf_0_DATA [get_bd_pins dfx_decoupler_filter_fault/s_intf_0_DATA] [get_bd_pins detect_fault_func]
  connect_bd_net -net filter_resize_0_detect_fault [get_bd_pins filter_resize_0/detect_fault] [get_bd_pins dfx_decoupler_filter_fault/rp_intf_0_DATA]
  connect_bd_net -net xlconcat_1_dout [get_bd_pins xlconcat_1/dout] [get_bd_pins decoupler_status]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: function_0
proc create_hier_cell_function_0 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_function_0() - Empty argument(s)!"}
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
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_ingr_req

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_ingr_resp

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_ingr_data

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_egr_req

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_egr_resp

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_egr_data

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_control_conv

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_conv

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_control_func


  # Create pins
  create_bd_pin -dir I -type clk aclk_mm
  create_bd_pin -dir O -from 0 -to 0 detect_fault_conv
  create_bd_pin -dir O -from 0 -to 0 -type intr detect_fault_func
  create_bd_pin -dir I -type rst aresetn_mm_filter
  create_bd_pin -dir I -type rst aresetn_mm_conv
  create_bd_pin -dir I decouple_filter
  create_bd_pin -dir I decouple_conv
  create_bd_pin -dir O -from 8 -to 0 decoupler_status

  # Create instance: dfx_decoupler_conv_fault, and set properties
  set dfx_decoupler_conv_fault [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_decoupler:1.0 dfx_decoupler_conv_fault ]
  set_property -dict [list \
    CONFIG.ALL_PARAMS {INTF {intf_0 {ID 0 VLNV xilinx.com:signal:data_rtl:1.0 SIGNALS {DATA {PRESENT 1 WIDTH 1}}}} IPI_PROP_COUNT 0} \
    CONFIG.GUI_SELECT_VLNV {xilinx.com:signal:data_rtl:1.0} \
  ] $dfx_decoupler_conv_fault


  # Create instance: dfx_decoupler_conv_axi_m, and set properties
  set dfx_decoupler_conv_axi_m [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_decoupler:1.0 dfx_decoupler_conv_axi_m ]
  set_property -dict [list \
    CONFIG.ALL_PARAMS {INTF {intf_0 {ID 0 VLNV xilinx.com:interface:aximm_rtl:1.0 PROTOCOL AXI4 SIGNALS {ARVALID {WIDTH 1 PRESENT 1} ARREADY {WIDTH 1 PRESENT 1} AWVALID {WIDTH 1 PRESENT 1} AWREADY {WIDTH\
1 PRESENT 1} BVALID {WIDTH 1 PRESENT 1} BREADY {WIDTH 1 PRESENT 1} RVALID {WIDTH 1 PRESENT 1} RREADY {WIDTH 1 PRESENT 1} WVALID {WIDTH 1 PRESENT 1} WREADY {WIDTH 1 PRESENT 1} AWID {WIDTH 1 PRESENT 1} AWADDR\
{WIDTH 64 PRESENT 1} AWLEN {WIDTH 8 PRESENT 1} AWSIZE {WIDTH 3 PRESENT 1} AWBURST {WIDTH 2 PRESENT 1} AWLOCK {WIDTH 1 PRESENT 1} AWCACHE {WIDTH 4 PRESENT 1} AWPROT {WIDTH 3 PRESENT 1} AWREGION {WIDTH 4\
PRESENT 1} AWQOS {WIDTH 4 PRESENT 1} AWUSER {WIDTH 0 PRESENT 0} WID {WIDTH 1 PRESENT 1} WDATA {WIDTH 512 PRESENT 1} WSTRB {WIDTH 64 PRESENT 1} WLAST {WIDTH 1 PRESENT 1} WUSER {WIDTH 0 PRESENT 0} BID {WIDTH\
1 PRESENT 1} BRESP {WIDTH 2 PRESENT 1} BUSER {WIDTH 0 PRESENT 0} ARID {WIDTH 1 PRESENT 1} ARADDR {WIDTH 64 PRESENT 1} ARLEN {WIDTH 8 PRESENT 1} ARSIZE {WIDTH 3 PRESENT 1} ARBURST {WIDTH 2 PRESENT 1} ARLOCK\
{WIDTH 1 PRESENT 1} ARCACHE {WIDTH 4 PRESENT 1} ARPROT {WIDTH 3 PRESENT 1} ARREGION {WIDTH 4 PRESENT 1} ARQOS {WIDTH 4 PRESENT 1} ARUSER {WIDTH 0 PRESENT 0} RID {WIDTH 1 PRESENT 1} RDATA {WIDTH 512 PRESENT\
1} RRESP {WIDTH 2 PRESENT 1} RLAST {WIDTH 1 PRESENT 1} RUSER {WIDTH 0 PRESENT 0}}}} IPI_PROP_COUNT 0} \
    CONFIG.GUI_SELECT_VLNV {xilinx.com:interface:aximm_rtl:1.0} \
  ] $dfx_decoupler_conv_axi_m


  # Create instance: dfx_decoupler_conv_axis_m, and set properties
  set dfx_decoupler_conv_axis_m [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_decoupler:1.0 dfx_decoupler_conv_axis_m ]
  set_property -dict [list \
    CONFIG.ALL_PARAMS {HAS_AXIS_CONTROL 0 HAS_AXIS_STATUS 0 INTF {intf_0 {ID 0 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH\
32} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 4} TKEEP {PRESENT 0 WIDTH 4}}} intf_1 {ID 1 VLNV xilinx.com:interface:axis_rtl:1.0\
SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 32} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT\
0 WIDTH 4} TKEEP {PRESENT 0 WIDTH 4}}} intf_2 {ID 2 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH\
0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_3 {ID 3 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID\
{PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8}\
TKEEP {PRESENT 0 WIDTH 8}}} intf_4 {ID 4 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST\
{PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_5 {ID 5 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT\
1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT\
0 WIDTH 8}}} intf_6 {ID 6 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 512} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH\
1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 64} TKEEP {PRESENT 0 WIDTH 64}}} intf_7 {ID 7 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY\
{PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}}\
intf_8 {ID 8 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT\
0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}}} IPI_PROP_COUNT 0} \
    CONFIG.GUI_SELECT_INTERFACE {0} \
    CONFIG.GUI_SELECT_VLNV {xilinx.com:interface:axis_rtl:1.0} \
  ] $dfx_decoupler_conv_axis_m


  # Create instance: dfx_decoupler_filter_axis_s, and set properties
  set dfx_decoupler_filter_axis_s [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_decoupler:1.0 dfx_decoupler_filter_axis_s ]
  set_property -dict [list \
    CONFIG.ALL_PARAMS {INTF {intf_0 {ID 0 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 32} TUSER {PRESENT 0 WIDTH\
0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 4} TKEEP {PRESENT 0 WIDTH 4}}} intf_1 {ID 1 MODE slave VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS\
{TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 32} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0\
WIDTH 4} TKEEP {PRESENT 0 WIDTH 4}}} intf_2 {ID 2 MODE slave VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT\
0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_3 {ID 3 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave\
SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT\
0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_4 {ID 4 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT\
0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_5 {ID 5 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave\
SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT\
0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}}} IPI_PROP_COUNT 1} \
    CONFIG.GUI_SELECT_INTERFACE {0} \
    CONFIG.GUI_SELECT_MODE {slave} \
    CONFIG.GUI_SELECT_VLNV {xilinx.com:interface:axis_rtl:1.0} \
  ] $dfx_decoupler_filter_axis_s


  # Create instance: dfx_decoupler_conv_axis_s, and set properties
  set dfx_decoupler_conv_axis_s [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_decoupler:1.0 dfx_decoupler_conv_axis_s ]
  set_property -dict [list \
    CONFIG.ALL_PARAMS {INTF {intf_0 {ID 0 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH\
0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_1 {ID 1 MODE slave VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS\
{TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0\
WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_2 {ID 2 MODE slave VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 32} TUSER {PRESENT\
0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 4} TKEEP {PRESENT 0 WIDTH 4}}} intf_3 {ID 3 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave\
SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 32} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT\
0 WIDTH 4} TKEEP {PRESENT 0 WIDTH 4}}} intf_4 {ID 4 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT\
0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_5 {ID 5 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave\
SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT\
0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_6 {ID 6 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT\
0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_7 {ID 7 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave\
SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 512} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT\
0 WIDTH 64} TKEEP {PRESENT 0 WIDTH 64}}} intf_8 {ID 8 VLNV xilinx.com:interface:axis_rtl:1.0 MODE slave SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT\
0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}}} IPI_PROP_COUNT 0} \
    CONFIG.GUI_SELECT_INTERFACE {0} \
    CONFIG.GUI_SELECT_MODE {slave} \
    CONFIG.GUI_SELECT_VLNV {xilinx.com:interface:axis_rtl:1.0} \
  ] $dfx_decoupler_conv_axis_s


  # Create instance: dfx_decoupler_filter_axis_m, and set properties
  set dfx_decoupler_filter_axis_m [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_decoupler:1.0 dfx_decoupler_filter_axis_m ]
  set_property -dict [list \
    CONFIG.ALL_PARAMS {HAS_AXIS_CONTROL 0 HAS_AXIS_STATUS 0 INTF {intf_0 {ID 0 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH\
64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_1 {ID 1 VLNV xilinx.com:interface:axis_rtl:1.0\
SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT\
0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_2 {ID 2 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 32} TUSER {PRESENT 0 WIDTH\
0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 4} TKEEP {PRESENT 0 WIDTH 4}}} intf_3 {ID 3 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID\
{PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 32} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 4}\
TKEEP {PRESENT 0 WIDTH 4}}} intf_4 {ID 4 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT 1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST\
{PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT 0 WIDTH 8}}} intf_5 {ID 5 VLNV xilinx.com:interface:axis_rtl:1.0 SIGNALS {TVALID {PRESENT\
1 WIDTH 1} TREADY {PRESENT 1 WIDTH 1} TDATA {PRESENT 1 WIDTH 64} TUSER {PRESENT 0 WIDTH 0} TLAST {PRESENT 0 WIDTH 1} TID {PRESENT 0 WIDTH 0} TDEST {PRESENT 0 WIDTH 0} TSTRB {PRESENT 0 WIDTH 8} TKEEP {PRESENT\
0 WIDTH 8}}}} IPI_PROP_COUNT 0} \
    CONFIG.GUI_SELECT_INTERFACE {0} \
    CONFIG.GUI_SELECT_VLNV {xilinx.com:interface:axis_rtl:1.0} \
  ] $dfx_decoupler_filter_axis_m


  # Create instance: dfx_decoupler_filter_fault, and set properties
  set dfx_decoupler_filter_fault [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_decoupler:1.0 dfx_decoupler_filter_fault ]
  set_property -dict [list \
    CONFIG.ALL_PARAMS {INTF {intf_0 {ID 0 VLNV xilinx.com:signal:data_rtl:1.0 SIGNALS {DATA {PRESENT 1 WIDTH 1}}}} IPI_PROP_COUNT 0} \
    CONFIG.GUI_SELECT_VLNV {xilinx.com:signal:data_rtl:1.0} \
  ] $dfx_decoupler_filter_fault


  # Create instance: xlconcat_1, and set properties
  set xlconcat_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_1 ]
  set_property CONFIG.NUM_PORTS {9} $xlconcat_1


  # Create instance: conversion_ada_0, and set properties
  set conversion_ada_0 [ create_bd_cell -type ip -vlnv xilinx.com:RTLKernel:conversion_adaptor:1.0 conversion_ada_0 ]

  # Create instance: filter_resize_0, and set properties
  set filter_resize_0 [ create_bd_cell -type ip -vlnv xilinx.com:RTLKernel:filter_resize:1.0 filter_resize_0 ]

  # Create instance: axi4l_decoupler_filter, and set properties
  set block_name axi4l_decoupler
  set block_cell_name axi4l_decoupler_filter
  if { [catch {set axi4l_decoupler_filter [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $axi4l_decoupler_filter eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property CONFIG.IN_ADDR_WIDTH {10} $axi4l_decoupler_filter


  # Create instance: axi4l_decoupler_conv, and set properties
  set block_name axi4l_decoupler
  set block_cell_name axi4l_decoupler_conv
  if { [catch {set axi4l_decoupler_conv [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $axi4l_decoupler_conv eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property CONFIG.IN_ADDR_WIDTH {10} $axi4l_decoupler_conv


  # Create interface connections
  connect_bd_intf_net -intf_net axi4l_decoupler_conv_m_axi [get_bd_intf_pins conversion_ada_0/s_axi_control] [get_bd_intf_pins axi4l_decoupler_conv/m_axi]
  connect_bd_intf_net -intf_net axi4l_decoupler_filter_m_axi [get_bd_intf_pins filter_resize_0/s_axi_control] [get_bd_intf_pins axi4l_decoupler_filter/m_axi]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axi_ingr_frame_buffer [get_bd_intf_pins conversion_ada_0/m_axi_ingr_frame_buffer] [get_bd_intf_pins dfx_decoupler_conv_axi_m/rp_intf_0]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_egr_rx_data [get_bd_intf_pins conversion_ada_0/m_axis_egr_rx_data] [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_6]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_egr_rx_req [get_bd_intf_pins conversion_ada_0/m_axis_egr_rx_req] [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_7]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_egr_rx_resp0 [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_4] [get_bd_intf_pins conversion_ada_0/m_axis_egr_rx_resp0]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_egr_rx_resp1 [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_5] [get_bd_intf_pins conversion_ada_0/m_axis_egr_rx_resp1]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_ingr_tx_data0 [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_0] [get_bd_intf_pins conversion_ada_0/m_axis_ingr_tx_data0]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_ingr_tx_data1 [get_bd_intf_pins conversion_ada_0/m_axis_ingr_tx_data1] [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_1]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_ingr_tx_req0 [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_2] [get_bd_intf_pins conversion_ada_0/m_axis_ingr_tx_req0]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_ingr_tx_req1 [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_3] [get_bd_intf_pins conversion_ada_0/m_axis_ingr_tx_req1]
  connect_bd_intf_net -intf_net conversion_ada_0_m_axis_ingr_tx_resp [get_bd_intf_pins conversion_ada_0/m_axis_ingr_tx_resp] [get_bd_intf_pins dfx_decoupler_conv_axis_m/rp_intf_8]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axi_m_s_intf_0 [get_bd_intf_pins m_axi_conv] [get_bd_intf_pins dfx_decoupler_conv_axi_m/s_intf_0]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_0 [get_bd_intf_pins dfx_decoupler_filter_axis_s/s_intf_0] [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_0]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_1 [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_1] [get_bd_intf_pins dfx_decoupler_filter_axis_s/s_intf_1]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_2 [get_bd_intf_pins dfx_decoupler_filter_axis_s/s_intf_2] [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_2]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_3 [get_bd_intf_pins dfx_decoupler_filter_axis_s/s_intf_3] [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_3]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_4 [get_bd_intf_pins dfx_decoupler_filter_axis_s/s_intf_4] [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_4]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_5 [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_5] [get_bd_intf_pins dfx_decoupler_filter_axis_s/s_intf_5]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_6 [get_bd_intf_pins m_axis_egr_data] [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_6]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_7 [get_bd_intf_pins m_axis_egr_req] [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_7]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_m_s_intf_8 [get_bd_intf_pins m_axis_ingr_resp] [get_bd_intf_pins dfx_decoupler_conv_axis_m/s_intf_8]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_0 [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_0] [get_bd_intf_pins conversion_ada_0/s_axis_ingr_tx_resp0]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_1 [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_1] [get_bd_intf_pins conversion_ada_0/s_axis_ingr_tx_resp1]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_2 [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_2] [get_bd_intf_pins conversion_ada_0/s_axis_egr_rx_data0]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_3 [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_3] [get_bd_intf_pins conversion_ada_0/s_axis_egr_rx_data1]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_4 [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_4] [get_bd_intf_pins conversion_ada_0/s_axis_egr_rx_req0]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_5 [get_bd_intf_pins conversion_ada_0/s_axis_egr_rx_req1] [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_5]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_6 [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_6] [get_bd_intf_pins conversion_ada_0/s_axis_egr_rx_resp]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_7 [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_7] [get_bd_intf_pins conversion_ada_0/s_axis_ingr_tx_data]
  connect_bd_intf_net -intf_net dfx_decoupler_conv_axis_s_rp_intf_8 [get_bd_intf_pins conversion_ada_0/s_axis_ingr_tx_req] [get_bd_intf_pins dfx_decoupler_conv_axis_s/rp_intf_8]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_m_s_intf_0 [get_bd_intf_pins dfx_decoupler_filter_axis_m/s_intf_0] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_0]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_m_s_intf_1 [get_bd_intf_pins dfx_decoupler_filter_axis_m/s_intf_1] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_1]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_m_s_intf_2 [get_bd_intf_pins dfx_decoupler_filter_axis_m/s_intf_2] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_2]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_m_s_intf_3 [get_bd_intf_pins dfx_decoupler_filter_axis_m/s_intf_3] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_3]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_m_s_intf_4 [get_bd_intf_pins dfx_decoupler_filter_axis_m/s_intf_4] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_4]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_m_s_intf_5 [get_bd_intf_pins dfx_decoupler_filter_axis_m/s_intf_5] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_5]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_s_rp_intf_0 [get_bd_intf_pins filter_resize_0/s_axis_rx_data_0] [get_bd_intf_pins dfx_decoupler_filter_axis_s/rp_intf_0]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_s_rp_intf_1 [get_bd_intf_pins filter_resize_0/s_axis_rx_data_1] [get_bd_intf_pins dfx_decoupler_filter_axis_s/rp_intf_1]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_s_rp_intf_2 [get_bd_intf_pins filter_resize_0/s_axis_rx_req_0] [get_bd_intf_pins dfx_decoupler_filter_axis_s/rp_intf_2]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_s_rp_intf_3 [get_bd_intf_pins filter_resize_0/s_axis_rx_req_1] [get_bd_intf_pins dfx_decoupler_filter_axis_s/rp_intf_3]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_s_rp_intf_4 [get_bd_intf_pins filter_resize_0/s_axis_tx_resp_0] [get_bd_intf_pins dfx_decoupler_filter_axis_s/rp_intf_4]
  connect_bd_intf_net -intf_net dfx_decoupler_filter_axis_s_rp_intf_5 [get_bd_intf_pins filter_resize_0/s_axis_tx_resp_1] [get_bd_intf_pins dfx_decoupler_filter_axis_s/rp_intf_5]
  connect_bd_intf_net -intf_net filter_resize_0_m_axis_rx_resp_0 [get_bd_intf_pins filter_resize_0/m_axis_rx_resp_0] [get_bd_intf_pins dfx_decoupler_filter_axis_m/rp_intf_0]
  connect_bd_intf_net -intf_net filter_resize_0_m_axis_rx_resp_1 [get_bd_intf_pins filter_resize_0/m_axis_rx_resp_1] [get_bd_intf_pins dfx_decoupler_filter_axis_m/rp_intf_1]
  connect_bd_intf_net -intf_net filter_resize_0_m_axis_tx_data_0 [get_bd_intf_pins filter_resize_0/m_axis_tx_data_0] [get_bd_intf_pins dfx_decoupler_filter_axis_m/rp_intf_2]
  connect_bd_intf_net -intf_net filter_resize_0_m_axis_tx_data_1 [get_bd_intf_pins filter_resize_0/m_axis_tx_data_1] [get_bd_intf_pins dfx_decoupler_filter_axis_m/rp_intf_3]
  connect_bd_intf_net -intf_net filter_resize_0_m_axis_tx_req_0 [get_bd_intf_pins filter_resize_0/m_axis_tx_req_0] [get_bd_intf_pins dfx_decoupler_filter_axis_m/rp_intf_4]
  connect_bd_intf_net -intf_net filter_resize_0_m_axis_tx_req_1 [get_bd_intf_pins filter_resize_0/m_axis_tx_req_1] [get_bd_intf_pins dfx_decoupler_filter_axis_m/rp_intf_5]
  connect_bd_intf_net -intf_net s_axi_control_conv_1 [get_bd_intf_pins s_axi_control_conv] [get_bd_intf_pins axi4l_decoupler_conv/s_axi]
  connect_bd_intf_net -intf_net s_axi_control_func_1 [get_bd_intf_pins s_axi_control_func] [get_bd_intf_pins axi4l_decoupler_filter/s_axi]
  connect_bd_intf_net -intf_net s_axis_egr_resp_1 [get_bd_intf_pins s_axis_egr_resp] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_6]
  connect_bd_intf_net -intf_net s_axis_ingr_data_1 [get_bd_intf_pins s_axis_ingr_data] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_7]
  connect_bd_intf_net -intf_net s_axis_ingr_req_1 [get_bd_intf_pins s_axis_ingr_req] [get_bd_intf_pins dfx_decoupler_conv_axis_s/s_intf_8]

  # Create port connections
  connect_bd_net -net ap_clk_0_1 [get_bd_pins aclk_mm] [get_bd_pins conversion_ada_0/ap_clk] [get_bd_pins filter_resize_0/ap_clk] [get_bd_pins axi4l_decoupler_filter/user_clk] [get_bd_pins axi4l_decoupler_conv/user_clk]
  connect_bd_net -net ap_rst_n1_1 [get_bd_pins aresetn_mm_conv] [get_bd_pins conversion_ada_0/ap_rst_n]
  connect_bd_net -net ap_rst_n_1 [get_bd_pins aresetn_mm_filter] [get_bd_pins filter_resize_0/ap_rst_n] [get_bd_pins axi4l_decoupler_filter/reset_n] [get_bd_pins axi4l_decoupler_conv/reset_n]
  connect_bd_net -net axi4l_decoupler_conv_decouple_status [get_bd_pins axi4l_decoupler_conv/decouple_status] [get_bd_pins xlconcat_1/In5]
  connect_bd_net -net axi4l_decoupler_filter_decouple_status [get_bd_pins axi4l_decoupler_filter/decouple_status] [get_bd_pins xlconcat_1/In3]
  connect_bd_net -net conversion_ada_0_detect_fault [get_bd_pins conversion_ada_0/detect_fault] [get_bd_pins dfx_decoupler_conv_fault/rp_intf_0_DATA]
  connect_bd_net -net decouple1_1 [get_bd_pins decouple_conv] [get_bd_pins dfx_decoupler_conv_axi_m/decouple] [get_bd_pins dfx_decoupler_conv_axis_s/decouple] [get_bd_pins dfx_decoupler_conv_fault/decouple] [get_bd_pins dfx_decoupler_conv_axis_m/decouple] [get_bd_pins axi4l_decoupler_conv/decouple_enable]
  connect_bd_net -net decouple_1 [get_bd_pins decouple_filter] [get_bd_pins dfx_decoupler_filter_axis_m/decouple] [get_bd_pins dfx_decoupler_filter_axis_s/decouple] [get_bd_pins dfx_decoupler_filter_fault/decouple] [get_bd_pins axi4l_decoupler_filter/decouple_enable]
  connect_bd_net -net dfx_decoupler_conv_axi_m_decouple_status [get_bd_pins dfx_decoupler_conv_axi_m/decouple_status] [get_bd_pins xlconcat_1/In7]
  connect_bd_net -net dfx_decoupler_conv_axis_m_decouple_status [get_bd_pins dfx_decoupler_conv_axis_m/decouple_status] [get_bd_pins xlconcat_1/In4]
  connect_bd_net -net dfx_decoupler_conv_axis_s_decouple_status [get_bd_pins dfx_decoupler_conv_axis_s/decouple_status] [get_bd_pins xlconcat_1/In6]
  connect_bd_net -net dfx_decoupler_conv_fault_decouple_status [get_bd_pins dfx_decoupler_conv_fault/decouple_status] [get_bd_pins xlconcat_1/In8]
  connect_bd_net -net dfx_decoupler_conv_fault_s_intf_0_DATA [get_bd_pins dfx_decoupler_conv_fault/s_intf_0_DATA] [get_bd_pins detect_fault_conv]
  connect_bd_net -net dfx_decoupler_filter_axis_m_decouple_status [get_bd_pins dfx_decoupler_filter_axis_m/decouple_status] [get_bd_pins xlconcat_1/In2]
  connect_bd_net -net dfx_decoupler_filter_axis_s_decouple_status [get_bd_pins dfx_decoupler_filter_axis_s/decouple_status] [get_bd_pins xlconcat_1/In1]
  connect_bd_net -net dfx_decoupler_filter_fault_decouple_status [get_bd_pins dfx_decoupler_filter_fault/decouple_status] [get_bd_pins xlconcat_1/In0]
  connect_bd_net -net dfx_decoupler_filter_fault_s_intf_0_DATA [get_bd_pins dfx_decoupler_filter_fault/s_intf_0_DATA] [get_bd_pins detect_fault_func]
  connect_bd_net -net filter_resize_0_detect_fault [get_bd_pins filter_resize_0/detect_fault] [get_bd_pins dfx_decoupler_filter_fault/rp_intf_0_DATA]
  connect_bd_net -net xlconcat_1_dout [get_bd_pins xlconcat_1/dout] [get_bd_pins decoupler_status]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: chain_1
proc create_hier_cell_chain_1 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_chain_1() - Empty argument(s)!"}
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
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_ingr_req

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_ingr_resp

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_ingr_data

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_egr_req

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_egr_resp

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_egr_data

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_control_direct

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_extif0_rd

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_extif1_rd

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_extif0_wr

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_extif1_wr

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_extif0_cmd

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_extif1_cmd

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_extif0_evt

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_extif1_evt

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_control_chain


  # Create pins
  create_bd_pin -dir O detect_fault_direct
  create_bd_pin -dir O detect_fault_chain
  create_bd_pin -dir I -type clk aclk_mm
  create_bd_pin -dir I -type rst aresetn_mm

  # Create instance: chain_control_0, and set properties
  set chain_control_0 [ create_bd_cell -type ip -vlnv xilinx.com:RTLKernel:chain_control:1.0 chain_control_0 ]

  # Create instance: direct_trans_a_0, and set properties
  set direct_trans_a_0 [ create_bd_cell -type ip -vlnv xilinx.com:RTLKernel:direct_trans_adaptor:1.0 direct_trans_a_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins direct_trans_a_0/m_axis_ingr_tx_req] [get_bd_intf_pins m_axis_ingr_req]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins direct_trans_a_0/s_axis_ingr_tx_resp] [get_bd_intf_pins s_axis_ingr_resp]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins direct_trans_a_0/m_axis_ingr_tx_data] [get_bd_intf_pins m_axis_ingr_data]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins direct_trans_a_0/s_axis_egr_rx_req] [get_bd_intf_pins s_axis_egr_req]
  connect_bd_intf_net -intf_net Conn5 [get_bd_intf_pins direct_trans_a_0/m_axis_egr_rx_resp] [get_bd_intf_pins m_axis_egr_resp]
  connect_bd_intf_net -intf_net Conn6 [get_bd_intf_pins direct_trans_a_0/s_axis_egr_rx_data] [get_bd_intf_pins s_axis_egr_data]
  connect_bd_intf_net -intf_net Conn7 [get_bd_intf_pins direct_trans_a_0/s_axi_control] [get_bd_intf_pins s_axi_control_direct]
  connect_bd_intf_net -intf_net Conn8 [get_bd_intf_pins chain_control_0/m_axi_extif0_buffer_rd] [get_bd_intf_pins m_axi_extif0_rd]
  connect_bd_intf_net -intf_net Conn9 [get_bd_intf_pins chain_control_0/m_axi_extif1_buffer_rd] [get_bd_intf_pins m_axi_extif1_rd]
  connect_bd_intf_net -intf_net Conn10 [get_bd_intf_pins chain_control_0/m_axi_extif0_buffer_wr] [get_bd_intf_pins m_axi_extif0_wr]
  connect_bd_intf_net -intf_net Conn11 [get_bd_intf_pins chain_control_0/m_axi_extif1_buffer_wr] [get_bd_intf_pins m_axi_extif1_wr]
  connect_bd_intf_net -intf_net Conn12 [get_bd_intf_pins chain_control_0/m_axis_extif0_cmd] [get_bd_intf_pins m_axis_extif0_cmd]
  connect_bd_intf_net -intf_net Conn13 [get_bd_intf_pins chain_control_0/m_axis_extif1_cmd] [get_bd_intf_pins m_axis_extif1_cmd]
  connect_bd_intf_net -intf_net Conn14 [get_bd_intf_pins chain_control_0/s_axis_extif0_evt] [get_bd_intf_pins s_axis_extif0_evt]
  connect_bd_intf_net -intf_net Conn15 [get_bd_intf_pins chain_control_0/s_axis_extif1_evt] [get_bd_intf_pins s_axis_extif1_evt]
  connect_bd_intf_net -intf_net Conn16 [get_bd_intf_pins chain_control_0/s_axi_control] [get_bd_intf_pins s_axi_control_chain]
  connect_bd_intf_net -intf_net chain_control_0_m_axis_egr_rx_resp [get_bd_intf_pins chain_control_0/m_axis_egr_rx_resp] [get_bd_intf_pins direct_trans_a_0/s_axis_egr_tx_resp]
  connect_bd_intf_net -intf_net chain_control_0_m_axis_ingr_tx_data [get_bd_intf_pins chain_control_0/m_axis_ingr_tx_data] [get_bd_intf_pins direct_trans_a_0/s_axis_ingr_rx_data]
  connect_bd_intf_net -intf_net chain_control_0_m_axis_ingr_tx_req [get_bd_intf_pins chain_control_0/m_axis_ingr_tx_req] [get_bd_intf_pins direct_trans_a_0/s_axis_ingr_rx_req]
  connect_bd_intf_net -intf_net direct_trans_a_0_m_axis_egr_tx_data [get_bd_intf_pins direct_trans_a_0/m_axis_egr_tx_data] [get_bd_intf_pins chain_control_0/s_axis_egr_rx_data]
  connect_bd_intf_net -intf_net direct_trans_a_0_m_axis_egr_tx_req [get_bd_intf_pins direct_trans_a_0/m_axis_egr_tx_req] [get_bd_intf_pins chain_control_0/s_axis_egr_rx_req]
  connect_bd_intf_net -intf_net direct_trans_a_0_m_axis_ingr_rx_resp [get_bd_intf_pins direct_trans_a_0/m_axis_ingr_rx_resp] [get_bd_intf_pins chain_control_0/s_axis_ingr_tx_resp]

  # Create port connections
  connect_bd_net -net ap_clk_0_1 [get_bd_pins aclk_mm] [get_bd_pins chain_control_0/ap_clk] [get_bd_pins direct_trans_a_0/ap_clk]
  connect_bd_net -net ap_rst_n_0_1 [get_bd_pins aresetn_mm] [get_bd_pins chain_control_0/ap_rst_n] [get_bd_pins direct_trans_a_0/ap_rst_n]
  connect_bd_net -net chain_control_0_detect_fault [get_bd_pins chain_control_0/detect_fault] [get_bd_pins detect_fault_chain]
  connect_bd_net -net direct_trans_a_0_detect_fault [get_bd_pins direct_trans_a_0/detect_fault] [get_bd_pins detect_fault_direct]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: chain_0
proc create_hier_cell_chain_0 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_chain_0() - Empty argument(s)!"}
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
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_ingr_req

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_ingr_resp

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_ingr_data

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_egr_req

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_egr_resp

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_egr_data

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_control_direct

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_extif0_rd

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_extif1_rd

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_extif0_wr

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_extif1_wr

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_extif0_cmd

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_extif1_cmd

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_extif0_evt

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_extif1_evt

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_control_chain


  # Create pins
  create_bd_pin -dir O detect_fault_direct
  create_bd_pin -dir O detect_fault_chain
  create_bd_pin -dir I -type clk aclk_mm
  create_bd_pin -dir I -type rst aresetn_mm

  # Create instance: chain_control_0, and set properties
  set chain_control_0 [ create_bd_cell -type ip -vlnv xilinx.com:RTLKernel:chain_control:1.0 chain_control_0 ]

  # Create instance: direct_trans_a_0, and set properties
  set direct_trans_a_0 [ create_bd_cell -type ip -vlnv xilinx.com:RTLKernel:direct_trans_adaptor:1.0 direct_trans_a_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins direct_trans_a_0/m_axis_ingr_tx_req] [get_bd_intf_pins m_axis_ingr_req]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins direct_trans_a_0/s_axis_ingr_tx_resp] [get_bd_intf_pins s_axis_ingr_resp]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins direct_trans_a_0/m_axis_ingr_tx_data] [get_bd_intf_pins m_axis_ingr_data]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins direct_trans_a_0/s_axis_egr_rx_req] [get_bd_intf_pins s_axis_egr_req]
  connect_bd_intf_net -intf_net Conn5 [get_bd_intf_pins direct_trans_a_0/m_axis_egr_rx_resp] [get_bd_intf_pins m_axis_egr_resp]
  connect_bd_intf_net -intf_net Conn6 [get_bd_intf_pins direct_trans_a_0/s_axis_egr_rx_data] [get_bd_intf_pins s_axis_egr_data]
  connect_bd_intf_net -intf_net Conn7 [get_bd_intf_pins direct_trans_a_0/s_axi_control] [get_bd_intf_pins s_axi_control_direct]
  connect_bd_intf_net -intf_net Conn8 [get_bd_intf_pins chain_control_0/m_axi_extif0_buffer_rd] [get_bd_intf_pins m_axi_extif0_rd]
  connect_bd_intf_net -intf_net Conn9 [get_bd_intf_pins chain_control_0/m_axi_extif1_buffer_rd] [get_bd_intf_pins m_axi_extif1_rd]
  connect_bd_intf_net -intf_net Conn10 [get_bd_intf_pins chain_control_0/m_axi_extif0_buffer_wr] [get_bd_intf_pins m_axi_extif0_wr]
  connect_bd_intf_net -intf_net Conn11 [get_bd_intf_pins chain_control_0/m_axi_extif1_buffer_wr] [get_bd_intf_pins m_axi_extif1_wr]
  connect_bd_intf_net -intf_net Conn12 [get_bd_intf_pins chain_control_0/m_axis_extif0_cmd] [get_bd_intf_pins m_axis_extif0_cmd]
  connect_bd_intf_net -intf_net Conn13 [get_bd_intf_pins chain_control_0/m_axis_extif1_cmd] [get_bd_intf_pins m_axis_extif1_cmd]
  connect_bd_intf_net -intf_net Conn14 [get_bd_intf_pins chain_control_0/s_axis_extif0_evt] [get_bd_intf_pins s_axis_extif0_evt]
  connect_bd_intf_net -intf_net Conn15 [get_bd_intf_pins chain_control_0/s_axis_extif1_evt] [get_bd_intf_pins s_axis_extif1_evt]
  connect_bd_intf_net -intf_net Conn16 [get_bd_intf_pins chain_control_0/s_axi_control] [get_bd_intf_pins s_axi_control_chain]
  connect_bd_intf_net -intf_net chain_control_0_m_axis_egr_rx_resp [get_bd_intf_pins chain_control_0/m_axis_egr_rx_resp] [get_bd_intf_pins direct_trans_a_0/s_axis_egr_tx_resp]
  connect_bd_intf_net -intf_net chain_control_0_m_axis_ingr_tx_data [get_bd_intf_pins chain_control_0/m_axis_ingr_tx_data] [get_bd_intf_pins direct_trans_a_0/s_axis_ingr_rx_data]
  connect_bd_intf_net -intf_net chain_control_0_m_axis_ingr_tx_req [get_bd_intf_pins chain_control_0/m_axis_ingr_tx_req] [get_bd_intf_pins direct_trans_a_0/s_axis_ingr_rx_req]
  connect_bd_intf_net -intf_net direct_trans_a_0_m_axis_egr_tx_data [get_bd_intf_pins direct_trans_a_0/m_axis_egr_tx_data] [get_bd_intf_pins chain_control_0/s_axis_egr_rx_data]
  connect_bd_intf_net -intf_net direct_trans_a_0_m_axis_egr_tx_req [get_bd_intf_pins direct_trans_a_0/m_axis_egr_tx_req] [get_bd_intf_pins chain_control_0/s_axis_egr_rx_req]
  connect_bd_intf_net -intf_net direct_trans_a_0_m_axis_ingr_rx_resp [get_bd_intf_pins direct_trans_a_0/m_axis_ingr_rx_resp] [get_bd_intf_pins chain_control_0/s_axis_ingr_tx_resp]

  # Create port connections
  connect_bd_net -net ap_clk_0_1 [get_bd_pins aclk_mm] [get_bd_pins chain_control_0/ap_clk] [get_bd_pins direct_trans_a_0/ap_clk]
  connect_bd_net -net ap_rst_n_0_1 [get_bd_pins aresetn_mm] [get_bd_pins chain_control_0/ap_rst_n] [get_bd_pins direct_trans_a_0/ap_rst_n]
  connect_bd_net -net chain_control_0_detect_fault [get_bd_pins chain_control_0/detect_fault] [get_bd_pins detect_fault_chain]
  connect_bd_net -net direct_trans_a_0_detect_fault [get_bd_pins direct_trans_a_0/detect_fault] [get_bd_pins detect_fault_direct]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: ss_ucs
proc create_hier_cell_ss_ucs { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_ss_ucs() - Empty argument(s)!"}
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

  # Create pins
  create_bd_pin -dir I -type clk clk_in1
  create_bd_pin -dir O -type clk clk_out1
  create_bd_pin -dir I dcm_locked
  create_bd_pin -dir I -type rst ext_reset_in
  create_bd_pin -dir O -from 0 -to 0 -type rst peripheral_aresetn
  create_bd_pin -dir O -from 0 -to 0 -type rst peripheral_aresetn1
  create_bd_pin -dir I -type rst reset
  create_bd_pin -dir I -type clk slowest_sync_clk

  # Create instance: clk_wiz_0, and set properties
  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {40.0} \
    CONFIG.CLKOUT1_JITTER {134.506} \
    CONFIG.CLKOUT1_PHASE_ERROR {154.678} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {24.000} \
    CONFIG.MMCM_CLKIN1_PERIOD {4.000} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.MMCM_DIVCLK_DIVIDE {5} \
  ] $clk_wiz_0


  # Create instance: ss_usr_arst_300, and set properties
  set ss_usr_arst_300 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 ss_usr_arst_300 ]

  # Create instance: ss_usr_arst_50, and set properties
  set ss_usr_arst_50 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 ss_usr_arst_50 ]

  # Create port connections
  connect_bd_net -net clk_wiz_0_clk_out1 [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins clk_out1] [get_bd_pins ss_usr_arst_300/slowest_sync_clk]
  connect_bd_net -net clk_wiz_0_locked [get_bd_pins clk_wiz_0/locked] [get_bd_pins ss_usr_arst_300/dcm_locked]
  connect_bd_net -net clk_wiz_250_2_100_clk_out_pcie50 [get_bd_pins slowest_sync_clk] [get_bd_pins ss_usr_arst_50/slowest_sync_clk]
  connect_bd_net -net clk_wiz_250_2_100_locked [get_bd_pins dcm_locked] [get_bd_pins ss_usr_arst_50/dcm_locked]
  connect_bd_net -net ext_reset_in11_1 [get_bd_pins ss_usr_arst_50/peripheral_aresetn] [get_bd_pins peripheral_aresetn1]
  connect_bd_net -net ext_reset_in7_1 [get_bd_pins ss_usr_arst_300/peripheral_aresetn] [get_bd_pins peripheral_aresetn]
  connect_bd_net -net pcie4c_uscale_plus_0_user_clk [get_bd_pins clk_in1] [get_bd_pins clk_wiz_0/clk_in1]
  connect_bd_net -net proc_sys_reset_50_peripheral_reset [get_bd_pins ext_reset_in] [get_bd_pins ss_usr_arst_50/ext_reset_in]
  connect_bd_net -net util_vector_logic_0_Res [get_bd_pins reset] [get_bd_pins clk_wiz_0/reset] [get_bd_pins ss_usr_arst_300/ext_reset_in]

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
  set pcie4_mgt [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pcie4_mgt ]

  set satellite_uart [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:uart_rtl:1.0 satellite_uart ]

  set sys_clk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sys_clk ]

  set ddr4_sdram_c0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_sdram_c0 ]

  set default_300mhz_clk0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 default_300mhz_clk0 ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {300000000} \
   ] $default_300mhz_clk0

  set ddr4_sdram_c1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_sdram_c1 ]

  set default_300mhz_clk1 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 default_300mhz_clk1 ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {300000000} \
   ] $default_300mhz_clk1

  set ddr4_sdram_c2 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_sdram_c2 ]

  set default_300mhz_clk2 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 default_300mhz_clk2 ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {300000000} \
   ] $default_300mhz_clk2

  set ddr4_sdram_c3 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_sdram_c3 ]

  set default_300mhz_clk3 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 default_300mhz_clk3 ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {300000000} \
   ] $default_300mhz_clk3


  # Create ports
  set pcie_perstn [ create_bd_port -dir I -type rst pcie_perstn ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_LOW} \
 ] $pcie_perstn
  set satellite_gpio [ create_bd_port -dir I -from 3 -to 0 -type intr satellite_gpio ]
  set_property -dict [ list \
   CONFIG.PortWidth {4} \
   CONFIG.SENSITIVITY {EDGE_RISING} \
 ] $satellite_gpio
  set qsfp0_reset_l_0 [ create_bd_port -dir O -from 0 -to 0 qsfp0_reset_l_0 ]
  set qsfp0_lpmode_0 [ create_bd_port -dir O -from 0 -to 0 qsfp0_lpmode_0 ]
  set qsfp0_modsel_l_0 [ create_bd_port -dir O -from 0 -to 0 qsfp0_modsel_l_0 ]
  set qsfp0_int_l_0 [ create_bd_port -dir I -from 0 -to 0 qsfp0_int_l_0 ]
  set qsfp0_modprs_l_0 [ create_bd_port -dir I -from 0 -to 0 qsfp0_modprs_l_0 ]

  # Create instance: ss_ucs
  create_hier_cell_ss_ucs [current_bd_instance .] ss_ucs

  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]

  # Create instance: c_shift_ram_0, and set properties
  set c_shift_ram_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:c_shift_ram:12.0 c_shift_ram_0 ]
  set_property -dict [list \
    CONFIG.AsyncInitVal {0} \
    CONFIG.DefaultData {0} \
    CONFIG.Depth {1} \
    CONFIG.Width {1} \
  ] $c_shift_ram_0


  # Create instance: axi_interconnect_4, and set properties
  set axi_interconnect_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_4 ]
  set_property -dict [list \
    CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
    CONFIG.NUM_MI {4} \
    CONFIG.XBAR_DATA_WIDTH {512} \
  ] $axi_interconnect_4


  # Create instance: axi_interconnect_ddr0, and set properties
  set axi_interconnect_ddr0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_ddr0 ]
  set_property -dict [list \
    CONFIG.M00_HAS_REGSLICE {4} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {11} \
    CONFIG.S00_HAS_REGSLICE {4} \
    CONFIG.S01_HAS_REGSLICE {4} \
    CONFIG.S02_HAS_REGSLICE {4} \
    CONFIG.S03_HAS_REGSLICE {4} \
    CONFIG.S04_HAS_REGSLICE {4} \
    CONFIG.S05_HAS_REGSLICE {4} \
    CONFIG.S06_HAS_REGSLICE {4} \
    CONFIG.S07_HAS_REGSLICE {4} \
    CONFIG.S08_HAS_REGSLICE {4} \
    CONFIG.S09_HAS_REGSLICE {4} \
    CONFIG.S10_HAS_REGSLICE {4} \
  ] $axi_interconnect_ddr0


  # Create instance: axi_interconnect_ddr2, and set properties
  set axi_interconnect_ddr2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_ddr2 ]
  set_property -dict [list \
    CONFIG.M00_HAS_REGSLICE {4} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {7} \
    CONFIG.S00_HAS_REGSLICE {4} \
    CONFIG.S01_HAS_REGSLICE {4} \
    CONFIG.S02_HAS_REGSLICE {4} \
    CONFIG.S03_HAS_REGSLICE {4} \
    CONFIG.S04_HAS_REGSLICE {4} \
    CONFIG.S05_HAS_REGSLICE {4} \
    CONFIG.S06_HAS_REGSLICE {4} \
  ] $axi_interconnect_ddr2


  # Create instance: axi_interconnect_ddr3, and set properties
  set axi_interconnect_ddr3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_ddr3 ]
  set_property -dict [list \
    CONFIG.M00_HAS_REGSLICE {4} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {7} \
    CONFIG.S00_HAS_REGSLICE {4} \
    CONFIG.S01_HAS_REGSLICE {4} \
    CONFIG.S02_HAS_REGSLICE {4} \
    CONFIG.S03_HAS_REGSLICE {4} \
    CONFIG.S04_HAS_REGSLICE {4} \
    CONFIG.S05_HAS_REGSLICE {4} \
    CONFIG.S06_HAS_REGSLICE {4} \
  ] $axi_interconnect_ddr3


  # Create instance: axi_interconnect_lldma_ddr_0, and set properties
  set axi_interconnect_lldma_ddr_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_lldma_ddr_0 ]
  set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {4} \
    CONFIG.S00_HAS_DATA_FIFO {1} \
    CONFIG.S01_HAS_DATA_FIFO {1} \
    CONFIG.S02_HAS_DATA_FIFO {1} \
    CONFIG.S03_HAS_DATA_FIFO {1} \
  ] $axi_interconnect_lldma_ddr_0


  # Create instance: axi_interconnect_ddr1, and set properties
  set axi_interconnect_ddr1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_ddr1 ]
  set_property -dict [list \
    CONFIG.M00_HAS_REGSLICE {4} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {5} \
    CONFIG.S00_HAS_REGSLICE {4} \
    CONFIG.S01_HAS_REGSLICE {4} \
    CONFIG.S02_HAS_REGSLICE {4} \
    CONFIG.S03_HAS_REGSLICE {4} \
    CONFIG.S04_HAS_REGSLICE {4} \
  ] $axi_interconnect_ddr1


  # Create instance: axi_interconnect_lldma_ddr_1, and set properties
  set axi_interconnect_lldma_ddr_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_lldma_ddr_1 ]
  set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {4} \
    CONFIG.S00_HAS_DATA_FIFO {1} \
    CONFIG.S01_HAS_DATA_FIFO {1} \
    CONFIG.S02_HAS_DATA_FIFO {1} \
    CONFIG.S03_HAS_DATA_FIFO {1} \
  ] $axi_interconnect_lldma_ddr_1


  # Create instance: axi_register_slice_0, and set properties
  set axi_register_slice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 axi_register_slice_0 ]
  set_property -dict [list \
    CONFIG.REG_R {7} \
    CONFIG.REG_W {7} \
  ] $axi_register_slice_0


  # Create instance: util_vector_logic_0, and set properties
  set util_vector_logic_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_0 ]
  set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
  ] $util_vector_logic_0


  # Create instance: util_vector_logic_1, and set properties
  set util_vector_logic_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_1 ]
  set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
  ] $util_vector_logic_1


  # Create instance: util_vector_logic_2, and set properties
  set util_vector_logic_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_2 ]
  set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
  ] $util_vector_logic_2


  # Create instance: util_vector_logic_3, and set properties
  set util_vector_logic_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_3 ]
  set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
  ] $util_vector_logic_3


  # Create instance: util_vector_logic_5, and set properties
  set util_vector_logic_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_5 ]
  set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
  ] $util_vector_logic_5


  # Create instance: util_vector_logic_4, and set properties
  set util_vector_logic_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_4 ]
  set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
  ] $util_vector_logic_4


  # Create instance: xlconstant_val0, and set properties
  set xlconstant_val0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_val0 ]
  set_property -dict [list \
    CONFIG.CONST_VAL {0} \
    CONFIG.CONST_WIDTH {8} \
  ] $xlconstant_val0


  # Create instance: xlconstant_val1, and set properties
  set xlconstant_val1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_val1 ]

  # Create instance: axi_gpio_0, and set properties
  set axi_gpio_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0 ]

  # Create instance: clk_wiz_250_2_100, and set properties
  set clk_wiz_250_2_100 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_250_2_100 ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {40.0} \
    CONFIG.CLKIN2_JITTER_PS {100.0} \
    CONFIG.CLKOUT1_JITTER {153.164} \
    CONFIG.CLKOUT1_PHASE_ERROR {154.678} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50.000} \
    CONFIG.CLKOUT2_JITTER {134.506} \
    CONFIG.CLKOUT2_PHASE_ERROR {154.678} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_JITTER {111.430} \
    CONFIG.CLKOUT3_PHASE_ERROR {154.678} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {300.000} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLKOUT4_JITTER {119.392} \
    CONFIG.CLKOUT4_PHASE_ERROR {154.678} \
    CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.CLKOUT4_USED {true} \
    CONFIG.CLKOUT5_JITTER {125.400} \
    CONFIG.CLKOUT5_PHASE_ERROR {154.678} \
    CONFIG.CLKOUT5_REQUESTED_OUT_FREQ {150.000} \
    CONFIG.CLKOUT5_USED {true} \
    CONFIG.CLK_OUT1_PORT {clk_out_pcie50} \
    CONFIG.CLK_OUT2_PORT {clk_out_pcie100} \
    CONFIG.CLK_OUT3_PORT {clk_out_pcie300} \
    CONFIG.CLK_OUT4_PORT {clk_out_pcie200} \
    CONFIG.CLK_OUT5_PORT {clk_out_pcie150} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {24.000} \
    CONFIG.MMCM_CLKIN1_PERIOD {4.000} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {24.000} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {12} \
    CONFIG.MMCM_CLKOUT2_DIVIDE {4} \
    CONFIG.MMCM_CLKOUT3_DIVIDE {6} \
    CONFIG.MMCM_CLKOUT4_DIVIDE {8} \
    CONFIG.MMCM_DIVCLK_DIVIDE {5} \
    CONFIG.NUM_OUT_CLKS {5} \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.SECONDARY_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.USE_INCLK_SWITCHOVER {false} \
    CONFIG.USE_LOCKED {true} \
  ] $clk_wiz_250_2_100


  # Create instance: cms_subsystem_0, and set properties
  set cms_subsystem_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:cms_subsystem:4.0 cms_subsystem_0 ]

  # Create instance: ddr4_0, and set properties
  set ddr4_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr4_0 ]
  set_property -dict [list \
    CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
    CONFIG.C0.DDR4_AUTO_AP_COL_A3 {true} \
    CONFIG.C0.DDR4_AxiAddressWidth {34} \
    CONFIG.C0.DDR4_Mem_Add_Map {ROW_COLUMN_BANK_INTLV} \
    CONFIG.C0_CLOCK_BOARD_INTERFACE {default_300mhz_clk0} \
    CONFIG.C0_DDR4_BOARD_INTERFACE {ddr4_sdram_c0} \
  ] $ddr4_0


  # Create instance: ddr4_1, and set properties
  set ddr4_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr4_1 ]
  set_property -dict [list \
    CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
    CONFIG.C0.DDR4_AUTO_AP_COL_A3 {true} \
    CONFIG.C0.DDR4_AxiAddressWidth {34} \
    CONFIG.C0.DDR4_Mem_Add_Map {ROW_COLUMN_BANK_INTLV} \
    CONFIG.C0_CLOCK_BOARD_INTERFACE {default_300mhz_clk1} \
    CONFIG.C0_DDR4_BOARD_INTERFACE {ddr4_sdram_c1} \
  ] $ddr4_1


  # Create instance: ddr4_2, and set properties
  set ddr4_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr4_2 ]
  set_property -dict [list \
    CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
    CONFIG.C0.DDR4_AUTO_AP_COL_A3 {true} \
    CONFIG.C0.DDR4_AxiAddressWidth {34} \
    CONFIG.C0.DDR4_Mem_Add_Map {ROW_COLUMN_BANK_INTLV} \
    CONFIG.C0_CLOCK_BOARD_INTERFACE {default_300mhz_clk2} \
    CONFIG.C0_DDR4_BOARD_INTERFACE {ddr4_sdram_c2} \
  ] $ddr4_2


  # Create instance: ddr4_3, and set properties
  set ddr4_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr4_3 ]
  set_property -dict [list \
    CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
    CONFIG.C0.DDR4_AUTO_AP_COL_A3 {true} \
    CONFIG.C0.DDR4_AxiAddressWidth {34} \
    CONFIG.C0.DDR4_Mem_Add_Map {ROW_COLUMN_BANK_INTLV} \
    CONFIG.C0_CLOCK_BOARD_INTERFACE {default_300mhz_clk3} \
    CONFIG.C0_DDR4_BOARD_INTERFACE {ddr4_sdram_c3} \
  ] $ddr4_3


  # Create instance: pcie4_uscale_plus_0, and set properties
  set pcie4_uscale_plus_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:pcie4_uscale_plus:1.3 pcie4_uscale_plus_0 ]
  set_property -dict [list \
    CONFIG.AXISTEN_IF_EXT_512_RQ_STRADDLE {false} \
    CONFIG.PCIE_BOARD_INTERFACE {Custom} \
    CONFIG.PF0_DEVICE_ID {903F} \
    CONFIG.PF2_DEVICE_ID {943F} \
    CONFIG.PF3_DEVICE_ID {963F} \
    CONFIG.PL_DISABLE_LANE_REVERSAL {true} \
    CONFIG.PL_LINK_CAP_MAX_LINK_SPEED {8.0_GT/s} \
    CONFIG.PL_LINK_CAP_MAX_LINK_WIDTH {X16} \
    CONFIG.SYS_RST_N_BOARD_INTERFACE {Custom} \
    CONFIG.axisten_freq {250} \
    CONFIG.axisten_if_enable_client_tag {true} \
    CONFIG.axisten_if_width {512_bit} \
    CONFIG.en_gt_selection {true} \
    CONFIG.mcap_enablement {Tandem_PCIe} \
    CONFIG.mcap_fpga_bitstream_version {0100001C} \
    CONFIG.mode_selection {Advanced} \
    CONFIG.pf0_bar0_64bit {true} \
    CONFIG.pf0_bar0_scale {Megabytes} \
    CONFIG.pf0_bar0_size {2} \
    CONFIG.pf0_base_class_menu {Processing_accelerators} \
    CONFIG.pf0_class_code_base {12} \
    CONFIG.pf0_class_code_sub {00} \
    CONFIG.plltype {QPLL1} \
    CONFIG.xlnx_ref_board {AU250} \
  ] $pcie4_uscale_plus_0


  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

  # Create instance: proc_sys_reset_100, and set properties
  set proc_sys_reset_100 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_100 ]

  # Create instance: proc_sys_reset_150, and set properties
  set proc_sys_reset_150 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_150 ]
  set_property CONFIG.C_AUX_RESET_HIGH {0} $proc_sys_reset_150


  # Create instance: proc_sys_reset_200, and set properties
  set proc_sys_reset_200 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_200 ]
  set_property CONFIG.C_AUX_RESET_HIGH {0} $proc_sys_reset_200


  # Create instance: proc_sys_reset_300, and set properties
  set proc_sys_reset_300 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_300 ]

  # Create instance: proc_sys_reset_50, and set properties
  set proc_sys_reset_50 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_50 ]

  # Create instance: util_ds_buf_0, and set properties
  set util_ds_buf_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf_0 ]
  set_property -dict [list \
    CONFIG.C_BUF_TYPE {IBUFDSGTE} \
    CONFIG.DIFF_CLK_IN_BOARD_INTERFACE {Custom} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $util_ds_buf_0


  # Create instance: axis_register_slice_16, and set properties
  set axis_register_slice_16 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_16 ]

  # Create instance: axis_register_slice_17, and set properties
  set axis_register_slice_17 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_17 ]

  # Create instance: axis_clock_converter_eve_0, and set properties
  set axis_clock_converter_eve_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_eve_0 ]

  # Create instance: axis_clock_converter_eve_1, and set properties
  set axis_clock_converter_eve_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_eve_1 ]

  # Create instance: axis_clock_converter_cmd_0, and set properties
  set axis_clock_converter_cmd_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_cmd_0 ]

  # Create instance: axis_clock_converter_cmd_1, and set properties
  set axis_clock_converter_cmd_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_cmd_1 ]

  # Create instance: axi_interconnect_reg_base, and set properties
  set axi_interconnect_reg_base [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_reg_base ]
  set_property -dict [list \
    CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
    CONFIG.M00_HAS_REGSLICE {4} \
    CONFIG.M01_HAS_REGSLICE {4} \
    CONFIG.M02_HAS_REGSLICE {4} \
    CONFIG.M03_HAS_REGSLICE {4} \
    CONFIG.M04_HAS_REGSLICE {4} \
    CONFIG.M05_HAS_REGSLICE {4} \
    CONFIG.M06_HAS_REGSLICE {4} \
    CONFIG.NUM_MI {5} \
    CONFIG.S00_HAS_REGSLICE {4} \
  ] $axi_interconnect_reg_base


  # Create instance: axi_interconnect_reg_0, and set properties
  set axi_interconnect_reg_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_reg_0 ]
  set_property -dict [list \
    CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
    CONFIG.M00_HAS_REGSLICE {4} \
    CONFIG.M01_HAS_REGSLICE {4} \
    CONFIG.M02_HAS_REGSLICE {4} \
    CONFIG.M03_HAS_REGSLICE {4} \
    CONFIG.M04_HAS_REGSLICE {4} \
    CONFIG.M05_HAS_REGSLICE {4} \
    CONFIG.M06_HAS_REGSLICE {4} \
    CONFIG.NUM_MI {5} \
    CONFIG.S00_HAS_REGSLICE {4} \
  ] $axi_interconnect_reg_0


  # Create instance: axi_interconnect_reg_1, and set properties
  set axi_interconnect_reg_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_reg_1 ]
  set_property -dict [list \
    CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
    CONFIG.M00_HAS_REGSLICE {4} \
    CONFIG.M01_HAS_REGSLICE {4} \
    CONFIG.M02_HAS_REGSLICE {4} \
    CONFIG.M03_HAS_REGSLICE {4} \
    CONFIG.M04_HAS_REGSLICE {4} \
    CONFIG.M05_HAS_REGSLICE {4} \
    CONFIG.M06_HAS_REGSLICE {4} \
    CONFIG.M07_HAS_REGSLICE {4} \
    CONFIG.M08_HAS_REGSLICE {4} \
    CONFIG.M09_HAS_REGSLICE {4} \
    CONFIG.M10_HAS_REGSLICE {4} \
    CONFIG.M11_HAS_REGSLICE {4} \
    CONFIG.M12_HAS_REGSLICE {4} \
    CONFIG.M13_HAS_REGSLICE {4} \
    CONFIG.NUM_MI {8} \
    CONFIG.S00_HAS_REGSLICE {4} \
  ] $axi_interconnect_reg_1


  # Create instance: axi_interconnect_reg_2, and set properties
  set axi_interconnect_reg_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_reg_2 ]
  set_property -dict [list \
    CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
    CONFIG.M00_HAS_REGSLICE {4} \
    CONFIG.M01_HAS_REGSLICE {4} \
    CONFIG.M02_HAS_REGSLICE {4} \
    CONFIG.M03_HAS_REGSLICE {4} \
    CONFIG.M04_HAS_REGSLICE {4} \
    CONFIG.M05_HAS_REGSLICE {4} \
    CONFIG.M06_HAS_REGSLICE {4} \
    CONFIG.NUM_MI {5} \
    CONFIG.S00_HAS_REGSLICE {4} \
  ] $axi_interconnect_reg_2


  # Create instance: clk_wiz_ddr4_0, and set properties
  set clk_wiz_ddr4_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_ddr4_0 ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {33.330000000000005} \
    CONFIG.CLKOUT1_JITTER {101.475} \
    CONFIG.CLKOUT1_PHASE_ERROR {77.836} \
    CONFIG.CLK_IN1_BOARD_INTERFACE {Custom} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {4.000} \
    CONFIG.MMCM_CLKIN1_PERIOD {3.333} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
  ] $clk_wiz_ddr4_0


  # Create instance: clk_wiz_ddr4_1, and set properties
  set clk_wiz_ddr4_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_ddr4_1 ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {33.330000000000005} \
    CONFIG.CLKOUT1_JITTER {101.475} \
    CONFIG.CLKOUT1_PHASE_ERROR {77.836} \
    CONFIG.CLK_IN1_BOARD_INTERFACE {Custom} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {4.000} \
    CONFIG.MMCM_CLKIN1_PERIOD {3.333} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
  ] $clk_wiz_ddr4_1


  # Create instance: clk_wiz_ddr4_2, and set properties
  set clk_wiz_ddr4_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_ddr4_2 ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {33.330000000000005} \
    CONFIG.CLKOUT1_JITTER {101.475} \
    CONFIG.CLKOUT1_PHASE_ERROR {77.836} \
    CONFIG.CLK_IN1_BOARD_INTERFACE {Custom} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {4.000} \
    CONFIG.MMCM_CLKIN1_PERIOD {3.333} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
  ] $clk_wiz_ddr4_2


  # Create instance: clk_wiz_ddr4_3, and set properties
  set clk_wiz_ddr4_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_ddr4_3 ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {33.330000000000005} \
    CONFIG.CLKOUT1_JITTER {101.475} \
    CONFIG.CLKOUT1_PHASE_ERROR {77.836} \
    CONFIG.CLK_IN1_BOARD_INTERFACE {Custom} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {4.000} \
    CONFIG.MMCM_CLKIN1_PERIOD {3.333} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
  ] $clk_wiz_ddr4_3


  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]

  # Create instance: util_reduced_logic_0, and set properties
  set util_reduced_logic_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_reduced_logic:2.0 util_reduced_logic_0 ]
  set_property -dict [list \
    CONFIG.C_OPERATION {or} \
    CONFIG.C_SIZE {17} \
  ] $util_reduced_logic_0


  # Create instance: xlconcat_1, and set properties
  set xlconcat_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_1 ]
  set_property CONFIG.NUM_PORTS {17} $xlconcat_1


  # Create instance: xlconstant_1, and set properties
  set xlconstant_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_1 ]
  set_property -dict [list \
    CONFIG.CONST_VAL {0} \
    CONFIG.CONST_WIDTH {8} \
  ] $xlconstant_1


  # Create instance: chain_0
  create_hier_cell_chain_0 [current_bd_instance .] chain_0

  # Create instance: chain_1
  create_hier_cell_chain_1 [current_bd_instance .] chain_1

  # Create instance: function_0
  create_hier_cell_function_0 [current_bd_instance .] function_0

  # Create instance: function_1
  create_hier_cell_function_1 [current_bd_instance .] function_1

  # Create instance: proc_sys_reset_250, and set properties
  set proc_sys_reset_250 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_250 ]
  set_property CONFIG.C_AUX_RESET_HIGH {0} $proc_sys_reset_250


  # Create instance: util_vector_logic_6, and set properties
  set util_vector_logic_6 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_6 ]
  set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
  ] $util_vector_logic_6


  # Create instance: xlconstant_2, and set properties
  set xlconstant_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_2 ]
  set_property -dict [list \
    CONFIG.CONST_VAL {0} \
    CONFIG.CONST_WIDTH {512} \
  ] $xlconstant_2


  # Create instance: xlconstant_3, and set properties
  set xlconstant_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_3 ]
  set_property CONFIG.CONST_VAL {0} $xlconstant_3


  # Create instance: proc_sys_reset_filter0, and set properties
  set proc_sys_reset_filter0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_filter0 ]
  set_property CONFIG.C_AUX_RESET_HIGH {0} $proc_sys_reset_filter0


  # Create instance: proc_sys_reset_filter1, and set properties
  set proc_sys_reset_filter1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_filter1 ]
  set_property CONFIG.C_AUX_RESET_HIGH {0} $proc_sys_reset_filter1


  # Create instance: proc_sys_reset_conv1, and set properties
  set proc_sys_reset_conv1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_conv1 ]
  set_property CONFIG.C_AUX_RESET_HIGH {0} $proc_sys_reset_conv1


  # Create instance: proc_sys_reset_conv0, and set properties
  set proc_sys_reset_conv0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_conv0 ]
  set_property CONFIG.C_AUX_RESET_HIGH {0} $proc_sys_reset_conv0


  # Create instance: util_vector_logic_7, and set properties
  set util_vector_logic_7 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_7 ]
  set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
  ] $util_vector_logic_7


  # Create instance: xlconcat_2, and set properties
  set xlconcat_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_2 ]
  set_property -dict [list \
    CONFIG.IN0_WIDTH {9} \
    CONFIG.IN1_WIDTH {9} \
    CONFIG.NUM_PORTS {2} \
  ] $xlconcat_2


  # Create instance: indirect_reg_access_0, and set properties
  set block_name indirect_reg_access
  set block_cell_name indirect_reg_access_0
  if { [catch {set indirect_reg_access_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $indirect_reg_access_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property CONFIG.IN_ADDR_WIDTH {12} $indirect_reg_access_0


  # Create instance: pci_mon_wire_0, and set properties
  set block_name pci_mon_wire
  set block_cell_name pci_mon_wire_0
  if { [catch {set pci_mon_wire_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $pci_mon_wire_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: fpga_reg_0, and set properties
  set block_name fpga_reg
  set block_cell_name fpga_reg_0
  if { [catch {set fpga_reg_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $fpga_reg_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property -dict [list \
    CONFIG.MAJOR_VERSION {0x0100001C} \
    CONFIG.MINOR_VERSION {0x24091201} \
  ] $fpga_reg_0


  # Create instance: axis2axi_bridge_0, and set properties
  set block_name axis2axi_bridge
  set block_cell_name axis2axi_bridge_0
  if { [catch {set axis2axi_bridge_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $axis2axi_bridge_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property -dict [list \
    CONFIG.ADDR_WIDTH {37} \
    CONFIG.MUSK_ADDR_WIDTH {21} \
  ] $axis2axi_bridge_0


  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /axis2axi_bridge_0/m_axi]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /axis2axi_bridge_0/m_axis_cc]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.CLK_DOMAIN {design_1_pcie4_uscale_plus_0_0_user_clk} \
 ] [get_bd_intf_pins /axis2axi_bridge_0/m_axis_direct]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /axis2axi_bridge_0/s_axis_cq]

  # Create instance: lldma_wrapper_0, and set properties
  set block_name lldma_wrapper
  set block_cell_name lldma_wrapper_0
  if { [catch {set lldma_wrapper_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $lldma_wrapper_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property -dict [list \
    CONFIG.CH_NUM_LOG {4} \
  ] $lldma_wrapper_0


  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/m_axi_cd_0]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/m_axi_cd_1]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/m_axi_cd_2]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/m_axi_cd_3]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/m_axi_cu_0]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/m_axi_cu_1]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/m_axi_cu_2]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/m_axi_cu_3]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/m_axis_rq]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/m_axis_transfer_eve_0]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/m_axis_transfer_eve_1]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/m_axis_transfer_eve_2]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/m_axis_transfer_eve_3]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/s_axi]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.CLK_DOMAIN {design_1_pcie4_uscale_plus_0_0_user_clk} \
 ] [get_bd_intf_pins /lldma_wrapper_0/s_axis_direct]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/s_axis_rc]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/s_axis_transfer_cmd_0]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/s_axis_transfer_cmd_1]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/s_axis_transfer_cmd_2]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /lldma_wrapper_0/s_axis_transfer_cmd_3]

  # Create interface connections
  connect_bd_intf_net -intf_net CLK_IN_D_1 [get_bd_intf_ports sys_clk] [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]
  connect_bd_intf_net -intf_net S02_AXI_1 [get_bd_intf_pins axi_interconnect_lldma_ddr_1/S02_AXI] [get_bd_intf_pins lldma_wrapper_0/m_axi_cu_2]
  connect_bd_intf_net -intf_net axi_interconnect_4_M00_AXI [get_bd_intf_pins axi_interconnect_4/M00_AXI] [get_bd_intf_pins axi_interconnect_ddr0/S00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_4_M01_AXI [get_bd_intf_pins axi_interconnect_4/M01_AXI] [get_bd_intf_pins axi_interconnect_ddr1/S00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_4_M02_AXI [get_bd_intf_pins axi_interconnect_4/M02_AXI] [get_bd_intf_pins axi_interconnect_ddr2/S00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_4_M03_AXI [get_bd_intf_pins axi_interconnect_4/M03_AXI] [get_bd_intf_pins axi_interconnect_ddr3/S00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_ddr0_M00_AXI [get_bd_intf_pins axi_interconnect_ddr0/M00_AXI] [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_ddr1_M00_AXI [get_bd_intf_pins axi_interconnect_ddr1/M00_AXI] [get_bd_intf_pins ddr4_1/C0_DDR4_S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_ddr2_M00_AXI [get_bd_intf_pins axi_interconnect_ddr2/M00_AXI] [get_bd_intf_pins ddr4_2/C0_DDR4_S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_ddr3_M00_AXI [get_bd_intf_pins ddr4_3/C0_DDR4_S_AXI] [get_bd_intf_pins axi_interconnect_ddr3/M00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_lldma_ddr_0_M00_AXI [get_bd_intf_pins axi_interconnect_lldma_ddr_0/M00_AXI] [get_bd_intf_pins axi_interconnect_ddr0/S05_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_lldma_ddr_1_M00_AXI [get_bd_intf_pins axi_interconnect_lldma_ddr_1/M00_AXI] [get_bd_intf_pins axi_interconnect_ddr0/S06_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_reg_0_M00_AXI [get_bd_intf_pins axi_interconnect_reg_0/M00_AXI] [get_bd_intf_pins fpga_reg_0/interface_aximm]
  connect_bd_intf_net -intf_net axi_interconnect_reg_0_M01_AXI [get_bd_intf_pins axi_interconnect_reg_0/M01_AXI] [get_bd_intf_pins chain_0/s_axi_control_chain]
  connect_bd_intf_net -intf_net axi_interconnect_reg_0_M03_AXI [get_bd_intf_pins axi_interconnect_reg_0/M03_AXI] [get_bd_intf_pins chain_0/s_axi_control_direct]
  connect_bd_intf_net -intf_net axi_interconnect_reg_0_M04_AXI [get_bd_intf_pins axi_interconnect_reg_0/M04_AXI] [get_bd_intf_pins chain_1/s_axi_control_direct]
  connect_bd_intf_net -intf_net axi_interconnect_reg_1_M04_AXI [get_bd_intf_pins axi_interconnect_reg_1/M04_AXI] [get_bd_intf_pins function_0/s_axi_control_conv]
  connect_bd_intf_net -intf_net axi_interconnect_reg_1_M05_AXI [get_bd_intf_pins axi_interconnect_reg_1/M05_AXI] [get_bd_intf_pins function_1/s_axi_control_conv]
  connect_bd_intf_net -intf_net axi_interconnect_reg_1_M06_AXI [get_bd_intf_pins axi_interconnect_reg_1/M06_AXI] [get_bd_intf_pins function_0/s_axi_control_func]
  connect_bd_intf_net -intf_net axi_interconnect_reg_1_M07_AXI [get_bd_intf_pins axi_interconnect_reg_1/M07_AXI] [get_bd_intf_pins function_1/s_axi_control_func]
  connect_bd_intf_net -intf_net axi_interconnect_reg_2_M00_AXI [get_bd_intf_pins indirect_reg_access_0/s_axi] [get_bd_intf_pins axi_interconnect_reg_2/M00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_reg_2_M01_AXI [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI_CTRL] [get_bd_intf_pins axi_interconnect_reg_2/M01_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_reg_2_M02_AXI [get_bd_intf_pins ddr4_1/C0_DDR4_S_AXI_CTRL] [get_bd_intf_pins axi_interconnect_reg_2/M02_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_reg_2_M03_AXI [get_bd_intf_pins ddr4_2/C0_DDR4_S_AXI_CTRL] [get_bd_intf_pins axi_interconnect_reg_2/M03_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_reg_2_M04_AXI [get_bd_intf_pins ddr4_3/C0_DDR4_S_AXI_CTRL] [get_bd_intf_pins axi_interconnect_reg_2/M04_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_reg_base_M00_AXI [get_bd_intf_pins axi_interconnect_reg_base/M00_AXI] [get_bd_intf_pins axi_interconnect_reg_0/S00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_reg_base_M01_AXI [get_bd_intf_pins axi_interconnect_reg_base/M01_AXI] [get_bd_intf_pins lldma_wrapper_0/s_axi]
  connect_bd_intf_net -intf_net axi_interconnect_reg_base_M02_AXI [get_bd_intf_pins axi_interconnect_reg_base/M02_AXI] [get_bd_intf_pins axi_interconnect_reg_1/S00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_reg_base_M03_AXI [get_bd_intf_pins axi_interconnect_reg_base/M03_AXI] [get_bd_intf_pins axi_interconnect_reg_2/S00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_reg_base_M04_AXI [get_bd_intf_pins axi_interconnect_reg_base/M04_AXI] [get_bd_intf_pins cms_subsystem_0/s_axi_ctrl]
  connect_bd_intf_net -intf_net axi_register_slice_0_M_AXI [get_bd_intf_pins axi_register_slice_0/M_AXI] [get_bd_intf_pins axi_interconnect_reg_base/S00_AXI]
  connect_bd_intf_net -intf_net axis2axi_bridge_0_m_axi [get_bd_intf_pins axi_register_slice_0/S_AXI] [get_bd_intf_pins axis2axi_bridge_0/m_axi]
  connect_bd_intf_net -intf_net axis2axi_bridge_0_m_axis_cc [get_bd_intf_pins axis2axi_bridge_0/m_axis_cc] [get_bd_intf_pins pci_mon_wire_0/s_axis_cc_user]
  connect_bd_intf_net -intf_net axis2axi_bridge_0_m_axis_direct [get_bd_intf_pins lldma_wrapper_0/s_axis_direct] [get_bd_intf_pins axis2axi_bridge_0/m_axis_direct]
  connect_bd_intf_net -intf_net axis_clock_converter_0_M_AXIS [get_bd_intf_pins axis_clock_converter_eve_0/M_AXIS] [get_bd_intf_pins chain_0/s_axis_extif0_evt]
  connect_bd_intf_net -intf_net axis_clock_converter_cmd_0_M_AXIS [get_bd_intf_pins axis_clock_converter_cmd_0/M_AXIS] [get_bd_intf_pins lldma_wrapper_0/s_axis_transfer_cmd_0]
  connect_bd_intf_net -intf_net axis_clock_converter_cmd_1_M_AXIS [get_bd_intf_pins lldma_wrapper_0/s_axis_transfer_cmd_1] [get_bd_intf_pins axis_clock_converter_cmd_1/M_AXIS]
  connect_bd_intf_net -intf_net axis_clock_converter_eve_1_M_AXIS [get_bd_intf_pins axis_clock_converter_eve_1/M_AXIS] [get_bd_intf_pins chain_1/s_axis_extif0_evt]
  connect_bd_intf_net -intf_net axis_register_slice_16_M_AXIS [get_bd_intf_pins lldma_wrapper_0/s_axis_rc] [get_bd_intf_pins axis_register_slice_16/M_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_17_M_AXIS [get_bd_intf_pins axis_register_slice_17/M_AXIS] [get_bd_intf_pins pci_mon_wire_0/s_axis_rq_user]
  connect_bd_intf_net -intf_net chain_m_axis_egr_rx_resp_0 [get_bd_intf_pins chain_1/m_axis_egr_resp] [get_bd_intf_pins function_1/s_axis_egr_resp]
  connect_bd_intf_net -intf_net chain_m_axis_egr_rx_resp_3 [get_bd_intf_pins chain_0/m_axis_egr_resp] [get_bd_intf_pins function_0/s_axis_egr_resp]
  connect_bd_intf_net -intf_net chain_m_axis_ingr_tx_data_0 [get_bd_intf_pins chain_1/m_axis_ingr_data] [get_bd_intf_pins function_1/s_axis_ingr_data]
  connect_bd_intf_net -intf_net chain_m_axis_ingr_tx_data_3 [get_bd_intf_pins chain_0/m_axis_ingr_data] [get_bd_intf_pins function_0/s_axis_ingr_data]
  connect_bd_intf_net -intf_net chain_m_axis_ingr_tx_req_0 [get_bd_intf_pins chain_1/m_axis_ingr_req] [get_bd_intf_pins function_1/s_axis_ingr_req]
  connect_bd_intf_net -intf_net chain_m_axis_ingr_tx_req_3 [get_bd_intf_pins chain_0/m_axis_ingr_req] [get_bd_intf_pins function_0/s_axis_ingr_req]
  connect_bd_intf_net -intf_net cms_subsystem_0_satellite_uart [get_bd_intf_ports satellite_uart] [get_bd_intf_pins cms_subsystem_0/satellite_uart]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_ports ddr4_sdram_c0] [get_bd_intf_pins ddr4_0/C0_DDR4]
  connect_bd_intf_net -intf_net ddr4_1_C0_DDR4 [get_bd_intf_ports ddr4_sdram_c1] [get_bd_intf_pins ddr4_1/C0_DDR4]
  connect_bd_intf_net -intf_net ddr4_2_C0_DDR4 [get_bd_intf_ports ddr4_sdram_c2] [get_bd_intf_pins ddr4_2/C0_DDR4]
  connect_bd_intf_net -intf_net ddr4_3_C0_DDR4 [get_bd_intf_ports ddr4_sdram_c3] [get_bd_intf_pins ddr4_3/C0_DDR4]
  connect_bd_intf_net -intf_net default_300mhz_clk0_1 [get_bd_intf_ports default_300mhz_clk0] [get_bd_intf_pins ddr4_0/C0_SYS_CLK]
  connect_bd_intf_net -intf_net default_300mhz_clk1_1 [get_bd_intf_ports default_300mhz_clk1] [get_bd_intf_pins ddr4_1/C0_SYS_CLK]
  connect_bd_intf_net -intf_net default_300mhz_clk2_1 [get_bd_intf_ports default_300mhz_clk2] [get_bd_intf_pins ddr4_2/C0_SYS_CLK]
  connect_bd_intf_net -intf_net default_300mhz_clk3_1 [get_bd_intf_ports default_300mhz_clk3] [get_bd_intf_pins ddr4_3/C0_SYS_CLK]
  connect_bd_intf_net -intf_net lldma_wrapper_0_m_axi_cd_0 [get_bd_intf_pins axi_interconnect_lldma_ddr_0/S00_AXI] [get_bd_intf_pins lldma_wrapper_0/m_axi_cd_0]
  connect_bd_intf_net -intf_net lldma_wrapper_0_m_axi_cd_1 [get_bd_intf_pins axi_interconnect_lldma_ddr_0/S01_AXI] [get_bd_intf_pins lldma_wrapper_0/m_axi_cd_1]
  connect_bd_intf_net -intf_net lldma_wrapper_0_m_axi_cd_2 [get_bd_intf_pins axi_interconnect_lldma_ddr_1/S00_AXI] [get_bd_intf_pins lldma_wrapper_0/m_axi_cd_2]
  connect_bd_intf_net -intf_net lldma_wrapper_0_m_axi_cd_3 [get_bd_intf_pins axi_interconnect_lldma_ddr_1/S01_AXI] [get_bd_intf_pins lldma_wrapper_0/m_axi_cd_3]
  connect_bd_intf_net -intf_net lldma_wrapper_0_m_axi_cu_0 [get_bd_intf_pins axi_interconnect_lldma_ddr_0/S02_AXI] [get_bd_intf_pins lldma_wrapper_0/m_axi_cu_0]
  connect_bd_intf_net -intf_net lldma_wrapper_0_m_axi_cu_1 [get_bd_intf_pins axi_interconnect_lldma_ddr_0/S03_AXI] [get_bd_intf_pins lldma_wrapper_0/m_axi_cu_1]
  connect_bd_intf_net -intf_net lldma_wrapper_0_m_axi_cu_3 [get_bd_intf_pins axi_interconnect_lldma_ddr_1/S03_AXI] [get_bd_intf_pins lldma_wrapper_0/m_axi_cu_3]
  connect_bd_intf_net -intf_net lldma_wrapper_0_m_axis_rq [get_bd_intf_pins lldma_wrapper_0/m_axis_rq] [get_bd_intf_pins axis_register_slice_17/S_AXIS]
  connect_bd_intf_net -intf_net lldma_wrapper_0_m_axis_transfer_eve_0 [get_bd_intf_pins axis_clock_converter_eve_0/S_AXIS] [get_bd_intf_pins lldma_wrapper_0/m_axis_transfer_eve_0]
  connect_bd_intf_net -intf_net lldma_wrapper_0_m_axis_transfer_eve_1 [get_bd_intf_pins lldma_wrapper_0/m_axis_transfer_eve_1] [get_bd_intf_pins axis_clock_converter_eve_1/S_AXIS]
  connect_bd_intf_net -intf_net function_block_m_axis_egr_rx_data_0 [get_bd_intf_pins function_1/m_axis_egr_data] [get_bd_intf_pins chain_1/s_axis_egr_data]
  connect_bd_intf_net -intf_net function_block_m_axis_egr_rx_data_3 [get_bd_intf_pins function_0/m_axis_egr_data] [get_bd_intf_pins chain_0/s_axis_egr_data]
  connect_bd_intf_net -intf_net function_block_m_axis_egr_rx_req_0 [get_bd_intf_pins function_1/m_axis_egr_req] [get_bd_intf_pins chain_1/s_axis_egr_req]
  connect_bd_intf_net -intf_net function_block_m_axis_egr_rx_req_3 [get_bd_intf_pins function_0/m_axis_egr_req] [get_bd_intf_pins chain_0/s_axis_egr_req]
  connect_bd_intf_net -intf_net function_block_m_axis_ingr_tx_resp_0 [get_bd_intf_pins function_1/m_axis_ingr_resp] [get_bd_intf_pins chain_1/s_axis_ingr_resp]
  connect_bd_intf_net -intf_net function_block_m_axis_ingr_tx_resp_3 [get_bd_intf_pins function_0/m_axis_ingr_resp] [get_bd_intf_pins chain_0/s_axis_ingr_resp]
  connect_bd_intf_net -intf_net indirect_reg_access_0_m_axi [get_bd_intf_pins axi_interconnect_4/S00_AXI] [get_bd_intf_pins indirect_reg_access_0/m_axi]
  connect_bd_intf_net -intf_net nw_chain_func_m_axi_extif0_buffer_rd_0_0 [get_bd_intf_pins chain_0/m_axi_extif0_rd] [get_bd_intf_pins axi_interconnect_ddr0/S01_AXI]
  connect_bd_intf_net -intf_net nw_chain_func_m_axi_extif0_buffer_rd_0_0_0 [get_bd_intf_pins chain_1/m_axi_extif0_rd] [get_bd_intf_pins axi_interconnect_ddr0/S03_AXI]
  connect_bd_intf_net -intf_net nw_chain_func_m_axi_extif0_buffer_wr_0_0 [get_bd_intf_pins chain_0/m_axi_extif0_wr] [get_bd_intf_pins axi_interconnect_ddr0/S02_AXI]
  connect_bd_intf_net -intf_net nw_chain_func_m_axi_extif0_buffer_wr_0_0_0 [get_bd_intf_pins chain_1/m_axi_extif0_wr] [get_bd_intf_pins axi_interconnect_ddr0/S04_AXI]
  connect_bd_intf_net -intf_net nw_chain_func_m_axi_extif1_buffer_rd_0_0 [get_bd_intf_pins chain_0/m_axi_extif1_rd] [get_bd_intf_pins axi_interconnect_ddr2/S01_AXI]
  connect_bd_intf_net -intf_net nw_chain_func_m_axi_extif1_buffer_rd_0_0_0 [get_bd_intf_pins chain_1/m_axi_extif1_rd] [get_bd_intf_pins axi_interconnect_ddr2/S03_AXI]
  connect_bd_intf_net -intf_net nw_chain_func_m_axi_extif1_buffer_wr_0_0 [get_bd_intf_pins chain_0/m_axi_extif1_wr] [get_bd_intf_pins axi_interconnect_ddr2/S02_AXI]
  connect_bd_intf_net -intf_net nw_chain_func_m_axi_extif1_buffer_wr_0_0_0 [get_bd_intf_pins chain_1/m_axi_extif1_wr] [get_bd_intf_pins axi_interconnect_ddr2/S04_AXI]
  connect_bd_intf_net -intf_net nw_chain_func_m_axi_ingr_frame_buffer_0_0 [get_bd_intf_pins function_0/m_axi_conv] [get_bd_intf_pins axi_interconnect_ddr1/S01_AXI]
  connect_bd_intf_net -intf_net nw_chain_func_m_axi_ingr_frame_buffer_0_0_0 [get_bd_intf_pins function_1/m_axi_conv] [get_bd_intf_pins axi_interconnect_ddr1/S02_AXI]
  connect_bd_intf_net -intf_net nw_chain_func_m_axis_extif0_cmd_0_0 [get_bd_intf_pins chain_0/m_axis_extif0_cmd] [get_bd_intf_pins axis_clock_converter_cmd_0/S_AXIS]
  connect_bd_intf_net -intf_net nw_chain_func_m_axis_extif0_cmd_0_0_0 [get_bd_intf_pins axis_clock_converter_cmd_1/S_AXIS] [get_bd_intf_pins chain_1/m_axis_extif0_cmd]
  connect_bd_intf_net -intf_net pci_mon_wire_0_m_axis_cc_mon [get_bd_intf_pins pci_mon_wire_0/m_axis_cc_mon] [get_bd_intf_pins indirect_reg_access_0/s_axis_ing_cmp_mon]
  connect_bd_intf_net -intf_net pci_mon_wire_0_m_axis_cc_pci [get_bd_intf_pins pcie4_uscale_plus_0/s_axis_cc] [get_bd_intf_pins pci_mon_wire_0/m_axis_cc_pci]
  connect_bd_intf_net -intf_net pci_mon_wire_0_m_axis_cq_mon [get_bd_intf_pins pci_mon_wire_0/m_axis_cq_mon] [get_bd_intf_pins indirect_reg_access_0/m_axis_ing_req_mon]
  connect_bd_intf_net -intf_net pci_mon_wire_0_m_axis_cq_user [get_bd_intf_pins pci_mon_wire_0/m_axis_cq_user] [get_bd_intf_pins axis2axi_bridge_0/s_axis_cq]
  connect_bd_intf_net -intf_net pci_mon_wire_0_m_axis_rc_mon [get_bd_intf_pins pci_mon_wire_0/m_axis_rc_mon] [get_bd_intf_pins indirect_reg_access_0/s_axis_egr_cmp_mon]
  connect_bd_intf_net -intf_net pci_mon_wire_0_m_axis_rc_user [get_bd_intf_pins axis_register_slice_16/S_AXIS] [get_bd_intf_pins pci_mon_wire_0/m_axis_rc_user]
  connect_bd_intf_net -intf_net pci_mon_wire_0_m_axis_rq_mon [get_bd_intf_pins pci_mon_wire_0/m_axis_rq_mon] [get_bd_intf_pins indirect_reg_access_0/m_axis_egr_req_mon]
  connect_bd_intf_net -intf_net pci_mon_wire_0_m_axis_rq_pci [get_bd_intf_pins pci_mon_wire_0/m_axis_rq_pci] [get_bd_intf_pins pcie4_uscale_plus_0/s_axis_rq]
  connect_bd_intf_net -intf_net pcie4_uscale_plus_0_m_axis_cq [get_bd_intf_pins pcie4_uscale_plus_0/m_axis_cq] [get_bd_intf_pins pci_mon_wire_0/s_axis_cq_pci]
  connect_bd_intf_net -intf_net pcie4_uscale_plus_0_m_axis_rc [get_bd_intf_pins pcie4_uscale_plus_0/m_axis_rc] [get_bd_intf_pins pci_mon_wire_0/s_axis_rc_pci]
  connect_bd_intf_net -intf_net pcie4_uscale_plus_0_pcie4_mgt [get_bd_intf_ports pcie4_mgt] [get_bd_intf_pins pcie4_uscale_plus_0/pcie4_mgt]
  connect_bd_intf_net -intf_net s_axi_control_1_0_0_1 [get_bd_intf_pins chain_1/s_axi_control_chain] [get_bd_intf_pins axi_interconnect_reg_0/M02_AXI]

  # Create port connections
  connect_bd_net -net M00_ACLK_1 [get_bd_pins ddr4_3/c0_ddr4_ui_clk] [get_bd_pins axi_interconnect_ddr3/M00_ACLK] [get_bd_pins axi_interconnect_reg_2/M04_ACLK] [get_bd_pins clk_wiz_ddr4_3/clk_in1]
  connect_bd_net -net M00_ARESETN_1 [get_bd_pins util_vector_logic_2/Res] [get_bd_pins axi_interconnect_ddr1/M00_ARESETN] [get_bd_pins ddr4_1/c0_ddr4_aresetn] [get_bd_pins axi_interconnect_reg_2/M02_ARESETN]
  connect_bd_net -net M00_ARESETN_2 [get_bd_pins util_vector_logic_1/Res] [get_bd_pins axi_interconnect_ddr0/M00_ARESETN] [get_bd_pins ddr4_0/c0_ddr4_aresetn] [get_bd_pins axi_interconnect_reg_2/M01_ARESETN]
  connect_bd_net -net axi_gpio_0_gpio_io_o [get_bd_pins axi_gpio_0/gpio_io_o] [get_bd_pins axi_gpio_0/gpio_io_i]
  connect_bd_net -net axis2axi_bridge_0_m_d2d_ack_valid [get_bd_pins axis2axi_bridge_0/m_d2d_ack_valid] [get_bd_pins lldma_wrapper_0/s_d2d_ack_valid]
  connect_bd_net -net axis2axi_bridge_0_m_d2d_data [get_bd_pins axis2axi_bridge_0/m_d2d_data] [get_bd_pins lldma_wrapper_0/s_d2d_data]
  connect_bd_net -net axis2axi_bridge_0_m_d2d_req_valid [get_bd_pins axis2axi_bridge_0/m_d2d_req_valid] [get_bd_pins lldma_wrapper_0/s_d2d_req_valid]
  connect_bd_net -net c_shift_ram_0_Q [get_bd_pins c_shift_ram_0/Q] [get_bd_pins lldma_wrapper_0/user_reset]
  connect_bd_net -net clk_wiz_0_clk_out1 [get_bd_pins ss_ucs/clk_out1] [get_bd_pins axi_interconnect_4/M00_ACLK] [get_bd_pins axi_interconnect_4/M01_ACLK] [get_bd_pins axi_interconnect_4/M02_ACLK] [get_bd_pins axi_interconnect_4/M03_ACLK] [get_bd_pins axi_interconnect_ddr0/S00_ACLK] [get_bd_pins axi_interconnect_ddr2/S00_ACLK] [get_bd_pins axi_interconnect_ddr3/ACLK] [get_bd_pins axi_interconnect_ddr3/S00_ACLK] [get_bd_pins axi_interconnect_ddr1/S00_ACLK]
  connect_bd_net -net clk_wiz_250_2_100_clk_out_pcie50 [get_bd_pins clk_wiz_250_2_100/clk_out_pcie50] [get_bd_pins ss_ucs/slowest_sync_clk] [get_bd_pins axi_gpio_0/s_axi_aclk] [get_bd_pins proc_sys_reset_50/slowest_sync_clk]
  connect_bd_net -net clk_wiz_250_2_100_clk_out_pcie100 [get_bd_pins clk_wiz_250_2_100/clk_out_pcie100] [get_bd_pins proc_sys_reset_100/slowest_sync_clk]
  connect_bd_net -net clk_wiz_250_2_100_clk_out_pcie150 [get_bd_pins clk_wiz_250_2_100/clk_out_pcie150] [get_bd_pins proc_sys_reset_150/slowest_sync_clk]
  connect_bd_net -net clk_wiz_250_2_100_clk_out_pcie200 [get_bd_pins clk_wiz_250_2_100/clk_out_pcie200] [get_bd_pins axi_interconnect_ddr0/S01_ACLK] [get_bd_pins axi_interconnect_ddr0/S02_ACLK] [get_bd_pins axi_interconnect_ddr0/S03_ACLK] [get_bd_pins axi_interconnect_ddr0/S04_ACLK] [get_bd_pins axi_interconnect_ddr0/S07_ACLK] [get_bd_pins axi_interconnect_ddr0/S08_ACLK] [get_bd_pins axi_interconnect_ddr0/S09_ACLK] [get_bd_pins axi_interconnect_ddr0/S10_ACLK] [get_bd_pins axi_interconnect_ddr2/ACLK] [get_bd_pins axi_interconnect_ddr2/S01_ACLK] [get_bd_pins axi_interconnect_ddr2/S02_ACLK] [get_bd_pins axi_interconnect_ddr2/S03_ACLK] [get_bd_pins axi_interconnect_ddr2/S04_ACLK] [get_bd_pins axi_interconnect_ddr2/S05_ACLK] [get_bd_pins axi_interconnect_ddr2/S06_ACLK] [get_bd_pins axi_interconnect_ddr3/S01_ACLK] [get_bd_pins axi_interconnect_ddr3/S02_ACLK] [get_bd_pins axi_interconnect_ddr3/S03_ACLK] [get_bd_pins axi_interconnect_ddr3/S04_ACLK] [get_bd_pins axi_interconnect_ddr3/S05_ACLK] [get_bd_pins axi_interconnect_ddr3/S06_ACLK] [get_bd_pins axi_interconnect_ddr1/ACLK] [get_bd_pins axi_interconnect_ddr1/S01_ACLK] [get_bd_pins axi_interconnect_ddr1/S02_ACLK] [get_bd_pins axi_interconnect_ddr1/S03_ACLK] [get_bd_pins axi_interconnect_ddr1/S04_ACLK] [get_bd_pins proc_sys_reset_200/slowest_sync_clk] [get_bd_pins axis_clock_converter_eve_0/m_axis_aclk] [get_bd_pins axis_clock_converter_eve_1/m_axis_aclk] [get_bd_pins axis_clock_converter_cmd_1/s_axis_aclk] [get_bd_pins axis_clock_converter_cmd_0/s_axis_aclk] [get_bd_pins axi_interconnect_reg_0/M01_ACLK] [get_bd_pins axi_interconnect_reg_0/M02_ACLK] [get_bd_pins axi_interconnect_reg_0/M03_ACLK] [get_bd_pins axi_interconnect_reg_0/M04_ACLK] [get_bd_pins axi_interconnect_reg_1/M00_ACLK] [get_bd_pins axi_interconnect_reg_1/M01_ACLK] [get_bd_pins axi_interconnect_reg_1/M02_ACLK] [get_bd_pins axi_interconnect_reg_1/M03_ACLK] [get_bd_pins axi_interconnect_reg_1/M04_ACLK] [get_bd_pins axi_interconnect_reg_1/M05_ACLK] [get_bd_pins axi_interconnect_reg_1/M06_ACLK] [get_bd_pins axi_interconnect_reg_1/M07_ACLK] [get_bd_pins chain_1/aclk_mm] [get_bd_pins function_1/aclk_mm] [get_bd_pins function_0/aclk_mm] [get_bd_pins chain_0/aclk_mm] [get_bd_pins proc_sys_reset_filter0/slowest_sync_clk] [get_bd_pins proc_sys_reset_filter1/slowest_sync_clk] [get_bd_pins proc_sys_reset_conv0/slowest_sync_clk] [get_bd_pins proc_sys_reset_conv1/slowest_sync_clk] [get_bd_pins lldma_wrapper_0/ext_clk] [get_bd_pins axi_interconnect_ddr0/ACLK]
  connect_bd_net -net clk_wiz_250_2_100_clk_out_pcie300 [get_bd_pins clk_wiz_250_2_100/clk_out_pcie300] [get_bd_pins proc_sys_reset_300/slowest_sync_clk]
  connect_bd_net -net clk_wiz_250_2_100_locked [get_bd_pins clk_wiz_250_2_100/locked] [get_bd_pins ss_ucs/dcm_locked] [get_bd_pins proc_sys_reset_100/dcm_locked] [get_bd_pins proc_sys_reset_150/dcm_locked] [get_bd_pins proc_sys_reset_200/dcm_locked] [get_bd_pins proc_sys_reset_300/dcm_locked] [get_bd_pins proc_sys_reset_50/dcm_locked] [get_bd_pins proc_sys_reset_250/dcm_locked] [get_bd_pins proc_sys_reset_filter0/dcm_locked] [get_bd_pins proc_sys_reset_filter1/dcm_locked] [get_bd_pins proc_sys_reset_conv0/dcm_locked] [get_bd_pins proc_sys_reset_conv1/dcm_locked] [get_bd_pins fpga_reg_0/locked_user_clk]
  connect_bd_net -net clk_wiz_ddr4_0_locked [get_bd_pins clk_wiz_ddr4_0/locked] [get_bd_pins fpga_reg_0/locked_ddr4_clk0]
  connect_bd_net -net clk_wiz_ddr4_1_locked [get_bd_pins clk_wiz_ddr4_1/locked] [get_bd_pins fpga_reg_0/locked_ddr4_clk1]
  connect_bd_net -net clk_wiz_ddr4_2_locked [get_bd_pins clk_wiz_ddr4_2/locked] [get_bd_pins fpga_reg_0/locked_ddr4_clk2]
  connect_bd_net -net clk_wiz_ddr4_3_locked [get_bd_pins clk_wiz_ddr4_3/locked] [get_bd_pins fpga_reg_0/locked_ddr4_clk3]
  connect_bd_net -net cms_subsystem_0_qsfp0_lpmode [get_bd_pins cms_subsystem_0/qsfp0_lpmode] [get_bd_ports qsfp0_lpmode_0]
  connect_bd_net -net cms_subsystem_0_qsfp0_modsel_l [get_bd_pins cms_subsystem_0/qsfp0_modsel_l] [get_bd_ports qsfp0_modsel_l_0]
  connect_bd_net -net cms_subsystem_0_qsfp0_reset_l [get_bd_pins cms_subsystem_0/qsfp0_reset_l] [get_bd_ports qsfp0_reset_l_0]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk [get_bd_pins ddr4_0/c0_ddr4_ui_clk] [get_bd_pins axi_interconnect_ddr0/M00_ACLK] [get_bd_pins axi_interconnect_reg_2/M01_ACLK] [get_bd_pins clk_wiz_ddr4_0/clk_in1]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk_sync_rst [get_bd_pins ddr4_0/c0_ddr4_ui_clk_sync_rst] [get_bd_pins util_vector_logic_1/Op1] [get_bd_pins clk_wiz_ddr4_0/reset]
  connect_bd_net -net ddr4_1_c0_ddr4_ui_clk [get_bd_pins ddr4_1/c0_ddr4_ui_clk] [get_bd_pins axi_interconnect_ddr1/M00_ACLK] [get_bd_pins axi_interconnect_reg_2/M02_ACLK] [get_bd_pins clk_wiz_ddr4_1/clk_in1]
  connect_bd_net -net ddr4_1_c0_ddr4_ui_clk_sync_rst [get_bd_pins ddr4_1/c0_ddr4_ui_clk_sync_rst] [get_bd_pins util_vector_logic_2/Op1] [get_bd_pins clk_wiz_ddr4_1/reset]
  connect_bd_net -net ddr4_2_c0_ddr4_ui_clk [get_bd_pins ddr4_2/c0_ddr4_ui_clk] [get_bd_pins axi_interconnect_ddr2/M00_ACLK] [get_bd_pins axi_interconnect_reg_2/M03_ACLK] [get_bd_pins clk_wiz_ddr4_2/clk_in1]
  connect_bd_net -net ddr4_2_c0_ddr4_ui_clk_sync_rst [get_bd_pins util_vector_logic_3/Res] [get_bd_pins axi_interconnect_ddr2/M00_ARESETN] [get_bd_pins ddr4_2/c0_ddr4_aresetn] [get_bd_pins axi_interconnect_reg_2/M03_ARESETN]
  connect_bd_net -net ddr4_2_c0_ddr4_ui_clk_sync_rst1 [get_bd_pins ddr4_2/c0_ddr4_ui_clk_sync_rst] [get_bd_pins util_vector_logic_3/Op1] [get_bd_pins clk_wiz_ddr4_2/reset]
  connect_bd_net -net ddr4_3_c0_ddr4_ui_clk_sync_rst [get_bd_pins ddr4_3/c0_ddr4_ui_clk_sync_rst] [get_bd_pins util_vector_logic_5/Op1] [get_bd_pins clk_wiz_ddr4_3/reset]
  connect_bd_net -net decouple_filter_1 [get_bd_pins fpga_reg_0/filter_1_decouple_enable] [get_bd_pins function_1/decouple_filter]
  connect_bd_net -net ext_reset_in7_1 [get_bd_pins ss_ucs/peripheral_aresetn] [get_bd_pins axi_interconnect_4/M00_ARESETN] [get_bd_pins axi_interconnect_4/M01_ARESETN] [get_bd_pins axi_interconnect_4/M02_ARESETN] [get_bd_pins axi_interconnect_4/M03_ARESETN] [get_bd_pins axi_interconnect_ddr0/S00_ARESETN] [get_bd_pins axi_interconnect_ddr2/S00_ARESETN] [get_bd_pins axi_interconnect_ddr3/ARESETN] [get_bd_pins axi_interconnect_ddr3/S00_ARESETN] [get_bd_pins axi_interconnect_ddr1/S00_ARESETN]
  connect_bd_net -net lldma_wrapper_0_cfg_config_space_enable [get_bd_pins lldma_wrapper_0/cfg_config_space_enable] [get_bd_pins pcie4_uscale_plus_0/cfg_config_space_enable]
  connect_bd_net -net lldma_wrapper_0_cfg_ds_bus_number [get_bd_pins lldma_wrapper_0/cfg_ds_bus_number] [get_bd_pins pcie4_uscale_plus_0/cfg_ds_bus_number]
  connect_bd_net -net lldma_wrapper_0_cfg_ds_device_number [get_bd_pins lldma_wrapper_0/cfg_ds_device_number] [get_bd_pins pcie4_uscale_plus_0/cfg_ds_device_number]
  connect_bd_net -net lldma_wrapper_0_cfg_ds_port_number [get_bd_pins lldma_wrapper_0/cfg_ds_port_number] [get_bd_pins pcie4_uscale_plus_0/cfg_ds_port_number]
  connect_bd_net -net lldma_wrapper_0_cfg_dsn [get_bd_pins lldma_wrapper_0/cfg_dsn] [get_bd_pins pcie4_uscale_plus_0/cfg_dsn]
  connect_bd_net -net lldma_wrapper_0_cfg_err_cor_in [get_bd_pins lldma_wrapper_0/cfg_err_cor_in] [get_bd_pins pcie4_uscale_plus_0/cfg_err_cor_in]
  connect_bd_net -net lldma_wrapper_0_cfg_err_uncor_in [get_bd_pins lldma_wrapper_0/cfg_err_uncor_in] [get_bd_pins pcie4_uscale_plus_0/cfg_err_uncor_in]
  connect_bd_net -net lldma_wrapper_0_cfg_fc_sel [get_bd_pins lldma_wrapper_0/cfg_fc_sel] [get_bd_pins pcie4_uscale_plus_0/cfg_fc_sel]
  connect_bd_net -net lldma_wrapper_0_cfg_flr_done [get_bd_pins lldma_wrapper_0/cfg_flr_done] [get_bd_pins pcie4_uscale_plus_0/cfg_flr_done]
  connect_bd_net -net lldma_wrapper_0_cfg_hot_reset_out [get_bd_pins lldma_wrapper_0/cfg_hot_reset_out] [get_bd_pins pcie4_uscale_plus_0/cfg_hot_reset_in]
  connect_bd_net -net lldma_wrapper_0_cfg_interrupt_int [get_bd_pins lldma_wrapper_0/cfg_interrupt_int] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_int]
  connect_bd_net -net lldma_wrapper_0_cfg_interrupt_msi_attr [get_bd_pins lldma_wrapper_0/cfg_interrupt_msi_attr] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_attr]
  connect_bd_net -net lldma_wrapper_0_cfg_interrupt_msi_function_number [get_bd_pins lldma_wrapper_0/cfg_interrupt_msi_function_number] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_function_number]
  connect_bd_net -net lldma_wrapper_0_cfg_interrupt_msi_int [get_bd_pins lldma_wrapper_0/cfg_interrupt_msi_int] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_int]
  connect_bd_net -net lldma_wrapper_0_cfg_interrupt_msi_pending_status [get_bd_pins lldma_wrapper_0/cfg_interrupt_msi_pending_status] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_pending_status]
  connect_bd_net -net lldma_wrapper_0_cfg_interrupt_msi_select [get_bd_pins lldma_wrapper_0/cfg_interrupt_msi_select] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_select]
  connect_bd_net -net lldma_wrapper_0_cfg_interrupt_msi_tph_present [get_bd_pins lldma_wrapper_0/cfg_interrupt_msi_tph_present] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_tph_present]
  connect_bd_net -net lldma_wrapper_0_cfg_interrupt_msi_tph_st_tag [get_bd_pins lldma_wrapper_0/cfg_interrupt_msi_tph_st_tag] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_tph_st_tag]
  connect_bd_net -net lldma_wrapper_0_cfg_interrupt_msi_tph_type [get_bd_pins lldma_wrapper_0/cfg_interrupt_msi_tph_type] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_tph_type]
  connect_bd_net -net lldma_wrapper_0_cfg_interrupt_pending [get_bd_pins lldma_wrapper_0/cfg_interrupt_pending] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_pending]
  connect_bd_net -net lldma_wrapper_0_cfg_link_training_enable [get_bd_pins lldma_wrapper_0/cfg_link_training_enable] [get_bd_pins pcie4_uscale_plus_0/cfg_link_training_enable]
  connect_bd_net -net lldma_wrapper_0_cfg_mgmt_addr [get_bd_pins lldma_wrapper_0/cfg_mgmt_addr] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_addr]
  connect_bd_net -net lldma_wrapper_0_cfg_mgmt_byte_enable [get_bd_pins lldma_wrapper_0/cfg_mgmt_byte_enable] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_byte_enable]
  connect_bd_net -net lldma_wrapper_0_cfg_mgmt_read [get_bd_pins lldma_wrapper_0/cfg_mgmt_read] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_read]
  connect_bd_net -net lldma_wrapper_0_cfg_mgmt_write [get_bd_pins lldma_wrapper_0/cfg_mgmt_write] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_write]
  connect_bd_net -net lldma_wrapper_0_cfg_mgmt_write_data [get_bd_pins lldma_wrapper_0/cfg_mgmt_write_data] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_write_data]
  connect_bd_net -net lldma_wrapper_0_cfg_msg_transmit [get_bd_pins lldma_wrapper_0/cfg_msg_transmit] [get_bd_pins pcie4_uscale_plus_0/cfg_msg_transmit]
  connect_bd_net -net lldma_wrapper_0_cfg_msg_transmit_data [get_bd_pins lldma_wrapper_0/cfg_msg_transmit_data] [get_bd_pins pcie4_uscale_plus_0/cfg_msg_transmit_data]
  connect_bd_net -net lldma_wrapper_0_cfg_msg_transmit_type [get_bd_pins lldma_wrapper_0/cfg_msg_transmit_type] [get_bd_pins pcie4_uscale_plus_0/cfg_msg_transmit_type]
  connect_bd_net -net lldma_wrapper_0_cfg_power_state_change_ack [get_bd_pins lldma_wrapper_0/cfg_power_state_change_ack] [get_bd_pins pcie4_uscale_plus_0/cfg_power_state_change_ack]
  connect_bd_net -net lldma_wrapper_0_cfg_req_pm_transition_l23_ready [get_bd_pins lldma_wrapper_0/cfg_req_pm_transition_l23_ready] [get_bd_pins pcie4_uscale_plus_0/cfg_req_pm_transition_l23_ready]
  connect_bd_net -net lldma_wrapper_0_cfg_vf_flr_done [get_bd_pins lldma_wrapper_0/cfg_vf_flr_done] [get_bd_pins pcie4_uscale_plus_0/cfg_vf_flr_done]
  connect_bd_net -net lldma_wrapper_0_cfg_vf_flr_func_num [get_bd_pins lldma_wrapper_0/cfg_vf_flr_func_num] [get_bd_pins pcie4_uscale_plus_0/cfg_vf_flr_func_num]
  connect_bd_net -net lldma_wrapper_0_error_detect_lldma [get_bd_pins lldma_wrapper_0/error_detect_lldma] [get_bd_pins xlconcat_1/In16]
  connect_bd_net -net lldma_wrapper_0_pcie_cq_np_req [get_bd_pins lldma_wrapper_0/pcie_cq_np_req] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net lldma_wrapper_0_s_d2d_ready [get_bd_pins lldma_wrapper_0/s_d2d_ready] [get_bd_pins axis2axi_bridge_0/m_d2d_ready]
  connect_bd_net -net fpga_reg_0_conv_0_decouple_enable [get_bd_pins fpga_reg_0/conv_0_decouple_enable] [get_bd_pins function_0/decouple_conv]
  connect_bd_net -net fpga_reg_0_conv_1_decouple_enable [get_bd_pins fpga_reg_0/conv_1_decouple_enable] [get_bd_pins function_1/decouple_conv]
  connect_bd_net -net fpga_reg_0_dfx_conv_0_soft_reset_n [get_bd_pins fpga_reg_0/dfx_conv_0_soft_reset_n] [get_bd_pins proc_sys_reset_conv0/aux_reset_in]
  connect_bd_net -net fpga_reg_0_dfx_conv_1_soft_reset_n [get_bd_pins fpga_reg_0/dfx_conv_1_soft_reset_n] [get_bd_pins proc_sys_reset_conv1/aux_reset_in]
  connect_bd_net -net fpga_reg_0_dfx_filter_0_soft_reset_n [get_bd_pins fpga_reg_0/dfx_filter_0_soft_reset_n] [get_bd_pins proc_sys_reset_filter0/aux_reset_in]
  connect_bd_net -net fpga_reg_0_dfx_filter_1_soft_reset_n [get_bd_pins fpga_reg_0/dfx_filter_1_soft_reset_n] [get_bd_pins proc_sys_reset_filter1/aux_reset_in]
  connect_bd_net -net fpga_reg_0_filter_0_decouple_enable [get_bd_pins fpga_reg_0/filter_0_decouple_enable] [get_bd_pins function_0/decouple_filter]
  connect_bd_net -net fpga_reg_0_soft_reset_n [get_bd_pins fpga_reg_0/soft_reset_n] [get_bd_pins proc_sys_reset_200/aux_reset_in] [get_bd_pins proc_sys_reset_250/aux_reset_in] [get_bd_pins proc_sys_reset_150/aux_reset_in]
  connect_bd_net -net function_0_dout [get_bd_pins function_0/decoupler_status] [get_bd_pins xlconcat_2/In0]
  connect_bd_net -net function_1_decoupler_status [get_bd_pins function_1/decoupler_status] [get_bd_pins xlconcat_2/In1]
  connect_bd_net -net nw_chain_func_detect_fault_0_0 [get_bd_pins chain_0/detect_fault_direct] [get_bd_pins xlconcat_1/In0]
  connect_bd_net -net nw_chain_func_detect_fault_0_0_0 [get_bd_pins chain_1/detect_fault_direct] [get_bd_pins xlconcat_1/In4]
  connect_bd_net -net nw_chain_func_detect_fault_0_1 [get_bd_pins function_0/detect_fault_conv] [get_bd_pins xlconcat_1/In2]
  connect_bd_net -net nw_chain_func_detect_fault_0_1_0 [get_bd_pins function_1/detect_fault_conv] [get_bd_pins xlconcat_1/In6]
  connect_bd_net -net nw_chain_func_detect_fault_1_0 [get_bd_pins chain_0/detect_fault_chain] [get_bd_pins xlconcat_1/In1]
  connect_bd_net -net nw_chain_func_detect_fault_1_0_0 [get_bd_pins chain_1/detect_fault_chain] [get_bd_pins xlconcat_1/In5]
  connect_bd_net -net nw_chain_func_detect_fault_1_1 [get_bd_pins function_0/detect_fault_func] [get_bd_pins xlconcat_1/In3]
  connect_bd_net -net nw_chain_func_detect_fault_1_1_0 [get_bd_pins function_1/detect_fault_func] [get_bd_pins xlconcat_1/In7]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_current_speed [get_bd_pins pcie4_uscale_plus_0/cfg_current_speed] [get_bd_pins lldma_wrapper_0/cfg_current_speed]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_err_cor_out [get_bd_pins pcie4_uscale_plus_0/cfg_err_cor_out] [get_bd_pins lldma_wrapper_0/cfg_err_cor_out]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_err_fatal_out [get_bd_pins pcie4_uscale_plus_0/cfg_err_fatal_out] [get_bd_pins lldma_wrapper_0/cfg_err_fatal_out]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_err_nonfatal_out [get_bd_pins pcie4_uscale_plus_0/cfg_err_nonfatal_out] [get_bd_pins lldma_wrapper_0/cfg_err_nonfatal_out]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_fc_cpld [get_bd_pins pcie4_uscale_plus_0/cfg_fc_cpld] [get_bd_pins lldma_wrapper_0/cfg_fc_cpld]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_fc_cplh [get_bd_pins pcie4_uscale_plus_0/cfg_fc_cplh] [get_bd_pins lldma_wrapper_0/cfg_fc_cplh]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_fc_npd [get_bd_pins pcie4_uscale_plus_0/cfg_fc_npd] [get_bd_pins lldma_wrapper_0/cfg_fc_npd]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_fc_nph [get_bd_pins pcie4_uscale_plus_0/cfg_fc_nph] [get_bd_pins lldma_wrapper_0/cfg_fc_nph]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_fc_pd [get_bd_pins pcie4_uscale_plus_0/cfg_fc_pd] [get_bd_pins lldma_wrapper_0/cfg_fc_pd]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_fc_ph [get_bd_pins pcie4_uscale_plus_0/cfg_fc_ph] [get_bd_pins lldma_wrapper_0/cfg_fc_ph]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_flr_in_process [get_bd_pins pcie4_uscale_plus_0/cfg_flr_in_process] [get_bd_pins lldma_wrapper_0/cfg_flr_in_process]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_function_power_state [get_bd_pins pcie4_uscale_plus_0/cfg_function_power_state] [get_bd_pins lldma_wrapper_0/cfg_function_power_state]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_function_status [get_bd_pins pcie4_uscale_plus_0/cfg_function_status] [get_bd_pins lldma_wrapper_0/cfg_function_status]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_hot_reset_out [get_bd_pins pcie4_uscale_plus_0/cfg_hot_reset_out] [get_bd_pins lldma_wrapper_0/cfg_hot_reset_in]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_interrupt_msi_data [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_data] [get_bd_pins lldma_wrapper_0/cfg_interrupt_msi_data]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_interrupt_msi_enable [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_enable] [get_bd_pins lldma_wrapper_0/cfg_interrupt_msi_enable]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_interrupt_msi_fail [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_fail] [get_bd_pins lldma_wrapper_0/cfg_interrupt_msi_fail]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_interrupt_msi_mask_update [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_mask_update] [get_bd_pins lldma_wrapper_0/cfg_interrupt_msi_mask_update]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_interrupt_msi_mmenable [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_mmenable] [get_bd_pins lldma_wrapper_0/cfg_interrupt_msi_mmenable]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_interrupt_msi_sent [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_sent] [get_bd_pins lldma_wrapper_0/cfg_interrupt_msi_sent]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_interrupt_sent [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_sent] [get_bd_pins lldma_wrapper_0/cfg_interrupt_sent]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_link_power_state [get_bd_pins pcie4_uscale_plus_0/cfg_link_power_state] [get_bd_pins lldma_wrapper_0/cfg_link_power_state]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_local_error_out [get_bd_pins pcie4_uscale_plus_0/cfg_local_error_out] [get_bd_pins lldma_wrapper_0/cfg_local_error_out]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_local_error_valid [get_bd_pins pcie4_uscale_plus_0/cfg_local_error_valid] [get_bd_pins lldma_wrapper_0/cfg_local_error_valid]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_ltssm_state [get_bd_pins pcie4_uscale_plus_0/cfg_ltssm_state] [get_bd_pins lldma_wrapper_0/cfg_ltssm_state]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_max_payload [get_bd_pins pcie4_uscale_plus_0/cfg_max_payload] [get_bd_pins lldma_wrapper_0/cfg_max_payload]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_max_read_req [get_bd_pins pcie4_uscale_plus_0/cfg_max_read_req] [get_bd_pins lldma_wrapper_0/cfg_max_read_req]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_mgmt_read_data [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_read_data] [get_bd_pins lldma_wrapper_0/cfg_mgmt_read_data]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_mgmt_read_write_done [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_read_write_done] [get_bd_pins lldma_wrapper_0/cfg_mgmt_read_write_done]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_msg_received [get_bd_pins pcie4_uscale_plus_0/cfg_msg_received] [get_bd_pins lldma_wrapper_0/cfg_msg_received]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_msg_received_data [get_bd_pins pcie4_uscale_plus_0/cfg_msg_received_data] [get_bd_pins lldma_wrapper_0/cfg_msg_received_data]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_msg_received_type [get_bd_pins pcie4_uscale_plus_0/cfg_msg_received_type] [get_bd_pins lldma_wrapper_0/cfg_msg_received_type]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_msg_transmit_done [get_bd_pins pcie4_uscale_plus_0/cfg_msg_transmit_done] [get_bd_pins lldma_wrapper_0/cfg_msg_transmit_done]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_negotiated_width [get_bd_pins pcie4_uscale_plus_0/cfg_negotiated_width] [get_bd_pins lldma_wrapper_0/cfg_negotiated_width]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_obff_enable [get_bd_pins pcie4_uscale_plus_0/cfg_obff_enable] [get_bd_pins lldma_wrapper_0/cfg_obff_enable]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_phy_link_down [get_bd_pins pcie4_uscale_plus_0/cfg_phy_link_down] [get_bd_pins lldma_wrapper_0/cfg_phy_link_down]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_pl_status_change [get_bd_pins pcie4_uscale_plus_0/cfg_pl_status_change] [get_bd_pins lldma_wrapper_0/cfg_pl_status_change]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_power_state_change_interrupt [get_bd_pins pcie4_uscale_plus_0/cfg_power_state_change_interrupt] [get_bd_pins lldma_wrapper_0/cfg_power_state_change_interrupt]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_rcb_status [get_bd_pins pcie4_uscale_plus_0/cfg_rcb_status] [get_bd_pins lldma_wrapper_0/cfg_rcb_status]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_vf_flr_in_process [get_bd_pins pcie4_uscale_plus_0/cfg_vf_flr_in_process] [get_bd_pins lldma_wrapper_0/cfg_vf_flr_in_process]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_vf_status [get_bd_pins pcie4_uscale_plus_0/cfg_vf_status] [get_bd_pins lldma_wrapper_0/cfg_vf_status]
  connect_bd_net -net pcie4_uscale_plus_0_pcie_cq_np_req_count [get_bd_pins pcie4_uscale_plus_0/pcie_cq_np_req_count] [get_bd_pins lldma_wrapper_0/pcie_cq_np_req_count]
  connect_bd_net -net pcie4_uscale_plus_0_pcie_tfc_npd_av [get_bd_pins pcie4_uscale_plus_0/pcie_tfc_npd_av] [get_bd_pins lldma_wrapper_0/pcie_tfc_npd_av]
  connect_bd_net -net pcie4_uscale_plus_0_pcie_tfc_nph_av [get_bd_pins pcie4_uscale_plus_0/pcie_tfc_nph_av] [get_bd_pins lldma_wrapper_0/pcie_tfc_nph_av]
  connect_bd_net -net pcie4_uscale_plus_0_user_lnk_up [get_bd_pins pcie4_uscale_plus_0/user_lnk_up] [get_bd_pins lldma_wrapper_0/user_lnk_up]
  connect_bd_net -net pcie4c_uscale_plus_0_user_clk [get_bd_pins pcie4_uscale_plus_0/user_clk] [get_bd_pins ss_ucs/clk_in1] [get_bd_pins c_shift_ram_0/CLK] [get_bd_pins axi_interconnect_4/ACLK] [get_bd_pins axi_interconnect_4/S00_ACLK] [get_bd_pins axi_interconnect_ddr0/S05_ACLK] [get_bd_pins axi_interconnect_ddr0/S06_ACLK] [get_bd_pins axi_interconnect_lldma_ddr_0/ACLK] [get_bd_pins axi_interconnect_lldma_ddr_0/S00_ACLK] [get_bd_pins axi_interconnect_lldma_ddr_0/M00_ACLK] [get_bd_pins axi_interconnect_lldma_ddr_0/S01_ACLK] [get_bd_pins axi_interconnect_lldma_ddr_0/S02_ACLK] [get_bd_pins axi_interconnect_lldma_ddr_0/S03_ACLK] [get_bd_pins axi_interconnect_lldma_ddr_1/ACLK] [get_bd_pins axi_interconnect_lldma_ddr_1/S00_ACLK] [get_bd_pins axi_interconnect_lldma_ddr_1/M00_ACLK] [get_bd_pins axi_interconnect_lldma_ddr_1/S01_ACLK] [get_bd_pins axi_interconnect_lldma_ddr_1/S02_ACLK] [get_bd_pins axi_interconnect_lldma_ddr_1/S03_ACLK] [get_bd_pins axi_register_slice_0/aclk] [get_bd_pins clk_wiz_250_2_100/clk_in1] [get_bd_pins cms_subsystem_0/aclk_ctrl] [get_bd_pins proc_sys_reset_0/slowest_sync_clk] [get_bd_pins axis_register_slice_16/aclk] [get_bd_pins axis_register_slice_17/aclk] [get_bd_pins axis_clock_converter_eve_0/s_axis_aclk] [get_bd_pins axis_clock_converter_eve_1/s_axis_aclk] [get_bd_pins axis_clock_converter_cmd_0/m_axis_aclk] [get_bd_pins axis_clock_converter_cmd_1/m_axis_aclk] [get_bd_pins axi_interconnect_reg_base/ACLK] [get_bd_pins axi_interconnect_reg_base/S00_ACLK] [get_bd_pins axi_interconnect_reg_base/M00_ACLK] [get_bd_pins axi_interconnect_reg_base/M01_ACLK] [get_bd_pins axi_interconnect_reg_base/M02_ACLK] [get_bd_pins axi_interconnect_reg_base/M03_ACLK] [get_bd_pins axi_interconnect_reg_base/M04_ACLK] [get_bd_pins axi_interconnect_reg_0/ACLK] [get_bd_pins axi_interconnect_reg_0/S00_ACLK] [get_bd_pins axi_interconnect_reg_0/M00_ACLK] [get_bd_pins axi_interconnect_reg_1/ACLK] [get_bd_pins axi_interconnect_reg_1/S00_ACLK] [get_bd_pins axi_interconnect_reg_2/ACLK] [get_bd_pins axi_interconnect_reg_2/S00_ACLK] [get_bd_pins axi_interconnect_reg_2/M00_ACLK] [get_bd_pins proc_sys_reset_250/slowest_sync_clk] [get_bd_pins indirect_reg_access_0/user_clk] [get_bd_pins pci_mon_wire_0/user_clk] [get_bd_pins fpga_reg_0/ACLK] [get_bd_pins axis2axi_bridge_0/user_clk] [get_bd_pins lldma_wrapper_0/user_clk]
  connect_bd_net -net pcie4c_uscale_plus_0_user_reset [get_bd_pins pcie4_uscale_plus_0/user_reset] [get_bd_pins ss_ucs/reset] [get_bd_pins util_vector_logic_0/Op1] [get_bd_pins clk_wiz_250_2_100/reset] [get_bd_pins ddr4_0/sys_rst] [get_bd_pins ddr4_1/sys_rst] [get_bd_pins ddr4_2/sys_rst] [get_bd_pins ddr4_3/sys_rst] [get_bd_pins proc_sys_reset_0/ext_reset_in] [get_bd_pins proc_sys_reset_200/ext_reset_in] [get_bd_pins proc_sys_reset_150/ext_reset_in] [get_bd_pins proc_sys_reset_250/ext_reset_in]
  connect_bd_net -net pcie_perstn_1 [get_bd_ports pcie_perstn] [get_bd_pins pcie4_uscale_plus_0/sys_reset] [get_bd_pins lldma_wrapper_0/sys_rst]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins cms_subsystem_0/aresetn_ctrl]
  connect_bd_net -net proc_sys_reset_200_peripheral_aresetn [get_bd_pins proc_sys_reset_200/peripheral_aresetn] [get_bd_pins axi_interconnect_ddr0/S01_ARESETN] [get_bd_pins axi_interconnect_ddr0/S02_ARESETN] [get_bd_pins axi_interconnect_ddr0/S03_ARESETN] [get_bd_pins axi_interconnect_ddr0/S04_ARESETN] [get_bd_pins axi_interconnect_ddr0/S07_ARESETN] [get_bd_pins axi_interconnect_ddr0/S08_ARESETN] [get_bd_pins axi_interconnect_ddr0/S09_ARESETN] [get_bd_pins axi_interconnect_ddr0/S10_ARESETN] [get_bd_pins axi_interconnect_ddr2/ARESETN] [get_bd_pins axi_interconnect_ddr2/S01_ARESETN] [get_bd_pins axi_interconnect_ddr2/S02_ARESETN] [get_bd_pins axi_interconnect_ddr2/S03_ARESETN] [get_bd_pins axi_interconnect_ddr2/S04_ARESETN] [get_bd_pins axi_interconnect_ddr2/S05_ARESETN] [get_bd_pins axi_interconnect_ddr2/S06_ARESETN] [get_bd_pins axi_interconnect_ddr3/S01_ARESETN] [get_bd_pins axi_interconnect_ddr3/S02_ARESETN] [get_bd_pins axi_interconnect_ddr3/S03_ARESETN] [get_bd_pins axi_interconnect_ddr3/S04_ARESETN] [get_bd_pins axi_interconnect_ddr3/S05_ARESETN] [get_bd_pins axi_interconnect_ddr3/S06_ARESETN] [get_bd_pins axi_interconnect_ddr1/ARESETN] [get_bd_pins axi_interconnect_ddr1/S01_ARESETN] [get_bd_pins axi_interconnect_ddr1/S02_ARESETN] [get_bd_pins axi_interconnect_ddr1/S03_ARESETN] [get_bd_pins axi_interconnect_ddr1/S04_ARESETN] [get_bd_pins util_vector_logic_4/Op1] [get_bd_pins axis_clock_converter_eve_0/m_axis_aresetn] [get_bd_pins axis_clock_converter_eve_1/m_axis_aresetn] [get_bd_pins axis_clock_converter_cmd_0/s_axis_aresetn] [get_bd_pins axis_clock_converter_cmd_1/s_axis_aresetn] [get_bd_pins axi_interconnect_reg_0/M01_ARESETN] [get_bd_pins axi_interconnect_reg_0/M02_ARESETN] [get_bd_pins axi_interconnect_reg_0/M03_ARESETN] [get_bd_pins axi_interconnect_reg_0/M04_ARESETN] [get_bd_pins axi_interconnect_reg_1/M00_ARESETN] [get_bd_pins axi_interconnect_reg_1/M01_ARESETN] [get_bd_pins axi_interconnect_reg_1/M02_ARESETN] [get_bd_pins axi_interconnect_reg_1/M03_ARESETN] [get_bd_pins axi_interconnect_reg_1/M04_ARESETN] [get_bd_pins axi_interconnect_reg_1/M05_ARESETN] [get_bd_pins axi_interconnect_reg_1/M06_ARESETN] [get_bd_pins axi_interconnect_reg_1/M07_ARESETN] [get_bd_pins chain_1/aresetn_mm] [get_bd_pins chain_0/aresetn_mm] [get_bd_pins util_vector_logic_7/Op1] [get_bd_pins axi_interconnect_ddr0/ARESETN]
  connect_bd_net -net proc_sys_reset_250_peripheral_aresetn [get_bd_pins proc_sys_reset_250/peripheral_aresetn] [get_bd_pins util_vector_logic_6/Op1]
  connect_bd_net -net proc_sys_reset_50_peripheral_reset [get_bd_pins proc_sys_reset_50/peripheral_reset] [get_bd_pins ss_ucs/ext_reset_in]
  connect_bd_net -net proc_sys_reset_conv0_peripheral_aresetn [get_bd_pins proc_sys_reset_conv0/peripheral_aresetn] [get_bd_pins function_0/aresetn_mm_conv]
  connect_bd_net -net proc_sys_reset_conv1_peripheral_aresetn [get_bd_pins proc_sys_reset_conv1/peripheral_aresetn] [get_bd_pins function_1/aresetn_mm_conv]
  connect_bd_net -net proc_sys_reset_function0_peripheral_aresetn [get_bd_pins proc_sys_reset_filter0/peripheral_aresetn] [get_bd_pins function_0/aresetn_mm_filter]
  connect_bd_net -net proc_sys_reset_function1_peripheral_aresetn [get_bd_pins proc_sys_reset_filter1/peripheral_aresetn] [get_bd_pins function_1/aresetn_mm_filter]
  connect_bd_net -net qsfp0_int_l_0_1 [get_bd_ports qsfp0_int_l_0] [get_bd_pins cms_subsystem_0/qsfp0_int_l]
  connect_bd_net -net qsfp0_modprs_l_0_1 [get_bd_ports qsfp0_modprs_l_0] [get_bd_pins cms_subsystem_0/qsfp0_modprs_l]
  connect_bd_net -net s_axi_aresetn_1 [get_bd_pins proc_sys_reset_50/peripheral_aresetn] [get_bd_pins axi_gpio_0/s_axi_aresetn]
  connect_bd_net -net satellite_gpio_1 [get_bd_ports satellite_gpio] [get_bd_pins cms_subsystem_0/satellite_gpio]
  connect_bd_net -net util_ds_buf_0_IBUF_DS_ODIV2 [get_bd_pins util_ds_buf_0/IBUF_DS_ODIV2] [get_bd_pins pcie4_uscale_plus_0/sys_clk]
  connect_bd_net -net util_ds_buf_0_IBUF_OUT [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins pcie4_uscale_plus_0/sys_clk_gt]
  connect_bd_net -net util_reduced_logic_0_Res [get_bd_pins util_reduced_logic_0/Res] [get_bd_pins fpga_reg_0/detect_fault]
  connect_bd_net -net util_vector_logic_0_Res [get_bd_pins util_vector_logic_0/Res] [get_bd_pins axi_interconnect_4/ARESETN] [get_bd_pins axi_interconnect_4/S00_ARESETN] [get_bd_pins axi_interconnect_ddr0/S05_ARESETN] [get_bd_pins axi_interconnect_ddr0/S06_ARESETN] [get_bd_pins axi_interconnect_lldma_ddr_0/ARESETN] [get_bd_pins axi_interconnect_lldma_ddr_0/S00_ARESETN] [get_bd_pins axi_interconnect_lldma_ddr_0/M00_ARESETN] [get_bd_pins axi_interconnect_lldma_ddr_0/S01_ARESETN] [get_bd_pins axi_interconnect_lldma_ddr_0/S02_ARESETN] [get_bd_pins axi_interconnect_lldma_ddr_0/S03_ARESETN] [get_bd_pins axi_interconnect_lldma_ddr_1/ARESETN] [get_bd_pins axi_interconnect_lldma_ddr_1/S00_ARESETN] [get_bd_pins axi_interconnect_lldma_ddr_1/M00_ARESETN] [get_bd_pins axi_interconnect_lldma_ddr_1/S01_ARESETN] [get_bd_pins axi_interconnect_lldma_ddr_1/S02_ARESETN] [get_bd_pins axi_interconnect_lldma_ddr_1/S03_ARESETN] [get_bd_pins axi_register_slice_0/aresetn] [get_bd_pins proc_sys_reset_300/ext_reset_in] [get_bd_pins proc_sys_reset_50/ext_reset_in] [get_bd_pins axis_register_slice_17/aresetn] [get_bd_pins axis_register_slice_16/aresetn] [get_bd_pins axis_clock_converter_eve_0/s_axis_aresetn] [get_bd_pins axis_clock_converter_eve_1/s_axis_aresetn] [get_bd_pins axis_clock_converter_cmd_0/m_axis_aresetn] [get_bd_pins axis_clock_converter_cmd_1/m_axis_aresetn] [get_bd_pins axi_interconnect_reg_base/ARESETN] [get_bd_pins axi_interconnect_reg_base/M00_ARESETN] [get_bd_pins axi_interconnect_reg_base/S00_ARESETN] [get_bd_pins axi_interconnect_reg_base/M01_ARESETN] [get_bd_pins axi_interconnect_reg_base/M02_ARESETN] [get_bd_pins axi_interconnect_reg_base/M03_ARESETN] [get_bd_pins axi_interconnect_reg_base/M04_ARESETN] [get_bd_pins axi_interconnect_reg_0/ARESETN] [get_bd_pins axi_interconnect_reg_0/S00_ARESETN] [get_bd_pins axi_interconnect_reg_0/M00_ARESETN] [get_bd_pins axi_interconnect_reg_1/ARESETN] [get_bd_pins axi_interconnect_reg_1/S00_ARESETN] [get_bd_pins axi_interconnect_reg_2/ARESETN] [get_bd_pins axi_interconnect_reg_2/S00_ARESETN] [get_bd_pins axi_interconnect_reg_2/M00_ARESETN] [get_bd_pins proc_sys_reset_100/ext_reset_in] [get_bd_pins indirect_reg_access_0/reset_n] [get_bd_pins pci_mon_wire_0/reset_n] [get_bd_pins fpga_reg_0/ARESET_N] [get_bd_pins axis2axi_bridge_0/reset_n]
  connect_bd_net -net util_vector_logic_4_Res [get_bd_pins util_vector_logic_4/Res] [get_bd_pins lldma_wrapper_0/ext_reset]
  connect_bd_net -net util_vector_logic_5_Res [get_bd_pins util_vector_logic_5/Res] [get_bd_pins axi_interconnect_ddr3/M00_ARESETN] [get_bd_pins ddr4_3/c0_ddr4_aresetn] [get_bd_pins axi_interconnect_reg_2/M04_ARESETN]
  connect_bd_net -net util_vector_logic_6_Res [get_bd_pins util_vector_logic_6/Res] [get_bd_pins c_shift_ram_0/D]
  connect_bd_net -net util_vector_logic_7_Res [get_bd_pins util_vector_logic_7/Res] [get_bd_pins proc_sys_reset_filter0/ext_reset_in] [get_bd_pins proc_sys_reset_filter1/ext_reset_in] [get_bd_pins proc_sys_reset_conv0/ext_reset_in] [get_bd_pins proc_sys_reset_conv1/ext_reset_in]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins xlconcat_0/dout] [get_bd_pins pcie4_uscale_plus_0/pcie_cq_np_req]
  connect_bd_net -net xlconcat_1_dout [get_bd_pins xlconcat_1/dout] [get_bd_pins util_reduced_logic_0/Op1]
  connect_bd_net -net xlconcat_2_dout [get_bd_pins xlconcat_2/dout] [get_bd_pins fpga_reg_0/decouple_status]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins xlconstant_val0/dout] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_function_number] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_debug_access] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_pending_status_data_enable] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_pending_status_function_num] [get_bd_pins pcie4_uscale_plus_0/cfg_pm_aspm_l1_entry_reject] [get_bd_pins lldma_wrapper_0/pcie_rq_seq_num] [get_bd_pins lldma_wrapper_0/pcie_rq_seq_num_vld] [get_bd_pins lldma_wrapper_0/pcie_rq_tag] [get_bd_pins lldma_wrapper_0/pcie_rq_tag_vld] [get_bd_pins lldma_wrapper_0/cfg_ltr_enable]
  connect_bd_net -net xlconstant_0_dout1 [get_bd_pins xlconstant_0/dout] [get_bd_pins fpga_reg_0/locked_qsfp_clk0] [get_bd_pins fpga_reg_0/locked_qsfp_clk1] [get_bd_pins chain_1/s_axis_extif1_evt_tvalid]
  connect_bd_net -net xlconstant_1_dout [get_bd_pins xlconstant_1/dout] [get_bd_pins fpga_reg_0/ddr4_ecc_single_0] [get_bd_pins fpga_reg_0/ddr4_ecc_multiple_0] [get_bd_pins fpga_reg_0/ddr4_ecc_single_1] [get_bd_pins fpga_reg_0/ddr4_ecc_multiple_1] [get_bd_pins fpga_reg_0/ddr4_ecc_single_2] [get_bd_pins fpga_reg_0/ddr4_ecc_multiple_2] [get_bd_pins fpga_reg_0/ddr4_ecc_single_3] [get_bd_pins fpga_reg_0/ddr4_ecc_multiple_3]
  connect_bd_net -net xlconstant_2_dout [get_bd_pins xlconstant_2/dout] [get_bd_pins lldma_wrapper_0/s_axis_transfer_cmd_2_tvalid] [get_bd_pins lldma_wrapper_0/s_axis_transfer_cmd_3_tvalid] [get_bd_pins lldma_wrapper_0/s_axis_transfer_cmd_2_tdata] [get_bd_pins lldma_wrapper_0/s_axis_transfer_cmd_3_tdata] [get_bd_pins lldma_wrapper_0/m_axis_transfer_eve_2_tready] [get_bd_pins lldma_wrapper_0/m_axis_transfer_eve_3_tready]
  connect_bd_net -net xlconstant_3_dout [get_bd_pins xlconstant_3/dout] [get_bd_pins xlconcat_1/In8] [get_bd_pins xlconcat_1/In9] [get_bd_pins xlconcat_1/In10] [get_bd_pins xlconcat_1/In11] [get_bd_pins xlconcat_1/In12] [get_bd_pins xlconcat_1/In13] [get_bd_pins xlconcat_1/In14] [get_bd_pins xlconcat_1/In15]
  connect_bd_net -net xlconstant_val1_dout [get_bd_pins xlconstant_val1/dout] [get_bd_pins xlconcat_0/In1] [get_bd_pins pcie4_uscale_plus_0/cfg_pm_aspm_tx_l0s_entry_disable] [get_bd_pins cms_subsystem_0/qsfp1_modprs_l] [get_bd_pins cms_subsystem_0/qsfp1_int_l] [get_bd_pins chain_1/m_axis_extif1_cmd_tready]

  ## Create address segments
  #assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces indirect_reg_access_0/m_axi] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x000400000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces indirect_reg_access_0/m_axi] [get_bd_addr_segs ddr4_1/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x000800000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces indirect_reg_access_0/m_axi] [get_bd_addr_segs ddr4_2/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x000C00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces indirect_reg_access_0/m_axi] [get_bd_addr_segs ddr4_3/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x00024000 -range 0x00000400 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs function_0/axi4l_decoupler_conv/s_axi/reg0] -force
  #assign_bd_address -offset 0x00024400 -range 0x00000400 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs function_1/axi4l_decoupler_conv/s_axi/reg0] -force
  #assign_bd_address -offset 0x00025000 -range 0x00000400 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs function_0/axi4l_decoupler_filter/s_axi/reg0] -force
  #assign_bd_address -offset 0x00026000 -range 0x00000400 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs function_1/axi4l_decoupler_filter/s_axi/reg0] -force
  #assign_bd_address -offset 0x00001000 -range 0x00001000 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs chain_0/chain_control_0/s_axi_control/reg0] -force
  #assign_bd_address -offset 0x00002000 -range 0x00001000 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs chain_1/chain_control_0/s_axi_control/reg0] -force
  #assign_bd_address -offset 0x00040000 -range 0x00040000 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs cms_subsystem_0/s_axi_ctrl/Mem] -force
  #assign_bd_address -offset 0x00031000 -range 0x00000400 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP_CTRL/C0_REG] -force
  #assign_bd_address -offset 0x00031400 -range 0x00000400 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs ddr4_1/C0_DDR4_MEMORY_MAP_CTRL/C0_REG] -force
  #assign_bd_address -offset 0x00031800 -range 0x00000400 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs ddr4_2/C0_DDR4_MEMORY_MAP_CTRL/C0_REG] -force
  #assign_bd_address -offset 0x00031C00 -range 0x00000400 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs ddr4_3/C0_DDR4_MEMORY_MAP_CTRL/C0_REG] -force
  #assign_bd_address -offset 0x00005000 -range 0x00001000 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs chain_0/direct_trans_a_0/s_axi_control/reg0] -force
  #assign_bd_address -offset 0x00006000 -range 0x00001000 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs chain_1/direct_trans_a_0/s_axi_control/reg0] -force
  #assign_bd_address -offset 0x00010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs lldma_wrapper_0/s_axi/reg0] -force
  #assign_bd_address -offset 0x00000000 -range 0x00001000 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs fpga_reg_0/interface_aximm/reg0] -force
  #assign_bd_address -offset 0x00030000 -range 0x00001000 -target_address_space [get_bd_addr_spaces axis2axi_bridge_0/m_axi] [get_bd_addr_segs indirect_reg_access_0/s_axi/reg0] -force
  #assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces lldma_wrapper_0/m_axi_cd_0] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces lldma_wrapper_0/m_axi_cd_1] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces lldma_wrapper_0/m_axi_cd_2] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces lldma_wrapper_0/m_axi_cd_3] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces lldma_wrapper_0/m_axi_cu_0] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces lldma_wrapper_0/m_axi_cu_1] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces lldma_wrapper_0/m_axi_cu_2] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces lldma_wrapper_0/m_axi_cu_3] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces chain_0/chain_control_0/m_axi_extif0_buffer_rd] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces chain_0/chain_control_0/m_axi_extif0_buffer_wr] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x000800000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces chain_0/chain_control_0/m_axi_extif1_buffer_rd] [get_bd_addr_segs ddr4_2/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x000800000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces chain_0/chain_control_0/m_axi_extif1_buffer_wr] [get_bd_addr_segs ddr4_2/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces chain_1/chain_control_0/m_axi_extif0_buffer_rd] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces chain_1/chain_control_0/m_axi_extif0_buffer_wr] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x000800000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces chain_1/chain_control_0/m_axi_extif1_buffer_rd] [get_bd_addr_segs ddr4_2/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x000800000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces chain_1/chain_control_0/m_axi_extif1_buffer_wr] [get_bd_addr_segs ddr4_2/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x000400000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces function_0/conversion_ada_0/m_axi_ingr_frame_buffer] [get_bd_addr_segs ddr4_1/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x00000000 -range 0x00000400 -target_address_space [get_bd_addr_spaces function_0/axi4l_decoupler_filter/m_axi] [get_bd_addr_segs function_0/filter_resize_0/s_axi_control/reg0] -force
  #assign_bd_address -offset 0x00000000 -range 0x00000400 -target_address_space [get_bd_addr_spaces function_0/axi4l_decoupler_conv/m_axi] [get_bd_addr_segs function_0/conversion_ada_0/s_axi_control/reg0] -force
  #assign_bd_address -offset 0x000400000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces function_1/conversion_ada_0/m_axi_ingr_frame_buffer] [get_bd_addr_segs ddr4_1/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  #assign_bd_address -offset 0x00000000 -range 0x00000400 -target_address_space [get_bd_addr_spaces function_1/axi4l_decoupler_conv/m_axi] [get_bd_addr_segs function_1/conversion_ada_0/s_axi_control/reg0] -force
  #assign_bd_address -offset 0x00000000 -range 0x00000400 -target_address_space [get_bd_addr_spaces function_1/axi4l_decoupler_filter/m_axi] [get_bd_addr_segs function_1/filter_resize_0/s_axi_control/reg0] -force


  # Restore current instance
  current_bd_instance $oldCurInst

  #validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


