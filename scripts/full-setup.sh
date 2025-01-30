#!/bin/bash
echo "Setting up AI development system on Mac..."

# Define project directory
PROJECT_DIR="/Users/nsxo/Downloads/my-ai-dev-system"

# Check for required dependencies
echo "Checking dependencies..."
dependencies=("git" "node" "python3" "gh" "code")
for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        echo "Error: $dep is not installed. Please install it before proceeding."
        exit 1
    fi
done

# Navigate to project directory
cd "$PROJECT_DIR" || exit

# Initialize Git repository
if [ ! -d ".git" ]; then
    git init
    git add .
    git commit -m "Initial AI-based project structure"
fi

# Create GitHub repository and push
if command -v gh &> /dev/null; then
    gh repo create my-ai-dev-system --public --push
    git push -u origin main
else
    echo "GitHub CLI (gh) is not installed. Please create a repo manually on GitHub."
fi

echo "Project setup complete! Open VS Code and let GitHub Copilot generate your code."
