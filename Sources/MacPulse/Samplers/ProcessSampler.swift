import Foundation
import Darwin

/// Enumerates processes and their CPU / memory footprints.
///
/// Uses `libproc` (`proc_listpids` + `proc_pid_rusage`), which is the supported
/// route on modern macOS — `sysctl KERN_PROC` is restricted under SIP.
final class ProcessSampler {

    private struct RawUsage {
        var pid: Int32
        var name: String
        var memory: UInt64
        var cpuTime: UInt64   // nanoseconds
    }

    private var previousTimes: [Int32: UInt64] = [:]
    private var previousSample: Date?

    /// - Parameter limit: maximum rows to return, sorted by CPU then memory.
    func sample(limit: Int = 8) -> [ProcessEntry] {
        let raw = enumerate()
        let now = Date()

        var entries: [ProcessEntry] = []
        entries.reserveCapacity(raw.count)

        let elapsed = previousSample.map { now.timeIntervalSince($0) } ?? 0
        let canDiff = elapsed > 0.05 && !previousTimes.isEmpty

        for proc in raw {
            var cpuPercent = 0.0
            if canDiff, let prev = previousTimes[proc.pid], proc.cpuTime >= prev {
                let deltaSeconds = Double(proc.cpuTime - prev) / 1_000_000_000.0
                cpuPercent = (deltaSeconds / elapsed) * 100.0
            }
            entries.append(ProcessEntry(
                pid: proc.pid,
                name: proc.name,
                cpu: cpuPercent,
                memory: proc.memory
            ))
        }

        previousTimes = Dictionary(raw.map { ($0.pid, $0.cpuTime) }, uniquingKeysWith: max)
        previousSample = now

        entries.sort {
            if abs($0.cpu - $1.cpu) > 0.5 { return $0.cpu > $1.cpu }
            return $0.memory > $1.memory
        }
        return Array(entries.prefix(limit))
    }

    // MARK: - Enumeration

    private func enumerate() -> [RawUsage] {
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard byteCount > 0 else { return [] }

        let capacity = Int(byteCount) / MemoryLayout<pid_t>.size + 32
        var pids = [pid_t](repeating: 0, count: capacity)
        let written = proc_listpids(
            UInt32(PROC_ALL_PIDS), 0,
            &pids, Int32(capacity * MemoryLayout<pid_t>.size)
        )
        guard written > 0 else { return [] }

        let count = Int(written) / MemoryLayout<pid_t>.size
        var results: [RawUsage] = []
        results.reserveCapacity(count)

        for i in 0..<count {
            let pid = pids[i]
            guard pid > 0 else { continue }
            guard let usage = rusage(pid) else { continue }

            // Only count processes with a real memory footprint.
            guard usage.resident > 0 else { continue }

            let name = executableName(pid) ?? "pid \(pid)"
            if name.isEmpty || name.hasPrefix("launchd") { continue }

            results.append(RawUsage(
                pid: pid,
                name: name,
                memory: usage.resident,
                cpuTime: usage.cpuTime
            ))
        }
        return results
    }

    private func rusage(_ pid: pid_t) -> (resident: UInt64, cpuTime: UInt64)? {
        var info = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &info) { pointer -> Int32 in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                proc_pid_rusage(pid, RUSAGE_INFO_V2, rebound)
            }
        }
        guard result == 0 else { return nil }
        return (
            resident: UInt64(info.ri_resident_size),
            cpuTime: UInt64(info.ri_user_time) &+ UInt64(info.ri_system_time)
        )
    }

    private func executableName(_ pid: pid_t) -> String? {
        var buffer = [UInt8](repeating: 0, count: 4096) // PROC_PIDPATHINFO_MAXSIZE
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        let path = String(cString: buffer)
        let base = (path as NSString).lastPathComponent
        return base.isEmpty ? nil : base
    }
}
