import XCTest
import Foundation

@testable import MacPulse

/// Sampler tests touch real hardware, so they assert on invariants and ranges
/// rather than exact values. They are written to pass on both Apple Silicon and
/// Intel Macs, and to skip gracefully where a sensor is absent.
final class SamplerTests: XCTestCase {

    // MARK: - CPU

    func testCPUProducesPerCoreValues() {
        let sampler = CPUSampler()
        _ = sampler.sample()                  // baseline
        Thread.sleep(forTimeInterval: 0.15)
        let snapshot = sampler.sample()

        XCTAssertGreaterThan(snapshot.coreCount, 0)
        XCTAssertEqual(snapshot.cores.count, snapshot.coreCount)
        for core in snapshot.cores {
            XCTAssertTrue((0...1).contains(core), "core ratio out of range: \(core)")
        }
        XCTAssertTrue((0...1).contains(snapshot.total))
    }

    func testCPULoadAveragesAreNonNegative() {
        let sampler = CPUSampler()
        _ = sampler.sample()
        Thread.sleep(forTimeInterval: 0.1)
        let snapshot = sampler.sample()

        XCTAssertGreaterThanOrEqual(snapshot.load1, 0)
        XCTAssertGreaterThanOrEqual(snapshot.load5, 0)
        XCTAssertGreaterThanOrEqual(snapshot.load15, 0)
    }

    // MARK: - Memory

    func testMemoryTotals() {
        let snapshot = MemorySampler().sample()

        XCTAssertGreaterThan(snapshot.total, 0)
        XCTAssertGreaterThan(snapshot.active, 0)
        XCTAssertLessThanOrEqual(snapshot.used, snapshot.total + snapshot.compressed)
        XCTAssertTrue((0...1).contains(snapshot.usedRatio))
    }

    func testMemoryPressureLevelIsKnown() {
        let level = MemorySampler().sample().pressureLevel
        XCTAssertTrue([MemoryPressureLevel.normal, .warning, .critical].contains(level))
    }

    // MARK: - Storage

    func testStorageCapacity() {
        let snapshot = StorageSampler().sample()

        XCTAssertGreaterThan(snapshot.total, 0)
        XCTAssertLessThanOrEqual(snapshot.free, snapshot.total)
        XCTAssertTrue((0...1).contains(snapshot.usedRatio))
        XCTAssertFalse(snapshot.volumeName.isEmpty)
    }

    // MARK: - Battery

    func testBatterySnapshotIsCoherent() {
        let snapshot = BatterySampler().sample()

        // Desktops have no battery; only assert when one is present.
        guard snapshot.isPresent else {
            XCTAssertEqual(snapshot.percentage, 0)
            return
        }
        XCTAssertTrue((0...100).contains(snapshot.percentage))
        XCTAssertGreaterThanOrEqual(snapshot.cycleCount, 0)
        XCTAssertGreaterThanOrEqual(snapshot.voltage, 0)
    }

    // MARK: - Network

    func testNetworkCountersAreMonotonic() {
        let sampler = NetworkSampler()
        let first = sampler.sample()
        Thread.sleep(forTimeInterval: 0.3)
        let second = sampler.sample()

        XCTAssertGreaterThanOrEqual(second.totalReceived, first.totalReceived)
        XCTAssertGreaterThanOrEqual(second.totalSent, first.totalSent)
    }

    // MARK: - Processes

    func testProcessesAreSortedAndBounded() {
        let sampler = ProcessSampler()
        _ = sampler.sample(limit: 8)
        Thread.sleep(forTimeInterval: 0.2)
        let entries = sampler.sample(limit: 5)

        XCTAssertLessThanOrEqual(entries.count, 5)
        XCTAssertFalse(entries.isEmpty, "expected at least one process")
        for entry in entries {
            XCTAssertGreaterThan(entry.pid, 0)
            XCTAssertFalse(entry.name.isEmpty)
            XCTAssertGreaterThanOrEqual(entry.cpu, 0)
            XCTAssertGreaterThan(entry.memory, 0)
        }
        // Sorted by CPU descending, then memory.
        for (a, b) in zip(entries, entries.dropFirst()) {
            XCTAssertTrue(a.cpu > b.cpu || abs(a.cpu - b.cpu) <= 0.5)
        }
    }

    // MARK: - Temperatures

    func testTemperatureReadingsAreInPhysicalRange() {
        let snapshot = TemperatureSampler().sample()

        // Sensor availability varies by model; do not fail when absent.
        guard snapshot.available else { return }

        XCTAssertGreaterThan(snapshot.readings.count, 0)
        for reading in snapshot.readings {
            XCTAssertGreaterThan(reading.celsius, 0)
            XCTAssertLessThan(reading.celsius, 130)
            XCTAssertFalse(reading.label.isEmpty)
        }
        // Sorted hottest first.
        let temps = snapshot.readings.map(\.celsius)
        XCTAssertEqual(temps, temps.sorted(by: >))
        XCTAssertEqual(snapshot.hottest, temps.first ?? 0)
    }

    func testFahrenheitConversion() {
        let reading = TemperatureReading(id: "t", sensor: "S", label: "S", celsius: 0)
        XCTAssertEqual(reading.fahrenheit, 32, accuracy: 0.001)
    }
}

/// The engine publishes on the main actor, so these run there.
@MainActor
final class SamplingEngineTests: XCTestCase {

    func testPrimePopulatesEverySnapshot() {
        let engine = SamplingEngine()
        engine.prime()

        XCTAssertGreaterThan(engine.cpu.coreCount, 0)
        XCTAssertGreaterThan(engine.memory.total, 0)
        XCTAssertGreaterThan(engine.storage.total, 0)
        XCTAssertFalse(engine.cpuHistory.isEmpty)
        XCTAssertFalse(engine.memoryHistory.isEmpty)

        XCTAssertTrue((0...1).contains(engine.cpu.total))
        XCTAssertTrue((0...1).contains(engine.memory.usedRatio))
    }

    func testHistoryIsBounded() {
        let engine = SamplingEngine()
        engine.prime()
        // Prime twice more; history must not grow without bound.
        for _ in 0..<5 { engine.refreshNow() }
        XCTAssertLessThanOrEqual(engine.cpuHistory.count, 61)
        XCTAssertLessThanOrEqual(engine.memoryHistory.count, 61)
    }

    func testMenuBarTextFollowsStyle() {
        let engine = SamplingEngine()
        engine.prime()
        let model = AppModel(engine: engine)

        model.menuBarStyle = .cpu
        XCTAssertTrue(model.menuBarText.hasSuffix("%"))

        model.menuBarStyle = .iconOnly
        XCTAssertTrue(model.menuBarText.isEmpty)
    }
}
