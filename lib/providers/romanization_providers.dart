import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_log.dart';
import '../core/paths.dart';
import '../services/lyrics/lyrics_shown.dart';
import '../services/lyrics/romanization_cache.dart';
import '../services/lyrics/romanization_resolver.dart';
import '../services/lyrics/script_detect.dart';
import 'chinese_dictionary_providers.dart';
import 'database_providers.dart' show trackRepositoryProvider;
import 'import_providers.dart' show importedTrackProvider;
import 'online_providers.dart';
import 'settings_providers.dart';

/// `<appSupportDir>/romanization_cache.json`; overridden in tests.
final romanizationCacheProvider = Provider<RomanizationCache>(
  (ref) => RomanizationCache(
    file: () async =>
        File(p.join(await appSupportDir(), romanizationCacheFileName)),
    liveIds: ref.read(trackRepositoryProvider).allIds,
  ),
);

/// Everything the transliteration of one track depends on. A change of any of
/// it is another key, so another resolver run starts from nothing: the view
/// never shows the old transliteration under a new text.
typedef _Key = ({
  int id,
  bool enabled,
  bool online,
  String? manual,
  bool handWritten,
  bool unsynced,
  String title,
  String artist,
  int durationMs,
  String? plain,
  String? synced,
});

final _keyProvider = Provider.autoDispose.family<_Key?, int>((ref, id) {
  final s = ref.watch(
    settingsProvider.select((s) => (s.romanization, s.autoLyrics)),
  );
  final manual = ref.watch(manualRomanizationProvider.select((m) => m[id]));
  final handWritten = ref.watch(
    handWrittenLyricsProvider.select((h) => h.contains(id)),
  );
  final unsynced = ref.watch(
    unsyncedLyricsProvider.select((u) => u.contains(id)),
  );
  final t = ref.watch(importedTrackProvider(id)).value;
  if (t == null) return null;
  return (
    id: id,
    enabled: s.$1,
    online: s.$2,
    manual: manual,
    handWritten: handWritten,
    unsynced: unsynced,
    title: t.title,
    artist: t.artist ?? '',
    durationMs: t.durationMs,
    plain: t.lyricsPlain,
    synced: t.lyricsSynced,
  );
});

// No automatic retry: a failure shows as «unavailable» (see [romanizationProvider]).
final _resolvedProvider = StreamProvider.autoDispose
    .family<RomanizationState, _Key>(retry: (_, _) => null, (ref, k) async* {
      // Chinese text only: keeps the dictionary (and its ~200k words in
      // memory) while this provider lives; other scripts never load it.
      if (detectScript('${k.plain ?? ''}\n${k.synced ?? ''}') ==
          LyricsScript.chinese) {
        ref.listen(chineseDictionaryProvider, (_, _) {});
      }
      final cancel = CancelToken();
      ref.onDispose(cancel.cancel);
      ChineseDictionaryNotifier dict() =>
          ref.read(chineseDictionaryProvider.notifier);
      final resolver = RomanizationResolver(
        cache: ref.read(romanizationCacheProvider),
        fetch: (i, c) => ref
            .read(neteaseLyricsClientProvider)
            .romanized(
              title: i.title,
              artist: i.artist,
              durationSec: i.durationSec,
              cancel: c,
            ),
        dictionaryInstalled: () => dict().installed(),
        dictionary: ({required download}) =>
            dict().ensure(download: download, automatic: true),
      );
      final off = k.unsynced && k.synced != null;
      yield* resolver.resolve(
        RomanizationInput(
          trackId: k.id,
          title: k.title,
          artist: k.artist,
          durationSec: k.durationMs > 0 ? (k.durationMs / 1000).round() : null,
          plain: off ? plainTextOf(k.plain, k.synced) : k.plain,
          synced: off ? null : k.synced,
          manual: k.manual,
          handWritten: k.handWritten,
          enabled: k.enabled,
          online: k.online,
        ),
        cancel: cancel,
      );
    });

/// The transliteration under the lyrics of track [id] (a library row, real id):
/// off / loading / downloading the dictionary / ready / unavailable. The lines
/// align with the text as shown (see [RomanizationState.lines]). Reads
/// `value ?? RomanizationState.loading`.
///
/// When the text, the settings or the typed transliteration change, the value
/// is empty (loading) until the new one is known, never the old one.
///
/// Network (NetEase, dictionary download) only when the automatic lyrics search
/// is on: the same opt-in as the lyrics enrichment. A text the user
/// typed in the editor counts as hand-written (`handWrittenLyricsProvider`).
final romanizationProvider = Provider.autoDispose
    .family<AsyncValue<RomanizationState>, int>((ref, id) {
      final k = ref.watch(_keyProvider(id));
      if (k == null) return const AsyncData(RomanizationState.loading);
      final r = ref.watch(_resolvedProvider(k));
      if (r is AsyncError<RomanizationState>) {
        AppLog.w('transliteration failed', r.error, r.stackTrace);
        return const AsyncData(RomanizationState.unavailable);
      }
      return r;
    });
