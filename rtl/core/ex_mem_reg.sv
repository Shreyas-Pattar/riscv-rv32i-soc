`timescale 1ns / 1ps
import rv32i_pkg::*;

module ex_mem_reg (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        stall,

    // Datapath inputs
    input  logic [31:0] ex_alu_result,
    input  logic [31:0] ex_wdata,       // Store data (after forwarding selection)
    input  logic [4:0]  ex_rd,
    input  logic [31:0] ex_pc4,         // For JAL/JALR writeback
    input  logic [2:0]  ex_funct3,      // For load/store alignment (byte, half, word)

    // Control inputs
    input  logic        ex_mem_read,
    input  logic        ex_mem_write,
    input  logic        ex_reg_write,
    input  wb_sel_e     ex_wb_sel,

    // Datapath outputs
    output logic [31:0] mem_alu_result,
    output logic [31:0] mem_wdata,
    output logic [4:0]  mem_rd,
    output logic [31:0] mem_pc4,
    output logic [2:0]  mem_funct3,

    // Control outputs
    output logic        mem_mem_read,
    output logic        mem_mem_write,
    output logic        mem_reg_write,
    output wb_sel_e     mem_wb_sel
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_alu_result <= 32'h0;
            mem_wdata      <= 32'h0;
            mem_rd         <= 5'h0;
            mem_pc4        <= 32'h0;
            mem_funct3     <= 3'h0;
            mem_mem_read   <= 1'b0;
            mem_mem_write  <= 1'b0;
            mem_reg_write  <= 1'b0;
            mem_wb_sel     <= WB_SEL_ALU;
        end else if (!stall) begin
            mem_alu_result <= ex_alu_result;
            mem_wdata      <= ex_wdata;
            mem_rd         <= ex_rd;
            mem_pc4        <= ex_pc4;
            mem_funct3     <= ex_funct3;
            mem_mem_read   <= ex_mem_read;
            mem_mem_write  <= ex_mem_write;
            mem_reg_write  <= ex_reg_write;
            mem_wb_sel     <= ex_wb_sel;
        end
    end

endmodule