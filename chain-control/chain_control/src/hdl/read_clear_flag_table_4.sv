/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

module read_clear_flag_table_4 #(
  parameter int INDEX_WIDTH = 9,
  parameter int DATA_WIDTH  = 32
) (
  input   wire                  clk         ,
  input   wire                  rstn        ,
  output  wire                  init_done   ,
  input   wire                  in0_valid   ,
  input   wire[INDEX_WIDTH-1:0] in0_index   ,
  input   wire[DATA_WIDTH-1:0]  in0_value   ,
  input   wire                  in1_valid   ,
  input   wire[INDEX_WIDTH-1:0] in1_index   ,
  input   wire[DATA_WIDTH-1:0]  in1_value   ,
  input   wire                  in2_valid   ,
  input   wire[INDEX_WIDTH-1:0] in2_index   ,
  input   wire[DATA_WIDTH-1:0]  in2_value   ,
  input   wire                  in3_valid   ,
  input   wire[INDEX_WIDTH-1:0] in3_index   ,
  input   wire[DATA_WIDTH-1:0]  in3_value   ,
  input   wire                  rdreq_valid ,
  input   wire[INDEX_WIDTH-1:0] rdreq_index ,
  output  wire                  rdack_valid ,
  output  wire[DATA_WIDTH-1:0]  rdack_value ,
  input   wire[DATA_WIDTH-1:0]  force_value ,
  input   wire[DATA_WIDTH-1:0]  mask_value  ,
  output  wire                  non_zero    ,
  output  wire                  err_overflow
);

  localparam int NUM_ENTRIES = 1 << INDEX_WIDTH;

  localparam int NUM_QUEUES = 4;
  localparam int QUEUE_WIDTH = INDEX_WIDTH + DATA_WIDTH;
  localparam int QUEUE_DEPTH = 16;

  // State Code
  typedef enum {
    ST_RESET,
    ST_INIT ,
    ST_IDLE ,
    ST_SET  ,
    ST_READ ,
    ST_CLEAR
  } state_t;

  wire[NUM_QUEUES-1:0] w_push_ready;
  wire[NUM_QUEUES-1:0] w_push_valid;
  wire[INDEX_WIDTH-1:0] w_push_index[0:NUM_QUEUES-1];
  wire[DATA_WIDTH-1:0] w_push_value[0:NUM_QUEUES-1];

  assign w_push_valid[0] = in0_valid & ( | in0_value);
  assign w_push_index[0] = in0_index;
  assign w_push_value[0] = in0_value;

  assign w_push_valid[1] = in1_valid & ( | in1_value);
  assign w_push_index[1] = in1_index;
  assign w_push_value[1] = in1_value;

  assign w_push_valid[2] = in2_valid & ( | in2_value);
  assign w_push_index[2] = in2_index;
  assign w_push_value[2] = in2_value;

  assign w_push_valid[3] = in3_valid & ( | in3_value);
  assign w_push_index[3] = in3_index;
  assign w_push_value[3] = in3_value;

  reg r_err_overflow;
  always @(posedge clk) begin
    if (!rstn) begin
      r_err_overflow <= '0;
    end else begin
      r_err_overflow <= | (w_push_valid & ~ w_push_ready);
    end
  end
  assign err_overflow = r_err_overflow;

  wire[NUM_QUEUES-1:0] w_pop_ready;
  wire[NUM_QUEUES-1:0] w_pop_valid;
  wire[INDEX_WIDTH-1:0] w_pop_index[0:NUM_QUEUES-1];
  wire[DATA_WIDTH-1:0] w_pop_value[0:NUM_QUEUES-1];

  generate
    for (genvar i = 0; i < NUM_QUEUES; i++) begin : queues
      ram_fifo #(
        .DATA_WIDTH (QUEUE_WIDTH),
        .DEPTH      (QUEUE_DEPTH)
      ) u_queue (
        .rstn     (rstn             ), // input
        .clk      (clk              ), // input
        .afull    (/* open */       ), // output
        .aempty   (/* open */       ), // output
        .written  (/* open */       ), // output[SIZE_WIDTH-1:0]
        .readable (/* open */       ), // output[SIZE_WIDTH-1:0]
        .wr_ready (w_push_ready [i] ), // output
        .wr_valid (w_push_valid [i] ), // input
        .wr_data  ({w_push_index[i],
                    w_push_value[i]}), // input [DATA_WIDTH-1:0]
        .rd_ready (w_pop_ready  [i] ), // input
        .rd_valid (w_pop_valid  [i] ), // output
        .rd_data  ({w_pop_index [i],
                    w_pop_value [i]})  // output[DATA_WIDTH-1:0]
      );
    end
  endgenerate

  wire w_pop_acpt = | {w_pop_ready & w_pop_valid};

  // Latch read clear request
  wire w_rdreq_ready;
  reg r_rdreq_valid;
  reg[INDEX_WIDTH-1:0] r_rdreq_index;
  wire w_rdreq_acpt = w_rdreq_ready & r_rdreq_valid;
  always @(posedge clk) begin
    if (!rstn) begin
      r_rdreq_valid <= '0;
      r_rdreq_index <= '0;
    end else if (rdreq_valid) begin
      r_rdreq_valid <= '1;
      r_rdreq_index <= rdreq_index;
    end else if (w_rdreq_acpt) begin
      r_rdreq_valid <= '0;
    end
  end

  state_t r_state;
  reg[$clog2(NUM_QUEUES)-1:0] r_pop_sel;
  wire w_nop;
  reg r_init_done;

  // Select Event Queue
  always @(posedge clk) begin
    if (!rstn) begin
      r_pop_sel <= '0;
    end else if (w_nop || r_state == ST_CLEAR) begin
      if (r_pop_sel < NUM_QUEUES - 1) begin
        r_pop_sel <= r_pop_sel + 'd1;
      end else begin
        r_pop_sel <= '0;
      end
    end
  end

  // Event queue and read clear arbitration
  assign w_rdreq_ready = (r_state == ST_IDLE);
  assign w_pop_ready = (r_state == ST_IDLE && !r_rdreq_valid) ? (1 << r_pop_sel) : 0;
  assign w_nop = (r_state == ST_IDLE) && !w_rdreq_acpt && !w_pop_acpt;

  // State Machine
  always @(posedge clk) begin
    if (!rstn) begin
      r_state <= ST_RESET;
    end else begin
      case(r_state)
        ST_RESET:
          r_state <= ST_INIT;
        
        ST_INIT:
          if (r_init_done) begin
            r_state <= ST_IDLE;
          end
          
        ST_IDLE:
          if (w_rdreq_acpt) begin
            r_state <= ST_READ;
          end else if (w_pop_acpt) begin
            r_state <= ST_SET;
          end

        ST_SET:
          r_state <= ST_IDLE;

        ST_READ:
          r_state <= ST_CLEAR;

        ST_CLEAR:
          r_state <= ST_IDLE;

        default:
          r_state <= ST_RESET;
      endcase
    end
  end
  
  // Initialization
  reg[INDEX_WIDTH-1:0] r_init_addr;
  always @(posedge clk) begin
    if (!rstn) begin
      r_init_addr <= '0;
      r_init_done <= '0;
    end else if (r_state == ST_INIT && ! r_init_done) begin
      r_init_addr <= r_init_addr + 'd1;
      r_init_done <= (r_init_addr >= NUM_ENTRIES - 1);
    end
  end
  assign init_done = r_init_done;
  
  // RAM control
  reg[INDEX_WIDTH-1:0] r_ram_addr;
  reg[DATA_WIDTH-1:0] r_ram_wr_en;
  wire w_ram_wr_data = 
    ( ! r_init_done) ? '0 :
    (r_state == ST_SET) ? '1 : '0;
  wire[DATA_WIDTH-1:0] w_ram_rd_data;
  always @(posedge clk) begin
    if (!rstn) begin
      r_ram_addr <= '0;
    end else if (r_state == ST_INIT) begin
      r_ram_addr <= r_init_addr;
    end else if (w_rdreq_acpt) begin
      r_ram_addr <= r_rdreq_index;
    end else if (w_pop_acpt) begin
      r_ram_addr <= w_pop_index[r_pop_sel];
    end
  end
  
  always @(posedge clk) begin
    if (!rstn) begin
      r_ram_wr_en <= '0;
    end else if (r_state == ST_INIT && ! r_init_done) begin
      r_ram_wr_en <= {DATA_WIDTH{1'b1}};
    end else if (w_pop_acpt) begin
      r_ram_wr_en <= w_pop_value[r_pop_sel] & ~mask_value;
    end else if (r_state == ST_READ) begin
      r_ram_wr_en <= {DATA_WIDTH{1'b1}};
    end else begin
      r_ram_wr_en <= '0;
    end
  end
  
  // RAM instance
  generate
    for (genvar i = 0; i < DATA_WIDTH; i++) begin : bits
      read_clear_flag_table_4_ram #(
        .ADDR_WIDTH(INDEX_WIDTH)
      ) u_bit (
        .clk    (clk              ), // input
        .wr_en  (r_ram_wr_en[i]   ), // input
        .wr_addr(r_ram_addr       ), // input [ADDR_WIDTH-1:0]
        .rd_addr(r_ram_addr       ), // input [ADDR_WIDTH-1:0]
        .wr_data(w_ram_wr_data    ), // input
        .rd_data(w_ram_rd_data[i] )  // output
      );
    end
  endgenerate
  
  // force latch and read clear
  reg[DATA_WIDTH-1:0] r_force_lat;
  always @(posedge clk) begin
    if (!rstn) begin
      r_force_lat <= '0;
    end else if (r_state == ST_READ) begin
      r_force_lat <= '0;
    end else begin
      r_force_lat <= r_force_lat | (force_value & ~mask_value);
    end
  end
  
  // Non-zero flag
  reg[NUM_ENTRIES-1:0] r_non_zero_table;
  always @(posedge clk) begin
    if (!rstn) begin
      r_non_zero_table <= '0;
    end else if (r_state == ST_SET) begin
      r_non_zero_table[r_ram_addr] <= '1;
    end else if (r_state == ST_CLEAR) begin
      r_non_zero_table[r_ram_addr] <= '0;
    end
  end

  // Latch read results
  reg r_rdack_valid;
  reg[DATA_WIDTH-1:0] r_rdack_value;
  always @(posedge clk) begin
    if (!rstn) begin
      r_rdack_valid <= '0;
      r_rdack_value <= '0;
    end else if (r_state == ST_READ) begin
      r_rdack_valid <= '1;
      r_rdack_value <= w_ram_rd_data | r_force_lat;
    end else begin
      r_rdack_valid <= '0;
    end
  end
  assign rdack_valid = r_rdack_valid;
  assign rdack_value = r_rdack_value;
  
  // aggregation of non-zero flags
  reg r_non_zero_pre;
  reg r_non_zero;
  always @(posedge clk) begin
    if (!rstn) begin
      r_non_zero_pre <= '0;
      r_non_zero <= '0;
    end else begin
      r_non_zero_pre <= | r_non_zero_table;
      r_non_zero <= r_non_zero_pre | ( | r_force_lat);
    end
  end
  assign non_zero = r_non_zero;
  
endmodule

// RAM module
module read_clear_flag_table_4_ram #(
  parameter int ADDR_WIDTH = 10,
  parameter int DEPTH      = 1 << ADDR_WIDTH
) (
  input   wire                clk     ,
  input   wire                wr_en   ,
  input   wire[ADDR_WIDTH-1:0]wr_addr ,
  input   wire[ADDR_WIDTH-1:0]rd_addr ,
  input   wire                wr_data ,
  output  wire                rd_data
);

  (* ram_style = "distributed" *) reg mem[0:DEPTH-1];

  always @(posedge clk) begin
    if (wr_en) begin
      mem[wr_addr] <= wr_data;
    end
  end

  assign rd_data = mem[rd_addr];

endmodule

`default_nettype wire
