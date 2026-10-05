# A failing Xcode scheme pre-action fails the build

Minimal reproduction of a build break: a shared scheme has a **Build pre-action**
that calls a project setup script, the script exits non-zero, and the whole scheme
stops building.

How it was found: the scheme kept building in the IDE of older Xcode versions while
its pre-action was failing, and it broke for everyone after moving to Xcode 26. The CI
matrix here shows that **`xcodebuild` already fails the build on a failing
pre-action in every version tested, from Xcode 15.4 to 27.0**, so the IDE side is
where the behaviour changed (not reproduced here: IDE builds can't be automated
in CI). Either way, the safe assumption today is: a non-zero pre-action = a failed
build.

## How to run

1. Open `Demo/Demo.xcodeproj` in Xcode 15+ (it uses this package as a local dependency).
2. Pick the **Demo** scheme and any iPhone simulator, then press **⌘R**. In the app,
   switch **Naive / Fixed** and **Xcode pre-action / Terminal / CI**: Naive called as
   an Xcode pre-action exits 1 = **BUILD FAILED**; Fixed warns and exits 0 =
   **BUILD SUCCEEDED**; from a terminal both still fail without the flag.
3. See the real thing: build the **Demo-Naive** scheme (fails with
   `Run custom shell script 'Project setup'`), then **Demo-Fixed** (builds; the
   pre-action output with the warning is in `/tmp/demo-prebuild.log`).
4. **⌘U** on the Demo scheme runs the package tests (`GreeterTests`). On the iOS
   simulator the test that executes the real shell scripts is skipped.
5. `swift test` works too (the package is plain Swift, no UIKit) and runs all
   tests on macOS, including the one that runs `scripts/prebuild_*.sh`.
   `tests/run.sh` is still the full check with the SwiftPM schemes below.

`Demo/project.yml` is the XcodeGen spec the project was generated from
(`cd Demo && xcodegen generate`).

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
| `Sources/Greeter/PreActionScript.swift`, `tests/GreeterTests` | Swift model of the two scripts + XCTests (checked against the real scripts on macOS) |
| `Demo/` | iOS demo app; schemes `Demo` (no pre-action), `Demo-Naive`, `Demo-Fixed` |

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
- CI (`.github/workflows/ci.yml`), same results on GitHub-hosted runners with
  Xcode 15.4, 16.0, 16.4, 26.0.1 and 26.6: the naive scheme fails, the fixed scheme
  builds, `SCHEME_ACTION_NAME` is the action title.
- Not verified here: the Xcode IDE behaviour (failing pre-action not stopping the
  build in the IDE of older Xcode versions) and the `.xcscheme` overwrite below; both are from day-to-day use.

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
