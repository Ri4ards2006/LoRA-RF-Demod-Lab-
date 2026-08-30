// ============================================================================
// Module: adc_parallel_in
// Description: Parallel High-Speed ADC Capture Ingress (AD9280 / AD9226)
// Targets: Gowin GW1NR-9C (Sipeed Tang Nano 9K)
// ============================================================================

`default_nettype none

module adc_parallel_in #(
    parameter integer DATA_WIDTH = 8
)(
    input  wire                  clk_adc,       // Clock sourced from/synced to ADC (e.g. 32 MHz)
    input  wire                  rst_n,         // Active-low synchronous reset
    input  wire [DATA_WIDTH-1:0] raw_adc_data,  // Hardware pins connected to ADC D[7:0]
    input  wire                  raw_adc_otr,   // ADC Out-Of-Range / Overflow pin
    
    output reg  [DATA_WIDTH-1:0] sample_data,   // Signed 2's complement aligned sample
    output reg                   sample_valid,  // Data valid strobe
    output reg                   sample_clip    // Asserted on ADC analog saturation
);

    // Pipeline registers for IOB capture & timing closure
    (* IOB = "TRUE" *) reg [DATA_WIDTH-1:0] r_adc_d1;
    (* IOB = "TRUE" *) reg                  r_adc_otr1;
    reg [DATA_WIDTH-1:0]                    r_adc_d2;
    reg                                     r_adc_otr2;

    always @(posedge clk_adc or negedge rst_n) begin
        if (!rst_n) begin
            r_adc_d1     <= {DATA_WIDTH{1'b0}};
            r_adc_otr1   <= 1'b0;
            r_adc_d2     <= {DATA_WIDTH{1'b0}};
            r_adc_otr2   <= 1'b0;
            sample_data  <= {DATA_WIDTH{1'b0}};
            sample_valid <= 1'b0;
            sample_clip  <= 1'b0;
        end else begin
            // Stage 1: Capture at IOB boundary
            r_adc_d1     <= raw_adc_data;
            r_adc_otr1   <= raw_adc_otr;

            // Stage 2: Register in fabric
            r_adc_d2     <= r_adc_d1;
            r_adc_otr2   <= r_adc_otr1;

            // Stage 3: Offset-Binary to 2's Complement Conversion
            // AD9280 outputs 0x00 (-FS) to 0xFF (+FS) -> Invert MSB to obtain signed 2's comp
            sample_data  <= {~r_adc_d2[DATA_WIDTH-1], r_adc_d2[DATA_WIDTH-2:0]};
            sample_valid <= 1'b1;
            sample_clip  <= r_adc_otr2;
        end
    end

endmodule
`default_nettype wire

