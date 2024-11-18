/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "conv_adpt_id.hpp"
#include "xf_config_params.h"

void conv_adpt_id(
		volatile uint32_t& conv_adpt_module_id,
		volatile uint32_t& conv_adpt_local_version) {
#pragma HLS INTERFACE mode = ap_none port = conv_adpt_module_id
#pragma HLS INTERFACE mode = ap_none port = conv_adpt_local_version
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

	conv_adpt_module_id = CONV_ADP_MODULE_ID;
	conv_adpt_local_version = CONV_ADP_LOCAL_VERSION;
}
