#!/usr/bin/env bash
# BeforeTool hook: inject the Gemini session_id into Alis MCP LoadSkill calls so the
# server can resolve the caller's active Context and prepend an <alis-runtime-context>
# block to the returned skill.
#
# Gemini CLI does not pass its session_id to MCP servers by default. A BeforeTool hook,
# however, receives session_id on stdin and may rewrite the outgoing tool arguments via
# hookSpecificOutput.tool_input, which merges with and overrides the model's arguments
# before execution. This merges the session_id into LoadSkill's arguments (the
# session_id field on the MCP LoadSkillRequest); the model never supplies it.
#
# Reads the hook payload (JSON) on stdin and writes the hook response to stdout.
set -euo pipefail

# jq rewrites the payload. Without it, emit nothing and exit 0 so the tool call
# proceeds unmodified (the skill falls back to its own in-markdown discovery).
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

exec jq -c '{
  hookSpecificOutput: {
    hookEventName: "BeforeTool",
    tool_input: (.tool_input + { session_id: .session_id })
  }
}'
