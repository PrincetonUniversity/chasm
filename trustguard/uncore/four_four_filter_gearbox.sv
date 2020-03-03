// Queued Request Four-to-One Gear Box
`timescale 1ns/1ps
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

//INT_WIDTH == DATA_WIDTH + 1;

module four_four_filter_gearbox
#(
    parameter INT_WIDTH = 1,
    parameter IDLE_FLUSH = 0
)
(
    input  logic                            input_inst_valid,
    input  logic [3:0]                      input_valid,
    input  logic [4*INT_WIDTH-1:0]          input_data,
    output logic                            output_full,
    output logic                            output_prog_full,
    output logic [3:0]                      output_valid,
    output logic [4*INT_WIDTH-1:0]          output_data,
    output logic [4*32-1:0]                 output_metadata,
    // Clock and Reset
    input  logic                            clk,
    input  logic                            rst
);

reg  [INT_WIDTH+32-1:0] output_bank [7:0];
reg  [7:0]              output_bank_valid;
reg  [2:0]              output_bank_ptr;

reg  [INT_WIDTH+32-1:0] fill_data   [3:0];
reg  [3:0]              fill_valid;
reg  [2:0]              fill_cnt;

reg  [63:0]             in_cnt;
reg  [63:0]             out_cnt;

reg  [63:0]             in_din;
wire [27:0]             input_din   [3:0];

wire [INT_WIDTH+32-1:0] input_datas [3:0];

// idle counter is needed to flush the filter gearbox
// when idle counter goes over threashold (say 10)
// the remaining item in the gearbox banks is flushed to the
// instruction memory request fifo
reg  [31:0]             idle_cnt;

always @(posedge clk) begin
    if(rst) idle_cnt <= 32'd0;
    else idle_cnt <= (|input_valid || output_full) ? 32'd0 : idle_cnt + 32'd1;
end

always @(posedge clk) begin
    if(rst) in_din <= 64'd0;
    else if(input_inst_valid) in_din <= in_din + 64'd4;
end

assign input_din[0] = in_din + 28'd1;
assign input_din[1] = in_din + 28'd2;
assign input_din[2] = in_din + 28'd3;
assign input_din[3] = in_din + 28'd4;

assign input_datas[0] = {input_din[0], 4'h1, input_data[0*INT_WIDTH+:INT_WIDTH]};
assign input_datas[1] = {input_din[1], 4'h2, input_data[1*INT_WIDTH+:INT_WIDTH]};
assign input_datas[2] = {input_din[2], 4'h4, input_data[2*INT_WIDTH+:INT_WIDTH]};
assign input_datas[3] = {input_din[3], 4'h8, input_data[3*INT_WIDTH+:INT_WIDTH]};

// cycle 1
always @(posedge clk) begin
    //fill_cnt        <= fill_valid[0] + fill_valid[1] + fill_valid[2] + fill_valid[3];
    fill_cnt        <=  input_valid[0] + input_valid[1] + input_valid[2] + input_valid[3];

    fill_data[0]    <=  input_valid[0] ? input_datas[0] :
                        input_valid[1] ? input_datas[1] :
                        input_valid[2] ? input_datas[2] :
                        input_valid[3] ? input_datas[3] : {INT_WIDTH{1'b1}};

    fill_data[1]    <=  input_valid[0] ?   
                            (input_valid[1] ? input_datas[1] :
                             input_valid[2] ? input_datas[2] :
                             input_valid[3] ? input_datas[3] : {INT_WIDTH{1'b1}}) : 
                            (input_valid[1] ? (input_valid[2] ? input_datas[2] : 
                                               input_valid[3] ? input_datas[3] : {INT_WIDTH{1'b1}}) :
                                             ((input_valid[2] && input_valid[3]) ? input_datas[3] : {INT_WIDTH{1'b1}}));

    fill_data[2]    <=  (input_valid[0] && input_valid[1]) ? // first two data both valid
                            (input_valid[2] ? input_datas[2] :
                             input_valid[3] ? input_datas[3] : {INT_WIDTH{1'b1}}) :
                            ((input_valid[0] || input_valid[1]) ? // one of first two data valid
                                ((input_valid[2] && input_valid[3]) ? input_datas[3] : {INT_WIDTH{1'b1}}) :  
                                {INT_WIDTH{1'b1}});                 // first two data both invalid

    fill_data[3]    <=  (input_valid == 4'b1111) ? input_datas[3] : {INT_WIDTH{1'b1}};
end

assign fill_valid[0] = fill_cnt > 3'd0;
assign fill_valid[1] = fill_cnt > 3'd1;
assign fill_valid[2] = fill_cnt > 3'd2;
assign fill_valid[3] = fill_cnt > 3'd3;


// Cycle 2
always @(posedge clk) begin
    if(rst) begin
        output_bank_ptr <= 3'd0;
        in_cnt <= 64'd0;
    end
    else begin
        if(fill_valid[0]) begin
            output_bank[output_bank_ptr+3'd0] <= fill_data[0];
        end
        if(fill_valid[1]) begin
            output_bank[output_bank_ptr+3'd1] <= fill_data[1];
        end
        if(fill_valid[2]) begin
            output_bank[output_bank_ptr+3'd2] <= fill_data[2];
        end
        if(fill_valid[3]) begin
            output_bank[output_bank_ptr+3'd3] <= fill_data[3];
        end
        output_bank_valid[output_bank_ptr+:4] <= fill_valid;
        output_bank_ptr <= output_full? 3'd0 : output_bank_ptr + fill_cnt;
        in_cnt <= output_full? 64'd0 : in_cnt + fill_cnt;
    end
end

// Cycle 3
wire flush;
always @(*) begin
    if (IDLE_FLUSH == 1) begin
        output_prog_full <= (idle_cnt >= 32'd18) && (in_cnt != out_cnt);
        output_full <= (idle_cnt >= 32'd20) && (in_cnt != out_cnt);
    end
    else begin
        output_prog_full <= 0;
        output_full <= 0;
    end
end

always @(posedge clk) begin
    if(rst) begin
        out_cnt <= 64'd0;
    end
    else begin
        // IDLE FLUSH enabled, for Inst Cache Memory Manager
        if (IDLE_FLUSH == 1) begin
            //if((idle_cnt > 32'd5) && (in_cnt != out_cnt)) begin
            if(output_full) begin
                // output first bank
                if(out_cnt[2:0] == 3'h0) begin
                    output_data     <= {output_bank[0][INT_WIDTH-1:0],
                        output_bank[1][INT_WIDTH-1:0],
                        output_bank[2][INT_WIDTH-1:0],
                    output_bank[3][INT_WIDTH-1:0]};
                    output_metadata <= {output_bank[0][INT_WIDTH+:32],
                        output_bank[1][INT_WIDTH+:32],
                        output_bank[2][INT_WIDTH+:32],
                    output_bank[3][INT_WIDTH+:32]};
                    output_valid    <= in_cnt[2:0] == 3'h1 ? 4'b0001 :
                    in_cnt[2:0] == 3'h2 ? 4'b0011 :
                    in_cnt[2:0] == 3'h3 ? 4'b0111 : 4'b0000;
                end
                else begin
                    output_data     <= {output_bank[4][INT_WIDTH-1:0],
                        output_bank[5][INT_WIDTH-1:0],
                        output_bank[6][INT_WIDTH-1:0],
                    output_bank[7][INT_WIDTH-1:0]};
                    output_metadata <= {output_bank[4][INT_WIDTH+:32],
                        output_bank[5][INT_WIDTH+:32],
                        output_bank[6][INT_WIDTH+:32],
                    output_bank[7][INT_WIDTH+:32]};
                    output_valid    <= in_cnt[2:0] == 3'h5 ? 4'b0001 :
                    in_cnt[2:0] == 3'h6 ? 4'b0011 :
                    in_cnt[2:0] == 3'h7 ? 4'b0111 : 4'b0000;
                end
                out_cnt <= 32'd0;
            end
            else if(in_cnt - out_cnt >= 64'd4) begin
                if(in_cnt[2:0] >= 3'h4) begin
                    output_data     <= {output_bank[0][INT_WIDTH-1:0],
                        output_bank[1][INT_WIDTH-1:0],
                        output_bank[2][INT_WIDTH-1:0],
                    output_bank[3][INT_WIDTH-1:0]};
                    output_metadata <= {output_bank[0][INT_WIDTH+:32],
                        output_bank[1][INT_WIDTH+:32],
                        output_bank[2][INT_WIDTH+:32],
                    output_bank[3][INT_WIDTH+:32]};
                    output_valid <= 4'hf;
                end
                else begin
                    output_data     <= {output_bank[4][INT_WIDTH-1:0],
                        output_bank[5][INT_WIDTH-1:0],
                        output_bank[6][INT_WIDTH-1:0],
                    output_bank[7][INT_WIDTH-1:0]};
                    output_metadata <= {output_bank[4][INT_WIDTH+:32],
                        output_bank[5][INT_WIDTH+:32],
                        output_bank[6][INT_WIDTH+:32],
                    output_bank[7][INT_WIDTH+:32]};
                    output_valid <= 4'hf;
                end
                out_cnt <= out_cnt + 64'd4;
            end
            else begin
                output_data <= 'd0;
                output_valid <= 4'h0;
            end
        end
        // IDLE FLUSH disabled, for data cache filter
        else begin
            if(in_cnt - out_cnt >= 64'd4) begin
                if(in_cnt[2:0] >= 3'h4) begin
                    output_data     <= {output_bank[0][INT_WIDTH-1:0],
                        output_bank[1][INT_WIDTH-1:0],
                        output_bank[2][INT_WIDTH-1:0],
                    output_bank[3][INT_WIDTH-1:0]};
                    output_metadata <= {output_bank[0][INT_WIDTH+:32],
                        output_bank[1][INT_WIDTH+:32],
                        output_bank[2][INT_WIDTH+:32],
                    output_bank[3][INT_WIDTH+:32]};
                    output_valid <= 4'hf;
                end
                else begin
                    output_data     <= {output_bank[4][INT_WIDTH-1:0],
                        output_bank[5][INT_WIDTH-1:0],
                        output_bank[6][INT_WIDTH-1:0],
                    output_bank[7][INT_WIDTH-1:0]};
                    output_metadata <= {output_bank[4][INT_WIDTH+:32],
                        output_bank[5][INT_WIDTH+:32],
                        output_bank[6][INT_WIDTH+:32],
                    output_bank[7][INT_WIDTH+:32]};
                    output_valid <= 4'hf;
                end
                out_cnt <= out_cnt + 64'd4;
            end
            else begin
                output_data <= 'd0;
                output_valid <= 4'h0;
            end
        end
    end
end

endmodule
