`timescale 1ps/1ps

`ifndef DEFINE_DDR
`define DEFINE_DDR
`include "./config/config_ddr.v"
`include "./config/define_ddr.v"
`endif

module tb_ddr_top();

// -------------------------------------------------------------------------------------
//   AXI4 burst length parameters
// -------------------------------------------------------------------------------------

reg                                           sys_clk; 
reg                                           sys_rstn_async;
	
wire                                          core_rstn_sync;
wire                                          core_clk;

wire                                           awvalid;
wire                                           awready;
wire  [BA_BITS+ROW_BITS+COL_BITS+DQ_LEVEL-2:0] awaddr;  
wire                                    [ 7:0] awlen;
wire                                           wvalid;
wire                                           wready;
wire                                           wlast;
wire                       [(8<<DQ_LEVEL)-1:0] wdata;
wire                                           bvalid;
wire                                           bready;
wire                                           arvalid;
wire                                           arready;
wire  [BA_BITS+ROW_BITS+COL_BITS+DQ_LEVEL-2:0] araddr;   
wire                                    [ 7:0] arlen;
wire                                           rvalid;
wire                                           rready;
wire                                           rlast;
wire                       [(8<<DQ_LEVEL)-1:0] rdata;

wire                                           ddr_ck_p, ddr_ck_n;  
wire                                           ddr_cke;
wire                                           ddr_cs_n;
wire                                           ddr_ras_n;
wire                                           ddr_cas_n;
wire                                           ddr_we_n;
wire                 [            BA_BITS-1:0] ddr_ba;
wire                 [           ROW_BITS-1:0] ddr_a;
wire                 [((1<<DQ_LEVEL)+1)/2-1:0] ddr_dm;
wire                 [((1<<DQ_LEVEL)+1)/2-1:0] ddr_dqs;
wire                 [      (4<<DQ_LEVEL)-1:0] ddr_dq;  


wire error_flag;
wire [15:0] error_cnt;


initial begin
    sys_clk         = 1;
    sys_rstn_async  = 0;

    #100000000;
    if(error_cnt == 0)
        $display("DDR runs correctly !!!");
    else
        $display("Error: Data match Failed !!!");

    $finish;
end

always #1250 sys_clk = ~sys_clk;

initial begin
    repeat(10) @(posedge sys_clk);
        sys_rstn_async <= 1;
end


mbist_axi_master #(
    .TEST_BITS   (5'd10 ),
    .WBURST_LEN  (8'd7  ),
    .RBURST_LEN  (8'd7  )
) mbist_axi_master_u0 (
    .core_rstn_sync (core_rstn_sync        ),
    .core_clk       (core_clk         ),
    .awvalid        (awvalid     ),
    .awready        (awready     ),
    .awaddr         (awaddr      ),
    .awlen          (awlen       ),
    .wvalid         (wvalid      ),
    .wready         (wready      ),
    .wlast          (wlast       ),
    .wdata          (wdata       ),
    .bvalid         (bvalid      ),
    .bready         (bready      ),
    .arvalid        (arvalid     ),
    .arready        (arready     ),
    .araddr         (araddr      ),
    .arlen          (arlen       ),
    .rvalid         (rvalid      ),
    .rready         (rready      ),
    .rlast          (rlast       ),
    .rdata          (rdata       ),
    .error_flag     (error_flag  ),
    .error_cnt      (error_cnt   )
);  


ddr_top ddr_top_u0 (
    .sys_rstn_async     (sys_rstn_async    ),
    .sys_clk            (sys_clk           ),
    .core_rstn_sync     (core_rstn_sync    ),
    .core_clk           (core_clk          ),
    .awvalid            (awvalid           ),
    .awready            (awready           ),
    .awaddr             (awaddr            ),
    .awlen              (awlen             ),
    .wvalid             (wvalid            ),
    .wready             (wready            ),
    .wlast              (wlast             ),
    .wdata              (wdata             ),
    .bvalid             (bvalid            ),
    .bready             (bready            ),
    .arvalid            (arvalid           ),
    .arready            (arready           ),
    .araddr             (araddr            ),
    .arlen              (arlen             ),
    .rvalid             (rvalid            ),
    .rready             (rready            ),
    .rlast              (rlast             ),
    .rdata              (rdata             ),
    .ddr_ck_p           (ddr_ck_p          ),
    .ddr_ck_n           (ddr_ck_n          ),
    .ddr_cke            (ddr_cke           ),
    .ddr_cs_n           (ddr_cs_n          ),
    .ddr_ras_n          (ddr_ras_n         ),
    .ddr_cas_n          (ddr_cas_n         ),
    .ddr_we_n           (ddr_we_n          ),
    .ddr_ba             (ddr_ba            ),
    .ddr_a              (ddr_a             ),
    .ddr_dm             (ddr_dm            ),
    .ddr_dqs            (ddr_dqs           ),
    .ddr_dq             (ddr_dq            )    
);


micron_ddr_sdram_model #(
    .BA_BITS     (BA_BITS     ),
    .ROW_BITS    (ROW_BITS    ),
    .COL_BITS    (COL_BITS    ),
    .DQ_LEVEL    (DQ_LEVEL    )
) ddr_model_u0 (
    .Clk         (ddr_ck_p    ),
    .Clk_n       (ddr_ck_n    ),
    .Cke         (ddr_cke     ),
    .Cs_n        (ddr_cs_n    ),
    .Ras_n       (ddr_ras_n   ),
    .Cas_n       (ddr_cas_n   ),
    .We_n        (ddr_we_n    ),
    .Ba          (ddr_ba      ),
    .Addr        (ddr_a       ),
    .Dm          (ddr_dm      ),
    .Dqs         (ddr_dqs     ),
    .Dq          (ddr_dq      )
);

initial begin
    $fsdbDumpfile("testbench.fsdb");
    $fsdbDumpvars;
    $fsdbDumpMDA;
end

endmodule
