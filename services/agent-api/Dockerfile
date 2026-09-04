FROM python:3.14-alpine@sha256:26730869004e2b9c4b9ad09cab8625e81d256d1ce97e72df5520e806b1709f92 AS builder

# NOTE: this image builds from the REPOSITORY ROOT context (see
# .github/workflows/main-deploy.yml -> agent-api), so it can bake the
# manifest/state files the app reads at runtime. All COPY sources are
# therefore repo-root relative.
WORKDIR /app
COPY services/agent-api/requirements.txt .
# Install build dependencies for any python packages that need compilation
RUN apk add --no-cache build-base postgresql-dev python3-dev libffi-dev \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.14-alpine@sha256:26730869004e2b9c4b9ad09cab8625e81d256d1ce97e72df5520e806b1709f92

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app
# Install current runtime dependencies (like libpq for psycopg) on top of the
# immutable base. Security scanners belong in CI, not in the serving image.
RUN apk upgrade --no-cache \
    && apk add --no-cache libpq ca-certificates
COPY --from=builder /install /usr/local

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
COPY docs/runtime-state/capability-gates.json /app/progress/capability-gates.json
COPY PROJECT_STATE.md /app/PROJECT_STATE.md
COPY docs/codex-integration/autonomous-agent-roster.json /app/docs/codex-integration/autonomous-agent-roster.json

RUN adduser -D -u 10001 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]
