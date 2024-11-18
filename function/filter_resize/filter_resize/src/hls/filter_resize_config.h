/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/


#ifndef _FILTER_RESIZE_CONFIG_
#define _FILTER_RESIZE_CONFIG_

#include "hls_stream.h"
#include "ap_int.h"
#include "xf_config_params.h"


/* Interface types*/
#if RO

#if RGBB
#define NPC_T XF_NPPC4
#else
#define NPC_T XF_NPPC8
#endif

#else
#define NPC_T XF_NPPC1
#endif

#if RGBB
#define TYPE XF_8UC3
#define CH_TYPE XF_RGB
#else
#define TYPE XF_8UC1
#define CH_TYPE XF_GRAY
#endif

#endif

