/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"

// Channel->Connection translation request for egress direction
void egr_forward(hls::stream<sessionReq> &egr_lookup_forward,
                 hls::stream<egrFwLookupResp> &egr_forward_lookup_resp,
                 hls::stream<sessionForward> &egr_lookup_resp,
                 volatile ap_uint<16> &egr_forward_mishit)
{
#pragma HLS INTERFACE mode = axis port = egr_lookup_forward
#pragma HLS INTERFACE mode = axis port = egr_forward_lookup_resp
#pragma HLS INTERFACE mode = axis port = egr_lookup_resp
#pragma HLS INTERFACE mode = ap_ovld port = egr_forward_mishit
#pragma HLS INTERFACE mode = ap_ctrl_none port = return
#pragma HLS PIPELINE

    if (!egr_lookup_forward.empty() &&
        !egr_forward_lookup_resp.empty() &&
        !egr_lookup_resp.full())
    {
        sessionReq forward_channel = egr_lookup_forward.read();

        // Get the connection corresponding to the channel
        egrFwLookupResp forward_connection = egr_forward_lookup_resp.read();

        // Discard decision
        uint8_t discard = forward_connection.value.enable && forward_connection.value.active ? 0 : 1;

        sessionForward fwd(
            forward_connection.value.ifid,
            forward_connection.value.connection,
            forward_channel.channel,
            forward_channel.burst_length,
            forward_channel.frame_length,
            forward_channel.sof,
            forward_channel.eof,
            discard,
            forward_connection.value.blocking);

        // Transfer
        egr_lookup_resp.write(fwd);

        if (!forward_connection.value.enable)
        {
            // Mishit notification
            ap_uint<16> tmp = 0;
            tmp(CONNECTION_WIDTH - 1, 0) = fwd.channel;
            egr_forward_mishit = tmp;
        }
    }
}
