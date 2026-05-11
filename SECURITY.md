# Security Policy

`dm-annotate` is a local-only macOS utility. It should not require accounts, telemetry, analytics, cloud sync, license activation, or normal-operation network calls.

## Supported versions

The public repository currently supports the latest `main` branch.

## Reporting a vulnerability

Please report security issues privately first.

Preferred path:

- Open a private security advisory on GitHub if available.
- If advisories are unavailable, contact the maintainer through the GitHub profile for `BradGroux`.

Please include:

- A clear description of the issue.
- Reproduction steps.
- Impact.
- Affected macOS version.
- Whether the issue requires Screen Recording, Accessibility, or Input Monitoring permission.

Do not include public proof-of-concept details until a fix is available.

## Security expectations

Security-sensitive areas include:

- Screen capture.
- Global and local keyboard monitoring.
- Accessibility permission flows.
- Click-through overlay behavior.
- Region screenshot selection.
- File paths used for screenshot output.
- Any future signing, notarization, or update workflow.

The app should continue to avoid:

- Telemetry.
- Analytics.
- Background network calls.
- Remote code execution or plugin systems.
- Uploading screenshots.
- Persisting annotation sessions without an explicit user-facing design.
