// ICache Emulation part of sentryControl unit
`timescale 1ns/1ps
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

// each cache set is composed of
// valid bit + dirty bit + tag bits + data bits

module sentryControl_icache (
    // interface to Merkle Tree Controller
    input  logic                        icache_req_valid,
    output logic                        icache_req_rd_en,
    input  addr_t                       icache_req_address,
    input  data_t                       icache_req_inst_result,
    // PERFOPT: add primitive register for all downstream fifo connections 
    // interface to inst_pkt1_fifo 
    output pkt1_t                       inst_pkt1_fifo_input,
    output logic [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_wr_en,
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_full,
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_almost_full,
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_prog_full,
    `ifdef SMAC // Optional SMAC Interface
        // interface to smac request queue/fifo
        output mem_req_t                    smac_req_fifo_input,
        output logic                        smac_req_fifo_wr_en,
        input  logic                        smac_req_fifo_full,
        input  logic                        smac_req_fifo_almost_full,
        input  logic                        smac_req_fifo_prog_full,
    `endif
    // interface to memory request queue/fifo
    output mem_req_t                    mem_req_fifo_input,
    output logic                        mem_req_fifo_wr_en,
    input  logic                        mem_req_fifo_full,
    input  logic                        mem_req_fifo_almost_full,
    input  logic                        mem_req_fifo_prog_full,
    // Clock and Reset
    input                               clk,
    input                               rst
);

genvar i;

typedef enum {
    S_CACHE_IDLE, 
    S_CACHE_RESP
} icache_state_e;

icache_state_e IC_STATE;
icache_state_e next_IC_STATE;

always @(posedge clk) begin
    if(rst) IC_STATE <= S_CACHE_IDLE;
    else IC_STATE <= next_IC_STATE;
end

reg  [3:0]                      random_num = 4'hf;
wire [`IWAYS-1:0]               wr_en_way;
wire [`IWAYS-1:0]               fill_way;
wire [2:0]                      hit_way;
wire [2:0]                      miss_way;

wire [`I_TAG_WIDTH-1:0]         tag     = icache_req_address[`ADDR_WIDTH-1-:`I_TAG_WIDTH];
wire [`I_INDEX_WIDTH-1:0]       index   = icache_req_address[`BYTE_OFFSET_WIDTH+:`I_INDEX_WIDTH];
wire [`BYTE_OFFSET_WIDTH-1:0]   offset  = icache_req_address[`BYTE_OFFSET_WIDTH-1:0];

wire [`IWAYS-1:0]               data_hit;
wire [`IWAYS-1:0]               valid_way;
wire [`IWAYS-1:0]               dirty_way;
wire [`I_TAG_WIDTH-1:0]         tag_way     [`IWAYS-1:0];

reg [$bits(tag_t)-`SENTRY_WIDTH-1:0] number = 0;

addr_t                      offset_mask = (1 << `BYTE_OFFSET_WIDTH) - 1;
`ifdef SMAC
    addr_t                      smac_offset_mask = (1 << `SMAC_OFFSET_WIDTH) - 1;
`endif
addr_t                      mem_address;
addr_t                      mem_address_aligned;
addr_t                      smac_address_aligned;
addr_t                      inst_result;

reg  [`I_TAG_WIDTH-1:0]     compare_tag;
reg  [`I_TAG_WIDTH-1:0]     wr_tag;
wire [`I_INDEX_WIDTH-1:0]   rd_index;
reg  [`I_INDEX_WIDTH-1:0]   wr_index;
wire                        cache_hit = |data_hit;

wire inst_pkt1_prog_full    = | inst_pkt1_fifo_prog_full;
reg  inst_pkt1_wr_en;

// round-robin feeding into pipelines
reg [`SENTRY_WIDTH-1:0] rotate;
reg [`SENTRY_WIDTH-1:0] rotate_reg;

// PERFOPT: primitive output registers before final output to downstream fifos
pkt1_t                      inst_pkt1_fifo_input_pre;
reg  [`SENTRY_WIDTH-1:0]    inst_pkt1_fifo_wr_en_pre;
`ifdef SMAC // Optional SMAC Interface
    mem_req_t                   smac_req_fifo_input_pre;
    reg                         smac_req_fifo_wr_en_pre;
`endif
mem_req_t                   mem_req_fifo_input_pre;
reg                         mem_req_fifo_wr_en_pre;

always @(posedge clk) begin
    inst_pkt1_fifo_input    <= inst_pkt1_fifo_input_pre;
    inst_pkt1_fifo_wr_en    <= inst_pkt1_fifo_wr_en_pre;
    `ifdef SMAC // Optional SMAC Interface
        smac_req_fifo_input     <= smac_req_fifo_input_pre;
        smac_req_fifo_wr_en     <= smac_req_fifo_wr_en_pre;
    `endif
    mem_req_fifo_input      <= mem_req_fifo_input_pre;
    mem_req_fifo_wr_en      <= mem_req_fifo_wr_en_pre;
end
assign rd_index = index;

//compare tags are delayed one cycle to match bram latency
always @(posedge clk) begin
    compare_tag             <= tag;
    wr_tag                  <= tag;
    wr_index                <= index;
    mem_address             <= icache_req_address;
    mem_address_aligned     <= icache_req_address & (~offset_mask);
    `ifdef SMAC
        smac_address_aligned    <= (`SMAC_START + ((icache_req_address & (~offset_mask)) >> 5 )) & (~smacoffset_mask);
    `endif
    inst_result             <= icache_req_inst_result; 
end

assign wr_en_way = ((IC_STATE == S_CACHE_IDLE) || cache_hit) ? 0 : fill_way;

// when cache is stalled, number stops updating too, 
// otherwise this will cause pending output buffer shut down
assign icache_req_rd_en =   icache_req_valid && 
(!inst_pkt1_prog_full) &&
(!mem_req_fifo_prog_full);

always @(posedge clk) begin
    if (icache_req_rd_en) begin  
        // update the random way select on fill
        number    <= number + 1;
        random_num  <= {random_num[2], random_num[1],
        random_num[0], random_num[3]^random_num[2]};
    end
end

always @(posedge clk) begin
    if (rst) rotate <= 1;
    else if (IC_STATE == S_CACHE_RESP) begin
        rotate <= (rotate << 1) | (rotate >> 3);
    end
    else begin
        rotate <= rotate;
    end
end

always @(posedge clk) begin
    rotate_reg <= rotate;
end

assign inst_pkt1_fifo_wr_en_pre = inst_pkt1_wr_en ? rotate_reg : 0;

//************************
// CACHE FSM
//************************
always @(*) begin
    next_IC_STATE = IC_STATE;
    case(IC_STATE) 
        S_CACHE_IDLE: begin
            if (icache_req_valid && 
                (!inst_pkt1_prog_full) &&
                (!mem_req_fifo_prog_full)
            ) begin
                // regardless of whether hit or miss, 
                // on response respond right away 
                next_IC_STATE = S_CACHE_RESP;
            end
        end
        S_CACHE_RESP: begin
            // cache should never be busy
            if (!icache_req_valid || 
                inst_pkt1_prog_full ||
                mem_req_fifo_prog_full
            ) begin
                next_IC_STATE = S_CACHE_IDLE;
            end
        end
    endcase
end

// Cycle 1
always @(posedge clk) begin
    // this needs to stall for downstream back pressure
    case(IC_STATE) 
        S_CACHE_IDLE: begin
            inst_pkt1_fifo_input_pre    <= 0;
            inst_pkt1_wr_en             <= 0;
            mem_req_fifo_input_pre      <= 0;
            mem_req_fifo_wr_en_pre      <= 0;
            `ifdef SMAC
                smac_req_fifo_input_pre     <= 0;
                smac_req_fifo_wr_en_pre     <= 0;
            `endif
        end
        S_CACHE_RESP: begin
            // if cache hit, send hit info to inst_pkt1_fifo
            if (cache_hit) begin
                // send instruction metadata
                inst_pkt1_fifo_input_pre.tag.number <= number;
                inst_pkt1_fifo_input_pre.tag.rotate <= rotate;
                inst_pkt1_fifo_input_pre.mhb        <= 0;
                inst_pkt1_fifo_input_pre.ens        <= data_hit;
                inst_pkt1_fifo_input_pre.evict      <= 0;
                inst_pkt1_fifo_input_pre.vidx       <= 0;
                inst_pkt1_fifo_input_pre.addr       <= mem_address;
                inst_pkt1_fifo_input_pre.result     <= inst_result;
                inst_pkt1_wr_en                     <= 1;
                mem_req_fifo_input_pre              <= 0;
                mem_req_fifo_wr_en_pre              <= 0;
                `ifdef SMAC
                    smac_req_fifo_input_pre             <= 0;
                    smac_req_fifo_wr_en_pre             <= 0;
                `endif
            end
            // if cache miss, send miss info to inst_pkt1_fifo
            // also perform the fill on the next cycle
            else begin
                // send instruction metadata
                inst_pkt1_fifo_input_pre.tag.number <= number;
                inst_pkt1_fifo_input_pre.tag.rotate <= rotate;
                inst_pkt1_fifo_input_pre.mhb        <= 1;
                inst_pkt1_fifo_input_pre.ens        <= fill_way;
                inst_pkt1_fifo_input_pre.evict      <= 0;
                inst_pkt1_fifo_input_pre.vidx       <= 0;
                inst_pkt1_fifo_input_pre.addr       <= mem_address;
                inst_pkt1_fifo_input_pre.result     <= inst_result;
                inst_pkt1_wr_en                     <= 1;
                // send miss line request
                mem_req_fifo_input_pre.tag.number   <= number;
                mem_req_fifo_input_pre.tag.rotate   <= rotate;
                mem_req_fifo_input_pre.addr         <= mem_address_aligned;
                mem_req_fifo_wr_en_pre              <= 1;
                `ifdef SMAC
                    // send miss smac request
                    smac_req_fifo_input_pre.tag.number  <= number;
                    smac_req_fifo_input_pre.tag.rotate  <= rotate;
                    smac_req_fifo_input_pre.addr        <= smac_address_aligned;
                    smac_req_fifo_wr_en_pre             <= 1;
                `endif
            end
        end
    endcase
end

// cache read hit data
generate
if(`IWAYS == 2) begin : hit_miss_2ways

    assign miss_way  =  fill_way[0] ? 3'd0        :
    fill_way[1] ? 3'd1        :
    {3{1'b1}}   ; // all 1's for debug

    assign hit_way   =  data_hit[0] ? 3'd0        :
    data_hit[1] ? 3'd1        :
    {3{1'b1}}   ; // all 1's for debug

    // cache fill way pick 
    assign fill_way = pick_way(valid_way, random_num);

    function [`IWAYS-1:0] pick_way;
        input [`IWAYS-1:0] valid_way;
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
else if(`IWAYS == 4) begin : hit_miss_4ways

    assign miss_way  =  fill_way[0] ? 3'd0        :
    fill_way[1] ? 3'd1        :
    fill_way[2] ? 3'd2        :
    fill_way[3] ? 3'd3        :
    {3{1'b1}}   ; // all 1's for debug

    assign hit_way   =  data_hit[0] ? 3'd0        :
    data_hit[1] ? 3'd1        :
    data_hit[2] ? 3'd2        :
    data_hit[3] ? 3'd3        :
    {3{1'b1}}   ; // all 1's for debug

    // cache fill way pick 
    assign fill_way = pick_way(valid_way, random_num);

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

endgenerate

generate
for (i=0; i< `IWAYS; i=i+1) begin: ram
    ram_block #(
        .DATA_WIDTH         (`I_VDTAG_WIDTH),
        .ADDR_WIDTH         (`I_INDEX_WIDTH),
        .INITIALIZE_TO_ZERO (1)
    )
    TAGRAM (
        .clk        (clk                                        ),
        .wr_en      (wr_en_way[i]                              ),
        .wr_addr    (wr_index                                   ),
        .wr_data    ({1'b1, 1'b0, wr_tag}                       ),
        .rd_addr    (rd_index                                   ),
        .rd_data    ({valid_way[i], dirty_way[i], tag_way[i]}   )
    );

    assign data_hit[i] = valid_way[i] && tag_way[i] == compare_tag;
end
endgenerate

endmodule

