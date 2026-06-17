#!/usr/bin/env bash
# SessionStart hook: inject the Alis Build DBD primer into the session, but only for
# sessions working inside an Alis Build workspace (~/alis.build/...).
#
# Unlike Claude Code (which appends a hook's raw stdout to context), Gemini CLI
# requires the only stdout to be a single JSON object. The primer text is therefore
# delivered via hookSpecificOutput.additionalContext.
set -euo pipefail

# Gemini sets GEMINI_PROJECT_DIR for hooks (and a CLAUDE_PROJECT_DIR alias); fall back
# to the current directory.
project_dir="${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}}"

# Resolve the extension root: prefer the substituted env var, else derive from this
# script's location (hooks/ -> extension root).
ext_root="${extensionPath:-$(cd "$(dirname "$0")/.." && pwd)}"

case "$project_dir" in
  */alis.build | */alis.build/*)
    # jq is used to emit valid JSON. Without it, inject nothing and exit cleanly.
    if command -v jq >/dev/null 2>&1; then
      primer="$(cat "${ext_root}/context/dbd-primer.md")"
      jq -n --arg c "$primer" \
        '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
    fi
    ;;
  *)
    # Not an Alis Build workspace: inject nothing.
    :
    ;;
esac
