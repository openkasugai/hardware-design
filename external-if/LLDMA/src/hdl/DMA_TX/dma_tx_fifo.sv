/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module dma_tx_fifo(
   input  logic         user_clk
  ,input  logic         reset_n
  ,input  logic         fifo_we
  ,input  logic [511:0] fifo_wd1
  ,input  logic [511:0] fifo_wd2
  ,input  logic         fifo_re
  ,output logic [511:0] fifo_rd1
  ,output logic [511:0] fifo_rd2
  ,output logic [ 10:0] fifo_wadrs
  ,output logic [ 10:0] fifo_radrs
  ,output logic [ 10:0] fifo_wp
  ,output logic [ 10:0] fifo_rp
);

  logic         fifo_we_1t;
//  logic [ 10:0] fifo_wp;
//  logic [ 10:0] fifo_rp;
  logic [ 11:0] used_cnt;

  logic         ram_we;
  logic [ 10:0] ram_wa;
  logic [511:0] ram_wd1;
  logic [511:0] ram_wd2;
  logic [511:0] ram_wd1_1t;
  logic [511:0] ram_wd2_1t;

  logic         ram_re_not_inc;
  logic         ram_re;
  logic [ 10:0] ram_ra;
  logic [511:0] ram_rd1;
  logic [511:0] ram_rd2;


  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      fifo_wp    <= '0;
      fifo_we_1t <= '0;
      fifo_rp    <= '0;
      fifo_rd1   <= '0;
      fifo_rd2   <= '0;
      used_cnt   <= '0;
      ram_wd1_1t <= '0;
      ram_wd2_1t <= '0;
    end
    else begin
      fifo_we_1t <= fifo_we;

      if(fifo_we) begin
        fifo_wp    <= fifo_wp  + 1'b1;
        ram_wd1_1t <= ram_wd1;
        ram_wd2_1t <= ram_wd2;
        if(fifo_re) begin
          fifo_rp <= fifo_rp  + 1'b1;
        end
        else begin
          used_cnt <= used_cnt + 1'b1;
        end
      end

      else if(fifo_re) begin
        fifo_rp  <= fifo_rp  + 1'b1;
        used_cnt <= used_cnt - 1'b1;
      end

      if((used_cnt == 0) & fifo_we) begin
          fifo_rd1 <= ram_wd1;
          fifo_rd2 <= ram_wd2;
      end
      else if(used_cnt == 1) begin
        if(fifo_re) begin
          if(fifo_we) begin
            fifo_rd1 <= ram_wd1;
            fifo_rd2 <= ram_wd2;
          end
        end
      end
      else if(used_cnt == 2) begin
        if(fifo_re) begin
            fifo_rd1 <= ram_wd1_1t;
            fifo_rd2 <= ram_wd2_1t;
        end
      end
      else if(used_cnt >  2) begin
        if(fifo_re) begin
            fifo_rd1 <= ram_rd1;
            fifo_rd2 <= ram_rd2;
        end
      end

    end
  end

  assign ram_we  = fifo_we;
  assign ram_wa  = fifo_wp;
  assign ram_wd1 = fifo_wd1;
  assign ram_wd2 = fifo_wd2;

  assign ram_re_not_inc = (used_cnt == 2) & fifo_we_1t & ~fifo_re;

  assign ram_re = ((used_cnt > 2) & fifo_re) | ram_re_not_inc;
  assign ram_ra = ram_re_not_inc ? fifo_rp + 1 :  fifo_rp + 2;

  DMA_BUF_128K FIFO_RAM1 (
    .clka(user_clk), .ena(ram_we), .wea(ram_we), .addra(ram_wa), .dina (ram_wd1),
    .clkb(user_clk), .enb(ram_re),               .addrb(ram_ra), .doutb(ram_rd1));

  DMA_BUF_128K FIFO_RAM2 (
    .clka(user_clk), .ena(ram_we), .wea(ram_we), .addra(ram_wa), .dina (ram_wd2),
    .clkb(user_clk), .enb(ram_re),               .addrb(ram_ra), .doutb(ram_rd2));


assign fifo_wadrs = ram_wa;
assign fifo_radrs = ram_ra;

endmodule
