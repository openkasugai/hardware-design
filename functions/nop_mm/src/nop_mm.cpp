/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include <stdint.h>
#include <ap_int.h>
#include <ap_axi_sdata.h>
#include <hls_stream.h>

#define DW_LOG 9
#define DW (1 << DW_LOG)

struct Axis {
    ap_uint<DW> data;
    ap_uint<1> last;
};

void nop_read(const ap_uint<DW>* mem_in, hls::stream<Axis>& istream, uint32_t size) {
nop_read:
    int loop_size = (size + DW/8 - 1) >> (DW_LOG - 3);
    for (int i=0; i<loop_size; i++) {
        Axis idata;
        idata.data = mem_in[i];
        idata.last = i == loop_size - 1;
        istream << idata;
    }
}

void nop_core(hls::stream<Axis>& istream, hls::stream<Axis>& ostream) {
nop_core:
    bool eof;
    do {
        Axis idata = istream.read();
        ostream << idata;
        eof = idata.last;
    } while (!eof);
}

void nop_write(ap_uint<DW>* mem_out, hls::stream<Axis>& ostream, uint32_t size) {
nop_write:
    bool eof;
    uint32_t pos = 0;
    int loop_size = (size + DW/8 - 1) >> (DW_LOG - 3);
    for (int i=0; i<loop_size; i++) {
        Axis odata = ostream.read();
        eof = odata.last;
        mem_out[i] = odata.data;
    };
}

extern "C" {

void nop_mm(const ap_uint<DW>* mm_in, ap_uint<DW>* mm_out, uint32_t size) {
#pragma HLS INTERFACE m_axi port = mm_in bundle = mem offset = direct
#pragma HLS INTERFACE m_axi port = mm_out bundle = mem offset = direct
#pragma HLS INTERFACE ap_none port = size
    static hls::stream<Axis> in_stream("i_stream");
    static hls::stream<Axis> out_stream("o_stream");
#pragma HLS STREAM variable = in_stream depth = 1024
#pragma HLS STREAM variable = out_stream depth = 1024

#pragma HLS DATAFLOW
    nop_read(mm_in, in_stream, size);
    nop_core(in_stream, out_stream);
    nop_write(mm_out, out_stream, size);
}

}
