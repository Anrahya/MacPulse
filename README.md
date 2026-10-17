# MacPulse

A macOS menu bar system monitor. Native SwiftUI, no dependencies, no Xcode required.

MacPulse watches CPU, memory, battery, network, storage, processes, and thermal
sensors, and surfaces them in a compact popover plus a full dashboard window.

## Requirements

- macOS 14 or later
- Xcode **or** just the Command Line Tools (`xcode-select --install`)

The project builds with Swift Package Manager, so a full Xcode install is not
required. On Apple Silicon, temperature readings work without root.

## Build and run

```bash
./scripts/build-app.sh          # release build → build/MacPulse.app
open build/MacPulse.app
```

For a faster iteration cycle:

```bash
swift build                     # compile only
./scripts/build-app.sh debug    # debug bundle
```

The app is a menu bar item (`LSUIElement`), so it has no Dock icon. Look for the
pulse glyph in the menu bar.

## Features

| Module | Source | Notes |
| --- | --- | --- |
| CPU | `host_processor_info` | Per-core deltas, user/system split, load averages |
| Memory | `host_statistics64`, `vm.swapusage` | App/wired/compressed/cached breakdown |
| Battery | `AppleSmartBattery` IORegistry | Charge, health, cycles, draw, temperature |
| Network | `sysctl NET_RT_IFLIST2` | Per-interface throughput from byte counters |
| Storage | `attributesOfFileSystem` | Boot volume capacity and free space |
| Processes | `libproc` (`proc_pid_rusage`) | CPU time deltas and resident memory |
| Temperatures | IOKit HID sensors | 20+ named die sensors, no root needed |

## Architecture

```
Sources/MacPulse/
├── MacPulseApp.swift        # MenuBarExtra + dashboard + settings scenes
├── Design/
│   ├── Theme.swift          # Colour tokens, type scale, load semantics
│   └── Components.swift     # Card, MeterBar, Sparkline, Metric, chips
├── Model/
│   ├── Snapshots.swift      # Value types produced by each sampler
│   ├── SamplingEngine.swift # Owns samplers, publishes on a shared cadence
│   ├── AppModel.swift       # Navigation and preferences
│   └── Format.swift         # Byte, rate, percent, temperature formatting
├── Samplers/                # One file per data source
└── Views/
    ├── MenuPanelView.swift  # Popover chrome
    ├── PanelContent.swift   # Popover body (cards)
    ├── DashboardView.swift  # Full window, seven detail panes
    └── SettingsView.swift   # Preferences
```

Each sampler is a small, dependency-free class that returns a snapshot value
type. `SamplingEngine` runs them off the main thread on a timer and publishes
results back on the main actor.

### Sampling cadence

Fast metrics (CPU, memory, network) refresh on the configured interval
(1–10 s, default 2 s). Slow metrics (battery, storage, processes, temperatures)
refresh at twice that interval to keep the app lightweight.

## Design

The interface follows a warm monochrome editorial style: off-white canvas,
hairline borders, a serif display face for headlines, tabular figures for live
numbers, and muted pastels reserved for semantic status. It respects the system
appearance in both light and dark mode.

## Notes on macOS APIs

- `AppleSMC` is root-restricted on Apple Silicon, so temperatures come from the
  IOKit HID event system instead — the same source `powermetrics` uses.
- `sysctl KERN_PROC` is restricted under SIP, so process data uses `libproc`.
- Raw battery capacity lives in a nested `BatteryData` dictionary on modern
  Macs rather than at the top level of the IORegistry node.

## Licence

Private project.
