# knURLink

a small macOS menu bar app that decides which browser a link opens in.

set it as your default browser. when you click a link anywhere (Slack, Mail, a terminal), knURLink either sends it straight to the browser or profile a rule names, or pops a ring of bubbles at your cursor so you can pick.

i built it because a coworker keeps posting tiktok links in Slack, and they kept opening in my work Chrome profile. now they go to Brave.

the name is a knurl (the grip pattern you cut into a tool handle) with a url hiding in it.

## what it does

- **picker.** one bubble per browser, and one per profile for Chromium browsers. turn off the browsers and profiles you don't use under Browsers in settings. click one, or press 1-9. arrows and return work too. esc or clicking away cancels.
- **domain rules.** `tiktok.com` covers `www.tiktok.com`, `vm.tiktok.com`, and so on.
- **path rules.** `github.com/my-org` matches that path and everything under it, on whole path segments.
- **source app rules.** leave the link blank and pick an app to route everything that app sends. or fill in both to scope a domain to one app.
- **private windows.** hold shift while you pick a bubble, or turn on Private for a rule, and the link opens in an incognito or private window. works for Chrome, Brave, Vivaldi, Chromium, Edge, and Firefox. Safari doesn't let other apps open private windows, so it opens a normal one.
- **"always" checkbox.** tick it in the picker (or press A) to save a domain rule on the spot.
- **test a link.** paste a link in settings to see which rule wins, and which other rules matched but lost.
- **launch at login.** a toggle in settings, off by default. it starts quietly in the menu bar.
- **update check.** the About section in settings (menu bar icon, then About knURLink) tells you when there's a new release. it never installs anything on its own.

when more than one rule matches, the most specific link wins: longer domain first, then longer path. a rule with no link is the fallback.

## install

grab `knURLink.dmg` from the [latest release](https://github.com/ry4nolson/knurlink/releases/latest), drag the app to Applications, open it, and click **Make Default**. release builds are signed and notarized. it needs macOS 14 or later.

## build it yourself

you need Xcode or the Swift toolchain (Swift 5.9+).

```bash
./scripts/build-app.sh --install
```

that builds a release binary, wraps it in `knURLink.app`, ad-hoc signs it, and copies it to `/Applications`. leave off `--install` to just get `dist/knURLink.app`.

to sign with your own Developer ID instead of ad-hoc, name the identity:

```bash
KNURLINK_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh --install
```

then open the app and click **Make Default**. macOS will ask you to confirm. settings live behind the menu bar icon after that.

run the tests with:

```bash
swift test
```

## where things live

- rules are saved to `~/Library/Application Support/Knurlink/config.json`. it's plain JSON if you'd rather edit it by hand. quit the app first, or it'll overwrite your edits.
- matching logic is in `Sources/KnurlinkCore`. the app itself is in `Sources/Knurlink`.

## limits

- profiles are only detected for Chromium browsers: Chrome, Brave, Edge, Vivaldi, Chromium. Firefox and Safari show up as one bubble each.
- source app rules depend on macOS reporting who sent the link. links opened with `open` from a terminal come through with no sender.
- local builds are ad-hoc signed unless you name an identity. only tagged releases are notarized.
- your links and rules never leave your mac. the one network call is the update check, a single request to GitHub's releases API. turn it off in the About section of settings if you'd rather it didn't.

## releasing

releases are cut from your mac with one command, so they don't wait on GitHub's macOS runners.

- add a line under `## [Unreleased]` in `CHANGELOG.md` with your change.
- an entry under `### Added` bumps the minor version. anything else bumps the patch.
- for a bigger jump, set `CFBundleShortVersionString` in `Resources/Info.plist` to the version you want. a higher number there wins.
- with nothing under Unreleased, the release notes list the commits instead.

once, save your notarization credentials to the keychain. it asks for your Apple ID, team ID, and an [app-specific password](https://support.apple.com/102654):

```bash
xcrun notarytool store-credentials knurlink
```

then, from a clean, pushed `main`:

```bash
./scripts/release.sh
```

it works out the version, stamps the changelog, runs the tests, signs with the Developer ID in your keychain, notarizes, commits the version back to `main` as `Release vX.Y.Z`, pushes, and publishes a GitHub release with a dmg and a zip. if anything fails before the commit, `Info.plist` and `CHANGELOG.md` are put back.

- `./scripts/release.sh --dry-run` builds and signs without notarizing or publishing anything.
- with more than one Developer ID in your keychain, pick one with `KNURLINK_SIGN_IDENTITY`.
- to use a different notarization profile name, set `KNURLINK_NOTARY_PROFILE`.

the [release workflow](.github/workflows/release.yml) still exists as a manual fallback (Actions, then release, then Run workflow). it needs four repo secrets, and stops if the cert is missing instead of publishing an unsigned build:

| secret | what it is |
|--------|------------|
| `DEVELOPER_ID_P12` | base64 of the Developer ID Application `.p12` |
| `DEVELOPER_ID_P12_PASSWORD` | password for that `.p12` |
| `APPLE_ID` | Apple ID for `notarytool` |
| `APPLE_ID_PASSWORD` | app-specific password |

## license

MIT. see [LICENSE](LICENSE).
