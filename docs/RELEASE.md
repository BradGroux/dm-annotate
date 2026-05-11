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
