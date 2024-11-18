/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#ifndef _CH_SEPARATION_
#define _CH_SEPARATION_

#include <hls_stream.h>
#include <ap_int.h>
#include <stdint.h>
#include "usr_struct.h"
#include "xf_config_params.h"

void ch_separation(
		hls::stream<ap_uint<CTL_WIDTH>>&       s_axis_ingr_rx_req,
		hls::stream<ap_uint<CTL_WIDTH>>&       m_axis_ingr_rx_resp,
        hls::stream<ap_uint<MDDT_WIDTH>, 128>& s_axis_ingr_rx_data,
        ap_uint<OUTPUT_PTR_WIDTH>*             m_axi_ingr_frame_buffer,
        hls::stream<ap_uint<CTL_WIDTH>>        m_axis_ingr_tx_req[IF_NUM],
        hls::stream<ap_uint<CTL_WIDTH>>&       s_axis_ingr_tx_resp_0,
        hls::stream<ap_uint<FCDT_WIDTH>>&      m_axis_ingr_tx_data_0,
        //hls::stream<ap_uint<CTL_WIDTH>>&       m_axis_ingr_tx_req_1,
        hls::stream<ap_uint<CTL_WIDTH>>&       s_axis_ingr_tx_resp_1,
        hls::stream<ap_uint<FCDT_WIDTH>>&      m_axis_ingr_tx_data_1,
        int                                    Rows,
        int                                    Cols,
        volatile ap_uint<24>&                  stat_ingr_rcv_data,
        volatile ap_uint<24>&                  stat_ingr_snd_data_0,
        volatile ap_uint<24>&                  stat_ingr_snd_data_1,
        volatile ap_uint<16>&                  stat_ingr_mem_err_detect,
        volatile ap_uint<16>&                  stat_ingr_length_err_detect,
        volatile ap_uint<16>&                  stat_ingr_frame_buffer_write,
        volatile ap_uint<16>&                  stat_ingr_frame_buffer_read,
        ap_uint<9>                             ingr_fail_insert,
		volatile uint32_t&                     rcv_req,
		volatile uint32_t&                     snd_resp,
		volatile uint32_t&                     rcv_dt,
		volatile uint32_t&                     wr_ddr,
		volatile uint32_t&                     rcv_eof,
		volatile uint32_t&                     snd_lreq,
		volatile uint32_t&                     rd_ddr,
		volatile uint32_t&                     snd_req,
		volatile uint32_t&                     rcv_resp_0,
		volatile uint32_t&                     snd_dt_0,
		volatile uint32_t&                     rcv_resp_1,
		volatile uint32_t&                     snd_dt_1);

#endif
