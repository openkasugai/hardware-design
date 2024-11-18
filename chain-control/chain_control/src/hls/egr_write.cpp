/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"
#include "barrel_shifter.hpp"

buffer_data_t write_buffer_shift(sessionPtr &session,
                                 length_t length,
                                 buffer_data_t old_last_word,
                                 hls::stream<session_data_t> &dma_data,
                                 hls::stream<session_data_t> &data,
                                 channelCycleDataCount &data_cnt)
{
    // Position of the first byte to be written
    int usr_mod = session.usr % BUFFER_WIDTH_BYTES;

    // Barrel shift amount
    // Since the shift is in the opposite direction from when reading, Take complement of it.
    int barrel_offset = (usr_mod == 0) ? 0 : BUFFER_WIDTH_BYTES - usr_mod;

    // Number of read words
    length_t num_reads = CDIV(length, BUFFER_WIDTH_BYTES);

    // Number of output words
    length_t num_writes = CDIV(length + usr_mod, BUFFER_WIDTH_BYTES);
    bool single_write = (num_writes <= 1);

    // Already aligned.
    bool already_aligned = (barrel_offset == 0);

    // Number of loops
    length_t num_total_loops =
        length == 0 ? 0 : single_write  ? 1
                      : already_aligned ? num_reads
                                        : num_writes;

    // Number of bytes in the last word
    length_t last_bytes = length % BUFFER_WIDTH_BYTES;
    if (last_bytes == 0)
        last_bytes = BUFFER_WIDTH_BYTES;

    // Barrel shift register
    ap_uint<BUFFER_WIDTH_BITS * 2> shift_reg = 0;
    // Filled with dummy data for ease of debugging
    for (int i = 0; i < BUFFER_WIDTH_BYTES * 2; i++)
    {
#pragma HLS UNROLL
        shift_reg(i * 8 + 7, i * 8) = 0xE3;
    }

    buffer_data_t new_last_word = old_last_word;

    // Loop with burst forwarding
LOOP_WRITE_BUFFER_WORDS:
    for (int i = 0; i < num_total_loops; i++)
    {
#pragma HLS PIPELINE II = 1
        // Stream receive
        buffer_data_t in_word = 0;
        // Filled with dummy data for ease of debugging
        for (int i = 0; i < BUFFER_WIDTH_BYTES; i++)
        {
#pragma HLS UNROLL
            in_word(i * 8 + 7, i * 8) = 0xE4;
        }

        if (i < num_reads)
        {
            in_word = data.read();

            // Without volatile, it may be optimized and counted incorrectly
            volatile uint8_t count = (i < num_reads - 1) ? BUFFER_WIDTH_BYTES : last_bytes;
            data_cnt = channelCycleDataCount(session.ifid, session.channel, count);
        }

        if (already_aligned)
        {
            // If barrel shift is not necessary, pack it to the lower side.
            shift_reg(BUFFER_WIDTH_BITS - 1, 0) = in_word;
        }
        else
        {
            // Concatenates with the previous read value if the read value spans multiple words
            shift_reg(BUFFER_WIDTH_BITS - 1, 0) = shift_reg(BUFFER_WIDTH_BITS * 2 - 1, BUFFER_WIDTH_BITS);
            shift_reg(BUFFER_WIDTH_BITS * 2 - 1, BUFFER_WIDTH_BITS) = in_word;
        }

        // Barrel shift and write to DDR
        new_last_word = barrel_1024to512_dsp(shift_reg, barrel_offset);

        if (i == 0 && barrel_offset > 0)
        {
            // Fill the space at the beginning of the first write with the space from the last write.
            new_last_word(usr_mod * 8 - 1, 0) = old_last_word(usr_mod * 8 - 1, 0);
        }

        dma_data.write(new_last_word);
    }

    return new_last_word;
}

void write_buffer_burst(buffer_data_t *buffer,
                        length_t words,
                        int offset,
                        hls::stream<session_data_t> &dma_data)
{
LOOP_WRITE_BUFFER_BURST:
    for (int i = 0; i < words; i++)
    {
#pragma HLS PIPELINE II = 1
        buffer[offset + i] = dma_data.read();
    }
}

void write_buffer_dma(address_t base,
                      sessionPtr &session,
                      length_t length,
                      uint8_t buffer_size_sel,
                      hls::stream<session_data_t> &dma_data,
                      buffer_data_t *buffer0,
                      buffer_data_t *buffer1)
{
    // Reading start index
    length_t buffer_bytes = calc_buffer_size(buffer_size_sel);

    // Reading start index
    ptr_t wrapped_sn = session.usr & (buffer_bytes - 1);

    // Barrel shift amount
    int barrel_offset = session.usr % BUFFER_WIDTH_BYTES;

    // Size of burst 0
    length_t bst0_bytes = length;
    length_t bst0_words = CDIV(barrel_offset + length, BUFFER_WIDTH_BYTES);

    // Size of Burst 1
    length_t bst1_bytes = 0;
    length_t bst1_words = 0;

    // Split burst if crossing a wrap around boundary
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
            write_buffer_burst(buffer0, bst0_words, index_base, dma_data);
        }
        else
        {
            write_buffer_burst(buffer1, bst0_words, index_base, dma_data);
        }
    }

    // Burst 1
    if (bst1_words > 0)
    {
        address_t index_base = base / BUFFER_WIDTH_BYTES;
        if (session.ifid == 0)
        {
            write_buffer_burst(buffer0, bst1_words, index_base, dma_data);
        }
        else
        {
            write_buffer_burst(buffer1, bst1_words, index_base, dma_data);
        }
    }
}

buffer_data_t write_buffer(address_t base,
                           sessionPtr &session,
                           length_t length,
                           uint8_t buffer_size_sel,
                           buffer_data_t old_last_word,
                           hls::stream<session_data_t> &data,
                           buffer_data_t *buffer0,
                           buffer_data_t *buffer1,
                           channelCycleDataCount &data_cnt)
{
    hls::stream<session_data_t> dma_data;
    // #pragma HLS stream variable=dma_data depth=2

#pragma HLS dataflow
    buffer_data_t new_last_word = write_buffer_shift(
        session, length, old_last_word, dma_data, data, data_cnt);
    write_buffer_dma(
        base, session, length, buffer_size_sel, dma_data, buffer0, buffer1);

    return new_last_word;
}

// buffer write for egress direction
void egr_write(address_t m_axi_extif0_buffer_tx_offset,
               length_t m_axi_extif0_buffer_tx_stride,
               uint8_t m_axi_extif0_buffer_tx_size,
               address_t m_axi_extif1_buffer_tx_offset,
               length_t m_axi_extif1_buffer_tx_stride,
               uint8_t m_axi_extif1_buffer_tx_size,
               hls::stream<session_data_t> &egr_session_data,
               hls::stream<sessionPtr> &egr_send_ptr,
               hls::stream<length_t> &egr_send_length,
               hls::stream<extifCommand> &egr_cmd_0,
               hls::stream<extifCommand> &egr_cmd_1,
               hls::stream<channel_t> &egr_frame_end,
               hls::stream<sessionPtr> &egr_meas_end,
               buffer_data_t *m_axi_extif0_buffer,
               buffer_data_t *m_axi_extif1_buffer,
               channelCycleDataCount &stat_egr_rcv_data,
               ap_uint<32> insert_command_fault_0,
               ap_uint<32> insert_command_fault_1,
               volatile axilite_data_t &dbg_cmd_snd_cid,
               volatile axilite_data_t &dbg_cmd_usr_wrt)
{
#pragma HLS INTERFACE mode = ap_none port = m_axi_extif0_buffer_tx_offset
#pragma HLS INTERFACE mode = ap_none port = m_axi_extif0_buffer_tx_stride
#pragma HLS INTERFACE mode = ap_none port = m_axi_extif0_buffer_tx_size
#pragma HLS INTERFACE mode = ap_none port = m_axi_extif1_buffer_tx_offset
#pragma HLS INTERFACE mode = ap_none port = m_axi_extif1_buffer_tx_stride
#pragma HLS INTERFACE mode = ap_none port = m_axi_extif1_buffer_tx_size
#pragma HLS INTERFACE mode = axis port = egr_session_data
#pragma HLS INTERFACE mode = axis port = egr_send_ptr
#pragma HLS INTERFACE mode = axis port = egr_send_length
#pragma HLS INTERFACE mode = axis port = egr_cmd_0
#pragma HLS INTERFACE mode = axis port = egr_cmd_1
#pragma HLS INTERFACE mode = axis port = egr_frame_end
#pragma HLS INTERFACE mode = axis port = egr_meas_end
#pragma HLS INTERFACE mode = m_axi port = m_axi_extif0_buffer offset = direct bundle = gmem_extif0 depth = 0x80000
#pragma HLS INTERFACE mode = m_axi port = m_axi_extif1_buffer offset = direct bundle = gmem_extif1 depth = 0x80000
#pragma HLS INTERFACE mode = ap_ovld port = stat_egr_rcv_data
#pragma HLS INTERFACE mode = ap_none port = insert_command_fault_0
#pragma HLS INTERFACE mode = ap_none port = insert_command_fault_1
#pragma HLS INTERFACE mode = ap_none port = dbg_cmd_snd_cid
#pragma HLS INTERFACE mode = ap_none port = dbg_cmd_usr_wrt
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

    static volatile axilite_data_t dbg_cmd_snd_cid_reg = 0;
    static volatile axilite_data_t dbg_cmd_usr_wrt_reg = 0;

    // RAM that temporarily holds fragments of less than 1 words
    static buffer_data_t fragments[PTR_TABLE_DEPTH];
#pragma HLS BIND_STORAGE variable = fragments type = RAM_S2P impl = URAM
#pragma HLS reset variable = fragments off

    if (!egr_send_ptr.empty() &&
        !egr_send_length.empty() &&
        !egr_cmd_0.full() &&
        !egr_cmd_1.full())
    {
        sessionPtr session_connection = egr_send_ptr.read();
        length_t burst_length = egr_send_length.read();

        if (!session_connection.discard && burst_length > 0)
        {
            int fragment_key =
                (((int)session_connection.ifid) << CONNECTION_WIDTH) | session_connection.connection;

            // buffer area setting and last word selection
            uint8_t buffer_size_sel;
            if (session_connection.ifid == 0)
            {
                buffer_size_sel = m_axi_extif0_buffer_tx_size;
            }
            else
            {
                buffer_size_sel = m_axi_extif1_buffer_tx_size;
            }
            buffer_data_t last_word = fragments[fragment_key];

            // Calculate buffer offset
            address_t buff_area_offset = calc_buffer_offset(
                session_connection.ifid,
                session_connection.connection,
                m_axi_extif0_buffer_tx_offset,
                m_axi_extif0_buffer_tx_stride,
                m_axi_extif1_buffer_tx_offset,
                m_axi_extif1_buffer_tx_stride);

            // Write transferred data from the post stage to DDR
            last_word = write_buffer(
                buff_area_offset,
                session_connection,
                burst_length,
                buffer_size_sel,
                last_word,
                egr_session_data,
                m_axi_extif0_buffer,
                m_axi_extif1_buffer,
                stat_egr_rcv_data);

            // Hold last word
            fragments[fragment_key] = last_word;

            // Update the user side pointer of the Tx buffer
            session_connection.usr = calc_sn(session_connection.usr, burst_length);
            extifCommand cmd(
                static_cast<command_t>(extifCommandStatus::SEND),
                session_connection.connection, session_connection.usr);
            // Notify updated pointer to external IF
            if (session_connection.ifid == 0)
            {
                if (insert_command_fault_0(0, 0))
                    cmd.cid = insert_command_fault_0(31, 16);

                egr_cmd_0.write(cmd);
            }
            else
            {
                if (insert_command_fault_1(0, 0))
                    cmd.cid = insert_command_fault_1(31, 16);

                egr_cmd_1.write(cmd);
            }
        }

        if (session_connection.eof)
            // End of frame notification (for Busy count)
            egr_frame_end.write(session_connection.channel);

        // End of latency measurement
        egr_meas_end.write(session_connection);

        // Debug register
        dbg_cmd_snd_cid_reg = static_cast<axilite_data_t>(session_connection.connection);
        dbg_cmd_usr_wrt_reg = static_cast<axilite_data_t>(session_connection.usr);
    }

    dbg_cmd_snd_cid = dbg_cmd_snd_cid_reg;
    dbg_cmd_usr_wrt = dbg_cmd_usr_wrt_reg;
}
