/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module toe_ctrl_ch_reg #(
    parameter IS_TX = 0,
    parameter CH_NUM_LOG = 4,
    parameter SESSION_NUM_LOG = 6,
    parameter CH_REG_BITS = 8
    ) (
    input [CH_REG_BITS-1:0]          araddr,
    input                            arvalid,
    output [31:0]                    rdata,
    output                           rvalid,
    input [CH_REG_BITS-1:0]          awaddr,
    input [31:0]                     wdata,
    input                            wvalid,

    output reg                       ch_enable,
    output reg                       ch_valid,
    output                           ch_activate,
    output reg                       ch_active,
    output reg                       ch_ready,
    output reg [SESSION_NUM_LOG-1:0] ch_session_id,
    output reg [31:0]                ch_frame_size,
    output reg [15:0]                ch_credit_max,
    output reg [15:0]                ch_credit_cur,
    output reg [31:0]                ch_ip_base,
    output reg [31:0]                ch_ip_mask,
    output reg [15:0]                ch_port_base,
    output reg [15:0]                ch_port_mask,

    input [SESSION_NUM_LOG-1:0]      connected_session_id,
    input                            connected,

    input                            close,
    input [SESSION_NUM_LOG-1:0]      close_session_id,

    input [SESSION_NUM_LOG-1:0]      find_ch_session_id,
    output reg                       find_ch_matched,

    input                            activate_done,
    input [SESSION_NUM_LOG-1:0]      activate_done_session_id,

    input [15:0]                     cp_config_credit_max,
    input [31:0]                     cp_config_frame_size,
    input [SESSION_NUM_LOG-1:0]      cp_config_session_id,
    input                            cp_config_valid,
    output                           cp_config_done,
    input [SESSION_NUM_LOG-1:0]      credit_inc_session_id,
    input                            credit_inc,
    input [SESSION_NUM_LOG-1:0]      credit_dec_session_id,
    input                            credit_dec,

    input                            clk,
    input                            resetn
    );

   wire     w_close = close && close_session_id == ch_session_id;
   wire     w_activate_done = activate_done && activate_done_session_id == ch_session_id;
   wire     w_cp_config_valid = cp_config_valid && cp_config_session_id == ch_session_id;
   wire     w_credit_inc = credit_inc && credit_inc_session_id == ch_session_id;
   wire     w_credit_dec = credit_dec && credit_dec_session_id == ch_session_id;

   always @(posedge clk) begin
      if (~resetn) begin
         find_ch_matched <= 1'b0;
      end else begin
         find_ch_matched <= ch_valid && find_ch_session_id == ch_session_id;
      end
   end

   generate
      if (IS_TX!=0) begin
         reg cp_config_done_reg;
         always @(posedge clk) begin
            if (~resetn) begin
               cp_config_done_reg <= 1'b0;
            end else begin
               cp_config_done_reg <= w_cp_config_valid;
            end
         end
         assign cp_config_done = cp_config_done_reg;
      end else begin
         assign cp_config_done = 1'b0;
      end
   endgenerate

   always @(posedge clk) begin
      if (~resetn) begin
         ch_enable <= 1'b0;
      end else if (w_close) begin
         ch_enable <= 1'b0;
      end else if (wvalid && awaddr == 'h0) begin
         ch_enable <= wdata[0];
      end
   end

   wire w_ch_activate_read;
   generate
      if (IS_TX == 0) begin
         reg ch_activate_reg;
         always @(posedge clk) begin
            if (~resetn) begin
               ch_activate_reg <= 1'b0;
            end else if (wvalid && awaddr == 'h0) begin
               ch_activate_reg <= wdata[4];
            end else if (w_activate_done | w_close | ~ch_enable) begin
               ch_activate_reg <= 1'b0;
            end
         end
         assign ch_activate = ch_activate_reg & ch_valid;
         assign w_ch_activate_read = ch_activate_reg;
      end else begin
         assign ch_activate = 1'b0;
         assign w_ch_activate_read = 1'b0;
      end
   endgenerate

   always @(posedge clk) begin
      if (~resetn) begin
         ch_valid <= 1'b0;
         ch_active <= 1'b0;
         ch_ready <= 1'b0;
      end else begin
         ch_valid <= (ch_enable && connected) | (ch_valid & ~w_close & ch_enable);
         ch_active <= w_activate_done | w_cp_config_valid | (ch_active & ~w_close & ch_enable);
         ch_ready <= ((w_activate_done | w_cp_config_valid | ch_active) & ch_valid) | (ch_ready & ~w_close & ch_valid);
      end
   end

   always @(posedge clk) begin
      if (~resetn) begin
         ch_session_id <= 'd0;
      end else if (connected) begin
         ch_session_id <= connected_session_id;
      end else if (w_close) begin
         ch_session_id <= 'd0;
      end
   end

   generate
      always @(posedge clk) begin
         if (~resetn) begin
            ch_frame_size <= 32'd0;
         end else if (IS_TX == 0) begin
            if (wvalid && awaddr == 'hc) begin
               ch_frame_size <= wdata;
            end
         end else begin
            if (w_cp_config_valid) begin
               ch_frame_size <= cp_config_frame_size;
            end
         end
      end
   endgenerate

   generate
      if (IS_TX == 0) begin
         always @(posedge clk) begin
            if (~resetn) begin
               ch_credit_max <= 'd0;
               ch_credit_cur <= 'd0;
            end else begin
               if (wvalid && awaddr == 'h10) begin
                  ch_credit_max <= wdata[15:0];
               end
               if (w_close) begin
                  ch_credit_cur <= 'd0;
               end else begin
                  ch_credit_cur <= ch_credit_cur + w_credit_inc - w_credit_dec;
               end
            end
         end
      end else begin
         always @(posedge clk) begin
            if (~resetn) begin
               ch_credit_max <= 'd0;
               ch_credit_cur <= 'd0;
            end else begin
               if (w_cp_config_valid) begin
                  ch_credit_max <= cp_config_credit_max;
                  ch_credit_cur <= 'd0;
               end else begin
                  ch_credit_cur <= ch_credit_cur + w_credit_inc - w_credit_dec;
               end
            end
         end
      end
   endgenerate

   always @(posedge clk) begin
      if (~resetn) begin
         ch_ip_base <= 'd0;
      end else if (wvalid && awaddr == 'h18) begin
         ch_ip_base <= wdata;
      end
   end
   always @(posedge clk) begin
      if (~resetn) begin
         ch_ip_mask <= 'd0;
      end else if (wvalid && awaddr == 'h1c) begin
         ch_ip_mask <= wdata;
      end
   end
   always @(posedge clk) begin
      if (~resetn) begin
         ch_port_base <= 'd0;
      end else if (wvalid && awaddr == 'h20) begin
         ch_port_base <= wdata[15:0];
      end
   end
   always @(posedge clk) begin
      if (~resetn) begin
         ch_port_mask <= 'd0;
      end else if (wvalid && awaddr == 'h24) begin
         ch_port_mask <= wdata[15:0];
      end
   end

   wire [31:0] w_rdata;
   reg [31:0]  rdata_reg;
   reg         rdata_valid_reg;
   always @(posedge clk) begin
      if (~resetn) begin
         rdata_reg <= 'd0;
         rdata_valid_reg <= 'd0;
      end else begin
         rdata_valid_reg <= arvalid;
         rdata_reg <= arvalid ? w_rdata : 32'd0;
      end
   end
   assign w_rdata = araddr == 'h00 ? {27'h0, w_ch_activate_read, 3'd0, ch_enable} :
                    araddr == 'h04 ? {23'h0, ch_ready, 3'd0, ch_active, 3'd0, ch_valid} :
                    araddr == 'h08 ? {{32-SESSION_NUM_LOG{1'b0}}, ch_session_id} :
                    araddr == 'h0c ? ch_frame_size :
                    araddr == 'h10 ? {16'd0, ch_credit_max} :
                    araddr == 'h14 ? {16'd0, ch_credit_cur} :
                    araddr == 'h18 ? ch_ip_base :
                    araddr == 'h1c ? ch_ip_mask :
                    araddr == 'h20 ? {16'd0, ch_port_base} :
                    araddr == 'h24 ? {16'd0, ch_port_mask} : 32'hdeadbeef;

   assign rdata = rdata_reg;
   assign rvalid = rdata_valid_reg;

endmodule
