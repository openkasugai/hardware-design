/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module enqdeq_arb #(
  parameter N = 16	// Round Robin bit
  )
  (
  // clock/reset
  input  logic user_clk,
  input  logic reset_n,
  
  // ctl port
  input  logic [(N-1):0] req,
  input  logic           tkn_ack,
  output logic [(N-1):0] tkn
  );

  // --------------------------------------------------------
  // Register
  // --------------------------------------------------------

  reg    [(N-1):0] pointer_reg;

  // --------------------------------------------------------
  // Net
  // --------------------------------------------------------

  wire   [(N-1):0] req_masked;
  wire   [(N-1):0] mask_higher_pri_reqs;
  wire   [(N-1):0] tkn_masked;
  wire   [(N-1):0] unmask_higher_pri_reqs;
  wire   [(N-1):0] tkn_unmasked;
  wire             no_req_masked;
  wire             mask_ptr_sel;
  wire             unmask_ptr_sel;
  integer          i;

  // --------------------------------------------------------
  // Mask_Expand Round-Robin Arbiter
  // --------------------------------------------------------

  // Simple priority arbitration for masked portion
  assign req_masked                  = req & pointer_reg;
  assign mask_higher_pri_reqs[N-1:1] = (mask_higher_pri_reqs[N-2:0] | req_masked[N-2:0]);
  assign mask_higher_pri_reqs[0]     = 1'b0;
  assign tkn_masked[N-1:0]           = (req_masked[N-1:0] & ~mask_higher_pri_reqs[N-1:0]);

  // Simple priority arbitration for unmasked portion
  assign unmask_higher_pri_reqs[N-1:1] = (unmask_higher_pri_reqs[N-2:0] | req[N-2:0]);
  assign unmask_higher_pri_reqs[0]     = 1'b0;
  assign tkn_unmasked[N-1:0]           = req[N-1:0] & ~unmask_higher_pri_reqs[N-1:0];

  // Use tkn_masked if there is any there, otherwise use tkn_unmasked
  assign no_req_masked = ~(|req_masked);
  assign tkn           = ({N{no_req_masked}} & tkn_unmasked) | tkn_masked;

  // Generate arbiter pointer update
  assign mask_ptr_sel   = |req_masked & tkn_ack;
  assign unmask_ptr_sel = |req        & tkn_ack;


  // --------------------------------------------------------
  // Pointer update : only update if there's a req
  // --------------------------------------------------------

  always @ (posedge user_clk or negedge reset_n)
  begin
    if (!reset_n) begin
      pointer_reg   <=    {N{1'b1}};
    end else if (mask_ptr_sel) begin   // select if masked arbiter used
      pointer_reg   <=    mask_higher_pri_reqs;
    end else if (unmask_ptr_sel) begin // select if unmasked arbiter used
      pointer_reg   <=    unmask_higher_pri_reqs;
    end
  end

endmodule
