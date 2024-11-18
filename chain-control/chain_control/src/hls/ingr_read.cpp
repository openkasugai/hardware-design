/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"
#include "barrel_shifter.hpp"

void read_buffer_burst(buffer_data_t *buffer,
                       int words,
                       int offset,
                       hls::stream<session_data_t> &dma_data)
{
LOOP_READ_BUFFER_BURST:
    for (int i = 0; i < words; i++)
    {
#pragma HLS PIPELINE II = 1
        dma_data.write(buffer[offset + i]);
    }
}

void read_buffer_dma(address_t base,
                     sessionPtr session,
                     length_t length,
                     uint8_t buffer_size_sel,
                     buffer_data_t *buffer0,
                     buffer_data_t *buffer1,
                     hls::stream<session_data_t> &dma_data)
{
    if (session.discard && !session.head)
        // if the discard flag is set, discard all but the header
        return;

    length_t buffer_bytes = calc_buffer_size(buffer_size_sel);

    // Reading start index
    ptr_t wrapped_sn = session.usr & (buffer_bytes - 1);

    // Barrel shift amount
    int barrel_offset = session.usr % BUFFER_WIDTH_BYTES;

    // Size of burst 0
    length_t bst0_bytes = length;
    length_t bst0_words = CDIV(barrel_offset + length, BUFFER_WIDTH_BYTES);

    // Size of burst 1
    length_t bst1_bytes = 0;
    length_t bst1_words = 0;

    // Split the burst if crossing the wrap around boundary
    if (wrapped_sn + bst0_bytes > buffer_bytes)
    {
        bst0_bytes = buffer_bytes - wrapped_sn;
        bst0_words = CDIV(bst0_bytes, BUFFER_WIDTH_BYTES);
        bst1_bytes = length - bst0_bytes;
        bst1_words = CDIV(bst1_bytes, BUFFER_WIDTH_BYTES);
    }

    // Burst 0
    if (bst0_words > 0)
    {
        address_t index_base = (base + wrapped_sn) / BUFFER_WIDTH_BYTES;
        if (session.ifid == 0)
        {
            read_buffer_burst(buffer0, bst0_words, index_base, dma_data);
        }
        else
        {
            read_buffer_burst(buffer1, bst0_words, index_base, dma_data);
        }
    }

    // Burst 1
    if (bst1_words > 0)
    {
        address_t index_base = base / BUFFER_WIDTH_BYTES;
        if (session.ifid == 0)
        {
            read_buffer_burst(buffer0, bst1_words, index_base, dma_data);
        }
        else
        {
            read_buffer_burst(buffer1, bst1_words, index_base, dma_data);
        }
    }
}

void read_buffer_shift(sessionPtr session,
                       length_t length,
                       hls::stream<session_data_t> &dma_data,
                       hls::stream<session_data_t> &data)
{
    if (session.discard && !session.head)
        // If the discard flag is set, discard all but the header
        return;

    // Barrel shift amount
    int barrel_offset = session.usr % BUFFER_WIDTH_BYTES;

    // Number of read words
    length_t num_reads = CDIV(barrel_offset + length, BUFFER_WIDTH_BYTES);
    bool single_read = (num_reads <= 1);

    // Number of output words
    length_t num_writes = CDIV(length, BUFFER_WIDTH_BYTES);

    // Already aligned.
    bool already_aligned = (barrel_offset == 0);

    // Number of loops
    length_t num_total_loops =
        length == 0 ? 0 : single_read   ? 1
                      : already_aligned ? num_reads
                                        : num_writes + 1;

    // Barrel shift register
    ap_uint<BUFFER_WIDTH_BITS * 2> shift_reg = 0;
    // Filled with dummy data for ease of debugging
    for (int i = 0; i < BUFFER_WIDTH_BYTES * 2; i++)
    {
#pragma HLS UNROLL
        shift_reg(i * 8 + 7, i * 8) = 0xE1;
    }

// Loop with burst forwarding
LOOP_READ_BUFFER_WORDS:
    for (length_t i = 0; i < num_total_loops; i++)
    {
#pragma HLS PIPELINE II = 1

        // DDR Read
        buffer_data_t in_word = 0;
        // Filled with dummy data for ease of debugging
        for (int i = 0; i < BUFFER_WIDTH_BYTES; i++)
        {
#pragma HLS UNROLL
            in_word(i * 8 + 7, i * 8) = 0xE2;
        }

        if (i < num_reads)
        {
            in_word = dma_data.read();
        }

        if (already_aligned || single_read)
        {
            // If it is already aligned, or if it does not span multiple words, pack it to the lower side.
            shift_reg(BUFFER_WIDTH_BITS - 1, 0) = in_word;
        }
        else
        {
            // If it is not aliged and the data spans multiple words, the previous read value is concatenated.
            shift_reg(BUFFER_WIDTH_BITS - 1, 0) = shift_reg(BUFFER_WIDTH_BITS * 2 - 1, BUFFER_WIDTH_BITS);
            shift_reg(BUFFER_WIDTH_BITS * 2 - 1, BUFFER_WIDTH_BITS) = in_word;
        }

        if (already_aligned || single_read || i > 0)
        {
            // Barrel shift and write to stream
            data.write(barrel_1024to512_dsp(shift_reg, barrel_offset));
        }
    }
}

void read_buffer_demux(sessionPtr session,
                       length_t length,
                       hls::stream<session_data_t> &aligned_data,
                       hls::stream<header_data_t> &header_data,
                       hls::stream<session_data_t> &session_data,
                       channelCycleDataCount &data_cnt,
                       ap_uint<1> insert_dummy_cycle)
{
    // Number of transfer words
    length_t words = CDIV(length, BUFFER_WIDTH_BYTES);

    // Number of bytes in the last word
    length_t last_bytes = length % BUFFER_WIDTH_BYTES;
    if (last_bytes == 0)
        last_bytes = BUFFER_WIDTH_BYTES;

LOOP_READ_BUFFER_DEMUX:
    for (int i = 0; i < words; i++)
    {
#pragma HLS PIPELINE II = 1
        if (session.head)
            header_data.write(aligned_data.read()(HDR_LENGTH * 8, 0));
        else if (!session.discard)
            session_data.write(aligned_data.read());

        if (!session.discard)
        {
            // Without volatile, it may be optimized and counted incorrectly
            volatile uint8_t count = (i < words - 1) ? BUFFER_WIDTH_BYTES : last_bytes;
            data_cnt = channelCycleDataCount(session.ifid, session.channel, count);
        }
    }

    if (insert_dummy_cycle && !session.discard && !session.head)
        session_data.write(0);
}

void read_buffer(address_t base,
                 sessionPtr session,
                 length_t length,
                 uint8_t buffer_size_sel,
                 buffer_data_t *buffer0,
                 buffer_data_t *buffer1,
                 hls::stream<header_data_t> &header_data,
                 hls::stream<session_data_t> &session_data,
                 channelCycleDataCount &data_cnt,
                 ap_uint<1> insert_dummy_cycle)
{
    hls::stream<session_data_t> dma_data;
    hls::stream<session_data_t> aligned_data;

#pragma HLS dataflow
    read_buffer_dma(
        base, session, length, buffer_size_sel, buffer0, buffer1, dma_data);
    read_buffer_shift(
        session, length, dma_data, aligned_data);
    read_buffer_demux(
        session, length, aligned_data, header_data, session_data,
        data_cnt, insert_dummy_cycle);
}

// buffer read in ingress direction
void ingr_read(address_t m_axi_extif0_buffer_rx_offset,
               length_t m_axi_extif0_buffer_rx_stride,
               uint8_t m_axi_extif0_buffer_rx_size,
               address_t m_axi_extif1_buffer_rx_offset,
               length_t m_axi_extif1_buffer_rx_stride,
               uint8_t m_axi_extif1_buffer_rx_size,
               hls::stream<sessionReq> &ingr_session_resp,
               hls::stream<session_data_t> &ingr_session_data,
               hls::stream<sessionPtr> &ingr_send,
               hls::stream<extifCommand> &ingr_cmd_0,
               hls::stream<extifCommand> &ingr_cmd_1,
               hls::stream<sessionPtr> &ingr_header_channel,
               hls::stream<header_data_t> &ingr_header_data,
               hls::stream<ptrUpdateReq> &ingr_usr_read_update_req,
               buffer_data_t *m_axi_extif0_buffer,
               buffer_data_t *m_axi_extif1_buffer,
               channelCycleDataCount &stat_ingr_snd_data,
               channelFrameCount &stat_ingr_snd_frame,
               channelBurstDataCount &stat_ingr_discard,
               ap_uint<32> insert_protocol_fault,
               ap_uint<32> insert_command_fault_0,
               ap_uint<32> insert_command_fault_1,
               volatile axilite_data_t &dbg_cmd_rcv_cid,
               volatile axilite_data_t &dbg_cmd_usr_read)
{
#pragma HLS INTERFACE mode = ap_none port = m_axi_extif0_buffer_rx_offset
#pragma HLS INTERFACE mode = ap_none port = m_axi_extif0_buffer_rx_stride
#pragma HLS INTERFACE mode = ap_none port = m_axi_extif0_buffer_rx_size
#pragma HLS INTERFACE mode = ap_none port = m_axi_extif1_buffer_rx_offset
#pragma HLS INTERFACE mode = ap_none port = m_axi_extif1_buffer_rx_stride
#pragma HLS INTERFACE mode = ap_none port = m_axi_extif1_buffer_rx_size
#pragma HLS INTERFACE mode = axis port = ingr_session_resp
#pragma HLS INTERFACE mode = axis port = ingr_session_data
#pragma HLS INTERFACE mode = axis port = ingr_send
#pragma HLS INTERFACE mode = axis port = ingr_cmd_0
#pragma HLS INTERFACE mode = axis port = ingr_cmd_1
#pragma HLS INTERFACE mode = axis port = ingr_header_channel
#pragma HLS INTERFACE mode = axis port = ingr_header_data
#pragma HLS INTERFACE mode = axis port = ingr_usr_read_update_req
#pragma HLS INTERFACE mode = m_axi port = m_axi_extif0_buffer offset = direct bundle = gmem_extif0 depth = 0x80000
#pragma HLS INTERFACE mode = m_axi port = m_axi_extif1_buffer offset = direct bundle = gmem_extif1 depth = 0x80000
#pragma HLS INTERFACE mode = ap_ovld port = stat_ingr_snd_data
#pragma HLS INTERFACE mode = ap_ovld port = stat_ingr_snd_frame
#pragma HLS INTERFACE mode = ap_ovld port = stat_ingr_discard
#pragma HLS INTERFACE mode = ap_none port = insert_protocol_fault
#pragma HLS INTERFACE mode = ap_none port = insert_command_fault_0
#pragma HLS INTERFACE mode = ap_none port = insert_command_fault_1
#pragma HLS INTERFACE mode = ap_none port = dbg_cmd_rcv_cid
#pragma HLS INTERFACE mode = ap_none port = dbg_cmd_usr_read
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

    static volatile axilite_data_t dbg_cmd_rcv_cid_reg = 0;
    static volatile axilite_data_t dbg_cmd_usr_read_reg = 0;

    if (!ingr_send.empty() &&
        !ingr_cmd_0.full() &&
        !ingr_cmd_1.full() &&
        !ingr_header_channel.full() &&
        !ingr_header_data.full() &&
        !ingr_usr_read_update_req.full())
    {
        // Out-of-Order is not supported, so it is not necessary to check the connection and channel mapping
        sessionPtr session_connection = ingr_send.read();

        // Select buffer area settings
        uint8_t buffer_size_sel;
        if (session_connection.ifid == 0)
            buffer_size_sel = m_axi_extif0_buffer_rx_size;
        else
            buffer_size_sel = m_axi_extif1_buffer_rx_size;

        // Calculate buffer offset
        address_t buff_area_offset = calc_buffer_offset(
            session_connection.ifid,
            session_connection.connection,
            m_axi_extif0_buffer_rx_offset,
            m_axi_extif0_buffer_rx_stride,
            m_axi_extif1_buffer_rx_offset,
            m_axi_extif1_buffer_rx_stride);

        // Determine burst length
        length_t burst_length;
        if (session_connection.head)
            // Fixed length for header
            burst_length = HDR_LENGTH;
        else if (session_connection.discard)
            // All received data when discarding
            burst_length = calc_length_bytes(session_connection.ext, session_connection.usr);
        else
            // Refer to the forwarding response when the header is not specified.
            burst_length = ingr_session_resp.read().burst_length;

        // Transfers data received read from DDR to the post stage
        if (burst_length > 0)
        {
            ap_uint<1> insert_dummy_cycle = (insert_protocol_fault >> PROTOCOL_FAULT_DATA_TRANS_CW_RESP) & 1;
            read_buffer(
                buff_area_offset, session_connection, burst_length,
                buffer_size_sel, m_axi_extif0_buffer, m_axi_extif1_buffer,
                ingr_header_data, ingr_session_data,
                stat_ingr_snd_data, insert_dummy_cycle);
        }

        if (session_connection.head)
            // In the case of a header, the channel ID is transfered to the ingr_hdr_rmv.
            ingr_header_channel.write(session_connection);

        if (!session_connection.discard)
        {
            if (session_connection.head)
                // Frame Count
                stat_ingr_snd_frame = channelFrameCount(
                    session_connection.ifid, session_connection.channel);
        }
        else
        {
            // Discard count
            stat_ingr_discard = channelBurstDataCount(
                session_connection.ifid, session_connection.channel, burst_length);
        }

        // Update the user side pointer of the receive buffer.
        // Update pointer even in read_buffer(), but pass by value because
        // passing by reference causes unintended HLS results.
        session_connection.usr = calc_sn(session_connection.usr, burst_length);

        // Debug register
        dbg_cmd_rcv_cid_reg = static_cast<axilite_data_t>(session_connection.connection);
        dbg_cmd_usr_read_reg = static_cast<axilite_data_t>(session_connection.usr);

        if (burst_length > 0)
        {
            // Notify updated pointers to the external IF
            extifCommand cmd(
                static_cast<command_t>(extifCommandStatus::RECEIVE),
                session_connection.connection, session_connection.usr);

            if (session_connection.ifid == 0)
            {
                if (insert_command_fault_0(0, 0))
                    cmd.cid = insert_command_fault_0(31, 16);

                ingr_cmd_0.write(cmd);
            }
            else
            {
                if (insert_command_fault_1(0, 0))
                    cmd.cid = insert_command_fault_1(31, 16);

                ingr_cmd_1.write(cmd);
            }
        }

        ingr_usr_read_update_req.write(ptrUpdateReq(
            tableOp::TABLE_OP_INSERT,
            session_connection.ifid,
            session_connection.connection,
            session_connection.usr,
            1));
    }

    dbg_cmd_rcv_cid = dbg_cmd_rcv_cid_reg;
    dbg_cmd_usr_read = dbg_cmd_usr_read_reg;
}
