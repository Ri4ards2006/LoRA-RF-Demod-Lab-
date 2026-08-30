// ============================================================================
// Module: symbol_peak_detector
// Description: Real-Time LoRa CSS 128-Bin DFT Correlator & ArgMax Peak Slicer
//
// Architecture:
// 1. Chip Accumulator: Integrates 16 decimated samples per chip into 128 complex values Z[c].
// 2. Ping-Pong BSRAM Buffer: Dual-buffered (128 words x 2 banks) for seamless continuous demodulation.
// 3. Fast DFT Search Engine: Computes Fourier projection X[k] = sum(Z[c] * exp(-j*2*pi*k*c/128)).
// 4. Power Slicer: Computes |X[k]|^2 = Re^2 + Im^2, tracks ArgMax(P[k]), and emits decoded symbol.
//
// Target: Gowin GW1NR-9C (Sipeed Tang Nano 9K)
// ============================================================================

`default_nettype none

module symbol_peak_detector #(
    parameter integer DATA_WIDTH        = 16,
    parameter integer SF                = 7,
    parameter integer N_BINS            = 1 << SF, // 128 bins
    parameter integer SAMPLES_PER_CHIP  = 16,      // 2048 / 128
    parameter         COS_LUT_FILE      = "cos_lut256.mem",
    parameter         SIN_LUT_FILE      = "sin_lut256.mem"
)(
    input  wire                              clk_dsp,            // High-speed DSP clock (>=27 MHz)
    input  wire                              rst_n,              // Active-low synchronous reset
    input  wire                              in_valid,           // Strobe from lora_dechirp core
    input  wire signed [DATA_WIDTH-1:0]      i_dechirp,          // Stationary baseband I
    input  wire signed [DATA_WIDTH-1:0]      q_dechirp,          // Stationary baseband Q

    output reg                               symbol_valid,       // Pulses high when symbol is decoded
    output reg  [SF-1:0]                     decoded_symbol,     // Demodulated symbol index (0..127)
    output reg  [31:0]                       peak_power          // Detected peak spectral magnitude
);

    // ------------------------------------------------------------------------
    // 1. Chip Accumulator & Ping-Pong Memory
    // ------------------------------------------------------------------------
    reg [4:0]  chip_sample_cnt;
    reg [6:0]  chip_idx;
    reg signed [19:0] acc_i, acc_q;
    reg bank_sel; // Ping-pong bank select

    // 256-word Dual-Bank Memory: Bank 0 = 0..127, Bank 1 = 128..255
    reg signed [15:0] z_re_mem [0:255];
    reg signed [15:0] z_im_mem [0:255];

    reg trigger_search;
    reg bank_search;

    always @(posedge clk_dsp or negedge rst_n) begin
        if (!rst_n) begin
            chip_sample_cnt <= 5'd0;
            chip_idx        <= 7'd0;
            acc_i           <= 20'sd0;
            acc_q           <= 20'sd0;
            bank_sel        <= 1'b0;
            trigger_search  <= 1'b0;
            bank_search     <= 1'b0;
        end else if (in_valid) begin
            if (chip_sample_cnt == (SAMPLES_PER_CHIP - 1)) begin
                chip_sample_cnt <= 5'd0;
                
                // Store accumulated chip into active bank (scaled to 16 bits)
                z_re_mem[{bank_sel, chip_idx}] <= (acc_i + $signed({{4{i_dechirp[15]}}, i_dechirp})) >>> 4;
                z_im_mem[{bank_sel, chip_idx}] <= (acc_q + $signed({{4{q_dechirp[15]}}, q_dechirp})) >>> 4;
                
                acc_i <= 20'sd0;
                acc_q <= 20'sd0;

                if (chip_idx == (N_BINS - 1)) begin
                    chip_idx       <= 7'd0;
                    bank_search    <= bank_sel;   // Search bank that just completed
                    bank_sel       <= ~bank_sel;  // Flip active ingestion bank
                    trigger_search <= 1'b1;       // Start search engine
                end else begin
                    chip_idx       <= chip_idx + 1'b1;
                    trigger_search <= 1'b0;
                end
            end else begin
                chip_sample_cnt <= chip_sample_cnt + 1'b1;
                acc_i           <= acc_i + $signed({{4{i_dechirp[15]}}, i_dechirp});
                acc_q           <= acc_q + $signed({{4{q_dechirp[15]}}, q_dechirp});
                trigger_search  <= 1'b0;
            end
        end else begin
            trigger_search <= 1'b0;
        end
    end

    // ------------------------------------------------------------------------
    // 2. Sine / Cosine Twiddle Factor LUTs
    // ------------------------------------------------------------------------
    reg signed [7:0] sin_rom [0:255];
    reg signed [7:0] cos_rom [0:255];

    initial begin
        $readmemh(COS_LUT_FILE, cos_rom);
        $readmemh(SIN_LUT_FILE, sin_rom);
    end

    // ------------------------------------------------------------------------
    // 3. Fast Sequential DFT Search Engine
    // Iterates k in [0..127], c in [0..127]
    // ------------------------------------------------------------------------
    localparam ST_IDLE    = 2'd0;
    localparam ST_SEARCH  = 2'd1;
    localparam ST_FINISH  = 2'd2;

    reg [1:0] state;
    reg [6:0] cur_k;
    reg [6:0] cur_c;
    reg signed [31:0] dft_re_acc, dft_im_acc;
    reg [31:0] max_pwr;
    reg [6:0]  best_symbol;

    // Twiddle phase: theta = 2 * pi * (k * c) / 128 -> LUT address = (k * c * 2) & 0xFF
    wire [7:0] twiddle_addr = (cur_k * cur_c * 2) & 8'hFF;
    wire signed [7:0] cos_twiddle = cos_rom[twiddle_addr];
    wire signed [7:0] sin_twiddle = sin_rom[twiddle_addr];

    wire signed [15:0] rd_z_re = z_re_mem[{bank_search, cur_c}];
    wire signed [15:0] rd_z_im = z_im_mem[{bank_search, cur_c}];

    always @(posedge clk_dsp or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            cur_k          <= 7'd0;
            cur_c          <= 7'd0;
            dft_re_acc     <= 32'sd0;
            dft_im_acc     <= 32'sd0;
            max_pwr        <= 32'd0;
            best_symbol    <= 7'd0;
            symbol_valid   <= 1'b0;
            decoded_symbol <= 7'd0;
            peak_power     <= 32'd0;
        end else begin
            case (state)
                ST_IDLE: begin
                    symbol_valid <= 1'b0;
                    if (trigger_search) begin
                        state       <= ST_SEARCH;
                        cur_k       <= 7'd0;
                        cur_c       <= 7'd0;
                        dft_re_acc  <= 32'sd0;
                        dft_im_acc  <= 32'sd0;
                        max_pwr     <= 32'd0;
                        best_symbol <= 7'd0;
                    end
                end

                ST_SEARCH: begin
                    // Multiply-Accumulate for DFT projection
                    // (Z_re + j*Z_im) * (cos - j*sin) = (Z_re*cos + Z_im*sin) + j*(Z_im*cos - Z_re*sin)
                    dft_re_acc <= dft_re_acc + (rd_z_re * cos_twiddle + rd_z_im * sin_twiddle);
                    dft_im_acc <= dft_im_acc + (rd_z_im * cos_twiddle - rd_z_re * sin_twiddle);

                    if (cur_c == (N_BINS - 1)) begin
                        cur_c <= 7'd0;
                        
                        // Compute power of current bin: P[k] = (Re/128)^2 + (Im/128)^2
                        // Truncating upper bits for comparison
                        begin
                            reg signed [15:0] bin_re;
                            reg signed [15:0] bin_im;
                            reg [31:0] bin_pwr;
                            
                            bin_re  = (dft_re_acc + (rd_z_re * cos_twiddle + rd_z_im * sin_twiddle)) >>> 12;
                            bin_im  = (dft_im_acc + (rd_z_im * cos_twiddle - rd_z_re * sin_twiddle)) >>> 12;
                            bin_pwr = (bin_re * bin_re) + (bin_im * bin_im);

                            if (bin_pwr > max_pwr) begin
                                max_pwr     <= bin_pwr;
                                best_symbol <= cur_k;
                            end
                        end

                        dft_re_acc <= 32'sd0;
                        dft_im_acc <= 32'sd0;

                        if (cur_k == (N_BINS - 1)) begin
                            state <= ST_FINISH;
                        end else begin
                            cur_k <= cur_k + 1'b1;
                        end
                    end else begin
                        cur_c <= cur_c + 1'b1;
                    end
                end

                ST_FINISH: begin
                    decoded_symbol <= best_symbol;
                    peak_power     <= max_pwr;
                    symbol_valid   <= 1'b1;
                    state          <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
`default_nettype wire

