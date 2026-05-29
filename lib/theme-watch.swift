import Foundation

// Event-driven watcher: re-themes all open Terminal windows whenever macOS
// switches between Light and Dark appearance. Idles in the run loop (~0% CPU,
// a few MB RAM). Compiled and launched by install.sh via a LaunchAgent.

let dir = ProcessInfo.processInfo.environment["TERM_TINT_DIR"]
    ?? (NSHomeDirectory() + "/.config/terminal-theme")
let script = dir + "/apply-theme.sh"

func applyAll() {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
    p.arguments = [script, "all"]
    do { try p.run() } catch {
        FileHandle.standardError.write("theme-watch: failed to run apply: \(error)\n".data(using: .utf8)!)
    }
}

// Sync once at launch in case appearance changed while we were not running.
applyAll()

DistributedNotificationCenter.default().addObserver(
    forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
    object: nil,
    queue: .main
) { _ in
    // Brief delay so AppleInterfaceStyle is fully updated before we read it.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { applyAll() }
}

RunLoop.main.run()
