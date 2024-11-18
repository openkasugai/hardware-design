/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module cif_clktr #(
)(
 input  logic         reset_n,
 input  logic         ext_reset_n,
 input  logic         user_clk,    // LLDMA internal clock
 input  logic         ext_clk,     // Chain control clock

 input  logic         transfer_cmd_valid,
 input  logic [63:0]  transfer_cmd_data,
 output logic         transfer_cmd_ready,
 output logic         transfer_eve_valid,
 output logic [127:0] transfer_eve_data,
 input  logic         transfer_eve_ready,

 output logic         cmd_valid,
 output logic [63:0]  cmd_data,
 input  logic         cmd_ready,
 input  logic         eve_valid,
 input  logic [127:0] eve_data,
 output logic         eve_ready
);

logic cmdi_full;
logic cmdi_empty;
logic eveo_full;
logic eveo_empty;

`ifdef FIFO_SIML

cif_cmdi_fifo cifu_cmdi_fifo (
  .rst           (~ext_reset_n),  // I
  .wr_clk        (ext_clk),  // I
  .rd_clk        (user_clk),  // I
  .din           (transfer_cmd_data),  // I
  .wr_en         (~cmdi_full & transfer_cmd_valid),  // I
  .rd_en         (~cmdi_empty & cmd_ready),  // I
  .dout          (cmd_data),  // O
  .full          (cmdi_full),  // O
  .empty         (cmdi_empty)  // O
);

cif_eveo_fifo cifu_eveo_fifo (
  .rst           (~reset_n),  // I
  .wr_clk        (user_clk),  // I
  .rd_clk        (ext_clk),  // I
  .din           (eve_data),  // I
  .wr_en         (~eveo_full & eve_valid),  // I
  .rd_en         (~eveo_empty & transfer_eve_ready),  // I
  .dout          (transfer_eve_data),  // O
  .full          (eveo_full),  // O
  .empty         (eveo_empty)  // O
);

`else

cif_cmdi_fifo cifu_cmdi_fifo (
  .srst          (~ext_reset_n),  // I
  .wr_clk        (ext_clk),  // I
  .rd_clk        (user_clk),  // I
  .din           (transfer_cmd_data),  // I
  .wr_en         (~cmdi_full & transfer_cmd_valid),  // I
  .wr_rst_busy   (),  // O
  .rd_en         (~cmdi_empty & cmd_ready),  // I
  .dout          (cmd_data),  // O
  .full          (cmdi_full),  // O
  .empty         (cmdi_empty),  // O
  .rd_rst_busy   ()  // O
);

cif_eveo_fifo cifu_eveo_fifo (
  .srst          (~reset_n),  // I
  .wr_clk        (user_clk),  // I
  .rd_clk        (ext_clk),  // I
  .din           (eve_data),  // I
  .wr_en         (~eveo_full & eve_valid),  // I
  .wr_rst_busy   (),  // O
  .rd_en         (~eveo_empty & transfer_eve_ready),  // I
  .dout          (transfer_eve_data),  // O
  .full          (eveo_full),  // O
  .empty         (eveo_empty),  // O
  .rd_rst_busy   ()  // O
);

`endif

assign transfer_cmd_ready = ~cmdi_full;
assign cmd_valid          = ~cmdi_empty;
assign eve_ready          = ~eveo_full;
assign transfer_eve_valid = ~eveo_empty;

endmodule
