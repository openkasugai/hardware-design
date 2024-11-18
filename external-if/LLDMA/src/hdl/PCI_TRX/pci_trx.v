/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

module pci_trx #(
  parameter        TCQ = 1,
  parameter        FPGA_INFO = 32'h0001012c,//FPGA INFO Ver/Rev
  parameter [1:0]  AXISTEN_IF_WIDTH = 2'b11,
  parameter        AXISTEN_IF_RQ_ALIGNMENT_MODE    = 0,//DW alignment //modify "FALSE"->"0"
  parameter        AXISTEN_IF_CC_ALIGNMENT_MODE    = 0,//DW alignment //modify "FALSE"->"0"
  parameter        AXISTEN_IF_CQ_ALIGNMENT_MODE    = 0,
  parameter        AXISTEN_IF_RC_ALIGNMENT_MODE    = 0,
  parameter        AXI4_CQ_TUSER_WIDTH             = 183,
  parameter        AXI4_CC_TUSER_WIDTH             = 81,
  parameter        AXI4_RQ_TUSER_WIDTH             = 137,
  parameter        AXI4_RC_TUSER_WIDTH             = 161,
  parameter        AXISTEN_IF_ENABLE_CLIENT_TAG    = 0,
  parameter        AXISTEN_IF_RQ_PARITY_CHECK      = 0,
  parameter        AXISTEN_IF_CC_PARITY_CHECK      = 0,
  parameter        AXISTEN_IF_RC_PARITY_CHECK      = 0,
  parameter        AXISTEN_IF_CQ_PARITY_CHECK      = 0,
  parameter        AXISTEN_IF_RC_STRADDLE          = 0,
  parameter        AXISTEN_IF_ENABLE_RX_MSG_INTFC  = 0,
  parameter [17:0] AXISTEN_IF_ENABLE_MSG_ROUTE     = 18'h2FFFF,

  //Do not modify the parameters below this line
  parameter C_DATA_WIDTH = 512,
  parameter PARITY_WIDTH = C_DATA_WIDTH /8,
  parameter KEEP_WIDTH   = C_DATA_WIDTH /32,

  //localparam for defining memory depth and width based on AXI-ST width 

  parameter ADDR_W       = 16, // Memory Depth based on the C_DATA_WIDTH. 6bit -> 16bit modify
  parameter MEM_W        = 512,// Memory Depth based on the C_DATA_WIDTH
  parameter BYTE_EN_W    = 64, // Width of byte enable going to memory for write data

  parameter integer DATA_WIDTH = 32, //! data bit width
  parameter integer STRB_WIDTH = (DATA_WIDTH+7)/8 //! Width of the STRB signal

  )(

  input                            user_clk,
  input                            reset_n,

  //----------------------------------------------
  // AXI4-Lite 
  //----------------------------------------------

  input   [ADDR_W-1:0]             s_axi_araddr  , //! AXI4-Lite ARADDR 
  input                            s_axi_arvalid , //! AXI4-Lite ARVALID
  output                           s_axi_arready , //! AXI4-Lite ARREADY
  output  [DATA_WIDTH-1:0]         s_axi_rdata   , //! AXI4-Lite RDATA  
  output  [1:0]                    s_axi_rresp   , //! AXI4-Lite RRESP  
  output                           s_axi_rvalid  , //! AXI4-Lite RVALID 
  input                            s_axi_rready  , //! AXI4-Lite RREADY 
  input   [ADDR_W-1:0]             s_axi_awaddr  , //! AXI4-Lite AWADDR 
  input                            s_axi_awvalid , //! AXI4-Lite AWVALID
  output                           s_axi_awready , //! AXI4-Lite AWREADY
  input   [DATA_WIDTH-1:0]         s_axi_wdata   , //! AXI4-Lite WDATA  
  input   [STRB_WIDTH-1:0]         s_axi_wstrb   , //! AXI4-Lite WSTRB not used
  input                            s_axi_wvalid  , //! AXI4-Lite WVALID 
  output                           s_axi_wready  , //! AXI4-Lite WREADY 
  output  [1:0]                    s_axi_bresp   , //! AXI4-Lite BRESP  
  output                           s_axi_bvalid  , //! AXI4-Lite BVALID 
  input                            s_axi_bready  , //! AXI4-Lite BREADY 

  //----------------------------------------------
  // CMS IF
  //----------------------------------------------

  input                            s_d2d_req_valid,
  input                            s_d2d_ack_valid,
  input   [511:0]                  s_d2d_data,
  output                           s_d2d_ready,

  //----------------------------------------------
  // Requester Completion Interface
  //----------------------------------------------

  input              [C_DATA_WIDTH-1:0]   s_axis_rc_tdata,
  input                                   s_axis_rc_tlast,
  input                                   s_axis_rc_tvalid,
  input                [KEEP_WIDTH-1:0]   s_axis_rc_tkeep,
  input       [AXI4_RC_TUSER_WIDTH-1:0]   s_axis_rc_tuser,
  output wire                             s_axis_rc_tready,

  //----------------------------------------------
  // AXI-S Requester Request Interface
  //----------------------------------------------

  output wire        [C_DATA_WIDTH-1:0]   m_axis_rq_tdata,
  output wire          [KEEP_WIDTH-1:0]   m_axis_rq_tkeep,
  output wire                             m_axis_rq_tlast,
  output wire                             m_axis_rq_tvalid,
  output wire [AXI4_RQ_TUSER_WIDTH-1:0]   m_axis_rq_tuser,
  input                                   m_axis_rq_tready,

  //----------------------------------------------
  // PIO Interrupt Interface
  //----------------------------------------------

  output wire                      interrupt_done,  // Indicates whether interrupt is done or in process

  //----------------------------------------------
  //Register Access Interface
  //----------------------------------------------

  output wire                      regreq_axis_tvalid_cifup,
  output wire                      regreq_axis_tvalid_cifdn,
  output wire                      regreq_axis_tvalid_dmar,
  output wire                      regreq_axis_tvalid_dmat,
  output wire            [511:0]   regreq_axis_tdata,
  output wire                      regreq_axis_tlast,
  output wire             [63:0]   regreq_axis_tuser,

  //----------------------------------------------
  //Register Access Read Reply Interface
  //----------------------------------------------

  input                            regrep_axis_tvalid_cifup,
  input                            regrep_axis_tvalid_cifdn,
  input                            regrep_axis_tvalid_dmar,
  input                            regrep_axis_tvalid_dmat,
  input                   [31:0]   regrep_axis_tdata_cifup,
  input                   [31:0]   regrep_axis_tdata_cifdn,
  input                   [31:0]   regrep_axis_tdata_dmar,
  input                   [31:0]   regrep_axis_tdata_dmat,

  //----------------------------------------------
  //RQ Request Interface
  //----------------------------------------------

  input                            rq_dmar_crd_axis_tvalid,
  input                  [511:0]   rq_dmar_crd_axis_tdata,
  input                            rq_dmar_crd_axis_tlast,
  output wire                      rq_dmar_crd_axis_tready,

  input                            rq_dmar_cwr_axis_tvalid,
  input                  [511:0]   rq_dmar_cwr_axis_tdata,
  input                            rq_dmar_cwr_axis_tlast,
  output wire                      rq_dmar_cwr_axis_tready,

  input                            rq_dmar_rd_axis_tvalid,
  input                  [511:0]   rq_dmar_rd_axis_tdata,
  input                            rq_dmar_rd_axis_tlast,
  output wire                      rq_dmar_rd_axis_tready,

  input                            rq_dmaw_dwr_axis_tvalid,
  input                  [511:0]   rq_dmaw_dwr_axis_tdata,
  input                            rq_dmaw_dwr_axis_tlast,
  output wire                      rq_dmaw_dwr_axis_tready,
  output wire                      rq_dmaw_dwr_axis_wr_ptr,
  output wire                      rq_dmaw_dwr_axis_rd_ptr,

  input                            rq_dmaw_cwr_axis_tvalid,
  input                  [511:0]   rq_dmaw_cwr_axis_tdata,
  input                            rq_dmaw_cwr_axis_tlast,
  output wire                      rq_dmaw_cwr_axis_tready,

  input                            rq_dmaw_crd_axis_tvalid,
  input                  [511:0]   rq_dmaw_crd_axis_tdata,
  input                            rq_dmaw_crd_axis_tlast,
  output wire                      rq_dmaw_crd_axis_tready,

  //----------------------------------------------
  //RC Read Reply Interface
  //----------------------------------------------

  output wire                      rc_axis_tvalid_dmar,
  output wire                      rc_axis_tvalid_dmat,
  output wire            [511:0]   rc_axis_tdata,
  output wire                      rc_axis_tlast,
  output wire             [15:0]   rc_axis_tkeep,
  output wire             [15:0]   rc_axis_tuser,
  output wire             [11:0]   rc_axis_taddr_dmar,
  input                            rc_axis_tready_dmar,
  input                            rc_axis_tready_dmat,

  //----------------------------------------------
  //PA/Trace Interface (to other module)
  //----------------------------------------------

  output wire            dbg_enable,         // PA ENB
  output wire            dbg_count_reset,    // PA CLR
  output wire            dma_trace_enable,   // TRACE ENB
  output wire            dma_trace_rst,      // TRACE CLR
  output wire   [31:0]   dbg_freerun_count,  // TRACE FREERUN COUNT

  //----------------------------------------------
  //MSI Int User Interface
  //----------------------------------------------

  input                   [31:0]   cfg_interrupt_msi_int_user,

  //----------------------------------------------
  //Tag availability and Flow control Information
  //----------------------------------------------

  input                    [3:0]   pcie_rq_seq_num,
  input                            pcie_rq_seq_num_vld,
  input                    [5:0]   pcie_rq_tag,
  input                            pcie_rq_tag_vld,
  input                    [3:0]   pcie_tfc_nph_av,
  input                    [3:0]   pcie_tfc_npd_av,
  input                            pcie_tfc_np_pl_empty,
  input                    [5:0]   pcie_cq_np_req_count,
  output wire                      pcie_cq_np_req,

  //----------------------------------------------
  // RX Message Interface
  //----------------------------------------------

  input                            cfg_msg_received,
  input                    [4:0]   cfg_msg_received_type,
  input                    [7:0]   cfg_msg_received_data,//cfg_msg_data -> cfg_msg_received_data

  //----------------------------------------------
  // TX Message Interface
  //----------------------------------------------

  input                            cfg_msg_transmit_done,
  output wire                      cfg_msg_transmit,
  output wire              [2:0]   cfg_msg_transmit_type,
  output wire             [31:0]   cfg_msg_transmit_data,

  //----------------------------------------------
  //Cfg Max Payload, Max Read Req
  //----------------------------------------------

  input                    [1:0]   cfg_max_payload,
  input                    [2:0]   cfg_max_read_req,

  //----------------------------------------------
  //Cfg Error
  //----------------------------------------------

  input                    [4:0]   cfg_local_error_out,
  input                            cfg_local_error_valid,

  //----------------------------------------------
  //Cfg Flow Control Information
  //----------------------------------------------

  input                    [7:0]   cfg_fc_ph,
  input                    [7:0]   cfg_fc_nph,
  input                    [7:0]   cfg_fc_cplh,
  input                   [11:0]   cfg_fc_pd,
  input                   [11:0]   cfg_fc_npd,
  input                   [11:0]   cfg_fc_cpld,
  output                   [2:0]   cfg_fc_sel,

  //----------------------------------------------
  // MSI Interrupt Interface
  //----------------------------------------------

  input                            cfg_interrupt_msi_enable,
  input                            cfg_interrupt_msi_sent,
  input                            cfg_interrupt_msi_fail,
  output wire             [31:0]   cfg_interrupt_msi_int,

  //----------------------------------------------
  //MSI-X Interrupt Interface
  //----------------------------------------------

  input                            cfg_interrupt_msix_enable,
  input                            cfg_interrupt_msix_sent,
  input                            cfg_interrupt_msix_fail,
  output wire                      cfg_interrupt_msix_int,
  output wire             [63:0]   cfg_interrupt_msix_address,
  output wire             [31:0]   cfg_interrupt_msix_data,

  //----------------------------------------------
  // Legacy Interrupt Interface
  //----------------------------------------------

  input                            cfg_interrupt_sent, // Core asserts this signal when it sends out a Legacy interrupt
  output wire              [3:0]   cfg_interrupt_int,  // 4 Bits for INTA, INTB, INTC, INTD (assert or deassert)

  //----------------------------------------------
  //completion Interface
  //----------------------------------------------

  output wire                      req_completion,
  output wire                      completion_done,

  //----------------------------------------------
  // Error detect
  //----------------------------------------------

  input                            error_detect_dma_tx,
  input                            error_detect_dma_rx,
  input                            error_detect_cif_up,
  input                            error_detect_cif_dn,
  output wire                      error_detect_lldma


  );

   // Local wires

  wire    [31:0]   reg_arb;

  wire    [31:0]   pa_dmaw_pkt_cnt;
  wire    [31:0]   pa_dmar_pkt_cnt;
  wire    [31:0]   pa_enque_poling_pkt_cnt;
  wire    [31:0]   pa_enque_clear_pkt_cnt;
  wire    [31:0]   pa_deque_poling_pkt_cnt;
  wire    [31:0]   pa_deque_pkt_cnt;

  wire             en_pa_pkt_cnt;
  wire             rst_pa_pkt_cnt;
  wire   [511:0]   deque_pkt_hold;

  wire             gen_leg_intr;
  wire             gen_msi_intr;
  wire             gen_msix_intr;

  // ---------------------------------------------------
  // PIO_EP_MEM_ACCESS
  // ---------------------------------------------------

  pio_ep_mem_access #(
    .FPGA_INFO        ( FPGA_INFO ),
    .C_DATA_WIDTH     ( C_DATA_WIDTH ),
    .ADDR_W           (ADDR_W        ),
    .MEM_W            (MEM_W         ),
    .BYTE_EN_W        (BYTE_EN_W     )
  
  ) ep_mem (

    .user_clk  (user_clk),
    .reset_n   (reset_n ),

    //AXI4-Lite 

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

    // CMS IF

    .s_d2d_req_valid (s_d2d_req_valid ),
    .s_d2d_ack_valid (s_d2d_ack_valid ),
    .s_d2d_data      (s_d2d_data      ),
    .s_d2d_ready     (s_d2d_ready     ),

    // arb ctrl

    .reg_arb         (reg_arb    ),

    // PA Interface

    .pa_dmaw_pkt_cnt         (pa_dmaw_pkt_cnt        ),
    .pa_dmar_pkt_cnt         (pa_dmar_pkt_cnt        ),
    .pa_enque_poling_pkt_cnt (pa_enque_poling_pkt_cnt),
    .pa_enque_clear_pkt_cnt  (pa_enque_clear_pkt_cnt ),
    .pa_deque_poling_pkt_cnt (pa_deque_poling_pkt_cnt),
    .pa_deque_pkt_cnt        (pa_deque_pkt_cnt       ),

    .en_pa_pkt_cnt           (en_pa_pkt_cnt          ),
    .rst_pa_pkt_cnt          (rst_pa_pkt_cnt         ),

    // Debug Deque Data

    .deque_pkt_hold           (deque_pkt_hold          ),

    // PA/Trace Interface (to DMA_RX)

    .dbg_enable               (dbg_enable              ),
    .dbg_count_reset          (dbg_count_reset         ),
    .dma_trace_enable         (dma_trace_enable        ),
    .dma_trace_rst            (dma_trace_rst           ),
    .dbg_freerun_count        (dbg_freerun_count       ),

    // Cfg Max Payload, Max Read Req Interface

    .cfg_max_payload          (cfg_max_payload  ),
    .cfg_max_read_req         (cfg_max_read_req ),

    // Cfg Error

    .cfg_local_error_out      (cfg_local_error_out     ),
    .cfg_local_error_valid    (cfg_local_error_valid   ),

    //Register Access Interface

//    .regreq_axis_tvalid_enqc (regreq_axis_tvalid_enqc ),
    .regreq_axis_tvalid_cifup (regreq_axis_tvalid_cifup ),
    .regreq_axis_tvalid_cifdn (regreq_axis_tvalid_cifdn ),
    .regreq_axis_tvalid_dmar  (regreq_axis_tvalid_dmar  ),
    .regreq_axis_tvalid_dmat  (regreq_axis_tvalid_dmat  ),
    .regreq_axis_tdata        (regreq_axis_tdata        ),
    .regreq_axis_tlast        (regreq_axis_tlast        ),
    .regreq_axis_tuser        (regreq_axis_tuser        ),

   //Register Access Read Reply Interface

//    .regrep_axis_tvalid_enqc (regrep_axis_tvalid_enqc ),
    .regrep_axis_tvalid_cifup (regrep_axis_tvalid_cifup ),
    .regrep_axis_tvalid_cifdn (regrep_axis_tvalid_cifdn ),
    .regrep_axis_tvalid_dmar  (regrep_axis_tvalid_dmar  ),
    .regrep_axis_tvalid_dmat  (regrep_axis_tvalid_dmat  ),
//    .regrep_axis_tdata_enqc   (regrep_axis_tdata_enqc   ),
    .regrep_axis_tdata_cifup  (regrep_axis_tdata_cifup  ),
    .regrep_axis_tdata_cifdn  (regrep_axis_tdata_cifdn  ),
    .regrep_axis_tdata_dmar   (regrep_axis_tdata_dmar   ),
    .regrep_axis_tdata_dmat   (regrep_axis_tdata_dmat   ),

    // Transactions and Interrupts

    .gen_msix_intr   (gen_msix_intr  ),
    .gen_msi_intr    (gen_msi_intr   ),
    .gen_leg_intr    (gen_leg_intr   ),

    // Error detect

    .error_detect_dma_tx      (error_detect_dma_tx      ),
    .error_detect_dma_rx      (error_detect_dma_rx      ),
    .error_detect_cif_up      (error_detect_cif_up      ),
    .error_detect_cif_dn      (error_detect_cif_dn      ),
    .error_detect_lldma       (error_detect_lldma       )

  );


  // ---------------------------------------------------
  // PIO_TX_ENGINE
  // ---------------------------------------------------

  pio_tx_engine #(
    .AXISTEN_IF_WIDTH             ( AXISTEN_IF_WIDTH ),
    .C_DATA_WIDTH                 ( C_DATA_WIDTH     ),
    .AXISTEN_IF_RQ_ALIGNMENT_MODE ( AXISTEN_IF_RQ_ALIGNMENT_MODE ),
    .AXISTEN_IF_CC_ALIGNMENT_MODE ( AXISTEN_IF_CC_ALIGNMENT_MODE ),
    .AXI4_CC_TUSER_WIDTH          ( AXI4_CC_TUSER_WIDTH),
    .AXI4_RQ_TUSER_WIDTH          ( AXI4_RQ_TUSER_WIDTH),
    .AXISTEN_IF_ENABLE_CLIENT_TAG ( AXISTEN_IF_ENABLE_CLIENT_TAG ),
    .AXISTEN_IF_RQ_PARITY_CHECK   ( AXISTEN_IF_RQ_PARITY_CHECK ),
    .AXISTEN_IF_CC_PARITY_CHECK   ( AXISTEN_IF_CC_PARITY_CHECK ),
    .ADDR_W                       ( ADDR_W ),     
    .MEM_W                        ( MEM_W ),	
    .BYTE_EN_W                    ( BYTE_EN_W )	
  ) ep_tx (
    .user_clk ( user_clk ),
    .reset_n  ( reset_n  ),

    // AXI-S Master Request Interface

    .m_axis_rq_tdata  ( m_axis_rq_tdata  ),
    .m_axis_rq_tkeep  ( m_axis_rq_tkeep  ),
    .m_axis_rq_tlast  ( m_axis_rq_tlast  ),
    .m_axis_rq_tvalid ( m_axis_rq_tvalid ),
    .m_axis_rq_tuser  ( m_axis_rq_tuser  ),
    .m_axis_rq_tready ( m_axis_rq_tready ),

    // TX Message Interface

    .cfg_msg_transmit_done ( cfg_msg_transmit_done ),
    .cfg_msg_transmit      ( cfg_msg_transmit      ),
    .cfg_msg_transmit_type ( cfg_msg_transmit_type ),
    .cfg_msg_transmit_data ( cfg_msg_transmit_data ),

    // Tag availability and Flow control Information

    .pcie_rq_tag          ( pcie_rq_tag          ),
    .pcie_rq_tag_vld      ( pcie_rq_tag_vld      ),
    .pcie_tfc_nph_av      ( pcie_tfc_nph_av      ),
    .pcie_tfc_npd_av      ( pcie_tfc_npd_av      ),
    .pcie_tfc_np_pl_empty ( pcie_tfc_np_pl_empty ),
    .pcie_rq_seq_num      ( pcie_rq_seq_num      ),
    .pcie_rq_seq_num_vld  ( pcie_rq_seq_num_vld  ),

    // Cfg Flow Control Information

    .cfg_fc_ph   ( cfg_fc_ph   ),
    .cfg_fc_nph  ( cfg_fc_nph  ),
    .cfg_fc_cplh ( cfg_fc_cplh ),
    .cfg_fc_pd   ( cfg_fc_pd   ),
    .cfg_fc_npd  ( cfg_fc_npd  ),
    .cfg_fc_cpld ( cfg_fc_cpld ),
    .cfg_fc_sel  ( cfg_fc_sel  ),

    // Arb Control Interface

    .reg_arb             ( reg_arb         ), 

    // PA Interface

    .pa_dmaw_pkt_cnt         (pa_dmaw_pkt_cnt        ),
    .pa_dmar_pkt_cnt         (pa_dmar_pkt_cnt        ),
    .pa_enque_poling_pkt_cnt (pa_enque_poling_pkt_cnt),
    .pa_enque_clear_pkt_cnt  (pa_enque_clear_pkt_cnt ),
    .pa_deque_poling_pkt_cnt (pa_deque_poling_pkt_cnt),
    .pa_deque_pkt_cnt        (pa_deque_pkt_cnt       ),

    .en_pa_pkt_cnt           (en_pa_pkt_cnt          ),
    .rst_pa_pkt_cnt          (rst_pa_pkt_cnt         ),

    // Debug Deque Data

    .deque_pkt_hold          ( deque_pkt_hold          ),

    //RQ Request Interface

    .rq_dmar_crd_axis_tvalid ( rq_dmar_crd_axis_tvalid ),
    .rq_dmar_crd_axis_tdata  ( rq_dmar_crd_axis_tdata  ),
    .rq_dmar_crd_axis_tlast  ( rq_dmar_crd_axis_tlast  ),
    .rq_dmar_crd_axis_tready ( rq_dmar_crd_axis_tready ),

    .rq_dmar_cwr_axis_tvalid ( rq_dmar_cwr_axis_tvalid ),
    .rq_dmar_cwr_axis_tdata  ( rq_dmar_cwr_axis_tdata  ),
    .rq_dmar_cwr_axis_tlast  ( rq_dmar_cwr_axis_tlast  ),
    .rq_dmar_cwr_axis_tready ( rq_dmar_cwr_axis_tready ),

    .rq_dmar_rd_axis_tvalid  ( rq_dmar_rd_axis_tvalid  ),
    .rq_dmar_rd_axis_tdata   ( rq_dmar_rd_axis_tdata   ),
    .rq_dmar_rd_axis_tlast   ( rq_dmar_rd_axis_tlast   ),
    .rq_dmar_rd_axis_tready  ( rq_dmar_rd_axis_tready  ),

    .rq_dmaw_dwr_axis_tvalid ( rq_dmaw_dwr_axis_tvalid ),
    .rq_dmaw_dwr_axis_tdata  ( rq_dmaw_dwr_axis_tdata  ),
    .rq_dmaw_dwr_axis_tlast  ( rq_dmaw_dwr_axis_tlast  ),
    .rq_dmaw_dwr_axis_tready ( rq_dmaw_dwr_axis_tready ),
    .rq_dmaw_dwr_axis_wr_ptr ( rq_dmaw_dwr_axis_wr_ptr ),
    .rq_dmaw_dwr_axis_rd_ptr ( rq_dmaw_dwr_axis_rd_ptr ),

    .rq_dmaw_cwr_axis_tvalid ( rq_dmaw_cwr_axis_tvalid ),
    .rq_dmaw_cwr_axis_tdata  ( rq_dmaw_cwr_axis_tdata  ),
    .rq_dmaw_cwr_axis_tlast  ( rq_dmaw_cwr_axis_tlast  ),
    .rq_dmaw_cwr_axis_tready ( rq_dmaw_cwr_axis_tready ),

    .rq_dmaw_crd_axis_tvalid ( rq_dmaw_crd_axis_tvalid ),
    .rq_dmaw_crd_axis_tdata  ( rq_dmaw_crd_axis_tdata  ),
    .rq_dmaw_crd_axis_tlast  ( rq_dmaw_crd_axis_tlast  ),
    .rq_dmaw_crd_axis_tready ( rq_dmaw_crd_axis_tready )

    );

  // ---------------------------------------------------
  // PIO_INTR_CTRL
  // ---------------------------------------------------

  pio_intr_ctrl ep_intr_ctrl(

    .user_clk ( user_clk ),
    .reset_n  ( reset_n  ),

    // Trigger to generate interrupts (to / from Mem access Block)

    .u_gen_leg_intr  ( 1'b0 ),
    .u_gen_msi_intr  ( 1'b0 ),
    .u_gen_msix_intr ( 1'b0 ),
    
    .gen_leg_intr    ( gen_leg_intr    ),
    .gen_msi_intr    ( gen_msi_intr    ),
    .gen_msix_intr   ( gen_msix_intr   ),
    .interrupt_done  ( interrupt_done  ),

    // Legacy Interrupt Interface

    .cfg_interrupt_sent ( cfg_interrupt_sent ),
    .cfg_interrupt_int  ( cfg_interrupt_int  ),

    // MSI Interrupt Interface

    .cfg_interrupt_msi_enable   ( cfg_interrupt_msi_enable   ),
    .cfg_interrupt_msi_sent     ( cfg_interrupt_msi_sent     ),
    .cfg_interrupt_msi_fail     ( cfg_interrupt_msi_fail     ),

    .cfg_interrupt_msi_int_user ( cfg_interrupt_msi_int_user ),
    
    .cfg_interrupt_msi_int      ( cfg_interrupt_msi_int      ),

    //MSI-X Interrupt Interface

    .cfg_interrupt_msix_enable  ( cfg_interrupt_msix_enable  ),
    .cfg_interrupt_msix_sent    ( cfg_interrupt_msix_sent    ),
    .cfg_interrupt_msix_fail    ( cfg_interrupt_msix_fail    ),

    .cfg_interrupt_msix_int     ( cfg_interrupt_msix_int     ),
    .cfg_interrupt_msix_address ( cfg_interrupt_msix_address ),
    .cfg_interrupt_msix_data    ( cfg_interrupt_msix_data    )

    );

  // ---------------------------------------------------
  // DATA_RECEIVE
  // ---------------------------------------------------

  data_receive data_receive(
    .user_clk ( user_clk ),
    .reset_n  ( reset_n  ),

    // Completion Interface from Hard-IP

    .s_axis_rc_tdata      ( s_axis_rc_tdata  ),
    .s_axis_rc_tkeep      ( s_axis_rc_tkeep  ),
    .s_axis_rc_tlast      ( s_axis_rc_tlast  ),
    .s_axis_rc_tvalid     ( s_axis_rc_tvalid ),
    .s_axis_rc_tuser      ( s_axis_rc_tuser[16:0] ),//size modify
    .s_axis_rc_tready     ( s_axis_rc_tready ),

    // Completion Interface to enq_ctrl,dma_rx

    .rc_axis_tvalid_dmar  ( rc_axis_tvalid_dmar ),
    .rc_axis_tvalid_dmat  ( rc_axis_tvalid_dmat ),
    .rc_axis_tdata        ( rc_axis_tdata       ),
    .rc_axis_tlast        ( rc_axis_tlast       ),
    .rc_axis_tkeep        ( rc_axis_tkeep       ),
    .rc_axis_tuser        ( rc_axis_tuser       ),
    .rc_axis_taddr_dmar   ( rc_axis_taddr_dmar  ),
    .rc_axis_tready_dmar  ( rc_axis_tready_dmar ),
    .rc_axis_tready_dmat  ( rc_axis_tready_dmat )

    );

  // ---------------------------------------------------
  // logic
  // ---------------------------------------------------

    assign req_completion  = 0;
    assign completion_done = interrupt_done ;
    assign pcie_cq_np_req  = 0;

endmodule // pci_trx



