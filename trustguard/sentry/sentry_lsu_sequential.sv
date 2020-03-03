// Load Store Unit for a sequential data cache
// outputs cache control signal to 4-to-4 filter gearbox
// then 4-to-1 fifo, then to a sequential data cache and victim cam
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

module sentry_lsu_sequential
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
    // Control Signals from Decode Stage
    input  logic                    lsu_req,
    input  inst_t                   lsu_instruction,
    input  tag_t                    lsu_tag,
    input  data_t                   lsu_data,
    input  addr_t                   lsu_addr,
    // Output Interface to 4-to-4 Filter Gearbox
    input  logic                    dcache_ctrl_req_fifo_full,
    input  logic                    dcache_ctrl_req_fifo_almost_full,
    input  logic                    dcache_ctrl_req_fifo_prog_full,
    output logic                    dcache_ctrl_req_fifo_wr_en,
    output dcache_ctrl_req_t        dcache_ctrl_req_fifo_input,
    // clock and reset
    input  logic                    clk,
    input  logic                    rst
);

genvar i, j, k;

// LSU Request Inst Ready
wire [6:0]                      OPCODE;
wire [2:0]                      FUNCT3;
wire [6:0]                      FUNCT7;
wire                            inst_valid;
tag_t                           tag;
inst_t                          instruction;
// Data PKT FIFOs Ready (Cycle 0)
wire                            data_ready;
// Load Store Unit Control Logic (Cycle 0)
wire                            inst_is_load;
wire                            inst_is_store;
wire                            inst_is_mem;
addr_t                          cache_address;
wire [`BYTE_OFFSET_WIDTH-1:0]   offset;
addr_t                          offset_mask = (1 << `BYTE_OFFSET_WIDTH) - 1;

// Interface to Victim CAM (to FIFO)
vindex_t                        victim_cam_index;
// Control Signals to DCache Control (to FIFO)
en_t                            cache_ens;
en_t                            cache_evicts;
addr_t                          cache_addr;
wire  [`LINE_WIDTH_BYTE-1:0]    cache_wr_en_byte;
line_t                          cache_wr_line;

// DCache Write Enable Instruction Decoded
wire                            store_byte;
wire                            store_hword;
wire                            store_word;
wire                            store_dword;
// DCache Store Selects
wire                            byte_sel;
wire                            hword_sel;
wire                            word_sel;
wire                            dword_sel;
wire [1:0]                      qword_sel;
// DCache Write Enable Before
reg                             byte_write;
reg                             hword_write;
reg                             word_write;
reg                             dword_write;
// DCache Write Data Before
reg  [7:0]                      write_byte;
reg  [15:0]                     write_hword;
reg  [31:0]                     write_word;
reg  [63:0]                     write_dword;
// DCache Write Byte Data Original
wire [7:0]                      original_byte;
wire [15:0]                     original_hword;
wire [31:0]                     original_word;
wire [63:0]                     original_dword;
wire [127:0]                    original_qword;
wire [511:0]                    original_line;
// DCache Write Byte Enable Original 
wire                            original_byte_en;
wire [1 :0]                     original_hword_en;
wire [3 :0]                     original_word_en;
wire [7 :0]                     original_dword_en;
wire [15:0]                     original_qword_en;
wire [63:0]                     original_line_en;
// DCache Write Line Updated
wire [7:0]                      updated_byte;
wire [15:0]                     updated_hword;
wire [31:0]                     updated_word;
wire [63:0]                     updated_dword;
wire [127:0]                    updated_qword;
wire [511:0]                    updated_line;
// DCache Write Byte Enable Updated
wire                            updated_byte_en;
wire [1 :0]                     updated_hword_en;
wire [3 :0]                     updated_word_en;
wire [7 :0]                     updated_dword_en;
wire [15:0]                     updated_qword_en;
wire [63:0]                     updated_line_en;

//************************************************************************
// LSU Request FIFO (used to hold LSU request and wait for data pkt1 and pkt2)
//************************************************************************
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

// Load Store Unit Control
// (Cycle 0 @ all fifo ready)
//assign inst_valid       = !lsu_req_fifo_empty & data_ready & !dcache_ctrl_req_fifo_prog_full; // inst_valid stays high while fifo not empty
assign inst_valid       = !lsu_req_fifo_empty & data_ready; // inst_valid stays high while fifo not empty
assign instruction      = lsu_req_fifo_output.instruction;
assign tag              = lsu_req_fifo_output.tag;
assign inst_is_load     = inst_valid && ((OPCODE == `RV32_LOAD) || (OPCODE == `RV_LOAD_UNT));
assign inst_is_store    = inst_valid && ((OPCODE == `RV32_STORE) || (OPCODE == `RV_STORE_UNT_NET && FUNCT3 < 4));
assign inst_is_mem      = inst_is_load || inst_is_store;
// Instruction Decode
assign OPCODE           = instruction[ 6: 0];
assign FUNCT3           = instruction[14:12];
assign FUNCT7           = instruction[31:25];

// (Cycle 0)
assign cache_address    = lsu_req_fifo_output.addr;
assign offset           = cache_address[`BYTE_OFFSET_WIDTH-1:0];

// Instruction Store Control Type
assign store_byte       = inst_valid && (FUNCT3 == `RV32_FUNCT3_SB);
assign store_hword      = inst_valid && (FUNCT3 == `RV32_FUNCT3_SH);
assign store_word       = inst_valid && (FUNCT3 == `RV32_FUNCT3_SW);
assign store_dword      = inst_valid && (FUNCT3 == `RV32_FUNCT3_SD);
// DCache Store Word Select (Cycle 0)
assign byte_sel         = offset[0];
assign hword_sel        = offset[1];
assign word_sel         = offset[2];
assign dword_sel        = offset[3];
assign qword_sel        = offset[5:4];
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
// cache write (Cycle 0)
assign byte_write      = inst_is_store && store_byte;
assign hword_write     = inst_is_store && store_hword; // increment counter
assign word_write      = inst_is_store && store_word;
assign dword_write     = inst_is_store && store_dword;
// actual write data (Cycle 0)
assign write_byte      = lsu_req_fifo_output.data[7:0];
assign write_hword     = lsu_req_fifo_output.data[15:0];
assign write_word      = lsu_req_fifo_output.data[31:0];
assign write_dword     = lsu_req_fifo_output.data[63:0];

// updated cache line (Cycle 0)
assign updated_byte     = byte_write  ? write_byte  : original_byte;

assign updated_hword    = hword_write ? write_hword : 
                          byte_sel    ? {updated_byte, original_hword[7: 0]} : 
                                        {original_hword[15:8], updated_byte} ;

assign updated_word     = word_write  ? write_word  : 
                          hword_sel   ? {updated_hword, original_word[15: 0]} : 
                                        {original_word[31:16], updated_hword} ;

assign updated_dword    = dword_write ? write_dword : 
                          word_sel    ? {updated_word, original_dword[31: 0]} : 
                                        {original_dword[63:32], updated_word} ;

assign updated_qword    = dword_sel   ? {updated_dword, original_qword[63 : 0]} : 
                                        {original_qword[127:64], updated_dword} ;

assign cache_wr_line    = qword_sel == 2'b00 ? {original_line[511:128], updated_qword                      } :
                          qword_sel == 2'b01 ? {original_line[511:256], updated_qword, original_line[127:0]} :
                          qword_sel == 2'b10 ? {original_line[511:384], updated_qword, original_line[255:0]} :
                                               {                        updated_qword, original_line[383:0]} ;

// updated byte enable (Cycle 0)
assign updated_byte_en  = byte_write    ? 1'b1  : original_byte_en;

assign updated_hword_en = hword_write   ? 2'b11                                   : 
                          byte_sel      ? {updated_byte_en, original_hword_en[0]} :
                                          {original_hword_en[1], updated_byte_en} ;

assign updated_word_en  = word_write    ? 4'hf                                      : 
                          hword_sel     ? {updated_hword_en, original_word_en[1:0]} :
                                          {original_word_en[3:2], updated_hword_en} ;

assign updated_dword_en = dword_write   ? 8'hff                                     : 
                          word_sel      ? {updated_word_en, original_dword_en[3:0]} :
                                          {original_dword_en[7:4], updated_word_en} ;

assign updated_qword_en = dword_sel     ? {updated_dword_en, original_qword_en[7:0]}  :
                                          {original_qword_en[15:8], updated_dword_en} ;

assign cache_wr_en_byte = !inst_valid        ? 'd0 :
                          qword_sel == 2'b00 ? {original_line_en[63:16], updated_qword_en                        } :
                          qword_sel == 2'b01 ? {original_line_en[63:32], updated_qword_en, original_line_en[15:0]} :
                          qword_sel == 2'b10 ? {original_line_en[63:48], updated_qword_en, original_line_en[31:0]} :
                                               {                         updated_qword_en, original_line_en[47:0]} ;

// Incoming Data PKT FIFO (Cycle 0)
assign data_ready   =   data_pkt1_fifo_empty        ? 0 :   // if pkt1 not ready, data not ready
                        !data_pkt1_fifo_output.mhb  ? 1 :   // if pkt1 ready and data hit, data ready
                        data_vpkt_fifo_empty        ? 0 :   // if D$ miss and vpkt not ready, data not ready
                        !data_vpkt_fifo_output.mhb  ? 1 :   // if D$ miss and victim cam hit, data ready from victim cam
                        data_pkt2_fifo_empty        ? 0 : 1;// if D$ miss, victim cam miss, data ready is pkt2 mem data ready

// For a cache write to happen, way enable need to set correctly
// and byte enable need to be high
// Cache way enable (Cycle 0)
assign cache_ens            = data_pkt1_fifo_output.ens;
assign cache_evicts         = inst_valid ? data_pkt1_fifo_output.evict : 'd0;

// Data Pkt FIFOs Drain Read Enable (Cycle 0)
assign data_pkt1_fifo_rd_en = inst_valid;
assign data_vpkt_fifo_rd_en = inst_valid && data_pkt1_fifo_output.mhb; // if D$ miss, there must be a vpkt
assign data_pkt2_fifo_rd_en = inst_valid && data_pkt1_fifo_output.mhb && data_vpkt_fifo_output.mhb; // if D$ miss and victim cam miss, there must be a pkt2
`ifdef SMAC
    assign data_pkt3_fifo_rd_en = inst_valid && (!data_pkt3_fifo_empty);
`endif

// Cycle 0
assign victim_cam_index = data_vpkt_fifo_output.vidx;

// DCache Control Request FIFO Input (Cycle 1)
always @(posedge clk) begin
    dcache_ctrl_req_fifo_wr_en                  <= inst_valid;
    // Instruction Decoded Controls
    dcache_ctrl_req_fifo_input.tag              <= tag;
    dcache_ctrl_req_fifo_input.fill_source      <= data_pkt2_fifo_rd_en ? 2'b11 :
                                                   data_vpkt_fifo_rd_en ? 2'b10 :
                                                   data_pkt1_fifo_rd_en ? 2'b01 : 2'b00;
    dcache_ctrl_req_fifo_input.inst_is_load     <= inst_is_load;
    dcache_ctrl_req_fifo_input.inst_is_store    <= inst_is_store;
    dcache_ctrl_req_fifo_input.FUNCT3           <= FUNCT3;
    // DCache Controls
    dcache_ctrl_req_fifo_input.cache_ens        <= cache_ens;
    dcache_ctrl_req_fifo_input.cache_address    <= cache_address;
    dcache_ctrl_req_fifo_input.cache_evicts     <= cache_evicts;
    dcache_ctrl_req_fifo_input.cache_wr_en_byte <= cache_wr_en_byte;
    dcache_ctrl_req_fifo_input.cache_wr_line    <= cache_wr_line;
    // victim cam lookup
    dcache_ctrl_req_fifo_input.victim_cam_index <= victim_cam_index;
    // victim cam data select
    // DCache Fill Victim CAM Line Select (to FIFO) (6 bits)
    dcache_ctrl_req_fifo_input.byte_sel         <= byte_sel;
    dcache_ctrl_req_fifo_input.hword_sel        <= hword_sel;
    dcache_ctrl_req_fifo_input.word_sel         <= word_sel;
    dcache_ctrl_req_fifo_input.dword_sel        <= dword_sel;
    dcache_ctrl_req_fifo_input.qword_sel        <= qword_sel;
    // DCache Fill Victim CAM Line Enable (to FIFO) (4 bits)
    dcache_ctrl_req_fifo_input.byte_write       <= byte_write;
    dcache_ctrl_req_fifo_input.hword_write      <= hword_write;
    dcache_ctrl_req_fifo_input.word_write       <= word_write;
    dcache_ctrl_req_fifo_input.dword_write      <= dword_write;
    // DCache Fill Victim CAM Line Data (to FIFO) (120 bits)
    dcache_ctrl_req_fifo_input.write_byte       <= write_byte;
    dcache_ctrl_req_fifo_input.write_hword      <= write_hword;
    dcache_ctrl_req_fifo_input.write_word       <= write_word;
    dcache_ctrl_req_fifo_input.write_dword      <= write_dword;
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


