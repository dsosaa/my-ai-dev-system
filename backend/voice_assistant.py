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

@app.route('/status')
def status():
    return {"status": "running"}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3001)

# AI Debugging Execution
def run_ai_debugging():
    import openai

    try:
        response = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[
                {"role": "system", "content": "Analyze the code and identify any bugs or improvements."},
                {"role": "user", "content": "Run an AI-powered debugging check."}
            ]
        )
        logger.info(f"AI Debugging Output: {response['choices'][0]['message']['content']}")
        return response['choices'][0]['message']['content']
    except Exception as e:
        logger.error(f"AI Debugging Failed: {str(e)}")
        return "AI debugging encountered an issue."
