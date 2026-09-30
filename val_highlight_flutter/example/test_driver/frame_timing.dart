// Collects the frame summaries from integration_test/frame_timing_test.dart
// and prints them as a table. Files land in build/frame_timing/.
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final dir = Directory('build/frame_timing')..createSync(recursive: true);
    stdout.writeln(
      '\nscenario                        frames  build avg/p90/worst ms   '
      'raster avg/p90/worst ms   missed budget',
    );
    for (final MapEntry(key: name, value: summary) in data.entries) {
      File(
        '${dir.path}/$name.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summary));
      final s = summary as Map<String, dynamic>;
      String ms(String key) => (s[key] as num).toStringAsFixed(1);
      final build =
          '${ms('average_frame_build_time_millis')}/'
          '${ms('90th_percentile_frame_build_time_millis')}/'
          '${ms('worst_frame_build_time_millis')}';
      final raster =
          '${ms('average_frame_rasterizer_time_millis')}/'
          '${ms('90th_percentile_frame_rasterizer_time_millis')}/'
          '${ms('worst_frame_rasterizer_time_millis')}';
      final missed =
          '${s['missed_frame_build_budget_count']}+'
          '${s['missed_frame_rasterizer_budget_count']}';
      stdout.writeln(
        '${name.padRight(32)}${'${s['frame_count']}'.padLeft(6)}  '
        '${build.padRight(24)}   ${raster.padRight(26)}$missed',
      );
    }
  },
);
