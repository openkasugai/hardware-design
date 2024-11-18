/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module pio_intr_ctrl
  (

  input             user_clk,      // User Clock
  input             reset_n,  // User Reset

  // Trigger to generate interrupts (to / from Mem access Block)
  input             u_gen_leg_intr,    // Generate Legacy Interrupts
  input             u_gen_msi_intr,    // Generate MSI Interrupts
  input             u_gen_msix_intr,   // Generate MSI-X Interrupts
  
  input             gen_leg_intr,    // Generate Legacy Interrupts
  input             gen_msi_intr,    // Generate MSI Interrupts
  input             gen_msix_intr,   // Generate MSI-X Interrupts
  output reg        interrupt_done,  // Indicates whether interrupt is done or in process

  // Legacy Interrupt Interface

  input             cfg_interrupt_sent, // Core asserts this signal when it sends out a Legacy interrupt
  output reg [3:0]  cfg_interrupt_int,  // 4 Bits for INTA, INTB, INTC, INTD (assert or deassert)

  // MSI Interrupt Interface

  input             cfg_interrupt_msi_enable,
  input             cfg_interrupt_msi_sent,
  input             cfg_interrupt_msi_fail,
  input      [31:0] cfg_interrupt_msi_int_user,

  output reg [31:0] cfg_interrupt_msi_int,

  //MSI-X Interrupt Interface

  input             cfg_interrupt_msix_enable,
  input             cfg_interrupt_msix_sent,
  input             cfg_interrupt_msix_fail,

  output reg        cfg_interrupt_msix_int,
  output reg [63:0] cfg_interrupt_msix_address,
  output reg [31:0] cfg_interrupt_msix_data

  );

  //wire    [31:0]   cfg_interrupt_msi_int_vio;

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n) begin

      cfg_interrupt_msi_int       <=  32'b0;
      cfg_interrupt_msix_int      <=  1'b0;
      cfg_interrupt_msix_address  <=  64'b0;
      cfg_interrupt_msix_data     <=  32'b0;
      cfg_interrupt_int           <=  4'b0;
      interrupt_done              <=  1'b0;

    end
        else begin

          case ({(gen_leg_intr || u_gen_leg_intr), (gen_msi_intr || u_gen_msi_intr), (gen_msix_intr || u_gen_msix_intr)})

            3'b100 : begin // Generate LEgacy interrupt

              if(cfg_interrupt_int == 4'h0) begin
                cfg_interrupt_int <=  4'h1;
              end
              else
                cfg_interrupt_int <=  4'h0;

            end //  Generate LEgacy interrupt

            3'b010 : begin // Generate MSI Interrupt

              if(cfg_interrupt_msi_enable)
                //cfg_interrupt_msi_int     <=  32'hAAAA_AAAA;
                //cfg_interrupt_msi_int     <= cfg_interrupt_msi_int_vio;
                cfg_interrupt_msi_int     <= cfg_interrupt_msi_int_user;
              else
                cfg_interrupt_msi_int     <=  32'b0;

            end

            3'b001 : begin // Generate MSI-X Interrupt

              if (cfg_interrupt_msix_enable) begin
                cfg_interrupt_msix_int          <=  1'b1;
                cfg_interrupt_msix_address<=  64'hAAAA_BBBB_CCCC_DDDD;
                cfg_interrupt_msix_data   <=  32'hDEAD_BEEF;
              end
              else begin
                cfg_interrupt_msix_int          <=  1'b0;
                cfg_interrupt_msix_address<=  64'b0;
                cfg_interrupt_msix_data   <=  32'b0;
              end

            end  // Generate MSI-X Interrupt

            default : begin

              cfg_interrupt_msi_int     <=  32'b0;
              cfg_interrupt_msix_int        <=  1'b0;
              cfg_interrupt_msix_address<=  64'b0;
              cfg_interrupt_msix_data   <=  32'b0;
              cfg_interrupt_int         <=  4'b0;

            end

          endcase

          if((cfg_interrupt_int != 4'h0) ||
            ((cfg_interrupt_msi_enable ) && (cfg_interrupt_msi_sent  || cfg_interrupt_msi_fail )) ||
            ((cfg_interrupt_msix_enable) && (cfg_interrupt_msix_sent || cfg_interrupt_msix_fail)))

            interrupt_done <=  1'b1;
          else
            interrupt_done <=  1'b0;

    end // end of resetelse block
  end

endmodule


