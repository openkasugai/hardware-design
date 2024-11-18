/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_control.hpp"

template <typename T>
void enqueue(bool &ready,
             bool &valid,
             T &data,
             hls::stream<T> &queue,
             volatile bool &fault)
{
#pragma HLS pipeline II = 1
#pragma HLS latency min = 0 max = 0

    bool fault_reg = 0;

    // Enqueue req
    if (ready == 1 && valid == 1)
    {
        if (queue.full())
        {
            // number of transaction must be less than  or equal outstanding number
            fault_reg = 1;
        }
        else
        {
            queue.write(data);
        }
    }

    fault = fault_reg;
}

template <int REQ_BURST_LENGTH_NZ, int RESP_BURST_LENGTH_EQ_REQ, int MAX_BURST_LENGTH>
void check_req_resp(hls::stream<sessionReq> &req_queue,
                    hls::stream<sessionReq> &resp_queue,
                    volatile bool &fault_resp_channel_eq_req,
                    volatile bool &fault_resp_burst_length_le_req,
                    volatile bool &fault_resp_sof_eq_req,
                    volatile bool &fault_resp_eof_eq_req,
                    volatile bool &fault_resp_trans_cw_req,
                    volatile bool &fault_req_max_burst_length,
                    volatile bool &fault_req_burst_length_nz,
                    volatile bool &fault_resp_burst_length_eq_req)
{
#pragma HLS pipeline II = 1

    bool fault_resp_channel_eq_req_reg = 0;
    bool fault_resp_burst_length_le_req_reg = 0;
    bool fault_resp_sof_eq_req_reg = 0;
    bool fault_resp_eof_eq_req_reg = 0;
    bool fault_resp_trans_cw_req_reg = 0;
    bool fault_req_max_burst_length_reg = 0;
    bool fault_req_burst_length_nz_reg = 0;
    bool fault_resp_burst_length_eq_req_reg = 0;

    // Compare req and resp
    if (!resp_queue.empty() && !req_queue.empty())
    {
        sessionReq resp_read = resp_queue.read();
        sessionReq req_read = req_queue.read();
        if (req_read.channel != resp_read.channel)
        {
            // [0] req and resp channel must be equal
            fault_resp_channel_eq_req_reg = 1;
        }
        if (req_read.burst_length < resp_read.burst_length)
        {
            // [1] resp burst length must be less than or equal req 
            fault_resp_burst_length_le_req_reg = 1;
        }
        if (req_read.sof != resp_read.sof)
        {
            // [2] req and resp sof must be equal
            fault_resp_sof_eq_req_reg = 1;
        }
        if (req_read.eof != resp_read.eof)
        {
            // [3] req and resp eof must be equal
            fault_resp_eof_eq_req_reg = 1;
        }
        if (resp_read.burst_length > MAX_BURST_LENGTH)
        {
            // [9] req burst length must be less than or equal max burst length
            fault_req_max_burst_length_reg = 1;
        }
        if (REQ_BURST_LENGTH_NZ == 1 && req_read.burst_length == 0)
        {
            // [12] req length must be greater than zero (optional)
            fault_req_burst_length_nz_reg = 1;
        }
        if (RESP_BURST_LENGTH_EQ_REQ == 1 && (req_read.burst_length != resp_read.burst_length))
        {
            // [13] req and resp length must be equal (optional)
            fault_resp_burst_length_eq_req_reg = 1;
        }
    }
    else if (!resp_queue.empty() && req_queue.empty())
    {
        sessionReq resp_read = resp_queue.read();

        // [4] number of req and resp transaction must be equal
        fault_resp_trans_cw_req_reg = 1;
    }

    fault_resp_channel_eq_req = fault_resp_channel_eq_req_reg;
    fault_resp_burst_length_le_req = fault_resp_burst_length_le_req_reg;
    fault_resp_sof_eq_req = fault_resp_sof_eq_req_reg;
    fault_resp_eof_eq_req = fault_resp_eof_eq_req_reg;
    fault_resp_trans_cw_req = fault_resp_trans_cw_req_reg;
    fault_req_max_burst_length = fault_req_max_burst_length_reg;
    fault_req_burst_length_nz = fault_req_burst_length_nz_reg;
    fault_resp_burst_length_eq_req = fault_resp_burst_length_eq_req_reg;
}

template <int DATA_WIDTH_BYTES, typename TData>
void check_resp_data(hls::stream<sessionReq> &resp_queue,
                     hls::stream<TData> &data_queue,
                     volatile bool &fault_data_trans_cw_resp)
{
#pragma HLS pipeline II = 1

    bool fault_data_trans_cw_resp_reg = 0;

    static uint32_t count_data = 0;
    static bool resp_read_vld = false;
    static sessionReq resp_read;

    // Count data
    if (!data_queue.empty() && !resp_read_vld && resp_queue.empty())
    {
        TData data_read = data_queue.read();

        // [5] number of data transaction consistent with resp
        resp_read_vld = false;
        count_data = 0;
        fault_data_trans_cw_resp_reg = 1;
    }
    else if (!data_queue.empty() && !resp_read_vld && !resp_queue.empty())
    {
        TData data_read = data_queue.read();

        resp_read = resp_queue.read();
        uint32_t cycle_num = CDIV(resp_read.burst_length, DATA_WIDTH_BYTES);
        if (cycle_num > 1)
        {
            // current transaction set and decrement
            resp_read_vld = true;
            count_data = cycle_num - 1;
            fault_data_trans_cw_resp_reg = 0;
        }
        else if (cycle_num > 0)
        {
            // current transaction set and data end
            resp_read_vld = false;
            count_data = 0;
            fault_data_trans_cw_resp_reg = 0;
        }
        else
        {
            // [5] number of data transaction consistent with resp
            resp_read_vld = false;
            count_data = 0;
            fault_data_trans_cw_resp_reg = 1;
        }
    }
    else if (!data_queue.empty() && count_data == 1 && !resp_queue.empty())
    {
        TData data_read = data_queue.read();

        resp_read = resp_queue.read();
        if (resp_read.burst_length > 0)
        {
            // current transaction data end and next transaction set
            resp_read_vld = true;
            count_data = CDIV(resp_read.burst_length, DATA_WIDTH_BYTES);
            fault_data_trans_cw_resp_reg = 0;
        }
        else
        {
            // current transaction data end and next transaction data is empty
            resp_read_vld = false;
            count_data = 0;
            fault_data_trans_cw_resp_reg = 0;
        }
    }
    else if (!data_queue.empty() && count_data == 1)
    {
        TData data_read = data_queue.read();

        // current transaction data end
        resp_read_vld = false;
        count_data = 0;
        fault_data_trans_cw_resp_reg = 0;
    }
    else if (!data_queue.empty() && count_data == 0)
    {
        TData data_read = data_queue.read();

        // [5] number of data transaction consistent with resp
        resp_read_vld = false;
        count_data = 0;
        fault_data_trans_cw_resp_reg = 1;
    }
    else if (!data_queue.empty())
    {
        TData data_read = data_queue.read();

        // decrement
        resp_read_vld = true;
        count_data--;
        fault_data_trans_cw_resp_reg = 0;
    }
    else if (data_queue.empty() && !resp_read_vld && !resp_queue.empty())
    {
        resp_read = resp_queue.read();
        if (resp_read.burst_length > 0)
        {
            // current transaction set
            resp_read_vld = true;
            count_data = CDIV(resp_read.burst_length, DATA_WIDTH_BYTES);
            fault_data_trans_cw_resp_reg = 0;
        }
        else
        {
            // current transaction data is empty
            resp_read_vld = false;
            count_data = 0;
            fault_data_trans_cw_resp_reg = 0;
        }
    }

    fault_data_trans_cw_resp = fault_data_trans_cw_resp_reg;
}
