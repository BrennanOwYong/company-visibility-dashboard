#!/usr/bin/env python3
"""Idempotent, project-local Codex factory bootstrap and startup context."""

from __future__ import annotations

import json
import os
import subprocess
import tomllib
from pathlib import Path


def git_root() -> Path:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        check=True,
        capture_output=True,
        text=True,
    )
    return Path(result.stdout.strip())


def ensure_layout(root: Path) -> None:
    directories = [
        ".factory/runtime/agents",
        ".factory/runtime/inbox",
        ".factory/runtime/locks",
        ".factory/runtime/ports",
        ".factory/events",
        "docs/product/features",
        "docs/product/decisions",
        "docs/architecture/modules",
        "docs/architecture/contracts/api",
        "docs/architecture/contracts/events",
        "docs/architecture/contracts/interfaces",
        "docs/architecture/decisions",
        "docs/delivery/tickets",
        "docs/delivery/audits",
        "docs/delivery/aars",
        "docs/delivery/improvement-candidates",
        "kanban",
    ]
    for directory in directories:
        (root / directory).mkdir(parents=True, exist_ok=True)


def worker_context(root: Path, role: str, ticket: str, project_root: str) -> str:
    role_file = Path(project_root) / ".codex" / "agents" / f"factory-{role}.toml"
    instructions = ""
    if role_file.is_file():
        instructions = tomllib.loads(role_file.read_text(encoding="utf-8")).get(
            "developer_instructions", ""
        ).strip()
    manifest_path = Path(project_root) / ".factory" / "runtime" / "contexts" / (
        os.environ.get("FACTORY_AGENT", "") + ".json"
    )
    manifest = ""
    if manifest_path.is_file():
        manifest = manifest_path.read_text(encoding="utf-8").strip()
    return (
        f"FACTORY WORKER role={role} ticket={ticket}. Canonical project root: {project_root}. "
        "Do not initialize a factory or act as the coordinator. "
        f"ROLE RULES:\n{instructions}\nTICKET CONTEXT:\n{manifest}"
    )


def startup_context(root: Path) -> str:
    role = os.environ.get("FACTORY_ROLE", "")
    ticket = os.environ.get("FACTORY_TICKET", "")
    project_root = os.environ.get("FACTORY_PROJECT_ROOT", "")
    if role:
        return worker_context(root, role, ticket, project_root or str(root))
    config = root / ".factory/project.json"
    if not config.exists():
        return (
            "FACTORY SETUP REQUIRED. Ask the user for the GitHub repository URL that will store "
            "this product. Then run bin/factory-bootstrap <github-url>. Do not gather product "
            "requirements until bootstrap succeeds. All factory state is project-local."
        )
    data = json.loads(config.read_text(encoding="utf-8"))
    remote = data.get("github", "")
    return (
        f"FACTORY ACTIVE for {root.name}. Product repository: {remote}. Read AGENTS.md, "
        "docs/architecture/roadmap.json, and current product feature documents before acting. Use only "
        "project-local .factory state. Build the kanban DAG with bin/roadmap-sync; never infer "
        "dependency edges agentically."
    )


def register_coordinator(root: Path) -> None:
    """Record the exact tmux session for deterministic main-agent notifications."""
    if not os.environ.get("TMUX"):
        return
    result = subprocess.run(
        ["tmux", "display-message", "-p", "#S"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode == 0 and result.stdout.strip():
        (root / ".factory/runtime/coordinator").write_text(
            result.stdout.strip() + "\n", encoding="utf-8"
        )


def ensure_ui(root: Path) -> str:
    if not (root / ".factory/project.json").exists():
        return ""
    command = root / "bin/factory-ui"
    if not command.exists():
        return ""
    result = subprocess.run([str(command), "start"], cwd=root, capture_output=True, text=True, check=False)
    return result.stdout.strip() if result.returncode == 0 else ""


def main() -> None:
    root = git_root()
    role = os.environ.get("FACTORY_ROLE", "")
    agent = os.environ.get("FACTORY_AGENT", "")
    project_root = Path(os.environ.get("FACTORY_PROJECT_ROOT", str(root)))
    if role and agent:
        state = project_root / ".factory" / "runtime" / "agents" / f"{agent}.state"
        ready = project_root / ".factory" / "runtime" / "agents" / f"{agent}.ready"
        state.parent.mkdir(parents=True, exist_ok=True)
        state.write_text("idle\n", encoding="utf-8")
        ready.write_text("ready\n", encoding="utf-8")
    if not os.environ.get("FACTORY_ROLE"):
        ensure_layout(root)
        register_coordinator(root)
    ui_url = "" if os.environ.get("FACTORY_ROLE") else ensure_ui(root)
    print(
        json.dumps(
            {
                "continue": True,
                "hookSpecificOutput": {
                    "hookEventName": "SessionStart",
                    "additionalContext": startup_context(root) + (f" Project control UI: {ui_url}." if ui_url else ""),
                },
            }
        )
    )


if __name__ == "__main__":
    main()
