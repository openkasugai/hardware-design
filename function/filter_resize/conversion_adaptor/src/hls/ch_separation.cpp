/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "ch_separation.hpp"
#include "chain_control.hpp"
#include <iostream>

struct DmaReq {
	uint32_t index;
	uint32_t pix_num;
	uint32_t func_num;
	uint8_t  val_byte;
	ap_uint<CTL_WIDTH> req;
};


template <int CTLWIDTH,
          int IFNUM>
static void assign_stream(
                hls::stream<ap_uint<CTLWIDTH>>& in, 
                hls::stream<ap_uint<CTLWIDTH>, 256>& out)
{
	ap_uint<CTLWIDTH> req;
	do{
		#pragma HLS PIPELINE style=flp
		if(!in.empty()){
			in.read_nb(req);
			out.write(req);
		}
	}while(1);
}


template <int CTLWIDTH>
void req2resp(
					hls::stream<ap_uint<CTLWIDTH>>& s_axis_ingr_rx_req,
					hls::stream<ap_uint<CTLWIDTH>>& _local_axis_req,
					hls::stream<ap_uint<CTLWIDTH>>& m_axis_ingr_rx_resp,
					volatile uint16_t&              ingr_rcv_fail_insert,
					volatile uint32_t&              dbg_rcv_req_cnt,
					volatile uint32_t&              dbg_send_resp_cnt) {
    //#pragma HLS stable variable=reg_axis_req_ready
	ap_uint<CTLWIDTH> req;
	ap_uint<CTLWIDTH> resp;
	static uint32_t req_cnt = 0;
	static uint32_t resp_cnt = 0;
    
	while(1) {
	    // req received
		if(!s_axis_ingr_rx_req.empty()) {
			s_axis_ingr_rx_req.read_nb(req);
			ap_uint<CTLWIDTH> frame_length = req(31, 0);
	    	ap_uint<CTLWIDTH> ch_id        = req(40, 32);
	    	ap_uint<CTLWIDTH> sof          = req(41, 41);
	    	ap_uint<CTLWIDTH> eof          = req(42, 42);
        	ap_uint<CTLWIDTH> direct       = req(43, 43);
        	ap_uint<CTLWIDTH> burst_length = req(63, 48); // no padding
			req_cnt++;
			dbg_rcv_req_cnt = req_cnt;

			// length calculation
			ap_uint<CTLWIDTH> len_block = burst_length/192; // 192 bytes: 3 words: let 64 pixels = 1block.
			ap_uint<CTLWIDTH> burst_length_re = len_block*192;    // Correct to a multiple of 192 bytes for length (0 bytes for less than 192 bytes)

        	// Insert Pseudo Fault
			uint16_t rcv_fail_insert = ingr_rcv_fail_insert;
        	if( rcv_fail_insert != 0) {
        	    if( (rcv_fail_insert >> INGR_PROTOCOL_FAULT_CHANNEL_EQ_REQ) & 0x00000001 ) {
        	        ch_id = ~ch_id & 0x000001FF;
        	    } else if( (rcv_fail_insert >> INGR_PROTOCOL_FAULT_BURST_LENGTH_LE_REQ) & 0x00000001 ) {
        	        burst_length_re = MAX_BURST_LENGTH;
        	    } else if( (rcv_fail_insert >> INGR_PROTOCOL_FAULT_SOF_EQ_REQ) & 0x00000001 ) {
        	      sof = ~sof & 0x00000001;
        	    } else if( (rcv_fail_insert >> INGR_PROTOCOL_FAULT_EOF_EQ_REQ) & 0x00000001 ) {
        	        eof = ~eof & 0x00000001;
        	    } else if( (rcv_fail_insert >> INGR_PROTOCOL_FAULT_BURST_LENGTH_EQ_REQ) & 0x00000001 ) {
        	        burst_length_re = ~burst_length_re;
        	    }
        	}

			ap_uint<CTLWIDTH> req_re = (burst_length_re<<48) | (direct<<43) | (eof<<42) | (sof<<41) | (ch_id<<32) | frame_length;
	
			// resp response
        	m_axis_ingr_rx_resp.write(req_re);
	    	_local_axis_req.write(req_re);
        	resp_cnt++;
			dbg_send_resp_cnt = resp_cnt;
		}
	}
}


template <int CTLWIDTH,
          int DDRWIDTH>
void data2gm_dma(
		hls::stream<DmaReq>&                   _local_dma_wr_req,
		hls::stream<ap_uint<CTLWIDTH>, 512>&   _local_manage_req,
		ap_uint<DDRWIDTH>*                     ddr_data,
		hls::stream<ap_uint<MDDT_WIDTH>, 128>& s_axis_ingr_rx_data,
		volatile ap_uint<24>&                  stat_ingr_rcv_data,
		volatile ap_uint<24>&                  stat_ingr_rcv_frame,
		volatile ap_uint<16>&                  stat_ingr_frame_buffer_write,
		volatile uint32_t&                     dbg_rcv_data_cnt,
		volatile uint32_t&                     dbg_rcv_eof_cnt)
{
	static uint32_t data_cnt = 0;
	static uint32_t eof_cnt = 0;
	static ap_uint<16> wr_note = 0;
	static ap_uint<24> data_byte = 0;
	static ap_uint<24> frame_num = 0;
	static ap_uint<16> buf_wr = 0;
	int ch_id = 0;
	int sof = 0;
	int eof = 0;

	while(1) {
		// req received
		DmaReq req = _local_dma_wr_req.read();
		ch_id = req.req(40, 32);
		sof   = req.req(41, 41);
		eof   = req.req(42, 42);

		// Write notification at start of write
		if(sof) {
			wr_note = (0x00000001<<CHANNEL_WIDTH) | ch_id;
			stat_ingr_frame_buffer_write = wr_note;
		}
		
		// DDR Write
		data2gm_dma: for (uint i = 0; i < req.pix_num; i++) {
			#pragma HLS PIPELINE
			ddr_data[req.index + i] = s_axis_ingr_rx_data.read();
			data_byte = (0x00000040 << 16) | ch_id;
			stat_ingr_rcv_data = data_byte; // 64byte
		}
		data_cnt += req.pix_num;
		dbg_rcv_data_cnt = data_cnt;

		// Send write completion notification at eof
		if( eof ) {
			_local_manage_req.write(req.req);
			eof_cnt++;
			dbg_rcv_eof_cnt = eof_cnt;

			// Statistics
			frame_num = (0x00000001 << 16) | ch_id;
			stat_ingr_rcv_frame = frame_num;
		}
	}
}

template <int CTLWIDTH,
          int FCDTWIDTH,
          int IFNUM,
          int DDRWIDTH>
void data2gm(
		hls::stream<ap_uint<CTLWIDTH>>&  _local_axis_req,
		hls::stream<DmaReq>&             _local_dma_wr_req,
		volatile ap_uint<16>&            stat_ingr_mem_err_detect,
		volatile ap_uint<16>&            stat_ingr_length_err_detect,
		volatile int&                    rows_in,
		volatile int&                    cols_in,
		volatile uint8_t&                ingr_parity_fail_insert,
		volatile uint32_t&               dbg_ddr_write_cnt)
{

	ap_uint<FCDTWIDTH+1> s_ddr_wr_offset[CH_NUM] = {0}; //ddr write address offset per ch_id
	#pragma HLS array_partition variable=s_ddr_wr_offset type=complete

	ap_uint<3> s_side_select[CH_NUM] = {0}; // 8 sides
	#pragma HLS array_partition variable=s_side_select type=complete

	static uint16_t   st_mem_err = 0;
	static uint16_t   length_err = 0;
	static uint32_t   write_cnt = 0;

	// ram initial
	for( int i=0; i<CH_NUM; i++ ) {
		#pragma HLS PIPELINE
		s_ddr_wr_offset[i] = 0;
		s_side_select[i] = 0;
	}

	while(1) {
		if( !_local_dma_wr_req.full() ) {
			// req received
			ap_uint<CTLWIDTH> req    = _local_axis_req.read();
			ap_uint<CTLWIDTH> frame_length = req(31, 0);
	    	ap_uint<CTLWIDTH> ch_id        = req(40, 32);
	    	ap_uint<CTLWIDTH> sof          = req(41, 41);
	    	ap_uint<CTLWIDTH> eof          = req(42, 42);
        	ap_uint<CTLWIDTH> direct       = req(43, 43);
        	ap_uint<CTLWIDTH> burst_length = req(63, 48); // no padding

			// frame length error detect
			if(frame_length > 0x017BB000) {
				length_err = 0x00000001 << ch_id;
				stat_ingr_length_err_detect = length_err;
			}
        
			// DDR Side Acquisition
			ap_uint<CTLWIDTH> sel = (ap_uint<CTLWIDTH>)s_side_select[ch_id];
        
			// DDR address offset calculation
			int rows = rows_in;
			int cols = cols_in;
			uint32_t pix_frame = (uint32_t)(rows*cols);
			uint32_t offset = (((uint32_t)ch_id + (uint32_t)sel*CH_NUM)*pix_frame) >> 2; //byte
			uint32_t pix_num = ((uint32_t)burst_length+63) >> 6; // 512 bit units
			
			// Parity check.
			ap_uint<FCDTWIDTH + 1> addr_out = s_ddr_wr_offset[ch_id];
			ap_uint<FCDTWIDTH> addr_tmp = addr_out(31, 0);
			ap_uint<1> parity_bit = addr_out(32, 32);
			
			// Insert Pseudo Fault
			uint8_t parity_fail_insert = ingr_parity_fail_insert;
			if((parity_fail_insert >> ch_id) & 0x01) {
				parity_bit = ~parity_bit;
			}
			if (parity_bit != addr_tmp.xor_reduce()) { // Parity check.
                // Parity error processing (set the bit of the corresponding channel to 1)
				st_mem_err = 0x00000001 << ch_id;
                stat_ingr_mem_err_detect = st_mem_err;
            } else {
				stat_ingr_mem_err_detect = 0;
            }
			ap_uint<CTLWIDTH> tmp = (ap_uint<CTLWIDTH>)addr_tmp; // Output without parity bit
        
			// DDR write req send
			DmaReq dmareq;
			dmareq.func_num = 0;
			dmareq.index = offset + (uint32_t)tmp;
			dmareq.pix_num = pix_num;
			dmareq.val_byte = 0;
			ap_uint<CTLWIDTH> l_req = (burst_length<<48) | (sel<<44) | (direct<<43) | (eof<<42) | (sof<<41) | (ch_id<<32) | frame_length;
			dmareq.req = l_req;
			_local_dma_wr_req.write(dmareq);
        
			tmp += (ap_uint<CTLWIDTH>)pix_num;//length;
    
			write_cnt++;
			dbg_ddr_write_cnt = write_cnt;

			if( eof ) {
				s_ddr_wr_offset[ch_id] = 0;
				if (sel == 7) {
					sel = 0;
				}else{
					sel = sel + 1;
				}
				s_side_select[ch_id] = sel;
			} else {
				// parity bit insert
				ap_uint<FCDTWIDTH + 1> addr_in = ((ap_uint<FCDTWIDTH+1>)tmp.xor_reduce()<<FCDTWIDTH) | (ap_uint<FCDTWIDTH+1>)tmp; // Parity bit calculation
				s_ddr_wr_offset[ch_id] = addr_in;
			}
		}
	}
}


template <int CTLWIDTH,
          int IFNUM>
void manage4localreq(
		hls::stream<ap_uint<CTLWIDTH>, 512>& _local_manage_req,
		hls::stream<ap_uint<CTLWIDTH>, 512>& _local_ddr_rd_req,
		volatile int&                        rows_in,
		volatile int&                        cols_in,
		volatile uint32_t&                   dbg_local_ddr_rd_req_cnt)
{
	static uint s_ddr_rd_cnt[8][CH_NUM]; // 8 sides
	#pragma HLS array_partition variable=s_ddr_rd_cnt type=complete

	static ap_uint<3> s_side_select[CH_NUM]; // 8 sides
	#pragma HLS array_partition variable=s_side_select type=complete
	
	int stop = 0;
	static int ch_cnt = 0;
	static int ch_st  = 0;
	static int last_done_ch = 0;
	static uint32_t rd_req_cnt = 0;

	// initial
	for( int i=0; i<8; i++ ) { // 8 sides
		#pragma HLS unroll
		for( int j=0; j<CH_NUM; j++ ) {
			#pragma HLS PIPELINE
			s_ddr_rd_cnt[i][j] = 0;
			s_side_select[j] = 0;
		}
	}

	do {
		// Skip new req reception if function kernel busy full
		if( ch_cnt < IFNUM ) {
			// Determine processing when receiving local req
			if( !_local_manage_req.empty() ) {
				// local req received
				ap_uint<CTLWIDTH> req;
				_local_manage_req.read_nb(req);
	    		ap_uint<CTLWIDTH> ch_id_rcv    = req(40, 32);
				ap_uint<CTLWIDTH> side_rcv      = req(47, 44);
				                
				// Increment rd management counter
				s_ddr_rd_cnt[side_rcv][ch_id_rcv] += 1 ;
				
				// Increment IFNUM management counter
				ch_cnt++;
			}
		}

		ap_uint<CTLWIDTH> burst_length_new = 0;
		int rows = rows_in;
		int cols = cols_in;
		manage4localreq:for ( int chid=ch_st; chid<ch_st+CH_NUM; chid++ ){
			#pragma HLS PIPELINE
			// ch_id set
			int ch = 0;
			if( chid < CH_NUM ) {
				ch = chid;
			} else {
				ch = chid - CH_NUM;
			}
			// req transmitted when FIFO is not full.
			if( !_local_ddr_rd_req.full() ) {
				int sel = s_side_select[ch];
				last_done_ch = ch;
				if(s_ddr_rd_cnt[sel][ch] != 0) {
					// Calculates the transfer size per req and the total number of reqs according to the frame size.
					ap_uint<CTLWIDTH> sof = 0;
	    			ap_uint<CTLWIDTH> eof = 0;
					int sel_next = 0;
					int burst_length_re = 0;
					int burst_length_eof = 0;
					int req_num = 0;
					int quotient = cols/64;
					int frame_byte = rows*cols*3;
					if(cols == quotient*64) {  // divisible by 1 line
						burst_length_re = cols*3;
						burst_length_eof = burst_length_re;
						req_num = rows;
					} else {                   // not divisible by 1 line
						burst_length_re = (quotient+1)*192; // rounded up undivisible part
						req_num = frame_byte / burst_length_re;    // Cut off the remainder.
						int remain_byte = frame_byte - burst_length_re * (frame_byte / burst_length_re);
						burst_length_eof = burst_length_re + remain_byte; // add extra length to last req
					}
					if(s_ddr_rd_cnt[sel][ch] == 1) {
						if(req_num == 1) {
							sof = 1;
							eof = 1;
							burst_length_new = (ap_uint<CTLWIDTH>)burst_length_eof;
							s_ddr_rd_cnt[sel][ch] = 0;
							if (sel == 7) {
								sel_next = 0;
							}else{
								sel_next = sel + 1;
							}
							s_side_select[ch] = sel_next;
							ch_cnt--;
						} else {
							sof = 1;
							eof = 0;
							burst_length_new = (ap_uint<CTLWIDTH>)burst_length_re;
						}
						s_ddr_rd_cnt[sel][ch]++;
					} else if(s_ddr_rd_cnt[sel][ch] == req_num) {
						sof = 0;
						eof = 1;
						burst_length_new = (ap_uint<CTLWIDTH>)burst_length_eof; // specifies the length of the last req
						s_ddr_rd_cnt[sel][ch] = 0;
						if (sel == 7) {
							sel_next = 0;
						}else{
							sel_next = sel + 1;
						}
						s_side_select[ch] = sel_next;
						ch_cnt--;
					} else {  // s_ddr_rd_cnt[i] < req_num
						sof = 0;
						eof = 0;
						burst_length_new = (ap_uint<CTLWIDTH>)burst_length_re;
						s_ddr_rd_cnt[sel][ch]++;
					}
					// length_out for one line without padding
					ap_uint<CTLWIDTH> req_out = burst_length_new<<48 | ((ap_uint<CTLWIDTH>)sel<<44) | (eof<<42) | (sof<<41) | ((ap_uint<CTLWIDTH>)ch<<32) | (ap_uint<CTLWIDTH>)frame_byte;
					_local_ddr_rd_req.write(req_out);
					rd_req_cnt++;
					dbg_local_ddr_rd_req_cnt = rd_req_cnt;
				}
			} else {
				break;
			}
		}

		// next loop start ch_id set
		if( last_done_ch == CH_NUM - 1 ) {
			ch_st = 0;
		} else {
			ch_st = last_done_ch + 1;
		}		
	}while(!stop);
}

template <int CTLWIDTH,
          int IFNUM,
          int DDRWIDTH>
void gm2req_dma(
		hls::stream<ap_uint<CTLWIDTH>, 256>      _s_axis_resp[IFNUM],
		hls::stream<DmaReq, 256>                _local_dma_rd_req[IFNUM],
		ap_uint<DDRWIDTH>*                      ddr_data,
		hls::stream<ap_uint<CTLWIDTH>, 32>      _m_local_resp[IFNUM],
		hls::stream<ap_uint<MDDT_WIDTH>, 3840>  _local_temp[IFNUM],
		volatile ap_uint<16>&                   stat_ingr_frame_buffer_read)

{
	ap_uint<CTLWIDTH> _resp;
	ap_uint<CTLWIDTH> _resp_fw;
	ap_uint<CTLWIDTH> _resp_tmp;
	static uint32_t   num = 0;
	static uint16_t   buf_rd = 0;
	int ch_id = 0;
	int eof = 0;
	
	while(1) {
		buf_rd = 0;
		ap_uint<MDDT_WIDTH> data;

		if ( !_s_axis_resp[num].empty() && !_local_dma_rd_req[num].empty() ) {
			// Start processing after receiving resp and ddr read req from function
			_s_axis_resp[num].read_nb(_resp);
			ch_id        = _resp(40, 32);
			eof          = _resp(42, 42);
			_resp_tmp    = _resp(63, 32);
			
			// _local_dma_rd_req receive
			DmaReq req;
			_local_dma_rd_req[num].read_nb(req);

		    // DDR Read
			gm2req_dma_inner: for (uint i = 0; i < req.pix_num; i++) {
				#pragma HLS PIPELINE //II=1 rewind
				data = ddr_data[req.index + i];
				_local_temp[num].write(data);
			}
			// _m_local_resp sent with 512bit valid bytes
			_resp_fw = _resp_tmp<<32 | (ap_uint<CTLWIDTH>)req.val_byte;
			_m_local_resp[num].write(_resp_fw);
			
			// Read notification when completion of reading
			if( eof ) {
				stat_ingr_frame_buffer_read = ch_id;
			}
		}
		if(num >= IFNUM-1) {
			num = 0;
		} else {
			num++;
		}
	}
}

template <int CTLWIDTH,
          int FCDTWIDTH,
          int IFNUM,
          int DDRWIDTH>
void gm2req(
		hls::stream<ap_uint<CTLWIDTH>, 512>&   _local_ddr_rd_req,
		hls::stream<DmaReq, 256>               _local_dma_rd_req[IFNUM],
		hls::stream<ap_uint<CTLWIDTH>>         _m_axis_req[IFNUM],
		volatile int&                          rows_in,
		volatile int&                          cols_in,
		volatile uint16_t&                     ingr_snd_fail_insert,
		volatile uint32_t&                     dbg_ddr_read_cnt,
		volatile uint32_t&                     dbg_send_req_cnt)
{

	uint s_ddr_rd_offset[CH_NUM] = {0}; //ddr read address offset per ch_id
	#pragma HLS array_partition variable=s_ddr_rd_offset type=complete
	
	uint s_func_busy[IFNUM];
	#pragma HLS array_partition variable=s_func_busy type=complete

	static uint32_t read_cnt = 0;
	static uint32_t snd_req_cnt = 0;

	static int function_num = 0;
	int stop = 0;

	static int num_st  = 0;
	static int pre_func_num = 255;
	static int pre_ch_id = 255;

	// initial
	for( int i=0; i<IFNUM; i++ ) {
		#pragma HLS PIPELINE
		s_func_busy[i] = 255;
	}

	stop = 0;
	do {
		#pragma HLS PIPELINE style=flp
		// req receive
		ap_uint<CTLWIDTH> rcv_req = 0 ;
		if( !_local_ddr_rd_req.empty() ) {
		_local_ddr_rd_req.read_nb(rcv_req);
		ap_uint<CTLWIDTH> frame_length = rcv_req(31, 0);
	    ap_uint<CTLWIDTH> ch_id        = rcv_req(40, 32);
	    ap_uint<CTLWIDTH> sof          = rcv_req(41, 41);
	    ap_uint<CTLWIDTH> eof          = rcv_req(42, 42);
        ap_uint<CTLWIDTH> direct       = rcv_req(43, 43);
		ap_uint<CTLWIDTH> sel          = rcv_req(47, 44);
        ap_uint<CTLWIDTH> burst_length = rcv_req(63, 48); // no padding (for 1 line)

		// comparison with last processed ch_id
		if( sof==1 && ch_id==pre_ch_id ) {
			function_num = pre_func_num;
			s_func_busy[function_num] = ch_id;
		} else {
			int num   = 0;
			int exit_flg = 0;
			// Select free function
			gm2req_1_1:for( int if_num=num_st; if_num<num_st+IFNUM; if_num++ ) {
				#pragma HLS PIPELINE
				if( if_num < IFNUM ) {
					num = if_num;
				} else {
					num = if_num - IFNUM;
				}
				if( sof ) {
					pre_ch_id = 255;
					pre_func_num = 255;
					if( s_func_busy[num] == 255 ) {
						int num_n = ~num & 0x1;
						do {
							if(!_m_axis_req[num].full()) {
								function_num = num;
								s_func_busy[function_num] = ch_id;
								exit_flg = 1;
							} else if( (s_func_busy[num_n] == 255) && (!_m_axis_req[num_n].full()) ) {
								function_num = num_n;
								s_func_busy[function_num] = ch_id;
								exit_flg = 1;
							}
						} while(!exit_flg);
						break;
					}
				} else {
					if( s_func_busy[num] == ch_id ) {
						function_num = num;
					}
				}
			}
		}
    
		// req send
		ap_uint<CTLWIDTH> new_length = (burst_length<<2) / 3;
		ap_uint<CTLWIDTH> snd_req = 0;
		ap_uint<9> shift = 0;
		uint16_t snd_fail_insert = ingr_snd_fail_insert;
		if(function_num == 0) {
			if((snd_fail_insert >> INGR_PROTOCOL_FAULT_MAX_BURST_LENGTH_0) & 0x1) {
				new_length = MAX_BURST_LENGTH + 1;
			}
			if((snd_fail_insert >> INGR_PROTOCOL_FAULT_BURST_LENGTH_NZ_0) & 0x1) {
				new_length = (ap_uint<CTLWIDTH>)0;
			}
		} else {
			if((snd_fail_insert >> INGR_PROTOCOL_FAULT_MAX_BURST_LENGTH_1) & 0x1) {
				new_length = MAX_BURST_LENGTH + 1;
			}
			if((snd_fail_insert >> INGR_PROTOCOL_FAULT_BURST_LENGTH_NZ_1) & 0x1) {
				new_length = (ap_uint<CTLWIDTH>)0;
			}
		}
		snd_req(63, 48) = new_length; // length with padding
		snd_req(47, 44) = sel;
		snd_req(43, 43) = direct;
		snd_req(42, 42) = eof;
		snd_req(41, 41) = sof;
		snd_req(40, 32) = ch_id;
		snd_req(31, 0) = frame_length;
		_m_axis_req[function_num].write(snd_req);
		snd_req_cnt++;
		dbg_send_req_cnt = snd_req_cnt;
		
		// ddr read offset calc
		int rows = rows_in;
		int cols = cols_in;
		uint32_t other_side_offset = (uint32_t)sel*CH_NUM*rows*cols; //pix
		uint32_t offset = (ch_id*rows*cols + other_side_offset + 3) >> 2; //byte
		uint32_t pix_num = 0;
		uint32_t val_byte = 0;
		if( burst_length < 64 ) {
			pix_num = 1;
			val_byte = (uint8_t)burst_length;
		} else {
			pix_num = (burst_length+63) >> 6; // 512 bit units
			if(burst_length%64 == 0) {
				val_byte = 64;
			} else {
				val_byte = burst_length % 64; // Effective bytes of final data
			}
		}
		
		uint32_t tmp = s_ddr_rd_offset[ch_id];
		
		// ddr read req send
		DmaReq dmareq;
		dmareq.index = tmp + offset;
		dmareq.pix_num = pix_num;
		dmareq.func_num = function_num;
		dmareq.val_byte = val_byte;
		_local_dma_rd_req[function_num].write(dmareq);
		
		tmp += pix_num;//length;
		read_cnt++;
		dbg_ddr_read_cnt = read_cnt;
		
		if( eof == 1 ) {
			// next loop start ifnum set
			if( function_num == IFNUM - 1 ) {
				num_st = 0;
			} else {
				num_st = function_num + 1;
			}
			// pre chid, func_num keep
			pre_func_num = function_num;
			pre_ch_id  = ch_id;
			s_func_busy[function_num] = 255;
			s_ddr_rd_offset[ch_id] = 0;
		} else {
			s_ddr_rd_offset[ch_id] = tmp;
		}
		}
	}while(!stop);
}


template <int CTLWIDTH,
          int FCDTWIDTH,
          int IFNUM>
void local2data_0(
		hls::stream<ap_uint<CTLWIDTH>, 32>&     _s_local_resp,
		hls::stream<ap_uint<MDDT_WIDTH>, 3840>& _local_temp,
		hls::stream<ap_uint<FCDTWIDTH>>&        _m_axis_data,
		volatile ap_uint<24>&                   stat_ingr_snd_data_0,
		volatile ap_uint<24>&                   stat_ingr_snd_frame_0,
		volatile uint32_t&                      dbg_rcv_resp_cnt_0,
		volatile uint32_t&                      dbg_send_data_cnt)
{
	static uint32_t resp_cnt = 0;
	static uint32_t data_cnt = 0;
	static ap_uint<24> snd_data_0 = 0;
	static ap_uint<24> frame_num_0 = 0;

	while(1) {
		if(!_s_local_resp.empty()) { 
			// local_resp received from gm2req_dma
			ap_uint<CTLWIDTH>  _resp;
			_s_local_resp.read_nb(_resp);
			int val_byte     = _resp(31, 0);
		    int ch_id        = _resp(40, 32);
			int eof          = _resp(42, 42);
    	    int burst_length_4b = _resp(63, 48); // burst_length with padding
			int burst_length_3b = (burst_length_4b * 3) >> 2; // burst_length without padding

			// Debug counters
			resp_cnt++;
			dbg_rcv_resp_cnt_0 = resp_cnt;

			int in_words = (burst_length_3b + 63) >> 6; // Number of input cycles
			int out_words = burst_length_4b >> 2; // number of output cycles = number of pixels
			ap_uint<8*66> sreg = 0; // Shift register for parallel conversion
			int sreg_size = 0; // Shift register remaining
			
local2data0_loop:
			for (int i = 0; i < out_words; i++) {
				#pragma HLS PIPELINE II=1
				if (sreg_size < 3 && in_words > 0) {
					// refill from input stream when shift register is less than 1 pixel
					sreg(sreg_size * 8 + 511, sreg_size * 8) = _local_temp.read();
					sreg_size += 64;
					in_words--;
				}

				// push it out from the lower side
				ap_uint<FCDTWIDTH> out_data = 0;
				out_data(23, 0) = sreg(23, 0);
				_m_axis_data.write(out_data);
				sreg(8*63-1, 0) = sreg(8*66-1, 24);
				sreg_size -= 3;
				
				// Statistics
				snd_data_0 = (0x00000003<<16) | (ap_uint<24>)ch_id;
				stat_ingr_snd_data_0 = snd_data_0;
				
				// Debug counters
				data_cnt++;
				dbg_send_data_cnt = data_cnt;
			}

			// Statistics
			if(eof) {
				frame_num_0 = (0x00000001 << 16) | (ap_uint<24>)ch_id;
				stat_ingr_snd_frame_0 = frame_num_0;
			}
		}  // !local_resp.empty
	}
}

template <int CTLWIDTH,
          int FCDTWIDTH,
          int IFNUM>
void local2data_1(
		hls::stream<ap_uint<CTLWIDTH>, 32>&     _s_local_resp,
		hls::stream<ap_uint<MDDT_WIDTH>, 3840>& _local_temp,
		hls::stream<ap_uint<FCDTWIDTH>>&        _m_axis_data,
		volatile ap_uint<24>&                   stat_ingr_snd_data_1,
		volatile ap_uint<24>&                   stat_ingr_snd_frame_1,
		volatile uint32_t&                      dbg_rcv_resp_cnt_1,
		volatile uint32_t&                      dbg_send_data_cnt)
{
	static uint32_t resp_cnt = 0;
	static uint32_t data_cnt = 0;
	static ap_uint<24> snd_data_1 = 0;
	static ap_uint<24> frame_num_1 = 0;

	while(1) {
		if(!_s_local_resp.empty()) { 
			// local_resp received from gm2req_dma
			ap_uint<CTLWIDTH>  _resp;
			_s_local_resp.read_nb(_resp);
			int val_byte     = _resp(31, 0);
		    int ch_id        = _resp(40, 32);
			int eof          = _resp(42, 42);
    	    int burst_length_4b = _resp(63, 48); // burst_length with padding
			int burst_length_3b = (burst_length_4b * 3) >> 2; // burst_length without padding

			// Debug counters
			resp_cnt++;
			dbg_rcv_resp_cnt_1 = resp_cnt;

			int in_words = (burst_length_3b + 63) >> 6; // Number of input cycles
			int out_words = burst_length_4b >> 2; // number of output cycles = number of pixels
			ap_uint<8*66> sreg = 0; // Shift register for parallel conversion
			int sreg_size = 0; // Shift register remaining
			
local2data1_loop:
			for (int i = 0; i < out_words; i++) {
				#pragma HLS PIPELINE II=1
				if (sreg_size < 3 && in_words > 0) {
					// refill from input stream when shift register is less than 1 pixel
					sreg(sreg_size * 8 + 511, sreg_size * 8) = _local_temp.read();
					sreg_size += 64;
					in_words--;
				}

				// push it out from the lower side
				ap_uint<FCDTWIDTH> out_data = 0;
				out_data(23, 0) = sreg(23, 0);
				_m_axis_data.write(out_data);
				sreg(8*63-1, 0) = sreg(8*66-1, 24);
				sreg_size -= 3;
				
				// Statistics
				snd_data_1 = (0x00000003<<16) | (ap_uint<24>)ch_id;
				stat_ingr_snd_data_1 = snd_data_1;
				
				// Debug counters
				data_cnt++;
				dbg_send_data_cnt = data_cnt;
			}

			// Statistics
			if(eof) {
				frame_num_1 = (0x00000001 << 16) | (ap_uint<24>)ch_id;
				stat_ingr_snd_frame_1 = frame_num_1;
			}
		}  // !local_resp.empty
	}
}



template <int CTLWIDTH,
          int FCDTWIDTH,
          int IFNUM,
          int DDRWIDTH>
void ch_separation_proc(
		hls::stream<ap_uint<CTL_WIDTH>>&       s_axis_ingr_rx_req,
		hls::stream<ap_uint<CTL_WIDTH>>&       m_axis_ingr_rx_resp,
        hls::stream<ap_uint<MDDT_WIDTH>, 128>& s_axis_ingr_rx_data,
        ap_uint<OUTPUT_PTR_WIDTH>*             m_axi_ingr_frame_buffer,
        hls::stream<ap_uint<CTL_WIDTH>>        m_axis_ingr_tx_req[IFNUM],
        hls::stream<ap_uint<CTL_WIDTH>>&       s_axis_ingr_tx_resp_0,
        hls::stream<ap_uint<FCDT_WIDTH>>&      m_axis_ingr_tx_data_0,
        hls::stream<ap_uint<CTL_WIDTH>>&       s_axis_ingr_tx_resp_1,
        hls::stream<ap_uint<FCDT_WIDTH>>&      m_axis_ingr_tx_data_1,
        volatile int&                          rows,
        volatile int&                          cols,
        volatile ap_uint<24>&                  stat_ingr_rcv_data,
        volatile ap_uint<24>&                  stat_ingr_snd_data_0,
        volatile ap_uint<24>&                  stat_ingr_snd_data_1,
        volatile ap_uint<24>&                  stat_ingr_rcv_frame,
        volatile ap_uint<24>&                  stat_ingr_snd_frame_0,
        volatile ap_uint<24>&                  stat_ingr_snd_frame_1,
        volatile ap_uint<16>&                  stat_ingr_mem_err_detect,
        volatile ap_uint<16>&                  stat_ingr_length_err_detect,
        volatile ap_uint<16>&                  stat_ingr_frame_buffer_write,
        volatile ap_uint<16>&                  stat_ingr_frame_buffer_read,
        volatile uint16_t&                     ingr_fail_insert,
		volatile uint8_t&                      parity_fail_insert,
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
		volatile uint32_t&                     snd_dt_1)
{
#pragma HLS stable variable = rows
#pragma HLS stable variable = cols
#pragma HLS stable variable = ingr_fail_insert
#pragma HLS stable variable = parity_fail_insert

	hls::stream<ap_uint<CTLWIDTH>>         _local_axis_req;
	hls::stream<ap_uint<CTLWIDTH>, 512>    _local_manage_req;
	hls::stream<ap_uint<CTLWIDTH>, 512>    _local_ddr_rd_req;
	hls::stream<DmaReq>                    _local_dma_wr_req;
	hls::stream<DmaReq, 256>               _local_dma_rd_req[IFNUM];
	hls::stream<ap_uint<CTLWIDTH>, 32>     _local_resp[IFNUM];
	hls::stream<ap_uint<CTLWIDTH>, 256>     _s_axis_resp[IFNUM];
	hls::stream<ap_uint<CTLWIDTH>, 32>     _s_local_resp[IFNUM];
	hls::stream<ap_uint<MDDT_WIDTH>, 3840> _local_temp[IFNUM];

	#pragma HLS DATAFLOW
	req2resp<CTLWIDTH>(s_axis_ingr_rx_req, _local_axis_req, m_axis_ingr_rx_resp, ingr_fail_insert, rcv_req, snd_resp);
	data2gm<CTLWIDTH, FCDTWIDTH, IFNUM, DDRWIDTH>(_local_axis_req, _local_dma_wr_req, stat_ingr_mem_err_detect, stat_ingr_length_err_detect, rows, cols, parity_fail_insert, wr_ddr);
	data2gm_dma<CTLWIDTH, DDRWIDTH>(_local_dma_wr_req, _local_manage_req, m_axi_ingr_frame_buffer, s_axis_ingr_rx_data, stat_ingr_rcv_data, stat_ingr_rcv_frame, stat_ingr_frame_buffer_write, rcv_dt, rcv_eof);
	manage4localreq<CTLWIDTH, IFNUM>(_local_manage_req, _local_ddr_rd_req, rows, cols, snd_lreq);
	gm2req<CTLWIDTH, FCDTWIDTH, IFNUM, DDRWIDTH>(_local_ddr_rd_req, _local_dma_rd_req, m_axis_ingr_tx_req, rows, cols, ingr_fail_insert, rd_ddr, snd_req);
	assign_stream<CTLWIDTH, IFNUM>(s_axis_ingr_tx_resp_0, _s_axis_resp[0]);
	assign_stream<CTLWIDTH, IFNUM>(s_axis_ingr_tx_resp_1, _s_axis_resp[1]);
	gm2req_dma<CTLWIDTH, IFNUM, DDRWIDTH>(_s_axis_resp, _local_dma_rd_req, m_axi_ingr_frame_buffer, _local_resp, _local_temp, stat_ingr_frame_buffer_read);
	local2data_0<CTLWIDTH, FCDTWIDTH, IFNUM>(_local_resp[0], _local_temp[0], m_axis_ingr_tx_data_0, stat_ingr_snd_data_0, stat_ingr_snd_frame_0, rcv_resp_0, snd_dt_0);
	local2data_1<CTLWIDTH, FCDTWIDTH, IFNUM>(_local_resp[1], _local_temp[1], m_axis_ingr_tx_data_1, stat_ingr_snd_data_1, stat_ingr_snd_frame_1, rcv_resp_1, snd_dt_1);

} //void


void ch_separation(
		hls::stream<ap_uint<CTL_WIDTH>>&       s_axis_ingr_rx_req,
		hls::stream<ap_uint<CTL_WIDTH>>&       m_axis_ingr_rx_resp,
        hls::stream<ap_uint<MDDT_WIDTH>, 128>& s_axis_ingr_rx_data,
        ap_uint<OUTPUT_PTR_WIDTH>*             m_axi_ingr_frame_buffer,
        hls::stream<ap_uint<CTL_WIDTH>>        m_axis_ingr_tx_req[IF_NUM],
        hls::stream<ap_uint<CTL_WIDTH>>&       s_axis_ingr_tx_resp_0,
        hls::stream<ap_uint<FCDT_WIDTH>>&      m_axis_ingr_tx_data_0,
        hls::stream<ap_uint<CTL_WIDTH>>&       s_axis_ingr_tx_resp_1,
        hls::stream<ap_uint<FCDT_WIDTH>>&      m_axis_ingr_tx_data_1,
        volatile int&                          Rows,
        volatile int&                          Cols,
        volatile ap_uint<24>&                  stat_ingr_rcv_data,
        volatile ap_uint<24>&                  stat_ingr_snd_data_0,
        volatile ap_uint<24>&                  stat_ingr_snd_data_1,
		volatile ap_uint<24>&                  stat_ingr_rcv_frame,
		volatile ap_uint<24>&                  stat_ingr_snd_frame_0,
		volatile ap_uint<24>&                  stat_ingr_snd_frame_1,
        volatile ap_uint<16>&                  stat_ingr_mem_err_detect,
        volatile ap_uint<16>&                  stat_ingr_length_err_detect,
        volatile ap_uint<16>&                  stat_ingr_frame_buffer_write,
        volatile ap_uint<16>&                  stat_ingr_frame_buffer_read,
        volatile uint16_t&                     ingr_fail_insert,
		volatile uint8_t&                      parity_fail_insert,
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
		volatile uint32_t&                     snd_dt_1)
{

#pragma HLS INTERFACE mode = axis port = s_axis_ingr_rx_req
#pragma HLS INTERFACE mode = axis port = m_axis_ingr_rx_resp
#pragma HLS INTERFACE mode = axis port = s_axis_ingr_rx_data
#pragma HLS INTERFACE mode = m_axi port = m_axi_ingr_frame_buffer offset = direct bundle = gmem3
#pragma HLS INTERFACE mode = axis port = m_axis_ingr_tx_req
#pragma HLS INTERFACE mode = axis port = s_axis_ingr_tx_resp_0
#pragma HLS INTERFACE mode = axis port = m_axis_ingr_tx_data_0
#pragma HLS INTERFACE mode = axis port = s_axis_ingr_tx_resp_1
#pragma HLS INTERFACE mode = axis port = m_axis_ingr_tx_data_1
#pragma HLS INTERFACE mode = ap_none port = Rows
#pragma HLS INTERFACE mode = ap_none port = Cols
#pragma HLS INTERFACE mode = ap_none port = ingr_fail_insert
#pragma HLS INTERFACE mode = ap_none port = parity_fail_insert
#pragma HLS INTERFACE mode = ap_none port = rcv_req
#pragma HLS INTERFACE mode = ap_none port = snd_resp
#pragma HLS INTERFACE mode = ap_none port = rcv_dt
#pragma HLS INTERFACE mode = ap_none port = wr_ddr
#pragma HLS INTERFACE mode = ap_none port = rcv_eof
#pragma HLS INTERFACE mode = ap_none port = snd_lreq
#pragma HLS INTERFACE mode = ap_none port = rd_ddr
#pragma HLS INTERFACE mode = ap_none port = snd_req
#pragma HLS INTERFACE mode = ap_none port = rcv_resp_0
#pragma HLS INTERFACE mode = ap_none port = snd_dt_0
#pragma HLS INTERFACE mode = ap_none port = rcv_resp_1
#pragma HLS INTERFACE mode = ap_none port = snd_dt_1
#pragma HLS INTERFACE mode = ap_ctrl_chain port = return

	ch_separation_proc<CTL_WIDTH, FCDT_WIDTH, IF_NUM, OUTPUT_PTR_WIDTH>(
		    s_axis_ingr_rx_req,
            m_axis_ingr_rx_resp,
            s_axis_ingr_rx_data,
            m_axi_ingr_frame_buffer,
            m_axis_ingr_tx_req,
            s_axis_ingr_tx_resp_0,
            m_axis_ingr_tx_data_0,
            s_axis_ingr_tx_resp_1,
            m_axis_ingr_tx_data_1,
            Rows,
            Cols,
            stat_ingr_rcv_data,
            stat_ingr_snd_data_0,
            stat_ingr_snd_data_1,
			stat_ingr_rcv_frame,
			stat_ingr_snd_frame_0,
			stat_ingr_snd_frame_1,
            stat_ingr_mem_err_detect,
            stat_ingr_length_err_detect,
            stat_ingr_frame_buffer_write,
            stat_ingr_frame_buffer_read,
            ingr_fail_insert,
			parity_fail_insert,
            rcv_req,
            snd_resp,
            rcv_dt,
            wr_ddr,
            rcv_eof,
            snd_lreq,
            rd_ddr,
            snd_req,
            rcv_resp_0,
            snd_dt_0,
            rcv_resp_1,
            snd_dt_1
			);
} //void
