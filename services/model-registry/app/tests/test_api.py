"""
Integration Tests – Model Registry API

Testet die API-Endpunkte der Model Registry.
"""

import pytest
from fastapi.testclient import TestClient
from services.model_registry.app.main import app


client = TestClient(app)


class TestModelRegistryAPI:
    """Test Model Registry FastAPI Endpunkte."""

    def test_health_check(self):
        """Test Health Check Endpunkt."""
        response = client.get("/api/v1/health")
        assert response.status_code == 200
        assert "status" in response.json()
        assert response.json()["status"] == "healthy"

    def test_list_models(self):
        """Test GET /api/v1/models."""
        response = client.get("/api/v1/models")
        assert response.status_code == 200
        models = response.json()
        assert isinstance(models, list)
        assert len(models) >= 4  # Mindestens die 4 Mock-Modelle

    def test_list_models_filter_zero_cost(self):
        """Test GET /api/v1/models mit only_zero_cost Filter."""
        response = client.get("/api/v1/models?only_zero_cost=true")
        assert response.status_code == 200
        models = response.json()
        # Alle sollten zero_cost_eligible sein
        for model in models:
            assert model["zero_cost_eligible"] is True

    def test_list_models_filter_access_class(self):
        """Test GET /api/v1/models mit access_class Filter."""
        response = client.get("/api/v1/models?access_class=FREE_LOCAL")
        assert response.status_code == 200
        models = response.json()
        for model in models:
            assert model["access_class"] == "FREE_LOCAL"

    def test_list_models_pagination(self):
        """Test GET /api/v1/models mit Pagination."""
        response = client.get("/api/v1/models?limit=2&offset=0")
        assert response.status_code == 200
        models = response.json()
        assert len(models) <= 2

    def test_top_models(self):
        """Test GET /api/v1/models/top – Top-50 Liste."""
        response = client.get("/api/v1/models/top")
        assert response.status_code == 200
        data = response.json()

        # Struktur validieren
        assert "total_verified_free_models" in data
        assert "target_model_count" in data
        assert "gap" in data
        assert "models" in data
        assert "status" in data

        # Phase 2: Noch nicht 50 Modelle
        # Status sollte PARTIAL_BUT_HONEST sein
        assert data["status"] in ["COMPLETE", "PARTIAL_BUT_HONEST"]

        # Gap sollte ehrlich berichtet werden
        assert data["gap"] >= 0
        assert data["total_verified_free_models"] + data["gap"] == data["target_model_count"]

    def test_top_models_honest_about_gap(self):
        """Test: Top-50 gibt ehrlich zu, wenn < 50 Modelle verfügbar sind."""
        response = client.get("/api/v1/models/top?limit=50")
        data = response.json()

        # Phase 2: Wir haben ~4 Modelle, Goal ist 50
        assert data["total_verified_free_models"] <= 50
        if data["total_verified_free_models"] < 50:
            assert data["status"] == "PARTIAL_BUT_HONEST"
            assert data["gap"] > 0

    def test_get_model_detail(self):
        """Test GET /api/v1/models/{model_id}."""
        # Verwende eines der bekannten Mock-Modelle
        response = client.get("/api/v1/models/local:gemma-3-1b-it")
        assert response.status_code == 200
        data = response.json()

        assert "metadata" in data
        assert "scores" in data
        assert "capabilities" in data
        assert "quotas" in data
        assert "evidence" in data

        # Verifiziere Modelldetails
        assert data["metadata"]["model_id"] == "local:gemma-3-1b-it"
        assert data["metadata"]["access_class"] == "FREE_LOCAL"
        assert data["metadata"]["zero_cost_eligible"] is True

    def test_get_model_not_found(self):
        """Test GET /api/v1/models/{model_id} mit nicht existentem Modell."""
        response = client.get("/api/v1/models/nonexistent-model-xyz")
        assert response.status_code == 404

    def test_probe_model(self):
        """Test POST /api/v1/models/{model_id}/probe."""
        response = client.post("/api/v1/models/local:gemma-3-1b-it/probe")
        assert response.status_code == 200
        data = response.json()

        assert "model_id" in data
        assert "status" in data
        assert "probed_at" in data

        # Phase 2 Placeholder: Immer AVAILABLE
        assert data["status"] == "AVAILABLE"

    def test_probe_model_not_found(self):
        """Test POST /api/v1/models/{model_id}/probe mit nicht existentem Modell."""
        response = client.post("/api/v1/models/nonexistent-model/probe")
        assert response.status_code == 404

    def test_refresh_models(self):
        """Test POST /api/v1/models/refresh."""
        response = client.post("/api/v1/models/refresh")
        assert response.status_code == 200
        data = response.json()

        assert "status" in data
        assert data["status"] == "refresh_started"
        assert "message" in data

    def test_discovery_status(self):
        """Test GET /api/v1/models/discovery-status."""
        response = client.get("/api/v1/models/discovery-status")
        assert response.status_code == 200
        data = response.json()

        assert "status" in data
        assert "phase" in data
        assert "discovered_models" in data
        assert "verified_models" in data
        assert "timestamp" in data


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
