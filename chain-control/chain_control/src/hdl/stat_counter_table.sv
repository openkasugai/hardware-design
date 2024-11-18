/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

`timescale 1ns/100ps
`default_nettype none

module stat_counter_table #(
  parameter int INDEX_WIDTH   = 10,
  parameter int COUNTER_WIDTH = 64,
  parameter int ADD_WIDTH     = 7
) (
  input   wire                    clk         ,
  input   wire                    rstn        ,
  output  wire                    init_done   ,
  input   wire                    add_valid   ,
  input   wire[INDEX_WIDTH-1:0]   add_index   ,
  input   wire[ADD_WIDTH-1:0]     add_value   ,
  input   wire                    rdreq_valid ,
  input   wire[INDEX_WIDTH-1:0]   rdreq_index ,
  output  wire                    rdack_valid ,
  output  wire[COUNTER_WIDTH-1:0] rdack_value
);
  
  localparam int NUM_ENTRIES = 1 << INDEX_WIDTH;
  
  localparam int NUM_STAGES = 6;
  
  localparam int CMD_WIDTH  = 2;
  localparam int CMD_ADD    = 0;
  localparam int CMD_CLR    = 1;
  
  // Addition input FF
  reg                   r_add_valid;
  reg[INDEX_WIDTH-1:0]  r_add_index;
  reg[ADD_WIDTH-1:0]    r_add_value;
  always @(posedge clk) begin
    if (!rstn) begin
      r_add_valid <= '0;
      r_add_index <= '0;
      r_add_value <= '0;
    end else begin
      r_add_valid <= add_valid;
      r_add_index <= add_index;
      r_add_value <= add_value;
    end
  end
  
  // Read clear request input FF
  // Latch on valid=1 and clear on ready=1
  reg                   w_rdreq_acpt;
  reg                   r_rdreq_valid;
  reg[INDEX_WIDTH-1:0]  r_rdreq_index;
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
  
  // addition command insertion control signal
  reg[NUM_STAGES-1:0]   w_ins_add_stage;
  reg[INDEX_WIDTH-1:0]  w_ins_add_idx;
  reg[ADD_WIDTH-1:0]    w_ins_add_val;
  
  // Read clear command insertion control signal
  reg[NUM_STAGES-1:0]   w_ins_clr_stage;
  reg[INDEX_WIDTH-1:0]  w_ins_clr_idx;
  
  // Signal common to all stages
  reg[CMD_WIDTH-1:0]      r_s_cmd [0:NUM_STAGES-1];
  reg[INDEX_WIDTH-1:0]    r_s_idx [0:NUM_STAGES-1];
  reg[COUNTER_WIDTH-1:0]  r_s_val [0:NUM_STAGES-1];
  
  // Signals specific to each stage
  wire[INDEX_WIDTH-1:0]   w_ram_rd_addr;
  wire[COUNTER_WIDTH-1:0] w_ram_rd_data;
  reg                     r_ram_wr_en;
  wire[INDEX_WIDTH-1:0]   w_ram_wr_addr;
  reg[COUNTER_WIDTH-1:0]  r_ram_wr_data;
  
  // RAM initialization counter
  reg[INDEX_WIDTH-1:0]    r_init_addr;
  reg                     r_init_done;
  
  // Function to determine which stage to insert the command into
  function [NUM_STAGES-1:0] f_determine_insert_stage(
    input[INDEX_WIDTH-1:0] index
  );
    reg[NUM_STAGES-1:0] v_stage;
    reg v_found;
    v_stage = '0;
    v_found = '0;
    // Looks for work on the same index already in progress during stage 0..4
    for (int i = 0; i < NUM_STAGES - 1; i++) begin
      if (r_s_cmd[i] != '0 && r_s_idx[i] == index) begin
        v_found = '1;
        if (i < NUM_STAGES - 2) begin
          // If found before stage 4, merge in the next stage
          v_stage[i + 1] = '1;
        end else begin
          // Insert into first stage if found in stage 4
          v_stage[0] = '1;
        end
        break;
      end
    end
    if (!v_found) begin
      // If not found,
      if (r_s_cmd[0] == '0) begin
        // If Stage 1 becomes available in the next cycle, put it in there.
        v_stage[1] = '1;
      end else begin
        // If stage 1 doesn't open up, put it in stage 0.
        v_stage[0] = '1;
      end
    end
    return v_stage;
  endfunction
  
  // Stage selection control
  always_comb begin
    w_ins_add_stage = '0;
    w_ins_add_idx = '0;
    w_ins_add_val = '0;
    w_ins_clr_stage = '0;
    w_ins_clr_idx = '0;
    w_rdreq_acpt = '0;
    
    if (r_add_valid) begin
      // Determine where to insert addition commands
      w_ins_add_stage = f_determine_insert_stage(r_add_index);
      w_ins_add_idx = r_add_index;
      w_ins_add_val = r_add_value;
    end
    
    if (r_rdreq_valid) begin
      // Determine where to insert the read clear command
      reg[NUM_STAGES-1:0] v_stage;
      v_stage = f_determine_insert_stage(r_rdreq_index);
      // avoid conflicts with addition commands
      if (v_stage != w_ins_add_stage || r_add_index == r_rdreq_index) begin
        w_rdreq_acpt = '1;
        w_ins_clr_stage = v_stage;
        w_ins_clr_idx = r_rdreq_index;
      end
    end
  end
  
  // Processing of each stage
  always @(posedge clk) begin
    if (!rstn) begin
      r_init_done <= '0;
      r_init_addr <= '0;
      for (int i = 0; i < NUM_STAGES; i++) begin
        r_s_cmd[i] <= '0;
        r_s_idx[i] <= '0;
        r_s_val[i] <= '0;
      end
      r_ram_wr_en <= '0;
      r_ram_wr_data <= '0;
    end else if (!r_init_done) begin
      // Initialize RAM
      r_init_addr <= r_init_addr + 'd1;
      r_init_done <= (r_init_addr >= NUM_ENTRIES - 1);
      r_ram_wr_en <= '1;
      r_ram_wr_data <= '0;
      r_s_idx[NUM_STAGES-1] <= r_init_addr;
    end else begin
      // Stage 0
      r_s_cmd[0][CMD_ADD] <= w_ins_add_stage[0];
      r_s_cmd[0][CMD_CLR] <= w_ins_clr_stage[0];
      if (w_ins_add_stage[0]) begin
        r_s_idx[0] <= w_ins_add_idx;
        r_s_val[0] <= w_ins_add_val;
      end else if (w_ins_clr_stage[0]) begin
        r_s_idx[0] <= w_ins_clr_idx;
        r_s_val[0] <= '0;
      end else begin
        r_s_idx[0] <= '0;
        r_s_val[0] <= '0;
      end
      
      // Stage 1.
      r_s_cmd[1][CMD_ADD] <= r_s_cmd[0][CMD_ADD] | w_ins_add_stage[1];
      r_s_cmd[1][CMD_CLR] <= r_s_cmd[0][CMD_CLR] | w_ins_clr_stage[1];
      if (w_ins_add_stage[1]) begin
        r_s_idx[1] <= w_ins_add_idx;
      end else if (w_ins_clr_stage[1]) begin
        r_s_idx[1] <= w_ins_clr_idx;
      end else begin
        r_s_idx[1] <= r_s_idx[0];
      end
      if (w_ins_add_stage[1]) begin
        r_s_val[1] <= r_s_val[0] + w_ins_add_val;
      end else begin
        r_s_val[1] <= r_s_val[0];
      end
      
      // Stage 2...5
      for (int i = 2; i < NUM_STAGES-1; i++) begin
        r_s_cmd[i][CMD_ADD] <= r_s_cmd[i-1][CMD_ADD] | w_ins_add_stage[i];
        r_s_cmd[i][CMD_CLR] <= r_s_cmd[i-1][CMD_CLR] | w_ins_clr_stage[i];
        r_s_idx[i] <= r_s_idx[i-1];
        if (w_ins_add_stage[i]) begin
          r_s_val[i] <= r_s_val[i-1] + w_ins_add_val;
        end else begin
          r_s_val[i] <= r_s_val[i-1];
        end
      end
      
      // Final stage
      begin
        reg[COUNTER_WIDTH-1:0] v_val;
        r_s_cmd[NUM_STAGES-1][CMD_ADD] <= r_s_cmd[NUM_STAGES-2][CMD_ADD];
        r_s_cmd[NUM_STAGES-1][CMD_CLR] <= r_s_cmd[NUM_STAGES-2][CMD_CLR];
        r_s_idx[NUM_STAGES-1] <= r_s_idx[NUM_STAGES-2];
        
        // Read-Modify-Write
        v_val = w_ram_rd_data;
        if (r_s_cmd[NUM_STAGES-2][CMD_ADD]) begin
          v_val += r_s_val[NUM_STAGES-2];
        end
        r_s_val[NUM_STAGES-1] <= v_val;
        if (r_s_cmd[NUM_STAGES-2][CMD_CLR]) begin
          v_val = '0;
        end
        r_ram_wr_data <= v_val;
        r_ram_wr_en <= | r_s_cmd[NUM_STAGES-2];
      end
    end
  end
  
  assign w_ram_rd_addr = r_s_idx[2];
  assign w_ram_wr_addr = r_s_idx[NUM_STAGES-1];
  stat_counter_table_sdpram #(
    .DATA_WIDTH (COUNTER_WIDTH),
    .ADDR_WIDTH (INDEX_WIDTH  )
  ) u_ram (
    .clk    (clk          ), // input
    .wr_en  (r_ram_wr_en  ), // input
    .wr_addr(w_ram_wr_addr), // input [ADDR_WIDTH-1:0]
    .wr_data(r_ram_wr_data), // input [DATA_WIDTH-1:0]
    .rd_en  (1'b1         ), // input
    .rd_addr(w_ram_rd_addr), // input [ADDR_WIDTH-1:0]
    .rd_data(w_ram_rd_data)  // output[DATA_WIDTH-1:0]
  );
  
  // Read clear response
  assign rdack_valid = r_s_cmd[NUM_STAGES-1][CMD_CLR];
  assign rdack_value = r_s_val[NUM_STAGES-1];
  
  // Initialization completion signal
  assign init_done = r_init_done;
  
endmodule

// RAM module
module stat_counter_table_sdpram #(
  parameter int DATA_WIDTH = 32,
  parameter int ADDR_WIDTH = 10,
  parameter int DEPTH      = 1 << ADDR_WIDTH
) (
  input   wire                  clk     ,
  input   wire                  wr_en   ,
  input   wire[ADDR_WIDTH-1:0]  wr_addr ,
  input   wire[DATA_WIDTH-1:0]  wr_data ,
  input   wire                  rd_en   ,
  input   wire[ADDR_WIDTH-1:0]  rd_addr ,
  output  wire[DATA_WIDTH-1:0]  rd_data
);

reg[DATA_WIDTH-1:0] mem [0:DEPTH-1];

logic r_wr_en;
logic[ADDR_WIDTH-1:0] r_wr_addr;
logic[DATA_WIDTH-1:0] r_wr_data;
always_ff @(posedge clk) begin
  r_wr_en <= wr_en;
  r_wr_addr <= wr_addr;
  r_wr_data <= wr_data;
end

always_ff @(posedge clk) begin
  if (r_wr_en) begin
    mem[r_wr_addr] <= r_wr_data;
  end
end

logic[ADDR_WIDTH-1:0] r_rd_addr;
logic[DATA_WIDTH-1:0] r_rd_data;
always_ff @(posedge clk) begin
  if (rd_en) begin
    r_rd_addr <= rd_addr;
    r_rd_data <= mem[r_rd_addr];
  end
end
assign rd_data = r_rd_data;

endmodule

`default_nettype wire
