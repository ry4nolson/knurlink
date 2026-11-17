# roadmap

ordered by what would annoy first if it's missing, not by how fun it is to build. nothing here is a promise.

## 1. shore up what's there

- [ ] confirm launch at login survives a real logout, and that it starts quietly (no settings window).
- [x] sign with a Developer ID. set `KNURLINK_SIGN_IDENTITY` and the build script uses it, with the hardened runtime on. without it the build is ad-hoc.
- [x] a "test a url" field in settings. paste a link, see which rule wins and why.
- [x] github actions running `swift test` on push.

## 2. fewer picker popups

- [ ] a default destination plus a hold-key. unmatched links go to one browser or profile silently, and holding a modifier brings up the bubbles.
- [ ] hide and reorder individual profiles, not just whole apps.
- [ ] "last used" as a quick pick.

## 3. smarter matching

- [ ] unwrap redirect links (outlook safelinks, google redirects) before matching, so rules see the real domain.
- [ ] strip tracking params (`utm_*`, `fbclid`) on the way through.
- [ ] optional short link expansion (bit.ly, t.co). it needs a network call, so it's off by default. this would be the first network code in the app.

## 4. more destinations

- [ ] open in the desktop app and skip the browser (zoom, figma, linear, spotify).
- [ ] private window on shift.
- [ ] Firefox profiles.

## 5. if other people use it

- [ ] notarized release builds. the workflow versions and publishes on every push to `main` that touches the app. it hasn't run yet.
- [ ] a homebrew cask. it needs a first release to point at, and a tap repo.
- [x] update check. the about window and the menu bar item say when a new release is out, and link to the download. it doesn't install anything itself.
- [ ] a screenshot in the README, with fake profile names.
- [x] an about page, with a "sponsored by texas beard co" line.

## not doing

- Safari profiles. there's no real API for them.
- global hotkeys to open a profile with no link. that's a different app.
