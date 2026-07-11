FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Fly and CI build this image from the repository root.
COPY services/memory-worker/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY services/memory-worker/app ./app
RUN useradd --create-home --uid 10001 appuser && chown -R appuser:appuser /app
USER appuser

CMD ["python", "-m", "app.worker"]
