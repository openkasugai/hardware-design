#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

.PHONY: axi_reader axi_writer toe_wrapper external

all: axi_reader axi_writer toe_wrapper

axi_reader:
	@make -C axi_reader

axi_writer:
	@make -C axi_writer

toe_wrapper: external
	@make -C toe_wrapper

external:
	@make -C external

clean:
	@make -C axi_reader clean
	@make -C axi_writer clean
	@make -C toe_wrapper clean
