# Security Policy

## Reporting a vulnerability

Please do **not** open a public issue for security problems.

Report privately through GitHub's [private vulnerability reporting][advisory]:
open the repository's **Security** tab and choose *Report a vulnerability*.
You can expect an acknowledgement within a few days.

[advisory]: https://github.com/Anrahya/MacPulse/security/advisories/new

## Scope

MacPulse runs as a normal, unsandboxed menu bar app. It has no network
listeners, no remote endpoints, and no telemetry — it only reads local system
data and renders it.

Areas worth scrutiny:

- Reading hardware sensors through IOKit HID and the IORegistry
- Process enumeration via `libproc`
- The ad-hoc signing step in `scripts/build-app.sh`

## Supported versions

Only the latest commit on `main` is supported. There are no maintained release
branches at this time.

## Note on releases

Builds are signed ad hoc, not with a Developer ID, and are not notarised. If you
download a prebuilt `.app`, macOS may require you to allow it under
*System Settings → Privacy & Security*. Building from source avoids this
entirely and is the recommended route.
