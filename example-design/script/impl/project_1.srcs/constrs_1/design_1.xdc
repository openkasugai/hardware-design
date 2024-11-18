#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

# Bitstream Generation for QSPI
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property BITSTREAM.CONFIG.CONFIGFALLBACK Enable [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN disable [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
#set_property BITSTREAM.CONFIG.CONFIGRATE 85.0          [current_design]                 ;# Customer can try but may not be reliable over all conditions.
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR Yes [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]

set_property PACKAGE_PIN BA19 [get_ports satellite_uart_rxd]
set_property -dict {IOSTANDARD LVCMOS12} [get_ports satellite_uart_rxd]
set_property PACKAGE_PIN BB19 [get_ports satellite_uart_txd]
set_property -dict {IOSTANDARD LVCMOS12 DRIVE 4} [get_ports satellite_uart_txd]

set_property PACKAGE_PIN AR20 [get_ports {satellite_gpio[0]}]
set_property -dict {IOSTANDARD LVCMOS12} [get_ports {satellite_gpio[0]}]
set_property PACKAGE_PIN AM20 [get_ports {satellite_gpio[1]}]
set_property -dict {IOSTANDARD LVCMOS12} [get_ports {satellite_gpio[1]}]
set_property PACKAGE_PIN AM21 [get_ports {satellite_gpio[2]}]
set_property -dict {IOSTANDARD LVCMOS12} [get_ports {satellite_gpio[2]}]
set_property PACKAGE_PIN AN21 [get_ports {satellite_gpio[3]}]
set_property -dict {IOSTANDARD LVCMOS12} [get_ports {satellite_gpio[3]}]

# for u280
#set_property PACKAGE_PIN AR14 [get_ports {sys_clk_clk_n[0]}]
#set_property PACKAGE_PIN AR15 [get_ports {sys_clk_clk_p[0]}]
# for u250
set_property PACKAGE_PIN AM10 [get_ports {sys_clk_clk_n[0]}]
set_property PACKAGE_PIN AM11 [get_ports {sys_clk_clk_p[0]}]


## BCmarge

set_property -dict {PACKAGE_PIN AU21 IOSTANDARD LVCMOS12} [get_ports DDR4_RESET_GATE]

#create_clock -name qsfp0_161mhz_0_clk_p -period 6.211 [get_ports qsfp0_161mhz_0_clk_p]

# LVDS Input SYSTEM CLOCKS for Memory Interfaces
#
set_property -dict {PACKAGE_PIN AY38 IOSTANDARD LVDS} [get_ports default_300mhz_clk0_clk_n]
set_property -dict {PACKAGE_PIN AY37 IOSTANDARD LVDS} [get_ports default_300mhz_clk0_clk_p]
set_property -dict {PACKAGE_PIN AW19 IOSTANDARD LVDS} [get_ports default_300mhz_clk1_clk_n]
set_property -dict {PACKAGE_PIN AW20 IOSTANDARD LVDS} [get_ports default_300mhz_clk1_clk_p]
set_property -dict {PACKAGE_PIN E32 IOSTANDARD LVDS} [get_ports default_300mhz_clk2_clk_n]
set_property -dict {PACKAGE_PIN F32 IOSTANDARD LVDS} [get_ports default_300mhz_clk2_clk_p]
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVDS} [get_ports default_300mhz_clk3_clk_n]
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVDS} [get_ports default_300mhz_clk3_clk_p]

# QSFP0_CLOCK        -> MGT Ref Clock 1 User selectable by QSFP0_FS
#
#set_property PACKAGE_PIN K10 [get_ports qsfp0_161mhz_0_clk_n     ]; # Bank 231 Net "QSFP0_CLOCK_N"        - MGTREFCLK1N_231
#set_property PACKAGE_PIN K11 [get_ports qsfp0_161mhz_0_clk_p     ]; # Bank 231 Net "QSFP0_CLOCK_P"        - MGTREFCLK1P_231
set_property PACKAGE_PIN K10 [get_ports qsfp0_161mhz_clk_n]
set_property PACKAGE_PIN K11 [get_ports qsfp0_161mhz_clk_p]

set_property -dict {PACKAGE_PIN BE17 IOSTANDARD LVCMOS12} [get_ports QSFP0_RESETL]
set_property -dict {PACKAGE_PIN BE20 IOSTANDARD LVCMOS12} [get_ports QSFP0_MODPRSL]
set_property -dict {PACKAGE_PIN BE21 IOSTANDARD LVCMOS12} [get_ports QSFP0_INTL]
set_property -dict {PACKAGE_PIN BD18 IOSTANDARD LVCMOS12} [get_ports QSFP0_LPMODE]
set_property -dict {PACKAGE_PIN BE16 IOSTANDARD LVCMOS12} [get_ports QSFP0_MODSELL]

# SLR2 settings
create_pblock pblock_SLR2
add_cells_to_pblock [get_pblocks pblock_SLR2] [get_cells -quiet [list design_1_i/nw_chain_func/mac_krnl]]
resize_pblock [get_pblocks pblock_SLR2] -add {CLOCKREGION_X0Y8:CLOCKREGION_X7Y11}

# SLR1 settings
create_pblock pblock_SLR1
resize_pblock [get_pblocks pblock_SLR1] -add {CLOCKREGION_X0Y4:CLOCKREGION_X7Y7}
add_cells_to_pblock [get_pblocks pblock_SLR1] [get_cells -quiet [list design_1_i/lldma_wrapper_0/inst/lldma/PCI_TRX]]

# SLR0 settings
create_pblock pblock_SLR0
#add_cells_to_pblock [get_pblocks pblock_SLR0] [get_cells -quiet [list design_1_i/lldma_wrapper_0/inst/lldma/CIF_DN design_1_i/lldma_wrapper_0/inst/lldma/CIF_UP design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX design_1_i/lldma_wrapper_0/inst/lldma/DMA_TX]]
#add_cells_to_pblock [get_pblocks pblock_SLR0] [get_cells -quiet [list design_1_i/lldma_wrapper_0]]
add_cells_to_pblock [get_pblocks pblock_SLR0] [get_cells -quiet [list design_1_i/lldma_wrapper_0/inst/lldma/CIF_UP \
                                                                      design_1_i/lldma_wrapper_0/inst/lldma/CIF_DN \
                                                                      design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX \
                                                                      design_1_i/lldma_wrapper_0/inst/lldma/DMA_TX \
                                                                      design_1_i/lldma_wrapper_0/inst/lldma/RS]]
resize_pblock [get_pblocks pblock_SLR0] -add {CLOCKREGION_X0Y0:CLOCKREGION_X7Y3}

#TANDEM settings
set_property HD.TANDEM_IP_PBLOCK Stage1_IO [get_cells pcie_perstn_IBUF_inst/IBUFCTRL_INST]
set_property HD.TANDEM_IP_PBLOCK Stage1_IO [get_cells pcie_perstn_IBUF_inst/INBUF_INST]
resize_pblock design_1_i_pcie4_uscale_plus_0_inst_Stage1_cfgiob -add {SLICE_X122Y300:SLICE_X124Y359 DSP48E2_X16Y120:DSP48E2_X16Y143} -locs keep_all -replace
add_cells_to_pblock design_1_i_pcie4_uscale_plus_0_inst_design_1_pcie4_uscale_plus_0_0_Stage1_main [get_cells [list dbg_hub]] -clear_locs
add_cells_to_pblock design_1_i_pcie4_uscale_plus_0_inst_design_1_pcie4_uscale_plus_0_0_Stage1_main [get_cells [list pcie_perstn_IBUF_inst]] -clear_locs
set_property HD.TANDEM 1 [get_cells dbg_hub]
set_property HD.TANDEM_IP_PBLOCK Stage1_Main [get_cells dbg_hub]
set_property BITSTREAM.STARTUP.MATCH_CYCLE NoWait [current_design]

#QSFP CMS
#set_property PACKAGE_PIN BE16      [get_ports qsfp0_modsel_l_0[0]  ]
#set_property IOSTANDARD  LVCMOS12  [get_ports qsfp0_modsel_l_0[0]  ]
#set_property PACKAGE_PIN BE17      [get_ports qsfp0_reset_l_0[0]   ]
#set_property IOSTANDARD  LVCMOS12  [get_ports qsfp0_reset_l_0[0]   ]
#set_property PACKAGE_PIN BD18      [get_ports qsfp0_lpmode_0[0]    ]
#set_property IOSTANDARD  LVCMOS12  [get_ports qsfp0_lpmode_0[0]    ]
#set_property PACKAGE_PIN BE20      [get_ports qsfp0_modprs_l_0[0]  ]
#set_property IOSTANDARD  LVCMOS12  [get_ports qsfp0_modprs_l_0[0]  ]
#set_property PACKAGE_PIN BE21      [get_ports qsfp0_int_l_0[0]     ]
#set_property IOSTANDARD  LVCMOS12  [get_ports qsfp0_int_l_0[0]     ]
#
#set_property PACKAGE_PIN AY20      [get_ports qsfp1_modsel_l_0[0]  ]
#set_property IOSTANDARD  LVCMOS12  [get_ports qsfp1_modsel_l_0[0]  ]
#set_property PACKAGE_PIN BC18      [get_ports qsfp1_reset_l_0[0]   ]
#set_property IOSTANDARD  LVCMOS12  [get_ports qsfp1_reset_l_0[0]   ]
#set_property PACKAGE_PIN AV22      [get_ports qsfp1_lpmode_0[0]    ]
#set_property IOSTANDARD  LVCMOS12  [get_ports qsfp1_lpmode_0[0]    ]
#set_property PACKAGE_PIN BC19      [get_ports qsfp1_modprs_l_0[0]  ]
#set_property IOSTANDARD  LVCMOS12  [get_ports qsfp1_modprs_l_0[0]  ]
#set_property PACKAGE_PIN AV21      [get_ports qsfp1_int_l_0[0]     ]
#set_property IOSTANDARD  LVCMOS12  [get_ports qsfp1_int_l_0[0]     ]

set_false_path -to design_1_i/fpga_reg_0/inst/r_reg_detect_fault_reg*
set_false_path -to design_1_i/fpga_reg_0/inst/r_reg_clock_down_raw_reg*

set_false_path -from design_1_i/fpga_reg_0/inst/r_reg_soft_reset_ext_reg*
set_false_path -from design_1_i/fpga_reg_0/inst/r_reg_dfx_soft_reset_ext_reg*

set_false_path -from design_1_i/fpga_reg_0/inst/r_reg_decouple_enable_reg*
set_false_path -to design_1_i/fpga_reg_0/inst/r_reg_decouple_status_reg*

# false settings
set_false_path -from design_1_i/pcie4_uscale_plus_0/inst/user_reset_reg/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[0][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[0][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[0][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[1][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[1][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[1][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[2][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[2][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[2][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[3][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[3][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[3][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[4][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[4][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[4][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[5][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[5][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[5][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[6][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[6][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[6][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[7][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[7][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[7][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[8][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[8][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[8][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[9][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[9][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[9][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[10][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[10][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[10][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[11][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[11][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[11][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[12][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[12][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[12][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[13][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[13][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[13][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[14][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[14][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[14][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[15][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[15][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[15][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[16][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[16][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[16][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[17][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[17][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[17][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[18][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[18][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[18][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[19][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[19][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[19][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[20][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[20][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[20][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[21][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[21][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[21][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[22][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[22][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[22][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[23][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[23][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[23][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[24][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[24][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[24][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[25][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[25][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[25][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[26][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[26][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[26][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[27][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[27][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[27][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[28][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[28][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[28][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[29][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[29][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[29][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[30][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[30][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[30][2]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[31][0]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[31][1]/C
set_false_path -from design_1_i/lldma_wrapper_0/inst/lldma/DMA_RX/ENQDEQ/ch_mode_reg[31][2]/C


create_clock -period 10.000 -name {sys_clk_clk_p[0]} -waveform {0.000 5.000} [get_ports {sys_clk_clk_p[0]}]
create_clock -period 4.000 -name VIRTUAL_clk -waveform {0.000 2.000}
create_clock -period 3.332 -name default_300mhz_clk0_clk_p [get_ports default_300mhz_clk0_clk_p]
create_clock -period 3.332 -name default_300mhz_clk1_clk_p [get_ports default_300mhz_clk1_clk_p]
create_clock -period 3.332 -name default_300mhz_clk2_clk_p [get_ports default_300mhz_clk2_clk_p]
create_clock -period 3.332 -name default_300mhz_clk3_clk_p [get_ports default_300mhz_clk3_clk_p]
create_clock -period 6.211 -name qsfp0_161mhz_clk_p [get_ports qsfp0_161mhz_clk_p]

####################################################################################
# Constraints from file : 'design_1_axilite_register_slice_4_5_clocks.xdc'
####################################################################################

set_property IOSTANDARD LVCMOS12 [get_ports pcie_perstn]



set_property PACKAGE_PIN BD21 [get_ports pcie_perstn]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk]
