/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module checker_axi_lite_end_point #(
  parameter integer ADDR_WIDTH = 17, //! address bit width
  parameter integer DATA_WIDTH = 32, //! data bit width
  parameter integer STRB_WIDTH = (DATA_WIDTH+7)/8 //! Width of the STRB signal
) (
  input   wire                  aclk          , //! system clock
  input   wire                  resetn        , //! System Reset (synchronizing negative logic)
  
  input   wire[ADDR_WIDTH-1:0]  s_axi_araddr  , //! AXI4-Lite ARADDR 
  input   wire                  s_axi_arvalid , //! AXI4-Lite ARVALID
  output  wire                  s_axi_arready , //! AXI4-Lite ARREADY
  output  wire[DATA_WIDTH-1:0]  s_axi_rdata   , //! AXI4-Lite RDATA  
  output  wire[1:0]             s_axi_rresp   , //! AXI4-Lite RRESP  
  output  wire                  s_axi_rvalid  , //! AXI4-Lite RVALID 
  input   wire                  s_axi_rready  , //! AXI4-Lite RREADY 
  input   wire[ADDR_WIDTH-1:0]  s_axi_awaddr  , //! AXI4-Lite AWADDR 
  input   wire                  s_axi_awvalid , //! AXI4-Lite AWVALID
  output  wire                  s_axi_awready , //! AXI4-Lite AWREADY
  input   wire[DATA_WIDTH-1:0]  s_axi_wdata   , //! AXI4-Lite WDATA  
  input   wire[STRB_WIDTH-1:0]  s_axi_wstrb   , //! AXI4-Lite WSTRB  
  input   wire                  s_axi_wvalid  , //! AXI4-Lite WVALID 
  output  wire                  s_axi_wready  , //! AXI4-Lite WREADY 
  output  wire[1:0]             s_axi_bresp   , //! AXI4-Lite BRESP  
  output  wire                  s_axi_bvalid  , //! AXI4-Lite BVALID 
  input   wire                  s_axi_bready  , //! AXI4-Lite BREADY 

  output  wire[ADDR_WIDTH-1:0]  local_addr    , //! local bus address
  output  wire                  local_wr_en   , //! Local Bus Write Enabled
  output  wire[DATA_WIDTH-1:0]  local_wr_data , //! Local bus write data
  input   wire                  local_wr_ack  , //! Local Bus Write Response
  output  wire                  local_rd_en   , //! Local Bus Read Enabled
  input   wire[DATA_WIDTH-1:0]  local_rd_data , //! Local bus read data
  input   wire                  local_rd_ack    //! local bus read response
);

  // Read address handshake
  wire w_araddr_acpt;
  wire w_araddr_busy;

  checker_axi_lite_channel_handshake handshake_ar (
    .aclk           (aclk         ), // input
    .resetn         (resetn       ), // input
    .axi_req_valid  (s_axi_arvalid), // input
    .axi_req_ready  (s_axi_arready), // output
    .axi_resp_valid (s_axi_rvalid ), // output
    .axi_resp_ready (s_axi_rready ), // input
    .local_acpt     (w_araddr_acpt), // output
    .local_busy     (w_araddr_busy), // output
    .local_done     (local_rd_ack )  // input
  );
  reg[ADDR_WIDTH-1:0] r_araddr;
  always @(posedge aclk) begin
    if ( ! resetn) begin
      r_araddr <= {ADDR_WIDTH{1'b0}};
    end else if (w_araddr_acpt) begin
      r_araddr <= s_axi_araddr;
    end
  end

  // write address handshake
  wire w_awaddr_acpt;
  wire w_awaddr_busy;

  checker_axi_lite_channel_handshake handshake_aw (
    .aclk           (aclk         ), // input
    .resetn         (resetn       ), // input
    .axi_req_valid  (s_axi_awvalid), // input
    .axi_req_ready  (s_axi_awready), // output
    .axi_resp_valid (s_axi_bvalid ), // output
    .axi_resp_ready (s_axi_bready ), // input
    .local_acpt     (w_awaddr_acpt), // output
    .local_busy     (w_awaddr_busy), // output
    .local_done     (local_wr_ack )  // input
  );
  reg[ADDR_WIDTH-1:0] r_awaddr;
  always @(posedge aclk) begin
    if ( ! resetn) begin
      r_awaddr <= {ADDR_WIDTH{1'b0}};
    end else if (w_awaddr_acpt) begin
      r_awaddr <= s_axi_awaddr;
    end
  end

  // Write Data Handshake
  wire w_wdata_busy;
  wire w_wdata_acpt;
  checker_axi_lite_channel_handshake handshake_w (
    .aclk           (aclk         ), // input
    .resetn         (resetn       ), // input
    .axi_req_valid  (s_axi_wvalid ), // input
    .axi_req_ready  (s_axi_wready ), // output
    .axi_resp_valid (             ), // output
    .axi_resp_ready (1'b1         ), // input
    .local_acpt     (w_wdata_acpt ), // output
    .local_busy     (w_wdata_busy ), // output
    .local_done     (local_wr_ack )  // input
  );
  reg[DATA_WIDTH-1:0] r_wdata;
  always @(posedge aclk) begin
    if ( ! resetn) begin
      r_wdata <= {DATA_WIDTH{1'b0}};
    end else if (w_wdata_acpt) begin
      r_wdata <= s_axi_wdata;
    end
  end

  wire w_waw_busy = w_awaddr_busy & w_wdata_busy;

  // Arbiter State
  typedef enum {
    IDLE , //! Waiting
    READ , //! Reading in progress
    WRITE  //! Writing in progress
  } state_t;
  
  // State Machine (Arbiter)
  state_t r_state;
  wire w_local_wr_en = (r_state == IDLE) && w_waw_busy;
  wire w_local_rd_en = (r_state == IDLE) && w_araddr_busy && ~ w_waw_busy;
  always @(posedge aclk) begin
    if ( ! resetn) begin
      r_state <= IDLE;
    end else begin
      case (r_state)
      IDLE:
        if (w_waw_busy) begin
          r_state <= WRITE;
        end else if (w_araddr_busy) begin
          r_state <= READ;
        end
      READ:
        if (local_rd_ack) begin
          r_state <= IDLE;
        end
      WRITE:
        if (local_wr_ack) begin
          r_state <= IDLE;
        end
      default:
        begin
          r_state <= IDLE;
        end
      endcase
    end
  end
  
  // Local Bus I/F
  reg r_local_wr_en;
  reg r_local_rd_en;
  always @(posedge aclk) begin
    if ( ! resetn) begin
      r_local_wr_en <= 1'b0;
      r_local_rd_en <= 1'b0;
    end else begin
      r_local_wr_en <= w_local_wr_en;
      r_local_rd_en <= w_local_rd_en;
    end
  end
  assign local_addr     = (r_state == WRITE) ? r_awaddr : r_araddr;
  assign local_wr_en    = r_local_wr_en;
  assign local_wr_data  = r_wdata;
  assign local_rd_en    = r_local_rd_en;

  // AXI4-Lite Response I/F
  reg[DATA_WIDTH-1:0] r_rdata;
  always @(posedge aclk) begin
    if ( ! resetn) begin
      r_rdata <= {DATA_WIDTH{1'b0}};
    end else if (local_rd_ack) begin
      r_rdata <= local_rd_data;
    end
  end
  assign s_axi_bresp = 2'b00; // 2b00 = OKAY
  assign s_axi_rresp = 2'b00; // 2b00 = OKAY
  assign s_axi_rdata = r_rdata;
  
endmodule

//! Manage transaction start and end with valid/ready
module checker_axi_lite_channel_handshake(
  input   wire  aclk          , //! system clock
  input   wire  resetn        , //! System Reset (synchronizing negative logic)
  input   wire  axi_req_valid , //! AXI request Valid
  output  wire  axi_req_ready , //! AXI Request Ready
  output  wire  axi_resp_valid, //! AXI Response Valid
  input   wire  axi_resp_ready, //! AXI Response Ready
  output  wire  local_acpt    , //! Local Bus Transaction Start
  output  wire  local_busy    , //! Local bus transaction in progress
  input   wire  local_done      //! Local Bus Completion Notification
);
  
  typedef enum {
    RESET, //! Resetting
    READY, //! Waiting for Request
    BUSY,  //! Transaction in progress
    RESP   //! Answering
  } state_t;
  
  state_t r_state;
  wire w_acpt = (r_state == READY) && axi_req_valid;
  always @(posedge aclk) begin
    if ( ! resetn) begin
      r_state <= RESET;
    end else begin
      case (r_state)
      RESET:
        begin
          r_state <= READY;
        end
      READY:
        if (w_acpt) begin
          r_state <= BUSY;
        end
      BUSY:
        if (local_done) begin
          r_state <= RESP;
        end
      RESP:
        if (axi_resp_ready) begin
          r_state <= READY;
        end
      default:
        begin
          r_state <= RESET;
        end
      endcase
    end
  end

  assign axi_req_ready  = (r_state == READY);
  assign axi_resp_valid = (r_state == RESP);

  assign local_acpt = w_acpt;
  assign local_busy = (r_state == BUSY) || w_acpt;

endmodule

