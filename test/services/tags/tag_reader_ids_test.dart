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

  test('mbid comes from read_ids; the parser ISRC wins over it', () async {
    final reader = AudioMetadataTagReader(
      loftyIds: (_) async =>
          const mg.TrackIds(mbid: ' abc-123 ', isrc: 'zz-zz-0000000'),
    );
    final t = await reader.read('test/fixtures/sample.mp3');
    expect(t.title, 'Fixture Song');
    expect(t.mbid, 'abc-123');
    expect(t.isrc, 'ZZZZ0000000'); // sample.mp3 has no TSRC: lofty's is used
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
