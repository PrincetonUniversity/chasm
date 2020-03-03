// ALU Unit
`include "parameters.svh"
`include "alu_ops.svh"
import TYPES::*;

(* keep_hierarchy = "yes" *)module sentry_alu
(
    input  logic [`ALU_OP_WIDTH-1:0]    op,
    input  data_t                       src1,
    input  data_t                       src2,
    input  logic                        in_sext,
    input  logic                        out_sext,
    input  logic                        srclow,
    input  logic                        resultlow,
    output data_t                       result
);

wire    [`SHAMT_WIDTH-1:0]  shamt    = src2[`SHAMT_WIDTH-1:0];
wire    [`X_LEN-2:0]        FILLBITS = 0;
wire    [`LOWBITS-1:0]      HIBITS   = 0;
data_t                      out;
data_t                      in1;
data_t                      in2;

assign in1 = in_sext ? {{`LOWBITS{src1[31]}}, src1[31:0]} : 
             srclow  ? {HIBITS, src1[`LOWBITS-1:0]}       : src1;

assign in2 = in_sext ? {{`LOWBITS{src2[31]}}, src2[31:0]} : 
             srclow  ? {HIBITS, src2[`LOWBITS-1:0]}       : src2;

always @(op or in1 or in2 or shamt or FILLBITS) begin
    case (op)
        `ALU_OP_ADD : out = in1 + in2;
        `ALU_OP_SLL : out = in1 << shamt;
        `ALU_OP_XOR : out = in1 ^ in2;
        `ALU_OP_OR  : out = in1 | in2;
        `ALU_OP_AND : out = in1 & in2;
        `ALU_OP_SRL : out = in1 >> shamt;
        `ALU_OP_SEQ : out = {FILLBITS, in1 == in2};
        `ALU_OP_SNE : out = {FILLBITS, in1 != in2};
        `ALU_OP_SUB : out = in1 - in2;
        `ALU_OP_SRA : out = $signed(in1) >>> shamt;
        `ALU_OP_SLT : out = {FILLBITS, $signed(in1) < $signed(in2)};
        `ALU_OP_SGE : out = {FILLBITS, $signed(in1) >= $signed(in2)};
        `ALU_OP_SLTU : out = {FILLBITS, in1 < in2};
        `ALU_OP_SGEU : out = {FILLBITS, in1 >= in2};
        default : out = 0;
    endcase // case op
end

assign result = resultlow ? {{`LOWBITS{1'b0}}, out[31:0]}     :
                out_sext  ? {{`LOWBITS{out[31]}}, out[31:0]}  :  out;

endmodule

