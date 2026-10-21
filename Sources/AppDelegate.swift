import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let monitor = SleepMonitor()
    private let keepAwake = KeepAwake()
    private let keptAwakeImage = OwlArt.menuBarImage(.keptAwake)
    private let awakeByOthersImage = OwlArt.menuBarImage(.awakeByOthers)
    private let canSleepImage = OwlArt.menuBarImage(.canSleep)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        monitor.onChange = { [weak self] state in self?.updateIcon(state) }
        monitor.start()
        updateIcon(monitor.state)
    }

    func applicationWillTerminate(_ notification: Notification) {
        keepAwake.setOn(false)
    }

    private func updateIcon(_ state: SleepState) {
        guard let button = statusItem.button else { return }
        if keepAwake.isOn {
            button.image = keptAwakeImage
            button.toolTip = "NightOwl: keeping Mac awake"
        } else if state.isAwake {
            button.image = awakeByOthersImage
            button.toolTip = "NightOwl: off, but Mac is kept awake by another source"
        } else {
            button.image = canSleepImage
            button.toolTip = "NightOwl: Mac can sleep"
        }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        monitor.refresh()
        let state = monitor.state
        menu.removeAllItems()

        menu.addItem(disabled(state.isAwake ? "Awake: Mac won't idle-sleep" : "Mac can sleep normally"))
        menu.addItem(.separator())

        let toggle = item("Keep Mac Awake", #selector(toggleKeepAwake))
        toggle.state = keepAwake.isOn ? .on : .off
        menu.addItem(toggle)

        let display = item("Keep Display On Too", #selector(toggleDisplay))
        display.state = keepAwake.keepsDisplayOn ? .on : .off
        display.isEnabled = keepAwake.isOn
        display.indentationLevel = 1
        menu.addItem(display)

        if state.isAwake {
            menu.addItem(.separator())
            menu.addItem(disabled("Kept awake by:"))
            if state.sleepDisabledInSettings {
                menu.addItem(disabled("System Settings: never sleep on \(state.powerSource)", indent: 1))
            }
            for blocker in state.blockers {
                menu.addItem(disabled("\(blocker.owner): \(truncated(blocker.detail))", indent: 1))
            }
        }

        menu.addItem(.separator())
        menu.addItem(item("Open Battery Settings…", #selector(openBatterySettings)))
        let login = item("Launch at Login", #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NightOwl", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func disabled(_ title: String, indent: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.indentationLevel = indent
        return item
    }

    private func truncated(_ text: String, limit: Int = 60) -> String {
        text.count <= limit ? text : String(text.prefix(limit - 1)) + "…"
    }

    // MARK: - Actions

    @objc private func toggleKeepAwake() {
        keepAwake.setOn(!keepAwake.isOn)
        monitor.refresh()
        updateIcon(monitor.state)
    }

    @objc private func toggleDisplay() {
        keepAwake.setDisplayOn(!keepAwake.keepsDisplayOn)
        monitor.refresh()
    }

    @objc private func openBatterySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension")!
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Could not change Launch at Login"
            alert.runModal()
        }
    }
}
