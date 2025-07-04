/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_axil_switch #(
    parameter AW = 16,
    parameter AR_BITS = 1,
    parameter R_BITS = 1,
    parameter AW_BITS = 1,
    parameter W_BITS = 1,
    parameter B_BITS = 1,
    parameter INUM = 1000
    ) ();

   localparam AR_BITS_MOD = AR_BITS > 0 ? AR_BITS : 1;
   localparam R_BITS_MOD = R_BITS > 0 ? R_BITS : 1;
   localparam AW_BITS_MOD = AW_BITS > 0 ? AW_BITS : 1;
   localparam W_BITS_MOD = W_BITS > 0 ? W_BITS : 1;
   localparam B_BITS_MOD = B_BITS > 0 ? B_BITS : 1;

   reg [AW-1:0]  in0_araddr;
   reg           in0_arvalid;
   wire          in0_arready;
   wire [31:0]   in0_rdata;
   wire [1:0]    in0_rresp;
   wire          in0_rvalid;
   reg           in0_rready;
   reg [AW-1:0]  in0_awaddr;
   reg           in0_awvalid;
   wire          in0_awready;
   reg [31:0]    in0_wdata;
   reg           in0_wvalid;
   wire          in0_wready;
   wire [1:0]    in0_bresp;
   wire          in0_bvalid;
   reg           in0_bready;

   reg [AW-1:0]  in1_araddr;
   reg           in1_arvalid;
   wire          in1_arready;
   wire [31:0]   in1_rdata;
   wire [1:0]    in1_rresp;
   wire          in1_rvalid;
   reg           in1_rready;
   reg [AW-1:0]  in1_awaddr;
   reg           in1_awvalid;
   wire          in1_awready;
   reg [31:0]    in1_wdata;
   reg           in1_wvalid;
   wire          in1_wready;
   wire [1:0]    in1_bresp;
   wire          in1_bvalid;
   reg           in1_bready;

   wire [AW-1:0] out_araddr;
   wire          out_arvalid;
   reg           out_arready;
   reg [31:0]    out_rdata;
   reg [1:0]     out_rresp;
   reg           out_rvalid;
   wire          out_rready;
   wire [AW-1:0] out_awaddr;
   wire          out_awvalid;
   reg           out_awready;
   wire [31:0]   out_wdata;
   wire          out_wvalid;
   reg           out_wready;
   reg [1:0]     out_bresp;
   reg           out_bvalid;
   wire          out_bready;

   wire          clk;
   wire          resetn;
   wire [31:0]   rd;

   clk_reset clk_reset (
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
   );

   axil_switch #(
       .AW ( AW )
   ) dut (
       .*
   );

   reg [31:0]    write_data0[0:255];
   reg [AW-1:0]  write_addr0[0:255];
   reg [7:0]     write_wpos0, write_wdpos0, write_rpos0, write_dpos0, write_bpos0;
   reg [31:0]    write_data1[0:255];
   reg [AW-1:0]  write_addr1[0:255];
   reg [7:0]     write_wpos1, write_wdpos1, write_rpos1, write_dpos1, write_bpos1;

   reg [AW-1:0]  read_addr0[0:255];
   reg [31:0]    read_data0[0:255];
   reg [7:0]     read_wpos0, read_rpos0, read_cpos0;
   reg [AW-1:0]  read_addr1[0:255];
   reg [31:0]    read_data1[0:255];
   reg [7:0]     read_wpos1, read_rpos1, read_cpos1;

   initial begin
      write_wpos0 = '0;
      write_wdpos0 = '0;
      write_rpos0 = '0;
      write_dpos0 = '0;
      write_bpos0 = '0;
      write_wpos1 = '0;
      write_wdpos1 = '0;
      write_rpos1 = '0;
      write_dpos1 = '0;
      write_bpos1 = '0;
      read_wpos0 = '0;
      read_rpos0 = '0;
      read_cpos0 = '0;
      read_wpos1 = '0;
      read_rpos1 = '0;
      read_cpos1 = '0;
   end

   reg need_read0_resp;
   reg need_read1_resp;
   wire w_read_resp_valid = R_BITS > 0 ? &rd[8+:R_BITS_MOD] : 1'b1;
   always @(posedge clk) begin
      if (~resetn) begin
         need_read0_resp <= 1'b0;
         need_read1_resp <= 1'b0;
         out_rresp <= 2'd0;
         out_rvalid <= 1'b0;
         out_arready <= 1'b0;
      end else if (out_arvalid && out_arready) begin
         if (out_araddr === read_addr0[read_rpos0]) begin
            if (w_read_resp_valid) begin
               out_rdata <= read_data0[read_rpos0];
               out_rvalid <= 1'b1;
               read_rpos0 <= read_rpos0 + 1'b1;
            end else begin
               need_read0_resp <= 1'b1;
               out_rvalid <= out_rvalid & ~out_rready;
            end
         end else if (out_araddr === read_addr1[read_rpos1]) begin
            if (w_read_resp_valid) begin
               out_rdata <= read_data1[read_rpos1];
               out_rvalid <= 1'b1;
               read_rpos1 <= read_rpos1 + 1'b1;
            end else begin
               need_read1_resp <= 1'b1;
               out_rvalid <= out_rvalid & ~out_rready;
            end
         end else begin
            $error("%d: read addr wrong. %h", $time, out_araddr);
            out_rvalid <= out_rvalid & ~out_rready;
         end
      end else if (need_read0_resp && w_read_resp_valid) begin
         out_rdata <= read_data0[read_rpos0];
         out_rvalid <= 1'b1;
         read_rpos0 <= read_rpos0 + 1'b1;
         need_read0_resp <= 1'b0;
      end else if (need_read1_resp && w_read_resp_valid) begin
         out_rdata <= read_data1[read_rpos1];
         out_rvalid <= 1'b1;
         read_rpos1 <= read_rpos1 + 1'b1;
         need_read1_resp <= 1'b0;
      end else begin
         out_rvalid <= out_rvalid & ~out_rready;
      end
      out_arready <= (AR_BITS > 0 ? &rd[3+:AR_BITS_MOD] : 1'b1) && (~out_rvalid || out_rready) && ~need_read0_resp && ~need_read1_resp;
   end

   logic is_write_a0;
   logic is_write_a1;
   logic is_write_d;
   reg   need_bresp0;
   reg   need_bresp1;
   reg [31:0] write_data;
   wire  w_bresp_valid = B_BITS > 0 ? &rd[13+:B_BITS_MOD] : 1'b1;
   always @(posedge clk) begin
      if (~resetn) begin
         is_write_a0 = 0;
         is_write_a1 = 0;
         is_write_d = 0;
         need_bresp0 <= 1'b0;
         need_bresp1 <= 1'b0;
         out_bresp <= 2'd0;
         out_bvalid <= 1'b0;
         out_awready <= 1'b0;
         out_wready <= 1'b0;
      end else begin
         if (out_awvalid && out_awready) begin
            if (out_awaddr == write_addr0[write_rpos0]) begin
               if (is_write_a0) $error("%d: write addr twice", $time);
               if (is_write_d) begin
                  need_bresp0 <= 1'b1;
                  is_write_d = 0;
                  if (write_data !== write_data0[write_dpos0]) begin
                     $error("%d: write data wrong. %h %h", $time, write_data, write_data0[write_dpos0]);
                  end
                  write_dpos0 <= write_dpos0 + 1'b1;
               end else begin
                  is_write_a0 = 1;
               end
               write_rpos0 <= write_rpos0 + 1'b1;
            end else if (out_awaddr == write_addr1[write_rpos1]) begin
               if (is_write_a1) $error("%d: write addr twice", $time);
               if (is_write_d) begin
                  need_bresp1 <= 1'b1;
                  is_write_d = 0;
                  if (write_data !== write_data1[write_dpos1]) begin
                     $error("%d: write data wrong. %h %h", $time, write_data, write_data1[write_dpos1]);
                  end
                  write_dpos1 <= write_dpos1 + 1'b1;
               end else begin
                  is_write_a1 = 1;
               end
               write_rpos1 <= write_rpos1 + 1'b1;
            end else begin
               $error("%d: write addr wrong. %h", $time, out_awaddr);
            end
         end
         if (is_write_a0 && is_write_a1) begin
            $error("%d: write addr duplicate", $time);
         end
         if (out_wvalid && out_wready) begin
            if (is_write_d) $error("%d: write data twice", $time);
            if (is_write_a0) begin
               need_bresp0 <= 1'b1;
               if (out_wdata !== write_data0[write_dpos0]) begin
                  $error("%d: write data wrong. %h %h", $time, out_wdata, write_data0[write_dpos0]);
               end
               write_dpos0 <= write_dpos0 + 1'b1;
               is_write_a0 = 0;
            end else if (is_write_a1) begin
               need_bresp1 <= 1'b1;
               if (out_wdata !== write_data1[write_dpos1]) begin
                  $error("%d: write data wrong. %h %h", $time, out_wdata, write_data1[write_dpos1]);
               end
               write_dpos1 <= write_dpos1 + 1'b1;
               is_write_a1 = 0;
            end else begin
               is_write_d = 1;
               write_data = out_wdata;
            end
         end
         out_awready <= (AW_BITS > 0 ? &rd[17+:AW_BITS_MOD] : 1'b1) && ~is_write_a0 && ~is_write_a1 && ~need_bresp0 && ~need_bresp1;
         out_wready <= (W_BITS > 0 ? &rd[20+:W_BITS_MOD] : 1'b1) && ~is_write_d && ~need_bresp0 && ~need_bresp1;
         if (need_bresp0 || need_bresp1) begin
            out_bvalid <= w_bresp_valid;
            need_bresp0 <= need_bresp0 && ~w_bresp_valid;
            need_bresp1 <= need_bresp1 && ~w_bresp_valid;
         end else begin
            out_bvalid <= out_bvalid & ~out_bready;
         end
      end
   end

   task static read_generate;
      logic is_in0 = 0;
      logic [AW-1:0] addr;
      logic [31:0]   data;
      logic          valid;
      logic          requesting0 = 0;
      logic          requesting1 = 0;
      int            read_req_count = 0;
      int            read_resp_count = 0;

      while (read_resp_count < INUM) @(posedge clk) begin
         is_in0 = rd[5];
         addr = rd;
         data = rd ^ 32'hdeadbeef;
         valid = (AR_BITS > 0 ? &rd[22+:AR_BITS_MOD] : 1'b1) && (read_req_count < INUM);
         if (is_in0 && ~requesting0) begin
            in0_araddr <= addr;
            in0_arvalid <= valid;
            in1_arvalid <= in1_arvalid & ~in1_arready;
            read_addr0[read_wpos0] <= addr;
            read_data0[read_wpos0] <= data;
            read_wpos0 <= read_wpos0 + valid;
            requesting0 <= valid;
            read_req_count+=valid;
         end else if (~is_in0 && ~requesting1) begin
            in1_araddr <= addr;
            in1_arvalid <= valid;
            in0_arvalid <= in0_arvalid & ~in0_arready;
            read_addr1[read_wpos1] <= addr;
            read_data1[read_wpos1] <= data;
            read_wpos1 <= read_wpos1 + valid;
            requesting1 <= valid;
            read_req_count+=valid;
         end else begin
            in0_arvalid <= in0_arvalid & ~in0_arready;
            in1_arvalid <= in1_arvalid & ~in1_arready;
         end
         if (in0_rvalid & in0_rready) begin
            if (~requesting0 || in0_rdata !== read_data0[read_cpos0]) begin
               $error("%d: read data wrong. %1d, %h %h", $time, requesting0,
                      in0_rdata, read_data0[read_cpos0]);
            end
            requesting0 <= 0;
            read_cpos0 <= read_cpos0 + 1'b1;
            read_resp_count++;
         end
         if (in1_rvalid & in1_rready) begin
            if (~requesting1 || in1_rdata !== read_data1[read_cpos1]) begin
               $error("%d: read data wrong. %1d, %h %h", $time, requesting1,
                      in1_rdata, read_data1[read_cpos1]);
            end
            requesting1 <= 0;
            read_cpos1 <= read_cpos1 + 1'b1;
            read_resp_count++;
         end
         in0_rready <= R_BITS > 0 ? &rd[27+:R_BITS_MOD] : 1'b1;
         in1_rready <= R_BITS > 0 ? &rd[26+:R_BITS_MOD] : 1'b1;
      end
   endtask

   task static write_generate;
      logic is_in0 = 0;
      logic [AW-1:0] addr;
      logic [31:0]   data;
      logic          avalid;
      logic          valid;
      logic [1:0]    requesting0 = 2'd0;
      logic [1:0]    requesting1 = 2'd0;
      int            write_areq_count = 0;
      int            write_req_count = 0;
      int            write_resp_count = 0;
      while (write_resp_count < INUM) @(posedge clk) begin
         if (~(requesting0[0] ^ requesting0[1]) && ~(requesting1[0] ^ requesting1[1])) begin
            is_in0 = rd[6];
         end
         addr = rd ^ 32'hba01;
         data = rd ^ 32'hbeeff00a;
         avalid = (AW_BITS > 0 ? &rd[12+:AW_BITS_MOD] : 1'b1) && (write_areq_count < INUM);
         valid = (W_BITS > 0 ? &rd[14+:W_BITS_MOD] : 1'b1) && (write_req_count < INUM);
         if (is_in0 && ~requesting0[0]) begin
            in0_awaddr <= addr;
            in0_awvalid <= avalid;
            in1_awvalid <= in1_awvalid & ~in1_awready;
            write_addr0[write_wpos0] <= addr;
            write_wpos0 <= write_wpos0 + avalid;
            requesting0[0] <= avalid;
            write_areq_count+=avalid;
         end else if (~is_in0 && ~requesting1[0]) begin
            in1_awaddr <= addr;
            in1_awvalid <= avalid;
            in0_awvalid <= in0_awvalid & ~in0_awready;
            write_addr1[write_wpos1] <= addr;
            write_wpos1 <= write_wpos1 + avalid;
            requesting1[0] <= avalid;
            write_areq_count+=avalid;
         end else begin
            in0_awvalid <= in0_awvalid & ~in0_awready;
            in1_awvalid <= in1_awvalid & ~in1_awready;
         end
         if (is_in0 && ~requesting0[1]) begin
            in0_wdata <= data;
            in0_wvalid <= valid;
            in1_wvalid <= in1_wvalid & ~in1_wready;
            write_data0[write_wdpos0] <= data;
            write_wdpos0 <= write_wdpos0 + valid;
            requesting0[1] <= valid;
            write_req_count+=valid;
         end else if (~is_in0 && ~requesting1[1]) begin
            in1_wdata <= data;
            in1_wvalid <= valid;
            in0_wvalid <= in0_wvalid & ~in0_wready;
            write_data1[write_wdpos1] <= data;
            write_wdpos1 <= write_wdpos1 + valid;
            requesting1[1] <= valid;
            write_req_count+=valid;
         end else begin
            in0_wvalid <= in0_wvalid & ~in0_wready;
            in1_wvalid <= in1_wvalid & ~in1_wready;
         end
         if (in0_bvalid & in0_bready) begin
            if (~&requesting0) begin
               $error("%d: write response wrong. %2h", $time, requesting0);
            end
            requesting0 <= 2'd0;
            write_resp_count++;
         end
         if (in1_bvalid & in1_bready) begin
            if (~&requesting1) begin
               $error("%d: write response wrong. %2h", $time, requesting1);
            end
            requesting1 <= 2'd0;
            write_resp_count++;
         end
         in0_bready <= B_BITS > 0 ? &rd[7+:B_BITS_MOD] : 1'b1;
         in1_bready <= B_BITS > 0 ? &rd[9+:B_BITS_MOD] : 1'b1;
      end
   endtask

   initial begin
      in0_arvalid = 1'b0;
      in0_rready = 1'b0;
      in0_awvalid = 1'b0;
      in0_wvalid = 1'b0;
      in0_bready = 1'b0;
      in1_arvalid = 1'b0;
      in1_rready = 1'b0;
      in1_awvalid = 1'b0;
      in1_wvalid = 1'b0;
      in1_bready = 1'b0;
      out_arready = 1'b0;
      out_rvalid = 1'b0;
      out_awready = 1'b0;
      out_wready = 1'b0;
      out_bvalid = 1'b0;

      @(posedge clk);
      while (~resetn) @(posedge clk);
      @(posedge clk);

      fork
         read_generate();
         write_generate();
      join

      $finish;
   end

endmodule

module test_axil_switch_fast;
   tb_axil_switch #(
       .AR_BITS ( 0 ),
       .R_BITS ( 0 ),
       .AW_BITS ( 0 ),
       .W_BITS ( 0 ),
       .B_BITS ( 0 )
   ) tb ();
endmodule

module test_axil_switch_random;
   tb_axil_switch tb();
endmodule

module test_axil_switch_slow_in;
   tb_axil_switch #(
       .AR_BITS ( 2 ),
       .R_BITS ( 0 ),
       .AW_BITS ( 2 ),
       .W_BITS ( 2 ),
       .B_BITS ( 0 )
   ) tb ();
endmodule

module test_axil_switch_slow_out;
   tb_axil_switch #(
       .AR_BITS ( 0 ),
       .R_BITS ( 2 ),
       .AW_BITS ( 0 ),
       .W_BITS ( 0 ),
       .B_BITS ( 2 )
   ) tb ();
endmodule
