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
	cs_ctrl_id                  \
	egr_forward                 \
	egr_hdr_ins                 \
	egr_resp                    \
	egr_term                    \
	egr_write                   \
	ht_egr_fw                   \
	ht_ingr_fw                  \
	ingr_hdr_rmv                \
	ingr_read                   \
	ingr_req                    \
	ingr_stall                  \
	ingr_term                   \
	select_stream_nw            \
	term_evt                    \
	term_update_req_egr_fw      \
	term_update_req_ingr_fw     \
	term_update_resp_egr_fw     \
	term_update_resp_ingr_fw    \
	cc_egr_monitor_protocol_core \
	cc_ingr_monitor_protocol_core

cs_ctrl_id:
	./ipgen.sh $@ ${KRNL_VERSION}

egr_forward:
	./ipgen.sh $@ ${KRNL_VERSION}

egr_hdr_ins:
	./ipgen.sh $@ ${KRNL_VERSION}

egr_resp:
	./ipgen.sh $@ ${KRNL_VERSION}

egr_term:
	./ipgen.sh $@ ${KRNL_VERSION}

egr_write:
	./ipgen.sh $@ ${KRNL_VERSION}

ht_egr_fw:
	./ipgen.sh $@ ${KRNL_VERSION}

ht_ingr_fw:
	./ipgen.sh $@ ${KRNL_VERSION}

ingr_hdr_rmv:
	./ipgen.sh $@ ${KRNL_VERSION}

ingr_read:
	./ipgen.sh $@ ${KRNL_VERSION}

ingr_req:
	./ipgen.sh $@ ${KRNL_VERSION}

ingr_stall:
	./ipgen.sh $@ ${KRNL_VERSION}

ingr_term:
	./ipgen.sh $@ ${KRNL_VERSION}

select_stream_nw:
	./ipgen.sh $@ ${KRNL_VERSION}

term_evt:
	./ipgen.sh $@ ${KRNL_VERSION}

term_update_req_egr_fw:
	./ipgen.sh $@ ${KRNL_VERSION}

term_update_req_ingr_fw:
	./ipgen.sh $@ ${KRNL_VERSION}

term_update_resp_egr_fw:
	./ipgen.sh $@ ${KRNL_VERSION}

term_update_resp_ingr_fw:
	./ipgen.sh $@ ${KRNL_VERSION}

cc_egr_monitor_protocol_core:
	./ipgen.sh $@ ${KRNL_VERSION}

cc_ingr_monitor_protocol_core:
	./ipgen.sh $@ ${KRNL_VERSION}

clean:
	rm -rf *_prj
	rm -f tmp.*.tcl
	rm -f *.log
