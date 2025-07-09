#=================================================
# Copyright 2025 NTT Corporation
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
# axis_ddu_sink, axis_ddu_sink, axis_ddu_sink, axis_ddu_sink, axis_dkuld_sink, axis_dkulid_sink, axis_du_sink, nop_st_wrapper

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
xilinx.com:ip:xdma:4.1\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:axi_bram_ctrl:4.1\
xilinx.com:ip:blk_mem_gen:8.4\
xilinx.com:ip:util_ds_buf:2.2\
xilinx.com:ip:axis_switch:1.1\
xilinx.com:ip:xlconstant:1.1\
xilinx.com:ip:system_ila:1.1\
xilinx.com:ip:axis_data_fifo:2.0\
user.org:user:stream_engine:1.0\
xilinx.com:ip:cmac_usplus:3.1\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:ddr4:2.2\
xilinx.com:ip:util_vector_logic:2.0\
xilinx.com:ip:axis_clock_converter:1.1\
xilinx.com:ip:cms_subsystem:4.0\
user.org:user:route_controller:1.0\
xilinx.com:ip:vio:3.0\
xilinx.com:ip:axis_register_slice:1.1\
user.org:user:toe_network:1.0\
user.org:user:toe_ctrl:1.0\
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
axis_ddu_sink\
axis_ddu_sink\
axis_ddu_sink\
axis_ddu_sink\
axis_dkuld_sink\
axis_dkulid_sink\
axis_du_sink\
nop_st_wrapper\
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
  set CLK_IN_D_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 CLK_IN_D_0 ]

  set pcie_mgt_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pcie_mgt_0 ]

  set C0_DDR4_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 C0_DDR4_0 ]

  set gt_ref_clk_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_ref_clk_0 ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {161132812} \
   ] $gt_ref_clk_0

  set C0_SYS_CLK_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 C0_SYS_CLK_0 ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {300000000} \
   ] $C0_SYS_CLK_0

  set satellite_uart_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:uart_rtl:1.0 satellite_uart_0 ]

  set gt_serial_port_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 gt_serial_port_0 ]


  # Create ports
  set sys_rst_n_0 [ create_bd_port -dir I -type rst sys_rst_n_0 ]
  set satellite_gpio_0 [ create_bd_port -dir I -from 3 -to 0 -type intr satellite_gpio_0 ]
  set_property -dict [ list \
   CONFIG.PortWidth {4} \
   CONFIG.SENSITIVITY {EDGE_RISING} \
 ] $satellite_gpio_0
  set qsfp0_lp_mode_0 [ create_bd_port -dir O -from 0 -to 0 qsfp0_lp_mode_0 ]
  set qsfp0_reset_l_0 [ create_bd_port -dir O -from 0 -to 0 qsfp0_reset_l_0 ]

  # Create instance: xdma_0, and set properties
  set xdma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xdma:4.1 xdma_0 ]
  set_property -dict [list \
    CONFIG.PCIE_BOARD_INTERFACE {pci_express_x16} \
    CONFIG.SYS_RST_N_BOARD_INTERFACE {pcie_perstn} \
    CONFIG.axi_bypass_64bit_en {true} \
    CONFIG.axi_bypass_prefetchable {true} \
    CONFIG.axil_master_64bit_en {true} \
    CONFIG.axilite_master_en {true} \
    CONFIG.axilite_master_size {2} \
    CONFIG.axist_bypass_en {true} \
    CONFIG.axist_bypass_scale {Gigabytes} \
    CONFIG.axist_bypass_size {32} \
    CONFIG.cfg_mgmt_if {false} \
    CONFIG.dsc_bypass_rd {0111} \
    CONFIG.dsc_bypass_wr {0111} \
    CONFIG.mode_selection {Advanced} \
    CONFIG.pf0_interrupt_pin {NONE} \
    CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
    CONFIG.xdma_axi_intf_mm {AXI_Stream} \
    CONFIG.xdma_axilite_slave {true} \
    CONFIG.xdma_num_usr_irq {16} \
    CONFIG.xdma_pcie_64bit_en {true} \
    CONFIG.xdma_rnum_chnl {3} \
    CONFIG.xdma_sts_ports {true} \
    CONFIG.xdma_wnum_chnl {3} \
  ] $xdma_0


  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

  # Create instance: axi_interconnect_0, and set properties
  set axi_interconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0 ]
  set_property -dict [list \
    CONFIG.M00_HAS_REGSLICE {3} \
    CONFIG.M01_HAS_REGSLICE {3} \
    CONFIG.M02_HAS_REGSLICE {3} \
    CONFIG.M03_HAS_REGSLICE {3} \
    CONFIG.M04_HAS_REGSLICE {3} \
    CONFIG.M05_HAS_REGSLICE {3} \
    CONFIG.M06_HAS_REGSLICE {3} \
    CONFIG.M07_HAS_REGSLICE {3} \
    CONFIG.M08_HAS_REGSLICE {3} \
    CONFIG.M09_HAS_REGSLICE {3} \
    CONFIG.M10_HAS_REGSLICE {3} \
    CONFIG.NUM_MI {11} \
  ] $axi_interconnect_0


  # Create instance: axi_bram_ctrl_0, and set properties
  set axi_bram_ctrl_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0 ]
  set_property -dict [list \
    CONFIG.PROTOCOL {AXI4LITE} \
    CONFIG.SINGLE_PORT_BRAM {1} \
  ] $axi_bram_ctrl_0


  # Create instance: blk_mem_gen_0, and set properties
  set blk_mem_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_0 ]
  set_property -dict [list \
    CONFIG.Coe_File {../../../../../../../bram.coe} \
    CONFIG.Load_Init_File {true} \
    CONFIG.Memory_Type {Single_Port_ROM} \
  ] $blk_mem_gen_0


  # Create instance: util_ds_buf_0, and set properties
  set util_ds_buf_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf_0 ]
  set_property CONFIG.DIFF_CLK_IN_BOARD_INTERFACE {pcie_refclk} $util_ds_buf_0


  # Create instance: if_header_switch, and set properties
  set if_header_switch [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 if_header_switch ]
  set_property -dict [list \
    CONFIG.M01_AXIS_HIGHTDEST {0x0000000f} \
    CONFIG.NUM_MI {2} \
    CONFIG.NUM_SI {2} \
  ] $if_header_switch


  # Create instance: of_header_switch, and set properties
  set of_header_switch [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 of_header_switch ]
  set_property -dict [list \
    CONFIG.M01_AXIS_HIGHTDEST {0x0000000f} \
    CONFIG.NUM_MI {2} \
    CONFIG.NUM_SI {2} \
  ] $of_header_switch


  # Create instance: idata_switch, and set properties
  set idata_switch [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 idata_switch ]
  set_property -dict [list \
    CONFIG.HAS_TLAST {1} \
    CONFIG.ARB_ON_TLAST {1} \
    CONFIG.ARB_ON_MAX_XFERS {0} \
    CONFIG.M01_AXIS_HIGHTDEST {0x0000000f} \
    CONFIG.NUM_MI {2} \
    CONFIG.NUM_SI {2} \
  ] $idata_switch


  # Create instance: if_header_consume_switch, and set properties
  set if_header_consume_switch [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 if_header_consume_switch ]
  set_property -dict [list \
    CONFIG.M01_AXIS_BASETDEST {0x00000002} \
    CONFIG.M01_AXIS_HIGHTDEST {0x0000000f} \
    CONFIG.M02_AXIS_BASETDEST {0x00000001} \
    CONFIG.M02_AXIS_HIGHTDEST {0x00000001} \
    CONFIG.NUM_MI {3} \
    CONFIG.NUM_SI {1} \
  ] $if_header_consume_switch


  # Create instance: if_consume_switch, and set properties
  set if_consume_switch [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 if_consume_switch ]
  set_property -dict [list \
    CONFIG.M01_AXIS_BASETDEST {0x00000002} \
    CONFIG.M01_AXIS_HIGHTDEST {0x0000000f} \
    CONFIG.M02_AXIS_BASETDEST {0x00000001} \
    CONFIG.M02_AXIS_HIGHTDEST {0x00000001} \
    CONFIG.NUM_MI {3} \
    CONFIG.NUM_SI {1} \
  ] $if_consume_switch


  # Create instance: of_complete_switch, and set properties
  set of_complete_switch [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 of_complete_switch ]
  set_property -dict [list \
    CONFIG.M01_AXIS_BASETDEST {0x00000002} \
    CONFIG.M01_AXIS_HIGHTDEST {0x0000000f} \
    CONFIG.M02_AXIS_BASETDEST {0x00000001} \
    CONFIG.M02_AXIS_HIGHTDEST {0x00000001} \
    CONFIG.NUM_MI {3} \
    CONFIG.NUM_SI {1} \
  ] $of_complete_switch


  # Create instance: odata_switch, and set properties
  set odata_switch [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 odata_switch ]
  set_property -dict [list \
    CONFIG.M01_AXIS_BASETDEST {0x00000002} \
    CONFIG.M01_AXIS_HIGHTDEST {0x0000000f} \
    CONFIG.M02_AXIS_BASETDEST {0x00000001} \
    CONFIG.M02_AXIS_HIGHTDEST {0x00000001} \
    CONFIG.NUM_MI {3} \
    CONFIG.NUM_SI {1} \
  ] $odata_switch


  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
  set_property CONFIG.CONST_VAL {0} $xlconstant_0


  # Create instance: if_header_ddu_sink, and set properties
  set block_name axis_ddu_sink
  set block_cell_name if_header_ddu_sink
  if { [catch {set if_header_ddu_sink [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $if_header_ddu_sink eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property CONFIG.DW {128} $if_header_ddu_sink


  # Create instance: of_header_ddu_sink, and set properties
  set block_name axis_ddu_sink
  set block_cell_name of_header_ddu_sink
  if { [catch {set of_header_ddu_sink [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $of_header_ddu_sink eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property CONFIG.DW {128} $of_header_ddu_sink


  # Create instance: if_consume_ddu_sink, and set properties
  set block_name axis_ddu_sink
  set block_cell_name if_consume_ddu_sink
  if { [catch {set if_consume_ddu_sink [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $if_consume_ddu_sink eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property CONFIG.DW {8} $if_consume_ddu_sink


  # Create instance: of_complete_ddu_sink, and set properties
  set block_name axis_ddu_sink
  set block_cell_name of_complete_ddu_sink
  if { [catch {set of_complete_ddu_sink [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $of_complete_ddu_sink eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property CONFIG.DW {128} $of_complete_ddu_sink


  # Create instance: odata_dkuld_sink, and set properties
  set block_name axis_dkuld_sink
  set block_cell_name odata_dkuld_sink
  if { [catch {set odata_dkuld_sink [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $odata_dkuld_sink eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: idata_dkulid_sink, and set properties
  set block_name axis_dkulid_sink
  set block_cell_name idata_dkulid_sink
  if { [catch {set idata_dkulid_sink [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $idata_dkulid_sink eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: if_header_consume_du_sink, and set properties
  set block_name axis_du_sink
  set block_cell_name if_header_consume_du_sink
  if { [catch {set if_header_consume_du_sink [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $if_header_consume_du_sink eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: xlconstant_0x16, and set properties
  set xlconstant_0x16 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0x16 ]
  set_property -dict [list \
    CONFIG.CONST_VAL {0} \
    CONFIG.CONST_WIDTH {16} \
  ] $xlconstant_0x16


  # Create instance: system_ila_iframe, and set properties
  set system_ila_iframe [ create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_iframe ]
  set_property -dict [list \
    CONFIG.C_INPUT_PIPE_STAGES {2} \
    CONFIG.C_NUM_MONITOR_SLOTS {9} \
    CONFIG.C_SLOT {8} \
    CONFIG.C_SLOT_0_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_1_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_2_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_3_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_4_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_5_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_6_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_7_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_8_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
  ] $system_ila_iframe


  # Create instance: system_ila_oframe, and set properties
  set system_ila_oframe [ create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_oframe ]
  set_property -dict [list \
    CONFIG.C_INPUT_PIPE_STAGES {2} \
    CONFIG.C_NUM_MONITOR_SLOTS {7} \
    CONFIG.C_SLOT {0} \
    CONFIG.C_SLOT_0_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_1_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_2_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_3_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_4_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_5_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_6_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
  ] $system_ila_oframe


  # Create instance: axis_data_fifo_nop_in, and set properties
  set axis_data_fifo_nop_in [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_data_fifo_nop_in ]
  set_property CONFIG.FIFO_DEPTH {2048} $axis_data_fifo_nop_in


  # Create instance: axis_data_fifo_nop_out, and set properties
  set axis_data_fifo_nop_out [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_data_fifo_nop_out ]
  set_property CONFIG.FIFO_DEPTH {2048} $axis_data_fifo_nop_out


  # Create instance: stream_engine_rx, and set properties
  set stream_engine_rx [ create_bd_cell -type ip -vlnv user.org:user:stream_engine:1.0 stream_engine_rx ]
  set_property -dict [list \
    CONFIG.BURST_MAX {6} \
    CONFIG.IS_TX {0} \
  ] $stream_engine_rx


  # Create instance: stream_engine_tx, and set properties
  set stream_engine_tx [ create_bd_cell -type ip -vlnv user.org:user:stream_engine:1.0 stream_engine_tx ]
  set_property -dict [list \
    CONFIG.BURST_MAX {6} \
    CONFIG.IS_TX {1} \
  ] $stream_engine_tx


  # Create instance: cmac_usplus_0, and set properties
  set cmac_usplus_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:cmac_usplus:3.1 cmac_usplus_0 ]
  set_property -dict [list \
    CONFIG.DIFFCLK_BOARD_INTERFACE {qsfp0_161mhz} \
    CONFIG.ENABLE_AXI_INTERFACE {1} \
    CONFIG.ENABLE_PIPELINE_REG {1} \
    CONFIG.ETHERNET_BOARD_INTERFACE {qsfp0_4x} \
    CONFIG.INCLUDE_RS_FEC {1} \
    CONFIG.RX_FLOW_CONTROL {0} \
    CONFIG.TX_FLOW_CONTROL {0} \
    CONFIG.USER_INTERFACE {AXIS} \
  ] $cmac_usplus_0


  # Create instance: clk_wiz_toe, and set properties
  set clk_wiz_toe [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_toe ]
  set_property -dict [list \
    CONFIG.CLKOUT1_JITTER {111.430} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {300} \
    CONFIG.CLKOUT2_JITTER {134.506} \
    CONFIG.CLKOUT2_PHASE_ERROR {154.678} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_JITTER {153.164} \
    CONFIG.CLKOUT3_PHASE_ERROR {154.678} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {50} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLK_OUT1_PORT {toe300} \
    CONFIG.CLK_OUT2_PORT {sys100} \
    CONFIG.CLK_OUT3_PORT {sys50} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {4.000} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {12} \
    CONFIG.MMCM_CLKOUT2_DIVIDE {24} \
    CONFIG.NUM_OUT_CLKS {3} \
    CONFIG.USE_RESET {false} \
  ] $clk_wiz_toe


  # Create instance: proc_sys_reset_toe, and set properties
  set proc_sys_reset_toe [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_toe ]
  set_property CONFIG.C_NUM_PERP_ARESETN {1} $proc_sys_reset_toe


  # Create instance: proc_sys_reset_toe_rx, and set properties
  set proc_sys_reset_toe_rx [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_toe_rx ]

  # Create instance: proc_sys_reset_toe_tx, and set properties
  set proc_sys_reset_toe_tx [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_toe_tx ]

  # Create instance: ddr4_2, and set properties
  set ddr4_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr4_2 ]
  set_property -dict [list \
    CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
    CONFIG.C0.DDR4_AUTO_AP_COL_A3 {true} \
    CONFIG.C0.DDR4_Mem_Add_Map {ROW_COLUMN_BANK_INTLV} \
    CONFIG.C0.DDR4_SAVE_RESTORE {false} \
    CONFIG.C0.DDR4_SELF_REFRESH {false} \
    CONFIG.C0_CLOCK_BOARD_INTERFACE {default_300mhz_clk2} \
    CONFIG.C0_DDR4_BOARD_INTERFACE {ddr4_sdram_c2} \
    CONFIG.RESET_BOARD_INTERFACE {pcie_perstn} \
  ] $ddr4_2


  # Create instance: proc_sys_reset_100, and set properties
  set proc_sys_reset_100 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_100 ]

  # Create instance: proc_sys_reset_ddr2, and set properties
  set proc_sys_reset_ddr2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_ddr2 ]

  # Create instance: sys_rst_inv, and set properties
  set sys_rst_inv [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 sys_rst_inv ]
  set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
  ] $sys_rst_inv


  # Create instance: axis_clock_converter_pci_toe_0, and set properties
  set axis_clock_converter_pci_toe_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_pci_toe_0 ]

  # Create instance: axis_clock_converter_pci_toe_1, and set properties
  set axis_clock_converter_pci_toe_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_pci_toe_1 ]

  # Create instance: axis_clock_converter_pci_toe_2, and set properties
  set axis_clock_converter_pci_toe_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_pci_toe_2 ]

  # Create instance: axis_clock_converter_pci_toe_3, and set properties
  set axis_clock_converter_pci_toe_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_pci_toe_3 ]

  # Create instance: axis_clock_converter_toe_pci_0, and set properties
  set axis_clock_converter_toe_pci_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_toe_pci_0 ]

  # Create instance: axis_clock_converter_toe_pci_1, and set properties
  set axis_clock_converter_toe_pci_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_toe_pci_1 ]

  # Create instance: axis_clock_converter_toe_pci_2, and set properties
  set axis_clock_converter_toe_pci_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_toe_pci_2 ]

  # Create instance: axis_clock_converter_toe_pci_3, and set properties
  set axis_clock_converter_toe_pci_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_toe_pci_3 ]

  # Create instance: axis_switch_frame_req, and set properties
  set axis_switch_frame_req [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_frame_req ]
  set_property -dict [list \
    CONFIG.M00_AXIS_HIGHTDEST {0x00000000} \
    CONFIG.M01_AXIS_BASETDEST {0x00000001} \
    CONFIG.M01_AXIS_HIGHTDEST {0x00000001} \
    CONFIG.NUM_MI {2} \
  ] $axis_switch_frame_req


  # Create instance: axis_switch_frame_ready, and set properties
  set axis_switch_frame_ready [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_frame_ready ]
  set_property -dict [list \
    CONFIG.M00_AXIS_HIGHTDEST {0x00000000} \
    CONFIG.M01_AXIS_BASETDEST {0x00000001} \
    CONFIG.M01_AXIS_HIGHTDEST {0x00000001} \
    CONFIG.NUM_MI {2} \
  ] $axis_switch_frame_ready


  # Create instance: axis_clock_converter_pci_toe_4, and set properties
  set axis_clock_converter_pci_toe_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_pci_toe_4 ]

  # Create instance: axis_data_fifo_0, and set properties
  set axis_data_fifo_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_data_fifo_0 ]
  set_property CONFIG.IS_ACLK_ASYNC {1} $axis_data_fifo_0


  # Create instance: axis_data_fifo_toe_pci, and set properties
  set axis_data_fifo_toe_pci [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_data_fifo_toe_pci ]
  set_property CONFIG.IS_ACLK_ASYNC {1} $axis_data_fifo_toe_pci


  # Create instance: cms_subsystem_0, and set properties
  set cms_subsystem_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:cms_subsystem:4.0 cms_subsystem_0 ]

  # Create instance: proc_sys_reset_50, and set properties
  set proc_sys_reset_50 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_50 ]

  # Create instance: route_controller_0, and set properties
  set route_controller_0 [ create_bd_cell -type ip -vlnv user.org:user:route_controller:1.0 route_controller_0 ]
  set_property -dict [list \
    CONFIG.BURST_BITS {6} \
    CONFIG.ENABLE_MULTI_CONTROLLER {1} \
  ] $route_controller_0


  # Create instance: route_controller_1, and set properties
  set route_controller_1 [ create_bd_cell -type ip -vlnv user.org:user:route_controller:1.0 route_controller_1 ]
  set_property -dict [list \
    CONFIG.BURST_BITS {6} \
    CONFIG.ENABLE_MULTI_CONTROLLER {1} \
    CONFIG.SELF_DEST {1} \
  ] $route_controller_1


  # Create instance: vio_0, and set properties
  set vio_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:vio:3.0 vio_0 ]
  set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN {0} \
    CONFIG.C_NUM_PROBE_OUT {2} \
    CONFIG.C_PROBE_OUT1_INIT_VAL {0x1} \
  ] $vio_0


  # Create instance: nop_st_wrapper_0, and set properties
  set block_name nop_st_wrapper
  set block_cell_name nop_st_wrapper_0
  if { [catch {set nop_st_wrapper_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $nop_st_wrapper_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property CONFIG.BURST_BITS {6} $nop_st_wrapper_0


  # Create instance: reg_slice_toe_cmd, and set properties
  set reg_slice_toe_cmd [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 reg_slice_toe_cmd ]
  set_property CONFIG.REG_CONFIG {12} $reg_slice_toe_cmd


  # Create instance: reg_slice_toe_rsp, and set properties
  set reg_slice_toe_rsp [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 reg_slice_toe_rsp ]
  set_property CONFIG.REG_CONFIG {12} $reg_slice_toe_rsp


  # Create instance: reg_slice_toe_rx_data, and set properties
  set reg_slice_toe_rx_data [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 reg_slice_toe_rx_data ]
  set_property CONFIG.REG_CONFIG {12} $reg_slice_toe_rx_data


  # Create instance: reg_slice_toe_tx_data, and set properties
  set reg_slice_toe_tx_data [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 reg_slice_toe_tx_data ]
  set_property CONFIG.REG_CONFIG {12} $reg_slice_toe_tx_data


  # Create instance: clk_wiz_toe_tx, and set properties
  set clk_wiz_toe_tx [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_toe_tx ]
  set_property -dict [list \
    CONFIG.CLKOUT1_JITTER {77.156} \
    CONFIG.CLKOUT1_PHASE_ERROR {72.826} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {322.266} \
    CONFIG.CLKOUT2_JITTER {134.506} \
    CONFIG.CLKOUT2_PHASE_ERROR {154.678} \
    CONFIG.CLKOUT2_USED {false} \
    CONFIG.CLKOUT3_JITTER {153.164} \
    CONFIG.CLKOUT3_PHASE_ERROR {154.678} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {50} \
    CONFIG.CLKOUT3_USED {false} \
    CONFIG.CLK_OUT1_PORT {toe322} \
    CONFIG.CLK_OUT2_PORT {sys100} \
    CONFIG.CLK_OUT3_PORT {sys50} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {3.750} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {3.750} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {1} \
    CONFIG.MMCM_CLKOUT2_DIVIDE {1} \
    CONFIG.MMCM_DIVCLK_DIVIDE {1} \
    CONFIG.NUM_OUT_CLKS {1} \
    CONFIG.USE_RESET {false} \
  ] $clk_wiz_toe_tx


  # Create instance: clk_wiz_toe_rx, and set properties
  set clk_wiz_toe_rx [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_toe_rx ]
  set_property -dict [list \
    CONFIG.CLKOUT1_JITTER {77.156} \
    CONFIG.CLKOUT1_PHASE_ERROR {72.826} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {322.266} \
    CONFIG.CLKOUT2_JITTER {134.506} \
    CONFIG.CLKOUT2_PHASE_ERROR {154.678} \
    CONFIG.CLKOUT2_USED {false} \
    CONFIG.CLKOUT3_JITTER {153.164} \
    CONFIG.CLKOUT3_PHASE_ERROR {154.678} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT3_USED {false} \
    CONFIG.CLK_OUT1_PORT {toe322} \
    CONFIG.CLK_OUT2_PORT {clk_out2} \
    CONFIG.CLK_OUT3_PORT {clk_out3} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {3.750} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {3.750} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {1} \
    CONFIG.MMCM_CLKOUT2_DIVIDE {1} \
    CONFIG.MMCM_DIVCLK_DIVIDE {1} \
    CONFIG.NUM_OUT_CLKS {1} \
    CONFIG.USE_RESET {false} \
  ] $clk_wiz_toe_rx


  # Create instance: system_ila_2, and set properties
  set system_ila_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_2 ]
  set_property -dict [list \
    CONFIG.C_DATA_DEPTH {1024} \
    CONFIG.C_INPUT_PIPE_STAGES {2} \
    CONFIG.C_MON_TYPE {MIX} \
    CONFIG.C_NUM_MONITOR_SLOTS {12} \
    CONFIG.C_NUM_OF_PROBES {5} \
    CONFIG.C_PROBE0_TYPE {1} \
    CONFIG.C_PROBE1_TYPE {0} \
    CONFIG.C_PROBE2_TYPE {1} \
    CONFIG.C_PROBE3_TYPE {1} \
    CONFIG.C_PROBE4_TYPE {1} \
    CONFIG.C_SLOT {0} \
    CONFIG.C_SLOT_0_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_10_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_11_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_12_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_13_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_14_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_1_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_2_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_3_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_4_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_5_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_6_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_7_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_8_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_9_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
  ] $system_ila_2


  # Create instance: toe_network_0, and set properties
  set toe_network_0 [ create_bd_cell -type ip -vlnv user.org:user:toe_network:1.0 toe_network_0 ]

  # Create instance: toe_ctrl_0, and set properties
  set toe_ctrl_0 [ create_bd_cell -type ip -vlnv user.org:user:toe_ctrl:1.0 toe_ctrl_0 ]
  set_property CONFIG.SESSION_NUM_LOG {10} $toe_ctrl_0

  # Create interface connections
  connect_bd_intf_net -intf_net C0_SYS_CLK_0_1 [get_bd_intf_ports C0_SYS_CLK_0] [get_bd_intf_pins ddr4_2/C0_SYS_CLK]
  connect_bd_intf_net -intf_net CLK_IN_D_0_1 [get_bd_intf_ports CLK_IN_D_0] [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]
  connect_bd_intf_net -intf_net axi_bram_ctrl_0_BRAM_PORTA [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTA]
  connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M01_AXI [get_bd_intf_pins axi_interconnect_0/M01_AXI] [get_bd_intf_pins stream_engine_tx/reg]
  connect_bd_intf_net -intf_net axi_interconnect_0_M02_AXI [get_bd_intf_pins axi_interconnect_0/M02_AXI] [get_bd_intf_pins stream_engine_rx/reg]
  connect_bd_intf_net -intf_net axi_interconnect_0_M03_AXI [get_bd_intf_pins axi_interconnect_0/M03_AXI] [get_bd_intf_pins route_controller_0/cfg]
  connect_bd_intf_net -intf_net axi_interconnect_0_M04_AXI [get_bd_intf_pins axi_interconnect_0/M04_AXI] [get_bd_intf_pins xdma_0/S_AXI_LITE]
  connect_bd_intf_net -intf_net axi_interconnect_0_M05_AXI [get_bd_intf_pins axi_interconnect_0/M05_AXI] [get_bd_intf_pins cmac_usplus_0/s_axi]
  connect_bd_intf_net -intf_net axi_interconnect_0_M06_AXI [get_bd_intf_pins axi_interconnect_0/M06_AXI] [get_bd_intf_pins ddr4_2/C0_DDR4_S_AXI_CTRL]
  connect_bd_intf_net -intf_net axi_interconnect_0_M07_AXI [get_bd_intf_pins axi_interconnect_0/M07_AXI] [get_bd_intf_pins toe_ctrl_0/axil]
  connect_bd_intf_net -intf_net axi_interconnect_0_M08_AXI [get_bd_intf_pins axi_interconnect_0/M08_AXI] [get_bd_intf_pins toe_network_0/axil]
  connect_bd_intf_net -intf_net axi_interconnect_0_M09_AXI [get_bd_intf_pins axi_interconnect_0/M09_AXI] [get_bd_intf_pins route_controller_1/cfg]
  connect_bd_intf_net -intf_net axi_interconnect_0_M10_AXI [get_bd_intf_pins axi_interconnect_0/M10_AXI] [get_bd_intf_pins cms_subsystem_0/s_axi_ctrl]
  connect_bd_intf_net -intf_net axis_clock_converter_pci_toe_0_M_AXIS [get_bd_intf_pins axis_clock_converter_pci_toe_0/M_AXIS] [get_bd_intf_pins route_controller_1/in_frame_header_consume]
connect_bd_intf_net -intf_net [get_bd_intf_nets axis_clock_converter_pci_toe_0_M_AXIS] [get_bd_intf_pins axis_clock_converter_pci_toe_0/M_AXIS] [get_bd_intf_pins system_ila_2/SLOT_6_AXIS]
  connect_bd_intf_net -intf_net axis_clock_converter_pci_toe_1_M_AXIS [get_bd_intf_pins axis_clock_converter_pci_toe_1/M_AXIS] [get_bd_intf_pins route_controller_1/out_frame_complete]
connect_bd_intf_net -intf_net [get_bd_intf_nets axis_clock_converter_pci_toe_1_M_AXIS] [get_bd_intf_pins axis_clock_converter_pci_toe_1/M_AXIS] [get_bd_intf_pins system_ila_2/SLOT_8_AXIS]
  connect_bd_intf_net -intf_net axis_clock_converter_pci_toe_2_M_AXIS [get_bd_intf_pins axis_clock_converter_pci_toe_2/M_AXIS] [get_bd_intf_pins route_controller_1/out_frame_out_req]
  connect_bd_intf_net -intf_net axis_clock_converter_pci_toe_3_M_AXIS [get_bd_intf_pins axis_clock_converter_pci_toe_3/M_AXIS] [get_bd_intf_pins route_controller_1/in_frame_out_ready]
  connect_bd_intf_net -intf_net axis_clock_converter_pci_toe_4_M_AXIS [get_bd_intf_pins axis_clock_converter_pci_toe_4/M_AXIS] [get_bd_intf_pins route_controller_1/in_frame_consume]
connect_bd_intf_net -intf_net [get_bd_intf_nets axis_clock_converter_pci_toe_4_M_AXIS] [get_bd_intf_pins axis_clock_converter_pci_toe_4/M_AXIS] [get_bd_intf_pins system_ila_2/SLOT_7_AXIS]
  connect_bd_intf_net -intf_net axis_clock_converter_toe_pci_0_M_AXIS [get_bd_intf_pins axis_clock_converter_toe_pci_0/M_AXIS] [get_bd_intf_pins if_header_switch/S01_AXIS]
  connect_bd_intf_net -intf_net axis_clock_converter_toe_pci_1_M_AXIS [get_bd_intf_pins axis_clock_converter_toe_pci_1/M_AXIS] [get_bd_intf_pins of_header_switch/S01_AXIS]
  connect_bd_intf_net -intf_net axis_clock_converter_toe_pci_2_M_AXIS [get_bd_intf_pins axis_clock_converter_toe_pci_2/M_AXIS] [get_bd_intf_pins axis_switch_frame_req/S00_AXIS]
  connect_bd_intf_net -intf_net axis_clock_converter_toe_pci_3_M_AXIS [get_bd_intf_pins axis_clock_converter_toe_pci_3/M_AXIS] [get_bd_intf_pins axis_switch_frame_ready/S00_AXIS]
  connect_bd_intf_net -intf_net axis_data_fifo_0_M_AXIS [get_bd_intf_pins axis_data_fifo_0/M_AXIS] [get_bd_intf_pins route_controller_1/user_st_in]
connect_bd_intf_net -intf_net [get_bd_intf_nets axis_data_fifo_0_M_AXIS] [get_bd_intf_pins axis_data_fifo_0/M_AXIS] [get_bd_intf_pins system_ila_2/SLOT_10_AXIS]
  connect_bd_intf_net -intf_net axis_data_fifo_nop_in_M_AXIS [get_bd_intf_pins axis_data_fifo_nop_in/M_AXIS] [get_bd_intf_pins nop_st_wrapper_0/in_0]
  connect_bd_intf_net -intf_net axis_data_fifo_nop_out_M_AXIS [get_bd_intf_pins axis_data_fifo_nop_out/M_AXIS] [get_bd_intf_pins odata_switch/S00_AXIS]
  connect_bd_intf_net -intf_net axis_data_fifo_toe_pci_M_AXIS [get_bd_intf_pins axis_data_fifo_toe_pci/M_AXIS] [get_bd_intf_pins idata_switch/S01_AXIS]
  connect_bd_intf_net -intf_net axis_switch_frame_ready_M00_AXIS [get_bd_intf_pins axis_switch_frame_ready/M00_AXIS] [get_bd_intf_pins route_controller_0/in_frame_out_ready]
  connect_bd_intf_net -intf_net axis_switch_frame_ready_M01_AXIS [get_bd_intf_pins axis_clock_converter_pci_toe_3/S_AXIS] [get_bd_intf_pins axis_switch_frame_ready/M01_AXIS]
  connect_bd_intf_net -intf_net axis_switch_frame_req_M00_AXIS [get_bd_intf_pins axis_switch_frame_req/M00_AXIS] [get_bd_intf_pins route_controller_0/out_frame_out_req]
  connect_bd_intf_net -intf_net axis_switch_frame_req_M01_AXIS [get_bd_intf_pins axis_clock_converter_pci_toe_2/S_AXIS] [get_bd_intf_pins axis_switch_frame_req/M01_AXIS]
  connect_bd_intf_net -intf_net cmac_usplus_0_axis_rx [get_bd_intf_pins cmac_usplus_0/axis_rx] [get_bd_intf_pins toe_network_0/mac_rx_data]
  connect_bd_intf_net -intf_net cmac_usplus_0_gt_serial_port [get_bd_intf_ports gt_serial_port_0] [get_bd_intf_pins cmac_usplus_0/gt_serial_port]
  connect_bd_intf_net -intf_net cms_subsystem_0_satellite_uart [get_bd_intf_ports satellite_uart_0] [get_bd_intf_pins cms_subsystem_0/satellite_uart]
  connect_bd_intf_net -intf_net ddr4_2_C0_DDR4 [get_bd_intf_ports C0_DDR4_0] [get_bd_intf_pins ddr4_2/C0_DDR4]
  connect_bd_intf_net -intf_net gt_ref_clk_0_1 [get_bd_intf_ports gt_ref_clk_0] [get_bd_intf_pins cmac_usplus_0/gt_ref_clk]
  connect_bd_intf_net -intf_net idata_switch_M00_AXIS [get_bd_intf_pins idata_switch/M00_AXIS] [get_bd_intf_pins axis_data_fifo_nop_in/S_AXIS]
  connect_bd_intf_net -intf_net idata_switch_M01_AXIS [get_bd_intf_pins idata_switch/M01_AXIS] [get_bd_intf_pins idata_dkulid_sink/in]
  connect_bd_intf_net -intf_net if_consume_switch_M00_AXIS [get_bd_intf_pins if_consume_switch/M00_AXIS] [get_bd_intf_pins route_controller_0/in_frame_consume]
connect_bd_intf_net -intf_net [get_bd_intf_nets if_consume_switch_M00_AXIS] [get_bd_intf_pins if_consume_switch/M00_AXIS] [get_bd_intf_pins system_ila_iframe/SLOT_2_AXIS]
  connect_bd_intf_net -intf_net if_consume_switch_M01_AXIS [get_bd_intf_pins if_consume_switch/M01_AXIS] [get_bd_intf_pins if_consume_ddu_sink/in]
  connect_bd_intf_net -intf_net if_consume_switch_M02_AXIS [get_bd_intf_pins axis_clock_converter_pci_toe_4/S_AXIS] [get_bd_intf_pins if_consume_switch/M02_AXIS]
  connect_bd_intf_net -intf_net if_header_consume_switch_M00_AXIS [get_bd_intf_pins if_header_consume_switch/M00_AXIS] [get_bd_intf_pins route_controller_0/in_frame_header_consume]
connect_bd_intf_net -intf_net [get_bd_intf_nets if_header_consume_switch_M00_AXIS] [get_bd_intf_pins if_header_consume_switch/M00_AXIS] [get_bd_intf_pins system_ila_iframe/SLOT_3_AXIS]
  connect_bd_intf_net -intf_net if_header_consume_switch_M01_AXIS [get_bd_intf_pins if_header_consume_switch/M01_AXIS] [get_bd_intf_pins if_header_consume_du_sink/in]
  connect_bd_intf_net -intf_net if_header_consume_switch_M02_AXIS [get_bd_intf_pins axis_clock_converter_pci_toe_0/S_AXIS] [get_bd_intf_pins if_header_consume_switch/M02_AXIS]
  connect_bd_intf_net -intf_net if_header_switch_M00_AXIS [get_bd_intf_pins if_header_switch/M00_AXIS] [get_bd_intf_pins nop_st_wrapper_0/in_frame_header_0]
connect_bd_intf_net -intf_net [get_bd_intf_nets if_header_switch_M00_AXIS] [get_bd_intf_pins if_header_switch/M00_AXIS] [get_bd_intf_pins system_ila_iframe/SLOT_6_AXIS]
  connect_bd_intf_net -intf_net if_header_switch_M01_AXIS [get_bd_intf_pins if_header_switch/M01_AXIS] [get_bd_intf_pins if_header_ddu_sink/in]
  connect_bd_intf_net -intf_net nop_st_wrapper_0_in_frame_consume_0 [get_bd_intf_pins nop_st_wrapper_0/in_frame_consume_0] [get_bd_intf_pins if_consume_switch/S00_AXIS]
connect_bd_intf_net -intf_net [get_bd_intf_nets nop_st_wrapper_0_in_frame_consume_0] [get_bd_intf_pins nop_st_wrapper_0/in_frame_consume_0] [get_bd_intf_pins system_ila_iframe/SLOT_8_AXIS]
  connect_bd_intf_net -intf_net nop_st_wrapper_0_in_frame_header_consume_0 [get_bd_intf_pins nop_st_wrapper_0/in_frame_header_consume_0] [get_bd_intf_pins if_header_consume_switch/S00_AXIS]
connect_bd_intf_net -intf_net [get_bd_intf_nets nop_st_wrapper_0_in_frame_header_consume_0] [get_bd_intf_pins nop_st_wrapper_0/in_frame_header_consume_0] [get_bd_intf_pins system_ila_iframe/SLOT_7_AXIS]
  connect_bd_intf_net -intf_net nop_st_wrapper_0_out_0 [get_bd_intf_pins nop_st_wrapper_0/out_0] [get_bd_intf_pins axis_data_fifo_nop_out/S_AXIS]
connect_bd_intf_net -intf_net [get_bd_intf_nets nop_st_wrapper_0_out_0] [get_bd_intf_pins nop_st_wrapper_0/out_0] [get_bd_intf_pins system_ila_oframe/SLOT_6_AXIS]
  connect_bd_intf_net -intf_net nop_st_wrapper_0_out_frame_complete_0 [get_bd_intf_pins nop_st_wrapper_0/out_frame_complete_0] [get_bd_intf_pins of_complete_switch/S00_AXIS]
connect_bd_intf_net -intf_net [get_bd_intf_nets nop_st_wrapper_0_out_frame_complete_0] [get_bd_intf_pins nop_st_wrapper_0/out_frame_complete_0] [get_bd_intf_pins system_ila_oframe/SLOT_4_AXIS]
  connect_bd_intf_net -intf_net odata_switch_M00_AXIS [get_bd_intf_pins odata_switch/M00_AXIS] [get_bd_intf_pins route_controller_0/user_st_in]
  connect_bd_intf_net -intf_net odata_switch_M01_AXIS [get_bd_intf_pins odata_switch/M01_AXIS] [get_bd_intf_pins odata_dkuld_sink/in]
  connect_bd_intf_net -intf_net odata_switch_M02_AXIS [get_bd_intf_pins axis_data_fifo_0/S_AXIS] [get_bd_intf_pins odata_switch/M02_AXIS]
  connect_bd_intf_net -intf_net of_complete_switch_M00_AXIS [get_bd_intf_pins of_complete_switch/M00_AXIS] [get_bd_intf_pins route_controller_0/out_frame_complete]
connect_bd_intf_net -intf_net [get_bd_intf_nets of_complete_switch_M00_AXIS] [get_bd_intf_pins of_complete_switch/M00_AXIS] [get_bd_intf_pins system_ila_oframe/SLOT_2_AXIS]
  connect_bd_intf_net -intf_net of_complete_switch_M01_AXIS [get_bd_intf_pins of_complete_switch/M01_AXIS] [get_bd_intf_pins of_complete_ddu_sink/in]
  connect_bd_intf_net -intf_net of_complete_switch_M02_AXIS [get_bd_intf_pins axis_clock_converter_pci_toe_1/S_AXIS] [get_bd_intf_pins of_complete_switch/M02_AXIS]
  connect_bd_intf_net -intf_net of_header_switch_M00_AXIS [get_bd_intf_pins of_header_switch/M00_AXIS] [get_bd_intf_pins nop_st_wrapper_0/out_frame_header_0]
connect_bd_intf_net -intf_net [get_bd_intf_nets of_header_switch_M00_AXIS] [get_bd_intf_pins of_header_switch/M00_AXIS] [get_bd_intf_pins system_ila_oframe/SLOT_5_AXIS]
  connect_bd_intf_net -intf_net of_header_switch_M01_AXIS [get_bd_intf_pins of_header_switch/M01_AXIS] [get_bd_intf_pins of_header_ddu_sink/in]
  connect_bd_intf_net -intf_net reg_slice_toe_cmd_M_AXIS [get_bd_intf_pins reg_slice_toe_cmd/M_AXIS] [get_bd_intf_pins toe_network_0/tcp_cmd]
  connect_bd_intf_net -intf_net reg_slice_toe_rsp_M_AXIS [get_bd_intf_pins reg_slice_toe_rsp/M_AXIS] [get_bd_intf_pins toe_ctrl_0/tx_toe_rsp]
  connect_bd_intf_net -intf_net reg_slice_toe_rx_data_M_AXIS [get_bd_intf_pins reg_slice_toe_rx_data/M_AXIS] [get_bd_intf_pins toe_ctrl_0/rx_toe]
  connect_bd_intf_net -intf_net reg_slice_toe_tx_data_M_AXIS [get_bd_intf_pins reg_slice_toe_tx_data/M_AXIS] [get_bd_intf_pins toe_network_0/tcp_tx_data]
  connect_bd_intf_net -intf_net route_controller_0_in_frame_completion [get_bd_intf_pins route_controller_0/in_frame_completion] [get_bd_intf_pins stream_engine_rx/stream_cpl_update]
connect_bd_intf_net -intf_net [get_bd_intf_nets route_controller_0_in_frame_completion] [get_bd_intf_pins route_controller_0/in_frame_completion] [get_bd_intf_pins system_ila_iframe/SLOT_1_AXIS]
  connect_bd_intf_net -intf_net route_controller_0_in_frame_header [get_bd_intf_pins route_controller_0/in_frame_header] [get_bd_intf_pins if_header_switch/S00_AXIS]
connect_bd_intf_net -intf_net [get_bd_intf_nets route_controller_0_in_frame_header] [get_bd_intf_pins route_controller_0/in_frame_header] [get_bd_intf_pins system_ila_iframe/SLOT_0_AXIS]
  connect_bd_intf_net -intf_net route_controller_0_in_frame_info_ready [get_bd_intf_pins route_controller_0/in_frame_info_ready] [get_bd_intf_pins stream_engine_rx/frame_info]
connect_bd_intf_net -intf_net [get_bd_intf_nets route_controller_0_in_frame_info_ready] [get_bd_intf_pins route_controller_0/in_frame_info_ready] [get_bd_intf_pins system_ila_iframe/SLOT_5_AXIS]
  connect_bd_intf_net -intf_net route_controller_0_in_frame_out_req [get_bd_intf_pins axis_switch_frame_req/S01_AXIS] [get_bd_intf_pins route_controller_0/in_frame_out_req]
  connect_bd_intf_net -intf_net route_controller_0_out_frame_header [get_bd_intf_pins route_controller_0/out_frame_header] [get_bd_intf_pins of_header_switch/S00_AXIS]
connect_bd_intf_net -intf_net [get_bd_intf_nets route_controller_0_out_frame_header] [get_bd_intf_pins route_controller_0/out_frame_header] [get_bd_intf_pins system_ila_oframe/SLOT_0_AXIS]
  connect_bd_intf_net -intf_net route_controller_0_out_frame_info [get_bd_intf_pins route_controller_0/out_frame_info] [get_bd_intf_pins stream_engine_tx/frame_info]
connect_bd_intf_net -intf_net [get_bd_intf_nets route_controller_0_out_frame_info] [get_bd_intf_pins route_controller_0/out_frame_info] [get_bd_intf_pins system_ila_oframe/SLOT_3_AXIS]
  connect_bd_intf_net -intf_net route_controller_0_out_frame_out_ready [get_bd_intf_pins axis_switch_frame_ready/S01_AXIS] [get_bd_intf_pins route_controller_0/out_frame_out_ready]
  connect_bd_intf_net -intf_net route_controller_0_st_out [get_bd_intf_pins route_controller_0/st_out] [get_bd_intf_pins stream_engine_tx/tx_in]
  connect_bd_intf_net -intf_net route_controller_0_user_st_out [get_bd_intf_pins route_controller_0/user_st_out] [get_bd_intf_pins idata_switch/S00_AXIS]
  connect_bd_intf_net -intf_net route_controller_1_in_frame_header [get_bd_intf_pins route_controller_1/in_frame_header] [get_bd_intf_pins axis_clock_converter_toe_pci_0/S_AXIS]
connect_bd_intf_net -intf_net [get_bd_intf_nets route_controller_1_in_frame_header] [get_bd_intf_pins route_controller_1/in_frame_header] [get_bd_intf_pins system_ila_2/SLOT_4_AXIS]
  connect_bd_intf_net -intf_net route_controller_1_in_frame_info_ready [get_bd_intf_pins route_controller_1/in_frame_info_ready] [get_bd_intf_pins toe_ctrl_0/rx_frame_info]
connect_bd_intf_net -intf_net [get_bd_intf_nets route_controller_1_in_frame_info_ready] [get_bd_intf_pins route_controller_1/in_frame_info_ready] [get_bd_intf_pins system_ila_2/SLOT_2_AXIS]
  connect_bd_intf_net -intf_net route_controller_1_in_frame_out_req [get_bd_intf_pins route_controller_1/in_frame_out_req] [get_bd_intf_pins axis_clock_converter_toe_pci_2/S_AXIS]
  connect_bd_intf_net -intf_net route_controller_1_out_frame_header [get_bd_intf_pins route_controller_1/out_frame_header] [get_bd_intf_pins axis_clock_converter_toe_pci_1/S_AXIS]
connect_bd_intf_net -intf_net [get_bd_intf_nets route_controller_1_out_frame_header] [get_bd_intf_pins route_controller_1/out_frame_header] [get_bd_intf_pins system_ila_2/SLOT_5_AXIS]
  connect_bd_intf_net -intf_net route_controller_1_out_frame_info [get_bd_intf_pins route_controller_1/out_frame_info] [get_bd_intf_pins toe_ctrl_0/tx_frame_info]
connect_bd_intf_net -intf_net [get_bd_intf_nets route_controller_1_out_frame_info] [get_bd_intf_pins route_controller_1/out_frame_info] [get_bd_intf_pins system_ila_2/SLOT_3_AXIS]
  connect_bd_intf_net -intf_net route_controller_1_out_frame_out_ready [get_bd_intf_pins route_controller_1/out_frame_out_ready] [get_bd_intf_pins axis_clock_converter_toe_pci_3/S_AXIS]
  connect_bd_intf_net -intf_net route_controller_1_st_out [get_bd_intf_pins route_controller_1/st_out] [get_bd_intf_pins toe_ctrl_0/tx_in]
  connect_bd_intf_net -intf_net route_controller_1_user_st_out [get_bd_intf_pins route_controller_1/user_st_out] [get_bd_intf_pins axis_data_fifo_toe_pci/S_AXIS]
connect_bd_intf_net -intf_net [get_bd_intf_nets route_controller_1_user_st_out] [get_bd_intf_pins route_controller_1/user_st_out] [get_bd_intf_pins system_ila_2/SLOT_11_AXIS]
  connect_bd_intf_net -intf_net stream_engine_rx_data_desc [get_bd_intf_pins stream_engine_rx/data_desc] [get_bd_intf_pins xdma_0/dsc_bypass_h2c_2]
  connect_bd_intf_net -intf_net stream_engine_rx_frame_info_out [get_bd_intf_pins route_controller_0/in_frame_info] [get_bd_intf_pins stream_engine_rx/frame_info_out]
connect_bd_intf_net -intf_net [get_bd_intf_nets stream_engine_rx_frame_info_out] [get_bd_intf_pins route_controller_0/in_frame_info] [get_bd_intf_pins system_ila_iframe/SLOT_4_AXIS]
  connect_bd_intf_net -intf_net stream_engine_rx_rd_desc [get_bd_intf_pins stream_engine_rx/rd_desc] [get_bd_intf_pins xdma_0/dsc_bypass_h2c_1]
  connect_bd_intf_net -intf_net stream_engine_rx_rx_out [get_bd_intf_pins route_controller_0/st_in] [get_bd_intf_pins stream_engine_rx/rx_out]
  connect_bd_intf_net -intf_net stream_engine_rx_wr [get_bd_intf_pins stream_engine_rx/wr] [get_bd_intf_pins xdma_0/S_AXIS_C2H_1]
  connect_bd_intf_net -intf_net stream_engine_rx_wr_desc [get_bd_intf_pins stream_engine_rx/wr_desc] [get_bd_intf_pins xdma_0/dsc_bypass_c2h_1]
  connect_bd_intf_net -intf_net stream_engine_tx_data_desc [get_bd_intf_pins stream_engine_tx/data_desc] [get_bd_intf_pins xdma_0/dsc_bypass_c2h_2]
  connect_bd_intf_net -intf_net stream_engine_tx_frame_info_out [get_bd_intf_pins stream_engine_tx/frame_info_out] [get_bd_intf_pins route_controller_0/out_buffer_info]
connect_bd_intf_net -intf_net [get_bd_intf_nets stream_engine_tx_frame_info_out] [get_bd_intf_pins stream_engine_tx/frame_info_out] [get_bd_intf_pins system_ila_oframe/SLOT_1_AXIS]
  connect_bd_intf_net -intf_net stream_engine_tx_rd_desc [get_bd_intf_pins stream_engine_tx/rd_desc] [get_bd_intf_pins xdma_0/dsc_bypass_h2c_0]
  connect_bd_intf_net -intf_net stream_engine_tx_tx_out [get_bd_intf_pins stream_engine_tx/tx_out] [get_bd_intf_pins xdma_0/S_AXIS_C2H_2]
  connect_bd_intf_net -intf_net stream_engine_tx_wr [get_bd_intf_pins stream_engine_tx/wr] [get_bd_intf_pins xdma_0/S_AXIS_C2H_0]
  connect_bd_intf_net -intf_net stream_engine_tx_wr_desc [get_bd_intf_pins stream_engine_tx/wr_desc] [get_bd_intf_pins xdma_0/dsc_bypass_c2h_0]
  connect_bd_intf_net -intf_net toe_ctrl_0_rx_frame_info_out [get_bd_intf_pins toe_ctrl_0/rx_frame_info_out] [get_bd_intf_pins route_controller_1/in_frame_info]
connect_bd_intf_net -intf_net [get_bd_intf_nets toe_ctrl_0_rx_frame_info_out] [get_bd_intf_pins toe_ctrl_0/rx_frame_info_out] [get_bd_intf_pins system_ila_2/SLOT_0_AXIS]
  connect_bd_intf_net -intf_net toe_ctrl_0_rx_out [get_bd_intf_pins toe_ctrl_0/rx_out] [get_bd_intf_pins route_controller_1/st_in]
connect_bd_intf_net -intf_net [get_bd_intf_nets toe_ctrl_0_rx_out] [get_bd_intf_pins toe_ctrl_0/rx_out] [get_bd_intf_pins system_ila_2/SLOT_9_AXIS]
  connect_bd_intf_net -intf_net toe_ctrl_0_tx_frame_info_out [get_bd_intf_pins toe_ctrl_0/tx_frame_info_out] [get_bd_intf_pins route_controller_1/out_buffer_info]
connect_bd_intf_net -intf_net [get_bd_intf_nets toe_ctrl_0_tx_frame_info_out] [get_bd_intf_pins toe_ctrl_0/tx_frame_info_out] [get_bd_intf_pins system_ila_2/SLOT_1_AXIS]
  connect_bd_intf_net -intf_net toe_ctrl_0_tx_toe [get_bd_intf_pins toe_ctrl_0/tx_toe] [get_bd_intf_pins reg_slice_toe_tx_data/S_AXIS]
  connect_bd_intf_net -intf_net toe_ctrl_0_tx_toe_cmd [get_bd_intf_pins toe_ctrl_0/tx_toe_cmd] [get_bd_intf_pins reg_slice_toe_cmd/S_AXIS]
  connect_bd_intf_net -intf_net toe_network_0_axi_dram [get_bd_intf_pins toe_network_0/axi_dram] [get_bd_intf_pins ddr4_2/C0_DDR4_S_AXI]
  connect_bd_intf_net -intf_net toe_network_0_mac_tx_data [get_bd_intf_pins toe_network_0/mac_tx_data] [get_bd_intf_pins cmac_usplus_0/axis_tx]
  connect_bd_intf_net -intf_net toe_network_0_tcp_rsp [get_bd_intf_pins toe_network_0/tcp_rsp] [get_bd_intf_pins reg_slice_toe_rsp/S_AXIS]
  connect_bd_intf_net -intf_net toe_network_0_tcp_rx_data [get_bd_intf_pins toe_network_0/tcp_rx_data] [get_bd_intf_pins reg_slice_toe_rx_data/S_AXIS]
  connect_bd_intf_net -intf_net xdma_0_M_AXIS_H2C_0 [get_bd_intf_pins xdma_0/M_AXIS_H2C_0] [get_bd_intf_pins stream_engine_tx/rd]
  connect_bd_intf_net -intf_net xdma_0_M_AXIS_H2C_1 [get_bd_intf_pins xdma_0/M_AXIS_H2C_1] [get_bd_intf_pins stream_engine_rx/rd]
  connect_bd_intf_net -intf_net xdma_0_M_AXIS_H2C_2 [get_bd_intf_pins xdma_0/M_AXIS_H2C_2] [get_bd_intf_pins stream_engine_rx/rx_in]
  connect_bd_intf_net -intf_net xdma_0_M_AXI_BYPASS [get_bd_intf_pins xdma_0/M_AXI_BYPASS] [get_bd_intf_pins stream_engine_rx/axi]
  connect_bd_intf_net -intf_net xdma_0_M_AXI_LITE [get_bd_intf_pins xdma_0/M_AXI_LITE] [get_bd_intf_pins axi_interconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net xdma_0_pcie_mgt [get_bd_intf_ports pcie_mgt_0] [get_bd_intf_pins xdma_0/pcie_mgt]

  # Create port connections
  connect_bd_net -net M05_ARESETN_1 [get_bd_pins proc_sys_reset_100/interconnect_aresetn] [get_bd_pins axi_interconnect_0/M05_ARESETN]
  connect_bd_net -net M10_ARESETN_1 [get_bd_pins proc_sys_reset_50/interconnect_aresetn] [get_bd_pins axi_interconnect_0/M10_ARESETN]
  connect_bd_net -net clk_wiz_toe_clk_out1 [get_bd_pins clk_wiz_toe/toe300] [get_bd_pins proc_sys_reset_toe/slowest_sync_clk] [get_bd_pins axi_interconnect_0/M08_ACLK] [get_bd_pins axi_interconnect_0/M07_ACLK] [get_bd_pins axis_clock_converter_pci_toe_0/m_axis_aclk] [get_bd_pins axis_clock_converter_pci_toe_1/m_axis_aclk] [get_bd_pins axis_clock_converter_pci_toe_2/m_axis_aclk] [get_bd_pins axis_clock_converter_pci_toe_3/m_axis_aclk] [get_bd_pins axis_clock_converter_toe_pci_3/s_axis_aclk] [get_bd_pins axis_clock_converter_toe_pci_2/s_axis_aclk] [get_bd_pins axis_clock_converter_toe_pci_1/s_axis_aclk] [get_bd_pins axis_clock_converter_toe_pci_0/s_axis_aclk] [get_bd_pins axis_clock_converter_pci_toe_4/m_axis_aclk] [get_bd_pins axis_data_fifo_0/m_axis_aclk] [get_bd_pins axi_interconnect_0/M09_ACLK] [get_bd_pins axis_data_fifo_toe_pci/s_axis_aclk] [get_bd_pins route_controller_1/clk] [get_bd_pins reg_slice_toe_cmd/aclk] [get_bd_pins reg_slice_toe_rsp/aclk] [get_bd_pins reg_slice_toe_rx_data/aclk] [get_bd_pins reg_slice_toe_tx_data/aclk] [get_bd_pins system_ila_2/clk] [get_bd_pins toe_network_0/toe_clk] [get_bd_pins toe_ctrl_0/clk]
  connect_bd_net -net clk_wiz_toe_clk_out2 [get_bd_pins clk_wiz_toe/sys100] [get_bd_pins cmac_usplus_0/s_axi_aclk] [get_bd_pins cmac_usplus_0/init_clk] [get_bd_pins cmac_usplus_0/drp_clk] [get_bd_pins axi_interconnect_0/M05_ACLK] [get_bd_pins proc_sys_reset_100/slowest_sync_clk] [get_bd_pins vio_0/clk]
  connect_bd_net -net clk_wiz_toe_locked [get_bd_pins clk_wiz_toe/locked] [get_bd_pins proc_sys_reset_toe/dcm_locked] [get_bd_pins proc_sys_reset_100/dcm_locked] [get_bd_pins proc_sys_reset_50/dcm_locked]
  connect_bd_net -net clk_wiz_toe_rx_locked [get_bd_pins clk_wiz_toe_rx/locked] [get_bd_pins proc_sys_reset_toe_rx/dcm_locked]
  connect_bd_net -net clk_wiz_toe_sys50 [get_bd_pins clk_wiz_toe/sys50] [get_bd_pins cms_subsystem_0/aclk_ctrl] [get_bd_pins proc_sys_reset_50/slowest_sync_clk] [get_bd_pins axi_interconnect_0/M10_ACLK]
  connect_bd_net -net clk_wiz_toe_tx_locked [get_bd_pins clk_wiz_toe_tx/locked] [get_bd_pins proc_sys_reset_toe_tx/dcm_locked]
  connect_bd_net -net cmac_usplus_0_gt_rxusrclk2 [get_bd_pins cmac_usplus_0/gt_rxusrclk2] [get_bd_pins cmac_usplus_0/rx_clk] [get_bd_pins proc_sys_reset_toe_rx/slowest_sync_clk] [get_bd_pins clk_wiz_toe_rx/clk_in1] [get_bd_pins toe_network_0/mac_rx_clk]
  connect_bd_net -net cmac_usplus_0_gt_txusrclk2 [get_bd_pins cmac_usplus_0/gt_txusrclk2] [get_bd_pins proc_sys_reset_toe_tx/slowest_sync_clk] [get_bd_pins clk_wiz_toe_tx/clk_in1] [get_bd_pins toe_network_0/mac_tx_clk]
  connect_bd_net -net ddr4_2_c0_ddr4_ui_clk [get_bd_pins ddr4_2/c0_ddr4_ui_clk] [get_bd_pins axi_interconnect_0/M06_ACLK] [get_bd_pins proc_sys_reset_ddr2/slowest_sync_clk] [get_bd_pins toe_network_0/dram_clk]
  connect_bd_net -net ddr4_2_c0_ddr4_ui_clk_sync_rst [get_bd_pins ddr4_2/c0_ddr4_ui_clk_sync_rst] [get_bd_pins proc_sys_reset_ddr2/ext_reset_in]
  connect_bd_net -net proc_sys_reset_0_interconnect_aresetn [get_bd_pins proc_sys_reset_0/interconnect_aresetn] [get_bd_pins axi_interconnect_0/M03_ARESETN] [get_bd_pins axi_interconnect_0/M02_ARESETN] [get_bd_pins axi_interconnect_0/M01_ARESETN] [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_pins axi_interconnect_0/S00_ARESETN] [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins if_header_switch/aresetn] [get_bd_pins of_header_switch/aresetn] [get_bd_pins idata_switch/aresetn] [get_bd_pins if_header_consume_switch/aresetn] [get_bd_pins odata_switch/aresetn] [get_bd_pins if_consume_switch/aresetn] [get_bd_pins of_complete_switch/aresetn] [get_bd_pins axi_interconnect_0/M04_ARESETN] [get_bd_pins axis_clock_converter_pci_toe_2/s_axis_aresetn] [get_bd_pins axis_clock_converter_pci_toe_3/s_axis_aresetn] [get_bd_pins axis_clock_converter_pci_toe_1/s_axis_aresetn] [get_bd_pins axis_clock_converter_pci_toe_0/s_axis_aresetn] [get_bd_pins axis_clock_converter_toe_pci_3/m_axis_aresetn] [get_bd_pins axis_clock_converter_toe_pci_2/m_axis_aresetn] [get_bd_pins axis_clock_converter_toe_pci_1/m_axis_aresetn] [get_bd_pins axis_clock_converter_toe_pci_0/m_axis_aresetn] [get_bd_pins axis_switch_frame_req/aresetn] [get_bd_pins axis_switch_frame_ready/aresetn] [get_bd_pins axis_clock_converter_pci_toe_4/s_axis_aresetn] [get_bd_pins axis_data_fifo_0/s_axis_aresetn]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] [get_bd_pins system_ila_iframe/resetn] [get_bd_pins system_ila_oframe/resetn] [get_bd_pins axis_data_fifo_nop_in/s_axis_aresetn] [get_bd_pins axis_data_fifo_nop_out/s_axis_aresetn] [get_bd_pins stream_engine_rx/resetn] [get_bd_pins stream_engine_tx/resetn] [get_bd_pins route_controller_0/resetn] [get_bd_pins nop_st_wrapper_0/resetn]
  connect_bd_net -net proc_sys_reset_100_peripheral_reset [get_bd_pins proc_sys_reset_100/peripheral_reset] [get_bd_pins cmac_usplus_0/s_axi_sreset] [get_bd_pins cmac_usplus_0/sys_reset] [get_bd_pins cmac_usplus_0/core_drp_reset]
  connect_bd_net -net proc_sys_reset_1_interconnect_aresetn [get_bd_pins proc_sys_reset_toe/interconnect_aresetn] [get_bd_pins axi_interconnect_0/M08_ARESETN] [get_bd_pins axi_interconnect_0/M07_ARESETN] [get_bd_pins axis_clock_converter_pci_toe_3/m_axis_aresetn] [get_bd_pins axis_clock_converter_pci_toe_2/m_axis_aresetn] [get_bd_pins axis_clock_converter_pci_toe_1/m_axis_aresetn] [get_bd_pins axis_clock_converter_pci_toe_0/m_axis_aresetn] [get_bd_pins axis_clock_converter_toe_pci_0/s_axis_aresetn] [get_bd_pins axis_clock_converter_toe_pci_1/s_axis_aresetn] [get_bd_pins axis_clock_converter_toe_pci_3/s_axis_aresetn] [get_bd_pins axis_clock_converter_toe_pci_2/s_axis_aresetn] [get_bd_pins axis_clock_converter_pci_toe_4/m_axis_aresetn] [get_bd_pins axi_interconnect_0/M09_ARESETN] [get_bd_pins axis_data_fifo_toe_pci/s_axis_aresetn] [get_bd_pins toe_network_0/toe_interconnect_aresetn]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins proc_sys_reset_toe/peripheral_aresetn] [get_bd_pins route_controller_1/resetn] [get_bd_pins reg_slice_toe_cmd/aresetn] [get_bd_pins reg_slice_toe_rsp/aresetn] [get_bd_pins reg_slice_toe_rx_data/aresetn] [get_bd_pins reg_slice_toe_tx_data/aresetn] [get_bd_pins system_ila_2/resetn] [get_bd_pins toe_network_0/toe_aresetn] [get_bd_pins toe_ctrl_0/resetn]
  connect_bd_net -net proc_sys_reset_50_peripheral_aresetn [get_bd_pins proc_sys_reset_50/peripheral_aresetn] [get_bd_pins cms_subsystem_0/aresetn_ctrl]
  connect_bd_net -net proc_sys_reset_ddr2_interconnect_aresetn [get_bd_pins proc_sys_reset_ddr2/interconnect_aresetn] [get_bd_pins axi_interconnect_0/M06_ARESETN] [get_bd_pins toe_network_0/dram_interconnect_aresetn]
  connect_bd_net -net proc_sys_reset_ddr2_peripheral_aresetn [get_bd_pins proc_sys_reset_ddr2/peripheral_aresetn] [get_bd_pins ddr4_2/c0_ddr4_aresetn]
  connect_bd_net -net proc_sys_reset_toe_rx_peripheral_aresetn [get_bd_pins proc_sys_reset_toe_rx/peripheral_aresetn] [get_bd_pins toe_network_0/mac_rx_aresetn]
  connect_bd_net -net proc_sys_reset_toe_rx_peripheral_reset [get_bd_pins proc_sys_reset_toe_rx/peripheral_reset] [get_bd_pins cmac_usplus_0/core_rx_reset]
  connect_bd_net -net proc_sys_reset_toe_tx_peripheral_reset [get_bd_pins proc_sys_reset_toe_tx/peripheral_reset] [get_bd_pins cmac_usplus_0/core_tx_reset]
  connect_bd_net -net route_controller_0_st_out_eop [get_bd_pins route_controller_0/st_out_eop] [get_bd_pins stream_engine_tx/tx_in_eop]
  connect_bd_net -net route_controller_0_st_out_sop [get_bd_pins route_controller_0/st_out_sop] [get_bd_pins stream_engine_tx/tx_in_sop]
  connect_bd_net -net route_controller_1_st_out_burst [get_bd_pins route_controller_1/st_out_burst] [get_bd_pins system_ila_2/probe3] [get_bd_pins toe_ctrl_0/tx_in_burst]
  connect_bd_net -net route_controller_1_st_out_eop [get_bd_pins route_controller_1/st_out_eop] [get_bd_pins system_ila_2/probe1] [get_bd_pins toe_ctrl_0/tx_in_eop]
  connect_bd_net -net route_controller_1_st_out_last_cnt [get_bd_pins route_controller_1/st_out_last_cnt] [get_bd_pins system_ila_2/probe2] [get_bd_pins toe_ctrl_0/tx_in_last_cnt]
  connect_bd_net -net route_controller_1_st_out_sop [get_bd_pins route_controller_1/st_out_sop] [get_bd_pins system_ila_2/probe0] [get_bd_pins toe_ctrl_0/tx_in_sop]
  connect_bd_net -net satellite_gpio_0_1 [get_bd_ports satellite_gpio_0] [get_bd_pins cms_subsystem_0/satellite_gpio]
  connect_bd_net -net stream_engine_rx_rx_out_eof [get_bd_pins stream_engine_rx/rx_out_eof] [get_bd_pins route_controller_0/st_in_eof]
  connect_bd_net -net sys_rst_inv_Res [get_bd_pins sys_rst_inv/Res] [get_bd_pins ddr4_2/sys_rst]
  connect_bd_net -net sys_rst_n_0_1 [get_bd_ports sys_rst_n_0] [get_bd_pins xdma_0/sys_rst_n] [get_bd_pins sys_rst_inv/Op1]
  connect_bd_net -net toe_ctrl_0_rx_out_eof [get_bd_pins toe_ctrl_0/rx_out_eof] [get_bd_pins route_controller_1/st_in_eof] [get_bd_pins system_ila_2/probe4]
  connect_bd_net -net util_ds_buf_0_IBUF_DS_ODIV2 [get_bd_pins util_ds_buf_0/IBUF_DS_ODIV2] [get_bd_pins xdma_0/sys_clk]
  connect_bd_net -net util_ds_buf_0_IBUF_OUT [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins xdma_0/sys_clk_gt]
  connect_bd_net -net vio_0_probe_out0 [get_bd_pins vio_0/probe_out0] [get_bd_ports qsfp0_lp_mode_0]
  connect_bd_net -net vio_0_probe_out1 [get_bd_pins vio_0/probe_out1] [get_bd_ports qsfp0_reset_l_0]
  connect_bd_net -net xdma_0_axi_aclk [get_bd_pins xdma_0/axi_aclk] [get_bd_pins proc_sys_reset_0/slowest_sync_clk] [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins axi_interconnect_0/M01_ACLK] [get_bd_pins axi_interconnect_0/M02_ACLK] [get_bd_pins axi_interconnect_0/M03_ACLK] [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] [get_bd_pins if_header_switch/aclk] [get_bd_pins of_header_switch/aclk] [get_bd_pins idata_switch/aclk] [get_bd_pins if_header_consume_switch/aclk] [get_bd_pins if_consume_switch/aclk] [get_bd_pins of_complete_switch/aclk] [get_bd_pins odata_switch/aclk] [get_bd_pins if_header_ddu_sink/clk] [get_bd_pins of_header_ddu_sink/clk] [get_bd_pins idata_dkulid_sink/clk] [get_bd_pins if_header_consume_du_sink/clk] [get_bd_pins if_consume_ddu_sink/clk] [get_bd_pins of_complete_ddu_sink/clk] [get_bd_pins odata_dkuld_sink/clk] [get_bd_pins axi_interconnect_0/M04_ACLK] [get_bd_pins system_ila_iframe/clk] [get_bd_pins system_ila_oframe/clk] [get_bd_pins axis_data_fifo_nop_in/s_axis_aclk] [get_bd_pins axis_data_fifo_nop_out/s_axis_aclk] [get_bd_pins stream_engine_rx/clk] [get_bd_pins stream_engine_tx/clk] [get_bd_pins axis_clock_converter_pci_toe_0/s_axis_aclk] [get_bd_pins axis_clock_converter_pci_toe_3/s_axis_aclk] [get_bd_pins axis_clock_converter_pci_toe_2/s_axis_aclk] [get_bd_pins axis_clock_converter_pci_toe_1/s_axis_aclk] [get_bd_pins axis_clock_converter_toe_pci_0/m_axis_aclk] [get_bd_pins axis_clock_converter_toe_pci_1/m_axis_aclk] [get_bd_pins axis_clock_converter_toe_pci_3/m_axis_aclk] [get_bd_pins axis_clock_converter_toe_pci_2/m_axis_aclk] [get_bd_pins axis_switch_frame_req/aclk] [get_bd_pins axis_switch_frame_ready/aclk] [get_bd_pins axis_clock_converter_pci_toe_4/s_axis_aclk] [get_bd_pins axis_data_fifo_0/s_axis_aclk] [get_bd_pins axis_data_fifo_toe_pci/m_axis_aclk] [get_bd_pins route_controller_0/clk] [get_bd_pins nop_st_wrapper_0/clk] [get_bd_pins clk_wiz_toe/clk_in1]
  connect_bd_net -net xdma_0_axi_aresetn [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins proc_sys_reset_0/ext_reset_in] [get_bd_pins proc_sys_reset_toe/ext_reset_in] [get_bd_pins proc_sys_reset_toe_rx/ext_reset_in] [get_bd_pins proc_sys_reset_toe_tx/ext_reset_in] [get_bd_pins proc_sys_reset_100/ext_reset_in] [get_bd_pins proc_sys_reset_50/ext_reset_in]
  connect_bd_net -net xdma_0_c2h_sts_0 [get_bd_pins xdma_0/c2h_sts_0] [get_bd_pins stream_engine_tx/wr_sts]
  connect_bd_net -net xdma_0_c2h_sts_1 [get_bd_pins xdma_0/c2h_sts_1] [get_bd_pins stream_engine_rx/wr_sts]
  connect_bd_net -net xdma_0_c2h_sts_2 [get_bd_pins xdma_0/c2h_sts_2] [get_bd_pins stream_engine_tx/data_sts]
  connect_bd_net -net xdma_0_h2c_sts_0 [get_bd_pins xdma_0/h2c_sts_0] [get_bd_pins stream_engine_tx/rd_sts]
  connect_bd_net -net xdma_0_h2c_sts_1 [get_bd_pins xdma_0/h2c_sts_1] [get_bd_pins stream_engine_rx/rd_sts]
  connect_bd_net -net xdma_0_h2c_sts_2 [get_bd_pins xdma_0/h2c_sts_2] [get_bd_pins stream_engine_rx/data_sts]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins xlconstant_0/dout] [get_bd_pins route_controller_0/out_frame_consume_tvalid] [get_bd_pins route_controller_1/out_frame_consume_tvalid]
  connect_bd_net -net xlconstant_0x16_dout [get_bd_pins xlconstant_0x16/dout] [get_bd_pins stream_engine_rx/irq_ack] [get_bd_pins stream_engine_tx/irq_ack]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x00010000000000000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_BYPASS] [get_bd_addr_segs stream_engine_rx/axi/reg0] -force
  assign_bd_address -offset 0x00010000 -range 0x00002000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force
  assign_bd_address -offset 0x00080000 -range 0x00010000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs cmac_usplus_0/s_axi/Reg] -force
  assign_bd_address -offset 0x000C0000 -range 0x00040000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs cms_subsystem_0/s_axi_ctrl/Mem] -force
  assign_bd_address -offset 0x00100000 -range 0x00100000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs ddr4_2/C0_DDR4_MEMORY_MAP_CTRL/C0_REG] -force
  assign_bd_address -offset 0x00040000 -range 0x00010000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs route_controller_0/cfg/reg0] -force
  assign_bd_address -offset 0x00050000 -range 0x00010000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs route_controller_1/cfg/reg0] -force
  assign_bd_address -offset 0x00020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs stream_engine_rx/reg/reg0] -force
  assign_bd_address -offset 0x00030000 -range 0x00010000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs stream_engine_tx/reg/reg0] -force
  assign_bd_address -offset 0x00060000 -range 0x00010000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs toe_ctrl_0/axil/reg0] -force
  assign_bd_address -offset 0x00070000 -range 0x00001000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs toe_network_0/axil/reg0] -force
  assign_bd_address -offset 0x00000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs xdma_0/S_AXI_LITE/CTL0] -force
  assign_bd_address -offset 0x00000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces toe_network_0/axi_dram] [get_bd_addr_segs ddr4_2/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force


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


