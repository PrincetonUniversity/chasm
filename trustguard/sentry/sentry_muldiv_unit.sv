// Multiply/Divide Unit Wrapper, configurable between pipelined and non-pipelined
`include "parameters.svh"
`include "muldiv_ops.svh"
import TYPES::*;

module sentry_muldiv_unit (
    input  logic                            clk,
    input  logic                            rst,
    input  logic                            req,
    input  logic  [`MD_OP_WIDTH-1:0]        req_op,
    input  logic                            req_srclow,
    input  logic                            req_src1_signed,
    input  logic                            req_src2_signed,
    input  data_t                           req_src1,
    input  data_t                           req_src2,
    input  logic [`MD_OUT_SEL_WIDTH-1:0]    req_out_sel,
    output logic                            ready,
    output logic                            done,
    output data_t                           out
);

`ifdef MULDIV_PIPE
    sentry_muldiv_pipe DUT (
        .clk                            (clk                        ),
        .req                            (req                        ),
        .req_op                         (req_op                     ),
        .req_srclow                     (req_srclow                 ),
        .req_src1_signed                (req_src1_signed            ),
        .req_src2_signed                (req_src2_signed            ),
        .req_src1                       (req_src1                   ),
        .req_src2                       (req_src2                   ),
        .req_out_sel                    (req_out_sel                ),
        .done                           (done                       ),
        .out                            (out                        )
    );
    assign ready = 1;
`else

    // a request fifo to queue up muldiv request
    // needs a way to apply back pressure to operand routing stage

    // Muldiv Unit request fifo
    // length: 64 + 64 + 2 + 2 + 1 + 1 + 1 = 135
    wire                            md_req_fifo_wr_en;
    wire [134:0]                    md_req_fifo_input;
    wire                            md_req_fifo_rd_en;
    wire [134:0]                    md_req_fifo_output;
    wire                            md_req_fifo_full;
    wire                            md_req_fifo_empty;
    wire                            md_req_fifo_almost_full;
    wire                            md_req_fifo_almost_empty;
    `ifdef DATA_COUNT
        wire [`QCNT_WIDTH-1 : 0]        md_req_fifo_data_count;
    `endif

    wire                            internal_req;
    wire [`MD_OP_WIDTH-1:0]         internal_req_op;
    wire                            internal_req_srclow;
    wire                            internal_req_src1_signed;
    wire                            internal_req_src2_signed;
    data_t                          internal_req_src1;
    data_t                          internal_req_src2;
    wire [`MD_OUT_SEL_WIDTH-1:0]    internal_req_out_sel;
    wire                            internal_ready;
    wire                            internal_done;
    data_t                          internal_out;

    assign md_req_fifo_input = {req_op, req_srclow, req_src1_signed, req_src2_signed, req_src1, req_src2, req_out_sel};
    assign {internal_req_op, internal_req_srclow, internal_req_src1_signed, internal_req_src2_signed, internal_req_src1, internal_req_src2, internal_req_out_sel} = md_req_fifo_output;
    assign internal_req = !md_req_fifo_empty && internal_ready;
    assign ready = !md_req_fifo_almost_full;
    assign md_req_fifo_wr_en = req;
    assign md_req_fifo_rd_en = internal_req;

    md_req_fifo MULDIV_REQ_FIFO (
        .clk            (clk                        ),  // input wire wr_clk
        .din            (md_req_fifo_input          ),  // input wire [134 : 0] din
        .wr_en          (md_req_fifo_wr_en          ),  // input wire wr_en
        .rd_en          (md_req_fifo_rd_en          ),  // input wire rd_en
        .dout           (md_req_fifo_output         ),  // output wire [134 : 0] dout
        .full           (md_req_fifo_full           ),  // output wire full
        .empty          (md_req_fifo_empty          ),  // output wire empty
        .almost_full    (md_req_fifo_almost_full    ),  // output wire full
        .almost_empty   (md_req_fifo_almost_empty   ),  // output wire empty
        `ifdef DATA_COUNT
            .data_count     (md_req_fifo_data_count     ),  // output wire [9 : 0] data_count
        `endif
        .srst           (rst                        )   // input wire rst
    );

    sentry_muldiv MD_CORE (
        .clk                            (clk                            ),
        .rst                            (rst                            ),
        .req                            (internal_req                   ),
        .req_op                         (internal_req_op                ),
        .req_srclow                     (internal_req_srclow            ),
        .req_src1_signed                (internal_req_src1_signed       ),
        .req_src2_signed                (internal_req_src2_signed       ),
        .req_src1                       (internal_req_src1              ),
        .req_src2                       (internal_req_src2              ),
        .req_out_sel                    (internal_req_out_sel           ),
        .ready                          (internal_ready                 ),
        .done                           (internal_done                  ),
        .out                            (internal_out                   )
    );

    assign done = internal_done;
    assign out = internal_out;

`endif


endmodule

