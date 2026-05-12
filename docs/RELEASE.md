# Release Guide

This project can build an unsigned local app bundle from source. Public binary releases should be signed and notarized before distribution.

## macOS requirements

- macOS 13 Ventura or later.
- Screen Recording permission for screenshots that include other apps.
- Accessibility permission for reliable global shortcuts.
- Input Monitoring may be required by macOS for global keyboard shortcuts.

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

## Homebrew Cask

The public Homebrew tap lives at:

```text
github.com/BradGroux/homebrew-tap
```

The installable cask path in that repo is:

```text
BradGroux/homebrew-tap/Casks/dm-annotate.rb
```

This repository also keeps a mirror cask at:

```text
dm-annotate/Casks/dm-annotate.rb
```

After publishing a new GitHub Release, update both cask files with the release version and SHA256:

```sh
VERSION="0.1.7"
tmpdir="$(mktemp -d)"
gh release download "v${VERSION}" \
  --repo BradGroux/dm-annotate \
  --pattern "dm-annotate-${VERSION}-macos.zip" \
  --dir "${tmpdir}"
shasum -a 256 "${tmpdir}/dm-annotate-${VERSION}-macos.zip"
rm -rf "${tmpdir}"
```

Validate the public tap before updating install docs:

```sh
export HOMEBREW_GITHUB_API_TOKEN="$(gh auth token)"
brew untap BradGroux/tap >/dev/null 2>&1 || true
brew tap BradGroux/tap
brew audit --cask --strict --online dm-annotate
brew install --cask --dry-run dm-annotate
brew untap BradGroux/tap
```

The CI workflow in this repo validates the mirrored cask against committed changes.

Current install path:

```sh
brew tap BradGroux/tap
brew install --cask dm-annotate
```

Fallback direct tap path:

```sh
brew tap BradGroux/dm-annotate https://github.com/BradGroux/dm-annotate
brew install --cask bradgroux/dm-annotate/dm-annotate
```

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

The automated release workflow currently publishes an ad-hoc signed developer preview zip. That is acceptable for early testers who understand macOS Gatekeeper prompts, but not ideal for broad distribution.

Developer ID signing and notarization are supported when the required GitHub Actions secrets are configured.

Required repository secrets:

- `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64`: base64-encoded `.p12` export containing the Developer ID Application certificate and private key.
- `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`: password for the `.p12` export.
- `APPLE_DEVELOPER_IDENTITY`: full codesigning identity, for example `Developer ID Application: Example LLC (TEAMID)`.
- `APPLE_NOTARIZATION_APPLE_ID`: Apple ID used for notarization.
- `APPLE_NOTARIZATION_PASSWORD`: app-specific password for that Apple ID.
- `APPLE_NOTARIZATION_TEAM_ID`: Apple Developer Team ID.

Create the certificate payload locally:

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
```

Then paste the clipboard value into `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64`.

When those secrets are present, the release workflow:

- imports the Developer ID certificate into a temporary keychain,
- signs the app with hardened runtime,
- submits the release zip to Apple notarization,
- staples the notarization ticket to the app,
- rebuilds the zip with the stapled app,
- uploads the notarized archive and SHA256 file to GitHub Releases.

## Opening developer preview builds

> [!IMPORTANT]
> Ad-hoc signed preview builds are not notarized. Until Developer ID signed/notarized releases are available, macOS may block them with an "Apple could not verify" dialog.
>
> For local testing only, after moving the app to `/Applications`, allow it manually:
>
> ```sh
> xattr -dr com.apple.quarantine "/Applications/Digital Meld Annotate.app"
> open "/Applications/Digital Meld Annotate.app"
> ```
>
> Only do this for builds you trust. General users should receive Developer ID signed and notarized releases.

Homebrew distribution should wait until signed/notarized releases are stable.
