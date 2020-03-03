// Central control of sentryControl unit
`timescale 1ns/1ps
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

module sentryControl_ctrl (
    input  logic                        clk,
    input  logic                        rst,
    // Incoming Trace Buffer Interface
    input  logic                        trace_ready,
    input  quad_trace_s                 trace_data,
    output logic                        trace_en,
    // Icache Control Interface
    input  logic                        icache_req_almost_full, // back pressure
    output logic [`SENTRY_WIDTH-1:0]    icache_req_valid,
    output addr_t                       icache_req_address      [`SENTRY_WIDTH-1:0],
    output data_t                       icache_req_inst_result  [`SENTRY_WIDTH-1:0],
    // DCache Control Interface
    input  logic                        dcache_req_almost_full, // back pressure
    output logic [`SENTRY_WIDTH-1:0]    dcache_req_valid,
    output logic [`SENTRY_WIDTH-1:0]    dcache_req_store,
    output addr_t                       dcache_req_address      [`SENTRY_WIDTH-1:0]
);

genvar i;

trace_s                     trace       [`SENTRY_WIDTH-1:0];
reg                         trace_en_reg;
inst_t                      instruction [`SENTRY_WIDTH-1:0];
// Debugging register
inst_t                      instruction_reg [`SENTRY_WIDTH-1:0];
addr_t                      result      [`SENTRY_WIDTH-1:0];
data_t                      result_reg  [`SENTRY_WIDTH-1:0];

addr_t                      PC; 
addr_t                      next_PC;
addr_t                      curr_PC     [`SENTRY_WIDTH-1:0];
addr_t                      curr_PC_reg [`SENTRY_WIDTH-1:0];

// Instruction Decode
reg_t                       rs1         [`SENTRY_WIDTH-1:0];
reg_t                       rs2         [`SENTRY_WIDTH-1:0];
reg_t                       rd          [`SENTRY_WIDTH-1:0];
data_t                      IMMI        [`SENTRY_WIDTH-1:0];
data_t                      IMMS        [`SENTRY_WIDTH-1:0];
wire [6:0]                  OPCODE      [`SENTRY_WIDTH-1:0];
wire [2:0]                  FUNCT3      [`SENTRY_WIDTH-1:0];
wire [6:0]                  FUNCT7      [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]    instruction_is_load;
wire [`SENTRY_WIDTH-1:0]    instruction_is_store;
wire [`SENTRY_WIDTH-1:0]    instruction_is_mem;
wire [`SENTRY_WIDTH-1:0]    instruction_is_jump;

// Data Access
addr_t                      data_address [`SENTRY_WIDTH-1:0];
reg  [`SENTRY_WIDTH-1:0]    data_access;
reg  [`SENTRY_WIDTH-1:0]    data_store;

// RegFile Interface
wire [`SENTRY_WIDTH-1:0]    wr_en;
reg_t                       wr_addr     [`SENTRY_WIDTH-1:0];
data_t                      wr_data     [`SENTRY_WIDTH-1:0]; 
reg_t                       rd_addr_a   [`SENTRY_WIDTH-1:0];
reg_t                       rd_addr_b   [`SENTRY_WIDTH-1:0];
data_t                      rd_data_a   [`SENTRY_WIDTH-1:0];
data_t                      rd_data_b   [`SENTRY_WIDTH-1:0];

// propagate back pressure to trace fifo
assign trace_en = trace_ready && !icache_req_almost_full && !dcache_req_almost_full; 
always @(posedge clk) begin
    trace_en_reg <= trace_en;
end

//typedef enum {
//    S_IDLE,         // idle state
//    S_REQ,          // wait for ready then send request
//    S_RESP,         // wait for response
//    S_PKT,          // prepare packet
//    S_RESULT        // send result packet
//} control_state_e;
//control_state_e STATE;
//control_state_e next_STATE;
//always @(posedge clk) begin
//    if(rst) begin
//        STATE <= S_IDLE;
//    end
//    else begin
//        STATE <= next_STATE;
//    end
//end

//addr_t  PC      [`SENTRY_WIDTH-1:0];
//addr_t  next_PC [`SENTRY_WIDTH-1:0];
// current starting PC for the first pipeline, 
// all subsequent pipeline PCs are determined sequentially
always @(posedge clk) begin
    if(rst) begin
        PC <= 'h7528;
    end
    else if(trace_en) begin
        PC <= next_PC;
    end
end

// next PC is determined immediately, combinational logic
generate
if(`SENTRY_WIDTH == 4) begin
    always @(*) begin
        next_PC    = instruction_is_jump[3] ? result[3]      :
                     instruction_is_jump[2] ? result[2] + 4  : 
                     instruction_is_jump[1] ? result[1] + 8  : 
                     instruction_is_jump[0] ? result[0] + 12 : PC + 16;

        curr_PC[0] = PC;

        curr_PC[1] = instruction_is_jump[0] ? result[0]      : PC + 4;

        curr_PC[2] = instruction_is_jump[1] ? result[1]      : 
                     instruction_is_jump[0] ? result[0] + 4  : PC + 8;

        curr_PC[3] = instruction_is_jump[2] ? result[2]      : 
                     instruction_is_jump[1] ? result[1] + 4  : 
                     instruction_is_jump[0] ? result[0] + 8  : PC + 12;
    end
end
endgenerate

generate
if(`SENTRY_WIDTH == 4) begin
    assign trace[0] = trace_data.trace0;
    assign trace[1] = trace_data.trace1;
    assign trace[2] = trace_data.trace2;
    assign trace[3] = trace_data.trace3;
end
endgenerate

generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: parallel_decode
    // instruction cache and data cache fetch (Cycle 0)
    assign instruction[i]           = trace[i].instruction;
    assign result[i]                = trace[i].result;
    assign OPCODE[i]                = instruction[i][ 6: 0];
    assign FUNCT3[i]                = instruction[i][14:12];
    assign FUNCT7[i]                = instruction[i][31:25];
    assign rs1[i]                   = instruction[i][19:15];
    assign rs2[i]                   = instruction[i][24:20];
    assign rd[i]                    = instruction[i][11: 7];
    assign rd_addr_a[i]             = rs1[i];
    assign rd_addr_b[i]             = rs2[i];
    assign wr_addr[i]               = rd[i];
    assign wr_data[i]               = (instruction[i][6:0] == `RV32_JAL) || (instruction[i][6:0] == `RV32_JALR) ? curr_PC[i]+4 : result[i]; // jal(r) writes pc+4 to rd
    assign instruction_is_load[i]   = (instruction[i][6:0] == `RV32_LOAD) || (instruction[i][6:0] == `RV_LOAD_UNT);
    assign instruction_is_store[i]  = (instruction[i][6:0] == `RV32_STORE) || (instruction[i][6:0] == `RV_STORE_UNT_NET && instruction[i][14:12] < 4);
    assign instruction_is_mem[i]    = instruction_is_load[i] || instruction_is_store[i];
    assign instruction_is_jump[i]   = (instruction[i][6:0] == `RV32_JAL) || (instruction[i][6:0] == `RV32_JALR) || (instruction[i][6:0] == `RV32_BRANCH);
    assign IMMI[i]                  = {{(`X_LEN-12){instruction[i][31]}}, instruction[i][31:20]}; 
    assign IMMS[i]                  = {{(`X_LEN-12){instruction[i][31]}}, instruction[i][31:25], instruction[i][11:7]};
    // register write does not happen until instruction valid
    // otherwise subsequent instructions in the pipe fram might overwrite earlier instruction sources and cause memory address to be wrong
    assign wr_en[i]                 = trace_en && ((OPCODE[i] == `RV32_LUI) || (OPCODE[i] == `RV32_AUIPC) || (OPCODE[i] == `RV32_JAL) || (OPCODE[i] == `RV32_JALR) 
                                    || (OPCODE[i] == `RV32_LOAD) || (OPCODE[i] == `RV_LOAD_UNT)
                                    || (OPCODE[i] == `RV_RECV_UNT) || ((OPCODE[i] == `RV_STORE_UNT_NET) && (FUNCT3[i] == `RV_FUNCT3_GET)) // NETWORK GET
                                    || (OPCODE[i] == `RV32_OP) || (OPCODE[i] == `RV32_OP_IMM) || (OPCODE[i] == `RV64_OP) || (OPCODE[i] == `RV64_OP_IMM));
end
endgenerate

generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: parallel_result
    always @(posedge clk) begin
        curr_PC_reg[i]      <= curr_PC[i];
        result_reg[i]       <= result[i];
        instruction_reg[i]  <= instruction[i];
    end
end
endgenerate

// Icache Request (Cycle 1)
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: icache_control
    assign icache_req_valid[i]          = trace_en_reg;
    assign icache_req_address[i]        = curr_PC_reg[i];
    assign icache_req_inst_result[i]    = result_reg[i];
end
endgenerate

//***************
// Register File
//***************
regFile_4wide SENTRYCONTROL_RF (
    .clk        (clk        ),
    .rst        (rst        ),
    .wr_en      (wr_en      ),
    .wr_addr    (wr_addr    ),
    .wr_data    (wr_data    ),
    .rd_addr_a  (rd_addr_a  ),
    .rd_addr_b  (rd_addr_b  ),
    .rd_data_a  (rd_data_a  ),
    .rd_data_b  (rd_data_b  )
);

// Dcache Request  (Cycle 1)
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: parallel_data_address
    always @(posedge clk) begin
        data_address[i] <= instruction_is_load[i] ? rd_data_a[i] + IMMI[i] : rd_data_a[i] + IMMS[i];
        data_access[i]  <= instruction_is_mem[i];
        data_store[i]   <= instruction_is_store[i];
    end
end
endgenerate

// Cycle 1
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: dcache_control
    assign dcache_req_address[i]    = data_address[i];
    assign dcache_req_valid[i]      = trace_en_reg && data_access[i];
    assign dcache_req_store[i]      = trace_en_reg && data_store[i];
end
endgenerate

endmodule

