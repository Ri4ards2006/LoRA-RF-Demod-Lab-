#!/usr/bin/env python3
"""
lora_css_simulator.py - End-to-End Numerical Simulation & Test Vector Generator
for LoRa Chirp Spread Spectrum (CSS) Modulation & Demodulation.

Features:
- Bit-accurate LoRa baseband chirp modulation (SF=7..12, BW=125/250/500 kHz).
- IF Upconversion (f_IF = 3.0 MHz) and 8-bit ADC quantization (32 MSPS).
- Verilog .mem testbench vector exporter (Q1.7 signed hex).
- Digital Downconversion (DDC), Conjugate De-chirping & FFT Peak Extraction.
- Verification assertion of decoded symbol against ground truth.
"""

import os
import argparse
import numpy as np

def generate_lora_symbol(sf=7, bw=125e3, symbol=42, fs=32e6, fif=3e6, snr_db=None):
    """
    Synthesize an IF-modulated, 8-bit quantized LoRa chirp symbol.
    """
    n_chips = 2 ** sf
    t_sym = n_chips / bw  # Symbol duration (s)
    n_samples = int(round(t_sym * fs))
    t = np.arange(n_samples) / fs
    chirp_rate = bw / t_sym  # mu = BW^2 / 2^SF (Hz/s)

    # 1. Baseband Modulated LoRa Chirp
    # Instantaneous frequency starts at (symbol/n_chips)*BW and sweeps linearly with wrap-around
    f_offset = (symbol / n_chips) * bw
    f_inst = (f_offset + chirp_rate * t) % bw - (bw / 2.0)
    
    # Phase calculation via numerical integration
    phi_bb = 2.0 * np.pi * np.cumsum(f_inst) / fs
    s_bb = np.exp(1j * phi_bb)

    # 2. IF Upconversion: x_IF(t) = Re{ s_bb(t) * exp(j * 2*pi * f_IF * t) }
    s_if = np.real(s_bb * np.exp(1j * 2.0 * np.pi * fif * t))

    # Optional AWGN Channel Noise
    if snr_db is not None:
        sig_pwr = np.mean(s_if ** 2)
        noise_pwr = sig_pwr / (10.0 ** (snr_db / 10.0))
        noise = np.random.normal(0, np.sqrt(noise_pwr), n_samples)
        s_if = s_if + noise

    # 3. 8-Bit Signed ADC Quantization (-128 to +127)
    s_norm = s_if / (np.max(np.abs(s_if)) + 1e-9)
    s_quant = np.clip(np.round(s_norm * 127.0), -128, 127).astype(np.int8)

    return {
        "sf": sf,
        "bw": bw,
        "symbol": symbol,
        "fs": fs,
        "fif": fif,
        "t_sym": t_sym,
        "n_samples": n_samples,
        "n_chips": n_chips,
        "t": t,
        "s_bb": s_bb,
        "s_if": s_if,
        "s_quant": s_quant,
        "chirp_rate": chirp_rate
    }

def export_mem_vector(quant_samples, filename):
    """
    Export 8-bit signed integer samples to Verilog $readmemh hex file.
    """
    os.makedirs(os.path.dirname(os.path.abspath(filename)), exist_ok=True)
    with open(filename, "w") as f:
        for s in quant_samples:
            # 2's complement 8-bit hex
            u8_val = int(s) & 0xFF
            f.write(f"{u8_val:02X}\n")
    print(f"[+] Exported {len(quant_samples)} stimulus samples to: {filename}")

def demodulate_lora_symbol(sim_data):
    """
    Complete DSP Demodulation: DDC -> Decimation -> Conjugate De-chirping -> FFT -> Peak Finder
    """
    s_quant = sim_data["s_quant"].astype(np.float64)
    fs = sim_data["fs"]
    fif = sim_data["fif"]
    t = sim_data["t"]
    sf = sim_data["sf"]
    bw = sim_data["bw"]
    n_chips = sim_data["n_chips"]
    t_sym = sim_data["t_sym"]
    chirp_rate = sim_data["chirp_rate"]

    # 1. Digital Downconversion (Quadrature Mixing with Local NCO)
    lo_cos = np.cos(2.0 * np.pi * fif * t)
    lo_sin = np.sin(2.0 * np.pi * fif * t)
    i_raw = s_quant * lo_cos
    q_raw = -s_quant * lo_sin
    iq_raw = i_raw + 1j * q_raw

    # 2. Decimation to chip rate (1 sample per chip, N = 2^SF points)
    # Using integration/average over each chip period
    samples_per_chip = len(t) // n_chips
    iq_dec = np.zeros(n_chips, dtype=complex)
    for c in range(n_chips):
        idx_start = c * samples_per_chip
        idx_end = (c + 1) * samples_per_chip
        iq_dec[c] = np.mean(iq_raw[idx_start:idx_end])

    # 3. Conjugate Reference Downchirp (unmodulated raw downchirp: -BW/2 to +BW/2)
    t_chips = (np.arange(n_chips) + 0.5) * (t_sym / n_chips)
    f_down = (chirp_rate * t_chips) % bw - (bw / 2.0)
    phi_down = 2.0 * np.pi * np.cumsum(f_down) * (t_sym / n_chips)
    ref_downchirp = np.exp(-1j * phi_down)

    # 4. De-chirping: Multiply received decimated signal by reference downchirp
    dechirped = iq_dec * ref_downchirp

    # 5. Discrete Fourier Transform (FFT) & Power Spectrum
    fft_spec = np.fft.fft(dechirped, n=n_chips)
    mag_spec = np.abs(fft_spec) ** 2

    # 6. Peak Estimation (ArgMax)
    detected_symbol = int(np.argmax(mag_spec))
    peak_power = mag_spec[detected_symbol]
    noise_floor = (np.sum(mag_spec) - peak_power) / (n_chips - 1 + 1e-9)
    peak_snr_db = 10.0 * np.log10(peak_power / (noise_floor + 1e-9))

    return {
        "detected_symbol": detected_symbol,
        "ground_truth": sim_data["symbol"],
        "peak_snr_db": peak_snr_db,
        "mag_spec": mag_spec,
        "success": (detected_symbol == sim_data["symbol"])
    }

def main():
    parser = argparse.ArgumentParser(description="LoRa CSS Simulator & Test Vector Generator")
    parser.add_argument("--sf", type=int, default=7, help="Spreading Factor (7..12, default=7)")
    parser.add_argument("--bw", type=float, default=125e3, help="Bandwidth in Hz (default=125000)")
    parser.add_argument("--symbol", type=int, default=42, help="Symbol to modulate (0..2^SF-1, default=42)")
    parser.add_argument("--fs", type=float, default=32e6, help="Sampling frequency (default=32 MHz)")
    parser.add_argument("--fif", type=float, default=3e6, help="Intermediate frequency (default=3 MHz)")
    parser.add_argument("--snr", type=float, default=30.0, help="Channel SNR in dB (default=30 dB)")
    parser.add_argument("--out", type=str, default=None, help="Output .mem file path")
    args = parser.parse_args()

    print("=================================================================")
    print("      LoRa CSS Numerical Simulator & DSP Verification Core       ")
    print("=================================================================")
    print(f"[*] Configuration: SF={args.sf}, BW={args.bw/1e3:.1f} kHz, Symbol={args.symbol}")
    print(f"[*] Acquisition:   f_s={args.fs/1e6:.1f} MSPS, f_IF={args.fif/1e6:.1f} MHz, SNR={args.snr} dB")

    # 1. Synthesize Stimulus
    sim_data = generate_lora_symbol(
        sf=args.sf,
        bw=args.bw,
        symbol=args.symbol,
        fs=args.fs,
        fif=args.fif,
        snr_db=args.snr
    )
    print(f"[*] Generated Symbol Duration: {sim_data['t_sym']*1e3:.3f} ms ({sim_data['n_samples']} samples)")

    # 2. Export Memory File
    if args.out is None:
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        out_mem = os.path.join(base_dir, "test_vectors", "lora_if_stimulus.mem")
    else:
        out_mem = args.out

    export_mem_vector(sim_data["s_quant"], out_mem)

    # Also copy to FPGA sim directory for easy Verilog access
    sim_dir_mem = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "..", "hw", "fpga", "sim", "lora_if_stimulus.mem"
    )
    export_mem_vector(sim_data["s_quant"], sim_dir_mem)

    # 3. Run Golden Reference DSP Demodulation
    print("\n[*] Executing Golden Reference DSP Demodulator...")
    results = demodulate_lora_symbol(sim_data)

    print("-----------------------------------------------------------------")
    print(f"[*] Ground Truth Symbol: {results['ground_truth']}")
    print(f"[*] Demodulated Symbol:  {results['detected_symbol']}")
    print(f"[*] Peak Spectral SNR:   {results['peak_snr_db']:.2f} dB")
    print(f"[*] Demodulation Status: {'[ PASS ] EXACT MATCH' if results['success'] else '[ FAIL ] MISMATCH'}")
    print("=================================================================")

    if not results["success"]:
        raise ValueError(f"Demodulation verification failed! Expected {results['ground_truth']}, got {results['detected_symbol']}")

if __name__ == "__main__":
    main()

