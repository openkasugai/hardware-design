/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_regs #(
    parameter VALUE = 32'h55555555,
    parameter RAND_VALUE = 0,
    parameter TEST_CASE = 0,
    parameter REG_BASE = 16'h1000,
    parameter VP_MAP_NUM_LOG = 4,
    parameter CH_NUM_LOG = 3,
    parameter QEW = 32,
    parameter ENABLE_QUEUE = 1,
    parameter [39:0] D2D_AXI_BASE = 40'h0,
    parameter [31:0] D2D_AXI_RANGE = 32'h4000_0000, // 1GB
    parameter QUEUE_DL = 3,
    parameter REQ_Q_HEAD_VAL = 8'h1,
    parameter REQ_Q_READ_POS_VAL = 8'h2,
    parameter REQ_Q_TAIL_VAL = 8'h3,
    parameter CPL_Q_HEAD_VAL = 8'h4,
    parameter CPL_Q_HEAD_INFLIGHT_VAL = 8'h5,
    parameter CPL_Q_TAIL_VAL = 8'h6,
    parameter CPL_COUNT_VAL = 8'h10,
    parameter CPL_COUNT2_VAL = 8'h11
    ) ();

    wire clk, resetn;
    wire [31:0] rd;
    clk_reset clk_reset(
        .clk ( clk ),
        .resetn ( resetn ),
        .rd ( rd )
    );

    localparam QUEUE_DEPTH = 1 << QUEUE_DL;
    localparam CH_NUM = 1 << CH_NUM_LOG;
    localparam QEW_LOG = $clog2(QEW);
    localparam VPMAP_END = 4 << (CH_NUM_LOG + VP_MAP_NUM_LOG + 3);
    localparam CTRLREG_END = VPMAP_END + (4 << (CH_NUM_LOG + 4));
    localparam QUEUE_START = (CTRLREG_END + 20 + 63) & ~63;
    localparam QUEUE_END = QUEUE_START + CH_NUM * QEW * QUEUE_DEPTH * 2;
    localparam QUEUE_HT_END = QUEUE_END + 16 * CH_NUM;
    localparam REG_END = ENABLE_QUEUE > 0 ? QUEUE_HT_END : CTRLREG_END + 20;

    localparam [7:0] VP_MAP_NUM_LOG_8B = VP_MAP_NUM_LOG;
    localparam [7:0] CH_NUM_LOG_8B = CH_NUM_LOG;
    localparam [31:0] STREAM_ENGINE_IDENTIFIER = 32'h6e457453;

    reg [15:0]           reg_araddr;
    reg                  reg_arvalid;
    wire                 reg_arready;
    wire [31:0]          reg_rdata;
    wire [1:0]           reg_rresp;
    wire                 reg_rvalid;
    reg                  reg_rready;
    reg [15:0]           reg_awaddr;
    reg                  reg_awvalid;
    wire                 reg_awready;
    reg [31:0]           reg_wdata;
    reg                  reg_wvalid;
    wire                 reg_wready;
    wire [1:0]           reg_bresp;
    wire                 reg_bvalid;
    reg                  reg_bready;

    reg [VP_MAP_NUM_LOG+CH_NUM_LOG-1:0] vpmap_conv_addr;
    wire [160:0]                        vpmap_conv_rdata;

    reg [CH_NUM-1:0]           stream_ch_initialized;
    wire [CH_NUM-1:0]          stream_ch_valids;
    wire [CH_NUM-1:0]          stream_ch_pendings;
    wire [CH_NUM*64-1:0]       stream_req_q_bases;
    wire [CH_NUM*64-1:0]       stream_cpl_q_bases;
    wire [CH_NUM*8-1:0]        stream_req_q_depth;
    wire [CH_NUM*8-1:0]        stream_cpl_q_depth;
    wire [CH_NUM*64-1:0]       stream_req_q_head_tails;
    wire [CH_NUM*64-1:0]       stream_cpl_q_head_tails;

    reg [CH_NUM_LOG-1:0]        stream_check_ch;
    reg                         stream_check_done;
    wire [(64<<CH_NUM_LOG)-1:0] stream_doorbell_addrs;
    wire [(1<<CH_NUM_LOG)-1:0]  stream_check_requests;
    wire [(1<<CH_NUM_LOG)-1:0]  stream_ch_check_with_doorbells;
    wire [(1<<CH_NUM_LOG)-1:0]  stream_ch_interrupt_enables;
    wire [(1<<CH_NUM_LOG)-1:0]  stream_ch_d2d_valids;

    wire [15:0]                stream_check_interval;
    wire [CH_NUM_LOG:0]        stream_ch_valid_num;
    wire [CH_NUM_LOG:0]        stream_ch_doorbell_num;

    reg [CH_NUM_LOG-1:0]       stream_req_update_ch; // head update
    reg [31:0]                 stream_req_update_size;
    reg                        stream_req_update;
    reg [CH_NUM_LOG-1:0]       stream_cpl_update_ch; // tail update
    reg                        stream_cpl_update;
    reg [CH_NUM_LOG-1:0]       stream_queue_read_ch;
    reg [QUEUE_DL-1:0]         stream_queue_read_entry;
    reg                        stream_queue_read_valid;
    wire [(QEW<<3)-1:0]        stream_queue_read_data;
    wire                       stream_queue_read_data_valid;

    wire [(8<<CH_NUM_LOG)-1:0] stream_req_q_heads;
    wire [(8<<CH_NUM_LOG)-1:0] stream_req_q_tails;
    wire [(8<<CH_NUM_LOG)-1:0] stream_cpl_q_heads;
    wire [(8<<CH_NUM_LOG)-1:0] stream_cpl_q_tails;

    wire [3:0]                 ctrl_reg_waddr;
    wire [31:0]                ctrl_reg_wdata;
    wire [CH_NUM_LOG-1:0]      ctrl_reg_wch;
    wire                       ctrl_reg_wen;

    wire [CH_NUM-1:0]          head_tail_updates;

    initial begin
        reg_araddr = 16'd0;
        reg_arvalid = 1'b0;
        reg_rready = 1'b0;
        reg_awaddr = 16'd0;
        reg_awvalid = 1'b0;
        reg_wdata = 32'd0;
        reg_wvalid = 1'b0;
        reg_bready = 1'b0;
        vpmap_conv_addr = 'd0;
        stream_ch_initialized = 'd0;
        stream_check_done = 1'b0;
        stream_req_update = 1'b0;
        stream_cpl_update = 1'b0;
        stream_queue_read_valid = 1'b0;
    end

    stream_engine_regs #(
        .REG_BASE ( REG_BASE ),
        .VP_MAP_NUM_LOG ( VP_MAP_NUM_LOG ),
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .QEW_LOG ( QEW_LOG ),
        .ENABLE_QUEUE ( ENABLE_QUEUE ),
        .D2D_AXI_BASE ( D2D_AXI_BASE ),
        .D2D_AXI_RANGE ( D2D_AXI_RANGE ),
        .QUEUE_DL ( QUEUE_DL )
    ) dut (
        .reg_araddr ( reg_araddr ),
        .reg_arvalid ( reg_arvalid ),
        .reg_arready ( reg_arready ),
        .reg_rdata ( reg_rdata ),
        .reg_rresp ( reg_rresp ),
        .reg_rvalid ( reg_rvalid ),
        .reg_rready ( reg_rready ),
        .reg_awaddr ( reg_awaddr ),
        .reg_awvalid ( reg_awvalid ),
        .reg_awready ( reg_awready ),
        .reg_wdata ( reg_wdata ),
        .reg_wvalid ( reg_wvalid ),
        .reg_wready ( reg_wready ),
        .reg_bresp ( reg_bresp ),
        .reg_bvalid ( reg_bvalid ),
        .reg_bready ( reg_bready ),
        .vpmap_conv_addr ( vpmap_conv_addr ),
        .vpmap_conv_rdata ( vpmap_conv_rdata ),
        .stream_ch_valids ( stream_ch_valids ),
        .stream_ch_initialized ( stream_ch_initialized ),
        .stream_ch_pendings ( stream_ch_pendings ),
        .stream_req_q_bases ( stream_req_q_bases ),
        .stream_cpl_q_bases ( stream_cpl_q_bases ),
        .stream_req_q_depth ( stream_req_q_depth ),
        .stream_cpl_q_depth ( stream_cpl_q_depth ),
        .stream_req_q_head_tails ( stream_req_q_head_tails ),
        .stream_cpl_q_head_tails ( stream_cpl_q_head_tails ),
        .stream_check_ch ( stream_check_ch ),
        .stream_check_done ( stream_check_done ),
        .stream_doorbell_addrs ( stream_doorbell_addrs ),
        .stream_check_requests ( stream_check_requests ),
        .stream_ch_check_with_doorbells ( stream_ch_check_with_doorbells ),
        .stream_ch_interrupt_enables ( stream_ch_interrupt_enables ),
        .stream_ch_d2d_valids ( stream_ch_d2d_valids ),
        .stream_check_interval ( stream_check_interval ),
        .stream_ch_valid_num ( stream_ch_valid_num ),
        .stream_ch_doorbell_num ( stream_ch_doorbell_num ),
        .stream_req_update_ch ( stream_req_update_ch ),
        .stream_req_update_size ( stream_req_update_size ),
        .stream_req_update ( stream_req_update ),
        .stream_cpl_update_ch ( stream_cpl_update_ch ),
        .stream_cpl_update ( stream_cpl_update ),
        .stream_queue_read_ch ( stream_queue_read_ch ),
        .stream_queue_read_entry ( stream_queue_read_entry ),
        .stream_queue_read_valid ( stream_queue_read_valid ),
        .stream_queue_read_data ( stream_queue_read_data ),
        .stream_queue_read_data_valid ( stream_queue_read_data_valid ),
        .stream_req_q_heads ( stream_req_q_heads ),
        .stream_req_q_tails ( stream_req_q_tails ),
        .stream_cpl_q_heads ( stream_cpl_q_heads ),
        .stream_cpl_q_tails ( stream_cpl_q_tails ),
        .ctrl_reg_wen ( ctrl_reg_wen ),
        .ctrl_reg_wch ( ctrl_reg_wch ),
        .ctrl_reg_waddr ( ctrl_reg_waddr ),
        .ctrl_reg_wdata ( ctrl_reg_wdata ),
        .i_rc_count ( 32'd12345 ),
        .i_rc_icount ( 32'd67890 ),
        .req_q_head ( {CH_NUM{REQ_Q_HEAD_VAL}} ),
        .req_q_read_pos ( {CH_NUM{REQ_Q_READ_POS_VAL}} ),
        .req_q_tail ( {CH_NUM{REQ_Q_TAIL_VAL}} ),
        .cpl_q_head ( {CH_NUM{CPL_Q_HEAD_VAL}} ),
        .cpl_q_head_inflight ( {CH_NUM{CPL_Q_HEAD_INFLIGHT_VAL}} ),
        .cpl_q_tail ( {CH_NUM{CPL_Q_TAIL_VAL}} ),
        .cpl_counts ( {CH_NUM{CPL_COUNT_VAL}} ),
        .cpl_counts2 ( {CH_NUM{CPL_COUNT2_VAL}} ),
        .dbg_transfer_valids ( 'd0 ),
        .dbg_transfer_issue_ends ( 'd0 ),
        .dbg_transfer_ends ( 'd0 ),
        .transfer_cpl_ch_cand ( 'd0 ),
        .clk ( clk ),
        .resetn ( resetn )
    );

    task static basic_read_write ();
        reg [31:0] written_data[0:REG_END/4-1];
        logic [31:0] valid_chs;
        logic [31:0]  cpl_queue_last_entry;
        logic [31:0]   ch;
        int          i, j;
        logic [CH_NUM-1:0] ch_valids = 0, ch_doorbells = 0;
        int                 ch_valid_num = 0, ch_doorbell_num = 0;
        // write
        for (i=0; i<REG_END/4;) begin
            reg [15:0] cur_addr = i * 4 + REG_BASE;
            reg [31:0] cur_data = RAND_VALUE == 0 ? VALUE : rd;
            reg [2:0]  write_stat = 3'd0;
            written_data[i] = cur_data;
            while (~&write_stat) begin
                @(posedge clk) begin
                    reg_awaddr <= cur_addr;
                    reg_awvalid <= (~write_stat[0] & ~reg_awvalid & rd[0]) | (reg_awvalid & ~reg_awready);
                    reg_wdata <= cur_data;
                    reg_wvalid <= (~write_stat[1] & ~reg_wvalid & rd[3]) | (reg_wvalid & ~reg_wready);
                    reg_bready <= ~write_stat[2] & rd[9];
                    write_stat <= &write_stat ? 'd0 :
                                  write_stat | {reg_bvalid & reg_bready, reg_wvalid & reg_wready, reg_awvalid & reg_awready};
                   ch = (i*4 - VPMAP_END)/16/4;
                   if (VPMAP_END <= i*4 && i*4 < CTRLREG_END && (i&15) == 0 && cur_data[0] && (~cur_data[4] || ENABLE_QUEUE==0)) begin
                       ch_valids[ch] = 1'b1;
                   end
                   if (VPMAP_END <= i*4 && i*4 < CTRLREG_END && (i&15) == 14 && cur_data[4]) ch_doorbells[ch] = ch_valids[ch];
                end
            end
            @(posedge clk) begin
                valid_chs = 'd0;
                for (j=0; j<CH_NUM; j++) begin
                    valid_chs = valid_chs + (stream_ch_valids[j] && (~stream_ch_d2d_valids[j] || ENABLE_QUEUE==0));
                end
                if (valid_chs !== stream_ch_valid_num) begin
                    $error("stream ch valids different: valids: %h, num: %d", stream_ch_valids, stream_ch_valid_num);
                end
                i++;
            end
        end
        for (i=0; i<CH_NUM; i++) begin
           ch_valid_num += ch_valids[i];
           ch_doorbell_num += ch_doorbells[i];
        end
        if (stream_ch_valid_num !== ch_valid_num ||
            stream_ch_doorbell_num !== ch_doorbell_num) begin
           $error("doorbell num: valid: %h, %2d %2d, doorbell: %h, %2d %2d", ch_valids, stream_ch_valid_num, ch_valid_num,
                  ch_doorbells, stream_ch_doorbell_num, ch_doorbell_num);
        end else begin
           $display("doorbell num: valid: %h, %2d %2d, doorbell: %h, %2d %2d", ch_valids, stream_ch_valid_num, ch_valid_num,
                    ch_doorbells, stream_ch_doorbell_num, ch_doorbell_num);
        end
        // read
        for (i=0; i<REG_END/4;) begin
            reg [15:0] cur_addr = i * 4 + REG_BASE;
            reg [1:0]  read_stat = 2'd0;
            reg [31:0] read_data;
            logic [31:0] mask;
            while (~&read_stat) begin
                @(posedge clk) begin
                    reg_araddr <= cur_addr;
                    reg_arvalid <= (~read_stat[0] & ~reg_arvalid & rd[2]) | (reg_arvalid & ~reg_arready);
                    reg_rready <= ~read_stat[1] & rd[11];
                    read_stat <= &read_stat ? 'd0 : read_stat | {reg_rvalid & reg_rready, reg_arvalid & reg_arready};
                    if (reg_rvalid & reg_rready) begin
                        read_data <= reg_rdata;
                    end
                end
            end
            mask = i*4 < VPMAP_END && (i&7) < 5     ? 32'hffffffff :
                   i*4 < VPMAP_END && (i&7) == 5    ? 32'h1 :
                   i*4 < VPMAP_END                  ? 32'h0 :
                   i*4 < CTRLREG_END && (i&15) < 1  ? 32'h1 :
                   i*4 < CTRLREG_END && (i&15) < 2  ? 32'h0 :
                   i*4 < CTRLREG_END && (i&15) < 10 ? 32'hffffffff :
                   i*4 < CTRLREG_END && (i&15) < 11 ? 32'hffff :
                   i*4 < CTRLREG_END && (i&15) < 12 ? 32'h0 :
                   i*4 < CTRLREG_END && (i&15) < 14 ? 32'hffffffff :
                   i*4 < CTRLREG_END && (i&15) < 15 ? 32'h00000111 :
                   i*4 < CTRLREG_END                ? 32'h0 :
                   i*4 < CTRLREG_END + 4            ? 32'h1ffff :
                   i*4 < CTRLREG_END + 8            ? 32'h0 :
                   i*4 < CTRLREG_END + 12           ? (32'h1<<CH_NUM_LOG)-1'b1 :
                   i*4 < QUEUE_START                ? 32'h0 :
                   i*4 < QUEUE_END && (i&7) == 2 && (((i*4-QUEUE_START)/QEW/QUEUE_DEPTH) & 1) == 1 ? 32'hffffffff :
                   i*4 < QUEUE_END                  ? 32'h0 :
                   i*4 < QUEUE_HT_END               ? ((32'h1 << QUEUE_DL)-1'b1) : 32'h0;
            if ((CTRLREG_END + 12 <= i*4 && i*4 < CTRLREG_END + 16 && read_data !== {8'd0, VP_MAP_NUM_LOG_8B, 8'd0, CH_NUM_LOG_8B}) ||
                (CTRLREG_END + 16 <= i*4 && i*4 < QUEUE_START && read_data !== STREAM_ENGINE_IDENTIFIER)) begin
                $error("[%h] read: %08x expect: %08x", reg_araddr, read_data,
                       i*4 >= CTRLREG_END + 16 ? STREAM_ENGINE_IDENTIFIER : {8'd0, VP_MAP_NUM_LOG_8B, 8'd0, CH_NUM_LOG_8B});
            end else if (i*4 >= VPMAP_END && i*4 < CTRLREG_END && (i&15) == 14) begin
               if (((written_data[i] & 32'h11) | ((written_data[i] & 32'h10)<<4)) !== (read_data & mask)) begin
                  $error("[%h] %2d write: %08x,%08x read: %08x,%08x mask: %08x", reg_araddr, i, written_data[i], written_data[i] & mask,
                         read_data, read_data & mask, mask);
               end
            end else if (QUEUE_START <= i*4 && i*4 < QUEUE_END && (i&7) == 2 && (((i*4-QUEUE_START)/QEW/QUEUE_DEPTH) & 1) == 1) begin
               // cpl queue size
               ch = (i*4 - QUEUE_START)/QEW/QUEUE_DEPTH/2;
               cpl_queue_last_entry = ((ch + 1) * QEW*QUEUE_DEPTH*2 - QEW + QUEUE_START)/4 + 2;
               if (stream_ch_valids[ch] && written_data[cpl_queue_last_entry] !== read_data) begin
                  $error("[%h] %2d write: %08x,%08x read: %08x,%08x mask: %08x", reg_araddr, i,
                         written_data[cpl_queue_last_entry], written_data[cpl_queue_last_entry] & mask,
                         read_data, read_data & mask, mask);
               end
            end else if (QUEUE_END <= i*4 && i*4 < QUEUE_HT_END) begin
               ch = (i*4 - QUEUE_END)/16;
               if (stream_ch_valids[ch] && (written_data[i] & mask) !== (read_data & mask)) begin
                  $error("[%h] %2d write: %08x,%08x read: %08x,%08x mask: %08x", reg_araddr, i, written_data[i], written_data[i] & mask,
                         read_data, read_data & mask, mask);
               end
            end else if ((written_data[i] & mask) !== (read_data & mask)) begin
                $error("[%h] %2d write: %08x,%08x read: %08x,%08x mask: %08x", reg_araddr, i, written_data[i], written_data[i] & mask,
                       read_data, read_data & mask, mask);
            end
            @(posedge clk) i++;
        end

    endtask

   task static queue_head_tail_updates;
      logic [CH_NUM_LOG:0] ch;
      logic [7:0]            q_head, q_tail;
      logic [63:0]           data_addr;
      logic [31:0]           data_size;
      // doorbell reset
      for (ch = 0; ch<CH_NUM; ch++) begin
         @(posedge clk) begin
            if (stream_check_requests[ch]) begin
               stream_check_done <= 1'b1;
               stream_check_ch = ch;
            end
         end
         @(posedge clk) stream_check_done <= 1'b0;
         while (stream_check_requests[ch]) @(posedge clk);
      end
      // req queue update
      for (ch = 0; ch<CH_NUM; ch++) begin
         if (stream_ch_valids[ch] && stream_ch_d2d_valids[ch]) begin
            @(posedge clk) begin
               q_head = stream_req_q_heads[ch*8+:8];
               data_size = rd;
               stream_req_update_ch <= ch;
               stream_req_update_size <= data_size;
               stream_req_update <= 1'b1;
            end
            @(posedge clk) begin
               stream_req_update <= 1'b0;
            end
            while (q_head == stream_req_q_heads[ch*8+:8]) @(posedge clk);
            @(posedge clk) begin
               stream_queue_read_ch <= ch;
               stream_queue_read_entry <= q_head;
               stream_queue_read_valid <= 1'b1;
            end
            @(posedge clk) stream_queue_read_valid <= 1'b0;
            while (stream_queue_read_data_valid || stream_queue_read_valid) @(posedge clk) begin
               stream_queue_read_valid <= 1'b0;
               data_addr = (64'd0 | D2D_AXI_BASE) + ({8'd0, D2D_AXI_RANGE} * (ch + 1));
               if (stream_queue_read_data_valid) begin
                  if (stream_queue_read_data[63:0] !== data_addr ||
                      stream_queue_read_data[127:64] !== {32'd0, data_size} ||
                      stream_queue_read_data[191:128] !== 64'd1) begin
                     $error("%d: req queue element: %h %h, %h %h, %h", $time, stream_queue_read_data[63:0], data_addr,
                            stream_queue_read_data[127:64], data_size, stream_queue_read_data[191:128]);
                  end
               end
            end
         end
      end
      // cpl queue update
      for (ch = 0; ch<CH_NUM; ch++) begin
         if (stream_ch_valids[ch] && stream_ch_d2d_valids[ch]) begin
            @(posedge clk) begin
               q_tail = stream_cpl_q_tails[ch*8+:8];
               stream_cpl_update_ch <= ch;
               stream_cpl_update <= 1'b1;
            end
            @(posedge clk) begin
               stream_cpl_update <= 1'b0;
            end
            while (q_tail == stream_cpl_q_tails[ch*8+:8]) @(posedge clk);
         end
      end
   endtask

    initial begin
        while (resetn !== 1'b1) @(posedge clk);

        case(TEST_CASE)
            0 : begin
               basic_read_write();
               queue_head_tail_updates();
            end
            default: begin
                $fatal(2, "unknown test case");
            end
        endcase

        $finish();
    end

endmodule

module test_regs_read_write_fixed();

    tb_regs tb();

endmodule

module test_regs_read_write_random();

    tb_regs #(
        .RAND_VALUE ( 1 )
    ) tb();

endmodule
