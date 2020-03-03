`ifndef _encodings_vh_
`define _encodings_vh_

/* 
* Opcode + Funct3 + Funct7 
*/

// RV32/64 I
`define RV32_LUI      7'b0110111  // 0x37
`define RV32_AUIPC    7'b0010111  // 0x17
`define RV32_JAL      7'b1101111  // 0x6f
`define RV32_JALR     7'b1100111  // 0x67
`define RV32_BRANCH   7'b1100011  // 0x63
// Branch Funct3 encodings
`define RV32_FUNCT3_BEQ  0
`define RV32_FUNCT3_BNE  1
`define RV32_FUNCT3_BLT  4
`define RV32_FUNCT3_BGE  5
`define RV32_FUNCT3_BLTU 6
`define RV32_FUNCT3_BGEU 7

`define RV32_LOAD     7'b0000011  // 0x03
// Load Funct3 encodings
`define RV32_FUNCT3_LB  0
`define RV32_FUNCT3_LH  1
`define RV32_FUNCT3_LW  2
`define RV32_FUNCT3_LD  3
`define RV32_FUNCT3_LBU 4
`define RV32_FUNCT3_LHU 5
`define RV32_FUNCT3_LWU 6

`define RV32_STORE    7'b0100011  // 0x23
// Store Funct3 encodings
`define RV32_FUNCT3_SB  0
`define RV32_FUNCT3_SH  1
`define RV32_FUNCT3_SW  2
`define RV32_FUNCT3_SD  3

`define RV32_OP       7'b0110011  // 0x33
`define RV32_OP_IMM   7'b0010011  // 0x13
`define RV64_OP       7'b0111011  // 0x3b
`define RV64_OP_IMM   7'b0011011  // 0x1b
// Arithmetic FUNCT3 encodings
`define RV32_FUNCT3_ADD_SUB 0
`define RV32_FUNCT3_SLL     1
`define RV32_FUNCT3_SLT     2
`define RV32_FUNCT3_SLTU    3
`define RV32_FUNCT3_XOR     4
`define RV32_FUNCT3_SRA_SRL 5
`define RV32_FUNCT3_OR      6
`define RV32_FUNCT3_AND     7
// MUL/DIV FUNCT7 & FUNCT3 encodings
`define RV32_FUNCT7_MULDIV 7'd1
`define RV64_FUNCT7_MULDIV 7'd1

`define RV32_FUNCT3_MUL    3'd0 // MULW
`define RV32_FUNCT3_MULH   3'd1
`define RV32_FUNCT3_MULHSU 3'd2
`define RV32_FUNCT3_MULHU  3'd3
`define RV32_FUNCT3_DIV    3'd4 // DIVW
`define RV32_FUNCT3_DIVU   3'd5 // DIVUW
`define RV32_FUNCT3_REM    3'd6 // REMW
`define RV32_FUNCT3_REMU   3'd7 // REMUW


`define RV32_SYSTEM   7'b1110011  // 0x73
`define RV32_MISC_MEM 7'b0001111  // 0x0f FENCE/FENCE.I

// RV32/64 A (Atomic)
`define RV32_AMO      7'b0101111  // 0x2f

// RV32/64 F/D
`define RV32_LOAD_FP  7'b0000111
`define RV32_STORE_FP 7'b0100111 
`define RV32_MADD     7'b1000011
`define RV32_MSUB     7'b1000111
`define RV32_NMADD    7'b1001111
`define RV32_NMSUB    7'b1001011
`define RV32_OP_FP    7'b1010011

// RV TrustGuard Encoding
`define RV_LOAD_UNT       7'b0011111
`define RV_STORE_UNT_NET  7'b0111111
`define RV_RECV_UNT       7'b1011111

`define RV_FUNCT3_PUT 3'd5
`define RV_FUNCT3_GET 3'd4

// 7'b1101011 is reserved
// 7'b1010111 is reserved
// 7'b1110111 is reserved
// 7'b0011011 is RV3264-specific
// 7'b0111011 is RV3264-specific

`endif
