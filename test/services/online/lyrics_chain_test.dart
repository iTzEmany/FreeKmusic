import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/lrclib_client.dart';
import 'package:codecore/services/online/lyrics_chain.dart';
import 'package:codecore/services/online/lyrics_ovh_client.dart';
import 'package:codecore/services/online/netease_lyrics_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Track _track({int durationMs = 370000}) => Track(
  coverSource: 0,
  id: 1,
  path: '/m/a.mp3',
  title: 'Get Lucky',
  artist: 'Daft Punk',
  albumKey: 'k',
  durationMs: durationMs,
  format: 'mp3',
  sizeBytes: 1,
  mtimeMs: 1,
  hasCover: false,
  isFavorite: false,
  enrichStatus: 0,
  userEdited: false,
  missing: false,
  ignored: false,
  kind: 0,
  addedAt: 1,
  playCount: 0,
);

class _Lrclib extends LrclibClient {
  _Lrclib(this.result, {this.error}) : super(_NoWeb());
  final LyricsResult? result;
  final Object? error;
  int calls = 0;
  @override
  Future<LyricsResult?> find({
    required String title,
    required String artist,
    String? album,
    int? durationSec,
    CancelToken? cancel,
    bool strict = false,
  }) async {
    calls++;
    if (error != null) throw error!;
    return result;
  }
}

class _Ne extends NeteaseLyricsClient {
  _Ne(this.result, {this.error}) : super(_NoWeb());
  final LyricsResult? result;
  final Object? error;
  int calls = 0;
  @override
  Future<LyricsResult?> find({
    required String title,
    required String artist,
    required int? durationSec,
    CancelToken? cancel,
  }) async {
    calls++;
    if (error != null) throw error!;
    return result;
  }
}

class _Ovh extends LyricsOvhClient {
  _Ovh(this.result) : super(_NoWeb());
  final LyricsResult? result;
  int calls = 0;
  @override
  Future<LyricsResult?> find({
    required String title,
    required String artist,
    CancelToken? cancel,
  }) async {
    calls++;
    return result;
  }
}

class _NoWeb implements WebClient {
  @override
  Future<Object?> getJson(
    String url, {
    Map<String, String>? query,
    CancelToken? cancel,
    bool strict = false,
  }) async => null;
  @override
  Future<List<int>?> getBytes(
    String url, {
    int maxBytes = 0,
    CancelToken? cancel,
  }) async => null;
}

const _synced = LyricsResult(synced: '[00:01.000] a');
const _plain = LyricsResult(plain: 'a');

void main() {
  test(
    'LRCLIB answering 503 rests: the next track does not ask it again',
    () async {
      var t = DateTime(2026);
      final lr = _Lrclib(null, error: const WebUnavailableException('u', 503));
      final chain = LyricsChain(lrclib: lr, ovh: _Ovh(_plain), now: () => t);
      final first = await chain.find(_track());
      final second = await chain.find(_track());
      expect(lr.calls, 1);
      expect([first.source, second.source], ['lyricsovh', 'lyricsovh']);
      expect(second.failed, isFalse); // a text was found
      t = t.add(const Duration(minutes: 4));
      await chain.find(_track());
      expect(lr.calls, 2);
    },
  );

  test('LRCLIB has the synced text: the fallbacks are not asked', () async {
    final ne = _Ne(_synced), ovh = _Ovh(_plain);
    final r = await LyricsChain(
      lrclib: _Lrclib(const LyricsResult(plain: 'p', synced: 's')),
      netease: ne,
      ovh: ovh,
    ).find(_track());
    expect(r.source, 'lrclib');
    expect(ne.calls + ovh.calls, 0);
  });

  test('LRCLIB plain + NetEase synced: merged', () async {
    final r = await LyricsChain(
      lrclib: _Lrclib(_plain),
      netease: _Ne(_synced),
      ovh: _Ovh(null),
    ).find(_track());
    expect(r.lyrics!.plain, 'a');
    expect(r.lyrics!.synced, '[00:01.000] a');
    expect(r.source, 'netease');
  });

  test('wantSynced false: NetEase is not asked', () async {
    final ne = _Ne(_synced);
    final r = await LyricsChain(
      lrclib: _Lrclib(_plain),
      netease: ne,
    ).find(_track(), wantSynced: false);
    expect(ne.calls, 0);
    expect(r.lyrics!.synced, isNull);
  });

  test(
    'nothing from LRCLIB and NetEase: lyrics.ovh gives the plain text',
    () async {
      final r = await LyricsChain(
        lrclib: _Lrclib(null),
        netease: _Ne(null),
        ovh: _Ovh(_plain),
      ).find(_track());
      expect(r.lyrics!.plain, 'a');
      expect(r.source, 'lyricsovh');
      expect(r.failed, isFalse);
    },
  );

  test('every source empty and valid: no text, not failed', () async {
    final r = await LyricsChain(
      lrclib: _Lrclib(null),
      netease: _Ne(null),
      ovh: _Ovh(null),
    ).find(_track());
    expect(r.lyrics, isNull);
    expect(r.failed, isFalse);
  });

  test('LRCLIB plain and NetEase in error: the text is there, the synced one is unknown', () async {
    final chain = LyricsChain(
      lrclib: _Lrclib(_plain),
      netease: _Ne(null, error: StateError('x')),
    );
    final r = await chain.find(_track());
    expect(r.lyrics!.plain, 'a');
    expect([r.failed, r.syncedFailed], [false, true]);
    final empty = await LyricsChain(
      lrclib: _Lrclib(_plain),
      netease: _Ne(null),
    ).find(_track());
    expect(empty.syncedFailed, isFalse);
  });

  test('a source errors and nothing is found: failed; an error with text found elsewhere is not', () async {
    final bad = LyricsChain(
      lrclib: _Lrclib(null),
      netease: _Ne(null, error: StateError('x')),
      ovh: _Ovh(null),
    );
    expect((await bad.find(_track())).failed, isTrue);
    final ok = LyricsChain(
      lrclib: _Lrclib(null),
      netease: _Ne(null, error: StateError('x')),
      ovh: _Ovh(_plain),
    );
    final r = await ok.find(_track());
    expect(r.failed, isFalse);
    expect(r.lyrics!.plain, 'a');
  });

  test(
    'LRCLIB in error and the fallbacks empty: failed, and they are still asked',
    () async {
      final ne = _Ne(null);
      final c = LyricsChain(
        lrclib: _Lrclib(null, error: const WebUnavailableException('u', 503)),
        netease: ne,
        ovh: _Ovh(null),
      );
      final r = await c.find(_track());
      expect(r.failed, isTrue);
      expect(ne.calls, 1);
    },
  );

  test('LRCLIB cancelled: the chain rethrows and asks nobody else', () async {
    final ne = _Ne(_synced), ovh = _Ovh(_plain);
    final c = LyricsChain(
      lrclib: _Lrclib(
        null,
        error: DioException.requestCancelled(
          requestOptions: RequestOptions(),
          reason: 'x',
        ),
      ),
      netease: ne,
      ovh: ovh,
    );
    await expectLater(c.find(_track()), throwsA(isA<DioException>()));
    expect(ne.calls + ovh.calls, 0);
  });

  test('NetEase gives the synced text: lyrics.ovh is not asked', () async {
    final ovh = _Ovh(_plain);
    await LyricsChain(
      lrclib: _Lrclib(null),
      netease: _Ne(_synced),
      ovh: ovh,
    ).find(_track());
    expect(ovh.calls, 0);
  });

  test('LRCLIB resting: failed but not limited, so the run does not drop the lyrics part', () async {
    final t = DateTime(2026);
    final chain = LyricsChain(
      lrclib: _Lrclib(null, error: const WebUnavailableException('u', 503)),
      ovh: _Ovh(_plain),
      now: () => t,
    );
    final first = await chain.find(_track());
    final second = await chain.find(_track());
    expect([first.limited, second.limited, second.syncedFailed], [false, false, true]);
    expect(second.lyrics, isNotNull);
  });

  test('429 from a fallback after a LRCLIB text: text kept, limited', () async {
    final r = await LyricsChain(
      lrclib: _Lrclib(_plain),
      netease: _Ne(null, error: const RateLimitedException(429)),
    ).find(_track());
    expect(r.lyrics?.plain, 'a');
    expect([r.limited, r.syncedFailed], [true, true]);
  });
}
