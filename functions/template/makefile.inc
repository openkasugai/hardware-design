#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

#TOP :=
#VSRC :=
#CFG :=
#WRAPPER_PARAMS :=

VFLAGS := -c --mode hls --config $(CFG)
VFLAGS += -Isrc
TOP_V := $(TOP)/hls/impl/verilog/$(TOP).v

GEN_WRAPPER ?= ../../ip/function_ctrl/script/create_wrapper.py
WRAPPER_TEMPLATE ?= ../../ip/function_ctrl/template/function_wrapper_template.v
WRAPPER_PARAMS ?= --IPORT_NUM=1 --OPORT_NUM=1
CTRL_WRAPPER ?= $(TOP)_wrapper.v

all: verilog ctrl_wrapper

verilog: $(TOP_V)

$(TOP_V): $(VSRC)
	v++ $(VFLAGS) $(VSRC)

ctrl_wrapper: $(WRAPPER_TEMPLATE) $(CTRL_WRAPPER)

$(CTRL_WRAPPER) : $(WRAPPER_TEMPLATE) $(TOP_V)
	@python3 $(GEN_WRAPPER) -t $< -o $@ -f $(TOP_V) $(VERBOSE) $(WRAPPER_PARAMS)

clean:
	@rm -f *~
	@rm -f *.log
	@rm -rf $(CFG:%.cfg=%)
	@rm -f $(CTRL_WRAPPER)
