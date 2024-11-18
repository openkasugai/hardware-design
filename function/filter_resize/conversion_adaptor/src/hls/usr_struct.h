/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#ifndef _USR_STRUCT_
#define _USR_STRUCT_

#include "ap_int.h"

template<int D>
struct usr_axis {
    ap_uint<D>   data;
};



#endif 