#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

VSRC := src/nop_mm.cpp
CFG := nop_mm.cfg
TOP := nop_mm

WRAPPER_PARAMS := --IPORT_NUM=1 --OPORT_NUM=1
WRAPPER_PARAMS += --bind func_out_updated_size_0=func_in_size_0 --bind func_out_updated_addr_0=func_out_addr_0
WRAPPER_PARAMS += --bind "func_out_updated_valid_0=in_frame_consume_0_tvalid & in_frame_consume_0_tready"
#WRAPPER_PARAMS += --OPORT_HEADER_UPDATE="8'd0"
WRAPPER_PARAMS += --IPORT_IS_MM="8'd1" --OPORT_IS_MM="8'd1"
WRAPPER_PARAMS += --bind mm_in=func_in_addr_0 --bind mm_out=func_out_addr_0
WRAPPER_PARAMS += --bind size=func_in_size_0

include ../template/makefile.inc
