FROM python:3.14-slim

WORKDIR /app

# Fly and CI build this image from the repository root.
COPY services/llm-gateway/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY services/llm-gateway/app ./app

RUN useradd --create-home --uid 10001 appuser && chown -R appuser:appuser /app

USER appuser

EXPOSE 4000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "4000"]
