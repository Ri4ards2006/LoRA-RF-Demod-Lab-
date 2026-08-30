// top_demod.v - einfache AM-Demodulation / LED Anzeige
module top_demod (
    input  wire clk_27m,      // 27 MHz Clock
    input  wire rst_n,        // Reset, active low
    input  wire adc_in,       // Eingangssignal vom ADC / GPIO
    output wire [5:0] LED     // LEDs zur Visualisierung
);

    // Parameter für Taktteilung
    parameter integer CLOCK_FREQ = 27000000;
    parameter integer DEMO_HZ   = 1000; // 1 kHz Demodulationsausgabe
    localparam integer DIV = CLOCK_FREQ / (2 * DEMO_HZ);

    // Clock divider
    reg [31:0] clk_div;
    always @(posedge clk_27m or negedge rst_n) begin
        if (!rst_n) clk_div <= 32'd0;
        else clk_div <= clk_div + 1;
    end

    // Demodulation (einfacher Peak-Detector / Envelope)
    reg adc_reg1, adc_reg2;
    reg demod;
    always @(posedge clk_27m or negedge rst_n) begin
        if (!rst_n) begin
            adc_reg1 <= 1'b0;
            adc_reg2 <= 1'b0;
            demod    <= 1'b0;
        end else begin
            adc_reg1 <= adc_in;
            adc_reg2 <= adc_reg1;
            // einfacher Envelope-Detector: steigende Flanke detektieren
            if (adc_reg1 & ~adc_reg2) demod <= 1'b1;
            else demod <= 1'b0;
        end
    end

    // langsamer Zähler für LED-Anzeige
    reg [23:0] slow;
    reg [2:0] bin;
    always @(posedge clk_27m or negedge rst_n) begin
        if (!rst_n) begin
            slow <= 24'd0;
            bin  <= 3'd0;
        end else begin
            slow <= slow + 1;
            if (slow == 24'd0) bin <= bin + 1;
        end
    end

    // LED-Mapping:
    // LED[0] zeigt Demodulationssignal, LED[2:1] zeigen binären Zähler
    assign LED[0] = demod;
    assign LED[2:1] = bin[1:0];
    assign LED[5:3] = 3'b000; // frei

endmodule

