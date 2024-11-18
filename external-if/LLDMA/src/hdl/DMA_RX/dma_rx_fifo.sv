/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module dma_rx_fifo(
  input  logic         user_clk,
  input  logic         reset_n,
  input  logic         fifo_we,
  input  logic [ 31:0] fifo_wd,
  input  logic         fifo_re,
  output logic [ 31:0] fifo_rd,
  output logic [ 10:0] used_cnt
);

  logic         fifo_we_1t;
  logic [  9:0] fifo_wp;
  logic [  9:0] fifo_rp;

  logic         ram_we;
  logic [  9:0] ram_wa;
  logic [ 31:0] ram_wd;
  logic [ 31:0] ram_wd_1t;

  logic         ram_re_not_inc;
  logic         ram_re;
  logic [  9:0] ram_ra;
  logic [ 31:0] ram_rd;

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      fifo_wp         <= '0;
      fifo_we_1t      <= '0;
      fifo_rp         <= '0;
      fifo_rd         <= '0;
      used_cnt        <= '0;
      ram_wd_1t       <= '0;
    end
    else begin
      fifo_we_1t <= fifo_we;

      if(fifo_we) begin
        fifo_wp       <= fifo_wp  + 1'b1;
        ram_wd_1t     <= ram_wd;
        if(fifo_re) begin
          fifo_rp     <= fifo_rp  + 1'b1;
        end
        else begin
          used_cnt    <= used_cnt + 1'b1;
        end
      end

      else if(fifo_re) begin
        fifo_rp       <= fifo_rp  + 1'b1;
        used_cnt      <= used_cnt - 1'b1;
      end

      if((used_cnt == 0) & fifo_we) begin
          fifo_rd     <= ram_wd;
      end
      else if(used_cnt == 1) begin
        if(fifo_re) begin
          if(fifo_we) begin
            fifo_rd   <= ram_wd;
          end
        end
      end
      else if(used_cnt == 2) begin
        if(fifo_re) begin
            fifo_rd   <= ram_wd_1t;
        end
      end
      else if(used_cnt >  2) begin
        if(fifo_re) begin
            fifo_rd   <= ram_rd;
        end
      end

    end
  end

  assign ram_we = fifo_we;
  assign ram_wa = fifo_wp;
  assign ram_wd = fifo_wd;

  assign ram_re_not_inc = (used_cnt == 2) & fifo_we_1t & ~fifo_re;

  assign ram_re = ((used_cnt > 2) & fifo_re) | ram_re_not_inc;
  assign ram_ra = ram_re_not_inc ? fifo_rp + 1 :  fifo_rp + 2;

  TRACE_4K FIFO_RAM (
    .clka(user_clk), .ena(ram_we), .wea(ram_we), .addra(ram_wa), .dina (ram_wd),
    .clkb(user_clk), .enb(ram_re),               .addrb(ram_ra), .doutb(ram_rd));

endmodule
