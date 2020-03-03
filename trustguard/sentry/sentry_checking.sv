// Checking Stage
`include "parameters.svh"
import TYPES::*;

module sentry_checking(
    // Add a no check bypass for store instructions?
    // Incoming Untrusted Host Result
    input  logic    result_select,
    input  data_t   host_result,
    input  tag_t    host_tag,
    // Incoming Function Unit Result
    input  logic    fu_ready,
    input  data_t   fu_result,
    // Outgoing Checked Correct Tag
    output tag_t    tag,
    output logic    tag_valid,
    input  logic    tag_clear,
    // Invalid and Alert signals
    output logic    invalid,
    output logic    ready,
    // clock and reset
    input           clk,
    input           rst
);

// Host Tag and Result FIFO Interface
wire            tag_result_fifo_wr_en;
tag_result_t    tag_result_fifo_input;
wire            tag_result_fifo_rd_en;
(*keep="true"*)tag_result_t    tag_result_fifo_output;
wire            tag_result_fifo_full;
wire            tag_result_fifo_empty;
wire            tag_result_fifo_almost_full;
wire            tag_result_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1:0]  tag_result_fifo_data_count;
`endif

// Functional Unit Result FIFO Interface
wire            fu_result_fifo_wr_en;
data_t          fu_result_fifo_input;
wire            fu_result_fifo_rd_en;
(*keep="true"*)data_t          fu_result_fifo_output;
wire            fu_result_fifo_full;
wire            fu_result_fifo_empty;
wire            fu_result_fifo_almost_full;
wire            fu_result_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1:0]  fu_result_fifo_data_count;
`endif

// Output Tag FIFO Interface
wire            tag_fifo_wr_en;
tag_t           tag_fifo_input;
wire            tag_fifo_rd_en;
tag_t           tag_fifo_output;
wire            tag_fifo_full;
wire            tag_fifo_empty;
wire            tag_fifo_almost_full;
wire            tag_fifo_almost_empty;
`ifdef DATA_COUNT
    wire [`QCNT_WIDTH-1:0]  tag_fifo_data_count;
`endif

(*keep="true"*)wire inputs_ready;
wire checking_almost_full;

// Host Tag Result FIFO Control
assign tag_result_fifo_input.tag    = host_tag;
assign tag_result_fifo_input.result = host_result;
assign tag_result_fifo_wr_en        = result_select;
assign tag_result_fifo_rd_en        = inputs_ready;

// Host Result FIFO Control
assign fu_result_fifo_input         = fu_result;
assign fu_result_fifo_wr_en         = fu_ready;
assign fu_result_fifo_rd_en         = inputs_ready;

// Host Tag Result FIFO
tag_result_fifo TAG_RESULT_FIFO (
    .clk            (clk                            ),  // input wire clk
    .din            (tag_result_fifo_input          ),  // input wire [95 : 0] din
    .wr_en          (tag_result_fifo_wr_en          ),  // input wire wr_en
    .rd_en          (tag_result_fifo_rd_en          ),  // input wire rd_en
    .dout           (tag_result_fifo_output         ),  // output wire [95 : 0] dout
    .full           (tag_result_fifo_full           ),  // output wire full
    .empty          (tag_result_fifo_empty          ),  // output wire empty
    .almost_full    (tag_result_fifo_almost_full    ),  // output wire almost_full
    .almost_empty   (tag_result_fifo_almost_empty   ),  // output wire almost_empty
    `ifdef DATA_COUNT
        .data_count     (tag_result_fifo_data_count     ),  // output wire [9 : 0] data_count
    `endif
    .srst           (rst                        )   // input wire srst
);

// Host Result FIFO
result_fifo_sync FU_RESULT_FIFO (
    .clk            (clk                            ),  // input wire clk
    .din            (fu_result_fifo_input           ),  // input wire [95 : 0] din
    .wr_en          (fu_result_fifo_wr_en           ),  // input wire wr_en
    .rd_en          (fu_result_fifo_rd_en           ),  // input wire rd_en
    .dout           (fu_result_fifo_output          ),  // output wire [95 : 0] dout
    .full           (fu_result_fifo_full            ),  // output wire full
    .empty          (fu_result_fifo_empty           ),  // output wire empty
    .almost_full    (fu_result_fifo_almost_full     ),  // output wire almost_full
    .almost_empty   (fu_result_fifo_almost_empty    ),  // output wire almost_empty
    `ifdef DATA_COUNT
        .data_count     (fu_result_fifo_data_count      ),  // output wire [9 : 0] data_count
    `endif
    .srst           (rst                        )   // input wire srst
);

assign inputs_ready = (!tag_result_fifo_empty) && (!fu_result_fifo_empty) && (!tag_fifo_almost_full);
assign tag_fifo_input = tag_result_fifo_output.tag;
assign tag_fifo_wr_en = inputs_ready && (tag_result_fifo_output.result == fu_result_fifo_output);

// Tag FIFO
tag_fifo  TAG_FIFO (
    .clk            (clk                            ),  // input wire clk
    .din            (tag_fifo_input                 ),  // input wire [31 : 0] din
    .wr_en          (tag_fifo_wr_en                 ),  // input wire wr_en
    .rd_en          (tag_fifo_rd_en                 ),  // input wire rd_en
    .dout           (tag_fifo_output                ),  // output wire [31 : 0] dout
    .full           (tag_fifo_full                  ),  // output wire full
    .empty          (tag_fifo_empty                 ),  // output wire empty
    .almost_full    (tag_fifo_almost_full           ),  // output wire almost_full
    .almost_empty   (tag_fifo_almost_empty          ),  // output wire almost_empty
    `ifdef DATA_COUNT
        .data_count     (tag_fifo_data_count            ),  // output wire [9 : 0] data_count
    `endif
    .srst           (rst                        )   // input wire srst
);

// in checking module, the outgoing checked tag fifo properly back pressures the incoming host and sentry result fifos
// so if either of the incoming fifos are almost filled up, we need to trigger stall to operand routing
assign checking_almost_full = (|tag_result_fifo_almost_full) || (|fu_result_fifo_almost_full);
assign ready = !checking_almost_full;
assign invalid = (!tag_result_fifo_empty) && (!fu_result_fifo_empty) && (tag_result_fifo_output.result != fu_result_fifo_output);

assign tag = tag_fifo_output;
assign tag_valid = !tag_fifo_empty;
assign tag_fifo_rd_en = tag_clear;

endmodule
