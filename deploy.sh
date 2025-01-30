#!/usr/bin/env bash
#
# deploy.sh
#
# This script runs a step-by-step pipeline to:
# 1) Run pre-commit hooks
# 2) Validate Flask & Node backends
# 3) Execute unit tests
# 4) Build & test a Docker container
# 5) Deploy to Vercel
# 6) Push the final changes to GitHub
#
# If any step fails, the script exits and asks for manual intervention to fix issues.
# Re-run after fixing to continue from the point of failure.

########################################
# 0. PRE-FLIGHT CHECKS
########################################

# Optionally, you can check if required tools are installed. Uncomment checks as needed:

# command -v pre-commit >/dev/null 2>&1 || {
#   echo >&2 "ERROR: pre-commit is not installed. Please install and re-run."; exit 1;
# }
# command -v python >/dev/null 2>&1 || {
#   echo >&2 "ERROR: python is not installed. Please install and re-run."; exit 1;
# }
# command -v node >/dev/null 2>&1 || {
#   echo >&2 "ERROR: node is not installed. Please install and re-run."; exit 1;
# }
# command -v docker >/dev/null 2>&1 || {
#   echo >&2 "ERROR: docker is not installed. Please install and re-run."; exit 1;
# }
# command -v vercel >/dev/null 2>&1 || {
#   echo >&2 "ERROR: vercel CLI is not installed (npm i -g vercel). Please install and re-run."; exit 1;
# }

# Exit on first error
set -e

########################################
# 1. RUN PRE-COMMIT HOOKS
########################################

echo ">>> [Step 1/6] Running pre-commit hooks..."
pre-commit run --all-files || {
  echo "ERROR: Pre-commit failed. Please fix issues and re-run."
  exit 1
}
echo "SUCCESS: Pre-commit hooks passed."

########################################
# 2. VALIDATE BACKEND APIs (Flask & Node.js)
########################################

echo ">>> [Step 2/6] Validating backend APIs..."

# Start Flask in background
echo "Starting Flask (Python) on background..."
python backend/app.py &
FLASK_PID=$!

# Start Node.js in background
echo "Starting Node (JavaScript) on background..."
node backend/index.js &
NODE_PID=$!

# Give them a few seconds to start
sleep 5

# Check Flask
FLASK_RESPONSE=$(curl -s http://localhost:5000/status || true)
if [[ "$FLASK_RESPONSE" == *'"status":"API is working"'* ]]; then
  echo "SUCCESS: Flask API responded correctly."
else
  echo "ERROR: Flask API not responding correctly. Stopping the script."
  kill $FLASK_PID $NODE_PID || true
  exit 1
fi

# Check Node.js
NODE_RESPONSE=$(curl -s http://localhost:3000/api/status || true)
if [[ "$NODE_RESPONSE" == *'"status":"API is working"'* ]]; then
  echo "SUCCESS: Node.js API responded correctly."
else
  echo "ERROR: Node.js API not responding correctly. Stopping the script."
  kill $FLASK_PID $NODE_PID || true
  exit 1
fi

echo "Both APIs responded correctly."

# (Optional) Keep them running for the test phase, or kill them if you don't need them:
kill $FLASK_PID $NODE_PID >/dev/null 2>&1 || true

########################################
# 3. EXECUTE UNIT TESTS
########################################

echo ">>> [Step 3/6] Running unit tests..."

# Python tests
echo "Running Python tests with pytest..."
pytest tests/test_app.py || {
  echo "ERROR: Python tests failed. Fix and re-run."
  exit 1
}
echo "SUCCESS: Python tests passed."

# Node.js tests
echo "Running Node tests with npm..."
npm test || {
  echo "ERROR: Node tests failed. Fix and re-run."
  exit 1
}
echo "SUCCESS: Node tests passed."

########################################
# 4. BUILD & TEST DOCKER DEPLOYMENT
########################################

echo ">>> [Step 4/6] Building Docker image..."
docker build -t my-ai-dev-system . || {
  echo "ERROR: Docker build failed. Fix Dockerfile or code and re-run."
  exit 1
}
echo "SUCCESS: Docker image built."

echo "Running Docker container..."
docker run -d -p 5000:5000 --name my-ai-dev-container my-ai-dev-system || {
  echo "ERROR: Failed to run Docker container. Fix and re-run."
  exit 1
}

# Wait a bit for the container to spin up
sleep 5

# Check if container is responding
DOCKER_RESPONSE=$(curl -s http://localhost:5000/status || true)
if [[ "$DOCKER_RESPONSE" == *'"status":"API is working"'* ]]; then
  echo "SUCCESS: Docker container responded correctly."
else
  echo "ERROR: Docker container not responding as expected."
  echo "Stopping and removing container..."
  docker stop my-ai-dev-container || true
  docker rm my-ai-dev-container || true
  exit 1
fi

# Cleanup container so it doesn't keep running
docker stop my-ai-dev-container >/dev/null 2>&1
docker rm my-ai-dev-container >/dev/null 2>&1

########################################
# 5. DEPLOY TO VERCEL
########################################

echo ">>> [Step 5/6] Deploying to Vercel..."

# Vercel deploy (assuming you're already logged in or using a token)
vercel deploy --prod || {
  echo "ERROR: Vercel deployment failed. Check logs, fix, and re-run."
  exit 1
}
echo "SUCCESS: Deployed to Vercel (prod)."

########################################
# 6. PUSH FINAL UPDATES TO GITHUB
########################################

echo ">>> [Step 6/6] Pushing final updates to GitHub..."

git add .
git commit -m "🚀 Finalized AI Dev System: Tests, Linting, Docker, and Deployment" || {
  echo "ERROR: Git commit failed. Possibly no changes to commit or conflict."
  exit 1
}
git push origin main || {
  echo "ERROR: Git push failed. Check your remote or credentials and re-run."
  exit 1
}

echo "SUCCESS: Code pushed to GitHub. Deployment complete!"
