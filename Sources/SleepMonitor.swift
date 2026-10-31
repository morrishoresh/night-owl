import AppKit
import Darwin
import IOKit.ps
import IOKit.pwr_mgt
import SystemConfiguration

/// Something currently holding a power assertion that blocks sleep.
struct SleepBlocker: Hashable {
    let owner: String
    let detail: String
    /// Process whose exit releases the assertion; nil for NightOwl itself.
    var process: BlockerProcess? = nil
}

/// The process behind a sleep assertion, for Activity Monitor and Quit / Force Quit.
struct BlockerProcess: Hashable {
    let pid: pid_t
    /// Name shown in the menu ("Safari", "caffeinate").
    let name: String
    /// Kernel process name, re-checked before killing in case the pid was reused.
    let processName: String
    /// Name Activity Monitor lists the process under (app name or kernel process name).
    let searchName: String
    /// Run by the current user, so it can be signalled without admin rights.
    let canQuit: Bool
}

struct SleepState: Equatable {
    /// System Settings sets the system sleep timer to "never" for the active power source.
    var sleepDisabledInSettings = false
    var powerSource = ""
    var blockers: [SleepBlocker] = []

    var isAwake: Bool { sleepDisabledInSettings || !blockers.isEmpty }
}

/// Watches every source that can keep the Mac awake: power assertions from any process
/// (caffeinate, Claude, this app, ...) and the System Settings sleep timer.
final class SleepMonitor {
    static let settingsKey = "State:/IOKit/PowerManagement/CurrentSettings"

    static let preventSleepTypes: Set<String> = [
        "PreventUserIdleSystemSleep", "PreventSystemSleep", "PreventUserIdleDisplaySleep",
        "NoIdleSleepAssertion", "NoDisplaySleepAssertion",
    ]

    /// System background tasks (runningboardd, Bluetooth) take assertions for a second or two;
    /// other processes' assertions must be this old before they count, to keep the icon steady.
    static let minimumAssertionAge: TimeInterval = 3

    /// powerd holds this whenever the display is on; it is not an override.
    static let ignoredAssertionNames: Set<String> = ["Powerd - Prevent sleep while display is on"]

    var onChange: ((SleepState) -> Void)?
    private(set) var state = SleepState()

    private var store: SCDynamicStore?
    private var timer: Timer?

    func start() {
        // Settings changes (System Settings, pmset) are pushed through SCDynamicStore.
        var context = SCDynamicStoreContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                            retain: nil, release: nil, copyDescription: nil)
        store = SCDynamicStoreCreate(nil, "NightOwl" as CFString, { _, _, info in
            guard let info else { return }
            Unmanaged<SleepMonitor>.fromOpaque(info).takeUnretainedValue().refresh()
        }, &context)
        if let store {
            SCDynamicStoreSetNotificationKeys(store, [Self.settingsKey] as CFArray, nil)
            if let source = SCDynamicStoreCreateRunLoopSource(nil, store, 0) {
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }

        // powerd does not notify ordinary clients about assertion changes, so poll.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        refresh()
    }

    func refresh() {
        var next = SleepState()
        next.powerSource = Self.powerSource()
        next.sleepDisabledInSettings = systemSleepTimer() == 0
        next.blockers = Self.activeBlockers()
        guard next != state else { return }
        state = next
        onChange?(next)
    }

    private func systemSleepTimer() -> Int? {
        guard let store,
              let settings = SCDynamicStoreCopyValue(store, Self.settingsKey as CFString) as? [String: Any]
        else { return nil }
        return settings["System Sleep Timer"] as? Int
    }

    private static func powerSource() -> String {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        else { return "" }
        return type == kIOPMACPowerKey ? "power adapter" : "battery"
    }

    static func activeBlockers() -> [SleepBlocker] {
        var byProcess: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&byProcess) == kIOReturnSuccess,
              let dict = byProcess?.takeRetainedValue() as NSDictionary?
        else { return [] }

        var seen = Set<SleepBlocker>()
        var result: [SleepBlocker] = []
        for (key, value) in dict {
            guard let pid = (key as? NSNumber)?.int32Value,
                  let assertions = value as? [[String: Any]] else { continue }
            for assertion in assertions {
                guard let type = assertion["AssertType"] as? String, preventSleepTypes.contains(type),
                      (assertion["AssertLevel"] as? Int ?? 255) != 0 else { continue }
                let name = assertion["AssertName"] as? String ?? type
                if ignoredAssertionNames.contains(name) || isBackgroundTaskCompletion(name) { continue }
                if pid != getpid(), let started = assertion["AssertStartWhen"] as? Date,
                   Date().timeIntervalSince(started) < minimumAssertionAge { continue }
                let onBehalfOf = (assertion["AssertionOnBehalfOfPID"] as? NSNumber)?.int32Value
                let blocker = describe(pid: pid, processName: assertion["Process Name"] as? String,
                                       onBehalfOf: onBehalfOf, assertionName: shortDetail(name))
                if seen.insert(blocker).inserted { result.append(blocker) }
            }
        }
        return result.sorted { ($0.owner, $0.detail) < ($1.owner, $1.detail) }
    }

    /// runningboardd names look like "extension<com.apple...>430-85258-256953:FBWorkspace Self-Assert";
    /// keep only the reason after the "<pid>-<pid>-<id>:" prefix.
    static func shortDetail(_ assertionName: String) -> String {
        guard let match = assertionName.range(of: #">\d+-\d+-\d+:"#, options: .regularExpression) else {
            return assertionName
        }
        let reason = assertionName[match.upperBound...].trimmingCharacters(in: .whitespaces)
        return reason.isEmpty ? assertionName : reason
    }

    /// runningboardd briefly keeps the Mac awake while an app finishes a background task.
    private static func isBackgroundTaskCompletion(_ assertionName: String) -> Bool {
        assertionName.contains("Shared Background Assertion")
    }

    private static func describe(pid: pid_t, processName: String?, onBehalfOf: pid_t?,
                                 assertionName: String) -> SleepBlocker {
        if pid == getpid() {
            return SleepBlocker(owner: "NightOwl", detail: "Keep Mac Awake")
        }
        if (processName ?? Self.processName(pid)) == "caffeinate" {
            // Quitting caffeinate itself leaves the terminal or Claude Code that started it running.
            let parent = parentPID(pid).map { displayName($0, processName: nil) } ?? "terminal"
            return SleepBlocker(owner: parent, detail: "via caffeinate", process: blockerProcess(pid))
        }
        // Daemons such as coreaudiod hold assertions for the app that asked; that app is the owner.
        if let onBehalfOf, onBehalfOf > 0, onBehalfOf != pid {
            return SleepBlocker(owner: displayName(onBehalfOf, processName: nil), detail: assertionName,
                                process: blockerProcess(onBehalfOf))
        }
        return SleepBlocker(owner: displayName(pid, processName: processName), detail: assertionName,
                            process: blockerProcess(pid))
    }

    private static func blockerProcess(_ pid: pid_t) -> BlockerProcess? {
        guard pid > 1, pid != getpid(), let process = processName(pid) else { return nil }
        let name = NSRunningApplication(processIdentifier: pid)?.localizedName ?? process
        let canQuit = bsdInfo(pid)?.pbi_uid == getuid()
        return BlockerProcess(pid: pid, name: shortName(name), processName: process,
                              searchName: name, canQuit: canQuit)
    }

    private static func displayName(_ pid: pid_t, processName: String?) -> String {
        if let app = NSRunningApplication(processIdentifier: pid)?.localizedName { return shortName(app) }
        let process = processName ?? Self.processName(pid) ?? "pid \(pid)"
        return process.lowercased().hasPrefix("claude") ? "Claude Code" : shortName(process)
    }

    static let maxNameLength = 24

    /// Drops a trailing "(...)" qualifier and caps the length, so menu rows stay narrow.
    static func shortName(_ name: String) -> String {
        var short = name
        if let open = short.range(of: " ("), short.hasSuffix(")") {
            short = String(short[..<open.lowerBound])
        }
        return short.count <= maxNameLength ? short : String(short.prefix(maxNameLength - 1)) + "…"
    }

    static func processName(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 256)
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func parentPID(_ pid: pid_t) -> pid_t? {
        bsdInfo(pid).map { pid_t($0.pbi_ppid) }
    }

    private static func bsdInfo(_ pid: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return info
    }
}
