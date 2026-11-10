import 'package:codecore/data/repositories/memory_queries.dart';
import 'package:codecore/ui/screens/memory/folder_labels.dart';
import 'package:codecore/ui/screens/memory/memory_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

SizeGroup _g(String name, String path) =>
    SizeGroup(name: name, path: path, totals: const SizeTotals());

void main() {
  test('folders with the same name get the shortest distinguishing path', () {
    final labels = folderLabels([
      _g('Music', '/storage/emulated/0/Music'),
      _g(
        'Music',
        '/storage/emulated/0/Android/data/com.freekmusic.player/files/Music',
      ),
      _g('Podcasts', '/storage/emulated/0/Podcasts'),
    ]);
    expect(labels['/storage/emulated/0/Music'], 'Music');
    expect(
      labels['/storage/emulated/0/Android/data/com.freekmusic.player/files/Music'],
      'com.freekmusic.player/Music',
    );
    expect(labels['/storage/emulated/0/Podcasts'], 'Podcasts');
  });

  testWidgets('bars of rows with different size labels have the same width', (
    tester,
  ) async {
    final h = await Harness.create(tester, tracks: 1);
    await h.pump(
      tester,
      const Scaffold(
        body: Column(
          children: [
            WeightRow(title: 'a', bytes: 5, fraction: 1),
            WeightRow(title: 'b', bytes: 123456789012, fraction: 1),
          ],
        ),
      ),
    );
    final bars = tester.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bars.length, 2);
    final widths = [
      for (final e in find.byType(LinearProgressIndicator).evaluate())
        tester.getSize(find.byWidget(e.widget)).width,
    ];
    expect(widths[0], widths[1]);
  });
}
