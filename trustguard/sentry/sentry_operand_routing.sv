// Sentry Operand Routing Stage
`timescale 1ns/1ps
`include "parameters.svh"
`include "encodings.svh" 
`include "alu_ops.svh" 
`include "muldiv_ops.svh" 
import TYPES::*;

module sentry_operand_routing (
    // Interface from sentry control
    // inst pkt1
    output logic [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_rd_en,
    input  pkt1_t                       inst_pkt1_fifo_output       [`SENTRY_WIDTH-1:0],
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_empty,
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_almost_empty,
    // inst pkt2
    output logic [`SENTRY_WIDTH-1:0]    inst_pkt2_fifo_rd_en,
    input  pkt2_t                       inst_pkt2_fifo_output       [`SENTRY_WIDTH-1:0],
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt2_fifo_empty,
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt2_fifo_almost_empty,
    `ifdef SMAC
        // inst pkt3
        output logic [`SENTRY_WIDTH-1:0]    inst_pkt3_fifo_rd_en,
        input  pkt3_t                       inst_pkt3_fifo_output       [`SENTRY_WIDTH-1:0],
        input  logic [`SENTRY_WIDTH-1:0]    inst_pkt3_fifo_empty,
        input  logic [`SENTRY_WIDTH-1:0]    inst_pkt3_fifo_almost_empty,
    `endif
    // data pkts side don't have rd_en because they just view
    // data pkt1
    output logic [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_rd_en,
    input  pkt1_t                       data_pkt1_fifo_output       [`SENTRY_WIDTH-1:0],
    input  logic [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_empty,
    input  logic [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_almost_empty,
    // data pkt2
    output logic [`SENTRY_WIDTH-1:0]    data_pkt2_fifo_rd_en,
    input  pkt2_t                       data_pkt2_fifo_output       [`SENTRY_WIDTH-1:0],
    input  logic [`SENTRY_WIDTH-1:0]    data_pkt2_fifo_empty,
    input  logic [`SENTRY_WIDTH-1:0]    data_pkt2_fifo_almost_empty,
    // data vpkt
    output logic [`SENTRY_WIDTH-1:0]    data_vpkt_fifo_rd_en,
    input  vpkt_t                       data_vpkt_fifo_output       [`SENTRY_WIDTH-1:0],
    input  logic [`SENTRY_WIDTH-1:0]    data_vpkt_fifo_empty,
    input  logic [`SENTRY_WIDTH-1:0]    data_vpkt_fifo_almost_empty,
    `ifdef SMAC
    // data pkt3
        input  pkt3_t                       data_pkt3_fifo_output       [`SENTRY_WIDTH-1:0],
        input  logic [`SENTRY_WIDTH-1:0]    data_pkt3_fifo_empty,
        input  logic [`SENTRY_WIDTH-1:0]    data_pkt3_fifo_almost_empty,
    `endif
    // data pkt2 fifo (round-robin)
    output pkt1_t                       lsu_pkt1_fifo_input         [`SENTRY_WIDTH-1:0],
    output logic [`SENTRY_WIDTH-1:0]    lsu_pkt1_fifo_wr_en,
    input  logic [`SENTRY_WIDTH-1:0]    lsu_pkt1_fifo_full,
    input  logic [`SENTRY_WIDTH-1:0]    lsu_pkt1_fifo_almost_full,
    // interface to data_vpkt_fifo
    output vpkt_t                       lsu_vpkt_fifo_input         [`SENTRY_WIDTH-1:0],
    output logic [`SENTRY_WIDTH-1:0]    lsu_vpkt_fifo_wr_en,
    input  logic [`SENTRY_WIDTH-1:0]    lsu_vpkt_fifo_full,
    input  logic [`SENTRY_WIDTH-1:0]    lsu_vpkt_fifo_almost_full,
    // data pkt2 fifo (round-robin)
    output pkt2_t                       lsu_pkt2_fifo_input         [`SENTRY_WIDTH-1:0],
    output logic [`SENTRY_WIDTH-1:0]    lsu_pkt2_fifo_wr_en,
    input  logic [`SENTRY_WIDTH-1:0]    lsu_pkt2_fifo_full,
    input  logic [`SENTRY_WIDTH-1:0]    lsu_pkt2_fifo_almost_full,
    // Interface to Decode Stage
    output logic [`SENTRY_WIDTH-1:0]    pipe_valid,
    output addr_t                       issue_PC                    [`SENTRY_WIDTH-1:0],
    output inst_t                       issue_instruction           [`SENTRY_WIDTH-1:0],
    output data_t                       issue_result                [`SENTRY_WIDTH-1:0],
    output tag_t                        issue_tag                   [`SENTRY_WIDTH-1:0],
    // Functional Unit Back Pressure
    input  logic [`SENTRY_WIDTH-1:0]    functional_unit_ready,
    input  logic [`SENTRY_WIDTH-1:0]    check_unit_ready,
    `ifdef DCACHE_OPT
        // LSU Enable FIFO Interface
        output logic [`SENTRY_WIDTH-1:0]    lsu_enable_fifo_input,
        output logic                        lsu_enable_fifo_wr_en,
        input  logic                        lsu_enable_fifo_full,
        input  logic                        lsu_enable_fifo_almost_full,
        input  logic                        lsu_enable_fifo_prog_full,
    `endif
    // sentry clock and reset
    input  logic                        clk,
    input  logic                        rst
);

localparam MEMD     = `ISETS        ; // memory depth
localparam DATAW    = `LINE_WIDTH   ; // data width
localparam nRPORTS  = `SENTRY_WIDTH ; // number of reading ports
localparam nWPORTS  = `SENTRY_WIDTH ; // number of writing ports
localparam WAW      = 1             ; // WAW (Write-After-Write ) protection
localparam WDW      = 0             ; // WDW (Write-During-Write) protection
localparam RAW      = 1             ; // RAW (Read-After-Write  ) protection
localparam RDW      = 1             ; // RDW (Read-During-Write ) protection
localparam BYP      = RDW ? "RDW" : (RAW ? "RAW" : (WAW ? "WAW" : "NON"));

genvar i, j;

// pipeline request valid
reg  [`SENTRY_WIDTH-1:0]    inst_valid;
wire [`SENTRY_WIDTH-1:0]    ready_to_issue;

// instruction and data and result routing
wire [`SENTRY_WIDTH-1:0]    inst_ready;
wire                        inst_frame_ready;
reg                         inst_frame_ready_reg;
data_t                      inst_result             [`SENTRY_WIDTH-1:0];
tag_t                       inst_tag                [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]    data_ready;
wire                        data_frame_ready;
reg                         data_frame_ready_reg;
inst_t                      instruction             [`SENTRY_WIDTH-1:0];
data_t                      result                  [`SENTRY_WIDTH-1:0];
tag_t                       tag                     [`SENTRY_WIDTH-1:0];

// instruction cache control
wire [`IWAYS-1:0]               wr_en               [`SENTRY_WIDTH-1:0];
wire [`I_INDEX_WIDTH-1:0]       wr_index            [`SENTRY_WIDTH-1:0];
line_t                          wr_line             [`SENTRY_WIDTH-1:0];
wire [`IWAYS-1:0]               rd_en               [`SENTRY_WIDTH-1:0];
wire [`I_INDEX_WIDTH-1:0]       rd_index            [`SENTRY_WIDTH-1:0];
line_t                          rd_line             [`SENTRY_WIDTH-1:0][`IWAYS-1:0];
wire [2:0]                      rd_hit_way          [`SENTRY_WIDTH-1:0];
reg  [2:0]                      rd_hit_way_reg      [`SENTRY_WIDTH-1:0];

// multiport ram control 
reg  [`SENTRY_WIDTH-1:0]                ram_wr_en     [`IWAYS-1:0];
reg  [`SENTRY_WIDTH*`I_INDEX_WIDTH-1:0] ram_wr_index  [`IWAYS-1:0];
reg  [`SENTRY_WIDTH*`LINE_WIDTH-1:0]    ram_wr_line   [`IWAYS-1:0];
reg  [`SENTRY_WIDTH*`I_INDEX_WIDTH-1:0] ram_rd_index  [`IWAYS-1:0];
wire [`SENTRY_WIDTH*`LINE_WIDTH-1:0]    ram_rd_line   [`IWAYS-1:0];

// inst cache line forwarding and read logic
reg                             forward0to1;
reg                             forward0to2;
reg                             forward0to3;
reg                             forward1to2;
reg                             forward1to3;
reg                             forward2to3;
reg  [`SENTRY_WIDTH-1:0]        pipe_mhb;
line_t                          actual_line         [`SENTRY_WIDTH-1:0];
line_t                          fifo_line           [`SENTRY_WIDTH-1:0];
line_t                          cache_line          [`SENTRY_WIDTH-1:0];

// instructions read from instruction line
inst_t                          instructions        [`SENTRY_WIDTH-1:0][15:0];
inst_t                          cache_instructions  [`SENTRY_WIDTH-1:0][15:0];
inst_t                          fifo_instructions   [`SENTRY_WIDTH-1:0][15:0];
wire [`BYTE_OFFSET_WIDTH-3:0]   inst_offset         [`SENTRY_WIDTH-1:0];
reg  [`BYTE_OFFSET_WIDTH-3:0]   inst_offset_reg     [`SENTRY_WIDTH-1:0];

// instruction type
wire [`SENTRY_WIDTH-1:0]    inst_is_jump;
wire [`SENTRY_WIDTH-1:0]    inst_is_load;
wire [`SENTRY_WIDTH-1:0]    inst_is_store;
wire [`SENTRY_WIDTH-1:0]    inst_is_mem;

// PC Manager
addr_t  PC; 
addr_t  next_PC;
addr_t  curr_PC [`SENTRY_WIDTH-1:0];

// Issue queue ogic
addr_t  PC_reg [`SENTRY_WIDTH-1:0];
tag_t   tag_reg [`SENTRY_WIDTH-1:0];
addr_t  result_reg [`SENTRY_WIDTH-1:0];
inst_t  instruction_reg [`SENTRY_WIDTH-1:0];
reg  [`SENTRY_WIDTH-1:0] is_mem_reg;
reg  [`SENTRY_WIDTH-1:0] wr_en_reg;

(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    issue_queue_wr_en;
(*keep="true"*)issue_t                     issue_queue_input       [`SENTRY_WIDTH-1:0];
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    issue_queue_rd_en;
(*keep="true"*)issue_t                     issue_queue_output      [`SENTRY_WIDTH-1:0];
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    issue_queue_full;
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    issue_queue_empty;
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    issue_queue_almost_full;
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    issue_queue_almost_empty;
(*keep="true"*)wire [`SENTRY_WIDTH-1:0]    issue_queue_prog_full;
`ifdef DATA_COUNT
    (*keep="true"*)wire [9              :0]    issue_queue_data_count  [`SENTRY_WIDTH-1:0];
`endif

wire issue_queues_almost_full = | issue_queue_almost_full;
wire issue_queues_prog_full = | issue_queue_prog_full;

// PC Generation Logic
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: program_counter
    // Cycle 1
    assign inst_is_jump[i]  = (instruction[i][6:0] == `RV32_JAL) || (instruction[i][6:0] == `RV32_JALR) || (instruction[i][6:0] == `RV32_BRANCH);
    assign inst_is_load[i]  = (instruction[i][6:0] == `RV32_LOAD) || (instruction[i][6:0] == `RV_LOAD_UNT);
    assign inst_is_store[i] = (instruction[i][6:0] == `RV32_STORE) || (instruction[i][6:0] == `RV_STORE_UNT_NET && instruction[i][14:12] < 4);
    assign inst_is_mem[i]   = inst_is_load[i] || inst_is_store[i];
end
endgenerate

`ifdef DCACHE_OPT
    // LSU Enable FIFO Interface
    // cycle 2, instruction is valid and is a memory instruction
    assign lsu_enable_fifo_input = is_mem_reg;
    assign lsu_enable_fifo_wr_en = | (is_mem_reg & wr_en_reg);
`endif

// PC is updated on Cycle 2
always @(posedge clk) begin
    if(rst) begin
        PC <= `START_PC;
    end
    else if(inst_frame_ready_reg) begin
        // Cycle 2
        PC <= next_PC;
    end
end

// next PC and curr PC is determined on Cycle 1
generate
if(`SENTRY_WIDTH == 4) begin
    // Cycle 1 (result and inst_is_jump are cycle 1 valid)
    always @(*) begin
        next_PC =   inst_is_jump[3] ? result[3]      :
                    inst_is_jump[2] ? result[2] + 4  : 
                    inst_is_jump[1] ? result[1] + 8  : 
                    inst_is_jump[0] ? result[0] + 12 : PC + 16;
    end
    // Cycle 1 (result and inst_is_jump are cycle 1 valid)
    assign curr_PC[0] = PC;

    assign curr_PC[1] = inst_is_jump[0] ? result[0]      : PC + 4;

    assign curr_PC[2] = inst_is_jump[1] ? result[1]      : 
                        inst_is_jump[0] ? result[0] + 4  : PC + 8;

    assign curr_PC[3] = inst_is_jump[2] ? result[2]      : 
                        inst_is_jump[1] ? result[1] + 4  : 
                        inst_is_jump[0] ? result[0] + 8  : PC + 12;
end
endgenerate

// Instruction ready and pkt control
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
    // Cycle 0
    assign inst_ready[i] =  inst_pkt1_fifo_empty[i]          ? 0 : // if pkt1 not ready, instruction not ready
                            !inst_pkt1_fifo_output[i].mhb    ? 1 : // if miss, need to wait for pkt2 ready 
                            inst_pkt2_fifo_empty[i]          ? 0 : 1;

    assign inst_pkt1_fifo_rd_en[i]  = inst_frame_ready && inst_ready[i]; 
    assign inst_pkt2_fifo_rd_en[i]  = inst_frame_ready && inst_pkt1_fifo_output[i].mhb;
    `ifdef SMAC
        assign inst_pkt3_fifo_rd_en[i]  = inst_frame_ready && (!inst_pkt3_fifo_empty[i]);
    `endif

end
endgenerate

// on all ready of a frame of instruction, signal inst_frame_ready, but make sure issue queue is not full
// and perform cache read/write operations
`ifdef DCACHE_OPT
assign inst_frame_ready = (& inst_ready) && 
                            (!issue_queues_prog_full) && 
                            (& functional_unit_ready) && 
                            (& check_unit_ready) && 
                            (!lsu_enable_fifo_prog_full);
`else
assign inst_frame_ready = (& inst_ready) && 
                            (!issue_queues_prog_full) && 
                            (& functional_unit_ready) && 
                            (& check_unit_ready);
`endif

assign data_frame_ready = (& data_ready) && 
                            (!(|lsu_pkt1_fifo_almost_full)) && 
                            (!(|lsu_vpkt_fifo_almost_full)) && 
                            (!(|lsu_pkt2_fifo_almost_full));

// Instruction gets routed to decode when all instruction cache lines are ready
always @(posedge clk) begin
    // Cycle 1
    inst_frame_ready_reg <= inst_frame_ready;
    data_frame_ready_reg <= data_frame_ready;
end

// Cache Read Hit Control
generate
if(`IWAYS == 2) begin : read_hit_2ways
    for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: inst_cache_rd_hit_way
        // Cycle 0
        assign rd_en[i]         =   inst_pkt1_fifo_output[i].ens;
        assign rd_hit_way[i]    =   rd_en[i][0] ? 3'd0        :
                                    rd_en[i][1] ? 3'd1        :
                                    {3{1'b1}}   ; // all 1's for debug
    end
end
else if(`IWAYS == 4) begin : read_hit_4ways
    for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: inst_cache_rd_hit_way
        // Cycle 0
        assign rd_en[i]         =   inst_pkt1_fifo_output[i].ens;
        assign rd_hit_way[i]    =   rd_en[i][0] ? 3'd0        :
                                    rd_en[i][1] ? 3'd1        :
                                    rd_en[i][2] ? 3'd2        :
                                    rd_en[i][3] ? 3'd3        :
                                    {3{1'b1}}   ; // all 1's for debug
    end
end
endgenerate

// Line forwarding logic
generate
if(`SENTRY_WIDTH == 4) begin : line_forward_4ways
    // Cycle 1
    always @(posedge clk) begin
        forward0to1 <= wr_index[0] == rd_index[1] && wr_en[0] == rd_en[1];
        forward0to2 <= wr_index[0] == rd_index[2] && wr_en[0] == rd_en[2];
        forward0to3 <= wr_index[0] == rd_index[3] && wr_en[0] == rd_en[3];
        forward1to2 <= wr_index[1] == rd_index[2] && wr_en[1] == rd_en[2];
        forward1to3 <= wr_index[1] == rd_index[3] && wr_en[1] == rd_en[3];
        forward2to3 <= wr_index[2] == rd_index[3] && wr_en[2] == rd_en[3];
    end
    // Cycle 1 (both fifo_line and cache_line are cycle 1 valid)
    assign actual_line[0]   =   pipe_mhb[0]   ? fifo_line[0]   : cache_line[0];

    assign actual_line[1]   =   pipe_mhb[1]   ? fifo_line[1]   : 
                                forward0to1   ? actual_line[0] : cache_line[1];

    assign actual_line[2]   =   pipe_mhb[2]   ? fifo_line[2]   : 
                                forward1to2   ? actual_line[1] :
                                forward0to2   ? actual_line[0] : cache_line[2];

    assign actual_line[3]   =   pipe_mhb[3]   ? fifo_line[3]   : 
                                forward2to3   ? actual_line[2] :
                                forward1to3   ? actual_line[1] :
                                forward0to3   ? actual_line[0] : cache_line[3];
end
endgenerate

// Delayed FIFO Input Line (Cycle 1)
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: delayed_fifo_line
    // Cycle 1
    always @(posedge clk) begin
        pipe_mhb[i]     <= inst_pkt1_fifo_output[i].mhb;
        fifo_line[i]    <= inst_pkt2_fifo_output[i].line;
    end
end
endgenerate

// Cache Control
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: inst_cache_line
    // Cycle 0
    assign wr_en[i]         = !inst_frame_ready ? 'd0 :
                            inst_pkt1_fifo_output[i].mhb ? inst_pkt1_fifo_output[i].ens : 'd0;    
    assign wr_index[i]      = inst_pkt1_fifo_output[i].addr[`BYTE_OFFSET_WIDTH+:`I_INDEX_WIDTH];
    assign wr_line[i]       = inst_pkt2_fifo_output[i].line;
    assign rd_index[i]      = inst_pkt1_fifo_output[i].addr[`BYTE_OFFSET_WIDTH+:`I_INDEX_WIDTH];
    assign inst_offset[i]   = inst_pkt1_fifo_output[i].addr[`BYTE_OFFSET_WIDTH-1:2];
    assign inst_result[i]   = inst_pkt1_fifo_output[i].result;
    assign inst_tag[i]      = inst_pkt1_fifo_output[i].tag;
    // Cycle 1
    assign cache_line[i]    = rd_line[i][rd_hit_way_reg[i]];
    assign instruction[i]   = instructions[i][inst_offset_reg[i]];
end
endgenerate

generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: inst_cache_line_offset
    always @(posedge clk) begin
        // Cycle 1
        rd_hit_way_reg[i]   <= rd_hit_way[i];
        inst_offset_reg[i]  <= inst_offset[i];
        // Cycle 1, this depends on when data becomes ready
        // does operand routing need to care about memory operation ordering? yes
        // does operand routing need to check issue queue full? yes
        inst_valid[i]       <= inst_frame_ready; 
        result[i]           <= inst_result[i];
        tag[i]              <= inst_tag[i];
        // Cycle 2, issue queue input
        PC_reg[i]           <= curr_PC[i];
        tag_reg[i]          <= tag[i];
        result_reg[i]       <= result[i];
        instruction_reg[i]  <= instruction[i];
        is_mem_reg[i]       <= inst_is_mem[i];
        wr_en_reg[i]        <= inst_valid[i];
    end
end
endgenerate

generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: inst_fetch
    for(j = 0; j < 16; j=j+1) begin
        // Cycle 1
        assign cache_instructions[i][j] = cache_line[i][j*`INST_LEN+:`INST_LEN];
        assign fifo_instructions[i][j]  = fifo_line[i][j*`INST_LEN+:`INST_LEN];
        assign instructions[i][j]       = actual_line[i][j*`INST_LEN+:`INST_LEN];
    end
end
endgenerate

// all instructuctions must wait for data frame to be ready before 
// issuing to the decode execute check RICU pipelines

// issue queue for instructions to wait in
generate
for(i = 0; i < `SENTRY_WIDTH; i = i + 1) begin: issue_queues
// Cycle 1 issue queue fill
//assign issue_queue_wr_en[i] = inst_valid[i];
//assign issue_queue_input[i].PC = curr_PC[i];
//assign issue_queue_input[i].tag = tag[i];
//assign issue_queue_input[i].result = result[i];
//assign issue_queue_input[i].instruction = instruction[i];
//assign issue_queue_input[i].is_mem = inst_is_mem[i];

// Cycle 2 issue queue fill
assign issue_queue_wr_en[i]             = wr_en_reg[i];
assign issue_queue_input[i].PC          = PC_reg[i];
assign issue_queue_input[i].tag         = tag_reg[i];
assign issue_queue_input[i].result      = result_reg[i];
assign issue_queue_input[i].instruction = instruction_reg[i];
assign issue_queue_input[i].is_mem      = is_mem_reg[i];

// Issue queue need to apply back pressure to inst pkt and data pkt consumes
issue_queue ISSUE_QUEUE (
    .clk            (clk                        ),  // input wire wr_clk
    .din            (issue_queue_input[i]       ),  // input wire [191 : 0] din
    .wr_en          (issue_queue_wr_en[i]       ),  // input wire wr_en
    .rd_en          (issue_queue_rd_en[i]       ),  // input wire rd_en
    .dout           (issue_queue_output[i]      ),  // output wire [191 : 0] dout
    .full           (issue_queue_full[i]        ),  // output wire full
    .empty          (issue_queue_empty[i]       ),  // output wire empty
    .almost_full    (issue_queue_almost_full[i] ),  // output wire full
    .almost_empty   (issue_queue_almost_empty[i]),  // output wire empty
    .prog_full      (issue_queue_prog_full[i]   ),  // output wire empty
    `ifdef DATA_COUNT
        .data_count     (issue_queue_data_count[i]  ),  // output wire [9 : 0] data_count
    `endif
    .srst           (rst                        )   // input wire rst
);

// Incoming Data PKT FIFO (Cycle 0)
assign data_ready[i]=   issue_queue_empty[i]            ? 0 :   // if no instruction, data not ready
                        !issue_queue_output[i].is_mem   ? 1 :   // if non memory instruction, data ready
                        data_pkt1_fifo_empty[i]         ? 0 :   // if pkt1 not ready, data not ready
                        !data_pkt1_fifo_output[i].mhb   ? 1 :   // if pkt1 ready and data hit, data ready
                        data_vpkt_fifo_empty[i]         ? 0 :   // if D$ miss and vpkt not ready, data not ready
                        !data_vpkt_fifo_output[i].mhb   ? 1 :   // if D$ miss and victim cam hit, data ready from victim cam
                        data_pkt2_fifo_empty[i]         ? 0 : 1;// if D$ miss, victim cam miss, data ready is pkt2 mem data ready


assign ready_to_issue[i]    =   data_frame_ready;
assign pipe_valid[i]        =   ready_to_issue[i];
assign issue_tag[i]         =   issue_queue_output[i].tag;
assign issue_PC[i]          =   issue_queue_output[i].PC;
assign issue_instruction[i] =   issue_queue_output[i].instruction;
assign issue_result[i]      =   issue_queue_output[i].result;
assign issue_queue_rd_en[i] =   ready_to_issue[i];

// hook up incoming data pkt fifos to internal lsu data pkt fifos
assign lsu_pkt1_fifo_input[i]   = data_pkt1_fifo_output[i];
assign data_pkt1_fifo_rd_en[i]  = data_frame_ready && issue_queue_output[i].is_mem;
assign lsu_pkt1_fifo_wr_en[i]   = data_frame_ready && issue_queue_output[i].is_mem;

assign lsu_vpkt_fifo_input[i]   = data_vpkt_fifo_output[i];
assign data_vpkt_fifo_rd_en[i]  = data_frame_ready && issue_queue_output[i].is_mem && data_pkt1_fifo_output[i].mhb;
assign lsu_vpkt_fifo_wr_en[i]   = data_frame_ready && issue_queue_output[i].is_mem && data_pkt1_fifo_output[i].mhb;

assign lsu_pkt2_fifo_input[i]   = data_pkt2_fifo_output[i];
assign data_pkt2_fifo_rd_en[i]  = data_frame_ready && issue_queue_output[i].is_mem && data_pkt1_fifo_output[i].mhb && data_vpkt_fifo_output[i].mhb;
assign lsu_pkt2_fifo_wr_en[i]   = data_frame_ready && issue_queue_output[i].is_mem && data_pkt1_fifo_output[i].mhb && data_vpkt_fifo_output[i].mhb;

end
endgenerate 

// pack and unpack parallel icache control data
generate
for (i=0; i<`IWAYS; i=i+1) begin: i_line_ram_control
    for (j=0; j<`SENTRY_WIDTH; j=j+1) begin
        //always @(*) begin
        //    // Cycle 1
        //    ram_wr_en[i][j]                                             = wr_en[j][i];
        //    ram_wr_index[i][(j+1)*`I_INDEX_WIDTH-1:j*`I_INDEX_WIDTH]    = wr_index[j];
        //    ram_wr_line[i][(j+1)*`LINE_WIDTH-1:j*`LINE_WIDTH]           = wr_line[j];
        //end
        always @(posedge clk) begin
            // Cycle 1
            ram_wr_en[i][j]                                             <= wr_en[j][i];
            ram_wr_index[i][(j+1)*`I_INDEX_WIDTH-1:j*`I_INDEX_WIDTH]    <= wr_index[j];
            ram_wr_line[i][(j+1)*`LINE_WIDTH-1:j*`LINE_WIDTH]           <= wr_line[j];
        end
        always @(*) begin
            // Cycle 0
            ram_rd_index[i][(j+1)*`I_INDEX_WIDTH-1:j*`I_INDEX_WIDTH]    = rd_index[j];
            // Cycle 1
            rd_line[j][i]                                               = ram_rd_line[i][(j+1)*`LINE_WIDTH-1:j*`LINE_WIDTH];
        end
    end
end
endgenerate

generate
for (i=0; i<`IWAYS; i=i+1) begin: i_line_ram
    // instantiate a multiported-RAM with binary-coded register-based LVT
    mpram   #(  
        .MEMD   (MEMD            ),  // memory depth
        .DATAW  (DATAW           ),  // data width
        .nRPORTS(nRPORTS         ),  // number of reading ports
        .nWPORTS(nWPORTS         ),  // number of writing ports
        .TYPE   ("LVTREG"        ),  // multi-port RAM implementation type
        .BYP    (BYP             ),  // Bypassing type: NON, WAW, RAW, RDW
        .IFILE  ("zero"          )  // initializtion file, optional
    )
    //mpram_lvtreg_dut (  
    //    .clk    (clk                                                            ),  // clock
    //    .WEnb   ({wr_en[3][i], wr_en[2][i], wr_en[1][i], wr_en[0][i]}           ),  // write enable for each writing port                - in : [nWPORTS-1:0            ]
    //    .WAddr  ({wr_index[3], wr_index[2], wr_index[1], wr_index[0]}           ),  // write addresses - packed from nWPORTS write ports - in : [`log2(MEMD)*nWPORTS-1:0]
    //    .WData  ({wr_line[3], wr_line[2], wr_line[1], wr_line[0]}               ),  // write data      - packed from nRPORTS read  ports - out: [DATAW      *nWPORTS-1:0]
    //    .RAddr  ({rd_index[3], rd_index[2], rd_index[1], rd_index[0]}           ),  // read  addresses - packed from nRPORTS read  ports - in : [`log2(MEMD)*nRPORTS-1:0]
    //    .RData  ({rd_line[3][i], rd_line[2][i], rd_line[1][i], rd_line[0][i]}   )); // read  data      - packed from nRPORTS read  ports - out: [DATAW      *nRPORTS-1:0]
    mpram_lvtreg_icache (  
        .clk    (clk                ),  // clock
        .WEnb   (ram_wr_en[i]       ),  // write enable for each writing port                - in : [nWPORTS-1:0            ]
        .WAddr  (ram_wr_index[i]    ),  // write addresses - packed from nWPORTS write ports - in : [`log2(MEMD)*nWPORTS-1:0]
        .WData  (ram_wr_line[i]     ),  // write data      - packed from nRPORTS read  ports - out: [DATAW      *nWPORTS-1:0]
        .RAddr  (ram_rd_index[i]    ),  // read  addresses - packed from nRPORTS read  ports - in : [`log2(MEMD)*nRPORTS-1:0]
        .RData  (ram_rd_line[i]     )   // read  data      - packed from nRPORTS read  ports - out: [DATAW      *nRPORTS-1:0]
    );

    //ram_4wide #(
    //    .ADDR_WIDTH (`I_INDEX_WIDTH),
    //    .DATA_WIDTH (`LINE_WIDTH),
    //    .NPORTS     (`SENTRY_WIDTH)
    //)
    //ram_4ports (
    //    .clk        (clk        ),
    //    .wr_en      (wr_en      ),
    //    .wr_addr    (wr_index   ),
    //    .wr_data    (wr_line    ), 
    //    .rd_addr    (rd_index   ),
    //    .rd_data    (rd_line    )
    //);
end
endgenerate


`ifdef SIMULATION
    // Pipeline Utilization Statistics
    reg [31:0] cycle_cnt;
    reg [31:0] busy_cnt;
    reg [31:0] mem_busy_cnt;
    reg [31:0] mem_busy_cnt1;
    reg [31:0] mem_busy_cnt2;
    reg [31:0] mem_busy_cnt3;
    reg [31:0] mem_busy_cnt4;
    wire mem_busy = |is_mem_reg;
    wire [31:0] mem_busy_frame = is_mem_reg[0] + is_mem_reg[1] + is_mem_reg[2] + is_mem_reg[3];
    wire mem_busy1 = mem_busy_frame == 32'd1;
    wire mem_busy2 = mem_busy_frame == 32'd2;
    wire mem_busy3 = mem_busy_frame == 32'd3;
    wire mem_busy4 = mem_busy_frame == 32'd4;
    always @(posedge clk) begin
        if(rst) begin
            cycle_cnt <= 0;
            busy_cnt <= 0;
            mem_busy_cnt <= 0;
            mem_busy_cnt1 <= 0;
            mem_busy_cnt2 <= 0;
            mem_busy_cnt3 <= 0;
            mem_busy_cnt4 <= 0;
        end
        else begin
            cycle_cnt <= cycle_cnt + 1;
            if(inst_frame_ready) begin
                busy_cnt <= busy_cnt + 1;
            end
            if(|is_mem_reg) begin
                mem_busy_cnt <= mem_busy_cnt + 1;
            end
            if(mem_busy1) begin
                mem_busy_cnt1 <= mem_busy_cnt1 + 1;
            end
            if(mem_busy2) begin
                mem_busy_cnt2 <= mem_busy_cnt2 + 1;
            end
            if(mem_busy3) begin
                mem_busy_cnt3 <= mem_busy_cnt3 + 1;
            end
            if(mem_busy4) begin
                mem_busy_cnt4 <= mem_busy_cnt4 + 1;
            end
        end
    end
`endif

endmodule
