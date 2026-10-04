# -----------------------------------------------------------------------------
# Timing Constraints: RV32I Core SoC (90 MHz Sign-Off, Period = 11.111 ns)
# Fmax achieved on XC7Z007S-1: 92.52 MHz
# -----------------------------------------------------------------------------
create_clock -period 11.111 -name sys_clk -waveform {0.000 5.555} [get_ports clk]

# False Path for Asynchronous Active-Low Reset
set_false_path -from [get_ports rst_n]

# Allow bitstream generation without physical LOC pin mapping
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

# Default I/O Standard
set_property IOSTANDARD LVCMOS33 [get_ports -filter {NAME =~ *}]