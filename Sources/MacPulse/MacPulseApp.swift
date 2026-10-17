import SwiftUI
import AppKit

@main
struct MacPulseApp: App {
    @StateObject private var engine: SamplingEngine
    @StateObject private var model: AppModel

    init() {
        let engine = SamplingEngine()
        _engine = StateObject(wrappedValue: engine)
        _model = StateObject(wrappedValue: AppModel(engine: engine))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView(model: model, engine: engine)
                .onAppear { engine.start() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.menuBarSymbol)
                    .font(.system(size: 11, weight: .regular))
                if model.menuBarStyle != .iconOnly {
                    Text(model.menuBarText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)

        Window("MacPulse", id: "dashboard") {
            DashboardView(model: model, engine: engine)
                .onAppear { engine.start() }
        }
        .defaultSize(width: 900, height: 620)
        .commandsRemoved()

        Settings {
            SettingsView(model: model)
                .onAppear { engine.start() }
        }
    }
}
