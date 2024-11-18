/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`default_nettype none

`timescale 1ns/1ps
module conversion_adaptor_control_s_axi #(
  parameter integer C_S_AXI_ADDR_WIDTH = 10,
  parameter integer C_S_AXI_DATA_WIDTH = 32
) (
  input   wire                            ACLK,
  input   wire                            ARESET_N,
  input   wire[C_S_AXI_ADDR_WIDTH-1:0]    AWADDR,
  input   wire                            AWVALID,
  output  wire                            AWREADY,
  input   wire[C_S_AXI_DATA_WIDTH-1:0]    WDATA,
  input   wire[C_S_AXI_DATA_WIDTH/8-1:0]  WSTRB,
  input   wire                            WVALID,
  output  wire                            WREADY,
  output  wire[1:0]                       BRESP,
  output  wire                            BVALID,
  input   wire                            BREADY,
  input   wire[C_S_AXI_ADDR_WIDTH-1:0]    ARADDR,
  input   wire                            ARVALID,
  output  wire                            ARREADY,
  output  wire[C_S_AXI_DATA_WIDTH-1:0]    RDATA,
  output  wire[1:0]                       RRESP,
  output  wire                            RVALID,
  input   wire                            RREADY,
  output  wire                            detect_fault,
  input   wire[31:0]                      module_id,
  input   wire[31:0]                      local_version,
  output  wire[63:0]                      m_axi_ingr_frame_buffer,
  output  wire[31:0]                      rows_in,
  output  wire[31:0]                      cols_in,
  input   wire[23:0]                      ingr_rcv_data,
  input   wire                            ingr_rcv_data_vld,
  input   wire[23:0]                      ingr_snd_data_0,
  input   wire                            ingr_snd_data_0_vld,
  input   wire[23:0]                      ingr_snd_data_1,
  input   wire                            ingr_snd_data_1_vld,
  input   wire[23:0]                      ingr_rcv_frame,
  input   wire                            ingr_rcv_frame_vld,
  input   wire[23:0]                      ingr_snd_frame_0,
  input   wire                            ingr_snd_frame_0_vld,
  input   wire[23:0]                      ingr_snd_frame_1,
  input   wire                            ingr_snd_frame_1_vld,
  input   wire[23:0]                      egr_rcv_frame_0,
  input   wire                            egr_rcv_frame_0_vld,
  input   wire[23:0]                      egr_rcv_frame_1,
  input   wire                            egr_rcv_frame_1_vld,
  input   wire[23:0]                      egr_snd_frame,
  input   wire                            egr_snd_frame_vld,
  input   wire[15:0]                      ingr_mem_err_detect,
  input   wire                            ingr_mem_err_detect_vld,
  input   wire[23:0]                      egr_rcv_data_0,
  input   wire                            egr_rcv_data_0_vld,
  input   wire[23:0]                      egr_rcv_data_1,
  input   wire                            egr_rcv_data_1_vld,
  input   wire[23:0]                      egr_snd_data,
  input   wire                            egr_snd_data_vld,
  input   wire[17:0]                      streamif_stall,
  input   wire[15:0]                      ingr_rcv_length_fault,
  input   wire                            ingr_rcv_length_fault_vld,
  input   wire[15:0]                      ingr_frame_buffer_write,
  input   wire                            ingr_frame_buffer_write_vld,
  input   wire[15:0]                      ingr_frame_buffer_read,
  input   wire                            ingr_frame_buffer_read_vld,
  input   wire [15:0]                     ingr_rcv_protocol_error,
  input   wire                            ingr_rcv_protocol_error_vld,
  input   wire [15:0]                     ingr_snd_protocol_error_0,
  input   wire                            ingr_snd_protocol_error_0_vld,
  input   wire [15:0]                     ingr_snd_protocol_error_1,
  input   wire                            ingr_snd_protocol_error_1_vld,
  input   wire [15:0]                     egr_rcv_protocol_error_0,
  input   wire                            egr_rcv_protocol_error_0_vld,
  input   wire [15:0]                     egr_rcv_protocol_error_1,
  input   wire                            egr_rcv_protocol_error_1_vld,
  input   wire [15:0]                     egr_snd_protocol_error,
  input   wire                            egr_snd_protocol_error_vld,
  output  wire [15:0]                     ingr_fail_insert,
  output  wire [15:0]                     egr_fail_insert,
  output  wire [7:0]                      parity_fail_insert,
  input   wire [31:0]                     cs_rcv_req,
  input   wire [31:0]                     cs_snd_resp,
  input   wire [31:0]                     cs_rcv_dt,
  input   wire [31:0]                     cs_wr_ddr,
  input   wire [31:0]                     cs_rcv_eof,
  input   wire [31:0]                     cs_snd_lreq,
  input   wire [31:0]                     cs_rd_ddr,
  input   wire [31:0]                     cs_snd_req,
  input   wire [31:0]                     cs_rcv_resp_0,
  input   wire [31:0]                     cs_snd_dt_0,
  input   wire [31:0]                     cs_rcv_resp_1,
  input   wire [31:0]                     cs_snd_dt_1,
  input   wire [31:0]                     cm_snd_req,
  input   wire [31:0]                     cm_snd_resp,
  input   wire [31:0]                     cm_snd_data,
  output  wire                            ap_start
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

localparam[ADDR_BITS-1:0] ADDR_CONTROL                          = 10'h000; // W
localparam[ADDR_BITS-1:0] ADDR_MODULE_ID                        = 10'h010; // R
localparam[ADDR_BITS-1:0] ADDR_LOCAL_VERSION                    = 10'h020; // R
localparam[ADDR_BITS-1:0] ADDR_M_AXI_INGR_FRAME_BUFFER_L        = 10'h030; // R/W
localparam[ADDR_BITS-1:0] ADDR_M_AXI_INGR_FRAME_BUFFER_H        = 10'h034; // R/W
localparam[ADDR_BITS-1:0] ADDR_ROWS_IN                          = 10'h040; // R/W
localparam[ADDR_BITS-1:0] ADDR_COLS_IN                          = 10'h044; // R/W
localparam[ADDR_BITS-1:0] ADDR_STAT_SEL_CHANNEL                 = 10'h050; // R/W
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_DATA_VALUE_L       = 10'h060; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_DATA_VALUE_H       = 10'h064; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_SND_DATA_0_VALUE_L     = 10'h070; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_SND_DATA_0_VALUE_H     = 10'h074; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_SND_DATA_1_VALUE_L     = 10'h078; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_SND_DATA_1_VALUE_H     = 10'h07C; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_RCV_DATA_0_VALUE_L      = 10'h080; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_RCV_DATA_0_VALUE_H      = 10'h084; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_RCV_DATA_1_VALUE_L      = 10'h088; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_RCV_DATA_1_VALUE_H      = 10'h08C; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_SND_DATA_VALUE_L        = 10'h090; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_SND_DATA_VALUE_H        = 10'h094; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_FRAME_VALUE        = 10'h098; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_SND_FRAME_0_VALUE      = 10'h0A0; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_SND_FRAME_1_VALUE      = 10'h0A4; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_RCV_FRAME_0_VALUE       = 10'h0A8; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_RCV_FRAME_1_VALUE       = 10'h0AC; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_EGR_SND_FRAME_VALUE         = 10'h0B0; // RC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_FRAME_BUFFER_OVERFLOW  = 10'h0C0; // R/WC
localparam[ADDR_BITS-1:0] ADDR_STAT_INGR_FRAME_BUFFER_USAGE     = 10'h0C4; // R
localparam[ADDR_BITS-1:0] ADDR_DETECT_FAULT                     = 10'h100; // R
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_PROTOCOL_FAULT          = 10'h110; // R/WC
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_PROTOCOL_FAULT_MASK     = 10'h118; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_PROTOCOL_FAULT_FORCE    = 10'h11C; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_PROTOCOL_FAULT_0        = 10'h120; // R/WC
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_PROTOCOL_FAULT_0_MASK   = 10'h128; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_PROTOCOL_FAULT_0_FORCE  = 10'h12C; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_PROTOCOL_FAULT_1        = 10'h130; // R/WC
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_PROTOCOL_FAULT_1_MASK   = 10'h138; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_PROTOCOL_FAULT_1_FORCE  = 10'h13C; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_RCV_PROTOCOL_FAULT_0         = 10'h140; // R/WC
localparam[ADDR_BITS-1:0] ADDR_EGR_RCV_PROTOCOL_FAULT_0_MASK    = 10'h148; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_RCV_PROTOCOL_FAULT_0_FORCE   = 10'h14C; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_RCV_PROTOCOL_FAULT_1         = 10'h150; // R/WC
localparam[ADDR_BITS-1:0] ADDR_EGR_RCV_PROTOCOL_FAULT_1_MASK    = 10'h158; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_RCV_PROTOCOL_FAULT_1_FORCE   = 10'h15C; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_PROTOCOL_FAULT           = 10'h160; // R/WC
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_PROTOCOL_FAULT_MASK      = 10'h168; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_PROTOCOL_FAULT_FORCE     = 10'h16C; // R/W
localparam[ADDR_BITS-1:0] ADDR_MEM_PARITY_FAULT                 = 10'h170; // R/WC
localparam[ADDR_BITS-1:0] ADDR_MEM_PARITY_FAULT_MASK            = 10'h178; // R/W
localparam[ADDR_BITS-1:0] ADDR_MEM_PARITY_FAULT_FORCE           = 10'h17C; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_LENGTH_FAULT            = 10'h180; // R/WC
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_LENGTH_FAULT_MASK       = 10'h188; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_LENGTH_FAULT_FORCE      = 10'h18C; // R/W
localparam[ADDR_BITS-1:0] ADDR_STREAMIF_STALL                   = 10'h190; // R
localparam[ADDR_BITS-1:0] ADDR_STREAMIF_STALL_MASK              = 10'h198; // R/W
localparam[ADDR_BITS-1:0] ADDR_STREAMIF_STALL_FORCE             = 10'h19C; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_RCV_INSERT_PROTOCOL_FAULT   = 10'h1C0; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_INSERT_PROTOCOL_FAULT_0 = 10'h1C4; // R/W
localparam[ADDR_BITS-1:0] ADDR_INGR_SND_INSERT_PROTOCOL_FAULT_1 = 10'h1C8; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_RCV_INSERT_PROTOCOL_FAULT_0  = 10'h1CC; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_RCV_INSERT_PROTOCOL_FAULT_1  = 10'h1D0; // R/W
localparam[ADDR_BITS-1:0] ADDR_EGR_SND_INSERT_PROTOCOL_FAULT    = 10'h1D4; // R/W
localparam[ADDR_BITS-1:0] ADDR_INSERT_MEM_PARITY_FAULT          = 10'h1D8; // R/W
localparam[ADDR_BITS-1:0] ADDR_CS_RCV_REQ                       = 10'h200; // R
localparam[ADDR_BITS-1:0] ADDR_CS_SND_RESP                      = 10'h204; // R
localparam[ADDR_BITS-1:0] ADDR_CS_RCV_DT                        = 10'h208; // R
localparam[ADDR_BITS-1:0] ADDR_CS_WR_DDR                        = 10'h20C; // R
localparam[ADDR_BITS-1:0] ADDR_CS_RCV_EOF                       = 10'h210; // R
localparam[ADDR_BITS-1:0] ADDR_CS_SND_LREQ                      = 10'h214; // R
localparam[ADDR_BITS-1:0] ADDR_CS_SND_LREQ_ERR_1                = 10'h218; // R
localparam[ADDR_BITS-1:0] ADDR_CS_SND_LREQ_ERR_2                = 10'h21C; // R
localparam[ADDR_BITS-1:0] ADDR_CS_RD_DDR                        = 10'h220; // R
localparam[ADDR_BITS-1:0] ADDR_CS_SND_REQ                       = 10'h224; // R
localparam[ADDR_BITS-1:0] ADDR_CS_SND_NOTIFY_ERR_1              = 10'h228; // R
localparam[ADDR_BITS-1:0] ADDR_CS_SND_NOTIFY_ERR_2              = 10'h22C; // R
localparam[ADDR_BITS-1:0] ADDR_CS_CHID_CHK_F0                   = 10'h230; // R
localparam[ADDR_BITS-1:0] ADDR_CS_CHID_CHK_F1                   = 10'h234; // R
localparam[ADDR_BITS-1:0] ADDR_CS_RCV_RESP_0                    = 10'h238; // R
localparam[ADDR_BITS-1:0] ADDR_CS_SND_DT_0                      = 10'h23C; // R
localparam[ADDR_BITS-1:0] ADDR_CS_RCV_RESP_1                    = 10'h240; // R
localparam[ADDR_BITS-1:0] ADDR_CS_SND_DT_1                      = 10'h244; // R
localparam[ADDR_BITS-1:0] ADDR_CM_SND_REQ                       = 10'h248; // R
localparam[ADDR_BITS-1:0] ADDR_CM_SND_RESP                      = 10'h24C; // R
localparam[ADDR_BITS-1:0] ADDR_CM_SND_DATA                      = 10'h250; // R

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
  reg       r_reg_control                           ; // W
  reg[31:0] r_reg_m_axi_ingr_frame_buffer_l         ; // R/W
  reg[31:0] r_reg_m_axi_ingr_frame_buffer_h         ; // R/W
  reg[31:0] r_reg_rows_in                           ; // R/W
  reg[31:0] r_reg_cols_in                           ; // R/W
  reg[31:0] r_reg_stat_sel_channel                  ; // R/W
  reg[31:0] r_reg_stat_ingr_rcv_data_value_l        ; // RC
  reg[31:0] r_reg_stat_ingr_rcv_data_value_h        ; // RC
  reg[31:0] r_reg_stat_ingr_snd_data_0_value_l      ; // RC
  reg[31:0] r_reg_stat_ingr_snd_data_0_value_h      ; // RC
  reg[31:0] r_reg_stat_ingr_snd_data_1_value_l      ; // RC
  reg[31:0] r_reg_stat_ingr_snd_data_1_value_h      ; // RC
  reg[31:0] r_reg_stat_egr_rcv_data_0_value_l       ; // RC
  reg[31:0] r_reg_stat_egr_rcv_data_0_value_h       ; // RC
  reg[31:0] r_reg_stat_egr_rcv_data_1_value_l       ; // RC
  reg[31:0] r_reg_stat_egr_rcv_data_1_value_h       ; // RC
  reg[31:0] r_reg_stat_egr_snd_data_value_l         ; // RC
  reg[31:0] r_reg_stat_egr_snd_data_value_h         ; // RC
  reg[31:0] r_reg_stat_ingr_rcv_frame_value         ; // RC
  reg[31:0] r_reg_stat_ingr_snd_frame_0_value       ; // RC
  reg[31:0] r_reg_stat_ingr_snd_frame_1_value       ; // RC
  reg[31:0] r_reg_stat_egr_rcv_frame_0_value        ; // RC
  reg[31:0] r_reg_stat_egr_rcv_frame_1_value        ; // RC
  reg[31:0] r_reg_stat_egr_snd_frame_value          ; // RC
  reg[31:0] r_reg_stat_ingr_frame_buffer_overflow   ; // R/WC
  reg[31:0] r_reg_stat_ingr_frame_buffer_usage      ; // R
  reg[31:0] r_reg_detect_fault                      ; // R
  reg[31:0] r_reg_ingr_rcv_protocol_fault           ; // R/WC
  reg[31:0] r_reg_ingr_rcv_protocol_fault_mask      ; // R/W
  reg[31:0] r_reg_ingr_rcv_protocol_fault_force     ; // R/W
  reg[31:0] r_reg_ingr_snd_protocol_fault_0         ; // R/WC
  reg[31:0] r_reg_ingr_snd_protocol_fault_0_mask    ; // R/W
  reg[31:0] r_reg_ingr_snd_protocol_fault_0_force   ; // R/W
  reg[31:0] r_reg_ingr_snd_protocol_fault_1         ; // R/WC
  reg[31:0] r_reg_ingr_snd_protocol_fault_1_mask    ; // R/W
  reg[31:0] r_reg_ingr_snd_protocol_fault_1_force   ; // R/W
  reg[31:0] r_reg_egr_rcv_protocol_fault_0          ; // R/WC
  reg[31:0] r_reg_egr_rcv_protocol_fault_0_mask     ; // R/W
  reg[31:0] r_reg_egr_rcv_protocol_fault_0_force    ; // R/W
  reg[31:0] r_reg_egr_rcv_protocol_fault_1          ; // R/WC
  reg[31:0] r_reg_egr_rcv_protocol_fault_1_mask     ; // R/W
  reg[31:0] r_reg_egr_rcv_protocol_fault_1_force    ; // R/W
  reg[31:0] r_reg_egr_snd_protocol_fault            ; // R/WC
  reg[31:0] r_reg_egr_snd_protocol_fault_mask       ; // R/W
  reg[31:0] r_reg_egr_snd_protocol_fault_force      ; // R/W
  reg[31:0] r_reg_mem_parity_fault                  ; // R/WC
  reg[31:0] r_reg_mem_parity_fault_mask             ; // R/W
  reg[31:0] r_reg_mem_parity_fault_force            ; // R/W
  reg[31:0] r_reg_ingr_rcv_length_fault             ; // R/WC
  reg[31:0] r_reg_ingr_rcv_length_fault_mask        ; // R/W
  reg[31:0] r_reg_ingr_rcv_length_fault_force       ; // R/W
  reg[31:0] r_reg_streamif_stall                    ; // R
  reg[31:0] r_reg_streamif_stall_mask               ; // R/W
  reg[31:0] r_reg_streamif_stall_force              ; // R/W
  reg[31:0] r_reg_ingr_rcv_insert_protocol_fault    ; // R/W
  reg[31:0] r_reg_ingr_snd_insert_protocol_fault_0  ; // R/W
  reg[31:0] r_reg_ingr_snd_insert_protocol_fault_1  ; // R/W
  reg[31:0] r_reg_egr_rcv_insert_protocol_fault_0   ; // R/W
  reg[31:0] r_reg_egr_rcv_insert_protocol_fault_1   ; // R/W
  reg[31:0] r_reg_egr_snd_insert_protocol_fault     ; // R/W
  reg[31:0] r_reg_insert_mem_parity_fault           ; // R/W
  reg[31:0] r_reg_cs_rcv_req                        ; // R
  reg[31:0] r_reg_cs_snd_resp                       ; // R
  reg[31:0] r_reg_cs_rcv_dt                         ; // R
  reg[31:0] r_reg_cs_wr_ddr                         ; // R
  reg[31:0] r_reg_cs_rcv_eof                        ; // R
  reg[31:0] r_reg_cs_snd_lreq                       ; // R
  //reg[31:0] r_reg_cs_snd_lreq_err_1                 ; // R
  //reg[31:0] r_reg_cs_snd_lreq_err_2                 ; // R
  reg[31:0] r_reg_cs_rd_ddr                         ; // R
  reg[31:0] r_reg_cs_snd_req                        ; // R
  //reg[31:0] r_reg_cs_snd_notify_err_1               ; // R
  //reg[31:0] r_reg_cs_snd_notify_err_2               ; // R
  //reg[31:0] r_reg_cs_chid_chk_f0                    ; // R
  //reg[31:0] r_reg_cs_chid_chk_f1                    ; // R
  reg[31:0] r_reg_cs_rcv_resp_0                     ; // R
  reg[31:0] r_reg_cs_snd_dt_0                       ; // R
  reg[31:0] r_reg_cs_rcv_resp_1                     ; // R
  reg[31:0] r_reg_cs_snd_dt_1                       ; // R
  reg[31:0] r_reg_cm_snd_req                        ; // R
  reg[31:0] r_reg_cm_snd_resp                       ; // R
  reg[31:0] r_reg_cm_snd_data                       ; // R

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
      ADDR_CONTROL                          : rdata <= r_reg_control                          ; // R/W
      ADDR_MODULE_ID                        : rdata <= module_id                              ; // R
      ADDR_LOCAL_VERSION                    : rdata <= local_version                          ; // R
      ADDR_M_AXI_INGR_FRAME_BUFFER_L        : rdata <= r_reg_m_axi_ingr_frame_buffer_l        ; // R/W
      ADDR_M_AXI_INGR_FRAME_BUFFER_H        : rdata <= r_reg_m_axi_ingr_frame_buffer_h        ; // R/W
      ADDR_ROWS_IN                          : rdata <= r_reg_rows_in                          ; // R/W
      ADDR_COLS_IN                          : rdata <= r_reg_cols_in                          ; // R/W
      ADDR_STAT_SEL_CHANNEL                 : rdata <= r_reg_stat_sel_channel                 ; // R/W
      ADDR_STAT_INGR_RCV_DATA_VALUE_H       : rdata <= r_stat_rdack_value[63:32]              ; // RC
      ADDR_STAT_INGR_SND_DATA_0_VALUE_H     : rdata <= r_stat_rdack_value[63:32]              ; // RC
      ADDR_STAT_INGR_SND_DATA_1_VALUE_H     : rdata <= r_stat_rdack_value[63:32]              ; // RC
      ADDR_STAT_EGR_RCV_DATA_0_VALUE_H      : rdata <= r_stat_rdack_value[63:32]              ; // RC
      ADDR_STAT_EGR_RCV_DATA_1_VALUE_H      : rdata <= r_stat_rdack_value[63:32]              ; // RC
      ADDR_STAT_EGR_SND_DATA_VALUE_H        : rdata <= r_stat_rdack_value[63:32]              ; // RC
      ADDR_STAT_INGR_RCV_FRAME_VALUE        : rdata <= r_stat_rdack_value[31:0]               ; // RC
      ADDR_STAT_INGR_SND_FRAME_0_VALUE      : rdata <= r_stat_rdack_value[31:0]               ; // RC
      ADDR_STAT_INGR_SND_FRAME_1_VALUE      : rdata <= r_stat_rdack_value[31:0]               ; // RC
      ADDR_STAT_EGR_RCV_FRAME_0_VALUE       : rdata <= r_stat_rdack_value[31:0]               ; // RC
      ADDR_STAT_EGR_RCV_FRAME_1_VALUE       : rdata <= r_stat_rdack_value[31:0]               ; // RC
      ADDR_STAT_EGR_SND_FRAME_VALUE         : rdata <= r_stat_rdack_value[31:0]               ; // RC
      ADDR_STAT_INGR_FRAME_BUFFER_OVERFLOW  : rdata <= r_reg_stat_ingr_frame_buffer_overflow  ; // R/WC
      ADDR_STAT_INGR_FRAME_BUFFER_USAGE     : rdata <= r_reg_stat_ingr_frame_buffer_usage     ; // R
      ADDR_DETECT_FAULT                     : rdata <= r_reg_detect_fault                     ; // R
      ADDR_INGR_RCV_PROTOCOL_FAULT          : rdata <= r_reg_ingr_rcv_protocol_fault          ; // R/WC
      ADDR_INGR_RCV_PROTOCOL_FAULT_MASK     : rdata <= r_reg_ingr_rcv_protocol_fault_mask     ; // R/W
      ADDR_INGR_RCV_PROTOCOL_FAULT_FORCE    : rdata <= r_reg_ingr_rcv_protocol_fault_force    ; // R/W
      ADDR_INGR_SND_PROTOCOL_FAULT_0        : rdata <= r_reg_ingr_snd_protocol_fault_0        ; // R/WC
      ADDR_INGR_SND_PROTOCOL_FAULT_0_MASK   : rdata <= r_reg_ingr_snd_protocol_fault_0_mask   ; // R/W
      ADDR_INGR_SND_PROTOCOL_FAULT_0_FORCE  : rdata <= r_reg_ingr_snd_protocol_fault_0_force  ; // R/W
      ADDR_INGR_SND_PROTOCOL_FAULT_1        : rdata <= r_reg_ingr_snd_protocol_fault_1        ; // R/WC
      ADDR_INGR_SND_PROTOCOL_FAULT_1_MASK   : rdata <= r_reg_ingr_snd_protocol_fault_1_mask   ; // R/W
      ADDR_INGR_SND_PROTOCOL_FAULT_1_FORCE  : rdata <= r_reg_ingr_snd_protocol_fault_1_force  ; // R/W
      ADDR_EGR_RCV_PROTOCOL_FAULT_0         : rdata <= r_reg_egr_rcv_protocol_fault_0         ; // R/WC
      ADDR_EGR_RCV_PROTOCOL_FAULT_0_MASK    : rdata <= r_reg_egr_rcv_protocol_fault_0_mask    ; // R/W
      ADDR_EGR_RCV_PROTOCOL_FAULT_0_FORCE   : rdata <= r_reg_egr_rcv_protocol_fault_0_force   ; // R/W
      ADDR_EGR_RCV_PROTOCOL_FAULT_1         : rdata <= r_reg_egr_rcv_protocol_fault_1         ; // R/WC
      ADDR_EGR_RCV_PROTOCOL_FAULT_1_MASK    : rdata <= r_reg_egr_rcv_protocol_fault_1_mask    ; // R/W
      ADDR_EGR_RCV_PROTOCOL_FAULT_1_FORCE   : rdata <= r_reg_egr_rcv_protocol_fault_1_force   ; // R/W
      ADDR_EGR_SND_PROTOCOL_FAULT           : rdata <= r_reg_egr_snd_protocol_fault           ; // R/WC
      ADDR_EGR_SND_PROTOCOL_FAULT_MASK      : rdata <= r_reg_egr_snd_protocol_fault_mask      ; // R/W
      ADDR_EGR_SND_PROTOCOL_FAULT_FORCE     : rdata <= r_reg_egr_snd_protocol_fault_force     ; // R/W
      ADDR_MEM_PARITY_FAULT                 : rdata <= r_reg_mem_parity_fault                 ; // R/WC
      ADDR_MEM_PARITY_FAULT_MASK            : rdata <= r_reg_mem_parity_fault_mask            ; // R/W
      ADDR_MEM_PARITY_FAULT_FORCE           : rdata <= r_reg_mem_parity_fault_force           ; // R/W
      ADDR_INGR_RCV_LENGTH_FAULT            : rdata <= r_reg_ingr_rcv_length_fault            ; // R/WC
      ADDR_INGR_RCV_LENGTH_FAULT_MASK       : rdata <= r_reg_ingr_rcv_length_fault_mask       ; // R/W
      ADDR_INGR_RCV_LENGTH_FAULT_FORCE      : rdata <= r_reg_ingr_rcv_length_fault_force      ; // R/W
      ADDR_STREAMIF_STALL                   : rdata <= r_reg_streamif_stall                   ; // R
      ADDR_STREAMIF_STALL_MASK              : rdata <= r_reg_streamif_stall_mask              ; // R/W
      ADDR_STREAMIF_STALL_FORCE             : rdata <= r_reg_streamif_stall_force             ; // R/W
      ADDR_INGR_RCV_INSERT_PROTOCOL_FAULT   : rdata <= r_reg_ingr_rcv_insert_protocol_fault   ; // R/W
      ADDR_INGR_SND_INSERT_PROTOCOL_FAULT_0 : rdata <= r_reg_ingr_snd_insert_protocol_fault_0 ; // R/W
      ADDR_INGR_SND_INSERT_PROTOCOL_FAULT_1 : rdata <= r_reg_ingr_snd_insert_protocol_fault_1 ; // R/W
      ADDR_EGR_RCV_INSERT_PROTOCOL_FAULT_0  : rdata <= r_reg_egr_rcv_insert_protocol_fault_0  ; // R/W
      ADDR_EGR_RCV_INSERT_PROTOCOL_FAULT_1  : rdata <= r_reg_egr_rcv_insert_protocol_fault_1  ; // R/W
      ADDR_EGR_SND_INSERT_PROTOCOL_FAULT    : rdata <= r_reg_egr_snd_insert_protocol_fault    ; // R/W
      ADDR_INSERT_MEM_PARITY_FAULT          : rdata <= r_reg_insert_mem_parity_fault          ; // R/W
      ADDR_CS_RCV_REQ                       : rdata <= r_reg_cs_rcv_req                       ; // R
      ADDR_CS_SND_RESP                      : rdata <= r_reg_cs_snd_resp                      ; // R
      ADDR_CS_RCV_DT                        : rdata <= r_reg_cs_rcv_dt                        ; // R
      ADDR_CS_WR_DDR                        : rdata <= r_reg_cs_wr_ddr                        ; // R
      ADDR_CS_RCV_EOF                       : rdata <= r_reg_cs_rcv_eof                       ; // R
      ADDR_CS_SND_LREQ                      : rdata <= r_reg_cs_snd_lreq                      ; // R
//      ADDR_CS_SND_LREQ_ERR_1                : rdata <= r_reg_cs_snd_lreq_err_1                ; // R
//      ADDR_CS_SND_LREQ_ERR_2                : rdata <= r_reg_cs_snd_lreq_err_2                ; // R
      ADDR_CS_RD_DDR                        : rdata <= r_reg_cs_rd_ddr                        ; // R
      ADDR_CS_SND_REQ                       : rdata <= r_reg_cs_snd_req                       ; // R
//      ADDR_CS_SND_NOTIFY_ERR_1              : rdata <= r_reg_cs_snd_notify_err_1              ; // R
//      ADDR_CS_SND_NOTIFY_ERR_2              : rdata <= r_reg_cs_snd_notify_err_2              ; // R
//      ADDR_CS_CHID_CHK_F0                   : rdata <= r_reg_cs_chid_chk_f0                   ; // R
//      ADDR_CS_CHID_CHK_F1                   : rdata <= r_reg_cs_chid_chk_f1                   ; // R
      ADDR_CS_RCV_RESP_0                    : rdata <= r_reg_cs_rcv_resp_0                    ; // R
      ADDR_CS_SND_DT_0                      : rdata <= r_reg_cs_snd_dt_0                      ; // R
      ADDR_CS_RCV_RESP_1                    : rdata <= r_reg_cs_rcv_resp_1                    ; // R
      ADDR_CS_SND_DT_1                      : rdata <= r_reg_cs_snd_dt_1                      ; // R
      ADDR_CM_SND_REQ                       : rdata <= r_reg_cm_snd_req                       ; // R
      ADDR_CM_SND_RESP                      : rdata <= r_reg_cm_snd_resp                      ; // R
      ADDR_CM_SND_DATA                      : rdata <= r_reg_cm_snd_data                      ; // R
    endcase
  end else if (r_stat_rdack_valid) begin
      rdata <= r_stat_rdack_value[31:0];
  end
end

//// write-only registers
//always @(posedge ACLK) begin
//  if (!ARESET_N) begin
//    r_reg_control <= 1'b0;
//  end else begin
//    r_reg_control <= (waddr == ADDR_CONTROL) ? (WDATA[0] & wmask[0]) : 1'b0;
//  end
//end


// read/write registers
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_reg_control                           <= 1'd0;
    r_reg_m_axi_ingr_frame_buffer_l         <= 32'd0;
    r_reg_m_axi_ingr_frame_buffer_h         <= 32'd0;
    r_reg_rows_in                           <= 32'd0;
    r_reg_cols_in                           <= 32'd0;
    r_reg_stat_sel_channel                  <= 32'd0;
    r_reg_ingr_rcv_protocol_fault_mask      <= 32'd0;
    r_reg_ingr_rcv_protocol_fault_force     <= 32'd0;
    r_reg_ingr_snd_protocol_fault_0_mask    <= 32'd0;
    r_reg_ingr_snd_protocol_fault_0_force   <= 32'd0;
    r_reg_ingr_snd_protocol_fault_1_mask    <= 32'd0;
    r_reg_ingr_snd_protocol_fault_1_force   <= 32'd0;
    r_reg_egr_rcv_protocol_fault_0_mask     <= 32'd0;
    r_reg_egr_rcv_protocol_fault_0_force    <= 32'd0;
    r_reg_egr_rcv_protocol_fault_1_mask     <= 32'd0;
    r_reg_egr_rcv_protocol_fault_1_force    <= 32'd0;
    r_reg_egr_snd_protocol_fault_mask       <= 32'd0;
    r_reg_egr_snd_protocol_fault_force      <= 32'd0;
    r_reg_mem_parity_fault_mask             <= 32'd0;
    r_reg_mem_parity_fault_force            <= 32'd0;
    r_reg_ingr_rcv_length_fault_mask        <= 32'd0;
    r_reg_ingr_rcv_length_fault_force       <= 32'd0;
    r_reg_streamif_stall_mask               <= 32'd0;
    r_reg_streamif_stall_force              <= 32'd0;
    r_reg_ingr_rcv_insert_protocol_fault    <= 32'd0;
    r_reg_ingr_snd_insert_protocol_fault_0  <= 32'd0;
    r_reg_ingr_snd_insert_protocol_fault_1  <= 32'd0;
    r_reg_egr_rcv_insert_protocol_fault_0   <= 32'd0;
    r_reg_egr_rcv_insert_protocol_fault_1   <= 32'd0;
    r_reg_egr_snd_insert_protocol_fault     <= 32'd0;
    r_reg_insert_mem_parity_fault           <= 32'd0;
  end else if (w_hs) begin
    case (waddr)
      ADDR_CONTROL                            : r_reg_control                         <= ((WDATA[31:0] & wmask) | (r_reg_control                          & ~wmask))                ; // [0]
      ADDR_M_AXI_INGR_FRAME_BUFFER_L          : r_reg_m_axi_ingr_frame_buffer_l       <= ((WDATA[31:0] & wmask) | (r_reg_m_axi_ingr_frame_buffer_l        & ~wmask))                ; // [31:0]
      ADDR_M_AXI_INGR_FRAME_BUFFER_H          : r_reg_m_axi_ingr_frame_buffer_h       <= ((WDATA[31:0] & wmask) | (r_reg_m_axi_ingr_frame_buffer_h        & ~wmask))                ; // [31:0]
      ADDR_ROWS_IN                            : r_reg_rows_in                         <= ((WDATA[31:0] & wmask) | (r_reg_rows_in                          & ~wmask))                ; // [????]
      ADDR_COLS_IN                            : r_reg_cols_in                         <= ((WDATA[31:0] & wmask) | (r_reg_cols_in                          & ~wmask))                ; // [????]
      ADDR_STAT_SEL_CHANNEL                   : r_reg_stat_sel_channel                <= ((WDATA[31:0] & wmask) | (r_reg_stat_sel_channel                 & ~wmask)) & CHANNEL_MASK ; // [8:0]
      ADDR_INGR_RCV_PROTOCOL_FAULT_MASK       : r_reg_ingr_rcv_protocol_fault_mask    <= ((WDATA[31:0] & wmask) | (r_reg_ingr_rcv_protocol_fault_mask     & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_INGR_RCV_PROTOCOL_FAULT_FORCE      : r_reg_ingr_rcv_protocol_fault_force   <= ((WDATA[31:0] & wmask) | (r_reg_ingr_rcv_protocol_fault_force    & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_INGR_SND_PROTOCOL_FAULT_0_MASK     : r_reg_ingr_snd_protocol_fault_0_mask  <= ((WDATA[31:0] & wmask) | (r_reg_ingr_snd_protocol_fault_0_mask   & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_INGR_SND_PROTOCOL_FAULT_0_FORCE    : r_reg_ingr_snd_protocol_fault_0_force <= ((WDATA[31:0] & wmask) | (r_reg_ingr_snd_protocol_fault_0_force  & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_INGR_SND_PROTOCOL_FAULT_1_MASK     : r_reg_ingr_snd_protocol_fault_1_mask  <= ((WDATA[31:0] & wmask) | (r_reg_ingr_snd_protocol_fault_1_mask   & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_INGR_SND_PROTOCOL_FAULT_1_FORCE    : r_reg_ingr_snd_protocol_fault_1_force <= ((WDATA[31:0] & wmask) | (r_reg_ingr_snd_protocol_fault_1_force  & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_EGR_RCV_PROTOCOL_FAULT_0_MASK      : r_reg_egr_rcv_protocol_fault_0_mask   <= ((WDATA[31:0] & wmask) | (r_reg_egr_rcv_protocol_fault_0_mask    & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_EGR_RCV_PROTOCOL_FAULT_0_FORCE     : r_reg_egr_rcv_protocol_fault_0_force  <= ((WDATA[31:0] & wmask) | (r_reg_egr_rcv_protocol_fault_0_force   & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_EGR_RCV_PROTOCOL_FAULT_1_MASK      : r_reg_egr_rcv_protocol_fault_1_mask   <= ((WDATA[31:0] & wmask) | (r_reg_egr_rcv_protocol_fault_1_mask    & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_EGR_RCV_PROTOCOL_FAULT_1_FORCE     : r_reg_egr_rcv_protocol_fault_1_force  <= ((WDATA[31:0] & wmask) | (r_reg_egr_rcv_protocol_fault_1_force   & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_EGR_SND_PROTOCOL_FAULT_MASK        : r_reg_egr_snd_protocol_fault_mask     <= ((WDATA[31:0] & wmask) | (r_reg_egr_snd_protocol_fault_mask      & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_EGR_SND_PROTOCOL_FAULT_FORCE       : r_reg_egr_snd_protocol_fault_force    <= ((WDATA[31:0] & wmask) | (r_reg_egr_snd_protocol_fault_force     & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_MEM_PARITY_FAULT_MASK              : r_reg_mem_parity_fault_mask           <= ((WDATA[31:0] & wmask) | (r_reg_mem_parity_fault_mask            & ~wmask)) & 32'h000000ff ; // [7:0]
      ADDR_MEM_PARITY_FAULT_FORCE             : r_reg_mem_parity_fault_force          <= ((WDATA[31:0] & wmask) | (r_reg_mem_parity_fault_force           & ~wmask)) & 32'h000000ff ; // [7:0]
      ADDR_INGR_RCV_LENGTH_FAULT_MASK         : r_reg_ingr_rcv_length_fault_mask      <= ((WDATA[31:0] & wmask) | (r_reg_ingr_rcv_length_fault_mask       & ~wmask)) & 32'h000000ff ; // [7:0]
      ADDR_INGR_RCV_LENGTH_FAULT_FORCE        : r_reg_ingr_rcv_length_fault_force     <= ((WDATA[31:0] & wmask) | (r_reg_ingr_rcv_length_fault_force      & ~wmask)) & 32'h000000ff ; // [7:0]
      ADDR_STREAMIF_STALL_MASK                : r_reg_streamif_stall_mask             <= ((WDATA[31:0] & wmask) | (r_reg_streamif_stall_mask              & ~wmask)) & 32'h0003ffff ; // [17:0]
      ADDR_STREAMIF_STALL_FORCE               : r_reg_streamif_stall_force            <= ((WDATA[31:0] & wmask) | (r_reg_streamif_stall_force             & ~wmask)) & 32'h0003ffff ; // [17:0]
      ADDR_INGR_RCV_INSERT_PROTOCOL_FAULT     : r_reg_ingr_rcv_insert_protocol_fault  <= ((WDATA[31:0] & wmask) | (r_reg_ingr_rcv_insert_protocol_fault   & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_INGR_SND_INSERT_PROTOCOL_FAULT_0   : r_reg_ingr_snd_insert_protocol_fault_0<= ((WDATA[31:0] & wmask) | (r_reg_ingr_snd_insert_protocol_fault_0 & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_INGR_SND_INSERT_PROTOCOL_FAULT_1   : r_reg_ingr_snd_insert_protocol_fault_1<= ((WDATA[31:0] & wmask) | (r_reg_ingr_snd_insert_protocol_fault_1 & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_EGR_RCV_INSERT_PROTOCOL_FAULT_0    : r_reg_egr_rcv_insert_protocol_fault_0 <= ((WDATA[31:0] & wmask) | (r_reg_egr_rcv_insert_protocol_fault_0  & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_EGR_RCV_INSERT_PROTOCOL_FAULT_1    : r_reg_egr_rcv_insert_protocol_fault_1 <= ((WDATA[31:0] & wmask) | (r_reg_egr_rcv_insert_protocol_fault_1  & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_EGR_SND_INSERT_PROTOCOL_FAULT      : r_reg_egr_snd_insert_protocol_fault   <= ((WDATA[31:0] & wmask) | (r_reg_egr_snd_insert_protocol_fault    & ~wmask)) & 32'h00003fff ; // [13:0]
      ADDR_INSERT_MEM_PARITY_FAULT            : r_reg_insert_mem_parity_fault         <= ((WDATA[31:0] & wmask) | (r_reg_insert_mem_parity_fault          & ~wmask)) & 32'h000000ff ; // [7:0]
    endcase
  end
end

assign ap_start = r_reg_control;
assign rows_in = r_reg_rows_in;
assign cols_in = r_reg_cols_in;
assign ingr_fail_insert = {6'd0, r_reg_ingr_snd_insert_protocol_fault_1[12], r_reg_ingr_snd_insert_protocol_fault_0[12], r_reg_ingr_snd_insert_protocol_fault_1[8], r_reg_ingr_snd_insert_protocol_fault_0[8], r_reg_ingr_rcv_insert_protocol_fault[13], r_reg_ingr_rcv_insert_protocol_fault[3:0]};
assign egr_fail_insert  = {3'd0,
                           r_reg_egr_snd_insert_protocol_fault[12],
                           r_reg_egr_snd_insert_protocol_fault[5],
                           r_reg_egr_rcv_insert_protocol_fault_1[8], r_reg_egr_rcv_insert_protocol_fault_0[8],
                           r_reg_egr_rcv_insert_protocol_fault_1[3], r_reg_egr_rcv_insert_protocol_fault_0[3],
                           r_reg_egr_rcv_insert_protocol_fault_1[2], r_reg_egr_rcv_insert_protocol_fault_0[2],
                           r_reg_egr_rcv_insert_protocol_fault_1[1], r_reg_egr_rcv_insert_protocol_fault_0[1],
                           r_reg_egr_rcv_insert_protocol_fault_1[0], r_reg_egr_rcv_insert_protocol_fault_0[0]};
assign parity_fail_insert = r_reg_insert_mem_parity_fault[7:0];

// read clear registers
wire w_stat_ingr_rcv_data_rdreq;
wire w_stat_ingr_rcv_data_rdack_valid;
wire [63:0] w_stat_ingr_rcv_data_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_ingr_rcv_data (
    .clk        (ACLK),                              // input
    .rstn       (ARESET_N),                          // input
    .init_done  (  /* open */),                      // output
    .add_valid  (ingr_rcv_data_vld),                 // input
    .add_index  (ingr_rcv_data[CHANNEL_WIDTH-1:0]),  // input [INDEX_WIDTH-1:0]
    .add_value  (ingr_rcv_data[23:16]),              // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_ingr_rcv_data_rdreq),        // input
    .rdreq_index(r_reg_stat_sel_channel),            // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_ingr_rcv_data_rdack_valid),  // output
    .rdack_value(w_stat_ingr_rcv_data_rdack_value)   // output[COUNTER_WIDTH-1:0]
);
assign w_stat_ingr_rcv_data_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_RCV_DATA_VALUE_L);

wire w_stat_ingr_snd_data_0_rdreq;
wire w_stat_ingr_snd_data_0_rdack_valid;
wire [63:0] w_stat_ingr_snd_data_0_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_ingr_snd_data_0 (
    .clk        (ACLK),                                // input
    .rstn       (ARESET_N),                            // input
    .init_done  (  /* open */),                        // output
    .add_valid  (ingr_snd_data_0_vld),                 // input
    .add_index  (ingr_snd_data_0[CHANNEL_WIDTH-1:0]),  // input [INDEX_WIDTH-1:0]
    .add_value  (ingr_snd_data_0[23:16]),              // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_ingr_snd_data_0_rdreq),        // input
    .rdreq_index(r_reg_stat_sel_channel),              // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_ingr_snd_data_0_rdack_valid),  // output
    .rdack_value(w_stat_ingr_snd_data_0_rdack_value)   // output[COUNTER_WIDTH-1:0]
);
assign w_stat_ingr_snd_data_0_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_SND_DATA_0_VALUE_L);

wire w_stat_ingr_snd_data_1_rdreq;
wire w_stat_ingr_snd_data_1_rdack_valid;
wire [63:0] w_stat_ingr_snd_data_1_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_ingr_snd_data_1 (
    .clk        (ACLK),                                // input
    .rstn       (ARESET_N),                            // input
    .init_done  (  /* open */),                        // output
    .add_valid  (ingr_snd_data_1_vld),                 // input
    .add_index  (ingr_snd_data_1[CHANNEL_WIDTH-1:0]),  // input [INDEX_WIDTH-1:0]
    .add_value  (ingr_snd_data_1[23:16]),              // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_ingr_snd_data_1_rdreq),        // input
    .rdreq_index(r_reg_stat_sel_channel),              // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_ingr_snd_data_1_rdack_valid),  // output
    .rdack_value(w_stat_ingr_snd_data_1_rdack_value)   // output[COUNTER_WIDTH-1:0]
);
assign w_stat_ingr_snd_data_1_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_SND_DATA_1_VALUE_L);

wire w_stat_egr_rcv_data_0_rdreq;
wire w_stat_egr_rcv_data_0_rdack_valid;
wire [63:0] w_stat_egr_rcv_data_0_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_egr_rcv_data_0 (
    .clk        (ACLK),                               // input
    .rstn       (ARESET_N),                           // input
    .init_done  (  /* open */),                       // output
    .add_valid  (egr_rcv_data_0_vld),                 // input
    .add_index  (egr_rcv_data_0[CHANNEL_WIDTH-1:0]),  // input [INDEX_WIDTH-1:0]
    .add_value  (egr_rcv_data_0[23:16]),              // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_egr_rcv_data_0_rdreq),        // input
    .rdreq_index(r_reg_stat_sel_channel),             // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_egr_rcv_data_0_rdack_valid),  // output
    .rdack_value(w_stat_egr_rcv_data_0_rdack_value)   // output[COUNTER_WIDTH-1:0]
);
assign w_stat_egr_rcv_data_0_rdreq = ar_hs && (raddr == ADDR_STAT_EGR_RCV_DATA_0_VALUE_L);

wire w_stat_egr_rcv_data_1_rdreq;
wire w_stat_egr_rcv_data_1_rdack_valid;
wire [63:0] w_stat_egr_rcv_data_1_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_egr_rcv_data_1 (
    .clk        (ACLK),                               // input
    .rstn       (ARESET_N),                           // input
    .init_done  (  /* open */),                       // output
    .add_valid  (egr_rcv_data_1_vld),                 // input
    .add_index  (egr_rcv_data_1[CHANNEL_WIDTH-1:0]),  // input [INDEX_WIDTH-1:0]
    .add_value  (egr_rcv_data_1[23:16]),              // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_egr_rcv_data_1_rdreq),        // input
    .rdreq_index(r_reg_stat_sel_channel),             // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_egr_rcv_data_1_rdack_valid),  // output
    .rdack_value(w_stat_egr_rcv_data_1_rdack_value)   // output[COUNTER_WIDTH-1:0]
);
assign w_stat_egr_rcv_data_1_rdreq = ar_hs && (raddr == ADDR_STAT_EGR_RCV_DATA_1_VALUE_L);

wire w_stat_egr_snd_data_rdreq;
wire w_stat_egr_snd_data_rdack_valid;
wire [63:0] w_stat_egr_snd_data_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_egr_snd_data (
    .clk        (ACLK),                             // input
    .rstn       (ARESET_N),                         // input
    .init_done  (  /* open */),                     // output
    .add_valid  (egr_snd_data_vld),                 // input
    .add_index  (egr_snd_data[CHANNEL_WIDTH-1:0]),  // input [INDEX_WIDTH-1:0]
    .add_value  (egr_snd_data[23:16]),              // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_egr_snd_data_rdreq),        // input
    .rdreq_index(r_reg_stat_sel_channel),           // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_egr_snd_data_rdack_valid),  // output
    .rdack_value(w_stat_egr_snd_data_rdack_value)   // output[COUNTER_WIDTH-1:0]
);
assign w_stat_egr_snd_data_rdreq = ar_hs && (raddr == ADDR_STAT_EGR_SND_DATA_VALUE_L);

wire w_stat_ingr_rcv_frame_rdreq;
wire w_stat_ingr_rcv_frame_rdack_valid;
wire [63:0] w_stat_ingr_rcv_frame_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_ingr_rcv_frame (
    .clk        (ACLK),                              // input
    .rstn       (ARESET_N),                          // input
    .init_done  (  /* open */),                      // output
    .add_valid  (ingr_rcv_frame_vld),                // input
    .add_index  (ingr_rcv_frame[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
    .add_value  (ingr_rcv_frame[23:16]),             // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_ingr_rcv_frame_rdreq),       // input
    .rdreq_index(r_reg_stat_sel_channel),            // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_ingr_rcv_frame_rdack_valid), // output
    .rdack_value(w_stat_ingr_rcv_frame_rdack_value)  // output[COUNTER_WIDTH-1:0]
);
assign w_stat_ingr_rcv_frame_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_RCV_FRAME_VALUE);

wire w_stat_ingr_snd_frame_0_rdreq;
wire w_stat_ingr_snd_frame_0_rdack_valid;
wire [63:0] w_stat_ingr_snd_frame_0_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_ingr_snd_frame_0 (
    .clk        (ACLK),                                // input
    .rstn       (ARESET_N),                            // input
    .init_done  (  /* open */),                        // output
    .add_valid  (ingr_snd_frame_0_vld),                // input
    .add_index  (ingr_snd_frame_0[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
    .add_value  (ingr_snd_frame_0[23:16]),             // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_ingr_snd_frame_0_rdreq),       // input
    .rdreq_index(r_reg_stat_sel_channel),              // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_ingr_snd_frame_0_rdack_valid), // output
    .rdack_value(w_stat_ingr_snd_frame_0_rdack_value)  // output[COUNTER_WIDTH-1:0]
);
assign w_stat_ingr_snd_frame_0_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_SND_FRAME_0_VALUE);

wire w_stat_ingr_snd_frame_1_rdreq;
wire w_stat_ingr_snd_frame_1_rdack_valid;
wire [63:0] w_stat_ingr_snd_frame_1_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_ingr_snd_frame_1 (
    .clk        (ACLK),                                // input
    .rstn       (ARESET_N),                            // input
    .init_done  (  /* open */),                        // output
    .add_valid  (ingr_snd_frame_1_vld),                // input
    .add_index  (ingr_snd_frame_1[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
    .add_value  (ingr_snd_frame_1[23:16]),             // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_ingr_snd_frame_1_rdreq),       // input
    .rdreq_index(r_reg_stat_sel_channel),              // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_ingr_snd_frame_1_rdack_valid), // output
    .rdack_value(w_stat_ingr_snd_frame_1_rdack_value)  // output[COUNTER_WIDTH-1:0]
);
assign w_stat_ingr_snd_frame_1_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_SND_FRAME_1_VALUE);

wire w_stat_egr_rcv_frame_0_rdreq;
wire w_stat_egr_rcv_frame_0_rdack_valid;
wire [63:0] w_stat_egr_rcv_frame_0_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_egr_rcv_frame_0 (
    .clk        (ACLK),                               // input
    .rstn       (ARESET_N),                           // input
    .init_done  (  /* open */),                       // output
    .add_valid  (egr_rcv_frame_0_vld),                // input
    .add_index  (egr_rcv_frame_0[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
    .add_value  (egr_rcv_frame_0[23:16]),             // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_egr_rcv_frame_0_rdreq),       // input
    .rdreq_index(r_reg_stat_sel_channel),             // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_egr_rcv_frame_0_rdack_valid), // output
    .rdack_value(w_stat_egr_rcv_frame_0_rdack_value)  // output[COUNTER_WIDTH-1:0]
);
assign w_stat_egr_rcv_frame_0_rdreq = ar_hs && (raddr == ADDR_STAT_EGR_RCV_FRAME_0_VALUE);

wire w_stat_egr_rcv_frame_1_rdreq;
wire w_stat_egr_rcv_frame_1_rdack_valid;
wire [63:0] w_stat_egr_rcv_frame_1_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_egr_rcv_frame_1 (
    .clk        (ACLK),                               // input
    .rstn       (ARESET_N),                           // input
    .init_done  (  /* open */),                       // output
    .add_valid  (egr_rcv_frame_1_vld),                // input
    .add_index  (egr_rcv_frame_1[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
    .add_value  (egr_rcv_frame_1[23:16]),             // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_egr_rcv_frame_1_rdreq),       // input
    .rdreq_index(r_reg_stat_sel_channel),             // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_egr_rcv_frame_1_rdack_valid), // output
    .rdack_value(w_stat_egr_rcv_frame_1_rdack_value)  // output[COUNTER_WIDTH-1:0]
);
assign w_stat_egr_rcv_frame_1_rdreq = ar_hs && (raddr == ADDR_STAT_EGR_RCV_FRAME_1_VALUE);

wire w_stat_egr_snd_frame_rdreq;
wire w_stat_egr_snd_frame_rdack_valid;
wire [63:0] w_stat_egr_snd_frame_rdack_value;
stat_counter_table #(
    .INDEX_WIDTH  (CHANNEL_WIDTH),
    .COUNTER_WIDTH(64),
    .ADD_WIDTH    (8)
) u_stat_egr_snd_frame (
    .clk        (ACLK),                             // input
    .rstn       (ARESET_N),                         // input
    .init_done  (  /* open */),                     // output
    .add_valid  (egr_snd_frame_vld),                // input
    .add_index  (egr_snd_frame[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
    .add_value  (egr_snd_frame[23:16]),             // input [ADD_WIDTH-1:0]
    .rdreq_valid(w_stat_egr_snd_frame_rdreq),       // input
    .rdreq_index(r_reg_stat_sel_channel),           // input [INDEX_WIDTH-1:0]
    .rdack_valid(w_stat_egr_snd_frame_rdack_valid), // output
    .rdack_value(w_stat_egr_snd_frame_rdack_value)  // output[COUNTER_WIDTH-1:0]
);
assign w_stat_egr_snd_frame_rdreq = ar_hs && (raddr == ADDR_STAT_EGR_SND_FRAME_VALUE);

assign w_stat_rdreq = | {
    w_stat_ingr_rcv_data_rdreq,
    w_stat_ingr_snd_data_0_rdreq,
    w_stat_ingr_snd_data_1_rdreq,
    w_stat_egr_rcv_data_0_rdreq,
    w_stat_egr_rcv_data_1_rdreq,
    w_stat_egr_snd_data_rdreq,
    w_stat_ingr_rcv_frame_rdreq,
    w_stat_ingr_snd_frame_0_rdreq,
    w_stat_ingr_snd_frame_1_rdreq,
    w_stat_egr_rcv_frame_0_rdreq,
    w_stat_egr_rcv_frame_1_rdreq,
    w_stat_egr_snd_frame_rdreq
};

assign w_stat_rdack_valid = | {
  w_stat_ingr_rcv_data_rdack_valid,
  w_stat_ingr_snd_data_0_rdack_valid,
  w_stat_ingr_snd_data_1_rdack_valid,
  w_stat_egr_rcv_data_0_rdack_valid,
  w_stat_egr_rcv_data_1_rdack_valid,
  w_stat_egr_snd_data_rdack_valid,
  w_stat_ingr_rcv_frame_rdack_valid,
  w_stat_ingr_snd_frame_0_rdack_valid,
  w_stat_ingr_snd_frame_1_rdack_valid,
  w_stat_egr_rcv_frame_0_rdack_valid,
  w_stat_egr_rcv_frame_1_rdack_valid,
  w_stat_egr_snd_frame_rdack_valid
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
      ({64{w_stat_ingr_rcv_data_rdack_valid }}    & w_stat_ingr_rcv_data_rdack_value) |
      ({64{w_stat_ingr_snd_data_0_rdack_valid }}  & w_stat_ingr_snd_data_0_rdack_value) |
      ({64{w_stat_ingr_snd_data_1_rdack_valid  }} & w_stat_ingr_snd_data_1_rdack_value) |
      ({64{w_stat_egr_rcv_data_0_rdack_valid  }}  & w_stat_egr_rcv_data_0_rdack_value) |
      ({64{w_stat_egr_rcv_data_1_rdack_valid}}    & w_stat_egr_rcv_data_1_rdack_value) |
      ({64{w_stat_egr_snd_data_rdack_valid}}      & w_stat_egr_snd_data_rdack_value) |
      ({64{w_stat_ingr_rcv_frame_rdack_valid}}    & w_stat_ingr_rcv_frame_rdack_value) |
      ({64{w_stat_ingr_snd_frame_0_rdack_valid}}  & w_stat_ingr_snd_frame_0_rdack_value) |
      ({64{w_stat_ingr_snd_frame_1_rdack_valid}}  & w_stat_ingr_snd_frame_1_rdack_value) |
      ({64{w_stat_egr_rcv_frame_0_rdack_valid}}   & w_stat_egr_rcv_frame_0_rdack_value) |
      ({64{w_stat_egr_rcv_frame_1_rdack_valid}}   & w_stat_egr_rcv_frame_1_rdack_value) |
      ({64{w_stat_egr_snd_frame_rdack_valid}}     & w_stat_egr_snd_frame_rdack_value);
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
reg [15:0] r_ingr_rcv_protocol_fault;
reg [15:0] r_ingr_snd_protocol_fault_0;
reg [15:0] r_ingr_snd_protocol_fault_1;
reg [15:0] r_egr_rcv_protocol_fault_0;
reg [15:0] r_egr_rcv_protocol_fault_1;
reg [15:0] r_egr_snd_protocol_fault;
reg [15:0] r_mem_parity_fault;
reg [15:0] r_ingr_rcv_length_fault;

always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_ingr_rcv_protocol_fault   <= 16'd0;
    r_ingr_snd_protocol_fault_0 <= 16'd0;
    r_ingr_snd_protocol_fault_1 <= 16'd0;
    r_egr_rcv_protocol_fault_0  <= 16'd0;
    r_egr_rcv_protocol_fault_1  <= 16'd0;
    r_egr_snd_protocol_fault    <= 16'd0;
    r_mem_parity_fault          <= 16'd0;
    r_ingr_rcv_length_fault     <= 16'd0;
  end else begin
    r_ingr_rcv_protocol_fault   <= (ingr_rcv_protocol_error_vld)   ? ingr_rcv_protocol_error   : 16'd0;
    r_ingr_snd_protocol_fault_0 <= (ingr_snd_protocol_error_0_vld) ? ingr_snd_protocol_error_0 : 16'd0;
    r_ingr_snd_protocol_fault_1 <= (ingr_snd_protocol_error_1_vld) ? ingr_snd_protocol_error_1 : 16'd0;
    r_egr_rcv_protocol_fault_0  <= (egr_rcv_protocol_error_0_vld)  ? egr_rcv_protocol_error_0  : 16'd0;
    r_egr_rcv_protocol_fault_1  <= (egr_rcv_protocol_error_1_vld)  ? egr_rcv_protocol_error_1  : 16'd0;
    r_egr_snd_protocol_fault    <= (egr_snd_protocol_error_vld)    ? egr_snd_protocol_error    : 16'd0;
    r_mem_parity_fault          <= (ingr_mem_err_detect_vld)       ? ingr_mem_err_detect       : 16'd0;
    r_ingr_rcv_length_fault     <= (ingr_rcv_length_fault_vld)     ? ingr_rcv_length_fault     : 16'd0;
  end
end

wire [15:0] w_ingr_rcv_protocol_fault_set   = (r_ingr_rcv_protocol_fault   | r_reg_ingr_rcv_protocol_fault_force)   & ~r_reg_ingr_rcv_protocol_fault_mask;
wire [15:0] w_ingr_snd_protocol_fault_0_set = (r_ingr_snd_protocol_fault_0 | r_reg_ingr_snd_protocol_fault_0_force) & ~r_reg_ingr_snd_protocol_fault_0_mask;
wire [15:0] w_ingr_snd_protocol_fault_1_set = (r_ingr_snd_protocol_fault_1 | r_reg_ingr_snd_protocol_fault_1_force) & ~r_reg_ingr_snd_protocol_fault_1_mask;
wire [15:0] w_egr_rcv_protocol_fault_0_set  = (r_egr_rcv_protocol_fault_0  | r_reg_egr_rcv_protocol_fault_0_force)  & ~r_reg_egr_rcv_protocol_fault_0_mask;
wire [15:0] w_egr_rcv_protocol_fault_1_set  = (r_egr_rcv_protocol_fault_1  | r_reg_egr_rcv_protocol_fault_1_force)  & ~r_reg_egr_rcv_protocol_fault_1_mask;
wire [15:0] w_egr_snd_protocol_fault_set    = (r_egr_snd_protocol_fault    | r_reg_egr_snd_protocol_fault_force)    & ~r_reg_egr_snd_protocol_fault_mask;
wire [15:0] w_mem_parity_fault_set          = (r_mem_parity_fault          | r_reg_mem_parity_fault_force)          & ~r_reg_mem_parity_fault_mask;
wire [15:0] w_ingr_rcv_length_fault_set     = (r_ingr_rcv_length_fault     | r_reg_ingr_rcv_length_fault_force)     & ~r_reg_ingr_rcv_length_fault_mask;

wire [15:0] w_ingr_rcv_protocol_fault_clr   = (w_hs && waddr == ADDR_INGR_RCV_PROTOCOL_FAULT)   ? (WDATA[15:0] & wmask[15:0]) : 16'd0;
wire [15:0] w_ingr_snd_protocol_fault_0_clr = (w_hs && waddr == ADDR_INGR_SND_PROTOCOL_FAULT_0) ? (WDATA[15:0] & wmask[15:0]) : 16'd0;
wire [15:0] w_ingr_snd_protocol_fault_1_clr = (w_hs && waddr == ADDR_INGR_SND_PROTOCOL_FAULT_1) ? (WDATA[15:0] & wmask[15:0]) : 16'd0;
wire [15:0] w_egr_rcv_protocol_fault_0_clr  = (w_hs && waddr == ADDR_EGR_RCV_PROTOCOL_FAULT_0)  ? (WDATA[15:0] & wmask[15:0]) : 16'd0;
wire [15:0] w_egr_rcv_protocol_fault_1_clr  = (w_hs && waddr == ADDR_EGR_RCV_PROTOCOL_FAULT_1)  ? (WDATA[15:0] & wmask[15:0]) : 16'd0;
wire [15:0] w_egr_snd_protocol_fault_clr    = (w_hs && waddr == ADDR_EGR_SND_PROTOCOL_FAULT)    ? (WDATA[15:0] & wmask[15:0]) : 16'd0;
wire [15:0] w_mem_parity_fault_clr          = (w_hs && waddr == ADDR_MEM_PARITY_FAULT)          ? (WDATA[15:0] & wmask[15:0]) : 16'd0;
wire [15:0] w_ingr_rcv_length_fault_clr     = (w_hs && waddr == ADDR_INGR_RCV_LENGTH_FAULT)     ? (WDATA[15:0] & wmask[15:0]) : 16'd0;

always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_reg_ingr_rcv_protocol_fault   <= 16'd0;
    r_reg_ingr_snd_protocol_fault_0 <= 16'd0;
    r_reg_ingr_snd_protocol_fault_1 <= 16'd0;
    r_reg_egr_rcv_protocol_fault_0  <= 16'd0;
    r_reg_egr_rcv_protocol_fault_1  <= 16'd0;
    r_reg_egr_snd_protocol_fault    <= 16'd0;
    r_reg_mem_parity_fault          <= 16'd0;
    r_reg_ingr_rcv_length_fault     <= 16'd0;
  end else begin
    r_reg_ingr_rcv_protocol_fault   <= (r_reg_ingr_rcv_protocol_fault   & ~w_ingr_rcv_protocol_fault_clr)   | w_ingr_rcv_protocol_fault_set;
    r_reg_ingr_snd_protocol_fault_0 <= (r_reg_ingr_snd_protocol_fault_0 & ~w_ingr_snd_protocol_fault_0_clr) | w_ingr_snd_protocol_fault_0_set;
    r_reg_ingr_snd_protocol_fault_1 <= (r_reg_ingr_snd_protocol_fault_1 & ~w_ingr_snd_protocol_fault_1_clr) | w_ingr_snd_protocol_fault_1_set;
    r_reg_egr_rcv_protocol_fault_0  <= (r_reg_egr_rcv_protocol_fault_0  & ~w_egr_rcv_protocol_fault_0_clr)  | w_egr_rcv_protocol_fault_0_set;
    r_reg_egr_rcv_protocol_fault_1  <= (r_reg_egr_rcv_protocol_fault_1  & ~w_egr_rcv_protocol_fault_1_clr)  | w_egr_rcv_protocol_fault_1_set;
    r_reg_egr_snd_protocol_fault    <= (r_reg_egr_snd_protocol_fault    & ~w_egr_snd_protocol_fault_clr)    | w_egr_snd_protocol_fault_set;
    r_reg_mem_parity_fault          <= (r_reg_mem_parity_fault          & ~w_mem_parity_fault_clr)          | w_mem_parity_fault_set;
    r_reg_ingr_rcv_length_fault     <= (r_reg_ingr_rcv_length_fault     & ~w_ingr_rcv_length_fault_clr)     | w_ingr_rcv_length_fault_set;
  end
end

// frame buffer
reg [3:0] rd_wr_counter [0:7];
reg [7:0] buffer_overflow;
reg [7:0] write_channel;
reg [7:0] read_channel;
reg [3:0] buffer_usage;
integer i;

always @(posedge ACLK) begin
  if (!ARESET_N) begin
    for (i = 0; i < 8; i = i + 1) begin
      rd_wr_counter[i] <= 4'h00;
    end
    buffer_overflow <= 8'h00;
    write_channel <= 8'h0;
    read_channel <= 8'h0;
    buffer_usage <= 4'h0;
  end else begin
    if (ingr_frame_buffer_write_vld) begin
      write_channel = ingr_frame_buffer_write[7:0];
      if (rd_wr_counter[write_channel] > 4'd8) begin
        buffer_overflow[write_channel] <= 1'b1;
      end else begin
        rd_wr_counter[write_channel] <= rd_wr_counter[write_channel] + 1;
      end
    end
    if (ingr_frame_buffer_read_vld) begin
      read_channel = ingr_frame_buffer_read[7:0];
      if (rd_wr_counter[read_channel] > 4'd0) begin
        rd_wr_counter[read_channel] <= rd_wr_counter[read_channel] - 1;
      end
    end
    buffer_usage <= rd_wr_counter[r_reg_stat_sel_channel[2:0]];
  end
end

wire [31:0] w_ingr_frame_buffer_overflow_clr   = (w_hs && waddr == ADDR_STAT_INGR_FRAME_BUFFER_OVERFLOW) ? (WDATA[31:0] & wmask[31:0]) : 32'd0;
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_reg_stat_ingr_frame_buffer_overflow <= 32'd0;
    r_reg_stat_ingr_frame_buffer_usage    <= 32'd0;
  end else begin
    r_reg_stat_ingr_frame_buffer_overflow <= ({28'd0, buffer_overflow} & ~w_ingr_frame_buffer_overflow_clr);
    r_reg_stat_ingr_frame_buffer_usage    <= {28'd0, buffer_usage};
  end
end


//------------------------Register logic-----------------
//assign interrupt            = int_interrupt;
//assign ap_start             = int_ap_start;
//assign task_ap_done         = (ap_done && !auto_restart_status) || auto_restart_done;
//assign task_ap_ready        = ap_ready && !int_auto_restart;
//assign ap_continue          = int_ap_continue || auto_restart_status;
//assign ddr_data             = int_ddr_data;
assign m_axi_ingr_frame_buffer = {r_reg_m_axi_ingr_frame_buffer_h, r_reg_m_axi_ingr_frame_buffer_l};


//// int_ap_continue
//always @(posedge ACLK) begin
//    if (ARESET)
//        int_ap_continue <= 1'b0;
//    else if (ACLK_EN) begin
//        if (w_hs && waddr == ADDR_AP_CTRL && WSTRB[0] && WDATA[4])
//            int_ap_continue <= 1'b1;
//        else
//            int_ap_continue <= 1'b0; // self clear
//    end
//end
//
//// auto_restart_status
//always @(posedge ACLK) begin
//    if (ARESET)
//        auto_restart_status <= 1'b0;
//    else if (ACLK_EN) begin
//        if (int_auto_restart)
//            auto_restart_status <= 1'b1;
//        else if (ap_idle)
//            auto_restart_status <= 1'b0;
//    end
//end

// dbg register
always @(posedge ACLK) begin
    if (!ARESET_N) begin
        r_reg_cs_rcv_req    <= 0;
        r_reg_cs_snd_resp   <= 0;
        r_reg_cs_rcv_dt     <= 0;
        r_reg_cs_wr_ddr     <= 0;
        r_reg_cs_rcv_eof    <= 0;
        r_reg_cs_snd_lreq   <= 0;
        r_reg_cs_rd_ddr     <= 0;
        r_reg_cs_snd_req    <= 0;
        r_reg_cs_rcv_resp_0 <= 0;
        r_reg_cs_snd_dt_0   <= 0;
        r_reg_cs_rcv_resp_1 <= 0;
        r_reg_cs_snd_dt_1   <= 0;
        r_reg_cm_snd_req    <= 0;
        r_reg_cm_snd_resp   <= 0;
        r_reg_cm_snd_data   <= 0;
    end else begin
        r_reg_cs_rcv_req    <= cs_rcv_req;
        r_reg_cs_snd_resp   <= cs_snd_resp;
        r_reg_cs_rcv_dt     <= cs_rcv_dt;
        r_reg_cs_wr_ddr     <= cs_wr_ddr;
        r_reg_cs_rcv_eof    <= cs_rcv_eof;
        r_reg_cs_snd_lreq   <= cs_snd_lreq;
        r_reg_cs_rd_ddr     <= cs_rd_ddr;
        r_reg_cs_snd_req    <= cs_snd_req;
        r_reg_cs_rcv_resp_0 <= cs_rcv_resp_0;
        r_reg_cs_snd_dt_0   <= cs_snd_dt_0;
        r_reg_cs_rcv_resp_1 <= cs_rcv_resp_1;
        r_reg_cs_snd_dt_1   <= cs_snd_dt_1;
        r_reg_cm_snd_req    <= cm_snd_req;
        r_reg_cm_snd_resp   <= cm_snd_resp;
        r_reg_cm_snd_data   <= cm_snd_data;
    end
end


//detect_fault
reg r_fault_or;
always @(posedge ACLK) begin
    if (!ARESET_N) begin
        r_fault_or <= 1'b0;
        r_reg_detect_fault <= 1'b0;
    end else begin
        r_fault_or <= |{r_reg_ingr_rcv_protocol_fault, r_reg_ingr_snd_protocol_fault_0, r_reg_ingr_snd_protocol_fault_1, r_reg_egr_rcv_protocol_fault_0, r_reg_egr_rcv_protocol_fault_1, r_reg_egr_snd_protocol_fault, r_reg_mem_parity_fault, r_reg_ingr_rcv_length_fault};
        r_reg_detect_fault <= r_fault_or;
    end
end
assign detect_fault = r_reg_detect_fault;

endmodule

`default_nettype wire
