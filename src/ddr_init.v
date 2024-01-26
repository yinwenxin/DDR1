`ifndef CONFIG_DDR
`define CONFIG_DDR
`include "../config/define_ddr.v"
`include "../config/config_ddr.v"
`endif

module ddr_init (
    input  wire                                           core_clk, 
    input  wire                                           core_rstn_sync,

    output reg                                            init_done,
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