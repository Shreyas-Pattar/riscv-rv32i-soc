`timescale 1ns / 1ps

module if_id_reg (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        stall,
    input  logic        flush,
    input  logic [31:0] if_pc,
    input  logic [31:0] if_inst,
    output logic [31:0] id_pc,
    output logic [31:0] id_inst
);

    localparam bit [31:0] NOP_INST = 32'h0000_0013; // addi x0, x0, 0

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_pc   <= 32'h0000_0000;
            id_inst <= NOP_INST;
        end else if (flush) begin
            id_pc   <= 32'h0000_0000;
            id_inst <= NOP_INST;
        end else if (!stall) begin
            id_pc   <= if_pc;
            id_inst <= if_inst;
        end
    end

endmodule