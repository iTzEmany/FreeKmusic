import 'dart:io';

import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/ui/shell/drop_overlay.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Item extends DropItem {
  _Item(super.path);
}

void main() {
  late List<List<String>> got;
  late Directory dir;

  Future<void> pump(WidgetTester t) async {
    got = [];
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DropOverlay(
            onAudio: (p) async => got.add(p),
            child: const Text('app'),
          ),
        ),
      ),
    );
  }

  Future<void> drop(WidgetTester t, List<String> paths) async {
    t.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
      DropDoneDetails(files: [for (final p in paths) _Item(p)], localPosition: Offset.zero, globalPosition: Offset.zero),
    );
    // The callback is fire-and-forget: give the file checks real time to finish.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await t.pump();
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('drop');
    for (final n in ['a.mp3', 'b.flac', 'c.txt']) {
      File('${dir.path}/$n').writeAsStringSync('x');
    }
    Directory('${dir.path}/d.mp3').createSync();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('audio goes to «Apri con» in the dropped order', (t) async {
    await t.runAsync(() async {
      await pump(t);
      await drop(t, ['${dir.path}/b.flac', '${dir.path}/a.mp3']);
    });
    expect(got.single, ['${dir.path}/b.flac', '${dir.path}/a.mp3']);
  });

  testWidgets('non-audio, a folder and a missing path are refused with a message', (t) async {
    await t.runAsync(() async {
      await pump(t);
      await drop(t, ['${dir.path}/c.txt', '${dir.path}/d.mp3', '']);
    });
    await t.pump();
    expect(got, isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('the veil shows while dragging and goes on exit', (t) async {
    await pump(t);
    final target = t.widget<DropTarget>(find.byType(DropTarget));
    final d = DropEventDetails(localPosition: Offset.zero, globalPosition: Offset.zero);
    target.onDragEntered!(d);
    await t.pump();
    final veil = find.byWidgetPredicate((w) => w is ColoredBox && w.color == Colors.black54);
    expect(veil, findsOneWidget);
    target.onDragExited!(d);
    await t.pump();
    expect(veil, findsNothing);
  });
}
