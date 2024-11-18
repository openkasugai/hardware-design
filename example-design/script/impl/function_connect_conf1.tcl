#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

################################################################
# START
################################################################

  # Create interface connections
  connect_bd_intf_net -intf_net axi_interconnect_reg_1_M04_AXI [get_bd_intf_pins axi_interconnect_reg_1/M04_AXI] [get_bd_intf_pins function_0/s_axi_control_conv]
  connect_bd_intf_net -intf_net axi_interconnect_reg_1_M05_AXI [get_bd_intf_pins axi_interconnect_reg_1/M05_AXI] [get_bd_intf_pins function_1/s_axi_control_conv]
  connect_bd_intf_net -intf_net axi_interconnect_reg_1_M06_AXI [get_bd_intf_pins axi_interconnect_reg_1/M06_AXI] [get_bd_intf_pins function_0/s_axi_control_func]
  connect_bd_intf_net -intf_net axi_interconnect_reg_1_M07_AXI [get_bd_intf_pins axi_interconnect_reg_1/M07_AXI] [get_bd_intf_pins function_1/s_axi_control_func]
  connect_bd_intf_net -intf_net chain_m_axis_egr_rx_resp_0 [get_bd_intf_pins chain_1/m_axis_egr_resp] [get_bd_intf_pins function_1/s_axis_egr_resp]
  connect_bd_intf_net -intf_net chain_m_axis_egr_rx_resp_3 [get_bd_intf_pins chain_0/m_axis_egr_resp] [get_bd_intf_pins function_0/s_axis_egr_resp]
  connect_bd_intf_net -intf_net chain_m_axis_ingr_tx_data_0 [get_bd_intf_pins chain_1/m_axis_ingr_data] [get_bd_intf_pins function_1/s_axis_ingr_data]
  connect_bd_intf_net -intf_net chain_m_axis_ingr_tx_data_3 [get_bd_intf_pins chain_0/m_axis_ingr_data] [get_bd_intf_pins function_0/s_axis_ingr_data]
  connect_bd_intf_net -intf_net chain_m_axis_ingr_tx_req_0 [get_bd_intf_pins chain_1/m_axis_ingr_req] [get_bd_intf_pins function_1/s_axis_ingr_req]
  connect_bd_intf_net -intf_net chain_m_axis_ingr_tx_req_3 [get_bd_intf_pins chain_0/m_axis_ingr_req] [get_bd_intf_pins function_0/s_axis_ingr_req]
  connect_bd_intf_net -intf_net function_block_m_axis_egr_rx_data_0 [get_bd_intf_pins function_1/m_axis_egr_data] [get_bd_intf_pins chain_1/s_axis_egr_data]
  connect_bd_intf_net -intf_net function_block_m_axis_egr_rx_data_3 [get_bd_intf_pins function_0/m_axis_egr_data] [get_bd_intf_pins chain_0/s_axis_egr_data]
  connect_bd_intf_net -intf_net function_block_m_axis_egr_rx_req_0 [get_bd_intf_pins function_1/m_axis_egr_req] [get_bd_intf_pins chain_1/s_axis_egr_req]
  connect_bd_intf_net -intf_net function_block_m_axis_egr_rx_req_3 [get_bd_intf_pins function_0/m_axis_egr_req] [get_bd_intf_pins chain_0/s_axis_egr_req]
  connect_bd_intf_net -intf_net function_block_m_axis_ingr_tx_resp_0 [get_bd_intf_pins function_1/m_axis_ingr_resp] [get_bd_intf_pins chain_1/s_axis_ingr_resp]
  connect_bd_intf_net -intf_net function_block_m_axis_ingr_tx_resp_3 [get_bd_intf_pins function_0/m_axis_ingr_resp] [get_bd_intf_pins chain_0/s_axis_ingr_resp]
  connect_bd_intf_net -intf_net nw_chain_func_m_axi_ingr_frame_buffer_0_0 [get_bd_intf_pins function_0/m_axi_conv] [get_bd_intf_pins axi_interconnect_ddr1/S01_AXI]
  connect_bd_intf_net -intf_net nw_chain_func_m_axi_ingr_frame_buffer_0_0_0 [get_bd_intf_pins function_1/m_axi_conv] [get_bd_intf_pins axi_interconnect_ddr1/S02_AXI]
  ##connect_bd_net -net decouple_filter_1 [get_bd_pins fpga_reg_0/filter_1_decouple_enable] [get_bd_pins function_1/decouple_filter]
  ##connect_bd_net -net fpga_reg_0_conv_0_decouple_enable [get_bd_pins fpga_reg_0/conv_0_decouple_enable] [get_bd_pins function_0/decouple_conv]
  ##connect_bd_net -net fpga_reg_0_conv_1_decouple_enable [get_bd_pins fpga_reg_0/conv_1_decouple_enable] [get_bd_pins function_1/decouple_conv]
  ##connect_bd_net -net fpga_reg_0_filter_0_decouple_enable [get_bd_pins fpga_reg_0/filter_0_decouple_enable] [get_bd_pins function_0/decouple_filter]
  ##connect_bd_net -net function_0_dout [get_bd_pins function_0/decoupler_status] [get_bd_pins xlconcat_2/In0]
  ##connect_bd_net -net function_1_decoupler_status [get_bd_pins function_1/decoupler_status] [get_bd_pins xlconcat_2/In1]
  connect_bd_net -net nw_chain_func_detect_fault_0_1 [get_bd_pins function_0/detect_fault_conv] [get_bd_pins xlconcat_1/In2]
  connect_bd_net -net nw_chain_func_detect_fault_0_1_0 [get_bd_pins function_1/detect_fault_conv] [get_bd_pins xlconcat_1/In6]
  connect_bd_net -net nw_chain_func_detect_fault_1_1 [get_bd_pins function_0/detect_fault_func] [get_bd_pins xlconcat_1/In3]
  connect_bd_net -net nw_chain_func_detect_fault_1_1_0 [get_bd_pins function_1/detect_fault_func] [get_bd_pins xlconcat_1/In7]
  connect_bd_net -net proc_sys_reset_conv0_peripheral_aresetn [get_bd_pins proc_sys_reset_conv0/peripheral_aresetn] [get_bd_pins function_0/aresetn_mm_conv]
  connect_bd_net -net proc_sys_reset_conv1_peripheral_aresetn [get_bd_pins proc_sys_reset_conv1/peripheral_aresetn] [get_bd_pins function_1/aresetn_mm_conv]
  connect_bd_net -net proc_sys_reset_function0_peripheral_aresetn [get_bd_pins proc_sys_reset_filter0/peripheral_aresetn] [get_bd_pins function_0/aresetn_mm_filter]
  connect_bd_net -net proc_sys_reset_function1_peripheral_aresetn [get_bd_pins proc_sys_reset_filter1/peripheral_aresetn] [get_bd_pins function_1/aresetn_mm_filter]
  connect_bd_net [get_bd_pins clk_wiz_250_2_100/clk_out_pcie200] [get_bd_pins function_0/aclk_mm]
  connect_bd_net [get_bd_pins clk_wiz_250_2_100/clk_out_pcie200] [get_bd_pins function_1/aclk_mm]
  connect_bd_net [get_bd_pins xlconstant_2/dout] [get_bd_pins fpga_reg_0/decouple_status]

