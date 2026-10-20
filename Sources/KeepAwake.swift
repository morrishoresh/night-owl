import IOKit.pwr_mgt

/// Holds this app's own power assertions.
final class KeepAwake {
    private var systemAssertion: IOPMAssertionID = 0
    private var displayAssertion: IOPMAssertionID = 0

    var isOn: Bool { systemAssertion != 0 }
    var keepsDisplayOn: Bool { displayAssertion != 0 }

    func setOn(_ on: Bool) {
        if on {
            create(&systemAssertion, type: "PreventUserIdleSystemSleep", name: "NightOwl: keeping Mac awake")
        } else {
            release(&systemAssertion)
            release(&displayAssertion)
        }
    }

    func setDisplayOn(_ on: Bool) {
        if on {
            create(&displayAssertion, type: "PreventUserIdleDisplaySleep", name: "NightOwl: keeping display on")
        } else {
            release(&displayAssertion)
        }
    }

    private func create(_ id: inout IOPMAssertionID, type: String, name: String) {
        guard id == 0 else { return }
        if IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                       name as CFString, &id) != kIOReturnSuccess {
            id = 0
        }
    }

    private func release(_ id: inout IOPMAssertionID) {
        guard id != 0 else { return }
        IOPMAssertionRelease(id)
        id = 0
    }
}
