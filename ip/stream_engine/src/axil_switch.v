/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module axil_switch #(
    parameter AW = 16
    ) (
    input [AW-1:0]  in0_araddr,
    input           in0_arvalid,
    output          in0_arready,
    output [31:0]   in0_rdata,
    output [1:0]    in0_rresp,
    output          in0_rvalid,
    input           in0_rready,
    input [AW-1:0]  in0_awaddr,
    input           in0_awvalid,
    output          in0_awready,
    input [31:0]    in0_wdata,
    input           in0_wvalid,
    output          in0_wready,
    output [1:0]    in0_bresp,
    output          in0_bvalid,
    input           in0_bready,

    input [AW-1:0]  in1_araddr,
    input           in1_arvalid,
    output          in1_arready,
    output [31:0]   in1_rdata,
    output [1:0]    in1_rresp,
    output          in1_rvalid,
    input           in1_rready,
    input [AW-1:0]  in1_awaddr,
    input           in1_awvalid,
    output          in1_awready,
    input [31:0]    in1_wdata,
    input           in1_wvalid,
    output          in1_wready,
    output [1:0]    in1_bresp,
    output          in1_bvalid,
    input           in1_bready,

    output [AW-1:0] out_araddr,
    output          out_arvalid,
    input           out_arready,
    input [31:0]    out_rdata,
    input [1:0]     out_rresp,
    input           out_rvalid,
    output          out_rready,
    output [AW-1:0] out_awaddr,
    output          out_awvalid,
    input           out_awready,
    output [31:0]   out_wdata,
    output          out_wvalid,
    input           out_wready,
    input [1:0]     out_bresp,
    input           out_bvalid,
    output          out_bready,

    input           clk,
    input           resetn
    );

   reg [AW-1:0]     araddr;
   reg              arvalid;
   reg [31:0]       rdata;
   reg              rvalid0, rvalid1;
   reg              rd_is_in0;
   reg              rd_valid;

   always @(posedge clk) begin
      if (~resetn) begin
         arvalid <= 1'b0;
         rd_valid <= 1'b0;
         rvalid0 <= 1'b0;
         rvalid1 <= 1'b0;
      end else begin
         if (in0_arvalid && in0_arready) begin
            araddr <= in0_araddr;
            arvalid <= 1'b1;
            rd_valid <= 1'b1;
            rd_is_in0 <= 1'b1;
         end else if (in1_arvalid && in1_arready) begin
            araddr <= in1_araddr;
            arvalid <= 1'b1;
            rd_valid <= 1'b1;
            rd_is_in0 <= 1'b0;
         end else begin
            arvalid <= arvalid && ~out_arready;
         end
         if (out_rvalid & out_rready) begin
            rdata <= out_rdata;
            rvalid0 <= rd_is_in0;
            rvalid1 <= ~rd_is_in0;
            rd_valid <= 1'b0;
         end else begin
            rvalid0 <= rvalid0 && ~in0_rready;
            rvalid1 <= rvalid1 && ~in1_rready;
         end
      end
   end
   assign in0_arready = ~rd_valid;
   assign in1_arready = ~rd_valid && ~in0_arvalid;
   assign out_araddr = araddr;
   assign out_arvalid = arvalid;
   assign out_rready = ~rvalid0 && ~rvalid1;
   assign in0_rresp = 2'd0;
   assign in1_rresp = 2'd0;
   assign in0_rdata = rdata;
   assign in1_rdata = rdata;
   assign in0_rvalid = rvalid0;
   assign in1_rvalid = rvalid1;

   reg [AW-1:0]     awaddr;
   reg              awvalid;
   reg [31:0]       wdata;
   reg              wvalid;
   reg              wr_is_in0;
   reg [1:0]        wr_valid;
   reg              bvalid0, bvalid1;

   always @(posedge clk) begin
      if (~resetn) begin
         awvalid <= 1'b0;
         wvalid <= 1'b0;
         wr_valid <= 2'd0;
         bvalid0 <= 1'b0;
         bvalid1 <= 1'b0;
      end else begin
         if (in0_awvalid && in0_awready) begin
            wr_is_in0 <= 1'b1;
            wr_valid[0] <= 1'b1;
            awvalid <= 1'b1;
            awaddr <= in0_awaddr;
         end else if (in1_awvalid && in1_awready) begin
            wr_is_in0 <= 1'b0;
            wr_valid[0] <= 1'b1;
            awvalid <= 1'b1;
            awaddr <= in1_awaddr;
         end else begin
            awvalid <= awvalid & ~out_awready;
         end
         if (in0_wvalid && in0_wready) begin
            wr_is_in0 <= 1'b1;
            wr_valid[1] <= 1'b1;
            wvalid <= 1'b1;
            wdata <= in0_wdata;
         end else if (in1_wvalid && in1_wready) begin
            wr_is_in0 <= 1'b0;
            wr_valid[1] <= 1'b1;
            wvalid <= 1'b1;
            wdata <= in1_wdata;
         end else begin
            wvalid <= wvalid & ~out_wready;
         end
         if (out_bvalid & out_bready) begin
            wr_valid <= 'd0;
            bvalid0 <= wr_is_in0;
            bvalid1 <= ~wr_is_in0;
         end else begin
            bvalid0 <= bvalid0 & ~in0_bready;
            bvalid1 <= bvalid1 & ~in1_bready;
         end
      end
   end

   assign in0_awready = ~wr_valid[0] && (~wr_valid[1] || wr_is_in0);
   assign in1_awready = ~wr_valid[0] && ((~wr_valid[1] && ~in0_awvalid && ~in0_wvalid) || (wr_valid[1] && ~wr_is_in0));
   assign in0_wready = ~wr_valid[1] && (~wr_valid[0] || wr_is_in0);
   assign in1_wready = ~wr_valid[1] && ((~wr_valid[1] && ~in0_awvalid && ~in0_wvalid) || (wr_valid[1] && ~wr_is_in0));
   assign out_awaddr = awaddr;
   assign out_awvalid = awvalid;
   assign out_wdata = wdata;
   assign out_wvalid = wvalid;
   assign out_bready = ~bvalid0 && ~bvalid1;
   assign in0_bresp = 2'd0;
   assign in1_bresp = 2'd0;
   assign in0_bvalid = bvalid0;
   assign in1_bvalid = bvalid1;

endmodule
