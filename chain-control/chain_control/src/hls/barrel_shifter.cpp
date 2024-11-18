/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "barrel_shifter.hpp"

// 128:64 multiplexer
ap_uint<64> barrel_128to64_dsp(ap_uint<128> in_data, ap_uint<6> in_sel)
{
#pragma HLS INLINE
    ap_uint<72> mid;
    ap_uint<64> out;

    // stage 1
    {
        // Calculate the multiplication value
        ap_uint<3> sel = in_sel(5, 3);
        ap_uint<8> factor = 1 << (7 - sel);

        // 16:9 shifter * 8
    mux128_s1_phase:
        for (int phase = 0; phase < 8; phase++)
        {
#pragma HLS UNROLL
            ap_uint<16> src;
        mux128_s1_map:
            for (int i = 0; i < 16; i++)
            {
#pragma HLS UNROLL
                src(i, i) = in_data(8 * i + phase, 8 * i + phase);
            }

            // Right shift using DSP
            auto dsp_out = src * factor;

            // Remap to intermediate vector
        mux128_s1_unmap:
            for (int i = 0; i < 9; i++)
            {
#pragma HLS UNROLL
                mid(i * 8 + phase, i * 8 + phase) = dsp_out(i + 7, i + 7);
            }
        }
    }

    // stage 2
    {
        // Calculate the multiplication value
        ap_uint<3> sel = in_sel(2, 0);
        ap_uint<8> factor = 1 << (7 - sel);

        // 23:16 shifter * 4
    mux128_s2_phase:
        for (int phase = 0; phase < 4; phase++)
        {
#pragma HLS UNROLL
            ap_uint<23> src;
        mux128_s2_map:
            for (int i = 0; i < 23; i++)
            {
#pragma HLS UNROLL
                src(i, i) = mid(phase * 16 + i, phase * 16 + i);
            }

            // Right shift using DSP
            auto dsp_out = src * factor;

            // Remap to output vector
        mux128_s2_unmap:
            for (int i = 0; i < 16; i++)
            {
#pragma HLS UNROLL
                out(phase * 16 + i, phase * 16 + i) = dsp_out(i + 7, i + 7);
            }
        }
    }

    return out;
}

// 128 bytes - 64 byte shifter
ap_uint<512> barrel_1024to512_dsp(ap_uint<1024> in_data, ap_uint<6> in_sel)
{
#pragma HLS INLINE
    ap_uint<512> out;
barrel512_phase:
    // Bits in a Byte are not mixed, so they are separated and processed in parallel
    for (int phase = 0; phase < 8; phase++)
    {
#pragma HLS UNROLL
        ap_uint<128> sel_src;
        // Cut out bits at 1 byte intervals and concatenate
    barrel512_map:
        for (int i = 0; i < 128; i++)
        {
#pragma HLS UNROLL
            sel_src(i, i) = in_data(i * 8 + phase, i * 8 + phase);
        }

        // 128:64 selector using DSP
        auto sel_out = barrel_128to64_dsp(sel_src, in_sel);

        // Cut out 1 bits at a time and rearrange at 1 byte intervals
    barrel512_unmap:
        for (int i = 0; i < 64; i++)
        {
#pragma HLS UNROLL
            out(i * 8 + phase, i * 8 + phase) = sel_out(i, i);
        }
    }

    return out;
}
