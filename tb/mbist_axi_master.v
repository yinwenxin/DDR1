`ifndef DEFINE_DDR
`define DEFINE_DDR
`include "./config/config_ddr.v"
`include "./config/define_ddr.v"
`endif

localparam [2:0] ADDR_INC = (1<<DQ_LEVEL);

module mbist_axi_master #(
    parameter [4:0] TEST_BITS    = 5'd13,
    parameter [7:0] WBURST_LEN   = 8'd7,
    parameter [7:0] RBURST_LEN   = 8'd7
)(
    input  wire                                                     core_rstn_sync,
    input  wire                                                     core_clk,
    output wire                                                     awvalid,
    input  wire                                                     awready,
    output reg  [BA_BITS+ROW_BITS+COL_BITS+DQ_LEVEL-2:0]            awaddr,
    output wire [        7:0]                                       awlen,
    output wire                                                     wvalid,
    input  wire                                                     wready,
    output wire                                                     wlast,
    output wire [(8<<DQ_LEVEL)-1:0]                                 wdata,
    input  wire                                                     bvalid,
    output wire                                                     bready,
    output wire                                                     arvalid,
    input  wire                                                     arready,
    output reg  [BA_BITS+ROW_BITS+COL_BITS+DQ_LEVEL-2:0]            araddr,
    output wire [        7:0]                                       arlen,
    input  wire                                                     rvalid,
    output wire                                                     rready,
    input  wire                                                     rlast,
    input  wire [(8<<DQ_LEVEL)-1:0]                                 rdata,
    output reg                                                      error_flag,
    output reg  [       15:0]                                       error_cnt
);


localparam [2:0] MBIST_INIT     = 3'd0;
localparam [2:0] MBIST_ADDR_W   = 3'd1;
localparam [2:0] MBIST_DATA_W   = 3'd2;
localparam [2:0] MBIST_RESP     = 3'd3;
localparam [2:0] MBIST_ADDR_R   = 3'd4;
localparam [2:0] MBIST_DATA_R   = 3'd5;

reg [2:0] mbist_state;


reg  awaddr_carry;
reg  [7:0] write_cnt;

wire [BA_BITS+ROW_BITS+COL_BITS+DQ_LEVEL-2:0] araddr_next;
wire araddr_carry;
assign {araddr_carry, araddr_next} = araddr + ADDR_INC;

wire write_end, read_end;
assign write_end = (TEST_BITS == BA_BITS+ROW_BITS+COL_BITS+DQ_LEVEL-1) ? awaddr_carry : awaddr[TEST_BITS];
assign read_end  = (TEST_BITS == BA_BITS+ROW_BITS+COL_BITS+DQ_LEVEL-1) ? araddr_carry : araddr_next[TEST_BITS];

assign awvalid  = (mbist_state==MBIST_ADDR_W);
assign awlen    = WBURST_LEN;
assign wvalid   = (mbist_state==MBIST_DATA_W);
assign wlast    = (write_cnt==WBURST_LEN);
assign wdata    = awaddr;
assign bready   = 1'b1;
assign arvalid  = (mbist_state==MBIST_ADDR_R);
assign arlen    = RBURST_LEN;
assign rready   = 1'b1;

always @ (posedge core_clk or negedge core_rstn_sync)
    if(~core_rstn_sync) begin
        {awaddr_carry, awaddr} <= 0;
        araddr <= 0;
        write_cnt <= 8'd0;
        araddr <= 0;
        mbist_state <= MBIST_INIT;
    end else begin
        case(mbist_state)
            MBIST_INIT: begin
                {awaddr_carry, awaddr} <= 0;
                araddr <= 0;
                write_cnt <= 8'd0;
                araddr <= 0;
                mbist_state <= MBIST_ADDR_W;
            end
            MBIST_ADDR_W: if(awready) begin
                write_cnt <= 8'd0;
                mbist_state <= MBIST_DATA_W;
            end
            MBIST_DATA_W: if(wready) begin
                {awaddr_carry, awaddr} <= {awaddr_carry, awaddr} + ADDR_INC;
                write_cnt <= write_cnt + 8'd1;
                if(wlast)
                    mbist_state <= MBIST_RESP;
            end
            MBIST_RESP: if(bvalid) begin
                mbist_state <= write_end ? MBIST_ADDR_R : MBIST_ADDR_W;
            end
            MBIST_ADDR_R: if(arready) begin
                mbist_state <= MBIST_DATA_R;
            end
            MBIST_DATA_R: if(rvalid) begin
                araddr <= araddr_next;
                if(rlast) begin
                    mbist_state <= MBIST_ADDR_R;
                    if(read_end) araddr <= 0;
                end
            end
        endcase
    end

// ------------------------------------------------------------
//  read and write mismatch detect
// ------------------------------------------------------------
wire [(8<<DQ_LEVEL)-1:0] rdata_correct = araddr;

always @ (posedge core_clk or negedge core_rstn_sync)
    if(~core_rstn_sync) begin
        error_flag  <= 1'b0;
        error_cnt   <= 16'd0;
    end else begin
        error_flag  <= rvalid && rready && rdata!=rdata_correct;
        error_cnt <= error_cnt + error_flag;
    end

endmodule
