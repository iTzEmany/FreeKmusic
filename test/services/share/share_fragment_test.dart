import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:codecore/services/share/share_fragment.dart';

String _b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
String _frag(String payload) => _b64(gzip.encode(utf8.encode(payload)));
List<SharedRow> _ids(int n) => [
  for (var i = 0; i < n; i++) SharedRow.id('abcdefgh${(i ~/ 10) % 10}_${i % 10}'),
];
List<String> _idStrs(int n) => [for (final r in _ids(n)) r.id!];

void main() {
  test('round trip for 1 and 50 tracks', () {
    for (final n in [1, kMaxSharedTracks]) {
      final f = SharedFragment(SharedKind.playlist, 'Mix', _ids(n));
      final d = decodeShareFragment(encodeShareFragment(f));
      expect(d.kind, SharedKind.playlist);
      expect(d.title, 'Mix');
      expect(d.rows, f.rows);
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

  test('blank title is encoded as "Senza titolo"', () {
    for (final t in ['', '  \n ']) {
      final f = SharedFragment(SharedKind.track, t, _ids(1));
      expect(decodeShareFragment(encodeShareFragment(f)).title, 'Senza titolo');
    }
  });

  test('leading # is stripped', () {
    final e = encodeShareFragment(
      SharedFragment(SharedKind.track, 'a', _ids(1)),
    );
    expect(decodeShareFragment('#$e').title, 'a');
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
      SharedFragment(SharedKind.playlist, 'M', [for (final i in ids) SharedRow.id(i)]),
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
      _frag('FK3\nt\nT\nabcdefghijk'),
      _frag('FK1\nx\nT\nabcdefghijk'),
      _frag('FK1\nt\nT\nabcdefghij'),
      _frag('FK1\nt\nT\nabcdefghij!'),
      _frag('FK1\nt\nT\n'),
      _frag('FK1\nt\nT\n${_idStrs(51).join()}'),
      _frag('FK1\nt\nT'),
      _frag('FK1\nt\n\nabcdefghijk'),
      _frag('FK1\nt\n  \nabcdefghijk'),
      _frag('FK1\nt\n${'x' * 121}\nabcdefghijk'),
      _frag('FK1\nt\nT\nabcde\nfghijk'),
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

  test('a ~200 MB bomb is cut quickly', () {
    final bomb = _b64(gzip.encode(Uint8List(200 * 1024 * 1024)));
    final sw = Stopwatch()..start();
    expect(() => decodeShareFragment(bomb), throwsA(isA<ShareFragmentError>()));
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
  });

  Matcher failsWith(String part) => throwsA(
    isA<ShareFragmentError>().having(
      (e) => e.message,
      'message',
      contains(part),
    ),
  );

  test('a truncated or extended gzip stream is rejected, however short the cut', () {
    final gz = gzip.encode(utf8.encode('FK1\np\nMix\n${_idStrs(30).join()}'));
    for (var cut = 1; cut <= 40; cut++) {
      expect(
        () => decodeShareFragment(_b64(gz.sublist(0, gz.length - cut))),
        throwsA(isA<ShareFragmentError>()),
        reason: 'cut $cut',
      );
    }
    for (final tail in [
      [0],
      [1, 2, 3],
      [0, 0, 0, 0],
    ]) {
      expect(
        () => decodeShareFragment(_b64([...gz, ...tail])),
        throwsA(isA<ShareFragmentError>()),
        reason: 'tail $tail',
      );
    }
  });

  test('zlib instead of gzip, and two gzip members, are rejected', () {
    final payload = utf8.encode('FK1\nt\nx\nabcdefghijk');
    expect(
      () => decodeShareFragment(_b64(zlib.encode(payload))),
      failsWith('gzip'),
    );
    final two = [
      ...gzip.encode(utf8.encode('FK1\nt\nx\n')),
      ...gzip.encode(utf8.encode('abcdefghijk')),
    ];
    expect(
      () => decodeShareFragment(_b64(two)),
      throwsA(isA<ShareFragmentError>()),
    );
  });

  test('anything after the base64url body is rejected', () {
    final e = encodeShareFragment(
      SharedFragment(SharedKind.track, 'a', _ids(1)),
    );
    for (final bad in ['$e!', '$e%3D', '$e?x=1', '$e x', '$e===', '##$e']) {
      expect(
        () => decodeShareFragment(bad),
        throwsA(isA<ShareFragmentError>()),
        reason: bad,
      );
    }
  });

  test('padding too short or too long is rejected, the exact one accepted', () {
    var checked = 0;
    for (final t in ['a', 'ab', 'abc', 'abcd']) {
      final e = encodeShareFragment(
        SharedFragment(SharedKind.track, t, _ids(1)),
      );
      final need = (4 - e.length % 4) % 4;
      if (need == 0) continue;
      checked++;
      expect(decodeShareFragment(e + '=' * need).title, t);
      for (final n in [need - 1, need + 1].where((n) => n > 0)) {
        expect(
          () => decodeShareFragment(e + '=' * n),
          throwsA(isA<ShareFragmentError>()),
          reason: '$t +$n',
        );
      }
    }
    expect(checked, greaterThan(0));
  });

  test('64 KB boundary: 65536 bytes reach the layout check, 65537 are too large', () {
    expect(
      () => decodeShareFragment(_b64(gzip.encode(List.filled(65536, 65)))),
      failsWith('layout'),
    );
    expect(
      () => decodeShareFragment(_b64(gzip.encode(List.filled(65537, 65)))),
      failsWith('too large'),
    );
  });

  test('layout: five lines, wrong kind code, a title of only U+0085', () {
    for (final p in [
      'FK1\nt\nT\nabcdefghijk\nabcdefghijk',
      'FK1\ntt\nT\nabcdefghijk',
      'FK1\nt \nT\nabcdefghijk',
      'FK1\nta\nT\nabcdefghijk',
      'FK1\nt\n\u0085\nabcdefghijk',
    ]) {
      expect(
        () => decodeShareFragment(_frag(p)),
        throwsA(isA<ShareFragmentError>()),
        reason: p,
      );
    }
  });

  test('encode rejects ids that are not 11 valid characters', () {
    for (final id in ['abcdefghij', 'abcdefghijkl', 'abcdefghij!']) {
      expect(
        () => encodeShareFragment(SharedFragment(SharedKind.track, 'x', [SharedRow.id(id)])),
        throwsA(isA<ShareFragmentError>()),
        reason: id,
      );
    }
  });

  test('FK2: ids and search rows mix and round trip; all-id rows still use FK1', () {
    const mixed = [SharedRow.id('dQw4w9WgXcQ'), SharedRow.search('Città', 'Canzone 日本語'), SharedRow.search('', 'Solo titolo')];
    final f = SharedFragment(SharedKind.playlist, 'Mix', mixed);
    expect(decodeShareFragment(encodeShareFragment(f)).rows, mixed);
    String payload(String frag) => utf8.decode(gzip.decode(base64Url.decode(base64Url.normalize(frag))));
    expect(payload(encodeShareFragment(f)), startsWith('FK2\n'));
    expect(payload(encodeShareFragment(SharedFragment(SharedKind.track, 'x', _ids(1)))), startsWith('FK1\n'));
  });

  test('a search row is clipped to 60 + 80 characters and tabs or newlines become spaces', () {
    final f = SharedFragment(SharedKind.track, 'x', [SharedRow.search('a\tb${'A' * 100}', 'T\n${'t' * 100}')]);
    final r = decodeShareFragment(encodeShareFragment(f)).rows.single;
    expect((r.artist!.runes.length, r.title!.runes.length), (60, 80));
    expect(r.artist, startsWith('a b'));
  });

  test('an emoji across the 60/80 cut is kept whole or dropped whole, never split', () {
    final f = SharedFragment(SharedKind.track, 'x', [SharedRow.search('${'a' * 59}🎵🎵', '${'b' * 79}🎵🎵')]);
    final r = decodeShareFragment(encodeShareFragment(f)).rows.single;
    expect(r.artist, '${'a' * 59}🎵');
    expect(r.title, '${'b' * 79}🎵');
  });

  test('FK2 rejects empty rows, long rows, a blank title, a bad id, too many rows', () {
    final bad = [
      'FK2\nt\nT\nabcdefghijk\n',
      'FK2\nt\nT\n\nabcdefghijk',
      'FK2\nt\nT\n~A\t${'x' * 81}',
      'FK2\nt\nT\n~${'A' * 61}\tx',
      'FK2\nt\nT\n~A\t ',
      'FK2\nt\nT\n~Ax',
      'FK2\nt\nT\nnot an id',
      'FK2\nt\nT\n${List.filled(51, '~A\tB').join('\n')}',
    ];
    for (final b in bad) {
      expect(() => decodeShareFragment(_frag(b)), throwsA(isA<ShareFragmentError>()), reason: b);
    }
  });

  test('a search row with no artist and no title round-trips as «Senza titolo»', () {
    final f = SharedFragment(SharedKind.track, 'x', const [SharedRow.search('A', '')]);
    expect(decodeShareFragment(encodeShareFragment(f)).rows.single, const SharedRow.search('A', untitledShare));
  });

  test('gzip with the right CRC and a wrong ISIZE is rejected', () {
    final raw = gzip.encode(utf8.encode('FK1\nt\nT\nabcdefghijk'));
    raw[raw.length - 4] ^= 1;
    expect(() => decodeShareFragment(_b64(raw)), throwsA(isA<ShareFragmentError>()));
  });

  test('shared vectors: positive decode, negative are rejected', () {
    final v = jsonDecode(
      File('test/services/share/fragment_vectors.json').readAsStringSync(),
    ) as List;
    expect(v, isNotEmpty);
    for (final e in v) {
      final f = e['fragment'] as String;
      if (e['error'] == true) {
        expect(
          () => decodeShareFragment(f),
          throwsA(isA<ShareFragmentError>()),
          reason: e['name'] as String,
        );
        continue;
      }
      final d = decodeShareFragment(f);
      expect(d.kind.code, e['kind']);
      expect(d.title, e['title']);
      expect(d.rows, [
        for (final r in (e['rows'] ?? e['ids']) as List)
          r is String ? SharedRow.id(r) : SharedRow.search(r['artist'] as String, r['title'] as String),
      ]);
    }
  });
}
