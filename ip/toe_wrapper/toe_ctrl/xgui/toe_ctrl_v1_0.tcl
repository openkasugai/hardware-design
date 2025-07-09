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
  ipgui::add_param $IPINST -name "BURST_BITS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "CH_NUM_LOG" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DW_LOG" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FRAME_MAX" -parent ${Page_0}
  ipgui::add_param $IPINST -name "MAX_INFLIGHT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SESSION_NUM_LOG" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TX_AUX_FIFO_DL" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TX_FIFO_DL" -parent ${Page_0}


}

proc update_PARAM_VALUE.ACTIVATE_MAGIC { PARAM_VALUE.ACTIVATE_MAGIC } {
	# Procedure called to update ACTIVATE_MAGIC when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ACTIVATE_MAGIC { PARAM_VALUE.ACTIVATE_MAGIC } {
	# Procedure called to validate ACTIVATE_MAGIC
	return true
}

proc update_PARAM_VALUE.AW { PARAM_VALUE.AW } {
	# Procedure called to update AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AW { PARAM_VALUE.AW } {
	# Procedure called to validate AW
	return true
}

proc update_PARAM_VALUE.BURST_BITS { PARAM_VALUE.BURST_BITS } {
	# Procedure called to update BURST_BITS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BURST_BITS { PARAM_VALUE.BURST_BITS } {
	# Procedure called to validate BURST_BITS
	return true
}

proc update_PARAM_VALUE.CH_NUM_LOG { PARAM_VALUE.CH_NUM_LOG } {
	# Procedure called to update CH_NUM_LOG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CH_NUM_LOG { PARAM_VALUE.CH_NUM_LOG } {
	# Procedure called to validate CH_NUM_LOG
	return true
}

proc update_PARAM_VALUE.CREDIT_MAGIC { PARAM_VALUE.CREDIT_MAGIC } {
	# Procedure called to update CREDIT_MAGIC when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CREDIT_MAGIC { PARAM_VALUE.CREDIT_MAGIC } {
	# Procedure called to validate CREDIT_MAGIC
	return true
}

proc update_PARAM_VALUE.DW_LOG { PARAM_VALUE.DW_LOG } {
	# Procedure called to update DW_LOG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DW_LOG { PARAM_VALUE.DW_LOG } {
	# Procedure called to validate DW_LOG
	return true
}

proc update_PARAM_VALUE.FRAME_MAX { PARAM_VALUE.FRAME_MAX } {
	# Procedure called to update FRAME_MAX when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FRAME_MAX { PARAM_VALUE.FRAME_MAX } {
	# Procedure called to validate FRAME_MAX
	return true
}

proc update_PARAM_VALUE.MAX_INFLIGHT { PARAM_VALUE.MAX_INFLIGHT } {
	# Procedure called to update MAX_INFLIGHT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MAX_INFLIGHT { PARAM_VALUE.MAX_INFLIGHT } {
	# Procedure called to validate MAX_INFLIGHT
	return true
}

proc update_PARAM_VALUE.SESSION_NUM_LOG { PARAM_VALUE.SESSION_NUM_LOG } {
	# Procedure called to update SESSION_NUM_LOG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SESSION_NUM_LOG { PARAM_VALUE.SESSION_NUM_LOG } {
	# Procedure called to validate SESSION_NUM_LOG
	return true
}

proc update_PARAM_VALUE.TX_AUX_FIFO_DL { PARAM_VALUE.TX_AUX_FIFO_DL } {
	# Procedure called to update TX_AUX_FIFO_DL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TX_AUX_FIFO_DL { PARAM_VALUE.TX_AUX_FIFO_DL } {
	# Procedure called to validate TX_AUX_FIFO_DL
	return true
}

proc update_PARAM_VALUE.TX_FIFO_DL { PARAM_VALUE.TX_FIFO_DL } {
	# Procedure called to update TX_FIFO_DL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TX_FIFO_DL { PARAM_VALUE.TX_FIFO_DL } {
	# Procedure called to validate TX_FIFO_DL
	return true
}


proc update_MODELPARAM_VALUE.AW { MODELPARAM_VALUE.AW PARAM_VALUE.AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AW}] ${MODELPARAM_VALUE.AW}
}

proc update_MODELPARAM_VALUE.DW_LOG { MODELPARAM_VALUE.DW_LOG PARAM_VALUE.DW_LOG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DW_LOG}] ${MODELPARAM_VALUE.DW_LOG}
}

proc update_MODELPARAM_VALUE.CH_NUM_LOG { MODELPARAM_VALUE.CH_NUM_LOG PARAM_VALUE.CH_NUM_LOG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CH_NUM_LOG}] ${MODELPARAM_VALUE.CH_NUM_LOG}
}

proc update_MODELPARAM_VALUE.BURST_BITS { MODELPARAM_VALUE.BURST_BITS PARAM_VALUE.BURST_BITS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BURST_BITS}] ${MODELPARAM_VALUE.BURST_BITS}
}

proc update_MODELPARAM_VALUE.SESSION_NUM_LOG { MODELPARAM_VALUE.SESSION_NUM_LOG PARAM_VALUE.SESSION_NUM_LOG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SESSION_NUM_LOG}] ${MODELPARAM_VALUE.SESSION_NUM_LOG}
}

proc update_MODELPARAM_VALUE.FRAME_MAX { MODELPARAM_VALUE.FRAME_MAX PARAM_VALUE.FRAME_MAX } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FRAME_MAX}] ${MODELPARAM_VALUE.FRAME_MAX}
}

proc update_MODELPARAM_VALUE.MAX_INFLIGHT { MODELPARAM_VALUE.MAX_INFLIGHT PARAM_VALUE.MAX_INFLIGHT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MAX_INFLIGHT}] ${MODELPARAM_VALUE.MAX_INFLIGHT}
}

proc update_MODELPARAM_VALUE.TX_FIFO_DL { MODELPARAM_VALUE.TX_FIFO_DL PARAM_VALUE.TX_FIFO_DL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TX_FIFO_DL}] ${MODELPARAM_VALUE.TX_FIFO_DL}
}

proc update_MODELPARAM_VALUE.TX_AUX_FIFO_DL { MODELPARAM_VALUE.TX_AUX_FIFO_DL PARAM_VALUE.TX_AUX_FIFO_DL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TX_AUX_FIFO_DL}] ${MODELPARAM_VALUE.TX_AUX_FIFO_DL}
}

proc update_MODELPARAM_VALUE.ACTIVATE_MAGIC { MODELPARAM_VALUE.ACTIVATE_MAGIC PARAM_VALUE.ACTIVATE_MAGIC } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ACTIVATE_MAGIC}] ${MODELPARAM_VALUE.ACTIVATE_MAGIC}
}

proc update_MODELPARAM_VALUE.CREDIT_MAGIC { MODELPARAM_VALUE.CREDIT_MAGIC PARAM_VALUE.CREDIT_MAGIC } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CREDIT_MAGIC}] ${MODELPARAM_VALUE.CREDIT_MAGIC}
}

