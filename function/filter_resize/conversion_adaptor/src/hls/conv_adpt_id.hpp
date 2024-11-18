/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#ifndef _CONVADP_ID
#define _CONVADP_ID

#include <stdint.h>

void conv_adpt_id(
		volatile uint32_t& conv_adpt_module_id,
		volatile uint32_t& conv_adpt_local_version);

#endif
