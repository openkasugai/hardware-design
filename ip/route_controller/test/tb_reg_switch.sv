/*************************************************
* Copyright 2025 NTT Corporation
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module tb_route_control_reg_switch #(
    parameter ADDR_BITS = 16,
    parameter CTX_ID_BITS = 4,
    parameter ABITS = 0,
    parameter DBITS = 0,
    parameter BBITS = 0,
    parameter SEED = 123568
    ) (
    );

   localparam ABITS_MOD = ABITS > 0 ? ABITS : 1;
   localparam DBITS_MOD = DBITS > 0 ? DBITS : 1;
   localparam BBITS_MOD = BBITS > 0 ? BBITS : 1;

   reg [ADDR_BITS-1:0]    cfg_araddr;
   reg                    cfg_arvalid;
   wire                   cfg_arready;
   wire [31:0]            cfg_rdata;
   wire [1:0]             cfg_rresp;
   wire                   cfg_rvalid;
   reg                    cfg_rready;
   reg [ADDR_BITS-1:0]    cfg_awaddr;
   reg                    cfg_awvalid;
   wire                   cfg_awready;
   reg [31:0]             cfg_wdata;
   reg                    cfg_wvalid;
   wire                   cfg_wready;
   wire [1:0]             cfg_bresp;
   wire                   cfg_bvalid;
   reg                    cfg_bready;

   wire [CTX_ID_BITS+4:0] incoming_raddr;
   wire                   incoming_arvalid;
   reg [31:0]             incoming_rdata;
   reg                    incoming_rvalid;
   wire [CTX_ID_BITS+4:0] incoming_waddr;
   wire [31:0]            incoming_wdata;
   wire                   incoming_wvalid;

   wire [CTX_ID_BITS+4:0] outgoing_raddr;
   wire                   outgoing_arvalid;
   reg [31:0]             outgoing_rdata;
   reg                    outgoing_rvalid;
   wire [CTX_ID_BITS+4:0] outgoing_waddr;
   wire [31:0]            outgoing_wdata;
   wire                   outgoing_wvalid;

   reg                    clk;
   reg                    resetn;
   reg [31:0]             rd;

   initial begin
      clk = 1'b0;
      resetn = 1'b0;
      rd = $random(SEED);

      cfg_arvalid = 1'b0;
      cfg_rready = 1'b1;
      cfg_awvalid = 1'b0;
      cfg_wvalid = 1'b0;
      cfg_bready = 1'b1;
      incoming_rvalid = 1'b0;
      outgoing_rvalid = 1'b0;
   end
   always #5 clk = ~clk;
   always #100 resetn = 1'b1;
   always @(posedge clk) begin
      rd <= $random();
   end

   route_control_reg_switch #(
       .ADDR_BITS ( ADDR_BITS ),
       .CTX_ID_BITS ( CTX_ID_BITS )
   ) dut (
       .*
   );

   task static write_regs();
      logic [ADDR_BITS-1:0] addr = 0;
      logic                 end_input = 0;
      logic                 end_output = 0;
      logic [31:0]          data;
      logic [31:0]          incoming_data_saved[0:255];
      logic [31:0]          outgoing_data_saved[0:255];
      logic [CTX_ID_BITS+4:0] incoming_addr_saved[0:255];
      logic [CTX_ID_BITS+4:0] outgoing_addr_saved[0:255];
      logic [7:0]             incoming_awpos = 0, incoming_wpos = 0, incoming_rpos = 0;
      logic [7:0]             outgoing_awpos = 0, outgoing_wpos = 0, outgoing_rpos = 0;
      logic                   wvalid, awvalid;
      logic [1:0]             stats = 0;
      logic [7:0]             idle_count = 0;

      while (!end_output) @(posedge clk) begin
         if (~stats[0] && !end_input) begin
            awvalid = ABITS > 0 ? &rd[4+:ABITS_MOD] : 1'b1;
            stats[0] = awvalid;
            cfg_awvalid <= awvalid;
            cfg_awaddr <= addr;
         end else begin
            cfg_awvalid <= cfg_awvalid & ~cfg_awready;
         end
         if (cfg_awvalid & cfg_awready) begin
            if (cfg_awaddr[ADDR_BITS-1:CTX_ID_BITS+7] == 'd0) begin
               incoming_addr_saved[incoming_awpos++] <= cfg_awaddr[CTX_ID_BITS+6:2];
            end else if (cfg_awaddr[ADDR_BITS-1:CTX_ID_BITS+7] == {1'b1, {ADDR_BITS-CTX_ID_BITS-8{1'b0}}}) begin
               outgoing_addr_saved[outgoing_awpos++] <= cfg_awaddr[CTX_ID_BITS+6:2];
            end
         end
         if (~stats[1] && !end_input) begin
            wvalid = DBITS > 0 ? &rd[8+:DBITS_MOD] : 1'b1;
            stats[1] = wvalid;
            cfg_wvalid <= wvalid;
            cfg_wdata <= rd;
         end else begin
            cfg_wvalid <= cfg_wvalid & ~cfg_wready;
         end
         if (cfg_wvalid & cfg_wready) begin
            if (addr[ADDR_BITS-1:CTX_ID_BITS+7] == 'd0) begin
               incoming_data_saved[incoming_wpos++] = cfg_wdata;
            end else if (addr[ADDR_BITS-1:CTX_ID_BITS+7] == {1'b1, {ADDR_BITS-CTX_ID_BITS-8{1'b0}}}) begin
               outgoing_data_saved[outgoing_wpos++] = cfg_wdata;
            end
         end
         if (cfg_bvalid & cfg_bready) begin
            stats = 'd0;
            addr += 4;
            if (addr == 0) end_input = 1;
         end
         cfg_bready <= BBITS > 0 ? &rd[12+:BBITS_MOD] : 1'b1;

         if (incoming_wvalid) begin
            if (incoming_waddr !== incoming_addr_saved[incoming_rpos] ||
                incoming_wdata !== incoming_data_saved[incoming_rpos]) begin
               $error("%d: incoming %h %h, %h %h", $time, incoming_waddr, incoming_addr_saved[incoming_rpos],
                      incoming_wdata, incoming_data_saved[incoming_rpos]);
            end
            incoming_rpos++;
         end
         if (outgoing_wvalid) begin
            if (outgoing_waddr !== outgoing_addr_saved[outgoing_rpos] ||
                outgoing_wdata !== outgoing_data_saved[outgoing_rpos]) begin
               $error("%d: outgoing %h %h, %h %h", $time, outgoing_waddr, outgoing_addr_saved[outgoing_rpos],
                      outgoing_wdata, outgoing_data_saved[outgoing_rpos]);
            end
            outgoing_rpos++;
         end
         if (end_input && ~incoming_wvalid && ~outgoing_wvalid) begin
            idle_count++;
            if (&idle_count) end_output = 1;
         end else begin
            idle_count = 0;
         end
      end
   endtask

   task static read_regs();
      logic [ADDR_BITS-1:0] addr = 0;
      logic                 end_input = 0;
      logic [31:0]          data;
      logic [31:0]          data_saved[0:255];
      logic [7:0]           wpos = 0, rpos = 0;
      logic                 irvalid, orvalid, arvalid;
      logic                 stats = 0;

      while (!end_input) @(posedge clk) begin
         if (~stats) begin
            arvalid = ABITS > 0 ? &rd[16+:ABITS_MOD] : 1'b1;
            stats = arvalid;
            cfg_arvalid <= arvalid;
            cfg_araddr <= addr;
         end else begin
            cfg_arvalid <= cfg_arvalid & ~cfg_arready;
         end
         if (incoming_arvalid) irvalid = 1'b1;
         if (outgoing_arvalid) orvalid = 1'b1;

         if (irvalid && (DBITS > 0 ? &rd[20+:DBITS_MOD] : 1'b1)) begin
            incoming_rvalid <= 1'b1;
            incoming_rdata <= rd & 32'h0fffffff;
            irvalid = 1'b0;
            data_saved[wpos] <= rd & 32'h0fffffff;
            wpos++;
         end else begin
            incoming_rvalid <= 1'b0;
         end
         if (orvalid && (DBITS > 0 ? &rd[24+:DBITS_MOD] : 1'b1)) begin
            outgoing_rvalid <= 1'b1;
            outgoing_rdata <= rd | 32'hf0000000;
            orvalid = 1'b0;
            data_saved[wpos] <= rd | 32'hf0000000;
            wpos++;
         end else begin
            outgoing_rvalid <= 1'b0;
         end
         if (cfg_rvalid & cfg_rready) begin
            if (cfg_rdata[31:28] != 4'hd) begin
               if (cfg_rdata !== data_saved[rpos]) begin
                  $error("%d: %h: %h %h", $time, addr, cfg_rdata, data_saved[rpos]);
               end
               rpos++;
               if (addr[ADDR_BITS-1:CTX_ID_BITS+7] == 0 && cfg_rdata[31:28] !== 0) begin
                  $error("%d: incoming %h: %h", $time, addr, cfg_rdata);
               end
               if (addr[ADDR_BITS-1:CTX_ID_BITS+7] == {1'b1, {ADDR_BITS-CTX_ID_BITS-8{1'b0}}} && cfg_rdata[31:28] !== 4'hf) begin
                  $error("%d: outgoing %h: %h", $time, addr, cfg_rdata);
               end
            end else if (addr[ADDR_BITS-2:CTX_ID_BITS+7] === 0) begin
               $error("%d: invalid area %h: %h", $time, addr, cfg_rdata);
            end
            stats = 1'b0;
            addr += 4;
            if (addr == 0) end_input = 1;
         end
         cfg_rready <= BBITS > 0 ? &rd[28+:BBITS_MOD] : 1'b1;
      end
   endtask

   initial begin
      @(posedge clk);
      while (~resetn) @(posedge clk);

      fork
         begin
            write_regs();
         end
         begin
            read_regs();
         end
      join

      $finish();
   end

endmodule

module test_reg_switch_fast;
   tb_route_control_reg_switch tb();
endmodule

module test_reg_switch_random;
   tb_route_control_reg_switch #(
       .ABITS ( 1 ),
       .DBITS ( 1 ),
       .BBITS ( 1 )
   ) tb ();
endmodule
