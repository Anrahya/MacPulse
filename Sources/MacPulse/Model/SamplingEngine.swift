import Foundation
import SwiftUI
import Combine

/// Owns all samplers and publishes snapshots on a shared cadence.
///
/// Heavy work (process enumeration, temperature reads) runs off the main
/// thread; snapshots are published back on the main queue.
@MainActor
final class SamplingEngine: ObservableObject {

    @Published private(set) var cpu = CPUSnapshot()
    @Published private(set) var memory = MemorySnapshot()
    @Published private(set) var battery = BatterySnapshot()
    @Published private(set) var network = NetworkSnapshot()
    @Published private(set) var storage = StorageSnapshot()
    @Published private(set) var processes: [ProcessEntry] = []
    @Published private(set) var temperatures = TemperatureSnapshot()

    /// Rolling history for sparklines, newest last.
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var memoryHistory: [Double] = []
    @Published private(set) var downloadHistory: [Double] = []
    @Published private(set) var uploadHistory: [Double] = []

    private let cpuSampler = CPUSampler()
    private let memorySampler = MemorySampler()
    private let batterySampler = BatterySampler()
    private let networkSampler = NetworkSampler()
    private let storageSampler = StorageSampler()
    private let processSampler = ProcessSampler()
    private let temperatureSampler = TemperatureSampler()

    private var fastTimer: Timer?
    private var slowTimer: Timer?
    private let historyLimit = 60

    /// Sampling cadence in seconds, user-configurable.
    var interval: TimeInterval = 2 {
        didSet { if interval != oldValue { restart() } }
    }

    private var isRunning = false

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Seed every sampler once so the first frame shows real values and
        // delta-based samplers have a baseline to compare against.
        prime()

        // Bind strongly before entering the Task: reading the weak `self`
        // inside concurrent code is what Swift 6 rejects. The timer holds the
        // closure, and the closure captures `self` weakly, so no cycle forms.
        fastTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tickFast() }
        }
        slowTimer = Timer.scheduledTimer(withTimeInterval: max(interval * 2, 4), repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tickSlow() }
        }
    }

    /// Fills every published property synchronously so the first frame of the
    /// popover has real values instead of zeros. Cheap enough to run on the
    /// main thread once at launch (~2 ms).
    func prime() {
        cpu = cpuSampler.sample()
        memory = memorySampler.sample()
        network = networkSampler.sample()
        battery = batterySampler.sample()
        storage = storageSampler.sample()
        processes = processSampler.sample(limit: 8)
        temperatures = temperatureSampler.sample()

        cpuHistory = [cpu.total]
        memoryHistory = [memory.usedRatio]
        downloadHistory = [network.downloadBytesPerSec]
        uploadHistory = [network.uploadBytesPerSec]
    }

    func stop() {
        fastTimer?.invalidate(); fastTimer = nil
        slowTimer?.invalidate(); slowTimer = nil
        isRunning = false
    }

    /// Runs one synchronous refresh of every metric.
    ///
    /// Used for the first paint and for manual refresh; the timers normally
    /// drive updates asynchronously.
    func refreshNow() {
        cpu = cpuSampler.sample()
        memory = memorySampler.sample()
        network = networkSampler.sample()
        battery = batterySampler.sample()
        storage = storageSampler.sample()
        processes = processSampler.sample(limit: 8)
        temperatures = temperatureSampler.sample()

        append(cpu.total, to: &cpuHistory)
        append(memory.usedRatio, to: &memoryHistory)
        append(network.downloadBytesPerSec, to: &downloadHistory)
        append(network.uploadBytesPerSec, to: &uploadHistory)
    }

    private func restart() {
        stop()
        start()
    }

    // MARK: - Ticks

    private func tickFast() {
        let cpuSampler = self.cpuSampler
        let memorySampler = self.memorySampler
        let networkSampler = self.networkSampler

        Task.detached(priority: .utility) {
            let cpu = cpuSampler.sample()
            let memory = memorySampler.sample()
            let network = networkSampler.sample()

            await MainActor.run {
                self.cpu = cpu
                self.memory = memory
                self.network = network
                self.append(self.cpu.total, to: &self.cpuHistory)
                self.append(memory.usedRatio, to: &self.memoryHistory)
                self.append(network.downloadBytesPerSec, to: &self.downloadHistory)
                self.append(network.uploadBytesPerSec, to: &self.uploadHistory)
            }
        }
    }

    private func tickSlow() {
        let batterySampler = self.batterySampler
        let storageSampler = self.storageSampler
        let processSampler = self.processSampler
        let temperatureSampler = self.temperatureSampler

        Task.detached(priority: .utility) {
            let battery = batterySampler.sample()
            let storage = storageSampler.sample()
            let processes = processSampler.sample(limit: 8)
            let temperatures = temperatureSampler.sample()

            await MainActor.run {
                self.battery = battery
                self.storage = storage
                self.processes = processes
                self.temperatures = temperatures
            }
        }
    }

    private func append(_ value: Double, to history: inout [Double]) {
        history.append(value)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
    }
}
