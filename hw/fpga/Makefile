# =============================================================================
# Makefile for Gowin GW1NR-9C (Sipeed Tang Nano 9K)
# Toolchain: Yosys + NextPNR-Gowin + Apycula + openFPGALoader + Icarus Verilog
# =============================================================================

PROJECT       := lora_rf_demod_top
DEVICE_FAMILY := GW1N-9C
DEVICE_PART   := GW1NR-LV9QN88PC6/I5

# Source Files
RTL_DIR       := rtl
RTL_SRCS      := $(wildcard $(RTL_DIR)/*.v) \
                 $(wildcard $(RTL_DIR)/capture/*.v) \
                 $(wildcard $(RTL_DIR)/dsp/*.v) \
                 $(wildcard $(RTL_DIR)/demod/*.v) \
                 $(wildcard $(RTL_DIR)/comms/*.v)

CST_FILE      := constraints/tangnano9k.cst
SDC_FILE      := constraints/tangnano9k.sdc

BUILD_DIR     := build

.PHONY: all clean flash sram sim

all: $(BUILD_DIR)/$(PROJECT).fs

# Step 1: Synthesis with Yosys
$(BUILD_DIR)/$(PROJECT).json: $(RTL_SRCS) $(CST_FILE) | $(BUILD_DIR)
	@echo "--- [1/4] Running Synthesis with Yosys ---"
	yosys -p "read_verilog -sv $(RTL_SRCS); synth_gowin -top $(PROJECT) -json $@"

# Step 2: Place & Route with NextPNR-Gowin
$(BUILD_DIR)/$(PROJECT)_pnr.json: $(BUILD_DIR)/$(PROJECT).json $(CST_FILE) $(SDC_FILE)
	@echo "--- [2/4] Running Place-and-Route with NextPNR ---"
	nextpnr-gowin \
		--json $< \
		--write $@ \
		--device $(DEVICE_PART) \
		--family $(DEVICE_FAMILY) \
		--cst $(CST_FILE) \
		--sdc $(SDC_FILE)

# Step 3: Bitstream Generation with Gowin_Pack (Apycula)
$(BUILD_DIR)/$(PROJECT).fs: $(BUILD_DIR)/$(PROJECT)_pnr.json
	@echo "--- [3/4] Packing Bitstream with gowin_pack ---"
	gowin_pack -d $(DEVICE_FAMILY) -o $@ $<

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Step 4: Program Bitstream to Onboard SRAM (Volatile, Fast)
sram: $(BUILD_DIR)/$(PROJECT).fs
	@echo "--- [4/4] Flashing Tang Nano 9K (SRAM) ---"
	openFPGALoader -b tangnano9k -m $<

# Program Bitstream to Internal Flash (Persistent)
flash: $(BUILD_DIR)/$(PROJECT).fs
	@echo "--- [4/4] Flashing Tang Nano 9K (Internal Flash) ---"
	openFPGALoader -b tangnano9k -f $<

# Simulation Target (Icarus Verilog + GTKWave)
sim: | $(BUILD_DIR)
	@echo "--- [Sim 1/2] Compiling Simulation Testbench with Icarus Verilog ---"
	cp -f rtl/dsp/*.mem $(BUILD_DIR)/ 2>/dev/null || true
	cp -f sim/*.mem $(BUILD_DIR)/ 2>/dev/null || true
	iverilog -g2012 -I $(RTL_DIR)/dsp -I sim -o $(BUILD_DIR)/sim.vvp sim/tb_top_rf_demod.v $(RTL_SRCS)
	@echo "--- [Sim 2/2] Running VVP Simulation Engine ---"
	cd $(BUILD_DIR) && vvp sim.vvp
	@echo "-----------------------------------------------------------------"
	@echo "Simulation successful. Signal waveform dumped to: $(BUILD_DIR)/dump.vcd"
	@echo "To inspect traces, execute: gtkwave $(BUILD_DIR)/dump.vcd"
	@echo "-----------------------------------------------------------------"

clean:
	rm -rf $(BUILD_DIR)
