// ============================================================================
// Module: cic_decimator
// Description: 3rd-Order CIC Decimation Filter (N=3, M=1, Decimation Rate R=16)
// Bit Growth: B_growth = N * ceil(log2(R*M)) = 3 * 4 = 12 bits
// Output bit width = DATA_IN_WIDTH + 12
// Targets: Gowin GW1NR-9C (Sipeed Tang Nano 9K)
// ============================================================================

`default_nettype none

module cic_decimator #(
    parameter integer IN_WIDTH  = 16,
    parameter integer DEC_RATE  = 16, // Rate R
    parameter integer ACC_WIDTH = IN_WIDTH + 12 // 28 bits
)(
    input  wire                             clk_dsp,    // Fast System Processing Clock
    input  wire                             rst_n,      // Active-low reset
    input  wire                             in_valid,   // Input sample strobe
    input  wire signed [IN_WIDTH-1:0]       in_data,    // High-rate input (I or Q)

    output reg                              out_valid,  // Decimated sample strobe
    output reg  signed [IN_WIDTH-1:0]       out_data    // Truncated/Rounded output
);

    // ------------------------------------------------------------------------
    // 1. Integrator Stages (Running at High Sample Rate f_s)
    // ------------------------------------------------------------------------
    reg signed [ACC_WIDTH-1:0] itg_1, itg_2, itg_3;

    always @(posedge clk_dsp or negedge rst_n) begin
        if (!rst_n) begin
            itg_1 <= {ACC_WIDTH{1'b0}};
            itg_2 <= {ACC_WIDTH{1'b0}};
            itg_3 <= {ACC_WIDTH{1'b0}};
        end else if (in_valid) begin
            itg_1 <= itg_1 + $signed({{12{in_data[IN_WIDTH-1]}}, in_data});
            itg_2 <= itg_2 + itg_1;
            itg_3 <= itg_3 + itg_2;
        end
    end

    // ------------------------------------------------------------------------
    // 2. Rate Decimation Strobe Generator (Divide by R = 16)
    // ------------------------------------------------------------------------
    reg [4:0] dec_counter;
    reg       sample_strobe;

    always @(posedge clk_dsp or negedge rst_n) begin
        if (!rst_n) begin
            dec_counter   <= 5'd0;
            sample_strobe <= 1'b0;
        end else if (in_valid) begin
            if (dec_counter == (DEC_RATE - 1)) begin
                dec_counter   <= 5'd0;
                sample_strobe <= 1'b1;
            end else begin
                dec_counter   <= dec_counter + 1'b1;
                sample_strobe <= 1'b0;
            end
        end else begin
            sample_strobe <= 1'b0;
        end
    end

    // ------------------------------------------------------------------------
    // 3. Comb Stages (Running at Low Sample Rate f_s / R)
    // ------------------------------------------------------------------------
    reg signed [ACC_WIDTH-1:0] comb_1_d, comb_2_d, comb_3_d;
    reg signed [ACC_WIDTH-1:0] diff_1, diff_2, diff_3;

    always @(posedge clk_dsp or negedge rst_n) begin
        if (!rst_n) begin
            comb_1_d   <= {ACC_WIDTH{1'b0}};
            comb_2_d   <= {ACC_WIDTH{1'b0}};
            comb_3_d   <= {ACC_WIDTH{1'b0}};
            diff_1     <= {ACC_WIDTH{1'b0}};
            diff_2     <= {ACC_WIDTH{1'b0}};
            diff_3     <= {ACC_WIDTH{1'b0}};
            out_valid  <= 1'b0;
            out_data   <= {IN_WIDTH{1'b0}};
        end else if (sample_strobe) begin
            // Differentiation Stage 1
            diff_1     <= itg_3 - comb_1_d;
            comb_1_d   <= itg_3;

            // Differentiation Stage 2
            diff_2     <= diff_1 - comb_2_d;
            comb_2_d   <= diff_1;

            // Differentiation Stage 3
            diff_3     <= diff_2 - comb_3_d;
            comb_3_d   <= diff_2;

            // Select dynamic range (MSBs)
            out_data   <= diff_3[ACC_WIDTH-1 : ACC_WIDTH-IN_WIDTH];
            out_valid  <= 1'b1;
        end else begin
            out_valid  <= 1'b0;
        end
    end

endmodule
`default_nettype wire

