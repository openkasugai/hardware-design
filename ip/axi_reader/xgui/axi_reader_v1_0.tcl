#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "BURST_MAX_LOG" -parent ${Page_0}
  ipgui::add_param $IPINST -name "CTX_ID_BITS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DATA_FIFO_DL" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DM_ADDR_BITS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DM_STS_FIFO_DL" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DW" -parent ${Page_0}
  ipgui::add_param $IPINST -name "HEADER_FIFO_DL" -parent ${Page_0}
  ipgui::add_param $IPINST -name "HEADER_OUT_FIFO_DL" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ODEST_BITS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "RR_BITS" -parent ${Page_0}


}

proc update_PARAM_VALUE.BURST_MAX_LOG { PARAM_VALUE.BURST_MAX_LOG } {
	# Procedure called to update BURST_MAX_LOG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BURST_MAX_LOG { PARAM_VALUE.BURST_MAX_LOG } {
	# Procedure called to validate BURST_MAX_LOG
	return true
}

proc update_PARAM_VALUE.CTX_ID_BITS { PARAM_VALUE.CTX_ID_BITS } {
	# Procedure called to update CTX_ID_BITS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CTX_ID_BITS { PARAM_VALUE.CTX_ID_BITS } {
	# Procedure called to validate CTX_ID_BITS
	return true
}

proc update_PARAM_VALUE.DATA_FIFO_DL { PARAM_VALUE.DATA_FIFO_DL } {
	# Procedure called to update DATA_FIFO_DL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_FIFO_DL { PARAM_VALUE.DATA_FIFO_DL } {
	# Procedure called to validate DATA_FIFO_DL
	return true
}

proc update_PARAM_VALUE.DM_ADDR_BITS { PARAM_VALUE.DM_ADDR_BITS } {
	# Procedure called to update DM_ADDR_BITS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DM_ADDR_BITS { PARAM_VALUE.DM_ADDR_BITS } {
	# Procedure called to validate DM_ADDR_BITS
	return true
}

proc update_PARAM_VALUE.DM_STS_FIFO_DL { PARAM_VALUE.DM_STS_FIFO_DL } {
	# Procedure called to update DM_STS_FIFO_DL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DM_STS_FIFO_DL { PARAM_VALUE.DM_STS_FIFO_DL } {
	# Procedure called to validate DM_STS_FIFO_DL
	return true
}

proc update_PARAM_VALUE.DW { PARAM_VALUE.DW } {
	# Procedure called to update DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DW { PARAM_VALUE.DW } {
	# Procedure called to validate DW
	return true
}

proc update_PARAM_VALUE.HEADER_FIFO_DL { PARAM_VALUE.HEADER_FIFO_DL } {
	# Procedure called to update HEADER_FIFO_DL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HEADER_FIFO_DL { PARAM_VALUE.HEADER_FIFO_DL } {
	# Procedure called to validate HEADER_FIFO_DL
	return true
}

proc update_PARAM_VALUE.HEADER_OUT_FIFO_DL { PARAM_VALUE.HEADER_OUT_FIFO_DL } {
	# Procedure called to update HEADER_OUT_FIFO_DL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HEADER_OUT_FIFO_DL { PARAM_VALUE.HEADER_OUT_FIFO_DL } {
	# Procedure called to validate HEADER_OUT_FIFO_DL
	return true
}

proc update_PARAM_VALUE.ODEST_BITS { PARAM_VALUE.ODEST_BITS } {
	# Procedure called to update ODEST_BITS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ODEST_BITS { PARAM_VALUE.ODEST_BITS } {
	# Procedure called to validate ODEST_BITS
	return true
}

proc update_PARAM_VALUE.RR_BITS { PARAM_VALUE.RR_BITS } {
	# Procedure called to update RR_BITS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RR_BITS { PARAM_VALUE.RR_BITS } {
	# Procedure called to validate RR_BITS
	return true
}


proc update_MODELPARAM_VALUE.DW { MODELPARAM_VALUE.DW PARAM_VALUE.DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DW}] ${MODELPARAM_VALUE.DW}
}

proc update_MODELPARAM_VALUE.CTX_ID_BITS { MODELPARAM_VALUE.CTX_ID_BITS PARAM_VALUE.CTX_ID_BITS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CTX_ID_BITS}] ${MODELPARAM_VALUE.CTX_ID_BITS}
}

proc update_MODELPARAM_VALUE.BURST_MAX_LOG { MODELPARAM_VALUE.BURST_MAX_LOG PARAM_VALUE.BURST_MAX_LOG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BURST_MAX_LOG}] ${MODELPARAM_VALUE.BURST_MAX_LOG}
}

proc update_MODELPARAM_VALUE.HEADER_FIFO_DL { MODELPARAM_VALUE.HEADER_FIFO_DL PARAM_VALUE.HEADER_FIFO_DL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HEADER_FIFO_DL}] ${MODELPARAM_VALUE.HEADER_FIFO_DL}
}

proc update_MODELPARAM_VALUE.HEADER_OUT_FIFO_DL { MODELPARAM_VALUE.HEADER_OUT_FIFO_DL PARAM_VALUE.HEADER_OUT_FIFO_DL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HEADER_OUT_FIFO_DL}] ${MODELPARAM_VALUE.HEADER_OUT_FIFO_DL}
}

proc update_MODELPARAM_VALUE.DATA_FIFO_DL { MODELPARAM_VALUE.DATA_FIFO_DL PARAM_VALUE.DATA_FIFO_DL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_FIFO_DL}] ${MODELPARAM_VALUE.DATA_FIFO_DL}
}

proc update_MODELPARAM_VALUE.DM_STS_FIFO_DL { MODELPARAM_VALUE.DM_STS_FIFO_DL PARAM_VALUE.DM_STS_FIFO_DL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DM_STS_FIFO_DL}] ${MODELPARAM_VALUE.DM_STS_FIFO_DL}
}

proc update_MODELPARAM_VALUE.RR_BITS { MODELPARAM_VALUE.RR_BITS PARAM_VALUE.RR_BITS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RR_BITS}] ${MODELPARAM_VALUE.RR_BITS}
}

proc update_MODELPARAM_VALUE.ODEST_BITS { MODELPARAM_VALUE.ODEST_BITS PARAM_VALUE.ODEST_BITS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ODEST_BITS}] ${MODELPARAM_VALUE.ODEST_BITS}
}

proc update_MODELPARAM_VALUE.DM_ADDR_BITS { MODELPARAM_VALUE.DM_ADDR_BITS PARAM_VALUE.DM_ADDR_BITS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DM_ADDR_BITS}] ${MODELPARAM_VALUE.DM_ADDR_BITS}
}

