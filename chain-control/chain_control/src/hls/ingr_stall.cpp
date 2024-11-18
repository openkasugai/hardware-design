/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"

// Flow control in the ingress direction
void ingr_stall(hls::stream<bool> &ingr_done,
                hls::stream<bool> &ingr_start,
                ap_uint<1> &ap_start)
{
#pragma HLS INTERFACE mode = axis port = ingr_done
#pragma HLS INTERFACE mode = axis port = ingr_start
#pragma HLS INTERFACE mode = ap_none port = ap_start
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

#pragma HLS PIPELINE

    static bool is_first = true;
    if ((ap_start == 1) && is_first && !ingr_start.full())
    {
        ingr_start.write(true);
        is_first = false;
    }
    else if ((ap_start == 1) && !is_first && !ingr_done.empty() && !ingr_start.full())
    {
        ingr_start.write(ingr_done.read());
    }
}
