# knURLink

a small macOS menu bar app that decides which browser a link opens in.

set it as your default browser. when you click a link anywhere (Slack, Mail, a terminal), knURLink either sends it straight to the browser or profile a rule names, or pops a ring of bubbles at your cursor so you can pick.

i built it because a coworker keeps posting tiktok links in Slack, and they kept opening in my work Chrome profile. now they go to Brave.

the name is a knurl (the grip pattern you cut into a tool handle) with a url hiding in it.

## what it does

- **picker.** one bubble per browser, and one per profile for Chromium browsers. click one, or press 1-9. arrows and return work too. esc or clicking away cancels.
- **domain rules.** `tiktok.com` covers `www.tiktok.com`, `vm.tiktok.com`, and so on.
- **path rules.** `github.com/my-org` matches that path and everything under it, on whole path segments.
- **source app rules.** leave the link blank and pick an app to route everything that app sends. or fill in both to scope a domain to one app.
- **"always" checkbox.** tick it in the picker (or press A) to save a domain rule on the spot.

when more than one rule matches, the most specific link wins: longer domain first, then longer path. a rule with no link is the fallback.

## requirements

- macOS 14 or later
- Xcode or the Swift toolchain (Swift 5.9+) to build it

## build and install

```bash
./scripts/build-app.sh --install
```

that builds a release binary, wraps it in `knURLink.app`, ad-hoc signs it, and copies it to `/Applications`. leave off `--install` to just get `dist/knURLink.app`.

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
- the app is ad-hoc signed, not notarized. it's meant to be built on the machine that runs it.
- nothing leaves your mac. there's no network code in it.

## license

MIT. see [LICENSE](LICENSE).
