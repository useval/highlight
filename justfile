# val_highlight workspace commands. Run `just` to list them.
# Every command uses the Flutter version pinned in .fvmrc.

flutter := "fvm flutter"
dart := "fvm dart"
example := "val_highlight_flutter/example"

# List commands.
default:
    @just --list

# Install the pinned Flutter SDK and fetch dependencies.
setup:
    fvm install
    {{flutter}} pub get

# Fetch dependencies for the whole workspace.
get:
    {{flutter}} pub get

# Format all Dart code.
format:
    {{dart}} format .

# Check formatting without changing files.
format-check:
    {{dart}} format --output=none --set-exit-if-changed .

# Analyze every package.
analyze:
    {{flutter}} analyze

# Run the core tests on the Dart VM.
test-core:
    cd val_highlight && {{dart}} test

# Run the core tests compiled to JavaScript (web regex engine).
test-core-js:
    cd val_highlight && {{dart}} test -p node

# Run the Flutter package tests.
test-flutter:
    cd val_highlight_flutter && {{flutter}} test

# Run the example app tests.
test-example:
    cd {{example}} && {{flutter}} test

# Run every test.
test: test-core test-flutter test-example

# Everything CI checks.
check: format-check analyze test test-core-js

# Highlighting time by input size, and one incremental keystroke (compiled, like a release app).
bench:
    cd val_highlight && {{dart}} compile exe benchmark/scaling.dart -o .dart_tool/bench_scaling >/dev/null
    val_highlight/.dart_tool/bench_scaling

# Per-language speed, compiled to native code.
bench-languages:
    cd val_highlight && {{dart}} compile exe benchmark/languages.dart -o .dart_tool/bench_languages >/dev/null
    val_highlight/.dart_tool/bench_languages

# Per-language speed, compiled to JavaScript and run on Node (web engine).
bench-js:
    cd val_highlight && {{dart}} compile js -O2 benchmark/languages.dart -o .dart_tool/bench_languages.js >/dev/null
    node val_highlight/.dart_tool/bench_languages.js

# Run every grammar over real files and report problems (crashes, scanner
# mismatches, slow files, strings or comments left open). Defaults to the
# pinned Flutter SDK and the pub cache; pass directories to scan others.
sweep *dirs:
    cd val_highlight && {{dart}} compile exe tool/corpus_sweep.dart -o .dart_tool/sweep >/dev/null
    val_highlight/.dart_tool/sweep --per-language=1000 {{ if dirs == "" { "$(fvm flutter --version --machine 2>/dev/null | sed -n 's/.*\"flutterRoot\": *\"\\([^\"]*\\)\".*/\\1/p') $HOME/.pub-cache/hosted/pub.dev" } else { dirs } }}

# Frame timings for scrolling and typing, in profile mode. Asks for a device unless one is given.
bench-frames device="":
    cd {{example}} && {{flutter}} drive --profile {{ if device == "" { "" } else { "-d " + device } }} --driver=test_driver/frame_timing.dart --target=integration_test/frame_timing_test.dart

# Smoke-test the example app and editor on a device. Asks for a device unless one is given.
test-device device="":
    cd {{example}} && {{flutter}} test integration_test/app_test.dart {{ if device == "" { "" } else { "-d " + device } }}
    cd {{example}} && {{flutter}} test integration_test/editor_test.dart {{ if device == "" { "" } else { "-d " + device } }}

# Run the pure-Dart example.
example-dart:
    cd val_highlight && {{dart}} run example/main.dart

# List the devices the example can run on.
devices:
    {{flutter}} devices

# Run the Flutter example. Asks for a device unless one is given (e.g. `just example-flutter chrome`).
example-flutter device="":
    cd {{example}} && {{flutter}} run {{ if device == "" { "" } else { "-d " + device } }}

# Run the Flutter example on the web.
example-web:
    cd {{example}} && {{flutter}} run -d chrome

# Regenerate the example gallery's samples from the golden inputs.
samples:
    cd {{example}} && {{dart}} run tool/generate_samples.dart && {{dart}} format lib/samples.g.dart

# Regenerate the README images in screenshots/. Review them before committing.
screenshots:
    cd val_highlight_flutter && {{flutter}} test tool/screenshots/generate_test.dart --update-goldens

# Build the Flutter example for the web into val_highlight_flutter/example/build/web.
build-web:
    cd {{example}} && {{flutter}} build web

# pub.dev points after publishing; fails under the threshold. The Flutter package needs val_highlight on pub.dev first.
score package="val_highlight" threshold="160":
    ./scripts/score.sh {{package}} {{threshold}}

# Same, but never fails, for seeing where the points went.
score-soft package="val_highlight":
    ./scripts/score.sh {{package}} 0

# Full pana report from the last `just score`, with every suggestion.
score-report package="val_highlight":
    @test -f /tmp/pana-{{package}}.md || (echo "run 'just score {{package}}' first" && exit 1)
    @cat /tmp/pana-{{package}}.md

# Packaging check for both packages, without uploading. Reports problems, never fails.
publish-dry:
    -cd val_highlight && {{flutter}} pub publish --dry-run
    -cd val_highlight_flutter && {{flutter}} pub publish --dry-run

# Remove build outputs.
clean:
    cd {{example}} && {{flutter}} clean
    rm -rf .dart_tool val_highlight/.dart_tool val_highlight_flutter/.dart_tool
