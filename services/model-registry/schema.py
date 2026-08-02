"""
Model Registry – Datenbankmigrationen

Zentrale Tabellen für Modellmetadaten, Versionen, Capabilities,
Zugangsklassen und Verfügbarkeitsstatus.
"""

# Migration: 001_create_model_registry.py
from datetime import datetime
from typing import Optional
from sqlalchemy import (
    Column, String, Integer, Float, Boolean, DateTime,
    Text, JSON, ForeignKey, Index, UniqueConstraint, Enum
)
from sqlalchemy.orm import declarative_base
from sqlalchemy.dialects.postgresql import UUID
import uuid

Base = declarative_base()


class Provider(Base):
    """Modellprovider (OpenAI, HuggingFace, LocalLLM, etc.)"""
    __tablename__ = "providers"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    provider_id = Column(String(100), unique=True, nullable=False, index=True)
    display_name = Column(String(200), nullable=False)
    base_url = Column(String(500))
    api_version = Column(String(50))
    is_active = Column(Boolean, default=True, index=True)
    last_health_check = Column(DateTime, nullable=True)
    health_status = Column(String(50), default="UNKNOWN")

    # Capabilities
    supports_streaming = Column(Boolean, default=False)
    supports_tools = Column(Boolean, default=False)
    supports_structured_output = Column(Boolean, default=False)
    supports_vision = Column(Boolean, default=False)

    # Discovery
    auto_discover = Column(Boolean, default=False)
    discover_endpoint = Column(String(500))
    last_discovery = Column(DateTime, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        Index("idx_provider_active", "is_active"),
        Index("idx_provider_health", "health_status"),
    )


class Model(Base):
    """Modell mit Basis-Metadaten"""
    __tablename__ = "models"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    model_id = Column(String(200), unique=True, nullable=False, index=True)
    canonical_name = Column(String(200), nullable=False)
    provider_id = Column(UUID(as_uuid=True), ForeignKey("providers.id"), nullable=False)
    provider_model_id = Column(String(200), nullable=False)  # z.B. "gpt-4-turbo" bei OpenAI
    model_family = Column(String(100))

    # Versions & Lifecycle
    release_date = Column(DateTime, nullable=True)
    deprecation_date = Column(DateTime, nullable=True)
    deprecated = Column(Boolean, default=False, index=True)
    replacement_model_id = Column(UUID(as_uuid=True), ForeignKey("models.id"), nullable=True)

    # Open Source
    open_weights = Column(Boolean, default=False, index=True)
    model_license = Column(String(200))
    commercial_use_allowed = Column(Boolean, default=True)

    # Capabilities
    context_window = Column(Integer)
    max_output_tokens = Column(Integer)
    supports_streaming = Column(Boolean, default=False)
    supports_tools = Column(Boolean, default=False)
    supports_structured_output = Column(Boolean, default=False)
    supports_vision = Column(Boolean, default=False)
    supports_reasoning = Column(Boolean, default=False)
    supports_fim = Column(Boolean, default=False)
    supports_embeddings = Column(Boolean, default=False)

    # Languages
    programming_languages = Column(JSON, default=list)

    # Scoring (0-100)
    coding_score = Column(Float, nullable=True)
    agentic_score = Column(Float, nullable=True)
    tool_use_score = Column(Float, nullable=True)
    repo_edit_score = Column(Float, nullable=True)
    test_generation_score = Column(Float, nullable=True)
    frontend_score = Column(Float, nullable=True)
    security_review_score = Column(Float, nullable=True)
    latency_score = Column(Float, nullable=True)
    reliability_score = Column(Float, nullable=True)
    free_sustainability_score = Column(Float, nullable=True)
    final_ranking_score = Column(Float, nullable=True, index=True)

    # Metadata
    strengths = Column(JSON, default=list)
    weaknesses = Column(JSON, default=list)
    recommended_tasks = Column(JSON, default=list)
    forbidden_tasks = Column(JSON, default=list)

    last_verified_at = Column(DateTime, nullable=True)
    availability = Column(String(50), default="UNKNOWN", index=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        Index("idx_model_deprecated", "deprecated"),
        Index("idx_model_provider", "provider_id"),
        Index("idx_model_ranking_score", "final_ranking_score"),
        Index("idx_model_availability", "availability"),
        UniqueConstraint("provider_id", "provider_model_id", name="uq_provider_model"),
    )


class ModelAccessStatus(Base):
    """Zugangsklasse und Verfügbarkeit für jedes Modell"""
    __tablename__ = "model_access_status"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    model_id = Column(UUID(as_uuid=True), ForeignKey("models.id"), nullable=False, unique=True)

    # Zugangsklasse (FREE_LOCAL, FREE_HOSTED, FREE_TIER, FREE_QUOTA, TRIAL_CREDIT, etc.)
    access_class = Column(String(50), nullable=False, index=True)
    zero_cost_eligible = Column(Boolean, default=False, index=True)
    free_route_verified = Column(Boolean, default=False)

    # Verifikation
    official_source_urls = Column(JSON, default=list)
    verification_method = Column(String(100))  # OFFICIAL_DOCS, API_PROBE, NETWORK_TEST
    evidence_hash = Column(String(256))  # SHA256 der Verifikationsquelle
    verified_at = Column(DateTime, nullable=True)

    # Kosten
    input_price_per_million = Column(Float, nullable=True)  # USD
    output_price_per_million = Column(Float, nullable=True)  # USD
    estimated_cost_cents = Column(Integer, default=0)

    # Quotas
    rpm_limit = Column(Integer, nullable=True)  # Requests per minute
    rpd_limit = Column(Integer, nullable=True)  # Requests per day
    tpm_limit = Column(Integer, nullable=True)  # Tokens per minute
    monthly_token_limit = Column(Integer, nullable=True)
    quota_reset_policy = Column(String(200))  # "daily", "monthly", "never"
    quota_remaining = Column(Integer, nullable=True)
    quota_reset_at = Column(DateTime, nullable=True)

    # Local Execution
    local_runtime_supported = Column(Boolean, default=False)
    local_runtime_options = Column(JSON, default=list)  # ["ollama", "vllm", "llama.cpp"]

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        Index("idx_access_class", "access_class"),
        Index("idx_zero_cost_eligible", "zero_cost_eligible"),
        Index("idx_free_route_verified", "free_route_verified"),
    )


class ModelVersion(Base):
    """Modellversionen mit Changelog"""
    __tablename__ = "model_versions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    model_id = Column(UUID(as_uuid=True), ForeignKey("models.id"), nullable=False)
    version_string = Column(String(100), nullable=False)
    released_at = Column(DateTime, nullable=True)

    # Changelog
    description = Column(Text)
    breaking_changes = Column(JSON, default=list)
    improvements = Column(JSON, default=list)

    # Scoring
    coding_score = Column(Float, nullable=True)
    agentic_score = Column(Float, nullable=True)

    # Lifecycle
    deprecated = Column(Boolean, default=False)
    is_latest = Column(Boolean, default=False, index=True)

    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        Index("idx_model_version_latest", "is_latest"),
        Index("idx_model_version_deprecated", "deprecated"),
    )


class ModelCapability(Base):
    """Spezifische Capabilities pro Modell und Programmiersprache"""
    __tablename__ = "model_capabilities"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    model_id = Column(UUID(as_uuid=True), ForeignKey("models.id"), nullable=False)

    # Kategorie
    capability_name = Column(String(200), nullable=False)  # "python-debug", "typescript-refactor"
    language = Column(String(50), nullable=True)
    category = Column(String(50))  # "coding", "testing", "debugging", "review"

    # Score
    score = Column(Float)  # 0-100
    confidence = Column(Float)  # 0-1

    # Evidence
    test_count = Column(Integer, default=0)
    passing_tests = Column(Integer, default=0)
    average_latency_ms = Column(Float, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        Index("idx_model_capability", "model_id", "capability_name"),
        Index("idx_capability_score", "score"),
    )


class Evidence(Base):
    """Audit-Trail: Proof für jede Verifikation und Routing-Entscheidung"""
    __tablename__ = "evidence"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # Kontext
    model_id = Column(UUID(as_uuid=True), ForeignKey("models.id"), nullable=True)
    run_id = Column(UUID(as_uuid=True), nullable=True, index=True)
    task_id = Column(UUID(as_uuid=True), nullable=True, index=True)
    agent_id = Column(String(100), nullable=True)

    # Typ
    evidence_type = Column(String(100), nullable=False, index=True)  # "model_discovery", "provider_probe", "benchmark_run", "security_test"

    # Inhalt
    description = Column(Text)
    result = Column(String(50))  # "PASS", "FAIL", "INCONCLUSIVE"
    details = Column(JSON)

    # Quellen
    source_url = Column(String(500))
    source_hash = Column(String(256))  # SHA256

    # Artefakte
    artifact_paths = Column(JSON, default=list)  # Pfade zu Logs, Screenshots, Diffs

    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        Index("idx_evidence_type", "evidence_type"),
        Index("idx_evidence_model", "model_id"),
        Index("idx_evidence_run", "run_id"),
    )


class LocalRuntime(Base):
    """Registrierte lokale Inferenz-Runtimes (Ollama, vLLM, etc.)"""
    __tablename__ = "local_runtimes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    runtime_type = Column(String(50), nullable=False)  # "ollama", "vllm", "llama.cpp"
    endpoint_url = Column(String(500), nullable=False, unique=True)
    status = Column(String(50), default="UNKNOWN")  # "HEALTHY", "DEGRADED", "OFFLINE"

    # Hardware
    available_models = Column(JSON, default=list)
    total_models = Column(Integer, default=0)

    last_health_check = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class LocalHardware(Base):
    """Hardware-Profile des Systems für lokale Modellauswahl"""
    __tablename__ = "local_hardware"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # CPU
    cpu_cores = Column(Integer)
    cpu_model = Column(String(200))

    # RAM
    total_ram_gb = Column(Float)
    available_ram_gb = Column(Float)

    # GPU
    has_gpu = Column(Boolean, default=False)
    gpu_vendor = Column(String(100))  # "nvidia", "amd", "intel", "apple"
    gpu_model = Column(String(200))
    gpu_vram_gb = Column(Float, nullable=True)

    # Compute
    cuda_available = Column(Boolean, default=False)
    rocm_available = Column(Boolean, default=False)
    directml_available = Column(Boolean, default=False)

    # Disk
    free_disk_gb = Column(Float)

    # Profile
    hardware_profile = Column(String(50))  # "CPU_ONLY", "LOW_VRAM", "8_GB", "24_GB", "48_PLUS", "MULTI_GPU"

    last_updated = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
