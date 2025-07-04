#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

FNS_PLATFORM ?= xcu250-figd2104-2L-e 
FNS_PLATFORM_PART ?= xcu250-figd2104-2L-e
FNS_DATA_WIDTH ?= 64
FNS_TCP_STACK_MSS ?= 8960
TARGET_FREQ ?= 380MHz
OPERATING_FREQ ?= 322.265625
WINDOW_SCALE_BITS ?= 4
FNS_TCP_STACK_MAX_SESSIONS ?= 1000
TCL_APPEND ?= "create_clock -period ${TARGET_FREQ}"
VITIS_ROOT ?= $(shell which v++ | sed 's/\/bin\/v.*//;')
VITIS_VERSION := $(shell $(VITIS_ROOT)/bin/v++ -v | head -n 2 | tail -n 1 | awk -e '{print $$3}')
FNS_REVISION ?= 75c32bae73f5c336b5c46c9de35ae0cb9cb7cc1c
IP_NUM := $(shell ls fpga-network-stack/build/ip_repo/*/component.xml 2> /dev/null | wc -l || echo 0)

.PHONY: fpga_network_stack davos

all: build_ip

build_ip: fpga_network_stack davos check_vitis
	@if [ $(IP_NUM) -ne 10 ]; then \
		mkdir -p fpga-network-stack/build && \
		cd fpga-network-stack/build && \
		cmake -L -DFNS_PLATFORM=$(FNS_PLATFORM) -DFNS_PLATFORM_PART=$(FNS_PLATFORM_PART) \
		-DFNS_TCP_STACK_MSS=$(FNS_TCP_STACK_MSS) -DTCL_APPEND=$(TCL_APPEND) \
		-DFNS_TCP_STACK_MAX_SESSIONS=$(FNS_TCP_STACK_MAX_SESSIONS) \
		-DFNS_TCP_STACK_OPERATING_FREQ=$(OPERATING_FREQ) -DFNS_TCP_STACK_WINDOW_SCALE_BITS=$(WINDOW_SCALE_BITS) \
		-DFNS_DATA_WIDTH=$(FNS_DATA_WIDTH) -DVITIS_ROOT=$(VITIS_ROOT) .. && \
		make ip; \
	fi

fpga_network_stack:
	@if [ ! -d fpga-network-stack ]; then \
		git clone --recurse-submodules https://github.com/fpgasystems/fpga-network-stack.git && \
		cd fpga-network-stack && git checkout $(FNS_REVISION) && git submodule update && \
		patch -p 1 < ../fpga-network-stack.patch; \
	fi

davos:
	@if [ ! -d davos ]; then \
		git clone https://github.com/fpgasystems/davos.git; \
	fi

check_vitis:
	@if [ "$(VITIS_VERSION)" != "v2023.1" ] && \
		[ "$(VITIS_VERSION)" != "v2023.1.1" ]; then \
		echo Vivado 2023.1 needed.; \
		echo "$(VIVADO_VERSION)"; \
		exit 1;  \
	fi

clean:
	@echo using 'make cleanall'

cleanall:
	@rm -rf fpga-network-stack
	@rm -rf davos
