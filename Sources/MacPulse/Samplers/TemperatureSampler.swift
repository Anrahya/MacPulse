import Foundation
import IOKit

/// Reads die/package temperatures from the IOKit HID sensor registry.
///
/// On Apple Silicon the raw `AppleSMC` user client is restricted to root, but
/// the HID event system still publishes named thermal sensors readable from a
/// normal user process. This is the same source `powermetrics` surfaces.
final class TemperatureSampler {

    private typealias ClientRef = CFTypeRef

    private var client: ClientRef?
    private var sensorCache: [(name: String, service: ClientRef)] = []
    private var lastRefresh: Date = .distantPast
    private let refreshInterval: TimeInterval = 30

    func sample() -> TemperatureSnapshot {
        var snapshot = TemperatureSnapshot()
        guard ensureClient() else { return snapshot }

        // Sensor topology changes rarely; cache the list and refresh slowly.
        if sensorCache.isEmpty || Date().timeIntervalSince(lastRefresh) > refreshInterval {
            rebuildSensorList()
        }

        var readings: [TemperatureReading] = []
        readings.reserveCapacity(sensorCache.count)

        for entry in sensorCache {
            guard let celsius = readTemperature(entry.service) else { continue }
            guard celsius > 0, celsius < 130 else { continue }
            readings.append(TemperatureReading(
                id: entry.name,
                sensor: entry.name,
                label: friendlyLabel(entry.name),
                celsius: celsius
            ))
        }

        readings.sort { $0.celsius > $1.celsius }
        snapshot.readings = readings
        snapshot.hottest = readings.first?.celsius ?? 0

        // Prefer the die sensors for the headline figures.
        snapshot.socTemperature = average(readings, matching: ["SOC", "PMGR"])
        snapshot.cpuTemperature = average(readings, matching: ["pACC", "eACC"])
        snapshot.gpuTemperature = average(readings, matching: ["GPU"])

        return snapshot
    }

    // MARK: - Sensor plumbing

    private func ensureClient() -> Bool {
        if client != nil { return true }
        client = IOHIDEventSystemClientCreateWithType(kCFAllocatorDefault, 1, nil)
        return client != nil
    }

    private func rebuildSensorList() {
        lastRefresh = Date()
        sensorCache = []
        guard let client,
              let services = IOHIDEventSystemClientCopyServices(client) as? [ClientRef] else {
            return
        }

        for service in services {
            guard let productRef = IOHIDServiceClientCopyProperty(service, "Product" as CFString) else {
                continue
            }
            let name = productRef as? String ?? "\(productRef)"
            let lowered = name.lowercased()
            guard lowered.contains("temp") || lowered.contains("sensor") else { continue }
            sensorCache.append((name: name, service: service))
        }
    }

    private func readTemperature(_ service: ClientRef) -> Double? {
        let eventType: Int64 = 15   // kIOHIDEventTypeTemperature
        let field: Int32 = Int32(15 << 16) // kIOHIDEventFieldTemperatureLevel
        guard let event = IOHIDServiceClientCopyEvent(service, eventType, 0, 0) else {
            return nil
        }
        let value = IOHIDEventGetFloatValue(event, field)
        return value.isFinite ? value : nil
    }

    private func average(_ readings: [TemperatureReading], matching needles: [String]) -> Double? {
        let subset = readings.filter { reading in
            needles.contains { reading.sensor.localizedCaseInsensitiveContains($0) }
        }
        guard !subset.isEmpty else { return nil }
        return subset.map(\.celsius).reduce(0, +) / Double(subset.count)
    }

    /// Turns "PMGR SOC Die Temp Sensor2" into something readable while keeping
    /// the sensor's index so repeated cluster names stay distinguishable.
    private func friendlyLabel(_ raw: String) -> String {
        // The index is the trailing digit of the raw name
        // ("pACC MTR Temp Sensor3"), so grab it before trimming.
        var suffix = ""
        if let last = raw.last, last.isNumber {
            suffix = String(last)
        }

        var text = raw
        if let range = text.range(of: " MTR") {
            text = String(text[..<range.lowerBound])
        }
        text = text
            .replacingOccurrences(of: " Temp Sensor", with: "")
            .replacingOccurrences(of: " Die", with: "")
            .replacingOccurrences(of: "temp", with: "Temp")
            .trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return raw }
        // Avoid "PMGR SOC2 2" when the block already ends in the index.
        if let last = text.last, String(last) == suffix { return text }
        return suffix.isEmpty ? text : "\(text) \(suffix)"
    }
}

// MARK: - IOKit HID SPI declarations

@_silgen_name("IOHIDEventSystemClientCreateWithType")
private func IOHIDEventSystemClientCreateWithType(
    _ allocator: CFAllocator?,
    _ type: Int32,
    _ options: CFDictionary?
) -> CFTypeRef?

@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServices(_ client: CFTypeRef) -> CFArray?

@_silgen_name("IOHIDServiceClientCopyProperty")
private func IOHIDServiceClientCopyProperty(_ service: CFTypeRef, _ key: CFString) -> CFTypeRef?

@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEvent(
    _ service: CFTypeRef,
    _ type: Int64,
    _ options: Int32,
    _ timestamp: Int64
) -> CFTypeRef?

@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValue(_ event: CFTypeRef, _ field: Int32) -> Double
