import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Activate the app so it can display windows and receive events
app.setActivationPolicy(.accessory)
app.activate(ignoringOtherApps: true)

// Run the application
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
