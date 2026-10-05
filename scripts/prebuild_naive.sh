#!/bin/bash
# Project setup script, NAIVE version.
#
# Usage: scripts/prebuild_naive.sh --resources-branch <name>
#
# Requires --resources-branch and fails hard without it. That is fine for a
# human on the command line, but this script is also wired into the shared
# scheme as a Build pre-action that never passes the flag. Up to Xcode 16 the
# failure was only logged; since Xcode 26 it aborts every build of the scheme.
set -euo pipefail

branch=""
while [ $# -gt 0 ]; do
  case "$1" in
    --resources-branch) branch="${2:-}"; shift 2 ;;
    *) echo "error: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$branch" ]; then
  echo "error: --resources-branch is required" >&2
  exit 1
fi

# Stand-in for the expensive part (re-cloning resources, pod install,
# wiping DerivedData, ...). Here it only leaves a marker so tests can see it ran.
echo "setup: preparing project with resources from '$branch'"
if [ -n "${SETUP_MARKER:-}" ]; then echo "$branch" > "$SETUP_MARKER"; fi
