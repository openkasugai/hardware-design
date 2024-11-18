/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module pci_pa_count #(
  parameter AXI4_CQ_TUSER_WIDTH = 183,
  parameter AXI4_CC_TUSER_WIDTH = 81,
  parameter C_DATA_WIDTH        = 512,
  parameter KEEP_WIDTH          = C_DATA_WIDTH /32
)(

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME user_clk, ASSOCIATED_BUSIF m_axis_req_mon:s_axis_cmp_mon, ASSOCIATED_RESET reset_n, FREQ_HZ 250000000, FREQ_TOLERANCE_HZ 0, PHASE 0.000, CLK_DOMAIN design_1_pcie4c_uscale_plus_0_1_user_clk, INSERT_VIP 0" *)
  input  wire                           user_clk,
  input  wire                           reset_n,

  // AXI-S Completer Request Interface
  input  wire                           m_axis_req_mon_tvalid,
  input  wire        [C_DATA_WIDTH-1:0] m_axis_req_mon_tdata,
  input  wire          [KEEP_WIDTH-1:0] m_axis_req_mon_tkeep,
  input  wire                           m_axis_req_mon_tlast,
  input  wire [AXI4_CQ_TUSER_WIDTH-1:0] m_axis_req_mon_tuser,
  input  wire                           m_axis_req_mon_tready,

  // AXI-S Completer Completion Interface
  input  wire                           s_axis_cmp_mon_tvalid,
  input  wire        [C_DATA_WIDTH-1:0] s_axis_cmp_mon_tdata,
  input  wire          [KEEP_WIDTH-1:0] s_axis_cmp_mon_tkeep,
  input  wire                           s_axis_cmp_mon_tlast,
  input  wire [AXI4_CC_TUSER_WIDTH-1:0] s_axis_cmp_mon_tuser,
  input  wire                           s_axis_cmp_mon_tready,
  
  input  wire                           pa_count_reset,  // 1:reset
  input  wire                           pa_count_enable, // 1:enable
  
  output wire                    [31:0] mem_rd_req_count,
  output wire                    [31:0] mem_wd_req_count,
  output wire                    [31:0] i_o_rd_req_count,
  output wire                    [31:0] i_o_wd_req_count,
  output wire                    [31:0] mem_fet_add_req_count,
  output wire                    [31:0] mem_uncnd_swp_req_count,
  output wire                    [31:0] mem_cmp_swp_req_count,
  output wire                    [31:0] lock_rd_req_count,
  output wire                    [31:0] type_0_cnf_rd_req_count,
  output wire                    [31:0] type_1_cnf_rd_req_count,
  output wire                    [31:0] type_0_cnf_wd_req_count,
  output wire                    [31:0] type_1_cnf_wd_req_count,
  output wire                    [31:0] any_message_count,
  output wire                    [31:0] v_d_message_count,
  output wire                    [31:0] ats_message_count,
  output wire                    [31:0] req_reserved_count,
  output wire                    [31:0] req_cmp_count
);

  
  localparam MEM_RD_REQ          = 4'b0000;     // Memory Read
  localparam MEM_WD_REQ          = 4'b0001;     // Memory Write
  localparam I_O_RD_REQ          = 4'b0010;     // IO Read
  localparam I_O_WD_REQ          = 4'b0011;     // IO Write
  localparam MEM_FET_ADD_REQ     = 4'b0100;     // Fetch and ADD
  localparam MEM_UNCND_SWP_REQ   = 4'b0101;     // Unconditional SWAP
  localparam MEM_CMP_SWP_REQ     = 4'b0110;     // Compare and SWAP
  localparam LOCK_RD_REQ         = 4'b0111;     // Locked Read Request
  localparam TYPE_0_CNF_RD_REQ   = 4'b1000;     // Type 0 Configuration Read Request (on Requester side only)
  localparam TYPE_1_CNF_RD_REQ   = 4'b1001;     // Type 1 Configuration Read Request (on Requester side only)
  localparam TYPE_0_CNF_WD_REQ   = 4'b1010;     // Type 0 Configuration Write Request (on Requester side only)
  localparam TYPE_1_CNF_WD_REQ   = 4'b1011;     // Type 1 Configuration Write Request (on Requester side only)
  localparam ANY_MESSAGE         = 4'b1100;     // Any message, except ATS and Vendor-Defined Messages
  localparam V_D_MESSAGE         = 4'b1101;     // Vendor-Defined Message
  localparam ATS_MESSAGE         = 4'b1110;     // ATS Message
  localparam REQ_RESERVED        = 4'b1111;     // Reserved
  
reg                           sr_m_axis_req_mon_tvalid;
reg        [C_DATA_WIDTH-1:0] sr_m_axis_req_mon_tdata;
reg          [KEEP_WIDTH-1:0] sr_m_axis_req_mon_tkeep;
reg                           sr_m_axis_req_mon_tlast;
reg [AXI4_CQ_TUSER_WIDTH-1:0] sr_m_axis_req_mon_tuser;
reg                           sr_m_axis_req_mon_tready;

reg                           sr_s_axis_cmp_mon_tvalid;
reg        [C_DATA_WIDTH-1:0] sr_s_axis_cmp_mon_tdata;
reg          [KEEP_WIDTH-1:0] sr_s_axis_cmp_mon_tkeep;
reg                           sr_s_axis_cmp_mon_tlast;
reg [AXI4_CC_TUSER_WIDTH-1:0] sr_s_axis_cmp_mon_tuser;
reg                           sr_s_axis_cmp_mon_tready;

reg sr_m_axis_req_mon_sop;
reg sr_s_axis_cmp_mon_sop;

reg [3:0] sr_req_type;
reg       sr_req_type_valid;
reg       sr_cmp_valid;

reg [31:0] sr_mem_rd_req_count;
reg [31:0] sr_mem_wd_req_count;
reg [31:0] sr_i_o_rd_req_count;
reg [31:0] sr_i_o_wd_req_count;
reg [31:0] sr_mem_fet_add_req_count;
reg [31:0] sr_mem_uncnd_swp_req_count;
reg [31:0] sr_mem_cmp_swp_req_count;
reg [31:0] sr_lock_rd_req_count;
reg [31:0] sr_type_0_cnf_rd_req_count;
reg [31:0] sr_type_1_cnf_rd_req_count;
reg [31:0] sr_type_0_cnf_wd_req_count;
reg [31:0] sr_type_1_cnf_wd_req_count;
reg [31:0] sr_any_message_count;
reg [31:0] sr_v_d_message_count;
reg [31:0] sr_ats_message_count;
reg [31:0] sr_req_reserved_count;
reg [31:0] sr_req_cmp_count;

// Input FF for timing closure
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_m_axis_req_mon_tvalid <= 1'b0;
    sr_m_axis_req_mon_tdata  <= {C_DATA_WIDTH{1'b0}};
    sr_m_axis_req_mon_tkeep  <= {KEEP_WIDTH{1'b0}};
    sr_m_axis_req_mon_tlast  <= 1'b0;
    sr_m_axis_req_mon_tuser  <= {AXI4_CQ_TUSER_WIDTH{1'b0}};
    sr_m_axis_req_mon_tready <= 1'b0;
    
    sr_s_axis_cmp_mon_tvalid <= 1'b0;
    sr_s_axis_cmp_mon_tdata  <= {C_DATA_WIDTH{1'b0}};
    sr_s_axis_cmp_mon_tkeep  <= {KEEP_WIDTH{1'b0}};
    sr_s_axis_cmp_mon_tlast  <= 1'b0;
    sr_s_axis_cmp_mon_tuser  <= {AXI4_CC_TUSER_WIDTH{1'b0}};
    sr_s_axis_cmp_mon_tready <= 1'b0;
  end else begin
    sr_m_axis_req_mon_tvalid <= m_axis_req_mon_tvalid;
    sr_m_axis_req_mon_tdata  <= m_axis_req_mon_tdata ;
    sr_m_axis_req_mon_tkeep  <= m_axis_req_mon_tkeep ;
    sr_m_axis_req_mon_tlast  <= m_axis_req_mon_tlast ;
    sr_m_axis_req_mon_tuser  <= m_axis_req_mon_tuser ;
    sr_m_axis_req_mon_tready <= m_axis_req_mon_tready;
    
    sr_s_axis_cmp_mon_tvalid <= s_axis_cmp_mon_tvalid;
    sr_s_axis_cmp_mon_tdata  <= s_axis_cmp_mon_tdata ;
    sr_s_axis_cmp_mon_tkeep  <= s_axis_cmp_mon_tkeep ;
    sr_s_axis_cmp_mon_tlast  <= s_axis_cmp_mon_tlast ;
    sr_s_axis_cmp_mon_tuser  <= s_axis_cmp_mon_tuser ;
    sr_s_axis_cmp_mon_tready <= s_axis_cmp_mon_tready;
  end
end

// start detection
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_m_axis_req_mon_sop <= 1'b1;
    sr_s_axis_cmp_mon_sop <= 1'b1;
  end else begin
    if(sr_m_axis_req_mon_tlast && sr_m_axis_req_mon_tvalid && sr_m_axis_req_mon_tready)begin
      sr_m_axis_req_mon_sop <= 1'b1;
    end else begin
      if(sr_m_axis_req_mon_tvalid && sr_m_axis_req_mon_tready)begin
        sr_m_axis_req_mon_sop <= 1'b0;
      end else begin
        sr_m_axis_req_mon_sop <= sr_m_axis_req_mon_sop;
      end
    end

    if(sr_s_axis_cmp_mon_tlast && sr_s_axis_cmp_mon_tvalid && sr_s_axis_cmp_mon_tready)begin
      sr_s_axis_cmp_mon_sop <= 1'b1;
    end else begin
      if(sr_s_axis_cmp_mon_tvalid && sr_s_axis_cmp_mon_tready)begin
        sr_s_axis_cmp_mon_sop <= 1'b0;
      end else begin
        sr_s_axis_cmp_mon_sop <= sr_s_axis_cmp_mon_sop;
      end
    end
  end
end

// extract detected position
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_req_type       <= 4'b0000;
    sr_req_type_valid <= 1'b0;

    sr_cmp_valid      <= 1'b0;
  end else begin
    sr_req_type       <= sr_m_axis_req_mon_tdata[78:75];
    sr_req_type_valid <= sr_m_axis_req_mon_sop && sr_m_axis_req_mon_tvalid && sr_m_axis_req_mon_tready;

    sr_cmp_valid      <= sr_s_axis_cmp_mon_sop && sr_s_axis_cmp_mon_tvalid && sr_s_axis_cmp_mon_tready;
  end
end

// Type counter
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_mem_rd_req_count        <= {32{1'b0}};
    sr_mem_wd_req_count        <= {32{1'b0}};
    sr_i_o_rd_req_count        <= {32{1'b0}};
    sr_i_o_wd_req_count        <= {32{1'b0}};
    sr_mem_fet_add_req_count   <= {32{1'b0}};
    sr_mem_uncnd_swp_req_count <= {32{1'b0}};
    sr_mem_cmp_swp_req_count   <= {32{1'b0}};
    sr_lock_rd_req_count       <= {32{1'b0}};
    sr_type_0_cnf_rd_req_count <= {32{1'b0}};
    sr_type_1_cnf_rd_req_count <= {32{1'b0}};
    sr_type_0_cnf_wd_req_count <= {32{1'b0}};
    sr_type_1_cnf_wd_req_count <= {32{1'b0}};
    sr_any_message_count       <= {32{1'b0}};
    sr_v_d_message_count       <= {32{1'b0}};
    sr_ats_message_count       <= {32{1'b0}};
    sr_req_reserved_count      <= {32{1'b0}};
    sr_req_cmp_count           <= {32{1'b0}};
  end else begin
    if(pa_count_reset)begin
      sr_mem_rd_req_count        <= {32{1'b0}};
      sr_mem_wd_req_count        <= {32{1'b0}};
      sr_i_o_rd_req_count        <= {32{1'b0}};
      sr_i_o_wd_req_count        <= {32{1'b0}};
      sr_mem_fet_add_req_count   <= {32{1'b0}};
      sr_mem_uncnd_swp_req_count <= {32{1'b0}};
      sr_mem_cmp_swp_req_count   <= {32{1'b0}};
      sr_lock_rd_req_count       <= {32{1'b0}};
      sr_type_0_cnf_rd_req_count <= {32{1'b0}};
      sr_type_1_cnf_rd_req_count <= {32{1'b0}};
      sr_type_0_cnf_wd_req_count <= {32{1'b0}};
      sr_type_1_cnf_wd_req_count <= {32{1'b0}};
      sr_any_message_count       <= {32{1'b0}};
      sr_v_d_message_count       <= {32{1'b0}};
      sr_ats_message_count       <= {32{1'b0}};
      sr_req_reserved_count      <= {32{1'b0}};
      sr_req_cmp_count           <= {32{1'b0}};
    end else begin
      if(sr_req_type_valid && pa_count_enable)begin
        case (sr_req_type)
          MEM_RD_REQ        : sr_mem_rd_req_count        <= sr_mem_rd_req_count        + 1;
          MEM_WD_REQ        : sr_mem_wd_req_count        <= sr_mem_wd_req_count        + 1;
          I_O_RD_REQ        : sr_i_o_rd_req_count        <= sr_i_o_rd_req_count        + 1;
          I_O_WD_REQ        : sr_i_o_wd_req_count        <= sr_i_o_wd_req_count        + 1;
          MEM_FET_ADD_REQ   : sr_mem_fet_add_req_count   <= sr_mem_fet_add_req_count   + 1;
          MEM_UNCND_SWP_REQ : sr_mem_uncnd_swp_req_count <= sr_mem_uncnd_swp_req_count + 1;
          MEM_CMP_SWP_REQ   : sr_mem_cmp_swp_req_count   <= sr_mem_cmp_swp_req_count   + 1;
          LOCK_RD_REQ       : sr_lock_rd_req_count       <= sr_lock_rd_req_count       + 1;
          TYPE_0_CNF_RD_REQ : sr_type_0_cnf_rd_req_count <= sr_type_0_cnf_rd_req_count + 1;
          TYPE_1_CNF_RD_REQ : sr_type_1_cnf_rd_req_count <= sr_type_1_cnf_rd_req_count + 1;
          TYPE_0_CNF_WD_REQ : sr_type_0_cnf_wd_req_count <= sr_type_0_cnf_wd_req_count + 1;
          TYPE_1_CNF_WD_REQ : sr_type_1_cnf_wd_req_count <= sr_type_1_cnf_wd_req_count + 1;
          ANY_MESSAGE       : sr_any_message_count       <= sr_any_message_count       + 1;
          V_D_MESSAGE       : sr_v_d_message_count       <= sr_v_d_message_count       + 1;
          ATS_MESSAGE       : sr_ats_message_count       <= sr_ats_message_count       + 1;
          REQ_RESERVED      : sr_req_reserved_count      <= sr_req_reserved_count      + 1;
          default :;
        endcase
      end
      
      if(sr_cmp_valid && pa_count_enable)begin
        sr_req_cmp_count <= sr_req_cmp_count + 1;
      end
      
    end
  end
end

assign mem_rd_req_count        = sr_mem_rd_req_count;
assign mem_wd_req_count        = sr_mem_wd_req_count;
assign i_o_rd_req_count        = sr_i_o_rd_req_count;
assign i_o_wd_req_count        = sr_i_o_wd_req_count;
assign mem_fet_add_req_count   = sr_mem_fet_add_req_count;
assign mem_uncnd_swp_req_count = sr_mem_uncnd_swp_req_count;
assign mem_cmp_swp_req_count   = sr_mem_cmp_swp_req_count;
assign lock_rd_req_count       = sr_lock_rd_req_count;
assign type_0_cnf_rd_req_count = sr_type_0_cnf_rd_req_count;
assign type_1_cnf_rd_req_count = sr_type_1_cnf_rd_req_count;
assign type_0_cnf_wd_req_count = sr_type_0_cnf_wd_req_count;
assign type_1_cnf_wd_req_count = sr_type_1_cnf_wd_req_count;
assign any_message_count       = sr_any_message_count;
assign v_d_message_count       = sr_v_d_message_count;
assign ats_message_count       = sr_ats_message_count;
assign req_reserved_count      = sr_req_reserved_count;
assign req_cmp_count           = sr_req_cmp_count;

endmodule
