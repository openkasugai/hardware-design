#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

.PHONY: nop_and_vec_fp_inc nop_minimum nop_mm nop_toe

all: nop_and_vec_fp_inc

nop_and_vec_fp_inc:
	@make -C nop_and_vec_fp_inc

nop_minimum:
	@make -C nop_minimum

nop_mm:
	@make -C nop_mm

nop_toe:
	@make -C nop_toe

clean:
	@echo realy? use make clean_bitstreams

clean_bitstreams:
	@make -C nop_minimum clean
	@make -C nop_mm clean
	@make -C nop_and_vec_fp_inc clean
	@make -C nop_toe clean

