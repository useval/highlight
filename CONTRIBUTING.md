# Contributing to val_highlight

Thanks for helping. This page covers how to report problems, set up the
project, and get a pull request merged.

The repository holds two packages:

- [`val_highlight`](val_highlight/) — the pure-Dart engine: grammars,
  themes, the scanner, HTML output.
- [`val_highlight_flutter`](val_highlight_flutter/) — the Flutter widgets:
  `CodeView`, `CodeField` and friends.

## Issues

Use the issue forms: **Bug report** or **Feature request**. For wrong
highlighting, the one thing that matters most is the **smallest code that
still shows the problem**, together with the language you highlight it as.
Please search open issues and pull requests first.

Many requests need no change to the package. A keyword list, an extra rule or
a theme entry can usually be added from your own app: see
[Changing a built-in language](val_highlight/README.md#-changing-a-built-in-language)
and [Themes](val_highlight/README.md#-themes).

## Setup

The repository is a [pub workspace](https://dart.dev/tools/pub/workspaces)
with a Flutter version pinned in `.fvmrc`. Every recipe runs through
[FVM](https://fvm.app), so install it first.

```sh
git clone https://github.com/useval/highlight.git
cd highlight
just setup
```

Recipes run with [`just`](https://github.com/casey/just); `just` with no
argument lists them. The ones you will use most:

| Recipe | What it does |
|---|---|
| `just check` | Format check, analyze, and every test on the VM and compiled to JavaScript — what CI runs |
| `just format` | Applies formatting |
| `just example-flutter` | Runs the example app; asks which device to use |
| `just bench` | Highlighting and HTML timings for 600 to 9,600 lines |
| `just bench-languages` | Speed per language on realistic source |
| `just sweep` | Runs every grammar over real source files and reports problems |
| `just score <package>` | The pub.dev score (pana) the package will get after publishing |
| `just publish-dry` | Packaging check for both packages, without uploading |

## Tests

`just check` must pass before a pull request is merged.

- **A fixed bug gets a regression test**, next to the tests for its language
  in `val_highlight/test/languages/`, or in the test file for the part of the
  engine you changed.
- **Golden snapshots.** Every language has realistic source in
  `val_highlight/test/golden_inputs/` and its reviewed highlighting in
  `val_highlight/test/goldens/`. If your change is meant to alter
  highlighting, update the snapshots and review the diff line by line:

  ```sh
  cd val_highlight
  UPDATE_GOLDENS=1 fvm dart test test/golden_test.dart
  ```

- **The web runs the same tests.** `just check` also runs the core tests
  compiled to JavaScript, where regular expressions behave slightly
  differently. A pattern that passes on the VM and fails there usually uses a
  feature JavaScript does not support.
- **Both scanner paths agree.** Dispatch, the plain-Dart matchers and
  incremental updates are fuzzed against the plain regular-expression result.
  A failure there is a real bug, not a flaky test.
- **Themes keep their contrast.** Every colour must reach WCAG AA contrast
  (4.5:1) against its background, 7:1 for the high-contrast themes.

## Adding or changing a language

1. Put the grammar in `val_highlight/lib/languages/<name>.dart`, and add it
   to `languages/all.dart` (the import, the export and `allLanguages`).
2. Prefer the building blocks (`LineComment`, `QuotedString`, `Numbers`, …)
   to raw regular expressions, and start patterns with something specific.
   See "Writing a grammar" in the [`val_highlight` README](val_highlight/README.md).
3. Add realistic source to `test/golden_inputs/<name>.txt`, generate its
   snapshot, and review every token.
4. Add edge-case tests: strings, comments, nesting, and anything the
   language does unusually.
5. Run `just sweep` on real files in that language if you have them, and
   `just bench-languages` to check its speed.
6. Run `just samples` so the example app's gallery includes it, and update
   the language count and lists in the READMEs.

## Making a change

**One change per pull request.** A fix, a feature, and a refactor are three
pull requests. Bundled changes are hard to review and are usually sent back.

What we look for:

- **No breaking changes** to the public API without discussion first. New
  options are optional and default to the current behaviour.
- **Speed is a feature.** For changes to the engine or a hot path, run
  `just bench` and `just bench-languages` before and after, and put the
  numbers in the pull request.
- **Identical results on every platform.** Native and web must produce the
  same tokens.
- **Small imports stay small.** Languages and themes are separate imports; do
  not make a single-language import pull in others.
- **A changelog entry** under `## Unreleased` in the `CHANGELOG.md` of each
  package you changed, in the same style as the entries already there.
- **Docs** updated when behaviour or API changes. Code samples in the READMEs
  should compile.

## After you open a pull request

A maintainer is requested for review automatically. CI runs the same checks as
`just check`, which need to pass. Expect review comments — most pull requests
go through a round or two.

## Releasing

Maintainers only. The two packages are versioned and released independently,
each with its own tag:

| Package | Tag |
|---|---|
| `val_highlight` | `val_highlight-v<version>` |
| `val_highlight_flutter` | `val_highlight_flutter-v<version>` |

To release:

1. Set `version` in the package's `pubspec.yaml`, and rename its changelog's
   `## Unreleased` heading to that version.
2. If `val_highlight_flutter` needs something new from `val_highlight`,
   release `val_highlight` first and raise the `val_highlight: ^x.y.z`
   constraint in `val_highlight_flutter/pubspec.yaml`.
3. Commit, then run `just release <package>`. It checks the changelog, runs
   `just check` and the pub.dev score, and asks before it tags and pushes.
4. The **Publish** workflow re-runs the checks on the tag and publishes the
   package to pub.dev.

A version already on pub.dev, such as a first release published by hand, is
only tagged; the workflow skips the publish step.

### Setting up a new package on pub.dev

Automated publishing can only be enabled once a package exists, so the first
version of each package is published by hand, from inside its folder:

```sh
cd val_highlight
fvm flutter pub publish
```

Publish `val_highlight` before `val_highlight_flutter`, which depends on it.
Then, on pub.dev, for each package:

1. **Admin → Transfer to publisher** → `useval.io`.
2. **Admin → Automated publishing** → enable publishing from GitHub Actions,
   with repository `useval/highlight` and tag pattern
   `<package>-v{{version}}`.

## License

val_highlight is released under the [BSD 3-Clause License](LICENSE). Your
contributions are released under the same license.
