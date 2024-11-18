#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

if { $::argc != 1 } {
    error "ERROR: Program \"$::argv0\" requires 1 arguments!, (${argc} given)\n"
}
set conf [lindex $::argv 0]

# Select configuration
set bd_design_file "bd_design_conf${conf}.tcl"
set bd_address_file "bd_address_conf${conf}.csv"
set design_wrapper_file "design_1_wrapper_conf${conf}.v"

set project_name "project_1"
set project_directory "../${project_name}"

# Open project
open_project $project_name

# Specify IP repository path
update_ip_catalog -rebuild
set_property  ip_repo_paths  $project_directory/ip/ip_repo [current_project]
update_ip_catalog

# Add source
add_files -norecurse "project_1.srcs/sources_1/$design_wrapper_file"
add_files -norecurse {\
../../../external-if/LLDMA/src/hdl/CIF/cif_arb.sv \
../../../external-if/LLDMA/src/hdl/CIF/cif_clktr.sv \
../../../external-if/LLDMA/src/hdl/CIF/cif_dn.sv \
../../../external-if/LLDMA/src/hdl/CIF/cif_dn_chainx.sv \
../../../external-if/LLDMA/src/hdl/CIF/cif_dn_chx.sv \
../../../external-if/LLDMA/src/hdl/CIF/cif_dn_chx_gd.sv \
../../../external-if/LLDMA/src/hdl/CIF/cif_dn_data_in.sv \
../../../external-if/LLDMA/src/hdl/CIF/cif_up.sv \
../../../external-if/LLDMA/src/hdl/CIF/cif_up_chainx.sv \
../../../external-if/LLDMA/src/hdl/CIF/cifd_reg.sv \
../../../external-if/LLDMA/src/hdl/CIF/cifu_reg.sv}
add_files -norecurse {\
../../../external-if/LLDMA/src/hdl/COMMON/axi_lite_end_point.sv \
../../../external-if/LLDMA/src/hdl/COMMON/enqdeq.sv \
../../../external-if/LLDMA/src/hdl/COMMON/enqdeq_arb.sv \
../../../external-if/LLDMA/src/hdl/COMMON/eve_arbter.sv \
../../../external-if/LLDMA/src/hdl/COMMON/eve_arbter_hub.sv \
../../../external-if/LLDMA/src/hdl/COMMON/indirect_reg_access.v \
../../../external-if/LLDMA/src/hdl/COMMON/pa_cnt.sv \
../../../external-if/LLDMA/src/hdl/COMMON/pa_cnt3.sv \
../../../external-if/LLDMA/src/hdl/COMMON/pa_cnt3_wrapper.sv \
../../../external-if/LLDMA/src/hdl/COMMON/pci_mon_wire.v \
../../../external-if/LLDMA/src/hdl/COMMON/pci_pa_count.v \
../../../external-if/LLDMA/src/hdl/COMMON/rs.sv \
../../../external-if/LLDMA/src/hdl/COMMON/rs_cmdeve.sv \
../../../external-if/LLDMA/src/hdl/COMMON/rs_ddr_r.sv \
../../../external-if/LLDMA/src/hdl/COMMON/rs_ddr_w.sv \
../../../external-if/LLDMA/src/hdl/COMMON/rs_pcie.sv \
../../../external-if/LLDMA/src/hdl/COMMON/rs_type4.sv \
../../../external-if/LLDMA/src/hdl/COMMON/trace_ram.sv}
add_files -norecurse {\
../../../external-if/LLDMA/src/hdl/DMA_RX/dma_rx.sv \
../../../external-if/LLDMA/src/hdl/DMA_RX/dma_rx_ch.sv \
../../../external-if/LLDMA/src/hdl/DMA_RX/dma_rx_ch_gh.sv \
../../../external-if/LLDMA/src/hdl/DMA_RX/dma_rx_fifo.sv \
../../../external-if/LLDMA/src/hdl/DMA_RX/dma_rx_ch_sel.sv}
add_files -norecurse {\
../../../external-if/LLDMA/src/hdl/DMA_TX/dma_tx.sv \
../../../external-if/LLDMA/src/hdl/DMA_TX/dma_tx_arb.sv \
../../../external-if/LLDMA/src/hdl/DMA_TX/dma_tx_chain.sv \
../../../external-if/LLDMA/src/hdl/DMA_TX/dma_tx_ctrl.sv \
../../../external-if/LLDMA/src/hdl/DMA_TX/dma_tx_deq.sv \
../../../external-if/LLDMA/src/hdl/DMA_TX/dma_tx_dsc.sv \
../../../external-if/LLDMA/src/hdl/DMA_TX/dma_tx_fifo.sv \
../../../external-if/LLDMA/src/hdl/DMA_TX/dma_tx_int.sv \
../../../external-if/LLDMA/src/hdl/DMA_TX/dma_tx_mux.sv \
../../../external-if/LLDMA/src/hdl/DMA_TX/dma_tx_que.sv \
../../../external-if/LLDMA/src/hdl/DMA_TX/dma_tx_reg.sv}
add_files -norecurse {\
../../../external-if/LLDMA/src/hdl/PCI_TRX/checker_axi_lite_end_point.sv \
../../../external-if/LLDMA/src/hdl/PCI_TRX/cwr_keep_gen.sv \
../../../external-if/LLDMA/src/hdl/PCI_TRX/data_receive.sv \
../../../external-if/LLDMA/src/hdl/PCI_TRX/pci_trx.v \
../../../external-if/LLDMA/src/hdl/PCI_TRX/pio_ep_mem_access.v \
../../../external-if/LLDMA/src/hdl/PCI_TRX/pio_intr_ctrl.v \
../../../external-if/LLDMA/src/hdl/PCI_TRX/pio_mem_fifo.v \
../../../external-if/LLDMA/src/hdl/PCI_TRX/pio_to_ctrl.v \
../../../external-if/LLDMA/src/hdl/PCI_TRX/pio_tx_arbiter.v \
../../../external-if/LLDMA/src/hdl/PCI_TRX/pio_tx_engine.v \
../../../external-if/LLDMA/src/hdl/PCI_TRX/pio_tx_fifo.v \
../../../external-if/LLDMA/src/hdl/PCI_TRX/pio_tx_rrb.v}
add_files -norecurse {\
../../../external-if/LLDMA/src/hdl/TOP/lldma.sv \
../../../external-if/LLDMA/src/hdl/TOP/lldma_wrapper.v}
add_files -norecurse {\
../../pci_conversion/src/hdl/axis2axi_bridge.v}
add_files -norecurse {\
../../fpga_reg/src/hdl/fpga_reg.v}
add_files -norecurse {\
../../../function/filter_resize/decoupler/src/hdl/axi4l_decoupler.v}
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1
update_compile_order -fileset sources_1
# Add IP
add_files -norecurse {\
../../../external-if/LLDMA/src/ip/cif_buf1/cif_buf1.xci \
../../../external-if/LLDMA/src/ip/cif_buf2/cif_buf2.xci \
../../../external-if/LLDMA/src/ip/cif_buf3/cif_buf3.xci \
../../../external-if/LLDMA/src/ip/cif_cmdi_fifo/cif_cmdi_fifo.xci \
../../../external-if/LLDMA/src/ip/cif_eve_fifo/cif_eve_fifo.xci \
../../../external-if/LLDMA/src/ip/cif_evei_fifo/cif_evei_fifo.xci \
../../../external-if/LLDMA/src/ip/cif_eveo_fifo/cif_eveo_fifo.xci \
../../../external-if/LLDMA/src/ip/cif_sb_fifo/cif_sb_fifo.xci \
../../../external-if/LLDMA/src/ip/design_1_fifo_generator_0_0/design_1_fifo_generator_0_0.xci \
../../../external-if/LLDMA/src/ip/DMA_BUF_128K/DMA_BUF_128K.xci \
../../../external-if/LLDMA/src/ip/enqc_dsc_fifo1_0/enqc_dsc_fifo1_0.xci \
../../../external-if/LLDMA/src/ip/enqc_fpga_info_mem1_0/enqc_fpga_info_mem1_0.xci \
../../../external-if/LLDMA/src/ip/enqc_next_table_mem1_0/enqc_next_table_mem1_0.xci \
../../../external-if/LLDMA/src/ip/pcie4c_uscale_plus_0_i/pcie4c_uscale_plus_0_i.xci \
../../../external-if/LLDMA/src/ip/TRACE_4K/TRACE_4K.xci}
update_compile_order -fileset sources_1

# Add constraint
add_files -fileset constrs_1 -norecurse $project_directory/project_1.srcs/constrs_1/design_1.xdc

# Create block design
create_bd_design "design_1"
source $bd_design_file

# Re-assign address
## The range in the address assignment is wrong and causes an error (the range is listed in tcl, but is it a tool bug?)
assign_bd_address -import_from_file $bd_address_file

# Re-setting clock frequency
## Parameter settings such as frequency are also off.
source clock_set.tcl

# Apply constraint
set_property target_constrs_file $project_directory/project_1.srcs/constrs_1/design_1.xdc [current_fileset -constrset]

# Save block design
save_bd_design
update_compile_order -fileset sources_1

# Close project
close_project

