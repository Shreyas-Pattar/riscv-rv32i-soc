`timescale 1ns / 1ps

module byte_align (
    input  logic [2:0]  funct3,
    input  logic [1:0]  byte_offset,    // addr[1:0]
    input  logic [31:0] mem_rdata_raw,  // Raw 32-bit read from memory/bus
    input  logic [31:0] cpu_wdata_raw,  // rs2 value to be stored
    output logic [31:0] mem_rdata_align,// Formatted load data to writeback mux
    output logic [31:0] mem_wdata_align,// Replicated data for write bus
    output logic [3:0]  mem_wstrb       // Byte lane enable strobes (PSTRB)
);

    // Load Data Alignment and Extension
    always_comb begin
        case (funct3)
            // LB (Signed Byte)
            3'b000: begin
                case (byte_offset)
                    2'b00: mem_rdata_align = {{24{mem_rdata_raw[7]}},  mem_rdata_raw[7:0]};
                    2'b01: mem_rdata_align = {{24{mem_rdata_raw[15]}}, mem_rdata_raw[15:8]};
                    2'b10: mem_rdata_align = {{24{mem_rdata_raw[23]}}, mem_rdata_raw[23:16]};
                    2'b11: mem_rdata_align = {{24{mem_rdata_raw[31]}}, mem_rdata_raw[31:24]};
                endcase
            end

            // LH (Signed Halfword)
            3'b001: begin
                case (byte_offset[1])
                    1'b0: mem_rdata_align = {{16{mem_rdata_raw[15]}}, mem_rdata_raw[15:0]};
                    1'b1: mem_rdata_align = {{16{mem_rdata_raw[31]}}, mem_rdata_raw[31:16]};
                endcase
            end

            // LW (Word)
            3'b010: begin
                mem_rdata_align = mem_rdata_raw;
            end

            // LBU (Unsigned Byte)
            3'b100: begin
                case (byte_offset)
                    2'b00: mem_rdata_align = {24'h0, mem_rdata_raw[7:0]};
                    2'b01: mem_rdata_align = {24'h0, mem_rdata_raw[15:8]};
                    2'b10: mem_rdata_align = {24'h0, mem_rdata_raw[23:16]};
                    2'b11: mem_rdata_align = {24'h0, mem_rdata_raw[31:24]};
                endcase
            end

            // LHU (Unsigned Halfword)
            3'b101: begin
                case (byte_offset[1])
                    1'b0: mem_rdata_align = {16'h0, mem_rdata_raw[15:0]};
                    1'b1: mem_rdata_align = {16'h0, mem_rdata_raw[31:16]};
                endcase
            end

            default: mem_rdata_align = mem_rdata_raw;
        endcase
    end

    // Store Data Alignment and Byte Strobes
    always_comb begin
        case (funct3[1:0])
            // SB (Store Byte)
            2'b00: begin
                mem_wdata_align = {4{cpu_wdata_raw[7:0]}};
                case (byte_offset)
                    2'b00: mem_wstrb = 4'b0001;
                    2'b01: mem_wstrb = 4'b0010;
                    2'b10: mem_wstrb = 4'b0100;
                    2'b11: mem_wstrb = 4'b1000;
                endcase
            end

            // SH (Store Halfword)
            2'b01: begin
                mem_wdata_align = {2{cpu_wdata_raw[15:0]}};
                case (byte_offset[1])
                    1'b0: mem_wstrb = 4'b0011;
                    1'b1: mem_wstrb = 4'b1100;
                endcase
            end

            // SW (Store Word)
            2'b10: begin
                mem_wdata_align = cpu_wdata_raw;
                mem_wstrb       = 4'b1111;
            end

            default: begin
                mem_wdata_align = cpu_wdata_raw;
                mem_wstrb       = 4'b1111;
            end
        endcase
    end

endmodule   