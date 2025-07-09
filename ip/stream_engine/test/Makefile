#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

SRCV := stream_engine_regs.v \
	stream_engine_queue_head_tail.v \
	stream_engine_queue_element.v \
	stream_engine_descriptor.v \
	stream_engine_transfer_cpl.v \
	stream_engine_core.v \
	calc_queue_info.v \
	xdma_wr_switch.v \
	xdma_rd_switch.v \
	xdma_ch_select.v \
	xdma_trx_descriptor.v \
	xdma_tx_switch.v \
	xdma_rx_switch.v \
	xdma_bypass_axi.v \
	xdma_rr_switch.v \
	axil_switch.v \
	stream_engine.v

EXT_SRCV := ../../common/src/fifo.v \
	../../common/src/ram_1rw_1r.v \
	../../common/src/axis_buf.v \
	../../common/src/ch_candidate.v \
        ../../common/src/ch_separate_fifo.v

TESTSV := ../../common/test/tb_util.sv \
	tb_regs.sv \
	tb_queue_head_tail.sv \
	tb_queue_element.sv \
	tb_descriptor.sv \
	tb_transfer_cpl.sv \
	tb_core.sv \
	tb_xdma_wr_switch.sv \
	tb_xdma_rd_switch.sv \
	tb_xdma_tx_switch.sv \
	tb_xdma_rx_switch.sv \
	tb_xdma_bypass_axi.sv \
	tb_axil_switch.sv \
	tb_stream_engine.sv \
	tb_ch_separate_fifo.sv

SRCV_WD := $(addprefix ../src/,$(SRCV)) $(EXT_SRCV)

SCRIPT := "open_vcd vcd/FILE.vcd\nlog_vcd [get_object /*/*]\nrun all\nstop_vcd\nclose_vcd\nexit\n"

.PHONY: compile

all: all_tests

all_tests: regs_tests \
	queue_head_tail_tests \
	queue_element_tests \
	descriptor_tests \
	transfer_cpl_tests \
	ch_separate_fifo_tests \
	core_tests \
	switch_tests \
	engine_tests

regs_tests : \
	test_regs_read_write_fixed \
	test_regs_read_write_random

queue_head_tail_tests : \
	test_queue_head_tail_initialize \
	test_queue_head_tail_update \
	test_queue_head_tail_update_max \
	test_queue_head_tail_update_fixed_ch \
	test_queue_head_tail_initialize_d2d \
	test_queue_head_tail_update_d2d

queue_element_tests : \
	test_queue_element_update \
	test_queue_element_frame_info_out \
	test_queue_element_frame_info_out_d2d

descriptor_tests : \
	test_descriptor_create \
	test_descriptor_create_full_vpmap \
	test_descriptor_create_with_frame_info \
	test_descriptor_create_with_frame_info_d2d

transfer_cpl_tests: \
	test_transfer_cpl_simple \
	test_transfer_cpl_simple2 \
	test_transfer_cpl_without_sent_size \
	test_transfer_cpl_simple_d2d

ch_separate_fifo_tests: \
	test_ch_separate_fifo_simple \
	test_ch_separate_fifo_slow_out \
	test_ch_separate_fifo_not_full

core_tests : \
	test_core_simple \
	test_core_simple2 \
	test_core_queue_full \
	test_core_restart \
	test_core_without_frame_info_restart \
	test_core_with_frame_info_out \
	test_core_simple_large_vpmap \
	test_core_simple_d2d

switch_tests : \
	test_xdma_wr_switch_fast \
	test_xdma_wr_switch_random \
	test_xdma_wr_switch_slow_in \
	test_xdma_wr_switch_slow_out \
	test_xdma_wr_switch_random_d2d_rx \
	test_xdma_rd_switch_fast \
	test_xdma_rd_switch_random \
	test_xdma_rd_switch_slow_in \
	test_xdma_rd_switch_slow_out \
	test_xdma_tx_switch_fast \
	test_xdma_tx_switch_random \
	test_xdma_tx_switch_slow_in \
	test_xdma_tx_switch_slow_out \
	test_xdma_bypass_axi_fast \
	test_xdma_bypass_axi_random \
	test_xdma_bypass_axi_slow_in \
	test_xdma_bypass_axi_slow_out \
	test_xdma_bypass_axi_random_data_read \
	test_axil_switch_fast \
	test_axil_switch_random \
	test_axil_switch_slow_in \
	test_axil_switch_slow_out

engine_tests : \
	test_all_simple \
	test_all_simple2 \
	test_all_simple3_slow_cpl_tail \
	test_all_simple_rx \
	test_all_simple_rx_1ch


compile: $(SRCV_WD) $(TESTSV)
	@if [ ! -d logs ]; then mkdir logs; fi
	@xvlog -work engine -log logs/compile.log $(SRCV_WD) > /dev/null
	@xvlog -work engine -log logs/compile_tb.log -sv $(TESTSV) > /dev/null

test_%: compile
	@echo "\e[1m\e[32m[RUN]\e[0m $@"
	@xelab engine.$@ -debug typical -log logs/elab_$@.log > /dev/null
	@echo $(SCRIPT) | sed 's/FILE/$@/g;' > xsim.dir/$@.tcl
	@if [ ! -d vcd ]; then mkdir vcd; fi
	@if [ ! -d wdb ]; then mkdir wdb; fi
	@xsim engine.$@ -t xsim.dir/$@.tcl -log logs/sim_$@.log -wdb wdb/$@.wdb > /dev/null
	@if [ `grep -i fatal logs/sim_$@.log | wc -l` -ne 0 ]; then \
		echo "\e[1m\e[31m[FATAL]\e[0m $@"; \
	else if [ `grep -i error logs/sim_$@.log | wc -l` -ne 0 ]; then \
		echo "\e[1m\e[31m[ERROR]\e[0m $@"; \
	else \
		echo "\e[1m\e[32m[OK ]\e[0m $@"; \
	fi; fi

clean:
	@rm -rf logs
	@rm -rf vcd
	@rm -rf wdb
	@rm -rf xsim.dir
	@rm -f *~
	@rm -f *.log
	@rm -f *.pb
	@rm -f *.jou
