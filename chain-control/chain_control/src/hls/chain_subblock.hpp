/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#pragma once

#include "chain_control.hpp"
#include "ht_ingr_fw.hpp"
#include "ht_egr_fw.hpp"

#define CSC_MODULE_ID (0x0000F0C0)
#ifndef CSC_LOCAL_VERSION
#define CSC_LOCAL_VERSION (0xDEADBEEF)
#endif

static constexpr uint8_t BUFFER_SIZE_SEL_MIN = 6;
static constexpr uint8_t BUFFER_SIZE_SEL_MAX = 15;

const int BUFFER_WIDTH_BITS = TRANS_DATA_WIDTH_BITS;
const int BUFFER_WIDTH_BYTES = BUFFER_WIDTH_BITS / 8;

static constexpr length_t HDR_LENGTH = 48;
static constexpr length_t HDR_FIELD_OFFSET_MARKER = 0;
static constexpr length_t HDR_FIELD_OFFSET_PAY_LEN = 4;
static constexpr length_t HDR_FIELD_OFFSET_SEQ_NO = 12;
static constexpr uint32_t HDR_MARKER = 0xe0ff10ad;

// alias for bus
using buffer_data_t = ap_uint<BUFFER_WIDTH_BITS>;
using header_data_t = ap_uint<8 * HDR_LENGTH>;

static constexpr int FW_TABLE_REG_FLAG_ENABLE = 16;
static constexpr int FW_TABLE_REG_FLAG_ACTIVE = 17;
static constexpr int FW_TABLE_REG_FLAG_DIRECT = 18;
static constexpr int FW_TABLE_REG_FLAG_VIRTUAL = 19;
static constexpr int FW_TABLE_REG_FLAG_BLOCKING = 20;

struct ptrUpdateReq
{
    uint8_t source;                                         // [7:0]
    tableOp op : 8;                                         // [15:8]
    channel_t connection : CHANNEL_WIDTH;                   // [24:16]
    ifid_t ifid : IFID_WIDTH;                               // [25]
    uint16_t reserved0 : (16 - CHANNEL_WIDTH - IFID_WIDTH); // [31:26]
    ptr_t ptr;                                              // [63:32]
    ptrUpdateReq() {}
    ptrUpdateReq(tableOp op, ifid_t ifid, channel_t connection, ptr_t ptr, uint8_t source)
        : source(source), op(op), connection(connection), ifid(ifid), ptr(ptr) {}
};

struct headerSeq
{
    channel_t channel : CHANNEL_WIDTH;         // [8:0]
    uint16_t reserved0 : (16 - CHANNEL_WIDTH); // [15:9]
    uint16_t discard : 1;                      // [16]
    uint16_t reserved1 : (16 - 1);             // [31:17]
    uint32_t seq_no : 32;                      // [63:32]
} __attribute__((packed));

struct headerPayloadLen
{
    length_t length;            // [31:0]
    uint8_t discard : 1;        // [32]
    uint8_t reserved : (8 - 1); // [39:33]
} __attribute__((packed));

struct headerInsReq
{
    length_t burst_length; // [31:0]
    length_t payload_len;  // [63:32]
    headerInsReq() {}
    headerInsReq(length_t burst_length, length_t payload_len)
        : burst_length(burst_length), payload_len(payload_len) {}
} __attribute__((packed));

struct headerBuffUsage
{
    channel_t connection : CONNECTION_WIDTH;                   // [8:0]
    ifid_t ifid : IFID_WIDTH;                                  // [9]
    uint16_t reserved0 : (16 - CONNECTION_WIDTH - IFID_WIDTH); // [15:10]
    channel_t channel : CHANNEL_WIDTH;                         // [24:16]
    uint8_t reserved1 : (16 - CHANNEL_WIDTH);                  // [31:25]
    uint8_t usage;                                             // [39:32]
    uint8_t bp : 1;                                            // [40]
    uint8_t reserved2 : 7;                                     // [47:41]
} __attribute__((packed));

struct sessionForward
{
    connection_t connection : CONNECTION_WIDTH;               // [8:0]
    ifid_t ifid : IFID_WIDTH;                                 // [9]
    uint8_t reserved0 : (16 - CONNECTION_WIDTH - IFID_WIDTH); // [15:10]
    channel_t channel : CHANNEL_WIDTH;                        // [24:16]
    uint8_t reserved1 : (16 - CHANNEL_WIDTH);                 // [31:25]
    length_t frame_length;                                    // [63:32]
    length_t burst_length : 16;                               // [79:64]
    uint8_t sof : 1;                                          // [80]
    uint8_t eof : 1;                                          // [81]
    uint8_t discard : 1;                                      // [82]
    uint8_t blocking : 1;                                     // [83]
    uint8_t reserved2 : 4;                                    // [87:84]
    sessionForward() {}
    sessionForward(ifid_t ifid, connection_t connection, channel_t channel,
                   length_t burst_length, length_t payload_len,
                   uint8_t sof, uint8_t eof, uint8_t discard, uint8_t blocking)
        : ifid(ifid), connection(connection), channel(channel),
          burst_length(burst_length), frame_length(payload_len),
          sof(sof), eof(eof), discard(discard), blocking(blocking) {}
} __attribute__((packed));

struct sessionPtr
{
    connection_t connection : CONNECTION_WIDTH;               // [8:0]
    ifid_t ifid : IFID_WIDTH;                                 // [9]
    uint8_t reserved0 : (16 - CONNECTION_WIDTH - IFID_WIDTH); // [15:10]
    channel_t channel : CHANNEL_WIDTH;                        // [24:16]
    uint8_t reserved1 : (16 - CHANNEL_WIDTH);                 // [31:25]
    ptr_t ext;                                                // [63:32]
    ptr_t usr;                                                // [95:64]
    length_t payload_len;                                     // [127:96]
    uint8_t head : 1;                                         // [128]
    uint8_t sof : 1;                                          // [129]
    uint8_t eof : 1;                                          // [130]
    uint8_t discard : 1;                                      // [131]
    uint8_t direct : 1;                                       // [132]
    uint8_t reserved2 : 3;                                    // [135:133]
    sessionPtr() {}
    sessionPtr(ifid_t ifid, connection_t connection, channel_t channel, ptr_t ext, ptr_t usr, uint32_t payload_len,
               uint8_t head, uint8_t sof, uint8_t eof, uint8_t discard, uint8_t direct)
        : ifid(ifid), connection(connection), channel(channel), ext(ext), usr(usr), payload_len(payload_len),
          head(head), sof(sof), eof(eof), discard(discard), direct(direct) {}
    sessionPtr(sessionForward fwd, ptr_t ext, ptr_t usr)
        : ifid(fwd.ifid), connection(fwd.connection), channel(fwd.channel), ext(ext), usr(usr), payload_len(fwd.frame_length),
          head(0), sof(fwd.sof), eof(fwd.eof), discard(fwd.discard), direct(0) {}

} __attribute__((packed));

struct sessionLastPtr
{
    ptr_t wr_ptr;                                            // [31:0]
    ptr_t rd_ptr;                                            // [63:32]
    connection_t connection : CONNECTION_WIDTH;              // [72:64]
    ifid_t ifid : IFID_WIDTH;                                // [73]
    uint8_t reserved : (16 - CONNECTION_WIDTH - IFID_WIDTH); // [79:74]
} __attribute__((packed));

struct channelBusyCount
{
    channel_t channel : CHANNEL_WIDTH;       // [8:0]
    uint8_t reserved : (16 - CHANNEL_WIDTH); // [15:9]
    uint8_t busy_count;                      // [23:16]
    channelBusyCount(channel_t channel, uint8_t busy_count)
        : channel(channel), reserved(0), busy_count(busy_count) {}
} __attribute__((packed));

length_t calc_length_bytes(ptr_t sn, ptr_t usr);
length_t calc_remain_bytes(ptr_t sn, ptr_t usr, length_t buffer_bytes);
ptr_t calc_sn(ptr_t sn, length_t length);
address_t calc_buffer_offset(ifid_t ifid,
                             connection_t channel,
                             address_t extif0_buffer_offset,
                             length_t extif0_buffer_stride,
                             address_t extif1_buffer_offset,
                             length_t extif1_buffer_stride);
length_t calc_buffer_size(uint8_t buffer_size_sel);
