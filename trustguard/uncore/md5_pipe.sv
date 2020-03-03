// hmac md5 module
`timescale 1ns/1ps
`include "parameters.svh"

module md5_pipe
(
    input  logic            clk,
    input  logic            rst,
    input  logic            req,
    input  logic [1023:0]   in,
    output logic            ready,
    output logic [127:0]    out
);

`define WORD_LEN 32
//reg [127:0] out;
// stage 0:     1 cycle a0-d0 initialization
// stage 1:     1 cycle A-D initialization
// stage 2-65:  64 cycle A-D compute
// stage 66:    1 cycle a0-d0 update
// stage 67:    1 cycle A-D initialization
// stage 68-131:64 cycle A-D compute
// stage 132:   1 cycle a0-d0 update
// stage 133:   1 cycle output
`define PSTAGE 134
// constants
reg  [43:0]             constants       [0:63];
wire [`WORD_LEN-1:0]    KI              [0:63];
wire [5:0]              SI              [0:63]; 
wire [3:0]              g               [0:63];
// pipeline stages
reg  [`WORD_LEN-1:0]    F               [0:`PSTAGE-1];
reg  [`WORD_LEN-1:0]    A               [0:`PSTAGE-1];
reg  [`WORD_LEN-1:0]    B               [0:`PSTAGE-1];
reg  [`WORD_LEN-1:0]    C               [0:`PSTAGE-1];
reg  [`WORD_LEN-1:0]    D               [0:`PSTAGE-1];
reg  [`WORD_LEN-1:0]    a0              [0:`PSTAGE-1];
reg  [`WORD_LEN-1:0]    b0              [0:`PSTAGE-1];
reg  [`WORD_LEN-1:0]    c0              [0:`PSTAGE-1];
reg  [`WORD_LEN-1:0]    d0              [0:`PSTAGE-1];
reg  [`WORD_LEN-1:0]    tmp             [0:`PSTAGE-1];
reg  [`WORD_LEN-1:0]    after_rotate    [0:`PSTAGE-1];
reg                     valid           [0:`PSTAGE-1];
reg  [511:0]            inputs          [0:`PSTAGE-1];
wire [`WORD_LEN-1:0]    msg_word        [0:`PSTAGE-1][0:15];
wire [511:0]            fifo_out;
wire                    full;
wire                    empty;

// debugging information
reg  [31:0]             debug_cnt;
always@(posedge clk) begin
    if(req) debug_cnt <= 0;
    else debug_cnt <= debug_cnt + 1;
end

// fifo to cache second half of the 1024 input
md5_fifo MD5_FIFO(
    .clk(clk),
    .rst(rst),
    .din(in[511:0]),
    .wr_en(req),
    .rd_en(valid[65]),
    .dout(fifo_out),
    .full(full),
    .empty(empty)
);

initial begin
    $readmemh("/home/hansenz/sentrySim/vSentry/src/main/verilog/md5_const.mem", constants);
end

genvar i, j;
generate
for(i = 0; i < `PSTAGE; i=i+1) begin : msgloop1
    for(j = 0; j < 16; j=j+1) begin : msgloop2
        assign msg_word[i][j] = inputs[i][j*`WORD_LEN+:`WORD_LEN];
    end
end
endgenerate

generate
for(i = 0; i < 64; i=i+1) begin : CONSTS
    assign KI[i] = constants[i][12+:32];
    assign SI[i] = constants[i][4+:6];
    assign g[i] = constants[i][0+:4];
end
endgenerate

generate
for(i = 0; i < `PSTAGE; i=i+1) begin : COMPUTE
    always @(posedge clk) begin
        if(i == 0) begin
            A[i]    <= 0;
            B[i]    <= 0;
            C[i]    <= 0;
            D[i]    <= 0;
            a0[i]   <= 32'h67452301;
            b0[i]   <= 32'hefcdab89;
            c0[i]   <= 32'h98badcfe;
            d0[i]   <= 32'h10325476;
            valid[i]    <= req;
            inputs[i]   <= in[1023:512];
        end
        else if(i == 1) begin
            A[i]    <= a0[i-1];
            B[i]    <= b0[i-1];
            C[i]    <= c0[i-1];
            D[i]    <= d0[i-1];
            a0[i]   <= a0[i-1];
            b0[i]   <= b0[i-1];
            c0[i]   <= c0[i-1];
            d0[i]   <= d0[i-1];
            valid[i]    <= valid[i-1];
            inputs[i]   <= inputs[i-1];
        end
        else if(i < 66) begin
            A[i]    <= D[i-1];
            B[i]    <= B[i-1] + after_rotate[i-1];
            C[i]    <= B[i-1];
            D[i]    <= C[i-1];
            a0[i]   <= a0[i-1];
            b0[i]   <= b0[i-1];
            c0[i]   <= c0[i-1];
            d0[i]   <= d0[i-1];
            valid[i]    <= valid[i-1];
            inputs[i]   <= inputs[i-1];
        end
        else if(i == 66) begin
            A[i]    <= 0;
            B[i]    <= 0;
            C[i]    <= 0;
            D[i]    <= 0;
            a0[i]   <= a0[i-1] + A[i-1];
            b0[i]   <= b0[i-1] + B[i-1];
            c0[i]   <= c0[i-1] + C[i-1];
            d0[i]   <= d0[i-1] + D[i-1];
            valid[i]    <= valid[i-1];
            inputs[i]   <= fifo_out;
        end
        else if(i == 67) begin
            A[i]    <= a0[i-1];
            B[i]    <= b0[i-1];
            C[i]    <= c0[i-1];
            D[i]    <= d0[i-1];
            a0[i]   <= a0[i-1];
            b0[i]   <= b0[i-1];
            c0[i]   <= c0[i-1];
            d0[i]   <= d0[i-1];
            valid[i]    <= valid[i-1];
            inputs[i]   <= inputs[i-1];
        end
        else if(i < 132) begin
            A[i]    <= D[i-1];
            B[i]    <= B[i-1] + after_rotate[i-1];
            C[i]    <= B[i-1];
            D[i]    <= C[i-1];
            a0[i]   <= a0[i-1];
            b0[i]   <= b0[i-1];
            c0[i]   <= c0[i-1];
            d0[i]   <= d0[i-1];
            valid[i]    <= valid[i-1];
            inputs[i]   <= inputs[i-1];
        end
        else if(i == 132) begin
            A[i]    <= 0;
            B[i]    <= 0;
            C[i]    <= 0;
            D[i]    <= 0;
            a0[i]   <= a0[i-1] + A[i-1];
            b0[i]   <= b0[i-1] + B[i-1];
            c0[i]   <= c0[i-1] + C[i-1];
            d0[i]   <= d0[i-1] + D[i-1];
            valid[i]    <= valid[i-1];
            inputs[i]   <= inputs[i-1];
        end
        else begin
            A[i]    <= 0;
            B[i]    <= 0;
            C[i]    <= 0;
            D[i]    <= 0;
            a0[i]   <= 0;
            b0[i]   <= 0;
            c0[i]   <= 0;
            d0[i]   <= 0;
            valid[i]    <= valid[i-1];
            inputs[i]   <= inputs[i-1];
            out     <= {a0[i-1], b0[i-1], c0[i-1], d0[i-1]};
            ready   <= valid[i-1];
        end
    end
end
endgenerate

generate
for(i = 0; i < `PSTAGE; i=i+1) begin : Floop
    always @(*) begin
        if((i >=   2) && (i <  18))         F[i-1] = ((B[i-1]&C[i-1])|((~B[i-1])&D[i-1]));
        else if((i >=  18) && (i <  34))    F[i-1] = ((B[i-1]&D[i-1])|(C[i-1]&(~D[i-1])));
        else if((i >=  34) && (i <  50))    F[i-1] = (B[i-1]^C[i-1]^D[i-1]);
        else if((i >=  50) && (i <  66))    F[i-1] = (C[i-1]^(B[i-1]|(~D[i-1])));
        else if((i >=  68) && (i <  84))    F[i-1] = ((B[i-1]&C[i-1])|((~B[i-1])&D[i-1]));
        else if((i >=  84) && (i < 100))    F[i-1] = ((B[i-1]&D[i-1])|(C[i-1]&(~D[i-1])));
        else if((i >= 100) && (i < 116))    F[i-1] = (B[i-1]^C[i-1]^D[i-1]);
        else if((i >= 116) && (i < 132))    F[i-1] = (C[i-1]^(B[i-1]|(~D[i-1])));
        else if(i >= 1)                     F[i-1] = 0;
        else                                F[i] = 0;
    end
end
endgenerate

generate
for(i = 0; i < `PSTAGE; i=i+1) begin : tmploop
    always @(*) begin
        if((i >= 2) && (i < 66)) begin
            tmp[i-1] = A[i-1] + F[i-1] + KI[i-2] + msg_word[i-1][g[i-2]];
            after_rotate[i-1] = (tmp[i-1] << SI[i-2]) | (tmp[i-1] >> (32-SI[i-2]));
        end
        else if((i >= 68) && (i < 132)) begin
            tmp[i-1] = A[i-1] + F[i-1] + KI[i-68] + msg_word[i-1][g[i-68]];
            after_rotate[i-1] = (tmp[i-1] << SI[i-68]) | (tmp[i-1] >> (32-SI[i-68]));
        end
        else if(i >= 1) begin
            tmp[i-1] = 0;
            after_rotate[i-1] = 0;
        end
        else begin
            tmp[i] = 0;
            after_rotate[i] = 0;
        end
    end
end
endgenerate

endmodule

//synthesis translate off
module md5_pipe_tb();
reg  clk;
reg  rst;
reg  req;
reg  [1023:0] in;
wire ready;
wire [127:0] out;

reg [`LINE_WIDTH-`SMAC_WIDTH-`ADDRCNT_WIDTH-1:0] fill1 = 0;
reg [`LINE_WIDTH-`SMAC_WIDTH-1:0] fill2 = 0;
reg [`SMAC_WIDTH-1:0] key = `SMAC_WIDTH'd0;
reg [`ADDRCNT_WIDTH-1:0] addrcnt;


md5_pipe DUT (
    .clk(clk),
    .rst(rst),
    .req(req),
    .in(in),
    .ready(ready),
    .out(out)
);

always begin
    #5 clk = ~clk;
end

initial begin
    clk = 1;
    rst = 1;
    req = 0;
    in = 0;

    repeat(150)  @(posedge clk);
    rst = 0;

    //repeat(10)   @(posedge clk);
    #100 req = 1;
    in = {({64{8'h36}}^{key, `ADDRCNT_WIDTH'd10, fill1}),512'd10};

    #10 in = {({64{8'h36}}^{key, `ADDRCNT_WIDTH'd11, fill1}),512'd11};
    #10 req = 0;
    //repeat(1)   @(posedge clk);
    //req = 0;


end

endmodule
//synthesis translate on

