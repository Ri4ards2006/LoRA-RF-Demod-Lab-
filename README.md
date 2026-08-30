# 📡 LoRa-RF-Demod-Lab

**FPGA-Based Real-Time Software-Defined Radio (SDR) & Wireless Communications Lab**

---

## 🔹 Overview

**LoRa-RF-Demod-Lab** is an experimental hardware, FPGA, and DSP development framework focused on real-time baseband demodulation of wireless signals (LoRa Chirp Spread Spectrum & FSK/GFSK). The lab bridges microcontrollers (ESP32, RP2040) emitting ground-truth RF telemetry with a **Sipeed Tang Nano 9K (Gowin GW1NR-9C)** FPGA performing high-speed parallel digital downconversion (DDC), decimation filtering, and demodulation.

---

## 🏗️ Architecture & Signal Processing Pipeline

```
+--------------------------------------------------------------------------------------------------+
| RF / IF STIMULUS               FPGA DIGITAL SIGNAL PROCESSING (DDC)             HOST TELEMETRY   |
|                                                                                                  |
| [ ESP32 / SX1276 ]            +-------------------+     +------------------+                     |
|  868 MHz / 433 MHz            | AD9280 Ingress    |     | 16-Bit NCO Mixer |                     |
|         |                     | (32 MSPS Parallel)| --> | (f_IF = 3.0 MHz) |                     |
|         v                     +-------------------+     +------------------+                     |
| [ RF Downconverter / IF ]                                         | (I/Q Baseband)               |
|         |                                                         v                              |
|         v                                               +------------------+                     |
| [ AD9280 8-Bit ADC ] ---------------------------------> | 3rd-Order CIC    |                     |
| (Offset Binary -> 2's Comp)                             | Decimator (R=16) |                     |
|                                                         +------------------+                     |
|                                                                   |                              |
|                                                                   v                     +-----+  |
|                                                         +------------------+  UART/USB  | BER |  |
|                                                         | De-Chirp & FFT   | ---------> | GUI |  |
|                                                         | Peak Estimation  | (3 Mbaud)  | Log |  |
|                                                         +------------------+            +-----+  |
+--------------------------------------------------------------------------------------------------+
```

---

## 📂 Repository Structure

```
LoRa-RF-Demod-Lab/
├── dsp/                                # Floating- & Fixed-Point DSP Models
│   ├── models/
│   │   └── lora_css_simulator.py       # Bit-accurate LoRa numerical simulator & test vector generator
│   ├── test_vectors/
│   │   ├── cos_lut256.mem              # Q1.7 Cosine ROM lookup table
│   │   ├── sin_lut256.mem              # Q1.7 Sine ROM lookup table
│   │   └── lora_if_stimulus.mem        # Synthesized 8-bit quantized IF stimulus vector
│   └── tools/
│       └── gen_lut.py                  # NCO trigonometric LUT generator
├── hw/
│   ├── fpga/
│   │   ├── Makefile                    # OSS CAD Suite toolchain (Yosys/NextPNR/Apycula/openFPGALoader)
│   │   ├── constraints/
│   │   │   ├── tangnano9k.cst          # Physical pin constraints (AD9280 + LEDs + Clock)
│   │   │   └── tangnano9k.sdc          # SDC timing & false-path definitions
│   │   ├── legacy/                     # Early experimentation Verilog modules
│   │   ├── rtl/
│   │   │   ├── top_rf_demod.v          # Top-level FPGA integration & diagnostic LED matrix
│   │   │   ├── capture/
│   │   │   │   └── adc_parallel_in.v   # AD9280 IOB double-registered capture engine
│   │   │   └── dsp/
│   │   │       ├── nco_quad_mixer.v    # 16-bit NCO Quadrature Downconverter
│   │   │       └── cic_decimator.v     # 3rd-order CIC Decimation Filter (R=16, 28-bit accumulator)
│   │   └── sim/
│   │       └── tb_top_rf_demod.v       # Automated Icarus Verilog testbench
│   └── pcb/                            # KiCad 8 RF front-end schematics & 50Ω GCPW layouts
├── mcu/
│   ├── README.md                       # Microcontroller wiring matrix & CLI documentation
│   └── esp32_lora_stimulus/            # ESP32 + SX1276 PRBS generator & DAC baseband testbench
└── tools/                              # Automated Python logging & BER/PER test scripts
```

---

## 🚀 Quick Start Guide

### 1. Generate Golden Stimulus & Verify Python Model

```bash
# Run LoRa CSS numerical model (SF=7, BW=125 kHz, Symbol=42, f_IF=3 MHz)
python3 dsp/models/lora_css_simulator.py --sf 7 --bw 125000 --symbol 42 --fif 3000000 --fs 32000000
```

### 2. Simulate FPGA DDC Pipeline (Icarus Verilog)

```bash
cd hw/fpga
make sim

# View signal waveforms with GTKWave:
gtkwave build/dump.vcd
```

### 3. Synthesize & Flash Tang Nano 9K (OSS CAD Suite)

```bash
cd hw/fpga

# Compile & load bitstream directly to FPGA SRAM:
make sram

# Flash bitstream to on-chip persistent Flash:
make flash
```

### 4. Build & Flash ESP32 Stimulus Generator

```bash
cd mcu/esp32_lora_stimulus
pio run -t upload
pio device monitor -b 115200
```

---

## 📜 Hardware Specifications

* **FPGA:** Gowin GW1NR-LV9QN88PC6/I5 (8,640 LUT4, 6,480 FF, 26 BSRAMs, 2 DSP multipliers)
* **ADC:** AD9280 (8-bit, 32 MSPS parallel CMOS output)
* **MCU Reference Nodes:** ESP32, RP2040 (Raspberry Pi Pico)
* **RF Transceivers:** Semtech SX1276 / SX1278 (LoRa), Nordic nRF24L01+ (2.4 GHz GFSK)
* **Target RF Bands:** $433\text{ MHz}$ / $868\text{ MHz}$ ISM Bands ($50\,\Omega$ GCPW matching)
