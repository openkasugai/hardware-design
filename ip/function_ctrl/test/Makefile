#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

SRCV := function_ctrl.v

FUNC_BASE := ../../../functions
NOP_BASE := $(FUNC_BASE)/nop_st/
NOP_V_BASE := $(NOP_BASE)/nop_st/hls/impl/verilog
NOP_MM_BASE := $(FUNC_BASE)/nop_mm/
NOP_MM_V_BASE := $(NOP_MM_BASE)/nop_mm/hls/impl/verilog
EXT_SRCV := \
	../../common/src/axis_buf.v \
	../../common/src/packet_fifo.v \
	$(NOP_V_BASE)/nop_st.v \
	$(NOP_V_BASE)/nop_st_flow_control_loop_pipe.v \
	$(NOP_V_BASE)/nop_st_nop_core.v \
	$(NOP_V_BASE)/nop_st_hls_deadlock_idx0_monitor.v \
	$(NOP_V_BASE)/nop_st_hls_deadlock_idx1_monitor.v \
	$(NOP_V_BASE)/nop_st_regslice_both.v \
	$(NOP_BASE)/nop_st_wrapper.v \
	$(NOP_MM_V_BASE)/nop_mm.v \
	$(NOP_MM_V_BASE)/nop_mm_entry_proc.v \
	$(NOP_MM_V_BASE)/nop_mm_fifo_w1024_d128_A.v \
	$(NOP_MM_V_BASE)/nop_mm_fifo_w32_d3_S.v \
	$(NOP_MM_V_BASE)/nop_mm_fifo_w64_d4_S.v \
	$(NOP_MM_V_BASE)/nop_mm_flow_control_loop_pipe.v \
	$(NOP_MM_V_BASE)/nop_mm_flow_control_loop_pipe_sequential_init.v \
	$(NOP_MM_V_BASE)/nop_mm_hls_deadlock_detection_unit.v \
	$(NOP_MM_V_BASE)/nop_mm_mem_m_axi.v \
	$(NOP_MM_V_BASE)/nop_mm_nop_core.v \
	$(NOP_MM_V_BASE)/nop_mm_nop_read.v \
	$(NOP_MM_V_BASE)/nop_mm_nop_read_Pipeline_VITIS_LOOP_17_1.v \
	$(NOP_MM_V_BASE)/nop_mm_nop_write.v \
	$(NOP_MM_V_BASE)/nop_mm_nop_write_Pipeline_VITIS_LOOP_40_1.v \
	$(NOP_MM_V_BASE)/nop_mm_start_for_nop_core_U0.v \
	$(NOP_MM_V_BASE)/nop_mm_start_for_nop_write_U0.v \
	$(NOP_MM_BASE)/nop_mm_wrapper.v

TESTSV := ../../common/test/tb_util.sv \
	tb_function_ctrl_nop.sv \
	tb_function_ctrl_nop_wrapper.sv \
	tb_function_ctrl_nop_mm_wrapper.sv

SRCV_WD := $(addprefix ../src/,$(SRCV)) $(EXT_SRCV)

SCRIPT := "open_vcd vcd/FILE.vcd\nlog_vcd [get_object /*/*]\nrun all\nstop_vcd\nclose_vcd\nexit\n"

.PHONY: compile

all: all_tests

all_tests: nop_tests \
	nop_wrapper_tests \
	nop_mm_wrapper_tests

nop_tests : \
	test_nop_function_fast \
	test_nop_function_random \
	test_nop_function_slow_out

nop_wrapper_tests : \
	test_nop_function_wrapper_fast \
	test_nop_function_wrapper_random \
	test_nop_function_wrapper_slow_out

nop_mm_wrapper_tests : \
	test_nop_mm_function_wrapper_fast \
	test_nop_mm_function_wrapper_random \
	test_nop_mm_function_wrapper_slow_out

compile: $(SRCV_WD) $(TESTSV)
	@if [ ! -d logs ]; then mkdir logs; fi
	@xvlog -work func -log logs/compile.log $(SRCV_WD) > /dev/null
	@xvlog -work func -log logs/compile_tb.log -sv $(TESTSV) > /dev/null

test_%: compile
	@echo "\e[1m\e[32m[RUN]\e[0m $@"
	@xelab func.$@ -debug typical -log logs/elab_$@.log > /dev/null
	@echo $(SCRIPT) | sed 's/FILE/$@/g;' > xsim.dir/$@.tcl
	@if [ ! -d vcd ]; then mkdir vcd; fi
	@if [ ! -d wdb ]; then mkdir wdb; fi
	@xsim func.$@ -t xsim.dir/$@.tcl -log logs/sim_$@.log -wdb wdb/$@.wdb > /dev/null
	@if [ `grep -i fatal logs/sim_$@.log | wc -l` -ne 0 ]; then \
		echo "\e[1m\e[31m[FATAL]\e[0m $@"; \
	else if [ `grep -i error logs/sim_$@.log | wc -l` -ne 0 ]; then \
		echo "\e[1m\e[31m[ERROR]\e[0m $@"; \
	else \
		echo "\e[1m\e[32m[OK ]\e[0m $@"; \
	fi; fi

$(NOP_V_BASE)/nop_st.v:
	@make -C $(FUNC_BASE)/nop_st

clean:
	@rm -rf logs
	@rm -rf vcd
	@rm -rf wdb
	@rm -rf xsim.dir
	@rm -f *~
	@rm -f *.log
	@rm -f *.pb
	@rm -f *.jou
