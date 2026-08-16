#!/usr/bin/env python3
"""Maintain project-local agent readiness for the durable message bus."""

from __future__ import annotations

import json
import os
from pathlib import Path


def main() -> None:
    event = json.load(__import__("sys").stdin)
    agent = os.environ.get("FACTORY_AGENT", "")
    root = os.environ.get("KANBAN_PROJECT_ROOT", "")
    if not agent or not root:
        print(json.dumps({"continue": True, "suppressOutput": True}))
        return
    state = "idle" if event.get("hook_event_name") in {"Stop", "SubagentStop"} else "busy"
    path = Path(root) / ".factory/runtime/agents" / f"{agent}.state"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(state + "\n", encoding="utf-8")
    print(json.dumps({"continue": True, "suppressOutput": True}))


if __name__ == "__main__":
    main()

