#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

# Loading additional proc with user specified bodies to compute parameter values.
source [file join [file dirname [file dirname [info script]]] gui/stream_engine_v1_0.gtcl]

# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0" -display_name {base}]
  set_property tooltip {base} ${Page_0}
  ipgui::add_param $IPINST -name "IS_TX" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DW_LOG" -parent ${Page_0}
  ipgui::add_param $IPINST -name "CH_NUM_LOG" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VP_MAP_NUM_LOG" -parent ${Page_0}
  ipgui::add_param $IPINST -name "D2D_AXI_BASE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "D2D_AXI_RANGE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "USE_ULTRA_RAM_VPMAP" -parent ${Page_0}

  #Adding Page
  set Page_1 [ipgui::add_page $IPINST -name "Page 1" -display_name {detail}]
  set_property tooltip {detail} ${Page_1}
  ipgui::add_param $IPINST -name "BURST_MAX" -parent ${Page_1}
  ipgui::add_param $IPINST -name "QUEUE_CHECK_TAG" -parent ${Page_1}
  ipgui::add_param $IPINST -name "QUEUE_READ_TAG" -parent ${Page_1}
  ipgui::add_param $IPINST -name "CH_BASE" -parent ${Page_1}
  ipgui::add_param $IPINST -name "DATA_FIFO_DL" -parent ${Page_1}
  ipgui::add_param $IPINST -name "CPL_FIFO_DL" -parent ${Page_1}
  ipgui::add_param $IPINST -name "DESC_FIFO_DL" -parent ${Page_1}
  ipgui::add_param $IPINST -name "DESC_BASE_FIFO_DL" -parent ${Page_1}
  ipgui::add_param $IPINST -name "FRAME_INFO_FIFO_DL" -parent ${Page_1}
  ipgui::add_param $IPINST -name "STS_FIFO_DL" -parent ${Page_1}
  ipgui::add_param $IPINST -name "ACTIVE_LOW_RESET_IN" -parent ${Page_1}


}

proc update_PARAM_VALUE.D2D_AXI_BASE { PARAM_VALUE.D2D_AXI_BASE PARAM_VALUE.IS_TX } {
	# Procedure called to update D2D_AXI_BASE when any of the dependent parameters in the arguments change
	
	set D2D_AXI_BASE ${PARAM_VALUE.D2D_AXI_BASE}
	set IS_TX ${PARAM_VALUE.IS_TX}
	set values(IS_TX) [get_property value $IS_TX]
	if { [gen_USERPARAMETER_D2D_AXI_BASE_ENABLEMENT $values(IS_TX)] } {
		set_property enabled true $D2D_AXI_BASE
	} else {
		set_property enabled false $D2D_AXI_BASE
	}
}

proc validate_PARAM_VALUE.D2D_AXI_BASE { PARAM_VALUE.D2D_AXI_BASE } {
	# Procedure called to validate D2D_AXI_BASE
	return true
}

proc update_PARAM_VALUE.D2D_AXI_RANGE { PARAM_VALUE.D2D_AXI_RANGE PARAM_VALUE.IS_TX } {
	# Procedure called to update D2D_AXI_RANGE when any of the dependent parameters in the arguments change
	
	set D2D_AXI_RANGE ${PARAM_VALUE.D2D_AXI_RANGE}
	set IS_TX ${PARAM_VALUE.IS_TX}
	set values(IS_TX) [get_property value $IS_TX]
	if { [gen_USERPARAMETER_D2D_AXI_RANGE_ENABLEMENT $values(IS_TX)] } {
		set_property enabled true $D2D_AXI_RANGE
	} else {
		set_property enabled false $D2D_AXI_RANGE
	}
}

proc validate_PARAM_VALUE.D2D_AXI_RANGE { PARAM_VALUE.D2D_AXI_RANGE } {
	# Procedure called to validate D2D_AXI_RANGE
	return true
}

proc update_PARAM_VALUE.ACTIVE_LOW_RESET_IN { PARAM_VALUE.ACTIVE_LOW_RESET_IN } {
	# Procedure called to update ACTIVE_LOW_RESET_IN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ACTIVE_LOW_RESET_IN { PARAM_VALUE.ACTIVE_LOW_RESET_IN } {
	# Procedure called to validate ACTIVE_LOW_RESET_IN
	return true
}

proc update_PARAM_VALUE.BURST_MAX { PARAM_VALUE.BURST_MAX } {
	# Procedure called to update BURST_MAX when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BURST_MAX { PARAM_VALUE.BURST_MAX } {
	# Procedure called to validate BURST_MAX
	return true
}

proc update_PARAM_VALUE.CH_BASE { PARAM_VALUE.CH_BASE } {
	# Procedure called to update CH_BASE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CH_BASE { PARAM_VALUE.CH_BASE } {
	# Procedure called to validate CH_BASE
	return true
}

proc update_PARAM_VALUE.CH_NUM_LOG { PARAM_VALUE.CH_NUM_LOG } {
	# Procedure called to update CH_NUM_LOG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CH_NUM_LOG { PARAM_VALUE.CH_NUM_LOG } {
	# Procedure called to validate CH_NUM_LOG
	return true
}

proc update_PARAM_VALUE.CH_POS { PARAM_VALUE.CH_POS } {
	# Procedure called to update CH_POS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CH_POS { PARAM_VALUE.CH_POS } {
	# Procedure called to validate CH_POS
	return true
}

proc update_PARAM_VALUE.CPL_FIFO_DL { PARAM_VALUE.CPL_FIFO_DL } {
	# Procedure called to update CPL_FIFO_DL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CPL_FIFO_DL { PARAM_VALUE.CPL_FIFO_DL } {
	# Procedure called to validate CPL_FIFO_DL
	return true
}

proc update_PARAM_VALUE.CPL_POS { PARAM_VALUE.CPL_POS } {
	# Procedure called to update CPL_POS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CPL_POS { PARAM_VALUE.CPL_POS } {
	# Procedure called to validate CPL_POS
	return true
}

proc update_PARAM_VALUE.DATA_FIFO_DL { PARAM_VALUE.DATA_FIFO_DL } {
	# Procedure called to update DATA_FIFO_DL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_FIFO_DL { PARAM_VALUE.DATA_FIFO_DL } {
	# Procedure called to validate DATA_FIFO_DL
	return true
}

proc update_PARAM_VALUE.DESC_BASE_FIFO_DL { PARAM_VALUE.DESC_BASE_FIFO_DL } {
	# Procedure called to update DESC_BASE_FIFO_DL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DESC_BASE_FIFO_DL { PARAM_VALUE.DESC_BASE_FIFO_DL } {
	# Procedure called to validate DESC_BASE_FIFO_DL
	return true
}

proc update_PARAM_VALUE.DESC_FIFO_DL { PARAM_VALUE.DESC_FIFO_DL } {
	# Procedure called to update DESC_FIFO_DL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DESC_FIFO_DL { PARAM_VALUE.DESC_FIFO_DL } {
	# Procedure called to validate DESC_FIFO_DL
	return true
}

proc update_PARAM_VALUE.DESC_LEN { PARAM_VALUE.DESC_LEN } {
	# Procedure called to update DESC_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DESC_LEN { PARAM_VALUE.DESC_LEN } {
	# Procedure called to validate DESC_LEN
	return true
}

proc update_PARAM_VALUE.DESC_MAX { PARAM_VALUE.DESC_MAX } {
	# Procedure called to update DESC_MAX when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DESC_MAX { PARAM_VALUE.DESC_MAX } {
	# Procedure called to validate DESC_MAX
	return true
}

proc update_PARAM_VALUE.DESC_RC_DK { PARAM_VALUE.DESC_RC_DK } {
	# Procedure called to update DESC_RC_DK when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DESC_RC_DK { PARAM_VALUE.DESC_RC_DK } {
	# Procedure called to validate DESC_RC_DK
	return true
}

proc update_PARAM_VALUE.DESC_RC_DW { PARAM_VALUE.DESC_RC_DW } {
	# Procedure called to update DESC_RC_DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DESC_RC_DW { PARAM_VALUE.DESC_RC_DW } {
	# Procedure called to validate DESC_RC_DW
	return true
}

proc update_PARAM_VALUE.DESC_RQ_DK { PARAM_VALUE.DESC_RQ_DK } {
	# Procedure called to update DESC_RQ_DK when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DESC_RQ_DK { PARAM_VALUE.DESC_RQ_DK } {
	# Procedure called to validate DESC_RQ_DK
	return true
}

proc update_PARAM_VALUE.DESC_RQ_DW { PARAM_VALUE.DESC_RQ_DW } {
	# Procedure called to update DESC_RQ_DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DESC_RQ_DW { PARAM_VALUE.DESC_RQ_DW } {
	# Procedure called to validate DESC_RQ_DW
	return true
}

proc update_PARAM_VALUE.DISABLE_FRAME_INFO { PARAM_VALUE.DISABLE_FRAME_INFO } {
	# Procedure called to update DISABLE_FRAME_INFO when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DISABLE_FRAME_INFO { PARAM_VALUE.DISABLE_FRAME_INFO } {
	# Procedure called to validate DISABLE_FRAME_INFO
	return true
}

proc update_PARAM_VALUE.DW_LOG { PARAM_VALUE.DW_LOG } {
	# Procedure called to update DW_LOG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DW_LOG { PARAM_VALUE.DW_LOG } {
	# Procedure called to validate DW_LOG
	return true
}

proc update_PARAM_VALUE.ENABLE_FRAME_INFO_OUT { PARAM_VALUE.ENABLE_FRAME_INFO_OUT } {
	# Procedure called to update ENABLE_FRAME_INFO_OUT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENABLE_FRAME_INFO_OUT { PARAM_VALUE.ENABLE_FRAME_INFO_OUT } {
	# Procedure called to validate ENABLE_FRAME_INFO_OUT
	return true
}

proc update_PARAM_VALUE.FRAME_INFO_FIFO_DL { PARAM_VALUE.FRAME_INFO_FIFO_DL } {
	# Procedure called to update FRAME_INFO_FIFO_DL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FRAME_INFO_FIFO_DL { PARAM_VALUE.FRAME_INFO_FIFO_DL } {
	# Procedure called to validate FRAME_INFO_FIFO_DL
	return true
}

proc update_PARAM_VALUE.IGNORE_CPL_SIZE { PARAM_VALUE.IGNORE_CPL_SIZE } {
	# Procedure called to update IGNORE_CPL_SIZE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IGNORE_CPL_SIZE { PARAM_VALUE.IGNORE_CPL_SIZE } {
	# Procedure called to validate IGNORE_CPL_SIZE
	return true
}

proc update_PARAM_VALUE.IS_TX { PARAM_VALUE.IS_TX } {
	# Procedure called to update IS_TX when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IS_TX { PARAM_VALUE.IS_TX } {
	# Procedure called to validate IS_TX
	return true
}

proc update_PARAM_VALUE.KDIV { PARAM_VALUE.KDIV } {
	# Procedure called to update KDIV when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.KDIV { PARAM_VALUE.KDIV } {
	# Procedure called to validate KDIV
	return true
}

proc update_PARAM_VALUE.QESIZE_POS { PARAM_VALUE.QESIZE_POS } {
	# Procedure called to update QESIZE_POS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.QESIZE_POS { PARAM_VALUE.QESIZE_POS } {
	# Procedure called to validate QESIZE_POS
	return true
}

proc update_PARAM_VALUE.QEW_LOG { PARAM_VALUE.QEW_LOG } {
	# Procedure called to update QEW_LOG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.QEW_LOG { PARAM_VALUE.QEW_LOG } {
	# Procedure called to validate QEW_LOG
	return true
}

proc update_PARAM_VALUE.QUEUE_CHECK_TAG { PARAM_VALUE.QUEUE_CHECK_TAG } {
	# Procedure called to update QUEUE_CHECK_TAG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.QUEUE_CHECK_TAG { PARAM_VALUE.QUEUE_CHECK_TAG } {
	# Procedure called to validate QUEUE_CHECK_TAG
	return true
}

proc update_PARAM_VALUE.QUEUE_DL { PARAM_VALUE.QUEUE_DL } {
	# Procedure called to update QUEUE_DL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.QUEUE_DL { PARAM_VALUE.QUEUE_DL } {
	# Procedure called to validate QUEUE_DL
	return true
}

proc update_PARAM_VALUE.QUEUE_READ_TAG { PARAM_VALUE.QUEUE_READ_TAG } {
	# Procedure called to update QUEUE_READ_TAG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.QUEUE_READ_TAG { PARAM_VALUE.QUEUE_READ_TAG } {
	# Procedure called to validate QUEUE_READ_TAG
	return true
}

proc update_PARAM_VALUE.RCBASE { PARAM_VALUE.RCBASE } {
	# Procedure called to update RCBASE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RCBASE { PARAM_VALUE.RCBASE } {
	# Procedure called to validate RCBASE
	return true
}

proc update_PARAM_VALUE.REG_BASE { PARAM_VALUE.REG_BASE } {
	# Procedure called to update REG_BASE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.REG_BASE { PARAM_VALUE.REG_BASE } {
	# Procedure called to validate REG_BASE
	return true
}

proc update_PARAM_VALUE.RQBASE { PARAM_VALUE.RQBASE } {
	# Procedure called to update RQBASE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RQBASE { PARAM_VALUE.RQBASE } {
	# Procedure called to validate RQBASE
	return true
}

proc update_PARAM_VALUE.STS_FIFO_DL { PARAM_VALUE.STS_FIFO_DL } {
	# Procedure called to update STS_FIFO_DL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.STS_FIFO_DL { PARAM_VALUE.STS_FIFO_DL } {
	# Procedure called to validate STS_FIFO_DL
	return true
}

proc update_PARAM_VALUE.USE_ULTRA_RAM_VPMAP { PARAM_VALUE.USE_ULTRA_RAM_VPMAP } {
	# Procedure called to update USE_ULTRA_RAM_VPMAP when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.USE_ULTRA_RAM_VPMAP { PARAM_VALUE.USE_ULTRA_RAM_VPMAP } {
	# Procedure called to validate USE_ULTRA_RAM_VPMAP
	return true
}

proc update_PARAM_VALUE.VP_MAP_NUM_LOG { PARAM_VALUE.VP_MAP_NUM_LOG } {
	# Procedure called to update VP_MAP_NUM_LOG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VP_MAP_NUM_LOG { PARAM_VALUE.VP_MAP_NUM_LOG } {
	# Procedure called to validate VP_MAP_NUM_LOG
	return true
}


proc update_MODELPARAM_VALUE.REG_BASE { MODELPARAM_VALUE.REG_BASE PARAM_VALUE.REG_BASE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.REG_BASE}] ${MODELPARAM_VALUE.REG_BASE}
}

proc update_MODELPARAM_VALUE.DW_LOG { MODELPARAM_VALUE.DW_LOG PARAM_VALUE.DW_LOG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DW_LOG}] ${MODELPARAM_VALUE.DW_LOG}
}

proc update_MODELPARAM_VALUE.QEW_LOG { MODELPARAM_VALUE.QEW_LOG PARAM_VALUE.QEW_LOG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.QEW_LOG}] ${MODELPARAM_VALUE.QEW_LOG}
}

proc update_MODELPARAM_VALUE.VP_MAP_NUM_LOG { MODELPARAM_VALUE.VP_MAP_NUM_LOG PARAM_VALUE.VP_MAP_NUM_LOG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VP_MAP_NUM_LOG}] ${MODELPARAM_VALUE.VP_MAP_NUM_LOG}
}

proc update_MODELPARAM_VALUE.QUEUE_DL { MODELPARAM_VALUE.QUEUE_DL PARAM_VALUE.QUEUE_DL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.QUEUE_DL}] ${MODELPARAM_VALUE.QUEUE_DL}
}

proc update_MODELPARAM_VALUE.FRAME_INFO_FIFO_DL { MODELPARAM_VALUE.FRAME_INFO_FIFO_DL PARAM_VALUE.FRAME_INFO_FIFO_DL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FRAME_INFO_FIFO_DL}] ${MODELPARAM_VALUE.FRAME_INFO_FIFO_DL}
}

proc update_MODELPARAM_VALUE.DESC_BASE_FIFO_DL { MODELPARAM_VALUE.DESC_BASE_FIFO_DL PARAM_VALUE.DESC_BASE_FIFO_DL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DESC_BASE_FIFO_DL}] ${MODELPARAM_VALUE.DESC_BASE_FIFO_DL}
}

proc update_MODELPARAM_VALUE.DATA_FIFO_DL { MODELPARAM_VALUE.DATA_FIFO_DL PARAM_VALUE.DATA_FIFO_DL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_FIFO_DL}] ${MODELPARAM_VALUE.DATA_FIFO_DL}
}

proc update_MODELPARAM_VALUE.CPL_FIFO_DL { MODELPARAM_VALUE.CPL_FIFO_DL PARAM_VALUE.CPL_FIFO_DL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CPL_FIFO_DL}] ${MODELPARAM_VALUE.CPL_FIFO_DL}
}

proc update_MODELPARAM_VALUE.DESC_FIFO_DL { MODELPARAM_VALUE.DESC_FIFO_DL PARAM_VALUE.DESC_FIFO_DL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DESC_FIFO_DL}] ${MODELPARAM_VALUE.DESC_FIFO_DL}
}

proc update_MODELPARAM_VALUE.STS_FIFO_DL { MODELPARAM_VALUE.STS_FIFO_DL PARAM_VALUE.STS_FIFO_DL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.STS_FIFO_DL}] ${MODELPARAM_VALUE.STS_FIFO_DL}
}

proc update_MODELPARAM_VALUE.CH_NUM_LOG { MODELPARAM_VALUE.CH_NUM_LOG PARAM_VALUE.CH_NUM_LOG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CH_NUM_LOG}] ${MODELPARAM_VALUE.CH_NUM_LOG}
}

proc update_MODELPARAM_VALUE.CH_BASE { MODELPARAM_VALUE.CH_BASE PARAM_VALUE.CH_BASE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CH_BASE}] ${MODELPARAM_VALUE.CH_BASE}
}

proc update_MODELPARAM_VALUE.QUEUE_CHECK_TAG { MODELPARAM_VALUE.QUEUE_CHECK_TAG PARAM_VALUE.QUEUE_CHECK_TAG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.QUEUE_CHECK_TAG}] ${MODELPARAM_VALUE.QUEUE_CHECK_TAG}
}

proc update_MODELPARAM_VALUE.QUEUE_READ_TAG { MODELPARAM_VALUE.QUEUE_READ_TAG PARAM_VALUE.QUEUE_READ_TAG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.QUEUE_READ_TAG}] ${MODELPARAM_VALUE.QUEUE_READ_TAG}
}

proc update_MODELPARAM_VALUE.KDIV { MODELPARAM_VALUE.KDIV PARAM_VALUE.KDIV } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.KDIV}] ${MODELPARAM_VALUE.KDIV}
}

proc update_MODELPARAM_VALUE.DESC_MAX { MODELPARAM_VALUE.DESC_MAX PARAM_VALUE.DESC_MAX } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DESC_MAX}] ${MODELPARAM_VALUE.DESC_MAX}
}

proc update_MODELPARAM_VALUE.RCBASE { MODELPARAM_VALUE.RCBASE PARAM_VALUE.RCBASE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RCBASE}] ${MODELPARAM_VALUE.RCBASE}
}

proc update_MODELPARAM_VALUE.RQBASE { MODELPARAM_VALUE.RQBASE PARAM_VALUE.RQBASE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RQBASE}] ${MODELPARAM_VALUE.RQBASE}
}

proc update_MODELPARAM_VALUE.QESIZE_POS { MODELPARAM_VALUE.QESIZE_POS PARAM_VALUE.QESIZE_POS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.QESIZE_POS}] ${MODELPARAM_VALUE.QESIZE_POS}
}

proc update_MODELPARAM_VALUE.CH_POS { MODELPARAM_VALUE.CH_POS PARAM_VALUE.CH_POS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CH_POS}] ${MODELPARAM_VALUE.CH_POS}
}

proc update_MODELPARAM_VALUE.CPL_POS { MODELPARAM_VALUE.CPL_POS PARAM_VALUE.CPL_POS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CPL_POS}] ${MODELPARAM_VALUE.CPL_POS}
}

proc update_MODELPARAM_VALUE.BURST_MAX { MODELPARAM_VALUE.BURST_MAX PARAM_VALUE.BURST_MAX } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BURST_MAX}] ${MODELPARAM_VALUE.BURST_MAX}
}

proc update_MODELPARAM_VALUE.DESC_LEN { MODELPARAM_VALUE.DESC_LEN PARAM_VALUE.DESC_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DESC_LEN}] ${MODELPARAM_VALUE.DESC_LEN}
}

proc update_MODELPARAM_VALUE.DESC_RQ_DW { MODELPARAM_VALUE.DESC_RQ_DW PARAM_VALUE.DESC_RQ_DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DESC_RQ_DW}] ${MODELPARAM_VALUE.DESC_RQ_DW}
}

proc update_MODELPARAM_VALUE.DESC_RC_DW { MODELPARAM_VALUE.DESC_RC_DW PARAM_VALUE.DESC_RC_DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DESC_RC_DW}] ${MODELPARAM_VALUE.DESC_RC_DW}
}

proc update_MODELPARAM_VALUE.DESC_RQ_DK { MODELPARAM_VALUE.DESC_RQ_DK PARAM_VALUE.DESC_RQ_DK } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DESC_RQ_DK}] ${MODELPARAM_VALUE.DESC_RQ_DK}
}

proc update_MODELPARAM_VALUE.DESC_RC_DK { MODELPARAM_VALUE.DESC_RC_DK PARAM_VALUE.DESC_RC_DK } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DESC_RC_DK}] ${MODELPARAM_VALUE.DESC_RC_DK}
}

proc update_MODELPARAM_VALUE.D2D_AXI_BASE { MODELPARAM_VALUE.D2D_AXI_BASE PARAM_VALUE.D2D_AXI_BASE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.D2D_AXI_BASE}] ${MODELPARAM_VALUE.D2D_AXI_BASE}
}

proc update_MODELPARAM_VALUE.D2D_AXI_RANGE { MODELPARAM_VALUE.D2D_AXI_RANGE PARAM_VALUE.D2D_AXI_RANGE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.D2D_AXI_RANGE}] ${MODELPARAM_VALUE.D2D_AXI_RANGE}
}

proc update_MODELPARAM_VALUE.IS_TX { MODELPARAM_VALUE.IS_TX PARAM_VALUE.IS_TX } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IS_TX}] ${MODELPARAM_VALUE.IS_TX}
}

proc update_MODELPARAM_VALUE.DISABLE_FRAME_INFO { MODELPARAM_VALUE.DISABLE_FRAME_INFO PARAM_VALUE.DISABLE_FRAME_INFO } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DISABLE_FRAME_INFO}] ${MODELPARAM_VALUE.DISABLE_FRAME_INFO}
}

proc update_MODELPARAM_VALUE.ENABLE_FRAME_INFO_OUT { MODELPARAM_VALUE.ENABLE_FRAME_INFO_OUT PARAM_VALUE.ENABLE_FRAME_INFO_OUT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENABLE_FRAME_INFO_OUT}] ${MODELPARAM_VALUE.ENABLE_FRAME_INFO_OUT}
}

proc update_MODELPARAM_VALUE.IGNORE_CPL_SIZE { MODELPARAM_VALUE.IGNORE_CPL_SIZE PARAM_VALUE.IGNORE_CPL_SIZE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IGNORE_CPL_SIZE}] ${MODELPARAM_VALUE.IGNORE_CPL_SIZE}
}

proc update_MODELPARAM_VALUE.USE_ULTRA_RAM_VPMAP { MODELPARAM_VALUE.USE_ULTRA_RAM_VPMAP PARAM_VALUE.USE_ULTRA_RAM_VPMAP } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.USE_ULTRA_RAM_VPMAP}] ${MODELPARAM_VALUE.USE_ULTRA_RAM_VPMAP}
}

proc update_MODELPARAM_VALUE.ACTIVE_LOW_RESET_IN { MODELPARAM_VALUE.ACTIVE_LOW_RESET_IN PARAM_VALUE.ACTIVE_LOW_RESET_IN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ACTIVE_LOW_RESET_IN}] ${MODELPARAM_VALUE.ACTIVE_LOW_RESET_IN}
}

