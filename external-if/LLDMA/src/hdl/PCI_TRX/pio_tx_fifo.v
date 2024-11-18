/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module pio_tx_fifo #(
  parameter ENABLE_BE = 0
  ) (

  input                          user_clk,
  input                          reset_n,

  input                          i_tvalid,
  input                [511:0]   i_tdata,
  input                          i_tlast,
  input                 [15:0]   i_tkeep,
  input                 [3:0]    i_be,
  output wire                    o_tready,
  output wire                    o_wr_ptr,
  output wire                    o_rd_ptr,

  output wire                    o_rq_axis_tvalid,
  output wire          [511:0]   o_rq_axis_tdata,
  output wire                    o_rq_axis_tlast,
  output wire           [15:0]   o_rq_axis_tkeep,
  output wire            [3:0]   o_rq_axis_be,

  input                          i_tkn,
  output wire                    o_req

  );


  reg   [1:0] fifo_cnt;
  reg         wr_ptr;
  reg         rd_ptr;

  reg  [1:0]        fifo_tvalid ;
  reg  [511:0] fifo_tdata[1:0]  ;
  reg  [1:0]        fifo_tlast  ;
  reg  [15:0]  fifo_tkeep[1:0]  ;

  integer          i;

  // --------------------------------------------
  // FIFO COUNT
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n) 
  begin
    if(!reset_n)begin
      fifo_cnt <= 0;
    end else begin
      if ((i_tvalid && o_tready) && (i_tkn)) begin
        fifo_cnt <= fifo_cnt;
      end else if (i_tvalid && o_tready) begin
        fifo_cnt <= fifo_cnt + 1'b1;
      end else if (i_tkn) begin
        fifo_cnt <= fifo_cnt - 1'b1;
      end
    end
  end

  // --------------------------------------------
  // COUNT FULL
  // --------------------------------------------

  assign o_tready = ~fifo_cnt[1];

  // --------------------------------------------
  // COUNT != 0
  // --------------------------------------------

  assign o_req = | fifo_cnt;

  // --------------------------------------------
  // WPTR
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n) 
  begin
    if(!reset_n)begin
      wr_ptr <= 0;
    end else begin
      if (i_tvalid && o_tready) begin
        if (wr_ptr == 1'b1) begin
          wr_ptr <= 1'b0;
        end else begin
          wr_ptr <= wr_ptr + 1'b1;
        end
      end
    end
  end

  // --------------------------------------------
  // RPTR
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n) 
  begin
    if(!reset_n)begin
      rd_ptr <= 0;
    end else begin
      if (i_tkn) begin
        if (rd_ptr == 1'b1) begin
          rd_ptr <= 1'b0;
        end else begin
          rd_ptr <= rd_ptr + 1'b1;
        end
      end
    end
  end

  // --------------------------------------------
  // FIFO
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n) 
  begin
    if(!reset_n)begin
      for (i=0; i<2; i=i+1) begin
        fifo_tvalid[i]       <= 1'b0;
        fifo_tdata[i][511:0] <= 512'b0;
        fifo_tlast[i]        <= 1'b0;
        fifo_tkeep[i][15:0]  <= 16'b0;
      end
    end else if (i_tvalid && o_tready) begin
        fifo_tvalid[wr_ptr]       <= i_tvalid;
        fifo_tdata[wr_ptr][511:0] <= i_tdata[511:0];
        fifo_tlast[wr_ptr]        <= i_tlast;
        fifo_tkeep[wr_ptr][15:0]  <= i_tkeep[15:0];
    end else begin
    end
  end

  generate
    if (ENABLE_BE>0) begin
      reg [3:0] fifo_be[1:0];
      always @(posedge user_clk or negedge reset_n)
      begin
        if(!reset_n)begin
           for (i=0; i<2; i=i+1) begin
             fifo_be[i][3:0] <= 4'd0;
           end
        end else if (i_tvalid && o_tready) begin
           fifo_be[wr_ptr][3:0] <= i_be[3:0];
        end
       end
       assign o_rq_axis_be[3:0]  = (i_tkn == 1'b1) ? fifo_be[rd_ptr][3:0]  : 4'b0;
    end
  endgenerate

  assign o_rq_axis_tvalid       = (i_tkn == 1'b1) ? fifo_tvalid[rd_ptr]       : 1'b0;
  assign o_rq_axis_tdata[511:0] = (i_tkn == 1'b1) ? fifo_tdata[rd_ptr][511:0] : 512'b0;
  assign o_rq_axis_tlast        = (i_tkn == 1'b1) ? fifo_tlast[rd_ptr]        : 1'b0;
  assign o_rq_axis_tkeep[15:0]  = (i_tkn == 1'b1) ? fifo_tkeep[rd_ptr][15:0]  : 16'b0;

  // --------------------------------------------
  // WPTR/RPTR OUTPUT TO DMA_TX
  // --------------------------------------------

  assign o_wr_ptr = wr_ptr;
  assign o_rd_ptr = rd_ptr;

endmodule // pio_tx_fifo
