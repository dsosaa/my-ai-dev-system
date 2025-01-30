FROM python:3.9
WORKDIR /app
COPY . .
RUN apt-get update && apt-get install -y \
    portaudio19-dev \
    libasound2-dev \
    libffi-dev \
    libssl-dev \
    libpq-dev \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir -r requirements.txt
EXPOSE 3001
CMD ["gunicorn", "-b", "0.0.0.0:3001", "backend.voice_assistant:app"]
