/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include <ap_int.h>
#include <hls_stream.h>

#include "chain_subblock.hpp"
#include "header_buffer.hpp"

struct igCidEntry
{
    connection_t connection : CONNECTION_WIDTH; // [8:0]
    ifid_t ifid : IFID_WIDTH;                   // [9]
    igCidEntry() {}
    igCidEntry(ifid_t ifid, connection_t connection) : ifid(ifid), connection(connection) {}
} __attribute__((packed));

void ingr_hdr_rmv(hls::stream<sessionPtr> &ingr_header_channel,
                  hls::stream<header_data_t> &ingr_header_data,
                  hls::stream<headerPayloadLen> &ingr_payload_len,
                  hls::stream<sessionPtr> &header_req,
                  hls::stream<header_data_t> &header_data,
                  hls::stream<headerSeq> &ingr_header_rmv_done,
                  headerBuffUsage &header_buff_usage,
                  volatile ap_uint<32> &detect_fault)
{
#pragma HLS INTERFACE mode = axis port = ingr_header_channel
#pragma HLS INTERFACE mode = axis port = ingr_header_data
#pragma HLS INTERFACE mode = axis port = ingr_payload_len
#pragma HLS INTERFACE mode = axis port = header_req
#pragma HLS INTERFACE mode = axis port = header_data
#pragma HLS INTERFACE mode = axis port = ingr_header_rmv_done
#pragma HLS INTERFACE mode = ap_ovld port = header_buff_usage
#pragma HLS INTERFACE mode = ap_ovld port = detect_fault
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

    static HeaderBuffer buff;
#pragma HLS BIND_STORAGE variable = buff.headers type = RAM_S2P impl = URAM
#pragma HLS reset variable = buff.headers off
#pragma HLS ARRAY_PARTITION variable = buff.empty_flag type = complete
#pragma HLS ARRAY_PARTITION variable = buff.full_flag type = complete

    static bool wr_pending = false;
    static sessionPtr wr_pending_session;
    static header_data_t wr_pending_data;

    static igCidEntry ig_cid[MAX_NUM_CHANNELS];
#pragma HLS aggregate variable = ig_cid compact = bit
#pragma HLS reset variable = ig_cid off

    if (wr_pending & !buff.full(wr_pending_session.channel))
    {
        // Processing of data waiting to be written
        headerBuffUsage usage;
        buff.write(wr_pending_session, wr_pending_data, usage);
        header_buff_usage = usage;
        wr_pending = false;
    }
    else if (!wr_pending &&
             !ingr_header_channel.empty() &&
             !ingr_header_data.empty() &&
             !ingr_payload_len.full() &&
             !ingr_header_rmv_done.full())
    {
        // Header write
        auto session = ingr_header_channel.read();
        auto data = ingr_header_data.read();

        // Header field extraction
        uint32_t marker = (data >> (HDR_FIELD_OFFSET_MARKER * 8));
        uint32_t pay_len = (data >> (HDR_FIELD_OFFSET_PAY_LEN * 8));
        uint32_t seq_no = (data >> (HDR_FIELD_OFFSET_SEQ_NO * 8));

        // Header check
        ap_uint<1> err_marker = (marker == HDR_MARKER) ? 0 : 1;
        ap_uint<1> err_payload_len = (pay_len > 0) ? 0 : 1;
        ap_uint<1> err_header_len = 0; // Header length checking to be implemented in the future
        ap_uint<1> err_checksum = 0;   // Checksum to be implemented in the future
        ap_uint<8> err_status = 0;     // Status checks will be implemented in the future

        ap_uint<16> err = 0;
        err(0, 0) = err_marker;
        err(1, 1) = err_payload_len;
        err(2, 2) = err_header_len;
        err(3, 3) = err_checksum;
        err(11, 4) = err_status;

        if (!session.discard)
        {
            // To notify buffer usage when reading header
            // keep the connection number on the IG side as it will be needed.
            ig_cid[session.channel] = igCidEntry(session.ifid, session.connection);

            if (!err)
            {
                // buffer if header is good
                if (buff.full(session.channel))
                {
                    // If the buffer is full, wait status is set.
                    wr_pending_session = session;
                    wr_pending_data = data;
                    wr_pending = true;
                }
                else
                {
                    headerBuffUsage usage;
                    buff.write(session, data, usage);
                    header_buff_usage = usage;
                }

                // Notification of completion of header deletion (start of function latency measurement)
                headerSeq seq;
                seq.channel = session.channel;
                seq.seq_no = seq_no;
                ingr_header_rmv_done.write(seq);
            }
            else
            {
                // Header error notification
                ap_uint<32> tmp = 0;
                tmp(CONNECTION_WIDTH - 1, 0) = session.connection;
                tmp(CONNECTION_WIDTH + IFID_WIDTH - 1, CONNECTION_WIDTH) = session.ifid;
                tmp(31, 16) = err;
                detect_fault = tmp;
            }
        }

        // Payload length notification
        headerPayloadLen hplen;
        hplen.length = pay_len;
        hplen.discard = err ? 1 : 0;
        ingr_payload_len.write(hplen);
    }
    else if (!header_req.empty() &&
             !header_data.full())
    {
        // Read Header
        sessionPtr req = header_req.read();
        headerBuffUsage usage;
        header_data_t data = buff.read(req, usage);
        igCidEntry cid_entry = ig_cid[req.channel];
        usage.ifid = cid_entry.ifid; // Replace with external IF ID on IG side
        usage.connection = cid_entry.connection; // Replace with IG's connection number
        header_buff_usage = usage;
        header_data.write(data);
    }
}
