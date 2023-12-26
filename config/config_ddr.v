    parameter BA_BITS          =       2; // The Number of Banks	=	1 << BA_BITS
    parameter ROW_BITS         =      13; // The Number of Rows		=	1 << ROW_BITS
    parameter COL_BITS         =      11; // The Number of Columns	=	1 << COL_BITS
    parameter DQ_LEVEL         =       1; // DDR DQ_BITS = 4 << DQ_LEVEL, AXI4 DATA WIDTH = 8 << DQ_LEVEL, for example:
										  // DQ_LEVEL = 0: DQ_BITS = 4  (x4)  , AXI DATA WIDTH = 8
										  // DQ_LEVEL = 1: DQ_BITS = 8  (x8)  , AXI DATA WIDTH = 16
										  // DQ_LEVEL = 2: DQ_BITS = 16 (x16) , AXI DATA WIDTH = 32
										  
    parameter tCK              =     5.0; // tCK    ns    Nominal Clock Cycle Time
    parameter tDQSQ            =     0.4; // tDQSQ  ns    DQS-DQ skew, DQS to last DQ valid, per group, per access
    parameter tMRD             =    10.0; // tMRD   ns    Load Mode Register command cycle time
    parameter tRAP             =    15.0; // tRAP   ns    ACTIVE to READ with Auto precharge command
    parameter tRAS             =    40.0; // tRAS   ns    Active to Precharge command time
    parameter tRC              =    55.0; // tRC    ns    Active to Active/Auto Refresh command time
    parameter tRFC             =    70.0; // tRFC   ns    Refresh to Refresh Command interval time
    parameter tRCD             =    15.0; // tRCD   ns    Active to Read/Write command time
    parameter tRP              =    15.0; // tRP    ns    Precharge command period
    parameter tRRD             =    10.0; // tRRD   ns    Active bank a to Active bank b command time
    parameter tWR              =    15.0; // tWR    ns    Write recovery time
