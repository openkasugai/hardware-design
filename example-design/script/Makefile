#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

SHELL=/bin/bash

.PHONY: help

help:
	@echo "Makefile Usage:"
	@echo "  make all CONF=<config number>"
	@echo "      Command to generate bitstream for specified configuration."
	@echo "      CONF=1 : Filter/Resize Function Card (2Lane external-if #0 LLDMA, w/ direct trans)"
	@echo ""
	@echo "  make clean"
	@echo "      Command to remove the generated non-hardware files."
	@echo ""
	@echo "  make distclean"
	@echo "      Command to remove all the generated files in the current directory"
	@echo ""
	@echo "  make distcleanall"
	@echo "      Command to remove all the generated in the current directory and one level down"
	@echo ""

DEVICE ?= xilinx_u250_gen3x16_xdma_3_1_202020_1
SPEED ?= 25
CONF ?= 1

ifeq ($(CONF), 1)
USE_FIL := 1
USE_DTA := 1
endif

XSA := $(strip $(patsubst %.xpfm, % , $(shell basename $(DEVICE))))
TEMP_DIR := _x.$(XSA)

BOARD_DIR = tmp_XilinxBoardStore

CHAIN_CONTROL_DIR = ../../chain-control/chain_control/script/ip
DIRECT_TRANS_ADAPTOR_DIR = ../../chain-control/direct_trans_adaptor/script/ip
CONVERSION_ADAPTOR_DIR = ../../function/filter_resize/conversion_adaptor/script/ip
FILTER_RESIZE_DIR = ../../function/filter_resize/filter_resize/script/ip

LIST_XO = $(CHAIN_CONTROL_DIR)/chain_control.xo
ifeq ($(USE_DTA), 1)
LIST_XO += $(DIRECT_TRANS_ADAPTOR_DIR)/direct_trans_adaptor.xo
endif
ifeq ($(USE_FIL), 1)
LIST_XO += $(CONVERSION_ADAPTOR_DIR)/conversion_adaptor.xo
LIST_XO += $(FILTER_RESIZE_DIR)/filter_resize.xo
endif

.PHONY: all clean distclean distcleanall export-ip build-design run-impl check-devices
all: run-impl

# Cleaning stuff
clean:
	rm -rf *v++* *.log *.jou *.str

distclean: clean
	rm -rf _x* *.tmp.tcl *.tmp.ini .Xil .ipcache/ tmp_*/ project_1/ impl/ip/ip_repo/xilinx_com_*/ sim_model_prj/ export_sim/ $(BOARD_DIR)

distcleanall: distclean
	make -C $(CHAIN_CONTROL_DIR) -f Makefile.bd_top.mk clean
	make -C $(DIRECT_TRANS_ADAPTOR_DIR) -f Makefile.bd_top.mk clean
	make -C $(CONVERSION_ADAPTOR_DIR) -f Makefile.bd_top.mk clean
	make -C $(FILTER_RESIZE_DIR) -f Makefile.bd_top.mk clean

export-ip: $(LIST_XO)
	rm -rf tmp_ip
	mkdir -p tmp_ip
	mkdir -p impl/ip/ip_repo
	$(foreach ip,$^,unzip -o -d tmp_ip $(ip);)
	cp -rp tmp_ip/ip_repo/* impl/ip/ip_repo/.

build-design: export-ip $(BOARD_DIR)/boards/Xilinx/au250/1.3/board.xml
	vivado -mode batch -source create_project.tcl -tclargs $(BOARD_DIR)
	cd project_1 &&	\
	cp -ar ../impl/* ./ && \
	vivado -mode batch -source build_design.tcl -tclargs $(CONF)

run-impl: export-ip $(BOARD_DIR)/boards/Xilinx/au250/1.3/board.xml
	vivado -mode batch -source create_project.tcl -tclargs $(BOARD_DIR)
	cd project_1 &&	\
	cp -ar ../impl/* ./ && \
	vivado -mode batch -source build_design.tcl -tclargs $(CONF) && \
	vivado -mode batch -source implementation.tcl

check-devices:
ifndef DEVICE
	$(error DEVICE not set. Please set the DEVICE properly and rerun. Run "make help" for more details.)
endif

# Building kernel
$(FILTER_RESIZE_DIR)/%.xo:
	make -C $(FILTER_RESIZE_DIR) -f Makefile.bd_top.mk all

$(CONVERSION_ADAPTOR_DIR)/conversion_adaptor.xo:
	make -C $(CONVERSION_ADAPTOR_DIR) -f Makefile.bd_top.mk all

$(DIRECT_TRANS_ADAPTOR_DIR)/direct_trans_adaptor.xo:
	make -C $(DIRECT_TRANS_ADAPTOR_DIR) -f Makefile.bd_top.mk all

$(CHAIN_CONTROL_DIR)/chain_control.xo:
	make -C $(CHAIN_CONTROL_DIR) -f Makefile.bd_top.mk all

$(BOARD_DIR)/boards/Xilinx/au250/1.3/board.xml:
	rm -rf $(BOARD_DIR)
	git clone --branch 2020.3 --filter=blob:none https://github.com/Xilinx/XilinxBoardStore.git $(BOARD_DIR)
