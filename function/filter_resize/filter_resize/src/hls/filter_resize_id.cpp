/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "filter_resize_id.hpp"
#include "xf_config_params.h"

void filter_resize_id(
		volatile uint32_t& filter_resize_module_id,
		volatile uint32_t& filter_resize_local_version) {
#pragma HLS INTERFACE mode = ap_none port = filter_resize_module_id
#pragma HLS INTERFACE mode = ap_none port = filter_resize_local_version
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

	filter_resize_module_id = FIL_RSZ_MODULE_ID;
	filter_resize_local_version = FIL_RSZ_LOCAL_VERSION;
}
