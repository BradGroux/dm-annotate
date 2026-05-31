# Release Guide

This project can build an ad-hoc signed local app bundle from source. Tagged GitHub releases publish a developer-preview zip when Apple release secrets are absent, and publish Developer ID signed, notarized, stapled zips when the full secret set is configured.

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
bash -n scripts/verify-release-zip.sh
bash -n scripts/smoke-ui.sh
zip_path="$(scripts/verify-release-zip.sh)"
shasum -a 256 "${zip_path}" > "${zip_path}.sha256"
test -s "${zip_path}.sha256"
```

## Build an app bundle

```sh
scripts/build-app.sh release
```

Output:

```text
.build/Digital Meld Annotate.app
```

## Package an ad-hoc signed zip

```sh
scripts/package-release.sh
```

Output:

```text
.build/dist/dm-annotate-VERSION-macos.zip
```

Ad-hoc signed builds are suitable for local testing, not polished end-user distribution.

## Verify a release zip

```sh
scripts/verify-release-zip.sh
```

Output:

```text
.build/dist/dm-annotate-VERSION-macos.zip
```

The verifier packages the app when no zip path is provided, unpacks the archive into a temporary directory, checks bundle metadata against `Packaging/Info.plist`, verifies the code signature, and runs the app executable in launch-verification mode without starting the overlay UI or requesting macOS permissions.

Require notarization checks when validating a signed release artifact:

```sh
REQUIRE_NOTARIZATION=1 scripts/verify-release-zip.sh
```

## Run local UI smoke

```sh
scripts/smoke-ui.sh
```

The UI smoke command builds a release app bundle when no app path is provided, starts the executable in controlled smoke mode, verifies the toolbar, settings, permissions, and command palette windows can appear, exercises toolbar layout states, checks command palette action generation for session and screenshot workflows, validates toolbar preset preference round-tripping, prints a short diagnostic summary, and exits. It does not test screenshot capture because that depends on local macOS Screen Recording consent.

## Sign

```sh
CODESIGN_IDENTITY="Developer ID Application: Example" scripts/package-release.sh
```

Check the local keychain for installed signing identities:

```sh
security find-identity -p codesigning -v
```

## Sign and notarize

With an App Store Connect API key:

```sh
CODESIGN_IDENTITY="Developer ID Application: Example" \
NOTARIZE_KEY_PATH="$HOME/private_keys/AuthKey_EXAMPLE.p8" \
NOTARIZE_KEY_ID="EXAMPLE1234" \
NOTARIZE_ISSUER_ID="00000000-0000-0000-0000-000000000000" \
scripts/package-release.sh
```

Omit `NOTARIZE_ISSUER_ID` for Individual API keys. Team API keys require the issuer UUID.

With a stored notarytool profile:

```sh
CODESIGN_IDENTITY="Developer ID Application: Example" \
NOTARIZE_PROFILE="dm-annotate" \
scripts/package-release.sh
```

The notarization profile should be created with `xcrun notarytool store-credentials`.

When notarization runs, `scripts/package-release.sh` also validates the stapled ticket and Gatekeeper acceptance:

```sh
xcrun stapler validate ".build/Digital Meld Annotate.app"
spctl -a -vvv -t exec ".build/Digital Meld Annotate.app"
```

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

The installable cask path is:

```text
BradGroux/homebrew-tap/Casks/dm-annotate.rb
```

After publishing a new GitHub Release, update the tap cask with the release version and SHA256:

```sh
VERSION="0.1.9"
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
brew audit --cask --strict --online bradgroux/tap/dm-annotate
brew install --cask --dry-run bradgroux/tap/dm-annotate
brew untap BradGroux/tap
```

Current install path:

```sh
brew tap BradGroux/tap
brew install --cask dm-annotate
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

The workflow fails if the tag does not match `CFBundleShortVersionString`. Apple signing/notarization secrets are all-or-nothing: a partial secret set fails the workflow, no secret set publishes an ad-hoc developer preview, and a complete secret set publishes a signed/notarized release. Notarization can use either App Store Connect API key secrets or Apple ID app-specific password secrets, but not both.

The workflow runs:

- `swift build`
- `swift test`
- `plutil -lint Packaging/Info.plist`
- packaging script syntax checks
- `scripts/package-release.sh`
- `scripts/verify-release-zip.sh`
- `bash -n scripts/smoke-ui.sh`
- SHA256 generation

It then creates a GitHub Release and attaches:

- `dm-annotate-VERSION-macos.zip`
- `dm-annotate-VERSION-macos.zip.sha256`

## Release signing status

The `BradGroux/dm-annotate` release workflow is configured with the complete Developer ID and App Store Connect secret set. Tagged releases publish Developer ID signed, notarized, stapled release zips and validate Gatekeeper acceptance. Forks or local clones without Apple release secrets fall back to ad-hoc signed developer previews.

Required Developer ID signing secrets:

- `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64`: base64-encoded `.p12` export containing the Developer ID Application certificate and private key.
- `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`: password for the `.p12` export.
- `APPLE_DEVELOPER_IDENTITY`: full codesigning identity, for example `Developer ID Application: Example LLC (TEAMID)`.

Required App Store Connect API key notarization secrets:

- `APPLE_NOTARIZATION_KEY_ID`: App Store Connect API key ID.
- `APPLE_NOTARIZATION_PRIVATE_KEY`: full `.p8` private key contents.
- `APPLE_NOTARIZATION_ISSUER_ID`: issuer UUID for Team API keys. Leave unset for Individual API keys.

Alternative Apple ID app-specific password notarization secrets:

- `APPLE_NOTARIZATION_APPLE_ID`: Apple ID used for notarization.
- `APPLE_NOTARIZATION_PASSWORD`: app-specific password for that Apple ID.
- `APPLE_NOTARIZATION_TEAM_ID`: Apple Developer Team ID.

Create the certificate payload locally:

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
```

Then paste the clipboard value into `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64`.

With those secrets configured, the release workflow:

- imports the Developer ID certificate into a temporary keychain,
- signs the app with hardened runtime,
- submits the release zip to Apple notarization,
- staples the notarization ticket to the app,
- validates the stapled ticket,
- validates Gatekeeper acceptance with `spctl`,
- rebuilds the zip with the stapled app,
- uploads the notarized archive and SHA256 file to GitHub Releases.

## Opening local preview builds

> [!IMPORTANT]
> Local ad-hoc signed builds are not notarized. macOS may block them with an "Apple could not verify" dialog.
>
> For local testing only, after moving the app to `/Applications`, allow it manually:
>
> ```sh
> xattr -dr com.apple.quarantine "/Applications/Digital Meld Annotate.app"
> open "/Applications/Digital Meld Annotate.app"
> ```
>
> Only do this for builds you trust. General users should receive Developer ID signed and notarized releases.

The dedicated `BradGroux/tap` cask is the current Homebrew distribution path. Published cask artifacts point at Developer ID signed, notarized, stapled GitHub release archives.
