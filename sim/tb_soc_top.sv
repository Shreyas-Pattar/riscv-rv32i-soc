`timescale 1ns / 1ps

module tb_soc_top;

    logic clk;
    logic rst_n;
    logic uart_tx;

    // 100 MHz clock generation (Period = 10 ns)
    always #5 clk = ~clk;

    // Instantiate SoC Top-level
    soc_top dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .uart_tx (uart_tx)
    );

    localparam int CLKS_PER_BIT = 16;
    localparam time BIT_PERIOD  = CLKS_PER_BIT * 10ns; // 160 ns
    string received_msg = "";

    // ----------------------------------------------------
    // Serial Receiver Task
    // ----------------------------------------------------
    task automatic uart_rx_monitor();
        logic [7:0] rx_byte;
        forever begin
            wait(uart_tx === 1'b1);
            @(negedge uart_tx);

            #(BIT_PERIOD * 3 / 2);

            for (int i = 0; i < 8; i++) begin
                rx_byte[i] = uart_tx;
                #(BIT_PERIOD);
            end

            if (rx_byte >= 8'h20 && rx_byte <= 8'h7E) begin
                received_msg = {received_msg, string'(rx_byte)};
            end

            $display("[UART RX @ %t] Byte Received: 0x%02h ('%c')", 
                     $realtime, rx_byte, (rx_byte >= 32 && rx_byte < 127) ? rx_byte : ".");

            #(BIT_PERIOD / 2);
        end
    endtask

    initial begin
        $display("[TB] Dumping IMEM content:");
        for (int i = 0; i < 16; i++) begin
            $display("  imem[%0d] (PC 0x%02h) = 0x%08h", i, i*4, dut.imem[i]);
        end
        $timeformat(-6, 3, " us", 10);
        clk   = 0;
        rst_n = 0;

        $display("==================================================");
        $display("   Running Full RV32I SoC String Transmission     ");
        $display("==================================================");

        fork
            uart_rx_monitor();
        join_none

        #50;
        rst_n = 1;
        $display("[TB] Reset deasserted. CPU executing string loader...");

        #100000;

        $display("\n==================================================");
        $display("               SIMULATION RESULTS                 ");
        $display("==================================================");
        $display("Transmitted String Captured: \"%s\"", received_msg);
        $display("==================================================");
        $finish;
    end

endmodule