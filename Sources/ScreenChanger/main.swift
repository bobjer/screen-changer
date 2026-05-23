import AppKit
import CoreGraphics
import ServiceManagement

private enum ScreenChangerError: Error, LocalizedError {
    case noExternalDisplay
    case beginConfiguration(CGError)
    case configure(String, CGError)
    case completeConfiguration(CGError)

    var errorDescription: String? {
        switch self {
        case .noExternalDisplay:
            return "External display is not connected."
        case .beginConfiguration(let error):
            return "Could not begin display configuration: \(error.rawValue)."
        case .configure(let step, let error):
            return "Could not configure display (\(step)): \(error.rawValue)."
        case .completeConfiguration(let error):
            return "Could not apply display configuration: \(error.rawValue)."
        }
    }
}

private final class DisplaySwitcher {
    var isReady: Bool {
        displayPair() != nil
    }

    func toggleMirrorMaster() throws {
        guard let pair = displayPair() else {
            throw ScreenChangerError.noExternalDisplay
        }

        let currentMaster = mirrorMaster(for: pair)
        let nextMaster = currentMaster == pair.external ? pair.builtIn : pair.external
        let nextMirror = nextMaster == pair.external ? pair.builtIn : pair.external

        try applyMirror(master: nextMaster, mirror: nextMirror)
    }

    private func applyMirror(master: CGDirectDisplayID, mirror: CGDirectDisplayID) throws {
        var config: CGDisplayConfigRef?
        let beginError = CGBeginDisplayConfiguration(&config)
        guard beginError == .success, let config else {
            throw ScreenChangerError.beginConfiguration(beginError)
        }

        func checked(_ step: String, _ error: CGError) throws {
            guard error == .success else {
                CGCancelDisplayConfiguration(config)
                throw ScreenChangerError.configure(step, error)
            }
        }

        do {
            try checked("unmirror master", CGConfigureDisplayMirrorOfDisplay(config, master, kCGNullDirectDisplay))
            try checked("unmirror mirror", CGConfigureDisplayMirrorOfDisplay(config, mirror, kCGNullDirectDisplay))
            try checked("set master origin", CGConfigureDisplayOrigin(config, master, 0, 0))
            try checked("set mirror", CGConfigureDisplayMirrorOfDisplay(config, mirror, master))

            let completeError = CGCompleteDisplayConfiguration(config, .forSession)
            guard completeError == .success else {
                throw ScreenChangerError.completeConfiguration(completeError)
            }
        } catch {
            throw error
        }
    }

    private func mirrorMaster(for pair: (builtIn: CGDirectDisplayID, external: CGDirectDisplayID)) -> CGDirectDisplayID {
        if CGDisplayMirrorsDisplay(pair.builtIn) == pair.external {
            return pair.external
        }

        if CGDisplayMirrorsDisplay(pair.external) == pair.builtIn {
            return pair.builtIn
        }

        if CGDisplayPrimaryDisplay(pair.builtIn) == pair.external {
            return pair.external
        }

        if CGDisplayPrimaryDisplay(pair.external) == pair.builtIn {
            return pair.builtIn
        }

        let mainDisplay = CGMainDisplayID()
        if mainDisplay == pair.external {
            return pair.external
        }

        return pair.builtIn
    }

    private func displayPair() -> (builtIn: CGDirectDisplayID, external: CGDirectDisplayID)? {
        let displays = onlineDisplays().filter { CGDisplayIsOnline($0) != 0 }
        guard let builtIn = displays.first(where: { CGDisplayIsBuiltin($0) != 0 }) else {
            return nil
        }

        let externalDisplays = displays.filter { CGDisplayIsBuiltin($0) == 0 }
        guard !externalDisplays.isEmpty else {
            return nil
        }

        let currentMain = CGMainDisplayID()
        let external = externalDisplays.first(where: { $0 == currentMain })
            ?? externalDisplays.first(where: { CGDisplayPrimaryDisplay($0) == currentMain })
            ?? externalDisplays.max(by: { displayArea($0) < displayArea($1) })!

        return (builtIn, external)
    }

    private func onlineDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else {
            return []
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else {
            return []
        }

        return Array(displays.prefix(Int(count)))
    }

    private func displayArea(_ display: CGDirectDisplayID) -> Int {
        Int(CGDisplayPixelsWide(display) * CGDisplayPixelsHigh(display))
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let switcher = DisplaySwitcher()
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var launchAtLoginItem: NSMenuItem!
    private var pendingDisplayRefresh: DispatchWorkItem?
    private var isSwitching = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableSuddenTermination()
        ProcessInfo.processInfo.disableAutomaticTermination("ScreenChanger is a menu bar app.")
        NSApp.setActivationPolicy(.accessory)

        configureStatusItem()
        configureMenu()

        CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())
        updateStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "com.damon.screenchanger.statusItem"
        statusItem.behavior = []
        statusItem.isVisible = true
        configureStatusButton()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.image = nil
        button.title = "🖥"
        button.font = .systemFont(ofSize: 16)
        button.imagePosition = .noImage
        button.isBordered = false
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureMenu() {
        launchAtLoginItem = NSMenuItem(
            title: "Toggle Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self

        let quitItem = NSMenuItem(
            title: "Quit ScreenChanger",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self

        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showMenu()
            return
        }

        guard !isSwitching else {
            NSSound.beep()
            return
        }

        guard switcher.isReady else {
            NSSound.beep()
            updateStatusItem()
            return
        }

        isSwitching = true
        updateStatusItem()

        do {
            try switcher.toggleMirrorMaster()
        } catch {
            isSwitching = false
            showError("Could Not Switch Displays", text: error.localizedDescription)
        }

        scheduleStatusUpdate(after: 2.5)
    }

    @objc private func toggleLaunchAtLogin(_ sender: Any?) {
        if #available(macOS 13.0, *) {
            do {
                let service = SMAppService.mainApp
                if service.status == .enabled {
                    try service.unregister()
                } else {
                    try service.register()
                }
            } catch {
                showError("Could Not Change Launch at Login", text: error.localizedDescription)
            }
        } else {
            showError("Launch at Login Is Unavailable", text: "macOS 13 or later is required.")
        }
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func showMenu() {
        updateLaunchAtLoginState()
        guard let button = statusItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    private func updateStatusItem() {
        statusItem.isVisible = true
        guard let button = statusItem.button else { return }

        let ready = switcher.isReady
        button.alphaValue = ready && !isSwitching ? 1.0 : 0.65
        button.title = "🖥"
        if isSwitching {
            button.toolTip = "Screen Changer: switching displays"
        } else {
            button.toolTip = ready
                ? "Screen Changer"
                : "Screen Changer: external display is not connected"
        }
    }

    private func scheduleStatusUpdate(after delay: TimeInterval = 0.4) {
        pendingDisplayRefresh?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.isSwitching = false
            self?.updateStatusItem()
        }

        pendingDisplayRefresh = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func updateLaunchAtLoginState() {
        if #available(macOS 13.0, *) {
            launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
            launchAtLoginItem.isEnabled = true
        } else {
            launchAtLoginItem.state = .off
            launchAtLoginItem.isEnabled = false
        }
    }

    private func showError(_ message: String, text: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.runModal()
    }

    fileprivate func displayConfigurationChanged(flags: CGDisplayChangeSummaryFlags) {
        guard !flags.contains(.beginConfigurationFlag) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scheduleStatusUpdate(after: self.isSwitching ? 2.5 : 0.4)
        }
    }
}

private let displayReconfigurationCallback: CGDisplayReconfigurationCallBack = { _, flags, userInfo in
    guard let userInfo else { return }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
    delegate.displayConfigurationChanged(flags: flags)
}

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
