/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"

// Ingress transfer request
void ingr_req(hls::stream<sessionPtr> &ingr_lookup_req,
              hls::stream<ingrFwLookupResp> &ingr_forward_lookup_resp,
              hls::stream<sessionReq> &ingr_session_req,
              hls::stream<sessionPtr> &ingr_send,
              ap_uint<16> &ingr_forward_mishit,
              volatile axilite_data_t &dbg_lup_rcv_nxt,
              volatile axilite_data_t &dbg_lup_usr_read,
              ap_uint<32> insert_protocol_fault)
{
#pragma HLS INTERFACE mode = axis port = ingr_lookup_req
#pragma HLS INTERFACE mode = axis port = ingr_forward_lookup_resp
#pragma HLS INTERFACE mode = axis port = ingr_session_req
#pragma HLS INTERFACE mode = axis port = ingr_send
#pragma HLS INTERFACE mode = ap_ovld port = ingr_forward_mishit
#pragma HLS INTERFACE mode = ap_none port = dbg_lup_rcv_nxt
#pragma HLS INTERFACE mode = ap_none port = dbg_lup_usr_read
#pragma HLS INTERFACE mode = ap_none port = insert_protocol_fault
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

#pragma HLS PIPELINE

    static volatile axilite_data_t dbg_lup_rcv_nxt_reg = 0;
    static volatile axilite_data_t dbg_lup_usr_read_reg = 0;

    if (!ingr_lookup_req.empty() &&
        !ingr_forward_lookup_resp.empty() &&
        !ingr_session_req.full() &&
        !ingr_send.full())
    {
        sessionPtr ingr_req_connection = ingr_lookup_req.read();
        ingrFwLookupResp ingr_channel = ingr_forward_lookup_resp.read();

        ingr_req_connection.channel = ingr_channel.value.channel;
        ingr_req_connection.direct = ingr_channel.value.direct;

        // Issue transfer requests only for valid connections and valid channels
        if (!ingr_req_connection.discard && ingr_channel.value.enable && ingr_channel.value.active)
        {
            // Debug register
            dbg_lup_rcv_nxt_reg = static_cast<axilite_data_t>(ingr_req_connection.ext);
            dbg_lup_usr_read_reg = static_cast<axilite_data_t>(ingr_req_connection.usr);

            if (!ingr_req_connection.head)
            {
                // Calculates the amount of storage in the receive buffer
                // and issues an ingress transfer request to the post stage.
                length_t length = calc_length_bytes(ingr_req_connection.ext, ingr_req_connection.usr);
                
                if (length > MAX_BURST_LENGTH) {
                    // Clip with MAX_BURST_LENGTH to avoid deadlock due to Tx buffer full.
                    // In this case, EOF is negated because it is not at the end of the frame.
                    length = MAX_BURST_LENGTH;
                    ingr_req_connection.eof = 0;
                }

                sessionReq req(
                    ingr_req_connection.channel,
                    length,
                    ingr_req_connection.sof,
                    ingr_req_connection.eof,
                    ingr_req_connection.direct,
                    ingr_req_connection.payload_len);

                if ((insert_protocol_fault >> PROTOCOL_FAULT_REQ_BURST_LENGTH_NZ) & 1)
                    req.burst_length = 0;
                if ((insert_protocol_fault >> PROTOCOL_FAULT_REQ_MAX_BURST_LENGTH) & 1)
                    req.burst_length = MAX_BURST_LENGTH + 1;

                ingr_session_req.write(req);
            }
        }
        else
        {
            // Discard
            ingr_req_connection.discard = 1;

            if (!ingr_channel.value.enable)
            {
                // Mishit Notification
                ap_uint<16> tmp = 0;
                tmp(CONNECTION_WIDTH - 1, 0) = ingr_req_connection.connection;
                tmp(CONNECTION_WIDTH + IFID_WIDTH - 1, CONNECTION_WIDTH) = ingr_req_connection.ifid;
                ingr_forward_mishit = tmp;
            }
        }

        // Forward same information to responder of Ingress
        // Since Out-of-Order is not supported, order of requests and responses is guaranteed
        ingr_send.write(ingr_req_connection);
    }

    dbg_lup_rcv_nxt = dbg_lup_rcv_nxt_reg;
    dbg_lup_usr_read = dbg_lup_usr_read_reg;
}
