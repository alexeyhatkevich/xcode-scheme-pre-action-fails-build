import SwiftUI
import Greeter

struct ContentView: View {
    /// Set by the Run action of each scheme in Demo/project.yml.
    private let launchedScheme = ProcessInfo.processInfo.environment["DEMO_SCHEME"]

    @State private var script: PreActionScript = .naive
    @State private var caller: PreActionScript.Caller = .xcodeSchemePreAction
    @State private var passFlag = false

    private var outcome: PreActionScript.Outcome {
        script.run(resourcesBranch: passFlag ? "main" : nil, caller: caller)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("A shared scheme has a Build pre-action that runs a project setup script without the --resources-branch flag. Pick the script version and watch the result.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Picker("Script", selection: $script) {
                        Text("Naive").tag(PreActionScript.naive)
                        Text("Fixed").tag(PreActionScript.fixed)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("scriptPicker")

                    Picker("Caller", selection: $caller) {
                        Text("Xcode pre-action").tag(PreActionScript.Caller.xcodeSchemePreAction)
                        Text("Terminal / CI").tag(PreActionScript.Caller.commandLine)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Pass --resources-branch main", isOn: $passFlag)

                    resultCard

                    VStack(alignment: .leading, spacing: 6) {
                        Text("What to watch").font(.headline)
                        Text("Naive + Xcode pre-action: exit 1, so the whole scheme fails to build (Xcode 26+ IDE, and xcodebuild everywhere).")
                        Text("Fixed + Xcode pre-action: Xcode exports SCHEME_ACTION_NAME, the script warns and exits 0, the build goes on.")
                        Text("Terminal / CI without the flag: both versions still fail hard, which is what you want there.")
                    }
                    .font(.footnote)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Try it for real").font(.headline)
                        Text("Build the Demo-Naive scheme: it fails with \"Run custom shell script 'Project setup'\". Build Demo-Fixed: it succeeds and the pre-action log (/tmp/demo-prebuild.log) has the warning.")
                        Text("Launched from scheme: \(launchedScheme ?? "unknown")")
                            .bold()
                    }
                    .font(.footnote)
                }
                .padding()
            }
            .navigationTitle("Pre-action demo")
        }
    }

    private var resultCard: some View {
        let out = outcome
        let failed = caller == .xcodeSchemePreAction && out.failsTheBuild
        let status: String = {
            switch caller {
            case .xcodeSchemePreAction: return failed ? "BUILD FAILED" : "BUILD SUCCEEDED"
            case .commandLine: return out.exitCode == 0 ? "SCRIPT OK" : "SCRIPT ERROR (intended)"
            }
        }()
        return VStack(alignment: .leading, spacing: 8) {
            Text("$ \(script.fileName)\(passFlag ? " --resources-branch main" : "")")
                .font(.system(.footnote, design: .monospaced))
            Text(out.output)
                .font(.system(.footnote, design: .monospaced))
            Text("exit \(out.exitCode)\(out.ranSetup ? " (setup ran)" : "")")
                .font(.system(.footnote, design: .monospaced))
            Text(status)
                .font(.title2.bold())
                .foregroundStyle(failed ? .red : (out.exitCode == 0 ? .green : .orange))
                .accessibilityIdentifier("status")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

#Preview { ContentView() }
