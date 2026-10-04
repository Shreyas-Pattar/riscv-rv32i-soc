`timescale 1ns / 1ps

module soc_top (
    input  logic        clk,
    input  logic        rst_n,
    output logic [3:0]  leds,
    output logic        uart_tx
);

    // ==========================================
    // Internal Core & Bus Nets
    // ==========================================
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;

    logic [31:0] paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    logic [3:0]  pstrb;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    // Subordinate Address Decoding
    logic        ram_sel;
    logic        uart_sel;
    logic [31:0] ram_prdata;
    logic [31:0] uart_prdata;
    logic        ram_pready;
    logic        uart_pready;

    // Keep core alive: route live execution signals to external pins
    assign leds = {uart_tx, imem_addr[3:1]};

    // Address Decoder:
    // 0x0000_0000 - 0x0000_07FC : Data RAM (2 KB)
    // 0x0000_0800 - 0x0000_080F : APB UART Peripheral
    assign ram_sel  = psel && (paddr < 32'h0000_0800);
    assign uart_sel = psel && (paddr >= 32'h0000_0800 && paddr < 32'h0000_0810);

    assign prdata  = uart_sel ? uart_prdata : ram_prdata;
    assign pready  = uart_sel ? uart_pready : ram_pready;
    assign pslverr = 1'b0;

    // ==========================================
    // 1. RV32I Core Instance
    // ==========================================
    (* DONT_TOUCH = "yes" *)
    riscv_core_top #(
        .RESET_ADDR(32'h0000_0000)
    ) u_core (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .paddr      (paddr),
        .psel       (psel),
        .penable    (penable),
        .pwrite     (pwrite),
        .pwdata     (pwdata),
        .pstrb      (pstrb),
        .prdata     (prdata),
        .pready     (pready),
        .pslverr    (pslverr)
    );

    // ==========================================
    // 2. Instruction Memory (ROM / Fetch Interface)
    // ==========================================
    (* ram_style = "distributed" *) logic [31:0] imem [0:1023];

    initial begin
        for (int i = 0; i < 1024; i++) begin
            imem[i] = 32'h0000_0013; // Fill with NOPs
        end

        // Base pointer x10 = 0x0000_0800
        imem[0] = 32'h00001537;
        imem[1] = 32'h80050513;

        // 1. Send 'R' (0x52)
        imem[2] = 32'h05200613;
        imem[3] = 32'h00c52023;

        // 2. Send 'V' (0x56)
        imem[4] = 32'h05600613;
        imem[5] = 32'h00c52023;

        // 3. Send '3' (0x33)
        imem[6] = 32'h03300613;
        imem[7] = 32'h00c52023;

        // 4. Send '2' (0x32)
        imem[8] = 32'h03200613;
        imem[9] = 32'h00c52023;

        // 5. Send 'I' (0x49)
        imem[10] = 32'h04900613;
        imem[11] = 32'h00c52023;

        // HALT
        imem[12] = 32'h0000006f;
    end

    assign imem_rdata = imem[imem_addr[11:2]];

    // ==========================================
    // 3. Data Memory Slave (2 KB True Block RAM)
    // ==========================================
    (* ram_style = "block" *) logic [31:0] dmem [0:511];

    initial begin
        for (int i = 0; i < 512; i++) begin
            dmem[i] = 32'h0000_0000;
        end
        $readmemh("program.mem", dmem);
    end

    // Pure synchronous memory without async reset on storage cells
    always_ff @(posedge clk) begin
        if (ram_sel && penable) begin
            if (pwrite) begin
                if (pstrb[0]) dmem[paddr[10:2]][7:0]   <= pwdata[7:0];
                if (pstrb[1]) dmem[paddr[10:2]][15:8]  <= pwdata[15:8];
                if (pstrb[2]) dmem[paddr[10:2]][23:16] <= pwdata[23:16];
                if (pstrb[3]) dmem[paddr[10:2]][31:24] <= pwdata[31:24];
            end
            ram_prdata <= dmem[paddr[10:2]];
        end
    end

    // Registered APB ready handshake
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_pready <= 1'b0;
        end else begin
            ram_pready <= (ram_sel && penable);
        end
    end

    // ==========================================
    // 4. APB UART Transmitter Peripheral
    // ==========================================
    (* DONT_TOUCH = "yes" *)
    apb_uart_tx u_uart (
        .pclk    (clk),
        .presetn (rst_n),
        .psel    (uart_sel),
        .penable (penable),
        .pwrite  (pwrite),
        .paddr   (paddr[11:0]),
        .pwdata  (pwdata),
        .pstrb   (pstrb),
        .prdata  (uart_prdata),
        .pready  (uart_pready),
        .pslverr (),
        .uart_tx (uart_tx)
    );

endmodule