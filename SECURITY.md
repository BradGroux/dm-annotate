# Security Policy

`dm-annotate` is a local-only macOS utility. It should not require accounts, telemetry, analytics, cloud sync, license activation, or normal-operation network calls.

## Supported versions

`dm-annotate` supports one downloadable release line at a time: the latest stable GitHub Release and the matching Homebrew cask.

| Version or channel | Security support |
| --- | --- |
| [Latest stable GitHub Release](https://github.com/BradGroux/dm-annotate/releases/latest) | Supported |
| Matching `BradGroux/tap` Homebrew cask | Supported |
| Older stable releases | Unsupported; upgrade to the latest stable release |
| Drafts, prereleases, and ad-hoc preview builds | Unsupported |
| `main` and other source snapshots | Development code, not a supported downloadable release |

Find the installed version in **About Digital Meld Annotate** or **Settings → Help/Diagnostics**, then compare it with the latest stable release tag. The app version omits the tag's leading `v` (`0.1.12` corresponds to `v0.1.12`). Because the project is pre-1.0, each new stable release replaces the previous release as the supported line when it is published.

## Fix and release policy

Security fixes are developed and reviewed on `main`, then delivered in a new signed, notarized stable release. Users of an affected older version should upgrade to the first stable release identified as fixed.

The project does not routinely backport fixes to older releases or maintain parallel supported branches. The maintainer may issue a narrowly scoped patch from the current stable line when that is the safest way to address a serious vulnerability, but this is a case-by-case decision, not a backport or response-time commitment.

When a vulnerability affects a published release, the advisory or release notes should identify the affected versions and the first fixed stable version. If no fixed stable version has been published, users should treat every published version named by the advisory as affected; a commit on `main` alone is not a supported end-user update.

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
