// Sentry Control Top Level
`timescale 1ns / 1ps
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

`define GEARBOX_OPT

module sentryControl_top(
    // AXI Interfaces
    // AXI4 Master Interface For Instruction Memory
    input  logic                        m00_axi_aclk,       // global clock
    input  logic                        m00_axi_aresetn,      // global reset, active low
    // write interface
    // write address
    output logic                        m00_axi_awid,         // write address id, 1'b0
    output logic [ 31:0]                m00_axi_awaddr,       // write address
    output logic [  7:0]                m00_axi_awlen,        // number of write transfers in a burst
    output logic [  2:0]                m00_axi_awsize,       // size of each write transfer in a burst
    output logic [  1:0]                m00_axi_awburst,      // write burst type, 2'b01
    output logic                        m00_axi_awlock,       // 1'b0, not used
    output logic [  3:0]                m00_axi_awcache,      // memory type, 4'b0010
    output logic [  2:0]                m00_axi_awprot,       // protection type, 3'h0
    output logic [  3:0]                m00_axi_awqos,        // quality of service identifier, 4'h0
    //output logic                        m00_axi_awuser,       // option user defined channel, 1'b1
    output logic                        m00_axi_awvalid,      // write address valid
    input  logic                        m00_axi_awready,      // write address ready
    // write data
    output logic [511:0]                m00_axi_wdata,        // write data
    output logic [ 63:0]                m00_axi_wstrb,        // write strobes (byte write enable)
    output logic                        m00_axi_wlast,        // indicates last transfer in a burst
    //output logic                        m00_axi_wuser,        // option user defined channel, 1'b0
    output logic                        m00_axi_wvalid,       // write data valid
    input  logic                        m00_axi_wready,       // write data ready
    // write response
    input  logic                        m00_axi_bid,          // master inteface write response
    input  logic [  1:0]                m00_axi_bresp,        // write response for write transaction
    //input  logic                        m00_axi_buser,        // option user defined channel
    input  logic                        m00_axi_bvalid,       // write response valid
    output logic                        m00_axi_bready,       // write response ready, master can accept another transaction
    // read interface
    // read address
    output logic                        m00_axi_arid,         // read address id, 1'b0
    output logic [ 31:0]                m00_axi_araddr,       // read address
    output logic [  7:0]                m00_axi_arlen,        // number of read transfers in a burst
    output logic [  2:0]                m00_axi_arsize,       // size of each read transfer in a burst
    output logic [  1:0]                m00_axi_arburst,      // read burst type, 2'b01
    output logic                        m00_axi_arlock,       // 1'b0, not used
    output logic [  3:0]                m00_axi_arcache,      // memory type, 4'b0010
    output logic [  2:0]                m00_axi_arprot,       // protection type, 3'h0
    output logic [  3:0]                m00_axi_arqos,        // quality of service identifier, 4'h0
    //output logic                        m00_axi_aruser,       // option user defined channel, 1'b1
    output logic                        m00_axi_arvalid,      // read address valid
    input  logic                        m00_axi_arready,      // read address ready
    // read data
    input  logic                        m00_axi_rid,          // master inteface write response
    input  logic [511:0]                m00_axi_rdata,        // read data
    input  logic [  1:0]                m00_axi_rresp,        // read response for read transaction
    input  logic                        m00_axi_rlast,        // indicates last transfer in a burst
    //input  logic                        m00_axi_ruser,        // option user defined channel
    input  logic                        m00_axi_rvalid,       // read data valid
    output logic                        m00_axi_rready,       // read data ready, master can accept read data
    // AXI4 Master Interface For Data Memory
    input  logic                        m01_axi_aclk,       // global clock
    input  logic                        m01_axi_aresetn,    // global reset, active low
    // write interface
    // write address
    output logic                        m01_axi_awid,         // write address id, 1'b0
    output logic [ 31:0]                m01_axi_awaddr,       // write address
    output logic [  7:0]                m01_axi_awlen,        // number of write transfers in a burst
    output logic [  2:0]                m01_axi_awsize,       // size of each write transfer in a burst
    output logic [  1:0]                m01_axi_awburst,      // write burst type, 2'b01
    output logic                        m01_axi_awlock,       // 1'b0, not used
    output logic [  3:0]                m01_axi_awcache,      // memory type, 4'b0010
    output logic [  2:0]                m01_axi_awprot,       // protection type, 3'h0
    output logic [  3:0]                m01_axi_awqos,        // quality of service identifier, 4'h0
    //output logic                        m01_axi_awuser,       // option user defined channel, 1'b1
    output logic                        m01_axi_awvalid,      // write address valid
    input  logic                        m01_axi_awready,      // write address ready
    // write data
    output logic [511:0]                m01_axi_wdata,        // write data
    output logic [ 63:0]                m01_axi_wstrb,        // write strobes (byte write enable)
    output logic                        m01_axi_wlast,        // indicates last transfer in a burst
    //output logic                        m01_axi_wuser,        // option user defined channel, 1'b0
    output logic                        m01_axi_wvalid,       // write data valid
    input  logic                        m01_axi_wready,       // write data ready
    // write response
    input  logic                        m01_axi_bid,          // master inteface write response
    input  logic [  1:0]                m01_axi_bresp,        // write response for write transaction
    //input  logic                        m01_axi_buser,        // option user defined channel
    input  logic                        m01_axi_bvalid,       // write response valid
    output logic                        m01_axi_bready,       // write response ready, master can accept another transaction
    // read interface
    // read address
    output logic                        m01_axi_arid,         // read address id, 1'b0
    output logic [ 31:0]                m01_axi_araddr,       // read address
    output logic [  7:0]                m01_axi_arlen,        // number of read transfers in a burst
    output logic [  2:0]                m01_axi_arsize,       // size of each read transfer in a burst
    output logic [  1:0]                m01_axi_arburst,      // read burst type, 2'b01
    output logic                        m01_axi_arlock,       // 1'b0, not used
    output logic [  3:0]                m01_axi_arcache,      // memory type, 4'b0010
    output logic [  2:0]                m01_axi_arprot,       // protection type, 3'h0
    output logic [  3:0]                m01_axi_arqos,        // quality of service identifier, 4'h0
    //output logic                        m01_axi_aruser,       // option user defined channel, 1'b1
    output logic                        m01_axi_arvalid,      // read address valid
    input  logic                        m01_axi_arready,      // read address ready
    // read data
    input  logic                        m01_axi_rid,          // master inteface write response
    input  logic [511:0]                m01_axi_rdata,        // read data
    input  logic [  1:0]                m01_axi_rresp,        // read response for read transaction
    input  logic                        m01_axi_rlast,        // indicates last transfer in a burst
    //input  logic                        m01_axi_ruser,        // option user defined channel
    input  logic                        m01_axi_rvalid,       // read data valid
    output logic                        m01_axi_rready,       // read data ready, master can accept read data
    // trace buffer interface
    `ifdef INST_RESULT
        input                               trace_ready,
        input  quad_trace_s                 trace_data,
        output                              trace_en,
    `else
        input                               trace_ready,
        input   quad_jump_result_s          trace_data,
        output                              trace_en,
    `endif
    // interface to fifos
    //inst pkt1 fifo (round-robin)
    output pkt1_t                       inst_pkt1_fifo_input    [`SENTRY_WIDTH-1:0],
    output logic [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_wr_en,
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_full,
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_almost_full,
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_prog_full,
    // data pkt1 fifo (round-robin)
    output pkt1_t                       data_pkt1_fifo_input,
    output logic [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_wr_en,
    input  logic [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_full,
    input  logic [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_almost_full,
    input  logic [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_prog_full,
    // inst pkt2 fifo (round-robin)
    output pkt2_t                       inst_pkt2_fifo_input,
    output logic [`SENTRY_WIDTH-1:0]    inst_pkt2_fifo_wr_en,
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt2_fifo_full,
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt2_fifo_almost_full,
    // data pkt2 fifo (round-robin)
    output pkt2_t                       data_pkt2_fifo_input,
    output logic [`SENTRY_WIDTH-1:0]    data_pkt2_fifo_wr_en,
    input  logic [`SENTRY_WIDTH-1:0]    data_pkt2_fifo_full,
    input  logic [`SENTRY_WIDTH-1:0]    data_pkt2_fifo_almost_full,
    `ifdef SMAC
        // inst pkt3 fifo (round-robin)
        output pkt3_t                       inst_pkt3_fifo_input,
        output logic [`SENTRY_WIDTH-1:0]    inst_pkt3_fifo_wr_en,
        input  logic [`SENTRY_WIDTH-1:0]    inst_pkt3_fifo_full,
        input  logic [`SENTRY_WIDTH-1:0]    inst_pkt3_fifo_almost_full,
        // data pkt3 fifo (round-robin)
        output pkt3_t                       data_pkt3_fifo_input,
        output logic [`SENTRY_WIDTH-1:0]    data_pkt3_fifo_wr_en,
        input  logic [`SENTRY_WIDTH-1:0]    data_pkt3_fifo_full,
        input  logic [`SENTRY_WIDTH-1:0]    data_pkt3_fifo_almost_full,
    `endif
    // interface to data_vpkt_fifo
    output vpkt_t                       data_vpkt_fifo_input,
    output logic [`SENTRY_WIDTH-1:0]    data_vpkt_fifo_wr_en,
    input  logic [`SENTRY_WIDTH-1:0]    data_vpkt_fifo_full,
    input  logic [`SENTRY_WIDTH-1:0]    data_vpkt_fifo_almost_full,
    // interface from victim data buffer
    `ifdef DATA_COUNT
        input  [`QCNT_WIDTH-1:0]            victim_data_fifo_rd_data_count,
    `endif
    input  victim_data_t                victim_data_fifo_output,
    input  logic                        victim_data_fifo_empty,
    output logic                        victim_data_fifo_rd_en,
    // sentry control clock and reset
    input                               control_clk,
    input                               gearbox_clk,
    input                               icache_clk,
    input                               dcache_clk,
    input                               cam_clk,
    input                               sentry_clk,
    input                               rst
);

parameter MEM_BASE_ADDR = `DDR_BASE_ADDR;

genvar i;

//******************************
// sentryControl central control
//******************************

// instruction cache access request before instruction cache
wire [`SENTRY_WIDTH-1:0]    icache_req_valid;
addr_t                      icache_req_address      [`SENTRY_WIDTH-1:0];
data_t                      icache_req_inst_result  [`SENTRY_WIDTH-1:0];

// parallel instruction cache access request fifo before instruction cache
addr_t                      icache_parallel_req_address      [`SENTRY_WIDTH-1:0];
data_t                      icache_parallel_req_inst_result  [`SENTRY_WIDTH-1:0];

`ifdef PARALLEL_ICACHE

    // instruction cache parallel access request fifo with result,
    // as buffer BEFORE parallel instruciton cache
    wire                                            icache_parallel_req_fifo_rd_en;
    wire [`SENTRY_WIDTH*(`ADDR_WIDTH+`X_LEN)-1:0]   icache_parallel_req_fifo_output;
    wire                                            icache_parallel_req_fifo_wr_en;
    wire [`SENTRY_WIDTH*(`ADDR_WIDTH+`X_LEN)-1:0]   icache_parallel_req_fifo_input; //icache req fifo also carries result
    wire                                            icache_parallel_req_fifo_full;
    wire                                            icache_parallel_req_fifo_empty;
    wire                                            icache_parallel_req_fifo_almost_full;
    wire                                            icache_parallel_req_fifo_almost_empty;
    wire                                            icache_parallel_req_fifo_prog_full;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]                        icache_parallel_req_fifo_data_count;
    `endif

    // inst mem access request fifo BEFORE 4-to-4 gear box
    wire                                            imem_parallel_gearbox_rd_en;
    mem_req_t                                       imem_parallel_gearbox_output;
    wire [`SENTRY_WIDTH-1:0]                        imem_parallel_gearbox_wr_en;
    mem_req_t                                       imem_parallel_gearbox_input    [`SENTRY_WIDTH-1:0];
    wire                                            imem_parallel_gearbox_flush;
    wire                                            imem_parallel_gearbox_full;
    wire                                            imem_parallel_gearbox_empty;
    wire                                            imem_parallel_gearbox_almost_full;
    wire                                            imem_parallel_gearbox_almost_empty;
    wire                                            imem_parallel_gearbox_prog_full;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]                        imem_parallel_gearbox_wr_data_count;
        wire [`QCNT_WIDTH-1 : 0]                        imem_parallel_gearbox_rd_data_count;
    `endif

    // inst mem access request fifo AFTER 4-to-4 gear box
    wire                                            imem_filter_req_fifo_rd_en;
    wire [96:0]                                     imem_filter_req_fifo_output;
    wire                                            imem_filter_req_fifo_wr_en;
    wire [`SENTRY_WIDTH*97-1:0]                     imem_filter_req_fifo_input;
    wire                                            imem_filter_req_fifo_full;
    wire                                            imem_filter_req_fifo_empty;
    wire                                            imem_filter_req_fifo_almost_full;
    wire                                            imem_filter_req_fifo_almost_empty;
    wire                                            imem_filter_req_fifo_prog_full;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]                        imem_filter_req_fifo_wr_data_count;
        wire [`QCNT_WIDTH-1 : 0]                        imem_filter_req_fifo_rd_data_count;
    `endif

`else

    // instruction cache access request fifo BEFORE sequential instruction cache
    wire                                            icache_req_fifo_rd_en;
    addr_result_t                                   icache_req_fifo_output;
    wire                                            icache_req_fifo_wr_en;
    wire [`SENTRY_WIDTH*(`ADDR_WIDTH+`X_LEN)-1:0]   icache_req_fifo_input; //icache req fifo also carries result
    wire                                            icache_req_fifo_full;
    wire                                            icache_req_fifo_empty;
    wire                                            icache_req_fifo_almost_full;
    wire                                            icache_req_fifo_almost_empty;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]                        icache_req_fifo_wr_data_count;
        wire [`QCNT_WIDTH+1 : 0]                        icache_req_fifo_rd_data_count;
    `endif

    // instruction memory controller AFTER sequential instruction cache
    wire                                            imem_req_fifo_rd_en;
    mem_req_t                                       imem_req_fifo_output;
    wire                                            imem_req_fifo_wr_en;
    mem_req_t                                       imem_req_fifo_input;
    wire                                            imem_req_fifo_full;
    wire                                            imem_req_fifo_empty;
    wire                                            imem_req_fifo_almost_full;
    wire                                            imem_req_fifo_almost_empty;
    wire                                            imem_req_fifo_prog_full;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]                        imem_req_fifo_wr_data_count;
        wire [`QCNT_WIDTH-1 : 0]                        imem_req_fifo_rd_data_count;
    `endif

`endif


// data cache access request fifo BEFORE data cache
wire [`SENTRY_WIDTH-1:0]    dcache_req_valid;
wire [`SENTRY_WIDTH-1:0]    dcache_req_store;
addr_t                      dcache_req_address      [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]    dcache_inst_valid;

`ifdef GEARBOX_OPT
// data cache access request fifo AFTER 4-to-4 gear box
wire                                            dcache_req_fifo_rd_en;
wire [(`ADDR_WIDTH+32+1)-1:0]                   dcache_req_fifo_output;
wire                                            dcache_req_fifo_wr_en;
wire [`SENTRY_WIDTH*(`ADDR_WIDTH+32+1)-1:0]     dcache_req_fifo_input;
wire                                            dcache_req_fifo_full;
wire                                            dcache_req_fifo_empty;
wire                                            dcache_req_fifo_almost_full;
wire                                            dcache_req_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]                        dcache_req_fifo_wr_data_count;
    wire [`QCNT_WIDTH-1 : 0]                        dcache_req_fifo_rd_data_count;
`endif

`else

// data cache access request fifo BEFORE 4-to-1 gear box
wire                                            dcache_req_fifo1_rd_en;
wire [`SENTRY_WIDTH*(`ADDR_WIDTH+2)-1:0]        dcache_req_fifo1_output;
wire                                            dcache_req_fifo1_wr_en;
wire [`SENTRY_WIDTH*(`ADDR_WIDTH+2)-1:0]        dcache_req_fifo1_input;
wire                                            dcache_req_fifo1_full;
wire                                            dcache_req_fifo1_empty;
wire                                            dcache_req_fifo1_almost_full;
wire                                            dcache_req_fifo1_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]                        dcache_req_fifo1_wr_data_count;
    wire [`QCNT_WIDTH-1 : 0]                        dcache_req_fifo1_rd_data_count;
`endif

// data cache access request fifo AFTER 4-to-1 gear box
wire                                            dcache_req_fifo2_rd_en;
wire [`ADDR_WIDTH+32:0]                         dcache_req_fifo2_output;
wire                                            dcache_req_fifo2_wr_en;
wire [`ADDR_WIDTH+32:0]                         dcache_req_fifo2_input;
wire                                            dcache_req_fifo2_full;
wire                                            dcache_req_fifo2_empty;
wire                                            dcache_req_fifo2_almost_full;
wire                                            dcache_req_fifo2_almost_empty;
wire                                            dcache_req_fifo2_prog_full;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]                        dcache_req_fifo2_wr_data_count;
    wire [`QCNT_WIDTH-1 : 0]                        dcache_req_fifo2_rd_data_count;
`endif

`endif

// signal splitter BEFORE sequential data cache 
wire [27:0]                 dcache_req_fifo_number;
wire [3 :0]                 dcache_req_fifo_rotate;
wire                        dcache_req_fifo_store;
wire [63:0]                 dcache_req_fifo_address;

// victim addr fifo
wire                        victim_addr_fifo_rd_en;
addr_t                      victim_addr_fifo_output;
wire                        victim_addr_fifo_wr_en;
addr_t                      victim_addr_fifo_input;
wire                        victim_addr_fifo_full;
wire                        victim_addr_fifo_empty;
wire                        victim_addr_fifo_almost_full;
wire                        victim_addr_fifo_almost_empty;
wire                        victim_addr_fifo_prog_full;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]    victim_addr_fifo_wr_data_count;
    wire [`QCNT_WIDTH-1 : 0]    victim_addr_fifo_rd_data_count;
`endif

// data cam request fifo
wire                        dcam_req_fifo_rd_en;
mem_req_t                   dcam_req_fifo_output;
wire                        dcam_req_fifo_wr_en;
mem_req_t                   dcam_req_fifo_input;
wire                        dcam_req_fifo_full;
wire                        dcam_req_fifo_empty;
wire                        dcam_req_fifo_almost_full;
wire                        dcam_req_fifo_almost_empty;
wire                        dcam_req_fifo_prog_full;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]    dcam_req_fifo_wr_data_count;
    wire [`QCNT_WIDTH-1 : 0]    dcam_req_fifo_rd_data_count;
`endif

// data cam insert fifo
wire                        cam_insert_fifo_rd_en;
mem_req_t                   cam_insert_fifo_output;
wire                        cam_insert_fifo_wr_en;
mem_req_t                   cam_insert_fifo_input;
wire                        cam_insert_fifo_full;
wire                        cam_insert_fifo_empty;
wire                        cam_insert_fifo_almost_full;
wire                        cam_insert_fifo_almost_empty;
wire                        cam_insert_fifo_prog_full;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]    cam_insert_fifo_wr_data_count;
    wire [`QCNT_WIDTH-1 : 0]    cam_insert_fifo_rd_data_count;
`endif

// data cam clear fifo
wire                        cam_clear_fifo_rd_en;
addr_t                      cam_clear_fifo_output;
wire                        cam_clear_fifo_wr_en;
addr_t                      cam_clear_fifo_input;
wire                        cam_clear_fifo_full;
wire                        cam_clear_fifo_empty;
wire                        cam_clear_fifo_almost_full;
wire                        cam_clear_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]    cam_clear_fifo_wr_data_count;
    wire [`QCNT_WIDTH-1 : 0]    cam_clear_fifo_rd_data_count;
`endif

// data memory request fifo
wire                        dmem_req_fifo_rd_en;
mem_req_t                   dmem_req_fifo_output;
wire                        dmem_req_fifo_wr_en;
mem_req_t                   dmem_req_fifo_input;
wire                        dmem_req_fifo_full;
wire                        dmem_req_fifo_empty;
wire                        dmem_req_fifo_almost_full;
wire                        dmem_req_fifo_almost_empty;
wire                        dmem_req_fifo_prog_full;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]    dmem_req_fifo_wr_data_count;
    wire [`QCNT_WIDTH-1 : 0]    dmem_req_fifo_rd_data_count;
`endif

`ifdef SMAC
    // instruction shadow memory request fifo
    wire                        ismac_req_fifo_rd_en;
    mem_req_t                   ismac_req_fifo_output;
    wire                        ismac_req_fifo_wr_en;
    mem_req_t                   ismac_req_fifo_input;
    wire                        ismac_req_fifo_full;
    wire                        ismac_req_fifo_empty;
    wire                        ismac_req_fifo_almost_full;
    wire                        ismac_req_fifo_almost_empty;
    wire                        ismac_req_fifo_prog_full;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]    ismac_req_fifo_wr_data_count;
        wire [`QCNT_WIDTH-1 : 0]    ismac_req_fifo_rd_data_count;
    `endif
    // data shadow memory request fifo
    wire                        dsmac_req_fifo_rd_en;
    mem_req_t                   dsmac_req_fifo_output;
    wire                        dsmac_req_fifo_wr_en;
    mem_req_t                   dsmac_req_fifo_input;
    wire                        dsmac_req_fifo_full;
    wire                        dsmac_req_fifo_empty;
    wire                        dsmac_req_fifo_almost_full;
    wire                        dsmac_req_fifo_almost_empty;
    wire                        dsmac_req_fifo_prog_full;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]    dsmac_req_fifo_wr_data_count;
        wire [`QCNT_WIDTH-1 : 0]    dsmac_req_fifo_rd_data_count;
    `endif
`endif


`ifdef INST_RESULT
//********************************************************
// If we receive both instruction and result from the host
//********************************************************

sentryControl_ctrl_instResult CTRL_INSTRESULT (
    .clk		                (control_clk                    ),
    .rst		                (rst                            ),
    // Trace Buffer Interface
    .trace_ready                (trace_ready                    ),
    .trace_data                 (trace_data                     ),
    .trace_en                   (trace_en                       ),
    // Icache Handshake Interface
    `ifdef PARALLEL_ICACHE
    .icache_req_almost_full     (icache_parallel_req_fifo_almost_full    ), // use almost full for some cushion
    `else
    .icache_req_almost_full     (icache_req_fifo_almost_full    ), // use almost full for some cushion
    `endif
    .icache_req_valid           (icache_req_valid               ),
    .icache_req_address         (icache_req_address             ),
    .icache_req_inst_result     (icache_req_inst_result         ),
    // Dcache Handshake Interface
    `ifdef GEARBOX_OPT
    .dcache_req_almost_full     (dcache_req_fifo_almost_full    ), // use almost full for some cushion
    `else
    .dcache_req_almost_full     (dcache_req_fifo1_almost_full   ), // use almost full for some cushion
    `endif
    .dcache_req_valid           (dcache_req_valid               ),
    .dcache_req_store           (dcache_req_store               ),
    .dcache_req_address         (dcache_req_address             )
);

`ifndef GEARBOX_OPT
// icache_req_valid serves as a instruction valid signal 
// used for gearbox to keep din count
assign dcache_req_fifo1_wr_en = icache_req_valid != `SENTRY_WIDTH'd0;
`endif

`else
//********************************************************
// If we receive both jump bit and result from the host
//********************************************************

// If we only have jump flag and result, we need to feed inst pkts
// back to sentry control ctrl to fetch, decode and issue dcache req

// ctrl inst pkt1
wire [`SENTRY_WIDTH-1:0]        ctrl_inst_pkt1_fifo_wr_en;
pkt1_t                          ctrl_inst_pkt1_fifo_input         [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]        ctrl_inst_pkt1_fifo_rd_en;
pkt1_t                          ctrl_inst_pkt1_fifo_output        [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]        ctrl_inst_pkt1_fifo_full;
wire [`SENTRY_WIDTH-1:0]        ctrl_inst_pkt1_fifo_empty;
wire [`SENTRY_WIDTH-1:0]        ctrl_inst_pkt1_fifo_almost_full;
wire [`SENTRY_WIDTH-1:0]        ctrl_inst_pkt1_fifo_almost_empty;
`ifdef DATA_COUNT
    `ifdef PARALLEL_ICACHE
        wire [`QCNT_WIDTH-1 : 0]        ctrl_inst_pkt1_fifo_data_count      [`SENTRY_WIDTH-1:0];
    `else
        wire [`QCNT_WIDTH-1 : 0]        ctrl_inst_pkt1_fifo_wr_data_count   [`SENTRY_WIDTH-1:0];
        wire [`QCNT_WIDTH-1 : 0]        ctrl_inst_pkt1_fifo_rd_data_count   [`SENTRY_WIDTH-1:0];
    `endif
`endif
// ctrl inst pkt2
wire [`SENTRY_WIDTH-1:0]        ctrl_inst_pkt2_fifo_wr_en;
pkt2_t                          ctrl_inst_pkt2_fifo_input         [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]        ctrl_inst_pkt2_fifo_rd_en;
pkt2_t                          ctrl_inst_pkt2_fifo_output        [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]        ctrl_inst_pkt2_fifo_full;
wire [`SENTRY_WIDTH-1:0]        ctrl_inst_pkt2_fifo_empty;
wire [`SENTRY_WIDTH-1:0]        ctrl_inst_pkt2_fifo_almost_full;
wire [`SENTRY_WIDTH-1:0]        ctrl_inst_pkt2_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]        ctrl_inst_pkt2_fifo_wr_data_count    [`SENTRY_WIDTH-1:0];
    wire [`QCNT_WIDTH-1 : 0]        ctrl_inst_pkt2_fifo_rd_data_count    [`SENTRY_WIDTH-1:0];
`endif

sentryControl_ctrl_jumpResult CTRL_JUMPRESULT (
    // Trace Buffer Interface
    .trace_ready                        (trace_ready                        ),
    .trace_data                         (trace_data                         ),
    .trace_en                           (trace_en                           ),
    // Icache Handshake Interface
    `ifdef PARALLEL_ICACHE
    .icache_req_almost_full             (icache_parallel_req_fifo_almost_full    ), // use almost full for some cushion
    `else
    .icache_req_almost_full             (icache_req_fifo_almost_full    ), // use almost full for some cushion
    `endif
    .icache_req_valid                   (icache_req_valid                   ),
    .icache_req_address                 (icache_req_address                 ),
    .icache_req_inst_result             (icache_req_inst_result             ),
    // Clock and Reset
    .clk		                        (control_clk                        ),
    .rst		                        (rst                                )
);

// *****************************************************************************************
// Instruction Duplicating to A Piece of ICache Decode for DCache/Memory Request Generation
// *****************************************************************************************
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: INTERNAL_INST_PKT_BUFFERS

    assign ctrl_inst_pkt1_fifo_input[i] = inst_pkt1_fifo_input[i];
    assign ctrl_inst_pkt1_fifo_wr_en[i] = inst_pkt1_fifo_wr_en[i];

    `ifdef PARALLEL_ICACHE
        pkt1_fifo_sync PARALLEL_INST_PKT1(
            .clk            (control_clk                            ),  // input wire wr_clk
            .din            (ctrl_inst_pkt1_fifo_input[i]           ),  // input wire [191 : 0] din
            .wr_en          (ctrl_inst_pkt1_fifo_wr_en[i]           ),  // input wire wr_en
            .rd_en          (ctrl_inst_pkt1_fifo_rd_en[i]           ),  // input wire rd_en
            .dout           (ctrl_inst_pkt1_fifo_output[i]          ),  // output wire [191 : 0] dout
            .full           (ctrl_inst_pkt1_fifo_full[i]            ),  // output wire full
            .empty          (ctrl_inst_pkt1_fifo_empty[i]           ),  // output wire empty
            .almost_full    (ctrl_inst_pkt1_fifo_almost_full[i]     ),  // output wire full
            .almost_empty   (ctrl_inst_pkt1_fifo_almost_empty[i]    ),  // output wire empty
            `ifdef DATA_COUNT
                .data_count     (ctrl_inst_pkt1_fifo_data_count[i]      ),  // output wire [9 : 0] data_count
            `endif
            .srst           (rst                                    )   // input wire rst
        );
    `else
        // internal inst pkt1 queues (173 bits)
        pkt1_fifo INST_PKT1(
            .wr_clk         (icache_clk                             ),  // input wire wr_clk
            .rd_clk         (control_clk                            ),  // input wire rd_clk
            .din            (ctrl_inst_pkt1_fifo_input[i]           ),  // input wire [191 : 0] din
            .wr_en          (ctrl_inst_pkt1_fifo_wr_en[i]           ),  // input wire wr_en
            .rd_en          (ctrl_inst_pkt1_fifo_rd_en[i]           ),  // input wire rd_en
            .dout           (ctrl_inst_pkt1_fifo_output[i]          ),  // output wire [191 : 0] dout
            .full           (ctrl_inst_pkt1_fifo_full[i]            ),  // output wire full
            .empty          (ctrl_inst_pkt1_fifo_empty[i]           ),  // output wire empty
            .almost_full    (ctrl_inst_pkt1_fifo_almost_full[i]     ),  // output wire full
            .almost_empty   (ctrl_inst_pkt1_fifo_almost_empty[i]    ),  // output wire empty
            `ifdef DATA_COUNT
                .wr_data_count  (ctrl_inst_pkt1_fifo_wr_data_count[i]   ),  // output wire [9 :0] wr_data_count
                .rd_data_count  (ctrl_inst_pkt1_fifo_rd_data_count[i]   ),  // output wire [9 :0] rd_data_count
            `endif
            .rst            (rst                                    )   // input wire rst
        );
    `endif

    assign ctrl_inst_pkt2_fifo_input[i] = inst_pkt2_fifo_input;
    assign ctrl_inst_pkt2_fifo_wr_en[i] = inst_pkt2_fifo_wr_en[i];
    // internal inst pkt2 queues
    pkt2_fifo INST_PKT2(
        .wr_clk         (m00_axi_aclk                           ),  // input wire wr_clk
        .rd_clk         (control_clk                            ),  // input wire rd_clk
        .din            (ctrl_inst_pkt2_fifo_input[i]           ),  // input wire [191 : 0] din
        .wr_en          (ctrl_inst_pkt2_fifo_wr_en[i]           ),  // input wire wr_en
        .rd_en          (ctrl_inst_pkt2_fifo_rd_en[i]           ),  // input wire rd_en
        .dout           (ctrl_inst_pkt2_fifo_output[i]          ),  // output wire [191 : 0] dout
        .full           (ctrl_inst_pkt2_fifo_full[i]            ),  // output wire full
        .empty          (ctrl_inst_pkt2_fifo_empty[i]           ),  // output wire empty
        .almost_full    (ctrl_inst_pkt2_fifo_almost_full[i]     ),  // output wire full
        .almost_empty   (ctrl_inst_pkt2_fifo_almost_empty[i]    ),  // output wire empty
        `ifdef DATA_COUNT
            .wr_data_count  (ctrl_inst_pkt2_fifo_wr_data_count[i]   ),  // output wire [9 :0] wr_data_count
            .rd_data_count  (ctrl_inst_pkt2_fifo_rd_data_count[i]   ),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst                                    )   // input wire rst
    );
end
endgenerate
 
sentryControl_ctrl_dcacheReq CTRL_DCACHEREQ (
    // interface to internal inst pkt forwarding
    // inst pkt1
    .ctrl_inst_pkt1_fifo_rd_en          (ctrl_inst_pkt1_fifo_rd_en          ),
    .ctrl_inst_pkt1_fifo_output         (ctrl_inst_pkt1_fifo_output         ),
    .ctrl_inst_pkt1_fifo_empty          (ctrl_inst_pkt1_fifo_empty          ),
    .ctrl_inst_pkt1_fifo_almost_empty   (ctrl_inst_pkt1_fifo_almost_empty   ),
    // inst pkt2
    .ctrl_inst_pkt2_fifo_rd_en          (ctrl_inst_pkt2_fifo_rd_en          ),
    .ctrl_inst_pkt2_fifo_output         (ctrl_inst_pkt2_fifo_output         ),
    .ctrl_inst_pkt2_fifo_empty          (ctrl_inst_pkt2_fifo_empty          ),
    .ctrl_inst_pkt2_fifo_almost_empty   (ctrl_inst_pkt2_fifo_almost_empty   ),
    // Dcache Handshake Interface
    `ifdef GEARBOX_OPT
    .dcache_req_almost_full             (dcache_req_fifo_prog_full          ), // use prog full for some cushion
    `else
    .dcache_req_almost_full             (dcache_req_fifo1_prog_full         ), // use prog full for some cushion
    `endif
    .dcache_req_valid                   (dcache_req_valid                   ),
    .dcache_req_store                   (dcache_req_store                   ),
    .dcache_req_address                 (dcache_req_address                 ),
    .dcache_inst_valid                  (dcache_inst_valid                  ),
    // Clock and Reset
    .clk		                        (control_clk                        ),
    .rst		                        (rst                                )
);

`ifndef GEARBOX_OPT
// dcache_inst_valid serves as a instruction valid signal 
// used for gearbox to keep din count
assign dcache_req_fifo1_wr_en = dcache_inst_valid != `SENTRY_WIDTH'd0;
`endif

`endif

//********************************************************
// Cache Input FIFOs
//********************************************************

`ifdef PARALLEL_ICACHE

    //******************************************
    // Parallel Version ICache Input FIFOS (4x4)
    //******************************************
    assign icache_parallel_req_fifo_input = {icache_req_address[0], icache_req_inst_result[0],
        icache_req_address[1], icache_req_inst_result[1],
        icache_req_address[2], icache_req_inst_result[2],
    icache_req_address[3], icache_req_inst_result[3]};
    // icache_req_valid is either 4'b0000 or 4'b1111
    assign icache_parallel_req_fifo_wr_en = icache_req_valid != `SENTRY_WIDTH'd0;

    cache_parallel_req_fifo ICACHE_PARALLEL_REQ_FIFO (
        .clk            (control_clk                            ),  // input wire wr_clk
        .din            (icache_parallel_req_fifo_input         ),  // input wire [511 : 0] din
        .wr_en          (icache_parallel_req_fifo_wr_en         ),  // input wire wr_en
        .rd_en          (icache_parallel_req_fifo_rd_en         ),  // input wire rd_en
        .dout           (icache_parallel_req_fifo_output        ),  // output wire [128: 0] dout
        .full           (icache_parallel_req_fifo_full          ),  // output wire full
        .empty          (icache_parallel_req_fifo_empty         ),  // output wire empty
        .almost_full    (icache_parallel_req_fifo_almost_full   ),  // output wire almost_full
        .almost_empty   (icache_parallel_req_fifo_almost_empty  ),  // output wire almost_empty
        `ifdef DATA_COUNT
            .data_count (icache_parallel_req_fifo_data_count    ),  // output wire [9 :0] wr_data_count
        `endif
        .srst            (rst                                   )   // input wire rst
    );

    assign {icache_parallel_req_address[0], icache_parallel_req_inst_result[0],
        icache_parallel_req_address[1], icache_parallel_req_inst_result[1],
        icache_parallel_req_address[2], icache_parallel_req_inst_result[2],
    icache_parallel_req_address[3], icache_parallel_req_inst_result[3]} = icache_parallel_req_fifo_output;

`else

    //*********************************************
    // Sequential Version ICache Input FIFOs (4x1)
    //*********************************************
    assign icache_req_fifo_input = {icache_req_address[0], icache_req_inst_result[0],
        icache_req_address[1], icache_req_inst_result[1],
        icache_req_address[2], icache_req_inst_result[2],
    icache_req_address[3], icache_req_inst_result[3]};
    // icache_req_valid is either 4'b0000 or 4'b1111
    assign icache_req_fifo_wr_en = icache_req_valid != `SENTRY_WIDTH'd0;

    cache_req_fifo ICACHE_REQ_FIFO (
        .wr_clk         (control_clk                    ),  // input wire wr_clk
        .rd_clk         (icache_clk                     ),  // input wire rd_clk
        .din            (icache_req_fifo_input          ),  // input wire [511 : 0] din
        .wr_en          (icache_req_fifo_wr_en          ),  // input wire wr_en
        .rd_en          (icache_req_fifo_rd_en          ),  // input wire rd_en
        .dout           (icache_req_fifo_output         ),  // output wire [128: 0] dout
        .full           (icache_req_fifo_full           ),  // output wire full
        .empty          (icache_req_fifo_empty          ),  // output wire empty
        .almost_full    (icache_req_fifo_almost_full    ),  // output wire almost_full
        .almost_empty   (icache_req_fifo_almost_empty   ),  // output wire almost_empty
        `ifdef DATA_COUNT
            .wr_data_count  (icache_req_fifo_wr_data_count  ),  // output wire [9 :0] wr_data_count
            .rd_data_count  (icache_req_fifo_rd_data_count  ),  // output wire [11:0] rd_data_count
        `endif
        .rst            (rst                            )   // input wire rst
    );

`endif

`ifdef GEARBOX_OPT
    //******************************************
    // Parallel Version DCache Input FIFOS (4x4)
    //******************************************
    // New gearbox design
    wire [  3:0] dcache_filter_gearbox_output_valid;
    wire [259:0] dcache_filter_gearbox_output_data;     // 4 * (`ADDR_WIDTH+1) bits
    wire [127:0] dcache_filter_gearbox_output_metadata; // 4 * 32 bits

    four_four_filter_gearbox #(
        .INT_WIDTH          (`ADDR_WIDTH+1                  ),
        .IDLE_FLUSH         (0                              )
    )
    DCACHE_FILTER_GEAR_BOX (
        .input_inst_valid   (dcache_inst_valid == 4'hf      ),
        .input_valid        ({dcache_req_valid[3], dcache_req_valid[2],
                              dcache_req_valid[1], dcache_req_valid[0]}),

        .input_data         ({dcache_req_store[3], dcache_req_address[3],
                              dcache_req_store[2], dcache_req_address[2],
                              dcache_req_store[1], dcache_req_address[1],
                              dcache_req_store[0], dcache_req_address[0]}),

        .output_valid       (dcache_filter_gearbox_output_valid     ),
        .output_data        (dcache_filter_gearbox_output_data      ),
        .output_metadata    (dcache_filter_gearbox_output_metadata  ),
        .clk                (control_clk                            ),
        .rst                (rst                                    )
    );

    assign dcache_req_fifo_input = {dcache_filter_gearbox_output_metadata[127:96], dcache_filter_gearbox_output_data[259:195],
        dcache_filter_gearbox_output_metadata[ 95:64], dcache_filter_gearbox_output_data[194:130],
        dcache_filter_gearbox_output_metadata[ 63:32], dcache_filter_gearbox_output_data[129: 65],
    dcache_filter_gearbox_output_metadata[ 31: 0], dcache_filter_gearbox_output_data[ 64:  0]};

    assign dcache_req_fifo_wr_en = dcache_filter_gearbox_output_valid == 4'hf;

    // 4-to-1 data cache access request fifo after 4-to-1 gear box
    dcache_req_fifo DCACHE_REQ_FIFO (
        .wr_clk         (control_clk                    ),  // input wire wr_clk
        .rd_clk         (dcache_clk                     ),  // input wire rd_clk
        .din            (dcache_req_fifo_input          ),  // input wire [68 : 0] din
        .wr_en          (dcache_req_fifo_wr_en          ),  // input wire wr_en
        .rd_en          (dcache_req_fifo_rd_en          ),  // input wire rd_en
        .dout           (dcache_req_fifo_output         ),  // output wire [68 : 0] dout
        .full           (dcache_req_fifo_full           ),  // output wire full
        .empty          (dcache_req_fifo_empty          ),  // output wire empty
        .almost_full    (dcache_req_fifo_almost_full    ),  // output wire almost full
        .almost_empty   (dcache_req_fifo_almost_empty   ),  // output wire almost empty
        .prog_full      (dcache_req_fifo_prog_full      ),
        `ifdef DATA_COUNT
            .wr_data_count  (dcache_req_fifo_wr_data_count  ),  // output wire [9 :0] wr_data_count
            .rd_data_count  (dcache_req_fifo_rd_data_count  ),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst                            )   // input wire rst
    );

`else
    //*********************************************
    // Sequential Version DCache Input FIFOs (4x1)
    //*********************************************

    // old gearbox design
    assign dcache_req_fifo1_input = {{dcache_req_valid[0], dcache_req_store[0], dcache_req_address[0]},
        {dcache_req_valid[1], dcache_req_store[1], dcache_req_address[1]},
        {dcache_req_valid[2], dcache_req_store[2], dcache_req_address[2]},
    {dcache_req_valid[3], dcache_req_store[3], dcache_req_address[3]}};

    // data cache access request fifo before 4-to-1 gear box
    cache_req_fifo1 DCACHE_REQ_FIFO1 (
        .wr_clk         (control_clk                    ),  // input wire wr_clk
        .rd_clk         (gearbox_clk                    ),  // input wire rd_clk
        .din            (dcache_req_fifo1_input         ),  // input wire [275 : 0] din
        .wr_en          (dcache_req_fifo1_wr_en         ),  // input wire wr_en
        .rd_en          (dcache_req_fifo1_rd_en         ),  // input wire rd_en
        .dout           (dcache_req_fifo1_output        ),  // output wire [275 : 0] dout
        .full           (dcache_req_fifo1_full          ),  // output wire full
        .empty          (dcache_req_fifo1_empty         ),  // output wire empty
        .almost_full    (dcache_req_fifo1_almost_full   ),  // output wire almost full
        .almost_empty   (dcache_req_fifo1_almost_empty  ),  // output wire almost empty
        `ifdef DATA_COUNT
            .wr_data_count  (dcache_req_fifo1_wr_data_count ),  // output wire [9 :0] wr_data_count
            .rd_data_count  (dcache_req_fifo1_rd_data_count ),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst                            )   // input wire rst
    );

    // data cache access request 4-to-1 gear box
    four_one_gearbox #(
        .INT_WIDTH      (`ADDR_WIDTH+2                  )
    )
    DCACHE_GEAR_BOX (
        .clk            (gearbox_clk                    ),
        .rst            (rst                            ),
        .input_empty    (dcache_req_fifo1_empty         ),  // use almost empty because rd_en is registerd on output
        .input_four     (dcache_req_fifo1_output        ),
        .input_rd_en    (dcache_req_fifo1_rd_en         ),
        .output_full    (dcache_req_fifo2_prog_full     ),
        .output_one     (dcache_req_fifo2_input         ),
        .output_wr_en   (dcache_req_fifo2_wr_en         )
    );


    // data cache access request fifo after 4-to-1 gear box
    cache_req_fifo2 DCACHE_REQ_FIFO2 (
        .wr_clk         (gearbox_clk                    ),  // input wire wr_clk
        .rd_clk         (dcache_clk                     ),  // input wire rd_clk
        .din            (dcache_req_fifo2_input         ),  // input wire [68 : 0] din
        .wr_en          (dcache_req_fifo2_wr_en         ),  // input wire wr_en
        .rd_en          (dcache_req_fifo2_rd_en         ),  // input wire rd_en
        .dout           (dcache_req_fifo2_output        ),  // output wire [68 : 0] dout
        .full           (dcache_req_fifo2_full          ),  // output wire full
        .empty          (dcache_req_fifo2_empty         ),  // output wire empty
        .almost_full    (dcache_req_fifo2_almost_full   ),  // output wire almost full
        .almost_empty   (dcache_req_fifo2_almost_empty  ),  // output wire almost empty
        .prog_full      (dcache_req_fifo2_prog_full     ),
        `ifdef DATA_COUNT
            .wr_data_count  (dcache_req_fifo2_wr_data_count ),  // output wire [9 :0] wr_data_count
            .rd_data_count  (dcache_req_fifo2_rd_data_count ),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst                            )   // input wire rst
    );

`endif

//************************
// INST CACHE
//************************
`ifdef PARALLEL_ICACHE

    //********************************
    // Parallel Version ICache
    //********************************
    sentryControl_icache_parallel ICACHE_PAR (
        // read intrerface from instruction cache access request fifo
        .icache_req_valid           (!icache_parallel_req_fifo_empty    ),
        .icache_req_rd_en           (icache_parallel_req_fifo_rd_en     ),
        .icache_req_address         (icache_parallel_req_address        ),
        .icache_req_inst_result     (icache_parallel_req_inst_result    ),
        // write interface to instruction pkt1 fifo
        .inst_pkt1_fifo_input       (inst_pkt1_fifo_input               ),
        .inst_pkt1_fifo_wr_en       (inst_pkt1_fifo_wr_en               ),
        .inst_pkt1_fifo_full        (inst_pkt1_fifo_full                ),
        .inst_pkt1_fifo_almost_full (inst_pkt1_fifo_almost_full         ),
        .inst_pkt1_fifo_prog_full   (inst_pkt1_fifo_prog_full           ),
        // write interface to instruction memory access request queue/fifo
        .mem_req_fifo_input         (imem_parallel_gearbox_input        ),
        .mem_req_fifo_wr_en         (imem_parallel_gearbox_wr_en        ),
        .mem_req_fifo_full          (imem_filter_req_fifo_full          ),
        .mem_req_fifo_almost_full   (imem_filter_req_fifo_almost_full   ),
        .mem_req_fifo_prog_full     (imem_filter_req_fifo_prog_full || imem_parallel_gearbox_prog_full ),
        `ifdef SMAC
            // write interface to instruction smac access request queue/fifo
            .smac_req_fifo_input        (),
            .smac_req_fifo_wr_en        (),
            .smac_req_fifo_full         (),
            .smac_req_fifo_almost_full  (),
            .smac_req_fifo_prog_full    (0),
        `endif
        // Clock and Reset
        .clk		                (control_clk                    ),
        .rst		                (rst                            )
    );

    // new gearbox design
    wire [  3:0] imem_filter_gearbox_output_valid;
    wire [383:0] imem_filter_gearbox_output_data;     // 4 * (`ADDR_WIDTH+1) bits
    wire [127:0] imem_filter_gearbox_output_metadata; // 4 * 32 bits

    four_four_filter_gearbox #(
        .INT_WIDTH          (96                             ),
        .IDLE_FLUSH         (1                              )
    )
    IMEM_FILTER_GEAR_BOX (
        .input_inst_valid   (0                                      ),
        .input_valid        (imem_parallel_gearbox_wr_en            ),
        .input_data         ({imem_parallel_gearbox_input[3],
                              imem_parallel_gearbox_input[2],
                              imem_parallel_gearbox_input[1],
                              imem_parallel_gearbox_input[0]}       ),
        .output_full        (imem_parallel_gearbox_full             ),
        .output_prog_full   (imem_parallel_gearbox_prog_full        ),
        .output_valid       (imem_filter_gearbox_output_valid       ),
        .output_data        (imem_filter_gearbox_output_data        ),
        .output_metadata    (imem_filter_gearbox_output_metadata    ),
        .clk                (control_clk                            ),
        .rst                (rst                                    )
    );

    assign imem_filter_req_fifo_input = {imem_filter_gearbox_output_valid[0], imem_filter_gearbox_output_data[383:288],
        imem_filter_gearbox_output_valid[1], imem_filter_gearbox_output_data[287:192],
        imem_filter_gearbox_output_valid[2], imem_filter_gearbox_output_data[191: 96],
        imem_filter_gearbox_output_valid[3], imem_filter_gearbox_output_data[ 95:  0]};

    assign imem_filter_req_fifo_wr_en = imem_filter_gearbox_output_valid != 4'h0;

    // 4:1 inst mem access request fifo after 4-to-4 filter gear box
    imem_parallel_req_fifo IMEM_PARALLEL_REQ_FIFO (
        .wr_clk         (control_clk                        ),  // input wire wr_clk
        .rd_clk         (m00_axi_aclk                       ),  // input wire rd_clk
        .din            (imem_filter_req_fifo_input         ),  // input wire [68 : 0] din
        .wr_en          (imem_filter_req_fifo_wr_en         ),  // input wire wr_en
        .rd_en          (imem_filter_req_fifo_rd_en         ),  // input wire rd_en
        .dout           (imem_filter_req_fifo_output        ),  // output wire [68 : 0] dout
        .full           (imem_filter_req_fifo_full          ),  // output wire full
        .empty          (imem_filter_req_fifo_empty         ),  // output wire empty
        .almost_full    (imem_filter_req_fifo_almost_full   ),  // output wire almost full
        .almost_empty   (imem_filter_req_fifo_almost_empty  ),  // output wire almost empty
        .prog_full      (imem_filter_req_fifo_prog_full     ),
        `ifdef DATA_COUNT
            .wr_data_count  (imem_filter_req_fifo_wr_data_count ),  // output wire [9 :0] wr_data_count
            .rd_data_count  (imem_filter_req_fifo_rd_data_count ),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst || !m00_axi_aresetn            )   // input wire rst
    );

    `ifdef SMAC
        ismac_parallel_req_fifo ISMAC_PARALLEL_REQ_FIFO (
            .wr_clk         (control_clk                        ),  // input wire wr_clk
            .rd_clk         (m02_axi_clk                        ),  // input wire rd_clk
            .din            (ismac_filter_req_fifo_input        ),  // input wire [68 : 0] din
            .wr_en          (ismac_filter_req_fifo_wr_en        ),  // input wire wr_en
            .rd_en          (ismac_filter_req_fifo_rd_en        ),  // input wire rd_en
            .dout           (ismac_filter_req_fifo_output       ),  // output wire [68 : 0] dout
            .full           (ismac_filter_req_fifo_full         ),  // output wire full
            .empty          (ismac_filter_req_fifo_empty        ),  // output wire empty
            .almost_full    (ismac_filter_req_fifo_almost_full  ),  // output wire almost full
            .almost_empty   (ismac_filter_req_fifo_almost_empty ),  // output wire almost empty
            .prog_full      (ismac_filter_req_fifo_prog_full    ),
            `ifdef DATA_COUNT
                .wr_data_count  (ismac_filter_req_fifo_wr_data_count),  // output wire [9 :0] wr_data_count
                .rd_data_count  (ismac_filter_req_fifo_rd_data_count),  // output wire [9 :0] rd_data_count
            `endif
            .rst            (rst || !m02_axi_aresetn            )   // input wire rst
        );
    `endif

`else

    //********************************
    // Sequential Version ICache
    //********************************
    pkt1_t inst_pkt1_fifo_input_orig;

    sentryControl_icache ICACHE (
        // read intrerface from instruction cache access request fifo
        .icache_req_valid           (!icache_req_fifo_empty         ),
        .icache_req_rd_en           (icache_req_fifo_rd_en          ),
        .icache_req_address         (icache_req_fifo_output.addr    ),
        .icache_req_inst_result     (icache_req_fifo_output.result  ),
        // write interface to instruction pkt1 fifo
        .inst_pkt1_fifo_input       (inst_pkt1_fifo_input_orig      ),
        .inst_pkt1_fifo_wr_en       (inst_pkt1_fifo_wr_en           ),
        .inst_pkt1_fifo_full        (inst_pkt1_fifo_full            ),
        .inst_pkt1_fifo_almost_full (inst_pkt1_fifo_almost_full     ),
        .inst_pkt1_fifo_prog_full   (inst_pkt1_fifo_prog_full       ),
        `ifdef SMAC
            // write interface to instruction smac access request queue/fifo
            .smac_req_fifo_input        (ismac_req_fifo_input           ),
            .smac_req_fifo_wr_en        (ismac_req_fifo_wr_en           ),
            .smac_req_fifo_full         (ismac_req_fifo_full            ),
            .smac_req_fifo_almost_full  (ismac_req_fifo_almost_full     ),
            .smac_req_fifo_prog_full    (ismac_req_fifo_prog_full       ),
        `endif
        // write interface to instruction memory access request queue/fifo
        .mem_req_fifo_input         (imem_req_fifo_input            ),
        .mem_req_fifo_wr_en         (imem_req_fifo_wr_en            ),
        .mem_req_fifo_full          (imem_req_fifo_full             ),
        .mem_req_fifo_almost_full   (imem_req_fifo_almost_full      ),
        .mem_req_fifo_prog_full     (imem_req_fifo_prog_full        ),
        // Clock and Reset
        .clk		                (icache_clk                     ),
        .rst		                (rst                            )
    );

    generate
    for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: INST_PKT1_BUFFERS
        assign inst_pkt1_fifo_input[i] = inst_pkt1_fifo_input_orig;
    end
    endgenerate

    // instruction memory access request fifo
    mem_req_fifo IMEM_REQ_FIFO (
        .wr_clk         (icache_clk                     ),  // input wire wr_clk
        .rd_clk         (m00_axi_aclk                   ),  // input wire rd_clk
        .din            (imem_req_fifo_input            ),  // input wire [95 : 0] din
        .wr_en          (imem_req_fifo_wr_en            ),  // input wire wr_en
        .rd_en          (imem_req_fifo_rd_en            ),  // input wire rd_en
        .dout           (imem_req_fifo_output           ),  // output wire [95 : 0] dout
        .full           (imem_req_fifo_full             ),  // output wire full
        .empty          (imem_req_fifo_empty            ),  // output wire empty
        .almost_full    (imem_req_fifo_almost_full      ),  // output wire almost full
        .almost_empty   (imem_req_fifo_almost_empty     ),  // output wire almost empty
        .prog_full      (imem_req_fifo_prog_full        ),  // output wire almost empty
        `ifdef DATA_COUNT
            .wr_data_count  (imem_req_fifo_wr_data_count    ),  // output wire [9 :0] wr_data_count
            .rd_data_count  (imem_req_fifo_rd_data_count    ),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst || !m00_axi_aresetn        )   // input wire rst
    );

    `ifdef SMAC
        // instruction smac access request fifo
        mem_req_fifo ISMAC_REQ_FIFO (
            .wr_clk         (cache_clk                      ),  // input wire wr_clk
            .rd_clk         (m02_axi_aclk                   ),  // input wire rd_clk
            .din            (ismac_req_fifo_input           ),  // input wire [95 : 0] din
            .wr_en          (ismac_req_fifo_wr_en           ),  // input wire wr_en
            .rd_en          (ismac_req_fifo_rd_en           ),  // input wire rd_en
            .dout           (ismac_req_fifo_output          ),  // output wire [95 : 0] dout
            .full           (ismac_req_fifo_full            ),  // output wire full
            .empty          (ismac_req_fifo_empty           ),  // output wire empty
            .almost_full    (ismac_req_fifo_almost_full     ),  // output wire almost full
            .almost_empty   (ismac_req_fifo_almost_empty    ),  // output wire almost empty
            .prog_full      (ismac_req_fifo_prog_full       ),  // output wire almost empty
            `ifdef DATA_COUNT
                .wr_data_count  (ismac_req_fifo_wr_data_count   ),  // output wire [9 :0] wr_data_count
                .rd_data_count  (ismac_req_fifo_rd_data_count   ),  // output wire [9 :0] rd_data_count
            `endif
            .rst            (rst || !m02_axi_aresetn        )   // input wire rst
        );
    `endif

`endif

// instruction memory access manager
sentryControl_icache_mem_manager #(
    .MEM_BASE_ADDR              (MEM_BASE_ADDR              )
) ICACHE_MEM_MANAGER (
    // AXI4 Master Interface                    
    .m_axi_aclk                 (m00_axi_aclk               ),  // global clock
    .m_axi_aresetn              (m00_axi_aresetn            ),  // global reset, active low
    // write interface
    // write address
    .m_axi_awid		            (m00_axi_awid		        ),  // write address id, 1'b0
    .m_axi_awaddr		        (m00_axi_awaddr		        ),  // write address
    .m_axi_awlen		        (m00_axi_awlen		        ),  // number of write transfers in a burst
    .m_axi_awsize		        (m00_axi_awsize		        ),  // size of each write transfer in a burst
    .m_axi_awburst		        (m00_axi_awburst		    ),  // write burst type, 2'b01
    .m_axi_awlock		        (m00_axi_awlock		        ),  // 1'b0, not used
    .m_axi_awcache		        (m00_axi_awcache		    ),  // memory type, 4'b0010
    .m_axi_awprot		        (m00_axi_awprot		        ),  // protection type, 3'h0
    .m_axi_awqos		        (m00_axi_awqos		        ),  // quality of service identifier, 4'h0
    //.m_axi_awuser		        (m00_axi_awuser		        ),  // option user defined channel, 1'b1
    .m_axi_awvalid		        (m00_axi_awvalid		    ),  // write address valid
    .m_axi_awready		        (m00_axi_awready		    ),  // write address ready
    // write data
    .m_axi_wdata		        (m00_axi_wdata		        ),  // write data
    .m_axi_wstrb		        (m00_axi_wstrb		        ),  // write strobes (byte write enable)
    .m_axi_wlast		        (m00_axi_wlast		        ),  // indicates last transfer in a burst
    //.m_axi_wuser		        (m00_axi_wuser		        ),  // option user defined channel, 1'b0
    .m_axi_wvalid		        (m00_axi_wvalid		        ),  // write data valid
    .m_axi_wready		        (m00_axi_wready		        ),  // write data ready
    // write response
    .m_axi_bid		            (m00_axi_bid		        ),  // master inteface write response
    .m_axi_bresp		        (m00_axi_bresp		        ),  // write response for write transaction
    //.m_axi_buser		        (m00_axi_buser		        ),  // option user defined channel
    .m_axi_bvalid		        (m00_axi_bvalid		        ),  // write response valid
    .m_axi_bready		        (m00_axi_bready		        ),  // write response ready, master can accept another transaction
    // read interface
    // read address
    .m_axi_arid		            (m00_axi_arid		        ),  // read address id, 1'b0
    .m_axi_araddr		        (m00_axi_araddr		        ),  // read address
    .m_axi_arlen		        (m00_axi_arlen		        ),  // number of read transfers in a burst
    .m_axi_arsize		        (m00_axi_arsize		        ),  // size of each read transfer in a burst
    .m_axi_arburst		        (m00_axi_arburst		    ),  // read burst type, 2'b01
    .m_axi_arlock		        (m00_axi_arlock		        ),  // 1'b0, not used
    .m_axi_arcache		        (m00_axi_arcache		    ),  // memory type, 4'b0010
    .m_axi_arprot		        (m00_axi_arprot		        ),  // protection type, 3'h0
    .m_axi_arqos		        (m00_axi_arqos		        ),  // quality of service identifier, 4'h0
    //.m_axi_aruser		        (m00_axi_aruser		        ),  // option user defined channel, 1'b1
    .m_axi_arvalid		        (m00_axi_arvalid		    ),  // read address valid
    .m_axi_arready		        (m00_axi_arready		    ),  // read address ready
    // read data
    .m_axi_rid		            (m00_axi_rid		        ),  // master inteface write response
    .m_axi_rdata		        (m00_axi_rdata		        ),  // read data
    .m_axi_rresp		        (m00_axi_rresp		        ),  // read response for read transaction
    .m_axi_rlast		        (m00_axi_rlast		        ),  // indicates last transfer in a burst
    //.m_axi_ruser		        (m00_axi_ruser		        ),  // option user defined channel
    .m_axi_rvalid		        (m00_axi_rvalid		        ),  // read data valid
    .m_axi_rready		        (m00_axi_rready		        ),  // read data ready, master can accept read data
    // read interface from instruction memory access request fifo
    `ifdef PARALLEL_ICACHE
        .mem_req_fifo_rd_en         (imem_filter_req_fifo_rd_en         ),
        .mem_req_fifo_valid         (imem_filter_req_fifo_output[96]    ),
        .mem_req_fifo_output        (imem_filter_req_fifo_output[95:0]  ),
        .mem_req_fifo_empty         (imem_filter_req_fifo_empty         ),
        .mem_req_fifo_almost_empty  (imem_filter_req_fifo_almost_empty  ),
    `else
        .mem_req_fifo_rd_en         (imem_req_fifo_rd_en                ),
        .mem_req_fifo_output        (imem_req_fifo_output               ),
        .mem_req_fifo_empty         (imem_req_fifo_empty                ),
        .mem_req_fifo_almost_empty  (imem_req_fifo_almost_empty         ),
    `endif
    // write interface to instruction pkt2 fifo 
    .inst_pkt2_fifo_input       (inst_pkt2_fifo_input       ),
    .inst_pkt2_fifo_wr_en       (inst_pkt2_fifo_wr_en       ),
    .inst_pkt2_fifo_full        (inst_pkt2_fifo_full        ),
    .inst_pkt2_fifo_almost_full (inst_pkt2_fifo_almost_full )
);

`ifdef SMAC
    // instruction smac access manager
    sentryControl_icache_smac_manager ICACHE_SMAC_MANAGER (
        // AXI4 Master Interface                    
        .m_axi_aclk		            (m02_axi_aclk               ),  // global clock
        .m_axi_aresetn		        (m02_axi_aresetn            ),  // global reset, active low
        // write interface
        // write address
        .m_axi_awid		            (m02_axi_awid		        ),  // write address id, 1'b0
        .m_axi_awaddr		        (m02_axi_awaddr		        ),  // write address
        .m_axi_awlen		        (m02_axi_awlen		        ),  // number of write transfers in a burst
        .m_axi_awsize		        (m02_axi_awsize		        ),  // size of each write transfer in a burst
        .m_axi_awburst		        (m02_axi_awburst		    ),  // write burst type, 2'b01
        .m_axi_awlock		        (m02_axi_awlock		        ),  // 1'b0, not used
        .m_axi_awcache		        (m02_axi_awcache		    ),  // memory type, 4'b0010
        .m_axi_awprot		        (m02_axi_awprot		        ),  // protection type, 3'h0
        .m_axi_awqos		        (m02_axi_awqos		        ),  // quality of service identifier, 4'h0
        //.m_axi_awuser		        (m02_axi_awuser		        ),  // option user defined channel, 1'b1
        .m_axi_awvalid		        (m02_axi_awvalid		    ),  // write address valid
        .m_axi_awready		        (m02_axi_awready		    ),  // write address ready
        // write data
        .m_axi_wdata		        (m02_axi_wdata		        ),  // write data
        .m_axi_wstrb		        (m02_axi_wstrb		        ),  // write strobes (byte write enable)
        .m_axi_wlast		        (m02_axi_wlast		        ),  // indicates last transfer in a burst
        //.m_axi_wuser		        (m02_axi_wuser		        ),  // option user defined channel, 1'b0
        .m_axi_wvalid		        (m02_axi_wvalid		        ),  // write data valid
        .m_axi_wready		        (m02_axi_wready		        ),  // write data ready
        // write response
        .m_axi_bid		            (m02_axi_bid		        ),  // master inteface write response
        .m_axi_bresp		        (m02_axi_bresp		        ),  // write response for write transaction
        //.m_axi_buser		        (m02_axi_buser		        ),  // option user defined channel
        .m_axi_bvalid		        (m02_axi_bvalid		        ),  // write response valid
        .m_axi_bready		        (m02_axi_bready		        ),  // write response ready, master can accept another transaction
        // read interface
        // read address
        .m_axi_arid		            (m02_axi_arid		        ),  // read address id, 1'b0
        .m_axi_araddr		        (m02_axi_araddr		        ),  // read address
        .m_axi_arlen		        (m02_axi_arlen		        ),  // number of read transfers in a burst
        .m_axi_arsize		        (m02_axi_arsize		        ),  // size of each read transfer in a burst
        .m_axi_arburst		        (m02_axi_arburst		    ),  // read burst type, 2'b01
        .m_axi_arlock		        (m02_axi_arlock		        ),  // 1'b0, not used
        .m_axi_arcache		        (m02_axi_arcache		    ),  // memory type, 4'b0010
        .m_axi_arprot		        (m02_axi_arprot		        ),  // protection type, 3'h0
        .m_axi_arqos		        (m02_axi_arqos		        ),  // quality of service identifier, 4'h0
        //.m_axi_aruser		        (m02_axi_aruser		        ),  // option user defined channel, 1'b1
        .m_axi_arvalid		        (m02_axi_arvalid		    ),  // read address valid
        .m_axi_arready		        (m02_axi_arready		    ),  // read address ready
        // read data
        .m_axi_rid		            (m02_axi_rid		        ),  // master inteface write response
        .m_axi_rdata		        (m02_axi_rdata		        ),  // read data
        .m_axi_rresp		        (m02_axi_rresp		        ),  // read response for read transaction
        .m_axi_rlast		        (m02_axi_rlast		        ),  // indicates last transfer in a burst
        //.m_axi_ruser		        (m02_axi_ruser		        ),  // option user defined channel
        .m_axi_rvalid		        (m02_axi_rvalid		        ),  // read data valid
        .m_axi_rready		        (m02_axi_rready		        ),  // read data ready, master can accept read data
        // read interface from instruction memory access request fifo
        .smac_req_fifo_output       (ismac_req_fifo_output      ),
        .smac_req_fifo_empty        (ismac_req_fifo_empty       ),
        .smac_req_fifo_rd_en        (ismac_req_fifo_rd_en       ),
        // write interface to instruction pkt3 fifo
        .inst_pkt3_fifo_input       (inst_pkt3_fifo_input       ),
        .inst_pkt3_fifo_wr_en       (inst_pkt3_fifo_wr_en       ),
        .inst_pkt3_fifo_full        (inst_pkt3_fifo_full        ),
        .inst_pkt3_fifo_almost_full (inst_pkt3_fifo_almost_full )
    );
`endif


`ifdef GEARBOX_OPT
assign dcache_req_fifo_number    = dcache_req_fifo_output[`ADDR_WIDTH+5+:28];
assign dcache_req_fifo_rotate    = dcache_req_fifo_output[`ADDR_WIDTH+1+:4];
assign dcache_req_fifo_store     = dcache_req_fifo_output[`ADDR_WIDTH];
assign dcache_req_fifo_address   = dcache_req_fifo_output[`ADDR_WIDTH-1:0];
`else
assign dcache_req_fifo_number    = dcache_req_fifo2_output[`ADDR_WIDTH+5+:28];
assign dcache_req_fifo_rotate    = dcache_req_fifo2_output[`ADDR_WIDTH+1+:4];
assign dcache_req_fifo_store     = dcache_req_fifo2_output[`ADDR_WIDTH];
assign dcache_req_fifo_address   = dcache_req_fifo2_output[`ADDR_WIDTH-1:0];
`endif

//************************
// DATA CACHE
//************************
sentryControl_dcache DCACHE (
    // read intrerface from data cache access request fifo 
    //.dcache_req_valid               (!dcache_req_fifo2_empty                    ),
    `ifdef GEARBOX_OPT
    .dcache_req_valid               (!dcache_req_fifo_empty                     ),
    `else
    .dcache_req_valid               (!dcache_req_fifo2_empty                    ),
    `endif
    .dcache_req_number              (dcache_req_fifo_number                     ),
    .dcache_req_rotate              (dcache_req_fifo_rotate                     ),
    .dcache_req_store               (dcache_req_fifo_store                      ),
    .dcache_req_address             (dcache_req_fifo_address                    ),
    `ifdef GEARBOX_OPT
        .dcache_req_rd_en               (dcache_req_fifo_rd_en                      ),
    `else
        .dcache_req_rd_en               (dcache_req_fifo2_rd_en                     ),
    `endif
    // write interface to data pkt1 fifo
    .data_pkt1_fifo_input           (data_pkt1_fifo_input                       ),
    .data_pkt1_fifo_wr_en           (data_pkt1_fifo_wr_en                       ),
    .data_pkt1_fifo_full            (data_pkt1_fifo_full                        ),
    .data_pkt1_fifo_almost_full     (data_pkt1_fifo_almost_full                 ),
    .data_pkt1_fifo_prog_full       (data_pkt1_fifo_prog_full                   ),
    `ifdef SMAC
        // write interface to instruction smac access request queue/fifo
        .smac_req_fifo_input            (dsmac_req_fifo_input                       ),
        .smac_req_fifo_wr_en            (dsmac_req_fifo_wr_en                       ),
        .smac_req_fifo_full             (dsmac_req_fifo_full                        ),
        .smac_req_fifo_almost_full      (dsmac_req_fifo_almost_full                 ),
        .smac_req_fifo_prog_full        (dsmac_req_fifo_prog_full                   ),
    `endif
    // write interface to data victim cam lookup request queue/fifo
    .cam_req_fifo_input             (dcam_req_fifo_input                        ),
    .cam_req_fifo_wr_en             (dcam_req_fifo_wr_en                        ),
    .cam_req_fifo_full              (dcam_req_fifo_full                         ),
    .cam_req_fifo_almost_full       (dcam_req_fifo_almost_full                  ),
    .cam_req_fifo_prog_full         (dcam_req_fifo_prog_full                    ),
    // victim cam insert interface
    .cam_insert_fifo_input          (cam_insert_fifo_input                      ),
    .cam_insert_fifo_wr_en          (cam_insert_fifo_wr_en                      ),
    .cam_insert_fifo_full           (cam_insert_fifo_full                       ),
    .cam_insert_fifo_almost_full    (cam_insert_fifo_almost_full                ),
    .cam_insert_fifo_prog_full      (cam_insert_fifo_prog_full                  ),
    // write interface to victim addr buffer
    .victim_addr_fifo_input         (victim_addr_fifo_input                     ),
    .victim_addr_fifo_wr_en         (victim_addr_fifo_wr_en                     ),
    .victim_addr_fifo_full          (victim_addr_fifo_full                      ),
    .victim_addr_fifo_almost_full   (victim_addr_fifo_almost_full               ),
    .victim_addr_fifo_prog_full     (victim_addr_fifo_prog_full                 ),
    // Clock and Reset
    .clk		                    (dcache_clk                                 ),
    .rst		                    (rst                                        )
);

// Victim Address Fifo
victim_addr_fifo VICTIM_ADDR_FIFO (
    .wr_clk         (dcache_clk                     ),  // input wire wr_clk
    .rd_clk         (m01_axi_aclk                   ),  // input wire rd_clk
    .din            (victim_addr_fifo_input         ),  // input wire [95 : 0] din
    .wr_en          (victim_addr_fifo_wr_en         ),  // input wire wr_en
    .rd_en          (victim_addr_fifo_rd_en         ),  // input wire rd_en
    .dout           (victim_addr_fifo_output        ),  // output wire [95 : 0] dout
    .full           (victim_addr_fifo_full          ),  // output wire full
    .empty          (victim_addr_fifo_empty         ),  // output wire empty
    .almost_full    (victim_addr_fifo_almost_full   ),  // output wire almost full
    .almost_empty   (victim_addr_fifo_almost_empty  ),  // output wire almost empty
    .prog_full      (victim_addr_fifo_prog_full     ),  // output wire almost empty
    `ifdef DATA_COUNT
        .wr_data_count  (victim_addr_fifo_wr_data_count ),  // output wire [9 :0] wr_data_count
        .rd_data_count  (victim_addr_fifo_rd_data_count ),  // output wire [9 :0] rd_data_count
    `endif
    .rst            (rst || !m01_axi_aresetn        )   // input wire rst
);

//Data Memory Access Request Fifo
mem_req_fifo DCAM_REQ_FIFO (
    .wr_clk         (dcache_clk                     ),  // input wire wr_clk
    .rd_clk         (cam_clk                        ),  // input wire rd_clk
    .din            (dcam_req_fifo_input            ),  // input wire [95 : 0] din
    .wr_en          (dcam_req_fifo_wr_en            ),  // input wire wr_en
    .rd_en          (dcam_req_fifo_rd_en            ),  // input wire rd_en
    .dout           (dcam_req_fifo_output           ),  // output wire [95 : 0] dout
    .full           (dcam_req_fifo_full             ),  // output wire full
    .empty          (dcam_req_fifo_empty            ),  // output wire empty
    .almost_full    (dcam_req_fifo_almost_full      ),  // output wire almost full
    .almost_empty   (dcam_req_fifo_almost_empty     ),  // output wire almost empty
    .prog_full      (dcam_req_fifo_prog_full        ),  // output wire prog full
    `ifdef DATA_COUNT
        .wr_data_count  (dcam_req_fifo_wr_data_count    ),  // output wire [9 :0] wr_data_count
        .rd_data_count  (dcam_req_fifo_rd_data_count    ),  // output wire [9 :0] rd_data_count
    `endif
    .rst            (rst                            )   // input wire rst
);

// Data Victim Cam Insert Fifo
mem_req_fifo DCAM_INSERT_FIFO (
    .wr_clk         (dcache_clk                     ),  // input wire wr_clk
    .rd_clk         (cam_clk                        ),  // input wire rd_clk
    .din            (cam_insert_fifo_input          ),  // input wire [95 : 0] din
    .wr_en          (cam_insert_fifo_wr_en          ),  // input wire wr_en
    .rd_en          (cam_insert_fifo_rd_en          ),  // input wire rd_en
    .dout           (cam_insert_fifo_output         ),  // output wire [95 : 0] dout
    .full           (cam_insert_fifo_full           ),  // output wire full
    .empty          (cam_insert_fifo_empty          ),  // output wire empty
    .almost_full    (cam_insert_fifo_almost_full    ),  // output wire almost full
    .almost_empty   (cam_insert_fifo_almost_empty   ),  // output wire almost empty
    .prog_full      (cam_insert_fifo_prog_full      ),  // output wire prog full
    `ifdef DATA_COUNT
        .wr_data_count  (cam_insert_fifo_wr_data_count  ),  // output wire [9 :0] wr_data_count
        .rd_data_count  (cam_insert_fifo_rd_data_count  ),  // output wire [9 :0] rd_data_count
    `endif
    .rst            (rst                            )   // input wire rst
);

// Data Victim Cam Clear Fifo
cam_addr_fifo DCAM_CLEAR_FIFO (
    .wr_clk         (m01_axi_aclk                   ),  // input wire wr_clk
    .rd_clk         (cam_clk                        ),  // input wire rd_clk
    .din            (cam_clear_fifo_input           ),  // input wire [95 : 0] din
    .wr_en          (cam_clear_fifo_wr_en           ),  // input wire wr_en
    .rd_en          (cam_clear_fifo_rd_en           ),  // input wire rd_en
    .dout           (cam_clear_fifo_output          ),  // output wire [95 : 0] dout
    .full           (cam_clear_fifo_full            ),  // output wire full
    .empty          (cam_clear_fifo_empty           ),  // output wire empty
    .almost_full    (cam_clear_fifo_almost_full     ),  // output wire almost full
    .almost_empty   (cam_clear_fifo_almost_empty    ),  // output wire almost empty
    `ifdef DATA_COUNT
        .wr_data_count  (cam_clear_fifo_wr_data_count   ),  // output wire [9 :0] wr_data_count
        .rd_data_count  (cam_clear_fifo_rd_data_count   ),  // output wire [9 :0] rd_data_count
    `endif
    .rst            (rst || !m01_axi_aresetn        )   // input wire rst
);

// Victim Content Addressable Memory
sentryControl_victim_cam #(
    .ADDR_WIDTH                     (`CAM_ADDR_WIDTH                )
)
VICTIM_CAM (
    // data victim cam insert interface
    .cam_insert_fifo_output         (cam_insert_fifo_output         ),
    .cam_insert_fifo_rd_en          (cam_insert_fifo_rd_en          ),
    .cam_insert_fifo_almost_empty   (cam_insert_fifo_almost_empty   ),
    .cam_insert_fifo_empty          (cam_insert_fifo_empty          ),
    // data victim cam clear interface
    .cam_clear_fifo_output          (cam_clear_fifo_output          ),
    .cam_clear_fifo_rd_en           (cam_clear_fifo_rd_en           ),
    .cam_clear_fifo_almost_empty    (cam_clear_fifo_almost_empty    ),
    .cam_clear_fifo_empty           (cam_clear_fifo_empty           ),
    // read interface from data victim cam lookup request queue/fifo
    .cam_req_fifo_output            (dcam_req_fifo_output           ),
    .cam_req_fifo_rd_en             (dcam_req_fifo_rd_en            ),
    .cam_req_fifo_almost_empty      (dcam_req_fifo_almost_empty     ),
    .cam_req_fifo_empty             (dcam_req_fifo_empty            ),
    // write interface to victim pkt fifo 
    .data_vpkt_fifo_input           (data_vpkt_fifo_input           ),
    .data_vpkt_fifo_wr_en           (data_vpkt_fifo_wr_en           ),
    .data_vpkt_fifo_full            (data_vpkt_fifo_full            ),
    .data_vpkt_fifo_almost_full     (data_vpkt_fifo_almost_full     ),
    // write interface to data memory access request queue/fifo
    .mem_req_fifo_input             (dmem_req_fifo_input            ),
    .mem_req_fifo_wr_en             (dmem_req_fifo_wr_en            ),
    .mem_req_fifo_full              (dmem_req_fifo_full             ),
    .mem_req_fifo_almost_full       (dmem_req_fifo_almost_full      ),
    // Clock and Reset
    .clk		                    (cam_clk                        ),
    .rst		                    (rst                            )
);

//data memory access request fifo
mem_req_fifo DMEM_REQ_FIFO (
    .wr_clk         (cam_clk                        ),  // input wire wr_clk
    .rd_clk         (m01_axi_aclk                   ),  // input wire rd_clk
    .din            (dmem_req_fifo_input            ),  // input wire [95 : 0] din
    .wr_en          (dmem_req_fifo_wr_en            ),  // input wire wr_en
    .rd_en          (dmem_req_fifo_rd_en            ),  // input wire rd_en
    .dout           (dmem_req_fifo_output           ),  // output wire [95 : 0] dout
    .full           (dmem_req_fifo_full             ),  // output wire full
    .empty          (dmem_req_fifo_empty            ),  // output wire empty
    .almost_full    (dmem_req_fifo_almost_full      ),  // output wire almost full
    .almost_empty   (dmem_req_fifo_almost_empty     ),  // output wire almost empty
    .prog_full      (dmem_req_fifo_prog_full        ),  // output wire prog empty
    `ifdef DATA_COUNT
        .wr_data_count  (dmem_req_fifo_wr_data_count    ),  // output wire [9 :0] wr_data_count
        .rd_data_count  (dmem_req_fifo_rd_data_count    ),  // output wire [9 :0] rd_data_count
    `endif
    .rst            (rst || !m01_axi_aresetn        )   // input wire rst
);

`ifdef SMAC
    //data smac access request fifo
    mem_req_fifo DSMAC_REQ_FIFO (
        .wr_clk         (dcache_clk                      ),  // input wire wr_clk
        .rd_clk         (m03_axi_aclk                   ),  // input wire rd_clk
        .din            (dsmac_req_fifo_input           ),  // input wire [95 : 0] din
        .wr_en          (dsmac_req_fifo_wr_en           ),  // input wire wr_en
        .rd_en          (dsmac_req_fifo_rd_en           ),  // input wire rd_en
        .dout           (dsmac_req_fifo_output          ),  // output wire [95 : 0] dout
        .full           (dsmac_req_fifo_full            ),  // output wire full
        .empty          (dsmac_req_fifo_empty           ),  // output wire empty
        .almost_full    (dsmac_req_fifo_almost_full     ),  // output wire almost full
        .almost_empty   (dsmac_req_fifo_almost_empty    ),  // output wire almost empty
        .prog_full      (dmem_req_fifo_prog_full        ),  // output wire prog empty
        `ifdef DATA_COUNT
            .wr_data_count  (dsmac_req_fifo_wr_data_count    ),  // output wire [9 :0] wr_data_count
            .rd_data_count  (dsmac_req_fifo_rd_data_count    ),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst || !m03_axi_aresetn        )   // input wire rst
    );
`endif

// instruction memory access manager
sentryControl_dcache_mem_manager #(
    .MEM_BASE_ADDR              (MEM_BASE_ADDR              )
)
DCACHE_MEM_MANAGER (
    // AXI4 Master Interface                    
    .m_axi_aclk		            (m01_axi_aclk               ),  // global clock
    .m_axi_aresetn		        (m01_axi_aresetn            ),  // global reset, active low
    // write interface
    // write address
    .m_axi_awid		            (m01_axi_awid		        ),  // write address id, 1'b0
    .m_axi_awaddr		        (m01_axi_awaddr		        ),  // write address
    .m_axi_awlen		        (m01_axi_awlen		        ),  // number of write transfers in a burst
    .m_axi_awsize		        (m01_axi_awsize		        ),  // size of each write transfer in a burst
    .m_axi_awburst		        (m01_axi_awburst		    ),  // write burst type, 2'b01
    .m_axi_awlock		        (m01_axi_awlock		        ),  // 1'b0, not used
    .m_axi_awcache		        (m01_axi_awcache		    ),  // memory type, 4'b0010
    .m_axi_awprot		        (m01_axi_awprot		        ),  // protection type, 3'h0
    .m_axi_awqos		        (m01_axi_awqos		        ),  // quality of service identifier, 4'h0
    //.m_axi_awuser		        (m01_axi_awuser		        ),  // option user defined channel, 1'b1
    .m_axi_awvalid		        (m01_axi_awvalid		    ),  // write address valid
    .m_axi_awready		        (m01_axi_awready		    ),  // write address ready
    // write data
    .m_axi_wdata		        (m01_axi_wdata		        ),  // write data
    .m_axi_wstrb		        (m01_axi_wstrb		        ),  // write strobes (byte write enable)
    .m_axi_wlast		        (m01_axi_wlast		        ),  // indicates last transfer in a burst
    //.m_axi_wuser		        (m01_axi_wuser		        ),  // option user defined channel, 1'b0
    .m_axi_wvalid		        (m01_axi_wvalid		        ),  // write data valid
    .m_axi_wready		        (m01_axi_wready		        ),  // write data ready
    // write response
    .m_axi_bid		            (m01_axi_bid		        ),  // master inteface write response
    .m_axi_bresp		        (m01_axi_bresp		        ),  // write response for write transaction
    //.m_axi_buser		        (m01_axi_buser		        ),  // option user defined channel
    .m_axi_bvalid		        (m01_axi_bvalid		        ),  // write response valid
    .m_axi_bready		        (m01_axi_bready		        ),  // write response ready, master can accept another transaction
    // read interface
    // read address
    .m_axi_arid		            (m01_axi_arid		        ),  // read address id, 1'b0
    .m_axi_araddr		        (m01_axi_araddr		        ),  // read address
    .m_axi_arlen		        (m01_axi_arlen		        ),  // number of read transfers in a burst
    .m_axi_arsize		        (m01_axi_arsize		        ),  // size of each read transfer in a burst
    .m_axi_arburst		        (m01_axi_arburst		    ),  // read burst type, 2'b01
    .m_axi_arlock		        (m01_axi_arlock		        ),  // 1'b0, not used
    .m_axi_arcache		        (m01_axi_arcache		    ),  // memory type, 4'b0010
    .m_axi_arprot		        (m01_axi_arprot		        ),  // protection type, 3'h0
    .m_axi_arqos		        (m01_axi_arqos		        ),  // quality of service identifier, 4'h0
    //.m_axi_aruser		        (m01_axi_aruser		        ),  // option user defined channel, 1'b1
    .m_axi_arvalid		        (m01_axi_arvalid		    ),  // read address valid
    .m_axi_arready		        (m01_axi_arready		    ),  // read address ready
    // read data
    .m_axi_rid		            (m01_axi_rid		        ),  // master inteface write response
    .m_axi_rdata		        (m01_axi_rdata		        ),  // read data
    .m_axi_rresp		        (m01_axi_rresp		        ),  // read response for read transaction
    .m_axi_rlast		        (m01_axi_rlast		        ),  // indicates last transfer in a burst
    //.m_axi_ruser		        (m01_axi_ruser		        ),  // option user defined channel
    .m_axi_rvalid		        (m01_axi_rvalid		        ),  // read data valid
    .m_axi_rready		        (m01_axi_rready		        ),  // read data ready, master can accept read data
    // read interface from data memory access request fifo
    .mem_req_fifo_output        (dmem_req_fifo_output       ),
    .mem_req_fifo_empty         (dmem_req_fifo_empty        ),
    .mem_req_fifo_almost_empty  (dmem_req_fifo_almost_empty ),
    .mem_req_fifo_rd_en         (dmem_req_fifo_rd_en        ),
    // write interface to data pkt2 fifo 
    .data_pkt2_fifo_input       (data_pkt2_fifo_input       ),
    .data_pkt2_fifo_wr_en       (data_pkt2_fifo_wr_en       ),
    .data_pkt2_fifo_full        (data_pkt2_fifo_full        ),
    .data_pkt2_fifo_almost_full (data_pkt2_fifo_almost_full ),
    // victim entry clear from front of victim buffer
    .cam_clear_fifo_input       (cam_clear_fifo_input       ),
    .cam_clear_fifo_wr_en       (cam_clear_fifo_wr_en       ),
    .cam_clear_fifo_full        (cam_clear_fifo_full        ),
    .cam_clear_fifo_almost_full (cam_clear_fifo_almost_full ),
    // interface from victim address buffer
    .victim_addr_fifo_output    (victim_addr_fifo_output    ),
    .victim_addr_fifo_empty     (victim_addr_fifo_empty     ),
    .victim_addr_fifo_rd_en     (victim_addr_fifo_rd_en     ),
    // interface from victim data buffer
    .victim_data_fifo_output    (victim_data_fifo_output    ),
    .victim_data_fifo_empty     (victim_data_fifo_empty     ),
    .victim_data_fifo_rd_en     (victim_data_fifo_rd_en     )

);

`ifdef SMAC
    // instruction smac access manager
    sentryControl_dcache_smac_manager DCACHE_SMAC_MANAGER (
        // AXI4 Master Interface                    
        .m_axi_aclk		            (m03_axi_aclk               ),  // global clock
        .m_axi_aresetn		        (m03_axi_aresetn            ),  // global reset, active low
        // write interface
        // write address
        .m_axi_awid		            (m03_axi_awid		        ),  // write address id, 1'b0
        .m_axi_awaddr		        (m03_axi_awaddr		        ),  // write address
        .m_axi_awlen		        (m03_axi_awlen		        ),  // number of write transfers in a burst
        .m_axi_awsize		        (m03_axi_awsize		        ),  // size of each write transfer in a burst
        .m_axi_awburst		        (m03_axi_awburst		    ),  // write burst type, 2'b01
        .m_axi_awlock		        (m03_axi_awlock		        ),  // 1'b0, not used
        .m_axi_awcache		        (m03_axi_awcache		    ),  // memory type, 4'b0010
        .m_axi_awprot		        (m03_axi_awprot		        ),  // protection type, 3'h0
        .m_axi_awqos		        (m03_axi_awqos		        ),  // quality of service identifier, 4'h0
        //.m_axi_awuser		        (m03_axi_awuser		        ),  // option user defined channel, 1'b1
        .m_axi_awvalid		        (m03_axi_awvalid		    ),  // write address valid
        .m_axi_awready		        (m03_axi_awready		    ),  // write address ready
        // write data
        .m_axi_wdata		        (m03_axi_wdata		        ),  // write data
        .m_axi_wstrb		        (m03_axi_wstrb		        ),  // write strobes (byte write enable)
        .m_axi_wlast		        (m03_axi_wlast		        ),  // indicates last transfer in a burst
        //.m_axi_wuser		        (m03_axi_wuser		        ),  // option user defined channel, 1'b0
        .m_axi_wvalid		        (m03_axi_wvalid		        ),  // write data valid
        .m_axi_wready		        (m03_axi_wready		        ),  // write data ready
        // write response
        .m_axi_bid		            (m03_axi_bid		        ),  // master inteface write response
        .m_axi_bresp		        (m03_axi_bresp		        ),  // write response for write transaction
        //.m_axi_buser		        (m03_axi_buser		        ),  // option user defined channel
        .m_axi_bvalid		        (m03_axi_bvalid		        ),  // write response valid
        .m_axi_bready		        (m03_axi_bready		        ),  // write response ready, master can accept another transaction
        // read interface
        // read address
        .m_axi_arid		            (m03_axi_arid		        ),  // read address id, 1'b0
        .m_axi_araddr		        (m03_axi_araddr		        ),  // read address
        .m_axi_arlen		        (m03_axi_arlen		        ),  // number of read transfers in a burst
        .m_axi_arsize		        (m03_axi_arsize		        ),  // size of each read transfer in a burst
        .m_axi_arburst		        (m03_axi_arburst		    ),  // read burst type, 2'b01
        .m_axi_arlock		        (m03_axi_arlock		        ),  // 1'b0, not used
        .m_axi_arcache		        (m03_axi_arcache		    ),  // memory type, 4'b0010
        .m_axi_arprot		        (m03_axi_arprot		        ),  // protection type, 3'h0
        .m_axi_arqos		        (m03_axi_arqos		        ),  // quality of service identifier, 4'h0
        //.m_axi_aruser		        (m03_axi_aruser		        ),  // option user defined channel, 1'b1
        .m_axi_arvalid		        (m03_axi_arvalid		    ),  // read address valid
        .m_axi_arready		        (m03_axi_arready		    ),  // read address ready
        // read data
        .m_axi_rid		            (m03_axi_rid		        ),  // master inteface write response
        .m_axi_rdata		        (m03_axi_rdata		        ),  // read data
        .m_axi_rresp		        (m03_axi_rresp		        ),  // read response for read transaction
        .m_axi_rlast		        (m03_axi_rlast		        ),  // indicates last transfer in a burst
        //.m_axi_ruser		        (m03_axi_ruser		        ),  // option user defined channel
        .m_axi_rvalid		        (m03_axi_rvalid		        ),  // read data valid
        .m_axi_rready		        (m03_axi_rready		        ),  // read data ready, master can accept read data
        // read interface from data memory access request fifo
        .smac_req_fifo_output       (dsmac_req_fifo_output      ),
        .smac_req_fifo_empty        (dsmac_req_fifo_empty       ),
        .smac_req_fifo_rd_en        (dsmac_req_fifo_rd_en       ),
        // write interface to data pkt3 fifo 
        .data_pkt3_fifo_input       (data_pkt3_fifo_input       ),
        .data_pkt3_fifo_wr_en       (data_pkt3_fifo_wr_en       ),
        .data_pkt3_fifo_full        (data_pkt3_fifo_full        ),
        .data_pkt3_fifo_almost_full (data_pkt3_fifo_almost_full )

    );
`endif

`ifdef SIMULATION
    // Pipeline Utilization Statistics
    reg [31:0] sentry_ctrl_cnt;
    reg [31:0] icache_req_cnt;
    reg [31:0] dcache_req_cnt;
    reg [31:0] inst_pkt1_cnt;
    reg [31:0] inst_pkt2_cnt;
    reg [31:0] data_pkt1_cnt;
    reg [31:0] data_pkt2_cnt;
    reg [31:0] evict_count;
    reg [31:0] evict_rd_count;
    // eviction count
    always @(posedge dcache_clk) begin
        if(rst) begin
            evict_count <= 32'd0;
            evict_rd_count <= 32'd0;
        end
        else if (victim_addr_fifo_wr_en) begin
            evict_count <= evict_count + 32'd1;
        end
        else if (victim_addr_fifo_rd_en) begin
            evict_rd_count <= evict_rd_count + 32'd1;
        end
    end
    // sentry control throghput
    always @(posedge control_clk) begin
        if(rst) begin
            sentry_ctrl_cnt <= 0;
        end
        else if(trace_en) begin
            sentry_ctrl_cnt <= sentry_ctrl_cnt + 4;
        end
    end
    `ifdef PARALLEL_ICACHE
    `else
        // pkt1
        always @(posedge icache_clk) begin
            if(rst) begin
                icache_req_cnt <= 0;
                inst_pkt1_cnt <= 0;
            end
            else begin
                if(icache_req_fifo_rd_en) begin
                    icache_req_cnt <= icache_req_cnt + 1;
                end
                if(|inst_pkt1_fifo_wr_en) begin
                    inst_pkt1_cnt <= inst_pkt1_cnt + inst_pkt1_fifo_wr_en[0] + inst_pkt1_fifo_wr_en[1] + inst_pkt1_fifo_wr_en[2] + inst_pkt1_fifo_wr_en[3];
                end
            end
        end
        always @(posedge dcache_clk) begin
            if(rst) begin
                dcache_req_cnt <= 0;
                data_pkt1_cnt <= 0;
            end
            else begin
                if(dcache_req_fifo2_rd_en) begin
                    dcache_req_cnt <= dcache_req_cnt + 1;
                end
                if(|data_pkt1_fifo_wr_en) begin
                    data_pkt1_cnt <= data_pkt1_cnt + data_pkt1_fifo_wr_en[0] + data_pkt1_fifo_wr_en[1] + data_pkt1_fifo_wr_en[2] + data_pkt1_fifo_wr_en[3];
                end
            end
        end
        // inst pkt2
        always @(posedge m00_axi_aclk) begin
            if(rst || !m00_axi_aresetn) begin
                inst_pkt2_cnt <= 0;
            end
            else begin
                if(|inst_pkt2_fifo_wr_en) begin
                    inst_pkt2_cnt <= inst_pkt2_cnt + inst_pkt2_fifo_wr_en[0] + inst_pkt2_fifo_wr_en[1] + inst_pkt2_fifo_wr_en[2] + inst_pkt2_fifo_wr_en[3];
                end
            end
        end
        // data pkt2
        always @(posedge m01_axi_aclk) begin
            if(rst || !m01_axi_aresetn) begin
                data_pkt2_cnt <= 0;
            end
            else begin
                if(|data_pkt2_fifo_wr_en) begin
                    data_pkt2_cnt <= data_pkt2_cnt + data_pkt2_fifo_wr_en[0] + data_pkt2_fifo_wr_en[1] + data_pkt2_fifo_wr_en[2] + data_pkt2_fifo_wr_en[3];
                end
            end
        end
    `endif
`endif

endmodule

