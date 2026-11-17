#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { unreleasedSection } from "./stamp-changelog.mjs";

const SEMVER = /^(\d+)\.(\d+)\.(\d+)$/;

function parts(version) {
  const match = SEMVER.exec(version);
  if (!match) {
    throw new Error(`Not a version: ${version}`);
  }
  return match.slice(1).map(Number);
}

export function compareVersions(a, b) {
  const [left, right] = [parts(a), parts(b)];
  return left.map((part, index) => part - right[index]).find((difference) => difference !== 0) ?? 0;
}

export function releaseBump(changelog) {
  const body = unreleasedSection(changelog)?.body ?? "";
  const added = /^### Added[^\n]*\n([\s\S]*?)(?=^### |(?![\s\S]))/im.exec(body);
  return added && /^\s*[-*] /m.test(added[1]) ? "minor" : "patch";
}

export function nextVersion({ latestTag, configVersion, changelog }) {
  const latest = latestTag?.replace(/^v/, "");
  if (!latest || compareVersions(configVersion, latest) > 0) {
    return configVersion;
  }
  const [major, minor, patch] = parts(latest);
  return releaseBump(changelog) === "minor" ? `${major}.${minor + 1}.0` : `${major}.${minor}.${patch + 1}`;
}

export function plistVersion(plist) {
  const match = /<key>CFBundleShortVersionString<\/key>\s*<string>([^<]+)<\/string>/.exec(plist);
  if (!match) {
    throw new Error("Info.plist has no CFBundleShortVersionString");
  }
  return match[1];
}

function latestTag() {
  return execFileSync("git", ["tag", "--list", "v[0-9]*.[0-9]*.[0-9]*", "--sort=-v:refname"], { encoding: "utf8" })
    .split("\n")
    .find((tag) => SEMVER.test(tag.replace(/^v/, "")));
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  const [changelogPath = "CHANGELOG.md", plistPath = "Resources/Info.plist"] = process.argv.slice(2);
  const configVersion = plistVersion(readFileSync(plistPath, "utf8"));
  process.stdout.write(`${nextVersion({ latestTag: latestTag(), configVersion, changelog: readFileSync(changelogPath, "utf8") })}\n`);
}
