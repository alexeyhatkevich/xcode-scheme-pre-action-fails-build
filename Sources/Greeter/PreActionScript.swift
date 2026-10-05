/// A Swift model of the two setup scripts in `scripts/`, so the Demo app can
/// show what each one does in each situation (an iOS app can't run the shell
/// scripts). `GreeterTests` checks this model against the real scripts on macOS.
public enum PreActionScript: String, CaseIterable, Identifiable, Sendable {
    case naive
    case fixed

    public var id: String { rawValue }
    public var fileName: String { "scripts/prebuild_\(rawValue).sh" }

    /// Who calls the script.
    public enum Caller: String, CaseIterable, Identifiable, Sendable {
        /// A scheme Build pre-action: Xcode exports `SCHEME_ACTION_NAME`.
        case xcodeSchemePreAction
        /// A terminal or CI job: no `SCHEME_ACTION_NAME`.
        case commandLine

        public var id: String { rawValue }

        /// The environment the script sees (only the variable that matters).
        public var environment: [String: String] {
            switch self {
            case .xcodeSchemePreAction: return ["SCHEME_ACTION_NAME": "Project setup"]
            case .commandLine: return [:]
            }
        }
    }

    public struct Outcome: Equatable, Sendable {
        public let exitCode: Int32
        public let output: String
        /// The expensive setup work (re-clone, pod install, ...) ran.
        public let ranSetup: Bool
        /// When the script is a scheme pre-action: non-zero exit = failed build.
        public var failsTheBuild: Bool { exitCode != 0 }
    }

    /// Mirrors the decision logic of the shell script.
    public func run(resourcesBranch: String?, environment: [String: String]) -> Outcome {
        if let branch = resourcesBranch, !branch.isEmpty {
            return Outcome(exitCode: 0,
                           output: "setup: preparing project with resources from '\(branch)'",
                           ranSetup: true)
        }
        if self == .fixed, let action = environment["SCHEME_ACTION_NAME"], !action.isEmpty {
            let scheme = environment["SCHEME_NAME"] ?? "?"
            return Outcome(exitCode: 0,
                           output: "warning: '\(action)' in scheme '\(scheme)' ran without --resources-branch; skipping project setup.",
                           ranSetup: false)
        }
        return Outcome(exitCode: 1, output: "error: --resources-branch is required", ranSetup: false)
    }

    public func run(resourcesBranch: String?, caller: Caller) -> Outcome {
        run(resourcesBranch: resourcesBranch, environment: caller.environment)
    }
}
