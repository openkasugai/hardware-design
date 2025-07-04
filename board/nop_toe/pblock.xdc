#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

create_pblock pblock_toe
add_cells_to_pblock [get_pblocks pblock_toe] [get_cells -quiet [list design_1_i/cmac_usplus_0 design_1_i/ddr4_2 design_1_i/proc_sys_reset_ddr2 design_1_i/proc_sys_reset_toe design_1_i/proc_sys_reset_toe_rx design_1_i/proc_sys_reset_toe_tx design_1_i/toe_network_0]]
resize_pblock [get_pblocks pblock_toe] -add {SLR2}
#add_cells_to_pblock [get_pblocks pblock_toe] [get_cells -quiet [list design_1_i/toe_ctrl_0 design_1_i/route_controller_1]]

#create_pblock pblock_toe_ctrl
#add_cells_to_pblock [get_pblocks pblock_toe_ctrl] [get_cells -quiet [list design_1_i/toe_ctrl_0 design_1_i/route_controller_1]]
#resize_pblock [get_pblocks pblock_toe_ctrl] -add {CLOCKREGION_X5Y8:CLOCKREGION_X7Y11}
#resize_pblock [get_pblocks pblock_toe_ctrl] -add {CLOCKREGION_X4Y8:CLOCKREGION_X4Y8}

create_pblock pblock_xdma
add_cells_to_pblock [get_pblocks pblock_xdma] [get_cells -quiet [list design_1_i/axi_bram_ctrl_0 design_1_i/cms_subsystem_0 design_1_i/route_controller_0 design_1_i/route_controller_1 design_1_i/stream_engine_rx design_1_i/stream_engine_tx design_1_i/toe_ctrl_0 design_1_i/xdma_0]]
resize_pblock [get_pblocks pblock_xdma] -add {SLR1}

#set_property -dict {PACKAGE_PIN BE16 IOSTANDARD LVCMOS12} [get_ports qsfp0_modsel_l_0]
#set_property -dict {PACKAGE_PIN BE20 IOSTANDARD LVCMOS12} [get_ports qsfp0_modprs_l_0]
#set_property -dict {PACKAGE_PIN BE21 IOSTANDARD LVCMOS12} [get_ports qsfp0_int_l_0]
set_property -dict {PACKAGE_PIN BD18 IOSTANDARD LVCMOS12} [get_ports qsfp0_lp_mode_0]
set_property -dict {PACKAGE_PIN BE17 IOSTANDARD LVCMOS12} [get_ports qsfp0_reset_l_0]

set_property PACKAGE_PIN BA19 [get_ports satellite_uart_0_rxd]
set_property -dict {IOSTANDARD LVCMOS12} [get_ports satellite_uart_0_rxd]
set_property PACKAGE_PIN BB19 [get_ports satellite_uart_0_txd]
set_property -dict {IOSTANDARD LVCMOS12 DRIVE 4} [get_ports satellite_uart_0_txd]

set_property PACKAGE_PIN AR20 [get_ports {satellite_gpio_0[0]}]
set_property IOSTANDARD LVCMOS12 [get_ports {satellite_gpio_0[0]}]
set_property PACKAGE_PIN AM20 [get_ports {satellite_gpio_0[1]}]
set_property IOSTANDARD LVCMOS12 [get_ports {satellite_gpio_0[1]}]
set_property PACKAGE_PIN AM21 [get_ports {satellite_gpio_0[2]}]
set_property IOSTANDARD LVCMOS12 [get_ports {satellite_gpio_0[2]}]
set_property PACKAGE_PIN AN21 [get_ports {satellite_gpio_0[3]}]
set_property IOSTANDARD LVCMOS12 [get_ports {satellite_gpio_0[3]}]



