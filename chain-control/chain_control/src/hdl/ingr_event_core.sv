/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

//`define INGR_EVENT_DEBUG_DISPLAY

module ingr_event_core (
  input   wire        ap_clk,
  input   wire        ap_rst_n,
  input   wire[63:0]  estab_0_tdata,  // ptrUpdateReq
  input   wire        estab_0_tvalid,
  output  wire        estab_0_tready,
  input   wire[63:0]  estab_1_tdata,  // ptrUpdateReq
  input   wire        estab_1_tvalid,
  output  wire        estab_1_tready,
  input   wire[63:0]  rcv_nxt_upd_0_tdata,  // ptrUpdateReq
  input   wire        rcv_nxt_upd_0_tvalid,
  output  wire        rcv_nxt_upd_0_tready,
  input   wire[63:0]  rcv_nxt_upd_1_tdata,  // ptrUpdateReq
  input   wire        rcv_nxt_upd_1_tvalid,
  output  wire        rcv_nxt_upd_1_tready,
  input   wire[63:0]  usr_read_upd_tdata,  // ptrUpdateReq
  input   wire        usr_read_upd_tvalid,
  output  wire        usr_read_upd_tready,
  input   wire[39:0]  payload_len_tdata,
  input   wire        payload_len_tvalid,
  output  wire        payload_len_tready,
  input   wire[7:0]   start_tdata,
  input   wire        start_tvalid,
  output  wire        start_tready,
  output  wire[7:0]   done_tdata,
  output  wire        done_tvalid,
  input   wire        done_tready,
  output  wire[135:0] receive_tdata,  // sessionPtr
  output  wire        receive_tvalid,
  input   wire        receive_tready,
  input   wire[47:0]  header_buff_usage,
  input   wire        header_buff_usage_vld,
  output  wire[47:0]  stat_rcv_data,
  output  wire        stat_rcv_data_vld,
  output  wire[15:0]  rcv_detect_fault,
  output  wire        rcv_detect_fault_vld,
  input   wire[7:0]   rcv_insert_fault,
  output  wire[31:0]  rcv_nxt_upd_count,
  output  wire[31:0]  usr_read_upd_count,
  output  wire[31:0]  rx_hp_upd_count,
  output  wire[31:0]  rx_tp_upd_count,
  input   wire[15:0]  dbg_sel_session,
  input   wire[15:0]  stat_sel_session,
  output  wire[1:0]   extif_session_status,
  output  wire[127:0] last_ptr
);

  localparam int NUM_INDEX  = 1024;                 // Number of index = external IF count * CID count
  localparam int NUM_BANK   = 32;                   // Number of RAM
  localparam int NUM_GROUP  = NUM_INDEX / NUM_BANK; // Number of groups

  localparam int INDEX_WIDTH= $clog2(NUM_INDEX);    // Index bit width
  localparam int BANK_WIDTH = $clog2(NUM_BANK);     // Bank number bit width
  localparam int ADDR_WIDTH = $clog2(NUM_GROUP);    // RAM address bit width

  localparam int PTR_WIDTH  = 32; // Pointer bit width

  localparam int PAYLEN_WIDTH = 32; // Payload length bit width
  
  localparam int VALID_UPD_DELAY  = 3; // Valid update delay amount

  localparam int HEADER_LEN = 48; // Header length
  
  // Table update operation type
  typedef enum logic[7:0] {
    TABLE_OP_INSERT = 0,
    TABLE_OP_DELETE = 1
  } tableOp;
  
  // Source of the table update request
  typedef enum logic[7:0] {
    SRC_ESTAB       = 0,
    SRC_RCV_NXT     = 1,
    SRC_USR_READ    = 2,
    SRC_PAYLOAD_LEN = 3
  } accessSource;

  // Table update request parameters
  typedef struct packed {
    logic[PTR_WIDTH-1:0]  ptr;    // [63:32] ptr (rcv_nxt/usr_read)
    logic[15:0]           index;  // [31:16] {ifid, cid}
    tableOp               op;     // [15: 8] 0:INSERT, 1:DELETE (valid only for the lower 1 bit)
    accessSource          source; // [ 7: 0] Not used for external I/F
  } ptrUpdateReq;

  // Receive request parameters
  typedef struct packed {
    logic[ 2:0]             reserved0;  // [135:133] reserved
    logic                   direct;     // [132] Direct Transfer Flag
    logic                   discard;    // [131] Discard flag
    logic                   eof;        // [130] eof flag
    logic                   sof;        // [129] sof flag
    logic                   head;       // [128] head flag
    logic[PAYLEN_WIDTH-1:0] payload_len;// [127:96] Payload length (valid when sof=1)
    logic[PTR_WIDTH-1:0]    usr;        // [95:64] usr_read/rx_tail
    logic[PTR_WIDTH-1:0]    ext;        // [63:32] rcv_nxt/rx_head
    logic[15:0]             channel;    // [31:16] Not used for external I/F (0x0000)
    logic[15:0]             index;      // [15: 0] {ifid, cid}
  } sessionPtr;

  // Table entry
  typedef struct packed {
    logic                 parity; // [32] Parity
    logic[PTR_WIDTH-1:0]  ptr;    // [31:0] Pointer
  } tableEntry;
  
  // State
  typedef enum {
    ST_RESET,
    ST_WAIT_RR,
    ST_POP_INGR_START,
    ST_PUSH_RECEIVE,
    ST_POP_USR_READ,
    ST_POP_PAYLOAD_LEN,
    ST_PUSH_DONE
  } State;

  // Stream accept clock enable
  wire w_input_clken;

  // CID Valid flag table signal
  wire[NUM_BANK-1:0]    w_cidvld_wr_en;
  wire[ADDR_WIDTH-1:0]  w_cidvld_wr_addr;
  wire                  w_cidvld_wr_data;
  wire[ADDR_WIDTH-1:0]  w_cidvld_rr_rd_addr;
  wire[NUM_BANK-1:0]    w_cidvld_rr_rd_data;

  // SOF flag table signal
  reg[NUM_BANK-1:0]     r_sof_wr_en;
  reg[ADDR_WIDTH-1:0]   r_sof_wr_addr;
  reg                   r_sof_wr_data;
  wire[ADDR_WIDTH-1:0]  w_sof_rd_addr;
  wire[NUM_BANK-1:0]    w_sof_rd_data;

  // Header buffer B.P. table signal
  wire[NUM_BANK-1:0]    w_bp_wr_en;
  wire[ADDR_WIDTH-1:0]  w_bp_wr_addr;
  wire                  w_bp_wr_data;
  wire[ADDR_WIDTH-1:0]  w_bp_rd_addr;
  wire[NUM_BANK-1:0]    w_bp_rd_data;

  // Discard flag table signal
  wire[NUM_BANK-1:0]    w_dis_wr_en;
  wire[ADDR_WIDTH-1:0]  w_dis_wr_addr;
  wire                  w_dis_wr_data;
  wire[ADDR_WIDTH-1:0]  w_dis_rd_addr;
  wire[NUM_BANK-1:0]    w_dis_rd_data;

  // rcv_nxt_table signal
  wire[NUM_BANK-1:0]    w_rn_wr_en;
  wire[ADDR_WIDTH-1:0]  w_rn_wr_addr;
  tableEntry            w_rn_wr_data;
  wire                  w_rn_rd_en;
  wire[ADDR_WIDTH-1:0]  w_rn_rd_addr;
  tableEntry            w_rn_rd_data[0:NUM_BANK-1];

  // usr_read_table signal
  wire[NUM_BANK-1:0]    w_ur_wr_en;
  wire[ADDR_WIDTH-1:0]  w_ur_wr_addr;
  tableEntry            w_ur_wr_data;
  wire                  w_ur_rd_en;
  wire[ADDR_WIDTH-1:0]  w_ur_rd_addr;
  tableEntry            w_ur_rd_data[0:NUM_BANK-1];

  // head_ptr_table signal
  wire[NUM_BANK-1:0]    w_hp_wr_en;
  wire[ADDR_WIDTH-1:0]  w_hp_wr_addr;
  tableEntry            w_hp_wr_data;
  wire                  w_hp_rd_en;
  wire[ADDR_WIDTH-1:0]  w_hp_rd_addr;
  tableEntry            w_hp_rd_data[0:NUM_BANK-1];
  
  // Round-robin control signal
  wire w_found_ready;
  wire w_found_valid;
  wire[INDEX_WIDTH-1:0] w_found_idx;
  wire[PTR_WIDTH-1:0] w_found_ext;
  wire[PTR_WIDTH-1:0] w_found_usr;
  wire[PAYLEN_WIDTH-1:0] w_found_payload_len;
  wire w_found_head;
  wire w_found_sof;
  wire w_found_eof;
  wire w_found_dis;
  
  // CID Valid table initialization control signal
  reg r_table_init_done;
  reg[INDEX_WIDTH-1:0] r_table_init_addr;
  
  // head and usr_read latches
  reg r_lat_head;
  reg[INDEX_WIDTH-1:0] r_lat_idx;
  reg[PTR_WIDTH-1:0] r_lat_usr;
  
  //------------------------------------------------
  // Arbitrate estab #0/#1 (#0 side priority)
  wire w_estab_tready;
  wire w_estab_0_tready, w_estab_1_tready;
  wire w_estab_tvalid = estab_0_tvalid | estab_1_tvalid;
  assign w_estab_0_tready = w_estab_tready;
  assign w_estab_1_tready = w_estab_tready & ~ estab_0_tvalid;
  assign estab_0_tready = w_estab_0_tready;
  assign estab_1_tready = w_estab_1_tready;

  ptrUpdateReq w_estab_tdata;
  always_comb begin
    if (estab_0_tvalid) begin
      w_estab_tdata = estab_0_tdata;
    end else if (estab_1_tvalid) begin
      w_estab_tdata = estab_1_tdata;
      w_estab_tdata.index += NUM_INDEX / 2; // Offset CID for #1 side
    end else begin
      w_estab_tdata = '0;
    end
  end

  //------------------------------------------------
  // Arbitrate rcv_nxt_upd #0/#1 (#0 side priority)
  wire w_rcv_nxt_upd_tready;
  wire w_rcv_nxt_upd_0_tready, w_rcv_nxt_upd_1_tready;
  wire w_rcv_nxt_upd_tvalid = rcv_nxt_upd_0_tvalid | rcv_nxt_upd_1_tvalid;
  assign w_rcv_nxt_upd_0_tready = w_rcv_nxt_upd_tready;
  assign w_rcv_nxt_upd_1_tready = w_rcv_nxt_upd_tready & ~ rcv_nxt_upd_0_tvalid;
  assign rcv_nxt_upd_0_tready = w_rcv_nxt_upd_0_tready;
  assign rcv_nxt_upd_1_tready = w_rcv_nxt_upd_1_tready;

  ptrUpdateReq w_rcv_nxt_upd_tdata;
  always_comb begin
    if (rcv_nxt_upd_0_tvalid) begin
      w_rcv_nxt_upd_tdata = rcv_nxt_upd_0_tdata;
    end else if (rcv_nxt_upd_1_tvalid) begin
      w_rcv_nxt_upd_tdata = rcv_nxt_upd_1_tdata;
      w_rcv_nxt_upd_tdata.index += NUM_INDEX / 2; // Offsets CID for #1 side
    end else begin
      w_rcv_nxt_upd_tdata = '0;
    end
  end
    
  //------------------------------------------------
  // Arbitrate table update requests

  // estab is always priority
  assign w_estab_tready = w_input_clken;

  // Accept others if estab is not valid
  assign w_rcv_nxt_upd_tready = w_input_clken & ~ w_estab_tvalid;
  wire w_usr_read_upd_tready = w_input_clken & ~ w_estab_tvalid;
  wire w_payload_len_tready = w_input_clken & ~ w_estab_tvalid;

  assign usr_read_upd_tready = w_usr_read_upd_tready;
  assign payload_len_tready = w_payload_len_tready;

  wire w_estab_strb = w_estab_tready & w_estab_tvalid;
  wire w_rcv_nxt_upd_strb = w_rcv_nxt_upd_tready & w_rcv_nxt_upd_tvalid;
  wire w_usr_read_upd_strb = w_usr_read_upd_tready & usr_read_upd_tvalid;
  wire w_payload_len_strb = w_payload_len_tready & payload_len_tvalid;

  wire w_rn_upd_req_strb = w_estab_strb | w_rcv_nxt_upd_strb;
  ptrUpdateReq w_rn_upd_req_data;
  always_comb begin
    if (w_estab_strb) begin
      w_rn_upd_req_data = w_estab_tdata;
      w_rn_upd_req_data.source = SRC_ESTAB;
    end else if (w_rcv_nxt_upd_strb) begin
      w_rn_upd_req_data = w_rcv_nxt_upd_tdata;
      w_rn_upd_req_data.source = SRC_RCV_NXT;
    end else begin
      w_rn_upd_req_data = '0;
    end
  end

  wire w_ur_upd_req_strb = w_estab_strb | w_usr_read_upd_strb;
  ptrUpdateReq w_ur_upd_req_data;
  always_comb begin
    if (w_estab_strb) begin
      w_ur_upd_req_data = w_estab_tdata;
      w_ur_upd_req_data.source = SRC_ESTAB;
    end else if (w_usr_read_upd_strb) begin
      w_ur_upd_req_data = usr_read_upd_tdata;
      w_ur_upd_req_data.source = SRC_USR_READ;
    end else begin
      w_ur_upd_req_data = '0;
    end
  end

  wire w_hp_upd_req_strb = w_estab_strb | w_payload_len_strb;
  ptrUpdateReq w_hp_upd_req_data;
  always_comb begin
    if (w_estab_strb) begin
      w_hp_upd_req_data = w_estab_tdata;
      w_hp_upd_req_data.source = SRC_ESTAB;
    end else if (w_payload_len_strb) begin
      w_hp_upd_req_data.ptr = payload_len_tdata[PAYLEN_WIDTH-1:0] + r_lat_usr + HEADER_LEN;
      w_hp_upd_req_data.index = r_lat_idx;
      w_hp_upd_req_data.op = TABLE_OP_INSERT;
      w_hp_upd_req_data.source = SRC_PAYLOAD_LEN;
    end else begin
      w_hp_upd_req_data = '0;
    end
  end

  // CID update signal (Network)
  ptrUpdateReq r_rn_sreg_data[0:VALID_UPD_DELAY-1];
  ptrUpdateReq r_ur_sreg_data[0:VALID_UPD_DELAY-1];
  ptrUpdateReq r_hp_sreg_data[0:VALID_UPD_DELAY-1];
  reg[VALID_UPD_DELAY-1:0] r_rn_sreg_strb;
  reg[VALID_UPD_DELAY-1:0] r_ur_sreg_strb;
  reg[VALID_UPD_DELAY-1:0] r_hp_sreg_strb;

  // FSM (state machine) signals
  State r_state;
  
  // CID latency tuning
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_rn_sreg_strb <= '0;
      r_ur_sreg_strb <= '0;
      r_hp_sreg_strb <= '0;
      for (int i = 0; i < VALID_UPD_DELAY; i++) begin
        r_rn_sreg_data[i] <= '0;
        r_ur_sreg_data[i] <= '0;
        r_hp_sreg_data[i] <= '0;
      end
    end else begin
      r_rn_sreg_strb[0] <= w_rn_upd_req_strb;
      r_ur_sreg_strb[0] <= w_ur_upd_req_strb;
      r_hp_sreg_strb[0] <= w_hp_upd_req_strb;
      r_rn_sreg_data[0] <= w_rn_upd_req_data;
      r_ur_sreg_data[0] <= w_ur_upd_req_data;
      r_hp_sreg_data[0] <= w_hp_upd_req_data;
      for (int i = 1; i < VALID_UPD_DELAY; i++) begin
        r_rn_sreg_strb[i] <= r_rn_sreg_strb[i-1];
        r_ur_sreg_strb[i] <= r_ur_sreg_strb[i-1];
        r_hp_sreg_strb[i] <= r_hp_sreg_strb[i-1];
        r_rn_sreg_data[i] <= r_rn_sreg_data[i-1];
        r_ur_sreg_data[i] <= r_ur_sreg_data[i-1];
        r_hp_sreg_data[i] <= r_hp_sreg_data[i-1];
      end
    end
  end

  wire r_rn_delay_strb, r_ur_delay_strb, r_hp_delay_strb;
  ptrUpdateReq r_rn_delay_data, r_ur_delay_data, r_hp_delay_data;
  assign r_rn_delay_strb = r_rn_sreg_strb[VALID_UPD_DELAY-1];
  assign r_ur_delay_strb = r_ur_sreg_strb[VALID_UPD_DELAY-1];
  assign r_hp_delay_strb = r_hp_sreg_strb[VALID_UPD_DELAY-1];
  assign r_rn_delay_data = r_rn_sreg_data[VALID_UPD_DELAY-1];
  assign r_ur_delay_data = r_ur_sreg_data[VALID_UPD_DELAY-1];
  assign r_hp_delay_data = r_hp_sreg_data[VALID_UPD_DELAY-1];
  
  wire w_ur_updated = r_ur_delay_strb && (r_ur_delay_data.op == TABLE_OP_INSERT) && (r_ur_delay_data.source == SRC_USR_READ);
  wire w_hp_updated = r_hp_delay_strb && (r_hp_delay_data.op == TABLE_OP_INSERT) && (r_hp_delay_data.source == SRC_PAYLOAD_LEN);
  
  //------------------------------------------------
  // Force parity error

  wire w_insert_pointer_table_fault_0 = rcv_insert_fault[0];
  wire w_insert_length_table_fault_0  = rcv_insert_fault[1];
  wire w_insert_pointer_table_fault_1 = rcv_insert_fault[4];
  wire w_insert_length_table_fault_1  = rcv_insert_fault[5];
  
  wire w_rn_pty_inv = 
    (((w_rn_upd_req_data.index[INDEX_WIDTH - 1] == '0) && w_insert_pointer_table_fault_0) ||
     ((w_rn_upd_req_data.index[INDEX_WIDTH - 1] == '1) && w_insert_pointer_table_fault_1)) ? 1'b1 : 1'b0;
  
  wire w_ur_pty_inv = 
    (((w_ur_upd_req_data.index[INDEX_WIDTH - 1] == '0) && w_insert_pointer_table_fault_0) ||
     ((w_ur_upd_req_data.index[INDEX_WIDTH - 1] == '1) && w_insert_pointer_table_fault_1)) ? 1'b1 : 1'b0;
  
  wire w_hp_pty_inv = 
    (((w_hp_upd_req_data.index[INDEX_WIDTH - 1] == '0) && w_insert_length_table_fault_0) ||
     ((w_hp_upd_req_data.index[INDEX_WIDTH - 1] == '1) && w_insert_length_table_fault_1)) ? 1'b1 : 1'b0;

  //------------------------------------------------
  // RAM write control
  
  // Flag clear signal when connection is established
  wire w_flag_clr_vld = r_rn_delay_strb && r_rn_delay_data.source == SRC_ESTAB && r_rn_delay_data.op == TABLE_OP_INSERT;
  wire[INDEX_WIDTH-1:0] w_flag_clr_idx = r_rn_delay_data.index;
  
  // CID Valid table initialization control
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_table_init_done <= '0;
      r_table_init_addr <= '0;
    end else if (!r_table_init_done) begin
      r_table_init_done <= (r_table_init_addr >= NUM_INDEX - 1);
      r_table_init_addr <= r_table_init_addr + 'd1;
    end
  end
  
  // CID Valid table write control
  reg w_cidvld_upd_val;
  reg[INDEX_WIDTH-1:0] w_cidvld_upd_idx;
  reg w_cidvld_upd_vld;
  always_comb begin
    w_cidvld_upd_val = '0;
    w_cidvld_upd_idx = '0;
    w_cidvld_upd_vld = '0;
    if (!r_table_init_done) begin
      w_cidvld_upd_val = '0;
      w_cidvld_upd_idx = r_table_init_addr;
      w_cidvld_upd_vld = '1;
    end else if (r_rn_delay_strb && r_rn_delay_data.source == SRC_ESTAB) begin
      if (r_rn_delay_data.op == TABLE_OP_INSERT) begin
        w_cidvld_upd_val = '1;
        w_cidvld_upd_idx = r_rn_delay_data.index;
        w_cidvld_upd_vld = '1;
      end else if (r_rn_delay_data.op == TABLE_OP_DELETE) begin
        w_cidvld_upd_val = '0;
        w_cidvld_upd_idx = r_rn_delay_data.index;
        w_cidvld_upd_vld = '1;
      end
    end
  end
  assign w_cidvld_wr_data = w_cidvld_upd_val;
  assign w_cidvld_wr_addr = w_cidvld_upd_idx[BANK_WIDTH+:ADDR_WIDTH];
  assign w_cidvld_wr_en   = {{NUM_BANK-1{1'h0}}, w_cidvld_upd_vld} << w_cidvld_upd_idx[BANK_WIDTH-1:0];
  
  // SOF flag table write control
  reg w_sof_upd_val;
  reg[INDEX_WIDTH-1:0] w_sof_upd_idx;
  reg w_sof_upd_vld;
  always_comb begin
    w_sof_upd_val = '0;
    w_sof_upd_idx = '0;
    w_sof_upd_vld = '0;
    if (w_ur_upd_req_strb && w_ur_upd_req_data.source == SRC_USR_READ && w_ur_upd_req_data.ptr != r_lat_usr) begin
      // Write the SOF flag table only when the value of usr_read changes
      // to continue sof=1 for the next req when resp.length=0 is returned for sof=1.
      w_sof_upd_val = r_lat_head;
      w_sof_upd_idx = r_lat_idx;
      w_sof_upd_vld = '1;
    end else if (w_flag_clr_vld) begin
      w_sof_upd_val = '0;
      w_sof_upd_idx = w_flag_clr_idx;
      w_sof_upd_vld = '1;
    end
  end
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_sof_wr_data = '0;
      r_sof_wr_addr = '0;
      r_sof_wr_en   = '0;
    end else begin
      r_sof_wr_data = w_sof_upd_val;
      r_sof_wr_addr = w_sof_upd_idx[BANK_WIDTH+:ADDR_WIDTH];
      r_sof_wr_en   = {{NUM_BANK-1{1'h0}}, w_sof_upd_vld} << w_sof_upd_idx[BANK_WIDTH-1:0];
    end
  end
  
  // header buffer B.P. table write control
  reg w_bp_upd_val;
  reg[INDEX_WIDTH-1:0] w_bp_upd_idx;
  reg w_bp_upd_vld;
  always_comb begin
    w_bp_upd_val = '0;
    w_bp_upd_idx = '0;
    w_bp_upd_vld = '0;
    if (w_flag_clr_vld) begin
      w_bp_upd_val = '0;
      w_bp_upd_idx = w_flag_clr_idx;
      w_bp_upd_vld = '1;
    end else if (header_buff_usage_vld) begin
      w_bp_upd_val = header_buff_usage[40];
      w_bp_upd_idx = header_buff_usage[INDEX_WIDTH-1:0];
      w_bp_upd_vld = '1;
    end
  end
  assign w_bp_wr_data = w_bp_upd_val;
  assign w_bp_wr_addr = w_bp_upd_idx[BANK_WIDTH+:ADDR_WIDTH];
  assign w_bp_wr_en   = {{NUM_BANK-1{1'h0}}, w_bp_upd_vld} << w_bp_upd_idx[BANK_WIDTH-1:0];

  // Discard flag table write control
  reg w_dis_upd_val;
  reg[INDEX_WIDTH-1:0] w_dis_upd_idx;
  reg w_dis_upd_vld;
  always_comb begin
    w_dis_upd_val = '0;
    w_dis_upd_idx = '0;
    w_dis_upd_vld = '0;
    if (w_payload_len_strb) begin
      w_dis_upd_val = payload_len_tdata[PAYLEN_WIDTH];
      w_dis_upd_idx = r_lat_idx;
      w_dis_upd_vld = '1;
    end else if (w_flag_clr_vld) begin
      w_dis_upd_val = '0;
      w_dis_upd_idx = w_flag_clr_idx;
      w_dis_upd_vld = '1;
    end
  end
  assign w_dis_wr_data = w_dis_upd_val;
  assign w_dis_wr_addr = w_dis_upd_idx[BANK_WIDTH+:ADDR_WIDTH];
  assign w_dis_wr_en   = {{NUM_BANK-1{1'h0}}, w_dis_upd_vld} << w_dis_upd_idx[BANK_WIDTH-1:0];
  
  // rcv_nxt write control
  assign w_rn_wr_data = { ^ {w_rn_upd_req_data.ptr, w_rn_pty_inv}, w_rn_upd_req_data.ptr };
  assign w_rn_wr_addr = w_rn_upd_req_data.index[BANK_WIDTH+:ADDR_WIDTH];
  assign w_rn_wr_en   = {{NUM_BANK-1{1'h0}}, w_rn_upd_req_strb} << w_rn_upd_req_data.index[BANK_WIDTH-1:0];
  
  // usr_read write control
  assign w_ur_wr_data = { ^ {w_ur_upd_req_data.ptr, w_ur_pty_inv}, w_ur_upd_req_data.ptr };
  assign w_ur_wr_addr = w_ur_upd_req_data.index[BANK_WIDTH+:ADDR_WIDTH];
  assign w_ur_wr_en   = {{NUM_BANK-1{1'h0}}, w_ur_upd_req_strb} << w_ur_upd_req_data.index[BANK_WIDTH-1:0];
  
  // head_ptr write control
  assign w_hp_wr_data = { ^ {w_hp_upd_req_data.ptr, w_hp_pty_inv}, w_hp_upd_req_data.ptr };
  assign w_hp_wr_addr = w_hp_upd_req_data.index[BANK_WIDTH+:ADDR_WIDTH];
  assign w_hp_wr_en   = {{NUM_BANK-1{1'h0}}, w_hp_upd_req_strb} << w_hp_upd_req_data.index[BANK_WIDTH-1:0];
  
  //------------------------------------------------
  // Table RAM
  
  generate
    for (genvar gi = 0; gi < NUM_BANK; gi = gi + 1) begin
    
      // CID Valid table (for round-robin)
      ingr_event_core_ram_dist #(
        .DATA_WIDTH (1        ), // integer
        .DEPTH      (NUM_GROUP)  // integer
      ) u_cidvld_table_rr (
        .clk    (ap_clk               ), // input                   
        .wr_en  (w_cidvld_wr_en   [gi]), // input                 
        .wr_addr(w_cidvld_wr_addr     ), // input [ADDR_WIDTH-1:0]  
        .wr_data(w_cidvld_wr_data     ), // input [DATA_WIDTH-1:0]  
        .rd_addr(w_cidvld_rr_rd_addr     ), // input [ADDR_WIDTH-1:0]  
        .rd_data(w_cidvld_rr_rd_data [gi])  // output[DATA_WIDTH-1:0]  
      );
    
      // SOF Flag Table
      ingr_event_core_ram_dist #(
        .DATA_WIDTH (1        ), // integer
        .DEPTH      (NUM_GROUP)  // integer
      ) u_sof_table (
        .clk    (ap_clk           ), // input                   
        .wr_en  (r_sof_wr_en  [gi]), // input                 
        .wr_addr(r_sof_wr_addr    ), // input [ADDR_WIDTH-1:0]  
        .wr_data(r_sof_wr_data    ), // input [DATA_WIDTH-1:0]  
        .rd_addr(w_sof_rd_addr    ), // input [ADDR_WIDTH-1:0]  
        .rd_data(w_sof_rd_data[gi])  // output[DATA_WIDTH-1:0]  
      );
    
      // Header buffer B.P. table
      ingr_event_core_ram_dist #(
        .DATA_WIDTH (1        ), // integer
        .DEPTH      (NUM_GROUP)  // integer
      ) u_header_bp_table (
        .clk    (ap_clk           ), // input                   
        .wr_en  (w_bp_wr_en   [gi]), // input                 
        .wr_addr(w_bp_wr_addr     ), // input [ADDR_WIDTH-1:0]  
        .wr_data(w_bp_wr_data     ), // input [DATA_WIDTH-1:0]  
        .rd_addr(w_bp_rd_addr     ), // input [ADDR_WIDTH-1:0]  
        .rd_data(w_bp_rd_data [gi])  // output[DATA_WIDTH-1:0]  
      );
    
      // Discard flag table
      ingr_event_core_ram_dist #(
        .DATA_WIDTH (1        ), // integer
        .DEPTH      (NUM_GROUP)  // integer
      ) u_discard_table (
        .clk    (ap_clk           ), // input                   
        .wr_en  (w_dis_wr_en  [gi]), // input                 
        .wr_addr(w_dis_wr_addr    ), // input [ADDR_WIDTH-1:0]  
        .wr_data(w_dis_wr_data    ), // input [DATA_WIDTH-1:0]  
        .rd_addr(w_dis_rd_addr    ), // input [ADDR_WIDTH-1:0]  
        .rd_data(w_dis_rd_data[gi])  // output[DATA_WIDTH-1:0]  
      );
    
      // rcv_nxt_table
      ingr_event_core_ram_sdp #(
        .DATA_WIDTH ($bits(tableEntry)), // integer
        .DEPTH      (NUM_GROUP        )  // integer
      ) u_rcv_nxt_table (
        .clk    (ap_clk           ), // input                   
        .wr_en  (w_rn_wr_en   [gi]), // input                 
        .wr_addr(w_rn_wr_addr     ), // input [ADDR_WIDTH-1:0]  
        .wr_data(w_rn_wr_data     ), // input [DATA_WIDTH-1:0]  
        .rd_en  (w_rn_rd_en       ), // input                   
        .rd_addr(w_rn_rd_addr     ), // input [ADDR_WIDTH-1:0]  
        .rd_data(w_rn_rd_data [gi])  // output[DATA_WIDTH-1:0]  
      );
      
      // usr_read_table
      ingr_event_core_ram_sdp #(
        .DATA_WIDTH ($bits(tableEntry)), // integer
        .DEPTH      (NUM_GROUP        )  // integer
      ) u_usr_read_table (
        .clk    (ap_clk           ), // input                   
        .wr_en  (w_ur_wr_en   [gi]), // input                   
        .wr_addr(w_ur_wr_addr     ), // input [ADDR_WIDTH-1:0]  
        .wr_data(w_ur_wr_data     ), // input [DATA_WIDTH-1:0]  
        .rd_en  (w_ur_rd_en       ), // input                   
        .rd_addr(w_ur_rd_addr     ), // input [ADDR_WIDTH-1:0]  
        .rd_data(w_ur_rd_data [gi])  // output[DATA_WIDTH-1:0]  
      );
      
      // head_ptr_table
      ingr_event_core_ram_sdp #(
        .DATA_WIDTH ($bits(tableEntry)), // integer
        .DEPTH      (NUM_GROUP        )  // integer
      ) u_head_ptr_table (
        .clk    (ap_clk           ), // input                   
        .wr_en  (w_hp_wr_en   [gi]), // input                   
        .wr_addr(w_hp_wr_addr     ), // input [ADDR_WIDTH-1:0]  
        .wr_data(w_hp_wr_data     ), // input [DATA_WIDTH-1:0]  
        .rd_en  (w_hp_rd_en       ), // input                   
        .rd_addr(w_hp_rd_addr     ), // input [ADDR_WIDTH-1:0]  
        .rd_data(w_hp_rd_data [gi])  // output[DATA_WIDTH-1:0]  
      );
    end
  endgenerate

  //------------------------------------------------
  // FSM (state machine)
  
  wire w_rr_stall;
  wire w_start_tready;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_state <= ST_RESET;
    end else begin
      case (r_state)
        ST_RESET:
          r_state <= ST_WAIT_RR;
          
        ST_WAIT_RR:
          if(w_found_valid && w_found_ready)begin
            r_state <= ST_POP_INGR_START;
          end
         
        ST_POP_INGR_START:
          if(start_tvalid && w_start_tready)begin
            r_state <= ST_PUSH_RECEIVE;
          end
          
        ST_PUSH_RECEIVE:
          if(receive_tvalid && receive_tready)begin
            r_state <= ST_POP_USR_READ;
          end
          
        ST_POP_USR_READ:
          if(w_ur_updated)begin
            if(r_lat_head)begin
              r_state <= ST_POP_PAYLOAD_LEN;
            end else begin
              r_state <= ST_PUSH_DONE;
            end
          end
        
        ST_POP_PAYLOAD_LEN:
          if(w_hp_updated)begin
            r_state <= ST_PUSH_DONE;
          end
        
        ST_PUSH_DONE:
          if(done_tvalid && done_tready)begin
            r_state <= ST_WAIT_RR;
          end
      
        default:
          r_state <= ST_RESET;
          
      endcase
    end
  end
  
  assign w_start_tready = (r_state == ST_POP_INGR_START);
  assign start_tready = w_start_tready;
  
  assign w_found_ready = (r_state == ST_WAIT_RR);

  //------------------------------------------------
  // Round-Robin

  assign w_rr_stall =
      (r_state == ST_POP_INGR_START) ||
      (r_state == ST_PUSH_RECEIVE) ||
      (r_state == ST_POP_USR_READ) ||
      (r_state == ST_POP_PAYLOAD_LEN);
  
  wire w_rr_ready_wait;
  wire w_rr_clken = (~ w_rr_stall) & (~ w_rr_ready_wait);
  
  reg r_pipe_init_valid;
  reg[ADDR_WIDTH-1:0] r_pipe_init_addr;
  reg[BANK_WIDTH-1:0] r_pipe_init_all_bank;
  
  // Stage1: Issue RAM Address
  reg[ADDR_WIDTH-1:0] r_s1_addr;
  reg[BANK_WIDTH-1:0] r_s1_all_bank;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_s1_addr <= '0;
      r_s1_all_bank <= '0;
    end else if (w_rr_clken) begin
      if (r_pipe_init_valid) begin
        r_s1_addr <= r_pipe_init_addr;
        r_s1_all_bank <= r_pipe_init_all_bank;
      end else begin
        r_s1_addr <= r_s1_addr + 'd1;
        r_s1_all_bank <= '0;
      end
    end
  end
  assign w_rn_rd_en = w_rr_clken;
  assign w_ur_rd_en = w_rr_clken;
  assign w_hp_rd_en = w_rr_clken;
  assign w_rn_rd_addr = r_s1_addr;
  assign w_ur_rd_addr = r_s1_addr;
  assign w_hp_rd_addr = r_s1_addr;
  
  // Stage2 removed to reduce utilization
  
  // Stage3: Waiting for RAM Read
  reg r_s3_valid;
  reg[ADDR_WIDTH-1:0] r_s3_addr;
  reg[BANK_WIDTH-1:0] r_s3_all_bank;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_s3_valid <= '0;
      r_s3_addr <= '0;
      r_s3_all_bank <= '0;
    end else if (w_rr_clken) begin
      r_s3_valid <= ~r_pipe_init_valid;
      r_s3_addr <= r_s1_addr;
      r_s3_all_bank <= r_s1_all_bank;
    end
  end
  assign w_cidvld_rr_rd_addr = r_s3_addr;
  assign w_sof_rd_addr = r_s3_addr;
  assign w_bp_rd_addr = r_s3_addr;
  assign w_dis_rd_addr = r_s3_addr;
  
  // Stage4: Detect bank containing received data
  reg r_s4_valid;
  reg[ADDR_WIDTH-1:0] r_s4_addr;
  reg[NUM_BANK-1:0][PTR_WIDTH-1:0] r_s4_rn;
  reg[NUM_BANK-1:0][PTR_WIDTH-1:0] r_s4_ur;
  reg[NUM_BANK-1:0][PAYLEN_WIDTH-1:0] r_s4_payload_len;
  reg[NUM_BANK-1:0] r_s4_rcv_list;
  reg[NUM_BANK-1:0] r_s4_head_list;
  reg[NUM_BANK-1:0] r_s4_sof_list;
  reg[NUM_BANK-1:0] r_s4_eof_list;
  reg[NUM_BANK-1:0] r_s4_dis_list;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_s4_valid <= '0;
      r_s4_addr <= '0;
      r_s4_rn <= '0;
      r_s4_ur <= '0;
      r_s4_payload_len <= '0;
      r_s4_rcv_list <= '0;
      r_s4_head_list <= '0;
      r_s4_sof_list <= '0;
      r_s4_eof_list <= '0;
      r_s4_dis_list <= '0;
    end else if (w_rr_clken) begin
      r_s4_valid <= r_s3_valid & ~r_pipe_init_valid;
      r_s4_addr <= r_s3_addr;
      for (int i = 0; i < NUM_BANK; i++) begin
        reg[INDEX_WIDTH-1:0] v_idx;
        reg v_head, v_sof, v_eof, v_bp;
        reg[PTR_WIDTH-1:0] v_received;
        reg[PTR_WIDTH-1:0] v_remaining;
        
        v_idx = r_s3_addr * NUM_BANK + i;
        
        // At the beginning of the frame or not
        v_head = w_ur_rd_data[i].ptr == w_hp_rd_data[i].ptr;
        
        // Amount of data received
        v_received = w_rn_rd_data[i].ptr - w_ur_rd_data[i].ptr;
        
        // Distance to the end of the current frame
        v_remaining = w_hp_rd_data[i].ptr - w_ur_rd_data[i].ptr;
        
        // First of payload or not
        v_sof = w_sof_rd_data[i] & ~v_head;
        
        // Include payload tail or not
        v_eof = !v_head && (v_remaining <= v_received);
        
        // B.P caused by header buffer full
        v_bp = w_bp_rd_data[i] & ~v_head;
        
        // Determine the number of bytes received
        if (v_head) begin
          // At the beginning of the frame, only the length of the header is acquired.
          r_s4_rn[i] <= w_ur_rd_data[i].ptr + HEADER_LEN;
        end else if (v_eof) begin
          // If it is not the beginning of the frame and the end of the frame has been received,
          // get to the end of the frame.
          r_s4_rn[i] <= w_hp_rd_data[i].ptr;
        end else begin
          // If none, all received data will be acquired.
          r_s4_rn[i] <= w_rn_rd_data[i].ptr;
        end
        
        r_s4_ur[i] <= w_ur_rd_data[i].ptr;
        
        // If sof=1, the payload length is the distance to the end of frame.
        r_s4_payload_len[i] <= v_remaining;
        
        // Set 1 to the bank that satisfies the condition below:
        // - CID is valid (w_cidvld_rr_rd_data)
        // - Header buffer has free space (v_bp)
        // - It is not already verified bank (r_s3_all_bank)
        // - There are enough received data (w_XX_rd_data)
        if (w_cidvld_rr_rd_data[i] && i >= r_s3_all_bank && !v_bp) begin
          r_s4_rcv_list[i] <= (!v_head && v_received > 0) || (v_head && v_received >= HEADER_LEN);
          r_s4_head_list[i] <= v_head;
          r_s4_sof_list[i] <= v_sof;
          r_s4_eof_list[i] <= v_eof;
          r_s4_dis_list[i] <= w_dis_rd_data[i] & ~ v_head;
        end else begin
          r_s4_rcv_list[i] <= '0;
          r_s4_head_list[i] <= '0;
          r_s4_sof_list[i] <= '0;
          r_s4_eof_list[i] <= '0;
          r_s4_dis_list[i] <= '0;
        end
      end
    end
  end
  
  // Stage5: Deciding which bank will issue the ingr_receive
  reg r_s5_valid;
  reg[INDEX_WIDTH-1:0] r_s5_idx;
  reg[PTR_WIDTH-1:0] r_s5_rn;
  reg[PTR_WIDTH-1:0] r_s5_ur;
  reg[PAYLEN_WIDTH-1:0] r_s5_payload_len;
  reg r_s5_head;
  reg r_s5_sof;
  reg r_s5_eof;
  reg r_s5_dis;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_s5_valid <= '0;
      r_s5_idx <= '0;
      r_s5_rn <= '0;
      r_s5_ur <= '0;
      r_s5_payload_len <= '0;
      r_s5_head <= '0;
      r_s5_sof <= '0;
      r_s5_eof <= '0;
      r_s5_dis <= '0;
    end else if (w_rr_clken) begin
      reg v_found;
      reg[BANK_WIDTH-1:0] v_bank;
      reg[INDEX_WIDTH-1:0] v_idx;

      // Priority Encoder
      v_found = '0;
      v_bank = '0;
      for (int i = 0; i < NUM_BANK; i++) begin
        if ( ! v_found && r_s4_rcv_list[i]) begin
          v_found = '1;
          v_bank = BANK_WIDTH'(i);
        end
      end
      
      v_idx = {r_s4_addr, v_bank[BANK_WIDTH-1:0]};
      
      if (r_s4_valid & v_found & ~r_pipe_init_valid) begin
        // Determine output content of ingr_receive
        r_s5_valid <= '1;
        r_s5_idx <= v_idx;
        r_s5_rn <= r_s4_rn[v_bank];
        r_s5_ur <= r_s4_ur[v_bank];
        r_s5_payload_len <= r_s4_payload_len[v_bank];
        r_s5_head <= r_s4_head_list[v_bank];
        r_s5_sof <= r_s4_sof_list[v_bank];
        r_s5_eof <= r_s4_eof_list[v_bank];
        r_s5_dis <= r_s4_dis_list[v_bank];
        
        // Initialize the pipeline and restart the scan at the end
        r_pipe_init_valid <= '1;
        if (32'(v_bank) < NUM_BANK - 1) begin
          // If the last bank has not been reached, restart from the next bank in the same group
          r_pipe_init_addr <= r_s4_addr;
          r_pipe_init_all_bank <= v_bank + 'd1;
        end else begin
          // If the last bank has been reached, restart from the first bank of the next group
          r_pipe_init_addr <= r_s4_addr + 'd1;
          r_pipe_init_all_bank <= '0;
        end
      end else begin
        r_s5_valid <= '0;
        r_pipe_init_valid <= '0;
      end
    end else if (w_found_ready) begin
      // Negate valid when the state machine receives the result
      r_s5_valid <= '0;
    end
  end
  
  assign w_found_valid = r_s5_valid;
  assign w_found_idx = r_s5_idx;
  assign w_found_ext = r_s5_rn;
  assign w_found_usr = r_s5_ur;
  assign w_found_payload_len = r_s5_payload_len;
  assign w_found_head = r_s5_head;
  assign w_found_sof = r_s5_sof;
  assign w_found_eof = r_s5_eof;
  assign w_found_dis = r_s5_dis;
  
  // Stall the pipeline until round robin selection results are latched.
  assign w_rr_ready_wait = w_found_valid;
  
  //------------------------------------------------  
  // Latches head and usr_read
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_lat_head <= '0;
      r_lat_idx <= '0;
      r_lat_usr <= '0;
    end else if (w_found_valid && w_found_ready) begin
      r_lat_head <= w_found_head;
      r_lat_idx <= w_found_idx;
      r_lat_usr <= w_found_usr;
    end
  end
  
  //------------------------------------------------  
  // ingr_receive output
  sessionPtr r_receive_tdata;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_receive_tdata <= '0;
    end else if (w_found_valid && w_found_ready) begin
      r_receive_tdata.index       <= w_found_idx;
      r_receive_tdata.ext         <= w_found_ext;
      r_receive_tdata.usr         <= w_found_usr;
      r_receive_tdata.payload_len <= w_found_payload_len;
      r_receive_tdata.head        <= w_found_head;
      r_receive_tdata.sof         <= w_found_sof;
      r_receive_tdata.eof         <= w_found_eof;
      r_receive_tdata.discard     <= w_found_dis;
`ifdef INGR_EVENT_DEBUG_DISPLAY
      $display("ingr_event: push receive: cid=%1d, ext=0x%1x, usr=0x%1x, head=%1d, sof=%1d, eof=%1d, payload_len=%1d, dis=%1d",
        w_found_idx, w_found_ext, w_found_usr, w_found_head, w_found_sof, w_found_eof, w_found_payload_len, w_found_dis);
`endif
    end
  end
  
  assign receive_tvalid = (r_state == ST_PUSH_RECEIVE);
  assign receive_tdata = r_receive_tdata;
  
  //------------------------------------------------  
  // ingr_done output
  assign done_tdata = '1;
  assign done_tvalid = (r_state == ST_PUSH_DONE);

  //------------------------------------------------
  // Transfer Count
  
  reg r_stat_s2_wen;
  reg r_stat_s3_wen;
  reg r_stat_s2_upd;
  reg r_stat_s3_upd;
  wire[INDEX_WIDTH-1:0] w_stat_s0_idx = w_rn_upd_req_data.index[INDEX_WIDTH-1:0];
  reg[INDEX_WIDTH-1:0] r_stat_s2_idx;
  reg[INDEX_WIDTH-1:0] r_stat_s3_idx;
  tableEntry w_stat_s2_old_ptr;
  tableEntry r_stat_s2_new_ptr;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_stat_s2_wen <= '0;
      r_stat_s3_wen <= '0;
      r_stat_s2_upd <= '0;
      r_stat_s3_upd <= '0;
      r_stat_s2_idx <= '0;
      r_stat_s3_idx <= '0;
      r_stat_s2_new_ptr <= '0;
    end else begin
      r_stat_s2_wen <= w_rn_upd_req_strb;
      r_stat_s3_wen <= r_stat_s2_wen;
      r_stat_s2_upd <= w_rcv_nxt_upd_strb;
      r_stat_s3_upd <= r_stat_s2_upd;
      r_stat_s2_idx <= w_stat_s0_idx;
      r_stat_s3_idx <= r_stat_s2_idx;
      r_stat_s2_new_ptr <= w_rn_wr_data;
    end
  end
  
  // Do not accept new pointers during table initialization and RAM updates
  assign w_input_clken = r_table_init_done & ~ (r_stat_s2_wen | r_stat_s3_wen);

  ingr_event_core_ram_sdp #(
    .DATA_WIDTH ($bits(tableEntry)), // integer
    .DEPTH      (NUM_INDEX        )  // integer
  ) u_rcv_nxt_table_2 (
    .clk    (ap_clk           ), // input
    .wr_en  (r_stat_s2_wen    ), // input
    .wr_addr(r_stat_s2_idx    ), // input [ADDR_WIDTH-1:0]
    .wr_data(r_stat_s2_new_ptr), // input [DATA_WIDTH-1:0]
    .rd_en  ('1               ), // input
    .rd_addr(w_stat_s0_idx    ), // input [ADDR_WIDTH-1:0]
    .rd_data(w_stat_s2_old_ptr)  // output[DATA_WIDTH-1:0]
  );
  
  reg[PTR_WIDTH-1:0] r_stat_s3_len;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_stat_s3_len <= '0;
    end else begin
      r_stat_s3_len <= r_stat_s2_new_ptr.ptr - w_stat_s2_old_ptr.ptr;
    end
  end
  
  reg[47:0] w_stat_s3_rcv_data;
  always_comb begin
    w_stat_s3_rcv_data = 0;
    w_stat_s3_rcv_data[INDEX_WIDTH-1:0] = r_stat_s3_idx;
    w_stat_s3_rcv_data[47:16] = r_stat_s3_len;
  end
  assign stat_rcv_data = w_stat_s3_rcv_data;
  assign stat_rcv_data_vld = r_stat_s3_upd;
  
  //------------------------------------------------
  // Debug counters
  wire w_rn_count_ena = (estab_0_tvalid & w_estab_0_tready) | (rcv_nxt_upd_0_tvalid & w_rcv_nxt_upd_0_tready);
  wire w_ur_count_ena = w_usr_read_upd_strb && (r_lat_idx[INDEX_WIDTH-1] == '0);
  reg[31:0] r_rn_count;
  reg[31:0] r_ur_count;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_rn_count <= '0;
      r_ur_count <= '0;
    end else begin
      if (w_rn_count_ena) begin
        r_rn_count <= r_rn_count + 'd1;
      end
      if (w_ur_count_ena) begin
        r_ur_count <= r_ur_count + 'd1;
      end
    end
  end
  assign rcv_nxt_upd_count = r_rn_count;
  assign usr_read_upd_count = r_ur_count;

  wire w_hp_count_ena = (estab_1_tvalid & w_estab_1_tready) | (rcv_nxt_upd_1_tvalid & w_rcv_nxt_upd_1_tready);
  wire w_tp_count_ena = w_usr_read_upd_strb && (r_lat_idx[INDEX_WIDTH-1] == '1);
  reg[31:0] r_hp_count;
  reg[31:0] r_tp_count;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_hp_count <= '0;
      r_tp_count <= '0;
    end else begin
      if (w_hp_count_ena) begin
        r_hp_count <= r_hp_count + 'd1;
      end
      if (w_tp_count_ena) begin
        r_tp_count <= r_tp_count + 'd1;
      end
    end
  end
  assign rx_hp_upd_count = r_hp_count;
  assign rx_tp_upd_count = r_tp_count;

  //------------------------------------------------
  // Connection establishment status
  
  // External IF #0 and #1 cannot both be read at once, so generate addresses alternatively
  reg r_session_status_rd_ifid;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_session_status_rd_ifid <= '0;
    end else begin
      r_session_status_rd_ifid <= ~ r_session_status_rd_ifid;
    end
  end
  wire[INDEX_WIDTH-2:0] w_session_status_rd_cid = stat_sel_session % (NUM_INDEX / 2);

  // CID Valid table (for notification to register)
  wire[INDEX_WIDTH-1:0] w_session_status_rd_addr = {r_session_status_rd_ifid, w_session_status_rd_cid};
  wire w_session_status_rd_data;
  ingr_event_core_ram_dist #(
    .DATA_WIDTH (1        ), // integer
    .DEPTH      (NUM_INDEX)  // integer
  ) u_cidvld_table_reg (
    .clk    (ap_clk                   ), // input                   
    .wr_en  (w_cidvld_upd_vld         ), // input                 
    .wr_addr(w_cidvld_upd_idx         ), // input [ADDR_WIDTH-1:0]  
    .wr_data(w_cidvld_upd_val         ), // input [DATA_WIDTH-1:0]  
    .rd_addr(w_session_status_rd_addr ), // input [ADDR_WIDTH-1:0]  
    .rd_data(w_session_status_rd_data )  // output[DATA_WIDTH-1:0]  
  );
  
  reg[1:0] r_session_status_out;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_session_status_out <= '0;
    end else if (r_session_status_rd_ifid == 0) begin
      r_session_status_out[0] <= w_session_status_rd_data;
    end else begin
      r_session_status_out[1] <= w_session_status_rd_data;
    end
  end
  assign extif_session_status = r_session_status_out;
  
  //------------------------------------------------
  // Last value of pointers
  reg[PTR_WIDTH-1:0] r_extif0_wr_ptr;
  reg[PTR_WIDTH-1:0] r_extif0_rd_ptr;
  reg[PTR_WIDTH-1:0] r_extif1_wr_ptr;
  reg[PTR_WIDTH-1:0] r_extif1_rd_ptr;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_extif0_wr_ptr <= '0;
      r_extif0_rd_ptr <= '0;
      r_extif1_wr_ptr <= '0;
      r_extif1_rd_ptr <= '0;
    end else if (r_s3_valid) begin
      reg v_addr_ifid;
      reg[ADDR_WIDTH-2:0] v_addr_cid_h;
      reg[ADDR_WIDTH-2:0] v_sel_cid_h;
      reg[BANK_WIDTH-1:0] v_sel_cid_l;
      v_addr_ifid = r_s3_addr[ADDR_WIDTH-1];
      v_addr_cid_h = r_s3_addr[ADDR_WIDTH-2:0];
      v_sel_cid_h = dbg_sel_session >> BANK_WIDTH;
      v_sel_cid_l = dbg_sel_session[BANK_WIDTH-1:0];
      if (v_addr_cid_h == v_sel_cid_h) begin
        if (v_addr_ifid == 0) begin
          r_extif0_wr_ptr <= w_rn_rd_data[v_sel_cid_l].ptr;
          r_extif0_rd_ptr <= w_ur_rd_data[v_sel_cid_l].ptr;
        end else begin
          r_extif1_wr_ptr <= w_rn_rd_data[v_sel_cid_l].ptr;
          r_extif1_rd_ptr <= w_ur_rd_data[v_sel_cid_l].ptr;
        end
      end
    end
  end
  assign last_ptr = {
    r_extif1_rd_ptr, // [127:96]
    r_extif1_wr_ptr, // [95:64]
    r_extif0_rd_ptr, // [63:32]
    r_extif0_wr_ptr  // [31:0]
  };
  
  //------------------------------------------------
  // Table mishit.
  
  // CID Valid table (for rcv_nxt mishit detection)
  wire[INDEX_WIDTH-1:0] w_cidvld_rn_rd_addr = w_rcv_nxt_upd_tdata.index;
  wire w_cidvld_rn_rd_data;
  ingr_event_core_ram_dist #(
    .DATA_WIDTH (1        ), // integer
    .DEPTH      (NUM_INDEX)  // integer
  ) u_cidvld_table_mishit_rn (
    .clk    (ap_clk             ), // input
    .wr_en  (w_cidvld_upd_vld   ), // input
    .wr_addr(w_cidvld_upd_idx   ), // input [ADDR_WIDTH-1:0]
    .wr_data(w_cidvld_upd_val   ), // input [DATA_WIDTH-1:0]
    .rd_addr(w_cidvld_rn_rd_addr), // input [ADDR_WIDTH-1:0]
    .rd_data(w_cidvld_rn_rd_data)  // output[DATA_WIDTH-1:0]
  );

  // CID Valid table (for usr_read mishit detection)
  wire[INDEX_WIDTH-1:0] w_cidvld_ur_rd_addr = w_ur_upd_req_data.index;
  wire w_cidvld_ur_rd_data;
  ingr_event_core_ram_dist #(
    .DATA_WIDTH (1        ), // integer
    .DEPTH      (NUM_INDEX)  // integer
  ) u_cidvld_table_mishit_ur (
    .clk    (ap_clk             ), // input
    .wr_en  (w_cidvld_upd_vld   ), // input
    .wr_addr(w_cidvld_upd_idx   ), // input [ADDR_WIDTH-1:0]
    .wr_data(w_cidvld_upd_val   ), // input [DATA_WIDTH-1:0]
    .rd_addr(w_cidvld_ur_rd_addr), // input [ADDR_WIDTH-1:0]
    .rd_data(w_cidvld_ur_rd_data)  // output[DATA_WIDTH-1:0]
  );

  // CID Valid table (for payload_len mishit detection)
  wire[INDEX_WIDTH-1:0] w_cidvld_hp_rd_addr = w_hp_upd_req_data.index;
  wire w_cidvld_hp_rd_data;
  ingr_event_core_ram_dist #(
    .DATA_WIDTH (1        ), // integer
    .DEPTH      (NUM_INDEX)  // integer
  ) u_cidvld_table_mishit_hp (
    .clk    (ap_clk             ), // input
    .wr_en  (w_cidvld_upd_vld   ), // input
    .wr_addr(w_cidvld_upd_idx   ), // input [ADDR_WIDTH-1:0]
    .wr_data(w_cidvld_upd_val   ), // input [DATA_WIDTH-1:0]
    .rd_addr(w_cidvld_hp_rd_addr), // input [ADDR_WIDTH-1:0]
    .rd_data(w_cidvld_hp_rd_data)  // output[DATA_WIDTH-1:0]
  );

  reg r_err_mishit_ptr;
  reg r_err_mishit_len;
  reg[INDEX_WIDTH-1:0] r_err_mishit_idx;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_err_mishit_ptr <= '0;
      r_err_mishit_len <= '0;
      r_err_mishit_idx <= '0;
    end else begin
      r_err_mishit_ptr <= '0;
      r_err_mishit_len <= '0;
      r_err_mishit_idx <= '0;
      if (w_rcv_nxt_upd_strb && ! w_cidvld_rn_rd_data) begin
        r_err_mishit_ptr <= '1;
        r_err_mishit_idx <= w_rcv_nxt_upd_tdata.index;
      end else if (w_usr_read_upd_strb && ! w_cidvld_ur_rd_data) begin
        r_err_mishit_ptr <= '1;
        r_err_mishit_idx <= w_ur_upd_req_data.index;
      end else if (w_payload_len_strb && ! w_cidvld_hp_rd_data) begin
        r_err_mishit_len <= '1;
        r_err_mishit_idx <= w_hp_upd_req_data.index;
      end
    end
  end
  
  //------------------------------------------------
  // Table data error (parity error)
  reg[NUM_BANK-1:0] r_s4_rn_parity;
  reg[NUM_BANK-1:0] r_s4_ur_parity;
  reg[NUM_BANK-1:0] r_s4_hp_parity;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_s4_rn_parity <= '0;
      r_s4_ur_parity <= '0;
      r_s4_hp_parity <= '0;
    end else if (r_s3_valid) begin
      for(int i = 0; i < NUM_BANK; i++) begin
        reg[INDEX_WIDTH-1:0] v_idx;
        v_idx = r_s3_addr * NUM_BANK + i;
        r_s4_rn_parity[i] <= w_cidvld_rr_rd_data[i] & ^ w_rn_rd_data[i];
        r_s4_ur_parity[i] <= w_cidvld_rr_rd_data[i] & ^ w_ur_rd_data[i];
        r_s4_hp_parity[i] <= w_cidvld_rr_rd_data[i] & ^ w_hp_rd_data[i];
      end
    end else begin
      r_s4_rn_parity <= '0;
      r_s4_ur_parity <= '0;
      r_s4_hp_parity <= '0;
    end
  end
  
  reg r_stat_s3_parity;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_stat_s3_parity <= '0;
    end else if (r_stat_s2_upd) begin
      r_stat_s3_parity <= ^ w_stat_s2_old_ptr;
    end else begin
      r_stat_s3_parity <= '0;
    end
  end
  
  reg r_err_parity_ptr;
  reg r_err_parity_len;
  reg[INDEX_WIDTH-1:0] r_err_parity_idx;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_err_parity_ptr <= '0;
      r_err_parity_len <= '0;
      r_err_parity_idx <= '0;
    end else begin
      r_err_parity_ptr <= '0;
      r_err_parity_len <= '0;
      r_err_parity_idx <= '0;
      if (r_s4_valid) begin : blk_parity_err
        for (int i = 0; i < NUM_BANK; i++) begin
          if (r_s4_rn_parity[i]) begin
            r_err_parity_ptr <= '1;
            r_err_parity_idx <= {r_s4_addr, i[BANK_WIDTH-1:0]};
            break;
          end else if (r_s4_ur_parity[i]) begin
            r_err_parity_ptr <= '1;
            r_err_parity_idx <= {r_s4_addr, i[BANK_WIDTH-1:0]};
            break;
          end else if (r_s4_hp_parity[i]) begin
            r_err_parity_len <= '1;
            r_err_parity_idx <= {r_s4_addr, i[BANK_WIDTH-1:0]};
            break;
          end
        end
      end else if (r_stat_s3_parity) begin
        r_err_parity_ptr <= '1;
        r_err_parity_idx <= r_stat_s3_idx;
      end
    end
  end

  //------------------------------------------------
  // Summarize faults
  reg r_fault_valid;
  reg[15:0] r_fault_data;
  always @(posedge ap_clk) begin
    if ( ! ap_rst_n) begin
      r_fault_valid <= '0;
      r_fault_data <= '0;
    end else if (r_err_mishit_ptr) begin
      r_fault_valid <= '1;
      r_fault_data[INDEX_WIDTH-1:0] <= r_err_mishit_idx;
      r_fault_data[10] <= '1;
    end else if (r_err_mishit_len) begin
      r_fault_valid <= '1;
      r_fault_data[INDEX_WIDTH-1:0] <= r_err_mishit_idx;
      r_fault_data[11] <= '1;
    end else if (r_err_parity_ptr) begin
      r_fault_valid <= '1;
      r_fault_data[INDEX_WIDTH-1:0] <= r_err_parity_idx;
      r_fault_data[12] <= '1;
    end else if (r_err_parity_len) begin
      r_fault_valid <= '1;
      r_fault_data[INDEX_WIDTH-1:0] <= r_err_parity_idx;
      r_fault_data[13] <= '1;
    end else begin
      r_fault_valid <= '0;
      r_fault_data <= '0;
    end
  end
  assign rcv_detect_fault_vld = r_fault_valid;
  assign rcv_detect_fault = r_fault_data;
  
endmodule

// Block RAM
module ingr_event_core_ram_sdp #(
  parameter integer DATA_WIDTH  = 32,
  parameter integer DEPTH       = 32,
  parameter integer ADDR_WIDTH  = $clog2(DEPTH)
) (
  input   wire                  clk     ,
  input   wire                  wr_en   ,
  input   wire[ADDR_WIDTH-1:0]  wr_addr ,
  input   wire[DATA_WIDTH-1:0]  wr_data ,
  input   wire                  rd_en   ,
  input   wire[ADDR_WIDTH-1:0]  rd_addr ,
  output  wire[DATA_WIDTH-1:0]  rd_data
);

  (* ram_style = "block" *) reg[DATA_WIDTH-1:0] mem [0:DEPTH-1];

  always @(posedge clk) begin
    if (wr_en) begin
      mem[wr_addr] <= wr_data;
    end
  end

  reg[DATA_WIDTH-1:0] r_rd_data;
  always @(posedge clk) begin
    if (rd_en) begin
      r_rd_data <= mem[rd_addr];
    end
  end
  assign rd_data = r_rd_data;

endmodule

// Distributed RAM
module ingr_event_core_ram_dist #(
  parameter integer DATA_WIDTH  = 32,
  parameter integer DEPTH       = 32,
  parameter integer ADDR_WIDTH  = $clog2(DEPTH)
) (
  input   wire                  clk     ,
  input   wire                  wr_en   ,
  input   wire[ADDR_WIDTH-1:0]  wr_addr ,
  input   wire[DATA_WIDTH-1:0]  wr_data ,
  input   wire[ADDR_WIDTH-1:0]  rd_addr ,
  output  wire[DATA_WIDTH-1:0]  rd_data
);

  (* ram_style = "distributed" *) reg[DATA_WIDTH-1:0] mem [0:DEPTH-1];

  always @(posedge clk) begin
    if (wr_en) begin
      mem[wr_addr] <= wr_data;
    end
  end

  assign rd_data = mem[rd_addr];

endmodule

`default_nettype wire
