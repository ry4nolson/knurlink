#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NOTARY_PROFILE="${KNURLINK_NOTARY_PROFILE:-knurlink}"
DRY_RUN=false
COMMITTED=false
WORK="$(mktemp -d)"

case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN=true ;;
    *)
        echo "Usage: scripts/release.sh [--dry-run]" >&2
        exit 1
        ;;
esac

cd "$ROOT"

fail() {
    echo "error: $*" >&2
    exit 1
}

step() {
    echo
    echo "==> $*"
}

cleanup() {
    if [ "$COMMITTED" != "true" ]; then
        git checkout -- Resources/Info.plist CHANGELOG.md 2>/dev/null || true
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT

staple() {
    for attempt in 1 2 3; do
        if xcrun stapler staple "$1"; then
            return 0
        fi
        echo "Stapling failed (attempt $attempt), retrying in 20 seconds..."
        sleep 20
    done
    return 1
}

step "Checking prerequisites"
for tool in git gh node swift xcrun; do
    command -v "$tool" >/dev/null || fail "$tool is not installed"
done
git fetch --quiet --tags origin
if [ "$DRY_RUN" = "true" ]; then
    [ -z "$(git status --porcelain -- Resources/Info.plist CHANGELOG.md)" ] \
        || fail "commit or stash your changes to Info.plist and CHANGELOG.md first"
else
    [ "$(git branch --show-current)" = "main" ] || fail "switch to main first"
    [ -z "$(git status --porcelain)" ] || fail "commit or stash your changes first"
    [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || fail "main is not in sync with origin/main. pull or push first"
fi
gh auth status >/dev/null 2>&1 || fail "gh is not signed in. run: gh auth login"

if [ -z "${KNURLINK_SIGN_IDENTITY:-}" ]; then
    IDENTITIES="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"$/\1/p' | sort -u)"
    [ -n "$IDENTITIES" ] || fail "no Developer ID Application identity in your keychain"
    [ "$(echo "$IDENTITIES" | wc -l | tr -d ' ')" = "1" ] || fail "more than one Developer ID identity found. set KNURLINK_SIGN_IDENTITY to pick one"
    KNURLINK_SIGN_IDENTITY="$IDENTITIES"
fi
export KNURLINK_SIGN_IDENTITY
echo "Signing as $KNURLINK_SIGN_IDENTITY"

if [ "$DRY_RUN" != "true" ]; then
    xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
        || fail "no notarytool profile named '$NOTARY_PROFILE'. create one with: xcrun notarytool store-credentials $NOTARY_PROFILE"
fi

REPOSITORY="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
PREVIOUS_TAG="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n 1)"

step "Checking changelog entries"
if [ -n "$PREVIOUS_TAG" ]; then
    git show "$PREVIOUS_TAG:CHANGELOG.md" > "$WORK/tagged-changelog.md"
    node scripts/check-changelog.mjs "$WORK/tagged-changelog.md"
fi

step "Determining version"
VERSION="$(node scripts/next-version.mjs)"
git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null && fail "tag v$VERSION already exists"
gh release view "v$VERSION" >/dev/null 2>&1 && fail "release v$VERSION already exists on GitHub"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Resources/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" Resources/Info.plist
echo "Version $VERSION${PREVIOUS_TAG:+ (previous $PREVIOUS_TAG)}"

step "Stamping changelog"
node scripts/stamp-changelog.mjs "$VERSION" "$(date -u +%F)" > "$WORK/changelog-notes.md"
if [ -s "$WORK/changelog-notes.md" ]; then
    echo "Moved [Unreleased] under [$VERSION]"
else
    echo "No unreleased entries. The release notes will list commits"
fi

step "Running tests"
node --test scripts/versioning.test.mjs
swift test

step "Building and signing"
./scripts/build-app.sh
test -f dist/knURLink.app/Contents/Resources/SponsorLogo.png
codesign --verify --strict --verbose=2 dist/knURLink.app

if [ "$DRY_RUN" = "true" ]; then
    ./scripts/create-dmg.sh
    codesign --force --timestamp --sign "$KNURLINK_SIGN_IDENTITY" dist/knURLink.dmg
    step "Dry run finished"
    echo "Built and signed v$VERSION in dist/. Skipped notarizing, committing, pushing, and publishing."
    echo "Info.plist and CHANGELOG.md are put back the way they were."
    exit 0
fi

step "Notarizing the app"
(
    cd dist
    rm -f knURLink.zip
    ditto -c -k --keepParent knURLink.app knURLink.zip
    xcrun notarytool submit knURLink.zip --keychain-profile "$NOTARY_PROFILE" --wait
    staple knURLink.app
    rm knURLink.zip
    ditto -c -k --keepParent knURLink.app knURLink.zip
)

step "Building and notarizing the disk image"
./scripts/create-dmg.sh
codesign --force --timestamp --sign "$KNURLINK_SIGN_IDENTITY" dist/knURLink.dmg
xcrun notarytool submit dist/knURLink.dmg --keychain-profile "$NOTARY_PROFILE" --wait
staple dist/knURLink.dmg
spctl --assess --type open --context context:primary-signature --verbose=2 dist/knURLink.dmg

step "Writing release notes"
if [ -s "$WORK/changelog-notes.md" ]; then
    cp "$WORK/changelog-notes.md" "$WORK/release-notes.md"
else
    git log "${PREVIOUS_TAG:+$PREVIOUS_TAG..}HEAD" --no-merges --format='- %s' > "$WORK/release-notes.md"
fi
if [ -n "$PREVIOUS_TAG" ]; then
    printf '\n**Full changelog:** https://github.com/%s/compare/%s...v%s\n' "$REPOSITORY" "$PREVIOUS_TAG" "$VERSION" >> "$WORK/release-notes.md"
fi
cat "$WORK/release-notes.md"

step "Committing and pushing Release v$VERSION"
git add Resources/Info.plist CHANGELOG.md
git commit --quiet -m "Release v$VERSION"
COMMITTED=true
git push origin HEAD:main
RELEASE_SHA="$(git rev-parse HEAD)"

step "Publishing the GitHub release"
cp "$WORK/release-notes.md" "$ROOT/dist/release-notes.md"
gh release create "v$VERSION" dist/knURLink.dmg dist/knURLink.zip \
    --target "$RELEASE_SHA" \
    --title "knURLink v$VERSION" \
    --notes-file dist/release-notes.md \
    || fail "the release commit is pushed, but publishing failed. retry with: gh release create v$VERSION dist/knURLink.dmg dist/knURLink.zip --target $RELEASE_SHA --title \"knURLink v$VERSION\" --notes-file dist/release-notes.md"

echo
echo "Released knURLink v$VERSION: https://github.com/$REPOSITORY/releases/tag/v$VERSION"
