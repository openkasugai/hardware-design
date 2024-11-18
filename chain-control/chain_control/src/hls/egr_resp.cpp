/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"

struct ptrEntry
{
    ptr_t ptr;          // [31:0]
    uint8_t parity : 1; // [32]
    ptrEntry() {}
    ptrEntry(ptr_t p, ap_uint<1> insert_fault) : ptr(p), parity(((ap_uint<32>)p).xor_reduce() ^ insert_fault) {}
    ptr_t check_parity(bool &parity_err)
    {
        parity_err = parity != ((ap_uint<32>)ptr).xor_reduce();
        return ptr;
    }
} __attribute__((packed));

void egr_resp_insert_protocol_fault(sessionReq &resp,
                                    ap_uint<32> &insert_protocol_fault)
{
    if ((insert_protocol_fault >> PROTOCOL_FAULT_RESP_CHANNEL_EQ_REQ) & 1)
        resp.channel += 1;
    if ((insert_protocol_fault >> PROTOCOL_FAULT_RESP_BURST_LENGTH_LE_REQ) & 1)
        resp.burst_length += 1;
    if ((insert_protocol_fault >> PROTOCOL_FAULT_RESP_SOF_EQ_REQ) & 1)
        resp.sof = ~resp.sof;
    if ((insert_protocol_fault >> PROTOCOL_FAULT_RESP_EOF_EQ_REQ) & 1)
        resp.eof = ~resp.eof;
    if ((insert_protocol_fault >> PROTOCOL_FAULT_REQ_MAX_BURST_LENGTH) & 1)
        resp.burst_length = MAX_BURST_LENGTH + 1;
}

// Forward response in the egress direction
void egr_resp(uint8_t m_axi_extif0_buffer_tx_size,
              uint8_t m_axi_extif1_buffer_tx_size,
              hls::stream<sessionForward> &egr_lookup_resp,
              hls::stream<ptrUpdateReq> &snd_una_update_req_0,
              hls::stream<ptrUpdateReq> &evt_usr_wrt_update_req_0,
              hls::stream<ptrUpdateReq> &snd_una_update_req_1,
              hls::stream<ptrUpdateReq> &evt_usr_wrt_update_req_1,
              hls::stream<sessionReq> &egr_session_resp,
              hls::stream<headerInsReq> &egr_hdr_ins_req,
              hls::stream<sessionPtr> &egr_hdr_ins_ptr,
              hls::stream<channel_t> &egr_frame_end,
              hls::stream<sessionPtr> &egr_meas_start,
              channelFrameCount &stat_egr_rcv_frame,
              sessionBurstDataCount &stat_egr_snd_data,
              sessionLastPtr &egr_last_ptr,
              channelBusyCount &egr_busy_count,
              ap_uint<24> &detect_fault,
              ap_uint<8> &insert_fault,
              ap_uint<32> &insert_protocol_fault,
              volatile axilite_data_t &snd_una_update_resp_count,
              volatile axilite_data_t &usr_wrt_update_resp_count,
              volatile axilite_data_t &tx_tail_update_resp_count,
              volatile axilite_data_t &tx_head_update_resp_count,
              volatile axilite_data_t &dbg_lup_snd_una,
              volatile axilite_data_t &dbg_lup_usr_wrt,
              volatile axilite_data_t &dbg_lup_tx_tail,
              volatile axilite_data_t &dbg_lup_tx_head)
{
#pragma HLS INTERFACE mode = ap_none port = m_axi_extif0_buffer_tx_size
#pragma HLS INTERFACE mode = ap_none port = m_axi_extif1_buffer_tx_size
#pragma HLS INTERFACE mode = axis port = egr_lookup_resp
#pragma HLS INTERFACE mode = axis port = snd_una_update_req_0
#pragma HLS INTERFACE mode = axis port = evt_usr_wrt_update_req_0
#pragma HLS INTERFACE mode = axis port = snd_una_update_req_1
#pragma HLS INTERFACE mode = axis port = evt_usr_wrt_update_req_1
#pragma HLS INTERFACE mode = axis port = egr_session_resp
#pragma HLS INTERFACE mode = axis port = egr_hdr_ins_req
#pragma HLS INTERFACE mode = axis port = egr_hdr_ins_ptr
#pragma HLS INTERFACE mode = axis port = egr_frame_end
#pragma HLS INTERFACE mode = axis port = egr_meas_start
#pragma HLS INTERFACE mode = ap_ovld port = stat_egr_rcv_frame
#pragma HLS INTERFACE mode = ap_ovld port = stat_egr_snd_data
#pragma HLS INTERFACE mode = ap_ovld port = egr_last_ptr
#pragma HLS INTERFACE mode = ap_ovld port = egr_busy_count
#pragma HLS INTERFACE mode = ap_ovld port = detect_fault
#pragma HLS INTERFACE mode = ap_none port = insert_fault
#pragma HLS INTERFACE mode = ap_none port = insert_protocol_fault
#pragma HLS INTERFACE mode = ap_none port = snd_una_update_resp_count
#pragma HLS INTERFACE mode = ap_none port = usr_wrt_update_resp_count
#pragma HLS INTERFACE mode = ap_none port = tx_tail_update_resp_count
#pragma HLS INTERFACE mode = ap_none port = tx_head_update_resp_count
#pragma HLS INTERFACE mode = ap_none port = dbg_lup_snd_una
#pragma HLS INTERFACE mode = ap_none port = dbg_lup_usr_wrt
#pragma HLS INTERFACE mode = ap_none port = dbg_lup_tx_tail
#pragma HLS INTERFACE mode = ap_none port = dbg_lup_tx_head
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

    // Initialization complete flag
    static bool init_done = false;

    // Wait transfer (the initial value is invalid connection)
    static bool session_remain_enable = false;
    static sessionForward session_remain;

    // Pointer Management Table
    static ap_uint<1> table_valid[PTR_TABLE_DEPTH];
#pragma HLS ARRAY_PARTITION variable = table_valid type = complete
    static ptrEntry table_snd_una[PTR_TABLE_DEPTH];
#pragma HLS aggregate variable = table_snd_una compact = bit
#pragma HLS reset variable = table_snd_una off
    static ptrEntry table_usr_wrt[PTR_TABLE_DEPTH];
#pragma HLS aggregate variable = table_usr_wrt compact = bit
#pragma HLS reset variable = table_usr_wrt off
    static ptrEntry table_pay_len[PTR_TABLE_DEPTH];
#pragma HLS aggregate variable = table_pay_len compact = bit
#pragma HLS reset variable = table_pay_len off
    static uint8_t busy_count[MAX_NUM_CHANNELS];
#pragma HLS reset variable = busy_count off

    // Counter
    static axilite_data_t snd_una_update_resp_count_reg = 0;
    static axilite_data_t usr_wrt_update_resp_count_reg = 0;
    static axilite_data_t tx_tail_update_resp_count_reg = 0;
    static axilite_data_t tx_head_update_resp_count_reg = 0;
    snd_una_update_resp_count = snd_una_update_resp_count_reg;
    usr_wrt_update_resp_count = usr_wrt_update_resp_count_reg;
    tx_tail_update_resp_count = tx_tail_update_resp_count_reg;
    tx_head_update_resp_count = tx_head_update_resp_count_reg;

    static volatile axilite_data_t dbg_lup_snd_una_reg = 0;
    static volatile axilite_data_t dbg_lup_usr_wrt_reg = 0;
    static volatile axilite_data_t dbg_lup_tx_tail_reg = 0;
    static volatile axilite_data_t dbg_lup_tx_head_reg = 0;
    dbg_lup_snd_una = dbg_lup_snd_una_reg;
    dbg_lup_usr_wrt = dbg_lup_usr_wrt_reg;
    dbg_lup_tx_tail = dbg_lup_tx_tail_reg;
    dbg_lup_tx_head = dbg_lup_tx_head_reg;

    bool err_snd_una_parity = false;
    bool err_usr_wrt_parity = false;
    bool err_pay_len_parity = false;
    bool err_ptr_mishit = false;
    bool err_pay_len_mishit = false;
    bool err_bad_pay_len = false;
    ifid_t err_ifid = 0;
    connection_t err_connection = 0;
    sessionForward session;

    if (!init_done)
    {
        // RAM self-initialization
        for (int i = 0; i < MAX_NUM_CHANNELS; i++)
        {
#pragma HLS PIPELINE
            busy_count[i] = 0;
        }
        init_done = true;
    }
    else if (!evt_usr_wrt_update_req_0.empty() || !evt_usr_wrt_update_req_1.empty())
    {
        ptrUpdateReq update_req;
        ptrEntry entry;
        int key = 0;
        ifid_t ifid;
        if (evt_usr_wrt_update_req_0.read_nb(update_req))
        {
            key = update_req.connection;
            ifid = 0;
        }
        else
        {
            update_req = evt_usr_wrt_update_req_1.read();
            key = update_req.connection | (1 << CONNECTION_WIDTH);
            ifid = 1;
        }

        ap_uint<1> ptr_insert_fault = (ifid == 0) ? insert_fault(0, 0) : insert_fault(4, 4);
        ap_uint<1> len_insert_fault = (ifid == 0) ? insert_fault(1, 1) : insert_fault(5, 5);

        if (update_req.op == tableOp::TABLE_OP_INSERT)
        {
            // Connection establishment: Clear pointer table
            table_snd_una[key] = ptrEntry(update_req.ptr, ptr_insert_fault);
            table_usr_wrt[key] = ptrEntry(update_req.ptr, ptr_insert_fault);
            table_pay_len[key] = ptrEntry(0, len_insert_fault);
            table_valid[key] = 1;
        }
        else if (update_req.op == tableOp::TABLE_OP_DELETE)
        {
            // Disconnection: Disable entry
            table_valid[key] = 0;
        }
    }
    else if (!snd_una_update_req_0.empty() || !snd_una_update_req_1.empty())
    {
        // snd_una update
        ptrUpdateReq update_req;
        ptrEntry entry;
        int key = 0;
        ifid_t ifid;
        if (snd_una_update_req_0.read_nb(update_req))
        {
            key = update_req.connection;
            ifid = 0;
        }
        else
        {
            update_req = snd_una_update_req_1.read();
            key = update_req.connection | (1 << CONNECTION_WIDTH);
            ifid = 1;
        }

        err_ifid = ifid;
        err_connection = update_req.connection;

        ap_uint<1> ptr_insert_fault = (ifid == 0) ? insert_fault(0, 0) : insert_fault(4, 4);

        if (table_valid[key])
        {
            ptr_t new_ptr = update_req.ptr;
            ptr_t old_ptr = table_snd_una[key].check_parity(err_snd_una_parity);
            table_snd_una[key] = ptrEntry(new_ptr, ptr_insert_fault);

            volatile length_t sent_bytes = calc_length_bytes(new_ptr, old_ptr);
            stat_egr_snd_data = sessionBurstDataCount(ifid, update_req.connection, sent_bytes);
        }
        else
            err_ptr_mishit = true;
    }
    else if (!egr_frame_end.empty())
    {
        // Frame write completion notification
        // --> Update busy count and notify to register
        channel_t ch = egr_frame_end.read();
        uint8_t count = busy_count[ch];
        if (count > 0)
            count--;
        busy_count[ch] = count;
        egr_busy_count = channelBusyCount(ch, count);
    }
    else if (session_remain_enable || !egr_lookup_resp.empty())
    {
        if (session_remain_enable)
            session = session_remain;
        else
            session = egr_lookup_resp.read();

        ap_uint<1> ptr_insert_fault = (session.ifid == 0) ? insert_fault(0, 0) : insert_fault(4, 4);
        ap_uint<1> len_insert_fault = (session.ifid == 0) ? insert_fault(1, 1) : insert_fault(5, 5);

        err_ifid = session.ifid;
        err_connection = session.connection;

        // Keys for table references
        int key = ((int)session.ifid << CONNECTION_WIDTH) | session.connection;

        // Buffer size calculation
        uint8_t buffer_size_sel =
            (session.ifid == 0) ? m_axi_extif0_buffer_tx_size : m_axi_extif1_buffer_tx_size;
        length_t buffer_connection_bytes = calc_buffer_size(buffer_size_sel);

        // Get a pointer to the send buffer
        ptr_t snd_una = table_snd_una[key].check_parity(err_snd_una_parity);
        ptr_t usr_wrt = table_usr_wrt[key].check_parity(err_usr_wrt_parity);
        ptr_t pay_len = table_pay_len[key].check_parity(err_pay_len_parity);
        err_pay_len_mishit = err_ptr_mishit = !table_valid[key];

        // Notification of final pointer value
        sessionLastPtr last_ptr;
        last_ptr.ifid = session.ifid;
        last_ptr.connection = session.connection;
        last_ptr.reserved = 0;
        last_ptr.wr_ptr = usr_wrt;
        last_ptr.rd_ptr = snd_una;
        egr_last_ptr = last_ptr;

        if (session.ifid == 0)
        {
            // Debug register
            dbg_lup_snd_una_reg = static_cast<axilite_data_t>(snd_una);
            dbg_lup_usr_wrt_reg = static_cast<axilite_data_t>(usr_wrt);
        }
        else
        {
            // Debug register
            dbg_lup_tx_tail_reg = static_cast<axilite_data_t>(snd_una);
            dbg_lup_tx_head_reg = static_cast<axilite_data_t>(usr_wrt);
        }

        // Use the user's pointer to determine that an Tx connection has been established
        // Calculates the amount of free space in the Tx buffer and issues an egress transfer request to a later stage
        length_t remain = calc_remain_bytes(snd_una, usr_wrt, buffer_connection_bytes);

        // The number of bytes written to the Tx buffer.
        // When sof==1, consider also header length
        length_t write_bytes = 0;
        if (!session.discard)
        {
            write_bytes = session.burst_length;
            if (session.sof)
                write_bytes += HDR_LENGTH;
        }

        if (remain >= write_bytes)
        {
            // Payload length check
            if (session.sof)
            {
                err_bad_pay_len |= (pay_len != 0); // Previous frame not completed
                pay_len = session.frame_length;
            }

            err_bad_pay_len |= pay_len < session.burst_length; // Burst length is longer than remaining payload length

            if (pay_len >= session.burst_length)
                pay_len -= session.burst_length;
            else
                pay_len = 0;

            if (session.eof)
                err_bad_pay_len |= (pay_len != 0); // EOF but remaining payload length is not 0
            else
                err_bad_pay_len |= (pay_len == 0); // Remaining payload length is 0 even though it is not EOF

            table_pay_len[key] = ptrEntry(pay_len, len_insert_fault);

            // return resp for req
            sessionReq resp(
                session.channel,
                session.burst_length,
                session.sof,
                session.eof,
                0,  // direct
                0); // frame_length
            egr_resp_insert_protocol_fault(resp, insert_protocol_fault);
            egr_session_resp.write(resp);

            // header insert request
            headerInsReq ins_req(session.burst_length, session.frame_length);
            egr_hdr_ins_req.write(ins_req);
            sessionPtr session_ptr(session, snd_una, usr_wrt);
            egr_hdr_ins_ptr.write(session_ptr);

            if (session.sof)
            {
                // SOF --> Update busy count and notify to register
                uint8_t count = busy_count[session.channel];
                if (count < 255)
                    count++;
                busy_count[session.channel] = count;
                egr_busy_count = channelBusyCount(session.channel, count);

                // Frame counter
                stat_egr_rcv_frame = channelFrameCount(session.ifid, session.channel);
            }

            if (!session.discard)
            {
                // usr_wrt update
                table_usr_wrt[key] = ptrEntry(calc_sn(usr_wrt, write_bytes), ptr_insert_fault);
            }

            if (session.ifid == 0)
            {
                usr_wrt_update_resp_count_reg++;
            }
            else
            {
                tx_head_update_resp_count_reg++;
            }

            // Clears the buffer free wait queue
            session_remain_enable = false;

            // Start latency measurement
            egr_meas_start.write(session_ptr);
        }
        else if (!session.blocking)
        {
            // Respond with burst_length = 0 if not a blocking transfer
            sessionReq resp(
                session.channel,
                0, // burst_length
                session.sof,
                session.eof,
                0,  // direct
                0); // frame_length
            egr_resp_insert_protocol_fault(resp, insert_protocol_fault);
            egr_session_resp.write(resp);
        }
        else
        {
            // Egress transfer notification trigger can't push out the rest,
            // so queueing the buffer waiting for a free buffer.
            session_remain = session;
            session_remain_enable = true;
        }
    }

    if (err_snd_una_parity || err_usr_wrt_parity || err_pay_len_parity ||
        err_ptr_mishit || err_pay_len_mishit || err_bad_pay_len)
    {
        ap_uint<24> tmp = 0;
        tmp(CONNECTION_WIDTH - 1, 0) = err_connection;
        tmp(CONNECTION_WIDTH + IFID_WIDTH - 1, CONNECTION_WIDTH) = err_ifid;
        tmp(16, 16) = err_bad_pay_len ? 1 : 0;
        tmp(17, 17) = err_ptr_mishit ? 1 : 0;
        tmp(18, 18) = err_pay_len_mishit ? 1 : 0;
        tmp(19, 19) = (err_snd_una_parity || err_usr_wrt_parity) ? 1 : 0;
        tmp(20, 20) = err_pay_len_parity ? 1 : 0;
        detect_fault = tmp;
    }
}
