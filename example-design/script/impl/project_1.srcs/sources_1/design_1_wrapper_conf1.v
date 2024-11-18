/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1 ps / 1 ps

module design_1_wrapper
   (DDR4_RESET_GATE,
    ddr4_sdram_c0_act_n,
    ddr4_sdram_c0_adr,
    ddr4_sdram_c0_ba,
    ddr4_sdram_c0_bg,
    ddr4_sdram_c0_ck_c,
    ddr4_sdram_c0_ck_t,
    ddr4_sdram_c0_cke,
    ddr4_sdram_c0_cs_n,
    ddr4_sdram_c0_dq,
    ddr4_sdram_c0_dqs_c,
    ddr4_sdram_c0_dqs_t,
    ddr4_sdram_c0_odt,
    ddr4_sdram_c0_par,
    ddr4_sdram_c0_reset_n,
    ddr4_sdram_c1_act_n,
    ddr4_sdram_c1_adr,
    ddr4_sdram_c1_ba,
    ddr4_sdram_c1_bg,
    ddr4_sdram_c1_ck_c,
    ddr4_sdram_c1_ck_t,
    ddr4_sdram_c1_cke,
    ddr4_sdram_c1_cs_n,
    ddr4_sdram_c1_dq,
    ddr4_sdram_c1_dqs_c,
    ddr4_sdram_c1_dqs_t,
    ddr4_sdram_c1_odt,
    ddr4_sdram_c1_par,
    ddr4_sdram_c1_reset_n,
    ddr4_sdram_c2_act_n,
    ddr4_sdram_c2_adr,
    ddr4_sdram_c2_ba,
    ddr4_sdram_c2_bg,
    ddr4_sdram_c2_ck_c,
    ddr4_sdram_c2_ck_t,
    ddr4_sdram_c2_cke,
    ddr4_sdram_c2_cs_n,
    ddr4_sdram_c2_dq,
    ddr4_sdram_c2_dqs_c,
    ddr4_sdram_c2_dqs_t,
    ddr4_sdram_c2_odt,
    ddr4_sdram_c2_par,
    ddr4_sdram_c2_reset_n,
    ddr4_sdram_c3_act_n,
    ddr4_sdram_c3_adr,
    ddr4_sdram_c3_ba,
    ddr4_sdram_c3_bg,
    ddr4_sdram_c3_ck_c,
    ddr4_sdram_c3_ck_t,
    ddr4_sdram_c3_cke,
    ddr4_sdram_c3_cs_n,
    ddr4_sdram_c3_dq,
    ddr4_sdram_c3_dqs_c,
    ddr4_sdram_c3_dqs_t,
    ddr4_sdram_c3_odt,
    ddr4_sdram_c3_par,
    ddr4_sdram_c3_reset_n,
    default_300mhz_clk0_clk_n,
    default_300mhz_clk0_clk_p,
    default_300mhz_clk1_clk_n,
    default_300mhz_clk1_clk_p,
    default_300mhz_clk2_clk_n,
    default_300mhz_clk2_clk_p,
    default_300mhz_clk3_clk_n,
    default_300mhz_clk3_clk_p,
    pcie4_mgt_rxn,
    pcie4_mgt_rxp,
    pcie4_mgt_txn,
    pcie4_mgt_txp,
    pcie_perstn,
    QSFP0_RESETL,
    QSFP0_MODPRSL,
    QSFP0_INTL,
    QSFP0_LPMODE,
    QSFP0_MODSELL,
    satellite_gpio,
    satellite_uart_rxd,
    satellite_uart_txd,
    sys_clk_clk_n,
    sys_clk_clk_p);
  output DDR4_RESET_GATE;
  output ddr4_sdram_c0_act_n;
  output [16:0]ddr4_sdram_c0_adr;
  output [1:0]ddr4_sdram_c0_ba;
  output [1:0]ddr4_sdram_c0_bg;
  output ddr4_sdram_c0_ck_c;
  output ddr4_sdram_c0_ck_t;
  output ddr4_sdram_c0_cke;
  output ddr4_sdram_c0_cs_n;
  inout [71:0]ddr4_sdram_c0_dq;
  inout [17:0]ddr4_sdram_c0_dqs_c;
  inout [17:0]ddr4_sdram_c0_dqs_t;
  output ddr4_sdram_c0_odt;
  output ddr4_sdram_c0_par;
  output ddr4_sdram_c0_reset_n;
  output ddr4_sdram_c1_act_n;
  output [16:0]ddr4_sdram_c1_adr;
  output [1:0]ddr4_sdram_c1_ba;
  output [1:0]ddr4_sdram_c1_bg;
  output ddr4_sdram_c1_ck_c;
  output ddr4_sdram_c1_ck_t;
  output ddr4_sdram_c1_cke;
  output ddr4_sdram_c1_cs_n;
  inout [71:0]ddr4_sdram_c1_dq;
  inout [17:0]ddr4_sdram_c1_dqs_c;
  inout [17:0]ddr4_sdram_c1_dqs_t;
  output ddr4_sdram_c1_odt;
  output ddr4_sdram_c1_par;
  output ddr4_sdram_c1_reset_n;
  output ddr4_sdram_c2_act_n;
  output [16:0]ddr4_sdram_c2_adr;
  output [1:0]ddr4_sdram_c2_ba;
  output [1:0]ddr4_sdram_c2_bg;
  output ddr4_sdram_c2_ck_c;
  output ddr4_sdram_c2_ck_t;
  output ddr4_sdram_c2_cke;
  output ddr4_sdram_c2_cs_n;
  inout [71:0]ddr4_sdram_c2_dq;
  inout [17:0]ddr4_sdram_c2_dqs_c;
  inout [17:0]ddr4_sdram_c2_dqs_t;
  output ddr4_sdram_c2_odt;
  output ddr4_sdram_c2_par;
  output ddr4_sdram_c2_reset_n;
  output ddr4_sdram_c3_act_n;
  output [16:0]ddr4_sdram_c3_adr;
  output [1:0]ddr4_sdram_c3_ba;
  output [1:0]ddr4_sdram_c3_bg;
  output ddr4_sdram_c3_ck_c;
  output ddr4_sdram_c3_ck_t;
  output ddr4_sdram_c3_cke;
  output ddr4_sdram_c3_cs_n;
  inout [71:0]ddr4_sdram_c3_dq;
  inout [17:0]ddr4_sdram_c3_dqs_c;
  inout [17:0]ddr4_sdram_c3_dqs_t;
  output ddr4_sdram_c3_odt;
  output ddr4_sdram_c3_par;
  output ddr4_sdram_c3_reset_n;
  input default_300mhz_clk0_clk_n;
  input default_300mhz_clk0_clk_p;
  input default_300mhz_clk1_clk_n;
  input default_300mhz_clk1_clk_p;
  input default_300mhz_clk2_clk_n;
  input default_300mhz_clk2_clk_p;
  input default_300mhz_clk3_clk_n;
  input default_300mhz_clk3_clk_p;
  input [15:0]pcie4_mgt_rxn;
  input [15:0]pcie4_mgt_rxp;
  output [15:0]pcie4_mgt_txn;
  output [15:0]pcie4_mgt_txp;
  input pcie_perstn;
  output QSFP0_RESETL;
  input QSFP0_MODPRSL;
  input QSFP0_INTL;
  output QSFP0_LPMODE;
  output QSFP0_MODSELL;
  input [3:0]satellite_gpio;
  input satellite_uart_rxd;
  output satellite_uart_txd;
  input [0:0]sys_clk_clk_n;
  input [0:0]sys_clk_clk_p;

  wire ddr4_sdram_c0_act_n;
  wire [16:0]ddr4_sdram_c0_adr;
  wire [1:0]ddr4_sdram_c0_ba;
  wire [1:0]ddr4_sdram_c0_bg;
  wire ddr4_sdram_c0_ck_c;
  wire ddr4_sdram_c0_ck_t;
  wire ddr4_sdram_c0_cke;
  wire ddr4_sdram_c0_cs_n;
  wire [71:0]ddr4_sdram_c0_dq;
  wire [17:0]ddr4_sdram_c0_dqs_c;
  wire [17:0]ddr4_sdram_c0_dqs_t;
  wire ddr4_sdram_c0_odt;
  wire ddr4_sdram_c0_par;
  wire ddr4_sdram_c0_reset_n;
  wire ddr4_sdram_c1_act_n;
  wire [16:0]ddr4_sdram_c1_adr;
  wire [1:0]ddr4_sdram_c1_ba;
  wire [1:0]ddr4_sdram_c1_bg;
  wire ddr4_sdram_c1_ck_c;
  wire ddr4_sdram_c1_ck_t;
  wire ddr4_sdram_c1_cke;
  wire ddr4_sdram_c1_cs_n;
  wire [71:0]ddr4_sdram_c1_dq;
  wire [17:0]ddr4_sdram_c1_dqs_c;
  wire [17:0]ddr4_sdram_c1_dqs_t;
  wire ddr4_sdram_c1_odt;
  wire ddr4_sdram_c1_par;
  wire ddr4_sdram_c1_reset_n;
  wire ddr4_sdram_c2_act_n;
  wire [16:0]ddr4_sdram_c2_adr;
  wire [1:0]ddr4_sdram_c2_ba;
  wire [1:0]ddr4_sdram_c2_bg;
  wire ddr4_sdram_c2_ck_c;
  wire ddr4_sdram_c2_ck_t;
  wire ddr4_sdram_c2_cke;
  wire ddr4_sdram_c2_cs_n;
  wire [71:0]ddr4_sdram_c2_dq;
  wire [17:0]ddr4_sdram_c2_dqs_c;
  wire [17:0]ddr4_sdram_c2_dqs_t;
  wire ddr4_sdram_c2_odt;
  wire ddr4_sdram_c2_par;
  wire ddr4_sdram_c2_reset_n;
  wire ddr4_sdram_c3_act_n;
  wire [16:0]ddr4_sdram_c3_adr;
  wire [1:0]ddr4_sdram_c3_ba;
  wire [1:0]ddr4_sdram_c3_bg;
  wire ddr4_sdram_c3_ck_c;
  wire ddr4_sdram_c3_ck_t;
  wire ddr4_sdram_c3_cke;
  wire ddr4_sdram_c3_cs_n;
  wire [71:0]ddr4_sdram_c3_dq;
  wire [17:0]ddr4_sdram_c3_dqs_c;
  wire [17:0]ddr4_sdram_c3_dqs_t;
  wire ddr4_sdram_c3_odt;
  wire ddr4_sdram_c3_par;
  wire ddr4_sdram_c3_reset_n;
  wire default_300mhz_clk0_clk_n;
  wire default_300mhz_clk0_clk_p;
  wire default_300mhz_clk1_clk_n;
  wire default_300mhz_clk1_clk_p;
  wire default_300mhz_clk2_clk_n;
  wire default_300mhz_clk2_clk_p;
  wire default_300mhz_clk3_clk_n;
  wire default_300mhz_clk3_clk_p;
  wire [15:0]pcie4_mgt_rxn;
  wire [15:0]pcie4_mgt_rxp;
  wire [15:0]pcie4_mgt_txn;
  wire [15:0]pcie4_mgt_txp;
  wire pcie_perstn;
  wire [3:0]satellite_gpio;
  wire satellite_uart_rxd;
  wire satellite_uart_txd;
  wire [0:0]sys_clk_clk_n;
  wire [0:0]sys_clk_clk_p;
  
  assign DDR4_RESET_GATE = 1'b0;
  assign QSFP0_RESETL  = 1'b1;
  assign QSFP0_LPMODE = 1'b0;
  assign QSFP0_MODSELL= 1'b1;
  
  //wire QSFP0_RESETL;
  //wire QSFP0_LPMODE;
  //wire QSFP0_MODSELL;
  wire QSFP0_MODPRSL;
  wire QSFP0_INTL;

  design_1 design_1_i
       (.ddr4_sdram_c0_act_n(ddr4_sdram_c0_act_n),
        .ddr4_sdram_c0_adr(ddr4_sdram_c0_adr),
        .ddr4_sdram_c0_ba(ddr4_sdram_c0_ba),
        .ddr4_sdram_c0_bg(ddr4_sdram_c0_bg),
        .ddr4_sdram_c0_ck_c(ddr4_sdram_c0_ck_c),
        .ddr4_sdram_c0_ck_t(ddr4_sdram_c0_ck_t),
        .ddr4_sdram_c0_cke(ddr4_sdram_c0_cke),
        .ddr4_sdram_c0_cs_n(ddr4_sdram_c0_cs_n),
        .ddr4_sdram_c0_dq(ddr4_sdram_c0_dq),
        .ddr4_sdram_c0_dqs_c(ddr4_sdram_c0_dqs_c),
        .ddr4_sdram_c0_dqs_t(ddr4_sdram_c0_dqs_t),
        .ddr4_sdram_c0_odt(ddr4_sdram_c0_odt),
        .ddr4_sdram_c0_par(ddr4_sdram_c0_par),
        .ddr4_sdram_c0_reset_n(ddr4_sdram_c0_reset_n),
        .ddr4_sdram_c1_act_n(ddr4_sdram_c1_act_n),
        .ddr4_sdram_c1_adr(ddr4_sdram_c1_adr),
        .ddr4_sdram_c1_ba(ddr4_sdram_c1_ba),
        .ddr4_sdram_c1_bg(ddr4_sdram_c1_bg),
        .ddr4_sdram_c1_ck_c(ddr4_sdram_c1_ck_c),
        .ddr4_sdram_c1_ck_t(ddr4_sdram_c1_ck_t),
        .ddr4_sdram_c1_cke(ddr4_sdram_c1_cke),
        .ddr4_sdram_c1_cs_n(ddr4_sdram_c1_cs_n),
        .ddr4_sdram_c1_dq(ddr4_sdram_c1_dq),
        .ddr4_sdram_c1_dqs_c(ddr4_sdram_c1_dqs_c),
        .ddr4_sdram_c1_dqs_t(ddr4_sdram_c1_dqs_t),
        .ddr4_sdram_c1_odt(ddr4_sdram_c1_odt),
        .ddr4_sdram_c1_par(ddr4_sdram_c1_par),
        .ddr4_sdram_c1_reset_n(ddr4_sdram_c1_reset_n),
        .ddr4_sdram_c2_act_n(ddr4_sdram_c2_act_n),
        .ddr4_sdram_c2_adr(ddr4_sdram_c2_adr),
        .ddr4_sdram_c2_ba(ddr4_sdram_c2_ba),
        .ddr4_sdram_c2_bg(ddr4_sdram_c2_bg),
        .ddr4_sdram_c2_ck_c(ddr4_sdram_c2_ck_c),
        .ddr4_sdram_c2_ck_t(ddr4_sdram_c2_ck_t),
        .ddr4_sdram_c2_cke(ddr4_sdram_c2_cke),
        .ddr4_sdram_c2_cs_n(ddr4_sdram_c2_cs_n),
        .ddr4_sdram_c2_dq(ddr4_sdram_c2_dq),
        .ddr4_sdram_c2_dqs_c(ddr4_sdram_c2_dqs_c),
        .ddr4_sdram_c2_dqs_t(ddr4_sdram_c2_dqs_t),
        .ddr4_sdram_c2_odt(ddr4_sdram_c2_odt),
        .ddr4_sdram_c2_par(ddr4_sdram_c2_par),
        .ddr4_sdram_c2_reset_n(ddr4_sdram_c2_reset_n),
        .ddr4_sdram_c3_act_n(ddr4_sdram_c3_act_n),
        .ddr4_sdram_c3_adr(ddr4_sdram_c3_adr),
        .ddr4_sdram_c3_ba(ddr4_sdram_c3_ba),
        .ddr4_sdram_c3_bg(ddr4_sdram_c3_bg),
        .ddr4_sdram_c3_ck_c(ddr4_sdram_c3_ck_c),
        .ddr4_sdram_c3_ck_t(ddr4_sdram_c3_ck_t),
        .ddr4_sdram_c3_cke(ddr4_sdram_c3_cke),
        .ddr4_sdram_c3_cs_n(ddr4_sdram_c3_cs_n),
        .ddr4_sdram_c3_dq(ddr4_sdram_c3_dq),
        .ddr4_sdram_c3_dqs_c(ddr4_sdram_c3_dqs_c),
        .ddr4_sdram_c3_dqs_t(ddr4_sdram_c3_dqs_t),
        .ddr4_sdram_c3_odt(ddr4_sdram_c3_odt),
        .ddr4_sdram_c3_par(ddr4_sdram_c3_par),
        .ddr4_sdram_c3_reset_n(ddr4_sdram_c3_reset_n),
        .default_300mhz_clk0_clk_n(default_300mhz_clk0_clk_n),
        .default_300mhz_clk0_clk_p(default_300mhz_clk0_clk_p),
        .default_300mhz_clk1_clk_n(default_300mhz_clk1_clk_n),
        .default_300mhz_clk1_clk_p(default_300mhz_clk1_clk_p),
        .default_300mhz_clk2_clk_n(default_300mhz_clk2_clk_n),
        .default_300mhz_clk2_clk_p(default_300mhz_clk2_clk_p),
        .default_300mhz_clk3_clk_n(default_300mhz_clk3_clk_n),
        .default_300mhz_clk3_clk_p(default_300mhz_clk3_clk_p),
        .pcie4_mgt_rxn(pcie4_mgt_rxn),
        .pcie4_mgt_rxp(pcie4_mgt_rxp),
        .pcie4_mgt_txn(pcie4_mgt_txn),
        .pcie4_mgt_txp(pcie4_mgt_txp),
        .pcie_perstn(pcie_perstn),
        .satellite_gpio(satellite_gpio),
        .satellite_uart_rxd(satellite_uart_rxd),
        .satellite_uart_txd(satellite_uart_txd),
        .sys_clk_clk_n(sys_clk_clk_n),
        .sys_clk_clk_p(sys_clk_clk_p),
        .qsfp0_reset_l_0(),
        .qsfp0_lpmode_0(),
        .qsfp0_modprs_l_0(QSFP0_MODPRSL),
        .qsfp0_modsel_l_0(),
        .qsfp0_int_l_0(QSFP0_INTL)
        );
endmodule
