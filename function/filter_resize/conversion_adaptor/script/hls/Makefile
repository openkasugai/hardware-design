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
	conv_adpt_id \
	ch_separation \
	ch_multiple \
	ca_ingr_rcv_monitor_protocol_core \
	ca_ingr_snd_monitor_protocol_core \
	ca_egr_rcv_monitor_protocol_core \
	ca_egr_snd_monitor_protocol_core

conv_adpt_id:
	./ipgen.sh $@ ${KRNL_VERSION}

ch_separation:
	./ipgen.sh $@ ${KRNL_VERSION}

ch_multiple:
	./ipgen.sh $@ ${KRNL_VERSION}

ca_ingr_rcv_monitor_protocol_core:
	./ipgen.sh $@ ${KRNL_VERSION}

ca_ingr_snd_monitor_protocol_core:
	./ipgen.sh $@ ${KRNL_VERSION}

ca_egr_rcv_monitor_protocol_core:
	./ipgen.sh $@ ${KRNL_VERSION}

ca_egr_snd_monitor_protocol_core:
	./ipgen.sh $@ ${KRNL_VERSION}

clean:
	rm -rf *_prj
	rm -f tmp.*.tcl
	rm -f *.log
