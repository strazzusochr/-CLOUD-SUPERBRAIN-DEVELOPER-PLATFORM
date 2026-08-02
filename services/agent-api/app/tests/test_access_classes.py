"""
Unit Tests – Cost Gate & Access Classes

Testet das Kostentor und Zugangsklassifizierung.
Keine extern Abhängigkeiten, nur Unit-Logic.
"""

import pytest
from datetime import datetime
from services.agent_api.app.core.access_classes import (
    AccessClass,
    AccessVerification,
    AccessPolicy,
)
from services.agent_api.app.core.cost_gate import (
    CostGatePolicy,
    CostCheckResult,
    PaidCallBlockedError,
    UnverifiedAccessError,
    verify_zero_cost_gate,
)


class TestAccessClasses:
    """Test Access Class Enum und Policies."""

    def test_all_access_classes_defined(self):
        """Stelle sicher, dass alle erforderlichen Klassen definiert sind."""
        required_classes = {
            AccessClass.FREE_LOCAL,
            AccessClass.FREE_HOSTED,
            AccessClass.FREE_TIER,
            AccessClass.FREE_QUOTA,
            AccessClass.TRIAL_CREDIT,
            AccessClass.PAID_BYOK,
            AccessClass.SUBSCRIPTION_ONLY,
            AccessClass.UNAVAILABLE,
            AccessClass.UNVERIFIED,
        }
        assert required_classes.issubset(set(AccessClass))

    def test_access_policy_auto_routable_classes(self):
        """Teste, welche Klassen automatisch routbar sind."""
        auto_routable = AccessPolicy.AUTO_ROUTABLE_CLASSES
        assert AccessClass.FREE_LOCAL in auto_routable
        assert AccessClass.FREE_HOSTED in auto_routable
        assert AccessClass.FREE_TIER in auto_routable
        assert AccessClass.FREE_QUOTA in auto_routable

    def test_access_policy_forbidden_classes(self):
        """Teste, welche Klassen nicht routbar sind."""
        forbidden = AccessPolicy.FORBIDDEN_AUTO_ROUTING
        assert AccessClass.UNAVAILABLE in forbidden
        assert AccessClass.UNVERIFIED in forbidden
        assert AccessClass.SUBSCRIPTION_ONLY in forbidden

    def test_access_verification_zero_cost(self):
        """Teste Verification für kostenloses Modell."""
        verification = AccessVerification(
            access_class=AccessClass.FREE_LOCAL,
            provider_id="local-llm",
            model_id="gemma-3-1b-it",
            official_source_url="https://ollama.ai/library/gemma",
            verified_at=datetime.utcnow(),
            verification_method="API_PROBE",
            evidence_hash="abc123",
            cost_cents_estimated=0,
        )
        assert verification.is_zero_cost is True
        assert verification.is_available is True

    def test_access_verification_paid(self):
        """Teste Verification für kostenpflichtiges Modell."""
        verification = AccessVerification(
            access_class=AccessClass.PAID_BYOK,
            provider_id="openai",
            model_id="gpt-4",
            official_source_url="https://openai.com/pricing",
            verified_at=datetime.utcnow(),
            verification_method="OFFICIAL_DOCS",
            evidence_hash="xyz789",
            cost_cents_estimated=150,
        )
        assert verification.is_zero_cost is False
        assert verification.is_available is False  # Weil PAID_BYOK


class TestCostGatePolicy:
    """Teste Cost Gate Sicherheitsmechanismen."""

    def test_zero_cost_mode_enabled(self):
        """Stelle sicher, dass Zero-Cost Mode standardmäßig aktiv ist."""
        gate = CostGatePolicy()
        assert gate.zero_cost_mode is True
        assert gate.max_autonomous_cost_eur == 0.00

    def test_can_call_free_local(self):
        """Test: Kostenloses lokales Modell sollte erlaubt sein."""
        gate = CostGatePolicy()
        result, reason = gate.can_call(
            access_class=AccessClass.FREE_LOCAL,
            estimated_cost_eur=0.0,
        )
        assert result == CostCheckResult.APPROVED_ZERO_COST

    def test_can_call_free_tier(self):
        """Test: Free-Tier Modell sollte erlaubt sein."""
        gate = CostGatePolicy()
        result, reason = gate.can_call(
            access_class=AccessClass.FREE_TIER,
            estimated_cost_eur=0.0,
        )
        assert result == CostCheckResult.APPROVED_ZERO_COST

    def test_cannot_call_paid_without_approval(self):
        """Test: Kostenpflichtiger Aufruf ohne Freigabe wird blockiert."""
        gate = CostGatePolicy()
        result, reason = gate.can_call(
            access_class=AccessClass.PAID_BYOK,
            estimated_cost_eur=10.0,
            explicit_approval=None,
        )
        assert result == CostCheckResult.BLOCKED_PAID_NO_APPROVAL
        assert "Zero-Cost Mode" in reason or "explizite Freigabe" in reason

    def test_cannot_call_subscription_only(self):
        """Test: Subscription-Only wird immer blockiert."""
        gate = CostGatePolicy()
        result, reason = gate.can_call(
            access_class=AccessClass.SUBSCRIPTION_ONLY,
        )
        assert result == CostCheckResult.BLOCKED_FORBIDDEN_CLASS

    def test_cannot_call_unverified(self):
        """Test: Unverifizierte Modelle werden blockiert."""
        gate = CostGatePolicy()
        result, reason = gate.can_call(
            access_class=AccessClass.UNVERIFIED,
        )
        assert result == CostCheckResult.BLOCKED_FORBIDDEN_CLASS

    def test_cannot_call_unavailable(self):
        """Test: Nicht verfügbare Modelle werden blockiert."""
        gate = CostGatePolicy()
        result, reason = gate.can_call(
            access_class=AccessClass.UNAVAILABLE,
        )
        assert result == CostCheckResult.BLOCKED_FORBIDDEN_CLASS

    def test_trial_credit_requires_approval(self):
        """Test: Trial Credit erfordert explizite Freigabe."""
        gate = CostGatePolicy()

        # Ohne Freigabe
        result, reason = gate.can_call(
            access_class=AccessClass.TRIAL_CREDIT,
            estimated_cost_eur=5.0,
            explicit_approval=None,
        )
        assert result == CostCheckResult.BLOCKED_PAID_NO_APPROVAL

        # Mit Freigabe
        result, reason = gate.can_call(
            access_class=AccessClass.TRIAL_CREDIT,
            estimated_cost_eur=5.0,
            explicit_approval="approval_token_xyz",
            approval_timestamp=datetime.utcnow(),
        )
        assert result == CostCheckResult.APPROVED_PAID_EXPLICIT

    def test_verify_zero_cost_gate_passes(self):
        """Test: Middleware erlaubt kostenloses Modell."""
        # Sollte nicht werfen
        verify_zero_cost_gate(AccessClass.FREE_LOCAL, 0.0)

    def test_verify_zero_cost_gate_blocks_paid(self):
        """Test: Middleware blockiert kostenpflichtiges Modell."""
        with pytest.raises(PaidCallBlockedError):
            verify_zero_cost_gate(AccessClass.PAID_BYOK, 10.0)

    def test_verify_zero_cost_gate_blocks_forbidden(self):
        """Test: Middleware blockiert verbotene Klassen."""
        with pytest.raises(UnverifiedAccessError):
            verify_zero_cost_gate(AccessClass.UNAVAILABLE)


class TestAccessPolicy:
    """Test statische AccessPolicy-Methoden."""

    def test_can_route_automatically_free_local(self):
        """Test: FREE_LOCAL kann automatisch geroutet werden."""
        assert AccessPolicy.can_route_automatically(AccessClass.FREE_LOCAL)

    def test_can_route_automatically_free_tier(self):
        """Test: FREE_TIER kann automatisch geroutet werden."""
        assert AccessPolicy.can_route_automatically(AccessClass.FREE_TIER)

    def test_cannot_route_automatically_paid_byok(self):
        """Test: PAID_BYOK kann nicht automatisch geroutet werden."""
        assert not AccessPolicy.can_route_automatically(AccessClass.PAID_BYOK)

    def test_requires_approval_paid_byok(self):
        """Test: PAID_BYOK erfordert Freigabe."""
        assert AccessPolicy.requires_approval(AccessClass.PAID_BYOK)

    def test_requires_approval_trial(self):
        """Test: TRIAL_CREDIT erfordert Freigabe."""
        assert AccessPolicy.requires_approval(AccessClass.TRIAL_CREDIT)

    def test_is_forbidden_unavailable(self):
        """Test: UNAVAILABLE ist verboten."""
        assert AccessPolicy.is_forbidden(AccessClass.UNAVAILABLE)

    def test_is_forbidden_unverified(self):
        """Test: UNVERIFIED ist verboten."""
        assert AccessPolicy.is_forbidden(AccessClass.UNVERIFIED)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
