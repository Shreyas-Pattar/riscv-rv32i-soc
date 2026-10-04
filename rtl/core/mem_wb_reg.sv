`timescale 1ns / 1ps
import rv32i_pkg::*;

module mem_wb_reg (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        stall,

    // Datapath inputs
    input  logic [31:0] mem_alu_result,
    input  logic [31:0] mem_rdata,      // Data read from memory/APB (aligned)
    input  logic [31:0] mem_pc4,
    input  logic [4:0]  mem_rd,

    // Control inputs
    input  logic        mem_reg_write,
    input  wb_sel_e     mem_wb_sel,

    // Datapath outputs
    output logic [31:0] wb_alu_result,
    output logic [31:0] wb_rdata,
    output logic [31:0] wb_pc4,
    output logic [4:0]  wb_rd,

    // Control outputs
    output logic        wb_reg_write,
    output wb_sel_e     wb_wb_sel
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_alu_result <= 32'h0;
            wb_rdata      <= 32'h0;
            wb_pc4        <= 32'h0;
            wb_rd         <= 5'h0;
            wb_reg_write  <= 1'b0;
            wb_wb_sel     <= WB_SEL_ALU;
        end else if (!stall) begin
            wb_alu_result <= mem_alu_result;
            wb_rdata      <= mem_rdata;
            wb_pc4        <= mem_pc4;
            wb_rd         <= mem_rd;
            wb_reg_write  <= mem_reg_write;
            wb_wb_sel     <= mem_wb_sel;
        end
    end

endmodule