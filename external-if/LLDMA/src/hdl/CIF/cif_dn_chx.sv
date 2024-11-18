/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module cif_dn_chx #(
  parameter CHAIN_ID = 0,
  parameter CID      = 0,
  parameter CH_NUM   = 8
)(
  input  logic         reset_n,
  input  logic         user_clk,

  input  logic         a0_fifo_out_axis_tvalid_chx,
  input  logic [511:0] a0_fifo_out_axis_tdata,
  input  logic         a0_fifo_out_axis_tready,
  output logic         a0_fifo_out_axis_tready_pre_chx,

  input  logic         m_axi_cd_awvalid,
  input  logic         m_axi_cd_awready,
  input  logic         m_axi_cd_wvalid,
  input  logic         m_axi_cd_wready,

  input  logic         cmd_valid,
  input  logic [63:0]  cmd_data,

  input  logic         rxch_oe_t1_ff,
  input  logic         rxch_clr_t1_ff,
  input  logic         dmar_rd_enb_mode,
  output logic         dmar_rd_enb_ff,

  input  logic [5:0]   a0_pkt_frac,
  output logic [6:0]   a0_nxt_total_frac_ff,
  output logic [6:0]   a0_total_frac_ff,
  output logic         a0_frstcnt_thd_t1_ff,
  output logic         a1_buf_we_ff,
  output logic [32:0]  a1_buf_wp_ff,

  input  logic [2:0]   cif_dn_rx_ddr_size,
  output logic         b0_bufrd_req,
  output logic         b1_bufrd_req,
  output logic [31:0]  b1_ddr_nxtwp_ff,
  output logic [4:0]   b1_bufrd_len_ff,
  output logic [32:0]  b1_buf_rp_ff,
  output logic [31:0]  b1_rx_ddr_wp_ff,
  input  logic         b1_bufrd_gnt_chx,
  input  logic         b1_bufrd_gnt_anych,
  input  logic [1:0]   b1_bufrd_stm_ff,
  input  logic [4:0]   b1_bufrd_remlen_ff,

  output logic [32:0]  a0_nxtfrm_wp_ff,
  output logic [31:0]  a0_remfrm_cnt_ff,
  output logic         a0_last_ff,
  output logic         a0_last_flg_ff,
  output logic [31:0]  rx_ddr_rp_ff,
  output logic [12:0]  buf_dtsize,
  output logic         buf_dtfull,
  output logic         buf_dtovfl,

// cif_dn_chx_gd
  input  logic [  1:0] chx_pkt_mode,
  input  logic         chx_que_wt_ack_mode2,

  output logic         chx_que_wt_req_mode2,
  output logic [ 31:0] chx_que_wt_req_ack_rp_mode2,
  output logic [ 31:0] chx_ack_rp_mode2,
  output logic         chx_cifd_busy_mode2
);

localparam IDLE     = 0;
localparam PRERD    = 1;
localparam BUFRD    = 2;
localparam CH_NUM_W = $clog2(CH_NUM);

logic [6:0]  a0_total_frac_nxt;
logic [8:0]  a0_frac_unwt_cnt_nxt;
logic [8:0]  a0_frac_unwt_cnt_ff;
logic [6:0]  a0_frac_unwt_ff;
logic [32:0] a0_buf_wp_ff;
logic [6:0]  a1_total_frac_ff;

logic [25:0] bm2_ddr_dtsize;
logic [25:0] bm2_ddr_dtsize_mask;
logic        bm1_bufrd_req_inh;
logic        bm1_ddr_notfull;
logic        bm1_buf_wph_eq_rph;
logic        bm1_buf_wpl_eq_rpl;
logic        bm1_buf_rpl_eq_0;
logic        bm1_nxt_frm_eq_0;
logic        bm1_bufwp_ge_nxtfrmhd;
logic        bm1_bufrd_req;
logic [32:0] bm1_bufrd_nxtrp;
logic [10:0] bm1_ddr_nxtwp_term;
logic [4:0]  bm1_bufrd_len;
logic [1:0]  bm1_debug_st;

logic [32:0] b0_bufrd_nxtrp;
logic [31:0] b0_ddr_nxtwp;
logic [4:0]  b0_bufrd_len;
logic [32:0] b1_bufrd_nxtrp_ff;
logic        chx_b1_buf_rp_update_gd;
logic [32:0] b1_buf_rp_gd;

logic        bufrd_gnt_hold_ff;

//// main ////

////////////////////////////////////////////////
// (11) Fraction Hold Counter
////////////////////////////////////////////////
// pkt_frac       : Fractional byte number of incoming packets
// total_frac     : Fraction to previous packet. [6] is for carry check.
// buf_wp_ff[5:0] : wp of internal buf of cif_dn. [5] is for overlap detection of wp/rp when wp wrapping.
always_comb begin
  if(a0_pkt_frac==6'h00) begin
    a0_total_frac_nxt = {1'b0, a0_total_frac_ff[5:0]} + 7'h40;
  end else begin
    a0_total_frac_nxt = {1'b0, a0_total_frac_ff[5:0]} + {1'b0, a0_pkt_frac[5:0]};
  end
end

//assign a0_frac_unwt_cnt_nxt = {9{a0_frac_unwt_ff > 7'h00}} & (a0_frac_unwt_cnt_ff + 9'h01);
assign a0_frac_unwt_cnt_nxt = (a0_frac_unwt_cnt_ff[8] | (a0_frac_unwt_ff[5:0] == 6'h00) | ~(a0_last_ff | a0_last_flg_ff) | a1_buf_we_ff)?
                              9'h000 : (a0_frac_unwt_cnt_ff + 9'h01);

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    a0_frac_unwt_cnt_ff     <= '0;
    a0_frstcnt_thd_t1_ff    <= '0;
  end else begin
    if(rxch_clr_t1_ff) begin
      a0_frac_unwt_cnt_ff   <= '0;
      a0_frstcnt_thd_t1_ff  <= '0;
    end else begin
      if(a0_fifo_out_axis_tready & rxch_oe_t1_ff) begin
        a0_frac_unwt_cnt_ff <= a0_fifo_out_axis_tvalid_chx? 9'h00 : a0_frac_unwt_cnt_nxt;
      end else begin
        a0_frac_unwt_cnt_ff <= (a0_fifo_out_axis_tvalid_chx | a0_frstcnt_thd_t1_ff)? 9'h00 : a0_frac_unwt_cnt_nxt;
      end
      a0_frstcnt_thd_t1_ff  <= a0_frac_unwt_cnt_ff[8];
    end
  end
end

////////////////////////////////////////////////
// (9) BUF wp control, (10) BUF write control
////////////////////////////////////////////////
// total_frac : Number of bytes of fractional data held in a1_tdata_sft_ff
// frac_wt    : Number of bytes kept in a1_tdata_sft_ff and not yet written to buf
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    a0_nxt_total_frac_ff     <= '0;
    a0_total_frac_ff         <= '0;
    a0_frac_unwt_ff          <= '0;
    a0_buf_wp_ff             <= '0;
    a1_buf_we_ff             <= '0;
  end else begin
    if(rxch_clr_t1_ff) begin
      a0_nxt_total_frac_ff   <= '0;
      a0_total_frac_ff       <= '0;
      a0_frac_unwt_ff        <= '0;
      a0_buf_wp_ff           <= '0;
      a1_buf_we_ff           <= '0;
    end else begin
      if(a0_frstcnt_thd_t1_ff & ~(a0_fifo_out_axis_tvalid_chx & a0_fifo_out_axis_tready & rxch_oe_t1_ff)) begin
        a0_nxt_total_frac_ff <= a0_nxt_total_frac_ff;
        a0_total_frac_ff     <= a0_total_frac_ff;
        a0_frac_unwt_ff      <= '0;
        a0_buf_wp_ff         <= {a0_buf_wp_ff[32:6],a0_frac_unwt_ff[5:0]};
        a1_buf_we_ff         <= a1_buf_we_ff;
      end else if(a0_fifo_out_axis_tready & rxch_oe_t1_ff) begin
        if(a0_fifo_out_axis_tvalid_chx & a0_last_flg_ff) begin  // start of packet
          a0_nxt_total_frac_ff <= a0_total_frac_nxt;
        end
  
        if(a0_fifo_out_axis_tvalid_chx & a0_last_ff & a0_last_flg_ff) begin  // start of packet & end of packet
          a0_total_frac_ff <= a0_total_frac_nxt;
          a0_frac_unwt_ff  <= a0_total_frac_nxt;
  
          if(a0_total_frac_nxt[6]) begin
            a0_buf_wp_ff <= {(a0_buf_wp_ff[32:6]+1'b1), 6'h00};
          end else begin
            a0_buf_wp_ff <= a0_buf_wp_ff;
          end
          a1_buf_we_ff <= 1'b1;
        end else if(a0_fifo_out_axis_tvalid_chx & a0_last_ff & ~a0_last_flg_ff) begin
          a0_total_frac_ff <= a0_nxt_total_frac_ff;
          a0_frac_unwt_ff  <= a0_nxt_total_frac_ff;
  
          if(a0_nxt_total_frac_ff[6]) begin
            a0_buf_wp_ff <= {(a0_buf_wp_ff[32:6]+1'b1), 6'h00};
          end else begin
            a0_buf_wp_ff <= a0_buf_wp_ff;
          end
          a1_buf_we_ff <= 1'b1;
        end else if(a0_fifo_out_axis_tvalid_chx & ~a0_last_ff) begin
          a0_total_frac_ff <= a0_total_frac_ff;
          a0_frac_unwt_ff  <= a0_frac_unwt_ff;
          a0_buf_wp_ff <= {(a0_buf_wp_ff[32:6]+1'b1), 6'h00};
          a1_buf_we_ff     <= 1'b1;
        end else begin
          a0_total_frac_ff <= a0_total_frac_ff;
          a0_frac_unwt_ff  <= a0_frac_unwt_ff;
          a0_buf_wp_ff     <= a0_buf_wp_ff;
          a1_buf_we_ff     <= 1'b0;
        end
      end
    end
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    a1_buf_wp_ff       <= 33'h00;
    a1_total_frac_ff   <= 7'h00;
  end else begin
    if(rxch_clr_t1_ff) begin
      a1_buf_wp_ff     <= 33'h00;
      a1_total_frac_ff <= 7'h00;
    end else if(a0_fifo_out_axis_tready & rxch_oe_t1_ff) begin
      a1_buf_wp_ff     <= a0_buf_wp_ff;
      a1_total_frac_ff <= a0_total_frac_ff;
    end
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    a0_nxtfrm_wp_ff      <= '0;
    a0_remfrm_cnt_ff     <= '0;
    a0_last_ff           <= '0;
    a0_last_flg_ff       <= 1'b1;
  end else begin
    if(rxch_clr_t1_ff) begin
      a0_nxtfrm_wp_ff    <= '0;
      a0_remfrm_cnt_ff   <= '0;
      a0_last_ff         <= '0;
      a0_last_flg_ff     <= 1'b1;
    end else if(a0_fifo_out_axis_tready & rxch_oe_t1_ff & a0_fifo_out_axis_tvalid_chx) begin
      if(a0_remfrm_cnt_ff == 32'h0) begin
        a0_nxtfrm_wp_ff  <= a0_nxtfrm_wp_ff + {1'b0,a0_fifo_out_axis_tdata[63:32]} + 33'h30;
        a0_remfrm_cnt_ff <= a0_fifo_out_axis_tdata[63:32] - 32'h10;
        a0_last_ff       <= 1'b0;
        a0_last_flg_ff   <= 1'b0;
      end else if(a0_remfrm_cnt_ff<=32'h40) begin
        a0_nxtfrm_wp_ff  <= a0_nxtfrm_wp_ff;
        a0_remfrm_cnt_ff <= 32'h0;
        a0_last_ff       <= 1'b0;
        a0_last_flg_ff   <= 1'b1;
      end else if(a0_remfrm_cnt_ff<=32'h80) begin
        a0_nxtfrm_wp_ff  <= a0_nxtfrm_wp_ff;
        a0_remfrm_cnt_ff <= a0_remfrm_cnt_ff - 32'h40;
        a0_last_ff       <= 1'b1;
        a0_last_flg_ff   <= 1'b0;
      end else begin
        a0_nxtfrm_wp_ff  <= a0_nxtfrm_wp_ff;
        a0_remfrm_cnt_ff <= a0_remfrm_cnt_ff - 32'h40;
        a0_last_ff       <= 1'b0;
        a0_last_flg_ff   <= 1'b0;
      end
    end
  end
end

////////////////////////////////////////////////
// (14) BUF read req control
////////////////////////////////////////////////
assign bm1_buf_wph_eq_rph    = (a1_buf_wp_ff[12:10]==b1_buf_rp_ff[12:10]);
assign bm1_buf_wpl_eq_rpl    = (a1_buf_wp_ff[9:0]  ==b1_buf_rp_ff[9:0]);
assign bm1_buf_rpl_eq_0      = (b1_buf_rp_ff[9:0]==10'b0);
assign bm1_nxt_frm_eq_0      = (a0_nxtfrm_wp_ff[32:0]==b1_buf_rp_ff[32:0]);
assign bm1_bufwp_ge_nxtfrmhd = (a1_buf_wp_ff[32:0]==a0_nxtfrm_wp_ff[32:0]);
assign bm2_ddr_dtsize        = (b1_rx_ddr_wp_ff[25:0] - rx_ddr_rp_ff[25:0]) | bm2_ddr_dtsize_mask;

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    bm1_ddr_notfull     <= '1;
    bm2_ddr_dtsize_mask <= '0;
  end else begin
    case (cif_dn_rx_ddr_size)
      3'h0    : bm2_ddr_dtsize_mask <= 26'h1f0_0000;
      3'h1    : bm2_ddr_dtsize_mask <= 26'h1e0_0000;
      3'h2    : bm2_ddr_dtsize_mask <= 26'h1c0_0000;
      3'h3    : bm2_ddr_dtsize_mask <= 26'h180_0000;
      3'h4    : bm2_ddr_dtsize_mask <= 26'h100_0000;
      3'h5    : bm2_ddr_dtsize_mask <= 26'h000_0000;
      3'h6    : bm2_ddr_dtsize_mask <= 26'h1ff_0000;
      3'h7    : bm2_ddr_dtsize_mask <= 26'h1fe_0000;
      default : bm2_ddr_dtsize_mask <= 26'h1f0_0000;
    endcase
    bm1_ddr_notfull <= (bm2_ddr_dtsize < {26'h1ff_fc00});
  end
end

always_comb begin
  case({rxch_oe_t1_ff,
       (b0_bufrd_req | bm1_bufrd_req_inh),
        bm1_ddr_notfull,
        bm1_buf_wph_eq_rph,
        bm1_buf_wpl_eq_rpl,
        bm1_buf_rpl_eq_0,
        bm1_nxt_frm_eq_0,
        bm1_bufwp_ge_nxtfrmhd}) inside
    8'b1010?1??: begin
      bm1_bufrd_req      = 1'b1;
      bm1_bufrd_nxtrp    = b1_buf_rp_ff + 33'h400;
      bm1_ddr_nxtwp_term = 11'h400;
      bm1_bufrd_len      = 5'h10;
      bm1_debug_st       = 2'h1;
    end
    8'b1010?0??: begin
      bm1_bufrd_req      = 1'b1;
      bm1_bufrd_nxtrp    = {b1_buf_rp_ff[32:10], 10'h000} + 33'h400;
      bm1_ddr_nxtwp_term = 11'h400 - b1_buf_rp_ff[9:0];
      bm1_bufrd_len      = 5'h10 - {1'b0, b1_buf_rp_ff[9:6]};
      bm1_debug_st       = 2'h2;
    end
    8'b10110?01: begin
      bm1_bufrd_req      = 1'b1;
      bm1_bufrd_nxtrp    = {b1_buf_rp_ff[32:13], a1_buf_wp_ff[12:0]};
      bm1_ddr_nxtwp_term = {1'b0, (a1_buf_wp_ff[9:0] - b1_buf_rp_ff[9:0])};
      bm1_bufrd_len      = {1'b0,a1_buf_wp_ff[9:6]} - {1'b0,b1_buf_rp_ff[9:6]} + {4'h0,(a1_buf_wp_ff[5:0]>0)};
      bm1_debug_st       = 2'h3;
    end
    default: begin
      bm1_bufrd_req      = 1'b0;
      bm1_bufrd_nxtrp    = b1_buf_rp_ff;
      bm1_ddr_nxtwp_term = '0;
      bm1_bufrd_len      = 5'h00;
      bm1_debug_st       = 2'h0;
    end
  endcase
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    bm1_bufrd_req_inh <= '0;
    b0_bufrd_req      <= '0;
    b0_bufrd_nxtrp    <= '0;
    b0_ddr_nxtwp      <= '0;
    b0_bufrd_len      <= '0;
  end else if(bm1_bufrd_req) begin
    b0_bufrd_req      <= '1;
    b0_bufrd_nxtrp    <= bm1_bufrd_nxtrp;
    b0_ddr_nxtwp      <= b1_rx_ddr_wp_ff + bm1_ddr_nxtwp_term;
    b0_bufrd_len      <= bm1_bufrd_len;
  end else if(b1_bufrd_gnt_chx) begin
    b0_bufrd_req      <= '0;
    bm1_bufrd_req_inh <= '1;
  end else if(bm1_bufrd_req_inh & (b1_bufrd_stm_ff==IDLE)) begin
    bm1_bufrd_req_inh <= '0;
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b1_bufrd_nxtrp_ff <= '0;
    b1_ddr_nxtwp_ff   <= '0;
    b1_bufrd_len_ff   <= '0;
  end else if(~b1_bufrd_gnt_chx & ~(bufrd_gnt_hold_ff & (b1_bufrd_stm_ff!=IDLE))) begin
    b1_bufrd_nxtrp_ff <= b0_bufrd_nxtrp;
    b1_ddr_nxtwp_ff   <= b0_ddr_nxtwp;
    b1_bufrd_len_ff   <= b0_bufrd_len;
  end
end

////////////////////////////////////////////////
// (12) DDR wp control
////////////////////////////////////////////////
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b1_rx_ddr_wp_ff   <= 'b0;
  end else begin
    if(rxch_clr_t1_ff) begin
      b1_rx_ddr_wp_ff <= 'b0;
    end else if(b1_bufrd_gnt_chx) begin
      b1_rx_ddr_wp_ff <= b1_ddr_nxtwp_ff;
    end
  end
end

////////////////////////////////////////////////
// (13) BUF rp control
////////////////////////////////////////////////
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    b1_buf_rp_ff              <= '0;
    bufrd_gnt_hold_ff         <= '0;
    chx_b1_buf_rp_update_gd   <= '0;
  end else begin
    if(rxch_clr_t1_ff) begin
      b1_buf_rp_ff            <= '0;
      bufrd_gnt_hold_ff       <= '0;
      chx_b1_buf_rp_update_gd <= '0;
    end else begin
      if(  (b1_bufrd_gnt_chx | (bufrd_gnt_hold_ff & (b1_bufrd_stm_ff==PRERD)))
         & (b1_bufrd_len_ff==5'h01)) begin
        if( (m_axi_cd_awready | ~m_axi_cd_awvalid)
           &(m_axi_cd_wready  | ~m_axi_cd_wvalid )) begin
          b1_buf_rp_ff <= b1_bufrd_nxtrp_ff;
          if (chx_pkt_mode == 2'h2) begin 
            chx_b1_buf_rp_update_gd <= 1'b1;
          end 
        end else begin
          chx_b1_buf_rp_update_gd <= 1'b0;
        end
      end else if(  (b1_bufrd_gnt_chx | (bufrd_gnt_hold_ff & (b1_bufrd_stm_ff==PRERD)))
                  & (b1_bufrd_len_ff!=5'h01)) begin
        if( (m_axi_cd_awready | ~m_axi_cd_awvalid)
           &(m_axi_cd_wready  | ~m_axi_cd_wvalid )) begin
          b1_buf_rp_ff <= {b1_buf_rp_ff[32:6], 6'h00} + 33'h040;
          chx_b1_buf_rp_update_gd <= 1'b0;
        end
      end else if(bufrd_gnt_hold_ff & (b1_bufrd_stm_ff==BUFRD) & (b1_bufrd_remlen_ff==5'h01)) begin
        if(m_axi_cd_wready  | ~m_axi_cd_wvalid) begin
          b1_buf_rp_ff <= b1_bufrd_nxtrp_ff;
          if (chx_pkt_mode == 2'h2) begin 
            chx_b1_buf_rp_update_gd <= 1'b1;
          end
        end else begin
          chx_b1_buf_rp_update_gd <= 1'b0;
        end
      end else if(bufrd_gnt_hold_ff & (b1_bufrd_stm_ff==BUFRD) & (b1_bufrd_remlen_ff!=5'h01)) begin
        if(m_axi_cd_wready  | ~m_axi_cd_wvalid) begin
          b1_buf_rp_ff <= {b1_buf_rp_ff[32:6], 6'h00} + 33'h040;
        end
        chx_b1_buf_rp_update_gd <= 1'b0;
      end else begin
        chx_b1_buf_rp_update_gd <= 1'b0;
      end
  
      if(b1_bufrd_gnt_chx) begin
        bufrd_gnt_hold_ff <= 1'b1;
      end else if(~b1_bufrd_gnt_chx & b1_bufrd_gnt_anych) begin
        bufrd_gnt_hold_ff <= 1'b0;
      end else if(b1_bufrd_stm_ff==IDLE) begin
        bufrd_gnt_hold_ff <= 1'b0;
      end
    end
  end
end

assign b1_buf_rp_gd = b1_buf_rp_ff;
assign b1_bufrd_req = b1_bufrd_gnt_chx | (bufrd_gnt_hold_ff & (b1_bufrd_stm_ff!=IDLE));

////////////////////////////////////////////////
// (8) DDR rp control
////////////////////////////////////////////////
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    rx_ddr_rp_ff   <= 32'h0;
  end else begin
    if(rxch_clr_t1_ff) begin
      rx_ddr_rp_ff <= 32'h0;
    end else begin
      // transfer_cmd_data[48]=1: receive command
      if(  cmd_valid
         & (cmd_data[47:32]==(CHAIN_ID*CH_NUM+CID[CH_NUM_W-1:0]))
         & cmd_data[48]
         & rxch_oe_t1_ff) begin
        rx_ddr_rp_ff <= cmd_data[31:0];
      end
    end
  end
end

assign buf_dtsize = a1_buf_wp_ff[12:0] - b1_buf_rp_ff[12:0];
assign buf_dtfull = buf_dtsize[12] & (buf_dtsize[11:0] == 0);
assign buf_dtovfl = buf_dtsize[12] & (buf_dtsize[11:0]  > 0);
assign a0_fifo_out_axis_tready_pre_chx = ~rxch_oe_t1_ff | ((buf_dtsize < 13'h0f80) & ~a0_frstcnt_thd_t1_ff);

////////////////////////////////////////////////
// (15a) d2c control signal generation (ch)
////////////////////////////////////////////////
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    dmar_rd_enb_ff <= '0;
  end else begin
    if (cif_dn_rx_ddr_size < 3'h6) begin
      dmar_rd_enb_ff <= (bm2_ddr_dtsize < {26'h1fc_0000});
    end else begin
      if(~dmar_rd_enb_mode) begin
        dmar_rd_enb_ff <= 1'b1;
      end else begin
        dmar_rd_enb_ff <= (bm2_ddr_dtsize < {26'h1ff_c000});
      end
    end
  end
end

////////////////////////////////////////////////
// (16) FPGA-to-FPGA communication direct transfer
////////////////////////////////////////////////
  cif_dn_chx_gd cif_dn_chx_gd (
  // input
    .user_clk(user_clk),
    .reset_n(reset_n),
    // ACK req receive from CIF_DN / cif_dn_chx
    .chx_b1_buf_rp_update_gd(chx_b1_buf_rp_update_gd),
    .b1_buf_rp_gd(b1_buf_rp_gd),
    // ACK ack receive from DMA_RX / ENQDEQ
    .chx_que_wt_ack_mode2(chx_que_wt_ack_mode2),
    // clear
    .rxch_clr_t1_ff(rxch_clr_t1_ff),
  // output
    // ACK req send to DMA_RX / ENQDEQ
    .chx_que_wt_req_mode2(chx_que_wt_req_mode2),
    .chx_que_wt_req_ack_rp_mode2(chx_que_wt_req_ack_rp_mode2),
    // status
    .chx_ack_rp_mode2(chx_ack_rp_mode2),
    // clear
    .chx_cifd_busy_mode2(chx_cifd_busy_mode2)
  );


logic [ 3:1] chk_bm1_debug_st_ff;
logic [15:0] chk_bm1_debug_st_cnt_ff[3:1];

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    chk_bm1_debug_st_ff          <= '0;
    for(int i=1; i<4; i++) begin
      chk_bm1_debug_st_cnt_ff[i] <= 0;
    end
  end else begin
    for(int i=1; i<4; i++) begin
      if(bm1_debug_st==i) begin
        chk_bm1_debug_st_ff[i]     <= '1;
        chk_bm1_debug_st_cnt_ff[i] <= chk_bm1_debug_st_cnt_ff[i] + 1;
      end
    end
  end
end

endmodule
