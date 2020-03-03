// Sentry Top Level
`timescale 1ns / 1ps
`include "parameters.svh"
`include "encodings.svh"
`include "alu_ops.svh"
`include "muldiv_ops.svh" 
import TYPES::*;

//`define PARALLEL_DCACHE

module sentry_top(
    // interface to sentry control
    // inst pkt1
    output [`SENTRY_WIDTH-1:0]          inst_pkt1_fifo_rd_en,
    input  pkt1_t                       inst_pkt1_fifo_output           [`SENTRY_WIDTH-1:0],
    input  [`SENTRY_WIDTH-1:0]          inst_pkt1_fifo_empty,
    input  [`SENTRY_WIDTH-1:0]          inst_pkt1_fifo_almost_empty,
    // data pkt1
    output [`SENTRY_WIDTH-1:0]          data_pkt1_fifo_rd_en,
    input  pkt1_t                       data_pkt1_fifo_output           [`SENTRY_WIDTH-1:0],
    input  [`SENTRY_WIDTH-1:0]          data_pkt1_fifo_empty,
    input  [`SENTRY_WIDTH-1:0]          data_pkt1_fifo_almost_empty,
    // inst pkt2
    output [`SENTRY_WIDTH-1:0]          inst_pkt2_fifo_rd_en,
    input  pkt2_t                       inst_pkt2_fifo_output           [`SENTRY_WIDTH-1:0],
    input  [`SENTRY_WIDTH-1:0]          inst_pkt2_fifo_empty,
    input  [`SENTRY_WIDTH-1:0]          inst_pkt2_fifo_almost_empty,
    // data pkt2
    output [`SENTRY_WIDTH-1:0]          data_pkt2_fifo_rd_en,
    input  pkt2_t                       data_pkt2_fifo_output           [`SENTRY_WIDTH-1:0],
    input  [`SENTRY_WIDTH-1:0]          data_pkt2_fifo_empty,
    input  [`SENTRY_WIDTH-1:0]          data_pkt2_fifo_almost_empty,
    // data vpkt
    output [`SENTRY_WIDTH-1:0]          data_vpkt_fifo_rd_en,
    input  vpkt_t                       data_vpkt_fifo_output           [`SENTRY_WIDTH-1:0],
    input  [`SENTRY_WIDTH-1:0]          data_vpkt_fifo_empty,
    input  [`SENTRY_WIDTH-1:0]          data_vpkt_fifo_almost_empty,
    `ifdef SMAC
        // inst pkt3
        output [`SENTRY_WIDTH-1:0]          inst_pkt3_fifo_rd_en,
        input  pkt3_t                       inst_pkt3_fifo_output           [`SENTRY_WIDTH-1:0],
        input  [`SENTRY_WIDTH-1:0]          inst_pkt3_fifo_empty,
        input  [`SENTRY_WIDTH-1:0]          inst_pkt3_fifo_almost_empty,
        // data pkt3
        output [`SENTRY_WIDTH-1:0]          data_pkt3_fifo_rd_en,
        input  pkt3_t                       data_pkt3_fifo_output           [`SENTRY_WIDTH-1:0],
        input  [`SENTRY_WIDTH-1:0]          data_pkt3_fifo_empty,
        input  [`SENTRY_WIDTH-1:0]          data_pkt3_fifo_almost_empty,
    `endif
    // victim data fifo interface
    output                              victim_data_fifo_wr_en,
    output victim_data_t                victim_data_fifo_input,
    input                               victim_data_fifo_full, 
    input                               victim_data_fifo_almost_full, 
    // uBlaze interface should a typical bram interface 
    // uBlaze would write to net_get interface
    // input from uBlaze, bram style write & write_enable
    output logic                        net_get_clk,
    output logic                        net_get_rst,
    output logic [7:0]                  net_get_wr_en,
    output logic                        net_get_rd_en,
    output logic [31:0]                 net_get_addr,
    output data_t                       net_get_wr_data,
    input  data_t                       net_get_rd_data,
    // uBlaze would read from net_put interface
    // output to uBlaze, bram style write & write_enable
    output logic                        net_put_clk,
    output logic                        net_put_rst,
    output logic [7:0]                  net_put_wr_en,
    output logic                        net_put_rd_en,
    output logic [31:0]                 net_put_addr,
    output data_t                       net_put_wr_data,
    input  data_t                       net_put_rd_data,
    // operation valid
    output                              checked,
    // sentry clock and reset
    input                               clk,
    input                               dcache_clk,
    input                               gearbox_clk,
    input                               rst
);

genvar i;

// lsu pkt1
wire [`SENTRY_WIDTH-1:0]                lsu_pkt1_fifo_wr_en;
pkt1_t                                  lsu_pkt1_fifo_input             [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                lsu_pkt1_fifo_rd_en;
pkt1_t                                  lsu_pkt1_fifo_output            [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                lsu_pkt1_fifo_full;
wire [`SENTRY_WIDTH-1:0]                lsu_pkt1_fifo_empty;
wire [`SENTRY_WIDTH-1:0]                lsu_pkt1_fifo_almost_full;
wire [`SENTRY_WIDTH-1:0]                lsu_pkt1_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]                lsu_pkt1_fifo_data_count        [`SENTRY_WIDTH-1:0];
`endif
// lsu vpkt
wire [`SENTRY_WIDTH-1:0]                lsu_vpkt_fifo_wr_en;
vpkt_t                                  lsu_vpkt_fifo_input             [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                lsu_vpkt_fifo_rd_en;
vpkt_t                                  lsu_vpkt_fifo_output            [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                lsu_vpkt_fifo_full;
wire [`SENTRY_WIDTH-1:0]                lsu_vpkt_fifo_empty;
wire [`SENTRY_WIDTH-1:0]                lsu_vpkt_fifo_almost_full;
wire [`SENTRY_WIDTH-1:0]                lsu_vpkt_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]                lsu_vpkt_fifo_data_count        [`SENTRY_WIDTH-1:0];
`endif
// lsu pkt2
wire [`SENTRY_WIDTH-1:0]                lsu_pkt2_fifo_wr_en;
pkt2_t                                  lsu_pkt2_fifo_input             [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                lsu_pkt2_fifo_rd_en;
pkt2_t                                  lsu_pkt2_fifo_output            [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                lsu_pkt2_fifo_full;
wire [`SENTRY_WIDTH-1:0]                lsu_pkt2_fifo_empty;
wire [`SENTRY_WIDTH-1:0]                lsu_pkt2_fifo_almost_full;
wire [`SENTRY_WIDTH-1:0]                lsu_pkt2_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]                lsu_pkt2_fifo_data_count        [`SENTRY_WIDTH-1:0];
`endif

// if Parallel DCache Pipeline Optimization Enabled, 
// throttle DCache Requests to 1 request frame per 2 cycles
`ifdef DCACHE_OPT
    // lsu enable fifo
    wire                                    lsu_enable_fifo_wr_en;
    wire [`SENTRY_WIDTH-1:0]                lsu_enable_fifo_input;
    wire                                    lsu_enable_fifo_rd_en;
    wire [`SENTRY_WIDTH-1:0]                lsu_enable_fifo_output;
    wire                                    lsu_enable_fifo_full;
    wire                                    lsu_enable_fifo_empty;
    wire                                    lsu_enable_fifo_almost_full;
    wire                                    lsu_enable_fifo_almost_empty;
    wire                                    lsu_enable_fifo_prog_full;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]                lsu_enable_fifo_data_count;
    `endif
`endif

// Operand Routing to Redundant Functional Unit Reexecution Pipeline
wire [`SENTRY_WIDTH-1:0]                pipe_valid;
addr_t                                  PC                              [`SENTRY_WIDTH-1:0];
inst_t                                  instruction                     [`SENTRY_WIDTH-1:0];
data_t                                  result                          [`SENTRY_WIDTH-1:0];
tag_t                                   tag                             [`SENTRY_WIDTH-1:0];

// RegFile Interface
wire [`SENTRY_WIDTH-1:0]                rf_wr_en;
reg_t                                   rf_wr_addr                      [`SENTRY_WIDTH-1:0];
data_t                                  rf_wr_data                      [`SENTRY_WIDTH-1:0]; 
reg_t                                   rf_rd_addr_a                    [`SENTRY_WIDTH-1:0];
reg_t                                   rf_rd_addr_b                    [`SENTRY_WIDTH-1:0];
data_t                                  rf_rd_data_a                    [`SENTRY_WIDTH-1:0];
data_t                                  rf_rd_data_b                    [`SENTRY_WIDTH-1:0];

// ALU Interface
wire [`SENTRY_WIDTH-1:0]                alu_req;
wire [`ALU_OP_WIDTH-1:0]                alu_op                          [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                alu_in_sext;
wire [`SENTRY_WIDTH-1:0]                alu_out_sext;
wire [`SENTRY_WIDTH-1:0]                alu_srclow;
wire [`SENTRY_WIDTH-1:0]                alu_resultlow;
data_t                                  alu_src1                        [`SENTRY_WIDTH-1:0];
data_t                                  alu_src2                        [`SENTRY_WIDTH-1:0];
data_t                                  alu_result                      [`SENTRY_WIDTH-1:0];

// Multiply Divide Unit Interface
wire [`SENTRY_WIDTH-1:0]                md_req;
wire [`MD_OP_WIDTH-1:0]                 md_op                           [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                md_srclow;
wire [`SENTRY_WIDTH-1:0]                md_src1_signed;
wire [`SENTRY_WIDTH-1:0]                md_src2_signed;
data_t                                  md_src1                         [`SENTRY_WIDTH-1:0];
data_t                                  md_src2                         [`SENTRY_WIDTH-1:0];
wire [`MD_OUT_SEL_WIDTH-1:0]            md_out_sel                      [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                md_ready;
wire [`SENTRY_WIDTH-1:0]                md_done;
data_t                                  md_result                       [`SENTRY_WIDTH-1:0];

// Functioal Unit Backwards Pressure Interface
wire [`SENTRY_WIDTH-1:0]                functional_unit_ready;

// Network Controller Interface
// Outgoing Put Request, forward it onto network request queues
wire [`SENTRY_WIDTH-1:0]                net_put_req;
tag_result_t                            net_put_pkt                     [`SENTRY_WIDTH-1:0];
// Outgoing Put Request, forward it onto network request queues
wire [`SENTRY_WIDTH-1:0]                net_get_req;
tag_t                                   net_get_tag                     [`SENTRY_WIDTH-1:0];
// Get result to mem check unit
data_t                                  net_get_data;
wire [`SENTRY_WIDTH-1:0]                net_get_done;

// Load Store Unit Interface
wire [`SENTRY_WIDTH-1:0]                lsu_req;
inst_t                                  lsu_instruction                 [`SENTRY_WIDTH-1:0];
data_t                                  lsu_data                        [`SENTRY_WIDTH-1:0];
addr_t                                  lsu_addr                        [`SENTRY_WIDTH-1:0];
tag_t                                   lsu_tag                         [`SENTRY_WIDTH-1:0];
// Stall signal to each other pipeline
`ifdef DCACHE_OPT
    wire [`SENTRY_WIDTH-1:0]                inst_valid_out;
    wire                                    lsu_stall;
    wire [`SENTRY_WIDTH-1:0]                lsu_enable;
`endif


`ifdef PARALLEL_DCACHE

    // Victim CAM Interface (Parallel)
    wire [`SENTRY_WIDTH-1:0]                victim_cam_en;
    vindex_t                                victim_cam_index                [`SENTRY_WIDTH-1:0];
    line_t                                  victim_cam_line                 [`SENTRY_WIDTH-1:0];
    // Data Cache Control Interface (Parallel)
    en_t                                    cache_ens                       [`SENTRY_WIDTH-1:0];
    en_t                                    cache_evicts                    [`SENTRY_WIDTH-1:0];
    wire [`LINE_WIDTH_BYTE-1:0]             cache_wr_en_byte                [`SENTRY_WIDTH-1:0];
    addr_t                                  cache_wr_addr                   [`SENTRY_WIDTH-1:0];
    line_t                                  cache_wr_line                   [`SENTRY_WIDTH-1:0];
    // Victim Line Update Interface (Parallel)
    wire [`SENTRY_WIDTH-1:0]                victim_byte_sel;
    wire [`SENTRY_WIDTH-1:0]                victim_hword_sel;
    wire [`SENTRY_WIDTH-1:0]                victim_word_sel;
    wire [`SENTRY_WIDTH-1:0]                victim_dword_sel;
    wire [1:0]                              victim_qword_sel                [`SENTRY_WIDTH-1:0];
    wire [`SENTRY_WIDTH-1:0]                victim_byte_write;
    wire [`SENTRY_WIDTH-1:0]                victim_hword_write;
    wire [`SENTRY_WIDTH-1:0]                victim_word_write;
    wire [`SENTRY_WIDTH-1:0]                victim_dword_write;
    wire [7:0]                              victim_write_byte               [`SENTRY_WIDTH-1:0];
    wire [15:0]                             victim_write_hword              [`SENTRY_WIDTH-1:0];
    wire [31:0]                             victim_write_word               [`SENTRY_WIDTH-1:0];
    wire [63:0]                             victim_write_dword              [`SENTRY_WIDTH-1:0];
    // Cache Read Logic (Parallel)
    addr_t                                  cache_rd_addr                   [`SENTRY_WIDTH-1:0];
    line_t                                  cache_rd_line                   [`SENTRY_WIDTH-1:0];
    // Data Cache to Checking (Parallel)
    wire                                    check_mem_ready                 [`SENTRY_WIDTH-1:0];
    data_t                                  check_mem_out                   [`SENTRY_WIDTH-1:0];

    // Cache Parallel Eviction Logic (Parallel)
    wire [`SENTRY_WIDTH-1:0]                cache_evicted;
    line_t                                  cache_evict_line                [`SENTRY_WIDTH-1:0];

    // victim data fifo before 4-to-1 gear box
    wire                                    victim_data_fifo1_rd_en;
    wire [`LINE_WIDTH+`SMAC_WIDTH:0]        victim_data_fifo1_output        [`SENTRY_WIDTH-1:0];
    reg                                     victim_data_fifo1_wr_en;
    reg  [`LINE_WIDTH+`SMAC_WIDTH:0]        victim_data_fifo1_input         [`SENTRY_WIDTH-1:0];
    wire [`SENTRY_WIDTH-1:0]                victim_data_fifo1_full;
    wire [`SENTRY_WIDTH-1:0]                victim_data_fifo1_empty;
    wire [`SENTRY_WIDTH-1:0]                victim_data_fifo1_almost_full;
    wire [`SENTRY_WIDTH-1:0]                victim_data_fifo1_almost_empty;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]                victim_data_fifo1_wr_data_count [`SENTRY_WIDTH-1:0];
        wire [`QCNT_WIDTH-1 : 0]                victim_data_fifo1_rd_data_count [`SENTRY_WIDTH-1:0];
    `endif

    // victim data fifo after 4-to-1 gear box
    wire                                    victim_data_fifo2_rd_en;
    wire [`LINE_WIDTH+`SMAC_WIDTH+32-1:0]   victim_data_fifo2_output;
    wire                                    victim_data_fifo2_wr_en;
    wire [`LINE_WIDTH+`SMAC_WIDTH+32-1:0]   victim_data_fifo2_input;
    wire                                    victim_data_fifo2_full;
    wire                                    victim_data_fifo2_empty;
    wire                                    victim_data_fifo2_almost_full;
    wire                                    victim_data_fifo2_almost_empty;
    wire                                    victim_data_fifo2_prog_full;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]                victim_data_fifo2_wr_data_count;
        wire [`QCNT_WIDTH-1 : 0]                victim_data_fifo2_rd_data_count;
    `endif

`else

    // data cache access request fifo BEFORE 4-to-4 gear box
    wire [`SENTRY_WIDTH-1:0]                dcache_ctrl_req_wr_en;
    //wire [$bits(dcache_ctrl_req_t)-1:0]     dcache_ctrl_req_input           [`SENTRY_WIDTH-1:0];
    dcache_ctrl_req_t                       dcache_ctrl_req_input           [`SENTRY_WIDTH-1:0];

    // data cache access request fifo AFTER 4-to-4 gear box (split among 4 FIFOs)
    wire                                    dcache_ctrl_req_fifo_rd_en_split1;
    wire [255 :0]                           dcache_ctrl_req_fifo_output_split1;
    wire                                    dcache_ctrl_req_fifo_wr_en_split1;
    wire [1023:0]                           dcache_ctrl_req_fifo_input_split1;
    wire                                    dcache_ctrl_req_fifo_full_split1;
    wire                                    dcache_ctrl_req_fifo_empty_split1;
    wire                                    dcache_ctrl_req_fifo_almost_full_split1;
    wire                                    dcache_ctrl_req_fifo_almost_empty_split1;
    wire                                    dcache_ctrl_req_fifo_prog_full_split1;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]                dcache_ctrl_req_fifo_wr_data_count_split1;
        wire [`QCNT_WIDTH-1 : 0]                dcache_ctrl_req_fifo_rd_data_count_split1;
    `endif

    wire                                    dcache_ctrl_req_fifo_rd_en_split2;
    wire [255 :0]                           dcache_ctrl_req_fifo_output_split2;
    wire                                    dcache_ctrl_req_fifo_wr_en_split2;
    wire [1023:0]                           dcache_ctrl_req_fifo_input_split2;
    wire                                    dcache_ctrl_req_fifo_full_split2;
    wire                                    dcache_ctrl_req_fifo_empty_split2;
    wire                                    dcache_ctrl_req_fifo_almost_full_split2;
    wire                                    dcache_ctrl_req_fifo_almost_empty_split2;
    wire                                    dcache_ctrl_req_fifo_prog_full_split2;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]                dcache_ctrl_req_fifo_wr_data_count_split2;
        wire [`QCNT_WIDTH-1 : 0]                dcache_ctrl_req_fifo_rd_data_count_split2;
    `endif

    wire                                    dcache_ctrl_req_fifo_rd_en_split3;
    wire [255 :0]                           dcache_ctrl_req_fifo_output_split3;
    wire                                    dcache_ctrl_req_fifo_wr_en_split3;
    wire [1023:0]                           dcache_ctrl_req_fifo_input_split3;
    wire                                    dcache_ctrl_req_fifo_full_split3;
    wire                                    dcache_ctrl_req_fifo_empty_split3;
    wire                                    dcache_ctrl_req_fifo_almost_full_split3;
    wire                                    dcache_ctrl_req_fifo_almost_empty_split3;
    wire                                    dcache_ctrl_req_fifo_prog_full_split3;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]                dcache_ctrl_req_fifo_wr_data_count_split3;
        wire [`QCNT_WIDTH-1 : 0]                dcache_ctrl_req_fifo_rd_data_count_split3;
    `endif

    wire                                    dcache_ctrl_req_fifo_rd_en_split4;
    wire [255 :0]                           dcache_ctrl_req_fifo_output_split4;
    wire                                    dcache_ctrl_req_fifo_wr_en_split4;
    wire [1023:0]                           dcache_ctrl_req_fifo_input_split4;
    wire                                    dcache_ctrl_req_fifo_full_split4;
    wire                                    dcache_ctrl_req_fifo_empty_split4;
    wire                                    dcache_ctrl_req_fifo_almost_full_split4;
    wire                                    dcache_ctrl_req_fifo_almost_empty_split4;
    wire                                    dcache_ctrl_req_fifo_prog_full_split4;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]                dcache_ctrl_req_fifo_wr_data_count_split4;
        wire [`QCNT_WIDTH-1 : 0]                dcache_ctrl_req_fifo_rd_data_count_split4;
    `endif

    // data cache access request fifo AFTER 4-to-4 gear box
    wire                                                dcache_ctrl_req_fifo_rd_en;
    wire [$bits(dcache_ctrl_req_t)-1:0]                 dcache_ctrl_req_fifo_output;
    wire                                                dcache_ctrl_req_fifo_wr_en;
    //wire [`SENTRY_WIDTH*$bits(dcache_ctrl_req_t)-1:0]   dcache_ctrl_req_fifo_input;
    wire [`SENTRY_WIDTH-1:0][$bits(dcache_ctrl_req_t)-1:0]  dcache_ctrl_req_fifo_input;
    wire                                                dcache_ctrl_req_fifo_full;
    wire                                                dcache_ctrl_req_fifo_empty;
    wire                                                dcache_ctrl_req_fifo_almost_full;
    wire                                                dcache_ctrl_req_fifo_almost_empty;
    wire                                                dcache_ctrl_req_fifo_prog_full;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]                            dcache_ctrl_req_fifo_wr_data_count;
        wire [`QCNT_WIDTH-1 : 0]                            dcache_ctrl_req_fifo_rd_data_count;
    `endif

    // Victim CAM Interface (Parallel)
    vindex_t                                victim_cam_index;
    line_t                                  victim_cam_line;
    // Data Cache to Checking (Parallel)
    wire [`SENTRY_WIDTH-1:0]                check_mem_ready;
    data_t                                  check_mem_out_sequential;
    data_t                                  check_mem_out                   [`SENTRY_WIDTH-1:0];

    // Cache Parallel Eviction Logic (Parallel)
    wire                                    cache_evicted;
    line_t                                  cache_evict_line;

`endif

// Checking Unit Interface
wire [`SENTRY_WIDTH-1:0]                result_alu_select;
wire [`SENTRY_WIDTH-1:0]                result_md_select;
wire [`SENTRY_WIDTH-1:0]                result_mem_select;
wire [`SENTRY_WIDTH-1:0]                result_net_select;
wire [`SENTRY_WIDTH-1:0]                result_bypass_select;
data_t                                  host_result                     [`SENTRY_WIDTH-1:0];
tag_t                                   host_tag                        [`SENTRY_WIDTH-1:0];

// Bypass Tag Interface for instructions that do not need checking
wire [`SENTRY_WIDTH-1:0]                bypass_tag_fifo_wr_en;
tag_t                                   bypass_tag_fifo_input           [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                bypass_tag_fifo_rd_en;
tag_t                                   bypass_tag_fifo_output          [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                bypass_tag_fifo_full;
wire [`SENTRY_WIDTH-1:0]                bypass_tag_fifo_empty;
wire [`SENTRY_WIDTH-1:0]                bypass_tag_fifo_almost_full;
wire [`SENTRY_WIDTH-1:0]                bypass_tag_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]                bypass_tag_fifo_data_count      [`SENTRY_WIDTH-1:0];
`endif

// Output Buffer Resolve Interface
tag_t                                   alu_tag                         [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                alu_tag_valid;
wire [`SENTRY_WIDTH-1:0]                alu_tag_clear;
tag_t                                   md_tag                          [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                md_tag_valid;
wire [`SENTRY_WIDTH-1:0]                md_tag_clear;
tag_t                                   mem_tag                         [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                mem_tag_valid;
wire [`SENTRY_WIDTH-1:0]                mem_tag_clear;
tag_t                                   net_tag                         [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                net_tag_valid;
wire [`SENTRY_WIDTH-1:0]                net_tag_clear;
tag_t                                   bypass_tag                      [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]                bypass_tag_valid;
wire [`SENTRY_WIDTH-1:0]                bypass_tag_clear;

// Output Buffer Invalid and Stall
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]                alu_invalid;
wire [`SENTRY_WIDTH-1:0]                alu_check_ready;
(*keep="true"*)reg [31:0]                              alu_invalid_cnt;
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]                md_invalid;
wire [`SENTRY_WIDTH-1:0]                md_check_ready;
(*keep="true"*)reg [31:0]                              md_invalid_cnt;
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]                mem_invalid;
wire [`SENTRY_WIDTH-1:0]                mem_check_ready;
(*keep="true"*)reg [31:0]                              mem_invalid_cnt;
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]                net_invalid;
wire [`SENTRY_WIDTH-1:0]                net_check_ready;
(*keep="true"*)reg [31:0]                              net_invalid_cnt;
// Bypass interface is always valid
wire [`SENTRY_WIDTH-1:0]                bypass_check_ready;
wire [`SENTRY_WIDTH-1:0]                check_unit_ready;

// net_get req fifo before 4-to-1 gear box
wire                                            net_get_req_fifo1_rd_en;
wire [`SENTRY_WIDTH*($bits(tag_t)+1)-1:0]       net_get_req_fifo1_output;
wire                                            net_get_req_fifo1_wr_en;
wire [`SENTRY_WIDTH*($bits(tag_t)+1)-1:0]       net_get_req_fifo1_input;
wire                                            net_get_req_fifo1_full;
wire                                            net_get_req_fifo1_empty;
wire                                            net_get_req_fifo1_almost_full;
wire                                            net_get_req_fifo1_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]                        net_get_req_fifo1_wr_data_count;
    wire [`QCNT_WIDTH-1 : 0]                        net_get_req_fifo1_rd_data_count;
`endif

// net_get req fifo after 4-to-1 gear box
wire                                            net_get_req_fifo2_rd_en;
wire [$bits(tag_t)+32-1:0]                      net_get_req_fifo2_output;
wire                                            net_get_req_fifo2_wr_en;
wire [$bits(tag_t)+32-1:0]                      net_get_req_fifo2_input;
wire                                            net_get_req_fifo2_full;
wire                                            net_get_req_fifo2_empty;
wire                                            net_get_req_fifo2_almost_full;
wire                                            net_get_req_fifo2_almost_empty;
wire                                            net_get_req_fifo2_prog_full;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]                        net_get_req_fifo2_wr_data_count;
    wire [`QCNT_WIDTH-1 : 0]                        net_get_req_fifo2_rd_data_count;
`endif

// net_put req fifo before 4-to-1 gear box
wire                                            net_put_req_fifo1_rd_en;
wire [`SENTRY_WIDTH*($bits(tag_result_t)+1)-1:0]net_put_req_fifo1_output;
wire                                            net_put_req_fifo1_wr_en;
wire [`SENTRY_WIDTH*($bits(tag_result_t)+1)-1:0]net_put_req_fifo1_input;
wire                                            net_put_req_fifo1_full;
wire                                            net_put_req_fifo1_empty;
wire                                            net_put_req_fifo1_almost_full;
wire                                            net_put_req_fifo1_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]                        net_put_req_fifo1_wr_data_count;
    wire [`QCNT_WIDTH-1 : 0]                        net_put_req_fifo1_rd_data_count;
`endif

// net_put req fifo after 4-to-1 gear box
wire                                            net_put_req_fifo2_rd_en;
wire [$bits(tag_result_t)+32-1:0]               net_put_req_fifo2_output;
wire                                            net_put_req_fifo2_wr_en;
wire [$bits(tag_result_t)+32-1:0]               net_put_req_fifo2_input;
wire                                            net_put_req_fifo2_full;
wire                                            net_put_req_fifo2_empty;
wire                                            net_put_req_fifo2_almost_full;
wire                                            net_put_req_fifo2_almost_empty;
wire                                            net_put_req_fifo2_prog_full;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]                        net_put_req_fifo2_wr_data_count;
    wire [`QCNT_WIDTH-1 : 0]                        net_put_req_fifo2_rd_data_count;
`endif

// Final Checked Outgoing Network Data
wire                                    net_outgoing_req_fifo_wr_en;
data_t                                  net_outgoing_req_fifo_input;
wire                                    net_outgoing_req_fifo_rd_en;
data_t                                  net_outgoing_req_fifo_output;
wire                                    net_outgoing_req_fifo_full;
wire                                    net_outgoing_req_fifo_empty;
wire                                    net_outgoing_req_fifo_almost_full;
wire                                    net_outgoing_req_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]                net_outgoing_req_fifo_data_count;
`endif

assign checked = |alu_invalid || |md_invalid || |mem_invalid || |net_invalid;

always @(posedge clk) begin
    if(rst) begin
        alu_invalid_cnt <= 0;
        mem_invalid_cnt <= 0;
        md_invalid_cnt  <= 0;
        net_invalid_cnt <= 0;
    end
    else if(|alu_invalid) begin
        alu_invalid_cnt <= alu_invalid_cnt + 1;
    end
    else if(|mem_invalid) begin
        mem_invalid_cnt <= mem_invalid_cnt + 1;
    end
    else if(|md_invalid) begin
        md_invalid_cnt  <= md_invalid_cnt + 1;
    end
    else if(|net_invalid) begin
        net_invalid_cnt <= net_invalid_cnt + 1;
    end
end


// *********************************************
// Operand Routing Stage And Accompanying Logic
// *********************************************

// Ready/Stall Signal from Functional Unit and Checking Units back to Operand Routing
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: FUNCTIONAL_UNIT_STALLS
    assign functional_unit_ready[i] = md_ready[i] || 1;
    assign check_unit_ready[i] = alu_check_ready[i] && md_check_ready[i] && mem_check_ready[i] && net_check_ready[i] && bypass_check_ready[i];
end
endgenerate

// Operand Routing
sentry_operand_routing SENTRY_OR (
    // epoll server buffer interface
    // interface to sentry control
    // inst pkt1
    .inst_pkt1_fifo_rd_en           (inst_pkt1_fifo_rd_en           ),
    .inst_pkt1_fifo_output          (inst_pkt1_fifo_output          ),
    .inst_pkt1_fifo_empty           (inst_pkt1_fifo_empty           ),
    .inst_pkt1_fifo_almost_empty    (inst_pkt1_fifo_almost_empty    ),
    // inst pkt2
    .inst_pkt2_fifo_rd_en           (inst_pkt2_fifo_rd_en           ),
    .inst_pkt2_fifo_output          (inst_pkt2_fifo_output          ),
    .inst_pkt2_fifo_empty           (inst_pkt2_fifo_empty           ),
    .inst_pkt2_fifo_almost_empty    (inst_pkt2_fifo_almost_empty    ),
    `ifdef SMAC
        // inst pkt3
        .inst_pkt3_fifo_rd_en           (inst_pkt3_fifo_rd_en           ),
        .inst_pkt3_fifo_output          (inst_pkt3_fifo_output          ),
        .inst_pkt3_fifo_empty           (inst_pkt3_fifo_empty           ),
        .inst_pkt3_fifo_almost_empty    (inst_pkt3_fifo_almost_empty    ),
    `endif
    // data pkt1
    .data_pkt1_fifo_rd_en           (data_pkt1_fifo_rd_en           ),
    .data_pkt1_fifo_output          (data_pkt1_fifo_output          ),
    .data_pkt1_fifo_empty           (data_pkt1_fifo_empty           ),
    .data_pkt1_fifo_almost_empty    (data_pkt1_fifo_almost_empty    ),
    // data pkt2
    .data_pkt2_fifo_rd_en           (data_pkt2_fifo_rd_en           ),
    .data_pkt2_fifo_output          (data_pkt2_fifo_output          ),
    .data_pkt2_fifo_empty           (data_pkt2_fifo_empty           ),
    .data_pkt2_fifo_almost_empty    (data_pkt2_fifo_almost_empty    ),
    // data vpkt
    .data_vpkt_fifo_rd_en           (data_vpkt_fifo_rd_en           ),
    .data_vpkt_fifo_output          (data_vpkt_fifo_output          ),
    .data_vpkt_fifo_empty           (data_vpkt_fifo_empty           ),
    .data_vpkt_fifo_almost_empty    (data_vpkt_fifo_almost_empty    ),
    `ifdef SMAC
        // data pkt3
        .data_pkt3_fifo_rd_en           (data_pkt3_fifo_rd_en           ),
        .data_pkt3_fifo_output          (data_pkt3_fifo_output          ),
        .data_pkt3_fifo_empty           (data_pkt3_fifo_empty           ),
        .data_pkt3_fifo_almost_empty    (data_pkt3_fifo_almost_empty    ),
    `endif
    // Interface to internal pkt fifos
    .lsu_pkt1_fifo_input            (lsu_pkt1_fifo_input            ),
    .lsu_pkt1_fifo_wr_en            (lsu_pkt1_fifo_wr_en            ),
    .lsu_pkt1_fifo_full             (lsu_pkt1_fifo_full             ),
    .lsu_pkt1_fifo_almost_full      (lsu_pkt1_fifo_almost_full      ),
    .lsu_vpkt_fifo_input            (lsu_vpkt_fifo_input            ),
    .lsu_vpkt_fifo_wr_en            (lsu_vpkt_fifo_wr_en            ),
    .lsu_vpkt_fifo_full             (lsu_vpkt_fifo_full             ),
    .lsu_vpkt_fifo_almost_full      (lsu_vpkt_fifo_almost_full      ),
    .lsu_pkt2_fifo_input            (lsu_pkt2_fifo_input            ),
    .lsu_pkt2_fifo_wr_en            (lsu_pkt2_fifo_wr_en            ),
    .lsu_pkt2_fifo_full             (lsu_pkt2_fifo_full             ),
    .lsu_pkt2_fifo_almost_full      (lsu_pkt2_fifo_almost_full      ),
    // Interface to Decode Stage
    .pipe_valid                     (pipe_valid                     ),
    .issue_PC                       (PC                             ),
    .issue_instruction              (instruction                    ),
    .issue_result                   (result                         ),
    .issue_tag                      (tag                            ),
    // Functional Unit Back Pressure
    .functional_unit_ready          (functional_unit_ready          ),
    .check_unit_ready               (check_unit_ready               ),
    `ifdef DCACHE_OPT
        // LSU Enable FIFO Interface
        .lsu_enable_fifo_input          (lsu_enable_fifo_input          ),
        .lsu_enable_fifo_wr_en          (lsu_enable_fifo_wr_en          ),
        .lsu_enable_fifo_full           (lsu_enable_fifo_full           ),
        .lsu_enable_fifo_almost_full    (lsu_enable_fifo_almost_full    ),
        .lsu_enable_fifo_prog_full      (lsu_enable_fifo_prog_full      ),
    `endif
    // sentry clock and reset
    .clk                            (clk                            ),
    .rst                            (rst                            )
);

generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: INTERNAL_DATA_PKT_BUFFERS
    // internal data pkt1 queues (173 bits)
pkt1_fifo_sync LSU_PKT1(
    .clk            (clk                            ),  // input wire wr_clk
    .din            (lsu_pkt1_fifo_input[i]         ),  // input wire [191 : 0] din
    .wr_en          (lsu_pkt1_fifo_wr_en[i]         ),  // input wire wr_en
    .rd_en          (lsu_pkt1_fifo_rd_en[i]         ),  // input wire rd_en
    .dout           (lsu_pkt1_fifo_output[i]        ),  // output wire [191 : 0] dout
    .full           (lsu_pkt1_fifo_full[i]          ),  // output wire full
    .empty          (lsu_pkt1_fifo_empty[i]         ),  // output wire empty
    .almost_full    (lsu_pkt1_fifo_almost_full[i]   ),  // output wire full
    .almost_empty   (lsu_pkt1_fifo_almost_empty[i]  ),  // output wire empty
    `ifdef DATA_COUNT
        .data_count     (lsu_pkt1_fifo_data_count[i]    ),  // output wire [9 : 0] data_count
    `endif
    .srst           (rst                            )   // input wire rst
);
// internal data vpkt queues
vpkt_fifo_sync LSU_VPKT(
    .clk            (clk                            ),  // input wire wr_clk
    .din            (lsu_vpkt_fifo_input[i]         ),  // input wire [191 : 0] din
    .wr_en          (lsu_vpkt_fifo_wr_en[i]         ),  // input wire wr_en
    .rd_en          (lsu_vpkt_fifo_rd_en[i]         ),  // input wire rd_en
    .dout           (lsu_vpkt_fifo_output[i]        ),  // output wire [191 : 0] dout
    .full           (lsu_vpkt_fifo_full[i]          ),  // output wire full
    .empty          (lsu_vpkt_fifo_empty[i]         ),  // output wire empty
    .almost_full    (lsu_vpkt_fifo_almost_full[i]   ),  // output wire full
    .almost_empty   (lsu_vpkt_fifo_almost_empty[i]  ),  // output wire empty
    `ifdef DATA_COUNT
        .data_count     (lsu_vpkt_fifo_data_count[i]    ),  // output wire [9 : 0] data_count
    `endif
    .srst           (rst                            )   // input wire rst
);
// internal data pkt2 queues
pkt2_fifo_sync LSU_PKT2(
    .clk            (clk                            ),  // input wire wr_clk
    .din            (lsu_pkt2_fifo_input[i]         ),  // input wire [191 : 0] din
    .wr_en          (lsu_pkt2_fifo_wr_en[i]         ),  // input wire wr_en
    .rd_en          (lsu_pkt2_fifo_rd_en[i]         ),  // input wire rd_en
    .dout           (lsu_pkt2_fifo_output[i]        ),  // output wire [191 : 0] dout
    .full           (lsu_pkt2_fifo_full[i]          ),  // output wire full
    .empty          (lsu_pkt2_fifo_empty[i]         ),  // output wire empty
    .almost_full    (lsu_pkt2_fifo_almost_full[i]   ),  // output wire full
    .almost_empty   (lsu_pkt2_fifo_almost_empty[i]  ),  // output wire empty
    `ifdef DATA_COUNT
        .data_count     (lsu_pkt2_fifo_data_count[i]    ),  // output wire [9 : 0] data_count
    `endif
    .srst           (rst                            )   // input wire rst
);
end
endgenerate

// 4-ported register file
regFile_4wide SENTRY_RF (
    .clk                (clk                ),
    .rst                (rst                ),
    .wr_en              (rf_wr_en           ),
    .wr_addr            (rf_wr_addr         ),
    .wr_data            (rf_wr_data         ),
    .rd_addr_a          (rf_rd_addr_a       ),
    .rd_addr_b          (rf_rd_addr_b       ),
    .rd_data_a          (rf_rd_data_a       ),
    .rd_data_b          (rf_rd_data_b       )
);

// Memory Subsystem Timing Optimization, data cache follows a 4-cycle sequence of 
// frame0 read, frame0 write, frame1 read, frame1 write
`ifdef DCACHE_OPT
    // LSU Enable FIFO
    lsu_enable_fifo LSU_EN_FIFO(
        .clk            (clk                            ),  // input wire wr_clk
        .din            (lsu_enable_fifo_input          ),  // input wire [191 : 0] din
        .wr_en          (lsu_enable_fifo_wr_en          ),  // input wire wr_en
        .rd_en          (lsu_enable_fifo_rd_en          ),  // input wire rd_en
        .dout           (lsu_enable_fifo_output         ),  // output wire [191 : 0] dout
        .full           (lsu_enable_fifo_full           ),  // output wire full
        .empty          (lsu_enable_fifo_empty          ),  // output wire empty
        .almost_full    (lsu_enable_fifo_almost_full    ),  // output wire full
        .almost_empty   (lsu_enable_fifo_almost_empty   ),  // output wire empty
        .prog_full      (lsu_enable_fifo_prog_full      ),  // output wire empty
        `ifdef DATA_COUNT
            .data_count     (lsu_enable_fifo_data_count     ),  // output wire [9 : 0] data_count
        `endif
        .srst           (rst                            )   // input wire rst
    );

    // LSU Selective Enable
    assign lsu_stall = | inst_valid_out;
    assign lsu_enable_fifo_rd_en = | inst_valid_out;
    assign lsu_enable = lsu_enable_fifo_output;
`endif

// ***************************************
// Parallel RICU Pipelines (Decode/LSU/FU)
// ***************************************
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: RICU
    // DECODE Unit
sentry_decode DECODE (
    // Interface from Operand Routing Stage
    .inst_valid                     (pipe_valid[i]                  ),
    .PC                             (PC[i]                          ),
    .instruction                    (instruction[i]                 ),
    .result                         (result[i]                      ),
    .tag                            (tag[i]                         ),
    // Register File Control
    .rs1                            (rf_rd_addr_a[i]                ),
    .rs2                            (rf_rd_addr_b[i]                ),
    .rs1_data                       (rf_rd_data_a[i]                ),
    .rs2_data                       (rf_rd_data_b[i]                ),
    .rd_wr_en                       (rf_wr_en[i]                    ),
    .rd                             (rf_wr_addr[i]                  ),
    .rd_data                        (rf_wr_data[i]                  ),
    // Network Buffer Control (Programmed I/O) 
    // Outgoing Put Request, forward it onto network request queues
    .net_put_req                    (net_put_req[i]                 ),
    .net_put_pkt                    (net_put_pkt[i]                 ),
    // Outgoing Get Request, forward it onto network request queues
    .net_get_req                    (net_get_req[i]                 ),
    .net_get_tag                    (net_get_tag[i]                 ),
    // Load Store Unit Control
    .lsu_req                        (lsu_req[i]                     ),
    .lsu_instruction                (lsu_instruction[i]             ),
    .lsu_data                       (lsu_data[i]                    ),
    .lsu_tag                        (lsu_tag[i]                     ),
    // ALU Control
    .alu_req                        (alu_req[i]                     ),
    .alu_op                         (alu_op[i]                      ),
    .alu_in_sext                    (alu_in_sext[i]                 ),
    .alu_out_sext                   (alu_out_sext[i]                ),
    .alu_srclow                     (alu_srclow[i]                  ),
    .alu_resultlow                  (alu_resultlow[i]               ),
    .alu_src1                       (alu_src1[i]                    ),
    .alu_src2                       (alu_src2[i]                    ),
    .alu_result                     (alu_result[i]                  ),
    // Multiply Divide Unit Control
    .md_req                         (md_req[i]                      ),
    .md_op                          (md_op[i]                       ),
    .md_srclow                      (md_srclow[i]                   ),
    .md_src1_signed                 (md_src1_signed[i]              ),
    .md_src2_signed                 (md_src2_signed[i]              ),
    .md_src1                        (md_src1[i]                     ),
    .md_src2                        (md_src2[i]                     ),
    .md_out_sel                     (md_out_sel[i]                  ),
    .md_result                      (md_result[i]                   ),
    // Results To Checking Stage
    .result_alu_select              (result_alu_select[i]           ),
    .result_md_select               (result_md_select[i]            ),
    .result_mem_select              (result_mem_select[i]           ),
    .result_net_select              (result_net_select[i]           ),
    .result_bypass_select           (result_bypass_select[i]        ),
    .host_result                    (host_result[i]                 ),
    .host_tag                       (host_tag[i]                    ),
    // sentry clock and reset
    .clk                            (clk                            ),
    .rst                            (rst                            )
);

`ifdef PARALLEL_DCACHE
    // Load Store Unit Parallel Memory Subsystem Version
    sentry_lsu LSU (
        // data pkt1
        .data_pkt1_fifo_rd_en           (lsu_pkt1_fifo_rd_en[i]         ),
        .data_pkt1_fifo_output          (lsu_pkt1_fifo_output[i]        ),
        .data_pkt1_fifo_empty           (lsu_pkt1_fifo_empty[i]         ),
        .data_pkt1_fifo_almost_empty    (lsu_pkt1_fifo_almost_empty[i]  ),
        // read interface from victim pkt fifo 
        .data_vpkt_fifo_rd_en           (lsu_vpkt_fifo_rd_en[i]         ),
        .data_vpkt_fifo_output          (lsu_vpkt_fifo_output[i]        ),
        .data_vpkt_fifo_empty           (lsu_vpkt_fifo_empty[i]         ),
        .data_vpkt_fifo_almost_empty    (lsu_vpkt_fifo_almost_empty[i]  ),
        // data pkt2
        .data_pkt2_fifo_rd_en           (lsu_pkt2_fifo_rd_en[i]         ),
        .data_pkt2_fifo_output          (lsu_pkt2_fifo_output[i]        ),
        .data_pkt2_fifo_empty           (lsu_pkt2_fifo_empty[i]         ),
        .data_pkt2_fifo_almost_empty    (lsu_pkt2_fifo_almost_empty[i]  ),
        `ifdef SMAC
            // data pkt3
            .data_pkt3_fifo_rd_en           (data_pkt3_fifo_rd_en[i]        ),
            .data_pkt3_fifo_output          (data_pkt3_fifo_output[i]       ),
            .data_pkt3_fifo_empty           (data_pkt3_fifo_empty[i]        ),
            .data_pkt3_fifo_almost_empty    (data_pkt3_fifo_almost_empty[i] ),
        `endif
        // Victim CAM Interface
        .victim_cam_en                  (victim_cam_en[i]               ),
        .victim_cam_index               (victim_cam_index[i]            ),
        // Load store Unit Request Interface
        .lsu_req                        (lsu_req[i]                     ),
        .lsu_instruction                (lsu_instruction[i]             ),
        .lsu_data                       (lsu_data[i]                    ),
        .lsu_addr                       (alu_result[i]                  ),
        .lsu_tag                        (lsu_tag[i]                     ),
        // Stall signal to each other pipeline
        `ifdef DCACHE_OPT
            .lsu_stall                      (lsu_stall                      ),
            .lsu_enable                     (lsu_enable[i]                  ),
            .inst_valid_out                 (inst_valid_out[i]              ),
        `endif
        // data cache control
        .cache_ens                      (cache_ens[i]                   ),   
        .cache_evicts                   (cache_evicts[i]                ),   
        .cache_wr_en_byte               (cache_wr_en_byte[i]            ),
        .cache_wr_addr                  (cache_wr_addr[i]               ),
        .cache_wr_line                  (cache_wr_line[i]               ),
        // Vicitm Line Updates
        .victim_byte_sel                (victim_byte_sel[i]             ),
        .victim_hword_sel               (victim_hword_sel[i]            ),
        .victim_word_sel                (victim_word_sel[i]             ),
        .victim_dword_sel               (victim_dword_sel[i]            ),
        .victim_qword_sel               (victim_qword_sel[i]            ),
        .victim_byte_write              (victim_byte_write[i]           ),
        .victim_hword_write             (victim_hword_write[i]          ),
        .victim_word_write              (victim_word_write[i]           ),
        .victim_dword_write             (victim_dword_write[i]          ),
        .victim_write_byte              (victim_write_byte[i]           ),
        .victim_write_hword             (victim_write_hword[i]          ),
        .victim_write_word              (victim_write_word[i]           ),
        .victim_write_dword             (victim_write_dword[i]          ),
        // Cache Read Control
        .cache_rd_addr                  (cache_rd_addr[i]               ),
        .cache_rd_line                  (cache_rd_line[i]               ),
        // Result Signals to Checking Stage
        .check_mem_ready                (check_mem_ready[i]             ),  
        .check_mem_out                  (check_mem_out[i]               ),  
        // Clock and Reset
        .clk                            (clk                            ),
        .rst                            (rst                            )
    );

    // Memory Checking Unit
    sentry_checking MEM_CHK (
        // Incoming Untrusted Host Result
        .result_select                  (result_mem_select[i]           ),
        .host_result                    (host_result[i]                 ),
        .host_tag                       (host_tag[i]                    ),
        // Incoming Function Unit Result
        .fu_ready                       (check_mem_ready[i]             ),
        .fu_result                      (check_mem_out[i]               ),
        // Outgoing Checked Correct Tag
        .tag                            (mem_tag[i]                     ), 
        .tag_valid                      (mem_tag_valid[i]               ),
        .tag_clear                      (mem_tag_clear[i]               ),
        // Invalid and Stall signals
        .invalid                        (mem_invalid[i]                 ),
        .ready                          (mem_check_ready[i]             ),
        // Clock and Reset
        .clk                            (clk                            ),
        .rst                            (rst                            )
    );

`else

    // Load Store Unit Sequential Memory Subsystem Version
    sentry_lsu_sequential LSU (
        // data pkt1
        .data_pkt1_fifo_rd_en               (lsu_pkt1_fifo_rd_en[i]             ),
        .data_pkt1_fifo_output              (lsu_pkt1_fifo_output[i]            ),
        .data_pkt1_fifo_empty               (lsu_pkt1_fifo_empty[i]             ),
        .data_pkt1_fifo_almost_empty        (lsu_pkt1_fifo_almost_empty[i]      ),
        // read interface from victim pkt fifo 
        .data_vpkt_fifo_rd_en               (lsu_vpkt_fifo_rd_en[i]             ),
        .data_vpkt_fifo_output              (lsu_vpkt_fifo_output[i]            ),
        .data_vpkt_fifo_empty               (lsu_vpkt_fifo_empty[i]             ),
        .data_vpkt_fifo_almost_empty        (lsu_vpkt_fifo_almost_empty[i]      ),
        // data pkt2
        .data_pkt2_fifo_rd_en               (lsu_pkt2_fifo_rd_en[i]             ),
        .data_pkt2_fifo_output              (lsu_pkt2_fifo_output[i]            ),
        .data_pkt2_fifo_empty               (lsu_pkt2_fifo_empty[i]             ),
        .data_pkt2_fifo_almost_empty        (lsu_pkt2_fifo_almost_empty[i]      ),
        `ifdef SMAC
            // data pkt3
            .data_pkt3_fifo_rd_en               (data_pkt3_fifo_rd_en[i]            ),
            .data_pkt3_fifo_output              (data_pkt3_fifo_output[i]           ),
            .data_pkt3_fifo_empty               (data_pkt3_fifo_empty[i]            ),
            .data_pkt3_fifo_almost_empty        (data_pkt3_fifo_almost_empty[i]     ),
        `endif
        // Load store Unit Request Interface
        .lsu_req                            (lsu_req[i]                         ),
        .lsu_instruction                    (lsu_instruction[i]                 ),
        .lsu_data                           (lsu_data[i]                        ),
        .lsu_addr                           (alu_result[i]                      ),
        .lsu_tag                            (lsu_tag[i]                         ),
        // Output Interface to 4-to-4 Filter Gearbox
        .dcache_ctrl_req_fifo_full          (dcache_ctrl_req_fifo_full          ),
        .dcache_ctrl_req_fifo_almost_full   (dcache_ctrl_req_fifo_almost_full   ),
        .dcache_ctrl_req_fifo_prog_full     (dcache_ctrl_req_fifo_prog_full     ),
        .dcache_ctrl_req_fifo_wr_en         (dcache_ctrl_req_wr_en[i]           ),
        .dcache_ctrl_req_fifo_input         (dcache_ctrl_req_input[i]           ),
        // Clock and Reset
        .clk                                (clk                                ),
        .rst                                (rst                                )
    );

    // Memory Checking Unit
    sentry_checking_async MEM_CHK (
        // Incoming Untrusted Host Result
        .result_select                  (result_mem_select[i]           ),
        .host_result                    (host_result[i]                 ),
        .host_tag                       (host_tag[i]                    ),
        // Incoming Function Unit Result
        .fu_ready                       (check_mem_ready[i]             ),
        .fu_result                      (check_mem_out[i]               ),
        // Outgoing Checked Correct Tag
        .tag                            (mem_tag[i]                     ), 
        .tag_valid                      (mem_tag_valid[i]               ),
        .tag_clear                      (mem_tag_clear[i]               ),
        // Invalid and Stall signals
        .invalid                        (mem_invalid[i]                 ),
        .ready                          (mem_check_ready[i]             ),
        // Clock and Reset
        .dcache_clk                     (dcache_clk                     ),
        .clk                            (clk                            ),
        .rst                            (rst                            )
    );

`endif

// ALU 
// (ALU is always ready so it does not need a request queue)
sentry_alu ALU (
    .op                             (alu_op[i]                      ),
    .src1                           (alu_src1[i]                    ),
    .src2                           (alu_src2[i]                    ),
    .in_sext                        (alu_in_sext[i]                 ),
    .out_sext                       (alu_out_sext[i]                ),
    .srclow                         (alu_srclow[i]                  ),
    .resultlow                      (alu_resultlow[i]               ),
    .result                         (alu_result[i]                  )
);

// ALU Checking Unit
sentry_checking ALU_CHK (
    // Incoming Untrusted Host Result
    .result_select                  (result_alu_select[i]           ),
    .host_result                    (host_result[i]                 ),
    .host_tag                       (host_tag[i]                    ),
    // Incoming Function Unit Result
    .fu_ready                       (alu_req[i]                     ),
    .fu_result                      (alu_result[i]                  ),
    // Outgoing Checked Correct Tag
    .tag                            (alu_tag[i]                     ), 
    .tag_valid                      (alu_tag_valid[i]               ),
    .tag_clear                      (alu_tag_clear[i]               ),
    // Invalid and Stall signals
    .invalid                        (alu_invalid[i]                 ),
    .ready                          (alu_check_ready[i]             ),
    // Clock and Reset
    .clk                            (clk                            ),
    .rst                            (rst                            )
);

// Multiply/Divide Unit 
// (MD unit isn't pipelined yet, therefore it 
// has significant latency so it needs a request queue)
sentry_muldiv_unit MULDIV (
    .clk                            (clk                            ),
    .rst                            (rst                            ),
    .req                            (md_req[i]                      ),
    .req_op                         (md_op[i]                       ),
    .req_srclow                     (md_srclow[i]                   ),
    .req_src1_signed                (md_src1_signed[i]              ),
    .req_src2_signed                (md_src2_signed[i]              ),
    .req_src1                       (md_src1[i]                     ),
    .req_src2                       (md_src2[i]                     ),
    .req_out_sel                    (md_out_sel[i]                  ),
    .ready                          (md_ready[i]                    ),
    .done                           (md_done[i]                     ),
    .out                            (md_result[i]                   )
);

// Multiply/Divide Checking Unit
sentry_checking MULDIV_CHK (
    // Incoming Untrusted Host Result
    .result_select                  (result_md_select[i]            ),
    .host_result                    (host_result[i]                 ),
    .host_tag                       (host_tag[i]                    ),
    // Incoming Function Unit Result
    .fu_ready                       (md_done[i]                     ),
    .fu_result                      (md_result[i]                   ),
    // Outgoing Checked Correct Tag
    .tag                            (md_tag[i]                      ), 
    .tag_valid                      (md_tag_valid[i]                ),
    .tag_clear                      (md_tag_clear[i]                ),
    // Invalid and Stall signals
    .invalid                        (md_invalid[i]                  ),
    .ready                          (md_check_ready[i]              ),
    // Clock and Reset
    .clk                            (clk                            ),
    .rst                            (rst                            )
);

// Network Operation Checking Unit
sentry_checking NET_CHK (
    // Incoming Untrusted Host Result
    .result_select                  (result_net_select[i]           ),
    .host_result                    (host_result[i]                 ),
    .host_tag                       (host_tag[i]                    ),
    // Incoming Function Unit Result
    .fu_ready                       (net_get_done[i]                ),
    .fu_result                      (net_get_data                   ),
    // Outgoing Checked Correct Tag
    .tag                            (net_tag[i]                     ), 
    .tag_valid                      (net_tag_valid[i]               ),
    .tag_clear                      (net_tag_clear[i]               ),
    // Invalid and Stall signals
    .invalid                        (net_invalid[i]                 ),
    .ready                          (net_check_ready[i]             ),
    // Clock and Reset
    .clk                            (clk                            ),
    .rst                            (rst                            )
);

// Bypass Tag FIFO
tag_fifo  BYPASS_TAG_FIFO (
    .clk                            (clk                            ),  // input wire clk
    .din                            (bypass_tag_fifo_input[i]       ),  // input wire [31 : 0] din
    .wr_en                          (bypass_tag_fifo_wr_en[i]       ),  // input wire wr_en
    .rd_en                          (bypass_tag_fifo_rd_en[i]       ),  // input wire rd_en
    .dout                           (bypass_tag_fifo_output[i]      ),  // output wire [31 : 0] dout
    .full                           (bypass_tag_fifo_full[i]        ),  // output wire full
    .empty                          (bypass_tag_fifo_empty[i]       ),  // output wire empty
    .almost_full                    (bypass_tag_fifo_almost_full[i] ),  // output wire almost_full
    .almost_empty                   (bypass_tag_fifo_almost_empty[i]),  // output wire almost_empty
    `ifdef DATA_COUNT
        .data_count                     (bypass_tag_fifo_data_count[i]  ),  // output wire [9 : 0] data_count
    `endif
    .srst                           (rst                            )   // input wire srst
);
assign bypass_tag_fifo_wr_en[i] = result_bypass_select[i];
assign bypass_tag_fifo_input[i] = host_tag[i];
assign bypass_tag[i]            = bypass_tag_fifo_output[i];
assign bypass_tag_valid[i]      = !bypass_tag_fifo_empty[i];
assign bypass_tag_fifo_rd_en[i] = bypass_tag_clear[i];
assign bypass_check_ready[i]    = !bypass_tag_fifo_almost_full[i];
end
endgenerate


// ******************************************************
// Memory Subsystem Parallel Version (Dcache/Victim CAM)
// ******************************************************
`ifdef PARALLEL_DCACHE
    // Data Cache Contrl Unit
    sentry_dcache_ctrl DC_CTRL (
        // Control Signals from Decode Stage
        .cache_ens          (cache_ens          ),   
        .cache_evicts       (cache_evicts       ),   
        .cache_wr_en_byte   (cache_wr_en_byte   ),   
        .cache_wr_addr      (cache_wr_addr      ),  
        .cache_wr_line      (cache_wr_line      ),  
        // Vicitm Line Updates
        .victim_byte_sel    (victim_byte_sel    ),
        .victim_hword_sel   (victim_hword_sel   ),
        .victim_word_sel    (victim_word_sel    ),
        .victim_dword_sel   (victim_dword_sel   ),
        .victim_qword_sel   (victim_qword_sel   ),
        .victim_byte_write  (victim_byte_write  ),
        .victim_hword_write (victim_hword_write ),
        .victim_word_write  (victim_word_write  ),
        .victim_dword_write (victim_dword_write ),
        .victim_write_byte  (victim_write_byte  ),
        .victim_write_hword (victim_write_hword ),
        .victim_write_word  (victim_write_word  ),
        .victim_write_dword (victim_write_dword ),
        // Cache Read Control
        .cache_rd_addr      (cache_rd_addr      ),  
        .cache_rd_line      (cache_rd_line      ),  
        // Cache fill from Victim CAM
        .victim_cam_en      (victim_cam_en      ),
        .victim_cam_line    (victim_cam_line    ),
        // Cache parallel eviction
        .cache_evicted      (cache_evicted      ),
        .cache_evict_line   (cache_evict_line   ),
        `ifdef SMAC
            .cache_evict_smac   (cache_evict_smac   ),
        `endif
        // clock and reset
        .clk                (clk                ),
        .rst                (rst                )
    );

    sentry_victim_cam #(
        .ADDR_WIDTH         (`CAM_ADDR_WIDTH    )
    )
    SENTRY_VICTIM_CAM (
        // Cache parallel eviction
        .cache_evicted      (cache_evicted      ),
        .cache_evict_line   (cache_evict_line   ),
        // Cache victim read back
        .victim_cam_index   (victim_cam_index   ),
        .victim_cam_line    (victim_cam_line    ),
        // clock and reset
        .clk                (clk                ),
        .rst                (rst                )
    );

    // ************************************************************************
    // Victim Data FIFO is the path for evicted cache lines to go back to sentry control
    // It is here delayed 1 cycle to synchronize onto clock edge
    // ************************************************************************

    //assign victim_data_fifo1_wr_en = cache_evicted != `SENTRY_WIDTH'd0;
    always @(posedge clk) begin
        victim_data_fifo1_wr_en <= cache_evicted != `SENTRY_WIDTH'd0;
    end

    generate
    for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: VICTIM_BUFFER_STAGE_0
        //`ifdef SMAC
        //    assign victim_data_fifo1_input[i] = {cache_evicted[i], cache_evict_line[i], cache_evict_smac[i]};
        //`else
        //    assign victim_data_fifo1_input[i] = {cache_evicted[i], cache_evict_line[i], `SMAC_WIDTH'd0};
        //`endif
    always @(posedge clk) begin
        `ifdef SMAC
            victim_data_fifo1_input[i] <= {cache_evicted[i], cache_evict_line[i], cache_evict_smac[i]};
        `else
            victim_data_fifo1_input[i] <= {cache_evicted[i], cache_evict_line[i], `SMAC_WIDTH'd0};
        `endif
    end

    // victim data fifo before 4-to-1 gear box
    victim_data_fifo1 VICTIM_DATA_FIFO1_1 (
        .wr_clk         (clk                                ),  // input wire wr_clk
        .rd_clk         (gearbox_clk                        ),  // input wire rd_clk
        .din            (victim_data_fifo1_input[i]         ),  // input wire [641 : 0] din
        .wr_en          (victim_data_fifo1_wr_en            ),  // input wire wr_en
        .rd_en          (victim_data_fifo1_rd_en            ),  // input wire rd_en
        .dout           (victim_data_fifo1_output[i]        ),  // output wire [275 : 0] dout
        .full           (victim_data_fifo1_full[i]          ),  // output wire full
        .empty          (victim_data_fifo1_empty[i]         ),  // output wire empty
        .almost_full    (victim_data_fifo1_almost_full[i]   ),  // output wire almost full
        .almost_empty   (victim_data_fifo1_almost_empty[i]  ),  // output wire almost empty
        `ifdef DATA_COUNT
            .wr_data_count  (victim_data_fifo1_wr_data_count[i] ),  // output wire [9 :0] wr_data_count
            .rd_data_count  (victim_data_fifo1_rd_data_count[i] ),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst                                )   // input wire rst
    );

end
endgenerate

// Victim Buffer 4-to-1 gear box
four_one_gearbox #(
    .INT_WIDTH      (`LINE_WIDTH+`SMAC_WIDTH+1      )
)
VICTIM_BUFFER_GEAR_BOX (
    .clk            (gearbox_clk                    ),
    .rst            (rst                            ),
    .input_empty    (|victim_data_fifo1_empty       ),  // use almost empty because rd_en is registerd on output
    .input_four     ({victim_data_fifo1_output[0], victim_data_fifo1_output[1], victim_data_fifo1_output[2], victim_data_fifo1_output[3]}   ),
    .input_rd_en    (victim_data_fifo1_rd_en        ),
    .output_full    (victim_data_fifo2_prog_full    ),
    .output_one     (victim_data_fifo2_input        ),
    .output_wr_en   (victim_data_fifo2_wr_en        )
);

// victim data fifo after 4-to-1 gear box
victim_data_fifo2 VICTIM_DATA_FIFO2 (
    .wr_clk         (gearbox_clk                    ),  // input wire wr_clk
    .rd_clk         (clk                            ),  // input wire rd_clk
    .din            (victim_data_fifo2_input        ),  // input wire [68 : 0] din
    .wr_en          (victim_data_fifo2_wr_en        ),  // input wire wr_en
    .rd_en          (victim_data_fifo2_rd_en        ),  // input wire rd_en
    .dout           (victim_data_fifo2_output       ),  // output wire [68 : 0] dout
    .full           (victim_data_fifo2_full         ),  // output wire full
    .empty          (victim_data_fifo2_empty        ),  // output wire empty
    .almost_full    (victim_data_fifo2_almost_full  ),  // output wire almost full
    .almost_empty   (victim_data_fifo2_almost_empty ),  // output wire almost empty
    .prog_full      (victim_data_fifo2_prog_full    ),  // output wire almost full
    `ifdef DATA_COUNT
        .wr_data_count  (victim_data_fifo2_wr_data_count),  // output wire [9 :0] wr_data_count
        .rd_data_count  (victim_data_fifo2_rd_data_count),  // output wire [9 :0] rd_data_count
    `endif
    .rst            (rst                            )   // input wire rst
);

// interface to victim data buffer
assign victim_data_fifo_wr_en = !victim_data_fifo2_empty;
assign victim_data_fifo2_rd_en = victim_data_fifo_wr_en;
assign victim_data_fifo_input.line = victim_data_fifo2_output[`SMAC_WIDTH+:`LINE_WIDTH];
assign victim_data_fifo_input.smac = victim_data_fifo2_output[0+:`SMAC_WIDTH];
// the full signal are't necessary because the victim_addr_fifo would've 
// filled up first and applied back pressure earlier in the processing pipeline


// ******************************************************
// Memory Subsystem Sequential Version (Dcache/Victim CAM)
// ******************************************************
`else
        // Output Interface to 4-to-4 Filter Gearbox
        //.dcache_ctrl_req_fifo_full          (dcache_ctrl_req_fifo_full          ),
        //.dcache_ctrl_req_fifo_almost_full   (dcache_ctrl_req_fifo_almost_full   ),
        //.dcache_ctrl_req_fifo_prog_full     (dcache_ctrl_req_fifo_prog_full     ),
        //.dcache_ctrl_req_fifo_wr_en         (dcache_ctrl_req_fifo_wr_en[i]      ),
        //.dcache_ctrl_req_fifo_input         (dcache_ctrl_req_fifo_input[i]      ),
    //
    wire [`SENTRY_WIDTH-1:0]                            dcache_ctrl_filter_gearbox_output_valid;
    wire [`SENTRY_WIDTH*$bits(dcache_ctrl_req_t)-1:0]   dcache_ctrl_filter_gearbox_output_data;     // 4 * $bits(dcache_ctrl_req_t) bits
    wire [`SENTRY_WIDTH*32-1:0]                         dcache_ctrl_filter_gearbox_output_metadata; // 4 * 32 bits

    four_four_filter_gearbox #(
        .INT_WIDTH          ($bits(dcache_ctrl_req_t)       ),
        .IDLE_FLUSH         (0                              )
    )
    DCACHE_FILTER_GEAR_BOX (
        .input_inst_valid   (dcache_ctrl_req_fifo_wr_en == 4'hf      ),
        .input_valid        ({dcache_ctrl_req_wr_en[3], 
                              dcache_ctrl_req_wr_en[2],
                              dcache_ctrl_req_wr_en[1], 
                              dcache_ctrl_req_wr_en[0]}),

        .input_data         ({dcache_ctrl_req_input[3],
                              dcache_ctrl_req_input[2],
                              dcache_ctrl_req_input[1],
                              dcache_ctrl_req_input[0]}),

        .output_full        (),
        .output_prog_full   (),
        .output_valid       (dcache_ctrl_filter_gearbox_output_valid    ),
        .output_data        (dcache_ctrl_filter_gearbox_output_data     ),
        .output_metadata    (dcache_ctrl_filter_gearbox_output_metadata ),
        .clk                (clk                                        ),
        .rst                (rst                                        )
    );

    assign dcache_ctrl_req_fifo_input = dcache_ctrl_filter_gearbox_output_data;
    wire [1024-$bits(dcache_ctrl_req_t)-1:0] split_fill = 'd0;
    // Input splitting among 4 max sized FIFOs
    assign dcache_ctrl_req_fifo_input_split1 = {split_fill, dcache_ctrl_req_fifo_input[3][$bits(dcache_ctrl_req_t)-1:768],
                                                split_fill, dcache_ctrl_req_fifo_input[2][$bits(dcache_ctrl_req_t)-1:768],
                                                split_fill, dcache_ctrl_req_fifo_input[1][$bits(dcache_ctrl_req_t)-1:768],
                                                split_fill, dcache_ctrl_req_fifo_input[0][$bits(dcache_ctrl_req_t)-1:768]};
    assign dcache_ctrl_req_fifo_input_split2 = {dcache_ctrl_req_fifo_input[3][767:512],
                                                dcache_ctrl_req_fifo_input[2][767:512],
                                                dcache_ctrl_req_fifo_input[1][767:512],
                                                dcache_ctrl_req_fifo_input[0][767:512]};
    assign dcache_ctrl_req_fifo_input_split3 = {dcache_ctrl_req_fifo_input[3][511:256],
                                                dcache_ctrl_req_fifo_input[2][511:256],
                                                dcache_ctrl_req_fifo_input[1][511:256],
                                                dcache_ctrl_req_fifo_input[0][511:256]};
    assign dcache_ctrl_req_fifo_input_split4 = {dcache_ctrl_req_fifo_input[3][255:  0],
                                                dcache_ctrl_req_fifo_input[2][255:  0],
                                                dcache_ctrl_req_fifo_input[1][255:  0],
                                                dcache_ctrl_req_fifo_input[0][255:  0]};

    assign dcache_ctrl_req_fifo_wr_en = dcache_ctrl_filter_gearbox_output_valid == 4'hf;
    // Input Enable splitting among 4 max sized FIFOs
    assign dcache_ctrl_req_fifo_wr_en_split1 = dcache_ctrl_req_fifo_wr_en;
    assign dcache_ctrl_req_fifo_wr_en_split2 = dcache_ctrl_req_fifo_wr_en;
    assign dcache_ctrl_req_fifo_wr_en_split3 = dcache_ctrl_req_fifo_wr_en;
    assign dcache_ctrl_req_fifo_wr_en_split4 = dcache_ctrl_req_fifo_wr_en;
    assign dcache_ctrl_req_fifo_rd_en_split1 = dcache_ctrl_req_fifo_rd_en;
    assign dcache_ctrl_req_fifo_rd_en_split2 = dcache_ctrl_req_fifo_rd_en;
    assign dcache_ctrl_req_fifo_rd_en_split3 = dcache_ctrl_req_fifo_rd_en;
    assign dcache_ctrl_req_fifo_rd_en_split4 = dcache_ctrl_req_fifo_rd_en;

    // FIFO Status Signal Merging from Split
    assign dcache_ctrl_req_fifo_full            = dcache_ctrl_req_fifo_full_split1;
    assign dcache_ctrl_req_fifo_almost_full     = dcache_ctrl_req_fifo_almost_full_split1;
    assign dcache_ctrl_req_fifo_prog_full       = dcache_ctrl_req_fifo_prog_full_split1;
    assign dcache_ctrl_req_fifo_empty           = dcache_ctrl_req_fifo_empty_split1;
    assign dcache_ctrl_req_fifo_almost_empty    = dcache_ctrl_req_fifo_almost_empty_split1;
    `ifdef DATA_COUNT
        assign dcache_ctrl_req_fifo_wr_data_count = dcache_ctrl_req_fifo_wr_data_count_split1;
        assign dcache_ctrl_req_fifo_rd_data_count = dcache_ctrl_req_fifo_rd_data_count_split1;
    `endif

    assign dcache_ctrl_req_fifo_output = {dcache_ctrl_req_fifo_output_split1[$bits(dcache_ctrl_req_t)-1-768:0],
                                          dcache_ctrl_req_fifo_output_split2,
                                          dcache_ctrl_req_fifo_output_split3,
                                          dcache_ctrl_req_fifo_output_split4};

    // 4-to-1 data cache access request fifo after 4-to-1 gear box
    // Native FIFO width limited to 1024 bits for Xilinx IP
    // need to use multiple 1024 bit FIFOs for splitting
    async_fifo_1024 DCACHE_CTRL_REQ_FIFO_SPLIT1 (
        .wr_clk         (clk                                        ),  // input wire wr_clk
        .rd_clk         (dcache_clk                                 ),  // input wire rd_clk
        .din            (dcache_ctrl_req_fifo_input_split1          ),  // input wire [68 : 0] din
        .wr_en          (dcache_ctrl_req_fifo_wr_en_split1          ),  // input wire wr_en
        .rd_en          (dcache_ctrl_req_fifo_rd_en_split1          ),  // input wire rd_en
        .dout           (dcache_ctrl_req_fifo_output_split1         ),  // output wire [68 : 0] dout
        .full           (dcache_ctrl_req_fifo_full_split1           ),  // output wire full
        .empty          (dcache_ctrl_req_fifo_empty_split1          ),  // output wire empty
        .almost_full    (dcache_ctrl_req_fifo_almost_full_split1    ),  // output wire almost full
        .almost_empty   (dcache_ctrl_req_fifo_almost_empty_split1   ),  // output wire almost empty
        .prog_full      (dcache_ctrl_req_fifo_prog_full_split1      ),
        `ifdef DATA_COUNT
            .wr_data_count  (dcache_ctrl_req_fifo_wr_data_count_split1  ),  // output wire [9 :0] wr_data_count
            .rd_data_count  (dcache_ctrl_req_fifo_rd_data_count_split1  ),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst                                        )   // input wire rst
    );
    async_fifo_1024 DCACHE_CTRL_REQ_FIFO_SPLIT2 (
        .wr_clk         (clk                                        ),  // input wire wr_clk
        .rd_clk         (dcache_clk                                 ),  // input wire rd_clk
        .din            (dcache_ctrl_req_fifo_input_split2          ),  // input wire [68 : 0] din
        .wr_en          (dcache_ctrl_req_fifo_wr_en_split2          ),  // input wire wr_en
        .rd_en          (dcache_ctrl_req_fifo_rd_en_split2          ),  // input wire rd_en
        .dout           (dcache_ctrl_req_fifo_output_split2         ),  // output wire [68 : 0] dout
        .full           (dcache_ctrl_req_fifo_full_split2           ),  // output wire full
        .empty          (dcache_ctrl_req_fifo_empty_split2          ),  // output wire empty
        .almost_full    (dcache_ctrl_req_fifo_almost_full_split2    ),  // output wire almost full
        .almost_empty   (dcache_ctrl_req_fifo_almost_empty_split2   ),  // output wire almost empty
        .prog_full      (dcache_ctrl_req_fifo_prog_full_split2      ),
        `ifdef DATA_COUNT
            .wr_data_count  (dcache_ctrl_req_fifo_wr_data_count_split2  ),  // output wire [9 :0] wr_data_count
            .rd_data_count  (dcache_ctrl_req_fifo_rd_data_count_split2  ),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst                                        )   // input wire rst
    );
    async_fifo_1024 DCACHE_CTRL_REQ_FIFO_SPLIT3 (
        .wr_clk         (clk                                        ),  // input wire wr_clk
        .rd_clk         (dcache_clk                                 ),  // input wire rd_clk
        .din            (dcache_ctrl_req_fifo_input_split3          ),  // input wire [68 : 0] din
        .wr_en          (dcache_ctrl_req_fifo_wr_en_split3          ),  // input wire wr_en
        .rd_en          (dcache_ctrl_req_fifo_rd_en_split3          ),  // input wire rd_en
        .dout           (dcache_ctrl_req_fifo_output_split3         ),  // output wire [68 : 0] dout
        .full           (dcache_ctrl_req_fifo_full_split3           ),  // output wire full
        .empty          (dcache_ctrl_req_fifo_empty_split3          ),  // output wire empty
        .almost_full    (dcache_ctrl_req_fifo_almost_full_split3    ),  // output wire almost full
        .almost_empty   (dcache_ctrl_req_fifo_almost_empty_split3   ),  // output wire almost empty
        .prog_full      (dcache_ctrl_req_fifo_prog_full_split3      ),
        `ifdef DATA_COUNT
            .wr_data_count  (dcache_ctrl_req_fifo_wr_data_count_split3  ),  // output wire [9 :0] wr_data_count
            .rd_data_count  (dcache_ctrl_req_fifo_rd_data_count_split3  ),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst                                        )   // input wire rst
    );
    async_fifo_1024 DCACHE_CTRL_REQ_FIFO_SPLIT4 (
        .wr_clk         (clk                                        ),  // input wire wr_clk
        .rd_clk         (dcache_clk                                 ),  // input wire rd_clk
        .din            (dcache_ctrl_req_fifo_input_split4          ),  // input wire [68 : 0] din
        .wr_en          (dcache_ctrl_req_fifo_wr_en_split4          ),  // input wire wr_en
        .rd_en          (dcache_ctrl_req_fifo_rd_en_split4          ),  // input wire rd_en
        .dout           (dcache_ctrl_req_fifo_output_split4         ),  // output wire [68 : 0] dout
        .full           (dcache_ctrl_req_fifo_full_split4           ),  // output wire full
        .empty          (dcache_ctrl_req_fifo_empty_split4          ),  // output wire empty
        .almost_full    (dcache_ctrl_req_fifo_almost_full_split4    ),  // output wire almost full
        .almost_empty   (dcache_ctrl_req_fifo_almost_empty_split4   ),  // output wire almost empty
        .prog_full      (dcache_ctrl_req_fifo_prog_full_split4      ),
        `ifdef DATA_COUNT
            .wr_data_count  (dcache_ctrl_req_fifo_wr_data_count_split4  ),  // output wire [9 :0] wr_data_count
            .rd_data_count  (dcache_ctrl_req_fifo_rd_data_count_split4  ),  // output wire [9 :0] rd_data_count
        `endif
        .rst            (rst                                        )   // input wire rst
    );


    //dcache_ctrl_req_fifo DCACHE_CTRL_REQ_FIFO (
    //    .wr_clk         (clk                                ),  // input wire wr_clk
    //    .rd_clk         (dcache_clk                         ),  // input wire rd_clk
    //    .din            (dcache_ctrl_req_fifo_input         ),  // input wire [68 : 0] din
    //    .wr_en          (dcache_ctrl_req_fifo_wr_en         ),  // input wire wr_en
    //    .rd_en          (dcache_ctrl_req_fifo_rd_en         ),  // input wire rd_en
    //    .dout           (dcache_ctrl_req_fifo_output        ),  // output wire [68 : 0] dout
    //    .full           (dcache_ctrl_req_fifo_full          ),  // output wire full
    //    .empty          (dcache_ctrl_req_fifo_empty         ),  // output wire empty
    //    .almost_full    (dcache_ctrl_req_fifo_almost_full   ),  // output wire almost full
    //    .almost_empty   (dcache_ctrl_req_fifo_almost_empty  ),  // output wire almost empty
    //    .prog_full      (dcache_ctrl_req_fifo_prog_full     ),
    //    `ifdef DATA_COUNT
    //        .wr_data_count  (dcache_ctrl_req_fifo_wr_data_count ),  // output wire [9 :0] wr_data_count
    //        .rd_data_count  (dcache_ctrl_req_fifo_rd_data_count ),  // output wire [9 :0] rd_data_count
    //    `endif
    //    .rst            (rst                                    )   // input wire rst
    //);

    // Data Cache Contrl Unit
    sentry_dcache_ctrl_sequential DC_CTRL_SEQUENTIAL (
        // Control Signals from LSU Stage, 4-to-4 Filter Gearbox and 4-to-1 asymmetric FIFO
        .dcache_ctrl_req_fifo_empty     (dcache_ctrl_req_fifo_empty     ), // req fifo not empty
        .dcache_ctrl_req_fifo_output    (dcache_ctrl_req_fifo_output    ),
        .dcache_ctrl_req_fifo_rd_en     (dcache_ctrl_req_fifo_rd_en     ), // req fifo not empty
        // Cache fill from Victim CAM
        .victim_cam_index               (victim_cam_index               ),
        .victim_cam_line                (victim_cam_line                ),
        // Cache parallel eviction
        .cache_evicted                  (cache_evicted                  ),
        .cache_evict_line               (cache_evict_line               ),
        `ifdef SMAC
            .cache_evict_smac           (cache_evict_smac               ),
        `endif
        // Result Signals to Checking Stage
        .check_mem_ready                (check_mem_ready                ),  
        .check_mem_out                  (check_mem_out_sequential       ),  
        // clock and reset
        .clk                            (dcache_clk                     ),
        .rst                            (rst                            )
    );

    // Fan Out of Sequential Check Memory Outs
    generate
    for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: CHECK_MEM_OUTS
        assign check_mem_out[i] = check_mem_out_sequential;
    end
    endgenerate

    sentry_victim_cam_sequential #(
        .ADDR_WIDTH         (`CAM_ADDR_WIDTH    )
    )
    SENTRY_VICTIM_CAM_SEQUENTIAL (
        // Cache parallel eviction
        .cache_evicted      (cache_evicted      ),
        .cache_evict_line   (cache_evict_line   ),
        // Cache victim read back
        .victim_cam_index   (victim_cam_index   ),
        .victim_cam_line    (victim_cam_line    ),
        // clock and reset
        .clk                (dcache_clk         ),
        .rst                (rst                )
    );

    // victim data fifo interface
    //output                              victim_data_fifo_wr_en,
    //output victim_data_t                victim_data_fifo_input,
    //input                               victim_data_fifo_full, 
    //input                               victim_data_fifo_almost_full, 
    assign victim_data_fifo_wr_en = cache_evicted;
    `ifdef SMAC
        assign victim_data_fifo_input = {cache_evict_line, cache_evict_smac};
    `else
        assign victim_data_fifo_input = {cache_evict_line, `SMAC_WIDTH'd0};
    `endif
    
`endif


// ***************************************
// Output Gate (POB/Network Buffer)
// ***************************************

// Network Get Request Queues (Pending Incoming Buffer)
assign net_get_req_fifo1_input = {net_get_req[0], net_get_tag[0], net_get_req[1], net_get_tag[1],
net_get_req[2], net_get_tag[2], net_get_req[3], net_get_tag[3]};

assign net_get_req_fifo1_wr_en = net_get_req != `SENTRY_WIDTH'd0;
// TODO, network request fifo almost full signal need to 
// hook back into operand routing to apply back pressure

// network get request fifo before 4-to-1 gear box ( 4*(32+1) = 132 bits )
net_get_req_fifo1 NET_GET_REQ_FIFO1 (
    .wr_clk         (clk                            ),  // input wire wr_clk
    .rd_clk         (gearbox_clk                    ),  // input wire rd_clk
    .din            (net_get_req_fifo1_input        ),  // input wire [131: 0] din
    .wr_en          (net_get_req_fifo1_wr_en        ),  // input wire wr_en
    .rd_en          (net_get_req_fifo1_rd_en        ),  // input wire rd_en
    .dout           (net_get_req_fifo1_output       ),  // output wire [131: 0] dout
    .full           (net_get_req_fifo1_full         ),  // output wire full
    .empty          (net_get_req_fifo1_empty        ),  // output wire empty
    .almost_full    (net_get_req_fifo1_almost_full  ),  // output wire almost full
    .almost_empty   (net_get_req_fifo1_almost_empty ),  // output wire almost empty
    `ifdef DATA_COUNT
        .wr_data_count  (net_get_req_fifo1_wr_data_count),  // output wire [9 :0] wr_data_count
        .rd_data_count  (net_get_req_fifo1_rd_data_count),  // output wire [9 :0] rd_data_count
    `endif
    .rst            (rst                            )   // input wire rst
);

// Network Get 4-to-1 gear box
four_one_gearbox #(
    .INT_WIDTH      ($bits(tag_t)+1                 )
)
NET_GET_REQUEST_GEAR_BOX (
    .clk            (gearbox_clk                    ),
    .rst            (rst                            ),
    .input_empty    (net_get_req_fifo1_empty        ),  // use almost empty because rd_en is registerd on output
    .input_four     (net_get_req_fifo1_output       ),
    .input_rd_en    (net_get_req_fifo1_rd_en        ),
    .output_full    (net_get_req_fifo2_prog_full    ),
    .output_one     (net_get_req_fifo2_input        ),
    .output_wr_en   (net_get_req_fifo2_wr_en        )
);

// network get request fifo after 4-to-1 gear box (32 + 32 = 64 bits)
net_get_req_fifo2 NET_GET_REQ_FIFO2 (
    .wr_clk         (gearbox_clk                    ),  // input wire wr_clk
    .rd_clk         (clk                            ),  // input wire rd_clk
    .din            (net_get_req_fifo2_input        ),  // input wire [63 : 0] din
    .wr_en          (net_get_req_fifo2_wr_en        ),  // input wire wr_en
    .rd_en          (net_get_req_fifo2_rd_en        ),  // input wire rd_en
    .dout           (net_get_req_fifo2_output       ),  // output wire [63 : 0] dout
    .full           (net_get_req_fifo2_full         ),  // output wire full
    .empty          (net_get_req_fifo2_empty        ),  // output wire empty
    .almost_full    (net_get_req_fifo2_almost_full  ),  // output wire almost full
    .almost_empty   (net_get_req_fifo2_almost_empty ),  // output wire almost empty
    .prog_full      (net_get_req_fifo2_prog_full    ),  // output wire almost full
    `ifdef DATA_COUNT
        .wr_data_count  (net_get_req_fifo2_wr_data_count),  // output wire [9 :0] wr_data_count
        .rd_data_count  (net_get_req_fifo2_rd_data_count),  // output wire [9 :0] rd_data_count
    `endif
    .rst            (rst                            )   // input wire rst
);

// Network Put Request Queues (Pending Output Buffer)
assign net_put_req_fifo1_input = {net_put_req[0], net_put_pkt[0], net_put_req[1], net_put_pkt[1],
net_put_req[2], net_put_pkt[2], net_put_req[3], net_put_pkt[3]};

assign net_put_req_fifo1_wr_en = net_put_req != `SENTRY_WIDTH'd0;

// network put request fifo before 4-to-1 gear box ( 4*(1+64+32) = 388 bits )
net_put_req_fifo1 NET_PUT_REQ_FIFO1 (
    .wr_clk         (clk                            ),  // input wire wr_clk
    .rd_clk         (gearbox_clk                    ),  // input wire rd_clk
    .din            (net_put_req_fifo1_input        ),  // input wire [387: 0] din
    .wr_en          (net_put_req_fifo1_wr_en        ),  // input wire wr_en
    .rd_en          (net_put_req_fifo1_rd_en        ),  // input wire rd_en
    .dout           (net_put_req_fifo1_output       ),  // output wire [387: 0] dout
    .full           (net_put_req_fifo1_full         ),  // output wire full
    .empty          (net_put_req_fifo1_empty        ),  // output wire empty
    .almost_full    (net_put_req_fifo1_almost_full  ),  // output wire almost full
    .almost_empty   (net_put_req_fifo1_almost_empty ),  // output wire almost empty
    `ifdef DATA_COUNT
        .wr_data_count  (net_put_req_fifo1_wr_data_count),  // output wire [9 :0] wr_data_count
        .rd_data_count  (net_put_req_fifo1_rd_data_count),  // output wire [9 :0] rd_data_count
    `endif
    .rst            (rst                            )   // input wire rst
);

// Network Put 4-to-1 gear box
four_one_gearbox #(
    .INT_WIDTH      ($bits(tag_result_t)+1          )
)
NET_PUT_REQUEST_GEAR_BOX (
    .clk            (gearbox_clk                    ),
    .rst            (rst                            ),
    .input_empty    (net_put_req_fifo1_empty        ),  // use almost empty because rd_en is registerd on output
    .input_four     (net_put_req_fifo1_output       ),
    .input_rd_en    (net_put_req_fifo1_rd_en        ),
    .output_full    (net_put_req_fifo2_prog_full    ),
    .output_one     (net_put_req_fifo2_input        ),
    .output_wr_en   (net_put_req_fifo2_wr_en        )
);

// network put request fifo after 4-to-1 gear box ( 32 + 32 + 64 = 128 bits )
net_put_req_fifo2 NET_PUT_REQ_FIFO2 (
    .wr_clk         (gearbox_clk                    ),  // input wire wr_clk
    .rd_clk         (clk                            ),  // input wire rd_clk
    .din            (net_put_req_fifo2_input        ),  // input wire [68 : 0] din
    .wr_en          (net_put_req_fifo2_wr_en        ),  // input wire wr_en
    .rd_en          (net_put_req_fifo2_rd_en        ),  // input wire rd_en
    .dout           (net_put_req_fifo2_output       ),  // output wire [68 : 0] dout
    .full           (net_put_req_fifo2_full         ),  // output wire full
    .empty          (net_put_req_fifo2_empty        ),  // output wire empty
    .almost_full    (net_put_req_fifo2_almost_full  ),  // output wire almost full
    .almost_empty   (net_put_req_fifo2_almost_empty ),  // output wire almost empty
    .prog_full      (net_put_req_fifo2_prog_full    ),  // output wire almost full
    `ifdef DATA_COUNT
        .wr_data_count  (net_put_req_fifo2_wr_data_count),  // output wire [9 :0] wr_data_count
        .rd_data_count  (net_put_req_fifo2_rd_data_count),  // output wire [9 :0] rd_data_count
    `endif
    .rst            (rst                            )   // input wire rst
);

// Pending Output Control (Check Instruction Tag based output gate)
sentry_pob PENDING_OUTPUT_BUF (
    // ALU Resolved Tag
    .alu_tag                            (alu_tag                                            ), 
    .alu_tag_valid                      (alu_tag_valid                                      ),
    .alu_tag_clear                      (alu_tag_clear                                      ),
    // MD Resolved Tag
    .md_tag                             (md_tag                                             ), 
    .md_tag_valid                       (md_tag_valid                                       ),
    .md_tag_clear                       (md_tag_clear                                       ),
    // Memory Resolved Tag
    .mem_tag                            (mem_tag                                            ), 
    .mem_tag_valid                      (mem_tag_valid                                      ),
    .mem_tag_clear                      (mem_tag_clear                                      ),
    // Network Resolved Tag
    .net_tag                            (net_tag                                            ), 
    .net_tag_valid                      (net_tag_valid                                      ),
    .net_tag_clear                      (net_tag_clear                                      ),
    // Bypass Resolved Tag
    .bypass_tag                         (bypass_tag                                         ), 
    .bypass_tag_valid                   (bypass_tag_valid                                   ),
    .bypass_tag_clear                   (bypass_tag_clear                                   ),
    // Read Interface from Sentry Network PUT Request Queue
    .net_put_req_fifo_empty             (net_put_req_fifo2_empty                            ), 
    .net_put_req_fifo_rd_en             (net_put_req_fifo2_rd_en                            ), 
    .net_put_req_fifo_tag_result        (net_put_req_fifo2_output[$bits(tag_result_t)-1:0]  ), 
    // Write Interface to Sentry Cleared Outgoing PUT Request Queue
    .net_outgoing_req_fifo_full         (net_outgoing_req_fifo_full                         ), 
    .net_outgoing_req_fifo_almost_full  (net_outgoing_req_fifo_almost_full                  ), 
    .net_outgoing_req_fifo_wr_en        (net_outgoing_req_fifo_wr_en                        ), 
    .net_outgoing_req_fifo_input        (net_outgoing_req_fifo_input                        ), 
    // Clock and Reset
    .clk                                (clk                                                ),
    .rst                                (rst                                                )
);

// network outgoing request queues (64 bits)
net_outgoing_req_fifo NET_OUTGOING_FIFO(
    .clk            (clk                                ),  // input wire wr_clk
    .din            (net_outgoing_req_fifo_input        ),  // input wire [63  : 0] din
    .wr_en          (net_outgoing_req_fifo_wr_en        ),  // input wire wr_en
    .rd_en          (net_outgoing_req_fifo_rd_en        ),  // input wire rd_en
    .dout           (net_outgoing_req_fifo_output       ),  // output wire [63  : 0] dout
    .full           (net_outgoing_req_fifo_full         ),  // output wire full
    .empty          (net_outgoing_req_fifo_empty        ),  // output wire empty
    .almost_full    (net_outgoing_req_fifo_almost_full  ),  // output wire full
    .almost_empty   (net_outgoing_req_fifo_almost_empty ),  // output wire empty
    `ifdef DATA_COUNT
        .data_count     (net_outgoing_req_fifo_data_count   ),  // output wire [9 : 0] data_count
    `endif
    .srst           (rst                            )   // input wire rst
);

// Sentry Network Buffer
sentry_network_buffer NETWORKBUF(
    // Network Gets
    // Read Interface from Sentry Network GET Request Queue
    .net_get_req_fifo_empty         (net_get_req_fifo2_empty                        ), 
    .net_get_req_fifo_rd_en         (net_get_req_fifo2_rd_en                        ), 
    .net_get_req_fifo_tag           (net_get_req_fifo2_output[$bits(tag_t)-1:0]     ), 
    // Get Response, Write Interface to Network Checking Unit
    .net_get_done                   (net_get_done                                   ),
    .net_get_data                   (net_get_data                                   ),
    // Network Puts 
    .net_outgoing_req_fifo_empty    (net_outgoing_req_fifo_empty                    ), 
    .net_outgoing_req_fifo_rd_en    (net_outgoing_req_fifo_rd_en                    ), 
    .net_outgoing_req_fifo_output   (net_outgoing_req_fifo_output                   ), 
    // uBlaze interfaces
    // interface, data for GET
    .net_get_clk                    (net_get_clk                                    ),
    .net_get_rst                    (net_get_rst                                    ),
    .net_get_rd_en                  (net_get_rd_en                                  ),
    .net_get_wr_en                  (net_get_wr_en                                  ),
    .net_get_addr                   (net_get_addr                                   ),
    .net_get_rd_data                (net_get_rd_data                                ),
    .net_get_wr_data                (net_get_wr_data                                ),
    // interface, data for PUT
    .net_put_clk                    (net_put_clk                                    ),
    .net_put_rst                    (net_put_rst                                    ),
    .net_put_rd_en                  (net_put_rd_en                                  ),
    .net_put_wr_en                  (net_put_wr_en                                  ),
    .net_put_addr                   (net_put_addr                                   ),
    .net_put_rd_data                (net_put_rd_data                                ),
    .net_put_wr_data                (net_put_wr_data                                ),
    // Clock and Reset
    .clk                            (clk                                            ),
    .rst                            (rst                                            )
);

endmodule

