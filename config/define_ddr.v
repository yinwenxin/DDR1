`define COMMAND     {ddr_cs_n, ddr_ras_n, ddr_cas_n, ddr_we_n}
`define DESELECT    4'b1000
`define NOP         4'b0111
`define ACTIVE      4'b0011
`define READ        4'b0101
`define WRITE       4'b0100
`define BURST_END   4'b0110
`define PRECHARGE   4'b0010
`define REFRESH     4'b0001
`define LMR         4'b0000
`define MR_COMMAND  {ddr_ba, ddr_a}