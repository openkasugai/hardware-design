/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "usr_struct.h"
#include <ap_axi_sdata.h>
#include <iostream>
#include "imgproc/xf_resize.hpp"
#include "common/xf_common.hpp"
#include "filter_resize_config.h"

static void assign_stream_in(
				int rows_in,
				int cols_in,
                hls::stream<ap_uint<FCDT_WIDTH>> &in, 
                xf::cv::Mat<TYPE, IN_HEIGHT, IN_WIDTH, NPC_T, 2>& out)
{
    ap_uint<FCDT_WIDTH> data;
    uint32_t pix_cnt = 0;
    int end_flg = 0;
    
    
	do{
		#pragma HLS PIPELINE style=flp
		data = in.read();
		out.write(0, data);
		pix_cnt ++;
		
		if (pix_cnt == rows_in*cols_in){
			end_flg = 1;
		}else{
			end_flg = 0;
		}
			
    }while(!end_flg);
}

static void assign_stream_out(
				int rows_out,
				int cols_out,
                xf::cv::Mat<TYPE, OUT_HEIGHT, OUT_WIDTH, NPC_T, 2>& in,
                hls::stream<ap_uint<FCDT_WIDTH>> &out) 
{
    ap_uint<FCDT_WIDTH> data;
    uint32_t pix_cnt = 0;
    int end_flg = 0;

	do{
		#pragma HLS PIPELINE style=flp
		data = in.read(0);
		out.write(data);
		pix_cnt ++;
		
		if (pix_cnt == rows_out*cols_out){
			end_flg = 1;
		}else{
			end_flg = 0;
		}
			
    }while(!end_flg);
}


extern "C" {
void resize_proc_krnl(
				hls::stream<ap_uint<FCDT_WIDTH>>& _data_in,
				hls::stream<ap_uint<FCDT_WIDTH>>& _data_out,
				int rows_in,
				int cols_in,
				int rows_out,
				int cols_out
                  ) {
    #pragma HLS INTERFACE mode = axis port = _data_in
    #pragma HLS INTERFACE mode = axis port = _data_out
    #pragma HLS INTERFACE mode = ap_none port = rows_in
    #pragma HLS INTERFACE mode = ap_none port = cols_in
    #pragma HLS INTERFACE mode = ap_none port = rows_out
    #pragma HLS INTERFACE mode = ap_none port = cols_out
    #pragma HLS INTERFACE mode = ap_ctrl_hs port = return    

	//frame_in -> filter
    xf::cv::Mat<TYPE, IN_HEIGHT, IN_WIDTH, NPC_T, 2> in_mat_resize(rows_in, cols_in);
    #pragma HLS stream variable=in_mat_resize.data depth=2

	//filter -> frame_out
    xf::cv::Mat<TYPE, OUT_HEIGHT, OUT_WIDTH, NPC_T, 2> out_mat_resize(rows_out, cols_out);
    #pragma HLS stream variable=out_mat_resize.data depth=2

    #pragma HLS DATAFLOW
    assign_stream_in(rows_in, cols_in, _data_in, in_mat_resize);
    xf::cv::resize<INTERPOLATION, TYPE, IN_HEIGHT, IN_WIDTH, OUT_HEIGHT, OUT_WIDTH, NPC_T, MAX_DOWNSCALE>(in_mat_resize, out_mat_resize);
    assign_stream_out(rows_out, cols_out, out_mat_resize, _data_out);



}
}
