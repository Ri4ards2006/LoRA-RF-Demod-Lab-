#!/usr/bin/env python3
"""
gen_lut.py - Generate 256-entry Sine and Cosine ROM initialization files for NCO.
Format: Q1.7 signed 8-bit integers formatted as two-digit hexadecimal per line (NO comments).
Targets: nco_quad_mixer.v, lora_dechirp.v, symbol_peak_detector.v on Gowin GW1NR-9C.
"""

import os
import math

def generate_luts(num_entries=256, output_dirs=None):
    if output_dirs is None:
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        fpga_dir = os.path.join(base_dir, "..", "hw", "fpga")
        output_dirs = [
            os.path.join(fpga_dir, "rtl", "dsp"),
            os.path.join(fpga_dir, "sim"),
            os.path.join(fpga_dir, "build"),
            fpga_dir,
            os.path.join(base_dir, "test_vectors")
        ]

    cos_hex = []
    sin_hex = []

    for i in range(num_entries):
        theta = 2.0 * math.pi * i / num_entries
        # Scale to Q1.7 (-128 to +127)
        c_val = int(round(127.0 * math.cos(theta)))
        s_val = int(round(127.0 * math.sin(theta)))

        # Clamp to 8-bit signed range
        c_val = max(-128, min(127, c_val))
        s_val = max(-128, min(127, s_val))

        # Convert to 2's complement hex (8-bit)
        c_u8 = (c_val + 256) & 0xFF if c_val < 0 else c_val & 0xFF
        s_u8 = (s_val + 256) & 0xFF if s_val < 0 else s_val & 0xFF

        cos_hex.append(f"{c_u8:02X}")
        sin_hex.append(f"{s_u8:02X}")

    for out_dir in output_dirs:
        os.makedirs(out_dir, exist_ok=True)
        cos_file = os.path.join(out_dir, "cos_lut256.mem")
        sin_file = os.path.join(out_dir, "sin_lut256.mem")

        with open(cos_file, "w") as f:
            f.write("\n".join(cos_hex) + "\n")
        with open(sin_file, "w") as f:
            f.write("\n".join(sin_hex) + "\n")

        print(f"[+] Generated: {cos_file} ({len(cos_hex)} entries)")
        print(f"[+] Generated: {sin_file} ({len(sin_hex)} entries)")

if __name__ == "__main__":
    generate_luts()
