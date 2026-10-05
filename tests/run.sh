#!/bin/bash
# Pins down how Xcode treats a failing scheme pre-action and proves the fix.
#
#   tests/run.sh            run everything (shell checks + xcodebuild checks)
#   tests/run.sh --shell    only the plain-shell checks (no Xcode needed)
#
# xcodebuild output goes to files under a temp dir, not to the console:
# for scheme actions xcodebuild echoes every exported environment variable,
# which would put your whole environment (tokens included) into the log.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$ROOT"

pass=0; fail=0
ok()   { echo "PASS  $1"; pass=$((pass + 1)); }
bad()  { echo "FAIL  $1"; fail=$((fail + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# ---------------------------------------------------------------- shell checks
# Run a script exactly as a terminal/CI would: no SCHEME_ACTION_NAME.
cli() { env -u SCHEME_ACTION_NAME -u SCHEME_NAME "$@"; }

echo "== shell checks"

# The naive script refuses to run without the flag (the behaviour that broke the build).
cli scripts/prebuild_naive.sh > "$WORK/o" 2>&1; rc=$?
check "test_naive_cli_without_flag_exits_1" '[ $rc -eq 1 ] && grep -q "is required" "$WORK/o"'

# The fixed script keeps that hard error for command-line callers.
cli scripts/prebuild_fixed.sh > "$WORK/o" 2>&1; rc=$?
check "test_fixed_cli_without_flag_still_exits_1" '[ $rc -eq 1 ] && grep -q "is required" "$WORK/o"'

# Inside a scheme action (SCHEME_ACTION_NAME set) it warns, exits 0 and does no setup work.
rm -f "$WORK/marker"
SCHEME_ACTION_NAME="Run Script" SETUP_MARKER="$WORK/marker" scripts/prebuild_fixed.sh > "$WORK/o" 2>&1; rc=$?
check "test_fixed_scheme_action_without_flag_warns_and_exits_0" '[ $rc -eq 0 ] && grep -q "^warning:" "$WORK/o" && [ ! -e "$WORK/marker" ]'

# With the flag, both versions do the real setup.
for v in naive fixed; do
  rm -f "$WORK/marker"
  cli env SETUP_MARKER="$WORK/marker" "scripts/prebuild_$v.sh" --resources-branch main > "$WORK/o" 2>&1; rc=$?
  check "test_${v}_cli_with_flag_runs_setup" '[ $rc -eq 0 ] && [ "$(cat "$WORK/marker" 2>/dev/null)" = main ]'
done

if [ "${1:-}" = "--shell" ]; then
  echo "== $pass passed, $fail failed"; [ $fail -eq 0 ]; exit
fi

# ------------------------------------------------------------ xcodebuild checks
XCODE_VERSION="$(xcodebuild -version | awk 'NR==1{print $2}')"
echo "== xcodebuild checks (Xcode $XCODE_VERSION)"

build() { # scheme -> sets rc; log in $WORK/<scheme>.log
  xcodebuild -scheme "$1" -destination 'generic/platform=macOS' \
    -derivedDataPath "$WORK/dd" build > "$WORK/$1.log" 2>&1
  rc=$?
}
summary() { grep -E 'BUILD (SUCCEEDED|FAILED)|Run custom shell script|^error:' "$WORK/$1.log" | sed 's/^/        /'; }

# (b) Xcode exports SCHEME_ACTION_NAME (the action's title) to pre-action scripts.
export PROBE_OUT="$WORK/probe.txt"
build EnvProbe
check "test_scheme_action_sees_SCHEME_ACTION_NAME" '[ $rc -eq 0 ] && grep -qx "SCHEME_ACTION_NAME=Project setup" "$PROBE_OUT"'
sed 's/^/        /' "$PROBE_OUT" 2>/dev/null
# xcodebuild does echo a pre-action's stdout (the Xcode IDE build log does not).
check "test_xcodebuild_log_contains_pre_action_stdout" 'grep -q PREACTION_STDOUT_MARKER "$WORK/EnvProbe.log"'

# (a) The naive pre-action exits 1 because the scheme never passes the flag.
export PREBUILD_LOG="$WORK/naive-prebuild.log"
build Naive; summary Naive
# xcodebuild fails the build when a pre-action exits non-zero. Observed on
# Xcode 15.4, 16.0, 16.4, 26.0.1, 26.6 and 27.0.
check "test_naive_pre_action_fails_the_build" \
  '[ $rc -ne 0 ] && grep -q "Run custom shell script '"'"'Project setup'"'"'" "$WORK/Naive.log"'
check "test_naive_pre_action_error_went_to_redirected_log" 'grep -q "is required" "$PREBUILD_LOG"'

# The fixed pre-action detects the scheme action, warns and lets the build continue.
export PREBUILD_LOG="$WORK/fixed-prebuild.log"
export SETUP_MARKER="$WORK/marker"; rm -f "$SETUP_MARKER"
build Fixed; summary Fixed
check "test_fixed_pre_action_build_succeeds" '[ $rc -eq 0 ]'
check "test_fixed_pre_action_skipped_setup_with_warning" 'grep -q "^warning:" "$PREBUILD_LOG" && [ ! -e "$SETUP_MARKER" ]'

echo "== $pass passed, $fail failed (Xcode $XCODE_VERSION)"
[ $fail -eq 0 ]
