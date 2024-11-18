/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module dma_tx_mux # (
  parameter CHAIN_NUM   = 4
  )
  (
  input  logic                    user_clk
 ,input  logic                    reset_n

 ,input  logic    [CHAIN_NUM-1:0] tvalid_in
 ,input  logic    [CHAIN_NUM-1:0] tlast_in
 ,input  logic            [511:0] tdata_in [CHAIN_NUM-1:0]
 ,output logic    [CHAIN_NUM-1:0] tready_in
 ,output logic    [CHAIN_NUM-1:0] rq_pend

 ,output  logic                   tvalid_out
 ,output  logic                   tlast_out
 ,output  logic           [511:0] tdata_out
 ,input   logic                   tready_out
 ,input   logic                   trx_fifo_rd_ptr
);

  logic [CHAIN_NUM-1:0] s0_next_s1v;
  logic [CHAIN_NUM-1:0] s0_set_s1d;

  logic [CHAIN_NUM-1:0] s1_tvalid;
  logic [CHAIN_NUM-1:0] s1_tlast;
  logic         [511:0] s1_tdata[CHAIN_NUM-1:0];

  logic [CHAIN_NUM-1:0] s01_tvalid;
  logic                 s01_tvalid_or;
  logic                 s01_tlast;
  logic         [511:0] s01_tdata;

  logic [CHAIN_NUM-1:0] s01_sel;
  logic [CHAIN_NUM-1:0] s01_sel_term1;
  logic [CHAIN_NUM-1:0] s01_sel_term2;
  logic                 s01_arb_inh;
  logic                 s01_arb_tkn;
  logic                 s01_next_s2v;
  logic                 s01_set_s2d;

  logic [CHAIN_NUM-1:0] s2_sel;
  logic                 s2_tvalid;
  logic                 s2_tlast;
  logic         [511:0] s2_tdata;
  logic                 s2_next_s3v;
  logic                 s2_set_s3d;

  logic [CHAIN_NUM-1:0] s3_sel;

  logic                 trx_fifo_rd_ptr_1t;
  logic                 trx_fifo_re_1t;
  logic                 trx_fifo_we;
  logic           [2:0] fifo_we_vec;
  logic           [2:0] fifo_v;
  logic [CHAIN_NUM-1:0] fifo_data[3:0];


// Register access IF ///////////////////////////////////////////////////////////////////////

  always_comb begin
    for (int i = 0; i < CHAIN_NUM; i++) begin
      s0_set_s1d[i]  =  tvalid_in[i] && (~s1_tvalid[i]) && (s2_tvalid || (~s01_sel[i]));
      s0_next_s1v[i] = (tvalid_in[i] ||   s1_tvalid[i]) && (s2_tvalid || (~s01_sel[i]));
    end
  end

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      s1_tvalid     <= '0;
      s1_tlast      <= '0;
      for (int i = 0; i < (CHAIN_NUM); i++) begin
    s1_tdata[i]      <= '0;
      end
      s01_arb_inh   <= '0;
      s01_sel_term2 <= '0;
    end 
    else begin
      for (int i = 0; i < (CHAIN_NUM); i++) begin
        s1_tvalid[i]  <= s0_next_s1v[i];
        if(s0_set_s1d[i]) begin
          s1_tlast[i]  <= tlast_in[i];
          s1_tdata[i]  <= tdata_in[i];
        end
      end
      if(s01_tvalid_or && (~s2_tvalid)) begin
        s01_arb_inh  <= ~ s01_tlast;
      end
      if(s01_arb_tkn) begin
        s01_sel_term2 <= s01_sel_term1;
      end
    end
  end

  assign tready_in = ~ s1_tvalid;

  assign s01_tvalid    = tvalid_in | s1_tvalid;
  assign s01_tvalid_or = |(s01_tvalid & s01_sel);
  assign s01_arb_tkn   = (|s01_tvalid) && (~s2_tvalid) && (~s01_arb_inh);

  enqdeq_arb #( .N(CHAIN_NUM)) rq_arb(
      .user_clk(user_clk),
      .reset_n(reset_n),
      .req(s01_tvalid),
      .tkn_ack(s01_arb_tkn),
      .tkn(s01_sel_term1)
  );

  assign s01_sel = s01_arb_tkn ? s01_sel_term1 : s01_sel_term2;

  always_comb begin
    s01_tlast = '0; 
    s01_tdata = '0; 
    s01_tlast = '0; 
    for (int i = 0; i < CHAIN_NUM; i++) begin
      if(s01_sel[i]) begin
        s01_tlast = s1_tvalid[i] ? s1_tlast[i] : tlast_in[i];
        s01_tdata = s1_tvalid[i] ? s1_tdata[i] : tdata_in[i];
      end
    end
  end

  assign s01_set_s2d  = (s01_tvalid_or && (~s2_tvalid) &&   tvalid_out && (~tready_out));
  assign s01_next_s2v = (s2_tvalid && tvalid_out && (~tready_out)) || s01_set_s2d;
  assign s2_set_s3d   = (s01_tvalid_or && (~s2_tvalid) && (~tvalid_out))                 || 
                        (s01_tvalid_or && (~s2_tvalid) &&   tvalid_out &&   tready_out ) ||
                        (                   s2_tvalid  &&   tvalid_out &&   tready_out );
  assign s2_next_s3v  = (tvalid_out && (~tready_out)) || s2_set_s3d;

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      s2_sel     <= '0;
      s2_tvalid  <= '0;
      s2_tlast   <= '0;
      s2_tdata   <= '0;
      s3_sel     <= '0;
      tvalid_out <= '0;
      tlast_out  <= '0;
      tdata_out  <= '0;
    end
    else begin 
      s2_tvalid  <= s01_next_s2v;
      tvalid_out <= s2_next_s3v;
      if(s01_set_s2d) begin
        s2_sel   <= s01_sel;
        s2_tlast <= s01_tlast;
        s2_tdata <= s01_tdata;
      end
      if(s2_set_s3d) begin
        s3_sel    <= s2_tvalid ? s2_sel   : s01_sel;
        tlast_out <= s2_tvalid ? s2_tlast : s01_tlast;
        tdata_out <= s2_tvalid ? s2_tdata : s01_tdata;
      end
    end
  end

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      trx_fifo_rd_ptr_1t <= '0;
    end
    else begin
      trx_fifo_rd_ptr_1t <= trx_fifo_rd_ptr;
    end
  end

  assign trx_fifo_we    = tvalid_out && tready_out;
  assign trx_fifo_re_1t = (trx_fifo_rd_ptr != trx_fifo_rd_ptr_1t);
  assign fifo_v[0]      = |fifo_data[0];
  assign fifo_v[1]      = |fifo_data[1];
  assign fifo_v[2]      = |fifo_data[2];

  assign fifo_we_vec[0] = trx_fifo_we && (trx_fifo_re_1t ? ((~fifo_v[1]) && fifo_v[0]) :   (~fifo_v[0]));
  assign fifo_we_vec[1] = trx_fifo_we && (trx_fifo_re_1t ? ((~fifo_v[2]) && fifo_v[1]) :  ((~fifo_v[1]) && fifo_v[0]));
  assign fifo_we_vec[2] = trx_fifo_we && (trx_fifo_re_1t ? (                fifo_v[2]) :  ((~fifo_v[2]) && fifo_v[1]));
  assign fifo_data[3]   = '0;

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      for (int i = 0; i < 3; i++) begin
    fifo_data[i] <= '0;
      end
    end 
    else begin
      for (int i = 0; i < 3; i++) begin
    fifo_data[i] <= fifo_we_vec[i] ? s3_sel : trx_fifo_re_1t ? fifo_data[i+1] : fifo_data[i];
      end
    end
  end

  always_comb begin
    for (int i = 0; i < CHAIN_NUM; i++) begin
      rq_pend[i] = s1_tvalid[i] || (s2_tvalid && s2_sel[i]) || (tvalid_out && s3_sel[i]) ||
                   fifo_data[0][i] || fifo_data[1][i] || fifo_data[2][i];
    end
  end

endmodule
