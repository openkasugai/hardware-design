/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"

// Transfer event end in ingress direction
void ingr_term(hls::stream<sessionPtr> &ingr_receive,
               hls::stream<ingrFwLookupReq> &ingr_forward_lookup_req,
               hls::stream<sessionPtr> &ingr_lookup_req,
               volatile axilite_data_t &dbg_ingr_receive_read_count)
{
#pragma HLS INTERFACE mode = axis port = ingr_receive
#pragma HLS INTERFACE mode = axis port = ingr_forward_lookup_req
#pragma HLS INTERFACE mode = axis port = ingr_lookup_req
#pragma HLS INTERFACE mode = ap_none port = dbg_ingr_receive_read_count
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

#pragma HLS PIPELINE

    static volatile axilite_data_t dbg_ingr_receive_read_count_reg = 0;

    if (!ingr_receive.empty() &&
        !ingr_forward_lookup_req.full() &&
        !ingr_lookup_req.full())
    {
        // Start Receive Request
        sessionPtr session = ingr_receive.read();
        // Get the channel corresponding to the connection
        ingrFwKey key;
        key.connection = session.connection;
        key.ifid = session.ifid;
        ingr_forward_lookup_req.write(
            ingrFwLookupReq(key, session.head, session.eof));
        // Transfer the same information to the table reference responder
        ingr_lookup_req.write(session);

        // Debug register
        dbg_ingr_receive_read_count_reg =
            (dbg_ingr_receive_read_count_reg < std::numeric_limits<axilite_data_t>::max()) ? dbg_ingr_receive_read_count_reg + 1 : 0;
    }

    dbg_ingr_receive_read_count = dbg_ingr_receive_read_count_reg;
}
