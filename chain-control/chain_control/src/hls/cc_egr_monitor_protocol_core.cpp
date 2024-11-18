/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "monitor_protocol_subblock.hpp"

static constexpr int OUTSTANDING_NUM = 2;
static constexpr int DATA_WIDTH_BYTES = TRANS_DATA_WIDTH_BYTES;
static constexpr int REQ_BURST_LENGTH_NZ = 1;
static constexpr int RESP_BURST_LENGTH_EQ_REQ = 0;

void cc_egr_monitor_protocol_core(bool &req_ready,
                                  bool &req_valid,
                                  sessionReq &req_data,
                                  bool &resp_ready_0,
                                  bool &resp_valid_0,
                                  sessionReq &resp_data_0,
                                  bool &resp_ready_1,
                                  bool &resp_valid_1,
                                  sessionReq &resp_data_1,
                                  bool &data_ready,
                                  bool &data_valid,
                                  session_data_t &data_data,
                                  volatile bool &fault_resp_channel_eq_req,      // [0]
                                  volatile bool &fault_resp_burst_length_le_req, // [1]
                                  volatile bool &fault_resp_sof_eq_req,          // [2]
                                  volatile bool &fault_resp_eof_eq_req,          // [3]
                                  volatile bool &fault_resp_trans_cw_req,        // [4]
                                  volatile bool &fault_data_trans_cw_resp,       // [5]
                                  volatile bool &fault_req_outstanding,          // [6]
                                  volatile bool &fault_resp_outstanding_0,       // [7]
                                  volatile bool &fault_resp_outstanding_1,       // [7]
                                  volatile bool &fault_data_outstanding,         // [8]
                                  volatile bool &fault_req_max_burst_length,     // [9]
                                  volatile bool &fault_req_burst_length_nz,      // [12]
                                  volatile bool &fault_resp_burst_length_eq_req  // [13]
)
{
#pragma HLS INTERFACE mode = ap_none port = fault_resp_channel_eq_req
#pragma HLS INTERFACE mode = ap_none port = fault_resp_burst_length_le_req
#pragma HLS INTERFACE mode = ap_none port = fault_resp_sof_eq_req
#pragma HLS INTERFACE mode = ap_none port = fault_resp_eof_eq_req
#pragma HLS INTERFACE mode = ap_none port = fault_resp_trans_cw_req
#pragma HLS INTERFACE mode = ap_none port = fault_data_trans_cw_resp
#pragma HLS INTERFACE mode = ap_none port = fault_req_outstanding
#pragma HLS INTERFACE mode = ap_none port = fault_resp_outstanding_0
#pragma HLS INTERFACE mode = ap_none port = fault_resp_outstanding_1
#pragma HLS INTERFACE mode = ap_none port = fault_data_outstanding
#pragma HLS INTERFACE mode = ap_none port = fault_req_max_burst_length
#pragma HLS INTERFACE mode = ap_none port = fault_req_burst_length_nz
#pragma HLS INTERFACE mode = ap_none port = fault_resp_burst_length_eq_req
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

#pragma HLS dataflow disable_start_propagation

    // transaction queue
    hls::stream<sessionReq> req_queue;
#pragma HLS stream variable = req_queue depth = OUTSTANDING_NUM
    hls::stream<sessionReq> resp_queue_0;
#pragma HLS stream variable = resp_queue_0 depth = OUTSTANDING_NUM
    hls::stream<sessionReq> resp_queue_1;
#pragma HLS stream variable = resp_queue_1 depth = OUTSTANDING_NUM
    hls::stream<session_data_t> data_queue;
#pragma HLS stream variable = data_queue depth = (OUTSTANDING_NUM + 1)

    enqueue<sessionReq>(req_ready,
                        req_valid,
                        req_data,
                        req_queue,
                        fault_req_outstanding);

    enqueue<sessionReq>(resp_ready_0,
                        resp_valid_0,
                        resp_data_0,
                        resp_queue_0,
                        fault_resp_outstanding_0);

    enqueue<sessionReq>(resp_ready_1,
                        resp_valid_1,
                        resp_data_1,
                        resp_queue_1,
                        fault_resp_outstanding_1);

    enqueue<session_data_t>(data_ready,
                            data_valid,
                            data_data,
                            data_queue,
                            fault_data_outstanding);

    check_req_resp<REQ_BURST_LENGTH_NZ, RESP_BURST_LENGTH_EQ_REQ, MAX_BURST_LENGTH>(req_queue,
                                                                                    resp_queue_0,
                                                                                    fault_resp_channel_eq_req,
                                                                                    fault_resp_burst_length_le_req,
                                                                                    fault_resp_sof_eq_req,
                                                                                    fault_resp_eof_eq_req,
                                                                                    fault_resp_trans_cw_req,
                                                                                    fault_req_max_burst_length,
                                                                                    fault_req_burst_length_nz,
                                                                                    fault_resp_burst_length_eq_req);

    check_resp_data<DATA_WIDTH_BYTES>(resp_queue_1,
                                      data_queue,
                                      fault_data_trans_cw_resp);
}
