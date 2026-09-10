from __future__ import annotations

import json
import sys
from pathlib import Path


project_root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(project_root / "services" / "agent-api"))

from app.main import organism_topology_payload  # noqa: E402


print(
    json.dumps(
        organism_topology_payload(),
        separators=(",", ":"),
        sort_keys=True,
    )
)
