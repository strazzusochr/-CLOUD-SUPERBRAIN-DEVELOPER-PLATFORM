from __future__ import annotations

import os
import unittest
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import patch
from uuid import uuid4

from fastapi import HTTPException

from app import main


TOKEN = "page01-runtime-agent-token"
OWNER = "local-session:12345678-1234-1234-1234-123456789abc"


class FakeConnection:
    def __init__(self) -> None:
        self.closed = False

    def __enter__(self) -> "FakeConnection":
        return self

    def __exit__(self, *_: object) -> None:
        self.closed = True

    def execute(self, sql: str, *_: object):
        if "INSERT INTO audit_log" in sql:
            return SimpleNamespace(fetchone=lambda: (uuid4(), datetime.now(timezone.utc)))
        return SimpleNamespace(fetchone=lambda: None)


def http_request(trace_id: str) -> SimpleNamespace:
    return SimpleNamespace(state=SimpleNamespace(trace_id=trace_id))


class Page01RuntimeProducerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.connection = FakeConnection()

    def test_artifact_creation_records_memory_and_artifact_runtime_events(self) -> None:
        request = main.WorkspaceArtifactRequest(
            project_id="page01",
            source_page="home",
            artifact_type="note",
            title="Runtime note",
            summary="A redacted artifact",
        )
        with (
            patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TOKEN}),
            patch.object(main, "database_url", return_value="postgresql://unit"),
            patch.object(main.psycopg, "connect", return_value=self.connection),
            patch.object(main, "find_or_create_project_uuid", return_value="project-id"),
            patch.object(main, "insert_memory_entry", return_value="memory-id"),
            patch.object(main, "_append_workspace_runtime_event", return_value="runtime-id") as append,
        ):
            result = main.create_workspace_artifact(
                request,
                http_request("artifact-trace"),
                x_superbrain_agent_token=TOKEN,
                x_superbrain_workspace_subject=OWNER,
            )
        self.assertTrue(result["audit_persisted"])
        self.assertEqual(append.call_count, 2)
        self.assertEqual(append.call_args_list[0].kwargs["event_type"], "memory_entry_created")
        self.assertEqual(append.call_args_list[1].kwargs["event_type"], "workspace_artifact_created")
        self.assertEqual(append.call_args_list[1].kwargs["parent_event_id"], "runtime-id")

    def test_read_only_memory_tool_records_tool_and_memory_runtime_events(self) -> None:
        request = main.ReadOnlyToolExecuteRequest(
            project_id="page01",
            tool_id="memory_read",
            query="safe query",
            trace_id="tool-trace",
        )
        with (
            patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TOKEN}),
            patch.object(main, "database_url", return_value="postgresql://unit"),
            patch.object(main.psycopg, "connect", return_value=self.connection),
            patch.object(main, "search_memory", return_value=[]),
            patch.object(main, "_append_workspace_runtime_event", return_value="runtime-id") as append,
        ):
            result = main.execute_read_only_tool(
                request,
                http_request("tool-trace"),
                x_superbrain_agent_token=TOKEN,
                x_superbrain_workspace_subject=OWNER,
            )
        self.assertEqual(result["status"], "success")
        self.assertEqual(append.call_count, 2)
        self.assertEqual(append.call_args_list[0].kwargs["event_type"], "memory_read_completed")
        self.assertEqual(append.call_args_list[1].kwargs["event_type"], "mcp_tool_executed")
        self.assertEqual(append.call_args_list[1].kwargs["parent_event_id"], "runtime-id")

    def test_autonomous_dispatch_records_agent_runtime_event(self) -> None:
        with patch.object(main, "_append_workspace_runtime_event", return_value="agent-runtime-id") as append:
            event_id = main.persist_autonomous_dispatch_runtime_event(
                self.connection,
                owner_subject=OWNER,
                dispatch_id="dispatch-1",
                project_id="page01",
                assignment_count=4,
                trace_id="dispatch-trace",
            )
        self.assertEqual(event_id, "agent-runtime-id")
        self.assertEqual(append.call_args.kwargs["event_type"], "agent_task_dispatch_queued")
        self.assertEqual(append.call_args.kwargs["producer"], "agent_orchestrator")

    def test_autonomous_dispatch_route_returns_owner_runtime_event(self) -> None:
        blueprint = {
            "logical_role": "planner",
            "execution_agent_type": "planner",
            "task_type": "page01_plan",
            "task_description": "Plan page01",
            "priority": 8,
            "allowed_tools": ["memory_read"],
            "planned_capabilities": ["scope_guard"],
            "write_scope": [],
            "acceptance_criteria": ["runtime_visibility"],
            "human_review_required": True,
            "blocked_actions": [],
        }
        task = SimpleNamespace(
            task_id="task-1",
            agent_type="planner",
            task_type="page01_plan",
            status="queued",
            priority=8,
            allowed_tools=["memory_read"],
            write_scope=[],
            acceptance_criteria=["runtime_visibility"],
            human_review_required=True,
            blocked_actions=[],
        )
        request = main.AutonomousCodingDispatchRequest(project_id="page01", objective="Plan home")
        with (
            patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TOKEN}),
            patch.object(main, "prepare_orchestrator_session", return_value="12345678-1234-1234-1234-123456789abc"),
            patch.object(main, "autonomous_assignment_blueprints", return_value=[blueprint]),
            patch.object(main, "validate_task_policy"),
            patch.object(main, "enqueue_task", return_value=task),
            patch.object(main, "store_autonomous_dispatch"),
            patch.object(main, "persist_autonomous_dispatch_audit"),
            patch.object(main, "autonomous_team_contract_payload", return_value={"non_claims": []}),
            patch.object(main, "database_url", return_value="postgresql://unit"),
            patch.object(main.psycopg, "connect", return_value=self.connection),
            patch.object(main, "_append_workspace_runtime_event", return_value="agent-runtime-id") as append,
        ):
            result = main.autonomous_task_dispatch(
                request,
                http_request("dispatch-trace"),
                x_superbrain_agent_token=TOKEN,
                x_superbrain_workspace_subject=OWNER,
            )
        self.assertTrue(result["runtime_event_persisted"])
        self.assertEqual(result["runtime_event_id"], "agent-runtime-id")
        self.assertEqual(append.call_args.kwargs["event_type"], "agent_task_dispatch_queued")


if __name__ == "__main__":
    unittest.main()
