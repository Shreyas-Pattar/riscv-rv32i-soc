# Pipelined RV32I RISC-V SoC with AMBA APB3 & Hardware Flow-Control UART

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Target FPGA](https://img.shields.io/badge/FPGA-Xilinx%20Zynq--7000%20(XC7Z007S)-orange.svg)
![EDA Tool](https://img.shields.io/badge/EDA-Vivado%202026.1-red.svg)
![Timing](https://img.shields.io/badge/Timing-Closed%20%40%2090MHz-brightgreen.svg)

A synthesizable, 5-stage pipelined 32-bit RISC-V (RV32I) System-on-Chip implemented in SystemVerilog. The architecture features an in-order pipeline with full data hazard forwarding, an AMBA APB3 bus master, 2 KB of dedicated Block RAM, and an autonomous UART transmitter featuring hardware backpressure flow control.

---

## 1. Architectural Architecture
                      +------------------------------------------------+
                      |                 RV32I Core Top                 |
                      |                                                |
                      |  [IF] ---> [ID] ---> [EX] ---> [MEM] ---> [WB] |
                      |    |         |        |         |              |
                      |    +---------+--------+---------+              |
                      |            Hazard & Data Forwarding            |
                      +-----------------------+------------------------+
                                              | AMBA APB3 Master
                                              v
                              +-------------------------------+
                              |       APB Address Decoder     |
                              +---------------+---------------+
                                              |
                     +------------------------+------------------------+
                     | (0x0000_0000 - 0x0000_07FC)                     | (0x0000_0800 - 0x0000_080F)
                     v                                                 v
        +-------------------------+                       +-------------------------+
        |  2 KB True Block RAM    |                       |  UART Transmitter Sub   |
        |   (Xilinx RAMB18E1)     |                       |    Hardware Flow-Ctrl   |
        +-------------------------+                       +-------------------------+
                                                                       |
                                                                       v
                                                                    uart_tx
### Microarchitectural Highlights
* **5-Stage In-Order Pipeline:** IF $\to$ ID $\to$ EX $\to$ MEM $\to$ WB.
* **Hazard & Forwarding Unit:** EX-to-EX and MEM-to-EX operand forwarding eliminating raw data dependencies; automated bubble insertion for Load-Use hazards.
* **AMBA APB3 Bus Master Adapter:** Bridges core memory accesses to standard two-phase APB transfers (`SETUP` $\to$ `ACCESS`), halting pipeline stages via `bus_stall` during peripheral wait states.
* **Hardware Flow-Control UART:** Deasserts `pready` during transmissions, automatically stalling the CPU when back-to-back writes occur without requiring software polling.
* **FPGA Memory Inference:** Clean synchronous inference mapping scratchpad memory to a single Xilinx `RAMB18E1` Block RAM primitive.

---

## 2. Memory Map

| Address Range | Size | Target Peripheral | Description |
| :--- | :--- | :--- | :--- |
| `0x0000_0000 - 0x0000_07FC` | 2048 B | Data BRAM (`dmem`) | Byte/Halfword/Word accessible scratchpad |
| `0x0000_0800` | 4 B | `UART_TX_DATA` | Write: Data byte (`[7:0]`) to transmit |
| `0x0000_0804` | 4 B | `UART_STATUS` | Read: Bit 0 indicates serializer busy (`tx_busy`) |
| `0x0000_0808` | 4 B | `UART_BAUD_DIV` | Read/Write: Baud-rate clock divisor |

---

## 3. Physical Implementation & Resource Utilization

Target Device: **AMD Xilinx Zynq-7000 XC7Z007S-CLG400-1**  
Toolchain: **Vivado ML Standard 2026.1**

| Resource Primitive | Used | Available | Utilization (%) |
| :--- | :--- | :--- | :--- |
| **Slice LUTs** | 1,862 | 14,400 | **12.93%** |
| **Slice Registers (FF)** | 1,618 | 28,800 | **5.62%** |
| **Block RAM (RAMB18E1)** | 1 | 100 | **1.00%** |
| **Global Clocks (BUFG)** | 1 | 32 | **3.13%** |
| **Bonded IOB** | 7 | 100 | **7.00%** |

---

## 4. Static Timing Analysis (STA) Sign-Off

Timing constraints closed cleanly across all corners at **90 MHz** ($T = 11.111\text{ ns}$):

* **Worst Negative Slack (WNS):** `+0.179 ns` (Zero setup violations)
* **Worst Hold Slack (WHS):** `+0.023 ns` (Zero hold violations)
* **Worst Pulse Width Slack (WPWS):** `+5.055 ns`
* **Total Negative Slack (TNS / THS):** `0.000 ns`

---

## 5. Verification Results

End-to-end SoC simulation validates CPU execution, memory fetches, APB transactions, and multi-byte UART serial stream reconstruction:

```text
==================================================
   Running Full RV32I SoC String Transmission     
==================================================
[TB] Reset deasserted. CPU executing string loader...
[UART RX @  1.655 us] Byte Received: 0x52 ('R')
[UART RX @  3.265 us] Byte Received: 0x56 ('V')
[UART RX @  4.875 us] Byte Received: 0x33 ('3')
[UART RX @  6.485 us] Byte Received: 0x32 ('2')
[UART RX @  8.095 us] Byte Received: 0x49 ('I')

==================================================
               SIMULATION RESULTS                 
==================================================
Transmitted String Captured: "RV32I"
==================================================
