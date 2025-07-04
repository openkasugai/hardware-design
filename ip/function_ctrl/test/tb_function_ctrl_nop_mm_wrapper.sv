/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1 ns / 1 ps

module tb_function_ctrl_nop_mm_wrapper #(
    parameter DW_LOG = 9,
    parameter CTX_ID_BITS = 4,
    parameter TDEST_BITS = 4,
    parameter BURST_BITS = 5,
    parameter IN_MM_BITS = 0,
    parameter OUT_MM_BITS = 0,
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
   localparam IN_MM_BITS_MOD = IN_MM_BITS > 0 ? IN_MM_BITS : 1;
   localparam OUT_MM_BITS_MOD = OUT_MM_BITS > 0 ? OUT_MM_BITS : 1;
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

   wire                   m_axi_mem_AWVALID;
   wire [64-1:0]          m_axi_mem_AWADDR;
   wire [1-1:0]           m_axi_mem_AWID;
   wire [7:0]             m_axi_mem_AWLEN;
   wire [2:0]             m_axi_mem_AWSIZE;
   wire [1:0]             m_axi_mem_AWBURST;
   wire [1:0]             m_axi_mem_AWLOCK;
   wire [3:0]             m_axi_mem_AWCACHE;
   wire [2:0]             m_axi_mem_AWPROT;
   wire [3:0]             m_axi_mem_AWQOS;
   wire [3:0]             m_axi_mem_AWREGION;
   wire [1-1:0]           m_axi_mem_AWUSER;
   reg                    m_axi_mem_AWREADY;

   wire                   m_axi_mem_WVALID;
   wire [512-1:0]         m_axi_mem_WDATA;
   wire [(512/8)-1:0]     m_axi_mem_WSTRB;
   wire                   m_axi_mem_WLAST;
   wire [1-1:0]           m_axi_mem_WID;
   wire [1-1:0]           m_axi_mem_WUSER;
   reg                    m_axi_mem_WREADY;

   wire                   m_axi_mem_ARVALID;
   wire [64-1:0]          m_axi_mem_ARADDR;
   wire [1-1:0]           m_axi_mem_ARID;
   wire [7:0]             m_axi_mem_ARLEN;
   wire [2:0]             m_axi_mem_ARSIZE;
   wire [1:0]             m_axi_mem_ARBURST;
   wire [1:0]             m_axi_mem_ARLOCK;
   wire [3:0]             m_axi_mem_ARCACHE;
   wire [2:0]             m_axi_mem_ARPROT;
   wire [3:0]             m_axi_mem_ARQOS;
   wire [3:0]             m_axi_mem_ARREGION;
   wire [1-1:0]           m_axi_mem_ARUSER;
   reg                    m_axi_mem_ARREADY;

   reg                    m_axi_mem_RVALID;
   reg [512-1:0]          m_axi_mem_RDATA;
   reg                    m_axi_mem_RLAST;
   reg [1-1:0]            m_axi_mem_RID;
   reg [1-1:0]            m_axi_mem_RUSER;
   reg [1:0]              m_axi_mem_RRESP;
   wire                   m_axi_mem_RREADY;

   reg                    m_axi_mem_BVALID;
   reg [1:0]              m_axi_mem_BRESP;
   reg [1-1:0]            m_axi_mem_BID;
   reg [1-1:0]            m_axi_mem_BUSER;
   wire                   m_axi_mem_BREADY;

   wire clk, resetn;
   wire [31:0] rd;

   clk_reset clk_reset (
       .clk ( clk ),
       .resetn ( resetn ),
       .rd ( rd )
   );

   nop_mm_wrapper #(
       .DW_LOG ( DW_LOG ),
       .CTX_ID_BITS ( CTX_ID_BITS ),
       .TDEST_BITS ( TDEST_BITS ),
       .BURST_BITS ( BURST_BITS )
   ) dut (
       .*
   );

   reg [31:0]  frame_sizes[0:255];
   reg [7:0]   frame_iids[0:255];
   reg [7:0]   frame_oids[0:255];
   reg [63:0]  frame_iaddrs[0:255];
   reg [63:0]  frame_oaddrs[0:255];
   reg [TDEST_BITS-1:0] frame_idests[0:255];
   reg [TDEST_BITS-1:0] frame_odests[0:255];
   reg [CTX_ID_BITS-1:0] frame_iusers[0:255];
   reg [CTX_ID_BITS-1:0] frame_ousers[0:255];
   reg [7:0]   frame_wpos;
   reg [7:0]   frame_ihpos, frame_ohpos;
   reg [7:0]   frame_ihcpos;
   reg [7:0]   frame_icpos, frame_ocpos;
   reg [7:0]   frame_idpos, frame_odpos;

   reg [63:0]  read_addrs[0:255];
   reg [31:0]  read_bursts[0:255];
   reg [31:0]  read_remains[0:255];
   reg [7:0]   read_awpos, read_arpos;

   reg [DW-1:0] data_data[0:255];
   reg          data_rlasts[0:255];
   reg          data_wlasts[0:255];
   reg [7:0]    data_wpos, data_rpos, data_cpos;

   reg [63:0]  write_addrs[0:255];
   reg [31:0]  write_bursts[0:255];
   reg [31:0]  write_remains[0:255];
   reg [7:0]   write_awpos, write_arpos;

   initial begin
      frame_wpos = 'd0;
      frame_ihpos = 'd0;
      frame_ohpos = 'd0;
      frame_ihcpos = 'd0;
      frame_icpos = 'd0;
      frame_ocpos = 'd0;
      frame_idpos = 'd0;
      frame_odpos = 'd0;
      read_awpos = 'd0;
      read_arpos = 'd0;
      data_wpos = 'd0;
      data_rpos = 'd0;
      data_cpos = 'd0;
      write_awpos = 'd0;
      write_arpos = 'd0;
      in_0_tvalid = 1'b0;
   end

   // in frame header
   always @(posedge clk) begin
      if (~resetn) begin
         in_frame_header_0_tvalid <= 1'b0;
      end else if (~in_frame_header_0_tvalid || in_frame_header_0_tready) begin
         if (frame_ihpos != frame_wpos &&
             (HEADER_V_BITS>0 ? &rd[24+:HEADER_V_BITS_MOD] : 1'b1)) begin
            in_frame_header_0_tdata <= {'d0, frame_idests[frame_ihpos], frame_iids[frame_ihpos], frame_sizes[frame_ihpos], frame_iaddrs[frame_ihpos]};
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
            out_frame_header_0_tdata <= {'d0, frame_odests[frame_ohpos], frame_oids[frame_ohpos], frame_sizes[frame_ohpos], frame_oaddrs[frame_ohpos]};
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
         if (in_frame_consume_0_tvalid && in_frame_consume_0_tready) begin
            if (in_frame_consume_0_tdata !== frame_iids[frame_icpos] ||
                in_frame_consume_0_tuser !== frame_iusers[frame_icpos] ||
                in_frame_consume_0_tdest !== frame_idests[frame_icpos]) begin
               $error("%d: [%2h] frame consume %h %h, %h %h, %h %h", $time, in_frame_consume_0_tuser,
                      in_frame_consume_0_tdata, frame_iids[frame_icpos],
                      in_frame_consume_0_tuser, frame_iusers[frame_icpos],
                      in_frame_consume_0_tdest, frame_idests[frame_icpos]);
            end
            frame_icpos <= frame_icpos + 1'b1;
         end
      end
   end
   // out frame complete
   always @(posedge clk) begin
      if (~resetn) begin
         out_frame_complete_0_tready <= 1'b0;
      end else begin
         if (out_frame_complete_0_tvalid && out_frame_complete_0_tready) begin
            if (out_frame_complete_0_tdata[63:0] !== frame_oaddrs[frame_ocpos] ||
                out_frame_complete_0_tdata[95:64] !== frame_sizes[frame_ocpos] ||
                out_frame_complete_0_tdata[103:96] !== frame_oids[frame_ocpos] ||
                out_frame_complete_0_tuser !== frame_ousers[frame_ocpos] ||
                out_frame_complete_0_tdest !== frame_odests[frame_ocpos]) begin
               $error("%d: [%2h] %h %h, %h %h, %h %h, %h %h, %h %h", $time, out_frame_complete_0_tuser,
                      out_frame_complete_0_tdata[63:0], frame_oaddrs[frame_ocpos],
                      out_frame_complete_0_tdata[95:64], frame_sizes[frame_ocpos],
                      out_frame_complete_0_tdata[103:96], frame_oids[frame_ocpos],
                      out_frame_complete_0_tuser, frame_ousers[frame_ocpos],
                      out_frame_complete_0_tdest, frame_odests[frame_ocpos]);
            end
            frame_ocpos <= frame_ocpos + 1'b1;
         end
         out_frame_complete_0_tready <= COMP_R_BITS > 0 ? &rd[15+:COMP_R_BITS_MOD] : 1'b1;
      end
   end
   // mm resp and check
   logic [31:0] read_pendings;
   always @(posedge clk) begin
      if (~resetn) begin
         m_axi_mem_AWREADY <= 1'b0;
         m_axi_mem_WREADY <= 1'b0;
         m_axi_mem_ARREADY <= 1'b0;
         m_axi_mem_RVALID <= 1'b0;
         m_axi_mem_BVALID <= 1'b0;
         read_pendings <= 'd0;
         m_axi_mem_RRESP <= 'd0;
         m_axi_mem_BRESP <= 'd0;
      end else begin
         if (m_axi_mem_AWVALID && m_axi_mem_AWREADY) begin
            if (m_axi_mem_AWADDR !== write_addrs[write_arpos] ||
                {1+m_axi_mem_AWLEN, {KW_LOG{1'b0}}} > write_remains[write_arpos]) begin
               $error("%d: axi write addr: %h %h %h %h", $time, m_axi_mem_AWADDR, write_addrs[write_arpos],
                      {1+m_axi_mem_AWLEN, {KW_LOG{1'b0}}}, write_remains[write_arpos]);
            end
            write_arpos <= write_arpos + 1'b1;
         end
         if (m_axi_mem_WVALID && m_axi_mem_WREADY) begin
            if (m_axi_mem_WDATA !== data_data[data_cpos] ||
                m_axi_mem_WLAST !== data_wlasts[data_cpos]) begin
               if (m_axi_mem_WVALID && ~|m_axi_mem_AWLEN) begin
                  $display("%d: axi write data with addr: %h %h %h %h", $time,
                           m_axi_mem_WDATA, data_data[data_cpos], m_axi_mem_WLAST, data_wlasts[data_cpos]);
               end else begin
                  $error("%d: axi write data: %h %h %h %h", $time,
                         m_axi_mem_WDATA, data_data[data_cpos], m_axi_mem_WLAST, data_wlasts[data_cpos]);
               end
            end
            data_cpos <= data_cpos + 1'b1;
            if (m_axi_mem_WLAST) begin
               m_axi_mem_BVALID <= 1'b1;
            end else begin
               m_axi_mem_BVALID <= m_axi_mem_BVALID & ~m_axi_mem_BREADY;
            end
         end else begin
            m_axi_mem_BVALID <= m_axi_mem_BVALID & ~m_axi_mem_BREADY;
         end
         if (m_axi_mem_ARVALID && m_axi_mem_ARREADY) begin
            if (m_axi_mem_ARADDR !== read_addrs[read_arpos] ||
                {1+m_axi_mem_ARLEN, {KW_LOG{1'b0}}} > read_remains[read_arpos]) begin
               $error("%d: axi read addr: %h %h %h %h", $time, m_axi_mem_ARADDR, read_addrs[read_arpos],
                      {1+m_axi_mem_ARLEN, {KW_LOG{1'b0}}}, read_remains[read_arpos]);
            end
            read_arpos <= read_arpos + 1'b1;
            read_pendings = read_pendings + 1 + m_axi_mem_ARLEN;
         end
         m_axi_mem_AWREADY <= OUT_MM_BITS > 0 ? &rd[17+:OUT_MM_BITS_MOD] : 1'b1;
         m_axi_mem_WREADY <= OUT_MM_BITS > 0 ? &rd[19+:OUT_MM_BITS_MOD] : 1'b1;
         m_axi_mem_ARREADY <= (IN_MM_BITS > 0 ? &rd[21+:IN_MM_BITS_MOD] : 1'b1);

         if (m_axi_mem_RVALID && m_axi_mem_RREADY) begin
            data_rpos = data_rpos + 1'b1;
            read_pendings --;
         end
         m_axi_mem_RDATA <= data_data[data_rpos];
         m_axi_mem_RLAST <= data_rlasts[data_rpos];
         m_axi_mem_RVALID <= (OUT_MM_BITS > 0 ? &rd[19+:OUT_MM_BITS_MOD] : 1'b1) && |read_pendings;
      end
   end

   task static generate_frames;
      int frame_num = 0;
      logic [31:0] size;
      logic [63:0] iaddr, oaddr;
      logic [7:0]  iid, oid;
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
               iaddr = {rd, rd} << 6;
               oaddr = {rd, rd, rd[20:10]} << 6;
               iid = rd[18+:8];
               oid = rd[23+:8];
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
               frame_iaddrs[frame_wpos] <= iaddr;
               frame_oaddrs[frame_wpos] <= oaddr;
               frame_iids[frame_wpos] <= iid;
               frame_oids[frame_wpos] <= oid;
               frame_wpos <= wpos_next;
               frame_num++;
            end
         end else begin
            valid = 0;
         end
      end
   endtask

   task static generate_mm_data;
      int frame_num = 0;
      logic [31:0] rsize = 0;
      logic [31:0] wsize = 0;
      logic [31:0] rburst = 0;
      logic [31:0] wburst = 0;
      logic [63:0] waddr, raddr;
      logic [31:0] rburst_count =0;
      logic [31:0] wburst_count =0;
      logic [DW-1:0]          data;
      logic                   last;
      logic [31:0]            rlast_points[0:255];
      logic [31:0]            wlast_points[0:255];
      logic [31:0]            cur_rlast_point;
      logic [31:0]            cur_wlast_point;
      logic [7:0]             rlast_pwpos = 0;
      logic [7:0]             rlast_prpos = 0;
      logic [7:0]             wlast_pwpos = 0;
      logic [7:0]             wlast_prpos = 0;
      logic [7:0]             data_wpos_next;
      logic [31:0]            data_rlpos = 0;
      logic [31:0]            data_wlpos = 0;
      logic [31:0]            data_count = 0;
      logic                   wlast_burst = 0;
      while (frame_num < FRAME_NUM || |rsize || |wsize) @(posedge clk) begin
         if (frame_wpos !== frame_idpos && ~|rsize) begin
            rsize = (frame_sizes[frame_idpos] + KW - 1) & ~(KW-1);
            raddr = frame_iaddrs[frame_idpos];
            frame_idpos <= frame_idpos + 1'b1;
            read_addrs[read_awpos] <= raddr;
            read_bursts[read_awpos] <= 0;
            read_remains[read_awpos] <= rsize;
            read_awpos <= read_awpos + 1'b1;
         end
         if (frame_wpos !== frame_odpos && ~|wsize) begin
            wsize = (frame_sizes[frame_odpos] + KW - 1) & ~(KW-1);
            waddr = frame_oaddrs[frame_odpos];
            frame_odpos <= frame_odpos + 1'b1;
            write_addrs[write_awpos] <= waddr;
            write_bursts[write_awpos] <= 0;
            write_remains[write_awpos] <= wsize;
            write_awpos <= write_awpos + 1'b1;
         end
         if (m_axi_mem_ARVALID && m_axi_mem_ARREADY) begin
            rburst = 1 + m_axi_mem_ARLEN;
            raddr += rburst << KW_LOG;
            rsize -= rburst << KW_LOG;
            rlast_points[rlast_pwpos] = data_rlpos + m_axi_mem_ARLEN;
            if (data_count > rlast_points[rlast_pwpos]) begin
               data_rlasts[rlast_points[rlast_pwpos] & 255] <= 1'b1;
            end
            rlast_pwpos++;
            data_rlpos += rburst;
            if (|rsize) begin
               read_addrs[read_awpos] <= raddr;
               read_remains[read_awpos] <= rsize;
               read_awpos <= read_awpos + 1'b1;
            end
         end
         if (m_axi_mem_AWVALID) begin
            wburst = 1 + m_axi_mem_AWLEN;
            wlast_points[wlast_pwpos] = data_wlpos + m_axi_mem_AWLEN;
            if (data_count > wlast_points[wlast_pwpos]) begin
               data_wlasts[wlast_points[wlast_pwpos] & 255] = 1'b1;
            end
            if (m_axi_mem_AWREADY) begin
               waddr += wburst << KW_LOG;
               wsize -= wburst << KW_LOG;
               wlast_pwpos++;
               data_wlpos += wburst;
               if (|wsize) begin
                  write_addrs[write_awpos] <= waddr;
                  write_remains[write_awpos] <= wsize;
                  write_awpos <= write_awpos + 1'b1;
               end else begin
                  frame_num++;
               end
            end
         end
         data_wpos_next = data_wpos + 1;
         if (data_wpos_next != data_rpos && data_wpos_next != data_cpos) begin
            for (int i=0; i<KW; i+=4) data[i*8+:32] = rd ^ (32'h124 << (i/4));
            data_data[data_wpos] <= data;
            cur_wlast_point = wlast_points[wlast_prpos];
            if (wlast_points[wlast_prpos] == data_count) begin
               data_wlasts[data_wpos] <= 1'b1;
               wlast_prpos++;
            end else begin
               data_wlasts[data_wpos] <= 1'b0;
            end
            if (rlast_pwpos != rlast_prpos && rlast_points[rlast_prpos] < data_count) rlast_prpos <= rlast_prpos + 1'b1;
            cur_rlast_point = rlast_points[rlast_prpos];
            if (rlast_pwpos != rlast_prpos && rlast_points[rlast_prpos] == data_count) begin
               data_rlasts[data_wpos] <= 1'b1;
               rlast_prpos <= rlast_prpos + 1'b1;
            end else begin
               data_rlasts[data_wpos] <= 1'b0;
            end
            data_wpos <= data_wpos + 1'b1;
            data_count <= data_count + 1'b1;
         end
      end
   endtask

   initial begin
      @(posedge clk);
      while (~resetn) @(posedge clk);

      fork
         generate_frames;
         generate_mm_data;
      join

      while (data_rpos !== data_cpos ||
             frame_wpos !== frame_icpos ||
             frame_wpos !== frame_ocpos ||
             frame_wpos !== frame_ihcpos ||
             frame_wpos !== frame_odpos) @(posedge clk);

      $finish;
   end

endmodule

module test_nop_mm_function_wrapper_fast;
   tb_function_ctrl_nop_mm_wrapper tb ();
endmodule

module test_nop_mm_function_wrapper_random;
   tb_function_ctrl_nop_mm_wrapper #(
       .IN_MM_BITS ( 1 ),
       .OUT_MM_BITS ( 1 ),
       .HEADER_V_BITS ( 4 ),
       .HEADER_R_BITS ( 4 ),
       .CONSUME_R_BITS ( 4 ),
       .COMP_R_BITS ( 4 )
   ) tb ();
endmodule

module test_nop_mm_function_wrapper_slow_out;
   tb_function_ctrl_nop_mm_wrapper #(
       .IN_MM_BITS ( 0 ),
       .OUT_MM_BITS ( 2 ),
       .HEADER_V_BITS ( 4 ),
       .HEADER_R_BITS ( 6 ),
       .CONSUME_R_BITS ( 6 ),
       .COMP_R_BITS ( 6 )
   ) tb ();
endmodule
