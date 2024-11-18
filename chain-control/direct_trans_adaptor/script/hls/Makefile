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
	direct_trans_adaptor_core \
	direct_trans_adaptor_id \
	dta_ingr_rcv_monitor_protocol_core \
	dta_ingr_snd_monitor_protocol_core \
	dta_egr_rcv_monitor_protocol_core \
	dta_egr_snd_monitor_protocol_core

direct_trans_adaptor_core:
	./ipgen.sh $@ ${KRNL_VERSION}

direct_trans_adaptor_id:
	./ipgen.sh $@ ${KRNL_VERSION}

dta_ingr_rcv_monitor_protocol_core:
	./ipgen.sh $@ ${KRNL_VERSION}

dta_ingr_snd_monitor_protocol_core:
	./ipgen.sh $@ ${KRNL_VERSION}

dta_egr_rcv_monitor_protocol_core:
	./ipgen.sh $@ ${KRNL_VERSION}

dta_egr_snd_monitor_protocol_core:
	./ipgen.sh $@ ${KRNL_VERSION}

clean:
	rm -rf *_prj
	rm -f tmp.*.tcl
	rm -f *.log
