// Register File
`include "parameters.svh"
import TYPES::*;

module ram_4wide
#(
    parameter ADDR_WIDTH    = 2,
    parameter DATA_WIDTH    = 32,
    parameter NPORTS        = 4
)
(
    input  logic  [NPORTS-1:0]                  wr_en,
    input  logic  [NPORTS-1:0][ADDR_WIDTH-1:0]  wr_addr,
    input  logic  [NPORTS-1:0][DATA_WIDTH-1:0]  wr_data, 
    input  logic  [NPORTS-1:0][ADDR_WIDTH-1:0]  rd_addr,
    output logic  [NPORTS-1:0][DATA_WIDTH-1:0]  rd_data,
    input  logic                                clk 
);


// actual ram content
reg  [DATA_WIDTH-1:0]   ram         [2**ADDR_WIDTH-1:0];

wire [DATA_WIDTH-1:0]   ram_data    [NPORTS-1:0];


// write handling
genvar i;
generate
if(NPORTS == 4) begin
    // Note: r0 is constant zero
    always @(posedge clk) begin
        // pipeline 0
        if(wr_en[0]) ram[wr_addr[0]] = wr_data[0];
        // pipeline 1
        if(wr_en[1]) ram[wr_addr[1]] = wr_data[1];
        // pipeline 2
        if(wr_en[2]) ram[wr_addr[2]] = wr_data[2];
        // pipeline 3
        if(wr_en[3]) ram[wr_addr[3]] = wr_data[3];

    end

    always @(posedge clk) begin
        rd_data[0] <= ram[rd_addr[0]];
        rd_data[1] <= ram[rd_addr[1]];
        rd_data[2] <= ram[rd_addr[2]];
        rd_data[3] <= ram[rd_addr[3]];
    end

    //// pipeline 0 read no forward
    //assign rd_data[0] = ram_data[0];

    //// pipeline 1 read forwarding
    //assign rd_data[1] = (wr_en[0] && (wr_addr[0] == rd_addr[1])) ? wr_data[0] : ram_data[1];

    //// pipeline 2 read forwarding
    //assign rd_data[2] = (wr_en[1] && (wr_addr[1] == rd_addr[2])) ? wr_data[1] :
    //                    (wr_en[0] && (wr_addr[0] == rd_addr[2])) ? wr_data[0] : ram_data[2];

    //// pipeline 3 read forwarding
    //assign rd_data[3] = (wr_en[2] && (wr_addr[2] == rd_addr[3])) ? wr_data[2] :
    //                    (wr_en[1] && (wr_addr[1] == rd_addr[3])) ? wr_data[1] :
    //                    (wr_en[0] && (wr_addr[0] == rd_addr[3])) ? wr_data[0] : ram_data[3] ;

end
else begin
    for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
        assign rd_data[i] = 0;
    end
end

endgenerate

`ifdef SIMULATION
    initial begin
        integer i;
        for(i = 0; i < 32; i=i+1) begin
            ram[i] = 0;
        end
    end
`endif

endmodule



