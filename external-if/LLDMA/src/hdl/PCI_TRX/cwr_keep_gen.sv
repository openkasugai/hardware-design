/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module cwr_keep_gen #(
   parameter C_DATA_WIDTH = 512
   ) (
   input [C_DATA_WIDTH-1:0]         cwr_axis_tdata,
   input                            cwr_axis_tvalid,
   input                            cwr_axis_tlast,
   input                            cwr_axis_tready,
   output reg [C_DATA_WIDTH-1:0]    cwr_axis_tdata_out,
   output reg                       cwr_axis_tvalid_out,
   output reg                       cwr_axis_tlast_out,
   output reg [C_DATA_WIDTH/32-1:0] cwr_axis_tkeep_out,
   output reg [3:0]                 cwr_axis_last_be,
   input                            clk,
   input                            resetn
   );

   reg [127:0]                  prev_data;
   reg [10:0]                   dwords;
   reg                          sop;
   reg                          one_dword;
   wire [C_DATA_WIDTH/32-1:0]   next_keep;

   always @(posedge clk) begin
      if (~resetn) begin
         sop <= 1'b1;
         one_dword <= 1'b0;
         dwords <= 'd0;
         prev_data <= 'd0;
         cwr_axis_tdata_out <= 'd0;
         cwr_axis_tvalid_out <= 1'b0;
         cwr_axis_tlast_out <= 1'b0;
         cwr_axis_tkeep_out <= 'd0;
         cwr_axis_last_be <= 'd0;
      end else if (cwr_axis_tvalid & cwr_axis_tready) begin
         sop <= cwr_axis_tlast;
         if (sop) begin
            prev_data <= cwr_axis_tdata[127:0];
            dwords <= cwr_axis_tdata[64+:11] + 3'd4;
            one_dword <= cwr_axis_tdata[64+:11] == 11'd1;
            if (|dwords) begin
//               cwr_axis_tdata_out <= {'d0, prev_data};
               cwr_axis_tdata_out <= {{(C_DATA_WIDTH-128){1'b0}}, prev_data};
               cwr_axis_tvalid_out <= 1'b1;
               cwr_axis_tlast_out <= 1'b1;
               cwr_axis_tkeep_out <= next_keep;
               cwr_axis_last_be <= {4{~one_dword}};
            end else begin
               cwr_axis_tvalid_out <= 1'b0;
            end
         end else begin
            prev_data <= cwr_axis_tdata[C_DATA_WIDTH-128+:128];
            dwords <= dwords >= 'd16 ? dwords - 'd16 : 'd0;
            cwr_axis_tdata_out <= {cwr_axis_tdata[C_DATA_WIDTH-129:0], prev_data};
            cwr_axis_tvalid_out <= 1'b1;
            cwr_axis_tlast_out <= dwords <= 'd16;
            cwr_axis_tkeep_out <= next_keep;
            cwr_axis_last_be <= {4{~one_dword}};
         end
      end else begin
         if (|dwords && dwords <= 'd4 && cwr_axis_tready) begin
//            cwr_axis_tdata_out <= {'d0, prev_data};
            cwr_axis_tdata_out <= {{(C_DATA_WIDTH-128){1'b0}}, prev_data};
            cwr_axis_tvalid_out <= 1'b1;
            cwr_axis_tlast_out <= 1'b1;
            cwr_axis_tkeep_out <= next_keep;
            cwr_axis_last_be <= {4{~one_dword}};
            dwords <= 'd0;
         end else begin
            cwr_axis_tvalid_out <= cwr_axis_tvalid_out & ~cwr_axis_tready;
         end
      end
   end

   generate
      for (genvar i=0; i<C_DATA_WIDTH/32; i=i+1) begin
         assign next_keep[i] = i < dwords;
      end
   endgenerate

endmodule
