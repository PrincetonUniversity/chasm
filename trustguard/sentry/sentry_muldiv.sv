// 64 cycle Multiply/Divide Unit Core
`include "parameters.svh"
`include "muldiv_ops.svh"
import TYPES::*;

module sentry_muldiv (
    input  logic                            clk,
    input  logic                            rst,
    input  logic                            req,
    input  logic  [`MD_OP_WIDTH-1:0]        req_op,
    input  logic                            req_srclow,
    input  logic                            req_src1_signed,
    input  logic                            req_src2_signed,
    input  data_t                           req_src1,
    input  data_t                           req_src2,
    input  logic [`MD_OUT_SEL_WIDTH-1:0]    req_out_sel,
    output logic                            ready,
    output logic                            done,
    output data_t                           out
);
// control logic
reg [`DOUBLE_X_LEN-1:0]     a;
data_t                      b;
reg                         out_negate;
reg [`MD_OP_WIDTH-1:0]      op;
reg [`MD_OUT_SEL_WIDTH-1:0] out_sel;
reg [`LOG2_X_LEN-1:0]       counter;
data_t                      result;

typedef enum {
    S_MD_INIT, 
    S_MD_COMPUTE,
    S_MD_DONE
} muldiv_state_e;

// state transition
muldiv_state_e  MD_STATE;
muldiv_state_e  next_MD_STATE;
always @(posedge clk) begin
    if(rst) MD_STATE <= S_MD_INIT;
    else MD_STATE <= next_MD_STATE;
end

wire [`LOWBITS-1:0] FILLBITS = 0;

wire [`DOUBLE_X_LEN-1:0] add = a + {b, `X_LEN'd0};
wire [`DOUBLE_X_LEN-1:0] sub = (a << 1) - {b, `X_LEN'd0};

data_t src1;
data_t src2;

wire src1_sign = req_src1_signed & req_src1[`X_LEN-1];
wire src2_sign = req_src2_signed & req_src2[`X_LEN-1];

assign src1 = req_srclow                                ? {FILLBITS, req_src1[`LOWBITS-1:0]} : 
              (req_src1_signed && req_src1[`X_LEN-1])   ? -req_src1 : req_src1;
assign src2 = req_srclow                                ? {FILLBITS, req_src2[`LOWBITS-1:0]} :
              (req_src2_signed && req_src2[`X_LEN-1])   ? -req_src2 : req_src2;

assign ready = MD_STATE == S_MD_INIT;

always @(MD_STATE or req or counter) begin
    next_MD_STATE = S_MD_INIT;
    case(MD_STATE)
        S_MD_INIT: next_MD_STATE = req ? S_MD_COMPUTE : S_MD_INIT;
        S_MD_COMPUTE: next_MD_STATE = (counter == 0) ? S_MD_DONE : S_MD_COMPUTE;
        S_MD_DONE: next_MD_STATE = S_MD_INIT;
        default: next_MD_STATE = S_MD_INIT;
    endcase
end

always @(posedge clk) begin
    case(MD_STATE)
        S_MD_INIT: begin
            if(req) begin
                a <= {`X_LEN'd0,src1};
                b <= src2;
                out_negate <= (req_op == `MD_OP_REM) ? src1_sign : src1_sign ^ src2_sign;
                op <= req_op;
                out_sel <= req_out_sel;
                counter <= `X_LEN-1;
                out <= `X_LEN'd0;
            end 
            else begin
                a <= {`X_LEN'd0, `X_LEN'd0};
                b <= `X_LEN'd0;
                out_negate <= 1'b0;
                op <= 2'd0;
                out_sel <= 1'b0;
                counter <= `LOG2_X_LEN'd0;
                out <= `X_LEN'd0;
            end
        end
        S_MD_COMPUTE: begin
            counter <= counter - 1'b1;
            //if (op == `MD_OP_MUL) begin
            //  if (a[0]) begin
            //     a[`X_LEN+:`X_LEN] <= a[`X_LEN+:`X_LEN] + b;
            //  end
            //  a <= a >> 1;
            //end else begin
            //  a <= a << 1;
            //  if (a[`X_LEN+:`X_LEN] >= b) begin
            //     a[`X_LEN+:`X_LEN] <= a[`X_LEN+:`X_LEN] - b;
            //     a[0] <= 1;
            //  end
            //  else begin
            //    a[0] <= 0;
            //  end
            //end
            if (op == `MD_OP_MUL) begin
                if (a[0]) begin
                    a <= add >> 1;
                end
                else begin
                    a <= a >> 1;
                end
            end else begin
                if (a[`X_LEN-1+:`X_LEN] >= b) begin
                    a <= {sub[`DOUBLE_X_LEN-1:1], 1'b1};
                end
                else begin
                    a <= {a[`DOUBLE_X_LEN-2:0], 1'b0};
                end
            end
        end
        S_MD_DONE: begin
            out <= result;
        end
    endcase
end

wire  [`DOUBLE_X_LEN-1:0] result_muxed = (out_sel == `MD_OUT_REM) ? a[`X_LEN+:`X_LEN] : a[0+:`X_LEN];
wire  [`DOUBLE_X_LEN-1:0] result_muxed_negated = (out_negate) ? -result_muxed : result_muxed;
assign result = (out_sel == `MD_OUT_HI) ? result_muxed_negated[`X_LEN+:`X_LEN] : result_muxed_negated[0+:`X_LEN];

always @(posedge clk) begin
    done <= MD_STATE == S_MD_DONE;
end


endmodule

// synthesis translate off
module sentry_muldiv_tb();

reg clk;
reg rst;
reg md_req;
reg [`MD_OP_WIDTH-1:0] md_op;
reg md_srclow;
reg md_src1_signed;
reg md_src2_signed;
data_t  md_src1;
data_t  md_src2;
reg [`MD_OUT_SEL_WIDTH-1:0] md_out_sel;
wire md_ready;
wire md_done;
data_t md_result;

integer i;

always begin
    #10 clk = ~clk;
end

initial begin
    clk = 1;
    rst = 1;
    md_req = 0;
    md_op = 0;
    md_src1 = 0;
    md_src2 = 0;
    md_src1_signed = 0;
    md_src2_signed = 0;
    md_srclow = 0;
    md_out_sel = 0;
    // De-assert Reset
    #100 rst = 0;
    md_src1 = 500;
    md_src2 = 6;
    md_op = 0;
    md_req = 1;
    #20 md_req = 0;
    #1500 md_op = 1;
    md_req = 1;
    #20 md_req = 0;
    #1500 md_op = 2;
    md_out_sel = 2;
    md_req = 1;
    #20 md_req = 0;
end

sentry_muldiv DUT (
    .clk                            (clk                            ),
    .rst                            (rst                            ),
    .req                            (md_req                         ),
    .req_op                         (md_op                          ),
    .req_srclow                     (md_srclow                      ),
    .req_src1_signed                (md_src1_signed                 ),
    .req_src2_signed                (md_src2_signed                 ),
    .req_src1                       (md_src1                        ),
    .req_src2                       (md_src2                        ),
    .req_out_sel                    (md_out_sel                     ),
    .ready                          (md_ready                       ),
    .done                           (md_done                        ),
    .out                            (md_result                      )
);

endmodule
// synthesis translate on
