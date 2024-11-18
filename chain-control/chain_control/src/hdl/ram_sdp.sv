/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

module ram_sdp #(
  parameter integer DATA_WIDTH  = 32,
  parameter integer DEPTH       = 32,
  parameter integer ADDR_WIDTH  = $clog2(DEPTH)
) (
  input   wire                  clk     ,
  input   wire                  wr_en   ,
  input   wire[ADDR_WIDTH-1:0]  wr_addr ,
  input   wire[DATA_WIDTH-1:0]  wr_data ,
  input   wire                  rd_en   ,
  input   wire[ADDR_WIDTH-1:0]  rd_addr ,
  output  wire[DATA_WIDTH-1:0]  rd_data
);
  
  reg                 r_wr_en;
  reg[ADDR_WIDTH-1:0] r_wr_addr;
  reg[DATA_WIDTH-1:0] r_wr_data;
  
  reg                 r_rd_en;
  reg[ADDR_WIDTH-1:0] r_rd_addr;
  reg[DATA_WIDTH-1:0] r_rd_data;
  
  reg[DATA_WIDTH-1:0] mem [0:DEPTH-1];

  always @(posedge clk) begin
    r_wr_en   <= wr_en;
    r_wr_addr <= wr_addr;
    r_wr_data <= wr_data;
    r_rd_en   <= rd_en;
    r_rd_addr <= rd_addr;
  end

  always @(posedge clk) begin
    if (r_wr_en) begin
      mem[r_wr_addr] <= r_wr_data;
    end
  end

  always @(posedge clk) begin
    if (r_rd_en) begin
      r_rd_data <= mem[r_rd_addr];
    end
  end
  assign rd_data = r_rd_data;

  //initial begin
  //  for (int i = 0; i < DEPTH; i++) begin
  //    mem[i] = $random(10);
  //  end
  //end

endmodule

`default_nettype wire
