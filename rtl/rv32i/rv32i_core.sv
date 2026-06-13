module rv32i_core #(
    parameter logic [31:0] RESET_PC = 32'h8000_0000,
    parameter logic [31:0] MTVEC_RESET = 32'h8000_0100,
    parameter logic [31:0] RAM_BASE = 32'h8000_0000,
    parameter logic [31:0] RAM_SIZE_BYTES = 32'h0001_0000,
    parameter logic [31:0] TOHOST_ADDR = 32'h8000_FFF8,
    parameter logic [31:0] FROMHOST_ADDR = 32'h8000_FFFC
) (
    input  logic        clk,
    input  logic        rst_n,
    output logic        mem_valid,
    output logic        mem_instr,
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    output logic [3:0]  mem_wstrb,
    input  logic [31:0] mem_rdata,
    input  logic        mem_ready,
    output logic        trap
);

localparam logic [3:0] ALU_ADD  = 4'd0;
localparam logic [3:0] ALU_SUB  = 4'd1;
localparam logic [3:0] ALU_SLT  = 4'd2;
localparam logic [3:0] ALU_SLTU = 4'd3;
localparam logic [3:0] ALU_XOR  = 4'd4;
localparam logic [3:0] ALU_OR   = 4'd5;
localparam logic [3:0] ALU_AND  = 4'd6;
localparam logic [3:0] ALU_SLL  = 4'd7;
localparam logic [3:0] ALU_SRL  = 4'd8;
localparam logic [3:0] ALU_SRA  = 4'd9;
localparam logic [3:0] ALU_COPY_B = 4'd10;

localparam logic [2:0] WB_NONE = 3'd0;
localparam logic [2:0] WB_ALU  = 3'd1;
localparam logic [2:0] WB_PC4  = 3'd2;
localparam logic [2:0] WB_CSR  = 3'd3;
localparam logic [2:0] WB_LOAD = 3'd4;

localparam logic [1:0] CSR_NONE = 2'd0;
localparam logic [1:0] CSR_RW   = 2'd1;
localparam logic [1:0] CSR_RS   = 2'd2;
localparam logic [1:0] CSR_RC   = 2'd3;

localparam logic [31:0] MISA_VALUE = 32'h4000_0100;

logic [31:0] regfile [0:31];

logic [31:0] pc_reg;

logic        if_id_valid;
logic [31:0] if_id_pc;
logic [31:0] if_id_insn;
logic        if_id_fault_valid;
logic [31:0] if_id_fault_cause;
logic [31:0] if_id_fault_tval;

logic        id_ex_valid;
logic [31:0] id_ex_pc;
logic [31:0] id_ex_insn;
logic        id_ex_fault_valid;
logic [31:0] id_ex_fault_cause;
logic [31:0] id_ex_fault_tval;
logic [4:0]  id_ex_rs1;
logic [4:0]  id_ex_rs2;
logic [4:0]  id_ex_rd;
logic [31:0] id_ex_rs1_val;
logic [31:0] id_ex_rs2_val;
logic [31:0] id_ex_imm;
logic [3:0]  id_ex_alu_op;
logic        id_ex_src1_pc;
logic        id_ex_src2_imm;
logic [2:0]  id_ex_wb_select;
logic        id_ex_reg_write;
logic        id_ex_is_load;
logic        id_ex_is_store;
logic [2:0]  id_ex_mem_funct3;
logic        id_ex_is_branch;
logic [2:0]  id_ex_branch_funct3;
logic        id_ex_is_jal;
logic        id_ex_is_jalr;
logic        id_ex_illegal;
logic [1:0]  id_ex_csr_cmd;
logic        id_ex_csr_use_imm;
logic [11:0] id_ex_csr_addr;
logic        id_ex_system_ecall;
logic        id_ex_system_ebreak;
logic        id_ex_system_mret;

logic        ex_mem_valid;
logic [31:0] ex_mem_pc;
logic [4:0]  ex_mem_rd;
logic        ex_mem_reg_write;
logic [2:0]  ex_mem_wb_select;
logic [31:0] ex_mem_wb_data;
logic        ex_mem_is_load;
logic        ex_mem_is_store;
logic [2:0]  ex_mem_mem_funct3;
logic [31:0] ex_mem_addr_q;
logic [31:0] ex_mem_store_data;
logic        ex_mem_csr_write;
logic [11:0] ex_mem_csr_addr;
logic [31:0] ex_mem_csr_wdata;

logic        mem_wb_valid;
logic [4:0]  mem_wb_rd;
logic        mem_wb_reg_write;
logic [31:0] mem_wb_wdata;
logic        mem_wb_csr_write;
logic [11:0] mem_wb_csr_addr;
logic [31:0] mem_wb_csr_wdata;

logic [31:0] csr_mstatus;
logic [31:0] csr_mtvec;
logic [31:0] csr_mepc;
logic [31:0] csr_mcause;
logic [31:0] csr_mtval;
logic [31:0] csr_mscratch;

logic fatal_trap;

function automatic logic addr_in_ram(input logic [31:0] addr);
    logic [31:0] ram_limit;
    begin
        ram_limit = RAM_BASE + RAM_SIZE_BYTES;
        addr_in_ram = (addr >= RAM_BASE) && (addr < ram_limit);
    end
endfunction

function automatic logic addr_is_mmio(input logic [31:0] addr);
    begin
        addr_is_mmio = (addr == TOHOST_ADDR) || (addr == FROMHOST_ADDR);
    end
endfunction

function automatic logic [31:0] sext12(input logic [11:0] imm);
    begin
        sext12 = {{20{imm[11]}}, imm};
    end
endfunction

function automatic logic [31:0] sext13(input logic [12:0] imm);
    begin
        sext13 = {{19{imm[12]}}, imm};
    end
endfunction

function automatic logic [31:0] sext21(input logic [20:0] imm);
    begin
        sext21 = {{11{imm[20]}}, imm};
    end
endfunction

function automatic logic [31:0] csr_read(input logic [11:0] addr);
    begin
        unique case (addr)
            12'h300: csr_read = csr_mstatus;
            12'h301: csr_read = MISA_VALUE;
            12'h305: csr_read = csr_mtvec;
            12'h340: csr_read = csr_mscratch;
            12'h341: csr_read = csr_mepc;
            12'h342: csr_read = csr_mcause;
            12'h343: csr_read = csr_mtval;
            12'hF14: csr_read = 32'h0;
            default: csr_read = 32'h0;
        endcase
    end
endfunction

function automatic logic csr_exists(input logic [11:0] addr);
    begin
        unique case (addr)
            12'h300, 12'h301, 12'h305, 12'h340, 12'h341, 12'h342, 12'h343, 12'hF14:
                csr_exists = 1'b1;
            default:
                csr_exists = 1'b0;
        endcase
    end
endfunction

function automatic logic csr_read_only(input logic [11:0] addr);
    begin
        csr_read_only = (addr == 12'h301) || (addr == 12'hF14);
    end
endfunction

function automatic logic [31:0] load_data_format(
    input logic [2:0]  funct3,
    input logic [31:0] raw_word,
    input logic [1:0]  byte_offset
);
    logic [31:0] shifted;
    begin
        shifted = raw_word >> (byte_offset * 8);
        unique case (funct3)
            3'b000: load_data_format = {{24{shifted[7]}}, shifted[7:0]};
            3'b001: load_data_format = {{16{shifted[15]}}, shifted[15:0]};
            3'b010: load_data_format = shifted;
            3'b100: load_data_format = {24'h0, shifted[7:0]};
            3'b101: load_data_format = {16'h0, shifted[15:0]};
            default: load_data_format = 32'h0;
        endcase
    end
endfunction

function automatic logic [3:0] store_wstrb(
    input logic [2:0] funct3,
    input logic [1:0] byte_offset
);
    begin
        unique case (funct3)
            3'b000: store_wstrb = 4'b0001 << byte_offset;
            3'b001: store_wstrb = byte_offset[1] ? 4'b1100 : 4'b0011;
            3'b010: store_wstrb = 4'b1111;
            default: store_wstrb = 4'b0000;
        endcase
    end
endfunction

function automatic logic [31:0] store_wdata(
    input logic [2:0]  funct3,
    input logic [31:0] rs2_val,
    input logic [1:0]  byte_offset
);
    begin
        unique case (funct3)
            3'b000: store_wdata = {4{rs2_val[7:0]}} << (byte_offset * 8);
            3'b001: store_wdata = {2{rs2_val[15:0]}} << (byte_offset[1] * 16);
            3'b010: store_wdata = rs2_val;
            default: store_wdata = 32'h0;
        endcase
    end
endfunction

logic [31:0] if_insn;
logic [6:0]  dec_opcode;
logic [2:0]  dec_funct3;
logic [6:0]  dec_funct7;
logic [4:0]  dec_rs1;
logic [4:0]  dec_rs2;
logic [4:0]  dec_rd;

logic [31:0] dec_imm_i;
logic [31:0] dec_imm_s;
logic [31:0] dec_imm_b;
logic [31:0] dec_imm_u;
logic [31:0] dec_imm_j;

logic        dec_uses_rs1;
logic        dec_uses_rs2;
logic [31:0] dec_imm;
logic [3:0]  dec_alu_op;
logic        dec_src1_pc;
logic        dec_src2_imm;
logic [2:0]  dec_wb_select;
logic        dec_reg_write;
logic        dec_is_load;
logic        dec_is_store;
logic [2:0]  dec_mem_funct3;
logic        dec_is_branch;
logic [2:0]  dec_branch_funct3;
logic        dec_is_jal;
logic        dec_is_jalr;
logic        dec_illegal;
logic [1:0]  dec_csr_cmd;
logic        dec_csr_use_imm;
logic [11:0] dec_csr_addr;
logic        dec_system_ecall;
logic        dec_system_ebreak;
logic        dec_system_mret;

assign if_insn   = if_id_insn;
assign dec_opcode = if_insn[6:0];
assign dec_rd     = if_insn[11:7];
assign dec_funct3 = if_insn[14:12];
assign dec_rs1    = if_insn[19:15];
assign dec_rs2    = if_insn[24:20];
assign dec_funct7 = if_insn[31:25];
assign dec_imm_i  = sext12(if_insn[31:20]);
assign dec_imm_s  = sext12({if_insn[31:25], if_insn[11:7]});
assign dec_imm_b  = sext13({if_insn[31], if_insn[7], if_insn[30:25], if_insn[11:8], 1'b0});
assign dec_imm_u  = {if_insn[31:12], 12'h000};
assign dec_imm_j  = sext21({if_insn[31], if_insn[19:12], if_insn[20], if_insn[30:21], 1'b0});

always_comb begin
    dec_uses_rs1 = 1'b0;
    dec_uses_rs2 = 1'b0;
    dec_imm = 32'h0;
    dec_alu_op = ALU_ADD;
    dec_src1_pc = 1'b0;
    dec_src2_imm = 1'b0;
    dec_wb_select = WB_NONE;
    dec_reg_write = 1'b0;
    dec_is_load = 1'b0;
    dec_is_store = 1'b0;
    dec_mem_funct3 = dec_funct3;
    dec_is_branch = 1'b0;
    dec_branch_funct3 = dec_funct3;
    dec_is_jal = 1'b0;
    dec_is_jalr = 1'b0;
    dec_illegal = 1'b0;
    dec_csr_cmd = CSR_NONE;
    dec_csr_use_imm = 1'b0;
    dec_csr_addr = if_insn[31:20];
    dec_system_ecall = 1'b0;
    dec_system_ebreak = 1'b0;
    dec_system_mret = 1'b0;

    unique case (dec_opcode)
        7'b0110111: begin
            dec_imm = dec_imm_u;
            dec_alu_op = ALU_COPY_B;
            dec_src2_imm = 1'b1;
            dec_reg_write = 1'b1;
            dec_wb_select = WB_ALU;
        end
        7'b0010111: begin
            dec_imm = dec_imm_u;
            dec_alu_op = ALU_ADD;
            dec_src1_pc = 1'b1;
            dec_src2_imm = 1'b1;
            dec_reg_write = 1'b1;
            dec_wb_select = WB_ALU;
        end
        7'b1101111: begin
            dec_imm = dec_imm_j;
            dec_is_jal = 1'b1;
            dec_reg_write = 1'b1;
            dec_wb_select = WB_PC4;
        end
        7'b1100111: begin
            dec_uses_rs1 = 1'b1;
            dec_imm = dec_imm_i;
            dec_is_jalr = (dec_funct3 == 3'b000);
            dec_reg_write = 1'b1;
            dec_wb_select = WB_PC4;
            if (dec_funct3 != 3'b000) begin
                dec_illegal = 1'b1;
            end
        end
        7'b1100011: begin
            dec_uses_rs1 = 1'b1;
            dec_uses_rs2 = 1'b1;
            dec_is_branch = 1'b1;
            dec_imm = dec_imm_b;
            unique case (dec_funct3)
                3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111: begin end
                default: dec_illegal = 1'b1;
            endcase
        end
        7'b0000011: begin
            dec_uses_rs1 = 1'b1;
            dec_imm = dec_imm_i;
            dec_src2_imm = 1'b1;
            dec_is_load = 1'b1;
            dec_reg_write = 1'b1;
            dec_wb_select = WB_LOAD;
            unique case (dec_funct3)
                3'b000, 3'b001, 3'b010, 3'b100, 3'b101: begin end
                default: dec_illegal = 1'b1;
            endcase
        end
        7'b0100011: begin
            dec_uses_rs1 = 1'b1;
            dec_uses_rs2 = 1'b1;
            dec_imm = dec_imm_s;
            dec_src2_imm = 1'b1;
            dec_is_store = 1'b1;
            unique case (dec_funct3)
                3'b000, 3'b001, 3'b010: begin end
                default: dec_illegal = 1'b1;
            endcase
        end
        7'b0010011: begin
            dec_uses_rs1 = 1'b1;
            dec_imm = dec_imm_i;
            dec_src2_imm = 1'b1;
            dec_reg_write = 1'b1;
            dec_wb_select = WB_ALU;
            unique case (dec_funct3)
                3'b000: dec_alu_op = ALU_ADD;
                3'b010: dec_alu_op = ALU_SLT;
                3'b011: dec_alu_op = ALU_SLTU;
                3'b100: dec_alu_op = ALU_XOR;
                3'b110: dec_alu_op = ALU_OR;
                3'b111: dec_alu_op = ALU_AND;
                3'b001: begin
                    dec_alu_op = ALU_SLL;
                    if (dec_funct7 != 7'b0000000) begin
                        dec_illegal = 1'b1;
                    end
                end
                3'b101: begin
                    if (dec_funct7 == 7'b0000000) begin
                        dec_alu_op = ALU_SRL;
                    end else if (dec_funct7 == 7'b0100000) begin
                        dec_alu_op = ALU_SRA;
                    end else begin
                        dec_illegal = 1'b1;
                    end
                end
                default: dec_illegal = 1'b1;
            endcase
        end
        7'b0110011: begin
            dec_uses_rs1 = 1'b1;
            dec_uses_rs2 = 1'b1;
            dec_reg_write = 1'b1;
            dec_wb_select = WB_ALU;
            unique case ({dec_funct7, dec_funct3})
                {7'b0000000, 3'b000}: dec_alu_op = ALU_ADD;
                {7'b0100000, 3'b000}: dec_alu_op = ALU_SUB;
                {7'b0000000, 3'b001}: dec_alu_op = ALU_SLL;
                {7'b0000000, 3'b010}: dec_alu_op = ALU_SLT;
                {7'b0000000, 3'b011}: dec_alu_op = ALU_SLTU;
                {7'b0000000, 3'b100}: dec_alu_op = ALU_XOR;
                {7'b0000000, 3'b101}: dec_alu_op = ALU_SRL;
                {7'b0100000, 3'b101}: dec_alu_op = ALU_SRA;
                {7'b0000000, 3'b110}: dec_alu_op = ALU_OR;
                {7'b0000000, 3'b111}: dec_alu_op = ALU_AND;
                default: dec_illegal = 1'b1;
            endcase
        end
        7'b0001111: begin
            if (dec_funct3 != 3'b000) begin
                dec_illegal = 1'b1;
            end
        end
        7'b1110011: begin
            if (dec_funct3 == 3'b000) begin
                unique case (if_insn[31:20])
                    12'h000: dec_system_ecall = 1'b1;
                    12'h001: dec_system_ebreak = 1'b1;
                    12'h302: dec_system_mret = 1'b1;
                    default: dec_illegal = 1'b1;
                endcase
            end else begin
                dec_reg_write = 1'b1;
                dec_wb_select = WB_CSR;
                unique case (dec_funct3)
                    3'b001: begin
                        dec_uses_rs1 = 1'b1;
                        dec_csr_cmd = CSR_RW;
                    end
                    3'b010: begin
                        dec_uses_rs1 = 1'b1;
                        dec_csr_cmd = CSR_RS;
                    end
                    3'b011: begin
                        dec_uses_rs1 = 1'b1;
                        dec_csr_cmd = CSR_RC;
                    end
                    3'b101: begin
                        dec_csr_use_imm = 1'b1;
                        dec_csr_cmd = CSR_RW;
                    end
                    3'b110: begin
                        dec_csr_use_imm = 1'b1;
                        dec_csr_cmd = CSR_RS;
                    end
                    3'b111: begin
                        dec_csr_use_imm = 1'b1;
                        dec_csr_cmd = CSR_RC;
                    end
                    default: dec_illegal = 1'b1;
                endcase
            end
        end
        default: begin
            dec_illegal = 1'b1;
        end
    endcase
end

logic load_use_stall;
assign load_use_stall = id_ex_valid && id_ex_is_load && (id_ex_rd != 5'd0) &&
    !if_id_fault_valid &&
    ((dec_uses_rs1 && (dec_rs1 == id_ex_rd)) || (dec_uses_rs2 && (dec_rs2 == id_ex_rd)));

logic [31:0] ex_rs1_fwd;
logic [31:0] ex_rs2_fwd;
logic [31:0] ex_alu_a;
logic [31:0] ex_alu_b;
logic [31:0] ex_alu_result;
logic        ex_branch_taken;
logic [31:0] ex_redirect_pc;
logic        ex_redirect_valid;
logic        ex_trap_valid;
logic [31:0] ex_trap_cause;
logic [31:0] ex_trap_tval;
logic [31:0] ex_csr_old;
logic [31:0] ex_csr_source;
logic [31:0] ex_csr_new;
logic        ex_csr_write_attempt;
logic        ex_csr_write_valid;
logic [31:0] ex_wb_data;

always_comb begin
    ex_rs1_fwd = id_ex_rs1_val;
    if (ex_mem_valid && ex_mem_reg_write && !ex_mem_is_load && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1)) begin
        ex_rs1_fwd = ex_mem_wb_data;
    end else if (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) begin
        ex_rs1_fwd = mem_wb_wdata;
    end

    ex_rs2_fwd = id_ex_rs2_val;
    if (ex_mem_valid && ex_mem_reg_write && !ex_mem_is_load && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2)) begin
        ex_rs2_fwd = ex_mem_wb_data;
    end else if (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2)) begin
        ex_rs2_fwd = mem_wb_wdata;
    end
end

assign ex_alu_a = id_ex_src1_pc ? id_ex_pc : ex_rs1_fwd;
assign ex_alu_b = id_ex_src2_imm ? id_ex_imm : ex_rs2_fwd;

always_comb begin
    unique case (id_ex_alu_op)
        ALU_ADD:    ex_alu_result = ex_alu_a + ex_alu_b;
        ALU_SUB:    ex_alu_result = ex_alu_a - ex_alu_b;
        ALU_SLT:    ex_alu_result = ($signed(ex_alu_a) < $signed(ex_alu_b)) ? 32'd1 : 32'd0;
        ALU_SLTU:   ex_alu_result = (ex_alu_a < ex_alu_b) ? 32'd1 : 32'd0;
        ALU_XOR:    ex_alu_result = ex_alu_a ^ ex_alu_b;
        ALU_OR:     ex_alu_result = ex_alu_a | ex_alu_b;
        ALU_AND:    ex_alu_result = ex_alu_a & ex_alu_b;
        ALU_SLL:    ex_alu_result = ex_alu_a << ex_alu_b[4:0];
        ALU_SRL:    ex_alu_result = ex_alu_a >> ex_alu_b[4:0];
        ALU_SRA:    ex_alu_result = $signed(ex_alu_a) >>> ex_alu_b[4:0];
        ALU_COPY_B: ex_alu_result = ex_alu_b;
        default:    ex_alu_result = 32'h0;
    endcase
end

always_comb begin
    unique case (id_ex_branch_funct3)
        3'b000: ex_branch_taken = (ex_rs1_fwd == ex_rs2_fwd);
        3'b001: ex_branch_taken = (ex_rs1_fwd != ex_rs2_fwd);
        3'b100: ex_branch_taken = ($signed(ex_rs1_fwd) < $signed(ex_rs2_fwd));
        3'b101: ex_branch_taken = ($signed(ex_rs1_fwd) >= $signed(ex_rs2_fwd));
        3'b110: ex_branch_taken = (ex_rs1_fwd < ex_rs2_fwd);
        3'b111: ex_branch_taken = (ex_rs1_fwd >= ex_rs2_fwd);
        default: ex_branch_taken = 1'b0;
    endcase
end

always_comb begin
    ex_redirect_valid = 1'b0;
    ex_redirect_pc = 32'h0;

    if (id_ex_is_branch && ex_branch_taken) begin
        ex_redirect_valid = 1'b1;
        ex_redirect_pc = id_ex_pc + id_ex_imm;
    end else if (id_ex_is_jal) begin
        ex_redirect_valid = 1'b1;
        ex_redirect_pc = id_ex_pc + id_ex_imm;
    end else if (id_ex_is_jalr) begin
        ex_redirect_valid = 1'b1;
        ex_redirect_pc = (ex_rs1_fwd + id_ex_imm) & 32'hFFFF_FFFE;
    end else if (id_ex_system_mret) begin
        ex_redirect_valid = 1'b1;
        ex_redirect_pc = {csr_mepc[31:2], 2'b00};
    end
end

assign ex_csr_old = csr_read(id_ex_csr_addr);
assign ex_csr_source = id_ex_csr_use_imm ? {27'h0, id_ex_rs1} : ex_rs1_fwd;
assign ex_csr_write_attempt =
    (id_ex_csr_cmd == CSR_RW) ||
    (((id_ex_csr_cmd == CSR_RS) || (id_ex_csr_cmd == CSR_RC)) && (ex_csr_source != 32'h0));

always_comb begin
    unique case (id_ex_csr_cmd)
        CSR_RW: ex_csr_new = ex_csr_source;
        CSR_RS: ex_csr_new = ex_csr_old | ex_csr_source;
        CSR_RC: ex_csr_new = ex_csr_old & ~ex_csr_source;
        default: ex_csr_new = ex_csr_old;
    endcase
end

assign ex_csr_write_valid = (id_ex_csr_cmd != CSR_NONE) && csr_exists(id_ex_csr_addr) &&
    !(csr_read_only(id_ex_csr_addr) && ex_csr_write_attempt);

always_comb begin
    unique case (id_ex_wb_select)
        WB_ALU:  ex_wb_data = ex_alu_result;
        WB_PC4:  ex_wb_data = id_ex_pc + 32'd4;
        WB_CSR:  ex_wb_data = ex_csr_old;
        default: ex_wb_data = 32'h0;
    endcase
end

always_comb begin
    ex_trap_valid = 1'b0;
    ex_trap_cause = 32'h0;
    ex_trap_tval = 32'h0;

    if (id_ex_fault_valid) begin
        ex_trap_valid = 1'b1;
        ex_trap_cause = id_ex_fault_cause;
        ex_trap_tval = id_ex_fault_tval;
    end else if (id_ex_illegal) begin
        ex_trap_valid = 1'b1;
        ex_trap_cause = 32'd2;
        ex_trap_tval = id_ex_insn;
    end else if ((id_ex_csr_cmd != CSR_NONE) && (!csr_exists(id_ex_csr_addr) ||
            (csr_read_only(id_ex_csr_addr) && ex_csr_write_attempt))) begin
        ex_trap_valid = 1'b1;
        ex_trap_cause = 32'd2;
        ex_trap_tval = id_ex_insn;
    end else if (id_ex_system_ecall) begin
        ex_trap_valid = 1'b1;
        ex_trap_cause = 32'd11;
    end else if (id_ex_system_ebreak) begin
        ex_trap_valid = 1'b1;
        ex_trap_cause = 32'd3;
    end else if (ex_redirect_valid && ex_redirect_pc[1:0] != 2'b00) begin
        ex_trap_valid = 1'b1;
        ex_trap_cause = 32'd0;
        ex_trap_tval = ex_redirect_pc;
    end
end

logic mem_stage_fault;
logic [31:0] mem_stage_fault_cause;
logic [31:0] mem_stage_fault_tval;
logic mem_stage_uses_bus;
logic mem_stage_hold;
logic [31:0] mem_stage_wdata;
logic [3:0]  mem_stage_wstrb;
logic [31:0] mem_stage_load_data;
logic [31:0] mem_stage_wb_data;

always_comb begin
    mem_stage_fault = 1'b0;
    mem_stage_fault_cause = 32'h0;
    mem_stage_fault_tval = 32'h0;
    mem_stage_uses_bus = ex_mem_valid && (ex_mem_is_load || ex_mem_is_store);
    mem_stage_wdata = 32'h0;
    mem_stage_wstrb = 4'h0;

    if (ex_mem_valid && (ex_mem_is_load || ex_mem_is_store)) begin
        if (!(addr_in_ram(ex_mem_addr_q) || addr_is_mmio(ex_mem_addr_q))) begin
            mem_stage_fault = 1'b1;
            mem_stage_fault_cause = ex_mem_is_load ? 32'd5 : 32'd7;
            mem_stage_fault_tval = ex_mem_addr_q;
        end else if (addr_is_mmio(ex_mem_addr_q) && (ex_mem_mem_funct3 != 3'b010)) begin
            mem_stage_fault = 1'b1;
            mem_stage_fault_cause = ex_mem_is_load ? 32'd5 : 32'd7;
            mem_stage_fault_tval = ex_mem_addr_q;
        end else begin
            unique case (ex_mem_mem_funct3)
                3'b000: begin end
                3'b001, 3'b101: begin
                    if (ex_mem_addr_q[0] != 1'b0) begin
                        mem_stage_fault = 1'b1;
                        mem_stage_fault_cause = ex_mem_is_load ? 32'd4 : 32'd6;
                        mem_stage_fault_tval = ex_mem_addr_q;
                    end
                end
                3'b010: begin
                    if (ex_mem_addr_q[1:0] != 2'b00) begin
                        mem_stage_fault = 1'b1;
                        mem_stage_fault_cause = ex_mem_is_load ? 32'd4 : 32'd6;
                        mem_stage_fault_tval = ex_mem_addr_q;
                    end
                end
                3'b000, 3'b100: begin end
                default: begin
                    mem_stage_fault = 1'b1;
                    mem_stage_fault_cause = ex_mem_is_load ? 32'd2 : 32'd2;
                    mem_stage_fault_tval = ex_mem_addr_q;
                end
            endcase
        end
    end

    if (ex_mem_is_store && !mem_stage_fault) begin
        mem_stage_wstrb = store_wstrb(ex_mem_mem_funct3, ex_mem_addr_q[1:0]);
        mem_stage_wdata = store_wdata(ex_mem_mem_funct3, ex_mem_store_data, ex_mem_addr_q[1:0]);
    end
end

assign mem_stage_hold = mem_stage_uses_bus && !mem_stage_fault && !mem_ready;
assign mem_stage_load_data = load_data_format(ex_mem_mem_funct3, mem_rdata, ex_mem_addr_q[1:0]);
assign mem_stage_wb_data = ex_mem_is_load ? mem_stage_load_data : ex_mem_wb_data;

logic fetch_will_issue;
logic fetch_fault_valid;
logic [31:0] fetch_fault_cause;
logic [31:0] fetch_fault_tval;
logic fetch_bus_ready;
logic use_mem_bus;

assign use_mem_bus = mem_stage_uses_bus && !mem_stage_fault;
assign fetch_will_issue = !fatal_trap && !mem_stage_hold && !load_use_stall && !use_mem_bus;
assign fetch_fault_valid = fetch_will_issue && (!addr_in_ram(pc_reg) || (pc_reg[1:0] != 2'b00));
assign fetch_fault_cause = !addr_in_ram(pc_reg) ? 32'd1 : 32'd0;
assign fetch_fault_tval = pc_reg;
assign fetch_bus_ready = fetch_will_issue && !fetch_fault_valid && mem_ready;

always_comb begin
    mem_valid = 1'b0;
    mem_instr = 1'b0;
    mem_addr = 32'h0;
    mem_wdata = 32'h0;
    mem_wstrb = 4'h0;

    if (use_mem_bus) begin
        mem_valid = 1'b1;
        mem_instr = 1'b0;
        mem_addr = ex_mem_addr_q;
        mem_wdata = mem_stage_wdata;
        mem_wstrb = ex_mem_is_store ? mem_stage_wstrb : 4'h0;
    end else if (fetch_will_issue && !fetch_fault_valid) begin
        mem_valid = 1'b1;
        mem_instr = 1'b1;
        mem_addr = pc_reg;
    end
end

integer i;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc_reg <= RESET_PC;
        if_id_valid <= 1'b0;
        if_id_pc <= 32'h0;
        if_id_insn <= 32'h0000_0013;
        if_id_fault_valid <= 1'b0;
        if_id_fault_cause <= 32'h0;
        if_id_fault_tval <= 32'h0;
        id_ex_valid <= 1'b0;
        id_ex_pc <= 32'h0;
        id_ex_insn <= 32'h0;
        id_ex_fault_valid <= 1'b0;
        id_ex_fault_cause <= 32'h0;
        id_ex_fault_tval <= 32'h0;
        id_ex_rs1 <= 5'h0;
        id_ex_rs2 <= 5'h0;
        id_ex_rd <= 5'h0;
        id_ex_rs1_val <= 32'h0;
        id_ex_rs2_val <= 32'h0;
        id_ex_imm <= 32'h0;
        id_ex_alu_op <= ALU_ADD;
        id_ex_src1_pc <= 1'b0;
        id_ex_src2_imm <= 1'b0;
        id_ex_wb_select <= WB_NONE;
        id_ex_reg_write <= 1'b0;
        id_ex_is_load <= 1'b0;
        id_ex_is_store <= 1'b0;
        id_ex_mem_funct3 <= 3'h0;
        id_ex_is_branch <= 1'b0;
        id_ex_branch_funct3 <= 3'h0;
        id_ex_is_jal <= 1'b0;
        id_ex_is_jalr <= 1'b0;
        id_ex_illegal <= 1'b0;
        id_ex_csr_cmd <= CSR_NONE;
        id_ex_csr_use_imm <= 1'b0;
        id_ex_csr_addr <= 12'h0;
        id_ex_system_ecall <= 1'b0;
        id_ex_system_ebreak <= 1'b0;
        id_ex_system_mret <= 1'b0;
        ex_mem_valid <= 1'b0;
        ex_mem_pc <= 32'h0;
        ex_mem_rd <= 5'h0;
        ex_mem_reg_write <= 1'b0;
        ex_mem_wb_select <= WB_NONE;
        ex_mem_wb_data <= 32'h0;
        ex_mem_is_load <= 1'b0;
        ex_mem_is_store <= 1'b0;
        ex_mem_mem_funct3 <= 3'h0;
        ex_mem_addr_q <= 32'h0;
        ex_mem_store_data <= 32'h0;
        ex_mem_csr_write <= 1'b0;
        ex_mem_csr_addr <= 12'h0;
        ex_mem_csr_wdata <= 32'h0;
        mem_wb_valid <= 1'b0;
        mem_wb_rd <= 5'h0;
        mem_wb_reg_write <= 1'b0;
        mem_wb_wdata <= 32'h0;
        mem_wb_csr_write <= 1'b0;
        mem_wb_csr_addr <= 12'h0;
        mem_wb_csr_wdata <= 32'h0;
        csr_mstatus <= 32'h0;
        csr_mtvec <= MTVEC_RESET;
        csr_mepc <= 32'h0;
        csr_mcause <= 32'h0;
        csr_mtval <= 32'h0;
        csr_mscratch <= 32'h0;
        fatal_trap <= 1'b0;
        for (i = 0; i < 32; i = i + 1) begin
            regfile[i] <= 32'h0;
        end
    end else begin
        if (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0)) begin
            regfile[mem_wb_rd] <= mem_wb_wdata;
        end
        regfile[0] <= 32'h0;

        if (mem_wb_valid && mem_wb_csr_write) begin
            unique case (mem_wb_csr_addr)
                12'h300: csr_mstatus <= mem_wb_csr_wdata;
                12'h305: csr_mtvec <= {mem_wb_csr_wdata[31:2], 2'b00};
                12'h340: csr_mscratch <= mem_wb_csr_wdata;
                12'h341: csr_mepc <= {mem_wb_csr_wdata[31:2], 2'b00};
                12'h342: csr_mcause <= mem_wb_csr_wdata;
                12'h343: csr_mtval <= mem_wb_csr_wdata;
                default: begin end
            endcase
        end

        mem_wb_valid <= 1'b0;
        mem_wb_rd <= 5'h0;
        mem_wb_reg_write <= 1'b0;
        mem_wb_wdata <= 32'h0;
        mem_wb_csr_write <= 1'b0;
        mem_wb_csr_addr <= 12'h0;
        mem_wb_csr_wdata <= 32'h0;

        if (mem_stage_hold) begin
            pc_reg <= pc_reg;
            if_id_valid <= if_id_valid;
            if_id_pc <= if_id_pc;
            if_id_insn <= if_id_insn;
            if_id_fault_valid <= if_id_fault_valid;
            if_id_fault_cause <= if_id_fault_cause;
            if_id_fault_tval <= if_id_fault_tval;
            id_ex_valid <= id_ex_valid;
            ex_mem_valid <= ex_mem_valid;
        end else begin
            if (ex_mem_valid && !mem_stage_fault) begin
                mem_wb_valid <= 1'b1;
                mem_wb_rd <= ex_mem_rd;
                mem_wb_reg_write <= ex_mem_reg_write;
                mem_wb_wdata <= mem_stage_wb_data;
                mem_wb_csr_write <= ex_mem_csr_write;
                mem_wb_csr_addr <= ex_mem_csr_addr;
                mem_wb_csr_wdata <= ex_mem_csr_wdata;
            end

            if (mem_stage_fault) begin
                csr_mepc <= {ex_mem_pc[31:2], 2'b00};
                csr_mcause <= mem_stage_fault_cause;
                csr_mtval <= mem_stage_fault_tval;
                csr_mstatus[7] <= csr_mstatus[3];
                csr_mstatus[3] <= 1'b0;
                csr_mstatus[12:11] <= 2'b11;
                ex_mem_valid <= 1'b0;
                id_ex_valid <= 1'b0;
                if_id_valid <= 1'b0;
                pc_reg <= {csr_mtvec[31:2], 2'b00};
            end else if (ex_trap_valid) begin
                csr_mepc <= {id_ex_pc[31:2], 2'b00};
                csr_mcause <= ex_trap_cause;
                csr_mtval <= ex_trap_tval;
                csr_mstatus[7] <= csr_mstatus[3];
                csr_mstatus[3] <= 1'b0;
                csr_mstatus[12:11] <= 2'b11;
                ex_mem_valid <= 1'b0;
                id_ex_valid <= 1'b0;
                if_id_valid <= 1'b0;
                pc_reg <= {csr_mtvec[31:2], 2'b00};
            end else begin
                ex_mem_valid <= id_ex_valid;
                ex_mem_pc <= id_ex_pc;
                ex_mem_rd <= id_ex_rd;
                ex_mem_reg_write <= id_ex_reg_write;
                ex_mem_wb_select <= id_ex_wb_select;
                ex_mem_wb_data <= ex_wb_data;
                ex_mem_is_load <= id_ex_is_load;
                ex_mem_is_store <= id_ex_is_store;
                ex_mem_mem_funct3 <= id_ex_mem_funct3;
                ex_mem_addr_q <= ex_alu_result;
                ex_mem_store_data <= ex_rs2_fwd;
                ex_mem_csr_write <= ex_csr_write_valid && ex_csr_write_attempt;
                ex_mem_csr_addr <= id_ex_csr_addr;
                ex_mem_csr_wdata <= ex_csr_new;

                if (ex_redirect_valid) begin
                    if_id_valid <= 1'b0;
                    id_ex_valid <= 1'b0;
                    pc_reg <= ex_redirect_pc;
                end else if (load_use_stall) begin
                    id_ex_valid <= 1'b0;
                    pc_reg <= pc_reg;
                end else begin
                    id_ex_valid <= if_id_valid;
                    id_ex_pc <= if_id_pc;
                    id_ex_insn <= if_id_insn;
                    id_ex_fault_valid <= if_id_fault_valid;
                    id_ex_fault_cause <= if_id_fault_cause;
                    id_ex_fault_tval <= if_id_fault_tval;
                    id_ex_rs1 <= dec_rs1;
                    id_ex_rs2 <= dec_rs2;
                    id_ex_rd <= dec_rd;
                    id_ex_rs1_val <= regfile[dec_rs1];
                    id_ex_rs2_val <= regfile[dec_rs2];
                    id_ex_imm <= dec_imm;
                    id_ex_alu_op <= dec_alu_op;
                    id_ex_src1_pc <= dec_src1_pc;
                    id_ex_src2_imm <= dec_src2_imm;
                    id_ex_wb_select <= dec_wb_select;
                    id_ex_reg_write <= dec_reg_write;
                    id_ex_is_load <= dec_is_load;
                    id_ex_is_store <= dec_is_store;
                    id_ex_mem_funct3 <= dec_mem_funct3;
                    id_ex_is_branch <= dec_is_branch;
                    id_ex_branch_funct3 <= dec_branch_funct3;
                    id_ex_is_jal <= dec_is_jal;
                    id_ex_is_jalr <= dec_is_jalr;
                    id_ex_illegal <= dec_illegal;
                    id_ex_csr_cmd <= dec_csr_cmd;
                    id_ex_csr_use_imm <= dec_csr_use_imm;
                    id_ex_csr_addr <= dec_csr_addr;
                    id_ex_system_ecall <= dec_system_ecall;
                    id_ex_system_ebreak <= dec_system_ebreak;
                    id_ex_system_mret <= dec_system_mret;

                    if (fetch_fault_valid) begin
                        if_id_valid <= 1'b1;
                        if_id_pc <= pc_reg;
                        if_id_insn <= 32'h0000_0013;
                        if_id_fault_valid <= 1'b1;
                        if_id_fault_cause <= fetch_fault_cause;
                        if_id_fault_tval <= fetch_fault_tval;
                        pc_reg <= pc_reg + 32'd4;
                    end else if (fetch_bus_ready) begin
                        if_id_valid <= 1'b1;
                        if_id_pc <= pc_reg;
                        if_id_insn <= mem_rdata;
                        if_id_fault_valid <= 1'b0;
                        if_id_fault_cause <= 32'h0;
                        if_id_fault_tval <= 32'h0;
                        pc_reg <= pc_reg + 32'd4;
                    end else begin
                        if_id_valid <= 1'b0;
                    end
                end

                if (id_ex_system_mret && !ex_trap_valid) begin
                    csr_mstatus[3] <= csr_mstatus[7];
                    csr_mstatus[7] <= 1'b1;
                    csr_mstatus[12:11] <= 2'b00;
                end
            end
        end

        if (csr_mtvec[1:0] != 2'b00) begin
            fatal_trap <= 1'b1;
        end
    end
end

assign trap = fatal_trap;

endmodule
