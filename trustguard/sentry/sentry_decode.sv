// Sentry Decode Stage
`timescale 1ns/1ps
`include "parameters.svh"
`include "encodings.svh" 
`include "alu_ops.svh" 
`include "muldiv_ops.svh" 
import TYPES::*;

module sentry_decode (
    // Incoming Instruction and Result Request
    input  logic                            inst_valid,
    input  addr_t                           PC,
    input  inst_t                           instruction,
    input  data_t                           result,
    input  tag_t                            tag,
    // Register File Control
    output logic [`REG_ADDR_WIDTH-1:0]      rs1,
    output logic [`REG_ADDR_WIDTH-1:0]      rs2,
    input  data_t                           rs1_data,
    input  data_t                           rs2_data,
    output logic                            rd_wr_en,
    output logic [`REG_ADDR_WIDTH-1:0]      rd,
    output data_t                           rd_data,
    // Network Buffer Control (Programmed I/O) 
    // Outgoing Put Request, forward it onto network request queues
    output logic                            net_put_req,
    output tag_result_t                     net_put_pkt,
    // Outgoing Get Request, forward it onto network request queues
    output logic                            net_get_req,
    output tag_t                            net_get_tag,
    // LSU Control
    output logic                            lsu_req,
    output inst_t                           lsu_instruction,
    output data_t                           lsu_data,
    output tag_t                            lsu_tag,
    // ALU Control
    output logic                            alu_req,
    output logic [`ALU_OP_WIDTH-1:0]        alu_op,
    output logic                            alu_in_sext,
    output logic                            alu_out_sext,
    output logic                            alu_srclow,
    output logic                            alu_resultlow,
    output data_t                           alu_src1,
    output data_t                           alu_src2,
    input  data_t                           alu_result,
    // Multiply Divide Unit Control
    output logic                            md_req,
    output logic [`MD_OP_WIDTH-1:0]         md_op,
    output logic                            md_srclow,
    output logic                            md_src1_signed,
    output logic                            md_src2_signed,
    output data_t                           md_src1,
    output data_t                           md_src2,
    output logic [`MD_OUT_SEL_WIDTH-1:0]    md_out_sel,
    input  data_t                           md_result,
    // ALU Result
    output logic                            result_alu_select,
    // Multiply/Divide Result
    output logic                            result_md_select,
    // Memory Operation Result
    output logic                            result_mem_select,
    // Network Operation Result
    output logic                            result_net_select,
    // Bypass Check Result
    output logic                            result_bypass_select,
    // Untrusted Host Result and Tag
    output data_t                           host_result,
    output tag_t                            host_tag,
    // clock and reset
    input                                   clk,
    input                                   rst

);

// Instruction Decoded to Control Logic (Cycle 0)
wire [6:0]                      OPCODE;
wire [2:0]                      FUNCT3;
wire [6:0]                      FUNCT7;
data_t                          IMMI;
data_t                          IMMS;
data_t                          IMMSB;
data_t                          IMMU;
data_t                          IMMUJ;
data_t                          imm_data; // Immediate Offset 
wire                            inst_is_load;
wire                            inst_is_store;
wire                            inst_is_mem;

// Instruction Decoded to Control Logic (Cycle 0)
assign OPCODE           = instruction[ 6: 0];
assign FUNCT3           = instruction[14:12];
assign FUNCT7           = instruction[31:25];
assign IMMI             = {{(`X_LEN-12){instruction[31]}}, instruction[31:20]}; 
assign IMMS             = {{(`X_LEN-12){instruction[31]}}, instruction[31:25], instruction[11:7]};
assign IMMSB            = {{(`X_LEN-13){instruction[31]}}, instruction[31], instruction[7], instruction[31:25], instruction[11:8], 1'b0};
assign IMMU             = {{(`X_LEN-32){instruction[31]}}, instruction[31:12], 12'b0};
assign IMMUJ            = {{(`X_LEN-21){instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
assign inst_is_load     = inst_valid && ((OPCODE == `RV32_LOAD) || (OPCODE == `RV_LOAD_UNT));
assign inst_is_store    = inst_valid && ((OPCODE == `RV32_STORE) || ((OPCODE == `RV_STORE_UNT_NET) && (FUNCT3 < 4)));
assign inst_is_mem      = inst_is_load || inst_is_store;

// Next PC Generation (Cycle 0)
addr_t PCP4;
addr_t PCIMM;

// next PCs (Cycle 0)
assign PCP4     = PC + 4;
assign PCIMM    = PC + imm_data;

// Register Control (Cycle 0)
assign rs1      = instruction[19:15];
assign rs2      = instruction[24:20];
assign rd       = instruction[11: 7];
assign rd_wr_en =  inst_valid && ((OPCODE == `RV32_LUI) || (OPCODE == `RV32_AUIPC) || (OPCODE == `RV32_JAL) || (OPCODE == `RV32_JALR)
                || (OPCODE == `RV32_LOAD) || (OPCODE == `RV_LOAD_UNT)
                || (OPCODE == `RV_RECV_UNT) || ((OPCODE == `RV_STORE_UNT_NET) && (FUNCT3 == `RV_FUNCT3_GET)) // NETWORK GET
                || (OPCODE == `RV32_OP) || (OPCODE == `RV32_OP_IMM) || (OPCODE == `RV64_OP) || (OPCODE == `RV64_OP_IMM));
assign rd_data  = OPCODE == `RV32_JAL || OPCODE == `RV32_JALR ? PCP4 : result; // jal(r) instructions store pc+4 to rd

// Immediate Data (Cycle 0)
always @(*) begin
    imm_data = 0;
    case (OPCODE)
        `RV32_LUI:    imm_data = IMMU;
        `RV32_AUIPC:  imm_data = IMMU;
        `RV32_JAL:    imm_data = IMMUJ;
        `RV32_JALR:   imm_data = IMMI;
        `RV32_OP_IMM: imm_data = IMMI;
        `RV64_OP_IMM: imm_data = IMMI;
        `RV32_BRANCH: imm_data = IMMSB;
        `RV32_LOAD:   imm_data = IMMI;
        `RV_LOAD_UNT: imm_data = IMMI;
        `RV32_STORE:  imm_data = IMMS;
        `RV_STORE_UNT_NET: begin
            if(FUNCT3 < 4) begin
                imm_data = IMMS;
            end
        end
        default:      imm_data = 0;
    endcase
end

// Load Store Unit(LSU) Controls (Cycle 1)
always @(posedge clk) begin
    lsu_req         <= inst_valid && ((OPCODE == `RV32_LOAD) || (OPCODE == `RV_LOAD_UNT) 
                    || (OPCODE == `RV32_STORE) || (OPCODE == `RV_STORE_UNT_NET && FUNCT3 < 4));
    lsu_instruction <= instruction;
    lsu_data        <= rs2_data;
    lsu_tag         <= tag;
end

// ALU Opcodes (Cycle 1)
always @(posedge clk) begin
    if(OPCODE == `RV32_BRANCH) begin
        case (FUNCT3)
            // BRANCH
            `RV32_FUNCT3_BEQ     : alu_op <= `ALU_OP_SEQ;
            `RV32_FUNCT3_BNE     : alu_op <= `ALU_OP_SNE;
            `RV32_FUNCT3_BLT     : alu_op <= `ALU_OP_SLT;
            `RV32_FUNCT3_BLTU    : alu_op <= `ALU_OP_SLTU;
            `RV32_FUNCT3_BGE     : alu_op <= `ALU_OP_SGE;
            `RV32_FUNCT3_BGEU    : alu_op <= `ALU_OP_SGEU;
            default              : alu_op <= 0;
        endcase
    end else if(OPCODE == `RV32_AUIPC) begin
        alu_op <= `ALU_OP_ADD;
        // 32bit alu op and 32 bit alu op imm and 64bit alu op does not need sign
        // extension
    end else if(OPCODE == `RV32_LUI) begin
        alu_op <= `ALU_OP_ADD;
    end else if(inst_is_mem) begin
        alu_op <= `ALU_OP_ADD; // load: rs1_data + immi; store: rs1_data + imms
    end else if((OPCODE == `RV32_OP) || (OPCODE == `RV32_OP_IMM) || (OPCODE == `RV64_OP) || (OPCODE == `RV64_OP_IMM)) begin
        case (FUNCT3)
            `RV32_FUNCT3_ADD_SUB : alu_op <= (((OPCODE==`RV32_OP) || (OPCODE==`RV64_OP)) && FUNCT7[5]) ? `ALU_OP_SUB : `ALU_OP_ADD;
            `RV32_FUNCT3_SLL     : alu_op <= `ALU_OP_SLL;
            `RV32_FUNCT3_SLT     : alu_op <= `ALU_OP_SLT;
            `RV32_FUNCT3_SLTU    : alu_op <= `ALU_OP_SLTU;
            `RV32_FUNCT3_XOR     : alu_op <= `ALU_OP_XOR;
            `RV32_FUNCT3_SRA_SRL : alu_op <= FUNCT7[5] ? `ALU_OP_SRA : `ALU_OP_SRL;
            `RV32_FUNCT3_OR      : alu_op <= `ALU_OP_OR;
            `RV32_FUNCT3_AND     : alu_op <= `ALU_OP_AND;
            default              : alu_op <= 0;
        endcase
    end else begin
        alu_op <= 0;
    end
end

// ALU Controls (Cycle 1)
always @(posedge clk) begin
    alu_req         <= inst_valid && ((OPCODE == `RV32_AUIPC) || (OPCODE == `RV32_OP && FUNCT7 != `RV32_FUNCT7_MULDIV) 
                    || (OPCODE == `RV32_OP_IMM) || (OPCODE == `RV64_OP && FUNCT7 != `RV64_FUNCT7_MULDIV) 
                    || (OPCODE == `RV64_OP_IMM) || (OPCODE == `RV32_LUI) // LUI will be 0 + immediate data
                    || (OPCODE == `RV32_JAL) || (OPCODE == `RV32_JALR) || (OPCODE == `RV32_BRANCH)
                    );
    // for auipc, result is PC + immU
    alu_in_sext     <= ((OPCODE == `RV64_OP) || (OPCODE == `RV64_OP_IMM)) && (FUNCT3 == `RV32_FUNCT3_SRA_SRL) && FUNCT7[5];
    alu_out_sext    <= (OPCODE == `RV64_OP) || (OPCODE == `RV64_OP_IMM);
    alu_srclow      <= (OPCODE == `RV64_OP) || (OPCODE == `RV64_OP_IMM); 
    //assign alu_resultlow = ((OPCODE == `RV64_OP) || (OPCODE == `RV64_OP_IMM)) && (FUNCT3 != `RV32_FUNCT3_ADD_SUB);
    //hack to limit srlw to 32bit only
    alu_resultlow   <= (OPCODE == `RV64_OP) && (FUNCT3 == `RV32_FUNCT3_SRA_SRL) && (FUNCT7[5] == 0);
    alu_src1        <= (OPCODE == `RV32_AUIPC || OPCODE == `RV32_JAL)   ? PC : 
                       (OPCODE == `RV32_LUI)                            ? 0 : rs1_data;
    alu_src2        <= ((OPCODE == `RV32_BRANCH) || (OPCODE == `RV32_OP) || (OPCODE == `RV64_OP)) ? rs2_data : imm_data;
end

// Multiply Divide Unit Opcodes (Cycle 1)
always @(posedge clk) begin
    if (((OPCODE == `RV32_OP) && (FUNCT7 == `RV32_FUNCT7_MULDIV)) || ((OPCODE == `RV64_OP) && (FUNCT7 == `RV64_FUNCT7_MULDIV))) begin
        // TODO, right now muldiv is the only thing decode request to, need to
        // make sure requrest only happen when pipe_req is high
        md_req      <= inst_valid;
        md_src1     <= rs1_data;
        md_src2     <= rs2_data;
        md_srclow   <= (OPCODE == `RV64_OP);
        case (FUNCT3)
            `RV32_FUNCT3_MUL    : begin
                md_op           <= `MD_OP_MUL;
                md_out_sel      <= `MD_OUT_LO;
                md_src1_signed  <= 0;
                md_src2_signed  <= 0;
            end
            `RV32_FUNCT3_MULH   : begin
                md_op           <= `MD_OP_MUL;
                md_out_sel      <= `MD_OUT_HI;
                md_src1_signed  <= 1;
                md_src2_signed  <= 1;
            end
            `RV32_FUNCT3_MULHSU : begin
                md_op           <= `MD_OP_MUL;
                md_out_sel      <= `MD_OUT_HI;
                md_src1_signed  <= 1;
                md_src2_signed  <= 0;
            end
            `RV32_FUNCT3_MULHU  : begin
                md_op           <= `MD_OP_MUL;
                md_out_sel      <= `MD_OUT_HI;
                md_src1_signed  <= 0;
                md_src2_signed  <= 0;
            end
            `RV32_FUNCT3_DIV    : begin
                md_op           <= `MD_OP_DIV;
                md_out_sel      <= `MD_OUT_LO;
                md_src1_signed  <= 1;
                md_src2_signed  <= 1;
            end
            `RV32_FUNCT3_DIVU   : begin
                md_op           <= `MD_OP_DIV;
                md_out_sel      <= `MD_OUT_LO;
                md_src1_signed  <= 0;
                md_src2_signed  <= 0;
            end
            `RV32_FUNCT3_REM    : begin
                md_op           <= `MD_OP_REM;
                md_out_sel      <= `MD_OUT_REM;
                md_src1_signed  <= 1;
                md_src2_signed  <= 1;
            end
            `RV32_FUNCT3_REMU   : begin
                md_op           <= `MD_OP_REM;
                md_out_sel      <= `MD_OUT_REM;
                md_src1_signed  <= 0;
                md_src2_signed  <= 0;
            end
            default             : begin
                md_op           <= 0;
                md_out_sel      <= 0;
                md_src1_signed  <= 0;
                md_src2_signed  <= 0;
            end
        endcase
    end
    else begin
        md_req          <= 0;
        md_src1         <= 0;
        md_src2         <= 0;
        md_srclow       <= 0;
        md_op           <= 0;
        md_out_sel      <= 0;
        md_src1_signed  <= 0;
        md_src2_signed  <= 0;
    end
end

// Programmed I/O via Network Buffer
// Network Buffer Control (Cycle 1)
wire network_get = (OPCODE == `RV_STORE_UNT_NET) && (FUNCT3 == `RV_FUNCT3_GET);
wire network_put = (OPCODE == `RV_STORE_UNT_NET) && (FUNCT3 == `RV_FUNCT3_PUT);
always @(posedge clk) begin
    net_get_req         <= inst_valid && network_get;
    net_get_tag         <= tag;
    net_put_req         <= inst_valid && network_put;
    net_put_pkt.tag     <= tag;
    net_put_pkt.result  <= rs1_data;
end

wire    [`X_LEN-2:0]        FILLBITS = 0;
// Checking Unit Control (Cycle 1)
always @(posedge clk) begin
    if(rst) begin
        result_alu_select   <= 0;
        result_md_select    <= 0;
        result_mem_select   <= 0;
        result_net_select   <= 0;
        result_bypass_select<= 0;
    end
    else begin
        // For alu operations, check all operations
        result_alu_select   <= inst_valid && ((OPCODE == `RV32_AUIPC) || (OPCODE == `RV32_OP && FUNCT7 != `RV32_FUNCT7_MULDIV) || (OPCODE == `RV32_OP_IMM) 
                            || (OPCODE == `RV64_OP && FUNCT7 != `RV64_FUNCT7_MULDIV) || (OPCODE == `RV64_OP_IMM) || (OPCODE == `RV32_LUI) // LUI will be 0 + immediate data
                            || (OPCODE == `RV32_JAL) || (OPCODE == `RV32_JALR) || (OPCODE == `RV32_BRANCH));
        // For multiply and divide operation, check all result
        result_md_select    <= inst_valid && ((OPCODE == `RV32_OP) || (OPCODE == `RV64_OP)) && (FUNCT7 == `RV32_FUNCT7_MULDIV);
        // For memory, only loads need to be checked to see if host loaded the correct value
        result_mem_select   <= inst_valid && ((OPCODE == `RV32_LOAD) || (OPCODE == `RV_LOAD_UNT));
        // For network, only GET operations need to be checked to see if host got the correct value
        result_net_select   <= inst_valid && (OPCODE == `RV_STORE_UNT_NET) && (FUNCT3 == `RV_FUNCT3_GET);
        // For instructions that do not need to be checked (like stores), activate bypass tag channel
        result_bypass_select<= inst_valid && ((OPCODE == `RV32_STORE) || ((OPCODE == `RV_STORE_UNT_NET) && (FUNCT3 < 4)) || network_put || (OPCODE == `RV_RECV_UNT));
        // Untrusted Host Result
        host_result         <= (OPCODE == `RV32_BRANCH) ? {FILLBITS, (result == PCIMM)} : result; // if branch instruciton, compare the result 
        host_tag            <= tag;
    end
end


`ifdef SIMULATION1
    reg [511:0] instruction_string;
    always @(instruction or OPCODE or FUNCT3 or FUNCT7) begin
        if(inst_valid) begin
            $display("PC: %h, instruction: %h, result: %h\n", PC, instruction, result);
            $display("opcode %h, funct3 %h, funct7 %h, rs1 %d, rs2 %d, rd %d\n", OPCODE, FUNCT3, FUNCT7, rs1, rs2, rd);
            $display("immediates: immI %h, immS %h, immSB %h, immU %h, immUJ %h\n", IMMI, IMMS, IMMSB, IMMU, IMMUJ);
            case (OPCODE)
                // TG EXTENSION
                `RV_LOAD_UNT: begin
                    instruction_string = "LOAD.UNT";
                    $display("Load Untrusted\n");
                end
                `RV_STORE_UNT_NET: begin
                    case (FUNCT3)
                        `RV_FUNCT3_PUT: instruction_string = "PUT";
                        `RV_FUNCT3_GET: instruction_string = "GET";
                        default:        instruction_string = "STORE.UNT";
                    endcase
                    $display("Store Untrusted or PUT or GET \n");
                end
                `RV_RECV_UNT: begin
                    instruction_string = "RECV.UNT";
                    $display("Sentry recv untrusted\n");
                end
                // RISCV ORIGINAL
                `RV32_LUI: begin
                    instruction_string = "LUI";
                    $display("LUI\n");
                end
                `RV32_AUIPC: begin
                    instruction_string = "AUIPC";
                    $display("AUIPC\n");
                end
                `RV32_JAL: begin
                    instruction_string = "JAL";
                    $display("JAL\n");
                end
                `RV32_JALR: begin
                    instruction_string = "JALR";
                    $display("JALR\n");
                end
                // Branch
                `RV32_BRANCH: begin
                    instruction_string = "BRANCH";
                    $display("BRANCH:\t");
                    case (FUNCT3)
                        `RV32_FUNCT3_BEQ: begin
                            $display("BEQ\n");
                        end
                        `RV32_FUNCT3_BNE: begin
                            $display("BNE\n");
                        end
                        `RV32_FUNCT3_BLT: begin
                            $display("BLT\n");
                        end
                        `RV32_FUNCT3_BGE: begin
                            $display("BGE\n");
                        end
                        `RV32_FUNCT3_BLTU: begin
                            $display("BLTU\n");
                        end
                        `RV32_FUNCT3_BGEU: begin
                            $display("BGEU\n");
                        end
                    endcase
                end
                // Load
                `RV32_LOAD: begin
                    instruction_string = "LOAD";
                    $display("LOAD:\t");
                    case (FUNCT3)
                        `RV32_FUNCT3_LB: begin
                            $display("LB\n");
                        end
                        `RV32_FUNCT3_LH: begin
                            $display("LH\n");
                        end
                        `RV32_FUNCT3_LW: begin
                            $display("LW\n");
                        end
                        `RV32_FUNCT3_LD: begin
                            $display("LD\n");
                        end
                        `RV32_FUNCT3_LBU: begin
                            $display("LBU\n");
                        end
                        `RV32_FUNCT3_LHU: begin
                            $display("LHU\n");
                        end
                        `RV32_FUNCT3_LWU: begin
                            $display("LWU\n");
                        end
                    endcase
                end
                // Store
                `RV32_STORE: begin
                    instruction_string = "STORE";
                    $display("STORE:\t");
                    case (FUNCT3)
                        `RV32_FUNCT3_SB: begin
                            $display("SB\n");
                        end
                        `RV32_FUNCT3_SH: begin
                            $display("SH\n");
                        end
                        `RV32_FUNCT3_SW: begin
                            $display("SW\n");
                        end
                        `RV32_FUNCT3_SD: begin
                            $display("SD\n");
                        end
                    endcase
                end
                // ALU 32bit OP
                `RV32_OP: begin
                    case (FUNCT7)
                        `RV32_FUNCT7_MULDIV: begin
                            if(FUNCT3 < 4) begin
                                $display("ALU 32 MUL\n");
                                instruction_string = "ALU 32 MUL";
                            end
                            else begin
                                $display("ALU 32 DIV\n");
                                instruction_string = "ALU 32 DIV";
                            end
                        end
                        default: begin
                            $display("ALU 32 OP\n");
                            instruction_string = "ALU 32 OP";
                        end
                    endcase
                end
                `RV32_OP_IMM: begin
                    instruction_string = "ALU IMM 32";
                    $display("ALU 32 OP IMM\n");
                end
                `RV64_OP: begin
                    case (FUNCT7)
                        `RV32_FUNCT7_MULDIV: begin
                            if(FUNCT3 < 4) begin
                                $display("ALU 64 MUL\n");
                                instruction_string = "ALU 64 MUL";
                            end
                            else begin
                                $display("ALU 64 DIV\n");
                                instruction_string = "ALU 64 DIV";
                            end
                        end
                        default: begin
                            $display("ALU 64 OP\n");
                            instruction_string = "ALU 64 OP";
                        end
                    endcase
                end
                `RV64_OP_IMM: begin
                    instruction_string = "ALU IMM 64";
                    $display("ALU 64 OP IMM\n");
                end
                `RV32_SYSTEM: begin
                    $display("SYSTEM\n");
                end
                `RV32_MISC_MEM: begin
                    $display("FENCE/FENCE.I\n");
                end
                default: $display("Unhandled instruction format !\n");
            endcase
        end
    end
`endif


endmodule

