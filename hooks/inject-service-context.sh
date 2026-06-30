#!/usr/bin/env bash
# SessionStart hook (Gemini CLI): when a session opens inside an Alis Build
# workspace (~/alis.build/<org>/{build,define}/...), inject a short pointer to
# the service's counterpart half — definitions (protobuf API contract) when on
# the build side, implementation when on the define side — plus the package id.
#
# Layout (verified): build  = <root>/alis.build/<org>/build/<path...>
#                     define = <root>/alis.build/<org>/define/<org>/<path...>
# Package id          = <org>.<path-with-/-as-.>   (e.g. alis.os.cli.v1)
#
# Gemini CLI requires a hook to print a single JSON object; injected context is
# delivered via hookSpecificOutput.additionalContext. The working directory is
# read from GEMINI_PROJECT_DIR (falling back to $PWD). Any non-match — or a
# missing jq — emits nothing and exits 0 so the session proceeds unmodified.
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

dir="${GEMINI_PROJECT_DIR:-$PWD}"
case "$dir" in */alis.build/*) ;; *) exit 0 ;; esac

root="${dir%%/alis.build/*}/alis.build"
rest="${dir#*/alis.build/}"

IFS='/' read -ra parts <<< "$rest"
org="${parts[0]:-}"; side="${parts[1]:-}"
[ -n "$org" ] && [ -n "$side" ] || exit 0

# Path segments below the side (and below the nested <org> on the define side).
segs=()
case "$side" in
  build)  segs=("${parts[@]:2}") ;;
  define) [ "${parts[2]:-}" = "$org" ] || exit 0   # skip vendored google/lf symlinks
          segs=("${parts[@]:3}") ;;
  *)      exit 0 ;;
esac

# Resolve up to the service version (vN) root; drop empty segments.
# The ${arr[@]+"${arr[@]}"} form expands to nothing for an empty array, which
# bash 3.2 (macOS) otherwise rejects under `set -u`.
svc=(); found_version=0
for s in ${segs[@]+"${segs[@]}"}; do
  [ -n "$s" ] || continue
  svc+=("$s")
  if [[ "$s" =~ ^v[0-9]+$ ]]; then found_version=1; break; fi
done
[ "${#svc[@]}" -gt 0 ] || exit 0   # at org/side root → nothing specific to say

join() { local IFS="$1"; shift; printf '%s' "$*"; }
relpath="$(join / "${svc[@]}")"
definedir="$root/$org/define/$org/$relpath"
builddir="$root/$org/build/$relpath"
pkg=""; [ "$found_version" -eq 1 ] && pkg="$org.$(join . "${svc[@]}")"

ctx=""
add() { ctx="${ctx}${1}"$'\n'; }

add_protos() {  # append top-level *.proto basenames in $1, if any
  local d="$1" f names=() out
  for f in "$d"/*.proto; do [ -e "$f" ] && names+=("$(basename "$f")"); done
  if [ "${#names[@]}" -gt 0 ]; then
    printf -v out '%s, ' "${names[@]}"
    add "  Proto files: ${out%, }"
  fi
}

if [ "$side" = "build" ]; then
  add "This Gemini session is inside an Alis Build service implementation (build) directory."
  [ -n "$pkg" ] && add "  Package id:  $pkg"
  if [ -d "$definedir" ]; then
    add "  The protobuf definitions (the API contract — the DBD \"Define\" step) are available here:"
    add "    $definedir"
    add_protos "$definedir"
  else
    add "  Expected definitions at $definedir (not found on disk)."
  fi
else  # define side
  add "This Gemini session is inside an Alis Build definitions (define) directory — the protobuf API contract."
  [ -n "$pkg" ] && add "  Package id:  $pkg"
  add_protos "$dir"
  if [ -d "$builddir" ]; then
    add "  The implementation (the DBD \"Build\" step) is available here:"
    add "    $builddir"
  else
    add "  This contract has no corresponding build/ implementation directory yet."
  fi
fi

jq -n --arg c "$ctx" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
exit 0
