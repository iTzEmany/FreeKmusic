import 'package:dio/dio.dart';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import 'http_client.dart';
import 'lrclib_client.dart';
import 'lyrics_ovh_client.dart';
import 'netease_lyrics_client.dart';
import 'query_cleaner.dart';

class LyricsChainResult {
  const LyricsChainResult({
    this.lyrics,
    this.failed = false,
    this.syncedFailed = false,
    this.limited = false,
    this.source,
  });

  final LyricsResult? lyrics;

  /// A fallback source errored and there is no text, so «nothing found» must not be remembered.
  final bool failed;

  /// LRCLIB or NetEase errored, so a missing synchronised text may only be unknown (even when plain text was found).
  final bool syncedFailed;

  /// A source was resting or refused (429): what is missing is unknown, and asking again now is pointless.
  final bool limited;

  /// Which source gave the text: 'lrclib', 'netease' or 'lyricsovh'.
  final String? source;
}

/// LRCLIB, then NetEase for the synchronised text, then lyrics.ovh for any text (D-111).
class LyricsChain {
  LyricsChain({
    required this.lrclib,
    this.netease,
    this.ovh,
    this.rest = const Duration(minutes: 3),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final LrclibClient lrclib;
  final NeteaseLyricsClient? netease;
  final LyricsOvhClient? ovh;

  /// How long LRCLIB is left alone after it answered 5xx (overloaded); the
  /// other sources carry on, and the track is not marked «nothing found».
  final Duration rest;
  final DateTime Function() _now;
  DateTime? _lrclibRestUntil;

  /// LRCLIB is being left alone: a «limited» answer from it is temporary, not a quota.
  bool get isResting => _lrclibRestUntil?.isAfter(_now()) ?? false;

  static bool _has(String? s) => s != null && s.isNotEmpty;

  /// Cancellation propagates; a rate limit gives [LyricsChainResult.limited] (a text already found is kept) and any other source error (LRCLIB included) is logged and reported as [LyricsChainResult.failed].
  Future<LyricsChainResult> find(
    Track t, {
    bool wantSynced = true,
    CancelToken? cancel,
  }) async {
    final c = cleanSearchQuery(t.title, t.artist ?? '');
    final sec = t.durationMs > 0 ? (t.durationMs / 1000).round() : null;
    var failed = false, limited = false;
    Future<LyricsResult?> fallback(Future<LyricsResult?> Function() f) async {
      try {
        return await f();
      } on RateLimitedException catch (e) {
        AppLog.w('lyrics fallback refused', e);
        failed = limited = true;
        return null;
      } on DioException {
        rethrow;
      } catch (e, st) {
        AppLog.w('lyrics fallback failed', e, st);
        failed = true;
        return null;
      }
    }

    final resting = isResting;
    if (resting) failed = limited = true;
    final lr = resting
        ? null
        : await fallback(() async {
            try {
              return await lrclib.find(
                title: c.title,
                artist: c.artist,
                album: t.album,
                durationSec: sec,
                cancel: cancel,
                strict: true,
              );
            } on WebUnavailableException catch (e) {
              if ((e.statusCode ?? 0) >= 500) {
                AppLog.w(
                  'LRCLIB answered ${e.statusCode}: resting ${rest.inMinutes} min',
                );
                _lrclibRestUntil = _now().add(rest);
              }
              rethrow;
            }
          });
    var plain = lr?.plain, synced = lr?.synced;
    String? source = lr == null || lr.isEmpty ? null : 'lrclib';
    final ne = netease;
    if (wantSynced && !_has(synced) && ne != null) {
      final r = await fallback(
        () => ne.find(
          title: c.title,
          artist: c.artist,
          durationSec: sec,
          cancel: cancel,
        ),
      );
      if (r != null) {
        synced = r.synced;
        source = 'netease';
      }
    }
    final syncedFailed = failed; // lyrics.ovh never gives a synced text
    final o = ovh;
    if (!_has(plain) && !_has(synced) && o != null) {
      final r = await fallback(
        () => o.find(
          title: c.title,
          artist: extractPrimaryArtist(c.artist),
          cancel: cancel,
        ),
      );
      if (r != null) {
        plain = r.plain;
        source = 'lyricsovh';
      }
    }
    final out = LyricsResult(plain: plain, synced: synced);
    return out.isEmpty
        ? LyricsChainResult(
            failed: failed,
            syncedFailed: syncedFailed,
            limited: limited,
          )
        : LyricsChainResult(
            lyrics: out,
            syncedFailed: syncedFailed,
            limited: limited,
            source: source,
          );
  }
}
