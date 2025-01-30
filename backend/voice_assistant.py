import speech_recognition as sr

def voice_command_listener():
    recognizer = sr.Recognizer()
    with sr.Microphone() as source:
        print("🎤 Listening for voice commands...")
        try:
            audio = recognizer.listen(source)
            command = recognizer.recognize_google(audio)
            print(f"🗣️ Command Recognized: {command}")
            return command
        except sr.UnknownValueError:
            print("🤷 Could not understand audio")
        except sr.RequestError:
            print("❌ Could not request results")

if __name__ == "__main__":
    voice_command_listener()
