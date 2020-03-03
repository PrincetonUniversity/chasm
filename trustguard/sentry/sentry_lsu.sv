// Load Store Unit
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

module sentry_lsu
(
    // data pkt1
    output logic                    data_pkt1_fifo_rd_en,
    input  pkt1_t                   data_pkt1_fifo_output,
    input  logic                    data_pkt1_fifo_empty,
    input  logic                    data_pkt1_fifo_almost_empty,
    // data pkt2
    output logic                    data_pkt2_fifo_rd_en,
    input  pkt2_t                   data_pkt2_fifo_output,
    input  logic                    data_pkt2_fifo_empty,
    input  logic                    data_pkt2_fifo_almost_empty,
    // data vpkt
    output logic                    data_vpkt_fifo_rd_en,
    input  vpkt_t                   data_vpkt_fifo_output,
    input  logic                    data_vpkt_fifo_empty,
    input  logic                    data_vpkt_fifo_almost_empty,
    `ifdef SMAC
        // data pkt3
        output logic                    data_pkt3_fifo_rd_en,
        input  pkt3_t                   data_pkt3_fifo_output,
        input  logic                    data_pkt3_fifo_empty,
        input  logic                    data_pkt3_fifo_almost_empty,
    `endif
    // Interface to Victim CAM
    output logic                    victim_cam_en,
    output vindex_t                 victim_cam_index,
    // Control Signals from Decode Stage
    input  logic                    lsu_req,
    input  inst_t                   lsu_instruction,
    input  tag_t                    lsu_tag,
    input  data_t                   lsu_data,
    input  addr_t                   lsu_addr,
    // Stall signal to each other pipeline
    `ifdef DCACHE_OPT
        input  logic                    lsu_stall,
        input  logic                    lsu_enable,
        output logic                    inst_valid_out,
    `endif
    // Control Signals to DCache Control
    // need to send byte, hword, word, dword, qword selects and original line
    // 1 cycle later they are used to determine the actual cache wr line
    output en_t                         cache_ens,
    output en_t                         cache_evicts,
    output logic [`LINE_WIDTH_BYTE-1:0] cache_wr_en_byte,
    output addr_t                       cache_wr_addr,
    output line_t                       cache_wr_line,
    // cache write update signals
    output logic                    victim_byte_sel,
    output logic                    victim_hword_sel,
    output logic                    victim_word_sel,
    output logic                    victim_dword_sel,
    output logic [1:0]              victim_qword_sel,
    output logic                    victim_byte_write,
    output logic                    victim_hword_write,
    output logic                    victim_word_write,
    output logic                    victim_dword_write,
    output logic [7:0]              victim_write_byte,
    output logic [15:0]             victim_write_hword,
    output logic [31:0]             victim_write_word,
    output logic [63:0]             victim_write_dword,
    // Cache Read Control
    output addr_t                   cache_rd_addr,
    input  line_t                   cache_rd_line,
    // Result Signals to Checking Stage
    output logic                    check_mem_ready,
    output data_t                   check_mem_out,
    // clock and reset
    input  logic                    clk,
    input  logic                    rst
);

genvar i, j, k;

// LSU Request Inst Ready
wire [6:0]                      OPCODE;
wire [2:0]                      FUNCT3;
reg  [2:0]                      FUNCT3_reg; // Cycle 1
wire [6:0]                      FUNCT7;
wire                            inst_valid;
inst_t                          lsu_inst;
// Data PKT FIFOs Ready
wire                            data_ready;
reg                             data_ready_reg;

// Load Store Unit Control Logic (Cycle 0)
wire                            inst_is_load;
wire                            inst_is_store;
wire                            inst_is_mem;
wire                            store_byte;
wire                            store_hword;
wire                            store_word;
wire                            store_dword;
addr_t                          mem_address;
wire [`BYTE_OFFSET_WIDTH-1:0]   offset;
addr_t                          offset_mask = (1 << `BYTE_OFFSET_WIDTH) - 1;
// mem store selects
wire                            byte_sel;
wire                            hword_sel;
wire                            word_sel;
wire                            dword_sel;
wire [1:0]                      qword_sel;
// mem store selects
reg                             byte_sel_reg;
reg                             hword_sel_reg;
reg                             word_sel_reg;
reg                             dword_sel_reg;
reg  [1:0]                      qword_sel_reg;
// cache read
wire [127:0]                    cache_rd_qword;
wire [63:0]                     cache_rd_dword;
wire [31:0]                     cache_rd_word;
wire [15:0]                     cache_rd_hword;
wire [7:0]                      cache_rd_byte;
// Cache Write Line Before
reg                             byte_write;
reg                             hword_write;
reg                             word_write;
reg                             dword_write;
reg  [7:0]                      write_byte;
reg  [15:0]                     write_hword;
reg  [31:0]                     write_word;
reg  [63:0]                     write_dword;
// Cache Write Byte Enable Before
wire [7:0]                      original_byte;
wire [15:0]                     original_hword;
wire [31:0]                     original_word;
wire [63:0]                     original_dword;
wire [127:0]                    original_qword;
wire [511:0]                    original_line;
wire                            original_byte_en;
wire [1 :0]                     original_hword_en;
wire [3 :0]                     original_word_en;
wire [7 :0]                     original_dword_en;
wire [15:0]                     original_qword_en;
wire [63:0]                     original_line_en;
// Cache Write Line After
wire [7:0]                      updated_byte;
wire [15:0]                     updated_hword;
wire [31:0]                     updated_word;
wire [63:0]                     updated_dword;
wire [127:0]                    updated_qword;
wire [511:0]                    updated_line;
// Cache Write Byte Enable After
wire                            updated_byte_en;
wire [1 :0]                     updated_hword_en;
wire [3 :0]                     updated_word_en;
wire [7 :0]                     updated_dword_en;
wire [15:0]                     updated_qword_en;
wire [63:0]                     updated_line_en;

// LSU Request FIFO (used to hold LSU request and wait for data pkt1 and pkt2)
wire                            lsu_req_fifo_wr_en;
lsu_req_t                       lsu_req_fifo_input;
wire                            lsu_req_fifo_rd_en;
lsu_req_t                       lsu_req_fifo_output;
wire                            lsu_req_fifo_full;
wire                            lsu_req_fifo_empty;
wire                            lsu_req_fifo_almost_full;
wire                            lsu_req_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]        lsu_req_fifo_data_count;
`endif

assign lsu_req_fifo_input.tag = lsu_tag;
assign lsu_req_fifo_input.addr = lsu_addr;
assign lsu_req_fifo_input.data = lsu_data;
assign lsu_req_fifo_input.instruction = lsu_instruction;
assign lsu_req_fifo_wr_en = lsu_req;
assign lsu_req_fifo_rd_en = inst_valid;

lsu_req_fifo LSU_REQ_FIFO (
    .clk            (clk                        ),  // input wire clk
    .din            (lsu_req_fifo_input         ),  // input wire [95 : 0] din
    .wr_en          (lsu_req_fifo_wr_en         ),  // input wire wr_en
    .rd_en          (lsu_req_fifo_rd_en         ),  // input wire rd_en
    .dout           (lsu_req_fifo_output        ),  // output wire [95 : 0] dout
    .full           (lsu_req_fifo_full          ),  // output wire full
    .empty          (lsu_req_fifo_empty         ),  // output wire empty
    .almost_full    (lsu_req_fifo_almost_full   ),  // output wire almost_full
    .almost_empty   (lsu_req_fifo_almost_empty  ),  // output wire almost_empty
    `ifdef DATA_COUNT
        .data_count     (lsu_req_fifo_data_count    ),  // output wire [9 : 0] data_count
    `endif
    .srst           (rst                        )   // input wire srst
);

// Instruction Decode
assign OPCODE           = lsu_inst[ 6: 0];
assign FUNCT3           = lsu_inst[14:12];
assign FUNCT7           = lsu_inst[31:25];
// Load Store Unit Control
// (Cycle 0 @ all fifo ready)
`ifdef DCACHE_OPT
    always @(posedge clk) begin
        inst_valid_out <= inst_valid;
    end
    //assign inst_valid_out = inst_valid;
    assign inst_valid       = !lsu_req_fifo_empty & data_ready & !lsu_stall && lsu_enable; // inst_valid stays high while fifo not empty
`else
    assign inst_valid       = !lsu_req_fifo_empty & data_ready; // inst_valid stays high while fifo not empty
`endif
assign lsu_inst         = lsu_req_fifo_output.instruction;
assign inst_is_load     = inst_valid && ((OPCODE == `RV32_LOAD) || (OPCODE == `RV_LOAD_UNT));
assign inst_is_store    = inst_valid && ((OPCODE == `RV32_STORE) || (OPCODE == `RV_STORE_UNT_NET && FUNCT3 < 4));
assign inst_is_mem      = inst_is_load || inst_is_store;
assign store_byte       = inst_valid && (FUNCT3 == `RV32_FUNCT3_SB);
assign store_hword      = inst_valid && (FUNCT3 == `RV32_FUNCT3_SH);
assign store_word       = inst_valid && (FUNCT3 == `RV32_FUNCT3_SW);
assign store_dword      = inst_valid && (FUNCT3 == `RV32_FUNCT3_SD);
// (Cycle 0)
assign mem_address      = lsu_req_fifo_output.addr;
assign offset           = mem_address[`BYTE_OFFSET_WIDTH-1:0];
assign cache_wr_addr    = mem_address;
assign cache_rd_addr    = mem_address;
// different word select (Cycle 0)
assign byte_sel         = offset[0];
assign hword_sel        = offset[1];
assign word_sel         = offset[2];
assign dword_sel        = offset[3];
assign qword_sel        = offset[5:4];
always @(posedge clk) begin
    victim_byte_sel     <= byte_sel;
    victim_hword_sel    <= hword_sel;
    victim_word_sel     <= word_sel;
    victim_dword_sel    <= dword_sel;
    victim_qword_sel    <= qword_sel;
end
// different rd word select (Cycle 1)
always @(posedge clk) begin
    qword_sel_reg <= qword_sel;
    dword_sel_reg <= dword_sel;
    word_sel_reg <= word_sel;
    hword_sel_reg <= hword_sel;
    byte_sel_reg <= byte_sel;
end
// original line (Cycle 0)
assign original_line    = data_pkt2_fifo_output;
assign original_qword   = original_line[qword_sel*128+:128];
assign original_dword   = original_qword[dword_sel*64+:64];
assign original_word    = original_dword[word_sel*32+:32];
assign original_hword   = original_word[hword_sel*16+:16];
assign original_byte    = original_hword[byte_sel*8+:8];
// original line byte enable (Cycle 0)
//assign original_line_en = data_pkt1_fifo_output.mhb ? {64{1'b1}}: 64'd0;
assign original_line_en = {(`LINE_WIDTH_BYTE){data_pkt1_fifo_output.mhb}}; // if fill, all Fs
assign original_qword_en= original_line_en[qword_sel*16+:16];
assign original_dword_en= original_qword_en[dword_sel*8+:8];
assign original_word_en = original_dword_en[word_sel*4+:4];
assign original_hword_en= original_word_en[hword_sel*2+:2];
assign original_byte_en = original_hword_en[byte_sel*1+:1];
// cache read (Cycle 1)
assign cache_rd_qword   = cache_rd_line[qword_sel_reg*128+:128];
assign cache_rd_dword   = cache_rd_qword[dword_sel_reg*64+:64];
assign cache_rd_word    = cache_rd_dword[word_sel_reg*32+:32];
assign cache_rd_hword   = cache_rd_word[hword_sel_reg*16+:16];
assign cache_rd_byte    = cache_rd_hword[byte_sel_reg*8+:8];
// cache write (Cycle 0)
assign byte_write      = inst_is_store && store_byte;
assign hword_write     = inst_is_store && store_hword; // increment counter
assign word_write      = inst_is_store && store_word;
assign dword_write     = inst_is_store && store_dword;
always @(posedge clk) begin
    victim_byte_write   <= byte_write;
    victim_hword_write  <= hword_write;
    victim_word_write   <= word_write;
    victim_dword_write  <= dword_write;
end
// actual write data (Cycle 0)
assign write_byte      = lsu_req_fifo_output.data[7:0];
assign write_hword     = lsu_req_fifo_output.data[15:0];
assign write_word      = lsu_req_fifo_output.data[31:0];
assign write_dword     = lsu_req_fifo_output.data[63:0];
always @(posedge clk) begin
    victim_write_byte   <= write_byte;
    victim_write_hword  <= write_hword;
    victim_write_word   <= write_word;
    victim_write_dword  <= write_dword;
end
// updated cache line and byte enable (Cycle 0)
assign updated_byte     = byte_write  ?    write_byte  : original_byte;

assign updated_hword    = hword_write ?    write_hword : 
byte_sel    ?    {updated_byte, original_hword[7: 0]} : 
{original_hword[15:8], updated_byte} ;

assign updated_word     = word_write  ?    write_word  : 
hword_sel   ?    {updated_hword, original_word[15: 0]} : 
{original_word[31:16], updated_hword} ;

assign updated_dword    = dword_write ?    write_dword : 
word_sel    ?    {updated_word, original_dword[31: 0]} : 
{original_dword[63:32], updated_word} ;

assign updated_qword    = dword_sel   ?    {updated_dword, original_qword[63 : 0]} : 
{original_qword[127:64], updated_dword} ;

assign cache_wr_line    = qword_sel == 2'b00 ? {original_line[511:128], updated_qword                      } :
qword_sel == 2'b01 ? {original_line[511:256], updated_qword, original_line[127:0]} :
qword_sel == 2'b10 ? {original_line[511:384], updated_qword, original_line[255:0]} :
{                        updated_qword, original_line[383:0]} ;

assign updated_byte_en  = byte_write    ?   1'b1  : original_byte_en;

assign updated_hword_en = hword_write   ?   2'b11                   : 
byte_sel      ?   {updated_byte_en, original_hword_en[0]} :
{original_hword_en[1], updated_byte_en} ;

assign updated_word_en  = word_write    ?   4'hf                        : 
hword_sel     ?   {updated_hword_en, original_word_en[1:0]}   :
{original_word_en[3:2], updated_hword_en}   ;

assign updated_dword_en = dword_write   ?   8'hff : 
word_sel      ?   {updated_word_en, original_dword_en[3:0]}   :
{original_dword_en[7:4], updated_word_en}   ;

assign updated_qword_en = dword_sel     ?   {updated_dword_en, original_qword_en[7:0]}  :
{original_qword_en[15:8], updated_dword_en} ;

assign cache_wr_en_byte = !inst_valid        ?    'd0 :
qword_sel == 2'b00 ?    {original_line_en[63:16], updated_qword_en                        }:
qword_sel == 2'b01 ?    {original_line_en[63:32], updated_qword_en, original_line_en[15:0]}:
qword_sel == 2'b10 ?    {original_line_en[63:48], updated_qword_en, original_line_en[31:0]}:
{                         updated_qword_en, original_line_en[47:0]};
// Incoming Data PKT FIFO (Cycle 0)
assign data_ready   =   data_pkt1_fifo_empty        ? 0 :   // if pkt1 not ready, data not ready
!data_pkt1_fifo_output.mhb  ? 1 :   // if pkt1 ready and data hit, data ready
data_vpkt_fifo_empty        ? 0 :   // if D$ miss and vpkt not ready, data not ready
!data_vpkt_fifo_output.mhb  ? 1 :   // if D$ miss and victim cam hit, data ready from victim cam
data_pkt2_fifo_empty        ? 0 : 1;// if D$ miss, victim cam miss, data ready is pkt2 mem data ready

always @(posedge clk) begin
    data_ready_reg <= data_ready;
end

// For a cache write to happen, way enable need to set correctly
// and byte enable need to be high
// Cache way enable (Cycle 0)
assign cache_ens            = data_pkt1_fifo_output.ens;
assign cache_evicts         = inst_valid ? data_pkt1_fifo_output.evict : 'd0;
assign data_pkt1_fifo_rd_en = inst_valid;
assign data_vpkt_fifo_rd_en = inst_valid && data_pkt1_fifo_output.mhb; // if D$ miss, there must be a vpkt
assign data_pkt2_fifo_rd_en = inst_valid && data_pkt1_fifo_output.mhb && data_vpkt_fifo_output.mhb; // if D$ miss and victim cam miss, there must be a pkt2
`ifdef SMAC
    assign data_pkt3_fifo_rd_en = inst_valid && (!data_pkt3_fifo_empty);
`endif

assign victim_cam_en    = inst_valid && data_pkt1_fifo_output.mhb && !data_vpkt_fifo_output.mhb;
assign victim_cam_index = data_vpkt_fifo_output.vidx;


// Data ready (Cycle 2)
reg inst_is_load_reg;
always @(posedge clk) begin
    inst_is_load_reg <= inst_is_load;
    check_mem_ready <= inst_is_load_reg;
    FUNCT3_reg <= FUNCT3;
end

// cache load data (Cycle 2)
always @(posedge clk) begin
    case(FUNCT3_reg)
        `RV32_FUNCT3_LB:  check_mem_out <= {{(`X_LEN-8){cache_rd_byte[7]}},  cache_rd_byte[7:0]};
        `RV32_FUNCT3_LH:  check_mem_out <= {{(`X_LEN-16){cache_rd_hword[15]}}, cache_rd_hword[15:0]};
        `RV32_FUNCT3_LW:  check_mem_out <= {{(`X_LEN-32){cache_rd_word[31]}}, cache_rd_word[31:0]};
        `RV32_FUNCT3_LD:  check_mem_out <= cache_rd_dword;
        `RV32_FUNCT3_LBU: check_mem_out <= {{(`X_LEN-8){1'b0}},  cache_rd_byte[7:0]};
        `RV32_FUNCT3_LHU: check_mem_out <= {{(`X_LEN-16){1'b0}}, cache_rd_hword[15:0]};
        `RV32_FUNCT3_LWU: check_mem_out <= {{(`X_LEN-32){1'b0}}, cache_rd_word[31:0]};
        default:          check_mem_out <= 0;
    endcase
end

`ifdef SIMULATION
    wire waitfor2 = !data_pkt1_fifo_empty && (data_pkt1_fifo_output.mhb && data_pkt2_fifo_empty);
    wire actualwaitfor2 = !lsu_req_fifo_empty &&  !data_pkt1_fifo_empty && (data_pkt1_fifo_output.mhb && data_pkt2_fifo_empty);
    reg [31:0] waitfor2_cnt;
    reg [31:0] actualwaitfor2_cnt;
    always @(posedge clk) begin
        if(rst) begin
            waitfor2_cnt <= 0;
            actualwaitfor2_cnt <= 0;
        end
        else begin
            if(waitfor2) begin
                waitfor2_cnt <= waitfor2_cnt + 1;
            end
            if(actualwaitfor2) begin
                actualwaitfor2_cnt <= actualwaitfor2_cnt + 1;
            end
        end
    end
`endif

endmodule

