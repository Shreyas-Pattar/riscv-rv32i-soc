`timescale 1ns / 1ps

module imm_gen (
    input  logic [31:0] inst,
    output logic [31:0] imm_ext
);

    logic [6:0] opcode;
    assign opcode = inst[6:0];

    always_comb begin
        case (opcode)
            // I-Type: ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI, JALR, Loads (LB, LH, LW, LBU, LHU)
            7'b0010011,
            7'b1100111,
            7'b0000011: begin
                imm_ext = {{20{inst[31]}}, inst[31:20]};
            end

            // S-Type: SB, SH, SW
            7'b0100011: begin
                imm_ext = {{20{inst[31]}}, inst[31:25], inst[11:7]};
            end

            // B-Type: BEQ, BNE, BLT, BGE, BLTU, BGEU
            7'b1100011: begin
                imm_ext = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
            end

            // U-Type: LUI, AUIPC
            7'b0110111,
            7'b0010111: begin
                imm_ext = {inst[31:12], 12'b0};
            end

            // J-Type: JAL
            7'b1101111: begin
                imm_ext = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
            end

            default: begin
                imm_ext = 32'h0000_0000;
            end
        endcase
    end

endmodule