import AppKit
import ApplicationServices

/// Opens Activity Monitor filtered to one process. Activity Monitor has no URL scheme or
/// scripting API, so the filter is typed into its search field through Accessibility.
/// Without Accessibility permission it only opens Activity Monitor.
enum ActivityMonitor {
    static let bundleID = "com.apple.ActivityMonitor"
    static let appURL = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")

    /// How long to wait for Activity Monitor's window and search field after launching it.
    static let searchFieldTimeout: TimeInterval = 5
    static let pollInterval: TimeInterval = 0.2

    static func show(_ searchName: String) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { app, _ in
            DispatchQueue.main.async {
                // Asks macOS to show its Accessibility prompt when permission is missing.
                let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                guard let app, AXIsProcessTrustedWithOptions(prompt) else { return }
                fillSearch(searchName, pid: app.processIdentifier,
                           deadline: Date().addingTimeInterval(searchFieldTimeout))
            }
        }
    }

    private static func fillSearch(_ text: String, pid: pid_t, deadline: Date) {
        if let field = searchField(in: AXUIElementCreateApplication(pid)) {
            AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, text as CFTypeRef)
            AXUIElementPerformAction(field, kAXConfirmAction as CFString)
            return
        }
        guard Date() < deadline else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) {
            fillSearch(text, pid: pid, deadline: deadline)
        }
    }

    private static func searchField(in app: AXUIElement) -> AXUIElement? {
        let windows = value(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
        for window in windows {
            if let field = find(in: window, depth: 0) { return field }
        }
        return nil
    }

    /// The search field sits in the window toolbar, a few levels down.
    private static func find(in element: AXUIElement, depth: Int) -> AXUIElement? {
        if value(element, kAXSubroleAttribute) as? String == "AXSearchField" { return element }
        guard depth < 6 else { return nil }
        for child in value(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
            if let field = find(in: child, depth: depth + 1) { return field }
        }
        return nil
    }

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &result)
        return result
    }
}
