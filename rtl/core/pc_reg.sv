`timescale 1ns / 1ps

module pc_reg #(
    parameter bit [31:0] RESET_ADDR = 32'h0000_0000
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        pc_en,      // Active-high enable (hazard stall / bus backpressure)
    input  logic [31:0] pc_next,    // Next PC target (PC+4, branch, or jump)
    output logic [31:0] pc          // Current PC output to IMEM / IF_ID
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= RESET_ADDR;
        end else if (pc_en) begin
            pc <= pc_next;
        end
    end

endmodule