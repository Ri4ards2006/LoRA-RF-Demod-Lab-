// ============================================================================
// Testbench: tb_top_rf_demod
// Description: Automated Simulation of ADC Ingress -> NCO DDC -> CIC Decimation
// Reads stimulus from "lora_if_stimulus.mem"
// ============================================================================

`timescale 1ns / 1ps
`default_nettype none

module tb_top_rf_demod;

    // Parameters
    localparam integer CLK_PERIOD_NS = 31; // ~32 MHz (31.25ns)
    localparam integer TOTAL_SAMPLES = 4096; // Ingest first 4096 samples for simulation

    // Signals
    reg        clk_adc;
    reg        rst_n;
    reg  [7:0] raw_adc_data;
    reg        raw_adc_otr;

    // ADC Ingress Outputs
    wire [7:0] sample_data;
    wire       sample_valid;
    wire       sample_clip;

    // NCO Mixer Outputs
    wire        iq_valid;
    wire signed [15:0] i_baseband;
    wire signed [15:0] q_baseband;

    // CIC Decimator Outputs
    wire        cic_i_valid;
    wire signed [15:0] cic_i_out;
    wire        cic_q_valid;
    wire signed [15:0] cic_q_out;

    // Memory array for stimulus
    reg [7:0] stimulus_mem [0:TOTAL_SAMPLES-1];
    integer sample_idx;

    // ------------------------------------------------------------------------
    // Clock Generation (32.0 MHz ADC & DSP Clock for TB)
    // ------------------------------------------------------------------------
    initial begin
        clk_adc = 1'b0;
        forever #(CLK_PERIOD_NS / 2.0) clk_adc = ~clk_adc;
    end

    // ------------------------------------------------------------------------
    // Module Instantiations
    // ------------------------------------------------------------------------
    
    // 1. ADC Ingress Core
    adc_parallel_in #(
        .DATA_WIDTH(8)
    ) u_adc_in (
        .clk_adc      (clk_adc),
        .rst_n        (rst_n),
        .raw_adc_data (raw_adc_data),
        .raw_adc_otr  (raw_adc_otr),
        .sample_data  (sample_data),
        .sample_valid (sample_valid),
        .sample_clip  (sample_clip)
    );

    // 2. NCO Quadrature Mixer (Tuning Word for f_IF = 3 MHz at f_s = 32 MHz)
    // Phase Step: (3 MHz / 32 MHz) * 65536 = 6144 = 16'h1800
    nco_quad_mixer #(
        .PHASE_WIDTH   (16),
        .DATA_IN_WIDTH (8),
        .DATA_OUT_WIDTH(16),
        .COS_LUT_FILE  ("cos_lut256.mem"),
        .SIN_LUT_FILE  ("sin_lut256.mem")
    ) u_nco_mixer (
        .clk_dsp      (clk_adc),
        .rst_n        (rst_n),
        .sample_valid (sample_valid),
        .adc_sample   (sample_data),
        .phase_inc    (16'h1800), // 3.0 MHz IF tuning word
        .iq_valid     (iq_valid),
        .i_out        (i_baseband),
        .q_out        (q_baseband)
    );

    // 3. CIC Decimators (I & Q channels, Decimation R=16)
    cic_decimator #(
        .IN_WIDTH  (16),
        .DEC_RATE  (16),
        .ACC_WIDTH (28)
    ) u_cic_i (
        .clk_dsp   (clk_adc),
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
        .clk_dsp   (clk_adc),
        .rst_n     (rst_n),
        .in_valid  (iq_valid),
        .in_data   (q_baseband),
        .out_valid (cic_q_valid),
        .out_data  (cic_q_out)
    );

    // ------------------------------------------------------------------------
    // Stimulus Driver & Monitor
    // ------------------------------------------------------------------------
    integer decimated_sample_count = 0;

    initial begin
        $dumpfile("build/dump.vcd");
        $dumpvars(0, tb_top_rf_demod);

        // Load Stimulus Vector
        $readmemh("lora_if_stimulus.mem", stimulus_mem);

        // Initialize signals
        rst_n        = 1'b0;
        raw_adc_data = 8'h00;
        raw_adc_otr  = 1'b0;
        sample_idx   = 0;

        // Reset Sequence
        #(CLK_PERIOD_NS * 5);
        rst_n = 1'b1;
        #(CLK_PERIOD_NS * 2);

        $display("==========================================================");
        $display("[*] Starting FPGA Ingress & DDC Pipeline Simulation");
        $display("==========================================================");

        // Drive samples
        for (sample_idx = 0; sample_idx < TOTAL_SAMPLES; sample_idx = sample_idx + 1) begin
            @(posedge clk_adc);
            // Convert signed 2's comp from mem to offset binary for ADC pin drive
            raw_adc_data <= {~stimulus_mem[sample_idx][7], stimulus_mem[sample_idx][6:0]};
            raw_adc_otr  <= 1'b0;
        end

        // Wait for pipeline drain
        #(CLK_PERIOD_NS * 100);

        $display("==========================================================");
        $display("[*] Simulation Completed Successfully.");
        $display("[*] Total Decimated Samples Captured: %0d", decimated_sample_count);
        $display("==========================================================");
        $finish;
    end

    // Monitor decimated output
    always @(posedge clk_adc) begin
        if (cic_i_valid) begin
            decimated_sample_count <= decimated_sample_count + 1;
        end
    end

endmodule
`default_nettype wire

