// ============================================================================
// Module: top_rf_demod
// Description: Top-level FPGA Integration for RF Demodulation Lab
// Target: Sipeed Tang Nano 9K (Gowin GW1NR-LV9QN88PC6/I5)
// ============================================================================

`default_nettype none

module top_rf_demod (
    input  wire       clk_27m,        // 27 MHz onboard crystal oscillator
    input  wire       rst_n,          // Active-low user pushbutton reset (S1)
    
    // AD9280 Parallel ADC Ingress
    input  wire [7:0] raw_adc_data,   // ADC Parallel Data Bus D[7:0]
    input  wire       raw_adc_otr,    // ADC Out-Of-Range indicator
    output wire       adc_clk_out,    // Clock forwarded to ADC

    // Telemetry & Output
    output wire       uart_tx,        // UART Telemetry TX (BL702 bridge)
    output wire [5:0] led             // Onboard diagnostic LEDs
);

    // Forward 27 MHz clock directly to ADC as baseline sample clock
    assign adc_clk_out = clk_27m;

    // 1. ADC Capture Ingress
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

    // 2. NCO Quadrature Mixer (f_IF = 3.0 MHz, f_s = 27.0 MHz)
    // Phase step: (3.0 / 27.0) * 65536 = 7281 = 16'h1C71
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
        .phase_inc    (16'h1C71),
        .iq_valid     (iq_valid),
        .i_out        (i_baseband),
        .q_out        (q_baseband)
    );

    // 3. CIC Decimation Filters (R=16)
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

    // 4. Diagnostic LEDs & Heartbeat
    reg [23:0] hb_cnt;
    always @(posedge clk_27m or negedge rst_n) begin
        if (!rst_n) hb_cnt <= 24'd0;
        else hb_cnt <= hb_cnt + 1'b1;
    end

    assign led[0] = hb_cnt[23];           // Heartbeat (1.6 Hz)
    assign led[1] = sample_clip;          // ADC Over-Range Warning
    assign led[2] = cic_i_out[15];        // Sign of Decimated I
    assign led[3] = cic_q_out[15];        // Sign of Decimated Q
    assign led[4] = |cic_i_out[14:10];    // I-channel magnitude activity
    assign led[5] = |cic_q_out[14:10];    // Q-channel magnitude activity

    assign uart_tx = 1'b1; // Idle high

endmodule
`default_nettype wire

