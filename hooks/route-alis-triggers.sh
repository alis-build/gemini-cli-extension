#!/usr/bin/env bash
# BeforeAgent hook: keep the Alis Build routing contract in front of the model
# once the user has engaged Alis, and load the Define->Build->Deploy primer on
# the engaging turn.
#
# BeforeAgent is Gemini CLI's user-prompt-submit event: it fires after the user
# submits a prompt and before agent planning. The payload (JSON on stdin)
# carries the prompt text in `.prompt` and the session in `.session_id`.
#
# Why "sticky": a hook injects per-turn, not as a standing instruction, so a
# routing contract injected once on "alis, ..." goes stale and later build/fix
# requests (often phrased without any trigger word, e.g. "could you help adding
# tracing?") get treated as plain coding tasks. So:
#
#   * vocative "alis" (e.g. "alis, ...", "ask alis to ...") -> inject the DBD
#     primer AND the routing contract, and mark this session as Alis-engaged.
#   * any later turn in an Alis-engaged session -> re-inject the routing contract
#     only (no primer), so follow-up build/fix/help requests route through
#     SearchSkills instead of going straight to code.
#   * sessions where the user never addressed Alis -> inject nothing.
#
# The routing contract is self-scoping (it only activates the router for
# build/fix-shaped Alis Build requests), and reinforces GEMINI.md's standing
# rule. Not gated on an ~/alis.build workspace.
#
# Unlike Claude Code / Codex (which append a hook's raw stdout to context),
# Gemini CLI requires the only stdout to be a single JSON object. The context is
# therefore delivered via hookSpecificOutput.additionalContext.
set -euo pipefail

# jq is used both to parse the prompt and to emit valid JSON. Without it, inject
# nothing and exit cleanly so the prompt proceeds unmodified.
command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"
prompt="$(printf '%s' "$payload" | jq -r '.prompt // empty' 2>/dev/null || true)"
[ -n "$prompt" ] || exit 0

# Lowercase for case-insensitive matching.
lc="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"

# Vocative "Alis" (addressing the agent), e.g. "alis,", "alis:", "hey alis",
# "ask alis", "alis please/could/can/help ...". Deliberately does NOT match bare
# platform mentions like "Use Alis Build to list landing zones".
alis_vocative='(^|[^[:alnum:]])alis[[:space:]]*[,:]|(^|[^[:alnum:]])(hey|hi|ask)[[:space:]]+alis([^[:alnum:]]|$)|(^|[^[:alnum:]])alis[[:space:]]+(please|pls|could|can|would|will|help)([^[:alnum:]]|$)'

# Per-session marker so the routing contract stays sticky after the first "alis".
session_id="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)"
marker=""
if [ -n "$session_id" ]; then
  safe="$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9._-')"
  [ -n "$safe" ] && marker="${TMPDIR:-/tmp}/alis-routing/${safe}"
fi

emit_primer=false
if printf '%s' "$lc" | grep -Eq "$alis_vocative"; then
  emit_primer=true
  if [ -n "$marker" ]; then
    mkdir -p "$(dirname "$marker")" 2>/dev/null || true
    : > "$marker" 2>/dev/null || true
  fi
elif [ -n "$marker" ] && [ -f "$marker" ]; then
  emit_primer=false
else
  exit 0
fi

# Resolve the extension root: prefer the substituted env var, else derive from
# this script's location (hooks/ -> extension root).
ext_root="${extensionPath:-$(cd "$(dirname "$0")/.." && pwd)}"
primer=""
if $emit_primer; then
  primer="$(cat "${ext_root}/context/dbd-primer.md" 2>/dev/null || true)"
fi

read -r -d '' routing <<'EOF' || true
<alis-routing>
Alis Build routing contract — the user has engaged Alis this session. Keep this
in mind for this and the following turns:

- "build it" / "fix it", or any request to build, fix, add, or change something
  on the Alis Build platform — including naturally phrased asks like "could you
  help add X to my server?" — → treat as a ROUTER, not a direct task. Work out
  the intended outcome (ask ONE concise question only if it is genuinely
  ambiguous), then call the Alis Build MCP `SearchSkills` tool FIRST with that
  outcome as the query (fall back to `ListSkills` if it returns nothing). Present
  the matching skills (id, what each does, when to choose it), ask which to use,
  and only then call `LoadSkill` and follow that skill's workflow — the loaded
  skill owns execution. Do NOT inspect, write, or edit code, run
  Define / Build / Deploy, or make commits before a skill is loaded. If no skill
  fits, say so and offer `RequestSkill`.

- "spec it" / "spec it up", or a request to turn the current session into a build
  specification → call the `SpecIt` tool DIRECTLY. Do NOT route this through
  SearchSkills. It needs no arguments (session context is resolved server-side);
  pass `build_spec` only when the user names an existing one to append to. Report
  the returned BuildSpec back to the user.
</alis-routing>
EOF

# DBD framing first (the mental model), then the actionable routing contract.
context="${primer:+$primer

}${routing}"

jq -n --arg c "$context" \
  '{hookSpecificOutput: {hookEventName: "BeforeAgent", additionalContext: $c}}'
