#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

# Loading additional proc with user specified bodies to compute parameter values.
source [file join [file dirname [file dirname [info script]]] gui/route_controller_v1_0.gtcl]

# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "DW_LOG" -parent ${Page_0}
  ipgui::add_param $IPINST -name "CTX_ID_BITS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TDEST_BITS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ENABLE_MULTI_CONTROLLER" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SELF_DEST" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BURST_BITS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "CREDIT_MAX" -parent ${Page_0}
  ipgui::add_param $IPINST -name "EXT_RELATION" -parent ${Page_0}


}

proc update_PARAM_VALUE.SELF_DEST { PARAM_VALUE.SELF_DEST PARAM_VALUE.ENABLE_MULTI_CONTROLLER } {
	# Procedure called to update SELF_DEST when any of the dependent parameters in the arguments change
	
	set SELF_DEST ${PARAM_VALUE.SELF_DEST}
	set ENABLE_MULTI_CONTROLLER ${PARAM_VALUE.ENABLE_MULTI_CONTROLLER}
	set values(ENABLE_MULTI_CONTROLLER) [get_property value $ENABLE_MULTI_CONTROLLER]
	if { [gen_USERPARAMETER_SELF_DEST_ENABLEMENT $values(ENABLE_MULTI_CONTROLLER)] } {
		set_property enabled true $SELF_DEST
	} else {
		set_property enabled false $SELF_DEST
	}
}

proc validate_PARAM_VALUE.SELF_DEST { PARAM_VALUE.SELF_DEST } {
	# Procedure called to validate SELF_DEST
	return true
}

proc update_PARAM_VALUE.ADDR_BITS { PARAM_VALUE.ADDR_BITS } {
	# Procedure called to update ADDR_BITS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ADDR_BITS { PARAM_VALUE.ADDR_BITS } {
	# Procedure called to validate ADDR_BITS
	return true
}

proc update_PARAM_VALUE.BURST_BITS { PARAM_VALUE.BURST_BITS } {
	# Procedure called to update BURST_BITS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BURST_BITS { PARAM_VALUE.BURST_BITS } {
	# Procedure called to validate BURST_BITS
	return true
}

proc update_PARAM_VALUE.CREDIT_MAX { PARAM_VALUE.CREDIT_MAX } {
	# Procedure called to update CREDIT_MAX when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CREDIT_MAX { PARAM_VALUE.CREDIT_MAX } {
	# Procedure called to validate CREDIT_MAX
	return true
}

proc update_PARAM_VALUE.CTX_ID_BITS { PARAM_VALUE.CTX_ID_BITS } {
	# Procedure called to update CTX_ID_BITS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CTX_ID_BITS { PARAM_VALUE.CTX_ID_BITS } {
	# Procedure called to validate CTX_ID_BITS
	return true
}

proc update_PARAM_VALUE.DW_LOG { PARAM_VALUE.DW_LOG } {
	# Procedure called to update DW_LOG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DW_LOG { PARAM_VALUE.DW_LOG } {
	# Procedure called to validate DW_LOG
	return true
}

proc update_PARAM_VALUE.ENABLE_MULTI_CONTROLLER { PARAM_VALUE.ENABLE_MULTI_CONTROLLER } {
	# Procedure called to update ENABLE_MULTI_CONTROLLER when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENABLE_MULTI_CONTROLLER { PARAM_VALUE.ENABLE_MULTI_CONTROLLER } {
	# Procedure called to validate ENABLE_MULTI_CONTROLLER
	return true
}

proc update_PARAM_VALUE.EXT_RELATION { PARAM_VALUE.EXT_RELATION } {
	# Procedure called to update EXT_RELATION when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.EXT_RELATION { PARAM_VALUE.EXT_RELATION } {
	# Procedure called to validate EXT_RELATION
	return true
}

proc update_PARAM_VALUE.TDEST_BITS { PARAM_VALUE.TDEST_BITS } {
	# Procedure called to update TDEST_BITS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TDEST_BITS { PARAM_VALUE.TDEST_BITS } {
	# Procedure called to validate TDEST_BITS
	return true
}


proc update_MODELPARAM_VALUE.CTX_ID_BITS { MODELPARAM_VALUE.CTX_ID_BITS PARAM_VALUE.CTX_ID_BITS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CTX_ID_BITS}] ${MODELPARAM_VALUE.CTX_ID_BITS}
}

proc update_MODELPARAM_VALUE.ADDR_BITS { MODELPARAM_VALUE.ADDR_BITS PARAM_VALUE.ADDR_BITS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ADDR_BITS}] ${MODELPARAM_VALUE.ADDR_BITS}
}

proc update_MODELPARAM_VALUE.DW_LOG { MODELPARAM_VALUE.DW_LOG PARAM_VALUE.DW_LOG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DW_LOG}] ${MODELPARAM_VALUE.DW_LOG}
}

proc update_MODELPARAM_VALUE.TDEST_BITS { MODELPARAM_VALUE.TDEST_BITS PARAM_VALUE.TDEST_BITS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TDEST_BITS}] ${MODELPARAM_VALUE.TDEST_BITS}
}

proc update_MODELPARAM_VALUE.BURST_BITS { MODELPARAM_VALUE.BURST_BITS PARAM_VALUE.BURST_BITS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BURST_BITS}] ${MODELPARAM_VALUE.BURST_BITS}
}

proc update_MODELPARAM_VALUE.EXT_RELATION { MODELPARAM_VALUE.EXT_RELATION PARAM_VALUE.EXT_RELATION } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.EXT_RELATION}] ${MODELPARAM_VALUE.EXT_RELATION}
}

proc update_MODELPARAM_VALUE.CREDIT_MAX { MODELPARAM_VALUE.CREDIT_MAX PARAM_VALUE.CREDIT_MAX } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CREDIT_MAX}] ${MODELPARAM_VALUE.CREDIT_MAX}
}

proc update_MODELPARAM_VALUE.ENABLE_MULTI_CONTROLLER { MODELPARAM_VALUE.ENABLE_MULTI_CONTROLLER PARAM_VALUE.ENABLE_MULTI_CONTROLLER } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENABLE_MULTI_CONTROLLER}] ${MODELPARAM_VALUE.ENABLE_MULTI_CONTROLLER}
}

proc update_MODELPARAM_VALUE.SELF_DEST { MODELPARAM_VALUE.SELF_DEST PARAM_VALUE.SELF_DEST } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SELF_DEST}] ${MODELPARAM_VALUE.SELF_DEST}
}

