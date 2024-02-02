`include "../config/config_ddr.v"

`ifndef DEFINE_DDR
`define DEFINE_DDR
`include "../config/define_ddr.v"
`endif


module ddr_trans (
    input  wire                                           sys_clk, 
    input  wire                                           sys_rstn_sync,

    input  wire                                           sys_clk_div2,	
    input  wire                                           core_rstn_sync,
    input  wire                                           core_clk,

    input  wire                                           init_done,

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
    
localparam [3:0] RESET      = 4'd0;
localparam [3:0] IDLE       = 4'd1;
localparam [3:0] REFRESH    = 4'd2;
localparam [3:0] ACTIVE_W   = 4'd3;
localparam [3:0] WRITE      = 4'd4;
localparam [3:0] WRITE_RESP = 4'd5;
localparam [3:0] ACTIVE_R   = 4'd6;
localparam [3:0] READ       = 4'd7;
localparam [3:0] READ_RESP  = 4'd8;

reg [3:0] main_state;

reg [3:0] refresh_require, refresh_ptr;
reg [9:0] refresh_cnt;

always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) begin
        refresh_require <= 0;
        refresh_cnt <= 0;
    end
    else if (refresh_cnt == tREFC/tCLK) begin
        refresh_require <= refresh_require + 1;
        refresh_cnt <= 0;
    end
    else begin
        refresh_require <= refresh_require;
        refresh_cnt <= refresh_cnt + 1;        
    end
end

reg [7:0] active_clk_cnt, refresh_clk_cnt;

always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) 
        active_clk_cnt <= 0;
    else if (active_clk_cnt == 255) 
        active_clk_cnt <= active_clk_cnt;
    else if (main_state == ACTIVE_R || main_state == ACTIVE_W)
        active_clk_cnt <= 0;
    else 
        active_clk_cnt <= active_clk_cnt + 1;
end

always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) 
        refresh_clk_cnt <= 0;
    else if (refresh_clk_cnt == 255) 
        refresh_clk_cnt <= refresh_clk_cnt;
    else if (main_state == REFRESH)
        refresh_clk_cnt <= 0;
    else 
        refresh_clk_cnt <= refresh_clk_cnt + 1;
end


reg [7:0] burst_len, trans_cnt;
wire burst_last;

assign burst_last = (trans_cnt == burst_len) ? 1 : 0;

reg [COL_BITS-2:0] col_addr;

wire [ROW_BITS-1:0] ddr_a_col_no_pre, ddr_a_col_auto_pre;
generate if(COL_BITS>10) begin
    assign ddr_a_col_no_pre = {col_addr[COL_BITS-2:9], 1'b0, col_addr[8:0], 1'b0};
    assign ddr_a_col_auto_pre = {col_addr[COL_BITS-2:9], 1'b1, col_addr[8:0], 1'b0};
end else begin
    assign ddr_a_col_no_pre = {1'b0, col_addr[8:0], 1'b0};
    assign ddr_a_col_auto_pre = {1'b1, col_addr[8:0], 1'b0};
end endgenerate


always @(posedge core_clk or negedge core_rstn_sync) begin
    if(core_rstn_sync) begin
        COMMAND <= COM_DESELECT;
        MR_COMMAND <= EMR_INIT;
        col_addr <= 0;
        burst_len <= 0;
        trans_cnt <= 0;
        refresh_ptr <= 0;
        main_state <= RESET;
    end
    else begin
        case(main_state)
            RESET:begin
                COMMAND <= COM_NOP;
                MR_COMMAND <= EMR_INIT;
                if(init_done == 1) 
                    main_state <= IDLE;
            end
            IDLE:begin
                COMMAND <= COM_NOP;
                MR_COMMAND <= EMR_INIT;
                if(refresh_ptr != refresh_require & refresh_clk_cnt > tRFC/tCLK & active_clk_cnt > tRC/tCLK) begin
                        refresh_ptr <= refresh_ptr + 1;
                        COMMAND <= COM_REFRESH;
                        main_state <= REFRESH;
                end
                else if(awvalid & active_clk_cnt > tRC/tCLK) begin
                    COMMAND <= ACTIVE;
                    {ddr_ba, ddr_a, col_addr} <= awaddr[BA_BITS+ROW_BITS+COL_BITS+DQ_LEVEL-2:DQ_LEVEL];
                    main_state <= ACTIVE_W;
                    burst_len <= awlen;
                end
                else if(arvalid & active_clk_cnt > tRC/tCLK) begin
                    COMMAND <= ACTIVE;
                    {ddr_ba, ddr_a, col_addr} <= araddr[BA_BITS+ROW_BITS+COL_BITS+DQ_LEVEL-2:DQ_LEVEL];
                    main_state <= ACTIVE_R;
                    burst_len <= arlen;
                end
            end
            REFRESH:begin
                COMMAND <= COM_NOP;
                MR_COMMAND <= EMR_INIT;
                main_state <= IDLE;
            end
            ACTIVE_W:begin
                COMMAND <= COM_NOP;
                MR_COMMAND <= EMR_INIT;
                trans_cnt <= 0;
                main_state <= WRITE;
            end
            WRITE:begin
                COMMAND <= COM_NOP;
                ddr_a <= (burst_last | wlast) ? ddr_a_col_auto_pre : ddr_a_col_no_pre;
                if (wvalid & active_clk_cnt > tRCD/tCLK) begin
                    COMMAND <= COM_WRITE;
                    col_addr <= col_addr + 1;
                    trans_cnt <= trans_cnt + 1;
                    main_state <= (burst_last | wlast) ? WRITE_RESP : WRITE;
                end
            end
            WRITE_RESP:begin
                COMMAND <= COM_NOP;
                main_state <= bready ? IDLE : WRITE_RESP;
            end
            ACTIVE_R:begin
                COMMAND <= COM_NOP;
                MR_COMMAND <= EMR_INIT;
                trans_cnt <= 0;
                main_state <= READ;
            end
            READ:begin
                COMMAND <= COM_NOP;
                ddr_a <= (burst_last) ? ddr_a_col_auto_pre : ddr_a_col_no_pre;
                if (rready & active_clk_cnt > tRCD/tCLK) begin
                    COMMAND <= COM_WRITE;
                    col_addr <= col_addr + 1;
                    trans_cnt <= trans_cnt + 1;
                    main_state <= (burst_last) ? READ_RESP : READ;
                end
            end
            READ_RESP:begin
                COMMAND <= COM_NOP;
                main_state <= bready ? IDLE : READ_RESP;
            end

        endcase
    end 

end

assign awready  = main_state == IDLE & awvalid & active_clk_cnt > tRC/tCLK;
assign wready   = main_state == WRITE & wvalid & active_clk_cnt > tRCD/tCLK;
assign bvalid   = main_state == WRITE_RESP;






endmodule