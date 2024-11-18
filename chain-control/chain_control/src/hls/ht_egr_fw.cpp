/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"

void ht_egr_fw(hls::stream<egrFwLookupReq> &s_axis_lup_req,
               hls::stream<egrFwLookupReq> &s_axis_read_req,
               hls::stream<egrFwUpdateReq> &s_axis_upd_req,
               hls::stream<egrFwLookupResp> &m_axis_lup_rsp,
               hls::stream<egrFwLookupResp> &m_axis_read_rsp,
               hls::stream<egrFwUpdateResp> &m_axis_upd_rsp,
               volatile ap_uint<16> &detect_fault,
               ap_uint<8> insert_fault)
{
#pragma HLS INTERFACE mode = axis port = s_axis_lup_req
#pragma HLS INTERFACE mode = axis port = s_axis_read_req
#pragma HLS INTERFACE mode = axis port = s_axis_upd_req
#pragma HLS INTERFACE mode = axis port = m_axis_lup_rsp
#pragma HLS INTERFACE mode = axis port = m_axis_read_rsp
#pragma HLS INTERFACE mode = axis port = m_axis_upd_rsp
#pragma HLS INTERFACE mode = ap_ovld port = detect_fault
#pragma HLS INTERFACE mode = ap_none port = insert_fault
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

    static ap_uint<1> frame_busy[MAX_NUM_CHANNELS] = {0}; // Frame period or not
#pragma HLS ARRAY_PARTITION variable = frame_busy type = complete
    static egrFwValue table_cfg[MAX_NUM_CHANNELS];        // Setting side
#pragma HLS aggregate variable = table_cfg compact = bit
#pragma HLS reset variable=table_cfg off
    static egrFwValue table_ref[MAX_NUM_CHANNELS]; // Reference side
#pragma HLS aggregate variable = table_ref compact = bit
#pragma HLS reset variable=table_ref off

    volatile bool err_parity = false;
    volatile channel_t err_channel = 0;

    if (!s_axis_lup_req.empty())
    {
        auto request = s_axis_lup_req.read();
        int key = request.key;

        egrFwValue entry;
        if (request.sof)
        {
            // Transfer from the setting side to the reference side in synchronization with the beginning of the frame
            entry = table_cfg[key];
            table_ref[key] = entry;
            frame_busy[key] = 1;
        }
        else
        {
            // Continue to read the reference side at positions other than the beginning of the frame.
            entry = table_ref[key];
            if (request.eof)
            {
                frame_busy[key] = 0;
            }
        }

        if (!entry.parity_ok())
        {
            err_parity = true;
            err_channel = key;
        }

        egrFwLookupResp response;
        response.key = request.key;
        response.value = entry;

        m_axis_lup_rsp.write(response);
    }
    else if (!s_axis_read_req.empty())
    {
        auto request = s_axis_read_req.read();
        int key = request.key;

        egrFwValue entry = table_cfg[key];
        if (!entry.parity_ok())
        {
            err_parity = true;
            err_channel = key;
        }

        egrFwLookupResp response;
        response.key = request.key;
        response.value = entry;

        m_axis_read_rsp.write(response);
    }
    else if (!s_axis_upd_req.empty())
    {
        auto request = s_axis_upd_req.read();
        int key = request.key;
        egrFwValue entry;

        bool ins_fault =
            (request.value.ifid == 0 && (insert_fault & 0x01) != 0) ||
            (request.value.ifid == 1 && (insert_fault & 0x10) != 0);

        if (request.op == TABLE_OP_INSERT)
        {
            egrFwUpdateResp response;
            response.op = request.op;
            response.key = request.key;
            response.success = 1;
            response.value = request.value;

            // insert entry
            // accept overwrite
            entry = request.value;
            entry.update_parity();
            if (ins_fault)
                entry.parity = ~entry.parity;
            table_cfg[key] = entry;

            m_axis_upd_rsp.write(response);
        }
        else // DELETE
        {
            entry = table_cfg[request.key];

            egrFwUpdateResp response;
            response.op = request.op;
            response.key = request.key;
            response.success = entry.enable;
            response.value = entry;

            // delete entry
            entry.enable = 0;
            entry.update_parity();
            if (ins_fault)
                entry.parity = ~entry.parity;
            table_cfg[key] = entry;

            m_axis_upd_rsp.write(response);
        }

        if (!frame_busy[key])
        {
            // Transfer to reference side if not in frame period.
            table_ref[key] = entry;
        }
    }

    if (err_parity)
    {
        ap_uint<16> tmp = 0;
        tmp(CONNECTION_WIDTH - 1, 0) = err_channel;
        detect_fault = tmp;
    }
}
