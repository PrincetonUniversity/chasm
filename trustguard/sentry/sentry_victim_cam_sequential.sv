// DCache Sequential Victim CAM buffer of sentry unit
`timescale 1ns/1ps
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

module sentry_victim_cam_sequential #(
    parameter ADDR_WIDTH = 4
)
(
    // Cache parallel eviction
    input  logic    cache_evicted,
    input  line_t   cache_evict_line,
    // Cache victim read back
    input  vindex_t victim_cam_index,
    output line_t   victim_cam_line,
    // sentry clock and reset
    input           clk,
    input           rst
);

// Write pointer manager
reg [ADDR_WIDTH-1:0] ptr; 

always @(posedge clk) begin
    if(rst) ptr <= 'd0;
    else if(cache_evicted) ptr <= ptr + 'd1;
end

// multiport ram control 
reg                     ram_wr_en;
reg  [ADDR_WIDTH-1:0]   ram_wr_index;
line_t                  ram_wr_line;
reg  [ADDR_WIDTH-1:0]   ram_rd_index;
line_t                  ram_rd_line;

// multiport ram control
// write control (Cycle 0) 
// because the evict writes of previous cache access is already delayed 1 cycle 
assign ram_wr_en        = cache_evicted;
assign ram_wr_index     = ptr;
assign ram_wr_line      = cache_evict_line;
// read control (Cycle 0)
assign ram_rd_index     = victim_cam_index;
assign victim_cam_line  = ram_rd_line;

// ram block instantiation
ram_block #(
    .DATA_WIDTH         (`LINE_WIDTH    ),
    .ADDR_WIDTH         (ADDR_WIDTH     ),
    .INITIALIZE_TO_ZERO (1)
)
CAM_ADDR_RAM (
    .clk            (clk                ),
    .wr_en          (ram_wr_en          ),
    .wr_addr        (ram_wr_index       ),
    .wr_data        (ram_wr_line        ),
    .rd_addr        (ram_rd_index       ),
    .rd_data        (ram_rd_line        )
);

endmodule


