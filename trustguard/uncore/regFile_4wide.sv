// Register File
`include "parameters.svh"
import TYPES::*;

(* keep_hierarchy = "yes" *)module regFile_4wide
(
    input  logic                          clk,
    input  logic                          rst,
    (*keep="true"*)input  logic  [`SENTRY_WIDTH-1:0]     wr_en,
    (*keep="true"*)input  logic  [`REG_ADDR_WIDTH-1:0]   wr_addr     [`SENTRY_WIDTH-1:0],
    (*keep="true"*)input  logic  [`X_LEN-1:0]            wr_data     [`SENTRY_WIDTH-1:0], 
    (*keep="true"*)input  logic  [`REG_ADDR_WIDTH-1:0]   rd_addr_a   [`SENTRY_WIDTH-1:0],
    (*keep="true"*)input  logic  [`REG_ADDR_WIDTH-1:0]   rd_addr_b   [`SENTRY_WIDTH-1:0],
    (*keep="true"*)output logic  [`X_LEN-1:0]            rd_data_a   [`SENTRY_WIDTH-1:0],
    (*keep="true"*)output logic  [`X_LEN-1:0]            rd_data_b   [`SENTRY_WIDTH-1:0]
);


(*keep="true"*)reg  [`X_LEN-1:0] rf        [`REG_DEPTH-1:0];
wire [`X_LEN-1:0] rf_data_a [`SENTRY_WIDTH-1:0];
wire [`X_LEN-1:0] rf_data_b [`SENTRY_WIDTH-1:0];

wire [`SENTRY_WIDTH-1:0] wr_disable;

// write handling
genvar i;
generate
if(`SENTRY_WIDTH == 4) begin
    assign wr_disable[0] = (wr_en[0] && wr_en[1] && (wr_addr[0] == wr_addr[1])) 
                        || (wr_en[0] && wr_en[2] && (wr_addr[0] == wr_addr[2]))
                        || (wr_en[0] && wr_en[3] && (wr_addr[0] == wr_addr[3]));

    assign wr_disable[1] = (wr_en[1] && wr_en[2] && (wr_addr[1] == wr_addr[2])) 
                        || (wr_en[1] && wr_en[3] && (wr_addr[1] == wr_addr[3]));

    assign wr_disable[2] = (wr_en[2] && wr_en[3] && (wr_addr[2] == wr_addr[3]));

    assign wr_disable[3] = 0;


// Note: r0 is constant zero
always @(posedge clk) begin
    // on reset, initialize stack pointer and return address
    if(rst) begin
        rf[`REG_ADDR_WIDTH'd1] <= `X_LEN'hdeadbeef; // return address
        rf[`REG_ADDR_WIDTH'd2] <= `X_LEN'h3ffffff8; // stack pointer
        rf[`REG_ADDR_WIDTH'd3] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd4] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd5] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd6] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd7] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd8] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd9] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd10] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd11] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd12] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd13] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd14] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd15] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd16] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd17] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd18] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd19] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd20] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd21] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd22] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd23] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd24] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd25] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd26] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd27] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd28] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd29] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd30] <= `X_LEN'd0;
        rf[`REG_ADDR_WIDTH'd31] <= `X_LEN'd0;
    end
    else begin
        // pipeline 0
        if (wr_en[0] && (!wr_disable[0]) && (|wr_addr[0])) begin
            rf[wr_addr[0]] <= wr_data[0];
            `ifdef SIMULATION
                //$display("Pipeline 0 WR.RF[%d] = %h\n", wr_addr[0], wr_data[0]);
            `endif
        end
        // pipeline 1
        if (wr_en[1] && (!wr_disable[1]) && (|wr_addr[1])) begin
            rf[wr_addr[1]] <= wr_data[1];
            `ifdef SIMULATION
                //$display("Pipeline 1 WR.RF[%d] = %h\n", wr_addr[1], wr_data[1]);
            `endif
        end
        // pipeline 2
        if (wr_en[2] && (!wr_disable[2]) && (|wr_addr[2])) begin
            rf[wr_addr[2]] <= wr_data[2];
            `ifdef SIMULATION
                //$display("Pipeline 2 WR.RF[%d] = %h\n", wr_addr[2], wr_data[2]);
            `endif
        end
        // pipeline 3
        if (wr_en[3] && (!wr_disable[3]) && (|wr_addr[3])) begin
            rf[wr_addr[3]] <= wr_data[3];
            `ifdef SIMULATION
                //$display("Pipeline 3 WR.RF[%d] = %h\n", wr_addr[3], wr_data[3]);
            `endif
        end
    end
end

assign  rf_data_a[0] = rf[rd_addr_a[0]];
assign  rf_data_a[1] = rf[rd_addr_a[1]];
assign  rf_data_a[2] = rf[rd_addr_a[2]];
assign  rf_data_a[3] = rf[rd_addr_a[3]];
assign  rf_data_b[0] = rf[rd_addr_b[0]];
assign  rf_data_b[1] = rf[rd_addr_b[1]];
assign  rf_data_b[2] = rf[rd_addr_b[2]];
assign  rf_data_b[3] = rf[rd_addr_b[3]];

// pipeline 0 read no forward
assign rd_data_a[0] = rd_addr_a[0] == 'd0 ? `X_LEN'd0 : rf_data_a[0];
assign rd_data_b[0] = rd_addr_b[0] == 'd0 ? `X_LEN'd0 : rf_data_b[0];

// pipeline 1 read forwarding
assign rd_data_a[1] = rd_addr_a[1] == 'd0 ? `X_LEN'd0 :
                      (wr_en[0] && (wr_addr[0] == rd_addr_a[1])) ? wr_data[0] : rf_data_a[1];
assign rd_data_b[1] = rd_addr_b[1] == 'd0 ? `X_LEN'd0 :
                      (wr_en[0] && (wr_addr[0] == rd_addr_b[1])) ? wr_data[0] : rf_data_b[1];

// pipeline 2 read forwarding
assign rd_data_a[2] = rd_addr_a[2] == 'd0 ? `X_LEN'd0 :
                      (wr_en[1] && (wr_addr[1] == rd_addr_a[2])) ? wr_data[1] :
                      (wr_en[0] && (wr_addr[0] == rd_addr_a[2])) ? wr_data[0] : rf_data_a[2];

assign rd_data_b[2] = rd_addr_b[2] == 'd0 ? `X_LEN'd0 :
                      (wr_en[1] && (wr_addr[1] == rd_addr_b[2])) ? wr_data[1] :
                      (wr_en[0] && (wr_addr[0] == rd_addr_b[2])) ? wr_data[0] : rf_data_b[2];

// pipeline 3 read forwarding
assign rd_data_a[3] = rd_addr_a[3] == 'd0 ? `X_LEN'd0 :
                      (wr_en[2] && (wr_addr[2] == rd_addr_a[3])) ? wr_data[2] :
                      (wr_en[1] && (wr_addr[1] == rd_addr_a[3])) ? wr_data[1] :
                      (wr_en[0] && (wr_addr[0] == rd_addr_a[3])) ? wr_data[0] : rf_data_a[3] ;

assign rd_data_b[3] = rd_addr_b[3] == 'd0 ? `X_LEN'd0 :
                      (wr_en[2] && (wr_addr[2] == rd_addr_b[3])) ? wr_data[2] :
                      (wr_en[1] && (wr_addr[1] == rd_addr_b[3])) ? wr_data[1] :
                      (wr_en[0] && (wr_addr[0] == rd_addr_b[3])) ? wr_data[0] : rf_data_b[3] ;

end
else begin
    for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
        assign rd_data_a[i] = 0;
        assign rd_data_b[i] = 0;
    end
end

endgenerate

endmodule


