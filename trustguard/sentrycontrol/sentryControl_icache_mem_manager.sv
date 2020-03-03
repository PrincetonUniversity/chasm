// ICache Emulation part of sentryControl unit
`timescale 1ns/1ps
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

// each cache set is composed of
// valid bit + dirty bit + tag bits + data bits

module sentryControl_icache_mem_manager #(
    parameter MEM_BASE_ADDR = 32'h00000000
)
(
    // AXI4 Master Interface
    input  logic            m_axi_aclk,         // global clock
    input  logic            m_axi_aresetn,      // global reset, active low
    // write interface
    // write address
    output logic            m_axi_awid,         // write address id, 1'b0
    output logic [ 31:0]    m_axi_awaddr,       // write address
    output logic [  7:0]    m_axi_awlen,        // number of write transfers in a burst
    output logic [  2:0]    m_axi_awsize,       // size of each write transfer in a burst
    output logic [  1:0]    m_axi_awburst,      // write burst type, 2'b01
    output logic            m_axi_awlock,       // 1'b0, not used
    output logic [  3:0]    m_axi_awcache,      // memory type, 4'b0010
    output logic [  2:0]    m_axi_awprot,       // protection type, 3'h0
    output logic [  3:0]    m_axi_awqos,        // quality of service identifier, 4'h0
    //output logic            m_axi_awuser,       // option user defined channel, 1'b1
    output logic            m_axi_awvalid,      // write address valid
    input  logic            m_axi_awready,      // write address ready
    // write data
    output logic [511:0]    m_axi_wdata,        // write data
    output logic [ 63:0]    m_axi_wstrb,        // write strobes (byte write enable)
    output logic            m_axi_wlast,        // indicates last transfer in a burst
    //output logic            m_axi_wuser,        // option user defined channel, 1'b0
    output logic            m_axi_wvalid,       // write data valid
    input  logic            m_axi_wready,       // write data ready
    // write response
    input  logic            m_axi_bid,          // master inteface write response
    input  logic [  1:0]    m_axi_bresp,        // write response for write transaction
    //input  logic            m_axi_buser,        // option user defined channel
    input  logic            m_axi_bvalid,       // write response valid
    output logic            m_axi_bready,       // write response ready, master can accept another transaction
    // read interface
    // read address
    output logic            m_axi_arid,         // read address id, 1'b0
    output logic [ 31:0]    m_axi_araddr,       // read address
    output logic [  7:0]    m_axi_arlen,        // number of read transfers in a burst
    output logic [  2:0]    m_axi_arsize,       // size of each read transfer in a burst
    output logic [  1:0]    m_axi_arburst,      // read burst type, 2'b01
    output logic            m_axi_arlock,       // 1'b0, not used
    output logic [  3:0]    m_axi_arcache,      // memory type, 4'b0010
    output logic [  2:0]    m_axi_arprot,       // protection type, 3'h0
    output logic [  3:0]    m_axi_arqos,        // quality of service identifier, 4'h0
    //output logic            m_axi_aruser,       // option user defined channel, 1'b1
    output logic            m_axi_arvalid,      // read address valid
    input  logic            m_axi_arready,      // read address ready
    // read data
    input  logic            m_axi_rid,          // master inteface write response
    input  logic [511:0]    m_axi_rdata,        // read data
    input  logic [  1:0]    m_axi_rresp,        // read response for read transaction
    input  logic            m_axi_rlast,        // indicates last transfer in a burst
    //input  logic            m_axi_ruser,        // option user defined channel
    input  logic            m_axi_rvalid,       // read data valid
    output logic            m_axi_rready,       // read data ready, master can accept read data

    // interface to ICache Controller
    `ifdef PARALLEL_ICACHE
        input  logic            mem_req_fifo_valid,
    `endif
    input  mem_req_t        mem_req_fifo_output,
    input  logic            mem_req_fifo_empty,
    input  logic            mem_req_fifo_almost_empty,
    output logic            mem_req_fifo_rd_en,

    // interface to inst_pkt2_fifo
    output pkt2_t                       inst_pkt2_fifo_input,
    output logic [`SENTRY_WIDTH-1:0]    inst_pkt2_fifo_wr_en,
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt2_fifo_full,
    input  logic [`SENTRY_WIDTH-1:0]    inst_pkt2_fifo_almost_full

);

// Clock and Rest
wire            clk = m_axi_aclk;
wire            rst = !m_axi_aresetn;

// write address
reg  [31:0]     axi_awaddr          = 'd0;
reg             axi_awvalid         = 'd0;
// write data
reg  [511:0]    axi_wdata           = 'd0;
reg             axi_wlast           = 'd0;
reg             axi_wvalid          = 'd0;
reg             axi_bready          = 'd0;
// read address
wire [31:0]     axi_araddr;
reg             axi_arvalid;
// read data
wire [511:0]    axi_rdata;
wire            axi_rvalid;
wire            axi_rready;

// write address
assign m_axi_awid       = 0;
assign m_axi_awaddr     = MEM_BASE_ADDR + axi_awaddr;
assign m_axi_awlen      = 0; // write 1 cache line (64B) each
assign m_axi_awsize     = 6;
assign m_axi_awburst    = 2'b01;
assign m_axi_awlock     = 1'b0;
assign m_axi_awcache    = 4'b0010;
assign m_axi_awprot	    = 3'h0;
assign m_axi_awqos	    = 4'h0;
assign m_axi_awuser	    = 'b1;
assign m_axi_awvalid    = axi_awvalid;
// write data
assign m_axi_wdata      = axi_wdata;
assign m_axi_wstrb	    = {64{1'b1}};
assign m_axi_wlast	    = axi_wlast;
assign m_axi_wuser	    = 'b0;
assign m_axi_wvalid	    = axi_wvalid;
// write response
assign m_axi_bready	    = axi_bready;

// read address
assign m_axi_arid	    = 'b0;
assign m_axi_araddr	    = MEM_BASE_ADDR + axi_araddr;
assign m_axi_arlen	    = 1 - 1;
assign m_axi_arsize	    = 6;
assign m_axi_arburst	= 2'b01; //00 for fixed address, 01 for incrementing address
assign m_axi_arlock	    = 1'b0;
assign m_axi_arcache	= 4'b0010;
assign m_axi_arprot	    = 3'h0;
assign m_axi_arqos	    = 4'h0;
assign m_axi_aruser	    = 'b1;
assign m_axi_arvalid	= axi_arvalid;
assign axi_arready      = m_axi_arready; //input address ready ready
// read response
assign m_axi_rready	    = axi_rready;
assign axi_rdata        = m_axi_rdata;
assign axi_rvalid       = m_axi_rvalid;


typedef enum {
    S_REQ_IDLE, 
    S_REQ_FLUSH, 
    S_REQ_ADDR_READY_WAIT, 
    S_REQ_WORK,
    S_REQ_DONE
} request_state_e;

typedef enum {
    S_RESP_IDLE, 
    S_RESP_WORK
} response_state_e;

request_state_e REQ_STATE;
request_state_e next_REQ_STATE;

always @(posedge clk) begin
    if(rst) begin 
        REQ_STATE <= S_REQ_IDLE;
    end
    else begin
        REQ_STATE <= next_REQ_STATE;
    end
end

`ifdef TAG_ADDR_DEBUG
    mem_req_t   tag_fifo_input;
`else
    tag_t       tag_fifo_input;
`endif
reg         tag_fifo_wr_en;
wire        tag_fifo_rd_en;
`ifdef TAG_ADDR_DEBUG
    mem_req_t   tag_fifo_output;
`else
    tag_t       tag_fifo_output;
`endif
wire        tag_fifo_full;
wire        tag_fifo_empty;
wire        tag_fifo_almost_full;
wire        tag_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]  tag_fifo_data_count;
`endif

//************************
// REQ FSM
//************************
//assign axi_arvalid = !mem_req_fifo_empty;
assign axi_araddr = mem_req_fifo_output.addr[31:0];
//assign mem_req_fifo_rd_en = !mem_req_fifo_empty && axi_arready;

// state transition
always @(*) begin
    next_REQ_STATE = REQ_STATE;
    case(REQ_STATE) 
        S_REQ_IDLE: begin
            // only request when upstream not empty and downstream not full
            // proceed onto the next cycle when incoming fifo is not empty and it is not during a read
            // because even if mem_req_fifo_empty is deasserted, it might be empty after the current assertion of mem_req_fifo_rd_en
            if (!mem_req_fifo_empty) begin
                `ifdef PARALLEL_ICACHE
                    if (mem_req_fifo_valid) begin
                        case(mem_req_fifo_output.tag.rotate)
                            4'b0001: begin
                                if(!inst_pkt2_fifo_almost_full[0] && !mem_req_fifo_empty) begin
                                    next_REQ_STATE = S_REQ_ADDR_READY_WAIT;
                                end
                            end
                            4'b0010: begin
                                if(!inst_pkt2_fifo_almost_full[1] && !mem_req_fifo_empty) begin
                                    next_REQ_STATE = S_REQ_ADDR_READY_WAIT;
                                end
                            end
                            4'b0100: begin
                                if(!inst_pkt2_fifo_almost_full[2] && !mem_req_fifo_empty) begin
                                    next_REQ_STATE = S_REQ_ADDR_READY_WAIT;
                                end
                            end
                            4'b1000: begin
                                if(!inst_pkt2_fifo_almost_full[3] && !mem_req_fifo_empty) begin
                                    next_REQ_STATE = S_REQ_ADDR_READY_WAIT;
                                end
                            end
                        endcase
                    end
                    else begin
                        next_REQ_STATE = S_REQ_FLUSH;
                    end
                `else
                    case(mem_req_fifo_output.tag.rotate)
                        4'b0001: begin
                            if(!inst_pkt2_fifo_almost_full[0] && !mem_req_fifo_empty) begin
                                next_REQ_STATE = S_REQ_ADDR_READY_WAIT;
                            end
                        end
                        4'b0010: begin
                            if(!inst_pkt2_fifo_almost_full[1] && !mem_req_fifo_empty) begin
                                next_REQ_STATE = S_REQ_ADDR_READY_WAIT;
                            end
                        end
                        4'b0100: begin
                            if(!inst_pkt2_fifo_almost_full[2] && !mem_req_fifo_empty) begin
                                next_REQ_STATE = S_REQ_ADDR_READY_WAIT;
                            end
                        end
                        4'b1000: begin
                            if(!inst_pkt2_fifo_almost_full[3] && !mem_req_fifo_empty) begin
                                next_REQ_STATE = S_REQ_ADDR_READY_WAIT;
                            end
                        end
                    endcase
                `endif
            end
            // else if memory request fifo empty do nothing
        end
        `ifdef PARALLEL_ICACHE
            S_REQ_FLUSH: begin
                next_REQ_STATE = S_REQ_IDLE;
            end
        `endif
        S_REQ_ADDR_READY_WAIT: begin
            if(axi_arready) begin
                next_REQ_STATE = S_REQ_WORK;
            end
        end
        S_REQ_WORK: begin
            next_REQ_STATE = S_REQ_DONE;
        end
        S_REQ_DONE: begin
            next_REQ_STATE = S_REQ_IDLE;
        end
    endcase
end
// state machine output
always @(posedge clk) begin
    case(REQ_STATE) 
        `ifdef PARALLEL_ICACHE
            S_REQ_IDLE: begin
                axi_arvalid         <= 0;
                if (!mem_req_fifo_empty && !mem_req_fifo_valid) begin
                    mem_req_fifo_rd_en  <= 1;
                end
                else begin
                    mem_req_fifo_rd_en  <= 0;
                end
                tag_fifo_wr_en      <= 0;
            end
        `endif
        S_REQ_ADDR_READY_WAIT: begin
            axi_arvalid         <= 1;
            mem_req_fifo_rd_en  <= 0;
            tag_fifo_wr_en      <= 0;
        end
        S_REQ_WORK: begin
            axi_arvalid         <= 0;
            mem_req_fifo_rd_en  <= 1;
            tag_fifo_wr_en      <= 1;
        end
        default: begin
            axi_arvalid         <= 0;
            mem_req_fifo_rd_en  <= 0;
            tag_fifo_wr_en      <= 0;
        end
    endcase
end

//assign tag_fifo_wr_en = axi_arready;
`ifdef TAG_ADDR_DEBUG
    assign tag_fifo_input = mem_req_fifo_output;
`else
    assign tag_fifo_input = mem_req_fifo_output.tag;
`endif
assign tag_fifo_rd_en = axi_rvalid;

`ifdef TAG_ADDR_DEBUG
    // debug addr tag fifo
    tag_addr_fifo TAG_FIFO (
        .clk            (clk                        ),  // input wire wr_clk
        .din            (tag_fifo_input             ),  // input wire [31 : 0] din
        .wr_en          (tag_fifo_wr_en             ),  // input wire wr_en
        .rd_en          (tag_fifo_rd_en             ),  // input wire rd_en
        .dout           (tag_fifo_output            ),  // output wire [31 : 0] dout
        .full           (tag_fifo_full              ),  // output wire full
        .empty          (tag_fifo_empty             ),  // output wire empty
        .almost_full    (tag_fifo_almost_full       ),  // output wire full
        .almost_empty   (tag_fifo_almost_empty      ),  // output wire empty
        `ifdef DATA_COUNT
            .data_count     (tag_fifo_data_count        ),  // output wire [9 : 0] data_count
        `endif
        .srst           (rst                        )   // input wire rst
    );
`else
    // tag fifo
    tag_fifo TAG_FIFO (
        .clk            (clk                        ),  // input wire wr_clk
        .din            (tag_fifo_input             ),  // input wire [31 : 0] din
        .wr_en          (tag_fifo_wr_en             ),  // input wire wr_en
        .rd_en          (tag_fifo_rd_en             ),  // input wire rd_en
        .dout           (tag_fifo_output            ),  // output wire [31 : 0] dout
        .full           (tag_fifo_full              ),  // output wire full
        .empty          (tag_fifo_empty             ),  // output wire empty
        .almost_full    (tag_fifo_almost_full       ),  // output wire full
        .almost_empty   (tag_fifo_almost_empty      ),  // output wire empty
        `ifdef DATA_COUNT
            .data_count     (tag_fifo_data_count        ),  // output wire [9 : 0] data_count
        `endif
        .srst           (rst                        )   // input wire rst
    );
`endif

//************************
// RESP FSM
//************************

// we are always ready to accept memory response 
// as long as the inst data packet queue is not full
assign axi_rready = ! (|inst_pkt2_fifo_full);

`ifdef TAG_ADDR_DEBUG
    assign inst_pkt2_fifo_input.tag     = tag_fifo_output.tag;
    assign inst_pkt2_fifo_input.addr    = tag_fifo_output.addr;
    assign inst_pkt2_fifo_wr_en = axi_rvalid ? tag_fifo_output.tag.rotate : 0;
`else
    assign inst_pkt2_fifo_input.tag = tag_fifo_output;
    assign inst_pkt2_fifo_wr_en = axi_rvalid ? tag_fifo_output.rotate : 0;
`endif
assign inst_pkt2_fifo_input.line = axi_rdata;

`ifdef SIMULATION
// debugging registers
reg [31:0] inCnt;
reg [31:0] outCnt;
always@(posedge clk) begin
    if(rst) begin
        inCnt <= 0;
        outCnt <= 0;
    end
    else begin
        if(mem_req_fifo_rd_en) begin
            inCnt <= inCnt + 1;
        end
        if(axi_rvalid) begin
            outCnt <= outCnt + 1;
        end
    end
end
`endif

endmodule

