/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"

enum hdrInsState
{
    HDR_INS_ST_REQ_WAIT = 0,
    HDR_INS_ST_HDR_WAIT = 1
};

void egr_hdr_ins(hls::stream<headerInsReq> &egr_hdr_ins_req,
                 hls::stream<sessionPtr> &egr_hdr_ins_ptr,
                 hls::stream<sessionPtr> &header_req,
                 hls::stream<header_data_t> &header_data,
                 hls::stream<buffer_data_t> &s_axis_egr_rx_data,
                 hls::stream<sessionPtr> &egr_send_ptr,
                 hls::stream<length_t> &egr_send_length,
                 hls::stream<buffer_data_t> &egr_session_data,
                 hls::stream<headerSeq> &egr_header_ins_done,
                 channelCycleDataCount &stat_egr_discard,
                 ap_uint<32> insert_fault)
{
#pragma HLS INTERFACE mode = axis port = egr_hdr_ins_req
#pragma HLS INTERFACE mode = axis port = egr_hdr_ins_ptr
#pragma HLS INTERFACE mode = axis port = header_req
#pragma HLS INTERFACE mode = axis port = header_data
#pragma HLS INTERFACE mode = axis port = s_axis_egr_rx_data
#pragma HLS INTERFACE mode = axis port = egr_send_ptr
#pragma HLS INTERFACE mode = axis port = egr_send_length
#pragma HLS INTERFACE mode = axis port = egr_session_data
#pragma HLS INTERFACE mode = axis port = egr_header_ins_done
#pragma HLS INTERFACE mode = ap_ovld port = stat_egr_discard
#pragma HLS INTERFACE mode = ap_none port = insert_fault
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

#pragma HLS PIPELINE

    static hdrInsState state = HDR_INS_ST_REQ_WAIT;
    static headerInsReq ins_req;
    static sessionPtr session;

    if (state == HDR_INS_ST_REQ_WAIT &&
        !egr_hdr_ins_req.empty() &&
        !egr_hdr_ins_ptr.empty())
    {
        ins_req = egr_hdr_ins_req.read();
        session = egr_hdr_ins_ptr.read();

        if (session.sof)
            // Get header data from ingr_hdr_rmv (even when discarding)
            header_req.write(session);

        state = HDR_INS_ST_HDR_WAIT;
    }
    else if (state == HDR_INS_ST_HDR_WAIT)
    {
        // DDR write bytes
        length_t wr_bytes = 0;
        if (!session.discard)
        {
            wr_bytes = ins_req.burst_length;
            if (session.sof)
                // If sof, add header length
                wr_bytes += HDR_LENGTH;
        }

        // Write instruction to egr_write (even when discarding)
        egr_send_ptr.write(session);
        egr_send_length.write(wr_bytes);

        header_data_t header = 0;
        if (session.sof)
            // Get header (even when discarding)
            header = header_data.read();

        // Number of input words
        length_t rd_words = CDIV(ins_req.burst_length, BUFFER_WIDTH_BYTES);

        if (session.discard)
        {
            // Discard
            int last_bytes = ins_req.burst_length % BUFFER_WIDTH_BYTES;
            if (last_bytes == 0)
                last_bytes = BUFFER_WIDTH_BYTES;
            for (int i = 0; i < rd_words; i++)
            {
#pragma HLS PIPELINE II = 1
                s_axis_egr_rx_data.read(); // Read and discard

                // Without volatile, it may be optimized and counted incorrectly
                volatile uint8_t count = (i < rd_words - 1) ? BUFFER_WIDTH_BYTES : last_bytes;
                if (i == 0 && session.sof)
                    count += HDR_LENGTH;
                stat_egr_discard = channelCycleDataCount(session.ifid, session.channel, count);
            }
        }
        else
        {
            // Number of output words
            length_t wr_words = CDIV(wr_bytes, BUFFER_WIDTH_BYTES);

            if (session.sof)
            {
                // Insert header
                int insert_fault_offset = (session.ifid == 0) ? 0 : 32;
                ap_uint<12> insert_fault_mux = insert_fault(insert_fault_offset + 31, insert_fault_offset);
                ap_uint<1> insert_marker_error = insert_fault_mux(0, 0);
                ap_uint<1> insert_payload_length_error = insert_fault_mux(1, 1);

                uint32_t payload_len = ins_req.payload_len;

                if (insert_marker_error)
                {
                    // Insert marker error
                    header(HDR_FIELD_OFFSET_MARKER * 8 + 31, HDR_FIELD_OFFSET_MARKER * 8) = ~HDR_MARKER;
                }

                if (insert_payload_length_error)
                {
                    // Insert payload length error
                    payload_len += 1;
                }

                // Put payload length
                header(HDR_FIELD_OFFSET_PAY_LEN * 8 + 31, HDR_FIELD_OFFSET_PAY_LEN * 8) = payload_len;

                // Data transfer while shifting by the header length
                buffer_data_t wr_data = 0;
                wr_data(48 * HDR_LENGTH, 0) = header;
                buffer_data_t rd_data;
                for (int i = 0; i < wr_words; i++)
                {
#pragma HLS PIPELINE II = 1
                    if (i < rd_words)
                    {
                        rd_data = s_axis_egr_rx_data.read();
                    }
                    else
                    {
                        // Fill with dummy data for ease of debugging
                        for (int i = 0; i < BUFFER_WIDTH_BYTES / 4; i++)
                        {
#pragma HLS UNROLL
                            rd_data(i * 32 + 31, i * 32) = 0xdeadbeef;
                        }
                    }

                    wr_data(BUFFER_WIDTH_BITS - 1, 8 * HDR_LENGTH) =
                        rd_data(8 * (BUFFER_WIDTH_BYTES - HDR_LENGTH) - 1, 0);

                    egr_session_data.write(wr_data);

                    wr_data(8 * HDR_LENGTH - 1, 0) =
                        rd_data(BUFFER_WIDTH_BITS - 1, 8 * (BUFFER_WIDTH_BYTES - HDR_LENGTH));
                }

                // Notification of completion of header insertion
                headerSeq seq;
                seq.channel = session.channel;
                seq.discard = session.discard;
                seq.seq_no = header(HDR_FIELD_OFFSET_SEQ_NO * 8 + 31, HDR_FIELD_OFFSET_SEQ_NO * 8);
                egr_header_ins_done.write(seq);
            }
            else
            {
                // Transfer of data other than header
                for (int i = 0; i < wr_words; i++)
                {
#pragma HLS PIPELINE II = 1
                    egr_session_data.write(s_axis_egr_rx_data.read());
                }
            }
        }

        state = HDR_INS_ST_REQ_WAIT;
    }
}
