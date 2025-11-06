#include <SPI.h>
#include <nRF24L01.h>
#include <RF24.h>

RF24 radio(49, 53); // CE, CSN Pins

void setup() {
  Serial.begin(9600);
  Serial.println("=== nRF24L01 Diagnose ===");

  if (!radio.begin()) {
    Serial.println("❌ Kein nRF24L01 gefunden oder keine SPI-Verbindung!");
    while (1);
  }

  Serial.println("✅ nRF24L01 erkannt!");
  
  radio.printDetails(); // Gibt Registerwerte aus
}

void loop() {}
