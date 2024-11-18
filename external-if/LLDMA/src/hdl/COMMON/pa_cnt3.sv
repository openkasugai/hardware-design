/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module pa_cnt3 # (
  parameter CH_NUM         = 16,
  parameter CHAIN_NUM      = CH_NUM/8
  )
  (
  input  logic	 user_clk,
  input  logic	 reset_n,

// Register access IF ///////////////////////////////////////////////////////////////////////
  input  logic [15:9]   reg_base_addr,
  input  logic	 	regreq_tvalid,
  input  logic [31:0]	regreq_tdata,
  input  logic [32:0]	regreq_tuser,
  output logic [31:0]	regreq_rdt,

// PA Counter /////////////////////////////////////////////////////////////////////////////
  input  logic	 	pa_enb,
  input  logic	 	pa_clr,

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
  input  logic [15:0]	pa10_add_val[CHAIN_NUM-1:0],
  input  logic [15:0]	pa11_add_val[CHAIN_NUM-1:0],
  input  logic [15:0]	pa12_add_val[CHAIN_NUM-1:0],
  input  logic [15:0]	pa13_add_val[CHAIN_NUM-1:0]

);

// PA Counter /////////////////////////////////////////////////////////////////////////////
  logic	 	pa_enb_1t;
  logic	 	pa_clr_1t;

  logic [CHAIN_NUM-1:0] 	pa00_inc_enb_1t;
  logic [CHAIN_NUM-1:0] 	pa01_inc_enb_1t;
  logic [CHAIN_NUM-1:0] 	pa02_inc_enb_1t;
  logic [CHAIN_NUM-1:0] 	pa03_inc_enb_1t;
  logic [CHAIN_NUM-1:0] 	pa04_inc_enb_1t;
  logic [CHAIN_NUM-1:0] 	pa05_inc_enb_1t;
  logic [CHAIN_NUM-1:0] 	pa06_inc_enb_1t;
  logic [CHAIN_NUM-1:0] 	pa07_inc_enb_1t;
  logic [CHAIN_NUM-1:0] 	pa08_inc_enb_1t;
  logic [CHAIN_NUM-1:0] 	pa09_inc_enb_1t;
  logic [15:0]	pa10_add_val_1t[CHAIN_NUM-1:0];
  logic [15:0]	pa11_add_val_1t[CHAIN_NUM-1:0];
  logic [15:0]	pa12_add_val_1t[CHAIN_NUM-1:0];
  logic [15:0]	pa13_add_val_1t[CHAIN_NUM-1:0];
  logic [CH_NUM-1:0] 	pa14_inc_enb_1t;
  logic [CH_NUM-1:0] 	pa15_inc_enb_1t;
  logic [CH_NUM-1:0] 	pa16_inc_enb_1t;
  logic [CH_NUM-1:0] 	pa17_inc_enb_1t;

  logic	[39:0]	pa00_cnt[CHAIN_NUM-1:0];
  logic	[39:0]	pa01_cnt[CHAIN_NUM-1:0];
  logic	[39:0]	pa02_cnt[CHAIN_NUM-1:0];
  logic	[39:0]	pa03_cnt[CHAIN_NUM-1:0];
  logic	[39:0]	pa04_cnt[CHAIN_NUM-1:0];
  logic	[39:0]	pa05_cnt[CHAIN_NUM-1:0];
  logic	[39:0]	pa06_cnt[CHAIN_NUM-1:0];
  logic	[39:0]	pa07_cnt[CHAIN_NUM-1:0];
  logic	[39:0]	pa08_cnt[CHAIN_NUM-1:0];
  logic	[39:0]	pa09_cnt[CHAIN_NUM-1:0];

  logic	[63:0]	pa10_cnt[CHAIN_NUM-1:0];
  logic	[63:0]	pa11_cnt[CHAIN_NUM-1:0];
  logic	[63:0]	pa12_cnt[CHAIN_NUM-1:0];
  logic	[63:0]	pa13_cnt[CHAIN_NUM-1:0];
  logic	[64:0]	pa10_cnt_mod[CHAIN_NUM-1:0];
  logic	[64:0]	pa11_cnt_mod[CHAIN_NUM-1:0];
  logic	[64:0]	pa12_cnt_mod[CHAIN_NUM-1:0];
  logic	[64:0]	pa13_cnt_mod[CHAIN_NUM-1:0];
  logic	[15:0]	pa10_max[CHAIN_NUM-1:0];
  logic	[15:0]	pa11_max[CHAIN_NUM-1:0];
  logic	[15:0]	pa12_max[CHAIN_NUM-1:0];
  logic	[15:0]	pa13_max[CHAIN_NUM-1:0];

  logic	[39:0]	pa14_cnt[CH_NUM-1:0];
  logic	[39:0]	pa15_cnt[CH_NUM-1:0];
  logic	[39:0]	pa16_cnt[CH_NUM-1:0];
  logic	[39:0]	pa17_cnt[CH_NUM-1:0];

  logic	[7:0]	chain_sel;
  logic	[3:0]	pa14_sel;
  logic	[3:0]	pa15_sel;
  logic	[3:0]	pa16_sel;
  logic	[3:0]	pa17_sel;
  logic		reg_wt_valid;
  logic		reg_rd_valid;

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      pa00_inc_enb_1t    <= '0;
      pa01_inc_enb_1t    <= '0;
      pa02_inc_enb_1t    <= '0;
      pa03_inc_enb_1t    <= '0;
      pa04_inc_enb_1t    <= '0;
      pa05_inc_enb_1t    <= '0;
      pa06_inc_enb_1t    <= '0;
      pa07_inc_enb_1t    <= '0;
      pa08_inc_enb_1t    <= '0;
      pa09_inc_enb_1t    <= '0;
      for (int i = 0; i < CHAIN_NUM; i++) begin
        pa10_add_val_1t[i] <= '0;
        pa11_add_val_1t[i] <= '0;
        pa12_add_val_1t[i] <= '0;
        pa13_add_val_1t[i] <= '0;
      end
      pa14_inc_enb_1t    <= '0;
      pa15_inc_enb_1t    <= '0;
      pa16_inc_enb_1t    <= '0;
      pa17_inc_enb_1t    <= '0;
    end
    else begin
      for (int i = 0; i < CHAIN_NUM; i++) begin
        pa00_inc_enb_1t[i] <= |pa00_inc_enb[i*8 +: 8];
        pa01_inc_enb_1t[i] <= |pa01_inc_enb[i*8 +: 8];
        pa02_inc_enb_1t[i] <= |pa02_inc_enb[i*8 +: 8];
        pa03_inc_enb_1t[i] <= |pa03_inc_enb[i*8 +: 8];
        pa04_inc_enb_1t[i] <= |pa04_inc_enb[i*8 +: 8];
        pa05_inc_enb_1t[i] <= |pa05_inc_enb[i*8 +: 8];
        pa06_inc_enb_1t[i] <= |pa06_inc_enb[i*8 +: 8];
        pa07_inc_enb_1t[i] <= |pa07_inc_enb[i*8 +: 8];
        pa08_inc_enb_1t[i] <= |pa08_inc_enb[i*8 +: 8];
        pa09_inc_enb_1t[i] <= |pa09_inc_enb[i*8 +: 8];
        pa10_add_val_1t[i] <= pa10_add_val[i];
        pa11_add_val_1t[i] <= pa11_add_val[i];
        pa12_add_val_1t[i] <= pa12_add_val[i];
        pa13_add_val_1t[i] <= pa13_add_val[i];
      end
      for (int i = 0; i < CH_NUM; i++) begin
        case(pa14_sel[3:0])
          4'h0 : pa14_inc_enb_1t[i] <= pa00_inc_enb[i];
          4'h1 : pa14_inc_enb_1t[i] <= pa01_inc_enb[i];
          4'h2 : pa14_inc_enb_1t[i] <= pa02_inc_enb[i];
          4'h3 : pa14_inc_enb_1t[i] <= pa03_inc_enb[i];
          4'h4 : pa14_inc_enb_1t[i] <= pa04_inc_enb[i];
          4'h5 : pa14_inc_enb_1t[i] <= pa05_inc_enb[i];
          4'h6 : pa14_inc_enb_1t[i] <= pa06_inc_enb[i];
          4'h7 : pa14_inc_enb_1t[i] <= pa07_inc_enb[i];
          4'h8 : pa14_inc_enb_1t[i] <= pa08_inc_enb[i];
          4'h9 : pa14_inc_enb_1t[i] <= pa09_inc_enb[i];
	  default : pa14_inc_enb_1t[i] <= '0;
        endcase
        case(pa15_sel[3:0])
          4'h0 : pa15_inc_enb_1t[i] <= pa00_inc_enb[i];
          4'h1 : pa15_inc_enb_1t[i] <= pa01_inc_enb[i];
          4'h2 : pa15_inc_enb_1t[i] <= pa02_inc_enb[i];
          4'h3 : pa15_inc_enb_1t[i] <= pa03_inc_enb[i];
          4'h4 : pa15_inc_enb_1t[i] <= pa04_inc_enb[i];
          4'h5 : pa15_inc_enb_1t[i] <= pa05_inc_enb[i];
          4'h6 : pa15_inc_enb_1t[i] <= pa06_inc_enb[i];
          4'h7 : pa15_inc_enb_1t[i] <= pa07_inc_enb[i];
          4'h8 : pa15_inc_enb_1t[i] <= pa08_inc_enb[i];
          4'h9 : pa15_inc_enb_1t[i] <= pa09_inc_enb[i];
	  default : pa14_inc_enb_1t[i] <= '0;
        endcase
        case(pa16_sel[3:0])
          4'h0 : pa16_inc_enb_1t[i] <= pa00_inc_enb[i];
          4'h1 : pa16_inc_enb_1t[i] <= pa01_inc_enb[i];
          4'h2 : pa16_inc_enb_1t[i] <= pa02_inc_enb[i];
          4'h3 : pa16_inc_enb_1t[i] <= pa03_inc_enb[i];
          4'h4 : pa16_inc_enb_1t[i] <= pa04_inc_enb[i];
          4'h5 : pa16_inc_enb_1t[i] <= pa05_inc_enb[i];
          4'h6 : pa16_inc_enb_1t[i] <= pa06_inc_enb[i];
          4'h7 : pa16_inc_enb_1t[i] <= pa07_inc_enb[i];
          4'h8 : pa16_inc_enb_1t[i] <= pa08_inc_enb[i];
          4'h9 : pa16_inc_enb_1t[i] <= pa09_inc_enb[i];
	  default : pa14_inc_enb_1t[i] <= '0;
        endcase
        case(pa17_sel[3:0])
          4'h0 : pa17_inc_enb_1t[i] <= pa00_inc_enb[i];
          4'h1 : pa17_inc_enb_1t[i] <= pa01_inc_enb[i];
          4'h2 : pa17_inc_enb_1t[i] <= pa02_inc_enb[i];
          4'h3 : pa17_inc_enb_1t[i] <= pa03_inc_enb[i];
          4'h4 : pa17_inc_enb_1t[i] <= pa04_inc_enb[i];
          4'h5 : pa17_inc_enb_1t[i] <= pa05_inc_enb[i];
          4'h6 : pa17_inc_enb_1t[i] <= pa06_inc_enb[i];
          4'h7 : pa17_inc_enb_1t[i] <= pa07_inc_enb[i];
          4'h8 : pa17_inc_enb_1t[i] <= pa08_inc_enb[i];
          4'h9 : pa17_inc_enb_1t[i] <= pa09_inc_enb[i];
	  default : pa14_inc_enb_1t[i] <= '0;
        endcase
      end
    end
  end

  always_comb begin
    for (int i = 0; i < CHAIN_NUM; i++) begin
      pa10_cnt_mod[i] = pa10_cnt[i] + pa10_add_val_1t[i];
      pa11_cnt_mod[i] = pa11_cnt[i] + pa11_add_val_1t[i];
      pa12_cnt_mod[i] = pa12_cnt[i] + pa12_add_val_1t[i];
      pa13_cnt_mod[i] = pa13_cnt[i] + pa13_add_val_1t[i];
    end
  end

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      pa_enb_1t <= '0;
      pa_clr_1t <= '0;
      for (int i = 0; i < CHAIN_NUM; i++) begin
        pa00_cnt[i] <= '0;
        pa01_cnt[i] <= '0;
        pa02_cnt[i] <= '0;
        pa03_cnt[i] <= '0;
        pa04_cnt[i] <= '0;
        pa05_cnt[i] <= '0;
        pa06_cnt[i] <= '0;
        pa07_cnt[i] <= '0;
        pa08_cnt[i] <= '0;
        pa09_cnt[i] <= '0;
        pa10_cnt[i] <= '0;
        pa11_cnt[i] <= '0;
        pa12_cnt[i] <= '0;
        pa13_cnt[i] <= '0;
        pa10_max[i] <= '0;
        pa11_max[i] <= '0;
        pa12_max[i] <= '0;
        pa13_max[i] <= '0;
      end
      for (int i = 0; i < CH_NUM; i++) begin
        pa14_cnt[i] <= '0;
        pa15_cnt[i] <= '0;
        pa16_cnt[i] <= '0;
        pa17_cnt[i] <= '0;
      end
    end
    else begin
      pa_enb_1t <= pa_enb;
      pa_clr_1t <= pa_clr;
      if(pa_clr_1t) begin
        for (int i = 0; i < CHAIN_NUM; i++) begin
          pa00_cnt[i] <= '0;
          pa01_cnt[i] <= '0;
          pa02_cnt[i] <= '0;
          pa03_cnt[i] <= '0;
          pa04_cnt[i] <= '0;
          pa05_cnt[i] <= '0;
          pa06_cnt[i] <= '0;
          pa07_cnt[i] <= '0;
          pa08_cnt[i] <= '0;
          pa09_cnt[i] <= '0;
          pa10_cnt[i] <= '0;
          pa11_cnt[i] <= '0;
          pa12_cnt[i] <= '0;
          pa13_cnt[i] <= '0;
          pa10_max[i] <= '0;
          pa11_max[i] <= '0;
          pa12_max[i] <= '0;
          pa13_max[i] <= '0;
        end
        for (int i = 0; i < CH_NUM; i++) begin
          pa14_cnt[i] <= '0;
          pa15_cnt[i] <= '0;
          pa16_cnt[i] <= '0;
          pa17_cnt[i] <= '0;
        end
      end
      else if(pa_enb_1t) begin
        for (int i = 0; i < CHAIN_NUM; i++) begin
  	  pa00_cnt[i] <= (pa00_cnt[i]==40'hFF_FFFF_FFFF) ? pa00_cnt[i] : pa00_cnt[i] + pa00_inc_enb_1t[i];
  	  pa01_cnt[i] <= (pa01_cnt[i]==40'hFF_FFFF_FFFF) ? pa01_cnt[i] : pa01_cnt[i] + pa01_inc_enb_1t[i];
  	  pa02_cnt[i] <= (pa02_cnt[i]==40'hFF_FFFF_FFFF) ? pa02_cnt[i] : pa02_cnt[i] + pa02_inc_enb_1t[i];
  	  pa03_cnt[i] <= (pa03_cnt[i]==40'hFF_FFFF_FFFF) ? pa03_cnt[i] : pa03_cnt[i] + pa03_inc_enb_1t[i];
  	  pa04_cnt[i] <= (pa04_cnt[i]==40'hFF_FFFF_FFFF) ? pa04_cnt[i] : pa04_cnt[i] + pa04_inc_enb_1t[i];
  	  pa05_cnt[i] <= (pa05_cnt[i]==40'hFF_FFFF_FFFF) ? pa05_cnt[i] : pa05_cnt[i] + pa05_inc_enb_1t[i];
  	  pa06_cnt[i] <= (pa06_cnt[i]==40'hFF_FFFF_FFFF) ? pa06_cnt[i] : pa06_cnt[i] + pa06_inc_enb_1t[i];
  	  pa07_cnt[i] <= (pa07_cnt[i]==40'hFF_FFFF_FFFF) ? pa07_cnt[i] : pa07_cnt[i] + pa07_inc_enb_1t[i];
  	  pa08_cnt[i] <= (pa08_cnt[i]==40'hFF_FFFF_FFFF) ? pa08_cnt[i] : pa08_cnt[i] + pa08_inc_enb_1t[i];
  	  pa09_cnt[i] <= (pa09_cnt[i]==40'hFF_FFFF_FFFF) ? pa09_cnt[i] : pa09_cnt[i] + pa09_inc_enb_1t[i];
  	  pa10_cnt[i] <= pa10_cnt_mod[i][64] ? '1 : pa10_cnt_mod[i][63:0];
  	  pa11_cnt[i] <= pa11_cnt_mod[i][64] ? '1 : pa11_cnt_mod[i][63:0];
  	  pa12_cnt[i] <= pa12_cnt_mod[i][64] ? '1 : pa12_cnt_mod[i][63:0];
  	  pa13_cnt[i] <= pa13_cnt_mod[i][64] ? '1 : pa13_cnt_mod[i][63:0];
  	  pa10_max[i] <= pa10_add_val_1t[i] > pa10_max[i] ? pa10_add_val[i] : pa10_max[i];
  	  pa11_max[i] <= pa11_add_val_1t[i] > pa11_max[i] ? pa11_add_val[i] : pa11_max[i];
  	  pa12_max[i] <= pa12_add_val_1t[i] > pa12_max[i] ? pa12_add_val[i] : pa12_max[i];
  	  pa13_max[i] <= pa13_add_val_1t[i] > pa13_max[i] ? pa13_add_val[i] : pa13_max[i];
        end
        for (int i = 0; i < CH_NUM; i++) begin
  	  pa14_cnt[i] <= (pa14_cnt[i]==40'hFF_FFFF_FFFF) ? pa14_cnt[i] : pa14_cnt[i] + pa14_inc_enb_1t[i];
  	  pa15_cnt[i] <= (pa15_cnt[i]==40'hFF_FFFF_FFFF) ? pa15_cnt[i] : pa15_cnt[i] + pa15_inc_enb_1t[i];
  	  pa16_cnt[i] <= (pa16_cnt[i]==40'hFF_FFFF_FFFF) ? pa16_cnt[i] : pa16_cnt[i] + pa16_inc_enb_1t[i];
  	  pa17_cnt[i] <= (pa17_cnt[i]==40'hFF_FFFF_FFFF) ? pa17_cnt[i] : pa17_cnt[i] + pa17_inc_enb_1t[i];
        end
      end
    end
  end


// Register access IF ///////////////////////////////////////////////////////////////////////

  assign reg_wt_valid = regreq_tvalid && (regreq_tuser[15:9] == reg_base_addr) && ( regreq_tuser[32]);
  assign reg_rd_valid = regreq_tvalid && (regreq_tuser[15:9] == reg_base_addr) && (~regreq_tuser[32]);

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      chain_sel     <= '0;
      regreq_rdt    <= '0;
      pa14_sel      <= 4'h0;
      pa15_sel      <= 4'h1;
      pa16_sel      <= 4'h2;
      pa17_sel      <= 4'h3;
    end
    else if(reg_wt_valid) begin
      case(regreq_tuser[8:0])
        9'h038  : chain_sel    <= regreq_tdata[7:0];
        9'h1A0  : pa14_sel     <= regreq_tdata[3:0];
        9'h1A4  : pa15_sel     <= regreq_tdata[3:0];
        9'h1A8  : pa16_sel     <= regreq_tdata[3:0];
        9'h1AC  : pa17_sel     <= regreq_tdata[3:0];
	default : ;
      endcase
    end
    else if(reg_rd_valid) begin
      case(regreq_tuser[8:0])
	9'h038  : regreq_rdt <= {24'h0, chain_sel};
	9'h080  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa00_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h084  : regreq_rdt <= {24'h0, (chain_sel < CHAIN_NUM) ? pa00_cnt[chain_sel][39:32] :  8'b0};
	9'h088  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa01_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h08C  : regreq_rdt <= {24'h0, (chain_sel < CHAIN_NUM) ? pa01_cnt[chain_sel][39:32] :  8'b0};
	9'h090  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa02_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h094  : regreq_rdt <= {24'h0, (chain_sel < CHAIN_NUM) ? pa02_cnt[chain_sel][39:32] :  8'b0};
	9'h098  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa03_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h09C  : regreq_rdt <= {24'h0, (chain_sel < CHAIN_NUM) ? pa03_cnt[chain_sel][39:32] :  8'b0};
	9'h0A0  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa04_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h0A4  : regreq_rdt <= {24'h0, (chain_sel < CHAIN_NUM) ? pa04_cnt[chain_sel][39:32] :  8'b0};
	9'h0A8  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa05_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h0AC  : regreq_rdt <= {24'h0, (chain_sel < CHAIN_NUM) ? pa05_cnt[chain_sel][39:32] :  8'b0};
	9'h0B0  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa06_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h0B4  : regreq_rdt <= {24'h0, (chain_sel < CHAIN_NUM) ? pa06_cnt[chain_sel][39:32] :  8'b0};
	9'h0B8  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa07_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h0BC  : regreq_rdt <= {24'h0, (chain_sel < CHAIN_NUM) ? pa07_cnt[chain_sel][39:32] :  8'b0};
	9'h0C0  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa08_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h0C4  : regreq_rdt <= {24'h0, (chain_sel < CHAIN_NUM) ? pa08_cnt[chain_sel][39:32] :  8'b0};
	9'h0C8  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa09_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h0CC  : regreq_rdt <= {24'h0, (chain_sel < CHAIN_NUM) ? pa09_cnt[chain_sel][39:32] :  8'b0};
	9'h0D0  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa10_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h0D4  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa10_cnt[chain_sel][63:32] : 32'b0 ;
	9'h0D8  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa11_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h0DC  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa11_cnt[chain_sel][63:32] : 32'b0 ;
	9'h0E0  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa12_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h0E4  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa12_cnt[chain_sel][63:32] : 32'b0 ;
	9'h0E8  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa13_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h0EC  : regreq_rdt <=         (chain_sel < CHAIN_NUM) ? pa13_cnt[chain_sel][63:32] : 32'b0 ;
	9'h0F0  : regreq_rdt <= {16'h0, (chain_sel < CHAIN_NUM) ? pa10_max[chain_sel][15:0]  : 16'b0};
	9'h0F4  : regreq_rdt <= {16'h0, (chain_sel < CHAIN_NUM) ? pa11_max[chain_sel][15:0]  : 16'b0};
	9'h0F8  : regreq_rdt <= {16'h0, (chain_sel < CHAIN_NUM) ? pa12_max[chain_sel][15:0]  : 16'b0};
	9'h0FC  : regreq_rdt <= {16'h0, (chain_sel < CHAIN_NUM) ? pa13_max[chain_sel][15:0]  : 16'b0};
	9'h180  : regreq_rdt <=         (chain_sel < CH_NUM) ? pa14_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h184  : regreq_rdt <= {24'h0, (chain_sel < CH_NUM) ? pa14_cnt[chain_sel][39:32] :  8'b0};
	9'h188  : regreq_rdt <=         (chain_sel < CH_NUM) ? pa15_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h18C  : regreq_rdt <= {24'h0, (chain_sel < CH_NUM) ? pa15_cnt[chain_sel][39:32] :  8'b0};
	9'h190  : regreq_rdt <=         (chain_sel < CH_NUM) ? pa16_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h194  : regreq_rdt <= {24'h0, (chain_sel < CH_NUM) ? pa16_cnt[chain_sel][39:32] :  8'b0};
	9'h198  : regreq_rdt <=         (chain_sel < CH_NUM) ? pa17_cnt[chain_sel][31:0]  : 32'b0 ;
	9'h19C  : regreq_rdt <= {24'h0, (chain_sel < CH_NUM) ? pa17_cnt[chain_sel][39:32] :  8'b0};
        9'h1A0  : regreq_rdt <= {28'h0, pa14_sel};
        9'h1A4  : regreq_rdt <= {28'h0, pa15_sel};
        9'h1A8  : regreq_rdt <= {28'h0, pa16_sel};
        9'h1AC  : regreq_rdt <= {28'h0, pa17_sel};
	default : regreq_rdt <= '0;
      endcase
    end
    else begin
      regreq_rdt = '0;
    end
  end

endmodule
