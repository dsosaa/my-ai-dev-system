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
