// top_blink.v - einfache LED-Blink für Tang Nano 9K
module top_blink(
    input wire clk_27m,      // 27 MHz Clock vom Board
    input wire rst_n,        // Reset, active low
    output reg [3:0] LED     // 4 LEDs
);

    reg [23:0] counter;      // langsamer Zähler

    always @(posedge clk_27m or negedge rst_n) begin
        if (!rst_n)
            counter <= 24'd0;
        else
            counter <= counter + 1;
    end

    // Zeige die oberen Bits als LED-Blink
    always @(posedge clk_27m or negedge rst_n) begin
        if (!rst_n)
            LED <= 4'b0000;
        else
            LED <= counter[23:20]; // langsame Blinkrate
    end

endmodule
