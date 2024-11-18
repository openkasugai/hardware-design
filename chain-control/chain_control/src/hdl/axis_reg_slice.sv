/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

module axis_reg_slice #(
  parameter integer DATA_WIDTH = 32 // Data Bus Width
) (
  input   wire                  resetn    , // Synchronous Reset
  input   wire                  ap_clk    , // Clock
  input   wire[DATA_WIDTH-1:0]  in_tdata  , // Write Data
  input   wire                  in_tvalid , // Write Valid
  output  wire                  in_tready , // Write Ready
  output  wire[DATA_WIDTH-1:0]  out_tdata , // Read Data
  output  wire                  out_tvalid, // Read Valid
  input   wire                  out_tready  // Read Ready
);

  // buffer registers
  reg r_in_ready;
  reg r_in_valid;
  reg r_out_valid;
  reg[DATA_WIDTH-1:0] r_in_data;
  reg[DATA_WIDTH-1:0] r_out_data;

  // buffer shift enable
  wire w_shift_en = out_tready | ~ r_out_valid;
  
  // buffer control
  always @(posedge ap_clk) begin
    if ( ! resetn) begin
      r_in_ready  <= 1'b0;
      r_in_valid  <= 1'b0;
      r_in_data   <= {DATA_WIDTH{1'b0}};
      r_out_valid <= 1'b0;
      r_out_data  <= {DATA_WIDTH{1'b0}};
    end else if (w_shift_en) begin
      r_in_ready  <= 1'b1;
      r_in_valid  <= 1'b0;
      if (r_in_ready) begin
        r_out_valid <= in_tvalid;
        r_out_data  <= in_tdata;
      end else begin
        r_out_valid <= r_in_valid;
        r_out_data  <= r_in_data;
      end
    end else begin
      if ( ! r_out_valid) begin
        r_in_ready  <= 1'b1;
        r_in_valid  <= 1'b0;
        r_out_valid <= in_tvalid;
        r_out_data  <= in_tdata;
      end else if ( ! r_in_valid) begin
        r_in_ready  <= ~ in_tvalid;
        r_in_valid  <= in_tvalid;
        r_in_data   <= in_tdata;
      end
    end
  end
  assign in_tready  = r_in_ready;
  assign out_tvalid = r_out_valid;
  assign out_tdata  = r_out_data;

endmodule

`default_nettype wire
