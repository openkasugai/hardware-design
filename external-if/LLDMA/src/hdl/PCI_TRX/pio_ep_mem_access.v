/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module pio_ep_mem_access #(

  parameter FPGA_INFO = 32'h00060101, //FPGA INFO Ver/Rev
  parameter C_DATA_WIDTH = 512, 
  parameter ADDR_W = 16,
  parameter MEM_W  = 512, 
  parameter BYTE_EN_W = 64,
  parameter integer DATA_WIDTH = 32, //! data bit width
  parameter integer STRB_WIDTH = (DATA_WIDTH+7)/8 //! Width of the STRB signal

  )(

  input      user_clk,
  input      reset_n,

  // AXI Lite IF

  input   wire[ADDR_W-1:0]      s_axi_araddr  , //! AXI4-Lite ARADDR 
  input   wire                  s_axi_arvalid , //! AXI4-Lite ARVALID
  output  wire                  s_axi_arready , //! AXI4-Lite ARREADY
  output  wire[DATA_WIDTH-1:0]  s_axi_rdata   , //! AXI4-Lite RDATA  
  output  wire[1:0]             s_axi_rresp   , //! AXI4-Lite RRESP  
  output  wire                  s_axi_rvalid  , //! AXI4-Lite RVALID 
  input   wire                  s_axi_rready  , //! AXI4-Lite RREADY 
  input   wire[ADDR_W-1:0]      s_axi_awaddr  , //! AXI4-Lite AWADDR 
  input   wire                  s_axi_awvalid , //! AXI4-Lite AWVALID
  output  wire                  s_axi_awready , //! AXI4-Lite AWREADY
  input   wire[DATA_WIDTH-1:0]  s_axi_wdata   , //! AXI4-Lite WDATA  
  input   wire[STRB_WIDTH-1:0]  s_axi_wstrb   , //! AXI4-Lite WSTRB not used
  input   wire                  s_axi_wvalid  , //! AXI4-Lite WVALID 
  output  wire                  s_axi_wready  , //! AXI4-Lite WREADY 
  output  wire[1:0]             s_axi_bresp   , //! AXI4-Lite BRESP  
  output  wire                  s_axi_bvalid  , //! AXI4-Lite BVALID 
  input   wire                  s_axi_bready  , //! AXI4-Lite BREADY 

  // CMS IF

  input                  s_d2d_req_valid,
  input                  s_d2d_ack_valid,
  input        [511:0]   s_d2d_data,
  output                 s_d2d_ready,

  // arb ctrl
  output reg    [31:0]   reg_arb,

  // PA Interface

  input         [31:0]   pa_dmaw_pkt_cnt,
  input         [31:0]   pa_dmar_pkt_cnt,
  input         [31:0]   pa_enque_poling_pkt_cnt,
  input         [31:0]   pa_enque_clear_pkt_cnt,
  input         [31:0]   pa_deque_poling_pkt_cnt,
  input         [31:0]   pa_deque_pkt_cnt,

  output wire            en_pa_pkt_cnt,
  output wire            rst_pa_pkt_cnt,

  // Debug Deque Data

  input        [511:0]   deque_pkt_hold,

 // PA/TRACE IF (to other module)
  output wire            dbg_enable,         // PA ENB
  output wire            dbg_count_reset,    // PA CLR
  output wire            dma_trace_enable,   // TRACE ENB
  output wire            dma_trace_rst,      // TRACE CLR
  output wire   [31:0]   dbg_freerun_count,  // TRACE FREERUN COUNT

  // Cfg Max Payload, Max Read Req Interface

  input          [1:0]   cfg_max_payload,
  input          [2:0]   cfg_max_read_req,

  // Cfg Error

  input          [4:0]   cfg_local_error_out,
  input                  cfg_local_error_valid,

  // Register Access Interface

  output reg             regreq_axis_tvalid_cifup,
  output reg             regreq_axis_tvalid_cifdn,
  output reg             regreq_axis_tvalid_dmar,
  output reg             regreq_axis_tvalid_dmat,
  output reg   [511:0]   regreq_axis_tdata,
  output wire            regreq_axis_tlast,
  output reg    [63:0]   regreq_axis_tuser,

  // Register Access Read Reply Interface

  input                  regrep_axis_tvalid_cifup,
  input                  regrep_axis_tvalid_cifdn,
  input                  regrep_axis_tvalid_dmar,
  input                  regrep_axis_tvalid_dmat,
  input         [31:0]   regrep_axis_tdata_cifup,
  input         [31:0]   regrep_axis_tdata_cifdn,
  input         [31:0]   regrep_axis_tdata_dmar,
  input         [31:0]   regrep_axis_tdata_dmat,

  // Trigger to TX and Interrupt Handler Block to generate
  // Transactions and Interrupts

  output reg           gen_leg_intr,
  output reg           gen_msi_intr,
  output reg           gen_msix_intr,

  // Error detect
  input                error_detect_dma_tx,
  input                error_detect_dma_rx,
  input                error_detect_cif_up,
  input                error_detect_cif_dn,
  output reg           error_detect_lldma


  );

  localparam IMPL_SEED          = 32'h00000000;//IMPL SEED
  
//  localparam FPGA_INFO          = 32'h00060101;//FPGA INFO Ver/Rev
  localparam PIO_INTR_GEN_REG   = 16'h01BB;

  localparam CIUP_WR    = 5'b00001;
  localparam CIDN_WR    = 5'b00010;
  localparam DMAR_WR    = 5'b00100;
  localparam DMAT_WR    = 5'b01000;
  localparam PCIX_WR    = 5'b10000;

  localparam CIUP_RD    = 5'b00001;
  localparam CIDN_RD    = 5'b00010;
  localparam DMAR_RD    = 5'b00100;
  localparam DMAT_RD    = 5'b01000;
  localparam PCIX_RD    = 5'b10000;
                          

 wire [15:0] wr_addr;
 wire [15:0] rd_addr;

 reg [4:0] rd_select_bit;
 reg [4:0] wr_select_bit;

 reg [31:0] reg_scratch0;
 reg [31:0] reg_scratch1;
 reg [31:0] reg_scratch2;
 reg [31:0] reg_scratch3;
 reg        reg_pa_enable;
 reg        reg_trace_enable;

 reg [4:0]  reg_cfg_err;

 reg reg_regrep_axis_tvalid_cifup_1t;
 reg reg_regrep_axis_tvalid_cifdn_1t;
 reg reg_regrep_axis_tvalid_dmar_1t;
 reg reg_regrep_axis_tvalid_dmat_1t;
 reg reg_regrep_axis_tvalid_dmat_2t;
 reg reg_pcix_rd_1t;
 reg reg_pcix_rd_2t;
 reg reg_pcix_rd_3t;
 reg reg_pcix_rd_4t;
 reg reg_pcix_rd_5t;
 reg reg_pcix_rd_6t;
 reg reg_pcix_rd_7t;

 reg [31:0] reg_regrep_axis_tdata_cifup_1t;
 reg [31:0] reg_regrep_axis_tdata_cifdn_1t;
 reg [31:0] reg_regrep_axis_tdata_dmar_1t;
 reg [31:0] reg_regrep_axis_tdata_dmat_1t;
 reg [31:0] reg_regrep_axis_tdata_dmat_2t;
 reg [31:0] reg_pci_trx_tdata_1t;
 reg [31:0] reg_pci_trx_tdata_1t_copy;
 reg [31:0] reg_pci_trx_tdata_1t_copy2;
 reg [31:0] reg_pci_trx_tdata_2t;
 reg [31:0] reg_pci_trx_tdata_3t;
 reg [31:0] reg_pci_trx_tdata_4t;
 reg [31:0] reg_pci_trx_tdata_5t;
 reg [31:0] reg_pci_trx_tdata_6t;
 reg [31:0] reg_pci_trx_tdata_7t;

 reg regreq_d2d_valid;

 reg regreq_axis_tlast_out;

 wire w_en_pa_pkt_cnt;
 wire w_rst_pa_pkt_cnt;
 wire w_en_trace_pkt_cnt;
 wire w_rst_trace_pkt_cnt;

 reg reg_en_pa_pkt_cnt;
 reg reg_rst_pa_pkt_cnt;
 reg reg_en_trace_pkt_cnt;
 reg reg_rst_trace_pkt_cnt;

 reg [63:0] reg_pa_cnt;
 reg [31:0] reg_trace_cnt;

 wire ciup_wr;
 wire cidn_wr;
 wire dmat_wr;
 wire dmar_wr;
 wire pcix_wr;

 wire ciup_rd;
 wire cidn_rd;
 wire dmat_rd;
 wire dmar_rd;
 wire pcix_rd;

 wire tvalid_ciup;
 wire tvalid_cidn;
 wire tvalid_dmat;
 wire tvalid_dmar;

 wire wr_or;
 wire rd_or;

 wire        tlast_or;
 wire [32:0] tuser;
 wire [31:0] rd_data_sel;
 wire        rd_tvalid_or;

 reg [31:0] pci_trx_tdata;
 reg [31:0] pci_trx_tdata_copy;
 reg [31:0] pci_trx_tdata_copy2;

 wire [31:0] cfg_reg;

 wire regreq_d2d_valid_in;

 // Local Bus
 wire[ADDR_W-1:0]     local_addr    ;
 wire                 local_wr_en   ;
 wire[DATA_WIDTH-1:0] local_wr_data ;
 reg                  local_wr_ack  ;
 wire                 local_rd_en   ;
 reg                  local_rd_ack  ;
 reg[DATA_WIDTH-1:0]  local_rd_data ;

 // fifo
 wire         d2d_req_valid;
 wire         d2d_ack_valid;
 wire [511:0] d2d_data;
 wire         tkn;
 wire         req;

 wire d2d_req;
 wire d2d_ack;

 wire [511:0] regreq_axis_tdata_in;

 // pci trx err

 reg  reg_pci_trx_err;
 wire pci_trx_err;

 // trace

 wire en_trace_pkt_cnt;
 wire rst_trace_pkt_cnt;

// Separate decoding for delay over.

 wire [31:0] reg_pci_trx_tdata_1t_or;


// Error detect
 wire [31:0] error_status;
 reg         error_detect_dma_tx_1t;
 reg         error_detect_dma_rx_1t;
 reg         error_detect_cif_up_1t;
 reg         error_detect_cif_dn_1t;


  assign wr_addr = local_addr;
  assign rd_addr = local_addr;

  // ---------------------------------------------------
  // AXI Lite Termination
  // ---------------------------------------------------

    checker_axi_lite_end_point #(
        .ADDR_WIDTH (ADDR_W     ), // integer
        .DATA_WIDTH (DATA_WIDTH )  // integer
    ) axi_endpoint (
        .aclk           (user_clk        ), // input
        .resetn         (reset_n         ), // input
        .s_axi_araddr   (s_axi_araddr    ), // input
        .s_axi_arvalid  (s_axi_arvalid   ), // input
        .s_axi_arready  (s_axi_arready   ), // output
        .s_axi_rdata    (s_axi_rdata     ), // output
        .s_axi_rresp    (s_axi_rresp     ), // output
        .s_axi_rvalid   (s_axi_rvalid    ), // output
        .s_axi_rready   (s_axi_rready    ), // input
        .s_axi_awaddr   (s_axi_awaddr    ), // input
        .s_axi_awvalid  (s_axi_awvalid   ), // input
        .s_axi_awready  (s_axi_awready   ), // output
        .s_axi_wdata    (s_axi_wdata     ), // input
        .s_axi_wstrb    (s_axi_wstrb     ), // input
        .s_axi_wvalid   (s_axi_wvalid    ), // input
        .s_axi_wready   (s_axi_wready    ), // output
        .s_axi_bresp    (s_axi_bresp     ), // output
        .s_axi_bvalid   (s_axi_bvalid    ), // output
        .s_axi_bready   (s_axi_bready    ), // input
        .local_addr     (local_addr      ), // output
        .local_wr_en    (local_wr_en     ), // output
        .local_wr_data  (local_wr_data   ), // output
        .local_wr_ack   (local_wr_ack    ), // input
        .local_rd_en    (local_rd_en     ), // output
        .local_rd_data  (local_rd_data   ), // input
        .local_rd_ack   (local_rd_ack    )  // input
    );


  // ---------------------------------------------------
  // FIFO Instance
  // ---------------------------------------------------

  pio_mem_fifo fifo_d2d(

    .user_clk     ( user_clk ),
    .reset_n      ( reset_n  ),

    .i_req_valid  ( s_d2d_req_valid    ),
    .i_ack_valid  ( s_d2d_ack_valid    ),
    .i_data       ( s_d2d_data[511:0] ),
    .o_tready     ( s_d2d_ready        ),

    .o_req_valid  ( d2d_req_valid      ),
    .o_ack_valid  ( d2d_ack_valid      ),
    .o_data       ( d2d_data[511:0]   ),

    .i_tkn        ( tkn  ),
    .o_req        ( req  )

    );

  assign tkn     = req & ~tlast_or;
  assign d2d_req = tkn & d2d_req_valid;
  assign d2d_ack = tkn & d2d_ack_valid;
  assign regreq_d2d_valid_in = d2d_req | d2d_ack;

  assign regreq_axis_tdata_in = (tkn == 1'b1) ? d2d_data[511:0] : {480'd0,local_wr_data[31:0]};

  assign regreq_axis_tlast = regreq_axis_tlast_out | regreq_d2d_valid;


  // ---------------------------------------------------
  // Write Address Decode
  // ---------------------------------------------------
  always @ (
            wr_addr[15:0]
            )
    begin
       casex(wr_addr[15:0])
         16'h00xx : wr_select_bit = PCIX_WR;
         16'h01xx : wr_select_bit = PCIX_WR;
         16'h02xx : wr_select_bit = DMAR_WR;
         16'h03xx : wr_select_bit = DMAR_WR;
         16'h04xx : wr_select_bit = DMAT_WR;
         16'h05xx : wr_select_bit = DMAT_WR;
         16'h06xx : wr_select_bit = CIDN_WR;
         16'h07xx : wr_select_bit = CIDN_WR;
         16'h08xx : wr_select_bit = CIUP_WR;
         16'h09xx : wr_select_bit = CIUP_WR;
         16'h10xx : wr_select_bit = PCIX_WR;
         16'h11xx : wr_select_bit = PCIX_WR;
         16'h12xx : wr_select_bit = DMAR_WR;
         16'h13xx : wr_select_bit = DMAR_WR;
         16'h14xx : wr_select_bit = DMAT_WR;
         16'h15xx : wr_select_bit = DMAT_WR;
         16'h16xx : wr_select_bit = CIDN_WR;
         16'h17xx : wr_select_bit = CIDN_WR;
         16'h18xx : wr_select_bit = CIUP_WR;
         16'h19xx : wr_select_bit = CIUP_WR;
         //16'h1Exx : wr_select_bit = ;//D2D
         //16'h1Fxx : wr_select_bit = ;//ACK
         default  : wr_select_bit = PCIX_WR; // no response
       endcase   end

  // ---------------------------------------------------
  // Read Address Decode
  // ---------------------------------------------------
  always @ (
            rd_addr[15:0]
            )
    begin
       casex(rd_addr[15:0])
         16'h00xx : rd_select_bit = PCIX_RD;
         16'h01xx : rd_select_bit = PCIX_RD;
         16'h02xx : rd_select_bit = DMAR_RD;
         16'h03xx : rd_select_bit = DMAR_RD;
         16'h04xx : rd_select_bit = DMAT_RD;
         16'h05xx : rd_select_bit = DMAT_RD;
         16'h06xx : rd_select_bit = CIDN_RD;
         16'h07xx : rd_select_bit = CIDN_RD;
         16'h08xx : rd_select_bit = CIUP_RD;
         16'h09xx : rd_select_bit = CIUP_RD;
         16'h10xx : rd_select_bit = PCIX_RD;
         16'h11xx : rd_select_bit = PCIX_RD;
         16'h12xx : rd_select_bit = DMAR_RD;
         16'h13xx : rd_select_bit = DMAR_RD;
         16'h14xx : rd_select_bit = DMAT_RD;
         16'h15xx : rd_select_bit = DMAT_RD;
         16'h16xx : rd_select_bit = CIDN_RD;
         16'h17xx : rd_select_bit = CIDN_RD;
         16'h18xx : rd_select_bit = CIUP_RD;
         16'h19xx : rd_select_bit = CIUP_RD;
         //16'h1Exx : wr_select_bit = ;//D2D
         //16'h1Fxx : wr_select_bit = ;//ACK
         default  : rd_select_bit = PCIX_RD; // zero response
       endcase
    end


  // ---------------------------------------------------
  // request tvalid / tlast / tuser
  // ---------------------------------------------------

  assign ciup_wr = (local_wr_en & (wr_select_bit == CIUP_WR)) ? 1'b1 : 1'b0;
  assign cidn_wr = (local_wr_en & (wr_select_bit == CIDN_WR)) ? 1'b1 : 1'b0;
  assign dmat_wr = (local_wr_en & (wr_select_bit == DMAT_WR)) ? 1'b1 : 1'b0;
  assign dmar_wr = (local_wr_en & (wr_select_bit == DMAR_WR)) ? 1'b1 : 1'b0;
  assign pcix_wr = (local_wr_en & (wr_select_bit == PCIX_WR)) ? 1'b1 : 1'b0;

  assign ciup_rd = (local_rd_en & (rd_select_bit == CIUP_RD)) ? 1'b1 : 1'b0;
  assign cidn_rd = (local_rd_en & (rd_select_bit == CIDN_RD)) ? 1'b1 : 1'b0;
  assign dmat_rd = (local_rd_en & (rd_select_bit == DMAT_RD)) ? 1'b1 : 1'b0;
  assign dmar_rd = (local_rd_en & (rd_select_bit == DMAR_RD)) ? 1'b1 : 1'b0;
  assign pcix_rd = (local_rd_en & (rd_select_bit == PCIX_RD)) ? 1'b1 : 1'b0;

  assign tvalid_ciup = ciup_wr | ciup_rd;
  assign tvalid_cidn = cidn_wr | cidn_rd;
  assign tvalid_dmat = dmat_wr | dmat_rd | d2d_ack;
  assign tvalid_dmar = dmar_wr | dmar_rd | d2d_req;

  assign wr_or = ciup_wr | cidn_wr | dmat_wr | dmar_wr ;//Exclude pcix_wr
  assign rd_or = ciup_rd | cidn_rd | dmat_rd | dmar_rd ;//Exclude pcix_rd

  assign tlast_or = wr_or | rd_or;

  // ---------------------------------------------------
  // tuser
  // ---------------------------------------------------

  assign tuser[32]    = (wr_or   == 1'b1) ? 1'b1 :
                        (d2d_req == 1'b1) ? 1'b1 :
                        (d2d_ack == 1'b1) ? 1'b1 :
                        (rd_or   == 1'b1) ? 1'b0 :1'b0;

  assign tuser[15:0]  = (wr_or   == 1'b1) ? wr_addr[15:0] :
                        (d2d_req == 1'b1) ? 16'h1E00 :
                        (d2d_ack == 1'b1) ? 16'h1F00 :
                        (rd_or   == 1'b1) ? rd_addr[15:0] :16'b0;

  assign tuser[31:16] = 16'b0;

  // ---------------------------------------------------
  // read tvalid / tdata
  // ---------------------------------------------------

  assign rd_tvalid_or = reg_regrep_axis_tvalid_cifup_1t |
                        reg_regrep_axis_tvalid_cifdn_1t |
                        reg_regrep_axis_tvalid_dmar_1t  |
                        reg_regrep_axis_tvalid_dmat_2t  |
                        reg_pcix_rd_7t;

  assign rd_data_sel[31:0] = (reg_regrep_axis_tvalid_cifup_1t == 1'b1) ? reg_regrep_axis_tdata_cifup_1t[31:0] :
                             (reg_regrep_axis_tvalid_cifdn_1t == 1'b1) ? reg_regrep_axis_tdata_cifdn_1t[31:0] :
                             (reg_regrep_axis_tvalid_dmar_1t  == 1'b1) ? reg_regrep_axis_tdata_dmar_1t[31:0]  :
                             (reg_regrep_axis_tvalid_dmat_2t  == 1'b1) ? reg_regrep_axis_tdata_dmat_2t[31:0]  :
                             (reg_pcix_rd_7t == 1'b1                 ) ? reg_pci_trx_tdata_7t[31:0]           :32'b0;

  // ---------------------------------------------------
  // output FF
  // ---------------------------------------------------

  always @(posedge user_clk or negedge reset_n) begin  
    if (!reset_n) begin 
      regreq_axis_tdata[511:0]  <=  512'b0;
      regreq_axis_tvalid_cifup  <=  1'b0;
      regreq_axis_tvalid_cifdn  <=  1'b0;
      regreq_axis_tvalid_dmar   <=  1'b0;
      regreq_axis_tvalid_dmat   <=  1'b0;
      regreq_axis_tlast_out     <=  1'b0;
      regreq_axis_tuser[63:0]   <=  64'b0;
      local_rd_ack              <=  1'b0;
      local_rd_data[31:0]       <=  32'b0;
    end else begin
      regreq_axis_tdata[511:0]  <=  regreq_axis_tdata_in[511:0];
      regreq_axis_tvalid_cifup  <=  tvalid_ciup;
      regreq_axis_tvalid_cifdn  <=  tvalid_cidn;
      regreq_axis_tvalid_dmar   <=  tvalid_dmar;
      regreq_axis_tvalid_dmat   <=  tvalid_dmat;
      regreq_axis_tlast_out     <=  tlast_or   ;
      regreq_axis_tuser[63:0]   <=  {31'b0,tuser[32:0]};
      local_rd_ack              <=  rd_tvalid_or;
      local_rd_data[31:0]       <=  rd_data_sel[31:0];
    end
  end


  // ---------------------------------------------------
  // PCI_TRX REGISTER
  // ---------------------------------------------------

  always @(posedge user_clk or negedge reset_n) begin  
    if (!reset_n) begin 
      reg_arb       <= 0;
      reg_scratch0  <= 0;
      reg_scratch1  <= 0;
      reg_scratch2  <= 0;
      reg_scratch3  <= 0;
      reg_pa_enable <= 0;
      reg_trace_enable <= 0;
    end 
    else begin
      if (pcix_wr) begin
        case ( wr_addr[15:0] )
          16'h0060 : reg_arb          <= local_wr_data[31:0];//ARB SET
          16'h0100 : reg_scratch0     <= local_wr_data[31:0];//SCRATCH0
          16'h0104 : reg_scratch1     <= local_wr_data[31:0];//SCRATCH1
          16'h0108 : reg_scratch2     <= local_wr_data[31:0];//SCRATCH2
          16'h010C : reg_scratch3     <= local_wr_data[31:0];//SCRATCH3
          16'h1000 : reg_pa_enable    <= local_wr_data[0]   ;//PA ENABLE
          16'h100C : reg_trace_enable <= local_wr_data[0]   ;//TRACE ENABLE
        endcase
      end
    end
  end


  always @(*) begin
    if (pcix_rd) begin
      case ( rd_addr[15:0] )
        16'h0040 : pci_trx_tdata[31:0] = FPGA_INFO              ;//FPGA INFO Ver/Rev
        16'h0050 : pci_trx_tdata[31:0] = cfg_reg                ;//PCI IP INFO
        16'h0060 : pci_trx_tdata[31:0] = reg_arb                ;//ARB SET
        16'h0100 : pci_trx_tdata[31:0] = reg_scratch0           ;//SCRATCH0
        16'h0104 : pci_trx_tdata[31:0] = reg_scratch1           ;//SCRATCH1
        16'h0108 : pci_trx_tdata[31:0] = reg_scratch2           ;//SCRATCH2
        16'h010C : pci_trx_tdata[31:0] = reg_scratch3           ;//SCRATCH3
        16'h01E0 : pci_trx_tdata[31:0] = error_status           ;//ERROR DETECT
        16'h0070 : pci_trx_tdata[31:0] = IMPL_SEED              ;//IMPL SEED

        default  : pci_trx_tdata[31:0] = 0;
      endcase
    end else begin
      pci_trx_tdata = 0;
    end
  end

  assign error_status[31:0] = {error_detect_lldma
                              , 27'h0
                              ,error_detect_cif_up_1t
                              ,error_detect_cif_dn_1t
                              ,error_detect_dma_tx_1t
                              ,error_detect_dma_rx_1t
                              };


  always @(*) begin    // Separate decoding for delay over.
    if (pcix_rd) begin
      case ( rd_addr[15:0] )
        16'h1000 : pci_trx_tdata_copy[31:0] = {31'b0,reg_pa_enable}    ;//PA CTRL
        16'h1004 : pci_trx_tdata_copy[31:0] = reg_pa_cnt[31:0]         ;//PA CNT LOW
        16'h1008 : pci_trx_tdata_copy[31:0] = reg_pa_cnt[63:32]        ;//PA CNT HIGH
        16'h100C : pci_trx_tdata_copy[31:0] = {31'b0,reg_trace_enable} ;//TRACE CTRL
        16'h1010 : pci_trx_tdata_copy[31:0] = pa_dmaw_pkt_cnt          ;//DMAW PKT CNT
        16'h1014 : pci_trx_tdata_copy[31:0] = pa_dmar_pkt_cnt          ;//DMAR PKT CNT
        16'h1018 : pci_trx_tdata_copy[31:0] = pa_enque_poling_pkt_cnt  ;//ENQUE POLING PKT CNT
        16'h101C : pci_trx_tdata_copy[31:0] = pa_enque_clear_pkt_cnt   ;//ENQUE CLR PKT CNT
        16'h1020 : pci_trx_tdata_copy[31:0] = pa_deque_poling_pkt_cnt  ;//DEQUE POLING PKT CNT
        16'h1024 : pci_trx_tdata_copy[31:0] = pa_deque_pkt_cnt         ;//DEQUE STORE PKT CNT

        default  : pci_trx_tdata_copy[31:0] = 0;
      endcase
    end else begin
      pci_trx_tdata_copy = 0;
    end
  end

  always @(*) begin    // Separate decoding for delay over.
    if (pcix_rd) begin
      case ( rd_addr[15:0] )
        16'h1030 : pci_trx_tdata_copy2[31:0] = deque_pkt_hold[31:0]   ;//PKT HOLD
        16'h1034 : pci_trx_tdata_copy2[31:0] = deque_pkt_hold[63:32]  ;//PKT HOLD
        16'h1038 : pci_trx_tdata_copy2[31:0] = deque_pkt_hold[95:64]  ;//PKT HOLD
        16'h103C : pci_trx_tdata_copy2[31:0] = deque_pkt_hold[127:96] ;//PKT HOLD
        16'h1040 : pci_trx_tdata_copy2[31:0] = deque_pkt_hold[159:128];//PKT HOLD
        16'h1044 : pci_trx_tdata_copy2[31:0] = deque_pkt_hold[191:160];//PKT HOLD
        16'h1048 : pci_trx_tdata_copy2[31:0] = deque_pkt_hold[223:192];//PKT HOLD
        16'h104C : pci_trx_tdata_copy2[31:0] = deque_pkt_hold[255:224];//PKT HOLD
        16'h1050 : pci_trx_tdata_copy2[31:0] = deque_pkt_hold[287:256];//PKT HOLD
        16'h1054 : pci_trx_tdata_copy2[31:0] = deque_pkt_hold[319:288];//PKT HOLD
        16'h1058 : pci_trx_tdata_copy2[31:0] = deque_pkt_hold[351:320];//PKT HOLD
        16'h105C : pci_trx_tdata_copy2[31:0] = deque_pkt_hold[383:352];//PKT HOLD
        16'h1060 : pci_trx_tdata_copy2[31:0] = deque_pkt_hold[415:384];//PKT HOLD
        16'h1064 : pci_trx_tdata_copy2[31:0] = deque_pkt_hold[447:416];//PKT HOLD

        default  : pci_trx_tdata_copy2[31:0] = 0;
      endcase
    end else begin
      pci_trx_tdata_copy2 = 0;
    end
  end

  // ---------------------------------------------------
  // PA/TRACE ENABLE / RESET
  // ---------------------------------------------------

  assign w_en_pa_pkt_cnt               = reg_pa_enable;
  assign w_rst_pa_pkt_cnt              = (( pcix_wr == 1'b1) && ( local_wr_data[1] == 1'b1 ) && ( wr_addr[15:0] == 16'h1000 )) ? 1'b1 : 1'b0;
  assign w_en_trace_pkt_cnt            = reg_trace_enable;
  assign w_rst_trace_pkt_cnt           = (( pcix_wr == 1'b1) && ( local_wr_data[1] == 1'b1 ) && ( wr_addr[15:0] == 16'h100C )) ? 1'b1 : 1'b0;

  assign en_pa_pkt_cnt     = reg_en_pa_pkt_cnt;
  assign rst_pa_pkt_cnt    = reg_rst_pa_pkt_cnt;
  assign en_trace_pkt_cnt  = reg_en_trace_pkt_cnt;
  assign rst_trace_pkt_cnt = reg_rst_trace_pkt_cnt;

  // ---------------------------------------------------
  // PCI TRX ERROR
  // ---------------------------------------------------

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      reg_pci_trx_err  <=  1'b0;
    end else if ((pcix_wr == 1'b1) && ( local_wr_data[0] == 1'b1 ) && (wr_addr == 16'h01E0)) begin
      reg_pci_trx_err  <=  1'b0;
    end else if (pci_trx_err) begin
      reg_pci_trx_err  <=  1'b1;
    end
  end

  assign pci_trx_err = 1'b0;

  // ---------------------------------------------------
  // INT Generate
  // ---------------------------------------------------

  always @(posedge user_clk or negedge reset_n)
  begin
    if(!reset_n)begin
      gen_leg_intr    <=  1'b0;
      gen_msi_intr    <=  1'b0;
      gen_msix_intr   <=  1'b0;
    end else if (pcix_wr == 1'b1) begin
      case(wr_addr)

        PIO_INTR_GEN_REG : begin
          if(local_wr_data[31:0] == 32'hCCCC_DDDD)
            gen_leg_intr  <=  1'b1;
          else if (local_wr_data[31:0] == 32'hEEEE_FFFF)
            gen_msi_intr  <=  1'b1;
          else if (local_wr_data[31:0] == 32'hDEAD_BEEF)
            gen_msix_intr <=  1'b1;
          else begin
            gen_leg_intr  <=  1'b0;
            gen_msi_intr  <=  1'b0;
            gen_msix_intr <=  1'b0;
          end
        end //PIO_INTR_GEN_REG

        default : begin
          gen_leg_intr    <=  1'b0;
          gen_msi_intr    <=  1'b0;
          gen_msix_intr   <=  1'b0;
        end
      endcase
    end
  end

  // --------------------------------------------
  // CFG ERROR HOLD
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n) 
  begin
    if(!reset_n)begin
      reg_cfg_err[4:0] <= 0;
    end else if (cfg_local_error_valid) begin
      reg_cfg_err[4:0] <= cfg_local_error_out[4:0];
    end
  end

  // --------------------------------------------
  // CFG Register
  // --------------------------------------------

  assign cfg_reg = {19'b0, reg_cfg_err[4:0], 2'b0, cfg_max_payload[1:0], 1'b0, cfg_max_read_req[2:0]};


  // ---------------------------------------------------
  // Retiming FF
  // ---------------------------------------------------

  always @(posedge user_clk or negedge reset_n) begin  
    if (!reset_n) begin 
      reg_regrep_axis_tvalid_cifup_1t<= 0;
      reg_regrep_axis_tvalid_cifdn_1t<= 0;
      reg_regrep_axis_tvalid_dmar_1t <= 0;
      reg_regrep_axis_tvalid_dmat_1t <= 0;
      reg_regrep_axis_tvalid_dmat_2t <= 0;
      reg_pcix_rd_1t                 <= 0;
      reg_pcix_rd_2t                 <= 0;
      reg_pcix_rd_3t                 <= 0;
      reg_pcix_rd_4t                 <= 0;
      reg_pcix_rd_5t                 <= 0;
      reg_pcix_rd_6t                 <= 0;
      reg_pcix_rd_7t                 <= 0;

      reg_regrep_axis_tdata_cifup_1t <= 0;
      reg_regrep_axis_tdata_cifdn_1t <= 0;
      reg_regrep_axis_tdata_dmar_1t  <= 0;
      reg_regrep_axis_tdata_dmat_1t  <= 0;
      reg_regrep_axis_tdata_dmat_2t  <= 0;
      reg_pci_trx_tdata_1t           <= 0;
      reg_pci_trx_tdata_1t_copy      <= 0;
      reg_pci_trx_tdata_1t_copy2     <= 0;
      reg_pci_trx_tdata_2t           <= 0;
      reg_pci_trx_tdata_3t           <= 0;
      reg_pci_trx_tdata_4t           <= 0;
      reg_pci_trx_tdata_5t           <= 0;
      reg_pci_trx_tdata_6t           <= 0;
      reg_pci_trx_tdata_7t           <= 0;
    end else begin
      reg_regrep_axis_tvalid_cifup_1t<= regrep_axis_tvalid_cifup;
      reg_regrep_axis_tvalid_cifdn_1t<= regrep_axis_tvalid_cifdn;
      reg_regrep_axis_tvalid_dmar_1t <= regrep_axis_tvalid_dmar;
      reg_regrep_axis_tvalid_dmat_1t <= regrep_axis_tvalid_dmat;
      reg_regrep_axis_tvalid_dmat_2t <= reg_regrep_axis_tvalid_dmat_1t;
      reg_pcix_rd_1t                 <= pcix_rd;
      reg_pcix_rd_2t                 <= reg_pcix_rd_1t;
      reg_pcix_rd_3t                 <= reg_pcix_rd_2t;
      reg_pcix_rd_4t                 <= reg_pcix_rd_3t;
      reg_pcix_rd_5t                 <= reg_pcix_rd_4t;
      reg_pcix_rd_6t                 <= reg_pcix_rd_5t;
      reg_pcix_rd_7t                 <= reg_pcix_rd_6t;

      reg_regrep_axis_tdata_cifup_1t <= regrep_axis_tdata_cifup;
      reg_regrep_axis_tdata_cifdn_1t <= regrep_axis_tdata_cifdn;
      reg_regrep_axis_tdata_dmar_1t  <= regrep_axis_tdata_dmar;
      reg_regrep_axis_tdata_dmat_1t  <= regrep_axis_tdata_dmat;
      reg_regrep_axis_tdata_dmat_2t  <= reg_regrep_axis_tdata_dmat_1t;
      reg_pci_trx_tdata_1t           <= pci_trx_tdata;
      reg_pci_trx_tdata_1t_copy      <= pci_trx_tdata_copy;
      reg_pci_trx_tdata_1t_copy2     <= pci_trx_tdata_copy2;
      reg_pci_trx_tdata_2t           <= reg_pci_trx_tdata_1t_or;
      reg_pci_trx_tdata_3t           <= reg_pci_trx_tdata_2t;
      reg_pci_trx_tdata_4t           <= reg_pci_trx_tdata_3t;
      reg_pci_trx_tdata_5t           <= reg_pci_trx_tdata_4t;
      reg_pci_trx_tdata_6t           <= reg_pci_trx_tdata_5t;
      reg_pci_trx_tdata_7t           <= reg_pci_trx_tdata_6t;
    end
  end

  assign reg_pci_trx_tdata_1t_or = reg_pci_trx_tdata_1t | reg_pci_trx_tdata_1t_copy | reg_pci_trx_tdata_1t_copy2;

  // ---------------------------------------------------
  // Other FF
  // ---------------------------------------------------

  always @(posedge user_clk or negedge reset_n) begin  
    if (!reset_n) begin 
      local_wr_ack <= 0;
      regreq_d2d_valid <=0;
    end else begin
      local_wr_ack <= local_wr_en;
      regreq_d2d_valid <= regreq_d2d_valid_in;
    end
  end


  // ---------------------------------------------------
  // PA / TRACE FF
  // ---------------------------------------------------

  always @(posedge user_clk or negedge reset_n) begin  
    if (!reset_n) begin 
      reg_en_pa_pkt_cnt     <= 0;
      reg_rst_pa_pkt_cnt    <= 0;
      reg_en_trace_pkt_cnt  <= 0;
      reg_rst_trace_pkt_cnt <= 0;
    end else begin
      reg_en_pa_pkt_cnt     <= w_en_pa_pkt_cnt    ;
      reg_rst_pa_pkt_cnt    <= w_rst_pa_pkt_cnt   ;
      reg_en_trace_pkt_cnt  <= w_en_trace_pkt_cnt ;
      reg_rst_trace_pkt_cnt <= w_rst_trace_pkt_cnt;
    end
  end

  // --------------------------------------------
  // PA COUNT
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n) 
  begin
    if(!reset_n)begin
      reg_pa_cnt <= 0;
    end else if (reg_rst_pa_pkt_cnt == 1'b1) begin
      reg_pa_cnt <= 0;
    end else if (reg_en_pa_pkt_cnt  == 1'b1) begin
      reg_pa_cnt <= reg_pa_cnt + 1'b1;
    end
  end

  // --------------------------------------------
  // TRACE COUNT
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n) 
  begin
    if(!reset_n)begin
      reg_trace_cnt <= 0;
    end else if (reg_rst_trace_pkt_cnt == 1'b1) begin
      reg_trace_cnt <= 0;
    end else if (reg_en_trace_pkt_cnt  == 1'b1) begin
      reg_trace_cnt <= reg_trace_cnt + 1'b1;
    end
  end

  // --------------------------------------------
  // PA / TRACE OUTPUT
  // --------------------------------------------

  assign dbg_enable        = reg_en_pa_pkt_cnt;
  assign dbg_count_reset   = reg_rst_pa_pkt_cnt;

  assign dma_trace_enable  = reg_en_trace_pkt_cnt;
  assign dma_trace_rst     = reg_rst_trace_pkt_cnt;
  assign dbg_freerun_count = reg_trace_cnt;

  // --------------------------------------------
  // Error detect
  // --------------------------------------------

  always @(posedge user_clk or negedge reset_n) 
  begin
    if(!reset_n)begin
      error_detect_dma_tx_1t <= 1'b0;
      error_detect_dma_rx_1t <= 1'b0;
      error_detect_cif_up_1t <= 1'b0;
      error_detect_cif_dn_1t <= 1'b0;
      error_detect_lldma     <= 1'b0;
    end
    else begin
      error_detect_dma_tx_1t <= error_detect_dma_tx;
      error_detect_dma_rx_1t <= error_detect_dma_rx;
      error_detect_cif_up_1t <= error_detect_cif_up;
      error_detect_cif_dn_1t <= error_detect_cif_dn;
      error_detect_lldma     <=  error_detect_dma_tx_1t
                               | error_detect_dma_rx_1t
                               | error_detect_cif_up_1t
                               | error_detect_cif_dn_1t
                               ;
    end
  end


endmodule
