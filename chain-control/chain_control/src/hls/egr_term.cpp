/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"

// Forward notification termination for egress direction
void egr_term(hls::stream<sessionReq> &egr_session_req,
              hls::stream<egrFwLookupReq> &egr_forward_lookup_req,
              hls::stream<sessionReq> &egr_lookup_forward)
{
#pragma HLS INTERFACE mode = axis port = egr_session_req
#pragma HLS INTERFACE mode = axis port = egr_forward_lookup_req
#pragma HLS INTERFACE mode = axis port = egr_lookup_forward
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

#pragma HLS PIPELINE

    sessionReq req;
    if (egr_session_req.read_nb(req))
    {
        // Request the connection corresponding to the channel
        egr_forward_lookup_req.write(
            egrFwLookupReq((req.channel & CHANNEL_MASK), req.sof, req.eof));

        // Transfer the same information to the table reference responder
        egr_lookup_forward.write(req);
    }
}
