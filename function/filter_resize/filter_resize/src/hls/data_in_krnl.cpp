/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include <ap_axi_sdata.h>
#include <iostream>

#include "filter_resize_config.h"
#include "usr_struct.h"
#include "data_in.hpp"
#include "common/xf_common.hpp"

extern "C" {
void data_in_krnl(
				hls::stream<ap_uint<CTL_WIDTH>>& s_axis_rx_req,
				hls::stream<ap_uint<CTL_WIDTH>>& s_axis_local_req,
				hls::stream<ap_uint<CTL_WIDTH>>& m_axis_rx_resp,
				hls::stream<ap_uint<FCDT_WIDTH>>& s_axis_rx_data,
				hls::stream<ap_uint<FCDT_WIDTH>>& m_axis_tx_data,
				int rows_in,
				int cols_in,
                volatile ap_uint<24> &stat_ingr_rcv_data,
                volatile ap_uint<24> &stat_ingr_rcv_frame,
                ap_uint<5> insert_protocol_fault,
				volatile uint32_t &rcv_req,
				volatile uint32_t &snd_resp,
				volatile uint32_t &rcv_sof,
				volatile uint32_t &rcv_cid_diff,
				volatile uint32_t &rcv_line_chk,
				volatile uint32_t &rcv_data,
				volatile uint32_t &rcv_length_chk
                  ) {
    #pragma HLS INTERFACE mode = axis port = s_axis_rx_req
    #pragma HLS INTERFACE mode = axis port = s_axis_local_req
    #pragma HLS INTERFACE mode = axis port = m_axis_rx_resp
    #pragma HLS INTERFACE mode = axis port = s_axis_rx_data
    #pragma HLS INTERFACE mode = axis port = m_axis_tx_data
    #pragma HLS INTERFACE mode = ap_none port = rows_in
    #pragma HLS INTERFACE mode = ap_none port = cols_in
    #pragma HLS INTERFACE mode = ap_none port = insert_protocol_fault
    #pragma HLS INTERFACE mode = ap_none port = rcv_req
    #pragma HLS INTERFACE mode = ap_none port = snd_resp
    #pragma HLS INTERFACE mode = ap_none port = rcv_sof
    #pragma HLS INTERFACE mode = ap_none port = rcv_cid_diff
    #pragma HLS INTERFACE mode = ap_none port = rcv_line_chk
    #pragma HLS INTERFACE mode = ap_none port = rcv_data
    #pragma HLS INTERFACE mode = ap_none port = rcv_length_chk
    #pragma HLS INTERFACE mode = ap_ctrl_hs port = return    

    data_in<CTL_WIDTH, FCDT_WIDTH, TYPE, IN_HEIGHT, IN_WIDTH, NPC_T>(s_axis_rx_req, s_axis_local_req, m_axis_rx_resp, s_axis_rx_data, m_axis_tx_data, rows_in, cols_in,
                                                                   stat_ingr_rcv_data, stat_ingr_rcv_frame, insert_protocol_fault, rcv_req, snd_resp, rcv_sof, rcv_cid_diff, rcv_line_chk, rcv_data, rcv_length_chk);

}
}
