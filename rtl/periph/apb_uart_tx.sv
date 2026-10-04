`timescale 1ns / 1ps

module apb_uart_tx (
    input  logic        pclk,
    input  logic        presetn,

    // APB3 Slave Interface
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [11:0] paddr,
    input  logic [31:0] pwdata,
    input  logic [3:0]  pstrb,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr,

    // Serial Output
    output logic        uart_tx
);

    assign pslverr = 1'b0;

    localparam logic [15:0] DEFAULT_DIV = 16'd16;

    logic [15:0] baud_div;
    logic [9:0]  tx_shift;
    logic [15:0] baud_cnt;
    logic [3:0]  bit_cnt;
    logic        tx_busy;

    // Flow Control: If CPU tries to write to TX buffer (offset 0x0) while busy,
    // stall the APB bus until transmission completes!
    assign pready = (psel && penable) ? !(pwrite && (paddr[3:0] == 4'h0) && tx_busy) : 1'b0;

    // Pure Combinational APB Read Mux
    always_comb begin
        prdata = 32'h0;
        if (psel && !pwrite) begin
            case (paddr[3:0])
                4'h0: prdata = 32'h0;
                4'h4: prdata = {31'h0, tx_busy};
                4'h8: prdata = {16'h0, baud_div};
                default: prdata = 32'h0;
            endcase
        end
    end

    // UART Transmitter Engine
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            baud_div <= DEFAULT_DIV;
            tx_shift <= 10'h3FF;
            tx_busy  <= 1'b0;
            baud_cnt <= 16'h0;
            bit_cnt  <= 4'h0;
        end else begin
            // Baud configuration write (offset 0x8)
            if (psel && penable && pready && pwrite && (paddr[3:0] == 4'h8)) begin
                baud_div <= pwdata[15:0];
            end

            // Transmit trigger write (offset 0x0)
            if (psel && penable && pready && pwrite && (paddr[3:0] == 4'h0) && !tx_busy) begin
                tx_shift <= {1'b1, pwdata[7:0], 1'b0};
                tx_busy  <= 1'b1;
                baud_cnt <= 16'h0;
                bit_cnt  <= 4'd0;
            end else if (tx_busy) begin
                if (baud_cnt < baud_div - 1) begin
                    baud_cnt <= baud_cnt + 16'd1;
                end else begin
                    baud_cnt <= 16'h0;
                    tx_shift <= {1'b1, tx_shift[9:1]};
                    if (bit_cnt < 4'd9) begin
                        bit_cnt <= bit_cnt + 4'd1;
                    end else begin
                        tx_busy  <= 1'b0;
                        bit_cnt  <= 4'd0;
                        tx_shift <= 10'h3FF;
                    end
                end
            end
        end
    end

    assign uart_tx = tx_shift[0];

endmodule