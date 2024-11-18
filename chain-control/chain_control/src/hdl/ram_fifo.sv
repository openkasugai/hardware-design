/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

module ram_fifo #(
  parameter int DATA_WIDTH= 32        ,
  parameter int DEPTH     = 16        ,
  parameter int AFULL_TH  = DEPTH - 4 ,
  parameter int AEMPTY_TH = 4         ,
  parameter int SIZE_WIDTH= $clog2(DEPTH+1)
) (
  input   wire                rstn    ,
  input   wire                clk     ,
  output  wire                afull   ,
  output  wire                aempty  ,
  output  wire[SIZE_WIDTH-1:0]written ,
  output  wire[SIZE_WIDTH-1:0]readable,
  output  wire                wr_ready,
  input   wire                wr_valid,
  input   wire[DATA_WIDTH-1:0]wr_data ,
  input   wire                rd_ready,
  output  wire                rd_valid,
  output  wire[DATA_WIDTH-1:0]rd_data
);
  localparam int ADDR_WIDTH = $clog2(DEPTH);
  localparam int ACPT_LATENCY = 4;
  localparam int RAM_RD_LATENCY = 2;
  
  reg r_wr_ready;
  
  wire w_wr_strb, w_wr_strb_d;
  wire w_rd_strb, w_rd_strb_d;
  wire w_rd_cken;
  
  assign w_wr_strb = r_wr_ready & wr_valid;
  
  reg[ADDR_WIDTH-1:0] r_wr_ptr;
  reg[SIZE_WIDTH-1:0] r_written;
  reg[ACPT_LATENCY-1:0] r_wr_strb_d;
  reg r_afull;
  always_ff @(posedge clk) begin
    if (!rstn) begin
      r_wr_ptr <= '0;
      r_wr_strb_d <= '0;
      r_written <= '0;
      r_wr_ready <= '0;
      r_afull <= '0;
    end else begin
      if (w_wr_strb) begin
        if (r_wr_ptr < DEPTH - 1) begin
          r_wr_ptr <= r_wr_ptr + 'd1;
        end else begin
          r_wr_ptr <= '0;
        end
      end
      
      if (w_wr_strb && !w_rd_strb_d) begin
        r_written <= r_written + 'd1;
        r_wr_ready <= r_written < DEPTH - 1;
      end else if (!w_wr_strb && w_rd_strb_d) begin
        r_written <= r_written - 'd1;
        r_wr_ready <= '1;
      end else begin
        r_wr_ready <= r_written < DEPTH;
      end
      
      r_afull <= r_written > AFULL_TH;
      
      r_wr_strb_d <= {r_wr_strb_d[ACPT_LATENCY-2:0], w_wr_strb};
    end
  end
  assign wr_ready = r_wr_ready;
  assign written = r_written;
  assign afull = r_afull;
  assign w_wr_strb_d = r_wr_strb_d[ACPT_LATENCY-1];
  
  reg[ADDR_WIDTH-1:0] r_rd_ptr;
  
  wire[DATA_WIDTH-1:0] w_rd_data;
  ram_fifo_sdpram #(
    .DATA_WIDTH (DATA_WIDTH ),
    .ADDR_WIDTH (ADDR_WIDTH ),
    .DEPTH      (DEPTH      )
  ) u_ram (
    .clk    (clk        ), // input
    .wr_en  (w_wr_strb  ), // input
    .wr_addr(r_wr_ptr   ), // input [ADDR_WIDTH-1:0]
    .wr_data(wr_data    ), // input [DATA_WIDTH-1:0]
    .rd_en  (w_rd_cken  ), // input
    .rd_addr(r_rd_ptr   ), // input [ADDR_WIDTH-1:0]
    .rd_data(rd_data    )  // output[DATA_WIDTH-1:0]
  );
  
  reg[SIZE_WIDTH-1:0] r_fetchable;
  reg[RAM_RD_LATENCY-1:0][SIZE_WIDTH-1:0] r_fetchable_d;
  reg r_fetch_en;
  reg[RAM_RD_LATENCY-1:0] r_fetch_en_d;
  reg[ACPT_LATENCY-1:0] r_rd_strb_d;
  reg r_aempty;

  assign w_rd_strb = w_rd_cken & r_fetch_en_d[RAM_RD_LATENCY-1];

  always_ff @(posedge clk) begin
    if (!rstn) begin
      r_rd_ptr <= '0;
      r_fetchable <= '0;
      r_fetchable_d <= '0;
      r_fetch_en <= '0;
      r_fetch_en_d <= '0;
      r_rd_strb_d <= '0;
      r_aempty <= '0;
    end else begin
      if (w_rd_cken) begin
        if (r_fetch_en) begin
          if (r_rd_ptr < DEPTH - 1) begin
            r_rd_ptr <= r_rd_ptr + 'd1;
          end else begin
            r_rd_ptr <= '0;
          end
        end
        
        r_fetch_en_d <= {r_fetch_en_d[RAM_RD_LATENCY-2:0], r_fetch_en};
      end
      
      if (w_rd_cken && r_fetch_en && !w_wr_strb_d) begin
        r_fetchable <= r_fetchable - 'd1;
        r_fetch_en <= r_fetchable > 'd1;
      end else if (!(w_rd_cken && r_fetch_en) && w_wr_strb_d) begin
        r_fetchable <= r_fetchable + 'd1;
        r_fetch_en <= '1;
      end else begin
        r_fetch_en <= r_fetchable > '0;
      end
      
      r_rd_strb_d <= {r_rd_strb_d[ACPT_LATENCY-2:0], w_rd_strb};
      
      r_fetchable_d <= {r_fetchable_d[RAM_RD_LATENCY-2:0], r_fetchable};
      
      r_aempty <= r_fetchable_d[RAM_RD_LATENCY-1] < AEMPTY_TH;
    end
  end
  assign w_rd_strb_d = r_rd_strb_d[ACPT_LATENCY-1];
  wire w_rd_valid = r_fetch_en_d[RAM_RD_LATENCY-1];
  assign rd_valid = w_rd_valid;
  assign readable = r_fetchable_d[RAM_RD_LATENCY-1];
  assign aempty = r_aempty;
  
  assign w_rd_cken = rd_ready || !w_rd_valid;
endmodule

module ram_fifo_sdpram #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 10,
    parameter int DEPTH      = 1 << ADDR_WIDTH
) (
    input   wire                    clk     ,
    input   wire                    wr_en   ,
    input   wire[ADDR_WIDTH-1:0]    wr_addr ,
    input   wire[DATA_WIDTH-1:0]    wr_data ,
    input   wire                    rd_en   ,
    input   wire[ADDR_WIDTH-1:0]    rd_addr ,
    output  wire[DATA_WIDTH-1:0]    rd_data
);

reg[DATA_WIDTH-1:0] mem [0:DEPTH-1];

logic r_wr_en;
logic[ADDR_WIDTH-1:0] r_wr_addr;
logic[DATA_WIDTH-1:0] r_wr_data;
always_ff @(posedge clk) begin
    r_wr_en <= wr_en;
    r_wr_addr <= wr_addr;
    r_wr_data <= wr_data;
end

always_ff @(posedge clk) begin
    if (r_wr_en) begin
        mem[r_wr_addr] <= r_wr_data;
    end
end

logic[ADDR_WIDTH-1:0] r_rd_addr;
logic[DATA_WIDTH-1:0] r_rd_data;
always_ff @(posedge clk) begin
    if (rd_en) begin
        r_rd_addr <= rd_addr;
        r_rd_data <= mem[r_rd_addr];
    end
end
assign rd_data = r_rd_data;

endmodule

`default_nettype wire
