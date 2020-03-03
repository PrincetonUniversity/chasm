// Central control of sentryControl unit
`timescale 1ns/1ps
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

module sentryControl_ctrl_jumpResult (
    // Incoming Trace Buffer Interface
    input  logic                        trace_ready,
    (*keep="true"*)input  quad_jump_result_s           trace_data,
    (*keep="true"*)output logic                        trace_en,
    // Icache Control Interface
    input  logic                        icache_req_almost_full, // back pressure
    output logic [`SENTRY_WIDTH-1:0]    icache_req_valid,
    output addr_t                       icache_req_address              [`SENTRY_WIDTH-1:0],
    output data_t                       icache_req_inst_result          [`SENTRY_WIDTH-1:0],
    // Clock and reset
    input  logic                        clk,
    input  logic                        rst
);

genvar i;

(*keep="true"*)jump_result_s               trace       [`SENTRY_WIDTH-1:0];
reg                         trace_en_reg;
addr_t                      result      [`SENTRY_WIDTH-1:0];
data_t                      result_reg  [`SENTRY_WIDTH-1:0];

addr_t                      PC; 
addr_t                      next_PC;
(*keep="true"*)addr_t                      curr_PC     [`SENTRY_WIDTH-1:0];
addr_t                      curr_PC_reg [`SENTRY_WIDTH-1:0];
integer                     din; 
integer                     next_din;
(*keep="true"*)integer                     curr_din    [`SENTRY_WIDTH-1:0];

wire [`SENTRY_WIDTH-1:0]    instruction_is_jump;

// array-ize the incoming traces
generate
if(`SENTRY_WIDTH == 4) begin
    assign trace[0] = trace_data.jump_result0;
    assign trace[1] = trace_data.jump_result1;
    assign trace[2] = trace_data.jump_result2;
    assign trace[3] = trace_data.jump_result3;
end
endgenerate

// propagate back pressure to trace fifo
assign trace_en = trace_ready && !icache_req_almost_full; 
always @(posedge clk) begin
    trace_en_reg <= trace_en;
end

// current starting PC for the first pipeline, 
// all subsequent pipeline PCs are determined sequentially
always @(posedge clk) begin
    if(rst) begin
        PC <= `START_PC;
        din <= 1;
    end
    else if(trace_en) begin
        PC <= next_PC;
        din <= next_din;
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

        next_din    = din+4;
        curr_din[0] = din;
        curr_din[1] = din+1;
        curr_din[2] = din+2;
        curr_din[3] = din+3;
    end
end
endgenerate

generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: parallel_decode
    // instruction cache fetch (Cycle 0)
    assign result[i]                = trace[i].result;
    assign instruction_is_jump[i]   = trace[i].jump_flag;
end
endgenerate

generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: parallel_result
    always @(posedge clk) begin
        curr_PC_reg[i]      <= curr_PC[i];
        result_reg[i]       <= result[i];
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

endmodule

