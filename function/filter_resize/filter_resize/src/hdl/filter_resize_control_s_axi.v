/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`default_nettype none

`timescale 1ns/1ps
module filter_resize_control_s_axi
#(parameter integer 
    C_S_AXI_ADDR_WIDTH = 10,
    C_S_AXI_DATA_WIDTH = 32
)(
    input  wire                          ACLK,
    input  wire                          ARESET_N,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] AWADDR,
    input  wire                          AWVALID,
    output wire                          AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] WDATA,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0] WSTRB,
    input  wire                          WVALID,
    output wire                          WREADY,
    output wire [1:0]                    BRESP,
    output wire                          BVALID,
    input  wire                          BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] ARADDR,
    input  wire                          ARVALID,
    output wire                          ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0] RDATA,
    output wire [1:0]                    RRESP,
    output wire                          RVALID,
    input  wire                          RREADY,
    output wire                          detect_fault,
    input  wire [31:0]                   module_id,
    input  wire [31:0]                   local_version,
    output wire [31:0]                   rows_in,
    output wire [31:0]                   cols_in,
    output wire [31:0]                   rows_out,
    output wire [31:0]                   cols_out,
    input  wire [23:0]                   ingr_stat_data_0,
    input  wire                          ingr_stat_data_0_vld,
    input  wire [23:0]                   ingr_stat_frame_0,
    input  wire                          ingr_stat_frame_0_vld,
    input  wire [23:0]                   ingr_stat_data_1,
    input  wire                          ingr_stat_data_1_vld,
    input  wire [23:0]                   ingr_stat_frame_1,
    input  wire                          ingr_stat_frame_1_vld,
    input  wire [23:0]                   egr_stat_data_0,
    input  wire                          egr_stat_data_0_vld,
    input  wire [23:0]                   egr_stat_frame_0,
    input  wire                          egr_stat_frame_0_vld,
    input  wire [23:0]                   egr_stat_data_1,
    input  wire                          egr_stat_data_1_vld,
    input  wire [23:0]                   egr_stat_frame_1,
    input  wire                          egr_stat_frame_1_vld,
    input  wire [15:0]                   ingr_protocol_error_0,
    input  wire                          ingr_protocol_error_0_vld,
    input  wire [15:0]                   ingr_protocol_error_1,
    input  wire                          ingr_protocol_error_1_vld,
    input  wire [15:0]                   egr_protocol_error_0,
    input  wire                          egr_protocol_error_0_vld,
    input  wire [15:0]                   egr_protocol_error_1,
    input  wire                          egr_protocol_error_1_vld,
    input  wire [11:0]                   streamif_stall,
    output  wire [4:0]                   insert_protocol_fault_resp_0,
    output  wire                         insert_protocol_fault_req_0,
    output  wire                         insert_protocol_fault_data_0,
    output  wire [4:0]                   insert_protocol_fault_resp_1,
    output  wire                         insert_protocol_fault_req_1,
    output  wire                         insert_protocol_fault_data_1,
    input  wire [31:0]                   rx_rcv_req_0,
    input  wire [31:0]                   rx_snd_resp_0,
    input  wire [31:0]                   rx_rcv_sof_0,
    input  wire [31:0]                   rx_rcv_cid_diff_0,
    input  wire [31:0]                   rx_rcv_line_chk_0,
    input  wire [31:0]                   rx_rcv_data_0,
    input  wire [31:0]                   rx_rcv_length_chk_0,
    input  wire [31:0]                   tx_snd_req_0,
    input  wire [31:0]                   tx_rcv_resp_0,
    input  wire [31:0]                   tx_snd_data_0,
    input  wire [31:0]                   rx_rcv_req_1,
    input  wire [31:0]                   rx_snd_resp_1,
    input  wire [31:0]                   rx_rcv_sof_1,
    input  wire [31:0]                   rx_rcv_cid_diff_1,
    input  wire [31:0]                   rx_rcv_line_chk_1,
    input  wire [31:0]                   rx_rcv_data_1,
    input  wire [31:0]                   rx_rcv_length_chk_1,
    input  wire [31:0]                   tx_snd_req_1,
    input  wire [31:0]                   tx_rcv_resp_1,
    input  wire [31:0]                   tx_snd_data_1,
    output wire                          ap_start
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

localparam[ADDR_BITS-1:0] ADDR_CONTROL                           = 10'h000; // R/W
localparam[ADDR_BITS-1:0] ADDR_MODULE_ID                         = 10'h010; // R
localparam[ADDR_BITS-1:0] ADDR_LOCAL_VERSION                     = 10'h020; // R
localparam[ADDR_BITS-1:0] ADDR_ROWS_IN                           = 10'h030; // R/W
localparam[ADDR_BITS-1:0] ADDR_COLS_IN                           = 10'h034; // R/W
localparam[ADDR_BITS-1:0] ADDR_ROWS_OUT                          = 10'h038; // R/W
localparam[ADDR_BITS-1:0] ADDR_COLS_OUT                          = 10'h03C; // R/W
localparam[ADDR_BITS-1:0] ADDR_STAT_SEL_CHANNEL                  = 10'h040; // R/W
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_DATA_0_VALUE_L      = 10'h050; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_DATA_0_VALUE_H      = 10'h054; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_DATA_1_VALUE_L      = 10'h058; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_DATA_1_VALUE_H      = 10'h05C; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_SND_DATA_0_VALUE_L       = 10'h060; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_SND_DATA_0_VALUE_H       = 10'h064; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_SND_DATA_1_VALUE_L       = 10'h068; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_SND_DATA_1_VALUE_H       = 10'h06C; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_FRAME_0_VALUE       = 10'h070; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_FRAME_1_VALUE       = 10'h074; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_SND_FRAME_0_VALUE        = 10'h078; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_SND_FRAME_1_VALUE        = 10'h07C; // RC
localparam[ADDR_BITS-1:0] ADDR_DETECT_FAULT                      = 10'h100; // R
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_PROTOCOL_FAULT_0         = 10'h110; // R/WC
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_PROTOCOL_FAULT_0_MASK    = 10'h118; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_PROTOCOL_FAULT_0_FORCE   = 10'h11C; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_PROTOCOL_FAULT_1         = 10'h120; // R/WC
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_PROTOCOL_FAULT_1_MASK    = 10'h128; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_PROTOCOL_FAULT_1_FORCE   = 10'h12C; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_PROTOCOL_FAULT_0          = 10'h130; // R/WC
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_PROTOCOL_FAULT_0_MASK     = 10'h138; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_PROTOCOL_FAULT_0_FORCE    = 10'h13C; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_PROTOCOL_FAULT_1          = 10'h140; // R/WC
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_PROTOCOL_FAULT_1_MASK     = 10'h148; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_PROTOCOL_FAULT_1_FORCE    = 10'h14C; // R/W
localparam[ADDR_BITS-1:0] ADDR_STREAMIF_STALL                    = 10'h150; // R
localparam[ADDR_BITS-1:0] ADDR_STREAMIF_STALL_MASK               = 10'h158; // R/W
localparam[ADDR_BITS-1:0] ADDR_STREAMIF_STALL_FORCE              = 10'h15C; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_INSERT_PROTOCOL_FAULT_0  = 10'h180; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_INSERT_PROTOCOL_FAULT_1  = 10'h184; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_INSERT_PROTOCOL_FAULT_0   = 10'h188; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_INSERT_PROTOCOL_FAULT_1   = 10'h18C; // R/W
localparam[ADDR_BITS-1:0] ADDR_RX_RCV_REQ_0                      = 10'h200; // R
localparam[ADDR_BITS-1:0] ADDR_RX_SND_RESP_0                     = 10'h204; // R
localparam[ADDR_BITS-1:0] ADDR_RX_RCV_SOF_0                      = 10'h208; // R
localparam[ADDR_BITS-1:0] ADDR_RX_RCV_CID_DIFF_0                 = 10'h20C; // R
localparam[ADDR_BITS-1:0] ADDR_RX_RCV_LINE_CHK_0                 = 10'h210; // R
localparam[ADDR_BITS-1:0] ADDR_RX_RCV_DATA_0                     = 10'h214; // R
localparam[ADDR_BITS-1:0] ADDR_RX_RCV_LENGTH_CHK_0               = 10'h218; // R
localparam[ADDR_BITS-1:0] ADDR_TX_SND_REQ_0                      = 10'h21C; // R
localparam[ADDR_BITS-1:0] ADDR_TX_RCV_RESP_0                     = 10'h220; // R
localparam[ADDR_BITS-1:0] ADDR_TX_SND_DATA_0                     = 10'h224; // R
localparam[ADDR_BITS-1:0] ADDR_RX_RCV_REQ_1                      = 10'h228; // R
localparam[ADDR_BITS-1:0] ADDR_RX_SND_RESP_1                     = 10'h22C; // R
localparam[ADDR_BITS-1:0] ADDR_RX_RCV_SOF_1                      = 10'h230; // R
localparam[ADDR_BITS-1:0] ADDR_RX_RCV_CID_DIFF_1                 = 10'h234; // R
localparam[ADDR_BITS-1:0] ADDR_RX_RCV_LINE_CHK_1                 = 10'h238; // R
localparam[ADDR_BITS-1:0] ADDR_RX_RCV_DATA_1                     = 10'h23C; // R
localparam[ADDR_BITS-1:0] ADDR_RX_RCV_LENGTH_CHK_1               = 10'h240; // R
localparam[ADDR_BITS-1:0] ADDR_TX_SND_REQ_1                      = 10'h244; // R
localparam[ADDR_BITS-1:0] ADDR_TX_RCV_RESP_1                     = 10'h248; // R
localparam[ADDR_BITS-1:0] ADDR_TX_SND_DATA_1                     = 10'h24C; // R

localparam integer CHANNEL_WIDTH = 9;
localparam[31:0] CHANNEL_MASK = (1 << CHANNEL_WIDTH) - 1;

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
wire                          ar_hs;
wire[ADDR_BITS-1:0]           raddr;

// internal registers
reg       r_reg_control                          ; // R/W
reg[31:0] r_reg_rows_in                          ; // R/W
reg[31:0] r_reg_cols_in                          ; // R/W
reg[31:0] r_reg_rows_out                         ; // R/W
reg[31:0] r_reg_cols_out                         ; // R/W
reg[31:0] r_reg_stat_sel_channel                 ; // R/W
reg[31:0] r_reg_stat_ingr_rcv_data_0_value_l     ; // RC
reg[31:0] r_reg_stat_ingr_rcv_data_0_value_h     ; // RC
reg[31:0] r_reg_stat_ingr_rcv_data_1_value_l     ; // RC
reg[31:0] r_reg_stat_ingr_rcv_data_1_value_h     ; // RC
reg[31:0] r_reg_stat_egr_snd_data_0_value_l      ; // RC
reg[31:0] r_reg_stat_egr_snd_data_0_value_h      ; // RC
reg[31:0] r_reg_stat_egr_snd_data_1_value_l      ; // RC
reg[31:0] r_reg_stat_egr_snd_data_1_value_h      ; // RC
reg[31:0] r_reg_stat_ingr_rcv_frame_0_value      ; // RC
reg[31:0] r_reg_stat_ingr_rcv_frame_1_value      ; // RC
reg[31:0] r_reg_stat_egr_snd_frame_0_value       ; // RC
reg[31:0] r_reg_stat_egr_snd_frame_1_value       ; // RC
reg[31:0] r_reg_detect_fault                     ; // R
reg[15:0] r_reg_ingr_rcv_protocol_fault_0        ; // R/WC
reg[15:0] r_reg_ingr_rcv_protocol_fault_0_mask   ; // R/W
reg[15:0] r_reg_ingr_rcv_protocol_fault_0_force  ; // R/W
reg[15:0] r_reg_ingr_rcv_protocol_fault_1        ; // R/WC
reg[15:0] r_reg_ingr_rcv_protocol_fault_1_mask   ; // R/W
reg[15:0] r_reg_ingr_rcv_protocol_fault_1_force  ; // R/W
reg[15:0] r_reg_egr_snd_protocol_fault_0         ; // R/WC
reg[15:0] r_reg_egr_snd_protocol_fault_0_mask    ; // R/W
reg[15:0] r_reg_egr_snd_protocol_fault_0_force   ; // R/W
reg[15:0] r_reg_egr_snd_protocol_fault_1         ; // R/WC
reg[15:0] r_reg_egr_snd_protocol_fault_1_mask    ; // R/W
reg[15:0] r_reg_egr_snd_protocol_fault_1_force   ; // R/W
reg[11:0] r_reg_streamif_stall                   ; // R
reg[11:0] r_reg_streamif_stall_mask              ; // R/W
reg[11:0] r_reg_streamif_stall_force             ; // R/W
reg[31:0] r_reg_ingr_rcv_insert_protocol_fault_0 ; // R/W
reg[31:0] r_reg_ingr_rcv_insert_protocol_fault_1 ; // R/W
reg[31:0] r_reg_egr_snd_insert_protocol_fault_0  ; // R/W
reg[31:0] r_reg_egr_snd_insert_protocol_fault_1  ; // R/W
reg[31:0] r_reg_rx_rcv_req_0                     ; // R
reg[31:0] r_reg_rx_snd_resp_0                    ; // R
reg[31:0] r_reg_rx_rcv_sof_0                     ; // R
reg[31:0] r_reg_rx_rcv_cid_diff_0                ; // R
reg[31:0] r_reg_rx_rcv_line_chk_0                ; // R
reg[31:0] r_reg_rx_rcv_data_0                    ; // R
reg[31:0] r_reg_rx_rcv_length_chk_0              ; // R
reg[31:0] r_reg_tx_snd_req_0                     ; // R
reg[31:0] r_reg_tx_rcv_resp_0                    ; // R
reg[31:0] r_reg_tx_snd_data_0                    ; // R
reg[31:0] r_reg_rx_rcv_req_1                     ; // R
reg[31:0] r_reg_rx_snd_resp_1                    ; // R
reg[31:0] r_reg_rx_rcv_sof_1                     ; // R
reg[31:0] r_reg_rx_rcv_cid_diff_1                ; // R
reg[31:0] r_reg_rx_rcv_line_chk_1                ; // R
reg[31:0] r_reg_rx_rcv_data_1                    ; // R
reg[31:0] r_reg_rx_rcv_length_chk_1              ; // R
reg[31:0] r_reg_tx_snd_req_1                     ; // R
reg[31:0] r_reg_tx_rcv_resp_1                    ; // R
reg[31:0] r_reg_tx_snd_data_1                    ; // R

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
reg [63:0] r_stat_rdack_value;

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
            if (RREADY & RVALID)
                rnext = RDIDLE;
            else
                rnext = RDDATA;
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
            ADDR_CONTROL                           : rdata <= r_reg_control                          ; // R/W
            ADDR_MODULE_ID                         : rdata <= module_id                              ; // R
            ADDR_LOCAL_VERSION                     : rdata <= local_version                          ; // R
            ADDR_ROWS_IN                           : rdata <= r_reg_rows_in                          ; // R/W
            ADDR_COLS_IN                           : rdata <= r_reg_cols_in                          ; // R/W
            ADDR_ROWS_OUT                          : rdata <= r_reg_rows_out                         ; // R/W
            ADDR_COLS_OUT                          : rdata <= r_reg_cols_out                         ; // R/W
            ADDR_STAT_SEL_CHANNEL                  : rdata <= r_reg_stat_sel_channel                 ; // R/W
            ADDR_STAT_INGR_RCV_DATA_0_VALUE_H      : rdata <= r_stat_rdack_value[63:32]              ; // RC
            ADDR_STAT_INGR_RCV_DATA_1_VALUE_H      : rdata <= r_stat_rdack_value[63:32]              ; // RC
            ADDR_STAT_EGR_SND_DATA_0_VALUE_H       : rdata <= r_stat_rdack_value[63:32]              ; // RC
            ADDR_STAT_EGR_SND_DATA_1_VALUE_H       : rdata <= r_stat_rdack_value[63:32]              ; // RC
            ADDR_STAT_INGR_RCV_FRAME_0_VALUE       : rdata <= r_stat_rdack_value[31:0]               ; // RC
            ADDR_STAT_INGR_RCV_FRAME_1_VALUE       : rdata <= r_stat_rdack_value[31:0]               ; // RC
            ADDR_STAT_EGR_SND_FRAME_0_VALUE        : rdata <= r_stat_rdack_value[31:0]               ; // RC
            ADDR_STAT_EGR_SND_FRAME_1_VALUE        : rdata <= r_stat_rdack_value[31:0]               ; // RC
            ADDR_DETECT_FAULT                      : rdata <= r_reg_detect_fault                     ; // R
            ADDR_INGR_RCV_PROTOCOL_FAULT_0         : rdata <= r_reg_ingr_rcv_protocol_fault_0        ; // R/W
            ADDR_INGR_RCV_PROTOCOL_FAULT_0_MASK    : rdata <= r_reg_ingr_rcv_protocol_fault_0_mask   ; // R/W
            ADDR_INGR_RCV_PROTOCOL_FAULT_0_FORCE   : rdata <= r_reg_ingr_rcv_protocol_fault_0_force  ; // R/W
            ADDR_INGR_RCV_PROTOCOL_FAULT_1         : rdata <= r_reg_ingr_rcv_protocol_fault_1        ; // R/W
            ADDR_INGR_RCV_PROTOCOL_FAULT_1_MASK    : rdata <= r_reg_ingr_rcv_protocol_fault_1_mask   ; // R/W
            ADDR_INGR_RCV_PROTOCOL_FAULT_1_FORCE   : rdata <= r_reg_ingr_rcv_protocol_fault_1_force  ; // R/W
            ADDR_EGR_SND_PROTOCOL_FAULT_0          : rdata <= r_reg_egr_snd_protocol_fault_0         ; // R/W
            ADDR_EGR_SND_PROTOCOL_FAULT_0_MASK     : rdata <= r_reg_egr_snd_protocol_fault_0_mask    ; // R/W
            ADDR_EGR_SND_PROTOCOL_FAULT_0_FORCE    : rdata <= r_reg_egr_snd_protocol_fault_0_force   ; // R/W
            ADDR_EGR_SND_PROTOCOL_FAULT_1          : rdata <= r_reg_egr_snd_protocol_fault_1         ; // R/W
            ADDR_EGR_SND_PROTOCOL_FAULT_1_MASK     : rdata <= r_reg_egr_snd_protocol_fault_1_mask    ; // R/W
            ADDR_EGR_SND_PROTOCOL_FAULT_1_FORCE    : rdata <= r_reg_egr_snd_protocol_fault_1_force   ; // R/W
            ADDR_STREAMIF_STALL                    : rdata <= r_reg_streamif_stall                   ; // R
            ADDR_STREAMIF_STALL_MASK               : rdata <= r_reg_streamif_stall_mask              ; // R/W
            ADDR_STREAMIF_STALL_FORCE              : rdata <= r_reg_streamif_stall_force             ; // R/W
            ADDR_INGR_RCV_INSERT_PROTOCOL_FAULT_0  : rdata <= r_reg_ingr_rcv_insert_protocol_fault_0 ; // R/W
            ADDR_INGR_RCV_INSERT_PROTOCOL_FAULT_1  : rdata <= r_reg_ingr_rcv_insert_protocol_fault_1 ; // R/W
            ADDR_EGR_SND_INSERT_PROTOCOL_FAULT_0   : rdata <= r_reg_egr_snd_insert_protocol_fault_0  ; // R/W
            ADDR_EGR_SND_INSERT_PROTOCOL_FAULT_1   : rdata <= r_reg_egr_snd_insert_protocol_fault_1  ; // R/W
            ADDR_RX_RCV_REQ_0                      : rdata <= r_reg_rx_rcv_req_0                     ; // R
            ADDR_RX_SND_RESP_0                     : rdata <= r_reg_rx_snd_resp_0                    ; // R
            ADDR_RX_RCV_SOF_0                      : rdata <= r_reg_rx_rcv_sof_0                     ; // R
            ADDR_RX_RCV_CID_DIFF_0                 : rdata <= r_reg_rx_rcv_cid_diff_0                ; // R
            ADDR_RX_RCV_LINE_CHK_0                 : rdata <= r_reg_rx_rcv_line_chk_0                ; // R
            ADDR_RX_RCV_DATA_0                     : rdata <= r_reg_rx_rcv_data_0                    ; // R
            ADDR_RX_RCV_LENGTH_CHK_0               : rdata <= r_reg_rx_rcv_length_chk_0              ; // R
            ADDR_TX_SND_REQ_0                      : rdata <= r_reg_tx_snd_req_0                     ; // R
            ADDR_TX_RCV_RESP_0                     : rdata <= r_reg_tx_rcv_resp_0                    ; // R
            ADDR_TX_SND_DATA_0                     : rdata <= r_reg_tx_snd_data_0                    ; // R
            ADDR_RX_RCV_REQ_1                      : rdata <= r_reg_rx_rcv_req_1                     ; // R
            ADDR_RX_SND_RESP_1                     : rdata <= r_reg_rx_snd_resp_1                    ; // R
            ADDR_RX_RCV_SOF_1                      : rdata <= r_reg_rx_rcv_sof_1                     ; // R
            ADDR_RX_RCV_CID_DIFF_1                 : rdata <= r_reg_rx_rcv_cid_diff_1                ; // R
            ADDR_RX_RCV_LINE_CHK_1                 : rdata <= r_reg_rx_rcv_line_chk_1                ; // R
            ADDR_RX_RCV_DATA_1                     : rdata <= r_reg_rx_rcv_data_1                    ; // R
            ADDR_RX_RCV_LENGTH_CHK_1               : rdata <= r_reg_rx_rcv_length_chk_1              ; // R
            ADDR_TX_SND_REQ_1                      : rdata <= r_reg_tx_snd_req_1                     ; // R
            ADDR_TX_RCV_RESP_1                     : rdata <= r_reg_tx_rcv_resp_1                    ; // R
            ADDR_TX_SND_DATA_1                     : rdata <= r_reg_tx_snd_data_1                    ; // R
        endcase
    end else if (r_stat_rdack_valid) begin
      rdata <= r_stat_rdack_value[31:0];
    end
end

//// write-only registers
//always @(posedge ACLK) begin
//    if (!ARESET_N) begin
//        r_reg_control <= 1'b0;
//    end else begin
//        r_reg_control <= (waddr == ADDR_CONTROL) ? (WDATA[0] & wmask[0]) : 1'b0;
//    end
//end

// read/write registers
always @(posedge ACLK) begin
    if (!ARESET_N) begin
        r_reg_control                          <= 1'd0;
        r_reg_rows_in                          <= 32'd0; // R/W
        r_reg_cols_in                          <= 32'd0; // R/W
        r_reg_rows_out                         <= 32'd0; // R/W
        r_reg_cols_out                         <= 32'd0; // R/W
        r_reg_stat_sel_channel                 <= 32'd0; // R/W
        r_reg_ingr_rcv_protocol_fault_0_mask   <= 32'd0; // R/W
        r_reg_ingr_rcv_protocol_fault_0_force  <= 32'd0; // R/W
        r_reg_ingr_rcv_protocol_fault_1_mask   <= 32'd0; // R/W
        r_reg_ingr_rcv_protocol_fault_1_force  <= 32'd0; // R/W
        r_reg_egr_snd_protocol_fault_0_mask    <= 32'd0; // R/W
        r_reg_egr_snd_protocol_fault_0_force   <= 32'd0; // R/W
        r_reg_egr_snd_protocol_fault_1_mask    <= 32'd0; // R/W
        r_reg_egr_snd_protocol_fault_1_force   <= 32'd0; // R/W
        r_reg_streamif_stall_mask              <= 32'd0; // R/W
        r_reg_streamif_stall_force             <= 32'd0; // R/W
        r_reg_ingr_rcv_insert_protocol_fault_0 <= 32'd0; // R/W
        r_reg_ingr_rcv_insert_protocol_fault_1 <= 32'd0; // R/W
        r_reg_egr_snd_insert_protocol_fault_0  <= 32'd0; // R/W
        r_reg_egr_snd_insert_protocol_fault_1  <= 32'd0; // R/W
    end else if (w_hs) begin
        case (waddr)
            ADDR_CONTROL                          : r_reg_control                          <= ((WDATA[31:0] & wmask) | (r_reg_control                          & ~wmask)) ; // [0]
            ADDR_ROWS_IN                          : r_reg_rows_in                          <= ((WDATA[31:0] & wmask) | (r_reg_rows_in                          & ~wmask)) ; // R/W
            ADDR_COLS_IN                          : r_reg_cols_in                          <= ((WDATA[31:0] & wmask) | (r_reg_cols_in                          & ~wmask)) ; // R/W
            ADDR_ROWS_OUT                         : r_reg_rows_out                         <= ((WDATA[31:0] & wmask) | (r_reg_rows_out                         & ~wmask)) ; // R/W
            ADDR_COLS_OUT                         : r_reg_cols_out                         <= ((WDATA[31:0] & wmask) | (r_reg_cols_out                         & ~wmask)) ; // R/W
            ADDR_STAT_SEL_CHANNEL                 : r_reg_stat_sel_channel                 <= ((WDATA[31:0] & wmask) | (r_reg_stat_sel_channel                 & ~wmask)) & CHANNEL_MASK ; // [8:0]
            ADDR_INGR_RCV_PROTOCOL_FAULT_0_MASK   : r_reg_ingr_rcv_protocol_fault_0_mask   <= ((WDATA[31:0] & wmask) | (r_reg_ingr_rcv_protocol_fault_0_mask   & ~wmask)) & 32'h00003fff ; // [13:0]
            ADDR_INGR_RCV_PROTOCOL_FAULT_0_FORCE  : r_reg_ingr_rcv_protocol_fault_0_force  <= ((WDATA[31:0] & wmask) | (r_reg_ingr_rcv_protocol_fault_0_force  & ~wmask)) & 32'h00003fff ; // [13:0]
            ADDR_INGR_RCV_PROTOCOL_FAULT_1_MASK   : r_reg_ingr_rcv_protocol_fault_1_mask   <= ((WDATA[31:0] & wmask) | (r_reg_ingr_rcv_protocol_fault_1_mask   & ~wmask)) & 32'h00003fff ; // [13:0]
            ADDR_INGR_RCV_PROTOCOL_FAULT_1_FORCE  : r_reg_ingr_rcv_protocol_fault_1_force  <= ((WDATA[31:0] & wmask) | (r_reg_ingr_rcv_protocol_fault_1_force  & ~wmask)) & 32'h00003fff ; // [13:0]
            ADDR_EGR_SND_PROTOCOL_FAULT_0_MASK    : r_reg_egr_snd_protocol_fault_0_mask    <= ((WDATA[31:0] & wmask) | (r_reg_egr_snd_protocol_fault_0_mask    & ~wmask)) & 32'h00003fff ; // [13:0]
            ADDR_EGR_SND_PROTOCOL_FAULT_0_FORCE   : r_reg_egr_snd_protocol_fault_0_force   <= ((WDATA[31:0] & wmask) | (r_reg_egr_snd_protocol_fault_0_force   & ~wmask)) & 32'h00003fff ; // [13:0]
            ADDR_EGR_SND_PROTOCOL_FAULT_1_MASK    : r_reg_egr_snd_protocol_fault_1_mask    <= ((WDATA[31:0] & wmask) | (r_reg_egr_snd_protocol_fault_1_mask    & ~wmask)) & 32'h00003fff ; // [13:0]
            ADDR_EGR_SND_PROTOCOL_FAULT_1_FORCE   : r_reg_egr_snd_protocol_fault_1_force   <= ((WDATA[31:0] & wmask) | (r_reg_egr_snd_protocol_fault_1_force   & ~wmask)) & 32'h00003fff ; // [13:0]
            ADDR_STREAMIF_STALL_MASK              : r_reg_streamif_stall_mask              <= ((WDATA[31:0] & wmask) | (r_reg_streamif_stall_mask              & ~wmask)) & 32'h00000fff ; // [11:0]
            ADDR_STREAMIF_STALL_FORCE             : r_reg_streamif_stall_force             <= ((WDATA[31:0] & wmask) | (r_reg_streamif_stall_force             & ~wmask)) & 32'h00000fff ; // [11:0]
            ADDR_INGR_RCV_INSERT_PROTOCOL_FAULT_0 : r_reg_ingr_rcv_insert_protocol_fault_0 <= ((WDATA[31:0] & wmask) | (r_reg_ingr_rcv_insert_protocol_fault_0 & ~wmask)) & 32'h00003fff ; // [13:0]
            ADDR_INGR_RCV_INSERT_PROTOCOL_FAULT_1 : r_reg_ingr_rcv_insert_protocol_fault_1 <= ((WDATA[31:0] & wmask) | (r_reg_ingr_rcv_insert_protocol_fault_1 & ~wmask)) & 32'h00003fff ; // [13:0]
            ADDR_EGR_SND_INSERT_PROTOCOL_FAULT_0  : r_reg_egr_snd_insert_protocol_fault_0  <= ((WDATA[31:0] & wmask) | (r_reg_egr_snd_insert_protocol_fault_0  & ~wmask)) & 32'h00003fff ; // [13:0]
            ADDR_EGR_SND_INSERT_PROTOCOL_FAULT_1  : r_reg_egr_snd_insert_protocol_fault_1  <= ((WDATA[31:0] & wmask) | (r_reg_egr_snd_insert_protocol_fault_1  & ~wmask)) & 32'h00003fff ; // [13:0]
        endcase
    end
end

assign ap_start = r_reg_control;
assign insert_protocol_fault_resp_0 = {r_reg_ingr_rcv_insert_protocol_fault_0[13], r_reg_ingr_rcv_insert_protocol_fault_0[3:0]};
assign insert_protocol_fault_resp_1 = {r_reg_ingr_rcv_insert_protocol_fault_1[13], r_reg_ingr_rcv_insert_protocol_fault_1[3:0]};
assign insert_protocol_fault_req_0  = r_reg_egr_snd_insert_protocol_fault_0[12];
assign insert_protocol_fault_req_1  = r_reg_egr_snd_insert_protocol_fault_1[12];
assign insert_protocol_fault_data_0 = r_reg_egr_snd_insert_protocol_fault_0[5];
assign insert_protocol_fault_data_1 = r_reg_egr_snd_insert_protocol_fault_1[5];

// read clear registers
wire w_stat_ingr_rcv_data_0_rdreq;
wire w_stat_ingr_rcv_data_0_rdack_valid;
wire [63:0] w_stat_ingr_rcv_data_0_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_ingr_rcv_data_0 (
    .clk        (ACLK),                                // input
    .rstn       (ARESET_N),                            // input
    .init_done  (  /* open */),                        // output
    .add_valid  (ingr_stat_data_0_vld),                // input
    .add_index  (ingr_stat_data_0[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
    .add_value  (ingr_stat_data_0[23:16]),             // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_ingr_rcv_data_0_rdreq),        // input
    .rdreq_index(r_reg_stat_sel_channel),              // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_ingr_rcv_data_0_rdack_valid),  // output
    .rdack_value(w_stat_ingr_rcv_data_0_rdack_value)   // output[COUNTER_WIDTH-1:0]
);
assign w_stat_ingr_rcv_data_0_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_RCV_DATA_0_VALUE_L);

wire w_stat_ingr_rcv_data_1_rdreq;
wire w_stat_ingr_rcv_data_1_rdack_valid;
wire [63:0] w_stat_ingr_rcv_data_1_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_ingr_rcv_data_1 (
    .clk        (ACLK),                                // input
    .rstn       (ARESET_N),                            // input
    .init_done  (  /* open */),                        // output
    .add_valid  (ingr_stat_data_1_vld),                // input
    .add_index  (ingr_stat_data_1[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
    .add_value  (ingr_stat_data_1[23:16]),             // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_ingr_rcv_data_1_rdreq),        // input
    .rdreq_index(r_reg_stat_sel_channel),              // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_ingr_rcv_data_1_rdack_valid),  // output
    .rdack_value(w_stat_ingr_rcv_data_1_rdack_value)   // output[COUNTER_WIDTH-1:0]
);
assign w_stat_ingr_rcv_data_1_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_RCV_DATA_1_VALUE_L);

wire w_stat_egr_snd_data_0_rdreq;
wire w_stat_egr_snd_data_0_rdack_valid;
wire [63:0] w_stat_egr_snd_data_0_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_egr_snd_data_0 (
    .clk        (ACLK),                                // input
    .rstn       (ARESET_N),                            // input
    .init_done  (  /* open */),                        // output
    .add_valid  (egr_stat_data_0_vld),                // input
    .add_index  (egr_stat_data_0[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
    .add_value  (egr_stat_data_0[23:16]),             // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_egr_snd_data_0_rdreq),        // input
    .rdreq_index(r_reg_stat_sel_channel),              // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_egr_snd_data_0_rdack_valid),  // output
    .rdack_value(w_stat_egr_snd_data_0_rdack_value)   // output[COUNTER_WIDTH-1:0]
);
assign w_stat_egr_snd_data_0_rdreq = ar_hs && (raddr == ADDR_STAT_EGR_SND_DATA_0_VALUE_L);

wire w_stat_egr_snd_data_1_rdreq;
wire w_stat_egr_snd_data_1_rdack_valid;
wire [63:0] w_stat_egr_snd_data_1_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_egr_snd_data_1 (
    .clk        (ACLK),                                // input
    .rstn       (ARESET_N),                            // input
    .init_done  (  /* open */),                        // output
    .add_valid  (egr_stat_data_1_vld),                // input
    .add_index  (egr_stat_data_1[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
    .add_value  (egr_stat_data_1[23:16]),             // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_egr_snd_data_1_rdreq),        // input
    .rdreq_index(r_reg_stat_sel_channel),              // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_egr_snd_data_1_rdack_valid),  // output
    .rdack_value(w_stat_egr_snd_data_1_rdack_value)   // output[COUNTER_WIDTH-1:0]
);
assign w_stat_egr_snd_data_1_rdreq = ar_hs && (raddr == ADDR_STAT_EGR_SND_DATA_1_VALUE_L);

wire w_stat_ingr_rcv_frame_0_rdreq;
wire w_stat_ingr_rcv_frame_0_rdack_valid;
wire [63:0] w_stat_ingr_rcv_frame_0_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_ingr_rcv_frame_0 (
    .clk        (ACLK),                                 // input
    .rstn       (ARESET_N),                             // input
    .init_done  (  /* open */),                         // output
    .add_valid  (ingr_stat_frame_0_vld),                // input
    .add_index  (ingr_stat_frame_0[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
    .add_value  (ingr_stat_frame_0[23:16]),             // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_ingr_rcv_frame_0_rdreq),        // input
    .rdreq_index(r_reg_stat_sel_channel),               // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_ingr_rcv_frame_0_rdack_valid),  // output
    .rdack_value(w_stat_ingr_rcv_frame_0_rdack_value)   // output[COUNTER_WIDTH-1:0]
);
assign w_stat_ingr_rcv_frame_0_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_RCV_FRAME_0_VALUE);

wire w_stat_ingr_rcv_frame_1_rdreq;
wire w_stat_ingr_rcv_frame_1_rdack_valid;
wire [63:0] w_stat_ingr_rcv_frame_1_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_ingr_rcv_frame_1 (
    .clk        (ACLK),                                 // input
    .rstn       (ARESET_N),                             // input
    .init_done  (  /* open */),                         // output
    .add_valid  (ingr_stat_frame_1_vld),                // input
    .add_index  (ingr_stat_frame_1[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
    .add_value  (ingr_stat_frame_1[23:16]),             // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_ingr_rcv_frame_1_rdreq),        // input
    .rdreq_index(r_reg_stat_sel_channel),               // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_ingr_rcv_frame_1_rdack_valid),  // output
    .rdack_value(w_stat_ingr_rcv_frame_1_rdack_value)   // output[COUNTER_WIDTH-1:0]
);
assign w_stat_ingr_rcv_frame_1_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_RCV_FRAME_1_VALUE);

wire w_stat_egr_snd_frame_0_rdreq;
wire w_stat_egr_snd_frame_0_rdack_valid;
wire [63:0] w_stat_egr_snd_frame_0_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_egr_snd_frame_0 (
    .clk        (ACLK),                                 // input
    .rstn       (ARESET_N),                             // input
    .init_done  (  /* open */),                         // output
    .add_valid  (egr_stat_frame_0_vld),                // input
    .add_index  (egr_stat_frame_0[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
    .add_value  (egr_stat_frame_0[23:16]),             // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_egr_snd_frame_0_rdreq),        // input
    .rdreq_index(r_reg_stat_sel_channel),               // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_egr_snd_frame_0_rdack_valid),  // output
    .rdack_value(w_stat_egr_snd_frame_0_rdack_value)   // output[COUNTER_WIDTH-1:0]
);
assign w_stat_egr_snd_frame_0_rdreq = ar_hs && (raddr == ADDR_STAT_EGR_SND_FRAME_0_VALUE);

wire w_stat_egr_snd_frame_1_rdreq;
wire w_stat_egr_snd_frame_1_rdack_valid;
wire [63:0] w_stat_egr_snd_frame_1_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_egr_snd_frame_1 (
    .clk        (ACLK),                                 // input
    .rstn       (ARESET_N),                             // input
    .init_done  (  /* open */),                         // output
    .add_valid  (egr_stat_frame_1_vld),                // input
    .add_index  (egr_stat_frame_1[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
    .add_value  (egr_stat_frame_1[23:16]),             // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_egr_snd_frame_1_rdreq),        // input
    .rdreq_index(r_reg_stat_sel_channel),               // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_egr_snd_frame_1_rdack_valid),  // output
    .rdack_value(w_stat_egr_snd_frame_1_rdack_value)   // output[COUNTER_WIDTH-1:0]
);
assign w_stat_egr_snd_frame_1_rdreq = ar_hs && (raddr == ADDR_STAT_EGR_SND_FRAME_1_VALUE);

assign w_stat_rdreq = | {
    w_stat_ingr_rcv_data_0_rdreq,
    w_stat_ingr_rcv_data_1_rdreq,
    w_stat_egr_snd_data_0_rdreq,
    w_stat_egr_snd_data_1_rdreq,
    w_stat_ingr_rcv_frame_0_rdreq,
    w_stat_ingr_rcv_frame_1_rdreq,
    w_stat_egr_snd_frame_0_rdreq,
    w_stat_egr_snd_frame_1_rdreq
};

assign w_stat_rdack_valid = | {
    w_stat_ingr_rcv_data_0_rdack_valid,
    w_stat_ingr_rcv_data_1_rdack_valid,
    w_stat_egr_snd_data_0_rdack_valid,
    w_stat_egr_snd_data_1_rdack_valid,
    w_stat_ingr_rcv_frame_0_rdack_valid,
    w_stat_ingr_rcv_frame_1_rdack_valid,
    w_stat_egr_snd_frame_0_rdack_valid,
    w_stat_egr_snd_frame_1_rdack_valid
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
        ({64{w_stat_ingr_rcv_data_0_rdack_valid }} & w_stat_ingr_rcv_data_0_rdack_value) |
        ({64{w_stat_ingr_rcv_data_1_rdack_valid }} & w_stat_ingr_rcv_data_1_rdack_value) |
        ({64{w_stat_egr_snd_data_0_rdack_valid  }} & w_stat_egr_snd_data_0_rdack_value) |
        ({64{w_stat_egr_snd_data_1_rdack_valid  }} & w_stat_egr_snd_data_1_rdack_value) |
        ({64{w_stat_ingr_rcv_frame_0_rdack_valid}} & w_stat_ingr_rcv_frame_0_rdack_value) |
        ({64{w_stat_ingr_rcv_frame_1_rdack_valid}} & w_stat_ingr_rcv_frame_1_rdack_value) |
        ({64{w_stat_egr_snd_frame_0_rdack_valid}} & w_stat_egr_snd_frame_0_rdack_value) |
        ({64{w_stat_egr_snd_frame_1_rdack_valid}} & w_stat_egr_snd_frame_1_rdack_value);
    end
end

// read only registers
always @(posedge ACLK) begin
    if (!ARESET_N) begin
        r_reg_streamif_stall <= 0;  // [11:0]
    end else begin
        r_reg_streamif_stall <= (streamif_stall | r_reg_streamif_stall_force) & ~r_reg_streamif_stall_mask;
    end
end

// read/write clear registers
reg [15:0] r_ingr_rcv_protocol_fault_0;
reg [15:0] r_ingr_rcv_protocol_fault_1;
reg [15:0] r_egr_snd_protocol_fault_0;
reg [15:0] r_egr_snd_protocol_fault_1;

always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_ingr_rcv_protocol_fault_0 <= 16'd0;
    r_ingr_rcv_protocol_fault_1 <= 16'd0;
    r_egr_snd_protocol_fault_0 <= 16'd0;
    r_egr_snd_protocol_fault_1 <= 16'd0;
  end else begin
    r_ingr_rcv_protocol_fault_0 <= (ingr_protocol_error_0_vld) ? ingr_protocol_error_0 : 16'd0;
    r_ingr_rcv_protocol_fault_1 <= (ingr_protocol_error_1_vld) ? ingr_protocol_error_1 : 16'd0;
    r_egr_snd_protocol_fault_0  <= (egr_protocol_error_0_vld)  ? egr_protocol_error_0  : 16'd0;
    r_egr_snd_protocol_fault_1  <= (egr_protocol_error_1_vld)  ? egr_protocol_error_1  : 16'd0;
  end
end

  wire [15:0] w_ingr_rcv_protocol_fault_0_set = (r_ingr_rcv_protocol_fault_0 | r_reg_ingr_rcv_protocol_fault_0_force) & ~r_reg_ingr_rcv_protocol_fault_0_mask;
  wire [15:0] w_ingr_rcv_protocol_fault_1_set = (r_ingr_rcv_protocol_fault_1 | r_reg_ingr_rcv_protocol_fault_1_force) & ~r_reg_ingr_rcv_protocol_fault_1_mask;
  wire [15:0] w_egr_snd_protocol_fault_0_set = (r_egr_snd_protocol_fault_0 | r_reg_egr_snd_protocol_fault_0_force) & ~r_reg_egr_snd_protocol_fault_0_mask;
  wire [15:0] w_egr_snd_protocol_fault_1_set = (r_egr_snd_protocol_fault_1 | r_reg_egr_snd_protocol_fault_1_force) & ~r_reg_egr_snd_protocol_fault_1_mask;
  
  wire [15:0] w_ingr_rcv_protocol_fault_0_clr = (w_hs && waddr == ADDR_INGR_RCV_PROTOCOL_FAULT_0) ? (WDATA[15:0] & wmask[15:0]) : 16'd0;
  wire [15:0] w_ingr_rcv_protocol_fault_1_clr = (w_hs && waddr == ADDR_INGR_RCV_PROTOCOL_FAULT_1) ? (WDATA[15:0] & wmask[15:0]) : 16'd0;
  wire [15:0] w_egr_snd_protocol_fault_0_clr = (w_hs && waddr == ADDR_EGR_SND_PROTOCOL_FAULT_0) ? (WDATA[15:0] & wmask[15:0]) : 16'd0;
  wire [15:0] w_egr_snd_protocol_fault_1_clr = (w_hs && waddr == ADDR_EGR_SND_PROTOCOL_FAULT_1) ? (WDATA[15:0] & wmask[15:0]) : 16'd0;

  always @(posedge ACLK) begin
    if (!ARESET_N) begin
      r_reg_ingr_rcv_protocol_fault_0 <= 16'd0;
      r_reg_ingr_rcv_protocol_fault_1 <= 16'd0;
      r_reg_egr_snd_protocol_fault_0 <= 16'd0;
      r_reg_egr_snd_protocol_fault_1 <= 16'd0;
    end else begin
      r_reg_ingr_rcv_protocol_fault_0 <= (r_reg_ingr_rcv_protocol_fault_0 & ~w_ingr_rcv_protocol_fault_0_clr) | w_ingr_rcv_protocol_fault_0_set;
      r_reg_ingr_rcv_protocol_fault_1 <= (r_reg_ingr_rcv_protocol_fault_1 & ~w_ingr_rcv_protocol_fault_1_clr) | w_ingr_rcv_protocol_fault_1_set;
      r_reg_egr_snd_protocol_fault_0 <= (r_reg_egr_snd_protocol_fault_0 & ~w_egr_snd_protocol_fault_0_clr) | w_egr_snd_protocol_fault_0_set;
      r_reg_egr_snd_protocol_fault_1 <= (r_reg_egr_snd_protocol_fault_1 & ~w_egr_snd_protocol_fault_1_clr) | w_egr_snd_protocol_fault_1_set;
    end
  end


//------------------------Register logic-----------------
//assign interrupt       = int_gie & (|int_isr);
//assign ap_start        = int_ap_start;
//assign task_ap_done    = (ap_done && !auto_restart_status) || auto_restart_done;
//assign task_ap_ready   = ap_ready && !int_auto_restart;
//assign ap_continue     = int_ap_continue || auto_restart_status;
assign rows_in         = r_reg_rows_in;
assign cols_in         = r_reg_cols_in;
assign rows_out        = r_reg_rows_out;
assign cols_out        = r_reg_cols_out;


// dbg register
always @(posedge ACLK) begin
    if (!ARESET_N) begin
        r_reg_rx_rcv_req_0        <= 32'd0;
        r_reg_rx_snd_resp_0       <= 32'd0;
        r_reg_rx_rcv_sof_0        <= 32'd0;
        r_reg_rx_rcv_cid_diff_0   <= 32'd0;
        r_reg_rx_rcv_line_chk_0   <= 32'd0;
        r_reg_rx_rcv_data_0       <= 32'd0;
        r_reg_rx_rcv_length_chk_0 <= 32'd0;
        r_reg_tx_snd_req_0        <= 32'd0;
        r_reg_tx_rcv_resp_0       <= 32'd0;
        r_reg_tx_snd_data_0       <= 32'd0;
        r_reg_rx_rcv_req_1        <= 32'd0;
        r_reg_rx_snd_resp_1       <= 32'd0;
        r_reg_rx_rcv_sof_1        <= 32'd0;
        r_reg_rx_rcv_cid_diff_1   <= 32'd0;
        r_reg_rx_rcv_line_chk_1   <= 32'd0;
        r_reg_rx_rcv_data_1       <= 32'd0;
        r_reg_rx_rcv_length_chk_1 <= 32'd0;
        r_reg_tx_snd_req_1        <= 32'd0;
        r_reg_tx_rcv_resp_1       <= 32'd0;
        r_reg_tx_snd_data_1       <= 32'd0;
    end else begin
        r_reg_rx_rcv_req_0        <= rx_rcv_req_0        ;
        r_reg_rx_snd_resp_0       <= rx_snd_resp_0       ;
        r_reg_rx_rcv_sof_0        <= rx_rcv_sof_0        ;
        r_reg_rx_rcv_cid_diff_0   <= rx_rcv_cid_diff_0   ;
        r_reg_rx_rcv_line_chk_0   <= rx_rcv_line_chk_0   ;
        r_reg_rx_rcv_data_0       <= rx_rcv_data_0       ;
        r_reg_rx_rcv_length_chk_0 <= rx_rcv_length_chk_0 ;
        r_reg_tx_snd_req_0        <= tx_snd_req_0        ;
        r_reg_tx_rcv_resp_0       <= tx_rcv_resp_0       ;
        r_reg_tx_snd_data_0       <= tx_snd_data_0       ;
        r_reg_rx_rcv_req_1        <= rx_rcv_req_1        ;
        r_reg_rx_snd_resp_1       <= rx_snd_resp_1       ;
        r_reg_rx_rcv_sof_1        <= rx_rcv_sof_1        ;
        r_reg_rx_rcv_cid_diff_1   <= rx_rcv_cid_diff_1   ;
        r_reg_rx_rcv_line_chk_1   <= rx_rcv_line_chk_1   ;
        r_reg_rx_rcv_data_1       <= rx_rcv_data_1       ;
        r_reg_rx_rcv_length_chk_1 <= rx_rcv_length_chk_1 ;
        r_reg_tx_snd_req_1        <= tx_snd_req_1        ;
        r_reg_tx_rcv_resp_1       <= tx_rcv_resp_1       ;
        r_reg_tx_snd_data_1       <= tx_snd_data_1       ;
    end
end

//detect_fault
reg r_fault_or;
always @(posedge ACLK) begin
    if (!ARESET_N) begin
        r_fault_or <= 1'b0;
        r_reg_detect_fault <= 1'b0;
    end else begin
        r_fault_or <= |{r_reg_ingr_rcv_protocol_fault_0, r_reg_ingr_rcv_protocol_fault_1, r_reg_egr_snd_protocol_fault_0, r_reg_egr_snd_protocol_fault_1};
        r_reg_detect_fault <= r_fault_or;
    end
end
assign detect_fault = r_reg_detect_fault;

endmodule

`default_nettype wire
