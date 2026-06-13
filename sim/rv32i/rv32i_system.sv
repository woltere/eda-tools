module rv32i_system #(
    parameter logic [31:0] RESET_PC = 32'h8000_0000,
    parameter logic [31:0] RAM_BASE = 32'h8000_0000,
    parameter logic [31:0] RAM_SIZE_BYTES = 32'h0001_0000,
    parameter logic [31:0] TOHOST_ADDR = 32'h8000_FFF8,
    parameter logic [31:0] FROMHOST_ADDR = 32'h8000_FFFC
) (
    input  logic        clk,
    input  logic        rst_n,
    output logic        pass,
    output logic        fail,
    output logic [31:0] fail_code,
    output logic        trap
);

localparam int RAM_WORDS = RAM_SIZE_BYTES / 4;

logic        mem_valid;
logic        mem_instr;
logic [31:0] mem_addr;
logic [31:0] mem_wdata;
logic [3:0]  mem_wstrb;
logic [31:0] mem_rdata;
logic        mem_ready;

logic [31:0] ram [0:RAM_WORDS-1];
logic [31:0] tohost_reg;
logic [31:0] fromhost_reg;
string memfile;
integer idx;

rv32i_core #(
    .RESET_PC(RESET_PC),
    .MTVEC_RESET(32'h8000_0100),
    .RAM_BASE(RAM_BASE),
    .RAM_SIZE_BYTES(RAM_SIZE_BYTES),
    .TOHOST_ADDR(TOHOST_ADDR),
    .FROMHOST_ADDR(FROMHOST_ADDR)
) u_core (
    .clk(clk),
    .rst_n(rst_n),
    .mem_valid(mem_valid),
    .mem_instr(mem_instr),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_wstrb(mem_wstrb),
    .mem_rdata(mem_rdata),
    .mem_ready(mem_ready),
    .trap(trap)
);

function automatic logic addr_in_ram(input logic [31:0] addr);
    logic [31:0] ram_limit;
    begin
        ram_limit = RAM_BASE + RAM_SIZE_BYTES;
        addr_in_ram = (addr >= RAM_BASE) && (addr < ram_limit);
    end
endfunction

initial begin
    for (idx = 0; idx < RAM_WORDS; idx = idx + 1) begin
        ram[idx] = 32'h0000_0013;
    end
    tohost_reg = 32'h0;
    fromhost_reg = 32'h0;
    if ($value$plusargs("mem=%s", memfile)) begin
        $display("Loading memory image %0s", memfile);
        $readmemh(memfile, ram);
    end
end

always_comb begin
    mem_ready = mem_valid;
    mem_rdata = 32'h0;

    if (mem_valid) begin
        if (addr_in_ram(mem_addr)) begin
            mem_rdata = ram[(mem_addr - RAM_BASE) >> 2];
        end else if (mem_addr == TOHOST_ADDR) begin
            mem_rdata = tohost_reg;
        end else if (mem_addr == FROMHOST_ADDR) begin
            mem_rdata = fromhost_reg;
        end
    end
end

always_ff @(posedge clk) begin
    if (mem_valid && (mem_wstrb != 4'h0)) begin
        if (addr_in_ram(mem_addr)) begin
            if (mem_wstrb[0]) ram[(mem_addr - RAM_BASE) >> 2][7:0] <= mem_wdata[7:0];
            if (mem_wstrb[1]) ram[(mem_addr - RAM_BASE) >> 2][15:8] <= mem_wdata[15:8];
            if (mem_wstrb[2]) ram[(mem_addr - RAM_BASE) >> 2][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) ram[(mem_addr - RAM_BASE) >> 2][31:24] <= mem_wdata[31:24];
        end else if (mem_addr == TOHOST_ADDR) begin
            if (mem_wstrb == 4'hF) begin
                tohost_reg <= mem_wdata;
            end
        end else if (mem_addr == FROMHOST_ADDR) begin
            if (mem_wstrb == 4'hF) begin
                fromhost_reg <= mem_wdata;
            end
        end
    end
end

assign pass = (tohost_reg == 32'h1);
assign fail = (tohost_reg != 32'h0) && (tohost_reg != 32'h1);
assign fail_code = tohost_reg;

endmodule
