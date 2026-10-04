`timescale 1ns / 1ps

module apb_master_adapter (
    input  logic        clk,
    input  logic        rst_n,

    // Core Memory Stage Interface (MEM Stage)
    input  logic        mem_req,        // mem_read || mem_write
    input  logic        mem_write,      // 1: Write, 0: Read
    input  logic [31:0] mem_addr,       // Access address from ALU result
    input  logic [31:0] mem_wdata,      // Formatted store data from byte_align
    input  logic [3:0]  mem_wstrb,      // Byte strobes
    output logic [31:0] mem_rdata,      // Data captured from APB PRDATA
    output logic        bus_stall,      // Halts pipeline when transfer is incomplete

    // AMBA APB3 Bus Master Interface
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

    typedef enum logic [1:0] {
        ST_IDLE   = 2'b00,
        ST_SETUP  = 2'b01,
        ST_ACCESS = 2'b10
    } apb_state_e;

    apb_state_e current_state, next_state;

    // Registers to latch request inputs during multi-cycle wait states
    logic [31:0] latched_addr;
    logic [31:0] latched_wdata;
    logic [3:0]  latched_wstrb;
    logic        latched_write;
    logic [31:0] latched_rdata;

    // ==========================================
    // FSM State Register & Input Latching
    // ==========================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= ST_IDLE;
            latched_addr  <= 32'h0;
            latched_wdata <= 32'h0;
            latched_wstrb <= 4'h0;
            latched_write <= 1'b0;
            latched_rdata <= 32'h0;
        end else begin
            current_state <= next_state;

            // Sample parameters upon initiating a transfer
            if (current_state == ST_IDLE && mem_req) begin
                latched_addr  <= mem_addr;
                latched_wdata <= mem_wdata;
                latched_wstrb <= mem_wstrb;
                latched_write <= mem_write;
            end

            // Capture read data when APB slave completes transfer
            if (current_state == ST_ACCESS && pready && !latched_write) begin
                latched_rdata <= prdata;
            end
        end
    end

    // ==========================================
    // Next-State Combinational Logic
    // ==========================================
    always_comb begin
        next_state = current_state;
        case (current_state)
            ST_IDLE: begin
                if (mem_req) begin
                    next_state = ST_SETUP;
                end
            end

            ST_SETUP: begin
                // In APB3, SETUP always transitions to ACCESS on next cycle
                next_state = ST_ACCESS;
            end

            ST_ACCESS: begin
                if (pready) begin
                    // Transfer finished: return to IDLE (or directly SETUP if new req)
                    next_state = ST_IDLE;
                end
            end

            default: next_state = ST_IDLE;
        endcase
    end

    // ==========================================
    // APB Protocol Output Signals & Pipeline Stall
    // ==========================================
    always_comb begin
        // Defaults
        psel      = 1'b0;
        penable   = 1'b0;
        paddr     = latched_addr;
        pwrite    = latched_write;
        pwdata    = latched_wdata;
        pstrb     = latched_wstrb;
        bus_stall = 1'b0;

        case (current_state)
            ST_IDLE: begin
                if (mem_req) begin
                    // Stall immediately on request detection
                    bus_stall = 1'b1;
                end
            end

            ST_SETUP: begin
                psel      = 1'b1;
                penable   = 1'b0;
                paddr     = latched_addr;
                pwrite    = latched_write;
                pwdata    = latched_wdata;
                pstrb     = latched_wstrb;
                bus_stall = 1'b1;
            end

            ST_ACCESS: begin
                psel      = 1'b1;
                penable   = 1'b1;
                paddr     = latched_addr;
                pwrite    = latched_write;
                pwdata    = latched_wdata;
                pstrb     = latched_wstrb;
                // Stall pipeline until peripheral completes with PREADY
                bus_stall = !pready;
            end

            default: begin
                bus_stall = 1'b0;
            end
        endcase
    end

    // Deliver either active bus data or latched data
    assign mem_rdata = (current_state == ST_ACCESS && pready) ? prdata : latched_rdata;

endmodule