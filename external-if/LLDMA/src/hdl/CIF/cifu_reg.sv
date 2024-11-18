/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`define PA_CIF
`define TRACE_CIF

module cifu_reg #(
  parameter CH_NUM      = 32,
  parameter CHAIN_NUM   = 4
)(
  input  logic               reset_n,
  input  logic               user_clk,

  input  logic               regreq_axis_tvalid_cif,
  input  logic [511:0]       regreq_axis_tdata,
  input  logic               regreq_axis_tlast,
  input  logic [63:0]        regreq_axis_tuser,
  output logic               regrep_axis_tvalid_cif,
  output logic [31:0]        regrep_axis_tdata_cif,

  output logic [31:0]        o_ad_0800[CHAIN_NUM-1:0],
  output logic [31:0]        o_ad_0804[CHAIN_NUM-1:0],
  output logic [2:0]         o_ad_0880,
  output logic               o_ad_09e0,
  output logic [31:0]        o_ad_09e4[CHAIN_NUM-1:0],
  output logic [31:0]        o_ad_09f4,
  output logic               o_ad_09f8,
  output logic               o_ad_09fc,
  output logic [31:0]        o_ad_1800,
  input  logic [31:0]        i_ad_0900[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_0904[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_0908[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_090c[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_0910[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_0914[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_09e4[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_09f8[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_1840[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_1844[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_1848[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_184c[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_1854[CH_NUM-1:0],
  input  logic [31:0]        i_ad_1858[CH_NUM-1:0],
  input  logic [31:0]        i_ad_185c[CH_NUM-1:0],
  input  logic [31:0]        i_ad_1860[CH_NUM-1:0],
  input  logic [31:0]        i_ad_1864[CH_NUM-1:0],
  input  logic [31:0]        i_ad_1868[CH_NUM-1:0],
  input  logic [31:0]        i_ad_186c[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_1870[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_1874[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_1878[CHAIN_NUM-1:0],
  input  logic [31:0]        i_ad_187c[CHAIN_NUM-1:0],

  input  logic [31:0]        i_dbg_dma_size[CH_NUM-1:0],
  input  logic               dbg_enable,
  input  logic               dbg_count_reset,
  input  logic [CH_NUM-1:0]  pa00_inc_enb,
  input  logic [CH_NUM-1:0]  pa01_inc_enb,
  input  logic [CH_NUM-1:0]  pa02_inc_enb,
  input  logic [CH_NUM-1:0]  pa03_inc_enb,
  input  logic [CH_NUM-1:0]  pa04_inc_enb,
  input  logic [CH_NUM-1:0]  pa05_inc_enb,
  input  logic [15:0]        pa10_add_val[(CH_NUM/8)-1:0],
  input  logic [15:0]        pa11_add_val[(CH_NUM/8)-1:0],
  input  logic [15:0]        pa12_add_val[(CH_NUM/8)-1:0],
  input  logic [15:0]        pa13_add_val[(CH_NUM/8)-1:0],
  input  logic               dma_trace_enable,
  input  logic               dma_trace_rst,
  input  logic [31:0]        dbg_freerun_count,
  input  logic [3:0]         trace_we[CHAIN_NUM-1:0],
  input  logic [3:0][31:0]   trace_wd[CHAIN_NUM-1:0],
  output logic [3:0]         trace_we_mode,
  output logic [3:0]         trace_wd_mode,
  output logic [31:0]        trace_free_run_cnt
);

localparam CH_NUM_W    = $clog2(CH_NUM);
localparam CHAIN_NUM_W = $clog2(CHAIN_NUM);

reg                   tvalid_ff;
reg                   tvalid_pa;
reg   [511:0]         tdata_ff;
reg   [63:0]          tuser_ff;

reg   [31:0]          rdata_reg_ff;
reg   [31:0]          rdata_reg_2t_ff;
reg   [31:0]          ad_0800_ff[3:0];
reg   [31:0]          ad_0804_ff[3:0];
reg   [2:0]           ad_0880_ff;
reg   [31:0]          ad_0900_ff[3:0];
reg   [31:0]          ad_0904_ff[3:0];
reg   [31:0]          ad_0908_ff[3:0];
reg   [31:0]          ad_090c_ff[3:0];
reg   [31:0]          ad_0910_ff[3:0];
reg   [31:0]          ad_0914_ff[3:0];
reg   [31:0]          ad_09e0_ff;
reg   [31:0]          ad_09e4_ff[3:0];
reg   [31:0]          ad_09f4_ff;
reg   [31:0]          ad_09f8_ff;
reg                   ad_09fc_ff;
reg   [31:0]          ad_1800_ff;
reg   [31:0]          ad_1804_ff;
reg   [31:0]          ad_183c_ff;
reg   [31:0]          ad_1840_ff;
reg   [31:0]          ad_1844_ff;
reg   [31:0]          ad_1848_ff;
reg   [31:0]          ad_184c_ff;
reg   [31:0]          ad_1850_ff;
reg   [31:0]          ad_1854_ff;
reg   [31:0]          ad_1858_ff;
reg   [31:0]          ad_185c_ff;
reg   [31:0]          ad_1860_ff;
reg   [31:0]          ad_1864_ff;
reg   [31:0]          ad_1868_ff;
reg   [31:0]          ad_186c_ff;
reg   [31:0]          ad_1870_ff;
reg   [31:0]          ad_1874_ff;
reg   [31:0]          ad_1878_ff;
reg   [31:0]          ad_187c_ff;
reg   [31:0]          ch_sel;
logic [31:0]          ad_09e4_or;
logic [31:0]          i_ad_09f8_or;
logic [CHAIN_NUM_W:0] chain_sel;
logic                 trace_mode;

`ifdef PA_CIF
logic                 rvalid_pa;
logic [31:0]          rdata_pa;
`endif
`ifdef TRACE_CIF
logic                 trace_enb;
logic                 trace_clr;
logic [3:0]           trace_re;
logic [31:0]          trace_rd[3:0];
`endif

reg                   tvalid_t1_ff;
reg                   tvalid_t2_ff;
reg                   regrep_axis_tvalid_cif_ff;
reg   [31:0]          regrep_axis_tdata_cif_ff;

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
wire [$clog2(CH_NUM)-1:0] ch_idx = tuser_ff[2+:$clog2(CH_NUM)];
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    rdata_reg_ff  <= 'b0;
  end else if(tvalid_ff & ~tuser_ff[32]) begin  // reg read
    case(tuser_ff[15:0]) inside
      16'h0800: rdata_reg_ff <= ad_0800_ff[0]; 
      16'h0804: rdata_reg_ff <= ad_0804_ff[0]; 
      16'h0808: rdata_reg_ff <= ad_0800_ff[1]; 
      16'h080c: rdata_reg_ff <= ad_0804_ff[1]; 
      16'h0810: rdata_reg_ff <= ad_0800_ff[2]; 
      16'h0814: rdata_reg_ff <= ad_0804_ff[2]; 
      16'h0818: rdata_reg_ff <= ad_0800_ff[3]; 
      16'h081c: rdata_reg_ff <= ad_0804_ff[3]; 
      16'h0880: rdata_reg_ff <= {29'b0,ad_0880_ff}; 
      16'h0900: rdata_reg_ff <= ad_0900_ff[0];
      16'h0904: rdata_reg_ff <= ad_0904_ff[0];
      16'h0908: rdata_reg_ff <= ad_0908_ff[0];
      16'h090c: rdata_reg_ff <= ad_090c_ff[0];
      16'h0910: rdata_reg_ff <= ad_0910_ff[0];
      16'h0914: rdata_reg_ff <= ad_0914_ff[0];
      16'h0940: rdata_reg_ff <= ad_0900_ff[1];
      16'h0944: rdata_reg_ff <= ad_0904_ff[1];
      16'h0948: rdata_reg_ff <= ad_0908_ff[1];
      16'h094c: rdata_reg_ff <= ad_090c_ff[1];
      16'h0950: rdata_reg_ff <= ad_0910_ff[1];
      16'h0954: rdata_reg_ff <= ad_0914_ff[1];
      16'h0980: rdata_reg_ff <= ad_0900_ff[2];
      16'h0984: rdata_reg_ff <= ad_0904_ff[2];
      16'h0988: rdata_reg_ff <= ad_0908_ff[2];
      16'h098c: rdata_reg_ff <= ad_090c_ff[2];
      16'h0990: rdata_reg_ff <= ad_0910_ff[2];
      16'h0994: rdata_reg_ff <= ad_0914_ff[2];
      16'h09c0: rdata_reg_ff <= ad_0900_ff[3];
      16'h09c4: rdata_reg_ff <= ad_0904_ff[3];
      16'h09c8: rdata_reg_ff <= ad_0908_ff[3];
      16'h09cc: rdata_reg_ff <= ad_090c_ff[3];
      16'h09d0: rdata_reg_ff <= ad_0910_ff[3];
      16'h09d4: rdata_reg_ff <= ad_0914_ff[3];
      16'h09e0: rdata_reg_ff <= ad_09e0_ff;
      16'h09e4: rdata_reg_ff <= ad_09e4_ff[0];
      16'h09e8: rdata_reg_ff <= ad_09e4_ff[1];
      16'h09ec: rdata_reg_ff <= ad_09e4_ff[2];
      16'h09f0: rdata_reg_ff <= ad_09e4_ff[3];
      16'h09f4: rdata_reg_ff <= ad_09f4_ff;
      16'h09f8: rdata_reg_ff <= ad_09f8_ff;
      16'h09fc: rdata_reg_ff <= {29'b0,ad_09fc_ff,2'b0};
      16'h1800: rdata_reg_ff <= ad_1800_ff;
      16'h1804: rdata_reg_ff <= ad_1804_ff;
      16'h183c: rdata_reg_ff <= ad_183c_ff;
      16'h1840: rdata_reg_ff <= ad_1840_ff;
      16'h1844: rdata_reg_ff <= ad_1844_ff;
      16'h1848: rdata_reg_ff <= ad_1848_ff;
      16'h184c: rdata_reg_ff <= ad_184c_ff;
      16'h1850: rdata_reg_ff <= ad_1850_ff;
      16'h1854: rdata_reg_ff <= ad_1854_ff;
      16'h1858: rdata_reg_ff <= ad_1858_ff;
      16'h185c: rdata_reg_ff <= ad_185c_ff;
      16'h1860: rdata_reg_ff <= ad_1860_ff;
      16'h1864: rdata_reg_ff <= ad_1864_ff;
      16'h1868: rdata_reg_ff <= ad_1868_ff;
      16'h186c: rdata_reg_ff <= ad_186c_ff;
      16'h1870: rdata_reg_ff <= ad_1870_ff;
      16'h1874: rdata_reg_ff <= ad_1874_ff;
      16'h1878: rdata_reg_ff <= ad_1878_ff;
      16'h187c: rdata_reg_ff <= ad_187c_ff;
      16'h19??: rdata_reg_ff <= i_dbg_dma_size[ch_idx];
      default: rdata_reg_ff <= 'b0;
    endcase
  end else begin
    rdata_reg_ff  <= 'b0;
  end
end

//// write
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    for(int i=0; i<4; i++) begin
      ad_0800_ff[i] <= 'b0;
      ad_0804_ff[i] <= 'b0;
      ad_0900_ff[i] <= 'b0;
      ad_0904_ff[i] <= 'b0;
      ad_0908_ff[i] <= 'b0;
      ad_090c_ff[i] <= 'b0;
      ad_0910_ff[i] <= 'b0;
      ad_0914_ff[i] <= 'b0;
      ad_09e4_ff[i] <= 'b0;
    end
    ad_0880_ff <= 'b0;
    ad_09e0_ff <= 'b0;
    ad_09f4_ff <= 'b0;
    ad_09f8_ff <= 'b0;
    ad_09fc_ff <= 'b0;
    ad_1800_ff <= 'b0;
    ad_1804_ff <= 'b0;
    ad_183c_ff <= 'b0;
    ad_1840_ff <= 'b0;
    ad_1844_ff <= 'b0;
    ad_1848_ff <= 'b0;
    ad_184c_ff <= 'b0;
    ad_1850_ff <= 'b0;
    ad_1854_ff <= 'b0;
    ad_1858_ff <= 'b0;
    ad_185c_ff <= 'b0;
    ad_1860_ff <= 'b0;
    ad_1864_ff <= 'b0;
    ad_1868_ff <= 'b0;
    ad_186c_ff <= 'b0;
    ad_1870_ff <= 'b0;
    ad_1874_ff <= 'b0;
    ad_1878_ff <= 'b0;
    ad_187c_ff <= 'b0;
  end else begin
    if(tvalid_ff & tuser_ff[32]) begin  // reg write
      case(tuser_ff[15:0])
        16'h0800: ad_0800_ff[0] <= tdata_ff[31:0]; 
        16'h0804: ad_0804_ff[0] <= tdata_ff[31:0]; 
        16'h0808: ad_0800_ff[1] <= tdata_ff[31:0]; 
        16'h080c: ad_0804_ff[1] <= tdata_ff[31:0]; 
        16'h0810: ad_0800_ff[2] <= tdata_ff[31:0]; 
        16'h0814: ad_0804_ff[2] <= tdata_ff[31:0]; 
        16'h0818: ad_0800_ff[3] <= tdata_ff[31:0]; 
        16'h081c: ad_0804_ff[3] <= tdata_ff[31:0]; 
        16'h0880: ad_0880_ff    <= tdata_ff[2:0]; 
        16'h09e0: begin
                  ad_09e0_ff    <= {32{~tdata_ff[0]}} & ad_09e0_ff[31:0];     // 1WC
                  ad_09e4_ff[0] <= {32{~tdata_ff[0]}} & ad_09e4_ff[0][31:0];  // 1WC
                  ad_09e4_ff[1] <= {32{~tdata_ff[0]}} & ad_09e4_ff[1][31:0];  // 1WC
                  ad_09e4_ff[2] <= {32{~tdata_ff[0]}} & ad_09e4_ff[2][31:0];  // 1WC
                  ad_09e4_ff[3] <= {32{~tdata_ff[0]}} & ad_09e4_ff[3][31:0];  // 1WC
                  end
        16'h09f4: ad_09f4_ff    <= tdata_ff[31:0];
        16'h09fc: ad_09fc_ff    <= tdata_ff[2];
        16'h1800: ad_1800_ff    <= tdata_ff[31:0];
        16'h1804: ad_1804_ff    <= tdata_ff[31:0];
        16'h183c: ad_183c_ff    <= tdata_ff[31:0];
        16'h1850: ad_1850_ff    <= tdata_ff[31:0];
      endcase
    end else begin
      ad_09e0_ff <= {31'h0,(|ad_09e4_or)};
      for(int i=0; i<CHAIN_NUM; i++) begin
        ad_09e4_ff[i] <= (ad_09e4_ff[i] | (i_ad_09e4[i] & ~ad_09f4_ff));
      end
      if (ad_09fc_ff == 1'b0) begin
        ad_09f8_ff <= 'b0;
      end else if ((ad_09f8_ff[2] == 1'b0) && (i_ad_09f8_or[2] == 1'b1)) begin
        ad_09f8_ff[2] <= 1'b1;
      end
    end
    for(int i=0; i<CHAIN_NUM; i++) begin
      ad_0900_ff[i] <= i_ad_0900[i];
      ad_0904_ff[i] <= i_ad_0904[i];
      ad_0908_ff[i] <= i_ad_0908[i];
      ad_090c_ff[i] <= i_ad_090c[i];
      ad_0910_ff[i] <= i_ad_0910[i];
      ad_0914_ff[i] <= i_ad_0914[i];
    end
    ad_1840_ff <= i_ad_1840[chain_sel];
    ad_1844_ff <= i_ad_1844[chain_sel];
    ad_1848_ff <= i_ad_1848[chain_sel];
    ad_184c_ff <= i_ad_184c[chain_sel];
    ad_1854_ff <= i_ad_1854[ch_sel];
    ad_1858_ff <= i_ad_1858[ch_sel];
    ad_185c_ff <= i_ad_185c[ch_sel];
    ad_1860_ff <= i_ad_1860[ch_sel];
    ad_1864_ff <= i_ad_1864[ch_sel];
    ad_1868_ff <= i_ad_1868[ch_sel];
    ad_186c_ff <= i_ad_186c[chain_sel];
    ad_1870_ff <= i_ad_1870[chain_sel];
    ad_1874_ff <= i_ad_1874[chain_sel];
    ad_1878_ff <= i_ad_1878[chain_sel];
    ad_187c_ff <= i_ad_187c[chain_sel];
  end
end

always_comb begin
  ad_09e4_or   = '0;
  i_ad_09f8_or = '0;
  for(int i=0; i<CHAIN_NUM; i++) begin
    ad_09e4_or   = ad_09e4_or   | ad_09e4_ff[i];
    i_ad_09f8_or = i_ad_09f8_or | i_ad_09f8[i];
  end
end

assign ch_sel                 = ad_1850_ff;
assign chain_sel              = ad_1850_ff[CH_NUM_W-1:CH_NUM_W-CHAIN_NUM_W];
assign o_ad_0800              = ad_0800_ff[CHAIN_NUM-1:0];
assign o_ad_0804              = ad_0804_ff[CHAIN_NUM-1:0];
assign o_ad_0880              = ad_0880_ff;
assign o_ad_09e0              = ad_09e0_ff[0];
assign o_ad_09e4              = ad_09e4_ff[CHAIN_NUM-1:0];
assign o_ad_09f4              = ad_09f4_ff;
assign o_ad_09f8              = ad_09f8_ff[2];
assign o_ad_09fc              = ad_09fc_ff;
assign o_ad_1800              = ad_1800_ff;
assign trace_mode             = ad_1804_ff[0];
assign trace_we_mode          = ad_1804_ff[7:4];
assign trace_wd_mode          = ad_1804_ff[11:8];

//// pa ////
`ifdef PA_CIF
pa_cnt3_wrapper #(
  .CH_NUM(CH_NUM), .FF_NUM(2)
) pa_cnt (
  .user_clk      (user_clk),
  .reset_n       (reset_n),

  .reg_base_addr (7'b0001_100),  // reg_base_addr[15:0]=0001_100x_xxxx_xxxx
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
  .pa06_inc_enb  ({CH_NUM{1'b0}}),
  .pa07_inc_enb  ({CH_NUM{1'b0}}),
  .pa08_inc_enb  ({CH_NUM{1'b0}}),
  .pa09_inc_enb  ({CH_NUM{1'b0}}),
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

assign trace_re[0] = tvalid_ff & ~tuser_ff[32] & (tuser_ff[15:0]==16'h19E0);
assign trace_re[1] = tvalid_ff & ~tuser_ff[32] & (tuser_ff[15:0]==16'h19E4);
assign trace_re[2] = tvalid_ff & ~tuser_ff[32] & (tuser_ff[15:0]==16'h19E8);
assign trace_re[3] = tvalid_ff & ~tuser_ff[32] & (tuser_ff[15:0]==16'h19EC);

for (genvar i = 0; i < 4; i++) begin : TRACE_UP
  trace_ram TRACE_RX (
    .user_clk(user_clk),
    .reset_n(reset_n),
    .trace_clr(trace_clr),
    .trace_enb(trace_enb),
    .trace_we(trace_we[ad_183c_ff[CHAIN_NUM_W-1:0]][i]),
    .trace_wd(trace_wd[ad_183c_ff[CHAIN_NUM_W-1:0]][i][31:0]),
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
    tvalid_t1_ff              <= tvalid_ff & ~tuser_ff[32] & (tuser_ff[15:13] == 3'b000) & (tuser_ff[11:9] == 3'b100) & ~((tuser_ff[15:0] == 16'h1838) | (tuser_ff[15:7] == 9'b0001_1000_1) | ((tuser_ff[15:7] == 9'b0001_1001_1) & (tuser_ff[6:5] != 2'h3)));
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

assign tvalid_pa              = tvalid_ff & ((tuser_ff[15:0] == 16'h1838) | (tuser_ff[15:7] == 9'b0001_1000_1) | ((tuser_ff[15:7] == 9'b0001_1001_1) & (tuser_ff[6:5] != 2'h3)));
assign regrep_axis_tvalid_cif = regrep_axis_tvalid_cif_ff;
assign regrep_axis_tdata_cif  = regrep_axis_tdata_cif_ff;

endmodule
