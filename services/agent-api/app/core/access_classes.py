"""
Access Classes for Model Providers – Verbindlich typsicher und verifikabel

Zentrale Klassifizierung aller Modellzugangstypen.
Jeder Zugang muss eine verfizierbare, reproduzierbare Kostenklasse haben.
"""

from enum import Enum
from typing import Optional, Dict, Any
from datetime import datetime


class AccessClass(str, Enum):
    """Verbindliche Zugangsklasse für jeden Provider-Endpunkt."""

    FREE_LOCAL = "FREE_LOCAL"
    """Open-Weight Modell lokal über Ollama/vLLM/llama.cpp etc.
    Dokumentation erforderlich:
    - Softwarelizenz
    - Modelllizenz
    - Hardwareanforderungen
    """

    FREE_HOSTED = "FREE_HOSTED"
    """Provider bietet das konkrete Modell ohne Tokenkosten über offizielle API.
    Rate Limits erlaubt.
    Quelle: Offizielle API-Dokumentation
    """

    FREE_TIER = "FREE_TIER"
    """Anbieter bietet dauerhaft beschriebenen kostenlosen Tarif.
    Regelmäßige Quotenerneuerung.
    Quelle: Offizielle Bedingungen
    """

    FREE_QUOTA = "FREE_QUOTA"
    """Kostenlose Entwicklerquote mit festen Limits.
    Requests/Token/Tag-Limits möglich.
    Quelle: Offizielle Developer Docs
    """

    TRIAL_CREDIT = "TRIAL_CREDIT"
    """Zeitlich begrenzt ODER benötigt Zahlungsmethode.
    Darf NICHT automatisch verwendet werden.
    Quelle: ToS
    """

    PAID_BYOK = "PAID_BYOK"
    """Kostenpflichtige API nach explizitem API-Schlüssel.
    Erst nach User-Eingabe und Freigabe verwendbar.
    """

    SUBSCRIPTION_ONLY = "SUBSCRIPTION_ONLY"
    """Nutzung an nicht frei verfügbares Abo gebunden.
    Nicht für Free-First Plattform nutzbar.
    """

    UNAVAILABLE = "UNAVAILABLE"
    """Modell eingestellt, gesperrt, offline oder nicht erreichbar.
    Darf nicht geroutet werden.
    """

    UNVERIFIED = "UNVERIFIED"
    """Status konnte nicht anhand offizieller Quelle geprüft werden.
    Darf NICHT automatisch geroutet werden.
    Muss manuell überprüft oder als Gap markiert sein.
    """


class AccessVerification:
    """Beweis für einen Zugang – unveränderlich und nachvollziehbar."""

    def __init__(
        self,
        access_class: AccessClass,
        provider_id: str,
        model_id: str,
        official_source_url: str,
        verified_at: datetime,
        verification_method: str,
        evidence_hash: str,
        cost_cents_estimated: int = 0,
        quota_limit: Optional[Dict[str, Any]] = None,
        deprecation_date: Optional[datetime] = None,
    ):
        self.access_class = access_class
        self.provider_id = provider_id
        self.model_id = model_id
        self.official_source_url = official_source_url
        self.verified_at = verified_at
        self.verification_method = verification_method  # "OFFICIAL_DOCS", "API_PROBE", "NETWORK_TEST"
        self.evidence_hash = evidence_hash  # SHA256 der Quelle
        self.cost_cents_estimated = cost_cents_estimated
        self.quota_limit = quota_limit or {}
        self.deprecation_date = deprecation_date
        self.is_zero_cost = cost_cents_estimated == 0
        self.is_available = access_class not in (
            AccessClass.UNAVAILABLE,
            AccessClass.UNVERIFIED,
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "access_class": self.access_class.value,
            "provider_id": self.provider_id,
            "model_id": self.model_id,
            "official_source_url": self.official_source_url,
            "verified_at": self.verified_at.isoformat(),
            "verification_method": self.verification_method,
            "cost_cents_estimated": self.cost_cents_estimated,
            "quota_limit": self.quota_limit,
            "is_zero_cost": self.is_zero_cost,
            "is_available": self.is_available,
            "deprecation_date": (
                self.deprecation_date.isoformat()
                if self.deprecation_date
                else None
            ),
        }


class AccessPolicy:
    """Richtlinie für automatische Routingentscheidungen."""

    # Standardrichtlinie: ZERO_COST_MODE = True
    ZERO_COST_MODE = True
    MAX_AUTONOMOUS_COST_EUR = 0.00
    PAID_PROVIDER_CALLS = False
    AUTO_TOP_UP = False
    AUTO_BILLING = False

    # Nur diese Zugangsklassen dürfen automatisch geroutet werden
    AUTO_ROUTABLE_CLASSES = {
        AccessClass.FREE_LOCAL,
        AccessClass.FREE_HOSTED,
        AccessClass.FREE_TIER,
        AccessClass.FREE_QUOTA,
    }

    # Diese benötigen explizite User-Freigabe
    REQUIRES_APPROVAL_CLASSES = {
        AccessClass.TRIAL_CREDIT,
        AccessClass.PAID_BYOK,
    }

    # Diese dürfen nie automatisch geroutet werden
    FORBIDDEN_AUTO_ROUTING = {
        AccessClass.SUBSCRIPTION_ONLY,
        AccessClass.UNAVAILABLE,
        AccessClass.UNVERIFIED,
    }

    @classmethod
    def can_route_automatically(cls, access_class: AccessClass) -> bool:
        """Prüfe, ob Zugang automatisch geroutet werden darf."""
        if not cls.ZERO_COST_MODE:
            return access_class not in cls.FORBIDDEN_AUTO_ROUTING
        return access_class in cls.AUTO_ROUTABLE_CLASSES

    @classmethod
    def requires_approval(cls, access_class: AccessClass) -> bool:
        """Prüfe, ob User-Freigabe erforderlich ist."""
        return access_class in cls.REQUIRES_APPROVAL_CLASSES

    @classmethod
    def is_forbidden(cls, access_class: AccessClass) -> bool:
        """Prüfe, ob Zugang komplett verboten ist."""
        return access_class in cls.FORBIDDEN_AUTO_ROUTING
