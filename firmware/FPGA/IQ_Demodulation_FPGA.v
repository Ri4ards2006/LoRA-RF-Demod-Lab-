// top_iq_demod.v - einfache IQ-Demodulation mit LED-Anzeige
module top_iq_demod (
    input  wire clk_27m,   // 27 MHz Clock
    input  wire rst_n,     // Reset, active low
    input  wire adc_in,    // Eingangssignal vom ADC / GPIO
    output wire [5:0] LED  // LEDs zur Visualisierung
);

    // Parameter
    parameter integer F_CARRIER = 1000000; // 1 MHz Trägerfrequenz
    parameter integer CLK_FREQ  = 27000000;
    localparam integer DIV = CLK_FREQ / (4 * F_CARRIER); // 4x, da 90°-Phasenversatz

    // ---------- Lokale Oszillatoren ----------
    reg [31:0] phase_cnt;
    reg [1:0]  phase;
    always @(posedge clk_27m or negedge rst_n) begin
        if (!rst_n) begin
            phase_cnt <= 32'd0;
            phase <= 2'd0;
        end else begin
            if (phase_cnt >= DIV) begin
                phase_cnt <= 0;
                phase <= phase + 1;
            end else begin
                phase_cnt <= phase_cnt + 1;
            end
        end
    end

    // Sinus & Cosinus als Rechteck-Näherung
    wire lo_i = (phase[1] == 1'b0);       // cos-Komponente
    wire lo_q = (phase[0] == 1'b0);       // sin-Komponente (90° verschoben)

    // ---------- IQ-Multiplikation ----------
    // XOR simuliert einfache Multiplikation zwischen binären Signalen
    wire I = adc_in ^ lo_i;
    wire Q = adc_in ^ lo_q;

    // ---------- Envelope Detection (Amplitude) ----------
    reg [7:0] envelope;
    always @(posedge clk_27m or negedge rst_n) begin
        if (!rst_n)
            envelope <= 0;
        else
            envelope <= {envelope[6:0], (I ^ Q)}; // einfache Aktivitätsanzeige
    end

    // ---------- LED-Visualisierung ----------
    assign LED[0] = I;
    assign LED[1] = Q;
    assign LED[5:2] = envelope[7:4]; // "Amplitude" -> Helligkeit per Bitmuster

endmodule
