/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/1ps
module tb_transfer_cpl #(
    parameter CH_NUM_LOG = 3,
    parameter DESC_RQ_DW = 512,
    parameter DESC_RQ_DK = 16,
    parameter RQ_DW = 384,
    parameter RQ_DK = 12,
    parameter QEW = 32,
    parameter QEW_LOG = 5,
    parameter RQBASE = 128,
    parameter RCBASE = 96,
    parameter VP_MAP_NUM_LOG = 4,
    parameter VPMAP_SIZE_MAX = 32'hfffffffc,
    parameter DESC_DWORD = 16,
    parameter CH_BASE = 0,
    parameter CHECK_INTERVAL = 200,
    parameter INITIALIZE_INTERVAL = 10,
    parameter UPDATE_INTERVAL = 30,
    parameter SIZE_MASK = 32'hffffffff,
    parameter DISABLE_FRAME_INFO = 0,
    parameter DESC_LEN = 512,
    parameter DESC_REQ_BITS = 2,
    parameter [(1<<CH_NUM_LOG)-1:0] CH_VALIDS = {(1<<CH_NUM_LOG){1'b1}},
    parameter DELAY = 5,
    parameter DELAY_RD_BITS = 1,
    parameter TRANSFER_END = 100,
    parameter ENABLE_QUEUE = 0,
    parameter TEST_CASE = 0
    ) ();

    wire clk, resetn;
    wire [31:0] rd;
    clk_reset clk_reset(
        .clk ( clk ),
        .resetn ( resetn ),
        .rd ( rd )
    );

    localparam CH_NUM = 1 << CH_NUM_LOG;
    localparam QEWB = QEW << 3;
    localparam QEWB_LOG = QEW_LOG + 3;
    localparam VP_MAP_NUM = 1 << VP_MAP_NUM_LOG;
    localparam TRANSFER_MAX_LOG = 12;
    localparam TRANSFER_MAX = 1 << TRANSFER_MAX_LOG;

    reg [64*CH_NUM-1:0]      desc_base_vaddr;
    reg [32*CH_NUM-1:0]      desc_base_size;
    reg [CH_NUM-1:0]         desc_base_final;
    reg [CH_NUM-1:0]         desc_base_valid;
    wire [CH_NUM-1:0]        desc_base_ready;

    reg [DESC_RQ_DW-1:0]     desc_req_data;
    reg [DESC_RQ_DK-1:0]     desc_req_keep;
    reg                      desc_req_valid;
    reg                      desc_req_last;
    wire                     desc_req_ready;

    reg [CH_NUM_LOG-1:0]     desc_cpl_ch;
    reg [31:0]               desc_cpl_data;
    reg                      desc_cpl_valid;
    wire                     desc_cpl_ready;

    wire [CH_NUM_LOG-1:0]    transfer_cpl_ch;
    wire                     transfer_cpl_ch_valid;
    reg                      transfer_cpl_ch_done;

    wire [RQ_DW-1:0]         queue_wr_data;
    wire [RQ_DK-1:0]         queue_wr_keep;
    wire                     queue_wr_valid;
    reg                      queue_wr_ready;

    reg [CH_NUM*64-1:0]      cpl_q_head_addrs;

    reg [CH_NUM*64-1:0]      stream_desc_bases;
    reg [CH_NUM*64-1:0]      stream_desc_ends;

    reg [CH_NUM-1:0]         stream_ch_valids;
    reg [CH_NUM-1:0]         stream_ch_d2d_valids;

    initial begin
        desc_req_data = 'd0;
        desc_req_keep = 'd0;
        desc_req_valid = 1'b0;
        desc_base_vaddr = 'd0;
        desc_base_size = 'd0;
        desc_base_final = 'b0;
        desc_base_valid = 'b0;
        desc_req_valid = 1'b0;
        desc_cpl_valid = 1'b0;
        queue_wr_ready = 1'b0;
        cpl_q_head_addrs = 'd0;
        stream_desc_bases = 'd0;
        stream_desc_ends = 'd0;
        stream_ch_valids = CH_VALIDS;
        stream_ch_d2d_valids = 0;
        @(posedge clk);
        while (ENABLE_QUEUE > 0 && ~|stream_ch_d2d_valids) @(posedge clk) begin
           stream_ch_d2d_valids = CH_VALIDS & rd;
        end
    end

    stream_engine_transfer_cpl #(
        .CH_NUM_LOG ( CH_NUM_LOG ),
        .QEW ( QEW ),
        .QEW_LOG ( QEW_LOG ),
        .DESC_RQ_DW ( DESC_RQ_DW ),
        .DESC_RQ_DK ( DESC_RQ_DK ),
        .DESC_LEN ( DESC_LEN ),
        .RQ_DW ( RQ_DW ),
        .RQ_DK ( RQ_DK ),
        .DISABLE_FRAME_INFO ( DISABLE_FRAME_INFO ),
        .RQBASE ( RQBASE )
    ) dut (
        .stream_ch_valids ( stream_ch_valids ),
        .stream_ch_d2d_valids ( stream_ch_d2d_valids ),

        .desc_base_vaddr ( desc_base_vaddr ),
        .desc_base_size ( desc_base_size ),
        .desc_base_final ( desc_base_final ),
        .desc_base_valid ( desc_base_valid ),
        .desc_base_ready ( desc_base_ready ),
`ifdef OLD_IMPL
        .desc_req_data ( desc_req_data ),
        .desc_req_keep ( desc_req_keep ),
        .desc_req_valid ( desc_req_valid ),
        .desc_req_last ( desc_req_last ),
        .desc_req_ready ( desc_req_ready ),
`else
        .desc_cpl_data ( desc_cpl_data ),
        .desc_cpl_ch ( desc_cpl_ch ),
        .desc_cpl_valid ( desc_cpl_valid ),
        .desc_cpl_ready ( desc_cpl_ready ),
`endif
        .transfer_cpl_ch ( transfer_cpl_ch ),
        .transfer_cpl_ch_valid ( transfer_cpl_ch_valid ),
        .transfer_cpl_ch_done ( transfer_cpl_ch_done ),

        .queue_wr_data ( queue_wr_data ),
        .queue_wr_keep ( queue_wr_keep ),
        .queue_wr_valid ( queue_wr_valid ),
        .queue_wr_ready ( queue_wr_ready ),

        .cpl_q_head_addrs ( cpl_q_head_addrs ),
`ifdef OLD_IMPL
//        .stream_desc_bases ( stream_desc_bases ),
//        .stream_desc_ends ( stream_desc_ends ),
`endif
        .clk ( clk ),
        .resetn ( resetn )
    );

    reg [63:0] vaddrs[0:CH_NUM-1];
    reg [31:0] vsizes[0:CH_NUM-1];
    reg [31:0] vaddr_offsets[0:CH_NUM-1];
    reg [63:0] vpmap_vaddrs[0:CH_NUM-1][0:VP_MAP_NUM-1];
    reg [31:0] vpmap_vsizes[0:CH_NUM-1][0:VP_MAP_NUM-1];
    reg [63:0] vpmap_paddrs[0:CH_NUM-1][0:VP_MAP_NUM-1];
    reg        vpmap_valids[0:CH_NUM-1][0:VP_MAP_NUM-1];

    reg [CH_NUM_LOG-1:0] frame_info_ch[0:TRANSFER_MAX-1];
    reg [31:0]           frame_info_sizes[0:TRANSFER_MAX-1];
    reg [63:0]           frame_info_vaddrs[0:TRANSFER_MAX-1];
    reg [TRANSFER_MAX_LOG-1:0] frame_info_enq_pos;
    reg [TRANSFER_MAX_LOG-1:0] frame_info_enq_pos2[0:CH_NUM-1];
    reg [TRANSFER_MAX_LOG-1:0] frame_info_enq_ch_pos[0:CH_NUM-1][0:TRANSFER_MAX-1];
    reg [TRANSFER_MAX_LOG-1:0] frame_info_deq_pos[0:CH_NUM-1];
    reg [TRANSFER_MAX_LOG-1:0] frame_info_deq_pos2[0:CH_NUM-1];

    initial begin
        for (int i=0; i<CH_NUM; i++) begin
            for (int j=0; j<VP_MAP_NUM; j++) begin
                vpmap_valids[i][j] = 1'b0;
            end
            frame_info_deq_pos[i] = 'd0;
            frame_info_deq_pos2[i] = 'd0;
            frame_info_enq_pos2[i] = 'd0;
        end
        frame_info_enq_pos = 'd0;
    end

    // transfer cpl ch
    reg [DELAY-1:0] transfer_cpl_ch_done_delay;
    reg             transfer_cpl_ch_valid_saved;
    always @(posedge clk) begin
        if (~resetn) begin
            transfer_cpl_ch_valid_saved <= 1'b0;
            transfer_cpl_ch_done <= 1'b0;
            transfer_cpl_ch_done_delay <= 'd0;
        end else begin
            transfer_cpl_ch_valid_saved <= (transfer_cpl_ch_valid | transfer_cpl_ch_valid_saved) & ~&rd[5+:DELAY_RD_BITS];
            transfer_cpl_ch_done_delay <= {transfer_cpl_ch_done_delay, (transfer_cpl_ch_valid | transfer_cpl_ch_valid_saved) & &rd[5+:DELAY_RD_BITS]};
            transfer_cpl_ch_done <= transfer_cpl_ch_done_delay[DELAY-1];
        end
    end

    reg [CH_NUM-1:0] deq_fins;

    // queue wr
    reg queue_wr_addr_found;
    logic [TRANSFER_MAX_LOG-1:0] cur_deq_pos;
    always @(posedge clk) begin
        if (queue_wr_valid === 1'b1 && queue_wr_ready === 1'b1) begin
            queue_wr_addr_found = 1'b0;
            for (int i=0; i<CH_NUM; i++) begin
                if (queue_wr_data[63:0] === cpl_q_head_addrs[i*64+:64]) begin
                    $display("%d [%2d]:                         cpl head: vaddr:%h size:%h stat:%h", $time, i,
                             queue_wr_data[RQBASE+:64], queue_wr_data[RQBASE+64+:32], queue_wr_data[RQBASE+128+:32]);
                    cur_deq_pos = frame_info_enq_ch_pos[i][frame_info_deq_pos[i]];
                    if (stream_ch_d2d_valids[i]) begin
                       $error("wrong write queue [%2h]", i);
                    end
                    if (frame_info_vaddrs[cur_deq_pos] !== queue_wr_data[RQBASE+:64] ||
                        frame_info_sizes[cur_deq_pos] !== queue_wr_data[RQBASE+64+:32] ||
                        frame_info_ch[cur_deq_pos] !== i || queue_wr_data[RQBASE+128+:32] !== 'd2) begin
                        $error("cpl head error[%3d]: ch:%h,%h, vaddr:%h,%h, size:%h,%h, stat:%h", frame_info_deq_pos2[i], i, frame_info_ch[cur_deq_pos],
                               queue_wr_data[RQBASE+:64], frame_info_vaddrs[cur_deq_pos],
                               queue_wr_data[RQBASE+64+:32], frame_info_sizes[cur_deq_pos], queue_wr_data[RQBASE+128+:32]);
                    end
                    frame_info_deq_pos[i] <= frame_info_deq_pos[i] + 1'b1;
                    queue_wr_addr_found = 1'b1;
                end
            end
            if (!queue_wr_addr_found) begin
                $error("queue wr addr failed: %h", queue_wr_data[63:0]);
            end
            if (queue_wr_data[74:64] !== (QEW>>2) ||
                queue_wr_data[78:75] !== 4'd1) begin
                $error("queue wr desc failed: %h %h", queue_wr_data[74:64], queue_wr_data[78:75]);
            end
        end
        queue_wr_ready <= rd[4];
    end
    always @(posedge clk) begin
        if (~resetn) begin
            deq_fins <= 'd0;
        end else begin
            for (int i=0; i<CH_NUM; i++) begin
                deq_fins[i] <= frame_info_enq_pos2[i] == frame_info_deq_pos[i];
            end
        end
    end

    reg [31:0] cpl_ch_count;
    always @(posedge clk) begin
        if (~resetn) begin
            cpl_ch_count <= 32'd0;
        end else if (transfer_cpl_ch_valid) begin
            cpl_ch_count <= cpl_ch_count + 1'b1;
        end
    end

    task static initialize_vpmap();
        int          i, j;
        reg [63:0]   cur_vaddr;
        reg [31:0]   cur_remain;
        // initialize registers
        for (i=0; i<CH_NUM; i++) begin
            for (j=0; j<VP_MAP_NUM; j++) begin
                if (j==0) begin
                    @(posedge clk) vaddrs[i] = {rd, rd[31:5], 5'd0};
                    @(posedge clk) begin
                        vsizes[i] = {rd[31:5], 5'd0};
                        cur_vaddr = vaddrs[i];
                        cur_remain = vsizes[i];
                        $display("[%2d]: vaddr: %h vsize: %h", i, vaddrs[i], vsizes[i]);
                    end
                end
                @(posedge clk) begin
                    if (cur_remain) begin
                        vpmap_vsizes[i][j] = cur_remain < {1'b0, rd[30:2], 2'd0} ? cur_remain : {1'b0, rd[30:2], 2'd0};
                        if (j == VP_MAP_NUM - 1) vpmap_vsizes[i][j] = cur_remain;
                        else if (vpmap_vsizes[i][j] > VPMAP_SIZE_MAX) vpmap_vsizes[i][j] = VPMAP_SIZE_MAX;
                        cur_remain = cur_remain - vpmap_vsizes[i][j];
                        vpmap_vaddrs[i][j] = cur_vaddr;
                        vpmap_valids[i][j] = 1'b1;
                        cur_vaddr = cur_vaddr + vpmap_vsizes[i][j];
                    end
                end
                @(posedge clk) begin
                    vpmap_paddrs[i][j] = {rd, rd[31:5], 5'd0};
                    $display("       %h vaddr: %h vsize: %h paddr: %h", vpmap_valids[i],
                             vpmap_vaddrs[i][j], vpmap_vsizes[i][j], vpmap_paddrs[i][j]);
                end
            end
        end
    endtask

    task static initialize_stream_desc_range();
        int i;
        for (i=0; i<CH_NUM; i++) begin
            @(posedge clk) begin
                if (stream_ch_valids[i]) stream_desc_bases[i*64+:64] <= {rd, rd} << ($clog2(DESC_LEN) - 3);
            end
            @(posedge clk) begin
                if (stream_ch_valids[i]) stream_desc_ends[i*64+:64] <= stream_desc_bases[i*64+:64] + (({32'd0, rd[4:0]} + 2'd2) << ($clog2(DESC_LEN) - 3));
            end
        end
        @(posedge clk);
        for (i=0; i<CH_NUM; i++) begin
            $display("desc range[%2d]: %h_%h:%h_%h", i,
                     stream_desc_bases[i*64+32+:32], stream_desc_bases[i*64+:32],
                     stream_desc_ends[i*64+32+:32], stream_desc_ends[i*64+:32]);
        end
    endtask

    task static initialize_queue_addrs();
        int i;
        for (i=0; i<CH_NUM; i++) begin
            @(posedge clk) begin
                cpl_q_head_addrs[i*64+:64] <= {rd, rd} << QEW_LOG;
                $display("cpl head[%2d]: %h_%h", i, {rd[31-QEW_LOG:0], rd[31-:QEW_LOG]}, rd << QEW_LOG);
            end
        end
    endtask

    task static add_request_and_complete();
        int i, j;
        reg [63:0] paddrs[0:TRANSFER_MAX-1];
        reg [31:0] sizes[0:TRANSFER_MAX-1];
        reg        lasts[0:TRANSFER_MAX-1];
        reg [CH_NUM_LOG-1:0] chs[0:TRANSFER_MAX-1];
        reg [TRANSFER_MAX_LOG:0] wpos, rpos;

        reg [63:0]               cur_vaddr;
        reg [31:0]               cur_remain;
        reg [CH_NUM_LOG-1:0]     cur_ch;
        reg                      cur_valid;

        reg [7:0]                desc_req_len;
        reg [63:0]               desc_req_addrs[0:CH_NUM-1];
        reg [CH_NUM_LOG-1:0]     desc_req_ch;

        @(posedge clk) begin
            wpos = 'd0;
            rpos = 'd0;
            cur_valid = 1'b0;
            desc_req_len = 'd0;
            desc_req_ch = 'd0;
            for (i=0; i<CH_NUM; i++) begin
                desc_req_addrs[i] = stream_desc_bases[64*i+:64];
            end
        end
        do @(posedge clk) begin
            // virtual transfer cmd
            if (frame_info_enq_pos < TRANSFER_END && ~cur_valid && ~|desc_base_valid) begin
                cur_ch = rd[15+:CH_NUM_LOG];
                if (stream_ch_valids[cur_ch]) begin
                    cur_vaddr = vaddrs[cur_ch] + {rd[31:2], 2'd0};
                    cur_remain = {rd[31:2], 2'd0} & SIZE_MASK;
                    if (|cur_remain) begin
                        cur_valid = cur_vaddr < vaddrs[cur_ch] + vsizes[cur_ch];
                        if (cur_vaddr + cur_remain > vaddrs[cur_ch] + vsizes[cur_ch]) begin
                            cur_remain = vaddrs[cur_ch] + vsizes[cur_ch] - cur_vaddr;
                        end
                        frame_info_ch[frame_info_enq_pos] <= cur_ch;
                        frame_info_sizes[frame_info_enq_pos] <= cur_remain;
                        frame_info_vaddrs[frame_info_enq_pos] <= cur_vaddr;
                        frame_info_enq_pos <= frame_info_enq_pos + cur_valid;
                        frame_info_enq_ch_pos[cur_ch][frame_info_enq_pos2[cur_ch]] <= frame_info_enq_pos;
                        frame_info_enq_pos2[cur_ch] <= frame_info_enq_pos2[cur_ch] + cur_valid;
                        if (stream_ch_d2d_valids[cur_ch]) begin
                            frame_info_deq_pos[cur_ch] <= frame_info_deq_pos[cur_ch] + cur_valid;
                        end
                        if (cur_valid) begin
                            $display("%d [%2d]: transfer vaddr:%h, size:%h", $time, cur_ch, cur_vaddr, cur_remain);
                        end
                    end
                end
            end
            // desc base
            if (cur_valid & &rd[9:8] & ~|desc_base_valid) begin
                desc_base_vaddr[cur_ch*64+:64] <= cur_vaddr;
                for (i=0; i<VP_MAP_NUM; i++) begin
                    if (vpmap_vaddrs[cur_ch][i] <= cur_vaddr &&
                        cur_vaddr < vpmap_vaddrs[cur_ch][i] + vpmap_vsizes[cur_ch][i]) begin
                        paddrs[wpos] <= vpmap_paddrs[cur_ch][i] + cur_vaddr - vpmap_vaddrs[cur_ch][i];
                        if (cur_remain <= vpmap_vaddrs[cur_ch][i] + vpmap_vsizes[cur_ch][i] - cur_vaddr) begin
                            sizes[wpos] <= cur_remain;
                            lasts[wpos] <= 1'b1;
                            cur_valid <= 1'b0;
                            desc_base_size[cur_ch*32+:32] <= cur_remain;
                            desc_base_final[cur_ch] <= 1'b1;
                            $display("%d [%2d]:         desc base[%2d] vaddr:%h, paddr:%h, size:%8h, final:1", $time, cur_ch, wpos,
                                     cur_vaddr, vpmap_paddrs[cur_ch][i] + cur_vaddr - vpmap_vaddrs[cur_ch][i], cur_remain);
                        end else begin
                            sizes[wpos] <= vpmap_vaddrs[cur_ch][i] + vpmap_vsizes[cur_ch][i] - cur_vaddr;
                            lasts[wpos] <= 1'b0;
                            cur_vaddr <= vpmap_vaddrs[cur_ch][i] + vpmap_vsizes[cur_ch][i];
                            cur_remain <= cur_remain - (vpmap_vaddrs[cur_ch][i] + vpmap_vsizes[cur_ch][i] - cur_vaddr);
                            desc_base_size[cur_ch*32+:32] <= vpmap_vaddrs[cur_ch][i] + vpmap_vsizes[cur_ch][i] - cur_vaddr;
                            desc_base_final[cur_ch] <= 1'b0;
                            $display("%d [%2d]:         desc base[%2d] vaddr:%h, paddr:%h, size:%8h, final:0", $time, cur_ch, wpos,
                                     cur_vaddr, vpmap_paddrs[cur_ch][i] + cur_vaddr - vpmap_vaddrs[cur_ch][i],
                                     vpmap_vaddrs[cur_ch][i] + vpmap_vsizes[cur_ch][i] - cur_vaddr);
                        end
                        break;
                    end
                end
                desc_base_valid[cur_ch] <= 1'b1;
                chs[wpos] <= cur_ch;
            end else begin
                desc_base_valid[cur_ch] <= desc_base_valid[cur_ch] & ~desc_base_ready[cur_ch];
                if (desc_base_valid[cur_ch] & desc_base_ready[cur_ch]) begin
                    wpos <= wpos + 1'b1;
                end
            end
`ifdef OLD_IMPL
            // desc req
            if (((wpos[TRANSFER_MAX_LOG] ^ rpos[TRANSFER_MAX_LOG]) ^ (wpos[TRANSFER_MAX_LOG-1:0] > rpos[TRANSFER_MAX_LOG-1:0])) &&
                &rd[9+:DESC_REQ_BITS] && (~desc_req_valid | desc_req_ready)) begin
                if (~|desc_req_len | (desc_req_valid & desc_req_ready & desc_req_last)) begin
                    desc_req_data[63:0] <= desc_req_addrs[chs[rpos[TRANSFER_MAX_LOG-1:0]]];
                    desc_req_data[74:64] <= DESC_LEN >> 5;
                    desc_req_data[78:75] <= 4'd1;
                    desc_req_data[RQBASE-1:79] <= 'd0;
                    if (DISABLE_FRAME_INFO > 0) begin
                        desc_req_data[DESC_RQ_DW-1:RQBASE] <= {{DESC_RQ_DW{1'b0}}, 8'd0, 8'd4, rd[15:0]};
                    end else begin
                        desc_req_data[DESC_RQ_DW-1:RQBASE] <= {{DESC_RQ_DW{1'b0}}, sizes[rpos[TRANSFER_MAX_LOG-1:0]], 8'd0, 8'd4, rd[15:0]};
                    end
                    desc_req_len <= (DESC_RQ_DW - RQBASE) >> 5;
                    desc_req_keep <= ('d1 << ((DESC_LEN + RQBASE) >> 5)) - 1'b1;
                    desc_req_last <= DESC_LEN + RQBASE <= DESC_RQ_DW;
                    if (DESC_LEN + RQBASE <= DESC_RQ_DW) begin
                        rpos <= rpos + 1'b1;
                        if (desc_req_addrs[chs[rpos[TRANSFER_MAX_LOG-1:0]]] + (DESC_LEN >> 3) >= stream_desc_ends[chs[rpos[TRANSFER_MAX_LOG-1:0]]*64+:64]) begin
                            desc_req_addrs[chs[rpos[TRANSFER_MAX_LOG-1:0]]] <= stream_desc_bases[chs[rpos[TRANSFER_MAX_LOG-1:0]]*64+:64];
                        end else begin
                            desc_req_addrs[chs[rpos[TRANSFER_MAX_LOG-1:0]]] <= desc_req_addrs[chs[rpos[TRANSFER_MAX_LOG-1:0]]] + (DESC_LEN >> 3);
                        end
                        $display("%d [%2d]:                  @@@ A) rpos++: %4d", $time, chs[rpos[TRANSFER_MAX_LOG-1:0]], rpos + 1'b1);
                    end
                    $display("%d [%2d]:                 desc req: rpos:%5d, addr:%h, size:%h", $time, chs[rpos[TRANSFER_MAX_LOG-1:0]],
                             rpos[TRANSFER_MAX_LOG-1:0], desc_req_addrs[chs[rpos[TRANSFER_MAX_LOG-1:0]]], sizes[rpos[TRANSFER_MAX_LOG-1:0]]);
                end else begin
                    desc_req_data <= {{DESC_RQ_DW{1'b0}}, sizes[rpos[TRANSFER_MAX_LOG-1:0]], 8'd0, 8'd4, rd[15:0]} >> ({desc_req_len, 5'd0} + RQBASE);
                    desc_req_len <= desc_req_len + (DESC_RQ_DW >> 5);
                    desc_req_keep <= ('d1 << ((DESC_LEN >> 5) - desc_req_len)) - 1'b1;
                    desc_req_last <= ({desc_req_len, 5'd0} + DESC_RQ_DW) >= DESC_LEN;
                    if (({desc_req_len, 5'd0} + DESC_RQ_DW) >= DESC_LEN) begin
                        rpos <= rpos + 1'b1;
                        if (desc_req_addrs[chs[rpos[TRANSFER_MAX_LOG-1:0]]] + (DESC_LEN >> 3) >= stream_desc_ends[chs[rpos[TRANSFER_MAX_LOG-1:0]]*64+:64]) begin
                            desc_req_addrs[chs[rpos[TRANSFER_MAX_LOG-1:0]]] <= stream_desc_bases[chs[rpos[TRANSFER_MAX_LOG-1:0]]*64+:64];
                        end else begin
                            desc_req_addrs[chs[rpos[TRANSFER_MAX_LOG-1:0]]] <= desc_req_addrs[chs[rpos[TRANSFER_MAX_LOG-1:0]]] + (DESC_LEN >> 3);
                        end
                        $display("%d [%2d]:                  @@@ B) rpos++: %4d", $time, chs[rpos[TRANSFER_MAX_LOG-1:0]], rpos + 1'b1);
                    end
                end
                desc_req_ch <= chs[rpos[TRANSFER_MAX_LOG-1:0]];
                desc_req_valid <= 1'b1;
            end else begin
                desc_req_valid <= desc_req_valid & ~desc_req_ready;
                desc_req_len <= desc_req_valid & desc_req_ready & desc_req_last ? 'd0 : desc_req_len;
            end
            if (desc_req_valid & desc_req_ready & ~desc_req_last) begin
                $display("%d [%2d]:                 ## desc req addr:%h, dword:%h, keep:%h, size:%h", $time, desc_req_ch,
                         desc_req_data[63:0], desc_req_data[74:64], desc_req_keep, desc_req_data[RQBASE+32+:32]);
            end
`else
            if (((wpos[TRANSFER_MAX_LOG] ^ rpos[TRANSFER_MAX_LOG]) ^ (wpos[TRANSFER_MAX_LOG-1:0] > rpos[TRANSFER_MAX_LOG-1:0])) &&
                &rd[9+:DESC_REQ_BITS] && (~desc_cpl_valid | desc_cpl_ready)) begin

               if (DISABLE_FRAME_INFO > 0) begin
                  desc_cpl_data <= 'd0;
               end else begin
                  desc_cpl_data <= sizes[rpos[TRANSFER_MAX_LOG-1:0]];
               end
               desc_cpl_ch <= chs[rpos[TRANSFER_MAX_LOG-1:0]];
               desc_cpl_valid <= 1'b1;
               rpos <= rpos + 1'b1;
            end else begin
               desc_cpl_valid <= desc_cpl_valid & ~desc_cpl_ready;
            end
`endif
            for (i=0; i<CH_NUM; i++) begin
                if (desc_base_valid[i] & desc_base_ready[i]) begin
                    $display("%d [%2d]:         ## desc base vaddr:%h, size:%h, final:%1d", $time, i,
                             desc_base_vaddr[i*64+:64], desc_base_size[i*32+:32], desc_base_final[i]);
                end
            end
        end while (frame_info_enq_pos < TRANSFER_END || ~&deq_fins);
    endtask

    initial begin
        int i;
        while (resetn !== 1'b1) @(posedge clk);

        case(TEST_CASE)
            0 : begin
                initialize_vpmap;
                initialize_queue_addrs();
                initialize_stream_desc_range();
                add_request_and_complete();
            end
            default: begin
                $fatal(2, "unknown test case");
            end
        endcase

        $display("cpl_count: %6d", cpl_ch_count);
        $finish();
    end

endmodule

module test_transfer_cpl_simple();

    tb_transfer_cpl tb();

endmodule

module test_transfer_cpl_simple2();

    tb_transfer_cpl #(
        .DISABLE_FRAME_INFO ( 1 ),
        .CH_NUM_LOG ( 4 ),
        .TRANSFER_END ( 1000 ),
        .CH_VALIDS ( 16'h5555 ),
        .DESC_REQ_BITS ( 1 ),
        .SIZE_MASK ( 32'hfff ),
        .DELAY ( 1 ),
        .DELAY_RD_BITS( 2 )
    ) tb();

endmodule

module test_transfer_cpl_without_sent_size();

    tb_transfer_cpl #(
        .DISABLE_FRAME_INFO ( 1 )
    ) tb ();

endmodule

module test_transfer_cpl_simple_d2d();

    tb_transfer_cpl #(
        .ENABLE_QUEUE ( 1 )
    ) tb ();

endmodule
