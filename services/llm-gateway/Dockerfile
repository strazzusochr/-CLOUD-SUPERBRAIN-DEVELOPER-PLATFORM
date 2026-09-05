FROM python:3.14.5-alpine3.22@sha256:6b91e66ab2a880ce9ca5a1b91c70f45963ff71ff68268df056336e1a657d5efd

WORKDIR /app
RUN apk upgrade --no-cache

# Fly and CI build this image from the repository root.
COPY services/llm-gateway/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY services/llm-gateway/app ./app

RUN adduser -D -u 10001 appuser && chown -R appuser:appuser /app

USER appuser

EXPOSE 4000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "4000"]
