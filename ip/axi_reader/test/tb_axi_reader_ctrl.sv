/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_axi_reader_ctrl #(
    parameter DW = 512,
    parameter CTX_ID_BITS = 5,
    parameter ODEST_BITS = 4,
    parameter BURST_MAX_LOG = 4,
    parameter HEADER_FIFO_DL = 2,
    parameter HEADER_OUT_FIFO_DL = 4,
    parameter DATA_FIFO_DL = BURST_MAX_LOG + 2,
    parameter DM_STS_FIFO_DL = 3,
    parameter RR_BITS = 4,
    parameter ENABLE_DATA_BYPASS = 0,
    parameter DM_ADDR_BITS = 40, // ceil to multiple of 8
    parameter ID_BITS = 1,
    parameter OD_BITS = 1,
    parameter DM_CMD_BITS = 1,
    parameter DM_STS_BITS = 4,
    parameter FRAME_COMPLETE_BITS = 1,
    parameter FRAME_CONSUME_BITS = 1,
    parameter FRAME_SIZE_BITS = 13,
    parameter PACKET_END = 0,
    parameter HEADER_MAX = 100,
    parameter IDATA_DELAY = 200,
    parameter SINGLE_CH = 0
    ) ();

   localparam TDEST_BITS = 0;
   localparam ID_BITS_MOD = ID_BITS > 0 ? ID_BITS : 1;
   localparam OD_BITS_MOD = OD_BITS > 0 ? OD_BITS : 1;
   localparam DM_CMD_BITS_MOD = DM_CMD_BITS > 0 ? DM_CMD_BITS : 1;
   localparam DM_STS_BITS_MOD = DM_STS_BITS > 0 ? DM_STS_BITS : 1;
   localparam FRAME_COMPLETE_BITS_MOD = FRAME_COMPLETE_BITS > 0 ? FRAME_COMPLETE_BITS : 1;
   localparam FRAME_CONSUME_BITS_MOD = FRAME_CONSUME_BITS > 0 ? FRAME_CONSUME_BITS : 1;

   localparam CH_NUM = 1 << CTX_ID_BITS;
   localparam DW_LOG = $clog2(DW);
   localparam KW = DW/8;
   localparam KW_LOG = DW_LOG - 3;
   localparam max_size_log = $clog2(DW/8) + BURST_MAX_LOG;
   localparam min_size_log = $clog2(DW/8);

   reg [DW-1:0]                    idata_tdata;
   reg [KW-1:0]                    idata_tkeep;
   reg                             idata_tlast;
   reg                             idata_tvalid;
   wire                            idata_tready;

   wire [DW-1:0]                   odata_tdata;
   wire [KW-1:0]                   odata_tkeep;
   wire [CTX_ID_BITS-1:0]          odata_tuser;
   wire [ODEST_BITS-1:0]           odata_tdest;
   wire                            odata_tlast;
   wire                            odata_tvalid;
   reg                             odata_tready;

   wire [DM_ADDR_BITS+39:0]        dm_cmd_tdata;
   wire                            dm_cmd_tvalid;
   reg                             dm_cmd_tready;
   reg [7:0]                       dm_sts_tdata;
   reg                             dm_sts_tvalid;
   wire                            dm_sts_tready;

   reg [127:0]                     frame_complete_tdata;
   reg [CTX_ID_BITS-1:0]           frame_complete_tuser;
   reg                             frame_complete_tvalid;
   wire                            frame_complete_tready;

   wire [127:0]                    frame_complete_consume_tdata;
   wire [CTX_ID_BITS-1:0]          frame_complete_consume_tuser;
   wire [ODEST_BITS-1:0]           frame_complete_consume_tdest;
   wire                            frame_complete_consume_tvalid;
   reg                             frame_complete_consume_tready;

   wire [7:0]                      frame_consume_tdata;
   wire [CTX_ID_BITS-1:0]          frame_consume_tuser;
   wire [ODEST_BITS-1:0]           frame_consume_tdest;
   wire                            frame_consume_tvalid;
   reg                             frame_consume_tready;

   wire [3:0]                      errors;
   wire [CH_NUM-1:0]               underflows;

   wire                            clk;
   wire                            resetn;
   wire [31:0]                     rd;

   clk_reset clk_reset (
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
   );

   axi_reader_ctrl #(
       .DW ( DW ),
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .BURST_MAX_LOG ( BURST_MAX_LOG ),
       .HEADER_FIFO_DL ( HEADER_FIFO_DL ),
       .HEADER_OUT_FIFO_DL ( HEADER_OUT_FIFO_DL ),
       .DATA_FIFO_DL ( DATA_FIFO_DL ),
       .RR_BITS ( RR_BITS ),
       .DM_STS_FIFO_DL ( DM_STS_FIFO_DL ),
       .DM_ADDR_BITS ( DM_ADDR_BITS ),
       .ODEST_BITS ( ODEST_BITS )
   ) dut (
       .*
   );

   initial begin
      idata_tvalid = 1'b0;
      odata_tready = 1'b1;
      dm_cmd_tready = 1'b1;
      dm_sts_tvalid = 1'b0;
      frame_complete_tvalid = 1'b0;
      frame_consume_tready = 1'b1;
   end

   reg [127:0] header_data[0:CH_NUM-1][0:255];
   reg [7:0]            header_wpos[0:CH_NUM-1];
   reg [7:0]            header_epos[0:CH_NUM-1];
   reg [7:0]            header_cpos[0:CH_NUM-1];
   reg [7:0]            header_rpos[0:CH_NUM-1];

   reg [DM_ADDR_BITS-1:0] read_addrs[0:255];
   reg [22:0]             read_sizes[0:255];
   reg [CTX_ID_BITS-1:0]  read_chs[0:255];
   reg [ODEST_BITS-1:0]   read_dests[0:255];
   reg                    read_lasts[0:255];
   reg [7:0]              read_wpos, read_epos, read_cpos, read_rpos;

   reg [DW-1:0]           data_saved[0:255];
   reg [KW-1:0]           keep_saved[0:255];
   reg [CTX_ID_BITS-1:0]  user_saved[0:255];
   reg [ODEST_BITS-1:0]   dest_saved[0:255];
   reg                    last_saved[0:255];
   reg [7:0]              data_wpos, data_rpos;

   initial begin
      for (int i=0; i<CH_NUM; i++) begin
         header_wpos[i] = 0;
         header_epos[i] = 0;
         header_cpos[i] = 0;
         header_rpos[i] = 0;
      end
      read_wpos = 0;
      read_epos = 0;
      read_cpos = 0;
      read_rpos = 0;
      data_wpos = 0;
      data_rpos = 0;
   end

   // header_out check
   always @(posedge clk) begin
      if (resetn) begin
         if (frame_consume_tvalid && frame_consume_tready) begin
            if (frame_consume_tdata !== header_data[frame_consume_tuser][header_rpos[frame_consume_tuser]][96+:8]) begin
               $error("%d [%2h]: header %h %h (%h, %h)", $time, frame_consume_tuser,
                      frame_consume_tdata, header_data[frame_consume_tuser][header_rpos[frame_consume_tuser]][96+:8],
                      header_rpos[frame_consume_tuser], header_wpos[frame_consume_tuser]);
            end else begin
               $display("%d [%2h]: header %h %h (%h, %h)", $time, frame_consume_tuser,
                        frame_consume_tdata, header_data[frame_consume_tuser][header_rpos[frame_consume_tuser]][96+:8],
                        header_rpos[frame_consume_tuser], header_wpos[frame_consume_tuser]);
            end
            header_rpos[frame_consume_tuser] <= header_rpos[frame_consume_tuser] + 1'b1;
         end
         frame_consume_tready <= FRAME_CONSUME_BITS > 0 ? &rd[6+:FRAME_CONSUME_BITS_MOD] : 1'b1;
      end
   end

   // complete consume check
   always @(posedge clk) begin
      if (resetn) begin
         if (frame_complete_consume_tvalid && frame_complete_consume_tready) begin
            if (!(header_wpos[frame_complete_consume_tuser] !== header_cpos[frame_complete_consume_tuser])) begin
               $error("%d [%2h]: header complete consume overrun(%3d, %3d)", $time, frame_complete_consume_tuser,
                      header_cpos[frame_complete_consume_tuser], header_epos[frame_complete_consume_tuser]);
            end
            if (frame_complete_consume_tdata !== header_data[frame_complete_consume_tuser][header_cpos[frame_complete_consume_tuser]] ||
                frame_complete_consume_tdest !== header_data[frame_complete_consume_tuser][header_cpos[frame_complete_consume_tuser]][104+:ODEST_BITS]) begin
               $error("%d [%2h]: header complete consume: %h %h, %h %h", $time, frame_complete_consume_tuser,
                      frame_complete_consume_tdata, header_data[frame_complete_consume_tuser][header_cpos[frame_complete_consume_tuser]],
                      frame_complete_consume_tdest, header_data[frame_complete_consume_tuser][header_cpos[frame_complete_consume_tuser]][104+:ODEST_BITS]);
            end
            header_cpos[frame_complete_consume_tuser] <= header_cpos[frame_complete_consume_tuser] + 1'b1;
         end
         frame_complete_consume_tready <= FRAME_CONSUME_BITS > 0 ? &rd[10+:FRAME_CONSUME_BITS_MOD] : 1'b1;
      end
   end

   // data check
   always @(posedge clk) begin
      if (resetn) begin
         if (odata_tvalid && odata_tready) begin
            if (odata_tdata !== data_saved[data_rpos] ||
                odata_tkeep !== keep_saved[data_rpos] ||
                odata_tuser !== user_saved[data_rpos] ||
                odata_tdest !== dest_saved[data_rpos] ||
                odata_tlast !== last_saved[data_rpos]) begin
               $error("%d [%2h]: data %h %h, %h %h, %h %h, %h %h, %h %h", $time, odata_tuser,
                      odata_tdata, data_saved[data_rpos], odata_tkeep, keep_saved[data_rpos],
                      odata_tuser, user_saved[data_rpos], odata_tdest, dest_saved[data_rpos], odata_tlast, last_saved[data_rpos]);
            end
            data_rpos <= data_rpos + 1'b1;
         end
         odata_tready <= OD_BITS > 0 ? &rd[9+:OD_BITS_MOD] : 1'b1;
      end
   end

   // errors
   reg [3:0] errors_prev;
   always @(posedge clk) begin
      if (~resetn) begin
         errors_prev <= 'd0;
      end else begin
         errors_prev <= errors;
         if (|(errors & errors_prev)) #10 $fatal(2, "%d : errors: %h underflow: %h", $time, errors, underflows);
      end
   end

   task static header_generation;
      int header_count = 0;
      logic [CTX_ID_BITS-1:0] ch;
      logic [63:0]            addr;
      logic [7:0]             frame_id;
      logic [FRAME_SIZE_BITS-1:0] size;
      logic                       valid = 0;
      while (header_count < HEADER_MAX || frame_complete_tvalid || valid) @(posedge clk) begin
         valid = (FRAME_COMPLETE_BITS > 0 ? &rd[4+:FRAME_COMPLETE_BITS_MOD] : 1'b1) &&
                 (~frame_complete_tvalid || (frame_complete_tready && header_count < HEADER_MAX-1)) && header_count < HEADER_MAX;
                 ch = SINGLE_CH == 0 ? rd[8+:CTX_ID_BITS] : SINGLE_CH;
         valid = valid && ((header_wpos[ch] + 1) & 255) !== header_rpos[ch];
         if (valid) begin
            addr = {rd, rd} << $clog2(DW/8);
            size = rd;
            frame_id = rd >> 16;
            if (~|size) valid = 1'b0;
            frame_complete_tvalid <= valid;
            if (valid) begin
               frame_complete_tuser <= ch;
               frame_complete_tdata <= {24'd0, frame_id, {32-FRAME_SIZE_BITS{1'b0}}, size, addr};
            end else begin
               frame_complete_tvalid <= frame_complete_tvalid & ~frame_complete_tready;
            end
         end else begin
            frame_complete_tvalid <= frame_complete_tvalid & ~frame_complete_tready;
         end
         if (frame_complete_tvalid & frame_complete_tready) begin
            header_data[frame_complete_tuser][header_wpos[frame_complete_tuser]] <= frame_complete_tdata;
            header_wpos[frame_complete_tuser] <= header_wpos[frame_complete_tuser] + 1'b1;
            header_count++;
         end
      end
      $display("header_generation end");
   endtask

   task static dm_cmd_checker;
      int dm_header_count = 0;
      logic [CTX_ID_BITS-1:0] ch;
      logic [63:0]            addrs[0:CH_NUM-1];
      logic [31:0]            sizes[0:CH_NUM-1];
      logic [ODEST_BITS-1:0]  dests[0:CH_NUM-1];
      logic [22:0]            size;
      logic                   last;
      logic [ODEST_BITS-1:0]  dest;
      for (int i=0; i<CH_NUM; i++) begin
         addrs[i] = 0;
         sizes[i] = 0;
         dests[i] = 0;
      end
      ch = 0;
      while (dm_header_count < HEADER_MAX) @(posedge clk) begin
         for (int i=0; i<CH_NUM; i++) begin
            if (~|sizes[i] && header_epos[i] != header_wpos[i]) begin
               addrs[i] = header_data[i][header_epos[i]][63:0];
               sizes[i] = header_data[i][header_epos[i]][95:64];
               dests[i] = header_data[i][header_epos[i]][104+:ODEST_BITS];
               header_epos[i]++;
            end
         end
         if (dm_cmd_tvalid && dm_cmd_tready) begin
            size = 0;
            for (int i=0; i<CH_NUM; i++) begin
               if (dm_cmd_tdata[32+:DM_ADDR_BITS] == addrs[i][DM_ADDR_BITS-1:0]) begin
                  size = dm_cmd_tdata[22:0];
                  last = dm_cmd_tdata[30];
                  ch = i;
                  break;
               end
            end
            if (|size) begin
               if (sizes[ch] == size ^ last) begin
                  $error("%d [%2h]: dm last is wrong %h %h %h", $time, ch,
                         dm_cmd_tdata, addrs[ch], sizes[ch]);
               end
               read_addrs[read_wpos] <= dm_cmd_tdata[32+:DM_ADDR_BITS];
               read_sizes[read_wpos] <= size;
               read_dests[read_wpos] <= dests[ch];
               read_chs[read_wpos] <= ch;
               read_lasts[read_wpos] <= last;
               read_wpos <= read_wpos + 1'b1;
               addrs[ch] = addrs[ch] + size;
               sizes[ch] = sizes[ch] - size;
               if (~|sizes[ch]) begin
                  dm_header_count++;
               end
            end else begin
               for (int i=0; i<CH_NUM; i++) begin
                  $display("dm_cmd_addr[%2h]: %h %h, %h", i, dm_cmd_tdata[32+:DM_ADDR_BITS], addrs[i][DM_ADDR_BITS-1:0], dm_cmd_tdata[22:0]);
               end
               #100 $fatal(2, "no channel found");
            end
         end
      end
      $display("dm_cmd_checker end");
   endtask

   task static dm_sts_generation;
      int dm_sts_count = 0;
      int dm_sts_out_count = 0;
      logic [22:0] size = 0;
      logic [CTX_ID_BITS-1:0] ch;
      logic [22:0] cur_size[0:255];
      logic [CTX_ID_BITS-1:0] cur_chs[0:255];
      logic        dm_sts_last;
      logic        last[0:255];
      logic        valid;
      logic [7:0]             cur_size_wpos = 0;
      logic [7:0]             cur_size_rpos = 0;
      logic [31:0]            cmd_count = 0;
      logic [15:0]            dm_cont_num = 0;
      logic [15:0]            dm_cont_num_save = 0;
      for (int i=0; i<256; i++) begin
         cur_size[i] = 0;
         last[i] = 0;
      end
      while (dm_sts_count < HEADER_MAX || dm_sts_out_count < HEADER_MAX || valid || dm_sts_tvalid) @(posedge clk) begin
         if (|size && cur_size[cur_size_wpos] == size) begin
            if (cur_chs[cur_size_wpos] != ch) begin
               $error("%d [%2h]: sts ch wrong: %h %h, %h %h", $time, ch, cur_size[cur_size_wpos], size, cur_chs[cur_size_wpos], ch);
            end
            cur_size[cur_size_wpos] = 0;
            cur_size_wpos++;
            cmd_count++;
            size = 0;
         end
         valid = (DM_STS_BITS > 0 ? &rd[18+:DM_STS_BITS_MOD] : 1'b1) && cur_size_wpos != cur_size_rpos;
         if (valid && (~dm_sts_tvalid || dm_sts_tready)) begin
            dm_sts_tdata <= 8'h80;
            dm_sts_tvalid <= 1'b1;
            if (last[cur_size_rpos]) begin
               dm_sts_count++;
            end
            dm_sts_last <= last[cur_size_rpos];
            cur_size_rpos <= cur_size_rpos + 1'b1;
         end else begin
            dm_sts_tvalid <= dm_sts_tvalid & ~dm_sts_tready;
         end
         if (dm_sts_tvalid && dm_sts_tready) begin
            if (dm_sts_last) begin
               dm_cont_num_save <= dm_cont_num + 1'b1;
               dm_cont_num <= 'd0;
               dm_sts_out_count++;
            end else begin
               dm_cont_num <= dm_cont_num + 1'b1;
            end
         end
         if (~|size && read_wpos != read_cpos) begin
            size = read_sizes[read_cpos];
            ch = read_chs[read_cpos];
            last[cur_size_wpos] = read_lasts[read_cpos];
            read_cpos <= read_cpos + 1'b1;
         end
         if (odata_tvalid & odata_tready) begin
            if (~|cur_size[cur_size_wpos] || cur_chs[cur_size_wpos] == odata_tuser) begin
               for (int i=0; i<KW; i++) cur_size[cur_size_wpos] += odata_tkeep[i];
               cur_chs[cur_size_wpos] = odata_tuser;
            end else begin
               $error("%d [%2h]: sts size wrong: %h ch: %h %h", $time, cur_chs[cur_size_wpos], cur_size[cur_size_wpos], odata_tuser, cur_chs[cur_size_wpos]);
            end
         end
      end
      $display("dm_sts_generation end");
   endtask

   task static data_generation;
      logic [22:0] size = 0;
      logic [CTX_ID_BITS-1:0] ch;
      logic [ODEST_BITS-1:0]  dest;
      logic                   last;
      logic                   valid;
      logic [DW-1:0]          data;
      logic [KW-1:0]          keep;
      int                     data_header_count = 0;
      int                     delay_count = 0;
      while (data_header_count < HEADER_MAX || |size || valid || idata_tvalid) @(posedge clk) begin
         if (~|size && read_wpos !== read_epos && delay_count >= IDATA_DELAY) begin
            size = read_sizes[read_epos];
            ch = read_chs[read_epos];
            last = read_lasts[read_epos];
            dest = read_dests[read_epos];
            read_epos <= read_epos + 1'b1;
         end
         if (delay_count < IDATA_DELAY) delay_count++;
         valid = ID_BITS > 0 ? &rd[18+:ID_BITS_MOD] : 1'b1;
         valid = valid & |size;
         if (~|size) begin
            idata_tvalid <= idata_tvalid & ~idata_tready;
            continue;
         end
         if (valid && (~idata_tvalid || idata_tready)) begin
            for (int i=0; i<DW; i+=8) begin
               keep[i/8] = size > i/8 ? 1'b1 : 1'b0;
               data[i+:8] = keep[i/8] ? (rd >> (i&31)) ^ (32'h2001 << (i/32)) ^ (i/64) : 8'd0;
            end
            size = size < KW ? 0 : size - KW;
            if (~|size && last) data_header_count++;
            idata_tdata <= data;
            idata_tkeep <= keep;
            idata_tlast <= ~|size && last;
            idata_tvalid <= 1'b1;
            data_saved[data_wpos] <= data;
            keep_saved[data_wpos] <= keep;
            user_saved[data_wpos] <= ch;
            dest_saved[data_wpos] <= dest;
            last_saved[data_wpos] <= ~|size && last;
            data_wpos <= data_wpos + 1'b1;
         end else begin
            idata_tvalid <= idata_tvalid & ~idata_tready;
         end
      end
      $display("data_generation end");
   endtask

   initial begin
      @(posedge clk);
      while (~resetn) @(posedge clk);

      fork
         begin
            header_generation;
         end
         begin
            dm_cmd_checker;
         end
         begin
            dm_sts_generation;
         end
         begin
            data_generation;
         end
      join

      $finish();
   end

endmodule

module test_axi_reader_ctrl_fast;

   tb_axi_reader_ctrl #(
       .DM_CMD_BITS ( 0 ),
       .DM_STS_BITS ( 0 ),
       .ID_BITS ( 0 ),
       .OD_BITS ( 0 ),
       .FRAME_COMPLETE_BITS ( 0 ),
       .FRAME_CONSUME_BITS ( 0 )
   ) tb ();

endmodule

module test_axi_reader_ctrl_random;

   tb_axi_reader_ctrl tb ();

endmodule

module test_axi_reader_ctrl_random_slow_ctrl_in;

   tb_axi_reader_ctrl #(
       .FRAME_COMPLETE_BITS ( 3 )
   ) tb ();

endmodule

module test_axi_reader_ctrl_random_slow_ctrl_out;

   tb_axi_reader_ctrl #(
       .FRAME_CONSUME_BITS ( 3 )
   ) tb ();

endmodule

module test_axi_reader_ctrl_fast_1ch;

   tb_axi_reader_ctrl #(
       .DM_CMD_BITS ( 0 ),
       .DM_STS_BITS ( 0 ),
       .ID_BITS ( 0 ),
       .OD_BITS ( 0 ),
       .FRAME_COMPLETE_BITS ( 0 ),
       .FRAME_CONSUME_BITS ( 0 ),
       .SINGLE_CH ( 4 )
   ) tb ();

endmodule

module test_axi_reader_ctrl_random_1ch;

   tb_axi_reader_ctrl #(
       .SINGLE_CH ( 4 )
   ) tb ();

endmodule
