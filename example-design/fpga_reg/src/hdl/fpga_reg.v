/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`default_nettype none

`timescale 1ns/1ps
module fpga_reg #(
  parameter integer C_S_AXI_ADDR_WIDTH  = 12,
  parameter integer C_S_AXI_DATA_WIDTH  = 32,
  parameter[31:0]   MAJOR_VERSION       = 32'h00011914,
  parameter[31:0]   MINOR_VERSION       = 32'h24031801
) (
  input  wire                             ACLK                  ,
  input  wire                             ARESET_N              ,
  input  wire [C_S_AXI_ADDR_WIDTH-1:0]    AWADDR                ,
  input  wire                             AWVALID               ,
  output wire                             AWREADY               ,
  input  wire [C_S_AXI_DATA_WIDTH-1:0]    WDATA                 ,
  input  wire [C_S_AXI_DATA_WIDTH/8-1:0]  WSTRB                 ,
  input  wire                             WVALID                ,
  output wire                             WREADY                ,
  output wire [1:0]                       BRESP                 ,
  output wire                             BVALID                ,
  input  wire                             BREADY                ,
  input  wire [C_S_AXI_ADDR_WIDTH-1:0]    ARADDR                ,
  input  wire                             ARVALID               ,
  output wire                             ARREADY               ,
  output wire [C_S_AXI_DATA_WIDTH-1:0]    RDATA                 ,
  output wire [1:0]                       RRESP                 ,
  output wire                             RVALID                ,
  input  wire                             RREADY                ,
  output wire                             soft_reset_n          ,
  input  wire                             detect_fault          ,
  input  wire                             locked_user_clk       ,
  input  wire                             locked_ddr4_clk0      ,
  input  wire                             locked_ddr4_clk1      ,
  input  wire                             locked_ddr4_clk2      ,
  input  wire                             locked_ddr4_clk3      ,
  input  wire                             locked_qsfp_clk0      ,
  input  wire                             locked_qsfp_clk1      ,
  input  wire [7:0]                       ddr4_ecc_single_0     ,
  input  wire [7:0]                       ddr4_ecc_multiple_0   ,
  input  wire [7:0]                       ddr4_ecc_single_1     ,
  input  wire [7:0]                       ddr4_ecc_multiple_1   ,
  input  wire [7:0]                       ddr4_ecc_single_2     ,
  input  wire [7:0]                       ddr4_ecc_multiple_2   ,
  input  wire [7:0]                       ddr4_ecc_single_3     ,
  input  wire [7:0]                       ddr4_ecc_multiple_3   ,
  output wire                             dfx_filter_0_soft_reset_n   ,
  output wire                             dfx_filter_1_soft_reset_n   ,
  output wire                             dfx_conv_0_soft_reset_n   ,
  output wire                             dfx_conv_1_soft_reset_n   ,
  output wire                             filter_0_decouple_enable,
  output wire                             conv_0_decouple_enable,
  output wire                             filter_1_decouple_enable,
  output wire                             conv_1_decouple_enable,
  input  wire [17:0]                      decouple_status
);

//------------------------Parameter----------------------

localparam integer WRIDLE   = 2'd0;
localparam integer WRDATA   = 2'd1;
localparam integer WRRESP   = 2'd2;
localparam integer WRRESET  = 2'd3;
localparam integer RDIDLE   = 2'd0;
localparam integer RDDATA   = 2'd1;
localparam integer RDRESET  = 2'd2;

localparam integer ADDR_BITS = C_S_AXI_ADDR_WIDTH;

localparam[ADDR_BITS-1:0] ADDR_FPGA_MAJOR_VERSION       = 12'h000; // R
localparam[ADDR_BITS-1:0] ADDR_FPGA_MINOR_VERSION       = 12'h004; // R
localparam[ADDR_BITS-1:0] ADDR_SCRATCHPAD               = 12'h008; // R/W
localparam[ADDR_BITS-1:0] ADDR_SOFT_RESET               = 12'h00C; // R/W
localparam[ADDR_BITS-1:0] ADDR_DETECT_FAULT             = 12'h100; // R
localparam[ADDR_BITS-1:0] ADDR_CLOCK_DOWN               = 12'h110; // R/WC
localparam[ADDR_BITS-1:0] ADDR_CLOCK_DOWN_RAW           = 12'h114; // R
localparam[ADDR_BITS-1:0] ADDR_CLOCK_DOWN_MASK          = 12'h118; // R/W
localparam[ADDR_BITS-1:0] ADDR_CLOCK_DOWN_FORCE         = 12'h11C; // R/W
localparam[ADDR_BITS-1:0] ADDR_DDR4_ECC_SINGLE          = 12'h120; // R/WC
localparam[ADDR_BITS-1:0] ADDR_DDR4_ECC_MULTIPLE        = 12'h124; // R/WC
localparam[ADDR_BITS-1:0] ADDR_DDR4_ECC_SINGLE_RAW      = 12'h128; // R
localparam[ADDR_BITS-1:0] ADDR_DDR4_ECC_MULTIPLE_RAW    = 12'h12C; // R
localparam[ADDR_BITS-1:0] ADDR_DDR4_ECC_SINGLE_MASK     = 12'h130; // R/W
localparam[ADDR_BITS-1:0] ADDR_DDR4_ECC_MULTIPLE_MASK   = 12'h134; // R/W
localparam[ADDR_BITS-1:0] ADDR_DDR4_ECC_SINGLE_FORCE    = 12'h138; // R/W
localparam[ADDR_BITS-1:0] ADDR_DDR4_ECC_MULTIPLE_FORCE  = 12'h13C; // R/W

localparam[ADDR_BITS-1:0] ADDR_DFX_RESET                = 12'h020; //   W
localparam[ADDR_BITS-1:0] ADDR_DECOUPLE_ENABLE          = 12'h024; // R/W
localparam[ADDR_BITS-1:0] ADDR_DECOUPLE_STATUS          = 12'h028; // R

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

reg[31:0] r_reg_scratchpad;
reg[0:0]  r_reg_soft_reset;
reg       r_reg_detect_fault;
reg[6:0]  r_reg_clock_down;
reg[6:0]  r_reg_clock_down_raw;
reg[6:0]  r_reg_clock_down_mask;
reg[6:0]  r_reg_clock_down_force;
reg[31:0] r_reg_ddr4_ecc_single;
reg[31:0] r_reg_ddr4_ecc_multiple;
reg[31:0] r_reg_ddr4_ecc_single_raw;
reg[31:0] r_reg_ddr4_ecc_multiple_raw;
reg[31:0] r_reg_ddr4_ecc_single_mask;
reg[31:0] r_reg_ddr4_ecc_multiple_mask;
reg[31:0] r_reg_ddr4_ecc_single_force;
reg[31:0] r_reg_ddr4_ecc_multiple_force;

reg[0:0]  r_reg_soft_reset_d[0:31];
reg[0:0]  r_reg_soft_reset_ext;


reg[31:0]  r_reg_dfx_soft_reset_d[3:0];
reg[31:0]  r_reg_dfx_soft_reset_ext;

reg[31:0]  r_reg_decouple_enable;
reg[31:0]  r_reg_decouple_status;

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
      if (ARVALID)
        rnext = RDDATA;
      else
        rnext = RDIDLE;
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
    rdata <= 32'd0;
    case (raddr)
      ADDR_FPGA_MAJOR_VERSION     : rdata      <= MAJOR_VERSION                ; // R    [31:0]
      ADDR_FPGA_MINOR_VERSION     : rdata      <= MINOR_VERSION                ; // R    [31:0]
      ADDR_SCRATCHPAD             : rdata      <= r_reg_scratchpad             ; // R/W  [31:0]
      ADDR_SOFT_RESET             : rdata[0]   <= r_reg_soft_reset             ; // R/W  [0]
      ADDR_DETECT_FAULT           : rdata[0]   <= r_reg_detect_fault           ; // R    [0]
      ADDR_CLOCK_DOWN             : rdata[6:0] <= r_reg_clock_down             ; // R/WC [6:0]
      ADDR_CLOCK_DOWN_RAW         : rdata[6:0] <= r_reg_clock_down_raw         ; // R    [6:0]
      ADDR_CLOCK_DOWN_MASK        : rdata[6:0] <= r_reg_clock_down_mask        ; // R/W  [6:0]
      ADDR_CLOCK_DOWN_FORCE       : rdata[6:0] <= r_reg_clock_down_force       ; // R/W  [6:0]
      ADDR_DDR4_ECC_SINGLE        : rdata      <= r_reg_ddr4_ecc_single        ; // R/WC [31:0]
      ADDR_DDR4_ECC_MULTIPLE      : rdata      <= r_reg_ddr4_ecc_multiple      ; // R/WC [31:0]
      ADDR_DDR4_ECC_SINGLE_RAW    : rdata      <= r_reg_ddr4_ecc_single_raw    ; // R    [31:0]
      ADDR_DDR4_ECC_MULTIPLE_RAW  : rdata      <= r_reg_ddr4_ecc_multiple_raw  ; // R    [31:0]
      ADDR_DDR4_ECC_SINGLE_MASK   : rdata      <= r_reg_ddr4_ecc_single_mask   ; // R/W  [31:0]
      ADDR_DDR4_ECC_MULTIPLE_MASK : rdata      <= r_reg_ddr4_ecc_multiple_mask ; // R/W  [31:0]
      ADDR_DDR4_ECC_SINGLE_FORCE  : rdata      <= r_reg_ddr4_ecc_single_force  ; // R/W  [31:0]
      ADDR_DDR4_ECC_MULTIPLE_FORCE: rdata      <= r_reg_ddr4_ecc_multiple_force; // R/W  [31:0]
      ADDR_DECOUPLE_ENABLE        : rdata      <= r_reg_decouple_enable        ; // R/W  [31:0]
      ADDR_DECOUPLE_STATUS        : rdata      <= r_reg_decouple_status        ; // R    [31:0]
    endcase
  end
end

// read/write registers
always @(posedge ACLK) begin
  if (!ARESET_N) begin
      r_reg_scratchpad              <= 32'd0; // [31:0]
      r_reg_soft_reset              <= 1'b0;  // [0]
      r_reg_clock_down_mask         <= 7'd0;  // [6:0]
      r_reg_clock_down_force        <= 7'd0;  // [6:0]
      r_reg_ddr4_ecc_single_mask    <= 32'd0; // [31:0]
      r_reg_ddr4_ecc_multiple_mask  <= 32'd0; // [31:0]
      r_reg_ddr4_ecc_single_force   <= 32'd0; // [31:0]
      r_reg_ddr4_ecc_multiple_force <= 32'd0; // [31:0]
      r_reg_decouple_enable         <= 32'd0; // [31:0]
  end else if (w_hs) begin
    case (waddr)
      ADDR_SCRATCHPAD             : r_reg_scratchpad              <= (WDATA[31:0] & wmask     ) | (r_reg_scratchpad               & ~wmask      ); // [31:0]
      ADDR_SOFT_RESET             : r_reg_soft_reset              <= (WDATA[0]    & wmask[0]  ) | (r_reg_soft_reset               & ~wmask[0]   ); // [0]
      ADDR_CLOCK_DOWN_MASK        : r_reg_clock_down_mask         <= (WDATA[6:0]  & wmask[6:0]) | (r_reg_clock_down_mask          & ~wmask[6:0] ); // [6:0]
      ADDR_CLOCK_DOWN_FORCE       : r_reg_clock_down_force        <= (WDATA[6:0]  & wmask[6:0]) | (r_reg_clock_down_force         & ~wmask[6:0] ); // [6:0]
      ADDR_DDR4_ECC_SINGLE_MASK   : r_reg_ddr4_ecc_single_mask    <= (WDATA[31:0] & wmask     ) | (r_reg_ddr4_ecc_single_mask     & ~wmask      ); // [31:0]
      ADDR_DDR4_ECC_MULTIPLE_MASK : r_reg_ddr4_ecc_multiple_mask  <= (WDATA[31:0] & wmask     ) | (r_reg_ddr4_ecc_multiple_mask   & ~wmask      ); // [31:0]
      ADDR_DDR4_ECC_SINGLE_FORCE  : r_reg_ddr4_ecc_single_force   <= (WDATA[31:0] & wmask     ) | (r_reg_ddr4_ecc_single_force    & ~wmask      ); // [31:0]
      ADDR_DDR4_ECC_MULTIPLE_FORCE: r_reg_ddr4_ecc_multiple_force <= (WDATA[31:0] & wmask     ) | (r_reg_ddr4_ecc_multiple_force  & ~wmask      ); // [31:0]
      ADDR_DECOUPLE_ENABLE        : r_reg_decouple_enable         <= (WDATA[31:0] & wmask     ) | (r_reg_decouple_enable          & ~wmask      ); // [31:0]
    endcase
  end
end

// write oneshot registers
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_reg_soft_reset_d[0] <= 1'b0;  // [0:0]
  end else begin
    r_reg_soft_reset_d[0] <= (w_hs == 1) && (waddr == ADDR_SOFT_RESET) && (WDATA[0:0] & wmask[0:0]); // [0:0]
  end
end

genvar i;
generate
  for (i = 0; i < 31; i = i + 1) begin
    always @(posedge ACLK) begin
      if (!ARESET_N) begin
        r_reg_soft_reset_d[i + 1] <= 1'b0; // [0:0]
      end else begin
        r_reg_soft_reset_d[i + 1] <= r_reg_soft_reset_d[i]; // [0:0]
      end
    end
  end
endgenerate

always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_reg_soft_reset_ext <= 1'b0; // [0:0]
  end else begin
    r_reg_soft_reset_ext <= r_reg_soft_reset_d[0] |
                            r_reg_soft_reset_d[1] |
                            r_reg_soft_reset_d[2] |
                            r_reg_soft_reset_d[3] |
                            r_reg_soft_reset_d[4] |
                            r_reg_soft_reset_d[5] |
                            r_reg_soft_reset_d[6] |
                            r_reg_soft_reset_d[7] |
                            r_reg_soft_reset_d[8] |
                            r_reg_soft_reset_d[9] |
                            r_reg_soft_reset_d[10] |
                            r_reg_soft_reset_d[11] |
                            r_reg_soft_reset_d[12] |
                            r_reg_soft_reset_d[13] |
                            r_reg_soft_reset_d[14] |
                            r_reg_soft_reset_d[15] |
                            r_reg_soft_reset_d[16] |
                            r_reg_soft_reset_d[17] |
                            r_reg_soft_reset_d[18] |
                            r_reg_soft_reset_d[19] |
                            r_reg_soft_reset_d[20] |
                            r_reg_soft_reset_d[21] |
                            r_reg_soft_reset_d[22] |
                            r_reg_soft_reset_d[23] |
                            r_reg_soft_reset_d[24] |
                            r_reg_soft_reset_d[25] |
                            r_reg_soft_reset_d[26] |
                            r_reg_soft_reset_d[27] |
                            r_reg_soft_reset_d[28] |
                            r_reg_soft_reset_d[29] |
                            r_reg_soft_reset_d[30] |
                            r_reg_soft_reset_d[31]; // [0:0]
  end
end

assign soft_reset_n = ~r_reg_soft_reset_ext[0];

// read only registers
wire w_detect_fault = |{
    detect_fault,
    r_reg_clock_down,
    r_reg_ddr4_ecc_single,
    r_reg_ddr4_ecc_multiple};

wire[6:0] w_clock_down_raw = ~{
    locked_qsfp_clk1,
    locked_qsfp_clk0,
    locked_ddr4_clk3,
    locked_ddr4_clk2,
    locked_ddr4_clk1,
    locked_ddr4_clk0,
    locked_user_clk };

wire[31:0] w_ddr4_ecc_single_raw = {
    ddr4_ecc_single_3,
    ddr4_ecc_single_2,
    ddr4_ecc_single_1,
    ddr4_ecc_single_0 };

wire[31:0] w_ddr4_ecc_multiple_raw = {
    ddr4_ecc_multiple_3,
    ddr4_ecc_multiple_2,
    ddr4_ecc_multiple_1,
    ddr4_ecc_multiple_0 };

always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_reg_detect_fault          <= 1'b0 ; // [0]
    r_reg_clock_down_raw        <= 7'd0 ; // [6:0]
    r_reg_ddr4_ecc_single_raw   <= 32'd0; // [31:0]
    r_reg_ddr4_ecc_multiple_raw <= 32'd0; // [31:0]
  end else begin
    r_reg_detect_fault          <= w_detect_fault         ; // [0]
    r_reg_clock_down_raw        <= w_clock_down_raw       ; // [6:0]
    r_reg_ddr4_ecc_single_raw   <= w_ddr4_ecc_single_raw  ; // [31:0]
    r_reg_ddr4_ecc_multiple_raw <= w_ddr4_ecc_multiple_raw; // [31:0]
  end
end

// read/write-clear registers
always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_reg_clock_down <= 7'd0;
  end else begin : blk_clock_down
    reg[6:0] tmp;
    tmp = r_reg_clock_down;
    if (w_hs && waddr == ADDR_CLOCK_DOWN) begin
      tmp = tmp & ~(WDATA[6:0] & wmask[6:0]);
    end
    tmp = tmp | (r_reg_clock_down_raw | r_reg_clock_down_force) & ~r_reg_clock_down_mask;
    r_reg_clock_down <= tmp;
  end
end

always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_reg_ddr4_ecc_single <= 32'h0 ;
  end else begin : blk_ddr4_ecc_single
    reg[31:0] tmp;
    tmp = r_reg_ddr4_ecc_single;
    if (w_hs && waddr == ADDR_DDR4_ECC_SINGLE) begin
      tmp = tmp & ~(WDATA & wmask);
    end
    tmp = tmp | (r_reg_ddr4_ecc_single_raw | r_reg_ddr4_ecc_single_force) & ~r_reg_ddr4_ecc_single_mask;
    r_reg_ddr4_ecc_single <= tmp;
  end
end

always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_reg_ddr4_ecc_multiple <= 32'h0 ;
  end else begin : blk_ddr4_ecc_multiple
    reg[31:0] tmp;
    tmp = r_reg_ddr4_ecc_multiple;
    if (w_hs && waddr == ADDR_DDR4_ECC_MULTIPLE) begin
      tmp = tmp & ~(WDATA & wmask);
    end
    tmp = tmp | (r_reg_ddr4_ecc_multiple_raw | r_reg_ddr4_ecc_multiple_force) & ~r_reg_ddr4_ecc_multiple_mask;
    r_reg_ddr4_ecc_multiple <= tmp;
  end
end

// write oneshot registers
generate
  for (i = 0; i < 4; i = i + 1) begin
    always @(posedge ACLK) begin
      if (!ARESET_N) begin
        r_reg_dfx_soft_reset_d[i][0] <= 1'b0;
      end else begin
        r_reg_dfx_soft_reset_d[i][0] <= (w_hs == 1) && (waddr == ADDR_DFX_RESET) && (WDATA[i] & wmask[i]);
      end
    end
  end
endgenerate

generate
  for (i = 0; i < 31; i = i + 1) begin
    always @(posedge ACLK) begin
      if (!ARESET_N) begin
        r_reg_dfx_soft_reset_d[i][31:1] <= {31{1'b0}};
      end else begin
        r_reg_dfx_soft_reset_d[i][31:1] <= r_reg_dfx_soft_reset_d[i][30:0];
      end
    end
  end
endgenerate

generate
  for (i = 0; i < 3; i = i + 1) begin
    always @(posedge ACLK) begin
      if (!ARESET_N) begin
        r_reg_dfx_soft_reset_ext[i] <= 1'b0;
      end else begin
        r_reg_dfx_soft_reset_ext[i] <= |r_reg_dfx_soft_reset_d[i];
      end
    end
  end
endgenerate

assign dfx_filter_0_soft_reset_n = ~r_reg_dfx_soft_reset_ext[0];
assign dfx_conv_0_soft_reset_n   = ~r_reg_dfx_soft_reset_ext[1];
assign dfx_filter_1_soft_reset_n = ~r_reg_dfx_soft_reset_ext[2];
assign dfx_conv_1_soft_reset_n   = ~r_reg_dfx_soft_reset_ext[3];


assign filter_0_decouple_enable  = r_reg_decouple_enable[0];
assign conv_0_decouple_enable    = r_reg_decouple_enable[1];
assign filter_1_decouple_enable  = r_reg_decouple_enable[2];
assign conv_1_decouple_enable    = r_reg_decouple_enable[3];

always @(posedge ACLK) begin
  if (!ARESET_N) begin
    r_reg_decouple_status <= 32'h0 ;
  end else begin
    r_reg_decouple_status <= {14'h000000,decouple_status};
  end
end

endmodule

`default_nettype wire
