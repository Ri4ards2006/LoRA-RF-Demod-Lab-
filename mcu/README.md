# MCU Telemetry & Stimulus Subsystem

This folder contains microcontroller firmware for generating known RF packets, digital baseband chirps, and low-jitter hardware synchronization triggers for the FPGA demodulator lab.

---

## 1. Hardware Pinout & Wiring Matrix

### A. ESP32 to SX1276 / SX1278 (SPI Transceiver)

| SX127x Pin | ESP32 Pin | Function | Notes |
| :--- | :--- | :--- | :--- |
| **VCC** | `3V3` | Power Supply | Connect $100\text{ nF} + 10\,\mu\text{F}$ decoupling capacitors |
| **GND** | `GND` | Ground Reference | Common ground with Tang Nano 9K |
| **NSS / CS** | `GPIO 18` | SPI Chip Select | Active LOW |
| **SCK** | `GPIO 5` / `SCK` | SPI Clock | Up to 10 MHz |
| **MISO** | `GPIO 19` | SPI Master-In Slave-Out | |
| **MOSI** | `GPIO 23` | SPI Master-Out Slave-In | |
| **RST** | `GPIO 14` | Hardware Reset | Active LOW |
| **DIO0** | `GPIO 27` | Packet Tx/Rx Done IRQ | Optional interrupt line |

### B. ESP32 to Tang Nano 9K / Testbench Interconnects

| Signal Name | ESP32 Pin | Tang Nano 9K Pin | Purpose |
| :--- | :--- | :--- | :--- |
| **`SYNC_MARKER`** | `GPIO 26` | `Pin 4` / Header | Low-jitter $10\,\mu\text{s}$ active-HIGH strobe asserted before preamble burst |
| **`ANALOG_STIM`** | `GPIO 25` (DAC1) | ADC Input Header | Baseband synthesized chirp for direct electrical loopback testing |
| **`GND`** | `GND` | `GND` | Common reference plane |

---

## 2. Firmware Features (`esp32_lora_stimulus`)

* **Dual-Mode Generation:**
  * **RF Mode:** Transmits over-the-air standard LoRa packets with embedded PRBS9 pseudo-random payloads.
  * **DAC/Baseband Mode:** Emits a hardware chirp directly on the built-in 8-bit DAC1 (`GPIO 25`) for bench testing without an external RF transmitter.
* **Hardware Frame Trigger:** Emits a precise $10\,\mu\text{s}$ synchronization pulse on `GPIO 26` at the exact start of every symbol/packet.
* **Serial CLI (115200 Baud):**
  * `BURST` - Force immediate trigger & packet transmission.
  * `SET_SF <7..12>` - Dynamically update Spreading Factor.
  * `SET_BW <125|250|500>` - Dynamically change signal bandwidth.
  * `SET_RATE <ms>` - Change repetition interval.
  * `STATUS` - Report live configuration registers.

---

## 3. Build & Flash Instructions

Using **PlatformIO Core / IDE**:

```bash
cd mcu/esp32_lora_stimulus

# Build firmware
pio run

# Upload to ESP32 over USB
pio run -t upload

# Open Serial Monitor CLI
pio device monitor -b 115200
```

