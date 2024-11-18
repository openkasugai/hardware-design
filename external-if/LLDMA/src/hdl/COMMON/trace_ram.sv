/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module trace_ram(
  input  logic         user_clk,
  input  logic         reset_n,
  input  logic         trace_clr,
  input  logic         trace_enb,
  input  logic         trace_we,
  input  logic [ 31:0] trace_wd,      
  input  logic         trace_re,
  input  logic         trace_mode,
  output logic [ 31:0] trace_rd       
);

  logic		ram_we;
  logic		ram_wt_inh;
  logic [  9:0] ram_wp;
  logic		ram_re;
  logic		ram_re_1tc;
  logic		ram_re_2tc;
  logic [  9:0] ram_rp;
  logic [ 31:0] ram_rd;
  logic [ 31:0] ram_rd_1tc;

  assign ram_we =   trace_enb  & trace_we & (~ram_wt_inh);
  assign ram_re = (~trace_enb) & trace_re;

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      ram_wt_inh      <= 'b0;
      ram_wp          <= 'b0;
      ram_re_1tc      <= 'b0;
      ram_re_2tc      <= 'b0;
      ram_rd_1tc      <= 'b0;
    end else begin
      ram_re_1tc      <= ram_re;
      ram_re_2tc      <= ram_re_1tc;
      if (trace_clr == 1'b1) begin
        ram_wp        <= 'b0;
        ram_wt_inh      <= 'b0;
      end else begin
	      if (ram_we || ram_re) begin
	        ram_wp   <= ram_wp + 1;
	      end  
	      ram_wt_inh <= trace_mode & (ram_wt_inh | (ram_we & (ram_wp==10'h3FF)));
      end
      if (ram_re_1tc) begin
        ram_rd_1tc <= ram_rd;
      end
   end
  end

  assign ram_rp = ram_wp;

  TRACE_4K TRACE_RAM (
    .clka(user_clk), .ena(ram_we), .wea(ram_we), .addra(ram_wp), .dina (trace_wd),
    .clkb(user_clk), .enb(ram_re),               .addrb(ram_rp), .doutb(ram_rd));

  assign trace_rd = ram_re_2tc ? ram_rd_1tc : 32'b0;

endmodule
