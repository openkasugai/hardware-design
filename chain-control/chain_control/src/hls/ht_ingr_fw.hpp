/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#pragma once

#include "fw_table.hpp"

union ingrFwKey
{
    uint16_t packed;
    struct
    {
        connection_t connection : CONNECTION_WIDTH;
        ifid_t ifid : IFID_WIDTH;
    } __attribute__((packed));
};

struct ingrFwValue
{
    channel_t channel : CHANNEL_WIDTH;
    uint8_t enable : 1;
    uint8_t active : 1;
    uint8_t direct : 1;
    uint8_t parity : 1;

    ap_uint<1> calc_parity()
    {
        return ((ap_uint<CHANNEL_WIDTH>)channel).xor_reduce() ^
               enable ^ active ^ direct;
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

struct ingrFwLookupReq
{
    ingrFwKey key;
    uint8_t head : 1;
    uint8_t eof : 1;
    ingrFwLookupReq() {}
    ingrFwLookupReq(ingrFwKey key, uint8_t head, uint8_t eof)
        : key(key), head(head), eof(eof) {}
};

struct ingrFwLookupResp
{
    ingrFwKey key;
    ingrFwValue value;
};

struct ingrFwUpdateReq
{
    tableOp op;
    ingrFwKey key;
    ingrFwValue value;
    ingrFwUpdateReq() {}
    ingrFwUpdateReq(tableOp op, ingrFwKey key, ingrFwValue value)
        : op(op), key(key), value(value) {}
};

struct ingrFwUpdateResp
{
    tableOp op;
    ingrFwKey key;
    ingrFwValue value;
    uint8_t success : 1;
} __attribute__((packed));
