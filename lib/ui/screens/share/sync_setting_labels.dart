import 'package:intl/intl.dart';

import '../../../data/repositories/library_entries.dart' show LibrarySort;
import '../../../l10n/app_localizations.dart';
import '../../../services/audio/audio_backend.dart' show TransitionMode;
import '../../../services/online/youtube_service.dart'
    show AudioQuality, DownloadFormat;
import '../../theme/palette.dart';
import '../settings/accent_picker.dart';
import '../settings/download_settings_tiles.dart';
import '../settings/quality_tiles.dart';
import '../settings/settings_pages.dart' show languageName;
import '../settings/transition_settings_tiles.dart';

/// The label each synced setting has in the Settings pages, by store key (a test checks every synced key is here).
final Map<String, String Function(AppLocalizations)> syncSettingLabels = {
  'theme': (l) => l.settingsTheme,
  'accent': (l) => l.settingsAccent,
  'fontScale': (l) => l.settingsTextSize,
  'compactMode': (l) => l.settingsCompact,
  'reducedMotion': (l) => l.settingsReducedMotion,
  'spinCover': (l) => l.settingsSpinCover,
  'language': (l) => l.settingsLanguage,
  'autoEnrich': (l) => l.autoEnrich,
  'autoLyrics': (l) => l.autoLyrics,
  'deezerMeta': (l) => l.deezerMeta,
  'creditsDetails': (l) => l.creditsDetails,
  'romanization': (l) => l.romanization,
  'autoCuriosities': (l) => l.autoCuriosities,
  'showUndoSnackbar': (l) => l.syncSettingUndo,
  'normalizeVolume': (l) => l.normalizeVolume,
  'librarySort': (l) => l.sortBy,
  'librarySortAscending': (l) => l.syncSettingSortDirection,
  'downloadFormat': (l) => l.downloadFormat,
  'downloadQuality': (l) => l.qualityDownload,
  'streamQuality': (l) => l.qualityStream,
  'importSureThreshold': (l) => l.importSureThreshold,
  'importReviewThreshold': (l) => l.importReviewThreshold,
  'playbackSpeed': (l) => l.playbackSpeed,
  'showKaraoke': (l) => l.showKaraoke,
  'transition': (l) => l.transitionMode,
  'crossfadeSeconds': (l) => l.syncSettingCrossfade,
  'crossfadePlainInAlbum': (l) => l.crossfadePlainInAlbum,
  'shufflePlus': (l) => l.shufflePlusTitle,
  'shufflePlusEvery': (l) => l.syncSettingShuffleEvery,
};

/// A synced setting's name as the Settings pages say it; an unknown key is shown as it is.
String syncSettingLabel(AppLocalizations l, String key) =>
    syncSettingLabels[key]?.call(l) ?? key;

/// A synced setting's value as the Settings pages show it: on/off, the choice's label, numbers in the user's language.
String syncSettingValue(AppLocalizations l, String key, Object? v) {
  if (v == null) return '—';
  if (key == 'librarySortAscending' && v is bool) {
    return v ? l.sortAscending : l.sortDescending;
  }
  if (v is bool) return v ? l.syncOn : l.syncOff;
  final n = v is num ? v.toDouble() : null;
  String fmt(String pattern) => NumberFormat(pattern, l.localeName).format(v);
  return switch (key) {
    'theme' => switch (appThemeIdFromName('$v')) {
      AppThemeId.notte => l.themeNotte,
      AppThemeId.oled => l.themeOled,
      AppThemeId.chiaro => l.themeChiaro,
    },
    'accent' => accentLabel(l, accentFromName('$v')),
    'language' => languageName('$v'),
    'fontScale' => switch (n) {
      0.9 => l.textSmall,
      1.0 => l.textNormal,
      1.15 => l.textLarge,
      _ => '$v',
    },
    'librarySort' => switch (LibrarySort.values.asNameMap()['$v']) {
      LibrarySort.recent => l.sortRecent,
      LibrarySort.added => l.sortAddedRecently,
      LibrarySort.alpha => l.sortTitleAToZ,
      LibrarySort.artist => l.sortArtist,
      LibrarySort.year => l.sortYear,
      LibrarySort.plays => l.sortMostPlayed,
      LibrarySort.duration => l.sortDuration,
      LibrarySort.trackCount => l.sortTrackCount,
      null => '$v',
    },
    'downloadFormat' => switch (DownloadFormat.values.asNameMap()['$v']) {
      final f? => downloadFormatLabel(l, f),
      null => '$v',
    },
    'downloadQuality' || 'streamQuality' => switch (AudioQuality.values
        .asNameMap()['$v']) {
      final q? => audioQualityLabel(l, q),
      null => '$v',
    },
    'transition' => switch (TransitionMode.values.asNameMap()['$v']) {
      final m? => transitionLabel(l, m),
      null => '$v',
    },
    'importSureThreshold' ||
    'importReviewThreshold' when n != null => '${(n * 100).round()}%',
    'playbackSpeed' when n != null => '${fmt('0.##')}×',
    'crossfadeSeconds' => '$v s',
    _ => '$v',
  };
}
