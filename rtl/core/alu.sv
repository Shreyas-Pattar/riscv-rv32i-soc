`timescale 1ns / 1ps
import rv32i_pkg::*;

module alu (
    input  logic [31:0] alu_a,
    input  logic [31:0] alu_b,
    input  alu_op_e     alu_ctrl,
    output logic [31:0] alu_result,
    output logic        zero
);

    wire [4:0] shamt = alu_b[4:0];

    always_comb begin
        case (alu_ctrl)
            ALU_ADD:    alu_result = alu_a + alu_b;
            ALU_SUB:    alu_result = alu_a - alu_b;
            ALU_SLL:    alu_result = alu_a << shamt;
            ALU_SLT:    alu_result = ($signed(alu_a) < $signed(alu_b)) ? 32'd1 : 32'd0;
            ALU_SLTU:   alu_result = (alu_a < alu_b) ? 32'd1 : 32'd0;
            ALU_XOR:    alu_result = alu_a ^ alu_b;
            ALU_SRL:    alu_result = alu_a >> shamt;
            ALU_SRA:    alu_result = $signed(alu_a) >>> shamt;
            ALU_OR:     alu_result = alu_a | alu_b;
            ALU_AND:    alu_result = alu_a & alu_b;
            ALU_PASS_B: alu_result = alu_b;
            default:    alu_result = 32'h0000_0000;
        endcase
    end

    assign zero = (alu_result == 32'h0000_0000);

endmodule