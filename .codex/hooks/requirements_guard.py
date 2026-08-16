#!/usr/bin/env python3
"""Deny worker file-edit tools that target Product Manager owned sources."""
import json, os, sys
try: payload=json.load(sys.stdin)
except Exception: raise SystemExit(0)
role=os.environ.get("FACTORY_ROLE","")
if role not in {"builder","tester","web-tester"}: raise SystemExit(0)
command=str(payload.get("tool_input",{}).get("command",""))
protected=("docs/product/", "docs/architecture/")
if any(path in command for path in protected):
    print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":f"{role} agents may reference but never edit Product Manager truth or the technical roadmap."}}))
