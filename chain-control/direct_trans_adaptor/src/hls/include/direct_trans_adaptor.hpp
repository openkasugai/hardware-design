/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#pragma once

#include "chain_control.hpp"

#define DTA_MODULE_ID (0x0000F3C0)
#ifndef DTA_LOCAL_VERSION
#define DTA_LOCAL_VERSION (0xDEADBEEF)
#endif

static constexpr int INGR_OUTSTANDING_NUM = 1;
static constexpr int EGR_OUTSTANDING_NUM = 2;

// Structure for protocol violation detection
struct faultProtocol
{
    uint8_t channel_eq : 1;       // [0]
    uint8_t burst_length_le : 1;  // [1]
    uint8_t sof_eq : 1;           // [2]
    uint8_t eof_eq : 1;           // [3]
    uint8_t resp_trans_cw : 1;    // [4]
    uint8_t data_trans_cw : 1;    // [5]
    uint8_t req_outstanding : 1;  // [6]
    uint8_t resp_outstanding : 1; // [7]
    uint8_t max_burst_length : 1; // [8]
    uint8_t data_outstanding : 1; // [9]
    uint8_t reserved : 2;         // [11:10]
    uint8_t burst_length_nz : 1;  // [12]
    uint8_t burst_length_eq : 1;  // [13]
    faultProtocol() {}
} __attribute__((packed));
