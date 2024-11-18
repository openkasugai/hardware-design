/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#pragma once

#include <ap_int.h>

ap_uint<512> barrel_1024to512_dsp(ap_uint<1024> in_data, ap_uint<6> in_sel);
