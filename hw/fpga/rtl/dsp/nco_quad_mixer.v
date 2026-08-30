// ============================================================================
// Module: nco_quad_mixer
// Description: Direct Digital Downconverter (NCO + Quadrature Mixer)
// Formula: I[n] = x[n] * cos(w*n),  Q[n] = -x[n] * sin(w*n)
// Targets: Gowin GW1NR-9C (Sipeed Tang Nano 9K)
// ============================================================================

`default_nettype none

module nco_quad_mixer #(
    parameter integer PHASE_WIDTH    = 16,
    parameter integer DATA_IN_WIDTH  = 8,
    parameter integer DATA_OUT_WIDTH = 16,
    parameter         COS_LUT_FILE   = "cos_lut256.mem",
    parameter         SIN_LUT_FILE   = "sin_lut256.mem"
)(
    input  wire                             clk_dsp,       // DSP Processing Clock (e.g. 54 MHz)
    input  wire                             rst_n,         // Active-low reset
    input  wire                             sample_valid,  // Strobe for incoming ADC sample
    input  wire signed [DATA_IN_WIDTH-1:0]  adc_sample,    // Signed input sample x[n]
    input  wire [PHASE_WIDTH-1:0]           phase_inc,     // Tuning word: (f_IF / f_sample) * 2^16

    output reg                              iq_valid,      // IQ output valid strobe
    output reg  signed [DATA_OUT_WIDTH-1:0] i_out,         // In-phase baseband component
    output reg  signed [DATA_OUT_WIDTH-1:0] q_out          // Quadrature baseband component
);

    // ------------------------------------------------------------------------
    // 1. Phase Accumulator
    // ------------------------------------------------------------------------
    reg [PHASE_WIDTH-1:0] phase_acc;

    always @(posedge clk_dsp or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc <= {PHASE_WIDTH{1'b0}};
        end else if (sample_valid) begin
            phase_acc <= phase_acc + phase_inc;
        end
    end

    // ------------------------------------------------------------------------
    // 2. Sine / Cosine LUT (256 entries, 8-bit depth, Q1.7 format)
    // ------------------------------------------------------------------------
    wire [7:0] lut_addr = phase_acc[PHASE_WIDTH-1 : PHASE_WIDTH-8];
    reg signed [7:0] sin_rom [0:255];
    reg signed [7:0] cos_rom [0:255];

    initial begin
        $readmemh(COS_LUT_FILE, cos_rom);
        $readmemh(SIN_LUT_FILE, sin_rom);
    end

    reg signed [7:0] r_cos, r_sin;
    reg signed [DATA_IN_WIDTH-1:0] r_sample_d1;
    reg r_valid_d1;

    always @(posedge clk_dsp) begin
        if (sample_valid) begin
            r_cos       <= cos_rom[lut_addr];
            r_sin       <= sin_rom[lut_addr];
            r_sample_d1 <= adc_sample;
        end
        r_valid_d1 <= sample_valid;
    end

    // ------------------------------------------------------------------------
    // 3. DSP Quadrature Multipliers (Pipelined 18x18 mapping)
    // ------------------------------------------------------------------------
    always @(posedge clk_dsp or negedge rst_n) begin
        if (!rst_n) begin
            i_out    <= {DATA_OUT_WIDTH{1'b0}};
            q_out    <= {DATA_OUT_WIDTH{1'b0}};
            iq_valid <= 1'b0;
        end else begin
            if (r_valid_d1) begin
                // Signed multiplication: 8-bit ADC * 8-bit LO = 16-bit output
                i_out <= r_sample_d1 * r_cos;
                q_out <= - (r_sample_d1 * r_sin); // Inversion for negative quadrature downconversion
            end
            iq_valid <= r_valid_d1;
        end
    end

endmodule
`default_nettype wire

