/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module pio_mem_fifo
  (

  input                          user_clk,
  input                          reset_n,

  input                          i_req_valid,
  input                          i_ack_valid,
  input                [511:0]   i_data,
  output wire                    o_tready,

  output wire                    o_req_valid,
  output wire                    o_ack_valid,
  output wire          [511:0]   o_data,

  input                          i_tkn,
  output wire                    o_req

  );


  reg  [1:0]    fifo_cnt;
  reg           wr_ptr;
  reg           rd_ptr;

  reg  [1:0]    fifo_req_valid ;
  reg  [1:0]    fifo_ack_valid ;
  reg  [511:0]  fifo_data[1:0] ;

  integer       i;

  wire i_valid_or;

  assign i_valid_or = i_req_valid | i_ack_valid;


  // --------------------------------------------
  // FIFO COUNT
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n) 
  begin
    if(!reset_n)begin
      fifo_cnt <= 0;
    end else begin
      if ((i_valid_or && o_tready) && (i_tkn)) begin
        fifo_cnt <= fifo_cnt;
      end else if (i_valid_or && o_tready) begin
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
      if (i_valid_or && o_tready) begin
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
        fifo_req_valid[i]    <= 1'b0;
        fifo_ack_valid[i]    <= 1'b0;
        fifo_data[i][511:0]  <= 512'b0;
      end
    end else if (i_valid_or && o_tready) begin
        fifo_req_valid[wr_ptr]      <= i_req_valid;
        fifo_ack_valid[wr_ptr]      <= i_ack_valid;
        fifo_data[wr_ptr][511:0]    <= i_data[511:0];
    end else begin
    end
  end

  assign o_req_valid    = (i_tkn == 1'b1) ? fifo_req_valid[rd_ptr]    : 1'b0;
  assign o_ack_valid    = (i_tkn == 1'b1) ? fifo_ack_valid[rd_ptr]    : 1'b0;
  assign o_data[511:0]  = (i_tkn == 1'b1) ? fifo_data[rd_ptr][511:0]  : 512'b0;

endmodule // pio_mem_fifo
