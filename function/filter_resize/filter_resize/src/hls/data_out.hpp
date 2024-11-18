/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "usr_struct.h"
#include "chain_control.hpp"

#ifndef _DATA_OUT_
#define _DATA_OUT_

/**
 * Image resizing sub function.
 */
template <int CTLWIDTH,
          int DTWIDTH,
          int TYPE,
          int DST_ROWS,
          int DST_COLS,
          int NPC>
void Mat2req(int ch_id,
             int frame_length,
             //int length,
             int sof,
             int eof,
             int pix_packet,
             hls::stream<ap_uint<DTWIDTH>>& _data_in,
             hls::stream<ap_uint<DTWIDTH>, 512>& _temp,
             hls::stream<ap_uint<CTLWIDTH>>& _req,
             ap_uint<1> ins_proto_fault_req,
             volatile uint32_t &snd_req) {

	ap_uint<DTWIDTH> data = 0;
	ap_uint<CTLWIDTH> req = 0;

	int length_re = 0;
  static uint32_t snd_req_cnt = 0;

	// receive data for length
	mat2req:for (int i=0; i<pix_packet; i++){
		#pragma HLS PIPELINE
		data = _data_in.read();
		_temp.write(data);

		// Send req only at the head
    if (i==0) {
      // Insert Pseudo Fault
      if(ins_proto_fault_req) {
        length_re = 0;
      } else {
        length_re = pix_packet<<2;
        //length_re = length;
      }

			req = ((ap_uint<CTLWIDTH>)length_re<<48) | ((ap_uint<CTLWIDTH>)eof<<42) | ((ap_uint<CTLWIDTH>)sof<<41) | ((ap_uint<CTLWIDTH>)ch_id<<32) | (ap_uint<CTLWIDTH>)frame_length;
			_req.write(req);
			snd_req_cnt = snd_req_cnt + 1;
			snd_req = snd_req_cnt;
		}
	}
}

template <int CTLWIDTH,
          int DTWIDTH>
void resp2data(
               hls::stream<ap_uint<CTLWIDTH>>& _resp,
               hls::stream<ap_uint<DTWIDTH>, 512>& _temp,
               hls::stream<ap_uint<DTWIDTH>>& _data,
               volatile ap_uint<24> &st_egr_snd_dt,
               volatile ap_uint<24> &st_egr_snd_fr,
               ap_uint<1> ins_proto_fault_data,
               volatile uint32_t &rcv_resp,
               volatile uint32_t &snd_data) {

	ap_uint<CTLWIDTH> resp;
	ap_uint<DTWIDTH> data;
	int eof = 0;
  int ch_id = 0;
  int length = 0;

	static ap_uint<24> snd_byte = 0;
  static ap_uint<24> snd_frame = 0;
  static ap_uint<24> bytenum  = 3;
  static uint32_t rcv_resp_cnt = 0;
	static uint32_t snd_data_cnt = 0;

	// resp receive
	resp = _resp.read();
  ch_id  = (int)resp(40, 32);
  eof    = (int)resp(42, 42);
  length = (int)resp(63, 48);
  rcv_resp_cnt = rcv_resp_cnt + 1;
  rcv_resp = rcv_resp_cnt;
	
  // data send
  data_out_resp2data:for (int i=0; i<(length>>2); i++){
		#pragma HLS PIPELINE
		data = _temp.read();
		_data.write(data);

    // Statistics
    snd_byte = bytenum<<16 | (ap_uint<24>)ch_id;
    st_egr_snd_dt = snd_byte;
		snd_data_cnt = snd_data_cnt + 1;
		snd_data = snd_data_cnt;
	}

  if(eof) {
    snd_frame = 0x00000001<<16 | ch_id;
    st_egr_snd_fr = snd_frame;
  }

  // Insert Pseudo Fault
  if(ins_proto_fault_data) {  //[0]: Insert data+1cycle
    _data.write(data);
  }
}

template <int CTLWIDTH,
          int DTWIDTH,
          int TYPE,
          int DST_ROWS,
          int DST_COLS,
          int NPC>
void data_out_proc(
                   int ch_id,
                   int frame_length,
                   //int length,
                   int sof,
                   int eof,
                   int pix_packet,
                   int pix_sum,
                   hls::stream<ap_uint<DTWIDTH>>& _data_in,
                   hls::stream<ap_uint<CTLWIDTH>>& _req,
                   hls::stream<ap_uint<CTLWIDTH>>& _resp,
                   hls::stream<ap_uint<DTWIDTH>>& _data,
                   int rows,
                   int cols,
                   volatile ap_uint<24> &st_egr_snd_dt,
                   volatile ap_uint<24> &st_egr_snd_fr,
                   ap_uint<1> ins_proto_fault_req,
                   ap_uint<1> ins_proto_fault_data,
                   volatile uint32_t &snd_req,
                   volatile uint32_t &rcv_resp,
                   volatile uint32_t &snd_data) {

    hls::stream<ap_uint<32>, 512> temp;

    #pragma HLS DATAFLOW
    //Mat2req<CTLWIDTH, DTWIDTH, TYPE, DST_ROWS, DST_COLS, NPC>(ch_id, frame_length, length, sof, eof, pix_packet, _data_in, temp, _req, ins_proto_fault_req, snd_req);
    Mat2req<CTLWIDTH, DTWIDTH, TYPE, DST_ROWS, DST_COLS, NPC>(ch_id, frame_length, sof, eof, pix_packet, _data_in, temp, _req, ins_proto_fault_req, snd_req);
    resp2data<CTLWIDTH, DTWIDTH>(_resp, temp, _data, st_egr_snd_dt, st_egr_snd_fr, ins_proto_fault_data, rcv_resp, snd_data);
}

/**
 * Image resizing function.
 */
template <int CTLWIDTH,
          int DTWIDTH,
          int PACKETSIZE,
          int TYPE,
          int DST_ROWS,
          int DST_COLS,
          int NPC>
void data_out(hls::stream<ap_uint<CTLWIDTH>>& _s_req,
              hls::stream<ap_uint<DTWIDTH>>& _data_in,
              hls::stream<ap_uint<CTLWIDTH>>& _m_req,
              hls::stream<ap_uint<CTLWIDTH>>& _s_resp,
              hls::stream<ap_uint<DTWIDTH>>& _data,
              int rows,
              int cols,
              volatile ap_uint<24> &st_egr_snd_dt,
              volatile ap_uint<24> &st_egr_snd_fr,
              ap_uint<1> ins_proto_fault_req,
              ap_uint<1> ins_proto_fault_data,
              volatile uint32_t &snd_req,
              volatile uint32_t &rcv_resp,
              volatile uint32_t &snd_data) {

	ap_uint<CTLWIDTH> req;

  int pix_frame = rows * cols;
  int pix_remain = pix_frame;
  int frame_length = 0;
  int ch_id = 0;
  int pix_packet = 0;
  int pix_sum = 0;
  int length = 0;
  int sof = 0;
  int eof = 0;

  int burst_length_re = 0;
	int burst_length_eof = 0;
	int req_num = 0;
	int quotient = cols/64;
	int frame_byte = pix_frame*4;
	if(cols == quotient*64) {  // divisible by 1 line
		burst_length_re = cols*4; // For 1 line (including padding)
		burst_length_eof = burst_length_re;
		req_num = rows;
	} else {                   // not divisible by 1 line
		burst_length_re = ((quotient+1)*192*4) / 3; // rounded up undivisible fraction (including padding)
		req_num = frame_byte / burst_length_re;    // Cut off the remainder.
		int remain_byte = frame_byte - burst_length_re * (frame_byte / burst_length_re);
		burst_length_eof = burst_length_re + remain_byte; // add extra length to last req
	}

	// framesize (frame size/packetsize)
	data_out:for (int i=0; i<pix_frame; i=i+pix_packet){
    #pragma HLS PIPELINE
    //sof
	  if (pix_remain == pix_frame){
	    sof = 1;
	    req = _s_req.read();
      frame_length = rows * cols * 3; // Convert to resized frame_length
	    ch_id        = (int)req(40, 32);
	  }else{
	    sof = 0;
    }

	  //eof
	  if (pix_remain <= (burst_length_eof>>2)){
    //if (pix_remain <= cols){
	    eof = 1;
	  }else{
	    eof = 0;
	  }

	  //length
	  if (pix_remain > (burst_length_eof>>2)){
    //if (pix_remain >= cols){
	    pix_packet = burst_length_re>>2;
      //pix_packet = cols;
		}else{
      pix_packet = pix_remain;
		}

		//length = pix_packet * 4;
		//data_out_proc<CTLWIDTH, DTWIDTH, TYPE, DST_ROWS, DST_COLS, NPC>(ch_id, frame_length, length, sof, eof, pix_packet, pix_sum, _data_in, _m_req, _s_resp, _data, rows, cols, st_egr_snd_dt, st_egr_snd_fr, ins_proto_fault_req, ins_proto_fault_data, snd_req, rcv_resp, snd_data);
    data_out_proc<CTLWIDTH, DTWIDTH, TYPE, DST_ROWS, DST_COLS, NPC>(ch_id, frame_length, sof, eof, pix_packet, pix_sum, _data_in, _m_req, _s_resp, _data, rows, cols, st_egr_snd_dt, st_egr_snd_fr, ins_proto_fault_req, ins_proto_fault_data, snd_req, rcv_resp, snd_data);
		pix_remain = pix_remain - pix_packet;
	  pix_sum = pix_sum + pix_packet;
	}
} //void



#endif
