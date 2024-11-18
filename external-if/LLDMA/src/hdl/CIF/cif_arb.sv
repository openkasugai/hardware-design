/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module cif_arb #(
  parameter CH_NUM = 8
)(
  input  logic              reset_n,
  input  logic              user_clk,

//  input  logic [CH_NUM-1:0] req,
//  output logic [CH_NUM-1:0] gnt,
  input  logic [CH_NUM-1:0] req,
  output logic [CH_NUM-1:0] gnt,
  output logic              gnt_anych,
  input  logic              arbenb
);

localparam CH_NUM_W = $clog2(CH_NUM);

// prio_max_ch: Highest priority channel
// Priority is prio_max_ch> prio_max_ch+1>prio_max_ch+2>...
reg                  arbenb_t1_ff;
reg   [CH_NUM_W-1:0] prio_max_ch_ff;
reg   [CH_NUM-1:0]   gnt_ch_ff;
logic [CH_NUM-1:0]   enb_prio_ch[CH_NUM-1:0];
logic [CH_NUM-1:0]   enb_req_ch;

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    arbenb_t1_ff <= 1'b0;
  end else begin
    arbenb_t1_ff <= arbenb;
  end
end

//// priority
always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    prio_max_ch_ff <= 'b0;
  end else if(arbenb_t1_ff) begin
    for(int i=0; i<CH_NUM; i++) begin
      if(gnt_ch_ff[i]==1) begin
        prio_max_ch_ff <= (i+1) % CH_NUM;
      end
    end
  end
end

//// ch arbitraion
always_comb begin
  for(int i=0; i<CH_NUM; i++) begin
    for(int j=0; j<CH_NUM; j++) begin
      enb_prio_ch[i][j] = 1;
      if(i==j) begin
      // nop
      end else if(i>j) begin
        for(int k=j; k<i; k++) begin
          enb_prio_ch[i][j] = enb_prio_ch[i][j] & ~req[k];
        end
      end else begin
        for(int k=j; k<i+CH_NUM; k++) begin
          enb_prio_ch[i][j] = enb_prio_ch[i][j] & ~req[k%CH_NUM];
        end
      end
    end
  end

  for(int i=0; i<CH_NUM; i++) begin
    enb_req_ch[i] = enb_prio_ch[i][prio_max_ch_ff];
  end
end

always_ff @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    gnt_ch_ff <= 'b0;
  end else begin
    if(arbenb & ~gnt_anych) begin
      for(int i=0; i<CH_NUM; i++) begin
        gnt_ch_ff[i] <= req[i]& enb_req_ch[i];
      end
    end else begin
      gnt_ch_ff <= 'b0;
    end
  end
end

assign gnt_anych = |gnt_ch_ff;
assign gnt = gnt_ch_ff;

endmodule
