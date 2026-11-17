# roadmap

ordered by what would annoy first if it's missing, not by how fun it is to build. nothing here is a promise.

## 1. shore up what's there

- [ ] confirm launch at login survives a real logout, and that it starts quietly (no settings window).
- [ ] sign with a Developer ID. the ad-hoc signature changes on every rebuild, which is the likely cause of the default browser or login item needing re-approval.
- [ ] a "test a url" field in settings. paste a link, see which rule wins and why.
- [ ] github actions running `swift test` on push.

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

- [ ] notarized release builds and a homebrew cask.
- [ ] auto-update.
- [ ] a screenshot in the README, with fake profile names.

## not doing

- Safari profiles. there's no real API for them.
- global hotkeys to open a profile with no link. that's a different app.
