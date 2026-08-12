#!/usr/bin/env bash
# SessionStart hook: refresh catalog metadata only. --cache-only is explicit
# for compatibility with older alis CLIs whose default sync installed native
# harness skills. Detached, silent, and fail-open.
cat >/dev/null 2>&1 || true
command -v alis >/dev/null 2>&1 || exit 0
(alis skills sync --cache-only >/dev/null 2>&1 &)
exit 0
