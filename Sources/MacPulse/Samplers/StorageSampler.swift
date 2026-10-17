import Foundation
import IOKit

/// Reads the boot volume's capacity using `statfs`.
final class StorageSampler {

    func sample() -> StorageSnapshot {
        var snapshot = StorageSnapshot()

        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") else {
            return snapshot
        }

        let total = (attrs[.systemSize] as? NSNumber)?.uint64Value ?? 0
        let free  = (attrs[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0

        snapshot.total = total
        snapshot.free = free

        if let name = volumeName() {
            snapshot.volumeName = name
        } else {
            snapshot.volumeName = "Macintosh HD"
        }
        return snapshot
    }

    private func volumeName() -> String? {
        let url = URL(fileURLWithPath: "/")
        return try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName
    }
}
