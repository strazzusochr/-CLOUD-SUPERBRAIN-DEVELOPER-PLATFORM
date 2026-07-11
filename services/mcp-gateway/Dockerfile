FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app
# Fly and CI build this image from the repository root.
COPY services/mcp-gateway/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY services/mcp-gateway/app ./app
RUN useradd --create-home --uid 10001 appuser && chown -R appuser:appuser /app /tmp
USER appuser

EXPOSE 9000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "9000"]
