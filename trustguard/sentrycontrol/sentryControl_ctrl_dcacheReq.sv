// Central control of sentryControl unit
`timescale 1ns/1ps
`include "parameters.svh"
`include "encodings.svh"
import TYPES::*;

module sentryControl_ctrl_dcacheReq (
    // Interface from internal inst pkt forwarding 
    // inst pkt1
    output logic [`SENTRY_WIDTH-1:0]    ctrl_inst_pkt1_fifo_rd_en,
    input  pkt1_t                       ctrl_inst_pkt1_fifo_output      [`SENTRY_WIDTH-1:0],
    input  logic [`SENTRY_WIDTH-1:0]    ctrl_inst_pkt1_fifo_empty,
    input  logic [`SENTRY_WIDTH-1:0]    ctrl_inst_pkt1_fifo_almost_empty,
    // inst pkt2
    output logic [`SENTRY_WIDTH-1:0]    ctrl_inst_pkt2_fifo_rd_en,
    input  pkt2_t                       ctrl_inst_pkt2_fifo_output      [`SENTRY_WIDTH-1:0],
    input  logic [`SENTRY_WIDTH-1:0]    ctrl_inst_pkt2_fifo_empty,
    input  logic [`SENTRY_WIDTH-1:0]    ctrl_inst_pkt2_fifo_almost_empty,
    // DCache Control Interface
    input  logic                        dcache_req_almost_full, // back pressure
    output logic [`SENTRY_WIDTH-1:0]    dcache_req_valid,
    output logic [`SENTRY_WIDTH-1:0]    dcache_req_store,
    output addr_t                       dcache_req_address              [`SENTRY_WIDTH-1:0],
    output logic [`SENTRY_WIDTH-1:0]    dcache_inst_valid,
    // Clock and reset
    input  logic                        clk,
    input  logic                        rst
);

localparam MEMD     = `ISETS        ; // memory depth
localparam DATAW    = `LINE_WIDTH   ; // data width
localparam nRPORTS  = `SENTRY_WIDTH ; // number of reading ports
localparam nWPORTS  = `SENTRY_WIDTH ; // number of writing ports
localparam WAW      = 1             ; // WAW (Write-After-Write ) protection
localparam WDW      = 0             ; // WDW (Write-During-Write) protection
localparam RAW      = 1             ; // RAW (Read-After-Write  ) protection
localparam RDW      = 1             ; // RDW (Read-During-Write ) protection
localparam BYP      = RDW ? "RDW" : (RAW ? "RAW" : (WAW ? "WAW" : "NON"));

genvar i, j;

// pipeline request valid
reg  [`SENTRY_WIDTH-1:0]                inst_valid;
wire [`SENTRY_WIDTH-1:0]                inst_ready;
wire                                    inst_frame_ready;
reg                                     inst_frame_ready_reg;
addr_t                                  inst_PC                 [`SENTRY_WIDTH-1:0];
data_t                                  inst_result             [`SENTRY_WIDTH-1:0];
wire [`BYTE_OFFSET_WIDTH-3:0]           inst_offset             [`SENTRY_WIDTH-1:0];
reg  [`BYTE_OFFSET_WIDTH-3:0]           inst_offset_reg         [`SENTRY_WIDTH-1:0];
inst_t                                  instruction             [`SENTRY_WIDTH-1:0];
data_t                                  result                  [`SENTRY_WIDTH-1:0];

// Instruction cache control
wire [`IWAYS-1:0]                       wr_en               [`SENTRY_WIDTH-1:0];
wire [`I_INDEX_WIDTH-1:0]               wr_index            [`SENTRY_WIDTH-1:0];
line_t                                  wr_line             [`SENTRY_WIDTH-1:0];
wire [`IWAYS-1:0]                       rd_en               [`SENTRY_WIDTH-1:0];
wire [`I_INDEX_WIDTH-1:0]               rd_index            [`SENTRY_WIDTH-1:0];
line_t                                  rd_line             [`SENTRY_WIDTH-1:0][`IWAYS-1:0];
wire [2:0]                              rd_hit_way          [`SENTRY_WIDTH-1:0];
reg  [2:0]                              rd_hit_way_reg      [`SENTRY_WIDTH-1:0];

// multiport ram control 
reg  [`SENTRY_WIDTH-1:0]                ram_wr_en     [`IWAYS-1:0];
//reg  [`SENTRY_WIDTH*`I_INDEX_WIDTH-1:0] ram_wr_index  [`IWAYS-1:0];
//reg  [`SENTRY_WIDTH*`LINE_WIDTH-1:0]    ram_wr_line   [`IWAYS-1:0];
//reg  [`SENTRY_WIDTH*`I_INDEX_WIDTH-1:0] ram_rd_index  [`IWAYS-1:0];
//wire [`SENTRY_WIDTH*`LINE_WIDTH-1:0]    ram_rd_line   [`IWAYS-1:0];
reg  [`SENTRY_WIDTH-1:0][`I_INDEX_WIDTH-1:0] ram_wr_index  [`IWAYS-1:0];
reg  [`SENTRY_WIDTH-1:0][`I_INDEX_WIDTH-1:0] ram_rd_index  [`IWAYS-1:0];
reg  [`SENTRY_WIDTH-1:0][`LINE_WIDTH-1:0]    ram_wr_line   [`IWAYS-1:0];
wire [`SENTRY_WIDTH-1:0][`LINE_WIDTH-1:0]    ram_rd_line   [`IWAYS-1:0];

// inst cache line forwarding and read logic
reg                                     forward0to1;
reg                                     forward0to2;
reg                                     forward0to3;
reg                                     forward1to2;
reg                                     forward1to3;
reg                                     forward2to3;
reg  [`SENTRY_WIDTH-1:0]                pipe_mhb;
line_t                                  actual_line         [`SENTRY_WIDTH-1:0];
line_t                                  fifo_line           [`SENTRY_WIDTH-1:0];
line_t                                  cache_line          [`SENTRY_WIDTH-1:0];

// instructions read from instruction line
inst_t                                  instructions        [`SENTRY_WIDTH-1:0][15:0];
inst_t                                  cache_instructions  [`SENTRY_WIDTH-1:0][15:0];
inst_t                                  fifo_instructions   [`SENTRY_WIDTH-1:0][15:0];

// Issue queue ogic
addr_t                                  PC_reg              [`SENTRY_WIDTH-1:0];
addr_t                                  result_reg          [`SENTRY_WIDTH-1:0];
inst_t                                  instruction_reg     [`SENTRY_WIDTH-1:0];
reg  [`SENTRY_WIDTH-1:0]                inst_valid_reg;

// instruction FIFO
wire                                    inst_fifo_wr_en;
quad_inst_result_pc_s                   inst_fifo_input;
wire                                    inst_fifo_rd_en;
quad_inst_result_pc_s                   inst_fifo_output;
wire                                    inst_fifo_full;
wire                                    inst_fifo_empty;
wire                                    inst_fifo_almost_full;
wire                                    inst_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1 : 0]                inst_fifo_data_count;
`endif


// Instruction ready and pkt control
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
    // Cycle 0
    assign inst_ready[i] =  ctrl_inst_pkt1_fifo_empty[i]          ? 0 : // if pkt1 not ready, instruction not ready
                            !ctrl_inst_pkt1_fifo_output[i].mhb    ? 1 : // if miss, need to wait for pkt2 ready 
                            ctrl_inst_pkt2_fifo_empty[i]          ? 0 : 1;

    assign ctrl_inst_pkt1_fifo_rd_en[i]  = inst_frame_ready && inst_ready[i]; 
    assign ctrl_inst_pkt2_fifo_rd_en[i]  = inst_frame_ready && ctrl_inst_pkt1_fifo_output[i].mhb;
    `ifdef SMAC
        assign ctrl_inst_pkt3_fifo_rd_en[i]  = inst_frame_ready && (!ctrl_inst_pkt3_fifo_empty[i]);
    `endif

end
endgenerate

// on all ready of a frame of instruction, signal inst_frame_ready, but make sure issue queue is not full
// and perform cache read/write operations
assign inst_frame_ready = & inst_ready;

// Cache Read Hit Control
generate
if(`IWAYS == 2) begin : read_hit_2ways
    for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
        // Cycle 0
        assign rd_en[i]         =   ctrl_inst_pkt1_fifo_output[i].ens;
        assign rd_hit_way[i]    =   rd_en[i][0] ? 3'd0        :
                                    rd_en[i][1] ? 3'd1        :
                                    {3{1'b1}}   ; // all 1's for debug
    end
end
else if(`IWAYS == 4) begin : read_hit_4ways
    for (i=0; i<`SENTRY_WIDTH; i=i+1) begin
        // Cycle 0
        assign rd_en[i]         =   ctrl_inst_pkt1_fifo_output[i].ens;
        assign rd_hit_way[i]    =   rd_en[i][0] ? 3'd0        :
                                    rd_en[i][1] ? 3'd1        :
                                    rd_en[i][2] ? 3'd2        :
                                    rd_en[i][3] ? 3'd3        :
                                    {3{1'b1}}   ; // all 1's for debug
    end
end
endgenerate

// Line forwarding logic
generate
if(`SENTRY_WIDTH == 4) begin : line_forward_4parallel
    // Cycle 1
    always @(posedge clk) begin
        forward0to1 <= wr_index[0] == rd_index[1] && wr_en[0] == rd_en[1];
        forward0to2 <= wr_index[0] == rd_index[2] && wr_en[0] == rd_en[2];
        forward0to3 <= wr_index[0] == rd_index[3] && wr_en[0] == rd_en[3];
        forward1to2 <= wr_index[1] == rd_index[2] && wr_en[1] == rd_en[2];
        forward1to3 <= wr_index[1] == rd_index[3] && wr_en[1] == rd_en[3];
        forward2to3 <= wr_index[2] == rd_index[3] && wr_en[2] == rd_en[3];
    end
    // Cycle 1 (both fifo_line and cache_line are cycle 1 valid)
    assign actual_line[0]   =   pipe_mhb[0]   ? fifo_line[0]   : cache_line[0];

    assign actual_line[1]   =   pipe_mhb[1]   ? fifo_line[1]   : 
                                forward0to1   ? actual_line[0] : cache_line[1];

    assign actual_line[2]   =   pipe_mhb[2]   ? fifo_line[2]   : 
                                forward1to2   ? actual_line[1] :
                                forward0to2   ? actual_line[0] : cache_line[2];

    assign actual_line[3]   =   pipe_mhb[3]   ? fifo_line[3]   : 
                                forward2to3   ? actual_line[2] :
                                forward1to3   ? actual_line[1] :
                                forward0to3   ? actual_line[0] : cache_line[3];
end
endgenerate

// Delayed FIFO Input Line (Cycle 1)
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: delayed_fifo_line
    // Cycle 1
    always @(posedge clk) begin
        pipe_mhb[i]     <= ctrl_inst_pkt1_fifo_output[i].mhb;
        fifo_line[i]    <= ctrl_inst_pkt2_fifo_output[i].line;
    end
end
endgenerate


// Cache Control
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: inst_cache_line
    // Cycle 0
    assign wr_en[i]         = !inst_frame_ready ? 'd0 :
                            ctrl_inst_pkt1_fifo_output[i].mhb ? ctrl_inst_pkt1_fifo_output[i].ens : 'd0;    
    assign wr_index[i]      = ctrl_inst_pkt1_fifo_output[i].addr[`BYTE_OFFSET_WIDTH+:`I_INDEX_WIDTH];
    assign wr_line[i]       = ctrl_inst_pkt2_fifo_output[i].line;
    assign rd_index[i]      = ctrl_inst_pkt1_fifo_output[i].addr[`BYTE_OFFSET_WIDTH+:`I_INDEX_WIDTH];
    assign inst_offset[i]   = ctrl_inst_pkt1_fifo_output[i].addr[`BYTE_OFFSET_WIDTH-1:2];
    assign inst_result[i]   = ctrl_inst_pkt1_fifo_output[i].result;
    assign inst_PC[i]       = ctrl_inst_pkt1_fifo_output[i].addr;
    // Cycle 1
    assign cache_line[i]    = rd_line[i][rd_hit_way_reg[i]];
    assign instruction[i]   = instructions[i][inst_offset_reg[i]];
end
endgenerate

generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: inst_cache_line_offset
    always @(posedge clk) begin
        // Cycle 1
        rd_hit_way_reg[i]   <= rd_hit_way[i];
        inst_offset_reg[i]  <= inst_offset[i];
        // Cycle 1, this depends on when data becomes ready
        // does operand routing need to care about memory operation ordering? yes
        // does operand routing need to check issue queue full? yes
        inst_valid[i]       <= inst_frame_ready; 
        result[i]           <= inst_result[i];
        // Cycle 2, instruction FIFO input
        PC_reg[i]           <= inst_PC[i];
        result_reg[i]       <= result[i];
        instruction_reg[i]  <= instruction[i];
        inst_valid_reg[i]   <= inst_valid[i];
    end
end
endgenerate

generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: inst_fetch
    for(j = 0; j < 16; j=j+1) begin
        // Cycle 1
        assign cache_instructions[i][j] = cache_line[i][j*`INST_LEN+:`INST_LEN];
        assign fifo_instructions[i][j]  = fifo_line[i][j*`INST_LEN+:`INST_LEN];
        assign instructions[i][j]       = actual_line[i][j*`INST_LEN+:`INST_LEN];
    end
end
endgenerate

// pack and unpack parallel icache control data
generate
for (i=0; i<`IWAYS; i=i+1) begin: i_line_ram_control
    for (j=0; j<`SENTRY_WIDTH; j=j+1) begin
        //always @(*) begin
        //    // Cycle 1
        //    ram_wr_en[i][j]                                             = wr_en[j][i];
        //    ram_wr_index[i][(j+1)*`I_INDEX_WIDTH-1:j*`I_INDEX_WIDTH]    = wr_index[j];
        //    ram_wr_line[i][(j+1)*`LINE_WIDTH-1:j*`LINE_WIDTH]           = wr_line[j];
        //end
        always @(posedge clk) begin
            // Cycle 1
            ram_wr_en[i][j]                                             <= wr_en[j][i];
            //ram_wr_index[i][(j+1)*`I_INDEX_WIDTH-1:j*`I_INDEX_WIDTH]    <= wr_index[j];
            //ram_wr_line[i][(j+1)*`LINE_WIDTH-1:j*`LINE_WIDTH]           <= wr_line[j];
            ram_wr_index[i][j]      <= wr_index[j];
            ram_wr_line[i][j]       <= wr_line[j];
        end
        always @(*) begin
            // Cycle 0
            //ram_rd_index[i][(j+1)*`I_INDEX_WIDTH-1:j*`I_INDEX_WIDTH]    = rd_index[j];
            ram_rd_index[i][j]      = rd_index[j];
            // Cycle 1
            //rd_line[j][i]           = ram_rd_line[i][(j+1)*`LINE_WIDTH-1:j*`LINE_WIDTH];
            rd_line[j][i]           = ram_rd_line[i][j];
        end
    end
end
endgenerate


generate
for (i=0; i<`IWAYS; i=i+1) begin: i_line_ram
    // instantiate a multiported-RAM with binary-coded register-based LVT
    mpram   #(  
        .MEMD   (MEMD            ),  // memory depth
        .DATAW  (DATAW           ),  // data width
        .nRPORTS(nRPORTS         ),  // number of reading ports
        .nWPORTS(nWPORTS         ),  // number of writing ports
        .TYPE   ("LVTREG"        ),  // multi-port RAM implementation type
        .BYP    (BYP             ),  // Bypassing type: NON, WAW, RAW, RDW
        .IFILE  ("zero"          )  // initializtion file, optional
    )
    mpram_lvtreg_icache (  
        .clk    (clk                ),  // clock
        //.WEnb   (ram_wr_en[i]       ),  // write enable for each writing port                - in : [nWPORTS-1:0            ]
        //.WAddr  (ram_wr_index[i]    ),  // write addresses - packed from nWPORTS write ports - in : [`log2(MEMD)*nWPORTS-1:0]
        //.WData  (ram_wr_line[i]     ),  // write data      - packed from nRPORTS read  ports - out: [DATAW      *nWPORTS-1:0]
        //.RAddr  (ram_rd_index[i]    ),  // read  addresses - packed from nRPORTS read  ports - in : [`log2(MEMD)*nRPORTS-1:0]
        //.RData  (ram_rd_line[i]     )   // read  data      - packed from nRPORTS read  ports - out: [DATAW      *nRPORTS-1:0]
        .WEnb   ({ram_wr_en[i][3],ram_wr_en[i][2],ram_wr_en[i][1],ram_wr_en[i][0]}              ),
        .WAddr  ({ram_wr_index[i][3],ram_wr_index[i][2],ram_wr_index[i][1],ram_wr_index[i][0]}  ),
        .WData  ({ram_wr_line[i][3],ram_wr_line[i][2],ram_wr_line[i][1],ram_wr_line[i][0]}      ),
        .RAddr  ({ram_rd_index[i][3],ram_rd_index[i][2],ram_rd_index[i][1],ram_rd_index[i][0]}  ),
        .RData  ({ram_rd_line[i][3],ram_rd_line[i][2],ram_rd_line[i][1],ram_rd_line[i][0]}      )
    );

    //ram_4wide #(
    //    .ADDR_WIDTH (2),
    //    .DATA_WIDTH (512),
    //    .NPORTS     (4)
    //)
    //custom_ram_4wide(
    //    .clk                (clk                ),  // clock
    //    .wr_en              (ram_wr_en[i]       ),  // write enable for each writing port                - in : [nWPORTS-1:0            ]
    //    .wr_addr            (ram_wr_index[i]    ),  // write addresses - packed from nWPORTS write ports - in : [`log2(MEMD)*nWPORTS-1:0]
    //    .wr_data            (ram_wr_line[i]     ),  // write data      - packed from nRPORTS read  ports - out: [DATAW      *nWPORTS-1:0]
    //    .rd_addr            (ram_rd_index[i]    ),  // read  addresses - packed from nRPORTS read  ports - in : [`log2(MEMD)*nRPORTS-1:0]
    //    .rd_data            (ram_rd_line[i]     )   // read  data      - packed from nRPORTS read  ports - out: [DATAW      *nRPORTS-1:0]
    //);
end
endgenerate

// Cycle 2 issue queue fill
assign inst_fifo_wr_en  = & inst_valid_reg;

(*keep="true"*)inst_result_pc_t inst_result_pc_in [`SENTRY_WIDTH-1:0];

generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: instruction_fifo_in
    assign inst_result_pc_in[i].result  = result_reg[i];
    assign inst_result_pc_in[i].inst    = instruction_reg[i];
    assign inst_result_pc_in[i].PC      = PC_reg[i];
end
endgenerate

generate
if(`SENTRY_WIDTH == 4) begin
    assign inst_fifo_input.inst_result_pc0 = inst_result_pc_in[0];
    assign inst_fifo_input.inst_result_pc1 = inst_result_pc_in[1];
    assign inst_fifo_input.inst_result_pc2 = inst_result_pc_in[2];
    assign inst_fifo_input.inst_result_pc3 = inst_result_pc_in[3];
end
endgenerate

//******************************
// instruction FIFO
//******************************

inst_result_pc_fifo_sync INST_RESULT_PC_FIFO (
    .clk            (clk                    ),  // input wire wr_clk
    .din            (inst_fifo_input        ),  // input wire [639 : 0] din
    .wr_en          (inst_fifo_wr_en        ),  // input wire wr_en
    .rd_en          (inst_fifo_rd_en        ),  // input wire rd_en
    .dout           (inst_fifo_output       ),  // output wire [639 : 0] dout
    .full           (inst_fifo_full         ),  // output wire full
    .empty          (inst_fifo_empty        ),  // output wire empty
    .almost_full    (inst_fifo_almost_full  ),  // output wire full
    .almost_empty   (inst_fifo_almost_empty ),  // output wire empty
    `ifdef DATA_COUNT
        .data_count     (inst_fifo_data_count   ),  // output wire [9 : 0] data_count
    `endif
    .srst           (rst                    )   // input wire rst
);

//******************************
// Sink of instruction FIFO
//******************************
inst_result_pc_t inst_result_pcs [`SENTRY_WIDTH-1:0];

// Instruction Decode
reg_t                       rs1         [`SENTRY_WIDTH-1:0];
reg_t                       rs2         [`SENTRY_WIDTH-1:0];
reg_t                       rd          [`SENTRY_WIDTH-1:0];
data_t                      IMMI        [`SENTRY_WIDTH-1:0];
data_t                      IMMS        [`SENTRY_WIDTH-1:0];
wire [6:0]                  OPCODE      [`SENTRY_WIDTH-1:0];
wire [2:0]                  FUNCT3      [`SENTRY_WIDTH-1:0];
wire [6:0]                  FUNCT7      [`SENTRY_WIDTH-1:0];
wire [`SENTRY_WIDTH-1:0]    instruction_is_load;
wire [`SENTRY_WIDTH-1:0]    instruction_is_store;
wire [`SENTRY_WIDTH-1:0]    instruction_is_mem;
wire [`SENTRY_WIDTH-1:0]    instruction_is_jump;

// Data Access
addr_t                      data_address [`SENTRY_WIDTH-1:0];
reg  [`SENTRY_WIDTH-1:0]    data_access;
reg  [`SENTRY_WIDTH-1:0]    data_store;

// RegFile Interface
wire [`SENTRY_WIDTH-1:0]    reg_wr_en;
reg_t                       reg_wr_addr     [`SENTRY_WIDTH-1:0];
data_t                      reg_wr_data     [`SENTRY_WIDTH-1:0]; 
reg_t                       reg_rd_addr_a   [`SENTRY_WIDTH-1:0];
reg_t                       reg_rd_addr_b   [`SENTRY_WIDTH-1:0];
data_t                      reg_rd_data_a   [`SENTRY_WIDTH-1:0];
data_t                      reg_rd_data_b   [`SENTRY_WIDTH-1:0];

generate
if(`SENTRY_WIDTH == 4) begin
    assign inst_result_pcs[0] = inst_fifo_output.inst_result_pc0;
    assign inst_result_pcs[1] = inst_fifo_output.inst_result_pc1;
    assign inst_result_pcs[2] = inst_fifo_output.inst_result_pc2;
    assign inst_result_pcs[3] = inst_fifo_output.inst_result_pc3;
end
endgenerate

// propagate back pressure to trace fifo
reg trace_en_reg;
assign inst_fifo_rd_en = !inst_fifo_empty && !dcache_req_almost_full; 
always @(posedge clk) begin
    trace_en_reg <= inst_fifo_rd_en;
end

// data cache fetch
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: parallel_decode
    assign OPCODE[i]                = inst_result_pcs[i].inst[ 6: 0];
    assign FUNCT3[i]                = inst_result_pcs[i].inst[14:12];
    assign FUNCT7[i]                = inst_result_pcs[i].inst[31:25];
    assign rs1[i]                   = inst_result_pcs[i].inst[19:15];
    assign rs2[i]                   = inst_result_pcs[i].inst[24:20];
    assign rd[i]                    = inst_result_pcs[i].inst[11: 7];
    assign reg_rd_addr_a[i]         = rs1[i];
    assign reg_rd_addr_b[i]         = rs2[i];
    assign reg_wr_addr[i]           = rd[i];
    assign reg_wr_data[i]           = (inst_result_pcs[i].inst[6:0] == `RV32_JAL) || (inst_result_pcs[i].inst[6:0] == `RV32_JALR) ? 
                                        inst_result_pcs[i].PC + 4 : inst_result_pcs[i].result; // jal(r) writes pc+4 to rd
    assign instruction_is_load[i]   = (inst_result_pcs[i].inst[6:0] == `RV32_LOAD) || (inst_result_pcs[i].inst[6:0] == `RV_LOAD_UNT);
    assign instruction_is_store[i]  = (inst_result_pcs[i].inst[6:0] == `RV32_STORE) || (inst_result_pcs[i].inst[6:0] == `RV_STORE_UNT_NET && inst_result_pcs[i].inst[14:12] < 4);
    assign instruction_is_mem[i]    = instruction_is_load[i] || instruction_is_store[i];
    assign instruction_is_jump[i]   = (inst_result_pcs[i].inst[6:0] == `RV32_JAL) || (inst_result_pcs[i].inst[6:0] == `RV32_JALR) || (inst_result_pcs[i].inst[6:0] == `RV32_BRANCH);
    assign IMMI[i]                  = {{(`X_LEN-12){inst_result_pcs[i].inst[31]}}, inst_result_pcs[i].inst[31:20]}; 
    assign IMMS[i]                  = {{(`X_LEN-12){inst_result_pcs[i].inst[31]}}, inst_result_pcs[i].inst[31:25], inst_result_pcs[i].inst[11:7]};
    // register write does not happen until inst_result_pcs valid
    // otherwise subsequent inst_result_pcss in the pipe fram might overwrite earlier inst_result_pcs sources and cause memory address to be wrong
    assign reg_wr_en[i]             = inst_fifo_rd_en && ((OPCODE[i] == `RV32_LUI) || (OPCODE[i] == `RV32_AUIPC) || (OPCODE[i] == `RV32_JAL) || (OPCODE[i] == `RV32_JALR) 
                                    || (OPCODE[i] == `RV32_LOAD) || (OPCODE[i] == `RV_LOAD_UNT)
                                    || (OPCODE[i] == `RV_RECV_UNT) || ((OPCODE[i] == `RV_STORE_UNT_NET) && (FUNCT3[i] == `RV_FUNCT3_GET)) // NETWORK GET
                                    || (OPCODE[i] == `RV32_OP) || (OPCODE[i] == `RV32_OP_IMM) || (OPCODE[i] == `RV64_OP) || (OPCODE[i] == `RV64_OP_IMM));
end
endgenerate

//***************
// Register File
//***************
regFile_4wide SENTRYCONTROL_RF (
    .clk        (clk            ),
    .rst        (rst            ),
    .wr_en      (reg_wr_en      ),
    .wr_addr    (reg_wr_addr    ),
    .wr_data    (reg_wr_data    ),
    .rd_addr_a  (reg_rd_addr_a  ),
    .rd_addr_b  (reg_rd_addr_b  ),
    .rd_data_a  (reg_rd_data_a  ),
    .rd_data_b  (reg_rd_data_b  )
);

// Dcache Request  (Cycle 1)
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: parallel_data_address
    always @(posedge clk) begin
        data_address[i] <= instruction_is_load[i] ? reg_rd_data_a[i] + IMMI[i] : reg_rd_data_a[i] + IMMS[i];
        data_access[i]  <= instruction_is_mem[i];
        data_store[i]   <= instruction_is_store[i];
    end
end
endgenerate

// Cycle 1
generate
for (i=0; i<`SENTRY_WIDTH; i=i+1) begin: dcache_control
    assign dcache_req_address[i]    = data_address[i];
    assign dcache_req_valid[i]      = trace_en_reg && data_access[i];
    assign dcache_req_store[i]      = trace_en_reg && data_store[i];
    assign dcache_inst_valid[i]     = trace_en_reg;
end
endgenerate


endmodule

