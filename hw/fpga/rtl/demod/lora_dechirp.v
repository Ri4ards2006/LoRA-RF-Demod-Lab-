// ============================================================================
// Module: lora_dechirp
// Description: Real-Time Baseband Conjugate De-Chirping Engine for LoRa CSS
//
// Operation:
// 1. Synthesizes a local conjugate reference downchirp r*(t) = I_down - j*Q_down.
// 2. Multiplies incoming analytical baseband sample (I_in + j*Q_in) with r*(t):
//      I_dechirp = I_in * I_down + Q_in * Q_down
//      Q_dechirp = Q_in * I_down - I_in * Q_down
// 3. Collapses linear frequency sweep into a stationary single tone at f_k.
//
// Target: Gowin GW1NR-9C (Sipeed Tang Nano 9K)
// ============================================================================

`default_nettype none

module lora_dechirp #(
    parameter integer DATA_WIDTH        = 16,
    parameter integer PHASE_WIDTH       = 16,
    parameter integer SAMPLES_PER_SYM   = 2048, // 2 MSPS decimated sample rate / (125 kHz / 128)
    parameter integer PHASE_INC_START   = -2048, // -BW/2 in 16-bit phase units (-62.5 kHz @ 2 MSPS)
    parameter integer PHASE_SLOPE       = 2,     // Linear frequency acceleration per sample
    parameter         COS_LUT_FILE      = "cos_lut256.mem",
    parameter         SIN_LUT_FILE      = "sin_lut256.mem"
)(
    input  wire                              clk_dsp,            // High-speed DSP Clock
    input  wire                              rst_n,              // Active-low synchronous reset
    input  wire                              in_valid,           // Valid strobe from CIC decimator
    input  wire signed [DATA_WIDTH-1:0]      i_in,               // Baseband In-Phase sample
    input  wire signed [DATA_WIDTH-1:0]      q_in,               // Baseband Quadrature sample

    output reg                               out_valid,          // Dechirped output strobe
    output reg  signed [DATA_WIDTH-1:0]      i_dechirp,          // Stationary analytical I
    output reg  signed [DATA_WIDTH-1:0]      q_dechirp,          // Stationary analytical Q
    output reg                               symbol_boundary     // Pulses high at end of symbol window
);

    // ------------------------------------------------------------------------
    // 1. Reference Downchirp Phase Trajectory Generator
    // ------------------------------------------------------------------------
    reg [11:0]                      sym_sample_cnt;
    reg signed [PHASE_WIDTH-1:0]    chirp_phase_inc;
    reg [PHASE_WIDTH-1:0]           chirp_phase_acc;

    always @(posedge clk_dsp or negedge rst_n) begin
        if (!rst_n) begin
            sym_sample_cnt   <= 12'd0;
            chirp_phase_inc  <= PHASE_INC_START;
            chirp_phase_acc  <= {PHASE_WIDTH{1'b0}};
            symbol_boundary  <= 1'b0;
        end else if (in_valid) begin
            if (sym_sample_cnt == (SAMPLES_PER_SYM - 1)) begin
                sym_sample_cnt   <= 12'd0;
                chirp_phase_inc  <= PHASE_INC_START;
                chirp_phase_acc  <= {PHASE_WIDTH{1'b0}};
                symbol_boundary  <= 1'b1;
            end else begin
                sym_sample_cnt   <= sym_sample_cnt + 1'b1;
                chirp_phase_inc  <= chirp_phase_inc + PHASE_SLOPE;
                chirp_phase_acc  <= chirp_phase_acc + chirp_phase_inc;
                symbol_boundary  <= 1'b0;
            end
        end else begin
            symbol_boundary <= 1'b0;
        end
    end

    // ------------------------------------------------------------------------
    // 2. Sine / Cosine Reference ROM (Q1.7 Format)
    // ------------------------------------------------------------------------
    wire [7:0] lut_addr = chirp_phase_acc[PHASE_WIDTH-1 : PHASE_WIDTH-8];
    reg signed [7:0] sin_rom [0:255];
    reg signed [7:0] cos_rom [0:255];

    initial begin
        $readmemh(COS_LUT_FILE, cos_rom);
        $readmemh(SIN_LUT_FILE, sin_rom);
    end

    reg signed [7:0]              r_cos_down, r_sin_down;
    reg signed [DATA_WIDTH-1:0]   r_i_in_d1, r_q_in_d1;
    reg                           r_valid_d1;

    always @(posedge clk_dsp) begin
        if (in_valid) begin
            r_cos_down <= cos_rom[lut_addr];
            r_sin_down <= sin_rom[lut_addr];
            r_i_in_d1  <= i_in;
            r_q_in_d1  <= q_in;
        end
        r_valid_d1 <= in_valid;
    end

    // ------------------------------------------------------------------------
    // 3. Complex Multiplier Core (Conjugate De-Chirping)
    // (I + jQ) * (cos - j*sin) = (I*cos + Q*sin) + j*(Q*cos - I*sin)
    // ------------------------------------------------------------------------
    reg signed [23:0] prod_ii, prod_qq, prod_qi, prod_iq;
    reg               r_valid_d2;

    always @(posedge clk_dsp or negedge rst_n) begin
        if (!rst_n) begin
            prod_ii    <= 24'sd0;
            prod_qq    <= 24'sd0;
            prod_qi    <= 24'sd0;
            prod_iq    <= 24'sd0;
            r_valid_d2 <= 1'b0;
        end else begin
            if (r_valid_d1) begin
                prod_ii <= r_i_in_d1 * r_cos_down;
                prod_qq <= r_q_in_d1 * r_sin_down;
                prod_qi <= r_q_in_d1 * r_cos_down;
                prod_iq <= r_i_in_d1 * r_sin_down;
            end
            r_valid_d2 <= r_valid_d1;
        end
    end

    // ------------------------------------------------------------------------
    // 4. Adder Stage & Dynamic Range Normalization
    // ------------------------------------------------------------------------
    always @(posedge clk_dsp or negedge rst_n) begin
        if (!rst_n) begin
            i_dechirp <= {DATA_WIDTH{1'b0}};
            q_dechirp <= {DATA_WIDTH{1'b0}};
            out_valid <= 1'b0;
        end else begin
            if (r_valid_d2) begin
                // Sum and scale back to 16 bits (Q1.7 LO scale removal)
                i_dechirp <= (prod_ii + prod_qq) >>> 7;
                q_dechirp <= (prod_qi - prod_iq) >>> 7;
            end
            out_valid <= r_valid_d2;
        end
    end

endmodule
`default_nettype wire

