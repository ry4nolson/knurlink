import assert from "node:assert/strict";
import { test } from "node:test";
import { misplacedEntries } from "./check-changelog.mjs";
import { nextVersion, plistVersion, releaseBump } from "./next-version.mjs";
import { stampChangelog } from "./stamp-changelog.mjs";

const header = "# Changelog\n\n";
const released = "## [1.2.3] - 2026-01-01\n\n### Fixed\n- An old fix\n";

test("first release uses the Info.plist version", () => {
  const changelog = `${header}## [Unreleased]\n\n### Added\n- A thing\n`;
  assert.equal(nextVersion({ latestTag: undefined, configVersion: "1.0.0", changelog }), "1.0.0");
});

test("an Added entry bumps the minor version", () => {
  const changelog = `${header}## [Unreleased]\n\n### Added\n- A thing\n\n${released}`;
  assert.equal(releaseBump(changelog), "minor");
  assert.equal(nextVersion({ latestTag: "v1.2.3", configVersion: "1.0.0", changelog }), "1.3.0");
});

test("anything else bumps the patch version", () => {
  const fixed = `${header}## [Unreleased]\n\n### Fixed\n- A fix\n\n${released}`;
  const empty = `${header}## [Unreleased]\n\n${released}`;
  assert.equal(nextVersion({ latestTag: "v1.2.3", configVersion: "1.0.0", changelog: fixed }), "1.2.4");
  assert.equal(nextVersion({ latestTag: "v1.2.3", configVersion: "1.0.0", changelog: empty }), "1.2.4");
});

test("a higher Info.plist version wins", () => {
  const changelog = `${header}## [Unreleased]\n\n${released}`;
  assert.equal(nextVersion({ latestTag: "v1.2.3", configVersion: "2.0.0", changelog }), "2.0.0");
});

test("reads the version from an Info.plist", () => {
  const plist = "<dict>\n<key>CFBundleShortVersionString</key>\n    <string>1.4.0</string>\n</dict>";
  assert.equal(plistVersion(plist), "1.4.0");
  assert.throws(() => plistVersion("<dict></dict>"));
});

test("stamping moves Unreleased under the new version", () => {
  const changelog = `${header}## [Unreleased]\n\n### Fixed\n- A fix\n\n${released}`;
  const { content, notes } = stampChangelog(changelog, "1.2.4", "2026-02-02");
  assert.equal(notes, "### Fixed\n- A fix");
  assert.ok(content.includes("## [Unreleased]\n\n## [1.2.4] - 2026-02-02\n\n### Fixed\n- A fix\n\n## [1.2.3]"));
});

test("stamping an empty Unreleased changes nothing", () => {
  const changelog = `${header}## [Unreleased]\n\n${released}`;
  assert.deepEqual(stampChangelog(changelog, "1.2.4", "2026-02-02"), { content: changelog, notes: "" });
});

test("flags entries added under a released version", () => {
  const later = released.replace("- An old fix\n", "- An old fix\n- A late entry\n");
  assert.deepEqual(misplacedEntries(`${header}${released}`, `${header}${later}`), [{ version: "1.2.3", entry: "- A late entry" }]);
  assert.deepEqual(misplacedEntries(`${header}${released}`, `${header}${released}`), []);
});
