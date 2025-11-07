#include <SPI.h>
#include <LoRa.h>

// ==========================
// CONFIGURATION SECTION
// ==========================
#define LORA_FREQUENCY      868E6       // EU frequency
#define LORA_SS_PIN         10
#define LORA_RST_PIN        9
#define LORA_DIO0_PIN       2
#define SERIAL_BAUDRATE     9600
#define MAX_MESSAGE_LENGTH  256
#define STATUS_INTERVAL_MS  5000
#define LORA_SYNC_WORD      0x34

// ==========================
// RUNTIME VARIABLES
// ==========================
unsigned long lastStatusTime = 0;
unsigned long packetCount = 0;
int lastRSSI = 0;
float avgRSSI = 0;

// ==========================
// FUNCTION DECLARATIONS
// ==========================
void printHeader();
void handlePacket();
void printStatus();
void restartLoRaIfNeeded();
void showError(const String& msg);
void setupLoRa();

// ==========================
// SETUP FUNCTION
// ==========================
void setup() {
  Serial.begin(SERIAL_BAUDRATE);
  while (!Serial);

  printHeader();
  setupLoRa();
  Serial.println("[INFO] Receiver ready. Waiting for packets...");
}

// ==========================
// MAIN LOOP
// ==========================
void loop() {
  int packetSize = LoRa.parsePacket();

  if (packetSize) {
    handlePacket();
  }

  unsigned long now = millis();
  if (now - lastStatusTime > STATUS_INTERVAL_MS) {
    printStatus();
    lastStatusTime = now;
  }

  restartLoRaIfNeeded();
}

// ==========================
// LORA INITIALIZATION
// ==========================
void setupLoRa() {
  Serial.println("[INFO] Initializing LoRa module...");

  LoRa.setPins(LORA_SS_PIN, LORA_RST_PIN, LORA_DIO0_PIN);

  if (!LoRa.begin(LORA_FREQUENCY)) {
    showError("LoRa init failed! Check wiring or frequency.");
    while (true);
  }

  LoRa.setSyncWord(LORA_SYNC_WORD);
  LoRa.enableCrc();

  Serial.print("[INFO] Frequency: ");
  Serial.println(LORA_FREQUENCY / 1E6, 3);
  Serial.print("[INFO] Sync Word: 0x");
  Serial.println(LORA_SYNC_WORD, HEX);
  Serial.println("[INFO] CRC: Enabled");
  Serial.println("[INFO] LoRa init success!");
}

// ==========================
// PACKET HANDLER
// ==========================
void handlePacket() {
  String incoming = "";

  while (LoRa.available()) {
    char c = (char)LoRa.read();
    incoming += c;
  }

  packetCount++;
  lastRSSI = LoRa.packetRssi();
  avgRSSI = (avgRSSI * (packetCount - 1) + lastRSSI) / packetCount;

  // JSON-style log output for later parsing
  Serial.println();
  Serial.println("{");
  Serial.print("  \"packet_id\": ");
  Serial.println(packetCount);
  Serial.print("  \"content\": \"");
  Serial.print(incoming);
  Serial.println("\",");
  Serial.print("  \"rssi\": ");
  Serial.print(lastRSSI);
  Serial.println(",");
  Serial.print("  \"snr\": ");
  Serial.print(LoRa.packetSnr());
  Serial.println(",");
  Serial.print("  \"timestamp\": ");
  Serial.println(millis());
  Serial.println("}");
  Serial.println("-----------------------------------------");
}

// ==========================
// STATUS MONITOR
// ==========================
void printStatus() {
  Serial.println();
  Serial.println("===== RECEIVER STATUS =====");
  Serial.print("Packets received: ");
  Serial.println(packetCount);
  Serial.print("Last RSSI: ");
  Serial.println(lastRSSI);
  Serial.print("Average RSSI: ");
  Serial.println(avgRSSI);
  Serial.print("Frequency: ");
  Serial.println(LORA_FREQUENCY / 1E6, 3);
  Serial.print("Uptime: ");
  Serial.print(millis() / 1000);
  Serial.println(" s");
  Serial.println("===========================");
}

// ==========================
// RESTART CHECK
// ==========================
void restartLoRaIfNeeded() {
  // Very simple failsafe: reinit every 5 minutes (for stability)
  static unsigned long lastRestart = 0;
  unsigned long now = millis();

  if (now - lastRestart > 300000) { // 5 minutes
    Serial.println("[WARN] Restarting LoRa module for stability...");
    LoRa.end();
    delay(1000);
    setupLoRa();
    lastRestart = now;
  }
}

// ==========================
// ERROR HANDLER
// ==========================
void showError(const String& msg) {
  Serial.println();
  Serial.println("[ERROR] =======================");
  Serial.println(msg);
  Serial.println("================================");
}

// ==========================
// HEADER OUTPUT
// ==========================
void printHeader() {
  Serial.println("========================================");
  Serial.println("         ADVANCED LORA RECEIVER");
  Serial.println("========================================");
  Serial.print("Build Time: ");
  Serial.println(__DATE__ " " __TIME__);
  Serial.println("========================================");
}
