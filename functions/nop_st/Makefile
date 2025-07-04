#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

VSRC := src/nop_st.cpp
CFG := nop_st.cfg
TOP := nop_st

WRAPPER_PARAMS := --IPORT_NUM=1 --OPORT_NUM=1
WRAPPER_PARAMS += --bind func_out_updated_size_0=func_in_size_0 --bind func_out_updated_addr_0=func_out_addr_0
WRAPPER_PARAMS += --bind "func_out_updated_valid_0=in_frame_header_consume_0_tvalid & in_frame_header_consume_0_tready"

include ../template/makefile.inc
