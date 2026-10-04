`timescale 1ns / 1ps
import rv32i_pkg::*;

module alu_control (
    input  logic [1:0]  alu_op_type, // 00: Load/Store/LUI/AUIPC, 01: Branch, 10: R-Type, 11: I-Type
    input  logic [2:0]  funct3,
    input  logic [6:0]  funct7,
    output alu_op_e     alu_ctrl
);

    always_comb begin
        case (alu_op_type)
            // ----------------------------------------------------
            // 00: Memory address generation or direct additions (LW, SW, AUIPC, LUI)
            // ----------------------------------------------------
            2'b00: alu_ctrl = ALU_ADD;

            // ----------------------------------------------------
            // 01: Branch operations (subtraction for comparison)
            // ----------------------------------------------------
            2'b01: alu_ctrl = ALU_SUB;

            // ----------------------------------------------------
            // 10: Register-Register operations (R-Type)
            // ----------------------------------------------------
            2'b10: begin
                case (funct3)
                    3'b000:  alu_ctrl = (funct7[5]) ? ALU_SUB : ALU_ADD; // SUB vs ADD
                    3'b001:  alu_ctrl = ALU_SLL;                          // SLL
                    3'b010:  alu_ctrl = ALU_SLT;                          // SLT
                    3'b011:  alu_ctrl = ALU_SLTU;                         // SLTU
                    3'b100:  alu_ctrl = ALU_XOR;                          // XOR
                    3'b101:  alu_ctrl = (funct7[5]) ? ALU_SRA : ALU_SRL; // SRA vs SRL
                    3'b110:  alu_ctrl = ALU_OR;                           // OR
                    3'b111:  alu_ctrl = ALU_AND;                          // AND
                    default: alu_ctrl = ALU_ADD;
                endcase
            end

            // ----------------------------------------------------
            // 11: Immediate operations (I-Type Arithmetic)
            // ----------------------------------------------------
            2'b11: begin
                case (funct3)
                    3'b000:  alu_ctrl = ALU_ADD;                          // ADDI
                    3'b001:  alu_ctrl = ALU_SLL;                          // SLLI
                    3'b010:  alu_ctrl = ALU_SLT;                          // SLTI
                    3'b011:  alu_ctrl = ALU_SLTU;                         // SLTIU
                    3'b100:  alu_ctrl = ALU_XOR;                          // XORI
                    3'b101:  alu_ctrl = (funct7[5]) ? ALU_SRA : ALU_SRL; // SRAI vs SRLI
                    3'b110:  alu_ctrl = ALU_OR;                           // ORI
                    3'b111:  alu_ctrl = ALU_AND;                          // ANDI
                    default: alu_ctrl = ALU_ADD;
                endcase
            end

            default: alu_ctrl = ALU_ADD;
        endcase
    end

endmodule