// Multiply/Divide Unit
`include "parameters.svh"
`include "muldiv_ops.svh"
import TYPES::*;

module sentry_muldiv_pipe (
    input  logic                            clk,
    input  logic                            req,
    input  logic  [`MD_OP_WIDTH-1:0]        req_op,
    input  logic                            req_srclow,
    input  logic                            req_src1_signed,
    input  logic                            req_src2_signed,
    input  data_t                           req_src1,
    input  data_t                           req_src2,
    input  logic [`MD_OUT_SEL_WIDTH-1:0]    req_out_sel,
    output logic                            done,
    output data_t                           out
);

localparam PSTAGE = 65;

genvar i, j;
// Input Resolve
wire [`LOWBITS-1:0] FILLBITS = 0;

data_t src1;
data_t src2;

wire src1_sign = req_src1_signed & req_src1[`X_LEN-1];
wire src2_sign = req_src2_signed & req_src2[`X_LEN-1];

assign src1 = req_srclow                                ? {FILLBITS, req_src1[`LOWBITS-1:0]} : 
              (req_src1_signed && req_src1[`X_LEN-1])   ? -req_src1 : req_src1;
assign src2 = req_srclow                                ? {FILLBITS, req_src2[`LOWBITS-1:0]} :
              (req_src2_signed && req_src2[`X_LEN-1])   ? -req_src2 : req_src2;

// control logic
reg [`DOUBLE_X_LEN-1:0]     a           [0:PSTAGE-1];
data_t                      b           [0:PSTAGE-1];
reg                         out_negate  [0:PSTAGE-1];
reg [`MD_OP_WIDTH-1:0]      op          [0:PSTAGE-1];
reg [`MD_OUT_SEL_WIDTH-1:0] out_sel     [0:PSTAGE-1];
wire [`DOUBLE_X_LEN-1:0]    add         [0:PSTAGE-1];
wire [`DOUBLE_X_LEN-1:0]    sub         [0:PSTAGE-1];
reg                         valid       [0:PSTAGE-1];

generate
for(i = 0; i < PSTAGE; i=i+1) begin : COMPUTE
    assign add[i] = a[i] + {b[i], `X_LEN'd0};
    assign sub[i] = (a[i] << 1) - {b[i], `X_LEN'd0};
    always @(posedge clk) begin
        if(i == 0) begin
                a[i]            <= {`X_LEN'd0,src1};
                b[i]            <= src2;
                out_negate[i]   <= (req_op == `MD_OP_REM) ? src1_sign : src1_sign ^ src2_sign;
                op[i]           <= req_op;
                out_sel[i]      <= req_out_sel;
                valid[i]        <= req;
        end
        else if(i < PSTAGE) begin
            b[i]            <= b[i-1];
            out_negate[i]   <= out_negate[i-1];
            op[i]           <= op[i-1];
            out_sel[i]      <= out_sel[i-1];
            valid[i]        <= valid[i-1];
            if (op[i-1] == `MD_OP_MUL) begin
                if (a[i-1][0]) begin
                    a[i]  <= add[i-1] >> 1;
                end
                else begin
                    a[i]  <= a[i-1] >> 1;
                end
            end 
            else begin
                if (a[i-1][`X_LEN-1+:`X_LEN] >= b[i-1]) begin
                    a[i]  <= {sub[i-1][`DOUBLE_X_LEN-1:1], 1'b1};
                end
                else begin
                    a[i]  <= {a[i-1][`DOUBLE_X_LEN-2:0], 1'b0};
                end
            end
        end
    end
end
endgenerate


wire  [`DOUBLE_X_LEN-1:0] result_muxed = (out_sel[PSTAGE-1] == `MD_OUT_REM) ? a[PSTAGE-1][`X_LEN+:`X_LEN] : a[PSTAGE-1][0+:`X_LEN];
wire  [`DOUBLE_X_LEN-1:0] result_muxed_negated = (out_negate[PSTAGE-1]) ? -result_muxed : result_muxed;

assign done = valid[PSTAGE-1];
assign out = (out_sel[PSTAGE-1] == `MD_OUT_HI) ? result_muxed_negated[`X_LEN+:`X_LEN] : result_muxed_negated[0+:`X_LEN];

endmodule

// synthesis translate off
module sentry_muldiv_pipe_tb();

reg clk;
reg md_req;
reg [`MD_OP_WIDTH-1:0] md_op;
reg md_srclow;
reg md_src1_signed;
reg md_src2_signed;
data_t  md_src1;
data_t  md_src2;
reg [`MD_OUT_SEL_WIDTH-1:0] md_out_sel;
wire md_done;
data_t md_result;

integer i;

always begin
    #10 clk = ~clk;
end

initial begin
    clk = 1;
    md_req = 0;
    md_op = 0;
    md_src1 = 0;
    md_src2 = 0;
    md_src1_signed = 0;
    md_src2_signed = 0;
    md_srclow = 0;
    md_out_sel = 0;
    // De-assert Reset
    // multiply by 1
    #100;
    md_src1 = 1;
    md_op = 0;
    md_req = 1;
    for(i = 1; i <= 100; i = i+1) begin
        md_src2 = i;
        #20;
    end
    md_req = 0;

    // multiply by -1
    #100;
    md_src1 = -1;
    md_op = 0;
    md_req = 1;
    for(i = 1; i <= 100; i = i+1) begin
        md_src2 = i;
        #20;
    end
    md_req = 0;

    // square
    #100;
    md_op = 0;
    md_req = 1;
    for(i = 1; i <= 100; i = i+1) begin
        md_src1 = i;
        md_src2 = i;
        #20;
    end
    md_req = 0;

    // TODO
    #1500 md_op = 1;
    md_req = 1;
    #20 md_req = 0;
    #1500 md_op = 2;
    md_out_sel = 2;
    md_req = 1;
    #20 md_req = 0;
end

sentry_muldiv_pipe DUT (
    .clk                            (clk                            ),
    .req                            (md_req                         ),
    .req_op                         (md_op                          ),
    .req_srclow                     (md_srclow                      ),
    .req_src1_signed                (md_src1_signed                 ),
    .req_src2_signed                (md_src2_signed                 ),
    .req_src1                       (md_src1                        ),
    .req_src2                       (md_src2                        ),
    .req_out_sel                    (md_out_sel                     ),
    .done                           (md_done                        ),
    .out                            (md_result                      )
);

endmodule
// synthesis translate on
