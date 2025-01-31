# AI Development System

## Installation Instructions
1. Clone the repository:
   ```bash
   git clone https://github.com/your-repo.git
   cd your-repo
   ```

2. Install dependencies:
   - For Python:
     ```bash
     pip install -r requirements.txt
     ```
   - For Node.js:
     ```bash
     npm install
     ```

3. Run the setup script:
   ```bash
   ./scripts/full-setup.sh
   ```

## Execution Commands
- Start the Flask backend:
  ```bash
  python backend/app.py
  ```

- Start the Node.js server:
  ```bash
  npm start
  ```

- Build Docker image:
  ```bash
  docker build -t your-image-name .
  ```

## Deployment Steps
- **Vercel Deployment:**
  1. Ensure `vercel.json` is configured.
  2. Deploy using:
     ```bash
     vercel deploy
     ```

- **Docker Deployment:**
  1. Build and run the Docker container:
     ```bash
     docker run -p 5000:5000 your-image-name
     ```

## Troubleshooting Guide
- **Common Errors:**
  - Ensure all environment variables are set.
  - Check for missing dependencies in `requirements.txt` or `package.json`.

## Troubleshooting
**ImportError**: If you encounter `ModuleNotFoundError: No module named 'backend'`, ensure an `__init__.py` file is placed in the `backend` folder. This designates `backend` as a Python package, resolving the import error.
