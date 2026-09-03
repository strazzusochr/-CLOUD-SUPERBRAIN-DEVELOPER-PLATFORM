FROM python:3.14-alpine@sha256:26730869004e2b9c4b9ad09cab8625e81d256d1ce97e72df5520e806b1709f92

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
