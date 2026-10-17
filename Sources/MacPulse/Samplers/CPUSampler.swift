import Foundation
import Darwin

/// Reads aggregate and per-core CPU load from Mach host statistics.
///
/// Uses delta sampling between successive `host_processor_info` calls, which is
/// the only way to get instantaneous load — the raw counters are cumulative
/// since boot.
final class CPUSampler {

    private struct CoreTicks {
        var user: UInt64
        var system: UInt64
        var idle: UInt64
        var nice: UInt64
        var total: UInt64 { user + system + idle + nice }
    }

    private var previous: [CoreTicks] = []

    func sample() -> CPUSnapshot {
        var snapshot = CPUSnapshot()

        let current = readTicks()
        defer { previous = current }

        snapshot.coreCount = current.count
        guard !current.isEmpty else { return snapshot }

        // First pass has no baseline; report a zeroed but well-formed snapshot.
        guard previous.count == current.count else {
            snapshot.cores = Array(repeating: 0, count: current.count)
            return snapshot
        }

        var perCore: [Double] = []
        perCore.reserveCapacity(current.count)

        var totalBusy = 0.0
        var totalUser = 0.0
        var totalSystem = 0.0
        var totalIdle = 0.0
        var totalDelta = 0.0

        for i in 0..<current.count {
            let c = current[i]
            let p = previous[i]

            let dUser   = Double(c.user &- min(c.user, p.user))
            let dSystem = Double(c.system &- min(c.system, p.system))
            let dIdle   = Double(c.idle &- min(c.idle, p.idle))
            let dNice   = Double(c.nice &- min(c.nice, p.nice))

            let dTotal = dUser + dSystem + dIdle + dNice
            let busy = dTotal > 0 ? (dUser + dSystem + dNice) / dTotal : 0

            perCore.append(busy)
            totalBusy   += (dUser + dSystem + dNice)
            totalUser   += dUser
            totalSystem += dSystem
            totalIdle   += dIdle
            totalDelta  += dTotal
        }

        snapshot.cores = perCore
        if totalDelta > 0 {
            snapshot.total  = min(totalBusy / totalDelta, 1)
            snapshot.user   = min(totalUser / totalDelta, 1)
            snapshot.system = min(totalSystem / totalDelta, 1)
            snapshot.idle   = max(totalIdle / totalDelta, 0)
        }

        var loads = [Double](repeating: 0, count: 3)
        if getloadavg(&loads, 3) == 3 {
            snapshot.load1 = loads[0]
            snapshot.load5 = loads[1]
            snapshot.load15 = loads[2]
        }

        return snapshot
    }

    // MARK: - Mach plumbing

    private func readTicks() -> [CoreTicks] {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &info,
            &infoCount
        )

        guard result == KERN_SUCCESS, let info else { return [] }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: info)),
                vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            )
        }

        let stride = Int(CPU_STATE_MAX)
        var ticks: [CoreTicks] = []
        ticks.reserveCapacity(Int(cpuCount))

        for core in 0..<Int(cpuCount) {
            let base = core * stride
            ticks.append(CoreTicks(
                user:   UInt64(info[base + Int(CPU_STATE_USER)]),
                system: UInt64(info[base + Int(CPU_STATE_SYSTEM)]),
                idle:   UInt64(info[base + Int(CPU_STATE_IDLE)]),
                nice:   UInt64(info[base + Int(CPU_STATE_NICE)])
            ))
        }
        return ticks
    }
}
