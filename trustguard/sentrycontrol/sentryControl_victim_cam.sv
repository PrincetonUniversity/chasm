// DCache Victim CAM buffer of sentryControl unit
`timescale 1ns/1ps
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

module sentryControl_victim_cam #(
    parameter ADDR_WIDTH = 4
)
(
    // data victim cam insert interface
    input  mem_req_t                    cam_insert_fifo_output,
    output logic                        cam_insert_fifo_rd_en,
    input  logic                        cam_insert_fifo_almost_empty,
    input  logic                        cam_insert_fifo_empty,
    // data victim cam clear interface
    //input  logic                        victim_cam_clear,
    input  addr_t                       cam_clear_fifo_output,
    output logic                        cam_clear_fifo_rd_en,
    input  logic                        cam_clear_fifo_almost_empty,
    input  logic                        cam_clear_fifo_empty,
    // read interface from data victim cam lookup request queue/fifo
    input  mem_req_t                    cam_req_fifo_output,
    output logic                        cam_req_fifo_rd_en,
    input  logic                        cam_req_fifo_almost_empty,
    input  logic                        cam_req_fifo_empty,
    // interface to data_vpkt_fifo
    output vpkt_t                       data_vpkt_fifo_input,
    output logic [`SENTRY_WIDTH-1:0]    data_vpkt_fifo_wr_en,
    input  logic [`SENTRY_WIDTH-1:0]    data_vpkt_fifo_full,
    input  logic [`SENTRY_WIDTH-1:0]    data_vpkt_fifo_almost_full,
    // write interface to memory manager request queue/fifo
    output mem_req_t                    mem_req_fifo_input,
    output logic                        mem_req_fifo_wr_en,
    input  logic                        mem_req_fifo_full,
    input  logic                        mem_req_fifo_almost_full,
    // Clock and Reset
    input                               clk,
    input                               rst
);


// victim cam fill logic 
reg  [ADDR_WIDTH-1:0]   wr_ptr;
reg  [ADDR_WIDTH-1:0]   rd_ptr;
reg  [ADDR_WIDTH:0]     status_cnt;
wire [ADDR_WIDTH:0]     status_threshold = {{(ADDR_WIDTH-2){1'b1}}, 2'd0};

reg                     wr_en;
reg                     rd_en;
wire full = status_cnt == {ADDR_WIDTH{1'b1}};
wire empty = status_cnt =={ADDR_WIDTH{1'b0}};

wire victim_cam_full;
addr_t victim_cam_data;

assign victim_cam_full = status_cnt == status_threshold;

//assign victim_cam_en = !cam_insert_fifo_empty;
//assign victim_cam_data = cam_insert_fifo_output;
//
//assign cam_insert_fifo_rd_en = !cam_insert_fifo_empty && !victim_cam_full;

// CAM need to sequentialized processing of insert and lookup request, instead of doing them in parallel

// CAM also need to disallow clear during lookup cause that might cause status_cnt to decrement
// and cause the lookup to miss the last one entry

// So the order should be instruction lookup -> same instruction insert-> cam clear

always @(posedge clk) begin
    if(rst)                 wr_ptr <= 0;
    //else if(!cam_insert_fifo_empty && !victim_cam_full)  wr_ptr <= wr_ptr + 1;
    else if(wr_en && !victim_cam_full)  wr_ptr <= wr_ptr + 1;
end

//assign cam_clear_fifo_rd_en = !cam_clear_fifo_empty;
//assign rd_en = !cam_clear_fifo_empty;

always @(posedge clk) begin
    if(rst)         rd_ptr <= 0;
    //else if(!cam_clear_fifo_empty)  rd_ptr <= rd_ptr + 1;
    else if(rd_en)  rd_ptr <= rd_ptr + 1; // clear does not wait for anyone
end

always @(posedge clk) begin
    if(rst) status_cnt <= 0;
    // if insert valid and clear invalid, add 1 to count
    else if(wr_en && !rd_en) status_cnt <= status_cnt + 1;
    // if insert invalid and clear valid, sub 1 to count
    else if(!wr_en && rd_en) status_cnt <= status_cnt - 1;
end


// loop around all available slots for match
reg [ADDR_WIDTH-1:0]    loop_ptr;
reg [ADDR_WIDTH-1:0]    loop_ptr_reg;
reg [ADDR_WIDTH:0]      loop_cnt;
reg [ADDR_WIDTH:0]      loop_cnt_reg;
reg [ADDR_WIDTH:0]      loop_cnt_reg_reg;
addr_t                  loop_data;
reg                     found;
reg [ADDR_WIDTH-1:0]    found_idx;
reg                     match_found;
reg                     match_not_found;

typedef enum {
    S_CAM_IDLE,     // 0
    S_CAM_LOOKUP,   // 1
    S_CAM_LOOKING,   // 1
    S_CAM_LOOKUP_COMPARE,   // 1
    S_CAM_LOOKUP_RESOLVE,   // 1
    S_CAM_LOOKUP_DONE,   // 1
    S_CAM_INSERT,   // 2
    S_CAM_CLEAR,    // 3
    S_CAM_MEMREQ,   // 4
    S_CAM_DONE      // 5
} cam_state_e;

cam_state_e CAM_STATE;
cam_state_e next_CAM_STATE;

always @(posedge clk) begin
    if(rst) CAM_STATE <= S_CAM_IDLE;
    else CAM_STATE <= next_CAM_STATE;
end

//************************
// CAM FSM
//************************
always @(*) begin
    next_CAM_STATE = CAM_STATE;
    case(CAM_STATE)
        S_CAM_IDLE: begin
            // if lookup upstream empty and insert upstream not empty and cam not full, just do insert
            if(!cam_insert_fifo_empty && cam_req_fifo_empty && !victim_cam_full) begin
                next_CAM_STATE = S_CAM_INSERT; 
            end
            // if insert upstream empty and lookup upstream not empty, just do lookup
            else if(cam_insert_fifo_empty && !cam_req_fifo_empty) begin
                // do nothing is downstream full
                if(mem_req_fifo_almost_full) begin
                    next_CAM_STATE = S_CAM_IDLE;
                end
                // if victim cam not empty, lookup
                else if(!empty) begin
                    next_CAM_STATE = S_CAM_LOOKUP;
                end
                // if upstream valid, downstream accepting and cam empty, go straight to mem req
                else begin
                    next_CAM_STATE = S_CAM_MEMREQ;
                end
            end
            // if both upstreams non-empty, compare tag.number and give lookup priority on equality
            // because if one instruction both lookup and evict, look up happens first
            else if(!cam_insert_fifo_empty && !cam_req_fifo_empty) begin
                // if lookup inst is before insert inst, do lookup first if victim cam not empty
                if((cam_req_fifo_output.tag.number <= cam_insert_fifo_output.tag.number)) begin // maybe this should be broken up
                    if(!empty) next_CAM_STATE = S_CAM_LOOKUP;
                    else next_CAM_STATE = S_CAM_MEMREQ;
                end
                // otherwise do insert if victim cam not full
                else if (!victim_cam_full) begin
                    next_CAM_STATE = S_CAM_INSERT;
                end
                else if (!cam_clear_fifo_empty) begin
                    next_CAM_STATE = S_CAM_CLEAR;
                end
                else begin
                    next_CAM_STATE = S_CAM_IDLE;
                end
            end
            else if (!cam_clear_fifo_empty) begin
                next_CAM_STATE = S_CAM_CLEAR;
            end
            else begin
                next_CAM_STATE = S_CAM_IDLE;
            end
        end
        S_CAM_INSERT: begin
            next_CAM_STATE = S_CAM_DONE;
        end
        S_CAM_LOOKUP: begin
            next_CAM_STATE = S_CAM_LOOKING;
        end
        S_CAM_LOOKING: begin
            if(loop_cnt == status_cnt-1) begin
                next_CAM_STATE = S_CAM_LOOKUP_COMPARE;
            end
        end
        S_CAM_LOOKUP_COMPARE: begin
            next_CAM_STATE = S_CAM_LOOKUP_RESOLVE;
        end
        S_CAM_LOOKUP_RESOLVE: begin
            next_CAM_STATE = S_CAM_LOOKUP_DONE;
        end
        S_CAM_LOOKUP_DONE: begin
            if(match_found) begin
                next_CAM_STATE = S_CAM_DONE;
            end
            else if(match_not_found) begin
                next_CAM_STATE = S_CAM_MEMREQ;
            end
        end
        S_CAM_MEMREQ: begin
            next_CAM_STATE = S_CAM_DONE;
        end
        S_CAM_CLEAR: begin
            next_CAM_STATE = S_CAM_DONE;
        end
        S_CAM_DONE: begin
            next_CAM_STATE = S_CAM_IDLE;
        end
    endcase

end

always @(posedge clk) begin
    case(CAM_STATE)
        S_CAM_IDLE: begin
            // if lookup upstream empty and insert upstream not empty and cam not full, just do insert
            if(!cam_insert_fifo_empty && cam_req_fifo_empty && !victim_cam_full) begin
                wr_en                   <= 0;
                rd_en                   <= 0;
                data_vpkt_fifo_input    <= 0;
                data_vpkt_fifo_wr_en    <= 0;
                mem_req_fifo_wr_en      <= 0;
                mem_req_fifo_input      <= 0;
                cam_insert_fifo_rd_en   <= 0;
                cam_clear_fifo_rd_en    <= 0;
                cam_req_fifo_rd_en      <= 0;
                victim_cam_data         <= 0;
            end
            // if insert upstream empty and lookup upstream not empty, just do lookup
            else if(cam_insert_fifo_empty && !cam_req_fifo_empty) begin
                // do nothing is downstream full
                if(mem_req_fifo_almost_full) begin
                    wr_en                   <= 0;
                    rd_en                   <= 0;
                    data_vpkt_fifo_input    <= 0;
                    data_vpkt_fifo_wr_en    <= 0;
                    mem_req_fifo_wr_en      <= 0;
                    mem_req_fifo_input      <= 0;
                    cam_insert_fifo_rd_en   <= 0;
                    cam_clear_fifo_rd_en    <= 0;
                    cam_req_fifo_rd_en      <= 0;
                    victim_cam_data         <= 0;
                end
                // if victim cam not empty, lookup
                else if(!empty) begin
                    wr_en                   <= 0;
                    rd_en                   <= 0;
                    data_vpkt_fifo_input    <= 0;
                    data_vpkt_fifo_wr_en    <= 0;
                    mem_req_fifo_wr_en      <= 0;
                    mem_req_fifo_input      <= 0;
                    cam_insert_fifo_rd_en   <= 0;
                    cam_clear_fifo_rd_en    <= 0;
                    cam_req_fifo_rd_en      <= 0;
                    victim_cam_data         <= 0;
                end
                // if upstream valid, downstream accepting and cam empty, go straight to mem req
                else begin
                    data_vpkt_fifo_input.tag    <= cam_req_fifo_output.tag;
                    data_vpkt_fifo_input.mhb    <= 1;
                    data_vpkt_fifo_input.vidx   <= 0;
                    data_vpkt_fifo_wr_en        <= cam_req_fifo_output.tag.rotate;
                    wr_en                       <= 0;
                    rd_en                       <= 0;
                    mem_req_fifo_wr_en          <= 0;
                    mem_req_fifo_input          <= 0;
                    cam_insert_fifo_rd_en       <= 0;
                    cam_clear_fifo_rd_en        <= 0;
                    cam_req_fifo_rd_en          <= 0;
                    victim_cam_data             <= 0;
                end
            end
            // if both upstreams non-empty, compare tag.number and give lookup priority on equality
            // because if one instruction both lookup and evict, look up happens first
            else if(!cam_insert_fifo_empty && !cam_req_fifo_empty) begin
                // if lookup inst is before insert inst, do lookup first if victim cam not empty
                if((cam_req_fifo_output.tag.number <= cam_insert_fifo_output.tag.number)) begin // maybe this should be broken up
                    if(!empty) begin
                        wr_en                   <= 0;
                        rd_en                   <= 0;
                        data_vpkt_fifo_input    <= 0;
                        data_vpkt_fifo_wr_en    <= 0;
                        mem_req_fifo_wr_en      <= 0;
                        mem_req_fifo_input      <= 0;
                        cam_insert_fifo_rd_en   <= 0;
                        cam_clear_fifo_rd_en    <= 0;
                        cam_req_fifo_rd_en      <= 0;
                        victim_cam_data         <= 0;
                    end
                    // if empty, go straght to memory request
                    else begin
                        data_vpkt_fifo_input.tag    <= cam_req_fifo_output.tag;
                        data_vpkt_fifo_input.mhb    <= 1;
                        data_vpkt_fifo_input.vidx   <= 0;
                        data_vpkt_fifo_wr_en        <= cam_req_fifo_output.tag.rotate;
                        wr_en                       <= 0;
                        rd_en                       <= 0;
                        mem_req_fifo_wr_en          <= 0;
                        mem_req_fifo_input          <= 0;
                        cam_insert_fifo_rd_en       <= 0;
                        cam_clear_fifo_rd_en        <= 0;
                        cam_req_fifo_rd_en          <= 0;
                        victim_cam_data             <= 0;
                    end
                end
                // otherwise do insert if victim cam not full
                else if (!victim_cam_full) begin
                    wr_en                   <= 0;
                    rd_en                   <= 0;
                    data_vpkt_fifo_input    <= 0;
                    data_vpkt_fifo_wr_en    <= 0;
                    mem_req_fifo_wr_en      <= 0;
                    mem_req_fifo_input      <= 0;
                    cam_insert_fifo_rd_en   <= 0;
                    cam_clear_fifo_rd_en    <= 0;
                    cam_req_fifo_rd_en      <= 0;
                    victim_cam_data         <= 0;
                end
                else if (!cam_clear_fifo_empty) begin
                    wr_en                   <= 0;
                    rd_en                   <= 0;
                    data_vpkt_fifo_input    <= 0;
                    data_vpkt_fifo_wr_en    <= 0;
                    mem_req_fifo_wr_en      <= 0;
                    mem_req_fifo_input      <= 0;
                    cam_insert_fifo_rd_en   <= 0;
                    cam_clear_fifo_rd_en    <= 0;
                    cam_req_fifo_rd_en      <= 0;
                    victim_cam_data         <= 0;
                end
                else begin
                    wr_en                   <= 0;
                    rd_en                   <= 0;
                    data_vpkt_fifo_input    <= 0;
                    data_vpkt_fifo_wr_en    <= 0;
                    mem_req_fifo_wr_en      <= 0;
                    mem_req_fifo_input      <= 0;
                    cam_insert_fifo_rd_en   <= 0;
                    cam_clear_fifo_rd_en    <= 0;
                    cam_req_fifo_rd_en      <= 0;
                    victim_cam_data         <= 0;
                end
            end
            else if (!cam_clear_fifo_empty) begin
                wr_en                   <= 0;
                rd_en                   <= 0;
                data_vpkt_fifo_input    <= 0;
                data_vpkt_fifo_wr_en    <= 0;
                mem_req_fifo_wr_en      <= 0;
                mem_req_fifo_input      <= 0;
                cam_insert_fifo_rd_en   <= 0;
                cam_clear_fifo_rd_en    <= 0;
                cam_req_fifo_rd_en      <= 0;
                victim_cam_data         <= 0;
            end
            else begin
                wr_en                   <= 0;
                rd_en                   <= 0;
                data_vpkt_fifo_input    <= 0;
                data_vpkt_fifo_wr_en    <= 0;
                mem_req_fifo_wr_en      <= 0;
                mem_req_fifo_input      <= 0;
                cam_insert_fifo_rd_en   <= 0;
                cam_clear_fifo_rd_en    <= 0;
                cam_req_fifo_rd_en      <= 0;
                victim_cam_data         <= 0;
            end
        end
        S_CAM_INSERT: begin
            wr_en                   <= 1;
            rd_en                   <= 0;
            data_vpkt_fifo_input    <= 0;
            data_vpkt_fifo_wr_en    <= 0;
            mem_req_fifo_wr_en      <= 0;
            mem_req_fifo_input      <= 0;
            cam_insert_fifo_rd_en   <= 1; // delayed insert_fifo rd_en of 1
            cam_clear_fifo_rd_en    <= 0;
            cam_req_fifo_rd_en      <= 0;
            victim_cam_data         <= cam_insert_fifo_output.addr;
        end
        S_CAM_LOOKUP_DONE: begin
            if(match_found) begin
                wr_en                       <= 0;
                rd_en                       <= 0;
                mem_req_fifo_wr_en          <= 0;
                mem_req_fifo_input          <= 0;
                cam_insert_fifo_rd_en       <= 0;
                cam_clear_fifo_rd_en        <= 0;
                victim_cam_data             <= 0;
                data_vpkt_fifo_input.tag    <= cam_req_fifo_output.tag;
                data_vpkt_fifo_input.mhb    <= 0;
                data_vpkt_fifo_input.vidx   <= found_idx;
                data_vpkt_fifo_wr_en        <= cam_req_fifo_output.tag.rotate;
                cam_req_fifo_rd_en          <= 1; // delayed req fifo rd_en of 1
            end
            else if(match_not_found) begin
                wr_en                       <= 0;
                rd_en                       <= 0;
                mem_req_fifo_wr_en          <= 0;
                mem_req_fifo_input          <= 0;
                cam_insert_fifo_rd_en       <= 0;
                cam_clear_fifo_rd_en        <= 0;
                victim_cam_data             <= 0;
                data_vpkt_fifo_input.tag    <= cam_req_fifo_output.tag;
                data_vpkt_fifo_input.mhb    <= 1;
                data_vpkt_fifo_input.vidx   <= 0;
                data_vpkt_fifo_wr_en        <= cam_req_fifo_output.tag.rotate;
                cam_req_fifo_rd_en          <= 0;
            end
        end
        S_CAM_MEMREQ: begin
            wr_en                   <= 0;
            rd_en                   <= 0;
            data_vpkt_fifo_input    <= 0;
            data_vpkt_fifo_wr_en    <= 0;
            mem_req_fifo_wr_en      <= 1;
            mem_req_fifo_input      <= cam_req_fifo_output;
            cam_insert_fifo_rd_en   <= 0;
            cam_clear_fifo_rd_en    <= 0;
            cam_req_fifo_rd_en      <= 1; //delayed req fifo rd_en of 1
            victim_cam_data         <= 0;
        end
        S_CAM_CLEAR: begin
            wr_en                   <= 0;
            rd_en                   <= 1;
            data_vpkt_fifo_input    <= 0;
            data_vpkt_fifo_wr_en    <= 0;
            mem_req_fifo_wr_en      <= 0;
            mem_req_fifo_input      <= 0;
            cam_insert_fifo_rd_en   <= 0;
            cam_clear_fifo_rd_en    <= 1; // delayed clear fifo rd_en of 1
            cam_req_fifo_rd_en      <= 0;
            victim_cam_data         <= 0;
        end
        S_CAM_DONE: begin
            wr_en                   <= 0;
            rd_en                   <= 0;
            data_vpkt_fifo_input    <= 0;
            data_vpkt_fifo_wr_en    <= 0;
            mem_req_fifo_wr_en      <= 0;
            mem_req_fifo_input      <= 0;
            cam_insert_fifo_rd_en   <= 0;
            cam_clear_fifo_rd_en    <= 0;
            cam_req_fifo_rd_en      <= 0;
            victim_cam_data         <= 0;
        end
        default: begin
            wr_en                   <= 0;
            rd_en                   <= 0;
            data_vpkt_fifo_input    <= 0;
            data_vpkt_fifo_wr_en    <= 0;
            mem_req_fifo_wr_en      <= 0;
            mem_req_fifo_input      <= 0;
            cam_insert_fifo_rd_en   <= 0;
            cam_clear_fifo_rd_en    <= 0;
            cam_req_fifo_rd_en      <= 0;
            victim_cam_data         <= 0;
        end
    endcase
end

// cam should find the latest copy of the content
// as in if there are two copies of the same address evicted
// one old and one new, then we pick the new one
// so we start from the wr_ptr and work our ways backwards
always @(posedge clk) begin
    loop_ptr_reg <= loop_ptr;
    if(CAM_STATE == S_CAM_LOOKUP) begin
        loop_ptr <= rd_ptr;
        loop_cnt <= 'd0;
        match_found <= 0;
        match_not_found <= 0;
        found <= 0;
        found_idx <= 0;
    end
    else if(CAM_STATE == S_CAM_LOOKING) begin
        // make sure match_found, match_not_found and found_idx assert on the same clock rising edge
        if(loop_cnt != status_cnt-1) begin
            loop_ptr <= loop_ptr + 1;
            loop_cnt <= loop_cnt + 1;
        end
        // Cycle 1 comparison, Cycle 2 assignment
        if(loop_data == cam_req_fifo_output.addr) begin
            found_idx   <= loop_ptr_reg;
            found       <= 1;
        end
    end
    else if(CAM_STATE == S_CAM_LOOKUP_COMPARE) begin
        // need to compare the last entry of data
        if(loop_data == cam_req_fifo_output.addr) begin
            found_idx   <= loop_ptr_reg;
            found       <= 1;
        end
    end
    else if(CAM_STATE == S_CAM_LOOKUP_RESOLVE) begin
        // if loop reached the end and no match, issue mem_req (Cycle 2 after last valid comparison)
        // Cycle 2 if statment, Cycle 2 match_found update
        if(found) begin
            match_found <= 1;
        end else begin
            match_not_found <= 1;
        end
    end
    // when idle, set loop_ptr to the last write location
    else begin
        loop_ptr <= rd_ptr;
        loop_cnt <= 'd0;
        match_found <= 0;
        match_not_found <= 0;
        found <= 0;
        found_idx <= 0;
    end
end

// ram block instantiation
ram_block #(
    .DATA_WIDTH         ($bits(addr_t)  ),
    .ADDR_WIDTH         (ADDR_WIDTH     ),
    .INITIALIZE_TO_ZERO (1)
)
CAM_ADDR_RAM (
    .clk        (clk                ),
    .wr_en      (wr_en              ),
    .wr_addr    (wr_ptr             ),
    .wr_data    (victim_cam_data    ),
    .rd_addr    (loop_ptr           ),
    .rd_data    (loop_data          )
);

`ifdef SIMULATION
    reg [31:0] evict_in_cnt;
    reg [31:0] evict_out_cnt;
    always @(posedge clk) begin
        if(rst) begin
            evict_in_cnt <= 0;
            evict_out_cnt <= 0;
        end
        else begin
            if(cam_insert_fifo_rd_en) evict_in_cnt <= evict_in_cnt + 1;
            if(cam_clear_fifo_rd_en) evict_out_cnt <= evict_out_cnt + 1;
        end
    end
`endif


endmodule
