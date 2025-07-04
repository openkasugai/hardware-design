/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1 ns / 1 ps

module tb_function_ctrl_nop_wrapper #(
    parameter DW_LOG = 9,
    parameter CTX_ID_BITS = 4,
    parameter TDEST_BITS = 4,
    parameter BURST_BITS = 5,
    parameter IN_ST_BITS = 0,
    parameter OUT_ST_BITS = 0,
    parameter HEADER_V_BITS = 0,
    parameter HEADER_R_BITS = 0,
    parameter CONSUME_R_BITS = 0,
    parameter COMP_R_BITS = 0,
    parameter FRAME_NUM = 10,
    parameter FRAME_BITS = 2,
    parameter SIZE_BITS = 14
    ) ();

   localparam DW = 1 << DW_LOG;
   localparam KW_LOG = DW_LOG - 3;
   localparam KW = 1 << KW_LOG;
   localparam IN_ST_BITS_MOD = IN_ST_BITS > 0 ? IN_ST_BITS : 1;
   localparam OUT_ST_BITS_MOD = OUT_ST_BITS > 0 ? OUT_ST_BITS : 1;
   localparam HEADER_V_BITS_MOD = HEADER_V_BITS > 0 ? HEADER_V_BITS : 1;
   localparam HEADER_R_BITS_MOD = HEADER_R_BITS > 0 ? HEADER_R_BITS : 1;
   localparam CONSUME_R_BITS_MOD = CONSUME_R_BITS > 0 ? CONSUME_R_BITS : 1;
   localparam COMP_R_BITS_MOD = COMP_R_BITS > 0 ? COMP_R_BITS : 1;
   localparam FRAME_BITS_MOD = FRAME_BITS > 0 ? FRAME_BITS : 1;

   reg [DW-1:0]           in_0_tdata;
   reg [KW-1:0]           in_0_tkeep;
   reg [CTX_ID_BITS-1:0]  in_0_tuser;
   reg                    in_0_tlast;
   reg                    in_0_tid; // eof
   reg                    in_0_tvalid;
   wire                   in_0_tready;
   wire [DW-1:0]          out_0_tdata;
   wire [KW-1:0]          out_0_tkeep;
   wire [CTX_ID_BITS-1:0] out_0_tuser;
   wire [TDEST_BITS-1:0]  out_0_tdest;
   wire                   out_0_tlast; // eof
   wire                   out_0_tvalid;
   reg                    out_0_tready;
   // reg frame info
   reg [127:0]            in_frame_header_0_tdata;
   reg [CTX_ID_BITS-1:0]  in_frame_header_0_tuser;
   reg                    in_frame_header_0_tvalid;
   wire                   in_frame_header_0_tready;
   wire [CTX_ID_BITS-1:0] in_frame_header_consume_0_tuser;
   wire [TDEST_BITS-1:0]  in_frame_header_consume_0_tdest;
   wire                   in_frame_header_consume_0_tvalid;
   reg                    in_frame_header_consume_0_tready;
   wire [7:0]             in_frame_consume_0_tdata;
   wire [CTX_ID_BITS-1:0] in_frame_consume_0_tuser;
   wire [TDEST_BITS-1:0]  in_frame_consume_0_tdest;
   wire                   in_frame_consume_0_tvalid;
   reg                    in_frame_consume_0_tready;
   // wire frame info
   reg [127:0]            out_frame_header_0_tdata;
   reg [CTX_ID_BITS-1:0]  out_frame_header_0_tuser;
   reg                    out_frame_header_0_tvalid;
   wire                   out_frame_header_0_tready;
   wire [127:0]           out_frame_complete_0_tdata;
   wire [CTX_ID_BITS-1:0] out_frame_complete_0_tuser;
   wire [TDEST_BITS-1:0]  out_frame_complete_0_tdest;
   wire                   out_frame_complete_0_tvalid;
   reg                    out_frame_complete_0_tready;

   wire clk, resetn;
   wire [31:0] rd;

   clk_reset clk_reset (
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
   );

   nop_st_wrapper #(
       .DW_LOG ( DW_LOG ),
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .TDEST_BITS ( TDEST_BITS ),
       .BURST_BITS ( BURST_BITS )
   ) dut (
       .*
   );

   reg [31:0]  frame_sizes[0:255];
   reg [TDEST_BITS-1:0] frame_idests[0:255];
   reg [TDEST_BITS-1:0] frame_odests[0:255];
   reg [CTX_ID_BITS-1:0] frame_iusers[0:255];
   reg [CTX_ID_BITS-1:0] frame_ousers[0:255];
   reg [7:0]   frame_wpos;
   reg [7:0]   frame_ihpos, frame_ohpos;
   reg [7:0]   frame_ihcpos;
   reg [7:0]   frame_icpos, frame_ocpos;
   reg [7:0]   frame_idpos, frame_odpos;

   reg [DW-1:0]          st_data[0:255];
   reg [KW-1:0]          st_keeps[0:255];
   reg [TDEST_BITS-1:0]  st_dests[0:255];
   reg [CTX_ID_BITS-1:0] st_users[0:255];
   reg                   st_lasts[0:255];
   reg [7:0]             st_wpos, st_rpos;

   initial begin
      frame_wpos = 'd0;
      frame_ihpos = 'd0;
      frame_ohpos = 'd0;
      frame_ihcpos = 'd0;
      frame_icpos = 'd0;
      frame_ocpos = 'd0;
      frame_idpos = 'd0;
      frame_odpos = 'd0;
      st_wpos = 'd0;
      st_rpos = 'd0;
      in_0_tvalid = 1'b0;
   end

   // in frame header
   always @(posedge clk) begin
      if (~resetn) begin
         in_frame_header_0_tvalid <= 1'b0;
      end else if (~in_frame_header_0_tvalid || in_frame_header_0_tready) begin
         if (frame_ihpos != frame_wpos &&
             (HEADER_V_BITS>0 ? &rd[24+:HEADER_V_BITS_MOD] : 1'b1)) begin
            in_frame_header_0_tdata <= {'d0, frame_idests[frame_ihpos], 8'd0, frame_sizes[frame_ihpos], 64'd0};
            in_frame_header_0_tuser <= frame_iusers[frame_ihpos];
            in_frame_header_0_tvalid <= 1'b1;
            frame_ihpos <= frame_ihpos + 1'b1;
         end else begin
            in_frame_header_0_tvalid <= 1'b0;
         end
      end
   end
   // out frame header
   always @(posedge clk) begin
      if (~resetn) begin
         out_frame_header_0_tvalid <= 1'b0;
      end else if (~out_frame_header_0_tvalid || out_frame_header_0_tready) begin
         if (frame_ohpos != frame_wpos &&
             (HEADER_V_BITS>0 ? &rd[25+:HEADER_V_BITS_MOD] : 1'b1)) begin
            out_frame_header_0_tdata <= {'d0, frame_odests[frame_ohpos], 8'd0, frame_sizes[frame_ohpos], 64'd0};
            out_frame_header_0_tuser <= frame_ousers[frame_ohpos];
            out_frame_header_0_tvalid <= 1'b1;
            frame_ohpos <= frame_ohpos + 1'b1;
         end else begin
            out_frame_header_0_tvalid <= 1'b0;
         end
      end
   end
   // in header consume
   always @(posedge clk) begin
      if (~resetn) begin
         in_frame_header_consume_0_tready <= 1'b0;
      end else begin
         if (in_frame_header_consume_0_tvalid && in_frame_header_consume_0_tready) begin
            if (in_frame_header_consume_0_tuser !== frame_iusers[frame_ihcpos] ||
                in_frame_header_consume_0_tdest !== frame_idests[frame_ihcpos]) begin
               $error("%d: [%2h] %h %h, %h %h", $time, in_frame_header_consume_0_tuser,
                      in_frame_header_consume_0_tuser, frame_iusers[frame_ihcpos],
                      in_frame_header_consume_0_tdest, frame_idests[frame_ihcpos]);
            end
            frame_ihcpos <= frame_ihcpos + 1'b1;
         end
         in_frame_header_consume_0_tready <= CONSUME_R_BITS > 0 ? &rd[15+:CONSUME_R_BITS_MOD] : 1'b1;
      end
   end
   // in frame consume
   always @(posedge clk) begin
      if (~resetn) begin
         in_frame_consume_0_tready <= 1'b1;
      end else begin
         if (in_frame_consume_0_tvalid) begin
            $error("%d: in frame consume", $time);
         end
      end
   end
   // out frame complete
   always @(posedge clk) begin
      if (~resetn) begin
         out_frame_complete_0_tready <= 1'b0;
      end else begin
         if (out_frame_complete_0_tvalid && out_frame_complete_0_tready) begin
            if (out_frame_complete_0_tdata[95:64] !== frame_sizes[frame_ocpos] ||
                out_frame_complete_0_tuser !== frame_ousers[frame_ocpos] ||
                out_frame_complete_0_tdest !== frame_odests[frame_ocpos]) begin
               $error("%d: [%2h] %h %h, %h %h", $time, out_frame_complete_0_tuser,
                      out_frame_complete_0_tdata[95:64], frame_sizes[frame_ocpos],
                      out_frame_complete_0_tuser, frame_ousers[frame_ocpos],
                      out_frame_complete_0_tdest, frame_odests[frame_ocpos]);
            end
            frame_ocpos <= frame_ocpos + 1'b1;
         end
         out_frame_complete_0_tready <= COMP_R_BITS > 0 ? &rd[15+:COMP_R_BITS_MOD] : 1'b1;
      end
   end
   // st check
   always @(posedge clk) begin
      if (~resetn) begin
         out_0_tready <= 1'b0;
      end else begin
         if (out_0_tvalid && out_0_tready) begin
            if (out_0_tdata !== st_data[st_rpos] ||
                out_0_tkeep !== st_keeps[st_rpos] ||
                out_0_tuser !== st_users[st_rpos] ||
                out_0_tdest !== st_dests[st_rpos] ||
                out_0_tlast !== st_lasts[st_rpos]) begin
               $error("%d: [%2h] %h %h, %h %h, %h %h, %h %h, %h %h", $time, out_0_tuser,
                      out_0_tdata, st_data[st_rpos], out_0_tkeep, st_keeps[st_rpos],
                      out_0_tuser, st_users[st_rpos], out_0_tdest, st_dests[st_rpos],
                      out_0_tlast, st_lasts[st_rpos]);
            end
            if (out_0_tlast) begin
               frame_odpos <= frame_odpos + 1'b1;
            end
            st_rpos <= st_rpos + 1'b1;
         end
         out_0_tready <= OUT_ST_BITS > 0 ? &rd[17+:OUT_ST_BITS_MOD] : 1'b1;
      end
   end

   task static generate_frames;
      int frame_num = 0;
      logic [31:0] size;
      logic [TDEST_BITS-1:0] idest, odest;
      logic [CTX_ID_BITS-1:0] iuser, ouser;
      logic                   valid = 0;
      logic [7:0]             wpos_next;

      while (frame_num < FRAME_NUM || valid) @(posedge clk) begin
         wpos_next = frame_wpos + 1'b1;
         if (wpos_next != frame_ihpos && wpos_next != frame_ohpos && wpos_next != frame_ihcpos &&
             /*wpos_next != frame_icpos && */wpos_next != frame_ocpos && wpos_next != frame_idpos && wpos_next != frame_odpos) begin
            valid = FRAME_BITS > 0 ? &rd[3+:FRAME_BITS_MOD] : 1'b1;
            valid = valid && frame_num < FRAME_NUM;
            if (valid) begin
               idest = rd[10+:TDEST_BITS];
               odest = rd[12+:TDEST_BITS];
               iuser = rd[14+:TDEST_BITS];
               ouser = rd[16+:TDEST_BITS];
               size = rd & {'d0, {SIZE_BITS{1'b1}}};
               frame_sizes[frame_wpos] <= size;
               frame_idests[frame_wpos] <= idest;
               frame_odests[frame_wpos] <= odest;
               frame_iusers[frame_wpos] <= iuser;
               frame_ousers[frame_wpos] <= ouser;
               frame_wpos <= wpos_next;
               frame_num++;
            end
         end else begin
            valid = 0;
         end
      end
   endtask

   task static generate_stream_data;
      int frame_num = 0;
      logic [31:0] size = 0;
      logic [TDEST_BITS-1:0] odest;
      logic [CTX_ID_BITS-1:0] iuser;
      logic [CTX_ID_BITS-1:0] ouser;
      logic                   valid;
      logic [DW-1:0]          data;
      logic [KW-1:0]          keep;
      logic                   last;
      logic                   eof;

      while (frame_num < FRAME_NUM || in_0_tvalid || valid) @(posedge clk) begin
         if (frame_wpos !== frame_idpos && ~|size) begin
            size = frame_sizes[frame_idpos];
            odest = frame_odests[frame_idpos];
            iuser = frame_iusers[frame_idpos];
            ouser = frame_ousers[frame_idpos];
            frame_idpos <= frame_idpos + 1'b1;
         end
         if (~in_0_tvalid || in_0_tready) begin
            valid = |size && (IN_ST_BITS > 0 ? &rd[19+:IN_ST_BITS_MOD] : 1'b1);
            valid = valid && ((st_wpos + 1) & 255) != st_rpos;
            last = rd[24];
            eof = size <= KW;
            for (int i=0; i<KW; i++) begin
               data[i*8+:8] = ~eof || i < size ? rd[(i&3)*8+:8] ^ (64'hdeadbeeff00baa01 >> i) : 8'd0;
               keep[i] = ~eof || i< size ? 1'b1 : 1'b0;
            end
            in_0_tvalid <= valid;
            if (valid) begin
               in_0_tdata <= data;
               in_0_tkeep <= keep;
               in_0_tuser <= iuser;
               in_0_tlast <= last | eof;
               in_0_tid <= eof;
               st_data[st_wpos] <= data;
               st_keeps[st_wpos] <= keep;
               st_users[st_wpos] <= ouser;
               st_dests[st_wpos] <= odest;
               st_lasts[st_wpos] <= eof;
               st_wpos <= st_wpos + 1'b1;
               if (eof) begin
                  size = 'd0;
                  frame_num++;
               end else begin
                  size = size - KW;
               end
            end
         end else begin
            valid = 0;
         end
      end
   endtask

   initial begin
      @(posedge clk);
      while (~resetn) @(posedge clk);

      fork
         generate_frames;
         generate_stream_data;
      join

      while (st_wpos !== st_rpos ||
             frame_wpos !== frame_ocpos ||
             frame_wpos !== frame_ihcpos ||
             frame_wpos !== frame_odpos) @(posedge clk);

      $finish;
   end

endmodule

module test_nop_function_wrapper_fast;
   tb_function_ctrl_nop_wrapper tb ();
endmodule

module test_nop_function_wrapper_random;
   tb_function_ctrl_nop_wrapper #(
       .IN_ST_BITS ( 1 ),
       .OUT_ST_BITS ( 1 ),
       .HEADER_V_BITS ( 4 ),
       .HEADER_R_BITS ( 4 ),
       .CONSUME_R_BITS ( 4 ),
       .COMP_R_BITS ( 4 )
   ) tb ();
endmodule

module test_nop_function_wrapper_slow_out;
   tb_function_ctrl_nop_wrapper #(
       .IN_ST_BITS ( 0 ),
       .OUT_ST_BITS ( 2 ),
       .HEADER_V_BITS ( 4 ),
       .HEADER_R_BITS ( 6 ),
       .CONSUME_R_BITS ( 6 ),
       .COMP_R_BITS ( 6 )
   ) tb ();
endmodule
