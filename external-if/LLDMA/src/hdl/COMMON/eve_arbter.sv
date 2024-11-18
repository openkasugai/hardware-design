/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module eve_arbter #(
   parameter CHAIN_NUM  = 1
  )(
  input  wire         user_clk,
  input  wire         reset_n,
  input  wire         s_axis_cd_transfer_eve_tvalid,
  input  wire [127:0] s_axis_cd_transfer_eve_tdata,
  output wire         s_axis_cd_transfer_eve_tready,
  input  wire         s_axis_cu_transfer_eve_tvalid,
  input  wire [127:0] s_axis_cu_transfer_eve_tdata,
  output wire         s_axis_cu_transfer_eve_tready,
  output wire         m_axis_transfer_eve_tvalid,
  output wire [127:0] m_axis_transfer_eve_tdata,
  input  wire         m_axis_transfer_eve_tready,
  output wire         m_axis_cd_transfer_cmd_tvalid,
  output wire  [63:0] m_axis_cd_transfer_cmd_tdata,
  input  wire         m_axis_cd_transfer_cmd_tready,
  output wire         m_axis_cu_transfer_cmd_tvalid,
  output wire  [63:0] m_axis_cu_transfer_cmd_tdata,
  input  wire         m_axis_cu_transfer_cmd_tready,
  input  wire         s_axis_transfer_cmd_tvalid,
  input  wire  [63:0] s_axis_transfer_cmd_tdata,
  output wire         s_axis_transfer_cmd_tready,
  input  wire   [7:0] dma_rx_ch_connection_enable,
  input  wire   [7:0] dma_tx_ch_connection_enable
);

//localparam CHAIN_ID_0  = 16'h0200 + (16'h0008 * (CHAIN_NUM-1));
localparam CHAIN_ID_0  = (16'h0008 * (CHAIN_NUM-1));
localparam CHAIN_ID_1  = CHAIN_ID_0+1;
localparam CHAIN_ID_2  = CHAIN_ID_0+2;
localparam CHAIN_ID_3  = CHAIN_ID_0+3;
localparam CHAIN_ID_4  = CHAIN_ID_0+4;
localparam CHAIN_ID_5  = CHAIN_ID_0+5;
localparam CHAIN_ID_6  = CHAIN_ID_0+6;
localparam CHAIN_ID_7  = CHAIN_ID_0+7;

localparam RECV_EVE   = 16'h04;
localparam SEND_EVE   = 16'h08;

localparam TCP_EVENT_ESTABLISHED   = 16'h0001;
localparam TCP_EVENT_RECV_RST      = 16'h0200;

localparam ESTABLISHED_DATA_ID_0   = {{32{1'b0}},CHAIN_ID_0,TCP_EVENT_ESTABLISHED,{64{1'b0}}};
localparam ESTABLISHED_DATA_ID_1   = {{32{1'b0}},CHAIN_ID_1,TCP_EVENT_ESTABLISHED,{64{1'b0}}};
localparam ESTABLISHED_DATA_ID_2   = {{32{1'b0}},CHAIN_ID_2,TCP_EVENT_ESTABLISHED,{64{1'b0}}};
localparam ESTABLISHED_DATA_ID_3   = {{32{1'b0}},CHAIN_ID_3,TCP_EVENT_ESTABLISHED,{64{1'b0}}};
localparam ESTABLISHED_DATA_ID_4   = {{32{1'b0}},CHAIN_ID_4,TCP_EVENT_ESTABLISHED,{64{1'b0}}};
localparam ESTABLISHED_DATA_ID_5   = {{32{1'b0}},CHAIN_ID_5,TCP_EVENT_ESTABLISHED,{64{1'b0}}};
localparam ESTABLISHED_DATA_ID_6   = {{32{1'b0}},CHAIN_ID_6,TCP_EVENT_ESTABLISHED,{64{1'b0}}};
localparam ESTABLISHED_DATA_ID_7   = {{32{1'b0}},CHAIN_ID_7,TCP_EVENT_ESTABLISHED,{64{1'b0}}};

localparam RECV_RST_DATA_ID_0   = {{32{1'b0}},CHAIN_ID_0,TCP_EVENT_RECV_RST,{64{1'b0}}};
localparam RECV_RST_DATA_ID_1   = {{32{1'b0}},CHAIN_ID_1,TCP_EVENT_RECV_RST,{64{1'b0}}};
localparam RECV_RST_DATA_ID_2   = {{32{1'b0}},CHAIN_ID_2,TCP_EVENT_RECV_RST,{64{1'b0}}};
localparam RECV_RST_DATA_ID_3   = {{32{1'b0}},CHAIN_ID_3,TCP_EVENT_RECV_RST,{64{1'b0}}};
localparam RECV_RST_DATA_ID_4   = {{32{1'b0}},CHAIN_ID_4,TCP_EVENT_RECV_RST,{64{1'b0}}};
localparam RECV_RST_DATA_ID_5   = {{32{1'b0}},CHAIN_ID_5,TCP_EVENT_RECV_RST,{64{1'b0}}};
localparam RECV_RST_DATA_ID_6   = {{32{1'b0}},CHAIN_ID_6,TCP_EVENT_RECV_RST,{64{1'b0}}};
localparam RECV_RST_DATA_ID_7   = {{32{1'b0}},CHAIN_ID_7,TCP_EVENT_RECV_RST,{64{1'b0}}};

reg         sr_s_axis_cd_transfer_eve_tvalid;
reg [127:0] sr_s_axis_cd_transfer_eve_tdata;
reg         sr_s_axis_cu_transfer_eve_tvalid;
reg [127:0] sr_s_axis_cu_transfer_eve_tdata;

reg         sr_transfer_eve_marge_tvalid;
reg [127:0] sr_transfer_eve_marge_tdata;

reg         sr_rr_flag;

reg   [7:0] sr_dma_rx_ch_connection_enable;
reg   [7:0] sr_dma_tx_ch_connection_enable;
reg   [7:0] sr_dma_ch_connection_enable;
reg   [7:0] sr_dma_ch_connection_enable_1d;

reg   [7:0] sr_ch_enable_flag;
reg   [7:0] sr_ch_mode_flag;

reg         sr_axis_transfer_eve_out_tvalid;
reg [127:0] sr_axis_transfer_eve_out_tdata;

// CMD signal
reg         sr_s_axis_transfer_cmd_tvalid;
reg  [63:0] sr_s_axis_transfer_cmd_tdata;

reg         sr_m_axis_cd_transfer_cmd_tvalid;
reg  [63:0] sr_m_axis_cd_transfer_cmd_tdata;
reg         sr_m_axis_cu_transfer_cmd_tvalid;
reg  [63:0] sr_m_axis_cu_transfer_cmd_tdata;



integer i;

function [8:0] fn_adopt_route;
   input [8:0] enable_route;
   input       valid;
   input [7:0] ready;
   begin
      if(!valid || ready)begin
        case (enable_route) inside
           9'b?_???????1 : fn_adopt_route = 9'b0_00000001;  
           9'b?_??????10 : fn_adopt_route = 9'b0_00000010; 
           9'b?_?????100 : fn_adopt_route = 9'b0_00000100; 
           9'b?_????1000 : fn_adopt_route = 9'b0_00001000; 
           9'b?_???10000 : fn_adopt_route = 9'b0_00010000; 
           9'b?_??100000 : fn_adopt_route = 9'b0_00100000; 
           9'b?_?1000000 : fn_adopt_route = 9'b0_01000000; 
           9'b?_10000000 : fn_adopt_route = 9'b0_10000000; 
           9'b1_00000000 : fn_adopt_route = 9'b1_00000000;
           default       : fn_adopt_route = {9{1'b0}}; // Unconditional
        endcase
      end else begin
        fn_adopt_route = {9{1'b0}};
      end
   end
endfunction

wire [8:0] w_adopt_route;
assign w_adopt_route = fn_adopt_route({sr_transfer_eve_marge_tvalid,sr_ch_enable_flag},sr_axis_transfer_eve_out_tvalid,m_axis_transfer_eve_tready);

function [1:0] fn_adopt_route_up_dn;
   input       marge_tvalid;
   input       adopt_route;
   input       rr_flag;
   input       cd_transfer_eve_tvalid;
   input       cu_transfer_eve_tvalid;
   begin
        if(!marge_tvalid || adopt_route)begin
          if(rr_flag)begin // dn priority
            if(cd_transfer_eve_tvalid)begin
              fn_adopt_route_up_dn = 2'b01;
            end else if(cu_transfer_eve_tvalid)begin
              fn_adopt_route_up_dn = 2'b10;
            end else begin
              fn_adopt_route_up_dn = 2'b00;
            end
          end else begin// up priority
            if(cu_transfer_eve_tvalid)begin
              fn_adopt_route_up_dn = 2'b10;
            end else if(cd_transfer_eve_tvalid)begin
              fn_adopt_route_up_dn = 2'b01;
            end else begin
              fn_adopt_route_up_dn = 2'b00;
            end
          end
        end else begin
          fn_adopt_route_up_dn = 2'b00;
        end
   end
endfunction

wire [1:0] w_adopt_route_up_dn;
assign w_adopt_route_up_dn = fn_adopt_route_up_dn(sr_transfer_eve_marge_tvalid,w_adopt_route[8],sr_rr_flag,sr_s_axis_cd_transfer_eve_tvalid,sr_s_axis_cu_transfer_eve_tvalid);

// CH enable state
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_dma_rx_ch_connection_enable    <= {8{1'b0}};
    sr_dma_tx_ch_connection_enable    <= {8{1'b0}};
    sr_dma_ch_connection_enable       <= {8{1'b0}};
    sr_dma_ch_connection_enable_1d    <= {8{1'b0}};
  end else begin
    sr_dma_rx_ch_connection_enable    <= dma_rx_ch_connection_enable;
    sr_dma_tx_ch_connection_enable    <= dma_tx_ch_connection_enable;
    for(i = 0; i < 8; i = i + 1) begin
      if((sr_dma_rx_ch_connection_enable[i]==1'b0) && (sr_dma_tx_ch_connection_enable[i]==1'b0))begin
        sr_dma_ch_connection_enable[i]  <= 1'b0;
      end else if((sr_dma_rx_ch_connection_enable[i]==1'b1) && (sr_dma_tx_ch_connection_enable[i]==1'b1))begin
        sr_dma_ch_connection_enable[i]  <= 1'b1;
      end else begin
        sr_dma_ch_connection_enable[i]  <= sr_dma_ch_connection_enable[i];
      end
    end
    sr_dma_ch_connection_enable_1d <= sr_dma_ch_connection_enable;
  end
end

// ESTABLISHED RECV_RST Prepare to Issue
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_ch_mode_flag   <= {8{1'b0}}; //0:ESTABLISHED,1:RECV_RST
    sr_ch_enable_flag <= {8{1'b0}};
  end else begin
    for(i = 0; i < 8; i = i + 1) begin
      // est or rcv_rst output flag
      if(w_adopt_route[i])begin
        sr_ch_enable_flag[i] <= 1'b0;
      end else begin
        if((sr_dma_ch_connection_enable_1d[i] == 1'b0)&&(sr_dma_ch_connection_enable[i] == 1'b1))begin
          sr_ch_enable_flag[i] <= 1'b1;
        end else if((sr_dma_ch_connection_enable_1d[i] == 1'b1)&&(sr_dma_ch_connection_enable[i] == 1'b0))begin
          sr_ch_enable_flag[i] <= 1'b1;
        end else begin
          sr_ch_enable_flag[i] <= sr_ch_enable_flag[i];
        end
      end
      
      //mode
      if((sr_dma_ch_connection_enable_1d[i] == 1'b0)&&(sr_dma_ch_connection_enable[i] == 1'b1))begin
        sr_ch_mode_flag[i] <= 1'b0;
      end else if((sr_dma_ch_connection_enable_1d[i] == 1'b1)&&(sr_dma_ch_connection_enable[i] == 1'b0))begin
        sr_ch_mode_flag[i] <= 1'b1;
      end else begin
        sr_ch_mode_flag[i] <= sr_ch_mode_flag[i];
      end
    end
  end
end

// Get eve
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_s_axis_cd_transfer_eve_tvalid <= 1'b0;
    sr_s_axis_cd_transfer_eve_tdata  <= {128{1'b0}};
    sr_s_axis_cu_transfer_eve_tvalid <= 1'b0;
    sr_s_axis_cu_transfer_eve_tdata  <= {128{1'b0}};
  end else begin
    if(!sr_s_axis_cd_transfer_eve_tvalid || w_adopt_route_up_dn[0])begin
      sr_s_axis_cd_transfer_eve_tvalid <= s_axis_cd_transfer_eve_tvalid;
      sr_s_axis_cd_transfer_eve_tdata  <= s_axis_cd_transfer_eve_tdata;
    end else begin
      sr_s_axis_cd_transfer_eve_tvalid <= sr_s_axis_cd_transfer_eve_tvalid;
      sr_s_axis_cd_transfer_eve_tdata  <= sr_s_axis_cd_transfer_eve_tdata;
    end
    
    if(!sr_s_axis_cu_transfer_eve_tvalid || w_adopt_route_up_dn[1])begin
      sr_s_axis_cu_transfer_eve_tvalid <= s_axis_cu_transfer_eve_tvalid;
      sr_s_axis_cu_transfer_eve_tdata  <= s_axis_cu_transfer_eve_tdata;
    end else begin
      sr_s_axis_cu_transfer_eve_tvalid <= sr_s_axis_cu_transfer_eve_tvalid;
      sr_s_axis_cu_transfer_eve_tdata  <= sr_s_axis_cu_transfer_eve_tdata;
    end
  end
end

// RR Select
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_transfer_eve_marge_tvalid <= 1'b0;
    sr_transfer_eve_marge_tdata  <= {128{1'b0}};
    sr_rr_flag                    <= 1'b0;
  end else begin
    if(!sr_transfer_eve_marge_tvalid || w_adopt_route[8])begin
      if(sr_rr_flag)begin // dn priority
        if(sr_s_axis_cd_transfer_eve_tvalid)begin
          sr_transfer_eve_marge_tvalid <= 1'b1;
          //sr_transfer_eve_marge_tdata  <= {sr_s_axis_cd_transfer_eve_tdata[127:80],RECV_EVE,sr_s_axis_cd_transfer_eve_tdata[63:0]};
          sr_transfer_eve_marge_tdata  <= sr_s_axis_cd_transfer_eve_tdata;
          sr_rr_flag                   <= 1'b1;
        end else if(sr_s_axis_cu_transfer_eve_tvalid)begin
          sr_transfer_eve_marge_tvalid <= 1'b1;
          //sr_transfer_eve_marge_tdata  <= {sr_s_axis_cu_transfer_eve_tdata[127:80],SEND_EVE,sr_s_axis_cu_transfer_eve_tdata[63:0]};
          sr_transfer_eve_marge_tdata  <= sr_s_axis_cu_transfer_eve_tdata;
          sr_rr_flag                   <= 1'b0;
        end else begin
          sr_transfer_eve_marge_tvalid <= 1'b0;
        end
      end else begin// up priority
        if(sr_s_axis_cu_transfer_eve_tvalid)begin
          sr_transfer_eve_marge_tvalid <= 1'b1;
          //sr_transfer_eve_marge_tdata  <= {sr_s_axis_cu_transfer_eve_tdata[127:80],SEND_EVE,sr_s_axis_cu_transfer_eve_tdata[63:0]};
          sr_transfer_eve_marge_tdata  <= sr_s_axis_cu_transfer_eve_tdata;
          sr_rr_flag                   <= 1'b0;
        end else if(sr_s_axis_cd_transfer_eve_tvalid)begin
          sr_transfer_eve_marge_tvalid <= 1'b1;
          //sr_transfer_eve_marge_tdata  <= {sr_s_axis_cd_transfer_eve_tdata[127:80],RECV_EVE,sr_s_axis_cd_transfer_eve_tdata[63:0]};
          sr_transfer_eve_marge_tdata  <= sr_s_axis_cd_transfer_eve_tdata;
          sr_rr_flag                   <= 1'b1;
        end else begin
          sr_transfer_eve_marge_tvalid <= 1'b0;
        end
      end
    end else begin
      sr_transfer_eve_marge_tvalid <= sr_transfer_eve_marge_tvalid;
      sr_transfer_eve_marge_tdata  <= sr_transfer_eve_marge_tdata;
      sr_rr_flag                   <= sr_rr_flag;
    end
  end
end

// Issue Event
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_axis_transfer_eve_out_tvalid <= 1'b0;
    sr_axis_transfer_eve_out_tdata  <= {128{1'b0}};
  end else begin
    if(!sr_axis_transfer_eve_out_tvalid || m_axis_transfer_eve_tready)begin
      sr_axis_transfer_eve_out_tvalid <= |{sr_transfer_eve_marge_tvalid,sr_ch_enable_flag};
      // Priority Encoder
      case ({sr_transfer_eve_marge_tvalid,sr_ch_enable_flag}) inside
         9'b?_???????1 : sr_axis_transfer_eve_out_tdata <= sr_ch_mode_flag[0] ?  RECV_RST_DATA_ID_0: ESTABLISHED_DATA_ID_0;  
         9'b?_??????10 : sr_axis_transfer_eve_out_tdata <= sr_ch_mode_flag[1] ?  RECV_RST_DATA_ID_1: ESTABLISHED_DATA_ID_1; 
         9'b?_?????100 : sr_axis_transfer_eve_out_tdata <= sr_ch_mode_flag[2] ?  RECV_RST_DATA_ID_2: ESTABLISHED_DATA_ID_2; 
         9'b?_????1000 : sr_axis_transfer_eve_out_tdata <= sr_ch_mode_flag[3] ?  RECV_RST_DATA_ID_3: ESTABLISHED_DATA_ID_3; 
         9'b?_???10000 : sr_axis_transfer_eve_out_tdata <= sr_ch_mode_flag[4] ?  RECV_RST_DATA_ID_4: ESTABLISHED_DATA_ID_4; 
         9'b?_??100000 : sr_axis_transfer_eve_out_tdata <= sr_ch_mode_flag[5] ?  RECV_RST_DATA_ID_5: ESTABLISHED_DATA_ID_5; 
         9'b?_?1000000 : sr_axis_transfer_eve_out_tdata <= sr_ch_mode_flag[6] ?  RECV_RST_DATA_ID_6: ESTABLISHED_DATA_ID_6; 
         9'b?_10000000 : sr_axis_transfer_eve_out_tdata <= sr_ch_mode_flag[7] ?  RECV_RST_DATA_ID_7: ESTABLISHED_DATA_ID_7; 
         9'b1_00000000 : sr_axis_transfer_eve_out_tdata <= sr_transfer_eve_marge_tdata;
         default       : sr_axis_transfer_eve_out_tdata <= {128{1'b0}}; // Unconditional
      endcase
    end else begin
      sr_axis_transfer_eve_out_tvalid <= sr_axis_transfer_eve_out_tvalid;
      sr_axis_transfer_eve_out_tdata  <= sr_axis_transfer_eve_out_tdata;
    end
    
  end
end

// Insert RS for timing closure
assign s_axis_cd_transfer_eve_tready = (!sr_s_axis_cd_transfer_eve_tvalid || w_adopt_route_up_dn[0]); // Insert RS if timing is tight
assign s_axis_cu_transfer_eve_tready = (!sr_s_axis_cu_transfer_eve_tvalid || w_adopt_route_up_dn[1]);
assign m_axis_transfer_eve_tvalid    = sr_axis_transfer_eve_out_tvalid;
assign m_axis_transfer_eve_tdata     = sr_axis_transfer_eve_out_tdata ;

//CMD
wire w_cmd_ready;
assign w_cmd_ready = (!sr_m_axis_cd_transfer_cmd_tvalid || m_axis_cd_transfer_cmd_tready)&&(!sr_m_axis_cu_transfer_cmd_tvalid || m_axis_cu_transfer_cmd_tready);

always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_s_axis_transfer_cmd_tvalid <= 1'b0;
    sr_s_axis_transfer_cmd_tdata  <= {64{1'b0}};
  end else begin
    if(!sr_s_axis_transfer_cmd_tvalid || w_cmd_ready)begin
      sr_s_axis_transfer_cmd_tvalid <= s_axis_transfer_cmd_tvalid;
      sr_s_axis_transfer_cmd_tdata  <= s_axis_transfer_cmd_tdata ;
    end else begin
      sr_s_axis_transfer_cmd_tvalid <= sr_s_axis_transfer_cmd_tvalid;
      sr_s_axis_transfer_cmd_tdata  <= sr_s_axis_transfer_cmd_tdata ;
    end
  end
end

// Destination Selection
always @(posedge user_clk or negedge reset_n) begin
  if(!reset_n) begin
    sr_m_axis_cd_transfer_cmd_tvalid  <= 1'b0;
    sr_m_axis_cd_transfer_cmd_tdata   <= {64{1'b0}};
    sr_m_axis_cu_transfer_cmd_tvalid  <= 1'b0;
    sr_m_axis_cu_transfer_cmd_tdata   <= {64{1'b0}};
  end else begin
    if(w_cmd_ready)begin
      if(~sr_s_axis_transfer_cmd_tdata[48])begin  // Send
        sr_m_axis_cd_transfer_cmd_tvalid <= 0;
        sr_m_axis_cu_transfer_cmd_tvalid <= sr_s_axis_transfer_cmd_tvalid;
      end else begin // Receive
        sr_m_axis_cd_transfer_cmd_tvalid <= sr_s_axis_transfer_cmd_tvalid;
        sr_m_axis_cu_transfer_cmd_tvalid <= 0;        
      end
    end else begin
      sr_m_axis_cd_transfer_cmd_tvalid <= sr_m_axis_cd_transfer_cmd_tvalid;
      sr_m_axis_cu_transfer_cmd_tvalid <= sr_m_axis_cu_transfer_cmd_tvalid;
    end
    sr_m_axis_cd_transfer_cmd_tdata <= sr_s_axis_transfer_cmd_tdata;
    sr_m_axis_cu_transfer_cmd_tdata <= sr_s_axis_transfer_cmd_tdata;
  end
end

assign m_axis_cd_transfer_cmd_tvalid = sr_m_axis_cd_transfer_cmd_tvalid;
assign m_axis_cd_transfer_cmd_tdata  = sr_m_axis_cd_transfer_cmd_tdata;
assign m_axis_cu_transfer_cmd_tvalid = sr_m_axis_cu_transfer_cmd_tvalid;
assign m_axis_cu_transfer_cmd_tdata  = sr_m_axis_cu_transfer_cmd_tdata;
assign s_axis_transfer_cmd_tready    = (!sr_s_axis_transfer_cmd_tvalid || w_cmd_ready);


endmodule
