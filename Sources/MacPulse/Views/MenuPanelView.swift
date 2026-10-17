import SwiftUI
import AppKit

/// The popover shown when the menu bar item is clicked.
struct MenuPanelView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var engine: SamplingEngine

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()
            ScrollView {
                PanelContent(model: model, engine: engine)
            }
            .frame(maxHeight: 520)
            Hairline()
            footer
        }
        .frame(width: 320)
        .background(Theme.canvas)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MacPulse")
                    .font(Theme.Typeface.title(19))
                    .foregroundStyle(Theme.ink)
                MicroLabel(text: "System Monitor")
            }
            Spacer()
            StatusChip(
                text: overallStatus.label,
                fg: overallStatus.color,
                bg: overallStatus.color.opacity(0.12)
            )
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.l)
        .padding(.bottom, Theme.Space.m)
    }

    private var overallStatus: LoadLevel {
        LoadLevel(max(engine.cpu.total, engine.memory.usedRatio))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Theme.Space.m) {
            Button {
                openDashboard()
            } label: {
                Image(systemName: "macwindow")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .buttonStyle(.plain)
            .help("Open dashboard")

            Spacer()

            MicroLabel(text: "Live")

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .buttonStyle(.plain)
            .help("Quit MacPulse")
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.m)
    }

    private func openDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        // MenuBarExtra popovers have no window of their own to reorder; the
        // dashboard is the first Window scene, so ask AppKit to surface it.
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.contains("dashboard") == true })
            ?? NSApp.windows.first(where: { $0.canBecomeMain && $0.contentView != nil }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
