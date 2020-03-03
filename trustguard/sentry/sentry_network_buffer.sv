// Network Shared Memory (Currently) Controller
`timescale 1ns/1ps
`include "parameters.svh"
import TYPES::*;

module sentry_network_buffer #(
    parameter BUF_SIZE = 256
)
(
    // Network Gets
    // Read Interface from Sentry Network GET Request Queue
    input  logic                        net_get_req_fifo_empty,
    output logic                        net_get_req_fifo_rd_en,
    input  tag_t                        net_get_req_fifo_tag,
    // Get Response, Write Interface to Network Checking Unit
    output logic [`SENTRY_WIDTH-1:0]    net_get_done,
    output data_t                       net_get_data,
    // Network Puts 
    input  logic                        net_outgoing_req_fifo_empty,
    output logic                        net_outgoing_req_fifo_rd_en,
    input  data_t                       net_outgoing_req_fifo_output,
    // uBlaze interface should a typical bram interface 
    // uBlaze would write to net_in interface
    // input from uBlaze, bram style write & write_enable
    output logic                        net_get_clk,
    output logic                        net_get_rst,
    output logic [7:0]                  net_get_wr_en,
    output logic                        net_get_rd_en,
    output logic [31:0]                 net_get_addr,
    output data_t                       net_get_wr_data,
    input  data_t                       net_get_rd_data,
    // uBlaze would read from net_out interface
    // output to uBlaze, bram style write & write_enable
    output logic                        net_put_clk,
    output logic                        net_put_rst,
    output logic [7:0]                  net_put_wr_en,
    output logic                        net_put_rd_en,
    output logic [31:0]                 net_put_addr,
    output data_t                       net_put_wr_data,
    input  data_t                       net_put_rd_data,
    // clock and reset
    input                               clk,
    input                               rst
);

// this would potentially be replaced by two port bram
reg [`NET_ADDR_WIDTH-1:0]  rd_ptr_in;
reg [`NET_ADDR_WIDTH-1:0]  wr_ptr_out;
reg [`NET_ADDR_WIDTH-1:0]  net_get_addr_int;
reg [`NET_ADDR_WIDTH-1:0]  net_put_addr_int;

assign net_get_clk = clk;
assign net_get_rst = rst;
assign net_put_clk = clk;
assign net_put_rst = rst;

// read/write happen on 64 bit/8 byte boundary
assign net_get_addr = {{(32-3-`NET_ADDR_WIDTH){1'b0}}, net_get_addr_int, 3'd0}; 
assign net_put_addr = {{(32-3-`NET_ADDR_WIDTH){1'b0}}, net_put_addr_int, 3'd0};

typedef enum {
    S_GET_INIT, 
    S_GET_WAIT, 
    S_GET_READ, 
    S_GET_CLEAR,
    S_GET_DONE
} get_state_e;

typedef enum {
    S_PUT_INIT, 
    S_PUT_WAIT, 
    S_PUT_WRITE, 
    S_PUT_SET,
    S_PUT_DONE
} put_state_e;

get_state_e GET_STATE, next_GET_STATE;

put_state_e PUT_STATE, next_PUT_STATE;

wire [`NET_ADDR_WIDTH-1:0] BUF_CUTOFF = BUF_SIZE-2;

always @(posedge clk) begin
    if(rst) begin
        GET_STATE   <= S_GET_INIT;
        PUT_STATE   <= S_PUT_INIT;
        rd_ptr_in   <= 0;
        wr_ptr_out  <= 0;
    end
    else begin
        GET_STATE   <= next_GET_STATE;
        PUT_STATE   <= next_PUT_STATE;
        if(GET_STATE == S_GET_CLEAR) begin
            rd_ptr_in   <= rd_ptr_in == BUF_CUTOFF ? 0 : rd_ptr_in + 2;
        end
        if(PUT_STATE == S_PUT_SET) begin
            wr_ptr_out  <= wr_ptr_out == BUF_CUTOFF ? 0 : wr_ptr_out + 2;
        end
    end
end

// GET: this is logic for sentry reading incoming data from network 
always @(*) begin
    next_GET_STATE = GET_STATE;
    case (GET_STATE) 
        S_GET_INIT: begin
            if(net_get_req_fifo_empty == 1'b0) begin
                next_GET_STATE = S_GET_WAIT;
            end
        end
        S_GET_WAIT: begin
            if(net_get_rd_data == 64'd1) begin
                next_GET_STATE = S_GET_READ;
            end
        end
        S_GET_READ: begin
            next_GET_STATE  = S_GET_CLEAR;
        end
        S_GET_CLEAR: begin
            next_GET_STATE  = S_GET_DONE;
        end
        S_GET_DONE: begin
            next_GET_STATE  = S_GET_INIT;
        end
    endcase
end

always @(posedge clk) begin
    case (GET_STATE) 
        S_GET_INIT: begin
            net_get_wr_en           <= 8'd0;
            net_get_wr_data         <= `X_LEN'd0;
            net_get_done            <= `SENTRY_WIDTH'd0;
            net_get_data            <= `X_LEN'd0;
            net_get_req_fifo_rd_en  <= 0;
            if(net_get_req_fifo_empty == 1'b0) begin
                net_get_rd_en           <= 1;
                net_get_addr_int        <= rd_ptr_in + 1;
            end
            else begin
                net_get_rd_en           <= 1'b0;
                net_get_addr_int        <= `NET_ADDR_WIDTH'd0;
            end
        end
        S_GET_WAIT: begin
            net_get_wr_en           <= 8'd0;
            net_get_wr_data         <= `X_LEN'd0;
            net_get_done            <= `SENTRY_WIDTH'd0;
            net_get_data            <= `X_LEN'd0;
            net_get_req_fifo_rd_en  <= 0;
            net_get_rd_en           <= 1;
            if(net_get_rd_data == 64'd1) begin
                net_get_addr_int        <= rd_ptr_in;
            end
            else begin
                net_get_addr_int        <= rd_ptr_in + 1;
            end
        end
        S_GET_READ: begin
            net_get_wr_en           <= 8'd0;
            net_get_wr_data         <= `X_LEN'd0;
            net_get_done            <= `SENTRY_WIDTH'd0;
            net_get_data            <= `X_LEN'd0;
            net_get_req_fifo_rd_en  <= 0;
            net_get_rd_en           <= 1'b0;
            net_get_addr_int        <= `NET_ADDR_WIDTH'd0;
        end
        S_GET_CLEAR: begin
            net_get_wr_en           <= 8'hff;
            net_get_wr_data         <= 0;
            net_get_done            <= net_get_req_fifo_tag.rotate;
            net_get_data            <= net_get_rd_data;
            net_get_req_fifo_rd_en  <= 1;
            net_get_rd_en           <= 1'b1;
            net_get_addr_int        <= rd_ptr_in + 1;
        end
        S_GET_DONE: begin
            net_get_wr_en           <= 8'd0;
            net_get_wr_data         <= `X_LEN'd0;
            net_get_done            <= `SENTRY_WIDTH'd0;
            net_get_data            <= `X_LEN'd0;
            net_get_req_fifo_rd_en  <= 0;
            net_get_rd_en           <= 1'b0;
            net_get_addr_int        <= `NET_ADDR_WIDTH'd0;
        end
    endcase
end

// PUT: this is logic for sentry writing outgoing data to network
always @(*) begin
    next_PUT_STATE = PUT_STATE;
    case (PUT_STATE) 
        S_PUT_INIT: begin
            if(net_outgoing_req_fifo_empty == 1'b0) begin
                next_PUT_STATE = S_PUT_WAIT;
            end
        end
        S_PUT_WAIT: begin
            if(net_put_rd_data == 64'd0) begin
                next_PUT_STATE = S_PUT_WRITE;
            end
        end
        S_PUT_WRITE: begin
            next_PUT_STATE = S_PUT_SET;
        end
        S_PUT_SET: begin
            next_PUT_STATE = S_PUT_DONE;
        end
        S_PUT_DONE: begin
            next_PUT_STATE = S_PUT_INIT;
        end
    endcase
end

always @(posedge clk) begin
    case (PUT_STATE) 
        S_PUT_INIT: begin
            net_put_wr_en               <= 8'd0;
            net_put_wr_data             <= `X_LEN'd0;
            net_outgoing_req_fifo_rd_en <= 0;
            if(net_outgoing_req_fifo_empty == 1'b0) begin
                net_put_rd_en               <= 1;
                net_put_addr_int            <= wr_ptr_out + 1;
            end
            else begin
                net_put_rd_en               <= 0;
                net_put_addr_int            <= `NET_ADDR_WIDTH'd0;
            end
        end
        S_PUT_WAIT: begin
            net_put_wr_en               <= 8'd0;
            net_put_wr_data             <= `X_LEN'd0;
            net_outgoing_req_fifo_rd_en <= 0;
            if(net_put_rd_data == 64'd0) begin
                net_put_rd_en               <= 0;
                net_put_addr_int            <= `NET_ADDR_WIDTH'd0;
            end
            else begin
                net_put_rd_en               <= 1;
                net_put_addr_int            <= wr_ptr_out + 1;
            end
        end
        S_PUT_WRITE: begin
            net_put_wr_en               <= 8'hff;
            net_put_wr_data             <= net_outgoing_req_fifo_output;
            net_outgoing_req_fifo_rd_en <= 0;
            net_put_rd_en               <= 1;
            net_put_addr_int            <= wr_ptr_out;
        end
        S_PUT_SET: begin
            net_put_wr_en               <= 8'hff;
            net_put_wr_data             <= 1;
            net_outgoing_req_fifo_rd_en <= 1;
            net_put_rd_en               <= 1;
            net_put_addr_int            <= wr_ptr_out + 1;
        end
        S_PUT_DONE: begin
            net_put_wr_en               <= 8'd0;
            net_put_wr_data             <= `X_LEN'd0;
            net_outgoing_req_fifo_rd_en <= 0;
            net_put_rd_en               <= 0;
            net_put_addr_int            <= `NET_ADDR_WIDTH'd0;
        end
    endcase
end

//always @(posedge clk) begin
//  if(net_get_wr_en) begin
//    net_mem_bypass[net_get_addr] <= net_get_wr_data;
//  end
//  else if(net_bypass_wr_en) begin : data_bypass_host_wr
//    net_mem_bypass[net_bypass_addr] <= net_bypass_wr_data;
//  end
//  if(net_bypass_rd_en) begin : data_bypass_host_rd
//    net_bypass_rd_data <= net_mem_bypass[net_bypass_addr];
//  end
//end

// uBlaze interface, this will go straight to bram module
//always @(posedge net_get_clk) begin
//  if(net_get_wr_en) begin
//    net_mem_in[net_get_addr] <= net_get_wr_data;
//  end
//  if(net_get_rd_en) begin
//    net_get_rd_data <= net_mem_in[net_get_addr];
//  end
//end

//always @(posedge net_put_clk) begin
//  if(net_put_wr_en) begin
//    net_mem_out[net_put_addr] <= net_put_wr_data;
//  end
//  if(net_put_rd_en) begin
//    net_put_rd_data <= net_mem_out[net_put_addr];
//  end
//end

// handles 4 wide read of network input
//if(|net_rd_ens) begin : net_data_to_reg
//  net_rd_regs[0*`X_LEN+:`X_LEN] <= (!net_rd_ens[0]) ? 0 : net_mem_in[rd_ptr_in] ;

//  net_rd_regs[1*`X_LEN+:`X_LEN] <= (!net_rd_ens[1]) ? 0 : 
//                   (net_rd_ens[0]) ? net_mem_in[rd_ptr_in+1] : net_mem_in[rd_ptr_in];

//  net_rd_regs[2*`X_LEN+:`X_LEN] <= (!net_rd_ens[2]) ? 0 :
//                   (net_rd_ens[1:0] == 2'b11) ? net_mem_in[rd_ptr_in+2] : 
//                   (net_rd_ens[1:0] != 2'b00) ? net_mem_in[rd_ptr_in+1] : net_mem_in[rd_ptr_in] ;

//  net_rd_regs[3*`X_LEN+:`X_LEN] <= (!net_rd_ens[3]) ? 0 :
//                   (net_rd_ens[2:0] == 3'b111)  ? net_mem_in[rd_ptr_in+3] : 
//                   ((net_rd_ens[2:0] == 3'b011) || (net_rd_ens[2:0] == 3'b101) || (net_rd_ens[2:0] == 3'b110))  ? net_mem_in[rd_ptr_in+2] : 
//                   (net_rd_ens[2:0] != 3'b000)  ? net_mem_in[rd_ptr_in+1] : net_mem_in[rd_ptr_in] ;

//  rd_ptr_in <= rd_ptr_in + inc_in;
//end

// handles 4 wide read of network input
//if(|net_wr_ens) begin : do_read
//  net_mem_out[wr_ptr_out]   = (net_wr_ens[0]) ? net_wr_regs[0*`X_LEN+:`X_LEN] : 0;

//  net_mem_out[wr_ptr_out+1] = (net_wr_ens[0] && net_wr_ens[1]) ? net_wr_regs[1*`X_LEN+:`X_LEN] : 0;

//  net_mem_out[wr_ptr_out+2] = (net_wr_ens[0] && net_wr_ens[1] && net_wr_ens[2]) ? net_wr_regs[2*`X_LEN+:`X_LEN] : 0;

//  net_mem_out[wr_ptr_out+3] = (net_wr_ens[0] && net_wr_ens[1] && net_wr_ens[2] && net_wr_ens[3]) ? net_wr_regs[3*`X_LEN+:`X_LEN] : 0;

//  wr_ptr_out <= wr_ptr_out + inc_out;
//end

//always @(posedge clk) begin :  update_count_in
//  if(rst) begin
//    count_in <= 0;
//  end
//  else begin
//    if((|net_rd_ens) && (!net_get_en) && (!empty_in)) begin
//      count_in <= count_in - inc_in;
//    end else if ( (!(|net_rd_ens)) && net_get_en && (!full_in)) begin
//      count_in <= count_in + 1;
//    end
//  end
//end

//always @(posedge clk) begin :  update_count_out
//  if(rst) begin
//    count_out <= 0;
//  end
//  else begin
//    if((|net_wr_ens) && (!net_put_en) && (!empty_out)) begin
//      count_out <= count_out + inc_out;
//    end else if ( (!(|net_wr_ens)) && net_put_en && (!full_out)) begin
//      count_out <= count_out - 1;
//    end
//  end
//end

endmodule
