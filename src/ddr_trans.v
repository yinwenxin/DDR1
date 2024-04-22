`ifndef DEFINE_DDR
`define DEFINE_DDR
`include "./config/config_ddr.v"
`include "./config/define_ddr.v"
`endif


module ddr_trans (
//clock and reset
    input  wire                                           sys_clk, 
    input  wire                                           sys_rstn_sync,

    input  wire                                           sys_clk_div2,	
    input  wire                                           core_rstn_sync,
    input  wire                                           core_clk,

    input  wire                                           init_done,

//AXI interface
    input  wire                                           awvalid,
    output wire                                           awready,
    input  wire  [BA_BITS+ROW_BITS+COL_BITS+DQ_LEVEL-2:0] awaddr,  
    input  wire                                    [ 7:0] awlen,
    input  wire                                           wvalid,
    output reg                                            wready,
    input  wire                                           wlast,
    input  wire                       [(8<<DQ_LEVEL)-1:0] wdata,
    output reg                                            bvalid,
    input  wire                                           bready,
    input  wire                                           arvalid,
    output wire                                           arready,
    input  wire  [BA_BITS+ROW_BITS+COL_BITS+DQ_LEVEL-2:0] araddr,   
    input  wire                                    [ 7:0] arlen,
    output reg                                            rvalid,
    input  wire                                           rready,
    output wire                                           rlast,
    output wire                       [(8<<DQ_LEVEL)-1:0] rdata,

//ddr pin
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

//translation state
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

reg [3:0] refresh_require; //The number of refresh required
reg [3:0] refresh_ptr; //The point of refresh has executed now
reg [9:0] refresh_cnt; //The clock cycle counter calculating the number of refresh required

always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) begin
        refresh_require <= 0;
        refresh_cnt <= 0;
    end
    else if (refresh_cnt == INT_tREFC/INT_tCLK) begin
        refresh_require <= refresh_require + 1;
        refresh_cnt <= 0;
    end
    else begin
        refresh_require <= refresh_require;
        refresh_cnt <= refresh_cnt + 1;        
    end
end

reg [7:0] active_clk_cnt, refresh_clk_cnt, precharge_clk_cnt;
reg [1:0] write_clk_cnt, read_clk_cnt;

//The clock cycle counter between active command and the next command
always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) 
        active_clk_cnt <= 0;
    else if (main_state == ACTIVE_R || main_state == ACTIVE_W)
        active_clk_cnt <= 0;
    else if (active_clk_cnt == 255) 
        active_clk_cnt <= active_clk_cnt;
    else 
        active_clk_cnt <= active_clk_cnt + 1;
end

//The clock cycle counter between refresh command and the next command
always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) 
        refresh_clk_cnt <= 0;
    else if (main_state == REFRESH)
        refresh_clk_cnt <= 0;
    else if (refresh_clk_cnt == 255) 
        refresh_clk_cnt <= refresh_clk_cnt;
    else 
        refresh_clk_cnt <= refresh_clk_cnt + 1;
end

//The clock cycle counter between precharge command and the next command
always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) 
        precharge_clk_cnt <= 0;
    else if (main_state == WRITE_RESP)
        precharge_clk_cnt <= 0;
    else if (precharge_clk_cnt == 255) 
        precharge_clk_cnt <= precharge_clk_cnt;
    else 
        precharge_clk_cnt <= precharge_clk_cnt + 1;
end

//The clock cycle counter between write command and the next command
always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) 
        write_clk_cnt <= 0;
    else if (main_state == WRITE & wvalid & active_clk_cnt > INT_tRCD/INT_tCLK & write_clk_cnt == CL - 1)
        write_clk_cnt <= 0;
    else if (write_clk_cnt == CL - 1) 
        write_clk_cnt <= write_clk_cnt;
    else 
        write_clk_cnt <= write_clk_cnt + 1;
end

//The clock cycle counter between read command and the next command
always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) 
        read_clk_cnt <= 0;
    else if (main_state == READ & rready & active_clk_cnt > INT_tRCD/INT_tCLK & read_clk_cnt == CL - 1)
        read_clk_cnt <= 0;
    else if (read_clk_cnt == CL - 1) 
        read_clk_cnt <= read_clk_cnt;
    else 
        read_clk_cnt <= read_clk_cnt + 1;
end

//burst length and translation count
reg [7:0] burst_len, trans_cnt;

wire burst_last;
//burst last flag
assign burst_last = (trans_cnt == burst_len) ? 1 : 0;

//column address
reg [COL_BITS-2:0] col_addr;
wire write_ddr_start, read_ddr_start;

//ddr command with and without auto precharge
wire [ROW_BITS-1:0] ddr_a_col_no_pre, ddr_a_col_auto_pre;
generate if(COL_BITS>10) begin
    assign ddr_a_col_no_pre = {col_addr[COL_BITS-2:9], 1'b0, col_addr[8:0], 1'b0};
    assign ddr_a_col_auto_pre = {col_addr[COL_BITS-2:9], 1'b1, col_addr[8:0], 1'b0};
end else begin
    assign ddr_a_col_no_pre = {1'b0, col_addr[8:0], 1'b0};
    assign ddr_a_col_auto_pre = {1'b1, col_addr[8:0], 1'b0};
end endgenerate


always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) begin
        `COMMAND <= `COM_DESELECT;
        `MR_COMMAND <= EMR_INIT;
        col_addr <= 0;
        burst_len <= 0;
        trans_cnt <= 0;
        refresh_ptr <= 0;
        main_state <= RESET;
    end
    else begin
        case(main_state)
            RESET:begin
                `COMMAND <= `COM_NOP;
                `MR_COMMAND <= EMR_INIT;
                if(init_done == 1)  // hold the RESET state for one more cycle to switch
                    main_state <= IDLE;
            end
            IDLE:begin
                `COMMAND <= `COM_NOP;
                `MR_COMMAND <= EMR_INIT;
                if(refresh_ptr != refresh_require & refresh_clk_cnt > INT_tRFC/INT_tCLK & active_clk_cnt > INT_tRC/INT_tCLK & precharge_clk_cnt > INT_tRP/INT_tCLK) begin
                    refresh_ptr <= refresh_ptr + 1; //if the time check passed and the number of refresh required is not zero, refresh it
                    `COMMAND <= `COM_REFRESH;
                    main_state <= REFRESH;
                end
                else if(awvalid & active_clk_cnt > INT_tRC/INT_tCLK & precharge_clk_cnt > INT_tRP/INT_tCLK) begin
                    `COMMAND <= `COM_ACTIVE; //if the time check passed and awvalid, active it
                    {ddr_ba, ddr_a, col_addr} <= awaddr[BA_BITS+ROW_BITS+COL_BITS+DQ_LEVEL-2:DQ_LEVEL];
                    main_state <= ACTIVE_W;
                    burst_len <= awlen;
                end
                else if(arvalid & active_clk_cnt > INT_tRC/INT_tCLK & precharge_clk_cnt > INT_tRP/INT_tCLK) begin
                    `COMMAND <= `COM_ACTIVE; //if the time check passed and arvalid, active it
                    {ddr_ba, ddr_a, col_addr} <= araddr[BA_BITS+ROW_BITS+COL_BITS+DQ_LEVEL-2:DQ_LEVEL];
                    main_state <= ACTIVE_R;
                    burst_len <= arlen;
                end
            end
            REFRESH:begin
                `COMMAND <= `COM_NOP;
                `MR_COMMAND <= EMR_INIT;
                main_state <= IDLE;
            end
            ACTIVE_W:begin
                `COMMAND <= `COM_NOP;
                trans_cnt <= 0;
                main_state <= WRITE;
            end
            WRITE:begin
                `COMMAND <= `COM_NOP;
                ddr_a <= (burst_last | wlast) ? ddr_a_col_auto_pre : ddr_a_col_no_pre; //send command with auto precharge when the last transfer
                if (wvalid & active_clk_cnt > INT_tRCD/INT_tCLK & write_clk_cnt == CL - 1) begin
                    `COMMAND <= `COM_WRITE; //if the time check passed and wvalid, write it
                    col_addr <= col_addr + 1; 
                    trans_cnt <= trans_cnt + 1;
                    main_state <= (burst_last | wlast) ? WRITE_RESP : WRITE;
                end
            end
            WRITE_RESP:begin  //write response
                `COMMAND <= `COM_NOP;
                main_state <= bready ? IDLE : WRITE_RESP;
            end
            ACTIVE_R:begin  
                `COMMAND <= `COM_NOP;
                trans_cnt <= 0;
                main_state <= READ;
            end
            READ:begin
                `COMMAND <= `COM_NOP;
                ddr_a <= (burst_last) ? ddr_a_col_auto_pre : ddr_a_col_no_pre; //send command with auto precharge when the last transfer
                if (rready & active_clk_cnt > INT_tRCD/INT_tCLK & read_clk_cnt == CL - 1) begin
                    `COMMAND <= `COM_READ; //if the time check passed and rvalid, read it
                    col_addr <= col_addr + 1;
                    trans_cnt <= trans_cnt + 1;
                    main_state <= (burst_last) ? READ_RESP : READ;
                end
            end
            READ_RESP:begin
                `COMMAND <= `COM_NOP;
                main_state <= bready ? IDLE : READ_RESP;
            end

        endcase
    end 

end

//if time check passed and no refresh required, pull up awready or arready
assign awready  = main_state == IDLE & awvalid & active_clk_cnt > INT_tRC/INT_tCLK & precharge_clk_cnt > INT_tRP/INT_tCLK & refresh_ptr == refresh_require;
assign arready  = main_state == IDLE & arvalid & active_clk_cnt > INT_tRC/INT_tCLK & precharge_clk_cnt > INT_tRP/INT_tCLK & refresh_ptr == refresh_require;

//if time check passed, start to write or read successfully
assign write_ddr_start = main_state == WRITE & wvalid & active_clk_cnt > INT_tRCD/INT_tCLK & write_clk_cnt == CL - 1;
assign read_ddr_start = main_state == READ  & rready & active_clk_cnt > INT_tRCD/INT_tCLK & read_clk_cnt == CL - 1;



always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) 
        wready <= 0;
    else
        wready <= write_ddr_start;
end

always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) 
        bvalid <= 0;
    else 
        bvalid <= main_state == WRITE_RESP;
end

//control delayed cycles of output enable pins when write starts 
reg output_enable, output_enable_r1, output_enable_r2;

always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) begin
        output_enable       <=  0;
        output_enable_r1    <=  0;
        output_enable_r2    <=  0;
    end
    else begin
        output_enable       <=  write_ddr_start | output_enable_r1 | output_enable_r2;
        output_enable_r1    <=  write_ddr_start;
        output_enable_r2    <=  output_enable_r1;
    end
end

reg  [(4<<DQ_LEVEL)-1:0] wdata_h, wdata_l, write_dq_reg1, write_dq_reg2;

reg dqs_reg;

assign  ddr_dm  =   output_enable ? {DQS_BITS{1'b0}}    : {DQS_BITS{1'bz}}; //ddr dq mask, low is effective
assign  ddr_dq  =   output_enable ? write_dq_reg2       : {(4<<DQ_LEVEL){1'bz}};
assign  ddr_dqs =   output_enable ? {DQS_BITS{dqs_reg}} : {DQS_BITS{1'bz}}; 

//split wdata to wdata_h and wdata_l
always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) 
        {wdata_h, wdata_l} <= 0;
    else 
        {wdata_h, wdata_l} <= wdata;
end

//send wdata_h and wdata_l with sys_clk_div2 (both posedge and negedge of core_clk)
always @(posedge sys_clk_div2) begin
    if(core_clk) begin
        write_dq_reg1 <= wdata_h;
        dqs_reg <= output_enable_r2;
    end
    else begin
        write_dq_reg1 <= wdata_l;
        dqs_reg <= 0;
    end
end

//update data with sys_clk, because the edge of dqs must be in the middle of the dq data
always @(posedge sys_clk) begin
    write_dq_reg2 <= write_dq_reg1;
end

//the pipe of read data
reg read_dqs;
reg  [(4<<DQ_LEVEL)-1:0] read_dq; 
reg  [(8<<DQ_LEVEL)-1:0] read_dq_reg1, read_dq_reg2; 

always @(posedge sys_clk_div2) begin
    read_dqs <= ddr_dqs;
    read_dq  <= ddr_dq;
end

//collect two cycles of data
always @(posedge sys_clk_div2) begin
    if(read_dqs)
        read_dq_reg1 <= {ddr_dq, read_dq};
end

always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) 
        read_dq_reg2    <= 0;
    else
        read_dq_reg2    <= read_dq_reg1;
end

//pipe the read valid signal and read last signal
reg read_valid, read_valid_r1, read_valid_r2, read_valid_r3, read_valid_r4;
reg read_last, read_last_r1, read_last_r2, read_last_r3, read_last_r4;

always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) begin
        read_valid      <= 0;
        read_valid_r1   <= 0;
        read_valid_r2   <= 0;
        read_valid_r3   <= 0;
        read_valid_r4   <= 0;
        read_last       <= 0;
        read_last_r1    <= 0;
        read_last_r2    <= 0;
        read_last_r3    <= 0;
        read_last_r4    <= 0;
    end
    else begin
        read_valid      <= read_ddr_start;
        read_last       <= burst_last;
        read_valid_r1   <= read_valid;
        read_valid_r2   <= read_valid_r1;
        read_valid_r3   <= read_valid_r2;
        read_valid_r4   <= read_valid_r3;
        read_last_r1    <= read_last;
        read_last_r2    <= read_last_r1;
        read_last_r3    <= read_last_r2;
        read_last_r4    <= read_last_r3;
    end

end



//the synchronous fifo of read buffer
localparam ADDR_WIDTH = 10;
localparam DATA_WIDTH = 1 + (8<<DQ_LEVEL); //read data and one bit of read_last signal

reg [DATA_WIDTH:0] buffer_fifo [(1 << ADDR_WIDTH)-1:0];
reg [ADDR_WIDTH:0] write_ptr, read_ptr;
reg [DATA_WIDTH:0] fifo_rdata;


wire    fifo_empty, fifo_full;
assign  fifo_empty  = write_ptr == read_ptr;
assign  fifo_full   = (read_ptr[ADDR_WIDTH-1:0]  == write_ptr[ADDR_WIDTH-1:0]) && (read_ptr[ADDR_WIDTH] != write_ptr[ADDR_WIDTH]);


wire fifo_write_req, fifo_read_req;
assign fifo_write_req = read_valid_r4;
assign fifo_read_req  = rready;

always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) 
        write_ptr <= 0;
    else if(fifo_write_req & !fifo_full)
        write_ptr <= write_ptr + 1;
end

always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) 
        read_ptr <= 0;
    else if(fifo_read_req & !fifo_empty)
        read_ptr <= read_ptr + 1;
end

always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) 
        fifo_rdata <= 0;
    else if(fifo_read_req & !fifo_empty)
        fifo_rdata <= buffer_fifo[read_ptr[ADDR_WIDTH-1:0]];
end

always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) 
        rvalid <= 0;
    else
        rvalid <= (fifo_read_req & !fifo_empty);
end

always @(posedge core_clk) begin
    if(fifo_write_req)
        buffer_fifo[write_ptr[ADDR_WIDTH-1:0]] <= {read_last_r4, read_dq_reg2};
end

assign {rlast, rdata} = fifo_rdata;

endmodule
