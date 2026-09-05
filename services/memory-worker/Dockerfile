FROM python:3.14-alpine@sha256:26730869004e2b9c4b9ad09cab8625e81d256d1ce97e72df5520e806b1709f92

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app
RUN apk upgrade --no-cache

# Fly and CI build this image from the repository root.
COPY services/memory-worker/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY services/memory-worker/app ./app
RUN adduser -D -u 10001 appuser && chown -R appuser:appuser /app
USER appuser

CMD ["python", "-m", "app.worker"]
