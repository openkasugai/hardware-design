/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

module latency_meas_core #(
  parameter int INDEX_WIDTH       = 9,
  parameter int SN_WIDTH          = 32
) (
  input   wire                  clk                 ,
  input   wire                  rstn                ,
  input   wire                  cfg_allow_overrun   ,
  input   wire                  start_valid         ,
  input   wire[INDEX_WIDTH-1:0] start_index         ,
  input   wire[SN_WIDTH-1:0]    start_sn            ,
  input   wire                  stop_valid          ,
  input   wire[INDEX_WIDTH-1:0] stop_index          ,
  input   wire[SN_WIDTH-1:0]    stop_sn             ,
  input   wire                  stop_discard        ,
  output  wire                  latency_valid       ,
  output  wire[47:0]            latency_data        ,
  output  wire                  err_start_queue_ovfl,
  output  wire                  err_stop_queue_ovfl ,
  output  wire                  err_stop_mishit     ,
  output  wire                  err_stop_overrun    ,
  output  wire                  err_panic
);

  localparam int NUM_ENTRIES = 1 << INDEX_WIDTH;

  localparam int QUEUE_DEPTH = 16;

  // Record of event queue
  typedef struct packed {
    logic                   discard;
    logic[INDEX_WIDTH-1:0]  index;
    logic[SN_WIDTH-1:0]     sn;
    logic[63:0]             clock;
  } event_t;

  // Record of the entry table
  typedef struct packed {
    logic[SN_WIDTH-1:0] sn;
    logic[63:0]         clock;
  } entry_t;

  // Measurement result
  typedef struct packed {
    logic[16-INDEX_WIDTH-1:0] reserved;
    logic[INDEX_WIDTH-1:0]    index;
    logic[31:0]               latency;
  } result_t;

  // State Code
  typedef enum {
    ST_RESET            ,
    ST_IDLE             ,
    ST_START_BUSY_CHECK ,
    ST_START_WRITE      ,
    ST_STOP_BUSY_CHECK  ,
    ST_STOP_READ_0      ,
    ST_STOP_READ_1      ,
    ST_STOP_READ_2      ,
    ST_STOP_JUDGE
  } state_t;

  //--------------------------------------------------------------------------------
  // Clock for measuring
  // split into lo and hi for timing closure

  reg[31:0] r_clock_lo;
  reg[31:0] r_clock_hi;
  always @(posedge clk) begin
    if (!rstn) begin
      r_clock_lo <= '0;
      r_clock_hi <= '0;
    end else begin
      r_clock_lo <= r_clock_lo + 'd1;
      if (r_clock_lo == 32'hffffffff) begin
        r_clock_hi <= r_clock_hi + 'd1;
      end
    end
  end
  wire[63:0] w_clock = { r_clock_hi, r_clock_lo };

  //--------------------------------------------------------------------------------
  // Event queue for start

  event_t w_start_push_event;
  always @(*) begin
    w_start_push_event.index   = start_index;
    w_start_push_event.sn      = start_sn;
    w_start_push_event.clock   = w_clock;
    w_start_push_event.discard = '0;
  end

  wire w_start_push_ready;
  wire w_start_pop_ready;
  wire w_start_pop_valid;
  event_t w_start_pop_event;
  ram_fifo #(
    .DATA_WIDTH ($bits(event_t) ),
    .DEPTH      (QUEUE_DEPTH    )
  ) u_start_queue (
    .rstn     (rstn               ), // input
    .clk      (clk                ), // input
    .afull    (/* open */         ), // output
    .aempty   (/* open */         ), // output
    .written  (/* open */         ), // output[SIZE_WIDTH-1:0]
    .readable (/* open */         ), // output[SIZE_WIDTH-1:0]
    .wr_ready (w_start_push_ready ), // output
    .wr_valid (start_valid        ), // input
    .wr_data  (w_start_push_event ), // input [DATA_WIDTH-1:0]
    .rd_ready (w_start_pop_ready  ), // input
    .rd_valid (w_start_pop_valid  ), // output
    .rd_data  (w_start_pop_event  )  // output[DATA_WIDTH-1:0]
  );

  //--------------------------------------------------------------------------------
  // Event queue for stop

  event_t w_stop_push_event;
  always @(*) begin
    w_stop_push_event.index    = stop_index;
    w_stop_push_event.sn       = stop_sn;
    w_stop_push_event.clock    = w_clock;
    w_stop_push_event.discard  = stop_discard;
  end

  wire w_stop_push_ready;
  wire w_stop_pop_ready;
  wire w_stop_pop_valid;
  event_t w_stop_pop_event;
  ram_fifo #(
    .DATA_WIDTH ($bits(event_t) ),
    .DEPTH      (QUEUE_DEPTH    )
  ) u_stop_queue (
    .rstn     (rstn             ), // input
    .clk      (clk              ), // input
    .afull    (/* open */       ), // output
    .aempty   (/* open */       ), // output
    .written  (/* open */       ), // output[SIZE_WIDTH-1:0]
    .readable (/* open */       ), // output[SIZE_WIDTH-1:0]
    .wr_ready (w_stop_push_ready), // output
    .wr_valid (stop_valid       ), // input
    .wr_data  (w_stop_push_event), // input [DATA_WIDTH-1:0]
    .rd_ready (w_stop_pop_ready ), // input
    .rd_valid (w_stop_pop_valid ), // output
    .rd_data  (w_stop_pop_event )  // output[DATA_WIDTH-1:0]
  );

  //--------------------------------------------------------------------------------
  // State Machine

  state_t r_state;
  event_t w_event_raw;
  event_t r_event_lat;
  wire w_start_strb;
  wire w_stop_strb;
  wire w_busy_release;

  // start/stop arbitration
  // Prioritize stop to reduce queue congestion
  assign w_start_pop_ready = (r_state == ST_IDLE) && !w_stop_pop_valid;
  assign w_stop_pop_ready = (r_state == ST_IDLE);
  assign w_start_strb = w_start_pop_valid & w_start_pop_ready;
  assign w_stop_strb = w_stop_pop_valid & w_stop_pop_ready;

  // Select Events
  always @(*) begin
    if (w_start_strb) begin
      w_event_raw = w_start_pop_event;
    end else if (w_stop_strb) begin
      w_event_raw = w_stop_pop_event;
    end else begin
      w_event_raw = '0;
    end
  end

  // Latching events
  always @(posedge clk) begin
    if (!rstn) begin
      r_event_lat <= '0;
    end else if (w_start_strb || w_stop_strb) begin
      r_event_lat <= w_event_raw;
    end
  end

  // Busy Flag Table
  reg[NUM_ENTRIES-1:0] r_busy_table;
  always @(posedge clk) begin
    if (!rstn) begin
      r_busy_table <= '0;
    end else if (r_state == ST_START_WRITE) begin
      r_busy_table[r_event_lat.index] = '1;
    end else if (w_busy_release) begin
      r_busy_table[r_event_lat.index] = '0;
    end
  end

  // Read busy flag table
  reg r_busy;
  always @(posedge clk) begin
    if (!rstn) begin
      r_busy <= '0;
    end else begin
      r_busy <= r_busy_table[w_event_raw.index];
    end
  end

  // State Machine
  always @(posedge clk) begin
    if (!rstn) begin
      r_state <= ST_RESET;
    end else begin
      case(r_state)
        ST_RESET:
          r_state <= ST_IDLE;

        ST_IDLE:
          if (w_start_strb) begin
            r_state <= ST_START_BUSY_CHECK;
          end else if (w_stop_strb) begin
            r_state <= ST_STOP_BUSY_CHECK;
          end

        ST_START_BUSY_CHECK:
          if (r_busy) begin
            r_state <= ST_IDLE;
          end else begin
            r_state <= ST_START_WRITE;
          end

        ST_START_WRITE:
          r_state <= ST_IDLE;

        ST_STOP_BUSY_CHECK:
          if (r_busy) begin
            r_state <= ST_STOP_READ_0;
          end else begin
            r_state <= ST_IDLE;
          end

        ST_STOP_READ_0:
          r_state <= ST_STOP_READ_1;

        ST_STOP_READ_1:
          r_state <= ST_STOP_READ_2;

        ST_STOP_READ_2:
          r_state <= ST_STOP_JUDGE;
        
        ST_STOP_JUDGE:
          r_state <= ST_IDLE;

        default:
          r_state <= ST_RESET;

      endcase
    end
  end

  //--------------------------------------------------------------------------------
  // Entry table

  wire                  w_table_wr_en;
  wire[INDEX_WIDTH-1:0] w_table_wr_addr;
  entry_t               w_table_wr_data;
  wire[INDEX_WIDTH-1:0] w_table_rd_addr;
  entry_t               w_table_rd_data;
  reg                   r_table_rd_valid;

  // Table Write
  assign w_table_wr_en = (r_state == ST_START_WRITE);
  assign w_table_wr_addr = r_event_lat.index;
  always @(*) begin
    w_table_wr_data.clock = r_event_lat.clock;
    w_table_wr_data.sn    = r_event_lat.sn;
  end
  
  // Table Read
  assign w_table_rd_addr = r_event_lat.index;
  always @(posedge clk) begin
    if (!rstn) begin
      r_table_rd_valid <= '0;
    end else begin
      r_table_rd_valid <= (r_state == ST_STOP_READ_2);
    end
  end
  
  // Table
  ram_sdp #(
    .DATA_WIDTH ($bits(entry_t) ),
    .DEPTH      (NUM_ENTRIES    )
  ) u_table (
    .clk    (clk            ), // input   wire
    .wr_en  (w_table_wr_en  ), // input   wire
    .wr_addr(w_table_wr_addr), // input   wire[ADDR_WIDTH-1:0]
    .wr_data(w_table_wr_data), // input   wire[DATA_WIDTH-1:0]
    .rd_en  ('1             ), // input   wire
    .rd_addr(w_table_rd_addr), // input   wire[ADDR_WIDTH-1:0]
    .rd_data(w_table_rd_data)  // output  wire[DATA_WIDTH-1:0]
  );

  //--------------------------------------------------------------------------------
  // SN catch-up detection and discard judgment
  
  reg w_judge_release;
  reg w_judge_success;
  reg w_judge_overrun;
  always @(*) begin
    if (r_table_rd_valid) begin
      reg[SN_WIDTH-1:0] v_diff;
      reg v_match;
      reg v_overrun;
      v_diff = w_table_rd_data.sn - r_event_lat.sn;
      v_match = (v_diff == 0); // SN match
      v_overrun = v_diff[SN_WIDTH-1]; // SN overrun (negative diff)
      if (r_event_lat.discard) begin
        // Discard
        w_judge_release = '1; // Release busy
        w_judge_success = '0; // Latency calculation failed
        w_judge_overrun = '0;
      end else begin
        // Release busy on match or overrun
        w_judge_release = v_match | v_overrun;
        
        // Latency can be calculated if the catch-up condition is satisfied
        w_judge_success = cfg_allow_overrun ? (v_match | v_overrun) : v_match;
        
        // Unexpected overrun
        w_judge_overrun = ! cfg_allow_overrun && v_overrun;
      end
    end else begin
      w_judge_release = '0;
      w_judge_success = '0;
      w_judge_overrun = '0;
    end
  end
  
  // Busy release detection
  assign w_busy_release = w_judge_release;
  
  //--------------------------------------------------------------------------------
  // Latency calculation
  
  reg[31:0] r_result_pre_latency;
  reg[INDEX_WIDTH-1:0] r_result_pre_index;
  reg r_result_pre_reverse;
  reg r_result_pre_valid;
  always @(posedge clk) begin
    if (!rstn) begin
      r_result_pre_latency <= '0;
      r_result_pre_index <= '0;
      r_result_pre_reverse <= '0;
      r_result_pre_valid <= '0;
    end else if (r_table_rd_valid) begin
      // subtract start event time from stop event time
      if (r_event_lat.clock < w_table_rd_data.clock) begin
        r_result_pre_latency <= '0; // Latency is negative
        r_result_pre_reverse <= '1;
      end else if (r_event_lat.clock - w_table_rd_data.clock <= 64'h00000000ffffffff) begin
        r_result_pre_latency <= r_event_lat.clock - w_table_rd_data.clock;
        r_result_pre_reverse <= '0;
      end else begin
        r_result_pre_latency <= 32'hffffffff; // Saturated
        r_result_pre_reverse <= '0;
      end
      r_result_pre_index <= r_event_lat.index;
      r_result_pre_valid <= w_judge_success;
    end else begin
      r_result_pre_reverse <= '0;
      r_result_pre_valid <= '0;
    end
  end
  
  // Delay 1 cycle for timing closure (expecting FF retiming)
  result_t r_result_data;
  reg r_result_valid;
  always @(posedge clk) begin
    if (!rstn) begin
      r_result_data <= '0;
      r_result_valid <= '0;
    end else begin
      r_result_data.latency <= r_result_pre_latency;
      r_result_data.index <= r_result_pre_index;
      r_result_valid <= r_result_pre_valid & ~r_result_pre_reverse;
    end
  end
  
  // Output
  assign latency_data = r_result_data;
  assign latency_valid = r_result_valid;
  
  //--------------------------------------------------------------------------------
  // Error detection (for debug)
  reg r_err_start_queue_ovfl;
  reg r_err_stop_queue_ovfl;
  reg r_err_stop_mishit;
  reg r_err_stop_overrun;
  reg r_err_panic;
  always @(posedge clk) begin
    if (!rstn) begin
      r_err_start_queue_ovfl <= '0;
      r_err_stop_queue_ovfl <= '0;
      r_err_stop_mishit <= '0;
      r_err_stop_overrun <= '0;
      r_err_panic <= '0;
    end else begin
      r_err_start_queue_ovfl <= start_valid & ~w_start_push_ready;
      r_err_stop_queue_ovfl <= stop_valid & ~w_stop_push_ready;
      r_err_stop_mishit <= (r_state == ST_STOP_BUSY_CHECK) && !r_busy;
      r_err_stop_overrun <= w_judge_overrun;
      r_err_panic <= r_result_pre_valid & r_result_pre_reverse;
    end
  end
  assign err_start_queue_ovfl = r_err_start_queue_ovfl;
  assign err_stop_queue_ovfl = r_err_stop_queue_ovfl;
  assign err_stop_mishit = r_err_stop_mishit;
  assign err_stop_overrun = r_err_stop_overrun;
  assign err_panic = r_err_panic;

endmodule

`default_nettype wire
