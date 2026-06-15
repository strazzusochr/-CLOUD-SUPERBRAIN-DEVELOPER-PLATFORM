FROM python:3.14-alpine AS builder

# NOTE: this image builds from the REPOSITORY ROOT context (see
# .github/workflows/main-deploy.yml -> agent-api), so it can bake the
# manifest/state files the app reads at runtime. All COPY sources are
# therefore repo-root relative.
WORKDIR /app
COPY services/agent-api/requirements.txt .
# Install build dependencies for any python packages that need compilation
RUN apk add --no-cache build-base postgresql-dev python3-dev libffi-dev \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.14-alpine

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app
# Install runtime dependencies (like libpq for psycopg)
RUN apk add --no-cache libpq ca-certificates
COPY --from=builder /install /usr/local
ARG GITLEAKS_VERSION=8.30.1

RUN apk add --no-cache curl \
    && ARCH=$(uname -m) \
    && GITLEAKS_ARCH=$(if [ "$ARCH" = "aarch64" ]; then echo "arm64"; else echo "x64"; fi) \
    && curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${GITLEAKS_ARCH}.tar.gz" -o /tmp/gitleaks.tar.gz \
    && tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks \
    && chmod +x /usr/local/bin/gitleaks \
    && rm -f /tmp/gitleaks.tar.gz \
    && apk del curl

COPY services/agent-api/app ./app

# Bake the read-only manifest/state files the app reads at runtime. On a single
# host these are bind-mounted (docker-compose.cloud.yml); on Fly there are no
# bind-mounts, so they must live in the image. Paths match the app defaults:
#   PROJECT_PROGRESS_MANIFEST_PATH=/app/progress/project-progress.manifest.json
#   EXTERNAL_GATE_SUMMARY_PATH=/app/progress/external-gate-summary.json
#   PROJECT_STATE_PATH=/app/PROJECT_STATE.md
#   AUTONOMOUS_AGENT_ROSTER_PATH=/app/docs/codex-integration/autonomous-agent-roster.json
COPY docs/project-progress.manifest.json /app/progress/project-progress.manifest.json
COPY docs/runtime-state/external-gate-summary.json /app/progress/external-gate-summary.json
COPY PROJECT_STATE.md /app/PROJECT_STATE.md
COPY docs/codex-integration/autonomous-agent-roster.json /app/docs/codex-integration/autonomous-agent-roster.json

RUN adduser -D -u 10001 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
