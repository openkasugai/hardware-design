/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#ifndef _CH_MULTIPLE_
#define _CH_MULTIPLE_

#include <hls_stream.h>
#include <ap_int.h>
#include <stdint.h>
#include "usr_struct.h"
#include "xf_config_params.h"

/**
 * Image resizing function.
 */
void ch_multiple(
		hls::stream<ap_uint<CTL_WIDTH>> _s_axis_req[IF_NUM],
		hls::stream<ap_uint<CTL_WIDTH>> _m_axis_resp[IF_NUM],
		hls::stream<ap_uint<FCDT_WIDTH>, 1024> _s_axis_data[IF_NUM],
		hls::stream<ap_uint<CTL_WIDTH>>& _m_axis_req,
		hls::stream<ap_uint<CTL_WIDTH>>& _s_axis_resp,
		hls::stream<ap_uint<MDDT_WIDTH>>& _m_axis_data,
		volatile uint32_t &snd_req,
		volatile uint32_t &snd_resp,
		volatile uint32_t &snd_data);

#endif
