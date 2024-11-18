/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

`timescale 1ns/1ps
module chain_control_control_s_axi #(
  parameter integer C_S_AXI_ADDR_WIDTH = 12,
  parameter integer C_S_AXI_DATA_WIDTH = 32
) (
  input   wire                            ACLK                      ,
  input   wire                            ARESET_N                  ,
  input   wire[C_S_AXI_ADDR_WIDTH-1:0]    AWADDR                    ,
  input   wire                            AWVALID                   ,
  output  wire                            AWREADY                   ,
  input   wire[C_S_AXI_DATA_WIDTH-1:0]    WDATA                     ,
  input   wire[C_S_AXI_DATA_WIDTH/8-1:0]  WSTRB                     ,
  input   wire                            WVALID                    ,
  output  wire                            WREADY                    ,
  output  wire[1:0]                       BRESP                     ,
  output  wire                            BVALID                    ,
  input   wire                            BREADY                    ,
  input   wire[C_S_AXI_ADDR_WIDTH-1:0]    ARADDR                    ,
  input   wire                            ARVALID                   ,
  output  wire                            ARREADY                   ,
  output  wire[C_S_AXI_DATA_WIDTH-1:0]    RDATA                     ,
  output  wire[1:0]                       RRESP                     ,
  output  wire                            RVALID                    ,
  input   wire                            RREADY                    ,
  input   wire[31:0]                      module_id                 ,
  input   wire[31:0]                      local_version             ,
  output  wire                            detect_fault              ,
  input   wire                            func_latency_valid        ,
  input   wire[47:0]                      func_latency_data         ,
  input   wire                            extif0_event_fault_ap_vld ,
  input   wire[9:0]                       extif0_event_fault        ,
  input   wire                            extif1_event_fault_ap_vld ,
  input   wire[9:0]                       extif1_event_fault        ,
  input   wire[9:0]                       streamif_stall            ,
  input   wire[2047:0]                    ingr_reg_in               ,
  output  wire[1023:0]                    ingr_reg_out              ,
  input   wire[2047:0]                    egr_reg_in                ,
  output  wire[1023:0]                    egr_reg_out               
);

//------------------------Parameter----------------------

localparam integer WRIDLE   = 2'd0;
localparam integer WRDATA   = 2'd1;
localparam integer WRRESP   = 2'd2;
localparam integer WRRESET  = 2'd3;
localparam integer RDIDLE   = 2'd0;
localparam integer RDWAIT   = 2'd1;
localparam integer RDDATA   = 2'd2;
localparam integer RDRESET  = 2'd3;

localparam integer ADDR_BITS = C_S_AXI_ADDR_WIDTH;

localparam[ADDR_BITS-1:0] ADDR_CONTROL                                = 12'h000; // W
localparam[ADDR_BITS-1:0] ADDR_MODULE_ID                              = 12'h010; // R
localparam[ADDR_BITS-1:0] ADDR_LOCAL_VERSION                          = 12'h020; // R
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF0_BUFFER_BASE_L             = 12'h100; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF0_BUFFER_BASE_H             = 12'h104; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF0_BUFFER_RX_OFFSET_L        = 12'h110; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF0_BUFFER_RX_OFFSET_H        = 12'h114; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF0_BUFFER_RX_STRIDE          = 12'h118; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF0_BUFFER_RX_SIZE            = 12'h11C; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF0_BUFFER_TX_OFFSET_L        = 12'h120; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF0_BUFFER_TX_OFFSET_H        = 12'h124; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF0_BUFFER_TX_STRIDE          = 12'h128; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF0_BUFFER_TX_SIZE            = 12'h12C; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF1_BUFFER_BASE_L             = 12'h140; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF1_BUFFER_BASE_H             = 12'h144; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF1_BUFFER_RX_OFFSET_L        = 12'h150; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF1_BUFFER_RX_OFFSET_H        = 12'h154; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF1_BUFFER_RX_STRIDE          = 12'h158; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF1_BUFFER_RX_SIZE            = 12'h15C; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF1_BUFFER_TX_OFFSET_L        = 12'h160; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF1_BUFFER_TX_OFFSET_H        = 12'h164; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF1_BUFFER_TX_STRIDE          = 12'h168; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_EXTIF1_BUFFER_TX_SIZE            = 12'h16C; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_FORWARD_UPDATE_REQ                = 12'h200; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_FORWARD_UPDATE_RESP               = 12'h204; // R
localparam[ADDR_BITS-1:0] ADDR_INGR_FORWARD_SESSION                   = 12'h208; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_FORWARD_CHANNEL                   = 12'h20C; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_FORWARD_UPDATE_REQ                 = 12'h220; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_FORWARD_UPDATE_RESP                = 12'h224; // R
localparam[ADDR_BITS-1:0] ADDR_EGR_FORWARD_CHANNEL                    = 12'h228; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_FORWARD_SESSION                    = 12'h22C; // R/W
localparam[ADDR_BITS-1:0] ADDR_STAT_SEL_SESSION                       = 12'h300; // R/W
localparam[ADDR_BITS-1:0] ADDR_STAT_SEL_CHANNEL                       = 12'h308; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_LATENCY_0_VALUE                   = 12'h320; // R
localparam[ADDR_BITS-1:0] ADDR_INGR_LATENCY_1_VALUE                   = 12'h324; // R
localparam[ADDR_BITS-1:0] ADDR_EGR_LATENCY_0_VALUE                    = 12'h328; // R
localparam[ADDR_BITS-1:0] ADDR_EGR_LATENCY_1_VALUE                    = 12'h32C; // R
localparam[ADDR_BITS-1:0] ADDR_FUNC_LATENCY_VALUE                     = 12'h330; // R
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_DATA_0_VALUE_L           = 12'h340; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_DATA_0_VALUE_H           = 12'h344; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_DATA_1_VALUE_L           = 12'h348; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_DATA_1_VALUE_H           = 12'h34C; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_SND_DATA_0_VALUE_L           = 12'h350; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_SND_DATA_0_VALUE_H           = 12'h354; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_SND_DATA_1_VALUE_L           = 12'h358; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_SND_DATA_1_VALUE_H           = 12'h35C; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_RCV_DATA_0_VALUE_L            = 12'h360; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_RCV_DATA_0_VALUE_H            = 12'h364; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_RCV_DATA_1_VALUE_L            = 12'h368; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_RCV_DATA_1_VALUE_H            = 12'h36C; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_SND_DATA_0_VALUE_L            = 12'h370; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_SND_DATA_0_VALUE_H            = 12'h374; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_SND_DATA_1_VALUE_L            = 12'h378; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_SND_DATA_1_VALUE_H            = 12'h37C; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_SND_FRAME_0_VALUE            = 12'h380; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_SND_FRAME_1_VALUE            = 12'h384; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_RCV_FRAME_0_VALUE             = 12'h388; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_RCV_FRAME_1_VALUE             = 12'h38C; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_DISCARD_DATA_0_VALUE_L       = 12'h3A0; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_DISCARD_DATA_0_VALUE_H       = 12'h3A4; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_DISCARD_DATA_1_VALUE_L       = 12'h3A8; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_DISCARD_DATA_1_VALUE_H       = 12'h3AC; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_DISCARD_DATA_0_VALUE_L        = 12'h3B0; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_DISCARD_DATA_0_VALUE_H        = 12'h3B4; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_DISCARD_DATA_1_VALUE_L        = 12'h3B8; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_DISCARD_DATA_1_VALUE_H        = 12'h3BC; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_HEADER_BUFF_STORED                = 12'h400; // R
localparam[ADDR_BITS-1:0] ADDR_STAT_HEADER_BUFF_BP                    = 12'h404; // R/WC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_BUSY                          = 12'h40C; // R
localparam[ADDR_BITS-1:0] ADDR_STAT_SESSION_ENABLE_0                  = 12'h410; // R
localparam[ADDR_BITS-1:0] ADDR_STAT_SESSION_ENABLE_1                  = 12'h414; // R
localparam[ADDR_BITS-1:0] ADDR_DETECT_FAULT                           = 12'h500; // R
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_DETECT_FAULT_0_VALUE          = 12'h510; // RC
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_DETECT_FAULT_0_MASK           = 12'h518; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_DETECT_FAULT_0_FORCE          = 12'h51C; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_DETECT_FAULT_1_VALUE          = 12'h520; // RC
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_DETECT_FAULT_1_MASK           = 12'h528; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_DETECT_FAULT_1_FORCE          = 12'h52C; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_DETECT_FAULT_0_VALUE          = 12'h530; // RC
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_DETECT_FAULT_0_MASK           = 12'h538; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_DETECT_FAULT_0_FORCE          = 12'h53C; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_DETECT_FAULT_1_VALUE          = 12'h540; // RC
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_DETECT_FAULT_1_MASK           = 12'h548; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_DETECT_FAULT_1_FORCE          = 12'h54C; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_RCV_DETECT_FAULT_VALUE             = 12'h550; // RC
localparam[ADDR_BITS-1:0] ADDR_EGR_RCV_DETECT_FAULT_MASK              = 12'h558; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_RCV_DETECT_FAULT_FORCE             = 12'h55C; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_DETECT_FAULT_0_VALUE           = 12'h560; // RC
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_DETECT_FAULT_0_MASK            = 12'h568; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_DETECT_FAULT_0_FORCE           = 12'h56C; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_DETECT_FAULT_1_VALUE           = 12'h570; // RC
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_DETECT_FAULT_1_MASK            = 12'h578; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_DETECT_FAULT_1_FORCE           = 12'h57C; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_PROTOCOL_FAULT                = 12'h580; // R/WC
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_PROTOCOL_FAULT_MASK           = 12'h588; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_PROTOCOL_FAULT_FORCE          = 12'h58C; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_RCV_PROTOCOL_FAULT                 = 12'h590; // R/WC
localparam[ADDR_BITS-1:0] ADDR_EGR_RCV_PROTOCOL_FAULT_MASK            = 12'h598; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_RCV_PROTOCOL_FAULT_FORCE           = 12'h59C; // R/W
localparam[ADDR_BITS-1:0] ADDR_EXTIF0_EVENT_FAULT                     = 12'h5A0; // R/WC
localparam[ADDR_BITS-1:0] ADDR_EXTIF0_EVENT_FAULT_MASK                = 12'h5A8; // R/W
localparam[ADDR_BITS-1:0] ADDR_EXTIF0_EVENT_FAULT_FORCE               = 12'h5AC; // R/W
localparam[ADDR_BITS-1:0] ADDR_EXTIF1_EVENT_FAULT                     = 12'h5B0; // R/WC
localparam[ADDR_BITS-1:0] ADDR_EXTIF1_EVENT_FAULT_MASK                = 12'h5B8; // R/W
localparam[ADDR_BITS-1:0] ADDR_EXTIF1_EVENT_FAULT_FORCE               = 12'h5BC; // R/W
localparam[ADDR_BITS-1:0] ADDR_STREAMIF_STALL                         = 12'h5C0; // R
localparam[ADDR_BITS-1:0] ADDR_STREAMIF_STALL_MASK                    = 12'h5C8; // R/W
localparam[ADDR_BITS-1:0] ADDR_STREAMIF_STALL_FORCE                   = 12'h5CC; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_INSERT_FAULT_0                = 12'h600; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_INSERT_FAULT_1                = 12'h604; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_INSERT_FAULT_0                 = 12'h608; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_INSERT_FAULT_1                 = 12'h60C; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_INSERT_PROTOCOL_FAULT         = 12'h610; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_RCV_INSERT_PROTOCOL_FAULT          = 12'h614; // R/W
localparam[ADDR_BITS-1:0] ADDR_EXTIF0_INSERT_COMMAND_FAULT            = 12'h618; // R/W
localparam[ADDR_BITS-1:0] ADDR_EXTIF1_INSERT_COMMAND_FAULT            = 12'h61C; // R/W
localparam[ADDR_BITS-1:0] ADDR_RCV_NXT_UPDATE_RESP_COUNT              = 12'h700; // R
localparam[ADDR_BITS-1:0] ADDR_RCV_NXT_UPDATE_RESP_FAIL_COUNT         = 12'h704; // R
localparam[ADDR_BITS-1:0] ADDR_USR_READ_UPDATE_RESP_COUNT             = 12'h708; // R
localparam[ADDR_BITS-1:0] ADDR_USR_READ_UPDATE_RESP_FAIL_COUNT        = 12'h70C; // R
localparam[ADDR_BITS-1:0] ADDR_SND_UNA_UPDATE_RESP_COUNT              = 12'h710; // R
localparam[ADDR_BITS-1:0] ADDR_SND_UNA_UPDATE_RESP_FAIL_COUNT         = 12'h714; // R
localparam[ADDR_BITS-1:0] ADDR_USR_WRT_UPDATE_RESP_COUNT              = 12'h718; // R
localparam[ADDR_BITS-1:0] ADDR_USR_WRT_UPDATE_RESP_FAIL_COUNT         = 12'h71C; // R
localparam[ADDR_BITS-1:0] ADDR_INGR_FORWARD_UPDATE_RESP_COUNT         = 12'h720; // R
localparam[ADDR_BITS-1:0] ADDR_INGR_FORWARD_UPDATE_RESP_FAIL_COUNT    = 12'h724; // R
localparam[ADDR_BITS-1:0] ADDR_EGR_FORWARD_UPDATE_RESP_COUNT          = 12'h728; // R
localparam[ADDR_BITS-1:0] ADDR_EGR_FORWARD_UPDATE_RESP_FAIL_COUNT     = 12'h72C; // R
localparam[ADDR_BITS-1:0] ADDR_RX_HEAD_UPDATE_RESP_COUNT              = 12'h730; // R
localparam[ADDR_BITS-1:0] ADDR_RX_TAIL_UPDATE_RESP_COUNT              = 12'h734; // R
localparam[ADDR_BITS-1:0] ADDR_TX_TAIL_UPDATE_RESP_COUNT              = 12'h738; // R
localparam[ADDR_BITS-1:0] ADDR_TX_HEAD_UPDATE_RESP_COUNT              = 12'h73C; // R
localparam[ADDR_BITS-1:0] ADDR_DBG_LUP_RX_HEAD                        = 12'h740; // R
localparam[ADDR_BITS-1:0] ADDR_DBG_LUP_RX_TAIL                        = 12'h744; // R
localparam[ADDR_BITS-1:0] ADDR_DBG_LUP_TX_TAIL                        = 12'h748; // R
localparam[ADDR_BITS-1:0] ADDR_DBG_LUP_TX_HEAD                        = 12'h74C; // R
localparam[ADDR_BITS-1:0] ADDR_HR_RCV_NOTIFY                          = 12'h750; // R
localparam[ADDR_BITS-1:0] ADDR_HR_SND_REQ_HD                          = 12'h754; // R
localparam[ADDR_BITS-1:0] ADDR_HR_RCV_DATA_HD                         = 12'h758; // R
localparam[ADDR_BITS-1:0] ADDR_HR_SND_REQ_DT                          = 12'h75C; // R
localparam[ADDR_BITS-1:0] ADDR_HR_SND_NOTIFY                          = 12'h760; // R
localparam[ADDR_BITS-1:0] ADDR_HR_RCV_REQ                             = 12'h764; // R
localparam[ADDR_BITS-1:0] ADDR_HR_RCV_DATA_DT                         = 12'h768; // R
localparam[ADDR_BITS-1:0] ADDR_HR_SND_DATA                            = 12'h76C; // R
localparam[ADDR_BITS-1:0] ADDR_HR_RCV_LENGTH_SMALL                    = 12'h770; // R
localparam[ADDR_BITS-1:0] ADDR_HA_RCV_REQ                             = 12'h774; // R
localparam[ADDR_BITS-1:0] ADDR_HA_SND_RESP                            = 12'h778; // R
localparam[ADDR_BITS-1:0] ADDR_HA_SND_REQ                             = 12'h77C; // R
localparam[ADDR_BITS-1:0] ADDR_HA_RCV_RESP                            = 12'h780; // R
localparam[ADDR_BITS-1:0] ADDR_HA_RCV_DATA                            = 12'h784; // R
localparam[ADDR_BITS-1:0] ADDR_HA_SND_DATA                            = 12'h788; // R
localparam[ADDR_BITS-1:0] ADDR_HR_RCV_DATA_DT2                        = 12'h78C; // R
localparam[ADDR_BITS-1:0] ADDR_HR_RCV_DATA_HD_ERR                     = 12'h790; // R
localparam[ADDR_BITS-1:0] ADDR_DBG_SEL_SESSION                        = 12'h7A0; // R/W
localparam[ADDR_BITS-1:0] ADDR_EXTIF0_INGR_LAST_WR_PTR                = 12'h7C0; // R
localparam[ADDR_BITS-1:0] ADDR_EXTIF0_INGR_LAST_RD_PTR                = 12'h7C4; // R
localparam[ADDR_BITS-1:0] ADDR_EXTIF0_EGR_LAST_WR_PTR                 = 12'h7C8; // R
localparam[ADDR_BITS-1:0] ADDR_EXTIF0_EGR_LAST_RD_PTR                 = 12'h7CC; // R
localparam[ADDR_BITS-1:0] ADDR_EXTIF1_INGR_LAST_WR_PTR                = 12'h7D0; // R
localparam[ADDR_BITS-1:0] ADDR_EXTIF1_INGR_LAST_RD_PTR                = 12'h7D4; // R
localparam[ADDR_BITS-1:0] ADDR_EXTIF1_EGR_LAST_WR_PTR                 = 12'h7D8; // R
localparam[ADDR_BITS-1:0] ADDR_EXTIF1_EGR_LAST_RD_PTR                 = 12'h7DC; // R

localparam integer IG_FW_KEY_WIDTH = 10;
localparam integer IG_FW_VAL_WIDTH = 19;
localparam integer EG_FW_KEY_WIDTH =  9;
localparam integer EG_FW_VAL_WIDTH = 21;
localparam integer CONNECTION_WIDTH = 9;
localparam integer CHANNEL_WIDTH = 9;

localparam integer MAX_NUM_CONNECTIONS = 1 << CONNECTION_WIDTH;
localparam integer MAX_NUM_CHANNELS = 1 << CHANNEL_WIDTH;

localparam[31:0] CONNECTION_MASK = MAX_NUM_CONNECTIONS - 1;
localparam[31:0] CHANNEL_MASK = MAX_NUM_CHANNELS - 1;

// Ingress register input signal
wire[31:0] w_ingr_forward_update_resp = ingr_reg_in[31:0];
wire[31:0] w_ingr_forward_update_resp_data = ingr_reg_in[63:32];
wire[0:0] w_ingr_forward_update_resp_data_ap_vld = ingr_reg_in[64:64];
wire[0:0] w_ingr_latency_0_valid = ingr_reg_in[96:96];
wire[47:0] w_ingr_latency_0_data = ingr_reg_in[175:128];
wire[0:0] w_ingr_latency_1_valid = ingr_reg_in[192:192];
wire[47:0] w_ingr_latency_1_data = ingr_reg_in[271:224];
wire[0:0] w_stat_ingr_rcv_data_valid = ingr_reg_in[288:288];
wire[47:0] w_stat_ingr_rcv_data_data = ingr_reg_in[367:320];
wire[0:0] w_stat_ingr_snd_data_ap_vld = ingr_reg_in[384:384];
wire[23:0] w_stat_ingr_snd_data = ingr_reg_in[439:416];
wire[0:0] w_stat_ingr_snd_frame_ap_vld = ingr_reg_in[448:448];
wire[15:0] w_stat_ingr_snd_frame = ingr_reg_in[495:480];
wire[0:0] w_stat_ingr_discard_data_ap_vld = ingr_reg_in[512:512];
wire[47:0] w_stat_ingr_discard_data = ingr_reg_in[591:544];
wire[0:0] w_header_buff_usage_ap_vld = ingr_reg_in[608:608];
wire[47:0] w_header_buff_usage = ingr_reg_in[687:640];
wire[0:0] w_ingr_hdr_rmv_fault_ap_vld = ingr_reg_in[704:704];
wire[31:0] w_ingr_hdr_rmv_fault = ingr_reg_in[767:736];
wire[0:0] w_ingr_event_fault_vld = ingr_reg_in[768:768];
wire[15:0] w_ingr_event_fault = ingr_reg_in[815:800];
wire[0:0] w_ht_ingr_fw_fault_ap_vld = ingr_reg_in[832:832];
wire[15:0] w_ht_ingr_fw_fault = ingr_reg_in[879:864];
wire[0:0] w_ingr_forward_mishit_ap_vld = ingr_reg_in[896:896];
wire[15:0] w_ingr_forward_mishit = ingr_reg_in[943:928];
wire[0:0] w_ingr_snd_protocol_fault_ap_vld = ingr_reg_in[960:960];
wire[15:0] w_ingr_snd_protocol_fault = ingr_reg_in[1007:992];
wire[1:0] w_extif_session_status = ingr_reg_in[1025:1024];
wire[127:0] w_ingr_last_ptr = ingr_reg_in[1183:1056];
wire[31:0] w_rcv_nxt_update_resp_count = ingr_reg_in[1215:1184];
wire[31:0] w_usr_read_update_resp_count = ingr_reg_in[1247:1216];
wire[31:0] w_ingr_forward_update_resp_count = ingr_reg_in[1279:1248];
wire[31:0] w_ingr_forward_update_resp_fail_count = ingr_reg_in[1311:1280];
wire[31:0] w_rx_head_update_resp_count = ingr_reg_in[1343:1312];
wire[31:0] w_rx_tail_update_resp_count = ingr_reg_in[1375:1344];

// Eggress register input signal
wire[31:0] w_egr_forward_update_resp = egr_reg_in[31:0];
wire[31:0] w_egr_forward_update_resp_data = egr_reg_in[63:32];
wire[0:0] w_egr_forward_update_resp_data_ap_vld = egr_reg_in[64:64];
wire[0:0] w_egr_latency_valid = egr_reg_in[96:96];
wire[47:0] w_egr_latency_data = egr_reg_in[175:128];
wire[0:0] w_stat_egr_rcv_data_ap_vld = egr_reg_in[192:192];
wire[23:0] w_stat_egr_rcv_data = egr_reg_in[247:224];
wire[0:0] w_stat_egr_snd_data_ap_vld = egr_reg_in[256:256];
wire[47:0] w_stat_egr_snd_data = egr_reg_in[335:288];
wire[0:0] w_stat_egr_rcv_frame_ap_vld = egr_reg_in[352:352];
wire[15:0] w_stat_egr_rcv_frame = egr_reg_in[399:384];
wire[0:0] w_stat_egr_discard_data_ap_vld = egr_reg_in[416:416];
wire[23:0] w_stat_egr_discard_data = egr_reg_in[471:448];
wire[0:0] w_egr_resp_fault_ap_vld = egr_reg_in[480:480];
wire[23:0] w_egr_resp_fault = egr_reg_in[535:512];
wire[0:0] w_ht_egr_fw_fault_ap_vld = egr_reg_in[544:544];
wire[15:0] w_ht_egr_fw_fault = egr_reg_in[591:576];
wire[0:0] w_egr_forward_mishit_ap_vld = egr_reg_in[608:608];
wire[15:0] w_egr_forward_mishit = egr_reg_in[655:640];
wire[0:0] w_egr_rcv_protocol_fault_ap_vld = egr_reg_in[672:672];
wire[15:0] w_egr_rcv_protocol_fault = egr_reg_in[719:704];
wire[0:0] w_egr_last_ptr_ap_vld = egr_reg_in[736:736];
wire[79:0] w_egr_last_ptr = egr_reg_in[847:768];
wire[31:0] w_snd_una_update_resp_count = egr_reg_in[895:864];
wire[31:0] w_usr_wrt_update_resp_count = egr_reg_in[927:896];
wire[31:0] w_egr_forward_update_resp_count = egr_reg_in[959:928];
wire[31:0] w_egr_forward_update_resp_fail_count = egr_reg_in[991:960];
wire[31:0] w_tx_tail_update_resp_count = egr_reg_in[1023:992];
wire[31:0] w_tx_head_update_resp_count = egr_reg_in[1055:1024];
wire[31:0] w_dbg_lup_tx_tail = egr_reg_in[1087:1056];
wire[31:0] w_dbg_lup_tx_head = egr_reg_in[1119:1088];
wire[0:0] w_egr_busy_count_ap_vld = egr_reg_in[1120:1120];
wire[23:0] w_egr_busy_count = egr_reg_in[1175:1152];

//------------------------Local signal-------------------
reg [1:0]                     wstate = WRRESET;
reg [1:0]                     wnext;
reg [ADDR_BITS-1:0]           waddr;
wire[C_S_AXI_DATA_WIDTH-1:0]  wmask;
wire                          aw_hs;
wire                          w_hs;
reg [1:0]                     rstate = RDRESET;
reg [1:0]                     rnext;
reg [C_S_AXI_DATA_WIDTH-1:0]  rdata;
reg [C_S_AXI_DATA_WIDTH-1:0]  r_hi_word;
wire                          ar_hs;
wire[ADDR_BITS-1:0]           raddr;
// internal registers
reg       r_reg_control                             ; // R/W
reg[31:0] r_reg_m_axi_extif0_buffer_base_l          ; // R/W
reg[31:0] r_reg_m_axi_extif0_buffer_base_h          ; // R/W
reg[31:0] r_reg_m_axi_extif0_buffer_rx_offset_l     ; // R/W
reg[31:0] r_reg_m_axi_extif0_buffer_rx_offset_h     ; // R/W
reg[31:0] r_reg_m_axi_extif0_buffer_rx_stride       ; // R/W
reg[3:0]  r_reg_m_axi_extif0_buffer_rx_size         ; // R/W
reg[31:0] r_reg_m_axi_extif0_buffer_tx_offset_l     ; // R/W
reg[31:0] r_reg_m_axi_extif0_buffer_tx_offset_h     ; // R/W
reg[31:0] r_reg_m_axi_extif0_buffer_tx_stride       ; // R/W
reg[3:0]  r_reg_m_axi_extif0_buffer_tx_size         ; // R/W
reg[31:0] r_reg_m_axi_extif1_buffer_base_l          ; // R/W
reg[31:0] r_reg_m_axi_extif1_buffer_base_h          ; // R/W
reg[31:0] r_reg_m_axi_extif1_buffer_rx_offset_l     ; // R/W
reg[31:0] r_reg_m_axi_extif1_buffer_rx_offset_h     ; // R/W
reg[31:0] r_reg_m_axi_extif1_buffer_rx_stride       ; // R/W
reg[3:0]  r_reg_m_axi_extif1_buffer_rx_size         ; // R/W
reg[31:0] r_reg_m_axi_extif1_buffer_tx_offset_l     ; // R/W
reg[31:0] r_reg_m_axi_extif1_buffer_tx_offset_h     ; // R/W
reg[31:0] r_reg_m_axi_extif1_buffer_tx_stride       ; // R/W
reg[3:0]  r_reg_m_axi_extif1_buffer_tx_size         ; // R/W
reg[1:0]  r_reg_ingr_forward_update_req             ; // R/W
reg[31:0] r_reg_ingr_forward_update_resp            ; // R
reg[31:0] r_reg_ingr_forward_session                ; // R/W  [31:0]
reg[31:0] r_reg_ingr_forward_channel                ; // R/W  [31:0]
reg[1:0]  r_reg_egr_forward_update_req              ; // R/W
reg[31:0] r_reg_egr_forward_update_resp             ; // R
reg[31:0] r_reg_egr_forward_channel                 ; // R/W  [31:0]
reg[31:0] r_reg_egr_forward_session                 ; // R/W  [31:0]
reg[CONNECTION_WIDTH-1:0] r_reg_stat_sel_session    ; // R/W
reg[CHANNEL_WIDTH-1:0]    r_reg_stat_sel_channel    ; // R/W
wire[31:0] w_reg_ingr_latency_0_value               ; // R
wire[31:0] w_reg_ingr_latency_1_value               ; // R
wire[31:0] w_reg_egr_latency_0_value                ; // R
wire[31:0] w_reg_egr_latency_1_value                ; // R
wire[31:0] w_reg_func_latency_value                 ; // R
wire[3:0] w_reg_stat_header_buff_stored             ; // R
reg       r_reg_stat_header_buff_bp                 ; // R/WC
wire[7:0] w_reg_stat_egr_busy_count                 ; // R
reg       r_reg_stat_session_enable_0               ; // R
reg       r_reg_stat_session_enable_1               ; // R
reg       r_reg_detect_fault                        ; // R
reg[17:0] r_reg_ingr_rcv_detect_fault_0_value       ; // RC
reg[17:0] r_reg_ingr_rcv_detect_fault_0_mask        ; // R/W
reg[17:0] r_reg_ingr_rcv_detect_fault_0_force       ; // R/W
reg[17:0] r_reg_ingr_rcv_detect_fault_1_value       ; // RC
reg[17:0] r_reg_ingr_rcv_detect_fault_1_mask        ; // R/W
reg[17:0] r_reg_ingr_rcv_detect_fault_1_force       ; // R/W
reg[16:0] r_reg_ingr_snd_detect_fault_0_value       ; // RC
reg[16:0] r_reg_ingr_snd_detect_fault_0_mask        ; // R/W
reg[16:0] r_reg_ingr_snd_detect_fault_0_force       ; // R/W
reg[16:0] r_reg_ingr_snd_detect_fault_1_value       ; // RC
reg[16:0] r_reg_ingr_snd_detect_fault_1_mask        ; // R/W
reg[16:0] r_reg_ingr_snd_detect_fault_1_force       ; // R/W
reg[16:0] r_reg_egr_rcv_detect_fault_value          ; // RC
reg[16:0] r_reg_egr_rcv_detect_fault_mask           ; // R/W
reg[16:0] r_reg_egr_rcv_detect_fault_force          ; // R/W
reg[17:0] r_reg_egr_snd_detect_fault_0_value        ; // RC
reg[17:0] r_reg_egr_snd_detect_fault_0_mask         ; // R/W
reg[17:0] r_reg_egr_snd_detect_fault_0_force        ; // R/W
reg[17:0] r_reg_egr_snd_detect_fault_1_value        ; // RC
reg[17:0] r_reg_egr_snd_detect_fault_1_mask         ; // R/W
reg[17:0] r_reg_egr_snd_detect_fault_1_force        ; // R/W
reg[15:0] r_reg_ingr_snd_protocol_fault             ; // R/WC [15:0]
reg[15:0] r_reg_ingr_snd_protocol_fault_mask        ; // R/W  [15:0]
reg[15:0] r_reg_ingr_snd_protocol_fault_force       ; // R/W  [15:0]
reg[15:0] r_reg_egr_rcv_protocol_fault              ; // R/WC [15:0]
reg[15:0] r_reg_egr_rcv_protocol_fault_mask         ; // R/W  [15:0]
reg[15:0] r_reg_egr_rcv_protocol_fault_force        ; // R/W  [15:0]
reg[9:0]  r_reg_extif0_event_fault                  ; // R/WC
reg[9:0]  r_reg_extif0_event_fault_mask             ; // R/W  [9:0]
reg[9:0]  r_reg_extif0_event_fault_force            ; // R/W  [9:0]
reg[9:0]  r_reg_extif1_event_fault                  ; // R/WC
reg[9:0]  r_reg_extif1_event_fault_mask             ; // R/W  [9:0]
reg[9:0]  r_reg_extif1_event_fault_force            ; // R/W  [9:0]
reg[9:0]  r_reg_streamif_stall                      ; // R
reg[9:0]  r_reg_streamif_stall_mask                 ; // R/W  [9:0]
reg[9:0]  r_reg_streamif_stall_force                ; // R/W  [9:0]
reg[2:0]  r_reg_ingr_rcv_insert_fault_0             ; // R/W  [2:0]
reg[2:0]  r_reg_ingr_rcv_insert_fault_1             ; // R/W  [2:0]
reg[18:0] r_reg_egr_snd_insert_fault_0              ; // R/W  [18:0]
reg[18:0] r_reg_egr_snd_insert_fault_1              ; // R/W  [18:0]
reg[31:0] r_reg_ingr_snd_insert_protocol_fault      ; // R/W  [31:0]
reg[31:0] r_reg_egr_rcv_insert_protocol_fault       ; // R/W  [31:0]
reg[31:0] r_reg_extif0_insert_command_fault         ; // R/W  [31:0]
reg[31:0] r_reg_extif1_insert_command_fault         ; // R/W  [31:0]
reg[31:0] r_reg_rcv_nxt_update_resp_count           ; // R
reg[31:0] r_reg_rcv_nxt_update_resp_fail_count      ; // R
reg[31:0] r_reg_usr_read_update_resp_count          ; // R
reg[31:0] r_reg_usr_read_update_resp_fail_count     ; // R
reg[31:0] r_reg_snd_una_update_resp_count           ; // R
reg[31:0] r_reg_snd_una_update_resp_fail_count      ; // R
reg[31:0] r_reg_usr_wrt_update_resp_count           ; // R
reg[31:0] r_reg_usr_wrt_update_resp_fail_count      ; // R
reg[31:0] r_reg_ingr_forward_update_resp_count      ; // R
reg[31:0] r_reg_ingr_forward_update_resp_fail_count ; // R
reg[31:0] r_reg_egr_forward_update_resp_count       ; // R
reg[31:0] r_reg_egr_forward_update_resp_fail_count  ; // R
reg[31:0] r_reg_rx_head_update_resp_count           ; // R
reg[31:0] r_reg_rx_tail_update_resp_count           ; // R
reg[31:0] r_reg_tx_tail_update_resp_count           ; // R
reg[31:0] r_reg_tx_head_update_resp_count           ; // R
reg[31:0] r_reg_dbg_lup_rx_head                     ; // R
reg[31:0] r_reg_dbg_lup_rx_tail                     ; // R
reg[31:0] r_reg_dbg_lup_tx_tail                     ; // R
reg[31:0] r_reg_dbg_lup_tx_head                     ; // R
reg[31:0] r_reg_hr_rcv_notify                       ; // R
reg[31:0] r_reg_hr_snd_req_hd                       ; // R
reg[31:0] r_reg_hr_rcv_data_hd                      ; // R
reg[31:0] r_reg_hr_snd_req_dt                       ; // R
reg[31:0] r_reg_hr_snd_notify                       ; // R
reg[31:0] r_reg_hr_rcv_req                          ; // R
reg[31:0] r_reg_hr_rcv_data_dt                      ; // R
reg[31:0] r_reg_hr_snd_data                         ; // R
reg[31:0] r_reg_hr_rcv_length_small                 ; // R
reg[31:0] r_reg_ha_rcv_req                          ; // R
reg[31:0] r_reg_ha_snd_resp                         ; // R
reg[31:0] r_reg_ha_snd_req                          ; // R
reg[31:0] r_reg_ha_rcv_resp                         ; // R
reg[31:0] r_reg_ha_rcv_data                         ; // R
reg[31:0] r_reg_ha_snd_data                         ; // R
reg[31:0] r_reg_hr_rcv_data_dt2                     ; // R
reg[31:0] r_reg_hr_rcv_data_hd_err                  ; // R
reg[CONNECTION_WIDTH-1:0] r_reg_dbg_sel_session     ; // R/W  [CONNECTION_WIDTH-1:0]
reg[31:0] r_reg_extif0_ingr_last_wr_ptr             ; // R
reg[31:0] r_reg_extif0_ingr_last_rd_ptr             ; // R
wire[31:0] w_reg_extif0_egr_last_wr_ptr             ; // R
wire[31:0] w_reg_extif0_egr_last_rd_ptr             ; // R
reg[31:0] r_reg_extif1_ingr_last_wr_ptr             ; // R
reg[31:0] r_reg_extif1_ingr_last_rd_ptr             ; // R
wire[31:0] w_reg_extif1_egr_last_wr_ptr             ; // R
wire[31:0] w_reg_extif1_egr_last_rd_ptr             ; // R

//------------------------AXI write fsm------------------
assign AWREADY = (wstate == WRIDLE);
assign WREADY  = (wstate == WRDATA);
assign BRESP   = 2'b00;  // OKAY
assign BVALID  = (wstate == WRRESP);
assign wmask   = { {8{WSTRB[3]}}, {8{WSTRB[2]}}, {8{WSTRB[1]}}, {8{WSTRB[0]}} };
assign aw_hs   = AWVALID & AWREADY;
assign w_hs    = WVALID & WREADY;

// wstate
always @(posedge ACLK) begin
  if (!ARESET_N)
    wstate <= WRRESET;
  else
    wstate <= wnext;
end

// wnext
always @(*) begin
  case (wstate)
    WRIDLE:
      if (AWVALID)
        wnext = WRDATA;
      else
        wnext = WRIDLE;
    WRDATA:
      if (WVALID)
        wnext = WRRESP;
      else
        wnext = WRDATA;
    WRRESP:
      if (BREADY)
        wnext = WRIDLE;
      else
        wnext = WRRESP;
    default:
      wnext = WRIDLE;
  endcase
end

// waddr
always @(posedge ACLK) begin
  if (aw_hs)
    waddr <= AWADDR[ADDR_BITS-1:0];
end

//------------------------AXI read fsm-------------------
assign ARREADY = (rstate == RDIDLE);
assign RDATA   = rdata;
assign RRESP   = 2'b00;  // OKAY
assign RVALID  = (rstate == RDDATA);
assign ar_hs   = ARVALID & ARREADY;
assign raddr   = ARADDR[ADDR_BITS-1:0];

wire w_stat_rdreq;
wire w_stat_rdack_valid;
reg r_stat_rdack_valid;
reg[63:0] r_stat_rdack_value;
reg r_stat_header_buff_bp_rdata;

// rstate
always @(posedge ACLK) begin
  if (!ARESET_N)
    rstate <= RDRESET;
  else
    rstate <= rnext;
end

// rnext
always @(*) begin
  case (rstate)
    RDIDLE:
      if (ARVALID) begin
        if (w_stat_rdreq) begin
          rnext = RDWAIT;
        end else begin
          rnext = RDDATA;
        end
      end else begin
        rnext = RDIDLE;
      end
    RDWAIT:
      if (r_stat_rdack_valid) begin
        rnext = RDDATA;
      end else begin
        rnext = RDWAIT;
      end
    RDDATA:
      if (RREADY & RVALID) begin
        rnext = RDIDLE;
      end else begin
        rnext = RDDATA;
      end
    default:
      rnext = RDIDLE;
  endcase
end

// rdata
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    rdata <= 32'd0;
  end else if (ar_hs) begin
    rdata <= 'b0;
    case (raddr)
      ADDR_CONTROL                                : rdata <= r_reg_control                              ; //
      ADDR_MODULE_ID                              : rdata <= module_id                                  ; // [31:0]
      ADDR_LOCAL_VERSION                          : rdata <= local_version                              ; // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_BASE_L             : rdata <= r_reg_m_axi_extif0_buffer_base_l           ; // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_BASE_H             : rdata <= r_reg_m_axi_extif0_buffer_base_h           ; // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_RX_OFFSET_L        : rdata <= r_reg_m_axi_extif0_buffer_rx_offset_l      ; // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_RX_OFFSET_H        : rdata <= r_reg_m_axi_extif0_buffer_rx_offset_h      ; // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_RX_STRIDE          : rdata <= r_reg_m_axi_extif0_buffer_rx_stride        ; // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_RX_SIZE            : rdata <= r_reg_m_axi_extif0_buffer_rx_size          ; // [3:0]
      ADDR_M_AXI_EXTIF0_BUFFER_TX_OFFSET_L        : rdata <= r_reg_m_axi_extif0_buffer_tx_offset_l      ; // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_TX_OFFSET_H        : rdata <= r_reg_m_axi_extif0_buffer_tx_offset_h      ; // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_TX_STRIDE          : rdata <= r_reg_m_axi_extif0_buffer_tx_stride        ; // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_TX_SIZE            : rdata <= r_reg_m_axi_extif0_buffer_tx_size          ; // [3:0]
      ADDR_M_AXI_EXTIF1_BUFFER_BASE_L             : rdata <= r_reg_m_axi_extif1_buffer_base_l           ; // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_BASE_H             : rdata <= r_reg_m_axi_extif1_buffer_base_h           ; // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_RX_OFFSET_L        : rdata <= r_reg_m_axi_extif1_buffer_rx_offset_l      ; // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_RX_OFFSET_H        : rdata <= r_reg_m_axi_extif1_buffer_rx_offset_h      ; // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_RX_STRIDE          : rdata <= r_reg_m_axi_extif1_buffer_rx_stride        ; // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_RX_SIZE            : rdata <= r_reg_m_axi_extif1_buffer_rx_size          ; // [3:0]
      ADDR_M_AXI_EXTIF1_BUFFER_TX_OFFSET_L        : rdata <= r_reg_m_axi_extif1_buffer_tx_offset_l      ; // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_TX_OFFSET_H        : rdata <= r_reg_m_axi_extif1_buffer_tx_offset_h      ; // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_TX_STRIDE          : rdata <= r_reg_m_axi_extif1_buffer_tx_stride        ; // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_TX_SIZE            : rdata <= r_reg_m_axi_extif1_buffer_tx_size          ; // [3:0]
      ADDR_INGR_FORWARD_UPDATE_REQ                : rdata <= r_reg_ingr_forward_update_req              ; // [1:0]
      ADDR_INGR_FORWARD_UPDATE_RESP               : rdata <= r_reg_ingr_forward_update_resp             ; // [31:0]
      ADDR_INGR_FORWARD_SESSION                   : rdata <= r_reg_ingr_forward_session                 ; // [31:0]
      ADDR_INGR_FORWARD_CHANNEL                   : rdata <= r_reg_ingr_forward_channel                 ; // [31:0]
      ADDR_EGR_FORWARD_UPDATE_REQ                 : rdata <= r_reg_egr_forward_update_req               ; // [1:0]
      ADDR_EGR_FORWARD_UPDATE_RESP                : rdata <= r_reg_egr_forward_update_resp              ; // [31:0]
      ADDR_EGR_FORWARD_CHANNEL                    : rdata <= r_reg_egr_forward_channel                  ; // [31:0]
      ADDR_EGR_FORWARD_SESSION                    : rdata <= r_reg_egr_forward_session                  ; // [31:0]
      ADDR_STAT_SEL_SESSION                       : rdata <= r_reg_stat_sel_session                     ; // [31:0]
      ADDR_STAT_SEL_CHANNEL                       : rdata <= r_reg_stat_sel_channel                     ; // [31:0]
      ADDR_INGR_LATENCY_0_VALUE                   : rdata <= w_reg_ingr_latency_0_value                 ; // [31:0]
      ADDR_INGR_LATENCY_1_VALUE                   : rdata <= w_reg_ingr_latency_1_value                 ; // [31:0]
      ADDR_EGR_LATENCY_0_VALUE                    : rdata <= w_reg_egr_latency_0_value                  ; // [31:0]
      ADDR_EGR_LATENCY_1_VALUE                    : rdata <= w_reg_egr_latency_1_value                  ; // [31:0]
      ADDR_FUNC_LATENCY_VALUE                     : rdata <= w_reg_func_latency_value                   ; // [31:0]
      ADDR_STAT_INGR_RCV_DATA_0_VALUE_H           : rdata <= r_stat_rdack_value[63:32]                  ; // [31:0]
      ADDR_STAT_INGR_RCV_DATA_1_VALUE_H           : rdata <= r_stat_rdack_value[63:32]                  ; // [31:0]
      ADDR_STAT_INGR_SND_DATA_0_VALUE_H           : rdata <= r_stat_rdack_value[63:32]                  ; // [31:0]
      ADDR_STAT_INGR_SND_DATA_1_VALUE_H           : rdata <= r_stat_rdack_value[63:32]                  ; // [31:0]
      ADDR_STAT_EGR_RCV_DATA_0_VALUE_H            : rdata <= r_stat_rdack_value[63:32]                  ; // [31:0]
      ADDR_STAT_EGR_RCV_DATA_1_VALUE_H            : rdata <= r_stat_rdack_value[63:32]                  ; // [31:0]
      ADDR_STAT_EGR_SND_DATA_0_VALUE_H            : rdata <= r_stat_rdack_value[63:32]                  ; // [31:0]
      ADDR_STAT_EGR_SND_DATA_1_VALUE_H            : rdata <= r_stat_rdack_value[63:32]                  ; // [31:0]
      ADDR_STAT_INGR_DISCARD_DATA_0_VALUE_H       : rdata <= r_stat_rdack_value[63:32]                  ; // [31:0]
      ADDR_STAT_INGR_DISCARD_DATA_1_VALUE_H       : rdata <= r_stat_rdack_value[63:32]                  ; // [31:0]
      ADDR_STAT_EGR_DISCARD_DATA_0_VALUE_H        : rdata <= r_stat_rdack_value[63:32]                  ; // [31:0]
      ADDR_STAT_EGR_DISCARD_DATA_1_VALUE_H        : rdata <= r_stat_rdack_value[63:32]                  ; // [31:0]
      ADDR_STAT_HEADER_BUFF_STORED                : rdata <= w_reg_stat_header_buff_stored              ; // [3:0]
      ADDR_STAT_HEADER_BUFF_BP                    : rdata <= r_reg_stat_header_buff_bp                  ; //
      ADDR_STAT_EGR_BUSY                          : rdata <= w_reg_stat_egr_busy_count                  ; // [7:0]
      ADDR_STAT_SESSION_ENABLE_0                  : rdata <= r_reg_stat_session_enable_0                ; //
      ADDR_STAT_SESSION_ENABLE_1                  : rdata <= r_reg_stat_session_enable_1                ; //
      ADDR_DETECT_FAULT                           : rdata <= r_reg_detect_fault                         ; //
      ADDR_INGR_RCV_DETECT_FAULT_0_VALUE          : rdata <= r_reg_ingr_rcv_detect_fault_0_value        ; // [17:0]
      ADDR_INGR_RCV_DETECT_FAULT_0_MASK           : rdata <= r_reg_ingr_rcv_detect_fault_0_mask         ; // [17:0]
      ADDR_INGR_RCV_DETECT_FAULT_0_FORCE          : rdata <= r_reg_ingr_rcv_detect_fault_0_force        ; // [17:0]
      ADDR_INGR_RCV_DETECT_FAULT_1_VALUE          : rdata <= r_reg_ingr_rcv_detect_fault_1_value        ; // [17:0]
      ADDR_INGR_RCV_DETECT_FAULT_1_MASK           : rdata <= r_reg_ingr_rcv_detect_fault_1_mask         ; // [17:0]
      ADDR_INGR_RCV_DETECT_FAULT_1_FORCE          : rdata <= r_reg_ingr_rcv_detect_fault_1_force        ; // [17:0]
      ADDR_INGR_SND_DETECT_FAULT_0_VALUE          : rdata <= r_reg_ingr_snd_detect_fault_0_value        ; // [16:0]
      ADDR_INGR_SND_DETECT_FAULT_0_MASK           : rdata <= r_reg_ingr_snd_detect_fault_0_mask         ; // [16:0]
      ADDR_INGR_SND_DETECT_FAULT_0_FORCE          : rdata <= r_reg_ingr_snd_detect_fault_0_force        ; // [16:0]
      ADDR_INGR_SND_DETECT_FAULT_1_VALUE          : rdata <= r_reg_ingr_snd_detect_fault_1_value        ; // [16:0]
      ADDR_INGR_SND_DETECT_FAULT_1_MASK           : rdata <= r_reg_ingr_snd_detect_fault_1_mask         ; // [16:0]
      ADDR_INGR_SND_DETECT_FAULT_1_FORCE          : rdata <= r_reg_ingr_snd_detect_fault_1_force        ; // [16:0]
      ADDR_EGR_RCV_DETECT_FAULT_VALUE             : rdata <= r_reg_egr_rcv_detect_fault_value           ; // [16:0]
      ADDR_EGR_RCV_DETECT_FAULT_MASK              : rdata <= r_reg_egr_rcv_detect_fault_mask            ; // [16:0]
      ADDR_EGR_RCV_DETECT_FAULT_FORCE             : rdata <= r_reg_egr_rcv_detect_fault_force           ; // [16:0]
      ADDR_EGR_SND_DETECT_FAULT_0_VALUE           : rdata <= r_reg_egr_snd_detect_fault_0_value         ; // [17:0]
      ADDR_EGR_SND_DETECT_FAULT_0_MASK            : rdata <= r_reg_egr_snd_detect_fault_0_mask          ; // [17:0]
      ADDR_EGR_SND_DETECT_FAULT_0_FORCE           : rdata <= r_reg_egr_snd_detect_fault_0_force         ; // [17:0]
      ADDR_EGR_SND_DETECT_FAULT_1_VALUE           : rdata <= r_reg_egr_snd_detect_fault_1_value         ; // [17:0]
      ADDR_EGR_SND_DETECT_FAULT_1_MASK            : rdata <= r_reg_egr_snd_detect_fault_1_mask          ; // [17:0]
      ADDR_EGR_SND_DETECT_FAULT_1_FORCE           : rdata <= r_reg_egr_snd_detect_fault_1_force         ; // [17:0]
      ADDR_INGR_SND_PROTOCOL_FAULT                : rdata <= r_reg_ingr_snd_protocol_fault              ; // [15:0]
      ADDR_INGR_SND_PROTOCOL_FAULT_MASK           : rdata <= r_reg_ingr_snd_protocol_fault_mask         ; // [15:0]
      ADDR_INGR_SND_PROTOCOL_FAULT_FORCE          : rdata <= r_reg_ingr_snd_protocol_fault_force        ; // [15:0]
      ADDR_EGR_RCV_PROTOCOL_FAULT                 : rdata <= r_reg_egr_rcv_protocol_fault               ; // [15:0]
      ADDR_EGR_RCV_PROTOCOL_FAULT_MASK            : rdata <= r_reg_egr_rcv_protocol_fault_mask          ; // [15:0]
      ADDR_EGR_RCV_PROTOCOL_FAULT_FORCE           : rdata <= r_reg_egr_rcv_protocol_fault_force         ; // [15:0]
      ADDR_EXTIF0_EVENT_FAULT                     : rdata <= r_reg_extif0_event_fault                   ; // [9:0]
      ADDR_EXTIF0_EVENT_FAULT_MASK                : rdata <= r_reg_extif0_event_fault_mask              ; // [9:0]
      ADDR_EXTIF0_EVENT_FAULT_FORCE               : rdata <= r_reg_extif0_event_fault_force             ; // [9:0]
      ADDR_EXTIF1_EVENT_FAULT                     : rdata <= r_reg_extif1_event_fault                   ; // [9:0]
      ADDR_EXTIF1_EVENT_FAULT_MASK                : rdata <= r_reg_extif1_event_fault_mask              ; // [9:0]
      ADDR_EXTIF1_EVENT_FAULT_FORCE               : rdata <= r_reg_extif1_event_fault_force             ; // [9:0]
      ADDR_STREAMIF_STALL                         : rdata <= r_reg_streamif_stall                       ; // [9:0]
      ADDR_STREAMIF_STALL_MASK                    : rdata <= r_reg_streamif_stall_mask                  ; // [9:0]
      ADDR_STREAMIF_STALL_FORCE                   : rdata <= r_reg_streamif_stall_force                 ; // [9:0]
      ADDR_INGR_RCV_INSERT_FAULT_0                : rdata <= r_reg_ingr_rcv_insert_fault_0              ; // [2:0]
      ADDR_INGR_RCV_INSERT_FAULT_1                : rdata <= r_reg_ingr_rcv_insert_fault_1              ; // [2:0]
      ADDR_EGR_SND_INSERT_FAULT_0                 : rdata <= r_reg_egr_snd_insert_fault_0               ; // [18:0]
      ADDR_EGR_SND_INSERT_FAULT_1                 : rdata <= r_reg_egr_snd_insert_fault_1               ; // [18:0]
      ADDR_INGR_SND_INSERT_PROTOCOL_FAULT         : rdata <= r_reg_ingr_snd_insert_protocol_fault       ; // [31:0]
      ADDR_EGR_RCV_INSERT_PROTOCOL_FAULT          : rdata <= r_reg_egr_rcv_insert_protocol_fault        ; // [31:0]
      ADDR_EXTIF0_INSERT_COMMAND_FAULT            : rdata <= r_reg_extif0_insert_command_fault          ; // [31:0]
      ADDR_EXTIF1_INSERT_COMMAND_FAULT            : rdata <= r_reg_extif1_insert_command_fault          ; // [31:0]
      ADDR_RCV_NXT_UPDATE_RESP_COUNT              : rdata <= r_reg_rcv_nxt_update_resp_count            ; // [31:0]
      ADDR_RCV_NXT_UPDATE_RESP_FAIL_COUNT         : rdata <= r_reg_rcv_nxt_update_resp_fail_count       ; // [31:0]
      ADDR_USR_READ_UPDATE_RESP_COUNT             : rdata <= r_reg_usr_read_update_resp_count           ; // [31:0]
      ADDR_USR_READ_UPDATE_RESP_FAIL_COUNT        : rdata <= r_reg_usr_read_update_resp_fail_count      ; // [31:0]
      ADDR_SND_UNA_UPDATE_RESP_COUNT              : rdata <= r_reg_snd_una_update_resp_count            ; // [31:0]
      ADDR_SND_UNA_UPDATE_RESP_FAIL_COUNT         : rdata <= r_reg_snd_una_update_resp_fail_count       ; // [31:0]
      ADDR_USR_WRT_UPDATE_RESP_COUNT              : rdata <= r_reg_usr_wrt_update_resp_count            ; // [31:0]
      ADDR_USR_WRT_UPDATE_RESP_FAIL_COUNT         : rdata <= r_reg_usr_wrt_update_resp_fail_count       ; // [31:0]
      ADDR_INGR_FORWARD_UPDATE_RESP_COUNT         : rdata <= r_reg_ingr_forward_update_resp_count       ; // [31:0]
      ADDR_INGR_FORWARD_UPDATE_RESP_FAIL_COUNT    : rdata <= r_reg_ingr_forward_update_resp_fail_count  ; // [31:0]
      ADDR_EGR_FORWARD_UPDATE_RESP_COUNT          : rdata <= r_reg_egr_forward_update_resp_count        ; // [31:0]
      ADDR_EGR_FORWARD_UPDATE_RESP_FAIL_COUNT     : rdata <= r_reg_egr_forward_update_resp_fail_count   ; // [31:0]
      ADDR_RX_HEAD_UPDATE_RESP_COUNT              : rdata <= r_reg_rx_head_update_resp_count            ; // [31:0]
      ADDR_RX_TAIL_UPDATE_RESP_COUNT              : rdata <= r_reg_rx_tail_update_resp_count            ; // [31:0]
      ADDR_TX_TAIL_UPDATE_RESP_COUNT              : rdata <= r_reg_tx_tail_update_resp_count            ; // [31:0]
      ADDR_TX_HEAD_UPDATE_RESP_COUNT              : rdata <= r_reg_tx_head_update_resp_count            ; // [31:0]
      ADDR_DBG_LUP_RX_HEAD                        : rdata <= r_reg_dbg_lup_rx_head                      ; // [31:0]
      ADDR_DBG_LUP_RX_TAIL                        : rdata <= r_reg_dbg_lup_rx_tail                      ; // [31:0]
      ADDR_DBG_LUP_TX_TAIL                        : rdata <= r_reg_dbg_lup_tx_tail                      ; // [31:0]
      ADDR_DBG_LUP_TX_HEAD                        : rdata <= r_reg_dbg_lup_tx_head                      ; // [31:0]
      ADDR_HR_RCV_NOTIFY                          : rdata <= r_reg_hr_rcv_notify                        ; // [31:0]
      ADDR_HR_SND_REQ_HD                          : rdata <= r_reg_hr_snd_req_hd                        ; // [31:0]
      ADDR_HR_RCV_DATA_HD                         : rdata <= r_reg_hr_rcv_data_hd                       ; // [31:0]
      ADDR_HR_SND_REQ_DT                          : rdata <= r_reg_hr_snd_req_dt                        ; // [31:0]
      ADDR_HR_SND_NOTIFY                          : rdata <= r_reg_hr_snd_notify                        ; // [31:0]
      ADDR_HR_RCV_REQ                             : rdata <= r_reg_hr_rcv_req                           ; // [31:0]
      ADDR_HR_RCV_DATA_DT                         : rdata <= r_reg_hr_rcv_data_dt                       ; // [31:0]
      ADDR_HR_SND_DATA                            : rdata <= r_reg_hr_snd_data                          ; // [31:0]
      ADDR_HR_RCV_LENGTH_SMALL                    : rdata <= r_reg_hr_rcv_length_small                  ; // [31:0]
      ADDR_HA_RCV_REQ                             : rdata <= r_reg_ha_rcv_req                           ; // [31:0]
      ADDR_HA_SND_RESP                            : rdata <= r_reg_ha_snd_resp                          ; // [31:0]
      ADDR_HA_SND_REQ                             : rdata <= r_reg_ha_snd_req                           ; // [31:0]
      ADDR_HA_RCV_RESP                            : rdata <= r_reg_ha_rcv_resp                          ; // [31:0]
      ADDR_HA_RCV_DATA                            : rdata <= r_reg_ha_rcv_data                          ; // [31:0]
      ADDR_HA_SND_DATA                            : rdata <= r_reg_ha_snd_data                          ; // [31:0]
      ADDR_HR_RCV_DATA_DT2                        : rdata <= r_reg_hr_rcv_data_dt2                      ; // [31:0]
      ADDR_HR_RCV_DATA_HD_ERR                     : rdata <= r_reg_hr_rcv_data_hd_err                   ; // [31:0]
      ADDR_DBG_SEL_SESSION                        : rdata <= r_reg_dbg_sel_session                      ; // [CONNECTION_WIDTH-1:0]
      ADDR_EXTIF0_INGR_LAST_WR_PTR                : rdata <= r_reg_extif0_ingr_last_wr_ptr              ; // [31:0]
      ADDR_EXTIF0_INGR_LAST_RD_PTR                : rdata <= r_reg_extif0_ingr_last_rd_ptr              ; // [31:0]
      ADDR_EXTIF0_EGR_LAST_WR_PTR                 : rdata <= w_reg_extif0_egr_last_wr_ptr               ; // [31:0]
      ADDR_EXTIF0_EGR_LAST_RD_PTR                 : rdata <= w_reg_extif0_egr_last_rd_ptr               ; // [31:0]
      ADDR_EXTIF1_INGR_LAST_WR_PTR                : rdata <= r_reg_extif1_ingr_last_wr_ptr              ; // [31:0]
      ADDR_EXTIF1_INGR_LAST_RD_PTR                : rdata <= r_reg_extif1_ingr_last_rd_ptr              ; // [31:0]
      ADDR_EXTIF1_EGR_LAST_WR_PTR                 : rdata <= w_reg_extif1_egr_last_wr_ptr               ; // [31:0]
      ADDR_EXTIF1_EGR_LAST_RD_PTR                 : rdata <= w_reg_extif1_egr_last_rd_ptr               ; // [31:0]
    endcase
  end else if (r_stat_rdack_valid) begin
    rdata <= r_stat_rdack_value[31:0];
  end
end

// read/write registers
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_reg_control                         <= 1'd0;
    r_reg_m_axi_extif0_buffer_base_l      <= 32'd0;
    r_reg_m_axi_extif0_buffer_base_h      <= 32'd0;
    r_reg_m_axi_extif0_buffer_rx_offset_l <= 32'd0;
    r_reg_m_axi_extif0_buffer_rx_offset_h <= 32'd0;
    r_reg_m_axi_extif0_buffer_rx_stride   <= 32'd0;
    r_reg_m_axi_extif0_buffer_rx_size     <= 32'd0;
    r_reg_m_axi_extif0_buffer_tx_offset_l <= 32'd0;
    r_reg_m_axi_extif0_buffer_tx_offset_h <= 32'd0;
    r_reg_m_axi_extif0_buffer_tx_stride   <= 32'd0;
    r_reg_m_axi_extif0_buffer_tx_size     <= 32'd0;
    r_reg_m_axi_extif1_buffer_base_l      <= 32'd0;
    r_reg_m_axi_extif1_buffer_base_h      <= 32'd0;
    r_reg_m_axi_extif1_buffer_rx_offset_l <= 32'd0;
    r_reg_m_axi_extif1_buffer_rx_offset_h <= 32'd0;
    r_reg_m_axi_extif1_buffer_rx_stride   <= 32'd0;
    r_reg_m_axi_extif1_buffer_rx_size     <= 32'd0;
    r_reg_m_axi_extif1_buffer_tx_offset_l <= 32'd0;
    r_reg_m_axi_extif1_buffer_tx_offset_h <= 32'd0;
    r_reg_m_axi_extif1_buffer_tx_stride   <= 32'd0;
    r_reg_m_axi_extif1_buffer_tx_size     <= 32'd0;
    r_reg_ingr_forward_update_req         <= 2'd0;
    r_reg_ingr_forward_session            <= 32'd0;
    r_reg_egr_forward_update_req          <= 2'd0;
    r_reg_egr_forward_channel             <= 32'd0;
    r_reg_stat_sel_session                <= 9'd0;
    r_reg_stat_sel_channel                <= 9'd0;
    r_reg_ingr_rcv_detect_fault_0_mask    <= 17'd0;
    r_reg_ingr_rcv_detect_fault_0_force   <= 17'd0;
    r_reg_ingr_rcv_detect_fault_1_mask    <= 17'd0;
    r_reg_ingr_rcv_detect_fault_1_force   <= 17'd0;
    r_reg_ingr_snd_detect_fault_0_mask    <= 16'd0;
    r_reg_ingr_snd_detect_fault_0_force   <= 16'd0;
    r_reg_ingr_snd_detect_fault_1_mask    <= 16'd0;
    r_reg_ingr_snd_detect_fault_1_force   <= 16'd0;
    r_reg_egr_rcv_detect_fault_mask       <= 16'd0;
    r_reg_egr_rcv_detect_fault_force      <= 16'd0;
    r_reg_egr_snd_detect_fault_0_mask     <= 17'd0;
    r_reg_egr_snd_detect_fault_0_force    <= 17'd0;
    r_reg_egr_snd_detect_fault_1_mask     <= 17'd0;
    r_reg_egr_snd_detect_fault_1_force    <= 17'd0;
    r_reg_ingr_snd_protocol_fault_mask    <= 16'd0;
    r_reg_ingr_snd_protocol_fault_force   <= 16'd0;
    r_reg_egr_rcv_protocol_fault_mask     <= 16'd0;
    r_reg_egr_rcv_protocol_fault_force    <= 16'd0;
    r_reg_extif0_event_fault_mask         <= 9'd0;
    r_reg_extif0_event_fault_force        <= 9'd0;
    r_reg_extif1_event_fault_mask         <= 9'd0;
    r_reg_extif1_event_fault_force        <= 9'd0;
    r_reg_streamif_stall_mask             <= 9'd0;
    r_reg_streamif_stall_force            <= 9'd0;
    r_reg_ingr_rcv_insert_fault_0         <= 2'd0;
    r_reg_ingr_rcv_insert_fault_1         <= 2'd0;
    r_reg_egr_snd_insert_fault_0          <= 19'd0;
    r_reg_egr_snd_insert_fault_1          <= 19'd0;
    r_reg_ingr_snd_insert_protocol_fault  <= 32'd0;
    r_reg_egr_rcv_insert_protocol_fault   <= 32'd0;
    r_reg_extif0_insert_command_fault     <= 32'd0;
    r_reg_extif1_insert_command_fault     <= 32'd0;
    r_reg_dbg_sel_session                 <= 9'd0;
  end else if (w_hs) begin
    case (waddr)
      ADDR_CONTROL                            : r_reg_control                         <= ((WDATA & wmask) | (r_reg_control                          & ~wmask)); // [0]
      ADDR_M_AXI_EXTIF0_BUFFER_BASE_L         : r_reg_m_axi_extif0_buffer_base_l      <= ((WDATA & wmask) | (r_reg_m_axi_extif0_buffer_base_l       & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_BASE_H         : r_reg_m_axi_extif0_buffer_base_h      <= ((WDATA & wmask) | (r_reg_m_axi_extif0_buffer_base_h       & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_RX_OFFSET_L    : r_reg_m_axi_extif0_buffer_rx_offset_l <= ((WDATA & wmask) | (r_reg_m_axi_extif0_buffer_rx_offset_l  & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_RX_OFFSET_H    : r_reg_m_axi_extif0_buffer_rx_offset_h <= ((WDATA & wmask) | (r_reg_m_axi_extif0_buffer_rx_offset_h  & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_RX_STRIDE      : r_reg_m_axi_extif0_buffer_rx_stride   <= ((WDATA & wmask) | (r_reg_m_axi_extif0_buffer_rx_stride    & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_RX_SIZE        : r_reg_m_axi_extif0_buffer_rx_size     <= ((WDATA & wmask) | (r_reg_m_axi_extif0_buffer_rx_size      & ~wmask)); // [3:0]
      ADDR_M_AXI_EXTIF0_BUFFER_TX_OFFSET_L    : r_reg_m_axi_extif0_buffer_tx_offset_l <= ((WDATA & wmask) | (r_reg_m_axi_extif0_buffer_tx_offset_l  & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_TX_OFFSET_H    : r_reg_m_axi_extif0_buffer_tx_offset_h <= ((WDATA & wmask) | (r_reg_m_axi_extif0_buffer_tx_offset_h  & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_TX_STRIDE      : r_reg_m_axi_extif0_buffer_tx_stride   <= ((WDATA & wmask) | (r_reg_m_axi_extif0_buffer_tx_stride    & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF0_BUFFER_TX_SIZE        : r_reg_m_axi_extif0_buffer_tx_size     <= ((WDATA & wmask) | (r_reg_m_axi_extif0_buffer_tx_size      & ~wmask)); // [3:0]
      ADDR_M_AXI_EXTIF1_BUFFER_BASE_L         : r_reg_m_axi_extif1_buffer_base_l      <= ((WDATA & wmask) | (r_reg_m_axi_extif1_buffer_base_l       & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_BASE_H         : r_reg_m_axi_extif1_buffer_base_h      <= ((WDATA & wmask) | (r_reg_m_axi_extif1_buffer_base_h       & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_RX_OFFSET_L    : r_reg_m_axi_extif1_buffer_rx_offset_l <= ((WDATA & wmask) | (r_reg_m_axi_extif1_buffer_rx_offset_l  & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_RX_OFFSET_H    : r_reg_m_axi_extif1_buffer_rx_offset_h <= ((WDATA & wmask) | (r_reg_m_axi_extif1_buffer_rx_offset_h  & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_RX_STRIDE      : r_reg_m_axi_extif1_buffer_rx_stride   <= ((WDATA & wmask) | (r_reg_m_axi_extif1_buffer_rx_stride    & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_RX_SIZE        : r_reg_m_axi_extif1_buffer_rx_size     <= ((WDATA & wmask) | (r_reg_m_axi_extif1_buffer_rx_size      & ~wmask)); // [3:0]
      ADDR_M_AXI_EXTIF1_BUFFER_TX_OFFSET_L    : r_reg_m_axi_extif1_buffer_tx_offset_l <= ((WDATA & wmask) | (r_reg_m_axi_extif1_buffer_tx_offset_l  & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_TX_OFFSET_H    : r_reg_m_axi_extif1_buffer_tx_offset_h <= ((WDATA & wmask) | (r_reg_m_axi_extif1_buffer_tx_offset_h  & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_TX_STRIDE      : r_reg_m_axi_extif1_buffer_tx_stride   <= ((WDATA & wmask) | (r_reg_m_axi_extif1_buffer_tx_stride    & ~wmask)); // [31:0]
      ADDR_M_AXI_EXTIF1_BUFFER_TX_SIZE        : r_reg_m_axi_extif1_buffer_tx_size     <= ((WDATA & wmask) | (r_reg_m_axi_extif1_buffer_tx_size      & ~wmask)); // [3:0]
      ADDR_INGR_FORWARD_UPDATE_REQ            : r_reg_ingr_forward_update_req         <= ((WDATA & wmask) | (r_reg_ingr_forward_update_req          & ~wmask)); // [1:0]
      ADDR_INGR_FORWARD_SESSION               : r_reg_ingr_forward_session            <= ((WDATA & wmask) | (r_reg_ingr_forward_session             & ~wmask)); // [31:0]
      ADDR_EGR_FORWARD_UPDATE_REQ             : r_reg_egr_forward_update_req          <= ((WDATA & wmask) | (r_reg_egr_forward_update_req           & ~wmask)); // [1:0]
      ADDR_EGR_FORWARD_CHANNEL                : r_reg_egr_forward_channel             <= ((WDATA & wmask) | (r_reg_egr_forward_channel              & ~wmask)); // [31:0]
      ADDR_STAT_SEL_SESSION                   : r_reg_stat_sel_session                <= ((WDATA & wmask) | (r_reg_stat_sel_session                 & ~wmask)); // [CONNECTION_WIDTH-1:0]
      ADDR_STAT_SEL_CHANNEL                   : r_reg_stat_sel_channel                <= ((WDATA & wmask) | (r_reg_stat_sel_channel                 & ~wmask)); // [CHANNEL_WIDTH-1:0]
      ADDR_INGR_RCV_DETECT_FAULT_0_MASK       : r_reg_ingr_rcv_detect_fault_0_mask    <= ((WDATA & wmask) | (r_reg_ingr_rcv_detect_fault_0_mask     & ~wmask)); // [17:0]
      ADDR_INGR_RCV_DETECT_FAULT_0_FORCE      : r_reg_ingr_rcv_detect_fault_0_force   <= ((WDATA & wmask) | (r_reg_ingr_rcv_detect_fault_0_force    & ~wmask)); // [17:0]
      ADDR_INGR_RCV_DETECT_FAULT_1_MASK       : r_reg_ingr_rcv_detect_fault_1_mask    <= ((WDATA & wmask) | (r_reg_ingr_rcv_detect_fault_1_mask     & ~wmask)); // [17:0]
      ADDR_INGR_RCV_DETECT_FAULT_1_FORCE      : r_reg_ingr_rcv_detect_fault_1_force   <= ((WDATA & wmask) | (r_reg_ingr_rcv_detect_fault_1_force    & ~wmask)); // [17:0]
      ADDR_INGR_SND_DETECT_FAULT_0_MASK       : r_reg_ingr_snd_detect_fault_0_mask    <= ((WDATA & wmask) | (r_reg_ingr_snd_detect_fault_0_mask     & ~wmask)); // [16:0]
      ADDR_INGR_SND_DETECT_FAULT_0_FORCE      : r_reg_ingr_snd_detect_fault_0_force   <= ((WDATA & wmask) | (r_reg_ingr_snd_detect_fault_0_force    & ~wmask)); // [16:0]
      ADDR_INGR_SND_DETECT_FAULT_1_MASK       : r_reg_ingr_snd_detect_fault_1_mask    <= ((WDATA & wmask) | (r_reg_ingr_snd_detect_fault_1_mask     & ~wmask)); // [16:0]
      ADDR_INGR_SND_DETECT_FAULT_1_FORCE      : r_reg_ingr_snd_detect_fault_1_force   <= ((WDATA & wmask) | (r_reg_ingr_snd_detect_fault_1_force    & ~wmask)); // [16:0]
      ADDR_EGR_RCV_DETECT_FAULT_MASK          : r_reg_egr_rcv_detect_fault_mask       <= ((WDATA & wmask) | (r_reg_egr_rcv_detect_fault_mask        & ~wmask)); // [16:0]
      ADDR_EGR_RCV_DETECT_FAULT_FORCE         : r_reg_egr_rcv_detect_fault_force      <= ((WDATA & wmask) | (r_reg_egr_rcv_detect_fault_force       & ~wmask)); // [16:0]
      ADDR_EGR_SND_DETECT_FAULT_0_MASK        : r_reg_egr_snd_detect_fault_0_mask     <= ((WDATA & wmask) | (r_reg_egr_snd_detect_fault_0_mask      & ~wmask)); // [17:0]
      ADDR_EGR_SND_DETECT_FAULT_0_FORCE       : r_reg_egr_snd_detect_fault_0_force    <= ((WDATA & wmask) | (r_reg_egr_snd_detect_fault_0_force     & ~wmask)); // [17:0]
      ADDR_EGR_SND_DETECT_FAULT_1_MASK        : r_reg_egr_snd_detect_fault_1_mask     <= ((WDATA & wmask) | (r_reg_egr_snd_detect_fault_1_mask      & ~wmask)); // [17:0]
      ADDR_EGR_SND_DETECT_FAULT_1_FORCE       : r_reg_egr_snd_detect_fault_1_force    <= ((WDATA & wmask) | (r_reg_egr_snd_detect_fault_1_force     & ~wmask)); // [17:0]
      ADDR_INGR_SND_PROTOCOL_FAULT_MASK       : r_reg_ingr_snd_protocol_fault_mask    <= ((WDATA & wmask) | (r_reg_ingr_snd_protocol_fault_mask     & ~wmask)); // [15:0]
      ADDR_INGR_SND_PROTOCOL_FAULT_FORCE      : r_reg_ingr_snd_protocol_fault_force   <= ((WDATA & wmask) | (r_reg_ingr_snd_protocol_fault_force    & ~wmask)); // [15:0]
      ADDR_EGR_RCV_PROTOCOL_FAULT_MASK        : r_reg_egr_rcv_protocol_fault_mask     <= ((WDATA & wmask) | (r_reg_egr_rcv_protocol_fault_mask      & ~wmask)); // [15:0]
      ADDR_EGR_RCV_PROTOCOL_FAULT_FORCE       : r_reg_egr_rcv_protocol_fault_force    <= ((WDATA & wmask) | (r_reg_egr_rcv_protocol_fault_force     & ~wmask)); // [15:0]
      ADDR_EXTIF0_EVENT_FAULT_MASK            : r_reg_extif0_event_fault_mask         <= ((WDATA & wmask) | (r_reg_extif0_event_fault_mask          & ~wmask)); // [9:0]
      ADDR_EXTIF0_EVENT_FAULT_FORCE           : r_reg_extif0_event_fault_force        <= ((WDATA & wmask) | (r_reg_extif0_event_fault_force         & ~wmask)); // [9:0]
      ADDR_EXTIF1_EVENT_FAULT_MASK            : r_reg_extif1_event_fault_mask         <= ((WDATA & wmask) | (r_reg_extif1_event_fault_mask          & ~wmask)); // [9:0]
      ADDR_EXTIF1_EVENT_FAULT_FORCE           : r_reg_extif1_event_fault_force        <= ((WDATA & wmask) | (r_reg_extif1_event_fault_force         & ~wmask)); // [9:0]
      ADDR_STREAMIF_STALL_MASK                : r_reg_streamif_stall_mask             <= ((WDATA & wmask) | (r_reg_streamif_stall_mask              & ~wmask)); // [9:0]
      ADDR_STREAMIF_STALL_FORCE               : r_reg_streamif_stall_force            <= ((WDATA & wmask) | (r_reg_streamif_stall_force             & ~wmask)); // [9:0]
      ADDR_INGR_RCV_INSERT_FAULT_0            : r_reg_ingr_rcv_insert_fault_0         <= ((WDATA & wmask) | (r_reg_ingr_rcv_insert_fault_0          & ~wmask)); // [2:0]
      ADDR_INGR_RCV_INSERT_FAULT_1            : r_reg_ingr_rcv_insert_fault_1         <= ((WDATA & wmask) | (r_reg_ingr_rcv_insert_fault_1          & ~wmask)); // [2:0]
      ADDR_EGR_SND_INSERT_FAULT_0             : r_reg_egr_snd_insert_fault_0          <= ((WDATA & wmask) | (r_reg_egr_snd_insert_fault_0           & ~wmask)); // [18:0]
      ADDR_EGR_SND_INSERT_FAULT_1             : r_reg_egr_snd_insert_fault_1          <= ((WDATA & wmask) | (r_reg_egr_snd_insert_fault_1           & ~wmask)); // [18:0]
      ADDR_INGR_SND_INSERT_PROTOCOL_FAULT     : r_reg_ingr_snd_insert_protocol_fault  <= ((WDATA & wmask) | (r_reg_ingr_snd_insert_protocol_fault   & ~wmask)); // [31:0]
      ADDR_EGR_RCV_INSERT_PROTOCOL_FAULT      : r_reg_egr_rcv_insert_protocol_fault   <= ((WDATA & wmask) | (r_reg_egr_rcv_insert_protocol_fault    & ~wmask)); // [31:0]
      ADDR_EXTIF0_INSERT_COMMAND_FAULT        : r_reg_extif0_insert_command_fault     <= ((WDATA & wmask) | (r_reg_extif0_insert_command_fault      & ~wmask)); // [31:0]
      ADDR_EXTIF1_INSERT_COMMAND_FAULT        : r_reg_extif1_insert_command_fault     <= ((WDATA & wmask) | (r_reg_extif1_insert_command_fault      & ~wmask)); // [31:0]
      ADDR_DBG_SEL_SESSION                    : r_reg_dbg_sel_session                 <= ((WDATA & wmask) | (r_reg_dbg_sel_session                  & ~wmask)); // [CONNECTION_WIDTH-1:0]
    endcase
  end
end

// ingress forward table data
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_reg_ingr_forward_channel <= 32'd0;
  end else if (w_hs && waddr == ADDR_INGR_FORWARD_CHANNEL) begin
    r_reg_ingr_forward_channel <= (WDATA[31:0] & wmask) | (r_reg_ingr_forward_channel & ~wmask);
  end else if (w_ingr_forward_update_resp_data_ap_vld) begin
    r_reg_ingr_forward_channel <= w_ingr_forward_update_resp_data;
  end
end


// egress forward table data
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_reg_egr_forward_session <= 32'd0;
  end else if (w_hs && waddr == ADDR_EGR_FORWARD_SESSION) begin
    r_reg_egr_forward_session <= (WDATA[31:0] & wmask) | (r_reg_egr_forward_session & ~wmask);
  end else if (w_egr_forward_update_resp_data_ap_vld) begin
    r_reg_egr_forward_session <= w_egr_forward_update_resp_data;
  end
end

// read only registers
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_reg_ingr_forward_update_resp            <= 0; // [31:0]
    r_reg_egr_forward_update_resp             <= 0; // [31:0]
    r_reg_streamif_stall                      <= 0; // [9:0]
    r_reg_rcv_nxt_update_resp_count           <= 0; // [31:0]
    r_reg_rcv_nxt_update_resp_fail_count      <= 0; // [31:0]
    r_reg_usr_read_update_resp_count          <= 0; // [31:0]
    r_reg_usr_read_update_resp_fail_count     <= 0; // [31:0]
    r_reg_snd_una_update_resp_count           <= 0; // [31:0]
    r_reg_snd_una_update_resp_fail_count      <= 0; // [31:0]
    r_reg_usr_wrt_update_resp_count           <= 0; // [31:0]
    r_reg_usr_wrt_update_resp_fail_count      <= 0; // [31:0]
    r_reg_ingr_forward_update_resp_count      <= 0; // [31:0]
    r_reg_ingr_forward_update_resp_fail_count <= 0; // [31:0]
    r_reg_egr_forward_update_resp_count       <= 0; // [31:0]
    r_reg_egr_forward_update_resp_fail_count  <= 0; // [31:0]
    r_reg_rx_head_update_resp_count           <= 0; // [31:0]
    r_reg_rx_tail_update_resp_count           <= 0; // [31:0]
    r_reg_tx_tail_update_resp_count           <= 0; // [31:0]
    r_reg_tx_head_update_resp_count           <= 0; // [31:0]
    r_reg_dbg_lup_rx_head                     <= 0; // [31:0]
    r_reg_dbg_lup_rx_tail                     <= 0; // [31:0]
    r_reg_dbg_lup_tx_tail                     <= 0; // [31:0]
    r_reg_dbg_lup_tx_head                     <= 0; // [31:0]
    r_reg_hr_rcv_notify                       <= 0; // [31:0]
    r_reg_hr_snd_req_hd                       <= 0; // [31:0]
    r_reg_hr_rcv_data_hd                      <= 0; // [31:0]
    r_reg_hr_snd_req_dt                       <= 0; // [31:0]
    r_reg_hr_snd_notify                       <= 0; // [31:0]
    r_reg_hr_rcv_req                          <= 0; // [31:0]
    r_reg_hr_rcv_data_dt                      <= 0; // [31:0]
    r_reg_hr_snd_data                         <= 0; // [31:0]
    r_reg_hr_rcv_length_small                 <= 0; // [31:0]
    r_reg_ha_rcv_req                          <= 0; // [31:0]
    r_reg_ha_snd_resp                         <= 0; // [31:0]
    r_reg_ha_snd_req                          <= 0; // [31:0]
    r_reg_ha_rcv_resp                         <= 0; // [31:0]
    r_reg_ha_rcv_data                         <= 0; // [31:0]
    r_reg_ha_snd_data                         <= 0; // [31:0]
    r_reg_hr_rcv_data_dt2                     <= 0; // [31:0]
    r_reg_hr_rcv_data_hd_err                  <= 0; // [31:0]
    r_reg_stat_session_enable_0               <= 0; //
    r_reg_stat_session_enable_1               <= 0; //
    r_reg_extif0_ingr_last_wr_ptr             <= 0; // [31:0]
    r_reg_extif0_ingr_last_rd_ptr             <= 0; // [31:0]
    r_reg_extif1_ingr_last_wr_ptr             <= 0; // [31:0]
    r_reg_extif1_ingr_last_rd_ptr             <= 0; // [31:0]
  end else begin
    r_reg_ingr_forward_update_resp            <= w_ingr_forward_update_resp; // [31:0]
    r_reg_egr_forward_update_resp             <= w_egr_forward_update_resp; // [31:0]
    r_reg_streamif_stall                      <= (streamif_stall | r_reg_streamif_stall_force) & ~ r_reg_streamif_stall_mask;
    r_reg_rcv_nxt_update_resp_count           <= w_rcv_nxt_update_resp_count;
    r_reg_usr_read_update_resp_count          <= w_usr_read_update_resp_count;
    r_reg_snd_una_update_resp_count           <= w_snd_una_update_resp_count;
    r_reg_usr_wrt_update_resp_count           <= w_usr_wrt_update_resp_count;
    r_reg_ingr_forward_update_resp_count      <= w_ingr_forward_update_resp_count;
    r_reg_ingr_forward_update_resp_fail_count <= w_ingr_forward_update_resp_fail_count;
    r_reg_egr_forward_update_resp_count       <= w_egr_forward_update_resp_count;
    r_reg_egr_forward_update_resp_fail_count  <= w_egr_forward_update_resp_fail_count;
    r_reg_rx_head_update_resp_count           <= w_rx_head_update_resp_count;
    r_reg_rx_tail_update_resp_count           <= w_rx_tail_update_resp_count;
    r_reg_tx_tail_update_resp_count           <= w_tx_tail_update_resp_count;
    r_reg_tx_head_update_resp_count           <= w_tx_head_update_resp_count;
    r_reg_dbg_lup_tx_tail                     <= w_dbg_lup_tx_tail;
    r_reg_dbg_lup_tx_head                     <= w_dbg_lup_tx_head;
    r_reg_stat_session_enable_0               <= w_extif_session_status[0];
    r_reg_stat_session_enable_1               <= w_extif_session_status[1];
    r_reg_extif0_ingr_last_wr_ptr             <= w_ingr_last_ptr[31:0];
    r_reg_extif0_ingr_last_rd_ptr             <= w_ingr_last_ptr[63:32];
    r_reg_extif1_ingr_last_wr_ptr             <= w_ingr_last_ptr[95:64];
    r_reg_extif1_ingr_last_rd_ptr             <= w_ingr_last_ptr[127:96];
  end
end

reg[15:0] r_ingr_snd_protocol_fault;
reg[15:0] r_egr_rcv_protocol_fault;
reg[ 9:0] r_extif0_event_fault;
reg[ 9:0] r_extif1_event_fault;
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_ingr_snd_protocol_fault <= 16'd0;
    r_egr_rcv_protocol_fault  <= 16'd0;
    r_extif0_event_fault      <= 10'd0;
    r_extif1_event_fault      <= 10'd0;
  end else begin
    r_ingr_snd_protocol_fault <= 16'd0;
    r_egr_rcv_protocol_fault  <= 16'd0;
    r_extif0_event_fault      <= 10'd0;
    r_extif1_event_fault      <= 10'd0;
    if (w_ingr_snd_protocol_fault_ap_vld) begin
      r_ingr_snd_protocol_fault <= w_ingr_snd_protocol_fault;
    end
    if (w_egr_rcv_protocol_fault_ap_vld) begin
      r_egr_rcv_protocol_fault  <= w_egr_rcv_protocol_fault;
    end
    if (extif0_event_fault_ap_vld) begin
      r_extif0_event_fault <= extif0_event_fault;
    end
    if (extif1_event_fault_ap_vld) begin
      r_extif1_event_fault <= extif1_event_fault;
    end
  end
end

// read/write-clear registers
wire[15:0] w_ingr_snd_protocol_fault_set = (r_ingr_snd_protocol_fault  | r_reg_ingr_snd_protocol_fault_force ) & ~ r_reg_ingr_snd_protocol_fault_mask;
wire[15:0] w_egr_rcv_protocol_fault_set  = (r_egr_rcv_protocol_fault   | r_reg_egr_rcv_protocol_fault_force  ) & ~ r_reg_egr_rcv_protocol_fault_mask ;
wire[ 9:0] w_extif0_event_fault_set      = (r_extif0_event_fault       | r_reg_extif0_event_fault_force      ) & ~ r_reg_extif0_event_fault_mask     ;
wire[ 9:0] w_extif1_event_fault_set      = (r_extif1_event_fault       | r_reg_extif1_event_fault_force      ) & ~ r_reg_extif1_event_fault_mask     ;
wire[15:0] w_ingr_snd_protocol_fault_clr = (w_hs && waddr == ADDR_INGR_SND_PROTOCOL_FAULT) ? (WDATA[15:0] & wmask[15:0]) : 16'd0;
wire[15:0] w_egr_rcv_protocol_fault_clr  = (w_hs && waddr == ADDR_EGR_RCV_PROTOCOL_FAULT ) ? (WDATA[15:0] & wmask[15:0]) : 16'd0;
wire[ 9:0] w_extif0_event_fault_clr      = (w_hs && waddr == ADDR_EXTIF0_EVENT_FAULT     ) ? (WDATA[ 9:0] & wmask[ 9:0]) : 10'd0;
wire[ 9:0] w_extif1_event_fault_clr      = (w_hs && waddr == ADDR_EXTIF1_EVENT_FAULT     ) ? (WDATA[ 9:0] & wmask[ 9:0]) : 10'd0;
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_reg_ingr_snd_protocol_fault <= 16'd0;
    r_reg_egr_rcv_protocol_fault  <= 16'd0;
    r_reg_extif0_event_fault      <= 10'd0;
    r_reg_extif1_event_fault      <= 10'd0;
  end else begin
    r_reg_ingr_snd_protocol_fault <= (r_reg_ingr_snd_protocol_fault & ~ w_ingr_snd_protocol_fault_clr ) | w_ingr_snd_protocol_fault_set ;
    r_reg_egr_rcv_protocol_fault  <= (r_reg_egr_rcv_protocol_fault  & ~ w_egr_rcv_protocol_fault_clr  ) | w_egr_rcv_protocol_fault_set  ;
    r_reg_extif0_event_fault      <= (r_reg_extif0_event_fault      & ~ w_extif0_event_fault_clr      ) | w_extif0_event_fault_set      ;
    r_reg_extif1_event_fault      <= (r_reg_extif1_event_fault      & ~ w_extif1_event_fault_clr      ) | w_extif1_event_fault_set      ;
  end
end

reg r_conn_table_init_done;
reg[CONNECTION_WIDTH-1:0] r_conn_table_init_addr;
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_conn_table_init_done <= 1'b0;
    r_conn_table_init_addr <= {CONNECTION_WIDTH{1'b0}};
  end else if (!r_conn_table_init_done) begin
    r_conn_table_init_done <= (r_conn_table_init_addr >= MAX_NUM_CONNECTIONS - 1);
    r_conn_table_init_addr <= r_conn_table_init_addr + 1;
  end
end

wire w_ingr_latency_0_wr_en;
wire[CONNECTION_WIDTH-1:0] w_ingr_latency_0_wr_addr;
wire[31:0] w_ingr_latency_0_wr_data;
assign w_ingr_latency_0_wr_en   = (~r_conn_table_init_done) | w_ingr_latency_0_valid;
assign w_ingr_latency_0_wr_addr = r_conn_table_init_done == 1'b0 ? r_conn_table_init_addr : w_ingr_latency_0_data[32+CONNECTION_WIDTH-1:32]; 
assign w_ingr_latency_0_wr_data = r_conn_table_init_done == 1'b0 ? 32'd0                  : w_ingr_latency_0_data[31:0];
control_s_axi_sdpram #(
  .DATA_WIDTH(32),
  .ADDR_WIDTH(CONNECTION_WIDTH)
) u_ram_ingr_latency_0 (
  .clk    (ACLK                       ), // input
  .wr_en  (w_ingr_latency_0_wr_en     ), // input
  .wr_addr(w_ingr_latency_0_wr_addr   ), // input [ADDR_WIDTH-1:0]
  .wr_data(w_ingr_latency_0_wr_data   ), // input [DATA_WIDTH-1:0]
  .rd_en  (1'b1                       ), // input
  .rd_addr(r_reg_stat_sel_session     ), // input [ADDR_WIDTH-1:0]
  .rd_data(w_reg_ingr_latency_0_value )  // output[DATA_WIDTH-1:0]
);

wire w_ingr_latency_1_wr_en;
wire[CONNECTION_WIDTH-1:0] w_ingr_latency_1_wr_addr;
wire[31:0] w_ingr_latency_1_wr_data;
assign w_ingr_latency_1_wr_en   = (~r_conn_table_init_done) | w_ingr_latency_1_valid;
assign w_ingr_latency_1_wr_addr = r_conn_table_init_done == 1'b0 ? r_conn_table_init_addr : w_ingr_latency_1_data[32+CONNECTION_WIDTH-1:32]; 
assign w_ingr_latency_1_wr_data = r_conn_table_init_done == 1'b0 ? 32'd0                  : w_ingr_latency_1_data[31:0];
control_s_axi_sdpram #(
  .DATA_WIDTH(32),
  .ADDR_WIDTH(CONNECTION_WIDTH)
) u_ram_ingr_latency_1 (
  .clk    (ACLK                       ), // input
  .wr_en  (w_ingr_latency_1_wr_en     ), // input
  .wr_addr(w_ingr_latency_1_wr_addr   ), // input [ADDR_WIDTH-1:0]
  .wr_data(w_ingr_latency_1_wr_data   ), // input [DATA_WIDTH-1:0]
  .rd_en  (1'b1                       ), // input
  .rd_addr(r_reg_stat_sel_session     ), // input [ADDR_WIDTH-1:0]
  .rd_data(w_reg_ingr_latency_1_value )  // output[DATA_WIDTH-1:0]
);

wire w_egr_latency_0_valid = w_egr_latency_valid & (w_egr_latency_data[32+CONNECTION_WIDTH] == 1'b0);
wire w_egr_latency_0_wr_en;
wire[CONNECTION_WIDTH-1:0] w_egr_latency_0_wr_addr;
wire[31:0] w_egr_latency_0_wr_data;
assign w_egr_latency_0_wr_en   = (~r_conn_table_init_done) | w_egr_latency_0_valid;
assign w_egr_latency_0_wr_addr = r_conn_table_init_done == 1'b0 ? r_conn_table_init_addr : w_egr_latency_data[32+CONNECTION_WIDTH-1:32]; 
assign w_egr_latency_0_wr_data = r_conn_table_init_done == 1'b0 ? 32'd0                  : w_egr_latency_data[31:0];
control_s_axi_sdpram #(
  .DATA_WIDTH(32),
  .ADDR_WIDTH(CONNECTION_WIDTH)
) u_ram_egr_latency_0 (
  .clk    (ACLK                     ), // input
  .wr_en  (w_egr_latency_0_wr_en    ), // input
  .wr_addr(w_egr_latency_0_wr_addr  ), // input [ADDR_WIDTH-1:0]
  .wr_data(w_egr_latency_0_wr_data  ), // input [DATA_WIDTH-1:0]
  .rd_en  (1'b1                     ), // input
  .rd_addr(r_reg_stat_sel_session   ), // input [ADDR_WIDTH-1:0]
  .rd_data(w_reg_egr_latency_0_value)  // output[DATA_WIDTH-1:0]
);

wire w_egr_latency_1_valid = w_egr_latency_valid & (w_egr_latency_data[32+CONNECTION_WIDTH] == 1'b1);
wire w_egr_latency_1_wr_en;
wire[CONNECTION_WIDTH-1:0] w_egr_latency_1_wr_addr;
wire[31:0] w_egr_latency_1_wr_data;
assign w_egr_latency_1_wr_en   = (~r_conn_table_init_done) | w_egr_latency_1_valid;
assign w_egr_latency_1_wr_addr = r_conn_table_init_done == 1'b0 ? r_conn_table_init_addr : w_egr_latency_data[32+CONNECTION_WIDTH-1:32]; 
assign w_egr_latency_1_wr_data = r_conn_table_init_done == 1'b0 ? 32'd0                  : w_egr_latency_data[31:0];
control_s_axi_sdpram #(
  .DATA_WIDTH(32),
  .ADDR_WIDTH(CONNECTION_WIDTH)
) u_ram_egr_latency_1 (
  .clk    (ACLK                     ), // input
  .wr_en  (w_egr_latency_1_wr_en    ), // input
  .wr_addr(w_egr_latency_1_wr_addr  ), // input [ADDR_WIDTH-1:0]
  .wr_data(w_egr_latency_1_wr_data  ), // input [DATA_WIDTH-1:0]
  .rd_en  (1'b1                     ), // input
  .rd_addr(r_reg_stat_sel_session   ), // input [ADDR_WIDTH-1:0]
  .rd_data(w_reg_egr_latency_1_value)  // output[DATA_WIDTH-1:0]
);

reg r_ch_table_init_done;
reg[CHANNEL_WIDTH-1:0] r_ch_table_init_addr;
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_ch_table_init_done <= 1'b0;
    r_ch_table_init_addr <= {CHANNEL_WIDTH{1'b0}};
  end else if (!r_ch_table_init_done) begin
    r_ch_table_init_done <= (r_ch_table_init_addr >= MAX_NUM_CHANNELS - 1);
    r_ch_table_init_addr <= r_ch_table_init_addr + 1;
  end
end

wire w_func_latency_wr_en;
wire[CHANNEL_WIDTH-1:0] w_func_latency_wr_addr;
wire[31:0] w_func_latency_wr_data;
assign w_func_latency_wr_en   = (~r_ch_table_init_done) | func_latency_valid;
assign w_func_latency_wr_addr = r_ch_table_init_done == 1'b0 ? r_ch_table_init_addr : func_latency_data[32+CHANNEL_WIDTH-1:32]; 
assign w_func_latency_wr_data = r_ch_table_init_done == 1'b0 ? 32'd0                : func_latency_data[31:0];
control_s_axi_sdpram #(
  .DATA_WIDTH(32),
  .ADDR_WIDTH(CHANNEL_WIDTH)
) u_ram_func_latency (
  .clk    (ACLK                     ), // input
  .wr_en  (w_func_latency_wr_en     ), // input
  .wr_addr(w_func_latency_wr_addr   ), // input [ADDR_WIDTH-1:0]
  .wr_data(w_func_latency_wr_data   ), // input [DATA_WIDTH-1:0]
  .rd_en  (1'b1                     ), // input
  .rd_addr(r_reg_stat_sel_channel   ), // input [ADDR_WIDTH-1:0]
  .rd_data(w_reg_func_latency_value )  // output[DATA_WIDTH-1:0]
);

wire w_stat_ingr_rcv_data_0_valid = w_stat_ingr_rcv_data_valid & (w_stat_ingr_rcv_data_data[CONNECTION_WIDTH] == 1'b0);
wire w_stat_ingr_rcv_data_0_rdreq;
wire w_stat_ingr_rcv_data_0_rdack_valid;
wire[63:0] w_stat_ingr_rcv_data_0_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CONNECTION_WIDTH ),
  .COUNTER_WIDTH(64               ),
  .ADD_WIDTH    (32               )
) u_stat_ingr_rcv_data_0 (
  .clk        (ACLK                                           ), // input
  .rstn       (ARESET_N                                       ), // input
  .init_done  (/* open */                                     ), // output
  .add_valid  (w_stat_ingr_rcv_data_0_valid                   ), // input
  .add_index  (w_stat_ingr_rcv_data_data[CONNECTION_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
  .add_value  (w_stat_ingr_rcv_data_data[47:16]               ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_ingr_rcv_data_0_rdreq                   ), // input
  .rdreq_index(r_reg_stat_sel_session                         ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_ingr_rcv_data_0_rdack_valid             ), // output
  .rdack_value(w_stat_ingr_rcv_data_0_rdack_value             )  // output[COUNTER_WIDTH-1:0]
);

wire w_stat_ingr_rcv_data_1_valid = w_stat_ingr_rcv_data_valid & (w_stat_ingr_rcv_data_data[CONNECTION_WIDTH] == 1'b1);
wire w_stat_ingr_rcv_data_1_rdreq;
wire w_stat_ingr_rcv_data_1_rdack_valid;
wire[63:0] w_stat_ingr_rcv_data_1_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CONNECTION_WIDTH ),
  .COUNTER_WIDTH(64               ),
  .ADD_WIDTH    (32               )
) u_stat_ingr_rcv_data_1 (
  .clk        (ACLK                                           ), // input
  .rstn       (ARESET_N                                       ), // input
  .init_done  (/* open */                                     ), // output
  .add_valid  (w_stat_ingr_rcv_data_1_valid                   ), // input
  .add_index  (w_stat_ingr_rcv_data_data[CONNECTION_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
  .add_value  (w_stat_ingr_rcv_data_data[47:16]               ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_ingr_rcv_data_1_rdreq                   ), // input
  .rdreq_index(r_reg_stat_sel_session                         ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_ingr_rcv_data_1_rdack_valid             ), // output
  .rdack_value(w_stat_ingr_rcv_data_1_rdack_value             )  // output[COUNTER_WIDTH-1:0]
);

wire w_stat_ingr_snd_data_0_valid = w_stat_ingr_snd_data_ap_vld & (w_stat_ingr_snd_data[CHANNEL_WIDTH] == 1'b0);
wire w_stat_ingr_snd_data_0_rdreq;
wire w_stat_ingr_snd_data_0_rdack_valid;
wire[63:0] w_stat_ingr_snd_data_0_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CHANNEL_WIDTH),
  .COUNTER_WIDTH(64           ),
  .ADD_WIDTH    (8            )
) u_stat_ingr_snd_data_0 (
  .clk        (ACLK                                   ), // input
  .rstn       (ARESET_N                               ), // input
  .init_done  (/* open */                             ), // output
  .add_valid  (w_stat_ingr_snd_data_0_valid           ), // input
  .add_index  (w_stat_ingr_snd_data[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
  .add_value  (w_stat_ingr_snd_data[23:16]            ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_ingr_snd_data_0_rdreq           ), // input
  .rdreq_index(r_reg_stat_sel_channel                 ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_ingr_snd_data_0_rdack_valid     ), // output
  .rdack_value(w_stat_ingr_snd_data_0_rdack_value     )  // output[COUNTER_WIDTH-1:0]
);

wire w_stat_ingr_snd_data_1_valid = w_stat_ingr_snd_data_ap_vld & (w_stat_ingr_snd_data[CHANNEL_WIDTH] == 1'b1);
wire w_stat_ingr_snd_data_1_rdreq;
wire w_stat_ingr_snd_data_1_rdack_valid;
wire[63:0] w_stat_ingr_snd_data_1_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CHANNEL_WIDTH),
  .COUNTER_WIDTH(64           ),
  .ADD_WIDTH    (8            )
) u_stat_ingr_snd_data_1 (
  .clk        (ACLK                                   ), // input
  .rstn       (ARESET_N                               ), // input
  .init_done  (/* open */                             ), // output
  .add_valid  (w_stat_ingr_snd_data_1_valid           ), // input
  .add_index  (w_stat_ingr_snd_data[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
  .add_value  (w_stat_ingr_snd_data[23:16]            ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_ingr_snd_data_1_rdreq           ), // input
  .rdreq_index(r_reg_stat_sel_channel                 ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_ingr_snd_data_1_rdack_valid     ), // output
  .rdack_value(w_stat_ingr_snd_data_1_rdack_value     )  // output[COUNTER_WIDTH-1:0]
);

wire w_stat_egr_rcv_data_0_valid = w_stat_egr_rcv_data_ap_vld & (w_stat_egr_rcv_data[CHANNEL_WIDTH] == 1'b0);
wire w_stat_egr_rcv_data_0_rdreq;
wire w_stat_egr_rcv_data_0_rdack_valid;
wire[63:0] w_stat_egr_rcv_data_0_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CHANNEL_WIDTH),
  .COUNTER_WIDTH(64           ),
  .ADD_WIDTH    (8            )
) u_stat_egr_rcv_data_0 (
  .clk        (ACLK                                   ), // input
  .rstn       (ARESET_N                               ), // input
  .init_done  (/* open */                             ), // output
  .add_valid  (w_stat_egr_rcv_data_0_valid            ), // input
  .add_index  (w_stat_egr_rcv_data[CHANNEL_WIDTH-1:0] ), // input [INDEX_WIDTH-1:0]
  .add_value  (w_stat_egr_rcv_data[23:16]             ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_egr_rcv_data_0_rdreq            ), // input
  .rdreq_index(r_reg_stat_sel_channel                 ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_egr_rcv_data_0_rdack_valid      ), // output
  .rdack_value(w_stat_egr_rcv_data_0_rdack_value      )  // output[COUNTER_WIDTH-1:0]
);

wire w_stat_egr_rcv_data_1_valid = w_stat_egr_rcv_data_ap_vld & (w_stat_egr_rcv_data[CHANNEL_WIDTH] == 1'b1);
wire w_stat_egr_rcv_data_1_rdreq;
wire w_stat_egr_rcv_data_1_rdack_valid;
wire[63:0] w_stat_egr_rcv_data_1_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CHANNEL_WIDTH),
  .COUNTER_WIDTH(64           ),
  .ADD_WIDTH    (8            )
) u_stat_egr_rcv_data_1 (
  .clk        (ACLK                                   ), // input
  .rstn       (ARESET_N                               ), // input
  .init_done  (/* open */                             ), // output
  .add_valid  (w_stat_egr_rcv_data_1_valid            ), // input
  .add_index  (w_stat_egr_rcv_data[CHANNEL_WIDTH-1:0] ), // input [INDEX_WIDTH-1:0]
  .add_value  (w_stat_egr_rcv_data[23:16]             ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_egr_rcv_data_1_rdreq            ), // input
  .rdreq_index(r_reg_stat_sel_channel                 ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_egr_rcv_data_1_rdack_valid      ), // output
  .rdack_value(w_stat_egr_rcv_data_1_rdack_value      )  // output[COUNTER_WIDTH-1:0]
);

wire w_stat_egr_snd_data_0_valid = w_stat_egr_snd_data_ap_vld & (w_stat_egr_snd_data[CONNECTION_WIDTH] == 1'b0);
wire w_stat_egr_snd_data_0_rdreq;
wire w_stat_egr_snd_data_0_rdack_valid;
wire[63:0] w_stat_egr_snd_data_0_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CONNECTION_WIDTH ),
  .COUNTER_WIDTH(64               ),
  .ADD_WIDTH    (32               )
) u_stat_egr_snd_data_0 (
  .clk        (ACLK                                     ), // input
  .rstn       (ARESET_N                                 ), // input
  .init_done  (/* open */                               ), // output
  .add_valid  (w_stat_egr_snd_data_0_valid              ), // input
  .add_index  (w_stat_egr_snd_data[CONNECTION_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
  .add_value  (w_stat_egr_snd_data[47:16]               ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_egr_snd_data_0_rdreq              ), // input
  .rdreq_index(r_reg_stat_sel_session                   ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_egr_snd_data_0_rdack_valid        ), // output
  .rdack_value(w_stat_egr_snd_data_0_rdack_value        )  // output[COUNTER_WIDTH-1:0]
);

wire w_stat_egr_snd_data_1_valid = w_stat_egr_snd_data_ap_vld & (w_stat_egr_snd_data[CONNECTION_WIDTH] == 1'b1);
wire w_stat_egr_snd_data_1_rdreq;
wire w_stat_egr_snd_data_1_rdack_valid;
wire[63:0] w_stat_egr_snd_data_1_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CONNECTION_WIDTH ),
  .COUNTER_WIDTH(64               ),
  .ADD_WIDTH    (32               )
) u_stat_egr_snd_data_1 (
  .clk        (ACLK                                     ), // input
  .rstn       (ARESET_N                                 ), // input
  .init_done  (/* open */                               ), // output
  .add_valid  (w_stat_egr_snd_data_1_valid              ), // input
  .add_index  (w_stat_egr_snd_data[CONNECTION_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
  .add_value  (w_stat_egr_snd_data[47:16]               ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_egr_snd_data_1_rdreq              ), // input
  .rdreq_index(r_reg_stat_sel_session                   ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_egr_snd_data_1_rdack_valid        ), // output
  .rdack_value(w_stat_egr_snd_data_1_rdack_value        )  // output[COUNTER_WIDTH-1:0]
);

wire w_stat_ingr_snd_frame_0_valid = w_stat_ingr_snd_frame_ap_vld & (w_stat_ingr_snd_frame[CHANNEL_WIDTH] == 1'b0);
wire w_stat_ingr_snd_frame_0_rdreq;
wire w_stat_ingr_snd_frame_0_rdack_valid;
wire[31:0] w_stat_ingr_snd_frame_0_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CHANNEL_WIDTH),
  .COUNTER_WIDTH(32           ),
  .ADD_WIDTH    (1            )
) u_stat_ingr_snd_frame_0 (
  .clk        (ACLK                                     ), // input
  .rstn       (ARESET_N                                 ), // input
  .init_done  (/* open */                               ), // output
  .add_valid  (w_stat_ingr_snd_frame_0_valid            ), // input
  .add_index  (w_stat_ingr_snd_frame[CHANNEL_WIDTH-1:0] ), // input [INDEX_WIDTH-1:0]
  .add_value  (1'b1                                     ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_ingr_snd_frame_0_rdreq            ), // input
  .rdreq_index(r_reg_stat_sel_channel                   ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_ingr_snd_frame_0_rdack_valid      ), // output
  .rdack_value(w_stat_ingr_snd_frame_0_rdack_value      )  // output[COUNTER_WIDTH-1:0]
);

wire w_stat_ingr_snd_frame_1_valid = w_stat_ingr_snd_frame_ap_vld & (w_stat_ingr_snd_frame[CHANNEL_WIDTH] == 1'b1);
wire w_stat_ingr_snd_frame_1_rdreq;
wire w_stat_ingr_snd_frame_1_rdack_valid;
wire[31:0] w_stat_ingr_snd_frame_1_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CHANNEL_WIDTH),
  .COUNTER_WIDTH(32           ),
  .ADD_WIDTH    (1            )
) u_stat_ingr_snd_frame_1 (
  .clk        (ACLK                                     ), // input
  .rstn       (ARESET_N                                 ), // input
  .init_done  (/* open */                               ), // output
  .add_valid  (w_stat_ingr_snd_frame_1_valid            ), // input
  .add_index  (w_stat_ingr_snd_frame[CHANNEL_WIDTH-1:0] ), // input [INDEX_WIDTH-1:0]
  .add_value  (1'b1                                     ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_ingr_snd_frame_1_rdreq            ), // input
  .rdreq_index(r_reg_stat_sel_channel                   ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_ingr_snd_frame_1_rdack_valid      ), // output
  .rdack_value(w_stat_ingr_snd_frame_1_rdack_value      )  // output[COUNTER_WIDTH-1:0]
);

wire w_stat_egr_rcv_frame_0_valid = w_stat_egr_rcv_frame_ap_vld & (w_stat_egr_rcv_frame[CHANNEL_WIDTH] == 1'b0);
wire w_stat_egr_rcv_frame_0_rdreq;
wire w_stat_egr_rcv_frame_0_rdack_valid;
wire[31:0] w_stat_egr_rcv_frame_0_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CHANNEL_WIDTH),
  .COUNTER_WIDTH(32           ),
  .ADD_WIDTH    (1            )
) u_stat_egr_rcv_frame_0 (
  .clk        (ACLK                                   ), // input
  .rstn       (ARESET_N                               ), // input
  .init_done  (/* open */                             ), // output
  .add_valid  (w_stat_egr_rcv_frame_0_valid           ), // input
  .add_index  (w_stat_egr_rcv_frame[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
  .add_value  (1'b1                                   ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_egr_rcv_frame_0_rdreq           ), // input
  .rdreq_index(r_reg_stat_sel_channel                 ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_egr_rcv_frame_0_rdack_valid     ), // output
  .rdack_value(w_stat_egr_rcv_frame_0_rdack_value     )  // output[COUNTER_WIDTH-1:0]
);

wire w_stat_egr_rcv_frame_1_valid = w_stat_egr_rcv_frame_ap_vld & (w_stat_egr_rcv_frame[CHANNEL_WIDTH] == 1'b1);
wire w_stat_egr_rcv_frame_1_rdreq;
wire w_stat_egr_rcv_frame_1_rdack_valid;
wire[31:0] w_stat_egr_rcv_frame_1_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CHANNEL_WIDTH),
  .COUNTER_WIDTH(32           ),
  .ADD_WIDTH    (1            )
) u_stat_egr_rcv_frame_1 (
  .clk        (ACLK                                   ), // input
  .rstn       (ARESET_N                               ), // input
  .init_done  (/* open */                             ), // output
  .add_valid  (w_stat_egr_rcv_frame_1_valid           ), // input
  .add_index  (w_stat_egr_rcv_frame[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
  .add_value  (1'b1                                   ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_egr_rcv_frame_1_rdreq           ), // input
  .rdreq_index(r_reg_stat_sel_channel                 ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_egr_rcv_frame_1_rdack_valid     ), // output
  .rdack_value(w_stat_egr_rcv_frame_1_rdack_value     )  // output[COUNTER_WIDTH-1:0]
);

wire w_stat_ingr_discard_data_0_valid = w_stat_ingr_discard_data_ap_vld & (w_stat_ingr_discard_data[CHANNEL_WIDTH] == 1'b0);
wire w_stat_ingr_discard_data_0_rdreq;
wire w_stat_ingr_discard_data_0_rdack_valid;
wire[63:0] w_stat_ingr_discard_data_0_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CHANNEL_WIDTH    ),
  .COUNTER_WIDTH(64               ),
  .ADD_WIDTH    (32               )
) u_stat_ingr_discard_data_0 (
  .clk        (ACLK                                       ), // input
  .rstn       (ARESET_N                                   ), // input
  .init_done  (/* open */                                 ), // output
  .add_valid  (w_stat_ingr_discard_data_0_valid           ), // input
  .add_index  (w_stat_ingr_discard_data[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
  .add_value  (w_stat_ingr_discard_data[47:16]            ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_ingr_discard_data_0_rdreq           ), // input
  .rdreq_index(r_reg_stat_sel_channel                     ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_ingr_discard_data_0_rdack_valid     ), // output
  .rdack_value(w_stat_ingr_discard_data_0_rdack_value     )  // output[COUNTER_WIDTH-1:0]
);

wire w_stat_ingr_discard_data_1_valid = w_stat_ingr_discard_data_ap_vld & (w_stat_ingr_discard_data[CHANNEL_WIDTH] == 1'b1);
wire w_stat_ingr_discard_data_1_rdreq;
wire w_stat_ingr_discard_data_1_rdack_valid;
wire[63:0] w_stat_ingr_discard_data_1_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CHANNEL_WIDTH ),
  .COUNTER_WIDTH(64               ),
  .ADD_WIDTH    (32               )
) u_stat_ingr_discard_data_1 (
  .clk        (ACLK                                       ), // input
  .rstn       (ARESET_N                                   ), // input
  .init_done  (/* open */                                 ), // output
  .add_valid  (w_stat_ingr_discard_data_1_valid           ), // input
  .add_index  (w_stat_ingr_discard_data[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
  .add_value  (w_stat_ingr_discard_data[47:16]            ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_ingr_discard_data_1_rdreq           ), // input
  .rdreq_index(r_reg_stat_sel_channel                     ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_ingr_discard_data_1_rdack_valid     ), // output
  .rdack_value(w_stat_ingr_discard_data_1_rdack_value     )  // output[COUNTER_WIDTH-1:0]
);

wire w_stat_egr_discard_data_0_valid = w_stat_egr_discard_data_ap_vld & (w_stat_egr_discard_data[CHANNEL_WIDTH] == 1'b0);
wire w_stat_egr_discard_data_0_rdreq;
wire w_stat_egr_discard_data_0_rdack_valid;
wire[63:0] w_stat_egr_discard_data_0_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CHANNEL_WIDTH),
  .COUNTER_WIDTH(64           ),
  .ADD_WIDTH    (8            )
) u_stat_egr_discard_data_0 (
  .clk        (ACLK                                       ), // input
  .rstn       (ARESET_N                                   ), // input
  .init_done  (/* open */                                 ), // output
  .add_valid  (w_stat_egr_discard_data_0_valid            ), // input
  .add_index  (w_stat_egr_discard_data[CHANNEL_WIDTH-1:0] ), // input [INDEX_WIDTH-1:0]
  .add_value  (w_stat_egr_discard_data[23:16]             ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_egr_discard_data_0_rdreq            ), // input
  .rdreq_index(r_reg_stat_sel_channel                     ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_egr_discard_data_0_rdack_valid      ), // output
  .rdack_value(w_stat_egr_discard_data_0_rdack_value      )  // output[COUNTER_WIDTH-1:0]
);

wire w_stat_egr_discard_data_1_valid = w_stat_egr_discard_data_ap_vld & (w_stat_egr_discard_data[CHANNEL_WIDTH] == 1'b1);
wire w_stat_egr_discard_data_1_rdreq;
wire w_stat_egr_discard_data_1_rdack_valid;
wire[63:0] w_stat_egr_discard_data_1_rdack_value;
stat_counter_table #(
  .INDEX_WIDTH  (CHANNEL_WIDTH),
  .COUNTER_WIDTH(64           ),
  .ADD_WIDTH    (8            )
) u_stat_egr_discard_data_1 (
  .clk        (ACLK                                       ), // input
  .rstn       (ARESET_N                                   ), // input
  .init_done  (/* open */                                 ), // output
  .add_valid  (w_stat_egr_discard_data_1_valid            ), // input
  .add_index  (w_stat_egr_discard_data[CHANNEL_WIDTH-1:0] ), // input [INDEX_WIDTH-1:0]
  .add_value  (w_stat_egr_discard_data[23:16]             ), // input [ADD_WIDTH-1:0]
  .rdreq_valid(w_stat_egr_discard_data_1_rdreq            ), // input
  .rdreq_index(r_reg_stat_sel_channel                     ), // input [INDEX_WIDTH-1:0]
  .rdack_valid(w_stat_egr_discard_data_1_rdack_valid      ), // output
  .rdack_value(w_stat_egr_discard_data_1_rdack_value      )  // output[COUNTER_WIDTH-1:0]
);

reg r_init_channel_done;
reg[CHANNEL_WIDTH-1:0] r_init_channel;
reg r_ram_stat_header_buff_stored_wr_en;
reg[CHANNEL_WIDTH-1:0] r_ram_stat_header_buff_stored_wr_addr;
reg[3:0] r_ram_stat_header_buff_stored_wr_data;
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_init_channel_done <= 1'b0;
    r_init_channel <= {CHANNEL_WIDTH{1'b0}};
    r_ram_stat_header_buff_stored_wr_en <= 1'b0;
    r_ram_stat_header_buff_stored_wr_addr <= {CHANNEL_WIDTH{1'b0}};
    r_ram_stat_header_buff_stored_wr_data <= 4'd0;
  end else if (!r_init_channel_done) begin
    r_init_channel <= r_init_channel + 1;
    if (r_init_channel >= MAX_NUM_CHANNELS - 1) begin
      r_init_channel_done <= 1'b1;
    end
    r_ram_stat_header_buff_stored_wr_en <= 1'b1;
    r_ram_stat_header_buff_stored_wr_addr <= r_init_channel;
    r_ram_stat_header_buff_stored_wr_data <= 4'd0;
  end else begin
    r_ram_stat_header_buff_stored_wr_en <= w_header_buff_usage_ap_vld;
    r_ram_stat_header_buff_stored_wr_addr <= w_header_buff_usage[16+CHANNEL_WIDTH-1:16];
    r_ram_stat_header_buff_stored_wr_data <= w_header_buff_usage[35:32];
  end
end

control_s_axi_sdpram #(
  .DATA_WIDTH(4),
  .ADDR_WIDTH(CHANNEL_WIDTH)
) u_ram_stat_header_buff_stored (
  .clk    (ACLK                                 ), // input
  .wr_en  (r_ram_stat_header_buff_stored_wr_en  ), // input
  .wr_addr(r_ram_stat_header_buff_stored_wr_addr), // input [ADDR_WIDTH-1:0]
  .wr_data(r_ram_stat_header_buff_stored_wr_data), // input [DATA_WIDTH-1:0]
  .rd_en  (1'b1                                 ), // input
  .rd_addr(r_reg_stat_sel_channel               ), // input [ADDR_WIDTH-1:0]
  .rd_data(w_reg_stat_header_buff_stored        )  // output[DATA_WIDTH-1:0]
);

reg r_header_buff_bp_strb;
reg r_header_buff_bp_value;
reg[CHANNEL_WIDTH-1:0] r_header_buff_bp_channel;
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_header_buff_bp_strb     <= 1'b0;
    r_header_buff_bp_value    <= 1'b0;
    r_header_buff_bp_channel  <= {CHANNEL_WIDTH{1'b0}};
  end else begin
    r_header_buff_bp_strb     <= w_header_buff_usage_ap_vld;
    r_header_buff_bp_value    <= w_header_buff_usage[40];
    r_header_buff_bp_channel  <= w_header_buff_usage[16+CHANNEL_WIDTH-1:16];
  end
end

reg[MAX_NUM_CHANNELS-1:0] r_stat_header_buff_bp_table_raw;
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_stat_header_buff_bp_table_raw <= {MAX_NUM_CHANNELS{1'b0}};
  end else if (r_header_buff_bp_strb) begin
    r_stat_header_buff_bp_table_raw[r_header_buff_bp_channel] <= r_header_buff_bp_value;
  end
end

reg[CHANNEL_WIDTH-1:0] r_stat_sel_channel_d;
reg r_stat_header_buff_bp_clr;
reg[MAX_NUM_CHANNELS-1:0] r_stat_header_buff_bp_table_lat;
always @(posedge ACLK) begin : blk_header_buff_bp_table_lat
  reg[MAX_NUM_CHANNELS-1:0] v_sel_onehot;
  reg[MAX_NUM_CHANNELS-1:0] v_tmp;
  integer v_ch;
  
  for (v_ch = 0; v_ch < MAX_NUM_CHANNELS; v_ch=v_ch+1) begin
    v_sel_onehot[v_ch] = (v_ch == r_stat_sel_channel_d) ? 1'b1 : 1'b0;
  end
  
  if (!ARESET_N) begin
    r_stat_sel_channel_d <= {CHANNEL_WIDTH{1'b0}};
    r_stat_header_buff_bp_clr <= 1'b0;
    r_stat_header_buff_bp_table_lat <= {MAX_NUM_CHANNELS{1'b0}};
    r_stat_header_buff_bp_rdata <= 1'b0;
    r_reg_stat_header_buff_bp <= 1'b0;
  end else begin
    r_stat_sel_channel_d <= r_reg_stat_sel_channel;
    r_stat_header_buff_bp_clr <= (w_hs && waddr == ADDR_STAT_HEADER_BUFF_BP && wmask[0] && WDATA[0]) ? 1'b1 : 1'b0;

    v_tmp = r_stat_header_buff_bp_table_lat;
    if (r_stat_header_buff_bp_clr) begin
      v_tmp = v_tmp & ~ v_sel_onehot;
    end
    v_tmp = v_tmp | r_stat_header_buff_bp_table_raw;
    r_stat_header_buff_bp_table_lat <= v_tmp;
    
    r_stat_header_buff_bp_rdata <= | (r_stat_header_buff_bp_table_lat & v_sel_onehot);
    r_reg_stat_header_buff_bp <= r_stat_header_buff_bp_rdata;
  end
end

reg r_ram_stat_egr_busy_wr_en;
reg[CHANNEL_WIDTH-1:0] r_ram_stat_egr_busy_wr_addr;
reg[7:0] r_ram_stat_egr_busy_wr_data;
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_ram_stat_egr_busy_wr_en <= 1'b0;
    r_ram_stat_egr_busy_wr_addr <= {CHANNEL_WIDTH{1'b0}};
    r_ram_stat_egr_busy_wr_data <= 4'd0;
  end else if (!r_init_channel_done) begin
    r_ram_stat_egr_busy_wr_en <= 1'b1;
    r_ram_stat_egr_busy_wr_addr <= r_init_channel;
    r_ram_stat_egr_busy_wr_data <= 8'd0;
  end else begin
    r_ram_stat_egr_busy_wr_en <= w_egr_busy_count_ap_vld;
    r_ram_stat_egr_busy_wr_addr <= w_egr_busy_count[CHANNEL_WIDTH-1:0];
    r_ram_stat_egr_busy_wr_data <= w_egr_busy_count[23:16];
  end
end

control_s_axi_sdpram #(
  .DATA_WIDTH(8),
  .ADDR_WIDTH(CHANNEL_WIDTH)
) u_ram_stat_egr_busy (
  .clk    (ACLK                       ), // input
  .wr_en  (r_ram_stat_egr_busy_wr_en  ), // input
  .wr_addr(r_ram_stat_egr_busy_wr_addr), // input [ADDR_WIDTH-1:0]
  .wr_data(r_ram_stat_egr_busy_wr_data), // input [DATA_WIDTH-1:0]
  .rd_en  (1'b1                       ), // input
  .rd_addr(r_reg_stat_sel_channel     ), // input [ADDR_WIDTH-1:0]
  .rd_data(w_reg_stat_egr_busy_count  )  // output[DATA_WIDTH-1:0]
);

// ingr_rcv_detect_fault
wire w_ingr_hdr_rmv_fault_0_valid = w_ingr_hdr_rmv_fault_ap_vld && (w_ingr_hdr_rmv_fault[CONNECTION_WIDTH] == 1'b0);
wire w_ingr_hdr_rmv_fault_1_valid = w_ingr_hdr_rmv_fault_ap_vld && (w_ingr_hdr_rmv_fault[CONNECTION_WIDTH] == 1'b1);
wire[CONNECTION_WIDTH-1:0] w_ingr_hdr_rmv_fault_index = w_ingr_hdr_rmv_fault[CONNECTION_WIDTH-1:0];
wire[17:0] w_ingr_hdr_rmv_fault_value; 
assign w_ingr_hdr_rmv_fault_value[11:0]   = w_ingr_hdr_rmv_fault[27:16];
assign w_ingr_hdr_rmv_fault_value[17:12]  = 6'd0;

wire w_ingr_event_fault_0_valid = w_ingr_event_fault_vld && (w_ingr_event_fault[CONNECTION_WIDTH] == 1'b0);
wire w_ingr_event_fault_1_valid = w_ingr_event_fault_vld && (w_ingr_event_fault[CONNECTION_WIDTH] == 1'b1);
wire[CONNECTION_WIDTH-1:0] w_ingr_event_fault_index = w_ingr_event_fault[CONNECTION_WIDTH-1:0];
wire[17:0] w_ingr_event_fault_value;
assign w_ingr_event_fault_value[11:0]   = 12'd0;
assign w_ingr_event_fault_value[13:12]  = w_ingr_event_fault[11:10];
assign w_ingr_event_fault_value[15:14]  = 2'd0;
assign w_ingr_event_fault_value[17:16]  = w_ingr_event_fault[13:12];

wire w_ingr_rcv_detect_fault_0_rdreq;
wire w_ingr_rcv_detect_fault_0_rdack_valid;
wire[17:0] w_ingr_rcv_detect_fault_0_rdack_value;
wire w_ingr_rcv_detect_fault_0_non_zero;
read_clear_flag_table_4 #(
  .INDEX_WIDTH(CONNECTION_WIDTH),
  .DATA_WIDTH (18)
) u_ingr_rcv_detect_fault_0 (
  .clk          (ACLK                                 ), // input
  .rstn         (ARESET_N                             ), // input
  .init_done    (/* open */                           ), // output 
  .in0_valid    (w_ingr_hdr_rmv_fault_0_valid         ), // input
  .in0_index    (w_ingr_hdr_rmv_fault_index           ), // input [INDEX_WIDTH-1:0]
  .in0_value    (w_ingr_hdr_rmv_fault_value           ), // input [DATA_WIDTH-1:0]
  .in1_valid    (w_ingr_event_fault_0_valid           ), // input
  .in1_index    (w_ingr_event_fault_index             ), // input [INDEX_WIDTH-1:0]
  .in1_value    (w_ingr_event_fault_value             ), // input [DATA_WIDTH-1:0]
  .in2_valid    (1'b0                                 ), // input
  .in2_index    ({CONNECTION_WIDTH{1'b0}}             ), // input [INDEX_WIDTH-1:0]
  .in2_value    (18'd0                                ), // input [DATA_WIDTH-1:0]
  .in3_valid    (1'b0                                 ), // input
  .in3_index    ({CONNECTION_WIDTH{1'b0}}             ), // input [INDEX_WIDTH-1:0]
  .in3_value    (18'd0                                ), // input [DATA_WIDTH-1:0]
  .rdreq_valid  (w_ingr_rcv_detect_fault_0_rdreq      ), // input
  .rdreq_index  (r_reg_stat_sel_session               ), // input [INDEX_WIDTH-1:0]
  .rdack_valid  (w_ingr_rcv_detect_fault_0_rdack_valid), // output
  .rdack_value  (w_ingr_rcv_detect_fault_0_rdack_value), // output[DATA_WIDTH-1:0]
  .force_value  (r_reg_ingr_rcv_detect_fault_0_force  ), // input [DATA_WIDTH-1:0]
  .mask_value   (r_reg_ingr_rcv_detect_fault_0_mask   ), // input [DATA_WIDTH-1:0]
  .non_zero     (w_ingr_rcv_detect_fault_0_non_zero   ), // output
  .err_overflow (/* open */                           )  // output
);

wire w_ingr_rcv_detect_fault_1_rdreq;
wire w_ingr_rcv_detect_fault_1_rdack_valid;
wire[17:0] w_ingr_rcv_detect_fault_1_rdack_value;
wire w_ingr_rcv_detect_fault_1_non_zero;
read_clear_flag_table_4 #(
  .INDEX_WIDTH(CONNECTION_WIDTH),
  .DATA_WIDTH (18)
) u_ingr_rcv_detect_fault_1 (
  .clk          (ACLK                                 ), // input
  .rstn         (ARESET_N                             ), // input
  .init_done    (/* open */                           ), // output 
  .in0_valid    (w_ingr_hdr_rmv_fault_1_valid         ), // input
  .in0_index    (w_ingr_hdr_rmv_fault_index           ), // input [INDEX_WIDTH-1:0]
  .in0_value    (w_ingr_hdr_rmv_fault_value           ), // input [DATA_WIDTH-1:0]
  .in1_valid    (w_ingr_event_fault_1_valid           ), // input
  .in1_index    (w_ingr_event_fault_index             ), // input [INDEX_WIDTH-1:0]
  .in1_value    (w_ingr_event_fault_value             ), // input [DATA_WIDTH-1:0]
  .in2_valid    (1'b0                                 ), // input
  .in2_index    ({CONNECTION_WIDTH{1'b0}}             ), // input [INDEX_WIDTH-1:0]
  .in2_value    (18'd0                                ), // input [DATA_WIDTH-1:0]
  .in3_valid    (1'b0                                 ), // input
  .in3_index    ({CONNECTION_WIDTH{1'b0}}             ), // input [INDEX_WIDTH-1:0]
  .in3_value    (18'd0                                ), // input [DATA_WIDTH-1:0]
  .rdreq_valid  (w_ingr_rcv_detect_fault_1_rdreq      ), // input
  .rdreq_index  (r_reg_stat_sel_session               ), // input [INDEX_WIDTH-1:0]
  .rdack_valid  (w_ingr_rcv_detect_fault_1_rdack_valid), // output
  .rdack_value  (w_ingr_rcv_detect_fault_1_rdack_value), // output[DATA_WIDTH-1:0]
  .force_value  (r_reg_ingr_rcv_detect_fault_1_force  ), // input [DATA_WIDTH-1:0]
  .mask_value   (r_reg_ingr_rcv_detect_fault_1_mask   ), // input [DATA_WIDTH-1:0]
  .non_zero     (w_ingr_rcv_detect_fault_1_non_zero   ), // output
  .err_overflow (/* open */                           )  // output
);

// ingr_snd_detect_fault
wire w_ingr_forward_mishit_0_valid = w_ingr_forward_mishit_ap_vld && (w_ingr_forward_mishit[CONNECTION_WIDTH] == 1'b0);
wire w_ingr_forward_mishit_1_valid = w_ingr_forward_mishit_ap_vld && (w_ingr_forward_mishit[CONNECTION_WIDTH] == 1'b1);
wire[CONNECTION_WIDTH-1:0] w_ingr_forward_mishit_index = w_ingr_forward_mishit[CONNECTION_WIDTH-1:0];

wire w_ht_ingr_fw_fault_0_valid = w_ht_ingr_fw_fault_ap_vld && (w_ht_ingr_fw_fault[CONNECTION_WIDTH] == 1'b0);
wire w_ht_ingr_fw_fault_1_valid = w_ht_ingr_fw_fault_ap_vld && (w_ht_ingr_fw_fault[CONNECTION_WIDTH] == 1'b1);
wire[CONNECTION_WIDTH-1:0] w_ht_ingr_fw_fault_index = w_ht_ingr_fw_fault[CONNECTION_WIDTH-1:0];

wire w_ingr_snd_detect_fault_0_rdreq;
wire w_ingr_snd_detect_fault_0_rdack_valid;
wire[16:0] w_ingr_snd_detect_fault_0_rdack_value;
wire w_ingr_snd_detect_fault_0_non_zero;
read_clear_flag_table_4 #(
  .INDEX_WIDTH(CONNECTION_WIDTH),
  .DATA_WIDTH (17)
) u_ingr_snd_detect_fault_0 (
  .clk          (ACLK                                 ), // input
  .rstn         (ARESET_N                             ), // input
  .init_done    (/* open */                           ), // output 
  .in0_valid    (1'b0                                 ), // input
  .in0_index    ({CONNECTION_WIDTH{1'b0}}             ), // input [INDEX_WIDTH-1:0]
  .in0_value    (17'd0                                ), // input [DATA_WIDTH-1:0]
  .in1_valid    (1'b0                                 ), // input
  .in1_index    ({CONNECTION_WIDTH{1'b0}}             ), // input [INDEX_WIDTH-1:0]
  .in1_value    (17'd0                                ), // input [DATA_WIDTH-1:0]
  .in2_valid    (w_ingr_forward_mishit_0_valid        ), // input
  .in2_index    (w_ingr_forward_mishit_index          ), // input [INDEX_WIDTH-1:0]
  .in2_value    (17'h00001                            ), // input [DATA_WIDTH-1:0]
  .in3_valid    (w_ht_ingr_fw_fault_0_valid           ), // input
  .in3_index    (w_ht_ingr_fw_fault_index             ), // input [INDEX_WIDTH-1:0]
  .in3_value    (17'h10000                            ), // input [DATA_WIDTH-1:0]
  .rdreq_valid  (w_ingr_snd_detect_fault_0_rdreq      ), // input
  .rdreq_index  (r_reg_stat_sel_session               ), // input [INDEX_WIDTH-1:0]
  .rdack_valid  (w_ingr_snd_detect_fault_0_rdack_valid), // output
  .rdack_value  (w_ingr_snd_detect_fault_0_rdack_value), // output[DATA_WIDTH-1:0]
  .force_value  (r_reg_ingr_snd_detect_fault_0_force  ), // input [DATA_WIDTH-1:0]
  .mask_value   (r_reg_ingr_snd_detect_fault_0_mask   ), // input [DATA_WIDTH-1:0]
  .non_zero     (w_ingr_snd_detect_fault_0_non_zero   ), // output
  .err_overflow (/* open */                           )  // output
);

wire w_ingr_snd_detect_fault_1_rdreq;
wire w_ingr_snd_detect_fault_1_rdack_valid;
wire[16:0] w_ingr_snd_detect_fault_1_rdack_value;
wire w_ingr_snd_detect_fault_1_non_zero;
read_clear_flag_table_4 #(
  .INDEX_WIDTH(CONNECTION_WIDTH),
  .DATA_WIDTH (17)
) u_ingr_snd_detect_fault_1 (
  .clk          (ACLK                                 ), // input
  .rstn         (ARESET_N                             ), // input
  .init_done    (/* open */                           ), // output 
  .in0_valid    (1'b0                                 ), // input
  .in0_index    ({CONNECTION_WIDTH{1'b0}}             ), // input [INDEX_WIDTH-1:0]
  .in0_value    (17'd0                                ), // input [DATA_WIDTH-1:0]
  .in1_valid    (1'b0                                 ), // input
  .in1_index    ({CONNECTION_WIDTH{1'b0}}             ), // input [INDEX_WIDTH-1:0]
  .in1_value    (17'd0                                ), // input [DATA_WIDTH-1:0]
  .in2_valid    (w_ingr_forward_mishit_1_valid        ), // input
  .in2_index    (w_ingr_forward_mishit_index          ), // input [INDEX_WIDTH-1:0]
  .in2_value    (17'h00001                            ), // input [DATA_WIDTH-1:0]
  .in3_valid    (w_ht_ingr_fw_fault_1_valid           ), // input
  .in3_index    (w_ht_ingr_fw_fault_index             ), // input [INDEX_WIDTH-1:0]
  .in3_value    (17'h10000                            ), // input [DATA_WIDTH-1:0]
  .rdreq_valid  (w_ingr_snd_detect_fault_1_rdreq      ), // input
  .rdreq_index  (r_reg_stat_sel_session               ), // input [INDEX_WIDTH-1:0]
  .rdack_valid  (w_ingr_snd_detect_fault_1_rdack_valid), // output
  .rdack_value  (w_ingr_snd_detect_fault_1_rdack_value), // output[DATA_WIDTH-1:0]
  .force_value  (r_reg_ingr_snd_detect_fault_1_force  ), // input [DATA_WIDTH-1:0]
  .mask_value   (r_reg_ingr_snd_detect_fault_1_mask   ), // input [DATA_WIDTH-1:0]
  .non_zero     (w_ingr_snd_detect_fault_1_non_zero   ), // output
  .err_overflow (/* open */                           )  // output
);

// egr_rcv_detect_fault
wire w_egr_forward_mishit_valid = w_egr_forward_mishit_ap_vld;
wire[CHANNEL_WIDTH-1:0] w_egr_forward_mishit_index = w_egr_forward_mishit[CHANNEL_WIDTH-1:0];

wire w_ht_egr_fw_fault_valid = w_ht_egr_fw_fault_ap_vld;
wire[CHANNEL_WIDTH-1:0] w_ht_egr_fw_fault_index = w_ht_egr_fw_fault[CHANNEL_WIDTH-1:0];

wire w_egr_rcv_detect_fault_rdreq;
wire w_egr_rcv_detect_fault_rdack_valid;
wire[16:0] w_egr_rcv_detect_fault_rdack_value;
wire w_egr_rcv_detect_fault_non_zero;
read_clear_flag_table_4 #(
  .INDEX_WIDTH(CHANNEL_WIDTH),
  .DATA_WIDTH (17)
) u_egr_rcv_detect_fault (
  .clk          (ACLK                                 ), // input
  .rstn         (ARESET_N                             ), // input
  .init_done    (/* open */                           ), // output 
  .in0_valid    (1'b0                                 ), // input
  .in0_index    ({CHANNEL_WIDTH{1'b0}}                ), // input [INDEX_WIDTH-1:0]
  .in0_value    (17'd0                                ), // input [DATA_WIDTH-1:0]
  .in1_valid    (1'b0                                 ), // input
  .in1_index    ({CHANNEL_WIDTH{1'b0}}                ), // input [INDEX_WIDTH-1:0]
  .in1_value    (17'd0                                ), // input [DATA_WIDTH-1:0]
  .in2_valid    (w_egr_forward_mishit_valid           ), // input
  .in2_index    (w_egr_forward_mishit_index           ), // input [INDEX_WIDTH-1:0]
  .in2_value    (17'h00001                            ), // input [DATA_WIDTH-1:0]
  .in3_valid    (w_ht_egr_fw_fault_valid              ), // input
  .in3_index    (w_ht_egr_fw_fault_index              ), // input [INDEX_WIDTH-1:0]
  .in3_value    (17'h10000                            ), // input [DATA_WIDTH-1:0]
  .rdreq_valid  (w_egr_rcv_detect_fault_rdreq         ), // input
  .rdreq_index  (r_reg_stat_sel_channel               ), // input [INDEX_WIDTH-1:0]
  .rdack_valid  (w_egr_rcv_detect_fault_rdack_valid   ), // output
  .rdack_value  (w_egr_rcv_detect_fault_rdack_value   ), // output[DATA_WIDTH-1:0]
  .force_value  (r_reg_egr_rcv_detect_fault_force     ), // input [DATA_WIDTH-1:0]
  .mask_value   (r_reg_egr_rcv_detect_fault_mask      ), // input [DATA_WIDTH-1:0]
  .non_zero     (w_egr_rcv_detect_fault_non_zero      ), // output
  .err_overflow (/* open */                           )  // output
);

// egr_snd_detect_fault
wire w_egr_resp_fault_0_valid = w_egr_resp_fault_ap_vld && (w_egr_resp_fault[CHANNEL_WIDTH] == 1'b0);
wire w_egr_resp_fault_1_valid = w_egr_resp_fault_ap_vld && (w_egr_resp_fault[CHANNEL_WIDTH] == 1'b1);
wire[CHANNEL_WIDTH-1:0] w_egr_resp_fault_index = w_egr_resp_fault[CHANNEL_WIDTH-1:0];
wire[17:0] w_egr_resp_fault_value; 
assign w_egr_resp_fault_value[0]      = 1'b0;
assign w_egr_resp_fault_value[1]      = w_egr_resp_fault[16];
assign w_egr_resp_fault_value[11:2]   = 10'd0;
assign w_egr_resp_fault_value[13:12]  = w_egr_resp_fault[18:17];
assign w_egr_resp_fault_value[15:14]  = 2'd0;
assign w_egr_resp_fault_value[17:16]  = w_egr_resp_fault[20:19];

wire w_egr_snd_detect_fault_0_rdreq;
wire w_egr_snd_detect_fault_0_rdack_valid;
wire[17:0] w_egr_snd_detect_fault_0_rdack_value;
wire w_egr_snd_detect_fault_0_non_zero;
read_clear_flag_table_4 #(
  .INDEX_WIDTH(CHANNEL_WIDTH),
  .DATA_WIDTH (18)
) u_egr_snd_detect_fault_0 (
  .clk          (ACLK                                 ), // input
  .rstn         (ARESET_N                             ), // input
  .init_done    (/* open */                           ), // output 
  .in0_valid    (w_egr_resp_fault_0_valid             ), // input
  .in0_index    (w_egr_resp_fault_index               ), // input [INDEX_WIDTH-1:0]
  .in0_value    (w_egr_resp_fault_value               ), // input [DATA_WIDTH-1:0]
  .in1_valid    (1'b0                                 ), // input
  .in1_index    ({CHANNEL_WIDTH{1'b0}}                ), // input [INDEX_WIDTH-1:0]
  .in1_value    (18'd0                                ), // input [DATA_WIDTH-1:0]
  .in2_valid    (1'b0                                 ), // input
  .in2_index    ({CHANNEL_WIDTH{1'b0}}                ), // input [INDEX_WIDTH-1:0]
  .in2_value    (18'd0                                ), // input [DATA_WIDTH-1:0]
  .in3_valid    (1'b0                                 ), // input
  .in3_index    ({CHANNEL_WIDTH{1'b0}}                ), // input [INDEX_WIDTH-1:0]
  .in3_value    (18'd0                                ), // input [DATA_WIDTH-1:0]
  .rdreq_valid  (w_egr_snd_detect_fault_0_rdreq       ), // input
  .rdreq_index  (r_reg_stat_sel_session               ), // input [INDEX_WIDTH-1:0]
  .rdack_valid  (w_egr_snd_detect_fault_0_rdack_valid ), // output
  .rdack_value  (w_egr_snd_detect_fault_0_rdack_value ), // output[DATA_WIDTH-1:0]
  .force_value  (r_reg_egr_snd_detect_fault_0_force   ), // input [DATA_WIDTH-1:0]
  .mask_value   (r_reg_egr_snd_detect_fault_0_mask    ), // input [DATA_WIDTH-1:0]
  .non_zero     (w_egr_snd_detect_fault_0_non_zero    ), // output
  .err_overflow (/* open */                           )  // output
);

wire w_egr_snd_detect_fault_1_rdreq;
wire w_egr_snd_detect_fault_1_rdack_valid;
wire[17:0] w_egr_snd_detect_fault_1_rdack_value;
wire w_egr_snd_detect_fault_1_non_zero;
read_clear_flag_table_4 #(
  .INDEX_WIDTH(CHANNEL_WIDTH),
  .DATA_WIDTH (18)
) u_egr_snd_detect_fault_1 (
  .clk          (ACLK                                 ), // input
  .rstn         (ARESET_N                             ), // input
  .init_done    (/* open */                           ), // output 
  .in0_valid    (w_egr_resp_fault_1_valid             ), // input
  .in0_index    (w_egr_resp_fault_index               ), // input [INDEX_WIDTH-1:0]
  .in0_value    (w_egr_resp_fault_value               ), // input [DATA_WIDTH-1:0]
  .in1_valid    (1'b0                                 ), // input
  .in1_index    ({CHANNEL_WIDTH{1'b0}}                ), // input [INDEX_WIDTH-1:0]
  .in1_value    (18'd0                                ), // input [DATA_WIDTH-1:0]
  .in2_valid    (1'b0                                 ), // input
  .in2_index    ({CHANNEL_WIDTH{1'b0}}                ), // input [INDEX_WIDTH-1:0]
  .in2_value    (18'd0                                ), // input [DATA_WIDTH-1:0]
  .in3_valid    (1'b0                                 ), // input
  .in3_index    ({CHANNEL_WIDTH{1'b0}}                ), // input [INDEX_WIDTH-1:0]
  .in3_value    (18'd0                                ), // input [DATA_WIDTH-1:0]
  .rdreq_valid  (w_egr_snd_detect_fault_1_rdreq       ), // input
  .rdreq_index  (r_reg_stat_sel_session               ), // input [INDEX_WIDTH-1:0]
  .rdack_valid  (w_egr_snd_detect_fault_1_rdack_valid ), // output
  .rdack_value  (w_egr_snd_detect_fault_1_rdack_value ), // output[DATA_WIDTH-1:0]
  .force_value  (r_reg_egr_snd_detect_fault_1_force   ), // input [DATA_WIDTH-1:0]
  .mask_value   (r_reg_egr_snd_detect_fault_1_mask    ), // input [DATA_WIDTH-1:0]
  .non_zero     (w_egr_snd_detect_fault_1_non_zero    ), // output
  .err_overflow (/* open */                           )  // output
);

assign w_stat_ingr_rcv_data_0_rdreq     = ar_hs && (raddr == ADDR_STAT_INGR_RCV_DATA_0_VALUE_L    );
assign w_stat_ingr_rcv_data_1_rdreq     = ar_hs && (raddr == ADDR_STAT_INGR_RCV_DATA_1_VALUE_L    );
assign w_stat_ingr_snd_data_0_rdreq     = ar_hs && (raddr == ADDR_STAT_INGR_SND_DATA_0_VALUE_L    );
assign w_stat_ingr_snd_data_1_rdreq     = ar_hs && (raddr == ADDR_STAT_INGR_SND_DATA_1_VALUE_L    );
assign w_stat_egr_rcv_data_0_rdreq      = ar_hs && (raddr == ADDR_STAT_EGR_RCV_DATA_0_VALUE_L     );
assign w_stat_egr_rcv_data_1_rdreq      = ar_hs && (raddr == ADDR_STAT_EGR_RCV_DATA_1_VALUE_L     );
assign w_stat_egr_snd_data_0_rdreq      = ar_hs && (raddr == ADDR_STAT_EGR_SND_DATA_0_VALUE_L     );
assign w_stat_egr_snd_data_1_rdreq      = ar_hs && (raddr == ADDR_STAT_EGR_SND_DATA_1_VALUE_L     );
assign w_stat_ingr_snd_frame_0_rdreq    = ar_hs && (raddr == ADDR_STAT_INGR_SND_FRAME_0_VALUE     );
assign w_stat_ingr_snd_frame_1_rdreq    = ar_hs && (raddr == ADDR_STAT_INGR_SND_FRAME_1_VALUE     );
assign w_stat_egr_rcv_frame_0_rdreq     = ar_hs && (raddr == ADDR_STAT_EGR_RCV_FRAME_0_VALUE      );
assign w_stat_egr_rcv_frame_1_rdreq     = ar_hs && (raddr == ADDR_STAT_EGR_RCV_FRAME_1_VALUE      );
assign w_stat_ingr_discard_data_0_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_DISCARD_DATA_0_VALUE_L);
assign w_stat_ingr_discard_data_1_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_DISCARD_DATA_1_VALUE_L);
assign w_stat_egr_discard_data_0_rdreq  = ar_hs && (raddr == ADDR_STAT_EGR_DISCARD_DATA_0_VALUE_L );
assign w_stat_egr_discard_data_1_rdreq  = ar_hs && (raddr == ADDR_STAT_EGR_DISCARD_DATA_1_VALUE_L );
assign w_ingr_rcv_detect_fault_0_rdreq  = ar_hs && (raddr == ADDR_INGR_RCV_DETECT_FAULT_0_VALUE   );
assign w_ingr_rcv_detect_fault_1_rdreq  = ar_hs && (raddr == ADDR_INGR_RCV_DETECT_FAULT_1_VALUE   );
assign w_ingr_snd_detect_fault_0_rdreq  = ar_hs && (raddr == ADDR_INGR_SND_DETECT_FAULT_0_VALUE   );
assign w_ingr_snd_detect_fault_1_rdreq  = ar_hs && (raddr == ADDR_INGR_SND_DETECT_FAULT_1_VALUE   );
assign w_egr_rcv_detect_fault_rdreq     = ar_hs && (raddr == ADDR_EGR_RCV_DETECT_FAULT_VALUE      );
assign w_egr_snd_detect_fault_0_rdreq   = ar_hs && (raddr == ADDR_EGR_SND_DETECT_FAULT_0_VALUE    );
assign w_egr_snd_detect_fault_1_rdreq   = ar_hs && (raddr == ADDR_EGR_SND_DETECT_FAULT_1_VALUE    );

assign w_stat_rdreq = | {
  w_stat_ingr_rcv_data_0_rdreq    ,
  w_stat_ingr_rcv_data_1_rdreq    ,
  w_stat_ingr_snd_data_0_rdreq    ,
  w_stat_ingr_snd_data_1_rdreq    ,
  w_stat_egr_rcv_data_0_rdreq     ,
  w_stat_egr_rcv_data_1_rdreq     ,
  w_stat_egr_snd_data_0_rdreq     ,
  w_stat_egr_snd_data_1_rdreq     ,
  w_stat_ingr_snd_frame_0_rdreq   ,
  w_stat_ingr_snd_frame_1_rdreq   ,
  w_stat_egr_rcv_frame_0_rdreq    ,
  w_stat_egr_rcv_frame_1_rdreq    ,
  w_stat_ingr_discard_data_0_rdreq,
  w_stat_ingr_discard_data_1_rdreq,
  w_stat_egr_discard_data_0_rdreq ,
  w_stat_egr_discard_data_1_rdreq ,
  w_ingr_rcv_detect_fault_0_rdreq ,
  w_ingr_rcv_detect_fault_1_rdreq ,
  w_ingr_snd_detect_fault_0_rdreq ,
  w_ingr_snd_detect_fault_1_rdreq ,
  w_egr_rcv_detect_fault_rdreq    ,
  w_egr_snd_detect_fault_0_rdreq  ,
  w_egr_snd_detect_fault_1_rdreq
};

assign w_stat_rdack_valid = | {
  w_stat_ingr_rcv_data_0_rdack_valid    ,
  w_stat_ingr_rcv_data_1_rdack_valid    ,
  w_stat_ingr_snd_data_0_rdack_valid    ,
  w_stat_ingr_snd_data_1_rdack_valid    ,
  w_stat_egr_rcv_data_0_rdack_valid     ,
  w_stat_egr_rcv_data_1_rdack_valid     ,
  w_stat_egr_snd_data_0_rdack_valid     ,
  w_stat_egr_snd_data_1_rdack_valid     ,
  w_stat_ingr_snd_frame_0_rdack_valid   ,
  w_stat_ingr_snd_frame_1_rdack_valid   ,
  w_stat_egr_rcv_frame_0_rdack_valid    ,
  w_stat_egr_rcv_frame_1_rdack_valid    ,
  w_stat_ingr_discard_data_0_rdack_valid,
  w_stat_ingr_discard_data_1_rdack_valid,
  w_stat_egr_discard_data_0_rdack_valid ,
  w_stat_egr_discard_data_1_rdack_valid ,
  w_ingr_rcv_detect_fault_0_rdack_valid ,
  w_ingr_rcv_detect_fault_1_rdack_valid ,
  w_ingr_snd_detect_fault_0_rdack_valid ,
  w_ingr_snd_detect_fault_1_rdack_valid ,
  w_egr_rcv_detect_fault_rdack_valid    ,
  w_egr_snd_detect_fault_0_rdack_valid  ,
  w_egr_snd_detect_fault_1_rdack_valid
};

always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_stat_rdack_valid <= 1'b0;
  end else begin
    r_stat_rdack_valid <= w_stat_rdack_valid;
  end
end

always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_stat_rdack_value <= 64'd0;
  end else if (w_stat_rdack_valid) begin
    r_stat_rdack_value <=
      ({64{w_stat_ingr_rcv_data_0_rdack_valid    }} & w_stat_ingr_rcv_data_0_rdack_value            ) |
      ({64{w_stat_ingr_rcv_data_1_rdack_valid    }} & w_stat_ingr_rcv_data_1_rdack_value            ) |
      ({64{w_stat_ingr_snd_data_0_rdack_valid    }} & w_stat_ingr_snd_data_0_rdack_value            ) |
      ({64{w_stat_ingr_snd_data_1_rdack_valid    }} & w_stat_ingr_snd_data_1_rdack_value            ) |
      ({64{w_stat_egr_rcv_data_0_rdack_valid     }} & w_stat_egr_rcv_data_0_rdack_value             ) |
      ({64{w_stat_egr_rcv_data_1_rdack_valid     }} & w_stat_egr_rcv_data_1_rdack_value             ) |
      ({64{w_stat_egr_snd_data_0_rdack_valid     }} & w_stat_egr_snd_data_0_rdack_value             ) |
      ({64{w_stat_egr_snd_data_1_rdack_valid     }} & w_stat_egr_snd_data_1_rdack_value             ) |
      ({64{w_stat_ingr_snd_frame_0_rdack_valid   }} & {32'd0, w_stat_ingr_snd_frame_0_rdack_value  }) |
      ({64{w_stat_ingr_snd_frame_1_rdack_valid   }} & {32'd0, w_stat_ingr_snd_frame_1_rdack_value  }) |
      ({64{w_stat_egr_rcv_frame_0_rdack_valid    }} & {32'd0, w_stat_egr_rcv_frame_0_rdack_value   }) |
      ({64{w_stat_egr_rcv_frame_1_rdack_valid    }} & {32'd0, w_stat_egr_rcv_frame_1_rdack_value   }) |
      ({64{w_stat_ingr_discard_data_0_rdack_valid}} & w_stat_ingr_discard_data_0_rdack_value        ) |
      ({64{w_stat_ingr_discard_data_1_rdack_valid}} & w_stat_ingr_discard_data_1_rdack_value        ) |
      ({64{w_stat_egr_discard_data_0_rdack_valid }} & w_stat_egr_discard_data_0_rdack_value         ) |
      ({64{w_stat_egr_discard_data_1_rdack_valid }} & w_stat_egr_discard_data_1_rdack_value         ) |
      ({64{w_ingr_rcv_detect_fault_0_rdack_valid }} & {46'd0, w_ingr_rcv_detect_fault_0_rdack_value}) |
      ({64{w_ingr_rcv_detect_fault_1_rdack_valid }} & {46'd0, w_ingr_rcv_detect_fault_1_rdack_value}) |
      ({64{w_ingr_snd_detect_fault_0_rdack_valid }} & {47'd0, w_ingr_snd_detect_fault_0_rdack_value}) |
      ({64{w_ingr_snd_detect_fault_1_rdack_valid }} & {47'd0, w_ingr_snd_detect_fault_1_rdack_value}) |
      ({64{w_egr_rcv_detect_fault_rdack_valid    }} & {47'd0, w_egr_rcv_detect_fault_rdack_value   }) |
      ({64{w_egr_snd_detect_fault_0_rdack_valid  }} & {46'd0, w_egr_snd_detect_fault_0_rdack_value }) |
      ({64{w_egr_snd_detect_fault_1_rdack_valid  }} & {46'd0, w_egr_snd_detect_fault_1_rdack_value });
  end
end

wire w_extif0_egr_last_ptr_ap_vld = w_egr_last_ptr_ap_vld & (w_egr_last_ptr[64+CONNECTION_WIDTH] == 1'b0);
wire[63:0] w_extif0_egr_last_ptr_value;
control_s_axi_sdpram #(
  .DATA_WIDTH(64),
  .ADDR_WIDTH(CONNECTION_WIDTH)
) u_ram_extif0_egr_last_ptr (
  .clk    (ACLK                                     ), // input
  .wr_en  (w_extif0_egr_last_ptr_ap_vld             ), // input
  .wr_addr(w_egr_last_ptr[64+CONNECTION_WIDTH-1:64] ), // input [ADDR_WIDTH-1:0]
  .wr_data(w_egr_last_ptr[63:0]                     ), // input [DATA_WIDTH-1:0]
  .rd_en  (1'b1                                     ), // input
  .rd_addr(r_reg_dbg_sel_session                    ), // input [ADDR_WIDTH-1:0]
  .rd_data(w_extif0_egr_last_ptr_value              )  // output[DATA_WIDTH-1:0]
);
assign w_reg_extif0_egr_last_wr_ptr = w_extif0_egr_last_ptr_value[31:0];
assign w_reg_extif0_egr_last_rd_ptr = w_extif0_egr_last_ptr_value[63:32];

wire w_extif1_egr_last_ptr_ap_vld = w_egr_last_ptr_ap_vld & (w_egr_last_ptr[64+CONNECTION_WIDTH] == 1'b1);
wire[63:0] w_extif1_egr_last_ptr_value;
control_s_axi_sdpram #(
  .DATA_WIDTH(64),
  .ADDR_WIDTH(CONNECTION_WIDTH)
) u_ram_extif1_egr_last_ptr (
  .clk    (ACLK                                     ), // input
  .wr_en  (w_extif1_egr_last_ptr_ap_vld             ), // input
  .wr_addr(w_egr_last_ptr[64+CONNECTION_WIDTH-1:64] ), // input [ADDR_WIDTH-1:0]
  .wr_data(w_egr_last_ptr[63:0]                     ), // input [DATA_WIDTH-1:0]
  .rd_en  (1'b1                                     ), // input
  .rd_addr(r_reg_dbg_sel_session                    ), // input [ADDR_WIDTH-1:0]
  .rd_data(w_extif1_egr_last_ptr_value              )  // output[DATA_WIDTH-1:0]
);
assign w_reg_extif1_egr_last_wr_ptr = w_extif1_egr_last_ptr_value[31:0];
assign w_reg_extif1_egr_last_rd_ptr = w_extif1_egr_last_ptr_value[63:32];

reg r_fault_or;
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_fault_or <= 1'b0;
    r_reg_detect_fault <= 1'b0;
  end else begin
    r_fault_or <= | {
      w_ingr_rcv_detect_fault_0_non_zero,
      w_ingr_rcv_detect_fault_1_non_zero,
      w_ingr_snd_detect_fault_0_non_zero,
      w_ingr_snd_detect_fault_1_non_zero,
      w_egr_rcv_detect_fault_non_zero   ,
      w_egr_snd_detect_fault_0_non_zero ,
      w_egr_snd_detect_fault_1_non_zero ,
      r_reg_ingr_snd_protocol_fault     ,
      r_reg_egr_rcv_protocol_fault      ,
      r_reg_extif0_event_fault          ,
      r_reg_extif1_event_fault
    };
    r_reg_detect_fault <= r_fault_or;
  end
end

assign detect_fault = r_reg_detect_fault;

reg[1023:0] w_ingr_reg_out;
always @(*) begin
  w_ingr_reg_out = 1024'd0;
  w_ingr_reg_out[0:0] = r_reg_control;
  w_ingr_reg_out[95:32] = {r_reg_m_axi_extif0_buffer_base_h, r_reg_m_axi_extif0_buffer_base_l};
  w_ingr_reg_out[159:96] = {r_reg_m_axi_extif1_buffer_base_h, r_reg_m_axi_extif1_buffer_base_l};
  w_ingr_reg_out[223:160] = {r_reg_m_axi_extif0_buffer_rx_offset_h, r_reg_m_axi_extif0_buffer_rx_offset_l};
  w_ingr_reg_out[255:224] = r_reg_m_axi_extif0_buffer_rx_stride;
  w_ingr_reg_out[263:256] = r_reg_m_axi_extif0_buffer_rx_size;
  w_ingr_reg_out[351:288] = {r_reg_m_axi_extif1_buffer_rx_offset_h, r_reg_m_axi_extif1_buffer_rx_offset_l};
  w_ingr_reg_out[383:352] = r_reg_m_axi_extif1_buffer_rx_stride;
  w_ingr_reg_out[391:384] = r_reg_m_axi_extif1_buffer_rx_size;
  w_ingr_reg_out[447:416] = r_reg_ingr_forward_update_req;
  w_ingr_reg_out[479:448] = r_reg_ingr_forward_session;
  w_ingr_reg_out[511:480] = r_reg_ingr_forward_channel;
  w_ingr_reg_out[519:512] = {2'd0, r_reg_ingr_rcv_insert_fault_1[1:0], 2'd0, r_reg_ingr_rcv_insert_fault_0[1:0]};
  w_ingr_reg_out[551:544] = {3'd0, r_reg_ingr_rcv_insert_fault_1[2], 3'd0, r_reg_ingr_rcv_insert_fault_0[2]};
  w_ingr_reg_out[607:576] = r_reg_ingr_snd_insert_protocol_fault;
  w_ingr_reg_out[639:608] = r_reg_extif0_insert_command_fault;
  w_ingr_reg_out[671:640] = r_reg_extif1_insert_command_fault;
  w_ingr_reg_out[687:672] = {7'd0, r_reg_dbg_sel_session};
  w_ingr_reg_out[719:704] = {7'd0, r_reg_stat_sel_session};
end
assign ingr_reg_out = w_ingr_reg_out;

reg[1023:0] w_egr_reg_out;
always @(*) begin
  w_egr_reg_out = 1024'd0;
  w_egr_reg_out[0:0] = r_reg_control;
  w_egr_reg_out[95:32] = {r_reg_m_axi_extif0_buffer_base_h, r_reg_m_axi_extif0_buffer_base_l};
  w_egr_reg_out[159:96] = {r_reg_m_axi_extif1_buffer_base_h, r_reg_m_axi_extif1_buffer_base_l};
  w_egr_reg_out[223:160] = {r_reg_m_axi_extif0_buffer_tx_offset_h, r_reg_m_axi_extif0_buffer_tx_offset_l};
  w_egr_reg_out[255:224] = r_reg_m_axi_extif0_buffer_tx_stride;
  w_egr_reg_out[263:256] = r_reg_m_axi_extif0_buffer_tx_size;
  w_egr_reg_out[351:288] = {r_reg_m_axi_extif1_buffer_tx_offset_h, r_reg_m_axi_extif1_buffer_tx_offset_l};
  w_egr_reg_out[383:352] = r_reg_m_axi_extif1_buffer_tx_stride;
  w_egr_reg_out[391:384] = r_reg_m_axi_extif1_buffer_tx_size;
  w_egr_reg_out[447:416] = r_reg_egr_forward_update_req;
  w_egr_reg_out[479:448] = r_reg_egr_forward_channel;
  w_egr_reg_out[511:480] = r_reg_egr_forward_session;
  w_egr_reg_out[543:512] = {4'd0, r_reg_egr_snd_insert_fault_1[11:0], 4'd0, r_reg_egr_snd_insert_fault_0[11:0]};
  w_egr_reg_out[551:544] = {2'd0, r_reg_egr_snd_insert_fault_1[17:16], 2'd0, r_reg_egr_snd_insert_fault_0[17:16]};
  w_egr_reg_out[583:576] = {3'd0, r_reg_egr_snd_insert_fault_1[18], 3'd0, r_reg_egr_snd_insert_fault_0[18]};
  w_egr_reg_out[639:608] = r_reg_egr_rcv_insert_protocol_fault;
  w_egr_reg_out[671:640] = r_reg_extif0_insert_command_fault;
  w_egr_reg_out[703:672] = r_reg_extif1_insert_command_fault;
end
assign egr_reg_out = w_egr_reg_out;

endmodule

module control_s_axi_sdpram #(
  parameter integer DATA_WIDTH  = 32,
  parameter integer ADDR_WIDTH  = 10,
  parameter integer DEPTH       = 1 << ADDR_WIDTH
) (
  input   wire                    clk     ,
  input   wire                    wr_en   ,
  input   wire[ADDR_WIDTH-1:0]    wr_addr ,
  input   wire[DATA_WIDTH-1:0]    wr_data ,
  input   wire                    rd_en   ,
  input   wire[ADDR_WIDTH-1:0]    rd_addr ,
  output  wire[DATA_WIDTH-1:0]    rd_data
);

reg[DATA_WIDTH-1:0] mem [0:DEPTH-1];

reg r_wr_en;
reg[ADDR_WIDTH-1:0] r_wr_addr;
reg[DATA_WIDTH-1:0] r_wr_data;
always @(posedge clk) begin
  r_wr_en <= wr_en;
  r_wr_addr <= wr_addr;
  r_wr_data <= wr_data;
end

always @(posedge clk) begin
  if (r_wr_en) begin
    mem[r_wr_addr] <= r_wr_data;
  end
end

reg[ADDR_WIDTH-1:0] r_rd_addr;
reg[DATA_WIDTH-1:0] r_rd_data;
always @(posedge clk) begin
  if (rd_en) begin
    r_rd_addr <= rd_addr;
    r_rd_data <= mem[r_rd_addr];
  end
end
assign rd_data = r_rd_data;

endmodule

`default_nettype wire
