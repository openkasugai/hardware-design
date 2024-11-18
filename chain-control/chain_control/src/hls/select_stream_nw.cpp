/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"

void select_stream_nw(hls::stream<extifCommand> &in_0,
                      hls::stream<extifCommand> &in_1,
                      hls::stream<extifCommand> &out)
{
#pragma HLS INTERFACE mode = axis port = in_0
#pragma HLS INTERFACE mode = axis port = in_1
#pragma HLS INTERFACE mode = axis port = out
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

#pragma HLS PIPELINE

    if ((!in_0.empty() || !in_1.empty()) && !out.full())
    {
        if (!in_0.empty())
        {
            out.write(in_0.read());
        }
        else if (!in_1.empty())
        {
            out.write(in_1.read());
        }
    }
}
