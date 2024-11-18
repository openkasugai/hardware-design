/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#pragma once

#include <stdint.h>
#include <iostream>
#include <fstream>
#include <iomanip>
#include <limits>
#include <hls_stream.h>
#if 0
#include <hls_vector.h>
#endif
#include "ap_int.h"

// ceil(a/b)
#define CDIV(a, b) (((a) + (b)-1) / (b))

// ceil(a/b)*b
#define CEIL(a, b) (CDIV((a), (b)) * (b))

// min, max
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#define MAX(a, b) ((a) > (b) ? (a) : (b))

// abs
#define ABS(a) ((a) < 0 ? (-(a)) : (a))

using length_t = uint32_t;
using channel_t = uint16_t;
using event_t = uint16_t;
using command_t = uint16_t;
using connection_t = uint16_t;
using ptr_table_key_t = uint16_t;
using ifid_t = uint8_t;
using ptr_t = uint32_t;
using sn_widen_t = uint64_t;
using length_widen_t = uint64_t;
using address_t = uint64_t;

using axilite_data_t = uint32_t;

// External IF ID bit width
static constexpr int IFID_WIDTH = 1;

// Connection ID bit width
static constexpr int CONNECTION_WIDTH = 9;

// Pointer table key bit width
static constexpr int PTR_TABLE_KEY_WIDTH = IFID_WIDTH + CONNECTION_WIDTH;

// Channel ID bit width
static constexpr int CHANNEL_WIDTH = 9;

// header buffer pointer bit width
static constexpr int HDR_BUFF_PTR_WIDTH = 3;

// Maximum number of connections per external IF
static constexpr int MAX_NUM_CONNECTIONS = 1 << CONNECTION_WIDTH;

// Maximum number of channels
static constexpr int MAX_NUM_CHANNELS = 1 << CHANNEL_WIDTH;

// Header buffer depth per channel
static constexpr int HDR_BUFF_DEPTH_PER_CHANNEL = 1 << HDR_BUFF_PTR_WIDTH;

// Pointer table depth
static constexpr int PTR_TABLE_DEPTH = 1 << PTR_TABLE_KEY_WIDTH;

// Bitmask for the external IF ID
static constexpr ifid_t IFID_MASK = (1 << IFID_WIDTH) - 1;

// Bitmask for the connection ID
static constexpr connection_t CONNECTION_MASK = (1 << CONNECTION_WIDTH) - 1;

// Bitmask for channel ID
static constexpr channel_t CHANNEL_MASK = (1 << CHANNEL_WIDTH) - 1;

// Maximum number of bytes of data Inter-block transfer
static constexpr size_t MAX_BURST_LENGTH = 32 * 1024;

// Inter-block transfer data bus bit width
static constexpr int TRANS_DATA_WIDTH_BITS = 512;

// Inter-block transfer data bus byte width
static constexpr int TRANS_DATA_WIDTH_BYTES = TRANS_DATA_WIDTH_BITS / 8;

// Type for inter-block transfer data
using session_data_t = ap_uint<TRANS_DATA_WIDTH_BITS>;

// Bit field definition for protocol monitoring error
static constexpr int PROTOCOL_FAULT_RESP_CHANNEL_EQ_REQ = 0;
static constexpr int PROTOCOL_FAULT_RESP_BURST_LENGTH_LE_REQ = 1;
static constexpr int PROTOCOL_FAULT_RESP_SOF_EQ_REQ = 2;
static constexpr int PROTOCOL_FAULT_RESP_EOF_EQ_REQ = 3;
static constexpr int PROTOCOL_FAULT_RESP_TRANS_CW_REQ = 4;
static constexpr int PROTOCOL_FAULT_DATA_TRANS_CW_RESP = 5;
static constexpr int PROTOCOL_FAULT_REQ_OUTSTANDING = 6;
static constexpr int PROTOCOL_FAULT_RESP_OUTSTANDING = 7;
// static constexpr int PROTOCOL_FAULT_DATA_OUTSTANDING = 8;
static constexpr int PROTOCOL_FAULT_REQ_MAX_BURST_LENGTH = 8;
static constexpr int PROTOCOL_FAULT_REQ_BURST_LENGTH_NZ = 12;
static constexpr int PROTOCOL_FAULT_RESP_BURST_LENGTH_EQ_REQ = 13;

// Protocol monitoring error bit field definition (conversion_adaptor ingress)
static constexpr int INGR_PROTOCOL_FAULT_CHANNEL_EQ_REQ = 0;
static constexpr int INGR_PROTOCOL_FAULT_BURST_LENGTH_LE_REQ = 1;
static constexpr int INGR_PROTOCOL_FAULT_SOF_EQ_REQ = 2;
static constexpr int INGR_PROTOCOL_FAULT_EOF_EQ_REQ = 3;
static constexpr int INGR_PROTOCOL_FAULT_BURST_LENGTH_EQ_REQ = 4;
static constexpr int INGR_PROTOCOL_FAULT_MAX_BURST_LENGTH_0 = 5;
static constexpr int INGR_PROTOCOL_FAULT_MAX_BURST_LENGTH_1 = 6;
static constexpr int INGR_PROTOCOL_FAULT_BURST_LENGTH_NZ_0 = 7;
static constexpr int INGR_PROTOCOL_FAULT_BURST_LENGTH_NZ_1 = 8;

// Protocol monitoring error bit field definition (conversion_adaptor egress)
static constexpr int EGR_PROTOCOL_FAULT_CHANNEL_EQ_REQ_0 = 0;
static constexpr int EGR_PROTOCOL_FAULT_CHANNEL_EQ_REQ_1 = 1;
static constexpr int EGR_PROTOCOL_FAULT_BURST_LENGTH_LE_REQ_0 = 2;
static constexpr int EGR_PROTOCOL_FAULT_BURST_LENGTH_LE_REQ_ = 3;
static constexpr int EGR_PROTOCOL_FAULT_SOF_EQ_REQ_0 = 4;
static constexpr int EGR_PROTOCOL_FAULT_SOF_EQ_REQ_1 = 5;
static constexpr int EGR_PROTOCOL_FAULT_EOF_EQ_REQ_0 = 6;
static constexpr int EGR_PROTOCOL_FAULT_EOF_EQ_REQ_1 = 7;
static constexpr int EGR_PROTOCOL_FAULT_MAX_BURST_LENGTH_0 = 8;
static constexpr int EGR_PROTOCOL_FAULT_MAX_BURST_LENGTH_1 = 9;
static constexpr int EGR_PROTOCOL_FAULT_TRANS_CW_RESP = 10;
static constexpr int EGR_PROTOCOL_FAULT_BURST_LENGTH_NZ = 11;

// External IF event code
enum class extifEventStatus : event_t
{
    ESTABLISHED = 0x1,
    CLOSE_WAIT = 0x2,
    ERASED = 0x4,
    SYN_TIMEOUT = 0x8,
    SYN_ACK_TIMEOUT = 0x10,
    TIMEOUT = 0x20,
    RECV_DATA = 0x40,
    SEND_DATA = 0x80,
    RECV_URGENT_DATA = 0x100,
    RECV_RST = 0x200
};

// External IF command code
enum class extifCommandStatus : command_t
{
    SEND = 0,
    RECEIVE = 1
};

// Structure for external IF event
struct extifEvent
{
    ptr_t rcv_nxt;            // [31:0]
    ptr_t snd_una;            // [63:32]
    event_t event;            // [79:64]
    connection_t cid;         // [95:80]
    axilite_data_t rxtx_base; // [127:96]
    extifEvent() {}
    extifEvent(axilite_data_t rxtx_base, connection_t cid, event_t event, ptr_t snd_una, ptr_t rcv_nxt)
        : rcv_nxt(rcv_nxt), snd_una(snd_una), event(event), cid(cid), rxtx_base(rxtx_base) {}
} __attribute__((packed));

// Structure for external IF command
struct extifCommand
{
    ptr_t usr_ptr;     // [31:0]
    connection_t cid;  // [47:32]
    command_t command; // [63:48]
    extifCommand() {}
    extifCommand(command_t command, connection_t cid, ptr_t usr_ptr)
        : usr_ptr(usr_ptr), cid(cid), command(command) {}
} __attribute__((packed));

// Structure for Inter-block req/resp
struct sessionReq
{
    length_t frame_length : 32;        // [31:0]
    channel_t channel : CHANNEL_WIDTH; // [40:32]
    uint8_t sof : 1;                   // [41]
    uint8_t eof : 1;                   // [42]
    uint8_t direct : 1;                // [43]
    uint8_t reserved : 4;              // [47:44]
    length_t burst_length : 16;        // [63:48]
    sessionReq() {}
    sessionReq(channel_t channel, uint16_t burst_length, uint8_t sof, uint8_t eof, uint8_t direct, uint32_t frame_length)
        : burst_length(burst_length), channel(channel), sof(sof), eof(eof), direct(direct), frame_length(frame_length), reserved(0) {}
} __attribute__((packed));

// Structure used to report the amount of data transferred per cycle along with the connection number
struct sessionCycleDataCount
{
    connection_t connection : CONNECTION_WIDTH;               // [8:0]
    ifid_t ifid : IFID_WIDTH;                                 // [9]
    uint16_t reserved : (16 - CONNECTION_WIDTH - IFID_WIDTH); // [15:10]
    uint8_t count;                                            // [23:16]
    sessionCycleDataCount(ifid_t ifid, connection_t connection, uint8_t count)
        : connection(connection), ifid(ifid), reserved(0), count(count) {}
} __attribute__((packed));

// Structure to report the amount of data transferred per cycle along with the channel number
struct channelCycleDataCount
{
    channel_t channel : CHANNEL_WIDTH;                     // [8:0]
    ifid_t ifid : IFID_WIDTH;                              // [9]
    uint16_t reserved : (16 - CHANNEL_WIDTH - IFID_WIDTH); // [15:10]
    uint8_t count;                                         // [23:16]
    channelCycleDataCount(ifid_t ifid, channel_t channel, uint8_t count)
        : channel(channel), ifid(ifid), reserved(0), count(count) {}
} __attribute__((packed));

// Structure for reporting burst transfer volume with connection number
// Since a 4 byte field cannot span a 2 byte boundary, split it into count_l and count_h.
struct sessionBurstDataCount
{
    channel_t connection : CONNECTION_WIDTH;                  // [0:8]
    ifid_t ifid : IFID_WIDTH;                                 // [9]
    uint16_t reserved : (16 - CONNECTION_WIDTH - IFID_WIDTH); // [15:10]
    uint16_t count_l;                                         // [31:16]
    uint16_t count_h;                                         // [47:32]
    sessionBurstDataCount(ifid_t ifid, connection_t connection, length_t count)
        : connection(connection), ifid(ifid), reserved(0),
          count_l(count & 0xffff), count_h((count >> 16) & 0xffff) {}
} __attribute__((packed));

// Structure for reporting burst transfer volume with channel number
// Since a 4 byte field cannot span a 2 byte boundary, split it into count_l and count_h.
struct channelBurstDataCount
{
    channel_t channel : CHANNEL_WIDTH;                     // [0:8]
    ifid_t ifid : IFID_WIDTH;                              // [9]
    uint16_t reserved : (16 - CHANNEL_WIDTH - IFID_WIDTH); // [15:10]
    uint16_t count_l;                                      // [31:16]
    uint16_t count_h;                                      // [47:32]
    channelBurstDataCount(ifid_t ifid, channel_t channel, length_t count)
        : channel(channel), ifid(ifid), reserved(0),
          count_l(count & 0xffff), count_h((count >> 16) & 0xffff) {}
} __attribute__((packed));

// Structure to signal frame forwarding with channel number
struct channelFrameCount
{
    channel_t channel : CHANNEL_WIDTH;                     // [8:0]
    ifid_t ifid : IFID_WIDTH;                              // [9]
    uint16_t reserved : (16 - CHANNEL_WIDTH - IFID_WIDTH); // [15:10]
    channelFrameCount(ifid_t ifid, channel_t channel)
        : channel(channel), ifid(ifid), reserved(0) {}
} __attribute__((packed));
