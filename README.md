# Xcode 26+: a failing scheme pre-action fails the build

Minimal reproduction of a build break that appears when you upgrade to Xcode 26:
a shared scheme has a **Build pre-action** that calls a project setup script, the
script exits non-zero, and the whole scheme stops building. Older Xcode versions
logged the failing pre-action and carried on, so the problem can sit unnoticed
for a long time.

## What's in here

| Path | What it is |
| --- | --- |
| `Package.swift`, `Sources/Greeter` | A trivial library, just something to build |
| `.swiftpm/xcode/xcshareddata/xcschemes/Naive.xcscheme` | Build pre-action calls `scripts/prebuild_naive.sh` without the flag it requires |
| `.swiftpm/xcode/xcshareddata/xcschemes/Fixed.xcscheme` | Same pre-action, but calls `scripts/prebuild_fixed.sh` |
| `.swiftpm/xcode/xcshareddata/xcschemes/EnvProbe.xcscheme` | Pre-action that records `SCHEME_ACTION_NAME` / `SCHEME_NAME` |
| `scripts/prebuild_naive.sh` | Setup script: `--resources-branch` missing = `exit 1` |
| `scripts/prebuild_fixed.sh` | Same, but when `SCHEME_ACTION_NAME` is set (Xcode scheme action) it warns and exits 0 |
| `tests/run.sh` | Shell checks + `xcodebuild` checks for all three schemes |

## The fix in one block

```bash
if [ -z "$branch" ]; then
  # Xcode exports SCHEME_ACTION_NAME to scheme pre/post-action scripts.
  if [ -n "${SCHEME_ACTION_NAME:-}" ]; then
    echo "warning: '$SCHEME_ACTION_NAME' ran without --resources-branch; skipping project setup."
    exit 0
  fi
  echo "error: --resources-branch is required" >&2
  exit 1
fi
```

Command-line and CI callers still get the hard error; the Xcode build no longer
dies. Passing the flag from the scheme would also "fix" it, but then the full
setup job (re-cloning resources, `pod install`, wiping DerivedData, ...) runs at
the start of every build.

Note: `SCHEME_ACTION_NAME` holds the **title of the action** as shown in the
scheme editor (`Run Script` by default, `Project setup` in this repo), not the
name of the scheme phase. Test it for "non-empty", not for a specific value.

## Running the tests

```bash
tests/run.sh           # shell checks + xcodebuild checks (needs Xcode)
tests/run.sh --shell   # shell checks only
```

`tests/run.sh` keeps `xcodebuild` output in a temp directory instead of printing it:
for scheme actions `xcodebuild` echoes every exported environment variable of the
script, so the raw log contains your whole environment, tokens included.

## Verified on

- Xcode 27.0 (27A266a), macOS, locally: naive scheme fails with
  `The following build commands failed: Run custom shell script 'Project setup'`
  (exit code 65); fixed scheme builds; `SCHEME_ACTION_NAME=Project setup` inside the pre-action.
- CI (`.github/workflows/ci.yml`): see the latest run for the Xcode versions on the
  GitHub-hosted runners.

## Two more gotchas

- **Editing the `.xcscheme` on disk while Xcode has the project open does not
  stick.** Xcode keeps its own copy in memory and writes it back, silently
  reverting your edit. Edit via *Product > Scheme > Edit Scheme...*, close the
  project first, or change the script the pre-action calls instead.
- **Pre-action output is not in the Xcode build log.** Redirect it yourself at the
  top of the pre-action: `exec > /tmp/prebuild.log 2>&1`. (`xcodebuild` on the
  command line does echo it.)

## License

MIT

Write-up: https://alexeyhatkevich.blogspot.com
