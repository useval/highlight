#!/usr/bin/env bash
#
# Pre-release gate for one package: verifies the version, the changelog and
# the score line up, then tags and pushes. Publishing itself happens on CI
# from the tag (.github/workflows/publish.yml).
#
#   ./scripts/release.sh val_highlight
#   ./scripts/release.sh val_highlight_flutter
#
# A version that is already on pub.dev (published by hand) is only tagged.
set -euo pipefail

cd "$(dirname "$0")/.."

PACKAGE="${1:?usage: release.sh <val_highlight|val_highlight_flutter>}"
if [[ "$PACKAGE" != "val_highlight" && "$PACKAGE" != "val_highlight_flutter" ]]; then
  echo "✗ unknown package '$PACKAGE' (expected val_highlight or val_highlight_flutter)" >&2
  exit 2
fi

VERSION="$(sed -n 's/^version: *//p' "$PACKAGE/pubspec.yaml")"
TAG="$PACKAGE-v$VERSION"
BRANCH="$(git branch --show-current)"
echo "▸ $PACKAGE $VERSION, tag $TAG, branch $BRANCH"

# pub.dev only counts the changelog when the version being published has its
# own heading. Publishing while it still says "Unreleased" tells users nothing.
if ! grep -qE "^## +\[?${VERSION//./\\.}\]?" "$PACKAGE/CHANGELOG.md"; then
  echo "✗ $PACKAGE/CHANGELOG.md has no '## $VERSION' heading."
  echo "  Rename the 'Unreleased' section before releasing."
  exit 1
fi
echo "▸ changelog has a heading for $VERSION"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "✗ working tree is dirty — commit before tagging"
  exit 1
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null ||
  git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "✗ tag $TAG already exists"
  exit 1
fi

just check

PUBLISHED=false
if curl -sf "https://pub.dev/api/packages/$PACKAGE" |
  grep -q "\"version\":\"$VERSION\""; then
  PUBLISHED=true
  echo "▸ $PACKAGE $VERSION is already on pub.dev — tagging only"
else
  ./scripts/score.sh "$PACKAGE" 160
fi

echo
echo "This will:"
echo "  • create the annotated tag $TAG on $(git rev-parse --short HEAD)"
echo "  • push branch $BRANCH and tag $TAG to origin"
if [[ "$PUBLISHED" == false ]]; then
  echo "  • publish $PACKAGE $VERSION to pub.dev through the Publish workflow"
fi
read -r -p "Go ahead? [y/N] " reply
if [[ ! "$reply" =~ ^[Yy]$ ]]; then
  echo "aborted — nothing tagged or pushed"
  exit 1
fi

git tag -a "$TAG" -m "$PACKAGE $VERSION"
git push origin "$BRANCH" "$TAG"

if [[ "$PUBLISHED" == true ]]; then
  echo "✓ pushed $TAG"
else
  echo "✓ pushed $TAG — the Publish workflow takes it from here"
fi
