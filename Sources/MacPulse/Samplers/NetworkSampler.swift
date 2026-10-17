import Foundation
import Darwin

/// Reads aggregate network throughput by diffing the primary interface's
/// byte counters between samples.
final class NetworkSampler {

    private var previousReceived: UInt64 = 0
    private var previousSent: UInt64 = 0
    private var previousTime: Date?
    private var primaryInterface: String = ""
    private var internetReachable = true

    func sample() -> NetworkSnapshot {
        var snapshot = NetworkSnapshot()

        let interfaces = readInterfaces()

        // Prefer the busiest non-loopback interface as the active one.
        let active = interfaces
            .filter { !$0.name.hasPrefix("lo") && $0.received > 0 || !$0.name.hasPrefix("lo") && $0.sent > 0 }
            .max { ($0.received + $0.sent) < ($1.received + $1.sent) }
            ?? interfaces.first { !$0.name.hasPrefix("lo") }

        guard let active else {
            snapshot.isConnected = false
            snapshot.interfaceName = ""
            snapshot.localIP = nil
            return snapshot
        }

        snapshot.interfaceName = active.name
        snapshot.totalReceived = active.received
        snapshot.totalSent = active.sent
        snapshot.isConnected = active.isUp
        snapshot.localIP = active.ipv4

        let now = Date()
        if active.name == primaryInterface,
           let prevTime = previousTime,
           previousReceived <= active.received,
           previousSent <= active.sent {
            let elapsed = now.timeIntervalSince(prevTime)
            if elapsed > 0.05 {
                snapshot.downloadBytesPerSec = Double(active.received - previousReceived) / elapsed
                snapshot.uploadBytesPerSec   = Double(active.sent - previousSent) / elapsed
            }
        }

        primaryInterface = active.name
        previousReceived = active.received
        previousSent = active.sent
        previousTime = now

        return snapshot
    }

    // MARK: - Interface enumeration

    private struct InterfaceStats {
        var name: String
        var received: UInt64
        var sent: UInt64
        var isUp: Bool
        var ipv4: String?
    }

    private func readInterfaces() -> [InterfaceStats] {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return [] }
        defer { freeifaddrs(ifaddrPtr) }

        var names = Set<String>()
        var addresses: [String: String] = [:]
        var upFlags: [String: Bool] = [:]

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ptr = cursor {
            let ifa = ptr.pointee
            let name = String(cString: ifa.ifa_name)
            names.insert(name)

            let flags = Int32(bitPattern: ifa.ifa_flags)
            let isUp = (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0
            upFlags[name] = (upFlags[name] ?? false) || isUp

            if ifa.ifa_addr?.pointee.sa_family == UInt8(AF_INET) {
                var addr = ifa.ifa_addr!.pointee
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(&addr, socklen_t(addr.sa_len),
                               &host, socklen_t(host.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = String(cString: host)
                    if !ip.hasPrefix("127.") { addresses[name] = ip }
                }
            }
            cursor = ifa.ifa_next
        }

        return names
            .filter { $0 != "lo0" && !$0.hasPrefix("utun") && !$0.hasPrefix("awdl")
                   && !$0.hasPrefix("llw") && !$0.hasPrefix("bridge") && !$0.hasPrefix("anpi") }
            .compactMap { name in
                guard let (rx, tx) = interfaceBytes(name) else { return nil }
                return InterfaceStats(
                    name: name,
                    received: rx,
                    sent: tx,
                    isUp: upFlags[name] ?? false,
                    ipv4: addresses[name]
                )
            }
    }

    /// Reads the 64-bit byte counters via `sysctl NET_RT_IFLIST2`.
    private func interfaceBytes(_ name: String) -> (UInt64, UInt64)? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len: size_t = 0

        guard sysctl(&mib, u_int(mib.count), nil, &len, nil, 0) == 0, len > 0 else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: len)
        guard sysctl(&mib, u_int(mib.count), &buffer, &len, nil, 0) == 0 else {
            return nil
        }

        return buffer.withUnsafeBytes { raw -> (UInt64, UInt64)? in
            var offset = 0
            while offset + MemoryLayout<if_msghdr2>.size <= len {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                let msgLen = Int(header.ifm_msglen)
                guard msgLen > 0 else { break }

                if Int32(header.ifm_type) == RTM_IFINFO2 {
                    let index = Int(header.ifm_index)
                    if let resolved = nameForIndex(index), resolved == name {
                        return (UInt64(header.ifm_data.ifi_ibytes),
                                UInt64(header.ifm_data.ifi_obytes))
                    }
                }
                offset += msgLen
            }
            return nil
        }
    }

    private func nameForIndex(_ index: Int) -> String? {
        var name = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        guard if_indextoname(UInt32(index), &name) != nil else { return nil }
        return String(cString: name)
    }
}
