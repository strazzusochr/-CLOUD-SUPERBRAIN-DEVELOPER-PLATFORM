from __future__ import annotations

import os
from datetime import datetime
from typing import Any

import psycopg
from psycopg.types.json import Json
from pydantic import BaseModel, Field

from app.db import database_url
from app.security import redact_json, redact_text


DEFAULT_EMBEDDING_MODEL_VERSION = "text-embedding-3-small"
DEFAULT_EMBEDDING_DIMENSIONS = 1536
EMBEDDING_SEARCH_MODE = "lexical_fallback"


def current_embedding_model_version() -> str:
    return os.getenv("MEMORY_EMBEDDING_MODEL_VERSION", DEFAULT_EMBEDDING_MODEL_VERSION).strip() or DEFAULT_EMBEDDING_MODEL_VERSION


def current_embedding_dimensions() -> int:
    raw_value = os.getenv("MEMORY_EMBEDDING_DIMENSIONS", str(DEFAULT_EMBEDDING_DIMENSIONS)).strip()
    try:
        value = int(raw_value)
    except ValueError:
        return DEFAULT_EMBEDDING_DIMENSIONS
    return value if value > 0 else DEFAULT_EMBEDDING_DIMENSIONS


class MemoryWriteRequest(BaseModel):
    project_id: str = Field(..., min_length=1)
    session_id: str | None = None
    content_text: str = Field(..., min_length=1, max_length=20_000)
    metadata: dict[str, Any] = Field(default_factory=dict)


class MemorySearchResult(BaseModel):
    id: str
    content: str
    relevance_score: float
    created_at: str
    session_id: str | None


def find_project_uuid(conn: psycopg.Connection, project_id: str) -> str | None:
    row = conn.execute(
        "SELECT id FROM projects WHERE metadata->>'external_id' = %s LIMIT 1",
        (project_id,),
    ).fetchone()
    return str(row[0]) if row else None


def find_or_create_project_uuid(conn: psycopg.Connection, project_id: str) -> str:
    existing = find_project_uuid(conn, project_id)
    if existing:
        return existing
    row = conn.execute(
        """
        INSERT INTO projects(name, owner_id, metadata)
        VALUES (%s, 'langgraph-memory-updater', %s::jsonb)
        RETURNING id
        """,
        (project_id, Json({"external_id": project_id, "source": "langgraph_memory_updater"})),
    ).fetchone()
    if not row:
        raise RuntimeError("project insert did not return id")
    return str(row[0])


def insert_memory_entry(
    conn: psycopg.Connection,
    project_uuid: str,
    session_id: str | None,
    content_text: str,
    metadata: dict[str, Any] | None = None,
) -> str:
    row = conn.execute(
        """
        INSERT INTO memory_entries(
          project_id, session_id, content_text, relevance_score,
          consolidation_status, embedding_model_version, metadata
        )
        VALUES (%s, %s, %s, %s, 'consolidated', %s, %s::jsonb)
        RETURNING id
        """,
        (
            project_uuid,
            session_id,
            redact_text(content_text),
            1.0,
            current_embedding_model_version(),
            Json(redact_json(metadata or {})),
        ),
    ).fetchone()
    if not row:
        raise RuntimeError("memory insert did not return an id")
    return str(row[0])


def store_memory(request: MemoryWriteRequest) -> str:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        project_uuid = find_project_uuid(conn, request.project_id)
        if not project_uuid:
            raise LookupError("project not found")
        return insert_memory_entry(
            conn,
            project_uuid,
            request.session_id,
            redact_text(request.content_text),
            {
                **request.metadata,
                "search_mode": EMBEDDING_SEARCH_MODE,
                "embedding_model_version": current_embedding_model_version(),
                "embedding_dimensions": current_embedding_dimensions(),
            },
        )


def search_memory(project_id: str, query: str, limit: int = 5) -> list[MemorySearchResult]:
    like_query = f"%{query}%"
    with psycopg.connect(database_url(), autocommit=True) as conn:
        project_uuid = find_project_uuid(conn, project_id)
        if not project_uuid:
            return []
        rows = conn.execute(
            """
            SELECT id, content_text, COALESCE(relevance_score, 0.5), created_at, session_id
            FROM memory_entries
            WHERE project_id = %s
              AND status = 'active'
              AND content_text ILIKE %s
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (project_uuid, like_query, limit),
        ).fetchall()
    return [
        MemorySearchResult(
            id=str(row[0]),
            content=row[1],
            relevance_score=float(row[2]),
            created_at=row[3].isoformat() if isinstance(row[3], datetime) else str(row[3]),
            session_id=str(row[4]) if row[4] else None,
        )
        for row in rows
    ]
