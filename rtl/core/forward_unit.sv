`timescale 1ns / 1ps

module forward_unit (
    input  logic [4:0]  id_ex_rs1,
    input  logic [4:0]  id_ex_rs2,
    input  logic [4:0]  ex_mem_rd,
    input  logic        ex_mem_reg_write,
    input  logic [4:0]  mem_wb_rd,
    input  logic        mem_wb_reg_write,

    // 00: No forward (from ID/EX), 10: Forward from EX/MEM, 01: Forward from MEM/WB
    output logic [1:0]  forward_a,
    output logic [1:0]  forward_b
);

    // ==========================================
    // Forwarding for Operand A (RS1)
    // ==========================================
    always_comb begin
        // Default: No forwarding
        forward_a = 2'b00;

        // EX Hazard (EX/MEM -> EX)
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1)) begin
            forward_a = 2'b10;
        end
        // MEM Hazard (MEM/WB -> EX) - with EX priority suppression
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) begin
            forward_a = 2'b01;
        end
    end

    // ==========================================
    // Forwarding for Operand B (RS2)
    // ==========================================
    always_comb begin
        // Default: No forwarding
        forward_b = 2'b00;

        // EX Hazard (EX/MEM -> EX)
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2)) begin
            forward_b = 2'b10;
        end
        // MEM Hazard (MEM/WB -> EX) - with EX priority suppression
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2)) begin
            forward_b = 2'b01;
        end
    end

endmodule