#!/usr/bin/env python3
"""Deny worker file-edit tools that target Product Manager owned sources."""
import json, os, sys
try: payload=json.load(sys.stdin)
except Exception: raise SystemExit(0)
role=os.environ.get("FACTORY_ROLE","")
if role not in {"builder","tester","web-tester"}: raise SystemExit(0)
tool_input=payload.get("tool_input",{})
# Inspect all edit-tool fields. apply_patch uses a patch field, while file tools use path fields.
edit_request=json.dumps(tool_input, sort_keys=True)
protected=("docs/product/", "docs/architecture/")
if any(path in edit_request.replace("\\\\", "/") for path in protected):
    print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":f"{role} agents may reference but never edit Product Manager truth or the technical roadmap."}}))
