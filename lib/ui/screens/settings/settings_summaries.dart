import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_info.dart';
import '../../../core/constants.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/daylist_providers.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/share_providers.dart';
import '../../../providers/theme_providers.dart';
import '../../../services/audio/audio_backend.dart' show TransitionMode;
import '../../theme/app_theme.dart';
import 'accent_picker.dart';
import 'download_settings_tiles.dart';
import 'settings_pages.dart';
import 'transition_settings_tiles.dart';

/// The line under an index entry. Reads providers that are already loaded.
String settingsSummary(BuildContext context, WidgetRef ref, SettingsPage p) {
  final l = context.l10n;
  final s = ref.watch(settingsProvider);
  switch (p) {
    case SettingsPage.appearance:
      final customId = customThemeIdOf(s.theme);
      final custom = customId == null
          ? null
          : ref.watch(customThemesProvider).byId(customId);
      final theme =
          custom?.name ??
          switch (appThemeIdFromName(s.theme)) {
            AppThemeId.notte => l.themeNotte,
            AppThemeId.oled => l.themeOled,
            AppThemeId.chiaro => l.themeChiaro,
          };
      return [
        theme,
        accentLabel(l, accentFromName(s.accent)),
        languageName(s.language),
      ].join(', ');
    case SettingsPage.playback:
      final t = transitionLabel(l, s.transition);
      return [
        s.transition == TransitionMode.crossfade
            ? '$t ${l.summaryCrossfade(s.crossfadeSeconds)}'
            : t,
        if (s.normalizeVolume) l.summaryNormalizeOn,
      ].join(', ');
    case SettingsPage.library:
      final folders = ref.watch(foldersProvider).value?.length;
      final tracks = ref.watch(trackCountProvider).value;
      // Nothing until both are known: no "0 cartelle, 0 brani" flash.
      return folders == null || tracks == null
          ? ''
          : l.summaryLibrary(folders, tracks);
    case SettingsPage.daylist:
      return l.daylistSummaryPage(
        ref.watch(daylistConfigProvider).slots.where((s) => s.enabled).length,
      );
    case SettingsPage.online:
      return kEnableYoutube
          ? downloadFormatLabel(l, s.downloadFormat)
          : (s.autoEnrich ? l.autoEnrich : l.settingsOnline);
    case SettingsPage.network:
      final n = ref.watch(trustedDevicesProvider).all.length;
      return n == 0 ? ref.watch(deviceNameProvider) : l.summaryTrusted(n);
    case SettingsPage.backup:
      return l.summaryBackup;
    case SettingsPage.advanced:
      return l.appVersion(kAppVersion);
  }
}
