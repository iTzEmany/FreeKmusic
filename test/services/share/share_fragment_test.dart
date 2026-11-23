import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:codecore/services/share/share_fragment.dart';

String _b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
String _frag(String payload) => _b64(gzip.encode(utf8.encode(payload)));
List<String> _ids(int n) => [
  for (var i = 0; i < n; i++) 'abcdefgh${(i ~/ 10) % 10}_${i % 10}',
];

void main() {
  test('round trip for 1 and 50 tracks', () {
    for (final n in [1, kMaxSharedTracks]) {
      final f = SharedFragment(SharedKind.playlist, 'Mix', _ids(n));
      final d = decodeShareFragment(encodeShareFragment(f));
      expect(d.kind, SharedKind.playlist);
      expect(d.title, 'Mix');
      expect(d.ids, f.ids);
    }
  });

  test('51 tracks or none: error on encode', () {
    expect(
      () =>
          encodeShareFragment(SharedFragment(SharedKind.album, 'x', _ids(51))),
      throwsA(isA<ShareFragmentError>()),
    );
    expect(
      () =>
          encodeShareFragment(const SharedFragment(SharedKind.album, 'x', [])),
      throwsA(isA<ShareFragmentError>()),
    );
  });

  test('title: newlines become spaces, unicode kept, clipped at 120', () {
    final f = SharedFragment(SharedKind.track, 'a\nb\r\n日本語 🎵', _ids(1));
    expect(decodeShareFragment(encodeShareFragment(f)).title, 'a b  日本語 🎵');
    final long = SharedFragment(SharedKind.track, '🎵' * 200, _ids(1));
    expect(
      decodeShareFragment(encodeShareFragment(long)).title.runes.length,
      120,
    );
  });

  test('padding is tolerated and never emitted', () {
    final e = encodeShareFragment(
      SharedFragment(SharedKind.track, 'ab', _ids(1)),
    );
    expect(e.contains('='), isFalse);
    final padded = e.padRight(e.length + (4 - e.length % 4) % 4, '=');
    expect(decodeShareFragment(padded).title, 'ab');
  });

  test('length is about 12-13 chars per track at 50 tracks', () {
    final r = Random(
      7,
    ); // real ids are near-random, repetitive ones compress too well
    const a =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
    final ids = [
      for (var i = 0; i < 50; i++)
        String.fromCharCodes([
          for (var j = 0; j < 11; j++) a.codeUnitAt(r.nextInt(64)),
        ]),
    ];
    final e = encodeShareFragment(
      SharedFragment(SharedKind.playlist, 'M', ids),
    );
    expect(e.length / 50, inInclusiveRange(11, 14));
  });

  test('bad input gives ShareFragmentError', () {
    final good = encodeShareFragment(
      SharedFragment(SharedKind.track, 't', _ids(2)),
    );
    final bad = <String>[
      '',
      '***not base64***',
      good.substring(0, good.length ~/ 2),
      _b64(utf8.encode('plain text, not gzip')),
      _frag('FK2\nt\nT\nabcdefghijk'),
      _frag('FK1\nx\nT\nabcdefghijk'),
      _frag('FK1\nt\nT\nabcdefghij'),
      _frag('FK1\nt\nT\nabcdefghij!'),
      _frag('FK1\nt\nT\n'),
      _frag('FK1\nt\nT\n${_ids(51).join()}'),
      _frag('FK1\nt\nT'),
      _b64(gzip.encode(List.filled(10 * 1024 * 1024, 65))),
      _b64(gzip.encode([0xff, 0xfe, 0x0a, 0x0a, 0x0a])),
    ];
    for (final s in bad) {
      expect(
        () => decodeShareFragment(s),
        throwsA(isA<ShareFragmentError>()),
        reason: s.length > 40 ? s.substring(0, 40) : s,
      );
    }
  });

  test('vectors produced by Dart decode to the expected payload', () {
    final v = jsonDecode(
      File('test/services/share/fragment_vectors.json').readAsStringSync(),
    ) as List;
    for (final e in v) {
      final d = decodeShareFragment(e['fragment'] as String);
      expect(d.kind.code, e['kind']);
      expect(d.title, e['title']);
      expect(d.ids, e['ids']);
    }
  });
}
