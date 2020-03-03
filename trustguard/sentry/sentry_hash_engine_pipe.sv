// sentry hash engine
`timescale 1ns/1ps
`include "parameters.svh"

module sentry_hash_engine_pipe (
    input  logic                        clk,
    input  logic                        rst,
    input  logic                        req,
    input  logic [`LINE_WIDTH-1:0]      message,
    input  logic [`ADDRCNT_WIDTH-1:0]   addrcnt,
    output logic                        ready,
    output logic [`SMAC_WIDTH-1:0]      digest 
);

wire first_hash_ready;
wire [127:0] first_hash;
wire second_hash_ready;
wire [127:0] second_hash;

wire [`LINE_WIDTH-`SMAC_WIDTH-`ADDRCNT_WIDTH-1:0] fill1 = 0;
wire [`LINE_WIDTH-`SMAC_WIDTH-1:0] fill2 = 0;
wire [`SMAC_WIDTH-1:0] key = `SMAC_WIDTH'd0;

wire [`LINE_WIDTH-1:0] i_key_pad = {64{8'h36}} ^ {key, addrcnt, fill1};
wire [`LINE_WIDTH-1:0] o_key_pad = {64{8'h5c}} ^ {key, fill2};

wire [1023:0] first_in = {i_key_pad, message};
wire [1023:0] second_in = {o_key_pad, first_hash, fill2};

md5_pipe MD5_1 (
    .clk(clk),
    .rst(rst),
    .req(req),
    .in(first_in),
    .ready(first_hash_ready),
    .out(first_hash)
);

md5_pipe MD5_2 (
    .clk(clk),
    .rst(rst),
    .req(first_hash_ready),
    .in(second_in),
    .ready(second_hash_ready),
    .out(second_hash)
);

assign ready = second_hash_ready;
assign digest = second_hash;

endmodule

//synthesis translate off
module sentry_hash_engine_pipe_tb();
reg                         clk;
reg                         rst;
reg                         req;
reg [`LINE_WIDTH-1:0]       message;
reg [`ADDRCNT_WIDTH-1:0]    addrcnt;
wire                        ready;
wire [`SMAC_WIDTH-1:0]      digest;
integer                     i;

sentry_hash_engine_pipe DUT(
    .clk(clk),
    .rst(rst),
    .req(req),
    .message(message),
    .addrcnt(addrcnt),
    .ready(ready),
    .digest(digest)
);

always begin
    #5 clk = ~clk;
end

initial begin
    clk = 1;
    rst = 1;
    req = 0;
    message = `LINE_WIDTH'd0;
    addrcnt = `ADDRCNT_WIDTH'd0;

    repeat(1000)  @(posedge clk);
    rst = 0;
    //repeat(100)  @(posedge clk);
    #100 req = 1;
    message = `LINE_WIDTH'h00542c230005029b000104330281302302113423fd01011300008067040101130381309f0301341f0004013300a5b023000285930002b51f0184329f00a5b023;
    addrcnt = `ADDRCNT_WIDTH'h000000000000750000000000000000000000;
    #10 req = 0;
    //for(i = 0; i < 256; i=i+1) begin
    //    message = i;
    //    addrcnt = i;
    //    #10;
    //end
    req = 0;

end
endmodule
//synthesis translate on

