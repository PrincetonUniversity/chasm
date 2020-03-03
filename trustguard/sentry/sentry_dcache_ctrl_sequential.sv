// Load Store Unit
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

module sentry_dcache_ctrl_sequential
(
    // Control Signals from LSU Stage, 4-to-4 Filter Gearbox and 4-to-1 asymmetric FIFO
    input  logic                        dcache_ctrl_req_fifo_empty, // req fifo not empty
    input  dcache_ctrl_req_t            dcache_ctrl_req_fifo_output,
    output logic                        dcache_ctrl_req_fifo_rd_en, // req fifo not empty
    // Cache Victim CAM Lookup
    output vindex_t                     victim_cam_index,
    input  line_t                       victim_cam_line,
    // Cache Eviction an Victim CAM Fill
    output logic                        cache_evicted,
    output line_t                       cache_evict_line,
    `ifdef SMAC
        output smac_t                       cache_evict_smac,
    `endif
    // Result Signals direction to Checking Stage
    output logic [`SENTRY_WIDTH-1:0]    check_mem_ready,
    output data_t                       check_mem_out,
    // clock and reset
    input  logic                        clk,
    input  logic                        rst
);

genvar i, j, k;

// DCache Control Data
wire                            cache_valid;
en_t                            cache_ens;
en_t                            cache_evicts;
wire [`LINE_WIDTH_BYTE-1:0]     cache_wr_en_byte;

// DCache RAM Interface
reg  [`LINE_WIDTH_BYTE-1:0]     cache_wr_en         [`DWAYS-1:0]; //where should this be figured out
reg  [`D_INDEX_WIDTH-1:0]       cache_wr_index      [`DWAYS-1:0];
line_t                          cache_wr_line       [`DWAYS-1:0];
wire [`D_INDEX_WIDTH-1:0]       cache_rd_index      [`DWAYS-1:0];
line_t                          cache_rd_line       [`DWAYS-1:0];

// Data Cache Control, these are the same
wire [`D_INDEX_WIDTH-1:0]       wr_index;
reg  [`D_INDEX_WIDTH-1:0]       wr_index_reg;
wire [`D_INDEX_WIDTH-1:0]       rd_index;

// mem data selects
reg                             byte_sel_reg;
reg                             hword_sel_reg;
reg                             word_sel_reg;
reg                             dword_sel_reg;
reg  [1:0]                      qword_sel_reg;

// DCache Read Data
wire [127:0]                    cache_rd_qword;
wire [63:0]                     cache_rd_dword;
wire [31:0]                     cache_rd_word;
wire [15:0]                     cache_rd_hword;
wire [7:0]                      cache_rd_byte;

// DCache Fill Victim CAM Line Select (from FIFO)
reg                             victim_byte_sel;
reg                             victim_hword_sel;
reg                             victim_word_sel;
reg                             victim_dword_sel;
reg  [1:0]                      victim_qword_sel;
// DCache Fill Victim CAM Line Enable (from FIFO)
reg                             victim_byte_write;
reg                             victim_hword_write;
reg                             victim_word_write;
reg                             victim_dword_write;
// DCache Fill Victim CAM Line Data (from FIFO)
reg  [7:0]                      victim_write_byte;
reg  [15:0]                     victim_write_hword;
reg  [31:0]                     victim_write_word;
reg  [63:0]                     victim_write_dword;

// DCache Fill Victim CAM Line Original
wire [7:0]                      victim_original_byte;
wire [15:0]                     victim_original_hword;
wire [31:0]                     victim_original_word;
wire [63:0]                     victim_original_dword;
wire [127:0]                    victim_original_qword;
// DCache Fill Victim CAM Line Updated
wire [7:0]                      victim_updated_byte;
wire [15:0]                     victim_updated_hword;
wire [31:0]                     victim_updated_word;
wire [63:0]                     victim_updated_dword;
wire [127:0]                    victim_updated_qword;
// Victim CAM Line Final
line_t                          updated_victim_cam_line;

// DCache Incoming/Self Control
wire [2:0]                      rd_hit_way;
reg  [2:0]                      rd_hit_way_reg;
line_t                          rd_line;
wire [2:0]                      evict_way;
reg  [2:0]                      evict_way_reg;
line_t                          actual_rd_line;

// inst cache line forwarding and read logic
tag_t                           tag;
addr_t                          mem_address;
reg  [1:0]                      cache_fill_source;
reg                             inst_is_load;
reg  [2:0]                      FUNCT3_reg; 
wire [`BYTE_OFFSET_WIDTH-1:0]   offset;
line_t                          victim_line;
line_t                          memory_line;

/* 
* these logic exist due to the 1 cycle delay in ram writes,
* therefore any read/evict after a write need to wait 1 cycle
*/
// RAW Hazard Detection Logic
en_t  cache_ens_reg;
reg   prev_write;
wire  raw_same_way;
wire  raw_same_index;
wire  raw;
wire  raw_hazard;
reg   raw_stall;
// EAW (evict-after-write) Hazard Detection Logic
wire  eaw_same_way;
wire  eaw_same_index;
wire  eaw;
wire  eaw_hazard;
reg   eaw_stall;
/* these logic exist due to the 1 cycle delay in ram writes*/

// DCache Always Reading
assign dcache_ctrl_req_fifo_rd_en = !dcache_ctrl_req_fifo_empty && !raw_hazard && !eaw_hazard;

//*************************************
// DCache Read Result to Memory Checking Stage
//*************************************
// DCache Line Read Data Select (Cycle 1)
always @(posedge clk) begin
    qword_sel_reg   <= dcache_ctrl_req_fifo_output.qword_sel;
    dword_sel_reg   <= dcache_ctrl_req_fifo_output.dword_sel;
    word_sel_reg    <= dcache_ctrl_req_fifo_output.word_sel;
    hword_sel_reg   <= dcache_ctrl_req_fifo_output.hword_sel;
    byte_sel_reg    <= dcache_ctrl_req_fifo_output.byte_sel;
    // instruction decoded controls
    tag             <= dcache_ctrl_req_fifo_output.tag;
    inst_is_load    <= dcache_ctrl_req_fifo_output.inst_is_load;
    FUNCT3_reg      <= dcache_ctrl_req_fifo_output.FUNCT3;
end

// DCache Read Selected Data (Cycle 1)
assign cache_rd_qword   = actual_rd_line[qword_sel_reg*128+:128];
assign cache_rd_dword   = cache_rd_qword[dword_sel_reg*64+:64];
assign cache_rd_word    = cache_rd_dword[word_sel_reg*32+:32];
assign cache_rd_hword   = cache_rd_word[hword_sel_reg*16+:16];
assign cache_rd_byte    = cache_rd_hword[byte_sel_reg*8+:8];

// cache load data (Cycle 2)
always @(posedge clk) begin
    // only check memory result if it is a valid memory request
    check_mem_ready <= (raw_stall && inst_is_load) ? tag.rotate : 'd0;
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

//*************************************
// Victim CAM to DCache Write
//*************************************
// Victim CAM Lookup (Cycle 0 address, cycle 1 data)
assign victim_cam_index     = dcache_ctrl_req_fifo_output.victim_cam_index;

// DCache Fill Victim CAM Line Select (from FIFO) (Cycle 1)
always @(posedge clk) begin
    victim_byte_sel     <= dcache_ctrl_req_fifo_output.byte_sel;
    victim_hword_sel    <= dcache_ctrl_req_fifo_output.hword_sel;
    victim_word_sel     <= dcache_ctrl_req_fifo_output.word_sel;
    victim_dword_sel    <= dcache_ctrl_req_fifo_output.dword_sel;
    victim_qword_sel    <= dcache_ctrl_req_fifo_output.qword_sel;
end
// DCache Fill Victim CAM Line Enable (from FIFO) (Cycle 1)
always @(posedge clk) begin
    victim_byte_write   <= dcache_ctrl_req_fifo_output.byte_write;
    victim_hword_write  <= dcache_ctrl_req_fifo_output.hword_write;
    victim_word_write   <= dcache_ctrl_req_fifo_output.word_write;
    victim_dword_write  <= dcache_ctrl_req_fifo_output.dword_write;
end
// DCache Fill Victim CAM Line Data (from FIFO) (Cycle 1)
always @(posedge clk) begin
    victim_write_byte   <= dcache_ctrl_req_fifo_output.write_byte;
    victim_write_hword  <= dcache_ctrl_req_fifo_output.write_hword;
    victim_write_word   <= dcache_ctrl_req_fifo_output.write_word;
    victim_write_dword  <= dcache_ctrl_req_fifo_output.write_dword;
end

// DCache Fill Victim CAM Line Original (Cycle 1)
assign victim_original_qword    = victim_cam_line[victim_qword_sel*128+:128];
assign victim_original_dword    = victim_original_qword[victim_dword_sel*64+:64];
assign victim_original_word     = victim_original_dword[victim_word_sel*32+:32];
assign victim_original_hword    = victim_original_word[victim_hword_sel*16+:16];
assign victim_original_byte     = victim_original_hword[victim_byte_sel*8+:8];

// DCache Fill Victim CAM Line Updated (Cycle 1)
assign victim_updated_byte      = victim_byte_write     ? victim_write_byte : victim_original_byte;

assign victim_updated_hword     = victim_hword_write    ? victim_write_hword : 
                                  victim_byte_sel       ? {victim_updated_byte, victim_original_hword[7: 0]} : 
                                                          {victim_original_hword[15:8], victim_updated_byte} ;

assign victim_updated_word      = victim_word_write     ? victim_write_word  : 
                                  victim_hword_sel      ? {victim_updated_hword, victim_original_word[15: 0]} : 
                                                          {victim_original_word[31:16], victim_updated_hword} ;

assign victim_updated_dword     = victim_dword_write    ? victim_write_dword : 
                                  victim_word_sel       ? {victim_updated_word, victim_original_dword[31: 0]} : 
                                                          {victim_original_dword[63:32], victim_updated_word} ;

assign victim_updated_qword     = victim_dword_sel      ? {victim_updated_dword, victim_original_qword[63 : 0]} : 
                                                          {victim_original_qword[127:64], victim_updated_dword} ;
// Victim CAM Line Final (Cycle 1)
assign updated_victim_cam_line  = victim_qword_sel == 2'b00 ? {victim_cam_line[511:128], victim_updated_qword                        } :
                                  victim_qword_sel == 2'b01 ? {victim_cam_line[511:256], victim_updated_qword, victim_cam_line[127:0]} :
                                  victim_qword_sel == 2'b10 ? {victim_cam_line[511:384], victim_updated_qword, victim_cam_line[255:0]} :
                                                              {                          victim_updated_qword, victim_cam_line[383:0]} ;


// Cycle 0
//assign cache_valid      = dcache_ctrl_req_fifo_rd_en;
assign cache_valid      = !dcache_ctrl_req_fifo_empty;
assign cache_ens        = dcache_ctrl_req_fifo_output.cache_ens;
assign cache_wr_en_byte = dcache_ctrl_req_fifo_output.cache_wr_en_byte;
assign cache_evicts     = dcache_ctrl_req_fifo_output.cache_evicts;
assign mem_address      = dcache_ctrl_req_fifo_output.cache_address;
assign offset           = mem_address[`BYTE_OFFSET_WIDTH-1:0];
assign wr_index         = mem_address[`BYTE_OFFSET_WIDTH+:`D_INDEX_WIDTH];
assign rd_index         = mem_address[`BYTE_OFFSET_WIDTH+:`D_INDEX_WIDTH];

// Cycle 1
always @(posedge clk) begin
    rd_hit_way_reg      <= rd_hit_way;
    evict_way_reg       <= evict_way;
    // cache evicted will be delayed 1 cycle if EAW hazard
    cache_evicted       <= (cache_valid && !eaw_hazard) ? |cache_evicts : 'd0;
    raw_stall           <= cache_valid & !raw_hazard;
end

generate
if(`DWAYS == 4) begin
    // read hit and evict way logic
    assign rd_hit_way       = cache_ens[0] ? 3'd0      :
                              cache_ens[1] ? 3'd1      :
                              cache_ens[2] ? 3'd2      :
                              cache_ens[3] ? 3'd3      :
                                            {3{1'b1}} ; // all 1's for debug

    assign evict_way        = cache_evicts[0] ? 3'd0       :
                              cache_evicts[1] ? 3'd1       :
                              cache_evicts[2] ? 3'd2       :
                              cache_evicts[3] ? 3'd3       :
                                                {3{1'b1}}  ; // all 1's for debug
end
endgenerate

// Cycle 1
always @(posedge clk) begin
    cache_fill_source   <= dcache_ctrl_req_fifo_output.fill_source; 
    memory_line         <= dcache_ctrl_req_fifo_output.cache_wr_line;
end

// Cycle 1
// Victim Line from Victim CAM
assign victim_line      = updated_victim_cam_line;
// Read Line from Cache
assign rd_line          = cache_rd_line[rd_hit_way_reg];

// Cycle 1
// if cache hit, use cache read line, else if cam forward, use victim line, otherwise use pkt2 line
// The correct order here should be, if cache read miss, use incoming line, 
// then check if there is forwarding from previous pipelines in the design,
// then use the cache read line
assign actual_rd_line   = cache_fill_source == 2'b11 ? memory_line  :
                          cache_fill_source == 2'b10 ? victim_line  :
                          cache_fill_source == 2'b01 ? rd_line      : {$bits(line_t){1'b1}};

// DCache Evict
// evicted line could be coming from sth written just one frame earlier
assign cache_evict_line = cache_evicted ? cache_rd_line[evict_way_reg] : 'd0;
reg [31:0] cache_evict_cnt;
always @(posedge clk) begin
    if(rst) cache_evict_cnt <= 32'd0;
    else if(cache_evicted) cache_evict_cnt <= cache_evict_cnt + 32'd1;
end

// cache read and write lines
generate
for (i=0; i<`DWAYS; i=i+1) begin
    // Cycle 1
    always @(posedge clk) begin
        // cache write is one to many (Cycle 1)
        // cache write is delayed 1 cycle if eaw happens
        cache_wr_en[i]          <= (cache_valid && !eaw_hazard && cache_ens[i]) ? cache_wr_en_byte : 'd0; // write byte enable is gated by way enable
        cache_wr_index[i]       <= wr_index;   // write index is the same for all ways
    end
    // Cycle 1, cache write can be data from memory or data from victim cam read back
    assign cache_wr_line[i]     = cache_fill_source == 2'b11 ? memory_line : victim_line ;

    // DCache Read
    // Cycle 0
    assign cache_rd_index[i]    = rd_index;   // read index is the same for all ways
end
endgenerate


// RAW Hazard Detection Logic (only delay load instructions)
always @(posedge clk) begin
  cache_ens_reg <= cache_ens;
  wr_index_reg  <= wr_index;
  // this way prev_write only stays high for the first cycle of any instruction,
  // which is what we need
  //prev_write    <= dcache_ctrl_req_fifo_output.inst_is_store & cache_wr_en_byte != 'd0 
  //                 && dcache_ctrl_req_fifo_rd_en; 
  // load fill and store instructions are both considered writes
  prev_write    <= (cache_wr_en_byte != 'd0) && dcache_ctrl_req_fifo_rd_en; 
end
assign  raw_same_way    = cache_ens == cache_ens_reg;
assign  raw_same_index  = rd_index == wr_index_reg;
assign  raw             = prev_write & dcache_ctrl_req_fifo_output.inst_is_load;
assign  raw_hazard      = raw_same_way & raw_same_index & raw;

// EAW Hazard Detection Logic (delay load and store instructions)
assign  eaw_same_way    = cache_evicts == cache_ens_reg;
assign  eaw_same_index  = rd_index == wr_index_reg;
assign  eaw             = prev_write & (|cache_evicts);
assign  eaw_hazard      = eaw_same_way & eaw_same_index & eaw;

wire [`SENTRY_WIDTH-1:0] collisions;
generate
for (i=0; i< `DWAYS; i=i+1) begin: ram
    //ram_block #(
    //    .DATA_WIDTH         (`LINE_WIDTH),
    //    .ADDR_WIDTH         (`D_INDEX_WIDTH),
    //    .INITIALIZE_TO_ZERO (1)
    //)
    //IP_RAM (
    //    .clk        (clk                ),
    //    .wr_en      (cache_wr_en[i]     ),
    //    .wr_addr    (cache_wr_index[i]  ),
    //    .wr_data    (cache_wr_line[i]   ),
    //    .rd_addr    (cache_rd_index[i]  ),
    //    .rd_data    (cache_rd_line[i]   )
    //);
    assign collisions[i] = |cache_wr_en[i] ? (cache_wr_index[i] == cache_rd_index[i]) : 1'b0;
    //ram_block_ip IP_RAM(
    ram_block_ip_depth16 IP_RAM(
        // port a for write
        .clka       (clk                ),  // input wire clka
        .ena        (1'b1               ),  // input wire ena
        .wea        (cache_wr_en[i]     ),  // input wire [63 : 0] wea
        .addra      (cache_wr_index[i]  ),  // input wire [3 : 0] addra
        .dina       (cache_wr_line[i]   ),  // input wire [511 : 0] dina
        .douta      (                   ),  // output wire [511 : 0] douta
        // port b for read
        .clkb       (clk                ),  // input wire clka
        .enb        (cache_ens[i]       ),  // input wire ena
        .web        (64'd0              ),  // input wire [63 : 0] wea
        .addrb      (cache_rd_index[i]  ),  // input wire [3 : 0] addra
        .dinb       (512'd0             ),  // input wire [511 : 0] dina
        .doutb      (cache_rd_line[i]   )   // output wire [511 : 0] douta
    );

end
endgenerate

reg forward0to1;
reg evict_forward0to1;
// Line forwarding logic
generate
if(`DWAYS == 4) begin
    // Cycle 1
    always @(posedge clk) begin
        // same frame store to read forward, should add read hit as one of the criterias
        //forward0to1 <= wr_index == rd_index && wr_en == rd_en && |cache_wr_en_byte;
        // same frame store to evict forward
        //evict_forward0to1 <= wr_index == rd_index && wr_en == cache_evicts && |cache_wr_en_byte;
    end
end
endgenerate


endmodule



