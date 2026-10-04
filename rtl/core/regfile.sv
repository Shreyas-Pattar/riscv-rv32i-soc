`timescale 1ns / 1ps

module regfile (
    input  logic        clk,
    input  logic        rst_n,

    // Read Ports (Asynchronous / Comb)
    input  logic [4:0]  raddr1,
    output logic [31:0] rdata1,
    input  logic [4:0]  raddr2,
    output logic [31:0] rdata2,

    // Write Port (Synchronous)
    input  logic        we,
    input  logic [4:0]  waddr,
    input  logic [31:0] wdata
);

    logic [31:0] registers [31:1]; // x1 to x31; x0 is hardwired

    // Synchronous Write Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 1; i < 32; i++) begin
                registers[i] <= 32'h0000_0000;
            end
        end else if (we && (waddr != 5'd0)) begin
            registers[waddr] <= wdata;
        end
    end

    // Asynchronous Read with internal WB->ID forwarding bypass
    always_comb begin
        // Read Port 1
        if (raddr1 == 5'd0) begin
            rdata1 = 32'h0000_0000;
        end else if (we && (waddr == raddr1)) begin
            rdata1 = wdata; // Internal bypass
        end else begin
            rdata1 = registers[raddr1];
        end

        // Read Port 2
        if (raddr2 == 5'd0) begin
            rdata2 = 32'h0000_0000;
        end else if (we && (waddr == raddr2)) begin
            rdata2 = wdata; // Internal bypass
        end else begin
            rdata2 = registers[raddr2];
        end
    end

endmodule