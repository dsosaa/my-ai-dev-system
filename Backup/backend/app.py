import sys
print("DEBUG: Python interpreter path:", sys.executable)

from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def home():
    return "✅ AI Dev System Backend Running!"

@app.route("/status")
def status():
    return {"status": "running", "uptime": "100%"}

@app.route('/api/status', methods=['GET'])
def api_status():
    return jsonify({'status': 'API is working'})

if __name__ == "__main__":
    app.run(port=3001)
