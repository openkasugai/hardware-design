#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

VIVADO_VER ?= $(shell vivado -version | head -n 1 | awk -F ' ' -e '{print $$2;}')

all: create_ip

create_ip:
	@if [ ! -e component.xml ]; then \
		vivado -mode batch -source create_ip.tcl; \
	fi

clean:
	@rm -rf toe_network
	@rm -f component.xml
	@rm -rf xgui
	@rm -f *.jou
	@rm -f *.log
