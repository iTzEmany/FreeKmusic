import 'package:codecore/ui/widgets/cover_image.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// True when any semantics node carries the image flag.
bool _hasImage(WidgetTester tester) {
  var found = false;
  void walk(SemanticsNode n) {
    if (n.getSemanticsData().flagsCollection.isImage) found = true;
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
  return found;
}

/// Labels of every semantics node under the root that carries one.
List<String> _labels(WidgetTester tester) {
  final out = <String>[];
  void walk(SemanticsNode n) {
    if (n.label.isNotEmpty) out.add(n.label);
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
  return out;
}

void main() {
  coverHeroTests();
  testWidgets('a cover is hidden from the screen reader unless it has a label', (tester) async {
    final h = await Harness.create(tester, tracks: 1);
    final sem = tester.ensureSemantics();
    await h.pump(
      tester,
      const Column(children: [
        CoverImage(coverKey: null, size: 40),
        CoverImage(coverKey: null, size: 40, semanticLabel: 'Big cover'),
      ]),
    );
    expect(_labels(tester), ['Big cover']);
    sem.dispose();
    await h.dispose(tester);
  });

  testWidgets('an unlabeled cover drops the image node of its picture, a labeled one keeps one', (tester) async {
    final sem = tester.ensureSemantics();
    // The picture itself reports as an image, like Image.file does.
    final pic = Semantics(image: true, label: 'raw picture', child: const SizedBox(width: 40, height: 40));
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [coverSemantics(pic, null)]),
    ));
    expect(_hasImage(tester), isFalse);
    expect(_labels(tester), isEmpty);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [coverSemantics(pic, 'Big cover')]),
    ));
    expect(_hasImage(tester), isTrue);
    expect(_labels(tester), ['Big cover']);
    sem.dispose();
  });

  testWidgets('a track row says title and artist once, the cover adds no node', (tester) async {
    final h = await Harness.create(tester, tracks: 1);
    final t = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!.first;
    final sem = tester.ensureSemantics();
    await h.pump(tester, Scaffold(body: LiveTrackRow(track: t, onTap: () {})));
    final labels = _labels(tester).where((l) => l.contains(t.title)).toList();
    expect(labels, hasLength(1));
    expect(_hasImage(tester), isFalse);
    sem.dispose();
    await h.dispose(tester);
  });

  testWidgets('an online track row exposes one node for its title', (tester) async {
    final h = await Harness.create(tester, tracks: 1);
    final t = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!.first.copyWith(id: -1);
    final sem = tester.ensureSemantics();
    await h.pump(tester, Scaffold(body: LiveTrackRow(track: t, onTap: () {})));
    expect(_labels(tester).where((l) => l.contains(t.title)), hasLength(1));
    sem.dispose();
    await h.dispose(tester);
  });
}

void coverHeroTests() {
  for (final pop in [false, true]) {
    testWidgets('coverHero: ${pop ? 'closing' : 'opening'} flies as a circle, not an ellipse', (tester) async {
      Widget cover(double w, double h) => coverHero('c', SizedBox(width: w, height: h));
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(
              builder: (_) => Scaffold(body: Align(alignment: Alignment.topLeft, child: cover(300, 100))),
            )),
            child: cover(48, 48),
          ),
        ),
      ));
      await tester.tap(find.byType(TextButton));
      if (pop) {
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final size = tester.getSize(find.byType(ClipOval));
      expect(size.width, size.height);
      await tester.pumpAndSettle();
    });
  }
}
