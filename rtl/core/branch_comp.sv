`timescale 1ns / 1ps

module branch_comp (
    input  logic [2:0]  funct3,
    input  logic [31:0] op_a,
    input  logic [31:0] op_b,
    output logic        branch_taken
);

    always_comb begin
        case (funct3)
            3'b000:  branch_taken = (op_a == op_b);                        // BEQ
            3'b001:  branch_taken = (op_a != op_b);                        // BNE
            3'b100:  branch_taken = ($signed(op_a) < $signed(op_b));       // BLT
            3'b101:  branch_taken = ($signed(op_a) >= $signed(op_b));      // BGE
            3'b110:  branch_taken = (op_a < op_b);                         // BLTU
            3'b111:  branch_taken = (op_a >= op_b);                        // BGEU
            default: branch_taken = 1'b0;
        endcase
    end

endmodule