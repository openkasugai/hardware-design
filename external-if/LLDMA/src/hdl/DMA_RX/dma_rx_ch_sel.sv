/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module dma_rx_ch_sel #(
  parameter CH_NUM    = 32,             // 8,16,24,32
  parameter LN_NUM    = CH_NUM / 8,     // 1-4
  parameter CID_WIDTH = $clog2(CH_NUM),
  parameter LID_WIDTH = $clog2(LN_NUM)
// +--------+--------+-----------+-----------+---------------+---------------------+-------------+
// | CH_NUM | LN_NUM | CID_WIDTH | LID_WIDTH | m of CID[m:0] | n of ch-sig[n:0][*] | this module |
// |        |        |           |           | = CID_WIDTH-1 | = CH_NUM-1          | output use  |
// +--------+--------+-----------+-----------+---------------+---------------------+-------------+
// |    8   |    1   |    3      |    0      |     2         |       7             |     use     |
// |   16   |    2   |    4      |    1      |     3         |      15             |     use     |
// |   24   |    3   |    5      |    2      |     4         |      23             |     use     |
// |   32   |    4   |    5      |    2      |     4         |      31             |     use     |
// +--------+--------+-----------+-----------+---------------+---------------------+-------------+
)(
  input  logic                 user_clk,
  input  logic                 reset_n,

  input  logic                 chx_pkt_send_valid[CH_NUM-1:0],
  input  logic                 pkt_send_go_1tc,

  output logic [CID_WIDTH-1:0] pkt_send_cid_2tc,
  output logic [31:0]          chx_lru_state[31:0]
);

// (example) chx_lru_state for CH_NUM = 3 
// chA = own CH
// chB = opposite CH
//         +-----------+
//         |  j:chB    |
//         +---+---+---+               chA  chB
//         | 0 | 1 | 2 |                |    |
// +---+---+---+---+---+                V    V
// | i | 0 | - | * | * | chx_lru_state[0][0,1,2]    0: chA > chB
// | ..+---+---+---+---+                            1: chA < chB
// |   | 1 | @ | - | * | chx_lru_state[1][0,1,2]
// |chA+---+---+---+---+                            *: FF exist(init=0)
// |   | 2 | @ | @ | - | chx_lru_state[2][0,1,2]    @: FF exist(inversion of *, init=1)
// +---+---+---+---+---+                            -: FF exist(unused due to chA=chB, always 0)
  logic                 lnx_pkt_send_valid[LN_NUM-1:0];
  logic [LN_NUM-1:0]    lnx_lru_state[LN_NUM-1:0];
  logic [LN_NUM-1:0]    lnx_pkt_send_win;
  logic [CH_NUM-1:0]    chx_pkt_send_valid_lnx_win;
  logic [CH_NUM-1:0]    chx_pkt_send_win;
  logic [CH_NUM-1:0]    chx_pkt_send_win_1tc;
  logic [LID_WIDTH-1:0] pkt_send_lid;
  logic [LID_WIDTH-1:0] pkt_send_lid_1tc;
  logic [LID_WIDTH-1:0] pkt_send_lid_2tc;
  logic [CID_WIDTH-1:0] pkt_send_cid_1tc;

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      for (int i = 0; i < LN_NUM; i++) begin
        for (int j = 0; j < LN_NUM; j++) begin
          if (j < i) begin
            lnx_lru_state[i][j] <= 1'b1;
          end else begin
            lnx_lru_state[i][j] <= 1'b0;
          end
        end
      end
      for (int i = 0; i < 32; i++) begin
        for (int j = 0; j < 32; j++) begin
          if (j < i) begin
            chx_lru_state[i][j] <= 1'b1;
          end else begin
            chx_lru_state[i][j] <= 1'b0;
          end
        end
      end
      pkt_send_lid_1tc     <= '0;
      chx_pkt_send_win_1tc <= '0;
      pkt_send_cid_2tc     <= '0;
    end else begin
      if (pkt_send_go_1tc == 1'b1) begin
        for (int j = 0; j < LN_NUM; j++) begin
          if (j != pkt_send_lid_2tc) begin
            lnx_lru_state[pkt_send_lid_2tc][j] <= 1'b1;
            lnx_lru_state[j][pkt_send_lid_2tc] <= 1'b0;
          end
        end
        for (int j = 0; j < CH_NUM; j++) begin
          if (((j >> 3) == pkt_send_lid_2tc) && (j != pkt_send_cid_2tc)) begin
            chx_lru_state[pkt_send_cid_2tc][j] <= 1'b1;
            chx_lru_state[j][pkt_send_cid_2tc] <= 1'b0;
          end
        end
      end
      pkt_send_lid_1tc     <= pkt_send_lid;
      pkt_send_lid_2tc     <= pkt_send_lid_1tc;
      chx_pkt_send_win_1tc <= chx_pkt_send_win;
      pkt_send_cid_2tc     <= pkt_send_cid_1tc;
    end
  end

  always_comb begin
    for (int i = 0; i < LN_NUM; i++) begin
      lnx_pkt_send_valid[i] = 1'b0;
      for (int k = 0; k < 8; k++) begin
        lnx_pkt_send_valid[i] = lnx_pkt_send_valid[i] | chx_pkt_send_valid[(i << 3) + k];
        lnx_pkt_send_win[i] = lnx_pkt_send_valid[i];
      end
    end
    for (int i = 0; i < LN_NUM; i++) begin
      for (int j = 0; j < LN_NUM; j++) begin
        if (j != i) begin
          lnx_pkt_send_win[i] = lnx_pkt_send_win[i] & (~lnx_pkt_send_valid[j] | ~lnx_lru_state[i][j]);
        end
      end
    end
    pkt_send_lid = '0;
    for (int i = 0; i < LN_NUM; i++) begin
      if (lnx_pkt_send_win[i] == 1'b1) begin
        pkt_send_lid = i;
      end
    end
    for (int i = 0; i < CH_NUM; i++) begin
      chx_pkt_send_valid_lnx_win[i] = lnx_pkt_send_win[i >> 3] & chx_pkt_send_valid[i];
      chx_pkt_send_win[i] = chx_pkt_send_valid_lnx_win[i];
    end
    for (int i = 0; i < CH_NUM; i++) begin
      for (int j = 0; j < CH_NUM; j++) begin
        if (j != i) begin
          chx_pkt_send_win[i] = chx_pkt_send_win[i] & (~chx_pkt_send_valid_lnx_win[j] | ~chx_lru_state[i][j]);
        end
      end
    end
    pkt_send_cid_1tc = '0;
    for (int i = 0; i < CH_NUM; i++) begin
      if (chx_pkt_send_win_1tc[i] == 1'b1) begin
        pkt_send_cid_1tc = i;
      end
    end
  end

endmodule
