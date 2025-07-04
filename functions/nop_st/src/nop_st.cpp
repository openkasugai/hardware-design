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

void nop_core(hls::stream<Axis>& istream, hls::stream<Axis>& ostream) {
nop_core:
    bool eof = false;
    do {
        Axis idata = istream.read();
        ostream << idata;
        eof = idata.last;
    } while (!eof);
}

extern "C" {

void nop_st(hls::stream<Axis>& st_in, hls::stream<Axis>& st_out) {
#pragma HLS INTERFACE axis port = st_in
#pragma HLS INTERFACE axis port = st_out

#pragma HLS DATAFLOW
    nop_core(st_in, st_out);
}

}
