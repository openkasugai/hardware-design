/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module pio_to_ctrl

  (
  input      clk,
  input      rst_n,

  input      req_compl,
  input      compl_done,

  input      cfg_power_state_change_interrupt,
  output reg cfg_power_state_change_ack
  );

  reg                 trn_pending;

  //  Check if completion is pending

  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n ) begin
      trn_pending <=  1'b0;
    end else begin
      if (!trn_pending && req_compl)
        trn_pending <=  1'b1;
      else if (compl_done)
        trn_pending <=  1'b0;
    end
  end


  //  Turn-off OK if requested and no transaction is pending


  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n ) begin
      cfg_power_state_change_ack <= 1'b0;
    end else begin
      if ( cfg_power_state_change_interrupt  && !trn_pending)
        cfg_power_state_change_ack <= 1'b1;
      else
        cfg_power_state_change_ack <= 1'b0;
    end
  end


endmodule // pio_to_ctrl
