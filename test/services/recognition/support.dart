import 'dart:convert';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart' show Track;
import 'package:codecore/services/online/acoustid_client.dart';
import 'package:codecore/services/online/innertube_client.dart';
import 'package:codecore/services/online/itunes_client.dart';
import 'package:codecore/services/online/metadata_resolver.dart';
import 'package:codecore/services/online/musicbrainz_client.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_song_parser.dart';
import 'package:codecore/services/recognition/track_recognizer.dart';
import 'package:codecore/services/tags/fingerprinter.dart';
import 'package:dio/dio.dart' show CancelToken;

Track track(String title, String? artist,
        {String path = '/m/x.mp3', int durationMs = 200000, String? isrc}) =>
    Track(
      coverSource: 0, id: 1, path: path, title: title, artist: artist, isrc: isrc,
      albumKey: 'k', durationMs: durationMs, format: 'mp3', sizeBytes: 1, mtimeMs: 1,
      hasCover: false, isFavorite: false, enrichStatus: 0, userEdited: false,
      missing: false, ignored: false, kind: 0, addedAt: 1, playCount: 0,
    );

List<AcoustIdHit> acoustIdFixture(String name) => parseAcoustId(
    jsonDecode(File('test/fixtures/acoustid/$name.json').readAsStringSync()) as Map);

/// Every source answers what the test sets and records what it was asked in [calls].
class Rig {
  final calls = <String>[];

  MbRecordingDetail? mbById;
  List<MbRecording> mbByIsrc = [];
  YtmSong? song;
  List<AcoustIdHit> hits = [];
  List<YtResult> ytm = [];
  ResolvedMeta? text;
  ({String? isrc, String? mbid}) ids = (isrc: null, mbid: null);
  bool acoustIdOn = true;
  bool acoustIdResting = false;
  bool fingerprintable = true;
  final isrcArgs = <String?>[];
  final ytmQueries = <String>[];
  Future<String?> Function(Track t)? videoIdFor;
  Object? mbError, acoustIdError, ytmError, textError, fingerprintError;

  late final recognizer = TrackRecognizer(
    musicBrainz: _Mb(this),
    innerTube: _Yt(this),
    acoustId: _Aid(this),
    fingerprinter: _Fp(this),
    useAcoustId: () => acoustIdOn,
    videoIdFor: videoIdFor,
    fileIds: (_) async => ids,
    now: () => DateTime.utc(2026, 11, 1),
  );

  Future<RecogOutcome> recognize(Track t, {CancelToken? cancel}) => recognizer.recognize(t,
      cancel: cancel,
      textProbe: (t, c, _) async {
        calls.add('text');
        if (textError != null) throw textError!;
        return text;
      });
}

ResolvedMeta meta(String title, String artist) =>
    ResolvedMeta(ItunesMatch(title: title, artist: artist), 'itunes');

class _Mb implements MusicBrainzClient {
  _Mb(this.r);
  final Rig r;

  @override
  Future<MbRecordingDetail?> recordingById(String mbid, {CancelToken? cancel}) async {
    r.calls.add('mb.id');
    if (r.mbError != null) throw r.mbError!;
    return r.mbById;
  }

  @override
  Future<List<MbRecording>> recordingsByIsrc(String isrc, int durationMs,
      {String? title, String? artist, CancelToken? cancel, bool strict = false}) async {
    r.calls.add('mb.isrc');
    r.isrcArgs.add('$title|$artist');
    if (r.mbError != null) throw r.mbError!;
    return r.mbByIsrc;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _Yt implements InnerTubeClient {
  _Yt(this.r);
  final Rig r;

  @override
  Future<YtmSong> songOf(String videoId, {CancelToken? cancel}) async {
    r.calls.add('songOf:$videoId');
    return r.song ?? (throw const InnerTubeChanged('no song'));
  }

  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5, CancelToken? cancel}) async {
    r.calls.add('ytm');
    r.ytmQueries.add(query);
    if (r.ytmError != null) throw r.ytmError!;
    return r.ytm;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _Aid implements AcoustIdClient {
  _Aid(this.r);
  final Rig r;

  @override
  bool get isResting => r.acoustIdResting;

  @override
  Future<List<AcoustIdHit>> lookup(String fp, int secs, {CancelToken? cancel}) async {
    r.calls.add('acoustid');
    if (r.acoustIdError != null) throw r.acoustIdError!;
    return r.hits;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _Fp implements Fingerprinter {
  _Fp(this.r);
  final Rig r;

  @override
  Future<({String fp, int secs})?> of(String path) async {
    r.calls.add('fp');
    if (r.fingerprintError != null) throw r.fingerprintError!;
    return r.fingerprintable ? (fp: 'AQAA', secs: 200) : null;
  }
}

