import Foundation
import Darwin

/// Reads virtual-memory statistics, swap usage, and pressure level.
final class MemorySampler {

    private var pageSize: UInt64 = 16384

    init() {
        var size: vm_size_t = 0
        if host_page_size(mach_host_self(), &size) == KERN_SUCCESS {
            pageSize = UInt64(size)
        }
    }

    func sample() -> MemorySnapshot {
        var snapshot = MemorySnapshot()
        snapshot.total = physicalMemory()

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )

        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return snapshot }

        let page = pageSize
        let active     = UInt64(stats.active_count) * page
        let wired      = UInt64(stats.wire_count) * page
        let compressed = UInt64(stats.compressor_page_count) * page
        let inactive   = UInt64(stats.inactive_count) * page
        let free       = UInt64(stats.free_count) * page
        let purgeable  = UInt64(stats.purgeable_count) * page

        snapshot.active     = active
        snapshot.wired      = wired
        snapshot.compressed = compressed
        snapshot.free       = free
        // File cache is roughly inactive + purgeable pages.
        snapshot.cached     = inactive > purgeable ? inactive - purgeable : inactive

        let (swapUsed, swapTotal) = swapUsage()
        snapshot.swapUsed = swapUsed
        snapshot.swapTotal = swapTotal

        if let pressure = pressureRatio(free: free, total: snapshot.total) {
            snapshot.pressure = pressure
        }
        snapshot.pressureLevel = currentPressureLevel()

        return snapshot
    }

    // MARK: - Components

    private func physicalMemory() -> UInt64 {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &value, &size, nil, 0)
        return value
    }

    private func swapUsage() -> (used: UInt64, total: UInt64) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let kr = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        guard kr == 0 else { return (0, 0) }
        return (usage.xsu_used, usage.xsu_total)
    }

    /// Kernel-reported pressure (1 = normal, 2 = warning, 4 = critical).
    private func currentPressureLevel() -> MemoryPressureLevel {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        switch level {
        case 2: return .warning
        case 4: return .critical
        default: return .normal
        }
    }

    /// Heuristic pressure ratio derived from free memory headroom.
    private func pressureRatio(free: UInt64, total: UInt64) -> Double? {
        guard total > 0 else { return nil }
        let usedFraction = 1.0 - (Double(free) / Double(total))
        return min(max(usedFraction, 0), 1)
    }
}
