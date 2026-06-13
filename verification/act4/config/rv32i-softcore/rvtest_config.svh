`ifndef RVTEST_CONFIG_SVH
`define RVTEST_CONFIG_SVH

localparam int unsigned RVTEST_XLEN = 32;
localparam logic [31:0] RVTEST_RESET_PC = 32'h8000_0000;
localparam logic [31:0] RVTEST_TRAP_VECTOR = 32'h8000_0100;
localparam logic [31:0] RVTEST_TOHOST = 32'h8000_FFF8;

`endif
