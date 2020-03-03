// ICache Emulation part of sentryControl unit
`timescale 1ns/1ps
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

// each cache set is composed of
// valid bit + dirty bit + tag bits + data bits

module sentryControl_icache_parallel (
    // interface to Merkle Tree Controller
    input  logic                        icache_req_valid,
    output logic                        icache_req_rd_en,
    input  addr_t                       icache_req_address      [`SENTRY_WIDTH-1:0],
    input  data_t                       icache_req_inst_result  [`SENTRY_WIDTH-1:0],
    // interface to inst_pkt1_fifo 
    output pkt1_t                       inst_pkt1_fifo_input    [`SENTRY_WIDTH-1:0],
    output logic [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_wr_en,
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_full,
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_almost_full,
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_prog_full,
    // this goes out to a  four-by-four filter gearbox
    // interface to memory request queue/fifo
    output mem_req_t                    mem_req_fifo_input      [`SENTRY_WIDTH-1:0],
    output logic [`SENTRY_WIDTH-1:0]    mem_req_fifo_wr_en,
    input  logic                        mem_req_fifo_full,
    input  logic                        mem_req_fifo_almost_full,
    input  logic                        mem_req_fifo_prog_full,
    `ifdef SMAC // Optional SMAC Interface
        // interface to smac request queue/fifo
        output mem_req_t                    smac_req_fifo_input     [`SENTRY_WIDTH-1:0],
        output logic [`SENTRY_WIDTH-1:0]    smac_req_fifo_wr_en,
        input  logic                        smac_req_fifo_full,
        input  logic                        smac_req_fifo_almost_full,
        input  logic                        smac_req_fifo_prog_full,
    `endif
    // Clock and Reset
    input                               clk,
    input                               rst
);

localparam MEMD     = `ISETS            ; // memory depth
localparam DATAW    = `I_VDTAG_WIDTH    ; // data width
localparam nRPORTS  = `SENTRY_WIDTH     ; // number of reading ports
localparam nWPORTS  = `SENTRY_WIDTH     ; // number of writing ports
localparam WAW      = 1                 ; // WAW (Write-After-Write ) protection
localparam WDW      = 0                 ; // WDW (Write-During-Write) protection
localparam RAW      = 1                 ; // RAW (Read-After-Write  ) protection
localparam RDW      = 1                 ; // RDW (Read-During-Write ) protection
localparam BYP      = RDW ? "RDW" : (RAW ? "RAW" : (WAW ? "WAW" : "NON"));

genvar i,j;

// instruction din count
reg [$bits(tag_t)-`SENTRY_WIDTH-1:0] number = 0;
reg [$bits(tag_t)-`SENTRY_WIDTH-1:0] dins               [`SENTRY_WIDTH-1:0];
// instruction cache control
reg  [3:0]                      random_num = 4'hf;
wire [`IWAYS-1:0]               fill_way;
wire [`IWAYS-1:0]               miss_fill_way           [`SENTRY_WIDTH-1:0]; // one-hot encoding

// write
wire [`IWAYS-1:0]               wr_en                   [`SENTRY_WIDTH-1:0]; // c1
reg  [`I_INDEX_WIDTH-1:0]       wr_index                [`SENTRY_WIDTH-1:0]; // c1
wire [`I_VDTAG_WIDTH-1:0]       wr_line                 [`SENTRY_WIDTH-1:0]; // c1
// read
wire [`IWAYS-1:0]               rd_en                   [`SENTRY_WIDTH-1:0]; // c0
wire [`I_INDEX_WIDTH-1:0]       rd_index                [`SENTRY_WIDTH-1:0]; // c0
reg  [`I_VDTAG_WIDTH-1:0]       rd_line                 [`SENTRY_WIDTH-1:0][`IWAYS-1:0]; // c1

// read hit/miss
wire [2:0]                      rd_hit_way              [`SENTRY_WIDTH-1:0]; // c1
wire [2:0]                      rd_miss_way             [`SENTRY_WIDTH-1:0]; // c1
// cache read hit/miss
reg  [`I_TAG_WIDTH-1:0]         compare_tag             [`SENTRY_WIDTH-1:0]; // c1
wire [`IWAYS-1:0]               data_hit                [`SENTRY_WIDTH-1:0]; // c1
wire [`SENTRY_WIDTH-1:0]        cache_hit; // c1
wire [`IWAYS-1:0]               valid_way               [`SENTRY_WIDTH-1:0]; // c1
wire [`IWAYS-1:0]               dirty_way               [`SENTRY_WIDTH-1:0]; // c1
wire [`I_TAG_WIDTH-1:0]         tag_way                 [`SENTRY_WIDTH-1:0][`IWAYS-1:0]; // c1

// multiport ram control 
reg  [`SENTRY_WIDTH-1:0]                ram_wr_en       [`IWAYS-1:0]; // c1
reg  [`SENTRY_WIDTH*`I_INDEX_WIDTH-1:0] ram_wr_index    [`IWAYS-1:0]; // c1
reg  [`SENTRY_WIDTH*`I_VDTAG_WIDTH-1:0] ram_wr_line     [`IWAYS-1:0]; // c1
reg  [`SENTRY_WIDTH*`I_INDEX_WIDTH-1:0] ram_rd_index    [`IWAYS-1:0]; // c0
wire [`SENTRY_WIDTH*`I_VDTAG_WIDTH-1:0] ram_rd_line     [`IWAYS-1:0]; // c1

// Icache Req FIFO Control
reg  icache_req_rd_en_reg; // c1
wire inst_pkt1_prog_full    = | inst_pkt1_fifo_prog_full;
assign icache_req_rd_en =   icache_req_valid && (!inst_pkt1_prog_full) && (!mem_req_fifo_prog_full);

// Input parsing
wire [`I_TAG_WIDTH-1:0]         tag                     [`SENTRY_WIDTH-1:0]; // c0
wire [`I_INDEX_WIDTH-1:0]       index                   [`SENTRY_WIDTH-1:0]; // c0
wire [`BYTE_OFFSET_WIDTH-1:0]   offset                  [`SENTRY_WIDTH-1:0]; // c0
reg  [`I_TAG_WIDTH-1:0]         wr_tag                  [`SENTRY_WIDTH-1:0]; // c1
addr_t                          mem_address             [`SENTRY_WIDTH-1:0]; // c1
addr_t                          mem_address_aligned     [`SENTRY_WIDTH-1:0]; // c1
data_t                          inst_result             [`SENTRY_WIDTH-1:0]; // c1
addr_t                          offset_mask = (1 << `BYTE_OFFSET_WIDTH) - 1;

// Cache hit forwarding
reg                             forward0to1; // c1
reg                             forward0to2; // c1
reg                             forward0to3; // c1
reg                             forward1to2; // c1
reg                             forward1to3; // c1
reg                             forward2to3; // c1
wire                            overwrite10; // c1
wire                            overwrite20; // c1
wire                            overwrite21; // c1
wire [`SENTRY_WIDTH-1:0]        hmb; // c1
wire [`SENTRY_WIDTH-1:0]        evicted; // c1
wire [`IWAYS-1:0]               actual_hit              [`SENTRY_WIDTH-1:0]; // c1

// PERFOPT: primitive output registers before final output to downstream fifos
pkt1_t                      inst_pkt1_fifo_input_pre    [`SENTRY_WIDTH-1:0];
reg  [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_wr_en_pre    [`SENTRY_WIDTH-1:0];
`ifdef SMAC // Optional SMAC Interface
    mem_req_t                   smac_req_fifo_input_pre     [`SENTRY_WIDTH-1:0];
    reg                         smac_req_fifo_wr_en_pre     [`SENTRY_WIDTH-1:0];
`endif
mem_req_t                   mem_req_fifo_input_pre      [`SENTRY_WIDTH-1:0];
reg                         mem_req_fifo_wr_en_pre      [`SENTRY_WIDTH-1:0];

generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
    always @(posedge clk) begin
        inst_pkt1_fifo_input[i] <= inst_pkt1_fifo_input_pre[i];
        inst_pkt1_fifo_wr_en[i] <= inst_pkt1_fifo_wr_en_pre[i];
        `ifdef SMAC // Optional SMAC Interface
            smac_req_fifo_input[i]  <= smac_req_fifo_input_pre[i];
            smac_req_fifo_wr_en[i]  <= smac_req_fifo_wr_en_pre[i];
        `endif
        mem_req_fifo_input[i]   <= mem_req_fifo_input_pre[i];
        mem_req_fifo_wr_en[i]   <= mem_req_fifo_wr_en_pre[i];
    end
end
endgenerate

// Cycle 0, read signals
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
    assign tag[i]       = icache_req_address[i][`ADDR_WIDTH-1-:`I_TAG_WIDTH];
    assign index[i]     = icache_req_address[i][`BYTE_OFFSET_WIDTH+:`I_INDEX_WIDTH];
    assign offset[i]    = icache_req_address[i][`BYTE_OFFSET_WIDTH-1:0];
    assign rd_en[i]     = {`IWAYS{icache_req_valid && (!inst_pkt1_prog_full) && (!mem_req_fifo_prog_full)}};
    assign rd_index[i]  = index[i];
end
endgenerate

// Cycle 1, hit/miss logic
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
    always @(posedge clk) begin
        compare_tag[i]  <= tag[i];
        wr_tag[i]       <= tag[i];
        wr_index[i]     <= index[i];
        mem_address[i]          <= icache_req_address[i];
        mem_address_aligned[i]  <= icache_req_address[i] & (~offset_mask);
        inst_result[i]          <= icache_req_inst_result[i]; 
    end
end
endgenerate

// Cache Read Hit Control
generate
if(`IWAYS == 4) begin : read_hit_miss_4ways
    for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
        // Cycle 0
        assign rd_hit_way[i]    =   data_hit[i][0] ? 3'd0   :
                                    data_hit[i][1] ? 3'd1   :
                                    data_hit[i][2] ? 3'd2   :
                                    data_hit[i][3] ? 3'd3   :
                                    {3{1'b1}}   ; // all 1's for debug

        assign rd_miss_way[i]   =   miss_fill_way[i][0] ? 3'd0  :
                                    miss_fill_way[i][1] ? 3'd1  :
                                    miss_fill_way[i][2] ? 3'd2  :
                                    miss_fill_way[i][3] ? 3'd3  :
                                    {3{1'b1}}   ; // all 1's for debug

    end
end
endgenerate

// Instruction din counts
assign dins[0]          = number + 28'd1;
assign dins[1]          = number + 28'd2;
assign dins[2]          = number + 28'd3;
assign dins[3]          = number + 28'd4;

// din count and random number generation (Cycle 1 Update)
always @(posedge clk) begin
    icache_req_rd_en_reg <= icache_req_rd_en;
    if (icache_req_rd_en_reg) begin  
        // update the random way select on fill
        number      <= number + 28'd4;
        random_num  <= {random_num[2], random_num[1],
                        random_num[0], random_num[3]^random_num[2]};
    end
end

if(`IWAYS == 4) begin : hit_miss_4ways
    // Cache fill way pick 
    // use the valid way of the first parallel pipeline, 
    // no need to care about other pipelines cause 
    // the choice is random and it doesn't matter
    assign fill_way = pick_way(valid_way[0], random_num);

    function [`IWAYS-1:0] pick_way;
        input [`IWAYS-1:0] valid_way;
        input [3:0] random_num;
        begin
            if      (valid_way[0] == 1'b0) begin
                pick_way = 4'b0001;
            end
            else if (valid_way[1] == 1'b0) begin
                pick_way = 4'b0010;
            end
            else if (valid_way[2] == 1'b0) begin
                pick_way = 4'b0100;
            end
            else if (valid_way[3] == 1'b0) begin
                pick_way = 4'b1000;
            end
            else begin
                case (random_num[3:1])
                    3'd0, 3'd1: pick_way = 4'b0100;
                    3'd2, 3'd3: pick_way = 4'b1000;
                    3'd4, 3'd5: pick_way = 4'b0001;
                    default:    pick_way = 4'b0010;
                endcase
            end
        end
    endfunction

end

// Cycle 1, forwarding between Sentry pipelines
generate
if(`SENTRY_WIDTH == 4) begin : line_hit_forward_4ways
    always @(posedge clk) begin
        forward0to1 <= index[0] == index[1] && tag[0] == tag[1];
        forward0to2 <= index[0] == index[2] && tag[0] == tag[2];
        forward0to3 <= index[0] == index[3] && tag[0] == tag[3];
        forward1to2 <= index[1] == index[2] && tag[1] == tag[2];
        forward1to3 <= index[1] == index[3] && tag[1] == tag[3];
        forward2to3 <= index[2] == index[3] && tag[2] == tag[3];
    end
end
endgenerate

wire cache_rst = rst || !icache_req_rd_en_reg;

// Cycle 1, eviction match between Sentry pipelines
generate
if(`SENTRY_WIDTH == 4) begin : line_evict_forward_4ways
    // 1, eviction detection logic to determine if a cache hit will be invalid
    // due to an eviction in earlier pipelines
    // 2, write enable will depending on whether cache hit and cache hit invalidation
    assign evicted[0] = 0;
    assign hmb[0] = cache_hit[0];
    assign wr_en[0] = (cache_rst || hmb[0]) ? 0 : miss_fill_way[0];
    assign actual_hit[0] = hmb[0] ? data_hit[0] : wr_en[0];

    assign evicted[1] = wr_index[1] == wr_index[0] && data_hit[1] == wr_en[0];
    assign hmb[1] = forward0to1 ? 1 : // whether 0 is hit or miss, if 0 forward 1, 1 will hit
                    evicted[1] ? 0 : cache_hit[1];
    assign wr_en[1] = (cache_rst || hmb[1]) ? 0 : miss_fill_way[1];
    // whether 0 is hit or miss, if 0 forward 1, 1 will hit
    assign actual_hit[1] = hmb[1] ? (forward0to1 ? actual_hit[0] : data_hit[1]) :
                            wr_en[1];
    assign overwrite10 = wr_index[1] == wr_index[0] && miss_fill_way[1] == data_hit[0];

    assign evicted[2] = (wr_index[2] == wr_index[0] && data_hit[2] == wr_en[0]) ||
                      (wr_index[2] == wr_index[1] && data_hit[2] == wr_en[1]);
    assign hmb[2] = forward1to2 ? 1 : // whether 1 is hit or miss, if 1 forward 2, 2 will hit
                    // if 0 forward 2, 2 will hit unless 1 overwrote 0's hit
                    forward0to2 ? (overwrite10 ? 0 : 1) : 
                    evicted[2] ? 0 : cache_hit[2];
    assign wr_en[2] = (cache_rst || hmb[2]) ? 0 : miss_fill_way[2];
    // whether 1 is hit or miss, if 1 forward 2, 2 will hit
    assign actual_hit[2] = hmb[2] ? (forward1to2 ? actual_hit[1] : 
                                     forward0to2 ? actual_hit[0] : data_hit[2]):
                                     wr_en[2];
    assign overwrite20 = wr_index[2] == wr_index[0] && miss_fill_way[2] == data_hit[0];
    assign overwrite21 = wr_index[2] == wr_index[1] && miss_fill_way[2] == data_hit[1];

    assign evicted[3] = (wr_index[3] == wr_index[0] && data_hit[3] == wr_en[0]) ||
                      (wr_index[3] == wr_index[1] && data_hit[3] == wr_en[1]) || 
                      (wr_index[3] == wr_index[2] && data_hit[3] == wr_en[2]);
    assign hmb[3] = forward2to3 ? 1 : // whether 2 is hit or miss, if 2 forward 3, 3 will hit
                    // if 1 forward 3, 3 will hit unless 2 overwrote 1's hit
                    forward1to3 ? (overwrite21 ? 0 : 1) : 
                    forward0to3 ? ((overwrite20 || overwrite10) ? 0 : 1) : 
                    evicted[3] ? 0 : cache_hit[3];
    assign wr_en[3] = (cache_rst || hmb[3]) ? 0 : miss_fill_way[3];
    // actual hit information is derived from original hit and miss fill forwarding
    // whether 2 is hit or miss, if 2 forward 3, 3 will hit
    assign actual_hit[3] = hmb[3] ? (forward2to3 ? actual_hit[2] : 
                                    // if 1 forward 3, 3 will hit unless 2 overwrote 1's hit
                                    forward1to3 ? actual_hit[1] : 
                                    forward0to3 ? actual_hit[0] : data_hit[3])  : 
                                    wr_en[3];

    // miss fill way for each parallel pipeline
    // NOTE: Having associativity of 4 guarantees that 
    // no overlapping writes will occur in the same clock cycle
    // each paralle pipeline will be directed to a different way
    assign miss_fill_way[0] = fill_way[3:0];
    assign miss_fill_way[1] = {fill_way[2:0], fill_way[3]};
    assign miss_fill_way[2] = {fill_way[1:0], fill_way[3:2]};
    assign miss_fill_way[3] = {fill_way[0], fill_way[3:1]};

end
endgenerate

// Cycle 2
wire [`SENTRY_WIDTH-1:0] rotate = 'd1;
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
    always @(posedge clk) begin
        if(icache_req_rd_en_reg) begin
            // if cache hit, send hit info to inst_pkt1_fifo
            if (hmb[i]) begin
                // send instruction metadata
                inst_pkt1_fifo_input_pre[i].tag.number  <= dins[i];
                inst_pkt1_fifo_input_pre[i].tag.rotate  <= (rotate << i);
                inst_pkt1_fifo_input_pre[i].mhb         <= 0;
                inst_pkt1_fifo_input_pre[i].ens         <= actual_hit[i];
                inst_pkt1_fifo_input_pre[i].evict       <= 0;
                inst_pkt1_fifo_input_pre[i].vidx        <= 0;
                inst_pkt1_fifo_input_pre[i].addr        <= mem_address[i];
                inst_pkt1_fifo_input_pre[i].result      <= inst_result[i];
                inst_pkt1_fifo_wr_en_pre[i]             <= 1;
                mem_req_fifo_input_pre[i]               <= 0;
                mem_req_fifo_wr_en_pre[i]               <= 0;
                `ifdef SMAC
                    smac_req_fifo_input_pre[i]             <= 0;
                    smac_req_fifo_wr_en_pre[i]             <= 0;
                `endif
            end
            // if cache miss, send miss info to inst_pkt1_fifo
            // also perform the fill on the next cycle
            else begin
                // send instruction metadata
                inst_pkt1_fifo_input_pre[i].tag.number  <= dins[i];
                inst_pkt1_fifo_input_pre[i].tag.rotate  <= (rotate << i);
                inst_pkt1_fifo_input_pre[i].mhb         <= 1;
                inst_pkt1_fifo_input_pre[i].ens         <= miss_fill_way[i];
                inst_pkt1_fifo_input_pre[i].evict       <= 0;
                inst_pkt1_fifo_input_pre[i].vidx        <= 0;
                inst_pkt1_fifo_input_pre[i].addr        <= mem_address[i];
                inst_pkt1_fifo_input_pre[i].result      <= inst_result[i];
                inst_pkt1_fifo_wr_en_pre[i]             <= 1;
                // send miss line request
                mem_req_fifo_input_pre[i].tag.number    <= dins[i];
                mem_req_fifo_input_pre[i].tag.rotate    <= (rotate << i);
                mem_req_fifo_input_pre[i].addr          <= mem_address_aligned[i];
                mem_req_fifo_wr_en_pre[i]               <= 1;
                `ifdef SMAC
                    // send miss smac request
                    smac_req_fifo_input_pre.tag.number  <= dins[i];
                    smac_req_fifo_input_pre.tag.rotate  <= (rotate << i);
                    smac_req_fifo_input_pre.addr        <= smac_address_aligned[i];
                    smac_req_fifo_wr_en_pre             <= 1;
                `endif
            end
        end
        else begin
                inst_pkt1_fifo_wr_en_pre[i]             <= 0;
                mem_req_fifo_wr_en_pre[i]               <= 0;
                `ifdef SMAC
                    smac_req_fifo_wr_en_pre[i]             <= 0;
                `endif
        end
    end

end
endgenerate

// generate parallel icache control data
// cache hit/miss logic:
// 0th pipeline, normal cache hit or fill on miss
// 1th pipeline, cache hit need to check for 0th pipe evict on fill, then fill on miss
// 2nd pipeline, cache hit need to check for 0th and 1th pipe evict on fill, then fill on miss
// 3rd pipeline, cache hit need to check for 0th and 1th and 2nd pipe evict on fill, then fill on miss
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
    assign cache_hit[i] = |data_hit[i]; // this is hit information derived from last cycle original snapshot
end
endgenerate

// Cycle 1
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
    assign wr_line[i] = {1'b1, 1'b0, wr_tag[i]};
    for (j=0; j<`IWAYS; j=j+1) begin
        // this data_hit is the original data hit before 
        // taking into account eviction by previous pipelines
        assign data_hit[i][j] = valid_way[i][j] && tag_way[i][j] == compare_tag[i];
        // cache fill way write enable
        assign {valid_way[i][j], dirty_way[i][j], tag_way[i][j]} = rd_line[i][j];
    end
end
endgenerate

// pack and unpack parallel icache control data
generate
for (i=0; i<`IWAYS; i=i+1) begin: sc_i_line_ram_control
    for (j=0; j<`SENTRY_WIDTH; j=j+1) begin
        always @(*) begin
            // Cycle 1
            ram_wr_en[i][j]                                             <= wr_en[j][i];
            ram_wr_index[i][(j+1)*`I_INDEX_WIDTH-1:j*`I_INDEX_WIDTH]    <= wr_index[j];
            ram_wr_line[i][(j+1)*`I_VDTAG_WIDTH-1:j*`I_VDTAG_WIDTH]     <= wr_line[j];
        end
        //always @(posedge clk) begin
        //    // Cycle 1
        //    ram_wr_en[i][j]                                             <= wr_en[j][i];
        //    ram_wr_index[i][(j+1)*`I_INDEX_WIDTH-1:j*`I_INDEX_WIDTH]      <= wr_index[j];
        //    ram_wr_line[i][(j+1)*`I_VDTAG_WIDTH-1:j*`I_VDTAG_WIDTH]       <= wr_line[j];
        //end
        always @(*) begin
            // Cycle 0
            ram_rd_index[i][(j+1)*`I_INDEX_WIDTH-1:j*`I_INDEX_WIDTH]    <= rd_index[j];
            // Cycle 1
            rd_line[j][i]                                               <= ram_rd_line[i][(j+1)*`I_VDTAG_WIDTH-1:j*`I_VDTAG_WIDTH];
        end
    end
end
endgenerate

generate
for (i=0; i<`IWAYS; i=i+1) begin: sc_i_line_ram
    // instantiate a multiported-RAM with binary-coded register-based LVT
    mpram   #(  
        .MEMD   (MEMD            ),  // memory depth
        .DATAW  (DATAW           ),  // data width
        .nRPORTS(nRPORTS         ),  // number of reading ports
        .nWPORTS(nWPORTS         ),  // number of writing ports
        .TYPE   ("LVTREG"        ),  // multi-port RAM implementation type
        .BYP    (BYP             ),  // Bypassing type: NON, WAW, RAW, RDW
        .IFILE  ("zero"          )  // initializtion file, optional
    )
    mpram_lvtreg_sc_icache (  
        .clk    (clk                ),  // clock
        .WEnb   (ram_wr_en[i]       ),  // write enable for each writing port                - in : [nWPORTS-1:0            ]
        .WAddr  (ram_wr_index[i]    ),  // write addresses - packed from nWPORTS write ports - in : [`log2(MEMD)*nWPORTS-1:0]
        .WData  (ram_wr_line[i]     ),  // write data      - packed from nRPORTS read  ports - out: [DATAW      *nWPORTS-1:0]
        .RAddr  (ram_rd_index[i]    ),  // read  addresses - packed from nRPORTS read  ports - in : [`log2(MEMD)*nRPORTS-1:0]
        .RData  (ram_rd_line[i]     )   // read  data      - packed from nRPORTS read  ports - out: [DATAW      *nRPORTS-1:0]
    );
    //ram_4wide #(
    //    .ADDR_WIDTH (`I_INDEX_WIDTH),
    //    .DATA_WIDTH (`I_VDTAG_WIDTH),
    //    .NPORTS     (`SENTRY_WIDTH)
    //)
    //ram_4ports (
    //    .clk        (clk        ),
    //    .wr_en      (ram_wr_en[i]   ),
    //    .wr_addr    (ram_wr_index[i]),
    //    .wr_data    (ram_wr_line[i] ), 
    //    .rd_addr    (ram_rd_index[i]),
    //    .rd_data    (ram_rd_line[i] )
    //);
end
endgenerate


endmodule

