/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "usr_struct.h"
#include "chain_control.hpp"
#include <iostream>

#ifndef _DATA_IN_
#define _DATA_IN_

template <int CTLWIDTH>
void req2req(hls::stream<ap_uint<CTLWIDTH>>& _s_req,
                hls::stream<ap_uint<CTLWIDTH>>& _req_out,
                hls::stream<ap_uint<CTLWIDTH>>& _req_re,
                hls::stream<ap_uint<CTLWIDTH>>& _m_resp,
                int rows,
				ap_uint<5> ins_protocol_fault,
				volatile uint32_t &rcv_req,
                volatile uint32_t &snd_resp, 
                volatile uint32_t &rcv_sof,
                volatile uint32_t &rcv_cid_diff,
                volatile uint32_t &rcv_line_chk) {

    ap_uint<CTLWIDTH> req;
	ap_uint<CTLWIDTH> req_new;
	int frame_length = 0;
    int ch_id = 0;
	int sof = 0;
    int eof = 0;
	int direct = 0;
	int length = 0;
    int ch_id_tmp = 0;
	static uint32_t rcv_line_cnt = 0;
	static uint32_t rcv_req_cnt = 0;
	static uint32_t snd_resp_cnt = 0;
	static uint32_t rcv_sof_cnt = 0;
	static uint32_t rcv_cid_diff_cnt = 0;
	static uint32_t rcv_line_chk_cnt = 0;
	bool ext = false;

    do {
		#pragma HLS PIPELINE style=flp
		// req received
		req = _s_req.read();
		frame_length = req(31, 0);
	    ch_id        = req(40, 32);
	    sof          = req(41, 41);
	    eof          = req(42, 42);
        direct       = req(43, 43);
        length       = req(63, 48);

		rcv_req_cnt = rcv_req_cnt + 1;
		rcv_req = rcv_req_cnt;

		// Insert Pseudo Fault (tentative)
        if( ins_protocol_fault > 0) {
            if( (ins_protocol_fault >> FR_PROTOCOL_FAULT_RESP_CHANNEL_EQ_REQ) & 0x00000001 ) {        //[0] insert_channel_fault
                ch_id = ~ch_id & 0x000001FF;
            } else if( (ins_protocol_fault >> FR_PROTOCOL_FAULT_RESP_BURST_LENGTH_LE_REQ) & 0x00000001 ) { //[1] insert_length_fault
                length = MAX_BURST_LENGTH;
            } else if( (ins_protocol_fault >> FR_PROTOCOL_FAULT_RESP_SOF_EQ_REQ) & 0x00000001 ) { //[2] insert_sof_fault
                sof = ~sof & 0x1;
            } else if( (ins_protocol_fault >> FR_PROTOCOL_FAULT_RESP_EOF_EQ_REQ) & 0x00000001 ) { //[3] insert_eof_fault
                eof = ~eof & 0x1;;
            } else if( (ins_protocol_fault >> FR_PROTOCOL_FAULT_RESP_BURST_LENGTH_EQ_REQ) & 0x00000001 ) { //[4] insert_eq_length_fault
                length = ~length;
            }
			req_new = (ap_uint<CTLWIDTH>)length<<48 | (ap_uint<CTLWIDTH>)direct<<43 | (ap_uint<CTLWIDTH>)eof<<42 | (ap_uint<CTLWIDTH>)sof<<41 | (ap_uint<CTLWIDTH>)ch_id<<32 | (ap_uint<CTLWIDTH>)frame_length;
        } else {
			req_new = req;
		}
		
		// resp send
		_m_resp.write(req_new);

		// local _req send
		_req_re.write(req_new);
		
		// end req to data_out at -sof
		if (sof == 1) {
			_req_out.write(req_new);
			rcv_sof_cnt = rcv_sof_cnt + 1;
			rcv_sof = rcv_sof_cnt;
		}
		
		if (ch_id != ch_id_tmp) {
			rcv_cid_diff_cnt = rcv_cid_diff_cnt + 1;
			rcv_cid_diff = rcv_cid_diff_cnt;
		}
		ch_id_tmp = ch_id;


		rcv_line_cnt = rcv_line_cnt + 1;
		if (eof == 1) {
			if (rcv_line_cnt != rows) {
				rcv_line_chk_cnt = rcv_line_chk_cnt + 1;
				rcv_line_chk = rcv_line_chk_cnt;
			}
			rcv_line_cnt = 0;
		}
	
		snd_resp_cnt = snd_resp_cnt + 1;
		snd_resp = snd_resp_cnt;

		if(eof) {
			ext = true;
		}

	}while(!ext);
}

template <int CTLWIDTH,
          int DTWIDTH,
          int TYPE,
          int SRC_ROWS,
          int SRC_COLS,
          int NPC>
void data2Mat(hls::stream<ap_uint<CTLWIDTH>>& _req_re,
              hls::stream<ap_uint<DTWIDTH>>& _data,
              hls::stream<ap_uint<DTWIDTH>>& _data_out,
              int cols,
			  volatile ap_uint<24> &st_igr_rcv_dt,
			  volatile ap_uint<24> &st_igr_rcv_fr,
              volatile uint32_t &rcv_data,
              volatile uint32_t &rcv_length_chk) {

    ap_uint<CTLWIDTH> req;
    ap_uint<DTWIDTH> data;
	static ap_uint<24> rcv_byte = 0;
	static ap_uint<24> rcv_frame = 0;
	static ap_uint<24> bytenum  = 3;
	static uint32_t rcv_data_cnt = 0;
	static uint32_t rcv_length_chk_cnt = 0;

    int ch_id = 0;
	int length = 0;
    int eof = 0;
	bool ext = false;

    do {
		#pragma HLS PIPELINE style=flp
	    // req received
		req = _req_re.read();
	    ch_id  = req(40, 32);
		eof    = req(42, 42);
        length = req(63, 48);

		if (length != cols*4) {
			rcv_length_chk_cnt = rcv_length_chk_cnt + 1;
			rcv_length_chk = rcv_length_chk_cnt;
		}
			
	    // length data sent
		data_in_data2Mat:for (int i=0; i<(length >> 2); i++){
	        #pragma HLS PIPELINE
	        data = _data.read();
			
			// Statistics
			rcv_byte = bytenum<<16 | ch_id;
			st_igr_rcv_dt = rcv_byte;
	        rcv_data_cnt = rcv_data_cnt + 1;
	        rcv_data = rcv_data_cnt;
		    
			// data send
			_data_out.write(data);
		}

		if(eof) {
			rcv_frame = 0x00000001<<16 | ch_id;
			st_igr_rcv_fr = rcv_frame;
			ext = true;
		}

    }while(!ext);

}

/**
 * Image resizing function.
 */
template <int CTLWIDTH,
          int DTWIDTH,
          int TYPE,
          int SRC_ROWS,
          int SRC_COLS,
          int NPC>
void data_in(hls::stream<ap_uint<CTLWIDTH>>& _s_req,
             hls::stream<ap_uint<CTLWIDTH>>& _req_out,
             hls::stream<ap_uint<CTLWIDTH>>& _m_resp,
             hls::stream<ap_uint<DTWIDTH>>& _data,
             hls::stream<ap_uint<DTWIDTH>>& _data_out,
             int rows,
             int cols,
             volatile ap_uint<24> &st_igr_rcv_dt,
			 volatile ap_uint<24> &st_igr_rcv_fr,
             ap_uint<5> ins_protocol_fault,
             volatile uint32_t &rcv_req,
             volatile uint32_t &snd_resp,
             volatile uint32_t &rcv_sof,
             volatile uint32_t &rcv_cid_diff,
             volatile uint32_t &rcv_line_chk,
             volatile uint32_t &rcv_data,
             volatile uint32_t &rcv_length_chk
) {

    hls::stream<ap_uint<CTLWIDTH>> _req_re;

    #pragma HLS DATAFLOW
    req2req<CTLWIDTH>(_s_req, _req_out, _req_re, _m_resp, rows, ins_protocol_fault, rcv_req, snd_resp, rcv_sof, rcv_cid_diff, rcv_line_chk);
    data2Mat<CTLWIDTH, DTWIDTH, TYPE, SRC_ROWS, SRC_COLS, NPC>(_req_re, _data, _data_out, cols, st_igr_rcv_dt, st_igr_rcv_fr, rcv_data, rcv_length_chk);

}

#endif
