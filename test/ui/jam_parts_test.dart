import 'dart:convert';
import 'dart:typed_data';

import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/ui/screens/jam/jam_parts.dart';
import 'package:codecore/ui/widgets/net_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

class _CoverJam extends JamController {
  _CoverJam(this.initial);
  final JamUiState initial;
  int fetched = 0;

  @override
  JamUiState build() => initial;

  @override
  Future<Uint8List?> fetchCover(JamItem item) async {
    fetched++;
    return _png;
  }
}

void main() {
  test('jamTriviaText keeps the text and drops the source url', () {
    expect(jamTriviaText(null), isNull);
    expect(jamTriviaText('https://a.b/x'), isNull);
    expect(jamTriviaText('\nhttps://a.b'), isNull);
    expect(jamTriviaText('testo\nhttps://a.b'), 'testo');
    expect(jamTriviaText('testo\n'), 'testo');
    expect(jamTriviaText('  '), isNull);
    expect(jamTriviaText('uno\ndue\nhttps://a.b'), 'uno\ndue');
  });

  Future<_CoverJam> pumpCover(WidgetTester tester, JamItem item, {bool remote = false}) async {
    final h = await Harness.create(tester);
    final fake = _CoverJam(JamUiState(
        remote: remote,
        jam: JamState(version: 1, items: [item], hostDeviceId: 'h', outputDeviceId: 'h')));
    await tester.pumpWidget(ProviderScope(
      overrides: [...h.overrides, jamProvider.overrideWith(() => fake)],
      child: MaterialApp(home: Scaffold(body: JamCover(item: item, size: 48))),
    ));
    await tester.pump();
    await tester.pump();
    return fake;
  }

  testWidgets('JamCover: another device\'s numeric ref shows the fetched bytes once',
      (tester) async {
    final fake = await pumpCover(
        tester, const JamItem(id: 7, ownerDeviceId: 'x', title: 'T', ext: 'mp3', ref: '12'));
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.music_note_rounded), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(fake.fetched, 1);
  });

  testWidgets('JamCover: an online item shows the YouTube thumbnail, no fetch', (tester) async {
    final fake = await pumpCover(
        tester,
        const JamItem(
            id: 8, ownerDeviceId: 'x', title: 'T', ext: 'm4a', ref: 'yt:youtube:abcdefghijk',
            videoId: 'abcdefghijk'));
    expect(find.byType(NetThumbnail), findsOneWidget);
    expect(fake.fetched, 0);
  });

  testWidgets('JamCover: the note stays only when there is nothing', (tester) async {
    await pumpCover(tester, const JamItem(id: 9, ownerDeviceId: 'x', title: 'T', ext: 'mp3'));
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
  });

  testWidgets('JamCover: LAN library item of another device keeps its owner bytes even with a video id',
      (tester) async {
    final fake = await pumpCover(
        tester,
        const JamItem(
            id: 10, ownerDeviceId: 'x', title: 'T', ext: 'mp3', ref: '12', videoId: 'abcdefghijk'));
    expect(find.byType(NetThumbnail), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(fake.fetched, 1);
  });

  testWidgets('JamCover: remote guest, library item with a video id shows the thumbnail, no fetch',
      (tester) async {
    final fake = await pumpCover(
        tester,
        const JamItem(
            id: 11, ownerDeviceId: 'x', title: 'T', ext: 'mp3', ref: '12', videoId: 'abcdefghijk'),
        remote: true);
    expect(find.byType(NetThumbnail), findsOneWidget);
    expect(fake.fetched, 0);
  });

  testWidgets('JamCover: remote guest, library item without a video id shows the note, no fetch',
      (tester) async {
    final fake = await pumpCover(
        tester, const JamItem(id: 12, ownerDeviceId: 'x', title: 'T', ext: 'mp3', ref: '12'),
        remote: true);
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    expect(fake.fetched, 0);
  });
}
