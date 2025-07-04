/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module function_ctrl_wrapper #(
    parameter DW_LOG = 9,
    parameter CTX_ID_BITS = 4,
    parameter TDEST_BITS = 4
    ) (
    //start generate IPORT_NUM IPORT_NUM
    input [(1<<DW_LOG)-1:0]      in_IPORT_NUM_tdata,
    input [(1<<(DW_LOG-3))-1:0]  in_IPORT_NUM_tkeep,
    input [CTX_ID_BITS-1:0]      in_IPORT_NUM_tuser,
    input                        in_IPORT_NUM_tlast,
    input                        in_IPORT_NUM_tid,
    input                        in_IPORT_NUM_tvalid,
    output                       in_IPORT_NUM_tready,
    //end
    //start generate OPORT_NUM OPORT_NUM
    output [(1<<DW_LOG)-1:0]     in_OPORT_NUM_tdata,
    output [(1<<(DW_LOG-3))-1:0] in_OPORT_NUM_tkeep,
    output [CTX_ID_BITS-1:0]     in_OPORT_NUM_tuser,
    output [TDEST_BITS-1:0]      in_OPORT_NUM_tdest,
    output                       in_OPORT_NUM_tlast,
    output                       in_OPORT_NUM_tvalid,
    input                        in_OPORT_NUM_tready,
    //end
    //start generate IPORT_NUM IPORT_NUM
    input [127:0]                in_frame_header_IPORT_NUM_tdata,
    input [CTX_ID_BITS-1:0]      in_frame_header_IPORT_NUM_tuser,
    input                        in_frame_header_IPORT_NUM_tvalid,
    output                       in_frame_header_IPORT_NUM_tready,
    //end
    //start generate IPORT_NUM IPORT_NUM
    output [CTX_ID_BITS-1:0]     in_frame_header_consume_IPORT_NUM_tuser,
    output [TDEST_BITS-1:0]      in_frame_header_consume_IPORT_NUM_tdest,
    output                       in_frame_header_consume_IPORT_NUM_tvalid,
    input                        in_frame_header_consume_IPORT_NUM_tready,
    //end
    //start generate IPORT_NUM IPORT_NUM
    output [7:0]                 in_frame_consume_IPORT_NUM_tdata,
    output [CTX_ID_BITS-1:0]     in_frame_consume_IPORT_NUM_tuser,
    output [TDEST_BITS-1:0]      in_frame_consume_IPORT_NUM_tdest,
    output                       in_frame_consume_IPORT_NUM_tvalid,
    input                        in_frame_consume_IPORT_NUM_tready,
    //end
    //start generate OPORT_NUM OPORT_NUM
    input [127:0]                out_frame_header_OPORT_NUM_tdata,
    input [CTX_ID_BITS-1:0]      out_frame_header_OPORT_NUM_tuser,
    input                        out_frame_header_OPORT_NUM_tvalid,
    output                       out_frame_header_OPORT_NUM_tready,
    //end
    //start generate OPORT_NUM OPORT_NUM
    output [127:0]               out_frame_complete_OPORT_NUM_tdata,
    output [CTX_ID_BITS-1:0]     out_frame_complete_OPORT_NUM_tuser,
    output [TDEST_BITS-1:0]      out_frame_complete_OPORT_NUM_tdest,
    output                       out_frame_complete_OPORT_NUM_tvalid,
    input                        out_frame_complete_OPORT_NUM_tready,
    //end
    //start generate IPORT_NUM IPORT_NUM
    output [(1<<DW_LOG)-1:0]     func_in_IPORT_NUM_tdata,
    output [(1<<(DW_LOG-3))-1:0] func_in_IPORT_NUM_tkeep,
    output [CTX_ID_BITS-1:0]     func_in_IPORT_NUM_tuser,
    output                       func_in_IPORT_NUM_tlast, // eof
    output                       func_in_IPORT_NUM_tvalid,
    input                        func_in_IPORT_NUM_tready,
    //end
    //start generate OPORT_NUM OPORT_NUM
    input [(1<<DW_LOG)-1:0]      func_out_OPORT_NUM_tdata,
    input [(1<<(DW_LOG-3))-1:0]  func_out_OPORT_NUM_tkeep,
    input [CTX_ID_BITS-1:0]      func_out_OPORT_NUM_tuser,
    input                        func_out_OPORT_NUM_tlast, // eof
    input                        func_out_OPORT_NUM_tvalid,
    output                       func_out_OPORT_NUM_tready,
    //end
    //start generate IPORT_NUM IPORT_NUM
    output [63:0]                func_in_addr_IPORT_NUM,
    output [31:0]                func_in_size_IPORT_NUM,
    //end
    //start generate OPORT_NUM OPORT_NUM
    output [63:0]                func_out_addr_OPORT_NUM,
    output [31:0]                func_out_size_OPORT_NUM,
    //end
    output                       func_ap_start,
    input                        func_ap_idle,
    input                        func_ap_done,
    input                        func_ap_ready,
    input                        clk,
    input                        resetn
    );

   localparam IPORT_MAX = 8;
   localparam OPORT_MAX = 8;

   //start parameter
   localparam IPORT_NUM = 1;
   localparam OPORT_NUM = 1;
   localparam [IPORT_MAX-1:0] IPORT_IS_MM = {IPORT_NUM{1'b0}};
   localparam [OPORT_MAX-1:0] OPORT_IS_MM = {OPORT_NUM{1'b0}};
   localparam [OPORT_MAX-1:0] OPORT_USER_OVERWRITE = {OPORT_NUM{1'b1}};
   //end

   function_ctrl #(
       .DW_LOG ( DW_LOG ),
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .TDEST_BITS ( TDEST_BITS ),
       .AXI_ID_BITS ( AXI_ID_BITS ),
       .IPORT_NUM ( IPORT_NUM ),
       .OPORT_NUM ( OPORT_NUM ),
       .IPORT_MAX ( IPORT_MAX ),
       .OPORT_MAX ( OPORT_MAX ),
       .IPORT_IS_MM ( IPORT_IS_MM ),
       .OPORT_IS_MM ( OPORT_IS_MM ),
       .OPORT_USER_OVERWRITE ( OPORT_USER_OVERWRITE )
   ) function_ctrl (
       //start aggregate IPORT_NUM IPORT_NUM
       .in_tdata ( in_IPORT_NUM_tdata ),
       .in_tkeep ( in_IPORT_NUM_tkeep ),
       .in_tuser ( in_IPORT_NUM_tuser ),
       .in_tlast ( in_IPORT_NUM_tlast ),
       .in_tid ( in_IPORT_NUM_tid ),
       .in_tvalid ( in_IPORT_NUM_tvalid ),
       .in_tready ( in_IPORT_NUM_tready ),
       //end
       //start aggregate OPORT_NUM OPORT_NUM
       .out_tdata ( out_OPORT_NUM_tdata ),
       .out_tkeep ( out_OPORT_NUM_tkeep ),
       .out_tuser ( out_OPORT_NUM_tuser ),
       .out_tdest ( out_OPORT_NUM_tdest ),
       .out_tlast ( out_OPORT_NUM_tlast ),
       .out_tvalid ( out_OPORT_NUM_tvalid ),
       .out_tready ( out_OPORT_NUM_tready ),
       //end
       //start aggregate IPORT_NUM IPORT_NUM
       .in_frame_header_tdata ( in_frame_header_IPORT_NUM_tdata ),
       .in_frame_header_tuser ( in_frame_header_IPORT_NUM_tuser ),
       .in_frame_header_tvalid ( in_frame_header_IPORT_NUM_tvalid ),
       .in_frame_header_tready ( in_frame_header_IPORT_NUM_tready ),
       .in_frame_header_consume_tuser ( in_frame_header_consume_IPORT_NUM_tuser ),
       .in_frame_header_consume_tdest ( in_frame_header_consume_IPORT_NUM_tdest ),
       .in_frame_header_consume_tvalid ( in_frame_header_consume_IPORT_NUM_tvalid ),
       .in_frame_header_consume_tready ( in_frame_header_consume_IPORT_NUM_tready ),
       .in_frame_consume_tdata ( in_frame_consume_IPORT_NUM_tdata ),
       .in_frame_consume_tuser ( in_frame_consume_IPORT_NUM_tuser ),
       .in_frame_consume_tdest ( in_frame_consume_IPORT_NUM_tdest ),
       .in_frame_consume_tvalid ( in_frame_consume_IPORT_NUM_tvalid ),
       .in_frame_consume_tready ( in_frame_consume_IPORT_NUM_tready ),
       //end
       //start aggregate OPORT_NUM OPORT_NUM
       .out_frame_header_tdata ( out_frame_header_OPORT_NUM_tdata ),
       .out_frame_header_tuser ( out_frame_header_OPORT_NUM_tuser ),
       .out_frame_header_tvalid ( out_frame_header_OPORT_NUM_tvalid ),
       .out_frame_header_tready ( out_frame_header_OPORT_NUM_tready ),
       .out_frame_complete_tdata ( out_frame_complete_OPORT_NUM_tdata ),
       .out_frame_complete_tuser ( out_frame_complete_OPORT_NUM_tuser ),
       .out_frame_complete_tdest ( out_frame_complete_OPORT_NUM_tdest ),
       .out_frame_complete_tvalid ( out_frame_complete_OPORT_NUM_tvalid ),
       .out_frame_complete_tready ( out_frame_complete_OPORT_NUM_tready ),
       //end
       //start aggregate IPORT_NUM IPORT_NUM
       .func_in_tdata ( func_in_IPORT_NUM_tdata ),
       .func_in_tkeep ( func_in_IPORT_NUM_tkeep ),
       .func_in_tuser ( func_in_IPORT_NUM_tuser ),
       .func_in_tlast ( func_in_IPORT_NUM_tlast ),
       .func_in_tvalid ( func_in_IPORT_NUM_tvalid ),
       .func_in_tready ( func_in_IPORT_NUM_tready ),
       //end
       //start aggregate OPORT_NUM OPORT_NUM
       .func_out_tdata ( func_out_OPORT_NUM_tdata ),
       .func_out_tkeep ( func_out_OPORT_NUM_tkeep ),
       .func_out_tuser ( func_out_OPORT_NUM_tuser ),
       .func_out_tlast ( func_out_OPORT_NUM_tlast ),
       .func_out_tvalid ( func_out_OPORT_NUM_tvalid ),
       .func_out_tready ( func_out_OPORT_NUM_tready ),
       //end
       //start aggregate IPORT_NUM IPORT_NUM
       .func_in_addr ( func_in_addr_IPORT_NUM ),
       .func_in_size ( func_in_size_IPORT_NUM ),
       //end
       //start aggregate OPORT_NUM OPORT_NUM
       .func_out_addr ( func_out_addr_OPORT_NUM ),
       .func_out_size ( func_out_size_OPORT_NUM ),
       //end
       .func_ap_start ( func_ap_start ),
       .func_ap_idle ( func_ap_idle ),
       .func_ap_done ( func_ap_done ),
       .func_ap_ready ( func_ap_ready ),
       .clk ( clk ),
       .resetn ( resetn )
   );

endmodule
