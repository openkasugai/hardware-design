/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module pa_cnt3_wrapper # (
  parameter CH_NUM         = 16,
  parameter CHAIN_NUM      = CH_NUM/8,
  parameter FF_NUM         = 1
  )
  (
  input  logic   user_clk,
  input  logic   reset_n,

// Register access IF ///////////////////////////////////////////////////////////////////////
  input  logic [15:9]       reg_base_addr,
  input  logic              regreq_tvalid,
  input  logic [31:0]       regreq_tdata,
  input  logic [32:0]       regreq_tuser,
  output logic              regrep_tvalid,
  output logic [31:0]       regrep_tdata,

// PA Counter /////////////////////////////////////////////////////////////////////////////
  input  logic              pa_enb,
  input  logic              pa_clr,

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
  input  logic [15:0]       pa10_add_val[CHAIN_NUM-1:0],
  input  logic [15:0]       pa11_add_val[CHAIN_NUM-1:0],
  input  logic [15:0]       pa12_add_val[CHAIN_NUM-1:0],
  input  logic [15:0]       pa13_add_val[CHAIN_NUM-1:0]

);

  logic [15:9]       reg_base_addr_1t;
  logic              regreq_tvalid_1t;
  logic [31:0]       regreq_tdata_1t;
  logic [32:0]       regreq_tuser_1t;
  logic              pa_enb_1t;
  logic              pa_clr_1t;
  logic [CH_NUM-1:0] pa00_inc_enb_1t;
  logic [CH_NUM-1:0] pa01_inc_enb_1t;
  logic [CH_NUM-1:0] pa02_inc_enb_1t;
  logic [CH_NUM-1:0] pa03_inc_enb_1t;
  logic [CH_NUM-1:0] pa04_inc_enb_1t;
  logic [CH_NUM-1:0] pa05_inc_enb_1t;
  logic [CH_NUM-1:0] pa06_inc_enb_1t;
  logic [CH_NUM-1:0] pa07_inc_enb_1t;
  logic [CH_NUM-1:0] pa08_inc_enb_1t;
  logic [CH_NUM-1:0] pa09_inc_enb_1t;
  logic [15:0]       pa10_add_val_1t[CHAIN_NUM-1:0];
  logic [15:0]       pa11_add_val_1t[CHAIN_NUM-1:0];
  logic [15:0]       pa12_add_val_1t[CHAIN_NUM-1:0];
  logic [15:0]       pa13_add_val_1t[CHAIN_NUM-1:0];

  logic [15:9]       reg_base_addr_nt[FF_NUM:1];
  logic              regreq_tvalid_nt[FF_NUM:1];
  logic [31:0]       regreq_tdata_nt[FF_NUM:1];
  logic [32:0]       regreq_tuser_nt[FF_NUM:1];
  logic              pa_enb_nt[FF_NUM:1];
  logic              pa_clr_nt[FF_NUM:1];
  logic [CH_NUM-1:0] pa00_inc_enb_nt[FF_NUM:1];
  logic [CH_NUM-1:0] pa01_inc_enb_nt[FF_NUM:1];
  logic [CH_NUM-1:0] pa02_inc_enb_nt[FF_NUM:1];
  logic [CH_NUM-1:0] pa03_inc_enb_nt[FF_NUM:1];
  logic [CH_NUM-1:0] pa04_inc_enb_nt[FF_NUM:1];
  logic [CH_NUM-1:0] pa05_inc_enb_nt[FF_NUM:1];
  logic [CH_NUM-1:0] pa06_inc_enb_nt[FF_NUM:1];
  logic [CH_NUM-1:0] pa07_inc_enb_nt[FF_NUM:1];
  logic [CH_NUM-1:0] pa08_inc_enb_nt[FF_NUM:1];
  logic [CH_NUM-1:0] pa09_inc_enb_nt[FF_NUM:1];
  logic [15:0]       pa10_add_val_nt[CHAIN_NUM-1:0][FF_NUM:1];
  logic [15:0]       pa11_add_val_nt[CHAIN_NUM-1:0][FF_NUM:1];
  logic [15:0]       pa12_add_val_nt[CHAIN_NUM-1:0][FF_NUM:1];
  logic [15:0]       pa13_add_val_nt[CHAIN_NUM-1:0][FF_NUM:1];

  logic [15:9]       reg_base_addr_pa_cnt;
  logic              regreq_tvalid_pa_cnt;
  logic [31:0]       regreq_tdata_pa_cnt;
  logic [32:0]       regreq_tuser_pa_cnt;
  logic              pa_enb_pa_cnt;
  logic              pa_clr_pa_cnt;
  logic [CH_NUM-1:0] pa00_inc_enb_pa_cnt;
  logic [CH_NUM-1:0] pa01_inc_enb_pa_cnt;
  logic [CH_NUM-1:0] pa02_inc_enb_pa_cnt;
  logic [CH_NUM-1:0] pa03_inc_enb_pa_cnt;
  logic [CH_NUM-1:0] pa04_inc_enb_pa_cnt;
  logic [CH_NUM-1:0] pa05_inc_enb_pa_cnt;
  logic [CH_NUM-1:0] pa06_inc_enb_pa_cnt;
  logic [CH_NUM-1:0] pa07_inc_enb_pa_cnt;
  logic [CH_NUM-1:0] pa08_inc_enb_pa_cnt;
  logic [CH_NUM-1:0] pa09_inc_enb_pa_cnt;
  logic [15:0]       pa10_add_val_pa_cnt[CHAIN_NUM-1:0];
  logic [15:0]       pa11_add_val_pa_cnt[CHAIN_NUM-1:0];
  logic [15:0]       pa12_add_val_pa_cnt[CHAIN_NUM-1:0];
  logic [15:0]       pa13_add_val_pa_cnt[CHAIN_NUM-1:0];

  logic              regrep_tvalid_pa_cnt;
  logic [31:0]       regrep_tdata_pa_cnt;

  logic              regrep_tvalid_1t;
  logic [31:0]       regrep_tdata_1t;

  logic              regrep_tvalid_nt[FF_NUM:1];
  logic [31:0]       regrep_tdata_nt[FF_NUM:1];

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      if (FF_NUM == 1) begin
        reg_base_addr_1t               <= '0;
        regreq_tvalid_1t               <= '0;
        regreq_tdata_1t                <= '0;
        regreq_tuser_1t                <= '0;
        pa_enb_1t                      <= '0;
        pa_clr_1t                      <= '0;
        pa00_inc_enb_1t                <= '0;
        pa01_inc_enb_1t                <= '0;
        pa02_inc_enb_1t                <= '0;
        pa03_inc_enb_1t                <= '0;
        pa04_inc_enb_1t                <= '0;
        pa05_inc_enb_1t                <= '0;
        pa06_inc_enb_1t                <= '0;
        pa07_inc_enb_1t                <= '0;
        pa08_inc_enb_1t                <= '0;
        pa09_inc_enb_1t                <= '0;
        for (int i = 0; i < CHAIN_NUM; i++) begin
          pa10_add_val_1t[i]           <= '0;
          pa11_add_val_1t[i]           <= '0;
          pa12_add_val_1t[i]           <= '0;
          pa13_add_val_1t[i]           <= '0;
        end
        regrep_tvalid_1t               <= '0;
        regrep_tdata_1t                <= '0;
      end else if (FF_NUM > 1) begin
        for (int j = 1; j <= FF_NUM; j++) begin
          reg_base_addr_nt[j]          <= '0;
          regreq_tvalid_nt[j]          <= '0;
          regreq_tdata_nt[j]           <= '0;
          regreq_tuser_nt[j]           <= '0;
          pa_enb_nt[j]                 <= '0;
          pa_clr_nt[j]                 <= '0;
          pa00_inc_enb_nt[j]           <= '0;
          pa01_inc_enb_nt[j]           <= '0;
          pa02_inc_enb_nt[j]           <= '0;
          pa03_inc_enb_nt[j]           <= '0;
          pa04_inc_enb_nt[j]           <= '0;
          pa05_inc_enb_nt[j]           <= '0;
          pa06_inc_enb_nt[j]           <= '0;
          pa07_inc_enb_nt[j]           <= '0;
          pa08_inc_enb_nt[j]           <= '0;
          pa09_inc_enb_nt[j]           <= '0;
          for (int i = 0; i < CHAIN_NUM; i++) begin
            pa10_add_val_nt[i][j]      <= '0;
            pa11_add_val_nt[i][j]      <= '0;
            pa12_add_val_nt[i][j]      <= '0;
            pa13_add_val_nt[i][j]      <= '0;
          end
          regrep_tvalid_nt[j]          <= '0;
          regrep_tdata_nt[j]           <= '0;
        end
      end
      regrep_tvalid_pa_cnt             <= '0;
    end else begin
      if (FF_NUM == 1) begin
        reg_base_addr_1t               <= reg_base_addr;
        regreq_tvalid_1t               <= regreq_tvalid;
        regreq_tdata_1t                <= regreq_tdata;
        regreq_tuser_1t                <= regreq_tuser;
        pa_enb_1t                      <= pa_enb;
        pa_clr_1t                      <= pa_clr;
        pa00_inc_enb_1t                <= pa00_inc_enb;
        pa01_inc_enb_1t                <= pa01_inc_enb;
        pa02_inc_enb_1t                <= pa02_inc_enb;
        pa03_inc_enb_1t                <= pa03_inc_enb;
        pa04_inc_enb_1t                <= pa04_inc_enb;
        pa05_inc_enb_1t                <= pa05_inc_enb;
        pa06_inc_enb_1t                <= pa06_inc_enb;
        pa07_inc_enb_1t                <= pa07_inc_enb;
        pa08_inc_enb_1t                <= pa08_inc_enb;
        pa09_inc_enb_1t                <= pa09_inc_enb;
        for (int i = 0; i < CHAIN_NUM; i++) begin
          pa10_add_val_1t[i]           <= pa10_add_val[i];
          pa11_add_val_1t[i]           <= pa11_add_val[i];
          pa12_add_val_1t[i]           <= pa12_add_val[i];
          pa13_add_val_1t[i]           <= pa13_add_val[i];
        end
        regrep_tvalid_pa_cnt           <= (regreq_tvalid_1t & ~regreq_tuser_1t[32]);
        regrep_tvalid_1t               <= regrep_tvalid_pa_cnt;
        regrep_tdata_1t                <= regrep_tdata_pa_cnt;
      end else if (FF_NUM > 1) begin
        reg_base_addr_nt[1]            <= reg_base_addr;
        regreq_tvalid_nt[1]            <= regreq_tvalid;
        regreq_tdata_nt[1]             <= regreq_tdata;
        regreq_tuser_nt[1]             <= regreq_tuser;
        pa_enb_nt[1]                   <= pa_enb;
        pa_clr_nt[1]                   <= pa_clr;
        pa00_inc_enb_nt[1]             <= pa00_inc_enb;
        pa01_inc_enb_nt[1]             <= pa01_inc_enb;
        pa02_inc_enb_nt[1]             <= pa02_inc_enb;
        pa03_inc_enb_nt[1]             <= pa03_inc_enb;
        pa04_inc_enb_nt[1]             <= pa04_inc_enb;
        pa05_inc_enb_nt[1]             <= pa05_inc_enb;
        pa06_inc_enb_nt[1]             <= pa06_inc_enb;
        pa07_inc_enb_nt[1]             <= pa07_inc_enb;
        pa08_inc_enb_nt[1]             <= pa08_inc_enb;
        pa09_inc_enb_nt[1]             <= pa09_inc_enb;
        for (int i = 0; i < CHAIN_NUM; i++) begin
          pa10_add_val_nt[i][1]        <= pa10_add_val[i];
          pa11_add_val_nt[i][1]        <= pa11_add_val[i];
          pa12_add_val_nt[i][1]        <= pa12_add_val[i];
          pa13_add_val_nt[i][1]        <= pa13_add_val[i];
        end
        reg_base_addr_nt[FF_NUM:2]     <= reg_base_addr_nt[FF_NUM-1:1];
        regreq_tvalid_nt[FF_NUM:2]     <= regreq_tvalid_nt[FF_NUM-1:1];
        regreq_tdata_nt[FF_NUM:2]      <= regreq_tdata_nt[FF_NUM-1:1];
        regreq_tuser_nt[FF_NUM:2]      <= regreq_tuser_nt[FF_NUM-1:1];
        pa_enb_nt[FF_NUM:2]            <= pa_enb_nt[FF_NUM-1:1];
        pa_clr_nt[FF_NUM:2]            <= pa_clr_nt[FF_NUM-1:1];
        pa00_inc_enb_nt[FF_NUM:2]      <= pa00_inc_enb_nt[FF_NUM-1:1];
        pa01_inc_enb_nt[FF_NUM:2]      <= pa01_inc_enb_nt[FF_NUM-1:1];
        pa02_inc_enb_nt[FF_NUM:2]      <= pa02_inc_enb_nt[FF_NUM-1:1];
        pa03_inc_enb_nt[FF_NUM:2]      <= pa03_inc_enb_nt[FF_NUM-1:1];
        pa04_inc_enb_nt[FF_NUM:2]      <= pa04_inc_enb_nt[FF_NUM-1:1];
        pa05_inc_enb_nt[FF_NUM:2]      <= pa05_inc_enb_nt[FF_NUM-1:1];
        pa06_inc_enb_nt[FF_NUM:2]      <= pa06_inc_enb_nt[FF_NUM-1:1];
        pa07_inc_enb_nt[FF_NUM:2]      <= pa07_inc_enb_nt[FF_NUM-1:1];
        pa08_inc_enb_nt[FF_NUM:2]      <= pa08_inc_enb_nt[FF_NUM-1:1];
        pa09_inc_enb_nt[FF_NUM:2]      <= pa09_inc_enb_nt[FF_NUM-1:1];
        for (int i = 0; i < CHAIN_NUM; i++) begin
          pa10_add_val_nt[i][FF_NUM:2] <= pa10_add_val_nt[i][FF_NUM-1:1];
          pa11_add_val_nt[i][FF_NUM:2] <= pa11_add_val_nt[i][FF_NUM-1:1];
          pa12_add_val_nt[i][FF_NUM:2] <= pa12_add_val_nt[i][FF_NUM-1:1];
          pa13_add_val_nt[i][FF_NUM:2] <= pa13_add_val_nt[i][FF_NUM-1:1];
        end
        regrep_tvalid_pa_cnt           <= (regreq_tvalid_nt[FF_NUM] & ~regreq_tuser_nt[FF_NUM][32]);
        regrep_tvalid_nt[1]            <= regrep_tvalid_pa_cnt;
        regrep_tdata_nt[1]             <= regrep_tdata_pa_cnt;
        regrep_tvalid_nt[FF_NUM:2]     <= regrep_tvalid_nt[FF_NUM-1:1];
        regrep_tdata_nt[FF_NUM:2]      <= regrep_tdata_nt[FF_NUM-1:1];
      end
    end
  end

  always_comb begin
    if (FF_NUM == 1) begin
      reg_base_addr_pa_cnt = reg_base_addr_1t;
      regreq_tvalid_pa_cnt = regreq_tvalid_1t;
      regreq_tdata_pa_cnt  = regreq_tdata_1t; 
      regreq_tuser_pa_cnt  = regreq_tuser_1t; 
      pa_enb_pa_cnt        = pa_enb_1t;       
      pa_clr_pa_cnt        = pa_clr_1t;
      pa00_inc_enb_pa_cnt  = pa00_inc_enb_1t; 
      pa01_inc_enb_pa_cnt  = pa01_inc_enb_1t; 
      pa02_inc_enb_pa_cnt  = pa02_inc_enb_1t; 
      pa03_inc_enb_pa_cnt  = pa03_inc_enb_1t; 
      pa04_inc_enb_pa_cnt  = pa04_inc_enb_1t; 
      pa05_inc_enb_pa_cnt  = pa05_inc_enb_1t; 
      pa06_inc_enb_pa_cnt  = pa06_inc_enb_1t; 
      pa07_inc_enb_pa_cnt  = pa07_inc_enb_1t; 
      pa08_inc_enb_pa_cnt  = pa08_inc_enb_1t; 
      pa09_inc_enb_pa_cnt  = pa09_inc_enb_1t;
      for (int i = 0; i < CHAIN_NUM; i++) begin
        pa10_add_val_pa_cnt[i]  = pa10_add_val_1t[i];
        pa11_add_val_pa_cnt[i]  = pa11_add_val_1t[i];
        pa12_add_val_pa_cnt[i]  = pa12_add_val_1t[i];
        pa13_add_val_pa_cnt[i]  = pa13_add_val_1t[i];
      end
      regrep_tvalid        = regrep_tvalid_1t;
      regrep_tdata         = regrep_tdata_1t; 
    end else if (FF_NUM > 1) begin
      reg_base_addr_pa_cnt = reg_base_addr_nt[FF_NUM];
      regreq_tvalid_pa_cnt = regreq_tvalid_nt[FF_NUM];
      regreq_tdata_pa_cnt  = regreq_tdata_nt[FF_NUM]; 
      regreq_tuser_pa_cnt  = regreq_tuser_nt[FF_NUM]; 
      pa_enb_pa_cnt        = pa_enb_nt[FF_NUM];       
      pa_clr_pa_cnt        = pa_clr_nt[FF_NUM];
      pa00_inc_enb_pa_cnt  = pa00_inc_enb_nt[FF_NUM]; 
      pa01_inc_enb_pa_cnt  = pa01_inc_enb_nt[FF_NUM]; 
      pa02_inc_enb_pa_cnt  = pa02_inc_enb_nt[FF_NUM]; 
      pa03_inc_enb_pa_cnt  = pa03_inc_enb_nt[FF_NUM]; 
      pa04_inc_enb_pa_cnt  = pa04_inc_enb_nt[FF_NUM]; 
      pa05_inc_enb_pa_cnt  = pa05_inc_enb_nt[FF_NUM]; 
      pa06_inc_enb_pa_cnt  = pa06_inc_enb_nt[FF_NUM]; 
      pa07_inc_enb_pa_cnt  = pa07_inc_enb_nt[FF_NUM]; 
      pa08_inc_enb_pa_cnt  = pa08_inc_enb_nt[FF_NUM]; 
      pa09_inc_enb_pa_cnt  = pa09_inc_enb_nt[FF_NUM];
      for (int i = 0; i < CHAIN_NUM; i++) begin
        pa10_add_val_pa_cnt[i]  = pa10_add_val_nt[i][FF_NUM];
        pa11_add_val_pa_cnt[i]  = pa11_add_val_nt[i][FF_NUM];
        pa12_add_val_pa_cnt[i]  = pa12_add_val_nt[i][FF_NUM];
        pa13_add_val_pa_cnt[i]  = pa13_add_val_nt[i][FF_NUM];
      end
      regrep_tvalid        = regrep_tvalid_nt[FF_NUM];
      regrep_tdata         = regrep_tdata_nt[FF_NUM]; 
    end
  end

  pa_cnt3 #(.CH_NUM(CH_NUM)) PA_CNT (
   .user_clk(user_clk),
   .reset_n(reset_n),
   .reg_base_addr(reg_base_addr_pa_cnt),
   .regreq_tvalid(regreq_tvalid_pa_cnt),
   .regreq_tdata(regreq_tdata_pa_cnt),
   .regreq_tuser(regreq_tuser_pa_cnt),
   .pa_enb(pa_enb_pa_cnt),
   .pa_clr(pa_clr_pa_cnt),
   .pa00_inc_enb(pa00_inc_enb_pa_cnt),
   .pa01_inc_enb(pa01_inc_enb_pa_cnt),
   .pa02_inc_enb(pa02_inc_enb_pa_cnt),
   .pa03_inc_enb(pa03_inc_enb_pa_cnt),
   .pa04_inc_enb(pa04_inc_enb_pa_cnt),
   .pa05_inc_enb(pa05_inc_enb_pa_cnt),
   .pa06_inc_enb(pa06_inc_enb_pa_cnt),
   .pa07_inc_enb(pa07_inc_enb_pa_cnt),
   .pa08_inc_enb(pa08_inc_enb_pa_cnt),
   .pa09_inc_enb(pa09_inc_enb_pa_cnt),
   .pa10_add_val(pa10_add_val_pa_cnt),
   .pa11_add_val(pa11_add_val_pa_cnt),
   .pa12_add_val(pa12_add_val_pa_cnt),
   .pa13_add_val(pa13_add_val_pa_cnt),
   .regreq_rdt(regrep_tdata_pa_cnt)
  );

endmodule
