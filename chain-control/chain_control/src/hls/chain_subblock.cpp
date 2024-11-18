/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "chain_subblock.hpp"

// ext precedes usr
length_t calc_length_bytes(ptr_t ext, ptr_t usr)
{
    length_widen_t length;
    if (ext >= usr)
    {
        length = ext - usr;
    }
    else
    {
        length = 0x100000000 - (usr - ext);
    }
    return static_cast<length_t>(length);
}

length_t calc_remain_bytes(ptr_t ext, ptr_t usr, length_t buffer_bytes)
{
    length_t remain;
    length_t length = calc_length_bytes(usr, ext); // Argument reversed because usr precedes ext
    // Decrease the free space by 1 word so that the Tx buffer pointer does not point to the same word.
    // This eliminates the need for read-modify-write.
    if (length > (buffer_bytes - BUFFER_WIDTH_BYTES))
    {
        remain = 0;
    }
    else
    {
        remain = (buffer_bytes - BUFFER_WIDTH_BYTES) - length;
    }
    return remain;
}

ptr_t calc_sn(ptr_t sn, length_t length)
{
    sn_widen_t next = sn + length;
    if (next >= 0x100000000)
    {
        next = next - 0x100000000;
    }
    else
    {
        next = next;
    }
    return static_cast<ptr_t>(next);
}

address_t calc_buffer_offset(ifid_t ifid,
                             connection_t channel,
                             address_t extif0_buffer_offset,
                             length_t extif0_buffer_stride,
                             address_t extif1_buffer_offset,
                             length_t extif1_buffer_stride)
{
    address_t buffer_offset;
    length_t buffer_stride;
    if (ifid == 0)
    {
        buffer_offset = extif0_buffer_offset;
        buffer_stride = extif0_buffer_stride;
    }
    else
    {
        buffer_offset = extif1_buffer_offset;
        buffer_stride = extif1_buffer_stride;
    }
    return buffer_offset + buffer_stride * channel;
}

length_t calc_buffer_size(uint8_t buffer_size_sel)
{
    constexpr length_t STEP = 1024;
    if (buffer_size_sel < BUFFER_SIZE_SEL_MIN)
        return STEP << BUFFER_SIZE_SEL_MIN;
    if (buffer_size_sel > BUFFER_SIZE_SEL_MAX)
        return STEP << BUFFER_SIZE_SEL_MAX;
    return STEP << buffer_size_sel;
}
