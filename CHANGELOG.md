# Changelog

All notable changes to knURLink are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Hold Option while you click a link to skip your rules and pick a browser from the bubbles

## [1.1.1] - 2026-11-18

### Fixed
- Links no longer take a few seconds to open after knURLink has sat idle. Routing uses the cached browser list and refreshes it in the background afterward

## [1.1.0] - 2026-11-17

### Added
- Safari private windows, opened through Safari's File menu with the Accessibility API. If it can't, knURLink asks before opening the link in a normal window

## [1.0.0] - 2026-11-17

### Added
- Radial picker at the cursor, with one bubble per browser and per Chromium profile
- Domain rules, path rules, and source app rules, with the most specific link winning
- "Always" checkbox in the picker to save a domain rule on the spot
- "Test a link" in settings to see which rule wins and which ones lost
- Launch at login
- About window with an update check against GitHub releases
- Developer ID signed and notarized release builds
- Show or hide individual Chromium profiles in the picker
- Private windows: hold Shift in the picker, or turn on Private for a rule (Chromium browsers, Edge, and Firefox)
- Safari profiles in the picker and in rules, opened through the Accessibility API

### Changed
- Settings window redesigned with a sidebar, split into General, Rules, Test a Link, Browsers, and About sections
- About moved from its own window into the settings sidebar

### Fixed
- Clicking a link no longer brings an open settings window to the front for a moment
- Cancelling the picker hands focus back to the app the link came from
