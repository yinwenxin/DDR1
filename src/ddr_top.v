`ifndef DEFINE_DDR
`define DEFINE_DDR
`include "./config/config_ddr.v"
`include "./config/define_ddr.v"
`endif



module ddr_top (
//clock and reset
    input  wire                                           sys_clk, 
    input  wire                                           sys_rstn_async,
    output reg                                            core_rstn_sync,
    output reg                                            core_clk,

//AXI interface
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

//ddr pin
    output wire                                           ddr_ck_p, ddr_ck_n,  
    output wire                                           ddr_cke,
    output wire                                           ddr_cs_n,
    output wire                                           ddr_ras_n,
    output wire                                           ddr_cas_n,
    output wire                                           ddr_we_n,
    output wire                 [            BA_BITS-1:0] ddr_ba,
    output wire                 [           ROW_BITS-1:0] ddr_a,
    output wire                 [((1<<DQ_LEVEL)+1)/2-1:0] ddr_dm,
    inout                       [((1<<DQ_LEVEL)+1)/2-1:0] ddr_dqs,
    inout                       [      (4<<DQ_LEVEL)-1:0] ddr_dq    
);

//complementary clock
assign  ddr_ck_p = ~ core_clk;
assign  ddr_ck_n =   core_clk;
//clock enable
assign  ddr_cke  = ~ ddr_cs_n;

//initialize part
wire    init_done;
wire    init_ddr_cs_n, init_ddr_ras_n, init_ddr_cas_n, init_ddr_we_n;
wire    [     BA_BITS-1:0] init_ddr_ba;
wire    [    ROW_BITS-1:0] init_ddr_a;

ddr_init ddr_init_u0(
                        .core_clk               (core_clk                   ),
                        .core_rstn_sync         (core_rstn_sync             ),
                        .init_done              (init_done                  ),

                        .ddr_cs_n               (init_ddr_cs_n              ),
                        .ddr_ras_n              (init_ddr_ras_n             ),
                        .ddr_cas_n              (init_ddr_cas_n             ),
                        .ddr_we_n               (init_ddr_we_n              ),
                        .ddr_ba                 (init_ddr_ba                ),
                        .ddr_a                  (init_ddr_a                 )

);

wire    sys_rstn_sync, sys_clk_div2;


//clock and reset part
ddr_clock_reset ddr_clock_reset_u0(
                        .sys_clk                (sys_clk                    ),
                        .sys_rstn_async         (sys_rstn_async             ),

                        .sys_rstn_sync          (sys_rstn_sync              ),
                        .sys_clk_div2           (sys_clk_div2               ),
                        .core_clk               (core_clk                   ),
                        .core_rstn_sync         (core_rstn_sync             )
                        
);

//choose signals from translation and initialize
wire    [     BA_BITS-1:0] trans_ddr_ba;
wire    [    ROW_BITS-1:0] trans_ddr_a;
wire    trans_ddr_cs_n, trans_ddr_ras_n, trans_ddr_cas_n, trans_ddr_we_n;
assign  ddr_ba      =   init_done ? trans_ddr_ba    : init_ddr_ba   ;
assign  ddr_a       =   init_done ? trans_ddr_a     : init_ddr_a    ;
assign  ddr_cs_n    =   init_done ? trans_ddr_cs_n  : init_ddr_cs_n ;
assign  ddr_cas_n   =   init_done ? trans_ddr_cas_n : init_ddr_cas_n;
assign  ddr_ras_n   =   init_done ? trans_ddr_ras_n : init_ddr_ras_n;
assign  ddr_we_n    =   init_done ? trans_ddr_we_n  : init_ddr_we_n ;

ddr_trans ddr_trans_u0(
                        .sys_clk                (sys_clk                    ),
                        .sys_rstn_sync          (sys_rstn_sync              ),
                        .sys_clk_div2           (sys_clk_div2               ),
                        .core_clk               (core_clk                   ),
                        .core_rstn_sync         (core_rstn_sync             ),

                        .init_done              (init_done                  ),

                        .ddr_cs_n               (trans_ddr_cs_n             ),
                        .ddr_ras_n              (trans_ddr_ras_n            ),
                        .ddr_cas_n              (trans_ddr_cas_n            ),
                        .ddr_we_n               (trans_ddr_we_n             ),
                        .ddr_ba                 (trans_ddr_ba               ),
                        .ddr_a                  (trans_ddr_a                ),
                        .ddr_dqs                (ddr_dqs                    ),
                        .ddr_dm                 (ddr_dm                     ),
                        .ddr_dq                 (ddr_dq                     ),

                        .awvalid                (awvalid                    ),
                        .awready                (awready                    ),
                        .awaddr                 (awaddr                     ),
                        .awlen                  (awlen                      ),
                        .wvalid                 (wvalid                     ),
                        .wready                 (wready                     ),
                        .wlast                  (wlast                      ),  
                        .wdata                  (wdata                      ),
                        .bvalid                 (bvalid                     ),
                        .bready                 (bready                     ),
                        .arvalid                (arvalid                    ),
                        .arready                (arready                    ),
                        .araddr                 (araddr                     ),
                        .arlen                  (arlen                      ),
                        .rvalid                 (rvalid                     ),
                        .rready                 (rready                     ),
                        .rlast                  (rlast                      ),
                        .rdata                  (rdata                      )

);



endmodule
