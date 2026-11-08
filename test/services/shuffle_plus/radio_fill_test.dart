import 'dart:io';

import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_radio_parser.dart';
import 'package:codecore/services/shuffle_plus/radio_fill.dart';
import 'package:codecore/services/shuffle_plus/radio_gate.dart';
import 'package:codecore/services/shuffle_plus/seed_index.dart';
import 'package:codecore/services/shuffle_plus/seed_resolver.dart';
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:codecore/services/shuffle_plus/suggestion_pool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

YtResult song(String id) => YtResult(
  id: id,
  title: 'Title $id',
  channel: 'Artist $id',
  duration: const Duration(seconds: 200),
  artists: ['Artist $id'],
  album: 'Album',
);

void main() {
  test('only the first request of the session ignores the gap; '
      'later ones wait for it, with the same continuation', () async {
    final dir = Directory.systemTemp.createTempSync('radio_fill');
    addTearDown(() => dir.deleteSync(recursive: true));
    final resolver = SeedResolver(
      downloads: DownloadIndex(File(p.join(dir.path, 'd.json'))),
      index: SeedIndex(file: () async => File(p.join(dir.path, 's.json'))),
      searchSongs: (q) async => const [],
    );
    final now = DateTime(2026, 11, 4);
    final gate = RadioGate(now: () => now)..asked(); // inside the gap
    final calls = <String?>[];
    final fill = RadioFill(
      seeds: [RadioSeed.online('seed', 'Seed')],
      resolver: resolver,
      radioPage: (id, {continuation}) async {
        calls.add(continuation);
        return RadioPage([
          RadioItem(song('seed'), RadioKind.song, isSeed: true),
          RadioItem(song('r${calls.length}'), RadioKind.song),
        ], continuation: 'next');
      },
      log: SuggestionLog(
        file: () async => File(p.join(dir.path, 'l.json')),
        writeDelay: const Duration(days: 1),
      ),
      gate: gate,
      inLibrary: (r) => false,
    );
    Future<List<String>> take() =>
        fill.take(1, inQueue: (_) => false).map((c) => c.result.id).toList();

    expect(await take(), ['r1']); // gap ignored: first of the session
    expect(await take(), isEmpty); // pool empty, gap closed: no request
    expect(calls, [null]);
    gate.lastRadio = now.subtract(RadioGate.minGap * 2);
    expect(await take(), ['r2']);
    expect(calls, [null, 'next']);
  });
}
