/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_axi_writer_ctrl #(
    parameter DW = 512,
    parameter CTX_ID_BITS = 5,
    parameter BURST_MAX_LOG = 4,
    parameter HEADER_FIFO_DL = 2,
    parameter HEADER_OUT_FIFO_DL = 4,
    parameter DATA_FIFO_DL = BURST_MAX_LOG + 2,
    parameter DM_STS_FIFO_DL = 5,
    parameter IDEST_BITS = 4,
    parameter DM_ADDR_BITS = 40, // ceil to multiple of 8
    parameter ID_BITS = 1,
    parameter OD_BITS = 1,
    parameter DM_CMD_BITS = 1,
    parameter DM_STS_BITS = 1,
    parameter FRAME_HEADER_I_BITS = 1,
    parameter FRAME_HEADER_O_BITS = 1,
    parameter FRAME_SIZE_BITS = 13,
    parameter PACKET_END = 0,
    parameter HEADER_MAX = 100,
    parameter SINGLE_CH = 0
    ) ();

   localparam ID_BITS_MOD = ID_BITS > 0 ? ID_BITS : 1;
   localparam OD_BITS_MOD = OD_BITS > 0 ? OD_BITS : 1;
   localparam DM_CMD_BITS_MOD = DM_CMD_BITS > 0 ? DM_CMD_BITS : 1;
   localparam DM_STS_BITS_MOD = DM_STS_BITS > 0 ? DM_STS_BITS : 1;
   localparam FRAME_HEADER_I_BITS_MOD = FRAME_HEADER_I_BITS > 0 ? FRAME_HEADER_I_BITS : 1;
   localparam FRAME_HEADER_O_BITS_MOD = FRAME_HEADER_O_BITS > 0 ? FRAME_HEADER_O_BITS : 1;

   localparam CH_NUM = 1 << CTX_ID_BITS;
   localparam DW_LOG = $clog2(DW);
   localparam KW = DW/8;
   localparam max_size_log = $clog2(DW/8) + BURST_MAX_LOG;
   localparam min_size_log = $clog2(DW/8);

   reg [DW-1:0]                    idata_tdata;
   reg [KW-1:0]                    idata_tkeep;
   reg [CTX_ID_BITS-1:0]           idata_tuser;
   reg                             idata_tlast;
   reg                             idata_tvalid;
   wire                            idata_tready;

   wire [DW-1:0]                   odata_tdata;
   wire [KW-1:0]                   odata_tkeep;
   wire [CTX_ID_BITS-1:0]          odata_tuser;
   wire                            odata_tlast;
   wire                            odata_tvalid;
   reg                             odata_tready;

   wire [DM_ADDR_BITS+39:0]        dm_cmd_tdata;
   wire                            dm_cmd_tvalid;
   reg                             dm_cmd_tready;
   reg [7:0]                       dm_sts_tdata;
   reg                             dm_sts_tvalid;
   wire                            dm_sts_tready;

   reg [127:0]                     frame_header_tdata;
   reg [CTX_ID_BITS-1:0]           frame_header_tuser;
   reg [IDEST_BITS-1:0]            frame_header_tdest;
   reg                             frame_header_tvalid;
   wire                            frame_header_tready;

   wire [127:0]                    frame_header_out_tdata;
   wire [CTX_ID_BITS-1:0]          frame_header_out_tuser;
   wire [IDEST_BITS-1:0]           frame_header_out_tdest;
   wire                            frame_header_out_tvalid;
   reg                             frame_header_out_tready;

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

   axi_writer_ctrl #(
       .DW ( DW ),
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .BURST_MAX_LOG ( BURST_MAX_LOG ),
       .HEADER_FIFO_DL ( HEADER_FIFO_DL ),
       .HEADER_OUT_FIFO_DL ( HEADER_OUT_FIFO_DL ),
       .DATA_FIFO_DL ( DATA_FIFO_DL ),
       .DM_STS_FIFO_DL ( DM_STS_FIFO_DL ),
       .IDEST_BITS ( IDEST_BITS ),
       .DM_ADDR_BITS ( DM_ADDR_BITS )
   ) dut (
       .*
   );

   initial begin
      idata_tvalid = 1'b0;
      odata_tready = 1'b1;
      dm_cmd_tready = 1'b1;
      dm_sts_tvalid = 1'b0;
      frame_header_tvalid = 1'b0;
      //frame_header_consume_tready = 1'b1;
      frame_header_out_tready = 1'b1;
   end

   reg [127:0] header_data[0:CH_NUM-1][0:255];
   reg [IDEST_BITS-1:0] header_dest[0:CH_NUM-1][0:255];
   reg [7:0]            header_wpos[0:CH_NUM-1];
   reg [7:0]            header_epos[0:CH_NUM-1];
   reg [7:0]            header_cpos[0:CH_NUM-1];
   reg [7:0]            header_rpos[0:CH_NUM-1];

   reg [DM_ADDR_BITS-1:0] write_addrs[0:255];
   reg [22:0] write_sizes[0:255];
   reg [CTX_ID_BITS-1:0] write_chs[0:255];
   reg                   write_lasts[0:255];
   reg [7:0]  write_wpos, write_epos, write_cpos, write_rpos;

   reg [DW-1:0] data_saved[0:255];
   reg [KW-1:0] keep_saved[0:255];
   reg [CTX_ID_BITS-1:0] user_saved[0:255];
   reg                   last_saved[0:255];
   reg [7:0]             data_wpos, data_rpos;

   initial begin
      for (int i=0; i<CH_NUM; i++) begin
         header_wpos[i] = 0;
         header_epos[i] = 0;
         header_cpos[i] = 0;
         header_rpos[i] = 0;
      end
      write_wpos = 0;
      write_epos = 0;
      write_cpos = 0;
      write_rpos = 0;
      data_wpos = 0;
      data_rpos = 0;
   end

   // header_out check
   always @(posedge clk) begin
      if (resetn) begin
         if (frame_header_out_tvalid && frame_header_out_tready) begin
            if (frame_header_out_tdata !== header_data[frame_header_out_tuser][header_rpos[frame_header_out_tuser]] ||
                frame_header_out_tdest !== header_dest[frame_header_out_tuser][header_rpos[frame_header_out_tuser]]) begin
               $error("%d [%2h]: header %h %h, %h %h", $time, frame_header_tuser,
                      frame_header_out_tdata, header_data[frame_header_out_tuser][header_rpos[frame_header_out_tuser]],
                      frame_header_out_tdest, header_dest[frame_header_out_tuser][header_rpos[frame_header_out_tuser]]);
            end
            header_rpos[frame_header_out_tuser] <= header_rpos[frame_header_out_tuser] + 1'b1;
         end
         frame_header_out_tready <= FRAME_HEADER_O_BITS > 0 ? &rd[6+:FRAME_HEADER_O_BITS_MOD] : 1'b1;
      end
   end

`ifdef _OLD
   // header consume check
   always @(posedge clk) begin
      if (resetn) begin
         if (frame_header_consume_tvalid && frame_header_consume_tready) begin
            if (!(header_wpos[frame_header_consume_tuser] !== header_cpos[frame_header_consume_tuser])) begin
               $error("%d [%2h]: header consume overrun(%3d, %3d)", $time, frame_header_consume_tuser,
                      header_cpos[frame_header_consume_tuser], header_epos[frame_header_consume_tuser]);
            end
            header_cpos[frame_header_consume_tuser] <= header_cpos[frame_header_consume_tuser] + 1'b1;
         end
         frame_header_consume_tready <= FRAME_HEADER_O_BITS > 0 ? &rd[10+:FRAME_HEADER_O_BITS_MOD] : 1'b1;
      end
   end
`endif

   // dm_cmd
   reg [22:0] dm_wait_counts[0:7];
   reg [2:0] dm_wait_head, dm_wait_tail;
   logic [2:0] dm_wait_pos;
   logic [15:0] out_data_count;
   always @(posedge clk) begin
      if (~resetn) begin
         for (int i=0; i<8; i++) dm_wait_counts[i] <= 'd0;
         dm_wait_head <= 'd0;
         out_data_count <= 'd0;
      end else begin
         // dm cmd
         if (dm_cmd_tvalid && dm_cmd_tready) begin
            if (dm_cmd_tdata[32+:DM_ADDR_BITS] !== write_addrs[write_rpos] ||
                dm_cmd_tdata[22:0] !== write_sizes[write_rpos]) begin
               $error("%d [%2h]: dm_cmd %h %h, %h %h (%h)", $time, write_chs[write_rpos],
                      dm_cmd_tdata[32+:DM_ADDR_BITS], write_addrs[write_rpos],
                      dm_cmd_tdata[22:0], write_sizes[write_rpos], dm_cmd_tdata);
            end
            write_rpos <= write_rpos + 1'b1;
            dm_wait_counts[dm_wait_head] <= 'd0 | dm_cmd_tdata[22:$clog2(DW/8)];
            dm_wait_head <= dm_wait_head + 1'b1;
         end
         if (odata_tvalid && odata_tready) begin
            out_data_count++;
         end
         if (|out_data_count) begin
            for (dm_wait_pos = dm_wait_tail; dm_wait_pos !== dm_wait_head; dm_wait_pos++) begin
               if (|dm_wait_counts[dm_wait_pos]) begin
                  dm_wait_counts[dm_wait_pos] <= dm_wait_counts[dm_wait_pos] - 1'b1;
                  out_data_count--;
                  break;
               end
            end
         end
         dm_cmd_tready <= (DM_CMD_BITS > 0 ? &rd[13+:DM_CMD_BITS_MOD] : 1'b1) &&
                          ((dm_wait_head + 1'b1) & 3'd7) !== dm_wait_tail;
      end
   end
   always @(posedge clk) begin
      if (~resetn) begin
         dm_wait_tail <= 'd0;
      end else begin
         // dm sts
         if (~|dm_wait_counts[dm_wait_tail] && (DM_STS_BITS > 0 ? &rd[20+:DM_STS_BITS_MOD] : 1'b1) &&
             (~dm_sts_tvalid || dm_sts_tready) && dm_wait_head !== dm_wait_tail) begin
            dm_sts_tdata <= 8'h80;
            dm_sts_tvalid <= 1'b1;
            dm_wait_tail <= dm_wait_tail + 1'b1;
         end else begin
            dm_sts_tvalid <= dm_sts_tvalid & ~dm_sts_tready;
         end
      end
   end

   // data check
   always @(posedge clk) begin
      if (resetn) begin
         if (odata_tvalid && odata_tready) begin
            if (odata_tdata !== data_saved[data_rpos] ||
                odata_tkeep !== keep_saved[data_rpos] ||
                odata_tuser !== user_saved[data_rpos] ||
                odata_tlast !== last_saved[data_rpos]) begin
               $error("%d [%2h]: data %h %h, %h %h, %h %h, %h %h", $time, odata_tuser,
                      odata_tdata, data_saved[data_rpos], odata_tkeep, keep_saved[data_rpos],
                      odata_tuser, user_saved[data_rpos], odata_tlast, last_saved[data_rpos]);
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

   logic [8*CH_NUM-1:0] w_header_counts;
   logic [8*CH_NUM-1:0] w_dm_cmd_counts;
   logic [8*CH_NUM-1:0] w_data_counts;
   logic [7:0] data_counts[0:CH_NUM-1];
   initial begin
      for (int i=0; i<CH_NUM; i++) data_counts[i] = 'd0;
   end
   generate
      for (genvar i=0; i<CH_NUM; i++) begin
         assign w_header_counts[i*8+:8] = header_wpos[i];
         assign w_dm_cmd_counts[i*8+:8] = header_epos[i];
         assign w_data_counts[i*8+:8] = data_counts[i];
      end
   endgenerate

   task static header_generation;
      int header_count = 0;
      logic [CTX_ID_BITS-1:0] ch;
      logic [63:0]            addr;
      logic [7:0]             frame_id;
      logic [FRAME_SIZE_BITS-1:0] size;
      logic [IDEST_BITS-1:0]      dest;
      logic                       valid;
      while (header_count < HEADER_MAX || frame_header_tvalid || valid) @(posedge clk) begin
         valid = (FRAME_HEADER_I_BITS > 0 ? &rd[4+:FRAME_HEADER_I_BITS_MOD] : 1'b1) &&
                 (~frame_header_tvalid || frame_header_tready) && header_count < HEADER_MAX;
         if (valid) begin
            ch = SINGLE_CH == 0 ? rd[8+:CTX_ID_BITS] : SINGLE_CH;
            valid = ((header_wpos[ch] + 1) & 255) !== header_rpos[ch];
            addr = {rd, rd} << $clog2(DW/8);
            size = rd; // << $clog2(DW/8);
            dest = rd >> 24;
            frame_id = rd >> 16;
            if (~|size) valid = 1'b0;
            frame_header_tvalid <= valid;
            if (valid) begin
               frame_header_tuser <= ch;
               frame_header_tdest <= dest;
               frame_header_tdata <= {24'd0, frame_id, {32-FRAME_SIZE_BITS{1'b0}}, size, addr};
            end
         end else begin
            frame_header_tvalid <= frame_header_tvalid & ~frame_header_tready;
         end
         if (frame_header_tvalid & frame_header_tready) begin
            header_data[frame_header_tuser][header_wpos[frame_header_tuser]] <= frame_header_tdata;
            header_dest[frame_header_tuser][header_wpos[frame_header_tuser]] <= frame_header_tdest;
            header_wpos[frame_header_tuser] <= header_wpos[frame_header_tuser] + 1'b1;
            header_count++;
         end
      end
   endtask

   task static dm_cmd_generation;
      int dm_header_count = 0;
      logic [CTX_ID_BITS-1:0] ch, cand_ch;
      logic                   valid;
      logic [63:0]            addrs[0:CH_NUM-1];
      logic [FRAME_SIZE_BITS-1:0] sizes[0:CH_NUM-1];
      logic [22:0]                size;
      logic [DM_ADDR_BITS-1:0]    addr;
      for (int i=0; i<CH_NUM; i++) begin
         addrs[i] = 0;
         sizes[i] = 0;
      end
      ch = 0;
      while (dm_header_count < HEADER_MAX) @(posedge clk) begin
         cand_ch = ch;
         while (~|sizes[ch] && header_wpos[cand_ch] == header_epos[cand_ch] && ((cand_ch + 1) % CH_NUM) !== ch) cand_ch++;
         if (~|sizes[cand_ch] && header_wpos[cand_ch] == header_epos[cand_ch]) begin
            ch = ch + 1'b1;
            continue;
         end

         ch = cand_ch;
         if (~|sizes[ch]) begin
            addrs[ch] = header_data[ch][header_epos[ch]][63:0];
            sizes[ch] = header_data[ch][header_epos[ch]][64+:FRAME_SIZE_BITS];
            header_epos[ch] <= header_epos[ch] + 1'b1;
            $display("%d [%2h]: %h %h", $time, ch, addrs[ch], sizes[ch]);
         end

         valid = (DM_CMD_BITS > 0 ? &rd[7+:DM_CMD_BITS_MOD] : 1'b1) && ((write_wpos + 1) & 255) != write_rpos;
         if (PACKET_END==0) begin
            size = 23'd0 | {rd[31:16+max_size_log], {max_size_log{1'b0}}};
         end else begin
            size = 23'd0 | {rd[31:16+min_size_log], {min_size_log{1'b0}}};
         end
         if (size > {23'd1, {max_size_log{1'b0}}}) size = {23'd1, {max_size_log{1'b0}}};
         if (size > sizes[ch]) size = 23'd0 | sizes[ch];
         if (~|size) valid = 1'b0;
         addr = addrs[ch];
         if (valid) begin
            write_addrs[write_wpos] <= addr;
            write_sizes[write_wpos] <= size;
            write_chs[write_wpos] <= ch;
            write_lasts[write_wpos] <= sizes[ch] == size;
            write_wpos <= write_wpos + 1'b1;
            addrs[ch] = addrs[ch] + size;
            sizes[ch] = sizes[ch] - size;
            $display("%d [%2h]: dm set %h %h", $time, ch, addr, size);
            if (~|sizes[ch]) begin
               dm_header_count++;
               ch = ch + 1'b1;
            end
         end
      end
   endtask

   task static data_generation;
      logic [22:0] size = 0;
      logic [CTX_ID_BITS-1:0] ch;
      logic                   last;
      logic                   valid;
      logic [DW-1:0]          data;
      logic [KW-1:0]          keep;
      int                     data_header_count = 0;
      while (data_header_count < HEADER_MAX || |size || idata_tvalid) @(posedge clk) begin
         if (~|size && write_wpos !== write_epos) begin
            size = write_sizes[write_epos];
            ch = write_chs[write_epos];
            last = write_lasts[write_epos];
            write_epos <= write_epos + 1'b1;
         end
         if (~|size) begin
            idata_tvalid <= idata_tvalid & ~idata_tready;
            continue;
         end
         valid = ID_BITS > 0 ? &rd[18+:ID_BITS_MOD] : 1'b1;
         if (valid && (~idata_tvalid || idata_tready)) begin
            for (int i=0; i<DW; i+=8) begin
               keep[i/8] = size > i/8 ? 1'b1 : 1'b0;
               data[i+:8] = keep[i/8] ? (rd >> (i & 31)) ^ (32'h2001 << (i/32)) ^ (i/32) : 32'd0;
            end
            size = size < KW ? 0 : size - KW;
            if (~|size && last) begin
               data_header_count++;
               data_counts[ch]++;
            end
            idata_tdata <= data;
            idata_tkeep <= keep;
            idata_tuser <= ch;
            idata_tlast <= PACKET_END == 0 ? ~|size && last : ~|size;
            idata_tvalid <= 1'b1;
            data_saved[data_wpos] <= data;
            keep_saved[data_wpos] <= keep;
            user_saved[data_wpos] <= ch;
            last_saved[data_wpos] <= 1'b0;
            data_wpos <= data_wpos + 1'b1;
         end else begin
            idata_tvalid <= idata_tvalid & ~idata_tready;
         end
      end
   endtask

   initial begin
      @(posedge clk);
      while (~resetn) @(posedge clk);

      fork
         begin
            header_generation;
         end
         begin
            dm_cmd_generation;
         end
         begin
            data_generation;
         end
      join

      $finish();
   end

endmodule

module test_axi_writer_ctrl_fast;

   tb_axi_writer_ctrl #(
       .DM_CMD_BITS ( 0 ),
       .DM_STS_BITS ( 0 ),
       .ID_BITS ( 0 ),
       .OD_BITS ( 0 ),
       .FRAME_HEADER_I_BITS ( 0 ),
       .FRAME_HEADER_O_BITS ( 0 )
   ) tb ();

endmodule

module test_axi_writer_ctrl_random;

   tb_axi_writer_ctrl tb ();

endmodule

module test_axi_writer_ctrl_random_slow_ctrl_in;

   tb_axi_writer_ctrl #(
       .FRAME_HEADER_I_BITS ( 3 )
   ) tb ();

endmodule

module test_axi_writer_ctrl_random_slow_ctrl_out;

   tb_axi_writer_ctrl #(
       .FRAME_HEADER_O_BITS ( 3 )
   ) tb ();

endmodule

module test_axi_writer_ctrl_random_packet_end;

   tb_axi_writer_ctrl #(
       .PACKET_END ( 1 )
   ) tb ();

endmodule

module test_axi_writer_ctrl_fast_packet_end;

   tb_axi_writer_ctrl #(
       .DM_CMD_BITS ( 0 ),
       .DM_STS_BITS ( 0 ),
       .ID_BITS ( 0 ),
       .OD_BITS ( 0 ),
       .FRAME_HEADER_I_BITS ( 0 ),
       .FRAME_HEADER_O_BITS ( 0 ),
       .PACKET_END ( 1 )
   ) tb ();

endmodule

module test_axi_writer_ctrl_fast_1ch;

   tb_axi_writer_ctrl #(
       .DM_CMD_BITS ( 0 ),
       .DM_STS_BITS ( 0 ),
       .ID_BITS ( 0 ),
       .OD_BITS ( 0 ),
       .FRAME_HEADER_I_BITS ( 0 ),
       .FRAME_HEADER_O_BITS ( 0 ),
       .SINGLE_CH ( 4 )
   ) tb ();

endmodule
