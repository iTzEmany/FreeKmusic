import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _langs = ['en', 'de', 'es', 'fr', 'pt'];

/// Strings that may read the same as the Italian: names, formats, units and
/// words that are the same in the other languages.
const _sameAsItalian = {
  'podcastOriginApple', 'podcastGenreSports', 'podcastGenreTrueCrime', 'podcastGenreTvFilm', 'podcastGenreTechnology', 'podcastGenreGovernment',
  'speakerNo', 'recogSrcVideo', 'releaseAlbumYear', 'releaseAlbumPlain', 'settingsPageBackup', 'summaryCrossfade',
  'tokenSurface1', 'tokenSurface2', 'tokenSurface3', 'themeCopyName',
  'accentRosa', 'backupSection', 'accentVerde', 'activityDownload', 'albumMeta', 'appName',
  'hoursAndMinutes', 'ytmArtistWithAudience', 'csvImportPause', 'csvOutHeaderAlbum', 'csvOutHeaderIsrc',
  'csvOutHeaderNote', 'detailFormat', 'devicesJamShort', 'discN',
  'downloadRateKb', 'downloadRateMb', 'durationMinutes', 'exportFormatJson',
  'fieldAlbum', 'fieldArtist', 'jamHostTag', 'jamOutputOther', 'jamTitle',
  'jamWith', 'kindAlbum', 'kindArtist', 'kindPlaylist', 'navHome', 'pause',
  'proposedValue', 'settingsAbout', 'settingsOnline', 'settingsTheme',
  'sharePin', 'sortAlbum', 'sortArtist', 'sortAscending', 'sortDescending', 'textLarge', 'tracksAndDuration',
  'youtube', 'ytDlpVersion', 'statsBarValue', 'statsHoursMinutes', 'statsFirstValue',
  'homeShuffleAllSub', 'playerResumeLastQueueSub', 'smartName', 'smartPlaylistLabel', 'searchSourceYoutube', 'searchSourceYoutubeMusic',
  'searchSourceSoundcloud', 'downloadFormatMp3High', 'importPhaseDownloading', 'activityLog', 'importPhaseDownloadStart', 'memoryCache',
  'radioTitle', 'radioAddName', 'radioOnlyCountry', 'radioGenrePop', 'radioGenreRock',
  'radioGenreJazz', 'radioGenreBlues', 'radioGenreDance', 'radioGenreHouse',
  'radioGenreHipHop', 'radioGenreLoFi', 'radioGenreChillout', 'radioGenreOldies',
  'radioGenreMetal', 'radioGenreReggae', 'radioGenreLatin', 'radioGenreSoul',
  'radioGenreSports', 'reportKindIdea', 'sortAToZ',
  'daylistTitle', 'settingsPageDaylist', 'daylistSlotRowLabel', 'daylistGenreMoodLabel',
  'recogIdent', 'recogCover', 'jamBrokerPort', 'coverSourceOnline', 'coverSizePx', 'creditRolePiano', 'creditRoleMastering', 'creditsBpm', 'creditsKindEp',
};

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _keys(Map<String, dynamic> arb) =>
    {for (final k in arb.keys) if (!k.startsWith('@')) k};

/// Names inside {…} that are not plural/select branches.
Set<String> _placeholders(String s) => {
      // «=0{Vuota}» is text, not a placeholder.
      for (final m in RegExp(r'\{(\w+)(?=[,}])')
          .allMatches(s.replaceAll(RegExp(r'=\d+\{[^{}]*\}'), '')))
        if (!const {'one', 'other', 'zero', 'two', 'few', 'many'}.contains(m[1]))
          m[1]!,
    };

void main() {
  final it = _arb('it');
  final itKeys = _keys(it);

  test('the template has strings', () {
    expect(itKeys.length, greaterThan(500));
  });

  for (final lang in _langs) {
    group(lang, () {
      final arb = _arb(lang);

      test('has exactly the keys of the Italian template', () {
        final keys = _keys(arb);
        expect(itKeys.difference(keys), isEmpty, reason: 'missing in $lang');
        expect(keys.difference(itKeys), isEmpty, reason: 'not in the template');
      });

      test('declares its own locale', () {
        expect(arb['@@locale'], lang);
      });

      test('uses the same placeholders as the Italian in every string', () {
        for (final k in itKeys) {
          expect(
            _placeholders(arb[k] as String),
            _placeholders(it[k] as String),
            reason: '$lang/$k',
          );
        }
      });

      test('no string is empty and plurals keep their «other» branch', () {
        for (final k in itKeys) {
          final v = arb[k] as String;
          expect(v.trim(), isNotEmpty, reason: '$lang/$k');
          if ((it[k] as String).contains('plural,')) {
            expect(v, contains('other{'), reason: '$lang/$k');
          }
        }
      });

      test('nothing is left in Italian, apart from names and shared words', () {
        final same = {
          for (final k in itKeys)
            if (arb[k] == it[k]) k,
        };
        expect(
          same.difference(_sameAsItalian),
          isEmpty,
          reason: '$lang: untranslated strings',
        );
      });
    });
  }

  test('French and Portuguese avoid the straight apostrophe (ICU escape)', () {
    for (final lang in ['fr', 'pt']) {
      final arb = _arb(lang);
      for (final k in itKeys) {
        expect((arb[k] as String).contains("'"), isFalse, reason: '$lang/$k');
      }
    }
  });

  test('no separator dots or arrows', () {
    for (final lang in ['it', ..._langs]) {
      final arb = _arb(lang);
      for (final k in _keys(arb)) {
        final v = arb[k] as String;
        expect(
          v.contains(' · ') || v.contains(' • ') || v.contains('→'),
          isFalse,
          reason: '$lang/$k: $v',
        );
      }
    }
  });

  test('every creditRole key exists in all six ARB files', () {
    final roles = _keys(it).where((k) => k.startsWith('creditRole')).toSet();
    expect(roles, isNotEmpty);
    for (final lang in _langs) {
      expect(roles.difference(_keys(_arb(lang))), isEmpty, reason: lang);
    }
  });

  test('the unsubscribe dialog has an ICU plural with a zero, one and other form in every language', () {
    for (final lang in ['it', ..._langs]) {
      final v = _arb(lang)['podcastUnsubscribeBody'] as String;
      expect(v, startsWith('{count, plural, =0{'), reason: lang);
      expect(v, contains('one{'), reason: lang);
      expect(v, contains('other{'), reason: lang);
    }
  });
}
