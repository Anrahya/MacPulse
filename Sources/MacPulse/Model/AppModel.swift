import SwiftUI
import Combine

enum DetailPane: String, CaseIterable, Identifiable {
    case cpu, memory, battery, network, storage, processes, temperatures
    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .battery: "Battery"
        case .network: "Network"
        case .storage: "Storage"
        case .processes: "Processes"
        case .temperatures: "Temps"
        }
    }

    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .battery: "battery.100"
        case .network: "arrow.up.arrow.down"
        case .storage: "internaldrive"
        case .processes: "list.bullet"
        case .temperatures: "thermometer.medium"
        }
    }
}

/// UI-facing state: navigation, presentation flags, user preferences.
@MainActor
final class AppModel: ObservableObject {

    @Published var activePane: DetailPane?
    @Published var showSettings = false
    @Published var showDashboard = false
    @Published var fahrenheit = false
    @Published var menuBarStyle: MenuBarStyle = .cpu
    @Published var samplingInterval: Double = 2
    @Published var showProcesses = true

    let engine: SamplingEngine

    init(engine: SamplingEngine? = nil) {
        self.engine = engine ?? SamplingEngine()
    }

    var menuBarText: String {
        switch menuBarStyle {
        case .cpu:    "\(Format.percent(engine.cpu.total))%"
        case .memory: "\(Format.percent(engine.memory.usedRatio))%"
        case .warmth:
            engine.temperatures.hottest > 0
                ? Format.temperature(engine.temperatures.hottest, fahrenheit: fahrenheit)
                : "—"
        case .battery: "\(Format.percent(engine.battery.percentage / 100))%"
        case .iconOnly: ""
        }
    }

    var menuBarSymbol: String {
        switch menuBarStyle {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .warmth: "thermometer.medium"
        case .battery: engine.battery.isCharging ? "battery.100.bolt" : "battery.75"
        case .iconOnly: "waveform.path.ecg"
        }
    }
}

enum MenuBarStyle: String, CaseIterable, Identifiable {
    case cpu, memory, warmth, battery, iconOnly
    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: "CPU load"
        case .memory: "Memory used"
        case .warmth: "Hottest sensor"
        case .battery: "Battery level"
        case .iconOnly: "Icon only"
        }
    }
}
