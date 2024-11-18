/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module axis2axi_bridge #(
  parameter AXI4_CQ_TUSER_WIDTH = 183,
  parameter AXI4_CC_TUSER_WIDTH = 81,
  parameter ADDR_WIDTH          = 36,
  parameter MUSK_ADDR_WIDTH     = 36,
  parameter C_DATA_WIDTH        = 512,
  parameter KEEP_WIDTH          = C_DATA_WIDTH /32
)(

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME user_clk, ASSOCIATED_BUSIF m_axis_cq:m_axis_cc:m_axi:m_axis_men_direct, ASSOCIATED_RESET reset_n, FREQ_HZ 250000000, FREQ_TOLERANCE_HZ 0, PHASE 0.000, CLK_DOMAIN design_1_pcie4_uscale_plus_0_0_user_clk, INSERT_VIP 0" *)
  input  wire                           user_clk,
  input  wire                           reset_n,

  // AXI-S Completer Request Interface (Slave)
  input  wire                           s_axis_cq_tvalid,
  input  wire        [C_DATA_WIDTH-1:0] s_axis_cq_tdata,
  input  wire          [KEEP_WIDTH-1:0] s_axis_cq_tkeep,
  input  wire                           s_axis_cq_tlast,
  input  wire [AXI4_CQ_TUSER_WIDTH-1:0] s_axis_cq_tuser,
  output wire                           s_axis_cq_tready,

  // AXI-S Completer Completion Interface (Master)
  output wire                           m_axis_cc_tvalid,
  output wire        [C_DATA_WIDTH-1:0] m_axis_cc_tdata,
  output wire          [KEEP_WIDTH-1:0] m_axis_cc_tkeep,
  output wire                           m_axis_cc_tlast,
  output wire [AXI4_CC_TUSER_WIDTH-1:0] m_axis_cc_tuser,
  input  wire                           m_axis_cc_tready,

  // AXI4-Lite Interface
  output wire          [ADDR_WIDTH-1:0] m_axi_awaddr,
  output wire                     [2:0] m_axi_awprot,
  output wire                           m_axi_awvalid,
  input  wire                           m_axi_awready,
  output wire                    [31:0] m_axi_wdata,
  output wire                     [3:0] m_axi_wstrb,
  output wire                           m_axi_wvalid,
  input  wire                           m_axi_wready,
  input  wire                     [1:0] m_axi_bresp,  // open
  input  wire                           m_axi_bvalid, // Write response (unused)
  output wire                           m_axi_bready,
  output wire          [ADDR_WIDTH-1:0] m_axi_araddr,
  output wire                     [2:0] m_axi_arprot,
  output wire                           m_axi_arvalid,
  input  wire                           m_axi_arready,
  input  wire                    [31:0] m_axi_rdata,
  input  wire                     [1:0] m_axi_rresp,  // open
  input  wire                           m_axi_rvalid,
  output wire                           m_axi_rready,

  // D2D,ACK
  output wire                   [511:0] m_d2d_data,
  output wire                           m_d2d_req_valid,
  output wire                           m_d2d_ack_valid,
  input  wire                           m_d2d_ready,
  
  // Direct Transfer
  output wire                           m_axis_direct_tvalid,
  output wire        [C_DATA_WIDTH-1:0] m_axis_direct_tdata,
  //output wire          [KEEP_WIDTH-1:0] m_axis_direct_tkeep,
  //output wire                           m_axis_direct_tlast,
  output wire                    [15:0] m_axis_direct_tuser,
  input  wire                           m_axis_direct_tready
);

  
  localparam MEM_RD_REQ          = 4'b0000;     // Memory Read
  localparam MEM_WD_REQ          = 4'b0001;     // Memory Write
  localparam I_O_RD_REQ          = 4'b0010;     // IO Read                not supported
  localparam I_O_WD_REQ          = 4'b0011;     // IO Write               not supported
  localparam MEM_FET_ADD_REQ     = 4'b0100;     // Fetch and ADD          not supported
  localparam MEM_UNCND_SWP_REQ   = 4'b0101;     // Unconditional SWAP     not supported
  localparam MEM_CMP_SWP_REQ     = 4'b0110;     // Compare and SWAP       not supported
  localparam LOCK_RD_REQ         = 4'b0111;     // Locked Read Request    not supported
  localparam TYPE_0_CNF_RD_REQ   = 4'b1000;     // Type 0 Configuration Read Request (on Requester side only)
  localparam TYPE_1_CNF_RD_REQ   = 4'b1001;     // Type 1 Configuration Read Request (on Requester side only)
  localparam TYPE_0_CNF_WD_REQ   = 4'b1010;     // Type 0 Configuration Write Request (on Requester side only)
  localparam TYPE_1_CNF_WD_REQ   = 4'b1011;     // Type 1 Configuration Write Request (on Requester side only)
  localparam ANY_MESSAGE         = 4'b1100;     // Any message, except ATS and Vendor-Defined Messages
  localparam V_D_MESSAGE         = 4'b1101;     // Vendor-Defined Message
  localparam ATS_MESSAGE         = 4'b1110;     // ATS Message
  localparam REQ_RESERVED        = 4'b1111;     // Reserved
  
  localparam AXIS_CC_ADDR_D2D = 64'h0000_0000_0001_1E00; // D2D address: comparison in fixed bits
  localparam AXIS_CC_ADDR_ACK = 64'h0000_0000_0001_1F00; // ACK address: comparison in fixed bits
  localparam AXIS_CC_ADDR_DRC = 64'h0000_0000_0001_1D00; // Direct forwarding address: fixed-bit comparison
  localparam AXIS_CC_ADDR_DRC_MIN = 64'h0000_0000_0001_2000; // Directed forward address minimum:
  localparam AXIS_CC_ADDR_DRC_MAX = 64'h0000_0000_0001_9FFC; // Direct Forward Address maximum:
  
  localparam MUSK_ADDR_WIDTH_REST  = ADDR_WIDTH - MUSK_ADDR_WIDTH;
  
  localparam REG_ACCESS_SIZE = 11'h001;
  localparam D2D_ACCESS_SIZE = 11'h010;
  

wire    w_s_axis_cq_val_last;
assign  w_s_axis_cq_val_last = s_axis_cq_tvalid && s_axis_cq_tlast;

reg                           sr_s_axis_cq_tvalid;
reg        [C_DATA_WIDTH-1:0] sr_s_axis_cq_tdata;
reg          [KEEP_WIDTH-1:0] sr_s_axis_cq_tkeep;
reg                           sr_s_axis_cq_tlast;
reg [AXI4_CQ_TUSER_WIDTH-1:0] sr_s_axis_cq_tuser;

reg                           sr_s_axis_cq_tvalid_d1;
reg        [C_DATA_WIDTH-1:0] sr_s_axis_cq_tdata_d1;
reg          [KEEP_WIDTH-1:0] sr_s_axis_cq_tkeep_d1;
reg                           sr_s_axis_cq_tlast_d1;
reg [AXI4_CQ_TUSER_WIDTH-1:0] sr_s_axis_cq_tuser_d1;

reg  [ADDR_WIDTH-1:0] sr_m_axi_awaddr;
reg                   sr_m_axi_awvalid;
reg  [31:0]           sr_m_axi_wdata;
reg                   sr_m_axi_wvalid;
reg  [ADDR_WIDTH-1:0] sr_m_axi_araddr;
reg                   sr_m_axi_arvalid;

reg [C_DATA_WIDTH -1:0] sr_d2d_data;
reg                     sr_d2d_req_valid;
reg                     sr_d2d_ack_valid;

reg [511:0] sr_m_axis_cc_tdata;
reg         sr_m_axis_cc_tvalid;
reg  [15:0] sr_m_axis_cc_tkeep;

reg [127:0] sr_m_axi_header;

wire [127:0] w_s_axis_cq_tdata_hold;
wire         w_m_axis_cr_hold_fifo_empty;
wire         w_m_axis_cr_hold_fifo_full; // Not used

reg         sr_packet_between;
reg         sr_axis_cq_sop;
reg         sr_axis_cq_sop_d1;
reg  [10:0] sr_rq_size;
reg   [4:0] sr_rq_burst_size;
reg   [7:0] sr_rq_ch_id;

reg         sr_mem_direct_flag;

reg  [255:0]sr_req_ng_reply;
reg         sr_req_ng_reply_flag;

reg                     sr_m_axis_direct_tvalid;
reg  [C_DATA_WIDTH-1:0] sr_m_axis_direct_tdata;
reg    [KEEP_WIDTH-1:0] sr_m_axis_direct_tkeep;
reg                     sr_m_axis_direct_tlast;
reg              [15:0] sr_m_axis_direct_tuser;

reg    [4:0] sr_active_norep_request; //[0]:MEM_WD_REQ
                                      //[1]:ANY_MESSAGE 
                                      //[2]:V_D_MESSAGE 
                                      //[3]:ATS_MESSAGE 
                                      //[4]:REQ_RESERVED

wire w_user_ready_comb;
//assign w_user_ready_comb = &{m_axis_cc_tready
//                            ,m_axi_awready
//                            ,m_axi_wready
//                            ,m_axi_arready
//                            ,!w_m_axis_cr_hold_fifo_full};
assign w_user_ready_comb = &{m_axi_awready
                            ,m_axi_wready
                            ,m_axi_arready
                            ,!w_m_axis_cr_hold_fifo_full};

wire   w_req_busy;
//assign w_req_busy = (sr_m_axi_arvalid&&!m_axi_arready)||(sr_m_axi_wvalid&&!m_axi_wready)||((m_d2d_req_valid||m_d2d_ack_valid)&&!m_d2d_ready);
assign w_req_busy = (sr_m_axi_arvalid&&!m_axi_arready)||(sr_m_axi_wvalid&&!m_axi_wready);

wire   w_d2d_busy;
assign w_d2d_busy = (sr_d2d_req_valid || sr_d2d_ack_valid)&&!m_d2d_ready;

wire   w_men_direct_busy;
assign w_men_direct_busy = sr_m_axis_direct_tvalid && !m_axis_direct_tready;

wire m_axis_cc_busy;
assign m_axis_cc_busy = !m_axis_cc_tready && sr_m_axis_cc_tvalid;

wire   w_req_ng_reply_busy;
assign w_req_ng_reply_busy = sr_req_ng_reply_flag && m_axis_cc_busy;

wire   w_reg_read_reply_busy;
assign w_reg_read_reply_busy = sr_req_ng_reply_flag || m_axis_cc_busy;

wire [511:0] w_req_ng_reply;
wire [511:0] w_reg_read_reply;


function [15: 0] F_DWORD_CMB_KEEP (
  input [3:0] dword
  );
  begin
    case(dword)
      4'h0: F_DWORD_CMB_KEEP = 16'b1111_1111_1111_1111;
      4'h1: F_DWORD_CMB_KEEP = 16'b0000_0000_0000_0001;
      4'h2: F_DWORD_CMB_KEEP = 16'b0000_0000_0000_0011;
      4'h3: F_DWORD_CMB_KEEP = 16'b0000_0000_0000_0111;
      4'h4: F_DWORD_CMB_KEEP = 16'b0000_0000_0000_1111;
      4'h5: F_DWORD_CMB_KEEP = 16'b0000_0000_0001_1111;
      4'h6: F_DWORD_CMB_KEEP = 16'b0000_0000_0011_1111;
      4'h7: F_DWORD_CMB_KEEP = 16'b0000_0000_0111_1111;
      4'h8: F_DWORD_CMB_KEEP = 16'b0000_0000_1111_1111;
      4'h9: F_DWORD_CMB_KEEP = 16'b0000_0001_1111_1111;
      4'ha: F_DWORD_CMB_KEEP = 16'b0000_0011_1111_1111;
      4'hb: F_DWORD_CMB_KEEP = 16'b0000_0111_1111_1111;
      4'hc: F_DWORD_CMB_KEEP = 16'b0000_1111_1111_1111;
      4'hd: F_DWORD_CMB_KEEP = 16'b0001_1111_1111_1111;
      4'he: F_DWORD_CMB_KEEP = 16'b0011_1111_1111_1111;
      4'hf: F_DWORD_CMB_KEEP = 16'b0111_1111_1111_1111;
      default: F_DWORD_CMB_KEEP = 16'b1111_1111_1111_1111;
    endcase
  end
endfunction


// keep data before 1cycle for D2D,ACK
always @(posedge user_clk or negedge reset_n) begin
  if(~reset_n) begin
    sr_s_axis_cq_tvalid <= 1'b0;
    sr_s_axis_cq_tdata  <= {C_DATA_WIDTH{1'b0}};
    sr_s_axis_cq_tkeep  <= {KEEP_WIDTH{1'b0}};
    sr_s_axis_cq_tlast  <= 1'b0;
    sr_s_axis_cq_tuser  <= {AXI4_CQ_TUSER_WIDTH{1'b0}};
  end else begin
    // Stop when FIFO full or ready goes down
    if(!w_req_busy&&!w_d2d_busy&&!w_men_direct_busy&&!w_req_ng_reply_busy)begin
      if(s_axis_cq_tvalid)begin // Described with conditions for consideration of indefinite values
        sr_s_axis_cq_tvalid <= 1'b1;
      end else begin
        sr_s_axis_cq_tvalid <= 1'b0;
      end
      sr_s_axis_cq_tdata  <= s_axis_cq_tdata;
      sr_s_axis_cq_tkeep  <= s_axis_cq_tkeep;
      sr_s_axis_cq_tlast  <= s_axis_cq_tlast;
      sr_s_axis_cq_tuser  <= s_axis_cq_tuser;
    end else begin
      sr_s_axis_cq_tvalid <= sr_s_axis_cq_tvalid;
      sr_s_axis_cq_tdata  <= sr_s_axis_cq_tdata;
      sr_s_axis_cq_tkeep  <= sr_s_axis_cq_tkeep;
      sr_s_axis_cq_tlast  <= sr_s_axis_cq_tlast;
      sr_s_axis_cq_tuser  <= sr_s_axis_cq_tuser;
    end
  end
end

// 1 stage control
always @(posedge user_clk or negedge reset_n) begin
  if(~reset_n) begin
    sr_s_axis_cq_tvalid_d1 <= 1'b0;
    sr_s_axis_cq_tdata_d1  <= {C_DATA_WIDTH{1'b0}};
    sr_s_axis_cq_tkeep_d1  <= {KEEP_WIDTH{1'b0}};
    sr_s_axis_cq_tlast_d1  <= 1'b0;
    sr_s_axis_cq_tuser_d1  <= {AXI4_CQ_TUSER_WIDTH{1'b0}};
    sr_axis_cq_sop_d1      <= 1'b0;
  end else begin
    if((!sr_packet_between || sr_s_axis_cq_tvalid) &&!(w_req_busy||w_d2d_busy||w_men_direct_busy))begin //if(!sr_packet_between || sr_s_axis_cq_tvalid &&!(w_req_busy||w_d2d_busy||w_men_direct_busy))begin
      sr_s_axis_cq_tvalid_d1 <= sr_s_axis_cq_tvalid;
      sr_s_axis_cq_tdata_d1  <= sr_s_axis_cq_tdata;
      sr_s_axis_cq_tkeep_d1  <= sr_s_axis_cq_tkeep;
      sr_s_axis_cq_tlast_d1  <= sr_s_axis_cq_tlast && sr_s_axis_cq_tvalid;
      sr_s_axis_cq_tuser_d1  <= sr_s_axis_cq_tuser;
      sr_axis_cq_sop_d1      <= sr_axis_cq_sop && sr_s_axis_cq_tvalid;
    end else begin
      sr_s_axis_cq_tvalid_d1 <= sr_s_axis_cq_tvalid_d1;
      sr_s_axis_cq_tdata_d1  <= sr_s_axis_cq_tdata_d1;
      sr_s_axis_cq_tkeep_d1  <= sr_s_axis_cq_tkeep_d1;
      sr_s_axis_cq_tlast_d1  <= sr_s_axis_cq_tlast_d1;
      sr_s_axis_cq_tuser_d1  <= sr_s_axis_cq_tuser_d1;
      sr_axis_cq_sop_d1      <= sr_axis_cq_sop_d1;
    end
  end
end

// In-packet detection (for anti-bubble)
always @(posedge user_clk or negedge reset_n) begin
  if(~reset_n) begin
    sr_packet_between <= 1'b0;
  end else begin
    if(sr_s_axis_cq_tlast&&sr_s_axis_cq_tvalid)begin
      sr_packet_between <= 1'b0;
    end else if(sr_axis_cq_sop&&sr_s_axis_cq_tvalid)begin
      sr_packet_between <= 1'b1;
    end else begin
      sr_packet_between <= sr_packet_between;
    end
  end
end

// Start detection
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_axis_cq_sop <= 1'b1;
  end else begin
    if(sr_s_axis_cq_tlast && sr_s_axis_cq_tvalid && !(w_req_busy||w_d2d_busy||w_men_direct_busy))begin
      sr_axis_cq_sop <= 1'b1;
    end else begin
      if(sr_s_axis_cq_tvalid && !(w_req_busy||w_d2d_busy||w_men_direct_busy))begin
        sr_axis_cq_sop <= 1'b0;
      end else begin
        sr_axis_cq_sop <= sr_axis_cq_sop;
      end
    end
  end
end

// Signal Extraction
wire [63:0] w_rq_addr;
assign      w_rq_addr = {sr_s_axis_cq_tdata[63:2],2'h0};
wire [10:0] w_rq_size;
assign      w_rq_size = sr_s_axis_cq_tdata[74:64];
wire  [3:0] w_rq_type; // register read, register write, data transfer write, error detection
assign w_rq_type = sr_s_axis_cq_tdata[78:75];

wire  [8:0] w_rq_ch_id;
assign      w_rq_ch_id = sr_s_axis_cq_tdata[16:8] - 9'h0_20;

// Register access (read/write)
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_m_axi_awaddr  <= {ADDR_WIDTH{1'b0}}; 
    sr_m_axi_awvalid <= 1'b0;       
    sr_m_axi_wdata   <= {32{1'b0}}; 
    sr_m_axi_wvalid  <= 1'b0;       
    sr_m_axi_araddr  <= {ADDR_WIDTH{1'b0}}; 
    sr_m_axi_arvalid <= 1'b0;     
    sr_m_axi_header  <= {128{1'b0}};
  end else begin
    if(!w_req_busy)begin
      //write
      sr_m_axi_awaddr  <= {{MUSK_ADDR_WIDTH_REST{1'b0}},w_rq_addr[MUSK_ADDR_WIDTH-1:0]};
      sr_m_axi_awvalid <= !w_men_direct_busy&&sr_s_axis_cq_tvalid&&sr_axis_cq_sop&&(w_rq_type==MEM_WD_REQ)&&(w_rq_size==REG_ACCESS_SIZE)
                          &&!(w_rq_addr[ADDR_WIDTH-1:0]==AXIS_CC_ADDR_D2D[ADDR_WIDTH-1:0])
                          &&!(w_rq_addr[ADDR_WIDTH-1:0]==AXIS_CC_ADDR_ACK[ADDR_WIDTH-1:0])
                          &&!((w_rq_addr[ADDR_WIDTH-1:0]>=AXIS_CC_ADDR_DRC_MIN[ADDR_WIDTH-1:0])&&(w_rq_addr[ADDR_WIDTH-1:0]<=AXIS_CC_ADDR_DRC_MAX[ADDR_WIDTH-1:0])); // addresses to D2D, ACK and DRC are not applicable
      sr_m_axi_wdata   <= sr_s_axis_cq_tdata[159:128];
      sr_m_axi_wvalid  <= !w_men_direct_busy&&sr_s_axis_cq_tvalid&&sr_axis_cq_sop&&(w_rq_type==MEM_WD_REQ)&&(w_rq_size==REG_ACCESS_SIZE)
                          &&!(w_rq_addr[ADDR_WIDTH-1:0]==AXIS_CC_ADDR_D2D[ADDR_WIDTH-1:0])
                          &&!(w_rq_addr[ADDR_WIDTH-1:0]==AXIS_CC_ADDR_ACK[ADDR_WIDTH-1:0])
                          &&!((w_rq_addr[ADDR_WIDTH-1:0]>=AXIS_CC_ADDR_DRC_MIN[ADDR_WIDTH-1:0])&&(w_rq_addr[ADDR_WIDTH-1:0]<=AXIS_CC_ADDR_DRC_MAX[ADDR_WIDTH-1:0])); // addresses to D2D, ACK and DRC are not applicable
      //read
      sr_m_axi_araddr  <= {{MUSK_ADDR_WIDTH_REST{1'b0}},w_rq_addr[MUSK_ADDR_WIDTH-1:0]};
      sr_m_axi_arvalid <= !w_men_direct_busy&&sr_s_axis_cq_tvalid&&sr_axis_cq_sop&&(w_rq_type==MEM_RD_REQ)&&(w_rq_size==REG_ACCESS_SIZE);
      sr_m_axi_header  <= sr_s_axis_cq_tdata[127:0];
    end else begin //BP HOLD
      sr_m_axi_awaddr  <= sr_m_axi_awaddr;
      sr_m_axi_awvalid <= sr_m_axi_awvalid;
      sr_m_axi_wdata   <= sr_m_axi_wdata;
      sr_m_axi_wvalid  <= sr_m_axi_wvalid;
      sr_m_axi_araddr  <= sr_m_axi_araddr;
      sr_m_axi_arvalid <= sr_m_axi_arvalid;
      sr_m_axi_header  <= sr_m_axi_header;
    end
  end
end

assign m_axi_awprot     = 3'h0;
assign m_axi_wstrb      = 4'hf;
assign m_axi_arprot     = 3'h0;
assign m_axi_bready     = m_axis_cc_tready;
assign s_axis_cq_tready = !(w_req_busy||w_d2d_busy||w_men_direct_busy);
assign m_axi_awaddr     = sr_m_axi_awaddr;
assign m_axi_awvalid    = sr_m_axi_awvalid;
assign m_axi_wdata      = sr_m_axi_wdata;
assign m_axi_wvalid     = sr_m_axi_wvalid;
assign m_axi_araddr     = sr_m_axi_araddr;
assign m_axi_arvalid    = sr_m_axi_arvalid;
assign m_axi_rready     = !w_reg_read_reply_busy && !w_m_axis_cr_hold_fifo_empty;

// read response FIFO
    design_1_fifo_generator_0_0 m_axis_cr_hold_fifo(
          .clk         (user_clk                          ),
          .din         (sr_m_axi_header                   ),
          .dout        (w_s_axis_cq_tdata_hold            ),
          .empty       (w_m_axis_cr_hold_fifo_empty       ),
          .full        (w_m_axis_cr_hold_fifo_full        ), 
          .rd_en       (m_axi_rvalid && !w_reg_read_reply_busy && !w_m_axis_cr_hold_fifo_empty ),
          .rd_rst_busy (                                  ), // Not used
          .srst        (!reset_n                          ),
          .wr_en       (sr_m_axi_arvalid&&!w_req_busy     ),
          .wr_rst_busy (                                  )  // Not used
          );

// D2D,ACK
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_d2d_data      <= {C_DATA_WIDTH{1'b0}};
    sr_d2d_req_valid <= 1'b0;
    sr_d2d_ack_valid <= 1'b0;
  end else begin
    if(!w_d2d_busy)begin
      sr_d2d_data      <= {s_axis_cq_tdata[127:0],sr_s_axis_cq_tdata[511:128]};
      sr_d2d_req_valid <= sr_s_axis_cq_tvalid && sr_axis_cq_sop && (w_rq_type==MEM_WD_REQ)&&(w_rq_size==D2D_ACCESS_SIZE)&&(w_rq_addr[MUSK_ADDR_WIDTH-1:0]==AXIS_CC_ADDR_D2D[MUSK_ADDR_WIDTH-1:0]);
      sr_d2d_ack_valid <= sr_s_axis_cq_tvalid && sr_axis_cq_sop && (w_rq_type==MEM_WD_REQ)&&(w_rq_size==D2D_ACCESS_SIZE)&&(w_rq_addr[MUSK_ADDR_WIDTH-1:0]==AXIS_CC_ADDR_ACK[MUSK_ADDR_WIDTH-1:0]);
    end else begin
      sr_d2d_data      <= sr_d2d_data;
      sr_d2d_req_valid <= sr_d2d_req_valid;
      sr_d2d_ack_valid <= sr_d2d_ack_valid;
    end
  end
end

//size latch(timing:d1)
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_rq_size       <= {11{1'b0}};
    sr_rq_burst_size <= {5{1'b0}};
    sr_rq_ch_id      <= {8{1'b0}};
  end else begin
    if((sr_axis_cq_sop && sr_s_axis_cq_tvalid)&&!(w_req_busy||w_d2d_busy||w_men_direct_busy))begin
      sr_rq_size       <= w_rq_size;
      sr_rq_burst_size <= w_rq_size[8:4]+|w_rq_size[3:0];
      sr_rq_ch_id      <= {3'b0,w_rq_ch_id[6:2]};
    end else begin
      sr_rq_size       <= sr_rq_size;
      sr_rq_burst_size <= sr_rq_burst_size;
      sr_rq_ch_id      <= sr_rq_ch_id;
    end
  end
end

//MEM Direct Select
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_mem_direct_flag <= 1'b0;
  end else begin
    // ON at sop, OFF at eop
    if(sr_axis_cq_sop && sr_s_axis_cq_tvalid&&!(w_req_busy||w_d2d_busy||w_men_direct_busy))begin
      if((w_rq_type==MEM_WD_REQ)&&((w_rq_addr[MUSK_ADDR_WIDTH-1:0]>=AXIS_CC_ADDR_DRC_MIN[MUSK_ADDR_WIDTH-1:0])&&(w_rq_addr[MUSK_ADDR_WIDTH-1:0]<=AXIS_CC_ADDR_DRC_MAX[MUSK_ADDR_WIDTH-1:0])))begin
        sr_mem_direct_flag <= 1'b1;
      end else begin
        sr_mem_direct_flag <= 1'b0;
      end
    //end else if(sr_s_axis_cq_tlast_d1&&!(w_req_busy||w_d2d_busy||w_men_direct_busy))begin // Excess BP
    end else if(sr_s_axis_cq_tlast_d1&&!w_men_direct_busy)begin
      sr_mem_direct_flag <= 1'b0;
    end else begin
      sr_mem_direct_flag <= sr_mem_direct_flag;
    end
  end
end

// MEM Direct
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_m_axis_direct_tvalid <= 1'b0;
    sr_m_axis_direct_tdata  <= {C_DATA_WIDTH{1'b0}};
    //sr_m_axis_direct_tkeep  <= {KEEP_WIDTH{1'b0}};
    //sr_m_axis_direct_tlast  <= 1'b0;
    sr_m_axis_direct_tuser  <= {16{1'b0}};
  end else begin
    if(!w_men_direct_busy)begin
      if(sr_mem_direct_flag)begin
        sr_m_axis_direct_tdata  <= {sr_s_axis_cq_tdata[127:0],sr_s_axis_cq_tdata_d1[511:128]};
        //sr_m_axis_direct_tkeep  <= F_DWORD_CMB_KEEP(sr_rq_size[3:0]);
        //sr_m_axis_direct_tuser  <= sr_axis_cq_sop_d1;
        if(sr_rq_size[3:0]>=4'hd || sr_rq_size[3:0]==4'h0)begin
          // When the active time becomes shorter by 1 cycle
          //sr_m_axis_direct_tvalid <= sr_axis_cq_sop_d1||!sr_s_axis_cq_tlast_d1;
          sr_m_axis_direct_tvalid <= !sr_s_axis_cq_tlast_d1 && sr_s_axis_cq_tvalid_d1 && (sr_s_axis_cq_tvalid || !sr_packet_between); // Anti-bubble
          //sr_m_axis_direct_tlast  <= sr_s_axis_cq_tlast;
          sr_m_axis_direct_tuser  <= {sr_rq_ch_id            //[15:8]CH_ID[7:0](Translated from address)
                                         ,sr_axis_cq_sop_d1      //   [7]SOP
                                         ,sr_s_axis_cq_tlast     //   [6]EOP
                                         ,1'b0                   //   [5]reserved
                                         ,sr_rq_burst_size   };  // [4:0]burst[4:0](number of cycles)
        end else begin
          //sr_m_axis_direct_tvalid <= 1'b1;
          sr_m_axis_direct_tvalid <= sr_s_axis_cq_tvalid_d1 && (sr_s_axis_cq_tvalid || !sr_packet_between); // Anti-bubble
          //sr_m_axis_direct_tlast  <= sr_s_axis_cq_tlast_d1;
          sr_m_axis_direct_tuser  <= {sr_rq_ch_id            //[15:8]CH_ID[7:0](Translated from address)
                                         ,sr_axis_cq_sop_d1      //   [7]SOP
                                         ,sr_s_axis_cq_tlast_d1  //   [6]EOP
                                         ,1'b0                   //   [5]reserved
                                         ,sr_rq_burst_size   };  // [4:0]burst[4:0](number of cycles)
        end
      end else begin
        sr_m_axis_direct_tvalid <= 1'b0;
        //sr_m_axis_direct_tlast  <= 1'b0;
      end
    end else begin
      sr_m_axis_direct_tvalid <= sr_m_axis_direct_tvalid;
      sr_m_axis_direct_tdata  <= sr_m_axis_direct_tdata;
      //sr_m_axis_direct_tkeep  <= sr_m_axis_direct_tkeep;
      //sr_m_axis_direct_tlast  <= sr_m_axis_direct_tlast;
      sr_m_axis_direct_tuser  <= sr_m_axis_direct_tuser;
    end
  end
end

// No response request detection
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_active_norep_request <= {5{1'b0}};
  end else begin
    if(!(w_req_busy||w_d2d_busy||w_men_direct_busy))begin
      sr_active_norep_request[0] <= sr_axis_cq_sop && sr_s_axis_cq_tvalid && (w_rq_type==MEM_WD_REQ);
      sr_active_norep_request[1] <= sr_axis_cq_sop && sr_s_axis_cq_tvalid && (w_rq_type==ANY_MESSAGE);
      sr_active_norep_request[2] <= sr_axis_cq_sop && sr_s_axis_cq_tvalid && (w_rq_type==V_D_MESSAGE);
      sr_active_norep_request[3] <= sr_axis_cq_sop && sr_s_axis_cq_tvalid && (w_rq_type==ATS_MESSAGE);
      sr_active_norep_request[4] <= sr_axis_cq_sop && sr_s_axis_cq_tvalid && (w_rq_type==REQ_RESERVED);
    end else begin
      sr_active_norep_request <= sr_active_norep_request;
    end
  end
end

// NG request response content
assign w_req_ng_reply  = {256'h0,                          // [511:256] reserved
                          sr_s_axis_cq_tdata_d1[127:0],    // [255:128] cq_discripter
                          8'h0,                            // [127:120] reserved
                          sr_s_axis_cq_tuser_d1[52:45],    // [119:112] tph_st_tag
                          5'h0,                            // [111:107] reserved
                          sr_s_axis_cq_tuser_d1[44:42],    // [106:104] tph_type[1:0],tph_present[0]
                          sr_s_axis_cq_tuser_d1[7:0],      // [103: 96] last_be[3:0],first_be[3:0]
                          1'h0,                            // [     95] reserved
                          3'h0,                            // [ 94: 92] Attribute
                          sr_s_axis_cq_tdata_d1[123:121],  // [ 91: 89] TC
                          1'h0,                            // [     88] Completer ID Enable
                          8'h0,                            // [ 87: 80] Completer Bus Number
                          sr_s_axis_cq_tdata_d1[111:104],  // [ 79: 72] Target Function
                          sr_s_axis_cq_tdata_d1[103:96],   // [ 71: 64] Tag
                          sr_s_axis_cq_tdata_d1[95:80],    // [ 63: 48] Requester ID
                          1'h0,                            // [     47] reserved
                          1'h0,                            // [     46] Poisoned Completion
                          3'b001,                          // [ 45: 43] Completion Status
                          11'h008,                         // [ 42: 32] This Packet Payload Size(DW)
                          2'h0,                            // [ 31: 30] reserved
                          1'h0,                            // [     29] Locked Read Completion
                          13'h0020,                        // [ 28: 16] Payload Size(byte)
                          6'h0,                            // [ 15: 10] reserved
                          sr_s_axis_cq_tdata_d1[1:0],      // [  9:  8] Adress Type
                          1'h0,                            // [      7] reserved
                          sr_s_axis_cq_tdata_d1[6:2],      // [  6:  2] Address
                          2'h0 };                          // [  1:  0] Address

// NG response generation
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_req_ng_reply      <= {256{1'b0}};
    sr_req_ng_reply_flag <= 1'b0;
  end else begin
    sr_req_ng_reply      <= w_req_ng_reply[255:0];
    //sr_req_ng_reply_flag <= sr_axis_cq_sop_d1 && !(sr_m_axi_awvalid||sr_m_axi_arvalid||sr_d2d_req_valid||sr_d2d_ack_valid||sr_mem_direct_flag); // Respond to all unsupported requests.
    sr_req_ng_reply_flag <= sr_axis_cq_sop_d1 && !(sr_m_axi_arvalid || (|sr_active_norep_request)); // Respond only if a response is required
  end
end

// Register read response
assign w_reg_read_reply = {384'h0,                         // [511:128] reserved
                          m_axi_rdata,                     // [127: 96] Payload
                          1'h0,                            // [     95] reserved
                          3'h0,                            // [ 94: 92] Attribute
                          w_s_axis_cq_tdata_hold[123:121], // [ 91: 89] TC
                          1'h0,                            // [     88] Completer ID Enable
                          8'h0,                            // [ 87: 80] Completer Bus Number
                          w_s_axis_cq_tdata_hold[111:104], // [ 79: 72] Target Function
                          w_s_axis_cq_tdata_hold[103:96],  // [ 71: 64] Tag
                          w_s_axis_cq_tdata_hold[95:80],   // [ 63: 48] Requester ID
                          1'h0,                            // [     47] reserved
                          1'h0,                            // [     46] Poisoned Completion
                          3'h0,                            // [ 45: 43] Completion Status
                          11'h001,                         // [ 42: 32] This Packet Payload Size(DW)
                          2'h0,                            // [ 31: 30] reserved
                          1'h0,                            // [     29] Locked Read Completion
                          13'h0004,                        // [ 28: 16] Payload Size(byte)
                          6'h0,                            // [ 15: 10] reserved
                          w_s_axis_cq_tdata_hold[1:0],     // [  9:  8] Adress Type
                          1'h0,                            // [      7] reserved
                          w_s_axis_cq_tdata_hold[6:2],     // [  6:  2] Address
                          2'h0 };                          // [  1:  0] Address

// AXI4-Lite Conversion
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_m_axis_cc_tdata  <= {512{1'b0}};
    sr_m_axis_cc_tvalid <= 1'b0;
    sr_m_axis_cc_tkeep  <= 16'h000f;
  end else begin
    if(!m_axis_cc_busy)begin
      if(sr_req_ng_reply_flag)begin
        sr_m_axis_cc_tdata  <= {{256{1'b0}},sr_req_ng_reply};
        sr_m_axis_cc_tvalid <= 1'b1;
        sr_m_axis_cc_tkeep  <= 16'h00ff;
      end else if(m_axi_rvalid && !w_m_axis_cr_hold_fifo_empty)begin
        sr_m_axis_cc_tdata  <= w_reg_read_reply;
        sr_m_axis_cc_tvalid <= 1'b1;
        sr_m_axis_cc_tkeep  <= 16'h000f;
      end else begin
        sr_m_axis_cc_tdata  <= sr_m_axis_cc_tdata;
        sr_m_axis_cc_tvalid <= 1'b0;
        sr_m_axis_cc_tkeep  <= sr_m_axis_cc_tkeep;
      end
    end else begin
      sr_m_axis_cc_tdata  <= sr_m_axis_cc_tdata;
      sr_m_axis_cc_tvalid <= sr_m_axis_cc_tvalid;
      sr_m_axis_cc_tkeep  <= sr_m_axis_cc_tkeep;
    end
  end
end

//assign m_axis_cc_tvalid = sr_m_axis_cc_tvalid & m_axis_cc_tready;
assign m_axis_cc_tvalid = sr_m_axis_cc_tvalid;
assign m_axis_cc_tdata  = sr_m_axis_cc_tdata;
assign m_axis_cc_tlast  = 1'b1;
assign m_axis_cc_tkeep  = sr_m_axis_cc_tkeep;
assign m_axis_cc_tuser  = 81'h1;

assign m_d2d_data      = sr_d2d_data;
assign m_d2d_req_valid = sr_d2d_req_valid;
assign m_d2d_ack_valid = sr_d2d_ack_valid;

assign m_axis_direct_tvalid = sr_m_axis_direct_tvalid;
assign m_axis_direct_tdata  = sr_m_axis_direct_tdata;
//assign m_axis_direct_tkeep  = sr_m_axis_direct_tkeep;
//assign m_axis_direct_tlast  = sr_m_axis_direct_tlast;
assign m_axis_direct_tuser  = sr_m_axis_direct_tuser;

endmodule
