`include "parameters.svh"
`include "alu_ops.svh"
import TYPES::*;

module sentry_pob
(
    // ALU Resolved Tag
    input  tag_t                        alu_tag         [`SENTRY_WIDTH-1:0],
    input  logic [`SENTRY_WIDTH-1:0]    alu_tag_valid,
    output logic [`SENTRY_WIDTH-1:0]    alu_tag_clear,
    // MD Resolved Tag
    input  tag_t                        md_tag          [`SENTRY_WIDTH-1:0],
    input  logic [`SENTRY_WIDTH-1:0]    md_tag_valid,
    output logic [`SENTRY_WIDTH-1:0]    md_tag_clear,
    // Memory Resolved Tag
    input  tag_t                        mem_tag         [`SENTRY_WIDTH-1:0],
    input  logic [`SENTRY_WIDTH-1:0]    mem_tag_valid,
    output logic [`SENTRY_WIDTH-1:0]    mem_tag_clear,
    // Network Resolved Tag
    input  tag_t                        net_tag         [`SENTRY_WIDTH-1:0],
    input  logic [`SENTRY_WIDTH-1:0]    net_tag_valid,
    output logic [`SENTRY_WIDTH-1:0]    net_tag_clear,
    // Network Resolved Tag
    input  tag_t                        bypass_tag      [`SENTRY_WIDTH-1:0],
    input  logic [`SENTRY_WIDTH-1:0]    bypass_tag_valid,
    output logic [`SENTRY_WIDTH-1:0]    bypass_tag_clear,
    // Read Interface from Sentry Network PUT Request Queue
    input  logic                        net_put_req_fifo_empty,
    output logic                        net_put_req_fifo_rd_en,
    input  tag_result_t                 net_put_req_fifo_tag_result,
    // Write Interface to Sentry Cleared Outgoing PUT Request Queue
    output data_t                       net_outgoing_req_fifo_input,
    output logic                        net_outgoing_req_fifo_wr_en,
    input  logic                        net_outgoing_req_fifo_full,
    input  logic                        net_outgoing_req_fifo_almost_full,
    // clock and reset
    input logic                         clk,
    input logic                         rst
);

genvar i;

typedef enum {
    S_POB_IDLE,
    S_POB_WORK,
    S_POB_DONE
} pob_state_e;

pob_state_e POB_STATE, next_POB_STATE;
always @(posedge clk) begin
    if(rst) POB_STATE <= S_POB_IDLE;
    else POB_STATE <= next_POB_STATE;
end

wire [`SENTRY_WIDTH-1:0] alu_match;
wire [`SENTRY_WIDTH-1:0] md_match;
wire [`SENTRY_WIDTH-1:0] mem_match;
wire [`SENTRY_WIDTH-1:0] net_match;
wire [`SENTRY_WIDTH-1:0] bypass_match;
wire [`SENTRY_WIDTH-1:0] pipe_match;

wire frame_match = &pipe_match;

(* keep = "true" *)din_t frame_din;
din_t next_frame_din;
din_t frame_din_pipe    [`SENTRY_WIDTH-1:0];

always @(posedge clk) begin
    if(rst) frame_din <= 1;
    else if(frame_match) frame_din <= next_frame_din;
end

assign frame_din_pipe[0] = frame_din;
assign frame_din_pipe[1] = frame_din + 1;
assign frame_din_pipe[2] = frame_din + 2;
assign frame_din_pipe[3] = frame_din + 3;
assign next_frame_din    = frame_din + 4;

generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: RESOLVE_SIGNALS
    // individual functional units of each pipeline check out
    assign alu_match[i]     = alu_tag_valid[i] && alu_tag[i].number == frame_din_pipe[i];
    assign md_match[i]      = md_tag_valid[i] && md_tag[i].number == frame_din_pipe[i];
    assign mem_match[i]     = mem_tag_valid[i] && mem_tag[i].number == frame_din_pipe[i];
    assign net_match[i]     = net_tag_valid[i] && net_tag[i].number == frame_din_pipe[i];
    assign bypass_match[i]  = bypass_tag_valid[i] && bypass_tag[i].number == frame_din_pipe[i];
    // single pipe result checked
    assign pipe_match[i]    = alu_match[i] || md_match[i] || mem_match[i] || net_match[i] || bypass_match[i];
    // clear only when all SENTRY_WIDTH pipes checked out
    // and only clear the one queue that matched
    assign alu_tag_clear[i]     = frame_match && alu_match[i];
    assign md_tag_clear[i]      = frame_match && md_match[i];
    assign mem_tag_clear[i]     = frame_match && mem_match[i];
    assign net_tag_clear[i]     = frame_match && net_match[i];
    assign bypass_tag_clear[i]  = frame_match && bypass_match[i];
end
endgenerate

// TODO right when put req fifo becomes not empty, curr_din is all 0s
// maybe this need to resolved a cycle later?
din_t put_din;
assign put_din = net_put_req_fifo_tag_result.tag.number;

always @(*) begin
    next_POB_STATE = POB_STATE;
    case(POB_STATE)
        S_POB_IDLE: begin
            // TODO as put req fifo deasserts empty, 
            // put_din stays at 0, need to wait one cycle for it to become actual content
            //if(!net_put_req_fifo_empty && (frame_din > put_din) && (put_din != {$bits(din_t){1'b0}})) begin
            if(!net_put_req_fifo_empty && (frame_din > put_din)) begin
                next_POB_STATE = S_POB_WORK;
            end
        end
        S_POB_WORK: begin
            next_POB_STATE = S_POB_DONE;
        end
        S_POB_DONE: begin
            next_POB_STATE = S_POB_IDLE;
        end
    endcase
end

always @(posedge clk) begin
    case(POB_STATE)
        S_POB_IDLE: begin
            net_outgoing_req_fifo_input <= `X_LEN'd0;
            net_outgoing_req_fifo_wr_en <= 1'b0;
            net_put_req_fifo_rd_en      <= 1'b0;
        end
        S_POB_WORK: begin
            net_outgoing_req_fifo_input <= net_put_req_fifo_tag_result.result;
            net_outgoing_req_fifo_wr_en <= 1;
            net_put_req_fifo_rd_en      <= 1;
        end
        S_POB_DONE: begin
            net_outgoing_req_fifo_input <= `X_LEN'd0;
            net_outgoing_req_fifo_wr_en <= 1'b0;
            net_put_req_fifo_rd_en      <= 1'b0;
        end
    endcase
end

endmodule

