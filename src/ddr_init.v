`ifndef DEFINE_DDR
    `define DEFINE_DDR
    `include "./config/config_ddr.v"
    `include "./config/define_ddr.v"
`endif

module ddr_init (
    input  wire                                           core_clk, 
    input  wire                                           core_rstn_sync,

    output wire                                           init_done, //init_done flag

    output reg                                            ddr_cs_n, //ddr command pin
    output reg                                            ddr_ras_n,
    output reg                                            ddr_cas_n,
    output reg                                            ddr_we_n,
    output reg                  [            BA_BITS-1:0] ddr_ba,
    output reg                  [           ROW_BITS-1:0] ddr_a
);


//To decouple the process of initialize, write out all the states

localparam [4:0] RESET              = 5'd0;
localparam [4:0] RESET_WAIT         = 5'd1;
localparam [4:0] CKE                = 5'd2;
localparam [4:0] CKE_WAIT           = 5'd3;
localparam [4:0] PRECHARGE0         = 5'd4;
localparam [4:0] PRECHARGE0_WAIT    = 5'd5;
localparam [4:0] EMR_LMR            = 5'd6;
localparam [4:0] EMR_LMR_WAIT       = 5'd7;
localparam [4:0] RESET_DLL          = 5'd8;
localparam [4:0] RESET_DLL_WAIT     = 5'd9;
localparam [4:0] PRECHARGE1         = 5'd10;
localparam [4:0] PRECHARGE1_WAIT    = 5'd11;
localparam [4:0] REFRESH0           = 5'd12;
localparam [4:0] REFRESH0_WAIT      = 5'd13;
localparam [4:0] REFRESH1           = 5'd14;
localparam [4:0] REFRESH1_WAIT      = 5'd15;
localparam [4:0] CLEAR_DLL          = 5'd16;
localparam [4:0] CLEAR_DLL_WAIT     = 5'd17;
localparam [4:0] INIT_END           = 5'd18;

reg [4:0] init_state, next_state; 
reg [7:0] counter_wait, counter_check;
assign init_done = (init_state == INIT_END) ? 1 : 0;

always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync)
        init_state <= RESET;
    else
        init_state <= next_state;
end

//clock counter between states
always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync)
        counter_wait <= 0;
    else if(init_state[0] == 0)
        counter_wait <= 0;
    else if(counter_wait == 255)
        counter_wait <= counter_wait;
    else
        counter_wait <= counter_wait + 1;
end

//200 cycles are required between reset DLL and read command
always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync)
        counter_check <= 0;
    else if(init_state == INIT_END)
        counter_check <= 0;
    else if(init_state >= RESET_DLL)
        counter_check <= counter_check + 1;
end

//generate next state
always @(*) begin
    case(init_state)
        RESET           :   next_state = RESET_WAIT     ;
        RESET_WAIT      :   next_state = (counter_wait > 200           ) ? CKE             : RESET_WAIT        ;
        CKE             :   next_state = CKE_WAIT       ;
        CKE_WAIT        :   next_state = PRECHARGE0     ;
        PRECHARGE0      :   next_state = PRECHARGE0_WAIT;
        PRECHARGE0_WAIT :   next_state = (counter_wait > INT_tRP/INT_tCLK      ) ? EMR_LMR         : PRECHARGE0_WAIT   ;
        EMR_LMR         :   next_state = EMR_LMR_WAIT   ;
        EMR_LMR_WAIT    :   next_state = (counter_wait > INT_tMRD/INT_tCLK     ) ? RESET_DLL       : EMR_LMR_WAIT      ;
        RESET_DLL       :   next_state = RESET_DLL_WAIT ;
        RESET_DLL_WAIT  :   next_state = (counter_wait > INT_tMRD/INT_tCLK     ) ? PRECHARGE1      : RESET_DLL_WAIT    ;
        PRECHARGE1      :   next_state = PRECHARGE1_WAIT;
        PRECHARGE1_WAIT :   next_state = (counter_wait > INT_tRP/INT_tCLK      ) ? REFRESH0        : PRECHARGE1_WAIT   ;
        REFRESH0        :   next_state = REFRESH0_WAIT  ;
        REFRESH0_WAIT   :   next_state = (counter_wait > INT_tRFC/INT_tCLK     ) ? REFRESH1        : REFRESH0_WAIT     ;
        REFRESH1        :   next_state = REFRESH1_WAIT  ;
        REFRESH1_WAIT   :   next_state = (counter_wait > INT_tRFC/INT_tCLK     ) ? CLEAR_DLL       : REFRESH1_WAIT     ;
        CLEAR_DLL       :   next_state = CLEAR_DLL_WAIT ;
        CLEAR_DLL_WAIT  :   next_state = (counter_wait > INT_tMRD/INT_tCLK
                                          && counter_check > 200       ) ? INIT_END        : CLEAR_DLL_WAIT    ;
        INIT_END        :   next_state = INIT_END       ;
        default         :   next_state = RESET          ;
    endcase
end


//send command and mode register command
always @(posedge core_clk or negedge core_rstn_sync) begin
    if(!core_rstn_sync) begin
        `COMMAND     <= `COM_DESELECT;
        `MR_COMMAND  <= EMR_INIT;
    end
    else case(next_state)
        RESET           :begin `COMMAND <= `COM_DESELECT   ; `MR_COMMAND <= EMR_INIT     ; end
        RESET_WAIT      :begin `COMMAND <= `COM_DESELECT   ; `MR_COMMAND <= EMR_INIT     ; end
        CKE             :begin `COMMAND <= `COM_NOP        ; `MR_COMMAND <= EMR_INIT     ; end
        CKE_WAIT        :begin `COMMAND <= `COM_NOP        ; `MR_COMMAND <= EMR_INIT     ; end
        PRECHARGE0      :begin `COMMAND <= `COM_PRECHARGE  ; `MR_COMMAND <= PRECHARGE_ALL; end
        PRECHARGE0_WAIT :begin `COMMAND <= `COM_NOP        ; `MR_COMMAND <= EMR_INIT     ; end
        EMR_LMR         :begin `COMMAND <= `COM_LMR        ; `MR_COMMAND <= EMR_INIT     ; end
        EMR_LMR_WAIT    :begin `COMMAND <= `COM_NOP        ; `MR_COMMAND <= EMR_INIT     ; end
        RESET_DLL       :begin `COMMAND <= `COM_LMR        ; `MR_COMMAND <= BMR_RESET_DLL; end
        RESET_DLL_WAIT  :begin `COMMAND <= `COM_NOP        ; `MR_COMMAND <= EMR_INIT     ; end
        PRECHARGE1      :begin `COMMAND <= `COM_PRECHARGE  ; `MR_COMMAND <= PRECHARGE_ALL; end
        PRECHARGE1_WAIT :begin `COMMAND <= `COM_NOP        ; `MR_COMMAND <= EMR_INIT     ; end
        REFRESH0        :begin `COMMAND <= `COM_REFRESH    ; `MR_COMMAND <= EMR_INIT     ; end
        REFRESH0_WAIT   :begin `COMMAND <= `COM_NOP        ; `MR_COMMAND <= EMR_INIT     ; end
        REFRESH1        :begin `COMMAND <= `COM_REFRESH    ; `MR_COMMAND <= EMR_INIT     ; end
        REFRESH1_WAIT   :begin `COMMAND <= `COM_NOP        ; `MR_COMMAND <= EMR_INIT     ; end
        CLEAR_DLL       :begin `COMMAND <= `COM_LMR        ; `MR_COMMAND <= BMR_CLEAR_DLL; end
        CLEAR_DLL_WAIT  :begin `COMMAND <= `COM_NOP        ; `MR_COMMAND <= EMR_INIT     ; end                       
        INIT_END        :begin `COMMAND <= `COM_NOP        ; `MR_COMMAND <= EMR_INIT     ; end
        default         :begin `COMMAND <= `COM_DESELECT   ; `MR_COMMAND <= EMR_INIT     ; end
    endcase
end



endmodule
