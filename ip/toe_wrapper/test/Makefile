#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

SRCV := network_ip_ctrl.v \
	toe_ctrl_regs.v \
	toe_ctrl_ch_reg.v \
	toe_ctrl_rx.v \
	toe_ctrl_tx.v \
	toe_ctrl.v

EXT_SRCV := ../../common/src/fifo.v \
	    ../../common/src/packet_fifo.v \
	    ../../common/src/ch_candidate.v \
	    ../../common/src/ch_separate_fifo.v \
	    ../../common/src/bit_counts.v \
	    ../../common/src/axis_buf.v

TESTSV := tb_network_ip_ctrl.sv \
	  tb_toe_ctrl_regs.sv \
	  tb_toe_ctrl_rx.sv \
	  tb_toe_ctrl_tx.sv \
	  tb_toe_ctrl.sv \
	  ../../common/test/tb_util.sv

SRCV_WD := $(addprefix ../src/,$(SRCV)) $(EXT_SRCV)

SCRIPT := "open_vcd vcd/FILE.vcd\nlog_vcd [get_object /*/*]\nrun all\nstop_vcd\nclose_vcd\nexit\n"

.PHONY: compile

all: all_tests

all_tests: regs_tests \
	toe_ctrl_regs_tests \
	toe_ctrl_rx_tests \
	toe_ctrl_tx_tests \
	toe_ctrl_tests

regs_tests : \
	test_reg_read \
	test_reg_write \
	test_open_close \
	test_listen_close \
	test_open_rx \
	test_listen_rx \
	test_open_tx \
	test_listen_tx \
	test_notifications

toe_ctrl_regs_tests : \
	test_toe_ctrl_regs_read_write_simple \
	test_toe_ctrl_regs_read_write_activates \
	test_toe_ctrl_regs_read_write_activates2

toe_ctrl_rx_tests : \
	test_toe_ctrl_rx_fast \
	test_toe_ctrl_rx_random \
	test_toe_ctrl_rx_slow_frame_info \
	test_toe_ctrl_rx_random_concat \
	test_toe_ctrl_rx_random_1ch \
	test_toe_ctrl_rx_random_1ch_aligned \
	test_toe_ctrl_rx_random_1ch_aligned_concat \
	test_toe_ctrl_rx_fast_1ch_aligned_concat_rare

toe_ctrl_tx_tests : \
	test_toe_ctrl_tx_fast \
	test_toe_ctrl_tx_random \
	test_toe_ctrl_tx_slow_frame_info \
	test_toe_ctrl_tx_random_1ch

toe_ctrl_tests : \
	test_toe_ctrl_fast \
	test_toe_ctrl_random \
	test_toe_ctrl_slow_frame_info \
	test_toe_ctrl_random_concat \
	test_toe_ctrl_random_1ch

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
