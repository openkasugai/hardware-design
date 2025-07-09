#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

SRCV := axi_reader_ctrl.v

EXT_SRCV := ../../common/src/fifo.v \
	../../axi_writer/src/mc_fifo.v \
	../../axi_writer/src/dm_ctrl.v

TESTSV := tb_axi_reader_ctrl.sv \
	../../common/test/tb_util.sv

SRCV_WD := $(addprefix ../src/,$(SRCV)) $(EXT_SRCV)

SCRIPT := "open_vcd vcd/FILE.vcd\nlog_vcd [get_object /*/*]\nrun all\nstop_vcd\nclose_vcd\nexit\n"

.PHONY: compile

all: all_tests

all_tests: axi_reader_ctrl_tests

axi_reader_ctrl_tests : \
	test_axi_reader_ctrl_fast \
	test_axi_reader_ctrl_random \
	test_axi_reader_ctrl_random_slow_ctrl_in \
	test_axi_reader_ctrl_random_slow_ctrl_out \
	test_axi_reader_ctrl_fast_1ch \
	test_axi_reader_ctrl_random_1ch

compile: $(SRCV_WD) $(TESTSV)
	@if [ ! -d logs ]; then mkdir logs; fi
	@xvlog -work reader -log logs/compile.log $(SRCV_WD) > /dev/null
	@xvlog -work reader -log logs/compile_tb.log -sv $(TESTSV) > /dev/null

test_%: compile
	@echo "\e[1m\e[32m[RUN]\e[0m $@"
	@xelab reader.$@ -debug typical -log logs/elab_$@.log > /dev/null
	@echo $(SCRIPT) | sed 's/FILE/$@/g;' > xsim.dir/$@.tcl
	@if [ ! -d vcd ]; then mkdir vcd; fi
	@if [ ! -d wdb ]; then mkdir wdb; fi
	@xsim reader.$@ -t xsim.dir/$@.tcl -log logs/sim_$@.log -wdb wdb/$@.wdb > /dev/null
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
