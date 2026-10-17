import Foundation

// MARK: - CPU

struct CPUSnapshot: Equatable {
    /// Overall busy ratio 0...1.
    var total: Double = 0
    var user: Double = 0
    var system: Double = 0
    var idle: Double = 1
    /// Per-core busy ratios 0...1.
    var cores: [Double] = []
    var load1: Double = 0
    var load5: Double = 0
    var load15: Double = 0
    var coreCount: Int = 0

    var physicalCores: Int { ProcessInfo.processInfo.processorCount }

    static func == (lhs: CPUSnapshot, rhs: CPUSnapshot) -> Bool {
        lhs.total == rhs.total
            && lhs.user == rhs.user
            && lhs.system == rhs.system
            && lhs.idle == rhs.idle
            && lhs.cores == rhs.cores
            && lhs.load1 == rhs.load1
            && lhs.load5 == rhs.load5
            && lhs.load15 == rhs.load15
            && lhs.coreCount == rhs.coreCount
    }
}

// MARK: - Memory

struct MemorySnapshot: Equatable {
    var total: UInt64 = 0
    var active: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var cached: UInt64 = 0
    var free: UInt64 = 0
    var swapUsed: UInt64 = 0
    var swapTotal: UInt64 = 0
    var pressure: Double = 0
    var pressureLevel: MemoryPressureLevel = .normal

    /// Memory considered "used" by apps + kernel.
    var used: UInt64 { active &+ wired &+ compressed }
    var usedRatio: Double { total > 0 ? Double(used) / Double(total) : 0 }
    var freeRatio: Double { total > 0 ? Double(free) / Double(total) : 0 }
}

enum MemoryPressureLevel: String, Equatable {
    case normal = "Nominal"
    case warning = "Warning"
    case critical = "Critical"
}

// MARK: - Battery

struct BatterySnapshot: Equatable {
    var isPresent = false
    var percentage: Double = 0
    var isCharging = false
    var isPluggedIn = false
    var fullyCharged = false
    var cycleCount = 0
    var health: Double = 0            // max/design
    var designCapacity: Int = 0
    var maxCapacity: Int = 0
    var currentCapacity: Int = 0
    var voltage: Double = 0           // volts
    var amperage: Double = 0          // amps
    var temperature: Double = 0       // celsius
    var timeRemainingMinutes: Int? = nil
    var condition: String = "Normal"

    var watts: Double { abs(voltage * amperage) }
}

// MARK: - Network

struct NetworkSnapshot: Equatable {
    var downloadBytesPerSec: Double = 0
    var uploadBytesPerSec: Double = 0
    var totalReceived: UInt64 = 0
    var totalSent: UInt64 = 0
    var interfaceName: String = ""
    var isConnected: Bool = false
    var localIP: String? = nil
}

// MARK: - Storage

struct StorageSnapshot: Equatable {
    var total: UInt64 = 0
    var free: UInt64 = 0
    var used: UInt64 { total > free ? total - free : 0 }
    var usedRatio: Double { total > 0 ? Double(used) / Double(total) : 0 }
    var volumeName: String = "Macintosh HD"
}

// MARK: - Processes

struct ProcessEntry: Identifiable, Equatable {
    let pid: Int32
    var name: String
    var cpu: Double        // percent of one core (0...100*n)
    var memory: UInt64     // resident bytes

    var id: Int32 { pid }
}

// MARK: - Temperature

struct TemperatureReading: Identifiable, Equatable {
    let id: String
    var sensor: String
    var label: String
    var celsius: Double

    var fahrenheit: Double { celsius * 9 / 5 + 32 }
}

struct TemperatureSnapshot: Equatable {
    var readings: [TemperatureReading] = []
    var hottest: Double = 0
    var cpuTemperature: Double? = nil
    var gpuTemperature: Double? = nil
    var socTemperature: Double? = nil
    var available: Bool { !readings.isEmpty }
}
