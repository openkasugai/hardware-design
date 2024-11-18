/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module pio_tx_rrb
  (
  // clock/reset
  user_clk,
  reset_n,
  
  // ctl port
  req,
  tkn,
  tkn_ack,
  pe
  );

  // --------------------------------------------------------
  // Parameter Declarations. Round Robin bit
  // --------------------------------------------------------

  parameter N = 6;

  // --------------------------------------------------------
  // Clock/Reset Signals
  // --------------------------------------------------------

  input            user_clk;
  input            reset_n;
   
  // --------------------------------------------------------
  // Arbiter Control Port
  // --------------------------------------------------------

  input  [(N-1):0] req;
  output [(N-1):0] tkn;
  input            tkn_ack;
  output           pe;

  // --------------------------------------------------------
  // Register
  // --------------------------------------------------------

  reg    [(N-1):0] pointer_reg;
  reg              pointer_reg_p;

  // --------------------------------------------------------
  // Net
  // --------------------------------------------------------

  wire   [(N-1):0] req_masked;
  wire   [(N-1):0] mask_higher_pri_reqs;
  reg              mask_higher_pri_reqs_p;
  wire   [(N-1):0] tkn_masked;
  wire   [(N-1):0] unmask_higher_pri_reqs;
  reg              unmask_higher_pri_reqs_p;
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
  // parity predict
  // --------------------------------------------------------

  always @(*)
  begin
    case(N%2)
      0       : begin // even bit pointer
        mask_higher_pri_reqs_p = 1'b1 ;
        unmask_higher_pri_reqs_p = 1'b1 ;
        for(i=N-1 ; i>=0 ; i=i-1) begin
          if(req_masked[i]) mask_higher_pri_reqs_p = (i[0]) ;
          if(req[i]) unmask_higher_pri_reqs_p = (i[0]) ;
        end end
      default : begin // odd bit pointer  
        mask_higher_pri_reqs_p = 1'b1 ;
        unmask_higher_pri_reqs_p = 1'b1 ;
        for(i=N-1 ; i>=0 ; i=i-1) begin
          if(req_masked[i]) mask_higher_pri_reqs_p = ~(i[0]) ;
          if(req[i]) unmask_higher_pri_reqs_p = ~(i[0]) ;
        end end
    endcase
  end

  // --------------------------------------------------------
  // Pointer update : only update if there's a req
  // --------------------------------------------------------

  always @ (posedge user_clk or negedge reset_n)
  begin
    if (!reset_n) begin
      pointer_reg   <=    {N{1'b1}};
      pointer_reg_p <= ~(^{N{1'b1}});
    end else if (mask_ptr_sel) begin   // select if masked arbiter used
      pointer_reg   <=    mask_higher_pri_reqs;
      pointer_reg_p <=    mask_higher_pri_reqs_p;
    end else if (unmask_ptr_sel) begin // select if unmasked arbiter used
      pointer_reg   <=    unmask_higher_pri_reqs;
      pointer_reg_p <=    unmask_higher_pri_reqs_p;
    end
  end

  // --------------------------------------------------------
  // Parity error
  // --------------------------------------------------------

  assign pe = ~(^{pointer_reg,pointer_reg_p});

endmodule
