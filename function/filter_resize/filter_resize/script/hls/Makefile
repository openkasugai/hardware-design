#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

.PHONY: all clean

# Kernel version
# If not explicitly stated, use YYMMDDSS
# (SS avoids conflicts with other ROMs loaded on the same day)
KRNL_VERSION := $(shell date +"%y%m%d%S")

all: \
	data_in_krnl \
	data_out_krnl \
	filter_proc_krnl \
	resize_proc_krnl \
	filter_resize_id \
	fr_ingr_monitor_protocol_core \
	fr_egr_monitor_protocol_core

data_in_krnl: get-vitis-lib
	./ipgen.sh $@ ${KRNL_VERSION}

data_out_krnl: get-vitis-lib
	./ipgen.sh $@ ${KRNL_VERSION}

filter_proc_krnl: get-vitis-lib
	./ipgen.sh $@ ${KRNL_VERSION}

resize_proc_krnl: get-vitis-lib
	./ipgen.sh $@ ${KRNL_VERSION}

filter_resize_id:
	./ipgen.sh $@ ${KRNL_VERSION}

fr_ingr_monitor_protocol_core:
	./ipgen.sh $@ ${KRNL_VERSION}

fr_egr_monitor_protocol_core:
	./ipgen.sh $@ ${KRNL_VERSION}

clean:
	rm -rf *_prj
	rm -rf tmp_Vitis_Libraries
	rm -rf ../../src/hls/common/include
	rm -f tmp.*.tcl
	rm -f *.log

get-vitis-lib:
	rm -rf tmp_Vitis_Libraries
	git clone --branch 2021.2 --filter=blob:none https://github.com/Xilinx/Vitis_Libraries.git tmp_Vitis_Libraries
	cp -rf tmp_Vitis_Libraries/vision/L1/include ../../src/hls/common/
	patch ../../src/hls/common/include/imgproc/xf_median_blur.hpp xf_median_blur.patch
	patch ../../src/hls/common/include/imgproc/xf_resize.hpp xf_resize.patch
	patch ../../src/hls/common/include/imgproc/xf_resize_nn_bilinear.hpp xf_resize_nn_bilinear.patch
