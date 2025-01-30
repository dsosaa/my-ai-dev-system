#!/bin/bash
set -e  # Exit on error

# ─────────────────────────────────────────────────────────────────────────
# Color-coded feedback for user-friendly output
# ─────────────────────────────────────────────────────────────────────────
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
RESET="\033[0m"

function print_info() {
  echo -e "${GREEN}$1${RESET}"
}
function print_warn() {
  echo -e "${YELLOW}⚠️ $1${RESET}"
}
function print_error() {
  echo -e "${RED}❌ $1${RESET}"
}
function print_step() {
  echo -e "${BLUE}--- $1 ---${RESET}"
}

# ─────────────────────────────────────────────────────────────────────────
# 1. Initial Checks & Basic Prerequisites
# ─────────────────────────────────────────────────────────────────────────
print_step "Starting Full AI-Powered Setup with Enhanced Best Practices"

print_info "🔎 Checking local dependencies: Git, Node.js, Python3..."

# Check Git
if ! command -v git >/dev/null 2>&1; then
  print_error "Git not found. Please install Git before continuing."
  exit 1
fi
# Check Node
if ! command -v node >/dev/null 2>&1; then
  print_error "Node.js not found. Please install Node 16+ before continuing."
  exit 1
fi
# Check Python
if ! command -v python3 >/dev/null 2>&1; then
  print_error "Python 3.8+ not found. Please install Python 3.8+ before continuing."
  exit 1
fi

print_info "✅ Local dependencies OK."

# ─────────────────────────────────────────────────────────────────────────
# 2. Offer Staged Onboarding (Wizard for Cloud Choices)
# ─────────────────────────────────────────────────────────────────────────
print_step "Cloud Hosting Preference Wizard"

echo "Which environment do you plan to use for hosting?"
echo "1) GitHub Codespaces + Vercel (default, recommended for novices)"
echo "2) AWS (EC2 / ECS / Lambda) or a custom Docker solution"
echo "3) I’m just exploring locally with Docker"
read -p "Enter choice (1,2,3): " environment_choice

case "$environment_choice" in
  1|"")
    print_info "You chose GitHub Codespaces + Vercel."
    ;;
  2)
    print_info "You chose AWS / custom Docker hosting. We'll skip some Vercel steps..."
    ;;
  3)
    print_info "You chose local Docker dev. We'll skip remote steps."
    ;;
  *)
    print_warn "Invalid choice, defaulting to 1 (Codespaces + Vercel)."
    environment_choice="1"
    ;;
esac

# ─────────────────────────────────────────────────────────────────────────
# 3. Environment Variables & Lint/Style Enforcement
# ─────────────────────────────────────────────────────────────────────────
print_step "Ensuring environment variables & linting are in place"

if [ ! -f ".env" ]; then
  print_warn ".env not found; creating one with placeholders..."
  cat <<EOT > .env
# Fill these placeholders or rely on OAuth + GH secrets
OPENAI_API_KEY=
CURSORAI_API_KEY=
VERCEL_TOKEN=
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
PERFORMANCE_MODE=
EOT
fi

print_info "Installing linting/pre-commit (Black for Python, ESLint for JS)..."
pip install --upgrade pip black flake8 pre-commit
if [ -f package.json ]; then
  npm install --save-dev eslint prettier
fi

# Minimal .pre-commit-config.yaml example
if [ ! -f ".pre-commit-config.yaml" ]; then
  cat <<EOT > .pre-commit-config.yaml
repos:
  - repo: https://github.com/psf/black
    rev: 22.12.0
    hooks:
      - id: black
  - repo: https://github.com/pycqa/flake8
    rev: 6.0.0
    hooks:
      - id: flake8
EOT
  pre-commit install
fi

print_info "✅ Linting and style hooks set up (run 'pre-commit run --all-files' to test)."

# ─────────────────────────────────────────────────────────────────────────
# 4. Security Scans (Dependency & Vulnerability Checks)
# ─────────────────────────────────────────────────────────────────────────
print_step "Running basic dependency & vulnerability scans (optional)"

if command -v pip-audit >/dev/null 2>&1; then
  pip-audit || print_warn "pip-audit found vulnerabilities. Check logs."
else
  print_warn "pip-audit not installed. Consider 'pip install pip-audit' for Python vulnerability checks."
fi

if [ -f package.json ]; then
  if command -v npx >/dev/null 2>&1; then
    npx audit || print_warn "npm audit found vulnerabilities. Check logs."
  fi
fi

print_info "Dependency checks done. (Use Dependabot or Snyk for ongoing scanning.)"

# ─────────────────────────────────────────────────────────────────────────
# 5. Performance vs. Cost-Efficient Mode
# ─────────────────────────────────────────────────────────────────────────
print_step "Selecting AI Mode (Performance or Cost-Efficient)"

if grep -q "PERFORMANCE_MODE=" .env; then
  perf_val=$(grep "PERFORMANCE_MODE=" .env | cut -d '=' -f2)
  if [ -z "$perf_val" ]; then
    echo "PERFORMANCE_MODE=false" >> .env
  fi
else
  echo "PERFORMANCE_MODE=false" >> .env
fi

perf_mode=$(grep "PERFORMANCE_MODE" .env | cut -d '=' -f2)
if [ "$perf_mode" = "true" ]; then
  print_info "🚀 Performance Mode enabled! AI calls favor speed & advanced models."
else
  print_info "💲 Cost-Efficient Mode enabled! Minimizing AI calls/cost."
fi

# ─────────────────────────────────────────────────────────────────────────
# 6. Cloud Service Validation (GitHub, Vercel, AWS)
# ─────────────────────────────────────────────────────────────────────────
print_step "Verifying cloud services & authentication"

if [ "$environment_choice" = "1" ] || [ "$environment_choice" = "" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    print_warn "GitHub CLI (gh) not found. GitHub integration might be partial."
  else
    gh auth status || print_warn "GH CLI could not confirm auth. 'gh auth login' if needed."
  fi
  if ! command -v vercel >/dev/null 2>&1; then
    print_warn "vercel CLI not installed. 'npm i -g vercel' if using Vercel."
  else
    vercel whoami || print_warn "Vercel login not found. 'vercel login' to authenticate."
  fi
fi

print_info "✅ Basic cloud auth checks done."

# ─────────────────────────────────────────────────────────────────────────
# ✅ DONE
# ─────────────────────────────────────────────────────────────────────────
print_info "✅ **All steps completed**. Review any warnings above, then explore your AI-powered system!"
exit 0
