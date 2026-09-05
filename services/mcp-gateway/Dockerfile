FROM python:3.14.5-alpine3.22@sha256:6b91e66ab2a880ce9ca5a1b91c70f45963ff71ff68268df056336e1a657d5efd

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app
RUN apk upgrade --no-cache
# Fly and CI build this image from the repository root.
COPY services/mcp-gateway/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY services/mcp-gateway/app ./app
COPY docs/project-progress.manifest.json /app/readonly/project-progress.manifest.json
RUN adduser -D -u 10001 appuser \
    && chown -R appuser:appuser /app /tmp \
    && chown -R root:root /app/readonly \
    && chmod 0555 /app/readonly \
    && chmod 0444 /app/readonly/project-progress.manifest.json
USER appuser

EXPOSE 9000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "9000"]
