/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module axis_ddu_sink #(
     parameter DW = 512,
     parameter DESTW = 4,
     parameter USERW = 4
     ) (
     input [DW-1:0]    in_tdata,
     input [USERW-1:0] in_tuser,
     input [DESTW-1:0] in_tdest,
     input             in_tvalid,
     output            in_tready,
     input             clk
     );

   assign in_tready = 1'b1;

endmodule

module axis_du_sink #(
     parameter DESTW = 4,
     parameter USERW = 4
     ) (
     input [USERW-1:0] in_tuser,
     input [DESTW-1:0] in_tdest,
     input             in_tvalid,
     output            in_tready,
     input             clk
     );

   assign in_tready = 1'b1;

endmodule

module axis_dkulid_sink #(
     parameter DW = 512,
     parameter DESTW = 4,
     parameter USERW = 4,
     parameter IDW = 1
     ) (
     input [DW-1:0]    in_tdata,
     input [DW/8-1:0]  in_tkeep,
     input [USERW-1:0] in_tuser,
     input [DESTW-1:0] in_tdest,
     input [IDW-1:0]   in_tid,
     input             in_tlast,
     input             in_tvalid,
     output            in_tready,
     input             clk
     );

   assign in_tready = 1'b1;

endmodule

module axis_dkuld_sink #(
     parameter DW = 512,
     parameter DESTW = 4,
     parameter USERW = 4
     ) (
     input [DW-1:0]    in_tdata,
     input [DW/8-1:0]  in_tkeep,
     input [USERW-1:0] in_tuser,
     input [DESTW-1:0] in_tdest,
     input             in_tlast,
     input             in_tvalid,
     output            in_tready,
     input             clk
     );

   assign in_tready = 1'b1;

endmodule
