// sentry hash engine
`timescale 1ns/1ps
`include "parameters.svh"

module sentry_hash_engine (
    input                       clk,
    input                       rst,
    input                       req,
    input [`LINE_WIDTH-1:0]     message,
    input [`ADDRCNT_WIDTH-1:0]  addrcnt,
    output                      ready,
    output [`SMAC_WIDTH-1:0]    digest 
);


localparam [3:0]    S_INIT  = 4'd0,
                    S_FIRST = 4'd1,
                    S_SECOND= 4'd2,
                    S_ALERT = 4'd15;

reg [3:0] H_STATE;

wire second_hash_ready;

reg [`LINE_WIDTH-1:0] hold_line;
reg [`ADDRCNT_WIDTH-1:0] hold_addrcnt;

wire [`LINE_WIDTH-`SMAC_WIDTH-`ADDRCNT_WIDTH-1:0] fill1 = 0;
wire [`LINE_WIDTH-`SMAC_WIDTH-1:0] fill2 = 0;
wire [`SMAC_WIDTH-1:0] key = `SMAC_WIDTH'd0;

wire [`LINE_WIDTH-1:0] i_key_pad = {64{8'h36}} ^ {key, hold_addrcnt, fill1};
wire [`LINE_WIDTH-1:0] o_key_pad = {64{8'h5c}} ^ {key, fill2};

wire first_hash_ready;
wire [`SMAC_WIDTH-1:0] first_hash_out;

wire [`BLOCKS_WIDTH-1:0] first_block_cnt;
wire [`BLOCKS_WIDTH-1:0] second_block_cnt;

wire [`LINE_WIDTH-1:0] first_hash_in  = first_block_cnt == 0  ? i_key_pad :
                                        first_block_cnt == 1  ? hold_line :
                                        `LINE_WIDTH'd0                    ;

wire [`LINE_WIDTH-1:0] second_hash_in = second_block_cnt == 0 ? o_key_pad :
                                        second_block_cnt == 1 ? {first_hash_out, fill2} :
                                        `LINE_WIDTH'd0                    ;

assign ready = H_STATE == S_INIT;

reg buf_first_hash_ready;
always @(posedge clk) begin
    buf_first_hash_ready <= first_hash_ready;
end
wire pulse_first_hash_ready = first_hash_ready & !buf_first_hash_ready;

always @(posedge clk) begin
    if(rst) begin
        H_STATE       <= S_INIT;
        hold_line     <= 0;
        hold_addrcnt  <= 0;
    end
    case (H_STATE)
        S_INIT: begin
            if(req) begin
                H_STATE       <= S_FIRST;
                hold_line     <= message;
                hold_addrcnt  <= addrcnt;
            end
        end
        S_FIRST: begin
            if(first_hash_ready) H_STATE <= S_SECOND;
        end
        S_SECOND: begin
            if(second_hash_ready) H_STATE <= S_INIT;
        end
    endcase
end

// make this parallel
md5 HMAC_MD5_1(
    .clk(clk),
    .rst(rst),
    .req(req),
    .in(first_hash_in),
    .blocks(`BLOCKS_WIDTH'd1),  // two blocks for data/smac { i_key_pad ^ addr_cnt, message }, two blocks for metadata { i_key_pad ^ nothing, message }
    .block_cnt(first_block_cnt),
    .ready(first_hash_ready),
    .out(first_hash_out)
);

md5 HMAC_MD5_2(
    .clk(clk),
    .rst(rst),
    .req(pulse_first_hash_ready),
    .in(second_hash_in),
    .blocks(`BLOCKS_WIDTH'd1), // two blocks: o_keypad + first_hash_out
    .block_cnt(second_block_cnt),
    .ready(second_hash_ready),
    .out(digest)
);


endmodule

//synthesis translate off
module sentry_hash_engine_tb();
reg                         clk;
reg                         rst;
reg                         req;
reg [`LINE_WIDTH-1:0]       message;
reg [`ADDRCNT_WIDTH-1:0]    addrcnt;
wire                        ready;
wire [`SMAC_WIDTH-1:0]      digest;
integer                     i;

sentry_hash_engine DUT(
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

    repeat(100)  @(posedge clk);
    rst = 0;

    for(i = 0; i < 256; i=i+1) begin
        wait(ready);
        repeat(1) @(posedge clk);
        req = 1;
        message = i;
        addrcnt = i;
        repeat(1) @(posedge clk);
        req = 0;
        repeat(1) @(posedge clk);
    end

end
endmodule
//synthesis translate on

