FROM python:3.14-slim@sha256:cea0e6040540fb2b965b6e7fb5ffa00871e632eef63719f0ea54bca189ce14a6

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app
# Fly and CI build this image from the repository root.
COPY services/mcp-gateway/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY services/mcp-gateway/app ./app
COPY docs/project-progress.manifest.json /app/readonly/project-progress.manifest.json
RUN useradd --create-home --uid 10001 appuser \
    && chown -R appuser:appuser /app /tmp \
    && chown -R root:root /app/readonly \
    && chmod 0555 /app/readonly \
    && chmod 0444 /app/readonly/project-progress.manifest.json
USER appuser

EXPOSE 9000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "9000"]
