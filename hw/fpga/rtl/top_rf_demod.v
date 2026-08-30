// ============================================================================
// Module: top_rf_demod
// Description: Top-level FPGA Integration for RF Demodulation Lab
// Target: Sipeed Tang Nano 9K (Gowin GW1NR-LV9QN88PC6/I5)
//
// Full Pipeline:
// 1. ADC Ingress (AD9280, 8-Bit Parallel, Offset Binary -> 2's Complement)
// 2. NCO Quadrature Mixer (f_IF = 3.0 MHz down to Analytical Baseband I/Q)
// 3. 3rd-Order CIC Decimation Filters (R=16, 32 MSPS -> 2 MSPS)
// 4. LoRa CSS Conjugate De-Chirp Correlator
// 5. 128-Bin DFT Energy Accumulator & ArgMax Peak Symbol Slicer
// 6. Diagnostic LEDs & Heartbeat
// ============================================================================

`default_nettype none

module top_rf_demod #(
    parameter [15:0] NCO_PHASE_INC = 16'h1800 // 3.0 MHz IF @ 32.0 MSPS ((3/32)*65536 = 6144)
)(
    input  wire       clk_27m,        // Master sample & DSP clock
    input  wire       rst_n,          // Active-low user pushbutton reset (S1)
    
    // AD9280 Parallel ADC Ingress
    input  wire [7:0] raw_adc_data,   // ADC Parallel Data Bus D[7:0]
    input  wire       raw_adc_otr,    // ADC Out-Of-Range indicator
    output wire       adc_clk_out,    // Clock forwarded to ADC

    // Demodulator Status & Telemetry
    output wire [6:0] sym_out,        // 7-bit decoded symbol (0..127)
    output wire       sym_valid,      // Symbol ready strobe
    output wire       uart_tx,        // UART Telemetry TX (BL702 bridge)
    output wire [5:0] led             // Onboard diagnostic LEDs
);

    // Forward clock directly to ADC
    assign adc_clk_out = clk_27m;

    // ------------------------------------------------------------------------
    // 1. ADC Capture Ingress
    // ------------------------------------------------------------------------
    wire [7:0] sample_data;
    wire       sample_valid;
    wire       sample_clip;

    adc_parallel_in #(
        .DATA_WIDTH(8)
    ) u_adc_ingress (
        .clk_adc      (clk_27m),
        .rst_n        (rst_n),
        .raw_adc_data (raw_adc_data),
        .raw_adc_otr  (raw_adc_otr),
        .sample_data  (sample_data),
        .sample_valid (sample_valid),
        .sample_clip  (sample_clip)
    );

    // ------------------------------------------------------------------------
    // 2. NCO Quadrature Mixer
    // ------------------------------------------------------------------------
    wire        iq_valid;
    wire signed [15:0] i_baseband;
    wire signed [15:0] q_baseband;

    nco_quad_mixer #(
        .PHASE_WIDTH   (16),
        .DATA_IN_WIDTH (8),
        .DATA_OUT_WIDTH(16),
        .COS_LUT_FILE  ("cos_lut256.mem"),
        .SIN_LUT_FILE  ("sin_lut256.mem")
    ) u_mixer (
        .clk_dsp      (clk_27m),
        .rst_n        (rst_n),
        .sample_valid (sample_valid),
        .adc_sample   (sample_data),
        .phase_inc    (NCO_PHASE_INC),
        .iq_valid     (iq_valid),
        .i_out        (i_baseband),
        .q_out        (q_baseband)
    );

    // ------------------------------------------------------------------------
    // 3. 3rd-Order CIC Decimation Filters (R=16)
    // ------------------------------------------------------------------------
    wire        cic_i_valid;
    wire signed [15:0] cic_i_out;
    wire        cic_q_valid;
    wire signed [15:0] cic_q_out;

    cic_decimator #(
        .IN_WIDTH  (16),
        .DEC_RATE  (16),
        .ACC_WIDTH (28)
    ) u_cic_i (
        .clk_dsp   (clk_27m),
        .rst_n     (rst_n),
        .in_valid  (iq_valid),
        .in_data   (i_baseband),
        .out_valid (cic_i_valid),
        .out_data  (cic_i_out)
    );

    cic_decimator #(
        .IN_WIDTH  (16),
        .DEC_RATE  (16),
        .ACC_WIDTH (28)
    ) u_cic_q (
        .clk_dsp   (clk_27m),
        .rst_n     (rst_n),
        .in_valid  (iq_valid),
        .in_data   (q_baseband),
        .out_valid (cic_q_valid),
        .out_data  (cic_q_out)
    );

    // ------------------------------------------------------------------------
    // 4. LoRa CSS Conjugate De-Chirp Correlator
    // ------------------------------------------------------------------------
    wire        dechirp_valid;
    wire signed [15:0] i_dechirp;
    wire signed [15:0] q_dechirp;
    wire        sym_boundary;

    lora_dechirp #(
        .DATA_WIDTH      (16),
        .PHASE_WIDTH     (16),
        .SAMPLES_PER_SYM (2048),
        .PHASE_INC_START (-2048),
        .PHASE_SLOPE     (2),
        .COS_LUT_FILE    ("cos_lut256.mem"),
        .SIN_LUT_FILE    ("sin_lut256.mem")
    ) u_dechirp (
        .clk_dsp         (clk_27m),
        .rst_n           (rst_n),
        .in_valid        (cic_i_valid),
        .i_in            (cic_i_out),
        .q_in            (cic_q_out),
        .out_valid       (dechirp_valid),
        .i_dechirp       (i_dechirp),
        .q_dechirp       (q_dechirp),
        .symbol_boundary (sym_boundary)
    );

    // ------------------------------------------------------------------------
    // 5. 128-Bin DFT Spectral Energy Slicer & Peak Detector
    // ------------------------------------------------------------------------
    wire [6:0]  decoded_symbol;
    wire [31:0] peak_power;
    wire        symbol_valid;

    symbol_peak_detector #(
        .DATA_WIDTH       (16),
        .SF               (7),
        .N_BINS           (128),
        .SAMPLES_PER_CHIP (16),
        .COS_LUT_FILE     ("cos_lut256.mem"),
        .SIN_LUT_FILE     ("sin_lut256.mem")
    ) u_peak_detector (
        .clk_dsp        (clk_27m),
        .rst_n          (rst_n),
        .in_valid       (dechirp_valid),
        .i_dechirp      (i_dechirp),
        .q_dechirp      (q_dechirp),
        .symbol_valid   (symbol_valid),
        .decoded_symbol (decoded_symbol),
        .peak_power     (peak_power)
    );

    assign sym_out   = decoded_symbol;
    assign sym_valid = symbol_valid;

    // ------------------------------------------------------------------------
    // 6. Diagnostic LEDs & Heartbeat
    // ------------------------------------------------------------------------
    reg [23:0] hb_cnt;
    reg [6:0]  r_latched_sym;

    always @(posedge clk_27m or negedge rst_n) begin
        if (!rst_n) begin
            hb_cnt        <= 24'd0;
            r_latched_sym <= 7'd0;
        end else begin
            hb_cnt <= hb_cnt + 1'b1;
            if (symbol_valid) begin
                r_latched_sym <= decoded_symbol;
            end
        end
    end

    // Display decoded symbol bits [5:0] on LEDs, or heartbeat on bit 0 when idle
    assign led[5:0] = (r_latched_sym[5:0] != 6'd0) ? r_latched_sym[5:0] : {5'b00000, hb_cnt[23]};

    assign uart_tx = 1'b1; // Idle high

endmodule
`default_nettype wire
