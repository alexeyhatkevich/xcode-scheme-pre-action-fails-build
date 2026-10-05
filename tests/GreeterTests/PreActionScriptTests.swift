import XCTest
@testable import Greeter

final class PreActionScriptTests: XCTestCase {
    // The bug: the scheme pre-action never passes the flag, the naive script
    // exits 1, and a non-zero pre-action fails the whole build.
    func test_naive_scheme_pre_action_without_flag_fails_the_build() {
        let out = PreActionScript.naive.run(resourcesBranch: nil, caller: .xcodeSchemePreAction)
        XCTAssertEqual(out.exitCode, 1)
        XCTAssertTrue(out.failsTheBuild)
        XCTAssertTrue(out.output.contains("is required"))
    }

    // The fix: same call, but the script sees SCHEME_ACTION_NAME, warns and exits 0.
    func test_fixed_scheme_pre_action_without_flag_warns_and_build_continues() {
        let out = PreActionScript.fixed.run(resourcesBranch: nil, caller: .xcodeSchemePreAction)
        XCTAssertEqual(out.exitCode, 0)
        XCTAssertFalse(out.failsTheBuild)
        XCTAssertFalse(out.ranSetup)
        XCTAssertTrue(out.output.hasPrefix("warning:"))
    }

    // Command-line / CI callers still get the hard error from both versions.
    func test_command_line_without_flag_is_still_an_error() {
        for script in PreActionScript.allCases {
            let out = script.run(resourcesBranch: nil, caller: .commandLine)
            XCTAssertEqual(out.exitCode, 1, "\(script)")
        }
    }

    // An empty SCHEME_ACTION_NAME does not count as a scheme action.
    func test_fixed_treats_empty_scheme_action_name_as_command_line() {
        let out = PreActionScript.fixed.run(resourcesBranch: nil, environment: ["SCHEME_ACTION_NAME": ""])
        XCTAssertEqual(out.exitCode, 1)
    }

    func test_with_flag_both_versions_run_setup() {
        for script in PreActionScript.allCases {
            for caller in PreActionScript.Caller.allCases {
                let out = script.run(resourcesBranch: "main", caller: caller)
                XCTAssertEqual(out.exitCode, 0)
                XCTAssertTrue(out.ranSetup)
            }
        }
    }

    // Keeps the Swift model honest: runs the real scripts (macOS only; an iOS
    // simulator test can't spawn processes).
    func test_model_matches_real_scripts() throws {
        #if os(macOS)
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for script in PreActionScript.allCases {
            for caller in PreActionScript.Caller.allCases {
                for branch in [nil, "main"] as [String?] {
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/bin/bash")
                    p.arguments = [root.appendingPathComponent(script.fileName).path]
                        + (branch.map { ["--resources-branch", $0] } ?? [])
                    var env = ProcessInfo.processInfo.environment
                    env["SCHEME_ACTION_NAME"] = nil
                    env["SCHEME_NAME"] = nil
                    env["SETUP_MARKER"] = nil
                    env.merge(caller.environment) { $1 }
                    p.environment = env
                    p.standardOutput = FileHandle.nullDevice
                    p.standardError = FileHandle.nullDevice
                    try p.run()
                    p.waitUntilExit()
                    let model = script.run(resourcesBranch: branch, caller: caller)
                    XCTAssertEqual(p.terminationStatus, model.exitCode, "\(script) \(caller) \(branch ?? "-")")
                }
            }
        }
        #else
        throw XCTSkip("Runs the shell scripts; macOS only (use `swift test`).")
        #endif
    }
}
