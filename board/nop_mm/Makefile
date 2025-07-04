#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

TOP := ../..
PROJ_DIR := project_1
XPR := $(PROJ_DIR)/project_1.xpr
BD := $(PROJ_DIR)/project_1.srcs/sources_1/bd/design_1/design_1.bd
BRAM_COE := bram.coe

NOP_ST_TOP := ../../functions/nop_st
NOP_MM_TOP := ../../functions/nop_mm

CREATE_TCL := create_project.tcl
BUILD_TCL := build_design.tcl
IMPL_TCL := implement.tcl
GEN_COE := ../scripts/create_board_map.py

all: implement

implement: build
	@vivado -mode batch -source $(IMPL_TCL)

build: create $(BRAM_COE) nop_st nop_mm
	@if [ ! -e $(BD) ]; then \
		vivado -mode batch -source $(BUILD_TCL); \
	fi

create: ip
	@if [ ! -e $(XPR) ]; then \
		vivado -mode batch -source $(CREATE_TCL); \
	fi

$(BRAM_COE): design_1.tcl
	@python3 $(GEN_COE) -i $< -o $@

nop_st:
	@if [ ! -e $(NOP_ST_TOP)/nop_st_wrapper.v ]; then \
		make -C $(NOP_ST_TOP); \
	fi

nop_mm:
	@if [ ! -e $(NOP_MM_TOP)/nop_mm_wrapper.v ]; then \
		make -C $(NOP_MM_TOP); \
	fi

clean:
	@rm -rf $(PROJ_DIR)
	@rm -f $(BRAM_COE)
	@rm -rf .Xil
	@rm -f *.log
	@rm -f *.jou
	@rm -f *.str

include ../common.makefile
