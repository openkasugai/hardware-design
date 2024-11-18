/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`default_nettype none

`timescale 1ns/1ps
module direct_trans_adaptor_control_s_axi #(
    parameter integer C_S_AXI_ADDR_WIDTH = 12,
    parameter integer C_S_AXI_DATA_WIDTH = 32
) (
    input  wire                            ACLK,
    input  wire                            ARESET_N,
    input  wire [  C_S_AXI_ADDR_WIDTH-1:0] AWADDR,
    input  wire                            AWVALID,
    output wire                            AWREADY,
    input  wire [  C_S_AXI_DATA_WIDTH-1:0] WDATA,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0] WSTRB,
    input  wire                            WVALID,
    output wire                            WREADY,
    output wire [                     1:0] BRESP,
    output wire                            BVALID,
    input  wire                            BREADY,
    input  wire [  C_S_AXI_ADDR_WIDTH-1:0] ARADDR,
    input  wire                            ARVALID,
    output wire                            ARREADY,
    output wire [  C_S_AXI_DATA_WIDTH-1:0] RDATA,
    output wire [                     1:0] RRESP,
    output wire                            RVALID,
    input  wire                            RREADY,
    output wire                            ap_start,
    input  wire [                    31:0] module_id,
    input  wire [                    31:0] local_version,
    output wire                            detect_fault,
    input  wire [                    15:0] stat_ingr_rcv_frame,
    input  wire                            stat_ingr_rcv_frame_ap_vld,
    input  wire [                    15:0] stat_ingr_snd_frame,
    input  wire                            stat_ingr_snd_frame_ap_vld,
    input  wire [                    23:0] stat_ingr_rcv_data,
    input  wire                            stat_ingr_rcv_data_ap_vld,
    input  wire [                    23:0] stat_ingr_snd_data,
    input  wire                            stat_ingr_snd_data_ap_vld,
    input  wire [                    15:0] stat_egr_rcv_frame,
    input  wire                            stat_egr_rcv_frame_ap_vld,
    input  wire [                    15:0] stat_egr_snd_frame,
    input  wire                            stat_egr_snd_frame_ap_vld,
    input  wire [                    23:0] stat_egr_rcv_data,
    input  wire                            stat_egr_rcv_data_ap_vld,
    input  wire [                    23:0] stat_egr_snd_data,
    input  wire                            stat_egr_snd_data_ap_vld,
    input  wire [                    15:0] ingr_rcv_protocol_fault,
    input  wire                            ingr_rcv_protocol_fault_ap_vld,
    input  wire [                    15:0] ingr_snd_protocol_fault,
    input  wire                            ingr_snd_protocol_fault_ap_vld,
    input  wire [                    15:0] egr_rcv_protocol_fault,
    input  wire                            egr_rcv_protocol_fault_ap_vld,
    input  wire [                    15:0] egr_snd_protocol_fault,
    input  wire                            egr_snd_protocol_fault_ap_vld,
    input  wire [                    11:0] streamif_stall,
    output wire [                    15:0] ingr_rcv_insert_protocol_fault,
    output wire [                    15:0] ingr_snd_insert_protocol_fault,
    output wire [                    15:0] egr_rcv_insert_protocol_fault,
    output wire [                    15:0] egr_snd_insert_protocol_fault
);

  //------------------------Parameter----------------------

  localparam integer WRIDLE = 2'd0;
  localparam integer WRDATA = 2'd1;
  localparam integer WRRESP = 2'd2;
  localparam integer WRRESET = 2'd3;
  localparam integer RDIDLE = 2'd0;
  localparam integer RDWAIT = 2'd1;
  localparam integer RDDATA = 2'd2;
  localparam integer RDRESET = 2'd3;

  localparam integer ADDR_BITS = C_S_AXI_ADDR_WIDTH;

  localparam [ADDR_BITS-1:0] ADDR_CONTROL = 12'h000;  // W
  localparam [ADDR_BITS-1:0] ADDR_MODULE_ID = 12'h010;  // R
  localparam [ADDR_BITS-1:0] ADDR_LOCAL_VERSION = 12'h020;  // R
  localparam [ADDR_BITS-1:0] ADDR_STAT_SEL_CHANNEL = 12'h040;  // R/W
  localparam [ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_DATA_VALUE_L = 12'h050;  // RC
  localparam [ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_DATA_VALUE_H = 12'h054;  // RC
  localparam [ADDR_BITS-1:0] ADDR_STAT_INGR_SND_DATA_VALUE_L = 12'h058;  // RC
  localparam [ADDR_BITS-1:0] ADDR_STAT_INGR_SND_DATA_VALUE_H = 12'h05C;  // RC
  localparam [ADDR_BITS-1:0] ADDR_STAT_EGR_RCV_DATA_VALUE_L = 12'h060;  // RC
  localparam [ADDR_BITS-1:0] ADDR_STAT_EGR_RCV_DATA_VALUE_H = 12'h064;  // RC
  localparam [ADDR_BITS-1:0] ADDR_STAT_EGR_SND_DATA_VALUE_L = 12'h068;  // RC
  localparam [ADDR_BITS-1:0] ADDR_STAT_EGR_SND_DATA_VALUE_H = 12'h06C;  // RC
  localparam [ADDR_BITS-1:0] ADDR_STAT_INGR_RCV_FRAME_VALUE = 12'h070;  // RC
  localparam [ADDR_BITS-1:0] ADDR_STAT_INGR_SND_FRAME_VALUE = 12'h074;  // RC
  localparam [ADDR_BITS-1:0] ADDR_STAT_EGR_RCV_FRAME_VALUE = 12'h078;  // RC
  localparam [ADDR_BITS-1:0] ADDR_STAT_EGR_SND_FRAME_VALUE = 12'h07C;  // RC
  localparam [ADDR_BITS-1:0] ADDR_DETECT_FAULT = 12'h100;  // R
  localparam [ADDR_BITS-1:0] ADDR_INGR_RCV_PROTOCOL_FAULT = 12'h110;  // R/WC
  localparam [ADDR_BITS-1:0] ADDR_INGR_RCV_PROTOCOL_FAULT_MASK = 12'h118;  // R/W
  localparam [ADDR_BITS-1:0] ADDR_INGR_RCV_PROTOCOL_FAULT_FORCE = 12'h11C;  // R/W
  localparam [ADDR_BITS-1:0] ADDR_INGR_SND_PROTOCOL_FAULT = 12'h120;  // R/WC
  localparam [ADDR_BITS-1:0] ADDR_INGR_SND_PROTOCOL_FAULT_MASK = 12'h128;  // R/W
  localparam [ADDR_BITS-1:0] ADDR_INGR_SND_PROTOCOL_FAULT_FORCE = 12'h12C;  // R/W
  localparam [ADDR_BITS-1:0] ADDR_EGR_RCV_PROTOCOL_FAULT = 12'h130;  // R/WC
  localparam [ADDR_BITS-1:0] ADDR_EGR_RCV_PROTOCOL_FAULT_MASK = 12'h138;  // R/W
  localparam [ADDR_BITS-1:0] ADDR_EGR_RCV_PROTOCOL_FAULT_FORCE = 12'h13C;  // R/W
  localparam [ADDR_BITS-1:0] ADDR_EGR_SND_PROTOCOL_FAULT = 12'h140;  // R/WC
  localparam [ADDR_BITS-1:0] ADDR_EGR_SND_PROTOCOL_FAULT_MASK = 12'h148;  // R/W
  localparam [ADDR_BITS-1:0] ADDR_EGR_SND_PROTOCOL_FAULT_FORCE = 12'h14C;  // R/W
  localparam [ADDR_BITS-1:0] ADDR_STREAMIF_STALL = 12'h150;  // R
  localparam [ADDR_BITS-1:0] ADDR_STREAMIF_STALL_MASK = 12'h158;  // R/W
  localparam [ADDR_BITS-1:0] ADDR_STREAMIF_STALL_FORCE = 12'h15C;  // R/W
  localparam [ADDR_BITS-1:0] ADDR_INGR_RCV_INSERT_PROTOCOL_FAULT = 12'h180;  // R/W
  localparam [ADDR_BITS-1:0] ADDR_INGR_SND_INSERT_PROTOCOL_FAULT = 12'h184;  // R/W
  localparam [ADDR_BITS-1:0] ADDR_EGR_RCV_INSERT_PROTOCOL_FAULT = 12'h188;  // R/W
  localparam [ADDR_BITS-1:0] ADDR_EGR_SND_INSERT_PROTOCOL_FAULT = 12'h18C;  // R/W

  localparam integer CHANNEL_WIDTH = 9;
  localparam integer MAX_NUM_CHANNELS = 1 << CHANNEL_WIDTH;
  localparam [31:0] CHANNEL_MASK = (1 << CHANNEL_WIDTH) - 1;

  //------------------------Local signal-------------------
  reg  [                   1:0] wstate = WRRESET;
  reg  [                   1:0] wnext;
  reg  [         ADDR_BITS-1:0] waddr;
  wire [C_S_AXI_DATA_WIDTH-1:0] wmask;
  wire                          aw_hs;
  wire                          w_hs;
  reg  [                   1:0] rstate = RDRESET;
  reg  [                   1:0] rnext;
  reg  [C_S_AXI_DATA_WIDTH-1:0] rdata;
  reg  [C_S_AXI_DATA_WIDTH-1:0] r_hi_word;
  wire                          ar_hs;
  wire [         ADDR_BITS-1:0] raddr;

  // internal registers
  reg                           r_reg_control;  // R/W
  reg  [     CHANNEL_WIDTH-1:0] r_reg_stat_sel_channel;  // R/W
  reg  [                  31:0] r_reg_stat_ingr_rcv_data_value_l;  // RC
  reg  [                  31:0] r_reg_stat_ingr_rcv_data_value_h;  // RC
  reg  [                  31:0] r_reg_stat_ingr_snd_data_value_l;  // RC
  reg  [                  31:0] r_reg_stat_ingr_snd_data_value_h;  // RC
  reg  [                  31:0] r_reg_stat_egr_rcv_data_value_l;  // RC
  reg  [                  31:0] r_reg_stat_egr_rcv_data_value_h;  // RC
  reg  [                  31:0] r_reg_stat_egr_snd_data_value_l;  // RC
  reg  [                  31:0] r_reg_stat_egr_snd_data_value_h;  // RC
  reg  [                  31:0] r_reg_stat_ingr_rcv_frame_value;  // RC
  reg  [                  31:0] r_reg_stat_ingr_snd_frame_value;  // RC
  reg  [                  31:0] r_reg_stat_egr_rcv_frame_value;  // RC
  reg  [                  31:0] r_reg_stat_egr_snd_frame_value;  // RC
  reg                           r_reg_detect_fault;  // R
  reg  [                  13:0] r_reg_ingr_rcv_protocol_fault;  // R/WC
  reg  [                  13:0] r_reg_ingr_rcv_protocol_fault_mask;  // R/W
  reg  [                  13:0] r_reg_ingr_rcv_protocol_fault_force;  // R/W
  reg  [                  13:0] r_reg_ingr_snd_protocol_fault;  // R/WC
  reg  [                  13:0] r_reg_ingr_snd_protocol_fault_mask;  // R/W
  reg  [                  13:0] r_reg_ingr_snd_protocol_fault_force;  // R/W
  reg  [                  13:0] r_reg_egr_rcv_protocol_fault;  // R/WC
  reg  [                  13:0] r_reg_egr_rcv_protocol_fault_mask;  // R/W
  reg  [                  13:0] r_reg_egr_rcv_protocol_fault_force;  // R/W
  reg  [                  13:0] r_reg_egr_snd_protocol_fault;  // R/WC
  reg  [                  13:0] r_reg_egr_snd_protocol_fault_mask;  // R/W
  reg  [                  13:0] r_reg_egr_snd_protocol_fault_force;  // R/W
  reg  [                  11:0] r_reg_streamif_stall;  // R
  reg  [                  11:0] r_reg_streamif_stall_mask;  // R/W
  reg  [                  11:0] r_reg_streamif_stall_force;  // R/W
  reg  [                  13:0] r_reg_ingr_rcv_insert_protocol_fault;  // R/W
  reg  [                  13:0] r_reg_ingr_snd_insert_protocol_fault;  // R/W
  reg  [                  13:0] r_reg_egr_rcv_insert_protocol_fault;  // R/W
  reg  [                  13:0] r_reg_egr_snd_insert_protocol_fault;  // R/W

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
    if (!ARESET_N) wstate <= WRRESET;
    else wstate <= wnext;
  end

  // wnext
  always @(*) begin
    case (wstate)
      WRIDLE:  if (AWVALID) wnext = WRDATA;
 else wnext = WRIDLE;
      WRDATA:  if (WVALID) wnext = WRRESP;
 else wnext = WRDATA;
      WRRESP:  if (BREADY) wnext = WRIDLE;
 else wnext = WRRESP;
      default: wnext = WRIDLE;
    endcase
  end

  // waddr
  always @(posedge ACLK) begin
    if (aw_hs) waddr <= AWADDR[ADDR_BITS-1:0];
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
  reg r_stat_header_buff_bp_rdata;

  // rstate
  always @(posedge ACLK) begin
    if (!ARESET_N) rstate <= RDRESET;
    else rstate <= rnext;
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
      default: rnext = RDIDLE;
    endcase
  end

  // rdata
  always @(posedge ACLK) begin
    if (!ARESET_N) begin
      rdata <= 32'd0;
    end else if (ar_hs) begin
      rdata <= 'b0;
      case (raddr)
        ADDR_CONTROL:                        rdata <= r_reg_control;  // R/W
        ADDR_MODULE_ID:                      rdata <= module_id;  // R
        ADDR_LOCAL_VERSION:                  rdata <= local_version;  // R
        ADDR_STAT_SEL_CHANNEL:               rdata <= r_reg_stat_sel_channel;  // R/W
        ADDR_STAT_INGR_RCV_DATA_VALUE_H:     rdata <= r_stat_rdack_value[63:32];  // RC
        ADDR_STAT_INGR_SND_DATA_VALUE_H:     rdata <= r_stat_rdack_value[63:32];  // RC
        ADDR_STAT_EGR_RCV_DATA_VALUE_H:      rdata <= r_stat_rdack_value[63:32];  // RC
        ADDR_STAT_EGR_SND_DATA_VALUE_H:      rdata <= r_stat_rdack_value[63:32];  // RC
        ADDR_STAT_INGR_RCV_FRAME_VALUE:      rdata <= r_reg_stat_ingr_rcv_frame_value;  // RC
        ADDR_STAT_INGR_SND_FRAME_VALUE:      rdata <= r_reg_stat_ingr_snd_frame_value;  // RC
        ADDR_STAT_EGR_RCV_FRAME_VALUE:       rdata <= r_reg_stat_egr_rcv_frame_value;  // RC
        ADDR_STAT_EGR_SND_FRAME_VALUE:       rdata <= r_reg_stat_egr_snd_frame_value;  // RC
        ADDR_DETECT_FAULT:                   rdata <= r_reg_detect_fault;  // R
        ADDR_INGR_RCV_PROTOCOL_FAULT:        rdata <= r_reg_ingr_rcv_protocol_fault;  // R/WC
        ADDR_INGR_RCV_PROTOCOL_FAULT_MASK:   rdata <= r_reg_ingr_rcv_protocol_fault_mask;  // R/W
        ADDR_INGR_RCV_PROTOCOL_FAULT_FORCE:  rdata <= r_reg_ingr_rcv_protocol_fault_force;  // R/W
        ADDR_INGR_SND_PROTOCOL_FAULT:        rdata <= r_reg_ingr_snd_protocol_fault;  // R/WC
        ADDR_INGR_SND_PROTOCOL_FAULT_MASK:   rdata <= r_reg_ingr_snd_protocol_fault_mask;  // R/W
        ADDR_INGR_SND_PROTOCOL_FAULT_FORCE:  rdata <= r_reg_ingr_snd_protocol_fault_force;  // R/W
        ADDR_EGR_RCV_PROTOCOL_FAULT:         rdata <= r_reg_egr_rcv_protocol_fault;  // R/WC
        ADDR_EGR_RCV_PROTOCOL_FAULT_MASK:    rdata <= r_reg_egr_rcv_protocol_fault_mask;  // R/W
        ADDR_EGR_RCV_PROTOCOL_FAULT_FORCE:   rdata <= r_reg_egr_rcv_protocol_fault_force;  // R/W
        ADDR_EGR_SND_PROTOCOL_FAULT:         rdata <= r_reg_egr_snd_protocol_fault;  // R/WC
        ADDR_EGR_SND_PROTOCOL_FAULT_MASK:    rdata <= r_reg_egr_snd_protocol_fault_mask;  // R/W
        ADDR_EGR_SND_PROTOCOL_FAULT_FORCE:   rdata <= r_reg_egr_snd_protocol_fault_force;  // R/W
        ADDR_STREAMIF_STALL:                 rdata <= r_reg_streamif_stall;  // R
        ADDR_STREAMIF_STALL_MASK:            rdata <= r_reg_streamif_stall_mask;  // R/W
        ADDR_STREAMIF_STALL_FORCE:           rdata <= r_reg_streamif_stall_force;  // R/W
        ADDR_INGR_RCV_INSERT_PROTOCOL_FAULT: rdata <= r_reg_ingr_rcv_insert_protocol_fault;  // R/W
        ADDR_INGR_SND_INSERT_PROTOCOL_FAULT: rdata <= r_reg_ingr_snd_insert_protocol_fault;  // R/W
        ADDR_EGR_RCV_INSERT_PROTOCOL_FAULT:  rdata <= r_reg_egr_rcv_insert_protocol_fault;  // R/W
        ADDR_EGR_SND_INSERT_PROTOCOL_FAULT:  rdata <= r_reg_egr_snd_insert_protocol_fault;  // R/W
      endcase
    end else if (r_stat_rdack_valid) begin
      rdata <= r_stat_rdack_value[31:0];
    end
  end

  assign ap_start = r_reg_control;

  // read/write registers
  always @(posedge ACLK) begin
    if (!ARESET_N) begin
      r_reg_control                        <= 32'd0;
      r_reg_stat_sel_channel               <= 32'd0;
      r_reg_ingr_rcv_protocol_fault_mask   <= 32'd0;
      r_reg_ingr_rcv_protocol_fault_force  <= 32'd0;
      r_reg_ingr_snd_protocol_fault_mask   <= 32'd0;
      r_reg_ingr_snd_protocol_fault_force  <= 32'd0;
      r_reg_egr_rcv_protocol_fault_mask    <= 32'd0;
      r_reg_egr_rcv_protocol_fault_force   <= 32'd0;
      r_reg_egr_snd_protocol_fault_mask    <= 32'd0;
      r_reg_egr_snd_protocol_fault_force   <= 32'd0;
      r_reg_streamif_stall_mask            <= 32'd0;
      r_reg_streamif_stall_force           <= 32'd0;
      r_reg_ingr_rcv_insert_protocol_fault <= 32'd0;
      r_reg_ingr_snd_insert_protocol_fault <= 32'd0;
      r_reg_egr_rcv_insert_protocol_fault  <= 32'd0;
      r_reg_egr_snd_insert_protocol_fault  <= 32'd0;
    end else if (w_hs) begin
      case (waddr)
        ADDR_CONTROL:                        r_reg_control <= ((WDATA[31:0] & wmask) | (r_reg_control & ~wmask)) & 32'h00000001;  // [0]
        ADDR_STAT_SEL_CHANNEL:               r_reg_stat_sel_channel <= ((WDATA[31:0] & wmask) | (r_reg_stat_sel_channel & ~wmask)) & CHANNEL_MASK;  // [8:0]
        ADDR_INGR_RCV_PROTOCOL_FAULT_MASK:   r_reg_ingr_rcv_protocol_fault_mask <= ((WDATA[31:0] & wmask) | (r_reg_ingr_rcv_protocol_fault_mask & ~wmask)) & 32'h00003fff;  // [13:0]
        ADDR_INGR_RCV_PROTOCOL_FAULT_FORCE:  r_reg_ingr_rcv_protocol_fault_force <= ((WDATA[31:0] & wmask) | (r_reg_ingr_rcv_protocol_fault_force & ~wmask)) & 32'h00003fff;  // [13:0]
        ADDR_INGR_SND_PROTOCOL_FAULT_MASK:   r_reg_ingr_snd_protocol_fault_mask <= ((WDATA[31:0] & wmask) | (r_reg_ingr_snd_protocol_fault_mask & ~wmask)) & 32'h00003fff;  // [13:0]
        ADDR_INGR_SND_PROTOCOL_FAULT_FORCE:  r_reg_ingr_snd_protocol_fault_force <= ((WDATA[31:0] & wmask) | (r_reg_ingr_snd_protocol_fault_force & ~wmask)) & 32'h00003fff;  // [13:0]
        ADDR_EGR_RCV_PROTOCOL_FAULT_MASK:    r_reg_egr_rcv_protocol_fault_mask <= ((WDATA[31:0] & wmask) | (r_reg_egr_rcv_protocol_fault_mask & ~wmask)) & 32'h00003fff;  // [13:0]
        ADDR_EGR_RCV_PROTOCOL_FAULT_FORCE:   r_reg_egr_rcv_protocol_fault_force <= ((WDATA[31:0] & wmask) | (r_reg_egr_rcv_protocol_fault_force & ~wmask)) & 32'h00003fff;  // [13:0]
        ADDR_EGR_SND_PROTOCOL_FAULT_MASK:    r_reg_egr_snd_protocol_fault_mask <= ((WDATA[31:0] & wmask) | (r_reg_egr_snd_protocol_fault_mask & ~wmask)) & 32'h00003fff;  // [13:0]
        ADDR_EGR_SND_PROTOCOL_FAULT_FORCE:   r_reg_egr_snd_protocol_fault_force <= ((WDATA[31:0] & wmask) | (r_reg_egr_snd_protocol_fault_force & ~wmask)) & 32'h00003fff;  // [13:0]
        ADDR_STREAMIF_STALL_MASK:            r_reg_streamif_stall_mask <= ((WDATA[31:0] & wmask) | (r_reg_streamif_stall_mask & ~wmask)) & 32'h00000fff;  // [11:0]
        ADDR_STREAMIF_STALL_FORCE:           r_reg_streamif_stall_force <= ((WDATA[31:0] & wmask) | (r_reg_streamif_stall_force & ~wmask)) & 32'h00000fff;  // [11:0]
        ADDR_INGR_RCV_INSERT_PROTOCOL_FAULT: r_reg_ingr_rcv_insert_protocol_fault <= ((WDATA[31:0] & wmask) | (r_reg_ingr_rcv_insert_protocol_fault & ~wmask)) & 32'h00003fff;  // [13:0]
        ADDR_INGR_SND_INSERT_PROTOCOL_FAULT: r_reg_ingr_snd_insert_protocol_fault <= ((WDATA[31:0] & wmask) | (r_reg_ingr_snd_insert_protocol_fault & ~wmask)) & 32'h00003fff;  // [13:0]
        ADDR_EGR_RCV_INSERT_PROTOCOL_FAULT:  r_reg_egr_rcv_insert_protocol_fault <= ((WDATA[31:0] & wmask) | (r_reg_egr_rcv_insert_protocol_fault & ~wmask)) & 32'h00003fff;  // [13:0]
        ADDR_EGR_SND_INSERT_PROTOCOL_FAULT:  r_reg_egr_snd_insert_protocol_fault <= ((WDATA[31:0] & wmask) | (r_reg_egr_snd_insert_protocol_fault & ~wmask)) & 32'h00003fff;  // [13:0]
      endcase
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
  reg [13:0] r_ingr_rcv_protocol_fault;
  reg [13:0] r_ingr_snd_protocol_fault;
  reg [13:0] r_egr_rcv_protocol_fault;
  reg [13:0] r_egr_snd_protocol_fault;
  always @(posedge ACLK) begin
    if (!ARESET_N) begin
      r_ingr_rcv_protocol_fault <= 14'd0;
      r_ingr_snd_protocol_fault <= 14'd0;
      r_egr_rcv_protocol_fault  <= 14'd0;
      r_egr_snd_protocol_fault  <= 14'd0;
    end else begin
      r_ingr_rcv_protocol_fault <= (ingr_rcv_protocol_fault_ap_vld) ? ingr_rcv_protocol_fault[13:0] : 14'd0;
      r_ingr_snd_protocol_fault <= (ingr_snd_protocol_fault_ap_vld) ? ingr_snd_protocol_fault[13:0] : 14'd0;
      r_egr_rcv_protocol_fault  <= (egr_rcv_protocol_fault_ap_vld) ? egr_rcv_protocol_fault[13:0] : 14'd0;
      r_egr_snd_protocol_fault  <= (egr_snd_protocol_fault_ap_vld) ? egr_snd_protocol_fault[13:0] : 14'd0;
    end
  end

  wire [13:0] w_ingr_rcv_protocol_fault_set = (r_ingr_rcv_protocol_fault | r_reg_ingr_rcv_protocol_fault_force) & ~r_reg_ingr_rcv_protocol_fault_mask;
  wire [13:0] w_ingr_snd_protocol_fault_set = (r_ingr_snd_protocol_fault | r_reg_ingr_snd_protocol_fault_force) & ~r_reg_ingr_snd_protocol_fault_mask;
  wire [13:0] w_egr_rcv_protocol_fault_set = (r_egr_rcv_protocol_fault | r_reg_egr_rcv_protocol_fault_force) & ~r_reg_egr_rcv_protocol_fault_mask;
  wire [13:0] w_egr_snd_protocol_fault_set = (r_egr_snd_protocol_fault | r_reg_egr_snd_protocol_fault_force) & ~r_reg_egr_snd_protocol_fault_mask;
  wire [13:0] w_ingr_rcv_protocol_fault_clr = (w_hs && waddr == ADDR_INGR_RCV_PROTOCOL_FAULT) ? (WDATA[13:0] & wmask[13:0]) : 14'd0;
  wire [13:0] w_ingr_snd_protocol_fault_clr = (w_hs && waddr == ADDR_INGR_SND_PROTOCOL_FAULT) ? (WDATA[13:0] & wmask[13:0]) : 14'd0;
  wire [13:0] w_egr_rcv_protocol_fault_clr = (w_hs && waddr == ADDR_EGR_RCV_PROTOCOL_FAULT) ? (WDATA[13:0] & wmask[13:0]) : 14'd0;
  wire [13:0] w_egr_snd_protocol_fault_clr = (w_hs && waddr == ADDR_EGR_SND_PROTOCOL_FAULT) ? (WDATA[13:0] & wmask[13:0]) : 14'd0;

  always @(posedge ACLK) begin
    if (!ARESET_N) begin
      r_reg_ingr_rcv_protocol_fault <= 14'd0;
      r_reg_ingr_snd_protocol_fault <= 14'd0;
      r_reg_egr_rcv_protocol_fault  <= 14'd0;
      r_reg_egr_snd_protocol_fault  <= 14'd0;
    end else begin
      r_reg_ingr_rcv_protocol_fault <= (r_reg_ingr_rcv_protocol_fault & ~w_ingr_rcv_protocol_fault_clr) | w_ingr_rcv_protocol_fault_set;
      r_reg_ingr_snd_protocol_fault <= (r_reg_ingr_snd_protocol_fault & ~w_ingr_snd_protocol_fault_clr) | w_ingr_snd_protocol_fault_set;
      r_reg_egr_rcv_protocol_fault  <= (r_reg_egr_rcv_protocol_fault & ~w_egr_rcv_protocol_fault_clr) | w_egr_rcv_protocol_fault_set;
      r_reg_egr_snd_protocol_fault  <= (r_reg_egr_snd_protocol_fault & ~w_egr_snd_protocol_fault_clr) | w_egr_snd_protocol_fault_set;
    end
  end

  // read clear registers
  wire w_stat_ingr_rcv_data_rdreq;
  wire w_stat_ingr_rcv_data_rdack_valid;
  wire [63:0] w_stat_ingr_rcv_data_rdack_value;
  stat_counter_table #(
      .INDEX_WIDTH  (CHANNEL_WIDTH),
      .COUNTER_WIDTH(64),
      .ADD_WIDTH    (8)
  ) u_stat_ingr_rcv_data (
      .clk        (ACLK),                                   // input
      .rstn       (ARESET_N),                               // input
      .init_done  (  /* open */),                           // output
      .add_valid  (stat_ingr_rcv_data_ap_vld),              // input
      .add_index  (stat_ingr_rcv_data[CHANNEL_WIDTH-1:0]),  // input [INDEX_WIDTH-1:0]
      .add_value  (stat_ingr_rcv_data[23:16]),              // input [ADD_WIDTH-1:0]
      .rdreq_valid(w_stat_ingr_rcv_data_rdreq),             // input
      .rdreq_index(r_reg_stat_sel_channel),                 // input [INDEX_WIDTH-1:0]
      .rdack_valid(w_stat_ingr_rcv_data_rdack_valid),       // output
      .rdack_value(w_stat_ingr_rcv_data_rdack_value)        // output[COUNTER_WIDTH-1:0]
  );

  wire w_stat_ingr_snd_data_rdreq;
  wire w_stat_ingr_snd_data_rdack_valid;
  wire [63:0] w_stat_ingr_snd_data_rdack_value;
  stat_counter_table #(
      .INDEX_WIDTH  (CHANNEL_WIDTH),
      .COUNTER_WIDTH(64),
      .ADD_WIDTH    (8)
  ) u_stat_ingr_snd_data (
      .clk        (ACLK),                                   // input
      .rstn       (ARESET_N),                               // input
      .init_done  (  /* open */),                           // output
      .add_valid  (stat_ingr_snd_data_ap_vld),              // input
      .add_index  (stat_ingr_snd_data[CHANNEL_WIDTH-1:0]),  // input [INDEX_WIDTH-1:0]
      .add_value  (stat_ingr_snd_data[23:16]),              // input [ADD_WIDTH-1:0]
      .rdreq_valid(w_stat_ingr_snd_data_rdreq),             // input
      .rdreq_index(r_reg_stat_sel_channel),                 // input [INDEX_WIDTH-1:0]
      .rdack_valid(w_stat_ingr_snd_data_rdack_valid),       // output
      .rdack_value(w_stat_ingr_snd_data_rdack_value)        // output[COUNTER_WIDTH-1:0]
  );

  wire w_stat_egr_rcv_data_rdreq;
  wire w_stat_egr_rcv_data_rdack_valid;
  wire [63:0] w_stat_egr_rcv_data_rdack_value;
  stat_counter_table #(
      .INDEX_WIDTH  (CHANNEL_WIDTH),
      .COUNTER_WIDTH(64),
      .ADD_WIDTH    (8)
  ) u_stat_egr_rcv_data (
      .clk        (ACLK),                                  // input
      .rstn       (ARESET_N),                              // input
      .init_done  (  /* open */),                          // output
      .add_valid  (stat_egr_rcv_data_ap_vld),              // input
      .add_index  (stat_egr_rcv_data[CHANNEL_WIDTH-1:0]),  // input [INDEX_WIDTH-1:0]
      .add_value  (stat_egr_rcv_data[23:16]),              // input [ADD_WIDTH-1:0]
      .rdreq_valid(w_stat_egr_rcv_data_rdreq),             // input
      .rdreq_index(r_reg_stat_sel_channel),                // input [INDEX_WIDTH-1:0]
      .rdack_valid(w_stat_egr_rcv_data_rdack_valid),       // output
      .rdack_value(w_stat_egr_rcv_data_rdack_value)        // output[COUNTER_WIDTH-1:0]
  );

  wire w_stat_egr_snd_data_rdreq;
  wire w_stat_egr_snd_data_rdack_valid;
  wire [63:0] w_stat_egr_snd_data_rdack_value;
  stat_counter_table #(
      .INDEX_WIDTH  (CHANNEL_WIDTH),
      .COUNTER_WIDTH(64),
      .ADD_WIDTH    (8)
  ) u_stat_egr_snd_data (
      .clk        (ACLK),                                  // input
      .rstn       (ARESET_N),                              // input
      .init_done  (  /* open */),                          // output
      .add_valid  (stat_egr_snd_data_ap_vld),              // input
      .add_index  (stat_egr_snd_data[CHANNEL_WIDTH-1:0]),  // input [INDEX_WIDTH-1:0]
      .add_value  (stat_egr_snd_data[23:16]),              // input [ADD_WIDTH-1:0]
      .rdreq_valid(w_stat_egr_snd_data_rdreq),             // input
      .rdreq_index(r_reg_stat_sel_channel),                // input [INDEX_WIDTH-1:0]
      .rdack_valid(w_stat_egr_snd_data_rdack_valid),       // output
      .rdack_value(w_stat_egr_snd_data_rdack_value)        // output[COUNTER_WIDTH-1:0]
  );

  wire w_stat_ingr_rcv_frame_rdreq;
  wire w_stat_ingr_rcv_frame_rdack_valid;
  wire [31:0] w_stat_ingr_rcv_frame_rdack_value;
  stat_counter_table #(
      .INDEX_WIDTH  (CHANNEL_WIDTH),
      .COUNTER_WIDTH(32),
      .ADD_WIDTH    (1)
  ) u_stat_ingr_rcv_frame (
      .clk        (ACLK),                                   // input
      .rstn       (ARESET_N),                               // input
      .init_done  (  /* open */),                           // output
      .add_valid  (stat_ingr_rcv_frame_ap_vld),             // input
      .add_index  (stat_ingr_rcv_frame[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
      .add_value  (1'b1),                                   // input [ADD_WIDTH-1:0]
      .rdreq_valid(w_stat_ingr_rcv_frame_rdreq),            // input
      .rdreq_index(r_reg_stat_sel_channel),                 // input [INDEX_WIDTH-1:0]
      .rdack_valid(w_stat_ingr_rcv_frame_rdack_valid),      // output
      .rdack_value(w_stat_ingr_rcv_frame_rdack_value)       // output[COUNTER_WIDTH-1:0]
  );

  wire w_stat_ingr_snd_frame_rdreq;
  wire w_stat_ingr_snd_frame_rdack_valid;
  wire [31:0] w_stat_ingr_snd_frame_rdack_value;
  stat_counter_table #(
      .INDEX_WIDTH  (CHANNEL_WIDTH),
      .COUNTER_WIDTH(32),
      .ADD_WIDTH    (1)
  ) u_stat_ingr_snd_frame (
      .clk        (ACLK),                                   // input
      .rstn       (ARESET_N),                               // input
      .init_done  (  /* open */),                           // output
      .add_valid  (stat_ingr_snd_frame_ap_vld),             // input
      .add_index  (stat_ingr_snd_frame[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
      .add_value  (1'b1),                                   // input [ADD_WIDTH-1:0]
      .rdreq_valid(w_stat_ingr_snd_frame_rdreq),            // input
      .rdreq_index(r_reg_stat_sel_channel),                 // input [INDEX_WIDTH-1:0]
      .rdack_valid(w_stat_ingr_snd_frame_rdack_valid),      // output
      .rdack_value(w_stat_ingr_snd_frame_rdack_value)       // output[COUNTER_WIDTH-1:0]
  );

  wire w_stat_egr_rcv_frame_rdreq;
  wire w_stat_egr_rcv_frame_rdack_valid;
  wire [31:0] w_stat_egr_rcv_frame_rdack_value;
  stat_counter_table #(
      .INDEX_WIDTH  (CHANNEL_WIDTH),
      .COUNTER_WIDTH(32),
      .ADD_WIDTH    (1)
  ) u_stat_egr_rcv_frame (
      .clk        (ACLK),                                  // input
      .rstn       (ARESET_N),                              // input
      .init_done  (  /* open */),                          // output
      .add_valid  (stat_egr_rcv_frame_ap_vld),             // input
      .add_index  (stat_egr_rcv_frame[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
      .add_value  (1'b1),                                  // input [ADD_WIDTH-1:0]
      .rdreq_valid(w_stat_egr_rcv_frame_rdreq),            // input
      .rdreq_index(r_reg_stat_sel_channel),                // input [INDEX_WIDTH-1:0]
      .rdack_valid(w_stat_egr_rcv_frame_rdack_valid),      // output
      .rdack_value(w_stat_egr_rcv_frame_rdack_value)       // output[COUNTER_WIDTH-1:0]
  );

  wire w_stat_egr_snd_frame_rdreq;
  wire w_stat_egr_snd_frame_rdack_valid;
  wire [31:0] w_stat_egr_snd_frame_rdack_value;
  stat_counter_table #(
      .INDEX_WIDTH  (CHANNEL_WIDTH),
      .COUNTER_WIDTH(32),
      .ADD_WIDTH    (1)
  ) u_stat_egr_snd_frame (
      .clk        (ACLK),                                  // input
      .rstn       (ARESET_N),                              // input
      .init_done  (  /* open */),                          // output
      .add_valid  (stat_egr_snd_frame_ap_vld),             // input
      .add_index  (stat_egr_snd_frame[CHANNEL_WIDTH-1:0]), // input [INDEX_WIDTH-1:0]
      .add_value  (1'b1),                                  // input [ADD_WIDTH-1:0]
      .rdreq_valid(w_stat_egr_snd_frame_rdreq),            // input
      .rdreq_index(r_reg_stat_sel_channel),                // input [INDEX_WIDTH-1:0]
      .rdack_valid(w_stat_egr_snd_frame_rdack_valid),      // output
      .rdack_value(w_stat_egr_snd_frame_rdack_value)       // output[COUNTER_WIDTH-1:0]
  );

  assign w_stat_ingr_rcv_data_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_RCV_DATA_VALUE_L);
  assign w_stat_ingr_snd_data_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_SND_DATA_VALUE_L);
  assign w_stat_egr_rcv_data_rdreq = ar_hs && (raddr == ADDR_STAT_EGR_RCV_DATA_VALUE_L);
  assign w_stat_egr_snd_data_rdreq = ar_hs && (raddr == ADDR_STAT_EGR_SND_DATA_VALUE_L);
  assign w_stat_ingr_rcv_frame_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_RCV_FRAME_VALUE);
  assign w_stat_ingr_snd_frame_rdreq = ar_hs && (raddr == ADDR_STAT_INGR_SND_FRAME_VALUE);
  assign w_stat_egr_rcv_frame_rdreq = ar_hs && (raddr == ADDR_STAT_EGR_RCV_FRAME_VALUE);
  assign w_stat_egr_snd_frame_rdreq = ar_hs && (raddr == ADDR_STAT_EGR_SND_FRAME_VALUE);

  assign w_stat_rdreq = | {
    w_stat_ingr_rcv_data_rdreq,
    w_stat_ingr_snd_data_rdreq,
    w_stat_egr_rcv_data_rdreq,
    w_stat_egr_snd_data_rdreq,
    w_stat_ingr_rcv_frame_rdreq,
    w_stat_ingr_snd_frame_rdreq,
    w_stat_egr_rcv_frame_rdreq,
    w_stat_egr_snd_frame_rdreq
  };

  assign w_stat_rdack_valid = | {
    w_stat_ingr_rcv_data_rdack_valid,
    w_stat_ingr_snd_data_rdack_valid,
    w_stat_egr_rcv_data_rdack_valid,
    w_stat_egr_snd_data_rdack_valid,
    w_stat_ingr_rcv_frame_rdack_valid,
    w_stat_ingr_snd_frame_rdack_valid,
    w_stat_egr_rcv_frame_rdack_valid,
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
        ({64{w_stat_ingr_rcv_data_rdack_valid }} & w_stat_ingr_rcv_data_rdack_value          ) |
        ({64{w_stat_ingr_snd_data_rdack_valid }} & w_stat_ingr_snd_data_rdack_value          ) |
        ({64{w_stat_egr_rcv_data_rdack_valid  }} & w_stat_egr_rcv_data_rdack_value           ) |
        ({64{w_stat_egr_snd_data_rdack_valid  }} & w_stat_egr_snd_data_rdack_value           ) |
        ({64{w_stat_ingr_rcv_frame_rdack_valid}} & {32'd0, w_stat_ingr_rcv_frame_rdack_value}) |
        ({64{w_stat_ingr_snd_frame_rdack_valid}} & {32'd0, w_stat_ingr_snd_frame_rdack_value}) |
        ({64{w_stat_egr_rcv_frame_rdack_valid }} & {32'd0, w_stat_egr_rcv_frame_rdack_value }) |
        ({64{w_stat_egr_snd_frame_rdack_valid }} & {32'd0, w_stat_egr_snd_frame_rdack_value });
    end
  end

  reg r_fault_or;
  always @(posedge ACLK) begin
    if (!ARESET_N) begin
      r_fault_or <= 1'b0;
      r_reg_detect_fault <= 1'b0;
    end else begin
      r_fault_or <= |{r_reg_ingr_rcv_protocol_fault, r_reg_ingr_snd_protocol_fault, r_reg_egr_rcv_protocol_fault, r_reg_egr_snd_protocol_fault};
      r_reg_detect_fault <= r_fault_or;
    end
  end

  assign detect_fault = r_reg_detect_fault;
  assign ingr_rcv_insert_protocol_fault = {2'd0,r_reg_ingr_rcv_insert_protocol_fault};
  assign ingr_snd_insert_protocol_fault = {2'd0,r_reg_ingr_snd_insert_protocol_fault};
  assign egr_rcv_insert_protocol_fault = {2'd0,r_reg_egr_rcv_insert_protocol_fault};
  assign egr_snd_insert_protocol_fault = {2'd0,r_reg_egr_snd_insert_protocol_fault};

endmodule

`default_nettype wire
