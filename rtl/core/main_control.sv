`timescale 1ns / 1ps
import rv32i_pkg::*;

module main_control (
    input  logic [6:0]  opcode,

    // Control lines passed to ID/EX pipeline register
    output logic [1:0]  alu_op_type, // Fed to alu_control
    output alu_src_a_e  alu_src_a,   // 0: RS1, 1: PC
    output alu_src_b_e  alu_src_b,   // 0: RS2, 1: Immediate
    output logic        mem_read,    // Asserted for Load instructions
    output logic        mem_write,   // Asserted for Store instructions
    output logic        reg_write,   // Register file write enable
    output wb_sel_e     wb_sel,      // 00: ALU result, 01: Memory read data, 10: PC+4
    output logic        branch,      // Conditional branch (B-type)
    output logic        jal,         // JAL instruction
    output logic        jalr         // JALR instruction
);

    always_comb begin
        // Safe default assignments (zero out all signals to prevent any spurious asserts)
        alu_op_type = 2'b00;
        alu_src_a   = ALU_SRC_A_RS1;
        alu_src_b   = ALU_SRC_B_RS2;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        reg_write   = 1'b0;
        wb_sel      = WB_SEL_ALU;
        branch      = 1'b0;
        jal         = 1'b0;
        jalr        = 1'b0;

        case (opcode)
            // R-Type Instructions (ADD, SUB, SLL, SLT, etc.)
            OP_R_TYPE: begin
                alu_op_type = 2'b10;
                alu_src_a   = ALU_SRC_A_RS1;
                alu_src_b   = ALU_SRC_B_RS2;
                reg_write   = 1'b1;
                wb_sel      = WB_SEL_ALU;
            end

            // I-Type Arithmetic Instructions (ADDI, XORI, ORI, etc.)
            OP_I_IMM: begin
                alu_op_type = 2'b11;
                alu_src_a   = ALU_SRC_A_RS1;
                alu_src_b   = ALU_SRC_B_IMM;
                reg_write   = 1'b1;
                wb_sel      = WB_SEL_ALU;
            end

            // Load Instructions (LB, LH, LW, LBU, LHU)
            OP_LOAD: begin
                alu_op_type = 2'b00;
                alu_src_a   = ALU_SRC_A_RS1;
                alu_src_b   = ALU_SRC_B_IMM;
                mem_read    = 1'b1;
                reg_write   = 1'b1;
                wb_sel      = WB_SEL_MEM;
            end

            // Store Instructions (SB, SH, SW)
            OP_STORE: begin
                alu_op_type = 2'b00;
                alu_src_a   = ALU_SRC_A_RS1;
                alu_src_b   = ALU_SRC_B_IMM;
                mem_write   = 1'b1;
            end

            // Branch Instructions (BEQ, BNE, BLT, BGE, etc.)
            OP_BRANCH: begin
                alu_op_type = 2'b01;
                alu_src_a   = ALU_SRC_A_RS1;
                alu_src_b   = ALU_SRC_B_RS2;
                branch      = 1'b1;
            end

            // JAL (Jump and Link)
            OP_JAL: begin
                reg_write   = 1'b1;
                wb_sel      = WB_SEL_PC4;
                jal         = 1'b1;
            end

            // JALR (Jump and Link Register)
            OP_JALR: begin
                alu_op_type = 2'b00;
                alu_src_a   = ALU_SRC_A_RS1;
                alu_src_b   = ALU_SRC_B_IMM;
                reg_write   = 1'b1;
                wb_sel      = WB_SEL_PC4;
                jalr        = 1'b1;
            end

            // LUI (Load Upper Immediate)
            OP_LUI: begin
                alu_op_type = 2'b00;
                alu_src_a   = ALU_SRC_A_RS1;
                alu_src_b   = ALU_SRC_B_IMM;
                reg_write   = 1'b1;
                wb_sel      = WB_SEL_ALU;
            end

            // AUIPC (Add Upper Immediate to PC)
            OP_AUIPC: begin
                alu_op_type = 2'b00;
                alu_src_a   = ALU_SRC_A_PC;
                alu_src_b   = ALU_SRC_B_IMM;
                reg_write   = 1'b1;
                wb_sel      = WB_SEL_ALU;
            end

            default: begin
                // All outputs remain safely 0
            end
        endcase
    end

endmodule