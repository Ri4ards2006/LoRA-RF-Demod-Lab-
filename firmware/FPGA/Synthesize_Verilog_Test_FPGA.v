// top.v - Blink / binary counter for Tang Nano 9K
module top (
  input  wire clk_27m,    // Onboard 27 MHz clock (pin name varies by board)
  input  wire rst_n,      // optional external reset (active low)
  output wire [5:0] LED   // up to 6 LEDs on Tang Nano 9K
);

  // Parameters: passe CLOCK_FREQ an falls anders
  parameter integer CLOCK_FREQ = 27000000; // 27 MHz
  parameter integer BLINK_HZ   = 1;        // 1 Hz blink
  localparam integer DIV = CLOCK_FREQ / (2 * BLINK_HZ);

  // wide counter for clock division
  reg [31:0] clk_div;
  always @(posedge clk_27m or negedge rst_n) begin
    if (!rst_n) clk_div <= 32'd0;
    else clk_div <= clk_div + 1;
  end

  // blink signal (toggles every DIV ticks)
  reg blink;
  always @(posedge clk_27m or negedge rst_n) begin
    if (!rst_n) blink <= 1'b0;
    else if (clk_div >= DIV-1) blink <= ~blink;
  end

  // small binary counter to show activity on multiple LEDs
  reg [2:0] bin;
  reg [23:0] slow; // slower divider for counter
  always @(posedge clk_27m or negedge rst_n) begin
    if (!rst_n) begin
      slow <= 24'd0;
      bin <= 3'd0;
    end else begin
      slow <= slow + 1;
      if (slow == 24'd0) bin <= bin + 1;
    end
  end

  // Map outputs:
  // LED[0] shows blink, LED[3:1] show binary counter bits
  assign LED[0] = blink;
  assign LED[2:1] = bin[1:0];
  assign LED[5:3] = 3'b000; // frei / nach Wunsch nutzen

endmodule
