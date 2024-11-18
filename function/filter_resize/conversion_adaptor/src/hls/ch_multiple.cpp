/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "ch_multiple.hpp"
#include "chain_control.hpp"
#include <iostream>

template <int CTLWIDTH,
          int IFNUM>
void req2req(
		hls::stream<ap_uint<CTLWIDTH>> _s_axis_req[IFNUM],
		hls::stream<ap_uint<CTLWIDTH>>& _m_axis_req,
		hls::stream<ap_uint<CTLWIDTH>, 1024>& _local_axis_req,
		volatile uint16_t &egr_snd_fail_insert,
		volatile uint32_t &snd_req)
{

	ap_uint<CTLWIDTH> s_req;
	ap_uint<CTLWIDTH> latched_req[IFNUM] = {0};
	ap_uint<CTLWIDTH> local_req;
	static uint32_t snd_req_cnt = 0;
	int sof = 0;
	int eof = 0;
	int ch_id = 0;
	int latched_cid[IFNUM] = {0};
	int not_rd_flg[IFNUM] = {0};
	int burst_length = 0;
	int new_length = 0;
	
	static uint8_t if_cnt = 0;
	static uint8_t if_oth = 0;

	// init
	for(int i=0; i<IFNUM; i++) {
		#pragma HLS unroll
		latched_req[i] = 0;
		latched_cid[i] = 0xFFFFFFFF;
		not_rd_flg[i] = 0;
	}

	do {
		#pragma HLS PIPELINE style=flp
		if_oth = ~if_cnt & 0x01;

		if(not_rd_flg[if_cnt]) {
			// ch_id comparison during flag assertion
			if(ch_id != latched_cid[if_oth]) {
				// Send req from latched req if ch_id is mis-hit
				local_req = latched_req[if_cnt];
				_m_axis_req.write(latched_req[if_cnt]);
				_local_axis_req.write(local_req);
				snd_req_cnt = snd_req_cnt + 1;
				snd_req = snd_req_cnt;

				// Latch req/Flag clear
				not_rd_flg[if_cnt]  = 0;
				latched_req[if_cnt] = 0;
			}
		} else if (!_s_axis_req[if_cnt].empty()) {
			// If there is no latched req, a new one is received.
			s_req = _s_axis_req[if_cnt].read();
        	ch_id        = (int)(s_req>>32) & 0x000001FF; // max:511(9bit)
			sof          = (int)(s_req>>41) & 0x00000001;
			eof          = (int)(s_req>>42) & 0x00000001;
	    	burst_length = (int)(s_req>>48) & 0x0000FFFF; // padding included length

			// Insert Pseudo Fault
			uint16_t snd_fail_insert = egr_snd_fail_insert;
			if((snd_fail_insert >> EGR_PROTOCOL_FAULT_BURST_LENGTH_NZ) & 0x1) {
				new_length = 0x0;
			} else {
				new_length = (burst_length*3) >> 2;         // Convert to no padding
			}

			if(sof) {
				// sof=1: ch_id comparison
				if(ch_id == latched_cid[if_oth]) {
					// If the same ch_id is hit, req latch/flag assert
					not_rd_flg[if_cnt]  = 1;
					latched_req[if_cnt] = ((ulong)new_length << 48) | ((ulong)if_cnt << 44) | (ulong)s_req(43, 0);
				} else {
					// If not the same ch_id, req transmitted/ch_id latch
					latched_cid[if_cnt] = ch_id;
					local_req = ((ulong)new_length << 48) | ((ulong)if_cnt << 44) | (ulong)s_req(43, 0);
					_m_axis_req.write(local_req); //_m_axis_req.write(s_req);
					_local_axis_req.write(local_req);
					snd_req_cnt = snd_req_cnt + 1;
					snd_req = snd_req_cnt;
				}
			} else {
				// Except for sof=1, req is transmitted without change.
				local_req = ((ulong)new_length << 48) | ((ulong)if_cnt << 44) | (ulong)s_req(43, 0);
				_m_axis_req.write(local_req); //_m_axis_req.write(s_req);
				_local_axis_req.write(local_req);
				snd_req_cnt = snd_req_cnt + 1;
				snd_req = snd_req_cnt;
			}

			if(eof) {
				// eof=1: latch ch_id clear
				latched_cid[if_cnt] = 0xFFFFFFFF;
			}
		}

		if (if_cnt == IFNUM - 1) {
			if_cnt = 0;
		}else{
			if_cnt = if_cnt + 1;
		}
	}while(1);

} //void


template <int CTLWIDTH,
          int IFNUM>
void resp2resp(
		hls::stream<ap_uint<CTLWIDTH>>& _s_axis_resp,
		hls::stream<ap_uint<CTLWIDTH>, 1024>& _local_axis_req,
		hls::stream<ap_uint<CTLWIDTH>> _m_axis_resp[IFNUM],
		hls::stream<ap_uint<CTLWIDTH>, 1024> _local_axis_resp[IFNUM],
		hls::stream<ap_uint<CTLWIDTH>, 1024>& _local_dtwr_resp,
		volatile uint16_t &egr_rcv_fail_insert,
		volatile uint32_t &snd_resp)
{
	static uint32_t snd_resp_cnt = 0;
	int num = 0;
	num &= 0x7; //max:7(3bit)

	do {
		#pragma HLS PIPELINE style=flp

		if ((!_s_axis_resp.empty()) && (!_local_axis_req.empty())) {
			// resp/internal req receive
			ap_uint<CTLWIDTH> s_resp;
			_s_axis_resp.read_nb(s_resp);
			int frame_length = (int)s_resp(31, 0);
	    	int ch_id        = (int)s_resp(40, 32);
	    	int sof          = (int)s_resp(41, 41);
	    	int eof          = (int)s_resp(42, 42);
			int burst_length = (int)s_resp(63, 48);
			int new_length   = (burst_length<<2) / 3; // Return to length with padding in response to fil_rsz

			ap_uint<CTLWIDTH> local_req;
			_local_axis_req.read_nb(local_req);
			num    = (int)(local_req>>44) & 0x00000007;

			// Insert Pseudo Fault
			uint16_t rcv_fail_insert = egr_rcv_fail_insert;
        	if( rcv_fail_insert > 0) {
				if(num == 0) {
        	        if( (rcv_fail_insert >> EGR_PROTOCOL_FAULT_CHANNEL_EQ_REQ_0) & 0x00000001 ) {
        	            ch_id = ~ch_id & 0x1FF;
        	        } else if( (rcv_fail_insert >> EGR_PROTOCOL_FAULT_BURST_LENGTH_LE_REQ_0) & 0x00000001 ) {
        	            new_length = MAX_BURST_LENGTH;
        	        } else if( (rcv_fail_insert >> EGR_PROTOCOL_FAULT_SOF_EQ_REQ_0) & 0x00000001 ) {
        	            sof = ~sof & 0x1;
        	        } else if( (rcv_fail_insert >> EGR_PROTOCOL_FAULT_EOF_EQ_REQ_0) & 0x00000001 ) {
        	            eof = ~eof & 0x1;
        	        } else if( (rcv_fail_insert >> EGR_PROTOCOL_FAULT_MAX_BURST_LENGTH_0) & 0x00000001 ) {
        	            new_length = MAX_BURST_LENGTH + 1;
        	        }
				} else {
					if( (rcv_fail_insert >> EGR_PROTOCOL_FAULT_CHANNEL_EQ_REQ_1) & 0x00000001 ) {
        	            ch_id = ~ch_id & 0x1FF;
        	        } else if( (rcv_fail_insert >> EGR_PROTOCOL_FAULT_BURST_LENGTH_LE_REQ_) & 0x00000001 ) {
        	            new_length = MAX_BURST_LENGTH;
        	        } else if( (rcv_fail_insert >> EGR_PROTOCOL_FAULT_SOF_EQ_REQ_1) & 0x00000001 ) {
        	            sof = ~sof & 0x1;
        	        } else if( (rcv_fail_insert >> EGR_PROTOCOL_FAULT_EOF_EQ_REQ_1) & 0x00000001 ) {
        	            eof = ~eof & 0x1;
        	        } else if( (rcv_fail_insert >> EGR_PROTOCOL_FAULT_MAX_BURST_LENGTH_1) & 0x00000001 ) {
        	            new_length = MAX_BURST_LENGTH + 1;
        	        }
				}
        	}

			ap_uint<CTLWIDTH> s_resp_re = ((ap_uint<CTLWIDTH>)new_length << 48) | ((ap_uint<CTLWIDTH>)eof << 42) | ((ap_uint<CTLWIDTH>)sof << 41) | ((ap_uint<CTLWIDTH>)ch_id << 32) | (ap_uint<CTLWIDTH>)frame_length;
			ap_uint<CTLWIDTH> s_local_resp = ((ap_uint<CTLWIDTH>)new_length << 48) | local_req;

			// resp/internal req send
			_m_axis_resp[num].write(s_resp_re);
			_local_axis_resp[num].write(s_resp_re);
			_local_dtwr_resp.write(s_local_resp);
			
			// Debug register
			snd_resp_cnt = snd_resp_cnt + 1;
			snd_resp = snd_resp_cnt;
		}
	}while(1);

} //void

template <int CTLWIDTH,
          int FCDTWIDTH,
          int MDDTWIDTH>
void data_rd(
		hls::stream<ap_uint<CTLWIDTH>, 1024>& _local_axis_resp,
		hls::stream<ap_uint<FCDTWIDTH>, 1024>& _s_axis_data,
		hls::stream<ap_uint<MDDTWIDTH>, 1024*2>& _local_data,
		hls::stream<ap_uint<CTLWIDTH>, 1024>& _local_num,
		volatile ap_uint<24> &st_rcv_data,
		volatile ap_uint<24> &st_rcv_frame)
{

	ap_uint<CTLWIDTH> local_resp;
	ap_uint<CTLWIDTH> local_resp_re;
	bool nflg = false;
	ap_uint<MDDTWIDTH> buffer = 0;
	int buffer_len = 0;
	static int PACK_NUM = MDDTWIDTH / 24;
	static int BYTE_NUM = (FCDTWIDTH*3) >> 5; //byte
	static ap_uint<24> rcv_data = 0;
	static ap_uint<24> rcv_frame = 0;

	do {
		#pragma HLS PIPELINE style=flp

		if (!_local_axis_resp.empty()) {
			nflg = false;
			_local_axis_resp.read_nb(local_resp);
			int frame_length = (int)(local_resp>>0)  & 0x001FFFFF; // max:1MB(21bit)
	        int ch_id        = (int)(local_resp>>32) & 0x000001FF; // max:511(9bit)
			int eof          = (int)(local_resp>>42) & 0x00000001; // 
		    int burst_length = (int)(local_resp>>48) & 0x0000FFFF; // padding included length
			int length_new   = (burst_length>>2)*3;                // Convert to length without padding for data_wr

			local_resp_re = (ap_uint<CTLWIDTH>)length_new<<48 | (ap_uint<CTLWIDTH>)local_resp(47,0);

			data_rd:for (int i=0; i<(burst_length>>2); i++){ // cols
				#pragma HLS PIPELINE
				// Receive 32 bit data
				ap_uint<32> data_32 = _s_axis_data.read();
				
				// Statistics counters
				rcv_data = (ap_uint<24>)BYTE_NUM<<16 | (ap_uint<24>)ch_id;
				st_rcv_data = rcv_data;
				
        		// Real Data Extraction
				ap_uint<24> valid_data = data_32(23, 0);

				// If adding data to the buffer exceeds 512 bits
				if (buffer_len + 24 > 512) { 
					int overflow = buffer_len + 24 - 512;
            		buffer(buffer_len + 23 - overflow, buffer_len) = valid_data(23-overflow, 0); // Add Data to Buffer
					_local_data.write(buffer); // buffer output
            		buffer = 0;                // Buffer Clear
            		buffer(overflow-1, 0) = valid_data(23, 24-overflow); // add data to the buffer to carry over to the next time
            		buffer_len = overflow; // Buffer length update
					nflg = false;
        		} 
				// If adding data to the buffer results in 512 bits
				else if (buffer_len + 24 == 512) { 
            		buffer(buffer_len + 23, buffer_len) = valid_data; // Add Data to Buffer
            		_local_data.write(buffer); // buffer output
            		buffer = 0;                // Buffer Clear
            		buffer_len = 0;            // Reset Buffer Length
					nflg = false;
					// Send local_num when looping with exactly 512 bits.
					if(i==(burst_length>>2) - 1){
						_local_num.write(local_resp_re);
					}
				}
				// If the buffer is less than 512 bits when data is added
				else {
            		buffer(buffer_len + 23, buffer_len) = valid_data; // Add Data to Buffer
            		buffer_len += 24; // Buffer length update
					nflg = true;
        		}
			}

			// Statistics
			if(eof) {
				rcv_frame = (0x00000001 << 16) | ch_id;
				st_rcv_frame = rcv_frame;
			}

		}
	}while(1);

}

template <int CTLWIDTH,
          int MDDTWIDTH,
          int IFNUM>
void data_wr(
		hls::stream<ap_uint<CTLWIDTH>, 1024>& _local_dtwr_resp,
		hls::stream<ap_uint<CTLWIDTH>, 1024> _local_num[IFNUM],
		hls::stream<ap_uint<MDDTWIDTH>, 1024*2> _local_data[IFNUM],
		hls::stream<ap_uint<MDDTWIDTH>>& _m_axis_data,
		volatile uint16_t &egr_snd_fail_insert,
		volatile ap_uint<24> &st_snd_data,
		volatile ap_uint<24> &st_snd_frame,
		volatile uint32_t &snd_data)
{

	static ap_uint<24> snd_dt;
	static ap_uint<24> snd_fr;
	static uint32_t snd_data_cnt = 0;

	do {
		//#pragma HLS PIPELINE style=flp

		if (!_local_dtwr_resp.empty()) {
			// Internal resp receive
			ap_uint<CTLWIDTH> local_dtwr_resp;
			_local_dtwr_resp.read_nb(local_dtwr_resp);
			int if_no = (int)(local_dtwr_resp>>44) & 0x00000007;

			// Internal req received
			ap_uint<CTLWIDTH> local_num = _local_num[if_no].read();
			int ch_id  = (int)(local_num>>32) & 0x000001FF; //9bit
			int eof    = (int)(local_num>>42) & 0x00000001; //1bit
			int num    = (int)(local_num>>44) & 0x00000007; //3bit
			int length = (int)(local_num>>48) & 0x0000FFFF; // No padding length
			int length_new = length + 63;

			

			ap_uint<MDDTWIDTH> local_data;
			while(_local_data[if_no].empty());
			data_wr:for (int i=0; i<(length_new>>6); i++){ // 512 bit bus
				//#pragma HLS PIPELINE
				local_data = _local_data[if_no].read();
				_m_axis_data.write(local_data);
				
				// Statistics register (set valid byte when the amount of data sent per 1req is 64 bytes or less)
				int val_byte = 0;
				if(length - 64*i < 64) {
					val_byte = length - 64*i;
				} else {
					val_byte = MDDTWIDTH>>3;
				}
				snd_dt = (ap_uint<24>)val_byte<<16 | (ap_uint<24>)ch_id;
				st_snd_data = snd_dt;
				
				// Debug register
				snd_data_cnt = snd_data_cnt + 1;
				snd_data = snd_data_cnt;
			}

			// Statistics
			if(eof) {
				snd_fr = (0x00000001 << 16) | ch_id;
				st_snd_frame = snd_fr;
			}

			// Insert Pseudo Fault
			uint16_t snd_fail_insert = egr_snd_fail_insert;
			if((snd_fail_insert >> EGR_PROTOCOL_FAULT_TRANS_CW_RESP) & 0x1) {
				_m_axis_data.write(local_data);
			}
		}
	}while(1);

} //void


template <int CTLWIDTH,
          int FCDTWIDTH,
          int MDDTWIDTH,
          int IFNUM>
void ch_multiple_proc(
		hls::stream<ap_uint<CTLWIDTH>> _s_axis_req[IFNUM],
		hls::stream<ap_uint<CTLWIDTH>> _m_axis_resp[IFNUM],
		hls::stream<ap_uint<FCDTWIDTH>, 1024> _s_axis_data[IFNUM],
		hls::stream<ap_uint<CTLWIDTH>>& _m_axis_req,
		hls::stream<ap_uint<CTLWIDTH>>& _s_axis_resp,
		hls::stream<ap_uint<MDDTWIDTH>>& _m_axis_data,
		volatile ap_uint<24> &st_rcv_data_0,
		volatile ap_uint<24> &st_rcv_data_1,
		volatile ap_uint<24> &st_snd_data,
		volatile ap_uint<24> &st_rcv_frame_0,
		volatile ap_uint<24> &st_rcv_frame_1,
		volatile ap_uint<24> &st_snd_frame,
		volatile uint16_t    &fail_insert,
		volatile uint32_t &snd_req,
		volatile uint32_t &snd_resp,
		volatile uint32_t &snd_data)
{
#pragma HLS stable variable = fail_insert

	hls::stream<ap_uint<CTLWIDTH>, 1024> _local_axis_req;
	hls::stream<ap_uint<CTLWIDTH>, 1024> _local_axis_resp[IFNUM];
	hls::stream<ap_uint<MDDTWIDTH>, 1024*2> _local_data[IFNUM];
	hls::stream<ap_uint<CTLWIDTH>, 1024> _local_dtwr_resp;
	hls::stream<ap_uint<CTLWIDTH>, 1024> _local_num[IFNUM];

	#pragma HLS DATAFLOW
	req2req<CTLWIDTH, IFNUM>(_s_axis_req, _m_axis_req, _local_axis_req, fail_insert, snd_req);
	resp2resp<CTLWIDTH, IFNUM>(_s_axis_resp, _local_axis_req, _m_axis_resp, _local_axis_resp, _local_dtwr_resp, fail_insert, snd_resp);
	data_rd<CTLWIDTH, FCDTWIDTH, MDDTWIDTH>(_local_axis_resp[0], _s_axis_data[0], _local_data[0], _local_num[0], st_rcv_data_0, st_rcv_frame_0);
	data_rd<CTLWIDTH, FCDTWIDTH, MDDTWIDTH>(_local_axis_resp[1], _s_axis_data[1], _local_data[1], _local_num[1], st_rcv_data_1, st_rcv_frame_1);
#if IF_NUM == 3
	data_rd<CTLWIDTH, FCDTWIDTH, MDDTWIDTH>(_local_axis_resp[2], _s_axis_data[2], _local_data[2]);
#endif
	data_wr<CTLWIDTH, MDDTWIDTH, IFNUM>(_local_dtwr_resp, _local_num, _local_data, _m_axis_data, fail_insert, st_snd_data, st_snd_frame, snd_data);

} //void


/**
 * Image resizing function.
 */
void ch_multiple(
		hls::stream<ap_uint<CTL_WIDTH>>   s_axis_egr_rx_req[IF_NUM],
		hls::stream<ap_uint<CTL_WIDTH>>   m_axis_egr_rx_resp[IF_NUM],
		hls::stream<ap_uint<FCDT_WIDTH>, 1024>  s_axis_egr_rx_data[IF_NUM],
		hls::stream<ap_uint<CTL_WIDTH>>&  m_axis_egr_tx_req,
		hls::stream<ap_uint<CTL_WIDTH>>&  s_axis_egr_tx_resp,
		hls::stream<ap_uint<MDDT_WIDTH>>& m_axis_egr_tx_data,
		volatile ap_uint<24> &stat_egr_rcv_data_0,
		volatile ap_uint<24> &stat_egr_rcv_data_1,
		volatile ap_uint<24> &stat_egr_snd_data,
		volatile ap_uint<24> &stat_egr_rcv_frame_0,
		volatile ap_uint<24> &stat_egr_rcv_frame_1,
		volatile ap_uint<24> &stat_egr_snd_frame,
		volatile uint16_t    &egr_fail_insert,
		volatile uint32_t &snd_req,
		volatile uint32_t &snd_resp,
		volatile uint32_t &snd_data)
{
#pragma HLS INTERFACE mode = axis port = s_axis_egr_rx_req
#pragma HLS INTERFACE mode = axis port = m_axis_egr_rx_resp
#pragma HLS INTERFACE mode = axis port = s_axis_egr_rx_data
#pragma HLS INTERFACE mode = axis port = m_axis_egr_tx_req
#pragma HLS INTERFACE mode = axis port = s_axis_egr_tx_resp
#pragma HLS INTERFACE mode = axis port = m_axis_egr_tx_data
#pragma HLS INTERFACE mode = ap_none port = egr_fail_insert
#pragma HLS INTERFACE mode = ap_none port = snd_req
#pragma HLS INTERFACE mode = ap_none port = snd_resp
#pragma HLS INTERFACE mode = ap_none port = snd_data
#pragma HLS INTERFACE mode = ap_ctrl_chain port = return

	ch_multiple_proc<CTL_WIDTH, FCDT_WIDTH, MDDT_WIDTH, IF_NUM>(s_axis_egr_rx_req, m_axis_egr_rx_resp, s_axis_egr_rx_data, m_axis_egr_tx_req, s_axis_egr_tx_resp, m_axis_egr_tx_data, 
	                                                            stat_egr_rcv_data_0, stat_egr_rcv_data_1, stat_egr_snd_data, stat_egr_rcv_frame_0, stat_egr_rcv_frame_1, stat_egr_snd_frame, egr_fail_insert, snd_req, snd_resp, snd_data);

} //void
