#!/usr/bin/env bash
#
# The pub.dev gate for one package: packaging validation plus the full pana
# score, with the Flutter version pinned in .fvmrc.
#
# pana awards 160 points across eleven categories. Two of them — "dependencies
# support latest version" and "supports latest stable SDKs" — decay on their
# own as Flutter and the ecosystem move, so a score that was 160 last month
# may not be today.
#
#   ./scripts/score.sh val_highlight          # require all 160 points
#   ./scripts/score.sh val_highlight 150      # accept 150 or better
set -euo pipefail

cd "$(dirname "$0")/.."

PACKAGE="${1:?usage: score.sh <package> [threshold]}"
THRESHOLD="${2:-160}"
REPORT="/tmp/pana-${PACKAGE}.md"

if [[ ! -f "$PACKAGE/pubspec.yaml" ]]; then
  echo "no package named '$PACKAGE' (expected val_highlight or val_highlight_flutter)" >&2
  exit 2
fi

# pana always resolves dependencies from pub.dev and ignores
# dependency_overrides, so a package whose sibling is not published yet fails
# to resolve and loses most of its points for that reason alone.
if [[ "$PACKAGE" == "val_highlight_flutter" ]]; then
  core_version=$(sed -n 's/^version: *//p' val_highlight/pubspec.yaml)
  if ! curl -sf https://pub.dev/api/packages/val_highlight |
    grep -q "\"version\":\"$core_version\""; then
    printf '\033[33mval_highlight %s is not on pub.dev yet.\033[0m\n' "$core_version"
    echo "pana resolves dependencies from pub.dev only, so val_highlight_flutter"
    echo "cannot be scored until val_highlight $core_version is published."
    exit 1
  fi
fi

# pana's --exit-code-threshold is a DEFICIT, not a score: it fails when
# (max - granted) exceeds the number given.
MAX_POINTS=160
DEFICIT=$((MAX_POINTS - THRESHOLD))

# Locally, use the SDK pinned in .fvmrc; on CI, the one already on PATH.
if command -v fvm >/dev/null 2>&1; then
  FLUTTER="fvm flutter"
  DART="fvm dart"
else
  FLUTTER="flutter"
  DART="dart"
fi

FLUTTER_ROOT=$($FLUTTER --version --machine 2>/dev/null |
  sed -n 's/.*"flutterRoot": *"\([^"]*\)".*/\1/p')

printf '\n\033[1m▸ %s: publish dry run\033[0m\n' "$PACKAGE"
# Catches packaging problems pana does not: oversized archives, files that are
# checked in but gitignored, layout conventions. Uncommitted changes are a
# warning here, so this never fails the gate.
(cd "$PACKAGE" && $FLUTTER pub publish --dry-run) || true

printf '\n\033[1m▸ %s: pana\033[0m\n' "$PACKAGE"
if ! $DART pub global list 2>/dev/null | grep -q '^pana '; then
  $DART pub global activate pana >/dev/null
fi

$DART pub global run pana \
  --no-warning \
  --flutter-sdk "$FLUTTER_ROOT" \
  --exit-code-threshold "$DEFICIT" \
  "$PACKAGE" 2>&1 | tee "$REPORT" | grep -E '^### |^Points:'

printf '\n\033[32m✓ %s scores at least %s of %s\033[0m\n' \
  "$PACKAGE" "$THRESHOLD" "$MAX_POINTS"
printf 'full report: %s\n' "$REPORT"
