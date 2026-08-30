// Timing Constraints for Tang Nano 9K SDR Demodulator
// Primary Reference Oscillator
create_clock -name clk_27m -period 37.037 [get_ports {clk_27m}]

// Synthesized DSP & Sampling Clock (Derived from PLL: 54.0 MHz)
create_generated_clock -name clk_dsp -source [get_ports {clk_27m}] -master_clock clk_27m -multiply_by 2 [get_pins {u_pll/CLKOUT}]

// Forwarded ADC Clock (32.0 MHz)
create_generated_clock -name adc_clk_out -source [get_ports {clk_27m}] -multiply_by 32 -divide_by 27 [get_pins {u_pll/CLKOUTD}]

// Input Constraints for AD9280 Parallel Bus
set_input_delay -clock [get_clocks {adc_clk_out}] -max 5.0 [get_ports {raw_adc_data[*] raw_adc_otr}]
set_input_delay -clock [get_clocks {adc_clk_out}] -min 1.0 [get_ports {raw_adc_data[*] raw_adc_otr}]

// False Path between Asynchronous Clock Domains
set_clock_groups -asynchronous -group [get_clocks {clk_27m}] -group [get_clocks {clk_dsp}] -group [get_clocks {adc_clk_out}]

