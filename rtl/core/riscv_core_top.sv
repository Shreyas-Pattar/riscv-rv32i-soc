`timescale 1ns / 1ps
import rv32i_pkg::*;

module riscv_core_top #(
    parameter bit [31:0] RESET_ADDR = 32'h0000_0000
) (
    input  logic        clk,
    input  logic        rst_n,

    // Instruction Memory Interface (Fetch Stage)
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,

    // AMBA APB3 Bus Master Interface (Data / MMIO)
    output logic [31:0] paddr,
    output logic        psel,
    output logic        penable,
    output logic        pwrite,
    output logic [31:0] pwdata,
    output logic [3:0]  pstrb,
    input  logic [31:0] prdata,
    input  logic        pready,
    input  logic        pslverr
);

    // ==========================================
    // Internal Wire Declarations
    // ==========================================

    // Hazard & Stall Wires
    logic pc_en;
    logic if_id_stall, id_ex_stall, ex_mem_stall, mem_wb_stall;
    logic if_id_flush, id_ex_flush;
    logic bus_stall;

    // Forwarding Wires
    logic [1:0] forward_a, forward_b;

    // --- IF Stage ---
    logic [31:0] if_pc_current;
    logic [31:0] if_pc_next;
    logic [31:0] if_pc_plus4;

    // --- ID Stage ---
    logic [31:0] id_pc;
    logic [31:0] id_inst;
    logic [4:0]  id_rs1, id_rs2, id_rd;
    logic [2:0]  id_funct3;
    logic [6:0]  id_funct7;
    logic [6:0]  id_opcode;
    logic [31:0] id_rdata1, id_rdata2;
    logic [31:0] id_imm;

    // ID Control
    logic [1:0]  id_alu_op_type;
    alu_op_e     id_alu_ctrl;
    alu_src_a_e  id_alu_src_a;
    alu_src_b_e  id_alu_src_b;
    logic        id_mem_read, id_mem_write, id_reg_write;
    wb_sel_e     id_wb_sel;
    logic        id_branch, id_jal, id_jalr;

    // --- EX Stage ---
    logic [31:0] ex_pc;
    logic [31:0] ex_rdata1, ex_rdata2;
    logic [31:0] ex_imm;
    logic [2:0]  ex_funct3;
    logic [4:0]  ex_rs1, ex_rs2, ex_rd;
    alu_op_e     ex_alu_ctrl;
    alu_src_a_e  ex_alu_src_a;
    alu_src_b_e  ex_alu_src_b;
    logic        ex_mem_read, ex_mem_write, ex_reg_write;
    wb_sel_e     ex_wb_sel;
    logic        ex_branch, ex_jal, ex_jalr;

    logic [31:0] ex_fwd_a, ex_fwd_b;
    logic [31:0] ex_alu_in_a, ex_alu_in_b;
    logic [31:0] ex_alu_result;
    logic        ex_alu_zero;
    logic        ex_branch_taken;
    logic [31:0] ex_branch_target;
    logic [31:0] ex_jump_target;
    logic [31:0] ex_pc_plus4;

    // --- MEM Stage ---
    logic [31:0] mem_alu_result;
    logic [31:0] mem_wdata;
    logic [4:0]  mem_rd;
    logic [31:0] mem_pc4;
    logic [2:0]  mem_funct3;
    logic        mem_mem_read, mem_mem_write, mem_reg_write;
    wb_sel_e     mem_wb_sel;

    logic [31:0] mem_raw_rdata;
    logic [31:0] mem_aligned_rdata;
    logic [31:0] mem_aligned_wdata;
    logic [3:0]  mem_wstrb;
    logic        mem_req;

    // --- WB Stage ---
    logic [31:0] wb_alu_result;
    logic [31:0] wb_rdata;
    logic [31:0] wb_pc4;
    logic [4:0]  wb_rd;
    logic        wb_reg_write;
    wb_sel_e     wb_wb_sel;
    logic [31:0] wb_final_data;

    // ==========================================
    // 1. INSTRUCTION FETCH (IF) STAGE
    // ==========================================
    assign if_pc_plus4 = if_pc_current + 32'd4;
    assign imem_addr   = if_pc_current;

    // Next PC selection: EX jump/branch targets override PC+4
    always_comb begin
        if (ex_jalr) begin
            if_pc_next = ex_jump_target;
        end else if (ex_jal || (ex_branch && ex_branch_taken)) begin
            if_pc_next = ex_branch_target;
        end else begin
            if_pc_next = if_pc_plus4;
        end
    end

    pc_reg #(
        .RESET_ADDR(RESET_ADDR)
    ) u_pc_reg (
        .clk     (clk),
        .rst_n   (rst_n),
        .pc_en   (pc_en),
        .pc_next (if_pc_next),
        .pc      (if_pc_current)
    );

    // ==========================================
    // IF/ID Pipeline Register
    // ==========================================
    if_id_reg u_if_id_reg (
        .clk     (clk),
        .rst_n   (rst_n),
        .stall   (if_id_stall),
        .flush   (if_id_flush),
        .if_pc   (if_pc_current),
        .if_inst (imem_rdata),
        .id_pc   (id_pc),
        .id_inst (id_inst)
    );

    // ==========================================
    // 2. INSTRUCTION DECODE (ID) STAGE
    // ==========================================
    assign id_opcode = id_inst[6:0];
    assign id_rd     = id_inst[11:7];
    assign id_funct3 = id_inst[14:12];
    assign id_rs1    = id_inst[19:15];
    assign id_rs2    = id_inst[24:20];
    assign id_funct7 = id_inst[31:25];

    main_control u_main_control (
        .opcode      (id_opcode),
        .alu_op_type (id_alu_op_type),
        .alu_src_a   (id_alu_src_a),
        .alu_src_b   (id_alu_src_b),
        .mem_read    (id_mem_read),
        .mem_write   (id_mem_write),
        .reg_write   (id_reg_write),
        .wb_sel      (id_wb_sel),
        .branch      (id_branch),
        .jal         (id_jal),
        .jalr        (id_jalr)
    );

    alu_control u_alu_control (
        .alu_op_type (id_alu_op_type),
        .funct3      (id_funct3),
        .funct7      (id_funct7),
        .alu_ctrl    (id_alu_ctrl)
    );

    regfile u_regfile (
        .clk    (clk),
        .rst_n  (rst_n),
        .raddr1 (id_rs1),
        .rdata1 (id_rdata1),
        .raddr2 (id_rs2),
        .rdata2 (id_rdata2),
        .we     (wb_reg_write),
        .waddr  (wb_rd),
        .wdata  (wb_final_data)
    );

    imm_gen u_imm_gen (
        .inst    (id_inst),
        .imm_ext (id_imm)
    );

    // ==========================================
    // ID/EX Pipeline Register
    // ==========================================
    id_ex_reg u_id_ex_reg (
        .clk          (clk),
        .rst_n        (rst_n),
        .stall        (id_ex_stall),
        .flush        (id_ex_flush),
        .id_pc        (id_pc),
        .id_rdata1    (id_rdata1),
        .id_rdata2    (id_rdata2),
        .id_imm       (id_imm),
        .id_funct3    (id_funct3),
        .id_rs1       (id_rs1),
        .id_rs2       (id_rs2),
        .id_rd        (id_rd),
        .id_alu_ctrl  (id_alu_ctrl),
        .id_alu_src_a (id_alu_src_a),
        .id_alu_src_b (id_alu_src_b),
        .id_mem_read  (id_mem_read),
        .id_mem_write (id_mem_write),
        .id_reg_write (id_reg_write),
        .id_wb_sel    (id_wb_sel),
        .id_branch    (id_branch),
        .id_jal       (id_jal),
        .id_jalr      (id_jalr),
        .ex_pc        (ex_pc),
        .ex_rdata1    (ex_rdata1),
        .ex_rdata2    (ex_rdata2),
        .ex_imm       (ex_imm),
        .ex_funct3    (ex_funct3),
        .ex_rs1       (ex_rs1),
        .ex_rs2       (ex_rs2),
        .ex_rd        (ex_rd),
        .ex_alu_ctrl  (ex_alu_ctrl),
        .ex_alu_src_a (ex_alu_src_a),
        .ex_alu_src_b (ex_alu_src_b),
        .ex_mem_read  (ex_mem_read),
        .ex_mem_write (ex_mem_write),
        .ex_reg_write (ex_reg_write),
        .ex_wb_sel    (ex_wb_sel),
        .ex_branch    (ex_branch),
        .ex_jal       (ex_jal),
        .ex_jalr      (ex_jalr)
    );

    // ==========================================
    // 3. EXECUTE (EX) STAGE
    // ==========================================
    assign ex_pc_plus4 = ex_pc + 32'd4;

    // Forwarding Muxes for ALU inputs
    always_comb begin
        case (forward_a)
            2'b10:   ex_fwd_a = mem_alu_result;
            2'b01:   ex_fwd_a = wb_final_data;
            default: ex_fwd_a = ex_rdata1;
        endcase

        case (forward_b)
            2'b10:   ex_fwd_b = mem_alu_result;
            2'b01:   ex_fwd_b = wb_final_data;
            default: ex_fwd_b = ex_rdata2;
        endcase
    end

    // ALU Operand A Mux
    assign ex_alu_in_a = (ex_alu_src_a == ALU_SRC_A_PC) ? ex_pc : ex_fwd_a;

    // ALU Operand B Mux
    assign ex_alu_in_b = (ex_alu_src_b == ALU_SRC_B_IMM) ? ex_imm : ex_fwd_b;

    alu u_alu (
        .alu_a      (ex_alu_in_a),
        .alu_b      (ex_alu_in_b),
        .alu_ctrl   (ex_alu_ctrl),
        .alu_result (ex_alu_result),
        .zero       (ex_alu_zero)
    );

    branch_comp u_branch_comp (
        .funct3       (ex_funct3),
        .op_a         (ex_fwd_a),
        .op_b         (ex_fwd_b),
        .branch_taken (ex_branch_taken)
    );

    // Branch & Jump Target Adders
    assign ex_branch_target = ex_pc + ex_imm;
    assign ex_jump_target   = (ex_fwd_a + ex_imm) & ~32'd1; // JALR clears LSB

    // ==========================================
    // EX/MEM Pipeline Register
    // ==========================================
    ex_mem_reg u_ex_mem_reg (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall          (ex_mem_stall),
        .ex_alu_result  (ex_alu_result),
        .ex_wdata       (ex_fwd_b), // Forwarded RS2 for store instructions
        .ex_rd          (ex_rd),
        .ex_pc4         (ex_pc_plus4),
        .ex_funct3      (ex_funct3),
        .ex_mem_read    (ex_mem_read),
        .ex_mem_write   (ex_mem_write),
        .ex_reg_write   (ex_reg_write),
        .ex_wb_sel      (ex_wb_sel),
        .mem_alu_result (mem_alu_result),
        .mem_wdata      (mem_wdata),
        .mem_rd         (mem_rd),
        .mem_pc4        (mem_pc4),
        .mem_funct3     (mem_funct3),
        .mem_mem_read   (mem_mem_read),
        .mem_mem_write  (mem_mem_write),
        .mem_reg_write  (mem_reg_write),
        .mem_wb_sel     (mem_wb_sel)
    );

    // ==========================================
    // 4. MEMORY ACCESS (MEM) STAGE
    // ==========================================
    assign mem_req = mem_mem_read || mem_mem_write;

    byte_align u_byte_align (
        .funct3          (mem_funct3),
        .byte_offset     (mem_alu_result[1:0]),
        .mem_rdata_raw   (mem_raw_rdata),
        .cpu_wdata_raw   (mem_wdata),
        .mem_rdata_align (mem_aligned_rdata),
        .mem_wdata_align (mem_aligned_wdata),
        .mem_wstrb       (mem_wstrb)
    );

    apb_master_adapter u_apb_master (
        .clk       (clk),
        .rst_n     (rst_n),
        .mem_req   (mem_req),
        .mem_write (mem_mem_write),
        .mem_addr  (mem_alu_result),
        .mem_wdata (mem_aligned_wdata),
        .mem_wstrb (mem_wstrb),
        .mem_rdata (mem_raw_rdata),
        .bus_stall (bus_stall),
        .paddr     (paddr),
        .psel      (psel),
        .penable   (penable),
        .pwrite    (pwrite),
        .pwdata    (pwdata),
        .pstrb     (pstrb),
        .prdata    (prdata),
        .pready    (pready),
        .pslverr   (pslverr)
    );

    // ==========================================
    // MEM/WB Pipeline Register
    // ==========================================
    mem_wb_reg u_mem_wb_reg (
        .clk           (clk),
        .rst_n         (rst_n),
        .stall         (mem_wb_stall),
        .mem_alu_result(mem_alu_result),
        .mem_rdata     (mem_aligned_rdata),
        .mem_pc4       (mem_pc4),
        .mem_rd        (mem_rd),
        .mem_reg_write (mem_reg_write),
        .mem_wb_sel    (mem_wb_sel),
        .wb_alu_result (wb_alu_result),
        .wb_rdata      (wb_rdata),
        .wb_pc4        (wb_pc4),
        .wb_rd         (wb_rd),
        .wb_reg_write  (wb_reg_write),
        .wb_wb_sel     (wb_wb_sel)
    );

    // ==========================================
    // 5. WRITEBACK (WB) STAGE
    // ==========================================
    always_comb begin
        case (wb_wb_sel)
            WB_SEL_ALU: wb_final_data = wb_alu_result;
            WB_SEL_MEM: wb_final_data = wb_rdata;
            WB_SEL_PC4: wb_final_data = wb_pc4;
            default:    wb_final_data = wb_alu_result;
        endcase
    end

    // ==========================================
    // 6. HAZARD & FORWARDING ENGINES
    // ==========================================
    forward_unit u_forward_unit (
        .id_ex_rs1        (ex_rs1),
        .id_ex_rs2        (ex_rs2),
        .ex_mem_rd        (mem_rd),
        .ex_mem_reg_write (mem_reg_write),
        .mem_wb_rd        (wb_rd),
        .mem_wb_reg_write (wb_reg_write),
        .forward_a        (forward_a),
        .forward_b        (forward_b)
    );

    hazard_unit u_hazard_unit (
        .if_id_rs1      (id_rs1),
        .if_id_rs2      (id_rs2),
        .id_ex_rd       (ex_rd),
        .id_ex_mem_read (ex_mem_read),
        .ex_branch      (ex_branch),        // <--- CONNECT THIS PORT
        .branch_taken   (ex_branch_taken),
        .ex_jal         (ex_jal),
        .ex_jalr        (ex_jalr),
        .bus_stall      (bus_stall),
        .pc_en          (pc_en),
        .if_id_stall    (if_id_stall),
        .id_ex_stall    (id_ex_stall),
        .ex_mem_stall   (ex_mem_stall),
        .mem_wb_stall   (mem_wb_stall),
        .if_id_flush    (if_id_flush),
        .id_ex_flush    (id_ex_flush)
    );

endmodule