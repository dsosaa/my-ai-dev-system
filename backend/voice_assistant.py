from flask import Flask
import speech_recognition as sr

app = Flask(__name__)

try:
    mic = sr.Microphone()
except OSError:
    print("⚠️ No default input device available. Running in non-audio mode.")
    mic = None  # Set mic to None so the app doesn't break

@app.route('/voice-command', methods=['GET'])
def voice_command_listener():
    recognizer = sr.Recognizer()
    with sr.Microphone() as source:
        print("🎤 Listening for voice commands...")
        try:
            audio = recognizer.listen(source)
            command = recognizer.recognize_google(audio)
            print(f"🗣️ Command Recognized: {command}")
            return {"command": command}
        except sr.UnknownValueError:
            print("🤷 Could not understand audio")
            return {"error": "Could not understand audio"}
        except sr.RequestError:
            print("❌ Could not request results")
            return {"error": "Could not request results"}

if __name__ == "__main__":
    app.run(port=3001)
