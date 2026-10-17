import Foundation
import IOKit
import IOKit.ps

/// Reads battery state from the `AppleSmartBattery` IORegistry node.
final class BatterySampler {

    private var service: io_service_t = 0

    deinit {
        if service != 0 { IOObjectRelease(service) }
    }

    func sample() -> BatterySnapshot {
        var snapshot = BatterySnapshot()

        guard let props = batteryProperties() else {
            snapshot.isPresent = false
            return snapshot
        }
        snapshot.isPresent = true

        snapshot.currentCapacity = int(props["CurrentCapacity"]) ?? 0
        snapshot.maxCapacity     = int(props["MaxCapacity"]) ?? 0
        snapshot.designCapacity  = int(props["DesignCapacity"]) ?? 0
        snapshot.cycleCount      = int(props["CycleCount"]) ?? 0

        // On Apple Silicon, the raw mAh figures and design capacity live in a
        // nested "BatteryData" dictionary rather than at the top level.
        let detail = props["BatteryData"] as? [String: Any] ?? [:]

        let rawMax     = int(detail["AppleRawMaxCapacity"]) ?? int(props["AppleRawMaxCapacity"])
            ?? int(detail["FullChargeCapacity"]) ?? snapshot.maxCapacity
        let rawCurrent = int(detail["AppleRawCurrentCapacity"]) ?? int(props["AppleRawCurrentCapacity"])
            ?? int(detail["CurrentCapacity"]) ?? snapshot.currentCapacity
        let design     = int(detail["DesignCapacity"]) ?? int(props["DesignCapacity"]) ?? 0

        snapshot.designCapacity = design

        if snapshot.maxCapacity > 0, snapshot.maxCapacity <= 100 {
            snapshot.percentage = Double(snapshot.maxCapacity)
        } else if rawMax > 0 {
            snapshot.percentage = Double(rawCurrent) / Double(rawMax) * 100
        }
        snapshot.percentage = min(max(snapshot.percentage, 0), 100)

        // Health = full charge capacity / design capacity.
        if design > 0, rawMax > 0 {
            snapshot.health = min(Double(rawMax) / Double(design), 1.5)
        }

        snapshot.isCharging     = bool(props["IsCharging"]) ?? false
        snapshot.isPluggedIn    = bool(props["ExternalConnected"]) ?? false
        snapshot.fullyCharged   = bool(props["FullyCharged"]) ?? false

        snapshot.voltage  = Double(int(props["Voltage"]) ?? 0) / 1000.0  // mV -> V
        snapshot.amperage = Double(int(props["Amperage"]) ?? int(props["InstantAmperage"]) ?? 0) / 1000.0
        snapshot.temperature = Double(int(detail["Temperature"]) ?? int(props["Temperature"]) ?? 0) / 100.0

        // Remaining time is reported under several names depending on state.
        let remaining = int(props["TimeRemaining"]) ?? int(props["AvgTimeToEmpty"])
        if let remaining, remaining > 0, remaining < 65535, !snapshot.isCharging {
            snapshot.timeRemainingMinutes = remaining
        }
        if let full = int(props["AvgTimeToFull"]), full > 0, full < 65535, snapshot.isCharging {
            snapshot.timeRemainingMinutes = full
        }

        snapshot.condition = string(props["BatteryHealth"]) ?? "Normal"
        return snapshot
    }

    // MARK: - IORegistry

    private func batteryProperties() -> [String: Any]? {
        if service == 0 {
            service = IOServiceGetMatchingService(
                kIOMainPortDefault,
                IOServiceMatching("AppleSmartBattery")
            )
        }
        guard service != 0 else { return nil }

        var unmanaged: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(
            service, &unmanaged, kCFAllocatorDefault, 0
        )
        guard kr == KERN_SUCCESS, let dict = unmanaged?.takeRetainedValue() else {
            return nil
        }
        return dict as? [String: Any]
    }

    private func int(_ any: Any?) -> Int? {
        if let v = any as? Int { return v }
        if let v = any as? Int64 { return Int(v) }
        if let v = any as? NSNumber { return v.intValue }
        return nil
    }

    private func bool(_ any: Any?) -> Bool? {
        if let v = any as? Bool { return v }
        if let v = any as? NSNumber { return v.boolValue }
        return nil
    }

    private func string(_ any: Any?) -> String? {
        any as? String
    }
}
