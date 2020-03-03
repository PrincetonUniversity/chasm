// DCache Emulation part of sentryControl unit
`timescale 1ns/1ps
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

`define TIMING_OPT
// each cache set is composed of
// valid bit + dirty bit + tag bits + data bits

module sentryControl_dcache (
    // interface to Sentry Control Controller
    input  logic                        dcache_req_valid, // req fifo not empty
    input  din_t                        dcache_req_number,
    input  logic [`SENTRY_WIDTH-1:0]    dcache_req_rotate,
    input  logic                        dcache_req_store,
    output logic                        dcache_req_rd_en,
    input  addr_t                       dcache_req_address,
    // PERFOPT: add primitive register for all downstream fifo connections 
    // (3.6ns clock period before opt, and 2.8ns clock period after)
    // interface to data_pkt1_fifo 
    output pkt1_t                       data_pkt1_fifo_input,
    output logic [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_wr_en,
    input  logic [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_full,
    input  logic [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_almost_full,
    input  logic [`SENTRY_WIDTH-1:0]    data_pkt1_fifo_prog_full,
    `ifdef SMAC // Optional SMAC Interface
        // interface to smac request queue/fifo
        output mem_req_t                    smac_req_fifo_input,
        output logic                        smac_req_fifo_wr_en,
        input  logic                        smac_req_fifo_full,
        input  logic                        smac_req_fifo_almost_full,
        input  logic                        smac_req_fifo_prog_full,
    `endif
    // write interface to data victim cam lookup request queue/fifo
    // cam insert has to stall for cam lookup to be done, as cam can't lookup using an updated cam state
    // this is the same as saying that cam_req has higher priority than cam_insert
    output mem_req_t                    cam_req_fifo_input,
    output logic                        cam_req_fifo_wr_en,
    input  logic                        cam_req_fifo_full,
    input  logic                        cam_req_fifo_almost_full,
    input  logic                        cam_req_fifo_prog_full,
    // victim entry insert to end of victim buffer
    output mem_req_t                    cam_insert_fifo_input,
    output logic                        cam_insert_fifo_wr_en,
    input  logic                        cam_insert_fifo_full,
    input  logic                        cam_insert_fifo_almost_full,
    input  logic                        cam_insert_fifo_prog_full,
    // interface to victim addr queue/fifo
    output addr_t                       victim_addr_fifo_input,
    output logic                        victim_addr_fifo_wr_en,
    input  logic                        victim_addr_fifo_full,
    input  logic                        victim_addr_fifo_almost_full,
    input  logic                        victim_addr_fifo_prog_full,
    // Clock and Reset
    input                               clk,
    input                               rst
);

genvar i;

typedef enum {
    S_CACHE_IDLE, 
    S_CACHE_RESP
} dcache_state_e;

dcache_state_e DC_STATE;
dcache_state_e next_DC_STATE;

always @(posedge clk) begin
    if(rst) DC_STATE <= S_CACHE_IDLE;
    else DC_STATE <= next_DC_STATE;
end

reg  [3:0]                      random_num = 4'hf;
wire [`DWAYS-1:0]               wr_en_way;
wire [`DWAYS-1:0]               fill_way;
wire [2:0]                      hit_way;
wire [2:0]                      miss_way;

wire [`D_TAG_WIDTH-1:0]         tag     = dcache_req_address[`ADDR_WIDTH-1-:`D_TAG_WIDTH];
wire [`D_INDEX_WIDTH-1:0]       index   = dcache_req_address[`BYTE_OFFSET_WIDTH+:`D_INDEX_WIDTH];
wire [`BYTE_OFFSET_WIDTH-1:0]   offset  = dcache_req_address[`BYTE_OFFSET_WIDTH-1:0];

wire [`DWAYS-1:0]               data_hit;
wire [`DWAYS-1:0]               valid_way;
wire [`DWAYS-1:0]               dirty_way;
wire [`D_TAG_WIDTH-1:0]         tag_way     [`DWAYS-1:0];

// eviction logic
`ifdef TIMING_OPT
reg  [`DWAYS-1:0]               evict_way;
reg  [`D_INDEX_WIDTH-1:0]       evict_index;
`else
wire [`DWAYS-1:0]               evict_way;
wire [`D_INDEX_WIDTH-1:0]       evict_index;
`endif
wire [`D_TAG_WIDTH-1:0]         evict_tag;
wire                            evict_valid;
addr_t                          evict_addr;


addr_t                          offset_mask = (1 << `BYTE_OFFSET_WIDTH) - 1;
`ifdef SMAC
addr_t                          smac_offset_mask = (1 << `SMAC_OFFSET_WIDTH) - 1;
`endif
din_t                           mem_number;

// read write logic
reg                             dcache_req_rd_en_reg;
reg                             dcache_req_store_reg;
reg  [`SENTRY_WIDTH-1:0]        mem_rotate;
reg  [`SENTRY_WIDTH-1:0]        mem_rotate_reg;
addr_t                          mem_address;
addr_t                          mem_address_aligned;
addr_t                          smac_address_aligned;
reg  [`D_TAG_WIDTH-1:0]         compare_tag;
reg  [`D_TAG_WIDTH-1:0]         wr_tag;
wire [`D_INDEX_WIDTH-1:0]       rd_index;
reg  [`D_INDEX_WIDTH-1:0]       wr_index;
wire                            cache_hit = |data_hit; // Cycle 1

wire data_pkt1_prog_full  = | data_pkt1_fifo_prog_full;
reg  data_pkt1_wr_en;

// PERFOPT: primitive output registers before final output to downstream fifos
pkt1_t                          data_pkt1_fifo_input_pre;
wire [`SENTRY_WIDTH-1:0]        data_pkt1_fifo_wr_en_pre;
`ifdef SMAC // Optional SMAC Interface
    mem_req_t                       smac_req_fifo_input_pre;
    reg                             smac_req_fifo_wr_en_pre;
`endif
mem_req_t                       cam_req_fifo_input_pre;
reg                             cam_req_fifo_wr_en_pre;
mem_req_t                       cam_insert_fifo_input_pre;
reg                             cam_insert_fifo_wr_en_pre;
addr_t                          victim_addr_fifo_input_pre;
reg                             victim_addr_fifo_wr_en_pre;

`ifdef TIMING_OPT
    reg  [`D_TAG_WIDTH-1:0]                 tag_way_reg     [`DWAYS-1:0];
    dcache_state_e                          DC_STATE_reg;
    reg  [`DWAYS-1:0]                       data_hit_reg;
    din_t                                   mem_number_reg;
    addr_t                                  mem_address_reg;
    reg  [`DWAYS-1:0]                       fill_way_reg;
    addr_t                                  mem_address_aligned_reg;
    addr_t                                  smac_address_aligned_reg;
    reg                                     cache_hit_reg;
    reg  [`SENTRY_WIDTH-1:0]                mem_rotate_reg_reg;
`endif

// Cycle 2
always @(posedge clk) begin
    data_pkt1_fifo_input    <= data_pkt1_fifo_input_pre;
    data_pkt1_fifo_wr_en    <= data_pkt1_fifo_wr_en_pre;
`ifdef SMAC // Optional SMAC Interface
    smac_req_fifo_input     <= smac_req_fifo_input_pre;
    smac_req_fifo_wr_en     <= smac_req_fifo_wr_en_pre;
`endif
    cam_req_fifo_input      <= cam_req_fifo_input_pre;
    cam_req_fifo_wr_en      <= cam_req_fifo_wr_en_pre;
    cam_insert_fifo_input   <= cam_insert_fifo_input_pre;
    cam_insert_fifo_wr_en   <= cam_insert_fifo_wr_en_pre;
    victim_addr_fifo_input  <= victim_addr_fifo_input_pre;
    victim_addr_fifo_wr_en  <= victim_addr_fifo_wr_en_pre;
end

// evict victim buffer index only increments
vindex_t evict_vidx;
always @(posedge clk) begin
    if(rst) begin
        evict_vidx <= 0;
    end
    else if(cam_insert_fifo_wr_en) begin
        evict_vidx <= evict_vidx + 1;
    end
end

// Cycle 0
assign rd_index = index;

`ifdef TIMING_OPT
// Cycle 2
assign evict_valid = |evict_way;
always @(posedge clk) begin
    evict_index <= wr_index;
end
assign evict_addr = {evict_tag, evict_index, `BYTE_OFFSET_WIDTH'd0};
`else
// Cycle 1
assign evict_valid = |evict_way;
assign evict_index = wr_index;
assign evict_addr = {evict_tag, evict_index, `BYTE_OFFSET_WIDTH'd0};
`endif

// compare tags are delayed one cycle to match bram latency
// (Cycle 1)
always @(posedge clk) begin
    compare_tag             <= tag;
    wr_tag                  <= tag;
    wr_index                <= index;
    dcache_req_rd_en_reg    <= dcache_req_rd_en;
    dcache_req_store_reg    <= dcache_req_rd_en && dcache_req_store;
    mem_number              <= dcache_req_number;
    mem_rotate              <= dcache_req_rotate;
    mem_rotate_reg          <= mem_rotate;
    mem_address             <= dcache_req_address;
    mem_address_aligned     <= dcache_req_address & (~offset_mask);
`ifdef SMAC
    smac_address_aligned    <= (`SMAC_START + ((icache_req_address & (~offset_mask)) >> 5 )) & (~smacoffset_mask);
`endif
end

// Cycle 1
assign wr_en_way =  (DC_STATE == S_CACHE_IDLE) ? 0 :    // when idle nothing happens
                    cache_hit ? data_hit & {`DWAYS{dcache_req_store_reg}} :  // store hits are write enable too
                    fill_way;

// only accept dcache request when request queue not empty and downstream queues not full
assign dcache_req_rd_en =   dcache_req_valid && 
                            (!data_pkt1_prog_full) &&
                            (!cam_req_fifo_prog_full) &&
                            (!cam_insert_fifo_prog_full) &&
                            (!victim_addr_fifo_prog_full);

always @(posedge clk) begin
    if (dcache_req_rd_en && dcache_req_store) begin
        // update the random way select on fill
        random_num  <= {random_num[2], random_num[1],
                        random_num[0], random_num[3]^random_num[2]};
    end
end

// rotate depends on rotate each instruction is allocated to
`ifdef TIMING_OPT
assign data_pkt1_fifo_wr_en_pre = data_pkt1_wr_en ? mem_rotate_reg_reg : 0;
`else
assign data_pkt1_fifo_wr_en_pre = data_pkt1_wr_en ? mem_rotate_reg : 0;
`endif


//************************
// CACHE FSM
//************************
always @(*) begin
    next_DC_STATE = DC_STATE;
    case(DC_STATE) 
        S_CACHE_IDLE: begin
            // stall on data pkt1 fifo full or victim addr fifo full or cam buffer full
            if (dcache_req_valid && 
                (!data_pkt1_prog_full) &&
                (!cam_req_fifo_prog_full) &&
                (!cam_insert_fifo_prog_full) &&
                (!victim_addr_fifo_prog_full)
            ) begin
                // regardless of whether hit or miss, on response respond right away 
                next_DC_STATE = S_CACHE_RESP;
            end
        end
        S_CACHE_RESP: begin
            // cache should never be busy, if upstream invalid and downstream full
            // switch back to idle state and wait till either upstream fills or downstream drains
            if (!dcache_req_valid || 
                data_pkt1_prog_full ||
                cam_req_fifo_prog_full ||
                cam_insert_fifo_prog_full ||
                victim_addr_fifo_prog_full
            ) begin
                next_DC_STATE = S_CACHE_IDLE;
            end
        end
    endcase
end

`ifdef TIMING_OPT
    generate
    for (i=0; i< `DWAYS; i=i+1) begin
        always @(posedge clk) begin
            tag_way_reg[i] <= tag_way[i];
        end
    end
    endgenerate
    always @(posedge clk) begin
        DC_STATE_reg    <= DC_STATE;
        cache_hit_reg   <= cache_hit;
        mem_number_reg  <= mem_number;
        mem_address_reg <= mem_address;
        data_hit_reg    <= data_hit;
        fill_way_reg    <= fill_way;
        mem_address_aligned_reg <= mem_address_aligned;
        smac_address_aligned_reg <= smac_address_aligned;
        mem_rotate_reg_reg <= mem_rotate_reg;
    end
    // Cache FSM Output
    always @(posedge clk) begin
        case(DC_STATE_reg) 
            S_CACHE_IDLE: begin
                data_pkt1_fifo_input_pre    <= 0;
                data_pkt1_wr_en             <= 0;
                `ifdef SMAC
                    smac_req_fifo_input_pre     <= 0;
                    smac_req_fifo_wr_en_pre     <= 0;
                `endif
                cam_req_fifo_input_pre      <= 0;
                cam_req_fifo_wr_en_pre      <= 0;
                victim_addr_fifo_input_pre  <= 0;
                victim_addr_fifo_wr_en_pre  <= 0;
                cam_insert_fifo_input_pre   <= 0;
                cam_insert_fifo_wr_en_pre   <= 0;
            end
            S_CACHE_RESP: begin
                // if cache hit, send hit info to data_pkt1_fifo
                // All happens on cycle 1 of cache_hit, which is cache2
                if (cache_hit_reg) begin
                    // send instruction metadata
                    data_pkt1_fifo_input_pre.tag.number <= mem_number_reg;
                    data_pkt1_fifo_input_pre.tag.rotate <= mem_rotate_reg;
                    data_pkt1_fifo_input_pre.mhb        <= 0;
                    data_pkt1_fifo_input_pre.ens        <= data_hit_reg;
                    data_pkt1_fifo_input_pre.evict      <= 0;
                    data_pkt1_fifo_input_pre.vidx       <= 0;
                    data_pkt1_fifo_input_pre.addr       <= mem_address_reg;
                    data_pkt1_wr_en                     <= 1;
                    `ifdef SMAC
                        smac_req_fifo_input_pre             <= 0;
                        smac_req_fifo_wr_en_pre             <= 0;
                    `endif
                    cam_req_fifo_input_pre              <= 0;
                    cam_req_fifo_wr_en_pre              <= 0;
                    victim_addr_fifo_input_pre          <= 0;
                    victim_addr_fifo_wr_en_pre          <= 0;
                    cam_insert_fifo_input_pre           <= 0;
                    cam_insert_fifo_wr_en_pre           <= 0;
                end
                // if cache miss, send miss info to data_pkt1_fifo
                // also perform the fill on the next cycle
                else begin
                    // send instruction metadata
                    data_pkt1_fifo_input_pre.tag.number <= mem_number_reg;
                    data_pkt1_fifo_input_pre.tag.rotate <= mem_rotate_reg;
                    data_pkt1_fifo_input_pre.mhb        <= 1;
                    data_pkt1_fifo_input_pre.ens        <= fill_way_reg;
                    data_pkt1_fifo_input_pre.evict      <= evict_way;
                    data_pkt1_fifo_input_pre.vidx       <= evict_vidx;
                    // need to add victim buffer index for evicts
                    data_pkt1_fifo_input_pre.addr       <= mem_address_reg;
                    data_pkt1_wr_en                     <= 1;
                    `ifdef SMAC
                        // send miss smac request
                        smac_req_fifo_input_pre.tag.number  <= mem_number_reg;
                        smac_req_fifo_input_pre.tag.rotate  <= mem_rotate_reg;
                        smac_req_fifo_input_pre.addr        <= smac_address_aligned_reg;
                        smac_req_fifo_wr_en_pre             <= 1;
                    `endif
                    // send miss line request, log the tag of the instruction
                    // that missed and needs lookup
                    cam_req_fifo_input_pre.tag.number   <= mem_number_reg;
                    cam_req_fifo_input_pre.tag.rotate   <= mem_rotate_reg;
                    cam_req_fifo_input_pre.addr         <= mem_address_aligned_reg;
                    cam_req_fifo_wr_en_pre              <= 1;
                    // send evited address if eviction happened
                    victim_addr_fifo_input_pre          <= evict_addr;
                    victim_addr_fifo_wr_en_pre          <= evict_valid;
                    // do victim buffer insert if eviction happened
                    // log the tag of the instruction that caused the evict
                    cam_insert_fifo_wr_en_pre           <= evict_valid;
                    cam_insert_fifo_input_pre.tag.number<= mem_number_reg;
                    cam_insert_fifo_input_pre.tag.rotate<= evict_vidx;
                    cam_insert_fifo_input_pre.addr      <= evict_addr;
                end
            end
        endcase
    end
`else
    // Cache FSM Output
    always @(posedge clk) begin
        case(DC_STATE) 
            S_CACHE_IDLE: begin
                data_pkt1_fifo_input_pre    <= 0;
                data_pkt1_wr_en             <= 0;
                `ifdef SMAC
                    smac_req_fifo_input_pre     <= 0;
                    smac_req_fifo_wr_en_pre     <= 0;
                `endif
                cam_req_fifo_input_pre      <= 0;
                cam_req_fifo_wr_en_pre      <= 0;
                victim_addr_fifo_input_pre  <= 0;
                victim_addr_fifo_wr_en_pre  <= 0;
                cam_insert_fifo_input_pre   <= 0;
                cam_insert_fifo_wr_en_pre   <= 0;
            end
            S_CACHE_RESP: begin
                // if cache hit, send hit info to data_pkt1_fifo
                // All happens on cycle 1 of cache_hit, which is cache2
                if (cache_hit) begin
                    // send instruction metadata
                    data_pkt1_fifo_input_pre.tag.number <= mem_number;
                    data_pkt1_fifo_input_pre.tag.rotate <= mem_rotate;
                    data_pkt1_fifo_input_pre.mhb        <= 0;
                    data_pkt1_fifo_input_pre.ens        <= data_hit;
                    data_pkt1_fifo_input_pre.evict      <= 0;
                    data_pkt1_fifo_input_pre.vidx       <= 0;
                    data_pkt1_fifo_input_pre.addr       <= mem_address;
                    data_pkt1_wr_en                     <= 1;
                    `ifdef SMAC
                        smac_req_fifo_input_pre             <= 0;
                        smac_req_fifo_wr_en_pre             <= 0;
                    `endif
                    cam_req_fifo_input_pre              <= 0;
                    cam_req_fifo_wr_en_pre              <= 0;
                    victim_addr_fifo_input_pre          <= 0;
                    victim_addr_fifo_wr_en_pre          <= 0;
                    cam_insert_fifo_input_pre           <= 0;
                    cam_insert_fifo_wr_en_pre           <= 0;
                end
                // if cache miss, send miss info to data_pkt1_fifo
                // also perform the fill on the next cycle
                else begin
                    // send instruction metadata
                    data_pkt1_fifo_input_pre.tag.number <= mem_number;
                    data_pkt1_fifo_input_pre.tag.rotate <= mem_rotate;
                    data_pkt1_fifo_input_pre.mhb        <= 1;
                    data_pkt1_fifo_input_pre.ens        <= fill_way;
                    data_pkt1_fifo_input_pre.evict      <= evict_way;
                    data_pkt1_fifo_input_pre.vidx       <= evict_vidx;
                    // need to add victim buffer index for evicts
                    data_pkt1_fifo_input_pre.addr       <= mem_address;
                    data_pkt1_wr_en                     <= 1;
                    `ifdef SMAC
                        // send miss smac request
                        smac_req_fifo_input_pre.tag.number  <= mem_number;
                        smac_req_fifo_input_pre.tag.rotate  <= mem_rotate;
                        smac_req_fifo_input_pre.addr        <= smac_address_aligned;
                        smac_req_fifo_wr_en_pre             <= 1;
                    `endif
                    // send miss line request, log the tag of the instruction
                    // that missed and needs lookup
                    cam_req_fifo_input_pre.tag.number   <= mem_number;
                    cam_req_fifo_input_pre.tag.rotate   <= mem_rotate;
                    cam_req_fifo_input_pre.addr         <= mem_address_aligned;
                    cam_req_fifo_wr_en_pre              <= 1;
                    // send evited address if eviction happened
                    victim_addr_fifo_input_pre          <= evict_addr;
                    victim_addr_fifo_wr_en_pre          <= evict_valid;
                    // do victim buffer insert if eviction happened
                    // log the tag of the instruction that caused the evict
                    cam_insert_fifo_wr_en_pre           <= evict_valid;
                    cam_insert_fifo_input_pre.tag.number<= mem_number;
                    cam_insert_fifo_input_pre.tag.rotate<= evict_vidx;
                    cam_insert_fifo_input_pre.addr      <= evict_addr;
                end
            end
        endcase
    end
`endif

// cache read hit data
// Cycle 1
generate
if(`DWAYS == 2) begin
    `ifdef TIMING_OPT
        // Cycle 2
        assign evict_tag =  evict_way[0]    ? tag_way_reg[0] :
                            evict_way[1]    ? tag_way_reg[1] :
                                              {`D_TAG_WIDTH{1'b1}}; // all 1's for debug
    `else
        // Cycle 1
        assign evict_tag =  evict_way[0]    ? tag_way[0] :
                            evict_way[1]    ? tag_way[1] :
                                              {`D_TAG_WIDTH{1'b1}}; // all 1's for debug
    `endif

    assign miss_way  =  fill_way[0] ? 3'd0      :
                        fill_way[1] ? 3'd1      :
                                      {3{1'b1}} ; // all 1's for debug

    assign hit_way   =  data_hit[0] ? 3'd0      :
                        data_hit[1] ? 3'd1      :
                                      {3{1'b1}} ; // all 1's for debug

    // cache fill way pick (Cycle 1)
    assign fill_way = pick_way(valid_way, random_num);

    function [`DWAYS-1:0] pick_way;
        input [`DWAYS-1:0] valid_way;
        input [3:0] random_num;
        begin
            if      (valid_way[0] == 1'b0) begin
                pick_way = 2'b01;
            end
            else if (valid_way[1] == 1'b0) begin
                pick_way = 2'b10;
            end
            else begin
                case (random_num[3:1])
                    3'd0, 3'd3,
                    3'd5, 3'd6: pick_way = 2'b10;
                    default:    pick_way = 2'b01;
                endcase
            end
        end
    endfunction

end
else if(`DWAYS == 4) begin
    `ifdef TIMING_OPT
        // Cycle 2
        assign evict_tag =  evict_way[0]    ? tag_way_reg[0] :
                            evict_way[1]    ? tag_way_reg[1] :
                            evict_way[2]    ? tag_way_reg[2] :
                            evict_way[3]    ? tag_way_reg[3] :
                                              {`D_TAG_WIDTH{1'b1}}; // all 1's for debug
    `else
        // Cycle 1
        assign evict_tag =  evict_way[0]    ? tag_way[0] :
                            evict_way[1]    ? tag_way[1] :
                            evict_way[2]    ? tag_way[2] :
                            evict_way[3]    ? tag_way[3] :
                                              {`D_TAG_WIDTH{1'b1}}; // all 1's for debug
    `endif

    assign miss_way  =  fill_way[0] ? 3'd0      :
                        fill_way[1] ? 3'd1      :
                        fill_way[2] ? 3'd2      :
                        fill_way[3] ? 3'd3      :
                                      {3{1'b1}} ; // all 1's for debug

    assign hit_way   =  data_hit[0] ? 3'd0      :
                        data_hit[1] ? 3'd1      :
                        data_hit[2] ? 3'd2      :
                        data_hit[3] ? 3'd3      :
                                      {3{1'b1}} ; // all 1's for debug

    // cache fill way pick (Cycle 1)
    assign fill_way = pick_way(valid_way, random_num);

    function [`DWAYS-1:0] pick_way;
        input [`DWAYS-1:0] valid_way;
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

endgenerate


generate
for (i=0; i< `DWAYS; i=i+1) begin: ram
    ram_block #(
        .DATA_WIDTH         (`D_VDTAG_WIDTH),
        .ADDR_WIDTH         (`D_INDEX_WIDTH),
        .INITIALIZE_TO_ZERO (1)
    )
    TAGRAM (
        .clk        (clk                                        ),
        .wr_en      (wr_en_way[i]                               ),
        .wr_addr    (wr_index                                   ),
        .wr_data    ({1'b1, dcache_req_store_reg, wr_tag}       ),
        .rd_addr    (rd_index                                   ),
        .rd_data    ({valid_way[i], dirty_way[i], tag_way[i]}   )
    );

    // Cycle 1
    assign data_hit[i] = dcache_req_rd_en_reg && valid_way[i] && tag_way[i] == compare_tag;
    // Cycle 2?
    `ifdef TIMING_OPT
    always @(posedge clk) begin
        evict_way[i] <= wr_en_way[i] && dirty_way[i]; // when a dirty way gets written into, evict
    end
    `else
    assign evict_way[i] = wr_en_way[i] && dirty_way[i]; // when a dirty way gets written into, evict
    `endif
end
endgenerate


endmodule

