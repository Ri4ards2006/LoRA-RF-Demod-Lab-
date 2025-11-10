from flask import Flask, jsonify
import random

app = Flask(__name__)

# Status-Route
@app.route("/")
def home():
    return jsonify({"status": "running", "message": "AetherScan backend alive!"})

# Signal-Route mit zufälligen Werten
@app.route("/signal")
def signal():
    # Zufällige Signalstärke zwischen 50 und 100 simulieren
    signal_strength = random.randint(50, 100)
    data = {
        "signal_strength": signal_strength,
        "status": "stable" if signal_strength > 60 else "weak"
    }
    return jsonify(data)

# Optional: Health-Check Route
@app.route("/health")
def health():
    return jsonify({"backend": "ok", "uptime": "short test mode"})

if __name__ == "__main__":
    # Debug=True zeigt dir Fehler direkt im Browser
    app.run(host="0.0.0.0", port=5000, debug=True)
