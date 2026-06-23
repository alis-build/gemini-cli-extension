#!/usr/bin/env bash
# BeforeAgent hook: when the user addresses Alis (a vocative "alis, ..."), inject
# the Define->Build->Deploy primer and the Alis Build routing contract into the
# session context.
#
# BeforeAgent is Gemini CLI's user-prompt-submit event: it fires after the user
# submits a prompt and before agent planning. The payload (JSON on stdin)
# carries the prompt text in `.prompt`.
#
# Trigger: only a vocative "alis" (e.g. "alis, ...", "ask alis to ..."). Bare
# "build it" / "fix it" / "spec it" deliberately do NOT re-trigger injection —
# the contract injected on the first "alis, ..." (plus GEMINI.md's standing
# rule) already explains how to handle them on this and the following turns. The
# routing block reinforces GEMINI.md at exactly the moment it matters, with a
# hard "do not edit code" directive, and is NOT gated on an ~/alis.build
# workspace.
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

printf '%s' "$lc" | grep -Eq "$alis_vocative" || exit 0

# Resolve the extension root: prefer the substituted env var, else derive from
# this script's location (hooks/ -> extension root).
ext_root="${extensionPath:-$(cd "$(dirname "$0")/.." && pwd)}"
primer="$(cat "${ext_root}/context/dbd-primer.md" 2>/dev/null || true)"

read -r -d '' routing <<'EOF' || true
<alis-routing>
The user addressed Alis. Keep this routing contract in mind for this and the
following turns:

- "build it" / "fix it", or any request to build or fix something on the Alis
  Build platform without naming a specific workflow → treat as a ROUTER, not a
  direct task. Work out the intended outcome (ask ONE concise question only if
  it is genuinely ambiguous), then call the Alis Build MCP `SearchSkills` tool
  FIRST with that outcome as the query (fall back to `ListSkills` if it returns
  nothing). Present the matching skills (id, what each does, when to choose it),
  ask which to use, and only then call `LoadSkill` and follow that skill's
  workflow — the loaded skill owns execution. Do NOT inspect, write, or edit
  code, run Define / Build / Deploy, or make commits from this router step. If
  no skill fits, say so and offer `RequestSkill`.

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
