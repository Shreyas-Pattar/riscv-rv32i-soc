`timescale 1ns / 1ps

module hazard_unit (
    // Decode Stage Registers
    input  logic [4:0]  if_id_rs1,
    input  logic [4:0]  if_id_rs2,

    // Execute Stage Signals
    input  logic [4:0]  id_ex_rd,
    input  logic        id_ex_mem_read,

    // Branch / Jump Signals from EX Stage
    input  logic        ex_branch,      // CRUCIAL: Must check if instruction is actually a branch!
    input  logic        branch_taken,
    input  logic        ex_jal,
    input  logic        ex_jalr,

    // Bus / Memory Subsystem Backpressure
    input  logic        bus_stall,

    // Output Pipeline Stall Controls
    output logic        pc_en,
    output logic        if_id_stall,
    output logic        id_ex_stall,
    output logic        ex_mem_stall,
    output logic        mem_wb_stall,

    // Output Pipeline Flush Controls
    output logic        if_id_flush,
    output logic        id_ex_flush
);

    logic load_use_hazard;
    logic pc_redirect;

    // A branch redirect ONLY happens if it's a branch AND condition is met!
    assign pc_redirect = (ex_branch && branch_taken) || ex_jal || ex_jalr;

    // Detect Load-Use data hazard
    assign load_use_hazard = id_ex_mem_read &&
                             (id_ex_rd != 5'd0) &&
                             ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));

    always_comb begin
        // Default: Normal execution pipeline flow
        pc_en        = 1'b1;
        if_id_stall  = 1'b0;
        id_ex_stall  = 1'b0;
        ex_mem_stall = 1'b0;
        mem_wb_stall = 1'b0;
        if_id_flush  = 1'b0;
        id_ex_flush  = 1'b0;

        // Priority 1: Bus Stalls
        if (bus_stall) begin
            pc_en        = 1'b0;
            if_id_stall  = 1'b1;
            id_ex_stall  = 1'b1;
            ex_mem_stall = 1'b1;
            mem_wb_stall = 1'b1;
        end
        // Priority 2: Control Hazards (Redirect)
        else if (pc_redirect) begin
            if_id_flush = 1'b1;
            id_ex_flush = 1'b1;
        end
        // Priority 3: Load-Use Hazard Stall
        else if (load_use_hazard) begin
            pc_en       = 1'b0;
            if_id_stall = 1'b1;
            id_ex_flush = 1'b1;
        end
    end

endmodule