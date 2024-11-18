/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#pragma once

#include "chain_subblock.hpp"

// Class for manage header buffers
class HeaderBuffer
{
public:
    header_data_t headers[MAX_NUM_CHANNELS * HDR_BUFF_DEPTH_PER_CHANNEL];
    uint8_t wr_ptr[MAX_NUM_CHANNELS] = {0};
    uint8_t rd_ptr[MAX_NUM_CHANNELS] = {0};
    ap_uint<1> full_flag[MAX_NUM_CHANNELS] = {0};
    ap_uint<1> empty_flag[MAX_NUM_CHANNELS] = {1};

    // Full flag per channel
    ap_uint<1> full(channel_t ch)
    {
#pragma HLS INLINE
        return full_flag[ch];
    }

    // Write to header buffer
    void write(sessionPtr session, header_data_t data, headerBuffUsage &usage)
    {
        channel_t ch = session.channel;
        if (full_flag[ch])
        {
            // full
            for (int i = 0; i < HDR_LENGTH; i++)
            {
#pragma HLS unroll
                data(i * 8 + 7, i * 8) = 0xff;
            }
            headers[ch * HDR_BUFF_DEPTH_PER_CHANNEL + wr_ptr[ch]] = data;
        }
        else
        {
            uint8_t wp = wr_ptr[ch];
            uint8_t rp = rd_ptr[ch];
            headers[ch * HDR_BUFF_DEPTH_PER_CHANNEL + wp] = data;
            wp = (wp + 1) % HDR_BUFF_DEPTH_PER_CHANNEL;
            if (wp == rp)
                full_flag[ch] = 1;
            empty_flag[ch] = 0;
            wr_ptr[ch] = wp;
            put_usage(session, wp, rp, full_flag[ch], usage);
        }
    }

    // Read header buffer
    header_data_t read(sessionPtr session, headerBuffUsage &usage)
    {
        channel_t ch = session.channel;
        header_data_t data;
        if (empty_flag[ch])
        {
            // empty
            for (int i = 0; i < HDR_LENGTH; i++)
            {
#pragma HLS unroll
                data(i * 8 + 7, i * 8) = 0xee;
            }
        }
        else
        {
            uint8_t wp = wr_ptr[ch];
            uint8_t rp = rd_ptr[ch];
            data = headers[ch * HDR_BUFF_DEPTH_PER_CHANNEL + rp];
            rp = (rp + 1) % HDR_BUFF_DEPTH_PER_CHANNEL;
            if (wp == rp)
                empty_flag[ch] = 1;
            full_flag[ch] = 0;
            rd_ptr[ch] = rp;
            put_usage(session, wp, rp, full_flag[ch], usage);
        }
        return data;
    }

    // Report header usage per channel
    static void put_usage(sessionPtr session, uint8_t wp, uint8_t rp, ap_uint<1> full, headerBuffUsage &usage)
    {
#pragma HLS INLINE
        headerBuffUsage tmp;
        tmp.ifid = session.ifid;
        tmp.connection = session.connection;
        tmp.channel = session.channel;
        tmp.bp = full;
        if (full)
        {
            tmp.usage = HDR_BUFF_DEPTH_PER_CHANNEL;
        }
        else if (wp >= rp)
        {
            tmp.usage = wp - rp;
        }
        else
        {
            tmp.usage = wp + HDR_BUFF_DEPTH_PER_CHANNEL - rp;
        }
        usage = tmp;
    }
};
