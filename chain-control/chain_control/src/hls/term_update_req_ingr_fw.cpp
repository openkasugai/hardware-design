/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"

// Hash table update request termination
void term_update_req_ingr_fw(axilite_data_t &update_req,
                             axilite_data_t &update_key,
                             axilite_data_t &update_value,
                             hls::stream<ingrFwUpdateReq> &st_update_req,
                             hls::stream<ingrFwLookupReq> &st_update_read)
{
#pragma HLS INTERFACE mode = ap_none port = update_req
#pragma HLS INTERFACE mode = ap_none port = update_key
#pragma HLS INTERFACE mode = ap_none port = update_value
#pragma HLS INTERFACE mode = axis port = st_update_req
#pragma HLS INTERFACE mode = axis port = st_update_read
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

    static bool busy = false;
    
    ingrFwKey key;
    key.connection = update_key & ((1 << CONNECTION_WIDTH) - 1);
    key.ifid = (update_key >> CONNECTION_WIDTH) & ((1 << IFID_WIDTH) - 1);

    ingrFwValue value;
    value.channel = update_value & ((1 << CHANNEL_WIDTH) - 1);
    value.enable = (update_value >> FW_TABLE_REG_FLAG_ENABLE) & 1;
    value.active = (update_value >> FW_TABLE_REG_FLAG_ACTIVE) & 1;
    value.direct = (update_value >> FW_TABLE_REG_FLAG_DIRECT) & 1;

    if (!busy && (update_req != 0) && !st_update_req.full() && !st_update_read.full())
    {
        // Update request
        // 0: NOP, 1: Add, 2: Delete, 3: Read
        if (update_req == 1)
        {
            st_update_req.write(
                ingrFwUpdateReq(tableOp::TABLE_OP_INSERT, key, value));
        }
        else if (update_req == 2)
        {
            st_update_req.write(
                ingrFwUpdateReq(tableOp::TABLE_OP_DELETE, key, value));
        }
        else if (update_req == 3)
        {
            st_update_read.write(
                ingrFwLookupReq(key, 0, 0));
        }
        busy = true;
    }
    else if (update_req == 0)
    {
        busy = false;
    }
}
