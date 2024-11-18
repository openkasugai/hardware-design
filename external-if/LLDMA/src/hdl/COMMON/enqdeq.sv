/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module enqdeq # (
  parameter RX          = 0,
  parameter CHAIN_NUM   = 2,
  parameter CH_NUM      = 16
  )
  (
  input  logic	 user_clk,
  input  logic	 reset_n,

// Register access IF ///////////////////////////////////////////////////////////////////////
  input  logic	 	regreq_tvalid,
  input  logic [31:0]	regreq_tdata,
  input  logic [32:0]	regreq_tuser,
  output logic [31:0]	regreq_rdt,
  output logic [2:0]	ch_mode [CH_NUM-1:0],

  output logic [CH_NUM-1:0]	ch_ie,
  output logic [CH_NUM-1:0]	ch_oe,
  output logic [CH_NUM-1:0]	ch_clr,
  output logic [CH_NUM-1:0]	ch_dscq_clr,
  input  logic [CH_NUM-1:0]	ch_busy,

// Queue Read IF ///////////////////////////////////////////////////////////////////////////
  input  logic [CH_NUM-1:0] que_rd_req,
  output logic [CH_NUM-1:0] que_rd_dv,
  output logic [127:0]      que_rd_dt,

  output logic	 	rq_crd_tvalid,
  output logic	 	rq_crd_tlast,
  output logic [511:0] 	rq_crd_tdata,
  input  logic	 	rq_crd_tready,

  input  logic	 	rc_tvalid,
  input  logic [511:0] 	rc_tdata,
  input  logic [15:0]	rc_tuser,

// Queue Write IF ///////////////////////////////////////////////////////////////////////////
  input  logic [CH_NUM-1:0] que_wt_req,
  input  logic [127:0]      que_wt_dt   [CH_NUM-1:0],
  output logic [CH_NUM-1:0] que_wt_ack,

  output logic	 	rq_cwr_tvalid,
  output logic	 	rq_cwr_tlast,
  output logic [511:0] 	rq_cwr_tdata,
  input  logic	 	rq_cwr_tready,

// D2D //////////////////////////////////////////////////////////////////////////////////////
  input  logic [31:0]   srbuf_wp      [CH_NUM-1:0],
  input  logic [31:0]   srbuf_rp      [CH_NUM-1:0],
  output logic [63:0]   srbuf_addr    [CH_NUM-1:0],
  output logic [31:0]   srbuf_size    [CH_NUM-1:0],
  output logic [63:0]   que_base_addr [CH_NUM-1:0],

// PA Counter /////////////////////////////////////////////////////////////////////////////
  output logic [CH_NUM-1:0]  	pa_item_fetch_enqdeq,
  output logic [CH_NUM-1:0] 	pa_item_receive_dsc,
  output logic [CH_NUM-1:0] 	pa_item_store_enqdeq,
  output logic [CH_NUM-1:0] 	pa_item_rcv_send_d2d,
  output logic [CH_NUM-1:0] 	pa_item_send_rcv_ack,
  output logic [15:0]    	pa_item_dscq_used_cnt[CH_NUM-1:0]
);

  parameter CH_PAR_CHAIN = CH_NUM / CHAIN_NUM;

// Register access IF ///////////////////////////////////////////////////////////////////////
  logic		reg_acc_valid;
  logic		reg_rd_valid;
  logic		reg_wt_valid;
  logic [31:12] regreq_tdata_for_size;

  logic [CH_NUM-1:0] ch_avail;
  logic [CH_NUM-1:0] ch_active;
  logic [CH_NUM-1:0] ch_busy_all;
  logic [CH_NUM-1:0] ch_ie_off;
  logic [CH_NUM-1:0] ch_clr_on;
  logic [CH_NUM-1:0] ch_enb;
  logic [CH_NUM-1:0] ch_busy_force1_1t;
  logic [CH_NUM-1:0] ch_busy_force1_2t;
  logic [CH_NUM-1:0] ch_busy_force1_3t;
  logic [CH_NUM-1:0] ch_busy_force1_4t;
  logic [CH_NUM-1:0] ch_busy_force1_5t;
  logic [7:0]	ch_sel;
  logic [15:0]	ch_cid 		[CH_NUM-1:0];
  logic [7:0]	ch_chain_id 	[CH_NUM-1:0];
  logic [7:0]	que_entry	[CH_NUM-1:0];
  logic [7:0]	que_dsc_size	[CH_NUM-1:0];
  logic [63:6]	que_addr	[CH_NUM-1:0];
  logic         clr_mode;

// Queue Read IF ///////////////////////////////////////////////////////////////////////////
  logic [CH_NUM-1:0] ch_mode_eq0;
  logic [CH_NUM-1:0] ch_mode_eq1;
  logic [CH_NUM-1:0] ch_mode_eq2;
  logic [CH_NUM-1:0] rd_req;
  logic [CH_NUM  :0] rd_sel;
  logic [CH_NUM  :0] rd_sel_1t;
  logic [CH_NUM  :0] rd_sel_2t;
  logic              rd_req_or;
  logic              rd_req_or_1t;
  logic              rd_req_or_2t;
  logic [CH_NUM-1:0] rd_busy;
  logic [15:0]       rd_wait_cnt [CH_NUM-1:0];
  logic [7:0]        que_rp      [CH_NUM-1:0];
  logic [63:6]       rd_addr_2t;
  logic [7:0]        rd_rp_2t;
  logic [4:0]        rd_ch_2t;
  logic              rc_tvalid_1t;
  logic [127:0]      rc_tdata_1t;
  logic [15:0]       rc_tuser_1t;
  logic              rc_rcv;
  logic              cmd_eq_1;
  logic [CH_NUM-1:0] que_rd_rc_rcv;

  logic [15:0]	     polling_interval1;
  logic [15:0]       polling_interval2;

// Queue Write IF ///////////////////////////////////////////////////////////////////////////
  logic [CH_NUM-1:0] wt_req;
  logic [CH_NUM-1:0] wt_sel;
  logic [CH_NUM-1:0] wt_sel_1t;
  logic [CH_NUM-1:0] wt_sel_2t;
  logic              wt_req_or;
  logic              wt_req_or_1t;
  logic              wt_req_or_2t;
  logic              wt_req_or_3t;
  logic [CH_NUM-1:0] wt_busy;
  logic [7:0]        que_wp      [CH_NUM-1:0];
  logic [63:6]       wt_addr_2t;
  logic [10:0]       wt_wp_2t;
  logic [127:0]      wt_wd_2t;

// Debug lead IF /////////////////////////////////////////////////////////////////////////
  logic		     dbg_acc_valid;
  logic		     dbg_rd_valid;
  logic		     dbg_wt_valid;
  logic		     dbg_enb;
  logic		     dbg_rd_req;
  logic		     dbg_rc_rcv; 
  logic [63:6]	     dbg_addr;
  logic		     dbg_rd_busy;
  logic [511:0]	     dbg_rd_data;

// PA Counter /////////////////////////////////////////////////////////////////////////////
  logic [CH_NUM-1:0] rcv_cid_vec;
  logic		     fetch_enqdeq;
  logic	[CH_NUM-1:0] rcv_d2d;
  logic	[CH_NUM-1:0] rcv_ack;
  logic [CH_NUM-1:0] send_d2d;
  logic [CH_NUM-1:0] send_ack;
  logic [4:0]        pa_item_dscq_used_cnt_tmp[CH_NUM-1:0];

// Register access IF ///////////////////////////////////////////////////////////////////////
  assign reg_acc_valid = regreq_tvalid && (regreq_tuser[15:8] == (RX ? 8'h02 : 8'h04));
  assign reg_rd_valid  = reg_acc_valid && (~regreq_tuser[32]);
  assign reg_wt_valid  = reg_acc_valid && ( regreq_tuser[32]);

  always_comb begin
    ch_avail = '0;
    for (int i = 0; i < CHAIN_NUM; i++) begin
      for (int j = 0; j < CH_PAR_CHAIN; j++) begin
        ch_avail    [CH_PAR_CHAIN*i+j] = 1'b1;
        ch_cid      [CH_PAR_CHAIN*i+j] = (CH_PAR_CHAIN*i+j);
        ch_chain_id [CH_PAR_CHAIN*i+j] = i;
	que_dsc_size[CH_PAR_CHAIN*i+j] = 8'h40;
      end
    end
  end

  assign regreq_tdata_for_size[31] = regreq_tdata[31];
  assign regreq_tdata_for_size[30] = regreq_tdata[31:30]==1;
  assign regreq_tdata_for_size[29] = regreq_tdata[31:29]==1;
  assign regreq_tdata_for_size[28] = regreq_tdata[31:28]==1;
  assign regreq_tdata_for_size[27] = regreq_tdata[31:27]==1;
  assign regreq_tdata_for_size[26] = regreq_tdata[31:26]==1;
  assign regreq_tdata_for_size[25] = regreq_tdata[31:25]==1;
  assign regreq_tdata_for_size[24] = regreq_tdata[31:24]==1;
  assign regreq_tdata_for_size[23] = regreq_tdata[31:23]==1;
  assign regreq_tdata_for_size[22] = regreq_tdata[31:22]==1;
  assign regreq_tdata_for_size[21] = regreq_tdata[31:21]==1;
  assign regreq_tdata_for_size[20] = regreq_tdata[31:20]==1;
  assign regreq_tdata_for_size[19] = regreq_tdata[31:19]==1;
  assign regreq_tdata_for_size[18] = regreq_tdata[31:18]==1;
  assign regreq_tdata_for_size[17] = regreq_tdata[31:17]==1;
  assign regreq_tdata_for_size[16] = regreq_tdata[31:16]==1;
  assign regreq_tdata_for_size[15] = regreq_tdata[31:15]==1;
  assign regreq_tdata_for_size[14] = regreq_tdata[31:14]==1;
  assign regreq_tdata_for_size[13] = regreq_tdata[31:13]==1;
  assign regreq_tdata_for_size[12] = regreq_tdata[31:12]==1;

  always_comb begin
    for (int i = 0; i < (CH_NUM); i++) begin
      ch_ie_off[i]   = reg_wt_valid && (regreq_tuser[7:0]==8'h10) && (~regreq_tdata[0]) && (ch_sel==i) &&   ch_ie;
      ch_clr_on[i]   = reg_wt_valid && (regreq_tuser[7:0]==8'h10) &&   regreq_tdata[2]  && (ch_sel==i) && (~ch_clr);
    end
  end

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      ch_sel    <= '0;
      ch_ie     <= '0;
      ch_oe     <= '0;
      for (int i = 0; i < (CH_NUM); i++) begin
	ch_mode[i]       <= '0;
	que_entry[i]     <= 8'h10;
	que_addr[i]      <= '0;
        srbuf_addr[i]    <= '0;
        srbuf_size[i]    <= '0;
      end
    end 
    else if(reg_wt_valid) begin
      case(regreq_tuser[7:0])
	8'h0C   : ch_sel                    <= regreq_tdata[7:0];
	8'h10   : begin 
                    ch_ie     [ch_sel]      <= regreq_tdata[0];
                    ch_oe     [ch_sel]      <= regreq_tdata[1];
                  end
	8'h14   : ch_mode   [ch_sel]        <= regreq_tdata[2:0];
	8'h20   : que_entry [ch_sel]        <= regreq_tdata[15:8];
	8'h28   : que_addr  [ch_sel][31:6]  <= regreq_tdata[31:6];
	8'h2C   : que_addr  [ch_sel][63:32] <= regreq_tdata[31:0];
	8'h38   : srbuf_addr[ch_sel][31:6]  <= regreq_tdata[31:6];
	8'h3C   : srbuf_addr[ch_sel][63:32] <= regreq_tdata[31:0];
	8'h40   : srbuf_size[ch_sel][31:12] <= regreq_tdata_for_size;
	default : ;
      endcase
    end
  end
  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      ch_clr            <= '0;
      ch_dscq_clr       <= '0;
      ch_busy_force1_1t <= '0;
      ch_busy_force1_2t <= '0;
      ch_busy_force1_3t <= '0;
      ch_busy_force1_4t <= '0;
      ch_busy_force1_5t <= '0;
    end
    else begin
      ch_busy_force1_1t <= ch_ie_off | ch_clr_on;
      ch_busy_force1_2t <= ch_busy_force1_1t;
      ch_busy_force1_3t <= ch_busy_force1_2t;
      ch_busy_force1_4t <= ch_busy_force1_3t;
      ch_busy_force1_5t <= ch_busy_force1_4t;
      for (int i = 0; i < (CH_NUM); i++) begin
        if(reg_wt_valid && (regreq_tuser[7:0]==8'h10) && regreq_tdata[2] && (ch_sel==i)) begin
          ch_clr[i]      <= ~clr_mode;
          ch_dscq_clr[i] <= 1'b1;
        end
        else if(~ch_busy_all[i]) begin
          ch_clr[i]      <= 1'b0;
          ch_dscq_clr[i] <= 1'b0;
        end
      end
    end
  end

assign ch_active   = ch_ie & ch_oe;
assign ch_busy_all = ch_busy | rd_busy | wt_busy | ch_busy_force1_1t | ch_busy_force1_2t
                             | ch_busy_force1_3t | ch_busy_force1_4t | ch_busy_force1_5t;
assign ch_enb = RX ? ch_ie : ch_oe;

for (genvar i=0; i<CH_NUM; i++) begin
    assign que_base_addr[i] = {que_addr[i],6'b0};
end

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      regreq_rdt <= '0;
    end
    else if(reg_rd_valid) begin
      case(regreq_tuser[7:0])
	8'h00   : regreq_rdt <= {{(32-CH_NUM){1'b0}},ch_avail};
	8'h04   : regreq_rdt <= {{(32-CH_NUM){1'b0}},ch_active};
	8'h0C   : regreq_rdt <= {24'b0, ch_sel};
	8'h10   : regreq_rdt <= {28'b0, ch_busy[ch_sel], ch_dscq_clr[ch_sel], ch_oe[ch_sel], ch_ie[ch_sel]};
	8'h14   : regreq_rdt <= {ch_cid[ch_sel], ch_chain_id[ch_sel], 5'b0, ch_mode[ch_sel]};
	8'h20   : regreq_rdt <= {que_rp[ch_sel], que_wp[ch_sel], que_entry[ch_sel], que_dsc_size[ch_sel]};
	8'h28   : regreq_rdt <= {que_addr[ch_sel][31:6],6'b0};
	8'h2C   : regreq_rdt <= {que_addr[ch_sel][63:32]};
	8'h30   : regreq_rdt <= {srbuf_wp[ch_sel]};
	8'h34   : regreq_rdt <= {srbuf_rp[ch_sel]};
	8'h38   : regreq_rdt <= {srbuf_addr[ch_sel][31:0]};
	8'h3C   : regreq_rdt <= {srbuf_addr[ch_sel][63:32]};
	8'h40   : regreq_rdt <= {srbuf_size[ch_sel]};
	8'h50   : regreq_rdt <= {{(32-CH_NUM){1'b0}},ch_ie};
	8'h54   : regreq_rdt <= {{(32-CH_NUM){1'b0}},ch_oe};
	8'h58   : regreq_rdt <= {{(32-CH_NUM){1'b0}},ch_clr};
	8'h5C   : regreq_rdt <= {{(32-CH_NUM){1'b0}},ch_busy};
	default : regreq_rdt <= '0;
      endcase
    end
    else if(dbg_rd_valid) begin
      case(regreq_tuser[8:0])
	9'h034   : regreq_rdt <= {31'b0,clr_mode};
	9'h03C   : regreq_rdt <= {polling_interval2,polling_interval1};
	9'h100   : regreq_rdt <= dbg_rd_data[31:0];
	9'h104   : regreq_rdt <= dbg_rd_data[63:32];
	9'h108   : regreq_rdt <= dbg_rd_data[95:64];
	9'h10C   : regreq_rdt <= dbg_rd_data[127:96];
	9'h110   : regreq_rdt <= dbg_rd_data[159:128];
	9'h114   : regreq_rdt <= dbg_rd_data[191:160];
	9'h118   : regreq_rdt <= dbg_rd_data[223:192];
	9'h11C   : regreq_rdt <= dbg_rd_data[255:224];
	9'h120   : regreq_rdt <= dbg_rd_data[287:256];
	9'h124   : regreq_rdt <= dbg_rd_data[319:288];
	9'h128   : regreq_rdt <= dbg_rd_data[351:320];
	9'h12C   : regreq_rdt <= dbg_rd_data[383:352];
	9'h130   : regreq_rdt <= dbg_rd_data[415:384];
	9'h134   : regreq_rdt <= dbg_rd_data[447:416];
	9'h138   : regreq_rdt <= dbg_rd_data[479:448];
	9'h13C   : regreq_rdt <= dbg_rd_data[511:480];
	9'h140   : regreq_rdt <= {63'b0,dbg_enb};
	9'h148   : regreq_rdt <= {dbg_addr[31:6],6'b0};
	9'h14C   : regreq_rdt <= {dbg_addr[63:32]};
      endcase
    end
    else begin
      regreq_rdt = '0;
    end
  end

// Debug Read IF /////////////////////////////////////////////////////////////////////////
  assign dbg_acc_valid = regreq_tvalid && (regreq_tuser[15:9] == (RX ? 7'b0001_001 : 7'b0001_010));
  assign dbg_rd_valid  = dbg_acc_valid && (~regreq_tuser[32]);
  assign dbg_wt_valid  = dbg_acc_valid && ( regreq_tuser[32]);
  assign dbg_rd_req    = RX && dbg_enb && (~dbg_rd_busy);
  assign dbg_rc_rcv    = RX && dbg_rd_busy && rc_tvalid && (3'b001 == rc_tuser[15:13]);

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      dbg_enb           <= '0;
      dbg_addr          <= '0;
      dbg_rd_busy       <= '0;
      dbg_rd_data       <= '0;
      polling_interval1 <= '0;
      polling_interval2 <= '0;
      clr_mode          <= '0;
    end
    else begin
      if(dbg_wt_valid) begin
        case(regreq_tuser[8:0])
	  9'h034   : clr_mode <= regreq_tdata[0];
	  9'h03C   : {polling_interval2,polling_interval1} <= regreq_tdata[31:0];
        endcase
	if(RX) begin
          case(regreq_tuser[8:0])
  	    9'h140   : dbg_enb          <= regreq_tdata[0] ? 1'b1 : dbg_enb && (~dbg_rc_rcv);
	    9'h148   : dbg_addr[31:6]   <= regreq_tdata[31:6];
	    9'h14C   : dbg_addr[63:32]  <= regreq_tdata[31:0];
          endcase
	end
      end
      else if(dbg_rc_rcv) begin
        dbg_enb     <= '0;
      end

      if(rd_req_or_1t && rd_sel_1t[CH_NUM]) begin
        dbg_rd_busy <= 1'b1;
      end
      else if(dbg_rc_rcv) begin
        dbg_rd_busy <= '0;
	dbg_rd_data <= rc_tdata;
      end
   end
  end

// Queue Read IF ///////////////////////////////////////////////////////////////////////////
  assign rc_rcv        = rc_tvalid_1t && ((RX ? 3'b000 : 3'b010) == rc_tuser_1t[15:13]);
  assign cmd_eq_1      = rc_tdata_1t[23:16] == 8'h01;

  always_comb begin
    for (int i = 0; i < (CH_NUM); i++) begin
      ch_mode_eq0[i]   = ch_mode[i] == 3'b000;
      ch_mode_eq1[i]   = ch_mode[i] == 3'b001;
      ch_mode_eq2[i]   = ch_mode[i] == 3'b010;
      rd_req[i]        = que_rd_req[i] && ch_enb[i] && ch_mode_eq0[i]
                                       && (~rd_busy[i]) && (rd_wait_cnt[i] == 16'h00);
      que_rd_rc_rcv[i] = rc_rcv && (rc_tuser_1t[12:8] == i) && rd_busy[i];
      que_rd_dv[i]     = que_rd_rc_rcv[i] && cmd_eq_1 && ch_enb[i];
    end
  end

  assign rd_req_or = (|rd_req || dbg_rd_req) && (~rq_crd_tvalid) && (~rd_req_or_1t) && (~rd_req_or_2t);

  enqdeq_arb #( .N(CH_NUM+1)) rd_arb(
      .user_clk(user_clk),
      .reset_n(reset_n),
      .req({dbg_rd_req,rd_req}),
      .tkn_ack(rd_req_or),
      .tkn(rd_sel)
  );

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      for (int i = 0; i < (CH_NUM); i++) begin
        rd_wait_cnt[i]    <= '0;
        que_rp[i]         <= '0;
        rd_busy[i]        <= '0;
      end
      rd_busy             <= '0;
      rd_req_or_1t        <= '0;
      rd_req_or_2t        <= '0;
      rd_sel_1t           <= '0;
      rd_sel_2t           <= '0;
      rd_addr_2t          <= '0;
      rd_rp_2t            <= '0;
      rd_ch_2t            <= '0;
      rq_crd_tvalid       <= '0;
      rq_crd_tlast        <= '0;
      rq_crd_tdata[127:0] <= '0;
      rc_tvalid_1t        <= '0;
      rc_tdata_1t         <= '0;
      rc_tuser_1t         <= '0;
    end
    else begin
      for (int i = 0; i < (CH_NUM); i++) begin
        rd_busy[i]        <= (rd_req_or && rd_sel[i]) || (rd_busy[i] && (~que_rd_rc_rcv[i])); 
        rd_wait_cnt[i]    <= que_rd_rc_rcv[i] ? (cmd_eq_1 ? polling_interval1 : polling_interval2)
	                                      : ((rd_wait_cnt[i]==16'b0) ? 16'b0 : rd_wait_cnt[i]-1);
        que_rp[i]         <= ch_dscq_clr[i] ? 0
                                            : que_rd_dv[i] ? ((que_rp[i]+1) == que_entry[i] ? 8'b0 : (que_rp[i]+1))
	                                                   : que_rp[i];
      end
      rd_req_or_1t        <= rd_req_or;
      rd_req_or_2t        <= rd_req_or_1t;
      rd_sel_1t           <= rd_sel;
      if(rd_req_or_1t) begin
        rd_sel_2t         <= rd_sel_1t;
        if(rd_sel_1t[CH_NUM]) begin
            rd_addr_2t    <= dbg_addr;
            rd_rp_2t      <= '0;
            rd_ch_2t      <= '0;
	end
	else begin
          for (int i = 0; i < (CH_NUM); i++) begin
  	    if(rd_sel_1t[i]) begin
              rd_addr_2t    <= que_addr[i];
              rd_rp_2t      <= que_rp[i];
              rd_ch_2t      <= ch_cid[i];
            end
          end
        end
      end
      if((~rq_crd_tvalid) || rq_crd_tready) begin
        rq_crd_tvalid     <= rd_req_or_2t;
        rq_crd_tlast      <= rd_req_or_2t;
      end
      if(rd_req_or_2t) begin
        rq_crd_tdata[127:0] <=  {1'b0					// FORCE_ECRC
				,3'b000					// ATTR
				,3'b000					// RQ_TC
			        ,1'b0					// REQUESTER_ID_ENABLE
			        ,16'h0000							// COMPLETER_ID
			        ,{rd_sel_2t[CH_NUM] ? 3'b001 : RX ? 3'b000 : 3'b010},rd_ch_2t	// TAG
			        ,16'h0000							// REQUESTER_ID
			        ,1'b0					// POISONED_REQUEST
			        ,4'h0					// REQ_TYPE
			        ,11'h010				// DWORD_COUNT
			        ,{rd_addr_2t+rd_rp_2t} 			// ADDR;
				,6'b0
			        };
      end
      rc_tvalid_1t        <= rc_tvalid;
      if(rc_tvalid) begin
        rc_tdata_1t         <= rc_tdata[127:0];
        rc_tuser_1t         <= rc_tuser;
      end
    end
  end

  assign que_rd_dt = rc_tdata_1t;
  assign rq_crd_tdata[511:128] = '0;

// Queue Write IF ///////////////////////////////////////////////////////////////////////////
  always_comb begin
    for (int i = 0; i < (CH_NUM); i++) begin
      wt_req[i]        = que_wt_req[i] && (~wt_busy[i])  && (ch_mode_eq0[i] || ch_mode_eq1[i] || (RX & ch_mode_eq2[i]));
    end
  end

  assign wt_req_or = (|wt_req) && (~rq_cwr_tvalid) && (~wt_req_or_1t) && (~wt_req_or_2t) && (~wt_req_or_3t);

  enqdeq_arb #( .N(CH_NUM)) wt_arb (
      .user_clk(user_clk),
      .reset_n(reset_n),
      .req(wt_req),
      .tkn_ack(wt_req_or),
      .tkn(wt_sel)
  );

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      for (int i = 0; i < (CH_NUM); i++) begin
	que_wp[i]         <= '0;
        wt_busy[i]        <= '0;
      end
      wt_req_or_1t        <= '0;
      wt_req_or_2t        <= '0;
      wt_req_or_3t        <= '0;
      wt_sel_1t           <= '0;
      wt_sel_2t           <= '0;
      que_wt_ack          <= '0;
      wt_addr_2t          <= '0;
      wt_wp_2t            <= '0;
      wt_wd_2t            <= '0;
      rq_cwr_tvalid       <= '0;
      rq_cwr_tlast        <= '0;
      rq_cwr_tdata[127:0] <= '0;
    end
    else begin
      for (int i = 0; i < (CH_NUM); i++) begin
        wt_busy[i]        <= (wt_req_or && wt_sel[i]) || (wt_busy[i] && (~que_wt_ack[i])); 
      end
      wt_req_or_1t        <= wt_req_or;
      wt_req_or_2t        <= wt_req_or_1t;
      wt_sel_1t           <= wt_sel;
      que_wt_ack          <= {CH_NUM{rq_cwr_tvalid & rq_cwr_tlast & rq_cwr_tready}} & wt_sel_2t;
      if(wt_req_or_1t) begin
        wt_sel_2t         <= wt_sel_1t;
        for (int i = 0; i < (CH_NUM); i++) begin
          que_wp[i]         <= ch_dscq_clr[i] ? 1'b0 
                                              : wt_sel_1t[i] ? ((que_wp[i]+1) == que_entry[i] ? 8'b0 : (que_wp[i]+1))
	                                                     : que_wp[i];
	  if(wt_sel_1t[i]) begin
            wt_addr_2t        <= que_addr[i];
            wt_wp_2t          <= ch_mode_eq0[i] ? {3'h0,que_wp[i]} : (RX ? 11'h47C : 11'h478);
            wt_wd_2t[127:24]  <= que_wt_dt[i][127:24];
            wt_wd_2t[23:16]   <= ch_mode_eq0[i] ? que_wt_dt[i][23:16] : que_entry[i][7:0];
            wt_wd_2t[15:0]    <= que_wt_dt[i][15:0];
          end
        end
      end
      else begin
        for (int i = 0; i < (CH_NUM); i++) begin
	    que_wp[i]     <= ch_dscq_clr[i] ? '0 : que_wp[i];
        end
      end
      if((~rq_cwr_tvalid) || rq_cwr_tready) begin
        wt_req_or_3t      <= wt_req_or_2t;
        rq_cwr_tvalid     <= wt_req_or_2t || wt_req_or_3t;
        rq_cwr_tlast      <= wt_req_or_3t;
      end
      if(wt_req_or_2t) begin
        rq_cwr_tdata[127:0] <=  {1'b0					// FORCE_ECRC
				,3'b000					// ATTR
				,3'b000					// RQ_TC
			        ,1'b0					// REQUESTER_ID_ENABLE
			        ,16'h0000				// COMPLETER_ID
			        ,8'h00                           	// TAG
			       	,16'h0000				// REQUESTER_ID
			        ,1'b0					// POISONED_REQUEST
			        ,4'h1					// REQ_TYPE
			       	,11'h010				// DWORD_COUNT
			        ,{wt_addr_2t + wt_wp_2t}		// ADDR
				,6'b0
			        };
      end if(wt_req_or_3t && rq_cwr_tready) begin
        rq_cwr_tdata[127:0] <=  wt_wd_2t;
      end
    end
  end

  assign rq_cwr_tdata[511:128] = '0;

// PA Counter /////////////////////////////////////////////////////////////////////////////
  always_comb begin
    for (int i = 0; i < (CH_NUM); i++) begin
      rcv_cid_vec[i]  = regreq_tdata[23:16] == i;
    end
  end

  assign fetch_enqdeq = rq_crd_tvalid && rq_crd_tlast && rq_crd_tready;

  always_comb begin
    for (int i = 0; i < (CH_NUM); i++) begin
      pa_item_fetch_enqdeq[i]  = fetch_enqdeq && (rd_ch_2t == i) && ch_mode_eq0[i];
      rcv_d2d[i]   = RX ?      regreq_tvalid && (regreq_tuser[15:0] == 16'h1E00) &&  ch_mode_eq1[i]                   & rcv_cid_vec[i] : '0;
      rcv_ack[i]   = RX ? '0 : regreq_tvalid && (regreq_tuser[15:0] == 16'h1F00) && (ch_mode_eq1[i] | ch_mode_eq2[i]) & rcv_cid_vec[i];
      send_d2d[i]  = RX ? '0 : que_wt_ack[i] &  ch_mode_eq1[i];
      send_ack[i]  = RX ?      que_wt_ack[i] & (ch_mode_eq1[i] | ch_mode_eq2[i]) : '0;
    end
  end

  assign pa_item_receive_dsc   = que_rd_dv  & ch_mode_eq0;
  assign pa_item_store_enqdeq  = que_wt_ack & ch_mode_eq0;
  assign pa_item_rcv_send_d2d  = send_d2d | rcv_d2d;
  assign pa_item_send_rcv_ack  = send_ack | rcv_ack;

  always_ff @(posedge user_clk or negedge reset_n) begin
    if (reset_n == 1'b0) begin
      for (int i = 0; i < (CH_NUM); i++) begin
        pa_item_dscq_used_cnt_tmp[i] <= '0;
      end
    end
    else begin
      for (int i = 0; i < (CH_NUM); i++) begin
        pa_item_dscq_used_cnt_tmp[i] <= pa_item_dscq_used_cnt_tmp[i] + (pa_item_receive_dsc[i]  || rcv_d2d[i])
	                                                             - (pa_item_store_enqdeq[i] || send_ack[i]); 
      end
    end
  end

  always_comb begin
    for (int i = 0; i < (CH_NUM); i++) begin
      pa_item_dscq_used_cnt[i] = {11'b0,pa_item_dscq_used_cnt_tmp[i]};
    end
  end

endmodule
