/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module bit_count #(
    parameter DIV = 4,
    parameter WL = 6
    ) (
    input [(1<<WL)-1:0]     idata,
    output [DIV*(WL+1)-1:0] odata
    );

   localparam WIDTH = 1 << WL;
   localparam DIV_WIDTH = WIDTH / DIV;

   generate
      for (genvar i=0; i<DIV; i=i+1) begin
         if (DIV_WIDTH == 16) begin
            assign odata[(WL+1)*i+:WL+1] = {{WL{1'b0}},idata[i*DIV_WIDTH]} + idata[i*DIV_WIDTH+1] +
                                           idata[i*DIV_WIDTH+2] + idata[i*DIV_WIDTH+3] +
                                           idata[i*DIV_WIDTH+4] + idata[i*DIV_WIDTH+5] +
                                           idata[i*DIV_WIDTH+6] + idata[i*DIV_WIDTH+7] +
                                           idata[i*DIV_WIDTH+8] + idata[i*DIV_WIDTH+9] +
                                           idata[i*DIV_WIDTH+10] + idata[i*DIV_WIDTH+11] +
                                           idata[i*DIV_WIDTH+12] + idata[i*DIV_WIDTH+13] +
                                           idata[i*DIV_WIDTH+14] + idata[i*DIV_WIDTH+15];
         end else begin
            // todo
         end
      end
   endgenerate

endmodule

module bit_count_sum #(
    parameter DIV = 4,
    parameter WL = 6,
    parameter ORIGIN = 1
    ) (
    input [DIV*(WL+1)-1:0] idata,
    output [WL:0]          odata
    );

   wire [WL:0]             mdata;
   generate
      if (DIV == 4) begin
         assign mdata = idata[0+:WL+1] + idata[WL+1+:WL+1] +
                        idata[(WL+1)*2+:WL+1] + idata[(WL+1)*3+:WL+1];
      end else begin
         // todo
      end
      if (ORIGIN == 0) begin
         assign odata = mdata - 1'b1;
      end else begin
         assign odata = mdata;
      end
   endgenerate

endmodule
