/// A deliberately trivial target: the interesting part of this repo is the
/// scheme's Build pre-action, not the code it builds.
public enum Greeter {
    public static func hello(_ name: String) -> String { "Hello, \(name)!" }
}
