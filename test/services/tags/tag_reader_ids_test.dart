import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:codecore/services/tags/audio_metadata_tag_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metadata_god/metadata_god.dart' as mg;

const _fixtures = 'test/services/tags/fixtures';

void main() {
  Future<mg.TrackIds> noIds(String _) async => const mg.TrackIds();

  for (final ext in ['mp3', 'm4a']) {
    test('a full date (20151119) in $ext breaks the parser and lofty fills in',
        () {
      expect(
        () => readMetadata(File('$_fixtures/fulldate.$ext'), getImage: false),
        throwsA(anything),
      );
    });

    test('falls back to lofty when the parser throws on $ext', () async {
      final reader = AudioMetadataTagReader(
        loftyRead: (_) async => mg.Metadata(
          title: 'Full Date Song',
          artist: 'Full Date Artist',
          album: 'Full Date Album',
          year: 2015,
          durationMs: 1000,
        ),
        loftyIds: noIds,
      );
      final t = await reader.read('$_fixtures/fulldate.$ext');
      expect(t.title, 'Full Date Song');
      expect(t.artist, 'Full Date Artist');
      expect(t.album, 'Full Date Album');
      expect(t.year, 2015);
      expect(t.durationMs, 1000);
    });
  }

  test('mbid comes from read_ids, trimmed; blank is null', () async {
    final ids = ['  abc-123 ', '   '];
    final reader = AudioMetadataTagReader(
      loftyIds: (_) async => mg.TrackIds(mbid: ids.removeAt(0)),
    );
    expect((await reader.read('test/fixtures/sample.mp3')).mbid, 'abc-123');
    expect((await reader.read('test/fixtures/sample.mp3')).mbid, isNull);
  });

  test('the ISRC from the parser wins over read_ids', () async {
    final reader = AudioMetadataTagReader(
      loftyIds: (_) async => const mg.TrackIds(isrc: 'zz-zz-0000000'),
    );
    expect((await reader.read('$_fixtures/isrc.mp3')).isrc, 'GBAYE0601498');
    // without a parser ISRC, lofty's is used (normalized)
    expect((await reader.read('test/fixtures/sample.mp3')).isrc, 'ZZZZ0000000');
  });

  test('a bogus year from lofty is dropped', () async {
    final reader = AudioMetadataTagReader(
      loftyRead: (_) async => mg.Metadata(title: 'T', year: 5),
      loftyIds: noIds,
    );
    final t = await reader.read('$_fixtures/fulldate.mp3');
    expect(t.title, 'T');
    expect(t.year, isNull);
  });

  test('a failing read_ids keeps the tags', () async {
    final reader = AudioMetadataTagReader(
      loftyIds: (_) async => throw StateError('no native lib'),
    );
    final t = await reader.read('test/fixtures/sample.mp3');
    expect(t.title, 'Fixture Song');
    expect(t.mbid, isNull);
  });
}
