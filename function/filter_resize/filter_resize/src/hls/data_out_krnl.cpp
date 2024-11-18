/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include <ap_axi_sdata.h>
#include <iostream>

#include "filter_resize_config.h"
#include "usr_struct.h"
#include "data_out.hpp"
#include "common/xf_common.hpp"

extern "C" {
void data_out_krnl(
				hls::stream<ap_uint<CTL_WIDTH>>& s_axis_local_req,
				hls::stream<ap_uint<FCDT_WIDTH>>& s_axis_rx_data,
				hls::stream<ap_uint<CTL_WIDTH>>& m_axis_tx_req,
				hls::stream<ap_uint<CTL_WIDTH>>& s_axis_tx_resp,
				hls::stream<ap_uint<FCDT_WIDTH>>& m_axis_tx_data,
				int rows_out,
				int cols_out,
                volatile ap_uint<24> &stat_egr_snd_data,
                volatile ap_uint<24> &stat_egr_snd_frame,
                ap_uint<1> insert_protocol_fault_req,
                ap_uint<1> insert_protocol_fault_data,
				volatile uint32_t &snd_req,
				volatile uint32_t &rcv_resp,
				volatile uint32_t &snd_data
                  ) {
    #pragma HLS INTERFACE mode = axis port = s_axis_local_req
    #pragma HLS INTERFACE mode = axis port = s_axis_rx_data
    #pragma HLS INTERFACE mode = axis port = m_axis_tx_req
    #pragma HLS INTERFACE mode = axis port = s_axis_tx_resp
    #pragma HLS INTERFACE mode = axis port = m_axis_tx_data
    #pragma HLS INTERFACE mode = ap_none port = rows_out
    #pragma HLS INTERFACE mode = ap_none port = cols_out
    #pragma HLS INTERFACE mode = ap_none port = insert_protocol_fault_req
    #pragma HLS INTERFACE mode = ap_none port = insert_protocol_fault_data
    #pragma HLS INTERFACE mode = ap_none port = snd_req
    #pragma HLS INTERFACE mode = ap_none port = rcv_resp
    #pragma HLS INTERFACE mode = ap_none port = snd_data
    #pragma HLS INTERFACE mode = ap_ctrl_hs port = return    

    data_out<CTL_WIDTH, FCDT_WIDTH, PACKET_PIX, TYPE, OUT_HEIGHT, OUT_WIDTH, NPC_T>(
        s_axis_local_req, 
        s_axis_rx_data, 
        m_axis_tx_req, 
        s_axis_tx_resp, 
        m_axis_tx_data, 
        rows_out, 
        cols_out, 
        stat_egr_snd_data, 
        stat_egr_snd_frame, 
        insert_protocol_fault_req, 
        insert_protocol_fault_data, 
        snd_req, 
        rcv_resp, 
        snd_data
    );

}
}
