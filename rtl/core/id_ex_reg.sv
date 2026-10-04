`timescale 1ns / 1ps
import rv32i_pkg::*;

module id_ex_reg (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        stall,
    input  logic        flush,

    // Datapath inputs
    input  logic [31:0] id_pc,
    input  logic [31:0] id_rdata1,
    input  logic [31:0] id_rdata2,
    input  logic [31:0] id_imm,
    input  logic [2:0]  id_funct3,
    input  logic [4:0]  id_rs1,
    input  logic [4:0]  id_rs2,
    input  logic [4:0]  id_rd,

    // Control inputs
    input  alu_op_e     id_alu_ctrl,
    input  alu_src_a_e  id_alu_src_a,
    input  alu_src_b_e  id_alu_src_b,
    input  logic        id_mem_read,
    input  logic        id_mem_write,
    input  logic        id_reg_write,
    input  wb_sel_e     id_wb_sel,
    input  logic        id_branch,
    input  logic        id_jal,
    input  logic        id_jalr,

    // Datapath outputs
    output logic [31:0] ex_pc,
    output logic [31:0] ex_rdata1,
    output logic [31:0] ex_rdata2,
    output logic [31:0] ex_imm,
    output logic [2:0]  ex_funct3,
    output logic [4:0]  ex_rs1,
    output logic [4:0]  ex_rs2,
    output logic [4:0]  ex_rd,

    // Control outputs
    output alu_op_e     ex_alu_ctrl,
    output alu_src_a_e  ex_alu_src_a,
    output alu_src_b_e  ex_alu_src_b,
    output logic        ex_mem_read,
    output logic        ex_mem_write,
    output logic        ex_reg_write,
    output wb_sel_e     ex_wb_sel,
    output logic        ex_branch,
    output logic        ex_jal,
    output logic        ex_jalr
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            ex_pc        <= 32'h0;
            ex_rdata1    <= 32'h0;
            ex_rdata2    <= 32'h0;
            ex_imm       <= 32'h0;
            ex_funct3    <= 3'h0;
            ex_rs1       <= 5'h0;
            ex_rs2       <= 5'h0;
            ex_rd        <= 5'h0;
            ex_alu_ctrl  <= ALU_ADD;
            ex_alu_src_a <= ALU_SRC_A_RS1;
            ex_alu_src_b <= ALU_SRC_B_RS2;
            ex_mem_read  <= 1'b0;
            ex_mem_write <= 1'b0;
            ex_reg_write <= 1'b0;
            ex_wb_sel    <= WB_SEL_ALU;
            ex_branch    <= 1'b0;
            ex_jal       <= 1'b0;
            ex_jalr      <= 1'b0;
        end else if (!stall) begin
            ex_pc        <= id_pc;
            ex_rdata1    <= id_rdata1;
            ex_rdata2    <= id_rdata2;
            ex_imm       <= id_imm;
            ex_funct3    <= id_funct3;
            ex_rs1       <= id_rs1;
            ex_rs2       <= id_rs2;
            ex_rd        <= id_rd;
            ex_alu_ctrl  <= id_alu_ctrl;
            ex_alu_src_a <= id_alu_src_a;
            ex_alu_src_b <= id_alu_src_b;
            ex_mem_read  <= id_mem_read;
            ex_mem_write <= id_mem_write;
            ex_reg_write <= id_reg_write;
            ex_wb_sel    <= id_wb_sel;
            ex_branch    <= id_branch;
            ex_jal       <= id_jal;
            ex_jalr      <= id_jalr;
        end
    end

endmodule