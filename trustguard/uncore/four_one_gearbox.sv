// Queued Request Four-to-One Gear Box
`timescale 1ns/1ps
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

//INT_WIDTH == DATA_WIDTH + 1;

module four_one_gearbox 
#(
    parameter INT_WIDTH = 1
)
(
    input  logic                            clk,
    input  logic                            rst,
    input  logic                            input_empty,
    // input format
    // -----------------------------------------------------------------------------
    // |  INT_WIDTH bits  |  INT_WIDTH bits  |  INT_WIDTH bits  |  INT_WIDTH bits  |
    // -----------------------------------------------------------------------------
    // |valid bit 0|data 0|valid bit 1|data 1|valid bit 2|data 2|valid bit 3|data 3|
    // -----------------------------------------------------------------------------
    input  logic [4*INT_WIDTH-1:0]          input_four,
    output logic                            input_rd_en,
    input  logic                            output_full,
    // output format
    // ----------------------------------------------------
    // |    28 bit   |  4 bit |   1 bit   |INT_WIDTH-1 bit|
    // ----------------------------------------------------
    // |dynamic cnt 0|rotate 0|valid bit 0| output data 0 |
    // ----------------------------------------------------
    output logic [1*INT_WIDTH+28+4-1-1:0]   output_one, 
    output logic                            output_wr_en
);

typedef enum {
    S_GEARBOX_IDLE, 
    S_GEARBOX_ONE,
    S_GEARBOX_TWO,
    S_GEARBOX_THREE,
    S_GEARBOX_FOUR
} gearbox_state_e;

gearbox_state_e GB_STATE;
gearbox_state_e next_GB_STATE;

always @(posedge clk) begin
    if(rst) GB_STATE <= S_GEARBOX_IDLE;
    else GB_STATE <= next_GB_STATE;
end

reg [27:0] number;
always @(posedge clk) begin
    if(rst) number <= 1;
    else if(GB_STATE != S_GEARBOX_IDLE) begin
        number <= number + 1;
    end
end

`define OPT
`ifdef OPT
always @(*) begin
    next_GB_STATE = GB_STATE;
    // current sequence of 4 writes all together requires room of at least 4 left over
    // use the programmable full threshold on the downstream fifos of this gearbox (.prog_full)
    // which currently are dcache_req_fifo2, net_get_req_fifo2, net_put_req_fifo2 and victim_data_fifo2
    case(GB_STATE) 
        S_GEARBOX_IDLE: begin
            //if(!input_empty && !output_full) begin // should this be !input_empty && !input_rd_en ?
            if(!input_empty && !input_rd_en && !output_full) begin // should this be !input_empty && !input_rd_en ?
                next_GB_STATE = S_GEARBOX_ONE;
            end
        end
        S_GEARBOX_ONE: begin
            next_GB_STATE = S_GEARBOX_TWO;
        end
        S_GEARBOX_TWO: begin
            next_GB_STATE = S_GEARBOX_THREE;
        end
        S_GEARBOX_THREE: begin
            next_GB_STATE = S_GEARBOX_FOUR;
        end
        S_GEARBOX_FOUR: begin
            next_GB_STATE = S_GEARBOX_IDLE;
        end
    endcase
end

always @(posedge clk) begin
    case(GB_STATE) 
        S_GEARBOX_IDLE: begin
            output_one      <= {(INT_WIDTH+28+4-1-1){1'b0}};
            output_wr_en    <= 0;
            input_rd_en     <= 0;
        end
        S_GEARBOX_ONE: begin
            if(input_four[4*INT_WIDTH-1]) begin
                output_one      <= {number, 4'b0001, input_four[3*INT_WIDTH +: (INT_WIDTH-1)]};
                output_wr_en    <= 1;
                input_rd_en     <= 0;
            end
            else begin
                output_one      <= {(INT_WIDTH+28+4-1-1){1'b0}};
                output_wr_en    <= 0;
                input_rd_en     <= 0;
            end
        end
        S_GEARBOX_TWO: begin
            if(input_four[3*INT_WIDTH-1]) begin
                output_one      <= {number, 4'b0010, input_four[2*INT_WIDTH +: (INT_WIDTH-1)]};
                output_wr_en    <= 1;
                input_rd_en     <= 0;
            end
            else begin
                output_one      <= {(INT_WIDTH+28+4-1-1){1'b0}};
                output_wr_en    <= 0;
                input_rd_en     <= 0;
            end
        end
        S_GEARBOX_THREE: begin
            if(input_four[2*INT_WIDTH-1]) begin
                output_one      <= {number, 4'b0100, input_four[1*INT_WIDTH +: (INT_WIDTH-1)]};
                output_wr_en    <= 1;
                input_rd_en     <= 0;
            end
            else begin
                output_one      <= {(INT_WIDTH+28+4-1-1){1'b0}};
                output_wr_en    <= 0;
                input_rd_en     <= 0;
            end
        end
        S_GEARBOX_FOUR: begin
            input_rd_en <= 1;
            if(input_four[1*INT_WIDTH-1]) begin
                output_one      <= {number, 4'b1000, input_four[0*INT_WIDTH +: (INT_WIDTH-1)]};
                output_wr_en    <= 1;
            end
            else begin
                output_one      <= {(INT_WIDTH+28+4-1-1){1'b0}};
                output_wr_en    <= 0;
            end
        end
        default: begin
            output_one      <= {(INT_WIDTH+28+4-1-1){1'b0}};
            output_wr_en    <= 0;
            input_rd_en     <= 0;
        end
    endcase
end

`else
always @(*) begin
    next_GB_STATE = GB_DSTATE;
    output_wr_en = 0;
    output_one = 0;
    input_rd_en = 0;
    // current sequence of 4 writes all together requires room of at least 4 left over
    // use the programmable full threshold on the downstream fifos of this gearbox (.prog_full)
    // which currently are dcache_req_fifo2, net_get_req_fifo2, net_put_req_fifo2 and victim_data_fifo2
    case(GB_STATE) 
        S_GEARBOX_IDLE: begin
            if(!input_empty && !output_full) begin
                next_GB_STATE = S_GEARBOX_ONE;
            end
        end
        S_GEARBOX_ONE: begin
            next_GB_STATE = S_GEARBOX_TWO;
            if(input_four[4*INT_WIDTH-1]) begin
                output_one = {number, 4'b0001, input_four[3*INT_WIDTH +: (INT_WIDTH-1)]};
                output_wr_en = 1;
            end
        end
        S_GEARBOX_TWO: begin
            next_GB_STATE = S_GEARBOX_THREE;
            if(input_four[3*INT_WIDTH-1]) begin
                output_one = {number, 4'b0010, input_four[2*INT_WIDTH +: (INT_WIDTH-1)]};
                output_wr_en = 1;
            end
        end
        S_GEARBOX_THREE: begin
            next_GB_STATE = S_GEARBOX_FOUR;
            if(input_four[2*INT_WIDTH-1]) begin
                output_one = {number, 4'b0100, input_four[1*INT_WIDTH +: (INT_WIDTH-1)]};
                output_wr_en = 1;
            end
        end
        S_GEARBOX_FOUR: begin
            input_rd_en = 1;
            next_GB_STATE = S_GEARBOX_IDLE;
            if(input_four[1*INT_WIDTH-1]) begin
                output_one = {number, 4'b1000, input_four[0*INT_WIDTH +: (INT_WIDTH-1)]};
                output_wr_en = 1;
            end
        end
    endcase
end
`endif

endmodule
