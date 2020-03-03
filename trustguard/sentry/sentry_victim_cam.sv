// DCache Victim CAM buffer of sentry unit
`timescale 1ns/1ps
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

module sentry_victim_cam #(
    parameter ADDR_WIDTH = 4
)
(
    // oracle evict write index
    //input  vindex_t                     cache_evict_index   [`SENTRY_WIDTH-1:0],
    // Cache parallel eviction
    input  logic [`SENTRY_WIDTH-1:0]    cache_evicted,
    input  line_t                       cache_evict_line    [`SENTRY_WIDTH-1:0],
    // Cache victim read back
    input  vindex_t                     victim_cam_index    [`SENTRY_WIDTH-1:0],
    output line_t                       victim_cam_line     [`SENTRY_WIDTH-1:0],
    // sentry clock and reset
    input                               clk,
    input                               rst
);

genvar i;

localparam MEMD     = 2**ADDR_WIDTH ; // memory depth
localparam DATAW    = `LINE_WIDTH   ; // data width
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

reg [ADDR_WIDTH-1:0]    wr_ptr      [`SENTRY_WIDTH-1:0];
reg [ADDR_WIDTH-1:0]    rd_ptr      [`SENTRY_WIDTH-1:0];
reg [ADDR_WIDTH:0]      status_cnt;

wire full = status_cnt == 4'hf;

// inst cache line forwarding and read logic
wire                            forward0to1;
wire                            forward0to2;
wire                            forward0to3;
wire                            forward1to2;
wire                            forward1to3;
wire                            forward2to3;
vindex_t                        victim_cam_index_reg    [`SENTRY_WIDTH-1:0];
line_t                          rd_line                 [`SENTRY_WIDTH-1:0];

// Write pointer manager
reg [ADDR_WIDTH-1:0] ptr; 
reg [ADDR_WIDTH-1:0] next_ptr;


// multiport ram control 
reg  [`SENTRY_WIDTH-1:0]                ram_wr_en;
reg  [`SENTRY_WIDTH*ADDR_WIDTH-1:0]     ram_wr_index;
reg  [`SENTRY_WIDTH*`LINE_WIDTH-1:0]    ram_wr_line;
reg  [`SENTRY_WIDTH*ADDR_WIDTH-1:0]     ram_rd_index;
wire [`SENTRY_WIDTH*`LINE_WIDTH-1:0]    ram_rd_line;

// write pointer is updated on Cycle 2
always @(posedge clk) begin
    if(rst) begin
        ptr <= 'd0;
    end
    else begin
        // Cycle 1
        ptr <= next_ptr;
    end
end
generate
if(`SENTRY_WIDTH == 4) begin
    // Cycle 0
    assign wr_ptr[0] = ptr;

    assign wr_ptr[1] = cache_evicted[0] ? wr_ptr[0]+1 : ptr;

    assign wr_ptr[2] = cache_evicted[1] ? wr_ptr[1]+1 : wr_ptr[1];

    assign wr_ptr[3] = cache_evicted[2] ? wr_ptr[2]+1 : wr_ptr[2];

    assign next_ptr  = cache_evicted[3] ? wr_ptr[3]+1 : wr_ptr[3];
end
endgenerate

// Forwarding logic, this needs to cover same cycle forwarding, 
// wr_ptr is cycle 1 and victim_cam_index is cycle 0, cache_evicted is cycle 1
// do we just delay victim_cam_index? fix for inst din 1322
// Cycle 1
generate
for (i=0; i< `DWAYS; i=i+1) begin
    always @(posedge clk) begin
        victim_cam_index_reg[i] <= victim_cam_index[i];
    end
end
endgenerate

assign forward0to1 = wr_ptr[0] == victim_cam_index_reg[1] && cache_evicted[0];
assign forward0to2 = wr_ptr[0] == victim_cam_index_reg[2] && cache_evicted[0];
assign forward0to3 = wr_ptr[0] == victim_cam_index_reg[3] && cache_evicted[0];
assign forward1to2 = wr_ptr[1] == victim_cam_index_reg[2] && cache_evicted[1];
assign forward1to3 = wr_ptr[1] == victim_cam_index_reg[3] && cache_evicted[1];
assign forward2to3 = wr_ptr[2] == victim_cam_index_reg[3] && cache_evicted[2];

assign victim_cam_line[0]   =   rd_line[0];

assign victim_cam_line[1]   =   forward0to1   ? cache_evict_line[0] : rd_line[1];

assign victim_cam_line[2]   =   forward1to2   ? cache_evict_line[1] :
                                forward0to2   ? cache_evict_line[0] : rd_line[2];

assign victim_cam_line[3]   =   forward2to3   ? cache_evict_line[2] :
                                forward1to3   ? cache_evict_line[1] :
                                forward0to3   ? cache_evict_line[0] : rd_line[3];

// multiport ram control
assign ram_wr_en = {cache_evicted[3],cache_evicted[2],cache_evicted[1],cache_evicted[0]};
assign ram_wr_index = {wr_ptr[3],wr_ptr[2],wr_ptr[1],wr_ptr[0]};
assign ram_wr_line = {cache_evict_line[3],cache_evict_line[2],cache_evict_line[1],cache_evict_line[0]};
assign ram_rd_index = {victim_cam_index[3],victim_cam_index[2],victim_cam_index[1],victim_cam_index[0]};
assign {rd_line[3],rd_line[2],rd_line[1],rd_line[0]} = ram_rd_line;

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
//mpram_lvtreg_dut (  
//    .clk    (clk                                                            ),  // clock
//    .WEnb   ({wr_en[3][i], wr_en[2][i], wr_en[1][i], wr_en[0][i]}           ),  // write enable for each writing port                - in : [nWPORTS-1:0            ]
//    .WAddr  ({wr_index[3], wr_index[2], wr_index[1], wr_index[0]}           ),  // write addresses - packed from nWPORTS write ports - in : [`log2(MEMD)*nWPORTS-1:0]
//    .WData  ({wr_line[3], wr_line[2], wr_line[1], wr_line[0]}               ),  // write data      - packed from nRPORTS read  ports - out: [DATAW      *nWPORTS-1:0]
//    .RAddr  ({rd_index[3], rd_index[2], rd_index[1], rd_index[0]}           ),  // read  addresses - packed from nRPORTS read  ports - in : [`log2(MEMD)*nRPORTS-1:0]
//    .RData  ({rd_line[3][i], rd_line[2][i], rd_line[1][i], rd_line[0][i]}   )); // read  data      - packed from nRPORTS read  ports - out: [DATAW      *nRPORTS-1:0]
mpram_lvtreg_cam (  
    .clk    (clk                ),  // clock
    .WEnb   (ram_wr_en          ),  // write enable for each writing port                - in : [nWPORTS-1:0            ]
    .WAddr  (ram_wr_index       ),  // write addresses - packed from nWPORTS write ports - in : [`log2(MEMD)*nWPORTS-1:0]
    .WData  (ram_wr_line        ),  // write data      - packed from nRPORTS read  ports - out: [DATAW      *nWPORTS-1:0]
    .RAddr  (ram_rd_index       ),  // read  addresses - packed from nRPORTS read  ports - in : [`log2(MEMD)*nRPORTS-1:0]
    .RData  (ram_rd_line        )   // read  data      - packed from nRPORTS read  ports - out: [DATAW      *nRPORTS-1:0]
);


endmodule

