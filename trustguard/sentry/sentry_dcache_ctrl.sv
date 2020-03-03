// Load Store Unit
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

module sentry_dcache_ctrl
(
    // Control Signals from LSU Stage
    input  en_t                         cache_ens               [`SENTRY_WIDTH-1:0],
    input  en_t                         cache_evicts            [`SENTRY_WIDTH-1:0],
    input  [`LINE_WIDTH_BYTE-1:0]       cache_wr_en_byte        [`SENTRY_WIDTH-1:0],
    input  addr_t                       cache_wr_addr           [`SENTRY_WIDTH-1:0],
    input  line_t                       cache_wr_line           [`SENTRY_WIDTH-1:0],
    // Cache Write Victim CAM Line Control
    input  logic [`SENTRY_WIDTH-1:0]    victim_byte_sel,
    input  logic [`SENTRY_WIDTH-1:0]    victim_hword_sel,
    input  logic [`SENTRY_WIDTH-1:0]    victim_word_sel,
    input  logic [`SENTRY_WIDTH-1:0]    victim_dword_sel,
    input  logic [1:0]                  victim_qword_sel        [`SENTRY_WIDTH-1:0],
    input  logic [`SENTRY_WIDTH-1:0]    victim_byte_write,
    input  logic [`SENTRY_WIDTH-1:0]    victim_hword_write,
    input  logic [`SENTRY_WIDTH-1:0]    victim_word_write,
    input  logic [`SENTRY_WIDTH-1:0]    victim_dword_write,
    input  logic [7:0]                  victim_write_byte       [`SENTRY_WIDTH-1:0],
    input  logic [15:0]                 victim_write_hword      [`SENTRY_WIDTH-1:0],
    input  logic [31:0]                 victim_write_word       [`SENTRY_WIDTH-1:0],
    input  logic [63:0]                 victim_write_dword      [`SENTRY_WIDTH-1:0],
    // Cache Read
    input  addr_t                       cache_rd_addr           [`SENTRY_WIDTH-1:0],
    output line_t                       cache_rd_line           [`SENTRY_WIDTH-1:0],
    // Cache Victim CAM Fill
    input  logic [`SENTRY_WIDTH-1:0]    victim_cam_en, // cycle 1
    input  line_t                       victim_cam_line         [`SENTRY_WIDTH-1:0],
    // Cache parallel eviction
    output logic [`SENTRY_WIDTH-1:0]    cache_evicted,
    output line_t                       cache_evict_line        [`SENTRY_WIDTH-1:0],
    `ifdef SMAC
        output smac_t                       cache_evict_smac        [`SENTRY_WIDTH-1:0],
    `endif
    // clock and reset
    input  logic                        clk,
    input  logic                        rst
);

localparam MEMD     = `DSETS        ; // memory depth
localparam DATAW    = 8             ; // data width
localparam nRPORTS  = `SENTRY_WIDTH ; // number of reading ports
localparam nWPORTS  = `SENTRY_WIDTH ; // number of writing ports
localparam WAW      = 1             ; // WAW (Write-After-Write ) protection
localparam WDW      = 0             ; // WDW (Write-During-Write) protection
localparam RAW      = 1             ; // RAW (Read-After-Write  ) protection
`ifdef DCACHE_OPT
    localparam RDW      = 0             ; // RDW (Read-During-Write ) protection
`else
    localparam RDW      = 1             ; // RDW (Read-During-Write ) protection
`endif
localparam BYP      = RDW ? "RDW" : (RAW ? "RAW" : (WAW ? "WAW" : "NON"));

genvar i, j, k;

// inst cache line forwarding and read logic
reg  [`LINE_WIDTH_BYTE-1:0]     forward0to1;
reg  [`LINE_WIDTH_BYTE-1:0]     forward0to2;
reg  [`LINE_WIDTH_BYTE-1:0]     forward0to3;
reg  [`LINE_WIDTH_BYTE-1:0]     forward1to2;
reg  [`LINE_WIDTH_BYTE-1:0]     forward1to3;
reg  [`LINE_WIDTH_BYTE-1:0]     forward2to3;
reg  [`LINE_WIDTH_BYTE-1:0]     evict_forward0to1;
reg  [`LINE_WIDTH_BYTE-1:0]     evict_forward0to2;
reg  [`LINE_WIDTH_BYTE-1:0]     evict_forward0to3;
reg  [`LINE_WIDTH_BYTE-1:0]     evict_forward1to2;
reg  [`LINE_WIDTH_BYTE-1:0]     evict_forward1to3;
reg  [`LINE_WIDTH_BYTE-1:0]     evict_forward2to3;
wire                            read_hit            [`SENTRY_WIDTH-1:0][`LINE_WIDTH_BYTE-1:0];
reg                             pipe_mhb            [`SENTRY_WIDTH-1:0][`LINE_WIDTH_BYTE-1:0];
reg  [7:0]                      actual_rd_line      [`SENTRY_WIDTH-1:0][`LINE_WIDTH_BYTE-1:0];
reg  [7:0]                      memory_line         [`SENTRY_WIDTH-1:0][`LINE_WIDTH_BYTE-1:0];
wire [7:0]                      victim_line         [`SENTRY_WIDTH-1:0][`LINE_WIDTH_BYTE-1:0];
reg  [7:0]                      incoming_line       [`SENTRY_WIDTH-1:0][`LINE_WIDTH_BYTE-1:0];
reg  [`SENTRY_WIDTH-1:0]        victim_cam_en_reg; // cycle 1

// dcache control data
//reg                             cache_wr_en         [`SENTRY_WIDTH-1:0][`DWAYS-1:0][`LINE_WIDTH_BYTE-1:0]; //where should this be figured out
reg  [`LINE_WIDTH_BYTE-1:0]     cache_wr_en         [`SENTRY_WIDTH-1:0][`DWAYS-1:0]; //where should this be figured out
reg  [`D_INDEX_WIDTH-1:0]       cache_wr_index      [`SENTRY_WIDTH-1:0][`DWAYS-1:0];
wire [7:0]                      cache_wr_line_byte  [`SENTRY_WIDTH-1:0][`DWAYS-1:0][`LINE_WIDTH_BYTE-1:0];
wire [`D_INDEX_WIDTH-1:0]       cache_rd_index      [`SENTRY_WIDTH-1:0][`DWAYS-1:0];
wire [7:0]                      cache_rd_line_byte  [`SENTRY_WIDTH-1:0][`DWAYS-1:0][`LINE_WIDTH_BYTE-1:0];
line_t                          cache_rd_way_line   [`SENTRY_WIDTH-1:0][`DWAYS-1:0];

en_t                            wr_en               [`SENTRY_WIDTH-1:0];
en_t                            wr_en_byte          [`SENTRY_WIDTH-1:0][`LINE_WIDTH_BYTE-1:0];
en_t                            rd_en               [`SENTRY_WIDTH-1:0];
en_t                            evict_en            [`SENTRY_WIDTH-1:0];
wire [2:0]                      rd_hit_way          [`SENTRY_WIDTH-1:0];
reg  [2:0]                      rd_hit_way_reg      [`SENTRY_WIDTH-1:0];
wire [7:0]                      rd_line             [`SENTRY_WIDTH-1:0][`LINE_WIDTH_BYTE-1:0];
wire [2:0]                      evict_way           [`SENTRY_WIDTH-1:0];
reg  [2:0]                      evict_way_reg       [`SENTRY_WIDTH-1:0];
wire [7:0]                      evict_line          [`SENTRY_WIDTH-1:0][`LINE_WIDTH_BYTE-1:0];
wire [7:0]                      actual_evict_line   [`SENTRY_WIDTH-1:0][`LINE_WIDTH_BYTE-1:0];

generate
if(`DWAYS == 4) begin
    for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: data_cache_rd_hit_way
        // Cycle 0
        assign wr_en[i]         =   |cache_wr_en_byte[i] ? cache_ens[i] : 'd0;
        assign rd_en[i]         =   cache_ens[i];
        assign evict_en[i]      =   cache_evicts[i];
        assign rd_hit_way[i]    =   rd_en[i][0] ? 3'd0      :
                                    rd_en[i][1] ? 3'd1      :
                                    rd_en[i][2] ? 3'd2      :
                                    rd_en[i][3] ? 3'd3      :
                                                  {3{1'b1}} ; // all 1's for debug

        assign evict_way[i]     =   evict_en[i][0] ? 3'd0       :
                                    evict_en[i][1] ? 3'd1       :
                                    evict_en[i][2] ? 3'd2       :
                                    evict_en[i][3] ? 3'd3       :
                                                     {3{1'b1}}  ; // all 1's for debug
        // Cycle 1
        always @(posedge clk) begin
            rd_hit_way_reg[i]   <= rd_hit_way[i];
            evict_way_reg[i]    <= evict_way[i];
            cache_evicted[i]    <= |cache_evicts[i];
        end
        `ifdef SMAC
            assign cache_evict_smac[i] = `SMAC_WIDTH'd0;
        `endif
    end
end
endgenerate

// Data Cache Control, these are the same
wire [`D_INDEX_WIDTH-1:0]       wr_index            [`SENTRY_WIDTH-1:0];
wire [`D_INDEX_WIDTH-1:0]       rd_index            [`SENTRY_WIDTH-1:0];

generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: data_cache_line
    assign wr_index[i]      = cache_wr_addr[i][`BYTE_OFFSET_WIDTH+:`D_INDEX_WIDTH];
    assign rd_index[i]      = cache_rd_addr[i][`BYTE_OFFSET_WIDTH+:`D_INDEX_WIDTH];
end
endgenerate

// Victim cam line byte update
line_t                          updated_victim_cam_line [`SENTRY_WIDTH-1:0];
// Victim Line Write Before
wire [7:0]                      victim_original_byte    [`SENTRY_WIDTH-1:0];
wire [15:0]                     victim_original_hword   [`SENTRY_WIDTH-1:0];
wire [31:0]                     victim_original_word    [`SENTRY_WIDTH-1:0];
wire [63:0]                     victim_original_dword   [`SENTRY_WIDTH-1:0];
wire [127:0]                    victim_original_qword   [`SENTRY_WIDTH-1:0];
// Victim Line Write After
wire [7:0]                      victim_updated_byte     [`SENTRY_WIDTH-1:0];
wire [15:0]                     victim_updated_hword    [`SENTRY_WIDTH-1:0];
wire [31:0]                     victim_updated_word     [`SENTRY_WIDTH-1:0];
wire [63:0]                     victim_updated_dword    [`SENTRY_WIDTH-1:0];
wire [127:0]                    victim_updated_qword    [`SENTRY_WIDTH-1:0];

generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: update_victim_cam_line

assign victim_original_qword[i]= victim_cam_line[i][victim_qword_sel[i]*128+:128];
assign victim_original_dword[i]= victim_original_qword[i][victim_dword_sel[i]*64+:64];
assign victim_original_word[i] = victim_original_dword[i][victim_word_sel[i]*32+:32];
assign victim_original_hword[i]= victim_original_word[i][victim_hword_sel[i]*16+:16];
assign victim_original_byte[i] = victim_original_hword[i][victim_byte_sel[i]*8+:8];

assign victim_updated_byte[i]  = victim_byte_write[i]   ?   victim_write_byte[i] : victim_original_byte[i];

assign victim_updated_hword[i] = victim_hword_write[i]  ?   victim_write_hword[i] : 
                                 victim_byte_sel[i]     ?   {victim_updated_byte[i], victim_original_hword[i][7: 0]} : 
                                                            {victim_original_hword[i][15:8], victim_updated_byte[i]} ;

assign victim_updated_word[i]  = victim_word_write[i]   ?   victim_write_word[i]  : 
                                 victim_hword_sel[i]    ?   {victim_updated_hword[i], victim_original_word[i][15: 0]} : 
                                                            {victim_original_word[i][31:16], victim_updated_hword[i]} ;

assign victim_updated_dword[i] = victim_dword_write[i]  ?   victim_write_dword[i] : 
                                 victim_word_sel[i]     ?   {victim_updated_word[i], victim_original_dword[i][31: 0]} : 
                                                            {victim_original_dword[i][63:32], victim_updated_word[i]} ;

assign victim_updated_qword[i] = victim_dword_sel[i]    ?   {victim_updated_dword[i], victim_original_qword[i][63 : 0]} : 
                                                            {victim_original_qword[i][127:64], victim_updated_dword[i]} ;

assign updated_victim_cam_line[i] = victim_qword_sel[i] == 2'b00 ? {victim_cam_line[i][511:128], victim_updated_qword[i]                           } :
                                    victim_qword_sel[i] == 2'b01 ? {victim_cam_line[i][511:256], victim_updated_qword[i], victim_cam_line[i][127:0]} :
                                    victim_qword_sel[i] == 2'b10 ? {victim_cam_line[i][511:384], victim_updated_qword[i], victim_cam_line[i][255:0]} :
                                                                   {                             victim_updated_qword[i], victim_cam_line[i][383:0]} ;

end
endgenerate

generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: delayed_memory_line
    for (j=0; j<`LINE_WIDTH_BYTE; j=j+1) begin
        // Cycle 0
        assign wr_en_byte[i][j] = cache_wr_en_byte[i][j] ? cache_ens[i] : 'd0;
        // Cycle 1
        assign cache_rd_line[i][(j+1)*8-1:j*8]  = actual_rd_line[i][j];
        //assign cache_evict_line[i][(j+1)*8-1:j*8]  = evict_line[i][j]; // evict line is only fill when evict_way is asserted
        assign cache_evict_line[i][(j+1)*8-1:j*8]  = actual_evict_line[i][j]; // evict line is only fill when evict_way is asserted
        assign read_hit[i][j] = wr_en_byte[i][j] == 'd0;
        // Cycle 1
        always @(posedge clk) begin
            pipe_mhb[i][j]      <= |wr_en_byte[i][j]; // if a byte is writing, need to use incoming data for that byte
            memory_line[i][j]   <= cache_wr_line[i][(j+1)*8-1:j*8];
            victim_cam_en_reg[i]<= victim_cam_en[i];
        end
        assign victim_line[i][j] = updated_victim_cam_line[i][(j+1)*8-1:j*8];
        // Cycle 1 multiplexed incoming line from cam or memory
        assign incoming_line[i][j] = victim_cam_en_reg[i]? victim_line[i][j] : memory_line[i][j];
    end
end
endgenerate
// Line forwarding logic
generate
if(`DWAYS == 4) begin
    // byte wise forwarding
    for (i=0; i<`LINE_WIDTH_BYTE; i=i+1) begin
        // Cycle 1
        always @(posedge clk) begin
            // same frame store to read forward, should add read hit as one of the criterias
            forward0to1[i] <= wr_index[0] == rd_index[1] && wr_en[0] == rd_en[1] && cache_wr_en_byte[0][i];
            forward0to2[i] <= wr_index[0] == rd_index[2] && wr_en[0] == rd_en[2] && cache_wr_en_byte[0][i];
            forward0to3[i] <= wr_index[0] == rd_index[3] && wr_en[0] == rd_en[3] && cache_wr_en_byte[0][i];
            forward1to2[i] <= wr_index[1] == rd_index[2] && wr_en[1] == rd_en[2] && cache_wr_en_byte[1][i];
            forward1to3[i] <= wr_index[1] == rd_index[3] && wr_en[1] == rd_en[3] && cache_wr_en_byte[1][i];
            forward2to3[i] <= wr_index[2] == rd_index[3] && wr_en[2] == rd_en[3] && cache_wr_en_byte[2][i];
            // same frame store to evict forward
            evict_forward0to1[i] <= wr_index[0] == rd_index[1] && wr_en[0] == evict_en[1] && cache_wr_en_byte[0][i];
            evict_forward0to2[i] <= wr_index[0] == rd_index[2] && wr_en[0] == evict_en[2] && cache_wr_en_byte[0][i];
            evict_forward0to3[i] <= wr_index[0] == rd_index[3] && wr_en[0] == evict_en[3] && cache_wr_en_byte[0][i];
            evict_forward1to2[i] <= wr_index[1] == rd_index[2] && wr_en[1] == evict_en[2] && cache_wr_en_byte[1][i];
            evict_forward1to3[i] <= wr_index[1] == rd_index[3] && wr_en[1] == evict_en[3] && cache_wr_en_byte[1][i];
            evict_forward2to3[i] <= wr_index[2] == rd_index[3] && wr_en[2] == evict_en[3] && cache_wr_en_byte[2][i];
        end
        // Cycle 1
        // if cache hit, use cache read line, else if cam forward, use victim line, otherwise use pkt2 line
        // The correct order here should be, if cache read miss, use incoming line, 
        // then check if there is forwarding from previous pipelines in the design,
        // then use the cache read line
        assign actual_rd_line[0][i] =   pipe_mhb[0][i]  ? incoming_line[0][i]   : rd_line[0][i];

        assign actual_rd_line[1][i] =   pipe_mhb[1][i]  ? incoming_line[1][i]   :
                                        forward0to1[i]  ? actual_rd_line[0][i]  : rd_line[1][i];
                                        

        assign actual_rd_line[2][i] =   pipe_mhb[2][i]  ? incoming_line[2][i]   :
                                        forward1to2[i]  ? actual_rd_line[1][i]  :
                                        forward0to2[i]  ? actual_rd_line[0][i]  : rd_line[2][i];
                                        

        assign actual_rd_line[3][i] =   pipe_mhb[3][i]  ? incoming_line[3][i]   :
                                        forward2to3[i]  ? actual_rd_line[2][i]  :
                                        forward1to3[i]  ? actual_rd_line[1][i]  :
                                        forward0to3[i]  ? actual_rd_line[0][i]  : rd_line[3][i];
                                        
        // Cycle 1
        // if cache evict, use cache read line, else if cam forward, use victim line, otherwise use pkt2 line
        assign actual_evict_line[0][i] =    evict_line[0][i];

        assign actual_evict_line[1][i] =    evict_forward0to1[i]    ? incoming_line[0][i] : evict_line[1][i];

        assign actual_evict_line[2][i] =    evict_forward1to2[i]    ? incoming_line[1][i] :
                                            evict_forward0to2[i]    ? incoming_line[0][i] : evict_line[2][i];

        assign actual_evict_line[3][i] =    evict_forward2to3[i]    ? incoming_line[2][i] :
                                            evict_forward1to3[i]    ? incoming_line[1][i] :
                                            evict_forward0to3[i]    ? incoming_line[0][i] : evict_line[3][i];
    end
end
endgenerate


// line read and write
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
    for (j=0; j<`DWAYS; j=j+1) begin
        for (k=0; k<`LINE_WIDTH_BYTE; k=k+1) begin
            always @(posedge clk) begin
                // cache write is on to many (Cycle 1)
                cache_wr_en[i][j][k]        <= cache_ens[i][j] ? cache_wr_en_byte[i][k] : 1'b0; // write byte enable is gated by way enable
            end
            // Cycle 1, cache write can be data from memory or data from victim cam read back
            assign cache_wr_line_byte[i][j][k] = incoming_line[i][k]; //victim_cam_en_reg[i]  ? victim_line[i][k] : memory_line[i][k];
            // Cycle 1
            assign cache_rd_way_line[i][j][(k+1)*8-1:k*8] = cache_rd_line_byte[i][j][k];
        end
    end
end

// cache read hit line
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
    for (j=0; j<`LINE_WIDTH_BYTE; j=j+1) begin
        // Cycle 1
        assign rd_line[i][j]    = cache_rd_line_byte[i][rd_hit_way_reg[i]][j];
        // evicted line could be coming from sth written just one frame earlier
        assign evict_line[i][j] = cache_evicted[i] ? cache_rd_line_byte[i][evict_way_reg[i]][j] : 'd0;
    end
end
endgenerate

// pack and unpack parallel dcache control data
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
    for (j=0; j<`DWAYS; j=j+1) begin
        always @(posedge clk) begin
            // Cycle 1
            cache_wr_index[i][j]    <=  wr_index[i];   // write index is the same for all ways
        end
        // Cycle 0
        assign cache_rd_index[i][j] =  rd_index[i];   // read index is the same for all ways
    end
end
endgenerate

generate
for (i=0; i<`DWAYS; i=i+1) begin: i_line_ram
    for (j=0; j<`LINE_WIDTH_BYTE; j=j+1) begin: byte_enable
        // instantiate a multiported-RAM with binary-coded register-based LVT
        mpram   #(  
            .MEMD   (MEMD            ),  // memory depth
            .DATAW  (DATAW           ),  // data width
            .nRPORTS(nRPORTS         ),  // number of reading ports
            .nWPORTS(nWPORTS         ),  // number of writing ports
            .TYPE   ("LVTREG"        ),  // multi-port RAM implementation type
            .BYP    (BYP             ),  // Bypassing type: NON, WAW, RAW, RDW
            .IFILE  ("zero"          ))  // initializtion file, optional
        //mpram_lvtreg_dut (  
        //    .clk    (clk                                                            ),  // clock
        //    .WEnb   ({wr_en[3][i], wr_en[2][i], wr_en[1][i], wr_en[0][i]}           ),  // write enable for each writing port                - in : [nWPORTS-1:0            ]
        //    .WAddr  ({wr_index[3], wr_index[2], wr_index[1], wr_index[0]}           ),  // write addresses - packed from nWPORTS write ports - in : [`log2(MEMD)*nWPORTS-1:0]
        //    .WData  ({wr_line[3], wr_line[2], wr_line[1], wr_line[0]}               ),  // write data      - packed from nRPORTS read  ports - out: [DATAW      *nWPORTS-1:0]
        //    .RAddr  ({rd_index[3], rd_index[2], rd_index[1], rd_index[0]}           ),  // read  addresses - packed from nRPORTS read  ports - in : [`log2(MEMD)*nRPORTS-1:0]
        //    .RData  ({rd_line[3][i], rd_line[2][i], rd_line[1][i], rd_line[0][i]}   )); // read  data      - packed from nRPORTS read  ports - out: [DATAW      *nRPORTS-1:0]
        mpram_lvtreg_dcache (  
            .clk    (clk                        ),  // clock
            .WEnb   ({cache_wr_en[3][i][j],cache_wr_en[2][i][j],cache_wr_en[1][i][j],cache_wr_en[0][i][j]}         ),  // write enable for each writing port                - in : [nWPORTS-1:0            ]
            .WAddr  ({cache_wr_index[3][i],cache_wr_index[2][i],cache_wr_index[1][i],cache_wr_index[0][i]}          ),  // write addresses - packed from nWPORTS write ports - in : [`log2(MEMD)*nWPORTS-1:0]
            .WData  ({cache_wr_line_byte[3][i][j],cache_wr_line_byte[2][i][j],cache_wr_line_byte[1][i][j],cache_wr_line_byte[0][i][j]}  ),  // write data      - packed from nRPORTS read  ports - out: [DATAW      *nWPORTS-1:0]
            .RAddr  ({cache_rd_index[3][i],cache_rd_index[2][i],cache_rd_index[1][i],cache_rd_index[0][i]}         ),  // read  addresses - packed from nRPORTS read  ports - in : [`log2(MEMD)*nRPORTS-1:0]
            .RData  ({cache_rd_line_byte[3][i][j],cache_rd_line_byte[2][i][j],cache_rd_line_byte[1][i][j],cache_rd_line_byte[0][i][j]}  )); // read  data      - packed from nRPORTS read  ports - out: [DATAW      *nRPORTS-1:0]
    end
end
endgenerate



endmodule


