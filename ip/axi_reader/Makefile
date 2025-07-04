#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

VIVADO ?= `which vivado`
CREATE_TCL := create_ip.tcl
IP_NUM := $(shell find src -name "*.xci" | wc -l)

all: build

build: 
	@echo $(IP_NUM)
	@if [ $(IP_NUM) -ne 1 ]; then \
		$(VIVADO) -mode batch -source $(CREATE_TCL); \
	fi

clean:
	@rm -f *~
	@rm -rf src/datamover_for_reader
	@rm -f vivado*
	@rm -rf create_ip

