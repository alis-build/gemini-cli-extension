#!/usr/bin/env bash
# BeforeAgent hook: when the user addresses Alis (a vocative "alis, ..."), inject
# the Define->Build->Deploy primer and the Alis Build routing contract.
#
# BeforeAgent is Gemini CLI's user-prompt-submit event: it fires after the user
# submits a prompt and before agent planning. The payload (JSON on stdin)
# carries the prompt text in `.prompt`.
#
# We inject ONLY when the user addresses Alis — "alis" is the explicit trigger
# word. The injected contract tells the model to keep routing build/fix work
# through SearchSkills for the rest of the session (reinforcing GEMINI.md's
# standing rule), so the user need not repeat "alis" every turn; but no context
# is injected on turns that do not address Alis. Vocative "alis" matches anywhere
# in the prompt (e.g. "could you help add X, alis?"). Not gated on an
# ~/alis.build workspace.
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
alis_vocative='(^|[^[:alnum:]])alis[[:space:]]*[,:]|(^|[^[:alnum:]])(hey|hi|ask)[[:space:]]+alis([^[:alnum:]]|$)|(^|[^[:alnum:]])alis[[:space:]]+(please|pls|could|can|would|will|help)([^[:alnum:]]|$)|,[[:space:]]*alis[[:space:]]*[?!.]*$|[[:space:]]alis[[:space:]]*[?!]'

printf '%s' "$lc" | grep -Eq "$alis_vocative" || exit 0

# Resolve the extension root: prefer the substituted env var, else derive from
# this script's location (hooks/ -> extension root).
ext_root="${extensionPath:-$(cd "$(dirname "$0")/.." && pwd)}"
primer="$(cat "${ext_root}/context/dbd-primer.md" 2>/dev/null || true)"

read -r -d '' routing <<'EOF' || true
<alis-routing>
Alis Build routing contract — the user has engaged Alis. Keep this in mind for
this and the following turns of the session, even if they do not say "alis"
again:

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

- A capability question about buildable Alis Build work (e.g. "can you help with
  tracing?", "are you able to add X?") rather than a concrete request → briefly
  confirm this is Alis Build work, then ask the user to state the specific change
  they want so you can route it through SearchSkills. Do NOT dive into the
  codebase or give a generic how-to before they name the concrete change.

- "spec it" / "spec it up", or a request to turn the current session into a build
  specification → call the `SpecIt` tool DIRECTLY. Do NOT route this through
  SearchSkills. It needs no arguments (session context is resolved server-side);
  pass `build_spec` only when the user names an existing one to append to. Report
  the returned BuildSpec back to the user.

Whenever a later request in this session would benefit from an Alis Build skill,
use `SearchSkills` to discover one before doing the work yourself.
</alis-routing>
EOF

# DBD framing first (the mental model), then the actionable routing contract.
context="${primer:+$primer

}${routing}"

jq -n --arg c "$context" \
  '{hookSpecificOutput: {hookEventName: "BeforeAgent", additionalContext: $c}}'
