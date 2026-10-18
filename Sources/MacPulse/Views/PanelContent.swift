import SwiftUI

/// Scrollable body of the popover, split out so it can be rendered or
/// previewed independently of the fixed header/footer chrome.
struct PanelContent: View {
    @ObservedObject var model: AppModel
    @ObservedObject var engine: SamplingEngine

    var body: some View {
        VStack(spacing: Theme.Space.m) {
            headlineMetrics
            cpuCard
            memoryCard
            if engine.battery.isPresent { batteryCard }
            networkCard
            storageCard
            temperaturesCard
            if model.showProcesses { processesCard }
        }
        .padding(Theme.Space.l)
    }

    // MARK: - Headline

    private var headlineMetrics: some View {
        HStack(spacing: 0) {
            Metric(
                label: "CPU",
                value: Format.percent(engine.cpu.total),
                unit: "%",
                tint: LoadLevel(engine.cpu.total).color,
                size: 24
            )
            Rectangle().fill(Theme.border).frame(width: 1, height: 30)
            Metric(
                label: "Memory",
                value: Format.percent(engine.memory.usedRatio),
                unit: "%",
                tint: LoadLevel(engine.memory.usedRatio).color,
                size: 24
            )
            Rectangle().fill(Theme.border).frame(width: 1, height: 30)
            Metric(
                label: model.fahrenheit ? "Warmest °F" : "Warmest °C",
                value: engine.temperatures.hottest > 0
                    ? Format.temperature(engine.temperatures.hottest, fahrenheit: model.fahrenheit)
                    : "—",
                tint: Theme.ink,
                size: 24
            )
        }
        .padding(.vertical, Theme.Space.s)
    }

    // MARK: - CPU

    private var cpuCard: some View {
        Card(padding: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(title: "Processor")
                    Spacer()
                    MicroLabel(text: "\(engine.cpu.coreCount) cores")
                }
                // Sparkline sits in a banded strip so it reads as a chart, not a rule.
                Sparkline(values: engine.cpuHistory, tint: LoadLevel(engine.cpu.total).color)
                    .frame(height: 44)
                    .background(Theme.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.s))
                    .overlay(alignment: .topLeading) {
                        MicroLabel(text: "60s").padding(5)
                    }
                coreGrid
                HStack(spacing: Theme.Space.l) {
                    StatRow(key: "User", value: Format.percent(engine.cpu.user) + "%")
                    StatRow(key: "System", value: Format.percent(engine.cpu.system) + "%")
                }
                StatRow(key: "Load average", value: String(format: "%.2f  %.2f  %.2f",
                                                          engine.cpu.load1, engine.cpu.load5, engine.cpu.load15))
            }
        }
    }

    private var coreGrid: some View {
        let cores = engine.cpu.cores
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(cores.enumerated()), id: \.offset) { _, value in
                VStack(spacing: 3) {
                    MeterBar(ratio: value, tint: LoadLevel(value).color, height: 6)
                    Text(Format.percent(value) + "%")
                        .font(Theme.Typeface.mono(8))
                        .foregroundStyle(Theme.inkTertiary)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Memory

    private var memoryCard: some View {
        Card(padding: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(title: "Memory")
                    Spacer()
                    MicroLabel(text: Format.bytes(engine.memory.total))
                }
                Sparkline(values: engine.memoryHistory, tint: LoadLevel(engine.memory.usedRatio).color)
                    .frame(height: 34)
                    .background(Theme.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.s))
                SegmentedBar(segments: [
                    .init(value: Double(engine.memory.active), color: Theme.accentBlue, label: "App"),
                    .init(value: Double(engine.memory.wired), color: Theme.inkSecondary, label: "Wired"),
                    .init(value: Double(engine.memory.compressed), color: Theme.accentYellow, label: "Compressed"),
                    .init(value: Double(engine.memory.cached), color: Theme.accentGreen.opacity(0.55), label: "Cached")
                ])
                HStack(spacing: Theme.Space.m) {
                    LegendDot(color: Theme.accentBlue, label: "App")
                    LegendDot(color: Theme.inkSecondary, label: "Wired")
                    LegendDot(color: Theme.accentYellow, label: "Comp")
                    LegendDot(color: Theme.accentGreen.opacity(0.55), label: "Cache")
                    Spacer()
                }
                StatRow(key: "Used", value: Format.bytes(engine.memory.used))
                if engine.memory.swapTotal > 0 {
                    StatRow(key: "Swap", value: Format.bytes(engine.memory.swapUsed))
                }
            }
        }
    }

    // MARK: - Battery

    private var batteryCard: some View {
        Card(padding: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(title: "Battery")
                    Spacer()
                    StatusChip(
                        text: batteryStatusText,
                        fg: engine.battery.isCharging ? Theme.accentGreen : Theme.inkSecondary,
                        bg: engine.battery.isCharging ? Theme.accentGreenBg : Theme.surfaceSunken
                    )
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(Format.percent(engine.battery.percentage / 100))
                        .font(Theme.Typeface.numeric(28))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("%")
                        .font(Theme.Typeface.caption(11))
                        .foregroundStyle(Theme.inkTertiary)
                    Spacer()
                    if let minutes = engine.battery.timeRemainingMinutes {
                        VStack(alignment: .trailing, spacing: 1) {
                            MicroLabel(text: engine.battery.isCharging ? "Until full" : "Remaining")
                            Text(Format.minutes(minutes))
                                .font(Theme.Typeface.numeric(12, weight: .medium))
                                .foregroundStyle(Theme.inkSecondary)
                        }
                    }
                }
                MeterBar(ratio: engine.battery.percentage / 100, tint: Theme.ink, height: 5)
                HStack {
                    MicroLabel(text: "Cycles \(engine.battery.cycleCount)")
                    Spacer()
                    MicroLabel(text: "Health \(Format.percent(engine.battery.health))%")
                }
            }
        }
    }

    private var batteryStatusText: String {
        if engine.battery.isCharging { return "Charging" }
        if engine.battery.fullyCharged && engine.battery.isPluggedIn { return "Charged" }
        return engine.battery.isPluggedIn ? "AC Power" : "On battery"
    }

    // MARK: - Network

    private var networkCard: some View {
        Card(padding: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(title: "Network")
                    Spacer()
                    MicroLabel(text: engine.network.interfaceName.isEmpty ? "offline" : engine.network.interfaceName)
                }
                HStack(spacing: Theme.Space.m) {
                    rateReadout(label: "Down", value: engine.network.downloadBytesPerSec,
                                symbol: "arrow.down", tint: Theme.accentBlue)
                    rateReadout(label: "Up", value: engine.network.uploadBytesPerSec,
                                symbol: "arrow.up", tint: Theme.accentGreen)
                }
                Sparkline(values: engine.downloadHistory, tint: Theme.accentBlue,
                          capacity: autoScale(engine.downloadHistory))
                    .frame(height: 30)
                    .background(Theme.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.s))
                if let ip = engine.network.localIP {
                    StatRow(key: "Local address", value: ip)
                }
            }
        }
    }

    private func rateReadout(label: String, value: Double, symbol: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                MicroLabel(text: label)
                Text(Format.rate(value))
                    .font(Theme.Typeface.numeric(11, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Storage

    private var storageCard: some View {
        Card(padding: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(title: "Storage")
                    Spacer()
                    MicroLabel(text: engine.storage.volumeName)
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(Format.percent(engine.storage.usedRatio))
                        .font(Theme.Typeface.numeric(22))
                        .foregroundStyle(LoadLevel(engine.storage.usedRatio).color)
                        .contentTransition(.numericText())
                    Text("%")
                        .font(Theme.Typeface.caption(10))
                        .foregroundStyle(Theme.inkTertiary)
                    Spacer()
                    Text(Format.bytes(engine.storage.free) + " free")
                        .font(Theme.Typeface.numeric(10, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary)
                }
                MeterBar(
                    ratio: engine.storage.usedRatio,
                    tint: LoadLevel(engine.storage.usedRatio).color,
                    height: 5
                )
                HStack {
                    MicroLabel(text: Format.bytes(engine.storage.used) + " used")
                    Spacer()
                    MicroLabel(text: Format.bytes(engine.storage.total) + " total")
                }
            }
        }
    }

    // MARK: - Thermals

    private var temperaturesCard: some View {
        Card(padding: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(title: "Thermals")
                    Spacer()
                    MicroLabel(text: "\(engine.temperatures.readings.count) sensors")
                }
                if engine.temperatures.readings.isEmpty {
                    EmptyState(message: "Sensors unavailable")
                } else {
                    HStack(spacing: Theme.Space.m) {
                        if let cpu = engine.temperatures.cpuTemperature {
                            temperatureMetric(label: "CPU", celsius: cpu)
                        }
                        if let soc = engine.temperatures.socTemperature {
                            temperatureMetric(label: "SOC", celsius: soc)
                        }
                        if let gpu = engine.temperatures.gpuTemperature {
                            temperatureMetric(label: "GPU", celsius: gpu)
                        }
                    }
                }
            }
        }
    }

    private func temperatureMetric(label: String, celsius: Double) -> some View {
        Metric(
            label: label,
            value: Format.temperature(celsius, fahrenheit: model.fahrenheit),
            tint: LoadLevel(normalizeTemperature(celsius)).color,
            size: 18
        )
    }

    private func normalizeTemperature(_ celsius: Double) -> Double {
        min(max((celsius - 35) / 60, 0), 1)
    }

    // MARK: - Processes

    private var processesCard: some View {
        Card(padding: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                SectionHeader(title: "Top Processes")
                if engine.processes.isEmpty {
                    EmptyState(message: "Collecting data")
                } else {
                    ForEach(engine.processes.prefix(5)) { proc in
                        HStack(spacing: Theme.Space.s) {
                            Text(proc.name)
                                .font(Theme.Typeface.caption(11))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Spacer(minLength: Theme.Space.s)
                            Text(Format.percent(proc.cpu / 100))
                                .font(Theme.Typeface.numeric(10, weight: .medium))
                                .foregroundStyle(Theme.inkSecondary)
                                .monospacedDigit()
                                .frame(width: 28, alignment: .trailing)
                            Text(Format.bytes(proc.memory))
                                .font(Theme.Typeface.mono(9))
                                .foregroundStyle(Theme.inkTertiary)
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func autoScale(_ values: [Double]) -> Double {
        let peak = values.max() ?? 0
        return peak > 0 ? peak : 1_048_576
    }
}

/// Compact colour swatch + label used in legends.
struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 5, height: 5)
            Text(label)
                .font(Theme.Typeface.mono(8))
                .foregroundStyle(Theme.inkTertiary)
        }
    }
}
