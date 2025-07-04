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
# axis_ddu_sink, axis_ddu_sink, axis_ddu_sink, axis_ddu_sink, axis_dkuld_sink, axis_dkulid_sink, axis_du_sink, nop_st_wrapper, axis_ddu_sink, axis_ddu_sink, axis_dkulid_sink, axis_ddu_sink, vec_fp_inc_wrapper, nop_mm_wrapper

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
user.org:user:route_controller:1.0\
xilinx.com:ip:system_ila:1.1\
user.org:user:stream_engine:1.0\
xilinx.com:ip:axis_data_fifo:2.0\
xilinx.com:ip:ddr4:2.2\
xilinx.com:ip:util_vector_logic:2.0\
user.org:user:axi_reader:1.0\
user.org:user:axi_writer:1.0\
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
axis_ddu_sink\
axis_ddu_sink\
axis_dkulid_sink\
axis_ddu_sink\
vec_fp_inc_wrapper\
nop_mm_wrapper\
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

  set C0_SYS_CLK_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 C0_SYS_CLK_0 ]

  set C0_DDR4_1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 C0_DDR4_1 ]

  set C0_SYS_CLK_1 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 C0_SYS_CLK_1 ]


  # Create ports
  set sys_rst_n_0 [ create_bd_port -dir I -type rst sys_rst_n_0 ]

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
    CONFIG.NUM_MI {8} \
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
    CONFIG.M01_AXIS_BASETDEST {0x00000002} \
    CONFIG.M01_AXIS_HIGHTDEST {0x00000007} \
    CONFIG.M02_AXIS_BASETDEST {0x00000008} \
    CONFIG.M02_AXIS_HIGHTDEST {0x00000008} \
    CONFIG.M03_AXIS_BASETDEST {0x00000009} \
    CONFIG.M03_AXIS_HIGHTDEST {0x0000000f} \
    CONFIG.M04_AXIS_BASETDEST {0x00000001} \
    CONFIG.M04_AXIS_HIGHTDEST {0x00000001} \
    CONFIG.NUM_MI {5} \
    CONFIG.NUM_SI {1} \
  ] $if_header_switch


  # Create instance: of_header_switch, and set properties
  set of_header_switch [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 of_header_switch ]
  set_property -dict [list \
    CONFIG.M01_AXIS_BASETDEST {0x00000002} \
    CONFIG.M01_AXIS_HIGHTDEST {0x00000007} \
    CONFIG.M02_AXIS_BASETDEST {0x00000008} \
    CONFIG.M02_AXIS_HIGHTDEST {0x00000008} \
    CONFIG.M03_AXIS_BASETDEST {0x00000009} \
    CONFIG.M03_AXIS_HIGHTDEST {0x0000000f} \
    CONFIG.M04_AXIS_BASETDEST {0x00000001} \
    CONFIG.M04_AXIS_HIGHTDEST {0x00000001} \
    CONFIG.NUM_MI {5} \
    CONFIG.NUM_SI {1} \
  ] $of_header_switch


  # Create instance: idata_switch, and set properties
  set idata_switch [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 idata_switch ]
  set_property -dict [list \
    CONFIG.M01_AXIS_BASETDEST {0x00000002} \
    CONFIG.M01_AXIS_HIGHTDEST {0x00000007} \
    CONFIG.M02_AXIS_BASETDEST {0x00000008} \
    CONFIG.M02_AXIS_HIGHTDEST {0x00000008} \
    CONFIG.M03_AXIS_BASETDEST {0x00000009} \
    CONFIG.M03_AXIS_HIGHTDEST {0x0000000f} \
    CONFIG.M04_AXIS_BASETDEST {0x00000001} \
    CONFIG.M04_AXIS_HIGHTDEST {0x00000001} \
    CONFIG.NUM_MI {5} \
    CONFIG.NUM_SI {1} \
  ] $idata_switch


  # Create instance: if_header_consume_switch, and set properties
  set if_header_consume_switch [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 if_header_consume_switch ]
  set_property -dict [list \
    CONFIG.M00_AXIS_HIGHTDEST {0x00000008} \
    CONFIG.M01_AXIS_BASETDEST {0x00000009} \
    CONFIG.M01_AXIS_HIGHTDEST {0x0000000f} \
    CONFIG.M02_AXIS_BASETDEST {0x00000010} \
    CONFIG.M02_AXIS_HIGHTDEST {0x00000011} \
    CONFIG.NUM_MI {2} \
    CONFIG.NUM_SI {3} \
  ] $if_header_consume_switch


  # Create instance: if_consume_switch, and set properties
  set if_consume_switch [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 if_consume_switch ]
  set_property -dict [list \
    CONFIG.M00_AXIS_HIGHTDEST {0x00000008} \
    CONFIG.M01_AXIS_BASETDEST {0x00000009} \
    CONFIG.M01_AXIS_HIGHTDEST {0x0000000f} \
    CONFIG.NUM_MI {2} \
    CONFIG.NUM_SI {3} \
  ] $if_consume_switch


  # Create instance: of_complete_switch, and set properties
  set of_complete_switch [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 of_complete_switch ]
  set_property -dict [list \
    CONFIG.M00_AXIS_HIGHTDEST {0x00000008} \
    CONFIG.M01_AXIS_BASETDEST {0x00000009} \
    CONFIG.M01_AXIS_HIGHTDEST {0x0000000f} \
    CONFIG.NUM_MI {2} \
    CONFIG.NUM_SI {3} \
  ] $of_complete_switch


  # Create instance: odata_switch, and set properties
  set odata_switch [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 odata_switch ]
  set_property -dict [list \
    CONFIG.ARB_ON_MAX_XFERS {64} \
    CONFIG.ARB_ON_NUM_CYCLES {0} \
    CONFIG.ARB_ON_TLAST {1} \
    CONFIG.HAS_TLAST {1} \
    CONFIG.M00_AXIS_HIGHTDEST {0x00000008} \
    CONFIG.M01_AXIS_BASETDEST {0x00000009} \
    CONFIG.M01_AXIS_HIGHTDEST {0x0000000f} \
    CONFIG.NUM_MI {2} \
    CONFIG.NUM_SI {3} \
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


  # Create instance: route_controller_0, and set properties
  set route_controller_0 [ create_bd_cell -type ip -vlnv user.org:user:route_controller:1.0 route_controller_0 ]
  set_property -dict [list \
    CONFIG.BURST_BITS {6} \
    CONFIG.ENABLE_MULTI_CONTROLLER {0} \
  ] $route_controller_0


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


  # Create instance: system_ila_rx, and set properties
  set system_ila_rx [ create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_rx ]
  set_property -dict [list \
    CONFIG.C_INPUT_PIPE_STAGES {2} \
    CONFIG.C_MON_TYPE {MIX} \
    CONFIG.C_NUM_MONITOR_SLOTS {3} \
    CONFIG.C_NUM_OF_PROBES {3} \
    CONFIG.C_PROBE10_TYPE {1} \
    CONFIG.C_PROBE11_TYPE {1} \
    CONFIG.C_PROBE12_TYPE {1} \
    CONFIG.C_PROBE13_TYPE {1} \
    CONFIG.C_PROBE6_TYPE {1} \
    CONFIG.C_PROBE7_TYPE {1} \
    CONFIG.C_PROBE8_TYPE {1} \
    CONFIG.C_PROBE9_TYPE {1} \
    CONFIG.C_SLOT {0} \
    CONFIG.C_SLOT_0_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_1_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_2_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_3_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
  ] $system_ila_rx


  # Create instance: system_ila_tx, and set properties
  set system_ila_tx [ create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_tx ]
  set_property -dict [list \
    CONFIG.C_INPUT_PIPE_STAGES {2} \
    CONFIG.C_MON_TYPE {MIX} \
    CONFIG.C_NUM_MONITOR_SLOTS {3} \
    CONFIG.C_NUM_OF_PROBES {3} \
    CONFIG.C_PROBE10_TYPE {1} \
    CONFIG.C_PROBE11_TYPE {1} \
    CONFIG.C_PROBE12_TYPE {1} \
    CONFIG.C_PROBE13_TYPE {1} \
    CONFIG.C_PROBE6_TYPE {1} \
    CONFIG.C_PROBE7_TYPE {1} \
    CONFIG.C_PROBE8_TYPE {1} \
    CONFIG.C_PROBE9_TYPE {1} \
    CONFIG.C_SLOT {0} \
    CONFIG.C_SLOT_0_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_1_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_2_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_3_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
  ] $system_ila_tx


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
    CONFIG.C_NUM_MONITOR_SLOTS {6} \
    CONFIG.C_SLOT {0} \
    CONFIG.C_SLOT_0_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_1_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_2_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_3_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_4_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_SLOT_5_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
  ] $system_ila_oframe


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


  # Create instance: axis_data_fifo_nop_in, and set properties
  set axis_data_fifo_nop_in [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_data_fifo_nop_in ]
  set_property CONFIG.FIFO_DEPTH {2048} $axis_data_fifo_nop_in


  # Create instance: axis_data_fifo_nop_out, and set properties
  set axis_data_fifo_nop_out [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_data_fifo_nop_out ]
  set_property CONFIG.FIFO_DEPTH {2048} $axis_data_fifo_nop_out


  # Create instance: ddr4_0, and set properties
  set ddr4_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr4_0 ]
  set_property -dict [list \
    CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
    CONFIG.C0.DDR4_AUTO_AP_COL_A3 {true} \
    CONFIG.C0.DDR4_Mem_Add_Map {ROW_COLUMN_BANK_INTLV} \
    CONFIG.C0.DDR4_SAVE_RESTORE {false} \
    CONFIG.C0.DDR4_SELF_REFRESH {false} \
    CONFIG.C0_CLOCK_BOARD_INTERFACE {default_300mhz_clk0} \
    CONFIG.C0_DDR4_BOARD_INTERFACE {ddr4_sdram_c0} \
    CONFIG.RESET_BOARD_INTERFACE {resetn} \
  ] $ddr4_0


  # Create instance: ddr4_1, and set properties
  set ddr4_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr4_1 ]
  set_property -dict [list \
    CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
    CONFIG.C0.DDR4_AUTO_AP_COL_A3 {true} \
    CONFIG.C0.DDR4_Mem_Add_Map {ROW_COLUMN_BANK_INTLV} \
    CONFIG.C0_CLOCK_BOARD_INTERFACE {default_300mhz_clk1} \
    CONFIG.C0_DDR4_BOARD_INTERFACE {ddr4_sdram_c1} \
    CONFIG.RESET_BOARD_INTERFACE {resetn} \
  ] $ddr4_1


  # Create instance: sys_rst_inv, and set properties
  set sys_rst_inv [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 sys_rst_inv ]
  set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
  ] $sys_rst_inv


  # Create instance: proc_sys_reset_ddr0, and set properties
  set proc_sys_reset_ddr0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_ddr0 ]

  # Create instance: proc_sys_reset_ddr1, and set properties
  set proc_sys_reset_ddr1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_ddr1 ]

  # Create instance: if_header_ddu_sink1, and set properties
  set block_name axis_ddu_sink
  set block_cell_name if_header_ddu_sink1
  if { [catch {set if_header_ddu_sink1 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $if_header_ddu_sink1 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property CONFIG.DW {128} $if_header_ddu_sink1


  # Create instance: of_header_ddu_sink1, and set properties
  set block_name axis_ddu_sink
  set block_cell_name of_header_ddu_sink1
  if { [catch {set of_header_ddu_sink1 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $of_header_ddu_sink1 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property CONFIG.DW {128} $of_header_ddu_sink1


  # Create instance: idata_dkulid_sink1, and set properties
  set block_name axis_dkulid_sink
  set block_cell_name idata_dkulid_sink1
  if { [catch {set idata_dkulid_sink1 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $idata_dkulid_sink1 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: of_consume_switch, and set properties
  set of_consume_switch [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 of_consume_switch ]
  set_property -dict [list \
    CONFIG.M00_AXIS_HIGHTDEST {0x00000008} \
    CONFIG.M01_AXIS_BASETDEST {0x00000009} \
    CONFIG.M01_AXIS_HIGHTDEST {0x0000000f} \
    CONFIG.NUM_SI {1} \
  ] $of_consume_switch


  # Create instance: if_consume_ddu_sink1, and set properties
  set block_name axis_ddu_sink
  set block_cell_name if_consume_ddu_sink1
  if { [catch {set if_consume_ddu_sink1 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $if_consume_ddu_sink1 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property CONFIG.DW {8} $if_consume_ddu_sink1


  # Create instance: axi_interconnect_1, and set properties
  set axi_interconnect_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_1 ]
  set_property -dict [list \
    CONFIG.ENABLE_ADVANCED_OPTIONS {0} \
    CONFIG.M00_HAS_DATA_FIFO {2} \
    CONFIG.M00_HAS_REGSLICE {4} \
    CONFIG.M01_HAS_DATA_FIFO {2} \
    CONFIG.M01_HAS_REGSLICE {4} \
    CONFIG.NUM_MI {2} \
    CONFIG.NUM_SI {3} \
    CONFIG.S00_HAS_DATA_FIFO {2} \
    CONFIG.S00_HAS_REGSLICE {4} \
    CONFIG.S01_HAS_DATA_FIFO {2} \
    CONFIG.S01_HAS_REGSLICE {4} \
    CONFIG.S02_HAS_DATA_FIFO {2} \
    CONFIG.S02_HAS_REGSLICE {4} \
    CONFIG.XBAR_DATA_WIDTH {512} \
  ] $axi_interconnect_1


  # Create instance: axi_reader_0, and set properties
  set axi_reader_0 [ create_bd_cell -type ip -vlnv user.org:user:axi_reader:1.0 axi_reader_0 ]
  set_property CONFIG.BURST_MAX_LOG {6} $axi_reader_0


  # Create instance: axi_writer_0, and set properties
  set axi_writer_0 [ create_bd_cell -type ip -vlnv user.org:user:axi_writer:1.0 axi_writer_0 ]
  set_property CONFIG.BURST_MAX_LOG {6} $axi_writer_0


  # Create instance: vec_fp_inc_wrapper_0, and set properties
  set block_name vec_fp_inc_wrapper
  set block_cell_name vec_fp_inc_wrapper_0
  if { [catch {set vec_fp_inc_wrapper_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $vec_fp_inc_wrapper_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: nop_mm_wrapper_0, and set properties
  set block_name nop_mm_wrapper
  set block_cell_name nop_mm_wrapper_0
  if { [catch {set nop_mm_wrapper_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $nop_mm_wrapper_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create interface connections
  connect_bd_intf_net -intf_net C0_SYS_CLK_0_1 [get_bd_intf_ports C0_SYS_CLK_0] [get_bd_intf_pins ddr4_0/C0_SYS_CLK]
  connect_bd_intf_net -intf_net C0_SYS_CLK_1_1 [get_bd_intf_ports C0_SYS_CLK_1] [get_bd_intf_pins ddr4_1/C0_SYS_CLK]
  connect_bd_intf_net -intf_net CLK_IN_D_0_1 [get_bd_intf_ports CLK_IN_D_0] [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]
  connect_bd_intf_net -intf_net S00_AXI_1 [get_bd_intf_pins axi_interconnect_1/S00_AXI] [get_bd_intf_pins axi_writer_0/axi]
  connect_bd_intf_net -intf_net S01_AXI_1 [get_bd_intf_pins axi_interconnect_1/S01_AXI] [get_bd_intf_pins axi_reader_0/axi]
  connect_bd_intf_net -intf_net S02_AXI_1 [get_bd_intf_pins axi_interconnect_1/S02_AXI] [get_bd_intf_pins nop_mm_wrapper_0/m_axi_mem]
  connect_bd_intf_net -intf_net axi_bram_ctrl_0_BRAM_PORTA [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTA]
  connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M01_AXI [get_bd_intf_pins axi_interconnect_0/M01_AXI] [get_bd_intf_pins stream_engine_tx/reg]
  connect_bd_intf_net -intf_net axi_interconnect_0_M02_AXI [get_bd_intf_pins axi_interconnect_0/M02_AXI] [get_bd_intf_pins stream_engine_rx/reg]
  connect_bd_intf_net -intf_net axi_interconnect_0_M03_AXI [get_bd_intf_pins axi_interconnect_0/M03_AXI] [get_bd_intf_pins route_controller_0/cfg]
  connect_bd_intf_net -intf_net axi_interconnect_0_M04_AXI [get_bd_intf_pins axi_interconnect_0/M04_AXI] [get_bd_intf_pins xdma_0/S_AXI_LITE]
  connect_bd_intf_net -intf_net axi_interconnect_0_M05_AXI [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI_CTRL] [get_bd_intf_pins axi_interconnect_0/M05_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M06_AXI [get_bd_intf_pins ddr4_1/C0_DDR4_S_AXI_CTRL] [get_bd_intf_pins axi_interconnect_0/M06_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M07_AXI [get_bd_intf_pins axi_interconnect_0/M07_AXI] [get_bd_intf_pins vec_fp_inc_wrapper_0/s_axi_ctrl]
  connect_bd_intf_net -intf_net axi_interconnect_1_M00_AXI [get_bd_intf_pins axi_interconnect_1/M00_AXI] [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_1_M01_AXI [get_bd_intf_pins axi_interconnect_1/M01_AXI] [get_bd_intf_pins ddr4_1/C0_DDR4_S_AXI]
  connect_bd_intf_net -intf_net axi_reader_0_frame_complete_consume [get_bd_intf_pins axi_reader_0/frame_complete_consume] [get_bd_intf_pins of_complete_switch/S01_AXIS]
  connect_bd_intf_net -intf_net axi_reader_0_frame_consume [get_bd_intf_pins axi_reader_0/frame_consume] [get_bd_intf_pins of_consume_switch/S00_AXIS]
  connect_bd_intf_net -intf_net axi_reader_0_odata [get_bd_intf_pins axi_reader_0/odata] [get_bd_intf_pins odata_switch/S01_AXIS]
  connect_bd_intf_net -intf_net axi_writer_0_frame_header_out [get_bd_intf_pins axi_writer_0/frame_header_out] [get_bd_intf_pins nop_mm_wrapper_0/in_frame_header_0]
  connect_bd_intf_net -intf_net axis_data_fifo_nop_in_M_AXIS [get_bd_intf_pins axis_data_fifo_nop_in/M_AXIS] [get_bd_intf_pins nop_st_wrapper_0/in_0]
  connect_bd_intf_net -intf_net axis_data_fifo_nop_out_M_AXIS [get_bd_intf_pins axis_data_fifo_nop_out/M_AXIS] [get_bd_intf_pins odata_switch/S00_AXIS]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_ports C0_DDR4_0] [get_bd_intf_pins ddr4_0/C0_DDR4]
  connect_bd_intf_net -intf_net ddr4_1_C0_DDR4 [get_bd_intf_ports C0_DDR4_1] [get_bd_intf_pins ddr4_1/C0_DDR4]
  connect_bd_intf_net -intf_net idata_switch_M00_AXIS [get_bd_intf_pins idata_switch/M00_AXIS] [get_bd_intf_pins axis_data_fifo_nop_in/S_AXIS]
  connect_bd_intf_net -intf_net idata_switch_M01_AXIS [get_bd_intf_pins idata_switch/M01_AXIS] [get_bd_intf_pins idata_dkulid_sink/in]
  connect_bd_intf_net -intf_net idata_switch_M02_AXIS [get_bd_intf_pins idata_switch/M02_AXIS] [get_bd_intf_pins axi_writer_0/idata]
  connect_bd_intf_net -intf_net idata_switch_M03_AXIS [get_bd_intf_pins idata_switch/M03_AXIS] [get_bd_intf_pins idata_dkulid_sink1/in]
  connect_bd_intf_net -intf_net idata_switch_M04_AXIS [get_bd_intf_pins idata_switch/M04_AXIS] [get_bd_intf_pins vec_fp_inc_wrapper_0/in_0]
  connect_bd_intf_net -intf_net if_consume_switch_M00_AXIS [get_bd_intf_pins if_consume_switch/M00_AXIS] [get_bd_intf_pins route_controller_0/in_frame_consume]
connect_bd_intf_net -intf_net [get_bd_intf_nets if_consume_switch_M00_AXIS] [get_bd_intf_pins if_consume_switch/M00_AXIS] [get_bd_intf_pins system_ila_iframe/SLOT_2_AXIS]
  connect_bd_intf_net -intf_net if_consume_switch_M01_AXIS [get_bd_intf_pins if_consume_switch/M01_AXIS] [get_bd_intf_pins if_consume_ddu_sink/in]
  connect_bd_intf_net -intf_net if_header_consume_switch_M00_AXIS [get_bd_intf_pins if_header_consume_switch/M00_AXIS] [get_bd_intf_pins route_controller_0/in_frame_header_consume]
connect_bd_intf_net -intf_net [get_bd_intf_nets if_header_consume_switch_M00_AXIS] [get_bd_intf_pins if_header_consume_switch/M00_AXIS] [get_bd_intf_pins system_ila_iframe/SLOT_3_AXIS]
  connect_bd_intf_net -intf_net if_header_consume_switch_M01_AXIS [get_bd_intf_pins if_header_consume_switch/M01_AXIS] [get_bd_intf_pins if_header_consume_du_sink/in]
  connect_bd_intf_net -intf_net if_header_switch_M00_AXIS [get_bd_intf_pins if_header_switch/M00_AXIS] [get_bd_intf_pins nop_st_wrapper_0/in_frame_header_0]
connect_bd_intf_net -intf_net [get_bd_intf_nets if_header_switch_M00_AXIS] [get_bd_intf_pins if_header_switch/M00_AXIS] [get_bd_intf_pins system_ila_iframe/SLOT_6_AXIS]
  connect_bd_intf_net -intf_net if_header_switch_M01_AXIS [get_bd_intf_pins if_header_switch/M01_AXIS] [get_bd_intf_pins if_header_ddu_sink/in]
  connect_bd_intf_net -intf_net if_header_switch_M02_AXIS [get_bd_intf_pins if_header_switch/M02_AXIS] [get_bd_intf_pins axi_writer_0/frame_header]
  connect_bd_intf_net -intf_net if_header_switch_M03_AXIS [get_bd_intf_pins if_header_switch/M03_AXIS] [get_bd_intf_pins if_header_ddu_sink1/in]
  connect_bd_intf_net -intf_net if_header_switch_M04_AXIS [get_bd_intf_pins if_header_switch/M04_AXIS] [get_bd_intf_pins vec_fp_inc_wrapper_0/in_frame_header_0]
  connect_bd_intf_net -intf_net nop_mm_wrapper_0_in_frame_consume_0 [get_bd_intf_pins nop_mm_wrapper_0/in_frame_consume_0] [get_bd_intf_pins if_consume_switch/S01_AXIS]
  connect_bd_intf_net -intf_net nop_mm_wrapper_0_in_frame_header_consume_0 [get_bd_intf_pins nop_mm_wrapper_0/in_frame_header_consume_0] [get_bd_intf_pins if_header_consume_switch/S01_AXIS]
  connect_bd_intf_net -intf_net nop_mm_wrapper_0_out_frame_complete_0 [get_bd_intf_pins nop_mm_wrapper_0/out_frame_complete_0] [get_bd_intf_pins axi_reader_0/frame_complete]
  connect_bd_intf_net -intf_net nop_st_wrapper_0_in_frame_consume_0 [get_bd_intf_pins nop_st_wrapper_0/in_frame_consume_0] [get_bd_intf_pins if_consume_switch/S00_AXIS]
connect_bd_intf_net -intf_net [get_bd_intf_nets nop_st_wrapper_0_in_frame_consume_0] [get_bd_intf_pins nop_st_wrapper_0/in_frame_consume_0] [get_bd_intf_pins system_ila_iframe/SLOT_8_AXIS]
  connect_bd_intf_net -intf_net nop_st_wrapper_0_in_frame_header_consume_0 [get_bd_intf_pins nop_st_wrapper_0/in_frame_header_consume_0] [get_bd_intf_pins if_header_consume_switch/S00_AXIS]
connect_bd_intf_net -intf_net [get_bd_intf_nets nop_st_wrapper_0_in_frame_header_consume_0] [get_bd_intf_pins nop_st_wrapper_0/in_frame_header_consume_0] [get_bd_intf_pins system_ila_iframe/SLOT_7_AXIS]
  connect_bd_intf_net -intf_net nop_st_wrapper_0_out_0 [get_bd_intf_pins nop_st_wrapper_0/out_0] [get_bd_intf_pins axis_data_fifo_nop_out/S_AXIS]
  connect_bd_intf_net -intf_net nop_st_wrapper_0_out_frame_complete_0 [get_bd_intf_pins nop_st_wrapper_0/out_frame_complete_0] [get_bd_intf_pins of_complete_switch/S00_AXIS]
connect_bd_intf_net -intf_net [get_bd_intf_nets nop_st_wrapper_0_out_frame_complete_0] [get_bd_intf_pins nop_st_wrapper_0/out_frame_complete_0] [get_bd_intf_pins system_ila_oframe/SLOT_4_AXIS]
  connect_bd_intf_net -intf_net odata_switch_M00_AXIS [get_bd_intf_pins odata_switch/M00_AXIS] [get_bd_intf_pins route_controller_0/user_st_in]
  connect_bd_intf_net -intf_net odata_switch_M01_AXIS [get_bd_intf_pins odata_switch/M01_AXIS] [get_bd_intf_pins odata_dkuld_sink/in]
  connect_bd_intf_net -intf_net of_complete_switch_M00_AXIS [get_bd_intf_pins of_complete_switch/M00_AXIS] [get_bd_intf_pins route_controller_0/out_frame_complete]
connect_bd_intf_net -intf_net [get_bd_intf_nets of_complete_switch_M00_AXIS] [get_bd_intf_pins of_complete_switch/M00_AXIS] [get_bd_intf_pins system_ila_oframe/SLOT_2_AXIS]
  connect_bd_intf_net -intf_net of_complete_switch_M01_AXIS [get_bd_intf_pins of_complete_switch/M01_AXIS] [get_bd_intf_pins of_complete_ddu_sink/in]
  connect_bd_intf_net -intf_net of_consume_switch_M00_AXIS [get_bd_intf_pins route_controller_0/out_frame_consume] [get_bd_intf_pins of_consume_switch/M00_AXIS]
  connect_bd_intf_net -intf_net of_consume_switch_M01_AXIS [get_bd_intf_pins of_consume_switch/M01_AXIS] [get_bd_intf_pins if_consume_ddu_sink1/in]
  connect_bd_intf_net -intf_net of_header_switch_M00_AXIS [get_bd_intf_pins of_header_switch/M00_AXIS] [get_bd_intf_pins nop_st_wrapper_0/out_frame_header_0]
connect_bd_intf_net -intf_net [get_bd_intf_nets of_header_switch_M00_AXIS] [get_bd_intf_pins of_header_switch/M00_AXIS] [get_bd_intf_pins system_ila_oframe/SLOT_5_AXIS]
  connect_bd_intf_net -intf_net of_header_switch_M01_AXIS [get_bd_intf_pins of_header_switch/M01_AXIS] [get_bd_intf_pins of_header_ddu_sink/in]
  connect_bd_intf_net -intf_net of_header_switch_M02_AXIS [get_bd_intf_pins of_header_switch/M02_AXIS] [get_bd_intf_pins nop_mm_wrapper_0/out_frame_header_0]
  connect_bd_intf_net -intf_net of_header_switch_M03_AXIS [get_bd_intf_pins of_header_switch/M03_AXIS] [get_bd_intf_pins of_header_ddu_sink1/in]
  connect_bd_intf_net -intf_net of_header_switch_M04_AXIS [get_bd_intf_pins of_header_switch/M04_AXIS] [get_bd_intf_pins vec_fp_inc_wrapper_0/out_frame_header_0]
  connect_bd_intf_net -intf_net route_controller_0_in_frame_completion [get_bd_intf_pins route_controller_0/in_frame_completion] [get_bd_intf_pins stream_engine_rx/stream_cpl_update]
connect_bd_intf_net -intf_net [get_bd_intf_nets route_controller_0_in_frame_completion] [get_bd_intf_pins route_controller_0/in_frame_completion] [get_bd_intf_pins system_ila_iframe/SLOT_1_AXIS]
  connect_bd_intf_net -intf_net route_controller_0_in_frame_header [get_bd_intf_pins route_controller_0/in_frame_header] [get_bd_intf_pins if_header_switch/S00_AXIS]
connect_bd_intf_net -intf_net [get_bd_intf_nets route_controller_0_in_frame_header] [get_bd_intf_pins route_controller_0/in_frame_header] [get_bd_intf_pins system_ila_iframe/SLOT_0_AXIS]
  connect_bd_intf_net -intf_net route_controller_0_in_frame_info_ready [get_bd_intf_pins route_controller_0/in_frame_info_ready] [get_bd_intf_pins stream_engine_rx/frame_info]
connect_bd_intf_net -intf_net [get_bd_intf_nets route_controller_0_in_frame_info_ready] [get_bd_intf_pins route_controller_0/in_frame_info_ready] [get_bd_intf_pins system_ila_iframe/SLOT_5_AXIS]
  connect_bd_intf_net -intf_net route_controller_0_out_frame_header [get_bd_intf_pins route_controller_0/out_frame_header] [get_bd_intf_pins of_header_switch/S00_AXIS]
connect_bd_intf_net -intf_net [get_bd_intf_nets route_controller_0_out_frame_header] [get_bd_intf_pins route_controller_0/out_frame_header] [get_bd_intf_pins system_ila_oframe/SLOT_0_AXIS]
  connect_bd_intf_net -intf_net route_controller_0_out_frame_info [get_bd_intf_pins route_controller_0/out_frame_info] [get_bd_intf_pins stream_engine_tx/frame_info]
connect_bd_intf_net -intf_net [get_bd_intf_nets route_controller_0_out_frame_info] [get_bd_intf_pins route_controller_0/out_frame_info] [get_bd_intf_pins system_ila_oframe/SLOT_3_AXIS]
  connect_bd_intf_net -intf_net route_controller_0_st_out [get_bd_intf_pins route_controller_0/st_out] [get_bd_intf_pins stream_engine_tx/tx_in]
  connect_bd_intf_net -intf_net route_controller_0_user_st_out [get_bd_intf_pins route_controller_0/user_st_out] [get_bd_intf_pins idata_switch/S00_AXIS]
  connect_bd_intf_net -intf_net stream_engine_rx_data_desc [get_bd_intf_pins stream_engine_rx/data_desc] [get_bd_intf_pins xdma_0/dsc_bypass_h2c_2]
  connect_bd_intf_net -intf_net stream_engine_rx_frame_info_out [get_bd_intf_pins route_controller_0/in_frame_info] [get_bd_intf_pins stream_engine_rx/frame_info_out]
connect_bd_intf_net -intf_net [get_bd_intf_nets stream_engine_rx_frame_info_out] [get_bd_intf_pins route_controller_0/in_frame_info] [get_bd_intf_pins system_ila_iframe/SLOT_4_AXIS]
  connect_bd_intf_net -intf_net stream_engine_rx_rd_desc [get_bd_intf_pins stream_engine_rx/rd_desc] [get_bd_intf_pins xdma_0/dsc_bypass_h2c_1]
  connect_bd_intf_net -intf_net stream_engine_rx_rx_out [get_bd_intf_pins route_controller_0/st_in] [get_bd_intf_pins stream_engine_rx/rx_out]
  connect_bd_intf_net -intf_net stream_engine_rx_wr [get_bd_intf_pins stream_engine_rx/wr] [get_bd_intf_pins xdma_0/S_AXIS_C2H_1]
connect_bd_intf_net -intf_net [get_bd_intf_nets stream_engine_rx_wr] [get_bd_intf_pins stream_engine_rx/wr] [get_bd_intf_pins system_ila_rx/SLOT_0_AXIS]
  connect_bd_intf_net -intf_net stream_engine_rx_wr_desc [get_bd_intf_pins stream_engine_rx/wr_desc] [get_bd_intf_pins xdma_0/dsc_bypass_c2h_1]
  connect_bd_intf_net -intf_net stream_engine_tx_data_desc [get_bd_intf_pins stream_engine_tx/data_desc] [get_bd_intf_pins xdma_0/dsc_bypass_c2h_2]
  connect_bd_intf_net -intf_net stream_engine_tx_frame_info_out [get_bd_intf_pins stream_engine_tx/frame_info_out] [get_bd_intf_pins route_controller_0/out_buffer_info]
connect_bd_intf_net -intf_net [get_bd_intf_nets stream_engine_tx_frame_info_out] [get_bd_intf_pins stream_engine_tx/frame_info_out] [get_bd_intf_pins system_ila_oframe/SLOT_1_AXIS]
  connect_bd_intf_net -intf_net stream_engine_tx_rd_desc [get_bd_intf_pins stream_engine_tx/rd_desc] [get_bd_intf_pins xdma_0/dsc_bypass_h2c_0]
  connect_bd_intf_net -intf_net stream_engine_tx_tx_out [get_bd_intf_pins stream_engine_tx/tx_out] [get_bd_intf_pins xdma_0/S_AXIS_C2H_2]
connect_bd_intf_net -intf_net [get_bd_intf_nets stream_engine_tx_tx_out] [get_bd_intf_pins stream_engine_tx/tx_out] [get_bd_intf_pins system_ila_tx/SLOT_2_AXIS]
  connect_bd_intf_net -intf_net stream_engine_tx_wr [get_bd_intf_pins stream_engine_tx/wr] [get_bd_intf_pins xdma_0/S_AXIS_C2H_0]
connect_bd_intf_net -intf_net [get_bd_intf_nets stream_engine_tx_wr] [get_bd_intf_pins stream_engine_tx/wr] [get_bd_intf_pins system_ila_tx/SLOT_0_AXIS]
  connect_bd_intf_net -intf_net stream_engine_tx_wr_desc [get_bd_intf_pins stream_engine_tx/wr_desc] [get_bd_intf_pins xdma_0/dsc_bypass_c2h_0]
  connect_bd_intf_net -intf_net vec_fp_inc_wrapper_0_in_frame_consume_0 [get_bd_intf_pins vec_fp_inc_wrapper_0/in_frame_consume_0] [get_bd_intf_pins if_consume_switch/S02_AXIS]
  connect_bd_intf_net -intf_net vec_fp_inc_wrapper_0_in_frame_header_consume_0 [get_bd_intf_pins vec_fp_inc_wrapper_0/in_frame_header_consume_0] [get_bd_intf_pins if_header_consume_switch/S02_AXIS]
  connect_bd_intf_net -intf_net vec_fp_inc_wrapper_0_out_0 [get_bd_intf_pins vec_fp_inc_wrapper_0/out_0] [get_bd_intf_pins odata_switch/S02_AXIS]
  connect_bd_intf_net -intf_net vec_fp_inc_wrapper_0_out_frame_complete_0 [get_bd_intf_pins vec_fp_inc_wrapper_0/out_frame_complete_0] [get_bd_intf_pins of_complete_switch/S02_AXIS]
  connect_bd_intf_net -intf_net xdma_0_M_AXIS_H2C_0 [get_bd_intf_pins xdma_0/M_AXIS_H2C_0] [get_bd_intf_pins stream_engine_tx/rd]
connect_bd_intf_net -intf_net [get_bd_intf_nets xdma_0_M_AXIS_H2C_0] [get_bd_intf_pins xdma_0/M_AXIS_H2C_0] [get_bd_intf_pins system_ila_tx/SLOT_1_AXIS]
  connect_bd_intf_net -intf_net xdma_0_M_AXIS_H2C_1 [get_bd_intf_pins xdma_0/M_AXIS_H2C_1] [get_bd_intf_pins stream_engine_rx/rd]
connect_bd_intf_net -intf_net [get_bd_intf_nets xdma_0_M_AXIS_H2C_1] [get_bd_intf_pins xdma_0/M_AXIS_H2C_1] [get_bd_intf_pins system_ila_rx/SLOT_1_AXIS]
  connect_bd_intf_net -intf_net xdma_0_M_AXIS_H2C_2 [get_bd_intf_pins xdma_0/M_AXIS_H2C_2] [get_bd_intf_pins stream_engine_rx/rx_in]
connect_bd_intf_net -intf_net [get_bd_intf_nets xdma_0_M_AXIS_H2C_2] [get_bd_intf_pins xdma_0/M_AXIS_H2C_2] [get_bd_intf_pins system_ila_rx/SLOT_2_AXIS]
  connect_bd_intf_net -intf_net xdma_0_M_AXI_BYPASS [get_bd_intf_pins xdma_0/M_AXI_BYPASS] [get_bd_intf_pins stream_engine_rx/axi]
  connect_bd_intf_net -intf_net xdma_0_M_AXI_LITE [get_bd_intf_pins xdma_0/M_AXI_LITE] [get_bd_intf_pins axi_interconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net xdma_0_pcie_mgt [get_bd_intf_ports pcie_mgt_0] [get_bd_intf_pins xdma_0/pcie_mgt]

  # Create port connections
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk [get_bd_pins ddr4_0/c0_ddr4_ui_clk] [get_bd_pins proc_sys_reset_ddr0/slowest_sync_clk] [get_bd_pins axi_interconnect_1/M00_ACLK] [get_bd_pins axi_interconnect_0/M05_ACLK] [get_bd_pins axi_interconnect_1/ACLK]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk_sync_rst [get_bd_pins ddr4_0/c0_ddr4_ui_clk_sync_rst] [get_bd_pins proc_sys_reset_ddr0/ext_reset_in]
  connect_bd_net -net ddr4_1_c0_ddr4_ui_clk [get_bd_pins ddr4_1/c0_ddr4_ui_clk] [get_bd_pins proc_sys_reset_ddr1/slowest_sync_clk] [get_bd_pins axi_interconnect_1/M01_ACLK] [get_bd_pins axi_interconnect_0/M06_ACLK]
  connect_bd_net -net ddr4_1_c0_ddr4_ui_clk_sync_rst [get_bd_pins ddr4_1/c0_ddr4_ui_clk_sync_rst] [get_bd_pins proc_sys_reset_ddr1/ext_reset_in]
  connect_bd_net -net proc_sys_reset_0_interconnect_aresetn [get_bd_pins proc_sys_reset_0/interconnect_aresetn] [get_bd_pins axi_interconnect_0/M03_ARESETN] [get_bd_pins axi_interconnect_0/M02_ARESETN] [get_bd_pins axi_interconnect_0/M01_ARESETN] [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_pins axi_interconnect_0/S00_ARESETN] [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins if_header_switch/aresetn] [get_bd_pins of_header_switch/aresetn] [get_bd_pins idata_switch/aresetn] [get_bd_pins if_header_consume_switch/aresetn] [get_bd_pins odata_switch/aresetn] [get_bd_pins if_consume_switch/aresetn] [get_bd_pins of_complete_switch/aresetn] [get_bd_pins axi_interconnect_0/M04_ARESETN] [get_bd_pins axi_interconnect_1/S00_ARESETN] [get_bd_pins axi_interconnect_1/S01_ARESETN] [get_bd_pins axi_interconnect_1/S02_ARESETN] [get_bd_pins axi_interconnect_0/M07_ARESETN]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] [get_bd_pins route_controller_0/resetn] [get_bd_pins nop_st_wrapper_0/resetn] [get_bd_pins system_ila_rx/resetn] [get_bd_pins system_ila_tx/resetn] [get_bd_pins system_ila_iframe/resetn] [get_bd_pins system_ila_oframe/resetn] [get_bd_pins stream_engine_rx/resetn] [get_bd_pins stream_engine_tx/resetn] [get_bd_pins axis_data_fifo_nop_in/s_axis_aresetn] [get_bd_pins axis_data_fifo_nop_out/s_axis_aresetn] [get_bd_pins of_consume_switch/aresetn] [get_bd_pins axi_reader_0/resetn] [get_bd_pins axi_writer_0/resetn] [get_bd_pins vec_fp_inc_wrapper_0/resetn] [get_bd_pins nop_mm_wrapper_0/resetn]
  connect_bd_net -net proc_sys_reset_ddr0_interconnect_aresetn [get_bd_pins proc_sys_reset_ddr0/interconnect_aresetn] [get_bd_pins axi_interconnect_1/M00_ARESETN] [get_bd_pins axi_interconnect_0/M05_ARESETN] [get_bd_pins axi_interconnect_1/ARESETN]
  connect_bd_net -net proc_sys_reset_ddr0_peripheral_aresetn [get_bd_pins proc_sys_reset_ddr0/peripheral_aresetn] [get_bd_pins ddr4_0/c0_ddr4_aresetn]
  connect_bd_net -net proc_sys_reset_ddr1_interconnect_aresetn [get_bd_pins proc_sys_reset_ddr1/interconnect_aresetn] [get_bd_pins axi_interconnect_1/M01_ARESETN] [get_bd_pins axi_interconnect_0/M06_ARESETN]
  connect_bd_net -net proc_sys_reset_ddr1_peripheral_aresetn [get_bd_pins proc_sys_reset_ddr1/peripheral_aresetn] [get_bd_pins ddr4_1/c0_ddr4_aresetn]
  connect_bd_net -net route_controller_0_st_out_eop [get_bd_pins route_controller_0/st_out_eop] [get_bd_pins stream_engine_tx/tx_in_eop]
  connect_bd_net -net route_controller_0_st_out_sop [get_bd_pins route_controller_0/st_out_sop] [get_bd_pins stream_engine_tx/tx_in_sop]
  connect_bd_net -net stream_engine_rx_rx_out_eof [get_bd_pins stream_engine_rx/rx_out_eof] [get_bd_pins route_controller_0/st_in_eof]
  connect_bd_net -net sys_rst_inv_Res [get_bd_pins sys_rst_inv/Res] [get_bd_pins ddr4_0/sys_rst] [get_bd_pins ddr4_1/sys_rst]
  connect_bd_net -net sys_rst_n_0_1 [get_bd_ports sys_rst_n_0] [get_bd_pins xdma_0/sys_rst_n] [get_bd_pins sys_rst_inv/Op1]
  connect_bd_net -net util_ds_buf_0_IBUF_DS_ODIV2 [get_bd_pins util_ds_buf_0/IBUF_DS_ODIV2] [get_bd_pins xdma_0/sys_clk]
  connect_bd_net -net util_ds_buf_0_IBUF_OUT [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins xdma_0/sys_clk_gt]
  connect_bd_net -net xdma_0_axi_aclk [get_bd_pins xdma_0/axi_aclk] [get_bd_pins proc_sys_reset_0/slowest_sync_clk] [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins axi_interconnect_0/M01_ACLK] [get_bd_pins axi_interconnect_0/M02_ACLK] [get_bd_pins axi_interconnect_0/M03_ACLK] [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] [get_bd_pins if_header_switch/aclk] [get_bd_pins of_header_switch/aclk] [get_bd_pins idata_switch/aclk] [get_bd_pins if_header_consume_switch/aclk] [get_bd_pins if_consume_switch/aclk] [get_bd_pins of_complete_switch/aclk] [get_bd_pins odata_switch/aclk] [get_bd_pins if_header_ddu_sink/clk] [get_bd_pins of_header_ddu_sink/clk] [get_bd_pins idata_dkulid_sink/clk] [get_bd_pins if_header_consume_du_sink/clk] [get_bd_pins if_consume_ddu_sink/clk] [get_bd_pins of_complete_ddu_sink/clk] [get_bd_pins odata_dkuld_sink/clk] [get_bd_pins route_controller_0/clk] [get_bd_pins nop_st_wrapper_0/clk] [get_bd_pins axi_interconnect_0/M04_ACLK] [get_bd_pins system_ila_rx/clk] [get_bd_pins system_ila_tx/clk] [get_bd_pins system_ila_iframe/clk] [get_bd_pins system_ila_oframe/clk] [get_bd_pins stream_engine_rx/clk] [get_bd_pins stream_engine_tx/clk] [get_bd_pins axis_data_fifo_nop_in/s_axis_aclk] [get_bd_pins axis_data_fifo_nop_out/s_axis_aclk] [get_bd_pins if_header_ddu_sink1/clk] [get_bd_pins of_header_ddu_sink1/clk] [get_bd_pins idata_dkulid_sink1/clk] [get_bd_pins if_consume_ddu_sink1/clk] [get_bd_pins axi_interconnect_1/S00_ACLK] [get_bd_pins axi_interconnect_1/S01_ACLK] [get_bd_pins axi_interconnect_1/S02_ACLK] [get_bd_pins of_consume_switch/aclk] [get_bd_pins axi_reader_0/clk] [get_bd_pins axi_writer_0/clk] [get_bd_pins vec_fp_inc_wrapper_0/clk] [get_bd_pins axi_interconnect_0/M07_ACLK] [get_bd_pins nop_mm_wrapper_0/clk]
  connect_bd_net -net xdma_0_axi_aresetn [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins proc_sys_reset_0/ext_reset_in]
  connect_bd_net -net xdma_0_c2h_sts_0 [get_bd_pins xdma_0/c2h_sts_0] [get_bd_pins system_ila_tx/probe0] [get_bd_pins stream_engine_tx/wr_sts]
  connect_bd_net -net xdma_0_c2h_sts_1 [get_bd_pins xdma_0/c2h_sts_1] [get_bd_pins system_ila_rx/probe0] [get_bd_pins stream_engine_rx/wr_sts]
  connect_bd_net -net xdma_0_c2h_sts_2 [get_bd_pins xdma_0/c2h_sts_2] [get_bd_pins system_ila_tx/probe2] [get_bd_pins stream_engine_tx/data_sts]
  connect_bd_net -net xdma_0_h2c_sts_0 [get_bd_pins xdma_0/h2c_sts_0] [get_bd_pins system_ila_tx/probe1] [get_bd_pins stream_engine_tx/rd_sts]
  connect_bd_net -net xdma_0_h2c_sts_1 [get_bd_pins xdma_0/h2c_sts_1] [get_bd_pins system_ila_rx/probe1] [get_bd_pins stream_engine_rx/rd_sts]
  connect_bd_net -net xdma_0_h2c_sts_2 [get_bd_pins xdma_0/h2c_sts_2] [get_bd_pins system_ila_rx/probe2] [get_bd_pins stream_engine_rx/data_sts]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins xlconstant_0/dout] [get_bd_pins nop_mm_wrapper_0/in_0_tvalid]
  connect_bd_net -net xlconstant_0x16_dout [get_bd_pins xlconstant_0x16/dout] [get_bd_pins stream_engine_rx/irq_ack] [get_bd_pins stream_engine_tx/irq_ack]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x00010000000000000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_BYPASS] [get_bd_addr_segs stream_engine_rx/axi/reg0] -force
  assign_bd_address -offset 0x00010000 -range 0x00002000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force
  assign_bd_address -offset 0x00100000 -range 0x00100000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP_CTRL/C0_REG] -force
  assign_bd_address -offset 0x00200000 -range 0x00100000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs ddr4_1/C0_DDR4_MEMORY_MAP_CTRL/C0_REG] -force
  assign_bd_address -offset 0x00040000 -range 0x00010000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs route_controller_0/cfg/reg0] -force
  assign_bd_address -offset 0x00020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs stream_engine_rx/reg/reg0] -force
  assign_bd_address -offset 0x00030000 -range 0x00010000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs stream_engine_tx/reg/reg0] -force
  assign_bd_address -offset 0x00012000 -range 0x00001000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs vec_fp_inc_wrapper_0/s_axi_ctrl/reg0] -force
  assign_bd_address -offset 0x00000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs xdma_0/S_AXI_LITE/CTL0] -force
  assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces axi_reader_0/axi] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x000400000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces axi_reader_0/axi] [get_bd_addr_segs ddr4_1/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces axi_writer_0/axi] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x000400000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces axi_writer_0/axi] [get_bd_addr_segs ddr4_1/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces nop_mm_wrapper_0/m_axi_mem] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x000400000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces nop_mm_wrapper_0/m_axi_mem] [get_bd_addr_segs ddr4_1/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force


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


