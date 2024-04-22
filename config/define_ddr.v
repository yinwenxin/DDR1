//Command pin define
`define COMMAND     {ddr_cs_n, ddr_ras_n, ddr_cas_n, ddr_we_n}
//Command instruction define
`define COM_DESELECT    4'b1000
`define COM_NOP         4'b0111
`define COM_ACTIVE      4'b0011
`define COM_READ        4'b0101
`define COM_WRITE       4'b0100
`define COM_BURST_END   4'b0110
`define COM_PRECHARGE   4'b0010
`define COM_REFRESH     4'b0001
`define COM_LMR         4'b0000
//Mode register pin define
`define MR_COMMAND  {ddr_ba, ddr_a}