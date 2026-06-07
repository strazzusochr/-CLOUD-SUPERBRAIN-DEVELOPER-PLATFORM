from __future__ import annotations

import os
import time
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Any
from urllib.parse import urlparse

import httpx

from app.security import redact_text

CLOUD_PROVIDER_CONTRACT_VERSION = "cloud-provider-inventory-v1"
CLOUD_PROVIDER_EVIDENCE_REF = "cloud_provider_inventory_visible"
CLOUD_LAYER_CONTRACT_VERSION = "cloud-layer-readiness-v1"
CLOUD_LAYER_EVIDENCE_REF = "cloud_layer_readiness_visible"
FLY_API_URL = "https://api.fly.io"
FLY_GRAPHQL_URL = "https://api.fly.io/graphql"
FLY_TIMEOUT_SECONDS = 5.0
FLY_CACHE_TTL_SECONDS = 60
GRAFANA_CLOUD_TIMEOUT_SECONDS = 5.0
GRAFANA_CLOUD_CACHE_TTL_SECONDS = 60
CLOUDFLARE_API_URL = "https://api.cloudflare.com/client/v4"
CLOUDFLARE_TIMEOUT_SECONDS = 5.0
CLOUDFLARE_CACHE_TTL_SECONDS = 60
VERCEL_API_URL = "https://api.vercel.com"
GITHUB_API_URL = "https://api.github.com"
HUGGINGFACE_API_URL = "https://huggingface.co"
GITLAB_DEFAULT_API_URL = "https://gitlab.com/api/v4"
PROVIDER_TIMEOUT_SECONDS = 5.0
PROVIDER_CACHE_TTL_SECONDS = 60
GITHUB_API_VERSION = "2022-11-28"

_fly_cache: dict[str, Any] | None = None
_fly_cache_time = 0.0
_grafana_cache: dict[str, Any] | None = None
_grafana_cache_time = 0.0
_cloudflare_cache: dict[str, Any] | None = None
_cloudflare_cache_time = 0.0
_vercel_cache: dict[str, Any] | None = None
_vercel_cache_time = 0.0
_github_cache: dict[str, Any] | None = None
_github_cache_time = 0.0
_ghcr_cache: dict[str, Any] | None = None
_ghcr_cache_time = 0.0
_huggingface_cache: dict[str, Any] | None = None
_huggingface_cache_time = 0.0
_gitlab_cache: dict[str, Any] | None = None
_gitlab_cache_time = 0.0


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def money(value: str | int | float | Decimal | None) -> Decimal:
    if value is None:
        return Decimal("0")
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError):
        return Decimal("0")


def eur_to_cents(value: Decimal) -> int:
    return int((value * Decimal("100")).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def env_any(keys: list[str]) -> bool:
    return any(bool(os.getenv(key)) for key in keys)


def masked_env_status(keys: list[str]) -> list[dict[str, object]]:
    return [{"key": key, "configured": bool(os.getenv(key))} for key in keys]


def mask_ip(value: object) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    if ":" in text:
        address, slash, cidr = text.partition("/")
        parts = [part for part in address.split(":") if part]
        prefix = ":".join(parts[:2]) if parts else "ipv6"
        return f"{prefix}:***::{('/' + cidr) if slash else ''}"
    parts = text.split(".")
    if len(parts) == 4:
        return f"{parts[0]}.{parts[1]}.{parts[2]}.***"
    return "***masked***"


def sanitize_error(exc: Exception) -> str:
    return redact_text(str(exc))[:300]


def configured_url_resource(kind: str, env_key: str, source: str) -> dict[str, object] | None:
    value = os.getenv(env_key) or ""
    if not value:
        return None
    parsed = urlparse(value)
    return {
        "kind": kind,
        "env_key": env_key,
        "host": parsed.netloc or parsed.path,
        "path_configured": bool(parsed.path and parsed.path != "/"),
        "source": source,
    }


def gitlab_api_url() -> str:
    return (os.getenv("GITLAB_API_URL") or GITLAB_DEFAULT_API_URL).rstrip("/")


def _fly_graphql(client: httpx.Client, token: str, query: str) -> dict[str, Any]:
    response = client.post(
        FLY_GRAPHQL_URL,
        headers={"Authorization": f"Bearer {token}"},
        json={"query": query},
    )
    response.raise_for_status()
    return response.json()


def _grafana_cloud_get(client: httpx.Client, token: str, url: str, path: str) -> dict[str, Any]:
    response = client.get(
        f"{url}{path}",
        headers={"Authorization": f"Bearer {token}"},
    )
    response.raise_for_status()
    return response.json()


def _cloudflare_get(client: httpx.Client, token: str, path: str) -> dict[str, Any]:
    response = client.get(
        f"{CLOUDFLARE_API_URL}{path}",
        headers={"Authorization": f"Bearer {token}"},
    )
    response.raise_for_status()
    payload = response.json()
    if payload.get("success") is False:
        errors = payload.get("errors") or []
        raise RuntimeError(f"cloudflare api returned success=false: {errors}")
    return payload


def _vercel_get(
    client: httpx.Client,
    token: str,
    path: str,
    params: dict[str, str] | None = None,
) -> dict[str, Any]:
    response = client.get(
        f"{VERCEL_API_URL}{path}",
        headers={"Authorization": f"Bearer {token}"},
        params=params,
    )
    response.raise_for_status()
    return response.json()


def _github_get(
    client: httpx.Client,
    token: str,
    path: str,
    params: dict[str, str] | None = None,
) -> dict[str, Any] | list[Any]:
    response = client.get(
        f"{GITHUB_API_URL}{path}",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": GITHUB_API_VERSION,
        },
        params=params,
    )
    response.raise_for_status()
    return response.json()


def _huggingface_get(client: httpx.Client, token: str, path: str) -> dict[str, Any]:
    response = client.get(
        f"{HUGGINGFACE_API_URL}{path}",
        headers={"Authorization": f"Bearer {token}"},
    )
    response.raise_for_status()
    return response.json()


def _gitlab_get(client: httpx.Client, token: str, path: str) -> dict[str, Any]:
    response = client.get(
        f"{gitlab_api_url()}{path}",
        headers={"PRIVATE-TOKEN": token},
    )
    response.raise_for_status()
    return response.json()


def _fly_app_resource(app: dict[str, Any]) -> dict[str, object]:
    return {
        "kind": "app",
        "id": app.get("id"),
        "name": app.get("name"),
        "status": app.get("status"),
        "hostname": app.get("hostname"),
        "organization": (app.get("organization") or {}).get("slug"),
        "source": "fly_api_readonly",
    }


def _fetch_fly_snapshot() -> dict[str, Any]:
    token = os.getenv("FLY_API_TOKEN")
    if not token:
        return {
            "status": "missing_token",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": None,
        }

    global _fly_cache, _fly_cache_time
    now = time.monotonic()
    if _fly_cache and now - _fly_cache_time < FLY_CACHE_TTL_SECONDS:
        return dict(_fly_cache)

    try:
        query = """
        {
            viewer {
                email
                organizations {
                    nodes {
                        slug
                    }
                }
            }
            apps {
                nodes {
                    id
                    name
                    status
                    hostname
                    organization {
                        slug
                    }
                }
            }
        }
        """
        with httpx.Client(timeout=FLY_TIMEOUT_SECONDS) as client:
            payload = _fly_graphql(client, token, query)
        data = payload.get("data") or {}
        apps_nodes = (data.get("apps") or {}).get("nodes") or []
        viewer = data.get("viewer") or {}
        resources: list[dict[str, object]] = []
        if viewer.get("email"):
            orgs = (viewer.get("organizations") or {}).get("nodes") or []
            resources.append({
                "kind": "authenticated_viewer",
                "email_configured": True,
                "org_count": len(orgs),
                "source": "fly_api_readonly",
            })
        for app in apps_nodes:
            if isinstance(app, dict):
                resources.append(_fly_app_resource(app))
        snapshot = {
            "status": "verified",
            "live_verified": True,
            "resources": resources,
            "last_checked_at": utc_now(),
            "error": None,
        }
    except Exception as exc:  # pragma: no cover - network failure shape depends on the provider edge.
        snapshot = {
            "status": "api_error",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": sanitize_error(exc),
        }

    _fly_cache = dict(snapshot)
    _fly_cache_time = now
    return snapshot


def fly_live_budget_items() -> list[dict[str, object]] | None:
    if not os.getenv("FLY_API_TOKEN"):
        return None
    snapshot = _fetch_fly_snapshot()
    if not snapshot.get("live_verified"):
        return None
    # Fly.io does not expose per-machine pricing via GraphQL;
    # return an empty list so the budget pipeline stays consistent.
    return []


def hetzner_live_budget_items() -> list[dict[str, object]] | None:
    return None


def _fetch_grafana_cloud_snapshot() -> dict[str, Any]:
    token = os.getenv("GRAFANA_CLOUD_API_KEY")
    url = os.getenv("GRAFANA_CLOUD_URL")
    if not token or not url:
        return {
            "status": "missing_token",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": None,
        }

    global _grafana_cache, _grafana_cache_time
    now = time.monotonic()
    if _grafana_cache and now - _grafana_cache_time < GRAFANA_CLOUD_CACHE_TTL_SECONDS:
        return dict(_grafana_cache)

    try:
        if token.startswith("glc_"):
            import base64
            import json
            padding = len(token[4:]) % 4
            b64 = token[4:] + ("=" * padding)
            payload = json.loads(base64.b64decode(b64).decode("utf-8"))
            org_id = payload.get("o")
            name = payload.get("n")
        else:
            raise ValueError("Token must start with glc_")

        resources = [{
            "kind": "organization",
            "id": org_id,
            "name": name,
            "source": "grafana_api_readonly",
        }]
        snapshot = {
            "status": "verified",
            "live_verified": True,
            "resources": resources,
            "last_checked_at": utc_now(),
            "error": None,
        }
    except Exception as exc:  # pragma: no cover
        snapshot = {
            "status": "api_error",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": sanitize_error(exc),
        }

    _grafana_cache = dict(snapshot)
    _grafana_cache_time = now
    return snapshot


def _cloudflare_env_resource() -> dict[str, object] | None:
    keys = [
        "CLOUDFLARE_ACCOUNT_ID",
        "CLOUDFLARE_ZONE_ID",
        "CLOUDFLARE_AI_GATEWAY_URL",
        "CLOUDFLARE_DASHBOARD_URL",
    ]
    if not env_any(keys):
        return None
    dashboard = os.getenv("CLOUDFLARE_DASHBOARD_URL") or ""
    ai_gateway = os.getenv("CLOUDFLARE_AI_GATEWAY_URL") or ""
    return {
        "kind": "configured_target",
        "account_id": os.getenv("CLOUDFLARE_ACCOUNT_ID"),
        "zone_id": os.getenv("CLOUDFLARE_ZONE_ID"),
        "ai_gateway_host": urlparse(ai_gateway).netloc if ai_gateway else None,
        "dashboard_host": urlparse(dashboard).netloc if dashboard else None,
        "dashboard_configured": bool(dashboard),
        "source": "env_metadata_no_secret",
    }


def _cloudflare_token_resource(payload: dict[str, Any]) -> dict[str, object]:
    result = payload.get("result") or {}
    return {
        "kind": "api_token",
        "id": result.get("id"),
        "status": result.get("status"),
        "expires_on": result.get("expires_on"),
        "not_before": result.get("not_before"),
        "source": "cloudflare_api_readonly",
    }


def _cloudflare_account_resource(payload: dict[str, Any]) -> dict[str, object]:
    result = payload.get("result") or {}
    return {
        "kind": "account",
        "id": result.get("id"),
        "name": result.get("name"),
        "source": "cloudflare_api_readonly",
    }


def _cloudflare_zone_resource(payload: dict[str, Any]) -> dict[str, object]:
    result = payload.get("result") or {}
    account = result.get("account") or {}
    return {
        "kind": "zone",
        "id": result.get("id"),
        "name": result.get("name"),
        "status": result.get("status"),
        "type": result.get("type"),
        "paused": result.get("paused"),
        "account_id": account.get("id"),
        "source": "cloudflare_api_readonly",
    }


def _fetch_cloudflare_snapshot() -> dict[str, Any]:
    token = os.getenv("CLOUDFLARE_API_TOKEN")
    if not token:
        return {
            "status": "missing_token",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": None,
        }

    global _cloudflare_cache, _cloudflare_cache_time
    now = time.monotonic()
    if _cloudflare_cache and now - _cloudflare_cache_time < CLOUDFLARE_CACHE_TTL_SECONDS:
        return dict(_cloudflare_cache)

    resources: list[dict[str, object]] = []
    optional_errors: list[str] = []
    try:
        with httpx.Client(timeout=CLOUDFLARE_TIMEOUT_SECONDS) as client:
            verify_payload = _cloudflare_get(client, token, "/user/tokens/verify")
            resources.append(_cloudflare_token_resource(verify_payload))
            account_id = os.getenv("CLOUDFLARE_ACCOUNT_ID")
            zone_id = os.getenv("CLOUDFLARE_ZONE_ID")
            if account_id:
                try:
                    resources.append(_cloudflare_account_resource(_cloudflare_get(client, token, f"/accounts/{account_id}")))
                except Exception as exc:  # pragma: no cover - token scopes vary by account.
                    optional_errors.append(f"account_read_failed:{sanitize_error(exc)}")
            if zone_id:
                try:
                    resources.append(_cloudflare_zone_resource(_cloudflare_get(client, token, f"/zones/{zone_id}")))
                except Exception as exc:  # pragma: no cover - token scopes vary by zone.
                    optional_errors.append(f"zone_read_failed:{sanitize_error(exc)}")
        snapshot = {
            "status": "partial_verified" if optional_errors else "verified",
            "live_verified": True,
            "resources": resources,
            "last_checked_at": utc_now(),
            "error": "; ".join(optional_errors) if optional_errors else None,
        }
    except Exception as exc:  # pragma: no cover - network failure shape depends on the provider edge.
        snapshot = {
            "status": "api_error",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": sanitize_error(exc),
        }

    _cloudflare_cache = dict(snapshot)
    _cloudflare_cache_time = now
    return snapshot


def _vercel_env_resource() -> dict[str, object] | None:
    keys = ["STAGING_BASE_URL", "VERCEL_PROJECT_ID", "VERCEL_ORG_ID"]
    if not env_any(keys):
        return None
    staging = os.getenv("STAGING_BASE_URL") or ""
    return {
        "kind": "configured_target",
        "staging_host": urlparse(staging).netloc if staging else None,
        "staging_configured": bool(staging),
        "project_id_configured": bool(os.getenv("VERCEL_PROJECT_ID")),
        "team_id_configured": bool(os.getenv("VERCEL_ORG_ID")),
        "source": "env_metadata_no_secret",
    }


def _vercel_user_resource(payload: dict[str, Any]) -> dict[str, object]:
    user = payload.get("user") or payload
    return {
        "kind": "authenticated_user",
        "id": user.get("id"),
        "username": user.get("username"),
        "name": user.get("name"),
        "source": "vercel_api_readonly",
    }


def _vercel_project_resources(payload: dict[str, Any]) -> list[dict[str, object]]:
    resources: list[dict[str, object]] = []
    target_project_id = os.getenv("VERCEL_PROJECT_ID")
    for project in (payload.get("projects") or [])[:5]:
        resources.append(
            {
                "kind": "project",
                "id": project.get("id"),
                "name": project.get("name"),
                "framework": project.get("framework"),
                "target_match": bool(target_project_id and project.get("id") == target_project_id),
                "source": "vercel_api_readonly",
            }
        )
    return resources


def _fetch_vercel_snapshot() -> dict[str, Any]:
    token = os.getenv("VERCEL_TOKEN")
    if not token:
        return {
            "status": "missing_token",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": None,
        }

    global _vercel_cache, _vercel_cache_time
    now = time.monotonic()
    if _vercel_cache and now - _vercel_cache_time < PROVIDER_CACHE_TTL_SECONDS:
        return dict(_vercel_cache)

    resources: list[dict[str, object]] = []
    optional_errors: list[str] = []
    try:
        with httpx.Client(timeout=PROVIDER_TIMEOUT_SECONDS) as client:
            resources.append(_vercel_user_resource(_vercel_get(client, token, "/v2/user")))
            params: dict[str, str] = {"limit": "20"}
            team_id = os.getenv("VERCEL_ORG_ID")
            if team_id:
                params["teamId"] = team_id
            try:
                resources.extend(_vercel_project_resources(_vercel_get(client, token, "/v10/projects", params=params)))
            except Exception as exc:  # pragma: no cover - token scopes vary by team/project.
                optional_errors.append(f"projects_read_failed:{sanitize_error(exc)}")
        snapshot = {
            "status": "partial_verified" if optional_errors else "verified",
            "live_verified": True,
            "resources": resources,
            "last_checked_at": utc_now(),
            "error": "; ".join(optional_errors) if optional_errors else None,
        }
    except Exception as exc:  # pragma: no cover - network failure shape depends on the provider edge.
        snapshot = {
            "status": "api_error",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": sanitize_error(exc),
        }

    _vercel_cache = dict(snapshot)
    _vercel_cache_time = now
    return snapshot


def _github_env_resource() -> dict[str, object] | None:
    repository = os.getenv("GITHUB_REPOSITORY")
    if not repository:
        return None
    return {
        "kind": "configured_repository",
        "repository": repository,
        "source": "env_metadata_no_secret",
    }


def _github_user_resource(payload: dict[str, Any]) -> dict[str, object]:
    return {
        "kind": "authenticated_user",
        "id": payload.get("id"),
        "login": payload.get("login"),
        "type": payload.get("type"),
        "two_factor_authentication": payload.get("two_factor_authentication"),
        "source": "github_api_readonly",
    }


def _github_repository_resource(payload: dict[str, Any]) -> dict[str, object]:
    return {
        "kind": "repository",
        "id": payload.get("id"),
        "full_name": payload.get("full_name"),
        "private": payload.get("private"),
        "default_branch": payload.get("default_branch"),
        "archived": payload.get("archived"),
        "source": "github_api_readonly",
    }


def _fetch_github_snapshot() -> dict[str, Any]:
    token = os.getenv("GITHUB_TOKEN")
    if not token:
        return {
            "status": "missing_token",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": None,
        }

    global _github_cache, _github_cache_time
    now = time.monotonic()
    if _github_cache and now - _github_cache_time < PROVIDER_CACHE_TTL_SECONDS:
        return dict(_github_cache)

    resources: list[dict[str, object]] = []
    optional_errors: list[str] = []
    try:
        with httpx.Client(timeout=PROVIDER_TIMEOUT_SECONDS) as client:
            user_payload = _github_get(client, token, "/user")
            if isinstance(user_payload, dict):
                resources.append(_github_user_resource(user_payload))
            repository = os.getenv("GITHUB_REPOSITORY")
            if repository:
                try:
                    repo_payload = _github_get(client, token, f"/repos/{repository}")
                    if isinstance(repo_payload, dict):
                        resources.append(_github_repository_resource(repo_payload))
                except Exception as exc:  # pragma: no cover - repo visibility and token scopes vary.
                    optional_errors.append(f"repository_read_failed:{sanitize_error(exc)}")
        snapshot = {
            "status": "partial_verified" if optional_errors else "verified",
            "live_verified": True,
            "resources": resources,
            "last_checked_at": utc_now(),
            "error": "; ".join(optional_errors) if optional_errors else None,
        }
    except Exception as exc:  # pragma: no cover - network failure shape depends on the provider edge.
        snapshot = {
            "status": "api_error",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": sanitize_error(exc),
        }

    _github_cache = dict(snapshot)
    _github_cache_time = now
    return snapshot


def _ghcr_env_resource() -> dict[str, object] | None:
    keys = ["GHCR_OWNER", "GHCR_PACKAGE"]
    if not env_any(keys):
        return None
    return {
        "kind": "configured_registry_target",
        "owner_configured": bool(os.getenv("GHCR_OWNER")),
        "package_configured": bool(os.getenv("GHCR_PACKAGE")),
        "source": "env_metadata_no_secret",
    }


def _ghcr_package_resource(payload: dict[str, Any]) -> dict[str, object]:
    owner = payload.get("owner") or {}
    target_package = os.getenv("GHCR_PACKAGE")
    return {
        "kind": "container_package",
        "id": payload.get("id"),
        "name": payload.get("name"),
        "visibility": payload.get("visibility"),
        "version_count": payload.get("version_count"),
        "owner_login": owner.get("login"),
        "target_match": bool(target_package and payload.get("name") == target_package),
        "source": "ghcr_api_readonly",
    }


def _fetch_ghcr_snapshot() -> dict[str, Any]:
    token = os.getenv("GHCR_TOKEN")
    if not token:
        return {
            "status": "missing_token",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": None,
        }

    global _ghcr_cache, _ghcr_cache_time
    now = time.monotonic()
    if _ghcr_cache and now - _ghcr_cache_time < PROVIDER_CACHE_TTL_SECONDS:
        return dict(_ghcr_cache)

    try:
        with httpx.Client(timeout=PROVIDER_TIMEOUT_SECONDS) as client:
            payload = _github_get(
                client,
                token,
                "/user/packages",
                params={"package_type": "container", "per_page": "20"},
            )
        packages = payload if isinstance(payload, list) else []
        resources = [_ghcr_package_resource(item) for item in packages if isinstance(item, dict)]
        if not resources:
            resources.append(
                {
                    "kind": "container_registry_namespace",
                    "package_count": 0,
                    "source": "ghcr_api_readonly",
                }
            )
        snapshot = {
            "status": "verified",
            "live_verified": True,
            "resources": resources,
            "last_checked_at": utc_now(),
            "error": None,
        }
    except Exception as exc:  # pragma: no cover - package scopes vary by token type.
        snapshot = {
            "status": "api_error",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": sanitize_error(exc),
        }

    _ghcr_cache = dict(snapshot)
    _ghcr_cache_time = now
    return snapshot


def _huggingface_env_resource() -> dict[str, object] | None:
    return configured_url_resource("configured_profile", "HF_PROFILE_URL", "env_metadata_no_secret")


def _huggingface_user_resource(payload: dict[str, Any]) -> dict[str, object]:
    orgs = payload.get("orgs")
    return {
        "kind": "authenticated_user",
        "name": payload.get("name"),
        "fullname": payload.get("fullname"),
        "type": payload.get("type"),
        "org_count": len(orgs) if isinstance(orgs, list) else None,
        "source": "huggingface_api_readonly",
    }


def _fetch_huggingface_snapshot() -> dict[str, Any]:
    token = os.getenv("HF_TOKEN")
    if not token:
        return {
            "status": "missing_token",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": None,
        }

    global _huggingface_cache, _huggingface_cache_time
    now = time.monotonic()
    if _huggingface_cache and now - _huggingface_cache_time < PROVIDER_CACHE_TTL_SECONDS:
        return dict(_huggingface_cache)

    try:
        with httpx.Client(timeout=PROVIDER_TIMEOUT_SECONDS) as client:
            resources = [_huggingface_user_resource(_huggingface_get(client, token, "/api/whoami-v2"))]
        snapshot = {
            "status": "verified",
            "live_verified": True,
            "resources": resources,
            "last_checked_at": utc_now(),
            "error": None,
        }
    except Exception as exc:  # pragma: no cover - network failure shape depends on the provider edge.
        snapshot = {
            "status": "api_error",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": sanitize_error(exc),
        }

    _huggingface_cache = dict(snapshot)
    _huggingface_cache_time = now
    return snapshot


def _gitlab_env_resource() -> dict[str, object] | None:
    resources = [
        resource
        for resource in [
            configured_url_resource("configured_profile", "GITLAB_PROFILE_URL", "env_metadata_no_secret"),
            configured_url_resource("configured_api", "GITLAB_API_URL", "env_metadata_no_secret"),
        ]
        if resource
    ]
    if not resources:
        return None
    return {
        "kind": "configured_targets",
        "targets": len(resources),
        "profile_configured": bool(os.getenv("GITLAB_PROFILE_URL")),
        "api_url_configured": bool(os.getenv("GITLAB_API_URL")),
        "source": "env_metadata_no_secret",
    }


def _gitlab_user_resource(payload: dict[str, Any]) -> dict[str, object]:
    return {
        "kind": "authenticated_user",
        "id": payload.get("id"),
        "username": payload.get("username"),
        "name": payload.get("name"),
        "state": payload.get("state"),
        "web_url": payload.get("web_url"),
        "source": "gitlab_api_readonly",
    }


def _fetch_gitlab_snapshot() -> dict[str, Any]:
    token = os.getenv("GITLAB_TOKEN")
    if not token:
        return {
            "status": "missing_token",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": None,
        }

    global _gitlab_cache, _gitlab_cache_time
    now = time.monotonic()
    if _gitlab_cache and now - _gitlab_cache_time < PROVIDER_CACHE_TTL_SECONDS:
        return dict(_gitlab_cache)

    try:
        with httpx.Client(timeout=PROVIDER_TIMEOUT_SECONDS) as client:
            resources = [_gitlab_user_resource(_gitlab_get(client, token, "/user"))]
        snapshot = {
            "status": "verified",
            "live_verified": True,
            "resources": resources,
            "last_checked_at": utc_now(),
            "error": None,
        }
    except Exception as exc:  # pragma: no cover - network failure shape depends on the provider edge.
        snapshot = {
            "status": "api_error",
            "live_verified": False,
            "resources": [],
            "last_checked_at": utc_now(),
            "error": sanitize_error(exc),
        }

    _gitlab_cache = dict(snapshot)
    _gitlab_cache_time = now
    return snapshot





def provider(
    *,
    provider_id: str,
    label: str,
    role: str,
    layers: list[str],
    required_env: list[str],
    optional_env: list[str] | None = None,
    resources: list[dict[str, object]] | None = None,
    live_verified: bool = False,
    status: str | None = None,
    monthly_cost_cents: int | None = None,
    last_checked_at: str | None = None,
    non_claims: list[str] | None = None,
) -> dict[str, object]:
    optional_env = optional_env or []
    configured = env_any(required_env + optional_env)
    if status is None:
        status = "live_verified" if live_verified else ("configured" if configured else "action_required")
    return {
        "id": provider_id,
        "label": label,
        "role": role,
        "layers": layers,
        "configured": configured,
        "live_verified": live_verified,
        "status": status,
        "required_env": required_env,
        "optional_env": optional_env,
        "env_status": masked_env_status(required_env + optional_env),
        "resources": resources or [],
        "monthly_cost_cents": monthly_cost_cents,
        "last_checked_at": last_checked_at,
        "non_claims": non_claims or [],
    }


def fly_provider() -> dict[str, object]:
    snapshot = _fetch_fly_snapshot()
    resources = list(snapshot.get("resources") or [])
    token_configured = bool(os.getenv("FLY_API_TOKEN"))
    configured = token_configured
    live_verified = bool(snapshot.get("live_verified"))
    if live_verified:
        status = "live_verified"
    elif token_configured:
        status = "api_error"
    else:
        status = "action_required"
    item = provider(
        provider_id="fly_io",
        label="Fly.io",
        role="Layer 2/3/6 runtime host for Orchestrator, Agent Pool, and PostgreSQL.",
        layers=["layer_2", "layer_3", "layer_6", "layer_7"],
        required_env=["FLY_API_TOKEN"],
        resources=resources,
        live_verified=live_verified,
        status=status,
        monthly_cost_cents=0 if live_verified else None,
        last_checked_at=str(snapshot.get("last_checked_at") or utc_now()),
        non_claims=[
            "No Fly.io token value is returned by this endpoint.",
            "Live Fly.io state is claimed only when FLY_API_TOKEN is present and the read-only GraphQL call succeeds.",
            "No Fly.io app, machine, volume, or secret write is performed by this endpoint.",
        ],
    )
    item["configured"] = configured
    if snapshot.get("error"):
        item["error"] = snapshot["error"]
    return item


def grafana_cloud_provider() -> dict[str, object]:
    snapshot = _fetch_grafana_cloud_snapshot()
    resources = list(snapshot.get("resources") or [])
    token_configured = bool(os.getenv("GRAFANA_CLOUD_API_KEY"))
    url_configured = bool(os.getenv("GRAFANA_CLOUD_URL"))
    configured = token_configured or url_configured
    live_verified = bool(snapshot.get("live_verified"))
    if live_verified:
        status = str(snapshot.get("status") or "verified")
    elif token_configured:
        status = "api_error"
    elif url_configured:
        status = "metadata_only"
    else:
        status = "action_required"
    item = provider(
        provider_id="grafana_cloud",
        label="Grafana Cloud",
        role="Layer 7 hosted observability, logs, metrics, and traces.",
        layers=["layer_7"],
        required_env=["GRAFANA_CLOUD_API_KEY"],
        optional_env=["GRAFANA_CLOUD_URL"],
        resources=resources,
        live_verified=live_verified,
        status=status,
        monthly_cost_cents=0 if live_verified else None,
        last_checked_at=str(snapshot.get("last_checked_at") or utc_now()),
        non_claims=[
            "No Grafana Cloud API key value is returned by this endpoint.",
            "Grafana Cloud identity is read-only and does not modify dashboards, alerts, or data sources.",
            "No organization, stack, dashboard, alert, or data-source write is performed.",
        ],
    )
    item["configured"] = configured
    if snapshot.get("error"):
        item["error"] = snapshot["error"]
    return item


def cloudflare_provider() -> dict[str, object]:
    metadata = _cloudflare_env_resource()
    snapshot = _fetch_cloudflare_snapshot()
    resources = list(snapshot.get("resources") or [])
    if metadata:
        resources.append(metadata)
    token_configured = bool(os.getenv("CLOUDFLARE_API_TOKEN"))
    metadata_configured = metadata is not None
    configured = token_configured or metadata_configured
    live_verified = bool(snapshot.get("live_verified"))
    if live_verified:
        status = str(snapshot.get("status") or "live_verified")
    elif token_configured:
        status = "api_error"
    elif metadata_configured:
        status = "metadata_only"
    else:
        status = "action_required"
    item = provider(
        provider_id="cloudflare_edge",
        label="Cloudflare Edge / AI Gateway",
        role="Layer 4 edge, DNS, AI gateway, and provider-cache boundary.",
        layers=["layer_4", "layer_7"],
        required_env=["CLOUDFLARE_API_TOKEN"],
        optional_env=[
            "CLOUDFLARE_ACCOUNT_ID",
            "CLOUDFLARE_ZONE_ID",
            "CLOUDFLARE_AI_GATEWAY_URL",
            "CLOUDFLARE_DASHBOARD_URL",
        ],
        resources=resources,
        live_verified=live_verified,
        status=status,
        monthly_cost_cents=0 if live_verified else None,
        last_checked_at=str(snapshot.get("last_checked_at") or utc_now()),
        non_claims=[
            "No Cloudflare token value is returned by this endpoint.",
            "The live proof calls Cloudflare read-only token verification and optional account or zone reads only.",
            "No DNS, Workers, AI Gateway, cache, or security rule write is performed by this endpoint.",
            "No AI Gateway routing is claimed without the LLM gateway policy proof.",
        ],
    )
    item["configured"] = configured
    if snapshot.get("error"):
        item["error"] = snapshot["error"]
    return item


def vercel_provider() -> dict[str, object]:
    metadata = _vercel_env_resource()
    snapshot = _fetch_vercel_snapshot()
    resources = list(snapshot.get("resources") or [])
    if metadata:
        resources.append(metadata)
    token_configured = bool(os.getenv("VERCEL_TOKEN"))
    metadata_configured = metadata is not None
    configured = token_configured or metadata_configured
    live_verified = bool(snapshot.get("live_verified"))
    if live_verified:
        status = str(snapshot.get("status") or "verified")
    elif token_configured:
        status = "api_error"
    elif metadata_configured:
        status = "metadata_only"
    else:
        status = "action_required"
    item = provider(
        provider_id="vercel_frontend",
        label="Vercel / Hosted Frontend",
        role="Layer 1 hosted frontend and staging proof origin.",
        layers=["layer_1", "layer_7"],
        required_env=["STAGING_BASE_URL"],
        optional_env=["VERCEL_TOKEN", "VERCEL_PROJECT_ID", "VERCEL_ORG_ID"],
        resources=resources,
        live_verified=live_verified,
        status=status,
        monthly_cost_cents=0 if live_verified else None,
        last_checked_at=str(snapshot.get("last_checked_at") or utc_now()),
        non_claims=[
            "No Vercel token value is returned by this endpoint.",
            "A live Vercel account read is not a hosted-staging success claim without STAGING_BASE_URL and the hosted verifier.",
            "No Vercel deployment, environment variable, alias, domain, or rollback write is performed.",
            "Localhost proof remains local unless the hosted verifier runs against the configured URL.",
        ],
    )
    item["configured"] = configured
    if snapshot.get("error"):
        item["error"] = snapshot["error"]
    return item


def github_provider() -> dict[str, object]:
    metadata = _github_env_resource()
    snapshot = _fetch_github_snapshot()
    resources = list(snapshot.get("resources") or [])
    if metadata:
        resources.append(metadata)
    token_configured = bool(os.getenv("GITHUB_TOKEN"))
    metadata_configured = metadata is not None
    configured = token_configured or metadata_configured
    live_verified = bool(snapshot.get("live_verified"))
    if live_verified:
        status = str(snapshot.get("status") or "verified")
    elif token_configured:
        status = "api_error"
    elif metadata_configured:
        status = "metadata_only"
    else:
        status = "action_required"
    item = provider(
        provider_id="github_actions",
        label="GitHub Actions",
        role="Layer 5 CI/CD, branch protection, and manual deployment proof gate.",
        layers=["layer_5", "layer_7"],
        required_env=["GITHUB_TOKEN"],
        optional_env=["BRANCH_PROTECTION_TOKEN", "GITHUB_REPOSITORY"],
        resources=resources,
        live_verified=live_verified,
        status=status,
        monthly_cost_cents=0 if live_verified else None,
        last_checked_at=str(snapshot.get("last_checked_at") or utc_now()),
        non_claims=[
            "No GitHub token value is returned by this endpoint.",
            "Branch protection success is not claimed without a verified branch-protection workflow proof.",
            "No workflow dispatch, branch, commit, pull request, package, or repository write is performed by this endpoint.",
        ],
    )
    item["configured"] = configured
    if snapshot.get("error"):
        item["error"] = snapshot["error"]
    return item


def ghcr_provider() -> dict[str, object]:
    metadata = _ghcr_env_resource()
    snapshot = _fetch_ghcr_snapshot()
    resources = list(snapshot.get("resources") or [])
    if metadata:
        resources.append(metadata)
    token_configured = bool(os.getenv("GHCR_TOKEN"))
    metadata_configured = metadata is not None
    configured = token_configured or metadata_configured
    live_verified = bool(snapshot.get("live_verified"))
    if live_verified:
        status = str(snapshot.get("status") or "verified")
    elif token_configured:
        status = "api_error"
    elif metadata_configured:
        status = "metadata_only"
    else:
        status = "action_required"
    item = provider(
        provider_id="ghcr_registry",
        label="GHCR Registry",
        role="Layer 5 container artifact registry for pull-based host deployment.",
        layers=["layer_5"],
        required_env=["GHCR_TOKEN"],
        optional_env=["GITHUB_TOKEN", "GHCR_OWNER", "GHCR_PACKAGE"],
        resources=resources,
        live_verified=live_verified,
        status=status,
        monthly_cost_cents=0 if live_verified else None,
        last_checked_at=str(snapshot.get("last_checked_at") or utc_now()),
        non_claims=[
            "No GHCR token value is returned by this endpoint.",
            "No image push, delete, package visibility change, or production pull is performed by this endpoint.",
            "Registry availability is claimed only when a read-only GitHub Packages container query succeeds.",
        ],
    )
    item["configured"] = configured
    if snapshot.get("error"):
        item["error"] = snapshot["error"]
    return item


def huggingface_provider() -> dict[str, object]:
    metadata = _huggingface_env_resource()
    snapshot = _fetch_huggingface_snapshot()
    resources = list(snapshot.get("resources") or [])
    if metadata:
        resources.append(metadata)
    token_configured = bool(os.getenv("HF_TOKEN"))
    metadata_configured = metadata is not None
    configured = token_configured or metadata_configured
    live_verified = bool(snapshot.get("live_verified"))
    if live_verified:
        status = str(snapshot.get("status") or "verified")
    elif token_configured:
        status = "api_error"
    elif metadata_configured:
        status = "metadata_only"
    else:
        status = "action_required"
    item = provider(
        provider_id="huggingface_identity",
        label="Hugging Face",
        role="Optional Layer 4 model/provider identity check; not the production runtime.",
        layers=["layer_4", "layer_7"],
        required_env=["HF_TOKEN"],
        optional_env=["HF_PROFILE_URL"],
        resources=resources,
        live_verified=live_verified,
        status=status,
        monthly_cost_cents=0 if live_verified else None,
        last_checked_at=str(snapshot.get("last_checked_at") or utc_now()),
        non_claims=[
            "No Hugging Face token value is returned by this endpoint.",
            "Hugging Face Spaces is not treated as the production runtime.",
            "No model, dataset, Space, inference endpoint, organization, or token write is performed.",
        ],
    )
    item["configured"] = configured
    if snapshot.get("error"):
        item["error"] = snapshot["error"]
    return item


def gitlab_provider() -> dict[str, object]:
    metadata = _gitlab_env_resource()
    snapshot = _fetch_gitlab_snapshot()
    resources = list(snapshot.get("resources") or [])
    if metadata:
        resources.append(metadata)
    token_configured = bool(os.getenv("GITLAB_TOKEN"))
    metadata_configured = metadata is not None
    configured = token_configured or metadata_configured
    live_verified = bool(snapshot.get("live_verified"))
    if live_verified:
        status = str(snapshot.get("status") or "verified")
    elif token_configured:
        status = "api_error"
    elif metadata_configured:
        status = "metadata_only"
    else:
        status = "action_required"
    item = provider(
        provider_id="gitlab_identity",
        label="GitLab",
        role="Optional Layer 5 external identity or mirror proof.",
        layers=["layer_5", "layer_7"],
        required_env=["GITLAB_TOKEN"],
        optional_env=["GITLAB_PROFILE_URL", "GITLAB_API_URL"],
        resources=resources,
        live_verified=live_verified,
        status=status,
        monthly_cost_cents=0 if live_verified else None,
        last_checked_at=str(snapshot.get("last_checked_at") or utc_now()),
        non_claims=[
            "No GitLab token value is returned by this endpoint.",
            "GitLab identity is optional and not a production-release gate in the patched architecture.",
            "No project, mirror, issue, pipeline, repository, group, or user write is performed.",
        ],
    )
    item["configured"] = configured
    if snapshot.get("error"):
        item["error"] = snapshot["error"]
    return item





def cloud_provider_state() -> dict[str, object]:
    providers = [
        vercel_provider(),
        fly_provider(),
        cloudflare_provider(),
        github_provider(),
        ghcr_provider(),
        huggingface_provider(),
        gitlab_provider(),
        grafana_cloud_provider(),
    ]
    configured = sum(1 for item in providers if bool(item.get("configured")))
    live_verified = sum(1 for item in providers if bool(item.get("live_verified")))
    layer_mapping = [
        {
            "layer_id": "layer_1",
            "label": "Frontend / Next.js",
            "providers": ["vercel_frontend"],
            "evidence_ref": CLOUD_PROVIDER_EVIDENCE_REF,
        },
        {
            "layer_id": "layer_2",
            "label": "Orchestrator / LangGraph",
            "providers": ["fly_io"],
            "evidence_ref": CLOUD_PROVIDER_EVIDENCE_REF,
        },
        {
            "layer_id": "layer_3",
            "label": "Agent Pool",
            "providers": ["fly_io"],
            "evidence_ref": CLOUD_PROVIDER_EVIDENCE_REF,
        },
        {
            "layer_id": "layer_4",
            "label": "LLM Gateway",
            "providers": ["cloudflare_edge", "huggingface_identity"],
            "evidence_ref": CLOUD_PROVIDER_EVIDENCE_REF,
        },
        {
            "layer_id": "layer_5",
            "label": "MCP Gateway / Tools",
            "providers": ["github_actions", "ghcr_registry", "gitlab_identity"],
            "evidence_ref": CLOUD_PROVIDER_EVIDENCE_REF,
        },
        {
            "layer_id": "layer_6",
            "label": "Memory / PostgreSQL pgvector",
            "providers": ["fly_io"],
            "evidence_ref": CLOUD_PROVIDER_EVIDENCE_REF,
        },
        {
            "layer_id": "layer_7",
            "label": "Observability / Evidence",
            "providers": [
                "vercel_frontend",
                "fly_io",
                "cloudflare_edge",
                "github_actions",
                "grafana_cloud",
            ],
            "evidence_ref": CLOUD_PROVIDER_EVIDENCE_REF,
        },
    ]
    return {
        "contract_version": CLOUD_PROVIDER_CONTRACT_VERSION,
        "status": "complete" if configured == len(providers) else ("partial" if configured else "action_required"),
        "endpoint": "GET /api/v1/clouds",
        "evidence_ref": CLOUD_PROVIDER_EVIDENCE_REF,
        "configured_count": configured,
        "live_verified_count": live_verified,
        "total_count": len(providers),
        "providers": providers,
        "seven_layer_mapping": layer_mapping,
        "policy_checks": [
            "No secret values are returned by the cloud inventory endpoint.",
            "Cloud providers map to the existing seven architecture layers.",
            "Live Fly.io reads are read-only and token-gated.",
            "Vercel, GitHub, GHCR, Hugging Face, GitLab, and Grafana Cloud live checks are read-only and token-gated.",
            "Budget guard remains the source of truth for new infrastructure permission.",
            "Production deployment remains blocked until hosted staging, branch protection, secret scan, and owner review pass.",
        ],
        "non_claims": [
            "This endpoint does not create, mutate, deploy, or delete cloud resources.",
            "It does not claim production deployment.",
            "It does not claim live LLM provider calls.",
            "It does not persist provider tokens.",
        ],
    }


def _providers_by_id(providers: list[dict[str, object]]) -> dict[str, dict[str, object]]:
    return {str(item.get("id")): item for item in providers}


def _provider_blockers(provider: dict[str, object]) -> list[str]:
    provider_id = str(provider.get("id") or "provider")
    required_env = [str(item) for item in provider.get("required_env", []) if item]
    missing_required_env = [
        env_key for env_key in required_env if not os.getenv(env_key)
    ]
    if missing_required_env:
        return [f"{provider_id}_requires_{env_key}" for env_key in missing_required_env]
    if provider.get("live_verified"):
        return []
    if provider.get("configured"):
        return [f"{provider_id}_live_read_not_verified"]
    return [f"{provider_id}_configuration_missing"]


def _layer_status(blockers: list[str], live_verified_provider_count: int, required_provider_count: int) -> str:
    if not blockers and live_verified_provider_count >= required_provider_count:
        return "live_verified"
    if live_verified_provider_count > 0:
        return "partial_live_verified"
    if blockers:
        return "action_required"
    return "metadata_ready"


def cloud_layer_readiness_state() -> dict[str, object]:
    inventory = cloud_provider_state()
    providers = [item for item in inventory["providers"] if isinstance(item, dict)]
    providers_by_id = _providers_by_id(providers)
    layers = []
    for mapping in inventory["seven_layer_mapping"]:
        if not isinstance(mapping, dict):
            continue
        provider_ids = [str(item) for item in mapping.get("providers", [])]
        mapped_providers = [providers_by_id[provider_id] for provider_id in provider_ids if provider_id in providers_by_id]
        configured = [str(provider.get("id")) for provider in mapped_providers if provider.get("configured")]
        live_verified = [str(provider.get("id")) for provider in mapped_providers if provider.get("live_verified")]
        blockers: list[str] = []
        for provider in mapped_providers:
            blockers.extend(_provider_blockers(provider))
        status = _layer_status(blockers, len(live_verified), len(mapped_providers))
        layer_id = str(mapping.get("layer_id"))
        next_safe_action = (
            "run_hosted_verifier_and_keep_localhost_as_dev_only"
            if layer_id == "layer_1"
            else "configure_runtime_env_then_refresh_cloud_inventory"
        )
        layers.append(
            {
                "layer_id": layer_id,
                "label": mapping.get("label"),
                "status": status,
                "required_providers": provider_ids,
                "configured_providers": configured,
                "live_verified_providers": live_verified,
                "blockers": blockers,
                "evidence_ref": CLOUD_LAYER_EVIDENCE_REF,
                "next_safe_action": next_safe_action if blockers else "capture_evidence_and_keep_fail_closed_claims",
                "non_claims": [
                    "Cloud readiness is not a production deployment claim.",
                    "A layer is not live-verified until its provider read gates pass.",
                ],
            }
        )
    ready_count = sum(1 for item in layers if item["status"] == "live_verified")
    partial_count = sum(1 for item in layers if item["status"] == "partial_live_verified")
    status = "verified" if ready_count == len(layers) else ("partial" if partial_count or ready_count else "action_required")
    return {
        "contract_version": CLOUD_LAYER_CONTRACT_VERSION,
        "status": status,
        "endpoint": "GET /api/v1/clouds/layers",
        "evidence_ref": CLOUD_LAYER_EVIDENCE_REF,
        "ready_layer_count": ready_count,
        "partial_layer_count": partial_count,
        "total_layer_count": len(layers),
        "layers": layers,
        "provider_inventory_endpoint": "GET /api/v1/clouds",
        "provider_inventory_evidence_ref": CLOUD_PROVIDER_EVIDENCE_REF,
        "policy_checks": [
            "Every cloud readiness record maps to one of the seven architecture layers.",
            "Provider secret values are never returned by this endpoint.",
            "Missing provider env gates are exposed as blocker strings.",
            "Localhost proof remains development-only and cannot close production cloud readiness.",
        ],
        "non_claims": [
            "This endpoint does not create or mutate cloud resources.",
            "This endpoint does not claim production deployment.",
            "This endpoint does not claim live LLM provider execution.",
        ],
    }
