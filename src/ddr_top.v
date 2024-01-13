
`include "../config/config_ddr.v"

module ddr_sdram_ctrl (
    input  wire                                           io_clk, 
    input  wire                                           io_clk_rstn,
	
    output reg                                            core_clk_rstn,
    output reg                                            core_clk,

    input  wire                                           awvalid,
    output wire                                           awready,
    input  wire  [BA_BITS+ROW_BITS+COL_BITS+DQ_LEVEL-2:0] awaddr,  
    input  wire                                    [ 7:0] awlen,
    input  wire                                           wvalid,
    output wire                                           wready,
    input  wire                                           wlast,
    input  wire                       [(8<<DQ_LEVEL)-1:0] wdata,
    output wire                                           bvalid,
    input  wire                                           bready,
    input  wire                                           arvalid,
    output wire                                           arready,
    input  wire  [BA_BITS+ROW_BITS+COL_BITS+DQ_LEVEL-2:0] araddr,   
    input  wire                                    [ 7:0] arlen,
    output wire                                           rvalid,
    input  wire                                           rready,
    output wire                                           rlast,
    output wire                       [(8<<DQ_LEVEL)-1:0] rdata,

    output wire                                           ddr_ck_p, ddr_ck_n,  
    output wire                                           ddr_cke,
    output reg                                            ddr_cs_n,
    output reg                                            ddr_ras_n,
    output reg                                            ddr_cas_n,
    output reg                                            ddr_we_n,
    output reg                  [            BA_BITS-1:0] ddr_ba,
    output reg                  [           ROW_BITS-1:0] ddr_a,
    output wire                 [((1<<DQ_LEVEL)+1)/2-1:0] ddr_dm,
    inout                       [((1<<DQ_LEVEL)+1)/2-1:0] ddr_dqs,
    inout                       [      (4<<DQ_LEVEL)-1:0] ddr_dq    
);
















endmodule