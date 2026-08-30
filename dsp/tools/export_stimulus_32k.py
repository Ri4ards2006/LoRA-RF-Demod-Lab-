#!/usr/bin/env python3
"""
export_stimulus_32k.py - Generate full 32768-sample (1.024ms @ 32 MSPS)
quantized LoRa IF stimulus vector for Symbol 42 without any comments.
"""

import os
import math

def generate_stimulus_32k():
    sf = 7
    bw = 125000.0
    symbol = 42
    fs = 32000000.0
    fif = 3000000.0
    n_chips = 2 ** sf
    t_sym = n_chips / bw  # 0.001024 s
    n_samples = 32768
    chirp_rate = bw / t_sym  # 122070312.5 Hz/s
    f_offset = (symbol / n_chips) * bw  # 41015.625 Hz

    # Wrap time when frequency reaches +BW/2
    t_wrap = (bw - f_offset) / chirp_rate
    phi_accum = 0.0
    dt = 1.0 / fs

    hex_lines = []

    for n in range(n_samples):
        t = n * dt
        # Instantaneous baseband frequency
        f_inst = (f_offset + chirp_rate * t) % bw - (bw / 2.0)
        phi_accum += 2.0 * math.pi * f_inst * dt

        # IF Upconversion
        s_if = math.cos(phi_accum + 2.0 * math.pi * fif * t)
        s_quant = int(round(127.0 * s_if))
        s_quant = max(-128, min(127, s_quant))
        s_u8 = (s_quant + 256) & 0xFF if s_quant < 0 else s_quant & 0xFF
        hex_lines.append(f"{s_u8:02X}")

    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    fpga_dir = os.path.join(base_dir, "..", "hw", "fpga")

    dest_paths = [
        os.path.join(base_dir, "test_vectors", "lora_if_stimulus.mem"),
        os.path.join(fpga_dir, "sim", "lora_if_stimulus.mem"),
        os.path.join(fpga_dir, "build", "lora_if_stimulus.mem"),
        os.path.join(fpga_dir, "lora_if_stimulus.mem")
    ]

    for p in dest_paths:
        os.makedirs(os.path.dirname(os.path.abspath(p)), exist_ok=True)
        with open(p, "w") as f:
            f.write("\n".join(hex_lines) + "\n")
        print(f"[+] Written {len(hex_lines)} samples to: {p}")

if __name__ == "__main__":
    generate_stimulus_32k()

