/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`define PA_CIF
`define TRACE_CIF

module cifd_reg #(
  parameter CH_NUM      = 32,
  parameter CHAIN_NUM   = 4
)(
  input  logic              reset_n,
  input  logic              user_clk,

  input  logic              regreq_axis_tvalid_cif,
  input  logic [511:0]      regreq_axis_tdata,
  input  logic              regreq_axis_tlast,
  input  logic [63:0]       regreq_axis_tuser,
  output logic              regrep_axis_tvalid_cif,
  output logic [31:0]       regrep_axis_tdata_cif,

  output logic [31:0]       o_ad_0600[CHAIN_NUM-1:0],
  output logic [31:0]       o_ad_0604[CHAIN_NUM-1:0],
  output logic [2:0]        o_ad_0680,
  output logic              o_ad_07e0,
  output logic [31:0]       o_ad_07e4[CHAIN_NUM-1:0],
  output logic [31:0]       o_ad_07f4,
  output logic              o_ad_07f8,
  output logic              o_ad_07fc,
  output logic [31:0]       o_ad_1600,
  input  logic [31:0]       i_ad_0700[CHAIN_NUM-1:0],
  input  logic [31:0]       i_ad_0704[CHAIN_NUM-1:0],
  input  logic [31:0]       i_ad_0708[CHAIN_NUM-1:0],
  input  logic [31:0]       i_ad_070c[CHAIN_NUM-1:0],
  input  logic [31:0]       i_ad_0710[CHAIN_NUM-1:0],
  input  logic [31:0]       i_ad_0714[CHAIN_NUM-1:0],
  input  logic [31:0]       i_ad_07e4[CHAIN_NUM-1:0],
  input  logic [31:0]       i_ad_07f8[CHAIN_NUM-1:0],
  input  logic [31:0]       i_ad_1640[CHAIN_NUM-1:0],
  input  logic [31:0]       i_ad_1644[CHAIN_NUM-1:0],
  input  logic [31:0]       i_ad_1648[CHAIN_NUM-1:0],
  input  logic [31:0]       i_ad_164c[CHAIN_NUM-1:0],
  input  logic [31:0]       i_ad_1654[CH_NUM-1:0],
  input  logic [31:0]       i_ad_1658[CH_NUM-1:0],
  input  logic [31:0]       i_ad_165c[CH_NUM-1:0],
  input  logic [31:0]       i_ad_1660[CH_NUM-1:0],
  input  logic [31:0]       i_ad_1664[CH_NUM-1:0],
  input  logic [31:0]       i_ad_1668[CH_NUM-1:0],
  input  logic [31:0]       i_ad_166c[CHAIN_NUM-1:0],
  input  logic [31:0]       i_ad_1670[CHAIN_NUM-1:0],
  input  logic [31:0]       i_ad_1674[CHAIN_NUM-1:0],
  input  logic [31:0]       i_ad_1678[CHAIN_NUM-1:0],

  input  logic              dbg_enable,
  input  logic              dbg_count_reset,
  input  logic [CH_NUM-1:0] pa00_inc_enb,
  input  logic [CH_NUM-1:0] pa01_inc_enb,
  input  logic [CH_NUM-1:0] pa02_inc_enb,
  input  logic [CH_NUM-1:0] pa03_inc_enb,
  input  logic [CH_NUM-1:0] pa04_inc_enb,
  input  logic [CH_NUM-1:0] pa05_inc_enb,
  input  logic [CH_NUM-1:0] pa06_inc_enb,
  input  logic [CH_NUM-1:0] pa07_inc_enb,
  input  logic [CH_NUM-1:0] pa08_inc_enb,
  input  logic [CH_NUM-1:0] pa09_inc_enb,
  input  logic [15:0]       pa10_add_val[(CH_NUM/8)-1:0],
  input  logic [15:0]       pa11_add_val[(CH_NUM/8)-1:0],
  input  logic [15:0]       pa12_add_val[(CH_NUM/8)-1:0],
  input  logic [15:0]       pa13_add_val[(CH_NUM/8)-1:0],
  input  logic              dma_trace_enable,
  input  logic              dma_trace_rst,
  input  logic [31:0]       dbg_freerun_count,
  input  logic [3:0]        trace_we[CHAIN_NUM-1:0],
  input  logic [3:0][31:0]  trace_wd[CHAIN_NUM-1:0],
  output logic [3:0]        trace_we_mode,
  output logic [3:0]        trace_wd_mode,
  output logic [31:0]       trace_free_run_cnt
);

localparam CH_NUM_W    = $clog2(CH_NUM);
localparam CHAIN_NUM_W = $clog2(CHAIN_NUM);

reg                     tvalid_ff;
reg                     tvalid_pa;
reg   [511:0]           tdata_ff;
reg   [63:0]            tuser_ff;

reg   [31:0]            rdata_reg_ff;
reg   [31:0]            rdata_reg_2t_ff;
reg   [31:0]            ad_0600_ff[3:0];
reg   [31:0]            ad_0604_ff[3:0];
reg   [2:0]             ad_0680_ff;
reg   [31:0]            ad_0700_ff[3:0];
reg   [31:0]            ad_0704_ff[3:0];
reg   [31:0]            ad_0708_ff[3:0];
reg   [31:0]            ad_070c_ff[3:0];
reg   [31:0]            ad_0710_ff[3:0];
reg   [31:0]            ad_0714_ff[3:0];
reg   [31:0]            ad_07e0_ff;
reg   [31:0]            ad_07e4_ff[3:0];
reg   [31:0]            ad_07f4_ff;
reg   [31:0]            ad_07f8_ff;
reg                     ad_07fc_ff;
reg   [31:0]            ad_1600_ff;
reg   [31:0]            ad_1604_ff;
reg   [31:0]            ad_163c_ff;
reg   [31:0]            ad_1640_ff;
reg   [31:0]            ad_1644_ff;
reg   [31:0]            ad_1648_ff;
reg   [31:0]            ad_164c_ff;
reg   [31:0]            ad_1650_ff;
reg   [31:0]            ad_1654_ff;
reg   [31:0]            ad_1658_ff;
reg   [31:0]            ad_165c_ff;
reg   [31:0]            ad_1660_ff;
reg   [31:0]            ad_1664_ff;
reg   [31:0]            ad_1668_ff;
reg   [31:0]            ad_166c_ff;
reg   [31:0]            ad_1670_ff;
reg   [31:0]            ad_1674_ff;
reg   [31:0]            ad_1678_ff;
reg   [31:0]            ch_sel;
logic [31:0]            i_ad_07f8_or;
logic [31:0]            ad_07e4_or;
logic [CHAIN_NUM_W-1:0] chain_sel;
logic                   trace_mode;

`ifdef PA_CIF
logic                   rvalid_pa;
logic [31:0]            rdata_pa;
`endif
`ifdef TRACE_CIF
logic                   trace_enb;
logic                   trace_clr;
logic [3:0]             trace_re;
logic [31:0]            trace_rd[3:0];
`endif

reg                     tvalid_t1_ff;
reg                     tvalid_t2_ff;
reg                     regrep_axis_tvalid_cif_ff;
reg   [31:0]            regrep_axis_tdata_cif_ff;

//// input ////
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    tvalid_ff <= 'b0;
    tdata_ff  <= 'b0;
    tuser_ff  <= 'b0;
  end else begin
    tvalid_ff <= regreq_axis_tvalid_cif;
    tdata_ff  <= regreq_axis_tdata;
    tuser_ff  <= regreq_axis_tuser;
  end
end

//// reg  ////
//// read
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    rdata_reg_ff  <= 'b0;
  end else if(tvalid_ff & ~tuser_ff[32]) begin  // reg read
    case(tuser_ff[15:0])
      16'h0600: rdata_reg_ff <= ad_0600_ff[0]; 
      16'h0604: rdata_reg_ff <= ad_0604_ff[0]; 
      16'h0608: rdata_reg_ff <= ad_0600_ff[1]; 
      16'h060c: rdata_reg_ff <= ad_0604_ff[1]; 
      16'h0610: rdata_reg_ff <= ad_0600_ff[2]; 
      16'h0614: rdata_reg_ff <= ad_0604_ff[2]; 
      16'h0618: rdata_reg_ff <= ad_0600_ff[3]; 
      16'h061c: rdata_reg_ff <= ad_0604_ff[3]; 
      16'h0680: rdata_reg_ff <= {29'b0,ad_0680_ff}; 
      16'h0700: rdata_reg_ff <= ad_0700_ff[0];
      16'h0704: rdata_reg_ff <= ad_0704_ff[0];
      16'h0708: rdata_reg_ff <= ad_0708_ff[0];
      16'h070c: rdata_reg_ff <= ad_070c_ff[0];
      16'h0710: rdata_reg_ff <= ad_0710_ff[0];
      16'h0714: rdata_reg_ff <= ad_0714_ff[0];
      16'h0740: rdata_reg_ff <= ad_0700_ff[1];
      16'h0744: rdata_reg_ff <= ad_0704_ff[1];
      16'h0748: rdata_reg_ff <= ad_0708_ff[1];
      16'h074c: rdata_reg_ff <= ad_070c_ff[1];
      16'h0750: rdata_reg_ff <= ad_0710_ff[1];
      16'h0754: rdata_reg_ff <= ad_0714_ff[1];
      16'h0780: rdata_reg_ff <= ad_0700_ff[2];
      16'h0784: rdata_reg_ff <= ad_0704_ff[2];
      16'h0788: rdata_reg_ff <= ad_0708_ff[2];
      16'h078c: rdata_reg_ff <= ad_070c_ff[2];
      16'h0790: rdata_reg_ff <= ad_0710_ff[2];
      16'h0794: rdata_reg_ff <= ad_0714_ff[2];
      16'h07c0: rdata_reg_ff <= ad_0700_ff[3];
      16'h07c4: rdata_reg_ff <= ad_0704_ff[3];
      16'h07c8: rdata_reg_ff <= ad_0708_ff[3];
      16'h07cc: rdata_reg_ff <= ad_070c_ff[3];
      16'h07d0: rdata_reg_ff <= ad_0710_ff[3];
      16'h07d4: rdata_reg_ff <= ad_0714_ff[3];
      16'h07e0: rdata_reg_ff <= ad_07e0_ff;
      16'h07e4: rdata_reg_ff <= ad_07e4_ff[0];
      16'h07e8: rdata_reg_ff <= ad_07e4_ff[1];
      16'h07ec: rdata_reg_ff <= ad_07e4_ff[2];
      16'h07f0: rdata_reg_ff <= ad_07e4_ff[3];
      16'h07f4: rdata_reg_ff <= ad_07f4_ff;
      16'h07f8: rdata_reg_ff <= ad_07f8_ff;
      16'h07fc: rdata_reg_ff <= {29'b0,ad_07fc_ff,2'b0};
      16'h1600: rdata_reg_ff <= ad_1600_ff;
      16'h1604: rdata_reg_ff <= ad_1604_ff;
      16'h163c: rdata_reg_ff <= ad_163c_ff;
      16'h1640: rdata_reg_ff <= ad_1640_ff;
      16'h1644: rdata_reg_ff <= ad_1644_ff;
      16'h1648: rdata_reg_ff <= ad_1648_ff;
      16'h164c: rdata_reg_ff <= ad_164c_ff;
      16'h1650: rdata_reg_ff <= ad_1650_ff;
      16'h1654: rdata_reg_ff <= ad_1654_ff;
      16'h1658: rdata_reg_ff <= ad_1658_ff;
      16'h165c: rdata_reg_ff <= ad_165c_ff;
      16'h1660: rdata_reg_ff <= ad_1660_ff;
      16'h1664: rdata_reg_ff <= ad_1664_ff;
      16'h1668: rdata_reg_ff <= ad_1668_ff;
      16'h166c: rdata_reg_ff <= ad_166c_ff;
      16'h1670: rdata_reg_ff <= ad_1670_ff;
      16'h1674: rdata_reg_ff <= ad_1674_ff;
      16'h1678: rdata_reg_ff <= ad_1678_ff;
    endcase
  end else begin
    rdata_reg_ff  <= 'b0;
  end
end

//// write
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    for(int i=0; i<4; i++) begin
      ad_0600_ff[i] <= 'b0;
      ad_0604_ff[i] <= 'b0;
      ad_0700_ff[i] <= 'b0;
      ad_0704_ff[i] <= 'b0;
      ad_0708_ff[i] <= 'b0;
      ad_070c_ff[i] <= 'b0;
      ad_0710_ff[i] <= 'b0;
      ad_0714_ff[i] <= 'b0;
      ad_07e4_ff[i] <= 'b0;
    end
    ad_0680_ff <= 'b0;
    ad_07e0_ff <= 'b0;
    ad_07f4_ff <= 'b0;
    ad_07f8_ff <= 'b0;
    ad_07fc_ff <= 'b0;
    ad_1600_ff <= 'b0;
    ad_1604_ff <= 'b0;
    ad_163c_ff <= 'b0;
    ad_1640_ff <= 'b0;
    ad_1644_ff <= 'b0;
    ad_1648_ff <= 'b0;
    ad_164c_ff <= 'b0;
    ad_1650_ff <= 'b0;
    ad_1654_ff <= 'b0;
    ad_1658_ff <= 'b0;
    ad_165c_ff <= 'b0;
    ad_1660_ff <= 'b0;
    ad_1664_ff <= 'b0;
    ad_1668_ff <= 'b0;
    ad_166c_ff <= 'b0;
    ad_1670_ff <= 'b0;
    ad_1674_ff <= 'b0;
    ad_1678_ff <= 'b0;
  end else begin
    if(tvalid_ff & tuser_ff[32]) begin  // reg write
      case(tuser_ff[15:0])
        16'h0600: ad_0600_ff[0] <= tdata_ff[31:0]; 
        16'h0604: ad_0604_ff[0] <= tdata_ff[31:0]; 
        16'h0608: ad_0600_ff[1] <= tdata_ff[31:0]; 
        16'h060c: ad_0604_ff[1] <= tdata_ff[31:0]; 
        16'h0610: ad_0600_ff[2] <= tdata_ff[31:0]; 
        16'h0614: ad_0604_ff[2] <= tdata_ff[31:0]; 
        16'h0618: ad_0600_ff[3] <= tdata_ff[31:0]; 
        16'h061c: ad_0604_ff[3] <= tdata_ff[31:0]; 
        16'h0680: ad_0680_ff    <= tdata_ff[2:0]; 
        16'h07e0: begin
                  ad_07e0_ff    <= {32{~tdata_ff[0]}} & ad_07e0_ff[31:0];     // 1WC
                  ad_07e4_ff[0] <= {32{~tdata_ff[0]}} & ad_07e4_ff[0][31:0];  // 1WC
                  ad_07e4_ff[1] <= {32{~tdata_ff[0]}} & ad_07e4_ff[1][31:0];  // 1WC
                  ad_07e4_ff[2] <= {32{~tdata_ff[0]}} & ad_07e4_ff[2][31:0];  // 1WC
                  ad_07e4_ff[3] <= {32{~tdata_ff[0]}} & ad_07e4_ff[3][31:0];  // 1WC
                  end
        16'h07f4: ad_07f4_ff    <= tdata_ff[31:0];
        16'h07fc: ad_07fc_ff    <= tdata_ff[2];
        16'h1600: ad_1600_ff    <= tdata_ff[31:0];
        16'h1604: ad_1604_ff    <= tdata_ff[31:0];
        16'h163c: ad_163c_ff    <= tdata_ff[31:0];
        16'h1650: ad_1650_ff    <= tdata_ff[31:0];
      endcase
    end else begin
      ad_07e0_ff <= {31'h0,(|ad_07e4_or)};
      for(int i=0; i<CHAIN_NUM; i++) begin
        ad_07e4_ff[i] <= (ad_07e4_ff[i] | (i_ad_07e4[i] & ~ad_07f4_ff));
      end
      if (ad_07fc_ff == 1'b0) begin
        ad_07f8_ff <= 'b0;
      end else if ((ad_07f8_ff[2] == 1'b0) && (i_ad_07f8_or[2] == 1'b1)) begin
        ad_07f8_ff[2] <= 1'b1;
      end
    end
    for(int i=0; i<CHAIN_NUM; i++) begin
      ad_0700_ff[i] <= i_ad_0700[i];
      ad_0704_ff[i] <= i_ad_0704[i];
      ad_0708_ff[i] <= i_ad_0708[i];
      ad_070c_ff[i] <= i_ad_070c[i];
      ad_0710_ff[i] <= i_ad_0710[i];
      ad_0714_ff[i] <= i_ad_0714[i];
    end
    ad_1640_ff <= i_ad_1640[chain_sel];
    ad_1644_ff <= i_ad_1644[chain_sel];
    ad_1648_ff <= i_ad_1648[chain_sel];
    ad_164c_ff <= i_ad_164c[chain_sel];
    ad_1654_ff <= i_ad_1654[ch_sel];
    ad_1658_ff <= i_ad_1658[ch_sel];
    ad_165c_ff <= i_ad_165c[ch_sel];
    ad_1660_ff <= i_ad_1660[ch_sel];
    ad_1664_ff <= i_ad_1664[ch_sel];
    ad_1668_ff <= i_ad_1668[ch_sel];
    ad_166c_ff <= i_ad_166c[chain_sel];
    ad_1670_ff <= i_ad_1670[chain_sel];
    ad_1674_ff <= i_ad_1674[chain_sel];
    ad_1678_ff <= i_ad_1678[chain_sel];
  end
end

always_comb begin
  ad_07e4_or   = '0;
  i_ad_07f8_or = '0;
  for(int i=0; i<CHAIN_NUM; i++) begin
    ad_07e4_or   = ad_07e4_or   | ad_07e4_ff[i];
    i_ad_07f8_or = i_ad_07f8_or | i_ad_07f8[i];
  end
end

assign ch_sel                 = ad_1650_ff;
assign chain_sel              = ad_1650_ff[CH_NUM_W-1:CH_NUM_W-CHAIN_NUM_W];
assign o_ad_0600              = ad_0600_ff[CHAIN_NUM-1:0];
assign o_ad_0604              = ad_0604_ff[CHAIN_NUM-1:0];
assign o_ad_0680              = ad_0680_ff;
assign o_ad_07e0              = ad_07e0_ff[0];
assign o_ad_07e4              = ad_07e4_ff[CHAIN_NUM-1:0];
assign o_ad_07f4              = ad_07f4_ff;
assign o_ad_07f8              = ad_07f8_ff[2];
assign o_ad_07fc              = ad_07fc_ff;
assign o_ad_1600              = ad_1600_ff;
assign trace_mode             = ad_1604_ff[0];
assign trace_we_mode          = ad_1604_ff[7:4];
assign trace_wd_mode          = ad_1604_ff[11:8];

//// pa ////
`ifdef PA_CIF
pa_cnt3_wrapper #(
  .CH_NUM(CH_NUM), .FF_NUM(1)
) pa_cnt (
  .user_clk      (user_clk),
  .reset_n       (reset_n),

  .reg_base_addr (7'b0001_011),  // reg_base_addr[15:0]=0001_011x_xxxx_xxxx
  .regreq_tvalid (tvalid_pa),
  .regreq_tdata  (tdata_ff[31:0]),
  .regreq_tuser  (tuser_ff[32:0]),
  .regrep_tvalid (rvalid_pa),
  .regrep_tdata  (rdata_pa),

  .pa_enb        (dbg_enable),
  .pa_clr        (dbg_count_reset),

  .pa00_inc_enb  (pa00_inc_enb),
  .pa01_inc_enb  (pa01_inc_enb),
  .pa02_inc_enb  (pa02_inc_enb),
  .pa03_inc_enb  (pa03_inc_enb),
  .pa04_inc_enb  (pa04_inc_enb),
  .pa05_inc_enb  (pa05_inc_enb),
  .pa06_inc_enb  (pa06_inc_enb),
  .pa07_inc_enb  (pa07_inc_enb),
  .pa08_inc_enb  (pa08_inc_enb),
  .pa09_inc_enb  (pa09_inc_enb),
  .pa10_add_val  (pa10_add_val),
  .pa11_add_val  (pa11_add_val),
  .pa12_add_val  (pa12_add_val),
  .pa13_add_val  (pa13_add_val)
); 
`endif

//// trace ////
`ifdef TRACE_CIF
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    trace_enb           <= '0;
    trace_clr           <= '0;
    trace_free_run_cnt  <= '0;
  end else begin
    trace_enb           <= dma_trace_enable;
    trace_clr           <= dma_trace_rst;
    trace_free_run_cnt  <= dbg_freerun_count;
  end
 end

assign trace_re[0] = tvalid_ff & ~tuser_ff[32] & (tuser_ff[15:0]==16'h17E0);
assign trace_re[1] = tvalid_ff & ~tuser_ff[32] & (tuser_ff[15:0]==16'h17E4);
assign trace_re[2] = tvalid_ff & ~tuser_ff[32] & (tuser_ff[15:0]==16'h17E8);
assign trace_re[3] = tvalid_ff & ~tuser_ff[32] & (tuser_ff[15:0]==16'h17EC);

for (genvar i = 0; i < 4; i++) begin : TRACE_DN
  trace_ram TRACE_RX (
    .user_clk(user_clk),
    .reset_n(reset_n),
    .trace_clr(trace_clr),
    .trace_enb(trace_enb),
    .trace_we(trace_we[ad_163c_ff[CHAIN_NUM_W-1:0]][i]),
    .trace_wd(trace_wd[ad_163c_ff[CHAIN_NUM_W-1:0]][i][31:0]),
    .trace_re(trace_re[i]),
    .trace_mode(trace_mode),
    .trace_rd(trace_rd[i][31:0])
  );
end
`endif

//// output ////
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    tvalid_t1_ff              <= 'b0;
    tvalid_t2_ff              <= 'b0;
    rdata_reg_2t_ff           <= 'b0;
    regrep_axis_tvalid_cif_ff <= 'b0;
    regrep_axis_tdata_cif_ff  <= 'b0;
  end else begin
    tvalid_t1_ff              <= tvalid_ff & ~tuser_ff[32] & (tuser_ff[15:13] == 3'b000) & (tuser_ff[11:9] == 3'b011) & ~((tuser_ff[15:0] == 16'h1638) | (tuser_ff[15:7] == 9'b0001_0110_1) | ((tuser_ff[15:7] == 9'b0001_0111_1) & (tuser_ff[6:5] != 2'h3)));
`ifdef PA_CIF
    tvalid_t2_ff              <= tvalid_t1_ff | rvalid_pa;
    rdata_reg_2t_ff           <= rdata_reg_ff | rdata_pa;
`else
    tvalid_t2_ff              <= tvalid_t1_ff;
    rdata_reg_2t_ff           <= rdata_reg_ff;
`endif
    regrep_axis_tvalid_cif_ff <= tvalid_t2_ff;
`ifdef TRACE_CIF
    regrep_axis_tdata_cif_ff  <= rdata_reg_2t_ff | trace_rd[0] | trace_rd[1] | trace_rd[2] | trace_rd[3];
`else
    regrep_axis_tdata_cif_ff  <= rdata_reg_2t_ff;
`endif
  end
end

assign tvalid_pa              = tvalid_ff & ((tuser_ff[15:0] == 16'h1638) | (tuser_ff[15:7] == 9'b0001_0110_1) | ((tuser_ff[15:7] == 9'b0001_0111_1) & (tuser_ff[6:5] != 2'h3)));
assign regrep_axis_tvalid_cif = regrep_axis_tvalid_cif_ff;
assign regrep_axis_tdata_cif  = regrep_axis_tdata_cif_ff;

endmodule
