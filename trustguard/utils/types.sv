`include "parameters.svh"

//`define PACKET_WIDTH            `OP_WIDTH + `MHB_WIDTH + `WAY_WIDTH + `ADDR_WIDTH + `LINE_WIDTH + `SMAC_WIDTH
//`define EVICT_PACKET_WIDTH      `ADDRCNT_WIDTH+`LINE_WIDTH+`SMAC_WIDTH
//`define COMB_CNT_WIDTH          80
//`define MAJOR_CNT_WIDTH         64
//`define MINOR_CNT_WIDTH         14


package TYPES;

typedef enum {
    S_INIT, 
    // instruction cache verification
    S_INST, S_INST_PARSE, S_INST_FIN, 
    S_INST_COUNTER, S_INST_SMAC_REQ, S_INST_COUNTER_HASH_REQ, S_INST_COUNTER_CACHE_WAIT,
    S_INST_VERI, S_INST_VERI_HASH_REQ, S_INST_VERI_CACHE_WAIT, 
    S_INST_VERI_DONE,
    // data cache verification
    S_DATA, S_DATA_CACHE_WAIT, 
    S_DATA_COUNTER, S_DATA_SMAC_REQ, S_DATA_COUNTER_HASH_REQ, S_DATA_COUNTER_CACHE_WAIT,
    S_DATA_VERI, S_DATA_VERI_HASH_REQ, S_DATA_VERI_CACHE_WAIT, 
    S_DATA_VERI_DONE,
    S_DATA_EVICT, S_DATA_EVICT_COUNTER, S_DATA_STACK_POP,
    // others
    S_ROOT, S_RESULT, 
    S_LOAD_UPDATE_PRE, S_LOAD_UPDATE,
    S_COMPARE, S_VICTIM_MOD_PRE, S_VICTIM_MOD_PRE1, S_VICTIM_MOD,
    S_VICTIM_MOD_DATA, S_VICTIM_MOD_HASH, S_ALERT
} s_state_e;

typedef enum {
    S_CACHE_INIT, 
    S_CHECK_EVICT,
    S_CACHE_READ_BEFORE_WRITE,
    S_CACHE_WRITE
} c_state_e;

typedef logic [32-`SENTRY_WIDTH-1:0]        din_t;
typedef logic [`CAM_ADDR_WIDTH-1:0]         vindex_t;
typedef logic [`WAYS-1:0]                   en_t;
typedef logic [`OP_WIDTH-1:0]               op_t;
typedef logic [`MHB_WIDTH-1:0]              mhb_t;
typedef logic [`WAY_WIDTH-1:0]              way_t;
typedef logic [`ADDR_WIDTH-1:0]             addr_t;
typedef logic [`LINE_WIDTH-1:0]             line_t;
typedef logic [`LINE_WIDTH_BYTE-1:0]        line_byte_t;
//typedef struct packed {
//    logic [15:0] [31:0] words;
//} line_t;
typedef logic [`SMAC_WIDTH-1:0]             smac_t;
typedef logic [`X_LEN-1:0]                  data_t;
typedef logic [`INST_LEN-1:0]               inst_t;
typedef logic [`REG_ADDR_WIDTH-1:0]         reg_t;
typedef logic [`BYTE_OFFSET_WIDTH-1:0]      offset_t;
typedef logic [`EVICT_MEM_ADDR_WIDTH-1:0]   victim_ptr_t;

//typedef logic [31:0]            tag_t;
typedef struct packed {
    din_t                       number;
    logic [`SENTRY_WIDTH-1:0]   rotate;
} tag_t;

// checking stage
typedef struct packed {
    tag_t   tag;
    data_t  result;
} tag_result_t;

// icache request fifo
typedef struct packed {
    addr_t  addr;
    data_t  result;
} addr_result_t;

// lsu request fifo
typedef struct packed {
    inst_t  instruction;
    tag_t   tag;
    addr_t  addr;
    data_t  data;
} lsu_req_t;

typedef struct packed {
    // Control Logic (32 + 6 = 38 bits)
    tag_t                           tag;
    logic  [1:0]                    fill_source;
    logic                           inst_is_load;
    logic                           inst_is_store;
    logic  [2:0]                    FUNCT3;
    // DCache Controls (4 + 4 + 64 + 64 + 512 = 648 bits)
    en_t                            cache_ens;
    en_t                            cache_evicts;
    vindex_t                        victim_cam_index;
    addr_t                          cache_address;
    line_byte_t                     cache_wr_en_byte;
    line_t                          cache_wr_line;
    // Victim CAM Lookup
    // dummy filler bits to check cache_address
    logic [1:0]                     dummy;
    // DCache Fill Victim CAM Line Select (to FIFO) (6 bits)
    logic                           byte_sel;
    logic                           hword_sel;
    logic                           word_sel;
    logic                           dword_sel;
    logic  [1:0]                    qword_sel;
    // DCache Fill Victim CAM Line Enable (to FIFO) (4 bits)
    logic                           byte_write;
    logic                           hword_write;
    logic                           word_write;
    logic                           dword_write;
    // DCache Fill Victim CAM Line Data (to FIFO) (120 bits)
    logic  [7:0]                    write_byte;
    logic  [15:0]                   write_hword;
    logic  [31:0]                   write_word;
    logic  [63:0]                   write_dword;
} dcache_ctrl_req_t;
// 768 bits

typedef struct packed {
    //op_t        op;
    mhb_t       mhb;
    en_t        ens;
    en_t        evict;
    vindex_t    vidx;
    tag_t       tag;
    addr_t      addr;
    data_t      result;
} pkt1_t; // 32 + 5 + 1 + 4 + 4 + 64 + 64 = 174 bits
// packet type 1, cache control info

typedef struct packed {
    tag_t   tag;
    `ifdef TAG_ADDR_DEBUG
        addr_t  addr;
    `endif
    line_t  line;
} pkt2_t; // 32 + 512 = 544 bits
// packet type 2, cache data

typedef struct packed {
    tag_t   tag;
    smac_t  smac;
} pkt3_t; // 32 + 128 = 160 bits
// packet type 3, cache smac metadata

typedef struct packed {
    tag_t       tag;
    mhb_t       mhb;
    vindex_t    vidx;
} vpkt_t;// vicitim packet format

typedef struct packed {
    logic       is_mem;
    tag_t       tag;
    addr_t      PC;
    inst_t      instruction;
    data_t      result;
} issue_t; // issue to RICU format

typedef struct packed {
    line_t  line;
    smac_t smac;
} victim_data_t; // 512 + 128 = 640 bits

typedef struct packed {
    tag_t   tag;
    addr_t  addr;
} mem_req_t;  // 32 + 64 = 96 bits

typedef struct packed {
    logic [127:0] p1;
    logic [127:0] p2;
    logic [127:0] p3;
    logic [127:0] p4;
} line_encoding1;

typedef union packed {
    line_t raw;
    line_encoding1 encoding1;
} line_u;

typedef struct packed {
    inst_t  inst;
    data_t  result;
    addr_t  PC;
} inst_result_pc_t;

typedef struct packed {
    inst_result_pc_t inst_result_pc0;
    inst_result_pc_t inst_result_pc1;
    inst_result_pc_t inst_result_pc2;
    inst_result_pc_t inst_result_pc3;
} quad_inst_result_pc_s;

typedef struct packed {
    logic [31:0] din;
    inst_t  instruction;
    data_t  result;
} trace_s;

typedef struct packed {
    trace_s trace0;
    trace_s trace1;
    trace_s trace2;
    trace_s trace3;
} quad_trace_s;

typedef struct packed {
    logic jump_flag;
    data_t  result;
} jump_result_s;

typedef struct packed {
    jump_result_s jump_result0;
    jump_result_s jump_result1;
    jump_result_s jump_result2;
    jump_result_s jump_result3;
    jump_result_s jump_result4;
    jump_result_s jump_result5;
    jump_result_s jump_result6;
    jump_result_s jump_result7;
} oct_jump_result_s;

typedef struct packed {
    jump_result_s jump_result0;
    jump_result_s jump_result1;
    jump_result_s jump_result2;
    jump_result_s jump_result3;
} quad_jump_result_s;

typedef struct packed {
    op_t    op;
    mhb_t   mhb;
    way_t   way;
    addr_t  addr;
    line_u  line;
    smac_t  smac;
} trace_packet_encoding1;

typedef struct packed {
    op_t    op;
    mhb_t   mhb;
    way_t   way;
    data_t  result;
    logic [64-1-`EVICT_MEM_ADDR_WIDTH:0]    padding1;
    victim_ptr_t  victim_ptr;
    logic [`LINE_WIDTH+`SMAC_WIDTH-64-1:0]  padding2;
} trace_packet_encoding2;


typedef union packed {
    logic [`PACKET_WIDTH-1:0] raw;
    trace_packet_encoding1 encoding1;
    trace_packet_encoding2 encoding2;
} trace_packet_u;

typedef logic [`MAJOR_CNT_WIDTH-1:0] major_cnt_t;
typedef logic [`MINOR_CNT_WIDTH-1:0] minor_cnt_t;

typedef struct packed {
    major_cnt_t major_cnt;
    logic [1:0] padding;
    minor_cnt_t minor_cnt;
} comb_cnt_s;

typedef struct packed {
    addr_t addr;
    comb_cnt_s comb_cnt;
} addrcnt_s;

typedef struct packed {
    line_u  line;
    smac_t  smac;
} evict_data_s;

typedef struct packed {
    addrcnt_s addrcnt;
    line_u  line;
    smac_t  smac;
} evict_packet_s;

typedef struct packed {
    s_state_e   state;
    addr_t      addr;
    line_u      data;
    smac_t      smac;
} evict_stack_s;

endpackage : TYPES
