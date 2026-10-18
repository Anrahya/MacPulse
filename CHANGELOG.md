# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.0] - 2026-10-19

### Added

- Storage card in the menu bar popover, showing used percentage, free space and
  total capacity for the boot volume

### Fixed

- Storage figures now report the data volume rather than the read-only sealed
  root snapshot, which under-reported usage by a wide margin

## [2.0.0] - 2026-10-17

First public release. A ground-up rewrite after the original source was lost
with an external drive.

### Added

- Menu bar popover with live CPU, memory, battery, network, thermal and
  process summaries
- Dashboard window with a dedicated pane for each module
- CPU sampling with per-core deltas, user/system split, and load averages
- Memory breakdown into app, wired, compressed and cached pages, plus swap
- Battery charge, health, cycle count, voltage, draw and temperature
- Network throughput per interface from kernel byte counters
- Storage capacity for the boot volume
- Process list with CPU time deltas and resident memory
- Temperature readings from 20+ named sensors without requiring root
- Preferences for the menu bar display, refresh interval and temperature unit
- Light and dark appearance support

### Notes

- Temperatures come from the IOKit HID sensor registry rather than `AppleSMC`,
  which is root-restricted on Apple Silicon
- Built with Swift Package Manager; a full Xcode install is not required to
  compile, though it is needed to run the test suite

[Unreleased]: https://github.com/Anrahya/MacPulse/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/Anrahya/MacPulse/releases/tag/v2.1.0
[2.0.0]: https://github.com/Anrahya/MacPulse/releases/tag/v2.0.0
