    localparam BA_BITS          =       2; // The Number of Banks	=	1 << BA_BITS
    localparam ROW_BITS         =      13; // The Number of Rows		=	1 << ROW_BITS
    localparam COL_BITS         =      11; // The Number of Columns	=	1 << COL_BITS
    localparam DQ_LEVEL         =       1; // DDR DQ_BITS = 4 << DQ_LEVEL, AXI4 DATA WIDTH = 8 << DQ_LEVEL, for example:
										  // DQ_LEVEL = 0: DQ_BITS = 4  (x4)  , AXI DATA WIDTH = 8
										  // DQ_LEVEL = 1: DQ_BITS = 8  (x8)  , AXI DATA WIDTH = 16
										  // DQ_LEVEL = 2: DQ_BITS = 16 (x16) , AXI DATA WIDTH = 32

    // localparam tSYSCLK          =    2.5;            // tSYSCLK  ns  Input clock
    localparam tCLK             =    10  ; // tCLK ns  DDR clock == core_clk

    // localparam tCK              =     5.0; // tCK    ns    Nominal Clock Cycle Time
    localparam tDQSQ            =     1; // tDQSQ  ns    DQS-DQ skew, DQS to last DQ valid, per group, per access
    localparam tMRD             =    10; // tMRD   ns    Load Mode Register command cycle time
    localparam tRAP             =    15; // tRAP   ns    ACTIVE to READ with Auto precharge command
    localparam tRAS             =    40; // tRAS   ns    Active to Precharge command time
    localparam tRC              =    55; // tRC    ns    Active to Active/Auto Refresh command time
    localparam tRFC             =    70; // tRFC   ns    Refresh to Refresh Command interval time
    localparam tRCD             =    15; // tRCD   ns    Active to Read/Write command time
    localparam tRP              =    15; // tRP    ns    Precharge command period
    localparam tRRD             =    10; // tRRD   ns    Active bank a to Active bank b command time
    localparam tWR              =    15; // tWR    ns    Write recovery time

    localparam [ROW_BITS+1:0] EMR_INIT      = {2'b01, {(ROW_BITS){1'b0}}};                      //Extended mode register initialize, normal drive, enable DLL
    localparam [ROW_BITS+1:0] BMR_RESET_DLL = {2'b00, {(ROW_BITS-9){1'b0}}, 9'b1_0010_1001};    //reset DLL, BL=2, tCAS=2
    localparam [ROW_BITS+1:0] BMR_CLEAR_DLL = {2'b00, {(ROW_BITS-9){1'b0}}, 9'b0_0010_1001};    //clear DLL, BL=2, tCAS=2