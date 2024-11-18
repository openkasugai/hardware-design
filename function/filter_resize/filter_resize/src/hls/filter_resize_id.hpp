/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#ifndef _CONVADP_ID
#define _CONVADP_ID

#include <stdint.h>

void filter_resize_id(
		volatile uint32_t& filter_resize_module_id,
		volatile uint32_t& filter_resize_local_version);

#endif
