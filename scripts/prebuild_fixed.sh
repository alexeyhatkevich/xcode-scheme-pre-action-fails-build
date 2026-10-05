#!/bin/bash
# Project setup script, FIXED version.
#
# Usage: scripts/prebuild_fixed.sh --resources-branch <name>
#
# Same contract as prebuild_naive.sh for command-line callers (missing flag =
# hard error), but when Xcode runs it as a scheme pre/post-action it warns and
# exits 0 instead of breaking the build.
set -euo pipefail

branch=""
while [ $# -gt 0 ]; do
  case "$1" in
    --resources-branch) branch="${2:-}"; shift 2 ;;
    *) echo "error: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$branch" ]; then
  # Xcode exports SCHEME_ACTION_NAME (set to the action's title, e.g.
  # "Run Script") to every scheme pre/post-action script. A terminal or CI
  # job calling this script directly does not have it.
  if [ -n "${SCHEME_ACTION_NAME:-}" ]; then
    echo "warning: '$SCHEME_ACTION_NAME' in scheme '${SCHEME_NAME:-?}' ran without --resources-branch; skipping project setup."
    exit 0
  fi
  echo "error: --resources-branch is required" >&2
  exit 1
fi

echo "setup: preparing project with resources from '$branch'"
if [ -n "${SETUP_MARKER:-}" ]; then echo "$branch" > "$SETUP_MARKER"; fi
