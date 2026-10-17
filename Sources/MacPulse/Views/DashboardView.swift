import SwiftUI

/// Full window with a sidebar of modules and a detail pane — the place where
/// each sampler gets room to breathe beyond the compact menu bar popover.
struct DashboardView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var engine: SamplingEngine

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            ScrollView {
                detail
                    .padding(Theme.Space.xxl)
                    .frame(maxWidth: 720, alignment: .leading)
            }
            .background(Theme.canvas)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, minHeight: 560)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MacPulse")
                    .font(Theme.Typeface.title(20))
                    .foregroundStyle(Theme.ink)
                MicroLabel(text: "System Monitor")
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, Theme.Space.l)
            .padding(.bottom, Theme.Space.l)

            ForEach(DetailPane.allCases) { pane in
                sidebarRow(pane)
            }

            Spacer()
        }
        .frame(width: 190)
        .background(Theme.surfaceSunken)
    }

    private func sidebarRow(_ pane: DetailPane) -> some View {
        let selected = (model.activePane ?? .cpu) == pane
        return Button {
            model.activePane = pane
        } label: {
            HStack(spacing: Theme.Space.s) {
                Image(systemName: pane.symbol)
                    .font(.system(size: 11, weight: .regular))
                    .frame(width: 16)
                Text(pane.title)
                    .font(Theme.Typeface.body(12))
                Spacer()
            }
            .foregroundStyle(selected ? Theme.ink : Theme.inkSecondary)
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, 7)
            .background(selected ? Theme.surface : Color.clear)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(selected ? Theme.ink : Color.clear)
                    .frame(width: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch model.activePane ?? .cpu {
        case .cpu:          CPUDashboard(engine: engine)
        case .memory:       MemoryDashboard(engine: engine)
        case .battery:      BatteryDashboard(engine: engine)
        case .network:      NetworkDashboard(engine: engine)
        case .storage:      StorageDashboard(engine: engine)
        case .processes:    ProcessesDashboard(engine: engine)
        case .temperatures: TemperaturesDashboard(engine: engine, model: model)
        }
    }
}

// MARK: - Shared header

struct DashboardHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.Typeface.display(26))
                .foregroundStyle(Theme.ink)
            MicroLabel(text: subtitle)
        }
        .padding(.bottom, Theme.Space.l)
    }
}

// MARK: - CPU

struct CPUDashboard: View {
    @ObservedObject var engine: SamplingEngine

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            DashboardHeader(title: "Processor", subtitle: "\(engine.cpu.coreCount) logical cores")

            HStack(spacing: Theme.Space.l) {
                Metric(label: "Total load", value: Format.percent(engine.cpu.total), unit: "%",
                       tint: LoadLevel(engine.cpu.total).color, size: 34)
                Metric(label: "User", value: Format.percent(engine.cpu.user), unit: "%", size: 34)
                Metric(label: "System", value: Format.percent(engine.cpu.system), unit: "%", size: 34)
                Metric(label: "Idle", value: Format.percent(engine.cpu.idle), unit: "%", size: 34)
            }

            Card {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    SectionHeader(title: "Load history", trailing: "60 samples")
                    Sparkline(values: engine.cpuHistory, tint: LoadLevel(engine.cpu.total).color)
                        .frame(height: 100)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    SectionHeader(title: "Per-core")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Space.l), count: 2),
                              spacing: Theme.Space.m) {
                        ForEach(Array(engine.cpu.cores.enumerated()), id: \.offset) { item in
                            HStack(spacing: Theme.Space.s) {
                                Text("Core \(item.offset)")
                                    .font(Theme.Typeface.mono(10))
                                    .foregroundStyle(Theme.inkTertiary)
                                    .frame(width: 52, alignment: .leading)
                                MeterBar(ratio: item.element, tint: LoadLevel(item.element).color, height: 6)
                                Text(Format.percent(item.element) + "%")
                                    .font(Theme.Typeface.numeric(10, weight: .medium))
                                    .foregroundStyle(Theme.ink)
                                    .frame(width: 34, alignment: .trailing)
                            }
                        }
                    }
                }
            }

            Card {
                VStack(spacing: Theme.Space.s) {
                    StatRow(key: "Load average (1m)", value: String(format: "%.2f", engine.cpu.load1))
                    StatRow(key: "Load average (5m)", value: String(format: "%.2f", engine.cpu.load5))
                    StatRow(key: "Load average (15m)", value: String(format: "%.2f", engine.cpu.load15))
                }
            }
        }
    }
}

// MARK: - Memory

struct MemoryDashboard: View {
    @ObservedObject var engine: SamplingEngine

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            DashboardHeader(title: "Memory", subtitle: Format.bytes(engine.memory.total) + " physical")
            HStack(spacing: Theme.Space.l) {
                Metric(label: "Used", value: Format.bytes(engine.memory.used), tint: LoadLevel(engine.memory.usedRatio).color, size: 30)
                Metric(label: "Free", value: Format.bytes(engine.memory.free), size: 30)
                Metric(label: "Pressure", value: engine.memory.pressureLevel.rawValue,
                       tint: LoadLevel(engine.memory.usedRatio).color, size: 30)
            }
            Card {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    SectionHeader(title: "Breakdown")
                    SegmentedBar(segments: [
                        .init(value: Double(engine.memory.active), color: Theme.accentBlue, label: "App"),
                        .init(value: Double(engine.memory.wired), color: Theme.inkSecondary, label: "Wired"),
                        .init(value: Double(engine.memory.compressed), color: Theme.accentYellow, label: "Compressed"),
                        .init(value: Double(engine.memory.cached), color: Theme.accentGreen.opacity(0.55), label: "Cached"),
                        .init(value: Double(engine.memory.free), color: Theme.border, label: "Free")
                    ], height: 10)
                    LegendItem(color: Theme.accentBlue, label: "App memory", value: Format.bytes(engine.memory.active))
                    LegendItem(color: Theme.inkSecondary, label: "Wired", value: Format.bytes(engine.memory.wired))
                    LegendItem(color: Theme.accentYellow, label: "Compressed", value: Format.bytes(engine.memory.compressed))
                    LegendItem(color: Theme.accentGreen.opacity(0.55), label: "Cached files", value: Format.bytes(engine.memory.cached))
                    LegendItem(color: Theme.border, label: "Free", value: Format.bytes(engine.memory.free))
                }
            }
            Card {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    SectionHeader(title: "Usage history")
                    Sparkline(values: engine.memoryHistory, tint: LoadLevel(engine.memory.usedRatio).color)
                        .frame(height: 90)
                }
            }
            if engine.memory.swapTotal > 0 {
                Card {
                    VStack(spacing: Theme.Space.s) {
                        StatRow(key: "Swap used", value: Format.bytes(engine.memory.swapUsed))
                        StatRow(key: "Swap total", value: Format.bytes(engine.memory.swapTotal))
                    }
                }
            }
        }
    }
}

// MARK: - Battery

struct BatteryDashboard: View {
    @ObservedObject var engine: SamplingEngine

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            DashboardHeader(title: "Battery", subtitle: engine.battery.isPresent ? "Internal battery" : "No battery")
            if engine.battery.isPresent {
                HStack(spacing: Theme.Space.l) {
                    Metric(label: "Charge", value: Format.percent(engine.battery.percentage / 100), unit: "%", size: 34)
                    Metric(label: "Health", value: Format.percent(engine.battery.health), unit: "%", size: 34)
                    Metric(label: "Cycles", value: "\(engine.battery.cycleCount)", size: 34)
                }
                Card {
                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        MeterBar(ratio: engine.battery.percentage / 100, tint: Theme.ink, height: 10)
                        HStack {
                            StatusChip(text: batteryState, fg: Theme.inkSecondary, bg: Theme.surfaceSunken)
                            Spacer()
                            if let mins = engine.battery.timeRemainingMinutes {
                                Text(Format.minutes(mins))
                                    .font(Theme.Typeface.numeric(12, weight: .medium))
                                    .foregroundStyle(Theme.inkSecondary)
                            }
                        }
                    }
                }
                Card {
                    VStack(spacing: Theme.Space.s) {
                        StatRow(key: "Design capacity", value: "\(engine.battery.designCapacity) mAh")
                        StatRow(key: "Full charge capacity", value: "\(engine.battery.maxCapacity) mAh")
                        StatRow(key: "Voltage", value: String(format: "%.2f V", engine.battery.voltage))
                        StatRow(key: "Draw", value: Format.watts(engine.battery.watts))
                        if engine.battery.temperature > 0 {
                            StatRow(key: "Temperature", value: String(format: "%.1f °C", engine.battery.temperature))
                        }
                    }
                }
            } else {
                EmptyState(message: "This Mac has no internal battery")
            }
        }
    }

    private var batteryState: String {
        if engine.battery.isCharging { return "Charging" }
        if engine.battery.fullyCharged { return "Fully charged" }
        return engine.battery.isPluggedIn ? "AC power" : "Discharging"
    }
}

// MARK: - Network

struct NetworkDashboard: View {
    @ObservedObject var engine: SamplingEngine

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            DashboardHeader(title: "Network", subtitle: engine.network.interfaceName.isEmpty ? "No interface" : engine.network.interfaceName)
            HStack(spacing: Theme.Space.l) {
                Metric(label: "Download", value: Format.rate(engine.network.downloadBytesPerSec), tint: Theme.accentBlue, size: 26)
                Metric(label: "Upload", value: Format.rate(engine.network.uploadBytesPerSec), tint: Theme.accentGreen, size: 26)
            }
            Card {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    SectionHeader(title: "Download history")
                    Sparkline(values: engine.downloadHistory, tint: Theme.accentBlue,
                              capacity: max(engine.downloadHistory.max() ?? 0, 1))
                        .frame(height: 80)
                    SectionHeader(title: "Upload history")
                    Sparkline(values: engine.uploadHistory, tint: Theme.accentGreen,
                              capacity: max(engine.uploadHistory.max() ?? 0, 1))
                        .frame(height: 80)
                }
            }
            Card {
                VStack(spacing: Theme.Space.s) {
                    if let ip = engine.network.localIP {
                        StatRow(key: "Local address", value: ip)
                    }
                    StatRow(key: "Interface", value: engine.network.interfaceName.isEmpty ? "—" : engine.network.interfaceName)
                    StatRow(key: "Total received", value: Format.bytes(engine.network.totalReceived))
                    StatRow(key: "Total sent", value: Format.bytes(engine.network.totalSent))
                }
            }
        }
    }
}

// MARK: - Storage

struct StorageDashboard: View {
    @ObservedObject var engine: SamplingEngine

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            DashboardHeader(title: "Storage", subtitle: engine.storage.volumeName)
            HStack(spacing: Theme.Space.l) {
                Metric(label: "Used", value: Format.bytes(engine.storage.used), size: 30)
                Metric(label: "Free", value: Format.bytes(engine.storage.free), size: 30)
                Metric(label: "Capacity", value: Format.bytes(engine.storage.total), size: 30)
            }
            Card {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    SectionHeader(title: "Capacity")
                    MeterBar(ratio: engine.storage.usedRatio,
                             tint: LoadLevel(engine.storage.usedRatio).color, height: 12)
                    HStack {
                        MicroLabel(text: "\(Format.percent(engine.storage.usedRatio))% used")
                        Spacer()
                        MicroLabel(text: Format.bytes(engine.storage.free) + " available")
                    }
                }
            }
        }
    }
}

// MARK: - Processes

struct ProcessesDashboard: View {
    @ObservedObject var engine: SamplingEngine

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            DashboardHeader(title: "Processes", subtitle: "Top \(engine.processes.count) by CPU")
            Card {
                VStack(spacing: 0) {
                    HStack {
                        MicroLabel(text: "Process")
                        Spacer()
                        MicroLabel(text: "CPU").frame(width: 50, alignment: .trailing)
                        MicroLabel(text: "Memory").frame(width: 70, alignment: .trailing)
                    }
                    .padding(.bottom, Theme.Space.s)
                    Hairline()
                    ForEach(engine.processes) { proc in
                        HStack {
                            Text(proc.name)
                                .font(Theme.Typeface.body(12))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Text("\(proc.pid)")
                                .font(Theme.Typeface.mono(9))
                                .foregroundStyle(Theme.inkTertiary)
                            Spacer()
                            Text(Format.percent(proc.cpu / 100) + "%")
                                .font(Theme.Typeface.numeric(11, weight: .medium))
                                .foregroundStyle(Theme.inkSecondary)
                                .frame(width: 50, alignment: .trailing)
                            Text(Format.bytes(proc.memory))
                                .font(Theme.Typeface.mono(10))
                                .foregroundStyle(Theme.inkTertiary)
                                .frame(width: 70, alignment: .trailing)
                        }
                        .padding(.vertical, 6)
                        Hairline()
                    }
                }
            }
        }
    }
}

// MARK: - Temperatures

struct TemperaturesDashboard: View {
    @ObservedObject var engine: SamplingEngine
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            DashboardHeader(title: "Temperatures",
                            subtitle: "\(engine.temperatures.readings.count) sensors")
            HStack(spacing: Theme.Space.l) {
                if let cpu = engine.temperatures.cpuTemperature {
                    Metric(label: "CPU cluster", value: Format.temperature(cpu, fahrenheit: model.fahrenheit), size: 30)
                }
                if let soc = engine.temperatures.socTemperature {
                    Metric(label: "SOC die", value: Format.temperature(soc, fahrenheit: model.fahrenheit), size: 30)
                }
                if let gpu = engine.temperatures.gpuTemperature {
                    Metric(label: "GPU", value: Format.temperature(gpu, fahrenheit: model.fahrenheit), size: 30)
                }
            }
            Card {
                VStack(spacing: 0) {
                    HStack {
                        MicroLabel(text: "Sensor")
                        Spacer()
                        MicroLabel(text: model.fahrenheit ? "°F" : "°C")
                    }
                    .padding(.bottom, Theme.Space.s)
                    Hairline()
                    if engine.temperatures.readings.isEmpty {
                        EmptyState(message: "Sensors unavailable")
                    } else {
                        ForEach(engine.temperatures.readings) { reading in
                            HStack(spacing: Theme.Space.m) {
                                Text(reading.label)
                                    .font(Theme.Typeface.body(11))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Spacer()
                                MeterBar(ratio: min(reading.celsius / 110, 1),
                                         tint: LoadLevel((reading.celsius - 35) / 60).color,
                                         height: 4)
                                    .frame(width: 90)
                                Text(Format.temperature(reading.celsius, fahrenheit: model.fahrenheit))
                                    .font(Theme.Typeface.numeric(11, weight: .medium))
                                    .foregroundStyle(Theme.ink)
                                    .frame(width: 42, alignment: .trailing)
                            }
                            .padding(.vertical, 5)
                            Hairline()
                        }
                    }
                }
            }
        }
    }
}
