`timescale 1ns / 1ps
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

module trustguard (
    // AXI Interfaces
    // AXI4 Master Interface For Instruction Memory
    input  logic                        m00_axi_aclk,         // global clock
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
        input   quad_trace_s                trace_data,
        output                              trace_en,
    `else
        input                               trace_ready,
        input   quad_jump_result_s          trace_data,
        output                              trace_en,
    `endif
    // uBlaze interface should a typical bram interface 
    // uBlaze would write to net_in interface
    // input from uBlaze, bram style write & write_enable
    output logic                        net_get_clk,
    output logic                        net_get_rst,
    output logic [7:0]                  net_get_wr_en,
    output logic                        net_get_rd_en,
    output logic [31:0]                 net_get_addr,
    output data_t                       net_get_wr_data,
    input  data_t                       net_get_rd_data,
    // uBlaze would read from net_out interface
    // output to uBlaze, bram style write & write_enable
    output logic                        net_put_clk,
    output logic                        net_put_rst,
    output logic [7:0]                  net_put_wr_en,
    output logic                        net_put_rd_en,
    output logic [31:0]                 net_put_addr,
    output data_t                       net_put_wr_data,
    input  data_t                       net_put_rd_data,
    // debug output, combined full signals
    output logic [63:0]                 fifo_fulls,
    // checked LED Output, should never light up
    output                              checked,
    // clocks and reset
    input  logic                        control_clk,
    input  logic                        gearbox_clk,
    input  logic                        icache_clk,
    input  logic                        dcache_clk,
    input  logic                        cam_clk,
    input  logic                        sentry_clk,
    input  logic                        rst
);

genvar i;

// inst pkt1
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_wr_en;
(*keep="true"*)pkt1_t                      inst_pkt1_fifo_input        [`SENTRY_WIDTH-1:0];
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_rd_en;
(*keep="true"*)pkt1_t                      inst_pkt1_fifo_output       [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_full;
wire [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_empty;
wire [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_almost_full;
wire [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_almost_empty;
wire [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_prog_full;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]    inst_pkt1_fifo_wr_data_count    [`SENTRY_WIDTH-1:0];
    wire [`QCNT_WIDTH-1 : 0]    inst_pkt1_fifo_rd_data_count    [`SENTRY_WIDTH-1:0];
`endif
// data pkt1
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_wr_en;
(*keep="true"*)pkt1_t                      data_pkt1_fifo_input;
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_rd_en;
(*keep="true"*)pkt1_t                      data_pkt1_fifo_output       [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_full;
wire [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_empty;
wire [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_almost_full;
wire [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_almost_empty;
wire [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_prog_full;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]    data_pkt1_fifo_wr_data_count    [`SENTRY_WIDTH-1:0];
    wire [`QCNT_WIDTH-1 : 0]    data_pkt1_fifo_rd_data_count    [`SENTRY_WIDTH-1:0];
`endif
// inst pkt2
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    inst_pkt2_fifo_wr_en;
(*keep="true"*)pkt2_t                      inst_pkt2_fifo_input;
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    inst_pkt2_fifo_rd_en;
(*keep="true"*)pkt2_t                      inst_pkt2_fifo_output       [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]    inst_pkt2_fifo_full;
wire [`SENTRY_WIDTH-1:0]    inst_pkt2_fifo_empty;
wire [`SENTRY_WIDTH-1:0]    inst_pkt2_fifo_almost_full;
wire [`SENTRY_WIDTH-1:0]    inst_pkt2_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]    inst_pkt2_fifo_wr_data_count    [`SENTRY_WIDTH-1:0];
    wire [`QCNT_WIDTH-1 : 0]    inst_pkt2_fifo_rd_data_count    [`SENTRY_WIDTH-1:0];
`endif
// data vpkt
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    data_vpkt_fifo_wr_en;
(*keep="true"*)vpkt_t                      data_vpkt_fifo_input;
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    data_vpkt_fifo_rd_en;
(*keep="true"*)vpkt_t                      data_vpkt_fifo_output       [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]    data_vpkt_fifo_full;
wire [`SENTRY_WIDTH-1:0]    data_vpkt_fifo_empty;
wire [`SENTRY_WIDTH-1:0]    data_vpkt_fifo_almost_full;
wire [`SENTRY_WIDTH-1:0]    data_vpkt_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]    data_vpkt_fifo_wr_data_count    [`SENTRY_WIDTH-1:0];
    wire [`QCNT_WIDTH-1 : 0]    data_vpkt_fifo_rd_data_count    [`SENTRY_WIDTH-1:0];
`endif
// data pkt2
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    data_pkt2_fifo_wr_en;
(*keep="true"*)pkt2_t                      data_pkt2_fifo_input;
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    data_pkt2_fifo_rd_en;
(*keep="true"*)pkt2_t                      data_pkt2_fifo_output       [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]    data_pkt2_fifo_full;
wire [`SENTRY_WIDTH-1:0]    data_pkt2_fifo_empty;
wire [`SENTRY_WIDTH-1:0]    data_pkt2_fifo_almost_full;
wire [`SENTRY_WIDTH-1:0]    data_pkt2_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]    data_pkt2_fifo_wr_data_count    [`SENTRY_WIDTH-1:0];
    wire [`QCNT_WIDTH-1 : 0]    data_pkt2_fifo_rd_data_count    [`SENTRY_WIDTH-1:0];
`endif
`ifdef SMAC
    // inst pkt3
    wire [`SENTRY_WIDTH-1:0]    inst_pkt3_fifo_wr_en;
    pkt3_t                      inst_pkt3_fifo_input;
    wire [`SENTRY_WIDTH-1:0]    inst_pkt3_fifo_rd_en;
    pkt3_t                      inst_pkt3_fifo_output       [`SENTRY_WIDTH-1:0];
    wire [`SENTRY_WIDTH-1:0]    inst_pkt3_fifo_full;
    wire [`SENTRY_WIDTH-1:0]    inst_pkt3_fifo_empty;
    wire [`SENTRY_WIDTH-1:0]    inst_pkt3_fifo_almost_full;
    wire [`SENTRY_WIDTH-1:0]    inst_pkt3_fifo_almost_empty;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]    inst_pkt3_fifo_wr_data_count    [`SENTRY_WIDTH-1:0];
        wire [`QCNT_WIDTH-1 : 0]    inst_pkt3_fifo_rd_data_count    [`SENTRY_WIDTH-1:0];
    `endif
    // data pkt3
    wire [`SENTRY_WIDTH-1:0]    data_pkt3_fifo_wr_en;
    pkt3_t                      data_pkt3_fifo_input;
    wire [`SENTRY_WIDTH-1:0]    data_pkt3_fifo_rd_en;
    pkt3_t                      data_pkt3_fifo_output       [`SENTRY_WIDTH-1:0];
    wire [`SENTRY_WIDTH-1:0]    data_pkt3_fifo_full;
    wire [`SENTRY_WIDTH-1:0]    data_pkt3_fifo_empty;
    wire [`SENTRY_WIDTH-1:0]    data_pkt3_fifo_almost_full;
    wire [`SENTRY_WIDTH-1:0]    data_pkt3_fifo_almost_empty;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]    data_pkt3_fifo_wr_data_count    [`SENTRY_WIDTH-1:0];
        wire [`QCNT_WIDTH-1 : 0]    data_pkt3_fifo_rd_data_count    [`SENTRY_WIDTH-1:0];
    `endif
`endif

// victim data fifo
wire                        victim_data_fifo_rd_en;
victim_data_t               victim_data_fifo_output;
wire                        victim_data_fifo_wr_en;
victim_data_t               victim_data_fifo_input;
wire                        victim_data_fifo_full;
wire                        victim_data_fifo_empty;
wire                        victim_data_fifo_almost_full;
wire                        victim_data_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]    victim_data_fifo_wr_data_count;
    wire [`QCNT_WIDTH-1 : 0]    victim_data_fifo_rd_data_count;
`endif

// debug fifo output
assign fifo_fulls = {
    8'd0,
    inst_pkt1_fifo_full,
    inst_pkt2_fifo_full,
    data_pkt1_fifo_full,
    data_pkt2_fifo_full,
    data_vpkt_fifo_full,
    victim_data_fifo_full,
    8'd0,
    inst_pkt1_fifo_almost_full,
    inst_pkt2_fifo_almost_full,
    data_pkt1_fifo_almost_full,
    data_pkt2_fifo_almost_full,
    data_vpkt_fifo_almost_full,
    victim_data_fifo_almost_full
};

// fifo interface between sentry and sentry control
// Sentry Control Module
sentryControl_top SENTRYCONTROL(
    // AXI4 Master Interface For Instruction Memory
    .m00_axi_aclk		            (m00_axi_aclk                   ),  // global clock
    .m00_axi_aresetn		        (m00_axi_aresetn                ),  // global reset, active low
    // write interface
    // write address
    .m00_axi_awid		            (m00_axi_awid		            ),  // write address id, 1'b0
    .m00_axi_awaddr		            (m00_axi_awaddr		            ),  // write address
    .m00_axi_awlen		            (m00_axi_awlen		            ),  // number of write transfers in a burst
    .m00_axi_awsize		            (m00_axi_awsize		            ),  // size of each write transfer in a burst
    .m00_axi_awburst		        (m00_axi_awburst		        ),  // write burst type, 2'b01
    .m00_axi_awlock		            (m00_axi_awlock		            ),  // 1'b0, not used
    .m00_axi_awcache		        (m00_axi_awcache		        ),  // memory type, 4'b0010
    .m00_axi_awprot		            (m00_axi_awprot		            ),  // protection type, 3'h0
    .m00_axi_awqos		            (m00_axi_awqos		            ),  // quality of service identifier, 4'h0
    //.m00_axi_awuser		        (m00_axi_awuser		            ),  // option user defined channel, 1'b1
    .m00_axi_awvalid		        (m00_axi_awvalid		        ),  // write address valid
    .m00_axi_awready		        (m00_axi_awready		        ),  // write address ready
    // write data
    .m00_axi_wdata		            (m00_axi_wdata		            ),  // write data
    .m00_axi_wstrb		            (m00_axi_wstrb		            ),  // write strobes (byte write enable)
    .m00_axi_wlast		            (m00_axi_wlast		            ),  // indicates last transfer in a burst
    //.m00_axi_wuser		        (m00_axi_wuser		            ),  // option user defined channel, 1'b0
    .m00_axi_wvalid		            (m00_axi_wvalid		            ),  // write data valid
    .m00_axi_wready		            (m00_axi_wready		            ),  // write data ready
    // write response
    .m00_axi_bid		            (m00_axi_bid		            ),  // master inteface write response
    .m00_axi_bresp		            (m00_axi_bresp		            ),  // write response for write transaction
    //.m00_axi_buser		        (m00_axi_buser		            ),  // option user defined channel
    .m00_axi_bvalid		            (m00_axi_bvalid		            ),  // write response valid
    .m00_axi_bready		            (m00_axi_bready		            ),  // write response ready, master can accept another transaction
    // read interface
    // read address
    .m00_axi_arid		            (m00_axi_arid		            ),  // read address id, 1'b0
    .m00_axi_araddr		            (m00_axi_araddr		            ),  // read address
    .m00_axi_arlen		            (m00_axi_arlen		            ),  // number of read transfers in a burst
    .m00_axi_arsize		            (m00_axi_arsize		            ),  // size of each read transfer in a burst
    .m00_axi_arburst		        (m00_axi_arburst		        ),  // read burst type, 2'b01
    .m00_axi_arlock		            (m00_axi_arlock		            ),  // 1'b0, not used
    .m00_axi_arcache		        (m00_axi_arcache		        ),  // memory type, 4'b0010
    .m00_axi_arprot		            (m00_axi_arprot		            ),  // protection type, 3'h0
    .m00_axi_arqos		            (m00_axi_arqos		            ),  // quality of service identifier, 4'h0
    //.m00_axi_aruser		        (m00_axi_aruser		            ),  // option user defined channel, 1'b1
    .m00_axi_arvalid		        (m00_axi_arvalid		        ),  // read address valid
    .m00_axi_arready		        (m00_axi_arready		        ),  // read address ready
    // read data
    .m00_axi_rid		            (m00_axi_rid		            ),  // master inteface write response
    .m00_axi_rdata		            (m00_axi_rdata		            ),  // read data
    .m00_axi_rresp		            (m00_axi_rresp		            ),  // read response for read transaction
    .m00_axi_rlast		            (m00_axi_rlast		            ),  // indicates last transfer in a burst
    //.m00_axi_ruser		        (m00_axi_ruser		            ),  // option user defined channel
    .m00_axi_rvalid		            (m00_axi_rvalid		            ),  // read data valid
    .m00_axi_rready		            (m00_axi_rready		            ),  // read data ready, master can accept read data
    // AXI4 Master Interface For Data Memory
    .m01_axi_aclk		            (m01_axi_aclk                   ),  // global clock
    .m01_axi_aresetn		        (m01_axi_aresetn                ),  // global reset, active low
    // write interface
    // write address
    .m01_axi_awid		            (m01_axi_awid		            ),  // write address id, 1'b0
    .m01_axi_awaddr		            (m01_axi_awaddr		            ),  // write address
    .m01_axi_awlen		            (m01_axi_awlen		            ),  // number of write transfers in a burst
    .m01_axi_awsize		            (m01_axi_awsize		            ),  // size of each write transfer in a burst
    .m01_axi_awburst		        (m01_axi_awburst		        ),  // write burst type, 2'b01
    .m01_axi_awlock		            (m01_axi_awlock		            ),  // 1'b0, not used
    .m01_axi_awcache		        (m01_axi_awcache		        ),  // memory type, 4'b0010
    .m01_axi_awprot		            (m01_axi_awprot		            ),  // protection type, 3'h0
    .m01_axi_awqos		            (m01_axi_awqos		            ),  // quality of service identifier, 4'h0
    //.m01_axi_awuser		        (m01_axi_awuser		            ),  // option user defined channel, 1'b1
    .m01_axi_awvalid		        (m01_axi_awvalid		        ),  // write address valid
    .m01_axi_awready		        (m01_axi_awready		        ),  // write address ready
    // write data
    .m01_axi_wdata		            (m01_axi_wdata		            ),  // write data
    .m01_axi_wstrb		            (m01_axi_wstrb		            ),  // write strobes (byte write enable)
    .m01_axi_wlast		            (m01_axi_wlast		            ),  // indicates last transfer in a burst
    //.m01_axi_wuser		        (m01_axi_wuser		            ),  // option user defined channel, 1'b0
    .m01_axi_wvalid		            (m01_axi_wvalid		            ),  // write data valid
    .m01_axi_wready		            (m01_axi_wready		            ),  // write data ready
    // write response
    .m01_axi_bid		            (m01_axi_bid		            ),  // master inteface write response
    .m01_axi_bresp		            (m01_axi_bresp		            ),  // write response for write transaction
    //.m01_axi_buser		        (m01_axi_buser		            ),  // option user defined channel
    .m01_axi_bvalid		            (m01_axi_bvalid		            ),  // write response valid
    .m01_axi_bready		            (m01_axi_bready		            ),  // write response ready, master can accept another transaction
    // read interface
    // read address
    .m01_axi_arid		            (m01_axi_arid		            ),  // read address id, 1'b0
    .m01_axi_araddr		            (m01_axi_araddr		            ),  // read address
    .m01_axi_arlen		            (m01_axi_arlen		            ),  // number of read transfers in a burst
    .m01_axi_arsize		            (m01_axi_arsize		            ),  // size of each read transfer in a burst
    .m01_axi_arburst		        (m01_axi_arburst		        ),  // read burst type, 2'b01
    .m01_axi_arlock		            (m01_axi_arlock		            ),  // 1'b0, not used
    .m01_axi_arcache		        (m01_axi_arcache		        ),  // memory type, 4'b0010
    .m01_axi_arprot		            (m01_axi_arprot		            ),  // protection type, 3'h0
    .m01_axi_arqos		            (m01_axi_arqos		            ),  // quality of service identifier, 4'h0
    //.m01_axi_aruser		        (m01_axi_aruser		            ),  // option user defined channel, 1'b1
    .m01_axi_arvalid		        (m01_axi_arvalid		        ),  // read address valid
    .m01_axi_arready		        (m01_axi_arready		        ),  // read address ready
    // read data
    .m01_axi_rid		            (m01_axi_rid		            ),  // master inteface write response
    .m01_axi_rdata		            (m01_axi_rdata		            ),  // read data
    .m01_axi_rresp		            (m01_axi_rresp		            ),  // read response for read transaction
    .m01_axi_rlast		            (m01_axi_rlast		            ),  // indicates last transfer in a burst
    //.m01_axi_ruser		        (m01_axi_ruser		            ),  // option user defined channel
    .m01_axi_rvalid		            (m01_axi_rvalid		            ),  // read data valid
    .m01_axi_rready		            (m01_axi_rready		            ),  // read data ready, master can accept read data
    // trace buffer interaface
    .trace_ready                    (trace_ready                    ),
    .trace_data                     (trace_data                     ),
    .trace_en                       (trace_en                       ),
    // interface to sentry
    // inst pkt1
    .inst_pkt1_fifo_wr_en           (inst_pkt1_fifo_wr_en           ),
    .inst_pkt1_fifo_input           (inst_pkt1_fifo_input           ),
    .inst_pkt1_fifo_full            (inst_pkt1_fifo_full            ),
    .inst_pkt1_fifo_almost_full     (inst_pkt1_fifo_almost_full     ),
    .inst_pkt1_fifo_prog_full       (inst_pkt1_fifo_prog_full       ),
    // data pkt1
    .data_pkt1_fifo_wr_en           (data_pkt1_fifo_wr_en           ),
    .data_pkt1_fifo_input           (data_pkt1_fifo_input           ),
    .data_pkt1_fifo_full            (data_pkt1_fifo_full            ),
    .data_pkt1_fifo_almost_full     (data_pkt1_fifo_almost_full     ),
    .data_pkt1_fifo_prog_full       (data_pkt1_fifo_prog_full       ),
    // inst pkt2
    .inst_pkt2_fifo_wr_en           (inst_pkt2_fifo_wr_en           ),
    .inst_pkt2_fifo_input           (inst_pkt2_fifo_input           ),
    .inst_pkt2_fifo_full            (inst_pkt2_fifo_full            ),
    .inst_pkt2_fifo_almost_full     (inst_pkt2_fifo_almost_full     ),
    // data pkt2
    .data_pkt2_fifo_wr_en           (data_pkt2_fifo_wr_en           ),
    .data_pkt2_fifo_input           (data_pkt2_fifo_input           ),
    .data_pkt2_fifo_full            (data_pkt2_fifo_full            ),
    .data_pkt2_fifo_almost_full     (data_pkt2_fifo_almost_full     ),
    `ifdef SMAC
        // inst pkt3
        .inst_pkt3_fifo_wr_en           (inst_pkt3_fifo_wr_en           ),
        .inst_pkt3_fifo_input           (inst_pkt3_fifo_input           ),
        .inst_pkt3_fifo_full            (inst_pkt3_fifo_full            ),
        .inst_pkt3_fifo_almost_full     (inst_pkt3_fifo_almost_full     ),
        // data pkt3
        .data_pkt3_fifo_wr_en           (data_pkt3_fifo_wr_en           ),
        .data_pkt3_fifo_input           (data_pkt3_fifo_input           ),
        .data_pkt3_fifo_full            (data_pkt3_fifo_full            ),
        .data_pkt3_fifo_almost_full     (data_pkt3_fifo_almost_full     ),
    `endif
    // write interface to victim pkt fifo 
    .data_vpkt_fifo_input           (data_vpkt_fifo_input           ),
    .data_vpkt_fifo_wr_en           (data_vpkt_fifo_wr_en           ),
    .data_vpkt_fifo_full            (data_vpkt_fifo_full            ),
    .data_vpkt_fifo_almost_full     (data_vpkt_fifo_almost_full     ),
    // interface from victim data buffer
    `ifdef DATA_COUNT
        .victim_data_fifo_rd_data_count (victim_data_fifo_rd_data_count ),
    `endif
    .victim_data_fifo_output        (victim_data_fifo_output        ),
    .victim_data_fifo_empty         (victim_data_fifo_empty         ),
    .victim_data_fifo_rd_en         (victim_data_fifo_rd_en         ),
    // sentry control clock and reset
    .control_clk                    (control_clk                    ),
    .gearbox_clk                    (gearbox_clk                    ),
    .icache_clk                     (icache_clk                     ),
    .dcache_clk                     (dcache_clk                     ),
    .cam_clk                        (cam_clk                        ),
    .sentry_clk                     (sentry_clk                     ),
    .rst                            (rst                            )
);

// all pktn fifos share same input, different wr_en
generate
for(i = 0; i < `SENTRY_WIDTH; i = i + 1) begin: inst_pkt1_fifos
    `ifdef PARALLEL_ICACHE
        pkt1_fifo INST_PKT1_FIFO (
            .wr_clk         (control_clk                    ),  // input wire wr_clk
            .rd_clk         (sentry_clk                     ),  // input wire rd_clk
            .din            (inst_pkt1_fifo_input[i]        ),  // input wire [164: 0] din
            .wr_en          (inst_pkt1_fifo_wr_en[i]        ),  // input wire wr_en
            .rd_en          (inst_pkt1_fifo_rd_en[i]        ),  // input wire rd_en
            .dout           (inst_pkt1_fifo_output[i]       ),  // output wire [164: 0] dout
            .full           (inst_pkt1_fifo_full[i]         ),  // output wire full
            .empty          (inst_pkt1_fifo_empty[i]        ),  // output wire empty
            .almost_full    (inst_pkt1_fifo_almost_full[i]  ),  // output wire almost full
            .almost_empty   (inst_pkt1_fifo_almost_empty[i] ),  // output wire almost empty
            .prog_full      (inst_pkt1_fifo_prog_full[i]    ),  // output wire prog full
            `ifdef DATA_COUNT
                .wr_data_count  (inst_pkt1_fifo_wr_data_count[i]),  // output wire [9 :0] wr_data_count
                .rd_data_count  (inst_pkt1_fifo_rd_data_count[i]),  // output wire [9 :0] rd_data_count
            `endif
            .rst            (rst                            )   // input wire rst
        );
    `else
        pkt1_fifo INST_PKT1_FIFO (
            .wr_clk         (icache_clk                     ),  // input wire wr_clk
            .rd_clk         (sentry_clk                     ),  // input wire rd_clk
            .din            (inst_pkt1_fifo_input[i]        ),  // input wire [164: 0] din
            .wr_en          (inst_pkt1_fifo_wr_en[i]        ),  // input wire wr_en
            .rd_en          (inst_pkt1_fifo_rd_en[i]        ),  // input wire rd_en
            .dout           (inst_pkt1_fifo_output[i]       ),  // output wire [164: 0] dout
            .full           (inst_pkt1_fifo_full[i]         ),  // output wire full
            .empty          (inst_pkt1_fifo_empty[i]        ),  // output wire empty
            .almost_full    (inst_pkt1_fifo_almost_full[i]  ),  // output wire almost full
            .almost_empty   (inst_pkt1_fifo_almost_empty[i] ),  // output wire almost empty
            .prog_full      (inst_pkt1_fifo_prog_full[i]    ),  // output wire prog full
            `ifdef DATA_COUNT
                .wr_data_count  (inst_pkt1_fifo_wr_data_count[i]),  // output wire [9 :0] wr_data_count
                .rd_data_count  (inst_pkt1_fifo_rd_data_count[i]),  // output wire [9 :0] rd_data_count
            `endif
            .rst            (rst                            )   // input wire rst
        );
    `endif
end

for(i = 0; i < `SENTRY_WIDTH; i = i + 1) begin: data_pkt1_fifos
    pkt1_fifo DATA_PKT1_FIFO (
        .wr_clk         (dcache_clk                     ),  // input wire wr_clk
        .rd_clk         (sentry_clk                     ),  // input wire rd_clk
        .din            (data_pkt1_fifo_input           ),  // input wire [164: 0] din
        .wr_en          (data_pkt1_fifo_wr_en[i]        ),  // input wire wr_en
        .rd_en          (data_pkt1_fifo_rd_en[i]        ),  // input wire rd_en
        .dout           (data_pkt1_fifo_output[i]       ),  // output wire [164: 0] dout
        .full           (data_pkt1_fifo_full[i]         ),  // output wire full
        .empty          (data_pkt1_fifo_empty[i]        ),  // output wire empty
        .almost_full    (data_pkt1_fifo_almost_full[i]  ),  // output wire almost full
        .almost_empty   (data_pkt1_fifo_almost_empty[i] ),  // output wire almost empty
        .prog_full      (data_pkt1_fifo_prog_full[i]    ),  // output wire prog full
        `ifdef DATA_COUNT
            .wr_data_count  (data_pkt1_fifo_wr_data_count[i]),  // output wire [9 :0] wr_data_count
            .rd_data_count  (data_pkt1_fifo_rd_data_count[i]),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst                            )   // input wire rst
    );
end
for(i = 0; i < `SENTRY_WIDTH; i = i + 1) begin: inst_pkt2_fifos
    pkt2_fifo INST_PKT2_FIFO (
        .wr_clk         (m00_axi_aclk                   ),  // input wire wr_clk
        .rd_clk         (sentry_clk                     ),  // input wire rd_clk
        .din            (inst_pkt2_fifo_input           ),  // input wire [543: 0] din
        .wr_en          (inst_pkt2_fifo_wr_en[i]        ),  // input wire wr_en
        .rd_en          (inst_pkt2_fifo_rd_en[i]        ),  // input wire rd_en
        .dout           (inst_pkt2_fifo_output[i]       ),  // output wire [543: 0] dout
        .full           (inst_pkt2_fifo_full[i]         ),  // output wire full
        .empty          (inst_pkt2_fifo_empty[i]        ),  // output wire empty
        .almost_full    (inst_pkt2_fifo_almost_full[i]  ),  // output wire almost full
        .almost_empty   (inst_pkt2_fifo_almost_empty[i] ),  // output wire almost empty
        `ifdef DATA_COUNT
            .wr_data_count  (inst_pkt2_fifo_wr_data_count[i]),  // output wire [9 :0] wr_data_count
            .rd_data_count  (inst_pkt2_fifo_rd_data_count[i]),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst || !m00_axi_aresetn        )   // input wire rst
    );
end
for(i = 0; i < `SENTRY_WIDTH; i = i + 1) begin: data_vpkt_fifos
    vpkt_fifo DATA_VPKT_FIFO (
        .wr_clk         (cam_clk                        ),  // input wire wr_clk
        .rd_clk         (sentry_clk                     ),  // input wire rd_clk
        .din            (data_vpkt_fifo_input           ),  // input wire [543: 0] din
        .wr_en          (data_vpkt_fifo_wr_en[i]        ),  // input wire wr_en
        .rd_en          (data_vpkt_fifo_rd_en[i]        ),  // input wire rd_en
        .dout           (data_vpkt_fifo_output[i]       ),  // output wire [543: 0] dout
        .full           (data_vpkt_fifo_full[i]         ),  // output wire full
        .empty          (data_vpkt_fifo_empty[i]        ),  // output wire empty
        .almost_full    (data_vpkt_fifo_almost_full[i]  ),  // output wire almost full
        .almost_empty   (data_vpkt_fifo_almost_empty[i] ),  // output wire almost empty
        `ifdef DATA_COUNT
            .wr_data_count  (data_vpkt_fifo_wr_data_count[i]),  // output wire [9 :0] wr_data_count
            .rd_data_count  (data_vpkt_fifo_rd_data_count[i]),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst                            )   // input wire rst
    );
end
for(i = 0; i < `SENTRY_WIDTH; i = i + 1) begin: data_pkt2_fifos
    pkt2_fifo DATA_PKT2_FIFO (
        .wr_clk         (m01_axi_aclk                   ),  // input wire wr_clk
        .rd_clk         (sentry_clk                     ),  // input wire rd_clk
        .din            (data_pkt2_fifo_input           ),  // input wire [543: 0] din
        .wr_en          (data_pkt2_fifo_wr_en[i]        ),  // input wire wr_en
        .rd_en          (data_pkt2_fifo_rd_en[i]        ),  // input wire rd_en
        .dout           (data_pkt2_fifo_output[i]       ),  // output wire [543: 0] dout
        .full           (data_pkt2_fifo_full[i]         ),  // output wire full
        .empty          (data_pkt2_fifo_empty[i]        ),  // output wire empty
        .almost_full    (data_pkt2_fifo_almost_full[i]  ),  // output wire almost full
        .almost_empty   (data_pkt2_fifo_almost_empty[i] ),  // output wire almost empty
        `ifdef DATA_COUNT
            .wr_data_count  (data_pkt2_fifo_wr_data_count[i]),  // output wire [9 :0] wr_data_count
            .rd_data_count  (data_pkt2_fifo_rd_data_count[i]),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst || !m01_axi_aresetn        )   // input wire rst
    );
end
`ifdef SMAC
    for(i = 0; i < `SENTRY_WIDTH; i = i + 1) begin: inst_pkt3_fifos
        pkt3_fifo INST_PKT3_FIFO (
            .wr_clk         (m02_axi_aclk                   ),  // input wire wr_clk
            .rd_clk         (sentry_clk                     ),  // input wire rd_clk
            .din            (inst_pkt3_fifo_input           ),  // input wire [99 : 0] din
            .wr_en          (inst_pkt3_fifo_wr_en[i]        ),  // input wire wr_en
            .rd_en          (inst_pkt3_fifo_rd_en[i]        ),  // input wire rd_en
            .dout           (inst_pkt3_fifo_output[i]       ),  // output wire [99 : 0] dout
            .full           (inst_pkt3_fifo_full[i]         ),  // output wire full
            .empty          (inst_pkt3_fifo_empty[i]        ),  // output wire empty
            .almost_full    (inst_pkt3_fifo_almost_full[i]  ),  // output wire almost full
            .almost_empty   (inst_pkt3_fifo_almost_empty[i] ),  // output wire almost empty
            `ifdef DATA_COUNT
                .wr_data_count  (inst_pkt3_fifo_wr_data_count[i]),  // output wire [9 :0] wr_data_count
                .rd_data_count  (inst_pkt3_fifo_rd_data_count[i]),  // output wire [9 :0] rd_data_count
            `endif
            .rst            (rst || !m02_axi_aresetn        )   // input wire rst
        );
    end
    for(i = 0; i < `SENTRY_WIDTH; i = i + 1) begin: data_pkt3_fifos
        pkt3_fifo DATA_PKT3_FIFO (
            .wr_clk         (m03_axi_aclk                   ),  // input wire wr_clk
            .rd_clk         (sentry_clk                     ),  // input wire rd_clk
            .din            (data_pkt3_fifo_input           ),  // input wire [99 : 0] din
            .wr_en          (data_pkt3_fifo_wr_en[i]        ),  // input wire wr_en
            .rd_en          (data_pkt3_fifo_rd_en[i]        ),  // input wire rd_en
            .dout           (data_pkt3_fifo_output[i]       ),  // output wire [99 : 0] dout
            .full           (data_pkt3_fifo_full[i]         ),  // output wire full
            .empty          (data_pkt3_fifo_empty[i]        ),  // output wire empty
            .almost_full    (data_pkt3_fifo_almost_full[i]  ),  // output wire almost full
            .almost_empty   (data_pkt3_fifo_almost_empty[i] ),  // output wire almost empty
            `ifdef DATA_COUNT
                .wr_data_count  (data_pkt3_fifo_wr_data_count[i]),  // output wire [9 :0] wr_data_count
                .rd_data_count  (data_pkt3_fifo_rd_data_count[i]),  // output wire [9 :0] rd_data_count
            `endif
            .rst            (rst || !m03_axi_aresetn        )   // input wire rst
        );
    end
`endif
endgenerate

// Backwards queue of evicted cache data
victim_data_fifo VICTIM_DATA_FIFO (
    `ifdef PARALLEL_DCACHE
        .wr_clk         (sentry_clk                     ),  // input wire wr_clk
    `else
        .wr_clk         (dcache_clk                     ),  // input wire wr_clk
    `endif
    .rd_clk         (m01_axi_aclk                   ),  // input wire rd_clk
    .din            (victim_data_fifo_input         ),  // input wire [95 : 0] din
    .wr_en          (victim_data_fifo_wr_en         ),  // input wire wr_en
    .rd_en          (victim_data_fifo_rd_en         ),  // input wire rd_en
    .dout           (victim_data_fifo_output        ),  // output wire [95 : 0] dout
    .full           (victim_data_fifo_full          ),  // output wire full
    .empty          (victim_data_fifo_empty         ),  // output wire empty
    .almost_full    (victim_data_fifo_almost_full   ),  // output wire almost full
    .almost_empty   (victim_data_fifo_almost_empty  ),  // output wire almost empty
    `ifdef DATA_COUNT
        .wr_data_count  (victim_data_fifo_wr_data_count ),  // output wire [9 :0] wr_data_count
        .rd_data_count  (victim_data_fifo_rd_data_count ),  // output wire [9 :0] rd_data_count
    `endif
    .rst            (rst || !m01_axi_aresetn        )   // input wire rst
);


// Sentry Module
sentry_top   SENTRY(
    // epoll server buffer interface
    // interface to sentry control
    // inst pkt1
    .inst_pkt1_fifo_rd_en           (inst_pkt1_fifo_rd_en           ),
    .inst_pkt1_fifo_output          (inst_pkt1_fifo_output          ),
    .inst_pkt1_fifo_empty           (inst_pkt1_fifo_empty           ),
    .inst_pkt1_fifo_almost_empty    (inst_pkt1_fifo_almost_empty    ),
    // data pkt1
    .data_pkt1_fifo_rd_en           (data_pkt1_fifo_rd_en           ),
    .data_pkt1_fifo_output          (data_pkt1_fifo_output          ),
    .data_pkt1_fifo_empty           (data_pkt1_fifo_empty           ),
    .data_pkt1_fifo_almost_empty    (data_pkt1_fifo_almost_empty    ),
    // inst pkt2
    .inst_pkt2_fifo_rd_en           (inst_pkt2_fifo_rd_en           ),
    .inst_pkt2_fifo_output          (inst_pkt2_fifo_output          ),
    .inst_pkt2_fifo_empty           (inst_pkt2_fifo_empty           ),
    .inst_pkt2_fifo_almost_empty    (inst_pkt2_fifo_almost_empty    ),
    // data pkt2
    .data_pkt2_fifo_rd_en           (data_pkt2_fifo_rd_en           ),
    .data_pkt2_fifo_output          (data_pkt2_fifo_output          ),
    .data_pkt2_fifo_empty           (data_pkt2_fifo_empty           ),
    .data_pkt2_fifo_almost_empty    (data_pkt2_fifo_almost_empty    ),
    // read interface from victim pkt fifo 
    .data_vpkt_fifo_rd_en           (data_vpkt_fifo_rd_en           ),
    .data_vpkt_fifo_output          (data_vpkt_fifo_output          ),
    .data_vpkt_fifo_empty           (data_vpkt_fifo_empty           ),
    .data_vpkt_fifo_almost_empty    (data_vpkt_fifo_almost_empty    ),
    `ifdef SMAC
        // inst pkt3
        .inst_pkt3_fifo_rd_en           (inst_pkt3_fifo_rd_en           ),
        .inst_pkt3_fifo_output          (inst_pkt3_fifo_output          ),
        .inst_pkt3_fifo_empty           (inst_pkt3_fifo_empty           ),
        .inst_pkt3_fifo_almost_empty    (inst_pkt3_fifo_almost_empty    ),
        // data pkt3
        .data_pkt3_fifo_rd_en           (data_pkt3_fifo_rd_en           ),
        .data_pkt3_fifo_output          (data_pkt3_fifo_output          ),
        .data_pkt3_fifo_empty           (data_pkt3_fifo_empty           ),
        .data_pkt3_fifo_almost_empty    (data_pkt3_fifo_almost_empty    ),
    `endif
    // victim data fifo interface
    .victim_data_fifo_wr_en         (victim_data_fifo_wr_en         ),
    .victim_data_fifo_input         (victim_data_fifo_input         ),
    .victim_data_fifo_full          (victim_data_fifo_full          ), 
    .victim_data_fifo_almost_full   (victim_data_fifo_almost_full   ), 
    // uBlaze interfaces
    // interface, data for GET
    .net_get_clk                    (net_get_clk                    ),
    .net_get_rst                    (net_get_rst                    ),
    .net_get_rd_en                  (net_get_rd_en                  ),
    .net_get_wr_en                  (net_get_wr_en                  ),
    .net_get_addr                   (net_get_addr                   ),
    .net_get_rd_data                (net_get_rd_data                ),
    .net_get_wr_data                (net_get_wr_data                ),
    // interface, data for PUT
    .net_put_clk                    (net_put_clk                    ),
    .net_put_rst                    (net_put_rst                    ),
    .net_put_rd_en                  (net_put_rd_en                  ),
    .net_put_wr_en                  (net_put_wr_en                  ),
    .net_put_addr                   (net_put_addr                   ),
    .net_put_rd_data                (net_put_rd_data                ),
    .net_put_wr_data                (net_put_wr_data                ),
    // checked
    .checked                        (checked                        ),
    // sentry clock and reset
    .clk                            (sentry_clk                     ),
    .dcache_clk                     (dcache_clk                     ),
    .gearbox_clk                    (cam_clk                        ),
    .rst                            (rst                            )
);

endmodule

