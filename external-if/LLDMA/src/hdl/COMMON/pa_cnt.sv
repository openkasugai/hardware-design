/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module pa_cnt # (
  parameter CH_NUM      = 16
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
  input  logic [15:0]	pa10_add_val[CH_NUM-1:0],
  input  logic [15:0]	pa11_add_val[CH_NUM-1:0],
  input  logic [15:0]	pa12_add_val[CH_NUM-1:0],
  input  logic [15:0]	pa13_add_val[CH_NUM-1:0]

);

// PA Counter /////////////////////////////////////////////////////////////////////////////
  logic	 	pa_enb_1t;
  logic	 	pa_clr_1t;

  logic [CH_NUM-1:0] 	pa00_inc_enb_1t;
  logic [CH_NUM-1:0] 	pa01_inc_enb_1t;
  logic [CH_NUM-1:0] 	pa02_inc_enb_1t;
  logic [CH_NUM-1:0] 	pa03_inc_enb_1t;
  logic [CH_NUM-1:0] 	pa04_inc_enb_1t;
  logic [CH_NUM-1:0] 	pa05_inc_enb_1t;
  logic [CH_NUM-1:0] 	pa06_inc_enb_1t;
  logic [CH_NUM-1:0] 	pa07_inc_enb_1t;
  logic [CH_NUM-1:0] 	pa08_inc_enb_1t;
  logic [CH_NUM-1:0] 	pa09_inc_enb_1t;
  logic	[39:0]	pa00_cnt[CH_NUM-1:0];
  logic	[39:0]	pa01_cnt[CH_NUM-1:0];
  logic	[39:0]	pa02_cnt[CH_NUM-1:0];
  logic	[39:0]	pa03_cnt[CH_NUM-1:0];
  logic	[39:0]	pa04_cnt[CH_NUM-1:0];
  logic	[39:0]	pa05_cnt[CH_NUM-1:0];
  logic	[39:0]	pa06_cnt[CH_NUM-1:0];
  logic	[39:0]	pa07_cnt[CH_NUM-1:0];
  logic	[39:0]	pa08_cnt[CH_NUM-1:0];
  logic	[39:0]	pa09_cnt[CH_NUM-1:0];

  logic	[63:0]	pa10_cnt[CH_NUM-1:0];
  logic	[63:0]	pa11_cnt[CH_NUM-1:0];
  logic	[63:0]	pa12_cnt[CH_NUM-1:0];
  logic	[63:0]	pa13_cnt[CH_NUM-1:0];
  logic	[64:0]	pa10_cnt_mod[CH_NUM-1:0];
  logic	[64:0]	pa11_cnt_mod[CH_NUM-1:0];
  logic	[64:0]	pa12_cnt_mod[CH_NUM-1:0];
  logic	[64:0]	pa13_cnt_mod[CH_NUM-1:0];
  logic	[15:0]	pa10_max[CH_NUM-1:0];
  logic	[15:0]	pa11_max[CH_NUM-1:0];
  logic	[15:0]	pa12_max[CH_NUM-1:0];
  logic	[15:0]	pa13_max[CH_NUM-1:0];

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
    end
    else begin
      pa00_inc_enb_1t    <= pa00_inc_enb;
      pa01_inc_enb_1t    <= pa01_inc_enb;
      pa02_inc_enb_1t    <= pa02_inc_enb;
      pa03_inc_enb_1t    <= pa03_inc_enb;
      pa04_inc_enb_1t    <= pa04_inc_enb;
      pa05_inc_enb_1t    <= pa05_inc_enb;
      pa06_inc_enb_1t    <= pa06_inc_enb;
      pa07_inc_enb_1t    <= pa07_inc_enb;
      pa08_inc_enb_1t    <= pa08_inc_enb;
      pa09_inc_enb_1t    <= pa09_inc_enb;
    end
  end

  always_comb begin
    for (int i = 0; i < CH_NUM; i++) begin
      pa10_cnt_mod[i] = pa10_cnt[i] + pa10_add_val[i];
      pa11_cnt_mod[i] = pa11_cnt[i] + pa11_add_val[i];
      pa12_cnt_mod[i] = pa12_cnt[i] + pa12_add_val[i];
      pa13_cnt_mod[i] = pa13_cnt[i] + pa13_add_val[i];
    end
  end

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      pa_enb_1t <= '0;
      pa_clr_1t <= '0;
      for (int i = 0; i < CH_NUM; i++) begin
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
    end
    else begin
      pa_enb_1t <= pa_enb;
      pa_clr_1t <= pa_clr;
      if(pa_clr_1t) begin
        for (int i = 0; i < CH_NUM; i++) begin
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
      end
      else if(pa_enb_1t) begin
        for (int i = 0; i < CH_NUM; i++) begin
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
  	  pa10_max[i] <= pa10_add_val[i] > pa10_max[i] ? pa10_add_val[i] : pa10_max[i];
  	  pa11_max[i] <= pa11_add_val[i] > pa11_max[i] ? pa11_add_val[i] : pa11_max[i];
  	  pa12_max[i] <= pa12_add_val[i] > pa12_max[i] ? pa12_add_val[i] : pa12_max[i];
  	  pa13_max[i] <= pa13_add_val[i] > pa13_max[i] ? pa13_add_val[i] : pa13_max[i];
        end
      end
    end
  end


// Register access IF ///////////////////////////////////////////////////////////////////////
  logic	[7:0]	ch_sel;
  logic		reg_wt_valid;
  logic		reg_rd_valid;

  assign reg_wt_valid = regreq_tvalid && (regreq_tuser[15:0] == {reg_base_addr,9'b0_0011_1000}) && ( regreq_tuser[32]);
  assign reg_rd_valid = regreq_tvalid && (regreq_tuser[15:8] == {reg_base_addr,1'b0}) && (~regreq_tuser[32]);

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      ch_sel     <= '0;
      regreq_rdt <= '0;
    end
    else if(reg_wt_valid) begin
      ch_sel     <= regreq_tdata[7:0];
    end
    else if(reg_rd_valid) begin
      case(regreq_tuser[7:0])
	8'h38   : regreq_rdt <= {24'h0, ch_sel};
	8'h80   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa00_cnt[ch_sel][31:0]  : 32'b0 ;
	8'h84   : regreq_rdt <= {24'h0, (ch_sel < CH_NUM) ? pa00_cnt[ch_sel][39:32] :  8'b0};
	8'h88   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa01_cnt[ch_sel][31:0]  : 32'b0 ;
	8'h8C   : regreq_rdt <= {24'h0, (ch_sel < CH_NUM) ? pa01_cnt[ch_sel][39:32] :  8'b0};
	8'h90   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa02_cnt[ch_sel][31:0]  : 32'b0 ;
	8'h94   : regreq_rdt <= {24'h0, (ch_sel < CH_NUM) ? pa02_cnt[ch_sel][39:32] :  8'b0};
	8'h98   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa03_cnt[ch_sel][31:0]  : 32'b0 ;
	8'h9C   : regreq_rdt <= {24'h0, (ch_sel < CH_NUM) ? pa03_cnt[ch_sel][39:32] :  8'b0};
	8'hA0   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa04_cnt[ch_sel][31:0]  : 32'b0 ;
	8'hA4   : regreq_rdt <= {24'h0, (ch_sel < CH_NUM) ? pa04_cnt[ch_sel][39:32] :  8'b0};
	8'hA8   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa05_cnt[ch_sel][31:0]  : 32'b0 ;
	8'hAC   : regreq_rdt <= {24'h0, (ch_sel < CH_NUM) ? pa05_cnt[ch_sel][39:32] :  8'b0};
	8'hB0   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa06_cnt[ch_sel][31:0]  : 32'b0 ;
	8'hB4   : regreq_rdt <= {24'h0, (ch_sel < CH_NUM) ? pa06_cnt[ch_sel][39:32] :  8'b0};
	8'hB8   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa07_cnt[ch_sel][31:0]  : 32'b0 ;
	8'hBC   : regreq_rdt <= {24'h0, (ch_sel < CH_NUM) ? pa07_cnt[ch_sel][39:32] :  8'b0};
	8'hC0   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa08_cnt[ch_sel][31:0]  : 32'b0 ;
	8'hC4   : regreq_rdt <= {24'h0, (ch_sel < CH_NUM) ? pa08_cnt[ch_sel][39:32] :  8'b0};
	8'hC8   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa09_cnt[ch_sel][31:0]  : 32'b0 ;
	8'hCC   : regreq_rdt <= {24'h0, (ch_sel < CH_NUM) ? pa09_cnt[ch_sel][39:32] :  8'b0};
	8'hD0   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa10_cnt[ch_sel][31:0]  : 32'b0 ;
	8'hD4   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa10_cnt[ch_sel][63:32] : 32'b0 ;
	8'hD8   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa11_cnt[ch_sel][31:0]  : 32'b0 ;
	8'hDC   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa11_cnt[ch_sel][63:32] : 32'b0 ;
	8'hE0   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa12_cnt[ch_sel][31:0]  : 32'b0 ;
	8'hE4   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa12_cnt[ch_sel][63:32] : 32'b0 ;
	8'hE8   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa13_cnt[ch_sel][31:0]  : 32'b0 ;
	8'hEC   : regreq_rdt <=         (ch_sel < CH_NUM) ? pa13_cnt[ch_sel][63:32] : 32'b0 ;
	8'hF0   : regreq_rdt <= {16'h0, (ch_sel < CH_NUM) ? pa10_max[ch_sel][15:0]  : 16'b0};
	8'hF4   : regreq_rdt <= {16'h0, (ch_sel < CH_NUM) ? pa11_max[ch_sel][15:0]  : 16'b0};
	8'hF8   : regreq_rdt <= {16'h0, (ch_sel < CH_NUM) ? pa12_max[ch_sel][15:0]  : 16'b0};
	8'hFC   : regreq_rdt <= {16'h0, (ch_sel < CH_NUM) ? pa13_max[ch_sel][15:0]  : 16'b0};
	default : regreq_rdt <= '0;
      endcase
    end
    else begin
      regreq_rdt = '0;
    end
  end

endmodule
