import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Hairline()
            Form {
                menuBarSection
                samplingSection
                unitsSection
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 380)
        .background(Theme.canvas)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Preferences")
                .font(Theme.Typeface.title(18))
                .foregroundStyle(Theme.ink)
            MicroLabel(text: "MacPulse")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Space.xl)
        .padding(.vertical, Theme.Space.l)
    }

    private var menuBarSection: some View {
        Section {
            Picker("Display", selection: $model.menuBarStyle) {
                ForEach(MenuBarStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.menu)
        } header: {
            MicroLabel(text: "Menu Bar")
        }
    }

    private var samplingSection: some View {
        Section {
            Picker("Refresh", selection: $model.samplingInterval) {
                Text("1 second").tag(1.0)
                Text("2 seconds").tag(2.0)
                Text("5 seconds").tag(5.0)
                Text("10 seconds").tag(10.0)
            }
            .pickerStyle(.menu)

            Toggle("Show process list", isOn: $model.showProcesses)
        } header: {
            MicroLabel(text: "Sampling")
        }
    }

    private var unitsSection: some View {
        Section {
            Toggle("Show temperatures in Fahrenheit", isOn: $model.fahrenheit)
        } header: {
            MicroLabel(text: "Units")
        }
    }
}
