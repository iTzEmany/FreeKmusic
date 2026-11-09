import 'package:dio/dio.dart' show CancelToken;

import '../../core/app_log.dart';
import '../online/lrc_parser.dart';
import 'hangul_romanizer.dart';
import 'pinyin_dictionary.dart';
import 'romanization_cache.dart';
import 'romanization_match.dart';
import 'script_detect.dart';

enum RomanizationStatus { off, loading, downloading, ready, unavailable }

/// Where the shown lines came from (the UI may offer «Elimina» for [manual]).
enum RomanizationSource { manual, computed, found, dictionary }

/// What a lyrics view shows under the original lines.
class RomanizationState {
  const RomanizationState(this.status, {this.lines = const [], this.source});

  const RomanizationState.ready(this.lines, this.source)
    : status = RomanizationStatus.ready;

  static const off = RomanizationState(RomanizationStatus.off);
  static const loading = RomanizationState(RomanizationStatus.loading);
  static const downloading = RomanizationState(RomanizationStatus.downloading);
  static const unavailable = RomanizationState(RomanizationStatus.unavailable);

  final RomanizationStatus status;

  /// When ready: one entry per line of the text shown (synced: `parseLrc` order;
  /// plain: [plainLines]), null where a line has none (blank, credit, no CJK).
  final List<String?> lines;
  final RomanizationSource? source;
}

/// The lines of an unsynchronised text, as the transliteration is aligned to them.
List<String> plainLines(String plain) => plain.split(RegExp(r'\r?\n'));

/// Everything that decides the transliteration of one track.
class RomanizationInput {
  const RomanizationInput({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.durationSec,
    this.plain,
    this.synced,
    this.manual,
    this.handWritten = false,
    this.enabled = true,
    this.online = false,
  });

  final int trackId;
  final String title, artist;
  final int? durationSec;

  /// The text as shown (the sync switch already applied).
  final String? plain, synced;

  /// Transliteration typed by the user, if any.
  final String? manual;

  /// The lyrics are the user's (D-475): only Korean is computed, nothing is searched.
  final bool handWritten;
  final bool enabled;

  /// The lyrics enrichment's network rule: web and dictionary download allowed.
  final bool online;
}

/// D-475: manual -> (hand-written text: only Korean) -> Korean computed ->
/// cache -> NetEase (saved, «none» too) -> Chinese dictionary -> unavailable.
/// Under half of the lines matched counts as unavailable.
class RomanizationResolver {
  RomanizationResolver({
    required this.cache,
    required this.fetch,
    required this.dictionaryInstalled,
    required this.dictionary,
  });

  final RomanizationCache cache;

  /// The `romalrc` of the song (NetEase); throws when the service fails.
  final Future<String?> Function(RomanizationInput, CancelToken?) fetch;

  /// The dictionary is on the device (loaded or as a file): no download needed.
  final Future<bool> Function() dictionaryInstalled;

  /// Loads the dictionary, downloading it when [download]; null when it fails.
  final Future<PinyinDictionary?> Function({required bool download}) dictionary;

  Stream<RomanizationState> resolve(
    RomanizationInput i, {
    CancelToken? cancel,
  }) async* {
    final synced = i.synced == null ? const <LrcLine>[] : parseLrc(i.synced!);
    final isSynced = synced.isNotEmpty;
    final original = isSynced
        ? [for (final l in synced) l.text]
        : plainLines(i.plain ?? '');
    final script = detectScript(original.join('\n'));
    if (!i.enabled || script == null) {
      yield RomanizationState.off;
      return;
    }
    yield RomanizationState.loading;

    RomanizationState? ready(RomanizationMatch m, RomanizationSource s) =>
        m.available ? RomanizationState.ready(m.lines, s) : null;

    final manual = i.manual;
    final hit =
        (manual == null
            ? null
            : ready(
                matchManualRomanization(original, manual),
                RomanizationSource.manual,
              )) ??
        (script == LyricsScript.korean
            ? ready(_korean(original), RomanizationSource.computed)
            : null);
    if (hit != null) {
      yield hit;
      return;
    }
    if (i.handWritten) {
      yield RomanizationState.unavailable;
      return;
    }

    RomanizationMatch fit(String lrc) => isSynced
        ? matchRomanization(synced, lrc)
        : matchRomanizationByIndex(original, lrc);

    final cached = await cache.get(i.trackId);
    var found = cached?.lrc == null
        ? null
        : ready(fit(cached!.lrc!), RomanizationSource.found);
    // A «none» still fresh is believed; a saved text that no longer fits is asked again.
    if (found == null && i.online && (cached == null || cached.lrc != null)) {
      try {
        final lrc = await fetch(i, cancel);
        await cache.put(i.trackId, lrc);
        if (lrc != null) found = ready(fit(lrc), RomanizationSource.found);
      } on Object catch (e, st) {
        if (!(cancel?.isCancelled ?? false)) {
          AppLog.w('romalrc lookup failed, not saved', e, st);
        }
      }
    }
    if (found != null) {
      yield found;
      return;
    }

    if (script == LyricsScript.chinese) {
      final installed = await dictionaryInstalled();
      if (installed || i.online) {
        if (!installed) yield RomanizationState.downloading;
        final d = await dictionary(download: i.online);
        final m = d == null ? null : _pinyin(original, d);
        if (m != null && m.available) {
          yield RomanizationState.ready(m.lines, RomanizationSource.dictionary);
          return;
        }
      }
    }
    yield RomanizationState.unavailable;
  }

  // Lines with nothing to convert (English, blank) stay null and are not counted.
  RomanizationMatch _convert(List<String> original, String Function(String) f) {
    final out = List<String?>.filled(original.length, null);
    var total = 0;
    for (var k = 0; k < original.length; k++) {
      final r = f(original[k]);
      if (r == original[k]) continue;
      out[k] = r;
      total++;
    }
    return RomanizationMatch(out, total);
  }

  RomanizationMatch _korean(List<String> original) =>
      _convert(original, romanizeHangul);

  RomanizationMatch _pinyin(List<String> original, PinyinDictionary d) =>
      _convert(original, d.romanize);
}
