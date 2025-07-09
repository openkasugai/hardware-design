/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include <stdint.h>
#include <ap_int.h>
#include <ap_axi_sdata.h>
#include <hls_stream.h>

#define DW 512

typedef ap_axiu<DW,0,0,0> Axis;

void vec_fp_inc_core(hls::stream<Axis>& istream, hls::stream<Axis>& ostream, float inc_val) {
nop_core:
    bool eof = false;
    do {
#pragma HLS pipeline II=1
        Axis idata = istream.read();
        union data_conv {
            ap_int<DW> i;
            float f[DW/32];

            data_conv() {
                i = 0;
            }
        } data;
        data.i = idata.data;
        for (int i=0; i<DW/32; i++) {
#pragma HLS unroll factor=DW/32
            float val = data.f[i];
            val += inc_val;
            data.f[i] = val;
        }
        idata.data = data.i;
        ostream << idata;
        eof = idata.last;
    } while (!eof);
}

extern "C" {

void vec_fp_inc(hls::stream<Axis>& st_in, hls::stream<Axis>& st_out, float inc_val) {
#pragma HLS INTERFACE axis port = st_in
#pragma HLS INTERFACE axis port = st_out
#pragma HLS INTERFACE s_axilite port = inc_val bundle = ctrl

#pragma HLS DATAFLOW
    vec_fp_inc_core(st_in, st_out, inc_val);
}

}
