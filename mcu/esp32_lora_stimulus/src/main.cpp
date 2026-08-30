/**
 * ============================================================================
 * Project: LoRa-RF-Demod-Lab MCU Stimulus Engine
 * File: main.cpp
 * Target: ESP32 Dev Module (WROOM-32 / NodeMCU-32S)
 * 
 * Features:
 * - Generates synchronized RF bursts via SX1276 / SX1278 (LoRa / FSK).
 * - Generates hardware baseband / low-IF chirps on DAC/GPIO for direct cable bench testing.
 * - Emits a low-jitter 10µs SYNC_PULSE on GPIO 26 before every burst.
 * - Interactive Serial CLI to configure SF, Bandwidth, Frequency, and Power.
 * ============================================================================
 */

#include <Arduino.h>
#include <SPI.h>
#include <LoRa.h>

#ifndef SYNC_PIN
#define SYNC_PIN      26
#endif

#ifndef STIMULUS_PIN
#define STIMULUS_PIN  25 // Built-in 8-bit DAC1 on ESP32
#endif

#ifndef LORA_SS
#define LORA_SS       18
#endif

#ifndef LORA_RST
#define LORA_RST      14
#endif

#ifndef LORA_DIO0
#define LORA_DIO0     27
#endif

// Default RF Configuration (Europe 868.1 MHz / ISM 433 MHz)
long  loraFrequency = 868100000;
int   spreadingFactor = 7;
long  signalBandwidth = 125E3;
int   codingRateDenominator = 5;
int   txPower = 14; // dBm
bool  loraHardwarePresent = false;

// Stimulus Sequence Counter
uint32_t packetCounter = 0;
uint32_t lastTxTime = 0;
uint32_t burstIntervalMs = 1000; // 1 second period

// Function Prototypes
void initLoRaHardware();
void generateBasebandChirp(uint8_t symbol, uint8_t sf, uint32_t bw);
void transmitPacket();
void handleSerialCLI();

void setup() {
    Serial.begin(115200);
    while (!Serial && millis() < 2000);

    Serial.println("\n==================================================");
    Serial.println("  LoRa-RF-Demod-Lab: ESP32 Stimulus Generator   ");
    Serial.println("==================================================");

    // Initialize Sync and Stimulus Pins
    pinMode(SYNC_PIN, OUTPUT);
    digitalWrite(SYNC_PIN, LOW);

    pinMode(STIMULUS_PIN, OUTPUT);
    digitalWrite(STIMULUS_PIN, LOW);

    // Attempt SX127x initialization
    initLoRaHardware();

    Serial.println("\n[*] Ready. Type 'HELP' for interactive commands.");
}

void loop() {
    // Check for user commands over USB Serial
    if (Serial.available()) {
        handleSerialCLI();
    }

    // Periodic Burst Generation
    if (millis() - lastTxTime >= burstIntervalMs) {
        lastTxTime = millis();
        transmitPacket();
    }
}

void initLoRaHardware() {
    LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);

    Serial.printf("[*] Probing SX127x SPI transceiver on Freq: %ld Hz...\n", loraFrequency);
    if (!LoRa.begin(loraFrequency)) {
        Serial.println("[-] Warning: SX127x module not detected! Running in DAC/GPIO Baseband Mode only.");
        loraHardwarePresent = false;
        return;
    }

    loraHardwarePresent = true;
    LoRa.setSpreadingFactor(spreadingFactor);
    LoRa.setSignalBandwidth(signalBandwidth);
    LoRa.setCodingRate4(codingRateDenominator);
    LoRa.setTxPower(txPower);
    LoRa.setPreambleLength(8);
    LoRa.enableCrc();

    Serial.printf("[+] LoRa Hardware OK: SF=%d, BW=%.1f kHz, CR=4/%d, Pwr=%d dBm\n",
                  spreadingFactor, signalBandwidth / 1e3, codingRateDenominator, txPower);
}

void transmitPacket() {
    packetCounter++;

    // 1. Assert Hardware Sync Marker for Oscilloscope / Logic Analyzer / FPGA Trigger
    digitalWrite(SYNC_PIN, HIGH);
    delayMicroseconds(10); // 10 µs trigger pulse
    digitalWrite(SYNC_PIN, LOW);

    // 2. Synthesize Emulated DAC Baseband Chirp (Symbol = packetCounter % 128)
    uint8_t sym = (uint8_t)(packetCounter % (1 << spreadingFactor));
    generateBasebandChirp(sym, spreadingFactor, signalBandwidth);

    // 3. Transmit Over-The-Air RF Packet if Hardware Transceiver is Attached
    if (loraHardwarePresent) {
        LoRa.beginPacket();
        LoRa.printf("PKT:%08lu|SYM:%03u|PRBS:", packetCounter, sym);
        
        // Append 16-byte PRBS9 test payload
        uint16_t lfsr = 0x01FF;
        for (int i = 0; i < 16; i++) {
            uint8_t byteVal = 0;
            for (int b = 0; b < 8; b++) {
                uint8_t bit = ((lfsr >> 0) ^ (lfsr >> 4)) & 1;
                lfsr = (lfsr >> 1) | (bit << 8);
                byteVal |= (bit << b);
            }
            LoRa.write(byteVal);
        }
        LoRa.endPacket();
    }

    Serial.printf("[TX Burst #%lu] Trigger Pulse Emitted | Symbol=%u | DAC Sweep Generated\n",
                  packetCounter, sym);
}

/**
 * Generates an emulated baseband chirp on DAC1 (GPIO 25)
 */
void generateBasebandChirp(uint8_t symbol, uint8_t sf, uint32_t bw) {
    uint32_t nChips = 1 << sf;
    uint32_t totalSamples = 128;
    
    for (uint32_t i = 0; i < totalSamples; i++) {
        // Calculate instantaneous normalized phase: (symbol + linear_sweep)
        float progress = (float)i / totalSamples;
        float inst_freq = fmodf((float)symbol + progress * nChips, (float)nChips);
        float angle = 2.0f * PI * (inst_freq / nChips) * i;
        
        // 8-bit DAC output (0..255) centered at 128
        uint8_t dac_val = (uint8_t)(128.0f + 120.0f * sinf(angle));
        dacWrite(STIMULUS_PIN, dac_val);
        delayMicroseconds(2);
    }
    dacWrite(STIMULUS_PIN, 128); // Return to DC bias
}

void handleSerialCLI() {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    cmd.toUpperCase();

    if (cmd == "HELP") {
        Serial.println("\n--- Available Commands ---");
        Serial.println("  BURST            - Trigger immediate packet burst & sync pulse");
        Serial.println("  SET_SF <7-12>    - Set Spreading Factor (e.g. SET_SF 7)");
        Serial.println("  SET_BW <125|250> - Set Bandwidth in kHz (e.g. SET_BW 125)");
        Serial.println("  SET_RATE <ms>    - Set repetition interval (e.g. SET_RATE 500)");
        Serial.println("  STATUS           - Display current configuration");
    } else if (cmd == "BURST") {
        transmitPacket();
    } else if (cmd.startsWith("SET_SF ")) {
        int val = cmd.substring(7).toInt();
        if (val >= 6 && val <= 12) {
            spreadingFactor = val;
            if (loraHardwarePresent) LoRa.setSpreadingFactor(spreadingFactor);
            Serial.printf("[+] SF updated to %d\n", spreadingFactor);
        } else {
            Serial.println("[-] Invalid SF! Range: 6..12");
        }
    } else if (cmd.startsWith("SET_BW ")) {
        long val = cmd.substring(7).toInt() * 1000;
        if (val == 125000 || val == 250000 || val == 500000) {
            signalBandwidth = val;
            if (loraHardwarePresent) LoRa.setSignalBandwidth(signalBandwidth);
            Serial.printf("[+] Bandwidth updated to %ld Hz\n", signalBandwidth);
        } else {
            Serial.println("[-] Invalid BW! Must be 125, 250, or 500");
        }
    } else if (cmd.startsWith("SET_RATE ")) {
        int val = cmd.substring(9).toInt();
        if (val >= 10) {
            burstIntervalMs = val;
            Serial.printf("[+] Burst interval updated to %lu ms\n", burstIntervalMs);
        }
    } else if (cmd == "STATUS") {
        Serial.printf("[STATUS] Freq=%ld Hz, SF=%d, BW=%.1f kHz, Interval=%lu ms, HW=%s\n",
                      loraFrequency, spreadingFactor, signalBandwidth/1e3, burstIntervalMs,
                      loraHardwarePresent ? "SX127x CONNECTED" : "DAC ONLY");
    } else if (cmd.length() > 0) {
        Serial.println("[-] Unknown command. Type 'HELP' for instructions.");
    }
}

