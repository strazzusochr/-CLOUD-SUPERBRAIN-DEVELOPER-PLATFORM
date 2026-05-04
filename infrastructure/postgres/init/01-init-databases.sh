#!/bin/sh
set -eu

primary_db="${POSTGRES_DB:-superbrain_prod}"
langfuse_db="${LANGFUSE_DB_NAME:-langfuse}"
langfuse_user="${LANGFUSE_DB_USER:-langfuse}"
langfuse_password="${LANGFUSE_DB_PASSWORD:-}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$primary_db" <<'SQL'
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SQL

role_exists="$(psql -tA --username "$POSTGRES_USER" --dbname "$primary_db" -c "SELECT 1 FROM pg_roles WHERE rolname = '${langfuse_user}'")"
if [ "$role_exists" != "1" ]; then
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$primary_db" -c "CREATE ROLE \"$langfuse_user\" LOGIN PASSWORD '$langfuse_password';"
elif [ -n "$langfuse_password" ]; then
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$primary_db" -c "ALTER ROLE \"$langfuse_user\" WITH PASSWORD '$langfuse_password';"
fi

db_exists="$(psql -tA --username "$POSTGRES_USER" --dbname "$primary_db" -c "SELECT 1 FROM pg_database WHERE datname = '${langfuse_db}'")"
if [ "$db_exists" != "1" ]; then
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$primary_db" -c "CREATE DATABASE \"$langfuse_db\" OWNER \"$langfuse_user\";"
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$langfuse_db" <<'SQL'
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SQL
