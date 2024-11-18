/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module cif_dn_data_in #(
  parameter CH_NUM     = 32
)(
  input  logic         user_clk,
  input  logic         reset_n,

///// DMA_RX for mode0,1
  input  logic         d2c_axis_tvalid,
  input  logic [511:0] d2c_axis_tdata,
  input  logic [ 15:0] d2c_axis_tuser,

  output logic         d2c_axis_tready,

///// axis2axi_bridge for mode2
  input  logic         s_axis_direct_tvalid,
  input  logic [511:0] s_axis_direct_tdata,
  input  logic [ 15:0] s_axis_direct_tuser,

  output logic         s_axis_direct_tready,

///// CIF_DN data FIFO
  output logic         fifo_in_axis_tvalid,
  output logic [511:0] fifo_in_axis_tdata,
  output logic [ 15:0] fifo_in_axis_tuser,

  input  logic         cif_dn_in_axis_tready,

///// clear
  output logic [CH_NUM-1:0] cif_dn_data_in_busy
);

  localparam CH_NUM_W = $clog2(CH_NUM);

///// DMA_RX for mode0,1
  logic         d2c_axis_tvalid_hld;
  logic [511:0] d2c_axis_tdata_hld;
  logic [ 15:0] d2c_axis_tuser_hld;
  logic         d2c_axis_tvalid_nxt_hld;
  logic [511:0] d2c_axis_tdata_nxt_hld;
  logic [ 15:0] d2c_axis_tuser_nxt_hld;
  logic         d2c_axis_tvalid_arb_sop_enb;
  logic         d2c_axis_tvalid_arb_eop_mc;
  logic         d2c_axis_tvalid_arb_win;
  logic         d2c_axis_tvalid_arb_win_mc;
  logic         d2c_axis_tvalid_back;
  logic [511:0] d2c_axis_tdata_back_hld;
  logic [ 15:0] d2c_axis_tuser_back_hld;

///// axis2axi_bridge for mode2
  logic         s_axis_direct_tvalid_hld;
  logic [511:0] s_axis_direct_tdata_hld;
  logic [ 15:0] s_axis_direct_tuser_hld;
  logic         s_axis_direct_tvalid_nxt_hld;
  logic [511:0] s_axis_direct_tdata_nxt_hld;
  logic [ 15:0] s_axis_direct_tuser_nxt_hld;
  logic         s_axis_direct_tvalid_arb_sop_enb;
  logic         s_axis_direct_tvalid_arb_eop_mc;
  logic         s_axis_direct_tvalid_arb_win;
  logic         s_axis_direct_tvalid_arb_win_mc;
  logic         s_axis_direct_tvalid_back;
  logic [511:0] s_axis_direct_tdata_back_hld;
  logic [ 15:0] s_axis_direct_tuser_back_hld;

///// arbiter
  logic         arb_enb;
  logic         direct_sel;
  logic         direct_sel_hld;
  logic         direct_sel_1tc;

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      d2c_axis_tvalid_hld          <= '0;
      d2c_axis_tdata_hld           <= '0;
      d2c_axis_tuser_hld           <= '0;
      d2c_axis_tvalid_nxt_hld      <= '0;
      d2c_axis_tdata_nxt_hld       <= '0;
      d2c_axis_tuser_nxt_hld       <= '0;
      d2c_axis_tvalid_back         <= '0;
      d2c_axis_tdata_back_hld      <= '0;
      d2c_axis_tuser_back_hld      <= '0;
      s_axis_direct_tvalid_hld     <= '0;
      s_axis_direct_tdata_hld      <= '0;
      s_axis_direct_tuser_hld      <= '0;
      s_axis_direct_tvalid_nxt_hld <= '0;
      s_axis_direct_tdata_nxt_hld  <= '0;
      s_axis_direct_tuser_nxt_hld  <= '0;
      s_axis_direct_tvalid_back    <= '0;
      s_axis_direct_tdata_back_hld <= '0;
      s_axis_direct_tuser_back_hld <= '0;
      arb_enb                      <= 1'b1;
      direct_sel_hld               <= '0;
      direct_sel_1tc               <= '0;
      cif_dn_data_in_busy          <= '0;
    end else begin
      if (d2c_axis_tvalid_back == 1'b1) begin
        d2c_axis_tvalid_hld            <= 1'b1;
        d2c_axis_tdata_hld             <= d2c_axis_tdata_back_hld;
        d2c_axis_tuser_hld             <= d2c_axis_tuser_back_hld;
        if (d2c_axis_tvalid_hld == 1'b1) begin
          d2c_axis_tvalid_nxt_hld      <= 1'b1;
          d2c_axis_tdata_nxt_hld       <= d2c_axis_tdata_hld;
          d2c_axis_tuser_nxt_hld       <= d2c_axis_tuser_hld;
        end
      end else if (d2c_axis_tready == 1'b1) begin
        d2c_axis_tvalid_hld            <= d2c_axis_tvalid;
        d2c_axis_tdata_hld             <= d2c_axis_tdata;
        d2c_axis_tuser_hld             <= d2c_axis_tuser;
      end else if ((d2c_axis_tvalid_hld == 1'b1) && (direct_sel == 1'b0)) begin
        if (d2c_axis_tvalid_nxt_hld == 1'b1) begin
          d2c_axis_tvalid_hld          <= 1'b1;
          d2c_axis_tdata_hld           <= d2c_axis_tdata_nxt_hld;
          d2c_axis_tuser_hld           <= d2c_axis_tuser_nxt_hld;
          d2c_axis_tvalid_nxt_hld      <= 1'b0;
        end else begin
          d2c_axis_tvalid_hld          <= 1'b0;
        end
      end
      if (s_axis_direct_tvalid_back == 1'b1) begin
        s_axis_direct_tvalid_hld       <= 1'b1;
        s_axis_direct_tdata_hld        <= s_axis_direct_tdata_back_hld;
        s_axis_direct_tuser_hld        <= s_axis_direct_tuser_back_hld;
        if (s_axis_direct_tvalid_hld == 1'b1) begin
          s_axis_direct_tvalid_nxt_hld <= 1'b1;
          s_axis_direct_tdata_nxt_hld  <= s_axis_direct_tdata_hld;
          s_axis_direct_tuser_nxt_hld  <= s_axis_direct_tuser_hld;
        end
      end else if (s_axis_direct_tready == 1'b1) begin
        s_axis_direct_tvalid_hld       <= s_axis_direct_tvalid;
        s_axis_direct_tdata_hld        <= s_axis_direct_tdata;
        s_axis_direct_tuser_hld        <= s_axis_direct_tuser;
      end else if ((s_axis_direct_tvalid_hld == 1'b1) && (direct_sel == 1'b1)) begin
        if (s_axis_direct_tvalid_nxt_hld == 1'b1) begin
          s_axis_direct_tvalid_hld     <= 1'b1;
          s_axis_direct_tdata_hld      <= s_axis_direct_tdata_nxt_hld;
          s_axis_direct_tuser_hld      <= s_axis_direct_tuser_nxt_hld;
          s_axis_direct_tvalid_nxt_hld <= 1'b0;
        end else begin
          s_axis_direct_tvalid_hld     <= 1'b0;
        end
      end
      if ((d2c_axis_tvalid_arb_win_mc | s_axis_direct_tvalid_arb_win_mc) == 1'b1) begin
        arb_enb <= 1'b0;
      end else if ((d2c_axis_tvalid_arb_eop_mc | s_axis_direct_tvalid_arb_eop_mc) == 1'b1) begin
        arb_enb <= 1'b1;
      end
      if (d2c_axis_tvalid_arb_win == 1'b1) begin
        direct_sel_hld <= 1'b0;
      end else if (s_axis_direct_tvalid_arb_win == 1'b1) begin
        direct_sel_hld <= 1'b1;
      end
      direct_sel_1tc               <= direct_sel;
      d2c_axis_tvalid_back         <= (d2c_axis_tvalid_arb_sop_enb & direct_sel & d2c_axis_tready);
      d2c_axis_tdata_back_hld      <= d2c_axis_tdata_hld;
      d2c_axis_tuser_back_hld      <= d2c_axis_tuser_hld;
      s_axis_direct_tvalid_back    <= (s_axis_direct_tvalid_arb_sop_enb & ~direct_sel & s_axis_direct_tready);
      s_axis_direct_tdata_back_hld <= s_axis_direct_tdata_hld;
      s_axis_direct_tuser_back_hld <= s_axis_direct_tuser_hld;
      for (int i=0 ; i<CH_NUM; i++) begin
        cif_dn_data_in_busy[i]   <= ((s_axis_direct_tvalid_hld     & (i == s_axis_direct_tuser_hld[CH_NUM_W+7:8] ?1:0))
                                    |(d2c_axis_tvalid_hld          & (i == d2c_axis_tuser_hld[CH_NUM_W+7:8] ?1:0))
                                    |(s_axis_direct_tvalid_nxt_hld & (i == s_axis_direct_tuser_nxt_hld[CH_NUM_W+7:8] ?1:0))
                                    |(d2c_axis_tvalid_nxt_hld      & (i == d2c_axis_tuser_nxt_hld[CH_NUM_W+7:8] ?1:0))
                                    |(s_axis_direct_tvalid_back    & (i == s_axis_direct_tuser_back_hld[CH_NUM_W+7:8] ?1:0))
                                    |(d2c_axis_tvalid_back         & (i == d2c_axis_tuser_back_hld[CH_NUM_W+7:8] ?1:0)));
      end
    end
  end

  always_comb begin
    if (direct_sel == 1'b1) begin
      fifo_in_axis_tvalid = s_axis_direct_tvalid_hld;
      fifo_in_axis_tdata  = s_axis_direct_tdata_hld;
      fifo_in_axis_tuser  = s_axis_direct_tuser_hld;
    end else begin
      fifo_in_axis_tvalid = d2c_axis_tvalid_hld;
      fifo_in_axis_tdata  = d2c_axis_tdata_hld;
      fifo_in_axis_tuser  = d2c_axis_tuser_hld;
    end
  end
     
  assign d2c_axis_tvalid_arb_sop_enb      =  arb_enb & d2c_axis_tvalid_hld &  d2c_axis_tuser_hld[7]                         & ~d2c_axis_tvalid_back;
  assign d2c_axis_tvalid_arb_eop_mc       = ~arb_enb & d2c_axis_tvalid_hld & ~d2c_axis_tuser_hld[7] & d2c_axis_tuser_hld[6] & ~d2c_axis_tvalid_back;
  assign d2c_axis_tvalid_arb_win          = d2c_axis_tvalid_arb_sop_enb & (direct_sel_hld | ~s_axis_direct_tvalid_arb_sop_enb);
  assign d2c_axis_tvalid_arb_win_mc       = d2c_axis_tvalid_arb_win & ~d2c_axis_tuser_hld[6];
  assign d2c_axis_tready                  = cif_dn_in_axis_tready & (~d2c_axis_tvalid_hld | ~direct_sel_1tc) & ~d2c_axis_tvalid_back & ~d2c_axis_tvalid_nxt_hld;
  assign s_axis_direct_tvalid_arb_sop_enb =  arb_enb & s_axis_direct_tvalid_hld &  s_axis_direct_tuser_hld[7]                              & ~s_axis_direct_tvalid_back;
  assign s_axis_direct_tvalid_arb_eop_mc  = ~arb_enb & s_axis_direct_tvalid_hld & ~s_axis_direct_tuser_hld[7] & s_axis_direct_tuser_hld[6] & ~s_axis_direct_tvalid_back;
  assign s_axis_direct_tvalid_arb_win     = s_axis_direct_tvalid_arb_sop_enb & (~direct_sel_hld | ~d2c_axis_tvalid_arb_sop_enb);
  assign s_axis_direct_tvalid_arb_win_mc  = s_axis_direct_tvalid_arb_win & ~s_axis_direct_tuser_hld[6];
  assign s_axis_direct_tready             = cif_dn_in_axis_tready & (~s_axis_direct_tvalid_hld | direct_sel_1tc) & ~s_axis_direct_tvalid_back & ~s_axis_direct_tvalid_nxt_hld;
  assign direct_sel                       = s_axis_direct_tvalid_arb_win | (~d2c_axis_tvalid_arb_win & direct_sel_hld);

endmodule
