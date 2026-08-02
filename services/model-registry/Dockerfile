FROM python:3.12-slim

WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy app
COPY services/model-registry/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY services/model-registry/app ./app

# Run as non-root
RUN useradd -m -u 10001 app
USER app

CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8003"]
