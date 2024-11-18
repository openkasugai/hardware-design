/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"

// Event termination for external IF
void term_evt(hls::stream<extifEvent> &s_axis_extif_evt,
              hls::stream<ptrUpdateReq> &rcv_nxt_update_req_estab,
              hls::stream<ptrUpdateReq> &rcv_nxt_update_req_receive,
              hls::stream<ptrUpdateReq> &snd_una_update_req,
              hls::stream<ptrUpdateReq> &evt_usr_wrt_update_req,
              volatile ap_uint<10> &extif_event_fault)
{
#pragma HLS INTERFACE mode = axis port = s_axis_extif_evt
#pragma HLS INTERFACE mode = axis port = rcv_nxt_update_req_estab
#pragma HLS INTERFACE mode = axis port = rcv_nxt_update_req_receive
#pragma HLS INTERFACE mode = axis port = snd_una_update_req
#pragma HLS INTERFACE mode = axis port = evt_usr_wrt_update_req
#pragma HLS INTERFACE mode = ap_ovld port = extif_event_fault
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

#pragma HLS PIPELINE

    extifEvent evt;
    if (s_axis_extif_evt.read_nb(evt))
    {
        if ((evt.event & static_cast<event_t>(extifEventStatus::ERASED)) ||
            (evt.event & static_cast<event_t>(extifEventStatus::RECV_RST)))
        {
            // Delete disconnected connections from the table
            rcv_nxt_update_req_estab.write(
                ptrUpdateReq(tableOp::TABLE_OP_DELETE, 0, evt.cid, evt.rcv_nxt, 0));
            evt_usr_wrt_update_req.write(
                ptrUpdateReq(tableOp::TABLE_OP_DELETE, 0, evt.cid, evt.snd_una, 0));
        }
        else if (evt.event & static_cast<event_t>(extifEventStatus::ESTABLISHED))
        {
            // Add established connections to the table
            // Initialize the user pointer with the external IF pointer for both Tx and Rx
            rcv_nxt_update_req_estab.write(
                ptrUpdateReq(tableOp::TABLE_OP_INSERT, 0, evt.cid, evt.rcv_nxt, 0));
            evt_usr_wrt_update_req.write(
                ptrUpdateReq(tableOp::TABLE_OP_INSERT, 0, evt.cid, evt.snd_una, 0));
        }
        else
        {
            if (evt.event & static_cast<event_t>(extifEventStatus::SEND_DATA))
            {
                snd_una_update_req.write(
                    ptrUpdateReq(tableOp::TABLE_OP_INSERT, 0, evt.cid, evt.snd_una, 0));
            }

            if (evt.event & static_cast<event_t>(extifEventStatus::RECV_DATA))
            {
                rcv_nxt_update_req_receive.write(
                    ptrUpdateReq(tableOp::TABLE_OP_INSERT, 0, evt.cid, evt.rcv_nxt, 0));
            }
        }

        ap_uint<10> err = 0;
        err(3, 3) = (evt.event & static_cast<event_t>(extifEventStatus::SYN_TIMEOUT)) ? 1 : 0;
        err(4, 4) = (evt.event & static_cast<event_t>(extifEventStatus::SYN_ACK_TIMEOUT)) ? 1 : 0;
        err(5, 5) = (evt.event & static_cast<event_t>(extifEventStatus::TIMEOUT)) ? 1 : 0;
        err(8, 8) = (evt.event & static_cast<event_t>(extifEventStatus::RECV_URGENT_DATA)) ? 1 : 0;
        if (err)
            extif_event_fault = err;
    }
}
