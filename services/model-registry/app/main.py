"""
Model Registry Service – FastAPI Backend

GET /api/v1/models – aktive Modelle
GET /api/v1/models/top – Top-50 Modelle
GET /api/v1/models/{id} – Modelldetails
POST /api/v1/models/refresh – Discovery & Refresh
POST /api/v1/models/{id}/probe – Verfügbarkeitsprobe
"""

from fastapi import FastAPI, HTTPException, Query, BackgroundTasks
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime
import uuid

app = FastAPI(
    title="Model Registry Service",
    description="Zentrale Modellverwaltung für 50+ kostenlose Coding-Modelle",
    version="0.1.0"
)


# ============================================================================
# Datenmodelle
# ============================================================================

class ProviderInfo(BaseModel):
    provider_id: str
    display_name: str
    base_url: Optional[str] = None
    health_status: str = "UNKNOWN"
    is_active: bool = True


class ModelMetadata(BaseModel):
    model_id: str
    canonical_name: str
    provider: str
    provider_model_id: str
    model_family: str
    release_date: Optional[str] = None

    # Capabilities
    context_window: Optional[int] = None
    max_output_tokens: Optional[int] = None
    supports_streaming: bool = False
    supports_tools: bool = False
    supports_structured_output: bool = False
    supports_vision: bool = False
    supports_fim: bool = False

    # Access
    access_class: str
    zero_cost_eligible: bool
    free_route_verified: bool
    official_source_urls: List[str] = []

    # Scores
    coding_score: Optional[float] = None
    agentic_score: Optional[float] = None
    final_ranking_score: Optional[float] = None

    # Quality
    availability: str = "UNKNOWN"
    last_verified_at: Optional[str] = None


class ModelDetail(BaseModel):
    metadata: ModelMetadata
    scores: Dict[str, Any] = {}
    capabilities: Dict[str, Any] = {}
    quotas: Dict[str, Any] = {}
    evidence: List[Dict[str, Any]] = []


class AvailabilityProbe(BaseModel):
    model_id: str
    status: str  # "AVAILABLE", "RATE_LIMITED", "OFFLINE"
    latency_ms: Optional[float] = None
    quota_remaining: Optional[int] = None
    error: Optional[str] = None
    probed_at: str


class Top50Response(BaseModel):
    total_verified_free_models: int
    target_model_count: int
    gap: int
    models: List[ModelMetadata] = []
    status: str  # "COMPLETE" oder "PARTIAL_BUT_HONEST"


# ============================================================================
# In-Memory Modellregistry (Phase 2 Placeholder)
# In Phase 4 wird dies durch PostgreSQL ersetzt
# ============================================================================

MOCK_MODELS: Dict[str, ModelMetadata] = {
    "local:gemma-3-1b-it": ModelMetadata(
        model_id="local:gemma-3-1b-it",
        canonical_name="Gemma 3.1 1B Instruct (Local)",
        provider="local-llm",
        provider_model_id="gemma-3-1b-it",
        model_family="gemma",
        access_class="FREE_LOCAL",
        zero_cost_eligible=True,
        free_route_verified=True,
        official_source_urls=["https://ollama.ai/library/gemma:3.1-1b-it"],
        context_window=8192,
        max_output_tokens=4096,
        supports_streaming=True,
        supports_tools=False,
        coding_score=42.0,
        final_ranking_score=42.0,
        availability="AVAILABLE",
    ),
    "hf:deepseek-coder": ModelMetadata(
        model_id="hf:deepseek-coder",
        canonical_name="DeepSeek-Coder (HF Free Tier)",
        provider="huggingface",
        provider_model_id="deepseek-ai/DeepSeek-Coder-1.3B-Instruct",
        model_family="deepseek",
        access_class="FREE_TIER",
        zero_cost_eligible=True,
        free_route_verified=True,
        official_source_urls=["https://huggingface.co/docs/inference-api"],
        context_window=4096,
        max_output_tokens=2048,
        supports_streaming=True,
        supports_tools=False,
        coding_score=58.0,
        final_ranking_score=58.0,
        availability="AVAILABLE",
    ),
    "hf:qwen": ModelMetadata(
        model_id="hf:qwen",
        canonical_name="Qwen 3-Coder (HF Free Tier)",
        provider="huggingface",
        provider_model_id="Qwen/Qwen3-Coder-1B",
        model_family="qwen",
        access_class="FREE_TIER",
        zero_cost_eligible=True,
        free_route_verified=True,
        official_source_urls=["https://huggingface.co/docs/inference-api"],
        context_window=8192,
        max_output_tokens=4096,
        supports_streaming=True,
        supports_tools=False,
        coding_score=65.0,
        final_ranking_score=65.0,
        availability="AVAILABLE",
    ),
    "hf:llama": ModelMetadata(
        model_id="hf:llama",
        canonical_name="Llama 3.1 8B Instruct (HF Free Tier)",
        provider="huggingface",
        provider_model_id="meta-llama/Llama-3.1-8B-Instruct",
        model_family="llama",
        access_class="FREE_TIER",
        zero_cost_eligible=True,
        free_route_verified=True,
        official_source_urls=["https://huggingface.co/docs/inference-api"],
        context_window=8192,
        max_output_tokens=4096,
        supports_streaming=True,
        supports_tools=False,
        coding_score=72.0,
        final_ranking_score=72.0,
        availability="AVAILABLE",
    ),
}


# ============================================================================
# API-Endpunkte
# ============================================================================

@app.get("/api/v1/health")
async def health_check():
    """Health Check"""
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}


@app.get("/api/v1/models", response_model=List[ModelMetadata])
async def list_models(
    access_class: Optional[str] = Query(None),
    only_zero_cost: bool = Query(False),
    only_verified: bool = Query(True),
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
):
    """
    Alle Modelle auflisten mit optionalen Filtern.

    - access_class: Filtern nach Zugangsklasse
    - only_zero_cost: Nur kostenlose Modelle
    - only_verified: Nur verifizierte Modelle
    """
    models = list(MOCK_MODELS.values())

    # Filter
    if access_class:
        models = [m for m in models if m.access_class == access_class]

    if only_zero_cost:
        models = [m for m in models if m.zero_cost_eligible]

    if only_verified:
        models = [m for m in models if m.free_route_verified]

    # Pagination
    total = len(models)
    models = models[offset : offset + limit]

    return models


@app.get("/api/v1/models/top", response_model=Top50Response)
async def top_models(limit: int = Query(50, ge=1, le=100)):
    """
    Top-50 kostenlose Modelle nach Ranking-Score.

    Gibt ehrlich an, wie viele verifizierte kostenlose Modelle tatsächlich existieren.
    Falls < 50: Status = "PARTIAL_BUT_HONEST" + Gap zur Warteliste.
    """
    models = [m for m in MOCK_MODELS.values() if m.zero_cost_eligible and m.free_route_verified]

    # Nach Final Score sortieren
    models = sorted(models, key=lambda m: m.final_ranking_score or 0, reverse=True)

    verified_count = len(models)
    target_count = limit
    gap = max(0, target_count - verified_count)
    status = "COMPLETE" if verified_count >= target_count else "PARTIAL_BUT_HONEST"

    return Top50Response(
        total_verified_free_models=verified_count,
        target_model_count=target_count,
        gap=gap,
        models=models[:limit],
        status=status,
    )


@app.get("/api/v1/models/{model_id}", response_model=ModelDetail)
async def get_model(model_id: str):
    """Modelldetails mit Scores, Capabilities, Quotas und Evidence."""
    if model_id not in MOCK_MODELS:
        raise HTTPException(status_code=404, detail=f"Model {model_id} not found")

    model = MOCK_MODELS[model_id]

    return ModelDetail(
        metadata=model,
        scores={
            "coding_score": model.coding_score,
            "agentic_score": model.agentic_score,
            "final_ranking_score": model.final_ranking_score,
        },
        capabilities={
            "streaming": model.supports_streaming,
            "tools": model.supports_tools,
            "structured_output": model.supports_structured_output,
            "vision": model.supports_vision,
        },
        quotas={},
        evidence=[],
    )


@app.post("/api/v1/models/{model_id}/probe", response_model=AvailabilityProbe)
async def probe_model(model_id: str, background_tasks: BackgroundTasks):
    """
    Verfügbarkeitsprobe: Ist das Modell erreichbar?
    Wird async im Hintergrund durchgeführt.
    """
    if model_id not in MOCK_MODELS:
        raise HTTPException(status_code=404, detail=f"Model {model_id} not found")

    # Phase 2 Placeholder: Immer AVAILABLE
    return AvailabilityProbe(
        model_id=model_id,
        status="AVAILABLE",
        latency_ms=150.0,
        quota_remaining=9999,
        probed_at=datetime.utcnow().isoformat(),
    )


@app.post("/api/v1/models/refresh")
async def refresh_models(background_tasks: BackgroundTasks):
    """
    Triggert einen Model Discovery Refresh im Hintergrund.

    Prüft:
    - Offizielle Modellkataloge
    - HuggingFace Inference API
    - Ollama Registry
    - vLLM Endpunkt
    - OpenRouter Models
    - Andere Provider
    """
    background_tasks.add_task(run_discovery)

    return {
        "status": "refresh_started",
        "message": "Model discovery running in background. Check /api/v1/models/discovery-status",
    }


@app.get("/api/v1/models/discovery-status")
async def discovery_status():
    """Status des laufenden Discovery-Prozesses."""
    return {
        "status": "in_progress",
        "phase": "probing_huggingface",
        "discovered_models": 4,
        "verified_models": 4,
        "timestamp": datetime.utcnow().isoformat(),
    }


# ============================================================================
# Background Tasks
# ============================================================================

async def run_discovery():
    """
    Background Task: Discovery & Refresh der Modellregistry.

    Wird in Phase 3 vollständig implementiert.
    Phase 2: Placeholder
    """
    print("[Discovery] Startet Model Discovery...")
    # TODO: Phase 3 – Provider-Adapter aufrufen
    print("[Discovery] Abgeschlossen")


# ============================================================================
# Startup / Shutdown
# ============================================================================

@app.on_event("startup")
async def startup_event():
    """Beim Start: Health Checks der Provider laufen."""
    print("[Model Registry] Service gestartet")
    print(f"[Model Registry] {len(MOCK_MODELS)} Mock-Modelle geladen")


@app.on_event("shutdown")
async def shutdown_event():
    """Beim Stop: Cleanup."""
    print("[Model Registry] Service beendet")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8003)
