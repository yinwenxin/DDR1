module ddr_clock_reset (
    input  wire                                           sys_clk, //System clock 300MHz
    input  wire                                           sys_rstn_async, //Asynchronous system reset
	
    output reg                                            sys_rstn_sync, //Synchronous system reset

    output wire                                           sys_clk_div2, //150MHz

    output wire                                           core_clk, // Core clock 75MHz
    output reg                                            core_rstn_sync //Synchronous system reset

);

//Asynchronous Reset, Synchronous Release
reg [2:0] sys_rstn_sync_reg;

always @(posedge sys_clk or negedge sys_rstn_async) begin
    if(!sys_rstn_async)
        {sys_rstn_sync, sys_rstn_sync_reg} <= 4'b0000;
    else
        {sys_rstn_sync, sys_rstn_sync_reg} <= {sys_rstn_sync_reg, 1'b1};
end

//Asynchronous Reset, Synchronous Release
reg [2:0] core_rstn_sync_reg;

always @(posedge core_clk or negedge sys_rstn_async) begin
    if(!sys_rstn_async)
        {core_rstn_sync, core_rstn_sync_reg} <= 4'b0000;
    else
        {core_rstn_sync, core_rstn_sync_reg} <= {core_rstn_sync_reg, 1'b1};
end


//clock divider
reg [1:0] sys_clk_counter;

always @(posedge sys_clk or negedge sys_rstn_sync) begin
    if(!sys_rstn_sync)
        sys_clk_counter <= 2'b00;
    else
        sys_clk_counter <= sys_clk_counter + 1;
end

wire sys_clk_div4;

assign sys_clk_div4 = sys_clk_counter[1];
assign sys_clk_div2 = sys_clk_counter[0];
assign core_clk     = sys_clk_div4;


endmodule