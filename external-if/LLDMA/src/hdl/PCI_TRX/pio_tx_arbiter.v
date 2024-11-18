/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module pio_tx_arbiter  #(

  parameter AXI4_RQ_TUSER_WIDTH = 137,
  parameter C_DATA_WIDTH = 512,
  parameter KEEP_WIDTH   = C_DATA_WIDTH /32

  )(

  input                          user_clk,
  input                          reset_n,

  input                          rq_dmar_crd_axis_tvalid,
  input                [511:0]   rq_dmar_crd_axis_tdata,
  input                          rq_dmar_crd_axis_tlast,
  input                 [15:0]   rq_dmar_crd_axis_tkeep,
  output                         rq_dmar_crd_axis_tready,

  input                          rq_dmar_cwr_axis_tvalid,
  input                [511:0]   rq_dmar_cwr_axis_tdata,
  input                          rq_dmar_cwr_axis_tlast,
  input                 [15:0]   rq_dmar_cwr_axis_tkeep,
  input                  [3:0]   rq_dmar_cwr_axis_last_be,
  output                         rq_dmar_cwr_axis_tready,

  input                          rq_dmar_rd_axis_tvalid,
  input                [511:0]   rq_dmar_rd_axis_tdata,
  input                          rq_dmar_rd_axis_tlast,
  input                 [15:0]   rq_dmar_rd_axis_tkeep,
  output                         rq_dmar_rd_axis_tready,

  input                          rq_dmaw_dwr_axis_tvalid,
  input                [511:0]   rq_dmaw_dwr_axis_tdata,
  input                          rq_dmaw_dwr_axis_tlast,
  input                 [15:0]   rq_dmaw_dwr_axis_tkeep,
  output                         rq_dmaw_dwr_axis_tready,
  output                         rq_dmaw_dwr_axis_wr_ptr,
  output                         rq_dmaw_dwr_axis_rd_ptr,

  input                          rq_dmaw_cwr_axis_tvalid,
  input                [511:0]   rq_dmaw_cwr_axis_tdata,
  input                          rq_dmaw_cwr_axis_tlast,
  input                 [15:0]   rq_dmaw_cwr_axis_tkeep,
  input                  [3:0]   rq_dmaw_cwr_axis_last_be,
  output                         rq_dmaw_cwr_axis_tready,

  input                          rq_dmaw_crd_axis_tvalid,
  input                [511:0]   rq_dmaw_crd_axis_tdata,
  input                          rq_dmaw_crd_axis_tlast,
  input                 [15:0]   rq_dmaw_crd_axis_tkeep,
  output                         rq_dmaw_crd_axis_tready,

  // AXI-S Requester Request Interface

  output reg                            m_axis_rq_tvalid,
  output reg        [C_DATA_WIDTH-1:0]  m_axis_rq_tdata,
  output reg          [KEEP_WIDTH-1:0]  m_axis_rq_tkeep,
  output reg                            m_axis_rq_tlast,
  output reg [AXI4_RQ_TUSER_WIDTH-1:0]  m_axis_rq_tuser,
  input                                 m_axis_rq_tready,

  // Arb Control Interface

  input            [31:0]        reg_arb,

  // PA Interface

  output reg            [31:0]   pa_dmaw_pkt_cnt,
  output reg            [31:0]   pa_dmar_pkt_cnt,
  output reg            [31:0]   pa_enque_poling_pkt_cnt,
  output reg            [31:0]   pa_enque_clear_pkt_cnt,
  output reg            [31:0]   pa_deque_poling_pkt_cnt,
  output reg            [31:0]   pa_deque_pkt_cnt,

  input                          en_pa_pkt_cnt,
  input                          rst_pa_pkt_cnt,

  // Debug Deque Data

  output reg           [511:0]   deque_pkt_hold

  );


  wire          o_dmar_crd_axis_tvalid ;
  wire  [511:0] o_dmar_crd_axis_tdata  ;
  wire          o_dmar_crd_axis_tlast  ;
  wire   [15:0] o_dmar_crd_axis_tkeep  ;
  wire          tkn_dmar_crd;
  wire          req_dmar_crd;

  wire          o_dmar_cwr_axis_tvalid;
  wire  [511:0] o_dmar_cwr_axis_tdata ;
  wire          o_dmar_cwr_axis_tlast ;
  wire   [15:0] o_dmar_cwr_axis_tkeep ;
  wire    [3:0] o_dmar_cwr_axis_last_be ;
  wire          tkn_dmar_cwr;
  wire          req_dmar_cwr;

  wire          o_dmar_rd_axis_tvalid;
  wire  [511:0] o_dmar_rd_axis_tdata ;
  wire          o_dmar_rd_axis_tlast ;
  wire   [15:0] o_dmar_rd_axis_tkeep ;
  wire          tkn_dmar_rd;
  wire          req_dmar_rd;

  wire          o_dmaw_dwr_axis_tvalid;
  wire  [511:0] o_dmaw_dwr_axis_tdata ;
  wire          o_dmaw_dwr_axis_tlast ;
  wire   [15:0] o_dmaw_dwr_axis_tkeep ;
  wire          tkn_dmaw_dwr;
  wire          req_dmaw_dwr;

  wire          o_dmaw_cwr_axis_tvalid;
  wire  [511:0] o_dmaw_cwr_axis_tdata ;
  wire          o_dmaw_cwr_axis_tlast ;
  wire   [15:0] o_dmaw_cwr_axis_tkeep ;
  wire    [3:0] o_dmaw_cwr_axis_last_be ;
  wire          tkn_dmaw_cwr;
  wire          req_dmaw_cwr;

  wire          o_dmaw_crd_axis_tvalid;
  wire  [511:0] o_dmaw_crd_axis_tdata ;
  wire          o_dmaw_crd_axis_tlast ;
  wire   [15:0] o_dmaw_crd_axis_tkeep ;
  wire          tkn_dmaw_crd;
  wire          req_dmaw_crd;

  reg           w_axis_rq_tvalid;
  reg   [511:0] w_axis_rq_tdata;
  reg    [15:0] w_axis_rq_tkeep;
  reg           w_axis_rq_tlast;
  reg   [136:0] w_axis_rq_tuser;

  wire  [136:0] clip_rq_tuser;
  wire  [136:0] clip_rq_tuser_dmar_cwr;
  wire  [136:0] clip_rq_tuser_dmaw_cwr;

  wire          prio_dmar;
  wire          prio_dmaw;

  wire          req_dmar_crd_mask ;
  wire          req_dmar_cwr_mask ;
  wire          req_dmar_rd_mask ;
  wire          req_dmaw_dwr_mask;
  wire          req_dmaw_cwr_mask;
  wire          req_dmaw_crd_mask;

  wire          tkn_or;

  wire    [5:0] select_bit;

  reg    [15:0] dmr_pkt_cnt;
  reg    [15:0] dmw_pkt_cnt;

  reg           dmaw_prio_enable;
  reg           dmar_prio_enable;

  reg           req_mask_dmar_crd;
  reg           req_mask_dmar_cwr;
  reg           req_mask_dmar_rd;
  reg           req_mask_dmaw_dwr;
  reg           req_mask_dmaw_cwr;
  reg           req_mask_dmaw_crd;

  wire          mask_or_dmar_crd  ;
  wire          mask_or_dmar_cwr  ;
  wire          mask_or_dmar_rd  ;
  wire          mask_or_dmaw_dwr ;
  wire          mask_or_dmaw_cwr ;
  wire          mask_or_dmaw_crd ;


  // ---------------------------------------------------
  // FIFO Instance
  // ---------------------------------------------------


  pio_tx_fifo fifo_dmar_crd(

    .user_clk ( user_clk ),
    .reset_n  ( reset_n  ),

    .i_tvalid ( rq_dmar_crd_axis_tvalid ),
    .i_tdata  ( rq_dmar_crd_axis_tdata  ),
    .i_tlast  ( rq_dmar_crd_axis_tlast  ),
    .i_tkeep  ( rq_dmar_crd_axis_tkeep  ),
    .i_be     (4'b0),                     // not connected
    .o_tready ( rq_dmar_crd_axis_tready ),
    .o_wr_ptr ( ),
    .o_rd_ptr ( ),

    .o_rq_axis_tvalid ( o_dmar_crd_axis_tvalid ),
    .o_rq_axis_tdata  ( o_dmar_crd_axis_tdata  ),
    .o_rq_axis_tlast  ( o_dmar_crd_axis_tlast  ),
    .o_rq_axis_tkeep  ( o_dmar_crd_axis_tkeep  ),
    .o_rq_axis_be     ( ),                // not connected

    .i_tkn  ( tkn_dmar_crd  ),
    .o_req  ( req_dmar_crd  )

    );


  pio_tx_fifo #(
    .ENABLE_BE ( 1 )
  )fifo_dmar_cwr(

    .user_clk ( user_clk ),
    .reset_n  ( reset_n  ),

    .i_tvalid ( rq_dmar_cwr_axis_tvalid ),
    .i_tdata  ( rq_dmar_cwr_axis_tdata  ),
    .i_tlast  ( rq_dmar_cwr_axis_tlast  ),
    .i_tkeep  ( rq_dmar_cwr_axis_tkeep  ),
    .i_be     ( rq_dmar_cwr_axis_last_be),
    .o_tready ( rq_dmar_cwr_axis_tready ),
    .o_wr_ptr ( ),
    .o_rd_ptr ( ),

    .o_rq_axis_tvalid ( o_dmar_cwr_axis_tvalid ),
    .o_rq_axis_tdata  ( o_dmar_cwr_axis_tdata  ),
    .o_rq_axis_tlast  ( o_dmar_cwr_axis_tlast  ),
    .o_rq_axis_tkeep  ( o_dmar_cwr_axis_tkeep  ),
    .o_rq_axis_be     ( o_dmar_cwr_axis_last_be),

    .i_tkn  ( tkn_dmar_cwr  ),
    .o_req  ( req_dmar_cwr  )

    );


  pio_tx_fifo fifo_dmar_rd(

    .user_clk ( user_clk ),
    .reset_n  ( reset_n  ),

    .i_tvalid ( rq_dmar_rd_axis_tvalid ),
    .i_tdata  ( rq_dmar_rd_axis_tdata  ),
    .i_tlast  ( rq_dmar_rd_axis_tlast  ),
    .i_tkeep  ( rq_dmar_rd_axis_tkeep  ),
    .i_be     (4'b0),                     // not connected
    .o_tready ( rq_dmar_rd_axis_tready ),
    .o_wr_ptr ( ),
    .o_rd_ptr ( ),

    .o_rq_axis_tvalid ( o_dmar_rd_axis_tvalid ),
    .o_rq_axis_tdata  ( o_dmar_rd_axis_tdata  ),
    .o_rq_axis_tlast  ( o_dmar_rd_axis_tlast  ),
    .o_rq_axis_tkeep  ( o_dmar_rd_axis_tkeep  ),
    .o_rq_axis_be     ( ),                // not connected

    .i_tkn  ( tkn_dmar_rd  ),
    .o_req  ( req_dmar_rd  )

    );


  pio_tx_fifo fifo_dmaw_dwr(

    .user_clk ( user_clk ),
    .reset_n  ( reset_n  ),

    .i_tvalid ( rq_dmaw_dwr_axis_tvalid ),
    .i_tdata  ( rq_dmaw_dwr_axis_tdata  ),
    .i_tlast  ( rq_dmaw_dwr_axis_tlast  ),
    .i_tkeep  ( rq_dmaw_dwr_axis_tkeep  ),
    .i_be     (4'b0),                     // not connected
    .o_tready ( rq_dmaw_dwr_axis_tready ),
    .o_wr_ptr ( rq_dmaw_dwr_axis_wr_ptr ),
    .o_rd_ptr ( rq_dmaw_dwr_axis_rd_ptr ),

    .o_rq_axis_tvalid ( o_dmaw_dwr_axis_tvalid ),
    .o_rq_axis_tdata  ( o_dmaw_dwr_axis_tdata  ),
    .o_rq_axis_tlast  ( o_dmaw_dwr_axis_tlast  ),
    .o_rq_axis_tkeep  ( o_dmaw_dwr_axis_tkeep  ),
    .o_rq_axis_be     ( ),                // not connected

    .i_tkn  ( tkn_dmaw_dwr  ),
    .o_req  ( req_dmaw_dwr  )

    );


  pio_tx_fifo #(
    .ENABLE_BE ( 1 )
  )fifo_dmaw_cwr(

    .user_clk ( user_clk ),
    .reset_n  ( reset_n  ),

    .i_tvalid ( rq_dmaw_cwr_axis_tvalid ),
    .i_tdata  ( rq_dmaw_cwr_axis_tdata  ),
    .i_tlast  ( rq_dmaw_cwr_axis_tlast  ),
    .i_tkeep  ( rq_dmaw_cwr_axis_tkeep  ),
    .i_be     ( rq_dmaw_cwr_axis_last_be),
    .o_tready ( rq_dmaw_cwr_axis_tready ),
    .o_wr_ptr ( ),
    .o_rd_ptr ( ),

    .o_rq_axis_tvalid ( o_dmaw_cwr_axis_tvalid ),
    .o_rq_axis_tdata  ( o_dmaw_cwr_axis_tdata  ),
    .o_rq_axis_tlast  ( o_dmaw_cwr_axis_tlast  ),
    .o_rq_axis_tkeep  ( o_dmaw_cwr_axis_tkeep  ),
    .o_rq_axis_be     ( o_dmaw_cwr_axis_last_be),
                        
    .i_tkn  ( tkn_dmaw_cwr  ),
    .o_req  ( req_dmaw_cwr  )

    );


  pio_tx_fifo fifo_dmaw_crd(

    .user_clk ( user_clk ),
    .reset_n  ( reset_n  ),

    .i_tvalid ( rq_dmaw_crd_axis_tvalid ),
    .i_tdata  ( rq_dmaw_crd_axis_tdata  ),
    .i_tlast  ( rq_dmaw_crd_axis_tlast  ),
    .i_tkeep  ( rq_dmaw_crd_axis_tkeep  ),
    .i_be     (4'b0),                     // not connected
    .o_tready ( rq_dmaw_crd_axis_tready ),
    .o_wr_ptr ( ),
    .o_rd_ptr ( ),

    .o_rq_axis_tvalid ( o_dmaw_crd_axis_tvalid ),
    .o_rq_axis_tdata  ( o_dmaw_crd_axis_tdata  ),
    .o_rq_axis_tlast  ( o_dmaw_crd_axis_tlast  ),
    .o_rq_axis_tkeep  ( o_dmaw_crd_axis_tkeep  ),
    .o_rq_axis_be     ( ),                // not connected

    .i_tkn  ( tkn_dmaw_crd  ),
    .o_req  ( req_dmaw_crd  )

    );


  // --------------------------------------------
  // RR Instance
  // --------------------------------------------

  assign tkn_or = tkn_dmaw_crd | tkn_dmaw_cwr | tkn_dmaw_dwr | tkn_dmar_rd | tkn_dmar_cwr | tkn_dmar_crd;

  pio_tx_rrb round_robin_6bit(
    .user_clk ( user_clk ),
    .reset_n  ( reset_n  ),

    .req      ({req_dmaw_crd_mask, req_dmaw_cwr_mask, req_dmaw_dwr_mask, req_dmar_rd_mask, req_dmar_cwr_mask, req_dmar_crd_mask}),
    .tkn_ack  ( tkn_or  ),
    .tkn      ({tkn_dmaw_crd     , tkn_dmaw_cwr     , tkn_dmaw_dwr     , tkn_dmar_rd     , tkn_dmar_cwr     , tkn_dmar_crd}),
    .pe ()

    );

  // --------------------------------------------
  // FIFO SELECT
  // --------------------------------------------

  assign select_bit = {tkn_dmaw_crd, tkn_dmaw_cwr, tkn_dmaw_dwr, tkn_dmar_rd, tkn_dmar_cwr, tkn_dmar_crd};

  always @ (*)
    begin
       casex(select_bit[5:0])
         6'bxxxxx1 : w_axis_rq_tvalid = o_dmar_crd_axis_tvalid;
         6'bxxxx10 : w_axis_rq_tvalid = o_dmar_cwr_axis_tvalid;
         6'bxxx100 : w_axis_rq_tvalid = o_dmar_rd_axis_tvalid;
         6'bxx1000 : w_axis_rq_tvalid = o_dmaw_dwr_axis_tvalid;
         6'bx10000 : w_axis_rq_tvalid = o_dmaw_cwr_axis_tvalid;
         6'b100000 : w_axis_rq_tvalid = o_dmaw_crd_axis_tvalid;
         default   : w_axis_rq_tvalid = 1'b0;
       endcase
    end

  always @ (*)
    begin
       casex(select_bit[5:0])
         6'bxxxxx1 : w_axis_rq_tdata = o_dmar_crd_axis_tdata;
         6'bxxxx10 : w_axis_rq_tdata = o_dmar_cwr_axis_tdata;
         6'bxxx100 : w_axis_rq_tdata = o_dmar_rd_axis_tdata;
         6'bxx1000 : w_axis_rq_tdata = o_dmaw_dwr_axis_tdata;
         6'bx10000 : w_axis_rq_tdata = o_dmaw_cwr_axis_tdata;
         6'b100000 : w_axis_rq_tdata = o_dmaw_crd_axis_tdata;
         default   : w_axis_rq_tdata = 512'b0;
       endcase
    end

  always @ (*)
    begin
       casex(select_bit[5:0])
         6'bxxxxx1 : w_axis_rq_tkeep = o_dmar_crd_axis_tkeep;
         6'bxxxx10 : w_axis_rq_tkeep = o_dmar_cwr_axis_tkeep;
         6'bxxx100 : w_axis_rq_tkeep = o_dmar_rd_axis_tkeep;
         6'bxx1000 : w_axis_rq_tkeep = o_dmaw_dwr_axis_tkeep;
         6'bx10000 : w_axis_rq_tkeep = o_dmaw_cwr_axis_tkeep;
         6'b100000 : w_axis_rq_tkeep = o_dmaw_crd_axis_tkeep;
         default   : w_axis_rq_tkeep = 16'b0;
       endcase
    end

  always @ (*)
    begin
       casex(select_bit[5:0])
         6'bxxxxx1 : w_axis_rq_tlast = o_dmar_crd_axis_tlast;
         6'bxxxx10 : w_axis_rq_tlast = o_dmar_cwr_axis_tlast;
         6'bxxx100 : w_axis_rq_tlast = o_dmar_rd_axis_tlast;
         6'bxx1000 : w_axis_rq_tlast = o_dmaw_dwr_axis_tlast;
         6'bx10000 : w_axis_rq_tlast = o_dmaw_cwr_axis_tlast;
         6'b100000 : w_axis_rq_tlast = o_dmaw_crd_axis_tlast;
         default   : w_axis_rq_tlast = 1'b0;
       endcase
    end

  always @ (*)
    begin
       casex(select_bit[5:0])
         6'bxxxxx1 : w_axis_rq_tuser = clip_rq_tuser;
         6'bxxxx10 : w_axis_rq_tuser = clip_rq_tuser_dmar_cwr;
         6'bxxx100 : w_axis_rq_tuser = clip_rq_tuser;
         6'bxx1000 : w_axis_rq_tuser = clip_rq_tuser;
         6'bx10000 : w_axis_rq_tuser = clip_rq_tuser_dmaw_cwr;
         6'b100000 : w_axis_rq_tuser = clip_rq_tuser;
         default   : w_axis_rq_tuser = 137'b0;
       endcase
    end

  // --------------------------------------------
  // TUSER clip
  // --------------------------------------------

  assign clip_rq_tuser = { 64'b0,        // Parity
                           6'b000000,    // Seq Number 1
                           6'b001010,    // Seq Number 0
                           16'h0000,     // TPH Steering Tag
                           2'b00,        // TPH indirect Tag Enable
                           4'b0000,      // TPH Type
                           2'b00,        // TPH Present
                           1'b0,         // Discontinue
                           4'b0000,      // offst of last DW of second TLP ending
                           4'b0000,      // offst of last DW of first TLP ending
                           2'b01,        // TLP is ending
                           2'b00,        // byte lane32
                           2'b00,        // byte lane0
                           2'b01,        // Start of TLP
                           4'b0000,      // Byte Lane number in case of Address Aligned mode
                           8'h0F,        // Last BE of the Read Data
                           8'h0F         // First BE of the Read Data
                           };
   assign clip_rq_tuser_dmar_cwr = {clip_rq_tuser[136:12], o_dmar_cwr_axis_last_be, clip_rq_tuser[7:0]};
   assign clip_rq_tuser_dmaw_cwr = {clip_rq_tuser[136:12], o_dmaw_cwr_axis_last_be, clip_rq_tuser[7:0]};

  // --------------------------------------------
  // OUTPUT REGISTER
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      m_axis_rq_tvalid <= 0;
      m_axis_rq_tdata  <= 0;
      m_axis_rq_tkeep  <= 0;
      m_axis_rq_tlast  <= 0;
      m_axis_rq_tuser  <= 0;
    end else if( m_axis_rq_tready || ~m_axis_rq_tvalid)begin
      m_axis_rq_tvalid <= w_axis_rq_tvalid ;
      m_axis_rq_tdata  <= w_axis_rq_tdata  ;
      m_axis_rq_tkeep  <= w_axis_rq_tkeep  ;
      m_axis_rq_tlast  <= w_axis_rq_tlast  ;
      m_axis_rq_tuser  <= w_axis_rq_tuser  ;
    end
  end


  // --------------------------------------------
  // DMAW PKT COUNT
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      dmw_pkt_cnt <= 0;
    end else if ((|reg_arb[15:0]) && dmaw_prio_enable) begin
      if (o_dmaw_dwr_axis_tlast) begin
        if (dmw_pkt_cnt == reg_arb[15:0]) begin
          dmw_pkt_cnt <= 16'b0;
        end else begin
          dmw_pkt_cnt <= dmw_pkt_cnt + 1'b1;
        end
      end
    end
  end


  // --------------------------------------------
  // DMAR PKT COUNT
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      dmr_pkt_cnt <= 0;
    end else if ((|reg_arb[31:16]) && dmar_prio_enable) begin
      if (o_dmar_rd_axis_tlast) begin
        if (dmr_pkt_cnt == reg_arb[31:16]) begin
          dmr_pkt_cnt <= 16'b0;
        end else begin
          dmr_pkt_cnt <= dmr_pkt_cnt + 1'b1;
        end
      end
    end
  end


  // --------------------------------------------
  // DMAW/R PKT COUNT ENABLE
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      dmaw_prio_enable <= 1;
      dmar_prio_enable <= 0;
    end else if ((|reg_arb[15:0]) && (|reg_arb[31:16]))begin
      if ((dmw_pkt_cnt == reg_arb[15:0])  && o_dmaw_dwr_axis_tlast)begin
        dmaw_prio_enable <= 0;
        dmar_prio_enable <= 1;
      end else if ((dmr_pkt_cnt == reg_arb[31:16]) && o_dmar_rd_axis_tlast)begin
        dmaw_prio_enable <= 1;
        dmar_prio_enable <= 0;
      end
    end else if (|reg_arb[31:16])begin
      dmaw_prio_enable <= 0;
      dmar_prio_enable <= 1;
    end else if (|reg_arb[15:0])begin
      dmaw_prio_enable <= 1;
      dmar_prio_enable <= 0;
    end
  end

  // --------------------------------------------
  // DMAW priority
  // --------------------------------------------

  assign prio_dmaw = (|dmw_pkt_cnt) && req_dmaw_dwr && ~mask_or_dmaw_dwr;

  // --------------------------------------------
  // DMAR priority
  // --------------------------------------------

  assign prio_dmar = (|dmr_pkt_cnt) && req_dmar_rd  && ~mask_or_dmar_rd;

  // --------------------------------------------
  // REQ MASK
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      req_mask_dmar_crd <= 0;
    end else if (o_dmar_crd_axis_tlast) begin
      req_mask_dmar_crd <= 1'b0;
    end else if (o_dmar_crd_axis_tvalid) begin
      req_mask_dmar_crd <= 1'b1;
    end
  end

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      req_mask_dmar_cwr <= 0;
    end else if (o_dmar_cwr_axis_tlast) begin
      req_mask_dmar_cwr <= 1'b0;
    end else if (o_dmar_cwr_axis_tvalid) begin
      req_mask_dmar_cwr <= 1'b1;
    end
  end

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      req_mask_dmar_rd <= 0;
    end else if (o_dmar_rd_axis_tlast) begin
      req_mask_dmar_rd <= 1'b0;
    end else if (o_dmar_rd_axis_tvalid) begin
      req_mask_dmar_rd <= 1'b1;
    end
  end

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      req_mask_dmaw_dwr <= 0;
    end else if (o_dmaw_dwr_axis_tlast) begin
      req_mask_dmaw_dwr <= 1'b0;
    end else if (o_dmaw_dwr_axis_tvalid) begin
      req_mask_dmaw_dwr <= 1'b1;
    end
  end

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      req_mask_dmaw_cwr <= 0;
    end else if (o_dmaw_cwr_axis_tlast) begin
      req_mask_dmaw_cwr <= 1'b0;
    end else if (o_dmaw_cwr_axis_tvalid) begin
      req_mask_dmaw_cwr <= 1'b1;
    end
  end

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      req_mask_dmaw_crd <= 0;
    end else if (o_dmaw_crd_axis_tlast) begin
      req_mask_dmaw_crd <= 1'b0;
    end else if (o_dmaw_crd_axis_tvalid) begin
      req_mask_dmaw_crd <= 1'b1;
    end
  end

  assign mask_or_dmar_crd  =                     req_mask_dmar_cwr | req_mask_dmar_rd | req_mask_dmaw_dwr | req_mask_dmaw_cwr | req_mask_dmaw_crd;
  assign mask_or_dmar_cwr  = req_mask_dmar_crd                     | req_mask_dmar_rd | req_mask_dmaw_dwr | req_mask_dmaw_cwr | req_mask_dmaw_crd;
  assign mask_or_dmar_rd   = req_mask_dmar_crd | req_mask_dmar_cwr                    | req_mask_dmaw_dwr | req_mask_dmaw_cwr | req_mask_dmaw_crd;
  assign mask_or_dmaw_dwr  = req_mask_dmar_crd | req_mask_dmar_cwr | req_mask_dmar_rd                     | req_mask_dmaw_cwr | req_mask_dmaw_crd;
  assign mask_or_dmaw_cwr  = req_mask_dmar_crd | req_mask_dmar_cwr | req_mask_dmar_rd | req_mask_dmaw_dwr                     | req_mask_dmaw_crd;
  assign mask_or_dmaw_crd  = req_mask_dmar_crd | req_mask_dmar_cwr | req_mask_dmar_rd | req_mask_dmaw_dwr | req_mask_dmaw_cwr                    ;

  // --------------------------------------------
  // ARB MASK
  // --------------------------------------------

  assign req_dmar_crd_mask  = req_dmar_crd & m_axis_rq_tready & ~mask_or_dmar_crd & ~prio_dmar & ~prio_dmaw ;
  assign req_dmar_cwr_mask  = req_dmar_cwr & m_axis_rq_tready & ~mask_or_dmar_cwr & ~prio_dmar & ~prio_dmaw ;
  assign req_dmar_rd_mask   = req_dmar_rd  & m_axis_rq_tready & ~mask_or_dmar_rd               & ~prio_dmaw ;
  assign req_dmaw_dwr_mask  = req_dmaw_dwr & m_axis_rq_tready & ~mask_or_dmaw_dwr & ~prio_dmar              ;
  assign req_dmaw_cwr_mask  = req_dmaw_cwr & m_axis_rq_tready & ~mask_or_dmaw_cwr & ~prio_dmar & ~prio_dmaw ;
  assign req_dmaw_crd_mask  = req_dmaw_crd & m_axis_rq_tready & ~mask_or_dmaw_crd & ~prio_dmar & ~prio_dmaw ;

  // --------------------------------------------
  // PA ENQUE READ PKT COUNT
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      pa_enque_poling_pkt_cnt <= 0;
    end else if (rst_pa_pkt_cnt == 1'b1) begin
      pa_enque_poling_pkt_cnt <= 0;
    end else if (en_pa_pkt_cnt && tkn_dmar_crd && o_dmar_crd_axis_tlast) begin
      pa_enque_poling_pkt_cnt <= pa_enque_poling_pkt_cnt + 1'b1;
    end
  end

  // --------------------------------------------
  // PA ENQUE CLEAR PKT COUNT
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      pa_enque_clear_pkt_cnt <= 0;
    end else if (rst_pa_pkt_cnt == 1'b1) begin
      pa_enque_clear_pkt_cnt <= 0;
    end else if (en_pa_pkt_cnt && tkn_dmar_cwr && o_dmar_cwr_axis_tlast) begin
      pa_enque_clear_pkt_cnt <= pa_enque_clear_pkt_cnt + 1'b1;
    end
  end

  // --------------------------------------------
  // PA DMAR PKT COUNT
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      pa_dmar_pkt_cnt <= 0;
    end else if (rst_pa_pkt_cnt == 1'b1) begin
      pa_dmar_pkt_cnt <= 0;
    end else if (en_pa_pkt_cnt && tkn_dmar_rd && o_dmar_rd_axis_tlast) begin
      pa_dmar_pkt_cnt <= pa_dmar_pkt_cnt + 1'b1;
    end
  end

  // --------------------------------------------
  // PA DMAW PKT COUNT
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      pa_dmaw_pkt_cnt <= 0;
    end else if (rst_pa_pkt_cnt == 1'b1) begin
      pa_dmaw_pkt_cnt <= 0;
    end else if (en_pa_pkt_cnt && tkn_dmaw_dwr && o_dmaw_dwr_axis_tlast) begin
      pa_dmaw_pkt_cnt <= pa_dmaw_pkt_cnt + 1'b1;
    end
  end

  // --------------------------------------------
  // PA DEQUE PKT COUNT
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      pa_deque_pkt_cnt <= 0;
    end else if (rst_pa_pkt_cnt == 1'b1) begin
      pa_deque_pkt_cnt <= 0;
    end else if (en_pa_pkt_cnt && tkn_dmaw_cwr && o_dmaw_cwr_axis_tlast) begin
      pa_deque_pkt_cnt <= pa_deque_pkt_cnt + 1'b1;
    end
  end

  // --------------------------------------------
  // PA DEQUE POLING PKT COUNT
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      pa_deque_poling_pkt_cnt <= 0;
    end else if (rst_pa_pkt_cnt == 1'b1) begin
      pa_deque_poling_pkt_cnt <= 0;
    end else if (en_pa_pkt_cnt && tkn_dmaw_crd && o_dmaw_crd_axis_tlast) begin
      pa_deque_poling_pkt_cnt <= pa_deque_poling_pkt_cnt + 1'b1;
    end
  end

  // --------------------------------------------
  // DEQUE PKT HOLD
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      deque_pkt_hold <= 0;
    end else if (tkn_dmaw_cwr && o_dmaw_cwr_axis_tvalid && ~o_dmaw_cwr_axis_tlast) begin
      deque_pkt_hold <= o_dmaw_cwr_axis_tdata;
    end
  end


endmodule // pio_tx_arbiter
