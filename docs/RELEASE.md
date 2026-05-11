# Release Guide

This project can build an unsigned local app bundle from source. Public binary releases should be signed and notarized before distribution.

## Version source

The app version is read from:

```text
Packaging/Info.plist
```

Check:

```sh
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Packaging/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Packaging/Info.plist
```

## Verification

Run:

```sh
swift build
swift test
plutil -lint Packaging/Info.plist
bash -n scripts/build-app.sh
bash -n scripts/package-release.sh
```

## Build an app bundle

```sh
scripts/build-app.sh release
```

Output:

```text
.build/Digital Meld Annotate.app
```

## Package an unsigned zip

```sh
scripts/package-release.sh
```

Output:

```text
.build/dist/dm-annotate-VERSION-macos.zip
```

Unsigned builds are suitable for local testing, not polished end-user distribution.

## Sign

```sh
CODESIGN_IDENTITY="Developer ID Application: Example" scripts/package-release.sh
```

## Sign and notarize

```sh
CODESIGN_IDENTITY="Developer ID Application: Example" \
NOTARIZE_PROFILE="dm-annotate" \
scripts/package-release.sh
```

The notarization profile should be created with `xcrun notarytool store-credentials`.

## GitHub release checklist

1. Confirm `README.md`, `docs/`, `LICENSE`, `SECURITY.md`, and `CONTRIBUTING.md` are current.
2. Run the verification commands above.
3. Build the release zip.
4. Create a version tag.
5. Draft a GitHub release with:
   - Summary.
   - Verification notes.
   - Known limitations.
   - Signed/notarized status.
6. Attach the zip only if it is appropriate for public distribution.

## Automated GitHub releases

The repository includes a tag-driven release workflow:

```text
.github/workflows/release.yml
```

To publish a release, update `Packaging/Info.plist`, commit the change, then push a matching version tag:

```sh
VERSION="0.1.0"
git tag "v${VERSION}"
git push origin "v${VERSION}"
```

The workflow fails if the tag does not match `CFBundleShortVersionString`.

The workflow runs:

- `swift build`
- `swift test`
- `plutil -lint Packaging/Info.plist`
- packaging script syntax checks
- `scripts/package-release.sh`
- SHA256 generation

It then creates a GitHub Release and attaches:

- `dm-annotate-VERSION-macos.zip`
- `dm-annotate-VERSION-macos.zip.sha256`

## Current release signing status

The automated release workflow currently publishes an unsigned developer preview zip. That is acceptable for early testers who understand macOS Gatekeeper prompts, but not ideal for broad distribution.

Before promoting releases for general users, add Developer ID signing and notarization to the release workflow.

Required future work:

- Import a Developer ID Application certificate into the GitHub Actions keychain from repository secrets.
- Run `codesign --options runtime --timestamp`.
- Run `xcrun notarytool submit`.
- Staple the notarization ticket.
- Attach only the signed, notarized archive to public releases.

Homebrew distribution should wait until signed/notarized releases are stable.
