`ifndef _parameter_svh_
`define _parameter_svh_

`define TAG_ADDR_DEBUG 1
//`define SIMULATION 1
`define DDR_BASE_ADDR 32'h40000000
`define MK         1
`define DATA_COUNT 1
`define QCNT_WIDTH 9

//`define HMAC                    1
//`define SMAC                    1
`define SENTRY                  1
`define SENTRY_WIDTH            4
`define AXI_TRACE               1
`define PARALLEL_ICACHE         1
//`define DCACHE_OPT              1

`define CAM_ADDR_WIDTH          5 // can go up to 8 bits

`define PCIE_LEN                32
`define DMA_ADDR_WIDTH          16 
`define DMA_LEN                 256

// pipeline related parameters
`define INST_LEN                32
`define X_LEN                   64
`define LOWBITS                 32
`define DOUBLE_X_LEN            128
`define QUAD_X_LEN              256
`define LOG2_X_LEN              6
`define ADDR_WIDTH              64  //`X_LEN

`define NET_ADDR_WIDTH          8
`define NET_DEPTH               256 //(1 << `NET_ADDR_WIDTH)
`define MEM_WIDTH               96  //(`INST_LEN + `X_LEN)
`define MEM_ADDR_WIDTH          8
`define MEM_DEPTH               256 //(1 << `MEM_ADDR_WIDTH)
`define REG_ADDR_WIDTH          5
`define REG_DEPTH               32  //(1 << `REG_ADDR_WIDTH)

`define EVICT_MEM_ADDR_WIDTH    6
`define EVICT_MEM_DEPTH         64  //(1 << `EVICT_MEM_ADDR_WIDTH)

`define EVICT_STACK_ADDR_WIDTH  3
`define EVICT_STACK_DEPTH       8   //(1 << `EVICT_STACK_ADDR_WIDTH)

`define SHAMT_WIDTH             6

// cache stuff
`ifdef SENTRY
  `define ICACHE_SIZE           1024    //1*1024
  //`define DCACHE_SIZE           1024    //1*1024
  `define DCACHE_SIZE           4096    //4*1024
  //`define DCACHE_SIZE           8192    //4*1024
  `define MCACHE_SIZE           4096    //4*1024
`else
  `define ICACHE_SIZE           16384   //16*1024
  `define DCACHE_SIZE           16384   //16*1024
  `define MCACHE_SIZE           16384   //16*1024
`endif

`define LINE_WIDTH              512 
`define LINE_WIDTH_BYTE         64  //`LINE_WIDTH/8
`define BYTE_OFFSET_WIDTH       6   //log2(`LINE_WIDTH_BYTE)
`define SMAC_START              32'h10000
`define SMAC_WIDTH              128
`define SMAC_WIDTH_BYTE         16  //`SMAC_WIDTH/8
`define SMAC_OFFSET_WIDTH       4   //log2(`SMAC_WIDTH_BYTE)

//`define LINES `CACHE_SIZE/`LINE_WIDTH_BYTE
`define ILINES                  16  //`ICACHE_SIZE/`LINE_WIDTH_BYTE
//`define DLINES                  16  //`DCACHE_SIZE/`LINE_WIDTH_BYTE
`define DLINES                  64  //`DCACHE_SIZE/`LINE_WIDTH_BYTE
//`define DLINES                  128 //`DCACHE_SIZE/`LINE_WIDTH_BYTE
`define MLINES                  64  //`MCACHE_SIZE/`LINE_WIDTH_BYTE

//`define WAYS 1
`define WAYS                    4
`define IWAYS                   4
`define DWAYS                   4
//`define WAYS                    2
//`define IWAYS                   2
//`define DWAYS                   2
`define MWAYS                   2

//`define SETS `LINES/`WAYS
`define ISETS                   4   //`ILINES/`IWAYS
//`define DSETS                   4   //`DLINES/`DWAYS
//`define DSETS                   16  //`DLINES/`DWAYS
`define DSETS                   32  //`DLINES/`DWAYS
`define MSETS                   32  //`MLINES/`MWAYS


`ifdef SENTRY
  //`define INDEX_WIDTH 4 //log2(`SETS)
  `define I_INDEX_WIDTH          2 //log2(`ISETS)
  //`define D_INDEX_WIDTH          2 //log2(`ISETS)
  `define D_INDEX_WIDTH          4 //log2(`ISETS)
  //`define D_INDEX_WIDTH          5 //log2(`ISETS)
  `define M_INDEX_WIDTH          5 //log2(`ISETS)
`else
  //`define INDEX_WIDTH 6 //log2(`SETS)
  `define I_INDEX_WIDTH          6 //log2(`SETS)
  `define D_INDEX_WIDTH          6 //log2(`SETS)
  `define M_INDEX_WIDTH          6 //log2(`SETS)
`endif

//`define TAG_WIDTH `ADDR_WIDTH-`INDEX_WIDTH-`BYTE_OFFSET_WIDTH
`define I_TAG_WIDTH             56  //`ADDR_WIDTH-`I_INDEX_WIDTH-`BYTE_OFFSET_WIDTH
//`define D_TAG_WIDTH             56  //`ADDR_WIDTH-`D_INDEX_WIDTH-`BYTE_OFFSET_WIDTH
`define D_TAG_WIDTH             54  //`ADDR_WIDTH-`D_INDEX_WIDTH-`BYTE_OFFSET_WIDTH
//`define D_TAG_WIDTH             53  //`ADDR_WIDTH-`D_INDEX_WIDTH-`BYTE_OFFSET_WIDTH
//`define MTAG_WIDTH             `ADDR_WIDTH-`MINDEX_WIDTH-`BYTE_OFFSET_WIDTH
`define M_TAG_WIDTH             58  //`ADDR_WIDTH-`BYTE_OFFSET_WIDTH

`define I_DTAG_WIDTH            57  //`I_TAG_WIDTH+1 // itag + dirty bit
//`define D_DTAG_WIDTH            57  //`D_TAG_WIDTH+1 // dtag + dirty bit
`define D_DTAG_WIDTH            55  //`D_TAG_WIDTH+1 // dtag + dirty bit
//`define D_DTAG_WIDTH            54  //`D_TAG_WIDTH+1 // dtag + dirty bit
`define M_DTAG_WIDTH            59  //`M_TAG_WIDTH+1 // mtag + dirty bit

`define I_VDTAG_WIDTH           58  //`I_DTAG_WIDTH+1 // itag + dirty bit + valid bit
//`define D_VDTAG_WIDTH           58  //`D_DTAG_WIDTH+1 // dtag + dirty bit + valid bit
`define D_VDTAG_WIDTH           56  //`D_DTAG_WIDTH+1 // dtag + dirty bit + valid bit
//`define D_VDTAG_WIDTH           55  //`D_DTAG_WIDTH+1 // dtag + dirty bit + valid bit
`define M_VDTAG_WIDTH           60  //`M_DTAG_WIDTH+1 // mtag + dirty bit + valid bit

// merkle tree stuff below
`define OP_WIDTH                4
`define MHB_WIDTH               1 //hit miss bit
`define WAY_WIDTH               3 //way information, enough for 8-way set associative

// packet opcodes
`define OP_INST                 3
`define OP_DATA                 4
`define OP_DATA_EVICT           6
`define OP_RESULT               7
`define OP_META                 1
`define OP_META_EVICT           8
`define OP_LOADUPDATE           2
`define OP_LOADUPDATE_EVICT     10
`define OP_VICTIM               5 // for metadata update in victim buffer, causes hash update

`define ADDRCNT_WIDTH           144
//`define CNT_WIDTH 16
`define COMB_CNT_WIDTH          80
`define MAJOR_CNT_WIDTH         64
`define MINOR_CNT_WIDTH         14
`define SEGMENT_WIDTH           56

// 4 + 4 + 64 + 512 + 128 = 712
`define PACKET_WIDTH            712 //`OP_WIDTH + `MHB_WIDTH + `WAY_WIDTH + `ADDR_WIDTH + `LINE_WIDTH + `SMAC_WIDTH
`define EVICT_PACKET_WIDTH      784 //`ADDRCNT_WIDTH+`LINE_WIDTH+`SMAC_WIDTH

//fib
//`define START_PC `X_LEN'h598

//fac
//`define START_PC                `X_LEN'h700// start pc for for factorial benchmark

//redis
`define START_PC                `X_LEN'h7528// start pc for for redis benchmark v1 without net put/get

`define ROOT                    128'h52c011d73aebb1c9a74e033b45882cd9   // root for redis benchmark
`define BLOCKS_WIDTH            32          // hash engine block width
`define ROOT_ADDR               64'h10aaae000
`define LAST_LEVEL_ADDR         64'h10aaad000

`endif
