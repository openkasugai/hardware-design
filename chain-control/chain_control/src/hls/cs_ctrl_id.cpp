/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"

// Version register
void cs_ctrl_id(volatile axilite_data_t &module_id,
                volatile axilite_data_t &local_version)
{
#pragma HLS INTERFACE mode = ap_none port = module_id
#pragma HLS INTERFACE mode = ap_none port = local_version
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

    module_id = CSC_MODULE_ID;
    local_version = CSC_LOCAL_VERSION;
}
