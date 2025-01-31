import os

def run_ai_debugging():
    print("🔍 Running AI Debugging...")

    # Simulate checking for common coding issues
    issues_found = [
        "Syntax error in backend/app.py on line 23",
        "Missing import in scripts/full-setup.sh",
        "Undefined variable in backend/index.js"
    ]

    if issues_found:
        print("⚠️ Issues detected:")
        for issue in issues_found:
            print(f" - {issue}")
    else:
        print("✅ No issues found. Your project is clean!")

if __name__ == "__main__":
    run_ai_debugging()
