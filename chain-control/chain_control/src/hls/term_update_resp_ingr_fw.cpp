/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"

// Hash table update request termination (for ID conversion)
void term_update_resp_ingr_fw(hls::stream<ingrFwUpdateResp> &update_resp,
                              hls::stream<ingrFwLookupResp> &read_resp,
                              volatile axilite_data_t &resp,
                              volatile axilite_data_t &resp_data,
                              volatile axilite_data_t &resp_count,
                              volatile axilite_data_t &resp_fail_count)
{
#pragma HLS INTERFACE mode = axis port = update_resp
#pragma HLS INTERFACE mode = axis port = read_resp
#pragma HLS INTERFACE mode = ap_none port = resp
#pragma HLS INTERFACE mode = ap_ovld port = resp_data
#pragma HLS INTERFACE mode = ap_none port = resp_count
#pragma HLS INTERFACE mode = ap_none port = resp_fail_count
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

    static volatile axilite_data_t resp_reg = 0;
    static volatile axilite_data_t resp_count_reg = 0;
    static volatile axilite_data_t resp_fail_count_reg = 0;
    resp = resp_reg;
    resp_count = resp_count_reg;
    resp_fail_count = resp_fail_count_reg;

    bool accessed = false;
    bool failed = false;

    if (!update_resp.empty())
    {
        auto term_resp = update_resp.read();

        resp_reg = (term_resp.success) ? 1 : 0;

        accessed = true;
        failed = !term_resp.success;
    }
    else if (!read_resp.empty())
    {
        auto term_resp = read_resp.read();

        resp_reg = 1;

        axilite_data_t tmp = 0;
        tmp |= term_resp.value.channel;
        tmp |= ((axilite_data_t)term_resp.value.enable) << FW_TABLE_REG_FLAG_ENABLE;
        tmp |= ((axilite_data_t)term_resp.value.active) << FW_TABLE_REG_FLAG_ACTIVE;
        tmp |= ((axilite_data_t)term_resp.value.direct) << FW_TABLE_REG_FLAG_DIRECT;
        resp_data = tmp;

        accessed = true;
        failed = false;
    }

    if (accessed)
    {
        resp_count_reg = (resp_count_reg < std::numeric_limits<axilite_data_t>::max()) ? resp_count_reg + 1 : 0;
    }

    if (failed)
    {
        resp_fail_count_reg = (resp_fail_count_reg < std::numeric_limits<axilite_data_t>::max()) ? resp_fail_count_reg + 1 : 0;
    }
}
