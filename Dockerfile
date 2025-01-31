# Use a lightweight Python base image
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Copy project files
COPY . /app

# Install system dependencies required for PyAudio and gevent
RUN apt-get update && apt-get install -y \
    portaudio19-dev \
    libasound2-dev \
    libffi-dev \
    libssl-dev \
    libpq-dev \
    gcc \
    python3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose port for Flask
EXPOSE 3001

# Run the application using Gunicorn (better for production)
CMD ["gunicorn", "-b", "0.0.0.0:3001", "backend.app:app"]

# Load environment variables from .env in Docker
ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
ENV AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
ENV AWS_REGION=${AWS_REGION}
ENV OPENAI_API_KEY=${OPENAI_API_KEY}
ENV SENTRY_ENABLED=${SENTRY_ENABLED}
ENV SENTRY_DSN=${SENTRY_DSN}
