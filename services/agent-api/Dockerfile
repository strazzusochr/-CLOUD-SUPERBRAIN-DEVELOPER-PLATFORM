FROM python:3.12-alpine AS builder

WORKDIR /app
COPY requirements.txt .
# Install build dependencies for any python packages that need compilation
RUN apk add --no-cache build-base postgresql-dev python3-dev libffi-dev \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-alpine

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

COPY app ./app
RUN adduser -D -u 10001 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
