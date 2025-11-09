from flask import Flask, jsonify, request
import random
import threading
import time
import serial  # für echten Serial-Port (optional)

app = Flask(__name__)

# -----------------------
# Simulierte Signaldaten
# -----------------------
signal_data = [{"time": i, "value": 70 + random.gauss(0, 5)} for i in range(50)]

def update_signal():
    """Kontinuierliche Signaländerung simulieren"""
    global signal_data
    while True:
        signal_data = [{"time": i, "value": 70 + random.gauss(0, 5)} for i in range(50)]
        time.sleep(2)  # alle 2 Sekunden neue Werte

@app.route("/signal")
def get_signal():
    """API-Endpunkt für JavaFX: liefert Signal-Daten"""
    return jsonify(signal_data)

# -----------------------
# Optionaler Serial Monitor
# -----------------------
serial_lines = []

def read_serial(port="/dev/ttyUSB0", baud=9600):
    """Liest Daten vom seriellen Port"""
    try:
        ser = serial.Serial(port, baud, timeout=1)
        print(f"Connected to {port}")
        while True:
            if ser.in_waiting:
                line = ser.readline().decode().strip()
                serial_lines.append(line)
            time.sleep(0.1)
    except serial.SerialException:
        print(f"Serial port {port} not available. Skipping serial reading.")

@app.route("/serial")
def get_serial():
    """API-Endpunkt für Serial Monitor"""
    # liefert die letzten 50 Zeilen
    return jsonify(serial_lines[-50:])

@app.route("/serial/send", methods=["POST"])
def send_serial():
    """Optional: Kommando an Serial senden"""
    cmd = request.json.get("cmd", "")
    # Hier würdest du ser.write(cmd.encode()) machen, wenn Serial aktiv
    serial_lines.append(f"> {cmd} (simuliert)")
    return jsonify({"status": "sent", "cmd": cmd})

# -----------------------
# Main
# -----------------------
if __name__ == "__main__":
    # Signal-Update im Hintergrund
    t = threading.Thread(target=update_signal, daemon=True)
    t.start()

    # Optional: Serial-Monitor starten
    # t_serial = threading.Thread(target=read_serial, daemon=True)
    # t_serial.start()

    # Flask-Server starten
    app.run(host="0.0.0.0", port=5000)
