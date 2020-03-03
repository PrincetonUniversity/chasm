// hmac md5 module
module md5
(
    input clk,
    input rst,
    input req,
    input [511:0] in,
    input [31:0] blocks, // this is a constant indicating the number of input blocks
    output reg [31:0] block_cnt,
    output ready,
    output reg [127:0] out
);

`define WORD_LEN 32

reg [43:0] constants;
wire [`WORD_LEN-1:0] KI = constants[12+:32];
wire [5:0] SI = constants[4+:6];
wire [3:0] g = constants[0+:4];
reg [`WORD_LEN-1:0] F, A, B, C, D;
reg [`WORD_LEN-1:0] tmp;
reg [`WORD_LEN-1:0] after_rotate;

localparam [3:0]    S_INIT          = 4'd0,
                    S_REG           = 4'd1,
                    S_COMPUTE       = 4'd2,
                    S_BLOCK_DONE    = 4'd3,
                    S_DONE_DONE     = 4'd4;

reg [3:0] C_STATE;
reg [3:0] next_C_STATE;
reg [5:0] counter;

wire [5:0] iter = counter;
wire [1:0] round = iter[5:4];

wire done_done = block_cnt == blocks;

wire [`WORD_LEN-1:0] msg_word [0:15];
reg [`WORD_LEN-1:0] msg_word_reg [0:15];

genvar i;
generate
for(i = 0; i < 16; i=i+1) begin : MSG 
    assign msg_word[i] = in[i*`WORD_LEN+:`WORD_LEN];
end
endgenerate

generate
for(i = 0; i < 16; i=i+1) begin : MSG_reg
    always @(posedge clk) begin
        if(C_STATE == S_REG) msg_word_reg[i] <= msg_word[i];
    end
end
endgenerate

reg [`WORD_LEN-1:0] a0, b0, c0, d0;

assign ready = C_STATE == S_INIT;

always @(posedge clk) begin
    if(rst) C_STATE <= S_INIT;
    else C_STATE <= next_C_STATE;
end

always @(C_STATE or req or counter or done_done) begin
    case(C_STATE)
        S_INIT: begin
            if(req) next_C_STATE = S_REG; 
            else next_C_STATE = S_INIT;
        end
        S_REG: begin
            next_C_STATE = S_COMPUTE;
        end
        S_COMPUTE: begin
            if(counter == 63) next_C_STATE = S_BLOCK_DONE;
            else next_C_STATE = S_COMPUTE;
        end
        S_BLOCK_DONE: begin
            if(done_done) next_C_STATE = S_DONE_DONE;
            else next_C_STATE = S_REG;
        end
        S_DONE_DONE: begin
            next_C_STATE = S_INIT;
        end
        default:
        next_C_STATE = S_INIT;
    endcase
end

always @(posedge clk) begin
    case(C_STATE)
        S_INIT: begin
            //$display("req is %d", req);
            counter <= 0;
            block_cnt <= 0;
            a0 <= 32'h67452301;
            b0 <= 32'hefcdab89;
            c0 <= 32'h98badcfe;
            d0 <= 32'h10325476;
            A <= a0;
            B <= b0;
            C <= c0;
            D <= d0;
        end
        S_COMPUTE: begin
            // output controls
            counter <= counter + 1;
            D <= C;
            C <= B;
            B <= B + after_rotate;
            A <= D;
        end
        S_BLOCK_DONE: begin
            a0 <= a0 + A;
            b0 <= b0 + B;
            c0 <= c0 + C;
            d0 <= d0 + D;
            A <= a0 + A;
            B <= b0 + B;
            C <= c0 + C;
            D <= d0 + D;
            if(!done_done) begin
                block_cnt <= block_cnt + 1;
            end
        end
        S_DONE_DONE: begin
            out <= {a0, b0, c0, d0};
        end
    endcase
end

always @(*) begin
    case(round)
        0: F =((B&C)|(~B&D));
        1: F =((B&D)|(C&(~D)));
        2: F =(B^C^D);
        3: F =(C^(B|~D));
    endcase
    tmp = A + F + KI + msg_word_reg[g];
    after_rotate = (tmp << SI) | (tmp >> (32-SI));
end

always @(iter) begin
    case (iter)
        0: constants = 44'hD76AA478070; 
        1: constants = 44'hE8C7B7560C1; 		
        2: constants = 44'h242070DB112; 
        3: constants = 44'hC1BDCEEE163; 
        4: constants = 44'hF57C0FAF074; 
        5: constants = 44'h4787C62A0C5; 
        6: constants = 44'hA8304613116; 
        7: constants = 44'hFD469501167; 
        8: constants = 44'h698098D8078; 		
        9: constants = 44'h8B44F7AF0C9; 
        10: constants = 44'hFFFF5BB111A; 
        11: constants = 44'h895CD7BE16B; 
        12: constants = 44'h6B90112207C; 
        13: constants = 44'hFD9871930CD; 
        14: constants = 44'hA679438E11E; 
        15: constants = 44'h49B4082116F; 		

        16: constants = 44'hf61e2562051; 
        17: constants = 44'hc040b340096; 
        18: constants = 44'h265e5a510EB; 
        19: constants = 44'he9b6c7aa140; 
        20: constants = 44'hd62f105d055; 
        21: constants = 44'h0244145309A; 
        22: constants = 44'hd8a1e6810EF; 		
        23: constants = 44'he7d3fbc8144; 
        24: constants = 44'h21e1cde6059; 
        25: constants = 44'hc33707d609E; 
        26: constants = 44'hf4d50d870E3; 
        27: constants = 44'h455a14ed148; 
        28: constants = 44'ha9e3e90505D; 
        29: constants = 44'hfcefa3f8092; 		
        30: constants = 44'h676f02d90E7; 
        31: constants = 44'h8d2a4c8a14C; 

        32: constants = 44'hfffa3942045; 
        33: constants = 44'h8771f6810B8; 
        34: constants = 44'h6d9d612210B; 
        35: constants = 44'hfde5380c17E; 
        36: constants = 44'ha4beea44041; 		
        37: constants = 44'h4bdecfa90B4; 
        38: constants = 44'hf6bb4b60107; 
        39: constants = 44'hbebfbc7017A; 
        40: constants = 44'h289b7ec604D; 
        41: constants = 44'heaa127fa0B0; 
        42: constants = 44'hd4ef3085103; 
        43: constants = 44'h04881d05176; 		
        44: constants = 44'hd9d4d039049; 
        45: constants = 44'he6db99e50BC; 
        46: constants = 44'h1fa27cf810F; 
        47: constants = 44'hc4ac5665172; 

        48: constants = 44'hf4292244060; 
        49: constants = 44'h432aff970A7; 
        50: constants = 44'hab9423a70FE; 		
        51: constants = 44'hfc93a039155; 
        52: constants = 44'h655b59c306C; 
        53: constants = 44'h8f0ccc920A3; 
        54: constants = 44'hffeff47d0FA; 
        55: constants = 44'h85845dd1151; 
        56: constants = 44'h6fa87e4f068; 
        57: constants = 44'hfe2ce6e00AF; 		
        58: constants = 44'ha30143140F6; 
        59: constants = 44'h4e0811a115D; 
        60: constants = 44'hf7537e82064; 
        61: constants = 44'hbd3af2350AB; 
        62: constants = 44'h2ad7d2bb0F2; 
        63: constants = 44'heb86d391159;		 
    endcase
end



endmodule

//synthesis translate off
module md5_tb();
reg  clk;
reg  rst;
reg  req;
reg  [511:0] in;
reg  [31:0] blocks; // this is a constant indicating the number of input blocks
wire [31:0] block_cnt;
wire ready;
wire [127:0] out;

md5 DUT (
    .clk(clk),
    .rst(rst),
    .req(req),
    .in(in),
    .blocks(blocks),
    .block_cnt(block_cnt),
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
    blocks = 0;

    repeat(10)  @(posedge clk);
    rst = 0;
    repeat(2)   @(posedge clk);
    req = 1;
    repeat(1)   @(posedge clk);
    req = 0;


end

endmodule
//synthesis translate on

