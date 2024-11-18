#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

.PHONY: all ipgen package clean

KERNEL_NAME = chain_control
CONF ?= 3

CPP_LIST := $(wildcard *.cpp)
HPP_LIST := $(wildcard *.hpp)

all: $(KERNEL_NAME).xo

$(KERNEL_NAME).xo: ipgen package

# Compile and package each function
ipgen:
	make -j8 -C ../hls all

# Generate kernel
package:
	# Register definition
	./print_registers.sh > tmp.registers.tcl
	# Generate kernel
	vivado \
		-mode batch \
		-source package_kernel.bd_top.tcl \
		-tclargs \
			$(KERNEL_NAME).xo \
			$(KERNEL_NAME) \
			$(CONF)

clean:
	rm -f *.xo
	rm -f *.log
	rm -f *.jou
	rm -f tmp.*.tcl
	rm -rf pack_${KERNEL_NAME}
	rm -rf tmp_${KERNEL_NAME}
	rm -rf .Xil
	rm -rf ../src
	make -C ../hls clean
