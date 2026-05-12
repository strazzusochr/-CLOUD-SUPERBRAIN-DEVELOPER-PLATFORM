import os
from pathlib import Path

import requests


API_URL = "https://api.hetzner.cloud/v1/ssh_keys"


def get_required_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def main() -> None:
    token = get_required_env("HETZNER_API_TOKEN")
    public_key_path = get_required_env("STAGING_SSH_PUBLIC_KEY_PATH")
    key_name = os.environ.get("STAGING_SSH_KEY_NAME", "superbrain-staging").strip()
    public_key = Path(public_key_path).read_text(encoding="utf-8").strip()

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    payload = {
        "name": key_name,
        "public_key": public_key,
    }

    response = requests.post(API_URL, headers=headers, json=payload, timeout=30)
    print(response.text)


if __name__ == "__main__":
    main()
