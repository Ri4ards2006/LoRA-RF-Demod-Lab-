#include <SPI.h>
#include <LoRa.h>

// Pins für SX127x (je nach Modul evtl. anpassen)
#define SS_PIN    18
#define RST_PIN   14
#define DIO0_PIN  26

// Frequenz – anpassen an dein Land
#define LORA_FREQ 868E6  // Europa: 868 MHz

void setup() {
  Serial.begin(9600);
  while (!Serial);

  Serial.println("LoRa Sender Test startet...");

  // Pins konfigurieren
  LoRa.setPins(SS_PIN, RST_PIN, DIO0_PIN);

  // LoRa starten
  if (!LoRa.begin(LORA_FREQ)) {
    Serial.println("Fehler: Kein LoRa Modul gefunden!");
    while (1);
  }

  Serial.println("LoRa Initialisierung erfolgreich!");
}

void loop() {
  Serial.println("Sende Paket...");

  LoRa.beginPacket();
  LoRa.print("Hello LoRa :)");
  LoRa.endPacket();

  Serial.println("Paket gesendet!");
  delay(2000);  // alle 2 Sekunden senden
}
