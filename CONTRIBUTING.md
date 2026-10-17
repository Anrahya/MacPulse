# Contributing to MacPulse

Thanks for taking the time to contribute. This project is small on purpose, so
the process stays light.

## Getting started

```bash
git clone https://github.com/Anrahya/MacPulse.git
cd MacPulse
swift build
./scripts/build-app.sh debug
open build/MacPulse.app
```

You need macOS 14 or later. A full Xcode install is not required — the Command
Line Tools are enough (`xcode-select --install`). If you do have Xcode, you can
still open `Package.swift` directly in it.

## How the app is laid out

```
Sources/MacPulse/
├── Design/     Colour tokens and reusable views
├── Model/      Snapshot types, the sampling engine, preferences
├── Samplers/   One file per data source
└── Views/      Popover, dashboard, settings
```

The rule of thumb: a **sampler** reads one kind of system data and returns a
snapshot value type. It owns no state beyond the deltas needed between calls.
The **engine** runs samplers off the main thread and publishes results back on
the main actor. **Views** never talk to a sampler directly.

Adding a metric usually means:

1. Add a snapshot type in `Model/Snapshots.swift`.
2. Add a sampler in `Samplers/`.
3. Wire it into `SamplingEngine` (`prime()` and one of the tick methods).
4. Surface it in `PanelContent` and/or `DashboardView`.

## Before opening a pull request

```bash
swift build -c release     # must compile cleanly
swift test                 # must pass
```

If your change affects layout, check the popover at 320 pt wide. Note that a
`ScrollView` needs an explicit height inside `MenuBarExtra`'s popover, because
the popover sizes itself to fit and a scroll view has no intrinsic height. You
can print the realised popover size with:

```bash
MACPULSE_DEBUG_SIZE=1 open build/MacPulse.app
```

## Reporting bugs

Good bug reports include:

- macOS version (`sw_vers`) and Mac model
- Whether it is Apple Silicon or Intel
- What you expected versus what happened
- The relevant part of the menu bar or dashboard, ideally a screenshot

Because this app reads hardware sensors, behaviour genuinely differs between
models. Please mention yours.

## Code style

- Keep the existing structure and naming.
- Prefer small, focused types over large ones.
- No third-party dependencies, and please do not add any.
- Comment the *why* when a platform API is surprising — several APIs here
  behave differently on Apple Silicon than on Intel.

## Commit messages

Write the subject in the imperative mood, under about 70 characters:

```
Fix network rate rounding to zero on idle interfaces
```

Add a body when the change is not obvious from the subject.

## License

By contributing, you agree that your contributions are licensed under the MIT
License in [LICENSE](LICENSE).
