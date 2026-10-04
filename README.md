# 5-Stage Pipelined RV32I Core with an APB Bus and UART

A synthesizable 5-stage in-order RV32I core written in SystemVerilog, with an APB master adapter, a 2 KB block RAM data memory and an APB UART transmitter. Implemented in Vivado for a Zynq-7000 (`XC7Z007S-CLG400-1`) at 90 MHz.

---

## Architecture

```text
                       soc_top
   ┌────────────────────────────────────────────────────────────┐
   │                                                            │
   │   Instruction ROM (4 KB, 1024 words)                       │
   │        ▲ imem_addr        │ imem_rdata                     │
   │        │                  ▼                                │
   │   ┌─────────────── riscv_core_top ───────────────┐         │
   │   │  IF ─► ID ─► EX ─► MEM ─► WB                 │         │
   │   │   hazard unit + forwarding unit              │         │
   │   │             │ MEM stage                      │         │
   │   │     apb_master_adapter  (freezes pipeline)   │         │
   │   └─────────────┬────────────────────────────────┘         │
   │                 │ APB: PSEL, PENABLE, PREADY, PSTRB        │
   │          address decoder                                   │
   │       ┌─────────┴───────────┐                              │
   │  0x000 - 0x7FC         0x800 - 0x80F                       │
   │  2 KB data BRAM        APB UART TX ──► uart_tx             │
   └────────────────────────────────────────────────────────────┘
```

| File | Role |
|------|------|
| `rv32i_pkg.sv` | Opcodes, ALU operations and mux-select enums |
| `riscv_core_top.sv` | Core top: wires the five stages, hazard and forwarding logic |
| `pc_reg.sv`, `if_id_reg.sv`, `id_ex_reg.sv`, `ex_mem_reg.sv`, `mem_wb_reg.sv` | PC and pipeline registers with stall and flush |
| `main_control.sv`, `alu_control.sv`, `imm_gen.sv` | Decode: control signals, ALU operation select, immediate generation |
| `regfile.sv` | 31 x 32-bit registers, with a write-to-read bypass for the WB to ID hazard |
| `alu.sv`, `branch_comp.sv` | ALU and branch comparator |
| `forward_unit.sv`, `hazard_unit.sv` | Operand forwarding, load-use stall, branch flush, bus stall |
| `byte_align.sv` | Load sign/zero extension and store byte strobes |
| `apb_master_adapter.sv` | Turns each load and store into an APB transfer |
| `apb_uart_tx.sv` | APB slave: UART transmitter with baud divisor register |
| `soc_top.sv` | Instruction ROM, address decoder, data BRAM, UART, top-level pins |

### Microarchitecture

- **Pipeline:** IF, ID, EX, MEM, WB, in order.
- **Forwarding:** EX/MEM to EX and MEM/WB to EX, plus a bypass inside the register file for the WB to ID case.
- **Load-use hazard:** one stall cycle, then the loaded value is forwarded from WB.
- **Branches and jumps:** resolved in EX with predict-not-taken. A taken branch or any jump flushes IF/ID and ID/EX, a 2-cycle penalty.
- **Instruction set:** RV32I base integer instructions (see the `lui` known issue below). `FENCE`, `ECALL` and `EBREAK` decode as NOPs, and there are no CSRs, interrupts or exceptions.
- **Memory:** separate instruction and data paths. Instructions come from a combinational-read ROM. All loads and stores go over APB.
- **Bus stalls:** every load and store becomes an APB transfer and freezes the whole pipeline until `PREADY`. That is about 3 stall cycles for the BRAM (its `PREADY` is registered) and 2 for an idle UART.
- **Byte and halfword access:** loads are extended from the full word in `byte_align`. Stores use `PSTRB` write strobes, which is an APB4 signal added to the APB3 handshake.

### Memory map

| Address | Size | Target | Description |
|---------|------|--------|-------------|
| `0x0000_0000` - `0x0000_07FC` | 2 KB | Data BRAM | Byte, halfword and word access |
| `0x0000_0800` | 4 B | `UART_TX_DATA` | Write: data byte `[7:0]` to send. Stalls while the UART is busy |
| `0x0000_0804` | 4 B | `UART_STATUS` | Read: bit 0 is `tx_busy` |
| `0x0000_0808` | 4 B | `UART_BAUD_DIV` | Read/write: baud divisor (bit time in clock cycles) |

**UART:** transmit only, 8N1. The default divisor is 16 so simulations run fast, which is about 5.6 Mbaud at 90 MHz. For 115200 baud at 90 MHz, write `781` to `UART_BAUD_DIV`.

### Program

The instruction ROM is a 1024-word array initialized in `soc_top.sv`. The program is 13 instructions: it points `x10` at the UART, sends `R`, `V`, `3`, `2`, `I` with `sw`, then spins in a `jal x0, 0` loop. `program.mem` holds the same 13 words. To run a different program, edit the `initial` block in `soc_top.sv` and re-synthesize.

---

## Results

Vivado 2026.1, `XC7Z007S-CLG400-1`, 90 MHz clock (11.111 ns), post-implementation. Constraints are in `constrs/timing_constraints.xdc`.

| Resource | Used | Available | Utilization |
|----------|-----:|----------:|------------:|
| Slice LUTs | 1,862 | 14,400 | 12.93% |
| Slice registers | 1,618 | 28,800 | 5.62% |
| Block RAM (RAMB18E1) | 1 | 100 | 1.00% |
| BUFG | 1 | 32 | 3.13% |
| Bonded IOB | 7 | 100 | 7.00% |

| Metric | Value |
|--------|-------|
| Worst negative slack (setup) | +0.179 ns |
| Worst hold slack | +0.023 ns |
| Worst pulse width slack | +5.055 ns |
| TNS / THS | 0.000 ns |

About 990 of the 1,618 registers are the register file. It uses an asynchronous reset, which stops Vivado from mapping it to LUT RAM.

The `leds` outputs carry `uart_tx` and three PC bits, and the core and UART are marked `DONT_TOUCH`. This keeps synthesis from removing the logic. The XDC has no pin locations, so it only builds a bitstream by downgrading pin DRCs to warnings. This design has not been run on a board.

---

## Verification

`sim/tb_soc_top.sv` runs the whole SoC with a UART receiver model (16 clocks per bit) and prints each byte it receives and the final captured string:

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
```

The bytes arrive 160 clock cycles apart because the second and later stores stall on `PREADY` until the UART finishes the previous byte. That run also exercises `lui`, `addi`, `sw`, `jal`, EX/MEM forwarding and APB write stalls. The testbench prints the captured string but does not compare it against the expected one automatically.

`sim/tb_riscv_top.sv` is a core-level harness with an APB memory model, a cycle trace and a signature check (the firmware writes `0xCAFEC000` to `0xFF0` to pass). It needs a self-checking test program, and none is included yet.

### Known issue

`lui` is decoded as `rs1 + imm`, and `rs1` is read from instruction bits 19:15, which belong to the immediate. It gives the right result only when the register named by those bits holds 0, as in the included program (`lui x10, 0x1`, where those bits name `x0`). A fix would force `rs1` to `x0` for `lui` in the decode stage.

### Not covered yet

- **No instruction-level tests.** Loads, conditional branches, shifts, logic operations, `slt`/`sltu`, `auipc`, `jalr`, the load-use stall and byte/halfword accesses are implemented but not exercised by any included test. There is no `riscv-tests` run.
- **No default APB slave.** An access above `0x0000_0810` is not decoded, so `PREADY` never rises and the CPU hangs.
- **No misaligned-access handling**, `FENCE`, `ECALL`, `EBREAK`, CSRs or interrupts.
- **Not run on hardware** (no pin constraints), and the UART default baud is simulation speed.
- **No branch prediction and no caches.** Every data access freezes the pipeline.

---

## Repository layout

```text
riscv-rv32i-soc/
├── rtl/        design sources (listed above)
├── sim/        tb_soc_top.sv, tb_riscv_top.sv, program.mem
├── constrs/    timing_constraints.xdc
├── LICENSE
└── README.md
```

## Running it in Vivado

1. Create an RTL project for `xc7z007sclg400-1`.
2. Add everything in `rtl/` as design sources (SystemVerilog) with `soc_top` as the top, and add `constrs/timing_constraints.xdc` as constraints.
3. Add `sim/tb_soc_top.sv` as a simulation source and set it as the simulation top. Add `sim/program.mem` as a simulation data file, since `soc_top.sv` reads it to initialize the data RAM.
4. Run Behavioral Simulation. The testbench runs for 100 µs and ends itself with `$finish`.
5. Run Synthesis and Implementation, then `report_timing_summary` and `report_utilization`.

## License

MIT. See [LICENSE](LICENSE).
