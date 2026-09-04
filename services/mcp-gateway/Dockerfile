FROM python:3.14-alpine@sha256:26730869004e2b9c4b9ad09cab8625e81d256d1ce97e72df5520e806b1709f92

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
