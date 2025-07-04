#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

SRCV := incoming_route_controller.v \
	outgoing_route_controller.v \
	route_control_regs.v \
	route_control_reg_switch.v \
	route_controller.v

EXT_SRCV := ../../common/src/fifo.v \
	../../common/src/axis_buf.v \
	../../common/src/bit_counts.v

TESTSV := tb_incoming_route_controller.sv \
	tb_outgoing_route_controller.sv \
	tb_reg_switch.sv \
	tb_route_controller.sv

SRCV_WD := $(addprefix ../src/,$(SRCV)) $(EXT_SRCV)

SCRIPT := "open_vcd vcd/FILE.vcd\nlog_vcd [get_object /*/*]\nrun all\nstop_vcd\nclose_vcd\nexit\n"

.PHONY: compile

all: all_tests

all_tests: incoming_tests \
	outgoing_tests \
	reg_switch_tests \
	route_controller_tests

incoming_tests : \
	test_incoming_route_controller_random_fast \
	test_incoming_route_controller_random \
	test_incoming_route_controller_mmapped_fast \
	test_incoming_route_controller_mmapped_random \
	test_incoming_route_controller_mmapped_random_2frames

outgoing_tests : \
	test_outgoing_route_controller_random_fast \
	test_outgoing_route_controller_random \
	test_outgoing_route_controller_random_slow_ctrl \
	test_outgoing_route_controller_mmapped_fast \
	test_outgoing_route_controller_mmapped_random \
	test_outgoing_route_controller_mmapped_random_2frames

reg_switch_tests : \
	test_reg_switch_fast \
	test_reg_switch_random

route_controller_tests: \
	test_route_controller_fast \
	test_route_controller_random

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
