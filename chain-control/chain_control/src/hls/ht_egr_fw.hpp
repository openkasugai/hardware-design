/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#pragma once

#include "fw_table.hpp"

struct egrFwValue
{
    connection_t connection : CONNECTION_WIDTH; // [8:0]
    ifid_t ifid : IFID_WIDTH;                   // [9]
    uint8_t enable : 1;                         // [10]
    uint8_t active : 1;                         // [11]
    uint8_t virt : 1;                           // [12]
    uint8_t blocking : 1;                       // [13]
    uint8_t parity : 1;                         // [14]

    ap_uint<1> calc_parity()
    {
        return ((ap_uint<CONNECTION_WIDTH>)connection).xor_reduce() ^
               enable ^ active ^ virt ^ blocking;
    }

    void update_parity()
    {
        parity = calc_parity();
    }

    bool parity_ok()
    {
        return calc_parity() == parity;
    }
} __attribute__((packed));

struct egrFwLookupReq
{
    channel_t key : CHANNEL_WIDTH;
    uint8_t sof : 1;
    uint8_t eof : 1;
    egrFwLookupReq() {}
    egrFwLookupReq(channel_t key, uint8_t sof, uint8_t eof)
        : key(key), sof(sof), eof(eof) {}
} __attribute__((packed));

struct egrFwLookupResp
{
    channel_t key : CHANNEL_WIDTH;
    egrFwValue value;
} __attribute__((packed));

struct egrFwUpdateReq
{
    tableOp op;
    channel_t key : CHANNEL_WIDTH;
    egrFwValue value;
    egrFwUpdateReq() {}
    egrFwUpdateReq(tableOp op, channel_t key, egrFwValue value)
        : op(op), key(key), value(value) {}
} __attribute__((packed));

struct egrFwUpdateResp
{
    tableOp op;
    channel_t key : CHANNEL_WIDTH;
    egrFwValue value;
    uint8_t success : 1;
} __attribute__((packed));
