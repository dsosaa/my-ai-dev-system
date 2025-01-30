from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return "✅ AI Dev System Backend Running!"

@app.route("/status")
def status():
    return {"status": "running", "uptime": "100%"}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
