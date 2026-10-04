`timescale 1ns / 1ps

package rv32i_pkg;

    // Major RV32I Opcodes
    typedef enum logic [6:0] {
        OP_R_TYPE   = 7'b0110011, // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
        OP_I_IMM    = 7'b0010011, // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
        OP_LOAD     = 7'b0000011, // LB, LH, LW, LBU, LHU
        OP_STORE    = 7'b0100011, // SB, SH, SW
        OP_BRANCH   = 7'b1100011, // BEQ, BNE, BLT, BGE, BLTU, BGEU
        OP_JAL      = 7'b1101111, // JAL
        OP_JALR     = 7'b1100111, // JALR
        OP_LUI      = 7'b0110111, // LUI
        OP_AUIPC    = 7'b0010111  // AUIPC
    } opcode_e;

    // ALU Operations
    typedef enum logic [3:0] {
        ALU_ADD    = 4'b0000,
        ALU_SUB    = 4'b0001,
        ALU_SLL    = 4'b0010,
        ALU_SLT    = 4'b0011,
        ALU_SLTU   = 4'b0100,
        ALU_XOR    = 4'b0101,
        ALU_SRL    = 4'b0110,
        ALU_SRA    = 4'b0111,
        ALU_OR     = 4'b1000,
        ALU_AND    = 4'b1001,
        ALU_PASS_B = 4'b1010
    } alu_op_e;

    // Writeback Multiplexer Selection
    typedef enum logic [1:0] {
        WB_SEL_ALU  = 2'b00,
        WB_SEL_MEM  = 2'b01,
        WB_SEL_PC4  = 2'b10
    } wb_sel_e;

    // ALU Source Operands Multiplexer Selection
    typedef enum logic {
        ALU_SRC_A_RS1 = 1'b0,
        ALU_SRC_A_PC  = 1'b1
    } alu_src_a_e;

    typedef enum logic {
        ALU_SRC_B_RS2 = 1'b0,
        ALU_SRC_B_IMM = 1'b1
    } alu_src_b_e;

endpackage