import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/paths.dart';
import '../services/lyrics/lyrics_shown.dart';
import '../services/lyrics/romanization_cache.dart';
import '../services/lyrics/romanization_resolver.dart';
import 'chinese_dictionary_providers.dart';
import 'database_providers.dart';
import 'import_providers.dart' show importedTrackProvider;
import 'online_providers.dart';
import 'settings_providers.dart';

/// `<appSupportDir>/romanization_cache.json`; overridden in tests.
final romanizationCacheProvider = Provider<RomanizationCache>(
  (ref) => RomanizationCache(
    file: () async =>
        File(p.join(await appSupportDir(), 'romanization_cache.json')),
  ),
);

/// The transliteration under the lyrics of track [id] (a library row, real id):
/// off / loading / downloading the dictionary / ready / unavailable. The lines
/// align with the text as shown (see [RomanizationState.lines]). Reads
/// `value ?? RomanizationState.loading`.
///
/// Network (NetEase, dictionary download) only when the automatic lyrics search
/// is on: the same opt-in as the lyrics enrichment. A text the user typed or
/// chose counts as hand-written (`lyricsByUser`).
final romanizationProvider = StreamProvider.autoDispose
    .family<RomanizationState, int>((ref, id) async* {
      final s = ref.watch(
        settingsProvider.select((s) => (s.romanization, s.autoLyrics)),
      );
      final manual = ref.watch(manualRomanizationProvider.select((m) => m[id]));
      final unsynced = ref.watch(
        unsyncedLyricsProvider.select((u) => u.contains(id)),
      );
      final t = ref.watch(
        importedTrackProvider(id).select(
          (a) => a.value == null
              ? null
              : (
                  a.value!.title,
                  a.value!.artist,
                  a.value!.durationMs,
                  a.value!.lyricsPlain,
                  a.value!.lyricsSynced,
                ),
        ),
      );
      // Keeps the dictionary (and its memory) while this provider lives.
      ref.listen(chineseDictionaryProvider, (_, _) {});
      if (t == null) {
        yield RomanizationState.loading;
        return;
      }
      final (title, artist, durationMs, plain, synced) = t;
      final cancel = CancelToken();
      ref.onDispose(cancel.cancel);
      final dict = ref.read(chineseDictionaryProvider.notifier);
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
        dictionaryInstalled: dict.installed,
        dictionary: ({required download}) => dict.ensure(download: download),
      );
      final off = unsynced && synced != null;
      yield* resolver.resolve(
        RomanizationInput(
          trackId: id,
          title: title,
          artist: artist ?? '',
          durationSec: durationMs > 0 ? (durationMs / 1000).round() : null,
          plain: off ? plainTextOf(plain, synced) : plain,
          synced: off ? null : synced,
          manual: manual,
          handWritten: await ref.read(trackRepositoryProvider).lyricsByUser(id),
          enabled: s.$1,
          online: s.$2,
        ),
        cancel: cancel,
      );
    });
