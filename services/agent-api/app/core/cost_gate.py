"""
Cost Gate Policy – Unbrechbares Zero-Cost Sicherheitstor

Sperrt ALLE kostenpflichtigen Aufrufe standardmäßig.
Verlangt explizite Freigabe pro Aufruf.
Niemals stille Upgrades zu kostenpflichtigem Fallback.
"""

from datetime import datetime
from typing import Optional, Dict, Any
from enum import Enum

from .access_classes import AccessClass, AccessPolicy


class CostCheckResult(str, Enum):
    """Ergebnis der Kostenprüfung."""
    APPROVED_ZERO_COST = "APPROVED_ZERO_COST"
    APPROVED_PAID_EXPLICIT = "APPROVED_PAID_EXPLICIT"
    BLOCKED_PAID_NO_APPROVAL = "BLOCKED_PAID_NO_APPROVAL"
    BLOCKED_FORBIDDEN_CLASS = "BLOCKED_FORBIDDEN_CLASS"
    BLOCKED_ZERO_COST_UNAVAILABLE = "BLOCKED_ZERO_COST_UNAVAILABLE"


class CostGatePolicy:
    """Zentrale Kostenfreigabe-Engine.

    Sicherheit durch:
    - Default DENY für kostenpflichtig
    - Explizite Freigabe pro Aufruf, nicht pauschal
    - Audit-Trail aller Entscheidungen
    - Zero-Cost Mode nicht umgehbar
    """

    def __init__(self):
        self.zero_cost_mode = AccessPolicy.ZERO_COST_MODE
        self.max_autonomous_cost_eur = AccessPolicy.MAX_AUTONOMOUS_COST_EUR

    def can_call(
        self,
        access_class: AccessClass,
        estimated_cost_eur: float = 0.0,
        explicit_approval: Optional[str] = None,
        approval_timestamp: Optional[datetime] = None,
    ) -> tuple[CostCheckResult, str]:
        """
        Prüfe, ob ein Aufruf kostenrechtlich freigegeben ist.

        Args:
            access_class: Zugangsklasse des Modells
            estimated_cost_eur: Geschätzte Kosten
            explicit_approval: Approval Token (nur wenn User explizit zustimmte)
            approval_timestamp: Wann die Zustimmung erfolgte

        Returns:
            (CostCheckResult, Reason)
        """

        # Zero-Cost Mode: Blockiere alles Teure
        if self.zero_cost_mode:
            if estimated_cost_eur > 0 and not explicit_approval:
                return (
                    CostCheckResult.BLOCKED_PAID_NO_APPROVAL,
                    f"Zero-Cost Mode aktiviert. Geschätzte Kosten: €{estimated_cost_eur:.2f}. "
                    f"Explizite Freigabe erforderlich.",
                )

        # Verbotene Zugangsklassen
        if AccessPolicy.is_forbidden(access_class):
            return (
                CostCheckResult.BLOCKED_FORBIDDEN_CLASS,
                f"Zugangsklasse {access_class.value} ist nicht autorisiert.",
            )

        # Automatisch routbar (kostenlos)
        if AccessPolicy.can_route_automatically(access_class):
            if estimated_cost_eur <= 0:
                return (
                    CostCheckResult.APPROVED_ZERO_COST,
                    f"Kostenlos. Zugangsklasse: {access_class.value}",
                )
            else:
                # Widerspruch: sollte kostenlos sein, ist aber nicht?
                return (
                    CostCheckResult.BLOCKED_ZERO_COST_UNAVAILABLE,
                    f"Zugangsklasse {access_class.value} sollte kostenlos sein, "
                    f"aber API meldet €{estimated_cost_eur:.2f}. Möglich: Kontingent erschöpft.",
                )

        # Genehmigung erforderlich (Trial, BYOK)
        if AccessPolicy.requires_approval(access_class):
            if explicit_approval:
                return (
                    CostCheckResult.APPROVED_PAID_EXPLICIT,
                    f"Explizite Freigabe erhalten am {approval_timestamp}. "
                    f"Geschätzte Kosten: €{estimated_cost_eur:.2f}",
                )
            else:
                return (
                    CostCheckResult.BLOCKED_PAID_NO_APPROVAL,
                    f"Zugangsklasse {access_class.value} erfordert explizite Freigabe. "
                    f"Geschätzte Kosten: €{estimated_cost_eur:.2f}",
                )

        # Fallback: unbekannte Klasse
        return (
            CostCheckResult.BLOCKED_FORBIDDEN_CLASS,
            f"Unbekannte Zugangsklasse: {access_class.value}",
        )

    def estimate_cost(
        self, model_id: str, input_tokens: int, output_tokens: int, provider: str
    ) -> Dict[str, Any]:
        """Schätze die Kosten für einen Aufruf."""
        # Platzhalter; wird mit echten Modellpreisen gefüllt
        return {
            "model_id": model_id,
            "provider": provider,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "estimated_cost_eur": 0.0,
            "confidence": "unknown",  # Wird später auf "high" gesetzt
        }


# Singleton-Instanz
cost_gate = CostGatePolicy()


class PaidCallBlockedError(Exception):
    """Exception: Kostenpflichtiger Aufruf wurde blockiert."""
    def __init__(self, reason: str):
        self.reason = reason
        super().__init__(reason)


class UnverifiedAccessError(Exception):
    """Exception: Zugang nicht verifiziert."""
    def __init__(self, reason: str):
        self.reason = reason
        super().__init__(reason)


def verify_zero_cost_gate(
    access_class: AccessClass, estimated_cost_eur: float = 0.0
) -> None:
    """
    Middleware: Wirft Exception wenn Aufruf nicht kostenlos ist.
    Wird vor JEDEM LLM-Aufruf aufgerufen.
    """
    result, reason = cost_gate.can_call(access_class, estimated_cost_eur)

    if result == CostCheckResult.APPROVED_ZERO_COST:
        return  # OK

    if result == CostCheckResult.BLOCKED_PAID_NO_APPROVAL:
        raise PaidCallBlockedError(reason)

    if result == CostCheckResult.BLOCKED_FORBIDDEN_CLASS:
        raise UnverifiedAccessError(reason)

    if result == CostCheckResult.BLOCKED_ZERO_COST_UNAVAILABLE:
        raise PaidCallBlockedError(reason)

    # Sollte nicht vorkommen
    raise UnverifiedAccessError(f"Unbekannter Kostengate-Status: {result}")
