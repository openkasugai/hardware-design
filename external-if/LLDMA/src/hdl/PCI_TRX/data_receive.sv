/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module data_receive(
  input  wire		user_clk,
  input  wire		reset_n,

  input			s_axis_rc_tvalid,
  input			s_axis_rc_tlast,
  input [511:0]		s_axis_rc_tdata,
  input [15:0]		s_axis_rc_tkeep,
  input [16:0]		s_axis_rc_tuser,
  output reg		s_axis_rc_tready,

  output reg 		rc_axis_tvalid_dmar,
  output reg 		rc_axis_tvalid_dmat,
  output reg 		rc_axis_tlast,
  output reg  [511:0]	rc_axis_tdata,
  output reg  [15:0]	rc_axis_tkeep,
  output reg  [15:0]	rc_axis_tuser,
  output reg  [11:0]	rc_axis_taddr_dmar,
  input			rc_axis_tready_dmar,
  input			rc_axis_tready_dmat
);

  reg		wait_req;
  reg [511:96]	s_axis_rc_tdata_1t;
  reg [15:3]	s_axis_rc_tkeep_1t;

  wire		rcv_1st_pkt;
  reg		tag_eq_dmat_deq;
  reg		tag_eq_dmar;
  wire		dmat_deq_vald;
  wire		dmar_vald;
  wire		dmat_0len_vald;
  wire          set_tlast;

  assign s_axis_rc_tready = 1'b1;

  always @(posedge user_clk) begin
	if(!reset_n) begin
		wait_req <= 1'b0;
	end
	else if(s_axis_rc_tvalid) begin
		wait_req <= ~s_axis_rc_tlast;
	end
  end

  assign rcv_1st_pkt = s_axis_rc_tvalid & (~wait_req);

  always @(posedge user_clk) begin
	if(!reset_n) begin
		tag_eq_dmat_deq     <= 1'b0;
		tag_eq_dmar         <= 1'b0;
		rc_axis_tuser[15:0] <= 16'b0;
		rc_axis_taddr_dmar[11:0] <= 12'b0;
        end
	else if(rcv_1st_pkt) begin
		tag_eq_dmat_deq          <= (s_axis_rc_tdata[71:69] == 3'b010);
		tag_eq_dmar              <= (s_axis_rc_tdata[71] == 1'b1) | (s_axis_rc_tdata[71:70] == 2'b00);
		rc_axis_tuser[15:8]      <= s_axis_rc_tdata[71:64];
		rc_axis_tuser[7:4]       <= s_axis_rc_tdata[46:43];
		rc_axis_tuser[3:0]       <= s_axis_rc_tdata[15:12];
		rc_axis_taddr_dmar[11:0] <= s_axis_rc_tdata[11:0];
	end
  end

  wire dmar_0len_vald = rcv_1st_pkt && (s_axis_rc_tdata[28:18] < 10'd13) && (s_axis_rc_tdata[71:69] == 3'b001) && s_axis_rc_tvalid;
  assign dmat_deq_vald  = s_axis_rc_tvalid & (wait_req) & tag_eq_dmat_deq;
  assign dmar_vald      = s_axis_rc_tvalid & (wait_req) & tag_eq_dmar;
  assign dmat_0len_vald = rcv_1st_pkt & (s_axis_rc_tdata[71:69] == 3'b011);
  assign set_tlast      = (s_axis_rc_tlast & (tag_eq_dmat_deq | tag_eq_dmar)) | dmat_0len_vald;

  always @(posedge user_clk) begin
	if(!reset_n) begin
		rc_axis_tvalid_dmar <= 1'b0;
		rc_axis_tvalid_dmat <= 1'b0;
		rc_axis_tlast       <= 1'b0;
	end
	else begin
		rc_axis_tvalid_dmar <= dmar_0len_vald | dmar_vald;
		rc_axis_tvalid_dmat <= dmat_0len_vald | dmat_deq_vald;
		rc_axis_tlast       <= set_tlast;
	end
  end

  always @(posedge user_clk) begin
	if(!reset_n) begin
		s_axis_rc_tdata_1t <= 416'b0;
		s_axis_rc_tkeep_1t <= 13'b0;
                rc_axis_tdata      <= 512'b0;
                rc_axis_tkeep      <= 16'b0;
        end
	else if(s_axis_rc_tvalid) begin
          if (rcv_1st_pkt && s_axis_rc_tlast) begin
		    s_axis_rc_tdata_1t[511:96] <= s_axis_rc_tdata[511:96];
		    s_axis_rc_tkeep_1t[15:3]   <= s_axis_rc_tkeep[15:3];
		    rc_axis_tdata[415:0]       <= s_axis_rc_tdata[511:96];
		    rc_axis_tdata[511:416]     <= s_axis_rc_tdata[95:0];
		    rc_axis_tkeep[12:0]        <= s_axis_rc_tkeep[15:3];
		    rc_axis_tkeep[15:13]       <= 'd0;
          end else begin
		    s_axis_rc_tdata_1t[511:96] <= s_axis_rc_tdata[511:96];
		    s_axis_rc_tkeep_1t[15:3]   <= s_axis_rc_tkeep[15:3];
		    rc_axis_tdata[415:0]       <= s_axis_rc_tdata_1t[511:96];
		    rc_axis_tdata[511:416]     <= s_axis_rc_tdata[95:0];
		    rc_axis_tkeep[12:0]        <= s_axis_rc_tkeep_1t[15:3];
		    rc_axis_tkeep[15:13]       <= s_axis_rc_tkeep[2:0];
          end
	end
  end

endmodule
