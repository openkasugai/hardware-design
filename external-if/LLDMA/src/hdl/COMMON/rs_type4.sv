/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module rs_type4 #(
  parameter DATA_WIDTH = 512
)(
  input  logic         user_clk,
  input  logic         reset_n,

  input  logic                  tvalid_in,
  input  logic [DATA_WIDTH-1:0] tdata_in,
  output logic                  tready_in,

  output logic                  tvalid_out,
  output logic [DATA_WIDTH-1:0] tdata_out,
  input  logic                  tready_out
);

  logic                  tvalid_q;
  logic [DATA_WIDTH-1:0] tdata_q;
  logic                  tvalid_q2;
  logic [DATA_WIDTH-1:0] tdata_q2;
  logic                  update;

  assign tready_in = (~tvalid_q)  || (~tvalid_q2);
  assign update    =   tready_out || (~tvalid_out);

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      tvalid_q     <= '0;
      tdata_q      <= '0;
      tvalid_q2    <= '0;
      tdata_q2     <= '0;
      tvalid_out   <= '0;
      tdata_out    <= '0;
    end else begin

      if(tready_in) begin
        tvalid_q   <= tvalid_in;
        tdata_q    <= tdata_in;
      end else if(update & tvalid_q & tvalid_q2) begin
        tvalid_q   <= '0;
      end

      tvalid_q2    <= (update ? (tvalid_q && tvalid_q2) : (tvalid_q || tvalid_q2));
      if((update || ~tvalid_q2) & tvalid_q) begin
        tdata_q2   <= tdata_q;
      end

      if(update) begin
        tvalid_out <= (tvalid_q || tvalid_q2);
        tdata_out  <= (tvalid_q2 ? tdata_q2 : tdata_q);
      end
    end
  end

endmodule
